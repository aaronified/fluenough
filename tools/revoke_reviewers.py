#!/usr/bin/env python3
"""The revocation job (ADR-0058, decision 9; work package W8, #1659).

The owner revokes a reviewer by adding the key id to
`assets/reviewer/denylist.txt` on main, ids only (owner: "I revoke. And it
does revoke past work."). This job then takes the work of every rater code
bound to a revoked key id out of the decks, as pull requests to `decks-live`
that wait for the owner. It never merges anything.

**The code and the key id never meet in a public place.** Which rater code a
key id is bound to lives only in the private store (the Gmail label
`fluenough/keys`, `tools/reviewer_binding.py`). The job reads it, works on
codes, and writes only what the decks already hold in public: no key id, no
code-to-key mapping, no reason, no address, in a branch name, a PR, a commit
message or the log. Branches and PRs are named by a hash of the code, or by
number; the log says counts only. (A public timeline can still tell: a code
leaving the decks on the day an id joins the denylist. Revoking several keys
in one commit makes that harder.)

What a run does, every run, from the current `decks-live`:

1. **One removal PR** (`review-bot/revoke/clean-<n>`): takes each revoked
   code out of every card's `checked_by`, out of every facet's `by` and every
   `flags` entry of `facet_checks`, out of the `accepted` list of every
   proposal not yet applied, and deletes the unapplied proposals the code
   made (a proposal's id is made from its proposer, so the proposer cannot
   be blanked, only the proposal withdrawn). A facet or card that falls below
   the quorum (`tools/review_quorum.py`, the one REVIEW_QUORUM) is no longer
   settled, by the same rule that settled it; a deck file tagged `reviewed`
   whose facets are no longer all at the quorum is tagged `unreviewed` again,
   in the same PR (`proposals.mark_unreviewed`).
2. **One revert PR for each revoked code** (`review-bot/revoke/revert-<hash>-<n>`),
   for the changes the code made possible: an applied change whose agreement
   (the proposer and those who accepted) would no longer reach the quorum
   without the revoked code. One commit per change, restoring the text the
   change replaced, so each can be dropped in review. See [Change] for the
   record this reads and what it lacks.

Idempotent: each run rebuilds from `decks-live`; a tree already clean yields
no PR, an open PR is rebuilt in place and pushed only when its tree would
differ, so a re-run changes nothing. A revert PR the owner closes is a
decision, remembered through a hidden line in its body: those changes are not
proposed again.

Environment (the same secrets as the feedback mail workflow):
    FEEDBACK_GMAIL_ADDRESS, FEEDBACK_GMAIL_APP_PASSWORD  the private store
    FLUENOUGH_BOT_TOKEN  the bot App's installation token
    GITHUB_TOKEN, GITHUB_REPOSITORY
Without them it does nothing and says so.
"""

from __future__ import annotations

import hashlib
import imaplib
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse
from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Callable, Protocol

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
import review_bot as rb  # noqa: E402
import review_quorum as rq  # noqa: E402
import reviewer_binding  # noqa: E402
import reviewer_keys as rk  # noqa: E402

PREFIX = rb.PREFIX + "revoke/"
LABELS = {"clean": "revocation", "revert": "revocation revert"}
# Slots tried for one kind of PR: a merged or closed PR is passed over for the
# next number.
SLOTS = 60

REVERTED_MARK = "<!-- fluenough-reverted "
_REVERTED = re.compile(re.escape(REVERTED_MARK) + r"([0-9, ]*) -->")


def norm(code: str) -> str:
    """A rater code as it is compared: upper case, trimmed."""
    return (code or "").strip().upper()


# --- Who is revoked --------------------------------------------------------------------

def revoked_codes(keyring: rk.Keyring, bindings) -> frozenset[str] | None:
    """The rater codes bound to a key id on the denylist, from the private
    store, or None when the store could not be read (then nothing is done:
    never a half answer). Nothing here is printed."""
    if not bindings.ready:
        return None
    return frozenset(norm(code) for key_id, code, _tier, _courses
                     in bindings.entries()
                     if key_id in keyring.denylist and norm(code))


