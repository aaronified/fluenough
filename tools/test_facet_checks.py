#!/usr/bin/env python3
"""Facet-level checks (ADR-0058, W9): the `facet_checks` line the bot writes
on a card's entry, the facet-level rule that tags a deck file `reviewed`, the
content hash that leaves the line out, the validator's check of it, and the
bot reading a review mail's `facets` and `receipts`.

Stdlib `unittest` plus PyYAML. Every test works on a copy of
tools/fixtures/b1/zz, a made-up language, in a temporary directory, and never
on decks/.
"""

from __future__ import annotations

import hashlib
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import deck_index  # noqa: E402
import proposals as pr  # noqa: E402
import review_bot as rb  # noqa: E402
import review_facets as rf  # noqa: E402
import validate_decks as vd  # noqa: E402
from test_checked_by import Base, content  # noqa: E402
from test_proposals import ALICE, BOB, code  # noqa: E402
from test_review_bot import Base as BotBase, SECRET, review_file  # noqa: E402

CAROL = code("K3M7Q9TD")
FLOW = '  - { id: "zz-9210", target: "పిల్లి", reading: "pilli", native: "cat" }\n'


def errors(path: Path) -> list[str]:
    return [str(e) for e in vd.validate(path).errors]


class Writing(Base):
    def setUp(self) -> None:
        super().setUp()
        self.single.write_text(self.single.read_text(encoding="utf-8") + FLOW,
                               encoding="utf-8")

    def entry(self, card: str, path: Path | None = None) -> pr.Entry:
        path = path or self.single
        return next(e for e in pr.entries(self.root, "zz", card) if e.path == path)

    def facets(self, card: str, answers: dict, who: str = ALICE,
               deck: str = "zz-en-extra", **kw) -> pr.Checks:
        result = pr.Checks()
        pr.check_facets(self.root, "zz", deck, card, who, answers, result,
                        write=kw.pop("write", True), **kw)
        return result

    def test_a_block_card_gets_one_line(self) -> None:
        result = self.facets("zz-9201", {"reading": rf.Answer(ALICE)})
        self.assertEqual(result.facets, [("zz-9201", "reading")])
        lines = self.single.read_text(encoding="utf-8").splitlines()
        self.assertIn(f'    facet_checks: {{"reading": {{"by": ["{ALICE}"]}}}}', lines)
        self.assertEqual(pr.facet_data(self.entry("zz-9201")),
                         {"reading": {"by": [ALICE], "flags": []}})
        self.assertEqual(errors(self.single), [])

    def test_a_rater_has_one_answer_to_a_facet(self) -> None:
        self.facets("zz-9201", {"reading": rf.Answer(ALICE)})
        self.facets("zz-9201", {"reading": rf.Answer(BOB, ("reading_wrong",), " kaala ")}, BOB)
        held = pr.facet_data(self.entry("zz-9201"))["reading"]
        self.assertEqual(held["by"], [ALICE])
        self.assertEqual(held["flags"],
                         [{"by": BOB, "tags": ["reading_wrong"], "fix": "kaala"}])
        # BOB changes their mind: from the flags to the codes, never both.
        self.facets("zz-9201", {"reading": rf.Answer(BOB)}, BOB)
        held = pr.facet_data(self.entry("zz-9201"))["reading"]
        self.assertEqual((held["by"], held["flags"]), ([ALICE, BOB], []))
        self.facets("zz-9201", {"reading": rf.Answer(ALICE, ("reading_wrong",))})
        held = pr.facet_data(self.entry("zz-9201"))["reading"]
        self.assertEqual(held["by"], [BOB])
        self.assertEqual([f["by"] for f in held["flags"]], [ALICE])
        self.assertEqual(self.single.read_text(encoding="utf-8").count("facet_checks"), 1)
        self.assertEqual(errors(self.single), [])

    def test_an_answer_goes_on_the_entry_that_owns_the_facet(self) -> None:
        # The word and the reading are the core's, the meaning the layer's.
        self.facets("zz-9001", {"word": rf.Answer(ALICE), "meaning": rf.Answer(ALICE)},
                    deck="zz-en-home")
        self.assertEqual(list(pr.facet_data(self.entry("zz-9001", self.core))), ["word"])
        self.assertEqual(list(pr.facet_data(self.entry("zz-9001", self.layer))), ["meaning"])
        for path in (self.core, self.layer):
            self.assertEqual(errors(path), [], path.name)

    def test_nothing_is_written_while_the_key_is_off(self) -> None:
        before = self.single.read_text(encoding="utf-8")
        result = self.facets("zz-9201", {"reading": rf.Answer(ALICE, ("reading_wrong",)),
                                         "word": rf.Answer(ALICE)}, write=False)
        self.assertEqual(self.single.read_text(encoding="utf-8"), before)
        self.assertEqual(sorted(result.facets_left),
                         [("zz-9201", "reading"), ("zz-9201", "word")])

    def test_a_flow_card_takes_it_last_and_with_checked_by(self) -> None:
        self.facets("zz-9210", {"reading": rf.Answer(ALICE)})
        text = self.single.read_text(encoding="utf-8")
        self.assertIn(f'native: "cat", facet_checks: {{"reading": {{"by": ["{ALICE}"]}}}} }}', text)
        # checked_by after it, in either order, and each rewrites its own.
        self.check("zz-9210")
        self.assertEqual(pr.checked_by(self.entry("zz-9210")), [ALICE])
        fix = 'a}, b: [c] "d \\ e'
        self.facets("zz-9210", {"reading": rf.Answer(BOB, ("reading_wrong",), fix)}, BOB)
        entry = self.entry("zz-9210")
        self.assertEqual(pr.checked_by(entry), [ALICE])
        self.assertEqual(pr.facet_data(entry)["reading"]["flags"][0]["fix"], fix)
        self.assertEqual(pr.facet_data(entry)["reading"]["by"], [ALICE])
        line = next(l for l in self.single.read_text(encoding="utf-8").splitlines()
                    if "zz-9210" in l)
        self.assertEqual(line.count("facet_checks"), 1)
        self.assertEqual(line.count("checked_by"), 1)
        self.assertEqual(errors(self.single), [])

    def test_a_sign_off_replaces_the_flags_of_that_rater(self) -> None:
        self.facets("zz-9201", {"reading": rf.Answer(ALICE, ("reading_wrong",))})
        self.facets("zz-9210", {"reading": rf.Answer(ALICE, ("reading_wrong",))})
        for card in ("zz-9201", "zz-9210"):
            self.check(card)
            entry = self.entry(card)
            held = pr.facet_data(entry)
            # Right on every facet the entry owns, no flag left, and the
            # mirror in checked_by says the card is signed off.
            self.assertEqual(sorted(held), sorted(pr.owned_facets(entry)), card)
            for facet in held.values():
                self.assertEqual((facet["by"], facet["flags"]), ([ALICE], []), card)
            self.assertEqual(pr.checked_by(entry), [ALICE], card)
        self.assertEqual(errors(self.single), [])

    def test_a_flag_after_a_sign_off_takes_the_code_out_of_checked_by(self) -> None:
        # One source of truth: once an entry carries facet_checks they say
        # who is right on what; checked_by only mirrors the full sign-offs.
        self.check("zz-9201")
        self.check("zz-9201", code=BOB)
        self.assertEqual(pr.checked_by(self.entry("zz-9201")), [ALICE, BOB])
        self.facets("zz-9201", {"reading": rf.Answer(BOB, ("reading_wrong",))}, BOB)
        entry = self.entry("zz-9201")
        self.assertEqual(pr.checked_by(entry), [ALICE])
        # The legacy sign-off of BOB was written out first: right on the
        # other facets, flagged on the reading.
        held = pr.facet_data(entry)
        self.assertEqual(held["word"]["by"], [ALICE, BOB])
        self.assertEqual(held["reading"]["by"], [ALICE])
        self.assertEqual([f["by"] for f in held["reading"]["flags"]], [BOB])
        # The status reads facet_checks alone, not checked_by on top.
        self.assertEqual(rf.facet_status(pr.entry_checks(entry, "reading")), "contested")
        self.assertEqual(rf.facet_status(pr.entry_checks(entry, "word")), "settled")
        # Nobody left in checked_by: the line goes.
        self.facets("zz-9201", {"reading": rf.Answer(ALICE, ("reading_wrong",))})
        self.assertEqual(pr.checked_by(self.entry("zz-9201")), [])
        self.assertNotIn("checked_by", self.single.read_text(encoding="utf-8"))
        self.assertEqual(errors(self.single), [])

    def test_a_fix_on_a_facet_that_is_not_text_is_not_kept(self) -> None:
        pointed = rf.read_answer("unit", ALICE, {"tags": ["wrong_unit"], "fix": "zz-home"})
        self.assertEqual(pointed, rf.Answer(ALICE, ("wrong_unit",), ""))
        self.facets("zz-9201", {"unit": pointed})
        held = pr.facet_data(self.entry("zz-9201"))["unit"]
        self.assertNotIn('"fix"', self.single.read_text(encoding="utf-8").split("facet_checks")[1])
        self.assertEqual(held["flags"][0]["fix"], "")
        self.assertEqual(errors(self.single), [])

    def test_a_fix_applied_clears_the_facet_for_sign_offs_too(self) -> None:
        # Two legacy sign-offs, then the meaning is changed by an agreed fix:
        # the sign-offs do not bring back rights to the old text.
        self.check("zz-9201")
        self.check("zz-9201", code=BOB)
        original = pr.WRITE_FACET_CHECKS
        self.addCleanup(setattr, pr, "WRITE_FACET_CHECKS", original)
        pr.WRITE_FACET_CHECKS = True
        pr.reset_facet(self.root, "zz", "zz-9201", "native")
        entry = self.entry("zz-9201")
        held = pr.facet_data(entry)
        self.assertNotIn("meaning", held)
        self.assertEqual(held["word"]["by"], [ALICE, BOB])
        self.assertEqual(rf.facet_status(pr.entry_checks(entry, "meaning")), "unchecked")
        self.assertEqual(pr.checked_by(entry), [])
        self.assertEqual(errors(self.single), [])

    def test_a_fix_applied_with_the_key_off_drops_legacy_sign_offs(self) -> None:
        self.check("zz-9201")
        self.assertFalse(pr.WRITE_FACET_CHECKS)
        pr.reset_facet(self.root, "zz", "zz-9201", "native")
        self.assertEqual(pr.checked_by(self.entry("zz-9201")), [])
        self.assertEqual(pr.facet_data(self.entry("zz-9201")), {})

    def test_right_on_every_facet_signs_the_card_off(self) -> None:
        owned = pr.owned_facets(self.entry("zz-9201"))
        self.assertEqual(owned, ["word", "reading", "meaning", "note", "unit"])
        partly = {f: rf.Answer(ALICE) for f in owned[:-1]}
        self.facets("zz-9201", partly)
        self.assertEqual(pr.checked_by(self.entry("zz-9201")), [])
        self.facets("zz-9201", {f: rf.Answer(ALICE) for f in owned})
        self.assertEqual(pr.checked_by(self.entry("zz-9201")), [ALICE])
        # A card-level "Looks right" with it covers the facets it does not
        # name, but never one flagged.
        self.facets("zz-9210", {"reading": rf.Answer(BOB, ("reading_wrong",))}, BOB,
                    right_all=True)
        self.assertEqual(pr.checked_by(self.entry("zz-9210")), [])
        self.facets("zz-9210", {"reading": rf.Answer(BOB)}, BOB, right_all=True)
        self.assertEqual(pr.checked_by(self.entry("zz-9210")), [BOB])

    def test_the_content_hash_leaves_it_out(self) -> None:
        paths = (self.core, self.layer, self.single)
        before = {p: content(p) for p in paths}
        sha = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
        for who, flag in ((ALICE, False), (BOB, True)):
            answer = rf.Answer(who, ("reading_wrong",), "x}, \"y\"") if flag else rf.Answer(who)
            self.facets("zz-9201", {"reading": answer}, who)
            self.facets("zz-9210", {"reading": answer}, who)
            self.facets("zz-9001", {"reading": answer, "meaning": rf.Answer(who)}, who,
                        deck="zz-en-home")
            self.check("zz-9201", code=who)
            self.check("zz-9001", "zz-en-home", who)
        for path in paths:
            self.assertEqual(content(path), before[path], path.name)
            self.assertNotEqual(hashlib.sha256(path.read_bytes()).hexdigest(), sha[path],
                                path.name)
            self.assertIn("facet_checks", path.read_text(encoding="utf-8"))
        # Nothing of it is left in what a learner's phone compares.
        now = self.single.read_text(encoding="utf-8")
        self.assertEqual(deck_index.content_bytes(now.encode("utf-8")).decode("utf-8")
                         .count("facet_checks"), 0)

    def test_the_validator_accepts_the_line_and_refuses_what_is_not_one(self) -> None:
        self.facets("zz-9201", {"reading": rf.Answer(ALICE, ("reading_wrong",), "pālū")})
        self.assertEqual(errors(self.single), [])
        good = self.single.read_text(encoding="utf-8")

        def broken(old: str, new: str) -> list[str]:
            self.single.write_text(good.replace(old, new), encoding="utf-8")
            try:
                return errors(self.single)
            finally:
                self.single.write_text(good, encoding="utf-8")

        self.assertTrue(any("may not be put" in e for e in
                            broken('"reading_wrong"', '"ipa_wrong"')))
        self.assertTrue(any("not a facet" in e for e in broken('{"reading": {', '{"colour": {')))
        self.assertTrue(any("rater code" in e for e in broken(ALICE, "FL-NOPE")))
        self.assertTrue(any("only pointed at" in e for e in
                            broken('"reading": {"flags"', '"unit": {"flags"')
                            + broken('"reading_wrong"', '"wrong_unit"')))
        self.assertTrue(any("twice" in e for e in broken(
            '{"reading": {"flags": [{"by": "%s", "tags": ["reading_wrong"], "fix": "pālū"}]}}'
            % ALICE,
            '{"reading": {"by": ["%s"], "flags": [{"by": "%s", "tags": ["reading_wrong"]}]}}'
            % (ALICE, ALICE))))
        self.assertTrue(any("facet_checks" in e for e in broken(
            'facet_checks: {"reading"', 'facet_checks: [{"reading"')))


