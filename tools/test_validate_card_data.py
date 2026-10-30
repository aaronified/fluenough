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
import validate_decks  # noqa: E402
from test_validate_b1 import CAT, CORE, EXTRA, LAYER, B1Case, card, single  # noqa: E402
from test_validate_b1 import CAT, CORE, EXTRA, LAYER, PATH, B1Case, card, single  # noqa: E402
import shutil
import tempfile
import unicodedata
import validate_decks
from test_validate_b1 import CAT, CORE, EXTRA, B1Case, card, single  # noqa: E402
from test_validate_decks import VOCAB, Validated
import contextlib
import io
from test_validate_b1 import CORE, EXTRA, LANGUAGE, LAYER, B1Case, card, single  # noqa: E402
import validate_decks as vd  # noqa: E402

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


class ScriptPos(Case):

    def test_a_card_may_be_a_letter_or_a_digit_but_a_sense_may_not(self) -> None:
        for pos in ("letter", "digit"):
            with self.subTest(pos):
                self.core(HOUSE, pos=pos)
                self.assertNoError(CORE)
        self.core(HOUSE, pos="thing")
        self.assertError(CORE, f"card {HOUSE}", "pos must be one of ['adj', 'adv', 'digit', "
                         "'letter', 'noun', 'other', 'particle', 'phrase', 'pronoun', "
                         "'verb'], got 'thing'")
        self.core(HOUSE, pos="noun", senses=[{"id": "a", "pos": "letter"}])
        self.assertIn("senses[0].pos must be one of", "\n".join(self.errors(CORE)))

    def test_hears_is_form_or_left_out(self) -> None:
        self.core(HOUSE, hears="form")
        self.assertNoError(CORE)
        self.core(HOUSE, hears="meaning")
        self.assertError(CORE, f"card {HOUSE}", 'hears must be "form", or left out; '
                         "got 'meaning'")


