#!/usr/bin/env python3
"""The revocation job (ADR-0058, W8): the work of a revoked reviewer key is
taken out of the decks, cards below the quorum are no longer settled, a file
tagged `reviewed` goes back to `unreviewed`, applied changes that only had
the quorum through the revoked reviewer are reverted, a clean run changes
nothing, and nothing public names a code beside a key.

Stdlib `unittest` plus PyYAML. Git and GitHub are fakes: a "decks-live" folder
in a temporary directory, and PRs in memory. The private binding store is the
`MemoryBindings` of W7, behind the interface the job reads. No network.
"""

from __future__ import annotations

import difflib
import hashlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
import review_bot as rb  # noqa: E402
import review_quorum as rq  # noqa: E402
import reviewer_binding as rbind  # noqa: E402
import reviewer_keys as rk  # noqa: E402
import revoke_reviewers as rv  # noqa: E402
from test_proposals import ALICE, BOB  # noqa: E402
from test_review_bot import Base as BotBase, FakeGitHub as BotGitHub  # noqa: E402
import review_bot  # noqa: E402

CAROL = "FL-1111-1111-1"
DAVE = "FL-2222-2222-2"
KEY_ID = "0123456789abcdef"

HEAD = '''schema: 1
id: "{id}"
name: "Test"
language: {{ code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }}
native: {{ code: "en", iso639_3: "eng", name: "English" }}
license: "CC-BY-SA-4.0"
tags: ["{tag}"]
cards:
'''


def card(cid: str, native: str = "milk", extra: tuple[str, ...] = ()) -> str:
    lines = [f'  - id: "{cid}"', '    target: "పాలు"', '    reading: "pālu"',
             f'    native: "{native}"', *extra]
    return "\n".join(lines) + "\n"


def checked(*codes: str) -> str:
    return "    " + pr.checked_line(list(codes))


def deck(deck_id: str, tag: str, *cards: str) -> str:
    return HEAD.format(id=deck_id, tag=tag) + "".join(cards)


def proposal(**kw) -> pr.Proposal:
    facts = dict(card="zz-9201", field="native", now="milk", text="cow's milk",
                 by=ALICE, date="2026-11-01")
    facts.update(kw)
    return pr.Proposal(**facts)


# The first deck: four cards of different kinds of work by ALICE, the revoked
# code, and a tag that says every facet is at the quorum.
BY_ALICE = proposal()
ACCEPTED_BY_ALICE = proposal(field="reading", now="pālu", text="pālū", by=BOB,
                             accepted=(ALICE, CAROL))
FACETS = {
    "word": {"by": [ALICE, BOB], "flags": []},
    "reading": {"by": [ALICE, BOB], "flags": []},
    "meaning": {"by": [BOB, CAROL],
                "flags": [{"by": ALICE, "tags": ["spelling_wrong"], "fix": ""}]},
    "unit": {"by": [BOB, CAROL], "flags": []},
}


def main_deck() -> str:
    return deck(
        "zz-test", "reviewed",
        card("zz-9201", extra=(checked(ALICE, BOB), "    proposed:",
                               "      " + BY_ALICE.line(),
                               "      " + ACCEPTED_BY_ALICE.line())),
        card("zz-9202", extra=(checked(ALICE, BOB, CAROL),)),
        card("zz-9203", extra=(checked(BOB), "    " + pr.facet_checks_line(FACETS))),
        card("zz-9204", extra=(checked(BOB, CAROL),)),
    )


class FakeGit:
    """`decks-live` is a folder (called main here); a branch is a copy of it,
    kept when pushed. [patches] are the diffs the fake commits made."""

    def __init__(self, tmp: Path) -> None:
        self.tmp = tmp
        self.main = tmp / "main"
        (self.main / "decks" / "zz").mkdir(parents=True)
        self.branches: dict[str, dict[str, str]] = {}
        self.commits: dict[str, list[str]] = {}
        self.pushes: list[str] = []
        self.patches: dict[str, bytes] = {}
        self.valid_ok = True
        self.msgs: dict[Path, list[str]] = {}
        self.last: dict[Path, dict[str, str]] = {}
        self.start: dict[Path, dict[str, str]] = {}
        self.changed: dict[str, dict[str, str]] = {}
        self.made = 0

    def write(self, name: str, text: str) -> Path:
        path = self.main / "decks" / "zz" / name
        path.write_text(text, encoding="utf-8")
        return path

    @staticmethod
    def snapshot(root: Path) -> dict[str, str]:
        return {p.relative_to(root).as_posix(): p.read_text(encoding="utf-8")
                for p in sorted((root / "decks").rglob("*.yaml"))}

    def fresh(self, branch: str) -> Path:
        self.made += 1
        root = self.tmp / f"work{self.made}"
        shutil.copytree(self.main, root)
        self.msgs[root] = []
        self.last[root] = self.snapshot(root)
        self.start[root] = dict(self.last[root])
        return root

    def commit(self, root: Path, message: str) -> bool:
        snap = self.snapshot(root)
        if snap == self.last[root]:
            return False
        self.last[root] = snap
        self.msgs[root].append(message)
        return True

    def reindex(self, root: Path) -> None:
        pass

    def valid(self, root: Path, langs: list[str]) -> bool:
        return self.valid_ok

    def publish(self, root: Path, branch: str) -> str:
        if not self.msgs[root]:
            return "empty"
        snap = self.snapshot(root)
        if self.branches.get(branch) == snap:
            return "unchanged"
        self.branches[branch] = snap
        self.changed[branch] = {rel: text for rel, text in snap.items()
                                if self.start[root].get(rel) != text}
        self.commits[branch] = list(self.msgs[root])
        self.pushes.append(branch)
        return "pushed"

    def patch_of(self, sha: str) -> bytes | None:
        return self.patches.get(sha)

    def apply_reverse(self, root: Path, patch: bytes) -> bool:
        for flags in (["--check"], []):
            done = subprocess.run(["git", "apply", "-R", *flags, "-"], cwd=root,
                                  input=patch, capture_output=True, check=False)
            if done.returncode != 0:
                return False
        return True

    def merge(self, branch: str) -> None:
        """What the branch changed, as a merge brings it."""
        for rel, text in self.changed[branch].items():
            (self.main / rel).write_text(text, encoding="utf-8")


