"""Tests for tools/check_themes_in_sync.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_themes_in_sync as c


def themes(*ids: str) -> str:
    body = "".join(f'  - {{ id: {i}, name: "{i}" }}\n' for i in ids)
    return f"schema: 1\nkind: themes\nthemes:\n{body}"


def run(tmp_path, main_ids, live_ids):
    a, b = tmp_path / "a", tmp_path / "b"
    a.write_text(themes(*main_ids))
    b.write_text(themes(*live_ids))
    return c.main(["s", str(a), str(b)])


def test_identical(tmp_path):
    assert run(tmp_path, ["first-words", "family"], ["first-words", "family"]) == 0


def test_decks_live_may_be_ahead(tmp_path):
    assert run(tmp_path, ["first-words"], ["first-words", "at-the-bank"]) == 0


def test_a_theme_dropped_from_decks_live_fails(tmp_path, capsys):
    assert run(tmp_path, ["first-words", "family"], ["first-words"]) == 1
    assert "family" in capsys.readouterr().out


def test_a_file_that_is_not_a_themes_file_is_a_bad_argument(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    a.write_text(themes("x"))
    b.write_text("x: 1\n")
    assert c.main(["s", str(a), str(b)]) == 2


def test_bad_args(tmp_path):
    assert c.main(["s"]) == 2
    assert c.main(["s", str(tmp_path / "no"), str(tmp_path / "no2")]) == 2
