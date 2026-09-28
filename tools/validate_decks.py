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
# Always used with fullmatch: `$` alone also matches before a trailing newline,
# so `re.match` would accept an id ending in "\n".
ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
LANG_RE = re.compile(r"^[a-z]{2,3}$")
BCP47_RE = re.compile(r"^[a-zA-Z]{2,3}(?:-[A-Za-z0-9]{2,8})*$")
ISO639_3_RE = re.compile(r"[a-z]{3}")

# A facts file must hold at least this many facts that make sense whatever the
# learner's interface language is: a month of one fact a day.
MIN_FACTS = 30

SCRIPTS = {
    "latin", "cyrillic", "greek", "arabic", "hebrew",
    "devanagari", "kana", "han", "hangul", "thai", "other",
}
KINDS = {"vocab", "grammar", "facts", "themes"}
THEMES_KEYS = {"schema", "kind", "description", "themes"}
MODES = {"recognition", "production", "listening", "grammar"}
POS = {"noun", "verb", "adj", "adv", "phrase", "particle", "other"}

HEADER_KEYS = {
    "schema", "id", "name", "kind", "language", "native", "license",
    "authors", "source", "description", "tags", "cards", "pattern", "facts",
    "theme",
}
CARD_KEYS = {
    "id", "target", "native", "reading", "alt_target", "alt_native",
    "pos", "gender", "tags", "notes", "audio", "examples", "modes",
}
PATTERN_KEYS = {"name", "slot_name", "slots", "prompt", "entries", "notes"}
FACT_KEYS = {"id", "text", "contrast", "tags", "source"}


class DeckLoader(yaml.SafeLoader):
    """A SafeLoader that refuses what the app's deck parser refuses.

    PyYAML keeps the last of two duplicate keys and expands `<<` merge keys.
    The Dart parser rejects both, so a deck using either would pass CI and then
    fail to load on a device.
    """

    def flatten_mapping(self, node: yaml.MappingNode) -> None:
        for key_node, _ in node.value:
            if key_node.tag == "tag:yaml.org,2002:merge":
                raise yaml.constructor.ConstructorError(
                    None, None,
                    "found a merge key (<<), which the app does not support; "
                    "write the fields out in full",
                    key_node.start_mark,
                )
        super().flatten_mapping(node)

    def construct_mapping(self, node: yaml.MappingNode, deep: bool = False) -> dict:
        if isinstance(node, yaml.MappingNode):
            self.flatten_mapping(node)
            seen: set[object] = set()
            for key_node, _ in node.value:
                key = self.construct_object(key_node, deep=deep)
                try:
                    duplicate = key in seen
                except TypeError:
                    continue  # unhashable; the base class reports it
                if duplicate:
                    raise yaml.constructor.ConstructorError(
                        "while constructing a mapping", node.start_mark,
                        f"found duplicate key {key!r}", key_node.start_mark,
                    )
                seen.add(key)
        return super().construct_mapping(node, deep=deep)


@dataclass
class Report:
    path: Path
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    # For the checks across files: the theme ids a themes file lists, in
    # order, and the (language, native, theme) a theme deck teaches.
    themes: list[str] | None = None
    theme_key: tuple[str, str, str] | None = None

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


def _check_optional_text(r: Report, where: str, block: dict, key: str) -> None:
    """A free-text field may be omitted, but when present it must be text.

    The app's parser types every field, so `notes: 1990` would pass here and
    then fail on a device if this were not checked.
    """
    val = block.get(key)
    if val is None or isinstance(val, str):
        return
    if isinstance(val, bool):
        r.error(where, f"{key} parsed as the boolean {val!r}, not text. Quote the value.")
    elif isinstance(val, (int, float)):
        r.error(where, f"{key} parsed as the number {val!r}, not text. Quote the value.")
    else:
        r.error(where, f"{key} must be text, got {val!r}")


