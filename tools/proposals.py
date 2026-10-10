#!/usr/bin/env python3
"""Proposals in the decks: written, accepted, applied and closed (ADR-0038).

The review bot (`tools/review_bot.py`) uses this on a fresh checkout of
`main`. A proposal is a fact about one field of one card: the card's id,
the field, the text the proposer saw (`now`), the new text, the proposer's
rater code and the date, with the codes of the reviewers who accepted it.
It is kept on the card, in the deck file that holds the field, as one line
of YAML in the card's `proposed` list:

    proposed:
      - { id: "3f9c0a1b2d", field: "native", now: "dog", text: "the dog", by: "FL-7K3M-Q9TD-6", date: "2026-10-09" }

Every edit here is made to the file's text, one line at a time, and never
by writing the YAML out again, so that no other line of a deck changes
(AGENTS.md rule 8). After each edit the file is read again, and an edit
that did not read back as meant is not saved: such a card is reported
"unsupported" and left for the owner. That covers a field written over
several lines and a card written in flow style.

Needs Python 3.11+ and PyYAML, like the validator.
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field, replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks as vd  # noqa: E402
import yaml  # noqa: E402

# The part of a card a review's suggestion names (lib/core/review/
# deck_review.dart, CardPart) and the field it is in the deck. An example,
# a picture or a base word's meaning (`base`, with the base's `word`) is
# left for the owner.
FIELD_OF_PART = {
    "word": "target",
    "reading": "reading",
    "ipa": "ipa",
    "meaning": "native",
    "notes": "notes",
}
# The order fields are written in, for a field the card did not have.
FIELD_ORDER = ("id", "ref", "target", "reading", "ipa", "native")


@dataclass(frozen=True)
class Proposal:
    """One proposed change to one field of one card."""
    card: str
    field: str
    now: str
    text: str
    by: str
    date: str
    why: str = ""
    accepted: tuple[str, ...] = ()

    @property
    def id(self) -> str:
        return vd.proposal_id(self.card, self.field, self.now, self.text, self.by)

    def line(self) -> str:
        """The proposal as its one line of YAML, without the indent."""
        def q(text: str) -> str:
            return json.dumps(text, ensure_ascii=False)
        parts = [f"id: {q(self.id)}", f"field: {q(self.field)}",
                 f"now: {q(self.now)}", f"text: {q(self.text)}",
                 f"by: {q(self.by)}", f"date: {q(self.date)}"]
        if self.why:
            parts.append(f"why: {q(self.why)}")
        if self.accepted:
            parts.append(f"accepted: [{', '.join(q(a) for a in self.accepted)}]")
        return "- { " + ", ".join(parts) + " }"

    @staticmethod
    def read(card: str, item: object) -> Proposal | None:
        """[item], one entry of a card's `proposed`, or None if it is not a
        proposal whose id is its facts'."""
        if not isinstance(item, dict):
            return None
        values = [item.get(k) for k in ("field", "now", "text", "by", "date")]
        if not all(isinstance(v, str) for v in values):
            return None
        why = item.get("why", "")
        accepted = item.get("accepted", [])
        if not isinstance(why, str) or not isinstance(accepted, list) \
                or not all(isinstance(a, str) for a in accepted):
            return None
        p = Proposal(card, *values, why=why, accepted=tuple(accepted))
        return p if item.get("id") == p.id else None


@dataclass
class Entry:
    """Where a card is in a deck file: the file, the kind of entry (a key of
    validate_decks.PROPOSAL_FIELDS), the entry as loaded, and the file's id
    and, for a layer, its core's."""
    path: Path
    form: str
    card: str
    data: dict
    deck: str
    core: str | None = None

    def value(self, name: str) -> object:
        """What the field says, "" when the card does not have it."""
        return self.data.get(name, "")

    def may_change(self, name: str) -> bool:
        if name not in vd.PROPOSAL_FIELDS[self.form]:
            return False
        return name != "notes" or isinstance(self.data.get("notes"), (str, type(None)))

    def proposals(self) -> list[Proposal]:
        items = self.data.get("proposed")
        if not isinstance(items, list):
            return []
        return [p for p in (Proposal.read(self.card, i) for i in items) if p]


class Unsupported(Exception):
    """The edit cannot be made to this file's text, one line at a time."""


def _load(path: Path) -> object:
    try:
        return yaml.load(path.read_text(encoding="utf-8"), Loader=vd.DeckLoader)
    except (OSError, UnicodeDecodeError, yaml.YAMLError):
        return None


