#!/usr/bin/env python3
"""Pick the Flutter test files one CI shard runs.

Usage:
    python3 tools/test_shard.py --total-shards 8 --shard-index 3
    flutter test $(python3 tools/test_shard.py --total-shards 8 --shard-index 3)
    python3 tools/test_shard.py --total-shards 8 --plan      # every shard, with its weight

`--shard-index` counts from 0, as `flutter test` does. Prints one test file
per line. Exit status: 0 on success, 1 if the shard would be empty (an empty
file list would make `flutter test` run EVERYTHING), 2 if the arguments are
wrong.

Why not `flutter test --total-shards`: that splits the tests one by one, round
robin, so every shard still compiles and loads every test file, and a shard's
time is luck (main run 41886601755: 249 s to 750 s for the same number of
tests). Giving each shard whole files, heaviest first onto the lightest shard,
makes each shard load only its own files and lets the weights balance them.

The weights are in test/shard_weights.json: roughly seconds on a CI runner,
measured from a CI log. A file that is not listed weighs "default", so a new
test file never breaks the split; it is merely placed by a guess until
someone lists it. A listed file that no longer exists is ignored here and
caught by tools/test_test_shard.py. To refresh the numbers, read the
"Passing tests" group of a shard's `flutter test` log: its timestamps show how
long each test file took.

Requires only the Python standard library.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WEIGHTS = REPO / "test" / "shard_weights.json"
FALLBACK_DEFAULT = 8


def discover(root: Path) -> list[str]:
    """Every test file under root/test, as `flutter test` finds them."""
    return sorted(
        p.relative_to(root).as_posix() for p in (root / "test").rglob("*_test.dart")
    )


def load_weights(path: Path) -> tuple[dict[str, float], float]:
    """(weights by file, default weight); a missing file gives equal weights."""
    if not path.exists():
        return {}, FALLBACK_DEFAULT
    data = json.loads(path.read_text(encoding="utf-8"))
    return dict(data.get("files", {})), data.get("default", FALLBACK_DEFAULT)


def assign(
    files: list[str],
    weights: dict[str, float],
    default: float,
    total: int,
) -> list[list[str]]:
    """Split files over `total` shards: heaviest first, onto the lightest shard.

    Deterministic: ties go to the lowest shard, equal weights to the earlier
    path, and the input order does not matter.
    """
    shards: list[list[str]] = [[] for _ in range(total)]
    loads = [0.0] * total
    for f in sorted(set(files), key=lambda f: (-weights.get(f, default), f)):
        i = min(range(total), key=lambda k: (loads[k], k))
        shards[i].append(f)
        loads[i] += weights.get(f, default)
    return [sorted(s) for s in shards]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--total-shards", type=int, required=True)
    ap.add_argument("--shard-index", type=int, help="0-based")
    ap.add_argument("--plan", action="store_true", help="print every shard and its weight")
    ap.add_argument("--root", type=Path, default=REPO, help=argparse.SUPPRESS)
    args = ap.parse_args(argv)

    total = args.total_shards
    if total < 1:
        ap.error("--total-shards must be at least 1")
    if not args.plan and (args.shard_index is None or not 0 <= args.shard_index < total):
        ap.error("--shard-index must be 0..total-shards-1 (or use --plan)")

    files = discover(args.root)
    weights, default = load_weights(args.root / "test" / "shard_weights.json")
    shards = assign(files, weights, default, total)

    if args.plan:
        for i, s in enumerate(shards):
            w = sum(weights.get(f, default) for f in s)
            print(f"shard {i}: {len(s)} files, weight {w:g}")
            for f in s:
                print(f"  {weights.get(f, default):>6g}  {f}")
        return 0

    mine = shards[args.shard_index]
    if not mine:
        print(
            f"shard {args.shard_index} of {total} has no test files "
            f"({len(files)} found); not running, because `flutter test` with "
            "no files would run them all",
            file=sys.stderr,
        )
        return 1
    print("\n".join(mine))
    return 0


if __name__ == "__main__":
    sys.exit(main())
