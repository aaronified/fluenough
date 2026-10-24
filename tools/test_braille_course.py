"""The English Braille course (ADR-0043): every card id is kept, every
target is braille, the dots a note names are the dots of its cell, and the
validator takes braille as a notation like the IPA: no reading, no tts and
no B1 plan."""
import re
import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

import validate_decks

QBE = Path(__file__).resolve().parent.parent / "decks" / "qbe"


def cores():
    for f in sorted(QBE.glob("qbe-*.yaml")):
        raw = yaml.safe_load(f.read_text(encoding="utf-8"))
        if raw.get("part") == "core" and raw.get("kind") == "vocab":
            yield f.stem, raw


def layer_cards() -> dict:
    cards = {}
    for f in sorted((QBE / "en").glob("qbe-en-*.yaml")):
        raw = yaml.safe_load(f.read_text(encoding="utf-8"))
        cards.update(raw.get("cards") or {})
    return cards


def dots_of(cell: str) -> str:
    bits = ord(cell) - 0x2800
    return "-".join(str(d) for d in range(1, 9) if bits & (1 << (d - 1)))


class BrailleCourse(unittest.TestCase):
    def _ids_are_kept(self):
        ids = sorted(c["id"] for _, raw in cores() for c in raw["cards"])
        self.assertEqual(ids, [f"qbe-{i:04d}" for i in range(1, 195)])

    def _targets_are_braille_without_a_reading(self):
        for _, raw in cores():
            self.assertEqual(raw["language"]["script"], "braille")
            self.assertNotIn("tts", raw["language"])
            self.assertNotIn("typed", raw["language"])
            for c in raw["cards"]:
                self.assertRegex(c["target"], r"^[⠀-⣿]+$", c["id"])
                self.assertNotIn("reading", c, c["id"])

    def _a_single_cell_note_names_its_dots(self):
        layers = layer_cards()
        for _, raw in cores():
            for c in raw["cards"]:
                if len(c["target"]) != 1:
                    continue
                note = layers[c["id"]]["notes"]["n1"]
                first = re.match(r"Dots? ([0-9-]+)", note)
                self.assertIsNotNone(first, c["id"])
                self.assertEqual(first.group(1), dots_of(c["target"]), c["id"])

    def _every_letter_cell_in_prose_has_its_letter(self):
        letters = {
            c["target"]: layer_cards()[c["id"]]["native"].split(";")[0]
            for stem, raw in cores() if stem.startswith("qbe-letters")
            for c in raw["cards"]
        }
        for cid, entry in layer_cards().items():
            for cell, letter in re.findall(r"([⠀-⣿]) \(([a-z])\)",
                                           entry["notes"]["n1"]):
                self.assertEqual(letters[cell], letter, cid)

    def test_ids_are_kept_and_every_target_and_note_is_braille(self) -> None:
        cases = (
            self._ids_are_kept,
            self._targets_are_braille_without_a_reading,
            self._a_single_cell_note_names_its_dots,
            self._every_letter_cell_in_prose_has_its_letter,
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


DECK = """\
schema: 1
id: qbe-en-probe
name: Probe
language: { code: qbe, iso639_3: eng, name: English Braille, script: braille, icon: "⠃" }
native: { code: en, iso639_3: eng, name: English }
license: CC-BY-SA-4.0
cards:
  - id: qbe-0001
    target: "⠁"
    native: a
"""


class BrailleValidator(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def _a_card_needs_no_reading_and_the_language_no_tts(self):
        (self.tmp / "qbe").mkdir()
        path = self.tmp / "qbe" / "qbe-en-probe.yaml"
        path.write_text(DECK, encoding="utf-8")
        report = validate_decks.validate(path)
        self.assertEqual(report.errors, [])
        self.assertFalse([w for w in report.warnings
                          if "reading" in w or "tts" in w or "script" in w],
                         report.warnings)

    def _braille_is_a_notation(self):
        self.assertIn("braille", validate_decks.SCRIPTS)
        self.assertIn("braille", validate_decks.NO_READING)
        self.assertEqual(validate_decks.NOTATION_SCRIPTS, {"ipa", "braille"})

    def test_braille_is_a_notation_with_no_reading_or_voice(self) -> None:
        cases = (
            self._a_card_needs_no_reading_and_the_language_no_tts,
            self._braille_is_a_notation,
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
