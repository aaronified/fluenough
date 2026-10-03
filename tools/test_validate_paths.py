#!/usr/bin/env python3
"""Course paths (#117, ADR-0013): a path file on its own, and against the
decks of its course.

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


def path_file(units: str, path_id: str = "hi-en-path", lang: str = "hi",
              native: str = "en", extra: str = "") -> str:
    return f"""\
schema: 1
kind: path
id: {path_id}
language: {lang}
native: {native}
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
    def test_a_path_is_valid_and_lists_its_decks_in_order(self) -> None:
        report = self.write("hi-en-path.yaml", path_file(
            "  - [hi-en-market, hi-en-grammar-nouns]\n  - [hi-en-help]\n"))
        self.assertEqual(report.errors, [])
        self.assertEqual(report.course_path,
                         ("hi", "en", ["hi-en-market", "hi-en-grammar-nouns",
                                       "hi-en-help"]))

    def test_the_id_is_the_file_name_and_names_the_course(self) -> None:
        self.assertRejected(
            self.write("hi-en-route.yaml", path_file("  - [hi-en-market]\n")),
            "filename stem")
        self.assertRejected(
            self.write("bn-en-path.yaml",
                       path_file("  - [hi-en-market]\n", path_id="bn-en-path")),
            "has id hi-en-path")

    def test_the_codes_are_language_codes(self) -> None:
        report = self.write("hi-en-path.yaml",
                            path_file("  - [hi-en-market]\n", native="no"))
        # YAML reads a bare no as false; the message says so.
        self.assertRejected(report, "boolean")
        self.assertIsNone(report.course_path)

    def test_units_are_non_empty_lists_of_deck_ids(self) -> None:
        for units, needle in (
            ("  []\n", "non-empty list"),
            ("  - hi-en-market\n", "non-empty list of deck ids"),
            ("  - []\n", "non-empty list of deck ids"),
            ("  - [Hi_Market]\n", "must list deck ids"),
            ("  - [hi-en-market]\n  - [hi-en-market]\n", "listed twice"),
        ):
            with self.subTest(units=units):
                self.assertRejected(
                    self.write("hi-en-path.yaml", path_file(units)), needle)

    def test_a_wildcard_ends_a_unit_and_is_not_a_deck(self) -> None:
        report = self.write("hi-en-path.yaml", path_file(
            '  - [hi-en-market, "*"]\n  - [hi-en-help]\n  - ["*"]\n'))
        self.assertEqual(report.errors, [])
        self.assertEqual(report.course_path,
                         ("hi", "en", ["hi-en-market", "hi-en-help"]))
        self.assertEqual(report.open_units, [["hi-en-market"]])

    def test_a_wildcard_only_ends_a_unit_and_alone_only_the_last(self) -> None:
        for units, needle in (
            ('  - ["*", hi-en-market]\n', "can only end a unit"),
            ('  - [hi-en-market, "*", "*"]\n', "can only end a unit"),
            ('  - ["*"]\n  - [hi-en-market]\n', "alone can only be the last"),
        ):
            with self.subTest(units=units):
                self.assertRejected(
                    self.write("hi-en-path.yaml", path_file(units)), needle)

    def test_the_alphabet_decks_are_on_the_path(self) -> None:
        units = "  - [hi-en-script-vowels]\n  - [hi-en-market]\n"
        report = self.write("hi-en-path.yaml", path_file(
            units, extra="alphabet: [hi-en-script-vowels]\n"))
        self.assertEqual(report.errors, [])
        self.assertRejected(
            self.write("hi-en-path.yaml", path_file(
                units, extra="alphabet: [hi-en-spelling]\n")),
            "lists 'hi-en-spelling', which the path does not")
        self.assertRejected(
            self.write("hi-en-path.yaml", path_file(
                units, extra="alphabet: hi-en-script-vowels\n")),
            "must be a list")

    def test_unknown_fields_are_rejected(self) -> None:
        self.assertRejected(
            self.write("hi-en-path.yaml",
                       path_file("  - [hi-en-market]\n", extra="theme: x\n")),
            "unknown field 'theme'")


class PathAcrossDecks(Paths):
    def problems(self, units: str, *more: validate_decks.Report) -> list[str]:
        path = self.write("hi-en-path.yaml", path_file(units))
        return validate_decks.check_paths_across([*self.course(), path, *more])

    def test_a_path_listing_every_deck_of_its_course_passes(self) -> None:
        self.assertEqual(
            self.problems("  - [hi-en-market, hi-en-grammar-nouns]\n"), [])

    def test_every_deck_of_the_course_is_on_its_path(self) -> None:
        problems = self.problems("  - [hi-en-market]\n")
        self.assertTrue(any("does not list 'hi-en-grammar-nouns'" in p
                            for p in problems), problems)

    def test_only_decks_of_the_course_and_only_decks(self) -> None:
        problems = self.problems(
            "  - [hi-en-market, hi-en-grammar-nouns, bn-en-market, hi-en-gone]\n")
        self.assertTrue(any("'bn-en-market', which teaches bn from en" in p
                            for p in problems), problems)
        self.assertTrue(any("'hi-en-gone', which is not a deck" in p
                            for p in problems), problems)

    def test_a_wildcard_unit_needs_a_theme_deck(self) -> None:
        themed = self.write("hi-en-home.yaml", deck("hi-en-home", theme="home"))
        self.assertEqual(self.problems(
            '  - [hi-en-home, "*"]\n  - [hi-en-market, hi-en-grammar-nouns]\n'
            '  - ["*"]\n', themed), [])
        problems = self.problems(
            '  - [hi-en-home]\n  - [hi-en-market, hi-en-grammar-nouns, "*"]\n',
            themed)
        self.assertTrue(any("has no theme deck" in p for p in problems), problems)

    def test_a_course_has_one_path(self) -> None:
        other = self.tmp / "other"
        other.mkdir()
        (other / "hi-en-path.yaml").write_text(
            path_file("  - [hi-en-market, hi-en-grammar-nouns]\n"),
            encoding="utf-8")
        problems = self.problems("  - [hi-en-market, hi-en-grammar-nouns]\n",
                                 validate_decks.validate(other / "hi-en-path.yaml"))
        self.assertTrue(any("already has a path" in p for p in problems), problems)

    def test_a_course_without_a_path_is_not_checked(self) -> None:
        self.assertEqual(validate_decks.check_paths_across(self.course()), [])


if __name__ == "__main__":
    unittest.main()
