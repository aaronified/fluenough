"""Tests for build_sample_pack.py: the downloadable sample deck pack (#92)."""

import tempfile
import unittest
import zipfile
from pathlib import Path

import build_sample_pack


class SamplePackTest(unittest.TestCase):
    def test_the_pack_holds_every_kind_and_the_course_and_is_repeatable(
            self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp) / "a.zip", Path(tmp) / "b.zip"
            self.assertGreater(build_sample_pack.build(a), 50)
            build_sample_pack.build(b)
            self.assertEqual(a.read_bytes(), b.read_bytes())
            with zipfile.ZipFile(a) as z:
                names = z.namelist()
        top = build_sample_pack.TOP
        self.assertIn(f"{top}/README.txt", names)
        self.assertIn(f"{top}/kinds/zz/zz-path.yaml", names)
        self.assertIn(f"{top}/kinds/zz/zz-proverbs-ejemplo.yaml", names)
        self.assertIn(f"{top}/course/es/es-path.yaml", names)
        self.assertIn(f"{top}/course/te/te-path.yaml", names)

    def test_a_missing_fixture_is_an_error_not_an_empty_pack(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(FileNotFoundError):
                build_sample_pack.build(Path(tmp) / "x.zip", root=Path(tmp))


if __name__ == "__main__":
    unittest.main()
