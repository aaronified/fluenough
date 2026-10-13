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
    def test_a_vocab_deck_keeps_every_id_and_text(self) -> None:
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

    def test_a_base_meaning_goes_to_the_layer(self) -> None:
        core, layer = split_deck.split_deck(load(VOCAB))
        self.assertEqual(core["cards"][3]["bases"][1],
                         {"word": "వెళ్తాను", "base": "వెళ్ళు", "reading": "veḷḷu"})
        self.assertEqual(layer["cards"]["te-9004"]["bases"], {"వెళ్తాను": "to go"})

    def test_a_ref_stays_a_ref(self) -> None:
        core, layer = split_deck.split_deck(load(VOCAB))
        self.assertEqual(core["cards"][4],
                         {"ref": "te-0001", "notes": [{"id": "n1", "kind": "note"}]})
        self.assertEqual(layer["cards"]["te-0001"],
                         {"native": "door", "notes": {"n1": "In this deck: the front door."}})

    def test_a_pair_becomes_a_pair_note(self) -> None:
        core, layer = split_deck.split_deck(load(VOCAB))
        pen, time = core["cards"][1], core["cards"][2]
        self.assertNotIn("pair", pen)
        # The note does not name the partner: a pair note is added.
        self.assertEqual(pen["notes"], [{"id": "n1", "kind": "note"},
                                        {"id": "pair", "kind": "pair", "ref": "te-9003"}])
        self.assertEqual(layer["cards"]["te-9002"]["notes"]["pair"],
                         "Not to be confused with కాలం (kālam), time.")
        # The note names the partner: it becomes the pair note.
        self.assertEqual(time["notes"], [{"id": "n1", "kind": "pair", "ref": "te-9002"}])
        self.assertEqual(layer["cards"]["te-9003"]["notes"]["n1"],
                         "Not కలం (kalam), pen: the a is long.")

    def test_a_grammar_deck_keeps_its_keys_and_slots(self) -> None:
        raw = load(GRAMMAR)
        core, layer = split_deck.split_deck(raw)
        self.assertEqual(split_deck.check_deck(raw, core, layer), [])
        self.assertEqual(core["id"], "te-grammar-past")
        self.assertEqual(core["pattern"]["slots"], ["నేను", "నువ్వు"])
        self.assertEqual(core["pattern"]["entries"][0]["key"], "vellu")
        self.assertNotIn("gloss", core["pattern"]["entries"][0])
        self.assertEqual(layer["pattern"]["entries"], {"vellu": "to go"})
        self.assertEqual(layer["pattern"]["notes"], "The past adds -ఆ- (-ā-).")

    def test_a_reading_deck_is_not_split(self) -> None:
        with self.assertRaises(split_deck.SplitError):
            split_deck.split_deck({"kind": "reading", "id": "te-en-reading-x"})

    def test_what_is_written_reads_back(self) -> None:
        core, layer = split_deck.split_deck(load(VOCAB))
        header, above = split_deck._comments(VOCAB)
        text = split_deck.render(core, header, above)
        self.assertEqual(load(text), core)
        self.assertIn("  # --- the house ---\n  - id: \"te-9001\"", text)
        self.assertIn('    native: "home; house"', split_deck.render(layer))
        self.assertEqual(load(split_deck.render(layer)), layer)

    def test_a_guide_merges_back_to_the_file(self) -> None:
        for text in (SCRIPT, SOUNDS):
            raw = load(text)
            core, layer = split_deck.split_guide(raw, split_deck.ENGLISH)
            self.assertEqual(split_deck.check_guide(raw, core, layer), [])
            self.assertEqual(core["id"], raw["id"])
            self.assertEqual(layer["core"], raw["id"])
        core, layer = split_deck.split_guide(load(SCRIPT), split_deck.ENGLISH)
        self.assertEqual(layer["id"], "bn-en-script")
        self.assertNotIn("name", core["features"][0])
        self.assertEqual(layer["features"]["knot"],
                         {"name": "The knot", "text": "A small loop that tells letters apart."})


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

    def test_a_guide_splits_into_files_that_validate(self) -> None:
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

    def test_a_deck_splits_and_the_old_file_goes(self) -> None:
        path = self.write("te/te-en-grammar-past.yaml", GRAMMAR)
        self.assertEqual(self.run_tool(str(path)), 0)
        self.assertFalse(path.exists())
        core = self.dir / "te" / "te-grammar-past.yaml"
        layer = self.dir / "te" / "en" / "te-en-grammar-past.yaml"
        self.assertEqual(load(core.read_text())["part"], "core")
        self.assertEqual(load(layer.read_text())["kind"], "layer")

    def test_check_writes_nothing(self) -> None:
        path = self.write("te/te-en-grammar-past.yaml", GRAMMAR)
        self.assertEqual(self.run_tool("--check", str(path)), 0)
        self.assertTrue(path.exists())
        self.assertFalse((self.dir / "te" / "te-grammar-past.yaml").exists())


