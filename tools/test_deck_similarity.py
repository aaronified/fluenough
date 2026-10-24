"""Tests for tools/deck_similarity.py (#692): what a reviewer is warned of,
and that a note naming the pair explains it."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import deck_similarity  # noqa: E402

DECK = """\
schema: 1
id: hi-en-words
name: "Words"
language: {{ code: hi, iso639_3: hin, name: Hindi, script: devanagari }}
native: {{ code: en, iso639_3: eng, name: English }}
license: CC0-1.0
cards:
{cards}
"""


def card(cid: str, target: str, ipa: str, extra: str = "") -> str:
    return f'  - {{ id: {cid}, target: "{target}", ipa: "{ipa}"{extra} }}'


def run(*cards: str) -> list[deck_similarity.Similar]:
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp) / "hi"
        folder.mkdir()
        (folder / "hi-words.yaml").write_text(
            DECK.format(cards="\n".join(cards)), encoding="utf-8")
        return deck_similarity.find_similar(
            deck_similarity.load_words(sorted(Path(tmp).glob("*/*.yaml"))))


class SimilarityTests(unittest.TestCase):
    def test_close_sounds_are_listed_and_distant_ones_are_not(self):
        found = run(card("hi-1", "कल", "kəl"), card("hi-2", "खल", "kʰəl"),
                    card("hi-3", "पल", "pəl"))
        self.assertEqual([(s.kind, s.a.id, s.b.id) for s in found],
                         [("sound", "hi-1", "hi-2")])

    def test_dental_and_retroflex_pair(self):
        found = run(card("hi-1", "ताल", "t̪aːl"), card("hi-2", "टाल", "ʈaːl"))
        self.assertEqual(len(found), 1)

    def test_a_pair_note_explains_it(self):
        found = run(card("hi-1", "कल", "kəl", ', pair: "hi-2"'),
                    card("hi-2", "खल", "kʰəl"))
        self.assertTrue(found[0].explained)

    def test_same_spelling_with_another_sound_is_a_homograph(self):
        found = run(card("hi-1", "कल", "kəl"), card("hi-2", "कल", "kal"))
        self.assertEqual([s.kind for s in found], ["homograph"])

    def test_a_mark_apart_is_a_lookalike(self):
        found = run(card("hi-1", "ज़ीना", "ziːnaː"), card("hi-2", "जीना", "dʒiːnaː"))
        self.assertIn("lookalike", [s.kind for s in found])


if __name__ == "__main__":
    unittest.main()
