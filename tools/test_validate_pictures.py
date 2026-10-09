#!/usr/bin/env python3
"""A card's picture: one emoji whose Noto Emoji image is bundled (ADR-0034)."""

from __future__ import annotations

import unittest

import validate_decks
from test_validate_content import VOCAB, Validated


class Pictures(Validated):
    def with_picture(self, value: str) -> str:
        return VOCAB.replace('    reading: "ghar"\n',
                             f'    reading: "ghar"\n    picture: {value}\n')

    def test_a_bundled_picture_is_valid(self) -> None:
        self.assertValid(self.with_picture('"🏠"'))

    def test_one_with_no_image_is_rejected(self) -> None:
        self.assertRejected(self.with_picture('"🦖"'), "has no image")

    def test_it_must_be_an_emoji(self) -> None:
        for bad in ('"house"', '""', "7"):
            with self.subTest(bad=bad):
                self.assertRejected(self.with_picture(bad), "picture must be one emoji")

    def test_its_file_is_named_as_the_app_names_it(self) -> None:
        self.assertEqual(validate_decks.picture_file("🏠"), "emoji_u1f3e0.png")
        self.assertEqual(validate_decks.picture_file("☁️"), "emoji_u2601.png")
        self.assertEqual(validate_decks.picture_file("🧑‍🏫"),
                         "emoji_u1f9d1_200d_1f3eb.png")


if __name__ == "__main__":
    unittest.main()