class Tagging(Base):
    def check_each(self, who: str) -> None:
        for card in self.core_cards():
            self.check(card, "zz-en-home", who)

    def settled(self, path: Path) -> bool:
        return pr.all_checked(path)

    def test_one_code_is_not_the_quorum_two_are(self) -> None:
        result = self.check_all("zz-en-home", self.core_cards(), ALICE)
        self.assertEqual(result.reviewed, [])
        self.assertIn('tags: ["unreviewed"]', self.core.read_text(encoding="utf-8"))
        result = self.check_all("zz-en-home", self.core_cards(), BOB)
        self.assertEqual(sorted(result.reviewed), ["zz-en-home", "zz-home"])
        self.assertIn('tags: ["reviewed"]\n', self.core.read_text(encoding="utf-8"))
        self.assertNotIn("unreviewed", self.core.read_text(encoding="utf-8"))

    def test_two_codes_on_all_but_one_card_stay_unreviewed(self) -> None:
        for who in (ALICE, BOB):
            result = self.check_all("zz-en-home", self.core_cards()[:-1], who)
        self.assertEqual(result.reviewed, [])
        self.assertFalse(self.settled(self.core))
        self.assertIn('tags: ["unreviewed"]', self.core.read_text(encoding="utf-8"))

    def test_a_flag_makes_a_facet_unsettled_whatever_the_sign_offs_say(self) -> None:
        self.check_each(ALICE)
        self.check_each(BOB)
        self.assertTrue(self.settled(self.core))
        # CAROL flags the reading of one card: contested, so the file is not
        # reviewed, though two codes signed the card off.
        result = pr.Checks()
        pr.check_facets(self.root, "zz", "zz-home", "zz-9001", CAROL,
                        {"reading": rf.Answer(CAROL, ("reading_wrong",))}, result, write=True)
        self.assertFalse(self.settled(self.core))
        # Others in the file are unaffected: the flag is on one facet.
        entry = next(e for e in pr.entries(self.root, "zz", "zz-9001") if e.path == self.core)
        self.assertFalse(pr.facets_settled(entry))
        other = next(e for e in pr.entries(self.root, "zz", "zz-9004") if e.path == self.core)
        self.assertTrue(pr.facets_settled(other))
        # CAROL then says it is right: settled again.
        pr.check_facets(self.root, "zz", "zz-home", "zz-9001", CAROL,
                        {"reading": rf.Answer(CAROL)}, result, write=True)
        self.assertTrue(self.settled(self.core))

    def test_a_rater_own_answer_wins_over_their_sign_off(self) -> None:
        self.check_each(ALICE)
        self.check_each(BOB)
        result = pr.Checks()
        pr.check_facets(self.root, "zz", "zz-home", "zz-9001", ALICE,
                        {"reading": rf.Answer(ALICE, ("reading_wrong",), "illū")}, result,
                        write=True)
        self.assertFalse(self.settled(self.core))
        # Marking the whole card "Looks right" again is their latest answer.
        pr.check(self.root, "zz", "zz-home", "zz-9001", ALICE, result)
        self.assertTrue(self.settled(self.core))

    def test_facet_answers_alone_settle_every_facet_or_not(self) -> None:
        result = pr.Checks()
        for who in (ALICE, BOB):
            for card in self.core_cards():
                entry = next(e for e in pr.entries(self.root, "zz", card)
                             if e.path == self.core)
                only_word = {"word": rf.Answer(who)}
                pr.check_facets(self.root, "zz", "zz-home", card, who, only_word, result,
                                write=True)
        # The word has its quorum on every card, nothing else does.
        self.assertFalse(self.settled(self.core))
        self.assertEqual(result.reviewed, [])
        for who in (ALICE, BOB):
            for card in self.core_cards():
                entry = next(e for e in pr.entries(self.root, "zz", card)
                             if e.path == self.core)
                every = {f: rf.Answer(who) for f in pr.owned_facets(entry)}
                pr.check_facets(self.root, "zz", "zz-home", card, who, every, result,
                                write=True)
        self.assertTrue(self.settled(self.core))
        pr.review_done(result)
        self.assertIn('tags: ["reviewed"]\n', self.core.read_text(encoding="utf-8"))
        self.assertEqual(errors(self.core), [])

    def test_an_entry_with_no_facet_asks_nothing(self) -> None:
        # An empty layer entry owns no facet.
        entry = pr.Entry(self.layer, "layer", "zz-0", {}, "zz-en-home", "zz-home")
        self.assertEqual(pr.owned_facets(entry), [])
        self.assertIsNone(pr.facets_settled(entry))


