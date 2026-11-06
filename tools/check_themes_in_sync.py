#!/usr/bin/env python3
"""Is decks-live's decks/themes.yaml the same file as main's?

    python3 tools/check_themes_in_sync.py <main themes.yaml> <decks-live themes.yaml>

The app bundles main's decks/themes.yaml (pubspec.yaml); an edit made only on
decks-live never reaches an app, while decks-live's validator reads its own
copy (owner, 2026-11-06: themes.yaml is edited only on main). decks-live's CI
runs this against main's copy. Exit 0 identical, 1 differ, 2 bad arguments.
"""

from __future__ import annotations

import sys
from pathlib import Path


def same(a: Path, b: Path) -> bool:
    """Equal bytes, ignoring a CRLF checkout."""
    norm = lambda p: p.read_bytes().replace(b"\r\n", b"\n")
    return norm(a) == norm(b)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    a, b = Path(argv[1]), Path(argv[2])
    for p in (a, b):
        if not p.is_file():
            print(f"::error::{p} not found")
            return 2
    if same(a, b):
        return 0
    print("::error::decks/themes.yaml on decks-live differs from main's copy. "
          "The app bundles main's; edit it only on main, then bring decks-live's copy to match.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
