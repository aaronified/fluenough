#!/usr/bin/env python3
"""Check a private language package: `validate_decks.py --private <package>`.

A private package (#1017, wiki Plan-Private-Languages) is a folder, or a
`.fnzip` (a zip), with a `manifest.yaml`, an optional path file, and decks
and layers whose ids all start with `fnpd-<code>-`. This is the author's
check, the Python twin of the app's import (lib/core/private/private_check.dart):
the same rules, the same fixture (test/fixtures/private/qaa-tiny), so a package
that passes here imports without an error.

Two kinds of check, in this order:

1. The package: safe names and sizes (level 0), then that it holds together
   (level 2): the manifest, the id prefix, no id twice, a path whose units
   name decks that exist, the card limit.
2. The decks: each core and layer is rewritten with `fnpd-<code>-` turned
   into `<code>-`, written to a temporary folder laid out as the repository's
   `decks/<code>/`, and checked by the validator's own rules. Its errors are
   shown under the package's file names.

The other way round, the validator refuses a private id anywhere else, so
that the repository's `decks/` never holds a private package (see
`private_ids_in`).

Usage:
    python3 tools/validate_decks.py --private path/to/package-folder
    python3 tools/validate_decks.py --private path/to/package.fnzip

Exit code 0 when the package has no error, 1 when it has, 2 for bad
arguments. Warnings never change it.
"""

from __future__ import annotations

import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks as vd  # noqa: E402

MARKER = "fnpd-"
FORMAT = "fluenough-private"
LICENSE = "CC-BY-SA-4.0"
ARCHIVE_MAX = 10 * 1024 * 1024
UNPACKED_MAX = 30 * 1024 * 1024
FILE_MAX = 2 * 1024 * 1024
FILES_MAX = 1000
CARDS_MAX = 20000
RATIO_MAX = 100
RATIO_FLOOR = 4096
NAME_RE = re.compile(r"^[A-Za-z0-9._/-]+$")
CODE_RE = re.compile(r"^[a-z]{2,3}$")
PRIVATE_USE_RE = re.compile(r"^q[a-t][a-z]$")
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")
# The private-use codes the app's own languages use (assets/languages.yaml):
# a package may not take them. Kept equal to the Dart list
# (lib/core/private/private_ids.dart); a test checks both against the file.
BUILT_IN_PRIVATE_USE = {"qap", "qbe", "qdo", "qgh", "qgk", "qhv", "qya"}
# Files that are data about a language, not a deck or a layer.
DATA_KINDS = {
    "path", "facts", "situations", "numbers", "romanisation", "sounds", "script",
    "themes", "topics", "creators", "recommendations", "sections",
}
MANIFEST = "manifest.yaml"
MANIFEST_FIELDS = {"format", "package", "revision", "kind", "language",
                   "min_app", "license", "based_on"}
LANGUAGE_FIELDS = {"code", "iso639_3", "name", "own_name", "script", "scripts",
                   "tts", "rtl", "icon"}


private_ids_in = vd.private_ids_in


def load(target: Path) -> tuple[dict[str, bytes], int | None, list[str]]:
    """The files of a package folder or `.fnzip`, by path in the package, the
    archive's size when it is one, and the errors of reading it."""
    errors: list[str] = []
    files: dict[str, bytes] = {}
    if target.is_dir():
        for p in sorted(target.rglob("*")):
            if p.is_file():
                files[p.relative_to(target).as_posix()] = p.read_bytes()
        return files, None, errors
    size = target.stat().st_size
    try:
        with zipfile.ZipFile(target) as z:
            infos = z.infolist()
            names = [i.filename for i in infos if not i.is_dir()]
            if len(names) > FILES_MAX:
                return {}, size, [f"too many files: {len(names)}, at most {FILES_MAX}"]
            for info in infos:
                if info.is_dir():
                    continue
                if info.flag_bits & 1:
                    return {}, size, ["the archive is encrypted"]
                if info.file_size > FILE_MAX:
                    return {}, size, [f"{info.filename}: over {FILE_MAX} bytes"]
                files[info.filename] = z.read(info)
    except zipfile.BadZipFile as exc:
        errors.append(f"not a zip file: {exc}")
    return files, size, errors


