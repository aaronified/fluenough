#!/usr/bin/env python3
"""The review bot: reviews become proposals, and agreement merges them
(ADR-0038, docs/plans/deck-browser.md, #441).

Run by `tools/mail_to_issues.py`, in the hourly mail workflow, once the
GitHub App that merges is set up. Three kinds of pull request, each on a
branch of its own under `review-bot/`, each started afresh from `main`:

- **A review's proposals** (`review-bot/review/<mail>`): each suggestion
  of one review mail becomes a proposal on its card, and each acceptance
  is recorded on the proposal it accepts. Merged as soon as the required
  checks pass.
- **An agreement** (`review-bot/apply/<proposal>`): once
  REVIEW_AGREEMENTS_NEEDED rater codes other than the proposer's have
  accepted a proposal, its text is written into the field, and it and the
  other proposals on that field are removed. Merged the same way.
- **Outdated proposals** (`review-bot/outdated/<language>-<ids>`):
  proposals whose field has changed since are removed.

The branch name comes from the mail or the proposals, so a rerun finds its
own PR instead of opening another; a PR the owner closed is never opened
again. A PR whose checks fail stays open for the owner. A PR that falls
behind `main` is built again from `main` and pushed over.

Every edit to a deck is made by `tools/proposals.py`, one line at a time;
the index is written by `tools/deck_index.py` and the language validated
by `tools/validate_decks.py` before anything is pushed.

What it logs and writes in PRs: rater codes, card ids, proposal ids,
counts and PR numbers. Never a mail address, and never a suggestion's
text, which reaches only the decks.

Environment, through `mail_to_issues.py`:
    FLUENOUGH_BOT_TOKEN  the App's installation token, made by the
        workflow from FLUENOUGH_BOT_APP_ID and FLUENOUGH_BOT_PRIVATE_KEY.
        Without it the bot does nothing and says so.
    REVIEW_AGREEMENTS_NEEDED  how many other reviewers must accept a
        proposal; 1 when unset or not a whole number of at least 1.
    GITHUB_TOKEN  the workflow's own token, to read check runs.
"""

from __future__ import annotations

import base64
import datetime
import hashlib
import json
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Protocol

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
from rater_codes import rater_code  # noqa: E402

PREFIX = "review-bot/"
LABEL = "review-bot"
KIND_LABELS = {
    "review": "proposals",
    "apply": "agreement",
    "outdated": "proposal outdated",
}
FAILED_LABEL = "review-bot: checks failed"
THRESHOLD = "REVIEW_AGREEMENTS_NEEDED"
FOOTER = ("<sub>Opened by the review bot (ADR-0038). The owner overrides it "
          "with any later commit: a revert, an edit, or a deleted proposal."
          "</sub>")


def agreements_needed(env: dict[str, str]) -> int:
    """How many other reviewers must accept a proposal: the variable, or 1
    when it is unset or not a whole number of at least 1."""
    raw = (env.get(THRESHOLD) or "").strip()
    try:
        value = int(raw)
    except ValueError:
        return 1
    return value if value >= 1 else 1


# --- What review files say -----------------------------------------------------

@dataclass
class Review:
    """What a mail's review files ask of the bot, by one rater code."""
    suggestions: list[pr.Suggestion] = field(default_factory=list)
    # (language, proposal id, text accepted)
    accepts: list[tuple[str, str, str]] = field(default_factory=list)
    # (language, proposal id, card)
    rejects: list[tuple[str, str, str]] = field(default_factory=list)
    edits: int = 0
    # Suggestions on a part the bot does not write: an example, a picture.
    left: int = 0


def _date(made: object) -> str:
    text = made[:10] if isinstance(made, str) else ""
    try:
        datetime.date.fromisoformat(text)
    except ValueError:
        return datetime.date.today().isoformat()
    return text


def read_review(files: list[dict], code: str) -> Review:
    """What [files], the review files of one mail, all by [code], ask: the
    suggestions as proposals to make, and the answers to proposals."""
    out = Review()
    for f in files:
        lang, deck = f.get("language"), f.get("deck")
        if not isinstance(lang, str) or not isinstance(deck, str) \
                or rater_code(f.get("rater_code")) != code:
            continue
        date = _date(f.get("made"))
        cards = f.get("cards") if isinstance(f.get("cards"), list) else []
        for c in cards:
            if not isinstance(c, dict) or not isinstance(c.get("card"), str):
                continue
            card = c["card"]
            s = c.get("suggestion")
            if isinstance(s, dict):
                name = pr.FIELD_OF_PART.get(s.get("part"))
                now, text, why = s.get("now"), s.get("text"), s.get("why", "")
                if name is None or not isinstance(now, str) \
                        or not isinstance(text, str):
                    out.left += 1
                else:
                    out.suggestions.append(pr.Suggestion(lang, deck, pr.Proposal(
                        card, name, now, text.strip(), code, date,
                        why.strip() if isinstance(why, str) else "")))
            answers = c.get("proposals") if isinstance(c.get("proposals"), list) else []
            for a in answers:
                if not isinstance(a, dict) or not isinstance(a.get("id"), str):
                    continue
                if a.get("answer") == "accept" and isinstance(a.get("text"), str):
                    out.accepts.append((lang, a["id"], a["text"]))
                elif a.get("answer") == "reject":
                    out.rejects.append((lang, a["id"], card))
                elif a.get("answer") == "edit":
                    out.edits += 1
    return out


