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
         "reading"}
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
MODES = {"recognition", "production", "listening", "grammar", "speaking"}
POS = {"noun", "verb", "adj", "adv", "phrase", "particle", "other"}

HEADER_KEYS = {
    "schema", "id", "name", "kind", "language", "native", "license",
    "authors", "source", "description", "tags", "cards", "pattern", "facts",
    "theme", "passages",
}
CARD_KEYS = {
    "id", "target", "native", "reading", "ipa", "alt_target", "alt_native",
    "pos", "gender", "tags", "notes", "audio", "examples", "modes", "pair",
}
# A ref lists a card written in another deck (ADR-0018). It may give its own
# native-side fields; what the card is in the language learned stays the
# card's own.
REF_KEYS = {
    "ref", "native", "reading", "ipa", "alt_native", "tags", "notes",
    "examples", "modes",
}
PATTERN_KEYS = {"name", "slot_name", "slots", "prompt", "entries", "notes"}
FACT_KEYS = {"id", "text", "contrast", "tags", "source"}
PASSAGE_KEYS = {"id", "title", "sentences", "source", "theme", "questions", "glossary"}
SENTENCE_KEYS = {"text", "reading", "ipa"}
QUESTION_KEYS = {"id", "prompt", "options", "answer"}
GLOSS_KEYS = {"word", "modern", "reading", "ipa", "meaning", "note"}
EXAMPLE_KEYS = {"target", "native", "reading", "ipa"}
# A reading question has this many options, and a passage this many
# questions (#98, ADR-0019).
CHOICES = range(2, 5)


class DeckLoader(yaml.SafeLoader):
    """A SafeLoader that refuses what the app's deck parser refuses.

    PyYAML keeps the last of two duplicate keys and expands `<<` merge keys.
    The Dart parser rejects both, so a deck using either would pass CI and then
    fail to load on a device.
    """

    def flatten_mapping(self, node: yaml.MappingNode) -> None:
        for key_node, _ in node.value:
            if key_node.tag == "tag:yaml.org,2002:merge":
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
    card_defs: dict[str, list[str]] = field(default_factory=dict)
    refs: list[tuple[str, bool, str]] = field(default_factory=list)
    # Each card's minimal-pair partner (ADR-0034): (partner id, where).
    pairs: list[tuple[str, str]] = field(default_factory=list)
    # For reading decks (#98, ADR-0019): the unit each deck of a path is in;
    # the words a vocab or grammar deck teaches; and a reading deck's
    # passages, as (id, theme, words in its sentences, words it glosses).
    course_units: tuple[str, str, dict[str, int]] | None = None
    taught_words: tuple[str, str, set[str]] | None = None
    passages: tuple[str, str, list[tuple[str, str | None, list[str], set[str]]]] | None = None

    def error(self, where: str, msg: str) -> None:
        self.errors.append(f"{where}: {msg}")

    def warn(self, where: str, msg: str) -> None:
        self.warnings.append(f"{where}: {msg}")


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
               script: str, lang: str) -> None:
    where = f"cards[{idx}]"
    if not isinstance(card, dict):
        r.error(where, "must be a mapping")
        return
    id_re = card_id_re(lang)

    if "ref" in card:
        check_ref(r, idx, card, seen, id_re)
        return

    cid = card.get("id")
    if not _is_str(cid) or not id_re.fullmatch(cid):
        r.error(where, f"id must be {lang}- and at least four digits, such as "
                       f"{lang}-0001, got {cid!r}")
    else:
        where = f"card {cid}"
        if cid in seen:
            r.error(where, "duplicate card id")
        seen.add(cid)
        alts = card.get("alt_target")
        r.card_defs[cid] = [
            t for t in [card.get("target"), *(alts if isinstance(alts, list) else [])]
            if _is_str(t)
        ]

    for unknown in sorted(set(card) - CARD_KEYS):
        r.error(where, f"unknown field {unknown!r}")

    for key in ("target", "native", "reading"):
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

    for key in ("gender", "notes", "audio"):
        _check_optional_text(r, where, card, key)

    pos = card.get("pos")
    if pos is not None and pos not in POS:
        r.error(where, f"pos must be one of {sorted(POS)}, got {pos!r}")

    modes = card.get("modes")
    if modes is not None:
        _check_str_list(r, where, "modes", modes)
        if isinstance(modes, list):
            for m in modes:
                if isinstance(m, str) and m not in MODES:
                    r.error(where, f"unknown mode {m!r}")

    if "pair" in card:
        partner = card["pair"]
        if not _is_str(partner) or not id_re.fullmatch(partner):
            r.error(where, f"pair must be the id of another {lang} card, "
                           f"got {partner!r}")
        elif partner == cid:
            r.error(where, "pair names the card itself")
        else:
            r.pairs.append((partner, where))

    _check_examples(r, where, card.get("examples"))


