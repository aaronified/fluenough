#!/usr/bin/env python3
"""Tests for assets/languages.yaml as the tools read it: every entry carries
its ISO 639-3 code, names are not shared, each family and script is named in
the app, and each script that needs a font has one (ADR-0042)."""

from __future__ import annotations

import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import deck_index  # noqa: E402

try:
    import yaml
except ImportError:  # the tools need PyYAML
    yaml = None

REPO = Path(__file__).resolve().parent.parent
ARB = REPO / "lib" / "l10n" / "app_en.arb"
FAMILY_LIST = REPO / "lib" / "features" / "languages" / "language_views.dart"

# Scripts that have no font in decks/fonts, and so rely on the phone's own: a
# new script is added here or gets a FONTS entry or a FONT_ALIASES one, never
# none. Braille is drawn by the app itself (its shadow-dot font ships in it).
NO_FONT_YET = {"braille"}


def _languages() -> list[dict]:
    raw = yaml.safe_load((REPO / "assets" / "languages.yaml").read_text("utf-8"))
    return raw["languages"]


def _select_ids(key: str) -> set[str]:
    arb = json.loads(ARB.read_text("utf-8"))
    return set(re.findall(r"(\w+)\{", arb[key]))


@unittest.skipIf(yaml is None, "PyYAML is missing")
class LanguagesList(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.langs = _languages()

    def test_every_entry_has_a_three_letter_iso_639_3_code(self) -> None:
        for entry in self.langs:
            with self.subTest(code=entry["code"]):
                self.assertRegex(entry.get("iso639_3", ""), r"^[a-z]{3}$")

    def test_verification_is_none_some_or_full_when_given(self) -> None:
        # Hand-set by the owner; absent means "none" (Add a language).
        for entry in self.langs:
            with self.subTest(code=entry["code"]):
                self.assertIn(entry.get("verification", "none"), {"none", "some", "full"})

    def test_popular_is_a_boolean_and_is_the_tiles_in_the_owners_order(self) -> None:
        for entry in self.langs:
            with self.subTest(code=entry["code"]):
                self.assertIsInstance(entry.get("popular", False), bool)
        # The eight big tiles of Add a language, in file order (owner,
        # 2026-11-16); Mandarin Chinese is in the full list only.
        popular = [e["name"] for e in self.langs if e.get("popular")]
        self.assertEqual(
            popular,
            ["Spanish", "French", "Telugu", "Hindustani", "Bengali",
             "Marathi", "Kannada", "Japanese"],
        )

    def test_codes_are_unique(self) -> None:
        codes = [e["code"] for e in self.langs]
        self.assertEqual(len(codes), len(set(codes)))

    def test_an_alias_names_one_language_only(self) -> None:
        seen: dict[str, str] = {}
        for entry in self.langs:
            for alias in entry.get("aliases", []):
                key = alias.casefold()
                with self.subTest(alias=alias):
                    self.assertNotIn(key, seen,
                                     f"{alias!r} is an alias of {seen.get(key)} and {entry['code']}")
                    seen[key] = entry["code"]
        # An alias is never another entry's own name.
        names = {e["name"].casefold(): e["code"] for e in self.langs}
        for entry in self.langs:
            for alias in entry.get("aliases", []):
                owner = names.get(alias.casefold())
                with self.subTest(alias=alias, code=entry["code"]):
                    self.assertIn(owner, (None, entry["code"]))

    def test_indonesian_is_its_own_language_and_not_an_alias_of_malay(self) -> None:
        by_code = {e["code"]: e for e in self.langs}
        self.assertEqual(by_code["id"]["iso639_3"], "ind")
        malay = {a.casefold() for a in by_code["ms"].get("aliases", [])}
        self.assertFalse(malay & {"indonesian", "bahasa indonesia"})

    def test_every_family_is_named_in_the_app_and_listed(self) -> None:
        named = _select_ids("knownFamily")
        listed = set(re.findall(r"'(\w+)',", FAMILY_LIST.read_text("utf-8")))
        for entry in self.langs:
            family = entry.get("family")
            with self.subTest(code=entry["code"]):
                self.assertIsNotNone(family)
                self.assertIn(family, named)
                self.assertIn(family, listed)

    def test_every_script_is_named_in_the_app(self) -> None:
        named = _select_ids("scriptName")
        for entry in self.langs:
            for script in entry.get("scripts", []):
                with self.subTest(code=entry["code"], script=script):
                    self.assertIn(script, named)

    def test_every_script_has_a_font_or_is_known_to_have_none(self) -> None:
        used = {s for e in self.langs for s in e.get("scripts", [])}
        for script in sorted(used):
            with self.subTest(script=script):
                self.assertTrue(
                    script in deck_index.FONTS or script in deck_index.FONT_ALIASES
                    or script in NO_FONT_YET,
                    f"{script} has no FONTS entry, alias or NO_FONT_YET entry")
        for script in NO_FONT_YET:
            with self.subTest(stale=script):
                self.assertNotIn(script, deck_index.FONTS)
                self.assertNotIn(script, deck_index.FONT_ALIASES)

    def test_aliases_point_at_fonts_and_match_the_app(self) -> None:
        for script, target in deck_index.FONT_ALIASES.items():
            with self.subTest(script=script):
                self.assertIn(target, deck_index.FONTS)
                self.assertNotIn(script, deck_index.FONTS)
        dart = (REPO / "lib" / "core" / "decks" / "script_fonts.dart").read_text("utf-8")
        block = dart[dart.index("scriptFontAliases"):]
        block = block[:block.index("};")]
        self.assertEqual(dict(re.findall(r"'(\w+)': '(\w+)'", block)),
                         deck_index.FONT_ALIASES)

    def test_content_fonts_match_the_app_and_every_language_lists_latin(self) -> None:
        dart = (REPO / "lib" / "core" / "decks" / "script_fonts.dart").read_text("utf-8")
        block = dart[dart.index("contentFontScripts"):]
        block = block[:block.index("];")]
        self.assertEqual(tuple(re.findall(r"'(\w+)'", block)), deck_index.CONTENT_FONTS)
        for script in deck_index.CONTENT_FONTS:
            self.assertEqual(deck_index.FONTS[script][0], "Noto Sans")

    def test_santali_and_yiddish_scripts_have_their_fonts(self) -> None:
        for script in ("ol_chiki", "hebrew"):
            family, name = deck_index.FONTS[script]
            folder = REPO / "decks" / "fonts" / script
            with self.subTest(script=script):
                self.assertTrue((folder / name).is_file())
                self.assertTrue((folder / "OFL.txt").is_file())
                self.assertTrue(family.startswith("Noto Sans"))

    def test_persian_and_pashto_are_drawn_in_naskh_and_match_the_app(self) -> None:
        self.assertEqual(deck_index.LANGUAGE_FONTS, {
            ("fa", "perso_arabic"): "perso_arabic_naskh",
            ("ps", "perso_arabic"): "perso_arabic_naskh",
            ("sd", "perso_arabic"): "perso_arabic_naskh",
            ("ks", "perso_arabic"): "perso_arabic_naskh"})
        self.assertEqual(deck_index.FONTS["perso_arabic_naskh"][0], "Noto Naskh Arabic")
        dart = (REPO / "lib" / "core" / "decks" / "script_fonts.dart").read_text("utf-8")
        in_app = dict(re.findall(r"'(\w+:\w+)': '(\w+)'", dart))
        in_tool = {f"{c}:{s}": f for (c, s), f in deck_index.LANGUAGE_FONTS.items()}
        self.assertEqual(in_app, in_tool)
        # Hindustani keeps the Nastaliq font.
        fonts = deck_index._font_entries(["devanagari", "perso_arabic"], "hi")
        self.assertEqual([f["script"] for f in fonts], ["devanagari", "perso_arabic"])
        fonts = deck_index._font_entries(["perso_arabic"], "fa")
        self.assertEqual([(f["script"], f["family"]) for f in fonts],
                         [("perso_arabic_naskh", "Noto Naskh Arabic")])
        for entry in self.langs:
            if entry["code"] in ("fa", "ps"):
                self.assertIn("dialect", entry)

    def test_malay_teaches_malaysian_and_sanskrit_is_classical(self) -> None:
        by_code = {e["code"]: e for e in self.langs}
        self.assertIn("Malaysian", by_code["ms"]["dialect"])
        self.assertEqual(by_code["sa"]["name"], "Classical Sanskrit")
        self.assertIn("Sanskrit", by_code["sa"]["aliases"])
        self.assertIn("Pāṇini", by_code["sa"]["dialect"])

    def test_the_first_words_languages_are_listed_in_their_own_script(self) -> None:
        by_code = {e["code"]: e for e in self.langs}
        expect = {
            "af": ("afr", "latin"), "nl": ("nld", "latin"), "id": ("ind", "latin"),
            "uk": ("ukr", "cyrillic"), "fa": ("fas", "perso_arabic"),
            "ps": ("pus", "perso_arabic"), "sat": ("sat", "ol_chiki"),
            "sa": ("san", "devanagari"),
        }
        for code, (iso, script) in expect.items():
            with self.subTest(code=code):
                self.assertEqual(by_code[code]["iso639_3"], iso)
                self.assertEqual(by_code[code]["scripts"][0], script)


if __name__ == "__main__":
    unittest.main()
