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
import unicodedata
import sys
from dataclasses import dataclass, field, replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks as vd  # noqa: E402
import yaml  # noqa: E402

# The part of a card a review's suggestion names (lib/core/review/
# deck_review.dart, CardPart) and the field it is in the deck. An example
# or a picture is left for the owner. A base (`base`, #476) and the
# accepted alternatives (`alt`, "Also heard") are read by the review bot
# into the fields BASES and ALT below.
FIELD_OF_PART = {
    "word": "target",
    "reading": "reading",
    "ipa": "ipa",
    "meaning": "native",
    "notes": "notes",
    "place": "place",
    # The card's scalars (#508): the bot writes these four, each with a
    # fixed set of values (see value_error). The lists, the facts and the
    # flags stay with the owner.
    "gender": "gender",
    "register": "register",
    "hears": "hears",
    "warning": "warning",
}
# The order fields are written in, for a field the card did not have.
FIELD_ORDER = ("id", "ref", "target", "reading", "ipa", "alt_target", "native")

# A proposal on one of a card's base words (#476): its `now` is the base as
# it is, and its `text` the base as proposed, each one line of JSON (see
# base_text), "" for none: an add has no `now`, a removal no `text`. The
# base is named by its `word`, the word as it stands in the target, so a
# card can have one proposal a base, and rivals are on the same word.
BASES = "bases"
# A proposal on the accepted alternatives, `alt_target`: its `now` and
# `text` are the lists as one line of JSON (see alt_text).
ALT = "alt_target"
# A proposal on where a card belongs (#477): its `now` is the core id of the
# deck that holds the card, its `text` the core id of the deck it is moved
# to, a deck the language's path lists (the review file may name the course's
# decks, `hi-en-home`, which the bot reads as their cores). Written on the
# card's entry in its core, and applied by moving the entry, with its layers'
# entries, to the end of the target's files, its id kept.
PLACE = "place"
# The fields whose value is one of a fixed set (#508).
FIXED_FIELDS = ("gender", "register", "hears", "warning")
# The keys of a base in a proposal, in the order they are written.
BASE_ORDER = ("word", "ref", "base", "reading", "meaning")


def base_text(base: dict | None) -> str:
    """[base] as a proposal's `now` or `text`: one line of JSON with the
    keys of BASE_ORDER that it has as text, in that order; "" for none."""
    if not base:
        return ""
    kept = {k: base[k].strip() for k in BASE_ORDER
            if isinstance(base.get(k), str) and base[k].strip()}
    if "ref" in kept:
        kept = {"word": kept.get("word", ""), "ref": kept["ref"]}
    return json.dumps(kept, ensure_ascii=False)


def read_base(text: str) -> dict | None:
    """A base as base_text writes it, or None: "" or not a base, which has
    its word and either a ref or a base form."""
    if not text:
        return None
    try:
        base = json.loads(text)
    except ValueError:
        return None
    if not isinstance(base, dict) or not isinstance(base.get("word"), str) \
            or not base["word"].strip():
        return None
    if not isinstance(base.get("ref"), str) and not isinstance(base.get("base"), str):
        return None
    return base


def base_word(p: Proposal) -> str | None:
    """The word of the target [p], a proposal on a base, is about."""
    found = read_base(p.text) or read_base(p.now)
    return found["word"] if found else None


def alt_text(items: object) -> str:
    """A card's `alt_target`, as a proposal on it says it: a JSON list of
    text, "[]" for none."""
    items = items if isinstance(items, list) else []
    return json.dumps([i for i in items if isinstance(i, str)], ensure_ascii=False)


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
    # The id of the change to the card's word this one came with (#476),
    # or "": it is applied with that word, in its PR, once the word is
    # agreed, and never on its own. Not one of the facts the id is made of.
    tied: str = ""

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
        if self.tied:
            parts.append(f"with: {q(self.tied)}")
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
        tied = item.get("with", "")
        accepted = item.get("accepted", [])
        if not isinstance(why, str) or not isinstance(accepted, list) \
                or not isinstance(tied, str) \
                or not all(isinstance(a, str) for a in accepted):
            return None
        p = Proposal(card, *values, why=why, accepted=tuple(accepted), tied=tied)
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
        if name == BASES:
            # A card that is its own root (`bases: "self"`) has none to
            # change; nor does a layer's entry for a core it cannot find.
            return isinstance(self.data.get("bases"), (list, dict, type(None)))
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