def check_langblock(r: Report, where: str, block: object, *, full: bool) -> None:
    if not isinstance(block, dict):
        r.error(where, "must be a mapping")
        return
    code = block.get("code")
    if not _is_str(code) or not LANG_RE.fullmatch(code):
        r.error(where, f"code must be a 2-3 letter language code, got {code!r}")
    if not _is_str(block.get("name")):
        r.error(where, "name is required")
    iso = block.get("iso639_3")
    if not _is_str(iso) or not ISO639_3_RE.fullmatch(iso):
        r.error(where, f"iso639_3 must be the language's three-letter ISO 639-3 "
                       f"code, e.g. 'hin' for Hindi, got {iso!r}")
    # `native` needs only code and name, but whatever else it declares is
    # checked like `language`: the app's parser reads those fields either way.
    script = block.get("script")
    if (full or script is not None) and script not in SCRIPTS:
        r.error(where, f"script must be one of {sorted(SCRIPTS)}, got {script!r}")
    tts = block.get("tts")
    if tts is not None and (not _is_str(tts) or not BCP47_RE.fullmatch(tts)):
        r.error(where, f"tts must be a BCP-47 tag, got {tts!r}")
    if full and tts is None:
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
    if not _is_str(cid) or not ID_RE.fullmatch(cid):
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

    for key in ("gender", "notes", "audio"):
        _check_optional_text(r, where, card, key)

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
    _check_optional_text(r, where, pattern, "notes")

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


def _code_error(value: object) -> str:
    if isinstance(value, bool):
        return (f"got the boolean {value!r} -- YAML read a bare no/yes/on/off "
                f"as a bool. Quote the code.")
    return f"got {value!r}"


def check_facts(r: Report, facts: object) -> None:
    """A language's daily facts. See "Facts files" in docs/DECK-FORMAT.md."""
    if not isinstance(facts, list) or not facts:
        r.error("facts", "must be a non-empty list")
        return

    seen: set[str] = set()
    universal = 0
    # English is the base interface language (ADR-0006), so it is counted even
    # when no fact is written in it: a facts file with no English text warns.
    universal_by_language: dict[str, int] = {"en": 0}
    for i, fact in enumerate(facts):
        where = f"facts[{i}]"
        if not isinstance(fact, dict):
            r.error(where, "must be a mapping")
            continue

        fid = fact.get("id")
        if not _is_str(fid) or not ID_RE.fullmatch(fid):
            r.error(where, f"id must match [a-z0-9-]+, got {fid!r}")
        else:
            where = f"fact {fid}"
            if fid in seen:
                r.error(where, "duplicate fact id")
            seen.add(fid)

        for unknown in sorted(set(fact) - FACT_KEYS, key=str):
            r.error(where, f"unknown field {unknown!r}")

        text = fact.get("text")
        written_in: list[str] = []
        if not isinstance(text, dict) or not text:
            r.error(where, "text must map language codes to the fact, e.g. { en: ... }")
            text = {}
        for code, value in text.items():
            if not isinstance(code, str) or not LANG_RE.fullmatch(code):
                r.error(where, f"text key must be a 2-3 letter language code, "
                               f"{_code_error(code)}")
            elif isinstance(value, bool):
                r.error(where, f"text.{code} parsed as the boolean {value!r}. Quote the value.")
            elif not _is_str(value):
                r.error(where, f"text.{code} must be non-empty text")
            else:
                written_in.append(code)

        contrast = fact.get("contrast")
        if contrast is None:
            universal += 1
            for code in written_in:
                universal_by_language[code] = universal_by_language.get(code, 0) + 1
        elif not isinstance(contrast, str) or not LANG_RE.fullmatch(contrast):
            r.error(where, f"contrast must be a 2-3 letter language code, "
                           f"{_code_error(contrast)}")
        elif contrast not in text:
            r.error(where, f"contrast is {contrast!r}, so text needs a {contrast!r} "
                           f"entry: the fact is shown only to learners whose "
                           f"interface language is {contrast!r}")

        if "tags" in fact:
            _check_str_list(r, where, "tags", fact["tags"])
        _check_optional_text(r, where, fact, "source")

    if universal < MIN_FACTS:
        r.error("facts", f"needs at least {MIN_FACTS} facts without a contrast, "
                         f"true whatever the interface language; has {universal}")
    for code, count in sorted(universal_by_language.items()):
        if count < MIN_FACTS:
            r.warn("facts", f"only {count} facts without a contrast have {code!r} "
                            f"text, so learners with that interface language get "
                            f"{count} daily facts, not {MIN_FACTS}")


