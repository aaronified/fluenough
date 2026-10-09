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
license: "CC0-1.0"
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


class Codes(unittest.TestCase):
    def test_the_two_codes_used_here_are_good(self) -> None:
        from rater_codes import rater_code
        self.assertEqual(rater_code(ALICE), ALICE)
        self.assertEqual(code("00000000"), BOB)
        self.assertEqual(rater_code(BOB), BOB)


class Writing(Base):
    def test_a_proposal_is_one_line_on_its_card(self) -> None:
        before = self.single.read_text(encoding="utf-8")
        p = self.p(why="It is cow's milk here.")
        result = self.propose(p)
        self.assertEqual(result.added, [p])
        after = self.single.read_text(encoding="utf-8")
        self.assertIn(f'    proposed:\n      {p.line()}\n\n  - id: "zz-9202"', after)
        # Only the two new lines: nothing else in the file changed.
        self.assertEqual(after.replace(f"    proposed:\n      {p.line()}\n", ""), before)
        self.assertEqual(self.errors(self.single), [])

    def test_the_id_is_the_facts(self) -> None:
        p = self.p()
        self.assertRegex(p.id, r"^[0-9a-f]{10}$")
        self.assertEqual(p.id, self.p().id)
        self.assertNotEqual(p.id, self.p(by=BOB).id)
        self.assertNotEqual(p.id, self.p(text="milk!").id)

    def test_the_same_proposal_twice_is_written_once(self) -> None:
        self.propose(self.p())
        again = self.propose(self.p())
        self.assertEqual(again.already, [self.p()])
        self.assertEqual(self.single.read_text(encoding="utf-8").count("proposed:"), 1)

    def test_a_second_proposal_joins_the_list(self) -> None:
        self.propose(self.p())
        self.propose(self.p(text="milk (of a cow)", by=BOB))
        entry = [e for e in pr.entries(self.root, "zz", "zz-9201")][0]
        self.assertEqual([p.by for p in entry.proposals()], [ALICE, BOB])
        self.assertEqual(self.errors(self.single), [])

    def test_a_field_changed_since_is_outdated(self) -> None:
        result = self.propose(self.p(now="mlik"))
        self.assertEqual(result.added, [])
        self.assertEqual(len(result.outdated), 1)
        self.assertNotIn("proposed", self.single.read_text(encoding="utf-8"))

    def test_a_card_gone_is_outdated(self) -> None:
        result = self.propose(self.p(card="zz-9999"))
        self.assertEqual(len(result.outdated), 1)

    def test_the_meaning_of_a_split_deck_goes_in_its_layer(self) -> None:
        p = self.p(card="zz-9004", now="mother", text="mum")
        self.assertEqual(self.propose(p, deck="zz-en-home").added, [p])
        self.assertIn("proposed:", self.layer.read_text(encoding="utf-8"))
        self.assertEqual(self.errors(self.layer), [])

    def test_the_word_of_a_split_deck_goes_in_its_core(self) -> None:
        p = self.p(card="zz-9004", field="target", now="అమ్మ", text="అమ్మా")
        self.assertEqual(self.propose(p, deck="zz-en-home").added, [p])
        self.assertIn(p.line(), self.core.read_text(encoding="utf-8"))
        self.assertEqual(self.errors(self.core), [])

    def test_a_ref_without_a_meaning_takes_the_written_cards(self) -> None:
        # zz-9001's meaning in zz-en-extra is the ref's own; in zz-en-home,
        # the layer's.
        p = self.p(card="zz-9001", now="home; house", text="home")
        self.assertEqual(self.propose(p, deck="zz-en-extra").added, [p])
        self.assertIn(p.line(), self.layer.read_text(encoding="utf-8"))
        q = self.p(card="zz-9001", now="house", text="a house")
        self.assertEqual(self.propose(q, deck="zz-en-extra").added, [q])
        self.assertIn(q.line(), self.single.read_text(encoding="utf-8"))

    def test_a_card_in_flow_style_is_left_for_the_owner(self) -> None:
        p = self.p(card="zz-9101", field="target", now="అమ్మ 1!", text="అమ్మ!")
        before = self.core.read_text(encoding="utf-8")
        result = self.propose(p, deck="zz-en-home")
        self.assertEqual(result.unsupported, [p])
        self.assertEqual(self.core.read_text(encoding="utf-8"), before)

    def test_typed_notes_are_left_for_the_owner(self) -> None:
        p = self.p(card="zz-9004", field="notes", now="x", text="y")
        self.assertEqual(len(self.propose(p, deck="zz-en-home").outdated), 1)

    def test_a_plain_note_can_be_proposed(self) -> None:
        p = self.p(field="notes", now="Always plural.", text="Plural in Telugu.")
        self.assertEqual(self.propose(p).added, [p])

    def test_a_reading_the_card_lacks_can_be_added(self) -> None:
        p = self.p(card="zz-9202", field="reading", now="", text="nīḷḷu")
        self.assertEqual(self.propose(p).added, [p])
        applied = pr.apply(self.root, "zz", p.id)
        self.assertEqual(applied.outcome, "applied")
        text = self.single.read_text(encoding="utf-8")
        self.assertIn('    target: "నీళ్ళు"\n    reading: "nīḷḷu"\n    native: "water"\n',
                      text)
        self.assertEqual(self.errors(self.single), [])


