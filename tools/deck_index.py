#!/usr/bin/env python3
"""Write decks/index.json: the decks the app downloads from GitHub (#210).

Usage:
    python3 tools/deck_index.py            # write decks/index.json
    python3 tools/deck_index.py --check    # exit 1 if it is out of date

The app reads the index from the repository's main branch, with no token,
and downloads each language's files from there (ADR-0037). For each language
it lists its name, icon and script; the native languages it is taught from;
its path's order, and each unit's planned and counted words, so the
language picker can show completeness toward B1 before a download; and
each file's path, size, SHA-256, schema and kind.

`tools/validate_decks.py decks/` fails when the index is out of date, so CI
keeps it current. Run this after changing any file under decks/.

Needs only Python 3.11+ and PyYAML, like the validator it reads decks with.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks as vd  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DECKS = ROOT / "decks"
INDEX = DECKS / "index.json"

# The index format. The app refuses an index of a newer version and asks
# for an app update; raise it only for a change an older app would misread.
INDEX_VERSION = 1

# Languages kept in the repository, and validated like any other, but not
# offered in the app for now. Remove a line to offer the language.
HIDDEN = {
    # Hidden for now: the app teaches Spanish and the Indic languages.
    "ja",
}

# What ships inside the app rather than downloading (the plan's item 7):
# the theme list. The spoken languages live in assets/, not here.
BUNDLED = {"decks/themes.yaml"}

# Kinds of file that hold no deck: one of each per language at most.
NOT_DECKS = {"path", "facts", "numbers", "romanisation", "sounds", "script"}


def _own_names() -> dict[str, str]:
    """Each language's name for itself, from assets/languages.yaml."""
    raw = vd._load_raw(ROOT / "assets" / "languages.yaml")
    names: dict[str, str] = {}
    if isinstance(raw, dict) and isinstance(raw.get("languages"), list):
        for entry in raw["languages"]:
            if isinstance(entry, dict) and vd._is_str(entry.get("code")) \
                    and vd._is_str(entry.get("own_name")):
                names[entry["code"]] = entry["own_name"]
    return names


