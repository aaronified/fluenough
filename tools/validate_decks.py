#!/usr/bin/env python3
"""Validate Fluenough deck files against schema 1.

Usage:
    python3 tools/validate_decks.py decks/
    python3 tools/validate_decks.py decks/es/es-en-core-100.yaml

    python3 tools/validate_decks.py --next-id bn

Requires only Python 3.11+ and PyYAML, so deck contributors need no Flutter
toolchain. Exits non-zero if any deck fails. See docs/DECK-FORMAT.md.
"""

from __future__ import annotations

import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError:
    sys.exit("error: PyYAML is required.  pip install pyyaml")

SCHEMA = 1
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
    "kana", "han", "hangul", "thai", "other",
}
# Scripts whose cards need no reading: they are read as written.
NO_READING = {"latin", "cyrillic", "greek"}
SCRIPT_RE = re.compile(r"[a-z]+(?:-[a-z]+)*")
KINDS = {"vocab", "grammar", "facts", "themes", "numbers", "path", "sounds", "script",
         "reading", "rules", "layer"}
THEMES_KEYS = {"schema", "kind", "description", "themes"}
PATH_KEYS = {"schema", "kind", "id", "language", "native", "description", "units",
             "alphabet"}
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
    "\u02e5-\u02e9\u203f|\u2016\u2191\u2193]+")
CONTRAST_KEYS = {"id", "name", "pairs", "within_word"}
SCRIPT_KEYS = {"schema", "kind", "id", "language", "name", "intro", "features"}
FEATURE_KEYS = {"id", "name", "term", "reading", "ipa", "example", "text",
                "letters"}
CODE_RE = re.compile(r"[a-z]{2,3}")
# `grammarUnderstood` is only for a rules table's cells (ADR-0035): a card or
# a ref that names it is refused.
MODES = {"recognition", "production", "listening", "grammar", "speaking",
         "grammarUnderstood"}
POS = {"noun", "verb", "adj", "adv", "phrase", "particle", "other", "pronoun"}

HEADER_KEYS = {
    "schema", "id", "name", "kind", "language", "native", "license",
    "authors", "source", "description", "tags", "cards", "pattern", "facts",
    "theme", "passages",
}
CARD_KEYS = {
    "id", "target", "native", "reading", "ipa", "alt_target", "alt_native",
    "pos", "gender", "tags", "notes", "audio", "examples", "modes", "pair",
    "picture", "phrasebook", "bases", "rules", "wiktionary",
}
# A ref lists a card written in another deck (ADR-0018). It may give its own
# native-side fields; what the card is in the language learned stays the
# card's own.
REF_KEYS = {
    "ref", "native", "reading", "ipa", "alt_native", "tags", "notes",
    "examples", "modes", "wiktionary",
}
PATTERN_KEYS = {"name", "slot_name", "slots", "prompt", "entries", "notes"}
FACT_KEYS = {"id", "text", "contrast", "tags", "source"}
PASSAGE_KEYS = {"id", "title", "sentences", "source", "theme", "questions", "glossary"}
SENTENCE_KEYS = {"text", "reading", "ipa"}
QUESTION_KEYS = {"id", "prompt", "options", "answer"}
GLOSS_KEYS = {"word", "modern", "reading", "ipa", "meaning", "note"}
EXAMPLE_KEYS = {"target", "native", "reading", "ipa", "bases"}
# A reading question has this many options, and a passage this many
# questions (#98, ADR-0019).
CHOICES = range(2, 5)

# --- The B1 format: cores, layers, rules decks, notes, bases, plans ---------
# See ADR-0035 and docs/DECK-FORMAT.md. A core (`part: "core"`) holds what
# belongs to the language learnt; a layer (`kind: "layer"`) what belongs to
# one native language. Merged, they are the deck the layer's id names.
CORE_HEADER_KEYS = {"schema", "id", "part", "kind", "language", "license",
                    "authors", "source", "tags", "theme", "cards", "pattern",
                    "table", "rules"}
LAYER_HEADER_KEYS = {"schema", "id", "kind", "core", "native", "name",
                     "description", "license", "authors", "source", "tags",
                     "cards", "pattern", "table", "rules"}
CORE_KINDS = ("vocab", "grammar", "rules")
CORE_CARD_KEYS = {"id", "target", "reading", "ipa", "alt_target", "pos",
                  "gender", "tags", "audio", "examples", "modes", "picture",
                  "notes", "phrasebook", "bases", "rules"}
CORE_REF_KEYS = {"ref", "reading", "ipa", "tags", "modes", "examples", "notes"}
CORE_EXAMPLE_KEYS = {"target", "reading", "ipa", "bases"}
# What a native language gives a card: never written in a core.
NATIVE_SIDE = ("native", "alt_native", "wiktionary")
LAYER_ENTRY_KEYS = {"native", "alt_native", "notes", "examples", "bases",
                    "wiktionary"}
CORE_ENTRY_KEYS = {"lemma", "key", "forms", "reading", "readings", "ipa", "ipas"}
LAYER_PATTERN_KEYS = {"name", "slot_name", "prompt", "slots", "entries", "notes"}
TABLE_KEYS = {"applies_to", "slots", "rows"}
APPLIES_KEYS = {"pos", "tags", "except"}
ROW_KEYS = {"word", "key", "forms", "readings", "ipas"}
RULE_KEYS = {"id", "slots", "words"}
LAYER_TABLE_KEYS = {"slot_name", "slots", "prompts"}
LAYER_RULE_KEYS = {"name", "explanation"}
NOTE_KINDS = ("behaviour", "culture", "note", "pair", "usage")
NOTE_KEYS = {"kind", "text", "id", "ref", "source", "words"}
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
RESERVED_CORES = {"facts": "facts file", "numbers": "number rules",
                  "romanisation": "romanisation file", "script": "script guide",
                  "sounds": "sounds file", "path": "path"}
UNIT_KEYS = {"decks", "planned", "words", "grammar", "milestone",
             "listening_passages", "reading_passages"}
PLANNED_KEYS = {"id", "theme", "grammar", "words"}
MILESTONES = ("A1", "A2", "B1")
# Words per level (owner, 2026-10-09; low confidence): A1 700, A2 900 more,
# B1 1,200 more. A level outside half to one and a half times is warned of.
LEVEL_WORDS = {"A1": 700, "A2": 900, "B1": 1200}
B1_TOTAL = (2000, 3500)
# A course's phrasebook (words-rules-sentences.md, section 1).
PHRASEBOOK_SIZE = (15, 25)
# Parts of speech whose several-word cards still count as one word.
LEXICAL_POS = {"noun", "verb", "adj", "adv", "pronoun"}
# Scripts written without spaces, whose words bases cannot find yet.
NO_SPACES = {"han", "kana", "thai"}

ROOT = Path(__file__).resolve().parent.parent


class DeckResolver(yaml.resolver.BaseResolver):
    """Plain scalars as YAML 1.2's core schema reads them, which is how the
    app's `package:yaml` reads them: `yes`, `no`, `on` and `off` are
    strings, `060` is 60, and `1_000` is a string. PyYAML's own resolver
    follows YAML 1.1, so without this the validator and the app would read
    the same deck differently."""


