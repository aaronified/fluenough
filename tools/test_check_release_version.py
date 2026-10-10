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
    def test_drops_the_build_number(self):
        self.assertEqual(crv.pubspec_version(PUBSPEC), "0.3.4")

    def test_without_a_build_number(self):
        self.assertEqual(crv.pubspec_version("version: 1.2.3\n"), "1.2.3")

    def test_quoted_and_commented(self):
        self.assertEqual(crv.pubspec_version('version: "1.2.3+4"  # bump\n'), "1.2.3")
        self.assertEqual(crv.pubspec_version("version: '1.2.3'\n"), "1.2.3")

    def test_crlf(self):
        self.assertEqual(crv.pubspec_version("name: x\r\nversion: 1.2.3+4\r\n"), "1.2.3")

    def test_ignores_indented_version(self):
        # Only the top-level key counts; the one inside `description` does not.
        self.assertIsNone(crv.pubspec_version("name: x\n  version: 9.9.9\n"))

    def test_missing(self):
        self.assertIsNone(crv.pubspec_version("name: x\n"))


class CheckTest(unittest.TestCase):
    def test_match(self):
        self.assertIsNone(crv.check("v0.3.4", PUBSPEC))

    def test_mismatch_says_what_to_bump(self):
        error = crv.check("v0.4.0", PUBSPEC)
        self.assertIsNotNone(error)
        self.assertIn("v0.4.0", error)
        self.assertIn("0.3.4", error)
        self.assertIn("pubspec.yaml", error)
        self.assertIn("AppInfo.version", error)

    def test_build_number_in_tag_is_not_a_version_tag(self):
        self.assertIn("not a version tag", crv.check("v0.3.4+7", PUBSPEC))

    def test_prefix_is_not_a_match(self):
        self.assertIsNotNone(crv.check("v0.3.4", "version: 0.3.40+1\n"))
        self.assertIsNotNone(crv.check("v0.3.40", PUBSPEC))

    def test_no_version_line(self):
        self.assertIn("no top-level", crv.check("v0.3.4", "name: x\n"))

    def test_repository_pubspec_is_readable(self):
        self.assertIsNotNone(crv.pubspec_version(REPO_PUBSPEC.read_text(encoding="utf-8")))


class CommandLineTest(unittest.TestCase):
    def run_script(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            capture_output=True,
            text=True,
        )

    def test_exit_codes(self):
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


if __name__ == "__main__":
    unittest.main()
