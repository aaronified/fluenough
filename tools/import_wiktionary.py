#!/usr/bin/env python3
"""Fill a language's cards from Wiktionary, through kaikki.org's extract
(#518).

Usage:
    python3 tools/import_wiktionary.py hi Hindi.jsonl                  # report only
    python3 tools/import_wiktionary.py hi Hindi.jsonl --write          # fill the decks
    python3 tools/import_wiktionary.py hi Hindi.jsonl --write --audio  # and recordings
    python3 tools/import_wiktionary.py hi Hindi.jsonl --write --images # and images
    python3 tools/import_wiktionary.py hi Hindi.jsonl --decks /tmp/copy/decks --write \\
        --dump-date 2026-10-13 --report hi-report.md

`Hindi.jsonl` is the language's Wiktextract dump from kaikki.org
(https://kaikki.org/dictionary/Hindi/, "all word senses" as JSON lines),
taken from the English Wiktionary. It is CC BY-SA 4.0, as the decks are
(ADR-0040).

For each vocab card a core writes, the tool finds the Wiktionary entries
whose title is exactly its target, and of the part of speech the card
has. Where more than one is left, it keeps those whose glosses share a
word with the card's English meaning; a card still matching more than one
is ambiguous and gets only an IPA all of them agree on. Then it fills
**only fields that are empty**, and never a card's meaning (owner,
2026-10-13: "A card's meaning never changes"):

- `ipa`, the entry's phonemic transcription, without its slashes;
- `gender` on a noun, where every sense agrees and the language's path
  lists the class;
- `bases: "self"` on a word that is its own root (a lemma not derived in
  the language), or its base by `ref` for an inflected form whose lemma a
  card teaches;
- `synonyms` and `antonyms`, each a card by `ref` where one teaches the
  word, else the word with its reading and, in the English layer, its
  meaning;
- `examples` with their translations (into the English layer), only those
  each of whose words the course teaches as a card, or an inflected form of
  one (given as a base by `ref`), so that the B1 check of every word holds;
- `forms`: a noun's plural, oblique and oblique plural, an adjective's
  feminine;
- `senses`, where the match is clear and the entry has two or more, each
  with its gloss as its meaning in the English layer;
- in the English layer, `wiktionary: true`, and a meaning only where the
  card has none;
- with `--audio`, `audio`: the recording Wiktionary links for exactly the
  card's text (owner: "you will not mix word sounds to create phrases"),
  downloaded from Wikimedia Commons and converted to Opus with `ffmpeg`
  at `decks/<lang>/audio/<card id>.opus`, with its `audio_credit`.
  Sentences stay text-to-speech. A licence that cannot ship in a CC BY-SA
  4.0 deck is skipped and reported.
- with `--images`, `image` on a card that has a `picture` (a concrete word,
  ADR-0034), by the owner's order (#523, 2026-10-16: "Wiktionary only"):
  the one picture in the language's section of its Wiktionary page, from
  Wikimedia Commons with its licence and credit checked, else OpenMoji's
  drawing of its `picture` (CC BY-SA 4.0). It is shrunk to 256 pixels and
  converted to WebP with `ffmpeg` at `decks/<lang>/images/<card id>.webp`,
  with its `image_credit`. With none, the card keeps its Noto picture.

Every item it adds names its `source` (owner: "Per item"): the entry's
Wiktionary page and nothing else (owner, 2026-10-16, #518: "Link only").
The dump's date and checksum, which pin the run so that it can be
repeated, are in the report only.
Readings are written by `tools/transcribe.py`, from Wiktionary's own
romanisation as a hint. What it imports is semi-verified (owner,
2026-10-13): reviewers check it, after the data Claude writes (#508).
The decks stay `unreviewed`.

It edits the deck files as text, a few lines per card, so that a diff
shows only what was added (AGENTS.md rule 8). A card written in flow
style, `- { id: ... }`, is left alone and reported.

The report, per language, says what was filled and what is still missing
card by card, for the builder to write (the build-deck skill). Run
`python3 tools/deck_index.py` and `python3 tools/validate_decks.py decks/`
after `--write`.

Needs only Python 3.11+ and PyYAML, like the other deck tools; `--audio`
and `--images` need `ffmpeg` on the PATH, and the network.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unicodedata
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import transcribe  # noqa: E402
import validate_decks as vd  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

# The most items of one kind the tool adds to a card: enough to ask about,
# few enough for a reviewer to check.
MAX_ITEMS = 4
MAX_EXAMPLES = 2
MAX_SENSES = 4

USER_AGENT = "fluenough-import/1.0 (https://github.com/aaronified/fluenough)"
COMMONS_API = "https://commons.wikimedia.org/w/api.php"

# A card's part of speech, to the Wiktextract parts of speech it matches.
POS = {
    "noun": {"noun"},
    "verb": {"verb"},
    "adj": {"adj"},
    "adv": {"adv"},
    "pronoun": {"pron"},
    "phrase": {"phrase", "prep_phrase", "proverb", "intj"},
    "particle": {"particle", "postp", "prep", "conj", "intj", "det", "num"},
}
GENDERS = {"masculine": "m", "feminine": "f", "neuter": "n"}
# Sense tags that mark a meaning no learner needs.
OLD = {"obsolete", "archaic", "dated", "rare"}
# Form tags to a form's kind (#517), by the card's part of speech.
FORM_KINDS = {
    "noun": (({"direct", "plural"}, "plural"), ({"oblique", "singular"}, "oblique"),
             ({"oblique", "plural"}, "oblique-plural")),
    "adj": (({"feminine", "singular"}, "feminine"),),
}
FORM_SKIP = {"romanization", "table-tags", "inflection-template", "class", "Urdu"}
STOPWORDS = {"the", "a", "an", "to", "of", "or", "and", "in", "on", "at", "for",
             "be", "is", "one", "some", "with", "by", "as"}


# --- The dump ---------------------------------------------------------------

@dataclass
class Word:
    """What the dump says of a word, kept for every word: its first gloss,
    its romanisation, and the lemmas it is an inflected form of."""
    gloss: str | None = None
    roman: str | None = None
    lemmas: set[str] = field(default_factory=set)


def nfc(text: str) -> str:
    return unicodedata.normalize("NFC", text)


def read_dump(path: Path, wanted: set[str]) -> tuple[dict[str, list[dict]], dict[str, Word]]:
    """The entries whose title is in [wanted], whole, and what the dump
    says of every word, by title."""
    entries: dict[str, list[dict]] = {}
    words: dict[str, Word] = {}
    with path.open(encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            e = json.loads(line)
            title = e.get("word")
            if not isinstance(title, str):
                continue
            title = nfc(title)
            if title in wanted:
                entries.setdefault(title, []).append(e)
            w = words.setdefault(title, Word())
            for form in e.get("forms", []):
                tags = set(form.get("tags", []))
                if "romanization" in tags and w.roman is None:
                    w.roman = form.get("form")
                elif form.get("source") in ("declension", "conjugation", "inflection") \
                        and not tags & FORM_SKIP and isinstance(form.get("form"), str):
                    words.setdefault(nfc(form["form"]), Word()).lemmas.add(title)
            for sense in e.get("senses", []):
                for of in sense.get("form_of", []) + sense.get("alt_of", []):
                    if isinstance(of.get("word"), str):
                        w.lemmas.add(nfc(of["word"]))
                if w.gloss is None and not sense.get("form_of") and not sense.get("alt_of"):
                    gloss = _gloss(sense)
                    if gloss:
                        w.gloss = gloss
    return entries, words


def _gloss(sense: dict) -> str | None:
    glosses = sense.get("glosses") or []
    if not glosses or not isinstance(glosses[-1], str):
        return None
    gloss = glosses[-1].strip().rstrip(".")
    return gloss if 0 < len(gloss) <= 80 and _latin(gloss) else None


def _latin(text: str) -> bool:
    """Whether [text] has no letter outside the Latin script: a gloss that
    quotes a word of the language would need its reading beside it."""
    return all(not unicodedata.category(c).startswith(("L", "M"))
               or unicodedata.name(c, "").startswith(("LATIN", "COMBINING"))
               for c in text)


def _plain_word(word: str) -> bool:
    """Whether [word] is only letters, marks, joiners, spaces and hyphens: not
    a reconstruction, `*मार्ग`, or a word with a note in it."""
    return bool(word.strip()) and all(
        unicodedata.category(c)[0] in "LM" or c in " -\u200c\u200d" for c in word)


def page(word: str) -> str:
    return f"https://en.wiktionary.org/wiki/{word.replace(' ', '_')}"


# --- The decks --------------------------------------------------------------

@dataclass
class Target:
    """A vocab card a core writes, as the tool fills it."""
    cid: str
    target: str
    pos: str | None
    core: Path
    card: dict
    layer: Path | None = None
    entry: dict | None = None          # the card's English layer entry
    native: str | None = None


@dataclass
class Language:
    code: str
    script: str
    genders: list[str]
    targets: list[Target]
    # Each single-word target or alternative a vocab card teaches, to its
    # card id, for refs and the words of examples.
    taught: dict[str, str]
    flow: list[str]
    # The language's English name, as its decks and Wiktionary's headings
    # give it: `Hindi`.
    name: str = ""


def read_language(decks: Path, code: str) -> Language:
    folder = decks / code
    path = vd._load_raw(folder / f"{code}-path.yaml")
    genders = path.get("genders", []) if isinstance(path, dict) else []
    targets: list[Target] = []
    taught: dict[str, str] = {}
    script = "latin"
    name = ""
    flow: list[str] = []
    for core in sorted(folder.glob("*.yaml")):
        raw = vd._load_raw(core)
        if not isinstance(raw, dict) or raw.get("kind") not in (None, "vocab"):
            continue
        if isinstance(raw.get("language"), dict):
            script = raw["language"].get("script", script)
            name = raw["language"].get("name", name)
        text = core.read_text(encoding="utf-8")
        for card in raw.get("cards") or []:
            if not isinstance(card, dict) or not vd._is_str(card.get("id")) \
                    or not vd._is_str(card.get("target")):
                continue
            if card.get("phrasebook") is not True:
                for t in [card["target"], *(card.get("alt_target") or [])]:
                    if isinstance(t, str) and len(vd._words(t)) == 1:
                        taught.setdefault(vd._key(t), card["id"])
            if raw.get("part") != "core":
                continue
            if not re.search(rf'(?m)^  - id: "?{re.escape(card["id"])}"?\s*$', text):
                flow.append(card["id"])
                continue
            targets.append(Target(card["id"], nfc(card["target"]), card.get("pos"),
                                  core, card))
    for t in targets:
        layer = folder / "en" / f"{code}-en-{t.core.stem[len(code) + 1:]}.yaml"
        raw = vd._load_raw(layer)
        if isinstance(raw, dict) and isinstance(raw.get("cards"), dict):
            t.layer = layer
            entry = raw["cards"].get(t.cid)
            t.entry = entry if isinstance(entry, dict) else None
            if t.entry is not None and vd._is_str(t.entry.get("native")):
                t.native = t.entry["native"]
    return Language(code, script, genders if isinstance(genders, list) else [],
                    targets, taught, flow, name if isinstance(name, str) else "")


# --- Choosing a card's entry ------------------------------------------------

def _content(text: str) -> set[str]:
    return {w for w in re.findall(r"[a-z]+", text.lower())
            if len(w) > 2 and w not in STOPWORDS}


def choose(t: Target, entries: list[dict]) -> tuple[dict | None, list[dict]]:
    """The card's entry, when exactly one fits its part of speech and
    meaning, and the entries that fit at all."""
    fits = [e for e in entries
            if t.pos is None or t.pos == "other" or e.get("pos") in POS.get(t.pos, set())]
    if not fits and t.pos == "phrase" and len(vd._words(t.target)) > 1:
        # Wiktionary files a phrase of more than one word under the part of
        # speech it acts as: `काम करना`, to work, is a verb.
        fits = list(entries)
    if len(fits) > 1 and t.native:
        meaning = _content(t.native)
        close = [e for e in fits
                 if any(meaning & _content(" ".join(s.get("glosses") or []))
                        for s in e.get("senses", []))]
        if close:
            fits = close
    return (fits[0] if len(fits) == 1 else None), fits


def ipa_of(entry: dict) -> str | None:
    found = [s["ipa"] for s in entry.get("sounds", []) if isinstance(s.get("ipa"), str)]
    for ipa in found:
        if ipa.startswith("/") and ipa.endswith("/"):
            return ipa.strip("/").replace(".", "").strip() or None
    for ipa in found:
        if ipa.startswith("[") and ipa.endswith("]"):
            return ipa.strip("[]").replace(".", "").strip() or None
    return None


def gender_of(entry: dict) -> str | None:
    seen: set[str] = set()
    for sense in entry.get("senses", []):
        seen |= {GENDERS[t] for t in sense.get("tags", []) if t in GENDERS}
    for t in entry.get("tags", []) or []:
        if t in GENDERS:
            seen.add(GENDERS[t])
    return seen.pop() if len(seen) == 1 else None


def derived(entry: dict, code: str) -> bool:
    """Whether the dump says the word is made in the language from parts:
    then it is not its own root."""
    for tpl in entry.get("etymology_templates", []):
        if tpl.get("name") in ("af", "affix", "suffix", "prefix", "compound", "confix",
                               "com", "suf", "pre") \
                and (tpl.get("args") or {}).get("1") == code:
            return True
    return False


# A script's language for `tools/transcribe.py`, for a language it has no
# table of its own for.
SCRIPT_LANG = {"devanagari": "hi", "bengali": "bn", "gujarati": "gu", "telugu": "te",
               "kannada": "kn"}


def reading(word: str, code: str, script: str, hint: str | None) -> str | None:
    """[word]'s reading, by `tools/transcribe.py`, from Wiktionary's own
    romanisation as a hint; None in a script that needs none, or one the
    transcriber cannot read, which leaves the item out (NoReading)."""
    if script in vd.NO_READING:
        return None
    lang = code if code in transcribe.BLOCKS else SCRIPT_LANG.get(script)
    if lang is None:
        raise NoReading(word)
    return transcribe.transcribe(word, lang, hint).reading


class NoReading(Exception):
    """A word that needs a reading the transcriber cannot give: the item is
    left out, as the validator would refuse it."""


def item_id(text: str, ids: set[str], fallback: str) -> str:
    """An id for an item, from its reading: `[a-z][a-z0-9-]*`, once in its
    list, never a YAML 1.1 boolean word."""
    plain = unicodedata.normalize("NFKD", text or "")
    slug = re.sub(r"[^a-z0-9]+", "-", "".join(c for c in plain if c.isascii()).lower())
    slug = slug.strip("-")[:24].strip("-")
    if not slug or not slug[0].isalpha() or not vd._is_key(slug):
        slug = fallback
    base, n = slug, 2
    while slug in ids or not vd._is_key(slug):
        slug = f"{base}-{n}"
        n += 1
    ids.add(slug)
    return slug


def _split_word(text: str) -> tuple[str, str | None]:
    """A thesaurus line, `आवास (āvās)`, as the word and its romanisation."""
    m = re.fullmatch(r"\s*(.+?)\s*\(([^()]*)\)\s*", text)
    return (nfc(m.group(1)), m.group(2)) if m else (nfc(text.strip()), None)


# --- What to add --------------------------------------------------------------

def q(text: str) -> str:
    return json.dumps(text, ensure_ascii=False)


def flow_map(pairs: list[tuple[str, object]]) -> str:
    def value(v: object) -> str:
        if isinstance(v, str):
            return q(v)
        if isinstance(v, list):
            return "[" + ", ".join(value(x) for x in v) + "]"
        if isinstance(v, dict):
            return flow_map(list(v.items()))
        return json.dumps(v)
    return "{ " + ", ".join(f"{k}: {value(v)}" for k, v in pairs) + " }"


@dataclass
class Fill:
    """What the tool adds to a card, as lines for its core and its layer,
    each after the key it follows (None: at the end)."""
    core: list[tuple[str | None, list[str]]] = field(default_factory=list)
    layer: list[tuple[str | None, list[str]]] = field(default_factory=list)
    fields: list[str] = field(default_factory=list)
    audio: dict | None = None          # the recording to fetch
    entry: dict | None = None          # the card's one entry, where it has one


class Importer:
    def __init__(self, lang: Language, entries: dict[str, list[dict]],
                 words: dict[str, Word]) -> None:
        self.lang = lang
        self.entries = entries
        self.words = words
        self.report = Report(lang.code)

    @staticmethod
    def source(word: str) -> str:
        """An item's `source`: the entry's page only (owner, 2026-10-16,
        #518: "Link only")."""
        return page(word)

    def ref_for(self, word: str, cid: str) -> str | None:
        ref = self.lang.taught.get(vd._key(word))
        return ref if ref is not None and ref != cid else None

    def fill(self, t: Target) -> Fill:
        f = Fill()
        card, code = t.card, self.lang.code
        entry, fits = choose(t, self.entries.get(t.target, []))
        r = self.report
        if not fits:
            r.unmatched.append(t)
            return f
        if entry is None:
            r.ambiguous.append(t)
            ipas = {ipa_of(e) for e in fits}
            if "ipa" not in card and len(ipas) == 1 and None not in ipas:
                f.core.append(("reading", [f"    ipa: {q(ipas.pop())}"]))
                f.fields.append("ipa")
            return f
        r.matched.append(t)
        f.entry = entry
        word = nfc(entry["word"])
        src = self.source(word)

        if "ipa" not in card and (ipa := ipa_of(entry)):
            f.core.append(("reading", [f"    ipa: {q(ipa)}"]))
            f.fields.append("ipa")

        if t.pos == "noun" and "gender" not in card and self.lang.genders \
                and (g := gender_of(entry)) in self.lang.genders:
            f.core.append(("pos", [f"    gender: {q(g)}"]))
            f.fields.append("gender")

        if "bases" not in card and len(vd._words(t.target)) == 1:
            lemmas = {nfc(of["word"]) for s in entry.get("senses", [])
                      for of in s.get("form_of", []) if isinstance(of.get("word"), str)}
            if not lemmas and not derived(entry, code):
                f.core.append((None, ['    bases: "self"']))
                f.fields.append("bases")
            elif len(lemmas) == 1 and (ref := self.ref_for(lemmas.pop(), t.cid)):
                f.core.append((None, ["    bases:",
                                      f"      - {flow_map([('word', t.target), ('ref', ref)])}"]))
                f.fields.append("bases")

        for key in ("synonyms", "antonyms"):
            if key in card:
                continue
            items, texts = self.items(t, entry, key, src)
            if items:
                f.core.append((None, [f"    {key}:", *[f"      - {i}" for i in items]]))
                if texts:
                    f.layer.append((None, [f"    {key}: {flow_map(texts)}"]))
                f.fields.append(key)

        if "examples" not in card:
            core_lines, layer_lines = self.examples(t, entry, src)
            if core_lines:
                f.core.append((None, ["    examples:", *core_lines]))
                f.layer.append((None, ["    examples:", *layer_lines]))
                f.fields.append("examples")

        if "forms" not in card and t.pos in FORM_KINDS:
            forms = self.forms(t, entry, src)
            if forms:
                f.core.append((None, ["    forms:", *[f"      - {x}" for x in forms]]))
                f.fields.append("forms")

        if "senses" not in card and t.entry is not None:
            core_lines, layer_lines = self.senses(t, entry, src)
            if core_lines:
                f.core.append((None, ["    senses:", *core_lines]))
                f.layer.append((None, ["    senses:", *layer_lines]))
                f.fields.append("senses")

        if t.entry is not None:
            if "wiktionary" not in t.entry and word == t.target:
                f.layer.append(("native", ["    wiktionary: true"]))
                f.fields.append("wiktionary")
            if t.native is None and (gloss := _first_gloss(entry)):
                f.layer.append((None, [f"    native: {q(gloss)}"]))
                f.fields.append("native")

        if "audio" not in card:
            sound = next((s for s in entry.get("sounds", [])
                          if s.get("audio") and (s.get("ogg_url") or s.get("mp3_url"))), None)
            if sound is not None:
                f.audio = sound
        return f

    def items(self, t: Target, entry: dict, key: str, src: str
              ) -> tuple[list[str], list[tuple[str, str]]]:
        found: list[tuple[str, str | None]] = []
        own = {nfc(x) for x in [t.target, *(t.card.get("alt_target") or [])]
               if isinstance(x, str)}
        lists = [entry.get(key, [])] + [s.get(key, []) for s in self.card_senses(t, entry)]
        for item in (x for xs in lists for x in xs):
            if not isinstance(item.get("word"), str):
                continue
            word, roman = _split_word(item["word"])
            roman = item.get("roman") or roman
            if word in own or re.search(r"[A-Za-z]", word) or not _plain_word(word) \
                    or any(w == word for w, _ in found):
                continue
            found.append((word, roman))
        items: list[str] = []
        texts: list[tuple[str, str]] = []
        ids: set[str] = set()
        for word, roman in found[:MAX_ITEMS]:
            known = self.words.get(word, Word())
            hint = roman or known.roman
            iid = item_id(hint or "", ids, f"{key[:3]}{len(ids) + 1}")
            if ref := self.ref_for(word, t.cid):
                items.append(flow_map([("id", iid), ("ref", ref), ("source", src)]))
                continue
            pairs: list[tuple[str, object]] = [("id", iid), ("word", word)]
            try:
                rd = reading(word, self.lang.code, self.lang.script, hint)
            except NoReading:
                continue
            if rd is not None:
                pairs.append(("reading", rd))
            items.append(flow_map([*pairs, ("source", src)]))
            if known.gloss:
                texts.append((q(iid), known.gloss))
            else:
                self.report.no_meaning.append(f"{t.cid} {key} {iid}")
        return items, texts

    @staticmethod
    def card_senses(t: Target, entry: dict) -> list[dict]:
        """The entry's senses that are the card's meaning: those whose
        gloss shares a word with it, or the only one. A synonym of another
        sense is not one of the card's word."""
        senses = [s for s in entry.get("senses", [])
                  if not s.get("form_of") and not s.get("alt_of")]
        if len(senses) <= 1 or not t.native:
            return senses if len(senses) <= 1 else []
        meaning = _content(t.native)
        return [s for s in senses
                if meaning & _content(" ".join(s.get("glosses") or []))]

    def examples(self, t: Target, entry: dict, src: str) -> tuple[list[str], list[str]]:
        core: list[str] = []
        layer: list[str] = []
        seen: set[str] = set()
        for sense in self.card_senses(t, entry):
            for ex in sense.get("examples", []):
                text = ex.get("text")
                english = ex.get("english") or ex.get("translation")
                if len(core) >= MAX_EXAMPLES or ex.get("type") == "quotation" \
                        or not isinstance(text, str) or not isinstance(english, str) \
                        or not _latin(english):
                    continue
                text = nfc(text.strip())
                if text in seen or re.search(r"[A-Za-z]", text):
                    continue
                bases = self.covered(text, t)
                if bases is None:
                    self.report.examples_skipped += 1
                    continue
                try:
                    rd = reading(text, self.lang.code, self.lang.script, ex.get("roman"))
                except NoReading:
                    continue
                seen.add(text)
                pairs: list[tuple[str, object]] = [("target", text)]
                if rd is not None:
                    pairs.append(("reading", rd))
                if bases:
                    pairs.append(("bases", bases))
                pairs.append(("source", src))
                core.append(f"      - {flow_map(pairs)}")
                layer.append(f"      {q(text)}: {q(english.strip())}")
        return core, layer

    def covered(self, text: str, t: Target) -> list[dict] | None:
        """The bases an example needs so that each of its words is taught,
        or None where a word is neither taught nor a form of a taught
        word."""
        bases: list[dict] = []
        for w in dict.fromkeys(vd._words(text)):
            k = vd._key(w)
            if k in self.lang.taught or k == vd._key(t.target):
                continue
            lemmas = self.words.get(nfc(w), Word()).lemmas
            refs = {self.ref_for(lemma, t.cid) for lemma in lemmas} - {None}
            if len(refs) != 1:
                return None
            bases.append({"word": w, "ref": refs.pop()})
        return bases

    def forms(self, t: Target, entry: dict, src: str) -> list[str]:
        out: list[str] = []
        done: set[str] = set()
        ids: set[str] = set()
        for tags, kind in FORM_KINDS[t.pos]:
            for form in entry.get("forms", []):
                ftags = set(form.get("tags", []))
                word = form.get("form")
                if kind in done or not isinstance(word, str) or not tags <= ftags \
                        or ftags & FORM_SKIP or ("vocative" in ftags):
                    continue
                if kind == "feminine" and ("oblique" in ftags or "plural" in ftags):
                    continue
                word = nfc(word)
                if not _plain_word(word):
                    continue
                if word == t.target:
                    done.add(kind)
                    continue
                try:
                    rd = reading(word, self.lang.code, self.lang.script, form.get("roman"))
                except NoReading:
                    continue
                pairs: list[tuple[str, object]] = [("id", item_id(kind, ids, kind)),
                                                   ("kind", kind), ("word", word)]
                if rd is not None:
                    pairs.append(("reading", rd))
                pairs.append(("source", src))
                out.append(flow_map(pairs))
                done.add(kind)
        return out

    def senses(self, t: Target, entry: dict, src: str) -> tuple[list[str], list[str]]:
        kept = []
        for sense in entry.get("senses", []):
            if sense.get("form_of") or sense.get("alt_of") or OLD & set(sense.get("tags", [])):
                continue
            gloss = _gloss(sense)
            if gloss and gloss not in [g for g, _ in kept]:
                kept.append((gloss, sense))
        if len(kept) < 2:
            return [], []
        core: list[str] = []
        layer: list[str] = []
        ids: set[str] = set()
        for gloss, _ in kept[:MAX_SENSES]:
            words = sorted(_content(gloss), key=lambda w: gloss.lower().index(w))
            sid = item_id(words[0] if words else "", ids, f"sense{len(ids) + 1}")
            pairs: list[tuple[str, object]] = [("id", sid)]
            if t.pos:
                pairs.append(("pos", t.pos))
            pairs.append(("source", src))
            core.append(f"      - {flow_map(pairs)}")
            layer.append(f"      {q(sid)}: {flow_map([('native', gloss)])}")
        return core, layer


def _first_gloss(entry: dict) -> str | None:
    for sense in entry.get("senses", []):
        if not sense.get("form_of") and (g := _gloss(sense)):
            return g
    return None


# --- Recordings ---------------------------------------------------------------

class ImportError_(Exception):
    """A step the tool cannot take, with what to do about it."""


def http_get(url: str) -> bytes:
    """[url]'s body. The one place the tool reaches the network, so that
    tests replace it."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def ffmpeg() -> str:
    """The ffmpeg to convert with, or an error saying how to get one."""
    found = shutil.which("ffmpeg")
    if found is None:
        raise ImportError_("ffmpeg is not installed, and recordings and images are "
                           "converted with it: install it (apt install ffmpeg, brew "
                           "install ffmpeg), or run without --audio and --images")
    return found


def convert(args: list[str]) -> None:
    """Runs ffmpeg with [args]. Tests replace it."""
    subprocess.run([ffmpeg(), "-nostdin", "-loglevel", "error", "-y", *args],
                   check=True, capture_output=True)


LICENCES = [
    (re.compile(r"cc0(?: 1\.0)?", re.I), lambda m: "CC0-1.0"),
    (re.compile(r"public domain|pd(?:-.*)?", re.I), lambda m: "public-domain"),
    (re.compile(r"cc[ -]by(-sa)?[ -](2\.0|2\.5|3\.0|4\.0)(?:[ -]([a-z]{2,3}))?", re.I),
     lambda m: "CC-BY" + ("-SA" if m.group(1) else "") + f"-{m.group(2)}"
               + (f"-{m.group(3).upper()}" if m.group(3) else "")),
]


def licence_id(short_name: str) -> str | None:
    """A Commons licence's short name, `CC BY-SA 4.0`, as the deck writes
    it, `CC-BY-SA-4.0`; None for one that cannot ship in a CC BY-SA 4.0
    deck."""
    for pattern, make in LICENCES:
        if m := pattern.fullmatch(short_name.strip()):
            licence = make(m)
            return licence if vd.MEDIA_LICENSE_RE.fullmatch(licence) else None
    return None


def strip_html(text: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", text))).strip()


def commons_file(name: str) -> dict:
    """A Commons file's page, URL, licence and credit."""
    title = name if name.startswith("File:") else f"File:{name}"
    url = COMMONS_API + "?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "prop": "imageinfo",
        "iiprop": "url|extmetadata", "iiurlwidth": "256", "titles": title})
    data = json.loads(http_get(url))
    pages = (data.get("query") or {}).get("pages") or {}
    info = next(iter(pages.values()), {}).get("imageinfo") or [{}]
    info = info[0]
    meta = info.get("extmetadata") or {}

    def value(key: str) -> str:
        v = (meta.get(key) or {}).get("value")
        return strip_html(v) if isinstance(v, str) else ""
    return {"page": info.get("descriptionurl") or f"https://commons.wikimedia.org/wiki/{title}",
            "url": info.get("url"), "thumb": info.get("thumburl"),
            "licence": value("LicenseShortName"),
            "credit": value("Artist") or value("Credit")}


