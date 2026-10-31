#!/usr/bin/env python3
"""Proposals for `pair` notes (#421; wiki/Plan-B1-Plans.md, "Notes, and a
Wiktionary link, on every word card").

Lists the words of a language whose IPA differs from another word's by
exactly one segment, and only between very close sounds, as DECK-FORMAT.md
says a minimal pair does: a short and a long vowel (e/eː), an unaspirated and
an aspirated consonant (k/kʰ), or a dental and a retroflex one (t̪/ʈ).

A writer reads each proposal, keeps the real pairs and writes the note's
text, naming the difference ("Not X: the a is long there"). The tool prints
a note to paste, with a `TODO` for the text, and changes no file.

A pair already written, as a card's `pair` or a `pair` note naming the other
word on either card, is left out. So is an offensive word, whose pairs the
reviewers keep (tools/offensive_alikes.py), and a word shorter than three
segments, which is close to too many.

    python3 tools/propose_pairs.py decks/ --language te
    python3 tools/propose_pairs.py decks/ --language te --all   # with written pairs
"""

from __future__ import annotations

import argparse
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from pick_warning import segments

RUDE = "offensive"

# The fewest segments a word has to be compared: a shorter one is close to
# too many.
MIN_SEGMENTS = 3

# Retroflex consonants and the dental or alveolar ones they pair with.
_RETROFLEX = {"ʈ": "t", "ɖ": "d", "ɳ": "n", "ɭ": "l", "ɽ": "r", "ʂ": "s",
              "ɻ": "r", "ʐ": "z"}
_LENGTH = "ːˑ"
_ASPIRATION = "ʰʱ"
# Dental, and the other marks that do not change which sound it is.
_DENTAL = "̪"


@dataclass
class Word:
    id: str
    language: str
    target: str
    reading: str
    ipa: str
    rude: bool = False
    # The ids of the words a `pair` or a pair note names.
    pairs: set[str] = field(default_factory=set)


@dataclass
class Proposal:
    a: Word
    b: Word
    # The two segments that differ, a's first.
    sounds: tuple[str, str]
    # What sets them apart: "length", "aspiration" or "place".
    difference: str


def _base(segment: str) -> tuple[str, dict[str, str]]:
    """A segment with length, aspiration and its place mark taken off, and
    what was taken off, by kind: ("t", {"place": "dental"}) for t̪,
    ("a", {"length": "long"}) for aː."""
    marks: dict[str, str] = {}
    out = []
    for ch in unicodedata.normalize("NFD", segment):
        if ch in _LENGTH:
            marks["length"] = "long"
        elif ch in _ASPIRATION:
            marks["aspiration"] = "aspirated"
        elif ch == _DENTAL:
            marks["place"] = "dental"
        elif ch in _RETROFLEX:
            out.append(_RETROFLEX[ch])
            marks["place"] = "retroflex"
        else:
            out.append(ch)
    return "".join(out), marks


def close_sounds(a: str, b: str) -> str | None:
    """What sets the segments [a] and [b] apart when they are very close
    sounds, else None: "length" for aː and a, "aspiration" for k and kʰ,
    "place" for t̪ and ʈ. Two sounds that differ in two of these, or in
    anything else, are not a minimal pair."""
    if a == b:
        return None
    base_a, marks_a = _base(a)
    base_b, marks_b = _base(b)
    if base_a != base_b:
        return None
    kinds = [k for k in ("length", "aspiration", "place")
             if marks_a.get(k) != marks_b.get(k)]
    return kinds[0] if len(kinds) == 1 else None


def _str(value: object) -> str:
    return value if isinstance(value, str) else ""


def _language(data: dict, path: Path) -> str:
    language = data.get("language")
    if isinstance(language, dict) and isinstance(language.get("code"), str):
        return language["code"]
    if isinstance(language, str):
        return language
    return path.parent.name


