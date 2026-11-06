#!/usr/bin/env python3
"""The review queue (owner, 2026-11-06, "go B"): the doubts deck builders
wrote in `docs/review-queue/<lang>.md`, turned into `decks/review-queue.json`,
the one file the app reads them from.

A queue file is a plain Markdown table: card id | unit | question for the
reviewer | raised by | date. This tool:

- parses each file, tolerating odd spacing, a missing header, `\\|` inside a
  cell and rows that are not tables at all (those are reported, never fatal);
- keeps the rows that name a card as the card's builder questions, and the
  `unit-level` and `course-wide` rows as the unit-level question list (no
  card, so never used to choose cards);
- checks every card id against the language's decks (`decks/<lang>/`) and
  reports the unknown ones; an unknown id stays out of the feed, and the run
  goes on;
- writes the feed, sorted, so that an unchanged queue gives an unchanged file;
- reports the settled cards: a card two reviewers signed off (its `checked_by`
  holds two codes) is no longer asked by the app. Nothing is removed from a
  queue file by this tool. A free-text doubt ("is gender m right?") may be
  about a field a sign-off does not cover, so a person takes the row out
  when the answer is in the deck.

The feed is `{"format": "fluenough-review-queue", "version": 1, "languages":
{"ta": {"cards": {"ta-0041": [{"question": ..., "by": ..., "date": ...}]},
"unit_level": [{"scope": "unit-level", "unit": ..., "question": ...}]}}}`.
Released apps never fetch it, so nothing changes for them; the app that does
ignores keys it does not know.

    python3 tools/review_queue.py [--root .] [--out decks/review-queue.json]
        [--report FILE]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

_Loader = getattr(yaml, "CSafeLoader", yaml.SafeLoader)

FORMAT = "fluenough-review-queue"
VERSION = 1
QUEUE_DIR = Path("docs") / "review-queue"
FEED = Path("decks") / "review-queue.json"
SCOPES = {"unit-level", "course-wide"}

# The most characters of a question that reach a phone.
MAX_QUESTION = 400
# How many reviewers' sign-offs settle a card (lib/core/review/question_generator.dart).
SIGNED_OFF_ENOUGH = 2

_CELL_SPLIT = re.compile(r"(?<!\\)\|")
_RULE_CELL = re.compile(r"^:?-{2,}:?$")
_CARD_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


@dataclass
class Row:
    card: str  # a card id, or "unit-level" / "course-wide"
    unit: str
    question: str
    by: str
    date: str
    line: int

    @property
    def scope(self) -> str | None:
        return self.card if self.card in SCOPES else None


@dataclass
class Queue:
    lang: str
    rows: list[Row] = field(default_factory=list)
    malformed: list[int] = field(default_factory=list)  # line numbers


def _cells(line: str) -> list[str]:
    inner = line.strip()
    if inner.startswith("|"):
        inner = inner[1:]
    if inner.endswith("|") and not inner.endswith("\\|"):
        inner = inner[:-1]
    return [c.replace("\\|", "|").strip() for c in _CELL_SPLIT.split(inner)]


def parse_queue(text: str, lang: str) -> Queue:
    """The rows of [text], a queue file of language [lang]. Tolerant: the
    header and the rule line are skipped wherever they are, a card id may
    be in backticks, and a row with fewer than three cells, or with no
    question, is counted as malformed and left out."""
    queue = Queue(lang)
    for number, line in enumerate(text.splitlines(), 1):
        if not line.lstrip().startswith("|"):
            continue
        cells = _cells(line)
        if all(_RULE_CELL.match(c) for c in cells if c) and any(cells):
            continue
        if cells[0].lower().strip("` ") == "card id":
            continue
        if len(cells) < 3:
            queue.malformed.append(number)
            continue
        card = cells[0].strip("` ")
        if card.lower() in SCOPES:
            card = card.lower()
        # Cells past the fifth belong to the question: a `|` that was not
        # escaped.
        if len(cells) > 5:
            question, by, date = " | ".join(cells[2:-2]), cells[-2], cells[-1]
        else:
            question = cells[2]
            by = cells[3] if len(cells) > 3 else ""
            date = cells[4] if len(cells) > 4 else ""
        question = re.sub(r"\s+", " ", question).strip()
        if not card or not question or (card not in SCOPES and not _CARD_ID.match(card)):
            queue.malformed.append(number)
            continue
        queue.rows.append(Row(card, cells[1], question[:MAX_QUESTION], by, date, number))
    return queue


def deck_cards(root: Path, lang: str) -> dict[str, int]:
    """Every card id in `decks/<lang>/`, with how many reviewer codes its
    `checked_by` lists (the most, across a core and its layers)."""
    found: dict[str, int] = {}
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
            codes = card.get("checked_by")
            count = len(codes) if isinstance(codes, list) else 0
            found[card["id"]] = max(count, found.get(card["id"], 0))
    return found


@dataclass
class Built:
    feed: dict
    unknown: dict[str, list[str]]  # lang -> card ids not in its decks
    settled: dict[str, list[str]]  # lang -> listed cards two reviewers signed off
    malformed: dict[str, list[int]]


def build(root: Path) -> Built:
    languages: dict[str, dict] = {}
    unknown: dict[str, list[str]] = {}
    settled: dict[str, list[str]] = {}
    malformed: dict[str, list[int]] = {}
    for path in sorted((root / QUEUE_DIR).glob("*.md")):
        lang = path.stem
        if lang.lower() == "readme":
            continue
        try:
            queue = parse_queue(path.read_text(encoding="utf-8"), lang)
        except (OSError, UnicodeDecodeError):
            continue
        if queue.malformed:
            malformed[lang] = queue.malformed
        known = deck_cards(root, lang)
        cards: dict[str, list[dict]] = {}
        unit_level: list[dict] = []
        for row in queue.rows:
            if row.scope:
                unit_level.append({"scope": row.scope, "unit": row.unit,
                                   "question": row.question})
            elif row.card not in known:
                unknown.setdefault(lang, []).append(row.card)
            else:
                cards.setdefault(row.card, []).append(
                    {"question": row.question, "by": row.by, "date": row.date})
                if known[row.card] >= SIGNED_OFF_ENOUGH:
                    settled.setdefault(lang, []).append(row.card)
        if cards or unit_level:
            languages[lang] = {"cards": cards, "unit_level": unit_level}
    for table in (unknown, settled):
        for lang in table:
            table[lang] = sorted(set(table[lang]))
    feed = {"format": FORMAT, "version": VERSION, "languages": languages}
    return Built(feed, unknown, settled, malformed)


def feed_text(feed: dict) -> str:
    return json.dumps(feed, ensure_ascii=False, indent=1, sort_keys=True) + "\n"


def report(built: Built) -> str:
    out = ["# Review queue report", ""]
    cards = sum(len(v["cards"]) for v in built.feed["languages"].values())
    units = sum(len(v["unit_level"]) for v in built.feed["languages"].values())
    out.append(f"{cards} cards with a builder question, {units} unit-level or "
               f"course-wide rows, in {len(built.feed['languages'])} languages.")
    sections = (
        ("Unknown card ids (not in the language's decks, left out of the feed)", built.unknown),
        ("Settled: two reviewers signed these off; a person removes their rows "
         "once the answer is in the deck", built.settled),
        ("Rows that are not a table row with a question (line numbers)", built.malformed),
    )
    for title, table in sections:
        if table:
            out += ["", f"## {title}", ""]
            out += [f"- {lang}: {', '.join(str(x) for x in items)}"
                    for lang, items in sorted(table.items())]
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--report", type=Path, default=None)
    args = ap.parse_args(argv)
    built = build(args.root)
    out = args.out or args.root / FEED
    out.write_text(feed_text(built.feed), encoding="utf-8")
    text = report(built)
    if args.report:
        args.report.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
