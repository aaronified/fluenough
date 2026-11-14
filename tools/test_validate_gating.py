#!/usr/bin/env python3
"""Character gating (#1227): a language's gating file,
decks/<lang>/<lang>-gating.yaml, names the scripts its path gates, and the
validator reports a card, an example or a `target_scripts` spelling that writes
a character of a gated script the path has not taught yet. The fixture
language zz gets a deck of two characters, a deck of sentences and a gating
file in each test. The gated script is made up (`glyph`, its blocks given in
the file), so nothing in the code under test names a language or a script.

Stdlib `unittest` plus PyYAML, like the validator itself.
"""

from __future__ import annotations

import unittest

import validate_decks
from kinds_testlib import PATH, KindsCase

GATING = "zz/zz-gating.yaml"
GLYPHS = "zz/zz-en-glyphs.yaml"
SENTENCES = "zz/zz-en-sentences.yaml"
NEEDLE = "the path has not taught"

# Three made-up characters, written in a code point range of their own; zz's
# decks are Latin, so "casa" is a spelling in another script.
A, B, C = "ক", "খ", "গ"


def single(deck_id: str, tags: list[str], cards: list[dict]) -> dict:
    return {
        "schema": 1, "id": deck_id, "name": deck_id,
        "language": {"code": "zz", "iso639_3": "zzz", "name": "Testlang",
                     "script": "latin", "tts": "es-ES", "icon": "Zz"},
        "native": {"code": "en", "iso639_3": "eng", "name": "English"},
        "license": "CC-BY-SA-4.0", "tags": tags, "cards": cards}


def card(cid: str, target: str, **extra: object) -> dict:
    return {"id": cid, "target": target, "native": "x", "pos": "noun", **extra}


def gating(**entry: object) -> dict:
    return {"schema": 1, "kind": "gating", "id": "zz-gating", "language": "zz",
            "license": "CC-BY-SA-4.0",
            "character_gating": [{"script": "glyph", "mode": "error",
                                  "blocks": ["0980-09FF"], **entry}]}


class GatingCase(KindsCase):
    def setUp(self) -> None:
        super().setUp()
        self.put(GLYPHS, single("zz-en-glyphs", ["script", "beginner"], [
            card("zz-9801", A, pos="letter"), card("zz-9802", B, pos="letter")]))
        self.put(SENTENCES, single("zz-en-sentences", ["beginner"], [
            card("zz-9811", A + B), card("zz-9812", "casa")]))
        self.put(GATING, gating())
        self.units(["zz-glyphs"], ["zz-sentences"])

    def units(self, *order: list[str]) -> None:
        """The path's units after the ordinary deck: each of [order]."""
        def change(d: dict) -> None:
            d["alphabet"] = ["zz-glyphs"]
            words, culture, planned = d["units"]
            # A path with a plan writes a unit as a mapping, but for an alphabet
            # unit, which stays a list.
            made = [list(u) if all(c in d["alphabet"] for c in u)
                    else {"decks": list(u), "words": 5} for u in order]
            d["units"] = [words, culture, *made, planned]
        self.restore(PATH)
        self.edit(PATH, change)

    def sentences(self, *cards: dict) -> None:
        self.put(SENTENCES, single("zz-en-sentences", ["beginner"], list(cards)))

    def run_text(self) -> tuple[int, str]:
        return self.run_main()

    def assertGated(self, *needles: str) -> None:
        code, text = self.run_text()
        self.assertEqual(code, 1, text)
        self.assertIn(NEEDLE, text)
        for needle in needles:
            self.assertIn(needle, text)

    def assertNotGated(self) -> None:
        code, text = self.run_text()
        self.assertNotIn(NEEDLE, text)
        self.assertEqual(code, 0, text)


