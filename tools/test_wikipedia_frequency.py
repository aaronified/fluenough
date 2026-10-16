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


class Counting(unittest.TestCase):

    def test_words(self) -> None:
        self.assertEqual(list(wf.words("घर, बड़ा-घर! 2026 Café क्‍ष")),
                         ["घर", "बड़ा", "घर", "café", "क्‍ष"])

    def test_only_articles_without_markup(self) -> None:
        counts = wf.count(wf.texts(DUMP))
        # मकान is only in a template, a link's target, a reference, a
        # category, a file, a table, a URL, a redirect and a talk page.
        self.assertNotIn("मकान", counts)
        self.assertEqual(counts["घर"], 7)
        self.assertEqual(counts["पानी"], 1)

    def test_ranks_ties_in_text_order(self) -> None:
        ranks = wf.ranks(wf.count(wf.texts(DUMP)))
        self.assertEqual([ranks[w] for w in ("घर", "बड़ा", "है", "कल")], [1, 2, 3, 4])

    def test_a_compressed_dump(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "zzwiki-20261001-pages-articles.xml.bz2"
            path.write_bytes(bz2.compress(DUMP.read_bytes()))
            self.assertEqual(wf.count(wf.texts(path)), wf.count(wf.texts(DUMP)))

    def test_a_folder_of_extracted_text(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / "AA"
            folder.mkdir()
            (folder / "wiki_00").write_text(
                '<doc id="1" title="घर">\nघर बड़ा है।\n</doc>\n', encoding="utf-8")
            self.assertEqual(wf.count(wf.texts(Path(tmp))),
                             {"घर": 1, "बड़ा": 1, "है": 1})

    def test_the_month_from_the_dump_name(self) -> None:
        self.assertEqual(wf.month_of(DUMP), "2026-10")
        self.assertIsNone(wf.month_of(Path("text.txt")))


class Writing(Case):

    def test_without_write_nothing_changes(self) -> None:
        before = (self.decks / CORE).read_text(encoding="utf-8")
        code, out, _ = self.run_tool(str(DUMP))
        self.assertEqual(code, 0)
        self.assertEqual((self.decks / CORE).read_text(encoding="utf-8"), before)
        self.assertIn("- Cards given a rank: 4", out)

    def test_ranks_written_with_their_source(self) -> None:
        code, out, _ = self.run_tool(str(DUMP), "--write")
        self.assertEqual(code, 0)
        self.assertEqual(self.card("zz-9001")["frequency"], {"rank": 1, "source": SOURCE})
        self.assertEqual(self.card("zz-9004")["frequency"], {"rank": 2, "source": SOURCE})
        self.assertEqual(self.card("zz-9005")["frequency"], {"rank": 3, "source": SOURCE})
        self.assertEqual(self.card("zz-9003")["frequency"], {"rank": 4, "source": SOURCE})
        self.assertEqual(vd.validate(self.decks / CORE).errors, [])
        self.assertIn(f"- Source: {SOURCE}", out)

    def test_an_unused_word_and_a_flow_card_are_listed(self) -> None:
        _, out, _ = self.run_tool(str(DUMP), "--write")
        self.assertNotIn("frequency", self.card("zz-9002"))
        self.assertIn("- zz-9002 मकान", out)
        self.assertIn("- Written in flow style, left alone: zz-9006", out)

    def test_a_frequency_is_kept(self) -> None:
        self.run_tool(str(DUMP), "--write")
        code, out, _ = self.run_tool(str(DUMP), "--write", "--month", "2027-01")
        self.assertEqual(code, 0)
        self.assertEqual(self.card("zz-9001")["frequency"], {"rank": 1, "source": SOURCE})
        self.assertIn("- Cards that keep their own: 4", out)

    def test_counts_saved_and_ranked_again(self) -> None:
        counts = self.tmp / "zz-counts.tsv"
        self.run_tool(str(DUMP), "--counts", str(counts))
        self.assertEqual(counts.read_text(encoding="utf-8").splitlines()[:2],
                         ["घर\t7", "बड़ा\t4"])
        code, _, _ = self.run_tool("--from-counts", str(counts), "--month", "2026-10",
                                   "--write")
        self.assertEqual(code, 0)
        self.assertEqual(self.card("zz-9001")["frequency"], {"rank": 1, "source": SOURCE})


class Arguments(Case):

    def test_the_month_is_needed(self) -> None:
        text = self.tmp / "text.txt"
        text.write_text("घर", encoding="utf-8")
        code, _, err = self.run_tool(str(text))
        self.assertEqual(code, 2)
        self.assertIn("give the dump's month with --month YYYY-MM", err)

    def test_a_bad_month(self) -> None:
        code, _, err = self.run_tool(str(DUMP), "--month", "2026-13")
        self.assertEqual(code, 2)
        self.assertIn("--month must be YYYY-MM", err)

    def test_text_or_counts(self) -> None:
        code, _, err = self.run_tool()
        self.assertEqual(code, 2)
        self.assertIn("give the text to count, or --from-counts", err)

    def test_a_bad_counts_file(self) -> None:
        counts = self.tmp / "bad.tsv"
        counts.write_text("घर seven\n", encoding="utf-8")
        code, _, err = self.run_tool("--from-counts", str(counts), "--month", "2026-10")
        self.assertEqual(code, 2)
        self.assertIn("expected a word, a tab and a number", err)


if __name__ == "__main__":
    unittest.main()
