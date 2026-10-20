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


class Writing(Base):
    def _a_block_card_gets_one_line(self) -> None:
        before = self.single.read_text(encoding="utf-8").splitlines()
        result = self.check("zz-9201")
        self.assertEqual(result.checked, [("zz-9201", "zz-en-extra")])
        after = self.single.read_text(encoding="utf-8").splitlines()
        self.assertEqual(len(after), len(before) + 1)
        self.assertIn(f'    checked_by: ["{ALICE}"]', after)
        self.assertEqual(self.checked(self.single, "zz-9201"), [ALICE])

    def _the_same_code_is_never_added_twice(self) -> None:
        self.check("zz-9201")
        text = self.single.read_text(encoding="utf-8")
        again = self.check("zz-9201")
        self.assertEqual(again.checked, [])
        self.assertEqual(again.already, ["zz-9201"])
        self.assertEqual(self.single.read_text(encoding="utf-8"), text)
        self.check("zz-9201", code=BOB)
        self.assertEqual(self.checked(self.single, "zz-9201"), [ALICE, BOB])
        self.assertEqual(self.single.read_text(encoding="utf-8").count("checked_by"), 1)


    def _a_layer_review_checks_the_core_too(self) -> None:
        self.check("zz-9001", deck="zz-en-home")
        self.assertEqual(self.checked(self.core, "zz-9001"), [ALICE])
        self.assertEqual(self.checked(self.layer, "zz-9001"), [ALICE])


    def test_a_sign_off_is_written_once_and_a_layer_review_checks_the_core(self) -> None:
        cases = (
            self._a_block_card_gets_one_line,
            self._the_same_code_is_never_added_twice,
            self._a_layer_review_checks_the_core_too,
        )
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()


class Tagging(Base):
    def _partly_checked_stays_unreviewed(self) -> None:
        result = self.check_all("zz-en-home", self.core_cards()[:-1])
        self.assertEqual(result.reviewed, [])
        self.assertIn('tags: ["unreviewed"]', self.core.read_text(encoding="utf-8"))

    def _every_card_checked_is_reviewed(self) -> None:
        result = self.check_all("zz-en-home", self.core_cards())
        self.assertEqual(sorted(result.reviewed), ["zz-en-home", "zz-home"])
        self.assertIn('tags: ["reviewed"]\n', self.core.read_text(encoding="utf-8"))
        self.assertNotIn("unreviewed", self.core.read_text(encoding="utf-8"))
        # The layer had no tags: the line is added before its cards.
        self.assertIn('tags: ["reviewed"]\ncards:', self.layer.read_text(encoding="utf-8"))


    def test_every_card_checked_tags_the_deck_reviewed(self) -> None:
        cases = (
            self._every_card_checked_is_reviewed,
            self._partly_checked_stays_unreviewed,
        )
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()


class ContentHash(Base):
    def _checked_by_does_not_change_it(self) -> None:
        before = {p: content(p) for p in (self.core, self.layer, self.single)}
        sha = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in before}
        self.check_all("zz-en-home", ["zz-9001", "zz-9101", "zz-9115"])
        self.check_all("zz-en-home", ["zz-9001", "zz-9101"], code=BOB)
        self.check_all("zz-en-extra", ["zz-9201", "zz-9001"])
        for path, hashed in before.items():
            self.assertEqual(content(path), hashed, path.name)
            self.assertNotEqual(hashlib.sha256(path.read_bytes()).hexdigest(),
                                sha[path], path.name)


    def test_checked_by_leaves_the_content_hash_alone(self) -> None:
        cases = (
            self._checked_by_does_not_change_it,
        )
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()


if __name__ == "__main__":
    unittest.main()
