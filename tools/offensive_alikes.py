#!/usr/bin/env python3
"""Sound-alike and look-alike lists for offensive words (#629; plan:
wiki/Plan-Offensive-Words.md, owner, 2026-10-09).

Compares each word of a language with the language's offensive words twice,
and lists the close pairs for a reviewer:

- by sound: the two IPA transcriptions differ by at most one segment
  ("sounds like": care when speaking);
- by writing: the two spellings, in the script or in its ISO 15919-based
  reading, differ by at most one letter or mark ("looks like": care when
  writing).

A reviewer keeps the real pairs and explains each with a note of at most 40
letters ("keep the long ā"): a `pair` note on the word, naming the offensive
word by `ref`, for a sound-alike; a `lookalike` or `homograph` note for a
look-alike. The deck validator warns about a close pair left unexplained
(`warn_alikes_across` in tools/validate_decks.py, which uses this module).

A reviewer who rejects a pair, because the two words are not alike enough to
need care, records it on the card with `not_sounds_like` or `not_looks_like`,
a list of the offensive words' ids (#808): the pair is then no longer
listed as unexplained, and the validator does not warn of it.

An offensive word is a card registered or tagged `offensive`, or any card of
a deck tagged `offensive`. Two offensive words are never paired with each
other, and a word shorter than three segments or letters is left out: a
short word is close to many.

    python3 tools/offensive_alikes.py decks/ --language te
    python3 tools/offensive_alikes.py decks/ --unexplained

The list is for a person to read; the tool changes no file.
"""

from __future__ import annotations

import argparse
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from pick_warning import distance, letters, segments

RUDE = "offensive"

# The note kinds that explain a pair, by the kind of closeness.
SOUND_NOTES = ("pair",)
LOOK_NOTES = ("lookalike", "homograph")

# The card keys that record a rejected pair, by the kind of closeness: the
# card lists the ids of the offensive words that only seemed close (#808).
SOUND_REJECTED = "not_sounds_like"
LOOK_REJECTED = "not_looks_like"

# The most letters a care note may have (owner, 2026-10-09).
CARE_LIMIT = 40

# The fewest segments or letters a word has to be compared: a shorter one
# is within one edit of too many words.
MIN_LENGTH = 3

# How far apart two words may be and still be listed.
MAX_DISTANCE = 1


@dataclass
class Word:
    """A card as the comparison reads it."""

    id: str
    language: str
    path: Path
    target: str = ""
    reading: str = ""
    ipa: str = ""
    rude: bool = False
    # (kind, ref) of each note naming another card, and the card's `pair`.
    notes: list[tuple[str, str]] = field(default_factory=list)
    # The ids this card says it is not like, by sound and by writing.
    not_sounds_like: list[str] = field(default_factory=list)
    not_looks_like: list[str] = field(default_factory=list)


@dataclass
class Alike:
    """A word close to an offensive one."""

    kind: str          # "sound" or "look"
    word: Word
    rude: Word
    distance: int
    basis: str         # "ipa", "script" or "reading"
    explained: bool

    @property
    def phrase(self) -> str:
        return "sounds like" if self.kind == "sound" else "looks like"


def _language(data: dict, path: Path) -> str:
    language = data.get("language")
    if isinstance(language, dict) and isinstance(language.get("code"), str):
        return language["code"]
    if isinstance(language, str):
        return language
    return path.parent.name


def _str(value: object) -> str:
    return value if isinstance(value, str) else ""


def _with_offensive_words(paths: list[Path]) -> list[Path]:
    """The files in the folders (languages) where some file says
    `offensive`: reading every deck's YAML is slow and a language with no
    offensive word has nothing to compare."""
    folders: set[Path] = set()
    for path in paths:
        try:
            if RUDE in path.read_text(encoding="utf-8"):
                folders.add(path.parent)
        except OSError:
            continue
    return [p for p in paths if p.parent in folders]


def load_words(paths: list[Path]) -> list[Word]:
    """The cards the files write, a core's and a single-file deck's alike,
    for the languages that have an offensive word. A layer, which writes no
    `target`, adds none."""
    words: dict[str, Word] = {}
    for path in _with_offensive_words(paths):
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
                path=path,
                target=card["target"],
                reading=_str(card.get("reading")),
                ipa=_str(card.get("ipa")),
                rude=(card.get("register") == RUDE or RUDE in tags
                      or RUDE in deck_tags),
            )
            for key, into in ((SOUND_REJECTED, word.not_sounds_like),
                              (LOOK_REJECTED, word.not_looks_like)):
                refs = card.get(key)
                if isinstance(refs, list):
                    into.extend(r for r in refs if isinstance(r, str))
            if isinstance(card.get("pair"), str):
                word.notes.append(("pair", card["pair"]))
            notes = card.get("notes")
            for note in notes if isinstance(notes, list) else []:
                if isinstance(note, dict) and isinstance(note.get("ref"), str):
                    word.notes.append((str(note.get("kind")), note["ref"]))
            words[word.id] = word
    return list(words.values())


