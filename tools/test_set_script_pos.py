#!/usr/bin/env python3
"""Tests for tools/set_script_pos.py."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import set_script_pos

CARDS = '''cards:
  - id: "te-1"
    target: "అ"
    reading: "a"
    ipa: "a"
    notes:
      - { id: "n1", kind: "note" }
  - id: "te-2"
    target: "ఆ"
    pos: "noun"
    modes: ["production"]
'''


class SetKeyTest(unittest.TestCase):
    def test_a_card_with_no_pos_gets_it_after_its_ipa(self) -> None:
        new, changes = set_script_pos.set_key(CARDS, "pos", "letter")
        self.assertIn('    ipa: "a"\n    pos: "letter"\n    notes:', new)
        self.assertEqual(changes[0], {"card": "te-1", "old": None, "new": "letter"})

    def test_a_card_with_another_pos_is_left_and_reported(self) -> None:
        new, changes = set_script_pos.set_key(CARDS, "pos", "letter")
        self.assertIn('    target: "ఆ"\n    pos: "noun"\n', new)
        self.assertEqual(changes[1], {"card": "te-2", "old": "noun", "new": None})

    def test_hears_goes_after_the_pos_it_has(self) -> None:
        new, _ = set_script_pos.set_key(CARDS, "hears", "form")
        self.assertIn('    pos: "noun"\n    hears: "form"\n    modes:', new)
        self.assertIn('    ipa: "a"\n    hears: "form"\n', new)

    def test_a_second_run_changes_nothing(self) -> None:
        once, _ = set_script_pos.set_key(CARDS, "pos", "letter")
        twice, changes = set_script_pos.set_key(once, "pos", "letter")
        self.assertEqual(once, twice)
        self.assertEqual([c for c in changes if c["new"]], [])

    def test_only_the_cards_are_touched(self) -> None:
        text = 'schema: 1\nid: "te-x"\n' + CARDS
        new, _ = set_script_pos.set_key(text, "pos", "letter")
        self.assertTrue(new.startswith('schema: 1\nid: "te-x"\ncards:\n'))


class ValueTest(unittest.TestCase):
    def test_letters_digits_and_words_are_told_apart(self) -> None:
        v = set_script_pos.value_for
        self.assertEqual(v("pos", "te-script-vowels"), "letter")
        self.assertEqual(v("pos", "hi-script-perso-arabic-shapes"), "letter")
        self.assertEqual(v("pos", "te-script-digits"), "digit")
        self.assertIsNone(v("pos", "te-spelling"))
        self.assertIsNone(v("pos", "te-script-reading"))
        self.assertEqual(v("hears", "te-spelling"), "form")
        self.assertEqual(v("hears", "hi-script-perso-arabic-reading"), "form")
        self.assertIsNone(v("hears", "te-script-vowels"))


class TreeTest(unittest.TestCase):
    def test_each_pass_marks_its_own_decks_and_no_others(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            lang = root / "te"
            lang.mkdir()
            names = ("te-script-vowels", "te-script-digits", "te-spelling",
                     "te-script-reading", "te-words")
            (lang / "te-path.yaml").write_text(
                "alphabet:\n" + "".join(f'  - "{n}"\n' for n in names[:4]))
            for name in names:
                (lang / f"{name}.yaml").write_text(
                    f'schema: 1\nid: "{name}"\npart: "core"\nkind: "vocab"\n'
                    'cards:\n  - id: "te-1"\n    target: "x"\n')
            results, left = set_script_pos.convert_tree(root, "pos", write=True)
            self.assertEqual(sorted(r["deck"] for r in results),
                             ["te-script-digits", "te-script-vowels"])
            self.assertEqual(left, ["te-script-reading", "te-spelling"])
            self.assertIn('pos: "digit"', (lang / "te-script-digits.yaml").read_text())
            self.assertNotIn("pos:", (lang / "te-spelling.yaml").read_text())
            results, _ = set_script_pos.convert_tree(root, "hears", write=True)
            self.assertEqual(sorted(r["deck"] for r in results),
                             ["te-script-reading", "te-spelling"])
            self.assertIn('hears: "form"', (lang / "te-spelling.yaml").read_text())
            self.assertNotIn("hears:", (lang / "te-words.yaml").read_text())


if __name__ == "__main__":
    unittest.main()
