"""Tests for prepare_release.py, on temporary copies of the three files."""

import tempfile
import unittest
from pathlib import Path

import prepare_release

PUBSPEC = "name: fluenough\nversion: 0.5.1+14\nflutter:\n  uses-material-design: true\n"
APP_INFO = "abstract final class AppInfo {\n  static const String version = '0.5.1';\n}\n"
CHANGELOG = """# Changelog

## [Unreleased]

### Added

- A new thing (#1).

## [0.5.1] - 2026-10-19

### Fixed

- An old thing.
"""


class PrepareReleaseTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        (self.root / "lib" / "app").mkdir(parents=True)
        self.write("pubspec.yaml", PUBSPEC)
        self.write("lib/app/app_info.dart", APP_INFO)
        self.write("CHANGELOG.md", CHANGELOG)

    def write(self, name, text):
        (self.root / name).write_text(text, encoding="utf-8")

    def read(self, name):
        return (self.root / name).read_text(encoding="utf-8")

    def test_bumps_version_files(self):
        prepare_release.prepare(self.root, "0.5.2", "2026-10-20")
        self.assertIn("version: 0.5.2+15\n", self.read("pubspec.yaml"))
        self.assertIn("version = '0.5.2';", self.read("lib/app/app_info.dart"))

    def test_moves_changelog_body(self):
        prepare_release.prepare(self.root, "0.5.2", "2026-10-20")
        text = self.read("CHANGELOG.md")
        self.assertIn(
            "## [Unreleased]\n\n## [0.5.2] - 2026-10-20\n\n### Added\n\n"
            "- A new thing (#1).\n\n## [0.5.1] - 2026-10-19\n",
            text,
        )
        self.assertEqual(text.count("A new thing"), 1)

    def test_empty_unreleased_fails_and_writes_nothing(self):
        self.write(
            "CHANGELOG.md",
            CHANGELOG.replace("### Added\n\n- A new thing (#1).\n\n", ""),
        )
        with self.assertRaisesRegex(prepare_release.ReleaseError, "empty"):
            prepare_release.prepare(self.root, "0.5.2", "2026-10-20")
        self.assertEqual(self.read("pubspec.yaml"), PUBSPEC)
        self.assertEqual(self.read("lib/app/app_info.dart"), APP_INFO)

    def test_not_higher_fails(self):
        for version in ("0.5.1", "0.5.0", "0.4.9"):
            with self.assertRaisesRegex(prepare_release.ReleaseError, "not higher"):
                prepare_release.prepare(self.root, version, "2026-10-20")
        self.assertEqual(self.read("pubspec.yaml"), PUBSPEC)

    def test_bad_version_fails(self):
        with self.assertRaises(prepare_release.ReleaseError):
            prepare_release.prepare(self.root, "v0.5.2", "2026-10-20")

    def test_unreleased_as_last_section(self):
        self.write("CHANGELOG.md", "# Changelog\n\n## [Unreleased]\n\n- Only.\n")
        prepare_release.prepare(self.root, "0.6.0", "2026-10-20")
        self.assertEqual(
            self.read("CHANGELOG.md"),
            "# Changelog\n\n## [Unreleased]\n\n## [0.6.0] - 2026-10-20\n\n- Only.\n",
        )


if __name__ == "__main__":
    unittest.main()