# --- A card's bases, as a proposal sees them (#476) -------------------------

def core_entry(root: Path, lang: str, entry: Entry) -> Entry | None:
    """The entry that writes [entry]'s bases: itself, or for a layer's entry
    its core's card, written there in full."""
    if entry.form in ("single", "layer-own", "core"):
        return entry
    if entry.form != "layer" or entry.core is None:
        return None
    return next((e for e in entries(root, lang, entry.card)
                 if e.deck == entry.core and e.form == "core"), None)


def _layer_meaning(entry: Entry, word: str) -> str | None:
    found = entry.data.get("bases")
    value = found.get(word) if isinstance(found, dict) else None
    if isinstance(value, dict):
        value = value.get("meaning")
    return value if isinstance(value, str) else None


def base_of(root: Path, lang: str, entry: Entry, word: str) -> dict | None:
    """[entry]'s base for [word] as one dict: its core's item, and for a
    layer the meaning the layer gives it. None when it has none."""
    core = core_entry(root, lang, entry)
    items = core.data.get("bases") if core is not None else None
    if not isinstance(items, list):
        return None
    item = next((b for b in items if isinstance(b, dict) and b.get("word") == word), None)
    if item is None:
        return None
    base = dict(item)
    if entry.form == "layer" and "ref" not in base:
        meaning = _layer_meaning(entry, word)
        base.pop("meaning", None)
        if meaning is not None:
            base["meaning"] = meaning
    return base


def now_of(root: Path, lang: str, entry: Entry, p: Proposal) -> str:
    """What [p]'s field says on [entry] now, as a proposal says it."""
    if p.field == BASES:
        word = base_word(p)
        return base_text(base_of(root, lang, entry, word)) if word else ""
    if p.field == ALT:
        return alt_text(entry.data.get(ALT))
    if p.field == PLACE:
        return entry.deck if entry.form == "core" else ""
    value = entry.value(p.field)
    return value if isinstance(value, str) else ""


def genders_of(root: Path, lang: str) -> list[str]:
    """The gender classes the language's path lists, `[]` for a language
    without gender or a path that lists none."""
    raw = _load(root / "decks" / lang / f"{lang}-path.yaml")
    classes = raw.get("genders") if isinstance(raw, dict) else None
    return [c for c in classes if isinstance(c, str)] if isinstance(classes, list) else []


def warning_choices(entry: Entry) -> list[str]:
    """What the card's `warning` may be (#691): the id of each of its pair,
    homograph and lookalike notes (a note with no id by its place, "1",
    "2"), `senses` when the card has senses, and `none`."""
    choices = []
    notes = entry.data.get("notes")
    for i, note in enumerate(notes if isinstance(notes, list) else []):
        if isinstance(note, dict) and note.get("kind") in vd.REF_NOTE_KINDS:
            nid = note.get("id")
            choices.append(str(i + 1) if nid is None else str(nid))
    senses = entry.data.get("senses")
    if isinstance(senses, list) and senses:
        choices.append("senses")
    return [*choices, "none"]


def value_error(root: Path, lang: str, entry: Entry, name: str, text: str) -> str | None:
    """Why [text] may not be written as [entry]'s [name], or None. Only the
    fixed-value fields have a rule: a gender is one of the language's
    classes, a register one of the five, `hears` is `form`, and a warning
    names a warning the card has. The text of any other field is free."""
    if name == "gender":
        classes = genders_of(root, lang)
        if text not in classes:
            return (f"gender {text!r} is not one of the language's classes "
                    f"({', '.join(classes) or 'none: the language has no gender'})")
    elif name in vd.PROPOSAL_VALUES and text not in vd.PROPOSAL_VALUES[name]:
        return f"{name} must be one of {', '.join(vd.PROPOSAL_VALUES[name])}, got {text!r}"
    elif name == "warning" and text not in warning_choices(entry):
        return f"warning {text!r} is not one of {', '.join(warning_choices(entry))}"
    return None


