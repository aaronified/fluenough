"""Tests for tools/check_citations.py and the bundled assets/citations.yaml."""

import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_citations as c

GOOD = """
schema: 1
kind: "citations"
groups:
  - id: "standards"
    kind: "standard"
    title: "Standards"
    entries:
      - id: "cefr"
        title: "CEFR"
        issuer: "Council of Europe"
        year: "2001"
        line: "Levels."
        checked: false
  - id: "spacing"
    kind: "research"
    title: "Spacing"
    line: "Reviews are spread out."
    appliesWhen: "offensivenessScale"
    entries:
      - id: "cepeda-2006"
        title: "Distributed practice"
        authors: "Cepeda, N."
        year: "2006"
        url: "https://doi.org/10.1/x"
        confidence: "High"
        checked: true
"""


def swap(old: str, new: str) -> str:
    assert old in GOOD
    return GOOD.replace(old, new)


def test_a_sound_file_has_no_problems():
    assert c.check(GOOD) == []


def test_a_duplicate_entry_id_is_named():
    text = swap('id: "cepeda-2006"', 'id: "cefr"')
    assert any("cefr is listed twice" in p for p in c.check(text))


def test_a_duplicate_group_id_is_named():
    text = swap('id: "spacing"', 'id: "standards"')
    assert any("standards is listed twice" in p for p in c.check(text))


def test_an_http_url_is_refused():
    text = swap("https://doi.org/10.1/x", "http://doi.org/10.1/x")
    assert any("https link" in p for p in c.check(text))


def test_an_empty_title_is_refused():
    problems = c.check(swap('title: "CEFR"', 'title: "  "'))
    assert any("title must be non-empty" in p for p in problems)


def test_a_bare_year_is_refused_as_unquoted():
    problems = c.check(swap('year: "2006"', "year: 2006"))
    assert any("year must be non-empty quoted text" in p for p in problems)


def test_checked_must_be_a_boolean():
    problems = c.check(swap("checked: true", 'checked: "yes"'))
    assert any("checked must be true or false" in p for p in problems)


def test_research_needs_authors_and_a_group_line():
    assert any("authors is missing" in p for p in c.check(
        swap('        authors: "Cepeda, N."\n', "")))
    assert any("needs a line" in p for p in c.check(
        swap('    line: "Reviews are spread out."\n', "")))


def test_a_standard_needs_an_issuer():
    problems = c.check(swap('        issuer: "Council of Europe"\n', ""))
    assert any("issuer is missing" in p for p in problems)


def test_an_unknown_key_is_named():
    problems = c.check(swap('title: "CEFR"', 'title: "CEFR"\n        doi: "x"'))
    assert any('unknown key "doi"' in p for p in problems)


def test_a_group_with_no_entries_is_refused():
    text = GOOD.split('  - id: "spacing"')[0] + (
        '  - id: "spacing"\n    kind: "research"\n    title: "S"\n'
        '    line: "L"\n    entries: []\n')
    assert any("entries must be a non-empty list" in p for p in c.check(text))


def test_a_bad_confidence_is_refused():
    problems = c.check(swap('"High"', '"Certain"'))
    assert any("confidence must be" in p for p in problems)


def test_problems_do_not_start_with_info(tmp_path, capsys):
    path = tmp_path / "c.yaml"
    path.write_text(swap("https://", "http://"), encoding="utf-8")
    assert c.main(["s", str(path)]) == 1
    assert not any(line.startswith("info")
                   for line in capsys.readouterr().out.splitlines())


def test_main_reports_a_missing_file(tmp_path):
    assert c.main(["s", str(tmp_path / "none.yaml")]) == 2


# The real, bundled file.

def real() -> dict:
    return yaml.safe_load(c.DEFAULT.read_text(encoding="utf-8"))


def test_the_bundled_file_is_sound():
    assert c.check(c.DEFAULT.read_text(encoding="utf-8")) == []


def test_the_six_standards_are_present():
    standards = [g for g in real()["groups"] if g["kind"] == "standard"]
    ids = {e["id"] for g in standards for e in g["entries"]}
    assert c.REQUIRED_STANDARDS <= ids


def test_no_id_is_used_twice_and_every_url_is_https():
    entries = [e for g in real()["groups"] for e in g["entries"]]
    ids = [e["id"] for e in entries]
    assert len(ids) == len(set(ids))
    assert all(e["url"].startswith("https://") for e in entries if "url" in e)


def test_research_groups_are_the_plans_and_omit_what_the_owner_removed():
    groups = {g["id"] for g in real()["groups"]}
    assert not groups & {"your-strengths", "offensiveness"}
    assert {"spacing", "testing", "skills", "listening-for-meaning"} <= groups