def fetch_recording(sound: dict, out: Path) -> dict:
    """Downloads [sound]'s file, converts it to Opus at [out], and returns
    its credit."""
    info = commons_file(sound["audio"])
    licence = licence_id(info["licence"])
    if licence is None:
        raise ImportError_(f"{sound['audio']}: licence {info['licence']!r} cannot ship "
                           f"in a CC BY-SA 4.0 deck")
    if not info["credit"]:
        raise ImportError_(f"{sound['audio']}: Commons names no speaker to credit")
    data = http_get(info["url"] or sound.get("ogg_url") or sound["mp3_url"])
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / ("in" + Path(sound["audio"]).suffix.lower())
        src.write_bytes(data)
        convert(["-i", str(src), "-vn", "-ac", "1", "-ar", "48000", "-c:a", "libopus",
                 "-b:a", "24k", str(out)])
    return {"source": info["page"], "license": licence, "credit": info["credit"]}


# --- Images ---------------------------------------------------------------------

WIKTIONARY_API = "https://en.wiktionary.org/w/api.php"
# OpenMoji's drawings, 618 pixels square, by their emoji's code points, and
# the page that credits one. The version is pinned, so that a run can be
# repeated.
OPENMOJI_PNG = "https://cdn.jsdelivr.net/npm/openmoji@15.1.0/color/618x618/{}.png"
OPENMOJI_PAGE = "https://openmoji.org/library/emoji-{}/"
# The longest side of a card's image, in pixels (owner, #523: "for example to
# 256 px WebP").
IMAGE_SIZE = 256
# Images on a Wiktionary page that are no picture of the word.
NOT_A_PICTURE = re.compile(r"(?i)\b(?:wiktionary|wikipedia|commons|logo|icon|flag|map|"
                           r"audio|speaker|nuvola|crystal)\b|\.svg$")