def holds(root: Path, lang: str, entry: Entry, p: Proposal) -> bool:
    """Whether [p] can go on [entry]: the entry may change its field, and
    the field says what the proposer saw."""
    return entry.may_change(p.field) and now_of(root, lang, entry, p) == p.now


def rivals_of(entry: Entry, p: Proposal) -> list[Proposal]:
    """The other proposals on [entry] that change what [p] changes: its
    field, and for a base, the same word."""
    word = base_word(p) if p.field == BASES else None
    return [o for o in entry.proposals() if o.field == p.field and o.id != p.id
            and (p.field != BASES or base_word(o) == word)]


def card_for_form(root: Path, lang: str, form: str, card: str) -> str | None:
    """The one card of [lang] other than [card] whose word is [form], or
    None: no card, or several."""
    want = unicodedata.normalize("NFC", form.strip())
    found = {e.card for e in entries(root, lang)
             if e.form in ("single", "core", "layer-own") and e.card != card
             and isinstance(e.data.get("target"), str)
             and unicodedata.normalize("NFC", e.data["target"].strip()) == want}
    return found.pop() if len(found) == 1 else None


def card_exists(root: Path, lang: str, card: str) -> bool:
    return any(e.form in ("single", "core", "layer-own")
               for e in entries(root, lang, card))


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
        self._set_line(name, _quoted(text))

    def set_list(self, name: str, items: list[str]) -> None:
        """Field [name] as a list of text on one line, `name: ["a", "b"]`;
        removed when [items] is empty."""
        if items:
            self._set_line(name, f"[{', '.join(_quoted(i) for i in items)}]")
            return
        i = self._key_line(name)
        if i is not None:
            if self._block_end(i) != i + 1:
                raise Unsupported(f"{name} is written over several lines")
            del self.lines[i]
            self.end -= 1

    def _set_line(self, name: str, rendered: str) -> None:
        line = f"{' ' * self.fi}{name}: {rendered}\n"
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

    # A field written as a block of one-line items: a card's `bases` list
    # (`- { word: … }`) or a layer's `bases` mapping (`"word": "meaning"`).

    def _block(self, name: str) -> tuple[int | None, list[int]]:
        """The line of field [name] and its item lines. Unsupported when
        the field is written on its own line ("self", a flow list)."""
        head = self._key_line(name)
        if head is None:
            return None, []
        bare = re.compile(rf"^ {{{self.fi}}}[\"']?{re.escape(name)}[\"']?\s*:\s*(#.*)?$")
        if not bare.match(self.lines[head].rstrip("\r\n")):
            raise Unsupported(f"{name} is not written as a block")
        return head, [i for i in range(head + 1, self._block_end(head))
                      if not _blank(self.lines[i])]

    def _parsed(self, i: int) -> object:
        try:
            return yaml.load(self.lines[i].strip(), Loader=vd.DeckLoader)
        except yaml.YAMLError as error:
            raise Unsupported("an item not written on one line") from error

    def _new_block(self, name: str, item: str) -> None:
        """Adds field [name] with its one [item] line, last among the
        card's fields, before who checked it and its proposals."""
        at = [i for i in (self._key_line("checked_by"), self._key_line("proposed"))
              if i is not None]
        where = min(at) if at else self.end
        self.lines[where:where] = [f"{' ' * self.fi}{name}:\n",
                                   f"{' ' * (self.fi + 2)}{item}\n"]
        self.end += 2

    def _set_item(self, name: str, i: int | None, items: list[int], head: int | None,
                  item: str | None) -> None:
        if item is None:
            if i is None:
                return
            del self.lines[i]
            self.end -= 1
            if len(items) == 1:
                del self.lines[head]
                self.end -= 1
        elif i is not None:
            self.lines[i] = f"{' ' * _indent(self.lines[i])}{item}\n"
        elif head is not None:
            indent = _indent(self.lines[items[0]]) if items else self.fi + 2
            self.lines.insert((items[-1] if items else head) + 1, f"{' ' * indent}{item}\n")
            self.end += 1
        else:
            self._new_block(name, item)

    def set_base(self, word: str, item: str | None) -> None:
        """The card's base for [word] written as [item], one line
        `- { word: … }`, in place of the one there or added last; removed
        when [item] is None, with `bases:` once it has none."""
        head, items = self._block(BASES)
        found = None
        for i in items:
            parsed = self._parsed(i)
            if not (isinstance(parsed, list) and len(parsed) == 1
                    and isinstance(parsed[0], dict)):
                raise Unsupported("a base not written on one line")
            if parsed[0].get("word") == word:
                found = i
        self._set_item(BASES, found, items, head, item)

    def set_meaning(self, word: str, meaning: str | None, keep_mark: bool = False) -> None:
        """A layer's meaning for the base [word], `"word": "meaning"`, in
        place of the one there or added last; removed when None. One
        written as `{ meaning, wiktionary }` stays so, its Wiktionary mark
        kept when [keep_mark] says the base's form and reading are."""
        head, items = self._block(BASES)
        found = None
        old = None
        for i in items:
            parsed = self._parsed(i)
            if not (isinstance(parsed, dict) and len(parsed) == 1):
                raise Unsupported("a base's meaning not written on one line")
            if word in parsed:
                found, old = i, parsed[word]
        if meaning is None:
            item = None
        elif isinstance(old, dict):
            fields = [f"meaning: {_quoted(meaning)}"]
            if keep_mark and isinstance(old.get("wiktionary"), bool):
                fields.append(f"wiktionary: {'true' if old['wiktionary'] else 'false'}")
            item = f"{_quoted(word)}: {{ {', '.join(fields)} }}"
        else:
            item = f"{_quoted(word)}: {_quoted(meaning)}"
        self._set_item(BASES, found, items, head, item)

    def ready(self, check) -> str:
        """The file's text with the edits, if it reads as [check] expects of
        the entry and no other card has changed."""
        text = "".join(self.lines)
        try:
            raw = yaml.load(text, Loader=vd.DeckLoader)
        except yaml.YAMLError as error:
            raise Unsupported("the edit does not parse") from error
        found = [e for e in _entries_in(self.entry.path, raw)
                 if e.card == self.entry.card and e.form == self.entry.form]
        if len(found) != 1 or not check(found[0]):
            raise Unsupported("the edit did not read back as meant")
        others = [e for e in _entries_in(self.entry.path, raw) if e.card != self.entry.card]
        before = [e for e in _entries_in(self.entry.path, _load(self.entry.path))
                  if e.card != self.entry.card]
        if [(e.card, e.data) for e in others] != [(e.card, e.data) for e in before]:
            raise Unsupported("the edit changed another card")
        return text

    def save(self, check) -> None:
        """Writes the lines, if the file then reads as [check] expects of
        the entry: check(entry or None) is True."""
        self.entry.path.write_text(self.ready(check), encoding="utf-8")


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
    found = [e for e in entries(root, lang, p.card) if holds(root, lang, e, p)]
    return min(found, key=lambda e: _rank(e, deck, lang), default=None)


