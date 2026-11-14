#!/usr/bin/env python3
"""A script deck's character data (#1226): the deck's `character_scheme`
header and a card's `character` block (readings by kind, level, strokes,
radical), and what the validator makes of them. The fixture language zz gets a
deck of three characters in each test. The scheme is the deck's own data, so
no language and no script is named by the code under test: the test's kinds
are `first` (written in one script) and `second` (in another).

Stdlib `unittest` plus PyYAML, like the validator itself.
"""

from __future__ import annotations

import copy
import unittest

import validate_decks
from kinds_testlib import PATH, KindsCase

GLYPHS = "zz/zz-en-glyphs.yaml"

SCHEME = {
    "readings": {
        "first": {"name": {"en": "First reading"}, "script": "bengali"},
        "second": {"name": {"en": "Second reading"}, "script": "latin"},
    },
    "levels": {
        "grade": {"name": {"en": "School grade"}, "values": [1, 2, 3]},
        "exam": {"name": {"en": "Exam"}, "values": ["E2", "E1"]},
    },
}


def deck() -> dict:
    """Three character cards: two reading kinds, a level, strokes and a radical
    on the first; one reading on the second; none on the third."""
    def card(cid: str, target: str, native: str, **extra: object) -> dict:
        return {"id": cid, "target": target, "native": native, "pos": "letter", **extra}

    return {
        "schema": 1, "id": "zz-en-glyphs", "name": "Glyphs",
        "language": {"code": "zz", "iso639_3": "zzz", "name": "Testlang",
                     "script": "latin", "tts": "es-ES", "icon": "Zz"},
        "native": {"code": "en", "iso639_3": "eng", "name": "English"},
        "license": "CC-BY-SA-4.0", "tags": ["beginner"],
        "character_scheme": copy.deepcopy(SCHEME),
        "cards": [
            card("zz-9801", "ক", "ka", character={
                "readings": [{"kind": "first", "text": "কা", "reading": "kaa"},
                             {"kind": "first", "text": "কি"},
                             {"kind": "second", "text": "ka"}],
                "level": {"grade": 1, "exam": "E2"}, "strokes": 4, "radical": "ক"}),
            card("zz-9802", "খ", "kha",
                 character={"readings": [{"kind": "second", "text": "kha"}]}),
            card("zz-9803", "গ", "ga")]}


class CharacterCase(KindsCase):
    def setUp(self) -> None:
        super().setUp()
        self.put(GLYPHS, deck())
        self.edit(PATH, lambda d: (d.__setitem__("alphabet", ["zz-glyphs"]),
                                   d["units"].insert(2, ["zz-glyphs"])))

    def change(self, edit) -> None:
        self.edit(GLYPHS, edit)

    def first(self, d: dict) -> dict:
        return d["cards"][0]["character"]

    def check(self, edit, needle: str) -> None:
        self.change(edit)
        self.assertIn(needle, "\n".join(self.errors(GLYPHS)))


class Valid(CharacterCase):
    def test_the_deck_is_valid(self) -> None:
        self.assertEqual(self.errors(GLYPHS), [])
        self.assertValid()

    def test_the_file_is_marked_as_using_the_new_field(self) -> None:
        report = validate_decks.validate(self.p(GLYPHS))
        self.assertEqual(report.new_fields, {"character"})

    def test_a_deck_without_the_block_uses_no_new_field(self) -> None:
        def change(d: dict) -> None:
            d.pop("character_scheme")
            for c in d["cards"]:
                c.pop("character", None)
        self.change(change)
        self.assertEqual(self.errors(GLYPHS), [])
        self.assertEqual(validate_decks.validate(self.p(GLYPHS)).new_fields, set())

    def test_a_scheme_may_have_readings_alone_or_levels_alone(self) -> None:
        def change(d: dict) -> None:
            d["character_scheme"].pop("levels")
            for c in d["cards"]:
                c.get("character", {}).pop("level", None)
        self.change(change)
        self.assertEqual(self.errors(GLYPHS), [])

    def test_a_level_scheme_without_values_takes_any_value(self) -> None:
        def change(d: dict) -> None:
            d["character_scheme"]["levels"]["grade"].pop("values")
            self.first(d)["level"] = {"grade": "anything"}
        self.change(change)
        self.assertEqual(self.errors(GLYPHS), [])

    def test_a_core_deck_may_use_it_too(self) -> None:
        # A core carries the scheme and the block as a single-file deck does.
        core = {k: v for k, v in deck().items() if k not in ("name", "native")}
        core.update(id="zz-glyphs", part="core", kind="vocab")
        core["language"] = dict(core["language"])
        for c in core["cards"]:
            c.pop("native")
        self.put("zz/zz-glyphs.yaml", core)
        errors = "\n".join(self.errors("zz/zz-glyphs.yaml"))
        self.assertNotIn("character_scheme", errors)
        self.assertNotIn(".character", errors)


