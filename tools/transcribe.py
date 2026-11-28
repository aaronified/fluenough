#!/usr/bin/env python3
"""A word's reading in ISO 15919 letters, as it is said, and its broad IPA
(ADR-0025).

    python3 tools/transcribe.py hi "कितना" kitna      # reading and IPA
    python3 tools/transcribe.py es "la casa"          # IPA
    python3 tools/transcribe.py fr "les enfants"      # IPA
    python3 tools/transcribe.py ml "ഞാൻ വരുന്നു"       # reading and IPA
    python3 tools/transcribe.py sa "संस्कृतम्"          # IAST reading and IPA
    python3 tools/transcribe.py ur "کتنا" kitna       # Urdu script (also `hi`)

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

import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

# --- Scripts -----------------------------------------------------------------

# The Indic blocks share one layout: a letter's offset from its block's
# start is the same in each script (ISCII order).
BLOCKS = {"hi": 0x0900, "mr": 0x0900, "sa": 0x0900, "vsn": 0x0900, "bn": 0x0980, "as": 0x0980,
          "gu": 0x0A80, "ta": 0x0B80, "te": 0x0C00, "kn": 0x0C80,
          "ml": 0x0D00}

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
            0x0CDE: "ḻ",   # Kannada ೞ
            0x0C58: "ts",  # Telugu ౘ, the archaic ts (not in ISO 15919)
            0x0C59: "dz"}  # Telugu ౙ, the archaic dz (not in ISO 15919)
# Telugu's vocalic l: ఌ ౡ, and the signs ౢ ౣ, by offset.
TE_VOWELS = {0x0C: "l", 0x61: "ll"}
TE_SIGNS = {0x62: "l", 0x63: "ll"}
KHANDA_TA = 0x09CE        # Bengali ৎ: a t with no vowel
# Malayalam's chillu letters, a consonant with no vowel, by offset: ൺ ൻ ർ ൽ
# ൾ ൿ. ൻ is written ṉ, as the decks write it, where ന is n.
CHILLU = {0x7A: "ṇ", 0x7B: "ṉ", 0x7C: "r", 0x7D: "l", 0x7E: "ḷ", 0x7F: "k"}
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
                    # র্ব is r and b, not a ব-ফলা: পূর্ব purbo.
                    if nxt == 0x2C and unit.letter not in ("m", "b", "r"):
                        unit.vaphala = True
                        i += 1
                        i = _vowel_after(chars, i, off, units, lang)
                        continue
                if i >= len(chars) or not _is_consonant(chars[i], off):
                    units.append(Unit("VIR"))
                continue
            i = _vowel_after(chars, i, off, units, lang)
            continue
        if lang == "ml" and o in CHILLU:
            units.append(Unit("C", CHILLU[o]))
            units.append(Unit("VIR"))
            i += 1
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
        if lang == "te" and o is not None and o in TE_VOWELS:
            units.append(Unit("V", TE_VOWELS[o]))
            i += 1
            continue
        # A Telugu dependent vowel sign with no consonant before it (a
        # suffix written -ిన, or a bare ending ాం) is read as the vowel
        # it stands for, with no consonant and no inherent a (#1357).
        if lang == "te" and o is not None and (o in SIGNS or o in TE_SIGNS):
            units.append(Unit("V", SIGNS.get(o) or TE_SIGNS[o]))
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
    if lang == "te" and i < len(chars) and off(chars[i]) in TE_SIGNS:
        units.append(Unit("S", TE_SIGNS[off(chars[i])]))
        return i + 1
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
              "l": ("l\u0325", "lu"), "ll": ("l\u0325\u0304", "luː"),
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
    # Tamil: five short and five long vowels and two diphthongs; the decks
    # say the short ones as they are written (no schwa), ஐ ai and ஔ au.
    "ta": {"a": ("a", "a"), "aa": ("ā", "aː"), "i": ("i", "i"),
           "ii": ("ī", "iː"), "u": ("u", "u"), "uu": ("ū", "uː"),
           "se": ("e", "e"), "e": ("ē", "eː"), "ai": ("ai", "ai"),
           "so": ("o", "o"), "o": ("ō", "oː"), "au": ("au", "au")},
    # Malayalam: ഋ is said ru. The inherent a is said [ə] unless it is the
    # word's last vowel (malayalam() below).
    "ml": {"a": ("a", "ə"), "aa": ("ā", "aː"), "i": ("i", "i"),
           "ii": ("ī", "iː"), "u": ("u", "u"), "uu": ("ū", "uː"),
           "r": ("ṛ", "ɾɯ"), "rr": ("ṝ", "ɾɯː"), "se": ("e", "e"),
           "e": ("ē", "eː"), "ai": ("ai", "ai"), "so": ("o", "o"),
           "o": ("ō", "oː"), "au": ("au", "au")},
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
        "ṛ": "ɽ", "ṛh": "ɽʱ", "ẏ": "j", "x": "x",
        "ts": "ts", "dz": "dz"}
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
    # Tamil's stops are one letter each: the decks write and say them
    # voiceless (the voicing between vowels is the narrow IPA's job,
    # tools/derive_phonetic.py). ச is s, but tʃ doubled or after ஞ
    # (tamil() below). ற is [r], ர the tap [ɾ].
    "ta": {"c": ("c", "s"), "r": ("r", "ɾ"), "ṟ": ("ṟ", "r"),
           "h": ("h", "h")},
    "te": {"ṟ": ("ṟ", "r"), "h": ("h", "h")},
    "kn": {"ṟ": ("r", "r"), "ḻ": ("ḷ", "ɭ"), "h": ("h", "h")},
    # Malayalam's ര and റ are both a tap; ḻ (ഴ) is kept apart from ḷ (ള).
    "ml": {"r": ("r", "ɾ"), "ṟ": ("ṟ", "ɾ"), "h": ("h", "h")},
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
    "h": ["h"], "ts": ["ts", "ch", "c", "s"], "dz": ["dz", "j", "z"],
    "q": ["q", "k"], "k͟h": ["kh", "k"], "ġ": ["gh", "g"],
    "z": ["z", "j"], "f": ["f", "ph"], "ṛ": ["r", "d", "rr"],
    "ṛh": ["rh", "r", "dh", "d"], "ẏ": ["y", "e", "i"], "x": ["x"],
}
TYPED_VOWELS = {
    "a": ["a", "o", "u"], "aa": ["aa", "a"], "i": ["i", "e", "ee"],
    "ii": ["ee", "ii", "i"], "u": ["u", "o", "oo"], "uu": ["oo", "uu", "u"],
    "r": ["ri", "ru", "r", "rri"], "rr": ["ri", "ru"],
    "l": ["lu", "li", "l"], "ll": ["lu", "li", "l"],
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


_LONG_TYPED = {"ii": "ī", "uu": "ū", "e": "ē", "o": "ō", "se": "ē",
               "so": "ō", "aa": "ā"}


def _iso_typed(ch: Choice, u: Unit) -> set[str]:
    """Spellings in ISO 15919's own letters that also fit a choice."""
    out = {ch.iso} if ch.iso else set()
    if u.kind in ("V", "S") and u.letter in _LONG_TYPED:
        out.add(_LONG_TYPED[u.letter])
    return out


def align(units: list[Unit], hint: str, lang: str) -> list[Choice] | None:
    """The cheapest way to read [hint] as [units], one choice per unit, or
    None when it does not fit."""
    hint = _lower(hint)
    # Punctuation in the hint is not matched letter for letter: it is
    # dropped, and the script's own punctuation is written.
    # A combining mark (ISO 15919's m̐, r̥) is part of the letter before it.
    hint = "".join(c for c in hint if c.isalnum() or c in " -" or
                   unicodedata.category(c).startswith("M"))
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
                # A stored reading is passed as the hint (transcribe_decks):
                # the choice's own ISO letters fit it, and so do the long
                # vowels ī ū ē ō where the reading writes them, so a hint
                # in the course's own letters is no longer dropped.
                for t in set(ch.typed) | _iso_typed(ch, units[k]):
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
    marathi_medial = _marathi_medial_drops(units) if lang == "mr" else set()
    for k, u in enumerate(units):
        if u.kind != "I":
            continue
        drop = False
        if lang in ("hi", "mr", "gu", "bn", "as"):
            end = k + 1 >= len(units) or units[k + 1].kind in ("SP", "P")
            # Bengali says a word's last vowel after a ব-ফলা: বিশ্ব biśśo.
            # After a য-ফলা too: সত্য śotto. And after র্ব, which is r and b,
            # not a ফলা: পূর্ব purbo.
            # Assamese keeps the vowel of a conjunct shown on a card of its
            # own, ক্ত ktô (all 23 such cards of the course), and drops it
            # after a ব-ফলা or র্ব, which Bengali says: ভ্ৰাতৃত্ব bhrātritt,
            # গৰ্ব gôrb (every such word of the course). After a য-ফলা the
            # course is mixed (নৃত্য nritj, but ৰাজ্য rāzjô), so Assamese
            # keeps Bengali's rule there.
            if end and lang == "as" and _bare_conjunct_word(units, k):
                continue
            if end and lang in ("bn", "as") and k > 0 and \
                    units[k - 1].kind == "C" and \
                    (units[k - 1].yaphala or
                     (lang == "bn" and (units[k - 1].vaphala or
                                        _rba_cluster(units, k - 1)))):
                continue
            # A word's last inherent vowel is not said, unless the word is a
            # single letter.
            first = k == 1 or (k >= 2 and units[k - 2].kind == "SP")
            if end and not first:
                drop = not _said_after_cluster(units, k, lang)
            elif lang == "mr":
                drop = k in marathi_medial
            elif lang in ("hi", "gu", "bn") and _schwa_drops(units, k):
                drop = True
        if drop:
            picked[k] = Choice("", "", [""], 0, "drop")
    return picked


# Letters after which a word's last vowel is said when a cluster ends in
# them (Hindi, Marathi, Gujarati; no-hint fix 1, #315): मित्र mitra.
_CLUSTER_END_SAID = {"r", "y", "v", "n", "ṇ", "m", "l"}


def _said_after_cluster(units: list[Unit], k: int, lang: str) -> bool:
    """Whether the inherent vowel ending a word is said, because the word
    ends in a cluster whose last consonant is r, y, v, n, ṇ, m or l."""
    if lang not in ("hi", "mr", "gu") or k < 2:
        return False
    last, before = units[k - 1], units[k - 2]
    return (last.kind == "C" and last.letter in _CLUSTER_END_SAID
            and not last.fixed and before.kind == "C")


# Consonants a Bengali or Assamese sibilant stays s before (no-hint fix 3):
# the stops and the dentals n and l.
_SIBILANT_STAYS_S = {"k", "kh", "g", "gh", "ṭ", "ṭh", "ḍ", "ḍh", "t", "th",
                     "d", "dh", "p", "ph", "b", "bh", "n", "l"}


def _sibilant_by_rule(units: list[Unit], k: int, lang: str
                      ) -> tuple[str, str]:
    """A Bengali or Assamese sibilant with no hint: the language's table
    (ś in Bengali, x in Assamese), but s before a dental or a stop."""
    nxt = units[k + 1] if k + 1 < len(units) else None
    if nxt is not None and nxt.kind == "C" and \
            nxt.letter in _SIBILANT_STAYS_S:
        return "s", "s"
    return consonant(units[k].letter, lang)


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


_OBSTRUENT = {"k", "kh", "g", "gh", "c", "ch", "j", "jh", "ṭ", "ṭh", "ḍ",
              "ḍh", "t", "th", "d", "dh", "p", "ph", "b", "bh", "s", "ś", "ṣ"}


def _marathi_medial_drops(units: list[Unit]) -> set[int]:
    """The inherent vowels Marathi does not say inside a word (#1476, owner
    2026-11-21: "2. Fix"). Hindi's VC_CV rule (`_schwa_drops`) stays, because
    the course's hand-typed readings follow it, side-by-side drops included
    (निवडणे nivḍṇe, नवरदेव navrdev, साखरपुडा sākhrpuḍā, सहनशीलता sahnśiltā).
    It over-deleted in two cases the course has no word for, so only these are
    cut back, to every other schwa counted from the right:
    a chain of three or more side-by-side drops (स्वजनजनधनाचा
    svajnjndhnācā, सकलमति saklmti), and a pair that would leave an
    obstruent, v or y, and an obstruent in a row (गजवदन gajvdan: no card of
    the course has such a run). A chain that ends before ṇ (the -णे and -णूक
    endings) is kept whole, as the course types it. A word's last vowel is
    not said and is never a drop here: `_schwa_drops` counts it as not said,
    so it is not a neighbour either."""
    drops = {k for k, u in enumerate(units)
             if u.kind == "I" and _schwa_drops(units, k)}
    for k in sorted(drops):
        if k not in drops or k - 2 in drops:
            continue
        chain = [k]
        while chain[-1] + 2 in drops:
            chain.append(chain[-1] + 2)
        if len(chain) < 2 or units[chain[-1] + 1].letter == "ṇ":
            continue
        a, b = units[chain[0] - 1], units[chain[0] + 1]
        c = units[chain[1] + 1]
        glide_run = (len(chain) == 2 and a.letter in _OBSTRUENT
                     and b.letter in ("v", "y") and c.letter in _OBSTRUENT)
        if len(chain) >= 3 or glide_run:
            for j in range(len(chain) - 2, -1, -2):
                drops.discard(chain[j])
    return drops


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
TE_ANUSVARA_BEFORE = {"s", "v", "l"}
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
    # Assamese digits, read as the course reads them on its number cards.
    ("as", "০"): ("xūnyô", "xunjɔ"),
    ("as", "১"): ("ek", "ek"),
    ("as", "২"): ("dui", "dui"),
    ("as", "৩"): ("tini", "tini"),
    ("as", "৪"): ("sāri", "saɹi"),
    ("as", "৫"): ("pām̐s", "pãs"),
    ("as", "৬"): ("sôy", "sɔj"),
    ("as", "৭"): ("xāt", "xat"),
    ("as", "৮"): ("āth", "atʰ"),
    ("as", "৯"): ("nô", "nɔ"),
    ("gu", "કંઈ"): ("kaim̐", "kə̃i"),
}


def transcribe(text: str, lang: str, hint: str | None = None
               ) -> Transcription:
    """[text]'s reading in ISO 15919 letters as said, and its broad IPA."""
    if lang in PERSO_ARABIC and (lang in PERSO_ARABIC_ONLY or
                                 _perso_arabic(text)):
        return urdu(text, hint)
    if lang == "es":
        return Transcription(text, spanish_ipa(text), True)
    if lang == "fr":
        return Transcription(text, french_ipa(text), True)
    if lang == "sw":
        return Transcription(text, swahili_ipa(text), True)
    if lang == "it":
        return _italian(text, hint)
    if lang == "de":
        return _german(text, hint)
    if lang == "ru":
        return _russian(text, hint)
    if lang == "el":
        return _greek(text, hint)
    if lang == "ja":
        return japanese(text)
    if lang == "ko":
        return korean(text)
    if lang == "zh":
        return mandarin(text, hint)
    if lang == "tok":
        return toki_pona(text)
    if lang == "ml":
        return malayalam(text, hint)
    if lang == "ta":
        return tamil(text)
    if lang == "sat":
        return santali(text)
    if lang in ("sa", "vsn"):
        return sanskrit(text, lang)
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


def _perso_arabic(text: str) -> bool:
    """Whether [text] is Perso-Arabic: it has an Arabic-block letter and no
    Devanagari letter (an Arabic comma or digit does not make it Urdu)."""
    arabic = any(c.isalpha() and (0x0600 <= ord(c) <= 0x06FF or
                                  0x0750 <= ord(c) <= 0x077F) for c in text)
    deva = any(c.isalpha() and 0x0900 <= ord(c) <= 0x097F for c in text)
    return arabic and not deva


def _bare(word: str) -> str:
    return "".join(c for c in word if c.isalpha() or
                   unicodedata.category(c).startswith("M"))


