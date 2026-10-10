#!/usr/bin/env python3
"""The review bot (ADR-0038): review mails become proposal PRs, agreement
becomes an apply PR, outdated proposals are closed, each merged once its
checks pass, and nothing is opened twice.

Stdlib `unittest` plus PyYAML. Git and GitHub are fakes: a "main" folder
in a temporary directory, and PRs in memory. No network.
"""

from __future__ import annotations

import contextlib
import email.message
import io
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import mail_to_issues  # noqa: E402
import proposals as pr  # noqa: E402
import review_bot as rb  # noqa: E402
import validate_decks as vd  # noqa: E402
from test_mail_to_issues import ENV, FakeImap  # noqa: E402
from test_proposals import ALICE, BOB, SINGLE, TOOLS  # noqa: E402

SECRET = "SECRET SUGGESTION TEXT"


class FakeGit:
    """`main` is a folder; a branch is a copy of it, kept when pushed."""

    def __init__(self, tmp: Path) -> None:
        self.tmp = tmp
        self.main = tmp / "main"
        shutil.copytree(TOOLS / "fixtures" / "b1" / "zz", self.main / "decks" / "zz")
        (self.main / "decks" / "zz" / "zz-en-extra.yaml").write_text(SINGLE, encoding="utf-8")
        self.branches: dict[str, dict[str, str]] = {}
        # What main held when each branch was last pushed.
        self.bases: dict[str, dict[str, str]] = {}
        self.pushes: list[str] = []
        self.made = 0
        self.invalid = False

    @staticmethod
    def snapshot(root: Path) -> dict[str, str]:
        return {p.relative_to(root).as_posix(): p.read_text(encoding="utf-8")
                for p in sorted((root / "decks").rglob("*.yaml"))}

    def fresh(self, branch: str) -> Path:
        self.made += 1
        root = self.tmp / f"work{self.made}"
        shutil.copytree(self.main, root)
        return root

    def push(self, root: Path, branch: str, message: str) -> bool:
        files = self.snapshot(root)
        if files == self.snapshot(self.main):
            return False
        self.branches[branch] = files
        self.bases[branch] = self.snapshot(self.main)
        self.pushes.append(branch)
        return True

    def reindex(self, root: Path) -> None:
        pass

    def valid(self, root: Path, langs: list[str]) -> bool:
        if self.invalid:
            return False
        return all(not vd.validate(p).errors
                   for lang in langs for p in vd._yaml_files(root / "decks" / lang))

    def merge(self, branch: str) -> None:
        for rel, text in self.branches[branch].items():
            (self.main / rel).write_text(text, encoding="utf-8")


class FakeGitHub:
    def __init__(self, git: FakeGit) -> None:
        self.git = git
        self.prs: list[dict] = []
        self.check = "passed"
        self.dirty = 0
        self.closed: list[int] = []
        self.merged_at: list[str] = []

    def find_pr(self, branch: str) -> dict | None:
        found = [p for p in self.prs if p["head"]["ref"] == branch]
        return found[-1] if found else None

    def open_pr(self, branch: str, title: str, body: str, labels: list[str]) -> dict:
        made = {"number": len(self.prs) + 1, "state": "open", "merged_at": None,
                "head": {"ref": branch, "sha": f"sha{len(self.prs)}"},
                "title": title, "body": body,
                "labels": [{"name": n} for n in labels]}
        self.prs.append(made)
        return made

    def open_prs(self, prefix: str) -> list[dict]:
        return [p for p in self.prs
                if p["state"] == "open" and p["head"]["ref"].startswith(prefix)]

    def checks(self, sha: str) -> str:
        return self.check

    def behind(self, sha: str) -> bool | None:
        branch = next(p["head"]["ref"] for p in self.prs if p["head"]["sha"] == sha)
        return self.git.bases[branch] != self.git.snapshot(self.git.main)

    def merge(self, found: dict, sha: str) -> str:
        if self.dirty:
            self.dirty -= 1
            return "behind"
        self.merged_at.append(sha)
        self.git.merge(found["head"]["ref"])
        found.update(state="closed", merged_at="2026-10-09T12:00:00Z")
        return "merged"

    def label(self, number: int, labels: list[str]) -> None:
        self.prs[number - 1]["labels"] += [{"name": n} for n in labels]

    def close(self, number: int, comment: str) -> None:
        self.prs[number - 1]["state"] = "closed"
        self.closed.append(number)

    def refresh(self, number: int) -> dict:
        return self.prs[number - 1]


