#!/usr/bin/env python3
"""The synonym-set validator refuses what ADR-0050 says it refuses.

Words are made up, never real language (AGENTS.md, "Tests check behaviour").
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_synonyms as v

HEADER = '# Test sets. Licence: CC BY-SA 4.0.\nversion: 1\nsets:\n'


def sets(*lines: str) -> str:
    return HEADER + "".join(f"  - {line}\n" for line in lines)


GOOD = sets('["florp", "quandle"]', '["glim", "snarkle"]')


class SetFile(unittest.TestCase):
    def refused(self, text: str, fragment: str) -> None:
        errors = v.check_sets(text)
        self.assertTrue(any(fragment in e for e in errors), errors)

    def test_valid_and_empty_files_pass(self) -> None:
        self.assertEqual(v.check_sets(GOOD), [])
        self.assertEqual(v.check_sets(HEADER.replace("sets:\n", "sets: []\n")), [])

    def test_a_word_in_two_sets_names_the_sets_to_merge(self) -> None:
        self.refused(sets('["florp", "quandle"]', '["quandle", "zib"]'),
                     "merge the two sets")

    def test_a_set_of_one_or_a_repeat_is_refused(self) -> None:
        self.refused(sets('["florp"]'), "needs two members")
        self.refused(sets('["florp", "florp"]'), "repeated")

    def test_unsorted_members_or_sets_are_refused(self) -> None:
        self.refused(sets('["quandle", "florp"]'), "members are not sorted")
        self.refused(sets('["glim", "snarkle"]', '["florp", "quandle"]'),
                     "sets are not sorted")

    def test_a_member_must_be_quoted_and_in_comparison_form(self) -> None:
        self.refused(sets('[florp, "quandle"]'), "not in double quotes")
        self.refused(sets('["Florp", "quandle"]'), "comparison form")
        self.refused(sets('["to florp", "quandle"]'), "comparison form")

    def test_the_header_and_version_are_required(self) -> None:
        self.refused("version: 1\nsets: []\n", "licence")
        self.refused("# CC BY-SA 4.0\nsets: []\n", "version")
        self.refused("# CC BY-SA 4.0\nversion: 2\nsets: []\n", "version must")


LAYER = """\
schema: 1
id: "xx-en-probe"
kind: "layer"
core: "xx-probe"
native: {{ code: "en", iso639_3: "eng", name: "English" }}
cards:
{cards}"""


class NotSynonyms(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def check(self, cards: str) -> list[str]:
        (self.tmp / "xx-en-probe.yaml").write_text(
            LAYER.format(cards=cards), encoding="utf-8")
        return v.validate(GOOD, self.tmp)

    def test_a_live_entry_passes(self) -> None:
        self.assertEqual(self.check(
            '  "xx-1":\n    native: "Florp!"\n'
            '    not_synonyms: ["quandle"]\n'), [])

    def test_a_dead_entry_is_an_error(self) -> None:
        errors = self.check('  "xx-1":\n    native: "florp"\n'
                            '    not_synonyms: ["snarkle"]\n')
        self.assertTrue(any("blocks nothing" in e for e in errors), errors)

    def test_a_set_escaped_on_two_cards_fails(self) -> None:
        errors = self.check(
            '  "xx-1":\n    native: "florp"\n    not_synonyms: ["quandle"]\n'
            '  "xx-2":\n    native: "quandle"\n    not_synonyms: ["florp"]\n')
        self.assertTrue(any("escaped by not_synonyms" in e for e in errors),
                        errors)

    def test_a_single_file_deck_card_is_checked_too(self) -> None:
        (self.tmp / "xx-en-solo.yaml").write_text(
            'schema: 1\nid: "xx-en-solo"\n'
            'native: { code: "en", iso639_3: "eng", name: "English" }\n'
            'cards:\n  - id: "xx-1"\n    native: "florp"\n'
            '    not_synonyms: ["snarkle"]\n', encoding="utf-8")
        errors = v.validate(GOOD, self.tmp)
        self.assertTrue(any("blocks nothing" in e for e in errors), errors)


if __name__ == "__main__":
    unittest.main()
