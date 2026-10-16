#!/usr/bin/env python3
"""A card's examples (#511): a per-item `source`, and at least 2 on a word
card once its language is filled in (DECK-FORMAT.md, Card data).

Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
PyYAML, like the validator itself.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks  # noqa: E402
from test_validate_b1 import CAT, CORE, EXTRA, LAYER, B1Case, card, single  # noqa: E402

TWO = [{"target": "ఇల్లు పెద్దది.", "reading": "illu peddadi.", "ipa": "illu peddadi"},
       {"target": "ఇల్లు చిన్నది.", "reading": "illu cinnadi.",
        "source": "https://tatoeba.org/en/sentences/show/1"}]
FILLED = "validate_decks.FILLED_LANGUAGES"
TOO_FEW = "a word card has at least 2 once zz is filled in (DECK-FORMAT.md, Card data)"


class ExampleSource(B1Case):

    def test_a_core_example_may_name_its_source(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=TWO))
        self.assertNoError(CORE)
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(
            examples={"ఇల్లు పెద్దది.": "The house is big.",
                      "ఇల్లు చిన్నది.": "The house is small."}))
        self.assertNoError(LAYER)

    def test_a_source_is_text(self) -> None:
        bad = [dict(TWO[0], source=""), dict(TWO[1], source=7)]
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=bad))
        self.assertError(CORE, "card zz-9001", "examples[0].source must be a non-empty "
                                               "string or omitted")
        self.assertError(CORE, "card zz-9001", "examples[1].source must be a non-empty "
                                               "string or omitted")

    def test_a_layer_gives_no_source(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=TWO[:1]))
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(
            examples={"ఇల్లు పెద్దది.": {"native": "The house is big.", "source": "x"}}))
        self.assertTrue(any("examples" in e for e in self.errors(LAYER)))

    def test_a_single_file_example_may_name_its_source(self) -> None:
        ex = {"target": "పిల్లి.", "native": "A cat.", "source": "Tatoeba #2"}
        self.put(EXTRA, single(cards=[dict(CAT, examples=[ex])]))
        self.assertNoError(EXTRA)
        self.put(EXTRA, single(cards=[dict(CAT, examples=[dict(ex, source=["x"])])]))
        self.assertError(EXTRA, "card zz-9501", "examples[0].source must be a non-empty "
                                                "string or omitted")


class ExampleMinimum(B1Case):

    def test_no_error_while_the_language_is_not_filled_in(self) -> None:
        self.assertNotIn("zz", validate_decks.FILLED_LANGUAGES)
        self.assertNoError(CORE, "example(s)")

    def test_no_language_is_filled_in_yet(self) -> None:
        self.assertEqual(validate_decks.FILLED_LANGUAGES, set())

    def test_a_word_card_needs_two_once_filled_in(self) -> None:
        with mock.patch(FILLED, {"zz"}):
            self.assertError(CORE, "card zz-9001", f"0 example(s); {TOO_FEW}")
            self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=TWO[:1]))
            self.assertError(CORE, "card zz-9001", f"1 example(s); {TOO_FEW}")
            self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=TWO))
            self.assertNoError(CORE, "card zz-9001: ")

    def test_only_word_cards_need_them(self) -> None:
        with mock.patch(FILLED, {"zz"}):
            errors = [e for e in self.errors(CORE) if "example(s)" in e]
            # Phrasebook cards and the sentence zz-9002 are not word cards.
            self.assertNotIn("zz-9101", " ".join(errors))
            self.assertNotIn("zz-9002", " ".join(errors))
            self.assertIn(f"card zz-9004: 0 example(s); {TOO_FEW}", errors)

    def test_a_single_file_word_card_too(self) -> None:
        self.put(EXTRA, single())
        with mock.patch(FILLED, {"zz"}):
            self.assertError(EXTRA, "card zz-9501", f"0 example(s); {TOO_FEW}")
        self.assertNoError(EXTRA, "example(s)")


if __name__ == "__main__":
    unittest.main()