def _meaning_only(root: Path, lang: str, deck: str, p: Proposal) -> Proposal:
    """[p] as a review file from before #476 has it, a change to the
    meaning of the base for a word only, `{"word", "meaning"}` on each
    side, with the rest of that base filled in from the entry nearest
    [deck] whose base for the word has that meaning. [p] as it is when it
    is not one, or no entry has the base."""
    try:
        old, new = json.loads(p.now), json.loads(p.text)
    except ValueError:
        return p
    if not all(isinstance(b, dict) and set(b) == {"word", "meaning"}
               and all(isinstance(v, str) for v in b.values()) for b in (old, new)):
        return p
    if not new["meaning"].strip():
        # No meaning to write: left for the owner, never a base without one.
        return p
    found = []
    for e in entries(root, lang, p.card):
        base = base_of(root, lang, e, old["word"]) if e.may_change(BASES) else None
        if base and "ref" not in base and base.get("meaning") == old["meaning"]:
            found.append((_rank(e, deck, lang), base))
    if not found:
        return p
    base = min(found, key=lambda f: f[0])[1]
    return replace(p, now=base_text(base),
                   text=base_text({**base, "meaning": new["meaning"]}))


def resolve_base(root: Path, lang: str, p: Proposal, deck: str = "") -> Proposal | None:
    """[p], a proposal on a base, as it is written: its `now` and `text` as
    base_text writes them, and an added base whose form is the word of one
    other card of the language given as a `ref` to it, unless the reviewer
    chose not to link it (`"link": false`). None when it is not a good one:
    no base on either side, the same on both, or a ref to no card or to the
    card itself."""
    p = _meaning_only(root, lang, deck, p)
    old, new = read_base(p.now), read_base(p.text)
    if (p.now and old is None) or (p.text and new is None) or (old is None and new is None):
        return None
    if old is not None and new is not None and old["word"] != new["word"]:
        return None
    if old is None and new is not None and not isinstance(new.get("ref"), str) \
            and new.get("link") is not False:
        ref = card_for_form(root, lang, new["base"], p.card)
        if ref is not None:
            new = {"word": new["word"], "ref": ref}
    if new is not None and isinstance(new.get("ref"), str) \
            and (new["ref"] == p.card or not card_exists(root, lang, new["ref"])):
        return None
    now, text = base_text(old), base_text(new)
    if now == text:
        return None
    return replace(p, now=now, text=text)