class FakeGitHub:
    def __init__(self) -> None:
        self.prs: list[dict] = []
        self.closed: list[int] = []

    def find_pr(self, branch: str) -> dict | None:
        found = [p for p in self.prs if p["head"]["ref"] == branch]
        return found[-1] if found else None

    def open_pr(self, branch: str, title: str, body: str, labels: list[str]) -> dict:
        made = {"number": 100 + len(self.prs), "state": "open", "merged_at": None,
                "head": {"ref": branch}, "title": title, "body": body,
                "labels": list(labels)}
        self.prs.append(made)
        return made

    def update_pr(self, number: int, title: str, body: str) -> None:
        pr_ = next(p for p in self.prs if p["number"] == number)
        pr_.update(title=title, body=body)

    def close(self, number: int, comment: str) -> None:
        next(p for p in self.prs if p["number"] == number)["state"] = "closed"
        self.closed.append(number)

    def merge(self, branch: str) -> None:
        found = self.find_pr(branch)
        found.update(state="closed", merged_at="2026-11-21T12:00:00Z")


class FakeLedger:
    def __init__(self, changes: list[rv.Change] | None = None) -> None:
        self.changes = changes or []

    def applied(self, codes: frozenset[str]) -> list[rv.Change]:
        return list(self.changes)


class Base(unittest.TestCase):
    def setUp(self) -> None:
        rq.set_tiers({})
        self.addCleanup(rq.set_tiers, {})
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.git = FakeGit(self.tmp)
        self.github = FakeGitHub()
        self.logged: list[str] = []
        self.ledger = FakeLedger()

    def job(self) -> rv.Revocation:
        return rv.Revocation(self.git, self.github, self.ledger, self.logged.append,
                             branch_key=b"test key")

    def text(self, name: str = "zz-test.yaml") -> str:
        return (self.git.main / "decks" / "zz" / name).read_text(encoding="utf-8")

    def entry(self, root: Path, cid: str) -> pr.Entry:
        return pr.entries(root, "zz", cid)[0]

    def everything_public(self) -> str:
        """All the text a run made public: PRs, branches, commits and log."""
        parts = [self.logged, self.git.branches.keys(), self.git.pushes,
                 *self.git.commits.values()]
        out = ["\n".join(map(str, p)) for p in parts]
        for p in self.github.prs:
            out += [p["title"], p["body"], p["head"]["ref"], *p["labels"]]
        return "\n".join(out)


