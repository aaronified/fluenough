#!/usr/bin/env python3
"""Check, and optionally fix, the stored `reading` and `ipa` of a language's
core decks against `tools/transcribe.py` (issue #1295).

Usage:
    python3 tools/transcribe_decks.py --check decks/te te
    python3 tools/transcribe_decks.py --fix decks/te te         # anusvara only
    python3 tools/transcribe_decks.py --fix --all decks/te te   # every difference

For each core deck file directly in the directory (the English layers in
`en/` are not read), every card, every card example and every
`{ word: ..., reading: ... }` entry (a card's bases and its notes' words) is
re-transcribed from its target text with the same logic as the single-word
mode: the stored reading is the typed hint, exactly as
`python3 tools/transcribe.py te "<target>" "<reading>"` would take it. A
stored value that differs from the recomputed one is printed with its id, the
field, the stored value and the recomputed value.

A difference is listed under "anusvara differences" when the target holds an
anusvara and the two values are the same once every nasal is treated as one
sound (the written nasal before a stop, ISO `ṁ`, IPA `ŋ ɲ ɳ n m`): that is
the medial-anusvara rule ("Telugu medial anusvara" in
wiki/Plan-Ipa-Revamp-And-Language-Phonology.md). Every other difference (ph
for f, ṛ for r̥, ...) is listed under "other differences".

`--check` exits 1 if anything differs, else 0. `--fix` rewrites only the
differing values, and only the anusvara ones unless `--all` is given. It never
re-dumps the YAML: it replaces the exact stored value on its own line, so
comments, quoting and ordering stay byte for byte. An entry whose reading or
ipa line is repeated or not a plain double-quoted string, or whose card id is
repeated in the file, is reported as "not changed" and left alone. Card ids
are never touched.

Standard library only, like the other deck tools.
"""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

from transcribe import transcribe

_ID = re.compile(r'^\s*- id: "([^"]+)"\s*$')
_KEY = re.compile(r'^(\s*)(?:- )?(target|reading|ipa): "([^"\\]*)"\s*(?:#.*)?$')
_LOOSE = re.compile(r"^\s*(?:- )?(target|reading|ipa):")
_FLOW = re.compile(r'\{[^{}]*\bword: "([^"\\]*)"[^{}]*\}')
_FLOW_READING = re.compile(r'\breading: "([^"\\]*)"')
_FLOW_BASE = re.compile(r'\bbase: "([^"\\]*)"')

_NASAL_ISO = re.compile("[ṁṃṅñṇnm]")
_NASAL_IPA = re.compile("n̪|[ŋɲɳnm]")


@dataclass
class Difference:
    file: Path
    entry: str          # the card id, its example, or its word entry
    field: str
    stored: str
    computed: str
    line: int           # 0-based line holding the stored value
    anusvara: bool


@dataclass
class Report:
    differences: list[Difference] = field(default_factory=list)
    unreadable: list[str] = field(default_factory=list)


def _has_anusvara(text: str) -> bool:
    return any("ANUSVARA" in unicodedata.name(c, "") for c in text)


def _same_but_nasals(field_name: str, stored: str, computed: str) -> bool:
    rx = _NASAL_IPA if field_name == "ipa" else _NASAL_ISO
    return rx.sub("N", stored) == rx.sub("N", computed)


def _is_anusvara(target: str, name: str, stored: str, computed: str) -> bool:
    return _has_anusvara(target) and _same_but_nasals(name, stored, computed)


def _entry_fields(lines: list[str], i: int, indent: int) -> dict:
    """The `reading` and `ipa` lines of the entry whose `target` is on line
    [i] with its keys at [indent]: name -> (line, value), or (reason, None)
    when the field is repeated or is not a plain double-quoted string."""
    fields: dict[str, tuple] = {}
    count: dict[str, int] = {}
    for j in range(i + 1, len(lines)):
        nxt = lines[j]
        if nxt.strip() == "" or nxt.lstrip().startswith("#"):
            continue
        ind = len(nxt) - len(nxt.lstrip())
        if ind < indent:
            break
        if ind != indent:
            continue  # nested lines (a card's examples) are other entries
        if nxt.lstrip().startswith("- "):
            break
        loose = _LOOSE.match(nxt)
        if not loose:
            continue
        name = loose.group(1)
        if name == "target":
            break
        count[name] = count.get(name, 0) + 1
        km = _KEY.match(nxt)
        fields[name] = ((j, km.group(3)) if km else
                        ("not a plain double-quoted value", None))
    for name, n in count.items():
        if n > 1:
            fields[name] = (f"{name} given more than once", None)
    return fields


def _check_entry(path, entry, target, fields, lang, report) -> None:
    stored_reading = fields.get("reading", (None, None))[1]
    try:
        t = transcribe(target, lang, stored_reading)
    except Exception as e:  # CannotRead, or a rule's own error
        report.unreadable.append(f"{path.name} {entry}: {e!r}")
        return
    computed = {"reading": t.reading, "ipa": t.ipa}
    for name in ("reading", "ipa"):
        if name not in fields:
            continue
        where, stored = fields[name]
        if stored is None:
            report.unreadable.append(f"{path.name} {entry}: {name}: {where}")
        elif stored != computed[name]:
            report.differences.append(Difference(
                path, entry, name, stored, computed[name], where,
                _is_anusvara(target, name, stored, computed[name])))