def check_files(files: dict[str, bytes], archive_bytes: int | None) -> list[str]:
    """Level 0: names, sizes, types and encoding."""
    errors: list[str] = []
    if archive_bytes is not None and archive_bytes > ARCHIVE_MAX:
        errors.append(f"the archive is {archive_bytes} bytes, over {ARCHIVE_MAX}")
    if len(files) > FILES_MAX:
        errors.append(f"{len(files)} files, at most {FILES_MAX}")
    seen: set[str] = set()
    total = 0
    for name, data in files.items():
        if (not name or not NAME_RE.fullmatch(name) or name.startswith("/")
                or any(part in ("", ".", "..") or part.startswith(".")
                       for part in name.split("/"))):
            errors.append(f"{name!r}: not a file name a package may have")
            continue
        if name.lower() in seen:
            errors.append(f"{name}: a name is used twice")
        seen.add(name.lower())
        if not (name.endswith(".yaml") or name.endswith(".json")):
            errors.append(f"{name}: only .yaml and .json files")
        if len(data) > FILE_MAX:
            errors.append(f"{name}: {len(data)} bytes, over {FILE_MAX}")
        total += len(data)
        try:
            data.decode("utf-8")
        except UnicodeDecodeError:
            errors.append(f"{name}: not UTF-8")
    if total > UNPACKED_MAX:
        errors.append(f"{total} bytes unpacked, over {UNPACKED_MAX}")
    return errors


def _parse(files: dict[str, bytes]) -> tuple[dict[str, dict], list[str]]:
    trees: dict[str, dict] = {}
    errors: list[str] = []
    for name, data in sorted(files.items()):
        if not name.endswith(".yaml"):
            continue
        try:
            tree = vd._load_deck(data.decode("utf-8"))
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{name}: not YAML: {str(exc).splitlines()[0] if str(exc) else exc}")
            continue
        if not isinstance(tree, dict):
            errors.append(f"{name}: must be a mapping")
            continue
        trees[name] = tree
    return trees, errors


def _manifest_errors(raw: dict) -> list[str]:
    errors: list[str] = []

    def bad(message: str) -> None:
        errors.append(f"{MANIFEST}: {message}")

    for key in raw:
        if key not in MANIFEST_FIELDS:
            bad(f"unknown field {key!r}")
    if raw.get("format") != FORMAT:
        bad(f'"format" must be "{FORMAT}"')
    language = raw.get("language")
    if not isinstance(language, dict):
        bad('"language" must be a mapping')
        return errors
    for key in language:
        if key not in LANGUAGE_FIELDS:
            bad(f"language: unknown field {key!r}")
    code = language.get("code")
    if not isinstance(code, str) or not CODE_RE.fullmatch(code):
        bad('"language.code" must be two or three lowercase letters')
        return errors
    kind = raw.get("kind")
    free_private = bool(PRIVATE_USE_RE.fullmatch(code)) and code not in BUILT_IN_PRIVATE_USE
    if kind == "new-language":
        if not free_private:
            bad(f'"language.code" {code!r} must be a private-use code, qaa to qtz, '
                f"that no built-in language uses, for a new language")
    elif kind == "modified-language":
        if free_private:
            bad(f'"language.code" {code!r} must be the code of a language the app '
                f"teaches, such as te, for a modified language")
        elif vd._language_scripts(code) is None:
            bad(f'"language.code" {code!r} is not a language the app teaches')
    else:
        bad('"kind" must be "new-language" or "modified-language"')
    if raw.get("package") != f"{MARKER}{code}":
        bad(f'"package" must be "{MARKER}{code}"')
    revision = raw.get("revision")
    if isinstance(revision, bool) or not isinstance(revision, int) or revision < 1:
        bad('"revision" must be a whole number, 1 or more')
    min_app = raw.get("min_app")
    if not isinstance(min_app, str) or not VERSION_RE.fullmatch(min_app):
        bad('"min_app" must be a version like 0.9.0')
    if raw.get("license") != LICENSE:
        bad(f'"license" must be "{LICENSE}"')
    iso = language.get("iso639_3")
    if not isinstance(iso, str) or not re.fullmatch(r"[a-z]{3}", iso):
        bad('"language.iso639_3" must be three lowercase letters')
    if not isinstance(language.get("name"), str) or not language["name"].strip():
        bad('"language.name" must be text')
    if raw.get("based_on") is not None and not isinstance(raw["based_on"], str):
        bad('"based_on" must be text')
    return errors


