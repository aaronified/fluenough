#!/usr/bin/env python3
"""A path's `achievement_sets` (#322, decision 7 of the achievements mockup):
an optional list of { id, kind, decks } naming the sets the achievements
count, each deck a core id the path lists.

Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
PyYAML, like the validator itself.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_validate_b1 import PATH, B1Case  # noqa: E402


class AchievementSets(B1Case):

    def sets(self, value: object) -> None:
        self.edit(PATH, lambda d: d.update(achievement_sets=value))

    def test_a_path_without_sets_is_valid(self) -> None:
        self.assertNoError(PATH, "achievement_sets")

    def test_a_chosen_set_of_listed_decks_is_valid(self) -> None:
        self.sets([
            {"id": "home", "kind": "word", "decks": ["zz-home"]},
            {"id": "case-endings", "kind": "grammar",
             "decks": ["zz-grammar-case-endings", "zz-home"]},
        ])
        self.assertNoError(PATH, "achievement_sets")

    def test_the_sets_are_a_list(self) -> None:
        self.sets("home")
        self.assertError(PATH, "achievement_sets",
                         "must be a list of sets, each { id, kind, decks }")

    def test_a_set_is_a_mapping_with_known_fields(self) -> None:
        self.sets(["home", {"id": "a", "kind": "word", "decks": ["zz-home"], "x": 1}])
        errors = self.errors(PATH)
        self.assertIn("achievement_sets[0]: must be a mapping with id, kind and decks", errors)
        self.assertIn("achievement_sets[1]: unknown field 'x'", errors)

    def test_the_id_is_a_name_and_unique(self) -> None:
        self.sets([
            {"id": "Home", "kind": "word", "decks": ["zz-home"]},
            {"id": "home", "kind": "word", "decks": ["zz-home"]},
            {"id": "home", "kind": "word", "decks": ["zz-home"]},
        ])
        errors = self.errors(PATH)
        self.assertIn("achievement_sets[0].id: must match [a-z0-9-]+, got 'Home'", errors)
        self.assertIn("achievement_sets[2]: 'home' is listed twice", errors)

    def test_the_kind_is_word_or_grammar(self) -> None:
        self.sets([{"id": "home", "kind": "verbs", "decks": ["zz-home"]}])
        self.assertError(PATH, "achievement_sets[0].kind",
                         "must be \"word\" or \"grammar\", got 'verbs'")

    def test_the_decks_are_core_ids_the_path_lists(self) -> None:
        self.sets([
            {"id": "a", "kind": "word", "decks": []},
            {"id": "b", "kind": "word", "decks": ["zz-health"]},
            {"id": "c", "kind": "word", "decks": ["home"]},
            {"id": "d", "kind": "word", "decks": ["zz-home", "zz-home"]},
        ])
        errors = self.errors(PATH)
        self.assertIn("achievement_sets[0].decks: must be a non-empty list of core ids", errors)
        self.assertIn("achievement_sets[1].decks: lists 'zz-health', which the path does not",
                      errors)
        self.assertIn("achievement_sets[2].decks: 'home' is not a core id of zz: zz- and a "
                      "name, such as zz-home", errors)
        self.assertIn("achievement_sets[3].decks: 'zz-home' is listed twice", errors)


if __name__ == "__main__":
    unittest.main()
