#!/usr/bin/env python3
"""Japanese written in kanji (docs/DECK-FORMAT.md, "Japanese kanji", ADR-0053).

A kanji deck is `script: han` with `scripts: [han, kana]`. A card's target is
in kanji, and its kana reading is its `target_scripts.kana`, as a Chinese card
shows pinyin. The validator checks that a kanji target has its kana reading,
and that the reading is kana, with no kanji in it.

Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
PyYAML, like the validator itself.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_validate_b1 import EXTRA, LANGUAGE, B1Case, single  # noqa: E402

JAPANESE = dict(LANGUAGE, code="zz", script="han", scripts=["han", "kana"],
                tts="ja-JP", icon="日")
# 食べる (taberu), to eat: kanji with its okurigana.
EAT = {"id": "zz-9701", "target": "食べる", "reading": "taberu", "native": "to eat",
       "pos": "verb", "target_scripts": {"kana": "たべる"}}
# ありがとう (arigatou): kana alone, nothing to read out.
THANKS = {"id": "zz-9702", "target": "ありがとう", "reading": "arigatou",
          "native": "thank you"}


class KanjiCards(B1Case):

    def errors_of(self, *cards: dict, language: dict | None = None) -> list[str]:
        self.put(EXTRA, single(cards=[dict(c) for c in cards],
                               language=dict(language or JAPANESE)))
        return self.errors(EXTRA)

    def test_a_kanji_card_with_its_kana_reading_is_valid(self) -> None:
        self.assertEqual(self.errors_of(EAT, THANKS), [])

    def test_katakana_and_the_long_vowel_mark_are_kana(self) -> None:
        coffee = {"id": "zz-9703", "target": "珈琲", "reading": "koohii",
                  "native": "coffee", "target_scripts": {"kana": "コーヒー"}}
        self.assertEqual(self.errors_of(coffee), [])

    def test_the_repeat_mark_is_a_kanji(self) -> None:
        people = {"id": "zz-9704", "target": "人々", "reading": "hitobito",
                  "native": "people", "target_scripts": {"kana": "ひとびと"}}
        self.assertEqual(self.errors_of(people), [])
        no_reading = {"id": "zz-9704", "target": "人々", "reading": "hitobito",
                      "native": "people"}
        self.assertIn("card zz-9704: a card written in kanji needs its kana "
                      "reading, `target_scripts: { kana: ... }`",
                      self.errors_of(no_reading))

    def test_a_kanji_target_without_a_kana_reading_is_refused(self) -> None:
        bare = {k: v for k, v in EAT.items() if k != "target_scripts"}
        self.assertIn("card zz-9701: a card written in kanji needs its kana "
                      "reading, `target_scripts: { kana: ... }`",
                      self.errors_of(bare))

    def test_a_kana_reading_with_a_kanji_in_it_is_refused(self) -> None:
        errors = self.errors_of(dict(EAT, target_scripts={"kana": "食べる様"}))
        self.assertIn("card zz-9701: target_scripts.kana has letters that are not "
                      "in kana: '食べる様'", errors)
        errors = self.errors_of(dict(EAT, target_scripts={"kana": "たべ流"}))
        self.assertTrue(any("not in kana" in e for e in errors), errors)

    def test_a_kana_reading_in_romaji_is_refused(self) -> None:
        errors = self.errors_of(dict(EAT, target_scripts={"kana": "taberu"}))
        self.assertTrue(any("not in kana" in e for e in errors), errors)

    def test_a_kana_reading_that_is_the_target_is_refused(self) -> None:
        errors = self.errors_of(dict(THANKS, target_scripts={"kana": "ありがとう"}))
        self.assertTrue(any("is the same as target" in e for e in errors), errors)

    def test_kana_is_a_key_only_where_the_block_lists_it(self) -> None:
        language = dict(JAPANESE, scripts=["han", "han_traditional"])
        errors = self.errors_of(EAT, language=language)
        self.assertTrue(any("target_scripts key 'kana' is not one of the "
                            "language's other scripts" in e for e in errors), errors)

    def test_a_chinese_han_deck_needs_no_kana(self) -> None:
        language = dict(JAPANESE, scripts=["han", "han_traditional"])
        book = {"id": "zz-9705", "target": "书", "reading": "shū", "native": "book",
                "target_scripts": {"han_traditional": "書"}}
        self.assertEqual(self.errors_of(book, language=language), [])

    def test_an_older_kana_deck_is_unchanged(self) -> None:
        language = dict(LANGUAGE, script="kana", tts="ja-JP", icon="日")
        self.assertEqual(self.errors_of(THANKS, language=language), [])


if __name__ == "__main__":
    unittest.main()