for _tag, _pattern in (
    ("bool", r"(?:true|True|TRUE|false|False|FALSE)\Z"),
    ("int", r"(?:[-+]?[0-9]+|0o[0-7]+|0x[0-9a-fA-F]+)\Z"),
    ("float", r"(?:[-+]?(?:\.[0-9]+|[0-9]+(?:\.[0-9]*)?)(?:[eE][-+]?[0-9]+)?"
              r"|[-+]?\.(?:inf|Inf|INF)|\.(?:nan|NaN|NAN))\Z"),
    ("null", r"(?:null|Null|NULL|~|)\Z"),
):
    DeckResolver.add_implicit_resolver(f"tag:yaml.org,2002:{_tag}",
                                       re.compile(_pattern), None)


class DeckLoader(yaml.reader.Reader, yaml.scanner.Scanner, yaml.parser.Parser,
                 yaml.composer.Composer, yaml.constructor.SafeConstructor,
                 DeckResolver):
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
        yaml.constructor.SafeConstructor.__init__(self)
        DeckResolver.__init__(self)

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
                    and key_node.value == "<<" and key_node.style is None):
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


DeckLoader.add_constructor("tag:yaml.org,2002:int", DeckLoader.construct_yaml_int)


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


@dataclass
class TableInfo:
    """A rules core's table, for the rows check across files."""
    pos: list[str]
    tags: list[str]
    excepted: list[str]
    rows: list[str]            # the rows' words, card ids
    script: str


@dataclass
class Unit:
    """A unit of a course path, list or mapping (ADR-0035)."""
    i: int
    decks: list[str]           # its written decks, without "*"
    mapping: bool = False
    planned: dict | None = None    # {id, theme, grammar} of a planned unit
    words: int | None = None   # its planned size in words
    grammar: list[str] = field(default_factory=list)
    milestone: str | None = None
    exempt: bool = False       # an alphabet unit, or "*" alone


@dataclass
class PathPlan:
    lang: str
    native: str
    units: list[Unit]
    alphabet: list[str]
    has_plan: bool
    marks: dict[str, int]      # milestone -> the unit it is on, when in order
    end: int                   # the last unit up to B1


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
    # For the course paths (#117, ADR-0013): the (language, native, id) of a
    # vocab or grammar deck, and the (language, native, deck ids) a path
    # file lists, in order.
    course_deck: tuple[str, str, str] | None = None
    course_path: tuple[str, str, list[str]] | None = None
    # For the language icons (ADR-0027): a deck's language code and the icon
    # it gives, or None, for the check that a language's decks agree.
    icon: tuple[str, str | None] | None = None
    # A path's units that end in the wildcard and list decks of their own,
    # each as its deck ids, for the check that one of them has a theme.
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
    # For reading decks (#98, ADR-0019): the unit each deck of a path is in;
    # the words a vocab or grammar deck teaches; and a reading deck's
    # passages, as (id, theme, words in its sentences, words it glosses).
    course_units: tuple[str, str, dict[str, int]] | None = None
    taught_words: tuple[str, str, set[str]] | None = None
    passages: tuple[str, str, list[tuple[str, str | None, list[str], set[str]]]] | None = None
    # The B1 format (ADR-0035). `part` is "core", "layer" or None (a
    # single-file deck, or another file); `core_id` a layer's core.
    part: str | None = None
    core_id: str | None = None
    infos: list[str] = field(default_factory=list)
    # Pair notes' partners, (ref, where, i), and bases' cards, (ref, where,
    # the base's place, such as `bases[0]`), each checked across files.
    note_refs: list[tuple[str, str, int]] = field(default_factory=list)
    base_refs: list[tuple[str, str, str]] = field(default_factory=list)
    # The rule ids a card's `rules` names: (rule id, where).
    card_rules: list[tuple[str, str]] = field(default_factory=list)
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
    # A rules core: its rules, (id, where), and its table.
    rules_defined: list[tuple[str, str]] = field(default_factory=list)
    table: TableInfo | None = None
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

    def error(self, where: str, msg: str) -> None:
        self.errors.append(f"{where}: {msg}")

    def warn(self, where: str, msg: str) -> None:
        self.warnings.append(f"{where}: {msg}")

    def info(self, where: str, msg: str) -> None:
        self.infos.append(f"{where}: {msg}")


def _is_str(v: object) -> bool:
    return isinstance(v, str) and v.strip() != ""


def _check_str_list(r: Report, where: str, key: str, value: object) -> None:
    if not isinstance(value, list):
        r.error(where, f"{key} must be a list")
        return
    for i, item in enumerate(value):
        if not _is_str(item):
            r.error(where, f"{key}[{i}] must be a non-empty string")


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
    tts = block.get("tts")
    if tts is not None and (not _is_str(tts) or not BCP47_RE.fullmatch(tts)):
        r.error(where, f"tts must be a BCP-47 tag, got {tts!r}")
    if full and tts is None:
        r.warn(where, "no tts tag; the device will pick a default regional voice")
    if "rtl" in block and not isinstance(block["rtl"], bool):
        r.error(where, "rtl must be a boolean")
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


def check_card(r: Report, idx: int, card: object, seen: set[str],
               script: str, lang: str, *, form: str = "single",
               key: str | None = None) -> None:
    """A card of a single-file deck (`form` "single"), of a core ("core"), or
    a layer's own card ("layer"), whose id is its key in the layer's
    `cards` mapping. A core card has the language side only (ADR-0035)."""
    where = f"cards[{idx}]" if key is None else f"cards.{key}"
    if not isinstance(card, dict):
        r.error(where, "must be a mapping")
        return
    id_re = card_id_re(lang)
    core = form == "core"

    if "ref" in card and form != "layer":
        check_ref(r, idx, card, seen, id_re, form=form, lang=lang, script=script)
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

    allowed = CORE_CARD_KEYS if core else CARD_KEYS - ({"id"} if form == "layer" else set())
    for unknown in sorted(set(card) - allowed, key=str):
        if core and unknown in NATIVE_SIDE:
            r.error(where, f"a core card's {unknown!r} is in each layer, under "
                           f"cards.{cid}")
        elif core and unknown == "pair":
            r.error(where, 'pair: in a core file a pair note names the partner, '
                           '{ kind: "pair", ref: ... }; Hear takes its sound-alike '
                           'from there')
        else:
            r.error(where, f"unknown field {unknown!r}")

    for key in ("target", "reading") if core else ("target", "native", "reading"):
        val = card.get(key)
        if key == "reading" and val is None:
            continue
        if isinstance(val, bool):
            # YAML 1.1 resolves no/yes/on/off/true/false to booleans. This bites
            # romanisation decks hard: the hiragana の romanises to "no".
            r.error(where, f"{key} parsed as the boolean {val!r} -- YAML read a "
                           f"bare no/yes/on/off as a bool. Quote the value.")
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

    _check_optional_text(r, where, card, "gender")
    notes = check_notes(r, where, card.get("notes"), cid, lang, script, core=core)
    _check_optional_text(r, where, card, "audio")

    pos = card.get("pos")
    if pos is not None and pos not in POS:
        r.error(where, f"pos must be one of {sorted(POS)}, got {pos!r}")

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

    if "phrasebook" in card and card["phrasebook"] is not True:
        r.error(where, f"phrasebook must be true, unquoted, or left out; got "
                       f"{card['phrasebook']!r}")
    if "wiktionary" in card and not core:
        _check_wiktionary(r, where, "", card["wiktionary"])
    if "rules" in card:
        _check_card_rules(r, where, card["rules"], lang)

    target = card.get("target")
    bases = check_bases(r, where, "", card.get("bases"),
                        target if _is_str(target) else None, cid, lang, script,
                        core=core)
    examples = _check_examples(r, where, card.get("examples"), form=form,
                               cid=cid, lang=lang, script=script)
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
            notes=notes, pair=partner, single=not core))


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
    """A rule id names the language and the rule (ADR-0035)."""
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
        if kind == "pair":
            if not _is_str(ref) or not id_re.fullmatch(ref):
                r.error(where, f"{p}.ref: a pair note names its partner, the id of "
                               f"another {lang} card, got {ref!r}")
                ref = None
            elif ref == cid:
                r.error(where, f"{p}.ref names the card itself")
                ref = None
            else:
                r.note_refs.append((ref, where, i))
        else:
            if "ref" in note:
                r.error(where, f"{p}.ref is only for a pair note")
            ref = None
        source = note.get("source")
        if kind == "culture":
            r.culture = True
        if kind == "culture" and not _is_str(source):
            r.error(where, f"{p}.source: a culture note names where its claims can "
                           f"be checked")
        elif "source" in note and not _is_str(source):
            r.error(where, f"{p}.source must be text, got {source!r}")
        words = check_note_words(r, where, f"{p}.words", note.get("words"), script)
        if not core and isinstance(text, str):
            check_placeholders(r, where, f"{p}.text ", text, words, "note")
        found.append(Note(i, nid if nid is not None else str(i + 1), kind or "note", ref))
    return found


