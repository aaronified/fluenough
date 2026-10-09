#!/usr/bin/env python3
"""Decks the app's parser rejects must fail validation too.

`lib/core/data/deck_parser.dart` is built never to reject a deck this validator
accepts, because a deck that passes CI and then fails on a device is invisible
until someone opens the app. These are the cases where PyYAML or Python used to
be more lenient than the parser.

Stdlib `unittest` plus PyYAML, like the validator itself.
"""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

import validate_decks

DECK = """\
schema: 1
id: es-en-probe
name: Probe
language: {{ code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }}
native: {{ code: en, iso639_3: eng, name: English }}
license: CC0-1.0
cards:
  - id: {card_id}
    target: la casa
    native: the house
{extra}"""


def deck(card_id: str = "es-0001", extra: str = "") -> str:
    return DECK.format(card_id=card_id, extra=extra)


class ParserParity(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def errors(self, text: str) -> list[str]:
        path = self.tmp / "es-en-probe.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path).errors

    def assertRejected(self, text: str, needle: str) -> None:
        errors = self.errors(text)
        self.assertTrue(
            any(needle in e for e in errors),
            f"expected an error containing {needle!r}, got {errors}",
        )

    def test_the_probe_deck_is_valid(self) -> None:
        self.assertEqual(self.errors(deck()), [])

    def test_a_duplicate_key_is_rejected(self) -> None:
        self.assertRejected(deck() + "name: Probe again\n", "duplicate key 'name'")

    def test_a_duplicate_key_inside_a_card_is_rejected(self) -> None:
        self.assertRejected(deck(extra="    native: the home\n"), "duplicate key 'native'")

    def test_a_merge_key_is_rejected(self) -> None:
        text = deck().replace(
            "native: { code: en, iso639_3: eng, name: English }",
            "base: &en { code: en, iso639_3: eng, name: English }\nnative: { <<: *en }",
        )
        self.assertRejected(text, "merge key")

    def test_a_boolean_schema_is_rejected(self) -> None:
        for value in ("true", "yes", "on"):
            with self.subTest(value=value):
                self.assertRejected(deck().replace("schema: 1", f"schema: {value}"), "schema")

    def test_an_id_ending_in_a_newline_is_rejected(self) -> None:
        self.assertRejected(deck(card_id='"es-0001\\n"'), "id must be")

    def test_a_code_or_tts_tag_ending_in_a_newline_is_rejected(self) -> None:
        cases = {
            "code": ("code: es,", 'code: "es\\n",', "code must be"),
            "tts": ("tts: es-ES", 'tts: "es-ES\\n"', "tts must be"),
        }
        for name, (old, new, needle) in cases.items():
            with self.subTest(name):
                self.assertRejected(deck().replace(old, new, 1), needle)

    def test_free_text_that_is_not_text_is_rejected(self) -> None:
        cases = {
            "notes on a card": deck(extra="    notes: 1990\n"),
            "gender on a card": deck(extra="    gender: 1\n"),
            "audio on a card": deck(extra="    audio: true\n"),
            "description": deck() + "description: 2019\n",
            "source": deck() + "source: 2019\n",
            "an author url": deck() + "authors: [{ name: A, url: 5 }]\n",
        }
        for name, text in cases.items():
            with self.subTest(name):
                self.assertRejected(text, "not text")

    def test_free_text_that_is_a_list_or_mapping_is_rejected(self) -> None:
        # Notes may now be a list of typed notes (ADR-0036), each a mapping.
        for value, needle in (("[a]", "notes[0] must be a mapping"),
                              ("{ a: b }", "must be text")):
            with self.subTest(value=value):
                self.assertRejected(deck(extra=f"    notes: {value}\n"), needle)
        self.assertRejected(deck(extra="    gender: [a]\n"), "must be text")

    def test_pattern_notes_that_are_not_text_are_rejected(self) -> None:
        text = """\
schema: 1
id: es-en-probe
name: Probe
kind: grammar
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
pattern:
  name: P
  slot_name: person
  slots: [yo]
  prompt: "{lemma} ({gloss}) {slot}"
  notes: 1990
  entries:
    - { lemma: hablar, gloss: to speak, forms: { yo: hablo } }
"""
        self.assertRejected(text, "not text")

    def test_the_native_block_is_checked_like_language(self) -> None:
        cases = {
            "rtl as text": '{ code: en, iso639_3: eng, name: English, rtl: "yes" }',
            "an empty script": '{ code: en, iso639_3: eng, name: English, script: "" }',
            "a bad tts tag": '{ code: en, iso639_3: eng, name: English, tts: "en_GB" }',
        }
        for name, block in cases.items():
            with self.subTest(name):
                text = deck().replace(
                    "native: { code: en, iso639_3: eng, name: English }", f"native: {block}"
                )
                self.assertTrue(self.errors(text), f"{name} was accepted")


class PlainScalars(unittest.TestCase):
    """The validator reads plain (unquoted) scalars as YAML 1.2's core schema
    does, which is how the app's `package:yaml` reads them (ADR-0036). One
    case per row of the table in docs/DECK-FORMAT.md, "YAML values"; each
    value here was checked against `package:yaml` 3.1 (`loadYaml`), which
    agrees with the table in every case."""

    def read(self, scalar: str) -> object:
        return yaml.load(f"k: {scalar}\n", Loader=validate_decks.DeckLoader)["k"]

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def errors(self, text: str) -> list[str]:
        path = self.tmp / "es-en-probe.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path).errors

    def test_true_and_false_in_three_spellings_are_booleans(self) -> None:
        for scalar, value in (("true", True), ("True", True), ("TRUE", True),
                              ("false", False), ("False", False), ("FALSE", False)):
            with self.subTest(scalar=scalar):
                self.assertIs(self.read(scalar), value)
        rtl = "native: { code: en, iso639_3: eng, name: English, rtl: True }"
        self.assertEqual(self.errors(deck().replace(
            "native: { code: en, iso639_3: eng, name: English }", rtl)), [])

    def test_digits_are_a_decimal_integer(self) -> None:
        for scalar, value in (("060", 60), ("-5", -5), ("+7", 7), ("00", 0), ("1", 1)):
            with self.subTest(scalar=scalar):
                self.assertEqual(self.read(scalar), value)
                self.assertIs(type(self.read(scalar)), int)
        # 060 is 60, not YAML 1.1's octal 48, to both readers.
        self.assertEqual(self.errors(deck().replace("schema: 1", "schema: 01")), [])

    def test_0o_and_0x_are_octal_and_hexadecimal(self) -> None:
        self.assertEqual(self.read("0o17"), 15)
        self.assertEqual(self.read("0x1F"), 31)
        self.assertEqual(self.read("0x1f"), 31)
        self.assertEqual(self.errors(deck().replace("schema: 1", "schema: 0x1")), [])

    def test_decimals_and_infinities_are_floats(self) -> None:
        for scalar, value in (("1.5", 1.5), (".5", 0.5), ("1.", 1.0), ("1e3", 1000.0),
                              ("-1.5e-3", -0.0015), ("+.5", 0.5), (".inf", float("inf")),
                              ("-.Inf", float("-inf")), ("+.INF", float("inf"))):
            with self.subTest(scalar=scalar):
                self.assertEqual(self.read(scalar), value)
                self.assertIs(type(self.read(scalar)), float)
        for scalar in (".nan", ".NaN", ".NAN"):
            value = self.read(scalar)
            self.assertNotEqual(value, value)
        self.assertTrue(any("not text" in e
                            for e in self.errors(deck(extra="    gender: 1.5\n"))))

    def test_null_in_its_spellings_is_null(self) -> None:
        for scalar in ("null", "Null", "NULL", "~", ""):
            with self.subTest(scalar=scalar):
                self.assertIsNone(self.read(scalar))
        # A null reading is a reading left out.
        self.assertEqual(self.errors(deck(extra="    gender: ~\n")), [])

    def test_anything_else_is_a_string(self) -> None:
        for scalar in ("yes", "no", "on", "off", "y", "n", "Yes", "NO", "1_000", "1:30",
                       "0b101", "2001-12-14", "tRUE", "nULL", "-.nan", "+0x1F", "0O17",
                       "1e", "."):
            with self.subTest(scalar=scalar):
                self.assertEqual(self.read(scalar), scalar)
        # The hiragana の romanises to no: a bare no is that text now, as
        # in the app; YAML 1.1 read it as false.
        self.assertEqual(self.errors(deck(extra="    reading: no\n")), [])
        self.assertTrue(any("schema" in e
                            for e in self.errors(deck().replace("schema: 1",
                                                                "schema: 1_000"))))
        # A bare yes where a boolean is wanted is refused by both readers.
        self.assertTrue(any("phrasebook must be true" in e
                            for e in self.errors(deck(extra="    phrasebook: yes\n"))))

    def test_a_plain_key_resolves_as_a_value_does(self) -> None:
        keys = yaml.load("on: 1\nno: 2\n7: 3\nfalse: 4\n",
                         Loader=validate_decks.DeckLoader)
        self.assertEqual(list(keys), ["on", "no", 7, False])


if __name__ == "__main__":
    unittest.main()
