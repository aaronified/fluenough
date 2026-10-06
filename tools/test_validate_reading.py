#!/usr/bin/env python3
"""Reading decks (#98, ADR-0019): passages and their questions, on their own
and against the rest of their course. Described in docs/DECK-FORMAT.md.

Stdlib `unittest` plus PyYAML, like the validator itself.
"""

from __future__ import annotations

import contextlib
import io
import shutil
import tempfile
import unittest
from pathlib import Path

import validate_decks

HEADER = """\
schema: 1
id: bn-en-reading-probe
name: "Probe"
kind: reading
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
source: "A book, in the public domain"
"""

SENTENCES = """\
      - text: "সে কাজ ক’রে বাড়ি যায়।"
        reading: "she kaj kore bari jay."
      - text: "বাড়িতে সে ভাত খায়।"
        reading: "barite she bhat khay."
"""

QUESTIONS = """\
      - id: bn-9101
        prompt: { en: "They eat rice at home.", bn: "সে বাড়িতে ভাত খায়।" }
        answer: true
      - id: bn-9102
        prompt: { en: "Where do they go?" }
        options:
          - { en: "Home" }
          - { en: "To the market" }
        answer: 1
"""

GLOSSARY = """\
    glossary:
      - word: "ক’রে"
        modern: "করে"
        reading: "kore"
        meaning: { en: "having done" }
        note: { en: "older spelling; the apostrophe marks a dropped ই (i)" }
"""


def deck(sentences: str = SENTENCES, questions: str = QUESTIONS,
         extra: str = GLOSSARY, header: str = HEADER) -> str:
    return (f"{header}passages:\n  - id: bn-home\n    title: \"Going home\"\n"
            f"    theme: market\n{extra}    sentences:\n{sentences}"
            f"    questions:\n{questions}")


def question(body: str) -> str:
    """One question, [body] after its id, and a second that is valid."""
    return f"      - id: bn-9103\n{body}" + QUESTIONS.split("      - id: bn-9102\n")[0]