def validate(path: Path) -> Report:
    r = Report(path)
    try:
        raw = yaml.load(path.read_text(encoding="utf-8"), Loader=DeckLoader)
    except yaml.YAMLError as exc:
        r.error("yaml", str(exc).replace("\n", " "))
        return r
    except UnicodeDecodeError as exc:
        r.error("encoding", f"file is not valid UTF-8: {exc}")
        return r

    if not isinstance(raw, dict):
        r.error("root", "deck must be a YAML mapping")
        return r

    if raw.get("kind") == "themes":
        check_themes_file(r, raw)
        return r

    for unknown in sorted(set(raw) - HEADER_KEYS):
        r.error("root", f"unknown field {unknown!r}")

    # `True == 1` in Python, so without the bool check a bare `schema: yes`
    # would pass here and then fail in the app.
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {raw.get('schema')!r}")

    deck_id = raw.get("id")
    if not _is_str(deck_id) or not ID_RE.fullmatch(deck_id):
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

    theme = raw.get("theme")
    if theme is not None:
        if kind != "vocab":
            r.error("theme", "only a vocab deck teaches a theme")
        elif not _is_str(theme) or not ID_RE.fullmatch(theme):
            r.error("theme", f"must be a theme id from decks/themes.yaml, got {theme!r}")
        else:
            lang, native = raw.get("language"), raw.get("native")
            if isinstance(lang, dict) and isinstance(native, dict):
                r.theme_key = (str(lang.get("code")), str(native.get("code")), theme)

    check_langblock(r, "language", raw.get("language"), full=True)
    if kind != "facts":
        check_langblock(r, "native", raw.get("native"), full=False)
    elif "native" in raw:
        r.error("native", "a facts file has no native: each fact carries its text "
                          "in every language it is written in")

    lang = raw.get("language")
    script = lang.get("script") if isinstance(lang, dict) else "other"
    if script not in SCRIPTS:
        script = "other"

    if "tags" in raw:
        _check_str_list(r, "root", "tags", raw["tags"])
    for key in ("description", "source"):
        _check_optional_text(r, "root", raw, key)

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
                else:
                    _check_optional_text(r, f"authors[{i}]", a, "url")

    if kind == "vocab":
        if "pattern" in raw:
            r.error("pattern", "only valid on a grammar deck")
        if "facts" in raw:
            r.error("facts", "only valid on a facts file")
        cards = raw.get("cards")
        if not isinstance(cards, list) or not cards:
            r.error("cards", "must be a non-empty list")
        else:
            seen: set[str] = set()
            for i, card in enumerate(cards):
                check_card(r, deck_id or "", i, card, seen, script)
    elif kind == "facts":
        for key in ("cards", "pattern"):
            if key in raw:
                r.error(key, "a facts file uses facts, not cards or a pattern")
        check_facts(r, raw.get("facts"))
    else:
        if "facts" in raw:
            r.error("facts", "only valid on a facts file")
        if "cards" in raw:
            r.error("cards", "a grammar deck uses pattern, not cards")
        if "pattern" not in raw:
            r.error("pattern", "is required on a grammar deck")
        else:
            check_pattern(r, raw["pattern"])

    return r


