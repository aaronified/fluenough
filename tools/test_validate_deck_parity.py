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

import validate_decks

DECK = """\
schema: 1
id: xx-probe
name: Probe
language: {{ code: es, name: Spanish, script: latin, tts: es-ES }}
native: {{ code: en, name: English }}
license: CC0-1.0
cards:
  - id: {card_id}
    target: la casa
    native: the house
{extra}"""


def deck(card_id: str = "xx-probe-0001", extra: str = "") -> str:
    return DECK.format(card_id=card_id, extra=extra)


class ParserParity(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def errors(self, text: str) -> list[str]:
        path = self.tmp / "xx-probe.yaml"
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
            "native: { code: en, name: English }",
            "base: &en { code: en, name: English }\nnative: { <<: *en }",
        )
        self.assertRejected(text, "merge key")

    def test_a_boolean_schema_is_rejected(self) -> None:
        for value in ("true", "yes", "on"):
            with self.subTest(value=value):
                self.assertRejected(deck().replace("schema: 1", f"schema: {value}"), "schema")

    def test_an_id_ending_in_a_newline_is_rejected(self) -> None:
        self.assertRejected(deck(card_id='"xx-probe-0001\\n"'), "id must match")

    def test_free_text_that_is_not_text_is_rejected(self) -> None:
        cases = {
            "notes on a card": deck(extra="    notes: 1990\n"),
            "gender on a card": deck(extra="    gender: 1\n"),
            "audio on a card": deck(extra="    audio: yes\n"),
            "description": deck() + "description: 2019\n",
            "source": deck() + "source: 2019\n",
            "an author url": deck() + "authors: [{ name: A, url: 5 }]\n",
        }
        for name, text in cases.items():
            with self.subTest(name):
                self.assertRejected(text, "not text")

    def test_pattern_notes_that_are_not_text_are_rejected(self) -> None:
        text = """\
schema: 1
id: xx-probe
name: Probe
kind: grammar
language: { code: es, name: Spanish, script: latin, tts: es-ES }
native: { code: en, name: English }
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
            "rtl as text": '{ code: en, name: English, rtl: "yes" }',
            "an empty script": '{ code: en, name: English, script: "" }',
            "a bad tts tag": '{ code: en, name: English, tts: "en_GB" }',
        }
        for name, block in cases.items():
            with self.subTest(name):
                text = deck().replace("native: { code: en, name: English }", f"native: {block}")
                self.assertTrue(self.errors(text), f"{name} was accepted")


if __name__ == "__main__":
    unittest.main()
