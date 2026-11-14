#!/usr/bin/env python3
"""Write the `chars` of a language's script topics from the cards of their
decks (#1228), so a topic of 200 characters is never copied by hand.

Usage:
    python3 tools/topic_chars.py ja                  # report only
    python3 tools/topic_chars.py ja --write          # patch the topics file
    python3 tools/topic_chars.py ja --check          # exit 1 if a topic differs
    python3 tools/topic_chars.py ja --all-targets    # every target, not only
                                                     # one-character ones

A topic of `kind: "script"` that lists `decks` gets `chars`: the target of
each single-character card of those decks (a letter, a kana, a conjunct, a
hanzi), in deck and card order, each once. A character the topic already
carries as a mapping (`{ text: ..., reading: ... }`) keeps its mapping. A
topic with no `decks` (one that only names `script_units`) is left alone.
Only the topic's `chars` lines are rewritten; the rest of the file is kept
byte for byte. The validator (`check_topic_chars`) is the judge of the result.

No script and no language is named here: what counts as one character is
Unicode's own marks and joiners (`validate_decks._clusters`).

Stdlib and PyYAML only.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks as vd  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent


def wanted_chars(t: dict, by_core: dict, all_targets: bool) -> list[str]:
    """The `chars` a topic's decks call for."""
    out = []
    for target in vd.topic_deck_targets(t, by_core):
        if all_targets:
            if re.search(r"\s", target) or len(target) > vd.MAX_CHARS_LEN:
                continue
        elif vd._clusters(target) != 1:
            continue
        out.append(target)
    return out


def _scalar(value: object) -> str:
    return json.dumps(value, ensure_ascii=False)


def render_chars(chars: list[str], existing: dict[str, dict], indent: int = 4) -> str:
    """The `chars` line: a flow list of quoted characters, a character that
    carried a mapping before keeping it."""
    items = []
    for ch in chars:
        if ch in existing:
            body = ", ".join(f"{k}: {_scalar(v)}" for k, v in existing[ch].items())
            items.append("{ " + body + " }")
        else:
            items.append(_scalar(ch))
    return " " * indent + "chars: [" + ", ".join(items) + "]"


def existing_mappings(t: dict) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for ref in t.get("chars") or []:
        if isinstance(ref, dict) and isinstance(ref.get("text"), str):
            out[unicodedata.normalize("NFC", ref["text"])] = ref
    return out


def current_chars(t: dict) -> list[str]:
    out = []
    for ref in t.get("chars") or []:
        text = ref.get("text") if isinstance(ref, dict) else ref
        if isinstance(text, str):
            out.append(unicodedata.normalize("NFC", text))
    return out


def value_end(lines: list[str], at: int, key_indent: int, end: int) -> int:
    """The line after the value of the key on line [at]: the lines under it,
    deeper than the key or a list item of the key's own indent (PyYAML writes
    lists that way), and no blank line at its tail."""
    stop = at + 1
    while stop < end:
        ln = lines[stop]
        indent = len(ln) - len(ln.lstrip())
        if ln.strip() and indent <= key_indent \
                and not (indent == key_indent and ln.lstrip().startswith("- ")):
            break
        stop += 1
    while stop > at + 1 and not lines[stop - 1].strip():
        stop -= 1
    return stop