def check_themes_file(r: Report, raw: dict) -> None:
    """The shared theme path, decks/themes.yaml. See ADR-0010."""
    for unknown in sorted(set(raw) - THEMES_KEYS):
        r.error("root", f"unknown field {unknown!r} in a themes file")
    schema = raw.get("schema")
    if isinstance(schema, bool) or schema != SCHEMA:
        r.error("schema", f"must be {SCHEMA}, got {schema!r}")
    themes = raw.get("themes")
    if not isinstance(themes, list) or not themes:
        r.error("themes", "must be a non-empty list")
        return
    ids: list[str] = []
    for i, theme in enumerate(themes):
        where = f"themes[{i}]"
        if not isinstance(theme, dict) or set(theme) - {"id", "name"}:
            r.error(where, "must be a mapping with only an id and a name")
            continue
        tid = theme.get("id")
        if not _is_str(tid) or not ID_RE.fullmatch(tid):
            r.error(where, f"id must match [a-z0-9-]+, got {tid!r}")
            continue
        if tid in ids:
            r.error(where, f"theme {tid!r} is listed twice")
        if not _is_str(theme.get("name")):
            r.error(where, f"theme {tid!r} needs a name")
        ids.append(tid)
    r.themes = ids


def check_themes_across(reports: list[Report]) -> list[str]:
    """Every theme a deck names is on the path, once per course."""
    listed = [rep for rep in reports if rep.themes is not None]
    problems = []
    if len(listed) > 1:
        problems.append("more than one themes file: "
                        + ", ".join(str(rep.path) for rep in listed))
    known = set(listed[0].themes) if listed else set()
    seen: dict[tuple[str, str, str], Path] = {}
    for rep in reports:
        key = rep.theme_key
        if key is None:
            continue
        if key[2] not in known:
            problems.append(f"{rep.path}: theme {key[2]!r} is not in decks/themes.yaml")
        elif key in seen:
            problems.append(f"{rep.path}: {key[0]} from {key[1]} already has a "
                            f"{key[2]!r} deck, {seen[key]}")
        else:
            seen[key] = rep.path
    return problems


def collect(target: Path) -> list[Path]:
    if target.is_file():
        return [target]
    return sorted(p for p in target.rglob("*.yaml") if "schema" not in p.parts)


def check_bundled(paths: list[Path]) -> list[str]:
    """Every language directory holding a deck must be a Flutter asset entry.

    A Flutter asset entry bundles only the files directly inside the directory
    it names, so `- decks/` does not reach `decks/es/`. A language missing from
    the list ships as an app with that language silently absent — it builds, it
    validates, and it is only visible on a device. Checking it here is cheaper
    than finding it there.

    Everything here is resolved against the repository root rather than the
    working directory. A check that quietly passes when run from the wrong
    directory is worse than no check, because it is trusted.
    """
    root = Path(__file__).resolve().parent.parent
    pubspec = root / "pubspec.yaml"
    if not pubspec.exists():
        return []
    try:
        declared = yaml.safe_load(pubspec.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        return [f"{pubspec} is not valid YAML: {exc}"]

    entries = ((declared or {}).get("flutter") or {}).get("assets") or []
    have = {str(e).strip().rstrip("/") for e in entries}

    problems = []
    unbundled: dict[str, None] = {}
    for p in sorted(paths):
        try:
            file = p.resolve().relative_to(root).as_posix()
        except ValueError:
            # Outside the repository, so nothing in pubspec.yaml could bundle
            # it. Validating a deck from elsewhere is legitimate; claiming it
            # is unbundled is not.
            continue
        directory = file.rsplit("/", 1)[0]
        # A directory entry bundles the files directly inside it; a file
        # entry, such as decks/themes.yaml, bundles just that file.
        if directory not in have and file not in have:
            unbundled[directory] = None
    for wanted in unbundled:
        problems.append(
            f"{wanted}/ holds decks but pubspec.yaml does not bundle it — "
            f"add `- {wanted}/` under flutter.assets"
        )
    return problems


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

    unbundled = check_bundled(paths)
    for problem in unbundled:
        print(f"error: {problem}")
    across = check_themes_across(reports)
    for problem in across:
        print(f"error: {problem}")

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
    return 1 if failed or unbundled or across else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
