#!/usr/bin/env python3
"""Convert every deck's `modes` list from an allowlist to an opt-out (#522,
step 6, ADR-0039).

Until now `modes: [recognition, production]` meant "only these". From the
release that reads `modes` as an opt-out it means "not these", so each shipped
list is rewritten to its complement over the four vocabulary skills
(recognition, production, listening, speaking), and never names a grammar
skill. A list that names all four becomes no `modes` at all. Card ids and
meanings do not change; a card that was allowed everything stays allowed
everything.

    python3 tools/convert_modes.py decks/            # report only
    python3 tools/convert_modes.py decks/ --write    # rewrite the files

The report lists every file changed and each card whose `modes` changed
meaning, for a reviewer to read. Only flow lists on one line are converted,
which is how every shipped deck writes them; anything else stops the run.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

VOCABULARY = ("recognition", "production", "listening", "speaking")

_LINE = re.compile(r"^(?P<head>\s*(?:-\s*)?(?:\{.*?)?)modes:\s*\[(?P<body>[^\]]*)\](?P<tail>.*)$")
_BARE = re.compile(r"\bmodes:")
_ID = re.compile(r"""\bid:\s*["']?([\w.\-]+)["']?""")
_REF = re.compile(r"""\bref:\s*["']?([\w.\-]+)["']?""")


def names(body: str) -> list[str]:
    return [n.strip().strip("\"'") for n in body.split(",") if n.strip()]


def complement(allowed: list[str]) -> list[str]:
    """The vocabulary skills a list leaves out, in the canonical order."""
    return [m for m in VOCABULARY if m not in allowed]


def convert_text(text: str) -> tuple[str, list[dict]]:
    """The file with every `modes` list converted, and what changed."""
    out: list[str] = []
    changes: list[dict] = []
    card = None
    for lineno, line in enumerate(text.splitlines(keepends=True), 1):
        stripped = line.lstrip()
        if stripped.startswith("- "):
            m = _ID.search(stripped) or _REF.search(stripped)
            if m:
                card = m.group(1)
        elif (m := re.match(r"id:\s*[\"']?([\w.\-]+)", stripped)) and line.startswith("    id:"):
            card = m.group(1)
        found = _LINE.match(line.rstrip("\n"))
        if not found:
            if _BARE.search(line) and "modes:" in line and "[" not in line.split("modes:", 1)[1]:
                raise ValueError(f"line {lineno}: modes is not a one-line list: {line.strip()}")
            out.append(line)
            continue
        old = names(found["body"])
        new = complement(old)
        newline = "\n" if line.endswith("\n") else ""
        head, tail = found["head"], found["tail"]
        if new:
            body = ", ".join(f'"{m}"' for m in new)
            out.append(f"{head}modes: [{body}]{tail}{newline}")
        else:
            # Everything was allowed: no `modes` says the same.
            rest = (head.rstrip().rstrip(",") + tail).rstrip()
            if rest.strip():
                raise ValueError(f"line {lineno}: modes shares a line with other fields")
            if tail.strip():
                out.append(f"{head}{tail.lstrip(', ')}{newline}")
        changes.append({"line": lineno, "card": card, "old": old, "new": new})
    return "".join(out), changes


def convert_tree(root: Path, write: bool) -> list[dict]:
    """Convert every deck file under [root]; [write] saves them."""
    results: list[dict] = []
    for path in sorted(root.rglob("*.yaml")):
        text = path.read_text(encoding="utf-8")
        if "modes:" not in text:
            continue
        new_text, changes = convert_text(text)
        if not changes:
            continue
        if write:
            path.write_text(new_text, encoding="utf-8")
        results.append({"path": path, "changes": changes})
    return results


def report(results: list[dict], root: Path) -> str:
    """The change list: per file, then each distinct meaning change counted."""
    lines = ["# modes: allowlist to opt-out", ""]
    total = sum(len(r["changes"]) for r in results)
    lines.append(f"{total} cards in {len(results)} files change.")
    kinds: dict[tuple[str, str], int] = {}
    for r in results:
        for c in r["changes"]:
            key = (", ".join(c["old"]) or "(none)", ", ".join(c["new"]) or "(none: all four)")
            kinds[key] = kinds.get(key, 0) + 1
    lines += ["", "| Was (only these) | Becomes (not these) | Cards |", "|---|---|---|"]
    for (old, new), n in sorted(kinds.items(), key=lambda kv: -kv[1]):
        lines.append(f"| {old} | {new} | {n} |")
    lines += ["", "| File | Cards |", "|---|---|"]
    for r in results:
        lines.append(f"| {r['path'].relative_to(root)} | {len(r['changes'])} |")
    phrases = [
        (r["path"], c["card"]) for r in results for c in r["changes"]
        if "production" in c["old"]
    ]
    lines += ["", f"{len(phrases)} lists allowed production; a phrase that does not "
              "rearrange is still not typed, as before, so check any such card "
              "in the files above by hand."]
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("decks", type=Path)
    ap.add_argument("--write", action="store_true", help="rewrite the files")
    args = ap.parse_args(argv)
    try:
        results = convert_tree(args.decks, args.write)
    except ValueError as e:
        print(e, file=sys.stderr)
        return 1
    sys.stdout.write(report(results, args.decks))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