def patch(lines: list[str], tid: str, chars: list[str],
          existing: dict[str, dict]) -> bool:
    """Replace, or add after the `decks` line, the `chars` of topic [tid] in
    the file's [lines], written at the indentation of the topic's own keys and
    with the file's line ending. False, nothing changed, when the topic's
    block is not found or the `chars` it would replace holds a comment."""
    crlf = bool(lines) and lines[0].endswith("\r")
    top = next((i for i, ln in enumerate(lines) if re.match(r"topics:\s*(#.*)?\r?$", ln)), None)
    if top is None:
        return False
    start = next((i for i in range(top + 1, len(lines))
                  if re.match(rf'\s*-\s+id:\s*["\']?{re.escape(tid)}["\']?\s*(#.*)?\r?$', lines[i])), None)
    if start is None:
        return False
    indent = len(lines[start]) - len(lines[start].lstrip())
    end = len(lines)
    for i in range(start + 1, len(lines)):
        ln = lines[i]
        if ln.strip() and not ln.lstrip().startswith("#") \
                and len(ln) - len(ln.lstrip()) <= indent:
            end = i
            break
    # `- id:` puts the topic's other keys two columns in.
    key_indent = indent + 2
    chars_at = next((i for i in range(start + 1, end)
                     if re.match(rf"\s{{{key_indent}}}chars:", lines[i])), None)
    new_line = render_chars(chars, existing, key_indent) + ("\r" if crlf else "")
    if chars_at is not None:
        stop = value_end(lines, chars_at, key_indent, end)
        if any("#" in ln for ln in lines[chars_at:stop]):
            return False
        lines[chars_at:stop] = [new_line]
        return True
    decks_at = next((i for i in range(start + 1, end)
                     if re.match(rf"\s{{{key_indent}}}decks:", lines[i])), None)
    if decks_at is None:
        return False
    lines.insert(value_end(lines, decks_at, key_indent, end), new_line)
    return True


def run(lang: str, decks: Path, write: bool, all_targets: bool) -> tuple[list[str], int]:
    """(a report line for each script topic, how many differ)."""
    topics_path = decks / lang / f"{lang}-topics.yaml"
    raw = vd._load_raw(topics_path)
    if not isinstance(raw, dict) or not isinstance(raw.get("topics"), list):
        raise SystemExit(f"error: {topics_path} is not a topics file")
    reports = []
    for p in vd.collect(decks / lang):
        if p.resolve() != topics_path.resolve():
            reports.append(vd.validate(p))
    by_core = vd._context(reports).lang(lang).by_core()
    with open(topics_path, encoding="utf-8", newline="") as f:
        text = f.read()
    lines = text.split("\n")
    report: list[str] = []
    differ = 0
    for t in raw["topics"]:
        if not isinstance(t, dict) or t.get("kind") != "script" or not t.get("decks"):
            continue
        tid = t.get("id")
        wanted = wanted_chars(t, by_core, all_targets)
        have = current_chars(t)
        if not wanted:
            report.append(f"{tid}: its decks have no matching cards, left alone")
            continue
        if wanted == have:
            report.append(f"{tid}: {len(have)} characters, as the decks say")
            continue
        differ += 1
        added = [c for c in wanted if c not in have]
        gone = [c for c in have if c not in wanted]
        reordered = "" if (added or gone) else ", reordered"
        report.append(f"{tid}: {len(have)} -> {len(wanted)} characters "
                      f"(+{len(added)}, -{len(gone)}{reordered})")
        if write and not patch(lines, tid, wanted, existing_mappings(t)):
            report.append(f"{tid}: could not patch it (block not found, or a comment in its chars), left alone")
    if write and differ:
        with open(topics_path, "w", encoding="utf-8", newline="") as f:
            f.write("\n".join(lines))
    return report, differ


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Write a language's script topics' chars from their decks.")
    parser.add_argument("lang", help="the language's code, such as ja")
    parser.add_argument("--decks", type=Path, default=ROOT / "decks",
                        help="the decks folder (default: the repository's)")
    parser.add_argument("--write", action="store_true", help="patch the topics file")
    parser.add_argument("--check", action="store_true",
                        help="report only, and exit 1 if a topic differs")
    parser.add_argument("--all-targets", action="store_true",
                        help="list every target of the decks, not only one-character "
                             "cards (a kana pair, a longer conjunct)")
    args = parser.parse_args(argv[1:])
    if not vd.LANG_RE.fullmatch(args.lang):
        print(f"error: {args.lang!r} is not a language code", file=sys.stderr)
        return 2
    if not (args.decks / args.lang / f"{args.lang}-topics.yaml").is_file():
        print(f"error: {args.lang} has no topics file "
              f"{args.decks / args.lang / (args.lang + '-topics.yaml')}", file=sys.stderr)
        return 2
    if args.write and args.check:
        print("error: --write and --check do not go together", file=sys.stderr)
        return 2
    report, differ = run(args.lang, args.decks, args.write, args.all_targets)
    print("\n".join(report) or "no script topic lists decks")
    if not args.write and differ:
        print(f"{differ} topic(s) differ; run with --write to patch", file=sys.stderr)
    return 1 if args.check and differ else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