def _transcribe(text: str, lang: str, hint: str | None) -> Transcription:
    units = parse(text, lang)
    picked = align(units, hint, lang) if hint else None
    fitted = picked is not None
    if picked is None and hint:
        picked = _word_by_word(units, hint, lang)
    by_rule = picked is None
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
            # With no hint nothing is typed: the language's table decides.
            if lang in ("bn", "as") and u.letter in ("ś", "ṣ", "s") and \
                    by_rule and not u.fixed and ch.tag != "silent":
                i_iso, i_ipa = _sibilant_by_rule(units, k, lang)
            elif lang in ("bn", "as") and u.letter in ("ś", "ṣ", "s") and \
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
                    (not _cluster_initial(units, k) or
                     (u.vaphala and _bare_conjunct(units, k))) and \
                    not _already_held(units, k):
                i_iso, i_ipa = _held(i_iso, i_ipa)
        elif u.kind == "N":
            if lang == "mr" and _word_final_nasal(units, k):
                # Marathi writes a word-final anusvara ṁ, as Telugu does
                # (#1476, owner 2026-11-21: "1. Standardize"); the IPA is
                # the nasal vowel, as before.
                i_iso, i_ipa = "ṁ", "̃"
            elif ch.tag == "silent" or typed == "":
                i_iso, i_ipa = _nasal_vowel(lang)
            elif lang in ("bn", "as"):
                # Bengali and Assamese say ং as ng whatever follows.
                i_iso, i_ipa = "ṅ", "ŋ"
            else:
                nxt = _next_letter(units, k)
                if lang == "te":
                    # Telugu (Plan-Ipa-Revamp-And-Language-Phonology,
                    # "Telugu medial anusvara"): before a stop or a nasal
                    # the anusvara is written as that letter's nasal, as the
                    # course's cards do: uṇḍi, saṅgītaṁ, mañci. Word-final
                    # and before s, v or l it is ṁ, ISO 15919's letter for
                    # it: annaṁ, māṁsaṁ, annaṁlō. Before any other letter
                    # (ś, ṣ, h, y, r, ḷ, ṟ) it is m: samyōgaṁ (a deliberate
                    # departure from ISO 15919, kept to match the cards). A
                    # hint that types an m or n does not change this.
                    # Before a vowel it is the consonant m, as in a letter
                    # name: ఎస్‌ఎంఎస్ esemes.
                    if k + 1 < len(units) and units[k + 1].kind == "V":
                        i_iso, i_ipa = "m", "m"
                    elif nxt in HOMORGANIC:
                        n = HOMORGANIC[nxt]
                        i_iso, i_ipa = n, HOMORGANIC_IPA[n]
                    elif nxt is None or nxt in TE_ANUSVARA_BEFORE:
                        i_iso, i_ipa = "ṁ", "m"
                    else:
                        i_iso, i_ipa = "m", "m"
                elif typed.startswith("m") and (nxt is None or
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


def _word_final_nasal(units: list[Unit], k: int) -> bool:
    """Whether the anusvara at [k] ends its word: a space, punctuation or
    the end of the text comes next (the same place Telugu's rule calls
    word-final, so a clitic written apart or a mark after it still counts)."""
    return k + 1 >= len(units) or units[k + 1].kind in ("SP", "P")


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


def _rba_cluster(units: list[Unit], k: int) -> bool:
    """Whether unit [k] is a ব written after a র with a virama (র্ব): the
    two consonants are said r and b, not as a ব-ফলা."""
    return k > 0 and units[k].kind == "C" and units[k].letter == "b" and \
        units[k - 1].kind == "C" and units[k - 1].letter == "r"


def _already_held(units: list[Unit], k: int) -> bool:
    """Whether the consonant before unit [k] is the same letter, written
    as a conjunct with it: the doubling is already said, so a ফলা on the
    second does not hold it a third time (উজ্জ্বল ujjôl)."""
    return k > 0 and units[k - 1].kind == "C" and \
        units[k - 1].letter == units[k].letter


def _bare_conjunct(units: list[Unit], k: int) -> bool:
    """Whether unit [k] with its ফলা is the whole word, as a conjunct is
    shown on a card of its own: জ্ব is said jjô. Inside a word a ফলা at the
    start says nothing (স্বামী śāmi)."""
    return (k == 0 or units[k - 1].kind in ("SP", "P")) and \
        k + 1 < len(units) and units[k + 1].kind == "I" and \
        (k + 2 >= len(units) or units[k + 2].kind in ("SP", "P"))


def _bare_conjunct_word(units: list[Unit], k: int) -> bool:
    """Whether the inherent vowel at [k] ends a word made only of two or
    more consonants joined by viramas: a conjunct on a card of its own."""
    j = k - 1
    while j >= 0 and units[j].kind == "C":
        j -= 1
    return k - 1 - j >= 2 and (j < 0 or units[j].kind in ("SP", "P"))


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
            elif nxt == "q":
                # `cq` (Bécquer, Jacquelin) is one /k/, said by the q:
                # the c adds no sound of its own.
                pass
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


# --- French ------------------------------------------------------------------

# Standard Parisian French, broad, in the notation of the French decks: no
# stress mark and no length mark, `ʁ` for r, the nasal vowels ɛ̃ ɑ̃ ɔ̃ œ̃, the
# semivowels j w ɥ, the schwa written inside a word (`pəti`), a silent final
# letter and a final mute e not written. Letter-to-sound rules for common
# spelling plus a short list of whole words that rules cannot reach.
#
# What is NOT guessed (a contributor or a source decides):
#   * liaison, except the obligatory kind listed in _FR_LIAISON_Z and
#     _FR_LIAISON_N below (determiners and pronouns before a vowel);
#   * the dropped e inside a word. The decks drop the medial schwa after a
#     vowel and a single consonant (`samdi`, `tɛlmɑ̃`, `mɛ̃tnɑ̃`, `aple`) and
#     keep it in the first syllable (`pətit`, `səmɛn`, `dəmɛ̃`). This tool
#     does NOT drop it (`samədi`): a known limit, left to a follow-up;
#   * the plural/verb ending -ent: a word ending in -ent (not -ment) with a
#     vowel before it is read as a verb ending and left silent (`parlent`
#     `paʁl`); nouns and adjectives in _FR_ENT_WORDS are read as -ent said
#     ɑ̃; `-ment` is always said ɑ̃ (`aiment` is a listed exception);
#   * the open and closed o in unusual words, and foreign words.

_FR_LETTERS = set("abcdefghijklmnopqrstuvwxyzàâäçéèêëîïôöùûüÿœæ")
_FR_VOWELS = set("aeiouyàâäéèêëîïôöùûüÿœæ")
_FR_OBSTRUENT = set("bcdfgkpv")

# Words that begin with an aspirated h (no elision, no liaison).
_FR_H_ASPIRE = {
    "haricot", "haricots", "hasard", "héros", "honte", "hibou", "haut",
    "haute", "hauts", "hautes", "hauteur", "hockey", "hollandais", "hongrois",
    "hanche", "hangar", "hamster", "hache", "handicap", "hérisson", "houx",
    "housse", "hurler", "huit", "huitième", "onze", "onzième", "oui",
    "harceler", "hâte", "hanter",
}

# An elided clitic, said joined to the next word (l'arrivée laʁive).
_FR_ELISION = {
    "l": "l", "d": "d", "j": "ʒ", "m": "m", "t": "t", "s": "s", "n": "n",
    "c": "s", "ç": "s", "qu": "k", "jusqu": "ʒysk", "lorsqu": "lɔʁsk",
    "puisqu": "pɥisk", "quoiqu": "kwak", "presqu": "pʁɛsk", "quelqu": "kɛlk",
}

# Whole words the rules do not reach: irregular, or short and frequent.
_FR_WORDS = {
    "femme": "fam", "monsieur": "məsjø", "fils": "fis", "et": "e",
    "est": "ɛ", "es": "ɛ", "tous": "tu", "plus": "ply", "ville": "vil",
    "mille": "mil", "tranquille": "tʁɑ̃kil", "village": "vilaʒ",
    "villa": "vila", "million": "miljɔ̃", "milliard": "miljaʁ",
    "les": "le", "des": "de", "mes": "me", "tes": "te", "ses": "se",
    "ces": "se", "ai": "e", "as": "a", "a": "a", "à": "a", "eu": "y",
    "où": "u", "oignon": "ɔɲɔ̃", "aujourd'hui": "oʒuʁdɥi", "huit": "ɥit",
    "sept": "sɛt", "dix": "dis", "six": "sis", "cent": "sɑ̃",
    "souvent": "suvɑ̃", "ennemi": "ɛnmi", "ennui": "ɑ̃nɥi", "donc": "dɔ̃k",
    "porc": "pɔʁ", "tabac": "taba", "estomac": "ɛstɔma", "corps": "kɔʁ",
    "doigt": "dwa", "sud": "syd", "ouest": "wɛst", "pays": "pei",
    "gentil": "ʒɑ̃ti", "outil": "uti", "faisons": "fəzɔ̃",
    "faisais": "fəzɛ", "faisait": "fəzɛ", "faisant": "fəzɑ̃", "vrai": "vʁɛ",
    "aiment": "ɛm", "soixante": "swasɑ̃t", "wagon": "vaɡɔ̃", "clef": "kle",
    "est-ce": "ɛs", "peut-être": "pøtɛtʁ", "dix-huit": "dizɥit",
    "dix-sept": "disɛt", "dix-neuf": "diznœf", "c'est-à-dire": "sɛtadiʁ",
    "deuxième": "døzjɛm", "sixième": "sizjɛm", "dixième": "dizjɛm",
    "tout": "tu", "toute": "tut", "cet": "sɛt", "dessert": "desɛʁ",
    "dessous": "dəsu", "dessus": "dəsy", "dessin": "desɛ̃",
    "dossier": "dosje", "football": "futbol", "longtemps": "lɔ̃tɑ̃",
    "restaurant": "ʁɛstɔʁɑ̃", "août": "u", "déjeuner": "deʒøne",
    "examen": "ɛɡzamɛ̃", "eue": "y", "eues": "y", "eus": "y", "eut": "y",
}
# Singulars whose plural (+ s) is said the same way.
# Verbs in -ment (3rd person plural) whose ending is silent.
_FR_MENT_VERBS = {"dorment", "ferment", "forment", "nomment", "estiment",
                  "animent", "arment"}
_FR_PLURAL_OK = {"femme", "ville", "villa", "village", "oignon", "doigt",
                 "gentil", "outil", "dossier"}

# Nouns and adjectives in -ent said ɑ̃ (a verb's -ent is silent).
_FR_ENT_WORDS = {
    "argent", "parent", "content", "présent", "différent", "évident",
    "patient", "client", "accident", "président", "ingrédient", "orient",
    "agent", "talent", "excellent", "intelligent", "récent", "absent",
    "urgent", "innocent", "violent", "prudent", "fréquent", "apparent",
    "accent", "incident", "résident", "serpent", "vent", "dent", "lent",
    "sent", "souvent", "moment",
}
# 3rd person singular verbs in -ient: the e is said, ɛ̃.
_FR_IENT_VERBS = {
    "vient": "vjɛ̃", "tient": "tjɛ̃", "devient": "dəvjɛ̃",
    "revient": "ʁəvjɛ̃", "convient": "kɔ̃vjɛ̃", "retient": "ʁətjɛ̃",
    "obtient": "ɔptjɛ̃", "contient": "kɔ̃tjɛ̃", "appartient": "apaʁtjɛ̃",
}
# Polysyllables in -er said ɛʁ, not e.
_FR_ER_WORDS = {"hiver": "ivɛʁ", "enfer": "ɑ̃fɛʁ", "amer": "amɛʁ",
                "hier": "jɛʁ", "fier": "fjɛʁ", "super": "sypɛʁ",
                "cancer": "kɑ̃sɛʁ", "laser": "lazɛʁ"}
# Final -s, -t, -x, -z, -p said, unlike the usual silent ending.
_FR_PRONOUNCED_END = {
    "bus": "bys", "virus": "viʁys", "cactus": "kaktys", "campus": "kɑ̃pys",
    "autobus": "otobys", "ours": "uʁs", "sens": "sɑ̃s", "os": "ɔs",
    "tennis": "tenis", "maïs": "mais", "jadis": "ʒadis", "hélas": "elas",
    "mars": "maʁs", "lys": "lis", "net": "nɛt", "but": "byt",
    "contact": "kɔ̃takt", "direct": "diʁɛkt", "correct": "kɔʁɛkt",
    "exact": "ɛɡzakt", "test": "tɛst", "gaz": "ɡɑz", "index": "ɛ̃dɛks",
    "lynx": "lɛ̃ks", "stop": "stɔp", "cap": "kap", "top": "tɔp",
    "club": "klœb", "album": "albɔm",
}
_FR_SILENT_P = {"trop", "sirop", "galop", "drap", "coup", "beaucoup", "loup"}

# Obligatory liaison, in the way the decks write it: a z before a vowel is
# joined to the next word (`le zɑ̃fɑ̃`, `vu zɛme`), an n or t is joined to the
# first word (`mɔ̃n ami`, `diz œʁ`).
_FR_LIAISON_Z = {"les", "des", "ces", "mes", "tes", "ses", "nos", "vos",
                 "leurs", "nous", "vous", "ils", "elles", "aux", "chez",
                 "très", "quels", "quelles"}
_FR_LIAISON_N = {"un": "n", "mon": "n", "ton": "n", "son": "n", "en": "n",
                 "on": "n", "aucun": "n"}
_FR_LIAISON_END = {"deux": "z", "trois": "z", "six": "z", "dix": "z",
                   "grand": "t", "petit": "t", "c'est": "t", "vingt": "t",
                   "cent": "t"}


def french_ipa(text: str) -> str:
    """Standard French of France, broad (see the notes above). The liaison
    of the obligatory kind is written; every other liaison is left out."""
    text = unicodedata.normalize("NFC", text.lower()).replace("’", "'")
    toks: list[list] = []     # [ipa, written word, a pause follows]
    for raw in text.split():
        pause = bool(re.search(r"[.,;:!?…»)\"]$", raw))
        word = re.sub(r"^[^\w']+|[^\w']+$", "", raw).strip("'")
        if not word:
            if toks and pause:
                toks[-1][2] = True
            continue
        toks.append([_fr_token(word), word, pause])
    out: list[str] = []
    for k, (ipa, word, pause) in enumerate(toks):
        nxt = toks[k + 1] if k + 1 < len(toks) and not pause else None
        vowel_next = (nxt is not None and nxt[1] not in ("et", "ou")
                      and _fr_vowel_initial(nxt[1]))
        if word in ("six", "dix"):
            # Said alone sis, dis; before a vowel siz, diz; before a
            # consonant si, di.
            if nxt is not None:
                ipa = ipa[:-1] + ("z" if vowel_next else "")
        elif vowel_next and word in _FR_LIAISON_END:
            ipa += _FR_LIAISON_END[word]
        elif vowel_next and word in _FR_LIAISON_N:
            ipa += _FR_LIAISON_N[word]
        elif vowel_next and word in _FR_LIAISON_Z:
            nxt[0] = "z" + nxt[0]
        out.append(ipa)
    return " ".join(p for p in out if p)


def _fr_vowel_initial(word: str) -> bool:
    """Whether a following liaison consonant is said: the word starts with a
    vowel or a mute h."""
    if not word or word in _FR_H_ASPIRE:
        return False
    return word[0] in _FR_VOWELS or word[0] == "h"


def _fr_token(word: str) -> str:
    """One written word, hyphens and elisions included."""
    if word in _FR_WORDS:
        return _FR_WORDS[word]
    pieces = word.split("-")
    out: list[str] = []
    for n, piece in enumerate(pieces):
        ipa = _fr_piece(piece)
        if piece == "t" and 0 < n < len(pieces) - 1:
            ipa = "t"                       # a-t-il
        nxt = pieces[n + 1] if n + 1 < len(pieces) else ""
        if piece == "vingt" and n == 0 and nxt:
            ipa = "vɛ̃t"                    # vingt-deux, vingt-et-un
        elif piece == "quatre" and nxt in ("vingt", "vingts"):
            ipa = "katʁə"                   # quatre-vingts
        elif piece == "dix" and nxt == "neuf":
            ipa = "diz"
        if nxt and _fr_vowel_initial(nxt) and n + 1 == len(pieces) - 1 \
                and piece not in ("t", "et"):
            # inverted subject: the said consonant of est-il, dit-il, vas-y
            if piece.endswith(("t", "d")) and not ipa.endswith("t"):
                ipa += "t"
            elif piece.endswith("s") and nxt in ("y", "en"):
                ipa += "z"
            elif piece.endswith("ez") and nxt in ("y", "en"):
                ipa += "z"
        out.append(ipa)
    return "".join(out)


def _fr_piece(piece: str) -> str:
    """A hyphen-free piece: elided clitics joined to the word after them."""
    if piece in _FR_WORDS:
        return _FR_WORDS[piece]
    if piece in ("t", ""):
        return "t" if piece else ""
    parts = piece.split("'")
    out = ""
    for k, part in enumerate(parts):
        if k < len(parts) - 1 and part in _FR_ELISION:
            out += _FR_ELISION[part]
        else:
            out += _fr_word(part)
    return out


def _fr_has_vowel(stem: str) -> bool:
    return any(c in _FR_VOWELS for c in stem.replace("qu", "q"))


def _fr_word(w: str) -> str:
    if w in _FR_WORDS:
        return _FR_WORDS[w]
    if w in _FR_PRONOUNCED_END:
        return _FR_PRONOUNCED_END[w]
    if w in _FR_IENT_VERBS:
        return _FR_IENT_VERBS[w]
    if w in _FR_ER_WORDS:
        return _FR_ER_WORDS[w]
    if w.endswith("s") and w[:-1] in _FR_PLURAL_OK:
        return _FR_WORDS[w[:-1]]
    if any(c not in _FR_LETTERS for c in w):
        raise CannotRead(f"cannot read {w!r} as French")
    core, mute = _fr_split_end(w)
    return _fr_scan(w, core, mute)


def _fr_split_end(w: str) -> tuple[str, bool]:
    """The letters that are said, and whether a mute e (or es, ent) was cut
    off the end. A silent consonant is cut by the same call."""
    # -er, -ez said é: the é is written back into the core.
    if len(w) > 2 and w.endswith(("er", "ez", "ed")) and w[-3] not in "eé" \
            and (w.endswith("ez") or _fr_has_vowel(w[:-2])):
        return w[:-2] + "é", False
    if len(w) > 3 and w.endswith("ers") and w[-4] not in "eé" \
            and _fr_has_vowel(w[:-3]) and w[:-1] not in _FR_ER_WORDS \
            and w not in _FR_ER_WORDS:
        return w[:-3] + "é", False
    # -ent of a verb is silent; a noun's or adjective's is said.
    if w in _FR_MENT_VERBS:
        return w[:-3], True
    if w.endswith("ent") and not w.endswith("ment") \
            and w not in _FR_ENT_WORDS and _fr_has_vowel(w[:-3]):
        return w[:-3], True
    if w.endswith("es") and _fr_has_vowel(w[:-2]):
        return w[:-2], True
    if w.endswith("e") and _fr_has_vowel(w[:-1]) and w != "e":
        return w[:-1], True
    core = w
    while len(core) > 1:
        last, before = core[-1], core[-2]
        if last == "s":
            core = core[:-1]
        elif last == "x":
            core = core[:-1]
        elif last == "t" and before not in "cps":
            core = core[:-1]
        elif last == "d":
            core = core[:-1]
        elif last == "p" and (before == "m" or core in _FR_SILENT_P
                              or core.endswith("oup")):
            core = core[:-1]
        elif last == "g" and before in "nr":
            core = core[:-1]
        elif last == "c" and before == "n":
            core = core[:-1]
        elif last == "z" and before in "ei":
            core = core[:-1]
        else:
            break
    return core, False


def _fr_scan(full: str, core: str, mute: bool) -> str:
    """Letters to sounds. [full] is the whole word, [core] its said part (a
    prefix of [full], except that a final er/ez is written back as é)."""
    if core != full[:len(core)]:
        full = core          # a final er/ez/ed was rewritten as é
    L = len(core)
    V = _FR_VOWELS

    def at(j: int) -> str:
        return full[j] if 0 <= j < len(full) else "\0"

    def pron_vowel(j: int) -> bool:
        return j < L and at(j) in V

    def units(j: int) -> tuple[list[str], int]:
        """The consonant units (a digraph or a doubled letter is one) from
        [j] up to a vowel or the end of the core."""
        found: list[str] = []
        while j < L and at(j) not in V:
            two = full[j:j + 2]
            if at(j) == "h":
                j += 1
            elif two in ("ch", "ph", "th", "gn", "sh", "qu", "ck") \
                    or (len(two) == 2 and two[0] == two[1]):
                found.append(two)
                j += 2
            else:
                found.append(at(j))
                j += 1
        return found, j

    def nasal(j: int) -> bool:
        """The n or m at [j] makes the vowel before it nasal."""
        if at(j) not in ("n", "m") or j >= L:
            return False
        k = j + 1
        if k >= L:
            return not mute
        return at(k) not in V and at(k) != at(j) and at(k) != "h"

    def eu(j: int) -> str:
        """eu or œu ending just before [j]: ø in an open syllable, else œ."""
        if j >= L:
            return "ø"
        found, k = units(j)
        if not found:
            return "œ"
        u = found[0]
        if u == "z":
            return "ø"
        if u == "s":
            return "ø" if at(j + 1) in V else "œ"
        if u == "r":
            return "ø" if k < L and len(found) == 1 else "œ"
        if u == "t":
            if len(found) == 2 and found[1] == "r":
                return "ø"
            return "ø" if len(found) == 1 and (k < L or mute) else "œ"
        if u == "d":
            return "ø" if len(found) == 1 and k < L else "œ"
        return "œ"

    def plain_e(i: int) -> str:
        """An e that is not nasal and part of no digraph."""
        if not any(c in V for c in
                   core[:i].replace("qu", "q") + core[i + 1:]):
            tail = full[L:]
            if i + 1 >= L:
                if tail == "":
                    return "ə"
                return "e" if tail == "s" else "ɛ"
        if i + 1 >= L:
            return "ɛ"
        if full[i + 1:i + 3] == "sc" and at(i + 3) in "eiéè":
            return "e"                  # descendre
        found, k = units(i + 1)
        n = len(found) + (1 if "x" in found else 0)
        if not found:
            return "ə"
        if len(found[0]) == 2 and found[0][0] == found[0][1]:
            return "ɛ"
        if n == 1:
            if k >= L:
                return "ɛ"
            return "ə"
        if n == 2 and found[0][0] in _FR_OBSTRUENT and found[1] in ("r", "l") \
                and len(found[0]) == 1:
            return "ə"
        return "ɛ"

    out: list[str] = []
    i = 0
    while i < L:
        c = at(i)
        nx, n2 = at(i + 1), at(i + 2)
        prev = at(i - 1)
        rest = full[i:L]

        # Vowel + il / ill: a j.
        m = None
        for pat, ipa, tail_only in (
                ("euill", "œj", False), ("ouill", "uj", False),
                ("aill", "aj", False), ("eill", "ɛj", False),
                ("uill", "ɥij", False), ("ueill", "œj", False), ("euil", "œj", True),
                ("ouil", "uj", True), ("œil", "œj", True),
                ("ueil", "œj", True), ("ail", "aj", True),
                ("eil", "ɛj", True)):
            if rest.startswith(pat) and (not tail_only or len(rest) == len(pat)):
                m = (ipa, len(pat))
                break
        if m:
            out.append(m[0])
            i += m[1]
            continue
        if rest.startswith("ill") and c == "i":
            if i == 0:
                out.append("il")
            elif prev in V:
                out.append("j")
            else:
                out.append("ij")
            i += 3
            continue

        # Vowels.
        if c in V:
            if full[i:i + 3] == "eau":
                out.append("o")
                i += 3
            elif full[i:i + 2] in ("ay", "oy", "uy", "ey") and pron_vowel(i + 2):
                out.append({"a": "ɛj", "o": "waj", "u": "ɥij", "e": "ɛj"}[c])
                i += 2
            elif c == "a" and nx == "u":
                out.append("ɔ" if n2 == "r" else "o")     # aurai, aurore
                i += 2
            elif c == "o" and nx == "û":
                out.append("u")           # coûter, goûter
                i += 2
            elif c == "o" and nx == "u":
                out.append("w" if pron_vowel(i + 2) else "u")
                i += 2
            elif c == "o" and nx in ("i", "î"):
                if nasal(i + 2):
                    out.append("wɛ̃")
                    i += 3
                else:
                    out.append("wa")
                    i += 2
            elif c == "œ" and nx == "u":
                out.append(eu(i + 2))
                i += 2
            elif c == "e" and nx == "u":
                out.append(eu(i + 2))
                i += 2
            elif c == "œ":
                out.append("œ")
                i += 1
            elif c in ("a", "e") and nx in ("i", "î"):
                if nasal(i + 2):
                    out.append("ɛ̃")
                    i += 3
                elif c == "a" and i + 2 == L and prev == "r" \
                        and full[L:] == "":
                    out.append("e")      # parlerai
                    i += 2
                else:
                    out.append("ɛ")
                    i += 2
            elif c in ("a", "â") and nasal(i + 1):
                out.append("ɑ̃")
                i += 2
            elif c == "e" and nasal(i + 1):
                k = i + 2
                if prev in ("i", "y", "é"):
                    if at(k) == "c" or (at(k) == "t" and full[k + 1:] in
                                        ("", "e", "es", "s")):
                        out.append("ɑ̃")
                    else:
                        out.append("ɛ̃")
                else:
                    out.append("ɑ̃")
                i += 2
            elif c in ("i", "î", "y") and nasal(i + 1) and not pron_vowel(i + 1):
                out.append("ɛ̃")
                i += 2
            elif c == "o" and nasal(i + 1):
                out.append("ɔ̃")
                i += 2
            elif c == "u" and nasal(i + 1):
                out.append("œ̃")
                i += 2
            elif c == "u":
                out.append(_fr_u(full, i, pron_vowel))
                i += 1
            elif c in ("i", "ï", "î"):
                if c != "ï" and pron_vowel(i + 1):
                    ij = i >= 2 and at(i - 2) in _FR_OBSTRUENT \
                        and prev in ("r", "l")
                    out.append("ij" if ij else "j")
                else:
                    out.append("i")
                i += 1
            elif c == "y":
                out.append("j" if i == 0 and pron_vowel(1) else "i")
                i += 1
            elif c == "e":
                out.append(plain_e(i))
                i += 1
            elif c == "o":
                if nx == "s" and at(i + 2) in V:
                    out.append("o")
                elif i + 1 >= L:
                    out.append("o")
                else:
                    out.append("ɔ")
                i += 1
            else:
                out.append({"a": "a", "à": "a", "ä": "a", "â": "ɑ", "é": "e",
                            "è": "ɛ", "ê": "ɛ", "ë": "ɛ", "ô": "o", "ö": "o",
                            "ù": "y", "û": "y", "ü": "y", "ÿ": "i",
                            "æ": "e", "ï": "i"}.get(c, c))
                i += 1
            continue

        # Consonants.
        if c == "c":
            if nx == "c":
                out.append("ks" if n2 in "eiyéèêëîï" else "k")
                i += 2
            elif nx == "h":
                out.append("k" if n2 in ("r", "l") else "ʃ")
                i += 2
            elif nx == "q":
                i += 1
            elif nx == "k":
                out.append("k")
                i += 2
            elif nx in "eiyéèêëîï":
                out.append("s")
                i += 1
            else:
                out.append("k")
                i += 1
        elif c == "ç":
            out.append("s")
            i += 1
        elif c == "g":
            if nx == "n":
                out.append("ɲ")
                i += 2
            elif nx == "u" and n2 in "eiyéèêëï":
                out.append("ɡ")
                i += 2
            elif nx == "e" and n2 in "aouâôù":
                out.append("ʒ")
                i += 2
            elif nx in "eiyéèêëî":
                out.append("ʒ")
                i += 1
            elif nx == "g":
                out.append("ɡ")
                i += 2
            else:
                out.append("ɡ")
                i += 1
        elif c == "h":
            i += 1
        elif c == "p":
            if nx == "h":
                out.append("f")
                i += 2
            elif nx == "p":
                out.append("p")
                i += 2
            elif prev == "m" and nx == "t":
                i += 1
            else:
                out.append("p")
                i += 1
        elif c == "q":
            out.append("k")
            i += 2 if nx == "u" else 1
        elif c == "s":
            if nx == "s":
                out.append("s")
                i += 2
            elif nx == "c" and n2 in "eiyéèêë":
                out.append("s")
                i += 2
            elif nx == "c" and n2 == "h":
                out.append("ʃ")
                i += 3
            elif nx == "h":
                out.append("ʃ")
                i += 2
            elif prev in V and nx in V:
                out.append("z")
                i += 1
            else:
                out.append("s")
                i += 1
        elif c == "t":
            if nx == "i" and n2 == "o" and at(i + 3) == "n" and prev not in "sx":
                out.append("s")
            elif nx == "t":
                out.append("t")
                i += 1
            else:
                out.append("t")
            i += 1
        elif c == "x":
            if i == 1 and full[0] == "e" and (nx in V or nx == "h"):
                out.append("ɡz")
            elif nx == "c" and n2 in "eiyéèêë":
                out.append("ks")
                i += 1
            else:
                out.append("ks")
            i += 1
        elif c == "w":
            out.append("w")
            i += 1
        elif c in ("r", "l", "m", "n", "b", "d", "f", "j", "k", "v", "z"):
            out.append({"r": "ʁ", "j": "ʒ"}.get(c, c))
            i += 2 if nx == c else 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def _fr_u(full: str, i: int, pron_vowel) -> str:
    """A plain u: y, or the semivowel ɥ before a said vowel."""
    nx = full[i + 1] if i + 1 < len(full) else ""
    if nx in ("i", "î"):
        return "ɥ"
    if pron_vowel(i + 1):
        cluster = i >= 2 and full[i - 2] in _FR_OBSTRUENT \
            and full[i - 1] in ("r", "l")
        return "y" if cluster else "ɥ"
    return "y"



# --- Swahili -----------------------------------------------------------------

# Standard Swahili (Kiswahili sanifu) is written as it is said, so its broad
# IPA is read from the spelling. Five vowels, none long (a doubled vowel is
# two vowels, `hii`), stress on the second to last syllable of a word of two
# or more, marked with ˈ as for Spanish. A syllable is a vowel or a syllabic
# nasal at the start of a word (`m` in `mtu`, `n` in `nchi`), which counts for stress but is written
# as a plain m or n, as the repo's other engines do not mark syllabic nasals.
_SW_DIGRAPHS = {"ch": "tʃ", "sh": "ʃ", "ny": "ɲ", "dh": "ð", "th": "θ",
                "gh": "ɣ", "kh": "x"}
_SW_SINGLE = {"j": "dʒ", "r": "ɾ", "y": "j", "g": "ɡ"}
_SW_PLAIN = set("bdfhklmnpstvwz")
_SW_PUNCT = set(".,?!;:\"“”()…")
# Letters after which a written m or n is part of a prenasalised consonant
# or a glide rather than a syllable of its own.
_SW_PRENASAL = {"m": "bvw", "n": "dgjzy"}


def swahili_ipa(text: str) -> str:
    """Standard Swahili, broad, with the stress marked on words of two
    syllables or more. Raises CannotRead for a letter, digit or sign that
    Swahili spelling does not use."""
    for c in text:
        if c.isspace() or c in _SW_PUNCT or c in "'’-":
            continue
        if not ("a" <= c.lower() <= "z") or c.lower() in "qx":
            raise CannotRead(f"not a Swahili letter: {c!r}")
    words = []
    for raw in re.split(r"[\s-]+", text.lower()):
        raw = "".join(c for c in raw if c not in _SW_PUNCT)
        if raw.strip("'’"):
            words.append(_sw_word(raw))
    return " ".join(w for w in words if w)


def _sw_word(w: str) -> str:
    ph: list[str] = []          # phonemes
    nuc: list[int] = []         # indexes of syllable nuclei
    i = 0
    while i < len(w):
        c = w[i]
        two = w[i:i + 2]
        nxt = w[i + 1] if i + 1 < len(w) else ""
        if c in "aeiou":
            nuc.append(len(ph))
            ph.append(c)
        elif c in "'’":
            pass                # only ever the tail of ng', read below
        elif c == "n" and nxt == "g":
            if w[i + 2:i + 3] in ("'", "’"):
                ph.append("ŋ")
                i += 2
            else:
                ph.append("ŋɡ")
                i += 1
        elif two in _SW_DIGRAPHS:
            ph.append(_SW_DIGRAPHS[two])
            i += 1
        elif c == "n" and nxt == "j":
            ph.append("ndʒ")
            i += 1
        elif c == "c":
            raise CannotRead("c is only written in ch")
        elif c in _SW_SINGLE or c in _SW_PLAIN:
            if c in "mn" and i == 0 and nxt and nxt not in "aeiou'’" and \
                    nxt not in _SW_PRENASAL[c] and \
                    not (c == "n" and w[i + 1:i + 3] in ("g'", "g’")):
                nuc.append(len(ph))     # syllabic nasal: mtu, nchi
            ph.append(_SW_SINGLE.get(c, c))
        else:
            raise CannotRead(f"not a Swahili letter: {c!r}")
        i += 1
    if len(nuc) < 2:
        return "".join(ph)
    start = nuc[-3] + 1 if len(nuc) > 2 else 0
    return "".join(ph[:start]) + "ˈ" + "".join(ph[start:])


# --- Italian -----------------------------------------------------------------

# Standard Italian, broad, as the decks write it: ˈ before the stressed
# syllable of a word of two syllables or more (as for Spanish), ɛ ɔ for the
# open mid vowels, doubled letters doubled in IPA (ˈnɔtte, ˈɡrattsje), the
# sounds that are long between vowels written long (ʎʎ ɲɲ ʃʃ, and tts for
# -zione), s between vowels z, and i and u before a vowel, or after a, e or o,
# the glides j and w. An s before a consonant closes the syllable before it
# (stuˈdɛn.te, mos.ˈtra.to), as Wiktionary divides.
#
# What the letters show: the consonants and their doubling, the glides, the
# stress of a word with a written accent (always the last vowel) and the
# default stress on the second to last syllable. What they do not show, and
# Italian spelling leaves to the reader's lexicon: which words are stressed
# on the third to last syllable (`tavolo`), whether a stressed e or o is open
# or closed (`bene` ɛ, `sera` e), whether a z is ts or dz, whether an i or u
# before a vowel is a glide (`storia`) or a syllable (`farmacìa`), and the
# voicing of an s between vowels that begins a word's second part
# (`buonasera` is s; _IT_S_VOICELESS lists the few the engine knows, any
# other such compound is read with z). The engine settles the
# stress, the openness and the z in four ways, and no more:
#  1. a written accent is believed, and a *hint* (the text with its words
#     marked as a dictionary marks them: `tàvolo`, `bène`, `farmacìa`) gives
#     the stress and the openness of words that have none: è ò for open, é ó
#     for closed, à ì ù for the stressed vowel of any other. A hint is used
#     only if, with its accents removed, it is the text;
#  2. a few endings that fix the stress or the openness of nearly every word
#     with them: _IT_ANTEPENULT (-bile, -ico, -issimo, ...), -ai/-ei/-oi
#     stressed last, _IT_OPEN_E and _IT_OPEN_O, e after j and o after w, the
#     ri- and -logia kinds of hiatus, and _IT_DZ for z;
#  3. _IT_MARKS, a short table of very frequent words that follow no rule,
#     which is read as a hint is (and _IT_PENULT, the frequent exceptions to
#     the -ico, -ile endings);
#  4. otherwise penultimate stress, a closed e or o and ts.
# Measured against the 85,616 single words of Wiktionary's Italian entries
# that have one untagged broad form (read 2026-11-27, kaikki.org; mostly
# rare, derived and learned words): 69.8 percent are read exactly as
# Wiktionary writes them, 8.6 percent differ only in where the stress is,
# 14.5 only in a vowel's openness, 0.8 only in the voicing of an s or z, and
# 6.5 in something else (mostly i or u as a syllable or a glide, and loan
# words). On 153 words of everyday vocabulary, 138 are exact. A card whose
# broad `ipa` the engine misreads is given a hint.
#
# Sources: Wikipedia "Italian phonology"; Wiktionary "Appendix:Italian
# pronunciation" and its entries' pronunciations (the measurement above).
_IT_ACCENTS = {"à": ("a", ""), "è": ("e", "ɛ"), "é": ("e", "e"),
               "ì": ("i", ""), "í": ("i", ""), "ò": ("o", "ɔ"),
               "ó": ("o", "o"), "ù": ("u", ""), "ú": ("u", "")}
_IT_PUNCT = set(".,?!;:\"“”«»()…-–—")
_IT_STOPS = "pbtdkɡfv"
# Very frequent words that no rule reads, as the dictionary marks them
# (read exactly as a hint is): open vowels, a stress the suffixes miss.
_IT_MARKS = {
    "ho": "hò", "no": "nò", "bene": "bène", "sempre": "sèmpre",
    "tempo": "tèmpo", "ecco": "ècco", "vecchio": "vècchio",
    "vecchia": "vècchia", "vecchi": "vècchi", "vecchie": "vècchie",
    "poco": "pòco", "cosa": "còsa", "cose": "còse", "porta": "pòrta",
    "forte": "fòrte", "volta": "vòlta", "gente": "gènte", "cento": "cènto",
    "venti": "vènti", "trenta": "trènta", "sette": "sètte", "terra": "tèrra",
    "devo": "dèvo", "deve": "dève", "devi": "dèvi", "oggi": "òggi",
    "adesso": "adèsso", "presto": "prèsto", "albergo": "albèrgo",
    "essere": "èssere", "poi": "pòi", "sei": "sèi", "lei": "lèi",
    "tavolo": "tàvolo", "numero": "nùmero", "camera": "càmera",
    "sabato": "sàbato", "perdere": "pèrdere", "prendere": "prèndere",
    "mezzo": "mèzzo", "mezza": "mèzza", "io": "ìo", "idea": "idèa",
    "costa": "còsta", "costo": "còsto", "studente": "studènte",
    "notte": "nòtte", "otto": "òtto", "nove": "nòve", "treno": "trèno",
    "aereo": "aèreo", "sedia": "sèdia", "finestra": "finèstra",
    "troppo": "tròppo", "donna": "dònna", "occhio": "òcchio",
    "testa": "tèsta", "prego": "prègo", "spagnolo": "spagnòlo",
    "parola": "paròla", "parole": "paròle", "leggere": "lèggere",
    "scrivere": "scrìvere", "piccolo": "pìccolo", "piccola": "pìccola",
    "macchina": "màcchina", "farmacia": "farmacìa",
    "telefono": "telèfono", "zucchero": "zùcchero",
    "scena": "scèna", "scene": "scène", "rosa": "ròsa", "rose": "ròse",
    "zero": "zèro", "gnocchi": "gnòcchi", "gnocco": "gnòcco", "so": "sò",
    "dopo": "dòpo", "nonno": "nònno", "nonna": "nònna",
    "destra": "dèstra", "prezzo": "prèzzo", "pezzo": "pèzzo",
    "america": "amèrica",
}
# Words whose s after the first part of the compound is voiceless, by the
# index of the s (buona-sera, risalire, girasole): every other s between
# vowels is z.
_IT_S_VOICELESS = {"buonasera": (5,), "risalire": (2,), "girasole": (4,)}
# One-syllable words with ui, which the rules would read as a glide.
_IT_FIXED = {"cui": "kui", "sui": "sui"}
# z is dz in these (zero, mezzo, pranzo, azzurro, -izzare); every other z
# is ts. Measured on Wiktionary's entries; the rest of the dz words need
# a hint-free respelling the engine does not have.
_IT_DZ = re.compile(r"^zer|^zeb|^zon|^zain|^zanz|^zucch|mezz|pranz|azzurr|romanz|"
                    r"izz(?=ar|az|at|abil|ant|and|er)")
# A word beginning ri- and a vowel keeps both vowels (riabbellire, riesplorare:
# 561 of 563 such words of six letters or more in Wiktionary); one that ends
# in one of these has a stressed i before its last vowel (-logia, -eria:
# farmacologia, macelleria). The rare exceptions (riempire, materia) need a
# hint.
_IT_HIATUS_END = re.compile(r"(?:logi|grafi|foni|nomi|eri|si|mi)[ae]$")


# The articles and prepositions that elide before a vowel, to their IPA when
# the letters alone cannot give it (l has no vowel); else "".
_IT_ELIDED = {"l": "l", "un": "", "dell": "", "all": "",
              "nell": "", "sull": "", "dall": "", "coll": "", "quell": "",
              "quest": "", "anch": "", "bell": "", "sant": "", "tutt": "",
              "senz": "", "nient": ""}


def italian_ipa(text: str, hint: str | None = None) -> str:
    """Standard Italian, broad. [hint] is the text with each word marked as a
    dictionary marks it (see the section header); it is used only if, with its
    accents removed, it is the text. Raises CannotRead for a letter Italian
    spelling does not use."""
    text = unicodedata.normalize("NFC", text.lower())
    for c in text:
        if c.isspace() or c in _IT_PUNCT or c in "'’":
            continue
        if not ("a" <= c <= "z") and c not in _IT_ACCENTS:
            raise CannotRead(f"not an Italian letter: {c!r}")
    words = [w for w in re.split(r"[\s\-–—]+", text) if w]
    hints = _it_hint_words(words, hint)
    out = []
    for k, raw in enumerate(words):
        out.append(_it_word(raw, hints[k] if hints else ""))
    return " ".join(w for w in out if w)


def _it_hint_words(words: list[str], hint: str | None) -> list[str]:
    """The hint's words if they are the text's words with stress marks, else
    none."""
    if not hint:
        return []
    hints = [w for w in re.split(r"[\s\-–—]+",
                                 unicodedata.normalize("NFC", hint.lower()))
             if w]
    if len(hints) != len(words) or any(
            _it_plain(h) != _it_plain(w) for h, w in zip(hints, words)):
        return []
    return hints


def _italian(text: str, hint: str | None) -> Transcription:
    ipa = italian_ipa(text, hint)
    words = [w for w in re.split(r"[\s\-–—]+",
                                 unicodedata.normalize("NFC", text.lower()))
             if w]
    fitted = not hint or bool(_it_hint_words(words, hint))
    return Transcription(text, ipa, fitted)


def _it_plain(word: str) -> str:
    """A word without its stress marks and punctuation, to compare a hint."""
    word = "".join(c for c in word if c not in _IT_PUNCT)
    return "".join(_IT_ACCENTS[c][0] if c in _IT_ACCENTS else c
                   for c in word)


def _it_word(raw: str, hint: str) -> str:
    # Elision: an article or preposition before an apostrophe (l'amico,
    # un'idea, dell'acqua) is read apart, unstressed, and the host word has
    # its own stress and openness; dov'è, cos'è, c'è are one word.
    head, apos, host = raw.partition("'") if "'" in raw else \
        raw.partition("’")
    if apos and host and head in _IT_ELIDED:
        h_head, _, h_host = hint.replace("’", "'").partition("'")
        tail = _it_word(host, h_host if h_head else "")
        front = _IT_ELIDED[head] if _IT_ELIDED[head] else \
            _it_word(head, "").replace("ˈ", "")
        if tail.startswith("ˈ") and front:
            return front[:-1] + "ˈ" + front[-1] + tail[1:]
        return front + tail
    word = "".join(c for c in raw if c not in _IT_PUNCT and c not in "'’")
    marked = "".join(c for c in hint if c not in _IT_PUNCT and c not in "'’")
    if not word:
        return ""
    plain = _it_plain(word)
    if plain in _IT_FIXED and not marked:
        return _IT_FIXED[plain]
    if not marked and plain in _IT_MARKS and \
            not any(c in _IT_ACCENTS for c in word):
        marked = _IT_MARKS[plain]
    # The letters, with each vowel's accent: the word's own, else the hint's.
    src = marked if marked and any(c in _IT_ACCENTS for c in marked) else word
    s = _it_plain(src)
    acc: dict[int, str] = {}        # index -> quality ('' for a, i, u)
    for i, c in enumerate(src):
        if c in _IT_ACCENTS:
            acc[i] = _IT_ACCENTS[c][1]
    # A word that is only a consonant, a glide and a vowel (`mio`, `zio`,
    # `dio`, `tua`) has its i or u as a syllable.
    if not acc and re.fullmatch(r"[^aeiouqgh][iu][aeiou]", s):
        acc[1] = ""
    syll: set[int] = set()          # an i or u that is a syllable, unstressed
    if not acc and len(s) > 5:
        if re.match(r"ri[aeiou]", s):
            syll.add(1)
        elif _IT_HIATUS_END.search(s):
            acc[len(s) - 2] = ""
    toks = _it_tokens(s, acc, syll)
    return _it_stress(toks, s, acc)


def _it_vowel(s: str, i: int) -> bool:
    return 0 <= i < len(s) and s[i] in "aeiou"


def _it_tokens(s: str, acc: dict[int, str],
               syll: set[int] = frozenset()) -> list[list]:
    """The word's sounds as [phoneme, kind, letter index]. Kind V is a
    syllable's vowel, v the second vowel of a diphthong (ai, au), G a glide
    and C a consonant."""
    n = len(s)
    toks: list[list] = []
    dz_at = {j for m in _IT_DZ.finditer(s) for j in range(m.start(), m.end())
             if s[j] == "z"}

    def add(ph: str, kind: str, idx: int) -> None:
        toks.append([ph, kind, idx])

    def after_vowel() -> bool:
        return bool(toks) and toks[-1][1] in ("V", "v", "G")

    def silent_i(j: int) -> bool:
        # The i of ci, gi, sci, gli before a vowel only marks the sound.
        return j < n and s[j] == "i" and _it_vowel(s, j + 1) and j not in acc

    i = 0
    while i < n:
        c = s[i]
        nx = s[i + 1] if i + 1 < n else ""
        dbl = nx == c and c in "bcdfgklmnprstvz"
        k = i + 2 if dbl else i + 1          # the letter after the sound
        kc = s[k] if k < n else ""
        if c in "aeiou":
            if c in "iu" and _it_vowel(s, i + 1) and i not in acc and \
                    i not in syll:
                add("j" if c == "i" else "w", "G", i)
            elif c + nx in _IT_FALLING and i + 1 not in acc and \
                    not _it_vowel(s, i + 2):
                add(c, "V", i)
                add("j" if nx == "i" else "w", "v", i + 1)
                i += 1
            else:
                add(c, "V", i)
        elif c == "h":
            pass
        elif c in "cg" and silent_i(k):
            soft = "tʃ" if c == "c" else "dʒ"
            if dbl:
                add("t" if c == "c" else "d", "C", i)
            add(soft, "C", i)
            i = k
        elif c in "cg" and kc in "ei":
            soft = "tʃ" if c == "c" else "dʒ"
            if dbl:
                add("t" if c == "c" else "d", "C", i)
            add(soft, "C", i)
            i = k - 1
        elif c in "cg":
            hard = "k" if c == "c" else "ɡ"
            if kc == "h":
                k += 1
            elif c == "g" and kc == "n" and not dbl:
                # gn: one long sound between vowels, `bagno`.
                if after_vowel():
                    add("ɲ", "C", i)
                add("ɲ", "C", i)
                i = k
                i += 1
                continue
            elif c == "g" and kc == "l" and not dbl and \
                    k + 1 < n and s[k + 1] == "i":
                # gli: ʎ, long between vowels; the i is silent before a vowel.
                if after_vowel():
                    add("ʎ", "C", i)
                add("ʎ", "C", i)
                i = k + 1 if silent_i(k + 1) else k
                i += 1
                continue
            add(hard, "C", i)
            if dbl:
                add(hard, "C", i)
            i = k - 1
        elif c == "q":
            add("k", "C", i)
        elif c == "s":
            if nx == "c" and s[i + 2:i + 3] in ("e", "i"):
                # sce, sci: one long ʃ between vowels; sci before a vowel
                # has a silent i.
                if after_vowel():
                    add("ʃ", "C", i)
                add("ʃ", "C", i)
                i += 1
                if silent_i(i + 1):
                    i += 1
            elif nx == "c" and s[i + 2:i + 3] == "h":
                add("s", "C", i)
                add("k", "C", i)
                i += 2
            elif dbl:
                add("s", "C", i)
                add("s", "C", i)
                i += 1
            elif i in _IT_S_VOICELESS.get(s, ()):
                add("s", "C", i)
            elif nx and nx in "bdglmnrv" or \
                    (after_vowel() and _it_vowel(s, i + 1)):
                add("z", "C", i)
            else:
                add("s", "C", i)
        elif c == "z":
            voiced = i in dz_at
            ph = "dz" if voiced else "ts"
            stop = "d" if voiced else "t"
            if dbl:
                add(stop, "C", i)
                i += 1
            elif after_vowel() and nx == "i" and _it_vowel(s, i + 2):
                add(stop, "C", i)        # -zione, -zia: long, `ɡrattsje`
            add(ph, "C", i)
        elif c in "bdfklmnprtv":
            add(c, "C", i)
            if dbl:
                add(c, "C", i)
                i += 1
        elif c in "jy":
            add("j", "G", i)
        elif c == "w":
            add("w", "G", i)
        elif c == "x":
            add("k", "C", i)
            add("s", "C", i)
        else:
            raise CannotRead(f"not an Italian letter: {c!r}")
        i += 1
    return toks


# Falling diphthongs, one syllable: ai ei oi au eu (the i or u is j or w).
_IT_FALLING = {"ai", "ei", "oi", "au", "eu"}
# Words of three syllables or more that end in one of these are stressed on
# the third to last syllable (measured on Wiktionary's Italian entries: each
# is right for 85 to 100 percent of the words, `-bile` and `-issimo` for all).
# Words of two syllables or more that end in -ai, -ei or -oi are stressed on
# that last syllable instead (vorrei, farai).
_IT_ANTEPENULT = ("bile", "bili", "ico", "ica", "ici", "iche", "ile",
                  "evole", "evoli", "issimo", "issima", "issimi", "issime",
                  "imo", "ono")
# The frequent words those suffixes get wrong: stressed on the second to
# last syllable.
_IT_PENULT = {"amico", "amica", "amici", "amiche", "nemico", "nemica",
              "nemici", "nemiche", "antico", "antica", "antici", "antiche",
              "fatica", "gentile", "sottile", "civile", "aprile", "fucile"}
# A stressed e or o is closed unless the word's end says otherwise: these
# are the endings (after the stressed vowel) measured to be open in at least
# 90 percent of the words, and e after j and o after w. About two thirds of
# the stressed e and three quarters of the stressed o of Wiktionary's entries
# come out right; the rest need a hint or a line in _IT_MARKS.
_IT_OPEN_E = re.compile(r"(ll[aeio]|nz[ae]|bbe|ic[oaei]|iche)$")
_IT_OPEN_O = re.compile(r"(ri[oa]|ic[oaei]|iche|cco|ma)$")


def _it_pick_stress(toks: list[list], s: str, acc: dict[int, str]) -> int:
    """The index in [toks] of the stressed vowel."""
    nuclei = [k for k, t in enumerate(toks) if t[1] == "V"]
    for k in nuclei:
        if toks[k][2] in acc:
            return k
    if not acc and len(nuclei) > 1 and toks[-1][1] == "v" and \
            toks[-2][1] == "V" and s.endswith(("ai", "ei", "oi")):
        return nuclei[-1]       # vorrei, farai: 98 percent of the -ai, -oi
    if len(nuclei) > 2 and s not in _IT_PENULT and \
            s.endswith(_IT_ANTEPENULT):
        return nuclei[-3]
    return nuclei[-2] if len(nuclei) > 1 else nuclei[-1]


def _it_stress(toks: list[list], s: str, acc: dict[int, str]) -> str:
    nuclei = [k for k, t in enumerate(toks) if t[1] == "V"]
    if not nuclei:
        raise CannotRead(f"no vowel to read: {s!r}")
    stressed = _it_pick_stress(toks, s, acc)
    for k in nuclei:
        t = toks[k]
        if t[0] in "eo":
            if t[2] in acc and acc[t[2]]:
                t[0] = acc[t[2]]
            elif k == stressed and not acc:
                glide = toks[k - 1][0] if k and toks[k - 1][1] == "G" else ""
                t[0] = _it_openness(s, t[0], t[2], glide)
    if len(nuclei) < 2:
        return "".join(t[0] for t in toks)
    # The mark goes before the stressed syllable's onset: a glide, then the
    # consonants that can begin a syllable (a single one, or a stop with l or
    # r after it; an s closes the syllable before it, as Wiktionary divides
    # `stuˈdɛn.te`, `mos.ˈtra.to`), a doubled one split between the two.
    pos = stressed
    if pos > 0 and toks[pos - 1][1] == "G":
        pos -= 1
    if pos > 0 and toks[pos - 1][1] == "C":
        pos -= 1
        while pos > 0 and toks[pos - 1][1] == "C" and \
                _it_joins(toks[pos - 1][0], toks[pos][0]):
            pos -= 1
    if not any(t[1] in ("V", "v") for t in toks[:pos]):
        pos = 0             # a word's first s and consonant: `ˈskuzi`
    out = [t[0] for t in toks]
    out.insert(pos, "ˈ")
    return "".join(out)


def _it_joins(first: str, second: str) -> bool:
    """Whether [first] and [second], two consonants before a vowel, begin
    the same syllable."""
    if first == second:
        return False
    return first in _IT_STOPS and second in ("l", "r")


def _it_openness(s: str, vowel: str, idx: int, glide: str) -> str:
    rest = s[idx + 1:]
    if vowel == "e":
        if glide == "j" or _IT_OPEN_E.search(rest):
            return "ɛ"
    elif glide == "w" or _IT_OPEN_O.search(rest):
        return "ɔ"
    return vowel


# --- German ------------------------------------------------------------------

# Standard German (Hochdeutsch, de-DE), broad, as the decks write it: ˈ before
# the stressed syllable of a word of two syllables or more, ː for a long
# vowel, ç and x for ch, ʃ for sch and for initial sp and st, ts for z and
# tz, v for w, f for v and ph, ʁ for r (the uvular sound, as Wiktionary's
# phonemic forms and the first cards write it) and ɐ̯ for r after a long
# vowel or a diphthong before a consonant or the end (hiːɐ̯, aber ʁ after a
# short one: ˈɡaʁtən), ɐ for the unstressed ending -er, ŋ for ng and nk, ɛː
# for a long ä, final-obstruent devoicing (b d g to p t k at the end of a
# syllable: ɡuːt, ʊnt, ɡɪpt), ə for the unstressed -e, -en, -el, -em, -es,
# written with the schwa (ˈɡuːtən, never a syllabic n), aɪ for ei, ɔɪ for eu
# and äu, aʊ for au. The glottal stop that begins a vowel is not written, nor
# is secondary stress, nor the non-syllabic mark under the second part of a
# diphthong.
#
# What the letters show: the consonants, the vowels and the diphthongs, the
# length of a vowel before one consonant or before two or more (Tag, Wasser;
# Rad against Stadt), a silent h or a doubled vowel or ie for length, and the
# default stress on the first syllable of a word that has no prefix. What
# they do not show, and German spelling leaves to the reader's lexicon:
#  - stress in loan words and in compounds (Computer, Restaurant, Hotel), and
#    the few native words with an unstressed first syllable;
#  - the length of a vowel before ch or before a cluster that is not one
#    (Mädchen, Sprache, Sache);
#  - words whose h is said (Alkohol, Uhu) and the glide of -ie (Familie);
#  - schwa deletion (the speaker says -n, -l without a vowel; the engine
#    writes ən, əl) and which unstressed e in the middle of a word is a schwa;
#  - whether ng is ŋ or n+ɡ, and v in native against foreign words.
# The engine settles the stress and the length in these ways, and no more:
#  1. a *hint*: the text with its words marked as a dictionary marks them. An
#     acute on a vowel (á é í ó ú, or ä ö ü followed by U+0301) marks the
#     stressed one (`Banáne`), a colon after a vowel marks it long (`Mä:dchen`,
#     `Spra:che`) and a caret after a vowel marks it short (`Mo^nd` if a word
#     the rules read long is short). Only the marked vowels change. A hint is
#     used only if, with its marks removed, it is the text. A bar starts the
#     next part of a compound (`Fahr|ra:d`): each part is read as a word;
#  2. endings and prefixes that fix the stress: the unstressed prefixes be-
#     ge- er- ver- zer- ent- emp- miss- (the stress goes to the stem, and the
#     prefix is read apart, `verstehen` fɛɐ̯ˈʃteːən); -ieren verbs, -ier,
#     -ei, -ie, -tion, -ität, -ur, -ent (Student), which carry the stress
#     themselves; the separable and other prefixes zurück-, zusammen-,
#     her-/hin- with a second prefix, and da-/wo- compounds (damit, wofür),
#     which take it on their second part; every other separable prefix (an-
#     auf- aus- ein- mit- vor- zu- ab- nach- her- hin- weg-) begins the word
#     and so takes the default stress;
#  3. _DE_MARKS, a short table of very frequent words that follow no rule,
#     read as a hint is (short vowels before one consonant: und, mit, bis,
#     das, es, in, man; the loan words of the first decks);
#  4. otherwise the first syllable, long before a single consonant and
#     short before two or more (a stop and l or r count as one).
# A card whose broad `ipa` the engine misreads is given a hint.
# Measured on 208 everyday words picked by hand and read from en.wiktionary on
# 2026-11-28 (not a random sample): 182 are read as one of the forms the
# entry lists, once its syllable dots, secondary stress, glottal stops and
# non-syllabic marks are left out (many of the 208 are in _DE_MARKS, whose
# entries were read from the same pages). The rest are the limits above: loan
# word stress and sounds (Computer, Restaurant, Banane, Familie, November,
# Toilette, Chef, Handy, Ferien), the length of Mond, Sprache, Bücher and of
# the vowel of a compound's second part not listed in _DE_MARKS (Telefon,
# Wochenende), the ɐ̯ that Wiktionary writes after a short vowel before r
# (Schmerzen), and ʁ against χ and ɐ in its narrow forms.
#
# Sources: Wikipedia "Standard German phonology"; Wiktionary "Appendix:German
# pronunciation" and its entries' pronunciations.
_DE_VOWELS = "aeiouäöüy"
_DE_PUNCT = set(".,?!;:\"“”«»()…-–—")
_DE_STOPS = "pbtdkɡf"
# Words that no rule reads, as a hint marks them (see the section header).
_DE_MARKS = {
    "und": "u^nd", "mit": "mi^t", "bis": "bi^s",
    "das": "da^s", "es": "e^s", "in": "i^n", "man": "ma^n", "bin": "bi^n",
    "hat": "ha^t", "an": "a^n", "am": "a^m", "um": "u^m", "ab": "a^b",
    "ob": "o^b", "von": "vo^n", "vom": "vo^m", "zum": "zu^m",
    "was": "wa^s", "ins": "i^ns", "hin": "hi^n",
    "des": "de^s", "kaffee": "kaffeé", "hallo": "halló:", "hotel": "hoté^l",
    "kino": "kíno:", "mädchen": "mä:dchen", "damit": "damí^t",
    # Length before r and a consonant, and the long vowel of a compound's
    # second part, which the letters do not show.
    "arzt": "a:rzt", "urlaub": "u:rlaub", "erste": "e:rste",
    "geburtstag": "gebú:rtstag", "fahrrad": "fahr|ra:d",
    "montag": "mo:ntag", "nachmittag": "na:chmittag",
    "vormittag": "vo:rmittag", "bahnhof": "bahnho:f",
    "flughafen": "flu:gha:fen", "flugzeug": "flu:gzeug",
    "schlafzimmer": "schla:fzimmer", "handtuch": "hand|tu:ch",
    "erdbeere": "e:rdbeere", "erdgeschoss": "e:rdgeschoss",
    "vielleicht": "vie^lléicht", "vierzig": "vie^rzig", "obst": "o:bst",
    "brötchen": "brö:tchen", "nämlich": "nä:mlich",
    # Loan words and others with lexical stress or length.
    "natürlich": "natü\u0301:rlich", "apotheke": "apothé:ke",
    "kartoffel": "kartóffel", "tomate": "tomáte", "salat": "salát",
    "marmelade": "marmeláde", "gitarre": "gitárre", "minute": "minúte",
    "januar": "ja^nua:r", "februar": "fe:brua:r", "april": "aprí^l",
    "oktober": "október", "dezember": "dezémber",
}
# Whole-word forms for words the stress and length tables cannot give: loan
# words with sounds of their own and a few exceptions. Each is the first form
# that the word's entry on en.wiktionary lists (read 2026-11-28), in the
# engine's conventions: ʁ for r, ɡ, and no secondary stress, glottal stop,
# syllable dot or non-syllabic mark. A hint on the text beats an entry here.
_DE_RESPELL = {
    "handy": "ˈhɛndi", "chef": "ʃɛf", "ferien": "ˈfeːʁiən",
    "china": "ˈçiːna", "chance": "ˈʃãːsə", "computer": "kɔmˈpjuːtɐ",
    "restaurant": "ʁɛstoˈʁãː", "familie": "faˈmiːliə",
    "banane": "baˈnaːnə", "telefon": "teːləˈfoːn",
    "november": "noˈvɛmbɐ", "museum": "muˈzeːʊm", "toilette": "toaˈlɛtə",
    "job": "dʒɔp", "team": "tiːm", "sport": "ʃpɔʁt", "pizza": "ˈpɪtsa",
    "tee": "teː", "taxi": "ˈtaksi", "bus": "bʊs", "foto": "ˈfoːto",
    "familien": "faˈmiːliən",
}
# The names of the letters, for a letter and a word (S-Bahn, U-Bahn): the
# first form of each letter's entry on en.wiktionary, glottal stop left out.
_DE_LETTER_NAMES = {
    "a": "aː", "b": "beː", "c": "tseː", "d": "deː", "e": "eː", "f": "ɛf",
    "g": "ɡeː", "h": "haː", "i": "iː", "j": "jɔt", "k": "kaː", "l": "ɛl",
    "m": "ɛm", "n": "ɛn", "o": "oː", "p": "peː", "q": "kuː", "r": "ɛʁ",
    "s": "ɛs", "t": "teː", "u": "uː", "v": "faʊ", "w": "veː", "x": "ɪks",
    "y": "ʏpsilɔn", "z": "tsɛt",
}
# Prefixes read apart and never stressed: letters, then the phonemes.
_DE_PREFIXES = (("miss", "mɪs"), ("emp", "ɛmp"), ("ent", "ɛnt"),
                ("zer", "tsɛɐ̯"), ("ver", "fɛɐ̯"), ("be", "bə"),
                ("ge", "ɡə"), ("er", "ɛɐ̯"))
# The stress goes on the second part: the letter index where it begins.
_DE_SECOND = re.compile(
    r"^(?:(?:her|hin)(?=aus|ein|auf|ab|an|um|unter|über|vor|zu|durch)|"
    r"(?:da|dar|wo|wor)(?=(?:bei|mit|von|zu|für|gegen|nach|auf|an|in|um|"
    r"über|aus|vor|her|hin|runter)$)|zu(?=rück|sammen|erst|letzt|gleich|"
    r"mindest|nächst))")
# A word ending in one of these has its stress on the letter group that
# matches, the named group `at` (the first letter of the stressed vowel).
_DE_END_STRESS = re.compile(
    r"(?:(?P<a>i)er(?:en|e|st|t|te|ten)?$|(?P<c>e)i(?:en)?$|"
    r"(?:g|ph|krat|nom)(?P<d>i)e$|ti(?P<e>o)n(?:en)?$|it(?P<f>ä)t(?:en)?$|"
    r"(?P<g>u)r$|(?<=[b-df-hj-np-tv-z])(?P<h>e)nt(?:en|in|innen)?$)")
# An h before a vowel after zu-, da- or wo- at the start is said (zuhören,
# daher, wohin); every other h after a vowel is silent.
_DE_H_SAID = re.compile(r"^(?:zu|da|wo)h[aeiouäöü]")
# -sam is long (langsam), as the rule would not say.
_DE_SEPARABLE = ("an", "ab", "auf", "aus", "ein", "mit", "vor", "zu", "nach",
                 "her", "hin", "weg", "zurück", "um", "bei")
_DE_LONG_SAM = re.compile(r"sa(?=m(?:e|en|er|es|em)?$)")
# -tag is long (Freitag, Mittag): the a of the second part.
_DE_LONG_TAG = re.compile(r"(?<=..)ta(?=g(?:e|en|es|s)?$)")
_DE_NO_FRONT = "aou"


@dataclass
class _DeTok:
    ph: str                 # the phoneme(s)
    kind: str               # V nucleus, C consonant
    start: int              # letter span in the word
    end: int
    weight: int = 1         # consonant: letters, for the length before it
    vowel: str = ""         # plain vowel letter whose quality the rules give
    long: bool = False
    fixed: bool = False     # a diphthong, ie, or a prefix: ph is final
    src: str = ""
    r: bool = False         # the letter r
    sp: bool = False        # the sch of an initial sp or st
    ch: bool = False        # the letters ch


def german_ipa(text: str, hint: str | None = None) -> str:
    """Standard German, broad. [hint] is the text with each word marked as a
    dictionary marks it (see the section header): an acute on the stressed
    vowel, a colon after a long vowel, a caret after a short one; it is used
    only if, with its marks removed, it is the text. The limits are the
    section header's: loan word stress, the length of a vowel before ch or
    an odd cluster, schwa deletion, and the words whose h or ie is read
    otherwise. Raises CannotRead for a letter German spelling does not use."""
    text = unicodedata.normalize("NFC", text.lower())
    for c in text:
        if c.isspace() or c in _DE_PUNCT or c in "'’":
            continue
        if not ("a" <= c <= "z") and c not in "äöüßé":
            raise CannotRead(f"not a German letter: {c!r}")
    if re.search(r"(?<!\w)[a-z]-\w", text):
        # A letter and a word (S-Bahn): the letter's name, then the word.
        toks = text.split()
        hs = hint.split() if hint else []
        if len(hs) != len(toks):
            hs = [""] * len(toks)
        return " ".join(w for w in (
            _de_letter_compound(t, h) for t, h in zip(toks, hs)) if w)
    words = [w for w in re.split(r"[\s\-–—]+", text) if w]
    plain = [w.replace("é", "e") for w in words]
    hints = _de_hint_words(plain, hint)
    out = []
    for k, raw in enumerate(words):
        h = hints[k] if hints else ""
        if not h and "é" in raw:
            h = raw.replace("é", "é:")      # é is stressed and long (Café)
        out.append(_de_word(plain[k], h))
    return " ".join(w for w in out if w)


def _de_letter_compound(tok: str, hint: str = "") -> str:
    """[tok] (a word of the text, a hint word for it) with its surrounding
    punctuation left out; a letter, a hyphen and a word is read by the
    letter's name and then the word (hint for the word, if it fits)."""
    strip = "".join(_DE_PUNCT - {"-"}) + "'’"
    tok = tok.strip(strip)
    head, sep, rest = tok.partition("-")
    if not (sep and len(head) == 1 and "a" <= head <= "z" and rest):
        return german_ipa(tok, hint.strip(strip) or None)
    if head not in _DE_LETTER_NAMES:
        raise CannotRead(f"no letter name for: {head!r}")
    h = hint.strip(strip).partition("-")[2]
    return "ˈ" + _DE_LETTER_NAMES[head] + german_ipa(rest, h or None)


def _de_marks(hint: str) -> tuple[str, int | None, dict[int, str],
                                  set[int]]:
    """A hint word's letters, the index of its stressed vowel, the marks of
    length by letter index ("L" long, "S" short) and the letter indices where
    a compound's next part begins (a bar, `Fahr|rad`)."""
    letters: list[str] = []
    stress: int | None = None
    marks: dict[int, str] = {}
    bounds: set[int] = set()
    for c in unicodedata.normalize("NFD", hint.lower()):
        if c == "|" and letters:
            bounds.add(len(letters))
        elif c == "̈" and letters:
            letters[-1] = unicodedata.normalize("NFC", letters[-1] + c)
        elif c == "́" and letters:
            stress = len(letters) - 1
        elif c in ":^" and letters and letters[-1] in _DE_VOWELS:
            marks[len(letters) - 1] = "L" if c == ":" else "S"
        elif c in _DE_PUNCT or c in "'’":
            continue
        else:
            letters.append(c)
    return "".join(letters), stress, marks, bounds


def _de_clean(word: str) -> str:
    return "".join(c for c in word if c not in _DE_PUNCT and c not in "'’")


def _de_hint_words(words: list[str], hint: str | None) -> list[str]:
    """The hint's words if they are the text's words with marks, else none."""
    if not hint:
        return []
    hints = [w for w in re.split(r"[\s\-–—]+",
                                 unicodedata.normalize("NFC", hint.lower()))
             if w]
    if len(hints) != len(words) or any(
            _de_marks(h)[0] != _de_clean(w) for h, w in zip(hints, words)):
        return []
    return hints


def _german(text: str, hint: str | None) -> Transcription:
    ipa = german_ipa(text, hint)
    words = [w for w in re.split(r"[\s\-–—]+",
                                 unicodedata.normalize("NFC", text.lower()))
             if w]
    fitted = not hint or bool(_de_hint_words(words, hint))
    return Transcription(text, ipa, fitted)


def _de_is_vowel(s: str, i: int) -> bool:
    return 0 <= i < len(s) and s[i] in _DE_VOWELS


def _de_prefix(word: str) -> tuple[int, str]:
    """The length and phonemes of the unstressed prefix [word] begins with,
    or (0, "")."""
    if word == "berlin":
        return 3, "bɛɐ̯"
    for letters, ph in _DE_PREFIXES:
        if not word.startswith(letters):
            continue
        rest = word[len(letters):]
        nuclei = len(re.findall(r"[aeiouäöüy]+", rest))
        if not nuclei:
            continue
        if letters in ("be", "ge") and rest[0] in "iue":
            continue            # a diphthong or ee: geil, beuge, Beere
        if letters == "be" and rest[0] == "r" and len(rest) > 1 and \
                rest[1] not in _DE_VOWELS:
            continue            # Berg, Bernd
        if letters == "er" and re.match(r"d[^aeiouäöüy]", rest):
            continue            # Erdbeere, Erdgeschoss
        if letters == "miss" and rest[0] in _DE_VOWELS:
            continue
        # A stem that only looks like a prefix: geben, gehen, Erde, gerne.
        if nuclei == 1 and re.fullmatch(
                r"[^aeiouäöüy]*e(?:[nrlsm]|rn|rm|rs|ns|ls)?", rest):
            continue
        return len(letters), ph
    return 0, ""


def _de_prefix_toks(ph: str, n: int) -> list[_DeTok]:
    """The tokens of a prefix: its consonants and its one vowel."""
    toks: list[_DeTok] = []
    for m in re.finditer(r"(ɛɐ̯|ɛ|ə|ɪ)|(.)", ph):
        if m.group(1):
            toks.append(_DeTok(m.group(1), "V", 0, n, fixed=True))
        else:
            toks.append(_DeTok(m.group(2), "C", 0, n))
    return toks


def _de_tokens(s: str, base: int, initial: bool) -> list[_DeTok]:
    """The sounds of [s], the word from letter index [base] on. [initial]:
    whether [s] begins a word or the part after a prefix."""
    n = len(s)
    toks: list[_DeTok] = []

    def add(ph: str, kind: str, i: int, j: int, **kw) -> _DeTok:
        t = _DeTok(ph, kind, base + i, base + j, src=s[i:j], **kw)
        toks.append(t)
        return t

    def vowel_at(i: int) -> bool:
        return i < n and s[i] in _DE_VOWELS

    i = 0
    while i < n:
        c = s[i]
        two = s[i:i + 2]
        if c in _DE_VOWELS:
            if c == "y" and i == 0 and vowel_at(1):
                add("j", "C", i, i + 1)
                i += 1
                continue
            if c == "i" and s[i:i + 2] == "ig" and (
                    i + 2 == n or re.match(r"(?:keit|lich)", s[i + 2:])):
                add("ɪ", "V", i, i + 1, fixed=True)
                add("ç", "C", i + 1, i + 2, weight=1)
                i += 2
                continue
            if two in ("ei", "ai", "ey", "ay"):
                t = add("aɪ", "V", i, i + 2, fixed=True)
                j = i + 2
            elif two in ("eu", "äu"):
                t = add("ɔɪ", "V", i, i + 2, fixed=True)
                j = i + 2
            elif two == "au":
                t = add("aʊ", "V", i, i + 2, fixed=True)
                j = i + 2
            elif two == "ie":
                t = add("iː", "V", i, i + 2, fixed=True, long=True)
                j = i + 2
            elif two in ("aa", "ee", "oo"):
                t = add(c, "V", i, i + 2, vowel=c, long=True)
                j = i + 2
            else:
                t = add(c, "V", i, i + 1, vowel="ü" if c == "y" else c)
                j = i + 1
            # An h after a vowel is silent and makes a plain vowel long.
            if j < n and s[j] == "h" and not (
                    base == 0 and j == 2 and _DE_H_SAID.match(s)):
                if not t.fixed or t.ph == "iː":
                    t.long = True
                t.end += 1
                j += 1
            i = j
            continue
        nx = s[i + 1] if i + 1 < n else ""
        # Letter groups of consonants, longest first.
        if s[i:i + 4] == "tsch":
            add("tʃ", "C", i, i + 4, weight=2)
            i += 4
        elif s[i:i + 4] == "tion" and i > 0:
            add("tsj", "C", i, i + 2)
            add("oː", "V", i + 2, i + 3, fixed=True, long=True)
            i += 3
        elif s[i:i + 3] == "sch":
            add("ʃ", "C", i, i + 3, weight=2)
            i += 3
        elif s[i:i + 3] == "chs":
            add("k", "C", i, i + 2, weight=2)
            add("s", "C", i + 2, i + 3)
            i += 3
        elif two == "ch":
            back = bool(toks) and toks[-1].kind == "V" and (
                (toks[-1].vowel != "" and toks[-1].vowel in _DE_NO_FRONT)
                or toks[-1].ph == "aʊ")
            if i == 0 and initial and not toks:
                ph = "k" if s[i + 2:i + 3] in ("a", "o", "u", "l", "r") \
                    else "ç"
            else:
                ph = "x" if back else "ç"
            add(ph, "C", i, i + 2, weight=2, ch=True)
            i += 2
        elif two == "ck":
            add("k", "C", i, i + 2, weight=2)
            i += 2
        elif two == "tz":
            add("ts", "C", i, i + 2, weight=2)
            i += 2
        elif two == "pf":
            add("pf", "C", i, i + 2, weight=2)
            i += 2
        elif two == "ph":
            add("f", "C", i, i + 2)
            i += 2
        elif two == "th":
            add("t", "C", i, i + 2)
            i += 2
        elif two == "dt":
            add("t", "C", i, i + 2, weight=2)
            i += 2
        elif c == "q":
            if nx == "u":
                add("kv", "C", i, i + 2, weight=2)
                i += 2
            else:
                add("k", "C", i, i + 1)
                i += 1
        elif c == "n" and nx in ("g", "k") and (
                s[:i + 1] in _DE_SEPARABLE and (
                    nx == "k" or s[:i + 1] == "ein" or
                    s[i + 2:i + 3] == "e")):
            add("n", "C", i, i + 1)
            i += 1
        elif c == "n" and nx == "g":
            add("ŋ", "C", i, i + 2, weight=2)
            i += 2
        elif c == "n" and nx == "k":
            add("ŋ", "C", i, i + 1)
            i += 1
        elif c == "s":
            if nx == "s":
                add("s", "C", i, i + 2, weight=2)
                i += 2
            elif nx in ("p", "t") and (i == 0 and initial or
                                       s[:i] in _DE_SEPARABLE):
                add("ʃ", "C", i, i + 1, sp=True)
                i += 1
            elif i == 1 and initial and s[0] == "p":
                add("s", "C", i, i + 1)         # Psalm, Psychologe
                i += 1
            elif vowel_at(i + 1):
                add("z", "C", i, i + 1)
                i += 1
            else:
                add("s", "C", i, i + 1)
                i += 1
        elif c == "ß":
            add("s", "C", i, i + 1)
            i += 1
        elif c == "z":
            j = i + 2 if nx == "z" else i + 1
            add("ts", "C", i, j, weight=j - i)
            i = j
        elif c == "x":
            add("ks", "C", i, i + 1, weight=2)
            i += 1
        elif c == "c":
            ph = "ts" if nx in ("e", "i", "ä", "ö", "ü", "y") else "k"
            add(ph, "C", i, i + 1)
            i += 1
        elif c == "v":
            if i == 0 or not vowel_at(i + 1):
                add("f", "C", i, i + 1)
            else:
                add("v", "C", i, i + 1)
            i += 1
        elif c == "w":
            add("v", "C", i, i + 1)
            i += 1
        elif c == "j":
            add("j", "C", i, i + 1)
            i += 1
        elif c == "h":
            add("h", "C", i, i + 1)
            i += 1
        elif c == "r":
            j = i + 2 if nx == "r" else i + 1
            add("ʁ", "C", i, j, weight=j - i, r=True)
            i = j
        elif c in "bdfgklmnpt":
            ph = "ɡ" if c == "g" else c
            j = i + 2 if nx == c else i + 1
            add(ph, "C", i, j, weight=j - i)
            i = j
        else:
            raise CannotRead(f"not a German letter: {c!r}")
    return toks


def _de_joins(a: _DeTok, b: _DeTok) -> bool:
    """Whether [a] and [b], two consonants before a vowel, begin the same
    syllable: a stop or f and then l or r, ʃ and then p t l m n v or r
    (schlafen, sprechen, Schwester), or ts and v (zwanzig)."""
    if a.kind != "C" or b.kind != "C":
        return False
    if a.ph == "ʃ":
        return b.ph in ("p", "t", "l", "m", "n", "v") or b.r
    if a.ph == "ts":
        return b.ph == "v"
    return a.ph in _DE_STOPS and (b.ph == "l" or b.r)


def _de_cluster(toks: list[_DeTok], k: int) -> list[_DeTok]:
    """The consonants after the nucleus at [k], up to the next one."""
    out = []
    j = k + 1
    while j < len(toks) and toks[j].kind == "C":
        out.append(toks[j])
        j += 1
    return out


def _de_onset_only(cluster: list[_DeTok]) -> bool:
    """Whether the whole cluster, followed by a vowel, begins a syllable."""
    return len(cluster) > 1 and all(
        _de_joins(a, b) for a, b in zip(cluster, cluster[1:]))


def _de_pick_stress(word: str, toks: list[_DeTok], off: int, k0: int,
                    hint_at: int | None) -> int:
    """The index in [toks] of the stressed nucleus; [off] is the length of
    the prefix, [k0] the index of the first token after it."""
    nuclei = [k for k, t in enumerate(toks) if t.kind == "V"]

    def at(pos: int) -> int | None:
        for k in nuclei:
            if toks[k].end > pos:
                return k
        return None

    if hint_at is not None and at(hint_at) is not None:
        return at(hint_at)  # type: ignore[return-value]
    m = _DE_SECOND.match(word)
    if m and m.end() < len(word):
        k = at(m.end())
        if k is not None:
            return k
    m = _DE_END_STRESS.search(word)
    if m and len(nuclei) > 1:
        group = next(g for g, v in m.groupdict().items() if v)
        k = at(m.start(group))
        if k is not None and (off == 0 or toks[k].start >= off):
            return k
    after = [k for k in nuclei if k >= k0]
    return after[0] if after else nuclei[0]


def _de_word(raw: str, hint: str) -> str:
    word = _de_clean(raw)
    if not word:
        return ""
    if not hint:
        if word in _DE_RESPELL:
            return _DE_RESPELL[word]
        if word.endswith("s") and word[:-1] in _DE_RESPELL:
            return _DE_RESPELL[word[:-1]] + "s"     # Fotos, Jobs
    stress_at: int | None = None
    marks: dict[int, str] = {}
    bounds: set[int] = set()
    if hint:
        _, stress_at, marks, bounds = _de_marks(hint)
    elif word in _DE_MARKS:
        _, stress_at, marks, bounds = _de_marks(_DE_MARKS[word])
    n_pre, pre_ph = _de_prefix(word)
    if n_pre and stress_at is not None and stress_at < n_pre:
        n_pre, pre_ph = 0, ""       # a hint that stresses the prefix
    toks = _de_prefix_toks(pre_ph, n_pre) if n_pre else []
    k0 = len(toks)
    edges = [n_pre] + sorted(b for b in bounds if n_pre < b < len(word)) + [
        len(word)]
    for a, b in zip(edges, edges[1:]):
        toks += _de_tokens(word[a:b], a, True)
    return _de_resolve(word, toks, n_pre, k0, stress_at, marks)


def _de_resolve(word: str, toks: list[_DeTok], n_pre: int, k0: int,
                stress_at: int | None, marks: dict[int, str]) -> str:
    nuclei = [k for k, t in enumerate(toks) if t.kind == "V"]
    if not nuclei:
        raise CannotRead(f"no vowel to read: {word!r}")
    stressed = _de_pick_stress(word, toks, n_pre, k0, stress_at)
    sam = {m.start() + 1 for m in _DE_LONG_SAM.finditer(word)}
    sam |= {m.start() + 1 for m in _DE_LONG_TAG.finditer(word)}
    for k in nuclei:
        t = toks[k]
        mark = next((marks[j] for j in range(t.start, t.end) if j in marks),
                    None)
        if t.fixed:
            if t.ph == "iː" and mark == "S":
                t.ph = "ɪ" if k == stressed else "i"     # vierzig, vielleicht
            continue
        cl = _de_cluster(toks, k)
        has_next = k + 1 + len(cl) < len(toks)
        onset_only = bool(cl) and has_next and _de_onset_only(cl)
        # The consonants that close the syllable; the last one of a cluster
        # before a vowel begins the next.
        coda = [] if onset_only or (
            len(cl) == 1 and has_next and (
                cl[0].weight == 1 or cl[0].ph in ("ʃ", "ç", "x", "tʃ"))
        ) else (
            cl[:-1] if has_next and len(cl) > 1 else cl)
        if not cl:
            w = 0
        elif onset_only:
            w = 1
        elif has_next and len(cl) == 1:
            w = cl[0].weight
        else:
            w = sum(c.weight for c in cl)
        if t.vowel == "u" and len(cl) == 1 and cl[0].ch:
            w = 1               # Buch, Tuch, Kuchen
        if mark == "L":
            t.long = True
        elif mark == "S":
            t.long = False
        elif t.start in sam:
            t.long = True
        elif k == stressed and not t.long:
            t.long = w < 2
        v = t.vowel
        if k == stressed or t.long or mark:
            t.ph = _DE_LONG[v] if t.long else _DE_SHORT[v]
            continue
        if v == "e" and k > stressed:
            if coda and coda[0].r:
                t.ph = "ɐ"          # unstressed er before a consonant or end
                coda[0].ph = ""
                coda[0].r = False
                continue
            if re.fullmatch(r"[lmnstdh]{0,2}", "".join(c.src for c in coda)):
                t.ph = "ə"
                continue
        elif v == "e" and k != nuclei[0] and not coda:
            t.ph = "ə"              # the e of Telefon, Bäckerei
            continue
        # Any other unstressed short vowel: the tense one when the syllable
        # is open and the vowel final, before a vowel or before the stress,
        # else the lax one.
        tense = not coda and (k < stressed or not cl or v == "i")
        t.ph = _DE_TENSE[v] if tense else _DE_SHORT[v]
    _de_consonants(toks)
    return _de_join(toks, stressed, len(nuclei))


_DE_LONG = {"a": "aː", "e": "eː", "i": "iː", "o": "oː", "u": "uː",
            "ä": "ɛː", "ö": "øː", "ü": "yː"}
_DE_SHORT = {"a": "a", "e": "ɛ", "i": "ɪ", "o": "ɔ", "u": "ʊ",
             "ä": "ɛ", "ö": "œ", "ü": "ʏ"}
_DE_TENSE = {"a": "a", "e": "e", "i": "i", "o": "o", "u": "u",
             "ä": "ɛ", "ö": "ø", "ü": "y"}


def _de_consonants(toks: list[_DeTok]) -> None:
    """Resolve r and the voicing of b, d, g in place."""
    for j, t in enumerate(toks):
        if t.kind != "C":
            continue
        prev = toks[j - 1] if j else None
        nxt = toks[j + 1] if j + 1 < len(toks) else None
        if t.r:
            if nxt is not None and nxt.kind == "V":
                t.ph = "ʁ"
            elif prev is not None and prev.kind == "V" and (
                    prev.ph.endswith("ː") or prev.ph in ("aɪ", "aʊ", "ɔɪ")):
                t.ph = "ɐ̯"
            else:
                t.ph = "ʁ"
        elif t.ph in ("b", "d", "ɡ"):
            onset = nxt is not None and nxt.kind == "C" and (
                nxt.ph == "l" or nxt.r or (j == 0 and nxt.ph == "n")
            ) and j + 2 < len(toks) and toks[j + 2].kind == "V"
            if nxt is None or (nxt.kind == "C" and not onset):
                t.ph = {"b": "p", "d": "t", "ɡ": "k"}[t.ph]


def _de_join(toks: list[_DeTok], stressed: int, n_nuclei: int) -> str:
    out = [t.ph for t in toks]
    if n_nuclei < 2:
        return "".join(out)
    pos = stressed
    if pos > 0 and toks[pos - 1].kind == "C":
        pos -= 1
        while pos > 0 and _de_joins(toks[pos - 1], toks[pos]):
            pos -= 1
    if all(t.kind == "C" for t in toks[:pos]):
        pos = 0             # the whole initial cluster is the onset: Kneipe
    out.insert(pos, "ˈ")
    return "".join(out)


# --- Russian -----------------------------------------------------------------

# Standard Russian (the Moscow norm), broad, as the decks write it: ˈ before
# the stressed syllable of a word of two syllables or more (none on a word of
# one), ʲ after a palatalised consonant, ɨ for ы, ʂ ʐ for ш ж, tɕ for ч, ɕː for
# щ, ts for ц, x for х, ɡ for г, j for й and for the glide before е ё ю я at
# the start of a word or after a vowel or a sign, and the reduced vowels of
# unstressed syllables: ɐ for о and а just before the stress or at the start
# of a word, ə for them elsewhere, ɪ for и, е and я (and for а after ч щ),
# ʊ for у and ю. The reading is the decks' transliteration, not a standard:
# BGN/PCGN's letters (ё yo, ж zh, х kh, ц ts, ч ch, ш sh, щ shch, ы y, э e,
# й y, ю yu, я ya) with these choices, each read off the cards already in
# decks/ru and kept: a soft or hard sign is written ' at the end of a word
# and before a vowel and left out before a consonant (ochen', bolshoye,
# skolko); е is ye at the start of a word and after а о у ы э ю я ё й or a
# sign but e after a consonant, и or е (dobroye, svidanie, medlennee); -ый is
# y (dobry); capitals stay capitals; the stress mark is never written.
#
# Sources: Wikipedia, "Russian phonology" (vowel reduction by position and
# by the consonant before; palatalisation; final devoicing and voicing
# assimilation, в excepted; the silent consonants of стн, вств, лнц, рдц; сч
# and зч as ɕː; long consonants; the -ся after т or ть as hard) and
# Wiktionary, "Appendix:Russian pronunciation" (the vowels, ж ш as hard,
# ч щ й as soft, the ɐ of an unstressed word-initial а or о). The broad
# symbols follow Wiktionary's phonemic forms and the first cards (ɐ ə ɪ ʊ, not
# ʌ). Not stated on those pages, and so the engine's own rules (several read
# off the first cards): -тся and -ться as tsə, the ɐ of the first pretonic
# syllable, ɪ for an unstressed э, the values of a final unstressed е and я,
# г as x before к and ч, the glide after a vowel, and the doubled-consonant
# rule below.
#
# Stress is in the lexicon, not the letters. The engine takes it from:
#  1. the text itself: a combining acute U+0301 after the stressed vowel
#     (`приве́т`) or an ё (always stressed);
#  2. a *hint*: the same words with their stress marked as in (1); used only
#     if, with its marks removed and ё read as е, it is the text;
#  3. a word of one vowel (stressed, no mark written), and a proclitic
#     (a preposition, conjunction or particle of one syllable such as в на не
#     и, in a text of two words or more), which is unstressed;
#  else a *guess*: the second-last syllable, which Russian does not make
#  safe. A guessed word is named in the Transcription's `notes`.
# Known limits: the guess; loan words whose е is hard (тест) or whose о is not
# reduced (радио); ё written е; the word-final г of бог; г as v in -ого -его
# is applied to every such word but a short list (много, строго, дорого ...);
# the stems of вств (чувство, здравствуй) are listed, so баловство keeps its
# в; стн, здн and стл drop their т or д everywhere, though some words keep
# it (костный); ч is ш only in что чтобы конечно скучно нарочно; no
# assimilation of softness (стʲ before a soft consonant) and no voicing
# across a word boundary; doubled soft consonants (Россия) are not checked;
# тч дц тс are not simplified; a prefix before с or з and ч (без часов) is
# read as щ; the proclitics are the listed words only; the й of пожалуйста
# is dropped (as the first cards write it), and no other word with a silent
# letter is known.

_RU_VOWELS = "аеёиоуыэюя"
_RU_CONS = "бвгджзклмнпрстфхцчшщй"
_RU_PUNCT = set(".,?!;:\"“”«»()…-–—")
_RU_CLITICS = {"в", "во", "к", "ко", "с", "со", "у", "о", "об", "обо",
               "от", "до", "за", "на", "по", "над", "под", "при", "про",
               "без", "из", "для", "не", "ни", "и", "а", "но", "же", "ли",
               "бы", "то", "ль"}
_RU_BASE = {"б": "b", "в": "v", "г": "ɡ", "д": "d", "ж": "ʐ", "з": "z",
            "к": "k", "л": "l", "м": "m", "н": "n", "п": "p", "р": "r",
            "с": "s", "т": "t", "ф": "f", "х": "x", "ц": "ts", "ч": "tɕ",
            "ш": "ʂ", "щ": "ɕː", "й": "j"}
_RU_DEVOICE = {"b": "p", "v": "f", "ɡ": "k", "d": "t", "ʐ": "ʂ", "z": "s"}
_RU_VOICE = {v: k for k, v in _RU_DEVOICE.items()}
_RU_VOICELESS = {"p", "f", "k", "t", "ʂ", "s", "ts", "tɕ", "ɕː", "x"}
_RU_VOICED_OBS = {"b", "d", "ɡ", "z", "ʐ"}
_RU_NO_V = {"ого", "много", "немного", "строго", "нестрого", "убого",
            "дорого", "недорого", "лого", "бого"}
_RU_CH_SH = {"что", "чтобы", "конечно", "скучно", "нарочно"}
_RU_VSTV = ("здравств", "чувств", "безмолвств")
_RU_ROMAN = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "ж": "zh", "з": "z",
    "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o",
    "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "kh",
    "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch", "ы": "y", "э": "e",
    "ю": "yu", "я": "ya", "ё": "yo"}