def propose(root: Path, suggestion: Suggestion, result: Proposed) -> None:
    p = suggestion.proposal
    if p.tied and find(root, suggestion.lang, p.tied) is None:
        # Its change to the word was not proposed: the card has changed
        # since, or the same word was proposed already by another.
        result.outdated.append(p)
        return
    if p.field == BASES:
        written = resolve_base(root, suggestion.lang, p, suggestion.deck)
        if written is None or p.by in p.accepted:
            result.unsupported.append(p)
            return
        p = written
    elif p.field == PLACE:
        written = resolve_place(root, suggestion.lang, p)
        if written is None or p.by in p.accepted:
            result.unsupported.append(p)
            return
        p = written
    elif p.by in p.accepted or p.text == p.now or not p.text.strip():
        result.unsupported.append(p)
        return
    if find(root, suggestion.lang, p.id) is not None:
        result.already.append(p)
        return
    entry = home(root, suggestion.lang, suggestion.deck, p)
    if entry is None:
        result.outdated.append(p)
        return
    if p.field in FIXED_FIELDS and value_error(
            root, suggestion.lang, entry, p.field, p.text):
        # A value the field may not have is never written, and not outdated:
        # it was never good.
        result.unsupported.append(p)
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
    entry: Entry | None = None


def apply(root: Path, lang: str, pid: str) -> Applied:
    """Writes proposal [pid]'s text into its field, if the field still says
    what the proposer saw, and removes it and every other proposal on that
    field of the card. Nothing is written otherwise."""
    found = find(root, lang, pid)
    if found is None:
        return Applied("missing")
    entry, p = found
    if not holds(root, lang, entry, p):
        return Applied("outdated", p)
    if p.field in FIXED_FIELDS and value_error(root, lang, entry, p.field, p.text):
        return Applied("unsupported", p)
    rivals = rivals_of(entry, p)
    gone = {o.id for o in (p, *rivals)}
    try:
        if p.field == BASES:
            _apply_base(root, lang, entry, p, gone)
        elif p.field == PLACE:
            _apply_place(root, lang, entry, p, gone)
        else:
            edit = _Text(entry)
            if p.field == ALT:
                edit.set_list(ALT, json.loads(p.text))
            else:
                edit.set_field(p.field, p.text)
            for o in gone:
                edit.remove(o)
            edit.save(lambda e: now_of(root, lang, e, p) == p.text
                      and not any(o.id in gone for o in e.proposals()))
    except (Unsupported, ValueError):
        return Applied("unsupported", p)
    return Applied("applied", p, rivals, entry)


