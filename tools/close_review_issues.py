#!/usr/bin/env python3
"""Closes the issue of a review mail once the mail's pull requests are done
(owner, 2026-11-26: "all such issues should be closed once merge happens via
the CI itself").

The mail workflow (`tools/mail_to_issues.py`) files one issue per review or
daily-questions mail, and the review bot (`tools/review_bot.py`, ADR-0038)
opens up to two PRs for it: `review-bot/review/<key>` for the proposals and
`review-bot/questions/<key>` for the answers. Nothing used to close the issue.

The link between the two is the mail's key, the name the bot already puts in
its branches. The workflow writes it into the issue's body as a hidden
comment, `<!-- fluenough-mail: <key> -->` (never shown, and no more than
the branch name says); a PR needs no change.

Every run, after the proposals, the open issues labelled `from-app` and
`review` (or `questions`) are looked at. An issue is closed, as completed,
with a one-line comment, when each of its mail's PRs is merged or closed (or
the mail had nothing to change, or its change did not validate) and none is
still open or waiting, and at least one PR or one such outcome is known. A
mail left to the owner (sender does not match, check the files, held for the
owner, sender not checked) is never closed here. Closing is by what GitHub
says each run, so it also catches a PR merged between runs, and closing an
issue twice cannot happen: closed issues are not listed.

Issues filed before this marker existed have no key. They are matched by the
rater code in their title: closed when every review-bot PR of that code is
merged or closed, at least one exists, and the newest was opened after the
issue was. A legacy mail that had nothing to propose stays open: nothing
records it.

Environment: GITHUB_TOKEN (the workflow's own: `issues: write` closes issues,
`pull-requests: read` reads the PRs) and GITHUB_REPOSITORY. Counts only in the
log: no title, no code, no mail address.
"""

from __future__ import annotations

import json
import re
import urllib.error
import urllib.request
from typing import Callable, Protocol

MARKER = "<!-- fluenough-mail: "
_MARKER = re.compile(re.escape(MARKER) + r"([0-9a-f]{12}) -->")
BRANCHES = {"review": "review-bot/review/",
            "questions": "review-bot/questions/"}
FROM_APP = "from-app"
LABELS = ("review", "questions")
# The outcomes of the bot's `job` that need nothing more from the owner.
DONE = ("merged", "closed", "nothing", "invalid")
# The issue labels that mean the owner decides (as in mail_to_issues).
OWNER_MARKS = ("check the files", "sender does not match",
               "held for the owner", "sender not checked")
COMMENT = ("Closed by the review pipeline: all of this mail's pull requests "
           "are merged or closed.")
TITLE_CODE = re.compile(r"^(?:Review|Questions): (\S+)")


def marker(key: str) -> str:
    """The hidden line that ties an issue to its mail's [key]."""
    return f"{MARKER}{key} -->"


def key_in(body: object) -> str | None:
    """The mail key written into an issue's [body], or None."""
    found = _MARKER.search(body if isinstance(body, str) else "")
    return found.group(1) if found else None


class Issues(Protocol):
    def open_issues(self, label: str) -> list[dict]: ...
    def find_pr(self, branch: str) -> dict | None: ...
    def bot_prs(self) -> list[dict]: ...
    def close(self, number: int, comment: str) -> None: ...