# --- Part 1: taking the codes out of the decks -----------------------------------------

@dataclass
class Removal:
    """What stripping the revoked codes from a checkout came to. Counts and
    card or deck ids only."""
    entries: int = 0        # card entries a code was taken off
    removed: int = 0        # unapplied proposals by a revoked code, withdrawn
    trimmed: int = 0        # unapplied proposals a revoked code had accepted
    below: int = 0          # entries that were settled and no longer are
    retagged: list[str] = field(default_factory=list)   # deck ids, set unreviewed
    unsupported: list[str] = field(default_factory=list)  # card ids, not written
    files: set[Path] = field(default_factory=set)

    @property
    def changed(self) -> bool:
        return bool(self.files)


def _bad(code: str, codes: frozenset[str]) -> bool:
    return norm(code) in codes


def dirty(entry: pr.Entry, codes: frozenset[str]) -> bool:
    """Whether [entry] carries the work of a revoked code anywhere the job
    cleans."""
    if any(_bad(c, codes) for c in pr.checked_by(entry)):
        return True
    for held in pr.facet_data(entry).values():
        if any(_bad(c, codes) for c in held["by"]) \
                or any(_bad(f["by"], codes) for f in held["flags"]):
            return True
    return any(_bad(p.by, codes) or any(_bad(a, codes) for a in p.accepted)
               for p in entry.proposals())


def _reload(entry: pr.Entry) -> pr.Entry:
    found = [e for e in pr._entries_in(entry.path, pr._load(entry.path))
             if e.card == entry.card and e.form == entry.form]
    if len(found) != 1:
        raise pr.Unsupported("the entry is gone")
    return found[0]


def _clean_entry(entry: pr.Entry, codes: frozenset[str], out: Removal) -> None:
    """Takes [codes] off [entry], one edit and one line at a time; raises
    Unsupported when the entry cannot be written that way (what was written
    before stays)."""
    # Proposals not applied: the revoked proposer's are withdrawn, and the
    # revoked acceptances of the others dropped.
    for p in entry.proposals():
        if _bad(p.by, codes):
            edit = pr._Text(entry)
            edit.remove(p.id)
            edit.save(lambda e, pid=p.id: all(x.id != pid for x in e.proposals()))
            out.removed += 1
        elif any(_bad(a, codes) for a in p.accepted):
            kept = replace(p, accepted=tuple(a for a in p.accepted
                                             if not _bad(a, codes)))
            edit = pr._Text(entry)
            edit.replace(kept)
            edit.save(lambda e, k=kept: k in e.proposals())
            out.trimmed += 1
        entry = _reload(entry)
    # The facets' answers: the revoked code's "right" and its flags.
    held = pr.facet_data(entry)
    if held:
        cleaned: dict[str, dict] = {}
        for facet, v in held.items():
            by = [c for c in v["by"] if not _bad(c, codes)]
            flags = [f for f in v["flags"] if not _bad(f["by"], codes)]
            if by or flags:
                cleaned[facet] = {"by": by, "flags": flags}
        if cleaned != held:
            pr._write_facets(entry, cleaned)
            entry = _reload(entry)
    # The sign-offs: `checked_by` lists the codes right on every facet, so what
    # is left of the mirror is the old list without the revoked codes.
    have = pr.checked_by(entry)
    if any(_bad(c, codes) for c in have):
        kept_codes = [c for c in have if not _bad(c, codes)]
        if kept_codes:
            pr._write_checked(entry, kept_codes)
        else:
            pr._remove_listed(entry, "checked_by", lambda e: not pr.checked_by(e))


