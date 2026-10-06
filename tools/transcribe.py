#!/usr/bin/env python3
"""A word's reading in ISO 15919 letters, as it is said, and its broad IPA
(ADR-0025).

    python3 tools/transcribe.py hi "कितना" kitna      # reading and IPA
    python3 tools/transcribe.py es "la casa"          # IPA

ISO 15919 writes letters, not sounds: कितना is `kitanā` letter for letter.
The decks write the word as it is said, in ISO 15919's letters: `kitnā`.
How a word is said is not in its letters alone. Hindi drops some inherent
vowels and keeps others, Bengali says one as [ɔ] or [o] or not at all, and
the anusvara is whichever nasal comes next. So the transcription takes a
hint: the word as people type it (`kitna`), which shows what is said. It
reads the hint against the letters, keeps the vowels the hint keeps, and
writes ISO letters and IPA for what is said. Without a hint, or with one
that does not fit the letters, it falls back on rules, and says so.

The tables below are each language's sounds. They are a contributor's aid
for writing a card's `reading` and `ipa`; the app reads neither from here.
Standard library only, like the other deck tools.
"""

from __future__ import annotations

import sys
import unicodedata
from dataclasses import dataclass, field

# --- Scripts -----------------------------------------------------------------

# The Indic blocks share one layout: a letter's offset from its block's
# start is the same in each script (ISCII order).
BLOCKS = {"hi": 0x0900, "mr": 0x0900, "bn": 0x0980, "as": 0x0980,
          "gu": 0x0A80, "te": 0x0C00, "kn": 0x0C80}

# Offsets of the independent vowels, and the vowel signs, to a vowel name.
VOWELS = {0x05: "a", 0x06: "aa", 0x07: "i", 0x08: "ii", 0x09: "u", 0x0A: "uu",
          0x0B: "r", 0x0D: "ce", 0x0E: "se", 0x0F: "e", 0x10: "ai",
          0x11: "co", 0x12: "so", 0x13: "o", 0x14: "au", 0x60: "rr",
          0x72: "ce", 0x73: "a", 0x74: "co"}
SIGNS = {0x3E: "aa", 0x3F: "i", 0x40: "ii", 0x41: "u", 0x42: "uu", 0x43: "r",
         0x44: "rr", 0x45: "ce", 0x46: "se", 0x47: "e", 0x48: "ai",
         0x49: "co", 0x4A: "so", 0x4B: "o", 0x4C: "au", 0x56: "ai",
         0x57: "au"}
# Offsets of the consonants, to an ISO 15919 letter.
CONSONANTS = {
    0x15: "k", 0x16: "kh", 0x17: "g", 0x18: "gh", 0x19: "ṅ",
    0x1A: "c", 0x1B: "ch", 0x1C: "j", 0x1D: "jh", 0x1E: "ñ",
    0x1F: "ṭ", 0x20: "ṭh", 0x21: "ḍ", 0x22: "ḍh", 0x23: "ṇ",
    0x24: "t", 0x25: "th", 0x26: "d", 0x27: "dh", 0x28: "n", 0x29: "ṉ",
    0x2A: "p", 0x2B: "ph", 0x2C: "b", 0x2D: "bh", 0x2E: "m",
    0x2F: "y", 0x30: "r", 0x31: "ṟ", 0x32: "l", 0x33: "ḷ", 0x34: "ḻ",
    0x35: "v", 0x36: "ś", 0x37: "ṣ", 0x38: "s", 0x39: "h",
}
# A consonant with a nukta, to the letter it makes.
NUKTA = {"k": "q", "kh": "k͟h", "g": "ġ", "j": "z", "ḍ": "ṛ", "ḍh": "ṛh",
         "ph": "f", "y": "ẏ", "n": "ṉ", "r": "ṟ", "ḷ": "ḻ"}
# Devanagari's composed nukta letters, and Bengali's.
COMPOSED = {0x0958: "q", 0x0959: "k͟h", 0x095A: "ġ", 0x095B: "z", 0x095C: "ṛ",
            0x095D: "ṛh", 0x095E: "f", 0x095F: "ẏ",
            0x09DC: "ṛ", 0x09DD: "ṛh", 0x09DF: "ẏ",
            0x09F0: "r",   # Assamese ৰ
            0x09F1: "v",   # Assamese ৱ
            0x0A5E: "f",
            0x0CDE: "ḻ"}   # Kannada ೞ
KHANDA_TA = 0x09CE        # Bengali ৎ: a t with no vowel
VIRAMA, NUKTA_SIGN, ANUSVARA, CANDRABINDU, VISARGA, AVAGRAHA = (
    0x4D, 0x3C, 0x02, 0x01, 0x03, 0x3D)
TELUGU_ARDHA = 0x0C01     # ఁ, the half nasal: also CANDRABINDU's offset
DIGITS = range(0x66, 0x70)
DANDA = {"।": ".", "॥": ".", "…": "...", "—": " - ", "–": " - "}
QUOTES = {"“": "'", "”": "'", "‘": "'", "’": "'", '"': "'"}
ZW = {"‌", "‍"}


@dataclass
class Unit:
    """One sound-bearing piece of the written word: a consonant, a vowel, a
    nasal or a mark, or a break between words."""
    kind: str             # C, V (written vowel), I (inherent vowel), N
                          # (anusvara), M (candrabindu), H (visarga),
                          # VIR (a virama ending a word), SP, P (punctuation)
    letter: str = ""      # ISO letter or vowel name; punctuation itself
    yaphala: bool = False  # Bengali ্য after this consonant
    vaphala: bool = False  # Bengali ্ব after this consonant
    # A conjunct said otherwise than its letters (ज्ञ gy): the ISO letters,
    # IPA and typed spellings this consonant is said with instead.
    fixed: tuple[str, str, list[str]] | None = None
    # Filled by alignment: the ISO letters and IPA for what is said.
    iso: str = ""
    ipa: str = ""
    said: str = ""        # the hint's letters this unit took


