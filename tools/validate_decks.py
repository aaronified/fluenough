#!/usr/bin/env python3
"""Validate Fluenough deck files against schema 1.

Usage:
    python3 tools/validate_decks.py decks/
    python3 tools/validate_decks.py decks/es/es-core-100.yaml

Requires only Python 3.11+ and PyYAML, so deck contributors need no Flutter
toolchain. Exits non-zero if any deck fails. See docs/DECK-FORMAT.md.
"""

from __future__ import annotations

import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError:
    sys.exit("error: PyYAML is required.  pip install pyyaml")

SCHEMA = 1
ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
LANG_RE = re.compile(r"^[a-z]{2,3}$")
BCP47_RE = re.compile(r"^[a-zA-Z]{2,3}(?:-[A-Za-z0-9]{2,8})*$")

SCRIPTS = {
    "latin", "cyrillic", "greek", "arabic", "hebrew",
    "devanagari", "kana", "han", "hangul", "thai", "other",
}
KINDS = {"vocab", "grammar"}
MODES = {"recognition", "production", "listening", "grammar"}
POS = {"noun", "verb", "adj", "adv", "phrase", "particle", "other"}

HEADER_KEYS = {
    "schema", "id", "name", "kind", "language", "native", "license",
    "authors", "source", "description", "tags", "cards", "pattern",
}
CARD_KEYS = {
    "id", "target", "native", "reading", "alt_target", "alt_native",
    "pos", "gender", "tags", "notes", "audio", "examples", "modes",
}
PATTERN_KEYS = {"name", "slot_name", "slots", "prompt", "entries", "notes"}


@dataclass
class Report:
    path: Path
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def error(self, where: str, msg: str) -> None:
        self.errors.append(f"{where}: {msg}")

    def warn(self, where: str, msg: str) -> None:
        self.warnings.append(f"{where}: {msg}")


def _is_str(v: object) -> bool:
    return isinstance(v, str) and v.strip() != ""


def _check_str_list(r: Report, where: str, key: str, value: object) -> None:
    if not isinstance(value, list):
        r.error(where, f"{key} must be a list")
        return
    for i, item in enumerate(value):
        if not _is_str(item):
            r.error(where, f"{key}[{i}] must be a non-empty string")


def check_langblock(r: Report, where: str, block: object, *, full: bool) -> None:
    if not isinstance(block, dict):
        r.error(where, "must be a mapping")
        return
    code = block.get("code")
    if not _is_str(code) or not LANG_RE.match(code):
        r.error(where, f"code must be a 2-3 letter language code, got {code!r}")
    if not _is_str(block.get("name")):
        r.error(where, "name is required")
    if not full:
        return
    script = block.get("script")
    if script not in SCRIPTS:
        r.error(where, f"script must be one of {sorted(SCRIPTS)}, got {script!r}")
    tts = block.get("tts")
    if tts is not None and (not _is_str(tts) or not BCP47_RE.match(tts)):
        r.error(where, f"tts must be a BCP-47 tag, got {tts!r}")
    if tts is None:
        r.warn(where, "no tts tag; the device will pick a default regional voice")
    if "rtl" in block and not isinstance(block["rtl"], bool):
        r.error(where, "rtl must be a boolean")


