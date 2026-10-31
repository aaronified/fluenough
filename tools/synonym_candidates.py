#!/usr/bin/env python3
"""Candidate synonym sets from what reviewers and deck authors add to cards
(ADR-0050, #924, plan step 9).

Usage:
    python3 tools/synonym_candidates.py [repo-root] [--min N]
    # prints the report; changes no file

A word added to one card's `alt_native` is that card's business. The same
pair, a card's answer and an extra accepted one, on several cards is a
candidate set: the report lists each such pair with its cards, counting the
`alt_native` the decks have and the `alt_native_add` proposals still waiting
on a card, and leaves out a pair that `assets/synonyms/en.yaml` already puts
in one set. A reviewer never edits that file (ADR-0050): the owner takes a
candidate through the seeding workflow, where a Sonnet pass pokes holes in
it before it ships.

Stdlib plus PyYAML, like the deck validator.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
from validate_synonyms import BRACKETS, meaning_key, set_index  # noqa: E402

MIN_CARDS = 2


def _keys(value: object) -> list[str]:
    """The comparison form of each `;` part of an answer."""
    if not isinstance(value, str):
        return []
    return [k for k in (meaning_key(p) for p in BRACKETS.sub(" ", value).split(";")) if k]


def candidates(root: Path, minimum: int = MIN_CARDS) -> list[tuple[tuple[str, str], list[str]]]:
    """Each pair of an English card's answer and an extra accepted one, held
    by at least [minimum] cards and not in one set already, with the cards,
    most cards first."""
    try:
        sets_text = (root / pr.SYNONYM_SETS).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        sets_text = ""
    _, set_of = set_index(sets_text)
    found: dict[tuple[str, str], set[str]] = {}
    for lang in pr.languages(root):
        for entry in pr.entries(root, lang):
            if "alt_native_add" not in pr.vd.PROPOSAL_FIELDS[entry.form] \
                    or pr.native_code_of(lang, entry) != "en":
                continue
            own = _keys(entry.data.get("native"))
            extra = [k for v in (entry.data.get("alt_native") or [])
                     for k in _keys(v)]
            extra += [meaning_key(p.text) for p in entry.proposals()
                      if p.field == "alt_native_add"]
            for a in own:
                for b in extra:
                    if a != b and not (a in set_of and set_of.get(a) == set_of.get(b)):
                        found.setdefault(tuple(sorted((a, b))), set()).add(
                            f"{lang}:{entry.card}")
    rows = [(pair, sorted(cards)) for pair, cards in found.items()
            if len(cards) >= minimum]
    return sorted(rows, key=lambda r: (-len(r[1]), r[0]))


def main(argv: list[str]) -> int:
    args = argv[1:]
    minimum = MIN_CARDS
    if "--min" in args:
        at = args.index("--min")
        try:
            minimum = int(args[at + 1])
            del args[at:at + 2]
        except (IndexError, ValueError):
            print(__doc__.split("\n\n")[0], file=sys.stderr)
            return 2
    root = Path(args[0]) if args else Path(__file__).resolve().parent.parent
    if len(args) > 1 or not (root / "decks").is_dir():
        print(__doc__.split("\n\n")[0], file=sys.stderr)
        return 2
    rows = candidates(root, minimum)
    for (a, b), cards in rows:
        print(f'["{a}", "{b}"]  {len(cards)} cards: {", ".join(cards)}')
    print(f"{len(rows)} candidate set(s) on {minimum} or more cards")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