_RU_ACUTE = "́"
_RU_OBSTRUENT = {"p", "b", "t", "d", "k", "ɡ", "f", "v", "x", "s", "z", "ʂ",
                 "ʐ", "ts", "tɕ"}
_RU_SIBILANT = {"s", "z", "ʂ", "ʐ", "ɕ"}


def _ru_check(text: str) -> None:
    for c in text.lower():
        if (c.isspace() or c in _RU_PUNCT or c == _RU_ACUTE
                or c in _RU_VOWELS or c in _RU_CONS or c in "ьъ"):
            continue
        raise CannotRead(f"not a Russian letter: {c!r}")


def _ru_words(text: str) -> list[str]:
    return "".join(" " if c in _RU_PUNCT else c for c in text).split()


def _ru_parse(word: str) -> tuple[str, int | None]:
    """A word's letters and the index of its marked vowel, if any."""
    letters: list[str] = []
    stress: int | None = None
    for c in word:
        if c == _RU_ACUTE:
            if letters:
                stress = len(letters) - 1
            continue
        if c == "ё":
            stress = len(letters)
        letters.append(c)
    return "".join(letters), stress


def _ru_fold(word: str) -> str:
    return _ru_parse(word)[0].replace("ё", "е")


def _ru_hint_words(words: list[str], hint: str | None) -> list[str]:
    """The hint's words if they are the text's words with stress marks, else
    none."""
    if not hint:
        return []
    hints = _ru_words(unicodedata.normalize("NFC", hint).lower())
    if len(hints) != len(words) or any(
            _ru_fold(h) != _ru_fold(w) for h, w in zip(hints, words)):
        return []
    return hints


