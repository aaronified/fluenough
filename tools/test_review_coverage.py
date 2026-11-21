#!/usr/bin/env python3
"""The owner coverage report (tools/review_coverage.py, ADR-0058 W5): shares
of facets per course, and nothing that names or counts a reviewer.

Stdlib `unittest` plus PyYAML. Works on a made-up course in a temporary
directory, never on decks/.
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import review_coverage as rc  # noqa: E402

A, B = "FL-AAAA-AAAA-A", "FL-BBBB-BBBB-B"

# Twelve facets: each of four cards owns a word, a meaning (no reading, IPA,
# example or note) and its place in a unit, as a single deck's card does.
DECK = f"""schema: 1
id: "zz-en-extra"
cards:
  - id: "zz-1"
    target: "one"
    native: "1"
    checked_by: ["{A}", "{B}"]
  - id: "zz-2"
    target: "two"
    native: "2"
    checked_by: ["{A}"]
  - id: "zz-3"
    target: "three"
    native: "3"
    facet_checks: {{"word": {{"by": ["{A}"], "flags": [{{"by": "{B}", "tags": ["spelling_wrong"], "fix": "tres"}}]}}}}
  - id: "zz-4"
    target: "four"
    native: "4"
    facet_checks: {{"word": {{"by": [], "flags": [{{"by": "{A}", "tags": ["spelling_wrong"], "fix": "x"}}, {{"by": "{B}", "tags": ["spelling_wrong"], "fix": "x"}}]}}}}
"""


class Coverage(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        (self.root / "decks" / "zz").mkdir(parents=True)
        (self.root / "decks" / "zz" / "zz-en-extra.yaml").write_text(DECK, encoding="utf-8")

    def test_counts_by_status(self) -> None:
        got = rc.statuses_of(self.root, "zz")
        # zz-1: all three facets settled by two codes. zz-2: one code, so
        # checking. zz-3: the word is contested (a check against a flag), the
        # other two unchecked. zz-4: the word has an agreed fix, the other two
        # unchecked.
        self.assertEqual(got["settled"], 3)
        self.assertEqual(got["checking"], 3)
        self.assertEqual(got["unchecked"], 4)
        self.assertEqual(got["contested"], 1)
        self.assertEqual(got["agreed_fix"], 1)
        self.assertEqual(sum(got.values()), 12)

    def test_the_table_is_shares_of_facets(self) -> None:
        text = rc.report(self.root)
        self.assertIn("| Course | Facets | Settled | Agreed fix | Being checked | Flagged | Contested |", text)
        self.assertIn("| zz | 12 | 25.0% | 8.3% | 58.3% | 0.0% | 8.3% |", text)
        self.assertIn("| All courses | 12 |", text)

    def test_nobody_is_named_or_counted(self) -> None:
        text = rc.report(self.root)
        for needle in (A, B, "FL-"):
            self.assertNotIn(needle, text)
        # The note may use the word, never with a number.
        self.assertNotRegex(text, r"\d+\s+reviewers?")

    def test_main_writes_the_table_and_rejects_a_missing_decks_folder(self) -> None:
        out = self.root / "out.md"
        self.assertEqual(rc.main([str(self.root), "--out", str(out)]), 0)
        self.assertIn("## Review coverage", out.read_text(encoding="utf-8"))
        empty = self.root / "none"
        empty.mkdir()
        self.assertEqual(rc.main([str(empty)]), 2)


if __name__ == "__main__":
    unittest.main()