def _rel(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


def _top(text: str, key: str) -> str | None:
    """A top-level key's plain value, read from the text: the validator has
    already parsed the file, and parsing it again doubles the run."""
    m = re.search(rf"(?m)^[\"']?{key}[\"']?\s*:\s*[\"']?([A-Za-z0-9-]+)", text)
    return m.group(1) if m else None


def _file_entry(path: Path, rep: vd.Report | None) -> dict:
    data = path.read_bytes()
    text = data.decode("utf-8", errors="replace")
    schema = _top(text, "schema")
    entry: dict = {
        "path": _rel(path),
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "schema": int(schema) if schema is not None and schema.isdigit() else 0,
        "kind": _top(text, "kind") or "vocab",
    }
    if _top(text, "part") == "core":
        entry["part"] = "core"
    if rep is not None and rep.native_code is not None:
        entry["native"] = rep.native_code
    if rep is not None and rep.listed_as is not None:
        entry["deck"] = rep.listed_as
    return entry


def _language_block(files: list[Path]) -> dict:
    """The language block of the first deck that has one."""
    for p in files:
        raw = vd._load_raw(p)
        if isinstance(raw, dict) and isinstance(raw.get("language"), dict):
            return raw["language"]
    return {}


def build(reports: list[vd.Report] | None = None) -> dict:
    """The index of the repository's decks/, from [reports] when the
    validator has them, else from validating every file here."""
    langs = sorted(p for p in DECKS.iterdir() if p.is_dir() and p.name not in HIDDEN)
    paths = [p for d in langs for p in vd._yaml_files(d)]
    if reports is None:
        reports = [vd.validate(p) for p in paths]
    by_path = {rep.path.resolve(): rep for rep in reports}
    missing = [p for p in paths if p.resolve() not in by_path]
    if missing:
        reports = reports + [vd.validate(p) for p in missing]
        by_path.update({rep.path.resolve(): rep for rep in reports})
    ctx = vd._context(reports)
    own = _own_names()
    out = []
    for d in langs:
        code = d.name
        files = vd._yaml_files(d)
        if not files:
            continue
        lang = ctx.lang(code)
        block = _language_block(files)
        entries = [_file_entry(p, by_path.get(p.resolve())) for p in files]
        natives = lang.natives()
        path_rep = lang.path()
        plan = path_rep.plan if path_rep is not None else None
        language: dict = {
            "code": code,
            "name": block.get("name") if vd._is_str(block.get("name")) else code,
        }
        if code in own:
            language["own_name"] = own[code]
        if vd._is_str(block.get("icon")):
            language["icon"] = block["icon"]
        if vd._is_str(block.get("script")):
            language["script"] = block["script"]
        language["script_decks"] = bool(plan and plan.alphabet)
        language["natives"] = [{"code": n, "name": lang.native_name(n)} for n in natives]
        language["size"] = sum(e["size"] for e in entries)
        if plan is not None:
            language["path"] = [core for u in plan.units for core in u.decks]
            units = []
            for u in plan.units:
                unit: dict = {"decks": list(u.decks)}
                if u.planned is not None:
                    unit["planned"] = True
                if u.words is not None:
                    unit["words"] = u.words
                if u.milestone is not None:
                    unit["milestone"] = u.milestone
                if u.grammar:
                    unit["grammar"] = list(u.grammar)
                has = {}
                for n in natives:
                    decks = lang.decks(n)
                    if any(lang.deck_for(n, core) in decks for core in u.decks):
                        has[n] = vd._unit_words(lang, u, plan, decks, n)
                if has:
                    unit["has"] = has
                units.append(unit)
            language["units"] = units
        language["files"] = entries
        out.append(language)
    return {
        "version": INDEX_VERSION,
        "schema": vd.SCHEMA,
        "bundled": sorted(BUNDLED),
        "languages": out,
    }


def render(index: dict) -> str:
    """[index] as the file holds it: stable, one file to a line, so that a
    change to one deck is a one-line diff."""
    def dump(value: object) -> str:
        return json.dumps(value, ensure_ascii=False, sort_keys=True,
                          separators=(", ", ": "))

    lines = ["{"]
    lines.append(f'  "version": {index["version"]},')
    lines.append(f'  "schema": {index["schema"]},')
    lines.append(f'  "bundled": {dump(index["bundled"])},')
    lines.append('  "languages": [')
    for i, language in enumerate(index["languages"]):
        lines.append("    {")
        keys = [k for k in language if k not in ("files", "units")]
        for k in keys:
            lines.append(f'      "{k}": {dump(language[k])},')
        if "units" in language:
            lines.append('      "units": [')
            units = language["units"]
            for j, unit in enumerate(units):
                lines.append(f"        {dump(unit)}{',' if j < len(units) - 1 else ''}")
            lines.append("      ],")
        lines.append('      "files": [')
        files = language["files"]
        for j, f in enumerate(files):
            lines.append(f"        {dump(f)}{',' if j < len(files) - 1 else ''}")
        lines.append("      ]")
        lines.append("    }" + ("," if i < len(index["languages"]) - 1 else ""))
    lines.append("  ]")
    lines.append("}")
    return "\n".join(lines) + "\n"


def stale(reports: list[vd.Report] | None = None) -> list[str]:
    """What is wrong with decks/index.json, if anything: missing, or not
    what this tool would write now."""
    wanted = render(build(reports))
    if not INDEX.exists():
        return [f"{_rel(INDEX)} is missing; run python3 tools/deck_index.py"]
    if INDEX.read_text(encoding="utf-8") != wanted:
        return [f"{_rel(INDEX)} is out of date; run python3 tools/deck_index.py "
                f"and commit it"]
    return []


def main(argv: list[str]) -> int:
    args = argv[1:]
    if args not in ([], ["--check"]):
        print("usage: deck_index.py [--check]", file=sys.stderr)
        return 2
    if not DECKS.is_dir():
        print(f"error: {DECKS} does not exist", file=sys.stderr)
        return 2
    if args == ["--check"]:
        problems = stale()
        for problem in problems:
            print(f"error: {problem}")
        return 1 if problems else 0
    INDEX.write_text(render(build()), encoding="utf-8")
    print(f"wrote {_rel(INDEX)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
