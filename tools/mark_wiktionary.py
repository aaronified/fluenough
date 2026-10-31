#!/usr/bin/env python3
"""Mark the cards whose word has a Wiktionary entry (#422).

Usage:
    python3 tools/mark_wiktionary.py hi Hindi.jsonl                  # report only
    python3 tools/mark_wiktionary.py hi Hindi.jsonl --write          # mark the decks
    python3 tools/mark_wiktionary.py hi Hindi.jsonl --section Hindi  # keep one section

`Hindi.jsonl` is the language's Wiktextract dump from kaikki.org (the English
Wiktionary), as `tools/import_wiktionary.py` reads it. Nothing is fetched:
the tool reads the file it is given and the decks.

The app links a word to its Wiktionary page only where the deck says an entry
exists: `wiktionary: true` on the card's entry in the English layer (DECK-FORMAT.md,
"The Wiktionary link"). This tool sets that mark and nothing else, on every
vocab card of the language's cores whose target is exactly the title of an
entry in the dump. A card already marked is left alone, and so is a card
written in flow style, as in the importer, which also sets the mark on the
cards it fills. A sentence, or an inflected form that has no page of its own,
is never found, and its base words carry the mark.

`--section NAME` keeps only entries whose language is NAME, for a dump that
holds more than one language. The dump says nothing of other Wiktionaries, so
only the English layer is marked: another native language's layer is marked
from that edition's own extract, by hand until a tool reads one.

A mark is only ever added, never removed: the report lists a marked card the
dump has no entry for, for a person to check. The edit is a line in the
layer's file, so a diff shows only the marks (AGENTS.md rule 8). Run
`python3 tools/validate_decks.py decks/` after `--write`.

Needs only Python 3.11+ and PyYAML, like the other deck tools.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import import_wiktionary as iw  # noqa: E402
import validate_decks as vd  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent


def titles(dump: Path, section: str | None = None) -> set[str]:
    """The titles of the dump's entries, NFC, of [section] if given."""
    found: set[str] = set()
    with dump.open(encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            entry = json.loads(line)
            word = entry.get("word")
            if not isinstance(word, str):
                continue
            if section is not None and entry.get("lang") != section:
                continue
            found.add(iw.nfc(word))
    return found


def mark_text(text: str, cid: str) -> str | None:
    """[text] with `wiktionary: true` added to card [cid]'s layer entry, or
    None when the entry is not found in a form this tool edits: a block-style
    head `  "id":` alone on its line, or a flow map `  "id": { ... }` with no
    comment after it."""
    head = re.compile(rf'^  "{re.escape(cid)}":\s*$')
    new = iw.apply(text, head, 2, [("native", ["    wiktionary: true"])])
    if new != text:
        return new
    flow = re.compile(rf'^(  "{re.escape(cid)}":\s*\{{)(.*?)(\s*\}})\s*$')
    lines = text.split("\n")
    for i, line in enumerate(lines):
        m = flow.match(line)
        if m and "#" not in m.group(2) and "wiktionary" not in m.group(2):
            body = m.group(2).rstrip()
            sep = "" if not body.strip() else (" " if body.endswith(",") else ", ")
            lines[i] = f"{m.group(1)}{body}{sep}wiktionary: true{m.group(3)}"
            return "\n".join(lines)
    return None


def run(code: str, dump: Path, decks: Path, write: bool,
        section: str | None = None) -> str:
    """Mark the decks, when [write], and say what was found."""
    return mark(code, dump, decks, write, section)[0]


def mark(code: str, dump: Path, decks: Path, write: bool,
         section: str | None = None) -> tuple[str, int]:
    """Like [run], and also the number of cards that could not be marked."""
    lang = iw.read_language(decks, code)
    entries = titles(dump, section)
    add: list[iw.Target] = []
    already: list[iw.Target] = []
    stale: list[iw.Target] = []
    none: list[iw.Target] = []
    off: list[iw.Target] = []
    unmatched: list[iw.Target] = []
    unlayered: list[iw.Target] = []
    for t in lang.targets:
        if t.layer is None or t.entry is None:
            unlayered.append(t)
        elif t.entry.get("wiktionary") is True:
            (already if t.target in entries else stale).append(t)
        elif "wiktionary" in t.entry:
            # `wiktionary: false` (or anything else) is a person's choice:
            # never a second key, never rewritten.
            off.append(t)
        elif t.target in entries:
            add.append(t)
        else:
            none.append(t)
    if write:
        by_file: dict[Path, list[iw.Target]] = {}
        marked: list[iw.Target] = []
        for t in add:
            by_file.setdefault(t.layer, []).append(t)
        for path, targets in by_file.items():
            text = path.read_text(encoding="utf-8")
            for t in targets:
                new = mark_text(text, t.cid)
                if new is None:
                    unmatched.append(t)
                else:
                    text = new
                    marked.append(t)
            path.write_text(text, encoding="utf-8")
        add = marked
    verb = "marked" if write else "to mark"
    out = [f"# Wiktionary marks for {code}",
           f"- {verb}: {len(add)}",
           f"- already marked: {len(already)}",
           f"- no entry in the dump: {len(none)}",
           f"- no English layer entry (not marked): {len(unlayered)}",
           f"- left out, written in flow style: {len(lang.flow)}"]
    if off:
        out.append("- `wiktionary` already set to something else, left alone: "
                   + ", ".join(f"{t.cid} {t.target}" for t in off))
    if unmatched:
        out.append("- unmatched, entry not in a form the tool edits "
                   "(edit by hand): "
                   + ", ".join(f"{t.cid} {t.target}" for t in unmatched))
    if stale:
        out.append(f"- marked but not in the dump, check by hand: "
                   + ", ".join(f"{t.cid} {t.target}" for t in stale))
    return "\n".join(out) + "\n", len(unmatched)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Mark the cards whose word has a Wiktionary entry, "
                    "from kaikki.org's extract.")
    parser.add_argument("lang", help="the language's code, such as hi")
    parser.add_argument("dump", type=Path, help="the language's kaikki.org JSONL")
    parser.add_argument("--decks", type=Path, default=ROOT / "decks",
                        help="the decks folder (default: the repository's)")
    parser.add_argument("--section", help="keep only entries of this language, "
                                          "as the dump names it: Hindi")
    parser.add_argument("--write", action="store_true",
                        help="mark the decks; without it, only report")
    args = parser.parse_args(argv[1:])
    if not vd.LANG_RE.fullmatch(args.lang) or not (args.decks / args.lang).is_dir():
        print(f"error: no decks for {args.lang!r} in {args.decks}", file=sys.stderr)
        return 2
    if not args.dump.is_file():
        print(f"error: {args.dump} does not exist", file=sys.stderr)
        return 2
    report, unmatched = mark(args.lang, args.dump, args.decks, args.write,
                             args.section)
    print(report, end="")
    return 1 if unmatched else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
