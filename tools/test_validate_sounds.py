#!/usr/bin/env python3
"""Sounds files (#89, ADR-0015): a language's sound contrasts, checked on
their own. Described in docs/DECK-FORMAT.md."""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import validate_decks

GOOD = """\
schema: 1
kind: sounds
id: bn-sounds
language: bn
contrasts:
  - id: aspiration
    name: "a breath after the consonant"
    pairs: [["ক", "খ"], ["ব", "ভ"]]
  - id: inherent-vowel
    name: "the open o against a"
    within_word: true
    pairs: [["", "া"]]
"""


class SoundsFileTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp())
        (self.dir / "bn").mkdir()
        self.addCleanup(shutil.rmtree, self.dir)

    def errors(self, text: str, name: str = "bn-sounds", folder: str = "bn") -> list[str]:
        (self.dir / folder).mkdir(exist_ok=True)
        path = self.dir / folder / f"{name}.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path).errors

    def test_a_good_file_passes(self) -> None:
        self.assertEqual(self.errors(GOOD), [])

    def test_the_id_follows_the_language_and_the_folder(self) -> None:
        self.assertTrue(any("bn-sounds" in e for e in self.errors(
            GOOD.replace("id: bn-sounds", "id: bengali-sounds"),
            name="bengali-sounds")))
        self.assertTrue(any("is in hi/" in e for e in self.errors(
            GOOD, folder="hi")))

    def test_a_contrast_needs_an_id_a_name_and_pairs(self) -> None:
        self.assertTrue(any("listed twice" in e for e in self.errors(
            GOOD.replace("id: inherent-vowel", "id: aspiration"))))
        self.assertTrue(any("needs a name" in e for e in self.errors(
            GOOD.replace('name: "a breath after the consonant"', 'name: ""'))))
        self.assertTrue(any("non-empty list" in e for e in self.errors(
            GOOD.replace('pairs: [["", "া"]]', "pairs: []"))))

    def test_a_pair_is_two_different_strings_at_most_one_empty(self) -> None:
        for bad in ('[["ক"]]', '[["ক", "ক"]]', '[["", ""]]', '[["ক", 1]]'):
            with self.subTest(bad):
                self.assertTrue(any("two different quoted strings" in e
                                    for e in self.errors(GOOD.replace(
                                        '[["", "া"]]', bad))))

    def test_unknown_fields_and_a_bad_within_word_fail(self) -> None:
        self.assertTrue(any("unknown field" in e for e in self.errors(
            GOOD + "extra: 1\n")))
        self.assertTrue(any("within_word" in e for e in self.errors(
            GOOD.replace("within_word: true", "within_word: sometimes"))))


if __name__ == "__main__":
    unittest.main()