def emoji_hex(emoji: str) -> list[str]:
    """OpenMoji's names for [emoji]: its code points in hex, without the
    variation selector, then with it."""
    full = "-".join(f"{ord(c):04X}" for c in emoji)
    bare = "-".join(f"{ord(c):04X}" for c in emoji if c != "\ufe0f")
    return list(dict.fromkeys([bare, full]))


def api(url: str, params: dict[str, str]) -> dict:
    data = json.loads(http_get(url + "?" + urllib.parse.urlencode(
        {**params, "format": "json"})))
    return data if isinstance(data, dict) else {}


def wiktionary_image(word: str, language: str) -> str | None:
    """The one picture in the language's section of [word]'s Wiktionary
    page, if it has exactly one."""
    sections = (api(WIKTIONARY_API, {"action": "parse", "page": word,
                                     "prop": "sections"}).get("parse") or {}).get(
        "sections") or []
    index = next((s.get("index") for s in sections
                  if s.get("level") == "2" and s.get("line") == language), None)
    if index is None:
        return None
    images = (api(WIKTIONARY_API, {"action": "parse", "page": word, "section": index,
                                   "prop": "images"}).get("parse") or {}).get("images") or []
    pictures = [i for i in images if isinstance(i, str) and not NOT_A_PICTURE.search(i)]
    return pictures[0] if len(pictures) == 1 else None


