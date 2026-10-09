#!/usr/bin/env python3
"""Tests for the parts of validate_decks.py that are not about a deck's content.

Stdlib `unittest` plus PyYAML, the same two things the validator itself needs,
so a deck contributor can run these without a Flutter toolchain.

Every test here builds a throwaway repository in a temporary directory and
runs the validator as a subprocess against it. That is deliberate: the bug
these were first written for was one of resolution — a check read
`pubspec.yaml` from the working directory, so it passed silently when run from
anywhere else — and a test that imports the function and calls it in-process
cannot see that. The check now is that decks/index.json is current (#210).
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
INDEXER = REPO / "tools" / "deck_index.py"
SAMPLE_DECK = REPO / "decks" / "es" / "es-en-core-100.yaml"


class IndexCheck(unittest.TestCase):
    """decks/index.json must be current, from any directory (#210)."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

        (self.tmp / "tools").mkdir()
        shutil.copy(VALIDATOR, self.tmp / "tools" / "validate_decks.py")
        shutil.copy(INDEXER, self.tmp / "tools" / "deck_index.py")

        (self.tmp / "decks" / "es").mkdir(parents=True)
        shutil.copy(SAMPLE_DECK, self.tmp / "decks" / "es")
        self.write_path("es", ["es-core-100"])
        # The sample deck's pictures, which the validator looks for beside
        # the tools directory it runs from.
        shutil.copytree(VALIDATOR.parent.parent / "assets" / "pictures",
                        self.tmp / "assets" / "pictures")
        self.write_index()

    def write_path(self, lang: str, decks: list[str]) -> None:
        """The path every language with a deck needs (ADR-0013, ADR-0036),
        listing core ids."""
        (self.tmp / "decks" / lang / f"{lang}-path.yaml").write_text(
            f"schema: 1\nkind: path\nid: {lang}-path\nlanguage: {lang}\n"
            f"units:\n  - [{', '.join(decks)}]\n",
            encoding="utf-8",
        )

    def write_index(self) -> None:
        result = subprocess.run(
            [sys.executable, str(self.tmp / "tools" / "deck_index.py")],
            cwd=self.tmp, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def add_language(self) -> None:
        """A second language, after the index was written."""
        hi = self.tmp / "decks" / "hi"
        hi.mkdir()
        deck = SAMPLE_DECK.read_text(encoding="utf-8")
        deck = deck.replace("id: es-en-core-100", "id: hi-en-probe")
        deck = deck.replace("code: es", "code: hi")
        deck = deck.replace("name: Spanish", "name: Hindi")
        deck = deck.replace("tts: es-ES", "tts: hi-IN")
        deck = deck.replace("id: es-0", "id: hi-0")
        (hi / "hi-en-probe.yaml").write_text(deck, encoding="utf-8")
        self.write_path("hi", ["hi-probe"])

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

    def test_passes_when_the_index_is_current(self) -> None:
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_fails_when_the_index_is_missing(self) -> None:
        (self.tmp / "decks" / "index.json").unlink()
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("decks/index.json is missing", result.stdout)

    def test_fails_when_a_language_is_added_after_it(self) -> None:
        self.add_language()
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("decks/index.json is out of date", result.stdout)
        self.write_index()
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_fails_when_a_deck_changes_after_it(self) -> None:
        deck = self.tmp / "decks" / "es" / "es-en-core-100.yaml"
        deck.write_text(deck.read_text(encoding="utf-8") + "\n", encoding="utf-8")
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("out of date", result.stdout)

    def test_a_hidden_language_is_still_validated(self) -> None:
        """decks/ja/ is hidden: left out of the index, but still checked."""
        shutil.copytree(REPO / "decks" / "ja", self.tmp / "decks" / "ja")
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

        deck = self.tmp / "decks" / "ja" / "ja-en-hiragana.yaml"
        deck.write_text(
            deck.read_text(encoding="utf-8").replace("schema: 1", "schema: 9"),
            encoding="utf-8",
        )
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("ja-en-hiragana.yaml", result.stdout)
        self.assertNotIn("index.json", result.stdout)

    def test_fails_from_a_different_working_directory(self) -> None:
        """The check reads decks/ beside the tools, not the working
        directory's: run from the parent, it still finds the stale index."""
        self.add_language()
        result = self.run_validator(f"{self.tmp.name}/decks/", self.tmp.parent)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("out of date", result.stdout)

    def test_absolute_paths_do_not_produce_false_failures(self) -> None:
        result = self.run_validator(str(self.tmp / "decks"), self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_absolute_path_still_catches_a_real_miss(self) -> None:
        self.add_language()
        result = self.run_validator(str(self.tmp / "decks"), self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("out of date", result.stdout)

    def test_one_deck_alone_skips_the_index(self) -> None:
        """Validating one file cannot say the index is current; the run over
        decks/ does."""
        self.add_language()
        result = self.run_validator("decks/hi/hi-en-probe.yaml", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_a_deck_outside_the_repo_skips_the_index(self) -> None:
        """Validating a deck you are drafting elsewhere is legitimate."""
        elsewhere = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, elsewhere, True)
        shutil.copy(SAMPLE_DECK, elsewhere)

        result = self.run_validator(str(elsewhere), self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_a_language_with_a_deck_needs_a_path(self) -> None:
        (self.tmp / "decks" / "es" / "es-path.yaml").unlink()
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("es has no path; add es-path.yaml in decks/es/", result.stdout)

    def test_one_deck_validates_alone_when_its_path_is_on_disk(self) -> None:
        result = self.run_validator("decks/es/es-en-core-100.yaml", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