def _clean_file(path: Path, codes: frozenset[str], out: Removal) -> None:
    entries = pr._entries_in(path, pr._load(path))
    before = {(e.card, e.form): pr.facets_settled(e) for e in entries}
    stuck: set[tuple[str, str]] = set()
    wrote = False
    for _ in range(len(entries) * 4 + 4):
        target = next((e for e in pr._entries_in(path, pr._load(path))
                       if (e.card, e.form) not in stuck and dirty(e, codes)), None)
        if target is None:
            break
        text = path.read_text(encoding="utf-8")
        try:
            _clean_entry(target, codes, out)
        except pr.Unsupported:
            out.unsupported.append(target.card)
            stuck.add((target.card, target.form))
        if path.read_text(encoding="utf-8") != text:
            wrote = True
            out.entries += 1
    if not wrote:
        return
    out.files.add(path)
    for e in pr._entries_in(path, pr._load(path)):
        if before.get((e.card, e.form)) is True and pr.facets_settled(e) is False:
            out.below += 1
    # A file tagged `reviewed` whose facets are no longer all at the quorum
    # goes back to `unreviewed`: the reverse of `review_done`.
    if not pr.all_checked(path) and pr.mark_unreviewed(path):
        raw = pr._load(path)
        out.retagged.append(raw.get("id") if isinstance(raw, dict)
                            and isinstance(raw.get("id"), str) else path.stem)


def strip_codes(root: Path, codes: frozenset[str]) -> Removal:
    """Takes every code of [codes] (upper case) out of the decks under
    [root]. Only the files that name one are read."""
    out = Removal()
    needles = [c.lower() for c in codes]
    for lang in pr.languages(root):
        for path in pr.language_files(root, lang):
            try:
                low = path.read_text(encoding="utf-8").lower()
            except (OSError, UnicodeDecodeError):
                continue
            if any(n in low for n in needles):
                _clean_file(path, codes, out)
    return out


def langs_of(root: Path, paths: set[Path]) -> list[str]:
    return sorted({p.relative_to(root / "decks").parts[0] for p in paths})


# --- Part 2: the changes a revoked code made possible ----------------------------------

@dataclass(frozen=True)
class Group:
    """One agreed proposal: who proposed it and who accepted it. [accepted]
    is None when the record does not say."""
    by: str
    accepted: tuple[str, ...] | None


@dataclass(frozen=True)
class Change:
    """One agreement the bot applied to the decks: the merged PR, the commit
    it made on `decks-live`, the card and field, and who agreed.

    The record is the body of the bot's agreement PR (`review_bot.apply`):
    the proposal's id, card and field, its proposer and those who accepted
    it. The apply drops the proposal from the deck, so the repository itself
    keeps no record of who agreed; the PR body is the only one, and its
    weaknesses are written in wiki/ADR-0058-Reviewer-UX.md (W8 note): it can
    be edited by the owner, a PR deleted from GitHub is lost, and a PR made
    before the hidden record existed names only the proposer of an agreed
    reading or IPA applied with a word, not who accepted it (such a group has
    `accepted=None` and is never reverted on that ground)."""
    number: int
    sha: str
    card: str
    field: str
    groups: tuple[Group, ...]


def change_of(number: int, sha: str, body: str) -> Change | None:
    """The change an agreement PR's [body] records, or None when it is not one."""
    found = rb.parse_applied(body)
    if found is None or not sha:
        return None
    groups = [Group(found["by"], tuple(found["accepted"]))]
    for g in found["with"]:
        groups.append(Group(g["by"], None if g["accepted"] is None
                            else tuple(g["accepted"])))
    return Change(number, sha, found["card"], found["field"], tuple(groups))


def verdict(change: Change, codes: frozenset[str], lang: str | None) -> tuple[str, str]:
    """("revert", the revoked code to queue it under), ("unknown", "") when a
    group a revoked code is in does not record who accepted it, or ("ok", "")."""
    unknown = False
    for g in change.groups:
        people = list(dict.fromkeys(
            norm(c) for c in [g.by, *(g.accepted or ())] if norm(c)))
        involved = [c for c in people if c in codes]
        if not involved:
            continue
        if g.accepted is None:
            unknown = True
            continue
        left = [(c, rq.tier_of(c, lang)) for c in people if c not in codes]
        if not rq.facet_reached_quorum(left):
            return "revert", sorted(involved)[0]
    return ("unknown", "") if unknown else ("ok", "")


