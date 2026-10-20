#!/usr/bin/env python3
"""Tests for the release tag / pubspec.yaml version check (#141)."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_release_version as crv  # noqa: E402

SCRIPT = Path(__file__).resolve().parent / "check_release_version.py"
REPO_PUBSPEC = Path(__file__).resolve().parent.parent / "pubspec.yaml"

PUBSPEC = """\
name: fluenough
description: >-
  Something.
  version: 9.9.9
publish_to: none
version: 0.3.4+7

dependencies:
  flutter:
    sdk: flutter
"""


class PubspecVersionTest(unittest.TestCase):
    def _drops_the_build_number(self):
        self.assertEqual(crv.pubspec_version(PUBSPEC), "0.3.4")

    def _without_a_build_number(self):
        self.assertEqual(crv.pubspec_version("version: 1.2.3\n"), "1.2.3")

    def _quoted_and_commented(self):
        self.assertEqual(crv.pubspec_version('version: "1.2.3+4"  # bump\n'), "1.2.3")
        self.assertEqual(crv.pubspec_version("version: '1.2.3'\n"), "1.2.3")

    def _crlf(self):
        self.assertEqual(crv.pubspec_version("name: x\r\nversion: 1.2.3+4\r\n"), "1.2.3")

    def _ignores_indented_version(self):
        # Only the top-level key counts; the one inside `description` does not.
        self.assertIsNone(crv.pubspec_version("name: x\n  version: 9.9.9\n"))

    def _missing(self):
        self.assertIsNone(crv.pubspec_version("name: x\n"))

    def test_reads_the_pubspec_version_without_its_build_number(self) -> None:
        cases = (
            self._drops_the_build_number,
            self._without_a_build_number,
            self._quoted_and_commented,
            self._crlf,
            self._ignores_indented_version,
            self._missing,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


class CheckTest(unittest.TestCase):
    def _match(self):
        self.assertIsNone(crv.check("v0.3.4", PUBSPEC))

    def _mismatch_says_what_to_bump(self):
        error = crv.check("v0.4.0", PUBSPEC)
        self.assertIsNotNone(error)
        self.assertIn("v0.4.0", error)
        self.assertIn("0.3.4", error)
        self.assertIn("pubspec.yaml", error)
        self.assertIn("AppInfo.version", error)

    def _build_number_in_tag_is_not_a_version_tag(self):
        self.assertIn("not a version tag", crv.check("v0.3.4+7", PUBSPEC))

    def _prefix_is_not_a_match(self):
        self.assertIsNotNone(crv.check("v0.3.4", "version: 0.3.40+1\n"))
        self.assertIsNotNone(crv.check("v0.3.40", PUBSPEC))

    def _no_version_line(self):
        self.assertIn("no top-level", crv.check("v0.3.4", "name: x\n"))

    def _repository_pubspec_is_readable(self):
        self.assertIsNotNone(crv.pubspec_version(REPO_PUBSPEC.read_text(encoding="utf-8")))

    def test_a_match_passes_and_a_mismatch_says_what_to_bump(self) -> None:
        cases = (
            self._match,
            self._mismatch_says_what_to_bump,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()

    def test_what_is_not_a_version_tag_fails(self) -> None:
        cases = (
            self._build_number_in_tag_is_not_a_version_tag,
            self._prefix_is_not_a_match,
            self._no_version_line,
            self._repository_pubspec_is_readable,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


class CommandLineTest(unittest.TestCase):
    def run_script(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            capture_output=True,
            text=True,
        )

    def _exit_codes(self):
        with tempfile.TemporaryDirectory() as tmp:
            pubspec = Path(tmp) / "pubspec.yaml"
            pubspec.write_text(PUBSPEC, encoding="utf-8")
            ok = self.run_script("v0.3.4", str(pubspec))
            self.assertEqual(ok.returncode, 0, ok.stdout + ok.stderr)
            bad = self.run_script("v0.3.5", str(pubspec))
            self.assertEqual(bad.returncode, 1)
            self.assertTrue(bad.stdout.startswith("::error::"))
            self.assertEqual(self.run_script().returncode, 2)
            self.assertEqual(
                self.run_script("v0.3.4", str(Path(tmp) / "missing.yaml")).returncode, 2
            )

    def test_exit_codes(self) -> None:
        cases = (
            self._exit_codes,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


if __name__ == "__main__":
    unittest.main()
