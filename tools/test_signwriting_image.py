#!/usr/bin/env python3
"""Tests for signwriting_image.py: the FSW it reads (ADR-0056). Drawing needs
Pillow and the Sutton fonts, which CI has not, so only the reading is tested."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import signwriting_image as sw  # noqa: E402


class Reading(unittest.TestCase):
    def test_a_sign_is_its_symbols_with_their_places(self) -> None:
        # ASL fingerspelling, the letter A: a fist, thumb at the side, black.
        self.assertEqual(sw.parse("M507x507S1f720487x492"), [(0x1F7, 2, 0, 487, 492)])

    def test_a_symbol_has_the_id_the_fonts_number_it_by(self) -> None:
        # The first symbol of the ISWA 2010 is id 1 (U+F0001 in the line font).
        self.assertEqual(sw.key_id(0x100, 0, 0), 1)
        self.assertEqual(sw.key_id(0x1F7, 2, 0), 23745)

    def test_what_is_not_one_unstyled_sign_is_refused(self) -> None:
        for bad in ("", "M500x500", "S1f720487x492", "M507x507S1f720487x492-C",
                    "M507x507S1f720487x492 M507x507S14720493x485"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                sw.parse(bad)


if __name__ == "__main__":
    unittest.main()
