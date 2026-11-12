#!/usr/bin/env python3
"""Does a set of real decks speak the format the sample deck stands for?

    python3 tools/check_sample_contract.py <sample root> <decks dir>
    python3 tools/check_sample_contract.py test/fixtures/sample-decks decks

The sample deck (test/fixtures/sample-decks on main, owner 2026-11-06) is the
standard both CIs hold to: the app's tests read it, and the decks-live
branch's CI runs this against its real decks. It fails when the real index
and the sample's disagree on the index `version` or `schema`, when the real
index has a top-level key the sample's lacks, or when a deck file's `kind` is
not one the validator knows. It only notes which kinds the sample lacks.
Exit 0 ok, 1 mismatch, 2 bad arguments.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def kinds_of(index: dict) -> set[str]:
    kinds: set[str] = set()
    # The shared files (themes, sections, creators, recommendations) are
    # listed apart from the languages, with the kind of each.
    for entry in index.get("shared") or []:
        if isinstance(entry, dict) and "kind" in entry:
            kinds.add(entry["kind"])
    for language in index.get("languages", []):
        for group in ("files", "script_guides", "situations", "resources",
                      "shelves", "topics"):
            entries = language.get(group) or []
            if isinstance(entries, dict):
                entries = [entries]
            for entry in entries:
                if isinstance(entry, dict) and "kind" in entry:
                    kinds.add(entry["kind"])
    return kinds


def check(sample: dict, real: dict, known_kinds: set[str]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    notes: list[str] = []
    for key in ("version", "schema"):
        if sample.get(key) != real.get(key):
            errors.append(f"index {key}: the real decks have {real.get(key)!r}, "
                          f"the sample deck {sample.get(key)!r}")
    extra = sorted(set(real) - set(sample))
    if extra:
        errors.append(f"the real index has top-level keys the sample's lacks: {', '.join(extra)}")
    unknown = sorted(kinds_of(real) - known_kinds)
    if unknown:
        errors.append(f"deck kinds the validator does not know: {', '.join(unknown)}")
    missing = sorted(known_kinds - kinds_of(sample))
    if missing:
        notes.append(f"the sample has no file of kind: {', '.join(missing)}")
    return errors, notes


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    sample_root, decks = Path(argv[1]), Path(argv[2])
    sample_index = sample_root / "decks" / "index.json"
    real_index = decks / "index.json"
    for p in (sample_index, real_index):
        if not p.is_file():
            print(f"error: {p} does not exist", file=sys.stderr)
            return 2
    import validate_decks
    errors, notes = check(load(sample_index), load(real_index),
                          set(validate_decks.KINDS) | {"romanisation"})
    for n in notes:
        print(f"note: {n}")
    for e in errors:
        print(f"error: {e}")
    if not errors:
        print("The real decks speak the sample deck's format.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
