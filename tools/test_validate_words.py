#!/usr/bin/env python3
"""A card's and an example's `words` (DECK-FORMAT.md, Base words; #661):
the words of a target in a script written without spaces, which the
validator then splits it into for bases and B1 coverage.

The B1 fixture (tools/fixtures/b1/zz) is Telugu, written with spaces; these
tests give it `words` and, where they say so, mark it a script without
spaces, to check what changes.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks as vd  # noqa: E402
from test_validate_b1 import CORE, B1Case, card  # noqa: E402


def spaced(target: str) -> list[str]:
    """The fixture's words, as its spaces give them, a mark at the end left
    off: what a deck in a script without spaces would list."""
    return [w.rstrip("!.") for w in target.split()]


def give_words(deck: dict) -> None:
    for c in deck["cards"]:
        if "target" in c:
            c["words"] = spaced(c["target"])


class GivenWords(B1Case):

    def test_words_joining_to_the_target_are_clean(self) -> None:
        self.edit(CORE, give_words)
        self.assertNoError(CORE, "words")

    def test_words_must_join_to_the_target(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9002").update(words=["నేను", "వెళ్తాను"]))
        self.assertError(CORE, "card zz-9002",
                         "words join to 'నేనువెళ్తాను', but the target is "
                         "'నేను ఇంటికి వెళ్తాను.'; give its words in order, every letter "
                         "of it in one word (spaces and punctuation left out)")

    def test_a_word_has_no_space_and_is_not_a_mark(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9002").update(
            words=["నేను ఇంటికి", "వెళ్తాను"]))
        self.assertError(CORE, "card zz-9002", "words: 'నేను ఇంటికి' is not a word: a "
                                               "word has no space in it, and is not "
                                               "punctuation alone")
        self.edit(CORE, lambda d: card(d, "zz-9002").update(
            words=["నేను", "ఇంటికి", "వెళ్తాను", "."]))
        self.assertError(CORE, "card zz-9002", "words: '.' is not a word: a word has no "
                                               "space in it, and is not punctuation alone")

    def test_words_are_a_list_of_strings(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9002").update(words="నేను"))
        self.assertError(CORE, "card zz-9002", "words must be a non-empty list of the "
                                               "target's words, in order, each a string")

    def test_an_examples_words_join_to_its_target(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=[{
            "target": "ఇల్లు చిన్నది.", "reading": "illu cinnadi.", "words": ["ఇల్లు"]}]))
        self.assertError(CORE, "card zz-9001",
                         "examples[0].words join to 'ఇల్లు', but the examples[0].target "
                         "is 'ఇల్లు చిన్నది.'; give its words in order, every letter of "
                         "it in one word (spaces and punctuation left out)")

    def test_the_words_given_are_the_words_bases_name(self) -> None:
        # Two words run together: ఇంటికి (iṇṭiki) is then no word of the
        # target, and its base names none.
        self.edit(CORE, lambda d: card(d, "zz-9002").update(
            words=["నేనుఇంటికి", "వెళ్తాను"]))
        self.assertError(CORE, "card zz-9002",
                         "bases[0].word 'ఇంటికి' is not a word of the target")


class UnspacedCoverage(B1Case):
    """A B1 deck in a script written without spaces: its words are given,
    and covered as a spaced deck's are."""

    def setUp(self) -> None:
        super().setUp()
        self.edit(CORE, lambda d: d["language"].update(script="thai"))

    def test_every_target_gives_its_words(self) -> None:
        self.assertAcross(f"{self.p(CORE)}: card zz-9101: no `words`; zz-en-home is a B1 "
                          f"deck in the thai script, written without spaces, so each "
                          f"target and example gives its words in order (DECK-FORMAT.md, "
                          f"Base words)")

    def test_with_its_words_the_deck_is_covered(self) -> None:
        self.edit(CORE, give_words)
        self.assertNotAcross("no `words`")
        self.assertNotAcross("is not a word the zz-en course teaches")

    def test_a_word_not_taught_still_needs_its_base(self) -> None:
        self.edit(CORE, give_words)
        self.edit(CORE, lambda d: card(d, "zz-9002").pop("bases"))
        self.assertAcross(f"{self.p(CORE)}: card zz-9002: 'ఇంటికి' is not a word the zz-en "
                          f"course teaches as a card, and has no bases entry; add {{ word: "
                          f"\"ఇంటికి\", ref: ... }}, or {{ word: \"ఇంటికి\", base: ..., "
                          f"reading: ... }}")

    def test_an_example_gives_its_words_too(self) -> None:
        self.edit(CORE, give_words)
        self.edit(CORE, lambda d: card(d, "zz-9001").update(
            examples=[{"target": "అమ్మ ఇల్లు.", "reading": "amma illu."}]))
        self.edit("en/zz-en-home.yaml", lambda d: d["cards"]["zz-9001"].update(
            examples={"అమ్మ ఇల్లు.": "Mother's house."}))
        self.assertAcross(f"{self.p(CORE)}: card zz-9001: examples[0]: no `words`; "
                          f"zz-en-home is a B1 deck in the thai script, written without "
                          f"spaces, so each target and example gives its words in order "
                          f"(DECK-FORMAT.md, Base words)")
        self.edit(CORE, lambda d: card(d, "zz-9001")["examples"][0].update(
            words=["అమ్మ", "ఇల్లు"]))
        self.assertNotAcross("no `words`")
        self.assertNotAcross("is not a word the zz-en course teaches")


class Splitting(unittest.TestCase):
    """What the words decide besides bases: whether a card is one word, and
    the tiles it is put in order with, as the app has them."""

    def test_a_card_of_several_given_words_is_no_word(self) -> None:
        self.assertTrue(vd.counts_as_word({"target": "我听不懂"}, "vocab"))
        self.assertFalse(vd.counts_as_word(
            {"target": "我听不懂", "words": ["我", "听不懂"]}, "vocab"))
        self.assertTrue(vd.counts_as_word(
            {"target": "ありがとう", "words": ["ありがとう"]}, "vocab"))

    def test_tiles_are_the_words_and_the_marks_between(self) -> None:
        self.assertEqual(vd._tiles("多少钱？", ["多少", "钱"]), ["多少", "钱", "？"])
        self.assertEqual(vd._tiles("ありがとうございます", ["ありがとう", "ございます"]),
                         ["ありがとう", "ございます"])
        self.assertTrue(vd._rearranges("我听不懂", "phrase", ["我", "听不懂"]))
        self.assertFalse(vd._rearranges("我听不懂", "phrase"))

    def test_words_that_do_not_match_fall_back_to_spaces(self) -> None:
        self.assertEqual(vd._tiles("多少钱？", ["多", "钱"]), ["多少钱", "？"])


if __name__ == "__main__":
    unittest.main()
