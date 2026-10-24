#!/usr/bin/env python3
"""Pick the one warning a word's teach card shows (#691; owner, 2026-10-23:
"Deck field picks it"; "Rude words should only come up as warning if it is
very close and very rude. Otherwise, sounds alike or some other one should
appear, if two fields are equally important, then at random").

A core card's `warning` names one of its warnings: the id of a `pair`,
`homograph` or `lookalike` note (a note without an id is named by its place,
"1", "2"), `"senses"` for its other meanings, or `"none"` when its only
warning is a rude word that does not qualify. The word sheet still shows
every warning; the field picks the teach card's.

Each warning gets an importance; the most important wins, and equals are
drawn at random, seeded by the card id so that a second run picks the same:

- 4: a sound-alike that is rude, very close and very rude: its IPA differs
  by at most one segment, and its partner's `level` is strong or strongest.
- 3: a sound-alike or look-alike that is very close (at most one segment of
  IPA, or one letter or mark of spelling, apart), and every homograph.
- 2: one further apart, or two or more other meanings.
- 1: a single other meaning.
- 0: a rude sound-alike that does not qualify, never picked.

A card with no warning gets no field. One that has it is left, and a
different pick is reported. Released apps reject a card key they do not
know, so the field goes to the decks a release after the app reads it:

    python3 tools/pick_warning.py decks/            # report
    python3 tools/pick_warning.py decks/ --write    # rewrite

Only the repository's block style is edited, a card found by its `- id:`
line.
"""

from __future__ import annotations

import argparse
import random
import re
import sys
import unicodedata
from pathlib import Path

import yaml

_ID = re.compile(r'^(?P<ind>\s*)- id:\s*["\']?(?P<id>[^"\'\s]+)["\']?\s*$')
_KEY = re.compile(r"^(?P<ind>\s+)(?P<key>[a-z_]+):")
_VALUE = re.compile(r'^(?P<ind>\s+)(?P<key>[a-z_]+):\s*["\']?(?P<value>[^"\'\s#]*)["\']?\s*$')

RUDE = "offensive"
VERY_RUDE = ("strong", "strongest")
ALIKE = ("pair", "homograph", "lookalike")

# Marks that carry no segment of their own: stress, syllable and word breaks.
_DROP = set("ˈˌ.‿ ")
# Joined to the segment before: length and the modifier letters.
_JOIN = set("ːˑʰʱʲʷˠˤⁿˡʼ")
_TIES = set("͜͡")


def segments(ipa: str) -> list[str]:
    """[ipa] as segments: a letter with its diacritics, length and modifier
    letters, and a tied pair as one."""
    out: list[str] = []
    tie = False
    for ch in unicodedata.normalize("NFD", ipa):
        if ch in _DROP:
            continue
        if ch in _TIES:
            tie = True
            if out:
                out[-1] += ch
            continue
        if out and (tie or ch in _JOIN or unicodedata.combining(ch)):
            out[-1] += ch
            tie = False
            continue
        out.append(ch)
    return out


def letters(text: str) -> list[str]:
    """[text] as code points, decomposed, so that a dot or a mark is one."""
    return [ch for ch in unicodedata.normalize("NFD", text) if not ch.isspace()]


def distance(a: list[str], b: list[str]) -> int:
    """The edit distance between two lists."""
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        cur = [i]
        for j, y in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
        prev = cur
    return prev[-1]


Index = dict[str, tuple[dict, list]]


