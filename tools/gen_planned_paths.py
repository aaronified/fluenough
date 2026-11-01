#!/usr/bin/env python3
"""Writes the path files of the planned languages (#959), deterministically.

    python3 tools/gen_planned_paths.py            # write the path files
    python3 tools/gen_planned_paths.py --check    # exit 1 if a file differs

Each planned language gets decks/<code>/<code>-path.yaml with its full unit
list to B1, from the scheme's unit template (wiki/Plan-Language-Paths-Scheme.md):
the sounds, the first themes, the script (where the language has one the
learner must learn), then the other themes woven with the grammar of the
language's family, three milestones, and a placeholder listening and reading
passage for every planned unit. Only unit 1 is written (the phrasebook and
the first words); every other unit is a `planned:` unit.

The path files of the nine path-only courses and the four ancient courses
that already have a full plan (`WIRED`) are not rewritten: only their unit 1
is turned into the written unit.

The data below is deliberately conservative. A grammar topic is a generic
category name of the language's family or typology (cases, aspect, tones,
noun classes), taken from the scheme's own steps; no word, form or rule of a
language is stated. Sizes follow the plan (A1 700, A2 900, B1 1,200 words)
for living languages and `levels` for the ancient and reconstructed ones.
Pure Python 3 standard library.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# The unit-1 decks of every course: the phrasebook, the first words, the
# learner's added decks.
FIRST_WORDS = 10

# --------------------------------------------------------------------------
# Themes, in the usual order (taken from the existing paths). Weights are
# the relative sizes the existing paths give each theme; they are scaled to
# each level's size.
# --------------------------------------------------------------------------
A1_THEMES = [
    ("questions", 11), ("pronouns", 33), ("family", 25), ("numbers-1-20", 20),
    ("about-me", 7), ("everyday-verbs", 33), ("adverbs", 50), ("quantities", 30),
    ("describing", 40), ("time", 18), ("location", 14), ("more-verbs", 32),
    ("work", 19), ("numbers-big", 13), ("food", 64), ("groceries", 16),
    ("market", 7), ("directions", 12), ("transport", 8), ("body", 28),
    ("places", 42), ("things", 39), ("home", 19), ("clothes", 26), ("animals", 30),
]
A2_THEMES = [
    ("daily-life", 8), ("weather", 45), ("calendar", 15), ("festivals", 40),
    ("shopping", 55), ("illness", 50), ("eating-out", 9), ("cooking", 50),
    ("help", 6), ("school", 55), ("hobbies", 55), ("chores", 45),
    ("appearance", 55), ("verbs-3", 70), ("phone", 45), ("journey", 60),
    ("nature", 55), ("adjectives-2", 60), ("workplace", 50), ("geography", 50),
]
B1_THEMES = [
    ("health", 60), ("feelings", 60), ("news", 60), ("opinions", 55),
    ("travel", 60), ("services", 50), ("government", 45), ("technology", 55),
    ("careers", 55), ("environment", 55), ("agriculture", 55), ("cinema", 60),
    ("arts", 50), ("history", 50), ("weddings", 50), ("sports", 45),
    ("relationships", 50), ("housing", 45), ("emergencies", 40), ("law", 40),
    ("verbs-4", 70), ("abstract-words", 60),
]
# The first four A1 themes come before the script, as the scheme has it
# ("a course opens with words, not letters").
HEAD_THEMES = 4

# Themes of modern life left out of the ancient and reconstructed courses.
ANCIENT_EXCLUDE = {
    "groceries", "market", "transport", "eating-out", "shopping", "phone",
    "technology", "cinema", "news", "services", "careers", "workplace",
    "environment", "sports", "emergencies", "housing", "hobbies", "chores",
    "appearance", "school", "adjectives-2", "verbs-3", "daily-life", "help",
    "geography",
}

# How a theme reads in a passage's description (default: its id, spaced).
LABEL = {
    "questions": "yes, no and questions", "pronouns": "pronouns and people words",
    "numbers-1-20": "numbers 1 to 20", "about-me": "talking about yourself",
    "everyday-verbs": "everyday verbs", "numbers-big": "tens and big numbers",
    "more-verbs": "more verbs", "verbs-3": "more daily actions",
    "verbs-4": "story actions", "adjectives-2": "describing a room",
    "daily-life": "a day", "eating-out": "eating out",
    "abstract-words": "ideas and values", "describing": "describing things and feelings",
}


def label(theme: str) -> str:
    return LABEL.get(theme, theme.replace("-", " "))


# --------------------------------------------------------------------------
# Grammar, by family or typology. Each entry is (unit name, [topics]): a unit
# `<code>-grammar-<name>` teaching those topics. Topic names are generic
# categories, taken from the scheme's steps for the family.
# --------------------------------------------------------------------------
G = {
    "romance": {
        "a1": [("articles-gender", ["articles", "gender-number"]),
               ("be-verbs", ["be-verbs"]),
               ("present-regular", ["present-regular"]),
               ("present-irregular", ["present-irregular"]),
               ("prepositions", ["prepositions"])],
        "a2": [("object-pronouns", ["object-pronouns"]),
               ("reflexives", ["reflexive-verbs"]),
               ("past", ["past-perfective", "past-imperfective"]),
               ("future-conditional", ["future", "conditional"]),
               ("imperatives", ["imperative"]),
               ("comparison", ["comparison"])],
        "b1": [("subjunctive", ["subjunctive-present", "subjunctive-past"]),
               ("compound-tenses", ["compound-tenses"]),
               ("relative-clauses", ["relative-clauses"]),
               ("passive", ["passive"]),
               ("conditional-clauses", ["conditional-clauses"]),
               ("reported-speech", ["reported-speech"])],
    },
    "germanic": {
        "a1": [("articles-gender", ["articles", "gender-number"]),
               ("word-order", ["v2-word-order"]),
               ("present", ["present-tense"]),
               ("be-and-have", ["be-and-have"])],
        "a2": [("modals", ["modal-verbs"]),
               ("particle-verbs", ["separable-particle-verbs"]),
               ("past", ["perfect-tense", "simple-past"]),
               ("imperatives", ["imperative"]),
               ("comparison", ["comparison"])],
        "b1": [("subordinate-clauses", ["subordinate-clause-order"]),
               ("passive", ["passive"]),
               ("relative-clauses", ["relative-clauses"]),
               ("conditional-clauses", ["conditional-clauses"]),
               ("reported-speech", ["reported-speech"])],
    },
    "slavic": {
        "a1": [("gender", ["grammatical-gender"]),
               ("present", ["present-tense"]),
               ("cases-1", ["nominative", "accusative", "prepositional-locative"]),
               ("be-verb", ["be-verb"])],
        "a2": [("cases-2", ["genitive", "dative", "instrumental"]),
               ("past", ["past-tense"]),
               ("aspect", ["aspect-pairs"]),
               ("future", ["future"]),
               ("imperatives", ["imperative"]),
               ("comparison", ["comparison"])],
        "b1": [("verbs-of-motion", ["verbs-of-motion"]),
               ("numerals", ["numerals-with-cases"]),
               ("participles", ["participles"]),
               ("conditional", ["conditional"]),
               ("relative-clauses", ["relative-clauses"]),
               ("reported-speech", ["reported-speech"])],
    },
    "greek": {
        "a1": [("articles-gender", ["articles", "gender-number"]),
               ("present", ["present-tense"]),
               ("cases-1", ["nominative", "accusative"]),
               ("be-verb", ["be-verb"])],
        "a2": [("cases-2", ["genitive", "vocative"]),
               ("past", ["aorist", "imperfect"]),
               ("aspect", ["aspect"]),
               ("future", ["future"]),
               ("imperatives", ["imperative"]),
               ("comparison", ["comparison"])],
        "b1": [("subjunctive", ["subjunctive-particle"]),
               ("passive", ["passive-voice"]),
               ("relative-clauses", ["relative-clauses"]),
               ("conditional-clauses", ["conditional-clauses"]),
               ("reported-speech", ["reported-speech"])],
    },
    "semitic": {
        "a1": [("roots", ["root-and-pattern"]),
               ("gender-agreement", ["gender-agreement"]),
               ("nominal-sentences", ["nominal-sentences"]),
               ("present", ["present-tense"])],
        "a2": [("past", ["past-tense"]),
               ("future", ["future-tense"]),
               ("construct-state", ["construct-state"]),
               ("pronoun-suffixes", ["pronoun-suffixes"]),
               ("comparison", ["comparison"]),
               ("imperatives", ["imperative"])],
        "b1": [("verb-patterns", ["verb-patterns"]),
               ("plurals", ["plural-forms"]),
               ("relative-clauses", ["relative-clauses"]),
               ("conditional-clauses", ["conditional-clauses"]),
               ("passive", ["passive"]),
               ("reported-speech", ["reported-speech"])],
    },
    "uralic": {
        "a1": [("suffix-logic", ["suffix-logic"]),
               ("vowel-harmony", ["vowel-harmony"]),
               ("present", ["present-tense"]),
               ("possessive", ["possessive-suffixes"])],
        "a2": [("local-cases", ["local-cases"]),
               ("past", ["past-tense"]),
               ("negation", ["negation"]),
               ("imperatives", ["imperative"]),
               ("conditional", ["conditional"])],
        "b1": [("further-cases", ["further-cases"]),
               ("participles", ["participles"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("passive", ["passive"]),
               ("reported-speech", ["reported-speech"])],
    },
    "turkic": {
        "a1": [("word-order", ["sov-word-order"]),
               ("vowel-harmony", ["vowel-harmony"]),
               ("suffix-logic", ["suffix-logic"]),
               ("present", ["present-tense"]),
               ("possessive", ["possessive-suffixes"])],
        "a2": [("locative-cases", ["locative-cases"]),
               ("past", ["past-tense", "reported-past"]),
               ("negation", ["negation"]),
               ("imperatives", ["imperative"]),
               ("conditional", ["conditional"])],
        "b1": [("participles", ["participles"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("passive-causative", ["passive", "causative"]),
               ("reported-speech", ["reported-speech"])],
    },
    "basque": {
        "a1": [("sounds-spelling", ["spelling"]),
               ("be-verbs", ["be-verbs"]),
               ("present", ["present-tense"]),
               ("ergative", ["ergative-absolutive"])],
        "a2": [("auxiliaries", ["auxiliary-verbs"]),
               ("cases", ["case-suffixes"]),
               ("past", ["past-tense"]),
               ("imperatives", ["imperative"]),
               ("conditional", ["conditional"])],
        "b1": [("subordinate-clauses", ["subordinate-clauses"]),
               ("participles", ["participles"]),
               ("relative-clauses", ["relative-clauses"]),
               ("reported-speech", ["reported-speech"])],
    },
    "celtic": {
        "a1": [("word-order", ["vso-word-order"]),
               ("be-verbs", ["two-be-verbs"]),
               ("mutations", ["lenition", "eclipsis"]),
               ("prepositional-pronouns", ["prepositional-pronouns"])],
        "a2": [("past", ["past-tense"]),
               ("present", ["present-tense"]),
               ("future", ["future"]),
               ("genitive", ["genitive-case"]),
               ("verbal-noun", ["verbal-noun"]),
               ("imperatives", ["imperative"])],
        "b1": [("conditional", ["conditional"]),
               ("relative-clauses", ["relative-clauses"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("comparison", ["comparison"]),
               ("reported-speech", ["reported-speech"])],
    },
    "sinitic": {
        "a1": [("word-order", ["word-order"]),
               ("classifiers", ["classifiers"]),
               ("sentence-final-particles", ["sentence-final-particles"]),
               ("negation", ["negation"])],
        "a2": [("aspect-markers", ["aspect-markers"]),
               ("complements", ["complements"]),
               ("questions", ["question-forms"]),
               ("comparison", ["comparison"]),
               ("time-and-place", ["time-and-place-order"])],
        "b1": [("written-colloquial", ["written-and-colloquial"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("passive", ["passive"]),
               ("reported-speech", ["reported-speech"])],
    },
    "kra_dai": {
        "a1": [("word-order", ["word-order"]),
               ("polite-particles", ["polite-particles"]),
               ("classifiers", ["classifiers"]),
               ("negation", ["negation"])],
        "a2": [("aspect-markers", ["aspect-markers"]),
               ("questions", ["question-forms"]),
               ("comparison", ["comparison"]),
               ("imperatives", ["imperative"])],
        "b1": [("register", ["register"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("passive", ["passive"]),
               ("reported-speech", ["reported-speech"])],
    },
    "vietnamese": {
        "a1": [("word-order", ["word-order"]),
               ("kinship-pronouns", ["kinship-pronouns"]),
               ("classifiers", ["classifiers"]),
               ("negation", ["negation"])],
        "a2": [("tense-markers", ["tense-markers"]),
               ("question-particles", ["question-particles"]),
               ("comparison", ["comparison"]),
               ("imperatives", ["imperative"])],
        "b1": [("register", ["register"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("passive", ["passive"]),
               ("reported-speech", ["reported-speech"])],
    },
    "austronesian_ph": {
        "a1": [("markers", ["ang-ng-sa-markers"]),
               ("word-order", ["word-order"]),
               ("negation", ["negation"])],
        "a2": [("focus", ["focus-system"]),
               ("aspect-affixes", ["aspect-affixes"]),
               ("linkers", ["linkers"]),
               ("imperatives", ["imperative"]),
               ("comparison", ["comparison"])],
        "b1": [("code-switching", ["code-switching"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("reported-speech", ["reported-speech"])],
    },
    "malay": {
        "a1": [("word-order", ["word-order"]),
               ("negation", ["negation"]),
               ("questions", ["question-forms"])],
        "a2": [("time-markers", ["time-markers"]),
               ("affixes", ["affixes"]),
               ("reduplication", ["reduplication"]),
               ("imperatives", ["imperative"]),
               ("comparison", ["comparison"])],
        "b1": [("register", ["register"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("passive", ["passive"]),
               ("reported-speech", ["reported-speech"])],
    },
    "bantu": {
        "a1": [("noun-classes-1", ["noun-classes"]),
               ("agreement", ["class-agreement"]),
               ("verb-slots", ["verb-slots"]),
               ("present", ["present-tense"])],
        "a2": [("tenses", ["tenses"]),
               ("negation", ["negation"]),
               ("object-markers", ["object-markers"]),
               ("imperatives", ["imperative"]),
               ("comparison", ["comparison"])],
        "b1": [("relatives", ["relative-forms"]),
               ("applicative-causative", ["applicative", "causative"]),
               ("passive", ["passive"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("reported-speech", ["reported-speech"])],
    },
    "chadic": {
        "a1": [("gender", ["grammatical-gender"]),
               ("pronouns-aspect", ["person-aspect-pronouns"]),
               ("be-and-have", ["be-and-have"]),
               ("negation", ["negation"])],
        "a2": [("plurals", ["plural-forms"]),
               ("tenses", ["tenses"]),
               ("imperatives", ["imperative"]),
               ("comparison", ["comparison"])],
        "b1": [("verb-grades", ["verb-grades"]),
               ("relative-clauses", ["relative-clauses"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("reported-speech", ["reported-speech"])],
    },
    "cushitic": {
        "a1": [("gender", ["grammatical-gender"]),
               ("focus-markers", ["focus-markers"]),
               ("declarative-waa", ["declarative-waa"]),
               ("negation", ["negation"])],
        "a2": [("verb-conjugation", ["verb-conjugation"]),
               ("tenses", ["tenses"]),
               ("imperatives", ["imperative"]),
               ("comparison", ["comparison"])],
        "b1": [("tone", ["tone"]),
               ("relative-clauses", ["relative-clauses"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("reported-speech", ["reported-speech"])],
    },
    "quechuan": {
        "a1": [("word-order", ["sov-word-order"]),
               ("suffix-logic", ["suffix-logic"]),
               ("present", ["present-tense"]),
               ("be-verb", ["be-verb"])],
        "a2": [("cases", ["case-suffixes"]),
               ("evidentials", ["evidentials"]),
               ("tenses", ["tenses"]),
               ("negation", ["negation"]),
               ("imperatives", ["imperative"])],
        "b1": [("subordination", ["subordination-suffixes"]),
               ("possession", ["possessive-suffixes"]),
               ("reported-speech", ["reported-speech"])],
    },
    # The ancient and reconstructed languages: reading courses.
    "latin": {
        "a1": [("case-system", ["case-system"]),
               ("first-second-declension", ["first-declension", "second-declension"]),
               ("present", ["present-tense"]),
               ("be-verb", ["be-verb"])],
        "a2": [("third-declension", ["third-declension"]),
               ("adjectives", ["adjective-agreement"]),
               ("perfect", ["perfect-tense"]),
               ("imperfect-future", ["imperfect-tense", "future"]),
               ("imperatives-infinitives", ["imperative", "infinitive"])],
        "b1": [("subjunctive", ["subjunctive"]),
               ("participles", ["participles"]),
               ("ablative-absolute", ["ablative-absolute"]),
               ("relative-clauses", ["relative-clauses"]),
               ("indirect-speech", ["indirect-speech"]),
               ("passive", ["passive-voice"])],
    },
    "vedic": {
        "a1": [("case-system", ["case-system"]),
               ("a-stems", ["a-stem-nouns"]),
               ("present-system", ["present-system"])],
        "a2": [("other-stems", ["other-noun-stems"]),
               ("aorist-perfect", ["aorist", "perfect"]),
               ("imperatives", ["imperative"]),
               ("participles", ["participles"]),
               ("compounds", ["compounds"])],
        "b1": [("moods", ["subjunctive", "optative", "injunctive"]),
               ("infinitives", ["infinitives"]),
               ("particles", ["particles"]),
               ("relative-clauses", ["relative-clauses"])],
    },
    "old_english": {
        "a1": [("cases-genders", ["noun-genders", "case-system"]),
               ("strong-weak-nouns", ["strong-nouns", "weak-nouns"]),
               ("present", ["present-tense"]),
               ("be-verbs", ["be-verbs"])],
        "a2": [("strong-weak-verbs", ["strong-verbs", "weak-verbs"]),
               ("past", ["past-tense"]),
               ("demonstratives", ["demonstratives"]),
               ("adjective-forms", ["adjective-forms"]),
               ("imperatives", ["imperative"])],
        "b1": [("subjunctive", ["subjunctive"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("verbal-prefixes", ["verbal-prefixes"]),
               ("alliterative-verse", ["alliterative-verse"])],
    },
    "middle_english": {
        "a1": [("noun-endings", ["noun-endings"]),
               ("pronoun-forms", ["pronoun-forms"]),
               ("present", ["present-tense"]),
               ("be-verbs", ["be-verbs"])],
        "a2": [("verb-classes", ["strong-verbs", "weak-verbs"]),
               ("past", ["past-tense"]),
               ("adjective-forms", ["adjective-forms"]),
               ("imperatives", ["imperative"])],
        "b1": [("dialects", ["dialect-variation"]),
               ("french-borrowings", ["french-borrowings"]),
               ("subordinate-clauses", ["subordinate-clauses"]),
               ("negation", ["negation"])],
    },
}

# --------------------------------------------------------------------------
# Script units (planned, grammar only, after the first six themes): what a
# learner must learn to read the language. Languages in the Latin alphabet
# with nothing new have none.
# --------------------------------------------------------------------------
S = {
    "cyrillic": [("letters", ["cyrillic-letters"]), ("reading", ["reading-and-spelling"])],
    "cyrillic_latin": [("letters", ["cyrillic-letters"]), ("both-scripts", ["latin-and-cyrillic"])],
    "greek": [("letters", ["greek-letters"]), ("stress-marks", ["stress-marks"])],
    "hebrew_pointed": [("letters", ["hebrew-letters"]), ("vowel-points", ["niqqud"]),
                       ("unpointed", ["unvoweled-text"])],
    "hebrew_yiddish": [("letters", ["hebrew-letters"]), ("spelling", ["yiddish-spelling"])],
    "arabic": [("letters", ["arabic-letters"]), ("letter-forms", ["letter-forms"]),
               ("vowel-marks", ["vowel-marks"])],
    "thai": [("consonants", ["thai-consonants"]), ("vowels", ["thai-vowels"]),
             ("tone-rules", ["consonant-classes", "tone-rules"])],
    "han": [("characters-1", ["radicals"]), ("characters-2", ["common-characters"])],
    "devanagari": [("letters", ["devanagari-letters"]), ("conjuncts", ["conjunct-letters"]),
                   ("accent-marks", ["accent-marks"])],
    "old_english_letters": [("letters", ["old-english-letters"])],
}

# --------------------------------------------------------------------------
# The languages: code -> data. `grammar` is a key of G. `sound` lists extra
# topics of the sounds unit, `tones` makes a unit of its own, `genders` is
# the path's `genders` (omitted when None), `levels` the sizes of a small
# course, `ancient` marks a reading course, `note` quotes the scheme.
# --------------------------------------------------------------------------
def L(name, grammar, **kw):
    return dict(name=name, grammar=grammar, **kw)


LANGS = {
    "pt": L("Portuguese", "romance", genders=["m", "f"], sound=["nasal-vowels"],
            note="Choose Brazilian or European; nasal vowels."),
    "it": L("Italian", "romance", genders=["m", "f"], sound=["double-consonants"],
            note="Double consonants; essere/stare."),
    "ca": L("Catalan", "romance", genders=["m", "f"],
            extra={"a2": [("weak-pronouns", ["weak-pronouns"])]},
            note="Weak pronouns (pronoms febles); faster after Spanish/French."),
    "sv": L("Swedish", "germanic", genders=["common", "neuter"], sound=["pitch-accent"],
            extra={"a1": [("definite-suffix", ["definite-suffix"])]},
            note="Pitch accent; definite suffix; only genitive -s + pronoun case."),
    "nb": L("Norwegian (Bokmål)", "germanic", genders=["m", "f", "n"], sound=["pitch-accent"],
            extra={"a1": [("definite-suffix", ["definite-suffix"])]},
            note="Choose Bokmål; pitch accent; definite suffix; dialect listening late."),
    "yi": L("Yiddish", "germanic", genders=["m", "f", "n"], script="hebrew_yiddish",
            note="Hebrew alphabet (RTL); Hebrew-origin words spelled without vowels."),
    "ru": L("Russian", "slavic", genders=["m", "f", "n"], script="cyrillic", sound=["stress"],
            note="Cyrillic; stress shifts per word."),
    "pl": L("Polish", "slavic", genders=["m", "f", "n"], sound=["digraphs"],
            extra={"a2": [("vocative", ["vocative"])]},
            note="Digraphs (sz, cz, rz); vocative."),
    "hbs": L("Serbo-Croatian", "slavic", genders=["m", "f", "n"], script="cyrillic_latin",
             extra={"a2": [("vocative", ["vocative"])], "b1": [("pitch-accent", ["pitch-accent"])]},
             note="Serbian: Cyrillic + Latin, mostly ekavian; Croatian: Latin, ijekavian; vocative; pitch accent late."),
    "el": L("Greek (Modern)", "greek", genders=["m", "f", "n"], script="greek",
            note="Alphabet; stress marks; three genders."),
    "he": L("Hebrew", "semitic", genders=["m", "f"], script="hebrew_pointed",
            extra={"a2": [("binyanim", ["binyanim"])]},
            note="Script with niqqud (RTL); transition to unvoweled text; binyanim."),
    "fi": L("Finnish", "uralic", genders=[],
            extra={"a1": [("consonant-gradation", ["consonant-gradation"])]},
            note="~15 cases; consonant gradation; spoken vs. written gap."),
    "hu": L("Hungarian", "uralic", genders=[],
            extra={"a2": [("definite-conjugation", ["definite-and-indefinite-conjugation"])]},
            note="Definite vs. indefinite conjugation; ~18 cases."),
    "tr": L("Turkish", "turkic", genders=[],
            note="SOV; evidential -miş."),
    "eu": L("Basque", "basque", genders=[],
            note="No vowel harmony; ergative; auxiliary verb system."),
    "ga": L("Irish", "celtic", genders=["m", "f"], sound=["broad-and-slender"],
            note="Choose dialect (Connacht/Munster/Ulster); broad/slender spelling; VSO; initial mutations."),
    "ar": L("Arabic", "semitic", genders=["m", "f"], script="arabic",
            extra={"b1": [("dual", ["dual"]), ("number-noun", ["number-noun-agreement"])]},
            sound=["emphatics"],
            note="Choose dialect (Egyptian/Levantine) for speaking + MSA for reading; emphatics, ʿayn; script (RTL, letter forms)."),
    "yue": L("Cantonese", "sinitic", genders=[], script="han", tones=True,
             note="Jyutping + tones; classifiers; sentence-final particles; aspect markers; traditional + colloquial written characters."),
    "th": L("Thai", "kra_dai", genders=[], script="thai", tones=True,
            note="Tones; script (consonant classes, tone rules, no word spaces); polite particles; classifiers; aspect markers; register."),
    "vi": L("Vietnamese", "vietnamese", genders=[], tones=True,
            note="Tones + diacritics (choose North/South); kinship pronouns; classifiers; tense markers; question particles."),
    "fil": L("Filipino", "austronesian_ph", genders=[],
             note="Numbers (native + Spanish-derived); ang/ng/sa markers; focus system; aspect affixes; Taglish code-switching."),
    "ms": L("Malay", "malay", genders=[],
            note="Choose Malaysian or Indonesian; time markers (sudah/akan); affixes (ber-, me-, -kan, -i); reduplication; register."),
    "sw": L("Swahili", "bantu", genders=[],
            note="Noun classes (m-wa, ki-vi first); verb slots (subject-tense-object-root); tenses; negation; relatives; applicative/causative."),
    "ha": L("Hausa", "chadic", genders=["m", "f"], tones=True,
            note="Tones + vowel length (unmarked in Boko script); gender; person-aspect pronouns; plurals; verb grades."),
    "so": L("Somali", "cushitic", genders=["m", "f"],
            note="Gender; focus markers (baa/ayaa) + declarative waa; verb conjugation; tone (marks gender/case)."),
    "qu": L("Quechua", "quechuan", genders=[], sound=["ejectives-and-aspirates"],
            note="Choose variety (Southern: Cusco or Ayacucho); SOV; suffix logic; cases; evidentials; tenses; subordination suffixes."),
    # Ancient and reconstructed (owner, 2026-10-31): reading courses with
    # their own `levels`.
    "la": L("Latin", "latin", genders=["m", "f", "n"], ancient=True,
            levels={"A1": 600, "A2": 800, "B1": 1100}, sound=["classical-pronunciation", "vowel-length"],
            note="A reading course in the classical language."),
    "vsn": L("Vedic Sanskrit", "vedic", genders=["m", "f", "n"], ancient=True, script="devanagari",
             levels={"A1": 300, "A2": 400, "B1": 600}, sound=["pitch-accent"],
             note="A reading course in the language of the Vedic hymns."),
    "ang": L("Old English", "old_english", genders=["m", "f", "n"], ancient=True,
             script="old_english_letters", levels={"A1": 400, "A2": 600, "B1": 800},
             note="A reading course in West Saxon prose and verse."),
    "enm": L("Middle English", "middle_english", genders=[], ancient=True,
             levels={"A1": 350, "A2": 500, "B1": 700}, sound=["spelling-variation"],
             note="A reading course in the language of about 1100 to 1500."),
}

# Courses that already have a full all-planned path: only unit 1 changes.
WIRED = ["de", "eo", "mai", "ml", "or", "pa", "ta", "jbo", "isv",
         "gmy", "sux", "egy", "ine"]


# --------------------------------------------------------------------------
# Building the unit list
# --------------------------------------------------------------------------
def allocate(total: int, weights: list[int]) -> list[int]:
    """Splits `total` by `weights`, whole numbers, each 1 or more, summing
    exactly to `total` (largest remainder)."""
    n = len(weights)
    assert total >= n, "level too small for its units"
    s = sum(weights)
    raw = [total * w / s for w in weights]
    out = [max(1, int(r)) for r in raw]
    # Fix the sum: hand out or take back one at a time, by remainder.
    order = sorted(range(n), key=lambda i: (raw[i] - int(raw[i]), -i), reverse=True)
    i = 0
    while sum(out) < total:
        out[order[i % n]] += 1
        i += 1
    order_back = sorted(range(n), key=lambda i: (raw[i] - int(raw[i]), i))
    i = 0
    while sum(out) > total:
        k = order_back[i % n]
        if out[k] > 1:
            out[k] -= 1
        i += 1
    return out


def weave(themes: list, grammars: list) -> list:
    """Places each grammar unit after an even share of the theme units."""
    out: list = []
    g = len(grammars)
    n = len(themes)
    placed = 0
    for i, t in enumerate(themes):
        out.append(t)
        while placed < g and (i + 1) * (g + 1) >= (placed + 1) * n:
            out.append(grammars[placed])
            placed += 1
    out.extend(grammars[placed:])
    return out


def levels_of(lang: dict) -> dict:
    return lang.get("levels") or {"A1": 700, "A2": 900, "B1": 1200}


def grammar_of(lang: dict, level: str) -> list:
    base = list(G[lang["grammar"]][level])
    base += lang.get("extra", {}).get(level, [])
    return base


def build_units(code: str) -> list[dict]:
    """The language's units, in order. A unit is a dict with `kind` (written,
    theme, grammar), `id`, and for a theme `theme`, `words`; for a grammar
    unit `topics`; the last unit of a level has `milestone`."""
    lang = LANGS[code]
    ancient = lang.get("ancient", False)
    sizes = levels_of(lang)

    def themes_of(table: list) -> list:
        return [(t, w) for t, w in table if not (ancient and t in ANCIENT_EXCLUDE)]

    units: list[dict] = [{"kind": "written", "id": f"{code}-phrasebook", "words": FIRST_WORDS}]
    sound = ["sound-differences"] + lang.get("sound", [])
    units.append({"kind": "grammar", "id": f"{code}-sound-differences", "topics": sound})
    if lang.get("tones"):
        units.append({"kind": "grammar", "id": f"{code}-tones", "topics": ["tones"]})

    result_levels = []
    for level, table in (("A1", A1_THEMES), ("A2", A2_THEMES), ("B1", B1_THEMES)):
        themes = themes_of(table)
        words = allocate(sizes[level] - (FIRST_WORDS if level == "A1" else 0),
                         [w for _, w in themes])
        tunits = [{"kind": "theme", "id": f"{code}-{t}", "theme": t, "words": n}
                  for (t, _), n in zip(themes, words)]
        gunits = [{"kind": "grammar", "id": f"{code}-grammar-{name}", "topics": list(topics)}
                  for name, topics in grammar_of(lang, level.lower())]
        if level == "A1":
            head, rest = tunits[:HEAD_THEMES], tunits[HEAD_THEMES:]
            script = [{"kind": "grammar", "id": f"{code}-script-{name}", "topics": list(topics)}
                      for name, topics in S.get(lang.get("script", ""), [])]
            body = head + script + weave(rest, gunits)
        else:
            body = weave(tunits, gunits)
        body[-1]["milestone"] = level
        result_levels.append(body)
    for body in result_levels:
        units.extend(body)
    return units


# --------------------------------------------------------------------------
# Writing the YAML
# --------------------------------------------------------------------------
def q(text: str) -> str:
    return json.dumps(text, ensure_ascii=False)


def passages(code: str, unit: dict, lang: dict) -> list[str]:
    name = lang["name"]
    uid = unit["id"][len(code) + 1:]
    aloud = lang.get("ancient", False)
    if unit["kind"] == "theme":
        about = f"on the theme {label(unit['theme'])}"
    else:
        about = "showing " + ", ".join(t.replace("-", " ") for t in unit["topics"])
    heard = (f"A short passage in {name} {about}, read aloud" if aloud
             else f"A short spoken passage in {name} {about}")
    read = f"A short written text in {name} {about}"
    return [
        "    listening_passages:",
        f'      - {{ id: {q(uid + "-heard")}, text: {{ "en": {q(heard)} }} }}',
        "    reading_passages:",
        f'      - {{ id: {q(uid + "-text")}, text: {{ "en": {q(read)} }} }}',
    ]


def unit_lines(code: str, unit: dict, lang: dict) -> list[str]:
    if unit["kind"] == "written":
        return [f'  - decks: [{q(code + "-phrasebook")}, {q(code + "-first-words")}, "*"]',
                f'    words: {unit["words"]}']
    if unit["kind"] == "theme":
        head = (f'  - planned: {{ id: {q(unit["id"])}, theme: {q(unit["theme"])}, '
                f'words: {unit["words"]} }}')
    else:
        topics = ", ".join(q(t) for t in unit["topics"])
        head = f'  - planned: {{ id: {q(unit["id"])}, grammar: [{topics}] }}'
    lines = [head] + passages(code, unit, lang)
    if "milestone" in unit:
        lines.append(f'    milestone: {q(unit["milestone"])}')
    return lines


def header(code: str, lang: dict, units: list[dict]) -> list[str]:
    name = lang["name"]
    sizes = levels_of(lang)
    ancient = lang.get("ancient", False)
    out = [
        f"# The order {name} is taught in, one unit per line, from every language",
        f"# it is taught from: each deck is named by its core id, and a learner from",
        f"# English is taught {code}-en-<name> for {code}-<name> (ADR-0013, ADR-0036).",
        "#",
        f"# This is also {name}'s B1 plan (docs/DECK-FORMAT.md, \"The B1 plan\"): every",
        "# unit from the first words to B1, with its size in words, its grammar",
        "# topics, the three milestones, and for each planned unit its listening",
        "# and reading passages. The file is written by tools/gen_planned_paths.py",
        "# from the unit template of the language-paths scheme",
        "# (wiki/Plan-Language-Paths-Scheme.md) and the grammar of the language's",
        "# family; edit the generator's data, or take a unit over by hand once its",
        "# deck is written (#959).",
        "#",
        "# Unit 1 is written: the phrasebook and the first words (10 words). Every",
        "# other unit is planned, so the course teaches each as \"Coming\" until its",
        "# deck is written. The passages are placeholders: each describes its unit's",
        "# theme or grammar and is reworded when the passage is written.",
    ]
    if lang.get("note"):
        out += ["#", "# From the scheme, for this language: " + lang["note"]]
    if ancient:
        out += ["#", f"# A reading course (owner, 2026-10-31): {name} has no living speakers, so",
                "# the milestones A1, A2 and B1 mean three reading levels, and the sizes",
                f"# are `levels` ({sizes['A1']}, {sizes['A2']} and {sizes['B1']} words, a judgement,",
                "# low confidence) in place of the plan's 700, 900 and 1,200. Themes of",
                "# modern life are left out."]
    out += ["#", "# `alphabet` is empty: the validator takes only written decks there. When",
            "# the script decks are written, they are listed in it."]
    if lang.get("script"):
        out += ["# The script is taught in the units named `script`, after the first six",
                "# themes, as the scheme has it."]
    return out


def render(code: str) -> str:
    lang = LANGS[code]
    units = build_units(code)
    lines = header(code, lang, units)
    lines += ["schema: 1", 'kind: "path"', f"id: {q(code + '-path')}", f"language: {q(code)}",
              f'description: {q(lang["name"] + ": the planned path to B1. Only the phrasebook and the first words are written.")}']
    if lang.get("genders") is not None:
        lines.append("genders: [" + ", ".join(q(g) for g in lang["genders"]) + "]")
    if lang.get("levels"):
        lv = lang["levels"]
        lines.append(f'levels: {{ A1: {lv["A1"]}, A2: {lv["A2"]}, B1: {lv["B1"]} }}')
    lines += ["alphabet: []", "units:"]
    for unit in units:
        lines += unit_lines(code, unit, lang)
    lines.append('  - ["*"]')
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------
# Wiring unit 1 of the courses that already have a full all-planned path
# --------------------------------------------------------------------------
def wire_unit_one(code: str, text: str) -> str:
    """Turns the planned phrasebook unit into the written unit 1. A path
    already written that way is returned unchanged."""
    if f'decks: ["{code}-phrasebook"' in text:
        return text
    pattern = re.compile(
        rf'^  - planned: \{{ id: "{code}-phrasebook"[^\n]*\n(?:    [^\n]*\n)+', re.M)
    if not pattern.search(text):
        raise ValueError(f"{code}: no planned phrasebook unit to wire")
    new = (f"  # The first words are written: {code}-first-words is taught with the\n"
           f"  # phrasebook (10 words).\n"
           f'  - decks: ["{code}-phrasebook", "{code}-first-words", "*"]\n'
           f"    words: {FIRST_WORDS}\n")
    return pattern.sub(lambda m: new, text, count=1)


# --------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 if a file differs")
    ap.add_argument("--root", type=Path, default=ROOT, help="the repository root")
    args = ap.parse_args(argv)
    stale = 0
    for code in sorted(LANGS):
        path = args.root / "decks" / code / f"{code}-path.yaml"
        text = render(code)
        if not path.exists() or path.read_text(encoding="utf-8") != text:
            stale += 1
            if not args.check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
    for code in WIRED:
        path = args.root / "decks" / code / f"{code}-path.yaml"
        old = path.read_text(encoding="utf-8")
        text = wire_unit_one(code, old)
        if text != old:
            stale += 1
            if not args.check:
                path.write_text(text, encoding="utf-8")
    if args.check and stale:
        print(f"{stale} path file(s) differ from the generator", file=sys.stderr)
        return 1
    print(f"{len(LANGS)} paths generated, {len(WIRED)} unit 1s wired, {stale} changed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