def parse(text: str, lang: str) -> list[Unit]:
    """[text] as units, in order. A consonant that carries no vowel sign and
    no virama is followed by its inherent vowel."""
    base = BLOCKS[lang]
    text = unicodedata.normalize("NFC", text)
    units: list[Unit] = []
    i = 0
    chars = [c for c in text if c not in ZW]

    def off(c: str) -> int | None:
        o = ord(c) - base
        return o if 0 <= o < 0x80 else None

    while i < len(chars):
        c = chars[i]
        o = off(c)
        cp = ord(c)
        if c.isspace():
            units.append(Unit("SP", " "))
            i += 1
            continue
        if cp in COMPOSED or (o is not None and o in CONSONANTS):
            letter = COMPOSED.get(cp) or CONSONANTS[o]
            if lang == "as" and cp == 0x09F1:
                letter = "w"
            i += 1
            if i < len(chars) and off(chars[i]) == NUKTA_SIGN:
                letter = NUKTA.get(letter, letter)
                i += 1
            if lang in ("bn", "as") and letter == "y" and units and \
                    units[-1].kind == "VIR" and False:
                pass
            unit = Unit("C", letter)
            units.append(unit)
            # What follows: a sign, a virama, or the inherent vowel.
            if i < len(chars) and off(chars[i]) == VIRAMA:
                i += 1
                # Bengali য-ফলা and ব-ফলা are marks on the consonant before.
                if lang in ("bn", "as") and i < len(chars):
                    nxt = off(chars[i])
                    # র্য is r and j, not a য-ফলা.
                    if nxt == 0x2F and ord(chars[i]) != 0x09DF and \
                            unit.letter != "r":
                        unit.yaphala = True
                        i += 1
                        i = _vowel_after(chars, i, off, units, lang)
                        continue
                    if nxt == 0x2C and unit.letter not in ("m", "b"):
                        unit.vaphala = True
                        i += 1
                        i = _vowel_after(chars, i, off, units, lang)
                        continue
                if i >= len(chars) or not _is_consonant(chars[i], off):
                    units.append(Unit("VIR"))
                continue
            i = _vowel_after(chars, i, off, units, lang)
            continue
        if cp == KHANDA_TA:
            units.append(Unit("C", "t"))
            units.append(Unit("VIR"))
            i += 1
            continue
        if o is not None and o in VOWELS:
            units.append(Unit("V", VOWELS[o]))
            i += 1
            continue
        if o is not None and o in (ANUSVARA, CANDRABINDU, VISARGA) or \
                (lang == "te" and ord(c) == 0x0C00):
            kind = {ANUSVARA: "N", CANDRABINDU: "M", VISARGA: "H"}.get(o, "M")
            units.append(Unit(kind))
            i += 1
            continue
        if o is not None and o in DIGITS:
            units.append(Unit("P", str(o - 0x66)))
            i += 1
            continue
        if o == AVAGRAHA:
            i += 1
            continue
        if c in DANDA:
            units.append(Unit("P", DANDA[c]))
        elif c in QUOTES:
            units.append(Unit("P", QUOTES[c]))
        else:
            units.append(Unit("P", c))
        i += 1
    if lang == "as":
        units = _apostrophes(units)
    return _clusters(units, lang)


def _apostrophes(units: list[Unit]) -> list[Unit]:
    """Assamese marks an inherent vowel said [o], not [ɔ], with an
    apostrophe after its consonant: ল'ৰা lorā."""
    out: list[Unit] = []
    for u in units:
        if u.kind == "P" and u.letter == "'" and out and out[-1].kind == "I":
            out[-1].letter = "o"
            continue
        out.append(u)
    return out


# Conjuncts said otherwise than their letters, by language: the two
# consonants' ISO letters, IPA and typed spellings, as said.
CLUSTERS = {
    "hi": {("j", "ñ"): [("g", "ɡ", ["g", "j", "d"]),
                        ("y", "j", ["y", "n", "ny", ""])],
           ("k", "ṣ"): [("k", "k", ["k"]),
                        ("ś", "ʃ", ["sh", "s", "ch", "x", "h"])]},
    "mr": {("j", "ñ"): [("d", "d̪", ["d", "g", "j"]),
                        ("ny", "ɲ", ["ny", "n", "y", ""])],
           ("k", "ṣ"): [("k", "k", ["k"]),
                        ("ṣ", "ʂ", ["sh", "s", "ch", "x", "h"])]},
    "gu": {("j", "ñ"): [("g", "ɡ", ["g", "j", "d"]),
                        ("n", "n", ["n", "ny", "y", ""])],
           ("k", "ṣ"): [("k", "k", ["k"]),
                        ("ś", "ʃ", ["sh", "s", "ch", "x", "h"])]},
    "bn": {("j", "ñ"): [("g", "ɡ", ["g"]), ("g", "ɡ", ["g", ""])],
           ("k", "ṣ"): [("k", "k", ["k", ""]), ("kh", "kʰ", ["kh", "k"])]},
    "as": {("j", "ñ"): [("g", "ɡ", ["g"]), ("y", "j", ["y", ""])],
           ("k", "ṣ"): [("k", "k", ["k", ""]), ("kh", "kʰ", ["kh", "k"])]},
}


def _clusters(units: list[Unit], lang: str) -> list[Unit]:
    table = CLUSTERS.get(lang, {})
    for k in range(len(units) - 1):
        a, b = units[k], units[k + 1]
        if a.kind == "C" and b.kind == "C" and (a.letter, b.letter) in table:
            first, second = table[(a.letter, b.letter)]
            a.fixed, b.fixed = first, second
    return units


def _is_consonant(c: str, off) -> bool:
    o = off(c)
    return ord(c) in COMPOSED or (o is not None and o in CONSONANTS)


def _vowel_after(chars, i, off, units, lang) -> int:
    if i < len(chars) and off(chars[i]) in SIGNS:
        units.append(Unit("V", SIGNS[off(chars[i])], ))
        units[-1].kind = "S"
        return i + 1
    if i < len(chars) and off(chars[i]) == VIRAMA:
        units.append(Unit("VIR"))
        return i + 1
    units.append(Unit("I", "a"))
    return i


# --- Languages ---------------------------------------------------------------

# How each vowel is written and said, by language: (ISO letters, IPA).
_VOWELS_TE = {"a": ("a", "a"), "aa": ("ā", "aː"), "i": ("i", "i"),
              "ii": ("ī", "iː"), "u": ("u", "u"), "uu": ("ū", "uː"),
              "r": ("ru", "ru"), "rr": ("rū", "ruː"), "se": ("e", "e"),
              "e": ("ē", "eː"), "ai": ("ai", "ai"), "so": ("o", "o"),
              "o": ("ō", "oː"), "au": ("au", "au"), "ce": ("ê", "æ"),
              "co": ("ô", "ɔ")}