def index(root: Path) -> Index:
    """Every core card under [root] by id, with its deck's tags."""
    found: Index = {}
    for path in sorted(root.glob("*/*.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict) or not isinstance(data.get("cards"), list):
            continue
        tags = list(data.get("tags") or [])
        for card in data["cards"]:
            if isinstance(card, dict) and isinstance(card.get("id"), str):
                found[card["id"]] = (card, tags)
    return found


def is_rude(card: dict, deck_tags: list) -> bool:
    return (card.get("register") == RUDE or RUDE in (card.get("tags") or [])
            or RUDE in deck_tags)


def candidates(card: dict, cards: Index) -> list[tuple[str, int]]:
    """[card]'s warnings, each as the value naming it and its importance."""
    found: list[tuple[str, int]] = []
    notes = card.get("notes")
    for place, note in enumerate(notes if isinstance(notes, list) else [], 1):
        if not isinstance(note, dict) or note.get("kind") not in ALIKE:
            continue
        name = str(note.get("id") or place)
        kind = note["kind"]
        partner, tags = cards.get(str(note.get("ref")), (None, []))
        if kind == "homograph":
            found.append((name, 3))
            continue
        if kind == "pair":
            a, b = card.get("ipa"), (partner or {}).get("ipa")
            # A pair is one segment apart by definition; without both IPAs,
            # take it at its word.
            close = (not (isinstance(a, str) and isinstance(b, str))
                     or distance(segments(a), segments(b)) <= 1)
            if partner is not None and is_rude(partner, tags):
                very = partner.get("level") in VERY_RUDE
                found.append((name, 4 if close and very else 0))
                continue
        else:
            a, b = card.get("target"), (partner or {}).get("target")
            close = (not (isinstance(a, str) and isinstance(b, str))
                     or distance(letters(a), letters(b)) <= 1)
        found.append((name, 3 if close else 2))
    senses = card.get("senses")
    if isinstance(senses, list) and senses:
        found.append(("senses", 2 if len(senses) >= 2 else 1))
    return found


def pick(card: dict, cards: Index) -> str | None:
    """The warning [card]'s teach card shows, "none", or None for a card
    with no warning at all."""
    found = candidates(card, cards)
    if not found:
        return None
    top = max(importance for _, importance in found)
    if top == 0:
        return "none"
    best = sorted(name for name, importance in found if importance == top)
    return random.Random(str(card.get("id"))).choice(best)


def set_warnings(text: str, picks: dict[str, str]) -> tuple[str, list[dict]]:
    """The file with `warning: "<pick>"` on each card of [picks] that lacks
    it, before its notes or senses, and what changed. A card with another
    warning is left and reported."""
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    changes: list[dict] = []
    i = 0
    in_cards = False
    while i < len(lines):
        line = lines[i]
        if line.startswith("cards:"):
            in_cards = True
        m = _ID.match(line) if in_cards else None
        if not m or m["id"] not in picks:
            out.append(line)
            i += 1
            continue
        j = i + 1
        while j < len(lines) and not _ID.match(lines[j]) and (
                lines[j].startswith(m["ind"] + " ") or not lines[j].strip()):
            j += 1
        block = lines[i:j]
        inner = m["ind"] + "  "
        card, value = m["id"], picks[m["id"]]
        have = None
        for bl in block[1:]:
            km = _VALUE.match(bl)
            if km and km["ind"] == inner and km["key"] == "warning":
                have = km["value"]
                break
        if have is None:
            at = next((k for k, bl in enumerate(block[1:], 1)
                       if (km := _KEY.match(bl)) and km["ind"] == inner
                       and km["key"] in ("notes", "senses")), None)
            if at is None:
                raise ValueError(f"card {card}: no notes or senses to put warning before")
            block.insert(at, f'{inner}warning: "{value}"\n')
            changes.append({"card": card, "old": None, "new": value})
        elif have != value:
            changes.append({"card": card, "old": have, "new": None})
        out.extend(block)
        i = j
    return "".join(out), changes


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("root", type=Path, help="the decks folder")
    parser.add_argument("--write", action="store_true", help="rewrite the files")
    args = parser.parse_args(argv)
    cards = index(args.root)
    total: dict[str, int] = {}
    for path in sorted(args.root.glob("*/*.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict) or not isinstance(data.get("cards"), list):
            continue
        picks = {c["id"]: p for c in data["cards"]
                 if isinstance(c, dict) and isinstance(c.get("id"), str)
                 if (p := pick(c, cards)) is not None}
        if not picks:
            continue
        text = path.read_text(encoding="utf-8")
        new, changes = set_warnings(text, picks)
        for change in changes:
            if change["new"] is None:
                print(f"{path}: {change['card']} keeps warning "
                      f"{change['old']!r}, not {picks[change['card']]!r}")
            else:
                print(f"{path}: {change['card']} warning {change['new']!r}")
                kind = change["new"] if change["new"] in ("senses", "none") else "note"
                total[kind] = total.get(kind, 0) + 1
        if args.write and new != text:
            path.write_text(new, encoding="utf-8")
    print(f"warnings set: {sum(total.values())} "
          + ", ".join(f"{k} {v}" for k, v in sorted(total.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
