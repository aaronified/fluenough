"""Tests for tools/propose_pairs.py (#421): the minimal pairs it proposes,
the ones it leaves out, and that it changes no file."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import propose_pairs  # noqa: E402

DECK = """\
schema: 1
id: zz-en-words
name: "Words"
language: {{ code: zz, iso639_3: zzz, name: Zedish, script: latin }}
native: {{ code: en, iso639_3: eng, name: English }}
license: CC0-1.0
{tags}
cards:
{cards}
"""


def card(cid: str, ipa: str, extra: str = "") -> str:
    return (f'  - {{ id: {cid}, target: "{cid}", native: "w", '
            f'reading: "{cid}r", ipa: "{ipa}"{extra} }}')


def deck(*cards: str, tags: str = "") -> str:
    return DECK.format(cards="\n".join(cards), tags=tags)


def words_of(text: str) -> list:
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "zz" / "zz-words.yaml"
        path.parent.mkdir()
        path.write_text(text, encoding="utf-8")
        before = path.read_text(encoding="utf-8")
        words = propose_pairs.load_words([path])
        assert path.read_text(encoding="utf-8") == before
        return words


class CloseSoundsTest(unittest.TestCase):
    def test_the_kinds_of_closeness(self):
        self.assertEqual(propose_pairs.close_sounds("a", "aː"), "length")
        self.assertEqual(propose_pairs.close_sounds("k", "kʰ"), "aspiration")
        self.assertEqual(propose_pairs.close_sounds("t̪", "ʈ"), "place")

    def test_far_sounds_and_double_differences_are_not_close(self):
        self.assertIsNone(propose_pairs.close_sounds("p", "m"))
        self.assertIsNone(propose_pairs.close_sounds("a", "e"))
        self.assertIsNone(propose_pairs.close_sounds("a", "a"))
        # long and different
        self.assertIsNone(propose_pairs.close_sounds("aː", "e"))
        # both the place and the aspiration differ
        self.assertIsNone(propose_pairs.close_sounds("t̪", "ʈʰ"))


class ProposeTest(unittest.TestCase):
    def test_a_long_and_a_short_vowel_are_proposed_once(self):
        words = words_of(deck(card("zz-0001", "kalam"), card("zz-0002", "kaːlam"),
                              card("zz-0003", "tipo")))
        found = propose_pairs.propose(words)
        self.assertEqual([(p.a.id, p.b.id, p.difference) for p in found],
                         [("zz-0001", "zz-0002", "length")])

    def test_a_far_word_and_a_two_sound_difference_are_not_proposed(self):
        words = words_of(deck(card("zz-0001", "kalam"), card("zz-0002", "kaːlaːm"),
                              card("zz-0003", "pelun")))
        self.assertEqual(propose_pairs.propose(words), [])

    def test_a_short_word_is_left_out(self):
        words = words_of(deck(card("zz-0001", "ka"), card("zz-0002", "kaː")))
        self.assertEqual(propose_pairs.propose(words), [])

    def test_a_pair_already_written_is_left_out_unless_asked_for(self):
        note = ', notes: [{ kind: "pair", ref: "zz-0002", text: "Long a." }]'
        words = words_of(deck(card("zz-0001", "kalam", note),
                              card("zz-0002", "kaːlam")))
        self.assertEqual(propose_pairs.propose(words), [])
        self.assertEqual(len(propose_pairs.propose(words, written=True)), 1)

    def test_a_card_pair_field_counts_as_written(self):
        words = words_of(deck(card("zz-0001", "kalam", ', pair: "zz-0002"'),
                              card("zz-0002", "kaːlam")))
        self.assertEqual(propose_pairs.propose(words), [])

    def test_an_offensive_word_is_left_out(self):
        words = words_of(deck(card("zz-0001", "kalam"),
                              card("zz-0002", "kaːlam", ', tags: ["offensive"]')))
        self.assertEqual(propose_pairs.propose(words), [])

    def test_words_of_other_languages_are_not_paired(self):
        a = propose_pairs.Word("zz-0001", "zz", "a", "a", "kalam")
        b = propose_pairs.Word("yy-0001", "yy", "b", "b", "kaːlam")
        self.assertEqual(propose_pairs.propose([a, b]), [])

    def test_the_proposal_names_the_sounds_and_the_note_to_paste(self):
        words = words_of(deck(card("zz-0001", "pat̪a"), card("zz-0002", "paʈa")))
        (p,) = propose_pairs.propose(words)
        self.assertEqual(p.sounds, ("t\u032a", "ʈ"))
        self.assertIn('ref: "zz-0002"', propose_pairs.note_for(p.a, p.b))


if __name__ == "__main__":
    unittest.main()
