#!/usr/bin/env python3
"""Lint assets/citations.yaml with the rules the app's parser applies.

    python3 tools/check_citations.py [path]      # default assets/citations.yaml

The file lists the standards and the research the Research and standards page
shows (#214, #286). lib/core/data/citations.dart reads it in the app; this
applies the same rules, so that a bad entry fails in CI with its place named
rather than at the page. Exit 0 ok, 1 problems found (one per line), 2 bad
arguments.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

DEFAULT = Path(__file__).resolve().parent.parent / "assets" / "citations.yaml"

SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
FEATURE = re.compile(r"^[a-z][A-Za-z0-9]*$")
YEAR = re.compile(r"^[0-9]{4}$")
CONFIDENCES = {"High", "Medium", "Low"}
KINDS = {"standard", "research"}
SUPPORTED_SCHEMA = 1

ROOT_KEYS = {"schema", "kind", "groups"}
GROUP_KEYS = {"id", "kind", "title", "line", "appliesWhen", "entries"}
ENTRY_KEYS = {
    "id", "title", "authors", "issuer", "year", "venue", "url", "line",
    "confidence", "checked",
}

# Standards every build must list (the plan's table, #214).
REQUIRED_STANDARDS = {
    "cefr", "iso-15919", "ipa", "iso-639-bcp-47", "unicode", "fsrs",
}


class _StrictLoader(yaml.SafeLoader):
    """SafeLoader that refuses a mapping key given twice, as the app's YAML
    reader does."""

    def construct_mapping(self, node, deep=False):
        seen = set()
        for key_node, _ in node.value:
            key = self.construct_object(key_node, deep=True)
            if key in seen:
                raise yaml.YAMLError(f'duplicate key "{key}"')
            seen.add(key)
        return super().construct_mapping(node, deep)


def _text(node: dict, key: str, where: str, errors: list[str],
          pattern: re.Pattern | None = None, required: bool = False):
    """The trimmed text at key, or None; a problem is added to errors."""
    if key not in node:
        if required:
            errors.append(f"{where}: {key} is missing")
        return None
    value = node[key]
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{where}: {key} must be non-empty quoted text")
        return None
    value = value.strip()
    if pattern is not None and not pattern.match(value):
        errors.append(f'{where}: {key} is malformed ("{value}")')
        return None
    return value


def _unknown(node: dict, allowed: set[str], where: str,
             errors: list[str]) -> None:
    for key in node:
        if key not in allowed:
            errors.append(f'{where}: unknown key "{key}"')


def _entry(node, where: str, kind: str, ids: set[str],
           errors: list[str]) -> None:
    if not isinstance(node, dict):
        errors.append(f"{where} is not a mapping")
        return
    _unknown(node, ENTRY_KEYS, where, errors)
    cid = _text(node, "id", where, errors, SLUG, True)
    if cid is not None:
        if cid in ids:
            errors.append(f"{where}: {cid} is listed twice")
        ids.add(cid)
        where = f"{where} ({cid})"
    _text(node, "title", where, errors, required=True)
    if not isinstance(node.get("checked"), bool):
        errors.append(f"{where}: checked must be true or false")
    url = _text(node, "url", where, errors)
    if url is not None and (
        not url.startswith("https://")
        or len(url) == len("https://")
        or re.search(r"\s", url)
    ):
        errors.append(f"{where}: url must be an https link")
    year = _text(node, "year", where, errors, YEAR)
    confidence = _text(node, "confidence", where, errors)
    if confidence is not None and confidence not in CONFIDENCES:
        errors.append(f"{where}: confidence must be High, Medium or Low")
    _text(node, "venue", where, errors)
    authors = _text(node, "authors", where, errors)
    issuer = _text(node, "issuer", where, errors)
    line = _text(node, "line", where, errors)
    if kind == "standard":
        if issuer is None:
            errors.append(f"{where}: issuer is missing")
        if line is None:
            errors.append(f"{where}: line is missing")
        if authors is not None:
            errors.append(f"{where}: a standard has an issuer, not authors")
    elif kind == "research":
        if authors is None:
            errors.append(f"{where}: authors is missing")
        if year is None and "year" not in node:
            errors.append(f"{where}: year is missing")
        if issuer is not None:
            errors.append(f"{where}: research has authors, not an issuer")
        if line is not None:
            errors.append(f"{where}: the line belongs to the group")


def check(text: str) -> list[str]:
    """Every problem in a citations file's text; empty when it is sound."""
    errors: list[str] = []
    try:
        root = yaml.load(text, Loader=_StrictLoader)
    except yaml.YAMLError as e:
        return [f"citations: not YAML: {e}"]
    if not isinstance(root, dict):
        return ["citations: the file is not a mapping"]
    _unknown(root, ROOT_KEYS, "citations", errors)
    if root.get("kind") != "citations":
        errors.append('citations: kind must be "citations"')
    schema = root.get("schema")
    if not isinstance(schema, int) or isinstance(schema, bool) or schema < 1:
        errors.append("citations: schema must be a number")
    elif schema > SUPPORTED_SCHEMA:
        errors.append(f"citations: schema {schema} is newer than this app")
    groups = root.get("groups")
    if not isinstance(groups, list) or not groups:
        errors.append("citations: groups must be a non-empty list")
        return errors
    group_ids: set[str] = set()
    entry_ids: set[str] = set()
    for i, group in enumerate(groups):
        where = f"groups[{i}]"
        if not isinstance(group, dict):
            errors.append(f"{where} is not a mapping")
            continue
        _unknown(group, GROUP_KEYS, where, errors)
        gid = _text(group, "id", where, errors, SLUG, True)
        if gid is not None:
            if gid in group_ids:
                errors.append(f"{where}: {gid} is listed twice")
            group_ids.add(gid)
            where = f"{where} ({gid})"
        kind = _text(group, "kind", where, errors, required=True)
        if kind is not None and kind not in KINDS:
            errors.append(f'{where}: kind must be "standard" or "research"')
            kind = None
        _text(group, "title", where, errors, required=True)
        line = _text(group, "line", where, errors)
        if kind == "research" and line is None and "line" not in group:
            errors.append(f"{where}: a research group needs a line")
        _text(group, "appliesWhen", where, errors, FEATURE)
        entries = group.get("entries")
        if not isinstance(entries, list) or not entries:
            errors.append(f"{where}: entries must be a non-empty list")
            continue
        for j, entry in enumerate(entries):
            _entry(entry, f"{where} entries[{j}]", kind or "", entry_ids,
                   errors)
    return errors


def main(argv: list[str]) -> int:
    if len(argv) > 2:
        print(__doc__)
        return 2
    path = Path(argv[1]) if len(argv) == 2 else DEFAULT
    if not path.is_file():
        print(f"::error::{path} not found")
        return 2
    problems = check(path.read_text(encoding="utf-8"))
    for problem in problems:
        print(f"::error::{problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
