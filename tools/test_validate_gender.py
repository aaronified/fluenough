#!/usr/bin/env python3
"""Gender classes (#512): a language's path lists its classes, and a noun's
`gender` is one of them; a noun with none is an error once the language is
filled in (DECK-FORMAT.md, Card data).

Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
PyYAML, like the validator itself.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_validate_b1 import CAT, CORE, EXTRA, LAYER, PATH, B1Case, card, single  # noqa: E402

FILLED = "validate_decks.FILLED_LANGUAGES"


class GenderClasses(B1Case):

    def classes(self, genders: object) -> None:
        self.edit(PATH, lambda d: d.update(genders=genders))

    def gender(self, cid: str, value: object) -> None:
        self.edit(CORE, lambda d: card(d, cid).update(gender=value))

    def across(self) -> list[str]:
        return [line for line in self.run_main() if line.startswith("error: ")]

    def test_a_path_may_list_its_classes(self) -> None:
        self.classes(["mahat", "amahat"])
        self.assertNoError(PATH)
        self.classes([])
        self.assertNoError(PATH)

    def test_the_classes_are_a_list_of_text(self) -> None:
        self.classes("m")
        self.assertTrue(any(e.startswith("genders: must be a list") for e in self.errors(PATH)))
        self.classes(["m", 1, " f", "m"])
        errors = self.errors(PATH)
        self.assertIn("genders[1]: must be a class name, quoted text with no spaces "
                      "around it, got 1", errors)
        self.assertIn("genders[2]: must be a class name, quoted text with no spaces "
                      "around it, got ' f'", errors)
        self.assertIn("genders[3]: 'm' is listed twice", errors)

    def test_a_noun_of_a_listed_class_passes(self) -> None:
        self.classes(["mahat", "amahat"])
        self.gender("zz-9001", "amahat")
        self.assertEqual(self.across(), [])
        self.assertEqual(self.code, 0)

    def test_a_noun_outside_the_classes_is_an_error(self) -> None:
        self.classes(["mahat", "amahat"])
        self.gender("zz-9001", "m")
        self.assertEqual(self.across(), [
            f"error: {self.p(CORE)}: card zz-9001: gender 'm' is not a class of zz; "
            f"its path lists mahat, amahat"])
        self.assertEqual(self.code, 1)

    def test_a_language_without_gender_takes_none(self) -> None:
        self.classes([])
        self.gender("zz-9001", "m")
        self.assertEqual(self.across(), [
            f"error: {self.p(CORE)}: card zz-9001: gender 'm', but zz has no gender "
            f"classes; leave gender out"])

    def test_only_nouns_are_checked(self) -> None:
        self.classes(["mahat", "amahat"])
        self.gender("zz-9003", "m")      # a verb
        self.assertEqual(self.across(), [])

    def test_no_classes_listed_checks_nothing(self) -> None:
        # zz is in neither its path nor the decided table.
        self.gender("zz-9001", "anything")
        with mock.patch(FILLED, {"zz"}):
            self.assertEqual(self.across(), [])

    def test_without_a_path_list_the_decided_classes_are_checked(self) -> None:
        # OPEN (#512): the paths do not list their classes yet; the owner's
        # table in the validator stands in until they do.
        with mock.patch("validate_decks.DECIDED_GENDERS", {"zz": ["mahat", "amahat"]}):
            self.gender("zz-9001", "m")
            self.assertEqual(self.across(), [
                f"error: {self.p(CORE)}: card zz-9001: gender 'm' is not a class of zz; "
                f"the decided classes (DECK-FORMAT.md, Gender) are mahat, amahat"])
            self.gender("zz-9001", "amahat")
            self.assertEqual(self.across(), [])

    def test_a_path_list_wins_over_the_decided_classes(self) -> None:
        with mock.patch("validate_decks.DECIDED_GENDERS", {"zz": []}):
            self.classes(["mahat", "amahat"])
            self.gender("zz-9001", "amahat")
            self.assertEqual(self.across(), [])

    def test_the_decided_classes_match_the_owner_table(self) -> None:
        import validate_decks
        self.assertEqual(validate_decks.DECIDED_GENDERS, {
            "hi": ["m", "f"], "mr": ["m", "f", "n"], "gu": ["m", "f", "n"],
            "kn": ["m", "f", "n"], "te": ["mahat", "amahat"], "es": ["m", "f"],
            "bn": [], "as": [], "ja": []})

    def test_a_missing_gender_is_an_error_once_filled_in(self) -> None:
        self.classes(["mahat", "amahat"])
        self.assertEqual(self.across(), [])
        with mock.patch(FILLED, {"zz"}):
            found = self.across()
        self.assertEqual(sorted(found), sorted(
            f"error: {self.p(CORE)}: card {cid}: a noun has a gender once zz is filled "
            f"in, one of mahat, amahat (DECK-FORMAT.md, Card data)"
            for cid in ("zz-9001", "zz-9004")))

    def test_a_language_without_gender_needs_none_once_filled_in(self) -> None:
        self.classes([])
        with mock.patch(FILLED, {"zz"}):
            self.assertEqual(self.across(), [])

    def test_a_single_file_deck_is_checked(self) -> None:
        self.classes(["mahat", "amahat"])
        self.put(EXTRA, single(cards=[dict(CAT, gender="f")]))
        self.assertEqual([e for e in self.across() if "gender" in e], [
            f"error: {self.p(EXTRA)}: card zz-9501: gender 'f' is not a class of zz; "
            f"its path lists mahat, amahat"])

    def test_a_layer_gives_no_gender(self) -> None:
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(gender="mahat"))
        self.assertTrue(any("gender" in e for e in self.errors(LAYER)))


if __name__ == "__main__":
    unittest.main()