def _entries_in(path: Path, raw: object) -> list[Entry]:
    if not isinstance(raw, dict):
        return []
    deck = raw.get("id") if isinstance(raw.get("id"), str) else path.stem
    cards = raw.get("cards")
    out = []
    if raw.get("kind") == "layer" and isinstance(cards, dict):
        core = raw.get("core") if isinstance(raw.get("core"), str) else None
        for key, data in cards.items():
            if isinstance(key, str) and isinstance(data, dict):
                form = "layer-own" if "target" in data else "layer"
                out.append(Entry(path, form, key, data, deck, core))
    elif isinstance(cards, list):
        core = raw.get("part") == "core"
        for data in cards:
            if not isinstance(data, dict):
                continue
            ref = "ref" in data
            card = data.get("ref" if ref else "id")
            if not isinstance(card, str):
                continue
            form = ("core-ref" if ref else "core") if core else ("ref" if ref else "single")
            out.append(Entry(path, form, card, data, deck))
    return out


def language_files(root: Path, lang: str) -> list[Path]:
    return vd._yaml_files(root / "decks" / lang)


def entries(root: Path, lang: str, card: str | None = None) -> list[Entry]:
    """Every card entry of [lang], or of [card] only, across its files."""
    out = []
    for path in language_files(root, lang):
        text = path.read_text(encoding="utf-8")
        if card is not None and card not in text:
            continue
        out.extend(e for e in _entries_in(path, _load(path))
                   if card is None or e.card == card)
    return out


def all_proposals(root: Path, lang: str) -> list[tuple[Entry, Proposal]]:
    return [(e, p) for e in entries(root, lang) for p in e.proposals()]


def find(root: Path, lang: str, pid: str) -> tuple[Entry, Proposal] | None:
    """The proposal [pid] of [lang] and the entry holding it, or None."""
    for path in language_files(root, lang):
        if pid not in path.read_text(encoding="utf-8"):
            continue
        for e in _entries_in(path, _load(path)):
            for p in e.proposals():
                if p.id == pid:
                    return e, p
    return None


# --- Editing a file's text ----------------------------------------------------

def _quoted(text: str) -> str:
    return json.dumps(text, ensure_ascii=False)


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _blank(line: str) -> bool:
    stripped = line.strip()
    return not stripped or stripped.startswith("#")