def russian_ipa(text: str, hint: str | None = None) -> str:
    """Standard Russian, broad. [hint] is the text with its words' stress
    marked (an acute U+0301 after the stressed vowel); it is used only if,
    with its marks removed, it is the text. The limits and the stress rules
    are the section header's. Raises CannotRead for a letter Russian
    spelling does not use."""
    return _ru_ipa(text, hint)[0]


def _ru_ipa(text: str, hint: str | None) -> tuple[str, list[str]]:
    text = unicodedata.normalize("NFC", text).lower()
    _ru_check(text)
    words = _ru_words(text)
    hints = _ru_hint_words(words, hint)
    out: list[str] = []
    notes: list[str] = []
    for k, raw in enumerate(words):
        letters, stress = _ru_parse(raw)
        if stress is None and hints:
            stress = _ru_parse(hints[k])[1]
        clitic = (len(words) > 1 and stress is None
                  and letters in _RU_CLITICS)
        ipa, guess = _ru_word(letters, stress, clitic)
        if guess:
            notes.append(f"{letters}: stress guessed (second-last "
                         f"syllable); mark it with an acute or give a hint")
        out.append(ipa)
    return " ".join(w for w in out if w), notes


def _russian(text: str, hint: str | None) -> Transcription:
    ipa, notes = _ru_ipa(text, hint)
    words = _ru_words(unicodedata.normalize("NFC", text).lower())
    fitted = not hint or bool(_ru_hint_words(words, hint))
    return Transcription(russian_reading(text), ipa, fitted, notes)


