#!/usr/bin/env python3
"""A card's spelling in a language's other scripts (`target_scripts`, #623),
the language block's `scripts`, and the script id `perso_arabic`.

Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
PyYAML, like the validator itself.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks  # noqa: E402
from test_validate_b1 import CORE, EXTRA, LANGUAGE, LAYER, B1Case, card, single  # noqa: E402

HOUSE = "zz-9001"

HINDUSTANI = dict(LANGUAGE, script="devanagari", scripts=["devanagari", "perso_arabic"])
BOOK = {"id": "zz-9601", "target": "किताब", "reading": "kitāb", "native": "book",
        "pos": "noun", "target_scripts": {"perso_arabic": "کتاب"}}


def deck(book: dict | None = None, language: dict | None = None, **card_fields) -> dict:
    book = dict(book or BOOK, **card_fields)
    return single(cards=[book], language=dict(language or HINDUSTANI))


class ScriptId(unittest.TestCase):

    def test_an_underscore_is_part_of_a_script_id(self) -> None:
        for name in ("perso_arabic", "ol_chiki", "meitei_mayek", "perso-arabic", "han"):
            self.assertTrue(validate_decks.SCRIPT_RE.fullmatch(name), name)
        for name in ("Perso_Arabic", "perso__arabic", "_arabic", "arabic_", "perso arabic"):
            self.assertFalse(validate_decks.SCRIPT_RE.fullmatch(name), name)


class Case(B1Case):

    def single(self, **kwargs) -> list[str]:
        self.put(EXTRA, deck(**kwargs))
        return self.errors(EXTRA)


class TargetScripts(Case):

    def test_a_card_with_its_second_spelling_is_valid(self) -> None:
        self.assertEqual(self.single(), [])

    def test_a_language_with_perso_arabic_as_its_script_is_valid(self) -> None:
        errors = self.single(language=dict(LANGUAGE, script="perso_arabic"))
        self.assertNotIn("language: script must be a lowercase script name, such as "
                         "'devanagari', got 'perso_arabic'", errors)

    def test_a_card_without_it_is_valid(self) -> None:
        book = {k: v for k, v in BOOK.items() if k != "target_scripts"}
        self.assertEqual(self.single(book=book), [])

    def test_the_key_is_one_of_the_languages_other_scripts(self) -> None:
        errors = self.single(target_scripts={"shahmukhi": "کتاب"})
        self.assertIn("card zz-9601: target_scripts key 'shahmukhi' is not one of the "
                      "language's other scripts (perso_arabic)", errors)

    def test_the_first_script_is_target_not_a_key(self) -> None:
        errors = self.single(target_scripts={"devanagari": "किताबें"})
        self.assertIn("card zz-9601: target_scripts key 'devanagari' is not one of the "
                      "language's other scripts (perso_arabic)", errors)

    def test_the_language_must_list_its_scripts(self) -> None:
        errors = self.single(language=dict(LANGUAGE, script="devanagari"))
        self.assertIn("card zz-9601: target_scripts needs the language block to list "
                      "its scripts, `scripts: [<first>, perso_arabic]`", errors)

    def test_the_letters_are_in_the_scripts_blocks(self) -> None:
        errors = self.single(target_scripts={"perso_arabic": "किताब"})
        self.assertIn("card zz-9601: target_scripts.perso_arabic has letters that are "
                      "not in perso_arabic: 'किताब'", errors)
        errors = self.single(target_scripts={"perso_arabic": "kitab"})
        self.assertTrue(any("not in perso_arabic" in e for e in errors), errors)

    def test_the_nastaliq_letters_and_marks_are_arabic(self) -> None:
        for word in ("ٹھنڈا", "بھائی", "ہے", "گھر", "ں", "کتاب۔", "آپ کیسے ہیں؟"):
            with self.subTest(word=word):
                self.assertEqual(self.single(target_scripts={"perso_arabic": word}), [])

    def test_the_value_differs_from_target(self) -> None:
        errors = self.single(target_scripts={"perso_arabic": "किताब"})
        self.assertIn("card zz-9601: target_scripts.perso_arabic is the same as target; "
                      "give a spelling in perso_arabic", errors)

    def test_a_mapping_of_text(self) -> None:
        for bad in ("کتاب", ["کتاب"], {}, None):
            with self.subTest(bad=bad):
                self.assertIn("card zz-9601: target_scripts must be a mapping of script "
                              "id to the word in that script", self.single(target_scripts=bad))
        errors = self.single(target_scripts={"perso_arabic": 5})
        self.assertIn("card zz-9601: target_scripts.perso_arabic must be a non-empty "
                      "string", errors)
        errors = self.single(target_scripts={"Perso Arabic": "کتاب"})
        self.assertIn("card zz-9601: target_scripts key 'Perso Arabic' is not a script id",
                      errors)

    def test_chinese_traditional_is_in_the_cjk_blocks(self) -> None:
        language = dict(LANGUAGE, script="han", scripts=["han", "han_traditional"])
        book = {"id": "zz-9601", "target": "书", "reading": "shū", "native": "book",
                "target_scripts": {"han_traditional": "書"}}
        self.assertEqual(self.single(book=book, language=language), [])
        errors = self.single(book=book, language=language,
                             target_scripts={"han_traditional": "kitab"})
        self.assertTrue(any("not in han_traditional" in e for e in errors), errors)

    def test_a_script_with_no_blocks_is_not_checked_for_letters(self) -> None:
        language = dict(LANGUAGE, script="devanagari", scripts=["devanagari", "ol_chiki"])
        errors = self.single(language=language, target_scripts={"ol_chiki": "ᱠᱤᱛᱟᱵ"})
        self.assertEqual(errors, [])

    def test_a_core_card_carries_it(self) -> None:
        def change(d: dict) -> None:
            d["language"] = dict(HINDUSTANI)
            card(d, HOUSE)["target"] = "घर"
            card(d, HOUSE)["target_scripts"] = {"perso_arabic": "گھر"}
        self.edit(CORE, change)
        self.assertNotIn("target_scripts", " ".join(self.errors(CORE)))
        self.edit(CORE, lambda d: card(d, HOUSE).update(
            target_scripts={"perso_arabic": "घर"}))
        self.assertTrue(any("is the same as target" in e for e in self.errors(CORE)))

    def test_a_layer_may_not_hold_it_on_a_card_the_core_wrote(self) -> None:
        self.edit(LAYER, lambda d: d["cards"][HOUSE].update(
            target_scripts={"perso_arabic": "گھر"}))
        self.assertTrue(any("target_scripts" in e for e in self.errors(LAYER)))


class Scripts(Case):

    def test_the_first_script_is_the_blocks_own(self) -> None:
        language = dict(HINDUSTANI, scripts=["perso_arabic", "devanagari"])
        self.assertIn("language: scripts starts with the block's script, 'devanagari', "
                      "got 'perso_arabic' first", self.single(language=language))

    def test_two_or_more_names_none_twice(self) -> None:
        for bad in (["devanagari"], "devanagari", ["devanagari", 5]):
            with self.subTest(bad=bad):
                errors = self.single(language=dict(HINDUSTANI, scripts=bad))
                self.assertTrue(any(e.startswith("language: scripts must list two or more")
                                    for e in errors), errors)
        errors = self.single(language=dict(HINDUSTANI, scripts=["devanagari", "devanagari"]))
        self.assertIn("language: scripts lists a script twice", errors)


if __name__ == "__main__":
    unittest.main()