# --- Git and GitHub --------------------------------------------------------------

class Git(Protocol):
    def fresh(self, branch: str) -> Path: ...
    def push(self, root: Path, branch: str, message: str) -> bool: ...
    def reindex(self, root: Path) -> None: ...
    def valid(self, root: Path, langs: list[str]) -> bool: ...


class GitHub(Protocol):
    def find_pr(self, branch: str) -> dict | None: ...
    def open_pr(self, branch: str, title: str, body: str, labels: list[str]) -> dict: ...
    def checks(self, sha: str) -> str: ...
    def merge(self, pr: dict) -> str: ...
    def label(self, number: int, labels: list[str]) -> None: ...
    def close(self, number: int, comment: str) -> None: ...
    def refresh(self, number: int) -> dict: ...


class LocalGit:
    """Branches in worktrees of the workflow's checkout, under [work], each
    from `origin/main`, pushed with the App's token."""

    NAME = "fluenough-review-bot"
    EMAIL = "fluenough-review-bot@users.noreply.github.com"

    def __init__(self, repo: Path, token: str, work: Path) -> None:
        self.repo, self.work = repo, work
        basic = base64.b64encode(f"x-access-token:{token}".encode()).decode()
        self._auth = ["-c", f"http.https://github.com/.extraheader="
                            f"AUTHORIZATION: basic {basic}"]

    def _git(self, *args: str, cwd: Path | None = None, auth: bool = False,
             check: bool = True) -> subprocess.CompletedProcess:
        """Runs git. A failure is raised without the command or its output:
        the command holds the token, and the job's log is public."""
        result = subprocess.run(
            ["git", *(self._auth if auth else []), *args],
            cwd=cwd or self.repo, capture_output=True, text=True, check=False)
        if check and result.returncode != 0:
            raise RuntimeError(f"git {args[0]} failed ({result.returncode})")
        return result

    def fresh(self, branch: str) -> Path:
        self._git("fetch", "--quiet", "origin", "main", auth=True)
        path = self.work / hashlib.sha256(branch.encode()).hexdigest()[:12]
        if path.exists():
            self._git("worktree", "remove", "--force", str(path), check=False)
            shutil.rmtree(path, ignore_errors=True)
        self._git("worktree", "prune")
        self._git("worktree", "add", "--quiet", "--force", "-B", branch,
                  str(path), "origin/main")
        return path

    def push(self, root: Path, branch: str, message: str) -> bool:
        self._git("add", "--all", "decks", cwd=root)
        if self._git("diff", "--cached", "--quiet", cwd=root, check=False).returncode == 0:
            return False
        self._git("-c", f"user.name={self.NAME}", "-c", f"user.email={self.EMAIL}",
                  "commit", "--quiet", "-m", message, cwd=root)
        self._git("push", "--quiet", "--force", "origin",
                  f"HEAD:refs/heads/{branch}", cwd=root, auth=True)
        return True

    def reindex(self, root: Path) -> None:
        subprocess.run([sys.executable, "tools/deck_index.py"], cwd=root,
                       capture_output=True, text=True, check=True)

    def valid(self, root: Path, langs: list[str]) -> bool:
        result = subprocess.run(
            # The themes file too: a language's decks are checked against it.
            [sys.executable, "tools/validate_decks.py", "decks/themes.yaml",
             *(f"decks/{lang}/" for lang in langs)],
            cwd=root, capture_output=True, text=True, check=False)
        return result.returncode == 0


