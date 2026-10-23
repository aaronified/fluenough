#!/usr/bin/env python3
"""Tests for tools/convert_modes.py: every list becomes its complement over the
four vocabulary skills, never names a grammar skill, and nothing else moves.
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import convert_modes


def one(card: str) -> str:
    return "cards:\n" + card


def marked(text: str) -> str:
    return convert_modes.MARKER + "\n" + text


class ComplementTest(unittest.TestCase):
    def test_a_list_becomes_the_skills_it_left_out(self) -> None:
        self.assertEqual(convert_modes.complement(["recognition"]),
                         ["production", "listening", "speaking"])
        self.assertEqual(convert_modes.complement(["recognition", "production"]),
                         ["listening", "speaking"])

    def test_the_order_is_the_skills_order_whatever_the_list_order(self) -> None:
        self.assertEqual(convert_modes.complement(["speaking", "recognition"]),
                         ["production", "listening"])

    def test_no_grammar_skill_is_ever_written(self) -> None:
        for allowed in (["grammar"], ["grammarUnderstood", "recognition"], []):
            out = convert_modes.complement(allowed)
            self.assertFalse({"grammar", "grammarUnderstood"} & set(out))

    def test_a_grammar_only_list_excludes_all_four(self) -> None:
        self.assertEqual(convert_modes.complement(["grammar"]),
                         list(convert_modes.VOCABULARY))


class ConvertTextTest(unittest.TestCase):
    def test_a_block_list_is_rewritten_in_place(self) -> None:
        text = one('  - id: "te-0001"\n    target: "a"\n    modes: ["recognition"]\n    pos: "noun"\n')
        new, changes = convert_modes.convert_text(text)
        self.assertEqual(new, marked(one('  - id: "te-0001"\n    target: "a"\n'
                                         '    modes: ["production", "listening", "speaking"]\n'
                                         '    pos: "noun"\n')))
        self.assertEqual(changes, [{"line": 4, "card": "te-0001",
                                    "old": ["recognition"],
                                    "new": ["production", "listening", "speaking"]}])

    def test_a_list_naming_all_four_is_dropped(self) -> None:
        text = one('  - id: "te-0001"\n    modes: ["recognition", "production", "listening", "speaking"]\n    pos: "noun"\n')
        new, _ = convert_modes.convert_text(text)
        self.assertEqual(new, marked(one('  - id: "te-0001"\n    pos: "noun"\n')))

    def test_a_flow_card_keeps_its_other_fields(self) -> None:
        text = '  - { id: x-1, target: "a", modes: [production] }\n'
        new, _ = convert_modes.convert_text(text)
        self.assertEqual(new, marked('  - { id: x-1, target: "a", modes: ["recognition", "listening", "speaking"] }\n'))

    def test_a_file_without_modes_is_unchanged(self) -> None:
        text = one('  - id: "te-0001"\n    target: "a"\n')
        self.assertEqual(convert_modes.convert_text(text), (text, []))

    def test_a_second_run_is_refused(self) -> None:
        # The conversion is a complement, so it must run exactly once: a
        # second run would flip every list back.
        text = one('  - id: "te-0001"\n    modes: ["recognition"]\n')
        once, _ = convert_modes.convert_text(text)
        with self.assertRaises(ValueError):
            convert_modes.convert_text(once)

    def test_an_empty_list_means_every_skill_and_is_dropped(self) -> None:
        new, changes = convert_modes.convert_text(
            one('  - id: "te-0001"\n    modes: []\n    pos: "noun"\n'))
        self.assertEqual(new, marked(one('  - id: "te-0001"\n    pos: "noun"\n')))
        self.assertEqual(changes[0]["new"], [])

    def test_modes_as_the_first_key_of_a_card_naming_all_four_stops_the_run(self) -> None:
        text = one('  - modes: ["recognition", "production", "listening", "speaking"]\n    id: "a"\n')
        with self.assertRaises(ValueError):
            convert_modes.convert_text(text)

    def test_modes_as_the_first_key_is_converted_when_something_is_left(self) -> None:
        new, _ = convert_modes.convert_text(one('  - modes: ["recognition"]\n    id: "a"\n'))
        self.assertIn('  - modes: ["production", "listening", "speaking"]\n', new)

    def test_a_block_style_list_stops_the_run(self) -> None:
        with self.assertRaises(ValueError):
            convert_modes.convert_text(one('  - id: "a"\n    modes:\n      - recognition\n'))


class ConvertTreeTest(unittest.TestCase):
    def test_report_only_does_not_write_and_write_does(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            deck = root / "te" / "te-a.yaml"
            deck.parent.mkdir()
            deck.write_text(one('  - id: "te-1"\n    modes: ["recognition"]\n'))
            before = deck.read_text()
            results = convert_modes.convert_tree(root, write=False)
            self.assertEqual(deck.read_text(), before)
            self.assertEqual(len(results), 1)
            convert_modes.convert_tree(root, write=True)
            with self.assertRaises(ValueError):
                convert_modes.convert_tree(root, write=True)
            self.assertIn('["production", "listening", "speaking"]', deck.read_text())
            self.assertIn("1 cards in 1 files", convert_modes.report(results, root))


if __name__ == "__main__":
    unittest.main()
