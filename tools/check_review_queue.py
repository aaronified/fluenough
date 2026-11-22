#!/usr/bin/env python3
"""Checks the v2 rows of the review queue (builder questions v2; owner,
2026-11-22; wiki Plan-Builder-Questions-V2).

A v2 row is `| card id | unit | facet | concern (optional) | raised by | date |`
under a header whose third cell is `facet` (tools/review_queue.py). It
doubts one facet of one card; the app asks one fixed question for the facet,
so a row never carries question text. This checker enforces, for every v2 row
of `docs/review-queue/<lang>.md`:

- six cells, a card id that is a card of the language's decks, never
  `unit-level` or `course-wide` (those stay only in the old table);
- the facet is one of the nine facets (`lib/core/review/facets.dart`) and the
  card has it: `reading`, `ipa`, `example`, `note` and `audio` only when the
  card has one, `offence` only on a card whose register is `offensive`; an
  example may be named as `example:<8 hex>`, the hash of its text, and must
  then be one of the card's examples;
- the concern, if any, is a plain statement of at most 140 characters: no
  `?`, and no card id but the row's own (it is context, shown as "The deck
  builder was unsure: ...", never turned into a question);
- `raised by` is not empty and the date is `YYYY-MM-DD`;
- one row at most for a (card, facet).

The old rows (free-text questions, `unit-level`, `course-wide`) are parsed
and counted in the report, never checked. Exit 0 when clean, 1 on any
violation, 2 on bad arguments.

    python3 tools/check_review_queue.py [--root .]
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

import review_queue as rq  # noqa: E402

_Loader = getattr(yaml, "CSafeLoader", yaml.SafeLoader)

MAX_CONCERN = 140
CARD_ID_IN_TEXT = re.compile(r"[a-z]{2,3}-\d{4}")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
REF = re.compile(r"^[0-9a-f]{8}$")


def point_hash(text: str) -> str:
    """`pointHash` of lib/core/review/review_question.dart: FNV-1a over the
    UTF-16 code units of the trimmed text, 8 lowercase hex digits."""
    h = 0x811C9DC5
    data = text.strip().encode("utf-16-le")
    for i in range(0, len(data), 2):
        h = ((h ^ (data[i] | data[i + 1] << 8)) * 0x01000193) & 0xFFFFFFFF
    return f"{h:08x}"


def _has(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def card_facts(root: Path, lang: str) -> dict[str, dict]:
    """What each card of `decks/<lang>/` has, by id: `facets` (the set of
    facets `facetsOf` in facets.dart gives it) and `examples` (the hashes of
    its examples' texts). Core files only; an English layer has no `cards`
    list."""
    found: dict[str, dict] = {}
    folder = root / "decks" / lang
    if not folder.is_dir():
        return found
    for path in sorted(folder.rglob("*.yaml")):
        try:
            data = yaml.load(path.read_text(encoding="utf-8"), Loader=_Loader)
        except (OSError, UnicodeDecodeError, yaml.YAMLError):
            continue
        cards = data.get("cards") if isinstance(data, dict) else None
        for card in cards if isinstance(cards, list) else []:
            if not isinstance(card, dict) or not isinstance(card.get("id"), str):
                continue
            examples = [e.get("target") for e in card.get("examples") or []
                        if isinstance(e, dict) and _has(e.get("target"))]
            facets = {"word", "meaning", "unit"}
            if _has(card.get("reading")):
                facets.add("reading")
            if _has(card.get("ipa")):
                facets.add("ipa")
            if examples:
                facets.add("example")
            if card.get("notes"):
                facets.add("note")
            if card.get("register") == "offensive":
                facets.add("offence")
            if _has(card.get("audio")):
                facets.add("audio")
            found[card["id"]] = {"facets": facets,
                                 "examples": {point_hash(t) for t in examples}}
    return found


@dataclass
class Violation:
    lang: str
    line: int
    message: str


@dataclass
class Checked:
    violations: list[Violation] = field(default_factory=list)
    v2_rows: int = 0
    # Old rows read and left alone, by language.
    legacy_rows: dict[str, int] = field(default_factory=dict)


def check_queue(queue: rq.Queue, facts: dict[str, dict], out: Checked) -> None:
    lang = queue.lang

    def bad(line: int, message: str) -> None:
        out.violations.append(Violation(lang, line, message))

    for line in queue.malformed_v2:
        bad(line, "a v2 row must have exactly six cells: card id | unit | facet | "
                  "concern | raised by | date (escape a `|` in the concern as `\\|`)")
    seen: dict[tuple[str, str], int] = {}
    legacy = 0
    for row in queue.rows:
        if not row.v2:
            legacy += 1
            continue
        out.v2_rows += 1
        n = row.line
        if row.scope:
            bad(n, f"`{row.card}` rows are allowed only in the old table, not in v2")
            continue
        have = facts.get(row.card)
        if have is None:
            bad(n, f"card id {row.card} is not a card of the {lang} decks")
        if row.facet not in rq.FACETS:
            bad(n, f"facet `{row.facet}` is not one of: {', '.join(rq.FACETS)}")
        elif have is not None and row.facet not in have["facets"]:
            bad(n, f"{row.card} has no {row.facet} to doubt")
        if row.ref:
            if row.facet != "example":
                bad(n, f"only an example facet takes a `:ref` (`{row.facet}:{row.ref}`)")
            elif not REF.match(row.ref):
                bad(n, f"example ref `{row.ref}` is not 8 hex digits")
            elif have is not None and row.ref not in have["examples"]:
                bad(n, f"example ref {row.ref} is not an example of {row.card}")
        if len(row.concern) > MAX_CONCERN:
            bad(n, f"concern is {len(row.concern)} characters, at most {MAX_CONCERN}")
        if "?" in row.concern or "？" in row.concern:
            bad(n, "concern has a `?`: it is a plain statement, not a question")
        others = {i for i in CARD_ID_IN_TEXT.findall(row.concern) if i != row.card}
        if others:
            bad(n, f"concern names another card ({', '.join(sorted(others))}); "
                   "a row is about its own card only")
        if not row.by:
            bad(n, "`raised by` is empty")
        if not DATE.match(row.date):
            bad(n, f"date `{row.date}` is not YYYY-MM-DD")
        key = (row.card, row.facet)
        if key in seen:
            bad(n, f"second row for {row.card} {row.facet} (the first is line {seen[key]})")
        else:
            seen[key] = n
    if legacy:
        out.legacy_rows[lang] = legacy


def check(root: Path) -> Checked:
    out = Checked()
    for path in sorted((root / rq.QUEUE_DIR).glob("*.md")):
        lang = path.stem
        if lang.lower() == "readme":
            continue
        try:
            queue = rq.parse_queue(path.read_text(encoding="utf-8"), lang)
        except (OSError, UnicodeDecodeError):
            continue
        check_queue(queue, card_facts(root, lang), out)
    return out


def format_violations(violations: list[Violation]) -> str:
    lines = [f"{len(violations)} problem(s) in the review queue's v2 rows:"]
    lines += [f"  {rq.QUEUE_DIR.as_posix()}/{v.lang}.md line {v.line}: {v.message}"
              for v in violations]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", type=Path, default=Path("."))
    args = ap.parse_args(argv)
    result = check(args.root)
    old = sum(result.legacy_rows.values())
    print(f"{result.v2_rows} v2 rows checked; {old} old rows read and left alone.")
    if result.violations:
        print(format_violations(result.violations), end="", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
