#!/usr/bin/env python3
"""A language's topics file, decks/<code>/<code>-topics.yaml (wiki/Plan-Deck-
Kinds-And-Topics.md, D6): ids, names, what a topic covers (decks, units,
cards, grammar, situations, topics, and, for scripts, script units and lists
of characters), and every reference resolved across the language's files."""

from __future__ import annotations

import unittest

from kinds_testlib import KindsCase, TOPICS

SCRIPT_TOPIC = "zz-juktakkhor"
VERBS = "zz-reflexive-verbs"
CONFERENCE = "zz-conference"


def topic(data: dict, tid: str) -> dict:
    return next(t for t in data["topics"] if t["id"] == tid)


class Topics(KindsCase):
    def check(self, change, needle: str) -> None:
        self.edit(TOPICS, change)
        self.assertIn(needle, "\n".join(self.errors(TOPICS)))

    def reject(self, change, needle: str) -> None:
        self.edit(TOPICS, change)
        self.assertRejected(needle)

    def test_the_fixture_file_is_valid(self) -> None:
        self.assertEqual(self.errors(TOPICS), [])
        self.assertValid()

    def test_a_script_topic_names_script_units_and_characters(self) -> None:
        t = topic(self.data(TOPICS), SCRIPT_TOPIC)
        self.assertEqual(t["script_units"], ["conjuncts", "r-forms"])
        self.assertIn("ক্ষ", t["chars"])
        self.assertNotIn("decks", t)

    def test_a_topic_may_cover_a_hidden_deck(self) -> None:
        self.assertEqual(topic(self.data(TOPICS), CONFERENCE)["decks"], ["zz-medicine-registro"])
        self.assertValid()

    # The file

    def test_the_file_is_named_for_its_language(self) -> None:
        self.check(lambda d: d.__setitem__("id", "xx-topics"), "a topics file is zz-topics.yaml")

    def test_unknown_keys_are_refused(self) -> None:
        self.check(lambda d: d.__setitem__("colour", "red"), "unknown field 'colour'")

    def test_topics_are_a_list(self) -> None:
        self.check(lambda d: d.__setitem__("topics", []), "topics: must be a non-empty list")

    # A topic

    def test_an_id_is_the_languages(self) -> None:
        self.check(lambda d: topic(d, VERBS).__setitem__("id", "xx-verbs"), "id must be zz-")

    def test_an_id_is_unique(self) -> None:
        self.check(lambda d: topic(d, VERBS).__setitem__("id", SCRIPT_TOPIC),
                   "duplicate topic id")

    def test_a_name_has_an_english_entry(self) -> None:
        self.check(lambda d: topic(d, VERBS).__setitem__("name", {"es": "Verbos"}),
                   "name needs en")

    def test_a_term_in_another_script_needs_its_reading(self) -> None:
        self.check(lambda d: topic(d, SCRIPT_TOPIC).__setitem__(
            "term", {"text": "যুক্তাক্ষর"}), "needs its reading")

    def test_a_level_is_one_of_the_six(self) -> None:
        self.check(lambda d: topic(d, VERBS).__setitem__("level", "A0"), "level must be one of")

    def test_a_topic_covers_something(self) -> None:
        def change(d: dict) -> None:
            for key in ("decks", "cards", "units", "topics"):
                topic(d, VERBS).pop(key)
        self.check(change, "covers nothing: list at least one of")

    def test_a_list_is_not_empty(self) -> None:
        self.check(lambda d: topic(d, VERBS).__setitem__("cards", []),
                   "cards must be a non-empty list, or left out")

    def test_a_list_names_an_item_once(self) -> None:
        self.check(lambda d: topic(d, VERBS).__setitem__("cards", ["zz-9501", "zz-9501"]),
                   "'zz-9501' is listed twice")

    def test_a_topic_does_not_list_itself(self) -> None:
        self.check(lambda d: topic(d, VERBS).__setitem__("topics", [VERBS]),
                   "a topic does not list itself")

    def test_a_related_topic_is_in_the_file(self) -> None:
        self.check(lambda d: topic(d, VERBS).__setitem__("topics", ["zz-nada"]),
                   "which is not in the file")

    def test_a_deck_is_a_core_id(self) -> None:
        self.check(lambda d: topic(d, VERBS).__setitem__("decks", ["xx-deck"]),
                   "must be a core id of zz")

    def test_a_card_is_a_card_id(self) -> None:
        self.check(lambda d: topic(d, VERBS).__setitem__("cards", ["nope"]),
                   "must be a zz card id")

    # Characters

    def test_a_character_has_no_spaces(self) -> None:
        self.check(lambda d: topic(d, SCRIPT_TOPIC)["chars"].append("ক ক"),
                   "a character is a letter, sign or conjunct")

    def test_a_character_is_short(self) -> None:
        self.check(lambda d: topic(d, SCRIPT_TOPIC)["chars"].append("ক" * 13),
                   "at most 12 code points")

    def test_a_character_is_listed_once(self) -> None:
        self.check(lambda d: topic(d, SCRIPT_TOPIC)["chars"].append("ক্ষ"), "listed twice")

    def test_a_character_may_carry_its_reading(self) -> None:
        def change(d: dict) -> None:
            topic(d, SCRIPT_TOPIC)["chars"].append({"text": "ঙ্ক", "reading": "ngk"})
        self.edit(TOPICS, change)
        self.assertEqual(self.errors(TOPICS), [])

    def test_a_character_in_another_script_with_a_mapping_needs_its_reading(self) -> None:
        self.check(lambda d: topic(d, SCRIPT_TOPIC)["chars"].append({"text": "ঙ্ক"}),
                   "needs its reading")

    # Across files

    def test_a_deck_must_be_a_deck_of_the_language(self) -> None:
        self.reject(lambda d: topic(d, VERBS).__setitem__("decks", ["zz-nada"]),
                    "decks names 'zz-nada', which is not a deck of zz")

    def test_a_unit_must_be_on_the_path(self) -> None:
        self.reject(lambda d: topic(d, VERBS).__setitem__("units", ["zz-nada"]),
                    "units names 'zz-nada', which is not a unit of zz's path")

    def test_a_card_must_exist(self) -> None:
        self.reject(lambda d: topic(d, VERBS).__setitem__("cards", ["zz-9999"]),
                    "cards[0] names card zz-9999, which no deck writes")

    def test_a_script_unit_must_be_a_feature_of_the_script_guide(self) -> None:
        self.reject(lambda d: topic(d, SCRIPT_TOPIC).__setitem__("script_units", ["nada"]),
                    "script_units names 'nada', which is not a script guide feature of zz")

    def test_a_situation_must_exist(self) -> None:
        self.reject(lambda d: topic(d, VERBS).__setitem__("situations", ["taxi"]),
                    "situations names 'taxi', which is not a situation of zz")

    def test_a_grammar_concept_must_be_on_the_path(self) -> None:
        self.reject(lambda d: topic(d, VERBS).__setitem__("grammar", ["nada"]),
                    "grammar names 'nada', which is not a grammar concept or rule of zz")

    def test_a_script_unit_resolves_without_the_guide_being_given(self) -> None:
        # The guide is read from the language's folder when only the topics
        # file is validated.
        self.assertEqual(self.errors(TOPICS), [])
        code, text = self.run_main()
        self.assertEqual(code, 0, text)


if __name__ == "__main__":
    unittest.main()