# --- Where a card belongs (#477) -------------------------------------------------

def _deck_file(root: Path, lang: str, deck: str) -> tuple[Path, dict] | None:
    """The file of [lang] whose `id` is [deck], and what it loads as."""
    for path in language_files(root, lang):
        raw = _load(path)
        if isinstance(raw, dict) and raw.get("id") == deck:
            return path, raw
    return None


def core_deck(root: Path, lang: str, deck: str) -> str | None:
    """The core id of [deck], which is a core's own id or a layer's course
    deck, `hi-en-home` for `hi-home`; None when the language has no such
    deck."""
    found = _deck_file(root, lang, deck)
    if found is None:
        return None
    raw = found[1]
    if raw.get("kind") == "layer":
        return raw["core"] if isinstance(raw.get("core"), str) else None
    return deck


def plan_decks(root: Path, lang: str) -> set[str]:
    """The core ids of the decks the language's path lists in its units,
    without the wildcard and without the script decks: where a card may be
    moved to. Empty when the language has no path."""
    raw = _load(root / "decks" / lang / f"{lang}-path.yaml")
    if not isinstance(raw, dict) or not isinstance(raw.get("units"), list):
        return set()
    alphabet = raw.get("alphabet")
    skip = set(alphabet) if isinstance(alphabet, list) else set()
    return {d for u in raw["units"] if isinstance(u, dict)
            and isinstance(u.get("decks"), list)
            for d in u["decks"] if isinstance(d, str) and d != "*" and d not in skip}


def resolve_place(root: Path, lang: str, p: Proposal) -> Proposal | None:
    """[p], a proposal on where a card belongs, with its `now` and `text`
    as the core ids of the decks. None when it is not a good one: a deck
    the language does not have, a target its path does not list (a new
    theme or unit goes by pull request), a core that is not a deck of the
    same kind as the card's, or the deck the card is in."""
    now, text = core_deck(root, lang, p.now), core_deck(root, lang, p.text)
    if now is None or text is None or now == text or text not in plan_decks(root, lang):
        return None
    src, tgt = _deck_file(root, lang, now), _deck_file(root, lang, text)
    if src is None or tgt is None:
        return None
    if tgt[1].get("part") != "core" or src[1].get("part") != "core" \
            or tgt[1].get("kind") != src[1].get("kind"):
        return None
    return replace(p, now=now, text=text)


def _cards_end(lines: list[str]) -> int:
    """The line after the last card of a file whose `cards:` block ends
    where the file does or is followed by another key."""
    top = next((i for i, l in enumerate(lines) if re.match(r"^cards\s*:\s*$", l)), None)
    if top is None:
        raise Unsupported("no block `cards:`")
    end = top + 1
    while end < len(lines) and (_blank(lines[end]) or _indent(lines[end]) > 0):
        end += 1
    while end > top + 1 and _blank(lines[end - 1]):
        end -= 1
    return end


def _first_indent(lines: list[str]) -> int:
    top = next((i for i, l in enumerate(lines) if re.match(r"^cards\s*:\s*$", l)), None)
    first = next((i for i in range(top + 1, len(lines)) if not _blank(lines[i])), None) \
        if top is not None else None
    if first is None:
        raise Unsupported("no cards")
    return _indent(lines[first])


