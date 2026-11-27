#!/usr/bin/env python3
"""The issue of a review mail is closed once the mail's PRs are done (owner,
2026-11-26). Stdlib `unittest`. GitHub is a fake: issues and PRs in memory.
No network."""

from __future__ import annotations

import contextlib
import io
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import close_review_issues as cri  # noqa: E402
import mail_to_issues  # noqa: E402
import test_review_bot as trb  # noqa: E402

KEY = "0123456789ab"
OTHER = "ba9876543210"
CODE = "FL-AAAA-BBBB-C"


def issue(number: int, key: str | None = KEY, *, title: str | None = None,
          labels: tuple[str, ...] = ("review", "from-app"),
          created: str = "2026-11-20T10:00:00Z", state: str = "open") -> dict:
    body = "A review came by mail."
    if key:
        body += "\n\n" + cri.marker(key)
    return {"number": number, "title": title or f"Review: {CODE} (te)",
            "body": body, "state": state, "created_at": created,
            "labels": [{"name": n} for n in labels]}


def pr(branch: str, state: str = "closed", merged: bool = True, *,
       title: str = f"Review proposals by {CODE}",
       created: str = "2026-11-21T10:00:00Z") -> dict:
    return {"number": 1, "title": title, "state": state,
            "merged_at": "2026-11-21T11:00:00Z" if merged else None,
            "created_at": created, "head": {"ref": branch}}


class FakeIssues:
    def __init__(self, issues: list[dict], prs: list[dict] | None = None) -> None:
        self.issues = issues
        self.prs = prs or []
        self.closed: list[tuple[int, str]] = []
        self.fail_prs = False

    def open_issues(self, label: str) -> list[dict]:
        return [i for i in self.issues if i["state"] == "open"
                and label in [lb["name"] for lb in i["labels"]]
                and "from-app" in [lb["name"] for lb in i["labels"]]]

    def find_pr(self, branch: str) -> dict | None:
        if self.fail_prs:
            raise RuntimeError("looking for the PR failed: 500")
        found = [p for p in self.prs if p["head"]["ref"] == branch]
        return found[-1] if found else None

    def bot_prs(self) -> list[dict]:
        return list(self.prs)

    def close(self, number: int, comment: str) -> None:
        target = next(i for i in self.issues if i["number"] == number)
        assert target["state"] == "open", "closed an issue twice"
        target["state"] = "closed"
        self.closed.append((number, comment))


def close(github: FakeIssues, outcomes: dict | None = None) -> dict[str, int]:
    logged: list[str] = []
    return cri.close_settled(github, outcomes, logged.append)


class Closing(unittest.TestCase):
    def test_closes_when_all_the_mails_prs_are_merged(self) -> None:
        github = FakeIssues([issue(1)], [
            pr(f"review-bot/review/{KEY}"),
            pr(f"review-bot/questions/{KEY}", title=f"Daily question answers by {CODE}")])
        self.assertEqual(close(github)["closed"], 1)
        self.assertEqual(github.closed, [(1, cri.COMMENT)])
        self.assertEqual(
            cri.COMMENT, "Closed by the review pipeline: all of this mail's "
                         "pull requests are merged or closed.")

    def test_a_pr_closed_without_merging_counts_as_done(self) -> None:
        github = FakeIssues([issue(1)], [
            pr(f"review-bot/review/{KEY}", merged=False)])
        self.assertEqual(close(github)["closed"], 1)

    def test_does_not_close_while_one_pr_is_open(self) -> None:
        github = FakeIssues([issue(1)], [
            pr(f"review-bot/review/{KEY}"),
            pr(f"review-bot/questions/{KEY}", state="open", merged=False)])
        counts = close(github)
        self.assertEqual((counts["closed"], counts["waiting"]), (0, 1))
        self.assertEqual(github.closed, [])

    def test_does_not_close_on_this_runs_pending_or_failed_outcome(self) -> None:
        for outcome in ("pending", "failed", "waiting for the sender check",
                        "left to the owner"):
            with self.subTest(outcome):
                github = FakeIssues([issue(1)], [pr(f"review-bot/review/{KEY}")])
                close(github, {KEY: {"review": outcome}})
                self.assertEqual(github.closed, [])

    def test_closes_when_there_was_nothing_to_propose(self) -> None:
        for outcome in ("nothing", "invalid", "closed", "merged"):
            with self.subTest(outcome):
                github = FakeIssues([issue(1)])
                close(github, {KEY: {"review": outcome}})
                self.assertEqual(len(github.closed), 1)

    def test_a_mail_with_no_pr_and_no_outcome_is_left_alone(self) -> None:
        github = FakeIssues([issue(1)])
        self.assertEqual(close(github)["waiting"], 1)
        self.assertEqual(github.closed, [])

    def test_closing_is_idempotent(self) -> None:
        github = FakeIssues([issue(1), issue(2, state="closed")],
                            [pr(f"review-bot/review/{KEY}")])
        close(github)
        again = close(github)
        self.assertEqual(again, {"closed": 0, "waiting": 0, "owner": 0})
        self.assertEqual(len(github.closed), 1)

    def test_only_the_finished_mails_issue_is_closed(self) -> None:
        github = FakeIssues([issue(1), issue(2, OTHER)], [
            pr(f"review-bot/review/{KEY}"),
            pr(f"review-bot/review/{OTHER}", state="open", merged=False)])
        close(github)
        self.assertEqual([n for n, _ in github.closed], [1])

    def test_a_questions_issue_is_closed_too(self) -> None:
        github = FakeIssues([issue(1, title=f"Questions: {CODE} (te)",
                                   labels=("questions", "from-app"))],
                            [pr(f"review-bot/questions/{KEY}")])
        self.assertEqual(close(github)["closed"], 1)

    def test_an_issue_the_owner_decides_is_never_closed(self) -> None:
        for mark in cri.OWNER_MARKS:
            with self.subTest(mark):
                github = FakeIssues(
                    [issue(1, labels=("review", "from-app", mark))],
                    [pr(f"review-bot/review/{KEY}")])
                self.assertEqual(close(github)["owner"], 1)
                self.assertEqual(github.closed, [])

    def test_a_github_error_leaves_the_issue_open_and_the_rest_go_on(self) -> None:
        github = FakeIssues([issue(1, OTHER), issue(2, title="Review: x")])
        github.fail_prs = True
        logged: list[str] = []
        counts = cri.close_settled(github, {}, logged.append)
        self.assertEqual(counts["waiting"], 2)
        self.assertTrue(all("warning" in line for line in logged))
        self.assertEqual(github.closed, [])

    def test_the_owner_marks_are_the_mail_tools(self) -> None:
        self.assertEqual(set(cri.OWNER_MARKS), {
            mail_to_issues.CHECK_FILES, mail_to_issues.SENDER_DIFFERS,
            mail_to_issues.HELD, mail_to_issues.SENDER_UNCHECKED})
        self.assertEqual(set(cri.LABELS), {mail_to_issues.REVIEW,
                                           mail_to_issues.QUESTIONS})
        self.assertEqual(cri.FROM_APP, mail_to_issues.FROM_APP)

    def test_the_key_is_read_back_from_the_body(self) -> None:
        self.assertEqual(cri.key_in(issue(1)["body"]), KEY)
        self.assertIsNone(cri.key_in(issue(1, None)["body"]))
        self.assertIsNone(cri.key_in(None))


