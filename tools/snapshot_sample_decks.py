#!/usr/bin/env python3
"""Refresh the SAMPLE DECK, the frozen deck set the app's tests read (owner, 2026-11-06).

Usage:
    python3 tools/snapshot_sample_decks.py

Copies the shipped files of a few whole languages from decks/ into
test/fixtures/sample-decks/decks/, with an index of their own, so that the pin
fails only when code changes how asks are chosen, never when a deck changes
(#522). Run it, then regenerate the golden, only for an intended change to
the pin; never as part of a deck pull request. See the test's header.

The tests that read it: grading_test, ipa_switch_everywhere_test,
progress_decks_test and sample_decks_test. A refresh may move numbers they
assert: update them in the same change. The decks-live branch's CI checks that
its real decks speak the sample's format (tools/check_sample_contract.py).

Needs only Python 3.11+, like the other deck tools. The fixture is not a
shipped deck: the validator and deck_index.py read decks/ only.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# The real decks: the decks-live branch, checked out beside, or this checkout's
# own decks/ (main's frozen copy) when FLUENOUGH_DECKS_SOURCE is not set.
SOURCE = Path(os.environ.get("FLUENOUGH_DECKS_SOURCE", ROOT / "decks")).resolve()
TARGET = ROOT / "test" / "fixtures" / "sample-decks" / "decks"

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
    # The deck-owned sections file the released app bundles: not in the index,
    # but the sample keeps it so the bundled-asset build finds it.
    paths.append("decks/sections.yaml")
    for language in kept:
        paths += [f["path"] for f in language["files"]]
        paths += [m["path"] for m in language.get("media", [])]
    for path in paths:
        to = TARGET.parent / path
        to.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SOURCE.parent / path, to)
    (TARGET / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"{len(paths)} files under {TARGET.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
