#!/usr/bin/env python3
"""The review queue's reader (tools/review_queue.py): the tables the deck
builders write, the unit-level rows, unknown ids, settled cards, the feed.
Stdlib `unittest` plus PyYAML. The words are made up.
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import review_queue as rq  # noqa: E402

HEADER = ("| card id | unit | question for the reviewer | raised by | date |\n"
          "|---|---|---|---|---|\n")


class Parse(unittest.TestCase):
    def test_a_plain_table(self):
        q = rq.parse_queue(HEADER + "| zz-0001 | zz-home | Is it m? | Haiku builder | 2026-11-05 |\n", "zz")
        self.assertEqual(len(q.rows), 1)
        row = q.rows[0]
        self.assertEqual((row.card, row.unit, row.question, row.by, row.date),
                         ("zz-0001", "zz-home", "Is it m?", "Haiku builder", "2026-11-05"))
        self.assertIsNone(row.scope)
        self.assertEqual(q.malformed, [])

    def test_odd_spacing_backticks_and_no_outer_pipes(self):
        text = ("|card id|unit|question for the reviewer|raised by|date|\n"
                "| :--- | --- | ---: | --- | --- |\n"
                "|   `zz-0002`   |  zz-home  |   Is   it\tnatural?   |  Sonnet reviewer |2026-11-06|\n"
                "  | zz-0003 | zz-home | Tone? | Haiku builder | 2026-11-06\n")
        q = rq.parse_queue(text, "zz")
        self.assertEqual([r.card for r in q.rows], ["zz-0002", "zz-0003"])
        self.assertEqual(q.rows[0].question, "Is it natural?")
        self.assertEqual(q.rows[1].date, "2026-11-06")

    def test_unit_level_and_course_wide_rows_are_scopes_not_cards(self):
        text = HEADER + ("| unit-level | zz-home (ids zz-0001 to zz-0009) | Natural? | Haiku builder | 2026-11-05 |\n"
                         "| Course-Wide | all decks | Style? | Haiku builder | 2026-11-05 |\n")
        q = rq.parse_queue(text, "zz")
        self.assertEqual([r.scope for r in q.rows], ["unit-level", "course-wide"])
        self.assertEqual(q.rows[0].unit, "zz-home (ids zz-0001 to zz-0009)")

    def test_an_escaped_pipe_stays_in_its_cell(self):
        q = rq.parse_queue(HEADER + "| zz-0001 | u | Is a \\| b right? | me | 2026-11-05 |\n", "zz")
        self.assertEqual(q.rows[0].question, "Is a | b right?")
        self.assertEqual(q.rows[0].by, "me")

    def test_an_unescaped_pipe_joins_the_question(self):
        q = rq.parse_queue(HEADER + "| zz-0001 | u | a | b | me | 2026-11-05 |\n", "zz")
        self.assertEqual(q.rows[0].question, "a | b")
        self.assertEqual((q.rows[0].by, q.rows[0].date), ("me", "2026-11-05"))

    def test_rows_without_a_question_or_cells_are_malformed_not_fatal(self):
        text = HEADER + ("| zz-0001 | u |\n"
                         "| zz-0002 | u |   | me | d |\n"
                         "| not an id! | u | q | me | d |\n"
                         "| zz-0004 | u | fine | me | d |\n"
                         "prose between rows\n")
        q = rq.parse_queue(text, "zz")
        self.assertEqual([r.card for r in q.rows], ["zz-0004"])
        self.assertEqual(q.malformed, [3, 4, 5])

    def test_a_long_question_is_cut(self):
        q = rq.parse_queue(HEADER + f"| zz-0001 | u | {'x' * 900} | me | d |\n", "zz")
        self.assertEqual(len(q.rows[0].question), rq.MAX_QUESTION)

    def test_no_text_no_rows(self):
        self.assertEqual(rq.parse_queue("", "zz").rows, [])


def card(i: str, checked: list[str] | None = None) -> str:
    extra = f"  checked_by: [{', '.join(checked)}]\n" if checked else ""
    return f"- id: {i}\n  target: x\n{extra}"


class Build(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "decks" / "zz" / "en").mkdir(parents=True)
        (self.root / "docs" / "review-queue").mkdir(parents=True)
        (self.root / "decks" / "zz" / "zz-home.yaml").write_text(
            "id: zz-home\ncards:\n" + card("zz-0001") + card("zz-0002", ["A", "B"])
            + card("zz-0003", ["A"]), encoding="utf-8")
        (self.root / "decks" / "zz" / "en" / "zz-en-home.yaml").write_text(
            "id: zz-en-home\ncards:\n" + card("zz-0001"), encoding="utf-8")

    def queue(self, lang: str, rows: str):
        (self.root / "docs" / "review-queue" / f"{lang}.md").write_text(HEADER + rows, encoding="utf-8")

    def test_known_cards_go_in_the_feed_and_unknown_ones_are_reported(self):
        self.queue("zz", "| zz-0001 | zz-home | Is it m? | Haiku builder | 2026-11-05 |\n"
                         "| zz-0001 | zz-home | And the tone? | Sonnet | 2026-11-06 |\n"
                         "| zz-9999 | zz-home | Ghost | Haiku builder | 2026-11-05 |\n")
        built = rq.build(self.root)
        cards = built.feed["languages"]["zz"]["cards"]
        self.assertEqual(list(cards), ["zz-0001"])
        self.assertEqual([x["question"] for x in cards["zz-0001"]], ["Is it m?", "And the tone?"])
        self.assertEqual(built.unknown, {"zz": ["zz-9999"]})
        self.assertIn("zz-9999", rq.report(built))

    def test_unit_level_rows_are_kept_apart_from_the_cards(self):
        self.queue("zz", "| unit-level | zz-home | Natural? | Haiku builder | 2026-11-05 |\n"
                         "| course-wide | all | Style? | Haiku builder | 2026-11-05 |\n")
        entry = rq.build(self.root).feed["languages"]["zz"]
        self.assertEqual(entry["cards"], {})
        self.assertEqual([u["scope"] for u in entry["unit_level"]], ["unit-level", "course-wide"])

    def test_a_card_two_reviewers_signed_off_is_reported_settled_but_kept(self):
        self.queue("zz", "| zz-0002 | zz-home | q | me | d |\n| zz-0003 | zz-home | q | me | d |\n")
        built = rq.build(self.root)
        self.assertEqual(built.settled, {"zz": ["zz-0002"]})
        self.assertEqual(sorted(built.feed["languages"]["zz"]["cards"]), ["zz-0002", "zz-0003"])

    def test_a_language_with_no_decks_reports_every_id_and_does_not_fail(self):
        self.queue("qq", "| qq-0001 | u | q | me | d |\n")
        built = rq.build(self.root)
        self.assertEqual(built.unknown, {"qq": ["qq-0001"]})
        self.assertEqual(built.feed["languages"], {})

    def test_readme_and_empty_queues_are_not_languages(self):
        (self.root / "docs" / "review-queue" / "README.md").write_text(HEADER + "| zz-0001 | u | q | me | d |\n")
        self.queue("zz", "")
        self.assertEqual(rq.build(self.root).feed["languages"], {})

    def test_the_cli_writes_a_stable_feed(self):
        self.queue("zz", "| zz-0001 | zz-home | Is it m? | Haiku builder | 2026-11-05 |\n")
        out = self.root / "feed.json"
        self.assertEqual(rq.main(["--root", str(self.root), "--out", str(out)]), 0)
        first = out.read_text(encoding="utf-8")
        rq.main(["--root", str(self.root), "--out", str(out)])
        self.assertEqual(first, out.read_text(encoding="utf-8"))
        data = json.loads(first)
        self.assertEqual((data["format"], data["version"]), (rq.FORMAT, 1))
        self.assertEqual(data["languages"]["zz"]["cards"]["zz-0001"][0]["by"], "Haiku builder")


if __name__ == "__main__":
    unittest.main()