class GuideLayerValidationTest(unittest.TestCase):
    """A script guide or sounds core, and its layer (#498)."""

    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir)
        core, layer = split_deck.split_guide(load(SCRIPT), split_deck.ENGLISH)
        self.core, self.layer = split_deck.render(core), split_deck.render(layer)
        core, layer = split_deck.split_guide(load(SOUNDS), split_deck.ENGLISH)
        self.score, self.slayer = split_deck.render(core), split_deck.render(layer)

    def errors(self, core: str, layer: str | None = None, kind: str = "script") -> list[str]:
        (self.dir / "bn" / "en").mkdir(parents=True, exist_ok=True)
        cpath = self.dir / "bn" / f"bn-{kind}.yaml"
        cpath.write_text(core, encoding="utf-8")
        if layer is None:
            return validate_decks.validate(cpath).errors
        lpath = self.dir / "bn" / "en" / f"bn-en-{kind}.yaml"
        lpath.write_text(layer, encoding="utf-8")
        return validate_decks.validate(lpath).errors

    def test_a_good_core_and_layer_pass(self) -> None:
        self.assertEqual(self.errors(self.core), [])
        self.assertEqual(self.errors(self.core, self.layer), [])
        self.assertEqual(self.errors(self.score, kind="sounds"), [])
        self.assertEqual(self.errors(self.score, self.slayer, kind="sounds"), [])

    def test_a_core_gives_no_text(self) -> None:
        bad = self.core.replace('features:', 'name: "x"\nfeatures:')
        self.assertTrue(any("in each layer" in e for e in self.errors(bad)))
        bad = self.core.replace('example: "ত"', 'example: "ত"\n    text: "x"')
        self.assertTrue(any("in each layer" in e for e in self.errors(bad)))
        bad = self.score.replace('pairs: [["ক"', 'name: "x"\n    pairs: [["ক"')
        self.assertTrue(any("in each layer" in e for e in self.errors(bad, kind="sounds")))

    def test_a_layer_gives_every_text_and_no_other(self) -> None:
        missing = self.layer.split('  "knot":')[0]
        self.assertTrue(any("gives no text for 'knot'" in e
                            for e in self.errors(self.core, missing)))
        other = self.layer.replace('"knot":', '"loop":')
        self.assertTrue(any("not one of the core's features" in e
                            for e in self.errors(self.core, other)))
        extra = self.layer.replace('name: "The knot"', 'name: "The knot"\n    example: "ত"')
        self.assertTrue(any("unknown field 'example'" in e
                            for e in self.errors(self.core, extra)))
        blank = self.slayer.replace('"the open o against a"', '""')
        self.assertTrue(any("required text" in e
                            for e in self.errors(self.score, blank, kind="sounds")))

    def test_a_layer_has_its_id_and_folder(self) -> None:
        bad = self.layer.replace('id: "bn-en-script"', 'id: "bn-en-guide"')
        self.assertTrue(any("filename stem" in e for e in self.errors(self.core, bad)))

    def test_its_prose_carries_readings(self) -> None:
        bad = self.layer.replace("along the top.", "along the top, as in ক.")
        self.assertTrue(any("transliteration" in e for e in self.errors(self.core, bad)))


if __name__ == "__main__":
    unittest.main()