def check_bases(r: Report, where: str, prefix: str, bases: object,
                text: str | None, cid: str | None, lang: str, script: str, *,
                core: bool) -> list[dict]:
    """A card's or an example's `bases`: the base word of each derived word
    in its text, by the card that teaches it or written in full (ADR-0035).
    Returns the well-formed entries."""
    if bases is None:
        return []
    if not isinstance(bases, list):
        r.error(where, f"{prefix}bases must be a list of {{ word, ref }} or "
                       f"{{ word, base, reading }}")
        return []
    of = "the target" if not prefix else f"{prefix}target"
    words = {_key(w) for w in _words(text)} if text is not None else None
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
                r.base_refs.append((ref, where, p))
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
                    lang: str = "xx", script: str = "other"
                    ) -> list[tuple[int, str, list[dict]]]:
    """A card's examples. In a core an example has its language side only,
    and each layer names it by its target. Returns (place, target, bases)
    of each well-formed example."""
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
        for key in ("reading", "ipa"):
            if key in ex and not _is_str(ex.get(key)):
                r.error(where, f"examples[{j}].{key} must be a non-empty "
                               f"string or omitted")
        bases = check_bases(r, where, f"examples[{j}].", ex.get("bases"),
                            ex["target"], cid, lang, script, core=form == "core")
        found.append((j, ex["target"], bases))
    return found


def check_ref(r: Report, idx: int, card: dict, seen: set[str],
              id_re: re.Pattern[str], *, form: str = "single", lang: str = "xx",
              script: str = "other") -> None:
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
    check_notes(r, where, card.get("notes"), rid, lang, script, core=core)
    _check_modes(r, where, card.get("modes"))
    if "wiktionary" in card and not core:
        _check_wiktionary(r, where, "", card["wiktionary"])
    _check_examples(r, where, card.get("examples"), form=form, cid=rid, lang=lang,
                    script=script)
    # A core's refs are only checked to exist: whether a learner sees one is
    # the merge's (ADR-0035), not an error.
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
        for key in ("name", "slot_name", "prompt"):
            if not _is_str(pattern.get(key)):
                r.error(where, f"{key} is required")
        _check_optional_text(r, where, pattern, "notes")

    prompt = pattern.get("prompt")
    if _is_str(prompt) and not core:
        for token in re.findall(r"\{(\w+)\}", prompt):
            if token not in ("lemma", "gloss", "slot"):
                r.error(where, f"prompt uses unknown placeholder {{{token}}}")
        if "{slot}" not in prompt:
            r.warn(where, "prompt has no {slot}; every cell will look identical")

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
    adds (ADR-0025)."""
    for ipa in sorted(set(_ipas_in(raw))):
        if ipa != unicodedata.normalize("NFC", ipa):
            r.error("ipa", f"{ipa!r} is not NFC-normalised")
        elif ipa != ipa.strip() or not IPA_RE.fullmatch(ipa):
            r.error("ipa", f"{ipa!r} is not a broad IPA transcription: IPA "
                           f"letters and marks only, without / / or [ ]")


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
        raw = yaml.load(file.read_text(encoding="utf-8"), Loader=DeckLoader)
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


def _code_error(value: object) -> str:
    if isinstance(value, bool):
        return (f"got the boolean {value!r} -- YAML read a bare no/yes/on/off "
                f"as a bool. Quote the code.")
    return f"got {value!r}"


def check_facts(r: Report, facts: object) -> None:
    """A language's daily facts. See "Facts files" in docs/DECK-FORMAT.md."""
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

    if universal < MIN_FACTS:
        r.error("facts", f"needs at least {MIN_FACTS} facts without a contrast, "
                         f"true whatever the interface language; has {universal}")
    for code, count in sorted(universal_by_language.items()):
        if count < MIN_FACTS:
            r.warn("facts", f"only {count} facts without a contrast have {code!r} "
                            f"text, so learners with that interface language get "
                            f"{count} daily facts, not {MIN_FACTS}")


# --- Transliteration in prose ------------------------------------------------
# "Always keep the transliteration, even in descriptions or labels" (owner,
# 2026-10-06): a word in a script other than Latin, quoted in a deck's notes,
# meanings, labels or explanations, is followed by its reading in
# parentheses, లేదు (lēdu), or follows it, lēdu (లేదు). A learner who cannot
# read the script yet can read the note. See docs/DECK-FORMAT.md.

_SCRIPT = ("ऀ-෿Ͱ-ϿЀ-ӿ֐-׿؀-ۿ"
           "฀-๿぀-ヿ一-鿿가-힯")
_SCRIPT_CHAR = re.compile(f"[{_SCRIPT}]")
_SCRIPT_RUN = re.compile(
    rf"-?[{_SCRIPT}](?:[{_SCRIPT}‌‍]|[ -](?=[{_SCRIPT}]))*(?:-(?!\w))?")
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
                 "sinhala": 0x0D80}
# Keys whose values are the word itself, not prose about it.
_WORD_KEYS = {"id", "key", "target", "reading", "readings", "ipa", "ipas",
              "term", "example", "letters", "letter", "forms", "alternatives",
              "answer", "answers", "accept", "equivalents", "words", "tiles",
              "source", "scheme", "audio",
              # The B1 format's (ADR-0035): a base's word, a card or a rule
              # named by id.
              "word", "base", "ref", "core", "except", "rules", "part"}


def _script_runs(text: str):
    """Each run of one non-Latin script in [text], with where it starts."""
    for m in _SCRIPT_RUN.finditer(text):
        start, run, block = m.start(), "", None
        for i, ch in enumerate(m.group(0)):
            mark = unicodedata.category(ch).startswith("M")
            b = ord(ch) >> 7 if _SCRIPT_CHAR.match(ch) and not mark else None
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
        if own is not None and ord(first) >> 7 == own >> 7:
            continue
        if code not in (None, "en"):
            if code in _CODE_BLOCK and ord(first) >> 7 == _CODE_BLOCK[code] >> 7:
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
                                             "alternatives") for k in keys[:-1]):
                return
            if key == "text" and "passages" in keys:
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


