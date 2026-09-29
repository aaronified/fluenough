#!/usr/bin/env python3
"""Content rules: ISO 639-3 codes on every language, and facts files.

Both are described in docs/DECK-FORMAT.md. Stdlib `unittest` plus PyYAML, like
the validator itself.
"""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import validate_decks

VOCAB = """\
schema: 1
id: xx-probe
name: Probe
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: xx-probe-0001
    target: घर
    native: the house
    reading: "ghar"
"""

FACTS_HEADER = """\
schema: 1
id: xx-probe
name: Hindi facts
kind: facts
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
license: CC0-1.0
facts:
"""


def fact(n: int, **fields: str) -> str:
    """One fact, written in English unless `fields` says otherwise."""
    lines = [f"  - id: hi-fact-{n:03d}"]
    text = fields.pop("text", f'{{ en: "Fact number {n}." }}')
    lines.append(f"    text: {text}")
    for key, value in fields.items():
        lines.append(f"    {key}: {value}")
    return "\n".join(lines) + "\n"


def facts_file(count: int = 30, extra: str = "", header: str = FACTS_HEADER) -> str:
    return header + "".join(fact(n) for n in range(1, count + 1)) + extra


class Validated(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def report(self, text: str) -> validate_decks.Report:
        path = self.tmp / "xx-probe.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def assertValid(self, text: str) -> validate_decks.Report:
        report = self.report(text)
        self.assertEqual(report.errors, [])
        return report

    def assertRejected(self, text: str, needle: str) -> None:
        errors = self.report(text).errors
        self.assertTrue(
            any(needle in e for e in errors),
            f"expected an error containing {needle!r}, got {errors}",
        )


class Iso6393Codes(Validated):
    def test_a_deck_with_both_codes_is_valid(self) -> None:
        self.assertValid(VOCAB)

    def test_both_language_blocks_need_one(self) -> None:
        for block, old in (
            ("language", "iso639_3: hin, "),
            ("native", "iso639_3: eng, "),
        ):
            with self.subTest(block):
                self.assertRejected(VOCAB.replace(old, ""), "iso639_3 must be")

    def test_it_must_be_three_lowercase_letters(self) -> None:
        for bad in ("hi", "hind", "HIN", "h1n", '"hin\\n"', "yes"):
            with self.subTest(bad=bad):
                self.assertRejected(VOCAB.replace("iso639_3: hin", f"iso639_3: {bad}"),
                                    "iso639_3 must be")

    def test_a_facts_file_needs_one_on_its_language(self) -> None:
        self.assertRejected(facts_file().replace("iso639_3: hin, ", ""), "iso639_3 must be")


class FactsFiles(Validated):
    def test_thirty_facts_are_valid(self) -> None:
        self.assertValid(facts_file(30))

    def test_twenty_nine_are_not_enough(self) -> None:
        self.assertRejected(facts_file(29), "at least 30 facts without a contrast")

    def test_contrast_facts_do_not_count_towards_the_thirty(self) -> None:
        extra = fact(90, contrast="en")
        self.assertRejected(facts_file(29, extra), "has 29")
        self.assertValid(facts_file(30, extra))

    def test_a_contrast_fact_must_be_written_in_its_language(self) -> None:
        extra = fact(90, contrast="bn")
        self.assertRejected(facts_file(30, extra), "text needs a 'bn' entry")

    def test_a_partial_translation_warns_but_does_not_fail(self) -> None:
        extra = fact(91, text='{ en: "One more.", bn: "আরও একটি।" }')
        report = self.assertValid(facts_file(30, extra))
        self.assertTrue(any("'bn'" in w and "1 daily facts" in w for w in report.warnings),
                        report.warnings)

    def test_fact_ids_are_unique(self) -> None:
        self.assertRejected(facts_file(30, fact(1)), "duplicate fact id")

    def test_fact_ids_match_the_id_pattern(self) -> None:
        text = facts_file(30).replace("id: hi-fact-001", "id: Hi_Fact_1")
        self.assertRejected(text, "id must match")

    def test_unknown_fields_are_rejected(self) -> None:
        self.assertRejected(facts_file(30, fact(90, colour="blue")), "unknown field 'colour'")

    def test_text_must_be_a_mapping_of_codes_to_text(self) -> None:
        cases = {
            "a plain string": ('"Just text."', "text must map language codes"),
            "a bad code": ('{ english: "Text." }', "text key must be"),
            "a bare no": ('{ no: "Tekst." }', "Quote the code"),
            "a boolean value": ("{ en: yes }", "parsed as the boolean"),
            "an empty value": ('{ en: "" }', "must be non-empty text"),
        }
        for name, (text, needle) in cases.items():
            with self.subTest(name):
                self.assertRejected(facts_file(30, fact(90, text=text)), needle)

    def test_contrast_must_be_a_language_code(self) -> None:
        self.assertRejected(facts_file(30, fact(90, contrast='"English"')),
                            "contrast must be")

    def test_a_facts_file_has_no_native(self) -> None:
        header = FACTS_HEADER.replace(
            "license:", "native: { code: en, iso639_3: eng, name: English }\nlicense:")
        self.assertRejected(facts_file(30, header=header), "a facts file has no native")

    def test_a_facts_file_has_no_cards(self) -> None:
        self.assertRejected(facts_file(30) + "cards: []\n", "uses facts, not cards")

    def test_other_decks_have_no_facts(self) -> None:
        self.assertRejected(VOCAB + "facts: []\n", "only valid on a facts file")

    def test_a_grammar_deck_has_no_facts(self) -> None:
        grammar = VOCAB.replace("name: Probe", "name: Probe\nkind: grammar").split("cards:")[0]
        grammar += (
            "pattern:\n  name: P\n  slot_name: person\n  slots: [yo]\n"
            '  prompt: "{lemma} {gloss} {slot}"\n'
            "  entries:\n    - { lemma: hablar, gloss: to speak, forms: { yo: hablo } }\n"
            "facts: []\n"
        )
        self.assertRejected(grammar, "only valid on a facts file")

    def test_a_facts_file_has_no_pattern(self) -> None:
        self.assertRejected(facts_file(30) + "pattern: {}\n", "uses facts, not cards or a pattern")

    def test_an_empty_facts_list_is_rejected(self) -> None:
        self.assertRejected(FACTS_HEADER.replace("facts:\n", "facts: []\n"),
                            "facts: must be a non-empty list")

    def test_each_fact_must_be_a_mapping(self) -> None:
        self.assertRejected(facts_file(30, '  - "just a string"\n'), "must be a mapping")

    def test_fact_tags_must_be_a_list_of_text(self) -> None:
        self.assertRejected(facts_file(30, fact(90, tags="script")), "tags must be a list")

    def test_fact_source_must_be_text(self) -> None:
        self.assertRejected(facts_file(30, fact(90, source="1990")), "not text")

    def test_contrast_facts_do_not_count_towards_a_language(self) -> None:
        # 30 English facts; Bengali appears only on a contrast fact, so it has
        # no contrast-free facts and should not be warned about as if it did.
        extra = fact(90, contrast="bn", text='{ bn: "তুলনা।" }')
        report = self.assertValid(facts_file(30, extra))
        self.assertFalse(any("'bn'" in w for w in report.warnings), report.warnings)

    def test_a_file_with_no_english_warns(self) -> None:
        text = facts_file(30).replace('{ en: "Fact number', '{ bn: "Fact number')
        report = self.assertValid(text)
        self.assertTrue(any("'en'" in w and "0 daily facts" in w for w in report.warnings),
                        report.warnings)

THEMES = """\
schema: 1
kind: themes
themes:
  - { id: first-words, name: "First words" }
  - { id: market, name: "Market" }
"""


class Themes(Validated):
    """The shared theme path, and theme decks (ADR-0010)."""

    def write(self, name: str, text: str) -> Path:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_a_themes_file_is_valid(self) -> None:
        report = validate_decks.validate(self.write("themes.yaml", THEMES))
        self.assertEqual(report.errors, [])
        self.assertEqual(report.themes, ["first-words", "market"])

    def test_a_malformed_themes_file_is_rejected(self) -> None:
        for bad, needle in (
            (THEMES.replace("id: market", "id: first-words"), "listed twice"),
            (THEMES.replace("id: market", "id: Market"), "id must match"),
            (THEMES.replace(', name: "Market"', ""), "needs a name"),
            (THEMES + "cards: []\n", "unknown field"),
            ("schema: 1\nkind: themes\nthemes: []\n", "non-empty"),
        ):
            with self.subTest(needle):
                errors = validate_decks.validate(self.write("themes.yaml", bad)).errors
                self.assertTrue(any(needle in e for e in errors), errors)

    def test_a_vocab_deck_may_name_a_theme(self) -> None:
        report = self.assertValid(VOCAB.replace("license:", "theme: market\nlicense:"))
        self.assertEqual(report.theme_key, ("hi", "en", "market"))

    def test_only_a_vocab_deck_takes_a_theme(self) -> None:
        self.assertRejected(
            facts_file().replace("license:", "theme: market\nlicense:"),
            "only a vocab deck teaches a theme",
        )

    def test_across_files_a_theme_must_exist_and_be_used_once(self) -> None:
        themes = validate_decks.validate(self.write("themes.yaml", THEMES))

        def deck(theme: str, name: str) -> validate_decks.Report:
            text = VOCAB.replace("license:", f"theme: {theme}\nlicense:")
            return validate_decks.validate(self.write(name, text))

        good = deck("market", "a.yaml")
        self.assertEqual(validate_decks.check_themes_across([themes, good]), [])
        unknown = deck("weather", "b.yaml")
        again = deck("market", "c.yaml")
        problems = validate_decks.check_themes_across([themes, good, unknown, again])
        self.assertTrue(any("'weather' is not in" in p for p in problems), problems)
        self.assertTrue(any("already has a 'market' deck" in p for p in problems), problems)


class Scripts(Validated):
    """`script` is an open list, checked with a warning (ADR-0009)."""

    def test_the_indic_starter_scripts_are_known(self) -> None:
        for script in ("bengali", "gujarati", "telugu", "devanagari", "arabic"):
            with self.subTest(script):
                report = self.assertValid(
                    VOCAB.replace("script: devanagari", f"script: {script}")
                )
                self.assertFalse(
                    [w for w in report.warnings if "not one the validator knows" in w]
                )

    def test_an_unknown_script_is_a_warning_not_an_error(self) -> None:
        report = self.assertValid(VOCAB.replace("script: devanagari", "script: ethiopic"))
        self.assertTrue(any("'ethiopic' is not one" in w for w in report.warnings))

    def test_a_script_that_is_not_a_lowercase_name_is_an_error(self) -> None:
        for bad in ("Bengali", "5", '""', "yes", "bengali script"):
            with self.subTest(bad=bad):
                self.assertRejected(
                    VOCAB.replace("script: devanagari", f"script: {bad}"),
                    "script must be a lowercase script name",
                )


if __name__ == "__main__":
    unittest.main()


GRAMMAR = """\
schema: 1
id: xx-probe
name: Probe
kind: grammar
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
pattern:
  name: P
  slot_name: person
  slots: ["मैं (m)", "मैं (f)"]
  prompt: "{lemma} ({gloss}) — {slot}"
  entries:
"""


def entry(lemma: str, key: str | None = None) -> str:
    key_line = f"      key: {key}\n" if key is not None else ""
    return (f'    - lemma: "{lemma}"\n{key_line}      gloss: "g"\n'
            f'      forms: {{ "मैं (m)": "a", "मैं (f)": "b" }}\n')


class PatternKeys(Validated):
    def test_an_ascii_lemma_needs_no_key(self) -> None:
        self.assertValid(GRAMMAR + entry("jaanaa"))

    def test_a_devanagari_lemma_with_a_key_is_valid(self) -> None:
        self.assertValid(GRAMMAR + entry("जाना", "jaanaa") + entry("आना", "aanaa"))

    def test_a_devanagari_lemma_needs_a_key(self) -> None:
        self.assertRejected(GRAMMAR + entry("जाना"), "cannot go into a card id")

    def test_a_key_must_be_an_id(self) -> None:
        self.assertRejected(GRAMMAR + entry("जाना", "Jaana"), "key must match")

    def test_two_rows_cannot_share_an_id_part(self) -> None:
        self.assertRejected(GRAMMAR + entry("जाना", "jaanaa") + entry("jaanaa"),
                            "already names another row")


NUMBERS = """\
schema: 1
id: hi-numbers
name: Hindi numbers
kind: numbers
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
license: CC0-1.0
words:
  1: "एक"
  2: ["दो"]
hundreds: { 1: "एक सौ", 2: "दो सौ", 3: "दो सौ", 4: "दो सौ", 5: "दो सौ", 6: "दो सौ", 7: "दो सौ", 8: "दो सौ", 9: "दो सौ" }
thousands: { 1: "एक हज़ार", 2: "दो हज़ार", 3: "दो हज़ार", 4: "दो हज़ार", 5: "दो हज़ार", 6: "दो हज़ार", 7: "दो हज़ार", 8: "दो हज़ार", 9: "दो हज़ार" }
"""

NUMBER_DECK = """\
schema: 1
id: hi-en-numbers-big
name: Tens and big numbers
theme: numbers-big
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-en-numbers-big-0001, target: "एक", native: "1", reading: "ek" }
  - { id: hi-en-numbers-big-0002, target: "दो", native: "2", reading: "do" }
  - { id: hi-en-numbers-big-0003, target: "सौ", native: "100", reading: "sau" }
  - { id: hi-en-numbers-big-0004, target: "हज़ार", native: "1000", reading: "hazaar" }
"""


class Numbers(Validated):
    """A language's number rules, and the words its number decks teach (ADR-0011)."""

    def write(self, name: str, text: str) -> validate_decks.Report:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def test_a_numbers_file_is_valid(self) -> None:
        report = self.write("hi-numbers.yaml", NUMBERS)
        self.assertEqual(report.errors, [])
        self.assertEqual(report.number_words[0], "hi")
        self.assertIn("हज़ार", report.number_words[1])

    def test_its_id_names_its_language(self) -> None:
        report = self.write("hi-numbers.yaml", NUMBERS.replace("id: hi-numbers", "id: hindi"))
        self.assertTrue(any("must be 'hi-numbers'" in e for e in report.errors), report.errors)

    def test_hundreds_and_thousands_need_every_digit(self) -> None:
        report = self.write("hi-numbers.yaml", NUMBERS.replace(', 9: "दो सौ" }', " }"))
        self.assertTrue(any("missing [9]" in e for e in report.errors), report.errors)

    def test_words_are_keyed_by_numbers_below_a_hundred(self) -> None:
        report = self.write("hi-numbers.yaml", NUMBERS.replace('  1: "एक"', '  100: "एक"'))
        self.assertTrue(any("from 1 to 99" in e for e in report.errors), report.errors)

    def test_every_word_must_be_taught_by_a_number_deck(self) -> None:
        rules = self.write("hi-numbers.yaml", NUMBERS)
        deck = self.write("hi-en-numbers-big.yaml", NUMBER_DECK)
        self.assertEqual(deck.errors, [])
        self.assertEqual(validate_decks.check_numbers_across([rules, deck]), [])

        untaught = self.write("hi-en-numbers-big.yaml", NUMBER_DECK.replace('"हज़ार"', '"हजार"'))
        problems = validate_decks.check_numbers_across([rules, untaught])
        self.assertTrue(any("teaches: हज़ार" in p for p in problems), problems)

    def test_rules_with_no_number_deck_are_refused(self) -> None:
        rules = self.write("hi-numbers.yaml", NUMBERS)
        problems = validate_decks.check_numbers_across([rules])
        self.assertTrue(any("no hi deck teaches a number theme" in p for p in problems), problems)
