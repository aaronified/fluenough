#!/usr/bin/env python3
"""Validate the sample deck on its own.

    python3 tools/validate_sample_decks.py [sample root]
    (default: test/fixtures/sample-decks, the folder that holds decks/)

validate_decks.py takes the repository it lives in for its own: its checks
across files also scan ROOT/decks, so pointing it at the sample while a real
decks/ sits in the checkout reports every sample core as a duplicate of the
real one. This copies tools/, assets/ and the sample's decks/ to a temporary
directory, where the copied validator's ROOT/decks IS the sample, and runs it
there (the index check off: the sample's index is a snapshot's). Exit codes
are the validator's: 0 ok, 1 errors, 2 bad arguments.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT = ROOT / "test" / "fixtures" / "sample-decks"


def main(argv: list[str]) -> int:
    sample = Path(argv[1]) if len(argv) > 1 else DEFAULT
    if len(argv) > 2 or not (sample / "decks").is_dir():
        print(f"error: {sample}/decks is not a folder", file=sys.stderr)
        return 2
    skip = shutil.ignore_patterns("__pycache__", "*.pyc")
    with tempfile.TemporaryDirectory(prefix="sample-decks-") as tmp:
        work = Path(tmp)
        shutil.copytree(ROOT / "tools", work / "tools", ignore=skip)
        shutil.copytree(ROOT / "assets", work / "assets")
        shutil.copytree(sample / "decks", work / "decks")
        env = dict(os.environ, FLUENOUGH_SKIP_INDEX_CHECK="1")
        done = subprocess.run(
            [sys.executable, "-u", str(work / "tools" / "validate_decks.py"),
             str(work / "decks")],
            cwd=work, env=env)
        return done.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv))
