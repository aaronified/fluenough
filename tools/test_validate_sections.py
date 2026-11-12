#!/usr/bin/env python3
"""decks/sections.yaml (wiki/Plan-Deck-Kinds-And-Topics.md, D8): the Decks
tab's sections, the genres, the professions and the search kinds, as data.
Also main's bundled copy, which must validate as the fixture's does."""

from __future__ import annotations

import unittest

import kinds_testlib as k
from kinds_testlib import KindsCase, SECTIONS

import validate_decks as vd


def genre(d: dict, gid: str) -> dict:
    return next(g for g in d["genres"] if g["id"] == gid)


class Sections(KindsCase):
    def check(self, change, needle: str) -> None:
        self.edit(SECTIONS, change)
        self.assertIn(needle, "\n".join(self.errors(SECTIONS)))

    def test_the_fixture_file_is_valid(self) -> None:
        self.assertEqual(self.errors(SECTIONS), [])

    def test_the_starter_file_on_main_is_valid(self) -> None:
        self.assertEqual(vd.validate(k.REPO / "decks" / "sections.yaml").errors, [])

    def test_the_starter_lists_four_genres_and_nine_search_kinds(self) -> None:
        raw = k.load(k.REPO / "decks" / "sections.yaml")
        self.assertEqual([g["id"] for g in raw["genres"]],
                         ["culture", "proverbs", "multiword", "professional"])
        self.assertEqual(len(raw["search_kinds"]), 9)
        self.assertEqual(raw["professions"], [])

    def test_unknown_keys_are_refused(self) -> None:
        self.check(lambda d: d.__setitem__("colours", []), "unknown field 'colours'")

    def test_the_schema_is_one(self) -> None:
        self.check(lambda d: d.__setitem__("schema", 2), "schema: must be 1")

    def test_the_file_is_sections_yaml(self) -> None:
        self.put("sections-copy.yaml", self.data(SECTIONS))
        self.assertIn("a sections file is decks/sections.yaml",
                      "\n".join(self.errors("sections-copy.yaml")))

    def test_an_id_is_unique(self) -> None:
        self.check(lambda d: d["sections"].append(dict(d["sections"][0])), "is listed twice")

    def test_an_id_is_a_slug(self) -> None:
        self.check(lambda d: d["sections"][0].__setitem__("id", "Not A Slug"),
                   "id must match [a-z0-9-]+")

    def test_a_name_has_an_english_entry(self) -> None:
        self.check(lambda d: d["sections"][0].__setitem__("name", {"es": "Curso"}),
                   "name needs en")

    def test_a_section_is_listed_or_not(self) -> None:
        self.check(lambda d: d["sections"][0].__setitem__("listed", "yes"),
                   "listed must be true or false")

    def test_a_genre_names_a_section_of_the_file(self) -> None:
        self.check(lambda d: genre(d, "culture").__setitem__("section", "nowhere"),
                   "section 'nowhere' is not a section of the file")

    def test_a_genre_names_a_search_kind_of_the_file(self) -> None:
        self.check(lambda d: genre(d, "culture").__setitem__("search_kind", "nowhere"),
                   "search_kind 'nowhere' is not a search kind of the file")

    def test_a_genre_weaves_or_not(self) -> None:
        self.check(lambda d: genre(d, "culture").__setitem__("weave", "sometimes"),
                   "weave must be true or false")

    def test_a_genre_must_be_one_the_validator_knows(self) -> None:
        def change(d: dict) -> None:
            d["genres"].append({"id": "poetry", "name": {"en": "Poetry"},
                                "section": "beyond-basics", "search_kind": "culture"})
        self.check(change, "'poetry' is not a genre the validator knows")

    def test_every_genre_the_validator_knows_is_listed(self) -> None:
        self.check(lambda d: d.__setitem__(
            "genres", [g for g in d["genres"] if g["id"] != "proverbs"]),
            "does not list 'proverbs'")

    def test_a_search_row_is_one_of_six_templates(self) -> None:
        self.check(lambda d: d["search_kinds"][0].__setitem__("row", "poster"),
                   "row must be one of scene, topic, deck, concept, card, unit")

    def test_a_search_order_is_unique(self) -> None:
        self.check(lambda d: d["search_kinds"][1].__setitem__("order", 1),
                   "order 1 is used twice")

    def test_a_search_order_is_a_number(self) -> None:
        self.check(lambda d: d["search_kinds"][1].__setitem__("order", "second"),
                   "order must be a whole number")

    def test_the_professions_may_be_empty_or_missing(self) -> None:
        self.edit(SECTIONS, lambda d: d.pop("professions"))
        self.assertEqual(self.errors(SECTIONS), [])

    def test_a_profession_has_a_name(self) -> None:
        self.check(lambda d: d["professions"][0].pop("name"), "name must map language codes")

    def test_the_file_is_under_512_kb(self) -> None:
        def change(d: dict) -> None:
            d["professions"] = [{"id": f"p{n}", "name": {"en": "x" * 60}}
                                for n in range(9000)]
        self.check(change, "is over 512 KB")


if __name__ == "__main__":
    unittest.main()
