#!/usr/bin/env python3
"""tools/split_deck.py (#397, #498): a single-file deck split into a core
and a layer keeps every card id and every text, and the two files pass the
validator. Script guides and sounds files split the same way."""

from __future__ import annotations

import contextlib
import io
import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

import split_deck
import validate_decks

VOCAB = """\
schema: 1
id: te-en-home
name: "Home"
kind: vocab
language: { code: te, iso639_3: tel, name: Telugu, script: telugu, tts: te-IN }
native:   { code: en, iso639_3: eng, name: English }
license: "CC-BY-SA-4.0"
description: "Rooms and the house."
theme: home
tags: [beginner, unreviewed]
cards:
  # --- the house ---
  - id: te-9001
    target: "ఇల్లు"
    native: "home; house"
    reading: "illu"
    ipa: "illu"
    pos: noun
    wiktionary: true
    notes: "Before an ending it becomes ఇంటి- (iṇṭi-)."
  - id: te-9002
    target: "కలం"
    native: "pen"
    reading: "kalam"
    notes: "The circle ం (am) is an m."
    pair: te-9003
  - id: te-9003
    target: "కాలం"
    native: "time"
    reading: "kālam"
    notes: "Not కలం (kalam), pen: the a is long."
    pair: te-9002
  - id: te-9004
    target: "ఇంటికి వెళ్తాను"
    native: "I will go home"
    reading: "iṇṭiki veḷtānu"
    pos: phrase
    bases:
      - { word: "ఇంటికి", ref: te-9001 }
      - { word: "వెళ్తాను", base: "వెళ్ళు", reading: "veḷḷu", meaning: "to go" }
  - ref: te-0001
    native: "door"
    notes: "In this deck: the front door."
"""

GRAMMAR = """\
schema: 1
id: te-en-grammar-past
name: "Past tense"
kind: grammar
language: { code: te, iso639_3: tel, name: Telugu, script: telugu, tts: te-IN }
native:   { code: en, iso639_3: eng, name: English }
license: "CC-BY-SA-4.0"
tags: [grammar]
pattern:
  name: "Simple past"
  slot_name: "person"
  slots: ["నేను", "నువ్వు"]
  prompt: "{lemma} ({gloss}) — {slot}"
  notes: "The past adds -ఆ- (-ā-)."
  entries:
    - lemma: "వెళ్ళు"
      key: vellu
      reading: "veḷḷu"
      gloss: "to go"
      forms: { "నేను": "వెళ్ళాను", "నువ్వు": "వెళ్ళావు" }
      readings: { "నేను": "veḷḷānu", "నువ్వు": "veḷḷāvu" }
"""

SCRIPT = """\
# How Bengali script works.
schema: 1
kind: script
id: bn-script
language: bn
name: "How Bengali script works"
intro: "A few ideas come back in letter after letter."
features:
  - id: headline
    name: "The headline"
    term: "মাত্রা"
    reading: "mātrā"
    example: "ক"
    text: "Most letters hang from a line along the top."
    letters: ["ক", "ঘ"]
  - id: knot
    name: "The knot"
    example: "ত"
    text: "A small loop that tells letters apart."
"""

SOUNDS = """\
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


def load(text: str) -> dict:
    return yaml.load(text, Loader=validate_decks.DeckLoader)


class SplitDeckTest(unittest.TestCase):
    def _a_vocab_deck_keeps_every_id_and_text(self) -> None:
        raw = load(VOCAB)
        core, layer = split_deck.split_deck(raw)
        self.assertEqual(split_deck.check_deck(raw, core, layer), [])
        self.assertEqual(core["id"], "te-home")
        self.assertEqual(core["part"], "core")
        self.assertEqual(core["theme"], "home")
        self.assertNotIn("native", core)
        self.assertEqual(layer["id"], "te-en-home")
        self.assertEqual(layer["core"], "te-home")
        self.assertEqual(layer["description"], "Rooms and the house.")
        self.assertEqual([c.get("id", c.get("ref")) for c in core["cards"]],
                         ["te-9001", "te-9002", "te-9003", "te-9004", "te-0001"])
        house = core["cards"][0]
        self.assertNotIn("native", house)
        self.assertNotIn("wiktionary", house)
        self.assertEqual(house["notes"], [{"id": "n1", "kind": "note"}])
        self.assertEqual(layer["cards"]["te-9001"], {
            "native": "home; house", "wiktionary": True,
            "notes": {"n1": "Before an ending it becomes ఇంటి- (iṇṭi-)."}})


    def _a_reading_deck_is_not_split(self) -> None:
        with self.assertRaises(split_deck.SplitError):
            split_deck.split_deck({"kind": "reading", "id": "te-en-reading-x"})


    def test_a_split_keeps_every_id_and_text_and_a_reading_deck_is_not_split(self) -> None:
        cases = (
            self._a_vocab_deck_keeps_every_id_and_text,
            self._a_reading_deck_is_not_split,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


class SplitFilesTest(unittest.TestCase):
    """The tool on files: the old one goes, the two new ones validate."""

    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir)

    def run_tool(self, *args: str) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return split_deck.main(list(args))

    def write(self, rel: str, text: str) -> Path:
        path = self.dir / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def _a_guide_splits_into_files_that_validate(self) -> None:
        for name, text in (("bn-script", SCRIPT), ("bn-sounds", SOUNDS)):
            path = self.write(f"bn/{name}.yaml", text)
            self.assertEqual(self.run_tool(str(path)), 0)
            layer = self.dir / "bn" / "en" / f"bn-en-{name.split('-')[1]}.yaml"
            self.assertTrue(path.exists() and layer.exists())
            if name == "bn-script":
                # The comments at the top stay with the core.
                self.assertIn("# How Bengali script works.", path.read_text())
            for p in (path, layer):
                self.assertEqual(validate_decks.validate(p).errors, [], p)

    def _a_deck_splits_and_the_old_file_goes(self) -> None:
        path = self.write("te/te-en-grammar-past.yaml", GRAMMAR)
        self.assertEqual(self.run_tool(str(path)), 0)
        self.assertFalse(path.exists())
        core = self.dir / "te" / "te-grammar-past.yaml"
        layer = self.dir / "te" / "en" / "te-en-grammar-past.yaml"
        self.assertEqual(load(core.read_text())["part"], "core")
        self.assertEqual(load(layer.read_text())["kind"], "layer")


    def test_the_files_validate(self) -> None:
        cases = (
            self._a_guide_splits_into_files_that_validate,
            self._a_deck_splits_and_the_old_file_goes,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


if __name__ == "__main__":
    unittest.main()
