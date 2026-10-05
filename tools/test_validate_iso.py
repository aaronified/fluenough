#!/usr/bin/env python3
"""ISO 15919 readings and IPA (ADR-0025): a romanisation file that names the
standard and how its letters are typed, readings in its letters, and every
`ipa` and `ipas` a broad IPA transcription."""

from __future__ import annotations

import shutil
import tempfile
import unicodedata
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
scheme: "ISO 15919 letters, spelled as said."
standard: "ISO 15919"
typed:
{typed}
equivalents:
  - ["i", "ee", "ii"]
"""

TYPED = """\
  - ["ā", "a"]
  - ["ḍ", "d"]
  - ["m̐", ""]"""


def vocab(reading: str, ipa: str) -> str:
    return HEAD.format(id="hi-en-probe", kind="vocab") + f"""\
cards:
  - id: hi-0001
    target: "थोड़ा"
    native: "a little"
    reading: "{reading}"
    ipa: "{ipa}"
"""


def grammar(ipas: str) -> str:
    return HEAD.format(id="hi-en-grammar-probe", kind="grammar") + """\
pattern:
  name: "Probe"
  slot_name: "person"
  slots: ["मैं", "तुम"]
  prompt: "{lemma} — {slot}"
  entries:
    - lemma: "जाना"
      key: jaanaa
      reading: "jānā"
      gloss: "to go"
      forms: { "मैं": "जाता हूँ", "तुम": null }
      readings: { "मैं": "jātā hū̃" }
""" + ipas


class IsoAndIpa(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def write(self, name: str, text: str) -> validate_decks.Report:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def romanisation(self, typed: str = TYPED) -> validate_decks.Report:
        return self.write("hi-romanisation.yaml", ROMANISATION.format(typed=typed))

    def assertRejected(self, report: validate_decks.Report, needle: str) -> None:
        self.assertTrue(any(needle in e for e in report.errors),
                        f"expected {needle!r} in {report.errors}")

    def test_an_iso_romanisation_file_is_valid(self) -> None:
        self.assertEqual(self.romanisation().errors, [])

    def test_iso_15919_is_the_one_standard(self) -> None:
        text = ROMANISATION.format(typed=TYPED).replace(
            '"ISO 15919"', '"IAST"')
        self.assertRejected(self.write("hi-romanisation.yaml", text),
                            "the one standard known is 'ISO 15919'")

    def test_typed_needs_the_standard(self) -> None:
        text = ROMANISATION.format(typed=TYPED).replace(
            'standard: "ISO 15919"\n', "")
        self.assertRejected(self.write("hi-romanisation.yaml", text),
                            "name the standard")

    def test_typed_pairs_are_iso_letters_and_how_they_are_typed(self) -> None:
        for typed, needle in (
            ('  - ["ā"]', "must be a pair"),
            ('  - ["ā", "a", "aa"]', "must be a pair"),
            ('  - ["Ā", "a"]', "must be ISO 15919 letters"),
            ('  - ["ä", "a"]', "must be ISO 15919 letters"),
            ('  - ["ā", "A"]', "must be lowercase ASCII"),
            ('  - ["ā", "â"]', "must be lowercase ASCII"),
        ):
            with self.subTest(typed=typed):
                self.assertRejected(self.romanisation(typed), needle)

    def test_with_the_standard_readings_are_iso_letters(self) -> None:
        self.romanisation()
        self.assertEqual(
            self.write("hi-en-probe.yaml", vocab("thoṛā", "tʰoɽaː")).errors, [])
        for reading in ("Thoṛā", "thoṛä"):
            with self.subTest(reading=reading):
                self.assertRejected(
                    self.write("hi-en-probe.yaml", vocab(reading, "tʰoɽaː")),
                    "lowercase ISO 15919 letters")
        decomposed = unicodedata.normalize("NFD", "thoṛā")
        self.assertRejected(
            self.write("hi-en-probe.yaml", vocab(decomposed, "tʰoɽaː")),
            "not NFC-normalised")

    def test_an_ipa_is_broad_ipa_without_slashes(self) -> None:
        self.assertEqual(
            self.write("hi-en-probe.yaml", vocab("thora", "tʰoɽaː")).errors, [])
        for ipa, needle in (
            ("/tʰoɽaː/", "not a broad IPA transcription"),
            ("[tʰoɽaː]", "not a broad IPA transcription"),
            (" tʰoɽaː", "not a broad IPA transcription"),
            ("thoda", None),
            (unicodedata.normalize("NFD", "hũː"), "not NFC-normalised"),
        ):
            with self.subTest(ipa=ipa):
                report = self.write("hi-en-probe.yaml", vocab("thora", ipa))
                if needle is None:
                    # Plain letters are IPA letters too.
                    self.assertEqual(report.errors, [])
                else:
                    self.assertRejected(report, needle)

    def test_a_grammar_entry_gives_each_form_its_ipa(self) -> None:
        self.assertEqual(self.write("hi-en-grammar-probe.yaml", grammar(
            '      ipas: { "मैं": "dʒaːtaː hũː" }\n')).errors, [])
        for ipas, needle in (
            ('      ipas: { "तुम": "dʒaːte ho" }\n', "given for a slot with no form"),
            ('      ipas: { "मैं": "dʒaːtaː hũː", "हम": "x" }\n', "not a slot"),
            ('      ipas: {}\n', "is missing; every form has one"),
            ('      ipas: { "मैं": 3 }\n', "must be text"),
            ('      ipas: ["dʒaːtaː hũː"]\n', "must be a mapping"),
            ('      ipas: { "मैं": "/dʒaːtaː hũː/" }\n', "not a broad IPA"),
        ):
            with self.subTest(ipas=ipas):
                self.assertRejected(self.write("hi-en-grammar-probe.yaml",
                                               grammar(ipas)), needle)


if __name__ == "__main__":
    unittest.main()