def check_card(r: Report, deck_id: str, idx: int, card: object, seen: set[str],
               script: str) -> None:
    where = f"cards[{idx}]"
    if not isinstance(card, dict):
        r.error(where, "must be a mapping")
        return

    cid = card.get("id")
    if not _is_str(cid) or not ID_RE.match(cid):
        r.error(where, f"id must match [a-z0-9-]+, got {cid!r}")
    else:
        where = f"card {cid}"
        if cid in seen:
            r.error(where, "duplicate card id")
        seen.add(cid)

    for unknown in sorted(set(card) - CARD_KEYS):
        r.error(where, f"unknown field {unknown!r}")

    for key in ("target", "native", "reading"):
        val = card.get(key)
        if key == "reading" and val is None:
            continue
        if isinstance(val, bool):
            # YAML 1.1 resolves no/yes/on/off/true/false to booleans. This bites
            # romanisation decks hard: the hiragana の romanises to "no".
            r.error(where, f"{key} parsed as the boolean {val!r} -- YAML read a "
                           f"bare no/yes/on/off as a bool. Quote the value.")
        elif not _is_str(val):
            if key == "reading":
                r.error(where, "reading must be a non-empty string or omitted")
            else:
                r.error(where, f"{key} is required and must be a non-empty string")

    target = card.get("target")
    if _is_str(target):
        if target != unicodedata.normalize("NFC", target):
            r.warn(where, "target is not NFC-normalised")
        if target != target.strip():
            r.error(where, "target has leading or trailing whitespace")

    if script not in ("latin", "cyrillic", "greek") and not _is_str(card.get("reading")):
        r.warn(where, f"no reading, but script is {script!r}; learners will need one")

    for key in ("alt_target", "alt_native", "tags"):
        if key in card:
            _check_str_list(r, where, key, card[key])

    pos = card.get("pos")
    if pos is not None and pos not in POS:
        r.error(where, f"pos must be one of {sorted(POS)}, got {pos!r}")

    modes = card.get("modes")
    if modes is not None:
        _check_str_list(r, where, "modes", modes)
        if isinstance(modes, list):
            for m in modes:
                if isinstance(m, str) and m not in MODES:
                    r.error(where, f"unknown mode {m!r}")

    examples = card.get("examples")
    if examples is not None:
        if not isinstance(examples, list):
            r.error(where, "examples must be a list")
        else:
            for j, ex in enumerate(examples):
                if not isinstance(ex, dict):
                    r.error(where, f"examples[{j}] must be a mapping")
                elif not _is_str(ex.get("target")) or not _is_str(ex.get("native")):
                    r.error(where, f"examples[{j}] needs both target and native")
                elif set(ex) - {"target", "native"}:
                    r.error(where, f"examples[{j}] has unknown fields")


def check_pattern(r: Report, pattern: object) -> None:
    where = "pattern"
    if not isinstance(pattern, dict):
        r.error(where, "must be a mapping")
        return

    for unknown in sorted(set(pattern) - PATTERN_KEYS):
        r.error(where, f"unknown field {unknown!r}")

    for key in ("name", "slot_name", "prompt"):
        if not _is_str(pattern.get(key)):
            r.error(where, f"{key} is required")

    prompt = pattern.get("prompt")
    if _is_str(prompt):
        for token in re.findall(r"\{(\w+)\}", prompt):
            if token not in ("lemma", "gloss", "slot"):
                r.error(where, f"prompt uses unknown placeholder {{{token}}}")
        if "{slot}" not in prompt:
            r.warn(where, "prompt has no {slot}; every cell will look identical")

    slots = pattern.get("slots")
    if not isinstance(slots, list) or not slots:
        r.error(where, "slots must be a non-empty list")
        return
    _check_str_list(r, where, "slots", slots)
    if len(set(slots)) != len(slots):
        r.error(where, "slots contains duplicates")

    entries = pattern.get("entries")
    if not isinstance(entries, list) or not entries:
        r.error(where, "entries must be a non-empty list")
        return

    lemmas: set[str] = set()
    for i, entry in enumerate(entries):
        ewhere = f"pattern.entries[{i}]"
        if not isinstance(entry, dict):
            r.error(ewhere, "must be a mapping")
            continue
        for unknown in sorted(set(entry) - {"lemma", "gloss", "forms"}):
            r.error(ewhere, f"unknown field {unknown!r}")
        lemma = entry.get("lemma")
        if not _is_str(lemma):
            r.error(ewhere, "lemma is required")
        else:
            ewhere = f"pattern.entries[{lemma}]"
            if lemma in lemmas:
                r.error(ewhere, "duplicate lemma")
            lemmas.add(lemma)
        if not _is_str(entry.get("gloss")):
            r.error(ewhere, "gloss is required")

        forms = entry.get("forms")
        if not isinstance(forms, dict):
            r.error(ewhere, "forms must be a mapping")
            continue
        missing = [s for s in slots if s not in forms]
        if missing:
            r.error(ewhere, f"forms missing slots: {missing}")
        for extra in sorted(set(forms) - set(slots)):
            r.error(ewhere, f"forms has key {extra!r} which is not a slot")
        filled = [s for s in slots if forms.get(s) is not None]
        if not filled:
            r.error(ewhere, "every form is null; nothing to drill")
        for slot in slots:
            val = forms.get(slot)
            if val is not None and not _is_str(val):
                r.error(ewhere, f"forms[{slot!r}] must be a non-empty string or null")


