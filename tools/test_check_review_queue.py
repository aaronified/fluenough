#!/usr/bin/env python3
"""The review queue's v2 checker (tools/check_review_queue.py) and the feed's
v2 shape (tools/review_queue.py). Stdlib `unittest` plus PyYAML. The words
are made up.
"""

from __future__ import annotations

import contextlib
import io
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_review_queue as crq  # noqa: E402
import review_queue as rq  # noqa: E402

V2 = ("| card id | unit | facet | concern (optional) | raised by | date |\n"
      "|---|---|---|---|---|---|\n")
OLD = ("| card id | unit | question for the reviewer | raised by | date |\n"
       "|---|---|---|---|---|\n")
EX = "zz example one"
EX_HASH = crq.point_hash(EX)

DECK = f"""schema: 1
id: "zz-home"
cards:
  - id: "zz-0001"
    target: "a"
    reading: "a"
    ipa: "a"
    notes:
      - {{ id: "n1", kind: "note" }}
    examples:
      - {{ target: "{EX}" }}
  - id: "zz-0002"
    target: "b"
    register: "offensive"
    audio: "decks/zz/audio/zz-0002.opus"
  - id: "zz-0003"
    target: "c"
"""


def row(card="zz-0001", facet="ipa", concern="", by="Haiku builder",
        date="2026-11-22", unit="zz-home") -> str:
    return f"| {card} | {unit} | {facet} | {concern} | {by} | {date} |\n"


class Hash(unittest.TestCase):
    def test_point_hash_is_fnv_1a_over_the_trimmed_text(self):
        # The standard FNV-1a 32 bit values of "" and "a".
        self.assertEqual(crq.point_hash(""), "811c9dc5")
        self.assertEqual(crq.point_hash(" a "), "e40c292c")


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "decks" / "zz").mkdir(parents=True)
        (self.root / "docs" / "review-queue").mkdir(parents=True)
        (self.root / "decks" / "zz" / "zz-home.yaml").write_text(DECK, encoding="utf-8")

    def queue(self, text: str, lang: str = "zz"):
        (self.root / "docs" / "review-queue" / f"{lang}.md").write_text(text, encoding="utf-8")

    def messages(self) -> list[str]:
        return [v.message for v in crq.check(self.root).violations]


class Parse(Base):
    def test_a_v2_header_starts_v2_rows_and_an_old_one_old_rows(self):
        q = rq.parse_queue(OLD + "| zz-0001 | u | Is it m? | me | d |\n" + V2
                           + row(facet=f"Example:{EX_HASH}", concern="  too   formal "), "zz")
        self.assertEqual([r.v2 for r in q.rows], [False, True])
        r = q.rows[1]
        self.assertEqual((r.card, r.facet, r.ref, r.concern, r.by, r.date),
                         ("zz-0001", "example", EX_HASH, "too formal", "Haiku builder", "2026-11-22"))

    def test_rows_before_any_header_are_old_rows(self):
        q = rq.parse_queue("| zz-0001 | u | Is it m? | me | d |\n", "zz")
        self.assertFalse(q.rows[0].v2)

    def test_a_v2_row_without_six_cells_is_malformed_v2(self):
        q = rq.parse_queue(V2 + "| zz-0001 | u | ipa | a | b | me | 2026-11-22 |\n"
                           "| zz-0001 | u | ipa |\n", "zz")
        self.assertEqual((q.rows, q.malformed_v2), ([], [3, 4]))