class Backfill(unittest.TestCase):
    """Issues filed before the key was written into them."""

    def test_an_old_issue_whose_codes_prs_are_all_done_is_closed(self) -> None:
        github = FakeIssues([issue(1, None)], [
            pr(f"review-bot/review/{OTHER}", created="2026-11-21T10:00:00Z")])
        self.assertEqual(close(github)["closed"], 1)
        self.assertEqual(github.closed, [(1, cri.COMMENT)])

    def test_an_open_pr_of_the_code_keeps_it_open(self) -> None:
        github = FakeIssues([issue(1, None)], [
            pr(f"review-bot/review/{OTHER}"),
            pr(f"review-bot/review/{KEY}", state="open", merged=False)])
        close(github)
        self.assertEqual(github.closed, [])

    def test_a_pr_older_than_the_issue_does_not_close_it(self) -> None:
        # The issue's own mail may not have been proposed yet.
        github = FakeIssues([issue(1, None, created="2026-11-25T10:00:00Z")],
                            [pr(f"review-bot/review/{OTHER}")])
        close(github)
        self.assertEqual(github.closed, [])

    def test_another_codes_prs_do_not_count(self) -> None:
        github = FakeIssues([issue(1, None)], [
            pr(f"review-bot/review/{OTHER}", title="Review proposals by FL-ZZZZ-ZZZZ-Z")])
        close(github)
        self.assertEqual(github.closed, [])

    def test_an_old_issue_with_no_pr_stays_open(self) -> None:
        github = FakeIssues([issue(1, None)])
        close(github)
        self.assertEqual(github.closed, [])


class EndToEnd(trb.Base):
    """A review mail through the tool with the fake bot: the issue it files
    carries the mail's key, and is closed once the bot has merged the PR."""

    def run_tool(self, imap, issues: FakeIssues) -> list[dict]:
        filed: list[dict] = []

        def file_issue(found: dict) -> None:
            filed.append(found)
            issues.issues.append(
                {**found, "number": len(filed), "state": "open",
                 "created_at": "2026-11-20T10:00:00Z",
                 "labels": [{"name": n} for n in found["labels"]]})
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            mail_to_issues.run(trb.ENV, imap, file_issue, bot=self.bot,
                               closer=issues)
        self.log = out.getvalue()
        return filed

    def files(self) -> list[dict]:
        return [trb.review_file([trb.suggestion(
            "zz-9201", "meaning", "milk", trb.SECRET)])]

    def test_the_issue_is_closed_when_the_bot_merges_the_pr(self) -> None:
        issues = FakeIssues([])
        imap = trb.ProposingImap([trb.review_mail(self.files())])
        filed = self.run_tool(imap, issues)
        key = mail_to_issues.mail_key(trb.review_mail([]))
        self.assertIn(cri.marker(key), filed[0]["body"])
        self.assertNotIn(trb.SECRET, filed[0]["body"])
        self.assertEqual([n for n, _ in issues.closed], [1])
        self.assertIn("Review issues: 1 closed", self.log)

    def test_the_issue_stays_open_while_the_pr_is_pending(self) -> None:
        self.github.check = "pending"
        issues = FakeIssues([])
        self.run_tool(trb.ProposingImap([trb.review_mail(self.files())]), issues)
        self.assertEqual(issues.closed, [])
        self.assertIn("1 waiting for their PRs", self.log)

    def test_a_pr_merged_between_runs_closes_the_issue_on_the_next(self) -> None:
        self.github.check = "pending"
        issues = FakeIssues([])
        self.run_tool(trb.ProposingImap([trb.review_mail(self.files())]), issues)
        self.assertEqual(issues.closed, [])
        # CI finishes and the bot merges the PR, in a run of its own.
        self.github.check = "passed"
        self.bot.github.merge(self.github.prs[0], self.github.prs[0]["head"]["sha"])
        issues.find_pr = self.github.find_pr
        self.run_tool(trb.ProposingImap([]), issues)
        self.assertEqual([n for n, _ in issues.closed], [1])


if __name__ == "__main__":
    unittest.main()
