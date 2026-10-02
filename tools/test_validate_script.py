#!/usr/bin/env python3
"""Script guides (#30, ADR-0016): a script's recurring features, checked on
their own. Described in docs/DECK-FORMAT.md."""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import validate_decks

GOOD = """\
schema: 1
kind: script
id: bn-script
language: bn
name: "How Bengali script works"
intro: "Most of what looks strange is a few ideas used again and again."
features:
  - id: headline
    name: "The headline"
    term: "মাত্রা"
    reading: "matra"
    example: "ক"
    text: "Most letters hang from a line along the top."
    letters: ["ক", "ঘ", "ত"]
  - id: knot
    name: "The knot"
    example: "ত"
    text: "A small loop that tells letters apart."
"""


class ScriptGuideTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir)

    def errors(self, text: str, name: str = "bn-script", folder: str = "bn") -> list[str]:
        (self.dir / folder).mkdir(exist_ok=True)
        path = self.dir / folder / f"{name}.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path).errors

    def test_a_good_guide_passes(self) -> None:
        self.assertEqual(self.errors(GOOD), [])

    def test_the_id_follows_the_language_and_the_folder(self) -> None:
        self.assertTrue(any("bn-script" in e for e in self.errors(
            GOOD.replace("id: bn-script", "id: bengali"), name="bengali")))
        self.assertTrue(any("is in hi/" in e for e in self.errors(GOOD, folder="hi")))

    def test_a_guide_needs_a_name_an_intro_and_features(self) -> None:
        self.assertTrue(any("name" in e for e in self.errors(
            GOOD.replace('name: "How Bengali script works"', 'name: ""'))))
        self.assertTrue(any("intro" in e for e in self.errors(
            GOOD.replace('intro: "Most of what looks strange is a few ideas used again and again."\n', ''))))
        self.assertTrue(any("non-empty list" in e for e in self.errors(
            GOOD.split("features:")[0] + "features: []\n")))

    def test_a_feature_needs_an_id_a_name_an_example_and_text(self) -> None:
        self.assertTrue(any("listed twice" in e for e in self.errors(
            GOOD.replace("id: knot", "id: headline"))))
        self.assertTrue(any("needs example" in e for e in self.errors(
            GOOD.replace('    example: "ত"\n', ''))))
        self.assertTrue(any("term" in e for e in self.errors(
            GOOD.replace('term: "মাত্রা"', 'term: ""'))))
        self.assertTrue(any("needs a term" in e for e in self.errors(
            GOOD.replace('    term: "মাত্রা"\n', ''))))
        self.assertTrue(any("reading" in e for e in self.errors(
            GOOD.replace('reading: "matra"', 'reading: ""'))))
        self.assertTrue(any("letters" in e for e in self.errors(
            GOOD.replace('letters: ["ক", "ঘ", "ত"]', 'letters: "ক"'))))

    def test_unknown_fields_fail(self) -> None:
        self.assertTrue(any("unknown field" in e for e in self.errors(GOOD + "extra: 1\n")))


if __name__ == "__main__":
    unittest.main()