def _is_deck(tree: dict) -> bool:
    kind = tree.get("kind", "vocab")
    return kind != "layer" and kind not in DATA_KINDS


def check_package(files: dict[str, bytes]) -> tuple[list[str], list[str], dict | None]:
    """Level 2: whether the package holds together. Returns the errors, the
    warnings, and the manifest when it read."""
    errors: list[str] = []
    warnings: list[str] = []
    trees, parse_errors = _parse(files)
    errors.extend(parse_errors)
    manifest = trees.get(MANIFEST)
    if manifest is None:
        if MANIFEST not in files:
            errors.append(f"{MANIFEST}: the package has no manifest")
        return errors, warnings, None
    manifest_errors = _manifest_errors(manifest)
    errors.extend(manifest_errors)
    language = manifest.get("language")
    code = language.get("code") if isinstance(language, dict) else None
    if manifest_errors or not isinstance(code, str):
        return errors, warnings, None
    prefix = f"{MARKER}{code}-"
    modified = manifest.get("kind") == "modified-language"
    card_ids: dict[str, str] = {}
    deck_ids: dict[str, str] = {}
    cards_total = 0
    has_path = False
    own_cores: set[str] = set()
    for name, tree in sorted(trees.items()):
        if name == MANIFEST:
            continue
        kind = tree.get("kind", "vocab")
        if kind == "path":
            has_path = True
            if tree.get("language") != code:
                errors.append(f"{name}: the path's language must be {code!r}")
            continue
        if kind in DATA_KINDS:
            if modified and kind not in ("themes", "sections"):
                warnings.append(f"{name}: a modified language replaces its path and "
                                f"decks only; this file is ignored")
            continue
        deck_id = tree.get("id")
        if isinstance(deck_id, str) and not deck_id.startswith(prefix):
            errors.append(f"{name}: id {deck_id!r} must start with {prefix!r}")
        if kind == "layer":
            cards = tree.get("cards")
            if isinstance(cards, dict):
                for key in cards:
                    if isinstance(key, str) and not key.startswith(prefix):
                        errors.append(f"{name}: card {key!r} must start with {prefix!r}")
            continue
        lang_block = tree.get("language")
        found = lang_block.get("code") if isinstance(lang_block, dict) else None
        if isinstance(found, str) and found != code:
            errors.append(f"{name}: language is {found!r}, the package's is {code!r}")
        if isinstance(deck_id, str):
            if deck_id in deck_ids:
                errors.append(f"{name}: deck id {deck_id!r} is also in {deck_ids[deck_id]}")
            deck_ids[deck_id] = name
            if tree.get("part") == "core" or tree.get("part") is None:
                own_cores.add(deck_id)
        cards = tree.get("cards")
        if isinstance(cards, list):
            cards_total += len(cards)
            for card in cards:
                if not isinstance(card, dict):
                    continue
                cid = card.get("id")
                if isinstance(cid, str):
                    if not cid.startswith(prefix):
                        errors.append(f"{name}: card {cid!r} must start with {prefix!r}")
                    if cid in card_ids:
                        errors.append(f"{name}: card id {cid!r} is also in {card_ids[cid]}")
                    card_ids[cid] = name
    if cards_total > CARDS_MAX:
        errors.append(f"{cards_total} cards, at most {CARDS_MAX}")
    if modified:
        if not has_path:
            errors.append(f"the package has no {code}-path.yaml, which a modified "
                          f"language needs")
        if manifest.get("based_on") is None:
            warnings.append(f"{MANIFEST}: based_on is missing; say which course "
                            f"revision you started from")
    for name, tree in sorted(trees.items()):
        if tree.get("kind") != "path":
            continue
        for unit in tree.get("units") or []:
            decks = unit.get("decks") if isinstance(unit, dict) else unit
            for deck in decks if isinstance(decks, list) else []:
                if not isinstance(deck, str) or deck == "*":
                    continue
                if deck not in own_cores and deck.startswith(MARKER):
                    errors.append(f"{name}: unit names {deck!r}, which the package "
                                  f"does not have")
    return errors, warnings, manifest


