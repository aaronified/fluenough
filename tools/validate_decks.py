#!/usr/bin/env python3
"""Validate Fluenough deck files against schema 1.

Usage:
    python3 tools/validate_decks.py decks/
    python3 tools/validate_decks.py decks/es/es-en-core-100.yaml

    python3 tools/validate_decks.py --next-id bn
    python3 tools/validate_decks.py --private my-package/   # a private language
                                                            # package, folder or .fnzip
    python3 tools/validate_decks.py --jobs 1 decks/     # one process; the default
                                                        # is one worker per CPU

Requires only Python 3.11+ and PyYAML, so deck contributors need no Flutter
toolchain. Exits non-zero if any deck fails. See docs/DECK-FORMAT.md.
"""

from __future__ import annotations

import collections
import copy
import os
import re
import sys
import threading
import unicodedata
import datetime
import hashlib
import json
import struct
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).resolve().parent))

from rater_codes import rater_code  # noqa: E402

try:
    import yaml
except ModuleNotFoundError:
    sys.exit("error: PyYAML is required.  pip install pyyaml")

SCHEMA = 1
# On while `--private` checks a private language package (tools/validate_private.py):
# its ids are `fnpd-<code>-` rewritten as `<code>-`, so the checks that look
# at the repository's own decks beside the file are left out.
PRIVATE_MODE = False
PRIVATE_ID_MARKER = "fnpd-"
# Always used with fullmatch: `$` alone also matches before a trailing newline,
# so `re.match` would accept an id ending in "\n".
ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
LANG_RE = re.compile(r"^[a-z]{2,3}$")
BCP47_RE = re.compile(r"^[a-zA-Z]{2,3}(?:-[A-Za-z0-9]{2,8})*$")
ISO639_3_RE = re.compile(r"[a-z]{3}")

# A facts file must hold at least this many facts that make sense whatever the
# learner's interface language is: a month of one fact a day.
MIN_FACTS = 30

# The scripts the validator knows (ADR-0009). Any other lowercase name is
# accepted with a warning: the field is a hint, and a new language must not
# need a change here to be valid.
SCRIPTS = {
    "latin", "cyrillic", "greek", "arabic", "hebrew",
    "devanagari", "bengali", "gujarati", "gurmukhi", "odia",
    "telugu", "tamil", "kannada", "malayalam", "sinhala",
    "kana", "han", "han_simplified", "han_traditional", "hangul", "thai",
    "ipa", "braille", "other",
}
# The notations taught like languages: the IPA (ADR-0041) and braille
# (ADR-0043). Neither is spoken, so neither has a tts tag, and neither is
# taught towards a level, so neither path has a B1 plan.
NOTATION_SCRIPTS = {"ipa", "braille"}
# Scripts whose cards need no reading: they are read as written. The
# notations are read as written, and their courses are no languages with a
# romanisation: a braille cell's print equivalent is its meaning.
NO_READING = {"latin", "cyrillic", "greek"} | NOTATION_SCRIPTS
# A script id is lowercase words joined by a hyphen or, as the app's own
# list has it (`ol_chiki`, `meitei_mayek`, `perso_arabic`), an underscore (#623).
SCRIPT_RE = re.compile(r"[a-z]+(?:[-_][a-z]+)*")
_ARABIC_BLOCKS = ((0x0600, 0x06FF), (0x0750, 0x077F), (0x08A0, 0x08FF),
                  (0xFB50, 0xFDFF), (0xFE70, 0xFEFF))
# 々 (the repeat mark), 〆 and 〇 are kanji too: 人々, 〆切, 〇.
_HAN_BLOCKS = ((0x3005, 0x3007), (0x3400, 0x4DBF), (0x4E00, 0x9FFF),
               (0xF900, 0xFAFF), (0x20000, 0x2FA1F))
# Kana: hiragana, katakana (with the long-vowel mark ー and the middle dot ・),
# the small katakana extensions and halfwidth katakana. No kanji: a kana
# reading with a kanji in it is no reading (docs/DECK-FORMAT.md, Kanji).
_KANA_BLOCKS = ((0x3040, 0x309F), (0x30A0, 0x30FF), (0x31F0, 0x31FF),
                (0xFF66, 0xFF9F))
# The Unicode blocks a script's letters are in, for a card's `target_scripts`
# (#623). Perso-Arabic and Shahmukhi are written in the Arabic blocks, and
# Chinese, traditional or simplified, in the CJK ones. A script not listed
# here is not checked for its letters.
SCRIPT_BLOCKS = {
    "arabic": _ARABIC_BLOCKS, "perso_arabic": _ARABIC_BLOCKS,
    "shahmukhi": _ARABIC_BLOCKS,
    "kana": _KANA_BLOCKS,
    "han": _HAN_BLOCKS, "han_traditional": _HAN_BLOCKS,
    "han_simplified": _HAN_BLOCKS, "traditional": _HAN_BLOCKS,
    "simplified": _HAN_BLOCKS,
    "devanagari": ((0x0900, 0x097F), (0xA8E0, 0xA8FF)),
    "gurmukhi": ((0x0A00, 0x0A7F),),
    "bengali": ((0x0980, 0x09FF),),
    "latin": ((0x0041, 0x024F), (0x1E00, 0x1EFF)),
}
KINDS = {"vocab", "grammar", "facts", "situations", "themes", "numbers", "path", "sounds", "script",
         "reading", "rules", "layer", "resources", "phonetics", "gating",
         "creators", "topics", "sections", "recommendations"}
THEMES_KEYS = {"schema", "kind", "description", "themes"}
# A language's path (ADR-0013), one per language learnt (ADR-0036).
PATH_KEYS = {"schema", "kind", "id", "language", "description", "units", "alphabet",
             "regions", "genders", "levels"}
# Ends a path's unit to take decks the path does not list (#22).
WILDCARD = "*"
SOUNDS_KEYS = {"schema", "kind", "id", "language", "description", "contrasts"}
ROMANISATION_KEYS = {"schema", "kind", "id", "language", "scheme", "standard",
                     "typed", "equivalents"}
# The letters ISO 15919 adds to a-z, as the decks use them (ADR-0025): the
# long vowels, the retroflex and other dotted consonants, ô and ê, and the
# candrabindu m̐. Composed where Unicode has a composed letter.
ISO15919_LETTERS = "āīūēōṭḍṇṅñḷḻṟṛśṣṁḥôêẏġ"
ISO15919_MARKS = "\u0310\u0325\u035f"  # m̐, r̥, and the double macron of k͟h
# A romanisation (#47): lowercase letters, digits, spaces and plain
# punctuation. A language whose romanisation file names ISO 15919 also uses
# its letters; any other uses ASCII only.
ROMAN_RE = re.compile(r"[a-z0-9 '.,?!;:()/\-]+")
ISO_ROMAN_RE = re.compile(
    rf"[a-z0-9 '.,?!;:()/\-{ISO15919_LETTERS}{ISO15919_MARKS}]+")
ROMAN_PIECE_RE = re.compile(r"[a-z]+(?:[ '-][a-z]+)*")
ISO_PIECE_RE = re.compile(rf"[a-z{ISO15919_LETTERS}{ISO15919_MARKS}]+")
# A broad IPA transcription, without its slashes (ADR-0025): IPA letters,
# modifier letters, combining diacritics, length and stress marks, and
# spaces between words.
IPA_RE = re.compile(
    "[a-zæçðøħŋœθβχãẽĩõũɐ-ʯʰ-˿\u0300-\u036f ."
    "\u02e5-\u02e9\u203f|\u2016\u2191\u2193"
    "\u01c0-\u01c3\u207f\u2c71\ua71c]+")
CONTRAST_KEYS = {"id", "name", "pairs", "within_word"}
SCRIPT_KEYS = {"schema", "kind", "id", "language", "name", "intro", "features"}
FEATURE_KEYS = {"id", "name", "term", "reading", "ipa", "example", "text",
                "letters"}
# A script guide or sounds file may be split, like a deck, into a core and a
# layer per native language (#498): the core keeps the letters, the layer
# the text a learner reads.
GUIDE_KINDS = ("script", "sounds")
# Kinds of file that are not a written deck (as tools/deck_index.py NOT_DECKS).
NOT_DECK_KINDS = {"path", "facts", "situations", "numbers", "romanisation", "sounds", "script",
                  "resources", "phonetics", "gating", "creators", "topics",
                  "sections", "recommendations"}
# A language's phonetic rules (tools/derive_phonetic.py): the ordered rules
# that turn a card's broad `ipa` into its narrow `phonetic`. Only the tool
# reads it; the index does not list it and the app never fetches it.
PHONETICS_KEYS = {"schema", "kind", "id", "language", "variety", "description", "rules"}
PHONETIC_RULE_KEYS = {"id", "pattern", "replace", "source"}
# A language's resources file (#832): where else to learn it. At most this
# many suggestions, a line of at most this many characters each.
RESOURCES_KEYS = {"schema", "kind", "id", "language", "resources"}
RESOURCE_KEYS = {"id", "name", "url", "kind", "why"}
RESOURCE_KINDS = {"app", "game", "site", "book", "film", "music"}
MAX_RESOURCES = 3
MAX_RESOURCE_WHY = 160
GUIDE_LAYER_KEYS = {
    "script": {"schema", "id", "kind", "core", "native", "name", "intro", "features"},
    "sounds": {"schema", "id", "kind", "core", "native", "description", "contrasts"},
}
CODE_RE = re.compile(r"[a-z]{2,3}")
# `grammarUnderstood` is only for a rules table's cells (ADR-0036): a card or
# a ref that names it is refused.
MODES = {"recognition", "production", "listening", "grammar", "speaking",
         "grammarUnderstood"}
POS = {"noun", "verb", "adj", "adv", "phrase", "particle", "other", "pronoun"}
# A card of a script's decks may also be a letter or a digit (#522, step 7):
# Hear asks for what was heard. Only a card has it, never a sense or a rules
# deck's row.
SCRIPT_POS = {"letter", "digit"}

HEADER_KEYS = {
    "schema", "id", "name", "kind", "language", "native", "license",
    "authors", "source", "description", "tags", "cards", "pattern", "facts",
    "theme", "passages", "situations",
    "genre", "level", "hidden", "professional", "section", "weave", "pattern_family",
    "character_scheme",
}
CARD_KEYS = {
    "id", "target", "native", "reading", "ipa", "phonetic", "phonetic_source", "alt_target", "alt_native",
    "not_synonyms", "pos", "hears", "gender", "tags", "notes", "audio", "examples", "modes", "pair",
    "picture", "picture_ask", "phrasebook", "bases", "rules", "wiktionary",
    "register", "frequency",
    "audio_credit", "image", "image_credit", "target_scripts", "words",
    "source", "level", "creator", "legacy", "character",
}
# A ref lists a card written in another deck (ADR-0018). It may give its own
# native-side fields; what the card is in the language learned stays the
# card's own.
REF_KEYS = {
    "ref", "native", "reading", "ipa", "alt_native", "not_synonyms", "tags",
    "notes", "examples", "modes", "wiktionary",
}
PATTERN_KEYS = {"name", "slot_name", "slots", "prompt", "entries", "notes"}
FACT_KEYS = {"id", "text", "contrast", "tags", "source", "cards"}
# A language's situation sheets (#724): the icons the app draws, in the order
# of Today's buttons (lib/core/models/situation.dart), and a situation's keys.
SITUATION_ICONS = ("taxi", "shops", "eat", "doctor", "traffic", "rail")
SITUATION_KEYS = {"id", "icon", "title", "phrases", "words"}
PASSAGE_KEYS = {"id", "title", "sentences", "source", "theme", "questions", "glossary",
                "level", "creator", "legacy"}
SENTENCE_KEYS = {"text", "reading", "ipa"}
QUESTION_KEYS = {"id", "prompt", "options", "answer"}
GLOSS_KEYS = {"word", "modern", "reading", "ipa", "meaning", "note"}
EXAMPLE_KEYS = {"target", "native", "reading", "ipa", "bases", "source",
                "language", "sounds", "words", "target_scripts"}
# A reading question has this many options, and a passage this many
# questions (#98, ADR-0019).
CHOICES = range(2, 5)

# --- The B1 format: cores, layers, rules decks, notes, bases, plans ---------
# See ADR-0036 and docs/DECK-FORMAT.md. A core (`part: "core"`) holds what
# belongs to the language learnt; a layer (`kind: "layer"`) what belongs to
# one native language. Merged, they are the deck the layer's id names.
CORE_HEADER_KEYS = {"schema", "id", "part", "kind", "language", "license",
                    "authors", "source", "tags", "theme", "cards", "pattern",
                    "table", "rules",
                    "genre", "level", "hidden", "professional", "section", "weave",
                    "pattern_family", "character_scheme"}
LAYER_HEADER_KEYS = {"schema", "id", "kind", "core", "native", "name",
                     "description", "license", "authors", "source", "tags",
                     "cards", "pattern", "table", "rules"}
CORE_KINDS = ("vocab", "grammar", "rules")
CORE_CARD_KEYS = {"id", "target", "reading", "ipa", "phonetic",
                  "phonetic_source", "alt_target", "pos", "hears",
                  "gender", "tags", "audio", "examples", "modes", "picture",
                  "picture_ask",
                  "notes", "phrasebook", "bases", "rules", "register", "frequency",
                  "synonyms", "antonyms", "collocations", "confusables", "forms",
                  "senses", "audio_credit", "image", "image_credit",
                  "target_scripts", "words", "warning", "not_sounds_like",
                  "not_looks_like", "source", "level", "creator", "legacy",
                  "character"}
CORE_REF_KEYS = {"ref", "reading", "ipa", "tags", "modes", "examples", "notes"}
# A set card (DECK-FORMAT.md, Set cards; #506, #515): a closed group shown
# together before its members are drilled. It is a card of a vocab core,
# `kind: "set"`, its members named by ref, or for a rules table, a rule and
# one fixed value of the table, the members coming from the table ("Rule +
# axis", owner, 2026-10-16). Its name and explanation are in each layer.
SET_KEYS = {"id", "kind", "members", "shown"}
# A set of one slot across the words (`{ rule, person: ... }`) names the rows
# its card shows, `shown`, a few the deck chooses; its Full list shows every
# row of the course (owner, 2026-10-16, #515: "A few curated verbs should be
# good enough").
SET_MEMBER_KEYS = {"ref"}
LAYER_SET_KEYS = {"native", "explanation"}
# A set needs at least this many members: one card alone is no group.
MIN_SET_MEMBERS = 2
CORE_EXAMPLE_KEYS = {"target", "reading", "ipa", "bases", "source",
                     "language", "sounds", "words", "target_scripts"}
# A word card has at least this many examples (owner, #506: "At least 2").
MIN_EXAMPLES = 2
# The languages filled in (#511, #512). In these, a word card with fewer than
# MIN_EXAMPLES examples is an error, and so is a noun with no gender where the
# language's path lists gender classes; in any other, neither is reported
# yet. A language is added here when its fill issue is closed.
FILLED_LANGUAGES: set[str] = set()
# Card data (DECK-FORMAT.md, Card data; #513, #514, #516, #517). Each item
# list is a core card's, each item with an id by which each layer gives its
# text; an item is a card of the language by `ref`, or a word written in
# full with its reading.
# Every item may take `ipa` and `source` (owner, 2026-10-15, #506: "Yes,
# all items may take ipa and source").
ITEM_KEYS = {
    "synonyms": {"id", "word", "ref", "reading", "ipa", "source"},
    "antonyms": {"id", "word", "ref", "reading", "ipa", "source"},
    "collocations": {"id", "word", "ref", "reading", "ipa", "source"},
    "confusables": {"id", "word", "ref", "reading", "ipa", "kind", "source"},
    "forms": {"id", "kind", "word", "reading", "ipa", "source"},
}
CARD_DATA = (*ITEM_KEYS, "senses")
CONFUSABLE_KINDS = ("form", "word", "sound", "mark")
FORM_KINDS = ("plural", "oblique", "oblique-plural", "feminine", "masculine", "other")
REGISTERS = ("formal", "neutral", "informal", "slang", "offensive")
SENSE_KEYS = {"id", "pos", "examples", "source"}
FREQUENCY_KEYS = {"rank", "source"}
# A confusable on a sentence put in order is a wrong tile: it has 2 to 3
# (owner, #506: "2–3, never a needed tile").
CONFUSABLE_TILES = range(2, 4)
# A card's own recording (#518) and image (#523), shipped with the deck:
# the field, its folder in the language's directory, and the file's ending.
# Each file is named by its card's id and carries its credit in
# `<field>_credit`.
MEDIA = {"audio": ("audio", ".opus"), "image": ("images", ".webp")}
MEDIA_CREDIT_KEYS = {"source", "license", "credit"}
# The licences a recording or an image may have to ship in a CC BY-SA 4.0
# deck (ADR-0040): CC0, the public domain, CC BY and CC BY-SA 2.0 to 4.0,
# ported versions too (`CC-BY-SA-3.0-DE`). GFDL alone, NC and ND cannot.
MEDIA_LICENSE_RE = re.compile(r"CC0-1\.0|public-domain|CC-BY(?:-SA)?-(?:2\.0|2\.5|3\.0|4\.0)"
                              r"(?:-[A-Z]{2,3})?")
# What a native language gives a card: never written in a core.
NATIVE_SIDE = ("native", "alt_native", "not_synonyms", "wiktionary")
LAYER_ENTRY_KEYS = {"native", "alt_native", "not_synonyms", "notes", "examples", "bases",
                    "wiktionary", "dictionary", *CARD_DATA}
DICTIONARY_KEYS = {"senses", "etymology", "source"}
CORE_ENTRY_KEYS = {"lemma", "key", "forms", "reading", "readings", "ipa", "ipas"}
LAYER_PATTERN_KEYS = {"name", "slot_name", "prompt", "slots", "entries", "notes"}
TABLE_KEYS = {"applies_to", "slots", "rows"}
APPLIES_KEYS = {"pos", "tags", "except"}
ROW_KEYS = {"word", "key", "forms", "readings", "ipas"}
RULE_KEYS = {"id", "slots", "words"}
LAYER_TABLE_KEYS = {"slot_name", "slots", "prompts"}
LAYER_RULE_KEYS = {"name", "explanation"}
NOTE_KINDS = ("behaviour", "culture", "homograph", "lookalike", "note", "pair", "usage")
# The kinds that name another card of the language by `ref`; a pair's partner
# must also be taught, since the minimal-pair panel shows both words.
# The keys that record a rejected sound-alike or look-alike pair (#808).
REJECTED_ALIKE_KEYS = ("not_sounds_like", "not_looks_like")
REF_NOTE_KINDS = ("homograph", "lookalike", "pair")
NOTE_KEYS = {"kind", "text", "id", "ref", "source", "words", "region"}
BASE_KEYS = {"word", "ref", "base", "reading", "ipa", "meaning", "wiktionary"}
# A slot key or a note id: it starts with a letter, so YAML never reads it as
# a number, and it is none of YAML 1.1's boolean words.
KEY_RE = re.compile(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*")
YAML11_BOOLS = {"yes", "no", "on", "off", "true", "false", "y", "n"}
# A placeholder in a note's text or a rule's explanation, and what looks like
# one but is not ({0}, {01}). The app uses these two, character for character.
PLACEHOLDER_RE = re.compile(r"\{([1-9][0-9]*)\}")
NUMBERED_RE = re.compile(r"\{([0-9]+)\}")
# The files beside the decks, whose names a core cannot take.
RESERVED_CORES = {"facts": "facts file", "situations": "situations file",
                  "numbers": "number rules",
                  "romanisation": "romanisation file", "script": "script guide",
                  "sounds": "sounds file", "path": "path",
                  "resources": "resources file", "phonetics": "phonetic rules file",
                  "gating": "character gating file"}
UNIT_KEYS = {"decks", "planned", "words", "grammar", "milestone",
             "listening_passages", "reading_passages"}
PLANNED_KEYS = {"id", "theme", "grammar", "words"}
PASSAGE_PLAN_KEYS = {"id", "text"}
REGION_KEYS = {"id", "name"}
# The region the app keeps for its own answer, after the language's own.
ELSEWHERE = "elsewhere"
MILESTONES = ("A1", "A2", "B1")
# Words per level (owner, 2026-10-09; low confidence): A1 700, A2 900 more,
# B1 1,200 more. A level outside half to one and a half times is warned of.
LEVEL_WORDS = {"A1": 700, "A2": 900, "B1": 1200}
B1_TOTAL = (2000, 3500)
# A path may give its own sizes, `levels: { A1: 120, A2: 60, B1: 80 }` (#615,
# ADR-0045); then they replace both constants for that path, and the B1 total
# is held to half to one and a half times their sum.
# A course's phrasebook (words-rules-sentences.md, section 1).
PHRASEBOOK_SIZE = (15, 25)
# Parts of speech whose several-word cards still count as one word.
LEXICAL_POS = {"noun", "verb", "adj", "adv", "pronoun"}
# Scripts written without spaces: a card of a B1 deck in one gives its
# words, `words`, on its target and on each example (DECK-FORMAT.md, Base
# words), since splitting at spaces cannot find them.
NO_SPACES = {"han", "han_simplified", "han_traditional", "kana", "thai"}

ROOT = Path(__file__).resolve().parent.parent


class DeckResolver(yaml.resolver.BaseResolver):
    """Plain scalars as YAML 1.2's core schema reads them, which is how the
    app's `package:yaml` reads them: `yes`, `no`, `on` and `off` are
    strings, `060` is 60, and `1_000` is a string. PyYAML's own resolver
    follows YAML 1.1, so without this the validator and the app would read
    the same deck differently. The app's deck parser retypes plain scalars
    by exactly these patterns (`_value` in lib/core/data/deck_parser.dart);
    change both together."""


for _tag, _pattern in (
    ("bool", r"(?:true|True|TRUE|false|False|FALSE)\Z"),
    ("int", r"(?:[-+]?[0-9]+|0o[0-7]+|0x[0-9a-fA-F]+)\Z"),
    ("float", r"(?:[-+]?(?:\.[0-9]+|[0-9]+(?:\.[0-9]*)?)(?:[eE][-+]?[0-9]+)?"
              r"|[-+]?\.(?:inf|Inf|INF)|\.(?:nan|NaN|NAN))\Z"),
    ("null", r"(?:null|Null|NULL|~|)\Z"),
):
    DeckResolver.add_implicit_resolver(f"tag:yaml.org,2002:{_tag}",
                                       re.compile(_pattern), None)


class _DeckConstructor(yaml.constructor.SafeConstructor):
    """What DeckLoader adds to PyYAML's safe constructor. It is a class of its
    own so that the pure-Python loader, [DeckLoader], and the libyaml-backed
    one, [CDeckLoader], build their data exactly alike."""

    def construct_yaml_int(self, node: yaml.ScalarNode) -> int:
        value = self.construct_scalar(node)
        try:
            if value.startswith("0o"):
                return int(value[2:], 8)
            if value.startswith("0x"):
                return int(value[2:], 16)
            return int(value, 10)
        except ValueError:
            raise yaml.constructor.ConstructorError(
                None, None, f"{value!r} is not a whole number", node.start_mark)

    def flatten_mapping(self, node: yaml.MappingNode) -> None:
        for key_node, _ in node.value:
            # YAML 1.2 has no merge key, so a plain `<<` resolves as a string;
            # it is refused all the same.
            if key_node.tag == "tag:yaml.org,2002:merge" or (
                    isinstance(key_node, yaml.ScalarNode)
                    and key_node.value == "<<" and not key_node.style):
                raise yaml.constructor.ConstructorError(
                    None, None,
                    "found a merge key (<<), which the app does not support; "
                    "write the fields out in full",
                    key_node.start_mark,
                )
        super().flatten_mapping(node)

    def construct_mapping(self, node: yaml.MappingNode, deep: bool = False) -> dict:
        if isinstance(node, yaml.MappingNode):
            self.flatten_mapping(node)
            seen: set[object] = set()
            for key_node, _ in node.value:
                key = self.construct_object(key_node, deep=deep)
                try:
                    duplicate = key in seen
                except TypeError:
                    continue  # unhashable; the base class reports it
                if duplicate:
                    raise yaml.constructor.ConstructorError(
                        "while constructing a mapping", node.start_mark,
                        f"found duplicate key {key!r}", key_node.start_mark,
                    )
                seen.add(key)
        return super().construct_mapping(node, deep=deep)


_DeckConstructor.add_constructor("tag:yaml.org,2002:int",
                                 _DeckConstructor.construct_yaml_int)


class DeckLoader(yaml.reader.Reader, yaml.scanner.Scanner, yaml.parser.Parser,
                 yaml.composer.Composer, _DeckConstructor, DeckResolver):
    """A safe loader that refuses what the app's deck parser refuses, and
    reads plain scalars as it does (YAML 1.2, [DeckResolver]).

    PyYAML keeps the last of two duplicate keys and expands `<<` merge keys.
    The Dart parser rejects both, so a deck using either would pass CI and then
    fail to load on a device.
    """

    def __init__(self, stream) -> None:
        yaml.reader.Reader.__init__(self, stream)
        yaml.scanner.Scanner.__init__(self)
        yaml.parser.Parser.__init__(self)
        yaml.composer.Composer.__init__(self)
        _DeckConstructor.__init__(self)
        DeckResolver.__init__(self)


if getattr(yaml, "__with_libyaml__", False) and not os.environ.get("FLUENOUGH_PURE_YAML"):
    from yaml.cyaml import CParser as _CParser

    class CDeckLoader(_CParser, _DeckConstructor, DeckResolver):
        """[DeckLoader] with libyaml doing the reading. Only [_fast_load]
        uses it, for the nodes: anything it cannot read is read again by
        [DeckLoader], so that every error message is the pure-Python
        loader's, word for word."""

        def __init__(self, stream) -> None:
            _CParser.__init__(self, stream)
            _DeckConstructor.__init__(self)
            DeckResolver.__init__(self)
else:  # PyYAML built without libyaml, or the escape hatch for debugging
    CDeckLoader = None


# Reading a deck's YAML faster, with the same result. libyaml, which
# `yaml.CParser` is, is quick at the first half of the job only: turning the
# text into nodes. Building the data from them stays in Python and takes most
# of the time. [_fast_load] does that for the plain case, a document of
# mappings, lists and scalars, which every deck is, and gives up on anything
# else. It never has an opinion of its own: a text it will not read, for any
# reason, raises [_Fallback], and [_load_deck] reads it with [DeckLoader], so
# that every error message is that loader's. What it does read it reads to the
# same data, scalar for scalar, key order included (tools/test_fast_yaml.py).


class _Fallback(Exception):
    """Not read here; read it with the loader of record."""


_TAG = "tag:yaml.org,2002:"
_KEY_TAGS = frozenset(_TAG + t for t in ("str", "int", "float", "bool", "null"))


def _fast_load(text: str, loader_class: type) -> object:
    """`yaml.load(text, Loader=L)`, where [loader_class] is the libyaml-backed
    twin of L (one that builds nodes with `yaml.CParser`). Raises [_Fallback]
    for anything but mappings, lists and scalars, for a duplicate key, for a
    `<<` key, for every error, and for the three things libyaml reads
    differently from PyYAML's own scanner: a tab outside a quoted scalar, a
    byte order mark (libyaml skips one at the start of any line, PyYAML only
    at the start of the text), and a `?` in a plain scalar inside a flow
    collection. So it never reads a text the pure loader would not."""
    if "\t" in text or "\ufeff" in text:
        raise _Fallback
    loader = None
    try:
        loader = loader_class(text)
        node = loader.get_single_node()
        if node is None:
            return None
        made: dict[int, object] = {}
        scalar, mapping, sequence = (yaml.ScalarNode, yaml.MappingNode,
                                     yaml.SequenceNode)
        construct = loader.construct_object
        str_tag, seq_tag, map_tag = _TAG + "str", _TAG + "seq", _TAG + "map"

        def build(node: yaml.Node, flow: bool = False) -> object:
            t = type(node)
            if t is scalar:
                if flow and not node.style and "?" in node.value:
                    raise _Fallback
                if node.tag == str_tag:
                    return node.value
                return construct(node, deep=True)
            done = made.get(id(node), made)
            if done is not made:
                return done
            inner = bool(node.flow_style)
            if t is sequence and node.tag == seq_tag:
                items: list = []
                made[id(node)] = items
                items.extend([build(n, inner) for n in node.value])
                return items
            if t is mapping and node.tag == map_tag:
                result: dict = {}
                made[id(node)] = result
                for key_node, value_node in node.value:
                    if type(key_node) is not scalar \
                            or key_node.tag not in _KEY_TAGS \
                            or key_node.value == "<<":
                        raise _Fallback
                    key = build(key_node, inner)
                    if key in result:
                        raise _Fallback
                    result[key] = build(value_node, inner)
                return result
            raise _Fallback

        return build(node)
    except _Fallback:
        raise
    except Exception as exc:  # noqa: BLE001 - re-read, for its message
        raise _Fallback from exc
    finally:
        if loader is not None:
            loader.dispose()


# Every file is read many times in one run: a layer reads its core, each core
# looks at its siblings' `native`, a path looks at the paths beside it. The
# parsed text is kept, by the digest of the text (so a file written again is
# read again), and each caller is handed a private copy it may change. The
# bound is on the text, in characters (the trees are about seven times as
# large, and each process keeps its own).
_YAML_CACHE: "collections.OrderedDict[bytes, object]" = collections.OrderedDict()
_YAML_CACHE_SIZES: dict[bytes, int] = {}
_YAML_CACHE_LIMIT = 12_000_000
_YAML_CACHE_BYTES = [0]
_NO_DATA = object()


class _Uncloneable(Exception):
    """A loaded tree holds something other than dicts, lists and scalars (an
    explicit `!!set`, say): it is handed out as read and never kept."""


_SCALARS = (str, int, float, bool, bytes, datetime.date, datetime.datetime)


def _clone(node: object, memo: dict[int, object]) -> object:
    """A copy of loaded YAML, as copy.deepcopy makes it (shared nodes stay
    shared) but several times faster, since a loaded tree holds only dicts,
    lists and scalars."""
    t = type(node)
    if t is str or t is int or t is float or t is bool or node is None:
        return node
    if t is dict:
        done = memo.get(id(node))
        if done is not None:
            return done
        copy_: dict = {}
        memo[id(node)] = copy_
        for k, v in node.items():
            copy_[k] = _clone(v, memo)
        return copy_
    if t is list:
        done = memo.get(id(node))
        if done is not None:
            return done
        out: list = []
        memo[id(node)] = out
        out.extend([_clone(v, memo) for v in node])
        return out
    if t in _SCALARS:
        return node
    raise _Uncloneable


def _digest(text: str) -> bytes:
    return hashlib.blake2b(text.encode("utf-8", "surrogatepass"),
                           digest_size=16).digest()


def _load_deck(text: str) -> object:
    """`yaml.load(text, Loader=DeckLoader)`, with the same result and the same
    errors, read once per distinct text and by libyaml where it is built."""
    key = _digest(text)
    tree = _YAML_CACHE.get(key, _NO_DATA)
    if tree is _NO_DATA:
        tree = _NO_DATA
        if CDeckLoader is not None:
            try:
                tree = _fast_load(text, CDeckLoader)
            except _Fallback:
                tree = _NO_DATA
        if tree is _NO_DATA:
            tree = yaml.load(text, Loader=DeckLoader)
        size = len(text)
        if size > _YAML_CACHE_LIMIT // 2:
            return tree
        try:
            copy_ = _clone(tree, {})
        except _Uncloneable:
            return tree
        _YAML_CACHE[key] = tree
        _YAML_CACHE_SIZES[key] = size
        _YAML_CACHE_BYTES[0] += size
        while _YAML_CACHE_BYTES[0] > _YAML_CACHE_LIMIT:
            old, _ = _YAML_CACHE.popitem(last=False)
            _YAML_CACHE_BYTES[0] -= _YAML_CACHE_SIZES.pop(old)
        return copy_
    _YAML_CACHE.move_to_end(key)
    return _clone(tree, {})


@dataclass
class CardDef:
    """What the checks across files know of a card the language writes."""
    path: Path                 # the file that writes the card
    natives: set[str]          # the native languages it is taught from
    words: list[str]           # what a number deck counts as taught by it
    target: str = ""
    alt_targets: list[str] = field(default_factory=list)
    pos: str | None = None
    tags: list[str] = field(default_factory=list)
    phrasebook: bool = False
    vocab: bool = False        # written in a vocab deck, core or layer
    reading: bool = False      # it has a reading
    in_core: bool = False      # written in a core: its layers give natives
    is_set: bool = False       # a set card: never a ref's, a pair's or a base's card


@dataclass
class Note:
    """A typed note, as the checks across files see it."""
    i: int                     # its place in the card's list
    nid: str                   # its id, or its 1-based position
    kind: str
    ref: str | None            # a pair note's partner


@dataclass
class TCard:
    """A written card, as the B1 checks see it."""
    id: str
    target: str
    alt_targets: list[str]
    pos: str | None
    phrasebook: bool
    path: Path                 # the file that writes its text
    where: str                 # `card {id}`, or `cards.{id}` in a layer
    tags: list[str] = field(default_factory=list)
    deck_kind: str = "vocab"
    bases: list[dict] = field(default_factory=list)
    # (place, target, bases) of each example the deck shows.
    examples: list[tuple[int, str, list[dict]]] = field(default_factory=list)
    notes: list[Note] = field(default_factory=list)
    pair: str | None = None
    single: bool = True        # written in a single-file deck or as layer-only
    # Its target's `words`, where it gives them, and each example's, by
    # place (DECK-FORMAT.md, Base words); None and absent where not given.
    words: list[str] | None = None
    example_words: dict[int, list[str]] = field(default_factory=dict)


@dataclass
class TableInfo:
    """A rules core's table, for the rows check across files."""
    pos: list[str]
    tags: list[str]
    excepted: list[str]
    rows: list[str]            # the rows' words, card ids
    script: str
    forms: dict[str, set[str]] = field(default_factory=dict)  # each row's cells
    slots: list[str] = field(default_factory=list)  # the table's slot keys, in order
    # Each row's slots that have a form, by the row's word.
    row_slots: dict[str, set[str]] = field(default_factory=dict)
    # Each rule's slots, by rule id, for the sets that name a rule.
    rule_slots: dict[str, list[str]] = field(default_factory=dict)


@dataclass
class Passage:
    """A passage a unit plans, named once with a description per native
    language (ADR-0036)."""
    key: str                   # listening_passages or reading_passages
    j: int                     # its place in that list
    id: str
    texts: set[str]            # the native languages it is described in


@dataclass
class Unit:
    """A unit of a language's path, list or mapping (ADR-0036)."""
    i: int
    decks: list[str]           # its written decks' core ids, without "*"
    mapping: bool = False
    planned: dict | None = None    # {id, theme, grammar} of a planned unit
    words: int | None = None   # its planned size in words
    grammar: list[str] = field(default_factory=list)
    milestone: str | None = None
    exempt: bool = False       # an alphabet unit, or "*" alone
    passages: list[Passage] = field(default_factory=list)


@dataclass
class PathPlan:
    """A language's path: every native language's, naming core ids."""
    lang: str
    units: list[Unit]
    alphabet: list[str]        # core ids
    has_plan: bool
    marks: dict[str, int]      # milestone -> the unit it is on, when in order
    end: int                   # the last unit up to B1
    regions: list[str] | None = None   # its region ids; None without regions
    # Its gender classes (#512); [] for a language without gender, None when
    # the path does not list them.
    genders: list[str] | None = None
    # Its own words per level (#615); None when the path gives none, and the
    # defaults (LEVEL_WORDS, B1_TOTAL) apply.
    levels: dict[str, int] | None = None


@dataclass
class Report:
    path: Path
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    # For the checks across files: the theme ids a themes file lists, in
    # order, and the (language, native, theme) a theme deck teaches.
    themes: list[str] | None = None
    theme_key: tuple[str, str, str] | None = None
    # For the number rules (ADR-0011): the words a numbers file spells with,
    # by language, and the words a number deck teaches.
    number_words: tuple[str, set[str]] | None = None
    number_taught: tuple[str, set[str]] | None = None
    # For the paths (#117, ADR-0013, ADR-0036): the (language, native, id)
    # of a deck, and the (language, core ids) a path file lists, in order.
    course_deck: tuple[str, str, str] | None = None
    course_path: tuple[str, list[str]] | None = None
    # What a language's path lists a deck as: a core's id, a layer's core,
    # a single-file deck's id less its native (`te-en-home` is `te-home`).
    listed_as: str | None = None
    # For the language icons (ADR-0027): a deck's language code and the icon
    # it gives, or None, for the check that a language's decks agree.
    icon: tuple[str, str | None] | None = None
    # A path's units that end in the wildcard and list decks of their own,
    # each as its core ids, for the check that one of them has a theme.
    open_units: list[list[str]] = field(default_factory=list)
    # For card ids (ADR-0018): the deck's language and native codes, the
    # cards it writes (id -> what a number deck counts as taught by it), and
    # the cards it lists by ref (id, whether it gives its own native, where).
    lang_code: str | None = None
    native_code: str | None = None
    card_defs: dict[str, CardDef] = field(default_factory=dict)
    refs: list[tuple[str, bool, str]] = field(default_factory=list)
    # Each card's minimal-pair partner (ADR-0034): (partner id, where).
    pairs: list[tuple[str, str]] = field(default_factory=list)
    # For reading decks (#98, ADR-0019): the words a vocab or grammar deck
    # teaches; and a reading deck's passages, as (id, theme, words in its
    # sentences, words it glosses).
    taught_words: tuple[str, str, set[str]] | None = None
    passages: tuple[str, str, list[tuple[str, str | None, list[str], set[str]]]] | None = None
    # The B1 format (ADR-0036). `part` is "core", "layer" or None (a
    # single-file deck, or another file); `core_id` a layer's core.
    part: str | None = None
    core_id: str | None = None
    infos: list[str] = field(default_factory=list)
    # Pair notes' partners, (ref, where, i), and the cards bases, card data
    # and facts name, (ref, where, the field, such as `bases[0].ref`), each
    # checked across files.
    note_refs: list[tuple[str, str, int]] = field(default_factory=list)
    # The same for homograph and lookalike notes: (ref, where, i, kind).
    like_refs: list[tuple[str, str, int, str]] = field(default_factory=list)
    base_refs: list[tuple[str, str, str]] = field(default_factory=list)
    # The cards `not_sounds_like` and `not_looks_like` name: (ref, where, place).
    rejected_refs: list[tuple[str, str, str]] = field(default_factory=list)
    # A confusable by ref on a sentence put in order: (ref, where, its place,
    # the tiles the answer needs), so that the card it names is no needed tile.
    tile_refs: list[tuple[str, str, str, list[str]]] = field(default_factory=list)
    # Each form a core card gives, (card id, where, its place, its word), for
    # the warning on a form a rules table has already (#517).
    card_forms: list[tuple[str, str, str, str]] = field(default_factory=list)
    # A facts or situations file's language, for the cards it names (#516,
    # #724).
    facts_lang: str | None = None
    # Set on a situations file: its language's code, for the one file per
    # language rule (#724).
    situations_lang: str | None = None
    # The rule ids a card's `rules` names: (rule id, where).
    card_rules: list[tuple[str, str]] = field(default_factory=list)
    # The regions a note names: (region id, where, the note's place).
    note_regions: list[tuple[str, str, int]] = field(default_factory=list)
    # The recordings and images its cards name (#518, #523), as paths in the
    # repository: `decks/hi/audio/hi-0001.opus`.
    media: list[str] = field(default_factory=list)
    # Each noun card's gender, or None without one: (gender, where) (#512).
    noun_genders: list[tuple[str | None, str]] = field(default_factory=list)
    # A layer: the ids of its core's cards and refs whose entry gives native.
    translated: set[str] | None = None
    # A core: the ids of its cards and refs, in order, each marked written.
    core_cards: list[tuple[str, bool]] | None = None
    # The kind of deck a file is (a single-file deck's, or a core's, which
    # its layers take), and the script of its language.
    deck_kind: str | None = None
    script: str | None = None
    # The cards a file writes: a single-file deck's, a core's, or a layer's
    # own. A layer's `merged` are its core's written cards it includes, with
    # only the notes and examples it gives text to; `core_refs` its core's
    # refs in order, each with whether the layer gives it a native.
    cards: list[TCard] = field(default_factory=list)
    merged: list[TCard] = field(default_factory=list)
    core_refs: list[tuple[str, bool]] = field(default_factory=list)
    core_theme: str | None = None
    # The text of each card's notes this file gives, and the words they
    # quote, by card id: a single-file card's, a core's quoted words, a
    # layer's texts. For the stem check across files.
    note_texts: dict[str, list[str]] = field(default_factory=dict)
    # A grammar deck's lemmas, for the stem check: a pronoun's case forms are
    # forms of the pronoun, not a new stem (#480).
    pattern_lemmas: list[str] = field(default_factory=list)
    # A rules core: its rules, (id, where), and its table.
    rules_defined: list[tuple[str, str]] = field(default_factory=list)
    table: TableInfo | None = None
    # A core's set cards (DECK-FORMAT.md, Set cards): (id, where, members),
    # their members checked across files.
    sets: list[tuple[str, str, object]] = field(default_factory=list)
    # A layer of a rules core: the rule ids it gives, of the core's.
    layer_rules: list[str] = field(default_factory=list)
    # A path: its units and B1 plan.
    plan: PathPlan | None = None
    # Whether the file holds a culture note's claim; a layer's native name,
    # the rules of its core (a rules core's layer), and each pair note of
    # its core it gives text to, (card id, note id, partner).
    culture: bool = False
    native_name: str | None = None
    core_rules: list[str] = field(default_factory=list)
    text_pairs: list[tuple[str, str, str]] = field(default_factory=list)
    # Deck kinds (wiki/Plan-Deck-Kinds-And-Topics.md): a deck's header
    # fields; a layer takes them from its core, for the checks across files.
    genre: str | None = None
    level: str | None = None
    hidden: bool = False
    professional: str | None = None
    section: str | None = None
    weave: bool | None = None
    reviewed: bool = False
    # The creators a card or passage names: (ids, where, source author, the
    # first year of its source date).
    creator_refs: list[tuple[list[str], str, object, int | None]] = field(default_factory=list)
    # The shared files of the kinds: their language and what they list.
    creators_lang: str | None = None
    creators_data: dict[str, dict] | None = None
    creators_images: list[str] = field(default_factory=list)
    topics_data: list[tuple[str, str, dict]] | None = None
    # A character gating file's language and its valid entries (#1227).
    gating_lang: str | None = None
    gating_data: list[dict] | None = None
    sections_data: dict[str, set[str]] | None = None
    recs_lang: str | None = None
    recs_data: list[tuple[str, str, dict]] | None = None
    situation_ids: list[str] = field(default_factory=list)
    script_features: set[str] = field(default_factory=set)
    # The card fields a released app refuses that this file uses, by name
    # (CARD_FIELD_MIN_APP): tools/deck_index.py puts the file behind the app
    # version that reads them (ADR-0052).
    new_fields: set[str] = field(default_factory=set)
    # A script guide core's characters by feature id: its example and its
    # letters, NFC (#1228); a script topic's `chars` may name them.
    script_chars: dict[str, set[str]] = field(default_factory=dict)
    # A creator's related cards, (card id, where).
    related_cards: list[tuple[str, str]] = field(default_factory=list)

    def error(self, where: str, msg: str) -> None:
        self.errors.append(f"{where}: {msg}")

    def warn(self, where: str, msg: str) -> None:
        self.warnings.append(f"{where}: {msg}")

    def info(self, where: str, msg: str) -> None:
        self.infos.append(f"{where}: {msg}")


# A source that names Wiktionary is the entry's page and nothing else (owner,
# 2026-10-16, #518: "Link only"; 2026-10-17: "Wiktionary source shape").
WIKTIONARY_SOURCE_RE = re.compile(r"https://en\.wiktionary\.org/wiki/[^\s#?/][^\s#?]*")


def _check_source_shape(r: Report, where: str, p: str, value: object,
                        item_id: object = None) -> None:
    """Any `source` naming wiktionary.org must be exactly
    `https://en.wiktionary.org/wiki/<word>`: no dump date, query or fragment."""
    if not isinstance(value, str) or "wiktionary.org" not in value.lower():
        return
    if WIKTIONARY_SOURCE_RE.fullmatch(value):
        return
    r.error(where, f"{p}.source {value!r} (item {item_id!r}) names Wiktionary but is "
                   f"not its page only: expected https://en.wiktionary.org/wiki/<word>, "
                   f"with a word and nothing after it (no dump date, query or fragment)")


def _is_str(v: object) -> bool:
    return isinstance(v, str) and v.strip() != ""


def _check_str_list(r: Report, where: str, key: str, value: object) -> None:
    if not isinstance(value, list):
        r.error(where, f"{key} must be a list")
        return
    for i, item in enumerate(value):
        if not _is_str(item):
            r.error(where, f"{key}[{i}] must be a non-empty string")


def _letters_in(text: str, blocks: tuple[tuple[int, int], ...]) -> bool:
    """Whether every letter and mark of `text` is in one of `blocks`. Digits,
    spaces, punctuation and the zero-width joiners are in any script."""
    for ch in text:
        if unicodedata.category(ch)[0] not in "LM" or ch in "\u200c\u200d":
            continue
        if not any(lo <= ord(ch) <= hi for lo, hi in blocks):
            return False
    return True


def _check_target_scripts(r: Report, where: str, value: object, target: object,
                          scripts: list[str] | None) -> None:
    """A card's `target_scripts` (#623): its spelling in each of the
    language's scripts but the first, by script id. `target` is in the first."""
    if not isinstance(value, dict) or not value:
        r.error(where, "target_scripts must be a mapping of script id to the "
                       "word in that script")
        return
    others = (scripts or [])[1:]
    for key, text in value.items():
        if not _is_str(key) or not SCRIPT_RE.fullmatch(key):
            r.error(where, f"target_scripts key {key!r} is not a script id")
        elif key not in others:
            if scripts and len(scripts) > 1:
                r.error(where, f"target_scripts key {key!r} is not one of the "
                               f"language's other scripts ({', '.join(others)})")
            else:
                r.error(where, f"target_scripts needs the language block to list "
                               f"its scripts, `scripts: [<first>, {key}]`")
        if not _is_str(text):
            r.error(where, f"target_scripts.{key} must be a non-empty string")
            continue
        if text != text.strip():
            r.error(where, f"target_scripts.{key} has leading or trailing whitespace")
        if text == target:
            r.error(where, f"target_scripts.{key} is the same as target; give a "
                           f"spelling in {key}")
        blocks = SCRIPT_BLOCKS.get(key) if _is_str(key) else None
        # `_letters_in` passes only letters and marks, and 〆 and 〇 are neither
        # (symbol, number): a kanji in a kana reading is refused all the same.
        if blocks and (not _letters_in(text, blocks)
                       or (key == "kana" and _has_kanji(text))):
            r.error(where, f"target_scripts.{key} has letters that are not in "
                           f"{key}: {text!r}")


def _has_kanji(text: str) -> bool:
    return any(lo <= ord(ch) <= hi for ch in text for lo, hi in _HAN_BLOCKS)


def _check_kanji_reading(r: Report, where: str, card: dict, target: object,
                         script: str, scripts: list[str] | None,
                         what: str = "card") -> None:
    """A Japanese card or example in kanji needs its kana reading.

    A card or example sentence written in kanji (script `han`, with `kana`
    among the language's scripts) shows its kana reading beside the kanji, as
    a Chinese card shows pinyin: the reading is its `target_scripts.kana`, and
    every target with a kanji in it needs one, as does an example sentence's
    (ADR-0053). The kana's letters are checked by `_check_target_scripts`
    (no kanji in a kana reading). A target in kana alone has nothing to read
    out and gives none.
    """
    if script != "han" or "kana" not in (scripts or [])[1:] or not _is_str(target):
        return
    spelled = card.get("target_scripts")
    kana = spelled.get("kana") if isinstance(spelled, dict) else None
    if _has_kanji(target) and not _is_str(kana):
        article = "an" if what == "example" else "a"
        r.error(where, f"{article} {what} written in kanji needs its kana "
                       "reading, `target_scripts: { kana: ... }`")


def _check_optional_text(r: Report, where: str, block: dict, key: str) -> None:
    """A free-text field may be omitted, but when present it must be text.

    The app's parser types every field, so `notes: 1990` would pass here and
    then fail on a device if this were not checked.
    """
    val = block.get(key)
    if val is None or isinstance(val, str):
        return
    if isinstance(val, bool):
        r.error(where, f"{key} parsed as the boolean {val!r}, not text. Quote the value.")
    elif isinstance(val, (int, float)):
        r.error(where, f"{key} parsed as the number {val!r}, not text. Quote the value.")
    else:
        r.error(where, f"{key} must be text, got {val!r}")


def check_langblock(r: Report, where: str, block: object, *, full: bool) -> None:
    if not isinstance(block, dict):
        r.error(where, "must be a mapping")
        return
    code = block.get("code")
    if not _is_str(code) or not LANG_RE.fullmatch(code):
        r.error(where, f"code must be a 2-3 letter language code, got {code!r}")
    if not _is_str(block.get("name")):
        r.error(where, "name is required")
    iso = block.get("iso639_3")
    if not _is_str(iso) or not ISO639_3_RE.fullmatch(iso):
        r.error(where, f"iso639_3 must be the language's three-letter ISO 639-3 "
                       f"code, e.g. 'hin' for Hindi, got {iso!r}")
    # `native` needs only code and name, but whatever else it declares is
    # checked like `language`: the app's parser reads those fields either way.
    script = block.get("script")
    if full or script is not None:
        if not _is_str(script) or not SCRIPT_RE.fullmatch(script):
            r.error(where, f"script must be a lowercase script name, such as "
                           f"'devanagari', got {script!r}")
        elif script not in SCRIPTS:
            r.warn(where, f"script {script!r} is not one the validator knows "
                          f"({', '.join(sorted(SCRIPTS))}); it is accepted, "
                          f"and a reading is expected on every card")
    scripts = block.get("scripts")
    if scripts is not None:
        if (not isinstance(scripts, list) or len(scripts) < 2
                or not all(_is_str(x) and SCRIPT_RE.fullmatch(x) for x in scripts)):
            r.error(where, f"scripts must list two or more script names, such as "
                           f"['devanagari', 'perso_arabic'], got {scripts!r}")
        elif len(set(scripts)) != len(scripts):
            r.error(where, "scripts lists a script twice")
        elif _is_str(script) and scripts[0] != script:
            r.error(where, f"scripts starts with the block's script, {script!r}, "
                           f"got {scripts[0]!r} first")
    tts = block.get("tts")
    if tts is not None and (not _is_str(tts) or not BCP47_RE.fullmatch(tts)):
        r.error(where, f"tts must be a BCP-47 tag, got {tts!r}")
    # A notation has no voice of its own: each IPA example is said in the
    # voice of its own language (ADR-0041), and braille is read by touch
    # or sight (ADR-0043).
    if full and tts is None and script not in NOTATION_SCRIPTS:
        r.warn(where, "no tts tag; the device will pick a default regional voice")
    if "rtl" in block and not isinstance(block["rtl"], bool):
        r.error(where, "rtl must be a boolean")
    # `typed: false` marks a language whose answers cannot be typed, so
    # production is asked by choosing (ADR-0041).
    if "typed" in block and not isinstance(block["typed"], bool):
        r.error(where, "typed must be a boolean")
    # A language's chip shows its icon: the first letter of its own name,
    # such as हि for Hindi (ADR-0027). A letter or two, no more.
    icon = block.get("icon")
    if icon is not None and (not _is_str(icon) or len(icon.strip()) > 4
                             or icon != icon.strip()):
        r.error(where, f"icon must be a letter or two of the language's own "
                       f"name, such as 'हि', got {icon!r}")


def card_id_re(lang: str) -> re.Pattern[str]:
    """A card id names the language learned and a number (ADR-0018)."""
    return re.compile(rf"{re.escape(lang)}-[0-9]{{4,}}")


# A typed English meaning is accepted for each `;`-separated part of the
# expected text and for no other split (lib/core/grading/meaning_rules.dart),
# so separately sayable alternatives must be written "Take care!; Careful!"
# (#924). A sentence break inside a bracket-free meaning with no `;` is
# therefore an error, unless the card is one of those whose sentences must
# all be said (the target says both), listed here by card id. Keep sorted;
# each needs a reason. Only card `native` and `alt_native` are checked, not
# examples.
MEANING_ALL_REQUIRED = frozenset({
    "es-0111",   # "Good morning, madam. How are you?": greeting, then question
    "zh-0282",   # "I am a student. Are you a teacher?": the target says both
    "zh-0331",   # "We are eating a meal. Are you going home?": both
    "zh-0333",   # "The child finishes school. Shall we wait?": both
})
_MEANING_BRACKETS = re.compile(r"\([^)]*\)|\[[^\]]*\]")
# Abbreviations whose full stop is not a sentence end.
_MEANING_ABBREV = re.compile(
    r"\b(?:mr|mrs|ms|dr|st|prof|sr|jr|vs|e\.g|i\.e|a\.m|p\.m|ph\.d|u\.s\.a|"
    r"mt|fig|approx)\.", re.IGNORECASE)
# An ellipsis, or a run of ?! or !?, is one pause, not a sentence break.
_MEANING_PAUSE = re.compile(r"\.{3,}|\u2026|[?!]{2,}")
_MEANING_BREAK = re.compile(r"[.!?]\s+\w")


def meaning_has_separate_sentences(text: str) -> bool:
    """Whether an English meaning has a sentence break and no `;`, outside
    brackets, abbreviations and pauses (#924)."""
    if ";" in text:
        return False
    text = _MEANING_PAUSE.sub(" ", _MEANING_ABBREV.sub(" ", _MEANING_BRACKETS.sub(" ", text)))
    return _MEANING_BREAK.search(text) is not None


def check_meaning_alternatives(r: Report, where: str, cid: str | None,
                               entry: dict) -> None:
    """An English `native` or `alt_native` value must not run separate
    sentences together without `;` (#924)."""
    if r.native_code != "en":
        return
    values = [entry.get("native")]
    alts = entry.get("alt_native")
    if isinstance(alts, list):
        values += alts
    for value in values:
        if not _is_str(value) or not meaning_has_separate_sentences(value):
            continue
        if cid in MEANING_ALL_REQUIRED:
            continue
        r.error(where, f"meaning has separate sentences; separate alternatives with "
                       f'";" (or reword it, or add the card id to MEANING_ALL_REQUIRED): {value!r}')


def check_not_synonyms(r: Report, where: str, entry: dict) -> None:
    """A card's `not_synonyms` (ADR-0050, #924): typed English answers the
    synonym sets must not accept for it. A list of quoted words in comparison
    form, once each, none of them one of the card's own answers (those are
    never blocked, so the entry would say two opposite things). Whether an
    entry blocks anything is checked against the sets by validate_synonyms.py.
    Released apps reject the key: decks use it only a release after the app
    that reads it, as for `warning` (#691); "Released app reads the decks"
    in CI is the guard."""
    if "not_synonyms" not in entry:
        return
    value = entry["not_synonyms"]
    if r.native_code != "en":
        r.error(where, "not_synonyms is for English meanings: the synonym sets "
                       "are English")
    _check_str_list(r, where, "not_synonyms", value)
    if not isinstance(value, list):
        return
    from validate_synonyms import answers, meaning_key
    own = set(answers(entry))
    seen: set[str] = set()
    for i, item in enumerate(value):
        if not _is_str(item):
            continue
        key = meaning_key(item)
        if key != item:
            r.error(where, f"not_synonyms[{i}] must be in comparison form (lower "
                           f"case, no leading to, no punctuation): write {key!r}")
        if key in own:
            r.error(where, f"not_synonyms[{i}] {item!r} is one of the card's own "
                           f"answers, which are never blocked")
        if key in seen:
            r.error(where, f"not_synonyms[{i}] {item!r} is listed twice")
        seen.add(key)


def check_card(r: Report, idx: int, card: object, seen: set[str],
               script: str, lang: str, *, form: str = "single",
               key: str | None = None,
               scripts: list[str] | None = None) -> None:
    """A card of a single-file deck (`form` "single"), of a core ("core"), or
    a layer's own card ("layer"), whose id is its key in the layer's
    `cards` mapping. A core card has the language side only (ADR-0036)."""
    where = f"cards[{idx}]" if key is None else f"cards.{key}"
    if not isinstance(card, dict):
        r.error(where, "must be a mapping")
        return
    id_re = card_id_re(lang)
    core = form == "core"

    if _is_set(card):
        r.error(where, "a set card is written in a vocab core, kind: \"set\", its "
                       "name and explanation in each layer (DECK-FORMAT.md, Set cards)")
        return

    if "ref" in card and form != "layer":
        check_ref(r, idx, card, seen, id_re, form=form, lang=lang, script=script,
                  scripts=scripts)
        return

    if form == "layer":
        cid = key
        seen.add(cid)
    else:
        cid = card.get("id")
    if form != "layer" and (not _is_str(cid) or not id_re.fullmatch(cid)):
        r.error(where, f"id must be {lang}- and at least four digits, such as "
                       f"{lang}-0001, got {cid!r}")
        cid = None
    else:
        if form != "layer":
            where = f"card {cid}"
            if cid in seen:
                r.error(where, "duplicate card id")
            seen.add(cid)
        alts = card.get("alt_target")
        alts = [t for t in alts if _is_str(t)] if isinstance(alts, list) else []
        target = card.get("target")
        pos = card.get("pos")
        tags = card.get("tags")
        r.card_defs[cid] = CardDef(
            path=r.path, natives=set(),
            words=[t for t in [target, *alts] if _is_str(t)],
            target=target if _is_str(target) else "", alt_targets=alts,
            pos=pos if isinstance(pos, str) else None,
            tags=[t for t in tags if isinstance(t, str)] if isinstance(tags, list) else [],
            phrasebook=card.get("phrasebook") is True,
            vocab=(r.deck_kind or "vocab") == "vocab",
            reading=_is_str(card.get("reading")), in_core=core)

    allowed = CORE_CARD_KEYS if core else CARD_KEYS - (
        {"id", "source", "level", "creator", "legacy", "character"}
        if form == "layer" else set())
    for unknown in sorted(set(card) - allowed, key=str):
        if core and unknown in NATIVE_SIDE:
            r.error(where, f"a core card's {unknown!r} is in each layer, under "
                           f"cards.{cid}")
        elif core and unknown == "pair":
            r.error(where, 'pair: in a core file a pair note names the partner, '
                           '{ kind: "pair", ref: ... }; Hear takes its sound-alike '
                           'from there')
        elif unknown in CARD_DATA:
            r.error(where, f"{unknown} is written on a core card, its text in each "
                           f"layer (DECK-FORMAT.md, Card data)")
        else:
            r.error(where, f"unknown field {unknown!r}")

    for key in ("target", "reading") if core else ("target", "native", "reading"):
        val = card.get(key)
        if key == "reading" and val is None:
            continue
        if isinstance(val, bool):
            # A bare true or false is a boolean. YAML 1.1 also read no, yes,
            # on and off as booleans, which bit romanisation decks hard (the
            # hiragana の romanises to "no"); DeckResolver reads them as text.
            r.error(where, f"{key} parsed as the boolean {val!r} -- YAML read a "
                           f"bare true or false as a bool. Quote the value.")
        elif not _is_str(val):
            if key == "reading":
                r.error(where, "reading must be a non-empty string or omitted")
            else:
                r.error(where, f"{key} is required and must be a non-empty string")

    target = card.get("target")
    if _is_str(target):
        if target != unicodedata.normalize("NFC", target):
            r.warn(where, "target is not NFC-normalised")
        if target != target.strip():
            r.error(where, "target has leading or trailing whitespace")

    if script not in NO_READING and not _is_str(card.get("reading")):
        r.warn(where, f"no reading, but script is {script!r}; learners will need one")

    for key in ("alt_target", "alt_native", "tags"):
        if key in card:
            _check_str_list(r, where, key, card[key])
    if not core:
        check_meaning_alternatives(r, where, cid, card)
        check_not_synonyms(r, where, card)
    if "target_scripts" in card:
        _check_target_scripts(r, where, card["target_scripts"], target, scripts)
    _check_kanji_reading(r, where, card, target, script, scripts)

    _check_optional_text(r, where, card, "gender")
    if card.get("pos") == "noun":
        gender = card.get("gender")
        r.noun_genders.append((gender if isinstance(gender, str) else None, where))
    notes = check_notes(r, where, card.get("notes"), cid, lang, script, core=core)
    _check_optional_text(r, where, card, "audio")
    for field in MEDIA:
        check_media(r, where, card, field, cid, lang)

    pos = card.get("pos")
    if pos is not None and pos not in POS | SCRIPT_POS:
        r.error(where, f"pos must be one of {sorted(POS | SCRIPT_POS)}, got {pos!r}")
    # A word that is heard and typed as its form, as a letter or a digit is
    # (#522, step 7). Only `form` is a value. Older apps reject the key, so
    # the decks give it only a release after the app that reads it.
    if "hears" in card and card["hears"] != "form":
        r.error(where, f'hears must be "form", or left out; got {card["hears"]!r}')

    if "warning" in card and core:
        _check_warning(r, where, card["warning"], notes, card.get("senses"))
    for key in REJECTED_ALIKE_KEYS:
        if key in card:
            _check_rejected_alikes(r, where, key, card[key], cid, lang)

    if "register" in card and card["register"] not in REGISTERS:
        r.error(where, f"register must be one of {', '.join(REGISTERS)}, got "
                       f"{card['register']!r}")
    if "frequency" in card:
        _check_frequency(r, where, card["frequency"])
    target = card.get("target")
    if core and _is_str(target):
        given = _given(card)
        tiles = _tiles(target, given) if _rearranges(target, pos, given) else None
        for key in ITEM_KEYS:
            if key in card:
                check_items(r, where, key, card[key], cid, target, lang, script, tiles)
        if "senses" in card:
            check_senses(r, where, card["senses"], cid, lang, script)

    _check_modes(r, where, card.get("modes"))

    partner = None
    if "pair" in card and not core:
        partner = card["pair"]
        if not _is_str(partner) or not id_re.fullmatch(partner):
            r.error(where, f"pair must be the id of another {lang} card, "
                           f"got {partner!r}")
            partner = None
        elif partner == cid:
            r.error(where, "pair names the card itself")
            partner = None
        else:
            r.pairs.append((partner, where))

    if "picture" in card:
        check_picture(r, where, card["picture"])
    if "picture_ask" in card:
        if card["picture_ask"] is not True:
            r.error(where, f"picture_ask must be true, unquoted, or left out; "
                           f"got {card['picture_ask']!r}")
        elif "picture" not in card:
            r.error(where, "picture_ask needs a picture: it puts a ? badge on it")

    if "phrasebook" in card and card["phrasebook"] is not True:
        r.error(where, f"phrasebook must be true, unquoted, or left out; got "
                       f"{card['phrasebook']!r}")
    if "wiktionary" in card and not core:
        _check_wiktionary(r, where, "", card["wiktionary"])
    if "rules" in card:
        _check_card_rules(r, where, card["rules"], lang)

    target = card.get("target")
    words = check_given_words(r, where, "", card.get("words"),
                              target if _is_str(target) else None)
    bases = check_bases(r, where, "", card.get("bases"),
                        target if _is_str(target) else None, cid, lang, script,
                        core=core, given=words)
    example_words: dict[int, list[str]] = {}
    examples = _check_examples(r, where, card.get("examples"), form=form,
                               cid=cid, lang=lang, script=script,
                               words=example_words, scripts=scripts)
    if (lang in FILLED_LANGUAGES and counts_as_word(card, r.deck_kind or "vocab")
            and len(examples) < MIN_EXAMPLES):
        r.error(where, f"{len(examples)} example(s); a word card has at least "
                       f"{MIN_EXAMPLES} once {lang} is filled in "
                       f"(DECK-FORMAT.md, Card data)")
    if cid is not None and _is_str(target):
        alts = card.get("alt_target")
        tags = card.get("tags")
        r.cards.append(TCard(
            id=cid, target=target,
            alt_targets=[t for t in alts if _is_str(t)] if isinstance(alts, list) else [],
            pos=pos if isinstance(pos, str) else None,
            tags=[t for t in tags if isinstance(t, str)] if isinstance(tags, list) else [],
            phrasebook=card.get("phrasebook") is True, path=r.path, where=where,
            deck_kind=r.deck_kind or "vocab", bases=bases, examples=examples,
            notes=notes, pair=partner, single=not core, words=words,
            example_words=example_words))


def _check_modes(r: Report, where: str, modes: object) -> None:
    if modes is None:
        return
    _check_str_list(r, where, "modes", modes)
    if isinstance(modes, list):
        for m in modes:
            if m == "grammarUnderstood":
                r.error(where, "grammarUnderstood is only for a rules table's cells")
            elif isinstance(m, str) and m not in MODES:
                r.error(where, f"unknown mode {m!r}")


def _check_wiktionary(r: Report, where: str, prefix: str, value: object) -> None:
    """The mark that the native language's Wiktionary has an entry: `true`,
    or left out. The link is built from the word, never stored."""
    if value is not True:
        r.error(where, f"{prefix}wiktionary must be true, or left out where "
                       f"Wiktionary has no entry; got {value!r}")


def _check_card_rules(r: Report, where: str, rules: object, lang: str) -> None:
    """A sentence's `rules`: the rule ids it uses, for the unlock gate."""
    if not isinstance(rules, list):
        r.error(where, f'rules must be a list of rule ids, such as ["{lang}-rule-past"]')
        return
    rule_re = rule_id_re(lang)
    seen: set[str] = set()
    for i, rid in enumerate(rules):
        if not _is_str(rid) or not rule_re.fullmatch(rid):
            r.error(where, f"rules[{i}] must be a {lang} rule id, {lang}-rule- and "
                           f"a name, got {rid!r}")
        elif rid in seen:
            r.error(where, f"rules lists {rid!r} twice")
        else:
            seen.add(rid)
            r.card_rules.append((rid, where))


def rule_id_re(lang: str) -> re.Pattern[str]:
    """A rule id names the language and the rule (ADR-0036)."""
    return re.compile(rf"{re.escape(lang)}-rule-[a-z0-9]+(?:-[a-z0-9]+)*")


def _is_key(value: object) -> bool:
    """A slot key or a note id."""
    return (isinstance(value, str) and KEY_RE.fullmatch(value) is not None
            and value not in YAML11_BOOLS)


def _key(word: str) -> str:
    """How a base's word and a text's words are compared."""
    return unicodedata.normalize("NFC", word).casefold()


def check_placeholders(r: Report, where: str, prefix: str, text: str,
                       words: list[str], what: str) -> None:
    """`{1}`, `{2}`, ... in a note's text or a rule's explanation stand for
    its `words`, written in the core once for every layer."""
    used: set[int] = set()
    for m in NUMBERED_RE.finditer(text):
        if not PLACEHOLDER_RE.fullmatch(m.group(0)):
            r.error(where, f"{prefix}{m.group(0)} is not a placeholder: "
                           f"placeholders count from {{1}}, without leading zeros")
            continue
        n = int(m.group(1))
        used.add(n)
        if n > len(words):
            r.error(where, f"{prefix}uses {{{n}}}, but the {what} has "
                           f"{len(words)} words")
    for n, word in enumerate(words, 1):
        if n not in used:
            r.warn(where, f"{prefix}never uses {{{n}}}, {word}")


def check_note_words(r: Report, where: str, prefix: str, words: object,
                     script: str) -> list[str]:
    """The language facts a note's text or a rule's explanation quotes,
    `{ word, reading, ipa? }`, each with its reading where the script needs
    one. Returns the words, in order."""
    if words is None:
        return []
    if not isinstance(words, list):
        r.error(where, f"{prefix} must be a list of {{ word, reading }}")
        return []
    found = []
    for k, w in enumerate(words):
        if (not isinstance(w, dict) or not _is_str(w.get("word"))
                or (script not in NO_READING and not _is_str(w.get("reading")))
                or set(w) - {"word", "reading", "ipa"}):
            r.error(where, f"{prefix}[{k}] needs word, and its reading in a "
                           f"script that needs one")
            found.append(str(w.get("word")) if isinstance(w, dict) else "")
        else:
            found.append(w["word"])
    return found


def _check_rejected_alikes(r: Report, where: str, key: str, value: object,
                           cid: str | None, lang: str) -> None:
    """A core card's `not_sounds_like` or `not_looks_like` (#808): the
    offensive words whose sound-alike or look-alike pair a reviewer rejected,
    so that the pair is no longer warned of. Older apps reject the key, so
    the decks give it only a release after the app that reads it: CI's
    "Released app reads the decks" refuses it until then."""
    if not isinstance(value, list) or not value:
        r.error(where, f"{key} must be a non-empty list of card ids, got {value!r}")
        return
    id_re = card_id_re(lang)
    seen: set[str] = set()
    for i, ref in enumerate(value):
        if not _is_str(ref) or not id_re.fullmatch(ref):
            r.error(where, f"{key}[{i}] must be the id of another {lang} card, "
                           f"got {ref!r}")
        elif ref == cid:
            r.error(where, f"{key}[{i}] names the card itself")
        elif ref in seen:
            r.error(where, f"{key}[{i}]: {ref} is listed twice")
        else:
            seen.add(ref)
            r.rejected_refs.append((ref, where, f"{key}[{i}]"))


def _check_warning(r: Report, where: str, value: object, notes: list[Note],
                   senses: object) -> None:
    """A core card's `warning` (#691): the one warning its teach card shows.
    The id of a pair, homograph or lookalike note (its place, "1", "2", for a
    note with no id), "senses" for the card's other meanings, or "none". Older
    apps reject the key, so the decks give it only a release after the app
    that reads it."""
    named = sorted({n.nid for n in notes if n.kind in REF_NOTE_KINDS})
    if not _is_str(value):
        r.error(where, f"warning must be text naming a warning, got {value!r}")
    elif value == "none":
        pass
    elif value == "senses":
        if not (isinstance(senses, list) and senses):
            r.error(where, 'warning "senses" needs the card to have senses')
    elif value not in named:
        r.error(where, f"warning {value!r} names no pair, homograph or lookalike "
                       f"note of this card (its notes: {', '.join(named) or 'none'}); "
                       f'use such a note\'s id, "senses" or "none"')


def check_notes(r: Report, where: str, notes: object, cid: str | None,
                lang: str, script: str, *, core: bool) -> list[Note]:
    """A card's notes: today's text, read as one note of kind `note`, or a
    list of typed notes. In a core a note holds the language facts only, and
    each layer gives its text by the note's id."""
    if notes is None:
        return []
    core_list = "notes must be a list of notes in a core file; their text is in each layer"
    if isinstance(notes, str):
        if core:
            r.error(where, core_list)
            return []
        # A blank string is no notes, as today, never one empty note.
        if cid is not None and notes.strip():
            r.note_texts.setdefault(cid, []).append(notes)
        return [Note(0, "1", "note", None)] if notes.strip() else []
    if not isinstance(notes, list):
        if core:
            r.error(where, core_list)
        elif isinstance(notes, (bool, int, float)):
            _check_optional_text(r, where, {"notes": notes}, "notes")
        else:
            r.error(where, "notes must be text, or a list of notes, each with a kind "
                           "and its text")
        return []
    if not notes:
        r.error(where, "notes must not be an empty list; leave it out")
        return []
    found: list[Note] = []
    ids: set[str] = set()
    id_re = card_id_re(lang)
    for i, note in enumerate(notes):
        p = f"notes[{i}]"
        if not isinstance(note, dict):
            r.error(where, f"{p} must be a mapping")
            continue
        for unknown in sorted(set(note) - NOTE_KEYS, key=str):
            r.error(where, f"{p}: unknown field {unknown!r}")
        kind = note.get("kind")
        if kind not in NOTE_KINDS:
            r.error(where, f"{p}.kind must be one of {', '.join(NOTE_KINDS)}, got {kind!r}")
            kind = None
        nid = note.get("id")
        if nid is None:
            if core:
                r.error(where, f"{p}.id is required in a core file: each layer names "
                               f"the note by it")
            nid = str(i + 1)
        elif not _is_key(nid):
            r.error(where, f"{p}.id must start with a letter and match [a-z0-9-]+, "
                           f"and not be a YAML 1.1 boolean word, got {nid!r}")
            nid = None
        elif nid in ids:
            r.error(where, f"{p}.id {nid!r} is used twice")
        if nid is not None:
            ids.add(nid)
        text = note.get("text")
        if core:
            if "text" in note:
                r.error(where, f"{p}.text: a core note's text is in each layer, under "
                               f"cards.{cid}.notes.{nid if nid is not None else '?'}")
        elif not _is_str(text):
            r.error(where, f"{p}.text is required and must be non-empty text")
        ref = note.get("ref")
        if kind in REF_NOTE_KINDS:
            the = "its partner" if kind == "pair" else "the other word"
            if not _is_str(ref) or not id_re.fullmatch(ref):
                r.error(where, f"{p}.ref: a {kind} note names {the}, the id of "
                               f"another {lang} card, got {ref!r}")
                ref = None
            elif ref == cid:
                r.error(where, f"{p}.ref names the card itself")
                ref = None
            elif kind == "pair":
                r.note_refs.append((ref, where, i))
            else:
                r.like_refs.append((ref, where, i, kind))
        else:
            if "ref" in note:
                r.error(where, f"{p}.ref is only for a pair, homograph or lookalike note")
            ref = None
        source = note.get("source")
        if kind == "culture":
            r.culture = True
        if kind == "culture" and not _is_str(source):
            r.error(where, f"{p}.source: a culture note names where its claims can "
                           f"be checked")
        elif "source" in note and not _is_str(source):
            r.error(where, f"{p}.source must be text, got {source!r}")
        _check_source_shape(r, where, p, source, note.get("id"))
        if "region" in note:
            check_note_regions(r, where, p, i, note["region"])
        words = check_note_words(r, where, f"{p}.words", note.get("words"), script)
        if not core and isinstance(text, str):
            check_placeholders(r, where, f"{p}.text ", text, words, "note")
        if cid is not None:
            r.note_texts.setdefault(cid, []).extend(
                [t for t in (text, *words) if isinstance(t, str)])
        found.append(Note(i, nid if nid is not None else str(i + 1), kind or "note", ref))
    return found


def check_note_regions(r: Report, where: str, p: str, i: int, value: object) -> None:
    """A region note's regions: a region id, or a non-empty list of them,
    each checked against the language's path across files (ADR-0036)."""
    regions = [value] if isinstance(value, str) else value
    if not isinstance(regions, list) or not regions or not all(_is_key(x) for x in regions):
        r.error(where, f'{p}.region must be a region id, or a list of them, such as '
                       f'"telangana", got {value!r}')
        return
    for k, region in enumerate(regions):
        if region in regions[:k]:
            r.error(where, f"{p}.region lists {region!r} twice")
    for region in dict.fromkeys(regions):
        r.note_regions.append((region, where, i))


def check_bases(r: Report, where: str, prefix: str, bases: object,
                text: str | None, cid: str | None, lang: str, script: str, *,
                core: bool, given: list[str] | None = None) -> list[dict]:
    """A card's or an example's `bases`: the base word of each derived word
    in its text, by the card that teaches it or written in full (ADR-0036).
    A card whose word is its own root says `bases: self` (#513). [given] is
    the text's `words`, where it gives them. Returns the well-formed
    entries."""
    if bases is None or (bases == "self" and not prefix):
        return []
    if not isinstance(bases, list):
        r.error(where, f"{prefix}bases must be a list of {{ word, ref }} or "
                       f"{{ word, base, reading }}"
                       + ("" if prefix else ', or "self" for a word that is its own root'))
        return []
    of = "the target" if not prefix else f"{prefix}target"
    words = ({_key(w) for w in _split(text, given)} if text is not None
             else None)
    seen: set[str] = set()
    found: list[dict] = []
    id_re = card_id_re(lang)
    for i, base in enumerate(bases):
        p = f"{prefix}bases[{i}]"
        if not isinstance(base, dict):
            r.error(where, f"{p} must be a mapping")
            continue
        for unknown in sorted(set(base) - BASE_KEYS, key=str):
            r.error(where, f"{p}: unknown field {unknown!r}")
        word = base.get("word")
        if not _is_str(word):
            r.error(where, f"{p}.word is required and must be a non-empty string")
            word = None
        else:
            if core and word != unicodedata.normalize("NFC", word):
                r.error(where, f"{p}.word is not NFC-normalised")
            if words is not None and _key(word) not in words:
                r.error(where, f"{p}.word {word!r} is not a word of {of}")
            if _key(word) in seen:
                r.error(where, f"{p}.word {word!r} is given twice")
            seen.add(_key(word))
        if "ref" in base and "base" in base:
            r.error(where, f"{p} gives ref or base, not both")
        elif "ref" in base:
            ref = base["ref"]
            if not _is_str(ref) or not id_re.fullmatch(ref):
                r.error(where, f"{p}.ref must be the id of a {lang} card, got {ref!r}")
            elif ref == cid:
                r.error(where, f"{p}.ref names the card itself")
            else:
                r.base_refs.append((ref, where, f"{p}.ref"))
            for key in ("reading", "ipa", "meaning", "wiktionary"):
                if key in base:
                    r.error(where, f"{p}.{key} is only for a base written in full")
        elif _is_str(base.get("base")):
            reading = base.get("reading")
            if "reading" in base and not _is_str(reading):
                r.error(where, f"{p}.reading must be a non-empty string or omitted")
            elif script not in NO_READING and not _is_str(reading):
                r.error(where, f"{p}: no reading, but script is {script!r}; give the "
                               f"base's reading")
            if core:
                for key in ("meaning", "wiktionary"):
                    if key in base:
                        r.error(where, f"{p}.{key}: a core file's meanings are in each "
                                       f"layer, under cards.{cid}.bases")
            else:
                if not _is_str(base.get("meaning")):
                    r.error(where, f"{p}.meaning is required beside base")
                if "wiktionary" in base:
                    _check_wiktionary(r, where, f"{p}.", base["wiktionary"])
        else:
            r.error(where, f"{p} needs ref, or base and its reading")
        if word is not None:
            found.append(base)
    return found


def _rearranges(target: str, pos: object, given: list[str] | None = None) -> bool:
    """Whether a card is produced by putting its words in order, as the
    app's `Card.rearranges` decides: three words or more, or a phrase of
    two or more, counted in its `words` where it gives them."""
    words = given if given is not None else [
        w for w in target.split() if any(unicodedata.category(c)[0] == "L" for c in w)]
    return len(words) >= 3 or (pos == "phrase" and len(words) >= 2)


def _tiles(text: str, given: list[str] | None = None) -> list[str]:
    """The tiles of [text] to put in order, as the app's `tilesOf` makes
    them: each word in lowercase, the marks at its edges tiles of their
    own. Where the card gives its `words`, as the app's `tilesOfWords`
    makes them: each word, and each mark between them."""
    if given is not None:
        found: list[str] = []
        at = 0
        for word in given:
            i = text.find(word, at)
            gap = [ch for ch in text[at:i] if not ch.isspace()]
            if i < 0 or any(unicodedata.category(ch)[0] in "LMN" for ch in gap):
                break
            found += gap
            found.append(word.lower())
            at = i + len(word)
        else:
            return found + [ch for ch in text[at:] if not ch.isspace()]
    tiles: list[str] = []
    for word in text.split():
        if not any(unicodedata.category(c)[0] == "L" for c in word):
            continue
        a, b = 0, len(word)
        while a < b and unicodedata.category(word[a])[0] not in "LMN":
            a += 1
        while b > a and unicodedata.category(word[b - 1])[0] not in "LMN":
            b -= 1
        tiles += [*word[:a], word[a:b].lower(), *word[b:]]
    return [t for t in tiles if t]


def _lang_dir(path: Path, lang: str) -> Path:
    """The language's directory a deck file is in: its own, or, for a
    layer in decks/<lang>/<native>/, its parent."""
    return path.parent if path.parent.name == lang else path.parent.parent


def check_media(r: Report, where: str, card: dict, field: str, cid: str | None,
                lang: str) -> None:
    """A card's own recording or image shipped with the deck (#518, #523):
    `decks/<lang>/<folder>/<card id><ending>`, the file there, and its
    credit, `{ source, license, credit }`, beside it in `<field>_credit`.
    `audio` may still be an asset path or a URL, with no credit."""
    folder, ending = MEDIA[field]
    value = card.get(field)
    credit_key = f"{field}_credit"
    shipped = _is_str(value) and value.startswith("decks/")
    if field != "audio" and value is not None and not shipped:
        r.error(where, f"{field} must be decks/{lang}/{folder}/<card id>{ending}, "
                       f"got {value!r}")
    if shipped and cid is not None:
        wanted = f"decks/{lang}/{folder}/{cid}{ending}"
        if value != wanted:
            r.error(where, f"{field} must be {wanted}: the file is named by its card, "
                           f"got {value!r}")
        elif not (_lang_dir(r.path, lang) / folder / f"{cid}{ending}").is_file():
            r.error(where, f"{field} {value} has no file")
        else:
            r.media.append(value)
        if credit_key not in card:
            r.error(where, f"{credit_key} is required with {field}: the file's "
                           f"{{ source, license, credit }}")
    if credit_key not in card:
        return
    credit = card[credit_key]
    if not shipped:
        r.error(where, f"{credit_key} is only for a file shipped with the deck, "
                       f"{field}: decks/{lang}/{folder}/<card id>{ending}")
        return
    if not isinstance(credit, dict):
        r.error(where, f"{credit_key} must be {{ source, license, credit }}")
        return
    for unknown in sorted(set(credit) - MEDIA_CREDIT_KEYS, key=str):
        r.error(where, f"{credit_key}: unknown field {unknown!r}")
    _check_source_shape(r, where, credit_key, credit.get("source"), field)
    for key in sorted(MEDIA_CREDIT_KEYS):
        if not _is_str(credit.get(key)):
            r.error(where, f"{credit_key}.{key} is required and must be a non-empty "
                           f"string")
    licence = credit.get("license")
    if _is_str(licence) and not MEDIA_LICENSE_RE.fullmatch(licence):
        r.error(where, f"{credit_key}.license {licence!r} cannot ship in a CC BY-SA "
                       f"4.0 deck: CC0-1.0, public-domain, or CC-BY or CC-BY-SA 2.0 "
                       f"to 4.0, such as CC-BY-SA-4.0")


def check_media_across(reports: list[Report]) -> list[str]:
    """Every recording and image in a language's folders is a file a card
    names (#518, #523), so nothing ships that no card plays or shows.
    Checked for a language whose deck files are all being validated."""
    given = {rep.path.resolve() for rep in reports}
    named: dict[Path, set[str]] = {}
    for rep in reports:
        if rep.lang_code is None:
            continue
        d = _lang_dir(rep.path, rep.lang_code).resolve()
        named.setdefault(d, set()).update(rep.media)
    problems: list[str] = []
    for d in sorted(named):
        if any(p.resolve() not in given for p in _yaml_files(d)):
            continue
        for field, (folder, ending) in MEDIA.items():
            for f in sorted((d / folder).glob("*")) if (d / folder).is_dir() else []:
                rel = f"decks/{d.name}/{folder}/{f.name}"
                if f.suffix != ending:
                    problems.append(f"{rel}: a card's {field} file ends in {ending}")
                elif rel not in named[d]:
                    problems.append(f"{rel}: no card names it as its {field}; remove "
                                    f"it, or name it on the card {f.stem}")
    return problems


def _check_frequency(r: Report, where: str, value: object) -> None:
    """A card's frequency (#516): its rank in a count of the language, and
    where it was counted."""
    if not isinstance(value, dict):
        r.error(where, "frequency must be { rank, source }")
        return
    for unknown in sorted(set(value) - FREQUENCY_KEYS, key=str):
        r.error(where, f"frequency: unknown field {unknown!r}")
    rank = value.get("rank")
    if isinstance(rank, bool) or not isinstance(rank, int) or rank < 1:
        r.error(where, f"frequency.rank must be a whole number from 1, got {rank!r}")
    if not _is_str(value.get("source")):
        r.error(where, "frequency.source is required: where the rank was counted")


def _check_item_id(r: Report, where: str, p: str, iid: object, ids: set[str]) -> None:
    """An item's id, by which each layer gives its text: unique in its list."""
    if not _is_key(iid):
        r.error(where, f"{p}.id must start with a letter and match [a-z0-9-]+, and "
                       f"not be a YAML 1.1 boolean word, got {iid!r}")
    elif iid in ids:
        r.error(where, f"{p}.id {iid!r} is used twice")
    else:
        ids.add(iid)


def check_items(r: Report, where: str, key: str, items: object, cid: str | None,
                target: str, lang: str, script: str, tiles: list[str] | None) -> None:
    """A core card's synonyms, antonyms, collocations, confusables or forms
    (DECK-FORMAT.md, Card data). Each has an id; a form is a word, any other
    item a card of the language by `ref` or a word written in full, with its
    reading in a script that needs one. On a sentence put in order
    ([tiles]), confusables are wrong tiles: 2 to 3, none a tile the answer
    needs."""
    if not isinstance(items, list) or not items:
        r.error(where, f"{key} must be a non-empty list; leave it out when there is none")
        return
    ids: set[str] = set()
    id_re = card_id_re(lang)
    kinds = {"forms": FORM_KINDS, "confusables": CONFUSABLE_KINDS}.get(key)
    for i, item in enumerate(items):
        p = f"{key}[{i}]"
        if not isinstance(item, dict):
            r.error(where, f"{p} must be a mapping")
            continue
        for unknown in sorted(set(item) - ITEM_KEYS[key], key=str):
            r.error(where, f"{p}: unknown field {unknown!r}")
        _check_item_id(r, where, p, item.get("id"), ids)
        if kinds is not None and item.get("kind") not in kinds:
            r.error(where, f"{p}.kind must be one of {', '.join(kinds)}, got "
                           f"{item.get('kind')!r}")
        for k in ("reading", "ipa", "source"):
            if k in item and not _is_str(item[k]):
                r.error(where, f"{p}.{k} must be a non-empty string or omitted")
        _check_source_shape(r, where, p, item.get("source"), item.get("id"))
        if "ref" in item:
            ref = item["ref"]
            if "word" in item:
                r.error(where, f"{p} gives word or ref, not both")
            elif not _is_str(ref) or not id_re.fullmatch(ref):
                r.error(where, f"{p}.ref must be the id of a {lang} card, got {ref!r}")
            elif ref == cid:
                r.error(where, f"{p}.ref names the card itself")
            else:
                r.base_refs.append((ref, where, f"{p}.ref"))
                if key == "confusables" and tiles is not None:
                    r.tile_refs.append((ref, where, p, tiles))
            for k in ("reading", "ipa"):
                if k in item:
                    r.error(where, f"{p}.{k} is only for a word written in full")
            continue
        word = item.get("word")
        if not _is_str(word):
            r.error(where, f"{p} needs word" + ("" if key == "forms" else " or ref"))
            continue
        if word != unicodedata.normalize("NFC", word):
            r.error(where, f"{p}.word is not NFC-normalised")
        if (script not in NO_READING and item.get("kind") != "mark"
                and not _is_str(item.get("reading"))):
            r.error(where, f"{p}: no reading, but script is {script!r}; give the "
                           f"word's reading")
        if key == "forms":
            if word == target:
                r.error(where, f"{p}.word is the card's own target")
            elif cid is not None:
                r.card_forms.append((cid, where, p, word))
        elif key == "confusables" and tiles is not None and word.lower() in tiles:
            r.error(where, f"{p}.word {word!r} is a tile the answer needs; a "
                           f"confusable is a wrong tile")
    if key == "confusables" and tiles is not None and len(items) not in CONFUSABLE_TILES:
        r.error(where, f"confusables: a sentence put in order has 2 to 3, as wrong "
                       f"tiles; got {len(items)}")


def check_senses(r: Report, where: str, senses: object, cid: str | None,
                 lang: str, script: str) -> None:
    """A core card's senses (#517): each an id, by which each layer gives
    its meaning, and its own examples, each with its reading in a script
    that needs one."""
    if not isinstance(senses, list) or not senses:
        r.error(where, "senses must be a non-empty list; leave it out when there is none")
        return
    ids: set[str] = set()
    for i, sense in enumerate(senses):
        p = f"senses[{i}]"
        if not isinstance(sense, dict):
            r.error(where, f"{p} must be a mapping")
            continue
        for unknown in sorted(set(sense) - SENSE_KEYS, key=str):
            r.error(where, f"{p}: unknown field {unknown!r}")
        _check_item_id(r, where, p, sense.get("id"), ids)
        if "pos" in sense and sense["pos"] not in POS:
            r.error(where, f"{p}.pos must be one of {sorted(POS)}, got {sense['pos']!r}")
        if "source" in sense and not _is_str(sense["source"]):
            r.error(where, f"{p}.source must be a non-empty string or omitted")
        _check_source_shape(r, where, p, sense.get("source"), sense.get("id"))
        examples = sense.get("examples")
        _check_examples(r, f"{where}: {p}", examples, form="core", cid=cid, lang=lang,
                        script=script)
        for j, ex in enumerate(examples if isinstance(examples, list) else []):
            if (isinstance(ex, dict) and script not in NO_READING
                    and not _is_str(ex.get("reading"))):
                r.error(where, f"{p}.examples[{j}]: no reading, but script is "
                               f"{script!r}")


PICTURES = Path(__file__).resolve().parent.parent / "assets" / "pictures"


def picture_file(emoji: str) -> str:
    """The bundled file of a card's picture, as `picturePath` in
    lib/core/models/card.dart names it: its code points in hex of at least
    four digits, joined by `_`, without U+FE0F."""
    points = [f"{ord(c):04x}" for c in emoji if c != "\ufe0f"]
    return f"emoji_u{'_'.join(points)}.png"


def check_picture(r: Report, where: str, picture: object) -> None:
    """A picture is one emoji whose Noto Emoji image is bundled
    (`tools/pictures.py` copies it)."""
    if not _is_str(picture) or not picture.strip() or picture.isascii():
        r.error(where, f"picture must be one emoji, got {picture!r}")
    elif not (PICTURES / picture_file(picture)).is_file():
        r.error(where, f"picture {picture} has no image: run "
                       f"tools/pictures.py to copy {picture_file(picture)}")


def _check_examples(r: Report, where: str, examples: object, *,
                    form: str = "single", cid: str | None = None,
                    lang: str = "xx", script: str = "other",
                    words: dict[int, list[str]] | None = None,
                    scripts: list[str] | None = None
                    ) -> list[tuple[int, str, list[dict]]]:
    """A card's examples. In a core an example has its language side only,
    and each layer names it by its target. Returns (place, target, bases)
    of each well-formed example, and puts each one's `words`, where given,
    in [words] by its place."""
    if examples is None:
        return []
    if not isinstance(examples, list):
        r.error(where, "examples must be a list")
        return []
    found = []
    targets: dict[str, int] = {}
    for j, ex in enumerate(examples):
        if not isinstance(ex, dict):
            r.error(where, f"examples[{j}] must be a mapping")
            continue
        if form == "core":
            if not _is_str(ex.get("target")):
                r.error(where, f"examples[{j}] needs target")
                continue
            unknown = sorted(set(ex) - CORE_EXAMPLE_KEYS, key=str)
            for key in unknown:
                if key in NATIVE_SIDE:
                    r.error(where, f"examples[{j}]: a core example's {key!r} is in "
                                   f"each layer, under cards.{cid}.examples")
            if any(key not in NATIVE_SIDE for key in unknown):
                r.error(where, f"examples[{j}] has unknown fields")
            target = ex["target"]
            if target != unicodedata.normalize("NFC", target):
                r.error(where, f"examples[{j}].target is not NFC-normalised; a layer "
                               f"names the example by it")
            same = targets.get(unicodedata.normalize("NFC", target))
            if same is not None:
                r.error(where, f"examples[{j}] has the same target as "
                               f"examples[{same}]; a layer names an example by its "
                               f"target")
            else:
                targets[unicodedata.normalize("NFC", target)] = j
        elif not _is_str(ex.get("target")) or not _is_str(ex.get("native")):
            r.error(where, f"examples[{j}] needs both target and native")
            continue
        elif set(ex) - EXAMPLE_KEYS:
            r.error(where, f"examples[{j}] has unknown fields")
            continue
        for key in ("reading", "ipa", "source"):
            if key in ex and not _is_str(ex.get(key)):
                r.error(where, f"examples[{j}].{key} must be a non-empty "
                               f"string or omitted")
        _check_source_shape(r, where, f"examples[{j}]", ex.get("source"), f"#{j}")
        # The language an example is in, when not the card's, and whether
        # the card's letter has the card's sound in it (ADR-0041).
        if "language" in ex and not (_is_str(ex["language"])
                                     and LANG_RE.fullmatch(ex["language"])):
            r.error(where, f"examples[{j}].language must be a 2-3 letter "
                           f"language code, got {ex['language']!r}")
        if "sounds" in ex and not isinstance(ex["sounds"], bool):
            r.error(where, f"examples[{j}].sounds must be true or false")
        if "target_scripts" in ex:
            _check_target_scripts(r, f"{where}: examples[{j}]", ex["target_scripts"],
                                  ex["target"], scripts)
        _check_kanji_reading(r, f"{where}: examples[{j}]", ex, ex["target"], script,
                             scripts, what="example")
        given = check_given_words(r, where, f"examples[{j}].", ex.get("words"),
                                  ex["target"])
        if given is not None and words is not None:
            words[j] = given
        bases = check_bases(r, where, f"examples[{j}].", ex.get("bases"),
                            ex["target"], cid, lang, script, core=form == "core",
                            given=given)
        found.append((j, ex["target"], bases))
    return found


def check_ref(r: Report, idx: int, card: dict, seen: set[str],
              id_re: re.Pattern[str], *, form: str = "single", lang: str = "xx",
              script: str = "other", scripts: list[str] | None = None) -> None:
    """A card written in another deck, listed here by its id, with any
    native-side fields this deck gives it. A core's ref gives none: its
    layers do."""
    rid = card.get("ref")
    where = f"cards[{idx}]"
    if not _is_str(rid) or not id_re.fullmatch(rid):
        r.error(where, f"ref must be a card id of this deck's language, got {rid!r}")
        return
    core = form == "core"
    where = f"ref {rid}"
    if rid in seen:
        r.error(where, "this card is already in the deck")
    seen.add(rid)
    for unknown in sorted(set(card) - (CORE_REF_KEYS if core else REF_KEYS), key=str):
        if core and unknown in NATIVE_SIDE:
            r.error(where, f"a core card's {unknown!r} is in each layer, under "
                           f"cards.{rid}")
        elif unknown in CARD_KEYS:
            r.error(where, f"a ref cannot give {unknown!r}: it belongs to the card "
                           f"itself, where it is written")
        else:
            r.error(where, f"unknown field {unknown!r}")
    for key in ("reading",) if core else ("native", "reading"):
        if key in card and not _is_str(card[key]):
            r.error(where, f"{key} must be a non-empty string")
    for key in ("tags",) if core else ("alt_native", "tags"):
        if key in card:
            _check_str_list(r, where, key, card[key])
    if not core:
        check_not_synonyms(r, where, card)
    check_notes(r, where, card.get("notes"), rid, lang, script, core=core)
    _check_modes(r, where, card.get("modes"))
    if "wiktionary" in card and not core:
        _check_wiktionary(r, where, "", card["wiktionary"])
    _check_examples(r, where, card.get("examples"), form=form, cid=rid, lang=lang,
                    script=script, scripts=scripts)
    # A core's refs are only checked to exist: whether a learner sees one is
    # the merge's (ADR-0036), not an error.
    r.refs.append((rid, core or _is_str(card.get("native")), where))


def check_pattern(r: Report, pattern: object, *, core: bool = False) -> None:
    """A grammar deck's table. A core's keeps the language side, its slots
    and its entries' forms; the names, prompt and glosses are each layer's."""
    where = "pattern"
    if not isinstance(pattern, dict):
        r.error(where, "must be a mapping")
        return

    for unknown in sorted(set(pattern) - PATTERN_KEYS, key=str):
        r.error(where, f"unknown field {unknown!r}")
    if core:
        for key in ("name", "slot_name", "prompt", "notes"):
            if key in pattern:
                r.error(where, f"a core pattern's {key!r} is in each layer, under "
                               f"pattern")
    else:
        for key in ("name", "slot_name"):
            if not _is_str(pattern.get(key)):
                r.error(where, f"{key} is required")
        _check_optional_text(r, where, pattern, "notes")
        _check_retired_prompt(r, where, pattern)

    slots = pattern.get("slots")
    if not isinstance(slots, list) or not slots:
        r.error(where, "slots must be a non-empty list")
        return
    _check_str_list(r, where, "slots", slots)
    if len(set(slots)) != len(slots):
        r.error(where, "slots contains duplicates")

    entries = pattern.get("entries")
    if not isinstance(entries, list) or not entries:
        r.error(where, "entries must be a non-empty list")
        return

    lemmas: set[str] = set()
    # What each row puts into its expanded card ids: its key, or its lemma.
    id_parts: set[str] = set()
    for i, entry in enumerate(entries):
        ewhere = f"pattern.entries[{i}]"
        if not isinstance(entry, dict):
            r.error(ewhere, "must be a mapping")
            continue
        id_part = "?"
        for unknown in sorted(set(entry) - CORE_ENTRY_KEYS - {"gloss"}, key=str):
            r.error(ewhere, f"unknown field {unknown!r}")
        if "reading" in entry and not _is_str(entry.get("reading")):
            r.error(ewhere, "reading, the lemma romanised, must be a non-empty "
                            "string or omitted")
        lemma = entry.get("lemma")
        if not _is_str(lemma):
            r.error(ewhere, "lemma is required")
        else:
            ewhere = f"pattern.entries[{lemma}]"
            if lemma in lemmas:
                r.error(ewhere, "duplicate lemma")
            lemmas.add(lemma)
            r.pattern_lemmas.append(lemma)
            # Card ids are ASCII (AGENTS.md rule 1): a lemma such as जाना
            # names its row with a key instead.
            key = entry.get("key")
            if key is not None:
                if not _is_str(key) or not ID_RE.fullmatch(key):
                    r.error(ewhere, f"key must match [a-z0-9-]+, got {key!r}")
                    key = None
            elif not ID_RE.fullmatch(lemma):
                r.error(ewhere, f"lemma {lemma!r} cannot go into a card id; "
                                f"give the entry a key of lowercase letters "
                                f"and digits, like 'jaanaa'")
            id_part = key if key is not None else lemma
            if id_part in id_parts:
                r.error(ewhere, f"{id_part!r} already names another row")
            id_parts.add(id_part)
        if core:
            if "gloss" in entry:
                r.error(ewhere, f"a core entry's gloss is in each layer, under "
                                f"pattern.entries.{id_part}")
        elif not _is_str(entry.get("gloss")):
            r.error(ewhere, "gloss is required")

        forms = entry.get("forms")
        if not _check_forms(r, ewhere, forms, slots):
            continue
        check_pattern_readings(r, ewhere, entry, forms, slots)
        check_pattern_ipas(r, ewhere, entry, forms, slots)


def _check_forms(r: Report, where: str, forms: object, slots: list) -> bool:
    """A grammar entry's or a rules row's forms: every slot, as a form, a
    list of forms (the first shown, all accepted), or null. True when it is
    a mapping, so that its readings can be checked."""
    if not isinstance(forms, dict):
        r.error(where, "forms must be a mapping")
        return False
    missing = [s for s in slots if s not in forms]
    if missing:
        r.error(where, f"forms missing slots: {missing}")
    for extra in sorted(set(forms) - set(slots), key=str):
        r.error(where, f"forms has key {extra!r} which is not a slot")
    filled = [s for s in slots if forms.get(s) is not None]
    if not filled:
        r.error(where, "every form is null; nothing to drill")
    for slot in slots:
        val = forms.get(slot)
        if isinstance(val, list):
            # The first is the form shown; every one is accepted (#144).
            if not val or not all(_is_str(v) for v in val):
                r.error(where, f"forms[{slot!r}] must list non-empty strings")
            elif len(set(val)) != len(val):
                r.error(where, f"forms[{slot!r}] lists a form twice")
        elif val is not None and not _is_str(val):
            r.error(where, f"forms[{slot!r}] must be a form, a list of forms, "
                           f"or null")
    return True


def check_pattern_readings(r: Report, where: str, entry: dict, forms: dict,
                           slots: list) -> None:
    """An entry's `readings`, each form romanised (#47): a reading, or a list
    of them, for every slot with a form, and none for a slot without."""
    readings = entry.get("readings")
    if readings is None:
        return
    if not isinstance(readings, dict):
        r.error(where, "readings must be a mapping of slot to reading")
        return
    for extra in sorted(set(readings) - set(slots)):
        r.error(where, f"readings has key {extra!r} which is not a slot")
    for slot in slots:
        form, reading = forms.get(slot), readings.get(slot)
        if form is None:
            if reading is not None:
                r.error(where, f"readings[{slot!r}] given for a slot with no form")
            continue
        if reading is None:
            r.error(where, f"readings[{slot!r}] is missing; every form has one")
        elif isinstance(reading, list):
            if not reading or not all(_is_str(v) for v in reading):
                r.error(where, f"readings[{slot!r}] must list non-empty strings")
        elif not _is_str(reading):
            r.error(where, f"readings[{slot!r}] must be a reading or a list")


def check_pattern_ipas(r: Report, where: str, entry: dict, forms: dict,
                       slots: list) -> None:
    """An entry's `ipas`, the form shown in each slot in the IPA
    (ADR-0025): one for every slot with a form, and none for a slot
    without."""
    ipas = entry.get("ipas")
    if ipas is None:
        return
    if not isinstance(ipas, dict):
        r.error(where, "ipas must be a mapping of slot to IPA")
        return
    for extra in sorted(set(ipas) - set(slots)):
        r.error(where, f"ipas has key {extra!r} which is not a slot")
    for slot in slots:
        form, ipa = forms.get(slot), ipas.get(slot)
        if form is None:
            if ipa is not None:
                r.error(where, f"ipas[{slot!r}] given for a slot with no form")
        elif ipa is None:
            r.error(where, f"ipas[{slot!r}] is missing; every form has one")
        elif not _is_str(ipa):
            r.error(where, f"ipas[{slot!r}] must be text")


def _ipas_in(node: object):
    """Every IPA transcription in a file: the values of `ipa` and `ipas`
    keys, wherever they are."""
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "ipa" and isinstance(value, str):
                yield value
            elif key == "ipas" and isinstance(value, dict):
                yield from (v for v in value.values() if isinstance(v, str))
            else:
                yield from _ipas_in(value)
    elif isinstance(node, list):
        for item in node:
            yield from _ipas_in(item)


def check_ipa(r: Report, raw: dict) -> None:
    """Every IPA transcription is broad IPA, without the slashes the app
    adds (ADR-0025). In the IPA course (language `ipa`) an example may also
    be narrow, written inside square brackets: `[pʰɪn]`."""
    language = raw.get("language")
    if isinstance(language, dict):
        language = language.get("code")
    narrow_ok = language == "ipa"
    for ipa in sorted(set(_ipas_in(raw))):
        if ipa != unicodedata.normalize("NFC", ipa):
            r.error("ipa", f"{ipa!r} is not NFC-normalised")
        elif (narrow_ok and len(ipa) > 2 and ipa[0] == "[" and ipa[-1] == "]"
              and IPA_RE.fullmatch(ipa[1:-1])):
            continue
        elif ipa != ipa.strip() or not IPA_RE.fullmatch(ipa):
            r.error("ipa", f"{ipa!r} is not a broad IPA transcription: IPA "
                           f"letters and marks only, without / / or [ ]")


PHONETIC_SOURCES = ("wiktionary", "rules")


def check_phonetic(r: Report, raw: dict) -> None:
    """A card's `phonetic` is a narrow IPA transcription written inside square
    brackets, `[ˈkʰæt]`, and `phonetic_source` says where it came from:
    `wiktionary` or `rules`. Each needs the other. `ipa` stays broad."""
    cards = raw.get("cards")
    if not isinstance(cards, list):
        return
    for card in cards:
        if not isinstance(card, dict):
            continue
        where = f"cards[{card.get('id')}]"
        phonetic = card.get("phonetic")
        source = card.get("phonetic_source")
        if phonetic is None and source is None:
            continue
        if phonetic is None:
            r.error(where, "phonetic_source is given without phonetic")
            continue
        if not isinstance(phonetic, str):
            r.error(where, "phonetic must be text")
            continue
        if phonetic != unicodedata.normalize("NFC", phonetic):
            r.error(where, f"phonetic {phonetic!r} is not NFC-normalised")
        elif not (len(phonetic) > 2 and phonetic[0] == "[" and phonetic[-1] == "]"
                  and IPA_RE.fullmatch(phonetic[1:-1])):
            r.error(where, f"phonetic {phonetic!r} must be IPA letters and marks "
                           f"inside square brackets, as [ˈkʰæt]")
        if source not in PHONETIC_SOURCES:
            r.error(where, f"phonetic_source must be one of "
                           f"{', '.join(PHONETIC_SOURCES)} when phonetic is given, "
                           f"not {source!r}")


def _readings_in(node: object):
    """Every romanisation in a file: the values of `reading` and `readings`
    keys, wherever they are."""
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "reading" and isinstance(value, str):
                yield value
            elif key == "readings" and isinstance(value, dict):
                for v in value.values():
                    if isinstance(v, str):
                        yield v
                    elif isinstance(v, list):
                        yield from (x for x in v if isinstance(x, str))
            else:
                yield from _readings_in(value)
    elif isinstance(node, list):
        for item in node:
            yield from _readings_in(item)


def _uses_iso15919(file: Path) -> bool:
    try:
        raw = _load_deck(file.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError):
        return False
    return isinstance(raw, dict) and raw.get("standard") == "ISO 15919"


def check_romanised(r: Report, raw: dict, path: Path, *, lang: str | None = None,
                    directory: Path | None = None) -> None:
    """Once a language has its romanisation file (#47), every reading in its
    files is in that scheme: lowercase, no capitals, and no diacritics but
    ISO 15919's where the file names that standard (ADR-0025). A layer gives
    its core's language and directory, where the file is."""
    if lang is not None:
        code = lang
    else:
        block = raw.get("language")
        code = block.get("code") if isinstance(block, dict) else block
    folder = directory if directory is not None else path.parent
    file = folder / f"{code}-romanisation.yaml" if _is_str(code) else None
    if file is None or not file.exists():
        return
    iso = _uses_iso15919(file)
    pattern = ISO_ROMAN_RE if iso else ROMAN_RE
    for reading in sorted(set(_readings_in(raw))):
        if reading != unicodedata.normalize("NFC", reading):
            r.error("reading", f"{reading!r} is not NFC-normalised")
        elif not pattern.fullmatch(reading):
            what = ("lowercase ISO 15919 letters, no capitals" if iso
                    else "lowercase ASCII, no diacritics or capitals")
            r.error("reading", f"{reading!r} is not in the {code} romanisation: "
                               f"{what}")


def check_romanisation_file(r: Report, raw: dict, path: Path) -> None:
    """decks/<lang>/<lang>-romanisation.yaml: the language's romanisation
    scheme, and the spellings a learner may type for the same sound (#47)."""
    for unknown in sorted(set(raw) - ROMANISATION_KEYS):
        r.error("root", f"unknown field {unknown!r}")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang = raw.get("language")
    if not _is_str(lang) or not CODE_RE.fullmatch(lang):
        r.error("language", f"must be a language code, {_code_error(lang)}")
    elif path.stem != f"{lang}-romanisation" or raw.get("id") != path.stem:
        r.error("id", f"a romanisation file is {lang}-romanisation.yaml with id "
                      f"{lang}-romanisation")
    if not _is_str(raw.get("scheme")):
        r.error("scheme", "is required: how the language is romanised, in a line")
    standard = raw.get("standard")
    if standard is not None and standard != "ISO 15919":
        r.error("standard", f"the one standard known is 'ISO 15919', got "
                            f"{standard!r}")
    typed = raw.get("typed")
    if typed is not None:
        if standard is None:
            r.error("typed", "is for a reading in a standard's letters; name "
                             "the standard")
        elif not isinstance(typed, list):
            r.error("typed", "must be a list of [letters, typed] pairs")
        else:
            for i, pair in enumerate(typed):
                if (not isinstance(pair, list) or len(pair) != 2
                        or not _is_str(pair[0]) or not isinstance(pair[1], str)):
                    r.error(f"typed[{i}]", "must be a pair: the letters in a "
                                           "reading, and how they are typed")
                elif not ISO_PIECE_RE.fullmatch(pair[0]):
                    r.error(f"typed[{i}]", f"{pair[0]!r} must be ISO 15919 "
                                           f"letters")
                elif pair[1] and not ROMAN_PIECE_RE.fullmatch(pair[1]):
                    r.error(f"typed[{i}]", f"{pair[1]!r} must be lowercase "
                                           f"ASCII letters, or empty for "
                                           f"letters not typed")
    groups = raw.get("equivalents")
    if not isinstance(groups, list):
        r.error("equivalents", "must be a list of groups of spellings")
        return
    seen: dict[str, int] = {}
    for i, group in enumerate(groups):
        where = f"equivalents[{i}]"
        if (not isinstance(group, list) or len(group) < 2
                or not all(_is_str(g) for g in group)):
            r.error(where, "must list two or more spellings")
            continue
        for spelling in group:
            if not ROMAN_PIECE_RE.fullmatch(spelling):
                r.error(where, f"{spelling!r} must be lowercase ASCII letters")
            elif spelling in seen:
                r.error(where, f"{spelling!r} is already in equivalents[{seen[spelling]}]")
            else:
                seen[spelling] = i


def check_resources_file(r: Report, raw: dict, path: Path) -> None:
    """decks/<lang>/<lang>-resources.yaml: where else to learn the language,
    up to three suggestions the app shows in the language's sheet (#832)."""
    for unknown in sorted(set(raw) - RESOURCES_KEYS, key=str):
        r.error("root", f"unknown field {unknown!r}")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang = raw.get("language")
    if not _is_str(lang) or not CODE_RE.fullmatch(lang):
        r.error("language", f"must be a language code, {_code_error(lang)}")
        lang = None
    elif path.stem != f"{lang}-resources" or raw.get("id") != path.stem:
        r.error("id", f"a resources file is {lang}-resources.yaml with id "
                      f"{lang}-resources")
    items = raw.get("resources")
    if not isinstance(items, list) or not items:
        r.error("resources", "must be a non-empty list")
        return
    if len(items) > MAX_RESOURCES:
        r.error("resources", f"at most {MAX_RESOURCES} resources a language, "
                             f"got {len(items)}")
    seen: set[str] = set()
    for i, item in enumerate(items):
        where = f"resources[{i}]"
        if not isinstance(item, dict):
            r.error(where, "must be a mapping")
            continue
        for unknown in sorted(set(item) - RESOURCE_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        rid = item.get("id")
        if not _is_str(rid) or not re.fullmatch(
                r"[a-z]{2,3}-res-[a-z0-9]+(?:-[a-z0-9]+)*", rid):
            r.error(where, f"id must be the language, -res- and a name, as "
                           f"{lang or 'xx'}-res-wagotabi, got {rid!r}")
        elif lang is not None and not rid.startswith(f"{lang}-res-"):
            r.error(where, f"id {rid!r} must start with {lang}-res-")
        elif rid in seen:
            r.error(where, f"id {rid!r} is used twice")
        else:
            seen.add(rid)
        for key in ("name", "why"):
            if not _is_str(item.get(key)) or not item[key].strip():
                r.error(where, f"{key} is required text, got {item.get(key)!r}")
        why = item.get("why")
        if _is_str(why) and len(why) > MAX_RESOURCE_WHY:
            r.error(where, f"why is {len(why)} characters; keep it to "
                           f"{MAX_RESOURCE_WHY}, two or three short lines")
        kind = item.get("kind")
        if kind not in RESOURCE_KINDS:
            r.error(where, f"kind must be one of {sorted(RESOURCE_KINDS)}, "
                           f"got {kind!r}")
        url = item.get("url")
        parsed = urlparse(url) if _is_str(url) else None
        if parsed is None or parsed.scheme != "https" or not parsed.netloc:
            r.error(where, f"url must be an https address, got {url!r}")


def check_phonetics_file(r: Report, raw: dict, path: Path) -> None:
    """decks/<lang>/<lang>-phonetics.yaml: the ordered rules that turn a card's
    broad `ipa` into its narrow `phonetic` (tools/derive_phonetic.py). Each
    rule is a regular expression, its replacement and the source that
    attests it."""
    for unknown in sorted(set(raw) - PHONETICS_KEYS, key=str):
        r.error("root", f"unknown field {unknown!r}")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang = raw.get("language")
    if not _is_str(lang) or not CODE_RE.fullmatch(lang):
        r.error("language", f"must be a language code, {_code_error(lang)}")
        lang = None
    elif path.stem != f"{lang}-phonetics" or raw.get("id") != path.stem:
        r.error("id", f"a phonetic rules file is {lang}-phonetics.yaml with id "
                      f"{lang}-phonetics")
    if not _is_str(raw.get("variety")) or not raw["variety"].strip():
        r.error("variety", "is required: the variety the rules describe, in a line")
    rules = raw.get("rules")
    if not isinstance(rules, list) or not rules:
        r.error("rules", "must be a non-empty list")
        return
    seen: set[str] = set()
    for i, rule in enumerate(rules):
        where = f"rules[{i}]"
        if not isinstance(rule, dict):
            r.error(where, "must be a mapping")
            continue
        for unknown in sorted(set(rule) - PHONETIC_RULE_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        rid = rule.get("id")
        if not _is_str(rid) or not re.fullmatch(
                r"[a-z]{2,3}-[a-z0-9]+(?:-[a-z0-9]+)*", rid):
            r.error(where, f"id must be the language and a name, as "
                           f"{lang or 'xx'}-n-velar, got {rid!r}")
        elif lang is not None and not rid.startswith(f"{lang}-"):
            r.error(where, f"id {rid!r} must start with {lang}-")
        elif rid in seen:
            r.error(where, f"id {rid!r} is used twice")
        else:
            seen.add(rid)
        pattern = rule.get("pattern")
        if not _is_str(pattern) or not pattern:
            r.error(where, "pattern is required: a regular expression")
        else:
            try:
                re.compile(pattern)
            except re.error as e:
                r.error(where, f"pattern {pattern!r} is not a regular expression: {e}")
        if not isinstance(rule.get("replace"), str):
            r.error(where, "replace is required text (it may be empty)")
        source = rule.get("source")
        if not _is_str(source) or len(source.strip()) < 10:
            r.error(where, "source is required: the work that attests the rule, "
                           "such as an author, a title and a year")


def _code_error(value: object) -> str:
    if isinstance(value, bool):
        return (f"got the boolean {value!r} -- YAML read a bare true or false "
                f"as a bool. Quote the code.")
    return f"got {value!r}"


def check_facts(r: Report, facts: object, lang: str | None = None) -> None:
    """A language's daily facts. See "Facts files" in docs/DECK-FORMAT.md."""
    r.facts_lang = lang
    if not isinstance(facts, list) or not facts:
        r.error("facts", "must be a non-empty list")
        return

    seen: set[str] = set()
    universal = 0
    # English is the base interface language (ADR-0006), so it is counted even
    # when no fact is written in it: a facts file with no English text warns.
    universal_by_language: dict[str, int] = {"en": 0}
    for i, fact in enumerate(facts):
        where = f"facts[{i}]"
        if not isinstance(fact, dict):
            r.error(where, "must be a mapping")
            continue

        fid = fact.get("id")
        if not _is_str(fid) or not ID_RE.fullmatch(fid):
            r.error(where, f"id must match [a-z0-9-]+, got {fid!r}")
        else:
            where = f"fact {fid}"
            if fid in seen:
                r.error(where, "duplicate fact id")
            seen.add(fid)

        for unknown in sorted(set(fact) - FACT_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")

        text = fact.get("text")
        written_in: list[str] = []
        if not isinstance(text, dict) or not text:
            r.error(where, "text must map language codes to the fact, e.g. { en: ... }")
            text = {}
        for code, value in text.items():
            if not isinstance(code, str) or not LANG_RE.fullmatch(code):
                r.error(where, f"text key must be a 2-3 letter language code, "
                               f"{_code_error(code)}")
            elif isinstance(value, bool):
                r.error(where, f"text.{code} parsed as the boolean {value!r}. Quote the value.")
            elif not _is_str(value):
                r.error(where, f"text.{code} must be non-empty text")
            else:
                written_in.append(code)

        contrast = fact.get("contrast")
        if contrast is None:
            universal += 1
            for code in written_in:
                universal_by_language[code] = universal_by_language.get(code, 0) + 1
        elif not isinstance(contrast, str) or not LANG_RE.fullmatch(contrast):
            r.error(where, f"contrast must be a 2-3 letter language code, "
                           f"{_code_error(contrast)}")
        elif contrast not in text:
            r.error(where, f"contrast is {contrast!r}, so text needs a {contrast!r} "
                           f"entry: the fact is shown only to learners whose "
                           f"interface language is {contrast!r}")

        if "tags" in fact:
            _check_str_list(r, where, "tags", fact["tags"])
        _check_optional_text(r, where, fact, "source")
        _check_source_shape(r, where, "fact", fact.get("source"), fact.get("id"))
        if "cards" in fact:
            _check_fact_cards(r, where, fact["cards"], lang or "xx")

    if universal < MIN_FACTS:
        r.error("facts", f"needs at least {MIN_FACTS} facts without a contrast, "
                         f"true whatever the interface language; has {universal}")
    for code, count in sorted(universal_by_language.items()):
        if count < MIN_FACTS:
            r.warn("facts", f"only {count} facts without a contrast have {code!r} "
                            f"text, so learners with that interface language get "
                            f"{count} daily facts, not {MIN_FACTS}")


def check_situations(r: Report, situations: object, lang: str | None = None) -> None:
    """A language's situation sheets (#724). See "Situations files" in
    docs/DECK-FORMAT.md."""
    r.facts_lang = lang
    r.situations_lang = lang
    if not isinstance(situations, list) or not situations:
        r.error("situations", "must be a non-empty list")
        return
    id_re = card_id_re(lang or "xx")
    seen: set[str] = set()
    icons: set[str] = set()
    for i, sit in enumerate(situations):
        where = f"situations[{i}]"
        if not isinstance(sit, dict):
            r.error(where, "must be a mapping")
            continue
        sid = sit.get("id")
        if not _is_str(sid) or not ID_RE.fullmatch(sid):
            r.error(where, f"id must match [a-z0-9-]+, got {sid!r}")
        else:
            where = f"situation {sid}"
            if sid in seen:
                r.error(where, "duplicate situation id")
            seen.add(sid)
            r.situation_ids.append(sid)
        for unknown in sorted(set(sit) - SITUATION_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")

        icon = sit.get("icon")
        if icon not in SITUATION_ICONS:
            r.error(where, f"icon must be one of {', '.join(SITUATION_ICONS)}, got {icon!r}")
        elif icon in icons:
            r.error(where, f"icon {icon!r} is on another situation: each button has "
                           f"its own")
        else:
            icons.add(icon)

        title = sit.get("title")
        if not isinstance(title, dict) or not title:
            r.error(where, "title must map language codes to the sheet's title, "
                           "e.g. { en: Taxi }")
        else:
            if "en" not in title:
                r.error(where, "title needs an English entry")
            for code, value in title.items():
                if not isinstance(code, str) or not LANG_RE.fullmatch(code):
                    r.error(where, f"title key must be a 2-3 letter language code, "
                                   f"{_code_error(code)}")
                elif isinstance(value, bool):
                    r.error(where, f"title.{code} parsed as the boolean {value!r}. "
                                   f"Quote the value.")
                elif not _is_str(value):
                    r.error(where, f"title.{code} must be non-empty text")

        listed: set[str] = set()
        for key in ("phrases", "words"):
            if key not in sit:
                continue
            cards = sit[key]
            if not isinstance(cards, list) or not cards:
                r.error(where, f"{key} must be a non-empty list of {lang or 'xx'} card ids")
                continue
            for k, cid in enumerate(cards):
                if not _is_str(cid) or not id_re.fullmatch(cid):
                    r.error(where, f"{key}[{k}] must be the id of a {lang or 'xx'} "
                                   f"card, got {cid!r}")
                elif cid in listed:
                    r.error(where, f"{cid} is listed twice")
                else:
                    listed.add(cid)
                    r.base_refs.append((cid, where, f"{key}[{k}]"))
        if not listed:
            r.error(where, "lists no cards: give phrases, words or both")


def _check_fact_cards(r: Report, where: str, cards: object, lang: str) -> None:
    """The cards a fact is about (#516), by id, each checked across files to
    be a card of the language."""
    id_re = card_id_re(lang)
    if not isinstance(cards, list) or not cards:
        r.error(where, f"cards must be a non-empty list of {lang} card ids")
        return
    for k, cid in enumerate(cards):
        if not _is_str(cid) or not id_re.fullmatch(cid):
            r.error(where, f"cards[{k}] must be the id of a {lang} card, got {cid!r}")
        elif cid in cards[:k]:
            r.error(where, f"cards lists {cid} twice")
        else:
            r.base_refs.append((cid, where, f"cards[{k}]"))


# --- Transliteration in prose ------------------------------------------------
# "Always keep the transliteration, even in descriptions or labels" (owner,
# 2026-10-06): a word in a script other than Latin, quoted in a deck's notes,
# meanings, labels or explanations, is followed by its reading in
# parentheses, లేదు (lēdu), or follows it, lēdu (లేదు). A learner who cannot
# read the script yet can read the note. See docs/DECK-FORMAT.md.

_SCRIPT = ("ऀ-෿Ͱ-ϿЀ-ӿ֐-׿؀-ۿ"
           "฀-๿぀-ヿ一-鿿가-힯")
_SCRIPT_CHAR = re.compile(f"[{_SCRIPT}]")
# An apostrophe inside a word is part of it in Eastern Nagari (Assamese ক'লা,
# ম'হ): a run goes on over one between two letters of that block, and over no
# other quote, so a stray one still ends the run.
_NAGARI_APOSTROPHE = "(?<=[\u0980-\u09ff])['’](?=[\u0980-\u09ff])"
_SCRIPT_RUN = re.compile(
    rf"-?[{_SCRIPT}](?:[{_SCRIPT}‌‍]|{_NAGARI_APOSTROPHE}|[ -](?=[{_SCRIPT}]))*"
    rf"(?:-(?!\w))?")
_LATIN = "A-Za-zÀ-ɏḀ-ỿ"
_DANDAS = "।॥"
# Signs with no sound of their own: the virama and the nukta.
_SILENT = set("़়઼಼्্્్್")
# The script a field written for speakers of a language is in: its own words
# need no reading there.
_CODE_BLOCK = {"hi": 0x0900, "mr": 0x0900, "ne": 0x0900, "sa": 0x0900,
               "bn": 0x0980, "as": 0x0980, "gu": 0x0A80, "te": 0x0C00,
               "kn": 0x0C80}
# The same, by the script a language block names: a core's own language is
# read as written in it.
_SCRIPT_BLOCK = {"devanagari": 0x0900, "bengali": 0x0980, "gurmukhi": 0x0A00,
                 "gujarati": 0x0A80, "odia": 0x0B00, "tamil": 0x0B80,
                 "telugu": 0x0C00, "kannada": 0x0C80, "malayalam": 0x0D00,
                 "sinhala": 0x0D80,
                 "perso_arabic": 0x0600, "arabic": 0x0600, "shahmukhi": 0x0600,
                 "han": 0x4E00, "han_simplified": 0x4E00,
                 "han_traditional": 0x4E00, "kana": 0x3040, "hangul": 0xAC00}
# Keys whose values are the word itself, not prose about it.
# `phonetic` is IPA, which uses Greek letters (β, θ, χ) and needs no reading.
_WORD_KEYS = {"id", "key", "target", "reading", "readings", "ipa", "ipas", "phonetic",
              "term", "example", "letters", "letter", "forms", "alternatives",
              "answer", "answers", "accept", "equivalents", "words", "tiles",
              "source", "scheme", "audio", "image", "icon",
              # The B1 format's (ADR-0036): a base's word, a card or a rule
              # named by id.
              "word", "base", "ref", "core", "except", "rules", "part", "region"}


# Scripts larger than one 128-code-point block, each counted as one, so
# that a word in them is one run with one reading after it: Han with kana
# (Japanese writes both in one word, 日本語 and its okurigana), and Hangul.
_HAN_KANA = (
    (0x3040, 0x30FF),    # hiragana, katakana
    (0x31F0, 0x31FF),    # katakana phonetic extensions
    (0x3400, 0x4DBF),    # CJK extension A
    (0x4E00, 0x9FFF),    # CJK unified ideographs
    (0xF900, 0xFAFF),    # CJK compatibility ideographs
    (0xFF66, 0xFF9F),    # halfwidth katakana
    (0x20000, 0x3FFFF),  # CJK extensions B and on
)
_HANGUL = (
    (0x1100, 0x11FF),    # jamo
    (0x3130, 0x318F),    # compatibility jamo
    (0xAC00, 0xD7AF),    # syllables
)


def _block(ch: str) -> int:
    """The 128-code-point block of [ch]; Arabic and its Perso-Arabic letters
    (U+0600-U+06FF, U+0750-U+077F) count as one, as do Han with kana, and
    Hangul ([_HAN_KANA], [_HANGUL])."""
    o = ord(ch)
    if 0x0600 <= o <= 0x06FF or 0x0750 <= o <= 0x077F:
        return 0x0600 >> 7
    if any(lo <= o <= hi for lo, hi in _HAN_KANA):
        return 0x4E00 >> 7
    if any(lo <= o <= hi for lo, hi in _HANGUL):
        return 0xAC00 >> 7
    return o >> 7


def _script_runs(text: str):
    """Each run of one non-Latin script in [text], with where it starts."""
    for m in _SCRIPT_RUN.finditer(text):
        start, run, block = m.start(), "", None
        for i, ch in enumerate(m.group(0)):
            mark = unicodedata.category(ch).startswith("M")
            b = _block(ch) if _SCRIPT_CHAR.match(ch) and not mark else None
            if b is not None and block is not None and b != block:
                kept = run.rstrip(" -")
                yield start, kept
                start, run = m.start() + i, ""
            if b is not None:
                block = b
            run += ch
        yield start, run


def _untransliterated(text: str, code: str | None, own: int | None = None) -> list[str]:
    """The runs of script in [text] with no reading beside them. [own] is
    the block of a script the text's readers read as written: a core's own
    language's."""
    letter = _LATIN if code in (None, "en") else r"\w"
    missing = []
    for start, run in _script_runs(text):
        lead = len(run) - len(run.lstrip(_DANDAS + " "))
        run = run.strip(_DANDAS + " ")
        start += lead
        end = start + len(run)
        first = next((c for c in run if _SCRIPT_CHAR.match(c)), None)
        if first is None or all(c in _SILENT or c == "-" for c in run):
            continue
        if own is not None and _block(first) == _block(chr(own)):
            continue
        if code not in (None, "en"):
            if code in _CODE_BLOCK and _block(first) == _block(chr(_CODE_BLOCK[code])):
                continue
        after = text[end:end + 12]
        if re.match(rf"[?!.,;:]?\s?\(\s?[*_'\"]?-?(?:\d|[{letter}])", after):
            continue
        if (re.search(rf"[{_LATIN}]\S*\s?\(\s*$", text[max(0, start - 45):start])
                and re.match(r"[?!.]?\s*\)", after)):
            continue
        missing.append(run)
    return missing


def check_transliterated(r: Report, raw: object, *, fixed: str | None = None,
                         own: int | None = None,
                         word_keys: set[str] = _WORD_KEYS) -> None:
    """Every run of script in a deck's prose carries its reading.

    In a core or a layer the language of every string is [fixed] for the
    whole file, never taken from a key: a slot key such as `lo` would read
    as Lao. A core is in the language learnt, so its own script, [own], is
    read as written."""
    def walk(node: object, path: list[str]) -> None:
        if isinstance(node, dict):
            for k, v in node.items():
                walk(v, path + [str(k)])
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, path + [str(i)])
        elif isinstance(node, str):
            keys = [p for p in path if not p.isdigit()]
            key = keys[-1] if keys else ""
            if key in word_keys or any(k in ("forms", "ipas", "readings",
                                             "alternatives", "target_scripts") for k in keys[:-1]):
                return
            if key == "text" and "passages" in keys:
                return
            # A character block's radical is itself one character, checked
            # as such by _check_character; its reading is the card's own.
            if key == "radical" and keys[-2:-1] == ["character"]:
                return
            if fixed is not None:
                code = fixed
            else:
                code = key if LANG_RE.fullmatch(key) and key not in ("name",) else None
            if code in (None, "en") and not re.search(f"[{_LATIN}]{{2,}}", node):
                return
            for run in _untransliterated(node, code, own):
                r.error(".".join(path),
                        f"{run!r} has no transliteration beside it; write its "
                        f"ISO 15919 reading in parentheses, as లేదు (lēdu)")
    walk(raw, [])


def private_ids_in(raw: object) -> list[str]:
    """The private ids (`fnpd-...`) a deck file writes: its own id, its cards'
    ids, and the keys a layer gives translations under."""
    found: list[str] = []
    if not isinstance(raw, dict):
        return found
    deck_id = raw.get("id")
    if isinstance(deck_id, str) and deck_id.startswith(PRIVATE_ID_MARKER):
        found.append(deck_id)
    cards = raw.get("cards")
    if isinstance(cards, list):
        for card in cards:
            cid = card.get("id") if isinstance(card, dict) else None
            if isinstance(cid, str) and cid.startswith(PRIVATE_ID_MARKER):
                found.append(cid)
    elif isinstance(cards, dict):
        found.extend(k for k in cards
                     if isinstance(k, str) and k.startswith(PRIVATE_ID_MARKER))
    return found


def check_not_private(r: Report, raw: dict) -> None:
    """A private language package never goes under `decks/` (#1017): its ids
    are the learner's own, and the repository's decks are shared. Refused
    here, outside `--private`, so that the repository never holds one."""
    if raw.get("format") == "fluenough-private":
        r.error("format", "a private package's manifest is not a deck; a private "
                          "package is checked with --private and never goes in decks/")
    ids = private_ids_in(raw)
    if ids:
        r.error("id", f"{ids[0]!r} is a private id (fnpd-...), which is never allowed "
                      f"in decks/; check a private package with --private")


def validate(path: Path) -> Report:
    r = Report(path)
    try:
        raw = _load_deck(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        r.error("yaml", str(exc).replace("\n", " "))
        return r
    except UnicodeDecodeError as exc:
        r.error("encoding", f"file is not valid UTF-8: {exc}")
        return r

    if not isinstance(raw, dict):
        r.error("root", "deck must be a YAML mapping")
        return r

    if not PRIVATE_MODE:
        check_not_private(r, raw)
        if r.errors:
            return r

    # Proposals are not deck content until applied (ADR-0038): taken out
    # before any other check, and checked on their own.
    proposals = strip_proposals(raw)
    checks = strip_checks(raw)
    _validate_raw(r, raw, path)
    check_reviewed_cards(r, raw, checks)
    check_proposals(r, proposals)
    check_checks(r, checks)
    if checks:
        check_checks_hashable(r, path)
    return r


# Fewer files than this are validated in this process: starting workers costs
# more than they save.
PARALLEL_MIN_FILES = 24


def _single_threaded() -> bool:
    """Whether no other thread runs here, so that forking is safe. Threads
    that `threading` does not know (a test runner's) are looked for in /proc."""
    if threading.active_count() > 1 or os.environ.get("PYTEST_XDIST_WORKER"):
        return False
    try:
        return len(os.listdir("/proc/self/task")) <= 1
    except OSError:
        return True


# Each worker keeps its own cache of parsed files, so the workers are capped.
MAX_JOBS = 8
# Seconds a parallel run may take before it is given up for a serial one.
PARALLEL_TIMEOUT = 600


def default_jobs() -> int:
    """The workers [validate_many] uses unless told: one per CPU this process
    may run on, at most MAX_JOBS, and none where forking is unsafe, in a
    process with other threads."""
    if not _single_threaded():
        return 1
    try:
        cpus = len(os.sched_getaffinity(0))
    except (AttributeError, OSError):
        cpus = os.cpu_count() or 1
    return max(1, min(MAX_JOBS, cpus))


def validate_many(paths: list[Path], jobs: int | None = None) -> list[Report]:
    """[validate] of each of [paths], in the order given. Each file is checked
    on its own, so with [jobs] above 1 (default: [default_jobs]) they are
    shared among worker processes; the reports are the same as one process
    makes, in the same order. Without `fork` (Windows) it stays in one
    process. Left to itself it does not start workers for fewer than
    PARALLEL_MIN_FILES files; a [jobs] of 2 or more asked for does."""
    if jobs is None:
        jobs = default_jobs() if len(paths) >= PARALLEL_MIN_FILES else 1
    if jobs <= 1 or len(paths) < 2:
        return [validate(p) for p in paths]
    try:
        import multiprocessing
        from concurrent.futures import ProcessPoolExecutor
        context = multiprocessing.get_context("fork")
    except (ImportError, ValueError):
        return [validate(p) for p in paths]
    jobs = min(jobs, len(paths))
    # Small runs of neighbouring files, which are mostly one language's and
    # share its core files, are what each worker takes at a time.
    chunk = max(1, min(8, len(paths) // (jobs * 4)))
    pool = ProcessPoolExecutor(max_workers=jobs, mp_context=context)
    try:
        reports = list(pool.map(validate, paths, chunksize=chunk,
                                timeout=PARALLEL_TIMEOUT))
        pool.shutdown()
        return reports
    except Exception:  # noqa: BLE001
        # A worker that died or hung, or a report that cannot be sent back:
        # do it here, where a crash in a check is the traceback it always was.
        for process in list(getattr(pool, "_processes", {}).values()):
            process.kill()
        pool.shutdown(wait=False, cancel_futures=True)
        return [validate(p) for p in paths]


def _validate_raw(r: Report, raw: dict, path: Path) -> Report:
    """Every check of a file but its proposals'."""
    # What the file is, before any other check (ADR-0036): a layer, a core,
    # or anything else as today.
    if raw.get("kind") == "layer":
        validate_layer(r, raw, path)
        return r
    if raw.get("part") == "core" and raw.get("kind") in GUIDE_KINDS:
        check_romanised(r, raw, path)
        check_ipa(r, raw)
        if raw["kind"] == "sounds":
            check_sounds_file(r, raw, path, core=True)
        else:
            check_script_file(r, raw, path, core=True)
        return r
    if raw.get("part") == "core":
        validate_core(r, raw, path)
        return r
    if "part" in raw:
        r.error("part", f'must be "core", or left out on a single-file deck; got '
                        f'{raw["part"]!r}')

    if raw.get("kind") not in ("romanisation", "phonetics", "gating", "creators",
                               "topics", "sections", "recommendations"):
        check_transliterated(r, raw)

    if raw.get("kind") == "themes":
        check_themes_file(r, raw)
        return r
    if raw.get("kind") == "numbers":
        check_numbers_file(r, raw, path)
        return r
    if raw.get("kind") == "path":
        check_path_file(r, raw, path)
        return r
    if raw.get("kind") == "romanisation":
        check_romanisation_file(r, raw, path)
        return r
    if raw.get("kind") in SHARED_KIND_CHECKS:
        check_ipa(r, raw)
        SHARED_KIND_CHECKS[raw["kind"]](r, raw, path)
        return r
    if raw.get("kind") == "resources":
        check_resources_file(r, raw, path)
        return r
    if raw.get("kind") == "phonetics":
        check_phonetics_file(r, raw, path)
        return r
    if raw.get("kind") == "gating":
        check_gating_file(r, raw, path)
        return r
    check_romanised(r, raw, path)
    check_ipa(r, raw)
    check_phonetic(r, raw)
    if raw.get("kind") == "sounds":
        check_sounds_file(r, raw, path)
        return r
    if raw.get("kind") == "script":
        check_script_file(r, raw, path)
        return r

    for unknown in sorted(set(raw) - HEADER_KEYS, key=str):
        # Keys meaningful in a core or a layer get their own message.
        if unknown == "part":
            continue
        if unknown == "core":
            r.error("core", 'only a layer names a core (kind: "layer")')
        elif unknown in ("table", "rules"):
            r.error(unknown, f"only a rules core has {unknown}; a rules deck is "
                             f"written as a core and layers")
        else:
            r.error("root", f"unknown field {unknown!r}")

    # `True == 1` in Python, so without the bool check a bare `schema: yes`
    # would pass here and then fail in the app.
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {raw.get('schema')!r}")

    deck_id = raw.get("id")
    if not _is_str(deck_id) or not ID_RE.fullmatch(deck_id):
        r.error("id", f"must match [a-z0-9-]+, got {deck_id!r}")
    elif deck_id != path.stem:
        r.error("id", f"is {deck_id!r} but the filename stem is {path.stem!r}")
    elif deck_id.endswith("-script"):
        r.error("id", f"{deck_id!r} ends in -script, which only a script guide's id does; "
                      f"give the deck another name")

    if not _is_str(raw.get("name")):
        r.error("name", "is required")
    if not _is_str(raw.get("license")):
        r.error("license", "is required (an SPDX identifier, such as CC-BY-SA-4.0)")

    kind = raw.get("kind", "vocab")
    if kind == "rules":
        r.error("kind", 'a rules deck is written as a core and layers; see "Rules '
                        'decks" in docs/DECK-FORMAT.md')
    elif kind not in KINDS:
        r.error("kind", f"must be one of {sorted(KINDS)}, got {kind!r}")
    r.deck_kind = kind if isinstance(kind, str) else None

    theme = raw.get("theme")
    if theme is not None:
        if kind != "vocab":
            r.error("theme", "only a vocab deck teaches a theme")
        elif not _is_str(theme) or not ID_RE.fullmatch(theme):
            r.error("theme", f"must be a theme id from decks/themes.yaml, got {theme!r}")
        else:
            lang, native = raw.get("language"), raw.get("native")
            if isinstance(lang, dict) and isinstance(native, dict):
                r.theme_key = (str(lang.get("code")), str(native.get("code")), theme)
            if theme in NUMBER_THEMES and isinstance(lang, dict):
                # The cards it writes, below; the ones it lists by ref, across
                # files.
                r.number_taught = (str(lang.get("code")), set())

    check_langblock(r, "language", raw.get("language"), full=True)
    if kind not in ("facts", "situations"):
        check_langblock(r, "native", raw.get("native"), full=False)
        lang = raw.get("language")
        if isinstance(lang, dict) and _is_str(lang.get("code")):
            icon = lang.get("icon")
            r.icon = (lang["code"], icon if _is_str(icon) else None)
    elif "native" in raw:
        r.error("native", f"a {kind} file has no native: its text is keyed by "
                          f"the language it is written in")

    lang = raw.get("language")
    native = raw.get("native")
    if kind not in ("facts", "situations") and _is_str(deck_id) \
            and isinstance(lang, dict) \
            and isinstance(native, dict) \
            and _is_str(lang.get("code")) and _is_str(native.get("code")):
        # A deck is a course, "Hindi from English", and its id says so.
        prefix = f"{lang['code']}-{native['code']}-"
        if not deck_id.startswith(prefix):
            r.error("id", f"must start with {prefix!r}, the language learned and then "
                          f"the language it is taught from, got {deck_id!r}")
        r.course_deck = (lang["code"], native["code"], deck_id)
        r.lang_code, r.native_code = lang["code"], native["code"]
        # The language's path lists the deck by its core id (ADR-0036).
        if deck_id.startswith(prefix):
            r.listed_as = f"{lang['code']}-{deck_id[len(prefix):]}"
        if _is_str(native.get("name")):
            r.native_name = native["name"]
    script = _script_of(lang)
    r.script = script

    _check_common_header(r, raw)

    if kind != "situations" and "situations" in raw:
        r.error("situations", "only valid on a situations file; add kind: situations")
    if kind != "reading" and "passages" in raw:
        r.error("passages", "only valid on a reading deck; add kind: reading")
    if kind == "vocab":
        if "pattern" in raw:
            r.error("pattern", "only valid on a grammar deck")
        if "facts" in raw:
            r.error("facts", "only valid on a facts file")
        cards = raw.get("cards")
        if not isinstance(cards, list) or not cards:
            r.error("cards", "must be a non-empty list")
        else:
            seen: set[str] = set()
            code = lang.get("code") if isinstance(lang, dict) else None
            for i, card in enumerate(cards):
                check_card(r, i, card, seen, script, code if _is_str(code) else "xx",
                           scripts=_scripts_of(lang))
            if r.number_taught is not None:
                r.number_taught[1].update(
                    w for d in r.card_defs.values() for t in d.words for w in t.split())
    elif kind == "facts":
        for key in ("cards", "pattern"):
            if key in raw:
                r.error(key, "a facts file uses facts, not cards or a pattern")
        code = lang.get("code") if isinstance(lang, dict) else None
        check_facts(r, raw.get("facts"), code if _is_str(code) else None)
    elif kind == "situations":
        for key in ("cards", "pattern", "facts"):
            if key in raw:
                r.error(key, "a situations file uses situations, not " + key)
        code = lang.get("code") if isinstance(lang, dict) else None
        if _is_str(code) and path.stem != f"{code}-situations":
            r.error("id", f"a situations file is {code}-situations.yaml, with that "
                          f"id, got {path.stem!r}")
        check_situations(r, raw.get("situations"), code if _is_str(code) else None)
    elif kind == "reading":
        for key in ("cards", "pattern", "facts"):
            if key in raw:
                r.error(key, "a reading deck has passages, not " + key)
        code = lang.get("code") if isinstance(lang, dict) else None
        passages = check_passages(r, raw.get("passages"), script,
                                  code if _is_str(code) else "xx")
        if r.course_deck is not None:
            r.passages = (r.course_deck[0], r.course_deck[1], passages)
    elif kind != "rules":
        if "facts" in raw:
            r.error("facts", "only valid on a facts file")
        if "cards" in raw:
            r.error("cards", "a grammar deck uses pattern, not cards")
        if "pattern" not in raw:
            r.error("pattern", "is required on a grammar deck")
        else:
            check_pattern(r, raw["pattern"])

    if kind in ("vocab", "grammar") and r.course_deck is not None:
        r.taught_words = (r.course_deck[0], r.course_deck[1], _taught(raw))
    _check_review_tags(r, raw)
    check_kind_header(r, raw, kind if isinstance(kind, str) else None)
    if r.native_code is not None:
        for d in r.card_defs.values():
            d.natives = {r.native_code}
    return r


# --- Proposals (ADR-0038) ----------------------------------------------------
# A change a reviewer proposed to one field of a card, kept on the card in
# the file that holds the field until enough other reviewers accept it.

PROPOSAL_KEYS = {"id", "field", "now", "text", "by", "date", "why", "with", "accepted"}
PROPOSAL_REQUIRED = ("id", "field", "now", "text", "by", "date")
PROPOSAL_ID_RE = re.compile(r"[0-9a-f]{10}")
DATE_RE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}")
# The fields a proposal may change, by where the card's entry is: a card a
# single-file deck writes, a ref there, a core's card or ref, a layer's
# entry for its core's card, or a card only the layer has.
#
# `bases` is one base word (#476): added, changed or removed, its `now`
# and `text` each one line of JSON, `{"word", "base", "reading",
# "meaning"}` or `{"word", "ref"}`, "" for none. It goes on the entry that
# holds the base's meaning, a layer's for a core's card, and the review bot
# writes the core's line with it. `alt_target` is the accepted
# alternatives, its `now` and `text` JSON lists. `place` is where a card
# belongs (#477): its `now` and `text` are core deck ids, and only a core's
# card has it. `gender`, `register`, `hears` and `warning` (#508) are the
# card's own scalars, so a card written in full has them and a ref or a
# layer's entry does not; `warning` is a core card's only.
#
# `alt_native_add` and `not_synonyms_add` (ADR-0050, #924) add one item to a
# list on the card's native side, so only the entries that give `alt_native`
# have them. Their `now` is always "" (nothing is replaced) and their `text`
# is the one item.
PROPOSAL_ADD_FIELDS = ("alt_native_add", "not_synonyms_add")
PROPOSAL_FIELDS = {
    "single": ("target", "reading", "ipa", "native", "notes", "bases", "alt_target",
               "gender", "register", "hears", *PROPOSAL_ADD_FIELDS),
    "ref": ("native", "reading", "ipa", "notes", *PROPOSAL_ADD_FIELDS),
    "core": ("target", "reading", "ipa", "notes", "alt_target", "place",
             "gender", "register", "hears", "warning"),
    "core-ref": ("reading", "ipa", "notes"),
    "layer": ("native", "bases", *PROPOSAL_ADD_FIELDS),
    "layer-own": ("target", "reading", "ipa", "native", "notes", "bases", "alt_target",
                  *PROPOSAL_ADD_FIELDS),
}
# The fields whose `now` and `text` are JSON, not the field's own text.
PROPOSAL_JSON_FIELDS = ("bases", "alt_target")
# The values a proposal on a fixed-value field may have, wherever the card is.
# `gender` (the language's path lists the classes) and `warning` (the card's
# own notes name the choices) depend on more than the proposal, and are
# checked by the review bot against them (tools/proposals.py).
PROPOSAL_VALUES = {"register": REGISTERS, "hears": ("form",)}


def _proposal_json_ok(name: str, value: str) -> bool:
    """Whether [value] is a `now` or `text` a proposal on [name], one of
    PROPOSAL_JSON_FIELDS, may have."""
    if name == "bases" and value == "":
        return True
    try:
        parsed = json.loads(value)
    except ValueError:
        return False
    if name == "alt_target":
        return isinstance(parsed, list) and all(_is_str(a) for a in parsed)
    return isinstance(parsed, dict) and _is_str(parsed.get("word")) \
        and (_is_str(parsed.get("ref")) or _is_str(parsed.get("base"))) \
        and all(isinstance(v, str) for v in parsed.values())


def _check_add_proposal(r: Report, where: str, name: str, now: object,
                        text: str) -> None:
    """A proposal to add one item to a card's `alt_native` or `not_synonyms`
    (ADR-0050): no `now`, and a `text` that is one item as the list would
    hold it. The card's own answers are checked when it is applied."""
    if now != "":
        r.error(where, f"now of a proposal on {name} must be \"\": it adds an "
                       f"item and replaces nothing, got {now!r}")
    if name == "alt_native_add":
        if ";" in text:
            r.error(where, f"text of a proposal on {name} is one answer: no \";\" "
                           f"(one proposal for each), got {text!r}")
        return
    if r.native_code not in (None, "en"):
        r.error(where, "not_synonyms_add is for English meanings: the synonym "
                       "sets are English")
    from validate_synonyms import meaning_key
    key = meaning_key(text)
    if not key or key != text:
        r.error(where, f"text of a proposal on {name} must be in comparison form "
                       f"(lower case, no leading to, no punctuation), got {text!r}")


def proposal_id(card: str, field_name: str, now: str, text: str, by: str) -> str:
    """A proposal's id: the first ten hex digits of the SHA-256 of its
    facts, so that the same proposal always has the same id."""
    joined = "\x1f".join((card, field_name, now, text, by))
    return hashlib.sha256(joined.encode("utf-8")).hexdigest()[:10]


@dataclass
class Proposed:
    """A card entry's `proposed` list, taken out of the file: where it was,
    the card's id, what kind of entry it is (a key of PROPOSAL_FIELDS) and
    the entry as it is left."""
    where: str
    card: object
    form: str
    entry: dict
    items: object


def strip_proposals(raw: object) -> list[Proposed]:
    """Takes every card's `proposed` out of [raw], a deck file as loaded,
    and returns them. Only a card entry's is taken: one anywhere else stays,
    and is an unknown field."""
    if not isinstance(raw, dict):
        return []
    cards = raw.get("cards")
    core = raw.get("part") == "core"
    found = []
    if isinstance(cards, list) and raw.get("kind") != "layer":
        for i, entry in enumerate(cards):
            if not isinstance(entry, dict) or "proposed" not in entry:
                continue
            ref = "ref" in entry
            form = ("core-ref" if ref else "core") if core else ("ref" if ref else "single")
            found.append(Proposed(f"cards[{i}]", entry.get("ref" if ref else "id"),
                                  form, entry, entry.pop("proposed")))
    elif isinstance(cards, dict) and raw.get("kind") == "layer":
        for key, entry in cards.items():
            if not isinstance(entry, dict) or "proposed" not in entry:
                continue
            form = "layer-own" if "target" in entry else "layer"
            found.append(Proposed(f"cards.{key}", key, form, entry,
                                  entry.pop("proposed")))
    return found


def check_proposals(r: Report, found: list[Proposed]) -> None:
    """Each proposal's shape: its facts, an id that is theirs, a field its
    entry may give, a good rater code and date, and acceptances by other
    codes. What it proposes is not checked: it is not deck content until it
    is applied, and then the field is checked as any field is."""
    ids: dict[str, str] = {}
    for p in found:
        if not isinstance(p.items, list) or not p.items:
            r.error(p.where, "proposed must be a non-empty list, one item per "
                             "proposal")
            continue
        for i, item in enumerate(p.items):
            where = f"{p.where}.proposed[{i}]"
            if not isinstance(item, dict):
                r.error(where, "must be a mapping")
                continue
            for unknown in sorted(set(item) - PROPOSAL_KEYS, key=str):
                r.error(where, f"unknown field {unknown!r}")
            missing = [k for k in PROPOSAL_REQUIRED if k not in item]
            if missing:
                r.error(where, f"missing {', '.join(missing)}")
                continue
            pid, name, now, text, by, date = (item[k] for k in PROPOSAL_REQUIRED)
            allowed = PROPOSAL_FIELDS[p.form]
            if name not in allowed:
                r.error(where, f"field must be one of {', '.join(allowed)} here, "
                               f"got {name!r}")
            elif name == "notes" and not isinstance(p.entry.get("notes"), (str, type(None))):
                r.error(where, "a proposal changes notes only where they are "
                               "plain text, not a list of notes")
            if not isinstance(now, str):
                r.error(where, f"now must be text, the field as the proposer saw "
                               f"it (\"\" when it had none), got {now!r}")
            if name in PROPOSAL_JSON_FIELDS:
                for key, value in (("now", now), ("text", text)):
                    if isinstance(value, str) and not _proposal_json_ok(name, value) \
                            and not (key == "now" and value == "" and name == "alt_target"):
                        r.error(where, f"{key} of a proposal on {name} must be one line "
                                       f"of JSON as the review bot writes it, got {value!r}")
                if not isinstance(text, str) or (name != "bases" and not text):
                    r.error(where, f"text must be text, got {text!r}")
                elif text == now:
                    r.error(where, "text is what the field said already")
            elif not _is_str(text):
                r.error(where, f"text must be non-empty text, got {text!r}")
            elif name in PROPOSAL_ADD_FIELDS:
                _check_add_proposal(r, where, name, now, text)
            elif isinstance(now, str) and text == now:
                r.error(where, "text is what the field said already")
            elif name in PROPOSAL_VALUES and text not in PROPOSAL_VALUES[name]:
                r.error(where, f"text of a proposal on {name} must be one of "
                               f"{', '.join(PROPOSAL_VALUES[name])}, got {text!r}")
            tied = item.get("with")
            if tied is not None and (not isinstance(tied, str)
                                     or not PROPOSAL_ID_RE.fullmatch(tied)):
                r.error(where, f"with must be the id of the change to the card's word "
                               f"it came with, ten hex digits, got {tied!r}")
            code = rater_code(by)
            if code is None or code != by:
                r.error(where, f"by must be a rater code, FL-XXXX-XXXX-C, got {by!r}")
            if not isinstance(date, str) or not DATE_RE.fullmatch(date) \
                    or not _is_date(date):
                r.error(where, f"date must be YYYY-MM-DD, quoted, got {date!r}")
            if "why" in item and not isinstance(item["why"], str):
                r.error(where, f"why must be text, got {item['why']!r}")
            accepted = item.get("accepted", [])
            if not isinstance(accepted, list) or any(
                    rater_code(a) is None or rater_code(a) != a for a in accepted):
                r.error(where, "accepted must be a list of rater codes")
            elif len(set(accepted)) != len(accepted):
                r.error(where, "accepted names a rater code twice")
            elif by in accepted:
                r.error(where, "accepted names the proposer; an agreement is "
                               "another reviewer's")
            if not isinstance(pid, str) or not PROPOSAL_ID_RE.fullmatch(pid):
                r.error(where, f"id must be ten hex digits, got {pid!r}")
                continue
            if pid in ids:
                r.error(where, f"id {pid} is also {ids[pid]}")
            ids[pid] = where
            if all(isinstance(v, str) for v in (p.card, name, now, text, by)) \
                    and pid != proposal_id(p.card, name, now, text, by):
                r.error(where, "id is not its facts' (card, field, now, text "
                               "and by); a proposal is never edited, only "
                               "removed")
            elif name in PROPOSAL_ADD_FIELDS and name in allowed and _is_str(text) \
                    and isinstance(p.entry.get(name.removesuffix("_add")), list) \
                    and text in p.entry[name.removesuffix("_add")]:
                r.info(where, f"proposal {pid} is outdated: the card's "
                              f"{name.removesuffix('_add')} has the item already")
            elif isinstance(now, str) and isinstance(name, str) \
                    and name in allowed and name not in PROPOSAL_JSON_FIELDS \
                    and name not in PROPOSAL_ADD_FIELDS \
                    and p.entry.get(name, "") != now:
                r.info(where, f"proposal {pid} is outdated: the {name} no longer "
                              f"says what it was proposed against")


# --- Who checked a card (#449, ADR-0038 amended) ----------------------------
# The rater codes of the reviewers who signed a card off, written on the
# card's entry by the review bot as one line: `checked_by: ["FL-…"]`.

@dataclass
class Checked:
    """A card entry's `checked_by` or `verified`, taken out of the file:
    where it was, the card's id, the value as written (the codes, or the
    settled points) and which key it was."""
    where: str
    card: object
    codes: object
    key: str = "checked_by"


def _card_entries(raw: object) -> list[tuple[str, object, dict]]:
    """Each card entry of [raw], a deck file as loaded, with where it is
    and its card's id: a list's cards and refs, or a layer's entries."""
    if not isinstance(raw, dict):
        return []
    cards = raw.get("cards")
    out: list[tuple[str, object, dict]] = []
    if isinstance(cards, list) and raw.get("kind") != "layer":
        for i, entry in enumerate(cards):
            if isinstance(entry, dict):
                out.append((f"cards[{i}]",
                            entry.get("ref" if "ref" in entry else "id"), entry))
    elif isinstance(cards, dict) and raw.get("kind") == "layer":
        for key, entry in cards.items():
            if isinstance(entry, dict):
                out.append((f"cards.{key}", key, entry))
    return out


def strip_checks(raw: object) -> list[Checked]:
    """Takes every card entry's `checked_by` and `verified` out of [raw], a
    deck file as loaded, and returns them, as strip_proposals does
    proposals: they are records of review, allowed on any card entry (a
    single file's, a core's, a layer's), and checked on their own."""
    return [Checked(where, card, entry.pop(key), key)
            for where, card, entry in _card_entries(raw)
            for key in ("checked_by", "verified") if key in entry]


# A settled data point of `verified` (#519), as the daily questions name it:
# the meaning, one example by the 8 hex digits of its text's hash, one
# confusable by its id, or the recording.
VERIFIED_POINT = re.compile(
    r"^(?:meaning|sound|example:[0-9a-f]{8}|confusable:[A-Za-z0-9_.-]{1,64})$")


def check_checks(r: Report, found: list[Checked]) -> None:
    """Each `checked_by`: a non-empty list of rater codes, each written as
    the app writes it, none twice; each `verified` (#519): a non-empty list
    of settled data points, none twice."""
    for c in found:
        where = f"{c.where}.{c.key}"
        if c.key == "verified":
            if not isinstance(c.codes, list) or not c.codes:
                r.error(where, "must be a non-empty list of settled data "
                               'points, ["meaning", "example:1a2b3c4d", '
                               '"confusable:<id>", "sound"]')
            elif any(not isinstance(p, str) or not VERIFIED_POINT.fullmatch(p)
                     for p in c.codes):
                r.error(where, "must list data points as the daily questions "
                               "name them: meaning, sound, example:<8 hex "
                               "digits> or confusable:<id>")
            elif len(set(c.codes)) != len(c.codes):
                r.error(where, "names a data point twice")
            continue
        if not isinstance(c.codes, list) or not c.codes:
            r.error(where, "must be a non-empty list of rater codes, "
                           '["FL-XXXX-XXXX-C"]')
            continue
        bad = [code for code in c.codes
               if rater_code(code) is None or rater_code(code) != code]
        if bad:
            r.error(where, f"must list rater codes, FL-XXXX-XXXX-C, got "
                           f"{', '.join(repr(b) for b in bad)}")
        elif len(set(c.codes)) != len(c.codes):
            r.error(where, "names a rater code twice")


def check_checks_hashable(r: Report, path: Path) -> None:
    """Each `checked_by` in [path] is written where tools/deck_index.py
    can take it out of `content_sha256`: a line of its own on a block card,
    or last before the closing brace of a card written on one line in flow
    style, as the bot writes it. Anywhere else, a sign-off would offer
    every learner an update (#449)."""
    import deck_index
    try:
        rest = _load_deck(deck_index.content_bytes(path.read_bytes())
                          .decode("utf-8"))
    except (OSError, UnicodeDecodeError, yaml.YAMLError):
        r.error("checked_by", "must be written as the bot writes it, a line "
                              "of its own or last in a card written on one "
                              "line, ending `checked_by: [...] }`; written "
                              "across lines in a flow card it cannot be left "
                              "out of content_sha256")
        return
    for c in strip_checks(rest):
        r.error(f"{c.where}.{c.key}",
                "must be a line of its own, or last in a card written on one "
                f"line, ending `{c.key}: [...] }}`; anywhere else it cannot "
                "be left out of content_sha256, and a sign-off would offer "
                "learners an update")


def _is_date(text: str) -> bool:
    try:
        datetime.date.fromisoformat(text)
    except ValueError:
        return False
    return True


def proposal_count(path: Path) -> int:
    """How many proposals [path] holds, for the index."""
    try:
        raw = _load_deck(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, yaml.YAMLError):
        return 0
    return sum(len(p.items) for p in strip_proposals(raw)
               if isinstance(p.items, list))


def _scripts_of(lang: object) -> list[str]:
    """The scripts a language block lists, its `script` first (#623)."""
    if isinstance(lang, dict):
        scripts = lang.get("scripts")
        if isinstance(scripts, list) and all(_is_str(x) for x in scripts):
            return list(scripts)
        if _is_str(lang.get("script")):
            return [lang["script"]]
    return []


def _script_of(lang: object) -> str:
    script = lang.get("script") if isinstance(lang, dict) else "other"
    return script if script in SCRIPTS else "other"


def _check_common_header(r: Report, raw: dict) -> None:
    """`tags`, `description`, `source` and `authors`, as every deck has them."""
    if "tags" in raw:
        _check_str_list(r, "root", "tags", raw["tags"])
    for key in ("description", "source"):
        _check_optional_text(r, "root", raw, key)

    authors = raw.get("authors")
    if authors is not None:
        if not isinstance(authors, list):
            r.error("authors", "must be a list")
        else:
            for i, a in enumerate(authors):
                if not isinstance(a, dict) or not _is_str(a.get("name")):
                    r.error(f"authors[{i}]", "must be a mapping with a name")
                elif set(a) - {"name", "url"}:
                    r.error(f"authors[{i}]", "unknown fields")
                else:
                    _check_optional_text(r, f"authors[{i}]", a, "url")


def _check_review_tags(r: Report, raw: dict) -> None:
    """A file that holds a culture note's claim is tagged "unreviewed" until
    a speaker checks it, then "reviewed": exactly one of them (ADR-0036).
    The tag "rated" marks a deck of offensive words whose words native
    speakers have rated: only such a deck can carry it (#630)."""
    if isinstance(raw.get("tags"), list) and "rated" in raw["tags"] \
            and "offensive" not in raw["tags"]:
        r.error("tags", '"rated" marks a deck of offensive words, which is '
                        'tagged "offensive"; this deck is not')
    if not r.culture:
        return
    tags = raw.get("tags") if isinstance(raw.get("tags"), list) else []
    if "reviewed" in tags and "unreviewed" in tags:
        r.error("tags", '"reviewed" and "unreviewed" together; a deck is one or '
                        'the other')
    elif "reviewed" not in tags and "unreviewed" not in tags:
        r.error("tags", 'has culture notes, so it is tagged "unreviewed" until a '
                        'speaker checks them, then "reviewed" (#99)')


# --- Cores and layers (ADR-0036) ---------------------------------------------

def _load_raw(path: Path) -> object:
    """[path] as the checks read it: its proposals, `checked_by` and `verified` taken
    out (ADR-0038)."""
    try:
        raw = _load_deck(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, yaml.YAMLError):
        return None
    strip_proposals(raw)
    strip_checks(raw)
    return raw


_VIEW_CACHE: "collections.OrderedDict[bytes, tuple[int, object]]" = collections.OrderedDict()
_VIEW_CACHE_BYTES = [0]
_VIEW_CACHE_LIMIT = 6_000_000  # characters of text


def _load_raw_view(path: Path) -> object:
    """[_load_raw]'s result, shared: the same tree for every caller, so a
    caller must only read it. For the checks that look at other files of a
    language, which would otherwise copy a core's whole tree to read one
    field of it, once per file asked about."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    key = _digest(text)
    hit = _VIEW_CACHE.get(key)
    if hit is not None:
        _VIEW_CACHE.move_to_end(key)
        return hit[1]
    try:
        raw = _load_deck(text)
    except yaml.YAMLError:
        return None
    strip_proposals(raw)
    strip_checks(raw)
    size = len(text)
    if size <= _VIEW_CACHE_LIMIT // 2:
        _VIEW_CACHE[key] = (size, raw)
        _VIEW_CACHE_BYTES[0] += size
        while _VIEW_CACHE_BYTES[0] > _VIEW_CACHE_LIMIT:
            _, (old, _) = _VIEW_CACHE.popitem(last=False)
            _VIEW_CACHE_BYTES[0] -= old
    return raw


def _yaml_files(directory: Path) -> list[Path]:
    """The files of a language: directly in its directory, and one level
    below, where its layers are."""
    if not directory.is_dir():
        return []
    return sorted(directory.glob("*.yaml")) + sorted(directory.glob("*/*.yaml"))


def _unique_dirs(*dirs: Path) -> list[Path]:
    seen: dict[Path, None] = {}
    for d in dirs:
        seen.setdefault(d.resolve(), None)
    return list(seen)


def _check_string_keys(r: Report, node: object, where: str) -> None:
    """Every mapping key in a layer, and in a rules core's table and rules,
    is a string: `1:` is the integer 1 to both readers."""
    if isinstance(node, dict):
        for k, v in node.items():
            if not isinstance(k, str):
                r.error(where, f"key {k!r} was read as {type(k).__name__}; quote it")
                continue
            _check_string_keys(r, v, k if where == "root" else f"{where}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            _check_string_keys(r, v, f"{where}[{i}]")


def _reads_as_course(dirs: list[Path], lang: str, seg: str) -> bool:
    """Whether [seg] is the native code of a deck or layer of [lang], or the
    name of a folder beside its decks."""
    for d in dirs:
        if (d / seg).is_dir():
            return True
        for p in sorted(d.glob(f"{lang}-{seg}-*.yaml")) + sorted(d.glob(f"*/{lang}-{seg}-*.yaml")):
            raw = _load_raw_view(p)
            native = raw.get("native") if isinstance(raw, dict) else None
            if isinstance(native, dict) and native.get("code") == seg:
                return True
    return False


def _check_core_id(r: Report, raw: dict, path: Path, lang: str) -> None:
    cid = raw.get("id")
    name = cid[len(lang) + 1:] if _is_str(cid) and cid.startswith(f"{lang}-") else ""
    if not ID_RE.fullmatch(name) or cid != path.stem:
        r.error("id", f"must be {lang}- and a name, the filename stem, got {cid!r}")
        return
    if name in RESERVED_CORES:
        r.error("id", f"{cid!r} is the name of the language's {RESERVED_CORES[name]}; "
                      f"give the core another name")
        return
    if name.endswith("-script"):
        r.error("id", f"{cid!r} ends in -script, which only a script guide's id does; "
                      f"give the core another name")
        return
    dirs = (_unique_dirs(path.parent) if PRIVATE_MODE
            else _unique_dirs(path.parent, ROOT / "decks" / lang))
    seg = name.split("-")[0]
    if _reads_as_course(dirs, lang, seg):
        r.error("id", f"{cid!r} reads as a deck of the {lang}-{seg} course; a core's "
                      f"name does not start with a native language's code")
    for d in dirs:
        for p in _yaml_files(d):
            if p.stem == path.stem and p.resolve() != path.resolve():
                r.error("id", f"{cid!r} is also the id of {p}; a core's id is its own")
                return


def _lang_code(block: object) -> str | None:
    code = block.get("code") if isinstance(block, dict) else None
    return code if _is_str(code) and LANG_RE.fullmatch(code) else None


def validate_core(r: Report, raw: dict, path: Path) -> None:
    """decks/<lang>/<lang>-<name>.yaml, `part: "core"`: what a deck is in
    the language learnt, the same for every learner. Each layer gives what
    it is in one native language."""
    r.part = "core"
    lang = raw.get("language")
    code = _lang_code(lang)
    shown = code or "<lang>"
    # The block's own script, known to the validator or not (perso_arabic).
    own = _SCRIPT_BLOCK.get(lang.get("script")) if isinstance(lang, dict) else None
    check_transliterated(r, raw, fixed=code or "", own=own,
                         word_keys=_WORD_KEYS | {"slots"})
    check_romanised(r, raw, path)
    check_ipa(r, raw)

    for unknown in sorted(set(raw) - CORE_HEADER_KEYS, key=str):
        if unknown == "native":
            r.error("native", f"a core file has no native: the language it is taught "
                              f"from is in each layer, in decks/{shown}/<native>/")
        elif unknown in ("name", "description"):
            r.error(unknown, f"a core file's {unknown} is in each layer, in the "
                             f"learner's language")
        elif unknown == "situations":
            r.error("situations", "only valid on a situations file; add kind: situations")
        else:
            r.error("root", f"unknown field {unknown!r}")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    check_langblock(r, "language", lang, full=True)
    if isinstance(lang, dict) and _is_str(lang.get("code")):
        icon = lang.get("icon")
        r.icon = (lang["code"], icon if _is_str(icon) else None)

    kind = raw.get("kind", "vocab")
    if kind not in CORE_KINDS:
        msg = f"a core is vocab, grammar or rules, got {kind!r}"
        if kind == "reading":
            msg += "; a reading deck stays a single-file deck"
        r.error("kind", msg)
        kind = None
    if code is not None:
        _check_core_id(r, raw, path, code)
        if path.parent.name != code:
            r.error("root", f"a core file lives in decks/{code}/, the folder of its "
                            f"language; this one is in {path.parent.name!r}")
    if not _is_str(raw.get("license")):
        r.error("license", "is required (an SPDX identifier, such as CC-BY-SA-4.0)")
    _check_common_header(r, {k: v for k, v in raw.items() if k != "description"})

    script = _script_of(lang)
    r.script, r.deck_kind, r.lang_code = script, kind, code
    r.core_id = raw.get("id") if _is_str(raw.get("id")) else None
    r.listed_as = r.core_id
    lc = code or "xx"

    theme = raw.get("theme")
    if theme is not None:
        if kind != "vocab":
            r.error("theme", "only a vocab deck teaches a theme")
        elif not _is_str(theme) or not ID_RE.fullmatch(theme):
            r.error("theme", f"must be a theme id from decks/themes.yaml, got {theme!r}")
        else:
            r.core_theme = theme
    owners = {"cards": ("vocab", "only a vocab core has cards"),
              "pattern": ("grammar", "only a grammar core has a pattern"),
              "table": ("rules", "only a rules core has table"),
              "rules": ("rules", "only a rules core has rules")}
    for key, (owner, msg) in owners.items():
        if key in raw and kind is not None and kind != owner:
            r.error(key, msg)

    if kind == "vocab":
        cards = raw.get("cards")
        if not isinstance(cards, list) or not cards:
            r.error("cards", "must be a non-empty list")
        else:
            seen: set[str] = set()
            for i, card in enumerate(cards):
                if _is_set(card):
                    check_set_card(r, i, card, seen, lc)
                else:
                    check_card(r, i, card, seen, script, lc, form="core",
                               scripts=_scripts_of(lang))
            r.core_cards = [(cid, c.written) for cid, c in _core_index(raw, lc).items()]
    elif kind == "grammar":
        if "pattern" not in raw:
            r.error("pattern", "is required on a grammar deck")
        else:
            check_pattern(r, raw["pattern"], core=True)
    elif kind == "rules":
        check_rules_core(r, raw, lc, script)
    _check_review_tags(r, raw)
    check_kind_header(r, raw, kind)


def _is_set(card: object) -> bool:
    """Whether [card], an item of a deck's cards, is a set card."""
    return isinstance(card, dict) and card.get("kind") == "set"


def _set_ids(core: dict) -> set[str]:
    """The ids of a core's set cards."""
    cards = core.get("cards")
    return {c["id"] for c in cards if _is_set(c) and _is_str(c.get("id"))} \
        if isinstance(cards, list) else set()


def check_set_card(r: Report, idx: int, card: dict, seen: set[str], lang: str) -> None:
    """A set card of a vocab core (DECK-FORMAT.md, Set cards): its id, a card
    id, permanent; its members, by ref, or a rule and one fixed value of its
    table. It has no question data: it is taught, never asked."""
    where = f"cards[{idx}]"
    cid = card.get("id")
    if not _is_str(cid) or not card_id_re(lang).fullmatch(cid):
        r.error(where, f"id must be {lang}- and at least four digits, such as "
                       f"{lang}-0001, got {cid!r}")
        cid = None
    else:
        where = f"card {cid}"
        if cid in seen:
            r.error(where, "duplicate card id")
        seen.add(cid)
        r.card_defs[cid] = CardDef(path=r.path, natives=set(), words=[], in_core=True,
                                   is_set=True)
    for unknown in sorted(set(card) - SET_KEYS, key=str):
        r.error(where, f"a set card has only id, kind, members and shown, its name "
                       f"and explanation in each layer; got {unknown!r}")
    members = card.get("members")
    shown = card.get("shown")
    if isinstance(members, list):
        refs = _set_refs(r, f"{where}.members", members, lang, cid, "member")
        if len(members) < MIN_SET_MEMBERS:
            r.error(f"{where}.members", f"a set has at least {MIN_SET_MEMBERS} members, "
                                        f"got {len(members)}")
        if "shown" in card:
            r.error(f"{where}.shown", "only a set of one slot across the words names "
                                      "the rows its card shows; a set by refs shows "
                                      "its members")
        if cid is not None:
            r.sets.append((cid, where, refs))
    elif isinstance(members, dict):
        rule = members.get("rule")
        axes = [k for k in members if k != "rule"]
        ok = True
        if not _is_str(rule) or not (rule_id_re(lang).fullmatch(rule)
                                     or (ID_RE.fullmatch(rule)
                                         and rule.startswith(f"{lang}-"))):
            r.error(f"{where}.members", f"rule must name a rule, such as "
                                        f"{lang}-rule-past, or a rules core, such as "
                                        f"{lang}-grammar-past, got {rule!r}")
            ok = False
        if len(axes) != 1 or not all(isinstance(k, str) and KEY_RE.fullmatch(k)
                                     for k in axes):
            r.error(f"{where}.members", "a rule's set fixes one value of its table "
                                        "beside rule, as { rule: ..., verb: \"...\" } "
                                        "or { rule: ..., person: \"...\" }, got "
                                        f"{sorted(map(str, axes))}")
            ok = False
        elif not _is_str(members[axes[0]]):
            r.error(f"{where}.members.{axes[0]}", "must be non-empty text")
            ok = False
        rows: list[str] = []
        if ok:
            # A part of speech fixes a row; any other key a slot, whose card
            # shows the rows the deck chose.
            if axes[0] in POS:
                if "shown" in card:
                    r.error(f"{where}.shown", "only a set of one slot across the words "
                                              "names the rows its card shows; this set "
                                              "shows every form of its row")
            elif not isinstance(shown, list):
                r.error(f"{where}.shown", f'is required: the rows its card shows, a few '
                                          f'of the table\'s, as [{{ ref: "{lang}-0001" }}, '
                                          f"...]; its Full list shows every row")
            else:
                rows = _set_refs(r, f"{where}.shown", shown, lang, None, "row")
                if len(shown) < MIN_SET_MEMBERS:
                    r.error(f"{where}.shown", f"a set shows at least {MIN_SET_MEMBERS} "
                                              f"rows, got {len(shown)}")
        if ok and cid is not None:
            r.sets.append((cid, where, (rule, axes[0], members[axes[0]], rows)))
    else:
        r.error(f"{where}.members", f'is required: a list of {{ ref: "{lang}-0001" }}, '
                                    f"or {{ rule, and one value of its table }}")


def _set_refs(r: Report, where: str, items: list, lang: str, cid: str | None,
              what: str) -> list[str]:
    """A set card's list of `{ ref }`, its members or the rows it shows: each
    a card id of the language, once, and not the set itself."""
    refs: list[str] = []
    for i, m in enumerate(items):
        mwhere = f"{where}[{i}]"
        if not isinstance(m, dict) or set(m) != SET_MEMBER_KEYS:
            r.error(mwhere, f'must be {{ ref: "{lang}-0001" }}, a card of the '
                            f"language, got {m!r}")
            continue
        ref = m["ref"]
        if not _is_str(ref) or not card_id_re(lang).fullmatch(ref):
            r.error(mwhere, f"ref must be a {lang} card id, got {ref!r}")
        elif ref == cid:
            r.error(mwhere, "a set is not a member of itself")
        elif ref in refs:
            r.error(mwhere, f"{ref} is a {what} already")
        else:
            refs.append(ref)
    return refs


def _check_layer_set(r: Report, where: str, entry: object) -> None:
    """A layer's entry for a set card of its core: its name, `native`, and
    its explanation, both text in this language."""
    if not isinstance(entry, dict):
        r.error(where, "must be a mapping")
        return
    for unknown in sorted(set(entry) - LAYER_SET_KEYS, key=str):
        r.error(where, f"a set card's entry gives native, its name, and explanation; "
                       f"got {unknown!r}")
    for key in ("native", "explanation"):
        value = entry.get(key)
        if isinstance(value, bool):
            r.error(where, f"{key} parsed as the boolean {value!r} -- YAML read a "
                           f"bare true or false as a bool. Quote the value.")
        elif not _is_str(value):
            r.error(where, f"{key} is required: without it the set is not taught "
                           f"from this language")


def check_rules_core(r: Report, raw: dict, lang: str, script: str) -> None:
    """A rules deck's core: one table, whose rows are words of one kind with
    every form listed, and whose columns belong to its rules (ADR-0036)."""
    slots: list[str] = []
    table = raw.get("table")
    if "table" not in raw:
        r.error("table", "is required on a rules deck")
    elif not isinstance(table, dict):
        r.error("table", "must be a mapping")
    else:
        _check_string_keys(r, table, "table")
        for unknown in sorted(set(table) - TABLE_KEYS, key=str):
            r.error("table", f"unknown field {unknown!r}")
        pos_list: list[str] = []
        tags_list: list[str] = []
        excepted: list[str] = []
        applies = table.get("applies_to")
        if not isinstance(applies, dict):
            r.error("table.applies_to", 'is required: which words are its rows, as '
                                        '{ pos: ["noun"] }')
        else:
            for unknown in sorted(set(applies) - APPLIES_KEYS, key=str):
                r.error("table.applies_to", f"unknown field {unknown!r}")
            pos = applies.get("pos")
            allowed = sorted(POS - {"phrase"})
            if (not isinstance(pos, list) or not pos
                    or not all(isinstance(p, str) and p in allowed for p in pos)):
                r.error("table.applies_to.pos", f"must be a non-empty list of parts of "
                                                f"speech from {allowed}, got {pos!r}")
            else:
                pos_list = pos
            if "tags" in applies:
                _check_str_list(r, "table.applies_to", "tags", applies["tags"])
                if isinstance(applies["tags"], list):
                    tags_list = [t for t in applies["tags"] if _is_str(t)]
            if "except" in applies:
                ex = applies["except"]
                if not isinstance(ex, list) or not all(
                        _is_str(c) and card_id_re(lang).fullmatch(c) for c in ex):
                    r.error("table.applies_to.except", f"must list {lang} card ids, "
                                                       f"got {ex!r}")
                else:
                    excepted = ex
        given_slots = table.get("slots")
        if not isinstance(given_slots, list) or not given_slots:
            r.error("table.slots", "must be a non-empty list of slot keys")
        else:
            for i, v in enumerate(given_slots):
                if not _is_key(v):
                    r.error("table.slots", f"slots[{i}] must start with a letter and "
                                           f"match [a-z0-9-]+, and not be a YAML 1.1 "
                                           f"boolean word, got {v!r}")
            slots = [v for v in given_slots if isinstance(v, str)]
            if len(set(slots)) != len(slots):
                r.error("table.slots", "slots contains duplicates")
        rows = table.get("rows")
        words: list[str] = []
        cells: dict[str, set[str]] = {}
        row_slots: dict[str, set[str]] = {}
        if not isinstance(rows, list) or not rows:
            r.error("table.rows", "must be a non-empty list of rows")
            rows = []
        parts: set[str] = set()
        for i, row in enumerate(rows):
            where = f"table.rows[{i}]"
            if not isinstance(row, dict):
                r.error(where, "must be a mapping")
                continue
            for unknown in sorted(set(row) - ROW_KEYS, key=str):
                r.error(where, f"unknown field {unknown!r}")
            word = row.get("word")
            if not _is_str(word) or not card_id_re(lang).fullmatch(word):
                r.error(where, f"word must be the id of a {lang} card, got {word!r}")
                continue
            where = f"table.rows[{word}]"
            if word in words:
                r.error(where, f"{word} has a row already")
            words.append(word)
            part = word.split("-", 1)[1]
            key = row.get("key")
            if key is not None:
                if not _is_str(key) or not ID_RE.fullmatch(key):
                    r.error(where, f"key must match [a-z0-9-]+, got {key!r}")
                else:
                    part = key
            if part in parts:
                r.error(where, f"{part!r} already names another row; give one of them "
                               f"a key")
            parts.add(part)
            forms = row.get("forms")
            if not slots or not _check_forms(r, where, forms, slots):
                continue
            cells[word] = {f for v in forms.values()
                           for f in (v if isinstance(v, list) else [v]) if _is_str(f)}
            row_slots[word] = {k for k, v in forms.items() if v is not None}
            if script not in NO_READING and "readings" not in row:
                r.error(where, f"readings is required: the script is {script!r}")
            check_pattern_readings(r, where, row, forms, slots)
            check_pattern_ipas(r, where, row, forms, slots)
            shown = {(v[0] if isinstance(v, list) and v else v)
                     for v in forms.values() if v is not None and not isinstance(v, dict)}
            if len(shown) == 1:
                r.warn(where, "has one form only, so its grammar questions cannot "
                              "offer a choice")
        r.table = TableInfo(pos_list, tags_list, excepted,
                            list(dict.fromkeys(words)), script, cells, slots,
                            row_slots=row_slots)

    rules = raw.get("rules")
    if not isinstance(rules, list) or not rules:
        r.error("rules", "is required on a rules deck: a non-empty list of rules")
        return
    _check_string_keys(r, rules, "rules")
    owner: dict[str, str] = {}
    ids: set[str] = set()
    for i, rule in enumerate(rules):
        where = f"rules[{i}]"
        if not isinstance(rule, dict):
            r.error(where, "must be a mapping")
            continue
        for unknown in sorted(set(rule) - RULE_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        rid = rule.get("id")
        if not _is_str(rid) or not rule_id_re(lang).fullmatch(rid):
            r.error(where, f"id must be {lang}-rule- and a name, such as "
                           f"{lang}-rule-past, got {rid!r}")
            name = where
        else:
            where = name = f"rule {rid}"
            if rid in ids:
                r.error(where, "duplicate rule id")
            else:
                ids.add(rid)
                r.rules_defined.append((rid, where))
        rule_slots = rule.get("slots")
        if r.table is not None and _is_str(rid) and isinstance(rule_slots, list):
            r.table.rule_slots[rid] = [s for s in rule_slots if isinstance(s, str)]
        if (not isinstance(rule_slots, list) or not rule_slots
                or not all(isinstance(s, str) for s in rule_slots)):
            r.error(where, "slots must be a non-empty list of the table's slots")
        else:
            for s in rule_slots:
                if slots and s not in slots:
                    r.error(where, f"{s!r} is not a slot of the table")
                elif s in owner:
                    r.error(where, f"{s!r} is also in rule {owner[s]}; a slot belongs "
                                   f"to one rule")
                else:
                    owner[s] = name.removeprefix("rule ")
        check_note_words(r, where, "words", rule.get("words"), script)
    for s in slots:
        if s not in owner:
            r.error("table.slots", f"{s!r} belongs to no rule")


@dataclass
class _CoreCard:
    """What a layer may name of a core's card or ref."""
    written: bool
    notes: dict[str, list[str]]      # note id -> the words it quotes
    examples: dict[str, list[str]]   # example target -> its inline bases' words
    bases: list[str]                 # its inline bases' words
    has_notes: bool
    has_examples: bool
    # Its card data's items by field, each id with the text a layer owes it
    # ("meaning", "why", "label"), or None when the layer may leave it out.
    items: dict[str, dict[str, str | None]] = field(default_factory=dict)
    # Its senses: each id with its examples, as in [examples].
    senses: dict[str, dict[str, list[str]]] = field(default_factory=dict)


def _owed(key: str, item: dict) -> str | None:
    """The text a layer owes a core card's item (DECK-FORMAT.md, Card data):
    a word's meaning, a confusable's why, the label of a form of kind
    other."""
    if key == "confusables":
        return "why"
    if key == "forms":
        return "label" if item.get("kind") == "other" else None
    return "meaning" if "ref" not in item else None


def _inline_words(bases: object) -> list[str]:
    if not isinstance(bases, list):
        return []
    return [b["word"] for b in bases if isinstance(b, dict) and _is_str(b.get("word"))
            and "base" in b and "ref" not in b]


def _core_index(core: dict, lang: str) -> dict[str, _CoreCard]:
    """A core's cards and refs, in order, by id."""
    found: dict[str, _CoreCard] = {}
    id_re = card_id_re(lang)
    cards = core.get("cards")
    for card in cards if isinstance(cards, list) else []:
        if not isinstance(card, dict) or _is_set(card):
            continue
        written = "ref" not in card
        cid = card.get("id") if written else card.get("ref")
        if not _is_str(cid) or not id_re.fullmatch(cid) or cid in found:
            continue
        notes: dict[str, list[str]] = {}
        for note in card.get("notes") if isinstance(card.get("notes"), list) else []:
            if isinstance(note, dict) and _is_str(note.get("id")):
                words = note.get("words")
                notes[note["id"]] = [str(w.get("word")) if isinstance(w, dict) else ""
                                     for w in words] if isinstance(words, list) else []
        examples: dict[str, list[str]] = {}
        for ex in card.get("examples") if isinstance(card.get("examples"), list) else []:
            if isinstance(ex, dict) and _is_str(ex.get("target")):
                examples.setdefault(ex["target"], _inline_words(ex.get("bases")))
        items = {key: {i["id"]: _owed(key, i) for i in card[key]
                       if isinstance(i, dict) and _is_str(i.get("id"))}
                 for key in ITEM_KEYS if written and isinstance(card.get(key), list)}
        senses = {
            sense["id"]: {ex["target"]: _inline_words(ex.get("bases"))
                          for ex in (sense.get("examples") or [])
                          if isinstance(ex, dict) and _is_str(ex.get("target"))}
            for sense in (card.get("senses") if written and isinstance(card.get("senses"),
                                                                      list) else [])
            if isinstance(sense, dict) and _is_str(sense.get("id"))
            and isinstance(sense.get("examples") or [], list)}
        found[cid] = _CoreCard(
            written, notes, examples,
            _inline_words(card.get("bases")) if written else [],
            bool(card.get("notes")), bool(card.get("examples")), items, senses)
    return found


def validate_layer(r: Report, raw: dict, path: Path) -> None:
    """decks/<lang>/<native>/<lang>-<native>-<name>.yaml, `kind: "layer"`:
    what a core's deck is in one native language. The core is read here, so
    a layer validated alone is checked against it."""
    r.part = "layer"
    if "part" in raw:
        r.error("part", 'a layer has no part; only a core is marked part: "core"')
    core_id = raw.get("core")
    if not _is_str(core_id) or not ID_RE.fullmatch(core_id):
        r.error("core", f"must be the id of a core file, such as 'te-home', got "
                        f"{core_id!r}")
        return
    folder = path.parent.parent
    file = folder / f"{core_id}.yaml"
    if not file.is_file():
        r.error("core", f"no core file {core_id}.yaml in {folder}; a layer's core is "
                        f"in the folder above it")
        return
    core = _load_raw_view(file)
    if not isinstance(core, dict) or core.get("part") != "core":
        r.error("core", f'{core_id}.yaml is not a core: it has no part: "core"')
        return
    if core.get("kind") in GUIDE_KINDS:
        validate_guide_layer(r, raw, path, core)
        return
    r.core_id = r.listed_as = core_id
    r.genre = core["genre"] if _is_str(core.get("genre")) and core["genre"] in GENRES \
        else None
    r.hidden = core.get("hidden") is True
    r.level = core.get("level") if core.get("level") in LEVELS else None
    r.weave = core["weave"] if isinstance(core.get("weave"), bool) else None
    for key in ("professional", "section"):
        if _is_str(core.get(key)) and ID_RE.fullmatch(core[key]):
            setattr(r, key, core[key])
    code = _lang_code(core.get("language"))
    lc = code or "xx"
    script = _script_of(core.get("language"))
    kind = core.get("kind", "vocab")
    kind = kind if kind in CORE_KINDS else None
    r.script, r.deck_kind = script, kind
    native = raw.get("native")
    ncode = _lang_code(native)
    nname = native.get("name") if isinstance(native, dict) and _is_str(native.get("name")) \
        else ncode
    r.native_name = nname

    # The script checks run with the core's language block.
    check_transliterated(r, raw, fixed=ncode or "")
    check_romanised(r, raw, path, lang=code or "", directory=folder)
    check_ipa(r, raw)
    _check_string_keys(r, raw, "root")

    for unknown in sorted(set(raw) - LAYER_HEADER_KEYS, key=str):
        if unknown == "part" or not isinstance(unknown, str):
            continue
        if unknown == "language":
            r.error("language", f"a layer takes its language from its core, {core_id}")
        elif unknown == "theme":
            r.error("theme", f"a layer takes its theme from its core, {core_id}")
        elif unknown in KIND_HEADER_KEYS:
            r.error(unknown, f"a layer takes {unknown} from its core, {core_id}")
        else:
            r.error("root", f"unknown field {unknown!r}")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    check_langblock(r, "native", native, full=False)
    lid = raw.get("id")
    if not _is_str(lid) or not ID_RE.fullmatch(lid):
        r.error("id", f"must match [a-z0-9-]+, got {lid!r}")
        lid = None
    elif lid != path.stem:
        r.error("id", f"is {lid!r} but the filename stem is {path.stem!r}")
    if code and ncode and core_id.startswith(f"{code}-"):
        expected = f"{code}-{ncode}-{core_id[len(code) + 1:]}"
        if lid != expected:
            r.error("id", f"a layer of {core_id} taught from {ncode} has id "
                          f"{expected!r}, got {raw.get('id')!r}")
    if ncode and path.parent.name != ncode:
        r.error("root", f"a layer lives in decks/{lc}/{ncode}/, the folder of its "
                        f"native language; this one is in {path.parent.name!r}")
    if not _is_str(raw.get("name")):
        r.error("name", "is required")
    if not _is_str(raw.get("license")):
        r.error("license", "is required (an SPDX identifier, such as CC-BY-SA-4.0)")
    _check_common_header(r, raw)
    owners = {"cards": "vocab", "pattern": "grammar", "table": "rules", "rules": "rules"}
    for key, owner in owners.items():
        if key in raw and kind is not None and kind != owner:
            r.error(key, f"only a layer of a {owner} core has {key}")
    if code and ncode and lid:
        r.lang_code, r.native_code = code, ncode
        r.course_deck = (code, ncode, lid)

    texts: list[object] = []
    if kind == "vocab":
        _check_layer_cards(r, raw, core, file, core_id, lc, script, nname or "")
        for c in r.merged + r.cards:
            texts.extend([c.target, *c.alt_targets, *(t for _, t, _ in c.examples)])
        theme = core.get("theme")
        if code and ncode and _is_str(theme) and ID_RE.fullmatch(theme):
            r.theme_key = (code, ncode, theme)
            if theme in NUMBER_THEMES:
                r.number_taught = (code, {w for c in r.merged + r.cards
                                          for t in [c.target, *c.alt_targets]
                                          for w in t.split()})
    elif kind == "grammar":
        texts = _check_layer_pattern(r, raw.get("pattern"), core.get("pattern"))
    elif kind == "rules":
        texts = _check_layer_rules(r, raw, core, core_id)
    if r.course_deck is not None:
        r.taught_words = (code, ncode, {w for t in texts if isinstance(t, str)
                                        for w in _words(t)})
    _check_review_tags(r, raw)
    if ncode is not None:
        for d in r.card_defs.values():
            d.natives = {ncode}


def _check_layer_cards(r: Report, raw: dict, core: dict, core_path: Path,
                       core_id: str, lang: str, script: str, nname: str) -> None:
    """A layer's `cards`: for each core card it teaches, its native side; and
    the cards only this layer has, written in full."""
    cards = raw.get("cards")
    if not isinstance(cards, dict) or not cards:
        r.error("cards", "a layer's cards is a mapping of card id to what this "
                         "language gives it")
        cards = {}
    index = _core_index(core, lang)
    r.core_cards = [(cid, c.written) for cid, c in index.items()]
    sets = _set_ids(core)
    translated: set[str] = set()
    given: dict[str, tuple[set[str], set[str]]] = {}
    seen: set[str] = set(index)
    id_re = card_id_re(lang)
    for i, (cid, entry) in enumerate(cards.items()):
        if not isinstance(cid, str):
            continue
        where = f"cards.{cid}"
        if cid in sets:
            _check_layer_set(r, where, entry)
            continue
        known = index.get(cid)
        if known is None:
            if not id_re.fullmatch(cid):
                r.error(where, f"id must be {lang}- and at least four digits, such as "
                               f"{lang}-0001, got {cid!r}")
            elif not isinstance(entry, dict) or "target" not in entry:
                r.error(where, f"{cid} is not a card of {core_id}; a card only this "
                               f"layer has gives its target too")
            else:
                check_card(r, i, entry, seen, script, lang, form="layer", key=cid,
                           scripts=_scripts_of(core.get("language")))
            continue
        gives, notes, examples = _check_layer_entry(r, where, cid, entry, known, nname,
                                                    lang)
        if gives:
            translated.add(cid)
        given[cid] = (notes, examples)
    r.translated = translated
    r.core_refs = [(cid, cid in translated) for cid, c in index.items() if not c.written]

    # The core's written cards this layer includes, as the merged deck has
    # them: only the notes and examples it gives text to.
    scratch = Report(core_path)
    scratch.deck_kind = "vocab"
    core_cards = core.get("cards") if isinstance(core.get("cards"), list) else []
    for i, card in enumerate(core_cards):
        if not _is_set(card):
            check_card(scratch, i, card, set(), script, lang, form="core",
                       scripts=_scripts_of(core.get("language")))
    for c in scratch.cards:
        if c.id not in translated:
            continue
        notes, examples = given.get(c.id, (set(), set()))
        kept = [n for n in c.notes if n.nid in notes]
        for n in kept:
            if n.kind == "pair" and n.ref is not None:
                r.text_pairs.append((c.id, n.nid, n.ref))
        r.merged.append(TCard(
            id=c.id, target=c.target, alt_targets=c.alt_targets, pos=c.pos,
            tags=c.tags, phrasebook=c.phrasebook, path=c.path, where=c.where,
            deck_kind="vocab", bases=c.bases,
            examples=[e for e in c.examples if e[1] in examples], notes=kept,
            pair=next((n.ref for n in kept if n.kind == "pair"), None), single=False,
            words=c.words, example_words=c.example_words))


def _check_dictionary(r: Report, where: str, value: object) -> None:
    """A layer entry's `dictionary`: a short entry imported from Wiktionary,
    `{ senses, etymology?, source }`. `source` is the Wiktionary page, for the
    CC BY-SA credit."""
    if not isinstance(value, dict):
        r.error(where, "dictionary must be a mapping of senses, etymology and source")
        return
    for unknown in sorted(set(value) - DICTIONARY_KEYS, key=str):
        r.error(where, f"dictionary: unknown field {unknown!r}")
    senses = value.get("senses")
    if (not isinstance(senses, list) or not senses
            or not all(_is_str(x) for x in senses)):
        r.error(where, "dictionary.senses must be a non-empty list of text, the "
                       "word's other meanings")
    if "etymology" in value and not _is_str(value["etymology"]):
        r.error(where, "dictionary.etymology must be non-empty text, or left out")
    source = value.get("source")
    if not _is_str(source):
        r.error(where, "dictionary.source is required: the Wiktionary page the entry "
                       "was imported from, for the CC BY-SA credit")
    elif not WIKTIONARY_SOURCE_RE.fullmatch(source):
        r.error(where, f"dictionary.source must be the Wiktionary page only, "
                       f"https://en.wiktionary.org/wiki/<word>, got {source!r}")


def _check_layer_entry(r: Report, where: str, cid: str, entry: object,
                       known: _CoreCard, nname: str, lang: str
                       ) -> tuple[bool, set[str], set[str]]:
    """A layer's entry for a card or ref of its core. Returns whether it
    gives a native, and the note ids and example targets it gives text to."""
    if not isinstance(entry, dict):
        r.error(where, "must be a mapping")
        return False, set(), set()
    for unknown in sorted(set(entry) - LAYER_ENTRY_KEYS, key=str):
        r.error(where, f"{unknown!r} belongs to the word, in the core; a layer gives "
                       f"native, alt_native, notes, examples, bases, wiktionary and "
                       f"dictionary")
    native = entry.get("native")
    if "native" in entry:
        if isinstance(native, bool):
            r.error(where, f"native parsed as the boolean {native!r} -- YAML read a "
                           f"bare true or false as a bool. Quote the value.")
        elif not _is_str(native):
            r.error(where, "native must be a non-empty string")
    elif known.written:
        r.error(where, f"native is required: without it the card is not taught from "
                       f"{nname}")
    gives = _is_str(native)
    if "alt_native" in entry:
        _check_str_list(r, where, "alt_native", entry["alt_native"])
    check_meaning_alternatives(r, where, cid, entry)
    check_not_synonyms(r, where, entry)
    if "wiktionary" in entry:
        _check_wiktionary(r, where, "", entry["wiktionary"])
    if "dictionary" in entry:
        _check_dictionary(r, where, entry["dictionary"])
    shown = gives or not known.written

    notes: set[str] = set()
    if "notes" in entry:
        nwhere = f"{where}.notes"
        if not known.written and not known.has_notes:
            r.error(nwhere, f"the core lists {cid} by ref without notes; give them in "
                            f"the core's ref")
        elif not isinstance(entry["notes"], dict):
            r.error(nwhere, "a mapping of the core note's id to its text")
        else:
            for nid, text in entry["notes"].items():
                if not isinstance(nid, str):
                    continue
                if nid not in known.notes:
                    r.error(f"{nwhere}.{nid}", f"the core card has no note {nid!r}")
                elif not _is_str(text):
                    r.error(f"{nwhere}.{nid}", "must be non-empty text")
                else:
                    check_placeholders(r, f"{nwhere}.{nid}", "", text,
                                       known.notes[nid], "note")
                    notes.add(nid)
                    r.note_texts.setdefault(cid, []).append(text)
    if shown:
        for nid in known.notes:
            if nid not in notes:
                r.warn(where, f"note {nid!r} has no text here, so learners from "
                              f"{nname} do not see it")

    examples: set[str] = set()
    if "examples" in entry and not known.written and not known.has_examples:
        r.error(f"{where}.examples", f"the core lists {cid} by ref without examples; "
                                     f"give them in the core's ref")
    elif "examples" in entry or shown:
        examples = _check_layer_examples(r, where, "examples", entry.get("examples"),
                                         known.examples, shown)

    bases = set()
    if "bases" in entry:
        bases = _check_layer_bases(r, f"{where}.bases", entry["bases"], known.bases)
    if shown:
        for word in known.bases:
            if word not in bases:
                r.warn(where, f"the inline base {word!r} has no meaning here; it is "
                              f"shown without one")
    for key in CARD_DATA:
        if key in entry and not known.written:
            r.error(f"{where}.{key}", f"the core lists {cid} by ref; its {key} are on "
                                      f"the card where it is written")
    if known.written:
        for key in ITEM_KEYS:
            if key in entry or key in known.items:
                _check_layer_items(r, where, key, entry.get(key),
                                   known.items.get(key, {}), shown)
        if "senses" in entry or known.senses:
            _check_layer_senses(r, where, entry.get("senses"), known.senses, shown, lang)
    return gives, notes, examples


def _check_layer_examples(r: Report, where: str, path: str, value: object,
                          known: dict[str, list[str]], shown: bool) -> set[str]:
    """A layer's translations of a core text's examples, by target: text, or
    `{ native, bases }`. Returns the targets translated."""
    examples: set[str] = set()
    named: set[str] = set()
    ewhere = f"{where}.{path}"
    if value is not None and not isinstance(value, dict):
        r.error(ewhere, "a mapping of an example's target, as the core writes it, "
                        "to its translation")
    for target, tr in value.items() if isinstance(value, dict) else []:
        if not isinstance(target, str):
            continue
        named.add(target)
        if target != unicodedata.normalize("NFC", target):
            r.error(ewhere, f"key {target!r} is not NFC-normalised")
        if target not in known:
            r.error(f"{ewhere}.{target}", "the core card has no example with this target")
            continue
        twhere = f"{ewhere}.{target}"
        bases: set[str] = set()
        if isinstance(tr, dict):
            for unknown in sorted(set(tr) - {"native", "bases"}, key=str):
                r.error(twhere, f"unknown field {unknown!r}")
            if not _is_str(tr.get("native")):
                r.error(twhere, "native is required: the example's translation")
                continue
            if "bases" in tr:
                bases = _check_layer_bases(r, f"{twhere}.bases", tr["bases"], known[target])
        elif not _is_str(tr):
            r.error(twhere, "must be the example's translation, or { native, bases }")
            continue
        examples.add(target)
        for word in known[target]:
            if word not in bases:
                r.warn(where, f"the inline base {word!r} has no meaning here; it is "
                              f"shown without one")
    if shown:
        for target in known:
            if target not in named:
                r.warn(where, f"example {target!r} has no translation here, so it is "
                              f"not shown")
    return examples


def _check_layer_items(r: Report, where: str, key: str, value: object,
                       items: dict[str, str | None], shown: bool) -> None:
    """A layer's text for a core card's items of [key], by id: a word's
    meaning (a collocation's may be `{ native, note }`), a confusable's
    `{ why }`, a form's line. A word with no meaning, a confusable with no
    why, is warned of; a form of kind other with no label is an error."""
    iwhere = f"{where}.{key}"
    given: set[str] = set()
    if value is not None and not isinstance(value, dict):
        r.error(iwhere, f"a mapping of the core item's id to its text")
    for iid, text in value.items() if isinstance(value, dict) else []:
        twhere = f"{iwhere}.{iid}"
        if iid not in items:
            r.error(twhere, f"the core card has no {key} item {iid!r}")
            continue
        if key == "confusables":
            if not isinstance(text, dict) or set(text) != {"why"} or not _is_str(text["why"]):
                r.error(twhere, "must be { why: ... }, why it is wrong")
                continue
        elif key == "collocations" and isinstance(text, dict):
            for unknown in sorted(set(text) - {"native", "note"}, key=str):
                r.error(twhere, f"unknown field {unknown!r}")
            if not _is_str(text.get("native")) or ("note" in text
                                                    and not _is_str(text["note"])):
                r.error(twhere, "must be its meaning, or { native, note }, each text")
                continue
        elif not _is_str(text):
            r.error(twhere, "must be non-empty text")
            continue
        given.add(iid)
    if not shown:
        return
    for iid, owed in items.items():
        if owed is None or iid in given:
            continue
        if owed == "label":
            r.error(iwhere, f"{iid!r} is a form of kind other: give its label here")
        else:
            r.warn(where, f"{key} {iid!r} has no {owed} here")


def _check_layer_senses(r: Report, where: str, value: object,
                        senses: dict[str, dict[str, list[str]]], shown: bool,
                        lang: str) -> None:
    """A layer's senses of a core card (#517), by id: `{ native, examples }`.
    A sense with no native here is warned of, and is an error once the
    language is filled in; two senses with one native are warned of."""
    swhere = f"{where}.senses"
    natives: dict[str, str] = {}
    if value is not None and not isinstance(value, dict):
        r.error(swhere, "a mapping of the core sense's id to { native, examples }")
    for sid, sense in value.items() if isinstance(value, dict) else []:
        twhere = f"{swhere}.{sid}"
        if sid not in senses:
            r.error(twhere, f"the core card has no sense {sid!r}")
            continue
        if not isinstance(sense, dict):
            r.error(twhere, "must be { native, examples }")
            continue
        for unknown in sorted(set(sense) - {"native", "examples"}, key=str):
            r.error(twhere, f"unknown field {unknown!r}")
        if not _is_str(sense.get("native")):
            r.error(twhere, "native is required: the sense's meaning")
            continue
        natives[sid] = sense["native"]
        _check_layer_examples(r, where, f"senses.{sid}.examples", sense.get("examples"),
                              senses[sid], shown)
    if not shown:
        return
    for sid in senses:
        if sid in natives or sid in (value if isinstance(value, dict) else {}):
            continue
        if lang in FILLED_LANGUAGES:
            r.error(swhere, f"sense {sid!r} has no native here; {lang} is filled in")
        else:
            r.warn(where, f"sense {sid!r} has no native here")
    seen: dict[str, str] = {}
    for sid, native in natives.items():
        if native in seen:
            r.warn(where, f"senses {seen[native]!r} and {sid!r} have the same native")
        seen.setdefault(native, sid)


def _check_layer_bases(r: Report, where: str, value: object,
                       inline: list[str]) -> set[str]:
    """A layer's meanings for a core text's inline bases, by word: a string,
    or `{ meaning, wiktionary }`. Returns the words given one."""
    if not isinstance(value, dict):
        r.error(where, "a mapping of an inline base's word to its meaning")
        return set()
    given: set[str] = set()
    for word, meaning in value.items():
        if not isinstance(word, str):
            continue
        if word != unicodedata.normalize("NFC", word):
            r.error(where, f"key {word!r} is not NFC-normalised")
        bwhere = f"{where}.{word}"
        if word not in inline:
            r.error(bwhere, f"the core card has no inline base for {word!r}; a base "
                            f"given by ref takes its meaning from that card")
            continue
        if isinstance(meaning, dict):
            for unknown in sorted(set(meaning) - {"meaning", "wiktionary"}, key=str):
                r.error(bwhere, f"unknown field {unknown!r}")
            if not _is_str(meaning.get("meaning")):
                r.error(bwhere, "meaning is required")
                continue
            if "wiktionary" in meaning:
                _check_wiktionary(r, bwhere, "", meaning["wiktionary"])
        elif not _is_str(meaning):
            r.error(bwhere, "must be the base's meaning, or { meaning, wiktionary }")
            continue
        given.add(word)
    return given


RETIRED_PROMPT = (
    "prompt is retired (ADR-0039): the app builds a cell's question itself, "
    "'{lemma} ({gloss}) — {slot}', and reads a prompt only for decks that still "
    "have one. Released apps that need it are still in use, so leave it as it is "
    "until they are not"
)


def _check_retired_prompt(r: Report, where: str, pattern: dict) -> None:
    """A pattern's `prompt` is optional and retired: flagged where given, and
    still checked, because the app reads it as written."""
    if "prompt" not in pattern:
        return
    prompt = pattern["prompt"]
    if not _is_str(prompt):
        r.error(where, "prompt must be non-empty text or omitted")
        return
    r.warn(where, RETIRED_PROMPT)
    _check_prompt(r, where, prompt)


def _check_prompt(r: Report, where: str, prompt: object) -> None:
    if _is_str(prompt):
        for token in re.findall(r"\{(\w+)\}", prompt):
            if token not in ("lemma", "gloss", "slot"):
                r.error(where, f"prompt uses unknown placeholder {{{token}}}")
        if "{slot}" not in prompt:
            r.warn(where, "prompt has no {slot}; every cell will look identical")


def _check_layer_pattern(r: Report, pattern: object, core_pattern: object) -> list[object]:
    """A grammar core's layer: the table's names, prompt and glosses. Returns
    the words the merged deck teaches."""
    if not isinstance(pattern, dict):
        r.error("pattern", "is required on a layer of a grammar core: its name, "
                           "slot_name and glosses")
        return []
    for unknown in sorted(set(pattern) - LAYER_PATTERN_KEYS, key=str):
        r.error("pattern", f"unknown field {unknown!r}")
    for key in ("name", "slot_name"):
        if not _is_str(pattern.get(key)):
            r.error("pattern", f"{key} is required")
    _check_optional_text(r, "pattern", pattern, "notes")
    _check_retired_prompt(r, "pattern", pattern)
    core_pattern = core_pattern if isinstance(core_pattern, dict) else {}
    core_slots = core_pattern.get("slots")
    core_slots = [s for s in core_slots if isinstance(s, str)] \
        if isinstance(core_slots, list) else []
    core_entries = core_pattern.get("entries")
    entries_of: dict[str, dict] = {}
    for e in core_entries if isinstance(core_entries, list) else []:
        if isinstance(e, dict):
            part = e.get("key") if _is_str(e.get("key")) else e.get("lemma")
            if _is_str(part):
                entries_of.setdefault(part, e)
    slots = pattern.get("slots")
    if slots is not None:
        if not isinstance(slots, dict):
            r.error("pattern.slots", "must map the core's slots to their labels")
        else:
            for slot, label in slots.items():
                if not isinstance(slot, str):
                    continue
                if slot not in core_slots:
                    r.error("pattern.slots", f"{slot!r} is not a slot of the core")
                elif not _is_str(label):
                    r.error(f"pattern.slots.{slot}", "must be the label shown for "
                                                     "{slot}, as text")
    texts: list[object] = []
    glosses = pattern.get("entries")
    if not isinstance(glosses, dict):
        r.error("pattern", "entries is required: a mapping of each core entry's key "
                           "to its gloss")
        return texts
    for part, gloss in glosses.items():
        if not isinstance(part, str):
            continue
        if part not in entries_of:
            r.error("pattern.entries", f"{part!r} is not an entry of the core")
        elif not _is_str(gloss):
            r.error(f"pattern.entries.{part}", "must be the entry's gloss, as text")
        else:
            entry = entries_of[part]
            forms = entry.get("forms")
            texts.append(entry.get("lemma"))
            for v in forms.values() if isinstance(forms, dict) else []:
                texts.extend(v if isinstance(v, list) else [v])
    for part in entries_of:
        if part not in glosses:
            r.error("pattern.entries", f"gives no gloss for {part!r}")
    return texts


def _check_layer_rules(r: Report, raw: dict, core: dict, core_id: str) -> list[object]:
    """A rules core's layer: the slots' labels, which are also the cells'
    prompts, and each rule's name and explanation. Returns the words the
    merged deck teaches: every form of every row."""
    table_core = core.get("table") if isinstance(core.get("table"), dict) else {}
    core_slots = table_core.get("slots")
    core_slots = [s for s in core_slots if isinstance(s, str)] \
        if isinstance(core_slots, list) else []
    rows = table_core.get("rows") if isinstance(table_core.get("rows"), list) else []
    core_rows = [row["word"] for row in rows
                 if isinstance(row, dict) and _is_str(row.get("word"))]
    core_rules: dict[str, list[str]] = {}
    for rule in core.get("rules") if isinstance(core.get("rules"), list) else []:
        if isinstance(rule, dict) and _is_str(rule.get("id")):
            words = rule.get("words")
            core_rules.setdefault(rule["id"], [
                str(w.get("word")) if isinstance(w, dict) else ""
                for w in words] if isinstance(words, list) else [])
    r.core_rules = list(core_rules)
    texts: list[object] = []
    for row in rows:
        forms = row.get("forms") if isinstance(row, dict) else None
        for v in forms.values() if isinstance(forms, dict) else []:
            texts.extend(v if isinstance(v, list) else [v])

    table = raw.get("table")
    if not isinstance(table, dict):
        r.error("table", "is required on a layer of a rules core: its slot_name and "
                         "every slot's label")
    else:
        for unknown in sorted(set(table) - LAYER_TABLE_KEYS, key=str):
            r.error("table", f"unknown field {unknown!r}")
        if not _is_str(table.get("slot_name")):
            r.error("table.slot_name", "is required")
        labels = table.get("slots")
        if not isinstance(labels, dict):
            r.error("table.slots", "must map every slot of the core to its label")
        else:
            for slot in core_slots:
                if slot not in labels:
                    r.error("table.slots", f"gives no label for {slot!r}")
            for slot, label in labels.items():
                if not isinstance(slot, str):
                    continue
                if slot not in core_slots:
                    r.error("table.slots", f"{slot!r} is not a slot of the core")
                elif not _is_str(label):
                    r.error(f"table.slots.{slot}", "must be the slot's label, as text")
                else:
                    for token in re.findall(r"\{(\w+)\}", label):
                        if token != "meaning":
                            r.error(f"table.slots.{slot}",
                                    f"uses unknown placeholder {{{token}}}; a label may "
                                    f"use {{meaning}}, and the word is shown with every "
                                    f"typed cell")
        prompts = table.get("prompts")
        if prompts is not None:
            if not isinstance(prompts, dict):
                r.error("table.prompts", "must map a row's word to its prompts, by slot")
            else:
                for word, by_slot in prompts.items():
                    if not isinstance(word, str):
                        continue
                    if word not in core_rows:
                        r.error("table.prompts", f"{word!r} is not a row of the core")
                    if not isinstance(by_slot, dict):
                        r.error(f"table.prompts.{word}", "must map slots to the whole "
                                                         "prompt")
                        continue
                    for slot, text in by_slot.items():
                        if not isinstance(slot, str):
                            continue
                        if slot not in core_slots:
                            r.error("table.prompts", f"{slot!r} is not a slot of the core")
                        elif not _is_str(text):
                            r.error(f"table.prompts.{word}.{slot}", "must be text")

    rules = raw.get("rules")
    if not isinstance(rules, dict):
        r.error("rules", "is required on a layer of a rules core: each rule's name "
                         "and explanation, by rule id")
        return texts
    for rid, rule in rules.items():
        if not isinstance(rid, str):
            continue
        if rid not in core_rules:
            r.error("rules", f"{rid!r} is not a rule of the core")
            continue
        where = f"rules.{rid}"
        if not isinstance(rule, dict):
            r.error(where, "must be a mapping with name and explanation")
            continue
        for unknown in sorted(set(rule) - LAYER_RULE_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        if not _is_str(rule.get("name")):
            r.error(where, "name is required")
        explanation = rule.get("explanation")
        if not _is_str(explanation):
            r.error(where, "explanation is required")
        else:
            check_placeholders(r, f"{where}.explanation", "", explanation,
                               core_rules[rid], "rule")
        r.layer_rules.append(rid)
    missing = [rid for rid in core_rules if rid not in r.layer_rules]
    msg = f"covers {len(r.layer_rules)} of {len(core_rules)} rules of {core_id}"
    if missing:
        msg += f"; the cells of {', '.join(missing)} are not asked"
    r.info("rules", msg)
    return texts


def _words(text: str) -> list[str]:
    """The words of [text], for comparing with the words decks teach: split
    at spaces and punctuation, but not at an apostrophe inside a word, as in
    ক’রে, and without numbers. A braille cell, though Unicode files it as a
    symbol, is a letter of its script, so ⠉⠁⠞ is one word (ADR-0043). Never
    used to change what is stored."""
    words = []
    for chunk in text.split():
        spaced = "".join(
            " " if unicodedata.category(ch)[0] in "PSZ" and ch not in "’'"
            and not "\u2800" <= ch <= "\u28ff" else ch
            for ch in chunk)
        for word in spaced.split():
            word = word.strip("’'")
            if word and not word.isdigit():
                words.append(unicodedata.normalize("NFC", word))
    return words


def _bare(text: str) -> str:
    """[text] without its spaces, punctuation and symbols, apostrophes kept,
    in Unicode's composed form: what a `words` list must join to."""
    return "".join(
        ch for ch in unicodedata.normalize("NFC", text)
        if not ch.isspace() and (unicodedata.category(ch)[0] not in "PSZ"
                                 or ch in "’'"))


def _split(text: str, given: list[str] | None) -> list[str]:
    """The words of [text]: its `words` where given ([check_given_words]),
    else [_words]'s split at spaces and punctuation."""
    return given if given is not None else _words(text)


def check_given_words(r: Report, where: str, prefix: str, value: object,
                      text: str | None) -> list[str] | None:
    """A card's or an example's `words` (DECK-FORMAT.md, Base words): the
    words of its target, in order, for a script written without spaces.
    Joined, with spaces and punctuation left out of both, they are the
    target. Returns them as [_words] gives words, or None where not given
    or wrong."""
    if value is None:
        return None
    if (not isinstance(value, list) or not value
            or not all(_is_str(w) for w in value)):
        r.error(where, f"{prefix}words must be a non-empty list of the "
                       f"{prefix}target's words, in order, each a string")
        return None
    bad = [w for w in value if any(ch.isspace() for ch in w) or not _bare(w)]
    if bad:
        r.error(where, f"{prefix}words: {bad[0]!r} is not a word: a word has no "
                       f"space in it, and is not punctuation alone")
        return None
    if text is not None and _bare("".join(value)) != _bare(text):
        r.error(where, f"{prefix}words join to {''.join(value)!r}, but the "
                       f"{prefix}target is {text!r}; give its words in order, "
                       f"every letter of it in one word (spaces and "
                       f"punctuation left out)")
        return None
    return [x for w in value for x in _words(w)]


def _given(block: dict) -> list[str] | None:
    """A card's or an example's `words`, as [check_given_words] returns them
    when well formed, for code that reads the raw YAML; None otherwise."""
    value, text = block.get("words"), block.get("target")
    if (not isinstance(value, list) or not value or not _is_str(text)
            or not all(_is_str(w) for w in value)
            or _bare("".join(value)) != _bare(text)):
        return None
    return [x for w in value for x in _words(w)]


def _taught(raw: dict) -> set[str]:
    """Every word a vocab or grammar deck teaches, as [_words] splits them,
    or as a card's or an example's `words` gives them."""
    texts: list[object] = []
    found: set[str] = set()
    for card in raw.get("cards") or []:
        if isinstance(card, dict):
            if (given := _given(card)) is not None:
                found.update(given)
            else:
                texts.append(card.get("target"))
            alts = card.get("alt_target")
            texts.extend(alts if isinstance(alts, list) else [])
            for ex in card.get("examples") or []:
                if isinstance(ex, dict) and (given := _given(ex)) is not None:
                    found.update(given)
                elif isinstance(ex, dict):
                    texts.append(ex.get("target"))
    pattern = raw.get("pattern")
    if isinstance(pattern, dict):
        for entry in pattern.get("entries") or []:
            if isinstance(entry, dict):
                texts.append(entry.get("lemma"))
                forms = entry.get("forms")
                texts.extend(forms.values() if isinstance(forms, dict) else [])
    return found | {w for t in texts if isinstance(t, str) for w in _words(t)}


def _check_by_language(r: Report, where: str, key: str, value: object) -> set[str]:
    """Text keyed by language code, as a fact's is, with English required.
    Returns the codes it has."""
    if not isinstance(value, dict) or not value:
        r.error(where, f"{key} must map language codes to text, e.g. {{ en: ... }}")
        return set()
    codes = set()
    for code, text in value.items():
        if not isinstance(code, str) or not LANG_RE.fullmatch(code):
            r.error(where, f"{key} key must be a 2-3 letter language code, "
                           f"{_code_error(code)}")
        elif isinstance(text, bool):
            r.error(where, f"{key}.{code} parsed as the boolean {text!r}. Quote the value.")
        elif not _is_str(text):
            r.error(where, f"{key}.{code} must be non-empty text")
        else:
            codes.add(code)
    if "en" not in value:
        r.error(where, f"{key} needs en: English is shown to every learner")
    return codes


def _check_passage_text(r: Report, where: str, block: dict, key: str) -> None:
    """Text from a passage, kept exactly as written: a quotation must stay
    letter for letter, so nothing here asks for it to be normalised."""
    val = block.get(key)
    if isinstance(val, bool):
        r.error(where, f"{key} parsed as the boolean {val!r} -- YAML read a "
                       f"bare true or false as a bool. Quote the value.")
    elif isinstance(val, (int, float)):
        r.error(where, f"{key} parsed as the number {val!r}, not text. Quote the value.")
    elif not _is_str(val):
        r.error(where, f"{key} is required and must be non-empty text")
    elif val != val.strip():
        r.warn(where, f"{key} has leading or trailing whitespace, which is kept "
                      f"exactly as written")


def check_passages(r: Report, passages: object, script: str, lang: str
                   ) -> list[tuple[str, str | None, list[str], set[str]]]:
    """A reading deck's passages and their questions (#98). See "Reading
    decks" in docs/DECK-FORMAT.md and ADR-0019."""
    found: list[tuple[str, str | None, list[str], set[str]]] = []
    if not isinstance(passages, list) or not passages:
        r.error("passages", "must be a non-empty list")
        return found
    needs_reading = script not in NO_READING
    # A question is a card: its id is a card id of the language, written
    # once in it (rule 1, ADR-0018). A passage's id names the language too,
    # and passage and question ids are one namespace.
    ids: set[str] = set()
    card_id = card_id_re(lang)
    passage_id = re.compile(rf"{re.escape(lang)}(?:-[a-z0-9]+)+")

    def new_id(where: str, value: object, *, question: bool) -> str | None:
        if question and (not _is_str(value) or not card_id.fullmatch(value)):
            r.error(where, f"id must be {lang}- and at least four digits, such as "
                           f"{lang}-0001, got {value!r}")
            return None
        if not question and (not _is_str(value) or not passage_id.fullmatch(value)
                             or card_id.fullmatch(value)):
            r.error(where, f"id must start with {lang}- and name the passage, such as "
                           f"{lang}-sahaj-path-1-01, got {value!r}")
            return None
        if value in ids:
            r.error(where, f"duplicate id {value!r}")
        ids.add(value)
        if question:
            r.card_defs[value] = CardDef(path=r.path, natives=set(), words=[])
        return value

    for i, passage in enumerate(passages):
        where = f"passages[{i}]"
        if not isinstance(passage, dict):
            r.error(where, "must be a mapping")
            continue
        pid = new_id(where, passage.get("id"), question=False)
        if pid is not None:
            where = f"passage {pid}"
        for unknown in sorted(set(passage) - PASSAGE_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        if not _is_str(passage.get("title")):
            r.error(where, "title is required")
        if not isinstance(passage.get("source"), dict):
            # A mapping is a culture passage's source block (D4), checked
            # with the deck's other kinds rules.
            _check_optional_text(r, where, passage, "source")
            _check_source_shape(r, where, "passage", passage.get("source"),
                                passage.get("id"))
        theme = passage.get("theme")
        if theme is not None and (not _is_str(theme) or not ID_RE.fullmatch(theme)):
            r.error(where, f"theme must be a theme id from decks/themes.yaml, got {theme!r}")
            theme = None

        texts: list[str] = []
        sentences = passage.get("sentences")
        if not isinstance(sentences, list) or not sentences:
            r.error(where, "sentences must be a non-empty list")
            sentences = []
        for j, sentence in enumerate(sentences):
            swhere = f"{where}.sentences[{j}]"
            if not isinstance(sentence, dict):
                r.error(swhere, "must be a mapping with text and reading")
                continue
            for unknown in sorted(set(sentence) - SENTENCE_KEYS, key=str):
                r.error(swhere, f"unknown field {unknown!r}")
            _check_passage_text(r, swhere, sentence, "text")
            if _is_str(sentence.get("text")):
                texts.append(sentence["text"])
            if "reading" in sentence or needs_reading:
                if needs_reading and "reading" not in sentence:
                    r.error(swhere, f"reading is required: the script is {script!r}")
                else:
                    _check_passage_text(r, swhere, sentence, "reading")

        questions = passage.get("questions")
        if not isinstance(questions, list) or len(questions) not in CHOICES:
            r.error(where, "questions must be a list of 2 to 4 questions")
            questions = questions if isinstance(questions, list) else []
        for j, question in enumerate(questions):
            qwhere = f"{where}.questions[{j}]"
            if not isinstance(question, dict):
                r.error(qwhere, "must be a mapping")
                continue
            qid = new_id(qwhere, question.get("id"), question=True)
            if qid is not None:
                qwhere = f"question {qid}"
            for unknown in sorted(set(question) - QUESTION_KEYS, key=str):
                r.error(qwhere, f"unknown field {unknown!r}")
            languages = _check_by_language(r, qwhere, "prompt", question.get("prompt"))
            options = question.get("options")
            answer = question.get("answer")
            if options is None:
                if not isinstance(answer, bool):
                    r.error(qwhere, f"a question without options is true or false, so "
                                    f"answer is true or false, got {answer!r}")
                continue
            if not isinstance(options, list) or len(options) not in CHOICES:
                r.error(qwhere, "options must be a list of 2 to 4 options")
                continue
            for k, option in enumerate(options):
                have = _check_by_language(r, qwhere, f"options[{k}]", option)
                if have and languages and have != languages:
                    r.error(qwhere, f"options[{k}] is written in {sorted(have)}, the "
                                    f"prompt in {sorted(languages)}: a question is "
                                    f"shown in a language only if all of it has it")
            if isinstance(answer, bool) or not isinstance(answer, int) \
                    or not 1 <= answer <= len(options):
                r.error(qwhere, f"answer must be the number of the right option, "
                                f"from 1 to {len(options)}, got {answer!r}")

        glossed: set[str] = set()
        glossary = passage.get("glossary")
        if glossary is not None and not isinstance(glossary, list):
            r.error(where, "glossary must be a list")
            glossary = []
        words: set[str] = set()
        for j, entry in enumerate(glossary or []):
            gwhere = f"{where}.glossary[{j}]"
            if not isinstance(entry, dict):
                r.error(gwhere, "must be a mapping with word, modern, reading and meaning")
                continue
            for unknown in sorted(set(entry) - GLOSS_KEYS, key=str):
                r.error(gwhere, f"unknown field {unknown!r}")
            _check_passage_text(r, gwhere, entry, "word")
            word = entry.get("word")
            if _is_str(word):
                if word in words:
                    r.error(gwhere, f"word {word!r} is listed twice")
                words.add(word)
                # Character for character: a curly apostrophe is not a
                # straight one, and nothing is normalised first.
                if not any(word in text for text in texts):
                    r.error(gwhere, f"word {word!r} does not occur in the passage, "
                                    f"character for character")
                glossed.update(_words(word))
            _check_passage_text(r, gwhere, entry, "modern")
            if _is_str(entry.get("modern")):
                glossed.update(_words(entry["modern"]))
            if needs_reading and "reading" not in entry:
                r.error(gwhere, f"reading is required: the script is {script!r}")
            elif "reading" in entry:
                _check_passage_text(r, gwhere, entry, "reading")
            _check_by_language(r, gwhere, "meaning", entry.get("meaning"))
            if "note" in entry:
                _check_by_language(r, gwhere, "note", entry["note"])

        if pid is not None:
            found.append((pid, theme, [w for t in texts for w in _words(t)], glossed))
    return found


def check_themes_file(r: Report, raw: dict) -> None:
    """The shared theme path, decks/themes.yaml. See ADR-0010."""
    for unknown in sorted(set(raw) - THEMES_KEYS):
        r.error("root", f"unknown field {unknown!r} in a themes file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    themes = raw.get("themes")
    if not isinstance(themes, list) or not themes:
        r.error("themes", "must be a non-empty list")
        return
    ids: list[str] = []
    for i, theme in enumerate(themes):
        where = f"themes[{i}]"
        if not isinstance(theme, dict) or set(theme) - {"id", "name", "tags"}:
            r.error(where, "must be a mapping with an id, a name and optional tags")
            continue
        tags = theme.get("tags")
        if tags is not None and (
            not isinstance(tags, list) or not tags
            or not all(_is_str(t) and t.strip() for t in tags)
        ):
            r.error(where, "tags must be a non-empty list of words (the search "
                    "finds the theme's decks by them)")
        tid = theme.get("id")
        if not _is_str(tid) or not ID_RE.fullmatch(tid):
            r.error(where, f"id must match [a-z0-9-]+, got {tid!r}")
            continue
        if tid in ids:
            r.error(where, f"theme {tid!r} is listed twice")
        if not _is_str(theme.get("name")):
            r.error(where, f"theme {tid!r} needs a name")
        ids.append(tid)
    r.themes = ids


def _is_core_id(value: object, lang: str) -> bool:
    """Whether [value] is a core id of [lang]: `<lang>-` and a name."""
    return (_is_str(value) and value.startswith(f"{lang}-")
            and ID_RE.fullmatch(value[len(lang) + 1:]) is not None)


def check_path_file(r: Report, raw: dict, path: Path) -> None:
    """A language's path, decks/<lang>/<lang>-path.yaml: its decks in
    teaching order, in units, by core id, shared by every native language
    it is taught from. See ADR-0013 and ADR-0036."""
    for unknown in sorted(set(raw) - PATH_KEYS - {"native"}, key=str):
        r.error("root", f"unknown field {unknown!r} in a path file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang = raw.get("language")
    lang_ok = isinstance(lang, str) and CODE_RE.fullmatch(lang) is not None
    if not lang_ok:
        r.error("language", f"must be a language code such as 'hi', {_code_error(lang)}")
    lc = lang if lang_ok else "xx"
    units = raw.get("units")
    if "native" in raw:
        # The per-course form, <lang>-<native>-path.yaml, before ADR-0036.
        native = raw.get("native")
        first = next((d for u in (units if isinstance(units, list) else [])
                      for d in (u if isinstance(u, list) else
                                u.get("decks", []) if isinstance(u, dict) else [])
                      if isinstance(d, str) and d != WILDCARD), None)
        example = f"{lc}-home"
        if isinstance(native, str) and first is not None \
                and first.startswith(f"{lc}-{native}-"):
            example = f"{lc}-{first[len(lc) + len(native) + 2:]}"
        r.error("native", f"a path is one per language learnt, decks/{lc}/{lc}-path.yaml, "
                          f"shared by every native language (ADR-0036); list core ids, "
                          f"such as {example!r}, and remove native")
    path_id = raw.get("id")
    if lang_ok and path_id != f"{lang}-path":
        r.error("id", f"a path of {lang} has id {lang}-path, the filename stem, "
                      f"got {path_id!r}")
    elif path_id != path.stem:
        r.error("id", f"is {path_id!r} but the filename stem is {path.stem!r}")
    _check_optional_text(r, "root", raw, "description")
    regions = check_regions(r, raw)
    genders = check_genders(r, raw)
    levels = check_levels(r, raw)
    if not isinstance(units, list) or not units:
        r.error("units", "must be a non-empty list")
        return
    listed: list[str] = []
    unit_of: dict[str, int] = {}
    parsed: list[Unit] = []
    sized: set[int] = set()
    passages: dict[str, int] = {}

    def check_decks(where: str, i: int, unit: object) -> list[str] | None:
        """A unit's core ids, the list form. Returns them without the
        wildcard, or None for the wildcard alone."""
        if not isinstance(unit, list) or not unit:
            r.error(where, "must be a non-empty list of core ids")
            return []
        # The wildcard takes decks the path does not list, such as a deck a
        # learner adds: its theme's unit, or a last unit of it alone.
        if WILDCARD in unit:
            if unit.index(WILDCARD) != len(unit) - 1 or unit.count(WILDCARD) > 1:
                r.error(where, f"{WILDCARD!r} can only end a unit")
            elif len(unit) == 1 and i != len(units) - 1:
                r.error(where, f"a unit of {WILDCARD!r} alone can only be the last")
            elif len(unit) > 1:
                r.open_units.append([d for d in unit if d != WILDCARD])
        decks = []
        for deck in unit:
            if deck == WILDCARD:
                continue
            if not _is_core_id(deck, lc):
                r.error(where, f"{deck!r} is not a core id of {lc}: {lc}- and a name, "
                               f"such as {lc}-home")
            elif deck in listed:
                r.error(where, f"{deck!r} is listed twice")
            else:
                listed.append(deck)
                unit_of[deck] = i
                decks.append(deck)
        return None if unit == [WILDCARD] else decks

    # A path has a B1 plan when a unit is a mapping that plans (ADR-0036).
    has_plan = any(isinstance(u, dict) and any(k in u for k in
                                                ("planned", "words", "grammar", "milestone"))
                   for u in units)
    for i, unit in enumerate(units):
        where = f"units[{i}]"
        if isinstance(unit, list):
            decks = check_decks(where, i, unit)
            parsed.append(Unit(i, decks or [], exempt=decks is None))
        elif isinstance(unit, dict):
            parsed.append(_check_unit(r, where, i, unit, check_decks, sized, lc,
                                      passages))
        else:
            r.error(where, "must be a list of core ids, or a mapping with decks or "
                           "planned")
            parsed.append(Unit(i, []))
    # The decks a learner who skips the alphabet leaves out: the script,
    # spelling and reading decks.
    alphabet = raw.get("alphabet", [])
    if not isinstance(alphabet, list):
        r.error("alphabet", "must be a list of core ids on the path")
        alphabet = []
    else:
        for deck in alphabet:
            if not _is_core_id(deck, lc):
                r.error("alphabet", f"{deck!r} is not a core id of {lc}: {lc}- and a "
                                    f"name, such as {lc}-home")
            elif deck not in listed:
                r.error("alphabet", f"lists {deck!r}, which the path does not")
    for u in parsed:
        if u.decks and u.planned is None and all(d in alphabet for d in u.decks):
            u.exempt = True
    marks, end = _check_plan(r, parsed, has_plan, sized, unit_of) if has_plan \
        else ({}, len(parsed) - 1)
    if lang_ok:
        r.course_path = (lang, listed)
        r.plan = PathPlan(lang, parsed, [d for d in alphabet if isinstance(d, str)],
                          has_plan, marks, end, regions, genders, levels)


def check_regions(r: Report, raw: dict) -> list[str] | None:
    """A language's regions (ADR-0036): where its speakers are, for a
    rater's answer and a card's region note. Returns their ids, or None
    when the path lists none."""
    if "regions" not in raw:
        return None
    regions = raw["regions"]
    ids: list[str] = []
    if not isinstance(regions, list) or not regions:
        r.error("regions", "must be a non-empty list of regions, each { id, name }")
        return ids
    for i, region in enumerate(regions):
        where = f"regions[{i}]"
        if not isinstance(region, dict):
            r.error(where, "must be a mapping")
            continue
        for unknown in sorted(set(region) - REGION_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        rid = region.get("id")
        if not _is_key(rid):
            r.error(f"{where}.id", f"must start with a letter and match [a-z0-9-]+, and "
                                   f"not be a YAML 1.1 boolean word, got {rid!r}")
        elif rid == ELSEWHERE:
            r.error(f"{where}.id", f"{ELSEWHERE} is the app's own answer; give the "
                                   f"region another id")
        elif rid in ids:
            r.error(f"{where}.id", f"{rid!r} is used twice")
        else:
            ids.append(rid)
        name = region.get("name")
        if not isinstance(name, dict) or not name:
            r.error(f"{where}.name", "must be a mapping of a language code to the "
                                     "region's name, with \"en\"")
            continue
        for code, text in name.items():
            if not isinstance(code, str) or not LANG_RE.fullmatch(code):
                r.error(f"{where}.name", f"{code!r} is not a language code")
            elif not _is_str(text):
                r.error(f"{where}.name", f"{code!r} is not text")
        if "en" not in name:
            r.error(f"{where}.name", 'has no "en"')
    return ids


def check_genders(r: Report, raw: dict) -> list[str] | None:
    """A language's gender classes (#512), such as ["m", "f"]: what a noun's
    `gender` may be. An empty list says the language has none. Returns
    them, or None when the path lists none."""
    if "genders" not in raw:
        return None
    genders = raw["genders"]
    if not isinstance(genders, list):
        r.error("genders", 'must be a list of the language\'s gender classes, such '
                           'as ["m", "f"], or [] for a language without gender')
        return []
    classes: list[str] = []
    for i, value in enumerate(genders):
        if not _is_str(value) or value != value.strip():
            r.error(f"genders[{i}]", f"must be a class name, quoted text with no "
                                     f"spaces around it, got {value!r}")
        elif value in classes:
            r.error(f"genders[{i}]", f"{value!r} is listed twice")
        else:
            classes.append(value)
    return classes


def check_levels(r: Report, raw: dict) -> dict[str, int] | None:
    """A path's own words per level (#615, ADR-0045), such as
    { A1: 120, A2: 60, B1: 80 }: what the level checks hold the plan to,
    instead of the fixed sizes. All three levels, each a whole number of 1 or
    more. Returns them, or None when the path gives none or they are
    malformed."""
    if "levels" not in raw:
        return None
    levels = raw["levels"]
    shape = 'must be a mapping of the words per level, such as { A1: 120, A2: 60, B1: 80 }'
    if not isinstance(levels, dict):
        r.error("levels", f"{shape}, got {levels!r}")
        return None
    ok = True
    for key in sorted(set(levels) - set(MILESTONES), key=str):
        r.error("levels", f"unknown level {key!r}; the levels are A1, A2 and B1")
        ok = False
    for level in MILESTONES:
        if level not in levels:
            r.error("levels", f"needs {level}; give the words for A1, A2 and B1")
            ok = False
            continue
        value = levels[level]
        if isinstance(value, bool) or not isinstance(value, int) or value < 1:
            r.error(f"levels.{level}", f"must be a whole number of words, 1 or more, "
                                       f"got {value!r}")
            ok = False
    return {level: levels[level] for level in MILESTONES} if ok else None


def _check_passages(r: Report, where: str, i: int, key: str, value: object,
                    seen: dict[str, int]) -> list[Passage]:
    """A unit's listening or reading passages: each named once in the path,
    with a description per native language (ADR-0036)."""
    shape = "must be a non-empty list of passages, each { id, text }"
    if not isinstance(value, list) or not value \
            or not all(isinstance(p, dict) for p in value):
        r.error(f"{where}.{key}", shape)
        return []
    found = []
    for j, passage in enumerate(value):
        pw = f"{where}.{key}[{j}]"
        for unknown in sorted(set(passage) - PASSAGE_PLAN_KEYS, key=str):
            r.error(pw, f"unknown field {unknown!r}")
        pid = passage.get("id")
        if not _is_str(pid) or not ID_RE.fullmatch(pid):
            r.error(pw, f"id must match [a-z0-9-]+, got {pid!r}")
            pid = None
        elif pid in seen:
            r.error(pw, f"passage {pid!r} is also earlier in this unit" if seen[pid] == i
                    else f"passage {pid!r} is also in units[{seen[pid]}]")
        else:
            seen[pid] = i
        text = passage.get("text")
        codes: set[str] = set()
        if not isinstance(text, dict) or not text:
            r.error(f"{pw}.text", "must be a mapping of a native language's code to the "
                                  "passage's description, such as { \"en\": \"...\" }")
        else:
            for code, t in text.items():
                if not isinstance(code, str) or not LANG_RE.fullmatch(code):
                    r.error(f"{pw}.text", f"{code!r} is not a language code")
                elif not _is_str(t):
                    r.error(f"{pw}.text", f"{code!r} is not text")
                else:
                    codes.add(code)
        if pid is not None:
            found.append(Passage(key, j, pid, codes))
    return found


def _check_unit(r: Report, where: str, i: int, unit: dict, check_decks,
                sized: set[int], lang: str, passages: dict[str, int]) -> Unit:
    """A unit written as a mapping: its core ids, or the deck it plans, with
    its planned size, grammar topics, milestone and passages."""
    for unknown in sorted(set(unit) - UNIT_KEYS, key=str):
        r.error(where, f"unknown field {unknown!r} in a unit")
    u = Unit(i, [], mapping=True)
    has_decks, has_planned = "decks" in unit, "planned" in unit
    if has_decks and has_planned:
        r.error(where, "has decks or planned, not both")
    elif not has_decks and not has_planned:
        r.error(where, "has neither decks nor planned")
    star = False
    if has_decks:
        decks = check_decks(f"{where}.decks", i, unit["decks"])
        star = decks is None
        u.decks = decks or []
        u.exempt = star
    planned = unit.get("planned") if has_planned and not has_decks else None
    theme_unit = False
    if has_planned and not has_decks:
        u.planned = {"id": None, "theme": None, "grammar": None}
        if not isinstance(planned, dict):
            r.error(f"{where}.planned", "must be a mapping with id, and theme or grammar")
            planned = None
        else:
            for unknown in sorted(set(planned) - PLANNED_KEYS, key=str):
                r.error(f"{where}.planned", f"unknown field {unknown!r}")
            pid = planned.get("id")
            if not _is_core_id(pid, lang):
                r.error(f"{where}.planned.id", f"must be a core id of {lang}, {lang}- and "
                                               f"a name, such as {lang}-health, got "
                                               f"{pid!r}")
            else:
                u.planned["id"] = pid
            # The unit's own `grammar` counts as the planned one (#622), as the
            # app reads it.
            has_grammar = "grammar" in planned or "grammar" in unit
            if "theme" in planned and has_grammar:
                r.error(f"{where}.planned", "names theme or grammar, not both")
            elif "theme" not in planned and not has_grammar:
                r.error(f"{where}.planned", "needs a theme or a grammar topic")
            if "theme" in planned:
                theme = planned["theme"]
                theme_unit = not has_grammar
                if not _is_str(theme) or not ID_RE.fullmatch(theme):
                    r.error(f"{where}.planned.theme", f"must be a theme id, got {theme!r}")
                else:
                    u.planned["theme"] = theme

    inner = isinstance(planned, dict)
    for key in ("words", "grammar"):
        if inner and key in planned and key in unit:
            r.error(where, f"{key} is given both in planned and beside it")
    words_given = (inner and "words" in planned) or "words" in unit
    if words_given:
        value = planned["words"] if inner and "words" in planned else unit["words"]
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            r.error(f"{where}.words", f"must be a whole number of words, 0 or "
                                      f"more, got {value!r}")
        else:
            u.words = value
    elif theme_unit:
        r.error(f"{where}.planned", "a planned theme unit gives its size in words")
    grammar_given = (inner and "grammar" in planned) or "grammar" in unit
    if grammar_given:
        value = planned["grammar"] if inner and "grammar" in planned else unit["grammar"]
        topics = [value] if isinstance(value, str) else value
        if (not isinstance(topics, list) or not topics
                or not all(_is_str(t) and ID_RE.fullmatch(t) for t in topics)):
            r.error(f"{where}.grammar", f'must be a grammar topic id or a list of them, '
                                        f'such as ["past"], got {value!r}')
        else:
            for k, t in enumerate(topics):
                if t in topics[:k]:
                    r.error(f"{where}.grammar", f"{t!r} is listed twice")
            u.grammar = list(dict.fromkeys(topics))
            if u.planned is not None and inner and "grammar" in planned:
                u.planned["grammar"] = u.grammar
    if words_given or grammar_given:
        sized.add(i)
    if "milestone" in unit:
        m = unit["milestone"]
        if m not in MILESTONES:
            r.error(f"{where}.milestone", f'must be "A1", "A2" or "B1", got {m!r}')
        else:
            u.milestone = m
    for key in ("listening_passages", "reading_passages"):
        if key in unit:
            u.passages += _check_passages(r, where, i, key, unit[key], passages)
    if has_planned and ("listening_passages" not in unit
                        or "reading_passages" not in unit):
        r.error(where, "a planned unit names its listening_passages and its "
                       "reading_passages (b1-plans.md: each planned unit names its "
                       "listening and reading passages)")
    if star and any(k in unit for k in ("words", "grammar", "milestone", "planned",
                                        "listening_passages", "reading_passages")):
        r.error(where, f'a unit of "{WILDCARD}" alone cannot carry a milestone or a '
                       f'plan')
    return u


def _check_plan(r: Report, units: list[Unit], has_plan: bool, sized: set[int],
                unit_of: dict[str, int]) -> tuple[dict[str, int], int]:
    """A path's B1 plan: the milestones A1, A2 and B1, in that order; every
    unit up to B1 sized; each grammar topic planned once. Returns where each
    milestone is, when they are in order, and the last unit up to B1."""
    found = [(u.milestone, u.i) for u in units if u.milestone is not None]
    first: dict[str, int] = {}
    for m, i in found:
        if m in first:
            r.error(f"units[{i}]", f"milestone {m!r} is already on units[{first[m]}]")
        else:
            first[m] = i
    names = [m for m, _ in found]
    marks: dict[str, int] = {}
    if names != list(MILESTONES):
        r.error("units", f"the B1 plan needs the milestones A1, A2 and B1, each once "
                         f"and in that order; found {', '.join(names) or 'none'}")
    else:
        marks = dict(first)
    end = first.get("B1", len(units) - 1)
    topics: dict[str, int] = {}
    planned_ids: dict[str, int] = {}
    for u in units:
        where = f"units[{u.i}]"
        if u.i <= end and not u.exempt:
            if u.mapping and u.i not in sized:
                r.error(where, "a unit up to B1 gives its planned size (words) or its "
                               "grammar topics (grammar)")
            elif not u.mapping:
                r.error(where, 'a unit up to B1 is a mapping with its words or grammar; '
                               'only an alphabet unit or "*" alone stays a list')
        if u.i <= end:
            for t in u.grammar:
                if t in topics:
                    r.error(where, f"grammar topic {t!r} is already planned in "
                                   f"units[{topics[t]}]")
                else:
                    topics[t] = u.i
        if u.planned is not None:
            if "B1" in first and u.i > first["B1"]:
                r.error(where, "a planned unit after the B1 mark; a B1 plan ends at B1")
            pid = u.planned["id"]
            if pid is not None:
                if pid in planned_ids:
                    r.error(f"{where}.planned.id", f"{pid!r} is planned twice, also in "
                                                   f"units[{planned_ids[pid]}]")
                elif pid in unit_of:
                    r.error(f"{where}.planned.id", f"{pid!r} is planned and also listed "
                                                   f"as a deck in units[{unit_of[pid]}]")
                planned_ids.setdefault(pid, u.i)
    return marks, end


def check_sounds_file(r: Report, raw: dict, path: Path, *, core: bool = False) -> None:
    """A language's sound contrasts, decks/<lang>/<lang>-sounds.yaml: pairs
    of letters or signs that change a word, for the speaking drill's
    feedback (#89). See ADR-0015. A core (`part: "core"`, #498) leaves each
    contrast's name and the description to its layers."""
    keys = (SOUNDS_KEYS - {"description"}) | {"part"} if core else SOUNDS_KEYS
    for unknown in sorted(set(raw) - keys, key=str):
        if core and unknown == "description":
            r.error("description", "a sounds core's description is in each layer")
        else:
            r.error("root", f"unknown field {unknown!r} in a sounds file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang = raw.get("language")
    if not isinstance(lang, str) or not CODE_RE.fullmatch(lang):
        r.error("language", f"must be a language code such as 'bn', {_code_error(lang)}")
        lang = None
    elif path.parent.name != lang:
        r.error("language", f"is {lang!r} but the file is in {path.parent.name}/")
    sounds_id = raw.get("id")
    if sounds_id != path.stem:
        r.error("id", f"is {sounds_id!r} but the filename stem is {path.stem!r}")
    elif lang is not None and sounds_id != f"{lang}-sounds":
        r.error("id", f"a sounds file for {lang} has id {lang}-sounds, got {sounds_id!r}")
    _check_optional_text(r, "root", raw, "description")
    contrasts = raw.get("contrasts")
    if not isinstance(contrasts, list) or not contrasts:
        r.error("contrasts", "must be a non-empty list")
        return
    ids: set[str] = set()
    for i, contrast in enumerate(contrasts):
        where = f"contrasts[{i}]"
        if not isinstance(contrast, dict):
            r.error(where, "must be a mapping with id, name and pairs")
            continue
        for unknown in sorted(set(contrast) - CONTRAST_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        if core and "name" in contrast:
            r.error(where, "a sounds core's names are in each layer, under contrasts")
        cid = contrast.get("id")
        if not _is_str(cid) or not ID_RE.fullmatch(cid):
            r.error(where, f"id must match [a-z0-9-]+, got {cid!r}")
        elif cid in ids:
            r.error(where, f"contrast {cid!r} is listed twice")
        else:
            ids.add(cid)
        if not core and (not _is_str(contrast.get("name")) or not contrast["name"].strip()):
            r.error(where, "needs a name, such as 'a breath after the consonant'")
        within = contrast.get("within_word", False)
        if not isinstance(within, bool):
            r.error(where, f"within_word must be true or false, got {within!r}")
        pairs = contrast.get("pairs")
        if not isinstance(pairs, list) or not pairs:
            r.error(where, "pairs must be a non-empty list")
            continue
        for j, pair in enumerate(pairs):
            ok = (isinstance(pair, list) and len(pair) == 2
                  and all(isinstance(p, str) for p in pair)
                  and pair[0] != pair[1] and (pair[0] or pair[1]))
            if not ok:
                r.error(f"{where}.pairs[{j}]",
                        f"must be two different quoted strings, at most one empty, got {pair!r}")


def _course_scripts(folder: Path) -> set[str]:
    """The scripts the decks directly in [folder] (a language's) are written
    in, hyphens as underscores: a script guide may be for any of them."""
    found: set[str] = set()
    for p in sorted(folder.glob("*.yaml")):
        raw = _load_raw_view(p)
        if isinstance(raw, dict) and isinstance(raw.get("language"), dict):
            found.update(s.replace("-", "_") for s in _scripts_of(raw["language"]))
    return found


def check_script_file(r: Report, raw: dict, path: Path, *, core: bool = False) -> None:
    """A script's guide, decks/<lang>/<lang>-script.yaml: the recurring
    features a learner from English misses, shown before the first script
    card (#30). See ADR-0016. A language written in several scripts has one
    guide for each: <lang>-script is its default, and <lang>-<script>-script,
    such as hi-perso-arabic-script, the guide of that script. A core (`part: "core"`, #498) leaves its name,
    intro and each feature's name and text to its layers."""
    texts = ("name", "intro")
    keys = (SCRIPT_KEYS - set(texts)) | {"part"} if core else SCRIPT_KEYS
    for unknown in sorted(set(raw) - keys, key=str):
        if core and unknown in texts:
            r.error(unknown, f"a script core's {unknown} is in each layer")
        else:
            r.error("root", f"unknown field {unknown!r} in a script guide")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang = raw.get("language")
    if not isinstance(lang, str) or not CODE_RE.fullmatch(lang):
        r.error("language", f"must be a language code such as 'bn', {_code_error(lang)}")
        lang = None
    elif path.parent.name != lang:
        r.error("language", f"is {lang!r} but the file is in {path.parent.name}/")
    if lang is not None:
        # The language it guides, for a topic that names its features.
        r.facts_lang = lang
    guide_id = raw.get("id")
    if guide_id != path.stem:
        r.error("id", f"is {guide_id!r} but the filename stem is {path.stem!r}")
    elif lang is not None:
        match = re.fullmatch(rf"{lang}-(?:([a-z]+(?:-[a-z]+)*)-)?script", guide_id)
        if match is None:
            r.error("id", f"a script guide for {lang} has id {lang}-script, or "
                          f"{lang}-<script>-script for another script of the language; "
                          f"got {guide_id!r}")
        elif match.group(1) is not None:
            script = match.group(1).replace("-", "_")
            scripts = _course_scripts(path.parent)
            if script not in scripts:
                r.error("id", f"{guide_id!r} is the guide for the script {script!r}, which "
                              f"none of the decks of {lang} is written in "
                              f"({', '.join(sorted(scripts)) or 'none found'})")
    for key in () if core else texts:
        if not _is_str(raw.get(key)) or not raw[key].strip():
            r.error(key, "is required text")
    features = raw.get("features")
    if not isinstance(features, list) or not features:
        r.error("features", "must be a non-empty list")
        return
    ids: set[str] = set()
    for i, feature in enumerate(features):
        where = f"features[{i}]"
        if not isinstance(feature, dict):
            r.error(where, "must be a mapping with id, name, example and text")
            continue
        for unknown in sorted(set(feature) - FEATURE_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        for key in ("name", "text") if core else ():
            if key in feature:
                r.error(where, f"a script core's feature {key} is in each layer, under "
                               f"features")
        fid = feature.get("id")
        if not _is_str(fid) or not ID_RE.fullmatch(fid):
            r.error(where, f"id must match [a-z0-9-]+, got {fid!r}")
        elif fid in ids:
            r.error(where, f"feature {fid!r} is listed twice")
        else:
            ids.add(fid)
            r.script_features.add(fid)
        for key in ("example",) if core else ("name", "example", "text"):
            if not _is_str(feature.get(key)) or not feature[key].strip():
                r.error(where, f"needs {key}, quoted text")
        if "term" in feature and (not _is_str(feature["term"]) or not feature["term"].strip()):
            r.error(where, "term must be quoted text, or left out")
        if "reading" in feature:
            if "term" not in feature:
                r.error(where, "reading is the term's, so it needs a term")
            elif not _is_str(feature["reading"]) or not feature["reading"].strip():
                r.error(where, "reading must be quoted text, or left out")
        letters = feature.get("letters", [])
        if not isinstance(letters, list) or not all(_is_str(x) and x for x in letters):
            r.error(where, "letters must be a list of quoted letters")
        elif core and _is_str(fid):
            r.script_chars.setdefault(fid, set()).update(
                unicodedata.normalize("NFC", x) for x in [feature.get("example"), *letters]
                if _is_str(x))


def validate_guide_layer(r: Report, raw: dict, path: Path, core: dict) -> None:
    """decks/<lang>/<native>/<lang>-<native>-script.yaml (or -sounds), the
    layer of a script guide or sounds core (#498): its text in one native
    language, keyed by the core's feature or contrast ids."""
    kind = core["kind"]
    lang = core.get("language") if _is_str(core.get("language")) else None
    native = raw.get("native")
    ncode = _lang_code(native)
    what = "script guide" if kind == "script" else "sounds file"
    check_transliterated(r, raw, fixed=ncode or "")
    _check_string_keys(r, raw, "root")
    for unknown in sorted(set(raw) - GUIDE_LAYER_KEYS[kind], key=str):
        if unknown == "part":
            r.error("part", 'a layer has no part; only a core is marked part: "core"')
        else:
            r.error("root", f"unknown field {unknown!r} in the layer of a {what}")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    check_langblock(r, "native", native, full=False)
    lid = raw.get("id")
    if lid != path.stem:
        r.error("id", f"is {lid!r} but the filename stem is {path.stem!r}")
    elif lang and ncode:
        # `hi-script` -> `hi-en-script`; `hi-perso-arabic-script` ->
        # `hi-en-perso-arabic-script`.
        core_id = core.get("id") if _is_str(core.get("id")) else f"{lang}-{kind}"
        want = f"{lang}-{ncode}" + core_id[len(lang):]
        if lid != want:
            r.error("id", f"the {ncode} layer of {core_id} has id {want}, got {lid!r}")
    if ncode and path.parent.name != ncode:
        r.error("root", f"a layer lives in decks/{lang}/{ncode}/, the folder of its "
                        f"native language; this one is in {path.parent.name!r}")
    if ncode:
        r.native_code = ncode

    def texts(key: str, items: object) -> dict[str, object]:
        """The core's [key] ids, each with its text here."""
        given = raw.get(key)
        if not isinstance(given, dict):
            r.error(key, f"must be a mapping from each of the core's {key} ids to "
                         f"its text")
            return {}
        ids = [x.get("id") for x in items if isinstance(x, dict)] \
            if isinstance(items, list) else []
        for k in given:
            if k not in ids:
                r.error(f"{key}.{k}", f"is not one of the core's {key}")
        for i in ids:
            if i not in given:
                r.error(key, f"gives no text for {i!r}")
        return {k: v for k, v in given.items() if k in ids}

    def text(where: str, value: object) -> None:
        if not _is_str(value) or not value.strip():
            r.error(where, "is required text")

    if kind == "script":
        text("name", raw.get("name"))
        text("intro", raw.get("intro"))
        for fid, value in texts("features", core.get("features")).items():
            where = f"features.{fid}"
            if not isinstance(value, dict):
                r.error(where, "must be a mapping with name and text")
                continue
            for unknown in sorted(set(value) - {"name", "text"}, key=str):
                r.error(where, f"unknown field {unknown!r}: the core gives the rest")
            text(f"{where}.name", value.get("name"))
            text(f"{where}.text", value.get("text"))
    else:
        _check_optional_text(r, "root", raw, "description")
        for cid, value in texts("contrasts", core.get("contrasts")).items():
            text(f"contrasts.{cid}", value)


NUMBERS_KEYS = {
    "schema", "id", "name", "kind", "language", "license", "description",
    "words", "tens_and_units", "hundreds", "hundreds_before", "thousands",
    "thousands_before", "join",
}
# The themes whose decks teach the words a numbers file may use.
NUMBER_THEMES = {"numbers-1-20", "numbers-big"}


def check_numbers_file(r: Report, raw: dict, path: Path) -> None:
    """A language's rules for spelling generated numbers. See ADR-0011."""
    for unknown in sorted(set(raw) - NUMBERS_KEYS, key=str):
        r.error("root", f"unknown field {unknown!r} in a numbers file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    for key in ("name", "license"):
        if not _is_str(raw.get(key)):
            r.error(key, "is required")
    check_langblock(r, "language", raw.get("language"), full=True)
    lang = raw.get("language")
    code = lang.get("code") if isinstance(lang, dict) else None
    if code is not None:
        want = f"{code}-numbers"
        if raw.get("id") != want:
            r.error("id", f"must be {want!r}, got {raw.get('id')!r}")
        elif path.stem != want:
            r.error("id", f"is {want!r} but the filename stem is {path.stem!r}")
    tu = raw.get("tens_and_units", False)
    if not isinstance(tu, bool):
        r.error("tens_and_units", "must be true or false")
    if "join" in raw and not isinstance(raw["join"], str):
        r.error("join", "must be text")

    used: set[str] = set()

    def table(key: str, lo: int, hi: int, *, required: bool, complete: bool) -> None:
        t = raw.get(key)
        if t is None:
            if required:
                r.error(key, "is required")
            return
        if not isinstance(t, dict) or not t:
            r.error(key, "must map numbers to their words")
            return
        for k, v in t.items():
            if isinstance(k, bool) or not isinstance(k, int) or not lo <= k <= hi:
                r.error(key, f"keys are whole numbers from {lo} to {hi}, got {k!r}")
                continue
            spellings = v if isinstance(v, list) else [v]
            if not spellings or not all(_is_str(x) for x in spellings):
                r.error(key, f"{k} must be a word or a list of words, got {v!r}")
                continue
            for x in spellings:
                if x != unicodedata.normalize("NFC", x):
                    r.error(key, f"{k}: {x!r} is not NFC-normalised")
                used.update(x.split())
        if complete:
            missing = [k for k in range(lo, hi + 1) if k not in t]
            if missing:
                r.error(key, f"needs an entry for each of {lo} to {hi}; missing {missing}")

    table("words", 1, 99, required=True, complete=False)
    table("hundreds", 1, 9, required=True, complete=True)
    table("hundreds_before", 1, 9, required=False, complete=True)
    table("thousands", 1, 9, required=True, complete=True)
    table("thousands_before", 1, 9, required=False, complete=True)
    if _is_str(code):
        r.number_words = (code, used)


def _lang_of(rep: Report) -> str | None:
    """The language a file belongs to, a path's included."""
    if rep.lang_code is not None:
        return rep.lang_code
    return rep.plan.lang if rep.plan is not None else None


class _Context:
    """What the checks across files read besides the files given: the other
    files of each language, read once per run (ADR-0036). Nothing is ever
    reported on a file read only for context."""

    def __init__(self, reports: list[Report]) -> None:
        self.reports = reports
        self.given = {rep.path.resolve() for rep in reports}
        self.stems = {rep.path.stem for rep in reports}
        self.langs: dict[str, _Language] = {}

    def lang(self, code: str) -> "_Language":
        if code not in self.langs:
            self.langs[code] = _Language(self, code)
        return self.langs[code]


class _Language:
    """A language's files: those given now, and every other one directly in
    its directory or one level below, in the repository's decks/<lang>/ and
    in the directory of every given file of the language. A file given now
    replaces one on disk with the same stem."""

    def __init__(self, ctx: _Context, code: str) -> None:
        self.ctx, self.code = ctx, code
        self.given = [rep for rep in ctx.reports if _lang_of(rep) == code]
        self.dirs = _unique_dirs(ROOT / "decks" / code, *(
            rep.path.parent.parent if rep.part == "layer" else rep.path.parent
            for rep in self.given), *(
            rep.path.parent for rep in ctx.reports if rep.facts_lang == code))
        self._files: list[Report] | None = None
        self._path: list[Report | None] | None = None
        self._defs: dict[str, CardDef] | None = None
        self._file_defs: dict[str, CardDef] | None = None
        self._natives: dict[str, set[str]] | None = None
        self._tcards: dict[str, TCard] | None = None

    def _on_disk(self, pattern: str) -> list[Path]:
        found: dict[Path, Path] = {}
        for d in self.dirs:
            for p in sorted(d.glob(pattern)):
                rp = p.resolve()
                if rp not in self.ctx.given and p.stem not in self.ctx.stems:
                    found.setdefault(rp, p)
        return list(found.values())

    def files(self) -> list[Report]:
        """The language's files not given now, validated for context."""
        if self._files is None:
            self._files = [rep for p in self._on_disk("*.yaml") + self._on_disk("*/*.yaml")
                           if _lang_of(rep := validate(p)) == self.code]
        return self._files

    def all(self) -> list[Report]:
        return self.given + self.files()

    def path(self) -> Report | None:
        """The language's path, decks/<lang>/<lang>-path.yaml (ADR-0036):
        given, else on disk. Read without reading the language's other
        files."""
        if self._path is None:
            given = [rep for rep in self.given if rep.plan is not None]
            if given:
                self._path = [given[0]]
            else:
                found = sorted(self._on_disk("*-path.yaml"),
                               key=lambda p: (p.stem != f"{self.code}-path", str(p)))
                self._path = [next((rep for p in found
                                    if (rep := validate(p)).plan is not None
                                    and rep.plan.lang == self.code), None)]
        return self._path[0]

    def natives(self) -> list[str]:
        """The native languages the language is taught from: those of its
        single-file decks and layers, given or on disk."""
        return sorted({rep.course_deck[1] for rep in self.all()
                       if rep.course_deck is not None})

    def native_name(self, native: str) -> str:
        """A native language's name, as its decks give it."""
        return next((rep.native_name for rep in self.all()
                     if rep.native_code == native and rep.native_name), native)

    def deck_for(self, native: str, core_id: str) -> str:
        """The deck a learner from [native] is taught for [core_id]:
        `te-home` from `en` is `te-en-home` (ADR-0036)."""
        return f"{self.code}-{native}-{core_id[len(self.code) + 1:]}"

    def by_core(self) -> dict[str, list[Report]]:
        """The language's cores and decks, by the core id a path lists them
        as: a core, and each course's deck for it."""
        found: dict[str, list[Report]] = {}
        for rep in self.all():
            if rep.listed_as is not None:
                found.setdefault(rep.listed_as, []).append(rep)
        return found

    def planned(self) -> list[tuple[str, Report]]:
        """The courses of a language whose path has a B1 plan, as (native,
        path): one path, read by each course."""
        path = self.path()
        if path is None or not path.plan.has_plan:
            return []
        return [(native, path) for native in self.natives()]

    def file_defs(self) -> dict[str, CardDef]:
        """The cards the language's files not given now write."""
        if self._file_defs is None:
            self._file_defs = {}
            for rep in self.files():
                for cid, d in rep.card_defs.items():
                    self._file_defs.setdefault(cid, d)
        return self._file_defs

    def defs(self) -> dict[str, CardDef]:
        """Every card the language writes, given files first."""
        if self._defs is None:
            self._defs = {}
            for rep in self.all():
                for cid, d in rep.card_defs.items():
                    self._defs.setdefault(cid, d)
        return self._defs

    def natives_of(self, cid: str, d: CardDef) -> set[str]:
        """The native languages a card is taught from: a core's card from
        each language whose layer gives it a native."""
        if not d.in_core:
            return d.natives
        if self._natives is None:
            self._natives = {}
            for rep in self.all():
                if rep.part == "layer" and rep.native_code is not None:
                    for c in rep.merged:
                        self._natives.setdefault(c.id, set()).add(rep.native_code)
        return self._natives.get(cid, set())

    def tcards(self) -> dict[str, TCard]:
        """Every written card of the language, as the B1 checks see it."""
        if self._tcards is None:
            self._tcards = {}
            for rep in self.all():
                for c in rep.cards:
                    self._tcards.setdefault(c.id, c)
        return self._tcards

    def decks(self, native: str) -> dict[str, Report]:
        """A course's decks by id: its single-file decks and its layers."""
        found: dict[str, Report] = {}
        for rep in self.all():
            if rep.course_deck is not None and rep.course_deck[1] == native:
                found.setdefault(rep.course_deck[2], rep)
        return found

    def deck_cards(self, rep: Report) -> list[TCard]:
        """The cards a course deck teaches: a single-file deck's written cards
        and its refs that resolve; a merged deck's included cards (ADR-0036)."""
        native = rep.native_code
        defs, tcards = self.defs(), self.tcards()
        cards = list(rep.merged) + list(rep.cards)
        refs = [(rid, has) for rid, has, _ in rep.refs] + list(rep.core_refs)
        for rid, has_native in refs:
            d = defs.get(rid)
            if d is not None and rid in tcards and (
                    has_native or native in self.natives_of(rid, d)):
                cards.append(tcards[rid])
        return cards

    def taught(self, native: str) -> dict[str, tuple[TCard, Report]]:
        """The cards a course teaches, each with the first deck teaching it."""
        found: dict[str, tuple[TCard, Report]] = {}
        for rep in self.decks(native).values():
            for c in self.deck_cards(rep):
                found.setdefault(c.id, (c, rep))
        return found

    def b1_decks(self, native: str) -> list[tuple[str, int, Report]]:
        """The B1 decks of a course, in path order, each with its unit: the
        course's deck for each core id its language's path lists when the
        path has a B1 plan, less its alphabet decks and its reading decks."""
        path = self.path()
        if path is None or not path.plan.has_plan:
            return []
        decks = self.decks(native)
        found = []
        for u in path.plan.units:
            for d in u.decks:
                rep = decks.get(self.deck_for(native, d))
                if d in path.plan.alphabet or rep is None or rep.deck_kind == "reading":
                    continue
                found.append((rep.course_deck[2], u.i, rep))
        return found

    def first_core(self) -> str | None:
        """The id of a core of the language, given or on disk, read without
        reading the language's other files where that can be helped."""
        for rep in self.given:
            if rep.part == "core" and rep.core_id is not None:
                return rep.core_id
        cores = []
        for p in self._on_disk("*.yaml"):
            try:
                text = p.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            if re.search(r"(?m)^[\"']?part[\"']?\s*:", text):
                raw = _load_raw_view(p)
                if isinstance(raw, dict) and raw.get("part") == "core" \
                        and raw.get("kind") not in GUIDE_KINDS:
                    cores.append(raw.get("id") if _is_str(raw.get("id")) else p.stem)
        return sorted(cores)[0] if cores else None


_LAST_CONTEXT: list = [None, None, None]


def _context(reports: list[Report]) -> _Context:
    """One context per run: the checks across files of one call to main
    share it, so each language's files are read once."""
    key = tuple(map(id, reports))
    if _LAST_CONTEXT[0] is reports and _LAST_CONTEXT[1] == key:
        return _LAST_CONTEXT[2]
    ctx = _Context(reports)
    _LAST_CONTEXT[:] = [reports, key, ctx]
    return ctx


def _repo_card_defs(lang: str) -> dict[str, CardDef]:
    """The cards the repository's own decks write for [lang], cores and
    layers included, so that one file can be validated alone and still have
    its refs resolved, and a new card takes a free id."""
    return _Context([]).lang(lang).defs()


def check_cards_across(reports: list[Report]) -> list[str]:
    """A card id is written once in its language, in any course, core or
    layer, and every ref names a card written in another deck of that
    language. A ref from a course taught from another language gives its
    own native (ADR-0018); a ref to a core's card resolves through a layer
    of the same native (ADR-0036)."""
    ctx = _context(reports)
    problems = []
    defs: dict[str, CardDef] = {}
    for rep in reports:
        if rep.lang_code is None:
            continue
        for cid, d in rep.card_defs.items():
            # A file of the language not among those given still writes its
            # cards, so a file checked alone is held to them; not to its own
            # deck's copy, which a draft elsewhere replaces.
            elsewhere = ctx.lang(rep.lang_code).file_defs().get(cid)
            first = defs.get(cid) or elsewhere
            if first is not None and first.path.resolve() != rep.path.resolve():
                problems.append(f"{rep.path}: card {cid} is already written in "
                                f"{first.path}; list it here with ref: {cid}")
            else:
                defs[cid] = d

    sheets: dict[str, list[Report]] = {}
    for rep in reports:
        if rep.situations_lang is not None:
            sheets.setdefault(rep.situations_lang, []).append(rep)
    for code, files in sorted(sheets.items()):
        if len(files) > 1:
            problems.append(f"more than one situations file for {code}: "
                            + ", ".join(str(rep.path) for rep in files))

    def find(rep: Report, cid: str) -> CardDef | None:
        found = defs.get(cid)
        code = rep.lang_code or rep.facts_lang
        if found is None and code is not None:
            found = ctx.lang(code).file_defs().get(cid)
        return found

    for rep in reports:
        for rid, has_native, where in rep.refs:
            found = find(rep, rid)
            if found is None:
                problems.append(f"{rep.path}: {where}: no deck writes card {rid}")
                continue
            if found.is_set:
                problems.append(f"{rep.path}: {where}: {rid} is a set card, taught in "
                                f"its own deck and never listed by ref")
                continue
            # A ref to a card its own deck writes is refused within the deck.
            natives = ctx.lang(rep.lang_code).natives_of(rid, found) \
                if rep.lang_code is not None else found.natives
            if rep.native_code not in natives and not has_native:
                problems.append(f"{rep.path}: {where}: the card is written for "
                                f"learners from {sorted(natives)}; this deck is taught "
                                f"from {rep.native_code!r}, so the ref needs its own "
                                f"native")
            if rep.number_taught is not None:
                rep.number_taught[1].update(w for t in found.words for w in t.split())
    for rep in reports:
        for pid, where in rep.pairs:
            if find(rep, pid) is None:
                problems.append(f"{rep.path}: {where}: pair names card {pid}, "
                                f"which no deck writes")
        for ref, where, i in rep.note_refs:
            if find(rep, ref) is None:
                problems.append(f"{rep.path}: {where}: notes[{i}].ref names card "
                                f"{ref}, which no deck writes")
        for ref, where, i, kind in rep.like_refs:
            if find(rep, ref) is None:
                problems.append(f"{rep.path}: {where}: notes[{i}].ref names card "
                                f"{ref}, which no deck writes ({kind} note)")
        for ref, where, place in rep.rejected_refs:
            if find(rep, ref) is None:
                problems.append(f"{rep.path}: {where}: {place} names card {ref}, "
                                f"which no deck writes")
        for ref, where, place in rep.base_refs:
            if find(rep, ref) is None:
                problems.append(f"{rep.path}: {where}: {place} names card {ref}, "
                                f"which no deck writes")
        for ref, where, place, tiles in rep.tile_refs:
            found = find(rep, ref)
            if found is not None and found.target.lower() in tiles:
                problems.append(f"{rep.path}: {where}: {place}.ref names {ref}, "
                                f"{found.target!r}, a tile the answer needs; a "
                                f"confusable is a wrong tile")
    return problems


def next_card_id(lang: str) -> str:
    """The next free card id in [lang], after every one its decks write."""
    numbers = [int(cid.rsplit("-", 1)[1]) for cid in _repo_card_defs(lang)]
    return f"{lang}-{max(numbers, default=0) + 1:04d}"


def check_numbers_across(reports: list[Report]) -> list[str]:
    """A numbers file spells only with words its language's number decks
    teach, so a generated number never uses a word the learner was not
    taught (#54)."""
    taught: dict[str, set[str]] = {}
    for rep in reports:
        if rep.number_taught is not None:
            code, words = rep.number_taught
            taught.setdefault(code, set()).update(words)
    problems = []
    for rep in reports:
        if rep.number_words is None:
            continue
        code, used = rep.number_words
        if code not in taught:
            problems.append(f"{rep.path}: no {code} deck teaches a number theme "
                            f"({', '.join(sorted(NUMBER_THEMES))}), so there are "
                            f"no taught words to spell with")
            continue
        missing = sorted(used - taught[code])
        if missing:
            problems.append(f"{rep.path}: spells with words no {code} number deck "
                            f"teaches: {', '.join(missing)}")
    return problems


def check_themes_across(reports: list[Report]) -> list[str]:
    """Every theme a deck names is on the path, once per course."""
    listed = [rep for rep in reports if rep.themes is not None]
    problems = []
    if len(listed) > 1:
        problems.append("more than one themes file: "
                        + ", ".join(str(rep.path) for rep in listed))
    known = set(listed[0].themes) if listed else set()
    seen: dict[tuple[str, str, str], Path] = {}
    for rep in reports:
        key = rep.theme_key
        if key is None:
            continue
        if key[2] not in known:
            problems.append(f"{rep.path}: theme {key[2]!r} is not in decks/themes.yaml")
        elif key in seen:
            problems.append(f"{rep.path}: {key[0]} from {key[1]} already has a "
                            f"{key[2]!r} deck, {seen[key]}")
        else:
            seen[key] = rep.path
    return problems


def check_icons_across(reports: list[Report]) -> list[str]:
    """Every deck of a language gives the same icon, or none does: its chip
    shows the icon of whichever deck the app reads first (ADR-0027)."""
    by_language: dict[str, dict[str | None, list[Path]]] = {}
    for rep in reports:
        if rep.icon is not None:
            code, icon = rep.icon
            by_language.setdefault(code, {}).setdefault(icon, []).append(rep.path)
    problems = []
    for code, icons in sorted(by_language.items()):
        if len(icons) > 1:
            given = "; ".join(
                f"{'no icon' if icon is None else repr(icon)} in {paths[0]}"
                + (f" and {len(paths) - 1} more" if len(paths) > 1 else "")
                for icon, paths in icons.items())
            problems.append(f"the {code} decks give different icons: {given}")
    return problems


def _course_of(lang: _Language, core_id: str) -> str | None:
    """The native code [core_id]'s name starts with, when it is a course's
    deck id and not a core id: `te-en-home` reads as the te-en course's."""
    seg = core_id[len(lang.code) + 1:].split("-")[0]
    if seg in lang.natives() or _reads_as_course(lang.dirs, lang.code, seg):
        return seg
    return None


def check_paths_across(reports: list[Report]) -> list[str]:
    """A language has one path, which lists every deck of the language
    exactly once, by its core id, for every course (ADR-0013, ADR-0036)."""
    ctx = _context(reports)
    given = {rep.path.resolve() for rep in reports}
    problems = []
    seen: dict[str, Path] = {}
    for rep in reports:
        if rep.course_path is None:
            continue
        lang, listed = rep.course_path
        if lang in seen:
            problems.append(f"{rep.path}: root: {lang} already has a path, {seen[lang]}; "
                            f"a language has one")
            continue
        seen[lang] = rep.path
        # A path left beside it, such as a course's path from before ADR-0036.
        for other in sorted(rep.path.parent.glob("*-path.yaml")):
            if other.resolve() in given:
                continue
            raw = _load_raw_view(other)
            if isinstance(raw, dict) and raw.get("kind") == "path" \
                    and raw.get("language") == lang:
                problems.append(f"{rep.path}: root: {lang} already has a path, {other}; "
                                f"a language has one")
                break
        language = ctx.lang(lang)
        by_core = language.by_core()
        for u in rep.plan.units:
            for core in u.decks:
                native = _course_of(language, core)
                if native is not None:
                    problems.append(
                        f"{rep.path}: units[{u.i}]: lists {core!r}, a deck of the "
                        f"{lang}-{native} course; a path lists core ids, here "
                        f"{lang + '-' + core[len(lang) + len(native) + 2:]!r}")
                elif core not in by_core:
                    problems.append(
                        f"{rep.path}: units[{u.i}]: lists {core!r}, which is no deck of "
                        f"{lang}: no core {core}, and no deck {lang}-<native>-"
                        f"{core[len(lang) + 1:]}")
                elif any(o.hidden for o in by_core[core]):
                    problems.append(
                        f"{rep.path}: units[{u.i}]: lists {core!r}, a hidden deck: a "
                        f"hidden deck is on no path (found by search, added by the "
                        f"learner)")
        # Every deck of the language given now, of every course, is on it.
        for deck in reports:
            # A deck with a genre is found by its section or by search, and is on
            # a path only when a unit names it (the plan, D1 and D3).
            if deck.course_deck is None or deck.course_deck[0] != lang \
                    or deck.listed_as is None or deck.listed_as in listed \
                    or deck.genre is not None or deck.hidden:
                continue
            problems.append(f"{rep.path}: units: does not list {deck.listed_as!r}, the "
                            f"core id of {deck.course_deck[2]}; every deck of {lang} is "
                            f"on its path")
        # A wildcard takes its unit's theme, so its unit needs a theme deck,
        # in some course. Only when the unit's decks can be looked at.
        for unit in rep.open_units:
            if all(core in by_core for core in unit) and not any(
                    o.theme_key is not None or o.core_theme is not None
                    for core in unit for o in by_core[core]):
                problems.append(f"{rep.path}: the unit [{', '.join(unit)}] ends in "
                                f"{WILDCARD!r} but has no theme deck to say which "
                                f"decks it takes")

    # A language with a deck in this repository needs a path. A path not
    # being validated now, in the language's folder on disk, counts:
    # validating one deck is legitimate. So is drafting one outside the
    # repository, as check_index also allows.
    root = ROOT
    pathless: dict[str, Path] = {}
    for rep in reports:
        if rep.course_deck is None or rep.course_deck[0] in seen:
            continue
        lang = rep.course_deck[0]
        try:
            rep.path.resolve().relative_to(root)
        except ValueError:
            continue
        # A layer's language folder is the one above it.
        folder = rep.path.parent.parent if rep.part == "layer" else rep.path.parent
        if (folder / f"{lang}-path.yaml").exists():
            continue
        pathless.setdefault(lang, rep.path)
    for lang, deck in pathless.items():
        problems.append(f"{deck}: {lang} has no path; add {lang}-path.yaml in "
                        f"decks/{lang}/")
    return problems


def check_reading_across(reports: list[Report]) -> list[str]:
    """A reading deck's passages against the rest of its course (#98).

    A passage's theme must be on the theme path. Two things are only
    warned of: a word in a passage that no deck of the course teaches, as
    [_words] splits them, glossed words aside; and a passage on the path in
    a unit no later than its theme's deck, whose new questions would then
    come before the words they use. Both decks are found on the language's
    path by their core ids."""
    problems: list[str] = []
    listed = [rep for rep in reports if rep.themes is not None]
    known = set(listed[0].themes) if listed else None
    taught: dict[tuple[str, str], set[str]] = {}
    for rep in reports:
        if rep.taught_words is not None:
            lang, native, words = rep.taught_words
            taught.setdefault((lang, native), set()).update(words)
    theme_decks = {rep.theme_key: (rep.course_deck[2], rep.listed_as) for rep in reports
                   if rep.theme_key is not None and rep.course_deck is not None}
    units: dict[str, dict[str, int]] = {}
    for rep in reports:
        if rep.plan is not None:
            units.setdefault(rep.plan.lang, {d: u.i for u in rep.plan.units
                                             for d in u.decks})
    for rep in reports:
        if rep.passages is None or rep.course_deck is None:
            continue
        lang, native, passages = rep.passages
        course = (lang, native)
        unit_of = units.get(lang, {})
        for pid, theme, words, glossed in passages:
            if theme is not None and known is not None and theme not in known:
                problems.append(f"{rep.path}: passage {pid}: theme {theme!r} is not "
                                f"in decks/themes.yaml")
            theme_deck, theme_core = theme_decks.get((lang, native, theme), (None, None))
            here, there = unit_of.get(rep.listed_as), unit_of.get(theme_core)
            if here is not None and there is not None and here <= there:
                rep.warn(f"passage {pid}", f"follows {theme!r}, but the path puts "
                                           f"{rep.course_deck[2]} in unit {here + 1} "
                                           f"and {theme_deck} in unit {there + 1}; put "
                                           f"it in a later unit")
            # Only against a course whose decks are being validated too.
            if course not in taught:
                continue
            unknown = list(dict.fromkeys(
                w for w in words if w not in taught[course] and w not in glossed))
            if unknown:
                rep.warn(f"passage {pid}", f"{len(unknown)} words appear in no "
                                           f"{lang}-{native} deck: {', '.join(unknown)}")
    return problems


# --- The B1 checks across files (ADR-0036) -----------------------------------

def counts_as_word(card: object, deck_kind: str) -> bool:
    """Whether a card counts as one of a unit's words: a card of a vocab
    deck, not a phrasebook card or a phrase, whose target is one word or a
    several-word noun, verb, adjective, adverb or pronoun. The app's
    `countsAsWord` is the same."""
    if isinstance(card, dict):
        target, pos = card.get("target"), card.get("pos")
        phrasebook = card.get("phrasebook") is True
        given = _given(card)
    else:
        target, pos, phrasebook = card.target, card.pos, card.phrasebook
        given = card.words
    if deck_kind != "vocab" or phrasebook or pos == "phrase" or not isinstance(target, str):
        return False
    return len(_split(target, given)) == 1 or pos in LEXICAL_POS


def _languages(reports: list[Report]) -> list[str]:
    return sorted({code for rep in reports if (code := _lang_of(rep)) is not None})


def check_sets_across(reports: list[Report]) -> list[str]:
    """A set card's members (DECK-FORMAT.md, Set cards): each ref a card of
    the language that is not a set; a rule's set a rule or rules core of the
    language, and the value it fixes a row of its table, by the word's
    target or id, under a part of speech of its rows, or else a slot of the
    table and of the rule."""
    ctx = _context(reports)
    problems: list[str] = []
    for rep in reports:
        if rep.lang_code is None or not rep.sets:
            continue
        lang = ctx.lang(rep.lang_code)
        defs = lang.defs()
        tables = [(o.core_id, o.table) for o in lang.all()
                  if o.part == "core" and o.table is not None]
        for cid, where, members in rep.sets:
            at = f"{rep.path}: {where}"
            if isinstance(members, list):
                for i, ref in enumerate(members):
                    d = defs.get(ref)
                    if d is None:
                        problems.append(f"{at}: members names card {ref}, which no deck "
                                        f"writes")
                    elif d.is_set:
                        problems.append(f"{at}: members names {ref}, a set card; a "
                                        f"set's members are cards that are asked")
                continue
            rule, axis, value, shown = members
            found = [(core_id, t) for core_id, t in tables
                     if rule == core_id or rule in t.rule_slots]
            if not found:
                problems.append(f"{at}: members.rule names {rule}, which no rules deck "
                                f"of {rep.lang_code} defines")
                continue
            core_id, t = found[0]
            slots = t.slots if rule == core_id else t.rule_slots[rule]
            if axis in t.pos:
                rows = [w for w in t.rows
                        if w == value or (w in defs and defs[w].target == value)]
                if not rows:
                    problems.append(f"{at}: members.{axis}: {value!r} is no row of "
                                    f"{core_id}; give a row's word, as its card writes "
                                    f"it, or its id")
            elif axis in POS:
                problems.append(f"{at}: members.{axis}: {core_id}'s rows are "
                                f"{', '.join(t.pos)}, not {axis}")
            elif value not in slots:
                problems.append(f"{at}: members.{axis}: {value!r} is not a slot of "
                                f"{rule}; a value that is not a row's word is a slot, "
                                f"one of {slots}, or use a part of speech of its rows "
                                f"({', '.join(t.pos)}) as the key")
            else:
                for i, row in enumerate(shown):
                    if row not in t.rows:
                        problems.append(f"{at}: shown[{i}]: {row} is no row of "
                                        f"{core_id}")
                    elif value not in t.row_slots.get(row, set()):
                        problems.append(f"{at}: shown[{i}]: {row} has no {value} form "
                                        f"in {core_id}")
    return problems


def check_layers_across(reports: list[Report]) -> list[str]:
    """How much of its core a layer teaches, and a core no layer names."""
    ctx = _context(reports)
    for rep in reports:
        if rep.lang_code is None:
            continue
        lang = ctx.lang(rep.lang_code)
        if rep.part == "layer" and rep.core_cards is not None and rep.translated is not None:
            defs = lang.defs()
            resolved = [rid for rid, gives in rep.core_refs if not gives and rid in defs
                        and rep.native_code in lang.natives_of(rid, defs[rid])]
            n = len(rep.translated) + len(resolved)
            m = len(rep.core_cards)
            pct = round(100 * n / m) if m else 0
            rep.info("cards", f"covers {n} of {m} cards of {rep.core_id} ({pct}%)")
            if rep.number_taught is not None:
                for rid, _ in rep.core_refs:
                    if rid in defs:
                        rep.number_taught[1].update(
                            w for t in defs[rid].words for w in t.split())
        if rep.part == "core" and rep.core_id is not None:
            if not any(o.part == "layer" and o.core_id == rep.core_id
                       for o in lang.all()):
                rep.warn("root", "no layer names this core, so no learner is taught it")
    return []


def check_rules_across(reports: list[Report]) -> list[str]:
    """A rules table's rows against the language's words, a rule id defined
    once in the language, and the rules a sentence names."""
    ctx = _context(reports)
    problems: list[str] = []
    for rep in reports:
        if rep.lang_code is None or not (rep.table or rep.rules_defined or rep.card_rules):
            continue
        lang = ctx.lang(rep.lang_code)
        if rep.table is not None:
            problems += _check_rows(rep, lang)
        for rid, where in rep.rules_defined:
            other = next((o for o in lang.all()
                          if o.path.resolve() != rep.path.resolve()
                          and any(rid == x for x, _ in o.rules_defined)), None)
            if other is not None:
                problems.append(f"{rep.path}: {where}: is also defined in {other.path}")
        if rep.card_rules:
            known = {rid for o in lang.all() for rid, _ in o.rules_defined}
            for rid, where in rep.card_rules:
                if rid not in known:
                    problems.append(f"{rep.path}: {where}: rules names {rid}, which no "
                                    f"rules deck of {rep.lang_code} defines")
    return problems


def _check_rows(rep: Report, lang: _Language) -> list[str]:
    """Every taught word of the table's kind has its row, and every row is
    such a word, with the reading a typed cell shows."""
    t = rep.table
    defs = lang.defs()
    p = rep.path
    problems = []

    def of_kind(pos: str | None, tags: list[str]) -> bool:
        return pos in t.pos and (not t.tags or bool(set(tags) & set(t.tags)))

    kinds = ", ".join(t.pos) + (f" tagged {', '.join(t.tags)}" if t.tags else "")
    for word in t.rows:
        where = f"table.rows[{word}]"
        d = defs.get(word)
        if d is None or not d.vocab:
            problems.append(f"{p}: {where}: no vocab deck writes card {word}")
            continue
        if not of_kind(d.pos, d.tags):
            problems.append(f"{p}: {where}: {word} is a {d.pos or 'word with no pos'}, "
                            f"not one of {kinds}")
        if d.phrasebook:
            problems.append(f"{p}: {where}: {word} is a phrasebook card; its words are "
                            f"taught as words")
        if word in t.excepted:
            problems.append(f"{p}: {where}: {word} is both a row and in "
                            f"applies_to.except")
        if t.script not in NO_READING and not d.reading:
            problems.append(f"{p}: {where}: {word} has no reading, but the script is "
                            f"{t.script!r}; a typed cell shows the word with its reading")
    for cid in t.excepted:
        if cid not in defs:
            problems.append(f"{p}: table.applies_to.except: no deck writes card {cid}")
    rows = set(t.rows)
    reported: set[str] = set()
    for native, _ in lang.planned():
        for deck_id, _, drep in lang.b1_decks(native):
            if drep is None or drep.deck_kind != "vocab":
                continue
            for c in lang.deck_cards(drep):
                if (c.id in reported or c.id in rows or c.id in t.excepted
                        or c.phrasebook or not of_kind(c.pos, c.tags)):
                    continue
                reported.add(c.id)
                problems.append(f"{p}: table: {c.id} ({c.target}) is a {c.pos} taught in "
                                f"{deck_id} but has no row; add its forms, or list it in "
                                f"applies_to.except")
    return problems


def check_notes_across(reports: list[Report]) -> list[str]:
    """A pair note's partner is taught in the course, so the minimal-pair
    panel can show both words with their meanings; and, in a B1 deck, every
    word card has notes and every `pair:` its pair note (warnings)."""
    ctx = _context(reports)
    problems: list[str] = []
    for rep in reports:
        if rep.lang_code is None or rep.native_code is None:
            continue
        if not rep.note_refs and not rep.text_pairs:
            continue
        lang = ctx.lang(rep.lang_code)
        defs, taught = lang.defs(), lang.taught(rep.native_code)
        course = f"{rep.lang_code}-{rep.native_code}"
        for ref, where, i in rep.note_refs:
            if ref in defs and ref not in taught:
                problems.append(f"{rep.path}: {where}: notes[{i}].ref names {ref}, which "
                                f"no {course} deck teaches; the minimal-pair panel shows "
                                f"both words with their meanings")
        for cid, nid, ref in rep.text_pairs:
            if ref in defs and ref not in taught:
                problems.append(f"{rep.path}: cards.{cid}.notes.{nid}: the partner {ref} "
                                f"is not taught from {rep.native_name}; translate it in a "
                                f"{course} deck, or leave this note's text out")

    given = {rep.path.resolve(): rep for rep in reports}
    warned: set[tuple[Path, str, str]] = set()
    for code in _languages(reports):
        lang = ctx.lang(code)
        for native, _ in lang.planned():
            for _, _, drep in lang.b1_decks(native):
                if drep is None or drep.deck_kind != "vocab":
                    continue
                for c in lang.deck_cards(drep):
                    owner = given.get(c.path.resolve())
                    written = lang.tcards().get(c.id, c)
                    if owner is None:
                        continue
                    if (counts_as_word(written, written.deck_kind) and not written.notes
                            and (c.path, c.id, "notes") not in warned):
                        warned.add((c.path, c.id, "notes"))
                        owner.warn(written.where, "no notes; every word card should have "
                                                  "one or more (pair, culture, usage, "
                                                  "behaviour, note)")
                    if (written.single and written.pair is not None
                            and not any(n.kind == "pair" and n.ref == written.pair
                                        for n in written.notes)
                            and (c.path, c.id, "pair") not in warned):
                        warned.add((c.path, c.id, "pair"))
                        owner.warn(written.where, f"pair names {written.pair}, but no "
                                                  f"pair note does; the minimal-pair "
                                                  f"button needs a pair note")
    return problems


def check_bases_across(reports: list[Report]) -> list[str]:
    """In a B1 deck, every word of a target or an example is a word the
    course teaches as a card, or has a `bases` entry. In a script written
    without spaces, the words are the card's and each example's `words`,
    which each gives."""
    ctx = _context(reports)
    given = {rep.path.resolve() for rep in reports}
    problems: list[str] = []
    seen: set[tuple] = set()
    for code in _languages(reports):
        lang = ctx.lang(code)
        for native, _ in lang.planned():
            course = f"{code}-{native}"
            taught: set[str] = set()
            for c, drep in lang.taught(native).values():
                if drep.deck_kind != "vocab" or c.phrasebook:
                    continue
                for t, w in [(c.target, c.words), *((a, None) for a in c.alt_targets)]:
                    words = _split(t, w)
                    if len(words) == 1:
                        taught.add(_key(words[0]))
            for deck_id, _, drep in lang.b1_decks(native):
                if drep is None or drep.deck_kind != "vocab":
                    continue
                unspaced = drep.script in NO_SPACES
                for c in list(drep.merged) + list(drep.cards):
                    if c.path.resolve() not in given:
                        continue
                    texts = [("", c.target, c.bases, c.words)] + [
                        (f"examples[{j}]: ", t, b, c.example_words.get(j))
                        for j, t, b in c.examples]
                    for prefix, text, bases, words in texts:
                        if unspaced and words is None:
                            key = (c.path, c.where, prefix, "words")
                            if key not in seen:
                                seen.add(key)
                                problems.append(
                                    f"{c.path}: {c.where}: {prefix}no `words`; {deck_id} "
                                    f"is a B1 deck in the {drep.script} script, written "
                                    f"without spaces, so each target and example gives "
                                    f"its words in order (DECK-FORMAT.md, Base words)")
                            continue
                        have = {_key(b["word"]) for b in bases}
                        for w in dict.fromkeys(_split(text, words)):
                            k = _key(w)
                            if k in taught or k in have:
                                continue
                            key = (c.path, c.where, prefix, k, course)
                            if key in seen:
                                continue
                            seen.add(key)
                            problems.append(
                                f"{c.path}: {c.where}: {prefix}{w!r} is not a word the "
                                f"{course} course teaches as a card, and has no bases "
                                f"entry; add {{ word: \"{w}\", ref: ... }}, or "
                                f"{{ word: \"{w}\", base: ..., reading: ... }}")
    return problems


def warn_base_stems_across(reports: list[Report]) -> None:
    """Warns on a base whose word does not start with the letter its base
    does, ఇచ్చాడు (iccāḍu) on ఇవ్వడం (ivvaḍam), unless the card's notes, in
    its core or any layer, name the base: the stem has changed, and the
    learner is told which stem the form takes (DECK-FORMAT.md, "Base
    words"). A warning, not an error: a prefix or a sound change can move
    the first letter without a new stem. A pronoun's case forms are not a
    new stem either: তাৰ (tār) is a form of সি (xi), not সি on another stem, so
    a base that is a pronoun, a card of `pos: pronoun` or a lemma of a
    pronoun grammar deck, is left out (#480)."""
    ctx = _context(reports)
    for code in _languages(reports):
        lang = ctx.lang(code)
        tcards = lang.tcards()
        pronouns = {_key(t) for c in tcards.values() if c.pos == "pronoun"
                    for t in [c.target, *c.alt_targets]}
        pronouns.update(_key(lemma) for rep in lang.all()
                        if rep.deck_kind == "grammar" and "grammar-pronoun" in rep.path.stem
                        for lemma in rep.pattern_lemmas)
        texts: dict[str, list[str]] = {}
        for rep in lang.all():
            for cid, found in rep.note_texts.items():
                texts.setdefault(cid, []).extend(_key(t) for t in found)
        for rep in lang.given:
            for c in rep.cards:
                notes = texts.get(c.id, [])
                bases = [("", b) for b in c.bases] + [
                    (f"examples[{j}].", b) for j, _, bs in c.examples for b in bs]
                for prefix, base in bases:
                    word = base.get("word")
                    lemma = base.get("base")
                    if "ref" in base:
                        ref = tcards.get(base["ref"]) if _is_str(base["ref"]) else None
                        lemma = ref.target if ref is not None else None
                    if not _is_str(word) or not _is_str(lemma):
                        continue
                    w, stem = _key(word), _key(lemma)
                    if w[:1] == stem[:1] or stem in pronouns:
                        continue
                    if any(stem in t for t in notes):
                        continue
                    rep.warn(c.where, f"{prefix}bases: {word!r} does not start as its "
                                      f"base {lemma!r} does, and the card's notes do not "
                                      f"name {lemma!r}; say in the notes which stem the "
                                      f"form takes (DECK-FORMAT.md, \"Base words\")")


def warn_forms_across(reports: list[Report]) -> None:
    """Warns on a card's form that a rules table of its language has as a
    cell of the card's row: the table is the source of its forms (#517)."""
    ctx = _context(reports)
    for rep in reports:
        if not rep.card_forms or rep.lang_code is None:
            continue
        cells: dict[str, set[str]] = {}
        for other in ctx.lang(rep.lang_code).all():
            for word, forms in (other.table.forms if other.table else {}).items():
                cells.setdefault(word, set()).update(forms)
        for cid, where, place, word in rep.card_forms:
            if word in cells.get(cid, set()):
                rep.warn(where, f"{place}.word {word!r} is a cell of {cid}'s row in a "
                                f"rules table, the source of its forms")


def warn_alikes_across(reports: list[Report]) -> None:
    """Warns on a word that sounds or looks like an offensive word of its
    language, when no note names the pair (#629): the tool compares each
    word's IPA and spelling with the offensive words', and a reviewer keeps
    the real pairs, each with a note."""
    from offensive_alikes import load_words, unexplained, warning
    by_path = {rep.path.resolve(): rep for rep in reports}
    words = load_words(list(by_path))
    if not any(w.rude for w in words):
        return
    for alike in unexplained(words):
        rep = by_path.get(alike.word.path.resolve())
        if rep is not None:
            rep.warn(f"card {alike.word.id}", warning(alike))


def check_phrasebook_across(reports: list[Report]) -> list[str]:
    """A course's phrasebook: 15 to 25 cards, counted per course, and, where
    its path has a B1 plan, taught in the path's first unit."""
    ctx = _context(reports)
    given = {rep.path.resolve() for rep in reports}
    problems: list[str] = []
    courses: set[tuple[str, str]] = set()
    for rep in reports:
        if rep.plan is not None and rep.plan.has_plan:
            # One path, read by every course of its language (ADR-0036).
            courses.update((rep.plan.lang, n) for n in ctx.lang(rep.plan.lang).natives())
        elif rep.course_deck is not None and any(c.phrasebook for c in rep.merged + rep.cards):
            courses.add(rep.course_deck[:2])
    for code, native in sorted(courses):
        lang = ctx.lang(code)
        path = lang.path()
        has_plan = path is not None and path.plan.has_plan
        if not has_plan and not any(c.phrasebook for rep in lang.given
                                    for c in rep.merged + rep.cards) \
                and not _mentions(lang, "phrasebook"):
            continue
        decks = lang.decks(native)
        order = [lang.deck_for(native, d) for u in path.plan.units
                 for d in u.decks] if path is not None else []
        order += sorted(d for d in decks if d not in order)
        cards_of = {d: {c.id: c for c in lang.deck_cards(decks[d])}
                    for d in order if d in decks}
        phrasebook = list(dict.fromkeys(cid for d in order if d in cards_of
                                        for cid, c in cards_of[d].items() if c.phrasebook))
        n = len(phrasebook)
        if n == 0 and not has_plan:
            continue
        lo, hi = PHRASEBOOK_SIZE
        # A course with no written deck yet (a path, and perhaps its script
        # layer) is not held to the size: it has nothing to take cards from.
        alphabet = set(path.plan.alphabet) if path is not None else set()
        written = any(rep.deck_kind not in NOT_DECK_KINDS and rep.listed_as not in alphabet
                      for rep in decks.values())
        if written and not lo <= n <= hi:
            teaching = [d for d in order if d in cards_of
                        and any(c.phrasebook for c in cards_of[d].values())]
            file = path.path if path is not None and path.path.resolve() in given \
                else next((decks[d].path for d in teaching
                           if decks[d].path.resolve() in given), None)
            if file is not None:
                which = (teaching[0] + (f", and {len(teaching) - 1} more decks"
                                        if len(teaching) > 1 else "")) if teaching else "none"
                problems.append(f"{file}: phrasebook: the {code}-{native} course has {n} "
                                f"phrasebook cards; a course's phrasebook has {lo} to "
                                f"{hi} ({which})")
        if not has_plan or path.path.resolve() not in given:
            continue
        # The course's first unit: the first it has a deck in.
        first = next((u for u in path.plan.units if not u.exempt and any(
            lang.deck_for(native, d) in cards_of for d in u.decks)), None)
        if first is None:
            continue
        in_first = {cid for d in first.decks
                    for cid in cards_of.get(lang.deck_for(native, d), {})}
        for cid in phrasebook:
            if cid in in_first:
                continue
            for u in path.plan.units:
                d = next((lang.deck_for(native, d) for d in u.decks
                          if cid in cards_of.get(lang.deck_for(native, d), {})), None)
                if d is not None:
                    problems.append(f"{path.path}: units[{u.i}]: {d} teaches phrasebook "
                                    f"card {cid}; the phrasebook comes first, in a deck "
                                    f"of units[{first.i}]")
                    break
    return problems


def _mentions(lang: _Language, word: str) -> bool:
    """Whether a file of the language on disk mentions [word], read as text:
    so that a check with nothing to find reads no YAML."""
    for p in lang._on_disk("*.yaml") + lang._on_disk("*/*.yaml"):
        try:
            if word in p.read_text(encoding="utf-8"):
                return True
        except (OSError, UnicodeDecodeError):
            continue
    return False


def _unit_words(lang: _Language, u: Unit, plan: PathPlan,
                decks: dict[str, Report], native: str) -> int:
    """A unit's words for a course: the distinct cards that count as words,
    written or listed by ref in the course's decks for its core ids, its
    alphabet decks left out."""
    tcards = lang.tcards()
    ids: set[str] = set()
    for d in u.decks:
        drep = decks.get(lang.deck_for(native, d))
        if drep is None or d in plan.alphabet or drep.deck_kind != "vocab":
            continue
        if drep.part == "layer":
            cards = lang.deck_cards(drep)
        else:
            cards = list(drep.cards) + [tcards[rid] for rid, _, _ in drep.refs
                                        if rid in tcards]
        ids.update(c.id for c in cards if counts_as_word(c, "vocab"))
    return len(ids)


def check_plans_across(reports: list[Report]) -> list[str]:
    """A path's B1 plan against the decks: a planned deck not written yet,
    grammar topics a listed deck teaches, the plan required once the
    language has a core, and its sizes (warnings and an info line). The
    plan is the language's; each course's decks are read through their
    core ids (ADR-0036)."""
    ctx = _context(reports)
    problems: list[str] = []
    themes = [rep for rep in reports if rep.themes is not None]
    known = set(themes[0].themes) if themes else None
    for rep in reports:
        plan = rep.plan
        if plan is None:
            continue
        code = plan.lang
        lang = ctx.lang(code)
        if not plan.has_plan:
            core = lang.first_core()
            # A notation's course, the IPA's or braille's, is no language
            # taught towards a level: it has no B1 plan (ADR-0041, ADR-0043).
            if core is not None and not any(
                    d.script in NOTATION_SCRIPTS for d in lang.all()):
                problems.append(f"{rep.path}: units: {code} has core files ({core}), "
                                f"so its path needs its B1 plan: the milestones A1, A2 "
                                f"and B1, in that order")
            continue
        by_core = lang.by_core()
        for u in plan.units:
            pid = u.planned["id"] if u.planned is not None else None
            if pid is None:
                continue
            native = _course_of(lang, pid)
            if native is not None:
                problems.append(f"{rep.path}: units[{u.i}].planned.id: lists {pid!r}, a "
                                f"deck of the {code}-{native} course; a path lists core "
                                f"ids, here {code + '-' + pid[len(code) + len(native) + 2:]!r}")
                continue
            if pid in by_core:
                found = by_core[pid][0].path
                problems.append(f"{rep.path}: units[{u.i}].planned.id: {pid} already "
                                f"exists ({found}); list it under decks in place of "
                                f"planned")
        for u in plan.units:
            if u.planned is not None or not u.grammar or not u.decks:
                continue
            # The rules of the rules decks the unit lists, in the order
            # their core gives them; a layer knows its core's.
            rules: dict[str, list[str]] = {}
            for d in u.decks:
                for o in by_core.get(d, []):
                    ids = [rid for rid, _ in o.rules_defined] or o.core_rules
                    if ids and d not in rules:
                        rules[d] = list(ids)
            unseen = any(d not in by_core for d in u.decks)
            for t in u.grammar:
                if any(f"{code}-rule-{t}" in ids for ids in rules.values()):
                    continue
                named = f"{code}-grammar-{t}"
                if named in u.decks:
                    # A rules deck's topics are its rules, so its own name
                    # is none: the deck and its rules would count twice.
                    if named in rules:
                        names = ", ".join(repr(rid.removeprefix(f"{code}-rule-"))
                                          for rid in rules[named])
                        problems.append(f"{rep.path}: units[{u.i}].grammar: {t!r} names "
                                        f"the rules deck {named!r}; its topics are its "
                                        f"rules, {names}")
                    continue
                if unseen:
                    continue
                problems.append(f"{rep.path}: units[{u.i}].grammar: {t!r} is taught by "
                                f"none of the unit's decks; name a rule "
                                f"({code}-rule-{t}) of a rules deck it lists, or a "
                                f"deck {code}-grammar-{t} it lists")

        natives = lang.natives()
        for native in natives:
            for d, ui, drep in lang.b1_decks(native):
                if drep.part is None:
                    rep.warn(f"units[{ui}]", f"{d} is a single-file deck; a deck in a B1 "
                                             f"plan is split into a core and its layers "
                                             f"as the plan is written")
        for u in plan.units:
            if u.planned is not None or u.words is None or not u.decks:
                continue
            for native in natives:
                decks = lang.decks(native)
                if not any(lang.deck_for(native, d) in decks for d in u.decks):
                    continue
                n = _unit_words(lang, u, plan, decks, native)
                if n > u.words:
                    name = lang.native_name(native)
                    rep.warn(f"units[{u.i}]", f"has {n} words for learners from {name}, "
                                              f"more than the {u.words} planned; raise "
                                              f"words")
        for u in plan.units:
            for passage in u.passages:
                for native in natives:
                    if native not in passage.texts:
                        name = lang.native_name(native)
                        rep.warn(f"units[{u.i}].{passage.key}[{passage.j}]",
                                 f"no description in {name}, so learners from {name} "
                                 f"see none")
        level_words = plan.levels or LEVEL_WORDS
        if plan.levels:
            whole = sum(plan.levels.values())
            b1_total = (whole // 2, whole * 3 // 2)
        else:
            b1_total = B1_TOTAL
        total = sum(u.words or 0 for u in plan.units if u.i <= plan.end)
        if not b1_total[0] <= total <= b1_total[1]:
            rep.warn("units", f"plans {total} words up to B1, outside "
                              f"{b1_total[0]:,}–{b1_total[1]:,}; check the sizes")
        if known is not None:
            for u in plan.units:
                theme = u.planned["theme"] if u.planned is not None else None
                if theme is not None and theme not in known:
                    rep.warn(f"units[{u.i}].planned.theme", f"{theme!r} is not in "
                                                            f"decks/themes.yaml; add it "
                                                            f"before the deck is written")
        marks = plan.marks
        if set(marks) == set(MILESTONES):
            def words(after: int, upto: int) -> int:
                return sum(u.words or 0 for u in plan.units if after < u.i <= upto)
            sizes = {"A1": words(-1, marks["A1"]), "A2": words(marks["A1"], marks["A2"]),
                     "B1": words(marks["A2"], marks["B1"])}
            topics = {t for u in plan.units if u.i <= marks["B1"] for t in u.grammar}
            planned = sum(1 for u in plan.units if u.planned is not None)
            rep.info("units", f"B1 plan: A1 {sizes['A1']} words (about "
                              f"{level_words['A1']:,}), A2 +{sizes['A2']} (about "
                              f"{level_words['A2']:,}), B1 +{sizes['B1']} (about "
                              f"{level_words['B1']:,}); {sum(sizes.values())} in all; {len(topics)} "
                              f"grammar topics; {planned} units planned")
            for level, n in sizes.items():
                size = level_words[level]
                lo, hi = size // 2, size * 3 // 2
                if not lo <= n <= hi:
                    rep.warn("units", f"{level} plans {n} words, far from about "
                                      f"{size:,} ({lo:,}–{hi:,})")
    return problems


def check_regions_across(reports: list[Report]) -> list[str]:
    """Every region a note names is a region of its language's path, given
    or on disk (ADR-0036). A language with no path is not checked: it is
    told it has none."""
    ctx = _context(reports)
    problems: list[str] = []
    for rep in reports:
        if not rep.note_regions or rep.lang_code is None:
            continue
        path = ctx.lang(rep.lang_code).path()
        if path is None:
            continue
        known = path.plan.regions or []
        for region, where, i in rep.note_regions:
            if region not in known:
                problems.append(f"{rep.path}: {where}: notes[{i}].region names "
                                f"{region!r}, which is not a region of {rep.lang_code}; "
                                f"its path lists {', '.join(known) or 'none'}")
    return problems


def check_genders_across(reports: list[Report]) -> list[str]:
    """A noun's gender is one of its language's classes, which its path
    lists (#512, "Nouns only"); a noun with none is an error once the
    language is filled in. A language whose path lists no classes is not
    checked, and other parts of speech never are."""
    ctx = _context(reports)
    problems: list[str] = []
    for rep in reports:
        if not rep.noun_genders or rep.lang_code is None:
            continue
        path = ctx.lang(rep.lang_code).path()
        if path is None or path.plan.genders is None:
            continue
        code, classes = rep.lang_code, path.plan.genders
        listed = ", ".join(classes)
        for gender, where in rep.noun_genders:
            if gender is None:
                if classes and code in FILLED_LANGUAGES:
                    problems.append(f"{rep.path}: {where}: a noun has a gender once "
                                    f"{code} is filled in, one of {listed} "
                                    f"(DECK-FORMAT.md, Card data)")
            elif not classes:
                problems.append(f"{rep.path}: {where}: gender {gender!r}, but {code} "
                                f"has no gender classes; leave gender out")
            elif gender not in classes:
                problems.append(f"{rep.path}: {where}: gender {gender!r} is not a "
                                f"class of {code}; its path lists {listed}")
    return problems


# --- Deck kinds, levels, hidden decks, sources, creators, topics -------------
# wiki/Plan-Deck-Kinds-And-Topics.md (decisions D1 to D13). Every field is
# optional: a deck without `genre`, `level` or `hidden` is checked as before.

LEVELS = ("A1", "A2", "B1", "B2", "C1", "C2")
KIND_HEADER_KEYS = ("genre", "level", "hidden", "professional", "section", "weave",
                    "pattern_family")
# Where the plan's `shared` kinds live: decks/creators/<code>.yaml and
# decks/recommendations/<code>.yaml, one file per language and a stem that is
# only the language's code, so not unique among decks.
SHARED_DIRS = ("creators", "recommendations")

# D1: the one place a genre's rules are written. `kinds` the header `kind` it
# may have; `modes` the question types a card may carry (a genre only narrows
# the fixed set of #107, never adds to it); `pos` the parts of speech a card
# may have (None: any), `pos_required` whether a card must name one; `source`
# and `creator` whether every card needs them (a creator not for an anonymous
# author); `register` and `usage` what every card must carry; `review`
# whether the deck is tagged "unreviewed" or "reviewed".
GENRES: dict[str, dict] = {
    "culture": {"kinds": ("vocab", "reading"),
                "modes": frozenset({"recognition", "listening"}),
                "pos": frozenset({"phrase", "noun"}), "pos_required": False,
                "source": True, "creator": True, "register": False, "usage": False,
                "review": True},
    "proverbs": {"kinds": ("vocab",),
                 "modes": frozenset({"recognition", "listening"}),
                 "pos": frozenset({"phrase"}), "pos_required": True,
                 "source": True, "creator": False, "register": True, "usage": False,
                 "review": False},
    "multiword": {"kinds": ("vocab", "grammar"),
                  "modes": frozenset({"recognition", "production", "listening",
                                      "grammar"}),
                  "pos": None, "pos_required": False,
                  "source": False, "creator": False, "register": False, "usage": True,
                  "review": False},
    "professional": {"kinds": ("vocab", "reading"),
                     "modes": frozenset({"recognition", "production", "listening"}),
                     "pos": None, "pos_required": False,
                     "source": False, "creator": False, "register": False, "usage": False,
                     "review": True},
}

# D4: the rights basis of a source block, and what each one needs.
SOURCE_BASES = ("public-domain", "licensed", "quotation", "oral-tradition")
SOURCE_KEYS = {"author", "work", "collection", "region", "date", "edition", "url",
               "basis", "author_died", "jurisdiction", "licence", "licence_url",
               "rights_checked"}
# No NC, no ND: a card is copied and adapted under CC-BY-SA-4.0.
FREE_LICENCES = ("CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0")
IMAGE_LICENCES = ("public-domain",) + FREE_LICENCES
QUOTATION_WORDS = 25
QUOTATION_CARDS = 5
# The mechanical public-domain floor (D4, rule 3): years after an author's
# death, by jurisdiction (ISO 3166-1 alpha-2). It catches typos; it is not a
# legal opinion, which the reviewer owns. Owner question 7 confirms the table.
PD_TERMS = {"IN": 60, "BD": 60, "ES": 70, "FR": 70, "JP": 70, "CN": 50}
PD_DEFAULT_TERM = 70
# An anonymous work: years after its publication.
PD_ANONYMOUS_TERM = 70
# Rule 3's alternative for an anonymous work: published before this year.
PD_ANONYMOUS_BEFORE = 1900

LEGACY_KINDS = ("curriculum", "festival", "film", "music", "saying", "commemoration",
                "adaptation", "place", "other")
LEGACY_WORDS = 60
RELATIONS = ("adaptation", "influence", "response", "echo")
MEDIA_KINDS = ("book", "film", "series", "song", "play", "podcast", "comic")
LEGAL_KINDS = ("library", "publisher", "store", "stream", "archive", "public-domain")
SEARCH_ROWS = ("scene", "topic", "deck", "concept", "card", "unit")
TOPIC_KINDS = ("grammar", "verbs", "words", "script", "register", "profession", "other")
IMAGE_MAX_BYTES = 300 * 1024
IMAGE_MAX_SIDE = 1024
SHARED_MAX_BYTES = 512 * 1024
MAX_CHARS_LEN = 12
PIRATE_HOSTS = Path(__file__).resolve().parent / "pirate_hosts.txt"


def _today() -> datetime.date:
    """Today; the tests replace it."""
    return datetime.date.today()


def pd_term(jurisdiction: object) -> int:
    """Years after an author's death that a work stays protected in
    [jurisdiction], by the floor's table."""
    return PD_TERMS.get(jurisdiction, PD_DEFAULT_TERM) if isinstance(jurisdiction, str) \
        else PD_DEFAULT_TERM


def parse_years(value: object) -> tuple[int, int] | None:
    """A source's `date`: a year (1892), a span ("1892-1909"), or "c. 1750",
    as its first and last year; None for anything else."""
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return (value, value) if 1 <= value <= 9999 else None
    if isinstance(value, str):
        m = re.fullmatch(r"(?:c\.\s?)?([0-9]{3,4})(?:-([0-9]{3,4}))?", value.strip())
        if m:
            first = int(m.group(1))
            last = int(m.group(2)) if m.group(2) else first
            return (first, last) if first <= last else None
    return None


def public_domain_problem(source: dict, *, today: datetime.date | None = None) -> str | None:
    """Why a `basis: public-domain` source fails the mechanical floor, or
    None: died + term < this year, or an anonymous work first published
    before 1900 and more than 70 years ago."""
    year = (today or _today()).year
    years = parse_years(source.get("date"))
    died = source.get("author_died")
    if isinstance(died, int) and not isinstance(died, bool):
        term = pd_term(source.get("jurisdiction"))
        if died + term >= year:
            return (f"author_died {died} + {term} years (the term in "
                    f"{source.get('jurisdiction')!r}) is not before {year}: the work "
                    f"may still be protected")
        return None
    if source.get("author") == "anonymous":
        if years is None or years[0] >= PD_ANONYMOUS_BEFORE:
            return (f"an anonymous work is public domain only when published before "
                    f"{PD_ANONYMOUS_BEFORE}; its date is {source.get('date')!r}")
        if years[1] + PD_ANONYMOUS_TERM >= year:
            return (f"published {years[1]} + {PD_ANONYMOUS_TERM} years is not before "
                    f"{year}: the work may still be protected")
        return None
    return "public-domain needs author_died (a year), or author: \"anonymous\" and a date before 1900"


def _iso_date(value: object) -> datetime.date | None:
    if isinstance(value, datetime.date) and not isinstance(value, datetime.datetime):
        return value
    if isinstance(value, str) and DATE_RE.fullmatch(value):
        try:
            return datetime.date.fromisoformat(value)
        except ValueError:
            return None
    return None


def _year_of(value: object) -> tuple[int | None, bool]:
    """A creator's `born` or `died`: a year (negative for BCE), or
    `{ year, circa: true }`. Returns (the year or None, whether it is circa)."""
    if isinstance(value, bool):
        return None, False
    if isinstance(value, int):
        return value, False
    if isinstance(value, dict) and set(value) <= {"year", "circa"} \
            and isinstance(value.get("year"), int) and not isinstance(value["year"], bool) \
            and (value.get("circa") is True or "circa" not in value):
        return value["year"], value.get("circa") is True
    return None, False


def _https(url: object) -> bool:
    if not isinstance(url, str):
        return False
    parts = urlparse(url)
    return parts.scheme == "https" and bool(parts.netloc) and " " not in url


# Scripts whose text needs a reading beside it (not Latin, Cyrillic or Greek).
_NEEDS_READING = re.compile("[\u0900-\u0dff\u0590-\u06ff\u0e00-\u0e7f\u3040-\u30ff"
                            "\u4e00-\u9fff\uac00-\ud7af]")


def _text_entry(r: Report, where: str, value: object) -> None:
    """A name or a title: `{ text, reading?, ipa? }`. A text in a script that
    is not Latin needs its reading (the rule of every card)."""
    if not isinstance(value, dict) or set(value) - {"text", "reading", "ipa"}:
        r.error(where, "must be a mapping with text, and optionally reading and ipa")
        return
    text = value.get("text")
    if not _is_str(text):
        r.error(where, "text is required and must be non-empty text")
        return
    for key in ("reading", "ipa"):
        if key in value and not _is_str(value[key]):
            r.error(where, f"{key} must be non-empty text, or left out")
    if _NEEDS_READING.search(text) and not _is_str(value.get("reading")):
        r.error(where, f"{text!r} is in a script other than Latin and needs its reading")


def _by_language(r: Report, where: str, value: object, *,
                 max_words: int | None = None) -> None:
    """Text keyed by language code, English required."""
    _check_by_language(r, where, "text", value)
    if max_words is not None and isinstance(value, dict):
        for code, text in value.items():
            if _is_str(text) and len(text.split()) > max_words:
                r.error(where, f"{code} text is {len(text.split())} words; at most "
                               f"{max_words}")


def _levels_ok(r: Report, where: str, level: object, deck_level: str | None) -> str | None:
    """A card's or passage's `level`: valid, and not below the deck's."""
    if level not in LEVELS:
        r.error(where, f"level must be one of {', '.join(LEVELS)}, got {level!r}")
        return None
    if deck_level is not None and LEVELS.index(level) < LEVELS.index(deck_level):
        r.error(where, f"level {level} is below the deck's {deck_level}: a card is "
                       f"never easier than its deck")
    return level


def _check_date_field(r: Report, where: str, key: str, value: object) -> datetime.date | None:
    """A date written YYYY-MM-DD, not in the future."""
    d = _iso_date(value)
    if d is None:
        r.error(where, f"{key} must be a date written YYYY-MM-DD, got {value!r}")
    elif d > _today():
        r.error(where, f"{key} {value} is in the future")
        return None
    return d


def check_source_block(r: Report, where: str, source: object, *, genre: str | None,
                       target: str | None = None, script: str = "") -> dict | None:
    """A culture or proverb card's `source` block (D4, rules 1 to 8). Returns
    {author, years, basis} for the checks across files, or None when it is
    not a mapping."""
    p = f"{where}.source"
    if not isinstance(source, dict):
        r.error(where, "source must be a mapping with author, work, date, basis, "
                       "jurisdiction, rights_checked and an edition or url "
                       "(wiki/Plan-Deck-Kinds-And-Topics.md, D4)")
        return None
    for unknown in sorted(set(source) - SOURCE_KEYS, key=str):
        r.error(p, f"unknown field {unknown!r}")
    basis = source.get("basis")
    if basis not in SOURCE_BASES:
        r.error(p, f"basis must be one of {', '.join(SOURCE_BASES)}, got {basis!r}")
        basis = None
    for key in ("author", "date", "jurisdiction", "rights_checked"):
        if key not in source:
            r.error(p, f"{key} is required")
    for key in ("author", "work", "collection", "region", "edition", "licence",
                "licence_url"):
        if key in source and not _is_str(source[key]):
            r.error(p, f"{key} must be non-empty text, got {source[key]!r}")
    author = source.get("author")
    anonymous = author == "anonymous"
    if basis == "oral-tradition":
        if not (_is_str(source.get("collection")) or _is_str(source.get("region"))):
            r.error(p, "an oral-tradition source names its collection or region")
        if genre != "proverbs" and not anonymous:
            r.error(p, "basis oral-tradition is for proverbs, or a folk item with "
                       'author: "anonymous"')
    else:
        if genre == "culture" and not _is_str(source.get("work")):
            r.error(p, "work is required on a culture card")
        elif not (_is_str(source.get("work")) or _is_str(source.get("collection"))):
            r.error(p, "work (or collection, for a proverb) is required")
    if "edition" not in source and "url" not in source:
        r.error(p, "needs an edition or a url, so the text can be checked")
    if "url" in source and not _https(source["url"]):
        r.error(p, f"url must be an https link, got {source['url']!r}")
    years = parse_years(source.get("date")) if "date" in source else None
    if "date" in source and years is None:
        r.error(p, f"date must be a year, a span like \"1892-1909\", or \"c. 1750\", "
                   f"got {source['date']!r}")
    if "jurisdiction" in source and not (
            isinstance(source["jurisdiction"], str)
            and re.fullmatch(r"[A-Z]{2}", source["jurisdiction"])):
        r.error(p, f"jurisdiction must be an ISO 3166-1 alpha-2 code such as \"IN\", "
                   f"got {source['jurisdiction']!r}")
    checked = None
    if "rights_checked" in source:
        checked = _check_date_field(r, p, "rights_checked", source["rights_checked"])
    if checked is not None and years is not None and years[1] > checked.year:
        r.error(p, f"date {source.get('date')!r} is after rights_checked "
                   f"{source['rights_checked']}")
    died = source.get("author_died")
    if "author_died" in source and (isinstance(died, bool) or not isinstance(died, int)
                                    or died > _today().year):
        r.error(p, f"author_died must be a year, got {died!r}")
    if basis == "public-domain":
        problem = public_domain_problem(source)
        if problem is not None:
            r.error(p, problem)
    elif basis == "licensed":
        if source.get("licence") not in FREE_LICENCES:
            r.error(p, f"a licensed source needs licence, one of "
                       f"{', '.join(FREE_LICENCES)} (no NC, no ND), got "
                       f"{source.get('licence')!r}")
        if not _https(source.get("licence_url")):
            r.error(p, "a licensed source needs licence_url, an https link to the licence")
    elif basis == "quotation":
        if not _is_str(source.get("licence")):
            r.error(p, "a quotation names the exception that allows it in licence, "
                       'such as "short quotation, Berne Convention art. 10(1)"')
        if target is not None:
            count = len(target) if script in NO_SPACES else len(target.split())
            if count > QUOTATION_WORDS:
                r.error(where, f"a quotation is at most {QUOTATION_WORDS} words; this "
                               f"is {count}: leave it out")
    return {"author": author, "years": years, "basis": basis}


def check_legacy(r: Report, where: str, legacy: object) -> None:
    """A creator's or a work's `legacy` (D5b): a short text, optionally by
    level, and one to six checkable items, each with a source."""
    p = f"{where}.legacy"
    if not isinstance(legacy, dict) or set(legacy) - {"text", "text_target", "items"}:
        r.error(where, "legacy must be a mapping with text, items and optionally "
                       "text_target")
        return
    if "text" in legacy:
        _by_language(r, p + ".text", legacy["text"], max_words=LEGACY_WORDS)
    target = legacy.get("text_target")
    if target is not None:
        if not isinstance(target, dict):
            r.error(p, "text_target must map a level to { text, reading, ipa }")
        else:
            for level, entry in target.items():
                if level not in ("A1", "A2", "B1"):
                    r.error(p, f"text_target level {level!r} must be A1, A2 or B1")
                _text_entry(r, f"{p}.text_target.{level}", entry)
    items = legacy.get("items")
    if not isinstance(items, list) or not 1 <= len(items) <= 6:
        r.error(p, "items is required: one to six concrete, checkable examples "
                   "(a summary alone is not enough)")
        return
    for i, item in enumerate(items):
        w = f"{p}.items[{i}]"
        if not isinstance(item, dict) or set(item) - {"kind", "text", "year", "source"}:
            r.error(w, "must be a mapping with kind, text, source and optionally year")
            continue
        if item.get("kind") not in LEGACY_KINDS:
            r.error(w, f"kind must be one of {', '.join(LEGACY_KINDS)}, got "
                       f"{item.get('kind')!r}")
        _by_language(r, w + ".text", item.get("text"))
        year = item.get("year")
        if "year" in item and (isinstance(year, bool) or not isinstance(year, int)
                               or year > _today().year):
            r.error(w, f"year must be a year, no later than this one, got {year!r}")
        src = item.get("source")
        if not isinstance(src, dict) or set(src) - {"url", "work", "accessed", "date"}:
            r.error(w, "source must be a mapping with an https url or a work, and "
                       "accessed or date")
            continue
        if "url" in src and not _https(src["url"]):
            r.error(w, f"source.url must be an https link, got {src['url']!r}")
        if "url" not in src and not _is_str(src.get("work")):
            r.error(w, "source needs an https url or a work: a claim without a "
                       "source fails")
        if "accessed" in src:
            _check_date_field(r, w + ".source", "accessed", src["accessed"])
        elif "date" in src:
            if not (parse_years(src["date"]) or _iso_date(src["date"])):
                r.error(w, f"source.date must be a year or YYYY-MM-DD, got {src['date']!r}")
        else:
            r.error(w, "source needs accessed (the day the link was read) or date")


def _creator_ids(r: Report, where: str, value: object, lang: str | None) -> list[str]:
    """A card's `creator`: one creator id, or a list of them."""
    ids = [value] if isinstance(value, str) else value
    pattern = re.compile(rf"{re.escape(lang)}-[a-z0-9]+(?:-[a-z0-9]+)*") if lang else None
    if not isinstance(ids, list) or not ids or not all(
            _is_str(i) and (pattern is None or pattern.fullmatch(i)) for i in ids):
        r.error(where, f"creator must be a creator id of the language, "
                       f"{lang or '<language>'}- and a name, or a list of them, got "
                       f"{value!r}")
        return []
    if len(set(ids)) != len(ids):
        r.error(where, "creator names an id twice")
    return list(dict.fromkeys(ids))


def check_kind_header(r: Report, raw: dict, kind: str | None) -> None:
    """A deck's `genre`, `level`, `hidden`, `professional`, `section`, `weave`
    and `pattern_family` (D1 to D3, D7), then its cards' and passages' kinds
    fields. Called for a single-file deck and for a core; a layer has none."""
    genre = raw.get("genre") if "genre" in raw else None
    spec = None
    if "genre" in raw:
        if not _is_str(genre) or genre not in GENRES:
            r.error("genre", f"must be one of {', '.join(sorted(GENRES))}, got {genre!r}")
        else:
            spec = GENRES[genre]
            r.genre = genre
    deck_level = None
    if "level" in raw:
        if raw["level"] in LEVELS:
            deck_level = r.level = raw["level"]
        else:
            r.error("level", f"must be one of {', '.join(LEVELS)}, got {raw['level']!r}")
    for key in ("hidden", "weave"):
        if key in raw and not isinstance(raw[key], bool):
            r.error(key, f"must be true or false, unquoted, got {raw[key]!r}")
    r.hidden = raw.get("hidden") is True
    r.weave = raw["weave"] if isinstance(raw.get("weave"), bool) else None
    for key in ("professional", "section", "pattern_family"):
        if key in raw and not (_is_str(raw[key]) and ID_RE.fullmatch(raw[key])):
            r.error(key, f"must match [a-z0-9-]+, got {raw[key]!r}")
    if _is_str(raw.get("professional")) and ID_RE.fullmatch(raw["professional"]):
        r.professional = raw["professional"]
    if _is_str(raw.get("section")) and ID_RE.fullmatch(raw["section"]):
        r.section = raw["section"]
    tags = raw.get("tags") if isinstance(raw.get("tags"), list) else []
    r.reviewed = "reviewed" in tags and "unreviewed" not in tags
    if "pattern_family" in raw and genre != "multiword":
        r.error("pattern_family", "only a multiword deck has a pattern_family")
    if "professional" in raw and genre != "professional":
        r.error("professional", "only a professional deck names a profession "
                                "(genre: \"professional\")")
    if spec is not None:
        if kind is not None and kind not in spec["kinds"]:
            r.error("kind", f"a {genre} deck is {' or '.join(spec['kinds'])}, got {kind!r}")
        if "level" not in raw:
            r.error("level", f"is required on a {genre} deck")
        if genre == "professional":
            if "professional" not in raw:
                r.error("professional", "a professional deck names its profession, a "
                                        "profession id of decks/sections.yaml")
            if raw.get("hidden") is not True:
                r.error("hidden", "a professional deck is hidden: true")
        if spec["review"] and not r.culture and (
                ("reviewed" in tags) == ("unreviewed" in tags)):
            r.error("tags", f'a {genre} deck is tagged "unreviewed" until a reviewer '
                            f'checks it, then "reviewed": exactly one of them')
    _check_character(r, raw)
    _check_kind_cards(r, raw, spec, genre, deck_level, kind)


# A deck of single characters (a script deck) may give each card structured
# data about its character (#1226): the readings it has by kind, its level in
# a named scheme, its strokes and its radical. What the kinds and schemes are
# is the deck's own data, `character_scheme` in its header, so no language and
# no script is named here.
CHARACTER_SCHEME_KEYS = {"readings", "levels"}
CHARACTER_KIND_KEYS = {"name", "script"}
CHARACTER_LEVEL_KEYS = {"name", "values"}
CHARACTER_KEYS = {"readings", "level", "strokes", "radical"}
CHARACTER_READING_KEYS = {"kind", "text", "reading"}
MAX_STROKES = 64
# The app version that first reads each card field below; a file that uses one
# is put behind it in the index (ADR-0052), because a released app refuses a
# card field it does not know. Raise it to the real number if the release that
# holds the parser is not this one.
CARD_FIELD_MIN_APP = {"character": "0.10.2"}


def _scheme_entries(r: Report, raw: object, key: str, keys: set[str],
                    need_script: bool) -> dict[str, dict]:
    """The valid entries of one `character_scheme` map, by id."""
    where = f"character_scheme.{key}"
    if not isinstance(raw, dict) or not raw:
        r.error(where, "must be a mapping of ids to their definitions")
        return {}
    found: dict[str, dict] = {}
    for kid, entry in raw.items():
        w = f"{where}.{kid}"
        if not (_is_str(kid) and ID_RE.fullmatch(kid)):
            r.error(where, f"id {kid!r} must match [a-z0-9-]+")
            continue
        if not isinstance(entry, dict):
            r.error(w, "must be a mapping")
            continue
        for unknown in sorted(set(entry) - keys, key=str):
            r.error(w, f"unknown field {unknown!r}")
        _check_by_language(r, w, "name", entry.get("name"))
        if need_script:
            script = entry.get("script")
            if not (_is_str(script) and SCRIPT_RE.fullmatch(script)):
                r.error(w, f"script must be a script id such as 'latin', got {script!r}")
                continue
        else:
            values = entry.get("values")
            if values is not None:
                if not isinstance(values, list) or not values:
                    r.error(w, "values must be a non-empty list, or left out")
                    continue
                texts = []
                for v in values:
                    if isinstance(v, bool) or not (isinstance(v, int) or _is_str(v)):
                        r.error(w, f"a value is a whole number or text, got {v!r}")
                    texts.append(str(v))
                if len(set(texts)) != len(texts):
                    r.error(w, "values lists a value twice")
        found[kid] = entry
    return found


def _check_character(r: Report, raw: dict) -> None:
    """A deck's `character_scheme` and its cards' `character` blocks (#1226).
    Only a core or a single-file deck has them; a layer's are refused as
    unknown fields."""
    scheme = raw.get("character_scheme")
    kinds: dict[str, dict] = {}
    levels: dict[str, dict] = {}
    if "character_scheme" in raw:
        r.new_fields.add("character")
        if not isinstance(scheme, dict) or not scheme:
            r.error("character_scheme", "must be a mapping with readings and/or levels")
        else:
            for unknown in sorted(set(scheme) - CHARACTER_SCHEME_KEYS, key=str):
                r.error("character_scheme", f"unknown field {unknown!r}")
            if "readings" in scheme:
                kinds = _scheme_entries(r, scheme["readings"], "readings",
                                        CHARACTER_KIND_KEYS, need_script=True)
            if "levels" in scheme:
                levels = _scheme_entries(r, scheme["levels"], "levels",
                                         CHARACTER_LEVEL_KEYS, need_script=False)
            if not scheme.keys() & CHARACTER_SCHEME_KEYS:
                r.error("character_scheme", "names no readings and no levels")
    cards = raw.get("cards")
    if not isinstance(cards, list):
        return
    for i, card in enumerate(cards):
        if not isinstance(card, dict) or "character" not in card:
            continue
        where = f"cards[{i}].character"
        r.new_fields.add("character")
        block = card["character"]
        if "character_scheme" not in raw:
            r.error(where, "the deck's header needs a character_scheme naming the "
                           "reading kinds and level schemes the block uses")
        if card.get("pos") not in SCRIPT_POS:
            r.error(where, f"is for a card of a script deck, pos one of "
                           f"{sorted(SCRIPT_POS)}, got {card.get('pos')!r}")
        if not isinstance(block, dict) or not block:
            r.error(where, "must be a mapping with readings, level, strokes or radical")
            continue
        for unknown in sorted(set(block) - CHARACTER_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        if "readings" in block:
            _check_character_readings(r, where, block["readings"], kinds)
        if "level" in block:
            _check_character_level(r, where, block["level"], levels)
        if "strokes" in block:
            strokes = block["strokes"]
            if isinstance(strokes, bool) or not isinstance(strokes, int) \
                    or not 1 <= strokes <= MAX_STROKES:
                r.error(where, f"strokes must be a whole number from 1 to {MAX_STROKES}, "
                               f"got {strokes!r}")
        if "radical" in block:
            radical = block["radical"]
            if not _is_str(radical) or radical != unicodedata.normalize("NFC", radical) \
                    or len(radical) != 1:
                r.error(where, f"radical must be one character (one code point), "
                               f"got {radical!r}")


def _check_character_readings(r: Report, where: str, value: object,
                              kinds: dict[str, dict]) -> None:
    where = f"{where}.readings"
    if not isinstance(value, list) or not value:
        r.error(where, "must be a non-empty list of { kind, text, reading? }")
        return
    seen: set[tuple[object, object]] = set()
    for k, item in enumerate(value):
        w = f"{where}[{k}]"
        if not isinstance(item, dict):
            r.error(w, "must be a mapping with kind and text")
            continue
        for unknown in sorted(set(item) - CHARACTER_READING_KEYS, key=str):
            r.error(w, f"unknown field {unknown!r}")
        kind, text = item.get("kind"), item.get("text")
        if not _is_str(kind) or kind not in kinds:
            r.error(w, f"kind {kind!r} is not a reading kind of the deck's "
                       f"character_scheme ({', '.join(sorted(kinds)) or 'none'})")
        if not _is_str(text) or text != text.strip():
            r.error(w, f"text must be the reading, text without spaces around it, "
                       f"got {text!r}")
        elif kind in kinds:
            script = kinds[kind].get("script")
            blocks = SCRIPT_BLOCKS.get(script) if _is_str(script) else None
            if blocks and not _letters_in(text, blocks):
                r.error(w, f"text {text!r} has letters that are not in the script "
                           f"{script!r} of the kind {kind!r}")
        if "reading" in item and not _is_str(item["reading"]):
            r.error(w, "reading must be non-empty text, or left out")
        if (kind, text) in seen:
            r.error(w, f"the {kind!r} reading {text!r} is listed twice")
        seen.add((kind, text))


def _check_character_level(r: Report, where: str, value: object,
                           levels: dict[str, dict]) -> None:
    where = f"{where}.level"
    if not isinstance(value, dict) or not value:
        r.error(where, "must be a mapping of scheme to value, such as { grade: 1 }")
        return
    for scheme, level in value.items():
        if not _is_str(scheme) or scheme not in levels:
            r.error(where, f"scheme {scheme!r} is not a level scheme of the deck's "
                           f"character_scheme ({', '.join(sorted(levels)) or 'none'})")
            continue
        if isinstance(level, bool) or not (isinstance(level, int) or _is_str(level)):
            r.error(where, f"{scheme} must be a whole number or text, got {level!r}")
            continue
        allowed = levels[scheme].get("values")
        if isinstance(allowed, list) and str(level) not in {str(v) for v in allowed}:
            r.error(where, f"{scheme} {level!r} is not one of its values "
                           f"({', '.join(str(v) for v in allowed)})")


def _check_kind_cards(r: Report, raw: dict, spec: dict | None, genre: str | None,
                      deck_level: str | None, kind: str | None) -> None:
    lang = r.lang_code
    script = r.script or ""
    cards = raw.get("cards")
    quotations = 0
    items: list[tuple[str, dict, bool, str | None]] = []
    if isinstance(cards, list):
        for i, card in enumerate(cards):
            if not isinstance(card, dict) or _is_set(card):
                continue
            cid = card.get("ref") if "ref" in card else card.get("id")
            where = f"card {cid}" if _is_str(cid) else f"cards[{i}]"
            items.append((where, card, "ref" in card,
                          card.get("target") if _is_str(card.get("target")) else None))
    passages = raw.get("passages")
    if isinstance(passages, list) and kind == "reading":
        for i, passage in enumerate(passages):
            if isinstance(passage, dict):
                pid = passage.get("id")
                sentences = passage.get("sentences")
                text = " ".join(s["text"] for s in sentences
                                if isinstance(s, dict) and _is_str(s.get("text"))) \
                    if isinstance(sentences, list) else None
                items.append((f"passage {pid}" if _is_str(pid) else f"passages[{i}]",
                              passage, False, text))
    for where, card, is_ref, target in items:
        if "modes" in card and spec is not None and isinstance(card["modes"], list):
            for m in card["modes"]:
                if isinstance(m, str) and m in MODES and m not in spec["modes"]:
                    r.error(where, f"mode {m!r} is not allowed on a {genre} card "
                                   f"({', '.join(sorted(spec['modes']))})")
        if is_ref:
            continue
        if "level" in card:
            _levels_ok(r, where, card["level"], deck_level)
        pos = card.get("pos")
        if spec is not None and spec["pos"] is not None and (
                "pos" in card or (spec["pos_required"] and kind == "vocab")):
            if pos not in spec["pos"]:
                r.error(where, f"pos must be {' or '.join(sorted(spec['pos']))} on a "
                               f"{genre} card, got {pos!r}")
        if spec is not None and spec["register"] and "register" not in card:
            r.error(where, f"a {genre} card has a register ({', '.join(REGISTERS)})")
        if spec is not None and spec["usage"]:
            notes = card.get("notes")
            if not (isinstance(notes, list) and any(
                    isinstance(n, dict) and n.get("kind") == "usage" for n in notes)):
                r.error(where, f"a {genre} card has a note of kind usage (separable "
                               f"or not, which particle or case follows)")
        info = None
        # A passage's `source` is still text in an ordinary deck: only a
        # mapping is a block.
        has_block = "source" in card and (
            not where.startswith("passage") or isinstance(card["source"], dict))
        if has_block or (spec is not None and spec["source"]):
            if not has_block:
                r.error(where, f"a {genre} card has a source block (D4)")
            else:
                info = check_source_block(r, where, card["source"], genre=genre,
                                          target=target, script=script)
                if info is not None and info["basis"] == "quotation":
                    quotations += 1
        if "legacy" in card:
            check_legacy(r, where, card["legacy"])
        author = info["author"] if info is not None else None
        if "creator" in card:
            ids = _creator_ids(r, where + ".creator", card["creator"], lang)
            if author == "anonymous":
                r.error(where, 'an anonymous source has no creator')
            elif ids:
                r.creator_refs.append((ids, where, author,
                                       info["years"][0] if info and info["years"] else None))
        elif spec is not None and spec["creator"] and author != "anonymous":
            r.error(where, f"a {genre} card names its creator by id (creator: "
                           f'"<language>-<name>"), unless its author is "anonymous"')
    if quotations > QUOTATION_CARDS:
        r.error("cards", f"{quotations} quotation cards; at most {QUOTATION_CARDS} per deck")


def check_reviewed_cards(r: Report, raw: object, checks: list) -> None:
    """D4, rule 9: a culture or proverbs deck tagged `reviewed` has every
    written card signed off with `checked_by`."""
    if not isinstance(raw, dict) or raw.get("kind") == "layer" \
            or r.genre not in ("culture", "proverbs") or not r.reviewed:
        return
    signed = {c.where for c in checks if c.key == "checked_by"}
    for where, cid, entry in _card_entries(raw):
        if "ref" not in entry and entry.get("kind") != "set" and where not in signed:
            r.error(where, f"card {cid}: the deck is tagged reviewed, so every card "
                           f"needs checked_by")


# --- decks/sections.yaml (D8) ------------------------------------------------

SECTIONS_KEYS = {"schema", "kind", "sections", "genres", "professions", "search_kinds"}


def _id_list(r: Report, raw: dict, key: str, entry_keys: set[str]) -> dict[str, dict]:
    """A list of mappings with an `id` and a `name` by language, each id once."""
    found: dict[str, dict] = {}
    value = raw.get(key)
    if key == "professions" and value is None:
        return found
    if not isinstance(value, list) or (not value and key != "professions"):
        r.error(key, "must be a non-empty list")
        return found
    for i, entry in enumerate(value):
        where = f"{key}[{i}]"
        if not isinstance(entry, dict):
            r.error(where, "must be a mapping")
            continue
        for unknown in sorted(set(entry) - entry_keys, key=str):
            r.error(where, f"unknown field {unknown!r}")
        eid = entry.get("id")
        if not _is_str(eid) or not ID_RE.fullmatch(eid):
            r.error(where, f"id must match [a-z0-9-]+, got {eid!r}")
            continue
        where = f"{key} {eid}"
        if eid in found:
            r.error(where, "is listed twice")
        found[eid] = entry
        _check_by_language(r, where, "name", entry.get("name"))
    return found


def check_sections_file(r: Report, raw: dict, path: Path) -> None:
    """decks/sections.yaml: the Decks tab's sections, the genres, the
    professions and the search kinds, as data (D8)."""
    for unknown in sorted(set(raw) - SECTIONS_KEYS, key=str):
        r.error("root", f"unknown field {unknown!r} in a sections file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    if path.stem != "sections":
        r.error("root", f"a sections file is decks/sections.yaml, got {path.name!r}")
    try:
        if path.stat().st_size > SHARED_MAX_BYTES:
            r.error("root", f"is over {SHARED_MAX_BYTES // 1024} KB, which the app "
                            f"refuses for a shared file")
    except OSError:
        pass
    sections = _id_list(r, raw, "sections", {"id", "name", "listed"})
    for sid, s in sections.items():
        if "listed" in s and not isinstance(s["listed"], bool):
            r.error(f"sections {sid}", "listed must be true or false")
    genres = _id_list(r, raw, "genres", {"id", "name", "section", "search_kind", "weave"})
    professions = _id_list(r, raw, "professions", {"id", "name"})
    kinds = _id_list(r, raw, "search_kinds", {"id", "name", "row", "order"})
    orders: set[object] = set()
    for kid, k in kinds.items():
        where = f"search_kinds {kid}"
        if k.get("row") not in SEARCH_ROWS:
            r.error(where, f"row must be one of {', '.join(SEARCH_ROWS)}, got "
                           f"{k.get('row')!r}")
        order = k.get("order")
        if isinstance(order, bool) or not isinstance(order, int):
            r.error(where, f"order must be a whole number, got {order!r}")
        elif order in orders:
            r.error(where, f"order {order} is used twice")
        else:
            orders.add(order)
    for gid, g in genres.items():
        where = f"genres {gid}"
        if g.get("section") not in sections:
            r.error(where, f"section {g.get('section')!r} is not a section of the file")
        if g.get("search_kind") not in kinds:
            r.error(where, f"search_kind {g.get('search_kind')!r} is not a search kind "
                           f"of the file")
        if "weave" in g and not isinstance(g["weave"], bool):
            r.error(where, "weave must be true or false")
        if gid not in GENRES:
            r.error(where, f"{gid!r} is not a genre the validator knows "
                           f"({', '.join(sorted(GENRES))}); add it to GENRES in "
                           f"tools/validate_decks.py too")
    for gid in GENRES:
        if gid not in genres:
            r.error("genres", f"does not list {gid!r}, a genre the validator knows")
    r.sections_data = {"sections": set(sections), "genres": set(genres),
                       "professions": set(professions), "search_kinds": set(kinds)}


# --- decks/creators/<code>.yaml (D5, D5b) ------------------------------------

CREATORS_KEYS = {"schema", "kind", "id", "language", "license", "eras", "creators"}
CREATOR_KEYS = {"id", "name", "born", "died", "living", "era", "region", "bio",
                "bio_target", "image", "legacy", "related", "checked_by"}
IMAGE_KEYS = {"file", "credit", "author", "licence", "licence_url", "source_url",
              "retrieved"}
MAX_LIFESPAN = 120
ERA_SLACK = 50
IMAGE_EXTS = (".jpg", ".png", ".webp")


def image_size(data: bytes) -> tuple[int, int] | None:
    """The width and height of a PNG, JPEG or WebP, read from its header; None
    when it is none of them or cannot be read."""
    try:
        if data[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", data[16:24])
        if data[:3] == b"\xff\xd8\xff":
            i = 2
            while i + 9 < len(data):
                if data[i] != 0xFF:
                    i += 1
                    continue
                marker = data[i + 1]
                if marker == 0xFF:
                    i += 1
                elif marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
                    i += 2
                elif 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
                    height, width = struct.unpack(">HH", data[i + 5:i + 9])
                    return width, height
                else:
                    i += 2 + struct.unpack(">H", data[i + 2:i + 4])[0]
            return None
        if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
            chunk = data[12:16]
            if chunk == b"VP8X":
                return (1 + int.from_bytes(data[24:27], "little"),
                        1 + int.from_bytes(data[27:30], "little"))
            if chunk == b"VP8 ":
                width, height = struct.unpack("<HH", data[26:30])
                return width & 0x3FFF, height & 0x3FFF
            if chunk == b"VP8L":
                bits = int.from_bytes(data[21:25], "little")
                return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    except (struct.error, IndexError):
        return None
    return None


def check_image(r: Report, where: str, image: object, creator_id: str, living: bool,
                path: Path) -> None:
    """A creator's optional `image` (D5): the file, and the credit and licence
    that let it be shown."""
    p = f"{where}.image"
    if not isinstance(image, dict):
        r.error(where, "image must be a mapping, or left out")
        return
    for unknown in sorted(set(image) - IMAGE_KEYS, key=str):
        r.error(p, f"unknown field {unknown!r}")
    licence = image.get("licence")
    required = ["file", "credit", "author", "licence", "source_url", "retrieved"]
    if licence != "public-domain":
        required.append("licence_url")
    for key in required:
        if not _is_str(image.get(key)):
            r.error(p, f"{key} is required")
    if licence is not None and licence not in IMAGE_LICENCES:
        r.error(p, f"licence must be one of {', '.join(IMAGE_LICENCES)} (no NC, no ND, "
                   f"no fair use), got {licence!r}")
    if living and licence == "public-domain":
        r.error(p, "a living creator's image is never public-domain by age: it needs "
                   "a free licence (CC0-1.0, CC-BY-4.0 or CC-BY-SA-4.0)")
    for key in ("licence_url", "source_url"):
        if key in image and not _https(image[key]):
            r.error(p, f"{key} must be an https link, got {image[key]!r}")
    if "retrieved" in image:
        _check_date_field(r, p, "retrieved", image["retrieved"])
    file = image.get("file")
    if not _is_str(file):
        return
    prefix = "decks/creators/images/"
    if not file.startswith(prefix) or "/" in file[len(prefix):] \
            or not file.endswith(IMAGE_EXTS):
        r.error(p, f"file must be {prefix}<creator id> and .jpg, .png or .webp, got "
                   f"{file!r}")
        return
    if file[len(prefix):].rsplit(".", 1)[0] != creator_id:
        r.error(p, f"file is named for its creator: {prefix}{creator_id}.<ext>")
    r.creators_images.append(file[len(prefix):])
    disk = path.parent / "images" / file[len(prefix):]
    if not disk.is_file():
        r.error(p, f"{file} does not exist")
        return
    data = disk.read_bytes()
    if len(data) > IMAGE_MAX_BYTES:
        r.error(p, f"{file} is {len(data) // 1024} KB; at most {IMAGE_MAX_BYTES // 1024}")
    size = image_size(data)
    ext = file.rsplit(".", 1)[1]
    magic = {"png": data[:4] == b"\x89PNG", "jpg": data[:3] == b"\xff\xd8\xff",
             "webp": data[:4] == b"RIFF" and data[8:12] == b"WEBP"}[ext]
    if not magic or size is None:
        r.error(p, f"{file} is not a readable {ext} image")
    elif max(size) > IMAGE_MAX_SIDE:
        r.error(p, f"{file} is {size[0]} x {size[1]} px; at most {IMAGE_MAX_SIDE} on a side")


def check_creators_file(r: Report, raw: dict, path: Path) -> None:
    """decks/creators/<code>.yaml: the people behind the works, once each
    (D5, D5b)."""
    for unknown in sorted(set(raw) - CREATORS_KEYS, key=str):
        r.error("root", f"unknown field {unknown!r} in a creators file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang = raw.get("language")
    if not isinstance(lang, str) or not CODE_RE.fullmatch(lang):
        r.error("language", f"must be a language code such as 'te', {_code_error(lang)}")
        lang = None
    else:
        r.creators_lang = lang
        if path.stem != lang or path.parent.name != "creators":
            r.error("language", f"a creators file is decks/creators/{lang}.yaml")
        if raw.get("id") != f"creators-{lang}":
            r.error("id", f"must be creators-{lang}, got {raw.get('id')!r}")
    if not _is_str(raw.get("license")):
        r.error("license", "is required (an SPDX identifier, such as CC-BY-SA-4.0)")
    try:
        if path.stat().st_size > SHARED_MAX_BYTES:
            r.error("root", f"is over {SHARED_MAX_BYTES // 1024} KB, which the app "
                            f"refuses for a shared file")
    except OSError:
        pass
    today = _today().year
    eras: dict[str, tuple[int, int | None]] = {}
    if "eras" in raw and not isinstance(raw["eras"], list):
        r.error("eras", "must be a list")
    for i, era in enumerate(raw["eras"] if isinstance(raw.get("eras"), list) else []):
        where = f"eras[{i}]"
        if not isinstance(era, dict) or set(era) - {"id", "name", "reading", "from", "to"}:
            r.error(where, "must be a mapping with id, name, from, to and optionally reading")
            continue
        eid = era.get("id")
        if not _is_str(eid) or not ID_RE.fullmatch(eid):
            r.error(where, f"id must match [a-z0-9-]+, got {eid!r}")
            continue
        where = f"era {eid}"
        if eid in eras:
            r.error(where, "is listed twice")
        _check_by_language(r, where, "name", era.get("name"))
        start, end = era.get("from"), era.get("to")
        if isinstance(start, bool) or not isinstance(start, int):
            r.error(where, f"from must be a year, got {start!r}")
            continue
        if end is not None and (isinstance(end, bool) or not isinstance(end, int)):
            r.error(where, f"to must be a year, or null for an era still running, got {end!r}")
            continue
        if end is not None and start >= end:
            r.error(where, f"from {start} is not before to {end}")
        eras[eid] = (start, end)
    creators = raw.get("creators")
    if not isinstance(creators, list) or not creators:
        r.error("creators", "must be a non-empty list")
        return
    id_re = re.compile(rf"{re.escape(lang)}-[a-z0-9]+(?:-[a-z0-9]+)*") if lang else None
    found: dict[str, dict] = {}
    for i, c in enumerate(creators):
        where = f"creators[{i}]"
        if not isinstance(c, dict):
            r.error(where, "must be a mapping")
            continue
        for unknown in sorted(set(c) - CREATOR_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        cid = c.get("id")
        if not _is_str(cid) or (id_re is not None and not id_re.fullmatch(cid)):
            r.error(where, f"id must be {lang or '<language>'}- and a name, got {cid!r}")
            continue
        where = f"creator {cid}"
        if cid in found:
            r.error(where, "is listed twice")
        names = c.get("name")
        if not isinstance(names, dict) or "en" not in names:
            r.error(where, "name maps a language code to { text, reading, ipa } and "
                           "has an en entry")
            names = {}
        for code, entry in names.items():
            _text_entry(r, f"{where}.name.{code}", entry)
        born, died = c.get("born"), c.get("died")
        by, _ = _year_of(born)
        dy, _ = _year_of(died)
        if by is None:
            r.error(where, f"born must be a year, or {{ year, circa: true }}, got {born!r}")
        if "died" in c and dy is None:
            r.error(where, f"died must be a year, or {{ year, circa: true }}, got {died!r}")
        if "living" in c and c["living"] is not True:
            r.error(where, "living must be true, or left out")
        living = c.get("living") is True
        if "died" not in c and not living:
            r.error(where, "has no died: add died, or living: true")
        if "died" in c and living:
            r.error(where, "is living: true and has died")
        if by is not None and dy is not None:
            if by >= dy:
                r.error(where, f"born {by} is not before died {dy}")
            elif dy - by > MAX_LIFESPAN:
                r.error(where, f"lived {dy - by} years; at most {MAX_LIFESPAN}")
        if dy is not None and dy > today:
            r.error(where, f"died {dy} is in the future")
        if by is not None and by > today:
            r.error(where, f"born {by} is in the future")
        era = c.get("era")
        if era is not None:
            if era not in eras:
                r.error(where, f"era {era!r} is not one of the file's eras")
            elif by is not None:
                start, end = eras[era]
                active_from = by + 15
                active_to = dy if dy is not None else today
                if active_to < start - ERA_SLACK or active_from > (
                        end if end is not None else today) + ERA_SLACK:
                    r.error(where, f"active {active_from} to {active_to}, but era {era!r} "
                                   f"runs {start} to {end if end is not None else 'today'} "
                                   f"(within {ERA_SLACK} years)")
        if "region" in c and not (_is_str(c["region"]) and ID_RE.fullmatch(c["region"])):
            r.error(where, f"region must be a region id of the language's path, got "
                           f"{c['region']!r}")
        _by_language(r, where + ".bio", c.get("bio"))
        bt = c.get("bio_target")
        if bt is not None:
            if not isinstance(bt, dict):
                r.error(where, "bio_target must map a level to { text, reading, ipa }")
            else:
                for level, entry in bt.items():
                    if level not in LEVELS:
                        r.error(where, f"bio_target level {level!r} is not one of "
                                       f"{', '.join(LEVELS)}")
                    _text_entry(r, f"{where}.bio_target.{level}", entry)
        if "image" in c:
            check_image(r, where, c["image"], cid, living, path)
        if "legacy" in c:
            check_legacy(r, where, c["legacy"])
        related = c.get("related")
        if related is not None and not isinstance(related, list):
            r.error(where, "related must be a list")
            related = []
        for k, rel in enumerate(related or []):
            w = f"{where}.related[{k}]"
            if not isinstance(rel, dict) or set(rel) - {"creator", "card", "relation"} \
                    or ("creator" in rel) == ("card" in rel):
                r.error(w, "must be a mapping with a creator or a card, and a relation")
                continue
            if rel.get("relation") not in RELATIONS:
                r.error(w, f"relation must be one of {', '.join(RELATIONS)}, got "
                           f"{rel.get('relation')!r}")
            if "card" in rel:
                if _is_str(rel["card"]) and lang and card_id_re(lang).fullmatch(rel["card"]):
                    r.related_cards.append((rel["card"], w))
                else:
                    r.error(w, f"card must be a {lang or ''} card id, got {rel['card']!r}")
            elif rel.get("creator") == cid:
                r.error(w, "relates a creator to themselves")
            elif not _is_str(rel.get("creator")):
                r.error(w, "creator must be a creator id")
        if "checked_by" in c:
            codes = c["checked_by"]
            if not isinstance(codes, list) or not codes or any(
                    rater_code(x) is None or rater_code(x) != x for x in codes):
                r.error(where, "checked_by must be a non-empty list of rater codes, "
                               "FL-XXXX-XXXX-C")
        found[cid] = {"names": {e["text"] for e in names.values()
                                if isinstance(e, dict) and _is_str(e.get("text"))},
                      "born": by, "died": dy, "region": c.get("region"),
                      "checked": bool(c.get("checked_by")), "where": where,
                      "related": [rel.get("creator") for rel in related or []
                                  if isinstance(rel, dict) and "creator" in rel]}
    for cid, c in found.items():
        for other in c["related"]:
            if _is_str(other) and id_re is not None and id_re.fullmatch(other) \
                    and other not in found:
                r.error(c["where"], f"related names {other!r}, which is not in the file")
    r.creators_data = found
    images = path.parent / "images"
    if lang and images.is_dir():
        cited = set(r.creators_images)
        for p in sorted(images.iterdir()):
            if p.name.startswith(f"{lang}-") and p.name not in cited:
                r.error("image", f"decks/creators/images/{p.name} is cited by no creator")


# --- decks/<code>/<code>-topics.yaml (D6) ------------------------------------

TOPICS_KEYS = {"schema", "kind", "id", "language", "license", "description", "topics"}
TOPIC_KEYS = {"id", "name", "summary", "term", "level", "kind", "decks", "units",
              "cards", "grammar", "situations", "topics", "script_units", "chars"}
# What a topic covers: at least one. `script_units` are a script guide's
# feature ids and `chars` a list of letters, signs or glyphs (a Bengali
# juktakkhor, a kanji group, a Braille groupsign): data only, no per-script
# code (owner, 2026-11-12, #1137).
TOPIC_COVERS = ("decks", "units", "cards", "grammar", "situations", "topics",
                "script_units", "chars")


def check_topics_file(r: Report, raw: dict, path: Path) -> None:
    """A language's topics: what a learner would search for, naming what
    exists (D6). References are resolved across the language's files."""
    for unknown in sorted(set(raw) - TOPICS_KEYS, key=str):
        r.error("root", f"unknown field {unknown!r} in a topics file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang = raw.get("language")
    if not isinstance(lang, str) or not CODE_RE.fullmatch(lang):
        r.error("language", f"must be a language code such as 'ja', {_code_error(lang)}")
        lang = None
    else:
        r.facts_lang = lang
        if path.stem != f"{lang}-topics" or raw.get("id") != f"{lang}-topics":
            r.error("id", f"a topics file is {lang}-topics.yaml, with that id, got "
                          f"{raw.get('id')!r} in {path.name!r}")
    lc = lang or "xx"
    topics = raw.get("topics")
    if not isinstance(topics, list) or not topics:
        r.error("topics", "must be a non-empty list")
        return
    id_re = re.compile(rf"{re.escape(lc)}-[a-z0-9]+(?:-[a-z0-9]+)*")
    ids: set[str] = set()
    collected: list[tuple[str, str, dict]] = []
    for i, t in enumerate(topics):
        where = f"topics[{i}]"
        if not isinstance(t, dict):
            r.error(where, "must be a mapping")
            continue
        for unknown in sorted(set(t) - TOPIC_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        tid = t.get("id")
        if not _is_str(tid) or not id_re.fullmatch(tid):
            r.error(where, f"id must be {lc}- and a name, [a-z0-9-]+, got {tid!r}")
            continue
        where = f"topic {tid}"
        if tid in ids:
            r.error(where, "duplicate topic id")
        ids.add(tid)
        _check_by_language(r, where, "name", t.get("name"))
        if "summary" in t:
            _check_by_language(r, where, "summary", t["summary"])
        if "term" in t:
            _text_entry(r, f"{where}.term", t["term"])
        if "level" in t and t["level"] not in LEVELS:
            r.error(where, f"level must be one of {', '.join(LEVELS)}, got {t['level']!r}")
        if "kind" in t and not (_is_str(t["kind"]) and ID_RE.fullmatch(t["kind"])):
            r.error(where, f"kind must be a word such as {', '.join(TOPIC_KINDS)}, got "
                           f"{t['kind']!r}")
        covered = 0
        for key in TOPIC_COVERS:
            if key not in t:
                continue
            value = t[key]
            if not isinstance(value, list) or not value:
                r.error(where, f"{key} must be a non-empty list, or left out")
                continue
            covered += 1
            seen: list[object] = []
            for k, ref in enumerate(value):
                w = f"{where}.{key}[{k}]"
                if key == "chars":
                    text = ref.get("text") if isinstance(ref, dict) else ref
                    if isinstance(ref, dict):
                        _text_entry(r, w, ref)
                    if not _is_str(text) or text != text.strip() or re.search(r"\s", text) \
                            or len(text) > MAX_CHARS_LEN:
                        r.error(w, f"a character is a letter, sign or conjunct of at "
                                   f"most {MAX_CHARS_LEN} code points with no spaces, "
                                   f"got {text!r}")
                        continue
                    ref = unicodedata.normalize("NFC", text)
                elif key == "cards":
                    if not _is_str(ref) or not card_id_re(lc).fullmatch(ref):
                        r.error(w, f"must be a {lc} card id, got {ref!r}")
                        continue
                    r.base_refs.append((ref, where, f"{key}[{k}]"))
                elif key == "decks" and not _is_core_id(ref, lc):
                    r.error(w, f"must be a core id of {lc}, {lc}- and a name, got {ref!r}")
                    continue
                elif key in ("units", "grammar", "situations", "script_units") \
                        and not (_is_str(ref) and ID_RE.fullmatch(ref)):
                    r.error(w, f"must be an id, [a-z0-9-]+, got {ref!r}")
                    continue
                elif key == "topics":
                    if ref == tid:
                        r.error(w, "a topic does not list itself")
                        continue
                    if not _is_str(ref) or not id_re.fullmatch(ref):
                        r.error(w, f"must be a topic id of {lc}, got {ref!r}")
                        continue
                if ref in seen:
                    r.error(w, f"{ref!r} is listed twice")
                seen.append(ref)
        if not covered:
            r.error(where, f"covers nothing: list at least one of "
                           f"{', '.join(TOPIC_COVERS)}")
        collected.append((tid, where, t))
    for tid, where, t in collected:
        others = t.get("topics")
        for other in others if isinstance(others, list) else []:
            if _is_str(other) and id_re.fullmatch(other) and other != tid \
                    and other not in ids:
                r.error(where, f"topics names {other!r}, which is not in the file")
    r.topics_data = collected


# --- decks/<code>/<code>-gating.yaml (#1227) ---------------------------------

GATING_KEYS = {"schema", "kind", "id", "language", "license", "description",
               "character_gating"}
GATING_ENTRY_KEYS = {"script", "mode", "allow", "blocks"}
GATING_MODES = ("warn", "error")
# At most this many reports for one deck, then a line saying how many more.
GATING_MAX_REPORTS = 20
_BLOCK_RE = re.compile(r"([0-9A-Fa-f]{4,6})-([0-9A-Fa-f]{4,6})")


def check_gating_file(r: Report, raw: dict, path: Path) -> None:
    """decks/<lang>/<lang>-gating.yaml: for each script the path gates, how
    strictly (`warn` or `error`), the characters allowed from the start and,
    for a script the validator has no Unicode blocks for, its blocks. Only
    the validator reads it: the app does not, so a path of released apps is
    never given a key it refuses (#1227). It lives beside the path and is
    checked against it across files."""
    for unknown in sorted(set(raw) - GATING_KEYS, key=str):
        r.error("root", f"unknown field {unknown!r} in a gating file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang = raw.get("language")
    if not _is_str(lang) or not CODE_RE.fullmatch(lang):
        r.error("language", f"must be a language code such as 'ja', {_code_error(lang)}")
        lang = None
    else:
        if path.stem != f"{lang}-gating" or raw.get("id") != path.stem:
            r.error("id", f"a gating file is {lang}-gating.yaml with id {lang}-gating, "
                          f"got {raw.get('id')!r} in {path.name!r}")
        r.gating_lang = lang
    entries = raw.get("character_gating")
    if not isinstance(entries, list) or not entries:
        r.error("character_gating", "must be a non-empty list of { script, mode, "
                                    "allow?, blocks? }")
        return
    valid: list[dict] = []
    scripts: set[str] = set()
    for i, entry in enumerate(entries):
        where = f"character_gating[{i}]"
        if not isinstance(entry, dict):
            r.error(where, "must be a mapping")
            continue
        for unknown in sorted(set(entry) - GATING_ENTRY_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")
        ok = True
        script = entry.get("script")
        if not (_is_str(script) and SCRIPT_RE.fullmatch(script)):
            r.error(where, f"script must be a script id such as 'han', got {script!r}")
            ok = False
        elif script in scripts:
            r.error(where, f"script {script!r} is gated twice")
            ok = False
        else:
            scripts.add(script)
        mode = entry.get("mode")
        if mode not in GATING_MODES:
            r.error(where, f"mode must be one of {', '.join(GATING_MODES)}, got {mode!r}")
            ok = False
        blocks: list[tuple[int, int]] = []
        if "blocks" in entry:
            given = entry["blocks"]
            if not isinstance(given, list) or not given:
                r.error(where, "blocks must be a non-empty list of 'XXXX-YYYY' "
                               "hexadecimal code point ranges, or left out")
                ok = False
            else:
                for b in given:
                    m = _BLOCK_RE.fullmatch(b) if isinstance(b, str) else None
                    if m is None or int(m[1], 16) > int(m[2], 16):
                        hint = "" if isinstance(b, str) else (
                            " (a bare number, not a range: the deck reader turns "
                            "0980 into 980)")
                        r.error(where, f"block {b!r} must be 'XXXX-YYYY', hexadecimal, "
                                       f"the first not after the second{hint}")
                        ok = False
                    else:
                        blocks.append((int(m[1], 16), int(m[2], 16)))
        elif ok and script not in SCRIPT_BLOCKS:
            r.error(where, f"the validator has no Unicode blocks for the script "
                           f"{script!r}: give them, blocks: [\"XXXX-YYYY\"]")
            ok = False
        allow: set[str] = set()
        if "allow" in entry:
            given = entry["allow"]
            if not isinstance(given, list) or not given:
                r.error(where, "allow must be a non-empty list of characters, or left out")
                ok = False
            else:
                for ch in given:
                    if not _is_str(ch) or len(ch) != 1:
                        r.error(where, f"allow lists one character each, got {ch!r}")
                        ok = False
                    elif ch in allow:
                        r.error(where, f"allow lists {ch!r} twice")
                    else:
                        allow.add(ch)
        if ok:
            valid.append({"script": script, "mode": mode, "allow": allow,
                          "blocks": tuple(blocks) or SCRIPT_BLOCKS[script], "where": where})
    r.gating_data = valid


def _gated_chars(text: str, blocks: tuple[tuple[int, int], ...]) -> list[str]:
    """The characters of [text] in [blocks], in order, each once."""
    found: dict[str, None] = {}
    for ch in text:
        if any(lo <= ord(ch) <= hi for lo, hi in blocks):
            found.setdefault(ch)
    return list(found)


def _card_texts(card: dict) -> list[tuple[str, str]]:
    """The spellings of a written card a gate looks at, with where each is:
    its target, alternatives and `target_scripts`, and each example's target
    and `target_scripts`."""
    texts: list[tuple[str, str]] = []

    def add(where: str, value: object) -> None:
        if _is_str(value):
            texts.append((where, value))

    add("target", card.get("target"))
    for k, alt in enumerate(card.get("alt_target") or []):
        add(f"alt_target[{k}]", alt)
    spellings = card.get("target_scripts")
    for key, value in (spellings.items() if isinstance(spellings, dict) else []):
        add(f"target_scripts.{key}", value)
    for k, ex in enumerate(card.get("examples") or []):
        if not isinstance(ex, dict):
            continue
        add(f"examples[{k}].target", ex.get("target"))
        spellings = ex.get("target_scripts")
        for key, value in (spellings.items() if isinstance(spellings, dict) else []):
            add(f"examples[{k}].target_scripts.{key}", value)
    return texts


def check_gating_across(reports: list[Report], ctx: "_Context") -> list[str]:
    """Each gated script of a language's gating file against its path: the
    characters taught so far are those of the character decks (the path's
    `alphabet` decks tagged `script`, one character on a card) of earlier
    units, of the unit itself for its other decks, and, in a character deck,
    of the cards before and including the one asked about. A card or an
    example that writes a gated character not yet taught is reported: an
    error, or a warning for `mode: warn`. A spelling in another script has
    none of the gated script's characters, so it is not asked about (#1227)."""
    problems: list[str] = []
    for gate in reports:
        if gate.gating_data is None or gate.gating_lang is None:
            continue
        lang = ctx.lang(gate.gating_lang)
        path = lang.path()
        if path is None or path.plan is None:
            problems.append(f"{gate.path}: character_gating: {gate.gating_lang} has no "
                            f"path to gate")
            continue
        plan = path.plan
        by_core = lang.by_core()
        for entry in gate.gating_data:
            _gate_one(problems, gate, entry, plan, by_core)
    return problems


def _written_cards(rep: Report) -> tuple[list[dict], list[str]]:
    """The written cards, in order, and the tags of a core or single-file
    deck, read for a gate."""
    raw = _load_raw_view(rep.path)
    if not isinstance(raw, dict) or not isinstance(raw.get("cards"), list):
        return [], []
    tags = raw.get("tags")
    return ([c for c in raw["cards"] if isinstance(c, dict) and _is_str(c.get("target"))],
            [t for t in tags if isinstance(t, str)] if isinstance(tags, list) else [])


def _gate_one(problems: list[str], gate: Report, entry: dict, plan: "PathPlan",
              by_core: dict[str, list[Report]]) -> None:
    blocks, mode = entry["blocks"], entry["mode"]
    taught: set[str] = set(entry["allow"])
    for unit in plan.units:
        decks = [(core, rep) for core in unit.decks for rep in by_core.get(core, [])
                 if rep.part != "layer"]
        loaded = {id(rep): _written_cards(rep) for _, rep in decks}
        is_char = {id(rep): core in plan.alphabet and "script" in loaded[id(rep)][1]
                   for core, rep in decks}
        # The characters the unit's character decks teach, whole.
        taught_here: set[str] = set()
        for _, rep in decks:
            if is_char[id(rep)]:
                for card in loaded[id(rep)][0]:
                    target = card["target"].strip()
                    if len(target) == 1 and _gated_chars(target, blocks):
                        taught_here.add(target)
        for core, rep in decks:
            cards = loaded[id(rep)][0]
            known = set(taught) if is_char[id(rep)] else taught | taught_here
            reported = 0
            for card in cards:
                target = card["target"].strip()
                if is_char[id(rep)] and len(target) == 1 and _gated_chars(target, blocks):
                    known.add(target)
                for spot, text in _card_texts(card):
                    for ch in _gated_chars(text, blocks):
                        if ch in known:
                            continue
                        reported += 1
                        if reported > GATING_MAX_REPORTS:
                            continue
                        msg = (f"card {card.get('id')}: {spot} writes {ch!r} (U+{ord(ch):04X}), "
                               f"a {entry['script']} character the path has not taught by "
                               f"unit {unit.i + 1}; write it in another script, or teach it "
                               f"in an earlier unit (gating file {gate.path.name}, "
                               f"{entry['where']})")
                        if mode == "error":
                            problems.append(f"{rep.path}: {msg}")
                        else:
                            rep.warn(f"card {card.get('id')}", msg.split(": ", 1)[1])
            if reported > GATING_MAX_REPORTS:
                extra = (f"{reported - GATING_MAX_REPORTS} more {entry['script']} "
                         f"characters not yet taught in {core}, not listed")
                if mode == "error":
                    problems.append(f"{rep.path}: {extra}")
                else:
                    rep.warn(core, extra)
        taught |= taught_here


# A script topic's `chars` against its decks (#1228). The cards a deck leaves
# out of `chars` are a warning until the real topics files are written by
# tools/topic_chars.py (decks-live's hiragana and katakana topics list the
# 46 basic letters but also name the marks decks); flip this to make a
# character card missing from `chars` an error, as `chars` naming a character
# that no listed card has already is.
TOPIC_CHARS_MISSING_IS_ERROR = False


def _clusters(text: str) -> int:
    """How many user-perceived characters [text] has, by data in Unicode and
    no script's name: a mark, a joiner, or a letter after a virama joins the
    one before it (a conjunct, a kana with a voicing mark)."""
    count, joined = 0, False
    for ch in text:
        if count and (joined or unicodedata.category(ch)[0] == "M"
                      or ch in "\u200c\u200d"):
            pass
        else:
            count += 1
        joined = unicodedata.combining(ch) == 9 or ch == "\u200d"
    return count


def topic_deck_targets(t: dict, by_core: dict[str, list[Report]]) -> list[str]:
    """The targets of the cards of a topic's `decks`, NFC, in deck and card
    order, each once: the characters its `chars` may name. A layer writes no
    target, so only a core or a single-file deck is read."""
    found: dict[str, None] = {}
    for deck in t.get("decks") or []:
        for rep in by_core.get(deck, []) if _is_str(deck) else []:
            if rep.part == "layer":
                continue
            for d in rep.card_defs.values():
                target = unicodedata.normalize("NFC", d.target.strip())
                if target:
                    found.setdefault(target)
    return list(found)


def topic_char_pool(t: dict, by_core: dict[str, list[Report]],
                    facts: list[Report]) -> tuple[set[str], set[str]] | None:
    """What a script topic's `chars` may name, and the single characters its
    decks teach: (every target of the cards of its `decks` and every example
    and letter of its `script_units`, the targets that are one character), or
    None when it lists neither, so there is nothing to check against."""
    if t.get("kind") != "script" or not (t.get("decks") or t.get("script_units")):
        return None
    targets = topic_deck_targets(t, by_core)
    allowed = set(targets)
    singles = {x for x in targets if _clusters(x) == 1}
    for fid in t.get("script_units") or []:
        for o in facts:
            allowed |= o.script_chars.get(fid, set())
    return allowed, singles


def check_topic_chars(rep: Report, where: str, t: dict, pool: tuple,
                      problems: list[str]) -> None:
    """A script topic's `chars` are only characters its decks teach (or its
    script units show), and each single-character card of its decks is
    listed (#1228)."""
    allowed, singles = pool
    chars = []
    for ref in t.get("chars") or []:
        text = ref.get("text") if isinstance(ref, dict) else ref
        if _is_str(text):
            chars.append(unicodedata.normalize("NFC", text))
    for ch in chars:
        if ch not in allowed:
            problems.append(f"{rep.path}: {where}: chars lists {ch!r}, which is no "
                            f"card's target in the topic's decks, nor a letter of its "
                            f"script units; `tools/topic_chars.py` writes chars from "
                            f"the decks")
    if t.get("decks"):
        left = sorted(singles - set(chars))
        if left:
            shown = ", ".join(repr(c) for c in left[:8]) + (", ..." if len(left) > 8 else "")
            msg = (f"chars leaves out {len(left)} single-character card(s) of the "
                   f"topic's decks ({shown}); `tools/topic_chars.py` writes chars "
                   f"from the decks")
            if TOPIC_CHARS_MISSING_IS_ERROR:
                problems.append(f"{rep.path}: {where}: {msg}")
            else:
                rep.warn(where, msg)


# --- decks/recommendations/<code>.yaml (D13) ---------------------------------

RECS_KEYS = {"schema", "kind", "id", "language", "license", "recommendations"}
REC_KEYS = {"id", "medium", "title", "creator", "year", "level", "script", "briefing",
            "questions", "legal", "quoted_in", "checked_by", "tags"}


def _pirate_hosts() -> set[str]:
    try:
        lines = PIRATE_HOSTS.read_text(encoding="utf-8").splitlines()
        return {line.strip().lower() for line in lines
                if line.strip() and not line.strip().startswith("#")}
    except OSError:
        return set()


def _language_scripts(code: str) -> list[str] | None:
    """The scripts assets/languages.yaml lists for [code], or None."""
    raw = _load_raw_view(ROOT / "assets" / "languages.yaml")
    if isinstance(raw, dict) and isinstance(raw.get("languages"), list):
        for entry in raw["languages"]:
            if isinstance(entry, dict) and entry.get("code") == code:
                scripts = entry.get("scripts")
                if isinstance(scripts, list):
                    return [s for s in scripts if isinstance(s, str)]
                return [entry["script"]] if _is_str(entry.get("script")) else None
    return None


def check_recommendations_file(r: Report, raw: dict, path: Path) -> None:
    """decks/recommendations/<code>.yaml: popular works to find elsewhere and
    be taught about, never reproduced (D13)."""
    for unknown in sorted(set(raw) - RECS_KEYS, key=str):
        r.error("root", f"unknown field {unknown!r} in a recommendations file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang = raw.get("language")
    if not isinstance(lang, str) or not CODE_RE.fullmatch(lang):
        r.error("language", f"must be a language code such as 'te', {_code_error(lang)}")
        lang = None
    else:
        r.recs_lang = lang
        if path.stem != lang or path.parent.name != "recommendations":
            r.error("language", f"a recommendations file is decks/recommendations/{lang}.yaml")
        if raw.get("id") != f"recommendations-{lang}":
            r.error("id", f"must be recommendations-{lang}, got {raw.get('id')!r}")
    if not _is_str(raw.get("license")):
        r.error("license", "is required (an SPDX identifier, such as CC-BY-SA-4.0)")
    recs = raw.get("recommendations")
    if not isinstance(recs, list) or not recs:
        r.error("recommendations", "must be a non-empty list")
        return
    scripts = _language_scripts(lang) if lang else None
    hosts = _pirate_hosts()
    if not hosts:
        r.error("recommendations", "tools/pirate_hosts.txt is missing or empty, the "
                                   "pirate-host deny list cannot run")
    id_re = re.compile(rf"{re.escape(lang)}-rec-[a-z0-9]+(?:-[a-z0-9]+)*") if lang else None
    ids: set[str] = set()
    collected: list[tuple[str, str, dict]] = []
    for i, rec in enumerate(recs):
        where = f"recommendations[{i}]"
        if not isinstance(rec, dict):
            r.error(where, "must be a mapping")
            continue
        for unknown in sorted(set(rec) - REC_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}: a recommendation holds no text "
                           f"of the work, only what is said about it")
        rid = rec.get("id")
        if not _is_str(rid) or (id_re is not None and not id_re.fullmatch(rid)):
            r.error(where, f"id must be {lang or '<language>'}-rec- and a name, got {rid!r}")
            continue
        where = f"recommendation {rid}"
        if rid in ids:
            r.error(where, "duplicate recommendation id")
        ids.add(rid)
        medium = rec.get("medium")
        if medium not in MEDIA_KINDS:
            r.error(where, f"medium must be one of {', '.join(MEDIA_KINDS)}, got {medium!r}")
        _text_entry(r, f"{where}.title", rec.get("title"))
        creators: list[str] = []
        if "creator" in rec:
            creators = _creator_ids(r, where + ".creator", rec["creator"], lang)
        else:
            r.error(where, "creator is required: the ids of the creators file")
        year = rec.get("year")
        if isinstance(year, bool) or not isinstance(year, int) or year > _today().year:
            r.error(where, f"year must be a year, no later than this one, got {year!r}")
        if rec.get("level") not in LEVELS:
            r.error(where, f"level must be one of {', '.join(LEVELS)}, got "
                           f"{rec.get('level')!r}")
        script = rec.get("script")
        if medium == "book":
            if not _is_str(script):
                r.error(where, "a book names the script it is printed in")
            elif scripts is not None and script not in scripts:
                r.error(where, f"script {script!r} is not one of {lang}'s "
                               f"({', '.join(scripts)})")
        elif "script" in rec:
            r.error(where, "only a book has a script")
        _by_language(r, where + ".briefing", rec.get("briefing"))
        questions = rec.get("questions")
        if not isinstance(questions, list) or not 3 <= len(questions) <= 8:
            r.error(where, "questions must be a list of 3 to 8 questions")
            questions = []
        qids: set[str] = set()
        for k, q in enumerate(questions):
            w = f"{where}.questions[{k}]"
            if not isinstance(q, dict) or set(q) - QUESTION_KEYS:
                r.error(w, "must be a mapping with id, prompt, options and answer")
                continue
            qid = q.get("id")
            if not _is_str(qid) or not ID_RE.fullmatch(qid):
                r.error(w, f"id must match [a-z0-9-]+, got {qid!r}")
            elif qid in qids:
                r.error(w, f"duplicate question id {qid!r}")
            else:
                qids.add(qid)
            _check_by_language(r, w, "prompt", q.get("prompt"))
            options = q.get("options")
            if not isinstance(options, dict) or "en" not in options:
                r.error(w, "options map a language code to a list of 2 to 4 options, "
                           "with an en entry")
                continue
            lengths = set()
            for code, opts in options.items():
                if not isinstance(opts, list) or len(opts) not in CHOICES \
                        or not all(_is_str(o) for o in opts):
                    r.error(w, f"options.{code} must be a list of 2 to 4 options")
                else:
                    lengths.add(len(opts))
            ans = q.get("answer")
            if len(lengths) != 1:
                r.error(w, "every language gives the same number of options")
            elif isinstance(ans, bool) or not isinstance(ans, int) \
                    or not 1 <= ans <= next(iter(lengths)):
                r.error(w, f"answer must be the number of the right option, from 1 to "
                           f"{next(iter(lengths))}, got {ans!r}")
        legal = rec.get("legal")
        if legal is not None and not isinstance(legal, list):
            r.error(where, "legal must be a list")
            legal = []
        for k, leg in enumerate(legal or []):
            w = f"{where}.legal[{k}]"
            if not isinstance(leg, dict) or set(leg) - {"kind", "url", "note"}:
                r.error(w, "must be a mapping with kind, url and optionally note")
                continue
            if leg.get("kind") not in LEGAL_KINDS:
                r.error(w, f"kind must be one of {', '.join(LEGAL_KINDS)}, got "
                           f"{leg.get('kind')!r}")
            if not _https(leg.get("url")):
                r.error(w, f"url must be an https link, got {leg.get('url')!r}")
            else:
                host = (urlparse(leg["url"]).hostname or "").lower().rstrip(".")
                if any(host == h or host.endswith("." + h) for h in hosts):
                    r.error(w, f"{host} is on the deny list of unlicensed hosts "
                               f"(tools/pirate_hosts.txt): link the rights-holder's "
                               f"or a library's page")
            if "note" in leg:
                _by_language(r, w + ".note", leg["note"])
        if "quoted_in" in rec and not (_is_str(rec["quoted_in"])
                                       and _is_core_id(rec["quoted_in"], lang or "xx")):
            r.error(where, f"quoted_in must be the core id of a {lang} culture deck, "
                           f"got {rec['quoted_in']!r}")
        tags = rec.get("tags")
        if tags is not None:
            _check_str_list(r, where, "tags", tags)
        if "checked_by" in rec:
            codes = rec["checked_by"]
            if not isinstance(codes, list) or not codes or any(
                    rater_code(x) is None or rater_code(x) != x for x in codes):
                r.error(where, "checked_by must be a non-empty list of rater codes")
        if isinstance(tags, list) and "reviewed" in tags and not rec.get("checked_by"):
            r.error(where, "is tagged reviewed, so it needs checked_by")
        info = dict(rec)
        info["_creators"] = creators
        collected.append((rid, where, info))
    r.recs_data = collected


SHARED_KIND_CHECKS = {
    "sections": check_sections_file,
    "creators": check_creators_file,
    "topics": check_topics_file,
    "recommendations": check_recommendations_file,
}


# --- The checks across files for the kinds -----------------------------------

def _find_shared(path: Path, rel: str) -> Path | None:
    """A deck-owned file ([rel], such as sections.yaml) as a deck at [path]
    sees it: in the decks/ folder above its language's, else the repository's."""
    resolved = path.resolve()
    bases = list(resolved.parents)[:3]
    if ROOT in resolved.parents:
        bases.append(ROOT / "decks")  # not for a draft or a test tree elsewhere
    for base in bases:
        candidate = base / rel
        if candidate.is_file():
            return candidate
    return None


def _creators_from_raw(raw: object) -> dict[str, dict]:
    out: dict[str, dict] = {}
    if isinstance(raw, dict) and isinstance(raw.get("creators"), list):
        for c in raw["creators"]:
            if not isinstance(c, dict) or not _is_str(c.get("id")):
                continue
            names = c.get("name") if isinstance(c.get("name"), dict) else {}
            out[c["id"]] = {
                "names": {e["text"] for e in names.values()
                          if isinstance(e, dict) and _is_str(e.get("text"))},
                "born": _year_of(c.get("born"))[0], "died": _year_of(c.get("died"))[0],
                "region": c.get("region"), "checked": bool(c.get("checked_by")),
                "where": f"creator {c['id']}", "related": []}
    return out


def _recommended_creators(reports: list[Report], rep: Report, code: str) -> set[str]:
    """The creator ids the language's recommendations file names: a creator
    named there counts as cited, as one a card names does."""
    for other in reports:
        if other.recs_lang == code and other.recs_data is not None:
            return {i for _, _, info in other.recs_data for i in info.get("_creators", [])}
    found = _find_shared(rep.path, f"recommendations/{code}.yaml")
    raw = _load_raw_view(found) if found is not None else None
    out: set[str] = set()
    for rec in (raw.get("recommendations") if isinstance(raw, dict) else None) or []:
        ids = rec.get("creator") if isinstance(rec, dict) else None
        for i in [ids] if isinstance(ids, str) else ids if isinstance(ids, list) else []:
            if _is_str(i):
                out.add(i)
    return out


def _creators_for(reports: list[Report], rep: Report, code: str
                  ) -> tuple[dict[str, dict] | None, Path | None]:
    for other in reports:
        if other.creators_lang == code and other.creators_data is not None:
            return other.creators_data, other.path
    found = _find_shared(rep.path, f"creators/{code}.yaml")
    if found is None:
        return None, None
    return _creators_from_raw(_load_raw_view(found)), found


def check_kinds_across(reports: list[Report]) -> list[str]:
    """The checks across files of the deck kinds: every genre, profession and
    section a deck uses is listed in decks/sections.yaml; a card's creator is
    in the language's creators file, its source author is that creator and
    its date is not before their birth; creator ids are unique across
    languages; topics and recommendations name what exists."""
    problems: list[str] = []
    ctx = _context(reports)
    given_paths = {o.path.resolve() for o in reports}

    # decks/sections.yaml.
    for rep in reports:
        if not (rep.genre or rep.professional or rep.section) or rep.part == "layer":
            continue
        listed = next((o.sections_data for o in reports if o.sections_data is not None),
                      None)
        if listed is None:
            found = _find_shared(rep.path, "sections.yaml")
            raw = _load_raw_view(found) if found is not None else None
            if not isinstance(raw, dict) or raw.get("kind") != "sections":
                continue
            listed = {k: {e["id"] for e in raw.get(k) or []
                          if isinstance(e, dict) and _is_str(e.get("id"))}
                      for k in ("sections", "genres", "professions")}
        if rep.genre and rep.genre not in listed["genres"]:
            problems.append(f"{rep.path}: genre: {rep.genre!r} is not listed in "
                            f"decks/sections.yaml; add its row there first")
        if rep.professional and rep.professional not in listed["professions"]:
            problems.append(f"{rep.path}: professional: {rep.professional!r} is not "
                            f"listed in decks/sections.yaml; add its row there first")
        if rep.section and rep.section not in listed["sections"]:
            problems.append(f"{rep.path}: section: {rep.section!r} is not listed in "
                            f"decks/sections.yaml")

    # Creator ids are unique across the language files.
    seen: dict[str, Path] = {}
    for rep in reports:
        if rep.creators_data is None:
            continue
        for cid in rep.creators_data:
            if cid in seen and seen[cid].resolve() != rep.path.resolve():
                problems.append(f"{rep.path}: creator {cid}: also in {seen[cid]}; an id "
                                f"is unique across the creators files")
            seen.setdefault(cid, rep.path)
        for other in sorted(rep.path.parent.glob("*.yaml")):
            if other.resolve() in given_paths:
                continue
            for cid in _creators_from_raw(_load_raw_view(other)):
                if cid in rep.creators_data:
                    problems.append(f"{rep.path}: creator {cid}: also in {other}; an id "
                                    f"is unique across the creators files")

    # The creators a card names.
    for rep in reports:
        if not rep.creator_refs or rep.lang_code is None:
            continue
        creators, file = _creators_for(reports, rep, rep.lang_code)
        if creators is None:
            problems.append(f"{rep.path}: names creators, but there is no "
                            f"decks/creators/{rep.lang_code}.yaml")
            continue
        for ids, where, author, year in rep.creator_refs:
            for cid in ids:
                c = creators.get(cid)
                if c is None:
                    problems.append(f"{rep.path}: {where}: creator {cid!r} is not in "
                                    f"{file}")
                    continue
                if _is_str(author) and author != "anonymous" and author not in c["names"]:
                    problems.append(f"{rep.path}: {where}: source.author {author!r} is "
                                    f"none of {cid}'s names")
                if year is not None and c["born"] is not None and year < c["born"]:
                    problems.append(f"{rep.path}: {where}: source date {year} is before "
                                    f"{cid} was born ({c['born']})")
                if rep.reviewed and rep.genre == "culture" and not c["checked"]:
                    problems.append(f"{rep.path}: {where}: the deck is tagged reviewed, "
                                    f"but creator {cid} has no checked_by")

    # A creators file against the language's path and cards.
    for rep in reports:
        if rep.creators_data is None or rep.creators_lang is None:
            continue
        lang = ctx.lang(rep.creators_lang)
        path = lang.path()
        regions = path.plan.regions if path is not None else None
        for cid, c in rep.creators_data.items():
            if regions is not None and c["region"] is not None and c["region"] not in regions:
                problems.append(f"{rep.path}: {c['where']}: region {c['region']!r} is not "
                                f"a region of {rep.creators_lang}'s path "
                                f"({', '.join(regions)})")
        defs = lang.defs()
        for cid, where in rep.related_cards:
            if defs and cid not in defs:
                problems.append(f"{rep.path}: {where}: card {cid} is not a card of "
                                f"{rep.creators_lang}")
        everyone = lang.all()
        cited = {i for o in everyone for ids, *_ in o.creator_refs for i in ids}
        cited |= _recommended_creators(reports, rep, rep.creators_lang)
        for cid in rep.creators_data:
            if everyone and cid not in cited:
                rep.warn(f"creator {cid}", "no card cites this creator yet")

    # Topics.
    for rep in reports:
        if rep.topics_data is None or rep.facts_lang is None:
            continue
        code = rep.facts_lang
        lang = ctx.lang(code)
        by_core = lang.by_core()
        path = lang.path()
        units: set[str] = set()
        grammar: set[str] = set()
        if path is not None:
            for u in path.plan.units:
                units.update(u.decks)
                if u.planned is not None and _is_str(u.planned.get("id")):
                    units.add(u.planned["id"])
                grammar.update(u.grammar)
        # The situations file and the script guides are no deck of the
        # language (they have no `lang_code`): those given, and on disk.
        facts = [o for o in reports if o.facts_lang == code] + [
            validate(p) for pat in ("*-situations.yaml", "*-script.yaml")
            for p in lang._on_disk(pat)]
        sheets = {sid for o in facts if o.situations_lang == code
                  for sid in o.situation_ids}
        features = {f for o in facts for f in o.script_features}
        rules = {rid for o in lang.all() for rid, _ in o.rules_defined}
        for tid, where, t in rep.topics_data:
            for key, known, what in (
                    ("decks", set(by_core), f"a deck of {code}"),
                    ("units", units, f"a unit of {code}'s path"),
                    ("grammar", grammar | rules, f"a grammar concept or rule of {code}"),
                    ("situations", sheets, f"a situation of {code}"),
                    ("script_units", features, f"a script guide feature of {code}")):
                for ref in t.get(key) or []:
                    # A path or rules the language does not have yet: nothing
                    # to resolve units and grammar against.
                    if (key == "units" and path is None) or (
                            key == "grammar" and path is None and not known):
                        continue
                    if _is_str(ref) and ref not in known:
                        problems.append(f"{rep.path}: {where}: {key} names {ref!r}, "
                                        f"which is not {what}")
            # A script topic's characters against its decks (#1228).
            pool = topic_char_pool(t, by_core, facts)
            if pool is not None and t.get("chars"):
                check_topic_chars(rep, where, t, pool, problems)

    # Character gating (#1227): only a language with a gating file.
    problems += check_gating_across(reports, ctx)

    # Recommendations.
    for rep in reports:
        if rep.recs_data is None or rep.recs_lang is None:
            continue
        creators, file = _creators_for(reports, rep, rep.recs_lang)
        by_core = ctx.lang(rep.recs_lang).by_core()
        for rid, where, rec in rep.recs_data:
            for cid in rec.get("_creators", []):
                c = creators.get(cid) if creators is not None else None
                if c is None:
                    problems.append(f"{rep.path}: {where}: creator {cid!r} is not in the "
                                    f"creators file of {rep.recs_lang}")
                elif isinstance(rec.get("year"), int) and c["born"] is not None \
                        and rec["year"] < c["born"]:
                    problems.append(f"{rep.path}: {where}: year {rec['year']} is before "
                                    f"{cid} was born ({c['born']})")
            quoted = rec.get("quoted_in")
            if _is_str(quoted):
                decks = by_core.get(quoted)
                if not decks:
                    problems.append(f"{rep.path}: {where}: quoted_in {quoted!r} is no "
                                    f"deck of {rep.recs_lang}")
                elif not any(set(rec.get("_creators", []))
                             & {i for ids, *_ in o.creator_refs for i in ids}
                             for o in decks):
                    problems.append(f"{rep.path}: {where}: quoted_in {quoted!r} has no "
                                    f"card citing the same creator")
    return problems


def collect(target: Path) -> list[Path]:
    if target.is_file():
        return [target]
    return sorted(p for p in target.rglob("*.yaml") if "schema" not in p.parts)


def check_index(targets: list[Path], reports: list[Report]) -> list[str]:
    """decks/index.json, the list the app downloads decks from (#210,
    ADR-0037), must be what tools/deck_index.py writes now. Checked when the
    repository's own decks/ is validated whole, from any working directory;
    validating one file or a draft elsewhere is legitimate and skips it.

    Everything is resolved against the repository root rather than the
    working directory: a check that quietly passes when run from the wrong
    directory is worse than no check, because it is trusted."""
    if not any(t.resolve() == ROOT / "decks" for t in targets):
        return []
    # CI sets this: the index is regenerated on main after each merge
    # (.github/workflows/deck-index.yml), so a pull request is not failed
    # for it. Unset, as locally, the check stays.
    if os.environ.get("FLUENOUGH_SKIP_INDEX_CHECK"):
        return []
    # The index tool reads decks through this module: share it, so that the
    # checks across files are not run twice.
    sys.modules.setdefault("validate_decks", sys.modules[__name__])
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import deck_index
    return deck_index.stale(reports)


def main(argv: list[str]) -> int:
    if len(argv) == 3 and argv[1] == "--next-id":
        if not LANG_RE.fullmatch(argv[2]):
            print(f"error: {argv[2]!r} is not a language code", file=sys.stderr)
            return 2
        print(next_card_id(argv[2]))
        return 0
    if len(argv) >= 2 and argv[1] == "--private":
        # A private language package (#1017): checked on its own, never as
        # part of decks/.
        sys.modules.setdefault("validate_decks", sys.modules[__name__])
        import validate_private
        return validate_private.main(argv[2:])
    args = argv[1:]
    jobs: int | None = None
    for i, a in enumerate(args):
        if a == "--jobs" or a.startswith("--jobs="):
            value = a.partition("=")[2] if "=" in a else \
                (args[i + 1] if i + 1 < len(args) else "")
            try:
                jobs = int(value)
                if jobs < 1:
                    raise ValueError
            except ValueError:
                print(f"error: --jobs takes a number of workers, 1 or more; "
                      f"got {value!r}", file=sys.stderr)
                return 2
            del args[i:i + (1 if "=" in a else 2)]
            break
    targets = [Path(a) for a in args] or [Path("decks")]
    paths: list[Path] = []
    for t in targets:
        if not t.exists():
            print(f"error: {t} does not exist", file=sys.stderr)
            return 2
        paths.extend(collect(t))

    if not paths:
        print("error: no deck files found", file=sys.stderr)
        return 2

    reports = validate_many(paths, jobs)

    ids: dict[str, Path] = {}
    for p in paths:
        if p.parent.name in SHARED_DIRS:
            continue  # decks/creators/<code>.yaml: one per language, by design
        if p.stem in ids:
            print(f"error: duplicate deck id {p.stem!r}: {ids[p.stem]} and {p}")
            return 1
        ids[p.stem] = p

    unbundled = check_index(targets, reports)
    for problem in unbundled:
        print(f"error: {problem}")
    across = (check_themes_across(reports) + check_cards_across(reports)
              + check_layers_across(reports)
              + check_numbers_across(reports) + check_paths_across(reports)
              + check_reading_across(reports) + check_icons_across(reports)
              + check_rules_across(reports) + check_notes_across(reports)
              + check_bases_across(reports) + check_phrasebook_across(reports)
              + check_plans_across(reports) + check_regions_across(reports)
              + check_genders_across(reports) + check_media_across(reports)
              + check_sets_across(reports) + check_kinds_across(reports))
    for problem in across:
        print(f"error: {problem}")
    warn_base_stems_across(reports)
    warn_forms_across(reports)
    warn_alikes_across(reports)

    failed = 0
    warned = 0
    for rep in reports:
        if rep.errors:
            failed += 1
            print(f"FAIL {rep.path}")
            for e in rep.errors:
                print(f"  error   {e}")
        elif rep.warnings:
            warned += 1
            print(f"warn {rep.path}")
        elif rep.infos:
            print(f"info {rep.path}")
        for w in rep.warnings:
            print(f"  warning {w}")
        # Infos never change the exit code or the count of valid decks.
        for i in rep.infos:
            print(f"  info    {i}")

    ok = len(reports) - failed
    print(f"\n{ok}/{len(reports)} decks valid"
          f"{f', {warned} with warnings' if warned else ''}.")
    if failed or unbundled or across:
        # CI logs run to thousands of lines and the cross-file errors print
        # near the top, so repeat every error at the very end, where the
        # log's tail shows it.
        print("\nErrors:")
        for problem in unbundled + across:
            print(f"  error: {problem}")
        for rep in reports:
            for e in rep.errors:
                print(f"  error: {rep.path}: {e}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