def _reading_letters(text: str) -> list[str]:
    """A reading as lowercase code points, decomposed, so that a length mark
    or a dot under a letter is one edit: ā is not a."""
    return [ch for ch in unicodedata.normalize("NFD", text.lower())
            if not ch.isspace() and ch not in "-'’"]


def _explained(word: Word, rude: Word, kinds: tuple[str, ...],
               rejected: str) -> bool:
    """Whether either word has a note of one of [kinds] naming the other, or
    lists the other under the card key [rejected]: a reviewer kept the pair,
    or rejected it."""
    return (any(k in kinds and ref == rude.id for k, ref in word.notes)
            or any(k in kinds and ref == word.id for k, ref in rude.notes)
            or rude.id in getattr(word, rejected)
            or word.id in getattr(rude, rejected))


def _close(a: list[str], b: list[str], limit: int) -> int | None:
    """The distance between [a] and [b] if both are long enough to compare
    and it is within [limit], else None."""
    if len(a) < MIN_LENGTH or len(b) < MIN_LENGTH or abs(len(a) - len(b)) > limit:
        return None
    d = distance(a, b)
    return d if d <= limit else None


def find_alikes(words: list[Word], limit: int = MAX_DISTANCE) -> list[Alike]:
    """Every word of a language that is close to one of its offensive words,
    by sound and by writing, nearest first."""
    found: list[Alike] = []
    for language in sorted({w.language for w in words}):
        group = [w for w in words if w.language == language]
        rudes = [w for w in group if w.rude]
        for word in group:
            if word.rude:
                continue
            for rude in rudes:
                if word.ipa and rude.ipa:
                    d = _close(segments(word.ipa), segments(rude.ipa), limit)
                    if d is not None:
                        found.append(Alike("sound", word, rude, d, "ipa",
                                           _explained(word, rude, SOUND_NOTES,
                                                   "not_sounds_like")))
                looks = [("script", _close(letters(word.target),
                                           letters(rude.target), limit))]
                if word.reading and rude.reading:
                    looks.append(("reading", _close(_reading_letters(word.reading),
                                                    _reading_letters(rude.reading),
                                                    limit)))
                near = [(d, basis) for basis, d in looks if d is not None]
                if near:
                    d, basis = min(near)
                    found.append(Alike("look", word, rude, d, basis,
                                       _explained(word, rude, LOOK_NOTES,
                                                   "not_looks_like")))
    found.sort(key=lambda a: (a.word.language, a.distance, a.kind, a.word.id,
                              a.rude.id))
    return found


def unexplained(words: list[Word], limit: int = MAX_DISTANCE) -> list[Alike]:
    """The close pairs no note explains: what the validator warns of."""
    return [a for a in find_alikes(words, limit) if not a.explained]


def warning(alike: Alike) -> str:
    """The validator's warning for an unexplained pair."""
    note = "pair" if alike.kind == "sound" else "lookalike"
    rejected = SOUND_REJECTED if alike.kind == "sound" else LOOK_REJECTED
    how = ("IPA" if alike.basis == "ipa" else alike.basis)
    return (f"{alike.phrase} the offensive word {alike.rude.id} ({how} "
            f"{alike.distance} apart) and no {note} note names it; a reviewer "
            f"keeps or rejects the pair, a kept one gets a {note} note "
            f"with a care note of at most {CARE_LIMIT} letters, and a "
            f"rejected one is listed under {rejected} "
            f"(tools/offensive_alikes.py, #629)")


def describe(alike: Alike) -> str:
    """One line for a reviewer."""
    state = "explained" if alike.explained else "UNEXPLAINED"
    return (f"{alike.word.language}  {alike.phrase:<11} {alike.word.id} "
            f"{alike.word.target} ({alike.word.reading or alike.word.ipa}) ~ "
            f"{alike.rude.id} {alike.rude.target} "
            f"({alike.rude.reading or alike.rude.ipa}); "
            f"{alike.basis} {alike.distance} apart; {state}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("root", type=Path, help="the decks folder")
    parser.add_argument("--language", help="only this language code")
    parser.add_argument("--unexplained", action="store_true",
                        help="only the pairs no note explains")
    parser.add_argument("--distance", type=int, default=MAX_DISTANCE,
                        help="the most segments or letters apart "
                             f"(default {MAX_DISTANCE})")
    args = parser.parse_args(argv)
    words = load_words(sorted(args.root.glob("*/*.yaml")))
    if args.language:
        words = [w for w in words if w.language == args.language]
    alikes = find_alikes(words, args.distance)
    if args.unexplained:
        alikes = [a for a in alikes if not a.explained]
    for alike in alikes:
        print(describe(alike))
    rude = sum(1 for w in words if w.rude)
    print(f"{len(alikes)} close pairs; {rude} offensive words among "
          f"{len(words)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