class _Text:
    """A deck file's lines, and the span of one card's entry in them."""

    def __init__(self, entry: Entry) -> None:
        self.entry = entry
        self.lines = entry.path.read_text(encoding="utf-8").splitlines(keepends=True)
        self.start, self.end, self.fi = self._span()

    def _span(self) -> tuple[int, int, int]:
        """The entry's first line, the line after its last, and the indent
        of its fields."""
        lines, card = self.lines, re.escape(self.entry.card)
        top = next((i for i, l in enumerate(lines) if re.match(r"^cards\s*:\s*$", l)), None)
        if top is None:
            raise Unsupported("no block `cards:`")
        first = next((i for i in range(top + 1, len(lines)) if not _blank(lines[i])), None)
        if first is None:
            raise Unsupported("no cards")
        at = _indent(lines[first])
        if self.entry.form in ("layer", "layer-own"):
            head = re.compile(rf"^ {{{at}}}[\"']?{card}[\"']?\s*:\s*(#.*)?$")
        else:
            head = re.compile(rf"^ {{{at}}}- [\"']?(?:id|ref)[\"']?\s*:\s*"
                              rf"[\"']?{card}[\"']?\s*(#.*)?$")
        start = next((i for i in range(first, len(lines))
                      if head.match(lines[i].rstrip("\n"))), None)
        if start is None:
            raise Unsupported("entry not found as a block")
        end = start + 1
        while end < len(lines) and (_blank(lines[end]) or _indent(lines[end]) > at):
            end += 1
        while end > start + 1 and _blank(lines[end - 1]):
            end -= 1
        if self.entry.form in ("layer", "layer-own"):
            if end == start + 1:
                raise Unsupported("empty entry")
            fi = _indent(lines[start + 1])
        else:
            fi = at + 2
        return start, end, fi

    def _key_line(self, name: str) -> int | None:
        key = re.compile(rf"^ {{{self.fi}}}[\"']?{re.escape(name)}[\"']?\s*:")
        for i in range(self.start + 1, self.end):
            if key.match(self.lines[i]):
                return i
        return None

    def _block_end(self, i: int) -> int:
        """The line after the field starting at [i] and anything under it."""
        j = i + 1
        while j < self.end and (_blank(self.lines[j]) or _indent(self.lines[j]) > self.fi):
            j += 1
        return j

    def set_field(self, name: str, text: str) -> None:
        line = f"{' ' * self.fi}{name}: {_quoted(text)}\n"
        i = self._key_line(name)
        if i is not None:
            if self._block_end(i) != i + 1:
                raise Unsupported(f"{name} is written over several lines")
            self.lines[i] = line
            return
        # A field the card did not have: after the last of those written
        # before it, or else last among its fields.
        after = self.start
        if name in FIELD_ORDER:
            for before in FIELD_ORDER[:FIELD_ORDER.index(name)]:
                j = self._key_line(before)
                if j is not None:
                    after = self._block_end(j) - 1
        else:
            j = self._key_line("proposed")
            after = (j if j is not None else self.end) - 1
        self.lines.insert(after + 1, line)
        self.end += 1

    def _items(self) -> tuple[int | None, list[int]]:
        """The `proposed:` line and its item lines."""
        head = self._key_line("proposed")
        if head is None:
            return None, []
        items = []
        for i in range(head + 1, self._block_end(head)):
            if _blank(self.lines[i]):
                continue
            if not self.lines[i].lstrip().startswith("- {"):
                raise Unsupported("a proposal not written on one line")
            items.append(i)
        return head, items

    def add(self, proposal: Proposal) -> None:
        line = f"{' ' * (self.fi + 2)}{proposal.line()}\n"
        head, items = self._items()
        if head is None:
            self.lines[self.end:self.end] = [f"{' ' * self.fi}proposed:\n", line]
            self.end += 2
        else:
            at = (items[-1] if items else head) + 1
            self.lines.insert(at, line)
            self.end += 1

    def _item(self, pid: str) -> int:
        _, items = self._items()
        for i in items:
            parsed = yaml.load(self.lines[i].strip(), Loader=vd.DeckLoader)
            if isinstance(parsed, list) and parsed and isinstance(parsed[0], dict) \
                    and parsed[0].get("id") == pid:
                return i
        raise Unsupported(f"proposal {pid} not found as one line")

    def replace(self, proposal: Proposal) -> None:
        i = self._item(proposal.id)
        self.lines[i] = f"{' ' * (self.fi + 2)}{proposal.line()}\n"

    def remove(self, pid: str) -> None:
        i = self._item(pid)
        del self.lines[i]
        self.end -= 1
        head, items = self._items()
        if head is not None and not items:
            del self.lines[head]
            self.end -= 1

    def save(self, check) -> None:
        """Writes the lines, if the file then reads as [check] expects of
        the entry: check(entry or None) is True."""
        text = "".join(self.lines)
        raw = yaml.load(text, Loader=vd.DeckLoader)
        found = [e for e in _entries_in(self.entry.path, raw)
                 if e.card == self.entry.card and e.form == self.entry.form]
        if len(found) != 1 or not check(found[0]):
            raise Unsupported("the edit did not read back as meant")
        others = [e for e in _entries_in(self.entry.path, raw) if e.card != self.entry.card]
        before = [e for e in _entries_in(self.entry.path, _load(self.entry.path))
                  if e.card != self.entry.card]
        if [(e.card, e.data) for e in others] != [(e.card, e.data) for e in before]:
            raise Unsupported("the edit changed another card")
        self.entry.path.write_text(text, encoding="utf-8")


# --- What the bot does ----------------------------------------------------------

@dataclass(frozen=True)
class Suggestion:
    """A suggested change from a review file, as a proposal to make."""
    lang: str
    deck: str
    proposal: Proposal


@dataclass
class Proposed:
    """What came of a review's suggestions and acceptances."""
    added: list[Proposal] = field(default_factory=list)
    already: list[Proposal] = field(default_factory=list)
    outdated: list[Proposal] = field(default_factory=list)
    unsupported: list[Proposal] = field(default_factory=list)
    accepted: list[tuple[str, str]] = field(default_factory=list)
    not_accepted: int = 0

    @property
    def changed(self) -> bool:
        return bool(self.added or self.accepted)


