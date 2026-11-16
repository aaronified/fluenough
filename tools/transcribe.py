#!/usr/bin/env python3
"""A word's reading in ISO 15919 letters, as it is said, and its broad IPA
(ADR-0025).

    python3 tools/transcribe.py hi "कितना" kitna      # reading and IPA
    python3 tools/transcribe.py es "la casa"          # IPA
    python3 tools/transcribe.py fr "les enfants"      # IPA
    python3 tools/transcribe.py ml "ഞാൻ വരുന്നു"       # reading and IPA
    python3 tools/transcribe.py sa "संस्कृतम्"          # IAST reading and IPA

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
            # Bengali says a word's last vowel after a ব-ফলা: বিশ্ব biśśo.
            # After a য-ফলা too: সত্য śotto. And after র্ব, which is r and b,
            # not a ফলা: পূর্ব purbo.
            if end and lang in ("bn", "as") and k > 0 and \
                    units[k - 1].kind == "C" and \
                    (units[k - 1].vaphala or units[k - 1].yaphala or
                     _rba_cluster(units, k - 1)):
                continue
            # A word's last inherent vowel is not said, unless the word is a
            # single letter.
            first = k == 1 or (k >= 2 and units[k - 2].kind == "SP")
            if end and not first:
                drop = not _said_after_cluster(units, k, lang)
            elif lang in ("hi", "mr", "gu", "bn") and \
                    _schwa_drops(units, k):
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
    ("gu", "કંઈ"): ("kaim̐", "kə̃i"),
}


def transcribe(text: str, lang: str, hint: str | None = None
               ) -> Transcription:
    """[text]'s reading in ISO 15919 letters as said, and its broad IPA."""
    if lang == "es":
        return Transcription(text, spanish_ipa(text), True)
    if lang == "fr":
        return Transcription(text, french_ipa(text), True)
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
            if ch.tag == "silent" or typed == "":
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
                    rom, (rom[:-1] + "y", _YOON_IPA_STEM.get(rom, rom[:-1] + "j")))
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


def _hangul_word(word: str) -> str:
    """One word's Revised Romanization, with the sound changes between its
    syllables: liaison (`한국어` hangugeo), nasalisation (`학문` hangmun),
    ㄹ's changes (`신라` silla, `종로` jongno) and ㅎ's (`좋다` jota). Tensing
    is not written, as the standard has it."""
    syl = []   # [initial jamo, vowel romanised, final jamo(s) or ""]
    for ch in word:
        n = ord(ch) - 0xAC00
        if 0 <= n < 11172:
            syl.append([_HG_INITIAL_JAMO[n // 588],
                        _HG_VOWEL[n % 588 // 28], _HG_FINAL[n % 28]])
        else:
            syl.append([None, ch, ""])
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
    for k, (init, vowel, final) in enumerate(syl):
        if init is None:
            out.append(vowel)
            continue
        rom = _HG_INITIAL_ROM[init]
        if init == "ㄹ" and k and syl[k - 1][2] == "ㄹ":
            rom = "l"
        out.append(rom + vowel)
        for jamo in _HG_PARTS.get(final, final):
            jamo = _HG_SAID.get(jamo, jamo)
            out.append(_HG_CODA_ROM.get(jamo, ""))
    return "".join(out)


def korean(text: str) -> Transcription:
    """[text] in Hangul, in the Revised Romanization the Korean decks use.
    Spaces end a word: no change runs across them."""
    if any(ord(c) > 0x7F and not 0xAC00 <= ord(c) <= 0xD7A3
           and not unicodedata.category(c).startswith("P") for c in text):
        raise CannotRead(text)
    words = [_hangul_word(w) for w in text.split(" ")]
    return Transcription(" ".join(words), "", True)


def mandarin(text: str, hint: str | None) -> Transcription:
    """Pinyin cannot be derived from characters, so it is the hint's:
    Wiktionary's, with its tone marks, as it was given. Sandhi is not
    applied; a card writes the citation tones."""
    if not hint or not hint.strip():
        raise CannotRead(text)
    return Transcription(unicodedata.normalize("NFC", hint.strip()), "", True)


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
