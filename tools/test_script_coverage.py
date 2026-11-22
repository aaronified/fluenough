"""Tests for tools/script_coverage.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import script_coverage as sc

SCRIPTS = ["devanagari", "perso_arabic"]
LANG = {"code": "hi", "scripts": SCRIPTS}


class FakeReport:
    def __init__(self, found):
        self.script_cards = found


def test_counts_cards_per_non_primary_script():
    cards = [{"target": "a", "target_scripts": {"perso_arabic": "x"}},
             {"target": "b"}, {"native": "no target"}]
    assert sc.count_cards(LANG, cards) == ("hi", SCRIPTS, 2, {"perso_arabic": 1})


def test_blank_spelling_does_not_count():
    cards = [{"target": "a", "target_scripts": {"perso_arabic": " "}}]
    assert sc.count_cards(LANG, cards) == ("hi", SCRIPTS, 1, {"perso_arabic": 0})


def test_single_script_language_is_not_counted():
    assert sc.count_cards({"code": "es", "script": "latin"}, [{"target": "a"}]) is None


def test_report_adds_decks_of_a_language():
    lines = sc.report_lines([FakeReport(("hi", SCRIPTS, 3, {"perso_arabic": 1})),
                             FakeReport(("hi", SCRIPTS, 1, {"perso_arabic": 0})),
                             FakeReport(None)])
    assert any("hi: 1/4 cards" in x and "3 lack it" in x for x in lines)
    assert all(not x.strip().startswith(("error", "FAIL")) for x in lines)
    # Not read as a deck's warnings or infos (test_validate_b1, decks-live).
    assert all(not x.startswith(("info ", "  info", "warn", "  warning"))
               for x in lines)
    assert any(x.startswith("  coverage hi:") for x in lines)


def test_no_report_without_a_multi_script_language():
    assert sc.report_lines([FakeReport(None)]) == []
