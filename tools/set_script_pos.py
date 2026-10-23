#!/usr/bin/env python3
"""Mark the cards of the script decks for Hear (#522, step 7; owner,
2026-10-23: "New pos letter/digit", "Letters only", "Key, two releases").

Hear asks for what was heard, typing the form, of a card that is a letter or
a digit (`pos: "letter"` or `pos: "digit"`) or is marked `hears: "form"`. The
decks are marked in two passes, a release apart, because an app that does not
know the `hears` key rejects the card:

    python3 tools/set_script_pos.py decks/ --set pos             # release N
    python3 tools/set_script_pos.py decks/ --set hears           # release N+1
    python3 tools/set_script_pos.py decks/ --set pos --write     # rewrite

`pos`: `digit` on a `-digits` deck, `letter` on a vowels, consonants, vowel
signs, conjuncts, or Perso-Arabic letters, shapes or vowels deck. `hears`:
`form` on the words of the spelling and script reading decks, which keep their
real part of speech. Only vocab cores on a path's `alphabet` list are read, and
a deck of another kind on it is listed. A card that already has the key is not
changed (a different `pos` is reported), so a second run changes nothing.
Only the repository's block style is edited, a card found by its `- id:` line.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

_ID = re.compile(r'^(?P<ind>\s*)- id:\s*["\']?(?P<id>[^"\'\s]+)["\']?\s*$')
_KEY = re.compile(r"^(?P<ind>\s+)(?P<key>[a-z_]+):")
_VALUE = re.compile(r'^(?P<ind>\s+)(?P<key>[a-z_]+):\s*["\']?(?P<value>[^"\'\s#]*)["\']?\s*$')

LETTER_DECKS = ("-script-vowels", "-script-consonants", "-script-vowel-signs",
                "-script-conjuncts", "-script-perso-arabic-letters",
                "-script-perso-arabic-shapes", "-script-perso-arabic-vowels")
DIGIT_DECKS = ("-digits",)
WORD_DECKS = ("-script-reading", "-script-perso-arabic-reading", "-spelling")

# Where a new key goes: after the first of these a card has, in this order.
_AFTER = {"pos": ("ipa", "reading", "target"),
          "hears": ("pos", "ipa", "reading", "target")}


def value_for(key: str, deck_id: str) -> str | None:
    """The value [key] takes on the cards of [deck_id], or None for none."""
    if key == "pos":
        if deck_id.endswith(DIGIT_DECKS):
            return "digit"
        if deck_id.endswith(LETTER_DECKS):
            return "letter"
    elif key == "hears" and deck_id.endswith(WORD_DECKS):
        return "form"
    return None


def alphabet_decks(root: Path) -> list[str]:
    """Every deck id on a path's `alphabet` list."""
    found: list[str] = []
    for path in sorted(root.glob("*/*-path.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        found += [str(d) for d in data.get("alphabet") or []]
    return found


def set_key(text: str, key: str, value: str) -> tuple[str, list[dict]]:
    """The file with `key: "value"` on each card that lacks it, and what
    changed. A card with the key and another value is left and reported."""
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
        if not m:
            out.append(line)
            i += 1
            continue
        j = i + 1
        while j < len(lines) and not _ID.match(lines[j]) and (
                lines[j].startswith(m["ind"] + " ") or not lines[j].strip()):
            j += 1
        block = lines[i:j]
        inner = m["ind"] + "  "
        card = m["id"]
        have = None
        for bl in block[1:]:
            km = _VALUE.match(bl)
            if km and km["ind"] == inner and km["key"] == key:
                have = km["value"]
                break
        if have is None:
            at = None
            for after in _AFTER[key]:
                for k, bl in enumerate(block[1:], 1):
                    km = _KEY.match(bl)
                    if km and km["ind"] == inner and km["key"] == after:
                        at = k
                        break
                if at is not None:
                    break
            if at is None:
                raise ValueError(f"card {card}: no target to put {key} after")
            end = at + 1
            while end < len(block) and not _KEY.match(block[end]):
                end += 1
            block.insert(end, f'{inner}{key}: "{value}"\n')
            changes.append({"card": card, "old": None, "new": value})
        elif have != value:
            changes.append({"card": card, "old": have, "new": None})
        out.extend(block)
        i = j
    return "".join(out), changes


def convert_tree(root: Path, key: str, write: bool) -> tuple[list[dict], list[str]]:
    """Mark every deck of [root] for [key]; also the alphabet decks left alone."""
    wanted = {d: v for d in alphabet_decks(root) if (v := value_for(key, d))}
    results: list[dict] = []
    for path in sorted(root.glob("*/*.yaml")):
        if path.name.endswith("-path.yaml"):
            continue
        text = path.read_text(encoding="utf-8")
        head = yaml.safe_load(text.split("\ncards:", 1)[0] + "\n") or {}
        deck_id = head.get("id")
        if (deck_id not in wanted or head.get("kind", "vocab") != "vocab"
                or head.get("part", "core") != "core"):
            continue
        new_text, changes = set_key(text, key, wanted[deck_id])
        if not changes:
            continue
        if write and any(c["new"] for c in changes):
            path.write_text(new_text, encoding="utf-8")
        results.append({"path": path, "deck": deck_id, "value": wanted[deck_id],
                        "changes": changes})
    left = sorted(d for d in alphabet_decks(root) if value_for(key, d) is None)
    return results, left


def report(results: list[dict], left: list[str], key: str) -> str:
    set_ = [c for r in results for c in r["changes"] if c["new"]]
    kept = [(r, c) for r in results for c in r["changes"] if not c["new"]]
    lines = ["# " + key + " on the script decks", "",
             f"{len(set_)} cards in {len(results)} decks get `{key}`; "
             f"{len(kept)} keep another value.", "",
             f"| Deck | {key} | Cards set |", "|---|---|---|"]
    for r in results:
        n = sum(1 for c in r["changes"] if c["new"])
        lines.append(f"| {r['deck']} | {r['value']} | {n} |")
    if kept:
        lines += ["", "Cards left with their own value:", ""]
        lines += [f"- {r['deck']} {c['card']}: `{c['old']}`" for r, c in kept]
    lines += ["", "On an alphabet list and not marked for this key: "
              + (", ".join(left) or "none")]
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("decks", type=Path)
    ap.add_argument("--set", choices=("pos", "hears"), required=True)
    ap.add_argument("--write", action="store_true", help="rewrite the files")
    args = ap.parse_args(argv)
    try:
        results, left = convert_tree(args.decks, args.set, args.write)
    except ValueError as e:
        print(e, file=sys.stderr)
        return 1
    sys.stdout.write(report(results, left, args.set))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