def russian_reading(text: str) -> str:
    """[text] in the decks' transliteration (see the section header). Raises
    CannotRead for a letter Russian spelling does not use."""
    text = unicodedata.normalize("NFC", text).replace(_RU_ACUTE, "")
    _ru_check(text)
    out: list[str] = []
    for m in re.finditer(r"[^\W\d_]+|[\W\d_]", text):
        w = m.group()
        if not w.isalpha():
            out.append(w)
            continue
        low = w.lower()
        parts: list[str] = []
        for i, c in enumerate(low):
            prev = low[i - 1] if i else ""
            nxt = low[i + 1] if i + 1 < len(low) else ""
            if c in "ьъ":
                before_vowel = bool(nxt) and nxt in _RU_VOWELS
                parts.append("'" if before_vowel or (not nxt and c == "ь")
                             else "")
            elif c == "е":
                ye = not prev or prev in "аоуыэюяёйьъ"
                parts.append("ye" if ye else "e")
            elif c == "й" and not nxt and prev == "ы":
                parts.append("")        # -ый is y
            else:
                parts.append(_RU_ROMAN[c])
        r = "".join(parts)
        if len(w) > 1 and w.isupper():
            r = r.upper()
        elif w[0].isupper():
            r = r[0].upper() + r[1:]
        out.append(r)
    return "".join(out)


@dataclass
class _RuUnit:
    kind: str                   # "C" or "V"
    letter: str
    stressed: bool = False
    base: str = ""
    soft: bool = False
    long: bool = False
    ctx: str = ""               # for a vowel: init, vowel, sign, soft, hard, hzs


def _ru_prepare(letters: str, stress: int | None) -> list[list]:
    """The word's letters, as [letter, stressed] pairs, with the spelling
    rules that drop or change a letter applied."""
    toks = [[c, i == stress] for i, c in enumerate(letters)]

    def word() -> str:
        return "".join(t[0] for t in toks)

    s = word()
    if s in _RU_CH_SH:
        toks[s.index("ч")][0] = "ш"
    if s == "сегодня":
        toks[2][0] = "в"
    if len(s) >= 3 and s.endswith(("ого", "его")) and s not in _RU_NO_V:
        toks[-2][0] = "в"
    if s == "пожалуйста":
        del toks[s.index("й")]          # the й is not said
    if any(st in s for st in _RU_VSTV):
        del toks[s.index("вств")]
    for pat, drop in (("стн", 1), ("здн", 1), ("стл", 1), ("лнц", 0),
                      ("рдц", 1)):
        while pat in word():
            del toks[word().index(pat) + drop]
    for tail in ("ться", "тся"):
        if word().endswith(tail) and not any(t[1] for t in toks[-len(tail):]):
            del toks[-len(tail):]
            toks.extend([["ц", False], ["а", False]])
            break
    for pair in ("сч", "зч"):
        while pair in word():
            i = word().index(pair)
            toks[i:i + 2] = [["щ", toks[i][1] or toks[i + 1][1]]]
    return toks


def _ru_units(toks: list[list]) -> list[_RuUnit]:
    units: list[_RuUnit] = []
    pending_sign = False
    for ch, st in toks:
        if ch in _RU_CONS:
            units.append(_RuUnit("C", ch, False, _RU_BASE[ch]))
            pending_sign = False
        elif ch in "ьъ":
            if units and units[-1].kind == "C":
                if ch == "ь" and units[-1].letter not in "жшцчщй":
                    units[-1].soft = True
            pending_sign = True
        else:
            if pending_sign:
                ctx = "sign"
            elif not units:
                ctx = "init"
            elif units[-1].kind == "V":
                ctx = "vowel"
            else:
                last = units[-1]
                if last.letter in "жшц":
                    ctx = "hzs"
                elif last.letter in "чщй":
                    ctx = "soft"
                elif ch in "еёиюя":
                    last.soft = True
                    ctx = "soft"
                else:
                    ctx = "hard"
            units.append(_RuUnit("V", ch, st, ctx=ctx))
            pending_sign = False
    merged: list[_RuUnit] = []
    for i, u in enumerate(units):
        if (u.kind == "C" and merged and merged[-1].kind == "C"
                and merged[-1].letter == u.letter):
            if i + 1 < len(units) and units[i + 1].kind == "V":
                merged[-1].long = True
            merged[-1].soft = merged[-1].soft or u.soft
            continue
        merged.append(u)
    return merged


def _ru_voicing(units: list[_RuUnit]) -> None:
    """Final devoicing and voicing assimilation, within the word."""
    n = len(units)
    for j in range(n - 1, -1, -1):
        u = units[j]
        if u.kind != "C":
            continue
        nxt = units[j + 1] if j + 1 < n else None
        if nxt is None:
            if u.base in _RU_DEVOICE:
                u.base = _RU_DEVOICE[u.base]
        elif nxt.kind == "C":
            if u.base == "ɡ" and nxt.base in ("k", "tɕ"):
                u.base = "x"            # мягкий, легко
            elif nxt.base in _RU_VOICELESS and u.base in _RU_DEVOICE:
                u.base = _RU_DEVOICE[u.base]
            elif nxt.base in _RU_VOICED_OBS and u.base in _RU_VOICE:
                u.base = _RU_VOICE[u.base]


def _ru_vowel(u: _RuUnit, rel: str, last: bool, prev_v: str) -> str:
    """One vowel's IPA, with the glide before it. [rel] is its place against
    the stress: stress, pre1 (just before it), pre or post."""
    letter, ctx = u.letter, u.ctx
    j = "j" if ctx in ("init", "vowel", "sign") and letter in "еёюя" else ""
    if rel == "stress":
        p = {"а": "a", "о": "o", "у": "u", "э": "ɛ", "ы": "ɨ", "е": "e",
             "ё": "o", "ю": "u", "я": "a", "и": "i"}[letter]
        if ctx == "hzs":
            p = {"е": "ɛ", "и": "ɨ"}.get(letter, p)
        return j + p
    if letter in "ао":
        if ctx == "soft" and not (last and rel == "post"):
            return "ɪ"
        return "ɐ" if rel == "pre1" or ctx == "init" else "ə"
    if letter in "ую":
        return j + "ʊ"
    if letter == "ы":
        return "ɨ"
    if letter == "и":
        return "ɨ" if ctx == "hzs" else "ɪ"
    if letter == "э":
        return "ɪ"
    if letter == "е":
        if ctx == "hzs":
            return "ɨ" if rel == "pre1" else "ə"
        if ctx == "vowel" and rel == "post" and prev_v not in ("ɪ", "i"):
            return j + "ə"
        return j + "ɪ"
    # я
    if ctx == "hzs":
        return "ɨ"
    return j + ("ə" if last and rel == "post" else "ɪ")


def _ru_legal(cl: list[str]) -> bool:
    """Whether the consonants can begin a syllable together."""
    if len(cl) == 1:
        return True
    if len(cl) == 2:
        a, b = cl
        return ((a in _RU_OBSTRUENT and b in {"l", "r", "v", "n", "m"})
                or (a in _RU_SIBILANT and b in _RU_OBSTRUENT | {
                    "m", "n", "l", "v"}))
    if len(cl) == 3:
        return cl[0] in _RU_SIBILANT and _ru_legal(cl[1:])
    return False


def _ru_word(letters: str, stress: int | None, clitic: bool
             ) -> tuple[str, bool]:
    """The IPA of one word, and whether its stress was guessed."""
    units = _ru_units(_ru_prepare(letters, stress))
    _ru_voicing(units)
    vowels = [i for i, u in enumerate(units) if u.kind == "V"]
    guessed = False
    s: int | None = None
    marked = [k for k, i in enumerate(vowels) if units[i].stressed]
    if marked:
        s = marked[0]
    elif len(vowels) == 1 and not clitic:
        s = 0
    elif len(vowels) >= 2 and not clitic:
        s = len(vowels) - 2
        guessed = True
    atoms: list[tuple[str, str]] = []       # (kind, text)
    stress_at = -1
    prev_v = ""
    for i, u in enumerate(units):
        if u.kind == "C":
            t = u.base + ("ʲ" if u.soft and u.letter not in "жшцчщй" else "")
            if u.long and not t.endswith("ː"):
                t += "ː"
            atoms.append(("C", t))
            continue
        k = vowels.index(i)
        if s is None:
            rel = "pre"
        elif k == s:
            rel = "stress"
        elif k == s - 1:
            rel = "pre1"
        elif k < s:
            rel = "pre"
        else:
            rel = "post"
        p = _ru_vowel(u, rel, k == len(vowels) - 1, prev_v)
        prev_v = p[-1]
        if rel == "stress":
            stress_at = len(atoms)
        atoms.append(("V", p))
    if stress_at >= 0 and len(vowels) >= 2:
        start = stress_at
        while start > 0 and atoms[start - 1][0] == "C":
            start -= 1
        run = [a[1].rstrip("ʲː") for a in atoms[start:stress_at]]
        pos = stress_at
        if start == 0:
            pos = 0                 # the whole initial cluster: мно́го
            run = []
        for b in range(len(run)):
            if _ru_legal(run[b:]):
                pos = start + b
                break
        atoms.insert(pos, ("M", "ˈ"))
    return "".join(a[1] for a in atoms), guessed


# --- Modern Greek ------------------------------------------------------------

# Standard Modern Greek (monotonic spelling), broad, as the decks write it: ˈ
# before the stressed syllable of a word of two syllables or more (none on a
# word of one), ɾ for ρ, ɡ for γκ, ð θ for δ θ, ɣ for γ, ʝ for γ before a
# front vowel (the front vowels are ε η ι υ and the digraphs αι ει οι υι),
# x for χ, ps and ks for ψ and ξ. Vowels: α a, ε e, η ι υ i, ο ω o; digraphs
# αι e, ει οι υι i, ου u; αυ and ευ are av ev before a vowel or a voiced
# consonant and af ef elsewhere. A tonos on the first letter of a pair (άι,
# όυ) or a diaeresis (ϊ ϋ ΐ ΰ) keeps the two vowels apart. An unstressed ι,
# ει or οι after a consonant (or at the start of a word) and before a vowel is
# the glide j (μια mja, πιο pjo, ποιος pjos), and a ʝ absorbs it (για ʝa,
# γεια ʝa). Consonant groups: μπ is b at the start of a word and mb inside
# it, ντ d and nd, γκ ɡ and ŋɡ, γγ ŋɡ (ŋɣ before ν), γχ ŋx,
# γξ ŋks, τσ ts, τζ dz; a doubled consonant is single (ελληνικά eliniˈka); σ and ς are z before a voiced consonant (β γ δ ζ λ μ ν ρ, b d ɡ
# from μπ ντ γκ) and s elsewhere, inside a word only.
#
# Choices read off the cards already in decks/el: κ and χ are not
# palatalised (όχι ˈoxi, not ˈoçi), and the stress mark goes before the
# longest group of consonants that can begin a syllable (taˈksiði, ˈkrio,
# staθˈmos, kurazˈmenos).
#
# Sources: Wiktionary, "Appendix:Greek pronunciation" and en.wikipedia.org,
# "Modern Greek phonology" (the vowels and digraphs, the voicing of αυ ευ, the
# nasal-stop groups, the voicing of σ, ʝ before front vowels); the glide and
# the onset groups are the engine's own rules, read off the first cards.
#
# Stress is the written tonos. A word of one syllable is unstressed and
# needs none; a word of two or more with no tonos (or with two) is refused
# with CannotRead, never guessed. Known limits: loan words (μπ ντ in a
# foreign word are read as native), a word spelt with υ or η before a vowel
# without a tonos (δυο: refused), the glide is not made after a vowel,
# elision marks and capitals written without a tonos (refused), ancient and
# polytonic letters (refused), no assimilation across a word boundary.
# The reading is the course's own Latin scheme (naí, óchi, ch for χ), which
# is not computed: the stored reading (the hint) is echoed.

_EL_PUNCT = set(".,?!;:\"“”«»()…-–—·")
_EL_LETTERS = set("αβγδεζηθικλμνξοπρσςτυφχψω")
_EL_BASE = {"β": "v", "δ": "ð", "ζ": "z", "θ": "θ", "κ": "k", "λ": "l",
            "μ": "m", "ν": "n", "ξ": "ks", "π": "p", "ρ": "ɾ", "τ": "t",
            "φ": "f", "χ": "x", "ψ": "ps"}
_EL_VOWEL_IPA = {"α": "a", "ε": "e", "η": "i", "ι": "i", "ο": "o", "υ": "i",
                 "ω": "o"}
_EL_DIGRAPH = {"αι": "e", "ει": "i", "οι": "i", "υι": "i", "ου": "u"}
_EL_VOICED_START = set("bdɡvɣʝðzmnlɾŋ")
_EL_OBSTRUENT = set("pbtdkɡfvθðxɣ")
_EL_LIQUID = {"ɾ", "l", "j"}
_EL_STOPS = set("ptkbdɡ")
_EL_VOWELS = set("aeiou")
_EL_TONOS = "́"
_EL_DIAERESIS = "̈"


@dataclass
class _ElUnit:
    kind: str                   # "C" or "V"
    ipa: str
    stressed: bool = False
    glide: bool = False
    front: bool = False
    raw: str = ""               # a pending letter: "γ" or "σ"


def _el_check(text: str) -> None:
    for c in unicodedata.normalize("NFD", text.lower()):
        if (c.isspace() or c in _EL_PUNCT or c in _EL_LETTERS
                or c in (_EL_TONOS, _EL_DIAERESIS)):
            continue
        raise CannotRead(f"not a Modern Greek letter: {c!r}")


def _el_words(text: str) -> list[str]:
    return "".join(" " if c in _EL_PUNCT else c for c in text).split()


def _el_letters(word: str) -> list[list]:
    """A word as [letter, stressed, diaeresis] lists, from its decomposed
    form (ά is α and a tonos, ΐ is ι with a diaeresis and a tonos)."""
    out: list[list] = []
    for c in unicodedata.normalize("NFD", word):
        if c == _EL_TONOS:
            if not out:
                raise CannotRead(f"a tonos with no letter in {word!r}")
            out[-1][1] = True
        elif c == _EL_DIAERESIS:
            if not out:
                raise CannotRead(f"a diaeresis with no letter in {word!r}")
            out[-1][2] = True
        else:
            out.append([c, False, False])
    return out


def _el_units(word: str) -> list[_ElUnit]:
    """The word's sounds, before the context rules (γ, σ, αυ, ευ, glides)."""
    ls = _el_letters(word)
    units: list[_ElUnit] = []
    i, n = 0, len(ls)
    while i < n:
        c, st, dia = ls[i]
        nxt = ls[i + 1] if i + 1 < n else None
        if c in _EL_VOWEL_IPA:
            if (nxt and not st and not dia and not nxt[2]
                    and c + nxt[0] in _EL_DIGRAPH):
                ipa = _EL_DIGRAPH[c + nxt[0]]
                units.append(_ElUnit("V", ipa, nxt[1], front=ipa in "ei"))
                i += 2
            elif (nxt and not st and not dia and not nxt[2] and c in "αε"
                    and nxt[0] == "υ"):
                units.append(_ElUnit("V", _EL_VOWEL_IPA[c], nxt[1],
                                     front=c == "ε"))
                units.append(_ElUnit("C", "", raw="υ"))   # v or f, below
                i += 2
            else:
                ipa = _EL_VOWEL_IPA[c]
                units.append(_ElUnit("V", ipa, st, front=ipa in "ei"))
                i += 1
            continue
        pair = c + nxt[0] if nxt else ""
        if c == "μ" and pair == "μπ":
            units.append(_ElUnit("C", "b" if not units else "mb"))
            i += 2
        elif pair == "ντ":
            units.append(_ElUnit("C", "d" if not units else "nd"))
            i += 2
        elif pair == "γκ":
            units.append(_ElUnit("C", "ɡ" if not units else "ŋɡ"))
            i += 2
        elif pair == "γγ":
            units.append(_ElUnit("C", "", raw="γγ"))
            i += 2
        elif pair == "γχ":
            units.append(_ElUnit("C", "ŋx"))
            i += 2
        elif pair == "γξ":
            units.append(_ElUnit("C", "ŋks"))
            i += 2
        elif pair == "τσ":
            units.append(_ElUnit("C", "ts"))
            i += 2
        elif pair == "τζ":
            units.append(_ElUnit("C", "dz"))
            i += 2
        elif nxt and nxt[0] == c and (c in _EL_BASE or c == "σ"):
            i += 1                      # a doubled consonant is single
        elif c == "γ":
            units.append(_ElUnit("C", "", raw="γ"))
            i += 1
        elif c in "σς":
            units.append(_ElUnit("C", "", raw="σ"))
            i += 1
        else:
            units.append(_ElUnit("C", _EL_BASE[c]))
            i += 1
    return units


def _el_glides(units: list[_ElUnit]) -> None:
    """Mark an unstressed ι, ει or οι (a vowel unit of i) after a consonant
    or at the start of a word and before a vowel as a glide."""
    for k, u in enumerate(units):
        if (u.kind != "V" or u.ipa != "i" or u.stressed
                or k + 1 >= len(units)):
            continue
        if k and units[k - 1].kind != "C":
            continue
        if units[k + 1].kind != "V":
            continue
        u.glide = True
        u.ipa = "j"


def _el_context(units: list[_ElUnit]) -> None:
    """Resolve γ, γγ, σ, αυ and ευ from what follows."""
    n = len(units)
    for k, u in enumerate(units):
        nxt = units[k + 1] if k + 1 < n else None
        if u.raw == "γ":
            u.ipa = "ʝ" if nxt and nxt.kind == "V" and nxt.front else "ɣ"
        elif u.raw == "γγ":
            u.ipa = "ŋɣ" if nxt and nxt.ipa == "n" else "ŋɡ"
    # Voicing needs the sound after, so a second pass.
    for k, u in enumerate(units):
        nxt = units[k + 1] if k + 1 < n else None
        voiced = nxt is not None and (
            nxt.kind == "V"
            or (nxt.raw not in ("σ", "υ") and nxt.ipa[:1] in _EL_VOICED_START))
        if u.raw == "σ":
            u.ipa = "z" if (nxt is not None and nxt.kind == "C"
                            and voiced) else "s"
        elif u.raw == "υ":
            u.ipa = "v" if voiced else "f"


def _el_legal(cl: list[str]) -> bool:
    """Whether the sounds can begin a syllable together."""
    if len(cl) == 1:
        return True
    if len(cl) == 2:
        a, b = cl
        return ((a in _EL_OBSTRUENT and b in _EL_LIQUID)
                or (a in ("s", "z") and b in _EL_STOPS)
                or (a, b) == ("ɣ", "n"))
    if len(cl) == 3:
        return cl[0] == "s" and _el_legal(cl[1:])
    return False


def _el_sounds(units: list[_ElUnit]) -> tuple[list[str], int]:
    """The word's sounds one by one (ts dz ks ps stay whole, mb is m and b),
    and the index of the stressed vowel's sound (-1 if none)."""
    sounds: list[str] = []
    at = -1
    for k, u in enumerate(units):
        if u.glide and k and units[k - 1].ipa == "ʝ":
            continue                    # a ʝ takes the glide in: για ʝa
        if u.stressed:
            at = len(sounds)
        rest = u.ipa
        while rest:
            for whole in ("ks", "ps", "ts", "dz"):
                if rest.startswith(whole):
                    sounds.append(whole)
                    rest = rest[2:]
                    break
            else:
                sounds.append(rest[0])
                rest = rest[1:]
    return sounds, at


def _el_word(word: str) -> str:
    """The IPA of one word. Raises CannotRead for a word of two syllables or
    more with no tonos, or with two."""
    units = _el_units(word)
    _el_glides(units)
    _el_context(units)
    nuclei = [u for u in units if u.kind == "V" and not u.glide]
    marked = [u for u in nuclei if u.stressed]
    if len(marked) > 1:
        raise CannotRead(f"two tonos marks in {word!r}")
    if not marked and len(nuclei) > 1:
        raise CannotRead(f"no tonos on {word!r}: mark the stressed vowel")
    sounds, at = _el_sounds(units)
    if marked and len(nuclei) > 1:
        start = at
        while start > 0 and sounds[start - 1] not in _EL_VOWELS:
            start -= 1
        pos = at
        for b in range(start, at):
            if _el_legal(sounds[b:at]):
                pos = b
                break
        sounds.insert(0 if start == 0 else pos, "ˈ")
    return "".join(sounds)


def greek_ipa(text: str, hint: str | None = None) -> str:
    """Modern Greek, broad. The stress is the written tonos, so [hint] is
    not needed and is not used for the IPA. Raises CannotRead for a letter
    Greek spelling does not use, and for a word of two syllables or more
    without exactly one tonos."""
    text = unicodedata.normalize("NFC", text).lower()
    _el_check(text)
    return " ".join(w for w in (_el_word(w) for w in _el_words(text)) if w)


def _greek(text: str, hint: str | None) -> Transcription:
    return Transcription(hint or "", greek_ipa(text, hint), True)


# --- Japanese, Korean, Mandarin and Toki Pona (#612) -------------------------

