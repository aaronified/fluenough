#!/usr/bin/env python3
"""Validate the English synonym sets (ADR-0050, #924).

Usage:
    python3 tools/validate_synonyms.py assets/synonyms/en.yaml [decks/]
    # 0 ok, 1 errors, 2 bad args

The file is a list of lists in a restricted YAML subset that the app's own
small parser (`lib/core/grading/synonym_sets.dart`) reads:

    # header comment: what it is, CC BY-SA 4.0, where the credit is
    version: 1
    sets:
      - ["colour", "color"]

Checks, on the file: a header that names the licence; `version: 1`; one set
per line with every member in double quotes; no set under two members; no
empty member; no repeat; every member in its comparison form (what the
app's `meaningKey` makes of it); members sorted within a set, and sets by
first member; no word in two sets (the error names the sets to merge).

With a decks directory it also reads every English layer card's
`not_synonyms`: an entry must be in comparison form and must be a member of
a set that has another member among the card's own answers (else it does
nothing); and a set escaped on two or more cards fails, because "absolutely
synonymous" is then false (plan question 6, recommendation A).

Stdlib plus PyYAML, like the deck validator. `meaning_key` mirrors
`lib/core/grading/meaning_rules.dart`; keep the two in step.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

IRREGULAR = {
    "can't": "can not", "cannot": "can not", "won't": "will not",
    "shan't": "shall not", "let's": "let us", "i'm": "i am",
    "ain't": "is not",
}
SUFFIXES = {"'s": " is", "'re": " are", "'ll": " will", "'ve": " have",
            "'d": " would"}
BRACKETS = re.compile(r"\([^)]*\)|\[[^\]]*\]")
PUNCTUATION = re.compile(r"""[.,!?;:"'()\[\]]""")


def _expand(word: str) -> str:
    if word in IRREGULAR:
        return IRREGULAR[word]
    if word.endswith("n't") and len(word) > 3:
        return word[:-3] + " not"
    for suffix, value in SUFFIXES.items():
        if word.endswith(suffix) and len(word) > len(suffix):
            return word[: -len(suffix)] + value
    return word


def meaning_key(meaning: str) -> str:
    """The comparison form of one meaning, as the app's `meaningKey`."""
    text = meaning.lower()
    text = re.sub("[‘’ʼ`´]", "'", text)
    text = re.sub("[“”]", '"', text)
    text = BRACKETS.sub(" ", text)
    text = re.sub(r"\bo\.k\b\.?", "ok", text)
    text = " ".join(_expand(w) for w in re.split(r"\s+", text))
    text = PUNCTUATION.sub(" ", text).strip()
    words = ["ok" if w == "okay" else w for w in text.split() if w]
    if len(words) > 1:
        words = [w for w in words if w != "please"]
    if len(words) > 1 and words[0] == "to":
        words = words[1:]
    return " ".join(words)


SET_LINE = re.compile(r"^-\s*\[(.*)\]$")
QUOTED = re.compile(r'^"([^"\\]*)"$')


def parse(text: str) -> tuple[list[tuple[int, list[str]]], list[str]]:
    """(line number, members) for each set, and the format errors."""
    errors: list[str] = []
    sets: list[tuple[int, list[str]]] = []
    header = False
    version = False
    in_sets = False
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            if "CC BY-SA 4.0" in line:
                header = True
            continue
        if line.startswith("version:"):
            version = True
            if line[len("version:"):].strip() != "1":
                errors.append(f"line {number}: version must be 1")
            continue
        if line in ("sets:", "sets: []"):
            in_sets = True
            continue
        match = SET_LINE.match(line)
        if not in_sets or not match:
            errors.append(f"line {number}: not a set line "
                          f'(expected - ["a", "b"] after "sets:"): {line}')
            continue
        members: list[str] = []
        for part in match.group(1).split(","):
            quoted = QUOTED.match(part.strip())
            if not quoted:
                errors.append(f"line {number}: member {part.strip()!r} is "
                              f"not in double quotes")
                continue
            members.append(quoted.group(1))
        sets.append((number, members))
    if not header:
        errors.append("the header comment must name the licence, CC BY-SA 4.0")
    if not version:
        errors.append("missing 'version: 1'")
    if not in_sets:
        errors.append("missing 'sets:'")
    return sets, errors


def check_sets(text: str) -> list[str]:
    sets, errors = parse(text)
    owner: dict[str, int] = {}
    first_members: list[str] = []
    for number, members in sets:
        if len(members) < 2:
            errors.append(f"line {number}: a set needs two members")
        for member in members:
            if not member.strip():
                errors.append(f"line {number}: empty member")
            elif meaning_key(member) != member:
                errors.append(
                    f"line {number}: {member!r} is not in comparison form "
                    f"(write {meaning_key(member)!r})")
        if len(set(members)) != len(members):
            errors.append(f"line {number}: a member is repeated")
        if members != sorted(members):
            errors.append(f"line {number}: members are not sorted")
        if members:
            first_members.append(sorted(members)[0])
        for member in set(members):
            if member in owner and owner[member] != number:
                errors.append(
                    f"line {number}: {member!r} is also in the set on line "
                    f"{owner[member]}: merge the two sets, or one of them is "
                    f"not absolutely synonymous")
            owner.setdefault(member, number)
    if first_members != sorted(first_members):
        errors.append("sets are not sorted by their first member")
    return errors