def _rank(entry: Entry, deck: str, lang: str) -> int:
    """How near [entry] is to the deck the review was of: its own file, its
    core, or another file of the language."""
    if entry.deck == deck:
        return 0
    m = re.fullmatch(rf"{re.escape(lang)}-[a-z]{{2,3}}-(.+)", deck)
    if m and entry.deck == f"{lang}-{m.group(1)}":
        return 1
    return 2


def home(root: Path, lang: str, deck: str, p: Proposal) -> Entry | None:
    """The entry a proposal goes on: the one nearest its deck that holds
    the field as the proposer saw it. None when none does: the card is
    gone, or the field has changed since."""
    found = [e for e in entries(root, lang, p.card)
             if e.may_change(p.field) and e.value(p.field) == p.now]
    return min(found, key=lambda e: _rank(e, deck, lang), default=None)


def propose(root: Path, suggestion: Suggestion, result: Proposed) -> None:
    p = suggestion.proposal
    if p.by in p.accepted or p.text == p.now or not p.text.strip():
        result.unsupported.append(p)
        return
    if find(root, suggestion.lang, p.id) is not None:
        result.already.append(p)
        return
    entry = home(root, suggestion.lang, suggestion.deck, p)
    if entry is None:
        result.outdated.append(p)
        return
    try:
        text = _Text(entry)
        text.add(p)
        text.save(lambda e: p in e.proposals())
    except Unsupported:
        result.unsupported.append(p)
        return
    result.added.append(p)


def accept(root: Path, lang: str, pid: str, code: str, text: str,
           result: Proposed) -> None:
    """Records [code]'s acceptance of [pid], if it is another reviewer's
    and of the same text, verbatim."""
    found = find(root, lang, pid)
    if found is None:
        result.not_accepted += 1
        return
    entry, p = found
    if code == p.by or code in p.accepted or text != p.text:
        result.not_accepted += 1
        return
    agreed = replace(p, accepted=(*p.accepted, code))
    try:
        edit = _Text(entry)
        edit.replace(agreed)
        edit.save(lambda e: agreed in e.proposals())
    except Unsupported:
        result.not_accepted += 1
        return
    result.accepted.append((pid, code))


@dataclass
class Applied:
    """What came of applying a proposal: "applied", "outdated", "missing" or
    "unsupported", and the proposals on the same field closed with it."""
    outcome: str
    proposal: Proposal | None = None
    closed: list[Proposal] = field(default_factory=list)


def apply(root: Path, lang: str, pid: str) -> Applied:
    """Writes proposal [pid]'s text into its field, if the field still says
    what the proposer saw, and removes it and every other proposal on that
    field of the card. Nothing is written otherwise."""
    found = find(root, lang, pid)
    if found is None:
        return Applied("missing")
    entry, p = found
    if not entry.may_change(p.field) or entry.value(p.field) != p.now:
        return Applied("outdated", p)
    rivals = [o for o in entry.proposals() if o.field == p.field and o.id != pid]
    try:
        edit = _Text(entry)
        edit.set_field(p.field, p.text)
        for o in (p, *rivals):
            edit.remove(o.id)
        edit.save(lambda e: e.value(p.field) == p.text
                  and not any(o.field == p.field for o in e.proposals()))
    except Unsupported:
        return Applied("unsupported", p)
    return Applied("applied", p, rivals)


def outdated(root: Path, lang: str) -> list[tuple[Entry, Proposal]]:
    """The proposals whose field no longer says what they were proposed
    against."""
    return [(e, p) for e, p in all_proposals(root, lang)
            if not e.may_change(p.field) or e.value(p.field) != p.now]


def close(root: Path, lang: str, pids: list[str]) -> list[Proposal]:
    """Removes the proposals [pids], untouched otherwise. Returns those
    removed."""
    closed = []
    for pid in pids:
        found = find(root, lang, pid)
        if found is None:
            continue
        entry, p = found
        try:
            edit = _Text(entry)
            edit.remove(pid)
            edit.save(lambda e: all(o.id != pid for o in e.proposals()))
        except Unsupported:
            continue
        closed.append(p)
    return closed


def languages(root: Path) -> list[str]:
    decks = root / "decks"
    return sorted(p.name for p in decks.iterdir()
                  if p.is_dir() and vd.LANG_RE.fullmatch(p.name))