class CannotRead(ValueError):
    """A text the tables cannot read: Han characters with no romanisation
    to go by, or a script with no table here."""


# Hiragana to (Hepburn without macrons, IPA), as the Japanese decks write
# them: long vowels are doubled (`ohayou`, `ookii`), ん is `n`.
_KANA = {
    "あ": ("a", "a"), "い": ("i", "i"), "う": ("u", "ɯ"), "え": ("e", "e"),
    "お": ("o", "o"),
    "か": ("ka", "ka"), "き": ("ki", "ki"), "く": ("ku", "kɯ"),
    "け": ("ke", "ke"), "こ": ("ko", "ko"),
    "さ": ("sa", "sa"), "し": ("shi", "ɕi"), "す": ("su", "sɯ"),
    "せ": ("se", "se"), "そ": ("so", "so"),
    "た": ("ta", "ta"), "ち": ("chi", "tɕi"), "つ": ("tsu", "tsɯ"),
    "て": ("te", "te"), "と": ("to", "to"),
    "な": ("na", "na"), "に": ("ni", "ni"), "ぬ": ("nu", "nɯ"),
    "ね": ("ne", "ne"), "の": ("no", "no"),
    "は": ("ha", "ha"), "ひ": ("hi", "çi"), "ふ": ("fu", "ɸɯ"),
    "へ": ("he", "he"), "ほ": ("ho", "ho"),
    "ま": ("ma", "ma"), "み": ("mi", "mi"), "む": ("mu", "mɯ"),
    "め": ("me", "me"), "も": ("mo", "mo"),
    "や": ("ya", "ja"), "ゆ": ("yu", "jɯ"), "よ": ("yo", "jo"),
    "ら": ("ra", "ɾa"), "り": ("ri", "ɾi"), "る": ("ru", "ɾɯ"),
    "れ": ("re", "ɾe"), "ろ": ("ro", "ɾo"),
    "わ": ("wa", "wa"), "を": ("o", "o"),
    "が": ("ga", "ɡa"), "ぎ": ("gi", "ɡi"), "ぐ": ("gu", "ɡɯ"),
    "げ": ("ge", "ɡe"), "ご": ("go", "ɡo"),
    "ざ": ("za", "dza"), "じ": ("ji", "dʑi"), "ず": ("zu", "dzɯ"),
    "ぜ": ("ze", "dze"), "ぞ": ("zo", "dzo"),
    "だ": ("da", "da"), "ぢ": ("ji", "dʑi"), "づ": ("zu", "dzɯ"),
    "で": ("de", "de"), "ど": ("do", "do"),
    "ば": ("ba", "ba"), "び": ("bi", "bi"), "ぶ": ("bu", "bɯ"),
    "べ": ("be", "be"), "ぼ": ("bo", "bo"),
    "ぱ": ("pa", "pa"), "ぴ": ("pi", "pi"), "ぷ": ("pu", "pɯ"),
    "ぺ": ("pe", "pe"), "ぽ": ("po", "po"),
    "ゔ": ("vu", "vɯ"),
}
_SMALL_VOWELS = {"ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o"}
_SMALL_IPA = {"a": "a", "i": "i", "u": "ɯ", "e": "e", "o": "o"}
_YOON = {"ゃ": "a", "ゅ": "u", "ょ": "o"}
_YOON_IPA = {"a": "a", "u": "ɯ", "o": "o"}
# The three letters Hepburn writes whole before a small ya, yu or yo.
_YOON_WHOLE = {"shi": ("sh", "ɕ"), "chi": ("ch", "tɕ"), "ji": ("j", "dʑ")}
_YOON_IPA_STEM = {"hi": "ç", "ni": "ɲ", "ri": "ɾj"}
_KANA_PUNCT = {"。": ".", "、": ",", "？": "?", "！": "!", "，": ",",
               "．": ".", "・": " ", "　": " ", "「": "'", "」": "'"}
_LONG = {("a", "a"), ("i", "i"), ("u", "u"), ("e", "e"), ("e", "i"),
         ("o", "o"), ("o", "u")}
_HAN = ((0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0xF900, 0xFAFF))


def kana_to_hiragana(text: str) -> str:
    """[text] with its katakana written as hiragana; ー is kept."""
    return "".join(chr(ord(c) - 0x60) if 0x30A1 <= ord(c) <= 0x30F6
                   else c for c in text)


def japanese(text: str) -> Transcription:
    """[text], in kana, as Hepburn letters without macrons and as IPA.

    Han characters cannot be read from their shape, so they raise
    CannotRead: the importer takes Wiktionary's romaji for them. は and へ
    are read `ha` and `he`; as particles they are `wa` and `e`, which only
    the sentence shows. ん is `n`, and `n'` before a vowel or y."""
    tokens: list[list[str]] = []      # [romaji, ipa, last vowel or ""]
    chars = list(kana_to_hiragana(text))
    sokuon = False
    i = 0
    while i < len(chars):
        c = chars[i]
        nxt = chars[i + 1] if i + 1 < len(chars) else ""
        if any(lo <= ord(c) <= hi for lo, hi in _HAN):
            raise CannotRead(text)
        if c in _KANA:
            rom, ipa = _KANA[c]
            if nxt in _YOON:
                v = _YOON[nxt]
                stem, ipa_stem = _YOON_WHOLE.get(
                    rom, (rom[:-1] + "y", _YOON_IPA_STEM.get(
                        # Hepburn's ASCII g must not leak into the IPA (#1428).
                        rom, rom[:-1].replace("g", "\u0261") + "j")))
                rom, ipa = stem + v, ipa_stem + _YOON_IPA[v]
                i += 1
            elif nxt in _SMALL_VOWELS:
                v = _SMALL_VOWELS[nxt]
                if rom == "u":
                    rom, ipa = "w" + v, "w" + _SMALL_IPA[v]
                else:
                    stem, ipa_stem = _YOON_WHOLE.get(
                        rom, (rom[:-1], ipa[:-1]))
                    rom, ipa = stem + v, ipa_stem + _SMALL_IPA[v]
                i += 1
            if sokuon:
                rom = ("t" if rom.startswith("ch") else rom[0]) + rom
                ipa = ipa[0] + ipa
                sokuon = False
            tokens.append([rom, ipa, rom[-1]])
        elif c == "っ":
            sokuon = True
        elif c == "ん":
            nxt_rom = _KANA.get(nxt, ("",))[0] if nxt else ""
            apostrophe = bool(nxt_rom) and nxt_rom[0] in "aiueoy" \
                or (nxt in _KANA and nxt_rom[:1] in "aiueoy")
            tokens.append(["n'" if apostrophe else "n", "ɴ", ""])
        elif c == "ー":
            if tokens and tokens[-1][2]:
                tokens[-1][0] += tokens[-1][2]
                tokens[-1][1] += "ː"
        elif c in _KANA_PUNCT:
            tokens.append([_KANA_PUNCT[c], "", ""])
        elif c.isascii() or c == " ":
            tokens.append([c, c if c.isalpha() or c == " " else "", ""])
        else:
            raise CannotRead(text)
        i += 1
    # A vowel after the same vowel, or o after u, is one long vowel.
    out: list[list[str]] = []
    for tok in tokens:
        prev = out[-1] if out else None
        if (prev and prev[2] and tok[0] in ("a", "i", "u", "e", "o")
                and (prev[2], tok[0]) in _LONG and not prev[1].endswith("ː")):
            prev[0] += tok[0]
            prev[1] += "ː"
            prev[2] = tok[0]
            continue
        out.append(tok)
    return Transcription("".join(t[0] for t in out).strip(),
                         "".join(t[1] for t in out).strip(), True)


# Revised Romanization of Korean. Initials, vowels and the sound each final
# letter has, in Unicode's order.
_HG_INITIAL = ["g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "",
               "j", "jj", "ch", "k", "t", "p", "h"]
_HG_VOWEL = ["a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae",
             "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"]
_HG_FINAL = ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ",
             "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ",
             "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
_HG_INITIAL_JAMO = ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
                    "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
# A final letter's parts, and how a single final letter is said at the end of
# a syllable.
_HG_PARTS = {"ㄳ": "ㄱㅅ", "ㄵ": "ㄴㅈ", "ㄶ": "ㄴㅎ", "ㄺ": "ㄹㄱ", "ㄻ": "ㄹㅁ",
             "ㄼ": "ㄹㅂ", "ㄽ": "ㄹㅅ", "ㄾ": "ㄹㅌ", "ㄿ": "ㄹㅍ", "ㅀ": "ㄹㅎ",
             "ㅄ": "ㅂㅅ"}
_HG_SAID = {"ㄲ": "ㄱ", "ㅋ": "ㄱ", "ㅅ": "ㄷ", "ㅆ": "ㄷ", "ㅈ": "ㄷ",
            "ㅊ": "ㄷ", "ㅌ": "ㄷ", "ㅍ": "ㅂ"}
_HG_CODA_ROM = {"ㄱ": "k", "ㄴ": "n", "ㄷ": "t", "ㄹ": "l", "ㅁ": "m",
                "ㅂ": "p", "ㅇ": "ng"}
_HG_ASPIRATE = {"ㄱ": "ㅋ", "ㄷ": "ㅌ", "ㅈ": "ㅊ", "ㅂ": "ㅍ"}
_HG_NASAL = {"ㄱ": "ㅇ", "ㄷ": "ㄴ", "ㅂ": "ㅁ"}
_HG_INITIAL_ROM = dict(zip(_HG_INITIAL_JAMO, _HG_INITIAL)) | {"ㅍ": "p"}


# Broad phonemic IPA of Standard (Seoul) Korean, written beside the reading.
# Sources, read 2026-11-26: Wikipedia "Korean phonology" (phoneme inventory,
# fortition after obstruents, nasalisation, lateralisation, vowels) and
# Wiktionary Module:ko-pron (which writes tense stops with the ͈ mark and the
# glides j w ɰ). Conventions, one only:
#  - phonemic, no brackets, no syllable dots; words separated by single spaces
#    as in the reading; punctuation is dropped;
#  - stops and affricates, three ways: plain k t p tɕ, tense k͈ t͈ p͈ t͈ɕ (the
#    combining ͈ U+0348, as Wikipedia writes them), aspirated kʰ tʰ pʰ tɕʰ;
#    sibilants s and s͈; ㅎ h. Voicing between sonorants ([ɡ d b dʑ]), [ɕ]
#    before i and j, and the ㅎ allophones are narrow detail and not written;
#  - ㄹ is ɾ before a vowel and l at the end of a syllable, ll when two meet
#    (신라 is silla, as the reading has it);
#  - ㅇ at the end of a syllable is ŋ; the unreleased finals [k̚ t̚ p̚] are
#    written as the plain phonemes k t p (broad), as is every coda;
#  - vowels: a ʌ o u ɯ i; ㅐ and ㅔ are both e (the Seoul merger Wikipedia
#    gives, [e̞]); ㅚ ㅙ ㅞ are we, ㅟ is wi (Wikipedia: mostly diphthongs now);
#    ㅢ is ɰi, and i after a consonant (Wikipedia: merges into [i]); the glides
#    are j and w (ㅑ ja, ㅕ jʌ, ㅘ wa, ㅝ wʌ ...);
#  - the sound changes of the reading apply (liaison, nasalisation, ㄹ's
#    changes, ㅎ's aspiration, cluster reduction), and an obstruent coda
#    (k t p) tenses a plain ㄱ ㄷ ㅂ ㅅ ㅈ that follows it, in the same word
#    (학교 hakk͈jo; Wikipedia: "/kt/ is pronounced [k̚t͈]"; ㅅ and ㅈ are in its
#    realisation table, not its prose). The reading does not write tensing.
# NOT handled (no source read, or not a letter-by-letter rule): tensing after
# a verb stem's ㄴ ㅁ (신다) and in compounds or after a Sino-Korean ㄹ
# (발달); ㄷ ㅌ + 이 palatalisation (같이 → 가치); ㅎ weakening between vowels;
# word-initial ㄹ said n or dropped (native) vs ɾ (loans); ㅢ as the particle
# "of" said e; ㅈ ㅉ ㅊ + glide (져 is tɕʌ, written tɕjʌ here); vowel length;
# ㄼ ㄺ ㄿ's second letter before a vowel-less suffix in particular words.
_HG_IPA_ONSET = {"ㄱ": "k", "ㄲ": "k͈", "ㄴ": "n", "ㄷ": "t", "ㄸ": "t͈",
                 "ㄹ": "ɾ", "ㅁ": "m", "ㅂ": "p", "ㅃ": "p͈", "ㅅ": "s",
                 "ㅆ": "s͈", "ㅇ": "", "ㅈ": "tɕ", "ㅉ": "t͈ɕ", "ㅊ": "tɕʰ",
                 "ㅋ": "kʰ", "ㅌ": "tʰ", "ㅍ": "pʰ", "ㅎ": "h"}
_HG_IPA_CODA = {"ㄱ": "k", "ㄴ": "n", "ㄷ": "t", "ㄹ": "l", "ㅁ": "m",
                "ㅂ": "p", "ㅇ": "ŋ", "ㅎ": "", "": ""}
_HG_IPA_TENSE = {"ㄱ": "ㄲ", "ㄷ": "ㄸ", "ㅂ": "ㅃ", "ㅅ": "ㅆ", "ㅈ": "ㅉ"}
# In _HG_VOWEL's order (ㅏ ㅐ ㅑ ㅒ ㅓ ㅔ ㅕ ㅖ ㅗ ㅘ ㅙ ㅚ ㅛ ㅜ ㅝ ㅞ ㅟ ㅠ ㅡ ㅢ ㅣ).
_HG_IPA_VOWEL = ["a", "e", "ja", "je", "ʌ", "e", "jʌ", "je", "o", "wa", "we",
                 "we", "jo", "u", "wʌ", "we", "wi", "ju", "ɯ", "ɰi", "i"]


def _hg_coda_said(final: str) -> str:
    """The one consonant letter a (possibly double) final letter is said as at
    the end of a syllable, by the same choices the reading makes."""
    parts = _HG_PARTS.get(final, final)
    if len(parts) == 2 and parts != "ㄹㅁ":
        parts = parts[0] if parts[0] != "ㄹ" or parts[1] in "ㅅㅌㅎ" else (
            "ㄱ" if parts == "ㄹㄱ" else "ㄹ" if parts == "ㄹㅂ" else "ㅂ")
    elif parts == "ㄹㅁ":
        parts = "ㅁ"
    return _HG_SAID.get(parts, parts)


def _hangul_word(word: str) -> str:
    """One word's Revised Romanization (see _hangul_word_both)."""
    return _hangul_word_both(word)[0]