def validate(path: Path) -> Report:
    r = Report(path)
    try:
        raw = yaml.load(path.read_text(encoding="utf-8"), Loader=DeckLoader)
    except yaml.YAMLError as exc:
        r.error("yaml", str(exc).replace("\n", " "))
        return r
    except UnicodeDecodeError as exc:
        r.error("encoding", f"file is not valid UTF-8: {exc}")
        return r

    if not isinstance(raw, dict):
        r.error("root", "deck must be a YAML mapping")
        return r

    # What the file is, before any other check (ADR-0035): a layer, a core,
    # or anything else as today.
    if raw.get("kind") == "layer":
        validate_layer(r, raw, path)
        return r
    if raw.get("part") == "core":
        validate_core(r, raw, path)
        return r
    if "part" in raw:
        r.error("part", f'must be "core", or left out on a single-file deck; got '
                        f'{raw["part"]!r}')

    if raw.get("kind") != "romanisation":
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
    check_romanised(r, raw, path)
    check_ipa(r, raw)
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

    if not _is_str(raw.get("name")):
        r.error("name", "is required")
    if not _is_str(raw.get("license")):
        r.error("license", "is required (SPDX identifier, or CC0-1.0)")

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
    if kind != "facts":
        check_langblock(r, "native", raw.get("native"), full=False)
        lang = raw.get("language")
        if isinstance(lang, dict) and _is_str(lang.get("code")):
            icon = lang.get("icon")
            r.icon = (lang["code"], icon if _is_str(icon) else None)
    elif "native" in raw:
        r.error("native", "a facts file has no native: each fact carries its text "
                          "in every language it is written in")

    lang = raw.get("language")
    native = raw.get("native")
    if kind != "facts" and _is_str(deck_id) and isinstance(lang, dict) \
            and isinstance(native, dict) \
            and _is_str(lang.get("code")) and _is_str(native.get("code")):
        # A deck is a course, "Hindi from English", and its id says so.
        prefix = f"{lang['code']}-{native['code']}-"
        if not deck_id.startswith(prefix):
            r.error("id", f"must start with {prefix!r}, the language learned and then "
                          f"the language it is taught from, got {deck_id!r}")
        r.course_deck = (lang["code"], native["code"], deck_id)
        r.lang_code, r.native_code = lang["code"], native["code"]
    script = _script_of(lang)
    r.script = script

    _check_common_header(r, raw)

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
                check_card(r, i, card, seen, script, code if _is_str(code) else "xx")
            if r.number_taught is not None:
                r.number_taught[1].update(
                    w for d in r.card_defs.values() for t in d.words for w in t.split())
    elif kind == "facts":
        for key in ("cards", "pattern"):
            if key in raw:
                r.error(key, "a facts file uses facts, not cards or a pattern")
        check_facts(r, raw.get("facts"))
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
    if r.native_code is not None:
        for d in r.card_defs.values():
            d.natives = {r.native_code}
    return r


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
    a speaker checks it, then "reviewed": exactly one of them (ADR-0035)."""
    if not r.culture:
        return
    tags = raw.get("tags") if isinstance(raw.get("tags"), list) else []
    if "reviewed" in tags and "unreviewed" in tags:
        r.error("tags", '"reviewed" and "unreviewed" together; a deck is one or '
                        'the other')
    elif "reviewed" not in tags and "unreviewed" not in tags:
        r.error("tags", 'has culture notes, so it is tagged "unreviewed" until a '
                        'speaker checks them, then "reviewed" (#99)')


# --- Cores and layers (ADR-0035) ---------------------------------------------

def _load_raw(path: Path) -> object:
    try:
        return yaml.load(path.read_text(encoding="utf-8"), Loader=DeckLoader)
    except (OSError, UnicodeDecodeError, yaml.YAMLError):
        return None


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
            raw = _load_raw(p)
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
    dirs = _unique_dirs(path.parent, ROOT / "decks" / lang)
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
    check_transliterated(r, raw, fixed=code or "", own=_SCRIPT_BLOCK.get(_script_of(lang)),
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
        r.error("license", "is required (SPDX identifier, or CC0-1.0)")
    _check_common_header(r, {k: v for k, v in raw.items() if k != "description"})

    script = _script_of(lang)
    r.script, r.deck_kind, r.lang_code = script, kind, code
    r.core_id = raw.get("id") if _is_str(raw.get("id")) else None
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
                check_card(r, i, card, seen, script, lc, form="core")
            r.core_cards = [(cid, c.written) for cid, c in _core_index(raw, lc).items()]
    elif kind == "grammar":
        if "pattern" not in raw:
            r.error("pattern", "is required on a grammar deck")
        else:
            check_pattern(r, raw["pattern"], core=True)
    elif kind == "rules":
        check_rules_core(r, raw, lc, script)
    _check_review_tags(r, raw)


def check_rules_core(r: Report, raw: dict, lang: str, script: str) -> None:
    """A rules deck's core: one table, whose rows are words of one kind with
    every form listed, and whose columns belong to its rules (ADR-0035)."""
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
                            list(dict.fromkeys(words)), script)

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
        if not isinstance(card, dict):
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
        found[cid] = _CoreCard(
            written, notes, examples,
            _inline_words(card.get("bases")) if written else [],
            bool(card.get("notes")), bool(card.get("examples")))
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
    core = _load_raw(file)
    if not isinstance(core, dict) or core.get("part") != "core":
        r.error("core", f'{core_id}.yaml is not a core: it has no part: "core"')
        return
    r.core_id = core_id
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
        r.error("license", "is required (SPDX identifier, or CC0-1.0)")
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
    translated: set[str] = set()
    given: dict[str, tuple[set[str], set[str]]] = {}
    seen: set[str] = set(index)
    id_re = card_id_re(lang)
    for i, (cid, entry) in enumerate(cards.items()):
        if not isinstance(cid, str):
            continue
        where = f"cards.{cid}"
        known = index.get(cid)
        if known is None:
            if not id_re.fullmatch(cid):
                r.error(where, f"id must be {lang}- and at least four digits, such as "
                               f"{lang}-0001, got {cid!r}")
            elif not isinstance(entry, dict) or "target" not in entry:
                r.error(where, f"{cid} is not a card of {core_id}; a card only this "
                               f"layer has gives its target too")
            else:
                check_card(r, i, entry, seen, script, lang, form="layer", key=cid)
            continue
        gives, notes, examples = _check_layer_entry(r, where, cid, entry, known, nname)
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
        check_card(scratch, i, card, set(), script, lang, form="core")
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
            pair=next((n.ref for n in kept if n.kind == "pair"), None), single=False))


def _check_layer_entry(r: Report, where: str, cid: str, entry: object,
                       known: _CoreCard, nname: str
                       ) -> tuple[bool, set[str], set[str]]:
    """A layer's entry for a card or ref of its core. Returns whether it
    gives a native, and the note ids and example targets it gives text to."""
    if not isinstance(entry, dict):
        r.error(where, "must be a mapping")
        return False, set(), set()
    for unknown in sorted(set(entry) - LAYER_ENTRY_KEYS, key=str):
        r.error(where, f"{unknown!r} belongs to the word, in the core; a layer gives "
                       f"native, alt_native, notes, examples, bases and wiktionary")
    native = entry.get("native")
    if "native" in entry:
        if isinstance(native, bool):
            r.error(where, f"native parsed as the boolean {native!r} -- YAML read a "
                           f"bare no/yes/on/off as a bool. Quote the value.")
        elif not _is_str(native):
            r.error(where, "native must be a non-empty string")
    elif known.written:
        r.error(where, f"native is required: without it the card is not taught from "
                       f"{nname}")
    gives = _is_str(native)
    if "alt_native" in entry:
        _check_str_list(r, where, "alt_native", entry["alt_native"])
    if "wiktionary" in entry:
        _check_wiktionary(r, where, "", entry["wiktionary"])
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
    if shown:
        for nid in known.notes:
            if nid not in notes:
                r.warn(where, f"note {nid!r} has no text here, so learners from "
                              f"{nname} do not see it")

    examples: set[str] = set()
    named: set[str] = set()
    if "examples" in entry:
        ewhere = f"{where}.examples"
        value = entry["examples"]
        if not known.written and not known.has_examples:
            r.error(ewhere, f"the core lists {cid} by ref without examples; give them "
                            f"in the core's ref")
        elif not isinstance(value, dict):
            r.error(ewhere, "a mapping of an example's target, as the core writes it, "
                            "to its translation")
        else:
            for target, tr in value.items():
                if not isinstance(target, str):
                    continue
                named.add(target)
                if target != unicodedata.normalize("NFC", target):
                    r.error(ewhere, f"key {target!r} is not NFC-normalised")
                if target not in known.examples:
                    r.error(f"{ewhere}.{target}", "the core card has no example with "
                                                  "this target")
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
                        bases = _check_layer_bases(r, f"{twhere}.bases", tr["bases"],
                                                   known.examples[target])
                elif not _is_str(tr):
                    r.error(twhere, "must be the example's translation, or "
                                    "{ native, bases }")
                    continue
                examples.add(target)
                for word in known.examples[target]:
                    if word not in bases:
                        r.warn(where, f"the inline base {word!r} has no meaning here; "
                                      f"it is shown without one")
    if shown:
        for target in known.examples:
            if target not in named:
                r.warn(where, f"example {target!r} has no translation here, so it is "
                              f"not shown")

    bases = set()
    if "bases" in entry:
        bases = _check_layer_bases(r, f"{where}.bases", entry["bases"], known.bases)
    if shown:
        for word in known.bases:
            if word not in bases:
                r.warn(where, f"the inline base {word!r} has no meaning here; it is "
                              f"shown without one")
    return gives, notes, examples


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
                           "slot_name, prompt and glosses")
        return []
    for unknown in sorted(set(pattern) - LAYER_PATTERN_KEYS, key=str):
        r.error("pattern", f"unknown field {unknown!r}")
    for key in ("name", "slot_name", "prompt"):
        if not _is_str(pattern.get(key)):
            r.error("pattern", f"{key} is required")
    _check_optional_text(r, "pattern", pattern, "notes")
    _check_prompt(r, "pattern", pattern.get("prompt"))
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
    ক’রে, and without numbers. Never used to change what is stored."""
    words = []
    for chunk in text.split():
        spaced = "".join(
            " " if unicodedata.category(ch)[0] in "PSZ" and ch not in "’'" else ch
            for ch in chunk)
        for word in spaced.split():
            word = word.strip("’'")
            if word and not word.isdigit():
                words.append(unicodedata.normalize("NFC", word))
    return words