class Ledger(Protocol):
    def applied(self, codes: frozenset[str]) -> list[Change]: ...


def reverted_numbers(body: str | None) -> set[int]:
    """The agreement PR numbers a revert PR's [body] says it reverts."""
    found = _REVERTED.search(body or "")
    return {int(n) for n in re.findall(r"\d+", found.group(1))} if found else set()


def lang_of_card(card: str, langs: list[str]) -> str | None:
    """The language folder a card id belongs to (`te-0001`), when it is one
    of [langs]: what a key's courses scope a reviewer's tier by."""
    head = card.split("-", 1)[0]
    return head if head in langs else None


# --- Git and GitHub for this job --------------------------------------------------------

class RevokeGit(Protocol):
    def fresh(self, branch: str) -> Path: ...
    def commit(self, root: Path, message: str) -> bool: ...
    def reindex(self, root: Path) -> None: ...
    def valid(self, root: Path, langs: list[str]) -> bool: ...
    def publish(self, root: Path, branch: str) -> str: ...
    def patch_of(self, sha: str) -> bytes | None: ...
    def apply_reverse(self, root: Path, patch: bytes) -> bool: ...


class LocalRevokeGit(rb.LocalGit):
    """The bot's worktrees (`review_bot.LocalGit`), with what a job of
    several commits needs."""

    def commit(self, root: Path, message: str) -> bool:
        self._git("add", "--all", "decks", cwd=root)
        if self._git("diff", "--cached", "--quiet", cwd=root, check=False).returncode == 0:
            return False
        self._git("-c", f"user.name={self.NAME}", "-c", f"user.email={self.EMAIL}",
                  "commit", "--quiet", "-m", message, cwd=root)
        return True

    def publish(self, root: Path, branch: str) -> str:
        """Pushes the worktree's commits as [branch], over what it held, but
        only when its tree differs from the branch as it is: a rerun that
        would push the same tree pushes nothing (and so starts no CI).
        "empty" when there is no commit on `decks-live`, "unchanged", "pushed"."""
        ahead = self._git("rev-list", "--count", f"origin/{rb.DECKS_BRANCH}..HEAD",
                          cwd=root).stdout.strip()
        if ahead in ("", "0"):
            return "empty"
        tree = self._git("rev-parse", "HEAD^{tree}", cwd=root).stdout.strip()
        remote = self._git("ls-remote", "--heads", "origin", branch,
                           cwd=root, auth=True).stdout.strip()
        if remote:
            fetched = self._git("fetch", "--quiet", "origin", branch,
                                cwd=root, auth=True, check=False)
            if fetched.returncode == 0 and self._git(
                    "rev-parse", "FETCH_HEAD^{tree}", cwd=root).stdout.strip() == tree:
                return "unchanged"
        self._git("push", "--quiet", "--force", "origin",
                  f"HEAD:refs/heads/{branch}", cwd=root, auth=True)
        return "pushed"

    def patch_of(self, sha: str) -> bytes | None:
        """The change commit [sha] made to the deck files (YAML only, never
        the index) against its first parent, when [sha] is on `decks-live`."""
        base = ["git", "-C", str(self.repo)]
        on = subprocess.run([*base, "merge-base", "--is-ancestor", sha,
                             f"origin/{rb.DECKS_BRANCH}"], capture_output=True)
        if on.returncode != 0:
            return None
        names = subprocess.run(
            [*base, "diff", "--name-only", f"{sha}^1", sha, "--", "decks"],
            capture_output=True, text=True, check=False)
        files = [n for n in names.stdout.split("\n")
                 if n.endswith((".yaml", ".yml"))]
        if names.returncode != 0 or not files:
            return None
        patch = subprocess.run([*base, "diff", f"{sha}^1", sha, "--", *files],
                               capture_output=True, check=False)
        return patch.stdout if patch.returncode == 0 and patch.stdout else None

    def apply_reverse(self, root: Path, patch: bytes) -> bool:
        """Applies [patch] backwards in [root], all of it or none."""
        for flags in (["--check"], []):
            done = subprocess.run(["git", "apply", "-R", "--whitespace=nowarn", *flags, "-"],
                                  cwd=root, input=patch, capture_output=True,
                                  check=False)
            if done.returncode != 0:
                return False
        return True


