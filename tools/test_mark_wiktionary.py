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

    def test_a_section_that_is_not_the_dumps_marks_nothing(self) -> None:
        mw.run("zz", DUMP, self.decks, write=True, section="Elsewhere")
        self.assertEqual(self.marked(), set())


if __name__ == "__main__":
    unittest.main()
