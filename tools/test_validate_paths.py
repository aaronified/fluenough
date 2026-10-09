#!/usr/bin/env python3
"""Paths (#117, ADR-0013, ADR-0036): a language's path file on its own, and
against the decks of the language, in every course.

Described in docs/DECK-FORMAT.md. Stdlib `unittest` plus PyYAML, like the
validator itself.
"""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import validate_decks


def deck(deck_id: str, lang: str = "hi", native: str = "en",
         theme: str | None = None) -> str:
    names = {"hi": ("hin", "Hindi", "devanagari", "hi-IN"),
             "bn": ("ben", "Bengali", "bengali", "bn-IN"),
             "en": ("eng", "English", "latin", "en-GB")}
    iso, name, script, tts = names[lang]
    n_iso, n_name, _, _ = names[native]
    return f"""\
schema: 1
id: {deck_id}
name: Probe
language: {{ code: {lang}, iso639_3: {iso}, name: {name}, script: {script}, tts: {tts} }}
native: {{ code: {native}, iso639_3: {n_iso}, name: {n_name} }}
license: CC0-1.0
{f"theme: {theme}" + chr(10) if theme else ""}cards:
  - id: {deck_id}-0001
    target: "x"
    native: the thing
    reading: "x"
"""


def path_file(units: str, path_id: str = "hi-path", lang: str = "hi",
              extra: str = "") -> str:
    return f"""\
schema: 1
kind: path
id: {path_id}
language: {lang}
{extra}units:
{units}"""


