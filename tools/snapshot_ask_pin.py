#!/usr/bin/env python3
"""Refresh the frozen deck copy that test/core/scheduling/ask_pin_test.dart reads.

Usage:
    python3 tools/snapshot_ask_pin.py

Copies the shipped files of a few whole languages from decks/ into
test/fixtures/ask_pin/decks/, with an index of their own, so that the pin
fails only when code changes how asks are chosen, never when a deck changes
(#522). Run it, then regenerate the golden, only for an intended change to
the pin; never as part of a deck pull request. See the test's header.

Needs only Python 3.11+, like the other deck tools. The fixture is not a
shipped deck: the validator and deck_index.py read decks/ only.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "decks"
TARGET = ROOT / "test" / "fixtures" / "ask_pin" / "decks"

# Whole languages, because a deck's cards refer to its path and its siblings.
# te: every card shape, rules cells, numbers, a script guide, layers.
# ipa: not typed, so no typed asks. es: a Latin-script language.
LANGUAGES = ("es", "ipa", "te")


def main() -> int:
    index = json.loads((SOURCE / "index.json").read_text(encoding="utf-8"))
    kept = [l for l in index["languages"] if l["code"] in LANGUAGES]
    if {l["code"] for l in kept} != set(LANGUAGES):
        print("a language is missing from decks/index.json", file=sys.stderr)
        return 1
    index["languages"] = kept
    if TARGET.exists():
        shutil.rmtree(TARGET)
    paths = list(index["bundled"])
    for language in kept:
        paths += [f["path"] for f in language["files"]]
        paths += [m["path"] for m in language.get("media", [])]
    for path in paths:
        to = TARGET.parent / path
        to.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / path, to)
    (TARGET / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"{len(paths)} files under {TARGET.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
