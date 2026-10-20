#!/usr/bin/env python3
"""Tests for tools/wikipedia_frequency.py (#516), on a pages-articles dump
of four pages (tools/fixtures/wikipedia) and the Wiktionary import's small
decks (tools/fixtures/wiktionary/decks): no real dump is downloaded.

Stdlib `unittest` plus PyYAML, like the tool.
"""

from __future__ import annotations

import bz2
import contextlib
import io
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks as vd  # noqa: E402
import wikipedia_frequency as wf  # noqa: E402

HERE = Path(__file__).resolve().parent
DUMP = HERE / "fixtures" / "wikipedia" / "zzwiki-20261001-pages-articles.xml"
DECKS = HERE / "fixtures" / "wiktionary" / "decks"
CORE = "zz/zz-home.yaml"
SOURCE = "zz.wikipedia.org, 2026-10"


class Case(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.decks = self.tmp / "decks"
        shutil.copytree(DECKS, self.decks)

    def run_tool(self, *args: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = wf.main(["wikipedia_frequency.py", "zz", *args,
                            "--decks", str(self.decks)])
        return code, out.getvalue(), err.getvalue()

    def card(self, cid: str) -> dict:
        return next(c for c in vd._load_raw(self.decks / CORE)["cards"] if c["id"] == cid)


class Writing(Case):

    def _without_write_nothing_changes(self) -> None:
        before = (self.decks / CORE).read_text(encoding="utf-8")
        code, out, _ = self.run_tool(str(DUMP))
        self.assertEqual(code, 0)
        self.assertEqual((self.decks / CORE).read_text(encoding="utf-8"), before)
        self.assertIn("- Cards given a rank: 4", out)

    def _ranks_written_with_their_source(self) -> None:
        code, out, _ = self.run_tool(str(DUMP), "--write")
        self.assertEqual(code, 0)
        self.assertEqual(self.card("zz-9001")["frequency"], {"rank": 1, "source": SOURCE})
        self.assertEqual(self.card("zz-9004")["frequency"], {"rank": 2, "source": SOURCE})
        self.assertEqual(self.card("zz-9005")["frequency"], {"rank": 3, "source": SOURCE})
        self.assertEqual(self.card("zz-9003")["frequency"], {"rank": 4, "source": SOURCE})
        self.assertEqual(vd.validate(self.decks / CORE).errors, [])
        self.assertIn(f"- Source: {SOURCE}", out)


    def test_ranks_are_written_with_their_source_and_only_with_write(self) -> None:
        cases = (
            self._ranks_written_with_their_source,
            self._without_write_nothing_changes,
        )
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()


if __name__ == "__main__":
    unittest.main()