class Stripping(Base):
    def setUp(self) -> None:
        super().setUp()
        self.git.write("zz-test.yaml", main_deck())
        # Tagged reviewed, and ALICE is one of three on every card: it stays.
        self.git.write("zz-keep.yaml", deck(
            "zz-keep", "reviewed",
            card("zz-9301", extra=(checked(ALICE, BOB, CAROL),))))
        # Tagged reviewed and does not name ALICE: not touched.
        self.git.write("zz-clean.yaml", deck(
            "zz-clean", "reviewed",
            card("zz-9401", extra=(checked(BOB, CAROL),))))

    def strip(self) -> rv.Removal:
        return rv.strip_codes(self.git.main, frozenset({ALICE}))

    def test_the_work_of_a_revoked_code_leaves_the_decks(self) -> None:
        result = self.strip()
        root = self.git.main
        # Sign-offs.
        self.assertEqual(pr.checked_by(self.entry(root, "zz-9201")), [BOB])
        self.assertEqual(pr.checked_by(self.entry(root, "zz-9202")), [BOB, CAROL])
        self.assertEqual(pr.checked_by(self.entry(root, "zz-9204")), [BOB, CAROL])
        # Facet answers: their "right" and their flag.
        held = pr.facet_data(self.entry(root, "zz-9203"))
        self.assertEqual(held["word"], {"by": [BOB], "flags": []})
        self.assertEqual(held["reading"], {"by": [BOB], "flags": []})
        self.assertEqual(held["meaning"], {"by": [BOB, CAROL], "flags": []})
        # Proposals: theirs withdrawn, their acceptance of another's dropped.
        left = self.entry(root, "zz-9201").proposals()
        self.assertEqual(left, [proposal(
            field="reading", now="pālu", text="pālū", by=BOB, accepted=(CAROL,))])
        self.assertNotIn(ALICE, self.text())
        self.assertNotIn(ALICE, self.text("zz-keep.yaml"))
        self.assertEqual((result.entries, result.removed, result.trimmed),
                         (4, 1, 1))
        self.assertEqual(result.unsupported, [])

    def test_a_card_that_falls_below_the_quorum_is_no_longer_settled(self) -> None:
        root = self.git.main
        self.assertTrue(pr.facets_settled(self.entry(root, "zz-9201")))
        self.assertTrue(pr.facets_settled(self.entry(root, "zz-9202")))
        result = self.strip()
        self.assertFalse(pr.facets_settled(self.entry(root, "zz-9201")))
        # Two others are left on it.
        self.assertTrue(pr.facets_settled(self.entry(root, "zz-9202")))
        # Only what was settled and no longer is: 9201. (9203 was contested.)
        self.assertEqual(result.below, 1)

    def test_a_reviewed_file_below_the_quorum_is_tagged_unreviewed_again(self) -> None:
        result = self.strip()
        self.assertIn('tags: ["unreviewed"]', self.text())
        self.assertNotIn('"reviewed"', self.text())
        self.assertEqual(result.retagged, ["zz-test"])
        # Still at the quorum without ALICE: its tag stays. Not touched: same.
        self.assertIn('tags: ["reviewed"]', self.text("zz-keep.yaml"))
        self.assertIn('tags: ["reviewed"]', self.text("zz-clean.yaml"))
        self.assertTrue(pr.all_checked(self.git.main / "decks" / "zz" / "zz-keep.yaml"))
        # Nothing else in the file changed but the tags line.
        self.assertIn("zz-test.yaml", {p.name for p in result.files})

    def test_a_clean_run_changes_nothing(self) -> None:
        self.strip()
        snapshot = self.git.snapshot(self.git.main)
        again = self.strip()
        self.assertFalse(again.changed)
        self.assertEqual(self.git.snapshot(self.git.main), snapshot)
        self.assertEqual((again.entries, again.removed, again.trimmed, again.retagged),
                         (0, 0, 0, []))

    def test_an_entry_that_cannot_be_edited_is_left_and_the_rest_cleaned(self) -> None:
        self.git.write("zz-odd.yaml", deck(
            "zz-odd", "unreviewed",
            card("zz-9501", extra=("    checked_by:", f'      - "{ALICE}"',
                                   f'      - "{BOB}"')),
            card("zz-9502", extra=(checked(ALICE, BOB),))))
        result = self.strip()
        self.assertEqual(result.unsupported, ["zz-9501"])
        self.assertEqual(pr.checked_by(self.entry(self.git.main, "zz-9502")), [BOB])
        # It terminates and says so again on the next run, with nothing written.
        before = self.git.snapshot(self.git.main)
        self.assertEqual(self.strip().unsupported, ["zz-9501"])
        self.assertEqual(self.git.snapshot(self.git.main), before)

    def test_the_code_is_matched_in_any_case(self) -> None:
        self.git.write("zz-case.yaml", deck(
            "zz-case", "unreviewed",
            card("zz-9601", extra=(checked(ALICE.lower(), BOB),))))
        rv.strip_codes(self.git.main, frozenset({rv.norm(ALICE)}))
        self.assertEqual(pr.checked_by(self.entry(self.git.main, "zz-9601")), [BOB])


class MarkUnreviewed(Base):
    def test_the_tags_line_is_the_only_change(self) -> None:
        path = self.git.write("zz-tags.yaml", deck("zz-tags", "reviewed", card("zz-9701"))
                              .replace('tags: ["reviewed"]',
                                       'tags: ["grammar", "reviewed"]  # kept'))
        before = path.read_text(encoding="utf-8")
        self.assertTrue(pr.mark_unreviewed(path))
        after = path.read_text(encoding="utf-8")
        self.assertEqual(after, before.replace('["grammar", "reviewed"]',
                                               '["grammar", "unreviewed"]'))
        # Not tagged reviewed any more: nothing to do, and the file is not written.
        self.assertFalse(pr.mark_unreviewed(path))
        self.assertEqual(path.read_text(encoding="utf-8"), after)

    def test_the_two_tags_are_each_others_reverse(self) -> None:
        path = self.git.write("zz-tags.yaml", deck("zz-tags", "unreviewed", card("zz-9701")))
        original = path.read_text(encoding="utf-8")
        self.assertTrue(pr.mark_reviewed(path))
        self.assertTrue(pr.mark_unreviewed(path))
        self.assertEqual(path.read_text(encoding="utf-8"), original)


