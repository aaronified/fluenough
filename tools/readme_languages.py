#!/usr/bin/env python3
"""Fills the README's languages list from decks/index.json.

    python3 tools/readme_languages.py            # rewrite the list
    python3 tools/readme_languages.py --check    # exit 1 if it is stale

The list is the table between `<!-- languages:start -->` and
`<!-- languages:end -->` in README.md: a line giving the number of
languages, then one row per language the index offers, with its name, its
language family and subfamily, the scripts it is written in, and the highest
level whose units are all written. That is A1, A2 or B1, or "in progress"
before A1. The deck-index workflow runs it after `tools/deck_index.py`, so
the list follows the decks.

The family and subfamily come from `tools/language_families.yaml`, a data
file of the tools alone (the app does not read it), keyed by language code.

A level is reached when every unit of the path up to and including the one
that carries its milestone is written (not `planned`). The levels are
approximate: they come from the path's units and their word counts, and no
exam is behind them (wiki/Proficiency-Levels.md).

The notation courses (the IPA and English Braille) teach no language and
have no levels: they are not listed.

Stdlib and PyYAML only, like the other deck tools.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
INDEX = ROOT / "decks" / "index.json"
LANGUAGES = ROOT / "assets" / "languages.yaml"
FAMILIES = ROOT / "tools" / "language_families.yaml"
ARB = ROOT / "lib" / "l10n" / "app_en.arb"
README = ROOT / "README.md"

START = "<!-- languages:start -->"
END = "<!-- languages:end -->"

# Courses that teach a notation, not a language (as tools/deck_index.py).
NOTATION_CODES = {"ipa", "qbe"}

LEVELS = ("A1", "A2", "B1")
IN_PROGRESS = "in progress"
UNKNOWN = "\u2014"


def script_names(arb_text: str) -> dict[str, str]:
    """The app's name for each script, from `scriptName` in app_en.arb, such
    as `bengali` for Eastern Nagari."""
    arb = json.loads(arb_text)
    message = arb.get("scriptName", "")
    return {code: name for code, name in
            re.findall(r"(\w+)\{([^{}]+)\}", message) if code != "other"}


def language_scripts(languages_yaml: str) -> dict[str, list[str]]:
    """Each language's scripts, its own first, from assets/languages.yaml."""
    raw = yaml.safe_load(languages_yaml) or {}
    found: dict[str, list[str]] = {}
    for entry in raw.get("languages", []):
        if isinstance(entry, dict) and isinstance(entry.get("code"), str) \
                and isinstance(entry.get("scripts"), list):
            found[entry["code"]] = [s for s in entry["scripts"]
                                    if isinstance(s, str)]
    return found


def language_families(families_yaml: str) -> dict[str, tuple[str, str]]:
    """Each language's (family, subfamily), from tools/language_families.yaml.
    Entries that are not a pair of strings are left out."""
    raw = yaml.safe_load(families_yaml) or {}
    return {code: (pair[0], pair[1]) for code, pair in raw.items()
            if isinstance(pair, list) and len(pair) == 2
            and all(isinstance(x, str) for x in pair)}


def level_reached(units: list[dict]) -> str:
    """The highest of A1, A2 and B1 whose units, from the first to the one
    carrying the milestone, are all written; else "in progress"."""
    reached = IN_PROGRESS
    for unit in units:
        if unit.get("planned"):
            break
        milestone = unit.get("milestone")
        if milestone in LEVELS:
            reached = milestone
    return reached


def rows(index: dict, names: dict[str, str], scripts: dict[str, list[str]],
         families: dict[str, tuple[str, str]] | None = None,
         ) -> list[tuple[str, str, str, str, str]]:
    """(language, family, subfamily, scripts, level) for each language of
    [index], by name. A language with no entry in [families] shows an em dash
    for both (the tests fail on it)."""
    found = []
    for language in index.get("languages", []):
        code = language.get("code")
        if code in NOTATION_CODES:
            continue
        codes = scripts.get(code) or (
            [language["script"]] if language.get("script") else [])
        shown = ", ".join(names.get(s, s) for s in codes)
        name = language.get("name") or code
        family, subfamily = (families or {}).get(code, (UNKNOWN, UNKNOWN))
        found.append((name, family, subfamily, shown,
                      level_reached(language.get("units", []))))
    return sorted(found, key=lambda row: row[0].casefold())


def summary(found: list) -> str:
    """The line above the table: how many languages it lists."""
    return f"**{len(found)} languages**"


def table(found: list[tuple[str, str, str, str, str]]) -> str:
    """The Markdown block for [found]: the count, then the table."""
    lines = [summary(found), "",
             "| Language | Family | Subfamily | Scripts | Level reached |",
             "|---|---|---|---|---|"]
    lines += [f"| {name} | {family} | {subfamily} | {shown} | {level} |"
              for name, family, subfamily, shown, level in found]
    return "\n".join(lines)


def fill(readme: str, block: str) -> str:
    """[readme] with [block] between the markers. Raises ValueError when a
    marker is missing."""
    start = readme.find(START)
    end = readme.find(END)
    if start < 0 or end < start:
        raise ValueError(f"README.md needs {START} and {END}, in that order")
    return readme[:start + len(START)] + "\n" + block + "\n" + readme[end:]


def build(index_path: Path = INDEX, readme_path: Path = README) -> str:
    """The README as it should be."""
    index = json.loads(index_path.read_text(encoding="utf-8"))
    names = script_names(ARB.read_text(encoding="utf-8"))
    scripts = language_scripts(LANGUAGES.read_text(encoding="utf-8"))
    families = language_families(FAMILIES.read_text(encoding="utf-8"))
    block = table(rows(index, names, scripts, families))
    with readme_path.open(encoding="utf-8", newline="") as f:
        return fill(f.read(), block)


def main(argv: list[str]) -> int:
    args = argv[1:]
    if args not in ([], ["--check"]):
        print("usage: readme_languages.py [--check]", file=sys.stderr)
        return 2
    try:
        text = build()
    except (OSError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    with README.open(encoding="utf-8", newline="") as f:
        current = f.read()
    if text == current:
        return 0
    if args:
        print("error: the README's languages list is stale; run "
              "python3 tools/readme_languages.py", file=sys.stderr)
        return 1
    with README.open("w", encoding="utf-8", newline="") as f:
        f.write(text)
    print("updated the languages list in README.md")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