def _apply_place(root: Path, lang: str, entry: Entry, p: Proposal, gone: set[str]) -> None:
    """Moves the card of [entry], a core's, to the end of the core [p] names,
    and its layer's entry in each native language to the end of that
    core's layer in the same one, the card's id and every other line of it
    kept; [gone] proposals are dropped. All or nothing."""
    if entry.form != "core" or p.text not in plan_decks(root, lang):
        raise Unsupported("not a card of a core, or a deck the path does not list")
    tgt = _deck_file(root, lang, p.text)
    if tgt is None or tgt[1].get("part") != "core" \
            or tgt[1].get("kind") != _load(entry.path).get("kind"):
        raise Unsupported("the target is not a core of the same kind")
    if sum(1 for e in _entries_in(entry.path, _load(entry.path))) < 2:
        raise Unsupported("it is the last card of its deck")
    # (file, entry in it) of each file the card is in, and where it goes.
    moves: list[tuple[Entry, Path]] = [(entry, tgt[0])]
    for path in language_files(root, lang):
        raw = _load(path)
        if not (isinstance(raw, dict) and raw.get("kind") == "layer"
                and raw.get("core") == entry.deck):
            continue
        mine = next((e for e in _entries_in(path, raw) if e.card == entry.card), None)
        if mine is None:
            continue
        native = (raw.get("native") or {}).get("code") if isinstance(raw.get("native"), dict) else None
        dest = next((f for f, r in ((f, _load(f)) for f in language_files(root, lang))
                     if isinstance(r, dict) and r.get("kind") == "layer"
                     and r.get("core") == p.text and isinstance(r.get("native"), dict)
                     and r["native"].get("code") == native), None)
        if dest is None:
            raise Unsupported(f"no {native} layer for the target")
        moves.append((mine, dest))
    texts: dict[Path, list[str]] = {}
    for e, dest in moves:
        src = _Text(e)
        for o in gone if e is entry else ():
            src.remove(o)
        block = src.lines[src.start:src.end]
        lines = texts.setdefault(e.path, src.lines)
        if lines is not src.lines:
            raise Unsupported("a file holds the card twice")
        del lines[src.start:src.end]
        out = texts.get(dest)
        if out is None:
            out = texts[dest] = dest.read_text(encoding="utf-8").splitlines(keepends=True)
        if _first_indent(out) != _indent(block[0]):
            raise Unsupported("the files indent their cards differently")
        at = _cards_end(out)
        if at and not out[at - 1].endswith("\n"):
            out[at - 1] += "\n"
        out[at:at] = block
    before = {path: _entries_in(path, _load(path)) for path in texts}
    parsed = {}
    for path, lines in texts.items():
        try:
            parsed[path] = _entries_in(path, yaml.load("".join(lines), Loader=vd.DeckLoader))
        except yaml.YAMLError as error:
            raise Unsupported("the move does not parse") from error
    for path, after in parsed.items():
        was = {(e.card, e.form): e.data for e in before[path]}
        now = {(e.card, e.form): e.data for e in after}
        if any(was[k] != now[k] for k in was.keys() & now.keys() if k[0] != entry.card) \
                or len([k for k in now if k[0] == entry.card]) > 1 \
                or {k for k in was if k[0] != entry.card} != {k for k in now if k[0] != entry.card}:
            raise Unsupported("the move changed another card")
    moved = [(a, [e for e in parsed[a] if e.card == entry.card]) for a in parsed]
    sources = {e.path for e, _ in moves}
    if any(bool(found) == (path in sources) for path, found in moved):
        raise Unsupported("the move did not read back as meant")
    for path, lines in texts.items():
        path.write_text("".join(lines), encoding="utf-8")


def _base_item(old: dict | None, new: dict, written_meaning: bool) -> dict:
    """The core's item for the base [new], from the base it replaces: its
    IPA and Wiktionary mark kept while its form and reading are."""
    if isinstance(new.get("ref"), str):
        return {"word": new["word"], "ref": new["ref"]}
    item = {"word": new["word"], "base": new["base"]}
    if new.get("reading"):
        item["reading"] = new["reading"]
    same = old is not None and old.get("base") == new["base"] \
        and old.get("reading") == new.get("reading")
    if same and isinstance(old.get("ipa"), str):
        item["ipa"] = old["ipa"]
    if written_meaning and new.get("meaning"):
        item["meaning"] = new["meaning"]
    if written_meaning and same and isinstance(old.get("wiktionary"), bool):
        item["wiktionary"] = old["wiktionary"]
    return item