VOWEL_TABLES = {
    "hi": {"a": ("a", "ə"), "aa": ("ā", "aː"), "i": ("i", "ɪ"),
           "ii": ("ī", "iː"), "u": ("u", "ʊ"), "uu": ("ū", "uː"),
           "r": ("ri", "rɪ"), "rr": ("rī", "riː"), "e": ("ē", "eː"),
           "se": ("e", "e"), "ai": ("ai", "ɛː"), "o": ("ō", "oː"),
           "so": ("o", "o"), "au": ("au", "ɔː"), "ce": ("ê", "ɛ"),
           "co": ("ô", "ɔ")},
    "mr": {"a": ("a", "ə"), "aa": ("ā", "a"), "i": ("i", "i"),
           "ii": ("i", "i"), "u": ("u", "u"), "uu": ("u", "u"),
           "r": ("ru", "ru"), "rr": ("ru", "ru"), "e": ("e", "e"),
           "se": ("e", "e"), "ai": ("ai", "əi"), "o": ("o", "o"),
           "so": ("o", "o"), "au": ("au", "əu"), "ce": ("ê", "æ"),
           "co": ("ô", "ɔ")},
    "gu": {"a": ("a", "ə"), "aa": ("ā", "a"), "i": ("i", "i"),
           "ii": ("i", "i"), "u": ("u", "u"), "uu": ("u", "u"),
           "r": ("ru", "ru"), "rr": ("ru", "ru"), "e": ("e", "e"),
           "se": ("e", "e"), "ai": ("ai", "əi"), "o": ("o", "o"),
           "so": ("o", "o"), "au": ("au", "əu"), "ce": ("ê", "ɛ"),
           "co": ("ô", "ɔ")},
    "bn": {"a": ("ô", "ɔ"), "aa": ("ā", "a"), "i": ("i", "i"),
           "ii": ("i", "i"), "u": ("u", "u"), "uu": ("u", "u"),
           "r": ("ri", "ri"), "rr": ("ri", "ri"), "e": ("e", "e"),
           "se": ("e", "e"), "ai": ("oi", "oi"), "o": ("o", "o"),
           "so": ("o", "o"), "au": ("ou", "ou"), "ce": ("ê", "æ"),
           "co": ("ô", "ɔ")},
    "as": {"a": ("ô", "ɔ"), "aa": ("ā", "a"), "i": ("i", "i"),
           "ii": ("i", "i"), "u": ("u", "u"), "uu": ("u", "u"),
           "r": ("ri", "ri"), "rr": ("ri", "ri"), "e": ("e", "e"),
           "se": ("e", "e"), "ai": ("ôi", "ɔi"), "o": ("u", "ʊ"),
           "so": ("u", "ʊ"), "au": ("ôu", "ɔu"), "ce": ("ê", "ɛ"),
           "co": ("ô", "ɔ")},
    "te": _VOWELS_TE,
    "kn": _VOWELS_TE,
}

# How each consonant is written and said, where a language departs from the
# ISO letter and the common IPA below.
_IPA = {"k": "k", "kh": "kʰ", "g": "ɡ", "gh": "ɡʱ", "ṅ": "ŋ",
        "c": "tʃ", "ch": "tʃʰ", "j": "dʒ", "jh": "dʒʱ", "ñ": "ɲ",
        "ṭ": "ʈ", "ṭh": "ʈʰ", "ḍ": "ɖ", "ḍh": "ɖʱ", "ṇ": "ɳ",
        "t": "t̪", "th": "t̪ʰ", "d": "d̪", "dh": "d̪ʱ", "n": "n", "ṉ": "n",
        "p": "p", "ph": "pʰ", "b": "b", "bh": "bʱ", "m": "m",
        "y": "j", "r": "r", "ṟ": "r", "l": "l", "ḷ": "ɭ", "ḻ": "ɻ",
        "v": "ʋ", "w": "w", "ś": "ʃ", "ṣ": "ʂ", "s": "s", "h": "ɦ",
        "q": "q", "k͟h": "x", "ġ": "ɣ", "z": "z", "f": "f",
        "ṛ": "ɽ", "ṛh": "ɽʱ", "ẏ": "j", "x": "x"}
CONSONANT_TABLES: dict[str, dict[str, tuple[str, str]]] = {
    "hi": {"ṣ": ("ś", "ʃ"), "ṟ": ("r", "r"), "ẏ": ("y", "j")},
    "mr": {"ṟ": ("r", "r")},
    "gu": {"ṣ": ("ś", "ʃ")},
    "bn": {"ṇ": ("n", "n"), "ñ": ("n", "n"), "y": ("j", "dʒ"),
           "ẏ": ("y", "j"), "v": ("b", "b"), "ṣ": ("ś", "ʃ"),
           "ś": ("ś", "ʃ"), "s": ("ś", "ʃ"), "h": ("h", "ɦ"),
           "ṛh": ("ṛ", "ɽ")},
    "as": {"c": ("s", "s"), "ch": ("s", "s"), "j": ("z", "z"),
           "jh": ("z", "z"), "y": ("z", "z"), "ẏ": ("y", "j"),
           "ṭ": ("t", "t"), "ṭh": ("th", "tʰ"), "ḍ": ("d", "d"),
           "ḍh": ("dh", "dʱ"), "t": ("t", "t"), "th": ("th", "tʰ"),
           "d": ("d", "d"), "dh": ("dh", "dʱ"), "ṇ": ("n", "n"),
           "ñ": ("n", "n"), "r": ("r", "ɹ"), "ṛ": ("r", "ɹ"),
           "ṛh": ("rh", "ɹ"), "ś": ("x", "x"), "ṣ": ("x", "x"),
           "s": ("x", "x"), "h": ("h", "h"), "v": ("b", "b"),
           "w": ("w", "w")},
    "te": {"ṟ": ("r", "r"), "h": ("h", "h")},
    "kn": {"ṟ": ("r", "r"), "ḻ": ("ḷ", "ɭ"), "h": ("h", "h")},
}