def _check_examples(r: Report, where: str, examples: object) -> None:
    if examples is None:
        return
    if not isinstance(examples, list):
        r.error(where, "examples must be a list")
        return
    for j, ex in enumerate(examples):
        if not isinstance(ex, dict):
            r.error(where, f"examples[{j}] must be a mapping")
        elif not _is_str(ex.get("target")) or not _is_str(ex.get("native")):
            r.error(where, f"examples[{j}] needs both target and native")
        elif set(ex) - EXAMPLE_KEYS:
            r.error(where, f"examples[{j}] has unknown fields")
        else:
            for key in ("reading", "ipa"):
                if key in ex and not _is_str(ex.get(key)):
                    r.error(where, f"examples[{j}].{key} must be a non-empty "
                                   f"string or omitted")


def check_ref(r: Report, idx: int, card: dict, seen: set[str],
              id_re: re.Pattern[str]) -> None:
    """A card written in another deck, listed here by its id, with any
    native-side fields this deck gives it."""
    rid = card.get("ref")
    where = f"cards[{idx}]"
    if not _is_str(rid) or not id_re.fullmatch(rid):
        r.error(where, f"ref must be a card id of this deck's language, got {rid!r}")
        return
    where = f"ref {rid}"
    if rid in seen:
        r.error(where, "this card is already in the deck")
    seen.add(rid)
    for unknown in sorted(set(card) - REF_KEYS):
        if unknown in CARD_KEYS:
            r.error(where, f"a ref cannot give {unknown!r}: it belongs to the card "
                           f"itself, where it is written")
        else:
            r.error(where, f"unknown field {unknown!r}")
    for key in ("native", "reading"):
        if key in card and not _is_str(card[key]):
            r.error(where, f"{key} must be a non-empty string")
    for key in ("alt_native", "tags"):
        if key in card:
            _check_str_list(r, where, key, card[key])
    _check_optional_text(r, where, card, "notes")
    modes = card.get("modes")
    if modes is not None:
        _check_str_list(r, where, "modes", modes)
        if isinstance(modes, list):
            for m in modes:
                if isinstance(m, str) and m not in MODES:
                    r.error(where, f"unknown mode {m!r}")
    _check_examples(r, where, card.get("examples"))
    r.refs.append((rid, _is_str(card.get("native")), where))


