#!/usr/bin/env python3
"""Tests for readme_languages.py, which fills the README's languages list."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import readme_languages as rl  # noqa: E402

NAMES = {"telugu": "Telugu", "devanagari": "Devanagari",
         "perso_arabic": "Perso-Arabic", "latin": "Latin"}
SCRIPTS = {"hi": ["devanagari", "perso_arabic"]}


def unit(planned: bool = False, milestone: str | None = None) -> dict:
    out: dict = {"decks": ["x"]}
    if planned:
        out["planned"] = True
    if milestone:
        out["milestone"] = milestone
    return out


class LevelReached(unittest.TestCase):
    def test_the_highest_level_whose_units_are_all_written(self) -> None:
        units = [unit(), unit(milestone="A1"), unit(),
                 unit(milestone="A2"), unit(planned=True),
                 unit(milestone="B1", planned=True)]
        self.assertEqual(rl.level_reached(units), "A2")

    def test_a_planned_unit_before_a_milestone_holds_it_back(self) -> None:
        units = [unit(planned=True), unit(milestone="A1")]
        self.assertEqual(rl.level_reached(units), "in progress")

    def test_every_unit_written_is_b1(self) -> None:
        units = [unit(milestone="A1"), unit(milestone="A2"),
                 unit(milestone="B1"), unit()]
        self.assertEqual(rl.level_reached(units), "B1")

    def test_no_milestones_is_in_progress(self) -> None:
        self.assertEqual(rl.level_reached([unit()]), "in progress")


class Rows(unittest.TestCase):
    index = {"languages": [
        {"code": "te", "name": "Telugu", "script": "telugu",
         "units": [unit(milestone="A1")]},
        {"code": "hi", "name": "Hindustani", "script": "devanagari",
         "units": [unit(planned=True, milestone="A1")]},
        {"code": "ipa", "name": "IPA", "script": "ipa", "units": []},
    ]}

    def test_a_row_per_language_by_name_without_the_notation_courses(
            self) -> None:
        found = rl.rows(self.index, NAMES, SCRIPTS)
        self.assertEqual(found, [
            ("Hindustani", "Devanagari, Perso-Arabic", "in progress"),
            ("Telugu", "Telugu", "A1"),
        ])

    def test_the_table_has_a_header_and_a_row_each(self) -> None:
        text = rl.table(rl.rows(self.index, NAMES, SCRIPTS))
        self.assertEqual(text.splitlines()[0],
                         "| Language | Scripts | Level reached |")
        self.assertIn("| Telugu | Telugu | A1 |", text)


class Fill(unittest.TestCase):
    def test_replaces_only_what_is_between_the_markers(self) -> None:
        readme = f"before\n{rl.START}\nold\n{rl.END}\nafter\n"
        self.assertEqual(rl.fill(readme, "new"),
                         f"before\n{rl.START}\nnew\n{rl.END}\nafter\n")

    def test_filling_twice_changes_nothing(self) -> None:
        once = rl.fill(f"{rl.START}\n{rl.END}\n", "new")
        self.assertEqual(rl.fill(once, "new"), once)

    def test_a_missing_marker_is_an_error(self) -> None:
        with self.assertRaises(ValueError):
            rl.fill("no markers", "new")


class RealFiles(unittest.TestCase):
    def test_script_names_come_from_the_apps_strings(self) -> None:
        names = rl.script_names(rl.ARB.read_text(encoding="utf-8"))
        self.assertEqual(names["bengali"], "Eastern Nagari")
        self.assertEqual(names["perso_arabic"], "Perso-Arabic")


if __name__ == "__main__":
    unittest.main()