class BotFacets(BotBase):
    def write(self, on: bool = True) -> None:
        original = pr.WRITE_FACET_CHECKS
        pr.WRITE_FACET_CHECKS = on
        self.addCleanup(setattr, pr, "WRITE_FACET_CHECKS", original)

    def text(self, card: str, facet: str) -> str:
        return pr.facet_texts(self.git.main, "zz", "zz-en-extra", card, facet)[0]

    def card(self, facets: dict, receipts: dict | None = None, **kw) -> dict:
        made = {"card": "zz-9201", "at": "2026-10-09T09:40:00.000Z", "facets": facets}
        if receipts:
            made["receipts"] = [
                {"card": "zz-9201", "facet": facet, "hash": rf.hash_of_seen(seen),
                 "decision": "flagged"} for facet, seen in receipts.items()]
        made.update(kw)
        return made

    def mail(self, key: str, who: str, *cards: dict) -> str:
        review = rb.read_review([review_file(list(cards), code=who)], who)
        return self.bot.review(key, who, review)

    def main_entry(self, card: str = "zz-9201") -> pr.Entry:
        return next(e for e in pr.entries(self.git.main, "zz", card)
                    if e.path.name == "zz-en-extra.yaml")

    def test_an_old_mail_is_read_and_done_as_before(self) -> None:
        old = {"card": "zz-9201", "at": "2026-10-09T09:40:00.000Z", "looks_right": True}
        review = rb.read_review([review_file([old])], ALICE)
        self.assertEqual(review.checks, [("zz", "zz-en-extra", "zz-9201")])
        self.assertEqual(review.facet_cards, [])
        # Facet data that is not any is as if it were not there.
        for junk in ({}, {"word": 5}, {"colour": {"ok": True}}, [], "x",
                     {"reading": {"tags": ["ipa_wrong"]}}):
            with self.subTest(junk=junk):
                review = rb.read_review([review_file([{**old, "facets": junk}])], ALICE)
                self.assertEqual(review.checks, [("zz", "zz-en-extra", "zz-9201")])
                self.assertEqual(review.facet_cards, [])
        self.assertEqual(self.bot.review("old", ALICE, rb.read_review(
            [review_file([old])], ALICE)), "merged")
        self.assertIn(f'checked_by: ["{ALICE}"]', self.main_text())
        self.assertNotIn("facet_checks", self.main_text())

    def test_a_card_with_facets_is_read_as_facets(self) -> None:
        card = self.card({"reading": {"ok": True}, "meaning": {"tags": ["meaning_wrong"],
                                                              "fix": "cow's milk"}},
                         {"meaning": "milk"}, looks_right=True)
        review = rb.read_review([review_file([card])], ALICE)
        self.assertEqual(review.checks, [])
        face = review.facet_cards[0]
        self.assertEqual((face.lang, face.deck, face.card, face.date),
                         ("zz", "zz-en-extra", "zz-9201", "2026-10-09"))
        self.assertEqual(face.answers["reading"], rf.Answer(ALICE))
        self.assertEqual(face.answers["meaning"],
                         rf.Answer(ALICE, ("meaning_wrong",), "cow's milk"))
        self.assertEqual(face.receipts, {"meaning": rf.hash_of_seen("milk")})
        self.assertTrue(face.right_all)

    def test_right_on_every_facet_signs_off_while_the_key_is_off(self) -> None:
        self.assertFalse(pr.WRITE_FACET_CHECKS)
        every = {f: {"ok": True} for f in ("word", "reading", "meaning", "note", "unit")}
        self.assertEqual(self.mail("m1", ALICE, self.card(every)), "merged")
        self.assertEqual(pr.checked_by(self.main_entry()), [ALICE])
        self.assertNotIn("facet_checks", self.main_text())

    def test_a_flag_while_the_key_is_off_is_counted_not_written(self) -> None:
        card = self.card({"reading": {"tags": ["reading_wrong"]}, "word": {"ok": True}},
                         looks_right=True)
        self.assertEqual(self.mail("m1", ALICE, card), "nothing")
        self.assertNotIn("facet_checks", self.main_text())
        self.assertNotIn("checked_by", self.main_text())
        self.assertTrue(any("not written" in line for line in self.logged), self.logged)

    def test_answers_are_written_and_a_flag_unsettles_the_card(self) -> None:
        self.write()
        every = {f: {"ok": True} for f in ("word", "reading", "meaning", "note", "unit")}
        self.mail("m1", ALICE, self.card(every))
        self.mail("m2", BOB, self.card(every))
        self.assertTrue(pr.facets_settled(self.main_entry()))
        self.mail("m3", CAROL, self.card({"reading": {"tags": ["reading_wrong"]}}))
        entry = self.main_entry()
        self.assertEqual(pr.facet_data(entry)["reading"]["flags"][0]["by"], CAROL)
        self.assertFalse(pr.facets_settled(entry))
        body = next(p["body"] for p in self.github.prs if CAROL in p["title"])
        self.assertIn(f"Facet answers by {CAROL}: 1 on 1 card(s)", body)

    def test_a_fix_is_a_proposal_and_never_applied_alone(self) -> None:
        self.write()
        fix = f"{SECRET} milk"
        card = self.card({"meaning": {"tags": ["meaning_wrong"], "fix": fix}},
                         {"meaning": self.text("zz-9201", "meaning")})
        self.assertEqual(self.mail("m1", ALICE, card), "merged")
        found = pr.all_proposals(self.git.main, "zz")
        self.assertEqual([(p.card, p.field, p.now, p.text, p.by) for _, p in found],
                         [("zz-9201", "native", "milk", fix, ALICE)])
        for body in (p["body"] for p in self.github.prs):
            self.assertNotIn(SECRET, body)
        self.assertEqual(self.bot.sweep()["applied"], 0)
        self.assertIn('native: "milk"', self.main_text())

    def test_the_same_fix_after_normalisation_is_the_agreement(self) -> None:
        self.write()
        first = self.card({"meaning": {"tags": ["meaning_wrong"], "fix": "café milk"}},
                          {"meaning": "milk"})
        second = self.card({"meaning": {"tags": ["meaning_wrong"],
                                        "fix": " café  milk "}},
                           {"meaning": "milk"})
        self.mail("m1", ALICE, first)
        self.mail("m2", BOB, second)
        (_, proposal), = pr.all_proposals(self.git.main, "zz")
        self.assertEqual(proposal.accepted, (BOB,))
        self.assertEqual(proposal.text, "café milk")
        entry = self.main_entry()
        self.assertEqual(rf.facet_status(pr.entry_checks(entry, "meaning")), "agreed_fix")
        self.assertEqual(self.bot.sweep()["applied"], 1)
        self.assertIn('native: "café milk"', self.main_text())
        # The answers were to the old text: that facet is asked afresh. The
        # others stay.
        self.assertNotIn("meaning", pr.facet_data(self.main_entry()))
        self.assertEqual(errors(self.git.main / "decks/zz/zz-en-extra.yaml"), [])

    def test_a_contested_facet_is_not_applied(self) -> None:
        self.write()
        flag = {"meaning": {"tags": ["meaning_wrong"], "fix": "café milk"}}
        self.mail("m1", ALICE, self.card(flag, {"meaning": "milk"}))
        self.mail("m2", BOB, self.card({"meaning": {"ok": True}}, {"meaning": "milk"}))
        self.mail("m3", CAROL, self.card(flag, {"meaning": "milk"}))
        (_, proposal), = pr.all_proposals(self.git.main, "zz")
        # The agreement is there, and the facet is contested: one says right.
        self.assertEqual(proposal.accepted, (CAROL,))
        self.assertEqual(rf.facet_status(pr.entry_checks(self.main_entry(), "meaning")),
                         "contested")
        counts = self.bot.sweep()
        self.assertEqual(counts["applied"], 0)
        self.assertIn('native: "milk"', self.main_text())
        self.assertEqual([p for p in self.github.prs
                          if p["head"]["ref"].startswith("review-bot/apply/")], [])
        # BOB changes their mind to the fix: nothing contests it any more.
        self.mail("m4", BOB, self.card(flag, {"meaning": "milk"}))
        self.assertEqual(self.bot.sweep()["applied"], 1)
        self.assertIn('native: "café milk"', self.main_text())

    def test_an_answer_to_text_that_has_changed_is_left_out(self) -> None:
        self.write()
        card = self.card({"meaning": {"tags": ["meaning_wrong"], "fix": "x"}},
                         {"meaning": "something it said before"})
        self.assertEqual(self.mail("m1", ALICE, card), "nothing")
        self.assertEqual(pr.all_proposals(self.git.main, "zz"), [])
        self.assertNotIn("facet_checks", self.main_text())
        self.assertTrue(any("1 stale" in line for line in self.logged), self.logged)
        # A looks-right sent with a stale answer does not sign the card off.
        card = self.card({"meaning": {"ok": True}}, {"meaning": "something else"},
                         looks_right=True)
        self.assertEqual(self.mail("m2", ALICE, card), "nothing")
        self.assertNotIn("checked_by", self.main_text())

    def test_a_card_level_looks_right_replaces_that_raters_flags(self) -> None:
        self.write()
        self.mail("m1", ALICE, self.card({"reading": {"tags": ["reading_wrong"]}}))
        self.assertIn("facet_checks", self.main_text())
        old = {"card": "zz-9201", "at": "2026-10-09T09:41:00.000Z", "looks_right": True}
        self.assertEqual(self.bot.review("m2", ALICE, rb.read_review(
            [review_file([old])], ALICE)), "merged")
        held = pr.facet_data(self.main_entry())
        self.assertEqual(held["reading"]["flags"], [])
        self.assertEqual(held["reading"]["by"], [ALICE])
        self.assertEqual(pr.checked_by(self.main_entry()), [ALICE])

    def test_looks_right_does_not_sign_off_text_that_changed(self) -> None:
        # The receipt of a facet the card-level answer does not name is
        # compared too.
        self.write()
        card = self.card({"word": {"ok": True}},
                         {"reading": "what it said before"}, looks_right=True)
        self.assertEqual(self.mail("m1", ALICE, card), "merged")
        held = pr.facet_data(self.main_entry())
        self.assertEqual(list(held), ["word"])
        self.assertNotIn("checked_by", self.main_text())
        self.assertTrue(any("1 stale" in line for line in self.logged), self.logged)

    def test_a_word_fix_ties_what_comes_with_it(self) -> None:
        self.write()
        card = self.card({"word": {"tags": ["spelling_wrong"], "fix": "పాలూ"},
                          "reading": {"tags": ["reading_wrong"], "fix": "pālū"}},
                         {"word": self.text("zz-9201", "word"),
                          "reading": self.text("zz-9201", "reading")})
        self.assertEqual(self.mail("m1", ALICE, card), "merged")
        proposals = {p.field: p for _, p in pr.all_proposals(self.git.main, "zz")}
        self.assertEqual(sorted(proposals), ["reading", "target"])
        self.assertEqual(proposals["reading"].tied, proposals["target"].id)
        self.assertEqual(proposals["target"].tied, "")


class Quorum(unittest.TestCase):
    def test_the_bot_and_the_facet_rule_read_the_one_constant(self) -> None:
        import review_quorum as rq
        self.assertEqual(rb.agreements_needed({}), max(rq.REVIEW_QUORUM - 1, 1))
        self.assertFalse(pr.WRITE_FACET_CHECKS)


if __name__ == "__main__":
    unittest.main()
