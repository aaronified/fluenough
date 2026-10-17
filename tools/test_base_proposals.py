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

    def test_a_change_rewrites_its_one_line(self) -> None:
        before = self.text()
        s = base_suggestion("zz-9301", "edit", "అమ్మ", was=MUM,
                            base={**MUM, "meaning": "mother"}, why="Mum is informal")
        p = self.proposal(s)
        result = self.propose(p)
        written = result.added[0]
        # Its now and text are the base, one line of JSON each.
        self.assertEqual(json.loads(written.now), MUM)
        self.assertEqual(json.loads(written.text)["meaning"], "mother")
        self.assertIn("proposed:", self.text())
        self.assert_valid()
        self.assertEqual(pr.apply(self.root, "zz", written.id).outcome, "applied")
        after = self.text()
        self.assertEqual(after, before.replace('meaning: "mum"', 'meaning: "mother"'))

    def test_an_added_base_whose_form_is_a_card_becomes_a_ref(self) -> None:
        s = base_suggestion("zz-9301", "add", "పాలు",
                            base={"base": "పాలు", "reading": "pālu", "meaning": "milk"})
        applied = self.apply(self.proposal(s))
        self.assertEqual(applied.outcome, "applied")
        self.assertEqual(json.loads(applied.proposal.text),
                         {"word": "పాలు", "ref": "zz-9302"})
        self.assertIn('      - { word: "పాలు", ref: "zz-9302" }\n', self.text())
        self.assert_valid()

    def test_unlinked_by_the_reviewer_it_is_written_in_full(self) -> None:
        s = base_suggestion("zz-9301", "add", "పాలు", base={
            "base": "పాలు", "reading": "pālu", "meaning": "milk", "link": False})
        self.assertEqual(self.apply(self.proposal(s)).outcome, "applied")
        self.assertIn('      - { word: "పాలు", base: "పాలు", reading: "pālu", '
                      'meaning: "milk" }\n', self.text())
        self.assert_valid()

    def test_a_ref_the_app_gives_is_kept_and_one_to_no_card_refused(self) -> None:
        good = base_suggestion("zz-9301", "add", "పాలు", base={"ref": "zz-9302"})
        self.assertEqual(json.loads(self.proposal(good).text),
                         {"word": "పాలు", "ref": "zz-9302"})
        bad = base_suggestion("zz-9301", "add", "పాలు", base={"ref": "zz-9999"})
        self.assertEqual(len(self.propose(self.proposal(bad)).unsupported), 1)
        itself = base_suggestion("zz-9301", "add", "పాలు", base={"ref": "zz-9301"})
        self.assertEqual(len(self.propose(self.proposal(itself)).unsupported), 1)

    def test_removing_the_last_base_removes_bases(self) -> None:
        s = base_suggestion("zz-9301", "remove", "అమ్మ", was=MUM, why="Wrong")
        self.assertEqual(self.apply(self.proposal(s)).outcome, "applied")
        self.assertNotIn("bases", self.text())
        self.assertNotIn("proposed", self.text())
        self.assert_valid()

    def test_a_base_changed_since_is_outdated(self) -> None:
        s = base_suggestion("zz-9301", "edit", "అమ్మ", was={**MUM, "meaning": "mama"},
                            base={**MUM, "meaning": "mother"})
        self.assertEqual(len(self.propose(self.proposal(s)).outdated), 1)

    def test_an_agreed_change_closes_rivals_on_its_base_only(self) -> None:
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

    def test_also_heard_is_one_line_list(self) -> None:
        s = {"part": "alt", "now": "", "text": "అమ్మ పాలు!\n"}
        p = self.proposal(s)
        self.assertEqual((p.field, p.now, p.text), (pr.ALT, "[]", '["అమ్మ పాలు!"]'))
        self.assertEqual(self.apply(p).outcome, "applied")
        self.assertIn('    reading: "amma pālu"\n    alt_target: ["అమ్మ పాలు!"]\n'
                      '    native: "mother\'s milk"\n', self.text())
        self.assert_valid()

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

    def test_in_a_split_deck_the_core_and_the_layer_each_change_a_line(self) -> None:
        self.split()
        core, layer = self.text(self.core), self.text(self.layer)
        s = base_suggestion("zz-9002", "edit", "నేను", was=self.I,
                            base={**self.I, "reading": "nenu", "meaning": "I, me"})
        p = self.proposal(s, cid="zz-9002")
        result = self.propose(p, deck="zz-en-home")
        # The proposal is kept in the layer, which holds the meaning.
        self.assertIn("proposed:", self.text(self.layer))
        self.assertEqual(pr.apply(self.root, "zz", result.added[0].id).outcome, "applied")
        self.assertEqual(self.text(self.core), core.replace(
            'base: "నేను", reading: "nēnu"', 'base: "నేను", reading: "nenu"'))
        self.assertEqual(self.text(self.layer), layer.replace('"నేను": "I"', '"నేను": "I, me"'))
        self.assert_valid(self.core, self.layer)

    def marked(self) -> None:
        """The split deck, its layer's meaning written with a Wiktionary mark."""
        self.split()
        layer = self.text(self.layer).replace(
            '"నేను": "I"', '"నేను": { meaning: "I", wiktionary: true }')
        self.layer.write_text(layer, encoding="utf-8")
        self.assert_valid(self.core, self.layer)

    def test_a_meaning_change_keeps_the_wiktionary_mark(self) -> None:
        self.marked()
        s = base_suggestion("zz-9002", "edit", "నేను", was=self.I,
                            base={**self.I, "meaning": "I, me"})
        self.assertEqual(self.apply(self.proposal(s, cid="zz-9002"), "zz-en-home").outcome,
                         "applied")
        self.assertIn('      "నేను": { meaning: "I, me", wiktionary: true }\n',
                      self.text(self.layer))
        self.assert_valid(self.core, self.layer)

    def test_a_new_form_or_reading_drops_the_wiktionary_mark(self) -> None:
        self.marked()
        s = base_suggestion("zz-9002", "edit", "నేను", was=self.I,
                            base={**self.I, "reading": "nenu"})
        self.assertEqual(self.apply(self.proposal(s, cid="zz-9002"), "zz-en-home").outcome,
                         "applied")
        self.assertIn('      "నేను": { meaning: "I" }\n', self.text(self.layer))
        self.assert_valid(self.core, self.layer)

    def test_an_old_mail_with_no_meaning_is_left_for_the_owner(self) -> None:
        before = self.text()
        for blank in ("", "   "):
            p = pr.Proposal("zz-9301", *facts({"part": "base", "word": "అమ్మ",
                                               "now": "mum", "text": blank}),
                            ALICE, "2026-10-17")
            self.assertEqual(len(self.propose(p).unsupported), 1)
        self.assertEqual(self.text(), before)

    def test_removed_in_a_split_deck_every_layer_loses_its_meaning(self) -> None:
        self.split()
        other = self.root / "decks" / "zz" / "xx" / "zz-xx-home.yaml"
        other.parent.mkdir()
        other.write_text(self.text(self.layer).replace('id: "zz-en-home"', 'id: "zz-xx-home"'),
                         encoding="utf-8")
        s = base_suggestion("zz-9002", "remove", "నేను", was=self.I)
        self.assertEqual(self.apply(self.proposal(s, cid="zz-9002"), "zz-en-home").outcome,
                         "applied")
        for path in (self.core, self.layer, other):
            self.assertNotIn("నేను\"", self.text(path).split('"zz-9002"')[1].split("zz-91")[0],
                             path)
        self.assertIn('      - { word: "వెళ్తాను", ref: "zz-9003" }\n  #', self.text(self.core))
        self.assert_valid(self.core, self.layer)

    def test_added_by_ref_in_a_split_deck_needs_no_meaning(self) -> None:
        s = base_suggestion("zz-9002", "add", "నేను", base={"ref": "zz-9006"})
        layer = self.text(self.layer)
        self.assertEqual(self.apply(self.proposal(s, cid="zz-9002"), "zz-en-home").outcome,
                         "applied")
        self.assertIn('      - { word: "నేను", ref: "zz-9006" }\n', self.text(self.core))
        self.assertEqual(self.text(self.layer), layer)
        self.assert_valid(self.core, self.layer)

    def test_the_validator_reads_the_new_kinds_and_refuses_bad_json(self) -> None:
        p = self.proposal(base_suggestion("zz-9301", "remove", "అమ్మ", was=MUM))
        self.propose(p)
        self.assert_valid()
        bad = self.text().replace('text: ""', 'text: "not json"')
        self.deck.write_text(bad, encoding="utf-8")
        errors = vd.validate(self.deck).errors
        self.assertTrue(any("one line of JSON" in e for e in errors), errors)


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

    def test_change_add_and_remove_round_trip(self) -> None:
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

    def test_an_old_mail_on_a_bases_meaning_still_reads_and_applies(self) -> None:
        old = {"card": "zz-9301", "at": "2026-10-09T09:40:00.000Z",
               "suggestion": {"part": "base", "word": "అమ్మ", "now": "mum",
                              "text": "mother", "why": "Informal"}}
        self.assertEqual(self.send("m1", ALICE, old), "merged")
        made = self.on_main()
        self.assertEqual(json.loads(made[0].now), MUM)
        self.assertEqual(json.loads(made[0].text), {**MUM, "meaning": "mother"})
        self.accept("m2", BOB, "zz-9301", *made)
        self.bot.sweep()
        self.assertIn('meaning: "mother" }', self.phrases())

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

    def test_a_word_change_and_what_it_brought_apply_as_one_pr(self) -> None:
        self.assertEqual(self.send("m1", ALICE, self.word_change()), "merged")
        made = self.on_main()
        word = next(p for p in made if p.field == "target")
        self.assertEqual(sorted(p.field for p in made if p.tied == word.id),
                         ["alt_target", "bases", "bases"])
        self.assertIn(f'with: "{word.id}"', self.phrases())
        self.assertEqual(vd.validate(self.git.main / "decks/zz/zz-en-phrases.yaml").errors, [])

        # Accepted on their own, the tied ones still wait for the word.
        tied = [p for p in made if p.tied]
        self.accept("m2", BOB, "zz-9301", *tied)
        self.bot.sweep()
        self.assertIn('target: "అమ్మ పాలు"', self.phrases())
        self.assertEqual([pr_["head"]["ref"] for pr_ in self.github.prs
                          if "apply" in pr_["head"]["ref"]], [])

        # The word agreed: one PR applies it and all it brought.
        self.accept("m3", BOB, "zz-9301", word)
        self.wiki = None
        self.assertEqual(self.bot.sweep()["applied"], 1)
        applies = [p for p in self.github.prs if "apply" in p["head"]["ref"]]
        self.assertEqual(len(applies), 1)
        text = self.phrases()
        self.assertIn('    target: "ఆవు పాలు"\n', text)
        self.assertIn('    alt_target: ["అమ్మ పాలు"]\n', text)
        self.assertIn('      - { word: "ఆవు", base: "ఆవు", reading: "āvu", '
                      'meaning: "cow" }\n', text)
        self.assertNotIn('word: "అమ్మ"', text)
        self.assertNotIn("proposed", text)
        # The reading follows the word, as none was proposed.
        self.assertIn('    reading: "āvu pālu"\n', text)
        body = applies[0]["body"]
        self.assertEqual(body.count("Applied with it, from the same review"), 3)
        self.assertEqual(vd.validate(self.git.main / "decks/zz/zz-en-phrases.yaml").errors, [])

    def test_a_reading_proposed_with_the_word_goes_in_and_is_not_worked_out(self) -> None:
        sent = self.word_change()
        sent["suggestions"].append({"part": "reading", "now": "amma pālu",
                                    "text": "āvu paalu"})
        self.send("m1", ALICE, sent)
        word = next(p for p in self.on_main() if p.field == "target")
        self.accept("m2", BOB, "zz-9301", word)
        self.bot.sweep()
        self.assertIn('    reading: "āvu paalu"\n', self.phrases())

    def test_a_word_whose_tied_base_no_longer_applies_waits_whole(self) -> None:
        self.send("m1", ALICE, self.word_change())
        word = next(p for p in self.on_main() if p.field == "target")
        self.accept("m2", BOB, "zz-9301", word)
        # The owner changes the old base on main: its removal is outdated.
        path = self.git.main / "decks/zz/zz-en-phrases.yaml"
        path.write_text(self.phrases().replace('meaning: "mum"', 'meaning: "mama"'),
                        encoding="utf-8")
        self.wiki = None
        self.assertEqual(self.bot.sweep()["applied"], 0)
        self.assertEqual([p for p in self.github.prs if "apply" in p["head"]["ref"]], [])
        text = self.phrases()
        self.assertIn('target: "అమ్మ పాలు"', text)
        self.assertNotIn("    alt_target: [", text)
        # Nothing it brought is closed: the word waits with it, logged.
        self.assertEqual(len(self.on_main()), 4)
        self.assertTrue(any("waits" in line and word.id in line for line in self.logged),
                        self.logged)

    def test_tied_proposals_whose_word_is_gone_are_closed(self) -> None:
        self.send("m1", ALICE, self.word_change())
        word = next(p for p in self.on_main() if p.field == "target")
        pr.close(self.git.main, "zz", [word.id])
        self.assertEqual(len(pr.outdated(self.git.main, "zz")), 3)
        self.bot.sweep()
        self.assertEqual(self.on_main(), [])
        self.assertIn('target: "అమ్మ పాలు"', self.phrases())


class Mail(unittest.TestCase):
    def test_the_issue_counts_base_changes_by_kind_without_text(self) -> None:
        files = [review_file([
            card("zz-9301",
                 base_suggestion("zz-9301", "add", "పాలు", base={"ref": "zz-9201"}),
                 base_suggestion("zz-9301", "remove", "అమ్మ", was=MUM, why="SECRET")),
            {"card": "zz-9302", "at": "2026-10-09T09:40:00.000Z",
             "suggestion": {"part": "base", "word": "w", "now": "x", "text": "y"}},
        ])]
        self.assertEqual(mail_to_issues.base_counts(files), (1, 1, 1))
        self.assertEqual(mail_to_issues.review_counts(files)[0], 3)


if __name__ == "__main__":
    unittest.main()