def scan(path: Path, lang: str, report: Report) -> None:
    """Walk one deck file's lines, filling [report]."""
    lines = path.read_text(encoding="utf-8").split("\n")
    ids: dict[str, int] = {}
    for ln in lines:
        m = _ID.match(ln)
        if m:
            ids[m.group(1)] = ids.get(m.group(1), 0) + 1
    card = "?"
    for i, ln in enumerate(lines):
        m = _ID.match(ln)
        if m:
            card = m.group(1)
        m = _KEY.match(ln)
        if m and m.group(2) == "target":
            is_item = ln.lstrip().startswith("- ")
            indent = len(m.group(1)) + (2 if is_item else 0)
            entry = f"{card}/example@{i + 1}" if is_item else card
            fields = _entry_fields(lines, i, indent)
            if not is_item and ids.get(card, 0) > 1:
                fields = {n: (f"card id {card} repeated in the file", None)
                          for n in fields}
            _check_entry(path, entry, m.group(3), fields, lang, report)
        for fm in _FLOW.finditer(ln):
            _check_word(path, card, i, ln, fm.group(0), fm.group(1),
                        lang, report)


def _check_word(path, card, i, ln, body, word, lang, report) -> None:
    """A flow entry `{ word: ..., reading: ... }`: its reading only."""
    rm = list(_FLOW_READING.finditer(body))
    if not rm:
        return
    bm = _FLOW_BASE.search(body)
    if bm and bm.group(1) != word:
        return  # the reading may be the base's, not the word's
    entry = f"{card}/word:{word}"
    stored = rm[0].group(1)
    if len(rm) > 1 or ln.count(f'reading: "{stored}"') > 1:
        report.unreadable.append(
            f"{path.name} {entry}: reading found more than once on the line")
        return
    try:
        reading = transcribe(word, lang, stored).reading
    except Exception as e:
        report.unreadable.append(f"{path.name} {entry}: {e!r}")
        return
    if reading != stored:
        report.differences.append(Difference(
            path, entry, "reading", stored, reading, i,
            _is_anusvara(word, "reading", stored, reading)))


def deck_files(directory: Path) -> list[Path]:
    """The core deck files directly in [directory] (not its `en/` layers)."""
    out = []
    for p in sorted(directory.glob("*.yaml")):
        head = p.read_text(encoding="utf-8").split("cards:", 1)[0]
        if re.search(r'^part: "core"', head, re.M):
            out.append(p)
    return out


def run(directory: Path, lang: str) -> Report:
    report = Report()
    for p in deck_files(directory):
        scan(p, lang, report)
    return report


def apply_fixes(report: Report, include_other: bool) -> tuple[int, list[str]]:
    """Patch the differing values in place. Returns (changed, refusals)."""
    changed = 0
    refused: list[str] = []
    by_file: dict[Path, list[Difference]] = {}
    for d in report.differences:
        if d.anusvara or include_other:
            by_file.setdefault(d.file, []).append(d)
    for path, diffs in by_file.items():
        lines = path.read_bytes().decode("utf-8").split("\n")
        for d in diffs:
            old = f'{d.field}: "{d.stored}"'
            if lines[d.line].count(old) != 1:
                refused.append(f"{path.name} {d.entry} {d.field}: stored "
                               "value not found once on its line")
                continue
            lines[d.line] = lines[d.line].replace(
                old, f'{d.field}: "{d.computed}"')
            changed += 1
        path.write_bytes("\n".join(lines).encode("utf-8"))
    return changed, refused


def _print(report: Report) -> None:
    for title, flag in (("anusvara differences", True),
                        ("other differences", False)):
        rows = [d for d in report.differences if d.anusvara == flag]
        print(f"{title}: {len(rows)}")
        for d in rows:
            print(f"  {d.file.name} {d.entry} {d.field}: "
                  f"stored {d.stored!r} -> computed {d.computed!r}")
    if report.unreadable:
        print(f"not checked or not changeable: {len(report.unreadable)}")
        for u in report.unreadable:
            print(f"  {u}")
    print(f"total differences: {len(report.differences)}")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--fix", action="store_true")
    ap.add_argument("--all", action="store_true",
                    help="with --fix, also fix the other differences")
    ap.add_argument("directory", type=Path)
    ap.add_argument("lang")
    args = ap.parse_args(argv[1:])
    if not args.directory.is_dir():
        print(f"not a directory: {args.directory}", file=sys.stderr)
        return 2
    report = run(args.directory, args.lang)
    _print(report)
    if args.check:
        return 1 if report.differences else 0
    changed, refused = apply_fixes(report, args.all)
    print(f"changed {changed} value(s)")
    for r in refused:
        print(f"  refused: {r}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