def validate(path: Path) -> Report:
    r = Report(path)
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        r.error("yaml", str(exc).replace("\n", " "))
        return r
    except UnicodeDecodeError as exc:
        r.error("encoding", f"file is not valid UTF-8: {exc}")
        return r

    if not isinstance(raw, dict):
        r.error("root", "deck must be a YAML mapping")
        return r

    for unknown in sorted(set(raw) - HEADER_KEYS):
        r.error("root", f"unknown field {unknown!r}")

    if raw.get("schema") != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {raw.get('schema')!r}")

    deck_id = raw.get("id")
    if not _is_str(deck_id) or not ID_RE.match(deck_id):
        r.error("id", f"must match [a-z0-9-]+, got {deck_id!r}")
    elif deck_id != path.stem:
        r.error("id", f"is {deck_id!r} but the filename stem is {path.stem!r}")

    if not _is_str(raw.get("name")):
        r.error("name", "is required")
    if not _is_str(raw.get("license")):
        r.error("license", "is required (SPDX identifier, or CC0-1.0)")

    kind = raw.get("kind", "vocab")
    if kind not in KINDS:
        r.error("kind", f"must be one of {sorted(KINDS)}, got {kind!r}")

    check_langblock(r, "language", raw.get("language"), full=True)
    check_langblock(r, "native", raw.get("native"), full=False)

    lang = raw.get("language")
    script = lang.get("script") if isinstance(lang, dict) else "other"
    if script not in SCRIPTS:
        script = "other"

    if "tags" in raw:
        _check_str_list(r, "root", "tags", raw["tags"])

    authors = raw.get("authors")
    if authors is not None:
        if not isinstance(authors, list):
            r.error("authors", "must be a list")
        else:
            for i, a in enumerate(authors):
                if not isinstance(a, dict) or not _is_str(a.get("name")):
                    r.error(f"authors[{i}]", "must be a mapping with a name")
                elif set(a) - {"name", "url"}:
                    r.error(f"authors[{i}]", "unknown fields")

    if kind == "vocab":
        if "pattern" in raw:
            r.error("pattern", "only valid on a grammar deck")
        cards = raw.get("cards")
        if not isinstance(cards, list) or not cards:
            r.error("cards", "must be a non-empty list")
        else:
            seen: set[str] = set()
            for i, card in enumerate(cards):
                check_card(r, deck_id or "", i, card, seen, script)
    else:
        if "cards" in raw:
            r.error("cards", "a grammar deck uses pattern, not cards")
        if "pattern" not in raw:
            r.error("pattern", "is required on a grammar deck")
        else:
            check_pattern(r, raw["pattern"])

    return r


def collect(target: Path) -> list[Path]:
    if target.is_file():
        return [target]
    return sorted(p for p in target.rglob("*.yaml") if "schema" not in p.parts)


def main(argv: list[str]) -> int:
    targets = [Path(a) for a in argv[1:]] or [Path("decks")]
    paths: list[Path] = []
    for t in targets:
        if not t.exists():
            print(f"error: {t} does not exist", file=sys.stderr)
            return 2
        paths.extend(collect(t))

    if not paths:
        print("error: no deck files found", file=sys.stderr)
        return 2

    reports = [validate(p) for p in paths]

    ids: dict[str, Path] = {}
    for p in paths:
        if p.stem in ids:
            print(f"error: duplicate deck id {p.stem!r}: {ids[p.stem]} and {p}")
            return 1
        ids[p.stem] = p

    failed = 0
    warned = 0
    for rep in reports:
        if rep.errors:
            failed += 1
            print(f"FAIL {rep.path}")
            for e in rep.errors:
                print(f"  error   {e}")
        elif rep.warnings:
            warned += 1
            print(f"warn {rep.path}")
        for w in rep.warnings:
            print(f"  warning {w}")

    ok = len(reports) - failed
    print(f"\n{ok}/{len(reports)} decks valid"
          f"{f', {warned} with warnings' if warned else ''}.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