def check_pattern(r: Report, pattern: object) -> None:
    where = "pattern"
    if not isinstance(pattern, dict):
        r.error(where, "must be a mapping")
        return

    for unknown in sorted(set(pattern) - PATTERN_KEYS):
        r.error(where, f"unknown field {unknown!r}")

    for key in ("name", "slot_name", "prompt"):
        if not _is_str(pattern.get(key)):
            r.error(where, f"{key} is required")
    _check_optional_text(r, where, pattern, "notes")

    prompt = pattern.get("prompt")
    if _is_str(prompt):
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
        for unknown in sorted(set(entry) - {"lemma", "key", "gloss", "forms",
                                            "reading", "readings", "ipa",
                                            "ipas"}):
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
        if not _is_str(entry.get("gloss")):
            r.error(ewhere, "gloss is required")

        forms = entry.get("forms")
        if not isinstance(forms, dict):
            r.error(ewhere, "forms must be a mapping")
            continue
        missing = [s for s in slots if s not in forms]
        if missing:
            r.error(ewhere, f"forms missing slots: {missing}")
        for extra in sorted(set(forms) - set(slots)):
            r.error(ewhere, f"forms has key {extra!r} which is not a slot")
        filled = [s for s in slots if forms.get(s) is not None]
        if not filled:
            r.error(ewhere, "every form is null; nothing to drill")
        for slot in slots:
            val = forms.get(slot)
            if isinstance(val, list):
                # The first is the form shown; every one is accepted (#144).
                if not val or not all(_is_str(v) for v in val):
                    r.error(ewhere, f"forms[{slot!r}] must list non-empty strings")
                elif len(set(val)) != len(val):
                    r.error(ewhere, f"forms[{slot!r}] lists a form twice")
            elif val is not None and not _is_str(val):
                r.error(ewhere, f"forms[{slot!r}] must be a form, a list of forms, "
                                f"or null")
        check_pattern_readings(r, ewhere, entry, forms, slots)
        check_pattern_ipas(r, ewhere, entry, forms, slots)


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


def check_romanised(r: Report, raw: dict, path: Path) -> None:
    """Once a language has its romanisation file (#47), every reading in its
    files is in that scheme: lowercase, no capitals, and no diacritics but
    ISO 15919's where the file names that standard (ADR-0025)."""
    lang = raw.get("language")
    code = lang.get("code") if isinstance(lang, dict) else lang
    file = path.parent / f"{code}-romanisation.yaml" if _is_str(code) else None
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
# Keys whose values are the word itself, not prose about it.
_WORD_KEYS = {"id", "key", "target", "reading", "readings", "ipa", "ipas",
              "term", "example", "letters", "letter", "forms", "alternatives",
              "answer", "answers", "accept", "equivalents", "words", "tiles",
              "source", "scheme", "audio"}


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


def _untransliterated(text: str, code: str | None) -> list[str]:
    """The runs of script in [text] with no reading beside them."""
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


def check_transliterated(r: Report, raw: object) -> None:
    """Every run of script in a deck's prose carries its reading."""
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
            if key in _WORD_KEYS or any(k in ("forms", "ipas", "readings",
                                              "alternatives") for k in keys[:-1]):
                return
            if key == "text" and "passages" in keys:
                return
            code = key if LANG_RE.fullmatch(key) and key not in ("name",) else None
            if code in (None, "en") and not re.search(f"[{_LATIN}]{{2,}}", node):
                return
            for run in _untransliterated(node, code):
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

    for unknown in sorted(set(raw) - HEADER_KEYS):
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
    if kind not in KINDS:
        r.error("kind", f"must be one of {sorted(KINDS)}, got {kind!r}")

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
    script = lang.get("script") if isinstance(lang, dict) else "other"
    if script not in SCRIPTS:
        script = "other"

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
                    w for texts in r.card_defs.values() for t in texts for w in t.split())
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
    else:
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
    return r


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
            r.card_defs[value] = []
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
    for i, unit in enumerate(units):
        where = f"units[{i}]"
        if not isinstance(unit, list) or not unit:
            r.error(where, "must be a non-empty list of deck ids")
            continue
        # The wildcard takes decks the path does not list, such as a deck a
        # learner adds: its theme's unit, or a last unit of it alone.
        if WILDCARD in unit:
            if unit.index(WILDCARD) != len(unit) - 1 or unit.count(WILDCARD) > 1:
                r.error(where, f"{WILDCARD!r} can only end a unit")
            elif len(unit) == 1 and i != len(units) - 1:
                r.error(where, f"a unit of {WILDCARD!r} alone can only be the last")
            elif len(unit) > 1:
                r.open_units.append([d for d in unit if d != WILDCARD])
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
    # The decks a learner who skips the alphabet leaves out: the script,
    # spelling and reading decks.
    alphabet = raw.get("alphabet", [])
    if not isinstance(alphabet, list):
        r.error("alphabet", "must be a list of deck ids on the path")
    else:
        for deck in alphabet:
            if deck not in listed:
                r.error("alphabet", f"lists {deck!r}, which the path does not")
    if codes_ok:
        r.course_path = (lang, native, listed)
        r.course_units = (lang, native, unit_of)


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