class RemovalPr(Base):
    def setUp(self) -> None:
        super().setUp()
        self.git.write("zz-test.yaml", main_deck())

    def test_one_pr_that_names_no_reviewer_and_waits_for_the_owner(self) -> None:
        counts = self.job().run(frozenset({ALICE}))
        self.assertEqual(counts["removal prs"], 1)
        self.assertEqual(len(self.github.prs), 1)
        made = self.github.prs[0]
        self.assertEqual(made["head"]["ref"], "review-bot/revoke/clean-1")
        self.assertEqual(made["state"], "open")
        self.assertIn("revocation", made["labels"])
        self.assertIn("`zz-test`", made["body"])  # the file set unreviewed again
        for code in (ALICE, BOB, CAROL):
            self.assertNotIn(code, self.everything_public())
        # The branch holds the cleaned decks; the decks themselves are not changed here.
        self.assertNotIn(ALICE, self.git.branches[made["head"]["ref"]]
                         ["decks/zz/zz-test.yaml"])
        self.assertIn(ALICE, self.text())
        self.assertNotIn(KEY_ID, self.everything_public())

    def test_a_rerun_changes_nothing(self) -> None:
        self.job().run(frozenset({ALICE}))
        before = (list(self.git.pushes), [dict(p) for p in self.github.prs])
        self.job().run(frozenset({ALICE}))
        self.assertEqual(self.git.pushes, before[0])
        self.assertEqual(self.github.prs, before[1])

    def test_a_merged_pr_is_not_opened_again_and_a_later_revocation_gets_a_new_one(self) -> None:
        self.job().run(frozenset({ALICE}))
        branch = "review-bot/revoke/clean-1"
        self.git.merge(branch)
        self.github.merge(branch)
        # Clean now: nothing opened.
        self.job().run(frozenset({ALICE}))
        self.assertEqual(len(self.github.prs), 1)
        self.assertEqual(self.git.pushes, [branch])
        # Another code revoked later, with work in the decks: the next number.
        self.git.write("zz-more.yaml", deck(
            "zz-more", "unreviewed", card("zz-9801", extra=(checked(DAVE, BOB),))))
        self.job().run(frozenset({ALICE, DAVE}))
        self.assertEqual([p["head"]["ref"] for p in self.github.prs],
                         [branch, "review-bot/revoke/clean-2"])

    def test_a_pr_that_is_clean_by_other_means_is_closed(self) -> None:
        self.job().run(frozenset({ALICE}))
        # The owner cleaned the decks by hand instead of merging.
        self.git.merge("review-bot/revoke/clean-1")
        self.job().run(frozenset({ALICE}))
        self.assertEqual(self.github.prs[0]["state"], "closed")
        self.assertEqual(len(self.github.closed), 1)

    def test_an_open_pr_is_rebuilt_when_decks_live_moves(self) -> None:
        self.job().run(frozenset({ALICE}))
        self.git.write("zz-new.yaml", deck("zz-new", "unreviewed", card("zz-9901")))
        self.job().run(frozenset({ALICE}))
        self.assertEqual(self.git.pushes, ["review-bot/revoke/clean-1"] * 2)
        self.assertEqual(len(self.github.prs), 1)

    def test_no_revoked_code_and_a_code_in_no_deck_open_nothing(self) -> None:
        self.assertEqual(self.job().run(frozenset())["removal prs"], 0)
        self.assertEqual(self.job().run(frozenset({"FL-9999-9999-9"}))["removal prs"], 0)
        self.assertEqual(self.github.prs, [])
        self.assertEqual(self.git.pushes, [])

    def test_the_log_says_counts_only(self) -> None:
        self.job().run(frozenset({ALICE}))
        said = "\n".join(self.logged)
        self.assertIn("1 revoked code(s)", said)
        for secret in (ALICE, BOB, CAROL, KEY_ID, "zz-9201"):
            self.assertNotIn(secret, said)


class Failures(Base):
    """What cannot be done is never a quiet success."""

    def test_an_entry_that_cannot_be_edited_is_a_problem_not_a_clean_run(self) -> None:
        self.git.write("zz-odd.yaml", deck(
            "zz-odd", "unreviewed",
            card("zz-9501", extra=("    checked_by:", f'      - "{ALICE}"',
                                   f'      - "{BOB}"'))))
        counts = self.job().run(frozenset({ALICE}))
        self.assertEqual(counts["problems"], 1)
        self.assertEqual(self.github.prs, [])
        self.assertEqual(rv.leftovers(self.git.main, frozenset({ALICE})), ["zz-9501"])

    def test_a_branch_that_does_not_validate_is_a_problem(self) -> None:
        self.git.write("zz-test.yaml", main_deck())
        self.git.valid_ok = False
        counts = self.job().run(frozenset({ALICE}))
        self.assertEqual(counts["problems"], 1)
        self.assertEqual((self.github.prs, self.git.pushes), ([], []))

    def test_a_reviewed_tag_that_cannot_be_edited_is_reported(self) -> None:
        text = deck("zz-tagsblock", "reviewed",
                    card("zz-9601", extra=(checked(ALICE, BOB),))).replace(
            'tags: ["reviewed"]', 'tags:\n  - "reviewed"')
        self.git.write("zz-tagsblock.yaml", text)
        result = rv.strip_codes(self.git.main, frozenset({ALICE}))
        self.assertEqual(result.retag_failed, ["zz-tagsblock"])
        self.assertEqual(result.retagged, [])
        counts = self.job().run(frozenset({ALICE}))
        self.assertEqual(counts["problems"], 0)  # already stripped on main above
        # Fresh, through the job: the PR names the deck and the run fails.
        self.git.write("zz-tagsblock.yaml", text)
        counts = self.job().run(frozenset({ALICE}))
        self.assertEqual(counts["problems"], 1)
        self.assertIn("`zz-tagsblock`", self.github.prs[0]["body"])

    def test_a_proposal_that_cannot_be_edited_does_not_keep_a_signoff_in(self) -> None:
        p = proposal(card="zz-9701")
        block = ("    proposed:", f'      - id: "{p.id}"', f'        field: "{p.field}"',
                 f'        now: "{p.now}"', f'        text: "{p.text}"',
                 f'        by: "{p.by}"', f'        date: "{p.date}"')
        self.git.write("zz-mixed.yaml", deck(
            "zz-mixed", "unreviewed",
            card("zz-9701", extra=(checked(ALICE, BOB), *block))))
        result = rv.strip_codes(self.git.main, frozenset({ALICE}))
        self.assertEqual(pr.checked_by(self.entry(self.git.main, "zz-9701")), [BOB])
        self.assertEqual(result.unsupported, ["zz-9701"])
        self.assertEqual(rv.leftovers(self.git.main, frozenset({ALICE})), ["zz-9701"])


