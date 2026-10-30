#!/usr/bin/env python3
"""A reviewer's gender, register, hears and warning (#508): the review file,
the review bot and tools/proposals.py. The bot writes these four, each only
with a value the field may have (docs/DECK-FORMAT.md); the lists, the facts
and the flags stay with the owner.

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
import validate_decks as vd  # noqa: E402
from test_proposals import ALICE, BOB, SINGLE, TOOLS  # noqa: E402

LANG = 'language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }'

# A core with a card that warns of a word it sounds like and one with
# other meanings, and a card that is neither.
SCALARS = f"""\
schema: 1
id: "zz-scalars"
part: "core"
kind: "vocab"
{LANG}
license: "CC-BY-SA-4.0"
tags: ["unreviewed"]
cards:
  - id: "zz-9301"
    target: "పాలు"
    reading: "pālu"
    pos: "noun"
    gender: "m"
    notes:
      - {{ id: "sound", kind: "pair", ref: "zz-9302" }}
      - {{ id: "why", kind: "usage" }}
  - id: "zz-9302"
    target: "పాల"
    reading: "pāla"
    pos: "noun"
    senses:
      - {{ id: "s1" }}
"""


def suggestion(part: str, now: str, text: str, **more: object) -> dict:
    """A suggestion as the app writes it in the review file
    (lib/core/review/deck_review.dart, Suggestion.toJson)."""
    return {"part": part, "now": now, "text": text, **more}


class Scalars(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        shutil.copytree(TOOLS / "fixtures" / "b1" / "zz", self.root / "decks" / "zz")
        zz = self.root / "decks" / "zz"
        self.core = zz / "zz-scalars.yaml"
        self.core.write_text(SCALARS, encoding="utf-8")
        self.single = zz / "zz-en-extra.yaml"
        self.single.write_text(SINGLE, encoding="utf-8")
        self.path = zz / "zz-path.yaml"
        text = self.path.read_text(encoding="utf-8")
        self.path.write_text(text.replace(
            'language: "zz"\n', 'language: "zz"\ngenders: ["m", "f"]\n', 1), encoding="utf-8")

    def propose(self, part: str, now: str, text: str, card: str = "zz-9301",
                deck: str = "zz-scalars", by: str = ALICE) -> pr.Proposed:
        facts = rb.suggestion_facts(suggestion(part, now, text))
        assert facts is not None, part
        result = pr.Proposed()
        pr.propose(self.root, pr.Suggestion("zz", deck, pr.Proposal(
            card, *facts, by, "2026-10-30")), result)
        return result

    def applied(self, result: pr.Proposed) -> str:
        self.assertEqual(len(result.added), 1, result)
        return pr.apply(self.root, "zz", result.added[0].id).outcome

    def text(self) -> str:
        return self.core.read_text(encoding="utf-8")

    def test_the_review_file_reads_the_four_scalars_and_leaves_flags(self) -> None:
        for part in ("gender", "register", "hears", "warning"):
            self.assertEqual(rb.suggestion_facts(suggestion(part, "", "x")), (part, "", "x"))
        # A flag offers no text, and an item of a list is the owner's.
        self.assertIsNone(rb.suggestion_facts(suggestion("gender", "", "", flag=True)))
        self.assertIsNone(rb.suggestion_facts(
            suggestion("synonyms", "", "x", word="new-1", action="add")))
        # The text is trimmed, as for any other field.
        self.assertEqual(rb.suggestion_facts(suggestion("register", "", " slang ")),
                         ("register", "", "slang"))

    def test_a_gender_is_one_of_the_languages_classes(self) -> None:
        good = self.propose("gender", "m", "f")
        self.assertEqual(self.applied(good), "applied")
        self.assertIn('    gender: "f"\n', self.text())
        self.assertNotIn('gender: "m"', self.text())
        self.assertEqual(vd.validate(self.path).errors, [])
        # Not a class of this language: never written.
        bad = self.propose("gender", "f", "n")
        self.assertEqual((len(bad.added), len(bad.unsupported)), (0, 1))
        self.assertNotIn('"n"', self.text())

    def test_a_language_without_gender_takes_no_gender(self) -> None:
        text = self.path.read_text(encoding="utf-8")
        self.path.write_text(text.replace('genders: ["m", "f"]', "genders: []"),
                             encoding="utf-8")
        result = self.propose("gender", "m", "f")
        self.assertEqual((len(result.added), len(result.unsupported)), (0, 1))

    def test_a_gender_on_a_card_without_one_is_added(self) -> None:
        result = self.propose("gender", "", "f", card="zz-9302")
        self.assertEqual(self.applied(result), "applied")
        entry = [e for e in pr.entries(self.root, "zz", "zz-9302")][0]
        self.assertEqual(entry.data["gender"], "f")

    def test_a_register_is_one_of_the_five(self) -> None:
        for value in vd.REGISTERS:
            fresh = type(self)(self._testMethodName)
            fresh.setUp()
            try:
                self.assertEqual(fresh.applied(fresh.propose("register", "", value)),
                                 "applied", value)
                self.assertIn(f'    register: "{value}"\n', fresh.text())
            finally:
                fresh.doCleanups()
        rude = self.propose("register", "", "rude")
        self.assertEqual((len(rude.added), len(rude.unsupported)), (0, 1))
        self.assertNotIn("register", self.text())

    def test_hears_is_only_form(self) -> None:
        self.assertEqual(self.applied(self.propose("hears", "", "form")), "applied")
        self.assertIn('    hears: "form"\n', self.text())
        other = self.propose("hears", "form", "spelling")
        self.assertEqual((len(other.added), len(other.unsupported)), (0, 1))

    def test_a_warning_names_one_the_card_has(self) -> None:
        # Its own pair note, by id; a note that is no warning is not one.
        for bad in ("why", "nowhere", "senses"):
            result = self.propose("warning", "", bad)
            self.assertEqual((len(result.added), len(result.unsupported)), (0, 1), bad)
        self.assertEqual(self.applied(self.propose("warning", "", "sound")), "applied")
        self.assertIn('    warning: "sound"\n', self.text())
        self.assertNotIn("proposed", self.text())
        # A card with other meanings may pick them; "none" is always a choice.
        self.assertEqual(
            self.applied(self.propose("warning", "", "senses", card="zz-9302")), "applied")
        self.assertEqual(
            self.applied(self.propose("warning", "sound", "none")), "applied")
        self.assertIn('    warning: "none"\n', self.text())

    def test_a_warning_is_a_core_cards_only(self) -> None:
        # A card a single-file deck writes has no warning: the proposal has
        # no home, as one on a field the card cannot have.
        result = self.propose("warning", "", "none", card="zz-9201", deck="zz-en-extra")
        self.assertEqual((len(result.added), len(result.outdated)), (0, 1))

    def test_a_scalar_on_a_single_file_card_is_written_there(self) -> None:
        result = self.propose("register", "", "informal", card="zz-9201", deck="zz-en-extra")
        self.assertEqual(self.applied(result), "applied")
        self.assertIn('    register: "informal"\n', self.single.read_text(encoding="utf-8"))
        self.assertEqual(vd.validate(self.single).errors, [])

    def test_a_scalar_changed_since_is_outdated(self) -> None:
        result = self.propose("gender", "f", "m")
        self.assertEqual((len(result.added), len(result.outdated)), (0, 1))

    def test_a_proposal_whose_note_is_gone_is_not_applied(self) -> None:
        added = self.propose("warning", "", "sound")
        self.core.write_text(self.text().replace(
            '      - { id: "sound", kind: "pair", ref: "zz-9302" }\n', ""), encoding="utf-8")
        self.assertEqual(pr.apply(self.root, "zz", added.added[0].id).outcome, "unsupported")
        self.assertNotIn("warning:", self.text().replace("proposed:", ""))

    def test_the_validator_checks_the_value_of_a_proposal(self) -> None:
        def errors(field: str, now: str, text: str) -> list[str]:
            p = pr.Proposal("zz-9301", field, now, text, ALICE, "2026-10-30")
            self.core.write_text(SCALARS.replace(
                '    gender: "m"\n', f'    gender: "m"\n    proposed:\n      {p.line()}\n'),
                encoding="utf-8")
            return vd.validate(self.core).errors
        self.assertEqual(errors("register", "", "slang"), [])
        self.assertEqual(errors("hears", "", "form"), [])
        for field, text in (("register", "rude"), ("hears", "spelling")):
            found = errors(field, "", text)
            self.assertTrue(any(f"proposal on {field} must be one of" in e for e in found), found)

    def test_a_scalar_proposal_is_agreed_by_other_reviewers_like_any_other(self) -> None:
        added = self.propose("register", "", "formal").added[0]
        result = pr.Proposed()
        pr.accept(self.root, "zz", added.id, BOB, "formal", result)
        self.assertEqual(result.accepted, [(added.id, BOB)])
        found = pr.find(self.root, "zz", added.id)
        assert found is not None
        self.assertEqual(found[1].accepted, (BOB,))
        # Not the same text, not accepted.
        again = pr.Proposed()
        pr.accept(self.root, "zz", added.id, "FL-1111-1111-1", "informal", again)
        self.assertEqual(again.not_accepted, 1)


if __name__ == "__main__":
    unittest.main()
