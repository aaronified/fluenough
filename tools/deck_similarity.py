#!/usr/bin/env python3
"""Similar-word warnings for a reviewer (#692; owner, 2026-10-20 and
2026-10-24: "the tool only warns").

Scans each language's cards for two kinds of neighbours and lists them:

- **sounds like** (a `pair` note, the ear icon): the two IPA transcriptions
  differ by exactly one segment, and only between very close sounds: a short
  and a long vowel (e/eː), an unaspirated and an aspirated consonant (k/kʰ),
  or a dental and a retroflex one (t̪/ʈ) (owner, 2026-10-22);
- **looks like** (a `homograph` or `lookalike` note, the ear-off icon): the
  same spelling with a different sound (a homograph), or two spellings that
  differ only by a mark that is easy to miss: a nukta, or a chandrabindu
  against an anusvara (a lookalike; owner, 2026-10-24). A vowel sign such
  as the i and ii of कि and की is a different word, not a lookalike.

A pair that either card already names, by `pair` or a `pair`, `homograph`
or `lookalike` note with its `ref`, is marked explained. A reviewer keeps
the real pairs and writes their notes: the tool changes no file, and the
validator does not read it.

    python3 tools/deck_similarity.py decks/
    python3 tools/deck_similarity.py decks/ --language hi --unexplained

Exit status is 0 whatever it finds.
"""

from __future__ import annotations

import argparse
import sys
import unicodedata
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from pick_warning import segments

# The fewest segments a word needs to be compared by sound: a one-sound word
# is one sound from too many.
MIN_SEGMENTS = 2

# Length, aspiration, voicing breath and the dental mark: what a close pair
# may differ by when the letters under them are the same.
_SOFT = set("ːˑʰʱ̪")

# Close sounds of different letters: a dental and a retroflex consonant.
_CLOSE = {frozenset(p) for p in (
    ("t", "ʈ"), ("d", "ɖ"), ("n", "ɳ"), ("l", "ɭ"), ("s", "ʂ"), ("ɾ", "ɽ"),
)}

SOUND_NOTES = ("pair",)
LOOK_NOTES = ("homograph", "lookalike")


@dataclass
class Word:
    id: str
    language: str
    path: Path
    target: str = ""
    ipa: str = ""
    reading: str = ""
    # (kind, ref) of the card's `pair` and of each note that names a card.
    notes: list[tuple[str, str]] = field(default_factory=list)


@dataclass
class Similar:
    kind: str      # "sound", "homograph" or "lookalike"
    a: Word
    b: Word
    detail: str
    explained: bool

    @property
    def phrase(self) -> str:
        return "sounds like" if self.kind == "sound" else "looks like"


def _str(value: object) -> str:
    return value if isinstance(value, str) else ""


def _language(data: dict, path: Path) -> str:
    language = data.get("language")
    if isinstance(language, dict) and isinstance(language.get("code"), str):
        return language["code"]
    return path.parent.name


def load_words(paths: list[Path]) -> list[Word]:
    """The cards the files write, a core's and a single-file deck's alike; a
    layer writes no `target` and adds none. A card in two files is one word."""
    words: dict[str, Word] = {}
    for path in paths:
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8"))
        except (OSError, yaml.YAMLError):
            continue
        if not isinstance(data, dict) or not isinstance(data.get("cards"), list):
            continue
        language = _language(data, path)
        for card in data["cards"]:
            if (not isinstance(card, dict) or not isinstance(card.get("id"), str)
                    or not isinstance(card.get("target"), str)):
                continue
            word = Word(card["id"], language, path, card["target"],
                        _str(card.get("ipa")), _str(card.get("reading")))
            if isinstance(card.get("pair"), str):
                word.notes.append(("pair", card["pair"]))
            notes = card.get("notes")
            for note in notes if isinstance(notes, list) else []:
                if isinstance(note, dict) and isinstance(note.get("ref"), str):
                    word.notes.append((str(note.get("kind")), note["ref"]))
            words.setdefault(word.id, word)
    return list(words.values())


def _explained(a: Word, b: Word, kinds: tuple[str, ...]) -> bool:
    return (any(k in kinds and ref == b.id for k, ref in a.notes)
            or any(k in kinds and ref == a.id for k, ref in b.notes))


def _base(segment: str) -> str:
    """A segment without its length, aspiration and dental mark."""
    return "".join(ch for ch in segment if ch not in _SOFT)


