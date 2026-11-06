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
FAMILIES = {"te": ("Dravidian", "South-Central"),
            "hi": ("Indo-European", "Indo-Aryan")}


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
        found = rl.rows(self.index, NAMES, SCRIPTS, FAMILIES)
        self.assertEqual(found, [
            ("Hindustani", "Indo-European", "Indo-Aryan",
             "Devanagari, Perso-Arabic", "in progress"),
            ("Telugu", "Dravidian", "South-Central", "Telugu", "A1"),
        ])

    def test_the_table_has_a_header_and_a_row_each(self) -> None:
        text = rl.table(rl.rows(self.index, NAMES, SCRIPTS, FAMILIES))
        self.assertIn(
            "| Language | Family | Subfamily | Scripts | Level reached |",
            text.splitlines())
        self.assertIn("| Telugu | Dravidian | South-Central | Telugu | A1 |",
                      text.splitlines())

    def test_the_count_line_sits_directly_above_the_table(self) -> None:
        lines = rl.table(rl.rows(self.index, NAMES, SCRIPTS,
                                 FAMILIES)).splitlines()
        self.assertEqual(lines[0], "**2 languages**")
        self.assertEqual(lines[1], "")
        self.assertTrue(lines[2].startswith("| Language |"))
        # The count is the number of rows: the notation course is not one.
        self.assertEqual(len(lines) - 4, 2)

    def test_a_language_without_a_family_shows_dashes(self) -> None:
        found = rl.rows(self.index, NAMES, SCRIPTS, {})
        self.assertEqual(found[0][1:3], ("\u2014", "\u2014"))


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


class Families(unittest.TestCase):
    families = rl.language_families(
        rl.FAMILIES.read_text(encoding="utf-8"))

    def test_every_language_of_the_index_has_a_family_and_subfamily(
            self) -> None:
        import json
        index = json.loads(rl.INDEX.read_text(encoding="utf-8"))
        codes = {l["code"] for l in index["languages"]} - rl.NOTATION_CODES
        missing = sorted(codes - set(self.families))
        self.assertEqual(missing, [], "add these to language_families.yaml")

    def test_every_language_of_the_app_has_one_too(self) -> None:
        import yaml
        raw = yaml.safe_load(rl.LANGUAGES.read_text(encoding="utf-8"))
        codes = {e["code"] for e in raw["languages"]}
        missing = sorted(codes - set(self.families) - rl.NOTATION_CODES)
        self.assertEqual(missing, [], "add these to language_families.yaml")

    def test_a_constructed_language_names_its_closest_family(self) -> None:
        f = self.families
        self.assertEqual(f["eo"], ("Constructed", "Romance"))
        self.assertEqual(f["isv"], ("Constructed", "Slavic"))
        self.assertEqual(f["sjn"], ("Constructed", "Celtic"))
        self.assertEqual(f["qya"], ("Constructed", "Uralic"))
        for code in ("qhv", "tok", "jbo", "tlh", "qdo"):
            self.assertEqual(f[code], ("Constructed", "None"), code)

    def test_every_entry_names_a_family_and_a_subfamily(self) -> None:
        for code, (family, subfamily) in self.families.items():
            self.assertTrue(family and subfamily, code)


if __name__ == "__main__":
    unittest.main()