class RevokeGitHub(rb.RestGitHub):
    def update_pr(self, number: int, title: str, body: str) -> None:
        self._call("PATCH", f"/pulls/{number}", {"title": title, "body": body})

    def applied_prs(self, codes: frozenset[str]) -> list[dict]:
        """The merged agreement PRs, onto `decks-live`, whose body names one of
        [codes]: `{number, body, sha}`."""
        wanted = [c.lower() for c in codes]
        labels = urllib.parse.quote(f"{rb.LABEL},{rb.KIND_LABELS['apply']}")
        out: list[dict] = []
        for page in range(1, 60):
            status, found = self._call(
                "GET", f"/issues?labels={labels}&state=closed&per_page=100&page={page}")
            if status != 200 or not isinstance(found, list):
                raise RuntimeError(f"listing the agreement PRs failed: {status}")
            for item in found:
                if not isinstance(item, dict) or "pull_request" not in item:
                    continue
                body = item.get("body") or ""
                if not any(w in body.lower() for w in wanted):
                    continue
                status, detail = self._call("GET", f"/pulls/{item['number']}")
                if status == 200 and isinstance(detail, dict) \
                        and detail.get("merged_at") \
                        and (detail.get("base") or {}).get("ref") == rb.DECKS_BRANCH:
                    out.append({"number": item["number"], "body": body,
                                "sha": detail.get("merge_commit_sha") or ""})
            if len(found) < 100:
                break
        return out


class GithubLedger:
    def __init__(self, github: RevokeGitHub) -> None:
        self.github = github

    def applied(self, codes: frozenset[str]) -> list[Change]:
        found = (change_of(p["number"], p["sha"], p["body"])
                 for p in self.github.applied_prs(codes))
        return sorted((c for c in found if c), key=lambda c: c.number)


# --- The job -----------------------------------------------------------------------------