def _taught(raw: dict) -> set[str]:
    """Every word a vocab or grammar deck teaches, as [_words] splits them."""
    texts: list[object] = []
    for card in raw.get("cards") or []:
        if isinstance(card, dict):
            texts.append(card.get("target"))
            alts = card.get("alt_target")
            texts.extend(alts if isinstance(alts, list) else [])
            for ex in card.get("examples") or []:
                if isinstance(ex, dict):
                    texts.append(ex.get("target"))
    pattern = raw.get("pattern")
    if isinstance(pattern, dict):
        for entry in pattern.get("entries") or []:
            if isinstance(entry, dict):
                texts.append(entry.get("lemma"))
                forms = entry.get("forms")
                texts.extend(forms.values() if isinstance(forms, dict) else [])
    return {w for t in texts if isinstance(t, str) for w in _words(t)}


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
                       f"bare no/yes/on/off as a bool. Quote the value.")
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
        _check_optional_text(r, where, passage, "source")
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
        if not isinstance(theme, dict) or set(theme) - {"id", "name"}:
            r.error(where, "must be a mapping with only an id and a name")
            continue
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


def check_path_file(r: Report, raw: dict, path: Path) -> None:
    """A course's curated path, decks/<lang>/<lang>-<native>-path.yaml: its
    decks in teaching order, in units. See ADR-0013."""
    for unknown in sorted(set(raw) - PATH_KEYS):
        r.error("root", f"unknown field {unknown!r} in a path file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    lang, native = raw.get("language"), raw.get("native")
    codes_ok = True
    for key, value in (("language", lang), ("native", native)):
        if not isinstance(value, str) or not CODE_RE.fullmatch(value):
            r.error(key, f"must be a language code such as 'hi', {_code_error(value)}")
            codes_ok = False
    path_id = raw.get("id")
    if path_id != path.stem:
        r.error("id", f"is {path_id!r} but the filename stem is {path.stem!r}")
    if codes_ok and path_id != f"{lang}-{native}-path":
        r.error("id", f"a path for {lang} from {native} has id "
                      f"{lang}-{native}-path, got {path_id!r}")
    _check_optional_text(r, "root", raw, "description")
    units = raw.get("units")
    if not isinstance(units, list) or not units:
        r.error("units", "must be a non-empty list")
        return
    listed: list[str] = []
    unit_of: dict[str, int] = {}
    parsed: list[Unit] = []
    sized: set[int] = set()

    def check_decks(where: str, i: int, unit: object) -> list[str] | None:
        """A unit's decks, today's list form. Returns them without the
        wildcard, or None for the wildcard alone."""
        if not isinstance(unit, list) or not unit:
            r.error(where, "must be a non-empty list of deck ids")
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
            if not _is_str(deck) or not ID_RE.fullmatch(deck):
                r.error(where, f"must list deck ids, got {deck!r}")
            elif deck in listed:
                r.error(where, f"deck {deck!r} is listed twice")
            else:
                listed.append(deck)
                unit_of[deck] = i
                decks.append(deck)
        return None if unit == [WILDCARD] else decks

    # A path has a B1 plan when a unit is a mapping that plans (ADR-0035).
    has_plan = any(isinstance(u, dict) and any(k in u for k in
                                                ("planned", "words", "grammar", "milestone"))
                   for u in units)
    for i, unit in enumerate(units):
        where = f"units[{i}]"
        if isinstance(unit, list):
            decks = check_decks(where, i, unit)
            parsed.append(Unit(i, decks or [], exempt=decks is None))
        elif isinstance(unit, dict):
            parsed.append(_check_unit(r, where, i, unit, check_decks, sized,
                                      lang if codes_ok else "xx",
                                      native if codes_ok else "xx"))
        else:
            r.error(where, "must be a list of deck ids, or a mapping with decks or "
                           "planned")
            parsed.append(Unit(i, []))
    # The decks a learner who skips the alphabet leaves out: the script,
    # spelling and reading decks.
    alphabet = raw.get("alphabet", [])
    if not isinstance(alphabet, list):
        r.error("alphabet", "must be a list of deck ids on the path")
        alphabet = []
    else:
        for deck in alphabet:
            if deck not in listed:
                r.error("alphabet", f"lists {deck!r}, which the path does not")
    for u in parsed:
        if u.decks and u.planned is None and all(d in alphabet for d in u.decks):
            u.exempt = True
    marks, end = _check_plan(r, parsed, has_plan, sized, unit_of) if has_plan \
        else ({}, len(parsed) - 1)
    if codes_ok:
        r.course_path = (lang, native, listed)
        r.course_units = (lang, native, unit_of)
        r.plan = PathPlan(lang, native, parsed,
                          [d for d in alphabet if isinstance(d, str)], has_plan,
                          marks, end)


def _check_unit(r: Report, where: str, i: int, unit: dict, check_decks,
                sized: set[int], lang: str, native: str) -> Unit:
    """A unit written as a mapping: its decks, or the deck it plans, with
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
            prefix = f"{lang}-{native}-"
            if not _is_str(pid) or not ID_RE.fullmatch(pid) or not pid.startswith(prefix):
                r.error(f"{where}.planned.id", f"must be a deck id starting with "
                                               f"{prefix}, the course, got {pid!r}")
            else:
                u.planned["id"] = pid
            if "theme" in planned and "grammar" in planned:
                r.error(f"{where}.planned", "names theme or grammar, not both")
            elif "theme" not in planned and "grammar" not in planned:
                r.error(f"{where}.planned", "needs a theme or a grammar topic")
            if "theme" in planned:
                theme = planned["theme"]
                theme_unit = "grammar" not in planned
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
        least = 1 if theme_unit else 0
        if isinstance(value, bool) or not isinstance(value, int) or value < least:
            r.error(f"{where}.words", f"must be a whole number of words, {least} or "
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
            v = unit[key]
            if not isinstance(v, list) or not v or not all(_is_str(x) for x in v):
                r.error(f"{where}.{key}", "must be a non-empty list of short "
                                          "descriptions")
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


def check_sounds_file(r: Report, raw: dict, path: Path) -> None:
    """A language's sound contrasts, decks/<lang>/<lang>-sounds.yaml: pairs
    of letters or signs that change a word, for the speaking drill's
    feedback (#89). See ADR-0015."""
    for unknown in sorted(set(raw) - SOUNDS_KEYS):
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
        for unknown in sorted(set(contrast) - CONTRAST_KEYS):
            r.error(where, f"unknown field {unknown!r}")
        cid = contrast.get("id")
        if not _is_str(cid) or not ID_RE.fullmatch(cid):
            r.error(where, f"id must match [a-z0-9-]+, got {cid!r}")
        elif cid in ids:
            r.error(where, f"contrast {cid!r} is listed twice")
        else:
            ids.add(cid)
        if not _is_str(contrast.get("name")) or not contrast["name"].strip():
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


def check_script_file(r: Report, raw: dict, path: Path) -> None:
    """A script's guide, decks/<lang>/<lang>-script.yaml: the recurring
    features a learner from English misses, shown before the first script
    card (#30). See ADR-0016."""
    for unknown in sorted(set(raw) - SCRIPT_KEYS):
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
    guide_id = raw.get("id")
    if guide_id != path.stem:
        r.error("id", f"is {guide_id!r} but the filename stem is {path.stem!r}")
    elif lang is not None and guide_id != f"{lang}-script":
        r.error("id", f"a script guide for {lang} has id {lang}-script, got {guide_id!r}")
    for key in ("name", "intro"):
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
        for unknown in sorted(set(feature) - FEATURE_KEYS):
            r.error(where, f"unknown field {unknown!r}")
        fid = feature.get("id")
        if not _is_str(fid) or not ID_RE.fullmatch(fid):
            r.error(where, f"id must match [a-z0-9-]+, got {fid!r}")
        elif fid in ids:
            r.error(where, f"feature {fid!r} is listed twice")
        else:
            ids.add(fid)
        for key in ("name", "example", "text"):
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
    files of each language, read once per run (ADR-0035). Nothing is ever
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
            for rep in self.given))
        self._files: list[Report] | None = None
        self._paths: list[Report] | None = None
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

    def paths(self) -> dict[str, Report]:
        """Each course's path, by native: given, else on disk. Read without
        reading the language's other files."""
        if self._paths is None:
            if self._files is not None:
                on_disk = [rep for rep in self._files if rep.plan is not None]
            else:
                on_disk = [rep for p in self._on_disk("*-path.yaml")
                           if (rep := validate(p)).plan is not None
                           and rep.plan.lang == self.code]
            self._paths = [rep for rep in self.given if rep.plan is not None] + on_disk
        found: dict[str, Report] = {}
        for rep in self._paths:
            found.setdefault(rep.plan.native, rep)
        return found

    def planned(self) -> list[tuple[str, Report]]:
        """The courses whose path has a B1 plan, as (native, path)."""
        return sorted((native, rep) for native, rep in self.paths().items()
                      if rep.plan.has_plan) if self.paths() else []

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
        and its refs that resolve; a merged deck's included cards (ADR-0035)."""
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

    def b1_decks(self, native: str) -> list[tuple[str, int, Report | None]]:
        """The B1 decks of a course, in path order, each with its unit: the
        decks its path lists when the path has a B1 plan, less its alphabet
        decks and its reading decks."""
        path = self.paths().get(native)
        if path is None or not path.plan.has_plan:
            return []
        decks = self.decks(native)
        found = []
        for u in path.plan.units:
            for d in u.decks:
                rep = decks.get(d)
                if d in path.plan.alphabet or (rep is not None and rep.deck_kind == "reading"):
                    continue
                found.append((d, u.i, rep))
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
                raw = _load_raw(p)
                if isinstance(raw, dict) and raw.get("part") == "core":
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
    of the same native (ADR-0035)."""
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

    def find(rep: Report, cid: str) -> CardDef | None:
        found = defs.get(cid)
        if found is None and rep.lang_code is not None:
            found = ctx.lang(rep.lang_code).file_defs().get(cid)
        return found

    for rep in reports:
        for rid, has_native, where in rep.refs:
            found = find(rep, rid)
            if found is None:
                problems.append(f"{rep.path}: {where}: no deck writes card {rid}")
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
        for ref, where, place in rep.base_refs:
            if find(rep, ref) is None:
                problems.append(f"{rep.path}: {where}: {place}.ref names card {ref}, "
                                f"which no deck writes")
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


def check_paths_across(reports: list[Report]) -> list[str]:
    """A course has one path, which lists every deck of that course exactly
    once, and only that course's decks."""
    course_of = {rep.course_deck[2]: rep.course_deck[:2]
                 for rep in reports if rep.course_deck is not None}
    themed = {rep.course_deck[2] for rep in reports
              if rep.course_deck is not None and rep.theme_key is not None}
    problems = []
    seen: dict[tuple[str, str], Path] = {}
    for rep in reports:
        if rep.course_path is None:
            continue
        lang, native, listed = rep.course_path
        course = (lang, native)
        if course in seen:
            problems.append(f"{rep.path}: {lang} from {native} already has a path, "
                            f"{seen[course]}")
            continue
        seen[course] = rep.path
        for deck in listed:
            if deck not in course_of:
                problems.append(f"{rep.path}: lists {deck!r}, which is not a deck")
            elif course_of[deck] != course:
                problems.append(f"{rep.path}: lists {deck!r}, which teaches "
                                f"{course_of[deck][0]} from {course_of[deck][1]}")
        missing = sorted(deck for deck, c in course_of.items()
                         if c == course and deck not in listed)
        for deck in missing:
            problems.append(f"{rep.path}: does not list {deck!r}; every deck of "
                            f"{lang} from {native} is on its path")
        # A wildcard takes its unit's theme, so its unit needs a theme deck.
        # Only when the unit's decks are being validated too.
        for unit in rep.open_units:
            if all(deck in course_of for deck in unit) and not any(
                    deck in themed for deck in unit):
                problems.append(f"{rep.path}: the unit [{', '.join(unit)}] ends in "
                                f"{WILDCARD!r} but has no theme deck to say which "
                                f"decks it takes")

    # A course with a deck in this repository needs a path. A path not being
    # validated now, beside the deck on disk, counts: validating one deck is
    # legitimate. So is drafting one outside the repository, as check_bundled
    # also allows.
    root = ROOT
    pathless: dict[tuple[str, str], Path] = {}
    for rep in reports:
        if rep.course_deck is None or rep.course_deck[:2] in seen:
            continue
        lang, native, _ = rep.course_deck
        try:
            rep.path.resolve().relative_to(root)
        except ValueError:
            continue
        # A layer's course path is beside its core, in the folder above it.
        folder = rep.path.parent.parent if rep.part == "layer" else rep.path.parent
        if (folder / f"{lang}-{native}-path.yaml").exists():
            continue
        pathless.setdefault((lang, native), rep.path)
    for (lang, native), deck in pathless.items():
        problems.append(f"{deck}: {lang} from {native} has no path; add "
                        f"{lang}-{native}-path.yaml beside its decks")
    return problems


