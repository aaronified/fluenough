#!/usr/bin/env python3
"""Tests for tools/pick_warning.py."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pick_warning

RUDE = {"id": "xx-9", "target": "kala", "ipa": "kala", "register": "offensive"}
VERY_RUDE = dict(RUDE, id="xx-8", level="strongest")
PLAIN = {"id": "xx-7", "target": "kalo", "ipa": "kaːlo"}
FAR = {"id": "xx-6", "target": "pulim", "ipa": "pulim"}


def cards(*found: dict, tags: list | None = None) -> pick_warning.Index:
    return {c["id"]: (c, tags or []) for c in found}


def card(*notes: dict, senses: int = 0, ipa: str = "kaːla") -> dict:
    out: dict = {"id": "xx-1", "target": "kāla", "ipa": ipa, "notes": list(notes)}
    if senses:
        out["senses"] = [{"id": f"s{i}"} for i in range(senses)]
    return out


def pair(ref: str, nid: str | None = "pair") -> dict:
    note = {"kind": "pair", "ref": ref}
    if nid:
        note["id"] = nid
    return note


class SegmentsTest(unittest.TestCase):
    def test_length_aspiration_and_diacritics_stay_on_their_letter(self) -> None:
        self.assertEqual(pick_warning.segments("ˈkʰaːt̪a"), ["kʰ", "aː", "t̪", "a"])

    def test_a_tied_affricate_is_one_segment(self) -> None:
        self.assertEqual(pick_warning.segments("t͡ʃa"), ["t͡ʃ", "a"])

    def test_a_long_vowel_is_one_segment_from_a_short_one(self) -> None:
        self.assertEqual(pick_warning.distance(pick_warning.segments("kaːla"),
                                               pick_warning.segments("kala")), 1)


class PickTest(unittest.TestCase):
    def test_a_card_with_no_warning_gets_none_at_all(self) -> None:
        self.assertIsNone(pick_warning.pick(card(), cards()))

    def test_a_very_close_very_rude_word_wins_over_everything(self) -> None:
        c = card(pair("xx-7", "plain"), pair("xx-8", "rude"), senses=3)
        self.assertEqual(pick_warning.pick(c, cards(PLAIN, VERY_RUDE)), "rude")

    def test_a_rude_word_without_a_strong_level_gives_way(self) -> None:
        c = card(pair("xx-9", "rude"), senses=1)
        self.assertEqual(pick_warning.pick(c, cards(RUDE)), "senses")

    def test_a_very_rude_word_that_is_not_very_close_gives_way(self) -> None:
        far_rude = dict(VERY_RUDE, ipa="pulim")
        c = card(pair("xx-8", "rude"), senses=1)
        self.assertEqual(pick_warning.pick(c, cards(far_rude)), "senses")

    def test_a_rude_deck_tag_makes_the_partner_rude(self) -> None:
        c = card(pair("xx-7", "rude"))
        self.assertEqual(pick_warning.pick(c, cards(PLAIN, tags=["offensive"])), "none")

    def test_a_rude_word_alone_that_does_not_qualify_shows_none(self) -> None:
        self.assertEqual(pick_warning.pick(card(pair("xx-9")), cards(RUDE)), "none")

    def test_a_close_sound_alike_beats_other_meanings(self) -> None:
        c = card(pair("xx-7"), senses=4)
        self.assertEqual(pick_warning.pick(c, cards(PLAIN)), "pair")

    def test_two_meanings_beat_a_far_sound_alike_tie_drawn(self) -> None:
        c = card(pair("xx-6"), senses=2)
        self.assertIn(pick_warning.pick(c, cards(FAR)), ("pair", "senses"))

    def test_a_single_other_meaning_loses_to_a_far_sound_alike(self) -> None:
        c = card(pair("xx-6"), senses=1)
        self.assertEqual(pick_warning.pick(c, cards(FAR)), "pair")

    def test_a_homograph_ties_with_a_close_sound_alike_and_both_are_drawn(self) -> None:
        drawn = set()
        for n in range(40):
            c = card(pair("xx-7"), {"id": "spelt", "kind": "homograph", "ref": "xx-7"})
            c["id"] = f"xx-{n}"
            drawn.add(pick_warning.pick(c, cards(PLAIN)))
        self.assertEqual(drawn, {"pair", "spelt"})

    def test_the_draw_is_the_same_on_a_second_run(self) -> None:
        c = card(pair("xx-6"), senses=2)
        first = pick_warning.pick(c, cards(FAR))
        self.assertEqual({pick_warning.pick(c, cards(FAR)) for _ in range(5)}, {first})

    def test_a_note_without_an_id_is_named_by_its_place(self) -> None:
        c = card({"kind": "usage"}, pair("xx-7", None))
        self.assertEqual(pick_warning.pick(c, cards(PLAIN)), "2")

    def test_a_lookalike_one_mark_apart_is_close(self) -> None:
        other = {"id": "xx-5", "target": "কলম", "ipa": "kɔlom"}
        mine = {"id": "xx-1", "target": "কলম়", "ipa": "kɔlom",
                "notes": [{"id": "look", "kind": "lookalike", "ref": "xx-5"}],
                "senses": [{"id": "a"}, {"id": "b"}]}
        self.assertEqual(pick_warning.pick(mine, cards(other)), "look")

    def test_a_partner_without_ipa_is_taken_as_close(self) -> None:
        c = card(pair("xx-4"), senses=2)
        self.assertEqual(pick_warning.pick(c, cards({"id": "xx-4", "target": "x"})), "pair")


FILE = '''id: "xx-test"
cards:
  - id: "xx-1"
    target: "kāla"
    ipa: "kaːla"
    pos: "noun"
    notes:
      - { id: "pair", kind: "pair", ref: "xx-7" }
    examples:
      - { target: "kāla." }
  - id: "xx-2"
    target: "mana"
    senses:
      - { id: "a" }
  - id: "xx-3"
    target: "pona"
    warning: "senses"
    notes:
      - { id: "pair", kind: "pair", ref: "xx-7" }
'''


class SetWarningsTest(unittest.TestCase):
    def test_the_warning_goes_before_the_notes_or_senses(self) -> None:
        new, _ = pick_warning.set_warnings(FILE, {"xx-1": "pair", "xx-2": "senses"})
        self.assertIn('    pos: "noun"\n    warning: "pair"\n    notes:', new)
        self.assertIn('    target: "mana"\n    warning: "senses"\n    senses:', new)

    def test_a_card_with_another_warning_is_left_and_reported(self) -> None:
        new, changes = pick_warning.set_warnings(FILE, {"xx-3": "pair"})
        self.assertIn('    warning: "senses"\n', new)
        self.assertNotIn('warning: "pair"', new)
        self.assertEqual(changes, [{"card": "xx-3", "old": "senses", "new": None}])

    def test_a_second_run_changes_nothing(self) -> None:
        once, _ = pick_warning.set_warnings(FILE, {"xx-1": "pair"})
        twice, changes = pick_warning.set_warnings(once, {"xx-1": "pair"})
        self.assertEqual(once, twice)
        self.assertEqual(changes, [])

    def test_the_rest_of_the_file_is_untouched(self) -> None:
        new, _ = pick_warning.set_warnings(FILE, {"xx-1": "pair"})
        self.assertEqual(new.replace('    warning: "pair"\n', "", 1), FILE)


class MainTest(unittest.TestCase):
    def test_write_marks_the_cards_of_every_core_and_no_layer(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "xx").mkdir()
            (root / "xx" / "en").mkdir()
            (root / "xx" / "xx-test.yaml").write_text(FILE, encoding="utf-8")
            (root / "xx" / "xx-other.yaml").write_text(
                'id: "xx-other"\ncards:\n  - id: "xx-7"\n    target: "kalo"\n    ipa: "kalo"\n',
                encoding="utf-8")
            layer = 'id: "xx-en-test"\nkind: "layer"\ncards:\n  "xx-1":\n    native: "time"\n'
            (root / "xx" / "en" / "xx-en-test.yaml").write_text(layer, encoding="utf-8")
            self.assertEqual(pick_warning.main([str(root), "--write"]), 0)
            text = (root / "xx" / "xx-test.yaml").read_text(encoding="utf-8")
            self.assertIn('    pos: "noun"\n    warning: "pair"\n', text)
            self.assertIn('    target: "mana"\n    warning: "senses"\n', text)
            self.assertEqual((root / "xx" / "en" / "xx-en-test.yaml").read_text(
                encoding="utf-8"), layer)


if __name__ == "__main__":
    unittest.main()