class FlowForm(Base):
    def test_a_card_written_on_one_line_is_cleaned(self) -> None:
        data = {"word": {"by": [ALICE, BOB], "flags": []},
                "meaning": {"by": [ALICE, BOB], "flags": []}}
        line = ('  - { id: "zz-9250", target: "పాలు", reading: "pālu", '
                f'native: "milk", checked_by: ["{ALICE}", "{BOB}"], '
                + pr.facet_checks_line(data) + " }\n")
        self.git.write("zz-flow.yaml", deck("zz-flow", "unreviewed") + line)
        result = rv.strip_codes(self.git.main, frozenset({ALICE}))
        entry = self.entry(self.git.main, "zz-9250")
        self.assertEqual(pr.checked_by(entry), [BOB])
        self.assertEqual(pr.facet_data(entry)["word"], {"by": [BOB], "flags": []})
        self.assertEqual(result.unsupported, [])
        self.assertNotIn(ALICE, self.text("zz-flow.yaml"))


class BotIgnoresRevoked(BotBase):
    """Until the removal PR merges, the review bot must not let a revoked code
    count, nor merge their work back (W8)."""

    def setUp(self) -> None:
        super().setUp()
        self.addCleanup(rq.set_revoked, ())

    def test_a_revoked_proposer_or_acceptor_does_not_reach_the_agreement(self) -> None:
        self.put_on_main(self.p(accepted=(BOB,)))
        for revoked in ({ALICE}, {BOB}, {ALICE, BOB}):
            self.bot.set_revoked(frozenset(revoked))
            self.assertEqual(self.bot.sweep()["applied"], 0)
            self.assertEqual(self.github.prs, [])
        self.bot.set_revoked(frozenset())
        self.assertEqual(self.bot.sweep()["applied"], 1)

    def test_an_open_agreement_pr_carrying_a_revoked_code_is_closed(self) -> None:
        self.put_on_main(self.p(accepted=(BOB,)))
        self.github.check = "pending"
        self.bot.sweep()
        self.assertEqual(self.github.prs[0]["state"], "open")
        self.bot.set_revoked(frozenset({BOB}))
        self.bot.sweep()
        self.assertEqual(self.github.prs[0]["state"], "closed")
        self.assertEqual(self.github.merged_at, [])

    def test_revocation_that_cannot_be_checked_applies_nothing(self) -> None:
        self.put_on_main(self.p(accepted=(BOB,)))
        self.bot.set_revoked(None)
        self.assertEqual(self.bot.sweep()["applied"], 0)
        self.assertEqual(self.bot.review("m", CAROL, rb.Review()), "held")
        self.assertEqual(self.github.prs, [])

    def test_a_revoked_reviewers_mail_makes_no_pr_and_closes_an_open_one(self) -> None:
        review = rb.Review(suggestions=[pr.Suggestion("zz", "zz-en-extra", self.p())])
        self.github.check = "pending"
        self.assertEqual(self.bot.review("m1", ALICE, review), "pending")
        self.bot.set_revoked(frozenset({ALICE}))
        self.assertEqual(self.bot.review("m1", ALICE, review), "held")
        self.assertEqual(self.github.prs[0]["state"], "closed")
        self.assertEqual(self.bot.review("m2", ALICE, review), "held")
        self.assertEqual(len(self.github.prs), 1)

    def test_a_revoked_check_does_not_settle_a_facet(self) -> None:
        checks = [(ALICE, "provisional"), (BOB, "provisional")]
        self.assertTrue(rq.facet_reached_quorum(checks))
        rq.set_revoked([ALICE.lower()])
        self.assertFalse(rq.facet_reached_quorum(checks))
        self.assertTrue(rq.facet_reached_quorum([*checks, (CAROL, "provisional")]))