# --- Who checked a card (#449) ------------------------------------------------
# A reviewer who marks a card "Looks right" signs it off. The bot adds their
# rater code to the card's `checked_by`, one line of the file, as it writes
# proposals: on its own line in a card written as a block, or at the end of
# a card written on one line in flow style. `tools/deck_index.py` leaves
# both out of the content hash, so learners are not offered an update for
# it. Once every card entry of a deck file lists a code, the file's tag
# `unreviewed` becomes `reviewed`, which learners do see.

_CHECKED_IN_FLOW = re.compile(r", checked_by: \[[^\]\n]*\](?= ?\}\s*$)")


def checked_line(codes: list[str] | tuple[str, ...]) -> str:
    """`checked_by: [...]`, as the bot writes it."""
    return f"checked_by: [{', '.join(_quoted(c) for c in codes)}]"


def checked_by(entry: Entry) -> list[str]:
    """The rater codes [entry] lists as having checked it."""
    codes = entry.data.get("checked_by")
    if not isinstance(codes, list):
        return []
    return [c for c in codes if isinstance(c, str)]


def _save_lines(entry: Entry, lines: list[str], check) -> None:
    """Writes [lines] to [entry]'s file, if it then reads as [check]
    expects of the entry and no other card has changed."""
    text = "".join(lines)
    try:
        raw = yaml.load(text, Loader=vd.DeckLoader)
    except yaml.YAMLError as error:
        raise Unsupported("the edit does not parse") from error
    found = [e for e in _entries_in(entry.path, raw)
             if e.card == entry.card and e.form == entry.form]
    if len(found) != 1 or not check(found[0]):
        raise Unsupported("the edit did not read back as meant")
    others = [(e.card, e.data) for e in _entries_in(entry.path, raw)
              if e.card != entry.card]
    before = [(e.card, e.data) for e in _entries_in(entry.path, _load(entry.path))
              if e.card != entry.card]
    if others != before:
        raise Unsupported("the edit changed another card")
    entry.path.write_text(text, encoding="utf-8")


def _flow_line(entry: Entry, lines: list[str]) -> int:
    """The line of [entry] written on one line in flow style: `- { id: … }`
    in a list, `"id": { … }` in a layer."""
    for i, line in enumerate(lines):
        if entry.card not in line or not line.rstrip().endswith("}"):
            continue
        try:
            parsed = yaml.load(line.strip(), Loader=vd.DeckLoader)
        except yaml.YAMLError:
            continue
        if entry.form in ("layer", "layer-own"):
            if isinstance(parsed, dict) and list(parsed) == [entry.card] \
                    and isinstance(parsed[entry.card], dict):
                return i
        elif isinstance(parsed, list) and len(parsed) == 1 \
                and isinstance(parsed[0], dict) \
                and parsed[0].get("ref" if entry.form in ("ref", "core-ref") else "id") \
                == entry.card:
            return i
    raise Unsupported("entry not found on one line")


def _write_checked(entry: Entry, codes: list[str]) -> None:
    """Writes [codes] as [entry]'s `checked_by`, one line."""
    def check(e: Entry) -> bool:
        return checked_by(e) == codes
    try:
        edit = _Text(entry)
    except Unsupported:
        edit = None
    if edit is not None:
        line = f"{' ' * edit.fi}{checked_line(codes)}\n"
        i = edit._key_line("checked_by")
        if i is not None:
            if edit._block_end(i) != i + 1:
                raise Unsupported("checked_by is written over several lines")
            edit.lines[i] = line
        else:
            # Last among the card's fields, before its proposals.
            j = edit._key_line("proposed")
            edit.lines.insert(j if j is not None else edit.end, line)
        _save_lines(entry, edit.lines, check)
        return
    lines = entry.path.read_text(encoding="utf-8").splitlines(keepends=True)
    i = _flow_line(entry, lines)
    body = lines[i].rstrip("\r\n")
    end = lines[i][len(body):]
    added = f", {checked_line(codes)}"
    if _CHECKED_IN_FLOW.search(body):
        body = _CHECKED_IN_FLOW.sub(added, body)
    elif "checked_by" in body:
        raise Unsupported("checked_by is not written as the bot writes it")
    else:
        stripped = body.rstrip()
        cut = len(stripped) - 1
        if stripped[cut - 1] == " ":
            cut -= 1
        body = stripped[:cut] + added + stripped[cut:]
    lines[i] = body + end
    _save_lines(entry, lines, check)


