#!/usr/bin/env python3
"""Does decks-live's decks/themes.yaml still list every theme main's does?

    python3 tools/check_themes_in_sync.py <main themes.yaml> <decks-live themes.yaml>

The theme list is deck-owned data (owner, 2026-11-11): decks-live holds the
current one, and an app downloads it with the decks. Main's copy is bundled
in the app as the fallback for an offline first start and for an app too old
to download it, so it is only ever behind decks-live's. This check keeps that
safe: every theme id of main's copy must still be in decks-live's (ids are
permanent, like card ids), so that an app on the bundled copy never meets a
deck whose theme the fallback lacks the other way round, and so a theme is
never dropped from under the fallback. New themes on decks-live need no
change on main. Exit 0 ok, 1 a theme of main's is missing on decks-live,
2 bad arguments.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml


def theme_ids(path: Path) -> list[str]:
    """The theme ids of a themes file, in order; raises ValueError if it is
    not one."""
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict) or not isinstance(raw.get("themes"), list):
        raise ValueError(f"{path} is not a themes file")
    ids = []
    for theme in raw["themes"]:
        if not isinstance(theme, dict) or not isinstance(theme.get("id"), str):
            raise ValueError(f"{path} has a theme with no id")
        ids.append(theme["id"])
    return ids


def missing(main: Path, live: Path) -> list[str]:
    """Theme ids main's copy lists that decks-live's does not."""
    have = set(theme_ids(live))
    return [i for i in theme_ids(main) if i not in have]


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    a, b = Path(argv[1]), Path(argv[2])
    for p in (a, b):
        if not p.is_file():
            print(f"::error::{p} not found")
            return 2
    try:
        gone = missing(a, b)
    except (ValueError, yaml.YAMLError) as e:
        print(f"::error::{e}")
        return 2
    if not gone:
        return 0
    print("::error::decks/themes.yaml on decks-live no longer lists "
          f"{', '.join(gone)}, which main's bundled copy has. Theme ids are "
          "permanent: put them back (an app on the bundled copy still uses them).")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
