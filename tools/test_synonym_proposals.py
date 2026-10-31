#!/usr/bin/env python3
"""A reviewer's extra accepted answer and refused synonym (ADR-0050, #924):
the review file, the validator's checks of the proposals, and what the
review bot's tools/proposals.py writes when one is applied.

Stdlib `unittest` plus PyYAML. Every test works on a copy of
tools/fixtures/b1/zz, a made-up language, in a temporary directory. No
network.
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
import review_bot as rb  # noqa: E402
import synonym_candidates as sc  # noqa: E402
import validate_decks as vd  # noqa: E402
from test_proposals import ALICE, BOB, SINGLE, TOOLS  # noqa: E402


def suggestion(part: str, text: str, **more: object) -> dict:
    """A suggestion as the review file carries it."""
    return {"part": part, "now": "", "text": text, "action": "add", **more}


class Synonyms(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        shutil.copytree(TOOLS / "fixtures" / "b1" / "zz", self.root / "decks" / "zz")
        zz = self.root / "decks" / "zz"
        self.single = zz / "zz-en-extra.yaml"
        self.single.write_text(SINGLE.replace(
            '    native: "milk"  # a comment stays\n',
            '    native: "milk"  # a comment stays\n    alt_native: ["cow juice"]\n'),
            encoding="utf-8")
        sets = self.root / "assets" / "synonyms"
        sets.mkdir(parents=True)
        # Made-up words; the cards' answers are in them.
        (sets / "en.yaml").write_text(
            "# Test sets. CC BY-SA 4.0.\nversion: 1\nsets:\n"
            '  - ["milk", "shore", "strand"]\n  - ["mother", "parent"]\n',
            encoding="utf-8")
        self.layer = zz / "en" / "zz-en-home.yaml"
        self.core = zz / "zz-home.yaml"

    def propose(self, part: str, text: str, card: str = "zz-9201",
                deck: str = "zz-en-extra", by: str = ALICE, **more: object) -> pr.Proposed:
        facts = rb.suggestion_facts(suggestion(part, text, **more))
        assert facts is not None, (part, text)
        result = pr.Proposed()
        pr.propose(self.root, pr.Suggestion("zz", deck, pr.Proposal(
            card, *facts, by, "2026-10-31")), result)
        return result

    def apply_one(self, result: pr.Proposed) -> pr.Applied:
        self.assertEqual(len(result.added), 1, result)
        return pr.apply(self.root, "zz", result.added[0].id)

    def accept(self, result: pr.Proposed) -> None:
        pid = result.added[0].id
        done = pr.Proposed()
        pr.accept(self.root, "zz", pid, BOB, result.added[0].text, done)
        self.assertEqual(len(done.accepted), 1)

    def entry(self, path: Path, card: str) -> dict:
        return next(e.data for e in pr.entries(self.root, "zz", card)
                    if e.path == path)

    # -- the review file ------------------------------------------------------

    def test_the_review_file_names_the_two_parts_and_only_an_add(self) -> None:
        self.assertEqual(rb.suggestion_facts(suggestion("alt_native", " cow's milk ")),
                         ("alt_native_add", "", "cow's milk"))
        # A word to refuse is put in comparison form, as the list holds it.
        self.assertEqual(rb.suggestion_facts(suggestion("not_synonyms", "To  Shore!")),
                         ("not_synonyms_add", "", "shore"))
        # A change, a removal, an empty word and a flag are not proposed.
        for more in ({"action": "edit"}, {"action": "remove"}, {"action": None}):
            self.assertIsNone(rb.suggestion_facts(suggestion("alt_native", "x", **more)))
        self.assertIsNone(rb.suggestion_facts(suggestion("alt_native", "  ")))
        self.assertIsNone(rb.suggestion_facts(suggestion("not_synonyms", "?!")))
        self.assertIsNone(rb.suggestion_facts(suggestion("alt_native", "x", flag=True)))

    # -- applying -------------------------------------------------------------

    def test_an_accepted_answer_is_added_to_the_list_and_nothing_else_changes(self) -> None:
        before = self.single.read_text(encoding="utf-8")
        result = self.propose("alt_native", "cow's milk")
        self.assertEqual(vd.validate(self.single).errors, [])
        self.accept(result)
        self.assertEqual(pr.apply(self.root, "zz", result.added[0].id).outcome, "applied")
        after = self.single.read_text(encoding="utf-8")
        self.assertIn('    alt_native: ["cow juice", "cow\'s milk"]\n', after)
        self.assertNotIn("proposed:", after)
        self.assertEqual(after, before.replace(
            '["cow juice"]', '["cow juice", "cow\'s milk"]'))
        self.assertEqual(vd.validate(self.single).errors, [])

    def test_a_card_without_the_list_gets_it_after_its_native_text(self) -> None:
        result = self.propose("alt_native", "the water", card="zz-9202")
        self.assertEqual(self.apply_one(result).outcome, "applied")
        self.assertIn('    native: "water"\n    alt_native: ["the water"]\n',
                      self.single.read_text(encoding="utf-8"))
        self.assertEqual(vd.validate(self.single).errors, [])

    def test_a_layers_entry_takes_both_lists(self) -> None:
        one = self.propose("alt_native", "mum", card="zz-9004", deck="zz-en-home")
        self.assertEqual(self.apply_one(one).outcome, "applied")
        two = self.propose("not_synonyms", "parent", card="zz-9004",
                           deck="zz-en-home")
        self.assertEqual(self.apply_one(two).outcome, "applied")
        data = self.entry(self.layer, "zz-9004")
        self.assertEqual(data["alt_native"], ["mum"])
        self.assertEqual(data["not_synonyms"], ["parent"])
        self.assertEqual(vd.validate(self.layer).errors, [])

    def test_a_card_of_a_core_goes_on_its_layers_entry(self) -> None:
        result = self.propose("alt_native", "dwelling", card="zz-9001", deck="zz-en-home")
        # Not on the core: the layer's entry takes it, where `native` is.
        self.assertEqual(result.added[0].field, "alt_native_add")
        found = pr.find(self.root, "zz", result.added[0].id)
        self.assertEqual(found[0].path, self.layer)

    def test_an_item_the_list_has_already_is_outdated_not_added_twice(self) -> None:
        result = self.propose("alt_native", "Cow Juice!")
        self.assertEqual((len(result.added), len(result.outdated)), (0, 1))
        self.assertNotIn("proposed:", self.single.read_text(encoding="utf-8"))

    def test_other_items_wait_their_turn_and_the_same_item_is_a_rival(self) -> None:
        first = self.propose("alt_native", "cow's milk")
        second = self.propose("alt_native", "dairy")
        same = self.propose("alt_native", "Cow's milk.", by=BOB)
        ids = [r.added[0].id for r in (first, second, same)]
        applied = pr.apply(self.root, "zz", ids[0])
        self.assertEqual(applied.outcome, "applied")
        # Only the proposal of the same item went with it.
        self.assertEqual([o.id for o in applied.closed], [ids[2]])
        entry = pr.find(self.root, "zz", ids[1])
        self.assertIsNotNone(entry)
        self.assertEqual(pr.outdated(self.root, "zz"), [])
        self.assertEqual(pr.apply(self.root, "zz", ids[1]).outcome, "applied")
        self.assertEqual(self.entry(self.single, "zz-9201")["alt_native"],
                         ["cow juice", "cow's milk", "dairy"])

    def test_an_extra_answer_the_card_refuses_is_left_for_the_owner(self) -> None:
        text = self.single.read_text(encoding="utf-8").replace(
            '    alt_native: ["cow juice"]\n',
            '    alt_native: ["cow juice"]\n    not_synonyms: ["shore", "strand"]\n')
        self.single.write_text(text, encoding="utf-8")
        self.assertEqual(vd.validate(self.single).errors, [])
        for word in ("Shore", "the strand", "a shore"):
            result = self.propose("alt_native", word)
            self.assertEqual((len(result.added), len(result.unsupported)), (0, 1), word)

    def test_an_english_extra_answer_may_not_run_sentences_together(self) -> None:
        result = self.propose("alt_native", "Cow milk. Not goat milk")
        self.assertEqual((len(result.added), len(result.unsupported)), (0, 1))
        self.assertNotIn("proposed:", self.single.read_text(encoding="utf-8"))

    def test_the_cards_own_native_text_is_already_an_answer(self) -> None:
        result = self.propose("alt_native", "Milk!")
        self.assertEqual((len(result.added), len(result.outdated)), (0, 1))
        self.assertNotIn("proposed:", self.single.read_text(encoding="utf-8"))

    # -- refusing what was never good ----------------------------------------

    def test_a_card_own_answer_is_never_listed_as_refused(self) -> None:
        for word in ("milk", "cow juice"):
            result = self.propose("not_synonyms", word)
            self.assertEqual((len(result.added), len(result.unsupported)), (0, 1), word)
        self.assertNotIn("not_synonyms", self.single.read_text(encoding="utf-8"))

    def test_one_answer_a_proposal_and_english_only(self) -> None:
        result = self.propose("alt_native", "milk; dairy")
        self.assertEqual((len(result.added), len(result.unsupported)), (0, 1))
        text = self.single.read_text(encoding="utf-8").replace(
            'native: { code: "en", iso639_3: "eng", name: "English" }',
            'native: { code: "hi", iso639_3: "hin", name: "Hindi" }').replace(
            'id: "zz-en-extra"', 'id: "zz-hi-extra"')
        other = self.root / "decks" / "zz" / "zz-hi-extra.yaml"
        other.write_text(text, encoding="utf-8")
        self.single.unlink()
        refused = self.propose("not_synonyms", "strand", deck="zz-hi-extra")
        self.assertEqual((len(refused.added), len(refused.unsupported)), (0, 1))

    def test_a_refused_word_must_do_something_the_ci_check_accepts(self) -> None:
        # In no set with one of the card's answers: it would block nothing.
        nothing = self.propose("not_synonyms", "parent")
        self.assertEqual((len(nothing.added), len(nothing.unsupported)), (0, 1))
        # In a set with the card's "milk": it blocks.
        good = self.propose("not_synonyms", "shore")
        self.assertEqual(self.apply_one(good).outcome, "applied")
        # A second card escaping the same set means the set is not absolute.
        second = self.propose("not_synonyms", "strand")
        self.assertEqual((len(second.added), len(second.unsupported)), (1, 0))
        text = self.single.read_text(encoding="utf-8").replace(
            'native: "water"', 'native: "milk"')
        self.single.write_text(text, encoding="utf-8")
        third = self.propose("not_synonyms", "strand", card="zz-9202")
        self.assertEqual((len(third.added), len(third.unsupported)), (0, 1))
        from validate_synonyms import validate
        sets = (self.root / pr.SYNONYM_SETS).read_text(encoding="utf-8")
        self.assertEqual(validate(sets, self.root / "decks" / "zz"), [])

    def test_a_list_written_over_several_lines_is_left_for_the_owner(self) -> None:
        text = self.single.read_text(encoding="utf-8").replace(
            '    alt_native: ["cow juice"]\n', '    alt_native:\n      - "cow juice"\n')
        self.single.write_text(text, encoding="utf-8")
        result = self.propose("alt_native", "cow's milk")
        self.assertEqual(self.apply_one(result).outcome, "unsupported")
        self.assertIn('      - "cow juice"\n', self.single.read_text(encoding="utf-8"))

    # -- the validator ------------------------------------------------------

    def check(self, p: pr.Proposal) -> list[str]:
        text = self.single.read_text(encoding="utf-8").replace(
            '    notes: "Always plural."\n',
            f'    notes: "Always plural."\n    proposed:\n      {p.line()}\n')
        self.single.write_text(text, encoding="utf-8")
        return vd.validate(self.single).errors

    def p(self, field: str, text: str, now: str = "") -> pr.Proposal:
        return pr.Proposal("zz-9201", field, now, text, ALICE, "2026-10-31")

    def test_the_validator_takes_good_proposals_and_refuses_bad_ones(self) -> None:
        cases = {
            self.p("alt_native_add", "cow's milk", now="milk"): "must be \"\"",
            self.p("alt_native_add", "a; b"): "one answer",
            self.p("not_synonyms_add", "Shore"): "comparison form",
            self.p("not_synonyms_add", "to shore"): "comparison form",
        }
        for p, message in cases.items():
            with self.subTest(message=message, field=p.field):
                fresh = type(self)(self._testMethodName)
                fresh.setUp()
                try:
                    errors = fresh.check(p)
                finally:
                    fresh.doCleanups()
                self.assertTrue(any(message in e for e in errors), errors)
        for good in (self.p("alt_native_add", "cow's milk"),
                     self.p("not_synonyms_add", "shore")):
            with self.subTest(good=good.field):
                fresh = type(self)(self._testMethodName)
                fresh.setUp()
                try:
                    self.assertEqual(fresh.check(good), [])
                finally:
                    fresh.doCleanups()

    def test_a_core_card_may_not_carry_one(self) -> None:
        text = self.core.read_text(encoding="utf-8")
        p = pr.Proposal("zz-9001", "alt_native_add", "", "dwelling", ALICE, "2026-10-31")
        first = text.index('  - id: "zz-9001"')
        end = text.index("\n", text.index("target:", first))
        self.core.write_text(text[:end + 1] + f"    proposed:\n      {p.line()}\n"
                             + text[end + 1:], encoding="utf-8")
        errors = vd.validate(self.core).errors
        self.assertTrue(any("field must be one of" in e for e in errors), errors)


class Candidates(unittest.TestCase):
    """tools/synonym_candidates.py: the same pair on several cards."""

    MORE = """\