def check_reading_across(reports: list[Report]) -> list[str]:
    """A reading deck's passages against the rest of its course (#98).

    A passage's theme must be on the theme path. Two things are only
    warned of: a word in a passage that no deck of the course teaches, as
    [_words] splits them, glossed words aside; and a passage on the path in
    a unit no later than its theme's deck, whose new questions would then
    come before the words they use."""
    problems: list[str] = []
    listed = [rep for rep in reports if rep.themes is not None]
    known = set(listed[0].themes) if listed else None
    taught: dict[tuple[str, str], set[str]] = {}
    for rep in reports:
        if rep.taught_words is not None:
            lang, native, words = rep.taught_words
            taught.setdefault((lang, native), set()).update(words)
    theme_decks = {rep.theme_key: rep.course_deck[2] for rep in reports
                   if rep.theme_key is not None and rep.course_deck is not None}
    units = {rep.course_units[:2]: rep.course_units[2] for rep in reports
             if rep.course_units is not None}
    for rep in reports:
        if rep.passages is None or rep.course_deck is None:
            continue
        lang, native, passages = rep.passages
        course = (lang, native)
        unit_of = units.get(course, {})
        for pid, theme, words, glossed in passages:
            if theme is not None and known is not None and theme not in known:
                problems.append(f"{rep.path}: passage {pid}: theme {theme!r} is not "
                                f"in decks/themes.yaml")
            theme_deck = theme_decks.get((lang, native, theme))
            here, there = unit_of.get(rep.course_deck[2]), unit_of.get(theme_deck)
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