def _hangul_word_both(word: str) -> tuple[str, str]:
    """A word's Revised Romanization and broad IPA, with the sound changes
    between its syllables: liaison (`한국어` hangugeo), nasalisation (`학문` hangmun),
    ㄹ's changes (`신라` silla, `종로` jongno) and ㅎ's (`좋다` jota). Tensing
    is not written, as the standard has it."""
    syl = []   # [initial jamo, vowel romanised, final jamo(s) or ""]
    vow = []   # each syllable's vowel index into _HG_VOWEL, None for others
    for ch in word:
        n = ord(ch) - 0xAC00
        if 0 <= n < 11172:
            syl.append([_HG_INITIAL_JAMO[n // 588],
                        _HG_VOWEL[n % 588 // 28], _HG_FINAL[n % 28]])
            vow.append(n % 588 // 28)
        else:
            syl.append([None, ch, ""])
            vow.append(None)
    for k in range(len(syl) - 1):
        a, b = syl[k], syl[k + 1]
        if a[0] is None or b[0] is None or not a[2]:
            continue
        coda = a[2]
        if b[0] == "ㅇ":
            if coda == "ㅇ":
                continue
            parts = _HG_PARTS.get(coda, coda)
            if parts[-1] == "ㅎ":
                parts = parts[:-1]
                a[2] = parts
                continue
            b[0] = parts[-1]
            a[2] = parts[:-1]
            continue
        parts = _HG_PARTS.get(coda, coda)
        if parts[-1] == "ㅎ" and b[0] in _HG_ASPIRATE:
            b[0] = _HG_ASPIRATE[b[0]]
            a[2] = parts[:-1]
            continue
        if b[0] == "ㅎ" and parts[-1] in _HG_ASPIRATE:
            b[0] = _HG_ASPIRATE[parts[-1]]
            a[2] = parts[:-1] if len(parts) > 1 else ""
            continue
        if len(parts) == 2 and parts not in ("ㄹㅁ",):
            # Of two final letters, the first is said, except ㄺ ㄻ ㄼ ㄿ's
            # second in some words; the standard's common case.
            parts = parts[0] if parts[0] != "ㄹ" or parts[1] in "ㅅㅌㅎ" else (
                "ㅁ" if parts == "ㄹㅁ" else "ㄱ" if parts == "ㄹㄱ" else
                "ㄹ" if parts == "ㄹㅂ" else "ㅂ")
        elif parts == "ㄹㅁ":
            parts = "ㅁ"
        coda = _HG_SAID.get(parts, parts)
        init = b[0]
        if init in ("ㄴ", "ㅁ") and coda in _HG_NASAL:
            coda = _HG_NASAL[coda]
        elif init == "ㄹ":
            if coda in ("ㅁ", "ㅇ"):
                b[0] = "ㄴ"
            elif coda in ("ㄱ", "ㅂ"):
                coda = _HG_NASAL[coda]
                b[0] = "ㄴ"
            elif coda == "ㄴ":
                coda = "ㄹ"
        elif init == "ㄴ" and coda == "ㄹ":
            b[0] = "ㄹ"
        a[2] = coda
    out = []
    ipa = []
    for k, (init, vowel, final) in enumerate(syl):
        if init is None:
            out.append(vowel)
            if not unicodedata.category(vowel).startswith("P"):
                ipa.append(vowel)
            continue
        rom = _HG_INITIAL_ROM[init]
        after_l = bool(k and syl[k - 1][2] == "ㄹ")
        if init == "ㄹ" and after_l:
            rom = "l"
        out.append(rom + vowel)
        for jamo in _HG_PARTS.get(final, final):
            jamo = _HG_SAID.get(jamo, jamo)
            out.append(_HG_CODA_ROM.get(jamo, ""))
        # The IPA: tense a plain onset after an obstruent coda of the
        # syllable before, ㄹㄹ is ll, ㅢ after a consonant is i.
        onset = init
        prev_coda = (_hg_coda_said(syl[k - 1][2])
                     if k and syl[k - 1][0] is not None else "")
        if prev_coda in ("ㄱ", "ㄷ", "ㅂ") and onset in _HG_IPA_TENSE:
            onset = _HG_IPA_TENSE[onset]
        sound = _HG_IPA_ONSET[onset]
        if onset == "ㄹ" and after_l:
            sound = "l"
        v = vow[k]
        vsound = "i" if v == 19 and onset != "ㅇ" else _HG_IPA_VOWEL[v]
        ipa.append(sound + vsound + _HG_IPA_CODA[_hg_coda_said(final)])
    return "".join(out), "".join(ipa)


def korean(text: str) -> Transcription:
    """[text] in Hangul, in the Revised Romanization the Korean decks use.
    Spaces end a word: no change runs across them."""
    if any(ord(c) > 0x7F and not 0xAC00 <= ord(c) <= 0xD7A3
           and not unicodedata.category(c).startswith("P") for c in text):
        raise CannotRead(text)
    both = [_hangul_word_both(w) for w in text.split(" ")]
    return Transcription(" ".join(r for r, _ in both),
                         " ".join(i for _, i in both if i), True)


# --- Mandarin ----------------------------------------------------------------

# Pinyin cannot be derived from characters, so a card's reading is the hint
# (Wiktionary's pinyin with tone marks, as it was given; sandhi is not
# applied, a card writes the citation tones except 不 and 一, written as said).
# The broad IPA is derived from that pinyin, deterministically, by the tables
# below (wiki: Deck-Work-Queue-ZH, section 4). Conventions:
#  - phonemic, no brackets, no tie bars, no syllable dots; a pinyin word is one
#    IPA word and the words stay separated by single spaces, as in the reading;
#    punctuation is dropped (`,` `.` `?` and the like), as in the other courses;
#  - every syllable ends in its tone, so the string is unambiguous without
#    dots: Chao tone letters for the citation tones (1 ˥˥, 2 ˧˥, 3 ˨˩˦,
#    4 ˥˩), as the Cantonese and Vietnamese decks do, and ˙ (U+02D9, the
#    light-tone mark) for the neutral tone, whose pitch depends on the tone
#    before it (the narrow rules give it one);
#  - initials: b p m f d t n l g k h = p pʰ m f t tʰ n l k kʰ x, j q x = tɕ
#    tɕʰ ɕ, zh ch sh = ʈʂ ʈʂʰ ʂ, r = ɻ, z c s = ts tsʰ s (Wikipedia, Standard
#    Chinese phonology: r is [ʐ ~ ɻ]; the broad form takes ɻ);
#  - the apical "vowels" of zhi chi shi ri zi ci si are written ɨ (the
#    alternative analysis Wikipedia gives); the narrow rules make them ɹ̩ and ɻ̩;
#  - e is ɤ, and ə in a neutral-tone syllable (de, le, me); ê is ɛ; en eng are
#    ən əŋ; ong is ʊŋ; ie üe ian üan have ɛ; ai ei ao ou are ai ei au ou;
#  - the glides are j w ɥ: ya ye you yan = ja jɛ jou jɛn, wo wei wen = wo wei
#    wən, yue yuan = ɥɛ ɥɛn; y and w are spellings, not sounds;
#  - the spellings are undone first: ü is written u after j q x y (ju qu xu
#    yu), uo is written o after b p m f (bo = pwo), and iu ui un are iou uei
#    uen (yin ying and jin are in iŋ... as written);
#  - erhua (a final r, 花儿 huār) follows Wikipedia, Erhua: the coda i or n is
#    deleted, ŋ nasalises the vowel, and the rhotic ɻ or ɚ ends the syllable
#    (shìr = ʂɚ˥˩); the standalone syllable er is ɚ.
ZH_INITIALS = ("zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g",
               "k", "h", "j", "q", "x", "r", "z", "c", "s", "y", "w")
ZH_INITIAL_IPA = {
    "b": "p", "p": "pʰ", "m": "m", "f": "f", "d": "t", "t": "tʰ", "n": "n",
    "l": "l", "g": "k", "k": "kʰ", "h": "x", "j": "tɕ", "q": "tɕʰ",
    "x": "ɕ", "zh": "ʈʂ", "ch": "ʈʂʰ", "sh": "ʂ", "r": "ɻ", "z": "ts",
    "c": "tsʰ", "s": "s", "": "",
}
# The full (unabbreviated) finals, with y and w and the shortenings undone.
ZH_FINAL_IPA = {
    "a": "a", "o": "o", "e": "ɤ", "ê": "ɛ", "ai": "ai", "ei": "ei",
    "ao": "au", "ou": "ou", "an": "an", "en": "ən", "ang": "aŋ",
    "eng": "əŋ", "ong": "ʊŋ", "er": "ɚ",
    "i": "i", "ia": "ja", "ie": "jɛ", "iao": "jau", "iou": "jou",
    "ian": "jɛn", "in": "in", "iang": "jaŋ", "ing": "iŋ", "iong": "jʊŋ",
    "u": "u", "ua": "wa", "uo": "wo", "uai": "wai", "uei": "wei",
    "uan": "wan", "uen": "wən", "uang": "waŋ", "ueng": "wəŋ",
    "ü": "y", "üe": "ɥɛ", "üan": "ɥɛn", "ün": "yn",
    "io": "jo",
}
# The same finals said with a final r (Wikipedia, Erhua, its chart with the
# rhotic mark ʵ written ɻ). The apical i is handled apart (ɚ).
ZH_ERHUA_IPA = {
    "a": "aɻ", "o": "oɻ", "e": "ɤɻ", "ai": "ɐɻ", "ei": "ɚ", "ao": "auɻ",
    "ou": "ouɻ", "an": "ɐɻ", "en": "ɚ", "ang": "ɑ̃ɻ",
    "eng": "ɤ̃ɻ", "i": "jɚ", "ia": "jaɻ", "ie": "jɛɻ", "iao": "jauɻ",
    "iou": "jouɻ", "ian": "jɐɻ", "in": "jɚ", "iang": "jɑ̃ɻ",
    "ing": "jɤ̃ɻ", "u": "uɻ", "ua": "waɻ", "uo": "woɻ", "uai": "wɐɻ",
    "uei": "wɚ", "uan": "wɐɻ", "uen": "wɚ", "uang": "wɑ̃ɻ",
    "ong": "ʊ̃ɻ", "ü": "ɥɚ", "üe": "ɥɛɻ", "üan": "ɥɐɻ", "ün": "ɥɚ",
    "iong": "jʊ̃ɻ", "er": "ɚ", "ê": "ɛɻ",
}
ZH_TONE_LETTERS = {1: "˥˥", 2: "˧˥", 3: "˨˩˦", 4: "˥˩", 0: "˙"}
ZH_TONE_MARKS = {"̄": 1, "́": 2, "̌": 3, "̀": 4}
ZH_APICAL = ("zh", "ch", "sh", "r", "z", "c", "s")
ZH_PUNCT = ".,;:!?…\"“”‘’()[]、，。！？；：—-"


def _zh_full_final(initial: str, written: str) -> tuple[str, str] | None:
    """The (initial, full final) a written pinyin syllable [initial]+[written]
    is, with the spellings undone, or None when the final is not one."""
    if initial == "y":
        # yi yin ying keep their i; ya ye yao you yan yang yong yo add it; yu
        # yue yuan yun are ü.
        if written[:1] == "i":
            full = written
        elif written[:1] in ("u", "ü"):
            full = "ü" + written[1:]
        else:
            full = "i" + written
        initial = ""
    elif initial == "w":
        full = written if written == "u" else "u" + written
        initial = ""
    elif initial in ("j", "q", "x") and written[:1] in ("u", "ü"):
        full = "ü" + written[1:]        # ju jue juan jun
    elif initial in ("b", "p", "m", "f") and written == "o":
        full = "uo"                     # bo is pwo
    else:
        full = written
        if initial and full in ("iu", "ui", "un"):
            full = {"iu": "iou", "ui": "uei", "un": "uen"}[full]
    if full == "er" and initial:
        return None                     # er is a syllable of its own: ger is g + er
    return (initial, full) if full in ZH_FINAL_IPA else None


def _zh_segment(letters: list[str], i: int, first: bool
                ) -> list[tuple[int, int, str, str]] | None:
    """The syllables (start, end, initial, full final) of letters[i:], longest
    syllable first, or None. Only a word's first syllable, or one after an
    apostrophe, may begin with a vowel: `dangan` is dan gan, `xi'an` xi an."""
    if i == len(letters):
        return []
    if letters[i] == "'":
        return _zh_segment(letters, i + 1, True)
    for end in range(min(len(letters), i + 6), i, -1):
        piece = "".join(letters[i:end])
        if "'" in piece:
            continue
        for initial in ZH_INITIALS + ("",):
            if initial and not piece.startswith(initial):
                continue
            if not initial and not first:
                continue
            written = piece[len(initial):]
            if not written:
                continue
            found = _zh_full_final(initial, written)
            if found is None:
                continue
            rest = _zh_segment(letters, end, False)
            if rest is not None:
                return [(i, end, found[0], found[1])] + rest
    return None


def _zh_word_ipa(word: str) -> str:
    """The broad IPA of one pinyin word (no spaces), or ValueError."""
    letters: list[str] = []
    tone_at: dict[int, int] = {}
    word = word.replace("\u2019", "'")
    for ch in unicodedata.normalize("NFD", word.lower()):
        if ch in ZH_TONE_MARKS:
            if not letters:
                raise ValueError(word)
            tone_at[len(letters) - 1] = ZH_TONE_MARKS[ch]
        elif ch == "̈" and letters and letters[-1] == "u":
            letters[-1] = "ü"
        elif ch == "̂" and letters and letters[-1] == "e":
            letters[-1] = "ê"
        elif ch == "'" or ("a" <= ch <= "z"):
            letters.append(ch)
        else:
            raise ValueError(word)
    erhua = False
    syllables = _zh_segment(letters, 0, True)
    if syllables is None and letters[-1:] == ["r"] and len(letters) > 1:
        syllables = _zh_segment(letters[:-1], 0, True)
        erhua = syllables is not None
    if not syllables:
        raise ValueError(word)
    out = []
    for n, (a, b, initial, final) in enumerate(syllables):
        tone = next((t for k, t in tone_at.items() if a <= k < b), 0)
        if erhua and n == len(syllables) - 1:
            if final == "i" and initial in ZH_APICAL:
                nucleus = "ɚ"
            elif final in ZH_ERHUA_IPA:
                nucleus = ZH_ERHUA_IPA[final]
            else:
                raise ValueError(word)
        elif final == "i" and initial in ZH_APICAL:
            nucleus = "ɨ"
        elif final == "e" and tone == 0:
            nucleus = "ə"
        else:
            nucleus = ZH_FINAL_IPA[final]
        out.append(ZH_INITIAL_IPA[initial] + nucleus + ZH_TONE_LETTERS[tone])
    return "".join(out)


def mandarin_ipa(pinyin: str) -> str:
    """The broad IPA of [pinyin] (tone-marked, words separated by spaces),
    punctuation dropped; ValueError naming the word it cannot read."""
    words = []
    for token in unicodedata.normalize("NFC", pinyin).split():
        token = token.strip(ZH_PUNCT)
        if token:
            words.append(_zh_word_ipa(token))
    return unicodedata.normalize("NFC", " ".join(words))


def mandarin(text: str, hint: str | None) -> Transcription:
    """Pinyin cannot be derived from characters, so the reading is the hint's:
    Wiktionary's, with its tone marks, as it was given. Sandhi is not
    applied; a card writes the citation tones. The broad IPA is derived from
    that pinyin (`mandarin_ipa`); a pinyin it cannot read gives an empty IPA,
    `fitted` false and a note naming the word. The narrow IPA (the `phonetic`
    field) is not made here: tools/derive_phonetic.py writes it from the broad
    IPA by decks/zh/zh-phonetics.yaml."""
    if not hint or not hint.strip():
        raise CannotRead(text)
    reading = unicodedata.normalize("NFC", hint.strip())
    try:
        return Transcription(reading, mandarin_ipa(reading), True)
    except ValueError as e:
        return Transcription(reading, "", False,
                             [f"pinyin not read: {e}"])


def toki_pona(text: str) -> Transcription:
    """Toki Pona is written as it is said: no reading is needed, and its
    IPA puts stress on the first syllable of a word of two or more. The
    letters are the IPA's, except that a capital marks a name."""
    out = []
    for w in re.findall(r"[^\W\d_]+", text.lower()):
        vowels = sum(c in "aeiou" for c in w)
        out.append(("ˈ" if vowels > 1 else "") + w)
    return Transcription(text, " ".join(out), True)


# --- Malayalam ---------------------------------------------------------------

# Malayalam is written as it is said, so it is read from its letters with no
# hint (the hint is ignored). The decks' conventions, from the Malayalam
# decks and their review queue:
#  - a geminate (ക്ക, ത്ത, ന്ന) is written and said doubled: kk, tt, nn;
#    a vowel is long (ː) where it is written long, and a consonant never is;
#  - the inherent vowel is written a and said [ə], except when it is the
#    word's last vowel, which is [a]; the vowel-less ് ending a word
#    (samvruthokaram) is not written or said;
#  - ṇ is [ɳ], ṟ and r are the tap [ɾ], ḻ is [ɻ], ḷ is [ɭ], ന is n and the
#    chillu ൻ is ṉ, also [n]; ം is ṁ, said [m];
#  - ന്റ is nṟ, said [nt̪ɾ]; റ്റ is ṟṟ, said [tt]; after സ് (സ്റ്റ, as
#    in English st) it is ṭ, said [ʈ].
ML_VOWEL_SIGNS = {"S", "V", "I"}


def malayalam(text: str, hint: str | None = None) -> Transcription:
    """[text]'s reading and broad IPA, by Malayalam's letters. The narrow
    IPA (the `phonetic` field) is not made here: tools/derive_phonetic.py
    writes it from the broad IPA by the language's rules file. The one
    thing the letters do not say is whether ഫ is [pʰ] or [f], as it is in
    words from English: a hint that has an f for it makes it f."""
    units = parse(text, "ml")
    words: list[list[Unit]] = [[]]
    for u in units:
        if u.kind == "SP":
            words.append([])
        else:
            words[-1].append(u)
    hints = (hint or "").lower().split()
    if len(hints) != len(words):
        hints = [""] * len(words)
    out_iso: list[str] = []
    out_ipa: list[str] = []
    for word, typed in zip(words, hints):
        if "f" in typed:
            for u in word:
                if u.kind == "C" and u.letter == "ph":
                    u.fixed = ("f", "f", ["f"])
        iso, ipa = _malayalam_word(word)
        out_iso.append(iso)
        if ipa:
            out_ipa.append(ipa)
    reading = _tidy(" ".join(out_iso))
    return Transcription(
        reading, unicodedata.normalize("NFC", " ".join(out_ipa)), True)


def _malayalam_word(units: list[Unit]) -> tuple[str, str]:
    # The word's last vowel keeps its [a]; earlier inherent vowels are [ə].
    last = max((k for k, u in enumerate(units) if u.kind in ML_VOWEL_SIGNS),
               default=-1)
    iso: list[str] = []
    ipa: list[str] = []
    skip_next = False
    for k, u in enumerate(units):
        if skip_next:
            skip_next = False
            continue
        nxt = units[k + 1] if k + 1 < len(units) else None
        prev = units[k - 1] if k > 0 else None
        if u.kind == "C":
            i_iso, i_ipa = (u.fixed[0], u.fixed[1]) if u.fixed else \
                consonant(u.letter, "ml")
            joined = nxt is not None and nxt.kind == "C"
            if joined and nxt.letter == u.letter and u.letter.endswith("h"):
                # ഖ്ഖ, a held kh, is said kkh.
                i_iso, i_ipa = i_iso[:-1], i_ipa.rstrip("ʰʱ")
            if joined and u.letter == "ṟ" and nxt.letter == "ṟ":
                if prev is not None and prev.kind == "C" and \
                        prev.letter == "s":
                    # സ്റ്റ: st, as in station.
                    iso.append("ṭ")
                    ipa.append("ʈ")
                    skip_next = True
                    continue
                i_ipa = "t"
            elif u.letter == "ṟ" and prev is not None and \
                    prev.kind == "C" and prev.letter == "ṟ":
                i_ipa = "t"
            elif u.letter == "ch" and prev is not None and \
                    prev.kind == "C" and prev.letter == "c":
                # ച്ഛ (acchan) is said as a held ച, with no breath.
                i_ipa = "tʃ"
            elif u.letter == "ṟ" and prev is not None and \
                    prev.kind == "C" and prev.letter == "n":
                # ന്റ: a stop and a tap after the n.
                i_ipa = "t̪ɾ"
            iso.append(i_iso)
            ipa.append(i_ipa)
        elif u.kind in ("V", "S", "I"):
            letter = "a" if u.kind == "I" else u.letter
            i_iso, i_ipa = VOWEL_TABLES["ml"][letter]
            if letter == "a" and k == last:
                i_ipa = "a"
            iso.append(i_iso)
            ipa.append(i_ipa)
        elif u.kind == "N":
            iso.append("ṁ")
            ipa.append("m")
        elif u.kind == "H":
            iso.append("ḥ")
            ipa.append("h")
        elif u.kind == "P":
            iso.append(u.letter if u.letter not in "'\"" else "'")
    return "".join(iso), "".join(ipa)


# --- Tamil -------------------------------------------------------------------

# Tamil is written as it is said, so it is read from its letters with no hint.
# The decks' conventions (decks/ta):
#  - the pulli ் ends a consonant; there are no ligatures, so a cluster is
#    just consonants in a row, and a geminate is written and said doubled;
#  - க ச ட த ப are written k c ṭ t p and said voiceless: the voiced or
#    fricative sounds between vowels are the narrow IPA's, not the broad;
#  - ச is [s], but [tʃ] after a stop or a nasal (cc, ñc, ṉc, ṭc), and ஜ
#    is [dʒ];
#  - ற is ṟ [r] and ர r [ɾ]; ன ṉ and ந n are both [n]; ழ ḻ [ɻ], ள ḷ [ɭ];
#  - a word-final ம் is m (not ṁ: it is a consonant, not an anusvara);
#  - ஃ (aytam) is ḵ, said [x].


TA_STOPS_NASALS = {"k", "c", "ṭ", "t", "p", "ṅ", "ñ", "ṇ", "n", "ṉ", "m"}


def tamil(text: str) -> Transcription:
    """[text]'s reading and broad IPA, by Tamil's letters."""
    units = parse(text, "ta")
    iso: list[str] = []
    ipa: list[str] = []
    for k, u in enumerate(units):
        prev = units[k - 1] if k > 0 else None
        if u.kind == "C":
            i_iso, i_ipa = consonant(u.letter, "ta")
            if u.letter == "c":
                nxt = units[k + 1] if k + 1 < len(units) else None
                if (prev is not None and prev.kind == "C" and
                        prev.letter in TA_STOPS_NASALS) or \
                        (nxt is not None and nxt.kind == "C" and
                         nxt.letter == "c"):
                    i_ipa = "tʃ"
            iso.append(i_iso)
            ipa.append(i_ipa)
        elif u.kind in ("V", "S", "I"):
            i_iso, i_ipa = VOWEL_TABLES["ta"]["a" if u.kind == "I"
                                              else u.letter]
            iso.append(i_iso)
            ipa.append(i_ipa)
        elif u.kind == "N":
            iso.append("ṁ")
            ipa.append("m")
        elif u.kind == "H":
            iso.append("ḵ")
            ipa.append("x")
        elif u.kind == "SP":
            iso.append(" ")
            ipa.append(" ")
        elif u.kind == "P":
            iso.append(u.letter if u.letter not in "'\"" else "'")
    return Transcription(
        _tidy("".join(iso)),
        unicodedata.normalize("NFC", " ".join("".join(ipa).split())), True)


# --- Santali (Ol Chiki) ------------------------------------------------------

# Ol Chiki (U+1C50-1C7F) is an alphabet, not an abugida: every letter is a
# consonant or a vowel, there is no inherent vowel, and a word is read letter
# for letter. Letter values are Wiktionary's Santali letter pages (the sound
# of each letter and its Latin name: lô, ôt, ôk', iñ, eṛ, ...), and the marks
# are the glosses of Wiktionary's mark pages; none is guessed. Readings are
# Latin letters based on ISO 15919, as the Santali cards write them:
#  - ᱚ (LA) is ô, written o̠ (o and U+0320) and said [ɔ]; ᱳ is o [o]; ᱮ is e
#    [e]; ᱟ ᱤ ᱩ are a i u;
#  - ᱸ (mu ttuddag) nasalises the vowel before it (a tilde: hẽ); ᱹ (gahla
#    ttuddag) and ᱻ (relaa) extend it (a macron: ā, [aː]); ᱺ (mu-gahla
#    ttuddag) does both (ā̃);
#  - ᱜ ᱫ ᱵ ᱡ are g d b j, but at the end of a word (or with ᱼ phaarkaa) they
#    are the checked stops k' t' p' c', said [k t p tʃ], the glottal stop
#    written ' as the cards do (dak', mit', ac'); ᱽ (ahad) keeps the plain
#    value at the end of a word;
#  - ᱷ after a stop is its aspiration (bh dh kh), [ʱ] after a voiced stop and
#    [ʰ] after a voiceless one; ᱪ is c [tʃ], ᱡ is j [dʒ], ᱝ is ṅ, ᱧ is ñ,
#    ᱬ is ṇ, ᱰ is ḍ, ᱴ is ṭ, ᱲ is ṛ [ɽ], ᱭ is y [j], ᱶ is w̃;
#  - a digit is read as the digit and has no IPA: Wiktionary gives no name for
#    any digit; ᱾ and ᱿ are written as a full stop.
SAT_VOWELS = {
    "ᱚ": ("o̠", "ɔ"), "ᱟ": ("a", "a"), "ᱤ": ("i", "i"),
    "ᱩ": ("u", "u"), "ᱮ": ("e", "e"), "ᱳ": ("o", "o")}
SAT_CONSONANTS = {
    "ᱛ": ("t", "t"), "ᱝ": ("ṅ", "ŋ"), "ᱞ": ("l", "l"), "ᱠ": ("k", "k"),
    "ᱢ": ("m", "m"), "ᱣ": ("w", "w"), "ᱥ": ("s", "s"), "ᱦ": ("h", "h"),
    "ᱧ": ("ñ", "ɲ"), "ᱨ": ("r", "r"), "ᱪ": ("c", "tʃ"), "ᱬ": ("ṇ", "ɳ"),
    "ᱭ": ("y", "j"), "ᱯ": ("p", "p"), "ᱰ": ("ḍ", "ɖ"), "ᱱ": ("n", "n"),
    "ᱲ": ("ṛ", "ɽ"), "ᱴ": ("ṭ", "ʈ"), "ᱶ": ("w̃", "w̃"), "ᱷ": ("h", "ʰ")}
# ᱜ ᱫ ᱵ ᱡ: (plain reading, checked reading, plain IPA, checked IPA).
SAT_CHECKABLE = {
    "ᱜ": ("g", "k'", "ɡ", "k"), "ᱫ": ("d", "t'", "d", "t"),
    "ᱵ": ("b", "p'", "b", "p"), "ᱡ": ("j", "c'", "dʒ", "tʃ")}
SAT_VOICED = set(SAT_CHECKABLE) | {"ᱰ"}
SAT_ASPIRABLE = SAT_VOICED | {"ᱠ", "ᱛ", "ᱯ", "ᱪ", "ᱴ"}
SAT_NASAL, SAT_LONG, SAT_NASAL_LONG, SAT_RELAA = "ᱸ", "ᱹ", "ᱺ", "ᱻ"
SAT_PHAARKAA, SAT_AHAD = "ᱼ", "ᱽ"
SAT_STOPS = {"᱾": ".", "᱿": "."}


def santali(text: str) -> Transcription:
    """[text]'s reading and broad IPA, by Ol Chiki's letters. The narrow IPA
    (the `phonetic` field) is not made here. Raises CannotRead on a letter
    or mark out of place (a mark with nothing to attach to)."""
    out_iso: list[str] = []
    out_ipa: list[str] = []
    notes: list[str] = []
    for word in unicodedata.normalize("NFC", text).split():
        iso, ipa, digits = _santali_word(word)
        out_iso.append(iso)
        if ipa:
            out_ipa.append(ipa)
        if digits and not notes:
            notes.append("a digit is read as the digit; Wiktionary gives no "
                         "name for it, so it has no IPA")
    return Transcription(_tidy(" ".join(out_iso)),
                         unicodedata.normalize("NFC", " ".join(out_ipa)),
                         True, notes)


def _santali_word(word: str) -> tuple[str, str, bool]:
    # Pass one: letters and marks to units. A unit is a list:
    # [kind, letter, long, nasal, mode]; kind V vowel, C consonant, D digit,
    # P punctuation; mode is "", "keep" (ᱼ) or "plain" (ᱽ).
    units: list[list] = []
    for c in word:
        prev = units[-1] if units else None
        if c in SAT_VOWELS:
            units.append(["V", c, False, False, ""])
        elif c in SAT_CONSONANTS or c in SAT_CHECKABLE:
            units.append(["C", c, False, False, ""])
        elif c in (SAT_NASAL, SAT_LONG, SAT_NASAL_LONG, SAT_RELAA):
            if prev is None or prev[0] != "V":
                raise CannotRead(f"{c!r} must follow an Ol Chiki vowel")
            if c in (SAT_NASAL, SAT_NASAL_LONG):
                prev[3] = True
            if c != SAT_NASAL:
                prev[2] = True
        elif c in (SAT_PHAARKAA, SAT_AHAD):
            if prev is None or prev[0] != "C" or prev[1] not in SAT_CHECKABLE:
                raise CannotRead(f"{c!r} must follow ᱜ, ᱫ, ᱵ or ᱡ")
            prev[4] = "keep" if c == SAT_PHAARKAA else "plain"
        elif 0x1C50 <= ord(c) <= 0x1C59:
            units.append(["D", str(ord(c) - 0x1C50), False, False, ""])
        elif c in SAT_STOPS:
            units.append(["P", SAT_STOPS[c], False, False, ""])
        elif c in ".,?!;:'\"()-":
            units.append(["P", c, False, False, ""])
        else:
            raise CannotRead(f"cannot read {c!r} as Santali")
    # Pass two: render.
    iso: list[str] = []
    ipa: list[str] = []
    for k, (kind, c, long, nasal, mode) in enumerate(units):
        prev = units[k - 1] if k > 0 else None
        nxt = units[k + 1] if k + 1 < len(units) else None
        if kind == "V":
            i_iso, i_ipa = SAT_VOWELS[c]
            if long:
                i_iso += "̄"
            if nasal:
                i_iso += "̃"
                i_ipa += "̃"
            if long:
                i_ipa += "ː"
            iso.append(i_iso)
            ipa.append(i_ipa)
        elif kind == "C" and c in SAT_CHECKABLE:
            p_iso, c_iso, p_ipa, c_ipa = SAT_CHECKABLE[c]
            final = nxt is None or nxt[0] in ("P", "D")
            if mode == "keep" or (final and mode != "plain"):
                iso.append(c_iso)
                ipa.append(c_ipa)
            else:
                iso.append(p_iso)
                ipa.append(p_ipa)
        elif kind == "C":
            i_iso, i_ipa = SAT_CONSONANTS[c]
            if c == "ᱷ" and prev is not None and prev[0] == "C" and \
                    prev[1] in SAT_ASPIRABLE:
                i_ipa = "ʱ" if prev[1] in SAT_VOICED else "ʰ"
            iso.append(i_iso)
            ipa.append(i_ipa)
        else:
            iso.append(c)
    digits = any(u[0] == "D" for u in units)
    return "".join(iso), "".join(ipa), digits


# --- Classical Sanskrit ------------------------------------------------------

# Classical (sa) and Vedic (vsn) Sanskrit are read from their letters alone, in
# IAST, as the Vedic course does: ṃ ḥ ṛ ṝ ḷ ś ṣ and long vowels with macrons. This departs from ISO 15919
# in four letters (ṃ for ṁ, ṛ ṝ ḷ for r̥ r̥̄ l̥, e o for ē ō); see
# wiki/Readings-ISO-15919.md. Every inherent a is said, word-final included
# (no Hindi schwa deletion), so the engine takes no hint: the letters are the
# whole reading. The IPA is broad and follows the house Indic choices: short a
# [ə], c j as [tʃ dʒ], ś [ʃ] and ṣ [ʂ] and s kept apart, aspirated stops,
# retroflexes, dentals t̪ d̪, v as ʋ, no tie bars. Vedic accent marks are never
# in the reading or the IPA; each is reported in `Transcription.notes`.
SA_VOWELS = {
    0x05: "a", 0x06: "ā", 0x07: "i", 0x08: "ī", 0x09: "u", 0x0A: "ū",
    0x0B: "ṛ", 0x60: "ṝ", 0x0C: "ḷ", 0x61: "ḹ", 0x0F: "e", 0x10: "ai",
    0x13: "o", 0x14: "au"}
SA_SIGNS = {
    0x3E: "ā", 0x3F: "i", 0x40: "ī", 0x41: "u", 0x42: "ū", 0x43: "ṛ",
    0x44: "ṝ", 0x62: "ḷ", 0x63: "ḹ", 0x47: "e", 0x48: "ai", 0x4B: "o",
    0x4C: "au"}
# A vowel's IAST letter to its broad IPA. Short a is the central [ɐ], long
# ā [aː]; e and o are always long; ai and au are diphthongs.
SA_VOWEL_IPA = {
    "a": "ə", "ā": "aː", "i": "i", "ī": "iː", "u": "u", "ū": "uː",
    "ṛ": "r̩", "ṝ": "r̩ː", "ḷ": "l̩", "ḹ": "l̩ː",
    "e": "eː", "ai": "əi", "o": "oː", "au": "əu"}
# Vedic ai and au are long diphthongs, āi and āu (Macdonell 1916, pp. 4-5; to
# be pinned by the Vedic sourcing task).
SA_VEDIC_DIPHTHONGS = {"ai": "aːi", "au": "aːu"}
SA_CONSONANTS = {
    0x15: "k", 0x16: "kh", 0x17: "g", 0x18: "gh", 0x19: "ṅ",
    0x1A: "c", 0x1B: "ch", 0x1C: "j", 0x1D: "jh", 0x1E: "ñ",
    0x1F: "ṭ", 0x20: "ṭh", 0x21: "ḍ", 0x22: "ḍh", 0x23: "ṇ",
    0x24: "t", 0x25: "th", 0x26: "d", 0x27: "dh", 0x28: "n",
    0x2A: "p", 0x2B: "ph", 0x2C: "b", 0x2D: "bh", 0x2E: "m",
    0x2F: "y", 0x30: "r", 0x32: "l", 0x35: "v",
    0x36: "ś", 0x37: "ṣ", 0x38: "s", 0x39: "h"}
SA_CONSONANT_IPA = {
    "k": "k", "kh": "kʰ", "g": "ɡ", "gh": "ɡʱ", "ṅ": "ŋ",
    "c": "tʃ", "ch": "tʃʰ", "j": "dʒ", "jh": "dʒʱ", "ñ": "ɲ",
    "ṭ": "ʈ", "ṭh": "ʈʰ", "ḍ": "ɖ", "ḍh": "ɖʱ", "ṇ": "ɳ",
    "t": "t̪", "th": "t̪ʰ", "d": "d̪", "dh": "d̪ʱ", "n": "n",
    "p": "p", "ph": "pʰ", "b": "b", "bh": "bʱ", "m": "m",
    "y": "j", "r": "r", "l": "l", "v": "ʋ",
    "ś": "ʃ", "ṣ": "ʂ", "s": "s", "h": "ɦ"}
# The nasal an anusvara is said as before a stop, by the stop's row.
SA_ROW_NASAL = {
    **dict.fromkeys(("k", "kh", "g", "gh", "ṅ"), "ŋ"),
    **dict.fromkeys(("c", "ch", "j", "jh", "ñ"), "ɲ"),
    **dict.fromkeys(("ṭ", "ṭh", "ḍ", "ḍh", "ṇ"), "ɳ"),
    **dict.fromkeys(("t", "th", "d", "dh", "n"), "n"),
    **dict.fromkeys(("p", "ph", "b", "bh", "m"), "m")}
# Before these the anusvara nasalises the vowel before it.
SA_NASALISING = {"y", "r", "l", "v", "ś", "ṣ", "s", "h"}
SA_ORIGIN = 0x0900
# The Vedic accent marks, all combining marks: removed before reading and
# reported in the notes. U+0951 is the svarita of the Rigveda and Atharvaveda
# editions (Unicode names it udātta), U+0952 the anudātta. U+0953 and U+0954
# are not Vedic accents and cannot be read.
SA_ACCENT_MARKS = (
    {0x0951, 0x0952} | set(range(0x1CD0, 0x1CD3)) | set(range(0x1CD4, 0x1CE9))
    | {0x1CED, 0x1CF4, 0x1CF8, 0x1CF9} | set(range(0xA8E0, 0xA8F2)))
SA_ACCENT_NAMES = {0x0951: "svarita", 0x0952: "anudātta"}
SA_JIHVAMULIYA, SA_UPADHMANIYA = 0x1CF5, 0x1CF6   # ᳵ ᳶ, Vedic letters
SA_LA = 0x33                                       # ळ, Vedic


def _sa_nasalise(ipa: list[str], k: int | None) -> None:
    """Put a tilde on the vowel at [ipa][k] (before its length mark)."""
    if k is None:
        return
    s = ipa[k]
    ipa[k] = s[:-1] + "̃ː" if s.endswith("ː") else s + "̃"


def sanskrit(text: str, variety: str = "sa") -> Transcription:
    """[text]'s IAST reading and broad IPA, by Devanagari's letters.
    [variety] is "sa" (Classical) or "vsn" (Vedic): Vedic adds ळ ळ्ह and the
    letters ᳵ ᳶ, says ऐ औ as long diphthongs, and cannot read ॐ.

    Raises CannotRead on a Devanagari letter Sanskrit does not use (the
    nukta letters) and on any other letter."""
    vedic = variety == "vsn"
    chars = [c for c in unicodedata.normalize("NFC", text) if c not in ZW]
    # An accent mark written between a consonant and its vowel sign is read
    # as if written after the sign, where editions print it.
    for j in range(1, len(chars) - 1):
        if ord(chars[j]) in SA_ACCENT_MARKS and \
                ord(chars[j + 1]) - SA_ORIGIN in SA_SIGNS and \
                ord(chars[j - 1]) - SA_ORIGIN in SA_CONSONANTS:
            chars[j], chars[j + 1] = chars[j + 1], chars[j]
    iso: list[str] = []
    ipa: list[str] = []
    notes: list[str] = []
    syllables = 0
    vowel: int | None = None     # index in [ipa] of the vowel just said

    def off(j: int) -> int | None:
        if j >= len(chars):
            return None
        o = ord(chars[j]) - SA_ORIGIN
        return o if 0 <= o < 0x80 else None

    def put_vowel(name: str) -> None:
        nonlocal vowel, syllables
        iso.append(name)
        ipa.append(SA_VEDIC_DIPHTHONGS.get(name) if vedic and
                   name in SA_VEDIC_DIPHTHONGS else SA_VOWEL_IPA[name])
        vowel = len(ipa) - 1
        syllables += 1

    i = 0
    while i < len(chars):
        c = chars[i]
        o = off(i)
        if ord(c) in SA_ACCENT_MARKS:
            name = SA_ACCENT_NAMES.get(ord(c), f"accent U+{ord(c):04X}")
            notes.append(f"{name} on syllable {syllables}")
            i += 1
        elif c.isspace():
            iso.append(" ")
            ipa.append(" ")
            vowel = None
            i += 1
        elif o in SA_CONSONANTS or (vedic and o == SA_LA):
            if o == SA_LA:
                letter, sound = "ḷ", "ɭ"
                # ळ्ह is one sound, ḷh [ɭʱ].
                if off(i + 1) == VIRAMA and off(i + 2) == 0x39:
                    letter, sound = "ḷh", "ɭʱ"
                    i += 2
            else:
                letter = SA_CONSONANTS[o]
                sound = SA_CONSONANT_IPA[letter]
            iso.append(letter)
            ipa.append(sound)
            vowel = None
            i += 1
            if off(i) == VIRAMA:
                i += 1
            elif off(i) in SA_SIGNS:
                put_vowel(SA_SIGNS[off(i)])
                i += 1
            else:
                put_vowel("a")
        elif o in SA_VOWELS:
            put_vowel(SA_VOWELS[o])
            i += 1
        elif o == ANUSVARA:
            # Always written ṃ; said as the nasal of the next stop, as a
            # nasal vowel before y r l v, a sibilant or h, and m at a word's
            # end or before anything else.
            iso.append("ṃ")
            nxt = SA_CONSONANTS.get(off(i + 1))
            if nxt in SA_ROW_NASAL:
                ipa.append(SA_ROW_NASAL[nxt])
                vowel = None
            elif nxt in SA_NASALISING:
                _sa_nasalise(ipa, vowel)
            else:
                ipa.append("m")
                vowel = None
            i += 1
        elif o == CANDRABINDU:
            iso.append("m\u0310")
            _sa_nasalise(ipa, vowel)
            i += 1
        elif o == VISARGA:
            iso.append("ḥ")
            ipa.append("h")
            vowel = None
            i += 1
        elif vedic and ord(c) in (SA_JIHVAMULIYA, SA_UPADHMANIYA):
            iso.append("ḥ")
            ipa.append("x" if ord(c) == SA_JIHVAMULIYA else "ɸ")
            vowel = None
            i += 1
        elif o == AVAGRAHA:
            iso.append("'")
            vowel = None
            i += 1
        elif o == 0x50 and not vedic:    # ॐ; its Vedic value is not pinned
            iso.append("oṃ")
            ipa.append("oːm")
            vowel = None
            i += 1
        elif o is not None and o in DIGITS:
            iso.append(str(o - 0x66))
            i += 1
        elif c in DANDA:
            iso.append(DANDA[c])
            i += 1
        elif c in QUOTES:
            iso.append(QUOTES[c])
            i += 1
        elif c.isalpha() or unicodedata.category(c).startswith("M") or \
                (o is not None and o not in SA_CONSONANTS) or \
                0x1CD0 <= ord(c) <= 0x1CFF or 0xA8E0 <= ord(c) <= 0xA8FF:
            raise CannotRead(f"cannot read {c!r} as Sanskrit")
        else:
            iso.append(c)
            i += 1
    return Transcription(
        _tidy("".join(iso)),
        unicodedata.normalize("NFC", " ".join("".join(ipa).split())), True,
        notes)


# --- Urdu (Perso-Arabic script) ----------------------------------------------

# Hindustani is one course with two scripts, so Urdu-script text is read into
# the same reading letters and IPA as the Devanagari cards, by the `hi`
# tables above (UR_READING_LANG). `transcribe.py ur "..."` always reads
# Perso-Arabic; `transcribe.py hi "..."` does so when the text is in that
# script. A language joins this engine by adding a row to PERSO_ARABIC and its
# letter tables below; the lexicon is a plain data file.
#
# Urdu leaves its short vowels unwritten, so the engine never invents them:
#  - a word with its marks (zabar, zer, pesh, sukun) is read as written;
#  - a hint (the word in Devanagari or typed in Latin letters) is read against
#    the consonants, as for the Indic scripts, and supplies the vowels;
#  - a word in tools/urdu_words.tsv (extendable: word, reading, optional note)
#    takes its reading from there, else one in tools/urdu_lexicon_kaikki.tsv
#    (generated from Wiktionary by tools/build_urdu_lexicon.py); a spelling
#    with several readings there is printed as ambiguous, never picked;
#  - otherwise the consonant skeleton is printed, with `?` where a short vowel
#    may be, and a note, so a person reviews it.
# A letter that has several readings (و ō/ū/v/au, ی ī/ē/y, ے ē/ai, a final
# ہ) gets its commonest one and a note.
PERSO_ARABIC = {"ur": "hi", "hi": "hi"}    # language code -> reading tables
PERSO_ARABIC_ONLY = {"ur"}                 # always read in this script
UR_READING_LANG = "hi"

UR_CONSONANTS = {
    "ب": "b", "پ": "p", "ت": "t", "ٹ": "ṭ", "ث": "s", "ج": "j", "چ": "c",
    "ح": "h", "خ": "k͟h", "د": "d", "ڈ": "ḍ", "ذ": "z", "ر": "r", "ڑ": "ṛ",
    "ز": "z", "ژ": "z͟h", "س": "s", "ش": "ś", "ص": "s", "ض": "z", "ط": "t",
    "ظ": "z", "غ": "ġ", "ف": "f", "ق": "q", "ک": "k", "گ": "g", "ل": "l",
    "م": "m", "ن": "n", "ہ": "h"}
# Letters written in another form by an Arabic keyboard, to the Urdu form.
UR_NORMALISE = str.maketrans({"ي": "ی", "ى": "ی", "ك": "ک", "ه": "ہ",
                              "ۃ": "ہ", "ۓ": "ے", "ؤ": "و"})
UR_IGNORE = {"ـ", "‌", "‍", "‎", "‏", "\ufeff"}
UR_ZABAR, UR_ZER, UR_PESH = "َ", "ِ", "ُ"
UR_SHADDA, UR_SUKUN, UR_DAGGER, UR_HAMZA_ABOVE = "ّ", "ْ", "ٰ", "ٔ"
UR_MARKS = {UR_ZABAR: "a", UR_ZER: "i", UR_PESH: "u"}
UR_OTHER_MARKS = {"ً", "ٌ", "ٍ", UR_SHADDA, UR_SUKUN, UR_DAGGER,
                  UR_HAMZA_ABOVE, "ٖ", "ٗ", "٘", "ٙ", "ٚ", "ٛ", "ٜ", "ٝ", "ٞ"}
UR_ASPIRATE = "ھ"
UR_NASAL = "ں"
UR_EZAFE = ("-e", "ɪ")                    # the written linking vowel, its IPA
UR_NASAL_MARK = "m̐"
UR_UNKNOWN = "?"
UR_PUNCT = {"،": ",", "؛": ";", "؟": "?", "۔": ".", "٫": ".", "٪": "%"}
UR_SHORT = {"a": "a", "i": "i", "u": "u"}
# Sonorants take the aspirate too (lh, mh, nh, rh), said breathy.
UR_BREATHY = {"l", "m", "n", "r"}
UR_EXTRA_IPA = {"z͟h": "ʒ"}
# Letters that are the same sound for judging whether a hint fits.
UR_FOLD = {"k͟h": "kh", "ġ": "g", "q": "k", "z͟h": "z", "ṭ": "t", "ḍ": "d",
           "ṇ": "n", "ṛ": "r", "ś": "s", "ṣ": "s", "ṭh": "th", "ḍh": "dh",
           "ṛh": "rh", "gh": "g", "ṅ": "n", "ñ": "n"}


def _ur_vowel_ipa() -> dict[str, str]:
    return {iso: ipa for iso, ipa in VOWEL_TABLES[UR_READING_LANG].values()}


def _ur_consonant_ipa(letter: str) -> str | None:
    if letter in UR_EXTRA_IPA:
        return UR_EXTRA_IPA[letter]
    if letter in _IPA:
        return consonant(letter, UR_READING_LANG)[1]
    if len(letter) > 1 and letter.endswith("h") and letter[:-1] in UR_BREATHY:
        return consonant(letter[:-1], UR_READING_LANG)[1] + "ʱ"
    return None


def _ur_tokens(reading: str) -> list[tuple[str, str]]:
    """[reading] split into ("C", letter), ("V", vowel), ("N", nasal) and
    ("X", anything else) pieces, longest letter first."""
    reading = unicodedata.normalize("NFC", reading)
    vowels = _ur_vowel_ipa()
    letters = sorted(set(_IPA) | set(UR_EXTRA_IPA) |
                     {c + "h" for c in UR_BREATHY}, key=len, reverse=True)
    out: list[tuple[str, str]] = []
    i = 0
    while i < len(reading):
        if reading.startswith(UR_NASAL_MARK, i):
            out.append(("N", UR_NASAL_MARK))
            i += len(UR_NASAL_MARK)
            continue
        hit = next((v for v in sorted(vowels, key=len, reverse=True)
                    if reading.startswith(v, i)), None)
        cons = next((c for c in letters if reading.startswith(c, i)), None)
        # A vowel letter beats a consonant that starts the same way (a, ai).
        if hit and (not cons or len(hit) >= len(cons)):
            out.append(("V", hit))
            i += len(hit)
        elif cons:
            out.append(("C", cons))
            i += len(cons)
        else:
            out.append(("X", reading[i]))
            i += 1
    return out


def reading_to_ipa(reading: str) -> str:
    """The broad IPA of a reading written in the course's letters."""
    vowels = _ur_vowel_ipa()
    out: list[str] = []
    toks = _ur_tokens(reading)
    ez = UR_EZAFE[0]
    skip = False
    for k, (kind, tok) in enumerate(toks):
        if skip:
            skip = False
            continue
        if (kind == "X" and tok == "-" and k + 1 < len(toks)
                and toks[k + 1] == ("V", ez[1:]) and (
                    k + 2 == len(toks) or toks[k + 2][0] == "X")):
            out.append(UR_EZAFE[1])
            skip = True
            continue
        if kind == "V":
            out.append(vowels[tok])
        elif kind == "C":
            out.append(_ur_consonant_ipa(tok) or tok)
        elif kind == "N":
            if out:
                last = out[-1]
                out[-1] = last[0] + "̃" + last[1:]
        elif tok == "'":
            out.append("ʔ")
        elif tok != "-":
            out.append(tok)
    return unicodedata.normalize("NFC", "".join(out))


@dataclass
class _UrLetter:
    ch: str
    vow: str | None = None        # a, i, u written on it
    shadda: bool = False
    sukun: bool = False
    dagger: bool = False
    hamza: bool = False


@dataclass
class _UrTok:
    kind: str                     # C, V, Q (hamza), A (a silent carrier), X
    iso: str = ""
    mark: str | None = None       # a consonant's written vowel; "0" for none
    nasal: bool = False


def _ur_letters(word: str) -> list[_UrLetter]:
    word = unicodedata.normalize("NFC", word).translate(UR_NORMALISE)
    out: list[_UrLetter] = []
    for c in word:
        if c in UR_IGNORE:
            continue
        if c == "ۂ":
            out.append(_UrLetter("ہ", hamza=True))
        elif c == "ئ":
            out.append(_UrLetter("ی", hamza=True))
        elif c in "أإ":
            out.append(_UrLetter("ا"))
        elif c in UR_MARKS and out:
            out[-1].vow = UR_MARKS[c]
        elif c == UR_SHADDA and out:
            out[-1].shadda = True
        elif c == UR_SUKUN and out:
            out[-1].sukun = True
        elif c == UR_DAGGER and out:
            out[-1].dagger = True
        elif c == UR_HAMZA_ABOVE and out:
            out[-1].hamza = True
        elif c in UR_OTHER_MARKS:
            continue
        else:
            out.append(_UrLetter(c))
    return out


def _ur_bare(word: str) -> str:
    """[word]'s letters alone, to look it up in the lexicon."""
    return "".join(l.ch for l in _ur_letters(word))


def _ur_parse(word: str) -> tuple[list[_UrTok], bool, list[str]]:
    """[word] as tokens; whether it ends in the linking vowel; and notes on
    letters that could be read more than one way."""
    letters = _ur_letters(word)
    notes: list[str] = []
    ezafe = False
    if len(letters) > 1:
        last = letters[-1]
        if last.ch == "ہ" and last.hamza:
            ezafe = True
        elif last.vow == "i" and last.ch not in "اآو":
            ezafe = True
            last.vow = None
    toks: list[_UrTok] = []
    aspirable = {"b", "p", "t", "ṭ", "j", "c", "d", "ḍ", "ṛ", "k", "g",
                 "l", "m", "n", "r"}

    def add_c(iso: str, L: _UrLetter) -> None:
        if L.shadda:
            toks.append(_UrTok("C", iso, "0"))
        mark = L.vow if L.vow else ("0" if L.sukun else None)
        toks.append(_UrTok("C", iso, mark))
        if L.dagger:
            toks.append(_UrTok("V", "ā"))

    for i, L in enumerate(letters):
        ch = L.ch
        nxt = letters[i + 1] if i + 1 < len(letters) else None
        prev = toks[-1] if toks else None
        after_c = prev is not None and prev.kind == "C"
        if ch == "آ":
            toks.append(_UrTok("V", "ā"))
        elif ch == "ا":
            if L.vow:
                toks.append(_UrTok("V", UR_SHORT[L.vow]))
            elif len(letters) == 1 or after_c or (
                    prev is not None and prev.kind in ("V", "A", "Q")):
                toks.append(_UrTok("V", "ā"))
            elif nxt is not None and nxt.ch in "وی ے".replace(" ", "") \
                    and not nxt.vow:
                toks.append(_UrTok("A"))
            else:
                toks.append(_UrTok("V", UR_UNKNOWN))
        elif ch == "ع":
            if L.vow:
                toks.append(_UrTok("V", UR_SHORT[L.vow]))
            elif nxt is None:
                toks.append(_UrTok("A"))
            elif nxt.ch in "اآوی" and not nxt.vow:
                toks.append(_UrTok("A"))
            else:
                toks.append(_UrTok("V", UR_UNKNOWN))
        elif ch == "ء":
            toks.append(_UrTok("Q", "'"))
        elif ch == "و":
            if L.vow:
                add_c("v", L)
            elif after_c and prev.mark in ("u", "a", "i"):
                # The mark and the letter write one long vowel or diphthong.
                toks.append(_UrTok("V", {"u": "ū", "a": "au", "i": "ō"}[
                    prev.mark]))
                prev.mark = "0"
            elif prev is None or prev.kind in ("Q",):
                add_c("v", L)
            elif prev.kind == "A":
                toks.append(_UrTok("V", "ō"))
                notes.append("و: ō, ū or au")
            elif after_c and nxt is not None and nxt.ch in "اآ":
                add_c("v", L)
            elif after_c:
                toks.append(_UrTok("V", "ō"))
                notes.append("و: ō, ū or au")
            elif prev.kind == "V" and nxt is not None and nxt.ch not in "ںی":
                add_c("v", L)
            else:
                toks.append(_UrTok("V", "ō"))
                notes.append("و: ō, ū or au")
        elif ch == "ی":
            glide = nxt is not None and not (
                nxt.ch == "و" and not nxt.vow) and (
                nxt.ch in "اآوے" or (L.hamza and nxt.ch == "ی"))
            if L.vow:
                add_c("y", L)
            elif prev is None and nxt is not None:
                add_c("y", L)
            elif L.hamza and glide:
                add_c("y", L)
            elif prev is not None and prev.kind in ("V", "Q") and glide:
                add_c("y", L)
            elif after_c and nxt is not None and nxt.ch in "اآ":
                if prev.mark is None:
                    # دیا, پیار: the vowel before the glide is not written.
                    toks.append(_UrTok("V", UR_UNKNOWN))
                add_c("y", L)
            elif after_c and prev.mark in ("i", "a"):
                toks.append(_UrTok("V", {"i": "ī", "a": "ai"}[prev.mark]))
                prev.mark = "0"
            elif any(l.ch != UR_NASAL for l in letters[i + 1:]):
                # Not word-final and unmarked: ī, i, ē, ai or iy (ایسا, دیکھیں,
                # بیٹھے, بیتاب): not derivable, so a person reviews it.
                toks.append(_UrTok("V", UR_UNKNOWN))
            else:
                toks.append(_UrTok("V", "ī"))
                notes.append("ی: ī or ē")
        elif ch == "ے":
            if after_c and prev.mark == "a":
                toks.append(_UrTok("V", "ai"))
                prev.mark = "0"
            else:
                toks.append(_UrTok("V", "ē"))
                if len(letters) > 1:
                    notes.append("ے: ē or ai")
        elif ch == UR_ASPIRATE:
            if after_c and prev.iso in aspirable and not prev.iso.endswith("h"):
                prev.iso += "h"
                if L.vow:
                    prev.mark = L.vow
                elif L.sukun:
                    prev.mark = "0"
            else:
                add_c("h", L)
        elif ch == "ہ":
            final = nxt is None
            if ezafe and final and L.hamza:
                toks.append(_UrTok("V", "a"))
            elif L.vow or prev is None or not final:
                add_c("h", L)
            elif prev.kind == "V":
                add_c("h", L)
            elif after_c:
                toks.append(_UrTok("V", UR_UNKNOWN))
                notes.append("final ہ: a silent vowel (a, ā or ē) or h")
            else:
                add_c("h", L)
        elif ch == UR_NASAL:
            if prev is not None and prev.kind == "V":
                prev.nasal = True
            else:
                toks.append(_UrTok("V", UR_UNKNOWN, nasal=True))
        elif ch in UR_CONSONANTS:
            add_c(UR_CONSONANTS[ch], L)
        elif ch.isdigit():
            toks.append(_UrTok("X", str(unicodedata.digit(ch, 0))))
        else:
            toks.append(_UrTok("X", UR_PUNCT.get(ch, ch)))
    return toks, ezafe, sorted(set(notes))


def _ur_reading(toks: list[_UrTok], ezafe: bool) -> str:
    out: list[str] = []
    for k, t in enumerate(toks):
        if t.kind == "C":
            out.append(t.iso)
            nxt = toks[k + 1] if k + 1 < len(toks) else None
            if t.mark in UR_SHORT:
                out.append(UR_SHORT[t.mark])
            elif t.mark is None and nxt is not None and nxt.kind == "C":
                out.append(UR_UNKNOWN)
        elif t.kind in ("V", "Q", "X"):
            out.append(t.iso + (UR_NASAL_MARK if t.nasal else ""))
    return "".join(out) + (UR_EZAFE[0] if ezafe else "")


def _ur_skeleton(items: list[str]) -> list[str]:
    folded = [UR_FOLD.get(c, c) for c in items]
    return [c for k, c in enumerate(folded) if k == 0 or c != folded[k - 1]]


def _ur_typed_to_reading(hint: str) -> str:
    """A hint as a reading: Devanagari is read by the Hindi engine, a hint
    with accented letters is kept, and one typed in plain Latin letters is
    turned into the reading's letters (aa to ā, sh to ś, lone e to ē, a final
    a to ā)."""
    hint = unicodedata.normalize("NFC", hint.strip())
    if any(0x0900 <= ord(c) < 0x0980 for c in hint):
        return transcribe(hint, "hi").reading
    if any(ord(c) > 127 for c in hint):
        return hint
    table = {"chh": "ch", "ch": "c", "sh": "ś", "aa": "ā", "ee": "ī",
             "ii": "ī", "oo": "ū", "uu": "ū"}
    s = re.sub(r"chh|ch|sh|aa|ee|ii|oo|uu",
               lambda m: table[m.group(0)], hint.lower())
    s = s.replace("e", "ē").replace("o", "ō")
    return re.sub(r"(?<=[^aāeēiīoōuūh\W])a(?=\b)", "ā", s)


_UR_LEXICON: dict[str, tuple[str, str]] | None = None


UR_LEXICON_FILES = ("urdu_lexicon_kaikki.tsv", "urdu_words.tsv")
UR_LEXICON_DIR = Path(__file__).resolve().parent


def _ur_read_lexicon(name: str, into: dict[str, tuple[str, str]]) -> None:
    """The rows of the lexicon file [name] (beside this script) put in
    [into], replacing a word already there; a word listed twice in one file
    is an error."""
    path = UR_LEXICON_DIR / name
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return
    seen: set[str] = set()
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cols = line.lstrip("\ufeff").split("\t")
        if len(cols) >= 2:
            key = _ur_bare(cols[0].strip())
            if key in seen:
                raise ValueError(f"{name}: {cols[0].strip()} is listed twice")
            seen.add(key)
            into[key] = (unicodedata.normalize("NFC", cols[1].strip()),
                         cols[2].strip() if len(cols) > 2 else "")


def urdu_lexicon() -> dict[str, tuple[str, str]]:
    """Bare Urdu word -> (reading, note). tools/urdu_lexicon_kaikki.tsv (made
    by tools/build_urdu_lexicon.py from the kaikki.org dump) is read first, and
    tools/urdu_words.tsv, the hand-written list, wins over it. A reading
    with `|` holds several readings of one spelling: it is ambiguous."""
    global _UR_LEXICON
    if _UR_LEXICON is None:
        lex: dict[str, tuple[str, str]] = {}
        for name in UR_LEXICON_FILES:
            _ur_read_lexicon(name, lex)
        _UR_LEXICON = lex
    return _UR_LEXICON


def _ur_word(word: str, hint: str | None
             ) -> tuple[str, bool | None, list[str]]:
    """One Urdu word's reading; whether its hint fitted (None: no hint); and
    notes."""
    toks, ezafe, notes = _ur_parse(word)
    reading = _ur_reading(toks, ezafe)
    unknown = UR_UNKNOWN in reading
    fitted: bool | None = None
    if hint:
        head, _, tail = _ur_typed_to_reading(hint).partition("-")
        theirs = _ur_skeleton([t for k, t in _ur_tokens(head) if k == "C"])
        ours = _ur_skeleton([t.iso for t in toks if t.kind == "C"])
        # A typed final n stands for ں, which is no consonant.
        if any(t.nasal for t in toks) and theirs and theirs[-1] == "n" and (
                not ours or ours[-1] != "n"):
            theirs = theirs[:-1]
            if head.endswith("n"):
                head = head[:-1] + UR_NASAL_MARK
        if ours == theirs:
            fitted = True
            reading = head + (UR_EZAFE[0] if tail or ezafe else "")
            return reading, fitted, []
        fitted = False
    if not unknown and not notes:
        return reading, fitted, []
    entry = urdu_lexicon().get(_ur_bare(word))
    if entry and "|" in entry[0]:
        # Several readings are listed for this spelling: none is picked.
        alts = entry[0].split("|")
        notes = notes + ["ambiguous: " + " / ".join(alts) + ", review"]
    elif entry:
        extra = [f"{word}: {entry[1]}"] if entry[1] else []
        return entry[0] + (UR_EZAFE[0] if ezafe else ""), fitted, extra
    elif unknown:
        notes = notes + [
            "unvowelled: short vowels are not written; the ? marks where "
            "one may be, so a person must review this reading"]
    return reading, fitted, [f"{word}: {n}" for n in notes]


def urdu(text: str, hint: str | None = None) -> Transcription:
    """[text], Urdu in Perso-Arabic script, as a reading and its broad IPA.
    The hint, if any, is one reading per word (see this section's header)."""
    words = text.split()
    hints = hint.split() if hint else []
    n_words = sum(1 for w in words
                  if any(c.isalpha() or unicodedata.category(c) == "Mn"
                         for c in w))
    notes: list[str] = []
    if hints and len(hints) != n_words:
        notes.append("the hint has a different number of words; ignored")
        hints = []
    readings: list[str] = []
    fitted_all = True
    h = 0
    for w in words:
        start = 0
        while start < len(w) and not (w[start].isalpha() or
                                      unicodedata.category(w[start]) in
                                      ("Mn", "Nd")):
            start += 1
        end = len(w)
        while end > start and not (w[end - 1].isalpha() or
                                   unicodedata.category(w[end - 1]) in
                                   ("Mn", "Nd")):
            end -= 1
        core = w[start:end]
        lead = "".join(UR_PUNCT.get(c, c) for c in w[:start])
        trail = "".join(UR_PUNCT.get(c, c) for c in w[end:])
        if not core:
            readings.append(lead + trail)
            continue
        if not any(c.isalpha() for c in core):
            readings.append(lead + "".join(
                str(unicodedata.digit(c, 0)) if c.isdigit() else c
                for c in core) + trail)
            continue
        r, fit, n = _ur_word(core, hints[h] if hints else None)
        h += 1 if hints else 0
        if fit is False:
            fitted_all = False
        notes.extend(n)
        readings.append(lead + r + trail)
    reading = " ".join(readings)
    return Transcription(reading, reading_to_ipa(reading), fitted_all, notes)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    lang, text = argv[1], argv[2]
    hint = argv[3] if len(argv) > 3 else None
    t = transcribe(text, lang, hint)
    print(f"reading: {t.reading}")
    print(f"ipa:     /{t.ipa}/")
    for note in t.notes:
        print(f"note:    {note}")
    if hint and not t.fitted:
        print("the hint did not fit the letters; the rules were used")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
