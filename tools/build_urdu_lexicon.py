#!/usr/bin/env python3
"""Build tools/urdu_lexicon_kaikki.tsv from the kaikki.org Urdu dump.

    python3 tools/build_urdu_lexicon.py [--dump PATH] [--dump-date YYYY-MM-DD]
                                        [--out PATH] [--cache DIR]

The Urdu script leaves its short vowels unwritten, so `transcribe.py ur` prints
`?` for them unless a hint or a lexicon supplies the reading. This script turns
the Wiktionary extract on kaikki.org into such a lexicon in bulk: one row per
Urdu headword and per inflected form (the dump's `forms`) for which the dump
gives an explicit transliteration. Vowels are never inferred: an entry without
a transliteration gives no row. (The dump's IPA is not used: it exists only on
a handful of headwords that have no transliteration.)

Each transliteration is converted to the reading letters of the Hindustani
decks (`roman_to_reading`), and a row is kept only when the consonants of the
converted reading are those of the Urdu word as `transcribe.py` reads it, so a
wrong transliteration on an entry of the dump is dropped. The key is the bare
word, the way `transcribe.urdu_lexicon` keys it. Readings that differ for one
key are all listed, `|`-separated: the engine prints them as ambiguous for a
person to review. Several-word forms are not keyed (the engine looks words up
one at a time).

Output is sorted and deterministic. Without `--dump` the dump is downloaded
once, with tools/import_phonetic.py's downloader, into a cache outside the
repo (`~/.cache/fluenough/kaikki`, or `--cache`).

The dump's text is from Wiktionary and is CC-BY-SA 4.0; the generated file
carries that notice in its header.
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path
from typing import Iterable

sys.path.insert(0, str(Path(__file__).resolve().parent))

import transcribe as tr  # noqa: E402

HERE = Path(__file__).resolve().parent
OUT = HERE / "urdu_lexicon_kaikki.tsv"
CACHE = Path.home() / ".cache" / "fluenough" / "kaikki"
DUMP_NAME = "kaikki.org-dictionary-Urdu.jsonl"
SOURCE_URL = "https://kaikki.org/dictionary/Urdu/" + DUMP_NAME

MACRON, TILDE, DOT_BELOW, DOT_ABOVE, ACUTE = (
    "̄", "̃", "̣", "̇", "́")
CARON, BREVE, RING_BELOW, MACRON_BELOW, DOUBLE_TILDE = (
    "̌", "̆", "̤", "̱", "͠")
VOWELS = set("aāiīuūeēoō")
# (base letter, combining marks) -> the decks' reading letter.
GRAPHEMES: dict[tuple[str, frozenset], str] = {}


def _g(base: str, marks: str, out: str) -> None:
    GRAPHEMES[(base, frozenset(marks))] = out


for _c in "abcdfghjklmnpqrstvyz":
    _g(_c, "", _c)
for _c, _o in (("a", "ā"), ("i", "ī"), ("u", "ū"), ("e", "ē"), ("o", "ō")):
    _g(_c, MACRON, _o)
_g("a", "", "a"), _g("i", "", "i"), _g("u", "", "u")
_g("e", "", "ē"), _g("o", "", "ō")
for _base, _marks, _out in (
        ("t", DOT_BELOW, "ṭ"), ("d", DOT_BELOW, "ḍ"), ("r", DOT_BELOW, "ṛ"),
        ("s", ACUTE, "ś"), ("s", CARON, "ś"), ("c", CARON, "c"),
        ("g", DOT_ABOVE, "ġ"), ("g", BREVE, "ġ"), ("x", "", "k͟h"),
        ("k", MACRON_BELOW, "k͟h"), ("z", CARON, "z͟h"),
        ("s", DOT_BELOW, "s"), ("s", MACRON_BELOW, "s"),
        ("z", DOT_BELOW, "z"), ("z", ACUTE, "z"), ("z", MACRON_BELOW, "z"),
        ("z", RING_BELOW, "z"), ("t", RING_BELOW, "t"),
        ("h", DOT_BELOW, "h"), ("n", DOT_BELOW, "n"), ("n", DOT_ABOVE, "n"),
        ("n", MACRON_BELOW, "n"), ("m", DOT_BELOW, "m")):
    _g(_base, _marks, _out)
APOSTROPHE = {"'", "’"}
ASPIRABLE = set("bptṭjcdḍṛkglmnr")
DROPPED = set("ʻʿ‘ʾ")                      # ʿain: the decks do not write it


def roman_to_reading(text: str, word: str = "") -> str | None:
    """Wiktionary's transliteration of one Urdu word as a reading in the
    decks' letters, or None when it holds anything this does not know (a
    space, a hyphen, a capital in the middle, an odd letter) or when its
    vowels cannot be trusted: a doubled short vowel (ʿain written `a'a`), or
    a final `ah`, which the dump writes for a final ہ that may be said a, ā
    or ē: such a row is dropped rather than guessed. [word] is the Urdu
    spelling: an apostrophe is kept (as the engine writes it) only for a
    hamza ء, never for ع, which the decks do not write."""
    keep_hamza = "ء" in word and "ع" not in word
    s = unicodedata.normalize("NFD", text.strip().lower())
    groups: list[list[str]] = []
    for ch in s:
        if unicodedata.combining(ch) and groups:
            groups[-1].append(ch)
        else:
            groups.append([ch])
    units: list[str] = []
    nasal_at: list[int] = []               # unit index carrying a nasal mark
    after_nasal_vowel = False
    for base, *marks in groups:
        if base in DROPPED:
            continue
        if base in APOSTROPHE and not marks:
            if keep_hamza:
                units.append("'")
            after_nasal_vowel = False
            continue
        mset = set(marks)
        nasal = False
        if DOUBLE_TILDE in mset:
            mset.discard(DOUBLE_TILDE)
            nasal = True
        if TILDE in mset:
            if base in "aiueo":
                mset.discard(TILDE)
                nasal = True
            elif base == "n" and mset == {TILDE}:
                units.append("n")          # ñ
                after_nasal_vowel = False
                continue
        out = GRAPHEMES.get((base, frozenset(mset)))
        if out is None:
            return None
        if out == "n" and DOT_ABOVE in marks and after_nasal_vowel:
            continue                       # hū̃ṅgā: the ṅ repeats the nasal
        units.append(out)
        if nasal:
            nasal_at.append(len(units) - 1)
        after_nasal_vowel = nasal and out in VOWELS
    inserts: set[int] = set()
    for i in nasal_at:
        j = i if units[i] in VOWELS else i + 1
        if j >= len(units) or units[j] not in VOWELS:
            return None
        end = j
        while end + 1 < len(units) and units[end + 1] in VOWELS:
            end += 1
        inserts.add(end)
    out_text: list[str] = []
    for k, u in enumerate(units):
        out_text.append(u)
        if k in inserts:
            out_text.append(tr.UR_NASAL_MARK)
    result = unicodedata.normalize("NFC", "".join(out_text))
    if not result or any(v * 2 in result for v in "aiu"):
        return None
    key = unicodedata.normalize("NFC", word)
    if result.endswith("ah") and key.endswith("ہ") and len(key) > 1 and (
            key[-2] not in "اآے"):
        return None
    return result


def _skeleton(letters: Iterable[str]) -> list[str]:
    """Consonant letters folded to what a reading and the Urdu spelling can
    be compared by: the aspirate h of kh, bh... is left out, so are the glides
    y, v (which Urdu spells with letters that also write vowels), m and n are
    one nasal, and runs of one letter are one. A lone h counts."""
    out: list[str] = []
    for c in letters:
        c = tr.UR_FOLD.get(c, c)
        if len(c) > 1 and c.endswith("h"):
            c = c[:-1]
        c = {"m": "n", "ṅ": "n"}.get(c, c)
        if c in ("y", "v", "w", "'"):
            continue
        if not out or out[-1] != c:
            out.append(c)
    return out


def _reading_letters(reading: str) -> list[str]:
    """The consonant letters of a reading (a vowel is not one)."""
    reading = reading.replace(tr.UR_NASAL_MARK, "")
    out: list[str] = []
    i = 0
    while i < len(reading):
        c = reading[i]
        if i + 2 < len(reading) and reading[i + 1] == "\u035f":
            out.append(reading[i:i + 3])
            i += 3
            continue
        if c == "h" and out and i > 0 and reading[i - 1] == out[-1] \
                and out[-1] in ASPIRABLE:
            out[-1] += "h"
        elif c not in VOWELS:
            out.append(c)
        i += 1
    return out


def consistent(word: str, reading: str) -> bool:
    """Whether [reading] has the consonants that [word] has, as the engine
    reads them (see `_skeleton`). The reading may lack an n (ن also writes the
    nasal of a vowel, ن٘ before a stop, which a reading writes as m̐), an h
    after one of the letters that take an aspirate (nh, lh, rh...), and a
    final h (a silent ہ)."""
    toks, _, _ = tr._ur_parse(word)
    ours = _skeleton(t.iso for t in toks if t.kind == "C")
    theirs = _skeleton(_reading_letters(reading))
    j = 0
    for k, c in enumerate(ours):
        if j < len(theirs) and theirs[j] == c:
            j += 1
        elif c == "n":
            continue
        elif c == "h" and (k == len(ours) - 1 or ours[k - 1] in ASPIRABLE):
            continue            # a final silent ہ; the h of nh, lh... (ں)
        else:
            return False
    return j == len(theirs)


def entry_rows(entry: dict) -> Iterable[tuple[str, str]]:
    """(Urdu word, transliteration) pairs of one dump entry: its headword with
    the transliteration the dump gives it, and each form that has its own."""
    forms = entry.get("forms") or []
    word = entry.get("word")
    if isinstance(word, str):
        for f in forms:
            if "romanization" in (f.get("tags") or []) and isinstance(
                    f.get("form"), str):
                yield word, f["form"]
    for f in forms:
        if isinstance(f.get("roman"), str) and isinstance(f.get("form"), str):
            yield f["form"], f["roman"]


def build(lines: Iterable[str]) -> tuple[dict[str, set[str]], dict[str, int]]:
    """The lexicon (bare word -> its readings) from a dump's lines, and the
    counts of what was seen and dropped."""
    lex: dict[str, set[str]] = defaultdict(set)
    n = {"entries": 0, "pairs": 0, "multi-word": 0, "unconvertible": 0,
         "mismatch": 0}
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        n["entries"] += 1
        for form, roman in entry_rows(entry):
            n["pairs"] += 1
            form = unicodedata.normalize("NFC", form).strip()
            if not form or any(c.isspace() for c in form):
                n["multi-word"] += 1
                continue
            reading = roman_to_reading(roman, form)
            if reading is None:
                n["unconvertible"] += 1
                continue
            key = tr._ur_bare(form)
            if not key or not consistent(form, reading):
                n["mismatch"] += 1
                continue
            lex[key].add(reading)
    return lex, n


def render(lex: dict[str, set[str]], dump_date: str) -> str:
    ambiguous = sum(1 for r in lex.values() if len(r) > 1)
    head = [
        "# Urdu words and their readings in the Hindustani decks' letters, made",
        "# by tools/build_urdu_lexicon.py from the kaikki.org Urdu dump of "
        f"Wiktionary:",
        f"#   source: {SOURCE_URL} (dump of {dump_date})",
        "# Licence: the readings are taken from Wiktionary, CC-BY-SA 4.0 "
        "(https://creativecommons.org/licenses/by-sa/4.0/); this file is shared "
        "under the same licence.",
        "# Do not edit by hand: rerun the script. Words to fix or pin go in "
        "tools/urdu_words.tsv, which wins over this file.",
        "# Columns, separated by a tab: the bare word, then its reading; "
        "several readings for one word are separated by | and the engine",
        "# prints such a word as ambiguous. Only explicit transliterations of "
        "the dump are used: no vowel is inferred.",
        f"# {len(lex)} words, {ambiguous} with more than one reading.",
    ]
    rows = [f"{k}\t{'|'.join(sorted(v))}" for k, v in sorted(lex.items())]
    return "\n".join(head + rows) + "\n"


def ensure_dump(cache: Path) -> Path:
    dest = cache / DUMP_NAME
    if not dest.is_file():
        import import_phonetic as ip   # its downloader; the cache is ours
        print(f"downloading {SOURCE_URL} to {dest} (once)", file=sys.stderr)
        ip.download(SOURCE_URL, dest)
    return dest


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--dump", type=Path,
                   help="a kaikki.org Urdu JSONL you have (default: the cached "
                        "download)")
    p.add_argument("--dump-date", help="the dump's date for the header "
                   "(default: the dump file's modification date)")
    p.add_argument("--out", type=Path, default=OUT)
    p.add_argument("--cache", type=Path, default=CACHE,
                   help="where the download is kept (default: %(default)s)")
    args = p.parse_args(argv[1:])
    dump = args.dump or ensure_dump(args.cache)
    date = args.dump_date or datetime.date.fromtimestamp(
        dump.stat().st_mtime).isoformat()
    with dump.open(encoding="utf-8") as f:
        lex, n = build(f)
    text = render(lex, date)
    args.out.write_text(text, encoding="utf-8")
    print(f"{n['entries']} entries, {n['pairs']} word/transliteration pairs; "
          f"dropped {n['multi-word']} multi-word, {n['unconvertible']} "
          f"unconvertible, {n['mismatch']} with other consonants; "
          f"{len(lex)} words written to {args.out} ({len(text)} bytes)",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
