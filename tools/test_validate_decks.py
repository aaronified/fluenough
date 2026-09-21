#!/usr/bin/env python3
"""Tests for the parts of validate_decks.py that are not about a deck's content.

Stdlib `unittest` plus PyYAML, the same two things the validator itself needs,
so a deck contributor can run these without a Flutter toolchain.

Every test here builds a throwaway repository in a temporary directory and
runs the validator as a subprocess against it. That is deliberate: the bug
these exist for was one of resolution — the check read `pubspec.yaml` from the
working directory, so it passed silently when run from anywhere else — and a
test that imports the function and calls it in-process cannot see that.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
VALIDATOR = REPO / "tools" / "validate_decks.py"
SAMPLE_DECK = REPO / "decks" / "es" / "es-core-100.yaml"

PUBSPEC = """\
name: fluenough
flutter:
  uses-material-design: true
  assets:
    - decks/es/
"""


class BundledAssetCheck(unittest.TestCase):
    """`decks/<lang>/` must appear under flutter.assets, from any directory."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

        (self.tmp / "tools").mkdir()
        shutil.copy(VALIDATOR, self.tmp / "tools" / "validate_decks.py")
        (self.tmp / "pubspec.yaml").write_text(PUBSPEC, encoding="utf-8")

        (self.tmp / "decks" / "es").mkdir(parents=True)
        shutil.copy(SAMPLE_DECK, self.tmp / "decks" / "es")

    def add_unbundled_language(self) -> None:
        """A second language directory that pubspec.yaml does not list."""
        hi = self.tmp / "decks" / "hi"
        hi.mkdir()
        deck = SAMPLE_DECK.read_text(encoding="utf-8")
        deck = deck.replace("id: es-core-100", "id: hi-probe")
        deck = deck.replace("code: es", "code: hi")
        deck = deck.replace("name: Spanish", "name: Hindi")
        deck = deck.replace("tts: es-ES", "tts: hi-IN")
        (hi / "hi-probe.yaml").write_text(deck, encoding="utf-8")

    def run_validator(
        self, target: str, cwd: Path
    ) -> subprocess.CompletedProcess:
        validator = self.tmp / "tools" / "validate_decks.py"
        return subprocess.run(
            [sys.executable, str(validator), target],
            cwd=cwd,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_passes_when_every_language_is_bundled(self) -> None:
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_fails_when_a_language_is_not_bundled(self) -> None:
        self.add_unbundled_language()
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("decks/hi/", result.stdout)

    def test_fails_from_a_different_working_directory(self) -> None:
        """The regression: the check used to read pubspec.yaml from the CWD.

        Run from the parent, it found no pubspec.yaml, returned no problems,
        and reported every deck valid — a guard that fails open.
        """
        self.add_unbundled_language()
        result = self.run_validator(f"{self.tmp.name}/decks/", self.tmp.parent)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("decks/hi/", result.stdout)

    def test_absolute_paths_do_not_produce_false_failures(self) -> None:
        """The other half: absolute paths used to be compared verbatim.

        Every deck was reported unbundled, naming an absolute path that could
        never appear in pubspec.yaml.
        """
        result = self.run_validator(str(self.tmp / "decks"), self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_absolute_path_still_catches_a_real_miss(self) -> None:
        self.add_unbundled_language()
        result = self.run_validator(str(self.tmp / "decks"), self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("decks/hi/", result.stdout)

    def test_a_deck_outside_the_repo_is_not_called_unbundled(self) -> None:
        """Validating a deck you are drafting elsewhere is legitimate.

        Nothing in pubspec.yaml could bundle it, so it is not a finding.
        """
        elsewhere = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, elsewhere, True)
        shutil.copy(SAMPLE_DECK, elsewhere)

        result = self.run_validator(str(elsewhere), self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
