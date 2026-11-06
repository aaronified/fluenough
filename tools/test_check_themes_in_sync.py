"""Tests for tools/check_themes_in_sync.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_themes_in_sync as c


def test_identical_and_crlf(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    a.write_bytes(b"x: 1\ny: 2\n")
    b.write_bytes(b"x: 1\r\ny: 2\r\n")
    assert c.main(["s", str(a), str(b)]) == 0


def test_differs(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    a.write_text("x: 1\n")
    b.write_text("x: 2\n")
    assert c.main(["s", str(a), str(b)]) == 1


def test_bad_args(tmp_path):
    assert c.main(["s"]) == 2
    assert c.main(["s", str(tmp_path / "no"), str(tmp_path / "no2")]) == 2