def _flow(item: dict) -> str:
    """[item] as one line of a list, `- { word: "…", … }`, its text quoted."""
    def value(v: object) -> str:
        return ("true" if v else "false") if isinstance(v, bool) else _quoted(str(v))
    return "- { " + ", ".join(f"{k}: {value(v)}" for k, v in item.items()) + " }"


def _item_of(e: Entry, word: str) -> dict | None:
    items = e.data.get("bases")
    if not isinstance(items, list):
        return None
    return next((b for b in items if isinstance(b, dict) and b.get("word") == word), None)


def _apply_base(root: Path, lang: str, entry: Entry, p: Proposal, gone: set[str]) -> None:
    """Writes [p], a proposal on a base, line by line: the core's item and,
    for a layer, its meaning there. A base removed, or now given by ref,
    loses its meaning in every layer of the core, which would otherwise
    name a base the core no longer writes in full. Every file is checked
    before any is written."""
    old, new = read_base(p.now), read_base(p.text)
    word = (new or old)["word"]
    core = core_entry(root, lang, entry)
    if core is None:
        raise Unsupported("the card's core entry is not found")
    split = entry.form == "layer"
    item = None if new is None else _base_item(_item_of(core, word), new, not split)
    line = None if item is None else _flow(item)
    meaning = new.get("meaning") if new is not None and item is not None \
        and "ref" not in item else None
    edits: list[tuple[_Text, object]] = []
    own = _Text(entry)
    if split:
        core_edit = _Text(core)
        core_edit.set_base(word, line)
        edits.append((core_edit, lambda e: _item_of(e, word) == item))
        was = _item_of(core, word)
        same = was is not None and item is not None and "ref" not in item \
            and was.get("base") == item.get("base") \
            and was.get("reading") == item.get("reading")
        own.set_meaning(word, meaning, keep_mark=same)
        if meaning is None:
            for other in entries(root, lang, entry.card):
                if other.form == "layer" and other.core == entry.core \
                        and other.path != entry.path \
                        and _layer_meaning(other, word) is not None:
                    edit = _Text(other)
                    edit.set_meaning(word, None)
                    edits.append((edit, lambda e: _layer_meaning(e, word) is None))
    else:
        own.set_base(word, line)
    for o in gone:
        own.remove(o)

    def done(e: Entry) -> bool:
        if any(o.id in gone for o in e.proposals()):
            return False
        if split:
            return _layer_meaning(e, word) == meaning
        return _item_of(e, word) == item
    edits.insert(0, (own, done))
    texts = [(edit.entry.path, edit.ready(check)) for edit, check in edits]
    for path, text in texts:
        path.write_text(text, encoding="utf-8")


def fill(entry: Entry, values: dict[str, str]) -> bool:
    """Writes [values], field to text, into [entry]'s card, line by line as
    apply does: the reading and IPA worked out for a changed word (#468).
    False, with nothing written, when a field may not change here or the
    edit cannot be made one line at a time."""
    if not values or not all(entry.may_change(n) for n in values):
        return False
    try:
        edit = _Text(entry)
        for name, text in values.items():
            edit.set_field(name, text)
        edit.save(lambda e: all(e.value(n) == t for n, t in values.items()))
    except Unsupported:
        return False
    return True


def outdated(root: Path, lang: str) -> list[tuple[Entry, Proposal]]:
    """The proposals whose field no longer says what they were proposed
    against, and those tied to a change to the word that is gone (#476)."""
    found = all_proposals(root, lang)
    ids = {p.id for _, p in found}
    return [(e, p) for e, p in found
            if not holds(root, lang, e, p) or (p.tied and p.tied not in ids)]


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