def translate(text: str, code: str) -> str:
    """The deck [text] with `fnpd-<code>-` written as `<code>-`, as the
    repository's own checks expect ids."""
    return text.replace(f"{MARKER}{code}-", f"{code}-")


def check_decks(files: dict[str, bytes], code: str) -> list[vd.Report]:
    """The validator's own checks of each core and layer, on the package's
    files with their ids translated. A report's path is the package's name for
    the file."""
    trees, _ = _parse(files)
    reports: list[vd.Report] = []
    tmp = Path(tempfile.mkdtemp(prefix="private-check-"))
    vd.PRIVATE_MODE = True
    try:
        for name, tree in sorted(trees.items()):
            if name == MANIFEST or tree.get("kind") in DATA_KINDS:
                continue
            text = translate(files[name].decode("utf-8"), code)
            deck_id = tree.get("id")
            stem = (deck_id[len(MARKER):] if isinstance(deck_id, str)
                    and deck_id.startswith(MARKER) else Path(name).stem)
            if tree.get("kind") == "layer":
                native = tree.get("native")
                folder = native.get("code") if isinstance(native, dict) else None
                target = tmp / code / str(folder or "xx") / f"{stem}.yaml"
            else:
                target = tmp / code / f"{stem}.yaml"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")
            try:
                report = vd.validate(target)
            except Exception as exc:  # noqa: BLE001
                # A check that cannot run on a private code is told, never
                # taken for a fault of the package.
                report = vd.Report(target)
                report.warn("checks", f"the validator's checks could not run: "
                                      f"{type(exc).__name__}")
            report.path = Path(name)
            reports.append(report)
    finally:
        vd.PRIVATE_MODE = False
        shutil.rmtree(tmp, ignore_errors=True)
    return reports


def check_private(target: Path) -> tuple[list[str], list[str], list[vd.Report]]:
    """Everything the package check finds: its errors, its warnings and the
    validator's reports of its decks (run only when the package itself has no
    error, because a broken package has no code to translate by)."""
    files, size, errors = load(target)
    if errors:
        return errors, [], []
    errors = check_files(files, size)
    if errors:
        return errors, [], []
    errors, warnings, manifest = check_package(files)
    reports: list[vd.Report] = []
    if manifest is not None and not errors:
        reports = check_decks(files, manifest["language"]["code"])
    return errors, warnings, reports


def main(args: list[str]) -> int:
    if len(args) != 1:
        print("usage: validate_decks.py --private <package folder or .fnzip>",
              file=sys.stderr)
        return 2
    target = Path(args[0])
    if not target.exists():
        print(f"error: {target} does not exist", file=sys.stderr)
        return 2
    errors, warnings, reports = check_private(target)
    for e in errors:
        print(f"  error   {e}")
    for w in warnings:
        print(f"  warning {w}")
    failed = 0
    for rep in reports:
        if rep.errors:
            failed += 1
            print(f"FAIL {rep.path}")
            for e in rep.errors:
                print(f"  error   {e}")
        for w in rep.warnings:
            print(f"  warning {rep.path}: {w}")
    if errors or failed:
        print(f"\n{len(errors) + failed} problem(s): the package is not ready to add.")
        return 1
    print(f"\n{len(reports)} decks checked: the package is ready to add.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