schema: 1
id: "zz-en-more"
name: "More"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
cards:
  - id: "zz-9301"
    target: "ఒకటి"
    native: "water"
    alt_native: ["moisture", "milk"]
  - id: "zz-9302"
    target: "రెండు"
    native: "water"
    proposed:
      %s
  - id: "zz-9303"
    target: "మూడు"
    native: "water"
"""

    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        zz = self.root / "decks" / "zz"
        zz.mkdir(parents=True)
        add = pr.Proposal("zz-9302", "alt_native_add", "", "moisture", ALICE, "2026-10-31")
        (zz / "zz-en-more.yaml").write_text(self.MORE % add.line(), encoding="utf-8")

    def test_the_same_pair_on_two_cards_is_a_candidate_set(self) -> None:
        # One card's alt_native and another's waiting proposal make a pair
        # of two cards; "milk" on one card alone is not enough.
        self.assertEqual(sc.candidates(self.root),
                         [(("moisture", "water"), ["zz:zz-9301", "zz:zz-9302"])])
        self.assertEqual(len(sc.candidates(self.root, 1)), 2)

    def test_a_pair_already_in_one_set_is_not_a_candidate(self) -> None:
        sets = self.root / "assets" / "synonyms"
        sets.mkdir(parents=True)
        (sets / "en.yaml").write_text(
            '# Test sets. CC BY-SA 4.0.\nversion: 1\nsets:\n  - ["moisture", "water"]\n',
            encoding="utf-8")
        self.assertEqual(sc.candidates(self.root), [])
        self.assertEqual([p for p, _ in sc.candidates(self.root, 1)], [("milk", "water")])


if __name__ == "__main__":
    unittest.main()
