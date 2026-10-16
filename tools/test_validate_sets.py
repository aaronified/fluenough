#!/usr/bin/env python3
"""Set cards in the validator (DECK-FORMAT.md, Set cards; #506, #515): a
card of a vocab core, `kind: "set"`, whose members are cards by ref, or a
rule and one fixed value of its table ("Rule + axis", owner, 2026-10-16),
with its name and explanation in each layer.

Each test copies the B1 fixture (tools/fixtures/b1/zz) as
tools/test_validate_b1.py does, adds a set card, and checks the exact
message. The fixture itself has no set card.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_validate_b1 import CORE, LAYER, RULES, B1Case, card, single  # noqa: E402

SET_ID = "zz-9201"
SET = {"id": SET_ID, "kind": "set",
       "members": [{"ref": "zz-9001"}, {"ref": "zz-9004"}, {"ref": "zz-9006"}]}
SET_TEXT = {"native": "Three first words",
            "explanation": "Three words you meet first: ఇల్లు (illu), అమ్మ (amma), "
                           "నేను (nēnu)."}


class SetCase(B1Case):

    def add_set(self, set_card: dict | None = None, text: dict | None = None) -> None:
        """Adds a set card to the core, and its text to the layer."""
        set_card = dict(SET) if set_card is None else set_card
        text = dict(SET_TEXT) if text is None else text
        self.edit(CORE, lambda d: d["cards"].append(set_card))
        self.edit(LAYER, lambda d: d["cards"].__setitem__(set_card.get("id", SET_ID),
                                                           text))


class RefSets(SetCase):

    def test_a_set_by_refs_with_its_layer_text_is_valid(self) -> None:
        self.add_set()
        lines = self.assertClean()
        # Not a card the layer covers: it is taught, never asked.
        self.assertIn("  info    cards: covers 20 of 20 cards of zz-home (100%)",
                      self.section(lines, LAYER))

    def test_a_set_card_has_only_id_kind_and_members(self) -> None:
        self.add_set({**SET, "target": "x"})
        self.assertError(CORE, f"card {SET_ID}", "a set card has only id, kind and "
                         "members, its name and explanation in each layer; got 'target'")

    def test_a_set_has_two_members_or_more(self) -> None:
        self.add_set({**SET, "members": [{"ref": "zz-9001"}]})
        self.assertError(CORE, f"card {SET_ID}.members",
                         "a set has at least 2 members, got 1")

    def test_a_member_is_a_ref_once(self) -> None:
        self.add_set({**SET, "members": [{"ref": "zz-9001"}, {"ref": "zz-9001"},
                                         {"ref": SET_ID}, {"word": "x"}]})
        self.assertError(CORE, f"card {SET_ID}.members[1]", "zz-9001 is a member already")
        self.assertError(CORE, f"card {SET_ID}.members[2]", "a set is not a member of "
                                                            "itself")
        self.assertError(CORE, f"card {SET_ID}.members[3]",
                         "must be { ref: \"zz-0001\" }, a card of the language, got "
                         "{'word': 'x'}")

    def test_members_are_required(self) -> None:
        self.add_set({"id": SET_ID, "kind": "set"})
        self.assertError(CORE, f"card {SET_ID}.members",
                         'is required: a list of { ref: "zz-0001" }, or { rule, and '
                         'one value of its table }')

    def test_its_id_is_a_card_id_of_the_language(self) -> None:
        self.add_set({**SET, "id": "zz-9001"})
        self.assertError(CORE, "card zz-9001", "duplicate card id")

    def test_a_member_is_a_card_the_language_writes(self) -> None:
        self.add_set({**SET, "members": [{"ref": "zz-9001"}, {"ref": "zz-9999"}]})
        self.assertAcross(f"{self.p(CORE)}: card {SET_ID}: members names card "
                          f"zz-9999, which no deck writes")

    def test_a_member_is_not_a_set(self) -> None:
        self.add_set()
        other = {"id": "zz-9202", "kind": "set",
                 "members": [{"ref": "zz-9001"}, {"ref": SET_ID}]}
        self.add_set(other, dict(SET_TEXT))
        self.assertAcross(f"{self.p(CORE)}: card zz-9202: members names {SET_ID}, a "
                          f"set card; a set's members are cards that are asked")

    def test_a_set_is_never_listed_by_ref(self) -> None:
        self.add_set()
        self.put("en/zz-en-extra.yaml", single(cards=[{"ref": SET_ID, "native": "x"}]))
        lines = self.run_main()
        self.assertTrue(any(f"{SET_ID} is a set card, taught in its own deck and never "
                            f"listed by ref" in x for x in lines), lines)

    def test_a_set_card_is_written_in_a_core(self) -> None:
        self.put("en/zz-en-extra.yaml", single(cards=[dict(SET)]))
        self.assertError("en/zz-en-extra.yaml", "cards[0]",
                         'a set card is written in a vocab core, kind: "set", its name '
                         'and explanation in each layer (DECK-FORMAT.md, Set cards)')


class LayerText(SetCase):

    def test_the_layer_gives_its_name_and_explanation(self) -> None:
        self.add_set(text={"native": "Three first words"})
        self.assertError(LAYER, f"cards.{SET_ID}", "explanation is required: without it "
                                                   "the set is not taught from this "
                                                   "language")

    def test_the_layer_gives_nothing_else(self) -> None:
        self.add_set(text={**SET_TEXT, "notes": {"a": "b"}})
        self.assertError(LAYER, f"cards.{SET_ID}", "a set card's entry gives native, its "
                                                   "name, and explanation; got 'notes'")

    def test_its_explanation_keeps_the_transliteration(self) -> None:
        self.add_set(text={**SET_TEXT, "explanation": "Words such as అమ్మ."})
        self.assertTrue(any("has no transliteration beside it" in e
                            for e in self.errors(LAYER)), self.errors(LAYER))


class RuleSets(SetCase):
    """{ rule, <axis>: value }: the members are the table's cells, a row
    fixed by its word, or a slot fixed by its key."""

    def test_a_row_by_its_words_target_or_id_and_a_slot(self) -> None:
        sets = [
            {"id": "zz-9201", "kind": "set",
             "members": {"rule": "zz-grammar-case-endings", "noun": "అమ్మ"}},
            {"id": "zz-9202", "kind": "set",
             "members": {"rule": "zz-grammar-case-endings", "noun": "zz-9001"}},
            {"id": "zz-9203", "kind": "set",
             "members": {"rule": "zz-rule-lo", "case": "lo"}},
        ]
        for s in sets:
            self.add_set(s)
        self.assertClean()

    def test_the_rule_is_one_of_the_language(self) -> None:
        self.add_set({**SET, "members": {"rule": "zz-rule-past", "noun": "అమ్మ"}})
        self.assertAcross(f"{self.p(CORE)}: card {SET_ID}: members.rule names "
                          f"zz-rule-past, which no rules deck of zz defines")

    def test_a_row_is_a_row_of_the_table(self) -> None:
        self.add_set({**SET, "members": {"rule": "zz-grammar-case-endings",
                                         "noun": "పిల్లి"}})
        self.assertAcross(f"{self.p(CORE)}: card {SET_ID}: members.noun: 'పిల్లి' is no "
                          f"row of zz-grammar-case-endings; give a row's word, as its "
                          f"card writes it, or its id")

    def test_a_slot_is_a_slot_of_the_rule(self) -> None:
        self.add_set({**SET, "members": {"rule": "zz-rule-lo", "case": "ki"}})
        self.assertAcross(f"{self.p(CORE)}: card {SET_ID}: members.case: 'ki' is not a "
                          f"slot of zz-rule-lo; a value that is not a row's word is a "
                          f"slot, one of ['lo'], or use a part of speech of its rows "
                          f"(noun) as the key")

    def test_a_part_of_speech_is_one_of_its_rows(self) -> None:
        self.add_set({**SET, "members": {"rule": "zz-grammar-case-endings",
                                         "verb": "lo"}})
        self.assertAcross(f"{self.p(CORE)}: card {SET_ID}: members.verb: "
                          f"zz-grammar-case-endings's rows are noun, not verb")

    def test_one_value_beside_the_rule(self) -> None:
        self.add_set({**SET, "members": {"rule": "zz-rule-lo", "case": "lo",
                                         "noun": "అమ్మ"}})
        self.assertError(CORE, f"card {SET_ID}.members",
                         "a rule's set fixes one value of its table beside rule, as "
                         "{ rule: ..., verb: \"...\" } or { rule: ..., person: \"...\" }, "
                         "got ['case', 'noun']")

    def test_the_rule_is_named_by_id(self) -> None:
        self.add_set({**SET, "members": {"rule": "lo", "case": "lo"}})
        self.assertError(CORE, f"card {SET_ID}.members",
                         "rule must name a rule, such as zz-rule-past, or a rules core, "
                         "such as zz-grammar-past, got 'lo'")


class Untouched(SetCase):

    def test_the_rules_core_is_unchanged_by_a_set(self) -> None:
        self.add_set()
        self.assertNoError(RULES)
        self.assertEqual(card(self.data(CORE), SET_ID)["kind"], "set")


if __name__ == "__main__":
    unittest.main()
