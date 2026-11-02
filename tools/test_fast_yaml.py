#!/usr/bin/env python3
"""Reading a deck's YAML the fast way gives what the slow way gave.

tools/validate_decks.py reads each text once, with libyaml where PyYAML has it
(`_fast_load`), and hands every caller a private copy. A deck must read
to the same data, and a broken one fail with the same message, as with the
pure-Python DeckLoader the validator always used. Stdlib `unittest` plus PyYAML.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

import offensive_alikes  # noqa: E402
import validate_decks as vd  # noqa: E402

GOOD = {
    "plain scalars": "a: yes\nb: no\nc: 060\nd: 1_000\ne: 0x1F\nf: 0o17\ng: .inf\nh: ~\ni:\n"
                     "j: 1e3\nk: '1'\nl: true\nm: 1.5\n",
    "nesting": "a:\n  - b: 1\n    c: [1, 2, {d: e}]\n  - [x, y]\nf: {g: h}\n",
    "block scalars": "a: |\n  one\n  two\nb: >\n  three\n  four\n",
    "integer keys": "1: a\n2: b\n",
    "quoted merge key": "'<<': 1\n",
    "anchor and alias": "a: &l [1, 2]\nb: *l\n",
    "unicode": 'a: "\\u0c07\\U0001F600"\nb: ఇల్లు\n',
    "empty": "",
    "explicit tags": "a: !!binary aGk=\nb: !!timestamp 2020-01-01\nc: !!set {x, y}\n",
    "long": "a: " + "x" * 5000 + "\n",
}
BAD = {
    "duplicate key": "a: 1\na: 2\n",
    "merge key": "a: &x {b: 1}\nc:\n  <<: *x\n",
    "syntax": "a: [1,\n",
    "tab": "a:\n\t- 1\n",
    "control character": "a: \x01\n",
    "two documents": "a: 1\n---\nb: 2\n",
    "unknown tag": "a: !foo 1\n",
    "unhashable key": "? [1, 2]\n: x\n",
}


def same(a: object, b: object) -> bool:
    """Equal data of equal types, key order included."""
    if type(a) is not type(b):
        return False
    if isinstance(a, dict):
        return list(a) == list(b) and all(same(a[k], b[k]) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    return a == b


class Reading(unittest.TestCase):
    def test_a_deck_reads_to_the_data_the_pure_loader_gives(self) -> None:
        for name, text in GOOD.items():
            with self.subTest(name):
                self.assertTrue(same(vd._load_deck(text),
                                     yaml.load(text, Loader=vd.DeckLoader)))

    def test_a_broken_deck_fails_with_the_pure_loaders_message(self) -> None:
        for name, text in BAD.items():
            with self.subTest(name):
                with self.assertRaises(yaml.YAMLError) as pure:
                    yaml.load(text, Loader=vd.DeckLoader)
                with self.assertRaises(yaml.YAMLError) as fast:
                    vd._load_deck(text)
                self.assertEqual(str(fast.exception), str(pure.exception))

    def test_every_caller_gets_its_own_copy(self) -> None:
        text = "cards:\n  - id: a\n    notes: [x]\n"
        first = vd._load_deck(text)
        first["cards"][0]["notes"].append("changed")
        first["cards"].append("more")
        self.assertEqual(vd._load_deck(text), {"cards": [{"id": "a", "notes": ["x"]}]})

    def test_a_text_written_again_is_read_again(self) -> None:
        self.assertEqual(vd._load_deck("a: 1\n"), {"a": 1})
        self.assertEqual(vd._load_deck("a: 2\n"), {"a": 2})

    @unittest.skipUnless(getattr(yaml, "__with_libyaml__", False), "PyYAML without libyaml")
    def test_the_safe_loader_is_read_as_it_always_was(self) -> None:
        # offensive_alikes.py reads with yaml.safe_load: YAML 1.1, where `no`
        # is false and a repeated key keeps the last.
        for text in ("a: no\nb: yes\nc: 060\nd: 2020-01-01\n", "a: 1\na: 2\n",
                     "x:\n  - y: [1, 2]\n", "", "a: [1,\n"):
            with self.subTest(text):
                try:
                    want = ("data", yaml.safe_load(text))
                except yaml.YAMLError as exc:
                    want = ("error", str(exc))
                try:
                    got = ("data", offensive_alikes._safe_load(text))
                except yaml.YAMLError as exc:
                    got = ("error", str(exc))
                self.assertEqual(want[0], got[0])
                self.assertTrue(want[1] == got[1] if want[0] == "error" else same(want[1], got[1]))


if __name__ == "__main__":
    unittest.main()
