#!/usr/bin/env python3
"""Card data (DECK-FORMAT.md, Card data): `bases: self`, synonyms and
antonyms (#513), confusables (#514), frequency and facts naming cards
(#516), and register, forms, collocations and senses (#517).

Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
PyYAML, like the validator itself.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_validate_b1 import CAT, CORE, EXTRA, LANGUAGE, LAYER, B1Case, card, single  # noqa: E402

FILLED = "validate_decks.FILLED_LANGUAGES"
HOUSE = "zz-9001"      # ఇల్లు (illu), a noun
SENTENCE = "zz-9002"   # నేను ఇంటికి వెళ్తాను. (nēnu iṇṭiki veḷtānu.), put in order


class Case(B1Case):

    def core(self, cid: str, **fields: object) -> None:
        self.edit(CORE, lambda d: card(d, cid).update(fields))

    def layer(self, cid: str, **fields: object) -> None:
        self.edit(LAYER, lambda d: d["cards"][cid].update(fields))

    def layer_errors(self) -> list[str]:
        return self.errors(LAYER)

    def warnings(self) -> list[str]:
        return self.section(self.run_main(), LAYER)


class OwnRoot(Case):

    def test_a_word_that_is_its_own_root(self) -> None:
        self.core(HOUSE, bases="self")
        self.assertNoError(CORE)
        self.assertNoError(LAYER)

    def test_only_self_besides_a_list(self) -> None:
        self.core(HOUSE, bases="itself")
        self.assertError(CORE, f"card {HOUSE}", 'bases must be a list of { word, ref } '
                         'or { word, base, reading }, or "self" for a word that is its '
                         'own root')

    def test_not_on_an_example(self) -> None:
        self.core(HOUSE, examples=[{"target": "ఇల్లు.", "reading": "illu.",
                                    "bases": "self"}])
        self.assertError(CORE, f"card {HOUSE}", "examples[0].bases must be a list of "
                                                "{ word, ref } or { word, base, reading }")

    def test_in_a_single_file_deck(self) -> None:
        self.put(EXTRA, single(cards=[dict(CAT, bases="self")]))
        self.assertNoError(EXTRA)


class WordItems(Case):
    """Synonyms and antonyms; collocations share their shape."""

    def test_a_card_or_a_word_with_its_reading_and_meaning(self) -> None:
        for key in ("synonyms", "antonyms", "collocations"):
            with self.subTest(key=key):
                self.setUp()
                self.core(HOUSE, **{key: [
                    {"id": "home", "ref": "zz-9004"},
                    {"id": "abode", "word": "నివాసం", "reading": "nivāsaṃ",
                     "source": "https://en.wiktionary.org/wiki/నివాసం"}]})
                self.assertNoError(CORE)
                self.layer(HOUSE, **{key: {"abode": "abode"}})
                self.assertNoError(LAYER)
                self.assertClean()

    def test_shape(self) -> None:
        self.core(HOUSE, synonyms=[
            {"id": "a", "ref": "zz-9004", "word": "x"},
            {"id": "a", "word": "నివాసం"},
            {"id": "Yes", "ref": HOUSE},
            {"id": "c", "ref": "zz-9004", "reading": "amma"},
            {"id": "d"},
            {"id": "e", "word": "నివాసం", "reading": "nivāsaṃ", "ipa": "x"}])
        errors = self.errors(CORE)
        w = f"card {HOUSE}"
        for msg in ("synonyms[0] gives word or ref, not both",
                    "synonyms[1].id 'a' is used twice",
                    "synonyms[1]: no reading, but script is 'telugu'; give the word's "
                    "reading",
                    "synonyms[2].id must start with a letter and match [a-z0-9-]+, and not "
                    "be a YAML 1.1 boolean word, got 'Yes'",
                    "synonyms[2].ref names the card itself",
                    "synonyms[3].reading is only for a word written in full",
                    "synonyms[4] needs word or ref",
                    "synonyms[5]: unknown field 'ipa'"):
            self.assertIn(f"{w}: {msg}", errors)

    def test_a_ref_names_a_card_of_the_language(self) -> None:
        self.core(HOUSE, antonyms=[{"id": "x", "ref": "zz-9999"}])
        self.assertAcross(f"{self.p(CORE)}: card {HOUSE}: antonyms[0].ref names card "
                          f"zz-9999, which no deck writes")

    def test_an_empty_list_is_left_out(self) -> None:
        self.core(HOUSE, synonyms=[])
        self.assertError(CORE, f"card {HOUSE}", "synonyms must be a non-empty list; "
                                                "leave it out when there is none")

    def test_never_an_error_when_absent(self) -> None:
        with mock.patch(FILLED, {"zz"}):
            self.assertNoError(CORE, "synonyms")

    def test_a_word_with_no_meaning_is_warned_of(self) -> None:
        self.core(HOUSE, synonyms=[{"id": "abode", "word": "నివాసం",
                                    "reading": "nivāsaṃ"}])
        self.assertIn("  warning cards.zz-9001: synonyms 'abode' has no meaning here",
                      self.warnings())

    def test_the_layer_names_core_items_only(self) -> None:
        self.core(HOUSE, synonyms=[{"id": "abode", "word": "నివాసం",
                                    "reading": "nivāsaṃ"}])
        self.layer(HOUSE, synonyms={"abode": "abode", "other": "x"})
        self.assertIn(f"cards.{HOUSE}.synonyms.other: the core card has no synonyms "
                      f"item 'other'", self.layer_errors())
        self.layer(HOUSE, synonyms={"abode": "abode"}, antonyms={"out": "outside"})
        self.assertIn(f"cards.{HOUSE}.antonyms.out: the core card has no antonyms item "
                      f"'out'", self.layer_errors())
        self.layer(HOUSE, synonyms={"abode": ["abode"]})
        self.assertIn(f"cards.{HOUSE}.synonyms.abode: must be non-empty text",
                      self.layer_errors())

    def test_a_collocation_may_give_a_note(self) -> None:
        self.core(HOUSE, collocations=[{"id": "go", "word": "వెళ్ళు", "reading": "veḷḷu"}])
        self.layer(HOUSE, collocations={"go": {"native": "to go", "note": "Home-ward."}})
        self.assertNoError(LAYER)
        self.layer(HOUSE, collocations={"go": {"native": "to go", "why": "x"}})
        self.assertIn(f"cards.{HOUSE}.collocations.go: unknown field 'why'",
                      self.layer_errors())

    def test_only_on_a_core_card(self) -> None:
        self.put(EXTRA, single(cards=[dict(CAT, synonyms=[{"id": "a", "ref": HOUSE}])]))
        self.assertError(EXTRA, "card zz-9501", "synonyms is written on a core card, its "
                                                "text in each layer (DECK-FORMAT.md, Card "
                                                "data)")


class Confusables(Case):

    def test_shape(self) -> None:
        self.core(HOUSE, confusables=[
            {"id": "form", "word": "ఇంటి", "reading": "iṇṭi", "kind": "form"},
            {"id": "mark", "word": "?", "kind": "mark"},
            {"id": "bad", "word": "ఇళ్ళు", "kind": "look"}])
        errors = self.errors(CORE)
        self.assertIn(f"card {HOUSE}: confusables[2].kind must be one of form, word, sound, "
                      f"mark, got 'look'", errors)
        self.assertIn(f"card {HOUSE}: confusables[2]: no reading, but script is 'telugu'; "
                      f"give the word's reading", errors)
        self.assertEqual(len(errors), 2)

    def test_a_missing_why_is_a_warning(self) -> None:
        self.core(HOUSE, confusables=[{"id": "form", "word": "ఇంటి", "reading": "iṇṭi",
                                       "kind": "form"}])
        self.assertIn("  warning cards.zz-9001: confusables 'form' has no why here",
                      self.warnings())
        self.layer(HOUSE, confusables={"form": {"why": "ఇంటి (iṇṭi) is the stem."}})
        self.assertNotIn("  warning cards.zz-9001: confusables 'form' has no why here",
                         self.warnings())
        self.layer(HOUSE, confusables={"form": "The stem."})
        self.assertIn(f"cards.{HOUSE}.confusables.form: must be {{ why: ... }}, why it is "
                      f"wrong", self.layer_errors())

    def test_two_to_three_on_a_sentence_put_in_order(self) -> None:
        one = [{"id": "a", "word": "ఇల్లు", "reading": "illu", "kind": "form"}]
        self.core(SENTENCE, confusables=one)
        self.assertError(CORE, f"card {SENTENCE}", "confusables: a sentence put in order "
                                                   "has 2 to 3, as wrong tiles; got 1")
        four = one + [{"id": k, "word": w, "reading": r, "kind": "word"}
                      for k, w, r in (("b", "నువ్వు", "nuvvu"), ("c", "వచ్చాను", "vaccānu"),
                                      ("d", "ఇంట్లో", "iṇṭlō"))]
        self.core(SENTENCE, confusables=four)
        self.assertError(CORE, f"card {SENTENCE}", "confusables: a sentence put in order "
                                                   "has 2 to 3, as wrong tiles; got 4")
        self.core(SENTENCE, confusables=four[:2])
        self.assertNoError(CORE, "confusables")

    def test_one_card_word_alone_is_not_put_in_order(self) -> None:
        self.core(HOUSE, confusables=[{"id": "a", "word": "ఇంటి", "reading": "iṇṭi",
                                       "kind": "form"}])
        self.assertNoError(CORE)

    def test_never_a_tile_the_answer_needs(self) -> None:
        self.core(SENTENCE, confusables=[
            {"id": "a", "word": "ఇంటికి", "reading": "iṇṭiki", "kind": "form"},
            {"id": "b", "word": ".", "kind": "mark"},
            {"id": "c", "ref": "zz-9006", "kind": "word"}])
        self.assertError(CORE, f"card {SENTENCE}", "confusables[0].word 'ఇంటికి' is a tile "
                                                   "the answer needs; a confusable is a "
                                                   "wrong tile")
        self.assertError(CORE, f"card {SENTENCE}", "confusables[1].word '.' is a tile the "
                                                   "answer needs; a confusable is a wrong "
                                                   "tile")
        self.assertAcross(f"{self.p(CORE)}: card {SENTENCE}: confusables[2].ref names "
                          f"zz-9006, 'నేను', a tile the answer needs; a confusable is a "
                          f"wrong tile")


class Frequency(Case):

    def test_a_rank_and_its_source(self) -> None:
        self.core(HOUSE, frequency={"rank": 120, "source": "te.wikipedia.org, 2026-10"})
        self.assertNoError(CORE)
        self.put(EXTRA, single(cards=[dict(CAT, frequency={"rank": 1, "source": "x"})]))
        self.assertNoError(EXTRA)

    def test_shape(self) -> None:
        w = f"card {HOUSE}"
        self.core(HOUSE, frequency=120)
        self.assertError(CORE, w, "frequency must be { rank, source }")
        self.core(HOUSE, frequency={"rank": 0, "count": 3})
        errors = self.errors(CORE)
        self.assertIn(f"{w}: frequency: unknown field 'count'", errors)
        self.assertIn(f"{w}: frequency.rank must be a whole number from 1, got 0", errors)
        self.assertIn(f"{w}: frequency.source is required: where the rank was counted",
                      errors)

    def test_a_layer_gives_none(self) -> None:
        self.layer(HOUSE, frequency={"rank": 1, "source": "x"})
        self.assertTrue(any("frequency" in e for e in self.layer_errors()))


class FactsNameCards(Case):

    FACTS = "zz-facts.yaml"

    def facts(self, cards: object) -> None:
        self.put(self.FACTS, {
            "schema": 1, "id": "zz-facts", "name": "Testlang facts", "kind": "facts",
            "language": dict(LANGUAGE), "license": "CC-BY-SA-4.0",
            "facts": [{"id": "zz-fact-001", "text": {"en": "A fact."}, "cards": cards}]})

    def test_cards_are_ids_of_the_language(self) -> None:
        self.facts([HOUSE, "zz-9004"])
        self.assertNoError(self.FACTS, "cards")
        self.assertNotAcross("names card", self.FACTS)

    def test_shape(self) -> None:
        self.facts([HOUSE, HOUSE, "hi-0001"])
        errors = self.errors(self.FACTS)
        self.assertIn(f"fact zz-fact-001: cards lists {HOUSE} twice", errors)
        self.assertIn("fact zz-fact-001: cards[2] must be the id of a zz card, got "
                      "'hi-0001'", errors)
        self.facts([])
        self.assertIn("fact zz-fact-001: cards must be a non-empty list of zz card ids",
                      self.errors(self.FACTS))

    def test_a_card_no_deck_writes(self) -> None:
        self.facts(["zz-9999"])
        self.assertAcross(f"{self.p(self.FACTS)}: fact zz-fact-001: cards[0] names card "
                          f"zz-9999, which no deck writes", self.FACTS)


class Register(Case):

    def test_one_of_five(self) -> None:
        for value in ("formal", "neutral", "informal", "slang", "offensive"):
            self.core(HOUSE, register=value)
            self.assertNoError(CORE)
        self.core(HOUSE, register="polite")
        self.assertError(CORE, f"card {HOUSE}", "register must be one of formal, neutral, "
                                                "informal, slang, offensive, got 'polite'")

    def test_a_layer_cannot_change_the_word(self) -> None:
        self.layer(HOUSE, register="formal")
        self.assertTrue(any("register" in e for e in self.layer_errors()))


class Forms(Case):

    PLURAL = {"id": "pl", "kind": "plural", "word": "ఇళ్ళు", "reading": "iḷḷu"}

    def test_a_form_with_its_reading(self) -> None:
        self.core(HOUSE, forms=[self.PLURAL])
        self.assertNoError(CORE)
        self.layer(HOUSE, forms={"pl": "More than one house."})
        self.assertClean()

    def test_shape(self) -> None:
        self.core(HOUSE, forms=[{"id": "a", "kind": "dual", "word": "ఇల్లు"},
                                {"id": "b", "kind": "plural", "ref": "zz-9004"}])
        errors = self.errors(CORE)
        w = f"card {HOUSE}"
        self.assertIn(f"{w}: forms[0].kind must be one of plural, oblique, oblique-plural, "
                      f"feminine, masculine, other, got 'dual'", errors)
        self.assertIn(f"{w}: forms[0].word is the card's own target", errors)
        self.assertIn(f"{w}: forms[0]: no reading, but script is 'telugu'; give the "
                      f"word's reading", errors)
        self.assertIn(f"{w}: forms[1]: unknown field 'ref'", errors)

    def test_a_form_of_kind_other_needs_its_label(self) -> None:
        self.core(HOUSE, forms=[dict(self.PLURAL, kind="other")])
        self.assertIn(f"cards.{HOUSE}.forms: 'pl' is a form of kind other: give its label "
                      f"here", self.layer_errors())
        self.layer(HOUSE, forms={"pl": "The plural."})
        self.assertNoError(LAYER)

    def test_a_form_a_rules_table_has_is_warned_of(self) -> None:
        self.core(HOUSE, forms=[{"id": "obl", "kind": "oblique", "word": "ఇంటికి",
                                 "reading": "iṇṭiki"}])
        lines = self.section(self.run_main(), CORE)
        self.assertIn(f"  warning card {HOUSE}: forms[0].word 'ఇంటికి' is a cell of "
                      f"{HOUSE}'s row in a rules table, the source of its forms", lines)


class Senses(Case):

    SENSES = [{"id": "house", "examples": [{"target": "ఇల్లు పెద్దది.",
                                            "reading": "illu peddadi."}]},
              {"id": "home", "pos": "noun"}]

    def test_senses_with_their_examples(self) -> None:
        self.core(HOUSE, senses=self.SENSES)
        self.assertNoError(CORE)
        self.layer(HOUSE, senses={
            "house": {"native": "house", "examples": {"ఇల్లు పెద్దది.": "The house is big."}},
            "home": {"native": "home"}})
        self.assertClean()

    def test_shape(self) -> None:
        self.core(HOUSE, senses=[{"id": "a", "pos": "thing",
                                  "examples": [{"target": "ఇల్లు."}]},
                                 {"id": "a", "native": "x"}])
        errors = self.errors(CORE)
        w = f"card {HOUSE}"
        self.assertIn(f"{w}: senses[0].pos must be one of ['adj', 'adv', 'noun', 'other', "
                      f"'particle', 'phrase', 'pronoun', 'verb'], got 'thing'", errors)
        self.assertIn(f"{w}: senses[0].examples[0]: no reading, but script is 'telugu'",
                      errors)
        self.assertIn(f"{w}: senses[1]: unknown field 'native'", errors)
        self.assertIn(f"{w}: senses[1].id 'a' is used twice", errors)

    def test_the_layer(self) -> None:
        self.core(HOUSE, senses=self.SENSES)
        self.layer(HOUSE, senses={"house": {"native": "home"}, "home": {"native": "home"},
                                  "other": {"native": "x"}})
        self.assertIn(f"cards.{HOUSE}.senses.other: the core card has no sense 'other'",
                      self.layer_errors())
        self.layer(HOUSE, senses={"house": {"native": "home"}, "home": {"native": "home"}})
        warnings = self.warnings()
        self.assertIn("  warning cards.zz-9001: senses 'house' and 'home' have the same "
                      "native", warnings)
        self.assertIn("  warning cards.zz-9001: example 'ఇల్లు పెద్దది.' has no translation "
                      "here, so it is not shown", warnings)
        self.layer(HOUSE, senses={"house": {"native": "house", "examples": {"x": "y"}}})
        self.assertIn(f"cards.{HOUSE}.senses.house.examples.x: the core card has no "
                      f"example with this target", self.layer_errors())

    def test_a_sense_with_no_native(self) -> None:
        self.core(HOUSE, senses=self.SENSES)
        self.assertIn("  warning cards.zz-9001: sense 'home' has no native here",
                      self.warnings())
        with mock.patch(FILLED, {"zz"}):
            self.assertIn(f"cards.{HOUSE}.senses: sense 'home' has no native here; zz is "
                          f"filled in", self.layer_errors())


if __name__ == "__main__":
    unittest.main()
