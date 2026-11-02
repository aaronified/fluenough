#!/usr/bin/env python3
"""TEMPORARY, for the validator-equivalence workflow: copies decks/ (and the
assets and docs the validator reads) to a directory and breaks each language
folder in one known way, so that the old and the new validator are compared on
a tree full of errors and not only on a clean one.

Usage: python3 tools/make_broken_copy.py <directory>

Each language folder gets its first core or deck file a card with an unknown
field, and a second file with a trailing tab; the validator's output on the
copy then has an error of each kind per language. The copy has its own tools/
beside it (the validator finds its repository from its own location).
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def main(argv: list[str]) -> int:
    target = Path(argv[1])
    for name in ("decks", "assets", "tools", "docs"):
        if (REPO / name).exists():
            shutil.copytree(REPO / name, target / name, dirs_exist_ok=True,
                            ignore=shutil.ignore_patterns("__pycache__"))
    broken = 0
    for lang in sorted(p for p in (target / "decks").iterdir() if p.is_dir()):
        files = sorted(f for f in lang.glob("*.yaml")
                       if not f.stem.endswith(("-path", "-facts", "-romanisation")))
        if not files:
            continue
        first = files[0]
        text = first.read_text(encoding="utf-8")
        marker = "\ncards:"
        if marker in text:
            first.write_text(text.replace(marker, "\nbogus_field_for_the_equivalence_check: 1"
                                          + marker, 1), encoding="utf-8")
            broken += 1
        if len(files) > 1:
            second = files[1]
            lines = second.read_text(encoding="utf-8").split("\n")
            lines[-2 if len(lines) > 1 else 0] += "\t"
            second.write_text("\n".join(lines), encoding="utf-8")
            broken += 1
    print(f"broke {broken} files in {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