def consonant(letter: str, lang: str) -> tuple[str, str]:
    table = CONSONANT_TABLES[lang]
    if letter in table:
        return table[letter]
    return letter, _IPA[letter]


# How people type each ISO letter in chat: the spellings a hint may use.
TYPED = {
    "k": ["k", "c", "q"], "kh": ["kh", "k"], "g": ["g"], "gh": ["gh", "g"],
    "ṅ": ["ng", "n"], "c": ["ch", "c", "s"], "ch": ["chh", "ch", "c", "s"],
    "j": ["j", "z"], "jh": ["jh", "j", "z"], "ñ": ["ny", "n"],
    "ṭ": ["t"], "ṭh": ["th", "t"], "ḍ": ["d", "r"], "ḍh": ["dh", "d", "rh"],
    "ṇ": ["n"], "t": ["t", "th"], "th": ["th", "t"], "d": ["d", "dh"],
    "dh": ["dh", "d"], "n": ["n"], "ṉ": ["n"], "p": ["p"],
    "ph": ["ph", "f", "p"], "b": ["b", "v"], "bh": ["bh", "b", "v"],
    "m": ["m"], "y": ["y", "j", "z", "i", "e"], "r": ["r"], "ṟ": ["r"],
    "l": ["l"], "ḷ": ["l", "zh"], "ḻ": ["l", "zh"],
    "v": ["v", "w", "b", "o", "u"], "w": ["w", "v", "o", "u"],
    "ś": ["sh", "s", "x"], "ṣ": ["sh", "s", "x", "kh"], "s": ["s", "sh", "x"],
    "h": ["h"], "q": ["q", "k"], "k͟h": ["kh", "k"], "ġ": ["gh", "g"],
    "z": ["z", "j"], "f": ["f", "ph"], "ṛ": ["r", "d", "rr"],
    "ṛh": ["rh", "r", "dh", "d"], "ẏ": ["y", "e", "i"], "x": ["x"],
}
TYPED_VOWELS = {
    "a": ["a", "o", "u"], "aa": ["aa", "a"], "i": ["i", "e", "ee"],
    "ii": ["ee", "ii", "i"], "u": ["u", "o", "oo"], "uu": ["oo", "uu", "u"],
    "r": ["ri", "ru", "r", "rri"], "rr": ["ri", "ru"],
    "e": ["e", "ae", "ee", "a", "ay", "ai", "ya", "i"],
    "se": ["e", "a", "ae"], "ai": ["ai", "ae", "ei", "oi", "e", "ay", "ay"],
    "o": ["o", "oo", "u"], "so": ["o", "u"],
    "au": ["au", "ou", "o", "ow", "ao", "aw"], "ce": ["e", "a", "ae"],
    "co": ["o", "aw", "au"],
}


# --- Alignment ---------------------------------------------------------------

@dataclass
class Choice:
    iso: str
    ipa: str
    typed: list[str]
    cost: int = 0
    tag: str = ""


