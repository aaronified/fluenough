#!/usr/bin/env python3
"""Base words and a new word for a card, from Suggest a change (#476): a
base added, changed or removed, and a change to the word with what it
brings, through the review file, the review bot and tools/proposals.py.

Stdlib `unittest` plus PyYAML. Every test works on a copy of
tools/fixtures/b1/zz, a made-up language, in a temporary directory, with
the fakes of tools/test_review_bot.py for Git and GitHub. No network.
"""

from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import mail_to_issues  # noqa: E402
import proposals as pr  # noqa: E402
import review_bot as rb  # noqa: E402
import validate_decks as vd  # noqa: E402
from test_proposals import ALICE, BOB, TOOLS  # noqa: E402
from test_review_bot import Base as BotBase, review_file  # noqa: E402

# A single-file deck: a phrase with one base written in full, and the word
# పాలు (pālu) as a card of its own.
PHRASES = """\
schema: 1
id: "zz-en-phrases"
name: "Phrases"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
cards:
  - id: "zz-9301"
    target: "అమ్మ పాలు"
    reading: "amma pālu"
    native: "mother's milk"
    bases:
      - { word: "అమ్మ", base: "అమ్మ", reading: "amma", meaning: "mum" }
  - id: "zz-9302"
    target: "పాలు"
    reading: "pālu"
    native: "milk"
"""

MUM = {"word": "అమ్మ", "base": "అమ్మ", "reading": "amma", "meaning": "mum"}


def base_suggestion(card: str, action: str, word: str, was: dict | None = None,
                    base: dict | None = None, why: str = "") -> dict:
    """A base's suggestion as the app writes it in the review file
    (lib/core/review/deck_review.dart, Suggestion.toJson)."""
    s = {"part": "base", "word": word, "action": action,
         "now": "shown now", "text": "shown as suggested" if base else ""}
    if was is not None:
        s["was"] = was
    if base is not None:
        s["base"] = base
    if why:
        s["why"] = why
    return s


def card(cid: str, *suggestions: dict) -> dict:
    return {"card": cid, "at": "2026-10-17T09:40:00.000Z",
            "suggestions": list(suggestions)}


def facts(s: dict) -> tuple[str, str, str]:
    found = rb.suggestion_facts(s)
    assert found is not None
    return found


class Proposals(unittest.TestCase):
    """A base's proposal written, and applied line by line."""

    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        shutil.copytree(TOOLS / "fixtures" / "b1" / "zz", self.root / "decks" / "zz")
        self.deck = self.root / "decks" / "zz" / "zz-en-phrases.yaml"
        self.deck.write_text(PHRASES, encoding="utf-8")
        self.core = self.root / "decks" / "zz" / "zz-home.yaml"
        self.layer = self.root / "decks" / "zz" / "en" / "zz-en-home.yaml"

    def text(self, path: Path | None = None) -> str:
        return (path or self.deck).read_text(encoding="utf-8")

    def proposal(self, s: dict, cid: str = "zz-9301", by: str = ALICE) -> pr.Proposal:
        return pr.Proposal(cid, *facts(s), by, "2026-10-17")

    def propose(self, p: pr.Proposal, deck: str = "zz-en-phrases") -> pr.Proposed:
        result = pr.Proposed()
        pr.propose(self.root, pr.Suggestion("zz", deck, p), result)
        return result

    def apply(self, p: pr.Proposal, deck: str = "zz-en-phrases") -> pr.Applied:
        result = self.propose(p, deck)
        self.assertEqual(len(result.added), 1, result)
        return pr.apply(self.root, "zz", result.added[0].id)

    def assert_valid(self, *paths: Path) -> None:
        for path in paths or (self.deck,):
            self.assertEqual(vd.validate(path).errors, [], path)


    def _an_agreed_change_closes_rivals_on_its_base_only(self) -> None:
        mine = self.proposal(base_suggestion(
            "zz-9301", "edit", "అమ్మ", was=MUM, base={**MUM, "meaning": "mother"}))
        rival = self.proposal(base_suggestion(
            "zz-9301", "edit", "అమ్మ", was=MUM, base={**MUM, "meaning": "mama"}), by=BOB)
        other = self.proposal(base_suggestion(
            "zz-9301", "add", "పాలు", base={"ref": "zz-9302"}), by=BOB)
        ids = [self.propose(p).added[0].id for p in (mine, rival, other)]
        applied = pr.apply(self.root, "zz", ids[0])
        self.assertEqual([o.id for o in applied.closed], [ids[1]])
        left = [p.id for e in pr.entries(self.root, "zz", "zz-9301") for p in e.proposals()]
        self.assertEqual(left, [ids[2]])


    # A core and its layer: the base's form in the core, its meaning in the layer.

    def split(self) -> None:
        core = self.text(self.core).replace(
            '      - { word: "ఇంటికి", ref: "zz-9001" }\n',
            '      - { word: "ఇంటికి", ref: "zz-9001" }\n'
            '      - { word: "నేను", base: "నేను", reading: "nēnu" }\n')
        self.core.write_text(core, encoding="utf-8")
        layer = self.text(self.layer).replace(
            '    native: "I will go home."\n',
            '    native: "I will go home."\n    bases:\n      "నేను": "I"\n')
        self.layer.write_text(layer, encoding="utf-8")
        self.assert_valid(self.core, self.layer)

    I = {"base": "నేను", "reading": "nēnu", "meaning": "I"}


    def marked(self) -> None:
        """The split deck, its layer's meaning written with a Wiktionary mark."""
        self.split()
        layer = self.text(self.layer).replace(
            '"నేను": "I"', '"నేను": { meaning: "I", wiktionary: true }')
        self.layer.write_text(layer, encoding="utf-8")
        self.assert_valid(self.core, self.layer)


    def test_an_agreed_change_closes_rivals_on_its_base_only(self) -> None:
        cases = (
            self._an_agreed_change_closes_rivals_on_its_base_only,
        )
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()