def answers(entry: dict) -> list[str]:
    out: list[str] = []
    values = [entry.get("native")]
    alt = entry.get("alt_native")
    values += alt if isinstance(alt, list) else [alt]
    for value in values:
        if not isinstance(value, str):
            continue
        for part in BRACKETS.sub(" ", value).split(";"):
            key = meaning_key(part)
            if key:
                out.append(key)
                for article in ("a ", "an ", "the "):
                    if key.startswith(article):
                        out.append(key[len(article):])
    return out


def set_index(text: str) -> tuple[list[tuple[int, list[str]]], dict[str, int]]:
    """The sets of [text], and the index of the set each member is in."""
    sets, _ = parse(text)
    set_of: dict[str, int] = {}
    for index, (_, members) in enumerate(sets):
        for member in members:
            set_of.setdefault(member, index)
    return sets, set_of


def refusal_blocks(set_of: dict[str, int], entry: dict, word: str) -> bool:
    """Whether refusing [word] on [entry] does something: it is in a set
    that has another member among the card's own answers."""
    index = set_of.get(word)
    return index is not None and index in {set_of[a] for a in answers(entry)
                                           if a in set_of}


def check_decks(text: str, decks: Path) -> list[str]:
    errors, escaped, sets, _ = scan_decks(text, decks)
    for index, cards in sorted(escaped.items()):
        if len(set(cards)) >= 2:
            members = ", ".join(sets[index][1])
            errors.append(
                f"the set [{members}] is escaped by not_synonyms on "
                f"{len(set(cards))} cards ({', '.join(sorted(set(cards)))}): "
                f"remove or split it")
    return errors


def scan_decks(text: str, decks: Path) -> tuple[list[str], dict[int, list[str]],
                                                list[tuple[int, list[str]]],
                                                dict[str, int]]:
    """The errors of each card's `not_synonyms`, the cards that escape each
    set (by its index), and the sets and their members' index."""
    import yaml  # PyYAML, as the deck validator

    sets, set_of = set_index(text)
    errors: list[str] = []
    escaped: dict[int, list[str]] = {}
    for path in sorted(decks.rglob("*.yaml")):
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8"))
        except Exception:
            continue  # the deck validator reports it
        if not isinstance(data, dict):
            continue
        native = data.get("native")
        if not isinstance(native, dict) or native.get("code") != "en":
            continue
        cards = data.get("cards")
        # A layer maps card ids to entries; a single-file deck lists cards.
        if isinstance(cards, dict):
            pairs = list(cards.items())
        elif isinstance(cards, list):
            pairs = [(c.get("ref") or c.get("id"), c) for c in cards
                     if isinstance(c, dict)]
        else:
            continue
        for card_id, entry in pairs:
            if not isinstance(entry, dict) or "not_synonyms" not in entry:
                continue
            where = f"{path.name}: {card_id}"
            values = entry["not_synonyms"]
            if not isinstance(values, list):
                errors.append(f"{where}: not_synonyms must be a list")
                continue
            answer_sets = {set_of[a] for a in answers(entry) if a in set_of}
            for value in values:
                if not isinstance(value, str) or meaning_key(value) != value:
                    errors.append(f"{where}: not_synonyms entry {value!r} is "
                                  f"not a quoted comparison form")
                    continue
                index = set_of.get(value)
                if index is None or index not in answer_sets:
                    errors.append(
                        f"{where}: not_synonyms entry {value!r} blocks "
                        f"nothing: it is not in a set that has another "
                        f"member among the card's answers")
                else:
                    escaped.setdefault(index, []).append(card_id)
    return errors, escaped, sets, set_of


def validate(text: str, decks: Path | None = None) -> list[str]:
    errors = check_sets(text)
    if decks is not None:
        errors += check_decks(text, decks)
    return errors


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3):
        print(__doc__.split("\n\n")[0], file=sys.stderr)
        return 2
    path = Path(argv[1])
    decks = Path(argv[2]) if len(argv) == 3 else None
    if not path.is_file() or (decks is not None and not decks.is_dir()):
        print("no such file or directory", file=sys.stderr)
        return 2
    errors = validate(path.read_text(encoding="utf-8"), decks)
    for error in errors:
        print(f"{path}: {error}")
    if errors:
        print(f"{len(errors)} error(s)")
        return 1
    print(f"{path}: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