def review_file(cards: list[dict], code: str = ALICE, deck: str = "zz-en-extra") -> dict:
    return {"format": "fluenough-review", "version": 1, "rater_code": code,
            "language": "zz", "deck": deck, "app_version": "0.4.0",
            "made": "2026-10-09T09:41:00.000Z", "signed_off": False,
            "cards": cards}


def suggestion(card: str, part: str, now: str, text: str, why: str = "") -> dict:
    return {"card": card, "at": "2026-10-09T09:40:00.000Z",
            "suggestion": {"part": part, "now": now, "text": text, "why": why}}


class Base(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.git = FakeGit(self.tmp)
        self.github = FakeGitHub(self.git)
        self.logged: list[str] = []
        self.bot = self.make_bot(1)

    def make_bot(self, threshold: int) -> rb.Bot:
        return rb.Bot(self.git, self.github, threshold, self.logged.append)

    def main_text(self, rel: str = "decks/zz/zz-en-extra.yaml") -> str:
        return (self.git.main / rel).read_text(encoding="utf-8")

    def put_on_main(self, p: pr.Proposal, deck: str = "zz-en-extra") -> None:
        result = pr.Proposed()
        pr.propose(self.git.main, pr.Suggestion("zz", deck, p), result)
        self.assertEqual(result.added, [p])

    def p(self, **kw) -> pr.Proposal:
        facts = dict(card="zz-9201", field="native", now="milk", text="cow's milk",
                     by=ALICE, date="2026-10-09")
        facts.update(kw)
        return pr.Proposal(**facts)


class Threshold(unittest.TestCase):
    def test_the_variable_or_one(self) -> None:
        for raw, wanted in (("", 1), ("abc", 1), ("0", 1), ("-2", 1), ("1.5", 1),
                            ("2", 2), (" 3 ", 3)):
            with self.subTest(raw=raw):
                self.assertEqual(rb.agreements_needed({rb.THRESHOLD: raw}), wanted)
        self.assertEqual(rb.agreements_needed({}), 1)


class ReadingReviews(unittest.TestCase):
    def test_suggestions_answers_and_what_is_left(self) -> None:
        files = [review_file([
            suggestion("zz-9201", "meaning", "milk", " cow's milk ", "Why not"),
            suggestion("zz-9201", "example", "x", "y"),
            # A base word's meaning (#410) is left for the owner too.
            {"card": "zz-9201", "at": "2026-10-09T09:40:00.000Z",
             "suggestion": {"part": "base", "word": "w", "now": "x", "text": "y"}},
            {"card": "zz-9202", "at": "2026-10-09T09:40:00.000Z", "proposals": [
                {"id": "aaaaaaaaaa", "answer": "accept", "field": "native", "text": "t"},
                {"id": "bbbbbbbbbb", "answer": "reject", "field": "native", "text": "u"},
                {"id": "cccccccccc", "answer": "edit", "field": "native", "text": "v"},
            ]},
        ]), review_file([suggestion("zz-9201", "word", "a", "b")], code=BOB)]
        review = rb.read_review(files, ALICE)
        self.assertEqual(len(review.suggestions), 1)
        s = review.suggestions[0]
        self.assertEqual((s.lang, s.deck), ("zz", "zz-en-extra"))
        self.assertEqual(s.proposal, pr.Proposal("zz-9201", "native", "milk",
                                                 "cow's milk", ALICE, "2026-10-09",
                                                 "Why not"))
        self.assertEqual(review.left, 2)
        self.assertEqual(review.accepts, [("zz", "aaaaaaaaaa", "t")])
        self.assertEqual(review.rejects, [("zz", "bbbbbbbbbb", "zz-9202")])
        self.assertEqual(review.edits, 1)


    def test_a_file_whose_language_is_not_a_code_is_dropped(self) -> None:
        files = []
        for lang in ("", ".", "..", "../x", "zz/..", "ZZ", "*", "zzzz"):
            f = review_file([suggestion("zz-9201", "meaning", "milk", "cow's milk")])
            f["language"] = lang
            files.append(f)
        review = rb.read_review(files, ALICE)
        self.assertEqual(review.suggestions, [])
        self.assertEqual(review.dropped, len(files))


class Checks(unittest.TestCase):
    """Only the checks `main` requires gate a merge."""

    @staticmethod
    def run_(name: str, status: str = "completed", conclusion: str | None = "success") -> dict:
        return {"name": name, "status": status, "conclusion": conclusion}

    def test_the_required_checks_and_only_those(self) -> None:
        ok = [self.run_(n) for n in rb.REQUIRED_CHECKS]
        self.assertEqual(rb.required_state(ok), "passed")
        self.assertEqual(rb.required_state(ok + [self.run_("Other", conclusion="failure")]),
                         "passed")
        self.assertEqual(rb.required_state(ok + [self.run_("Other", "in_progress", None)]),
                         "passed")
        self.assertEqual(rb.required_state([]), "missing")
        self.assertEqual(rb.required_state([self.run_("Other")]), "missing")
        self.assertEqual(rb.required_state(ok[:2]), "pending")
        self.assertEqual(rb.required_state(
            ok[:2] + [self.run_(rb.REQUIRED_CHECKS[2], "queued", None)]), "pending")
        self.assertEqual(rb.required_state(
            ok[:1] + [self.run_(rb.REQUIRED_CHECKS[1], conclusion="failure")]), "failed")

    def test_they_are_the_jobs_of_ci(self) -> None:
        import yaml
        ci = yaml.safe_load((TOOLS.parent / ".github" / "workflows" / "ci.yml")
                            .read_text(encoding="utf-8"))
        self.assertEqual(sorted(j["name"] for j in ci["jobs"].values()),
                         sorted(rb.REQUIRED_CHECKS))

    def test_rest_reads_the_latest_runs_and_merges_at_the_checked_head(self) -> None:
        calls: list[tuple] = []

        class Stub(rb.RestGitHub):
            def _call(self, method, path, body=None, token=None):
                calls.append((method, path, body, token))
                if "/check-runs" in path:
                    return 200, {"check_runs": [Checks.run_(n) for n in rb.REQUIRED_CHECKS]}
                if path.startswith("/compare/"):
                    return 200, {"behind_by": 2}
                if method == "GET":
                    return 200, {"merged": False, "mergeable_state": "clean",
                                 "head": {"sha": "moved"}}
                return 200, {}
        gh = Stub("o/r", "app", "reader")
        self.assertEqual(gh.checks("abc"), "passed")
        self.assertIn("filter=latest", calls[0][1])
        self.assertEqual(calls[0][3], "reader")
        self.assertTrue(gh.behind("abc"))
        # The head moved since its checks passed: not merged.
        self.assertEqual(gh.merge({"number": 3}, "abc"), "pending")
        self.assertFalse(any(m == "PUT" for m, *_ in calls))
        self.assertEqual(gh.merge({"number": 3}, "moved"), "merged")
        self.assertEqual(calls[-1][2]["sha"], "moved")


class Reviews(Base):
    def review(self) -> rb.Review:
        return rb.read_review([review_file([
            suggestion("zz-9201", "meaning", "milk", "cow's milk", SECRET),
            suggestion("zz-9004", "meaning", "mother", "mum")], deck="zz-en-extra")],
            ALICE)

    def test_a_review_becomes_one_pr_that_merges_once_checks_pass(self) -> None:
        self.github.check = "pending"
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "pending")
        self.assertEqual(len(self.github.prs), 1)
        opened = self.github.prs[0]
        self.assertEqual(opened["head"]["ref"], "review-bot/review/mail1")
        self.assertIn(ALICE, opened["title"])
        self.assertIn("`zz-9201` native", opened["body"])
        self.assertIn("`zz-9004` native", opened["body"])
        self.assertNotIn(SECRET, opened["body"])
        self.assertNotIn("cow's milk", opened["body"])
        self.assertNotIn("proposed", self.main_text())

        # The next run finds its PR, and merges it once the checks pass.
        self.github.check = "passed"
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "merged")
        self.assertEqual(len(self.github.prs), 1)
        self.assertIn("proposed:", self.main_text())
        self.assertIn("proposed:", self.main_text("decks/zz/en/zz-en-home.yaml"))
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "merged")
        self.assertEqual(len(self.github.prs), 1)
        self.assertEqual(self.git.pushes, ["review-bot/review/mail1"])

    def test_failed_checks_are_left_open_and_labelled_once(self) -> None:
        self.github.check = "failed"
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "failed")
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "failed")
        names = [lb["name"] for lb in self.github.prs[0]["labels"]]
        self.assertEqual(names.count(rb.FAILED_LABEL), 1)
        self.assertEqual(self.github.prs[0]["state"], "open")

    def test_nothing_to_propose_opens_nothing(self) -> None:
        review = rb.read_review([review_file([
            suggestion("zz-9201", "meaning", "milkk", "cow's milk")])], ALICE)
        self.assertEqual(self.bot.review("mail2", ALICE, review), "nothing")
        self.assertEqual(self.github.prs, [])

    def test_a_change_that_does_not_validate_is_not_pushed(self) -> None:
        self.git.invalid = True
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "invalid")
        self.assertEqual(self.github.prs, [])
        self.assertEqual(self.git.pushes, [])

    def test_a_closed_pr_is_never_opened_again(self) -> None:
        self.github.check = "pending"
        self.bot.review("mail1", ALICE, self.review())
        self.github.close(1, "no")
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "closed")
        self.assertEqual(len(self.github.prs), 1)

    def test_behind_main_it_is_built_again_from_main(self) -> None:
        self.github.dirty = 1
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "pending")
        self.assertEqual(self.git.pushes, ["review-bot/review/mail1"] * 2)
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "merged")

    def test_a_review_with_nothing_to_propose_logs_what_was_left(self) -> None:
        review = rb.read_review([review_file([
            suggestion("zz-9201", "meaning", "milkk", SECRET),
            suggestion("zz-9201", "example", "x", SECRET),
            suggestion("zz-9004", "meaning", "mother", "mother")])], ALICE)
        self.assertEqual(self.bot.review("mail2", ALICE, review), "nothing")
        line = self.logged[-1]
        self.assertIn(f"Review by {ALICE}: 2 suggestion(s) left for the owner, "
                      f"1 outdated", line)
        self.assertIn("the PR: nothing", line)
        self.assertNotIn(SECRET, " ".join(self.logged))

    def test_a_head_is_merged_at_the_sha_its_checks_passed_on(self) -> None:
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "merged")
        self.assertEqual(self.github.merged_at, [self.github.prs[0]["head"]["sha"]])

    def test_no_checks_for_long_is_logged(self) -> None:
        self.github.check = "missing"
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "pending")
        self.assertFalse(any("checks" in line for line in self.logged))
        self.github.prs[0]["updated_at"] = "2026-01-01T00:00:00Z"
        self.assertEqual(self.bot.review("mail1", ALICE, self.review()), "pending")
        self.assertIn("none of the required checks has started", self.logged[-1])

    def test_an_acceptance_is_recorded_by_the_reviewers_pr(self) -> None:
        p = self.p()
        self.put_on_main(p)
        review = rb.read_review([review_file([{
            "card": "zz-9201", "at": "2026-10-09T09:40:00.000Z",
            "proposals": [{"id": p.id, "answer": "accept", "field": "native",
                           "text": p.text}]}], code=BOB)], BOB)
        self.assertEqual(self.bot.review("mail3", BOB, review), "merged")
        self.assertIn(f'accepted: ["{BOB}"]', self.main_text())
        self.assertIn(f"{BOB} accepts: `{p.id}`", self.github.prs[0]["body"])