class RealCommits(unittest.TestCase):
    """The revert, from a REAL apply commit made by `proposals.apply` in a real
    git repository, through `LocalRevokeGit`, then the bot's sweep."""

    def setUp(self) -> None:
        rq.set_tiers({})
        self.addCleanup(rq.set_revoked, ())

    def sh(self, *args: str, cwd: Path) -> str:
        done = subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t",
                               "-c", "commit.gpgsign=false", *args], cwd=cwd,
                              capture_output=True, text=True, check=True)
        return done.stdout.strip()

    def build(self, winner: pr.Proposal, rival: pr.Proposal) -> tuple[Path, str]:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        seed = self.tmp / "seed"
        (seed / "tools").mkdir(parents=True)
        (seed / "assets").mkdir()
        (seed / "tools" / "x.txt").write_text("x", encoding="utf-8")
        (seed / "assets" / "y.txt").write_text("y", encoding="utf-8")
        self.sh("init", "-q", "-b", "main", cwd=seed)
        self.sh("add", "--all", cwd=seed)
        self.sh("commit", "-q", "-m", "main", cwd=seed)
        self.sh("checkout", "-q", "-b", "decks-live", cwd=seed)
        path = seed / "decks" / "zz" / "zz-real.yaml"
        path.parent.mkdir(parents=True)
        path.write_text(deck("zz-real", "unreviewed", card(
            "zz-9201", extra=("    proposed:", "      " + winner.line(),
                              "      " + rival.line()))), encoding="utf-8")
        self.sh("add", "--all", cwd=seed)
        self.sh("commit", "-q", "-m", "deck", cwd=seed)
        applied = pr.apply(seed, "zz", winner.id)
        self.assertEqual(applied.outcome, "applied")
        self.assertIn('native: "cow\'s milk"', path.read_text(encoding="utf-8"))
        self.sh("add", "--all", cwd=seed)
        self.sh("commit", "-q", "-m", "apply", cwd=seed)
        sha = self.sh("rev-parse", "HEAD", cwd=seed)
        self.bare = self.tmp / "origin.git"
        self.sh("init", "-q", "--bare", "-b", "main", str(self.bare), cwd=self.tmp)
        self.sh("remote", "add", "origin", str(self.bare), cwd=seed)
        self.sh("push", "-q", "origin", "main", "decks-live", cwd=seed)
        self.sh("clone", "-q", str(self.bare), str(self.tmp / "clone"), cwd=self.tmp)
        return self.tmp / "clone", sha

    def git(self, clone: Path) -> "JobGit":
        work = self.tmp / "work"
        work.mkdir()
        return JobGit(clone, "token", work)

    def revert(self, winner: pr.Proposal, rival: pr.Proposal,
               codes: frozenset[str]) -> tuple[str, FakeGitHub, "JobGit"]:
        clone, sha = self.build(winner, rival)
        git = self.git(clone)
        github = FakeGitHub()
        change = rv.Change(7, sha, "zz-9201", "native",
                           (rv.Group(winner.by, tuple(winner.accepted)),))
        rv.Revocation(git, github, FakeLedger([change]), branch_key=b"k").run(codes)
        reverts = [p for p in github.prs if "/revert-" in p["head"]["ref"]]
        self.assertEqual(len(reverts), 1)
        branch = reverts[0]["head"]["ref"]
        text = self.sh("show", f"{branch}:decks/zz/zz-real.yaml", cwd=self.bare)
        # A commit for the revert and one for taking the codes out again.
        self.assertEqual(self.sh("rev-list", "--count", f"decks-live..{branch}",
                                 cwd=self.bare), "2")
        return text, github, git

    def test_a_proposer_revoked_the_winner_does_not_come_back(self) -> None:
        winner = proposal(accepted=(BOB,))
        rival = proposal(text="milk (cow's)", by=CAROL)
        text, github, git = self.revert(winner, rival, frozenset({ALICE}))
        self.assertIn('native: "milk"', text)
        self.assertNotIn(ALICE, text)
        self.assertNotIn(winner.id, text)
        # Their rival is restored: not the revoked reviewer's work.
        self.assertIn(rival.id, text)
        self.assertNotIn(ALICE, self.everything(github))

    def test_an_acceptor_revoked_the_winner_returns_without_their_code(self) -> None:
        winner = proposal(by=BOB, accepted=(ALICE,))
        rival = proposal(text="milk (cow's)", by=CAROL)
        text, github, git = self.revert(winner, rival, frozenset({ALICE}))
        self.assertIn('native: "milk"', text)
        self.assertNotIn(ALICE, text)
        # It waits for another speaker, with no acceptance left.
        self.assertIn(winner.id, text)
        self.assertNotIn("accepted", text)

    def test_a_rerun_pushes_nothing_when_the_tree_is_the_same(self) -> None:
        winner = proposal(accepted=(BOB,))
        rival = proposal(text="milk (cow's)", by=CAROL)
        clone, sha = self.build(winner, rival)
        git = self.git(clone)
        change = rv.Change(7, sha, "zz-9201", "native", (rv.Group(ALICE, (BOB,)),))
        github = FakeGitHub()
        job = rv.Revocation(git, github, FakeLedger([change]), branch_key=b"k")
        job.run(frozenset({ALICE}))
        branch = github.prs[0]["head"]["ref"]
        first = self.sh("rev-parse", branch, cwd=self.bare)
        job.run(frozenset({ALICE}))
        self.assertEqual(self.sh("rev-parse", branch, cwd=self.bare), first)
        self.assertEqual(len(github.prs), 1)
        self.assertEqual(git.patch_of("0" * 40), None)
        self.assertTrue(rv.patch_files(git.patch_of(sha)))
        self.assertEqual(rv.lang_of_patch(git.patch_of(sha)), "zz")

    def everything(self, github: "FakeGitHub") -> str:
        return "\n".join(f"{p['title']}\n{p['body']}" for p in github.prs)

    def test_after_the_revert_the_sweep_does_not_apply_it_again(self) -> None:
        winner = proposal(by=BOB, accepted=(ALICE,))
        rival = proposal(text="milk (cow's)", by=CAROL)
        _, github, git = self.revert(winner, rival, frozenset({ALICE}))
        branch = github.prs[0]["head"]["ref"]
        self.sh("update-ref", "refs/heads/decks-live", f"refs/heads/{branch}",
                cwd=self.bare)
        bot_github = BotGitHub(git)
        bot = review_bot.Bot(git, bot_github, 1, lambda _: None)
        bot.set_revoked(frozenset({ALICE}))
        self.assertEqual(bot.sweep()["applied"], 0)
        self.assertEqual(bot_github.prs, [])


