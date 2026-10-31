#!/usr/bin/env python3
"""A card's `verified` (#519): the data points reviewers settled with agreeing
"yes" answers. The validator allows it on a single file's card, a core's and
a layer's and checks its shape; the bot writes it one line at a time; the
index's content hash leaves it out, so learners are offered no update for
it. Stdlib `unittest` plus PyYAML, on a copy of tools/fixtures/b1/zz.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
import validate_decks as vd  # noqa: E402
from test_checked_by import Base, content  # noqa: E402
from test_proposals import BOB  # noqa: E402


def errors(path: Path) -> list[str]:
    return [str(e) for e in vd.validate(path).errors]


class Validating(Base):
    def put(self, path: Path, card: str, value: str) -> None:
        text = path.read_text(encoding="utf-8")
        marker = f'id: "{card}"\n' if path != self.layer else f'"{card}":\n'
        head = text.index(marker) if marker in text else text.index(f'"{card}":')
        end = text.index("\n", head) + 1
        path.write_text(text[:end] + f"    verified: {value}\n" + text[end:],
                        encoding="utf-8")

    def test_it_is_allowed_on_single_core_and_layer_cards(self) -> None:
        pr.settle_points(self.root, "zz", "zz-9201", ["meaning"])
        pr.settle_points(self.root, "zz", "zz-9001", ["sound", "example:0123abcd"])
        self.assertEqual(errors(self.single), [])
        self.assertEqual(errors(self.core), [])
        self.assertEqual(errors(self.layer), [])

    def test_a_malformed_list_is_refused(self) -> None:
        for bad in ('"meaning"', "[]", '["colour"]', '["meaning", "meaning"]',
                    '["example:xyz"]', "[3]"):
            with self.subTest(bad):
                fresh = type(self)("test_it_is_allowed_on_single_core_and_layer_cards")
                fresh.setUp()
                try:
                    fresh.put(fresh.single, "zz-9201", bad)
                    self.assertTrue(any("verified" in e for e in errors(fresh.single)),
                                    errors(fresh.single))
                finally:
                    fresh.doCleanups()


class Writing(Base):
    def test_it_is_one_line_listing_each_point_once(self) -> None:
        before = self.single.read_text(encoding="utf-8").splitlines()
        self.assertEqual(pr.settle_points(self.root, "zz", "zz-9201", ["meaning"]), "written")
        after = self.single.read_text(encoding="utf-8").splitlines()
        self.assertEqual(len(after), len(before) + 1)
        self.assertIn('    verified: ["meaning"]', after)
        self.assertEqual(pr.settle_points(self.root, "zz", "zz-9201", ["meaning"]), "none")
        self.assertEqual(pr.settle_points(self.root, "zz", "zz-9201", ["sound"]), "written")
        self.assertIn('    verified: ["meaning", "sound"]',
                      self.single.read_text(encoding="utf-8"))

    def test_it_goes_on_the_core_card_and_not_the_layer_translation(self) -> None:
        pr.settle_points(self.root, "zz", "zz-9001", ["meaning"])
        self.assertIn("verified", self.core.read_text(encoding="utf-8"))
        self.assertNotIn("verified", self.layer.read_text(encoding="utf-8"))

    def test_it_sits_beside_a_sign_off_in_either_order(self) -> None:
        self.check("zz-9201")
        pr.settle_points(self.root, "zz", "zz-9201", ["meaning"])
        self.check("zz-9201", code=BOB)
        text = self.single.read_text(encoding="utf-8")
        self.assertEqual(text.count("verified:"), 1)
        self.assertEqual(text.count("checked_by:"), 1)
        self.assertEqual(errors(self.single), [])


class Hashing(Base):
    def test_a_settled_point_offers_learners_no_update(self) -> None:
        before = content(self.single), content(self.core)
        pr.settle_points(self.root, "zz", "zz-9201", ["meaning", "sound"])
        pr.settle_points(self.root, "zz", "zz-9001", ["meaning"])
        self.check("zz-9201")
        self.assertEqual((content(self.single), content(self.core)), before)

    def test_a_flow_card_keeps_its_hash_too(self) -> None:
        line = '  - { id: "zz-1", target: "x", reading: "x" }\n'
        marked = ('  - { id: "zz-1", target: "x", reading: "x", '
                  'checked_by: ["FL-A"], verified: ["meaning"] }\n')
        import deck_index
        self.assertEqual(deck_index.content_bytes(marked.encode()), line.encode())
        only = '  - { id: "zz-1", target: "x", reading: "x", verified: ["meaning"] }\n'
        self.assertEqual(deck_index.content_bytes(only.encode()), line.encode())

    def test_a_flow_card_is_written_last_and_keeps_its_hash(self) -> None:
        before = content(self.core)
        self.assertEqual(pr.settle_points(self.root, "zz", "zz-9101", ["sound"]), "written")
        self.check("zz-9101", deck="zz-home")
        self.assertIn('phrasebook: true, verified: ["sound"], checked_by: ["',
                      self.core.read_text(encoding="utf-8"))
        self.assertEqual(errors(self.core), [])
        self.assertEqual(content(self.core), before)
        # And the other order: a point added after a sign-off.
        self.assertEqual(pr.settle_points(self.root, "zz", "zz-9101", ["meaning"]), "written")
        self.assertIn('verified: ["sound", "meaning"], checked_by: ["',
                      self.core.read_text(encoding="utf-8"))
        self.assertEqual(errors(self.core), [])
        self.assertEqual(content(self.core), before)


if __name__ == "__main__":
    unittest.main()
