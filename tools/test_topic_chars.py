#!/usr/bin/env python3
"""A script topic's `chars` checked against its decks, and
tools/topic_chars.py, which writes them (#1228). The fixture language zz
gets a deck of single characters in each test; no language or script is
named by the code under test.

Stdlib `unittest` plus PyYAML, like the tools.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import topic_chars  # noqa: E402
import validate_decks  # noqa: E402
from kinds_testlib import PATH, TOPICS, KindsCase  # noqa: E402

GLYPHS = "zz/zz-en-glyphs.yaml"
TOPIC = "zz-glyphs-script"


def glyph_deck() -> dict:
    """Three one-character cards and a two-character one."""
    def card(cid: str, target: str, native: str, pos: str) -> dict:
        return {"id": cid, "target": target, "native": native, "pos": pos}

    return {
        "schema": 1, "id": "zz-en-glyphs", "name": "Glyphs",
        "language": {"code": "zz", "iso639_3": "zzz", "name": "Testlang",
                     "script": "latin", "tts": "es-ES", "icon": "Zz"},
        "native": {"code": "en", "iso639_3": "eng", "name": "English"},
        "license": "CC-BY-SA-4.0", "tags": ["beginner"],
        "cards": [card("zz-9801", "ক", "ka", "letter"),
                  card("zz-9802", "খ", "kha", "letter"),
                  card("zz-9803", "ক্ষ", "kssa", "letter"),
                  card("zz-9804", "কখ", "kakha", "noun")]}


class TopicCharsCase(KindsCase):
    def setUp(self) -> None:
        super().setUp()
        self.put(GLYPHS, glyph_deck())
        self.edit(PATH, lambda d: (d.__setitem__("alphabet", ["zz-glyphs"]),
                                   d["units"].insert(2, ["zz-glyphs"])))
        self.set_topic(chars=["ক", "খ", "ক্ষ"])

    def set_topic(self, **fields: object) -> None:
        def change(d: dict) -> None:
            d["topics"] = [t for t in d["topics"] if t["id"] != TOPIC]
            d["topics"].append({"id": TOPIC, "name": {"en": "Glyphs"}, "kind": "script",
                                "level": "A1", "decks": ["zz-glyphs"], **fields})
        self.edit(TOPICS, change)

    def chars(self) -> list:
        topic = next(t for t in self.data(TOPICS)["topics"] if t["id"] == TOPIC)
        return topic["chars"]


class ValidatorChecks(TopicCharsCase):
    def test_chars_that_match_the_decks_are_valid(self) -> None:
        self.assertValid()

    def test_a_two_character_card_need_not_be_listed(self) -> None:
        # কখ is a card of the deck, and not one character.
        code, text = self.run_main()
        self.assertEqual(code, 0, text)
        self.assertNotIn("leaves out", text)

    def test_a_character_no_card_has_is_an_error(self) -> None:
        self.set_topic(chars=["ক", "খ", "ক্ষ", "গ"])
        self.assertRejected("chars lists 'গ', which is no card's target")

    def test_a_listed_two_character_target_is_allowed(self) -> None:
        self.set_topic(chars=["ক", "খ", "ক্ষ", "কখ"])
        self.assertValid()

    def test_a_character_may_carry_its_reading(self) -> None:
        self.set_topic(chars=["ক", {"text": "খ", "reading": "kha"}, "ক্ষ"])
        self.assertValid()

    def test_a_missing_character_is_a_warning_for_now(self) -> None:
        self.set_topic(chars=["ক", "খ"])
        code, text = self.run_main()
        self.assertEqual(code, 0, text)
        self.assertIn("chars leaves out 1 single-character card(s)", text)
        self.assertIn("'ক্ষ'", text)

    def test_a_missing_character_is_an_error_once_the_switch_is_on(self) -> None:
        self.set_topic(chars=["ক", "খ"])
        with mock.patch.object(validate_decks, "TOPIC_CHARS_MISSING_IS_ERROR", True):
            self.assertRejected("chars leaves out 1 single-character card(s)")

    def test_a_topic_of_script_units_only_is_valid(self) -> None:
        def change(d: dict) -> None:
            next(t for t in d["topics"] if t["id"] == "zz-juktakkhor").pop("chars")
        self.edit(TOPICS, change)
        self.assertValid()

    def test_chars_of_a_topic_without_decks_are_checked_against_its_script_units(self) -> None:
        def change(d: dict) -> None:
            next(t for t in d["topics"] if t["id"] == "zz-juktakkhor")["chars"].append("গ")
        self.edit(TOPICS, change)
        self.assertRejected("chars lists 'গ', which is no card's target")

    def test_a_topic_that_is_not_a_script_topic_is_not_checked(self) -> None:
        self.set_topic(chars=["ক", "খ", "ক্ষ", "গ"], kind="words")
        self.assertValid()


class Tool(TopicCharsCase):
    def run_tool(self, write: bool, all_targets: bool = False) -> tuple[list[str], int]:
        return topic_chars.run("zz", self.root, write, all_targets)

    def test_a_topic_that_matches_is_left_as_it_is(self) -> None:
        before = self.p(TOPICS).read_text(encoding="utf-8")
        report, differ = self.run_tool(write=True)
        self.assertEqual(differ, 0, report)
        self.assertEqual(self.p(TOPICS).read_text(encoding="utf-8"), before)

    def test_report_only_changes_nothing(self) -> None:
        self.set_topic(chars=["ক", "গ"])
        before = self.p(TOPICS).read_text(encoding="utf-8")
        report, differ = self.run_tool(write=False)
        self.assertEqual(differ, 1, report)
        self.assertEqual(self.p(TOPICS).read_text(encoding="utf-8"), before)

    def test_write_makes_the_list_match_the_decks(self) -> None:
        self.set_topic(chars=["ক", "গ"])
        report, differ = self.run_tool(write=True)
        self.assertEqual(differ, 1, report)
        self.assertEqual(self.chars(), ["ক", "খ", "ক্ষ"])
        self.assertValid()

    def test_write_adds_chars_to_a_topic_without_them(self) -> None:
        self.set_topic()
        self.run_tool(write=True)
        self.assertEqual(self.chars(), ["ক", "খ", "ক্ষ"])
        self.assertValid()

    def test_write_keeps_the_rest_of_the_file(self) -> None:
        self.set_topic(chars=["ক"])
        before = self.p(TOPICS).read_text(encoding="utf-8")
        others = [t for t in self.data(TOPICS)["topics"] if t["id"] != TOPIC]
        self.run_tool(write=True)
        after = self.p(TOPICS).read_text(encoding="utf-8")
        self.assertEqual([t for t in self.data(TOPICS)["topics"] if t["id"] != TOPIC],
                         others)
        # Everything before the rewritten topic's chars is as it was.
        head = before[:before.rindex("chars:")]
        self.assertTrue(after.startswith(head))

    def test_write_keeps_a_characters_reading(self) -> None:
        self.set_topic(chars=[{"text": "খ", "reading": "kha"}])
        self.run_tool(write=True)
        self.assertEqual(self.chars(), ["ক", {"text": "খ", "reading": "kha"}, "ক্ষ"])
        self.assertValid()

    def test_all_targets_lists_the_two_character_card_too(self) -> None:
        self.run_tool(write=True, all_targets=True)
        self.assertEqual(self.chars(), ["ক", "খ", "ক্ষ", "কখ"])
        self.assertValid()

    def test_a_topic_with_only_script_units_is_left_alone(self) -> None:
        before = next(t for t in self.data(TOPICS)["topics"] if t["id"] == "zz-juktakkhor")
        self.run_tool(write=True)
        after = next(t for t in self.data(TOPICS)["topics"] if t["id"] == "zz-juktakkhor")
        self.assertEqual(before, after)

    def test_main_check_fails_when_a_topic_differs(self) -> None:
        self.set_topic(chars=["ক"])
        argv = ["topic_chars.py", "zz", "--decks", str(self.root), "--check"]
        self.assertEqual(topic_chars.main(argv), 1)
        self.assertEqual(self.chars(), ["ক"])
        self.run_tool(write=True)
        self.assertEqual(topic_chars.main(argv), 0)

    def test_main_refuses_a_language_without_topics(self) -> None:
        self.assertEqual(topic_chars.main(
            ["topic_chars.py", "yy", "--decks", str(self.root)]), 2)


if __name__ == "__main__":
    unittest.main()