class Reading(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def write(self, text: str, name: str = "bn-en-reading-probe.yaml"
              ) -> validate_decks.Report:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def assertRejected(self, report: validate_decks.Report, needle: str) -> None:
        self.assertTrue(
            any(needle in e for e in report.errors),
            f"expected an error containing {needle!r}, got {report.errors}",
        )


class ReadingDeck(Reading):
    def test_a_reading_deck_is_valid(self) -> None:
        report = self.write(deck())
        self.assertEqual(report.errors, [])
        self.assertEqual(report.warnings, [])
        pid, theme, words, glossed = report.passages[2][0]
        self.assertEqual((pid, theme), ("bn-home", "market"))
        self.assertIn("ক’রে", words)
        self.assertEqual(glossed, {"ক’রে", "করে"})

    def test_a_question_id_is_used_once_in_the_deck(self) -> None:
        twice = QUESTIONS.replace("id: bn-9102", "id: bn-9101")
        self.assertRejected(self.write(deck(questions=twice)),
                            "duplicate id 'bn-9101'")
        # A question id is a card id (ADR-0018); a passage's names it.
        self.assertRejected(
            self.write(deck(questions=QUESTIONS.replace("id: bn-9102", "id: home-q2"))),
            "id must be bn- and at least four digits")
        self.assertRejected(
            self.write(deck().replace("  - id: bn-home\n", "  - id: bn-9100\n")),
            "id must start with bn- and name the passage")

    def test_an_answer_is_an_option_number_or_true_or_false(self) -> None:
        for body, needle in (
            ('        prompt: { en: "A?" }\n        options: [{ en: "A" }, { en: "B" }]\n'
             '        answer: 3\n', "from 1 to 2, got 3"),
            ('        prompt: { en: "A?" }\n        options: [{ en: "A" }, { en: "B" }]\n'
             '        answer: true\n', "from 1 to 2, got True"),
            ('        prompt: { en: "A?" }\n        options: [{ en: "A" }, { en: "B" }]\n'
             '        answer: 0\n', "from 1 to 2, got 0"),
            ('        prompt: { en: "A." }\n        answer: 1\n', "true or false"),
        ):
            with self.subTest(body=body):
                self.assertRejected(self.write(deck(questions=question(body))), needle)

    def test_two_to_four_options_and_questions(self) -> None:
        one = '[{ en: "A" }]'
        five = ", ".join('{ en: "%s" }' % c for c in "ABCDE")
        for options in (one, f"[{five}]"):
            with self.subTest(options=options):
                self.assertRejected(self.write(deck(questions=question(
                    f'        prompt: {{ en: "A?" }}\n        options: {options}\n'
                    f'        answer: 1\n'))), "2 to 4 options")
        single = QUESTIONS.split("      - id: bn-9102\n")[0]
        self.assertRejected(self.write(deck(questions=single)), "2 to 4 questions")

    def test_text_is_keyed_by_language_with_english(self) -> None:
        self.assertRejected(
            self.write(deck(questions=question('        prompt: { bn: "ভাত?" }\n'
                                               '        answer: true\n'))),
            "prompt needs en")
        # A bare no reads as false, so the key is no language code.
        self.assertRejected(
            self.write(deck(questions=question('        prompt: { en: "A.", no: "B." }\n'
                                               '        answer: true\n'))),
            "boolean")

    def test_every_option_is_in_the_prompt_s_languages(self) -> None:
        self.assertRejected(self.write(deck(questions=question(
            '        prompt: { en: "Which?", bn: "কোনটা?" }\n'
            '        options: [{ en: "A", bn: "ক" }, { en: "B" }]\n'
            '        answer: 1\n'))), "options[1] is written in ['en']")

    def test_a_sentence_has_text_and_in_this_script_a_reading(self) -> None:
        self.assertRejected(
            self.write(deck(sentences='      - text: "সে যায়।"\n')),
            "reading is required")
        self.assertRejected(
            self.write(deck(sentences='      - text: yes\n        reading: "x"\n')),
            "boolean")
        self.assertRejected(self.write(deck(sentences="      []\n")),
                            "sentences must be a non-empty list")

    def test_passage_text_is_never_asked_to_change(self) -> None:
        # Decomposed য + ়, which NFC would not compose: no warning, since
        # a quotation stays as the book writes it.
        decomposed = deck(sentences='      - text: "য়ে ক’রে"\n        reading: "x"\n')
        report = self.write(decomposed)
        self.assertEqual(report.errors, [])
        self.assertFalse(any("NFC" in w for w in report.warnings), report.warnings)
        spaced = self.write(deck(sentences='      - text: " ক’রে "\n        reading: "x"\n'))
        self.assertEqual(spaced.errors, [])
        self.assertTrue(any("kept exactly as written" in w for w in spaced.warnings))

    def test_a_glossed_word_occurs_in_its_passage_letter_for_letter(self) -> None:
        straight = GLOSSARY.replace("ক’রে", "ক'রে")
        self.assertRejected(self.write(deck(extra=straight)),
                            "does not occur in the passage")
        self.assertRejected(self.write(deck(extra=GLOSSARY.replace("ক’রে", "লয়"))),
                            "does not occur in the passage")
        twice = GLOSSARY + GLOSSARY.split("    glossary:\n")[1]
        self.assertRejected(self.write(deck(extra=twice)), "listed twice")

    def test_a_glossary_entry_has_a_modern_form_reading_and_meaning(self) -> None:
        for old, new, needle in (
            ('        modern: "করে"\n', "", "modern is required"),
            ('        reading: "kore"\n', "", "reading is required"),
            ('meaning: { en: "having done" }', 'meaning: { bn: "করে" }', "meaning needs en"),
            ("note: { en:", "note: { bn:", "note needs en"),
            ('        note:', '        sense: "x"\n        note:', "unknown field 'sense'"),
        ):
            with self.subTest(needle=needle):
                self.assertRejected(self.write(deck(extra=GLOSSARY.replace(old, new))),
                                    needle)

    def test_passages_are_only_for_a_reading_deck_and_cards_not(self) -> None:
        self.assertRejected(self.write(deck(header=HEADER.replace("kind: reading\n", ""))),
                            "only valid on a reading deck")
        with_cards = deck() + 'cards:\n  - { id: c1, target: "x", native: "y" }\n'
        self.assertRejected(self.write(with_cards), "has passages, not cards")
        themed = deck(header=HEADER + "theme: market\n")
        self.assertRejected(self.write(themed), "only a vocab deck teaches a theme")

    def test_a_card_cannot_be_drilled_by_reading(self) -> None:
        card = HEADER.replace("kind: reading\n", "").replace("bn-en-reading-probe",
                                                            "bn-en-words")
        card += ('cards:\n  - { id: c1, target: "ভাত", native: "rice", reading: "bhat",'
                 ' modes: [reading] }\n')
        self.assertRejected(self.write(card, "bn-en-words.yaml"), "unknown mode 'reading'")


class ReadingAcrossDecks(Reading):
    WORDS = """\
schema: 1
id: bn-en-market
name: "Market"
theme: market
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: bn-9001, target: "সে", native: "he, she", reading: "she" }
  - { id: bn-9002, target: "ভাত খায়", native: "eats rice", reading: "bhat khay" }
"""

    def course(self, units: str = "  - [bn-en-market]\n  - [bn-en-reading-probe]\n"
               ) -> list[validate_decks.Report]:
        themes = self.write("schema: 1\nkind: themes\nthemes:\n"
                            "  - { id: market, name: \"Market\" }\n", "themes.yaml")
        path = self.write("schema: 1\nkind: path\nid: bn-en-path\nlanguage: bn\n"
                          f"native: en\nunits:\n{units}", "bn-en-path.yaml")
        words = self.write(self.WORDS, "bn-en-market.yaml")
        return [themes, path, words, self.write(deck())]

    def test_words_no_deck_teaches_are_warned_of_not_refused(self) -> None:
        reports = self.course()
        self.assertEqual(validate_decks.check_reading_across(reports), [])
        reading = reports[-1]
        self.assertEqual(reading.errors, [])
        warning = " ".join(reading.warnings)
        self.assertIn("words appear in no bn-en deck", warning)
        for word in ("কাজ", "বাড়ি", "যায়", "বাড়িতে"):
            self.assertIn(word, warning)
        # Taught, or glossed.
        for word in ("সে,", "ভাত", "খায়", "ক’রে"):
            self.assertNotIn(word, warning)

    def test_no_word_is_warned_of_without_the_course_s_decks(self) -> None:
        reading = self.write(deck())
        self.assertEqual(validate_decks.check_reading_across([reading]), [])
        self.assertEqual(reading.warnings, [])

    def test_a_passage_s_theme_is_on_the_theme_path(self) -> None:
        reports = self.course()
        reports[-1] = self.write(deck().replace("theme: market", "theme: moon"))
        problems = validate_decks.check_reading_across(reports)
        self.assertTrue(any("theme 'moon' is not in decks/themes.yaml" in p
                            for p in problems), problems)

    def test_a_passage_comes_after_its_theme_on_the_path(self) -> None:
        reports = self.course("  - [bn-en-reading-probe, bn-en-market]\n")
        validate_decks.check_reading_across(reports)
        self.assertTrue(any("put it in a later unit" in w for w in reports[-1].warnings),
                        reports[-1].warnings)
        later = self.course()
        validate_decks.check_reading_across(later)
        self.assertFalse(any("later unit" in w for w in later[-1].warnings))

    def test_the_whole_command_passes_with_warnings_only(self) -> None:
        self.course()
        (self.tmp / "pubspec.yaml").unlink(missing_ok=True)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = validate_decks.main(["validate_decks.py", str(self.tmp)])
        self.assertEqual(code, 0, out.getvalue())
        self.assertIn("words appear in no bn-en deck", out.getvalue())


if __name__ == "__main__":
    unittest.main()