class Gate(GatingCase):
    def test_a_sentence_of_taught_characters_is_valid(self) -> None:
        self.assertNotGated()

    def test_a_sentence_with_a_third_character_is_an_error(self) -> None:
        self.sentences(card("zz-9811", A + C))
        self.assertGated(f"writes {C!r} (U+0997)", "by unit 4", "card zz-9811")

    def test_the_same_sentence_in_a_unit_before_the_character_unit_is_an_error(self) -> None:
        self.units(["zz-sentences"], ["zz-glyphs"])
        self.assertGated(f"writes {A!r}", "by unit 3")

    def test_a_sentence_in_the_character_units_own_unit_may_use_its_characters(self) -> None:
        self.units(["zz-glyphs", "zz-sentences"])
        self.assertNotGated()

    def test_a_spelling_in_another_script_is_not_asked_about(self) -> None:
        self.sentences(card("zz-9811", "casa"), card("zz-9812", "agua"))
        self.assertNotGated()

    def test_an_example_is_checked(self) -> None:
        self.sentences(card("zz-9811", "casa", examples=[{"target": "casa " + C, "native": "y"}]))
        self.assertGated("examples[0].target")

    def test_a_target_scripts_spelling_is_checked(self) -> None:
        self.sentences(card("zz-9811", "casa", target_scripts={"other": C}))
        self.assertGated("target_scripts.other")

    def test_an_examples_target_scripts_spelling_is_checked(self) -> None:
        self.sentences(card("zz-9811", "casa", examples=[
            {"target": "casa", "native": "y", "target_scripts": {"other": C}}]))
        self.assertGated("examples[0].target_scripts.other")

    def test_an_alternative_target_is_checked(self) -> None:
        self.sentences(card("zz-9811", "casa", alt_target=[C]))
        self.assertGated("alt_target[0]")

    def test_an_allowed_character_is_taught_from_the_start(self) -> None:
        self.put(GATING, gating(allow=[C]))
        self.sentences(card("zz-9811", A + C))
        self.assertNotGated()

    def test_a_warning_is_not_an_error(self) -> None:
        self.put(GATING, gating(mode="warn"))
        self.sentences(card("zz-9811", A + C))
        code, text = self.run_text()
        self.assertEqual(code, 0, text)
        self.assertIn(f"writes {C!r}", text)
        self.assertIn(NEEDLE, text)

    def test_a_character_deck_teaches_a_character_before_its_own_examples(self) -> None:
        self.put(GLYPHS, single("zz-en-glyphs", ["script"], [
            card("zz-9801", A, pos="letter",
                 examples=[{"target": "casa " + A, "native": "y"}]),
            card("zz-9802", B, pos="letter",
                 examples=[{"target": A + B, "native": "y"}])]))
        self.assertNotGated()

    def test_a_character_deck_may_not_use_a_character_it_has_not_reached(self) -> None:
        self.put(GLYPHS, single("zz-en-glyphs", ["script"], [
            card("zz-9801", A, pos="letter",
                 examples=[{"target": A + B, "native": "y"}]),
            card("zz-9802", B, pos="letter")]))
        self.assertGated(f"writes {B!r}", "by unit 3")

    def test_a_deck_not_tagged_script_teaches_nothing(self) -> None:
        self.put(GLYPHS, single("zz-en-glyphs", ["beginner"], [
            card("zz-9801", A, pos="letter"), card("zz-9802", B, pos="letter")]))
        self.assertGated("by unit 3")

    def test_a_deck_off_the_alphabet_teaches_nothing(self) -> None:
        def change(d: dict) -> None:
            d["alphabet"] = []
            d["units"][2] = {"decks": ["zz-glyphs"], "words": 5}
        self.edit(PATH, change)
        self.assertGated("by unit")

    def test_a_deck_the_path_does_not_list_is_not_checked(self) -> None:
        self.put("zz/zz-en-stray.yaml", single(
            "zz-en-stray", ["beginner"], [card("zz-9821", C)]))
        code, text = self.run_text()
        self.assertNotIn(f"writes {C!r}", text)

    def test_a_long_run_of_reports_is_cut_short(self) -> None:
        self.sentences(*[card(f"zz-{9811 + i}", C) for i in range(25)])
        code, text = self.run_text()
        # The validator prints a cross-file error twice, where it happens and
        # again in the closing "Errors:" recap, so count the inline lines only.
        inline = [line for line in text.splitlines()
                  if line.startswith("error: ") and f"writes {C!r}" in line]
        self.assertEqual(len(inline), validate_decks.GATING_MAX_REPORTS)
        self.assertIn("5 more glyph characters not yet taught", text)

    def test_without_a_gating_file_nothing_is_checked(self) -> None:
        self.p(GATING).unlink()
        self.sentences(card("zz-9811", A + C))
        code, text = self.run_text()
        self.assertNotIn(NEEDLE, text)

    def test_a_known_script_needs_no_blocks(self) -> None:
        data = gating()
        data["character_gating"][0].update(script="bengali")
        data["character_gating"][0].pop("blocks")
        self.put(GATING, data)
        self.sentences(card("zz-9811", A + C))
        self.assertGated("a bengali character")


class File(GatingCase):
    def check(self, data: dict, needle: str) -> None:
        self.put(GATING, data)
        self.assertIn(needle, "\n".join(self.errors(GATING)))

    def test_the_file_is_valid(self) -> None:
        self.assertEqual(self.errors(GATING), [])

    def test_the_file_is_named_for_its_language(self) -> None:
        data = gating()
        data["id"] = "xx-gating"
        self.check(data, "a gating file is zz-gating.yaml")

    def test_unknown_fields_are_refused(self) -> None:
        data = gating()
        data["colour"] = "red"
        self.check(data, "unknown field 'colour'")
        data = gating(colour="red")
        self.check(data, "character_gating[0]: unknown field 'colour'")

    def test_a_mode_is_warn_or_error(self) -> None:
        self.check(gating(mode="fail"), "mode must be one of warn, error")

    def test_a_script_is_gated_once(self) -> None:
        data = gating()
        data["character_gating"].append(dict(data["character_gating"][0]))
        self.check(data, "script 'glyph' is gated twice")

    def test_a_script_without_blocks_needs_them(self) -> None:
        data = gating()
        data["character_gating"][0].pop("blocks")
        self.check(data, "no Unicode blocks for the script 'glyph'")

    def test_a_block_is_a_hexadecimal_range(self) -> None:
        self.check(gating(blocks=["09A0"]), "block '09A0' must be 'XXXX-YYYY'")
        # Written bare, 0980 is the number 980 to the deck reader (and the
        # app), so the original text is gone: the error says it is a number.
        self.check(gating(blocks=["0980"]), "block 980 must be 'XXXX-YYYY'")
        self.check(gating(blocks=["0980"]), "a bare number")
        self.check(gating(blocks=["09FF-0980"]), "the first not after the second")

    def test_an_allowed_entry_is_one_character(self) -> None:
        self.check(gating(allow=[A + B]), "allow lists one character each")
        self.check(gating(allow=[A, A]), f"allow lists {A!r} twice")

    def test_the_gates_are_a_list(self) -> None:
        data = gating()
        data["character_gating"] = []
        self.check(data, "character_gating: must be a non-empty list")

    def test_the_language_needs_a_path(self) -> None:
        self.p(PATH).unlink()
        code, text = self.run_text()
        self.assertIn("zz has no path to gate", text)


if __name__ == "__main__":
    unittest.main()
