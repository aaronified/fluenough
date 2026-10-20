#!/usr/bin/env python3
"""Proposals in the decks (ADR-0038): the validator's checks of them, and
the edits the review bot makes with tools/proposals.py.

Stdlib `unittest` plus PyYAML, like the validator itself. Every test works
on a copy of tools/fixtures/b1/zz, a made-up language, in a temporary
directory, and never on decks/.
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
import validate_decks as vd  # noqa: E402

TOOLS = Path(__file__).resolve().parent
ALICE = "FL-7K3M-Q9TD-6"
BOB = "FL-0000-0000-0"

SINGLE = """\
# A single-file deck, for proposals on a card it writes and on a ref.
schema: 1
id: "zz-en-extra"
name: "Extra"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
cards:
  - id: "zz-9201"
    target: "పాలు"
    reading: "pālu"
    native: "milk"  # a comment stays
    notes: "Always plural."

  - id: "zz-9202"
    target: "నీళ్ళు"
    native: "water"
  - ref: "zz-9001"
    native: "house"
"""


def code(body: str) -> str:
    from rater_codes import check_symbol
    return f"FL-{body[:4]}-{body[4:]}-{check_symbol(body)}"


class Base(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        shutil.copytree(TOOLS / "fixtures" / "b1" / "zz", self.root / "decks" / "zz")
        self.single = self.root / "decks" / "zz" / "zz-en-extra.yaml"
        self.single.write_text(SINGLE, encoding="utf-8")
        self.core = self.root / "decks" / "zz" / "zz-home.yaml"
        self.layer = self.root / "decks" / "zz" / "en" / "zz-en-home.yaml"

    def p(self, card="zz-9201", field="native", now="milk", text="cow's milk",
          by=ALICE, **kw) -> pr.Proposal:
        return pr.Proposal(card, field, now, text, by, "2026-10-09", **kw)

    def propose(self, p: pr.Proposal, deck="zz-en-extra") -> pr.Proposed:
        result = pr.Proposed()
        pr.propose(self.root, pr.Suggestion("zz", deck, p), result)
        return result

    def errors(self, path: Path) -> list[str]:
        return vd.validate(path).errors


class Writing(Base):
    def _a_proposal_is_one_line_on_its_card(self) -> None:
        before = self.single.read_text(encoding="utf-8")
        p = self.p(why="It is cow's milk here.")
        result = self.propose(p)
        self.assertEqual(result.added, [p])
        after = self.single.read_text(encoding="utf-8")
        self.assertIn(f'    proposed:\n      {p.line()}\n\n  - id: "zz-9202"', after)
        # Only the two new lines: nothing else in the file changed.
        self.assertEqual(after.replace(f"    proposed:\n      {p.line()}\n", ""), before)
        self.assertEqual(self.errors(self.single), [])


    def _a_field_changed_since_is_outdated(self) -> None:
        result = self.propose(self.p(now="mlik"))
        self.assertEqual(result.added, [])
        self.assertEqual(len(result.outdated), 1)
        self.assertNotIn("proposed", self.single.read_text(encoding="utf-8"))


    def _the_meaning_of_a_split_deck_goes_in_its_layer(self) -> None:
        p = self.p(card="zz-9004", now="mother", text="mum")
        self.assertEqual(self.propose(p, deck="zz-en-home").added, [p])
        self.assertIn("proposed:", self.layer.read_text(encoding="utf-8"))
        self.assertEqual(self.errors(self.layer), [])


    def test_a_proposal_is_one_line_on_its_card_and_outdated_once_the_field_changes(self) -> None:
        cases = (
            self._a_proposal_is_one_line_on_its_card,
            self._a_field_changed_since_is_outdated,
            self._the_meaning_of_a_split_deck_goes_in_its_layer,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


class Applying(Base):
    def _applying_writes_the_field_and_closes_its_rivals(self) -> None:
        win, lose = self.p(), self.p(text="milk (cow's)", by=BOB)
        other = self.p(field="notes", now="Always plural.", text="Plural.")
        for p in (win, lose, other):
            self.propose(p)
        before = self.single.read_text(encoding="utf-8")
        applied = pr.apply(self.root, "zz", win.id)
        self.assertEqual(applied.outcome, "applied")
        self.assertEqual(applied.closed, [lose])
        after = self.single.read_text(encoding="utf-8")
        self.assertIn('    native: "cow\'s milk"\n', after)
        self.assertNotIn(win.id, after)
        self.assertNotIn(lose.id, after)
        self.assertIn(other.line(), after)
        self.assertEqual(self.errors(self.single), [])
        # Only the card's own lines changed.
        self.assertEqual(before.split('  - id: "zz-9202"')[1],
                         after.split('  - id: "zz-9202"')[1])


    def _a_layer_meaning_is_applied_in_the_layer(self) -> None:
        p = self.p(card="zz-9006", now="I", text="I (me)")
        self.propose(p, deck="zz-en-home")
        self.assertEqual(pr.apply(self.root, "zz", p.id).outcome, "applied")
        text = self.layer.read_text(encoding="utf-8")
        self.assertIn('  "zz-9006":\n    native: "I (me)"\n    notes:\n', text)
        self.assertEqual(self.errors(self.layer), [])

    def test_applying_writes_the_field_and_closes_its_rivals(self) -> None:
        cases = (
            self._applying_writes_the_field_and_closes_its_rivals,
            self._a_layer_meaning_is_applied_in_the_layer,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


class Validating(Base):
    def write(self, item: str, field_line: str = "") -> Path:
        text = SINGLE.replace('    notes: "Always plural."\n',
                              f'    notes: "Always plural."\n{field_line}'
                              f"    proposed:\n      {item}\n")
        self.single.write_text(text, encoding="utf-8")
        return self.single

    def _a_good_proposal_passes(self) -> None:
        self.assertEqual(self.errors(self.write(self.p().line())), [])


    def _bad_fields(self) -> None:
        cases = {
            self.p(field="pos", now="", text="noun"): "field must be one of",
            self.p(by="FL-0000-0000-1"): "by must be a rater code",
            self.p(accepted=(ALICE,)): "accepted names the proposer",
            self.p(accepted=(BOB, BOB)): "names a rater code twice",
        }
        for p, message in cases.items():
            with self.subTest(message=message):
                errors = self.errors(self.write(p.line()))
                self.assertTrue(any(message in e for e in errors), errors)


    def test_a_good_proposal_passes_and_a_bad_one_fails(self) -> None:
        cases = (
            self._a_good_proposal_passes,
            self._bad_fields,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


if __name__ == "__main__":
    unittest.main()
