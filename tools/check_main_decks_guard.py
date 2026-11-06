#!/usr/bin/env python3
"""Fail a pull request to main that edits the frozen decks/ folder.

    git diff --name-only --no-renames HEAD^1 HEAD | python3 tools/check_main_decks_guard.py

Decks live on the decks-live branch (owner, 2026-11-06). Main's decks/ is
frozen so an app older than the one that reads decks-live keeps the decks it
had; nothing validates it any more, so an edit here would break silently.
The only app files under decks/ are ALLOWED (the same two the "Which parts
changed" job counts as app files): themes.yaml, bundled in the app, and
min_app.json. Reads changed paths, one per line, from stdin or a file
argument. Exit 0 ok, 1 forbidden edit, 2 bad arguments.
"""

from __future__ import annotations

import sys

ALLOWED = frozenset({"decks/themes.yaml", "decks/min_app.json"})


def forbidden(paths: list[str]) -> list[str]:
    """Changed paths under decks/ that are not an allowed app file."""
    out = []
    for raw in paths:
        p = raw.strip()
        if len(p) > 1 and p[0] == '"':
            # git quotes odd paths ("decks/\303\251.yaml") unless
            # core.quotepath=false; never let a quote hide a decks/ path.
            p = p[1:]
        if p.startswith("decks/") and p not in ALLOWED:
            out.append(p)
    return out


def main(argv: list[str]) -> int:
    if len(argv) > 2:
        print(__doc__)
        return 2
    try:
        text = open(argv[1], encoding="utf-8").read() if len(argv) == 2 else sys.stdin.read()
    except OSError as e:
        print(f"cannot read: {e}")
        return 2
    bad = forbidden(text.splitlines())
    if not bad:
        return 0
    print("::error::Main's decks/ is frozen. Open this pull request against `decks-live`.")
    print("Only decks/themes.yaml and decks/min_app.json may change on main. Offending files:")
    for p in bad[:20]:
        print(f"  {p}")
    if len(bad) > 20:
        print(f"  ... and {len(bad) - 20} more")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
