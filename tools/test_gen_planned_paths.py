#!/usr/bin/env python3
"""Tests for gen_planned_paths.py: each generated path meets the validator's
path rules (DECK-FORMAT.md, "The B1 plan"), checked here on the plan alone."""

from __future__ import annotations

import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gen_planned_paths as gp  # noqa: E402

try:
    import yaml
except ImportError:  # the tools need PyYAML; the parse checks are skipped without it
    yaml = None

THEMES_FILE = Path(__file__).resolve().parent.parent / "decks" / "themes.yaml"
ID = re.compile(r"^[a-z0-9-]+$")


class Plans(unittest.TestCase):
    def test_every_plan_meets_the_path_rules(self) -> None:
        for code in gp.LANGS:
            with self.subTest(code=code):
                units = gp.build_units(code)
                self.assertEqual(units[0]["kind"], "written")
                self.assertEqual(units[0]["words"], 10)
                marks = [u["milestone"] for u in units if "milestone" in u]
                self.assertEqual(marks, ["A1", "A2", "B1"])
                ids = [u["id"] for u in units]
                self.assertEqual(len(ids), len(set(ids)), "a unit id twice")
                topics = [t for u in units if u["kind"] == "grammar" for t in u["topics"]]
                self.assertEqual(len(topics), len(set(topics)), "a grammar topic twice")
                for u in units:
                    self.assertTrue(u["id"].startswith(code + "-"))
                    for t in u.get("topics", []):
                        self.assertRegex(t, ID)
                    if u["kind"] == "theme":
                        self.assertGreaterEqual(u["words"], 1)
                    if u["kind"] == "grammar":
                        self.assertTrue(u["topics"])
                # The first words are a deck of the phrasebook's unit, never a unit.
                self.assertNotIn(f"{code}-first-words", ids)
                self.assertNotIn(f"{code}-phrasebook-words", ids)

    def test_levels_sum_to_their_sizes(self) -> None:
        for code, lang in gp.LANGS.items():
            with self.subTest(code=code):
                sizes = gp.levels_of(lang)
                got = {"A1": 0, "A2": 0, "B1": 0}
                level = "A1"
                for u in gp.build_units(code):
                    got[level] += u.get("words", 0)
                    if "milestone" in u:
                        level = {"A1": "A2", "A2": "B1", "B1": "B1"}[u["milestone"]]
                self.assertEqual(got, sizes)
                total = sum(got.values())
                self.assertTrue(sum(sizes.values()) // 2 <= total <= sum(sizes.values()) * 3 // 2)

    def test_only_the_ancient_languages_set_levels(self) -> None:
        for code, lang in gp.LANGS.items():
            self.assertEqual("levels" in lang, bool(lang.get("ancient")), code)

    @unittest.skipIf(yaml is None, "PyYAML is missing")
    def test_themes_exist_in_themes_yaml(self) -> None:
        known = {t["id"] for t in yaml.safe_load(THEMES_FILE.read_text("utf-8"))["themes"]} \
            if THEMES_FILE.exists() else None
        if known is None:
            self.skipTest("decks/themes.yaml is not here")
        for table in (gp.A1_THEMES, gp.A2_THEMES, gp.B1_THEMES):
            for theme, _ in table:
                self.assertIn(theme, known)

    def test_ancient_courses_leave_out_modern_themes(self) -> None:
        for code in ("la", "vsn", "ang", "enm"):
            themes = {u["theme"] for u in gp.build_units(code) if u["kind"] == "theme"}
            self.assertFalse(themes & gp.ANCIENT_EXCLUDE, code)


class Rendering(unittest.TestCase):
    @unittest.skipIf(yaml is None, "PyYAML is missing")
    def test_the_yaml_parses_to_the_plan(self) -> None:
        for code in gp.LANGS:
            with self.subTest(code=code):
                doc = yaml.safe_load(gp.render(code))
                self.assertEqual(doc["id"], f"{code}-path")
                self.assertEqual(doc["language"], code)
                self.assertEqual(doc["kind"], "path")
                units = doc["units"]
                self.assertEqual(units[0]["decks"],
                                 [f"{code}-phrasebook", f"{code}-first-words", "*"])
                self.assertEqual(units[0]["words"], 10)
                self.assertEqual(units[-1], ["*"])
                passage_ids = []
                for u in units[1:-1]:
                    self.assertIn("planned", u)
                    self.assertTrue(("theme" in u["planned"]) != ("grammar" in u["planned"]))
                    for key in ("listening_passages", "reading_passages"):
                        self.assertEqual(len(u[key]), 1)
                        for p in u[key]:
                            self.assertRegex(p["id"], ID)
                            self.assertTrue(p["text"]["en"])
                            passage_ids.append(p["id"])
                self.assertEqual(len(passage_ids), len(set(passage_ids)))
                self.assertEqual([u["milestone"] for u in units[:-1] if "milestone" in u],
                                 ["A1", "A2", "B1"])
                self.assertEqual(doc["alphabet"], [])
                if gp.LANGS[code].get("levels"):
                    self.assertEqual(doc["levels"], gp.LANGS[code]["levels"])
                else:
                    self.assertNotIn("levels", doc)

    def test_rendering_is_deterministic(self) -> None:
        self.assertEqual(gp.render("pt"), gp.render("pt"))

    def test_allocate_sums_and_keeps_every_unit(self) -> None:
        for total, weights in ((690, [11, 33, 25]), (30, [1, 1, 1, 100]), (7, [5, 5, 5])):
            got = gp.allocate(total, weights)
            self.assertEqual(sum(got), total)
            self.assertTrue(all(n >= 1 for n in got))


class Wiring(unittest.TestCase):
    SAMPLE = (
        "units:\n"
        "  # 1. The phrasebook.\n"
        '  - planned: { id: "xx-phrasebook", theme: "first-words", words: 8 }\n'
        "    listening_passages:\n"
        '      - { id: "a", text: { "en": "A" } }\n'
        "    reading_passages:\n"
        '      - { id: "b", text: { "en": "B" } }\n'
        "  # 2. Next.\n"
        '  - planned: { id: "xx-sound-differences", grammar: "sound-differences", words: 12 }\n'
    )

    def test_unit_one_becomes_the_written_unit(self) -> None:
        out = gp.wire_unit_one("xx", self.SAMPLE)
        self.assertIn('  - decks: ["xx-phrasebook", "xx-first-words", "*"]\n    words: 10\n', out)
        self.assertNotIn('"a"', out)
        self.assertIn('id: "xx-sound-differences"', out)

    def test_wiring_twice_changes_nothing(self) -> None:
        once = gp.wire_unit_one("xx", self.SAMPLE)
        self.assertEqual(gp.wire_unit_one("xx", once), once)

    def test_a_path_without_the_planned_unit_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            gp.wire_unit_one("xx", "units:\n  - [\"*\"]\n")

    def test_main_writes_and_check_agrees(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for code in gp.WIRED:
                d = root / "decks" / code
                d.mkdir(parents=True)
                (d / f"{code}-path.yaml").write_text(
                    self.SAMPLE.replace("xx", code), encoding="utf-8")
            self.assertEqual(gp.main(["--root", tmp]), 0)
            self.assertEqual(gp.main(["--root", tmp, "--check"]), 0)
            self.assertTrue((root / "decks" / "pt" / "pt-path.yaml").exists())


if __name__ == "__main__":
    unittest.main()
