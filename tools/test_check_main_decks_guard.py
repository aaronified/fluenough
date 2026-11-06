"""Tests for tools/check_main_decks_guard.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_main_decks_guard as g


def test_deck_file_is_forbidden():
    assert g.forbidden(["decks/es/core.yaml", "lib/main.dart"]) == ["decks/es/core.yaml"]


def test_index_is_forbidden():
    assert g.forbidden(["decks/index.json"]) == ["decks/index.json"]


def test_app_files_are_allowed():
    assert g.forbidden(["decks/themes.yaml", "decks/min_app.json"]) == []


def test_non_deck_paths_are_allowed():
    assert g.forbidden([".github/workflows/ci.yml", "tools/x.py", "test/fixtures/sample-decks/decks/a.yaml"]) == []


def test_lookalike_prefix_is_not_decks():
    assert g.forbidden(["decks-notes.md", "decksx/a"]) == []


def test_main_exit_codes(tmp_path):
    f = tmp_path / "files.txt"
    f.write_text("tools/a.py\ndecks/themes.yaml\n")
    assert g.main(["x", str(f)]) == 0
    f.write_text("decks/bn/core.yaml\n")
    assert g.main(["x", str(f)]) == 1
    assert g.main(["x", "a", "b"]) == 2


def test_non_ascii_and_quoted_deck_paths_are_forbidden():
    assert g.forbidden(["decks/\u00e9s/core.yaml"]) == ["decks/\u00e9s/core.yaml"]
    assert g.forbidden(['"decks/\\303\\251.yaml"']) == ['decks/\\303\\251.yaml"']