def convert_image(data: bytes, suffix: str, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / ("in" + suffix)
        src.write_bytes(data)
        convert(["-i", str(src), "-vf",
                 f"scale={IMAGE_SIZE}:{IMAGE_SIZE}:force_original_aspect_ratio=decrease",
                 "-frames:v", "1", "-c:v", "libwebp", "-quality", "80", str(out)])


def commons_image(name: str, out: Path) -> dict:
    """Downloads a Commons file's 256-pixel rendering, converts it to WebP at
    [out], and returns its credit."""
    info = commons_file(name)
    licence = licence_id(info["licence"])
    if licence is None:
        raise ImportError_(f"{name}: licence {info['licence']!r} cannot ship in a CC "
                           f"BY-SA 4.0 deck")
    if not info["credit"]:
        raise ImportError_(f"{name}: Commons names no one to credit")
    url = info["thumb"] or info["url"]
    if not url:
        raise ImportError_(f"{name}: Commons gives no file")
    convert_image(http_get(url), Path(urllib.parse.urlparse(url).path).suffix.lower(), out)
    return {"source": info["page"], "license": licence, "credit": info["credit"]}


def openmoji_image(emoji: str, out: Path) -> dict:
    """Downloads OpenMoji's drawing of [emoji], converts it to WebP at
    [out], and returns its credit."""
    last: Exception | None = None
    for name in emoji_hex(emoji):
        try:
            data = http_get(OPENMOJI_PNG.format(name))
        except OSError as e:
            last = e
            continue
        convert_image(data, ".png", out)
        return {"source": OPENMOJI_PAGE.format(name), "license": "CC-BY-SA-4.0",
                "credit": "OpenMoji"}
    raise ImportError_(f"OpenMoji has no drawing of {emoji}: {last}")


def fetch_image(t: Target, entry: dict | None, language: str, out: Path
                ) -> tuple[str, dict]:
    """A card's image, by the owner's order (#523, 2026-10-16: "Wiktionary
    only"): the one picture of its Wiktionary page's section, else
    OpenMoji's drawing of its `picture`. Returns where it came from and its
    credit; raises where none can ship, and the card keeps its Noto
    picture."""
    problems: list[str] = []
    if entry is not None:
        try:
            name = wiktionary_image(t.target, language)
            if name:
                return "wiktionary", commons_image(name, out)
        except (ImportError_, OSError, ValueError,
                subprocess.CalledProcessError) as e:
            problems.append(str(e))
    try:
        return "openmoji", openmoji_image(t.card["picture"], out)
    except (ImportError_, OSError, subprocess.CalledProcessError) as e:
        problems.append(str(e))
    raise ImportError_("; ".join(problems))


# --- Editing the files ----------------------------------------------------------

def _block(lines: list[str], head: re.Pattern, indent: int) -> tuple[int, int] | None:
    for i, line in enumerate(lines):
        if head.match(line):
            j = i + 1
            while j < len(lines) and (not lines[j].strip()
                                      or len(lines[j]) - len(lines[j].lstrip(" ")) > indent):
                j += 1
            while j > i + 1 and not lines[j - 1].strip():
                j -= 1
            return i, j
    return None


def _insert_at(lines: list[str], start: int, end: int, after: str | None) -> int:
    """Where to add a field to the block [start, end): after [after]'s key
    and its lines, or at the end."""
    if after is None:
        return end
    key = re.compile(rf"^(?:  - |    ){re.escape(after)}:")
    for i in range(start, end):
        if key.match(lines[i]):
            j = i + 1
            while j < end and len(lines[j]) - len(lines[j].lstrip(" ")) > 4:
                j += 1
            return j
    return end


def apply(text: str, head: re.Pattern, indent: int,
          adds: list[tuple[str | None, list[str]]]) -> str:
    lines = text.split("\n")
    found = _block(lines, head, indent)
    if found is None:
        return text
    start, end = found
    for after, new in adds:
        at = _insert_at(lines, start, end, after)
        lines[at:at] = new
        end += len(new)
    return "\n".join(lines)


# --- The report ---------------------------------------------------------------

FIELDS = ("ipa", "gender", "bases", "synonyms", "antonyms", "examples", "forms",
          "senses", "wiktionary", "native", "audio", "image")


@dataclass
class Report:
    code: str
    matched: list[Target] = field(default_factory=list)
    ambiguous: list[Target] = field(default_factory=list)
    unmatched: list[Target] = field(default_factory=list)
    filled: dict[str, int] = field(default_factory=dict)
    missing: dict[str, list[str]] = field(default_factory=dict)
    examples_skipped: int = 0
    # Synonyms and antonyms written as a word that Wiktionary gives no
    # meaning for: the layer's text is still to write.
    no_meaning: list[str] = field(default_factory=list)
    audio_found: int = 0
    audio_failed: list[str] = field(default_factory=list)
    # Images by where they came from, and the cards none could be found for.
    images_from: dict[str, int] = field(default_factory=dict)
    images_failed: list[str] = field(default_factory=list)
    flow: list[str] = field(default_factory=list)

    def render(self, name: str, dump: Path, dump_sha: str, dump_date: str,
               total: int) -> str:
        def pct(n: int) -> str:
            return f"{n} ({100 * n // total if total else 0}%)"
        lines = [f"# Wiktionary import: {name} ({self.code})", "",
                 f"- Dump: kaikki.org {dump.name}, {dump_date}, sha256 {dump_sha[:16]}",
                 f"- Core vocab cards: {total}",
                 f"- Matched one entry: {pct(len(self.matched))}",
                 f"- Ambiguous (more than one entry fits): {pct(len(self.ambiguous))}",
                 f"- Not in Wiktionary: {pct(len(self.unmatched))}"]
        if self.flow:
            lines.append(f"- Written in flow style, left alone: {', '.join(self.flow)}")
        lines += ["", "## Filled", "", "| Field | Cards |", "|---|---|"]
        lines += [f"| `{k}` | {self.filled.get(k, 0)} |" for k in FIELDS]
        lines += ["", f"Examples left out because a word is not taught: "
                      f"{self.examples_skipped}.",
                  f"Recordings Wiktionary links for exactly a card's text: "
                  f"{self.audio_found}."]
        if self.no_meaning:
            lines += ["", f"Synonyms and antonyms with no meaning in the English layer "
                          f"yet ({len(self.no_meaning)}): {', '.join(self.no_meaning)}."]
        if self.audio_failed:
            lines += ["", "Recordings not imported:", ""]
            lines += [f"- {x}" for x in self.audio_failed]
        if self.images_from:
            lines += ["", "Images by source: " + ", ".join(
                f"{k} {v}" for k, v in sorted(self.images_from.items())) + "."]
        if self.images_failed:
            lines += ["", "Images not imported (the card keeps its Noto picture):", ""]
            lines += [f"- {x}" for x in self.images_failed]
        lines += ["", "## Still missing", "",
                  "Cards still without the field, for the builder to write "
                  "(the build-deck skill) and reviewers to check.", ""]
        for k in FIELDS:
            if self.missing.get(k):
                ids = self.missing[k]
                lines.append(f"- `{k}` ({len(ids)}): {', '.join(ids)}")
        return "\n".join(lines) + "\n"


def tally(r: Report, targets: list[Target], fills: dict[str, Fill],
          genders: list[str], audio: bool, images: bool) -> None:
    for t in targets:
        f = fills.get(t.cid, Fill())
        for k in f.fields:
            r.filled[k] = r.filled.get(k, 0) + 1
        have = set(t.card) | set(f.fields)
        layer = set(t.entry or {}) | ({"wiktionary"} if "wiktionary" in f.fields else set())
        label = f"{t.cid} {t.target}"
        for k in FIELDS:
            if k == "gender" and (t.pos != "noun" or not genders):
                continue
            if k in ("wiktionary", "native"):
                if k not in layer and t.entry is not None:
                    r.missing.setdefault(k, []).append(label)
                continue
            if k == "examples":
                n = len(t.card.get("examples") or []) + (MAX_EXAMPLES if k in f.fields else 0)
                if n < vd.MIN_EXAMPLES:
                    r.missing.setdefault(k, []).append(label)
                continue
            if k == "audio" and audio:
                continue
            # An image is only for a concrete word: a card with a picture.
            if k == "image" and (images or "picture" not in t.card):
                continue
            if k not in have:
                r.missing.setdefault(k, []).append(label)


# --- Running --------------------------------------------------------------------

LANGUAGE_NAMES = {"hi": "Hindi", "bn": "Bengali", "te": "Telugu", "mr": "Marathi",
                  "gu": "Gujarati", "kn": "Kannada", "as": "Assamese"}


def run(code: str, dump: Path, decks: Path, dump_date: str, write: bool,
        audio: bool, images: bool = False) -> str:
    if audio or images:
        ffmpeg()
    lang = read_language(decks, code)
    wanted = {t.target for t in lang.targets}
    entries, words = read_dump(dump, wanted)
    importer = Importer(lang, entries, words)
    report = importer.report
    report.flow = lang.flow
    fills = {t.cid: importer.fill(t) for t in lang.targets}
    for t in lang.targets:
        f = fills[t.cid]
        if f.audio is None:
            continue
        report.audio_found += 1
        if not (audio and write):
            continue
        out = decks / code / "audio" / f"{t.cid}.opus"
        try:
            credit = fetch_recording(f.audio, out)
        except (ImportError_, OSError, subprocess.CalledProcessError, ValueError) as e:
            report.audio_failed.append(f"{t.cid} {t.target}: {e}")
            continue
        f.core.append(("ipa", [f"    audio: {q(f'decks/{code}/audio/{t.cid}.opus')}",
                               f"    audio_credit: {flow_map(list(credit.items()))}"]))
        f.fields.append("audio")
    for t in lang.targets:
        if not (images and write) or "picture" not in t.card or "image" in t.card:
            continue
        f = fills[t.cid]
        out = decks / code / "images" / f"{t.cid}.webp"
        try:
            kind, credit = fetch_image(t, f.entry, lang.name, out)
        except ImportError_ as e:
            report.images_failed.append(f"{t.cid} {t.target}: {e}")
            continue
        report.images_from[kind] = report.images_from.get(kind, 0) + 1
        f.core.append(("picture", [f"    image: {q(f'decks/{code}/images/{t.cid}.webp')}",
                                   f"    image_credit: {flow_map(list(credit.items()))}"]))
        f.fields.append("image")
    tally(report, lang.targets, fills, lang.genders, audio, images)
    if write:
        by_file: dict[Path, list[tuple[re.Pattern, int, list]]] = {}
        for t in lang.targets:
            f = fills[t.cid]
            if f.core:
                by_file.setdefault(t.core, []).append(
                    (re.compile(rf'^  - id: "?{re.escape(t.cid)}"?\s*$'), 2, f.core))
            if f.layer and t.layer is not None and t.entry is not None:
                by_file.setdefault(t.layer, []).append(
                    (re.compile(rf'^  "{re.escape(t.cid)}":\s*$'), 2, f.layer))
        for path, edits in by_file.items():
            text = path.read_text(encoding="utf-8")
            for head, indent, adds in edits:
                text = apply(text, head, indent, adds)
            path.write_text(text, encoding="utf-8")
    digest = hashlib.sha256(dump.read_bytes()).hexdigest()
    return report.render(LANGUAGE_NAMES.get(code, code), dump, digest, dump_date,
                         len(lang.targets))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Fill a language's cards from kaikki.org's Wiktionary extract.")
    parser.add_argument("lang", help="the language's code, such as hi")
    parser.add_argument("dump", type=Path, help="the language's kaikki.org JSONL")
    parser.add_argument("--decks", type=Path, default=ROOT / "decks",
                        help="the decks folder (default: the repository's)")
    parser.add_argument("--dump-date",
                        help="the dump's date, YYYY-MM-DD (default: the file's)")
    parser.add_argument("--write", action="store_true",
                        help="fill the decks; without it, only report")
    parser.add_argument("--audio", action="store_true",
                        help="download and convert recordings (needs ffmpeg)")
    parser.add_argument("--images", action="store_true",
                        help="download and convert images for cards with a picture "
                             "(needs ffmpeg)")
    parser.add_argument("--report", type=Path, help="write the report here")
    args = parser.parse_args(argv[1:])
    if not vd.LANG_RE.fullmatch(args.lang) or not (args.decks / args.lang).is_dir():
        print(f"error: no decks for {args.lang!r} in {args.decks}", file=sys.stderr)
        return 2
    if not args.dump.is_file():
        print(f"error: {args.dump} does not exist", file=sys.stderr)
        return 2
    date = args.dump_date or dt.date.fromtimestamp(args.dump.stat().st_mtime).isoformat()
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        print(f"error: --dump-date must be YYYY-MM-DD, got {date!r}", file=sys.stderr)
        return 2
    try:
        text = run(args.lang, args.dump, args.decks, date, args.write, args.audio,
                   args.images)
    except ImportError_ as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    if args.report:
        args.report.write_text(text, encoding="utf-8")
        print(f"wrote {args.report}")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