class Paths(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def write(self, name: str, text: str) -> validate_decks.Report:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def assertRejected(self, report: validate_decks.Report, needle: str) -> None:
        self.assertTrue(
            any(needle in e for e in report.errors),
            f"expected an error containing {needle!r}, got {report.errors}",
        )

    def course(self) -> list[validate_decks.Report]:
        """Two Hindi decks and a Bengali one, all valid."""
        return [
            self.write("hi-en-market.yaml", deck("hi-en-market")),
            self.write("hi-en-grammar-nouns.yaml", deck("hi-en-grammar-nouns")),
            self.write("bn-en-market.yaml", deck("bn-en-market", lang="bn")),
        ]


class PathFile(Paths):
    def test_a_path_is_valid_and_lists_its_decks_by_core_id_in_order(self) -> None:
        report = self.write("hi-path.yaml", path_file(
            "  - [hi-market, hi-grammar-nouns]\n  - [hi-help]\n"))
        self.assertEqual(report.errors, [])
        self.assertEqual(report.course_path,
                         ("hi", ["hi-market", "hi-grammar-nouns", "hi-help"]))

    def test_the_id_is_the_languages_and_the_file_name(self) -> None:
        self.assertRejected(
            self.write("hi-route.yaml", path_file("  - [hi-market]\n",
                                                  path_id="hi-route")),
            "a path of hi has id hi-path, the filename stem, got 'hi-route'")
        self.assertRejected(
            self.write("hi-route.yaml", path_file("  - [hi-market]\n")),
            "is 'hi-path' but the filename stem is 'hi-route'")

    def test_a_path_for_one_course_is_refused_and_told_what_to_do(self) -> None:
        report = self.write("hi-en-path.yaml", path_file(
            "  - [hi-en-market]\n", path_id="hi-en-path", extra="native: en\n"))
        self.assertIn(
            "native: a path is one per language learnt, decks/hi/hi-path.yaml, shared "
            "by every native language (ADR-0036); list core ids, such as "
            "'hi-market', and remove native", report.errors)
        self.assertIn("id: a path of hi has id hi-path, the filename stem, got "
                      "'hi-en-path'", report.errors)

    def test_the_language_is_a_language_code(self) -> None:
        report = self.write("hi-path.yaml",
                            path_file("  - [hi-market]\n", lang="false"))
        # YAML reads a bare false as a boolean; the message says so. (A bare
        # no is the string "no", YAML 1.2, as the app reads it.)
        self.assertRejected(report, "boolean")
        self.assertIsNone(report.course_path)

    def test_units_are_non_empty_lists_of_core_ids(self) -> None:
        for units, needle in (
            ("  []\n", "non-empty list"),
            ("  - hi-market\n", "must be a list of core ids, or a mapping"),
            ("  - []\n", "non-empty list of core ids"),
            ("  - [Hi_Market]\n", "'Hi_Market' is not a core id of hi: hi- and a "
                                  "name, such as hi-home"),
            ("  - [bn-market]\n", "'bn-market' is not a core id of hi"),
            ("  - [hi-market]\n  - [hi-market]\n", "'hi-market' is listed twice"),
        ):
            with self.subTest(units=units):
                self.assertRejected(
                    self.write("hi-path.yaml", path_file(units)), needle)

    def test_a_wildcard_ends_a_unit_and_is_not_a_deck(self) -> None:
        report = self.write("hi-path.yaml", path_file(
            '  - [hi-market, "*"]\n  - [hi-help]\n  - ["*"]\n'))
        self.assertEqual(report.errors, [])
        self.assertEqual(report.course_path, ("hi", ["hi-market", "hi-help"]))
        self.assertEqual(report.open_units, [["hi-market"]])

    def test_a_wildcard_only_ends_a_unit_and_alone_only_the_last(self) -> None:
        for units, needle in (
            ('  - ["*", hi-market]\n', "can only end a unit"),
            ('  - [hi-market, "*", "*"]\n', "can only end a unit"),
            ('  - ["*"]\n  - [hi-market]\n', "alone can only be the last"),
        ):
            with self.subTest(units=units):
                self.assertRejected(
                    self.write("hi-path.yaml", path_file(units)), needle)

    def test_the_alphabet_decks_are_on_the_path(self) -> None:
        units = "  - [hi-script-vowels]\n  - [hi-market]\n"
        report = self.write("hi-path.yaml", path_file(
            units, extra="alphabet: [hi-script-vowels]\n"))
        self.assertEqual(report.errors, [])
        self.assertRejected(
            self.write("hi-path.yaml", path_file(
                units, extra="alphabet: [hi-spelling]\n")),
            "lists 'hi-spelling', which the path does not")
        self.assertRejected(
            self.write("hi-path.yaml", path_file(
                units, extra="alphabet: [hi-en-script-vowels]\n")),
            "lists 'hi-en-script-vowels', which the path does not")
        self.assertRejected(
            self.write("hi-path.yaml", path_file(
                units, extra="alphabet: hi-script-vowels\n")),
            "must be a list")

    def test_unknown_fields_are_rejected(self) -> None:
        self.assertRejected(
            self.write("hi-path.yaml",
                       path_file("  - [hi-market]\n", extra="theme: x\n")),
            "unknown field 'theme'")


class PathAcrossDecks(Paths):
    def problems(self, units: str, *more: validate_decks.Report) -> list[str]:
        path = self.write("hi-path.yaml", path_file(units))
        return validate_decks.check_paths_across([*self.course(), path, *more])

    def test_a_path_listing_every_deck_of_the_language_passes(self) -> None:
        self.assertEqual(self.problems("  - [hi-market, hi-grammar-nouns]\n"), [])

    def test_every_deck_of_the_language_is_on_its_path(self) -> None:
        problems = self.problems("  - [hi-market]\n")
        self.assertIn(f"{self.tmp / 'hi-path.yaml'}: units: does not list "
                      f"'hi-grammar-nouns', the core id of hi-en-grammar-nouns; every "
                      f"deck of hi is on its path", problems)

    def test_a_deck_of_a_second_native_language_is_on_it_by_its_core_id(self) -> None:
        bengali = self.write("hi-bn-market.yaml", deck("hi-bn-market", native="bn"))
        self.assertEqual(self.problems("  - [hi-market, hi-grammar-nouns]\n", bengali),
                         [])
        bengali = self.write("hi-bn-words.yaml", deck("hi-bn-words", native="bn"))
        self.assertIn(f"{self.tmp / 'hi-path.yaml'}: units: does not list 'hi-words', "
                      f"the core id of hi-bn-words; every deck of hi is on its path",
                      self.problems("  - [hi-market, hi-grammar-nouns]\n", bengali))

    def test_a_listed_id_is_a_core_id_of_a_deck_of_the_language(self) -> None:
        problems = self.problems(
            "  - [hi-market, hi-grammar-nouns, hi-en-market, hi-gone]\n")
        where = self.tmp / "hi-path.yaml"
        self.assertIn(f"{where}: units[0]: lists 'hi-en-market', a deck of the hi-en "
                      f"course; a path lists core ids, here 'hi-market'", problems)
        self.assertIn(f"{where}: units[0]: lists 'hi-gone', which is no deck of hi: no "
                      f"core hi-gone, and no deck hi-<native>-gone", problems)

    def test_a_wildcard_unit_needs_a_theme_deck(self) -> None:
        themed = self.write("hi-en-home.yaml", deck("hi-en-home", theme="home"))
        self.assertEqual(self.problems(
            '  - [hi-home, "*"]\n  - [hi-market, hi-grammar-nouns]\n'
            '  - ["*"]\n', themed), [])
        problems = self.problems(
            '  - [hi-home]\n  - [hi-market, hi-grammar-nouns, "*"]\n',
            themed)
        self.assertTrue(any("has no theme deck" in p for p in problems), problems)

    def test_a_language_has_one_path(self) -> None:
        other = self.tmp / "other"
        other.mkdir()
        (other / "hi-path.yaml").write_text(
            path_file("  - [hi-market, hi-grammar-nouns]\n"), encoding="utf-8")
        problems = self.problems("  - [hi-market, hi-grammar-nouns]\n",
                                 validate_decks.validate(other / "hi-path.yaml"))
        self.assertIn(f"{other / 'hi-path.yaml'}: root: hi already has a path, "
                      f"{self.tmp / 'hi-path.yaml'}; a language has one", problems)

    def test_a_course_path_left_beside_it_is_a_second_path(self) -> None:
        (self.tmp / "hi-en-path.yaml").write_text(
            path_file("  - [hi-en-market]\n", path_id="hi-en-path",
                      extra="native: en\n"), encoding="utf-8")
        self.assertIn(f"{self.tmp / 'hi-path.yaml'}: root: hi already has a path, "
                      f"{self.tmp / 'hi-en-path.yaml'}; a language has one",
                      self.problems("  - [hi-market, hi-grammar-nouns]\n"))

    def test_a_language_without_a_path_is_not_checked(self) -> None:
        self.assertEqual(validate_decks.check_paths_across(self.course()), [])


if __name__ == "__main__":
    unittest.main()