class Agreement(Base):
    def test_enough_acceptances_apply_the_change_and_close_its_rivals(self) -> None:
        win = self.p(accepted=(BOB,))
        rival = self.p(text="milk (cow's)", by=BOB)
        for p in (win, rival):
            self.put_on_main(p)
        counts = self.bot.sweep()
        self.assertEqual(counts["applied"], 1)
        text = self.main_text()
        self.assertIn('native: "cow\'s milk"', text)
        self.assertNotIn("proposed", text)
        body = self.github.prs[0]["body"]
        self.assertIn(f"Proposed by {ALICE}", body)
        self.assertIn(f"Accepted by {BOB}", body)
        self.assertIn(f"`{rival.id}` by {BOB}", body)
        self.assertEqual(self.github.prs[0]["head"]["ref"], rb.apply_branch(win))
        self.assertEqual(rb.apply_branch(win), f"review-bot/apply/{win.id}-2026-10-09")
        # Again: nothing left, nothing opened.
        self.bot.sweep()
        self.assertEqual(len(self.github.prs), 1)

    def test_fewer_acceptances_than_needed_wait(self) -> None:
        self.put_on_main(self.p(accepted=(BOB,)))
        counts = self.make_bot(2).sweep()
        self.assertEqual(counts["applied"], 0)
        self.assertEqual(self.github.prs, [])

    def test_while_its_checks_run_a_rerun_opens_nothing_more(self) -> None:
        self.github.check = "pending"
        self.put_on_main(self.p(accepted=(BOB,)))
        self.put_on_main(self.p(text="milk (cow's)", by=BOB, accepted=(ALICE,)))
        self.bot.sweep()
        self.bot.sweep()
        self.assertEqual(len(self.github.prs), 1)

    def test_when_the_owner_closes_the_winner_the_next_goes(self) -> None:
        self.github.check = "pending"
        first = self.p(accepted=(BOB,))
        second = self.p(text="milk (cow's)", by=BOB, accepted=(ALICE,))
        self.put_on_main(first)
        self.put_on_main(second)
        self.bot.sweep()
        self.github.close(1, "no")
        self.github.check = "passed"
        self.bot.sweep()
        self.assertEqual(self.github.prs[-1]["head"]["ref"], rb.apply_branch(second))
        self.assertIn('native: "milk (cow\'s)"', self.main_text())

    def accept_on_main(self, p: pr.Proposal, code: str) -> None:
        result = pr.Proposed()
        pr.accept(self.git.main, "zz", p.id, code, p.text, result)
        self.assertEqual(result.accepted, [(p.id, code)])

    def test_the_first_to_reach_the_agreement_wins_not_the_first_in_the_file(self) -> None:
        self.github.check = "pending"
        earlier = self.p(text="milk (cow's)", by=BOB)
        later = self.p(accepted=(BOB,))
        self.put_on_main(earlier)
        self.put_on_main(later)
        self.bot.sweep()
        self.assertEqual([p["head"]["ref"] for p in self.github.prs],
                         [rb.apply_branch(later)])
        # The earlier one reaches it too while the later's PR is open.
        self.accept_on_main(earlier, ALICE)
        self.github.check = "passed"
        self.bot.sweep()   # main moved: the open PR is built again
        self.bot.sweep()
        self.assertEqual([p["head"]["ref"] for p in self.github.prs],
                         [rb.apply_branch(later)])
        self.assertIn('native: "cow\'s milk"', self.main_text())
        self.assertNotIn("proposed", self.main_text())

    def test_two_open_for_one_field_keep_only_the_first(self) -> None:
        self.github.check = "pending"
        a = self.p(accepted=(BOB,))
        b = self.p(text="milk (cow's)", by=BOB, accepted=(ALICE,))
        self.put_on_main(a)
        self.put_on_main(b)
        # As an older run might have left them: both open.
        self.bot.apply("zz", b)
        self.bot.apply("zz", a)
        self.bot.sweep()
        self.assertEqual([p["state"] for p in self.github.prs], ["open", "closed"])

    def test_a_proposal_deleted_on_main_is_not_applied(self) -> None:
        self.github.check = "pending"
        p = self.p(accepted=(BOB,))
        self.put_on_main(p)
        self.bot.sweep()
        self.assertEqual(self.github.prs[0]["state"], "open")
        # The owner deletes the proposal: the open PR is closed, not merged.
        pr.close(self.git.main, "zz", [p.id])
        self.github.check = "passed"
        self.bot.sweep()
        self.assertEqual(self.github.prs[0]["state"], "closed")
        self.assertIn('native: "milk"', self.main_text())
        self.assertEqual(self.github.merged_at, [])

    def test_a_pr_built_on_an_older_main_is_built_again_before_merging(self) -> None:
        self.github.check = "pending"
        p = self.p(accepted=(BOB,))
        self.put_on_main(p)
        self.bot.sweep()
        other = self.git.main / "decks" / "zz" / "zz-en-extra.yaml"
        other.write_text(self.main_text().replace('native: "water"', 'native: "fresh water"'),
                         encoding="utf-8")
        self.github.check = "passed"
        self.bot.sweep()
        self.assertEqual(self.git.pushes, [rb.apply_branch(p)] * 2)
        self.assertEqual(self.github.merged_at, [])
        self.bot.sweep()
        text = self.main_text()
        self.assertIn('native: "cow\'s milk"', text)
        self.assertIn('native: "fresh water"', text)

    def test_the_same_proposal_made_again_later_is_applied_again(self) -> None:
        p = self.p(accepted=(BOB,))
        self.put_on_main(p)
        self.bot.sweep()
        self.assertIn('native: "cow\'s milk"', self.main_text())
        path = self.git.main / "decks" / "zz" / "zz-en-extra.yaml"
        path.write_text(self.main_text().replace('native: "cow\'s milk"', 'native: "milk"'),
                        encoding="utf-8")
        again = self.p(date="2026-10-20", accepted=(BOB,))
        self.assertEqual(again.id, p.id)
        self.put_on_main(again)
        self.bot.sweep()
        self.assertEqual(len(self.github.prs), 2)
        self.assertIn('native: "cow\'s milk"', self.main_text())

    def test_the_owners_revert_of_an_agreement_is_not_applied_again(self) -> None:
        p = self.p(accepted=(BOB,))
        self.put_on_main(p)
        before = self.main_text()
        self.bot.sweep()
        path = self.git.main / "decks" / "zz" / "zz-en-extra.yaml"
        path.write_text(before, encoding="utf-8")   # the revert
        self.bot.sweep()
        self.assertEqual(len(self.github.prs), 1)
        self.assertEqual(self.main_text(), before)

    def test_an_outdated_proposal_is_closed_not_applied(self) -> None:
        p = self.p(accepted=(BOB,))
        self.put_on_main(p)
        path = self.git.main / "decks" / "zz" / "zz-en-extra.yaml"
        path.write_text(self.main_text().replace('native: "milk"', 'native: "fresh milk"'),
                        encoding="utf-8")
        counts = self.bot.sweep()
        self.assertEqual(counts, {"applied": 0, "waiting": 0, "outdated": 1})
        self.assertEqual(len(self.github.prs), 1)
        self.assertTrue(self.github.prs[0]["head"]["ref"].startswith("review-bot/outdated/zz-"))
        self.assertIn(f"`{p.id}` on `zz-9201` native, by {ALICE}", self.github.prs[0]["body"])
        text = self.main_text()
        self.assertIn('native: "fresh milk"', text)
        self.assertNotIn("proposed", text)