class RestGitHub:
    """The REST API: PRs and merges with the App's token ([token]), check
    runs with the workflow's ([reader])."""

    def __init__(self, repo: str, token: str, reader: str) -> None:
        self.repo, self.token, self.reader = repo, token, reader
        self.owner = repo.split("/")[0]

    def _call(self, method: str, path: str, body: dict | None = None,
              token: str | None = None) -> tuple[int, object]:
        request = urllib.request.Request(
            f"https://api.github.com/repos/{self.repo}{path}",
            data=json.dumps(body).encode("utf-8") if body is not None else None,
            method=method,
            headers={
                "Authorization": f"Bearer {token or self.token}",
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

    def find_pr(self, branch: str) -> dict | None:
        status, found = self._call(
            "GET", f"/pulls?head={self.owner}:{branch}&state=all&per_page=10")
        if status != 200 or not isinstance(found, list) or not found:
            return None
        return found[0]

    def open_pr(self, branch: str, title: str, body: str, labels: list[str]) -> dict:
        status, made = self._call("POST", "/pulls", {
            "title": title, "head": branch, "base": "main", "body": body,
            "maintainer_can_modify": True})
        if status != 201 or not isinstance(made, dict):
            raise RuntimeError(f"opening the PR for {branch} failed: {status}")
        self.label(made["number"], labels)
        return made

    def refresh(self, number: int) -> dict:
        status, found = self._call("GET", f"/pulls/{number}")
        if status != 200 or not isinstance(found, dict):
            raise RuntimeError(f"reading PR #{number} failed: {status}")
        return found

    def checks(self, sha: str) -> str:
        status, found = self._call(
            "GET", f"/commits/{sha}/check-runs?per_page=100", token=self.reader)
        runs = found.get("check_runs") if status == 200 and isinstance(found, dict) else None
        if not runs:
            return "pending"
        if any(r.get("status") != "completed" for r in runs):
            return "pending"
        good = {"success", "neutral", "skipped"}
        return "passed" if all(r.get("conclusion") in good for r in runs) else "failed"

    def merge(self, pr: dict) -> str:
        found = self.refresh(pr["number"])
        if found.get("merged"):
            return "merged"
        if found.get("mergeable_state") in ("behind", "dirty"):
            return "behind"
        for method in ("squash", "merge"):
            status, answer = self._call(
                "PUT", f"/pulls/{pr['number']}/merge",
                {"merge_method": method, "sha": found["head"]["sha"]})
            if status == 200:
                return "merged"
            message = str((answer or {}).get("message", "")) if isinstance(answer, dict) else ""
            if status == 405 and "method" in message.lower():
                continue
            return "pending"
        return "pending"

    def label(self, number: int, labels: list[str]) -> None:
        self._call("POST", f"/issues/{number}/labels", {"labels": labels})

    def close(self, number: int, comment: str) -> None:
        self._call("POST", f"/issues/{number}/comments", {"body": comment})
        self._call("PATCH", f"/pulls/{number}", {"state": "closed"})


# --- The bot ----------------------------------------------------------------------

@dataclass
class Built:
    """What a branch's edit made: its PR's title, body and labels, and the
    languages to validate."""
    title: str
    body: str
    labels: list[str]
    langs: list[str]


Build = Callable[[Path], Built | None]


class Bot:
    def __init__(self, git: Git, github: GitHub, threshold: int,
                 log: Callable[[str], None] = print) -> None:
        self.git, self.github, self.threshold, self.log = git, github, threshold, log

    def job(self, branch: str, build: Build) -> str:
        """Brings [branch]'s PR one step on, opening it first if need be.
        Returns "merged", "closed" (by the owner, or with nothing left to
        change), "nothing" (nothing to change, no PR), "invalid" (the
        change does not validate, no PR), "pending" or "failed" (its
        checks failed; left open for the owner)."""
        found = self.github.find_pr(branch)
        if found is not None:
            if found.get("merged_at"):
                return "merged"
            if found.get("state") == "closed":
                return "closed"
            return self._advance(found, branch, build)
        built = self._build(branch, build)
        if isinstance(built, str):
            return built
        made = self.github.open_pr(branch, built.title, built.body, built.labels)
        self.log(f"Opened PR #{made['number']} ({branch}).")
        return self._advance(made, branch, build)

    def _build(self, branch: str, build: Build) -> Built | str:
        """Builds [branch] afresh from main and pushes it over whatever it
        held. The outcome instead when there is nothing to push."""
        root = self.git.fresh(branch)
        built = build(root)
        if built is None:
            return "nothing"
        self.git.reindex(root)
        if not self.git.valid(root, built.langs):
            self.log(f"::warning::{branch} does not validate; left for the owner.")
            return "invalid"
        if not self.git.push(root, branch, built.title):
            return "nothing"
        return built

    def _advance(self, found: dict, branch: str, build: Build) -> str:
        number = found["number"]
        state = self.github.checks(found["head"]["sha"])
        if state == "pending":
            return "pending"
        if state == "failed":
            labels = [lb.get("name") for lb in found.get("labels", []) if isinstance(lb, dict)]
            if FAILED_LABEL not in labels:
                self.github.label(number, [FAILED_LABEL])
                self.log(f"::warning::PR #{number}'s checks failed; left open "
                         f"for the owner.")
            return "failed"
        result = self.github.merge(found)
        if result == "merged":
            self.log(f"Merged PR #{number}.")
            return "merged"
        if result == "behind":
            if isinstance(self._build(branch, build), str):
                self.github.close(number, "Nothing is left to change: `main` "
                                          "already has it, or it is outdated.")
                return "closed"
            self.log(f"Rebuilt PR #{number} from main.")
        return "pending"

    # The three kinds of PR.

    def review(self, key: str, code: str, review: Review) -> str:
        """The PR of one review mail, by [code]: its proposals and
        acceptances."""
        def build(root: Path) -> Built | None:
            result = pr.Proposed()
            for s in review.suggestions:
                pr.propose(root, s, result)
            for lang, pid, text in review.accepts:
                pr.accept(root, lang, pid, code, text, result)
            if not result.changed:
                return None
            langs = sorted({s.lang for s in review.suggestions}
                           | {lang for lang, _, _ in review.accepts})
            lines = [f"Review by **{code}**, from the review mail (ADR-0038).", ""]
            if result.added:
                lines.append(f"- New proposals: {len(result.added)}, on "
                             + ", ".join(f"`{p.card}` {p.field} (`{p.id}`)"
                                         for p in result.added))
            if result.accepted:
                lines.append(f"- {code} accepts: "
                             + ", ".join(f"`{pid}`" for pid, _ in result.accepted))
            if result.outdated:
                lines.append(f"- Left out as outdated: {len(result.outdated)}")
            if result.unsupported:
                lines.append(f"- Left for the owner: {len(result.unsupported)}")
            lines += ["", "Learners do not see proposals. Reviewers of the "
                          "language see them once this merges.", "", FOOTER]
            return Built(
                title=f"Review proposals by {code}",
                body="\n".join(lines),
                labels=[LABEL, KIND_LABELS["review"]],
                langs=langs)
        return self.job(f"{PREFIX}review/{key}", build)

    def apply(self, lang: str, pid: str) -> str:
        def build(root: Path) -> Built | None:
            applied = pr.apply(root, lang, pid)
            if applied.outcome != "applied":
                return None
            p = applied.proposal
            lines = [f"Proposal `{pid}` on `{p.card}` reached the agreement "
                     f"needed ({self.threshold}) and goes to learners.", "",
                     f"- Field: {p.field}",
                     f"- Proposed by {p.by}",
                     f"- Accepted by {', '.join(p.accepted)}"]
            if applied.closed:
                lines.append("- Closed as outdated with it: " + ", ".join(
                    f"`{o.id}` by {o.by}" for o in applied.closed))
            lines += ["", FOOTER]
            return Built(
                title=f"Apply the agreed change to {p.card} ({p.field})",
                body="\n".join(lines),
                labels=[LABEL, KIND_LABELS["apply"]],
                langs=[lang])
        return self.job(f"{PREFIX}apply/{pid}", build)

    def close_outdated(self, lang: str, pids: list[str]) -> str:
        key = hashlib.sha256(",".join(sorted(pids)).encode()).hexdigest()[:10]

        def build(root: Path) -> Built | None:
            closed = pr.close(root, lang, pids)
            if not closed:
                return None
            lines = ["These proposals' fields have changed since they were "
                     "proposed, so they are closed as outdated (ADR-0038):", ""]
            lines += [f"- `{p.id}` on `{p.card}` {p.field}, by {p.by}" for p in closed]
            lines += ["", FOOTER]
            return Built(
                title=f"Close {len(closed)} outdated proposal(s) in {lang}",
                body="\n".join(lines),
                labels=[LABEL, KIND_LABELS["outdated"]],
                langs=[lang])
        return self.job(f"{PREFIX}outdated/{lang}-{key}", build)

    def sweep(self) -> dict[str, int]:
        """On `main`: applies each proposal with enough agreement, the
        first on its field winning, and closes the outdated ones."""
        counts = {"applied": 0, "waiting": 0, "outdated": 0}
        root = self.git.fresh(f"{PREFIX}read-main")
        for lang in pr.languages(root):
            found = pr.all_proposals(root, lang)
            stale = {p.id for _, p in pr.outdated(root, lang)}
            groups: dict[tuple, list[pr.Proposal]] = {}
            for e, p in found:
                if p.id not in stale and len(p.accepted) >= self.threshold:
                    groups.setdefault((str(e.path), p.card, p.field), []).append(p)
            for ready in groups.values():
                for p in ready:
                    outcome = self.apply(lang, p.id)
                    if outcome == "closed":
                        continue
                    counts["applied" if outcome == "merged" else "waiting"] += 1
                    break
            if stale:
                counts["outdated"] += len(stale)
                self.close_outdated(lang, sorted(stale))
        return counts
