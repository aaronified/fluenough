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
each file's path, size, SHA-256, schema and kind, and how many proposals
reviewers have made in it (ADR-0038); and, under `media`, the recordings
and images its cards name (#518, #523), each with its path, size, SHA-256
and kind, `audio` or `image`, which the language's size counts. They are
listed apart from `files` so that an app too old to read them passes them
by. So are the script guides of a language's other scripts, such as
`hi-perso-arabic-script`, under `script_guides` (ADR-0016): the app before
them reads only `<code>-script` and fails a file named otherwise. So is
the situations file (#724), under `situations`: the released app has no case
for its kind and would show it as a broken deck. Under
`fonts` it lists the font of each script its decks are shown in,
for scripts that phones often draw wrongly or lack (ADR-0042): path, size,
SHA-256, `script` and `family`, kept apart from `files` and left out of the
language's size, for the same reason. Each file's `content_sha256` is the
SHA-256 of the file with its proposals and its cards' `checked_by` taken
out, so that a learner's phone is not offered an update when only a
proposal or a reviewer's sign-off changed (#444, #449).

A language, or one file, may carry `min_app`, the oldest app version that can
read it (ADR-0052), written from decks/min_app.json. The app that knows the
key does not download what needs a newer app and says so; the released app
before it ignores the key.

Writing the index also keeps the languages badge in the root README.md
current: its number (`languages-N` and `N languages`) is the count of the
index's real languages, leaving out the notation courses (script `ipa` or
`braille`, else code `ipa` or `qbe`). It is rewritten only when it changed,
and skipped when README.md or the badge is not there.

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
README = ROOT / "README.md"
MIN_APP = DECKS / "min_app.json"

# Notation courses, not languages: the badge does not count them.
NOTATION_SCRIPTS = {"ipa", "braille"}
NOTATION_CODES = {"ipa", "qbe"}
_BADGE = re.compile(r'(badge/languages-)\d+(-[^"\s]*"\s+alt=")\d+( languages")')

# The index format. The app refuses an index of a newer version and asks
# for an app update; raise it only for a change an older app would misread.
INDEX_VERSION = 1

# The oldest app version that can read a language, or one file, written to
# the index as `min_app` (ADR-0052) from decks/min_app.json:
#   {"languages": {"pt": "0.7.1"}, "files": {"decks/es/es-en-x.yaml": "0.7.2"}}
# An app that knows the key (0.7.1 and later) does not download what needs a
# newer app and says "needs app X"; an older one ignores it, as it ignores
# every key it does not know. Nothing listed, nothing written.
_APP_VERSION = re.compile(r"^\d+\.\d+\.\d+$")


class MinAppError(ValueError):
    """decks/min_app.json is not what it should be."""


def load_min_app() -> tuple[dict[str, str], dict[str, str]]:
    """The language and file requirements of decks/min_app.json, checked for
    shape: two maps of strings to versions like 0.7.1. A missing file is no
    requirements. Whether each key names something is checked against the
    index being built ([check_min_app])."""
    if not MIN_APP.is_file():
        return {}, {}
    try:
        raw = json.loads(MIN_APP.read_text(encoding="utf-8"))
    except ValueError as e:
        raise MinAppError(f"{_rel(MIN_APP)} is not JSON: {e}") from e
    if not isinstance(raw, dict):
        raise MinAppError(f"{_rel(MIN_APP)} must be an object")
    unknown = sorted(set(raw) - {"languages", "files", "note"})
    if unknown:
        raise MinAppError(f"{_rel(MIN_APP)} has unknown keys {unknown}; "
                          f"it has languages and files")
    maps: list[dict[str, str]] = []
    for key in ("languages", "files"):
        block = raw.get(key, {})
        if not isinstance(block, dict):
            raise MinAppError(f"{_rel(MIN_APP)}: {key} must be an object")
        for name, version in block.items():
            if not isinstance(version, str) or not _APP_VERSION.match(version):
                raise MinAppError(
                    f"{_rel(MIN_APP)}: {key}[{name!r}] is {version!r}, "
                    f"not a version like \"0.7.1\"")
        maps.append(dict(block))
    return maps[0], maps[1]


def check_min_app(languages: dict[str, str], files: dict[str, str],
                  listed_languages: set[str], listed_files: set[str]) -> list[str]:
    """What names nothing in the index being built: a language that is not
    in it, or a file it does not list. A requirement that points nowhere
    would silently do nothing."""
    problems = []
    for code in sorted(languages):
        if code not in listed_languages:
            problems.append(f"{_rel(MIN_APP)}: language {code!r} is not in the "
                            f"index (no decks, or hidden)")
    for path in sorted(files):
        if path not in listed_files:
            problems.append(f"{_rel(MIN_APP)}: file {path!r} is not listed in "
                            f"the index")
    return problems


# Languages kept in the repository, and validated like any other, but not
# offered in the app for now. Remove a line to offer the language.
# Japanese, hidden until 2026-10-20, is offered (owner: write its first
# decks).
HIDDEN: set[str] = set()

# What ships inside the app rather than downloading (the plan's item 7):
# the theme list. The spoken languages live in assets/, not here.
BUNDLED = {"decks/themes.yaml"}

# The fonts the app downloads with a course (ADR-0042): for each script that
# phones often draw wrongly or lack, one OFL-licensed Noto font in
# `decks/fonts/<script>/`, with its OFL.txt. The Noto CJK fonts (simplified
# and traditional Han, kana, Hangul) are 10 to 18 MB each: they download
# only when the learner says the phone's own font shows boxes (#611).
# Japanese's `han` (kanji) is Noto Sans JP too, as `kana` is: the app keeps
# a font by its path, which must sit in its script's folder, so the file is
# there twice rather than shared. The key is the script as
# `assets/languages.yaml` and the deck files name it; the value, the
# font's family name and its file.
FONTS = {
    "perso_arabic": ("Noto Nastaliq Urdu", "NotoNastaliqUrdu.ttf"),
    "devanagari": ("Noto Sans Devanagari", "NotoSansDevanagari.ttf"),
    "bengali": ("Noto Sans Bengali", "NotoSansBengali.ttf"),
    "telugu": ("Noto Sans Telugu", "NotoSansTelugu.ttf"),
    "kannada": ("Noto Sans Kannada", "NotoSansKannada.ttf"),
    "gujarati": ("Noto Sans Gujarati", "NotoSansGujarati.ttf"),
    "gurmukhi": ("Noto Sans Gurmukhi", "NotoSansGurmukhi.ttf"),
    "odia": ("Noto Sans Oriya", "NotoSansOriya.ttf"),
    "tamil": ("Noto Sans Tamil", "NotoSansTamil.ttf"),
    "malayalam": ("Noto Sans Malayalam", "NotoSansMalayalam.ttf"),
    "egyptian_hieroglyphs": (
        "Noto Sans Egyptian Hieroglyphs", "NotoSansEgyptianHieroglyphs.ttf"),
    "cuneiform": ("Noto Sans Cuneiform", "NotoSansCuneiform.ttf"),
    "linear_b": ("Noto Sans Linear B", "NotoSansLinearB.ttf"),
    "han_simplified": ("Noto Sans SC", "NotoSansSC.ttf"),
    "han_traditional": ("Noto Sans TC", "NotoSansTC.ttf"),
    "han": ("Noto Sans JP", "NotoSansJP.ttf"),
    "kana": ("Noto Sans JP", "NotoSansJP.ttf"),
    "hangul": ("Noto Sans KR", "NotoSansKR.ttf"),
}
FONTS_DIR = DECKS / "fonts"

# Kinds of file that hold no deck: one of each per language at most. A
# language whose files are all of these has no written deck, and is left
# out of the index.
NOT_DECKS = {
    "path",
    "facts",
    "situations",
    "numbers",
    "romanisation",
    "sounds",
    "script",
    "resources",
    "phonetics",
}


# The core a layer names when it is the layer of a script guide for one of a
# language's other scripts: hi-perso-arabic-script, not hi-script.
_OTHER_SCRIPT_CORE = re.compile(r"[a-z]{2,3}-[a-z]+(?:-[a-z]+)*-script")


def _other_script_guide(path: Path, entry: dict) -> bool:
    """Whether the file is a script guide, or a layer of one, for another
    script of its language than the default `<code>-script` guide."""
    code = entry["path"].split("/")[1]
    if entry["kind"] not in ("script", "layer"):
        return False
    text = path.read_text(encoding="utf-8", errors="replace")
    if entry["kind"] == "script":
        guide = _top(text, "id")
        return guide is not None and guide != f"{code}-script"
    core = _top(text, "core")
    return core is not None and _OTHER_SCRIPT_CORE.fullmatch(core) is not None


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


_PROPOSED_KEY = re.compile(r"^( *)proposed:[ \t]*$")
# A card's `checked_by`, the rater codes that signed it off (#449), and its
# `verified`, the data points reviewers settled (#519): one
# line as the bot writes it, `checked_by: ["FL-…"]`, or a bare key with
# its items under it.
_CHECKED_KEY = re.compile(r"^( *)(?:checked_by|verified):[ \t]*(\S.*)?$")
# The same, at the end of a card written on one line in flow style, as the
# bot writes it there: `- { id: "te-0001", …, checked_by: ["FL-…"] }`.
_CHECKED_IN_FLOW = re.compile(
    rb"(?:, (?:checked_by|verified): \[[^\]\n]*\])+(?= ?\}[ \t]*\r?\n?$)")


def content_bytes(data: bytes) -> bytes:
    """[data], a deck file, with its proposals and its cards' `checked_by`
    and `verified` taken out: what a learner is offered an update for (ADR-0038, #444,
    #449).

    The review bot writes a card's proposals as a `proposed:` line and its
    items, one line each, indented under it; this drops those lines and
    keeps every other byte as it is, blank lines after the items too: the
    file with its last proposal removed hashes as it did before the
    first. Items YAML allows at the key's own indent (`- ` lines straight
    under it) go too, so a proposal written that way by hand still leaves
    the content hash alone.

    The bot writes `checked_by` as one line, which is dropped the same way,
    with any items under a bare `checked_by:` written by hand; on a card
    written on one line in flow style it adds `, checked_by: [...]` before
    the closing brace, and that is taken out of the line. A deck's
    tags are kept: `reviewed` in place of `unreviewed` is a change a
    learner sees."""
    lines = [line.decode("utf-8", errors="replace").rstrip("\r\n")
             for line in data.splitlines(keepends=True)]
    raw = data.splitlines(keepends=True)
    out: list[bytes] = []
    i = 0
    while i < len(lines):
        m = _PROPOSED_KEY.match(lines[i])
        checked = _CHECKED_KEY.match(lines[i]) if m is None else None
        if checked is not None and checked.group(2) is not None \
                and not checked.group(2).startswith("#"):
            # The one line the bot writes, its value on it; a flow list
            # carried on over the next lines by hand goes up to its `]`.
            value = checked.group(2)
            i += 1
            if value.startswith("[") and "]" not in value:
                while i < len(lines) and "]" not in lines[i]:
                    i += 1
                i = min(i + 1, len(lines))
            continue
        m = m or checked
        if m is None:
            out.append(_CHECKED_IN_FLOW.sub(b"", raw[i])
                       if b"checked_by" in raw[i] or b"verified" in raw[i]
                       else raw[i])
            i += 1
            continue
        indent = len(m.group(1))
        i += 1
        # The items: every line indented deeper than the key, or a `- `
        # item at the key's own indent, and blank lines between two of them.
        while i < len(lines):
            j = i
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j == len(lines):
                break
            line = lines[j]
            depth = len(line) - len(line.lstrip(" "))
            item = line[depth:]
            same_indent_item = depth == indent and (
                item == "-" or item.startswith("- "))
            if depth <= indent and not same_indent_item:
                break
            i = j + 1
    return b"".join(out)


def _file_entry(path: Path, rep: vd.Report | None) -> dict:
    data = path.read_bytes()
    text = data.decode("utf-8", errors="replace")
    schema = _top(text, "schema")
    entry: dict = {
        "path": _rel(path),
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        # The hash a learner's phone compares: proposals, checked_by and
        # verified left out (#444, #449, #519).
        "content_sha256": hashlib.sha256(content_bytes(data)).hexdigest(),
        "schema": int(schema) if schema is not None and schema.isdigit() else 0,
        "kind": _top(text, "kind") or "vocab",
    }
    if _top(text, "part") == "core":
        entry["part"] = "core"
    if rep is not None and rep.native_code is not None:
        entry["native"] = rep.native_code
    if rep is not None and rep.listed_as is not None:
        entry["deck"] = rep.listed_as
    # What reviewers have proposed in the file and not yet agreed
    # (ADR-0038); learners never see it.
    if "proposed" in text:
        proposed = vd.proposal_count(path)
        if proposed:
            entry["proposed"] = proposed
    return entry


def _media_entries(directory: Path) -> list[dict]:
    """The recordings and images in a language's folders (#518, #523)."""
    entries = []
    for kind, (folder, ending) in vd.MEDIA.items():
        for p in sorted((directory / folder).glob(f"*{ending}")):
            data = p.read_bytes()
            entries.append({"path": _rel(p), "size": len(data),
                            "sha256": hashlib.sha256(data).hexdigest(), "kind": kind})
    return entries


def _own_scripts() -> dict[str, list[str]]:
    """Each language's scripts, from assets/languages.yaml."""
    raw = vd._load_raw(ROOT / "assets" / "languages.yaml")
    found: dict[str, list[str]] = {}
    if isinstance(raw, dict) and isinstance(raw.get("languages"), list):
        for entry in raw["languages"]:
            if isinstance(entry, dict) and vd._is_str(entry.get("code")) \
                    and isinstance(entry.get("scripts"), list):
                found[entry["code"]] = [
                    s for s in entry["scripts"] if vd._is_str(s)]
    return found


def _scripts_of(code: str, block: dict, scripts: dict[str, list[str]]) -> list[str]:
    """The scripts a language's decks are shown in: the one its language
    block names, then the others `assets/languages.yaml` lists for it, as
    Hindustani's Perso-Arabic."""
    found: list[str] = []
    if vd._is_str(block.get("script")):
        found.append(block["script"])
    for script in scripts.get(code, []):
        if script not in found:
            found.append(script)
    return found


def _font_entries(scripts: list[str]) -> list[dict]:
    """The fonts of [scripts] that decks/fonts/ holds (ADR-0042), in the
    order of [scripts]."""
    entries = []
    for script in scripts:
        if script not in FONTS:
            continue
        family, name = FONTS[script]
        path = FONTS_DIR / script / name
        if not path.is_file():
            continue
        data = path.read_bytes()
        entries.append({"path": _rel(path), "size": len(data),
                        "sha256": hashlib.sha256(data).hexdigest(),
                        "script": script, "family": family})
    return entries


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
    langs = sorted(p for p in DECKS.iterdir()
                   if p.is_dir() and p.name not in HIDDEN | {FONTS_DIR.name})
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
    own_scripts = _own_scripts()
    min_languages, min_files = load_min_app()
    listed_files: set[str] = set()
    out = []
    for d in langs:
        code = d.name
        files = vd._yaml_files(d)
        if not files:
            continue
        lang = ctx.lang(code)
        block = _language_block(files)
        entries = [_file_entry(p, by_path.get(p.resolve())) for p in files]
        # The resources file (#832) is no deck: listed apart, below.
        resources = [e for e in entries if e["kind"] == "resources"]
        files = [p for p, e in zip(files, entries) if e["kind"] != "resources"]
        entries = [e for e in entries if e["kind"] != "resources"]
        # The situations file (#724) is listed apart too, under its own key:
        # the released app has no case for `kind: situations` and would show
        # the entry as a broken deck. The app that knows it reads the key
        # and fetches the file with the decks.
        situations = [e for e in entries if e["kind"] == "situations"]
        files = [p for p, e in zip(files, entries) if e["kind"] != "situations"]
        entries = [e for e in entries if e["kind"] != "situations"]
        # The phonetic rules are for tools/derive_phonetic.py alone: not
        # listed, not fetched, not in the size.
        files = [p for p, e in zip(files, entries) if e["kind"] != "phonetics"]
        entries = [e for e in entries if e["kind"] != "phonetics"]
        guides = [e for p, e in zip(files, entries) if _other_script_guide(p, e)]
        entries = [e for e in entries if e not in guides]
        # A course with a path but no written deck is not offered: the
        # app would list it empty. It appears once its first deck lands.
        if all(e["kind"] in NOT_DECKS for e in entries + guides + situations):
            continue
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
        if code in min_languages:
            language["min_app"] = min_languages[code]
        language["natives"] = [{"code": n, "name": lang.native_name(n)} for n in natives]
        media = _media_entries(d)
        language["size"] = sum(e["size"] for e in entries + guides + situations + media)
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
        for e in entries + guides + situations:
            listed_files.add(e["path"])
            if e["path"] in min_files:
                e["min_app"] = min_files[e["path"]]
        language["files"] = entries
        if guides:
            language["script_guides"] = guides
        if situations:
            language["situations"] = situations
        if media:
            language["media"] = media
        # Apart from `files` and from the size: the released app reads only
        # those, and passes this by (ADR-0042).
        fonts = _font_entries(_scripts_of(code, block, own_scripts))
        if fonts:
            language["fonts"] = fonts
        # Apart from `files` and from the size too: the released app passes
        # an unknown key by, and the app that knows it fetches the file
        # alone, when a sheet wants it (#832).
        if resources:
            language["resources"] = resources
        out.append(language)
    problems = check_min_app(min_languages, min_files,
                             {lang["code"] for lang in out}, listed_files)
    if problems:
        raise MinAppError("; ".join(problems))
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
        lists = ("files", "script_guides", "situations", "media", "fonts", "resources")
        keys = [k for k in language if k not in ("units", *lists)]
        for k in keys:
            lines.append(f'      "{k}": {dump(language[k])},')
        if "units" in language:
            lines.append('      "units": [')
            units = language["units"]
            for j, unit in enumerate(units):
                lines.append(f"        {dump(unit)}{',' if j < len(units) - 1 else ''}")
            lines.append("      ],")
        present = [k for k in lists if k in language]
        for key in present:
            last = key == present[-1]
            lines.append(f'      "{key}": [')
            files = language[key]
            for j, f in enumerate(files):
                lines.append(f"        {dump(f)}{',' if j < len(files) - 1 else ''}")
            lines.append("      ]" + ("" if last else ","))
        lines.append("    }" + ("," if i < len(index["languages"]) - 1 else ""))
    lines.append("  ]")
    lines.append("}")
    return "\n".join(lines) + "\n"


def stale(reports: list[vd.Report] | None = None) -> list[str]:
    """What is wrong with decks/index.json, if anything: missing, or not
    what this tool would write now."""
    try:
        wanted = render(build(reports))
    except MinAppError as e:
        return [str(e)]
    if not INDEX.exists():
        return [f"{_rel(INDEX)} is missing; run python3 tools/deck_index.py"]
    if INDEX.read_text(encoding="utf-8") != wanted:
        return [f"{_rel(INDEX)} is out of date; run python3 tools/deck_index.py "
                f"and commit it"]
    return []


def language_count(index: dict) -> int:
    """How many of the index's languages are real languages."""
    n = 0
    for lang in index.get("languages", []):
        script = lang.get("script")
        if script is not None:
            notation = script in NOTATION_SCRIPTS
        else:
            notation = lang.get("code") in NOTATION_CODES
        n += not notation
    return n


def update_badge(index: dict) -> bool:
    """Rewrite the README's languages badge to the index's count. True when
    it changed; False, silently, when README.md or the badge is missing or
    already right."""
    if not README.is_file():
        return False
    with README.open(encoding="utf-8", newline="") as f:
        text = f.read()
    count = str(language_count(index))
    new = _BADGE.sub(lambda m: m.group(1) + count + m.group(2) + count + m.group(3),
                     text, count=1)
    if new == text:
        return False
    with README.open("w", encoding="utf-8", newline="") as f:
        f.write(new)
    return True


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
    try:
        index = build()
    except MinAppError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    INDEX.write_text(render(index), encoding="utf-8")
    print(f"wrote {_rel(INDEX)}")
    if update_badge(index):
        print(f"updated the languages badge in {_rel(README)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