def review_mail(files: list[dict], sender: str = "anvi@example.com",
                ident: str = "<one@example.com>") -> email.message.EmailMessage:
    message = email.message.EmailMessage()
    message["Subject"] = f"[Fluenough review] {ALICE} (zz)"
    message["From"] = f"Anvi <{sender}>"
    message["Message-ID"] = ident
    message.set_content("1 deck.")
    for data in files:
        message.add_attachment(json.dumps(data).encode("utf-8"),
                               maintype="application", subtype="json",
                               filename=f"fluenough-review-{data['deck']}.json")
    return message


class ProposingImap(FakeImap):
    """FakeImap that also takes the label a proposed mail gets."""

    def __init__(self, *args, **kw) -> None:
        super().__init__(*args, **kw)
        self.proposed: list[bytes] = []
        self.searches: list[tuple] = []

    def search(self, charset, *criteria):
        if self.selected == "INBOX":
            self.searches.append(criteria)
        return super().search(charset, *criteria)

    def store(self, number: bytes, command: str, label: str) -> None:
        if label == mail_to_issues.PROPOSED:
            self.proposed.append(number)
            return
        super().store(number, command, label)


class Mails(Base):
    def run_tool(self, imap: ProposingImap) -> tuple[list[dict], str]:
        filed: list[dict] = []
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            mail_to_issues.run(ENV, imap, filed.append, bot=self.bot)
        return filed, out.getvalue()

    def files(self) -> list[dict]:
        return [review_file([suggestion("zz-9201", "meaning", "milk", SECRET)])]

    def test_a_filed_review_is_proposed_and_labelled(self) -> None:
        imap = ProposingImap([review_mail(self.files())])
        filed, log = self.run_tool(imap)
        self.assertEqual(len(filed), 1)
        self.assertEqual(imap.proposed, [b"1"])
        self.assertIn("fluenough-filed -label:fluenough-proposed", imap.searches[-1][1])
        self.assertIn(SECRET, self.main_text())
        self.assertIn("Review mails proposed: 1 merged.", log)
        self.assertIn("Agreed proposals: 0 merged, 0 waiting; 0 outdated.", log)
        for text in (log, str(filed), str(self.github.prs)):
            self.assertNotIn(SECRET, text)
            self.assertNotIn("anvi@example.com", text)
        self.assertEqual(self.github.prs[0]["head"]["ref"],
                         f"review-bot/review/{mail_to_issues.mail_key(review_mail([]))}")

    def test_a_pending_pr_leaves_the_mail_for_the_next_run(self) -> None:
        self.github.check = "pending"
        imap = ProposingImap([review_mail(self.files())])
        _, log = self.run_tool(imap)
        self.assertEqual(imap.proposed, [])
        self.assertIn("1 pending", log)

    def test_another_sender_is_left_to_the_owner(self) -> None:
        record = email.message.EmailMessage()
        record["Subject"] = ALICE
        record.set_content("first@example.com")
        imap = ProposingImap([review_mail(self.files(), sender="other@example.com")],
                             raters=[record.as_bytes()])
        filed, log = self.run_tool(imap)
        self.assertIn(mail_to_issues.SENDER_DIFFERS, filed[0]["labels"])
        self.assertEqual(imap.proposed, [b"1"])
        self.assertEqual(self.github.prs, [])
        self.assertIn("1 left to the owner", log)

    def test_unreadable_records_wait_for_the_next_run(self) -> None:
        imap = ProposingImap([review_mail(self.files())], label=False)
        _, log = self.run_tool(imap)
        self.assertEqual(imap.proposed, [])
        self.assertEqual(self.github.prs, [])
        self.assertIn("1 waiting for the sender check", log)

    def test_a_rejection_is_flagged_in_the_issue_without_text(self) -> None:
        files = [review_file([{"card": "zz-9201", "at": "2026-10-09T09:40:00.000Z",
                               "proposals": [{"id": "0123456789", "answer": "reject",
                                              "field": "native", "text": SECRET}]}])]
        imap = ProposingImap([review_mail(files)])
        filed, _ = self.run_tool(imap)
        issue = filed[0]
        self.assertIn(mail_to_issues.REJECTED, issue["labels"])
        self.assertIn("`0123456789` on `zz-9201`", issue["body"])
        self.assertIn("- Proposals rejected: 1", issue["body"])
        self.assertNotIn(SECRET, str(issue))

    def test_without_the_app_nothing_is_proposed(self) -> None:
        imap = ProposingImap([review_mail(self.files())])
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            mail_to_issues.run(ENV, imap, lambda issue: None)
        self.assertIn("GitHub App is not set up", out.getvalue())
        self.assertEqual(imap.proposed, [])
        self.assertEqual(len(imap.searches), 1)

    def test_a_failing_bot_does_not_stop_the_run(self) -> None:
        class Broken(rb.Bot):
            def review(self, *args):
                raise RuntimeError("git fetch failed (128)")

            def sweep(self):
                raise RuntimeError("git fetch failed (128)")
        self.bot = Broken(self.git, self.github, 1, self.logged.append)
        imap = ProposingImap([review_mail(self.files())])
        filed, log = self.run_tool(imap)
        self.assertEqual(len(filed), 1)
        self.assertEqual(imap.proposed, [])
        self.assertIn("RuntimeError: git fetch failed (128)", log)


class LocalGitAuth(unittest.TestCase):
    def test_a_failed_git_command_never_shows_the_token(self) -> None:
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, True)
        git = rb.LocalGit(tmp, "ghs_SECRETTOKEN", tmp / "work")
        with self.assertRaises(RuntimeError) as caught:
            git._git("fetch", "origin", "main", auth=True)
        self.assertNotIn("SECRETTOKEN", str(caught.exception))
        self.assertNotIn("basic", str(caught.exception))
        self.assertEqual(str(caught.exception), "git fetch failed (128)")


if __name__ == "__main__":
    unittest.main()