@dataclass
class Checks:
    """What came of a review's sign-offs: each (card, deck file) a code was
    added to, the cards it was on already, those not found in the deck, and
    those that cannot be written one line at a time. And the decks whose
    every card is now checked, tagged `reviewed`."""
    checked: list[tuple[str, str]] = field(default_factory=list)
    already: list[str] = field(default_factory=list)
    missing: list[str] = field(default_factory=list)
    unsupported: list[str] = field(default_factory=list)
    reviewed: list[str] = field(default_factory=list)
    touched: set[Path] = field(default_factory=set)

    @property
    def changed(self) -> bool:
        return bool(self.checked or self.reviewed)


def _core_of(root: Path, lang: str, deck: str) -> str | None:
    """The core of [deck], when it is a layer of [lang]."""
    for path in language_files(root, lang):
        if path.stem != deck:
            continue
        raw = _load(path)
        if isinstance(raw, dict) and raw.get("kind") == "layer" \
                and isinstance(raw.get("core"), str):
            return raw["core"]
    return None


def check(root: Path, lang: str, deck: str, card: str, code: str,
          result: Checks) -> None:
    """Adds [code] to the `checked_by` of [card] as deck [deck] has it: its
    entry in the deck's file, and for a layer its core's entry too, since
    a reviewer of the merged deck checked the word as well as the meaning.
    A code already there is not added again."""
    core = _core_of(root, lang, deck)
    found = [e for e in entries(root, lang, card)
             if e.deck == deck or (core is not None and e.deck == core)]
    if not found:
        result.missing.append(card)
        return
    added = False
    for e in found:
        # Looked at for its tag even when the code is on it already: the
        # file may be fully checked with its tag not yet changed.
        result.touched.add(e.path)
        have = checked_by(e)
        if code in have:
            continue
        try:
            _write_checked(e, [*have, code])
        except Unsupported:
            result.unsupported.append(card)
            continue
        result.checked.append((card, e.deck))
        added = True
    if not added and card not in result.unsupported:
        result.already.append(card)


def all_checked(path: Path) -> bool:
    """Whether every card entry of [path] lists a code in `checked_by`; a
    file with no card entries never is."""
    found = _entries_in(path, _load(path))
    return bool(found) and all(checked_by(e) for e in found)


_TAGS = re.compile(r"^tags[ \t]*:[ \t]*(\[.*\])[ \t]*(#.*)?$")


def mark_reviewed(path: Path) -> bool:
    """Tags [path] `reviewed` in place of `unreviewed`, its `tags` line
    written again and no other; adds the line, before `cards:`, to a file
    with no tags. False when it is reviewed already or cannot be edited
    one line at a time."""
    raw = _load(path)
    if not isinstance(raw, dict):
        return False
    tags = raw.get("tags", [])
    if not isinstance(tags, list) or not all(isinstance(t, str) for t in tags):
        return False
    if "reviewed" in tags and "unreviewed" not in tags:
        return False
    new: list[str] = []
    for t in tags:
        t = "reviewed" if t == "unreviewed" else t
        if t not in new:
            new.append(t)
    if "reviewed" not in new:
        new.append("reviewed")
    line = f"tags: [{', '.join(_quoted(t) for t in new)}]"
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    at = [i for i, l in enumerate(lines) if _TAGS.match(l.rstrip("\r\n"))]
    if "tags" in raw:
        if len(at) != 1:
            return False
        comment = _TAGS.match(lines[at[0]].rstrip("\r\n")).group(2)
        lines[at[0]] = line + (f"  {comment}" if comment else "") + "\n"
    else:
        cards = next((i for i, l in enumerate(lines)
                      if re.match(r"^cards\s*:", l)), None)
        if cards is None:
            return False
        lines.insert(cards, line + "\n")
    text = "".join(lines)
    after = yaml.load(text, Loader=vd.DeckLoader)
    if not isinstance(after, dict) or after.get("tags") != new:
        return False
    rest = {k: v for k, v in after.items() if k != "tags"}
    if rest != {k: v for k, v in raw.items() if k != "tags"}:
        return False
    path.write_text(text, encoding="utf-8")
    return True


def review_done(result: Checks) -> None:
    """Tags `reviewed` each file [result] touched whose every card is now
    checked. A core and its layer are tagged each on its own, and the
    merged deck reads as reviewed only once both are."""
    for path in sorted(result.touched):
        if all_checked(path) and mark_reviewed(path):
            raw = _load(path)
            result.reviewed.append(raw.get("id") if isinstance(raw, dict)
                                   and isinstance(raw.get("id"), str) else path.stem)
