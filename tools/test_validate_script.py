#!/usr/bin/env python3
"""Script guides (#30, ADR-0016): a script's recurring features, checked on
their own. Described in docs/DECK-FORMAT.md."""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import validate_decks

GOOD = """\
schema: 1
kind: script
id: bn-script
language: bn
name: "How Bengali script works"
intro: "Most of what looks strange is a few ideas used again and again."
features:
  - id: headline
    name: "The headline"
    term: "মাত্রা"
    reading: "matra"
    example: "ক"
    text: "Most letters hang from a line along the top."
    letters: ["ক", "ঘ", "ত"]
  - id: knot
    name: "The knot"
    example: "ত"
    text: "A small loop that tells letters apart."
"""


class ScriptGuideTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir)

    def errors(self, text: str, name: str = "bn-script", folder: str = "bn") -> list[str]:
        (self.dir / folder).mkdir(exist_ok=True)
        path = self.dir / folder / f"{name}.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path).errors

    def test_a_good_guide_passes(self) -> None:
        self.assertEqual(self.errors(GOOD), [])

    def test_the_id_follows_the_language_and_the_folder(self) -> None:
        self.assertTrue(any("bn-script" in e for e in self.errors(
            GOOD.replace("id: bn-script", "id: bengali"), name="bengali")))
        self.assertTrue(any("is in hi/" in e for e in self.errors(GOOD, folder="hi")))

    def test_a_guide_needs_a_name_an_intro_and_features(self) -> None:
        self.assertTrue(any("name" in e for e in self.errors(
            GOOD.replace('name: "How Bengali script works"', 'name: ""'))))
        self.assertTrue(any("intro" in e for e in self.errors(
            GOOD.replace('intro: "Most of what looks strange is a few ideas used again and again."\n', ''))))
        self.assertTrue(any("non-empty list" in e for e in self.errors(
            GOOD.split("features:")[0] + "features: []\n")))

    def test_a_feature_needs_an_id_a_name_an_example_and_text(self) -> None:
        self.assertTrue(any("listed twice" in e for e in self.errors(
            GOOD.replace("id: knot", "id: headline"))))
        self.assertTrue(any("needs example" in e for e in self.errors(
            GOOD.replace('    example: "ত"\n', ''))))
        self.assertTrue(any("term" in e for e in self.errors(
            GOOD.replace('term: "মাত্রা"', 'term: ""'))))
        self.assertTrue(any("needs a term" in e for e in self.errors(
            GOOD.replace('    term: "মাত্রা"\n', ''))))
        self.assertTrue(any("reading" in e for e in self.errors(
            GOOD.replace('reading: "matra"', 'reading: ""'))))
        self.assertTrue(any("letters" in e for e in self.errors(
            GOOD.replace('letters: ["ক", "ঘ", "ত"]', 'letters: "ক"'))))

    def test_unknown_fields_fail(self) -> None:
        self.assertTrue(any("unknown field" in e for e in self.errors(GOOD + "extra: 1\n")))


SECOND = GOOD.replace("id: bn-script", "id: bn-sylheti-script")
# A deck of the language in a second script, which is all the guide's check
# reads of it.
SECOND_DECK = 'language: { code: "bn", script: "bengali", scripts: ["bengali", "sylheti"] }\n'


class OtherScriptGuideTest(unittest.TestCase):
    """A language written in several scripts has a guide for each: `<code>-script`
    is the default, `<code>-<script>-script` the guide of another (ADR-0016)."""

    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir)
        (self.dir / "bn").mkdir()

    def errors(self, text: str, name: str, deck: str | None = SECOND_DECK) -> list[str]:
        if deck is not None:
            (self.dir / "bn" / "bn-letters.yaml").write_text(deck, encoding="utf-8")
        path = self.dir / "bn" / f"{name}.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path).errors

    def test_a_guide_of_another_script_of_the_course_passes(self) -> None:
        self.assertEqual(self.errors(SECOND, "bn-sylheti-script"), [])

    def test_a_hyphenated_script_is_the_courses_underscored_one(self) -> None:
        deck = SECOND_DECK.replace("sylheti", "perso_arabic")
        text = GOOD.replace("id: bn-script", "id: bn-perso-arabic-script")
        self.assertEqual(self.errors(text, "bn-perso-arabic-script", deck), [])

    def test_its_script_must_be_one_the_course_is_written_in(self) -> None:
        errors = self.errors(SECOND, "bn-sylheti-script", SECOND_DECK.replace("sylheti", "other"))
        self.assertTrue(any("sylheti" in e and "none of the decks" in e for e in errors), errors)
        self.assertTrue(any("none of the decks" in e for e in self.errors(
            SECOND, "bn-sylheti-script", None)))

    def test_a_guide_id_has_the_language_and_script_only(self) -> None:
        for bad in ("bn-sylheti", "bn-script-sylheti", "xx-sylheti-script"):
            text = GOOD.replace("id: bn-script", f"id: {bad}")
            self.assertTrue(any("<script>-script" in e for e in self.errors(text, bad)), bad)

    def test_a_deck_never_has_an_id_ending_in_script(self) -> None:
        deck = 'schema: 1\nid: bn-letters-script\nname: "x"\nlicense: "CC0-1.0"\n'
        self.assertTrue(any("ends in -script" in e for e in self.errors(
            deck, "bn-letters-script", None)))

    def test_the_layer_of_another_script_is_named_for_it(self) -> None:
        (self.dir / "bn" / "en").mkdir()
        core = SECOND.replace("kind: script\n", 'kind: script\npart: "core"\n')
        core = core.replace('name: "How Bengali script works"\n', "").replace(
            'intro: "Most of what looks strange is a few ideas used again and again."\n', "")
        core = core.replace('    name: "The headline"\n', "").replace(
            '    text: "Most letters hang from a line along the top."\n', "").replace(
            '    name: "The knot"\n', "").replace(
            '    text: "A small loop that tells letters apart."\n', "")
        self.errors(core, "bn-sylheti-script")
        layer = (
            'schema: 1\nid: "bn-en-sylheti-script"\nkind: "layer"\n'
            'core: "bn-sylheti-script"\n'
            'native: { code: "en", iso639_3: "eng", name: "English" }\n'
            'name: "How Sylheti works"\nintro: "A few ideas."\n'
            'features:\n  "headline":\n    name: "The headline"\n    text: "Along the top."\n'
            '  "knot":\n    name: "The knot"\n    text: "A small loop."\n')
        path = self.dir / "bn" / "en" / "bn-en-sylheti-script.yaml"
        path.write_text(layer, encoding="utf-8")
        self.assertEqual(validate_decks.validate(path).errors, [])
        path.write_text(layer.replace("bn-en-sylheti-script", "bn-en-script", 1),
                        encoding="utf-8")
        self.assertTrue(any("bn-en-sylheti-script" in e for e in
                            validate_decks.validate(path).errors))


class HindustaniPersoArabicGuideTest(unittest.TestCase):
    """The guide the repository ships for Hindustani's second script."""

    def test_the_core_and_its_english_layer_are_valid(self) -> None:
        hi = validate_decks.ROOT / "decks" / "hi"
        for path in (hi / "hi-perso-arabic-script.yaml",
                     hi / "en" / "hi-en-perso-arabic-script.yaml"):
            self.assertEqual(validate_decks.validate(path).errors, [], path.name)


if __name__ == "__main__":
    unittest.main()