class JobGit(rv.LocalRevokeGit):
    """The real git of the job, with the index tool and validator left out."""
    ok = True

    def reindex(self, root: Path) -> None:
        pass

    def valid(self, root: Path, langs: list[str]) -> bool:
        return self.ok


def diff_of(name: str, old: str, new: str) -> bytes:
    """What a commit that changed [name] from [old] to [new] is, as a patch."""
    return "".join(difflib.unified_diff(
        old.splitlines(keepends=True), new.splitlines(keepends=True),
        f"a/decks/zz/{name}", f"b/decks/zz/{name}")).encode("utf-8")


class Reverts(Base):
    """Applied changes. The deck holds each change's new text; the patch of
    the commit that made it goes back to the old text."""

    def add(self, number: int, groups: tuple[rv.Group, ...]) -> rv.Change:
        name = f"zz-c{number}.yaml"
        cid = f"zz-{number:04d}"
        old = deck(f"zz-c{number}", "unreviewed", card(cid, native="milk"))
        new = deck(f"zz-c{number}", "unreviewed", card(cid, native="cow's milk"))
        self.git.write(name, new)
        self.git.patches[f"sha{number}"] = diff_of(name, old, new)
        change = rv.Change(number, f"sha{number}", cid, "native", groups)
        self.ledger.changes.append(change)
        return change

    def setUp(self) -> None:
        super().setUp()
        self.lost = self.add(11, (rv.Group(ALICE, (BOB,)),))
        # Three agree and ALICE is one: the quorum holds without them.
        self.kept = self.add(12, (rv.Group(BOB, (CAROL, ALICE)),))
        # The record does not say who accepted what came with the word.
        self.unknown = self.add(13, (rv.Group(BOB, (CAROL,)), rv.Group(ALICE, None)))
        # A second revoked code, and one change both are in.
        self.second = self.add(14, (rv.Group(DAVE, (BOB,)),))
        self.both = self.add(15, (rv.Group(ALICE, (DAVE,)),))
        self.codes = frozenset({ALICE, DAVE})

    def reverts(self) -> list[dict]:
        return [p for p in self.github.prs if "/revert-" in p["head"]["ref"]]

    def test_one_revert_pr_for_each_revoked_code_with_a_commit_for_each_change(self) -> None:
        counts = self.job().run(self.codes)
        self.assertEqual(counts["revert prs"], 2)
        self.assertEqual(counts["changes to revert"], 3)
        self.assertEqual(counts["changes unknown"], 1)
        prs = self.reverts()
        self.assertEqual(len(prs), 2)
        self.assertEqual(len({p["head"]["ref"] for p in prs}), 2)
        # Each change is in exactly one PR, with a commit of its own.
        listed = [n for p in prs for n in rv.reverted_numbers(p["body"])]
        self.assertEqual(sorted(listed), [11, 14, 15])
        for p in prs:
            wanted = len(rv.reverted_numbers(p["body"]))
            self.assertEqual(len(self.git.commits[p["head"]["ref"]]), wanted)
            self.assertIn("revocation revert", p["labels"])
            self.assertEqual(p["state"], "open")
        # The old text is back on each PR's branch for its own changes, and the
        # others were never touched; decks-live itself is untouched.
        for p in prs:
            snap = self.git.branches[p["head"]["ref"]]
            ours = rv.reverted_numbers(p["body"])
            for number in (11, 12, 13, 14, 15):
                text = snap[f"decks/zz/zz-c{number}.yaml"]
                if number in ours:
                    self.assertIn('native: "milk"', text)
                else:
                    self.assertIn("cow's milk", text)
        for number in (11, 12, 13, 14, 15):
            self.assertIn("cow's milk", self.text(f"zz-c{number}.yaml"))
        for number in (12, 13):
            self.assertNotIn(number, listed)

    def test_only_what_fell_below_the_quorum_is_reverted(self) -> None:
        self.assertEqual(rv.verdict(self.lost, self.codes, "zz")[0], "revert")
        self.assertEqual(rv.verdict(self.kept, self.codes, "zz"), ("ok", ""))
        self.assertEqual(rv.verdict(self.unknown, self.codes, "zz"), ("unknown", ""))
        # Not one of them in the change: nothing to say.
        self.assertEqual(rv.verdict(self.lost, frozenset({CAROL}), "zz"), ("ok", ""))
        # The proposer alone, with nobody else's acceptance, was never enough.
        alone = rv.Change(1, "x", "zz-1", "native", (rv.Group(ALICE, ()),))
        self.assertEqual(rv.verdict(alone, self.codes, None)[0], "revert")

    def test_no_pr_names_a_reviewer(self) -> None:
        self.job().run(self.codes)
        public = self.everything_public()
        for secret in (ALICE, DAVE, BOB, CAROL, KEY_ID):
            self.assertNotIn(secret, public)
        # Branches are named by a keyed hash of the code: not the code, and not
        # a plain hash anyone can compute from the public codes.
        refs = " ".join(p["head"]["ref"] for p in self.reverts())
        for code in (ALICE, DAVE):
            self.assertNotIn(hashlib.sha256(code.encode()).hexdigest()[:10], refs)
            self.assertIn(self.job().branch_of(code), refs)
        self.assertNotEqual(rv.Revocation(self.git, self.github, self.ledger,
                                          branch_key=b"other").branch_of(ALICE),
                            self.job().branch_of(ALICE))

    def test_a_rerun_changes_nothing_and_a_merged_revert_is_not_made_again(self) -> None:
        self.job().run(self.codes)
        pushes, count = list(self.git.pushes), len(self.github.prs)
        self.job().run(self.codes)
        self.assertEqual((self.git.pushes, len(self.github.prs)), (pushes, count))
        for p in self.reverts():
            self.git.merge(p["head"]["ref"])
            self.github.merge(p["head"]["ref"])
        self.job().run(self.codes)
        self.assertEqual((self.git.pushes, len(self.github.prs)), (pushes, count))

    def test_a_revert_pr_the_owner_closed_is_a_decision(self) -> None:
        self.job().run(self.codes)
        count = len(self.github.prs)
        for p in self.reverts():
            p["state"] = "closed"
        self.job().run(self.codes)
        self.assertEqual(len(self.github.prs), count)

    def test_a_change_that_cannot_be_reversed_any_more_is_left_out_and_said(self) -> None:
        # The field was edited since: the patch no longer applies.
        self.git.write("zz-c11.yaml", self.text("zz-c11.yaml").replace(
            "cow's milk", "cow milk"))
        self.job().run(frozenset({ALICE}))
        prs = self.reverts()
        self.assertEqual(len(prs), 1)
        self.assertIn("Not reverted: 1", prs[0]["body"])
        self.assertEqual(rv.reverted_numbers(prs[0]["body"]), {15})

    def test_a_change_without_a_commit_on_decks_live_is_left_out(self) -> None:
        del self.git.patches["sha11"]
        self.job().run(frozenset({ALICE}))
        listed = {n for p in self.reverts() for n in rv.reverted_numbers(p["body"])}
        self.assertEqual(listed, {15})


