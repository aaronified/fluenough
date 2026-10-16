#!/usr/bin/env python3
"""Who checked a card (#449, ADR-0038 amended): the validator's checks of
`checked_by`, the bot's edits that add a reviewer's sign-off to it and tag
a fully checked deck `reviewed`, and the content hash that leaves
`checked_by` out so learners are not offered an update for it.

Stdlib `unittest` plus PyYAML, like the validator itself. Every test works
on a copy of tools/fixtures/b1/zz, a made-up language, in a temporary
directory, and never on decks/.
"""

from __future__ import annotations

import hashlib
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import deck_index  # noqa: E402
import proposals as pr  # noqa: E402
import review_bot as rb  # noqa: E402
import validate_decks as vd  # noqa: E402
from test_proposals import ALICE, BOB, SINGLE, TOOLS  # noqa: E402
from test_review_bot import Base as BotBase, review_file  # noqa: E402


def content(path: Path) -> str:
    return hashlib.sha256(deck_index.content_bytes(path.read_bytes())).hexdigest()


class Base(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        shutil.copytree(TOOLS / "fixtures" / "b1" / "zz", self.root / "decks" / "zz")
        self.single = self.root / "decks" / "zz" / "zz-en-extra.yaml"
        self.single.write_text(SINGLE, encoding="utf-8")
        self.core = self.root / "decks" / "zz" / "zz-home.yaml"
        self.layer = self.root / "decks" / "zz" / "en" / "zz-en-home.yaml"

    def check(self, card: str, deck: str = "zz-en-extra", code: str = ALICE,
              result: pr.Checks | None = None) -> pr.Checks:
        result = result if result is not None else pr.Checks()
        pr.check(self.root, "zz", deck, card, code, result)
        return result

    def checked(self, path: Path, card: str) -> list[str]:
        return next(pr.checked_by(e) for e in pr.entries(self.root, "zz", card)
                    if e.path == path)

    def check_all(self, deck: str, cards: list[str], code: str = ALICE) -> pr.Checks:
        result = pr.Checks()
        for card in cards:
            self.check(card, deck, code, result)
        pr.review_done(result)
        return result

    def core_cards(self) -> list[str]:
        return [e.card for e in pr.entries(self.root, "zz") if e.deck == "zz-home"]


class Validating(Base):
    def write(self, line: str) -> Path:
        self.single.write_text(SINGLE.replace(
            '    notes: "Always plural."\n',
            f'    notes: "Always plural."\n    {line}\n'), encoding="utf-8")
        return self.single

    def test_a_list_of_rater_codes_passes(self) -> None:
        self.assertEqual(vd.validate(self.write(f'checked_by: ["{ALICE}", "{BOB}"]')).errors, [])

    def test_on_every_kind_of_entry(self) -> None:
        self.check_all("zz-en-home", self.core_cards())
        self.check("zz-9202")
        self.check("zz-9001")
        for path in (self.core, self.layer, self.single):
            self.assertEqual(vd.validate(path).errors, [], path.name)

    def test_bad_lists(self) -> None:
        for line, said in (
                ('checked_by: []', "non-empty list"),
                ('checked_by: "FL-7K3M-Q9TD-6"', "non-empty list"),
                ('checked_by: ["FL-7K3M-Q9TD-7"]', "must list rater codes"),
                ('checked_by: ["fl-7k3m-q9td-6"]', "must list rater codes"),
                (f'checked_by: ["{ALICE}", "{ALICE}"]', "twice")):
            errors = vd.validate(self.write(line)).errors
            self.assertTrue(any(said in e for e in errors), (line, errors))

    def flow(self, card: str) -> Path:
        self.single.write_text(SINGLE.replace(
            '  - ref: "zz-9001"\n    native: "house"\n', card), encoding="utf-8")
        return self.single

    def test_last_in_a_one_line_flow_card_passes(self) -> None:
        path = self.flow(f'  - {{ ref: "zz-9001", native: "house", checked_by: ["{ALICE}"] }}\n')
        self.assertEqual(vd.validate(path).errors, [])
        self.assertNotIn(b"checked_by", deck_index.content_bytes(path.read_bytes()))

    def test_anywhere_the_index_cannot_take_it_out_is_an_error(self) -> None:
        # In the middle of a flow card, or a flow card wrapped over lines:
        # content_sha256 would change, and every learner be offered an update.
        for card in (
                f'  - {{ ref: "zz-9001", checked_by: ["{ALICE}"], native: "house" }}\n',
                f'  - {{ ref: "zz-9001", native: "house",\n      checked_by: ["{ALICE}"] }}\n',
                f'  - {{ ref: "zz-9001", native: "house", checked_by: [\n      "{ALICE}"] }}\n'):
            errors = vd.validate(self.flow(card)).errors
            self.assertTrue(any("content_sha256" in e for e in errors), (card, errors))

    def test_not_deck_content_for_other_checks(self) -> None:
        # Not an unknown field on a layer entry, which allows only the
        # learner's language.
        self.check_all("zz-en-home", ["zz-9001"])
        self.assertFalse(any("checked_by" in e and "unknown" in e
                             for e in vd.validate(self.layer).errors))


class Writing(Base):
    def test_a_block_card_gets_one_line(self) -> None:
        before = self.single.read_text(encoding="utf-8").splitlines()
        result = self.check("zz-9201")
        self.assertEqual(result.checked, [("zz-9201", "zz-en-extra")])
        after = self.single.read_text(encoding="utf-8").splitlines()
        self.assertEqual(len(after), len(before) + 1)
        self.assertIn(f'    checked_by: ["{ALICE}"]', after)
        self.assertEqual(self.checked(self.single, "zz-9201"), [ALICE])

    def test_the_same_code_is_never_added_twice(self) -> None:
        self.check("zz-9201")
        text = self.single.read_text(encoding="utf-8")
        again = self.check("zz-9201")
        self.assertEqual(again.checked, [])
        self.assertEqual(again.already, ["zz-9201"])
        self.assertEqual(self.single.read_text(encoding="utf-8"), text)
        self.check("zz-9201", code=BOB)
        self.assertEqual(self.checked(self.single, "zz-9201"), [ALICE, BOB])
        self.assertEqual(self.single.read_text(encoding="utf-8").count("checked_by"), 1)

    def test_a_flow_card_gets_it_on_its_line(self) -> None:
        result = self.check("zz-9101", deck="zz-en-home")
        self.assertEqual(sorted(result.checked),
                         [("zz-9101", "zz-en-home"), ("zz-9101", "zz-home")])
        self.assertIn(f'phrasebook: true, checked_by: ["{ALICE}"] }}',
                      self.core.read_text(encoding="utf-8"))
        self.assertIn(f'"zz-9101": {{ native: "Mother 1!", checked_by: ["{ALICE}"] }}',
                      self.layer.read_text(encoding="utf-8"))
        self.check("zz-9101", deck="zz-en-home", code=BOB)
        self.assertEqual(self.checked(self.core, "zz-9101"), [ALICE, BOB])
        self.assertEqual(self.checked(self.layer, "zz-9101"), [ALICE, BOB])

    def test_a_layer_review_checks_the_core_too(self) -> None:
        self.check("zz-9001", deck="zz-en-home")
        self.assertEqual(self.checked(self.core, "zz-9001"), [ALICE])
        self.assertEqual(self.checked(self.layer, "zz-9001"), [ALICE])

    def test_a_single_deck_review_checks_only_its_own_entry(self) -> None:
        # zz-9001 is written in the core and listed by ref in zz-en-extra.
        result = self.check("zz-9001")
        self.assertEqual(result.checked, [("zz-9001", "zz-en-extra")])
        self.assertNotIn("checked_by", self.core.read_text(encoding="utf-8"))

    def test_a_card_not_in_the_deck_is_missing(self) -> None:
        self.assertEqual(self.check("zz-9999").missing, ["zz-9999"])
        self.assertEqual(self.check("zz-9004").missing, ["zz-9004"])

    def test_no_other_card_changes(self) -> None:
        before = vd._load_raw(self.core)
        self.check("zz-9004", deck="zz-en-home")
        after = vd._load_raw(self.core)
        self.assertEqual(before, after)


class Tagging(Base):
    def test_partly_checked_stays_unreviewed(self) -> None:
        result = self.check_all("zz-en-home", self.core_cards()[:-1])
        self.assertEqual(result.reviewed, [])
        self.assertIn('tags: ["unreviewed"]', self.core.read_text(encoding="utf-8"))

    def test_every_card_checked_is_reviewed(self) -> None:
        result = self.check_all("zz-en-home", self.core_cards())
        self.assertEqual(sorted(result.reviewed), ["zz-en-home", "zz-home"])
        self.assertIn('tags: ["reviewed"]\n', self.core.read_text(encoding="utf-8"))
        self.assertNotIn("unreviewed", self.core.read_text(encoding="utf-8"))
        # The layer had no tags: the line is added before its cards.
        self.assertIn('tags: ["reviewed"]\ncards:', self.layer.read_text(encoding="utf-8"))

    def test_a_merged_deck_is_reviewed_only_once_core_and_layer_are(self) -> None:
        # Every layer entry checked by hand, the core not.
        lines = self.layer.read_text(encoding="utf-8")
        result = pr.Checks()
        self.check("zz-9001", "zz-en-home", result=result)
        # Only the core's first card and the layer's are checked: neither
        # file is, as a whole.
        pr.review_done(result)
        self.assertEqual(result.reviewed, [])
        self.assertNotEqual(lines, self.layer.read_text(encoding="utf-8"))
        # The layer fully checked while the core is not: the layer is
        # tagged, the core keeps unreviewed, and the merged deck reads
        # unreviewed (docs/DECK-FORMAT.md, "What the merged deck is").
        for card in [e.card for e in pr.entries(self.root, "zz") if e.path == self.layer]:
            pr._write_checked(next(e for e in pr.entries(self.root, "zz", card)
                                   if e.path == self.layer), [ALICE])
        self.assertTrue(pr.all_checked(self.layer))
        self.assertFalse(pr.all_checked(self.core))
        result = self.check_all("zz-en-home", ["zz-9004"])
        self.assertEqual(result.reviewed, ["zz-en-home"])
        self.assertIn("unreviewed", self.core.read_text(encoding="utf-8"))

    def test_other_tags_are_kept(self) -> None:
        self.core.write_text(self.core.read_text(encoding="utf-8").replace(
            'tags: ["unreviewed"]', 'tags: [beginner, unreviewed, grammar]'),
            encoding="utf-8")
        self.assertTrue(pr.mark_reviewed(self.core))
        self.assertIn('tags: ["beginner", "reviewed", "grammar"]\n',
                      self.core.read_text(encoding="utf-8"))
        self.assertFalse(pr.mark_reviewed(self.core))

    def test_a_file_with_no_cards_is_never_all_checked(self) -> None:
        grammar = self.root / "decks" / "zz" / "zz-grammar-case-endings.yaml"
        self.assertFalse(pr.all_checked(grammar))


class ContentHash(Base):
    def test_checked_by_does_not_change_it(self) -> None:
        before = {p: content(p) for p in (self.core, self.layer, self.single)}
        sha = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in before}
        self.check_all("zz-en-home", ["zz-9001", "zz-9101", "zz-9115"])
        self.check_all("zz-en-home", ["zz-9001", "zz-9101"], code=BOB)
        self.check_all("zz-en-extra", ["zz-9201", "zz-9001"])
        for path, hashed in before.items():
            self.assertEqual(content(path), hashed, path.name)
            self.assertNotEqual(hashlib.sha256(path.read_bytes()).hexdigest(),
                                sha[path], path.name)

    def test_the_tag_flip_does(self) -> None:
        before = content(self.core)
        self.check_all("zz-en-home", self.core_cards())
        self.assertNotEqual(content(self.core), before)
        flipped = self.core.read_text(encoding="utf-8")
        # Only the tag counts: the file as it was, tagged reviewed.
        self.core.write_bytes(deck_index.content_bytes(flipped.encode("utf-8")))
        self.assertNotIn("checked_by", self.core.read_text(encoding="utf-8"))
        self.assertEqual(vd._load_raw(self.core)["tags"], ["reviewed"])

    def test_a_bare_key_with_items_by_hand(self) -> None:
        text = SINGLE.replace('    notes: "Always plural."\n',
                              f'    notes: "Always plural."\n    checked_by:\n      - "{ALICE}"\n')
        self.assertEqual(deck_index.content_bytes(text.encode()), SINGLE.encode())
        text = SINGLE.replace('    notes: "Always plural."\n',
                              f'    notes: "Always plural."\n    checked_by: [\n      "{ALICE}"]\n')
        self.assertEqual(deck_index.content_bytes(text.encode()), SINGLE.encode())