class OwnRoot(Case):

    def _a_word_that_is_its_own_root(self) -> None:
        self.core(HOUSE, bases="self")
        self.assertNoError(CORE)
        self.assertNoError(LAYER)

    def _only_self_besides_a_list(self) -> None:
        self.core(HOUSE, bases="itself")
        self.assertError(CORE, f"card {HOUSE}", 'bases must be a list of { word, ref } '
                         'or { word, base, reading }, or "self" for a word that is its '
                         'own root')

    def _not_on_an_example(self) -> None:
        self.core(HOUSE, examples=[{"target": "ఇల్లు.", "reading": "illu.",
                                    "bases": "self"}])
        self.assertError(CORE, f"card {HOUSE}", "examples[0].bases must be a list of "
                                                "{ word, ref } or { word, base, reading }")

    def _in_a_single_file_deck(self) -> None:
        self.put(EXTRA, single(cards=[dict(CAT, bases="self")]))
        self.assertNoError(EXTRA)

    def _a_card_or_a_word_with_its_reading_and_meaning(self) -> None:
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

    def _shape(self) -> None:
        self.core(HOUSE, synonyms=[
            {"id": "a", "ref": "zz-9004", "word": "x"},
            {"id": "a", "word": "నివాసం"},
            {"id": "Yes", "ref": HOUSE},
            {"id": "c", "ref": "zz-9004", "reading": "amma"},
            {"id": "d"},
            {"id": "e", "word": "నివాసం", "reading": "nivāsaṃ", "gloss": "x"},
            {"id": "f", "ref": "zz-9004", "ipa": "amma"}])
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
                    "synonyms[5]: unknown field 'gloss'",
                    "synonyms[6].ipa is only for a word written in full"):
            self.assertIn(f"{w}: {msg}", errors)

    def _every_item_may_take_ipa_and_source(self) -> None:
        # Owner, 2026-10-15 (#506): "Yes, all items may take ipa and source".
        word = {"id": "w", "word": "ఇంటి", "reading": "iṇṭi", "ipa": "iɳʈi",
                "source": "https://en.wiktionary.org/wiki/ఇంటి"}
        for key, extra in (("synonyms", {}), ("antonyms", {}), ("collocations", {}),
                           ("confusables", {"kind": "form"}), ("forms", {"kind": "other"})):
            with self.subTest(key=key):
                self.setUp()
                self.core(HOUSE, **{key: [dict(word, **extra)]})
                self.assertNoError(CORE)
        self.setUp()
        self.core(HOUSE, confusables=[{"id": "r", "ref": "zz-9004", "kind": "word",
                                       "source": "Wiktionary"}])
        self.assertNoError(CORE)

    def _a_ref_names_a_card_of_the_language(self) -> None:
        self.core(HOUSE, antonyms=[{"id": "x", "ref": "zz-9999"}])
        self.assertAcross(f"{self.p(CORE)}: card {HOUSE}: antonyms[0].ref names card "
                          f"zz-9999, which no deck writes")

    def _an_empty_list_is_left_out(self) -> None:
        self.core(HOUSE, synonyms=[])
        self.assertError(CORE, f"card {HOUSE}", "synonyms must be a non-empty list; "
                                                "leave it out when there is none")

    def _never_an_error_when_absent(self) -> None:
        with mock.patch(FILLED, {"zz"}):
            self.assertNoError(CORE, "synonyms")

    def _a_word_with_no_meaning_is_warned_of(self) -> None:
        self.core(HOUSE, synonyms=[{"id": "abode", "word": "నివాసం",
                                    "reading": "nivāsaṃ"}])
        self.assertIn("  warning cards.zz-9001: synonyms 'abode' has no meaning here",
                      self.warnings())

    def _the_layer_names_core_items_only(self) -> None:
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

    def _a_collocation_may_give_a_note(self) -> None:
        self.core(HOUSE, collocations=[{"id": "go", "word": "వెళ్ళు", "reading": "veḷḷu"}])
        self.layer(HOUSE, collocations={"go": {"native": "to go", "note": "Home-ward."}})
        self.assertNoError(LAYER)
        self.layer(HOUSE, collocations={"go": {"native": "to go", "why": "x"}})
        self.assertIn(f"cards.{HOUSE}.collocations.go: unknown field 'why'",
                      self.layer_errors())

    def _only_on_a_core_card(self) -> None:
        self.put(EXTRA, single(cards=[dict(CAT, synonyms=[{"id": "a", "ref": HOUSE}])]))
        self.assertError(EXTRA, "card zz-9501", "synonyms is written on a core card, its "
                                                "text in each layer (DECK-FORMAT.md, Card "
                                                "data)")

    def test_a_card_has_its_own_root_and_word_items(self) -> None:
        cases = (
            self._a_word_that_is_its_own_root,
            self._only_self_besides_a_list,
            self._not_on_an_example,
            self._in_a_single_file_deck,
            self._a_card_or_a_word_with_its_reading_and_meaning,
            self._shape,
            self._every_item_may_take_ipa_and_source,
            self._a_ref_names_a_card_of_the_language,
            self._an_empty_list_is_left_out,
            self._never_an_error_when_absent,
            self._a_word_with_no_meaning_is_warned_of,
            self._the_layer_names_core_items_only,
            self._a_collocation_may_give_a_note,
            self._only_on_a_core_card,
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


class Confusables(Case):

    def _shape(self) -> None:
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

    def _a_missing_why_is_a_warning(self) -> None:
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

    def _two_to_three_on_a_sentence_put_in_order(self) -> None:
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

    def _one_card_word_alone_is_not_put_in_order(self) -> None:
        self.core(HOUSE, confusables=[{"id": "a", "word": "ఇంటి", "reading": "iṇṭi",
                                       "kind": "form"}])
        self.assertNoError(CORE)

    def _never_a_tile_the_answer_needs(self) -> None:
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

    def test_confusables_are_never_a_tile_the_answer_needs(self) -> None:
        cases = (
            self._shape,
            self._a_missing_why_is_a_warning,
            self._two_to_three_on_a_sentence_put_in_order,
            self._one_card_word_alone_is_not_put_in_order,
            self._never_a_tile_the_answer_needs,
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


class FactsNameCards(Case):

    FACTS = "zz-facts.yaml"

    def facts(self, cards: object) -> None:
        self.put(self.FACTS, {
            "schema": 1, "id": "zz-facts", "name": "Testlang facts", "kind": "facts",
            "language": dict(LANGUAGE), "license": "CC-BY-SA-4.0",
            "facts": [{"id": "zz-fact-001", "text": {"en": "A fact."}, "cards": cards}]})

    def _cards_are_ids_of_the_language(self) -> None:
        self.facts([HOUSE, "zz-9004"])
        self.assertNoError(self.FACTS, "cards")
        self.assertNotAcross("names card", self.FACTS)

    def _shape(self) -> None:
        self.facts([HOUSE, HOUSE, "hi-0001"])
        errors = self.errors(self.FACTS)
        self.assertIn(f"fact zz-fact-001: cards lists {HOUSE} twice", errors)
        self.assertIn("fact zz-fact-001: cards[2] must be the id of a zz card, got "
                      "'hi-0001'", errors)
        self.facts([])
        self.assertIn("fact zz-fact-001: cards must be a non-empty list of zz card ids",
                      self.errors(self.FACTS))

    def _a_card_no_deck_writes(self) -> None:
        self.facts(["zz-9999"])
        self.assertAcross(f"{self.p(self.FACTS)}: fact zz-fact-001: cards[0] names card "
                          f"zz-9999, which no deck writes", self.FACTS)

    SITUATIONS = "zz-situations.yaml"

    def situations(self, *sheets: dict) -> None:
        self.put(self.SITUATIONS, {
            "schema": 1, "id": "zz-situations", "name": "Testlang situations",
            "kind": "situations", "language": dict(LANGUAGE), "license": "CC-BY-SA-4.0",
            "situations": list(sheets)})

    def _a_situation_lists_real_cards(self) -> None:
        taxi = {"id": "taxi", "icon": "taxi", "title": {"en": "Taxi"},
                "phrases": [HOUSE], "words": ["zz-9004"]}
        self.situations(taxi)
        self.assertNoError(self.SITUATIONS, "situation taxi")
        self.assertNotAcross("names card", self.SITUATIONS)
        self.situations(dict(taxi, words=["zz-9999"]))
        self.assertAcross(f"{self.p(self.SITUATIONS)}: situation taxi: words[0] names "
                          f"card zz-9999, which no deck writes", self.SITUATIONS)

    def _a_situation_has_its_shape(self) -> None:
        taxi = {"id": "taxi", "icon": "taxi", "title": {"en": "Taxi"}, "phrases": [HOUSE]}
        self.situations(taxi, dict(taxi, id="cab"),
                        {"id": "eat", "icon": "eat", "title": {"bn": "x"}})
        errors = self.errors(self.SITUATIONS)
        self.assertIn("situation cab: icon 'taxi' is on another situation: each button "
                      "has its own", errors)
        self.assertIn("situation eat: title needs an English entry", errors)
        self.assertIn("situation eat: lists no cards: give phrases, words or both", errors)

    def _an_icon_is_one_of_the_six(self) -> None:
        taxi = {"id": "taxi", "icon": "taxi", "title": {"en": "Taxi"}, "phrases": [HOUSE]}
        self.situations(dict(taxi, icon="boat"))
        self.assertTrue(any("icon must be one of" in e
                            for e in self.errors(self.SITUATIONS)))

    def _a_situations_file_is_one_per_language_and_named_so(self) -> None:
        taxi = {"id": "taxi", "icon": "taxi", "title": {"en": "Taxi"}, "phrases": [HOUSE]}
        self.situations(taxi)
        self.assertNoError(self.SITUATIONS, "situations file is")
        self.put("zz-sheets.yaml", {
            "schema": 1, "id": "zz-sheets", "name": "Testlang situations",
            "kind": "situations", "language": dict(LANGUAGE), "license": "CC-BY-SA-4.0",
            "situations": [taxi]})
        self.assertTrue(any("a situations file is zz-situations.yaml" in e
                            for e in self.errors("zz-sheets.yaml")))
        self.put("other/zz-situations.yaml", {
            "schema": 1, "id": "zz-situations", "name": "Testlang situations",
            "kind": "situations", "language": dict(LANGUAGE), "license": "CC-BY-SA-4.0",
            "situations": [taxi]})
        self.assertTrue(any("more than one situations file for zz" in line
                            for line in self.run_main(self.SITUATIONS,
                                                      "other/zz-situations.yaml")))

    def _a_situations_key_belongs_to_a_situations_file(self) -> None:
        self.core(HOUSE)
        self.edit(CORE, lambda d: d.__setitem__("situations", []))
        self.assertError(CORE, "situations",
                         "only valid on a situations file; add kind: situations")

    def _a_rank_and_its_source(self) -> None:
        self.core(HOUSE, frequency={"rank": 120, "source": "te.wikipedia.org, 2026-10"})
        self.assertNoError(CORE)
        self.put(EXTRA, single(cards=[dict(CAT, frequency={"rank": 1, "source": "x"})]))
        self.assertNoError(EXTRA)

    def _frequency_shape(self) -> None:
        w = f"card {HOUSE}"
        self.core(HOUSE, frequency=120)
        self.assertError(CORE, w, "frequency must be { rank, source }")
        self.core(HOUSE, frequency={"rank": 0, "count": 3})
        errors = self.errors(CORE)
        self.assertIn(f"{w}: frequency: unknown field 'count'", errors)
        self.assertIn(f"{w}: frequency.rank must be a whole number from 1, got 0", errors)
        self.assertIn(f"{w}: frequency.source is required: where the rank was counted",
                      errors)

    def _a_layer_gives_none(self) -> None:
        self.layer(HOUSE, frequency={"rank": 1, "source": "x"})
        self.assertTrue(any("frequency" in e for e in self.layer_errors()))

    def _one_of_five(self) -> None:
        for value in ("formal", "neutral", "informal", "slang", "offensive"):
            self.core(HOUSE, register=value)
            self.assertNoError(CORE)
        self.core(HOUSE, register="polite")
        self.assertError(CORE, f"card {HOUSE}", "register must be one of formal, neutral, "
                                                "informal, slang, offensive, got 'polite'")

    def _a_layer_cannot_change_the_word(self) -> None:
        self.layer(HOUSE, register="formal")
        self.assertTrue(any("register" in e for e in self.layer_errors()))

    def test_frequency_register_and_facts_naming_cards(self) -> None:
        cases = (
            self._cards_are_ids_of_the_language,
            self._shape,
            self._a_card_no_deck_writes,
            self._a_situation_lists_real_cards,
            self._a_situation_has_its_shape,
            self._an_icon_is_one_of_the_six,
            self._a_situations_file_is_one_per_language_and_named_so,
            self._a_situations_key_belongs_to_a_situations_file,
            self._a_rank_and_its_source,
            self._frequency_shape,
            self._a_layer_gives_none,
            self._one_of_five,
            self._a_layer_cannot_change_the_word,
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


class Forms(Case):

    PLURAL = {"id": "pl", "kind": "plural", "word": "ఇళ్ళు", "reading": "iḷḷu"}

    def _a_form_with_its_reading(self) -> None:
        self.core(HOUSE, forms=[self.PLURAL])
        self.assertNoError(CORE)
        self.layer(HOUSE, forms={"pl": "More than one house."})
        self.assertClean()

    def _shape(self) -> None:
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

    def _a_form_of_kind_other_needs_its_label(self) -> None:
        self.core(HOUSE, forms=[dict(self.PLURAL, kind="other")])
        self.assertIn(f"cards.{HOUSE}.forms: 'pl' is a form of kind other: give its label "
                      f"here", self.layer_errors())
        self.layer(HOUSE, forms={"pl": "The plural."})
        self.assertNoError(LAYER)

    def _a_form_a_rules_table_has_is_warned_of(self) -> None:
        self.core(HOUSE, forms=[{"id": "obl", "kind": "oblique", "word": "ఇంటికి",
                                 "reading": "iṇṭiki"}])
        lines = self.section(self.run_main(), CORE)
        self.assertIn(f"  warning card {HOUSE}: forms[0].word 'ఇంటికి' is a cell of "
                      f"{HOUSE}'s row in a rules table, the source of its forms", lines)

    def test_forms(self) -> None:
        cases = (
            self._a_form_with_its_reading,
            self._shape,
            self._a_form_of_kind_other_needs_its_label,
            self._a_form_a_rules_table_has_is_warned_of,
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


class Senses(Case):

    SENSES = [{"id": "house", "examples": [{"target": "ఇల్లు పెద్దది.",
                                            "reading": "illu peddadi."}]},
              {"id": "home", "pos": "noun"}]

    def _senses_with_their_examples(self) -> None:
        self.core(HOUSE, senses=self.SENSES)
        self.assertNoError(CORE)
        self.layer(HOUSE, senses={
            "house": {"native": "house", "examples": {"ఇల్లు పెద్దది.": "The house is big."}},
            "home": {"native": "home"}})
        self.assertClean()

    def _shape(self) -> None:
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

    def _the_layer(self) -> None:
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

    def _a_sense_with_no_native(self) -> None:
        self.core(HOUSE, senses=self.SENSES)
        self.assertIn("  warning cards.zz-9001: sense 'home' has no native here",
                      self.warnings())
        with mock.patch(FILLED, {"zz"}):
            self.assertIn(f"cards.{HOUSE}.senses: sense 'home' has no native here; zz is "
                          f"filled in", self.layer_errors())

    def test_senses(self) -> None:
        cases = (
            self._senses_with_their_examples,
            self._shape,
            self._the_layer,
            self._a_sense_with_no_native,
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


class WiktionarySourceShape(Case):
    """A source naming wiktionary.org is the entry's page only (owner,
    2026-10-16, #518: "Link only"; 2026-10-17: "Wiktionary source shape")."""

    def put_source(self, source: str) -> None:
        self.setUp()
        self.core(HOUSE, synonyms=[{"id": "abode", "word": "నివాసం",
                                    "reading": "nivāsaṃ", "source": source}])

    def _the_importers_own_output_passes(self) -> None:
        try:
            import import_wiktionary
        except ImportError:
            self.skipTest("import_wiktionary is not importable")
        for word in ("నివాసం", "ice cream"):
            with self.subTest(word=word):
                self.put_source(import_wiktionary.Importer.source(word))
                self.assertNoError(CORE, "source")

    def _the_old_dump_date_form_fails(self) -> None:
        self.put_source("https://en.wiktionary.org/wiki/నివాసం (kaikki.org 2026-10-01)")
        errors = self.errors(CORE)
        self.assertTrue(any(
            e.startswith(f"card {HOUSE}: synonyms[0].source") and "'abode'" in e
            and "https://en.wiktionary.org/wiki/<word>" in e for e in errors), errors)

    def _other_wrong_forms_fail(self) -> None:
        for bad in ("http://en.wiktionary.org/wiki/నివాసం",
                    "https://hi.wiktionary.org/wiki/నివాసం",
                    "https://en.wiktionary.org/wiki/",
                    "https://en.wiktionary.org/wiki/నివాసం#Telugu",
                    "https://en.wiktionary.org/wiki/నివాసం?action=raw"):
            with self.subTest(bad=bad):
                self.put_source(bad)
                self.assertTrue(any("names Wiktionary" in e for e in self.errors(CORE)))

    def _every_kind_of_item_is_checked(self) -> None:
        bad = "https://en.wiktionary.org/wiki/x#y"
        self.core(HOUSE, senses=[{"id": "s", "source": bad}])
        self.assertTrue(any("senses[0].source" in e for e in self.errors(CORE)))
        self.setUp()
        self.core(HOUSE, examples=[{"target": "ఇల్లు.", "reading": "illu.", "source": bad}])
        self.assertTrue(any("examples[0].source" in e for e in self.errors(CORE)))

    def _a_source_not_naming_wiktionary_is_unaffected(self) -> None:
        for ok in ("Wiktionary", "https://tatoeba.org/en/sentences/show/1#x",
                   "Own work (2026-10-01)"):
            with self.subTest(ok=ok):
                self.put_source(ok)
                self.assertNoError(CORE, "source")

    def test_a_wiktionary_source_has_its_shape(self) -> None:
        cases = (
            self._the_importers_own_output_passes,
            self._the_old_dump_date_form_fails,
            self._other_wrong_forms_fail,
            self._every_kind_of_item_is_checked,
            self._a_source_not_naming_wiktionary_is_unaffected,
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


# From test_validate_examples.py.
# A card's examples (#511): a per-item `source`, and at least 2 on a word
# card once its language is filled in (DECK-FORMAT.md, Card data).
#
# Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
# PyYAML, like the validator itself.


TWO = [{"target": "ఇల్లు పెద్దది.", "reading": "illu peddadi.", "ipa": "illu peddadi"},
       {"target": "ఇల్లు చిన్నది.", "reading": "illu cinnadi.",
        "source": "https://tatoeba.org/en/sentences/show/1"}]
FILLED_EXAMPLES = "validate_decks.FILLED_LANGUAGES"
TOO_FEW = "a word card has at least 2 once zz is filled in (DECK-FORMAT.md, Card data)"


class ExampleSource(B1Case):

    def _a_core_example_may_name_its_source(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=TWO))
        self.assertNoError(CORE)
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(
            examples={"ఇల్లు పెద్దది.": "The house is big.",
                      "ఇల్లు చిన్నది.": "The house is small."}))
        self.assertNoError(LAYER)

    def _a_source_is_text(self) -> None:
        bad = [dict(TWO[0], source=""), dict(TWO[1], source=7)]
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=bad))
        self.assertError(CORE, "card zz-9001", "examples[0].source must be a non-empty "
                                               "string or omitted")
        self.assertError(CORE, "card zz-9001", "examples[1].source must be a non-empty "
                                               "string or omitted")

    def _a_layer_gives_no_source(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=TWO[:1]))
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(
            examples={"ఇల్లు పెద్దది.": {"native": "The house is big.", "source": "x"}}))
        self.assertTrue(any("examples" in e for e in self.errors(LAYER)))

    def _a_single_file_example_may_name_its_source(self) -> None:
        ex = {"target": "పిల్లి.", "native": "A cat.", "source": "Tatoeba #2"}
        self.put(EXTRA, single(cards=[dict(CAT, examples=[ex])]))
        self.assertNoError(EXTRA)
        self.put(EXTRA, single(cards=[dict(CAT, examples=[dict(ex, source=["x"])])]))
        self.assertError(EXTRA, "card zz-9501", "examples[0].source must be a non-empty "
                                                "string or omitted")

    def _no_error_while_the_language_is_not_filled_in(self) -> None:
        self.assertNotIn("zz", validate_decks.FILLED_LANGUAGES)
        self.assertNoError(CORE, "example(s)")

    def _no_language_is_filled_in_yet(self) -> None:
        self.assertEqual(validate_decks.FILLED_LANGUAGES, set())

    def _a_word_card_needs_two_once_filled_in(self) -> None:
        with mock.patch(FILLED_EXAMPLES, {"zz"}):
            self.assertError(CORE, "card zz-9001", f"0 example(s); {TOO_FEW}")
            self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=TWO[:1]))
            self.assertError(CORE, "card zz-9001", f"1 example(s); {TOO_FEW}")
            self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=TWO))
            self.assertNoError(CORE, "card zz-9001: ")

    def _only_word_cards_need_them(self) -> None:
        with mock.patch(FILLED_EXAMPLES, {"zz"}):
            errors = [e for e in self.errors(CORE) if "example(s)" in e]
            # Phrasebook cards and the sentence zz-9002 are not word cards.
            self.assertNotIn("zz-9101", " ".join(errors))
            self.assertNotIn("zz-9002", " ".join(errors))
            self.assertIn(f"card zz-9004: 0 example(s); {TOO_FEW}", errors)

    def _a_single_file_word_card_too(self) -> None:
        self.put(EXTRA, single())
        with mock.patch(FILLED_EXAMPLES, {"zz"}):
            self.assertError(EXTRA, "card zz-9501", f"0 example(s); {TOO_FEW}")
        self.assertNoError(EXTRA, "example(s)")

    def test_a_layer_gives_no_source_and_a_filled_language_two_examples(self) -> None:
        cases = (
            self._a_core_example_may_name_its_source,
            self._a_source_is_text,
            self._a_layer_gives_no_source,
            self._a_single_file_example_may_name_its_source,
            self._no_error_while_the_language_is_not_filled_in,
            self._no_language_is_filled_in_yet,
            self._a_word_card_needs_two_once_filled_in,
            self._only_word_cards_need_them,
            self._a_single_file_word_card_too,
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


# From test_validate_gender.py.
# Gender classes (#512): a language's path lists its classes, and a noun's
# `gender` is one of them; a noun with none is an error once the language is
# filled in (DECK-FORMAT.md, Card data).
#
# Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
# PyYAML, like the validator itself.


FILLED_GENDER = "validate_decks.FILLED_LANGUAGES"


class GenderClasses(B1Case):

    def classes(self, genders: object) -> None:
        self.edit(PATH, lambda d: d.update(genders=genders))

    def gender(self, cid: str, value: object) -> None:
        self.edit(CORE, lambda d: card(d, cid).update(gender=value))

    def across(self) -> list[str]:
        return [line for line in self.run_main() if line.startswith("error: ")]

    def _a_path_may_list_its_classes(self) -> None:
        self.classes(["mahat", "amahat"])
        self.assertNoError(PATH)
        self.classes([])
        self.assertNoError(PATH)

    def _the_classes_are_a_list_of_text(self) -> None:
        self.classes("m")
        self.assertTrue(any(e.startswith("genders: must be a list") for e in self.errors(PATH)))
        self.classes(["m", 1, " f", "m"])
        errors = self.errors(PATH)
        self.assertIn("genders[1]: must be a class name, quoted text with no spaces "
                      "around it, got 1", errors)
        self.assertIn("genders[2]: must be a class name, quoted text with no spaces "
                      "around it, got ' f'", errors)
        self.assertIn("genders[3]: 'm' is listed twice", errors)

    def _a_noun_of_a_listed_class_passes(self) -> None:
        self.classes(["mahat", "amahat"])
        self.gender("zz-9001", "amahat")
        self.assertEqual(self.across(), [])
        self.assertEqual(self.code, 0)

    def _a_noun_outside_the_classes_is_an_error(self) -> None:
        self.classes(["mahat", "amahat"])
        self.gender("zz-9001", "m")
        self.assertEqual(self.across(), [
            f"error: {self.p(CORE)}: card zz-9001: gender 'm' is not a class of zz; "
            f"its path lists mahat, amahat"])
        self.assertEqual(self.code, 1)

    def _a_language_without_gender_takes_none(self) -> None:
        self.classes([])
        self.gender("zz-9001", "m")
        self.assertEqual(self.across(), [
            f"error: {self.p(CORE)}: card zz-9001: gender 'm', but zz has no gender "
            f"classes; leave gender out"])

    def _only_nouns_are_checked(self) -> None:
        self.classes(["mahat", "amahat"])
        self.gender("zz-9003", "m")      # a verb
        self.assertEqual(self.across(), [])

    def _no_classes_listed_checks_nothing(self) -> None:
        self.gender("zz-9001", "anything")
        with mock.patch(FILLED_GENDER, {"zz"}):
            self.assertEqual(self.across(), [])

    def _every_path_lists_the_decided_classes(self) -> None:
        import validate_decks
        decided = {"hi": ["m", "f"], "mr": ["m", "f", "n"], "gu": ["m", "f", "n"],
                   "kn": ["m", "f", "n"], "te": ["mahat", "amahat"], "es": ["m", "f"],
                   "bn": [], "as": [], "ja": []}
        for code, classes in decided.items():
            with self.subTest(code=code):
                rep = validate_decks.validate(
                    validate_decks.ROOT / "decks" / code / f"{code}-path.yaml")
                self.assertEqual(rep.plan.genders, classes)

    def _a_missing_gender_is_an_error_once_filled_in(self) -> None:
        self.classes(["mahat", "amahat"])
        self.assertEqual(self.across(), [])
        with mock.patch(FILLED_GENDER, {"zz"}):
            found = self.across()
        self.assertEqual(sorted(found), sorted(
            f"error: {self.p(CORE)}: card {cid}: a noun has a gender once zz is filled "
            f"in, one of mahat, amahat (DECK-FORMAT.md, Card data)"
            for cid in ("zz-9001", "zz-9004")))

    def _a_language_without_gender_needs_none_once_filled_in(self) -> None:
        self.classes([])
        with mock.patch(FILLED_GENDER, {"zz"}):
            self.assertEqual(self.across(), [])

    def _a_single_file_deck_is_checked(self) -> None:
        self.classes(["mahat", "amahat"])
        self.put(EXTRA, single(cards=[dict(CAT, gender="f")]))
        self.assertEqual([e for e in self.across() if "gender" in e], [
            f"error: {self.p(EXTRA)}: card zz-9501: gender 'f' is not a class of zz; "
            f"its path lists mahat, amahat"])

    def _a_layer_gives_no_gender(self) -> None:
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(gender="mahat"))
        self.assertTrue(any("gender" in e for e in self.errors(LAYER)))

    def test_a_noun_has_a_gender_of_the_paths_classes(self) -> None:
        cases = (
            self._a_path_may_list_its_classes,
            self._the_classes_are_a_list_of_text,
            self._a_noun_of_a_listed_class_passes,
            self._a_noun_outside_the_classes_is_an_error,
            self._a_language_without_gender_takes_none,
            self._only_nouns_are_checked,
            self._no_classes_listed_checks_nothing,
            self._every_path_lists_the_decided_classes,
            self._a_missing_gender_is_an_error_once_filled_in,
            self._a_language_without_gender_needs_none_once_filled_in,
            self._a_single_file_deck_is_checked,
            self._a_layer_gives_no_gender,
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


# From test_validate_ipa.py.
# The IPA course's format (ADR-0041): an example's `language` and `sounds`,
# a language block's `typed`, and `script: ipa`, which needs no reading, no
# tts tag and no B1 plan.
#
# Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
# PyYAML, like the validator itself.


YES = {"target": "ఇల్లు", "language": "te", "sounds": True}
NO = {"target": "इल्लू", "language": "hi", "sounds": False}


class IpaLanguageBlock(B1Case):
    IPA = {"code": "ipa", "iso639_3": "zxx", "name": "IPA", "script": "ipa",
           "typed": False, "icon": "ə"}

    def _typed_is_a_boolean(self) -> None:
        self.put(EXTRA, single(language=dict(self.IPA)))
        self.assertNoError(EXTRA, "typed")
        self.put(EXTRA, single(language=dict(self.IPA, typed="false")))
        self.assertError(EXTRA, "language", "typed must be a boolean")

    def _the_ipa_script_needs_no_reading_and_no_tts(self) -> None:
        self.put(EXTRA, single(language=dict(self.IPA)))
        self.assertNoError(EXTRA, "reading")
        self.assertNoError(EXTRA, "script")
        self.assertNoError(EXTRA, "tts")

    def _a_bracketed_ipa_is_narrow_and_only_for_the_ipa_course(self) -> None:
        ex = {"target": "pin", "native": "pin", "language": "en", "ipa": "[pʰɪn]"}
        self.put(EXTRA, single(language=dict(self.IPA),
                               cards=[dict(CAT, examples=[ex])]))
        self.assertNoError(EXTRA, "not a broad IPA")
        self.put(EXTRA, single(cards=[dict(CAT, examples=[ex])]))
        self.assertError(EXTRA, "ipa", "'[pʰɪn]' is not a broad IPA "
                         "transcription: IPA letters and marks only, "
                         "without / / or [ ]")

    def _a_core_example_may_give_its_language_and_sounds(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=[YES, NO]))
        self.assertNoError(CORE, "examples[")

    def _the_translations_stay_in_the_layer(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=[YES, NO]))
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(
            examples={"ఇల్లు": "house", "इल्लू": "not a word"}))
        self.assertNoError(LAYER)

    def _sounds_is_a_boolean(self) -> None:
        for bad in ("false", 0, None):
            self.edit(CORE, lambda d, b=bad: card(d, "zz-9001").update(
                examples=[dict(YES, sounds=b)]))
            self.assertError(CORE, "card zz-9001",
                             "examples[0].sounds must be true or false")

    def _language_is_a_code(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(
            examples=[dict(YES, language="Telugu")]))
        self.assertError(CORE, "card zz-9001", "examples[0].language must be a 2-3 "
                                               "letter language code, got 'Telugu'")

    def _a_single_file_example_may_give_them(self) -> None:
        ex = {"target": "పిల్లి.", "native": "A cat.", "language": "te",
              "sounds": False}
        self.put(EXTRA, single(cards=[dict(CAT, examples=[ex])]))
        self.assertNoError(EXTRA)
        self.put(EXTRA, single(cards=[dict(CAT, examples=[dict(ex, sounds="no")])]))
        self.assertError(EXTRA, "card zz-9501", "examples[0].sounds must be true or false")

    def test_ipa_examples_and_the_ipa_course(self) -> None:
        cases = (
            self._typed_is_a_boolean,
            self._the_ipa_script_needs_no_reading_and_no_tts,
            self._a_bracketed_ipa_is_narrow_and_only_for_the_ipa_course,
            self._a_core_example_may_give_its_language_and_sounds,
            self._the_translations_stay_in_the_layer,
            self._sounds_is_a_boolean,
            self._language_is_a_code,
            self._a_single_file_example_may_give_them,
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


# From test_validate_iso.py.
# ISO 15919 readings and IPA (ADR-0025): a romanisation file that names the
# standard and how its letters are typed, readings in its letters, and every
# `ipa` and `ipas` a broad IPA transcription.


HEAD = """\
schema: 1
id: {id}
name: Probe
kind: {kind}
language: {{ code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }}
native: {{ code: en, iso639_3: eng, name: English }}
license: CC-BY-SA-4.0
"""

ROMANISATION = """\
schema: 1
kind: romanisation
id: hi-romanisation
language: hi
scheme: "ISO 15919 letters, spelled as said."
standard: "ISO 15919"
typed:
{typed}
equivalents:
  - ["i", "ee", "ii"]
"""

TYPED = """\
  - ["ā", "a"]
  - ["ḍ", "d"]
  - ["m̐", ""]"""


def vocab(reading: str, ipa: str) -> str:
    return HEAD.format(id="hi-en-probe", kind="vocab") + f"""\
cards:
  - id: hi-0001
    target: "थोड़ा"
    native: "a little"
    reading: "{reading}"
    ipa: "{ipa}"
"""


def grammar(ipas: str) -> str:
    return HEAD.format(id="hi-en-grammar-probe", kind="grammar") + """\
pattern:
  name: "Probe"
  slot_name: "person"
  slots: ["मैं", "तुम"]
  prompt: "{lemma} — {slot}"
  entries:
    - lemma: "जाना"
      key: jaanaa
      reading: "jānā"
      gloss: "to go"
      forms: { "मैं": "जाता हूँ", "तुम": null }
      readings: { "मैं": "jātā hū̃" }
""" + ipas


class IsoAndIpa(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def write(self, name: str, text: str) -> validate_decks.Report:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def romanisation(self, typed: str = TYPED) -> validate_decks.Report:
        return self.write("hi-romanisation.yaml", ROMANISATION.format(typed=typed))

    def assertRejected(self, report: validate_decks.Report, needle: str) -> None:
        self.assertTrue(any(needle in e for e in report.errors),
                        f"expected {needle!r} in {report.errors}")

    def _an_iso_romanisation_file_is_valid(self) -> None:
        self.assertEqual(self.romanisation().errors, [])

    def _iso_15919_is_the_one_standard(self) -> None:
        text = ROMANISATION.format(typed=TYPED).replace(
            '"ISO 15919"', '"IAST"')
        self.assertRejected(self.write("hi-romanisation.yaml", text),
                            "the one standard known is 'ISO 15919'")

    def _typed_needs_the_standard(self) -> None:
        text = ROMANISATION.format(typed=TYPED).replace(
            'standard: "ISO 15919"\n', "")
        self.assertRejected(self.write("hi-romanisation.yaml", text),
                            "name the standard")

    def _typed_pairs_are_iso_letters_and_how_they_are_typed(self) -> None:
        for typed, needle in (
            ('  - ["ā"]', "must be a pair"),
            ('  - ["ā", "a", "aa"]', "must be a pair"),
            ('  - ["Ā", "a"]', "must be ISO 15919 letters"),
            ('  - ["ä", "a"]', "must be ISO 15919 letters"),
            ('  - ["ā", "A"]', "must be lowercase ASCII"),
            ('  - ["ā", "â"]', "must be lowercase ASCII"),
        ):
            with self.subTest(typed=typed):
                self.assertRejected(self.romanisation(typed), needle)

    def _with_the_standard_readings_are_iso_letters(self) -> None:
        self.romanisation()
        self.assertEqual(
            self.write("hi-en-probe.yaml", vocab("thoṛā", "tʰoɽaː")).errors, [])
        for reading in ("Thoṛā", "thoṛä"):
            with self.subTest(reading=reading):
                self.assertRejected(
                    self.write("hi-en-probe.yaml", vocab(reading, "tʰoɽaː")),
                    "lowercase ISO 15919 letters")
        decomposed = unicodedata.normalize("NFD", "thoṛā")
        self.assertRejected(
            self.write("hi-en-probe.yaml", vocab(decomposed, "tʰoɽaː")),
            "not NFC-normalised")

    def _an_ipa_is_broad_ipa_without_slashes(self) -> None:
        self.assertEqual(
            self.write("hi-en-probe.yaml", vocab("thora", "tʰoɽaː")).errors, [])
        for ipa, needle in (
            ("/tʰoɽaː/", "not a broad IPA transcription"),
            ("[tʰoɽaː]", "not a broad IPA transcription"),
            (" tʰoɽaː", "not a broad IPA transcription"),
            ("thoda", None),
            (unicodedata.normalize("NFD", "hũː"), "not NFC-normalised"),
        ):
            with self.subTest(ipa=ipa):
                report = self.write("hi-en-probe.yaml", vocab("thora", ipa))
                if needle is None:
                    # Plain letters are IPA letters too.
                    self.assertEqual(report.errors, [])
                else:
                    self.assertRejected(report, needle)

    def _a_grammar_entry_gives_each_form_its_ipa(self) -> None:
        self.assertEqual(self.write("hi-en-grammar-probe.yaml", grammar(
            '      ipas: { "मैं": "dʒaːtaː hũː" }\n')).errors, [])
        for ipas, needle in (
            ('      ipas: { "तुम": "dʒaːte ho" }\n', "given for a slot with no form"),
            ('      ipas: { "मैं": "dʒaːtaː hũː", "हम": "x" }\n', "not a slot"),
            ('      ipas: {}\n', "is missing; every form has one"),
            ('      ipas: { "मैं": 3 }\n', "must be text"),
            ('      ipas: ["dʒaːtaː hũː"]\n', "must be a mapping"),
            ('      ipas: { "मैं": "/dʒaːtaː hũː/" }\n', "not a broad IPA"),
        ):
            with self.subTest(ipas=ipas):
                self.assertRejected(self.write("hi-en-grammar-probe.yaml",
                                               grammar(ipas)), needle)

    def test_readings_are_based_on_iso_15919(self) -> None:
        cases = (
            self._an_iso_romanisation_file_is_valid,
            self._iso_15919_is_the_one_standard,
            self._typed_needs_the_standard,
            self._typed_pairs_are_iso_letters_and_how_they_are_typed,
            self._with_the_standard_readings_are_iso_letters,
            self._an_ipa_is_broad_ipa_without_slashes,
            self._a_grammar_entry_gives_each_form_its_ipa,
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


# From test_validate_media.py.
# A card's own recording (#518), shipped with the deck: `audio` naming
# `decks/<lang>/audio/<card id>.opus`, the file there, and its credit,
# `audio_credit: { source, license, credit }`.
#
# Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
# PyYAML, like the validator itself.


HOUSE_MEDIA = "zz-9001"
CREDIT = {"source": "https://commons.wikimedia.org/wiki/File:Te-ఇల్లు.ogg",
          "license": "CC-BY-SA-4.0", "credit": "A. Speaker"}


class CaseMedia(B1Case):

    def core(self, cid: str, **fields: object) -> None:
        self.edit(CORE, lambda d: card(d, cid).update(fields))

    def file(self, rel: str) -> None:
        path = self.dir / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"OggS")


class Audio(CaseMedia):

    def _a_recording_with_its_credit(self) -> None:
        self.file(f"audio/{HOUSE_MEDIA}.opus")
        self.core(HOUSE_MEDIA, audio=f"decks/zz/audio/{HOUSE_MEDIA}.opus", audio_credit=CREDIT)
        self.assertNoError(CORE)
        self.assertNotIn(f"error: decks/zz/audio/{HOUSE_MEDIA}.opus: no card names it as its "
                         f"audio; remove it, or name it on the card {HOUSE_MEDIA}",
                         self.run_main())

    def _in_a_single_file_deck(self) -> None:
        self.file("audio/zz-9501.opus")
        self.put(EXTRA, single(cards=[dict(CAT, audio="decks/zz/audio/zz-9501.opus",
                                           audio_credit=CREDIT)]))
        self.assertNoError(EXTRA)

    def _named_by_its_card(self) -> None:
        self.file("audio/zz-9002.opus")
        self.core(HOUSE_MEDIA, audio="decks/zz/audio/zz-9002.opus", audio_credit=CREDIT)
        self.assertError(CORE, f"card {HOUSE_MEDIA}", f"audio must be decks/zz/audio/{HOUSE_MEDIA}"
                         f".opus: the file is named by its card, got "
                         f"'decks/zz/audio/zz-9002.opus'")

    def _the_file_is_there(self) -> None:
        self.core(HOUSE_MEDIA, audio=f"decks/zz/audio/{HOUSE_MEDIA}.opus", audio_credit=CREDIT)
        self.assertError(CORE, f"card {HOUSE_MEDIA}", f"audio decks/zz/audio/{HOUSE_MEDIA}.opus has "
                                                f"no file")

    def _the_credit_is_required(self) -> None:
        self.file(f"audio/{HOUSE_MEDIA}.opus")
        self.core(HOUSE_MEDIA, audio=f"decks/zz/audio/{HOUSE_MEDIA}.opus")
        self.assertError(CORE, f"card {HOUSE_MEDIA}", "audio_credit is required with audio: "
                                                "the file's { source, license, credit }")

    def _the_credit_shape(self) -> None:
        self.file(f"audio/{HOUSE_MEDIA}.opus")
        self.core(HOUSE_MEDIA, audio=f"decks/zz/audio/{HOUSE_MEDIA}.opus",
                  audio_credit={"source": "x", "license": "GFDL", "by": "y"})
        errors = self.errors(CORE)
        w = f"card {HOUSE_MEDIA}"
        for msg in ("audio_credit: unknown field 'by'",
                    "audio_credit.credit is required and must be a non-empty string",
                    "audio_credit.license 'GFDL' cannot ship in a CC BY-SA 4.0 deck: "
                    "CC0-1.0, public-domain, or CC-BY or CC-BY-SA 2.0 to 4.0, such as "
                    "CC-BY-SA-4.0"):
            self.assertIn(f"{w}: {msg}", errors)

    def _licences_that_ship(self) -> None:
        self.file(f"audio/{HOUSE_MEDIA}.opus")
        for licence in ("CC0-1.0", "public-domain", "CC-BY-2.5", "CC-BY-SA-3.0-DE",
                        "CC-BY-SA-4.0"):
            with self.subTest(licence=licence):
                self.core(HOUSE_MEDIA, audio=f"decks/zz/audio/{HOUSE_MEDIA}.opus",
                          audio_credit=dict(CREDIT, license=licence))
                self.assertNoError(CORE)
        for licence in ("CC-BY-NC-4.0", "CC-BY-SA-1.0", "GFDL-1.2"):
            with self.subTest(licence=licence):
                self.core(HOUSE_MEDIA, audio=f"decks/zz/audio/{HOUSE_MEDIA}.opus",
                          audio_credit=dict(CREDIT, license=licence))
                self.assertEqual([e for e in self.errors(CORE) if "cannot ship" in e],
                                 [f"card {HOUSE_MEDIA}: audio_credit.license {licence!r} cannot "
                                  f"ship in a CC BY-SA 4.0 deck: CC0-1.0, public-domain, "
                                  f"or CC-BY or CC-BY-SA 2.0 to 4.0, such as CC-BY-SA-4.0"])

    def _a_credit_only_with_a_shipped_file(self) -> None:
        self.core(HOUSE_MEDIA, audio="https://example.org/house.ogg", audio_credit=CREDIT)
        self.assertError(CORE, f"card {HOUSE_MEDIA}", "audio_credit is only for a file shipped "
                         "with the deck, audio: decks/zz/audio/<card id>.opus")
        self.core(HOUSE_MEDIA, audio="https://example.org/house.ogg")
        self.edit(CORE, lambda d: card(d, HOUSE_MEDIA).pop("audio_credit"))
        self.assertNoError(CORE)

    def _not_in_a_layer(self) -> None:
        self.edit("en/zz-en-home.yaml",
                  lambda d: d["cards"][HOUSE_MEDIA].update(audio_credit=CREDIT))
        self.assertTrue(any("audio_credit" in e for e in self.errors("en/zz-en-home.yaml")))

    def _a_file_no_card_names(self) -> None:
        self.file("audio/zz-9002.opus")
        self.file("audio/notes.txt")
        lines = self.run_main()
        self.assertIn("error: decks/zz/audio/zz-9002.opus: no card names it as its audio; "
                      "remove it, or name it on the card zz-9002", lines)
        self.assertIn("error: decks/zz/audio/notes.txt: a card's audio file ends in .opus",
                      lines)

    def _an_image_with_its_credit(self) -> None:
        self.file(f"images/{HOUSE_MEDIA}.webp")
        self.core(HOUSE_MEDIA, image=f"decks/zz/images/{HOUSE_MEDIA}.webp", image_credit=IMAGE_CREDIT)
        self.assertNoError(CORE)
        self.assertFalse(any("images/" in line for line in self.run_main()
                             if line.startswith("error")))

    def _image_in_a_single_file_deck(self) -> None:
        self.file("images/zz-9501.webp")
        self.put(EXTRA, single(cards=[dict(CAT, image="decks/zz/images/zz-9501.webp",
                                           image_credit=IMAGE_CREDIT)]))
        self.assertNoError(EXTRA)

    def _only_a_file_shipped_with_the_deck(self) -> None:
        self.core(HOUSE_MEDIA, image="https://example.org/house.jpg", image_credit=IMAGE_CREDIT)
        self.assertError(CORE, f"card {HOUSE_MEDIA}", "image must be decks/zz/images/<card id>"
                         ".webp, got 'https://example.org/house.jpg'")

    def _named_by_its_card_and_there(self) -> None:
        self.core(HOUSE_MEDIA, image="decks/zz/images/zz-9002.webp", image_credit=IMAGE_CREDIT)
        self.assertError(CORE, f"card {HOUSE_MEDIA}", f"image must be decks/zz/images/{HOUSE_MEDIA}"
                         f".webp: the file is named by its card, got "
                         f"'decks/zz/images/zz-9002.webp'")
        self.core(HOUSE_MEDIA, image=f"decks/zz/images/{HOUSE_MEDIA}.webp")
        self.assertError(CORE, f"card {HOUSE_MEDIA}", f"image decks/zz/images/{HOUSE_MEDIA}.webp has "
                                                f"no file")

    def _the_credit_is_required_and_ships(self) -> None:
        self.file(f"images/{HOUSE_MEDIA}.webp")
        self.core(HOUSE_MEDIA, image=f"decks/zz/images/{HOUSE_MEDIA}.webp")
        self.assertError(CORE, f"card {HOUSE_MEDIA}", "image_credit is required with image: "
                                                "the file's { source, license, credit }")
        self.core(HOUSE_MEDIA, image_credit=dict(IMAGE_CREDIT, license="GFDL"))
        self.assertError(CORE, f"card {HOUSE_MEDIA}", "image_credit.license 'GFDL' cannot ship "
                         "in a CC BY-SA 4.0 deck: CC0-1.0, public-domain, or CC-BY or "
                         "CC-BY-SA 2.0 to 4.0, such as CC-BY-SA-4.0")

    def _not_in_a_layer_nor_on_a_ref(self) -> None:
        self.edit("en/zz-en-home.yaml",
                  lambda d: d["cards"][HOUSE_MEDIA].update(image="decks/zz/images/x.webp"))
        self.assertTrue(any("image" in e for e in self.errors("en/zz-en-home.yaml")))

    def _image_a_file_no_card_names(self) -> None:
        self.file("images/zz-9002.webp")
        self.file("images/zz-9001.png")
        lines = self.run_main()
        self.assertIn("error: decks/zz/images/zz-9002.webp: no card names it as its image; "
                      "remove it, or name it on the card zz-9002", lines)
        self.assertIn("error: decks/zz/images/zz-9001.png: a card's image file ends in "
                      ".webp", lines)

    def test_a_recording_or_image_needs_its_file_and_a_shippable_credit(self) -> None:
        cases = (
            self._a_recording_with_its_credit,
            self._in_a_single_file_deck,
            self._named_by_its_card,
            self._the_file_is_there,
            self._the_credit_is_required,
            self._the_credit_shape,
            self._licences_that_ship,
            self._a_credit_only_with_a_shipped_file,
            self._not_in_a_layer,
            self._a_file_no_card_names,
            self._an_image_with_its_credit,
            self._image_in_a_single_file_deck,
            self._only_a_file_shipped_with_the_deck,
            self._named_by_its_card_and_there,
            self._the_credit_is_required_and_ships,
            self._not_in_a_layer_nor_on_a_ref,
            self._image_a_file_no_card_names,
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


IMAGE_CREDIT = {"source": "https://openmoji.org/library/emoji-1F3E0/",
                "license": "CC-BY-SA-4.0", "credit": "OpenMoji"}


# From test_validate_pictures.py.
# A card's picture: one emoji whose Noto Emoji image is bundled (ADR-0034).


class Pictures(Validated):
    def with_picture(self, value: str) -> str:
        return VOCAB.replace('    reading: "ghar"\n',
                             f'    reading: "ghar"\n    picture: {value}\n')

    def _a_bundled_picture_is_valid(self) -> None:
        self.assertValid(self.with_picture('"🏠"'))

    def _one_with_no_image_is_rejected(self) -> None:
        self.assertRejected(self.with_picture('"🦖"'), "has no image")

    def _it_must_be_an_emoji(self) -> None:
        for bad in ('"house"', '""', "7"):
            with self.subTest(bad=bad):
                self.assertRejected(self.with_picture(bad), "picture must be one emoji")

    def _its_file_is_named_as_the_app_names_it(self) -> None:
        self.assertEqual(validate_decks.picture_file("🏠"), "emoji_u1f3e0.png")
        self.assertEqual(validate_decks.picture_file("☁️"), "emoji_u2601.png")
        self.assertEqual(validate_decks.picture_file("🧑‍🏫"),
                         "emoji_u1f9d1_200d_1f3eb.png")

    def with_ask(self, picture: str, ask: str) -> str:
        text = self.with_picture(picture) if picture else VOCAB
        return text.replace('    reading: "ghar"\n',
                            f'    reading: "ghar"\n    picture_ask: {ask}\n')

    def _a_question_picture_is_valid(self) -> None:
        self.assertValid(self.with_ask('"🏠"', "true"))

    def _picture_ask_needs_a_picture(self) -> None:
        self.assertRejected(self.with_ask("", "true"), "picture_ask needs a picture")

    def _picture_ask_is_only_true(self) -> None:
        for bad in ("false", '"true"', "yes"):
            with self.subTest(bad=bad):
                self.assertRejected(self.with_ask('"🏠"', bad),
                                    "picture_ask must be true, unquoted")

    def test_a_question_word_picture_asks(self) -> None:
        for case in (self._a_question_picture_is_valid,
                     self._picture_ask_needs_a_picture,
                     self._picture_ask_is_only_true):
            with self.subTest(case.__name__.lstrip("_")):
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()

    def test_a_picture_is_an_emoji_named_as_the_app_names_it(self) -> None:
        cases = (
            self._a_bundled_picture_is_valid,
            self._one_with_no_image_is_rejected,
            self._it_must_be_an_emoji,
            self._its_file_is_named_as_the_app_names_it,
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


# From test_validate_reading.py.
# Reading decks (#98, ADR-0019): passages and their questions, on their own
# and against the rest of their course. Described in docs/DECK-FORMAT.md.
#
# Stdlib `unittest` plus PyYAML, like the validator itself.


HEADER = """\
schema: 1
id: bn-en-reading-probe
name: "Probe"
kind: reading
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC-BY-SA-4.0
source: "A book, in the public domain"
"""

SENTENCES = """\
      - text: "সে কাজ ক’রে বাড়ি যায়।"
        reading: "she kaj kore bari jay."
      - text: "বাড়িতে সে ভাত খায়।"
        reading: "barite she bhat khay."
"""

QUESTIONS = """\
      - id: bn-9101
        prompt: { en: "They eat rice at home.", bn: "সে বাড়িতে ভাত খায়।" }
        answer: true
      - id: bn-9102
        prompt: { en: "Where do they go?" }
        options:
          - { en: "Home" }
          - { en: "To the market" }
        answer: 1
"""

GLOSSARY = """\
    glossary:
      - word: "ক’রে"
        modern: "করে"
        reading: "kore"
        meaning: { en: "having done" }
        note: { en: "older spelling; the apostrophe marks a dropped ই (i)" }
"""


def deck(sentences: str = SENTENCES, questions: str = QUESTIONS,
         extra: str = GLOSSARY, header: str = HEADER) -> str:
    return (f"{header}passages:\n  - id: bn-home\n    title: \"Going home\"\n"
            f"    theme: market\n{extra}    sentences:\n{sentences}"
            f"    questions:\n{questions}")


def question(body: str) -> str:
    """One question, [body] after its id, and a second that is valid."""
    return f"      - id: bn-9103\n{body}" + QUESTIONS.split("      - id: bn-9102\n")[0]


class Reading(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def write(self, text: str, name: str = "bn-en-reading-probe.yaml"
              ) -> validate_decks.Report:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def assertRejected(self, report: validate_decks.Report, needle: str) -> None:
        self.assertTrue(
            any(needle in e for e in report.errors),
            f"expected an error containing {needle!r}, got {report.errors}",
        )


class ReadingAcrossDecks(Reading):
    WORDS = """\
schema: 1
id: bn-en-market
name: "Market"
theme: market
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC-BY-SA-4.0
cards:
  - { id: bn-9001, target: "সে", native: "he, she", reading: "she" }
  - { id: bn-9002, target: "ভাত খায়", native: "eats rice", reading: "bhat khay" }
"""

    def course(self, units: str = "  - [bn-market]\n  - [bn-reading-probe]\n"
               ) -> list[validate_decks.Report]:
        themes = self.write("schema: 1\nkind: themes\nthemes:\n"
                            "  - { id: market, name: \"Market\" }\n", "themes.yaml")
        path = self.write("schema: 1\nkind: path\nid: bn-path\nlanguage: bn\n"
                          f"units:\n{units}", "bn-path.yaml")
        words = self.write(self.WORDS, "bn-en-market.yaml")
        return [themes, path, words, self.write(deck())]

    def _words_no_deck_teaches_are_warned_of_not_refused(self) -> None:
        reports = self.course()
        self.assertEqual(validate_decks.check_reading_across(reports), [])
        reading = reports[-1]
        self.assertEqual(reading.errors, [])
        warning = " ".join(reading.warnings)
        self.assertIn("words appear in no bn-en deck", warning)
        for word in ("কাজ", "বাড়ি", "যায়", "বাড়িতে"):
            self.assertIn(word, warning)
        # Taught, or glossed.
        for word in ("সে,", "ভাত", "খায়", "ক’রে"):
            self.assertNotIn(word, warning)

    def _no_word_is_warned_of_without_the_course_s_decks(self) -> None:
        reading = self.write(deck())
        self.assertEqual(validate_decks.check_reading_across([reading]), [])
        self.assertEqual(reading.warnings, [])

    def _a_passage_s_theme_is_on_the_theme_path(self) -> None:
        reports = self.course()
        reports[-1] = self.write(deck().replace("theme: market", "theme: moon"))
        problems = validate_decks.check_reading_across(reports)
        self.assertTrue(any("theme 'moon' is not in decks/themes.yaml" in p
                            for p in problems), problems)

    def _a_passage_comes_after_its_theme_on_the_path(self) -> None:
        reports = self.course("  - [bn-reading-probe, bn-market]\n")
        validate_decks.check_reading_across(reports)
        self.assertTrue(any("put it in a later unit" in w for w in reports[-1].warnings),
                        reports[-1].warnings)
        later = self.course()
        validate_decks.check_reading_across(later)
        self.assertFalse(any("later unit" in w for w in later[-1].warnings))

    def _the_whole_command_passes_with_warnings_only(self) -> None:
        self.course()
        (self.tmp / "pubspec.yaml").unlink(missing_ok=True)
        out = io.StringIO()
        # The probe course stands in for a language: the repository's own
        # decks/bn, which now has cores and so needs its B1 plan, is not part of it.
        with mock.patch.object(validate_decks, "ROOT", self.tmp), \
                contextlib.redirect_stdout(out):
            code = validate_decks.main(["validate_decks.py", str(self.tmp)])
        self.assertEqual(code, 0, out.getvalue())
        self.assertIn("words appear in no bn-en deck", out.getvalue())

    def _a_reading_deck_is_valid(self) -> None:
        report = self.write(deck())
        self.assertEqual(report.errors, [])
        self.assertEqual(report.warnings, [])
        pid, theme, words, glossed = report.passages[2][0]
        self.assertEqual((pid, theme), ("bn-home", "market"))
        self.assertIn("ক’রে", words)
        self.assertEqual(glossed, {"ক’রে", "করে"})

    def _a_question_id_is_used_once_in_the_deck(self) -> None:
        twice = QUESTIONS.replace("id: bn-9102", "id: bn-9101")
        self.assertRejected(self.write(deck(questions=twice)),
                            "duplicate id 'bn-9101'")
        # A question id is a card id (ADR-0018); a passage's names it.
        self.assertRejected(
            self.write(deck(questions=QUESTIONS.replace("id: bn-9102", "id: home-q2"))),
            "id must be bn- and at least four digits")
        self.assertRejected(
            self.write(deck().replace("  - id: bn-home\n", "  - id: bn-9100\n")),
            "id must start with bn- and name the passage")

    def _an_answer_is_an_option_number_or_true_or_false(self) -> None:
        for body, needle in (
            ('        prompt: { en: "A?" }\n        options: [{ en: "A" }, { en: "B" }]\n'
             '        answer: 3\n', "from 1 to 2, got 3"),
            ('        prompt: { en: "A?" }\n        options: [{ en: "A" }, { en: "B" }]\n'
             '        answer: true\n', "from 1 to 2, got True"),
            ('        prompt: { en: "A?" }\n        options: [{ en: "A" }, { en: "B" }]\n'
             '        answer: 0\n', "from 1 to 2, got 0"),
            ('        prompt: { en: "A." }\n        answer: 1\n', "true or false"),
        ):
            with self.subTest(body=body):
                self.assertRejected(self.write(deck(questions=question(body))), needle)

    def _two_to_four_options_and_questions(self) -> None:
        one = '[{ en: "A" }]'
        five = ", ".join('{ en: "%s" }' % c for c in "ABCDE")
        for options in (one, f"[{five}]"):
            with self.subTest(options=options):
                self.assertRejected(self.write(deck(questions=question(
                    f'        prompt: {{ en: "A?" }}\n        options: {options}\n'
                    f'        answer: 1\n'))), "2 to 4 options")
        single = QUESTIONS.split("      - id: bn-9102\n")[0]
        self.assertRejected(self.write(deck(questions=single)), "2 to 4 questions")

    def _text_is_keyed_by_language_with_english(self) -> None:
        self.assertRejected(
            self.write(deck(questions=question('        prompt: { bn: "ভাত?" }\n'
                                               '        answer: true\n'))),
            "prompt needs en")
        # A bare false is a boolean, so the key is no language code. (A bare
        # no is the string "no" to both the validator and the app, YAML 1.2.)
        self.assertRejected(
            self.write(deck(questions=question('        prompt: { en: "A.", false: "B." }\n'
                                               '        answer: true\n'))),
            "boolean")

    def _every_option_is_in_the_prompt_s_languages(self) -> None:
        self.assertRejected(self.write(deck(questions=question(
            '        prompt: { en: "Which?", bn: "কোনটা?" }\n'
            '        options: [{ en: "A", bn: "ক" }, { en: "B" }]\n'
            '        answer: 1\n'))), "options[1] is written in ['en']")

    def _a_sentence_has_text_and_in_this_script_a_reading(self) -> None:
        self.assertRejected(
            self.write(deck(sentences='      - text: "সে যায়।"\n')),
            "reading is required")
        self.assertRejected(
            self.write(deck(sentences='      - text: true\n        reading: "x"\n')),
            "boolean")
        self.assertRejected(self.write(deck(sentences="      []\n")),
                            "sentences must be a non-empty list")

    def _passage_text_is_never_asked_to_change(self) -> None:
        # Decomposed য + ়, which NFC would not compose: no warning, since
        # a quotation stays as the book writes it.
        decomposed = deck(sentences='      - text: "য়ে ক’রে"\n        reading: "x"\n')
        report = self.write(decomposed)
        self.assertEqual(report.errors, [])
        self.assertFalse(any("NFC" in w for w in report.warnings), report.warnings)
        spaced = self.write(deck(sentences='      - text: " ক’রে "\n        reading: "x"\n'))
        self.assertEqual(spaced.errors, [])
        self.assertTrue(any("kept exactly as written" in w for w in spaced.warnings))

    def _a_glossed_word_occurs_in_its_passage_letter_for_letter(self) -> None:
        straight = GLOSSARY.replace("ক’রে", "ক'রে")
        self.assertRejected(self.write(deck(extra=straight)),
                            "does not occur in the passage")
        self.assertRejected(self.write(deck(extra=GLOSSARY.replace("ক’রে", "লয়"))),
                            "does not occur in the passage")
        twice = GLOSSARY + GLOSSARY.split("    glossary:\n")[1]
        self.assertRejected(self.write(deck(extra=twice)), "listed twice")

    def _a_glossary_entry_has_a_modern_form_reading_and_meaning(self) -> None:
        for old, new, needle in (
            ('        modern: "করে"\n', "", "modern is required"),
            ('        reading: "kore"\n', "", "reading is required"),
            ('meaning: { en: "having done" }', 'meaning: { bn: "করে" }', "meaning needs en"),
            ("note: { en:", "note: { bn:", "note needs en"),
            ('        note:', '        sense: "x"\n        note:', "unknown field 'sense'"),
        ):
            with self.subTest(needle=needle):
                self.assertRejected(self.write(deck(extra=GLOSSARY.replace(old, new))),
                                    needle)

    def _passages_are_only_for_a_reading_deck_and_cards_not(self) -> None:
        self.assertRejected(self.write(deck(header=HEADER.replace("kind: reading\n", ""))),
                            "only valid on a reading deck")
        with_cards = deck() + 'cards:\n  - { id: c1, target: "x", native: "y" }\n'
        self.assertRejected(self.write(with_cards), "has passages, not cards")
        themed = deck(header=HEADER + "theme: market\n")
        self.assertRejected(self.write(themed), "only a vocab deck teaches a theme")

    def _a_card_cannot_be_drilled_by_reading(self) -> None:
        card = HEADER.replace("kind: reading\n", "").replace("bn-en-reading-probe",
                                                            "bn-en-words")
        card += ('cards:\n  - { id: c1, target: "ভাত", native: "rice", reading: "bhat",'
                 ' modes: [reading] }\n')
        self.assertRejected(self.write(card, "bn-en-words.yaml"), "unknown mode 'reading'")

    def test_a_reading_deck_and_its_glossary(self) -> None:
        cases = (
            self._words_no_deck_teaches_are_warned_of_not_refused,
            self._no_word_is_warned_of_without_the_course_s_decks,
            self._a_passage_s_theme_is_on_the_theme_path,
            self._a_passage_comes_after_its_theme_on_the_path,
            self._the_whole_command_passes_with_warnings_only,
            self._a_reading_deck_is_valid,
            self._a_question_id_is_used_once_in_the_deck,
            self._an_answer_is_an_option_number_or_true_or_false,
            self._two_to_four_options_and_questions,
            self._text_is_keyed_by_language_with_english,
            self._every_option_is_in_the_prompt_s_languages,
            self._a_sentence_has_text_and_in_this_script_a_reading,
            self._passage_text_is_never_asked_to_change,
            self._a_glossed_word_occurs_in_its_passage_letter_for_letter,
            self._a_glossary_entry_has_a_modern_form_reading_and_meaning,
            self._passages_are_only_for_a_reading_deck_and_cards_not,
            self._a_card_cannot_be_drilled_by_reading,
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


# From test_validate_romanisation.py.
# Romanisation (#47): a language's romanisation file, grammar rows'
# readings, and every reading in the scheme once the file exists.


HEAD_ROMANISATION = """\
schema: 1
id: {id}
name: Probe
kind: {kind}
language: {{ code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }}
native: {{ code: en, iso639_3: eng, name: English }}
license: CC-BY-SA-4.0
"""

ROMANISATION_ROMANISATION = """\
schema: 1
kind: romanisation
id: hi-romanisation
language: hi
scheme: "Popular: lowercase, no length or retroflex marks, spelled as said."
equivalents:
  - ["i", "ee", "ii"]
  - ["u", "oo", "uu"]
  - ["v", "w"]
"""


def grammar_romanisation(readings: str) -> str:
    return HEAD_ROMANISATION.format(id="hi-en-grammar-probe", kind="grammar") + """\
pattern:
  name: "Probe"
  slot_name: "person"
  slots: ["मैं", "तुम"]
  prompt: "{lemma} — {slot}"
  entries:
    - lemma: "जाना"
      key: jaanaa
      reading: "jana"
      gloss: "to go"
      forms: { "मैं": "जाता हूँ", "तुम": null }
""" + readings


class Romanisation(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def write(self, name: str, text: str) -> validate_decks.Report:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def assertRejected(self, report: validate_decks.Report, needle: str) -> None:
        self.assertTrue(any(needle in e for e in report.errors),
                        f"expected {needle!r} in {report.errors}")

    def _a_romanisation_file_is_valid(self) -> None:
        self.assertEqual(self.write("hi-romanisation.yaml", ROMANISATION_ROMANISATION).errors, [])

    def _its_groups_are_lowercase_spellings_in_one_group_each(self) -> None:
        for groups, needle in (
            ('  - ["i"]\n', "two or more"),
            ('  - ["i", "Ī"]\n', "lowercase ASCII"),
            ('  - ["i", "ee"]\n  - ["ee", "y"]\n', "already in"),
        ):
            with self.subTest(groups=groups):
                text = ROMANISATION_ROMANISATION.split("equivalents:\n")[0] + "equivalents:\n" + groups
                self.assertRejected(self.write("hi-romanisation.yaml", text), needle)

    def _its_name_is_the_language(self) -> None:
        self.assertRejected(self.write("hi-roman.yaml", ROMANISATION_ROMANISATION), "id")

    def _grammar_readings_follow_the_forms(self) -> None:
        self.assertEqual(self.write("hi-en-grammar-probe.yaml", grammar_romanisation(
            '      readings: { "मैं": "jata hun" }\n')).errors, [])
        for readings, needle in (
            ('      readings: { "तुम": "jate ho" }\n', "no form"),
            ('      readings: { "हम": "x" }\n', "not a slot"),
            ('      readings: { "मैं": 3 }\n', "must be a reading"),
            ('      readings: {}\n', "is missing"),
        ):
            with self.subTest(readings=readings):
                self.assertRejected(self.write("hi-en-grammar-probe.yaml",
                                               grammar_romanisation(readings)), needle)

    def _with_the_file_every_reading_is_in_the_scheme(self) -> None:
        deck = HEAD_ROMANISATION.format(id="hi-en-probe", kind="vocab") + """\
cards:
  - id: hi-0001
    target: "थोड़ा"
    native: "a little"
    reading: "thoDaa"
"""
        # Without the language's file, any reading is let through.
        self.assertEqual(self.write("hi-en-probe.yaml", deck).errors, [])
        self.write("hi-romanisation.yaml", ROMANISATION_ROMANISATION)
        self.assertRejected(self.write("hi-en-probe.yaml", deck),
                            "not in the hi romanisation")
        self.assertEqual(self.write("hi-en-probe.yaml",
                                    deck.replace("thoDaa", "thoda")).errors, [])

    def _with_the_file_grammar_readings_are_in_the_scheme_too(self) -> None:
        self.write("hi-romanisation.yaml", ROMANISATION_ROMANISATION)
        self.assertEqual(self.write("hi-en-grammar-probe.yaml", grammar_romanisation(
            '      readings: { "मैं": "jata hun" }\n')).errors, [])
        for readings in (
            '      readings: { "मैं": "jaatā hun" }\n',
            '      readings: { "मैं": ["Jata hun"] }\n',
        ):
            with self.subTest(readings=readings):
                self.assertRejected(
                    self.write("hi-en-grammar-probe.yaml", grammar_romanisation(readings)),
                    "not in the hi romanisation")

    def test_a_romanisation_file_and_its_readings(self) -> None:
        cases = (
            self._a_romanisation_file_is_valid,
            self._its_groups_are_lowercase_spellings_in_one_group_each,
            self._its_name_is_the_language,
            self._grammar_readings_follow_the_forms,
            self._with_the_file_every_reading_is_in_the_scheme,
            self._with_the_file_grammar_readings_are_in_the_scheme_too,
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


# From test_validate_script.py.
# Script guides (#30, ADR-0016): a script's recurring features, checked on
# their own. Described in docs/DECK-FORMAT.md.


GOOD = """\
schema: 1
kind: script
id: bn-script
language: bn
name: "How Bengali script works"
intro: "Most of what looks strange is a few ideas used again and again."
features:
  - id: headline
    name: "The headline"
    term: "মাত্রা"
    reading: "matra"
    example: "ক"
    text: "Most letters hang from a line along the top."
    letters: ["ক", "ঘ", "ত"]
  - id: knot
    name: "The knot"
    example: "ত"
    text: "A small loop that tells letters apart."
"""


class ScriptGuideTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir)

    def errors(self, text: str, name: str = "bn-script", folder: str = "bn") -> list[str]:
        (self.dir / folder).mkdir(exist_ok=True)
        path = self.dir / folder / f"{name}.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path).errors

    def _a_good_guide_passes(self) -> None:
        self.assertEqual(self.errors(GOOD), [])

    def _the_id_follows_the_language_and_the_folder(self) -> None:
        self.assertTrue(any("bn-script" in e for e in self.errors(
            GOOD.replace("id: bn-script", "id: bengali"), name="bengali")))
        self.assertTrue(any("is in hi/" in e for e in self.errors(GOOD, folder="hi")))

    def _a_guide_needs_a_name_an_intro_and_features(self) -> None:
        self.assertTrue(any("name" in e for e in self.errors(
            GOOD.replace('name: "How Bengali script works"', 'name: ""'))))
        self.assertTrue(any("intro" in e for e in self.errors(
            GOOD.replace('intro: "Most of what looks strange is a few ideas used again and again."\n', ''))))
        self.assertTrue(any("non-empty list" in e for e in self.errors(
            GOOD.split("features:")[0] + "features: []\n")))

    def _a_feature_needs_an_id_a_name_an_example_and_text(self) -> None:
        self.assertTrue(any("listed twice" in e for e in self.errors(
            GOOD.replace("id: knot", "id: headline"))))
        self.assertTrue(any("needs example" in e for e in self.errors(
            GOOD.replace('    example: "ত"\n', ''))))
        self.assertTrue(any("term" in e for e in self.errors(
            GOOD.replace('term: "মাত্রা"', 'term: ""'))))
        self.assertTrue(any("needs a term" in e for e in self.errors(
            GOOD.replace('    term: "মাত্রা"\n', ''))))
        self.assertTrue(any("reading" in e for e in self.errors(
            GOOD.replace('reading: "matra"', 'reading: ""'))))
        self.assertTrue(any("letters" in e for e in self.errors(
            GOOD.replace('letters: ["ক", "ঘ", "ত"]', 'letters: "ক"'))))

    def _unknown_fields_fail(self) -> None:
        self.assertTrue(any("unknown field" in e for e in self.errors(GOOD + "extra: 1\n")))

    def _the_core_and_its_english_layer_are_valid(self) -> None:
        hi = validate_decks.ROOT / "decks" / "hi"
        for path in (hi / "hi-perso-arabic-script.yaml",
                     hi / "en" / "hi-en-perso-arabic-script.yaml"):
            self.assertEqual(validate_decks.validate(path).errors, [], path.name)

    def test_a_script_guide_follows_its_language_and_folder(self) -> None:
        cases = (
            self._a_good_guide_passes,
            self._the_id_follows_the_language_and_the_folder,
            self._a_guide_needs_a_name_an_intro_and_features,
            self._a_feature_needs_an_id_a_name_an_example_and_text,
            self._unknown_fields_fail,
            self._the_core_and_its_english_layer_are_valid,
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


SECOND = GOOD.replace("id: bn-script", "id: bn-sylheti-script")
# A deck of the language in a second script, which is all the guide's check
# reads of it.
SECOND_DECK = 'language: { code: "bn", script: "bengali", scripts: ["bengali", "sylheti"] }\n'


class OtherScriptGuideTest(unittest.TestCase):
    """A language written in several scripts has a guide for each: `<code>-script`
    is the default, `<code>-<script>-script` the guide of another (ADR-0016)."""

    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir)
        (self.dir / "bn").mkdir()

    def errors(self, text: str, name: str, deck: str | None = SECOND_DECK) -> list[str]:
        if deck is not None:
            (self.dir / "bn" / "bn-letters.yaml").write_text(deck, encoding="utf-8")
        path = self.dir / "bn" / f"{name}.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path).errors

    def _a_guide_of_another_script_of_the_course_passes(self) -> None:
        self.assertEqual(self.errors(SECOND, "bn-sylheti-script"), [])

    def _a_hyphenated_script_is_the_courses_underscored_one(self) -> None:
        deck = SECOND_DECK.replace("sylheti", "perso_arabic")
        text = GOOD.replace("id: bn-script", "id: bn-perso-arabic-script")
        self.assertEqual(self.errors(text, "bn-perso-arabic-script", deck), [])

    def _its_script_must_be_one_the_course_is_written_in(self) -> None:
        errors = self.errors(SECOND, "bn-sylheti-script", SECOND_DECK.replace("sylheti", "other"))
        self.assertTrue(any("sylheti" in e and "none of the decks" in e for e in errors), errors)
        self.assertTrue(any("none of the decks" in e for e in self.errors(
            SECOND, "bn-sylheti-script", None)))

    def _a_guide_id_has_the_language_and_script_only(self) -> None:
        for bad in ("bn-sylheti", "bn-script-sylheti", "xx-sylheti-script"):
            text = GOOD.replace("id: bn-script", f"id: {bad}")
            self.assertTrue(any("<script>-script" in e for e in self.errors(text, bad)), bad)

    def _a_deck_never_has_an_id_ending_in_script(self) -> None:
        deck = 'schema: 1\nid: bn-letters-script\nname: "x"\nlicense: "CC0-1.0"\n'
        self.assertTrue(any("ends in -script" in e for e in self.errors(
            deck, "bn-letters-script", None)))

    def _the_layer_of_another_script_is_named_for_it(self) -> None:
        (self.dir / "bn" / "en").mkdir()
        core = SECOND.replace("kind: script\n", 'kind: script\npart: "core"\n')
        core = core.replace('name: "How Bengali script works"\n', "").replace(
            'intro: "Most of what looks strange is a few ideas used again and again."\n', "")
        core = core.replace('    name: "The headline"\n', "").replace(
            '    text: "Most letters hang from a line along the top."\n', "").replace(
            '    name: "The knot"\n', "").replace(
            '    text: "A small loop that tells letters apart."\n', "")
        self.errors(core, "bn-sylheti-script")
        layer = (
            'schema: 1\nid: "bn-en-sylheti-script"\nkind: "layer"\n'
            'core: "bn-sylheti-script"\n'
            'native: { code: "en", iso639_3: "eng", name: "English" }\n'
            'name: "How Sylheti works"\nintro: "A few ideas."\n'
            'features:\n  "headline":\n    name: "The headline"\n    text: "Along the top."\n'
            '  "knot":\n    name: "The knot"\n    text: "A small loop."\n')
        path = self.dir / "bn" / "en" / "bn-en-sylheti-script.yaml"
        path.write_text(layer, encoding="utf-8")
        self.assertEqual(validate_decks.validate(path).errors, [])
        path.write_text(layer.replace("bn-en-sylheti-script", "bn-en-script", 1),
                        encoding="utf-8")
        self.assertTrue(any("bn-en-sylheti-script" in e for e in
                            validate_decks.validate(path).errors))

    def test_another_scripts_guide_is_named_for_it(self) -> None:
        cases = (
            self._a_guide_of_another_script_of_the_course_passes,
            self._a_hyphenated_script_is_the_courses_underscored_one,
            self._its_script_must_be_one_the_course_is_written_in,
            self._a_guide_id_has_the_language_and_script_only,
            self._a_deck_never_has_an_id_ending_in_script,
            self._the_layer_of_another_script_is_named_for_it,
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


# From test_validate_target_scripts.py.
# A card's spelling in a language's other scripts (`target_scripts`, #623),
# the language block's `scripts`, and the script id `perso_arabic`.
#
# Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
# PyYAML, like the validator itself.


HOUSE_TARGET_SCRIPTS = "zz-9001"

HINDUSTANI = dict(LANGUAGE, script="devanagari", scripts=["devanagari", "perso_arabic"])
BOOK = {"id": "zz-9601", "target": "किताब", "reading": "kitāb", "native": "book",
        "pos": "noun", "target_scripts": {"perso_arabic": "کتاب"}}


def deck_target_scripts(book: dict | None = None, language: dict | None = None, **card_fields) -> dict:
    book = dict(book or BOOK, **card_fields)
    return single(cards=[book], language=dict(language or HINDUSTANI))


class CaseTargetScripts(B1Case):

    def single(self, **kwargs) -> list[str]:
        self.put(EXTRA, deck_target_scripts(**kwargs))
        return self.errors(EXTRA)


class TargetScripts(CaseTargetScripts):

    def _a_card_with_its_second_spelling_is_valid(self) -> None:
        self.assertEqual(self.single(), [])

    def _a_language_with_perso_arabic_as_its_script_is_valid(self) -> None:
        errors = self.single(language=dict(LANGUAGE, script="perso_arabic"))
        self.assertNotIn("language: script must be a lowercase script name, such as "
                         "'devanagari', got 'perso_arabic'", errors)

    def _a_card_without_it_is_valid(self) -> None:
        book = {k: v for k, v in BOOK.items() if k != "target_scripts"}
        self.assertEqual(self.single(book=book), [])

    def _the_key_is_one_of_the_languages_other_scripts(self) -> None:
        errors = self.single(target_scripts={"shahmukhi": "کتاب"})
        self.assertIn("card zz-9601: target_scripts key 'shahmukhi' is not one of the "
                      "language's other scripts (perso_arabic)", errors)

    def _the_first_script_is_target_not_a_key(self) -> None:
        errors = self.single(target_scripts={"devanagari": "किताबें"})
        self.assertIn("card zz-9601: target_scripts key 'devanagari' is not one of the "
                      "language's other scripts (perso_arabic)", errors)

    def _the_language_must_list_its_scripts(self) -> None:
        errors = self.single(language=dict(LANGUAGE, script="devanagari"))
        self.assertIn("card zz-9601: target_scripts needs the language block to list "
                      "its scripts, `scripts: [<first>, perso_arabic]`", errors)

    def _the_letters_are_in_the_scripts_blocks(self) -> None:
        errors = self.single(target_scripts={"perso_arabic": "किताब"})
        self.assertIn("card zz-9601: target_scripts.perso_arabic has letters that are "
                      "not in perso_arabic: 'किताब'", errors)
        errors = self.single(target_scripts={"perso_arabic": "kitab"})
        self.assertTrue(any("not in perso_arabic" in e for e in errors), errors)

    def _the_nastaliq_letters_and_marks_are_arabic(self) -> None:
        for word in ("ٹھنڈا", "بھائی", "ہے", "گھر", "ں", "کتاب۔", "آپ کیسے ہیں؟"):
            with self.subTest(word=word):
                self.assertEqual(self.single(target_scripts={"perso_arabic": word}), [])

    def _the_value_differs_from_target(self) -> None:
        errors = self.single(target_scripts={"perso_arabic": "किताब"})
        self.assertIn("card zz-9601: target_scripts.perso_arabic is the same as target; "
                      "give a spelling in perso_arabic", errors)

    def _a_mapping_of_text(self) -> None:
        for bad in ("کتاب", ["کتاب"], {}, None):
            with self.subTest(bad=bad):
                self.assertIn("card zz-9601: target_scripts must be a mapping of script "
                              "id to the word in that script", self.single(target_scripts=bad))
        errors = self.single(target_scripts={"perso_arabic": 5})
        self.assertIn("card zz-9601: target_scripts.perso_arabic must be a non-empty "
                      "string", errors)
        errors = self.single(target_scripts={"Perso Arabic": "کتاب"})
        self.assertIn("card zz-9601: target_scripts key 'Perso Arabic' is not a script id",
                      errors)

    def _chinese_traditional_is_in_the_cjk_blocks(self) -> None:
        language = dict(LANGUAGE, script="han", scripts=["han", "han_traditional"])
        book = {"id": "zz-9601", "target": "书", "reading": "shū", "native": "book",
                "target_scripts": {"han_traditional": "書"}}
        self.assertEqual(self.single(book=book, language=language), [])
        errors = self.single(book=book, language=language,
                             target_scripts={"han_traditional": "kitab"})
        self.assertTrue(any("not in han_traditional" in e for e in errors), errors)

    def _a_script_with_no_blocks_is_not_checked_for_letters(self) -> None:
        language = dict(LANGUAGE, script="devanagari", scripts=["devanagari", "ol_chiki"])
        errors = self.single(language=language, target_scripts={"ol_chiki": "ᱠᱤᱛᱟᱵ"})
        self.assertEqual(errors, [])

    def _a_core_card_carries_it(self) -> None:
        def change(d: dict) -> None:
            d["language"] = dict(HINDUSTANI)
            card(d, HOUSE_TARGET_SCRIPTS)["target"] = "घर"
            card(d, HOUSE_TARGET_SCRIPTS)["target_scripts"] = {"perso_arabic": "گھر"}
        self.edit(CORE, change)
        self.assertNotIn("target_scripts", " ".join(self.errors(CORE)))
        self.edit(CORE, lambda d: card(d, HOUSE_TARGET_SCRIPTS).update(
            target_scripts={"perso_arabic": "घर"}))
        self.assertTrue(any("is the same as target" in e for e in self.errors(CORE)))

    def _a_layer_may_not_hold_it_on_a_card_the_core_wrote(self) -> None:
        self.edit(LAYER, lambda d: d["cards"][HOUSE_TARGET_SCRIPTS].update(
            target_scripts={"perso_arabic": "گھر"}))
        self.assertTrue(any("target_scripts" in e for e in self.errors(LAYER)))

    def _the_first_script_is_the_blocks_own(self) -> None:
        language = dict(HINDUSTANI, scripts=["perso_arabic", "devanagari"])
        self.assertIn("language: scripts starts with the block's script, 'devanagari', "
                      "got 'perso_arabic' first", self.single(language=language))

    def _two_or_more_names_none_twice(self) -> None:
        for bad in (["devanagari"], "devanagari", ["devanagari", 5]):
            with self.subTest(bad=bad):
                errors = self.single(language=dict(HINDUSTANI, scripts=bad))
                self.assertTrue(any(e.startswith("language: scripts must list two or more")
                                    for e in errors), errors)
        errors = self.single(language=dict(HINDUSTANI, scripts=["devanagari", "devanagari"]))
        self.assertIn("language: scripts lists a script twice", errors)

    def _an_underscore_is_part_of_a_script_id(self) -> None:
        for name in ("perso_arabic", "ol_chiki", "meitei_mayek", "perso-arabic", "han"):
            self.assertTrue(validate_decks.SCRIPT_RE.fullmatch(name), name)
        for name in ("Perso_Arabic", "perso__arabic", "_arabic", "arabic_", "perso arabic"):
            self.assertFalse(validate_decks.SCRIPT_RE.fullmatch(name), name)

    def test_a_target_script_is_another_script_of_the_language(self) -> None:
        cases = (
            self._a_card_with_its_second_spelling_is_valid,
            self._a_language_with_perso_arabic_as_its_script_is_valid,
            self._a_card_without_it_is_valid,
            self._the_key_is_one_of_the_languages_other_scripts,
            self._the_first_script_is_target_not_a_key,
            self._the_language_must_list_its_scripts,
            self._the_letters_are_in_the_scripts_blocks,
            self._the_nastaliq_letters_and_marks_are_arabic,
            self._the_value_differs_from_target,
            self._a_mapping_of_text,
            self._chinese_traditional_is_in_the_cjk_blocks,
            self._a_script_with_no_blocks_is_not_checked_for_letters,
            self._a_core_card_carries_it,
            self._a_layer_may_not_hold_it_on_a_card_the_core_wrote,
            self._the_first_script_is_the_blocks_own,
            self._two_or_more_names_none_twice,
            self._an_underscore_is_part_of_a_script_id,
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


# From test_validate_cjk.py.
# Readings beside Chinese, Japanese and Korean words in prose: a word in
# Han, kana or Hangul spans several 128-code-point blocks, and is one run
# with one reading after it, as an Arabic one is.


class CjkReadings(unittest.TestCase):

    def _one_reading_after_a_whole_word(self) -> None:
        for text in ("Say 天气 (tiānqì) here.",
                     "Say 안녕하세요 (annyeonghaseyo) here.",
                     "Say こんばんは (konbanwa) here.",
                     "Say 日本語 (nihongo) here."):
            self.assertEqual(vd._untransliterated(text, "en"), [], text)

    def _a_word_without_its_reading_is_one_run(self) -> None:
        self.assertEqual(vd._untransliterated("Say 天气 here.", "en"), ["天气"])
        self.assertEqual(vd._untransliterated("Say 안녕하세요 here.", "en"),
                         ["안녕하세요"])

    def _a_cores_own_script_needs_no_reading(self) -> None:
        own = vd._SCRIPT_BLOCK["kana"]
        self.assertEqual(vd._untransliterated("先生 です", "ja", own), [])
        own = vd._SCRIPT_BLOCK["hangul"]
        self.assertEqual(vd._untransliterated("학생이에요", "ko", own), [])

    def test_cjk_readings(self) -> None:
        cases = (
            self._one_reading_after_a_whole_word,
            self._a_word_without_its_reading_is_one_run,
            self._a_cores_own_script_needs_no_reading,
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


class RejectedAlikes(Case):
    """A core card's `not_sounds_like` and `not_looks_like` (#808): the
    offensive words whose sound-alike or look-alike pair a reviewer rejected."""

    def key_errors(self, key: str) -> list[str]:
        return [e for e in self.errors(CORE) if key in e]

    def test_a_list_of_ids_of_other_cards_is_accepted(self) -> None:
        for key in ("not_sounds_like", "not_looks_like"):
            with self.subTest(key):
                self.core(HOUSE, **{key: ["zz-9006"]})
                self.assertEqual(self.key_errors(key), [])

    def test_a_value_that_is_no_list_of_other_cards_is_refused(self) -> None:
        for value in ("zz-9006", [], [3], ["zz-9006", "zz-9006"], [HOUSE]):
            with self.subTest(repr(value)):
                self.core(HOUSE, not_sounds_like=value)
                self.assertTrue(self.key_errors("not_sounds_like"))


if __name__ == "__main__":
    unittest.main()


class TeachWarning(Case):
    """A core card's `warning` (#691): the one warning its teach card shows."""

    NOTES = [{"kind": "usage", "id": "polite"},
             {"kind": "homograph", "id": "other-house", "ref": "zz-9006"},
             {"kind": "lookalike", "id": "looks", "ref": "zz-9006"}]

    def warning_errors(self) -> list[str]:
        return [e for e in self.errors(CORE) if "warning" in e]

    def test_a_note_of_the_card_that_warns_is_named_by_its_id(self) -> None:
        for name in ("other-house", "looks"):
            with self.subTest(name):
                self.core(HOUSE, notes=self.NOTES, warning=name)
                self.assertEqual(self.warning_errors(), [])

    def test_a_note_with_no_id_is_named_by_its_place(self) -> None:
        # A core note needs an id; the place names it where a card has none.
        r = validate_decks.Report(Path("x.yaml"))
        validate_decks._check_warning(
            r, "card zz-1", "2", [validate_decks.Note(0, "1", "note", None),
                                  validate_decks.Note(1, "2", "homograph", "zz-2")], None)
        self.assertEqual(r.errors, [])

    def test_senses_and_none_are_values(self) -> None:
        self.core(HOUSE, senses=Senses.SENSES, warning="senses")
        self.assertEqual(self.warning_errors(), [])
        self.core(HOUSE, warning="none")
        self.assertEqual(self.warning_errors(), [])

    def test_senses_needs_the_card_to_have_senses(self) -> None:
        self.core(HOUSE, warning="senses")
        self.assertIn(f'card {HOUSE}: warning "senses" needs the card to have senses',
                      self.errors(CORE))

    def test_a_note_that_is_no_warning_or_is_missing_is_refused(self) -> None:
        # A usage note is not a pair, homograph or lookalike note.
        for name in ("polite", "nowhere"):
            with self.subTest(name):
                self.core(HOUSE, notes=self.NOTES, warning=name)
                errors = self.warning_errors()
                self.assertEqual(len(errors), 1, errors)
                self.assertIn(f"card {HOUSE}: warning {name!r} names no pair, "
                              f"homograph or lookalike note", errors[0])

    def test_it_must_be_text(self) -> None:
        for value in (3, True, ["senses"]):
            with self.subTest(repr(value)):
                self.core(HOUSE, warning=value)
                self.assertIn(f"card {HOUSE}: warning must be text naming a warning, "
                              f"got {value!r}", self.errors(CORE))

    def test_it_is_left_out_without_error(self) -> None:
        self.assertEqual(self.warning_errors(), [])