class RestIssues:
    """The REST API, with the workflow's own token."""

    def __init__(self, repo: str, token: str) -> None:
        self.repo, self.token = repo, token
        self.owner = repo.split("/")[0]

    def _call(self, method: str, path: str,
              body: dict | None = None) -> tuple[int, object]:
        request = urllib.request.Request(
            f"https://api.github.com/repos/{self.repo}{path}",
            data=json.dumps(body).encode("utf-8") if body is not None else None,
            method=method,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Accept": "application/vnd.github+json",
                "Content-Type": "application/json",
                "X-GitHub-Api-Version": "2022-11-28",
            })
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
                return response.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            raw = error.read()
            try:
                return error.code, json.loads(raw) if raw else None
            except ValueError:
                return error.code, None

    def _pages(self, path: str) -> list[dict]:
        out: list[dict] = []
        for page in range(1, 11):
            status, found = self._call("GET", f"{path}&per_page=100&page={page}")
            if status != 200 or not isinstance(found, list):
                raise RuntimeError(f"listing {path.split('?')[0]} failed: {status}")
            out += [i for i in found if isinstance(i, dict)]
            if len(found) < 100:
                break
        return out

    def open_issues(self, label: str) -> list[dict]:
        found = self._pages(f"/issues?state=open&labels={FROM_APP},{label}")
        return [i for i in found if "pull_request" not in i]

    def find_pr(self, branch: str) -> dict | None:
        status, found = self._call(
            "GET", f"/pulls?head={self.owner}:{branch}&state=all&per_page=10")
        if status != 200 or not isinstance(found, list):
            raise RuntimeError(f"looking for the PR of {branch} failed: {status}")
        return found[0] if found else None

    def bot_prs(self) -> list[dict]:
        """Every PR of the review bot's review and answer branches, any state."""
        return [p for p in self._pages("/pulls?state=all")
                if str((p.get("head") or {}).get("ref", "")).startswith(
                    tuple(BRANCHES.values()))]

    def close(self, number: int, comment: str) -> None:
        status, _ = self._call("PATCH", f"/issues/{number}", {
            "state": "closed", "state_reason": "completed"})
        if status != 200:
            raise RuntimeError(f"closing issue #{number} failed: {status}")
        # The comment is a courtesy: an issue already closed is not retried.
        self._call("POST", f"/issues/{number}/comments", {"body": comment})


def _pr_state(found: dict | None) -> str:
    if found is None:
        return "none"
    if found.get("merged_at") or found.get("state") == "closed":
        return "done"
    return "open"


def key_settled(github: Issues, key: str, outcomes: dict[str, str]) -> bool:
    """Whether the mail [key] is finished. [outcomes] are what this run's
    bot returned for the mail's parts ("review", "questions"); a part not in
    it is looked up by its PR. Finished: no part open or waiting, and at least
    one part done."""
    states = []
    for kind, prefix in BRANCHES.items():
        outcome = outcomes.get(kind)
        if outcome is not None:
            states.append("done" if outcome in DONE else "open")
        else:
            states.append(_pr_state(github.find_pr(f"{prefix}{key}")))
    return "open" not in states and "done" in states


def legacy_settled(issue: dict, prs: list[dict]) -> bool:
    """Whether an issue with no mail key is finished, by its rater code: see
    the module's text."""
    found = TITLE_CODE.match(str(issue.get("title", "")))
    if not found:
        return False
    mine = [p for p in prs if str(p.get("title", "")).endswith(f" by {found[1]}")]
    if not mine or any(_pr_state(p) != "done" for p in mine):
        return False
    newest = max(str(p.get("created_at", "")) for p in mine)
    return newest > str(issue.get("created_at", "9999"))


def close_settled(github: Issues,
                  outcomes: dict[str, dict[str, str]] | None = None,
                  log: Callable[[str], None] = print) -> dict[str, int]:
    """Closes every open review or questions issue whose mail is finished.
    [outcomes] are this run's, by mail key and part. Returns counts:
    "closed", "waiting" and "owner" (left to the owner)."""
    outcomes = outcomes or {}
    counts = {"closed": 0, "waiting": 0, "owner": 0}
    prs: list[dict] | None = None
    seen: set[int] = set()
    for label in LABELS:
        for issue in github.open_issues(label):
            number = issue.get("number")
            if not isinstance(number, int) or number in seen:
                continue
            seen.add(number)
            names = {lb.get("name") for lb in issue.get("labels", [])
                     if isinstance(lb, dict)}
            if names & set(OWNER_MARKS):
                counts["owner"] += 1
                continue
            try:
                key = key_in(issue.get("body"))
                if key is not None:
                    finished = key_settled(github, key, outcomes.get(key, {}))
                else:
                    if prs is None:
                        prs = github.bot_prs()
                    finished = legacy_settled(issue, prs)
                if finished:
                    github.close(number, COMMENT)
            except RuntimeError as error:
                log(f"::warning::Issue #{number} of a review mail: {error}")
                counts["waiting"] += 1
                continue
            counts["closed" if finished else "waiting"] += 1
    return counts