def close_sounds(x: str, y: str) -> bool:
    """Whether two different segments are a very close pair."""
    if x == y:
        return False
    bx, by = _base(x), _base(y)
    return bx == by or frozenset((bx, by)) in _CLOSE


def _strip_marks(text: str) -> str:
    """The spelling as a reader may take it: no nukta, and a chandrabindu
    read as an anusvara. Every other mark, a vowel sign above all, stays."""
    out = []
    for ch in unicodedata.normalize("NFD", text):
        if ch.isspace():
            continue
        name = unicodedata.name(ch, "")
        if "NUKTA" in name:
            continue
        out.append("\u0902" if "CANDRABINDU" in name else ch)
    return "".join(out)


def _one_apart(group: list[Word]) -> list[tuple[Word, Word, str]]:
    """The pairs whose segments differ at exactly one place by a close pair."""
    seg = {w.id: segments(w.ipa) for w in group
           if len(segments(w.ipa)) >= MIN_SEGMENTS}
    by_id = {w.id: w for w in group}
    buckets: dict[tuple, list[str]] = defaultdict(list)
    for wid, s in seg.items():
        for i in range(len(s)):
            buckets[(i, tuple(s[:i]), tuple(s[i + 1:]))].append(wid)
    found: dict[tuple[str, str], str] = {}
    for key, ids in buckets.items():
        if len(ids) < 2:
            continue
        i = key[0]
        for n, first in enumerate(ids):
            for second in ids[n + 1:]:
                x, y = seg[first][i], seg[second][i]
                if close_sounds(x, y):
                    pair = tuple(sorted((first, second)))
                    found[pair] = f"{x} / {y}"
    return [(by_id[a], by_id[b], d) for (a, b), d in sorted(found.items())]


def find_similar(words: list[Word]) -> list[Similar]:
    """Every sound-alike and look-alike pair within a language."""
    found: list[Similar] = []
    for language in sorted({w.language for w in words}):
        group = [w for w in words if w.language == language]
        for a, b, d in _one_apart(group):
            if a.target != b.target:
                found.append(Similar("sound", a, b, f"IPA {d}",
                                     _explained(a, b, SOUND_NOTES)))
        spelled: dict[str, list[Word]] = defaultdict(list)
        stripped: dict[str, list[Word]] = defaultdict(list)
        for w in group:
            spelled[unicodedata.normalize("NFC", w.target)].append(w)
            if _strip_marks(w.target):
                stripped[_strip_marks(w.target)].append(w)
        for same in spelled.values():
            for n, a in enumerate(same):
                for b in same[n + 1:]:
                    if a.ipa and b.ipa and segments(a.ipa) != segments(b.ipa):
                        found.append(Similar(
                            "homograph", a, b, f"IPA {a.ipa} / {b.ipa}",
                            _explained(a, b, LOOK_NOTES)))
        for same in stripped.values():
            for n, a in enumerate(same):
                for b in same[n + 1:]:
                    if (unicodedata.normalize("NFC", a.target)
                            != unicodedata.normalize("NFC", b.target)):
                        found.append(Similar(
                            "lookalike", a, b, "a mark apart",
                            _explained(a, b, LOOK_NOTES)))
    found.sort(key=lambda s: (s.a.language, s.kind, s.a.id, s.b.id))
    return found


def describe(s: Similar) -> str:
    state = "explained" if s.explained else "UNEXPLAINED"
    return (f"{s.a.language}  {s.phrase:<11} {s.kind:<9} {s.a.id} {s.a.target} "
            f"({s.a.reading or s.a.ipa}) ~ {s.b.id} {s.b.target} "
            f"({s.b.reading or s.b.ipa}); {s.detail}; {state}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("root", type=Path, help="the decks folder")
    parser.add_argument("--language", help="only this language code")
    parser.add_argument("--unexplained", action="store_true",
                        help="only the pairs no note explains")
    args = parser.parse_args(argv)
    words = load_words(sorted(args.root.glob("*/*.yaml")))
    if args.language:
        words = [w for w in words if w.language == args.language]
    found = find_similar(words)
    if args.unexplained:
        found = [s for s in found if not s.explained]
    for s in found:
        print(describe(s))
    print(f"{len(found)} similar pairs among {len(words)} words")
    return 0


if __name__ == "__main__":
    sys.exit(main())