class Revocation:
    def __init__(self, git: RevokeGit, github, ledger: Ledger,
                 log: Callable[[str], None] = print) -> None:
        self.git, self.github, self.ledger, self.log = git, github, ledger, log

    def run(self, codes: frozenset[str]) -> dict[str, int]:
        """One run, for [codes] (upper case). Counts only."""
        counts = {"revoked codes": len(codes), "removal prs": 0, "revert prs": 0,
                  "changes to revert": 0, "changes unknown": 0}
        if not codes:
            self.log("No rater code is bound to a revoked key: nothing to do.")
            return counts
        branch, found, _ = self._free(PREFIX + "clean")
        outcome = ("full" if branch is None else
                   self._job(branch, found, lambda root: self._clean(root, codes)))
        counts["removal prs"] = int(outcome in ("opened", "updated", "pending"))
        reverts, counts["changes unknown"] = self._reverts(codes)
        counts["changes to revert"] = sum(len(v) for v in reverts.values())
        for code, changes in sorted(reverts.items()):
            stem = PREFIX + "revert-" + hashlib.sha256(code.encode()).hexdigest()[:10]
            branch, found, decided = self._free(stem)
            todo = [c for c in changes if c.number not in decided]
            if branch is None or (not todo and found is None):
                continue
            outcome = self._job(branch, found, lambda root, t=todo: self._revert(root, t))
            counts["revert prs"] += int(outcome in ("opened", "updated", "pending"))
        self.log(f"Revocation: {counts['revoked codes']} revoked code(s); "
                 f"{counts['removal prs']} removal PR(s) open; "
                 f"{counts['changes to revert']} applied change(s) to revert in "
                 f"{counts['revert prs']} PR(s); {counts['changes unknown']} with "
                 f"no record of who accepted.")
        return counts

    # Builds. Each makes its commits in the worktree [root] and answers with
    # what the PR says, or None when there is nothing to change.

    def _clean(self, root: Path, codes: frozenset[str]) -> rb.Built | None:
        result = strip_codes(root, codes)
        if not result.changed:
            return None
        self.git.commit(root, "Remove the work of revoked reviewer keys from the decks")
        lines = ["The owner revoked reviewer keys (ADR-0058, decision 9), and "
                 "their work is removed from the decks. No reviewer is named "
                 "here.", "",
                 f"- Card entries taken off sign-offs, facet answers or "
                 f"proposals: {result.entries}",
                 f"- Proposals withdrawn (made by a revoked reviewer): {result.removed}",
                 f"- Proposals that lose an acceptance: {result.trimmed}",
                 f"- Entries that no longer have the review quorum: {result.below}"]
        if result.retagged:
            lines.append("- Deck files tagged `unreviewed` again: "
                         + ", ".join(f"`{d}`" for d in sorted(result.retagged)))
        if result.unsupported:
            lines.append("- Entries that cannot be edited one line at a time, "
                         "left for the owner: "
                         + ", ".join(f"`{c}`" for c in sorted(set(result.unsupported))))
        lines += ["", "Not merged by the bot: the owner reviews and merges it. "
                      "A rerun rebuilds this from `decks-live`.", "", rb.FOOTER]
        return rb.Built(title="Remove the work of revoked reviewer keys",
                        body="\n".join(lines),
                        labels=[rb.LABEL, LABELS["clean"]],
                        langs=langs_of(root, result.files))

    def _reverts(self, codes: frozenset[str]) -> tuple[dict[str, list[Change]], int]:
        """The applied changes that no longer have the quorum, by the revoked
        code to queue each under (the first when two are in one change), and
        how many have no record of who accepted."""
        root = self.git.fresh(PREFIX + "read-decks")
        langs = pr.languages(root)
        out: dict[str, list[Change]] = {}
        unknown = 0
        for change in self.ledger.applied(codes):
            kind, code = verdict(change, codes, lang_of_card(change.card, langs))
            if kind == "revert":
                out.setdefault(code, []).append(change)
            elif kind == "unknown":
                unknown += 1
        return out, unknown

    def _revert(self, root: Path, changes: list[Change]) -> rb.Built | None:
        done: list[Change] = []
        not_reverted = 0
        # Latest first, so that the older change is reverted on top of the newer.
        for change in sorted(changes, key=lambda c: -c.number):
            patch = self.git.patch_of(change.sha)
            if patch is None or not self.git.apply_reverse(root, patch):
                not_reverted += 1
                continue
            self.git.commit(
                root, f"Revert the agreed change to {change.card} ({change.field}), "
                      f"PR #{change.number}\n\nRestores the text that PR replaced. "
                      f"Its agreement no longer holds.")
            done.append(change)
        if not done:
            return None
        lines = ["The owner revoked a reviewer key (ADR-0058, decision 9). "
                 "These agreed changes only had the review quorum because of "
                 "that reviewer, so each is reverted, one commit each: drop a "
                 "commit to keep that change. No reviewer is named here.", ""]
        lines += [f"- `{c.card}` {c.field}, applied in #{c.number}"
                  for c in sorted(done, key=lambda c: c.number)]
        if not_reverted:
            lines.append(f"- Not reverted: {not_reverted} (already reverted, or "
                         f"the field has been edited since).")
        lines += ["", "Not merged by the bot: the owner reviews and merges it. "
                      "Closing it keeps these changes; it is not proposed again.",
                  "", REVERTED_MARK + ", ".join(str(c.number) for c in sorted(
                      done, key=lambda c: c.number)) + " -->", rb.FOOTER]
        langs = sorted({m for c in done for m in
                        [lang_of_card(c.card, pr.languages(root))] if m})
        return rb.Built(title=f"Revert {len(done)} change(s) agreed with a revoked "
                              f"reviewer's help",
                        body="\n".join(lines),
                        labels=[rb.LABEL, LABELS["revert"]], langs=langs)

    # PRs. Never merged here.

    def _free(self, stem: str) -> tuple[str | None, dict | None, set[int]]:
        """The first branch of [stem] whose PR is not merged or closed (with
        that PR, if open), and the agreement PR numbers the merged or closed
        revert PRs before it decided."""
        decided: set[int] = set()
        for n in range(1, SLOTS + 1):
            branch = f"{stem}-{n}"
            found = self.github.find_pr(branch)
            if found is not None and (found.get("merged_at") or found.get("state") == "closed"):
                decided |= reverted_numbers(found.get("body"))
                continue
            return branch, found, decided
        self.log(f"::warning::{stem}: {SLOTS} pull requests used; the owner "
                 f"should merge them.")
        return None, None, decided

    def _job(self, branch: str, found: dict | None,
             build: Callable[[Path], rb.Built | None]) -> str:
        root = self.git.fresh(branch)
        built = build(root)
        if built is None:
            if found is not None:
                self.github.close(found["number"], "Nothing is left to change: "
                                  "`decks-live` is already clean.")
                self.log(f"Closed PR #{found['number']}: nothing left to change.")
                return "closed"
            return "nothing"
        self.git.reindex(root)
        self.git.commit(root, "Regenerate the deck index")
        if not self.git.valid(root, built.langs):
            self.log(f"::warning::{branch} does not validate; left for the owner.")
            return "invalid"
        pushed = self.git.publish(root, branch)
        if pushed == "empty":
            return "nothing"
        if found is None:
            made = self.github.open_pr(branch, built.title, built.body, built.labels)
            self.log(f"Opened PR #{made['number']} ({branch}).")
            return "opened"
        if found.get("title") != built.title or found.get("body") != built.body:
            self.github.update_pr(found["number"], built.title, built.body)
        if pushed == "pushed":
            self.log(f"Rebuilt PR #{found['number']} from decks-live.")
            return "updated"
        return "pending"