# --- The B1 checks across files (ADR-0035) -----------------------------------

def counts_as_word(card: object, deck_kind: str) -> bool:
    """Whether a card counts as one of a unit's words: a card of a vocab
    deck, not a phrasebook card or a phrase, whose target is one word or a
    several-word noun, verb, adjective, adverb or pronoun. The app's
    `countsAsWord` is the same."""
    if isinstance(card, dict):
        target, pos = card.get("target"), card.get("pos")
        phrasebook = card.get("phrasebook") is True
    else:
        target, pos, phrasebook = card.target, card.pos, card.phrasebook
    if deck_kind != "vocab" or phrasebook or pos == "phrase" or not isinstance(target, str):
        return False
    return len(_words(target)) == 1 or pos in LEXICAL_POS


def _languages(reports: list[Report]) -> list[str]:
    return sorted({code for rep in reports if (code := _lang_of(rep)) is not None})


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
    course teaches as a card, or has a `bases` entry."""
    ctx = _context(reports)
    given = {rep.path.resolve() for rep in reports}
    problems: list[str] = []
    seen: set[tuple] = set()
    for code in _languages(reports):
        lang = ctx.lang(code)
        for native, path in lang.planned():
            course = f"{code}-{native}"
            taught: set[str] = set()
            for c, drep in lang.taught(native).values():
                if drep.deck_kind != "vocab" or c.phrasebook:
                    continue
                for t in [c.target, *c.alt_targets]:
                    words = _words(t)
                    if len(words) == 1:
                        taught.add(_key(words[0]))
            for deck_id, ui, drep in lang.b1_decks(native):
                if drep is None or drep.deck_kind != "vocab":
                    continue
                if drep.script in NO_SPACES:
                    if path.path.resolve() in given and (deck_id, "spaces") not in seen:
                        seen.add((deck_id, "spaces"))
                        problems.append(f"{path.path}: units[{ui}]: {deck_id} is in the "
                                        f"{drep.script} script, written without spaces; "
                                        f"bases cannot be checked until the format gives "
                                        f"its words (OPEN-26)")
                    continue
                for c in list(drep.merged) + list(drep.cards):
                    if c.path.resolve() not in given:
                        continue
                    texts = [("", c.target, c.bases)] + [
                        (f"examples[{j}]: ", t, b) for j, t, b in c.examples]
                    for prefix, text, bases in texts:
                        have = {_key(b["word"]) for b in bases}
                        for w in dict.fromkeys(_words(text)):
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


def check_phrasebook_across(reports: list[Report]) -> list[str]:
    """A course's phrasebook: 15 to 25 cards, counted per course, and, where
    its path has a B1 plan, taught in the path's first unit."""
    ctx = _context(reports)
    given = {rep.path.resolve() for rep in reports}
    problems: list[str] = []
    courses: set[tuple[str, str]] = set()
    for rep in reports:
        if rep.plan is not None:
            courses.add((rep.plan.lang, rep.plan.native))
        elif rep.course_deck is not None and any(c.phrasebook for c in rep.merged + rep.cards):
            courses.add(rep.course_deck[:2])
    for code, native in sorted(courses):
        lang = ctx.lang(code)
        path = lang.paths().get(native)
        has_plan = path is not None and path.plan.has_plan
        if not has_plan and not any(c.phrasebook for rep in lang.given
                                    for c in rep.merged + rep.cards) \
                and not _mentions(lang, "phrasebook"):
            continue
        decks = lang.decks(native)
        order = [d for u in path.plan.units for d in u.decks] if path is not None else []
        order += sorted(d for d in decks if d not in order)
        cards_of = {d: {c.id: c for c in lang.deck_cards(decks[d])}
                    for d in order if d in decks}
        phrasebook = list(dict.fromkeys(cid for d in order if d in cards_of
                                        for cid, c in cards_of[d].items() if c.phrasebook))
        n = len(phrasebook)
        if n == 0 and not has_plan:
            continue
        lo, hi = PHRASEBOOK_SIZE
        if not lo <= n <= hi:
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
        first = next((u for u in path.plan.units if not u.exempt), None)
        if first is None:
            continue
        in_first = {cid for d in first.decks if d in cards_of for cid in cards_of[d]}
        for cid in phrasebook:
            if cid in in_first:
                continue
            for u in path.plan.units:
                d = next((d for d in u.decks if cid in cards_of.get(d, {})), None)
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
                decks: dict[str, Report]) -> int:
    """A unit's words: the distinct cards that count as words, written or
    listed by ref in its decks, its alphabet decks left out."""
    tcards = lang.tcards()
    ids: set[str] = set()
    for d in u.decks:
        drep = decks[d]
        if d in plan.alphabet or drep.deck_kind != "vocab":
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
    language has a core, and its sizes (warnings and an info line)."""
    ctx = _context(reports)
    problems: list[str] = []
    themes = [rep for rep in reports if rep.themes is not None]
    known = set(themes[0].themes) if themes else None
    for rep in reports:
        plan = rep.plan
        if plan is None:
            continue
        lang = ctx.lang(plan.lang)
        if not plan.has_plan:
            core = lang.first_core()
            if core is not None:
                problems.append(f"{rep.path}: units: {plan.lang} has core files ({core}), "
                                f"so this path needs its B1 plan: the milestones A1, A2 "
                                f"and B1, in that order")
            continue
        native = plan.native
        decks = lang.decks(native)
        for u in plan.units:
            pid = u.planned["id"] if u.planned is not None else None
            if pid is None:
                continue
            found = next((o.path for o in reports if o.course_deck is not None
                          and o.course_deck[2] == pid), None)
            if found is None:
                for cand in [rep.path.parent / f"{pid}.yaml",
                             *sorted(rep.path.parent.glob(f"*/{pid}.yaml"))]:
                    raw = _load_raw(cand) if cand.is_file() else None
                    if isinstance(raw, dict) and raw.get("part") != "core":
                        found = cand
                        break
            if found is not None:
                problems.append(f"{rep.path}: units[{u.i}].planned.id: {pid} already "
                                f"exists ({found}); list it under decks in place of "
                                f"planned")
        for u in plan.units:
            if u.planned is not None or not u.grammar or not u.decks \
                    or any(d not in decks for d in u.decks):
                continue
            rules = {rid for d in u.decks for rid in decks[d].core_rules}
            for t in u.grammar:
                if f"{plan.lang}-rule-{t}" in rules \
                        or f"{plan.lang}-{native}-grammar-{t}" in u.decks:
                    continue
                problems.append(f"{rep.path}: units[{u.i}].grammar: {t!r} is taught by "
                                f"none of the unit's decks; name a rule "
                                f"({plan.lang}-rule-{t}) of a rules deck it lists, or a "
                                f"deck {plan.lang}-{native}-grammar-{t} it lists")

        for d, ui, drep in lang.b1_decks(native):
            if drep is not None and drep.part is None:
                rep.warn(f"units[{ui}]", f"{d} is a single-file deck; a deck in a B1 "
                                         f"plan is split into a core and its layers as "
                                         f"the plan is written")
        for u in plan.units:
            if u.planned is None and u.words is not None and u.decks \
                    and all(d in decks for d in u.decks):
                n = _unit_words(lang, u, plan, decks)
                if n > u.words:
                    rep.warn(f"units[{u.i}]", f"has {n} words, more than the {u.words} "
                                              f"planned; raise words")
        total = sum(u.words or 0 for u in plan.units if u.i <= plan.end)
        if not B1_TOTAL[0] <= total <= B1_TOTAL[1]:
            rep.warn("units", f"plans {total} words up to B1, outside 2,000–3,500; "
                              f"check the sizes")
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
            rep.info("units", f"B1 plan: A1 {sizes['A1']} words (about 700), A2 "
                              f"+{sizes['A2']} (about 900), B1 +{sizes['B1']} (about "
                              f"1,200); {sum(sizes.values())} in all; {len(topics)} "
                              f"grammar topics; {planned} units planned")
            for level, n in sizes.items():
                size = LEVEL_WORDS[level]
                lo, hi = size // 2, size * 3 // 2
                if not lo <= n <= hi:
                    rep.warn("units", f"{level} plans {n} words, far from about "
                                      f"{size:,} ({lo:,}–{hi:,})")
    return problems


def collect(target: Path) -> list[Path]:
    if target.is_file():
        return [target]
    return sorted(p for p in target.rglob("*.yaml") if "schema" not in p.parts)


# Language directories kept in the repository, and validated like any other,
# but left out of the app on purpose, so that check_bundled does not ask for
# their pubspec.yaml entry. Remove a line when its directory goes back under
# flutter.assets.
NOT_BUNDLED = {
    # Hidden for now: the app teaches Spanish and the Indic languages.
    "decks/ja",
    # The validator's own fixtures, a B1 core and layers in a made-up
    # language (tools/test_validate_b1.py); never part of the app.
    "tools/fixtures/b1/zz",
    "tools/fixtures/b1/zz/en",
}


def check_bundled(paths: list[Path]) -> list[str]:
    """Every language directory holding a deck must be a Flutter asset entry.

    A Flutter asset entry bundles only the files directly inside the directory
    it names, so `- decks/` does not reach `decks/es/`. A language missing from
    the list ships as an app with that language silently absent — it builds, it
    validates, and it is only visible on a device. Checking it here is cheaper
    than finding it there. The directories in NOT_BUNDLED are absent on
    purpose, and are not asked for.

    Everything here is resolved against the repository root rather than the
    working directory. A check that quietly passes when run from the wrong
    directory is worse than no check, because it is trusted.
    """
    root = Path(__file__).resolve().parent.parent
    pubspec = root / "pubspec.yaml"
    if not pubspec.exists():
        return []
    try:
        declared = yaml.safe_load(pubspec.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        return [f"{pubspec} is not valid YAML: {exc}"]

    entries = ((declared or {}).get("flutter") or {}).get("assets") or []
    have = {str(e).strip().rstrip("/") for e in entries}

    problems = []
    unbundled: dict[str, None] = {}
    for p in sorted(paths):
        try:
            file = p.resolve().relative_to(root).as_posix()
        except ValueError:
            # Outside the repository, so nothing in pubspec.yaml could bundle
            # it. Validating a deck from elsewhere is legitimate; claiming it
            # is unbundled is not.
            continue
        directory = file.rsplit("/", 1)[0]
        if directory in NOT_BUNDLED:
            continue
        # A directory entry bundles the files directly inside it; a file
        # entry, such as decks/themes.yaml, bundles just that file.
        if directory not in have and file not in have:
            unbundled[directory] = None
    for wanted in unbundled:
        problems.append(
            f"{wanted}/ holds decks but pubspec.yaml does not bundle it — "
            f"add `- {wanted}/` under flutter.assets"
        )
    return problems


def main(argv: list[str]) -> int:
    if len(argv) == 3 and argv[1] == "--next-id":
        if not LANG_RE.fullmatch(argv[2]):
            print(f"error: {argv[2]!r} is not a language code", file=sys.stderr)
            return 2
        print(next_card_id(argv[2]))
        return 0
    targets = [Path(a) for a in argv[1:]] or [Path("decks")]
    paths: list[Path] = []
    for t in targets:
        if not t.exists():
            print(f"error: {t} does not exist", file=sys.stderr)
            return 2
        paths.extend(collect(t))

    if not paths:
        print("error: no deck files found", file=sys.stderr)
        return 2

    reports = [validate(p) for p in paths]

    ids: dict[str, Path] = {}
    for p in paths:
        if p.stem in ids:
            print(f"error: duplicate deck id {p.stem!r}: {ids[p.stem]} and {p}")
            return 1
        ids[p.stem] = p

    unbundled = check_bundled(paths)
    for problem in unbundled:
        print(f"error: {problem}")
    across = (check_themes_across(reports) + check_cards_across(reports)
              + check_layers_across(reports)
              + check_numbers_across(reports) + check_paths_across(reports)
              + check_reading_across(reports) + check_icons_across(reports)
              + check_rules_across(reports) + check_notes_across(reports)
              + check_bases_across(reports) + check_phrasebook_across(reports)
              + check_plans_across(reports))
    for problem in across:
        print(f"error: {problem}")

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
    return 1 if failed or unbundled or across else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