def load_words(paths: list[Path]) -> list[Word]:
    """The cards the files write, a core's and a single-file deck's alike;
    a layer writes no `target` and adds none. Reads no file but YAML."""
    words: dict[str, Word] = {}
    for path in paths:
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8"))
        except (OSError, yaml.YAMLError):
            continue
        if not isinstance(data, dict) or not isinstance(data.get("cards"), list):
            continue
        deck_tags = data.get("tags") if isinstance(data.get("tags"), list) else []
        language = _language(data, path)
        for card in data["cards"]:
            if not isinstance(card, dict) or not isinstance(card.get("id"), str):
                continue
            if not isinstance(card.get("target"), str):
                continue
            tags = card.get("tags") if isinstance(card.get("tags"), list) else []
            word = Word(
                id=card["id"],
                language=language,
                target=card["target"],
                reading=_str(card.get("reading")),
                ipa=_str(card.get("ipa")),
                rude=(card.get("register") == RUDE or RUDE in tags
                      or RUDE in deck_tags),
            )
            if isinstance(card.get("pair"), str):
                word.pairs.add(card["pair"])
            notes = card.get("notes")
            for note in notes if isinstance(notes, list) else []:
                if (isinstance(note, dict) and note.get("kind") == "pair"
                        and isinstance(note.get("ref"), str)):
                    word.pairs.add(note["ref"])
            words[word.id] = word
    return list(words.values())


def propose(words: list[Word], *, written: bool = False) -> list[Proposal]:
    """Every minimal pair among [words] of one language, each once, in id
    order. [written] keeps the pairs a note already names."""
    found: list[Proposal] = []
    for language in sorted({w.language for w in words}):
        group = [w for w in words if w.language == language and w.ipa
                 and not w.rude]
        segs = {w.id: segments(w.ipa) for w in group}
        # Words that are the same but for one place share a key there.
        buckets: dict[tuple, list[Word]] = {}
        for w in group:
            s = segs[w.id]
            if len(s) < MIN_SEGMENTS:
                continue
            for i in range(len(s)):
                buckets.setdefault((i, tuple(s[:i]), tuple(s[i + 1:])),
                                   []).append(w)
        seen: set[tuple[str, str]] = set()
        for (i, _, _), bucket in buckets.items():
            for x in range(len(bucket)):
                for y in range(x + 1, len(bucket)):
                    a, b = sorted((bucket[x], bucket[y]), key=lambda w: w.id)
                    if (a.id, b.id) in seen:
                        continue
                    sa, sb = segs[a.id][i], segs[b.id][i]
                    difference = close_sounds(sa, sb)
                    if difference is None:
                        continue
                    seen.add((a.id, b.id))
                    if not written and (b.id in a.pairs or a.id in b.pairs):
                        continue
                    found.append(Proposal(a, b, (sa, sb), difference))
    found.sort(key=lambda p: (p.a.language, p.a.id, p.b.id))
    return found


def note_for(a: Word, b: Word) -> str:
    """The note to paste on [a], naming [b], its text left to the writer."""
    return (f'{a.id}: - {{ kind: "pair", ref: "{b.id}", '
            f'text: "TODO: not {b.target} ({b.reading}): ..." }}')


def describe(p: Proposal) -> str:
    """One line for a writer."""
    def one(w: Word) -> str:
        return f"{w.id} {w.target} ({w.reading or w.ipa})"
    return (f"{p.a.language}  {one(p.a)} ~ {one(p.b)}; "
            f"{p.sounds[0]} / {p.sounds[1]} ({p.difference})")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("root", type=Path, help="the decks folder")
    parser.add_argument("--language", help="only this language code")
    parser.add_argument("--all", action="store_true",
                        help="also the pairs a note already names")
    args = parser.parse_args(argv)
    words = load_words(sorted(args.root.glob("*/*.yaml")))
    if args.language:
        words = [w for w in words if w.language == args.language]
    proposals = propose(words, written=args.all)
    for p in proposals:
        print(describe(p))
        print("    " + note_for(p.a, p.b))
        print("    " + note_for(p.b, p.a))
    print(f"{len(proposals)} proposed pairs among {len(words)} words")
    return 0


if __name__ == "__main__":
    sys.exit(main())