class ReadingTheRecord(unittest.TestCase):
    BODY = (f"Proposal `abc123` on `zz-9201` reached the agreement needed (1) and "
            f"goes to learners.\n\n- Field: target\n- Proposed by {ALICE}\n"
            f"- Accepted by {BOB}, {CAROL}\n"
            f"- Applied with it, agreed: `def456` on reading, by {DAVE}\n\n"
            f"<sub>Opened by the review bot (ADR-0038).</sub>")

    def test_an_older_pr_is_read_from_its_visible_lines(self) -> None:
        got = rb.parse_applied(self.BODY)
        self.assertEqual((got["id"], got["card"], got["field"], got["by"]),
                         ("abc123", "zz-9201", "target", ALICE))
        self.assertEqual(got["accepted"], [BOB, CAROL])
        self.assertFalse(got["exact"])
        # Who accepted what came with the word is not in such a body.
        self.assertEqual(got["with"], [{"id": "def456", "field": "reading",
                                        "by": DAVE, "accepted": None}])

    def test_a_pr_with_the_hidden_record_is_read_from_it(self) -> None:
        p = proposal(card="zz-9201", field="target", accepted=(BOB,))
        body = "\n".join(["Proposal text.", "",
                          rb.applied_trailer(p, [{"id": "def456", "field": "reading",
                                                  "by": DAVE, "accepted": [CAROL]}]),
                          rb.FOOTER])
        got = rb.parse_applied(body)
        self.assertTrue(got["exact"])
        self.assertEqual((got["by"], got["accepted"]), (ALICE, [BOB]))
        self.assertEqual(got["with"][0]["accepted"], [CAROL])
        self.assertEqual(rb.parse_applied(rb.applied_trailer(p, []))["with"], [])

    def test_a_body_that_is_not_an_agreements_is_not_read(self) -> None:
        self.assertIsNone(rb.parse_applied("Review by FL-X, from the review mail."))
        self.assertIsNone(rb.parse_applied(""))
        self.assertIsNone(rv.change_of(1, "", self.BODY))

    def test_a_change_is_its_groups(self) -> None:
        change = rv.change_of(7, "sha", self.BODY)
        self.assertEqual(change.groups, (rv.Group(ALICE, (BOB, CAROL)),
                                         rv.Group(DAVE, None)))
        self.assertEqual((change.number, change.card, change.field),
                         (7, "zz-9201", "target"))

    def test_the_reverted_line_round_trips(self) -> None:
        self.assertEqual(rv.reverted_numbers(f"x\n{rv.REVERTED_MARK}3, 14 -->\ny"), {3, 14})
        self.assertEqual(rv.reverted_numbers("nothing"), set())
        self.assertEqual(rv.reverted_numbers(None), set())


class WhoIsRevoked(unittest.TestCase):
    RING = rk.Keyring({}, frozenset({KEY_ID}))

    def test_codes_come_from_the_private_store_for_the_revoked_ids_only(self) -> None:
        store = rbind.MemoryBindings()
        store.bind(KEY_ID, ALICE.lower(), "verified", ("zz",))
        store.bind("fedcba9876543210", BOB, "verified", ("zz",))
        self.assertEqual(rv.revoked_codes(self.RING, store), frozenset({ALICE}))

    def test_an_unreadable_store_revokes_nothing(self) -> None:
        self.assertIsNone(rv.revoked_codes(self.RING, rbind.MemoryBindings(ready=False)))

    def test_a_revoked_id_nobody_used_names_no_code(self) -> None:
        self.assertEqual(rv.revoked_codes(self.RING, rbind.MemoryBindings()), frozenset())

    def test_the_command_does_nothing_without_what_it_needs(self) -> None:
        # No denylist entry, or no secrets: either way it stops before any network.
        self.assertEqual(rv.main({}), 0)


if __name__ == "__main__":
    unittest.main()