# --- The command ------------------------------------------------------------------------

def main(env: dict[str, str] | None = None,
         connect: Callable[[str], imaplib.IMAP4] = imaplib.IMAP4_SSL) -> int:
    env = dict(os.environ if env is None else env)
    keyring = rk.load_keyring()
    if not keyring.denylist:
        print("The denylist is empty: nothing to revoke.")
        return 0
    address = env.get("FEEDBACK_GMAIL_ADDRESS", "")
    password = env.get("FEEDBACK_GMAIL_APP_PASSWORD", "")
    token = env.get("FLUENOUGH_BOT_TOKEN", "")
    if not (address and password and token):
        print("::notice::The feedback inbox or the review bot's GitHub App is "
              "not set up (FEEDBACK_GMAIL_*, FLUENOUGH_BOT_APP_ID, "
              "FLUENOUGH_BOT_PRIVATE_KEY): revocation cannot run.")
        return 0
    imap = connect("imap.gmail.com")
    imap.login(address, password)
    try:
        bindings = reviewer_binding.GmailBindings(imap)
        bindings.load()
    finally:
        try:
            imap.logout()
        except (imaplib.IMAP4.error, OSError):
            pass
    codes = revoked_codes(keyring, bindings)
    if codes is None:
        print(f"::error::The key bindings ({reviewer_binding.KEYS}) could not "
              f"be read: nothing was revoked this run.")
        return 1
    print(f"{len(keyring.denylist)} revoked key id(s), {len(codes)} bound to a "
          f"rater code.")
    # What the quorum reads of the others, for the cards cleaned: the live keys only.
    rq.set_tiers(reviewer_binding.KeyGate(keyring, bindings).tiers())
    repo = env.get("GITHUB_REPOSITORY", "")
    root = Path(__file__).resolve().parent.parent
    work = Path(env.get("RUNNER_TEMP") or tempfile.gettempdir()) / "revoke"
    work.mkdir(parents=True, exist_ok=True)
    github = RevokeGitHub(repo, token, env.get("GITHUB_TOKEN", ""))
    job = Revocation(LocalRevokeGit(root, token, work), github, GithubLedger(github))
    try:
        job.run(codes)
    except Exception as error:  # noqa: BLE001 - the type only: a message may hold a token
        print(f"::error::The revocation job failed: {type(error).__name__}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
