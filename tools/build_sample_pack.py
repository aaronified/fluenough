#!/usr/bin/env python3
"""Build the SAMPLE DECK PACK, a zip of example decks to read and copy (#92).

Usage:
    python3 tools/build_sample_pack.py [OUTPUT.zip]     (default: fluenough-sample-decks.zip)

The pack holds what the repository already keeps frozen for its own checks:

- `kinds/`   one deck of every kind the fixtures cover (vocab, script,
             proverbs, culture, multi-word, a professional register deck),
             with a path, topics, creators and recommendations, in the
             made-up language `zz` (test/fixtures/deck-kinds);
- `course/`  the Spanish and Telugu sample course (and the IPA decks) (test/fixtures/sample-decks,
             refreshed by tools/snapshot_sample_decks.py).

The release workflow attaches it to every release. Needs only Python 3.11+.
The output is the same for the same inputs (sorted files, fixed timestamps).
"""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PARTS = (
    ("kinds", "test/fixtures/deck-kinds/decks"),
    ("course", "test/fixtures/sample-decks/decks"),
)
TOP = "fluenough-sample-decks"
FIXED_TIME = (2026, 1, 1, 0, 0, 0)

README = """Fluenough sample decks
======================

Example decks to read and copy when you write your own. The decks are
licensed CC BY-SA 4.0, like every Fluenough deck.

kinds/   One deck of every kind, in the made-up language "zz": vocab, script,
         proverbs, culture, multi-word and a professional register deck, with
         a path, topics, creators and recommendations.
course/  A small real course, Spanish and Telugu (and the IPA decks), with its
         path, core decks and English layers.

The format is described in the Deck format page of the wiki:
https://github.com/aaronified/fluenough/wiki/Deck-Format

A single deck can be added in the app: Settings, Your decks.
"""


def build(output: Path, root: Path = ROOT) -> int:
    """Write the zip; return the number of deck files in it."""
    count = 0
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as z:
        info = zipfile.ZipInfo(f"{TOP}/README.txt", FIXED_TIME)
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, README)
        for folder, rel in PARTS:
            base = root / rel
            if not base.is_dir():
                raise FileNotFoundError(f"{rel} is missing")
            for path in sorted(p for p in base.rglob("*") if p.is_file()):
                name = f"{TOP}/{folder}/{path.relative_to(base).as_posix()}"
                info = zipfile.ZipInfo(name, FIXED_TIME)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o644 << 16
                z.writestr(info, path.read_bytes())
                count += 1
    return count


def main(argv: list[str]) -> int:
    output = Path(argv[1]) if len(argv) > 1 else Path(
        "fluenough-sample-decks.zip")
    try:
        count = build(output)
    except (OSError, zipfile.BadZipFile) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    print(f"{output}: {count} files")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