class Bot(BotBase):
    """Through the review bot, from the review file to the deck."""

    def setUp(self) -> None:
        super().setUp()
        (self.git.main / "decks" / "zz" / "zz-en-phrases.yaml").write_text(
            PHRASES.replace('  - id: "zz-9302"\n    target: "పాలు"\n    reading: "pālu"\n'
                            '    native: "milk"\n', ""), encoding="utf-8")

    def phrases(self) -> str:
        return self.main_text("decks/zz/zz-en-phrases.yaml")

    def send(self, key: str, code: str, *cards: dict) -> str:
        files = [review_file(list(cards), code=code, deck="zz-en-phrases")]
        return self.bot.review(key, code, rb.read_review(files, code))

    def accept(self, key: str, code: str, cid: str, *ps: pr.Proposal) -> str:
        found = {p.id: p for e in pr.entries(self.git.main, "zz", cid) for p in e.proposals()}
        return self.send(key, code, {
            "card": cid, "at": "2026-10-17T10:00:00.000Z",
            "proposals": [{"id": p.id, "answer": "accept", "field": p.field,
                           "text": found[p.id].text} for p in ps]})

    def on_main(self, cid: str = "zz-9301") -> list[pr.Proposal]:
        return [p for e in pr.entries(self.git.main, "zz", cid) for p in e.proposals()]

    def _change_add_and_remove_round_trip(self) -> None:
        self.assertEqual(self.send("m1", ALICE, card(
            "zz-9301",
            base_suggestion("zz-9301", "edit", "అమ్మ", was=MUM,
                            base={**MUM, "meaning": "mother"}, why="Informal"),
            base_suggestion("zz-9301", "add", "పాలు", base={
                "base": "పాలు", "reading": "pālu", "meaning": "milk"}),
        )), "merged")
        made = self.on_main()
        self.assertEqual([p.field for p in made], ["bases", "bases"])
        # The added base is the word of zz-9201: it becomes a ref.
        self.assertEqual(json.loads(made[1].text), {"word": "పాలు", "ref": "zz-9201"})
        self.assertIn("`zz-9301` bases", self.github.prs[0]["body"])
        self.assertEqual(self.accept("m2", BOB, "zz-9301", *made), "merged")
        self.bot.sweep()
        self.bot.sweep()
        text = self.phrases()
        self.assertIn('      - { word: "అమ్మ", base: "అమ్మ", reading: "amma", '
                      'meaning: "mother" }\n      - { word: "పాలు", ref: "zz-9201" }\n', text)
        self.assertNotIn("proposed", text)

        self.assertEqual(self.send("m3", ALICE, card("zz-9301", base_suggestion(
            "zz-9301", "remove", "పాలు", was={"ref": "zz-9201"}, why="Taught"))), "merged")
        self.assertEqual(self.accept("m4", BOB, "zz-9301", *self.on_main()), "merged")
        self.bot.sweep()
        self.assertNotIn("పాలు\", ref", self.phrases())
        self.assertIn('meaning: "mother" }\n', self.phrases())


    def word_change(self) -> dict:
        """A Word change on zz-9301 as the sheet sends it: the word, the old
        word kept as also heard, the old base removed and a new one added."""
        return card(
            "zz-9301",
            {"part": "word", "now": "అమ్మ పాలు", "text": "ఆవు పాలు",
             "why": "More common"},
            {"part": "alt", "now": "", "text": "అమ్మ పాలు"},
            base_suggestion("zz-9301", "remove", "అమ్మ", was=MUM, why="Not in it now"),
            base_suggestion("zz-9301", "add", "ఆవు", base={
                "base": "ఆవు", "reading": "āvu", "meaning": "cow"}),
        )


    def test_a_base_added_changed_and_removed_round_trips(self) -> None:
        cases = (
            self._change_add_and_remove_round_trip,
        )
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()


if __name__ == "__main__":
    unittest.main()
