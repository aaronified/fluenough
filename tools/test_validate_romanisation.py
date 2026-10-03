#!/usr/bin/env python3
"""Romanisation (#47): a language's romanisation file, grammar rows'
readings, and every reading in the scheme once the file exists."""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import validate_decks

HEAD = """\
schema: 1
id: {id}
name: Probe
kind: {kind}
language: {{ code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }}
native: {{ code: en, iso639_3: eng, name: English }}
license: CC0-1.0
"""

ROMANISATION = """\
schema: 1
kind: romanisation
id: hi-romanisation
language: hi
scheme: "Popular: lowercase, no length or retroflex marks, spelled as said."
equivalents:
  - ["i", "ee", "ii"]
  - ["u", "oo", "uu"]
  - ["v", "w"]
"""


def grammar(readings: str) -> str:
    return HEAD.format(id="hi-en-grammar-probe", kind="grammar") + """\
pattern:
  name: "Probe"
  slot_name: "person"
  slots: ["मैं", "तुम"]
  prompt: "{lemma} — {slot}"
  entries:
    - lemma: "जाना"
      key: jaanaa
      reading: "jana"
      gloss: "to go"
      forms: { "मैं": "जाता हूँ", "तुम": null }
""" + readings


class Romanisation(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def write(self, name: str, text: str) -> validate_decks.Report:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def assertRejected(self, report: validate_decks.Report, needle: str) -> None:
        self.assertTrue(any(needle in e for e in report.errors),
                        f"expected {needle!r} in {report.errors}")

    def test_a_romanisation_file_is_valid(self) -> None:
        self.assertEqual(self.write("hi-romanisation.yaml", ROMANISATION).errors, [])

    def test_its_groups_are_lowercase_spellings_in_one_group_each(self) -> None:
        for groups, needle in (
            ('  - ["i"]\n', "two or more"),
            ('  - ["i", "Ī"]\n', "lowercase ASCII"),
            ('  - ["i", "ee"]\n  - ["ee", "y"]\n', "already in"),
        ):
            with self.subTest(groups=groups):
                text = ROMANISATION.split("equivalents:\n")[0] + "equivalents:\n" + groups
                self.assertRejected(self.write("hi-romanisation.yaml", text), needle)

    def test_its_name_is_the_language(self) -> None:
        self.assertRejected(self.write("hi-roman.yaml", ROMANISATION), "id")

    def test_grammar_readings_follow_the_forms(self) -> None:
        self.assertEqual(self.write("hi-en-grammar-probe.yaml", grammar(
            '      readings: { "मैं": "jata hun" }\n')).errors, [])
        for readings, needle in (
            ('      readings: { "तुम": "jate ho" }\n', "no form"),
            ('      readings: { "हम": "x" }\n', "not a slot"),
            ('      readings: { "मैं": 3 }\n', "must be a reading"),
            ('      readings: {}\n', "is missing"),
        ):
            with self.subTest(readings=readings):
                self.assertRejected(self.write("hi-en-grammar-probe.yaml",
                                               grammar(readings)), needle)

    def test_with_the_file_every_reading_is_in_the_scheme(self) -> None:
        deck = HEAD.format(id="hi-en-probe", kind="vocab") + """\
cards:
  - id: hi-0001
    target: "थोड़ा"
    native: "a little"
    reading: "thoDaa"
"""
        # Without the language's file, any reading is let through.
        self.assertEqual(self.write("hi-en-probe.yaml", deck).errors, [])
        self.write("hi-romanisation.yaml", ROMANISATION)
        self.assertRejected(self.write("hi-en-probe.yaml", deck),
                            "not in the hi romanisation")
        self.assertEqual(self.write("hi-en-probe.yaml",
                                    deck.replace("thoDaa", "thoda")).errors, [])


if __name__ == "__main__":
    unittest.main()