class Check(Base):
    def test_clean_rows_pass_and_old_rows_are_counted_not_checked(self):
        self.queue(OLD + "| zz-9999 | u | no question mark | me | d |\n"
                   "| unit-level | u | Natural? | me | d |\n" + V2
                   + row("zz-0001", "ipa", "the vowel length is a guess")
                   + row("zz-0001", f"example:{EX_HASH}")
                   + row("zz-0002", "offence") + row("zz-0002", "audio")
                   + row("zz-0003", "unit") + row("zz-0001", "note"))
        result = crq.check(self.root)
        self.assertEqual(result.violations, [])
        self.assertEqual((result.v2_rows, result.legacy_rows), (6, {"zz": 2}))

    def test_each_rule_has_a_readable_message(self):
        self.queue(V2
                   + row("zz-7777", "ipa")                      # unknown card
                   + row("zz-0001", "colour")                   # unknown facet
                   + row("zz-0003", "reading")                  # card has none
                   + row("zz-0003", "example")
                   + row("zz-0001", "word", "Is it right?")     # a question
                   + row("zz-0002", "word", "x" * 141)          # too long
                   + row("zz-0003", "word", "like zz-0001")     # other card
                   + row("zz-0003", "meaning", by="", date="soon")
                   + row("zz-0001", "reading") + row("zz-0001", "reading")
                   + row("unit-level", "word")
                   + row("zz-0001", "example:deadbeef")
                   + row("zz-0001", "ipa:abcd1234")
                   + "| zz-0001 | u | ipa |\n")
        text = "\n".join(self.messages())
        for part in ("zz-7777 is not a card", "`colour` is not one of",
                     "zz-0003 has no reading", "zz-0003 has no example",
                     "has a `?`", "141 characters", "names another card (zz-0001)",
                     "`raised by` is empty", "not YYYY-MM-DD",
                     "second row for zz-0001 reading",
                     "only in the old table", "deadbeef is not an example",
                     "only an example facet takes", "exactly six cells"):
            self.assertIn(part, text)

    def test_the_concern_may_name_its_own_card(self):
        self.queue(V2 + row("zz-0001", "word", "zz-0001 may be a loan"))
        self.assertEqual(self.messages(), [])

    def test_the_cli_exit_codes(self):
        self.queue(V2 + row())
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(crq.main(["--root", str(self.root)]), 0)
        self.queue(V2 + row("zz-0003", "ipa"))
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            self.assertEqual(crq.main(["--root", str(self.root)]), 1)
        self.assertIn("zz.md line 3", err.getvalue())


class Feed(Base):
    def test_v2_rows_become_asks_and_the_old_shape_is_intact(self):
        self.queue(OLD + "| zz-0001 | zz-home | Is it m? | me | 2026-11-05 |\n"
                   "| unit-level | zz-home | Natural? | me | 2026-11-05 |\n" + V2
                   + row("zz-0001", f"example:{EX_HASH}", "too formal")
                   + row("zz-0002", "audio"))
        feed = rq.build(self.root).feed
        # What a released app reads: version 1 and the old keys, untouched.
        self.assertEqual((feed["format"], feed["version"]), (rq.FORMAT, 1))
        self.assertEqual(feed["asks_version"], 2)
        entry = feed["languages"]["zz"]
        self.assertEqual(entry["cards"], {"zz-0001": [
            {"question": "Is it m?", "by": "me", "date": "2026-11-05"}]})
        self.assertEqual(entry["unit_level"], [
            {"scope": "unit-level", "unit": "zz-home", "question": "Natural?"}])
        self.assertEqual(entry["asks"], {
            "zz-0001": [{"facet": "example", "ref": EX_HASH, "concern": "too formal",
                         "by": "Haiku builder", "date": "2026-11-22"}],
            "zz-0002": [{"facet": "audio", "by": "Haiku builder", "date": "2026-11-22"}]})

    def test_only_v2_rows_leave_cards_empty_but_present(self):
        self.queue(V2 + row())
        entry = rq.build(self.root).feed["languages"]["zz"]
        self.assertEqual((entry["cards"], entry["unit_level"]), ({}, []))

    def test_the_cli_refuses_to_write_a_feed_for_a_rejected_row(self):
        out = self.root / "feed.json"
        self.queue(V2 + row() + row("zz-0003", "ipa"))
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(rq.main(["--root", str(self.root), "--out", str(out)]), 1)
        self.assertFalse(out.exists())
        self.queue(V2 + row())
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(rq.main(["--root", str(self.root), "--out", str(out)]), 0)
        self.assertEqual(json.loads(out.read_text(encoding="utf-8"))["version"], 1)


class FacetsMatchTheApp(unittest.TestCase):
    def test_the_facet_list_is_the_dart_enum(self):
        text = (Path(__file__).resolve().parent.parent / "lib/core/review/facets.dart"
                ).read_text(encoding="utf-8")
        body = text.split("enum Facet {", 1)[1].split(";", 1)[0]
        wires = re.findall(r"\w+\('(\w+)'\)", body)
        self.assertEqual(tuple(wires), rq.FACETS)


if __name__ == "__main__":
    unittest.main()