def _lower(hint: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFC", hint.lower()))


def choices(units: list[Unit], k: int, lang: str) -> list[Choice]:
    """The ways unit [k] may be said, each with how it is typed."""
    u = units[k]
    if u.kind == "C" and u.fixed:
        iso, ipa, typed = u.fixed
        out = [Choice(iso, ipa, [t for t in typed if t])]
        if "" in typed:
            out.append(Choice("", "", [""], 1, "silent"))
        return out
    if u.kind == "C":
        iso, ipa = consonant(u.letter, lang)
        typed = TYPED[u.letter]
        if u.yaphala or u.vaphala:
            glide = ("y",) if u.yaphala else ("w", "b", "o")
            typed = [d + x for t in typed for d in (t, _doubled(t))
                     for x in ("",) + glide]
        out = [Choice(iso, ipa, typed)]
        # A vowel said between two consonants written together: ख़त्म
        # khatam. It is typed, but not written.
        if k + 1 < len(units) and units[k + 1].kind == "C":
            out.append(Choice(iso, ipa, [t + "a" for t in typed], 2))
        # A doubled consonant is often typed once: సిక్కాపట్టె sikkapatte,
        # but అమ్మ amma.
        nxt = _next_consonant(units, k)
        if nxt is not None and nxt.letter in (u.letter, u.letter + "h"):
            out.append(Choice(iso, ipa, [""], 1, "single"))
        if u.letter in ("y", "ẏ", "v", "w", "h") or lang in ("bn", "as"):
            out.append(Choice("", "", [""], 3, "silent"))
        return out
    if u.kind in ("V", "S"):
        iso, ipa = VOWEL_TABLES[lang][u.letter]
        typed = TYPED_VOWELS[u.letter]
        # A vowel after a vowel is often typed with a glide: सुनिए suniye.
        if u.kind == "V" and k > 0 and units[k - 1].kind in ("S", "V", "I"):
            typed = typed + ["y" + t for t in typed] + ["w" + t for t in typed]
        out = [Choice(iso, ipa, typed)]
        if lang == "bn" and u.letter in ("e", "se"):
            out.append(Choice("ê", "æ", ["a", "ya", "ae"], 1, "ae"))
        if lang == "as" and u.letter in ("e", "se"):
            out.append(Choice("ê", "ɛ", ["e", "a", "ae"], 1, "ae"))
        if lang == "as" and u.letter in ("o", "so"):
            # ও is [ʊ], typed u; in words from English it is [o], typed o.
            out = [Choice(iso, ipa, ["u", "oo"]),
                   Choice("o", "o", ["o"], 0, "o")]
        return out
    if u.kind == "I" and u.letter == "o":
        return [Choice("o", "o", ["o", "u"])]
    if u.kind == "I":
        if lang in ("bn", "as"):
            return [Choice("ô", "ɔ", ["o", "a", "ô", "aw"]),
                    Choice("", "", [""], 0, "drop")]
        if lang in ("te", "kn"):
            return [Choice("a", "a", ["a", "u", "o", "e"]),
                    Choice("", "", [""], 4, "drop")]
        return [Choice("a", "ə", ["a", "u", "e", "o"]),
                Choice("", "", [""], 0, "drop")]
    if u.kind == "N":
        return [Choice("ṁ", "", ["n", "m", "ng", "nn", "mm", "nh", ""]),
                Choice("", "", [""], 2, "silent")]
    if u.kind == "M":
        # Telugu's half nasal ఁ is no longer said.
        if lang == "te":
            return [Choice("", "", ["", "n", "m"])]
        return [Choice("m̐", "̃", ["n", "m", "ng", "nn", ""])]
    if u.kind == "H":
        out = [Choice("ḥ", "h", ["h", "ha"]), Choice("", "", [""], 1)]
        # দুঃখ dukkho: before a consonant it doubles it.
        if k + 1 < len(units) and units[k + 1].kind == "C":
            iso, ipa = consonant(units[k + 1].letter, lang)
            first = iso[0] if iso else ""
            out.append(Choice(first, ipa.rstrip("ʰʱ"), [first], 0))
        return out
    if u.kind == "VIR":
        return [Choice("", "", ["", "u", "a", "o"])]
    if u.kind == "SP":
        return [Choice(" ", " ", [" ", "-", "", "  "])]
    return [Choice(u.letter, "", [u.letter, ""])]


def _doubled(typed: str) -> str:
    """A typed consonant held long: kk, and ddh for a held dh."""
    if len(typed) > 1 and typed.endswith("h"):
        return typed[:-1] + typed
    return typed + typed[-1:]


def _next_consonant(units: list[Unit], k: int) -> Unit | None:
    j = k + 1
    while j < len(units) and units[j].kind == "VIR":
        j += 1
    if j < len(units) and units[j].kind == "C" and k + 1 < len(units) and \
            units[k + 1].kind != "I" and units[k + 1].kind != "S":
        return units[j]
    return None


def align(units: list[Unit], hint: str, lang: str) -> list[Choice] | None:
    """The cheapest way to read [hint] as [units], one choice per unit, or
    None when it does not fit."""
    hint = _lower(hint)
    # Punctuation in the hint is not matched letter for letter: it is
    # dropped, and the script's own punctuation is written.
    hint = "".join(c for c in hint if c.isalnum() or c in " -")
    hint = " ".join(hint.split())
    n = len(units)
    INF = 10 ** 9
    # best[k][p]: cost of reading units[:k] as hint[:p].
    best = [[INF] * (len(hint) + 1) for _ in range(n + 1)]
    back: list[list[tuple[int, int] | None]] = [
        [None] * (len(hint) + 1) for _ in range(n + 1)]
    back_skip: list[list[int | None]] = [
        [None] * (len(hint) + 1) for _ in range(n + 1)]
    best[0][0] = 0
    opts = [choices(units, k, lang) for k in range(n)]
    for k in range(n):
        for p in range(len(hint) + 1):
            if best[k][p] >= INF:
                continue
            # A space or hyphen the letters do not have: ik-hattar.
            if p < len(hint) and hint[p] in " -" and \
                    best[k][p] + 1 < best[k][p + 1]:
                best[k][p + 1] = best[k][p] + 1
                back_skip[k][p + 1] = p
            for ci, ch in enumerate(opts[k]):
                for t in set(ch.typed):
                    if hint.startswith(t, p):
                        q = p + len(t)
                        # A consonant may be typed twice: అమ్మ amma is one
                        # m doubled, and a hint may double a single one.
                        c = best[k][p] + ch.cost + (1 if t == "" and
                                                    units[k].kind == "C" else 0)
                        if c < best[k + 1][q]:
                            best[k + 1][q] = c
                            back[k + 1][q] = (ci, p)
                        if units[k].kind == "C" and t and \
                                hint.startswith(t[-1], q):
                            q2 = q + 1
                            if best[k][p] + ch.cost + 1 < best[k + 1][q2]:
                                best[k + 1][q2] = best[k][p] + ch.cost + 1
                                back[k + 1][q2] = (ci, p)
    if best[n][len(hint)] >= INF:
        return None
    picked: list[Choice] = []
    p = len(hint)
    for k in range(n, 0, -1):
        while back[k][p] is None or (back_skip[k][p] is not None and
                                     _skip_better(best, back, k, p)):
            p = back_skip[k][p]
        ci, prev = back[k][p]
        ch = opts[k - 1][ci]
        picked.append(Choice(ch.iso, ch.ipa, [hint[prev:p]], ch.cost, ch.tag))
        p = prev
    picked.reverse()
    return picked


def _word_by_word(units: list[Unit], hint: str, lang: str
                  ) -> list[Choice] | None:
    """Each word of [units] read against its word of [hint], those that
    do not fit by the rules: so that one word typed oddly spoils only
    itself. None when the words do not pair up."""
    words: list[list[Unit]] = [[]]
    for u in units:
        if u.kind == "SP":
            words.append([])
        else:
            words[-1].append(u)
    hints = _lower(hint).split()
    if len(hints) != len(words):
        return None
    picked: list[Choice] = []
    for i, (word, h) in enumerate(zip(words, hints)):
        if i:
            picked.append(Choice(" ", " ", [" "]))
        got = align(word, h, lang) or default_choices(word, lang)
        picked.extend(got)
    return picked


def _skip_better(best, back, k, p) -> bool:
    return False


def default_choices(units: list[Unit], lang: str) -> list[Choice]:
    """Without a hint that fits: the first way of each unit, with the
    inherent vowel dropped where the language's rules drop it."""
    picked = [choices(units, k, lang)[0] for k in range(len(units))]
    for k, u in enumerate(units):
        if u.kind != "I":
            continue
        drop = False
        if lang in ("hi", "mr", "gu", "bn", "as"):
            end = k + 1 >= len(units) or units[k + 1].kind in ("SP", "P")
            # A word's last inherent vowel is not said, unless the word is a
            # single letter.
            first = k == 1 or (k >= 2 and units[k - 2].kind == "SP")
            if end and not first:
                drop = True
            elif lang in ("hi", "mr", "gu") and _schwa_drops(units, k):
                drop = True
        if drop:
            picked[k] = Choice("", "", [""], 0, "drop")
    return picked


def _schwa_drops(units: list[Unit], k: int) -> bool:
    """Hindi's rule, roughly: a schwa between a vowel and a consonant that
    is followed by a vowel is not said (VC_CV)."""
    if k < 2 or k + 2 >= len(units):
        return False
    before = units[k - 2]
    after_c, after_v = units[k + 1], units[k + 2]
    # The vowel after must be said: an inherent one ending the word is not.
    said_after = after_v.kind == "S" or (
        after_v.kind == "I" and k + 3 < len(units)
        and units[k + 3].kind not in ("SP", "P"))
    return (before.kind in ("V", "S", "I") and after_c.kind == "C"
            and said_after)


# --- Writing -----------------------------------------------------------------

@dataclass
class Transcription:
    reading: str
    ipa: str
    fitted: bool          # whether the hint fitted the letters
    notes: list[str] = field(default_factory=list)


HOMORGANIC = {"k": "ṅ", "kh": "ṅ", "g": "ṅ", "gh": "ṅ", "ṅ": "ṅ",
              "c": "ñ", "ch": "ñ", "j": "ñ", "jh": "ñ", "ñ": "ñ",
              "ṭ": "ṇ", "ṭh": "ṇ", "ḍ": "ṇ", "ḍh": "ṇ", "ṇ": "ṇ",
              "t": "n", "th": "n", "d": "n", "dh": "n", "n": "n",
              "p": "m", "ph": "m", "b": "m", "bh": "m", "m": "m"}
HOMORGANIC_IPA = {"ṅ": "ŋ", "ñ": "ɲ", "ṇ": "ɳ", "n": "n", "m": "m"}
FRONT = {"i", "ii", "e", "se", "ai", "ce"}


# Words said in a way neither their letters nor a typed hint can show:
# (language, word) to the reading and IPA.
WORDS = {
    ("bn", "পঁয়ত্রিশ"): ("pôm̐ytriś", "pɔ̃jt̪riʃ"),
    ("bn", "সাঁইত্রিশ"): ("śām̐itriś", "ʃãit̪riʃ"),
    ("bn", "পঁয়তাল্লিশ"): ("pôm̐ytālliś", "pɔ̃jt̪alliʃ"),
    ("bn", "পঁয়ষট্টি"): ("pôm̐yśôṭṭi", "pɔ̃jʃɔʈʈi"),
    ("bn", "ওয়ালাইকুম"): ("wālāikum", "walaikum"),
    ("bn", "জ্ঞ"): ("ggô", "ɡɡɔ"),
    # ঞ on its own, as a letter card names it, so that it differs from ন.
    ("bn", "ঞ"): ("ñô", "ɲɔ"),
    ("as", "ঞ"): ("ñô", "ɲɔ"),
    ("gu", "કંઈ"): ("kaim̐", "kə̃i"),
}


def transcribe(text: str, lang: str, hint: str | None = None
               ) -> Transcription:
    """[text]'s reading in ISO 15919 letters as said, and its broad IPA."""
    if lang == "es":
        return Transcription(text, spanish_ipa(text), True)
    if (lang, text) in WORDS:
        reading, ipa = WORDS[(lang, text)]
        return Transcription(reading, ipa, True)
    words = text.split(" ")
    if len(words) > 1 and any((lang, _bare(w)) in WORDS for w in words):
        hints = hint.split(" ") if hint else []
        if len(hints) != len(words):
            hints = [None] * len(words)
        parts = []
        for w, h in zip(words, hints):
            bare = _bare(w)
            if (lang, bare) in WORDS:
                r, i = WORDS[(lang, bare)]
                parts.append(Transcription(w.replace(bare, r), i, True))
            else:
                parts.append(transcribe(w, lang, h))
        return Transcription(" ".join(p.reading for p in parts),
                             " ".join(p.ipa for p in parts if p.ipa),
                             all(p.fitted for p in parts))
    return _transcribe(text, lang, hint)


def _bare(word: str) -> str:
    return "".join(c for c in word if c.isalpha() or
                   unicodedata.category(c).startswith("M"))


def _transcribe(text: str, lang: str, hint: str | None) -> Transcription:
    units = parse(text, lang)
    picked = align(units, hint, lang) if hint else None
    fitted = picked is not None
    if picked is None and hint:
        picked = _word_by_word(units, hint, lang)
    if picked is None:
        picked = default_choices(units, lang)
    iso: list[str] = []
    ipa: list[str] = []
    for k, (u, ch) in enumerate(zip(units, picked)):
        i_iso, i_ipa = ch.iso, ch.ipa
        typed = ch.typed[0] if ch.typed else ""
        if u.kind == "C":
            if ch.tag == "silent":
                i_iso, i_ipa = "", ""
            # Bengali and Assamese say a sibilant as s where it is typed s.
            if lang in ("bn", "as") and u.letter in ("ś", "ṣ", "s") and \
                    typed.startswith("s") and not typed.startswith("sh"):
                i_iso, i_ipa = "s", "s"
            # ফ, ಫ in a word from English is f, typed f: ಫ್ಲಾಟ್ flat.
            if u.letter == "ph" and typed.startswith("f"):
                i_iso, i_ipa = "f", "f"
            # য় after a vowel is said as the vowel it is typed as.
            if u.letter == "ẏ" and typed in ("i", "e"):
                i_iso, i_ipa = typed, typed
            # A ম-ফলা not said holds the consonant before it: আত্মীয়
            # āttiyo.
            if lang in ("bn", "as") and k + 1 < len(units) and \
                    units[k + 1].kind == "C" and units[k + 1].letter == "m" \
                    and picked[k + 1].tag == "silent" and i_iso:
                i_iso, i_ipa = _held(i_iso, i_ipa)
            # ठ्ठ, a held ṭh, is said ṭṭh.
            nxt = _next_consonant(units, k)
            if nxt is not None and nxt.letter == u.letter and \
                    u.letter.endswith("h") and len(i_iso) > 1:
                i_iso, i_ipa = i_iso[:-1], i_ipa.rstrip("ʰʱ")
            # Marathi says च and ज as ts and dz before a back vowel.
            if lang == "mr" and u.letter in ("c", "j", "jh") and not u.fixed:
                v = _vowel_of(units, k)
                if v is not None and v not in FRONT and v != "y":
                    i_ipa = {"c": "ts", "j": "dz", "jh": "dzʱ"}[u.letter]
            if u.yaphala and lang == "as":
                # Assamese says a য-ফলা as a y glide: ব্যস্ত byôsto.
                i_iso, i_ipa = i_iso + "y", i_ipa + "j"
            elif (u.yaphala or u.vaphala) and i_iso and \
                    not _cluster_initial(units, k):
                i_iso, i_ipa = _held(i_iso, i_ipa)
        elif u.kind == "N":
            if ch.tag == "silent" or typed == "":
                i_iso, i_ipa = _nasal_vowel(lang)
            elif lang in ("bn", "as"):
                # Bengali and Assamese say ং as ng whatever follows.
                i_iso, i_ipa = "ṅ", "ŋ"
            else:
                nxt = _next_letter(units, k)
                if typed.startswith("m") and (nxt is None or
                                              nxt not in HOMORGANIC or
                                              HOMORGANIC[nxt] == "m"):
                    i_iso, i_ipa = "m", "m"
                elif nxt in HOMORGANIC:
                    n = HOMORGANIC[nxt]
                    if lang in ("bn", "as") and n in ("ñ", "ṇ"):
                        n = "n"
                    i_iso, i_ipa = n, HOMORGANIC_IPA[n]
                elif lang in ("bn", "as"):
                    i_iso, i_ipa = "ṅ", "ŋ"
                elif nxt is not None and lang in ("hi", "mr", "gu"):
                    # Before y, r, l, v, a sibilant or h it nasalises the
                    # vowel, and is written as the anusvara: saṁsār.
                    i_iso, i_ipa = "ṁ", "̃"
                elif nxt is None and lang in ("hi", "mr", "gu"):
                    i_iso, i_ipa = _nasal_vowel(lang)
                else:
                    i_iso, i_ipa = "m", "m"
        elif u.kind == "I" and i_iso and lang in ("bn", "as") and \
                u.letter != "o":
            i_iso, i_ipa = _bengali_inherent(units, k, lang, typed)
        elif u.kind in ("V", "S") and lang == "bn" and k > 0 and \
                units[k - 1].kind == "C" and units[k - 1].yaphala and \
                _cluster_initial(units, k - 1) and u.letter == "aa":
            i_iso, i_ipa = "ê", "æ"
        if u.kind == "I" and lang == "bn" and i_iso and k > 0 and \
                units[k - 1].kind == "C" and units[k - 1].yaphala and \
                _cluster_initial(units, k - 1):
            i_iso, i_ipa = "ê", "æ"
        if (u.kind == "M" and i_iso) or (u.kind == "N" and i_ipa == "̃"):
            _nasalise(ipa)
            iso.append(i_iso)
            continue
        if u.kind == "P":
            iso.append(u.letter if u.letter not in "'\"" else "'")
            continue
        iso.append(i_iso)
        ipa.append(i_ipa)
    reading = _tidy("".join(iso))
    out_ipa = unicodedata.normalize("NFC", " ".join("".join(ipa).split()))
    return Transcription(reading, out_ipa, fitted)


def _held(iso: str, ipa: str) -> tuple[str, str]:
    """A consonant held long, as a য-ফলা makes it: dd, and ddh for dh."""
    if len(iso) > 1 and iso.endswith("h"):
        return iso[:-1] + iso, ipa.rstrip("ʰʱ") + ipa
    return iso + iso, ipa + ipa


def _nasal_vowel(lang: str) -> tuple[str, str]:
    return "m̐", "̃"


def _nasalise(ipa: list[str]) -> None:
    """Put a nasal tilde on the vowel just written."""
    for j in range(len(ipa) - 1, -1, -1):
        s = ipa[j]
        if not s or s == " ":
            continue
        if s.endswith("ː"):
            ipa[j] = s[:-1] + "̃ː"
        elif s[-1] in "aeiouəɛɔæɪʊ":
            ipa[j] = s + "̃"
        return


def _vowel_of(units: list[Unit], k: int) -> str | None:
    if k + 1 >= len(units):
        return None
    nxt = units[k + 1]
    if nxt.kind in ("S", "V"):
        return nxt.letter
    if nxt.kind == "I":
        return "a"
    if nxt.kind == "C":
        return nxt.letter
    return None


def _next_letter(units: list[Unit], k: int) -> str | None:
    for j in range(k + 1, len(units)):
        if units[j].kind == "C":
            return units[j].letter
        if units[j].kind in ("SP", "P", "V"):
            return None
    return None


def _cluster_initial(units: list[Unit], k: int) -> bool:
    """Whether unit [k] is in its word's first cluster: only consonants
    come before it in the word, as ফ and ল do in ফ্ল্যাট."""
    j = k - 1
    while j >= 0 and units[j].kind == "C":
        j -= 1
    return j < 0 or units[j].kind in ("SP", "P")


def _word_initial(units: list[Unit], k: int) -> bool:
    return k == 0 or units[k - 1].kind in ("SP", "P")


def _bengali_inherent(units: list[Unit], k: int, lang: str, typed: str
                      ) -> tuple[str, str]:
    """Bengali's and Assamese's inherent vowel, when said: [ɔ] in a word's
    first syllable unless an i or u follows in the next, and [o] after
    the first syllable and before an i or u (ADR-0025; the common rules,
    which have exceptions)."""
    # Is this the first syllable of its word?
    j = k - 1
    first = True
    while j >= 0 and units[j].kind not in ("SP", "P"):
        if units[j].kind in ("V", "S", "I"):
            first = False
            break
        j -= 1
    nxt = None
    for j in range(k + 1, len(units)):
        if units[j].kind in ("SP", "P"):
            break
        if units[j].kind in ("V", "S", "I"):
            nxt = units[j]
            break
    harmony = nxt is not None and nxt.letter in ("i", "ii", "u", "uu", "r")
    if lang == "as":
        return ("o", "o") if harmony else ("ô", "ɔ")
    # The vowel before ক্ষ or a য-ফলা is [o] too.
    follows_cluster = k + 1 < len(units) and units[k + 1].kind == "C" and \
        units[k + 1].yaphala
    if first and not harmony and not follows_cluster:
        return "ô", "ɔ"
    return "o", "o"


def _tidy(reading: str) -> str:
    reading = " ".join(reading.split())
    for mark in ".,?!;:":
        reading = reading.replace(" " + mark, mark)
    return unicodedata.normalize("NFC", reading)


# --- Spanish -----------------------------------------------------------------

_ES_ACCENT = {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u"}
_ES_VOWELS = set("aeiouáéíóúü")
_ES_ONSETS = {"pl", "pr", "bl", "br", "fl", "fr", "kl", "kr", "gl", "gr",
              "tr", "dr", "tl"}
_ES_CLITICS = {"el", "la", "los", "las", "lo", "le", "les", "de", "del",
               "que", "y", "e", "en", "a", "al", "un", "una", "con", "por",
               "mi", "tu", "su", "me", "te", "se", "nos", "o", "u", "sin"}


def spanish_ipa(text: str) -> str:
    """Castilian Spanish, as the decks' es-ES voice says it, broad: b d ɡ
    for β ð ɣ, θ for c and z, ʝ for ll and y, and the stress marked on
    words of two syllables or more (ADR-0025)."""
    words = []
    for raw in text.lower().split():
        word = "".join(c for c in raw if c.isalpha())
        if word:
            words.append(_es_word(word))
    return " ".join(w for w in words if w)


def _es_word(word: str) -> str:
    # Letters to phonemes, with each vowel's written accent kept aside.
    out: list[tuple[str, bool]] = []    # (phoneme, stressed by accent)
    i = 0
    w = word
    while i < len(w):
        c = w[i]
        nxt = w[i + 1] if i + 1 < len(w) else ""
        if c in "aeiouáéíóú":
            out.append((_ES_ACCENT.get(c, c), c in _ES_ACCENT))
        elif c == "ü":
            out.append(("w", False))
        elif c == "b" or c == "v":
            out.append(("b", False))
        elif c == "c":
            if nxt == "h":
                out.append(("tʃ", False))
                i += 1
            elif nxt in ("e", "i", "é", "í"):
                out.append(("θ", False))
            else:
                out.append(("k", False))
        elif c == "g":
            if nxt in ("e", "i", "é", "í"):
                out.append(("x", False))
            elif nxt == "u" and i + 2 < len(w) and w[i + 2] in "eiéí":
                out.append(("ɡ", False))
                i += 1
            else:
                out.append(("ɡ", False))
        elif c == "q":
            out.append(("k", False))
            if nxt == "u":
                i += 1
        elif c == "h":
            pass
        elif c == "j":
            out.append(("x", False))
        elif c == "l" and nxt == "l":
            out.append(("ʝ", False))
            i += 1
        elif c == "ñ":
            out.append(("ɲ", False))
        elif c == "r":
            if nxt == "r":
                out.append(("r", False))
                i += 1
            elif i == 0 or w[i - 1] in "nls":
                out.append(("r", False))
            else:
                out.append(("ɾ", False))
        elif c == "y":
            if i == len(w) - 1 or nxt not in _ES_VOWELS:
                out.append(("i", False))
            else:
                out.append(("ʝ", False))
        elif c == "z":
            out.append(("θ", False))
        elif c == "x":
            out.extend([("k", False), ("s", False)])
        else:
            out.append((c, False))
        i += 1
    # Unstressed i and u beside another vowel are glides.
    phon = [p for p, _ in out]
    acc = [a for _, a in out]
    vowels = set("aeiou")
    for k, p in enumerate(phon):
        if p in ("i", "u") and not acc[k]:
            before = k > 0 and phon[k - 1] in vowels
            after = k + 1 < len(phon) and phon[k + 1] in vowels
            if after or (before and not (k + 1 < len(phon)
                                         and phon[k + 1] in vowels)):
                if after or before:
                    # i between vowels, or i/u before or after one
                    if after and before and phon[k - 1] in "iu":
                        continue
                    phon[k] = "j" if p == "i" else "w"
    # Syllables: each vowel a nucleus; consonants between go to the next
    # syllable, but for a cluster that cannot begin one.
    nuclei = [k for k, p in enumerate(phon) if p in vowels]
    if not nuclei:
        return "".join(phon)
    starts = [0]
    for a, b in zip(nuclei, nuclei[1:]):
        between = list(range(a + 1, b))
        cons = [k for k in between if phon[k] not in ("j", "w")]
        glides_after = [k for k in between if phon[k] in ("j", "w")]
        if not between:
            starts.append(b)
            continue
        # glides belong with the following vowel when before it
        core = [k for k in between]
        # consonants (not glides) in the gap
        c_only = [k for k in core if phon[k] not in ("j", "w")]
        if len(c_only) <= 1:
            start = c_only[0] if c_only else (glides_after[0] if
                                               glides_after and
                                               glides_after[0] > a + 0
                                               else b)
            # a glide right after the first vowel stays with it
            if not c_only:
                g = [k for k in core if k > a]
                start = b if all(k == a + 1 for k in g) and len(g) == 1 \
                    and phon[a + 1] in ("j", "w") and False else \
                    (g[-1] if g and phon[g[-1]] in ("j", "w") and
                     g[-1] == b - 1 and len(g) > 1 else b)
            starts.append(start)
            continue
        last_two = "".join(_es_letter(phon[k]) for k in c_only[-2:])
        if last_two in _ES_ONSETS:
            starts.append(c_only[-2])
        else:
            starts.append(c_only[-1])
    syllables = []
    bounds = starts + [len(phon)]
    for a, b in zip(bounds, bounds[1:]):
        syllables.append(phon[a:b])
    # Stress: the accented syllable, else the second to last if the word
    # ends in a vowel, n or s, else the last.
    stressed = None
    for si, syl in enumerate(syllables):
        idx = bounds[si]
        if any(acc[idx + j] for j in range(len(syl))):
            stressed = si
    if stressed is None:
        end = word[-1]
        if len(syllables) == 1:
            stressed = 0
        elif end in "aeiouns":
            stressed = len(syllables) - 2
        else:
            stressed = len(syllables) - 1
    text = ""
    for si, syl in enumerate(syllables):
        if si == stressed and len(syllables) > 1:
            text += "ˈ"
        text += "".join(syl)
    return text


def _es_letter(p: str) -> str:
    return {"ɡ": "g", "ɾ": "r", "θ": "z"}.get(p, p)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    lang, text = argv[1], argv[2]
    hint = argv[3] if len(argv) > 3 else None
    t = transcribe(text, lang, hint)
    print(f"reading: {t.reading}")
    print(f"ipa:     /{t.ipa}/")
    if hint and not t.fitted:
        print("the hint did not fit the letters; the rules were used")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