def _repo_card_defs(lang: str) -> dict[str, tuple[Path, str, list[str]]]:
    """The cards the repository's own decks write for [lang], so that one
    file can be validated alone and still have its refs resolved."""
    root = Path(__file__).resolve().parent.parent / "decks" / lang
    found: dict[str, tuple[Path, str, list[str]]] = {}
    for p in sorted(root.glob("*.yaml")) if root.is_dir() else []:
        rep = validate(p)
        if rep.native_code is None:
            continue
        for cid, words in rep.card_defs.items():
            found.setdefault(cid, (p, rep.native_code, words))
    return found


def check_cards_across(reports: list[Report]) -> list[str]:
    """A card id is written once in its language, in any course, and every
    ref names a card written in another deck of that language. A ref from a
    course taught from another language gives its own native (ADR-0018)."""
    problems = []
    defs: dict[str, tuple[Path, str, list[str]]] = {}
    repo: dict[str, dict[str, tuple[Path, str, list[str]]]] = {}

    def repo_defs(lang: str) -> dict[str, tuple[Path, str, list[str]]]:
        if lang not in repo:
            repo[lang] = _repo_card_defs(lang)
        return repo[lang]

    given = {rep.path.resolve() for rep in reports}
    for rep in reports:
        if rep.native_code is None or rep.lang_code is None:
            continue
        for cid, words in rep.card_defs.items():
            # A deck in the repository but not among those given still
            # writes its cards, so a file checked alone is held to them;
            # not to its own deck's copy, which a draft elsewhere replaces.
            elsewhere = repo_defs(rep.lang_code).get(cid)
            if elsewhere is not None and (elsewhere[0].resolve() in given
                                          or elsewhere[0].stem == rep.path.stem):
                elsewhere = None
            first = defs.get(cid) or elsewhere
            if first is not None and first[0].resolve() != rep.path.resolve():
                problems.append(f"{rep.path}: card {cid} is already written in "
                                f"{first[0]}; list it here with ref: {cid}")
            else:
                defs[cid] = (rep.path, rep.native_code, words)
    for rep in reports:
        for rid, has_native, where in rep.refs:
            found = defs.get(rid)
            if found is None and rep.lang_code is not None:
                found = repo_defs(rep.lang_code).get(rid)
            if found is None:
                problems.append(f"{rep.path}: {where}: no deck writes card {rid}")
                continue
            # A ref to a card its own deck writes is refused within the deck.
            path, native, words = found
            if native != rep.native_code and not has_native:
                problems.append(f"{rep.path}: {where}: the card is written for "
                                f"learners from {native!r}; this deck is taught from "
                                f"{rep.native_code!r}, so the ref needs its own native")
            if rep.number_taught is not None:
                rep.number_taught[1].update(w for t in words for w in t.split())
    for rep in reports:
        for pid, where in rep.pairs:
            if pid not in defs and (rep.lang_code is None
                                    or pid not in repo_defs(rep.lang_code)):
                problems.append(f"{rep.path}: {where}: pair names card {pid}, "
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
    root = Path(__file__).resolve().parent.parent
    pathless: dict[tuple[str, str], Path] = {}
    for rep in reports:
        if rep.course_deck is None or rep.course_deck[:2] in seen:
            continue
        lang, native, _ = rep.course_deck
        try:
            rep.path.resolve().relative_to(root)
        except ValueError:
            continue
        if (rep.path.parent / f"{lang}-{native}-path.yaml").exists():
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
              + check_numbers_across(reports) + check_paths_across(reports)
              + check_reading_across(reports) + check_icons_across(reports))
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
        for w in rep.warnings:
            print(f"  warning {w}")

    ok = len(reports) - failed
    print(f"\n{ok}/{len(reports)} decks valid"
          f"{f', {warned} with warnings' if warned else ''}.")
    return 1 if failed or unbundled or across else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