class Agreeing(Base):
    def test_an_acceptance_is_recorded_on_the_proposal(self) -> None:
        p = self.p()
        self.propose(p)
        result = pr.Proposed()
        pr.accept(self.root, "zz", p.id, BOB, p.text, result)
        self.assertEqual(result.accepted, [(p.id, BOB)])
        _, found = pr.find(self.root, "zz", p.id)
        self.assertEqual(found.accepted, (BOB,))
        self.assertEqual(self.errors(self.single), [])

    def test_not_by_the_proposer_twice_or_of_other_text(self) -> None:
        p = self.p()
        self.propose(p)
        result = pr.Proposed()
        pr.accept(self.root, "zz", p.id, ALICE, p.text, result)
        pr.accept(self.root, "zz", p.id, BOB, "other", result)
        pr.accept(self.root, "zz", p.id, BOB, p.text, result)
        pr.accept(self.root, "zz", p.id, BOB, p.text, result)
        pr.accept(self.root, "zz", "0123456789", BOB, p.text, result)
        self.assertEqual(result.accepted, [(p.id, BOB)])
        self.assertEqual(result.not_accepted, 4)


class Applying(Base):
    def test_applying_writes_the_field_and_closes_its_rivals(self) -> None:
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

    def test_a_field_changed_since_is_not_written(self) -> None:
        p = self.p()
        self.propose(p)
        text = self.single.read_text(encoding="utf-8")
        self.single.write_text(text.replace('native: "milk"', 'native: "fresh milk"'),
                               encoding="utf-8")
        self.assertEqual(pr.apply(self.root, "zz", p.id).outcome, "outdated")
        self.assertIn('native: "fresh milk"', self.single.read_text(encoding="utf-8"))
        self.assertEqual([q for _, q in pr.outdated(self.root, "zz")], [p])
        self.assertEqual(pr.close(self.root, "zz", [p.id]), [p])
        self.assertNotIn("proposed", self.single.read_text(encoding="utf-8"))

    def test_a_proposal_gone_is_missing(self) -> None:
        self.assertEqual(pr.apply(self.root, "zz", "0123456789").outcome, "missing")

    def test_a_layer_meaning_is_applied_in_the_layer(self) -> None:
        p = self.p(card="zz-9006", now="I", text="I (me)")
        self.propose(p, deck="zz-en-home")
        self.assertEqual(pr.apply(self.root, "zz", p.id).outcome, "applied")
        text = self.layer.read_text(encoding="utf-8")
        self.assertIn('  "zz-9006":\n    native: "I (me)"\n    notes:\n', text)
        self.assertEqual(self.errors(self.layer), [])


class Validating(Base):
    def write(self, item: str, field_line: str = "") -> Path:
        text = SINGLE.replace('    notes: "Always plural."\n',
                              f'    notes: "Always plural."\n{field_line}'
                              f"    proposed:\n      {item}\n")
        self.single.write_text(text, encoding="utf-8")
        return self.single

    def test_a_good_proposal_passes(self) -> None:
        self.assertEqual(self.errors(self.write(self.p().line())), [])

    def test_its_text_is_not_deck_content(self) -> None:
        # Script without its reading is an error in deck prose, not here.
        p = self.p(text="పాలు", why="పాలు")
        self.assertEqual(self.errors(self.write(p.line())), [])

    def test_an_id_that_is_not_its_facts(self) -> None:
        line = self.p().line().replace(self.p().id, "0123456789")
        self.assertTrue(any("id is not its facts" in e
                            for e in self.errors(self.write(line))))

    def test_bad_fields(self) -> None:
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

    def test_a_bad_date_and_a_missing_fact(self) -> None:
        bad = self.p().line().replace('"2026-10-09"', '"2026-13-09"')
        self.assertTrue(any("date must be" in e for e in self.errors(self.write(bad))))
        missing = '- { id: "0123456789", field: "native" }'
        self.assertTrue(any("missing now, text, by, date" in e
                            for e in self.errors(self.write(missing))))

    def test_text_the_same_as_now(self) -> None:
        p = self.p(text="milk")
        self.assertTrue(any("what the field said already" in e
                            for e in self.errors(self.write(p.line()))))

    def test_an_unknown_key_and_proposed_elsewhere(self) -> None:
        line = self.p().line().replace(" }", ', votes: 3 }')
        self.assertTrue(any("unknown field 'votes'" in e
                            for e in self.errors(self.write(line))))
        text = SINGLE.replace("cards:\n", "proposed: []\ncards:\n")
        self.single.write_text(text, encoding="utf-8")
        self.assertTrue(any("unknown field 'proposed'" in e
                            for e in self.errors(self.single)))

    def test_an_outdated_proposal_is_an_info_line(self) -> None:
        p = self.p(now="milk!", text="cow's milk")
        rep = vd.validate(self.write(p.line()))
        self.assertEqual(rep.errors, [])
        self.assertTrue(any("is outdated" in i for i in rep.infos))

    def test_a_core_card_proposes_no_meaning(self) -> None:
        text = self.core.read_text(encoding="utf-8")
        p = self.p(card="zz-9004", now="mother", text="mum")
        text = text.replace('''      - { id: "address", kind: "usage" }
''', f'''      - {{ id: "address", kind: "usage" }}
    proposed:
      {p.line()}
''')
        self.core.write_text(text, encoding="utf-8")
        self.assertTrue(any("field must be one of target, reading, ipa, notes" in e
                            for e in self.errors(self.core)))

    def test_the_index_counts_proposals(self) -> None:
        self.propose(self.p())
        self.propose(self.p(text="cow milk"))
        self.assertEqual(vd.proposal_count(self.single), 2)
        self.assertEqual(vd.proposal_count(self.core), 0)


if __name__ == "__main__":
    unittest.main()
