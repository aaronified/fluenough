#!/usr/bin/env python3
"""Tests for tools/mark_wiktionary.py (#422), on the fixture in
tools/fixtures/wiktionary: a small core and English layer as the language zz,
and a kaikki.org extract. Nothing is downloaded.

Stdlib `unittest` plus PyYAML, like the tool.
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import mark_wiktionary as mw  # noqa: E402
import validate_decks as vd  # noqa: E402

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "wiktionary"
DUMP = FIXTURE / "Testlang.jsonl"
LAYER = "zz/en/zz-en-home.yaml"


class MarkWiktionary(unittest.TestCase):
    def setUp(self) -> None:
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        self.decks = tmp / "decks"
        shutil.copytree(FIXTURE / "decks", self.decks)

    def marked(self) -> set[str]:
        raw = vd._load_raw(self.decks / LAYER)
        return {cid for cid, e in raw["cards"].items() if e.get("wiktionary") is True}

    def test_a_report_changes_nothing(self) -> None:
        before = (self.decks / LAYER).read_text(encoding="utf-8")
        report = mw.run("zz", DUMP, self.decks, write=False)
        self.assertIn("to mark: 5", report)
        self.assertEqual((self.decks / LAYER).read_text(encoding="utf-8"), before)

    def test_marks_only_words_with_an_entry(self) -> None:
        mw.run("zz", DUMP, self.decks, write=True)
        # घर, मकान, कल, बड़ा and है have entries; रसोईघर has none, and पानी is
        # written in flow style, which the tool leaves alone.
        self.assertEqual(self.marked(), {"zz-9001", "zz-9002", "zz-9003",
                                         "zz-9004", "zz-9005"})

    def test_a_second_run_finds_nothing_to_do_and_the_layer_still_reads(self) -> None:
        mw.run("zz", DUMP, self.decks, write=True)
        text = (self.decks / LAYER).read_text(encoding="utf-8")
        report = mw.run("zz", DUMP, self.decks, write=True)
        self.assertIn("marked: 0", report)
        self.assertIn("already marked: 5", report)
        self.assertEqual((self.decks / LAYER).read_text(encoding="utf-8"), text)

    def edit_layer(self, old: str, new: str) -> None:
        path = self.decks / LAYER
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text)
        path.write_text(text.replace(old, new), encoding="utf-8")

    def test_an_unmatched_head_is_reported_not_counted(self) -> None:
        # A trailing comment after the id: not a form the tool edits.
        self.edit_layer('"zz-9001":\n', '"zz-9001": # the house\n')
        report = mw.run("zz", DUMP, self.decks, write=True)
        self.assertIn("marked: 4", report)
        self.assertIn("unmatched", report)
        self.assertIn("zz-9001", report)
        self.assertNotIn("zz-9001", self.marked())
        _, left = mw.mark("zz", DUMP, self.decks, write=True)
        self.assertEqual(left, 1, "a second run lists it again")

    def test_a_flow_style_entry_is_marked(self) -> None:
        self.edit_layer('"zz-9001":\n    native: "house; home"',
                        '"zz-9001": { native: "house; home" }')
        report = mw.run("zz", DUMP, self.decks, write=True)
        self.assertIn("marked: 5", report)
        self.assertEqual(self.marked(), {"zz-9001", "zz-9002", "zz-9003",
                                         "zz-9004", "zz-9005"})

    def test_wiktionary_false_gets_no_second_key(self) -> None:
        self.edit_layer('"zz-9002":\n    native: "house (the building)"',
                        '"zz-9002":\n    native: "house (the building)"\n'
                        '    wiktionary: false')
        report = mw.run("zz", DUMP, self.decks, write=True)
        self.assertIn("marked: 4", report)
        self.assertIn("zz-9002", report)
        text = (self.decks / LAYER).read_text(encoding="utf-8")
        self.assertEqual(text.count("wiktionary: false"), 1)
        self.assertNotIn("zz-9002", self.marked())

    def test_a_section_that_is_not_the_dumps_marks_nothing(self) -> None:
        mw.run("zz", DUMP, self.decks, write=True, section="Elsewhere")
        self.assertEqual(self.marked(), set())


if __name__ == "__main__":
    unittest.main()