class Readings(CharacterCase):
    def test_a_reading_in_the_wrong_script_is_an_error(self) -> None:
        # The kind `first` is written in one script; this text is Latin.
        self.check(lambda d: self.first(d)["readings"][0].__setitem__("text", "ka"),
                   "letters that are not in the script 'bengali' of the kind 'first'")

    def test_a_reading_in_the_right_script_of_the_other_kind_is_valid(self) -> None:
        self.change(lambda d: self.first(d)["readings"][2].__setitem__("text", "kā"))
        self.assertEqual(self.errors(GLYPHS), [])

    def test_a_kind_the_scheme_does_not_name_is_an_error(self) -> None:
        self.check(lambda d: self.first(d)["readings"][0].__setitem__("kind", "third"),
                   "kind 'third' is not a reading kind of the deck's character_scheme")

    def test_a_reading_needs_its_text(self) -> None:
        self.check(lambda d: self.first(d)["readings"][0].pop("text"),
                   "text must be the reading")

    def test_a_reading_may_not_be_listed_twice(self) -> None:
        self.check(lambda d: self.first(d)["readings"].append({"kind": "second", "text": "ka"}),
                   "the 'second' reading 'ka' is listed twice")

    def test_a_reading_has_known_fields_only(self) -> None:
        self.check(lambda d: self.first(d)["readings"][0].__setitem__("colour", "red"),
                   "unknown field 'colour'")

    def test_readings_are_a_non_empty_list(self) -> None:
        self.check(lambda d: self.first(d).__setitem__("readings", []),
                   "readings: must be a non-empty list")


class LevelStrokesRadical(CharacterCase):
    def test_a_negative_stroke_count_is_an_error(self) -> None:
        self.check(lambda d: self.first(d).__setitem__("strokes", -2),
                   "strokes must be a whole number from 1 to 64, got -2")

    def test_zero_text_and_true_are_no_stroke_count(self) -> None:
        for bad in (0, "four", True, 4.5, 65):
            with self.subTest(bad=bad):
                self.change(lambda d, bad=bad: self.first(d).__setitem__("strokes", bad))
                self.assertIn("strokes must be a whole number",
                              "\n".join(self.errors(GLYPHS)))

    def test_a_scheme_the_deck_does_not_name_is_an_error(self) -> None:
        self.check(lambda d: self.first(d)["level"].__setitem__("rank", 1),
                   "scheme 'rank' is not a level scheme of the deck's character_scheme")

    def test_a_value_outside_the_schemes_values_is_an_error(self) -> None:
        self.check(lambda d: self.first(d)["level"].__setitem__("grade", 9),
                   "grade 9 is not one of its values (1, 2, 3)")

    def test_a_radical_is_one_character(self) -> None:
        self.check(lambda d: self.first(d).__setitem__("radical", "কখ"),
                   "radical must be one character")

    def test_a_block_has_known_fields_only(self) -> None:
        self.check(lambda d: self.first(d).__setitem__("colour", "red"),
                   "unknown field 'colour'")

    def test_an_empty_block_is_an_error(self) -> None:
        self.check(lambda d: d["cards"][0].__setitem__("character", {}),
                   "must be a mapping with readings, level, strokes or radical")


class Scheme(CharacterCase):
    def test_a_block_needs_the_decks_scheme(self) -> None:
        self.check(lambda d: d.pop("character_scheme"),
                   "the deck's header needs a character_scheme")

    def test_a_kind_needs_a_name_with_english(self) -> None:
        self.check(lambda d: d["character_scheme"]["readings"]["first"].__setitem__(
            "name", {"es": "Primera"}), "name needs en")

    def test_a_kind_needs_a_script_id(self) -> None:
        self.check(lambda d: d["character_scheme"]["readings"]["first"].pop("script"),
                   "script must be a script id")

    def test_a_scheme_has_known_fields_only(self) -> None:
        self.check(lambda d: d["character_scheme"].__setitem__("colours", {}),
                   "unknown field 'colours'")

    def test_a_scheme_names_something(self) -> None:
        self.check(lambda d: d.__setitem__("character_scheme", {}),
                   "character_scheme: must be a mapping with readings and/or levels")

    def test_a_value_is_listed_once(self) -> None:
        self.check(lambda d: d["character_scheme"]["levels"]["grade"].__setitem__(
            "values", [1, "1"]), "values lists a value twice")

    def test_the_block_is_for_a_card_of_a_script_deck(self) -> None:
        self.check(lambda d: d["cards"][0].__setitem__("pos", "noun"),
                   "is for a card of a script deck")


class Layers(CharacterCase):
    def test_a_layer_may_not_carry_a_character_block(self) -> None:
        layer = "zz/en/zz-en-words.yaml"
        self.edit(layer, lambda d: d["cards"]["zz-9001"].__setitem__(
            "character", {"strokes": 3}))
        self.assertIn("'character' belongs to the word, in the core",
                      "\n".join(self.errors(layer)))


if __name__ == "__main__":
    unittest.main()
