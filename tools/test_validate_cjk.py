#!/usr/bin/env python3
"""Readings beside Chinese, Japanese and Korean words in prose: a word in
Han, kana or Hangul spans several 128-code-point blocks, and is one run
with one reading after it, as an Arabic one is."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks as vd  # noqa: E402


class CjkReadings(unittest.TestCase):

    def test_one_reading_after_a_whole_word(self) -> None:
        for text in ("Say 天气 (tiānqì) here.",
                     "Say 안녕하세요 (annyeonghaseyo) here.",
                     "Say こんばんは (konbanwa) here.",
                     "Say 日本語 (nihongo) here."):
            self.assertEqual(vd._untransliterated(text, "en"), [], text)

    def test_a_word_without_its_reading_is_one_run(self) -> None:
        self.assertEqual(vd._untransliterated("Say 天气 here.", "en"), ["天气"])
        self.assertEqual(vd._untransliterated("Say 안녕하세요 here.", "en"),
                         ["안녕하세요"])

    def test_a_cores_own_script_needs_no_reading(self) -> None:
        own = vd._SCRIPT_BLOCK["kana"]
        self.assertEqual(vd._untransliterated("先生 です", "ja", own), [])
        own = vd._SCRIPT_BLOCK["hangul"]
        self.assertEqual(vd._untransliterated("학생이에요", "ko", own), [])


if __name__ == "__main__":
    unittest.main()