class Bot(BotBase):
    def signoff(self, cards: list[str], code: str = ALICE,
                deck: str = "zz-en-home") -> rb.Review:
        return rb.read_review([review_file([
            {"card": c, "at": "2026-10-09T09:40:00.000Z", "looks_right": True}
            for c in cards], code=code, deck=deck)], code)

    def core_cards(self) -> list[str]:
        return [e.card for e in pr.entries(self.git.main, "zz") if e.deck == "zz-home"]

    def test_looks_right_is_read_as_a_sign_off(self) -> None:
        review = self.signoff(["zz-9001", "zz-9004"])
        self.assertEqual(review.checks, [("zz", "zz-en-home", "zz-9001"),
                                         ("zz", "zz-en-home", "zz-9004")])
        self.assertEqual(review.suggestions, [])

    def test_a_sign_off_is_written_by_the_reviewers_pr(self) -> None:
        self.assertEqual(self.bot.review("mail1", ALICE, self.signoff(["zz-9001"])),
                         "merged")
        self.assertIn(f'checked_by: ["{ALICE}"]', self.main_text("decks/zz/zz-home.yaml"))
        self.assertIn(f'checked_by: ["{ALICE}"]',
                      self.main_text("decks/zz/en/zz-en-home.yaml"))
        opened = self.github.prs[0]
        self.assertEqual(opened["title"], f"Review sign-offs by {ALICE}")
        self.assertIn(f"Checked by {ALICE}: 1 card(s), `zz-9001`", opened["body"])
        self.assertNotIn("now tagged reviewed", opened["body"])

    def test_the_same_code_twice_opens_nothing(self) -> None:
        self.bot.review("mail1", ALICE, self.signoff(["zz-9001"]))
        self.assertEqual(self.bot.review("mail2", ALICE, self.signoff(["zz-9001"])),
                         "nothing")
        self.assertEqual(len(self.github.prs), 1)
        self.assertEqual(self.main_text("decks/zz/zz-home.yaml").count(ALICE), 1)

    def test_the_last_card_checked_tags_the_deck_reviewed(self) -> None:
        cards = self.core_cards()
        self.bot.review("mail1", ALICE, self.signoff(cards[:-1]))
        self.assertIn("unreviewed", self.main_text("decks/zz/zz-home.yaml"))
        self.bot.review("mail2", BOB, self.signoff(cards[-1:], code=BOB))
        self.assertNotIn("unreviewed", self.main_text("decks/zz/zz-home.yaml"))
        self.assertIn('tags: ["reviewed"]', self.main_text("decks/zz/zz-home.yaml"))
        self.assertIn("now tagged reviewed: `zz-en-home`, `zz-home`",
                      self.github.prs[1]["body"])

    def test_a_suggestion_is_not_a_sign_off(self) -> None:
        review = rb.read_review([review_file([
            {"card": "zz-9201", "at": "2026-10-09T09:40:00.000Z", "looks_right": True,
             "suggestion": {"part": "meaning", "now": "milk", "text": "cow's milk"}}])],
            ALICE)
        self.assertEqual(review.checks, [])


if __name__ == "__main__":
    unittest.main()
