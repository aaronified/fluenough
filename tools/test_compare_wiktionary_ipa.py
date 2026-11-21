#!/usr/bin/env python3
"""Tests for tools/compare_wiktionary_ipa.py (#305). A small language, zz, and
a Wiktextract-shaped extract of its words (tools/fixtures/phonetic_compare)
stand in for the real decks and dump: nothing is downloaded, and the decks
are checked to be unchanged.

Stdlib `unittest` plus PyYAML, like the tool.
"""

from __future__ import annotations

import contextlib
import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

import compare_wiktionary_ipa as cw  # noqa: E402
import import_phonetic as ip  # noqa: E402

DUMP = Path(__file__).resolve().parent / "fixtures" / "phonetic_compare" / "Zed.jsonl"

HEAD = '''schema: 1
id: "zz-home"
part: "core"
kind: "vocab"
language: { code: "zz", iso639_3: "zzz", name: "Zed", script: "latin" }
license: "CC-BY-SA-4.0"
theme: "home"
cards:
'''

# (id, target, broad ipa, phonetic, phonetic_source)
CARDS = [
    ("zz-0001", "kat", "kat", "[kʰat]", "rules"),           # agrees at both levels
    ("zz-0002", "dog", "dɔɡ", "[dɔɡ̊]", "wiktionary"),       # agrees, taken from Wiktionary
    ("zz-0003", "bat", "bat", None, None),                  # consonant, one sound
    ("zz-0004", "jam", "jam", None, None),                  # consonant, two sounds
    ("zz-0005", "pen", "pen", None, None),                  # vowel quality
    ("zz-0006", "tin", "tin", None, None),  # length mark
    ("zz-0007", "sun", "sun", None, None),                  # Wiktionary's stress is ignored
    ("zz-0008", "pan", "pan", "[ˈpan]", "rules"),           # narrow: stress
    ("zz-0009", "cup", "kup", None, None),                  # contrastive mark (nasalisation)
    ("zz-0010", "map", "map", None, None),                  # matches one of two variants
    ("zz-0011", "mud", "mud", None, None),                  # matches neither of two
    ("zz-0012", "nobody", "nobodi", None, None),            # not on Wiktionary
    ("zz-0013", "hat", "hat", None, None),                  # no broad form there
    ("zz-0014", "fig", "fig", None, None),                  # vowel and consonant
]


def deck_text() -> str:
    out = [HEAD]
    for cid, target, ipa, phon, src in CARDS:
        out.append(f'  - id: "{cid}"\n    target: "{target}"\n    ipa: "{ipa}"\n')
        if phon:
            out.append(f'    phonetic: "{phon}"\n    phonetic_source: "{src}"\n')
        out.append('    pos: "noun"\n')
    return "".join(out)


def digest(root: Path) -> dict[str, str]:
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob("*")) if p.is_file()}


class Compare(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.decks = self.tmp / "decks"
        (self.decks / "zz").mkdir(parents=True)
        (self.decks / "zz" / "zz-home.yaml").write_text(deck_text(), encoding="utf-8")
        patcher = mock.patch.dict(ip.VARIETIES, {"zz": ip.Variety("Zed")})
        patcher.start()
        self.addCleanup(patcher.stop)

    def result(self, **kw) -> cw.Comparison:
        return cw.compare("zz", DUMP, self.decks, **kw)

    def kinds(self, res: cw.Comparison, level: str) -> dict[str, str | None]:
        return {r.cid: r.kind for r in res.rows if r.level == level}

    def run_main(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cw.main(["compare_wiktionary_ipa.py", *argv])
        return code, out.getvalue(), err.getvalue()

    def test_each_kind_of_difference_is_named_and_agreement_is_not_one(self) -> None:
        broad = self.kinds(self.result(), "broad")
        self.assertEqual(broad, {
            "zz-0001": None, "zz-0002": None,
            "zz-0003": "consonant", "zz-0004": "consonant",
            "zz-0005": "vowel quality", "zz-0006": "length mark",
            "zz-0007": None,  # the card writes no stress, so Wiktionary's is no difference
            "zz-0008": None, "zz-0009": "contrastive mark", "zz-0010": None,
            "zz-0011": "multiple Wiktionary variants",
            "zz-0012": "missing in Wiktionary", "zz-0013": "missing in Wiktionary",
            "zz-0014": "vowel and consonant"})
        self.assertEqual(self.kinds(self.result(), "narrow"),
                         {"zz-0001": None, "zz-0002": None, "zz-0008": "stress"})

    def test_several_wiktionary_forms_agree_if_one_matches_and_otherwise_name_the_nearest(self) -> None:
        rows = {r.cid: r for r in self.result().rows if r.level == "broad"}
        self.assertTrue(rows["zz-0010"].agrees)
        self.assertEqual(rows["zz-0010"].wiktionary, ["map", "mab"])
        self.assertEqual(rows["zz-0011"].closest, "consonant")
        self.assertEqual(rows["zz-0011"].wiktionary, ["mut", "mub"])

    def test_missing_forms_say_why_and_are_not_counted_in_the_rate(self) -> None:
        res = self.result()
        why = {r.cid: r.reason for r in res.rows if r.kind == cw.MISSING}
        self.assertEqual(why, {"zz-0012": "no entry", "zz-0013": "no broad form"})
        broad = res.summary()["levels"]["broad"]
        self.assertEqual(broad["missing"], 2)
        self.assertEqual(broad["compared"], 12)

    def test_summary_gives_agreement_per_level_kind_and_source(self) -> None:
        s = self.result().summary()
        self.assertEqual(s["levels"]["broad"], {
            "compared": 12, "agree": 5, "disagree": 7, "missing": 2,
            "agreement_rate": round(5 / 12, 4)})
        self.assertEqual(s["levels"]["narrow"]["agreement_rate"], round(2 / 3, 4))
        self.assertEqual(s["by_kind"]["consonant"]["count"], 2)
        self.assertEqual(s["by_kind"]["stress"]["count"], 1)
        self.assertEqual(s["narrow_by_source"]["wiktionary"]["agreement_rate"], 1.0)
        self.assertEqual(s["narrow_by_source"]["rules"]["agreement_rate"], 0.5)
        self.assertEqual(s["cards"], 14)
        self.assertEqual(s["cards_without_narrow"], 11)

    def test_likeliest_real_errors_come_first_and_missing_last(self) -> None:
        order = [(r.cid, r.level) for r in self.result().review()]
        self.assertEqual(order, [
            ("zz-0003", "broad"), ("zz-0004", "broad"),   # consonant, smaller first
            ("zz-0005", "broad"),                          # vowel quality
            ("zz-0014", "broad"),                          # vowel and consonant
            ("zz-0009", "broad"),                          # contrastive mark (nasalisation)
            ("zz-0011", "broad"),                          # several forms, none match
            ("zz-0006", "broad"),                          # length mark
            ("zz-0008", "narrow"),                         # stress
            ("zz-0012", "broad"), ("zz-0013", "broad")])   # missing

    def test_limit_and_rules_only_narrow_what_is_compared(self) -> None:
        self.assertEqual({r.cid for r in self.result(limit=2).rows},
                         {"zz-0001", "zz-0002"})
        narrow = [r.cid for r in self.result(rules_only=True).rows if r.level == "narrow"]
        self.assertEqual(narrow, ["zz-0001", "zz-0008"])

    def test_markdown_credits_wiktionary_and_lists_each_row(self) -> None:
        text = cw.markdown([self.result()])
        self.assertIn("CC BY-SA 4.0", text)
        self.assertIn("## zz: summary", text)
        self.assertIn("## zz: review list (10)", text)
        self.assertIn("| level | compared | agree | disagree | missing in Wiktionary | "
                      "agreement |", text)
        self.assertIn("| 1 | zz-0003 | bat | broad | /bat/ | /bad/ | consonant | "
                      "[page](https://en.wiktionary.org/wiki/bat) |", text)
        self.assertIn("multiple Wiktionary variants (nearest: consonant)", text)
        self.assertIn("(no entry)", text)

    def test_json_has_the_same_rows_for_tools(self) -> None:
        data = cw.as_json([self.result()])
        self.assertEqual(data["source"]["licence"], "CC BY-SA 4.0")
        self.assertEqual(data["kinds"], cw.KINDS)
        zz = data["languages"]["zz"]
        self.assertEqual(zz["variety"], "Zed")
        self.assertEqual(len(zz["review"]), 10)
        first = zz["review"][0]
        self.assertEqual(first, {
            "id": "zz-0003", "word": "bat", "deck": "zz-home", "level": "broad",
            "ours": "bat", "wiktionary": ["bad"], "kind": "consonant",
            "closest_kind": None, "distance": 1, "source": None, "reason": "",
            "url": "https://en.wiktionary.org/wiki/bat"})
        json.dumps(data)

    def test_the_command_writes_the_two_files_and_never_touches_the_decks(self) -> None:
        before = digest(self.decks)
        md, js = self.tmp / "r.md", self.tmp / "r.json"
        code, _, err = self.run_main("zz", "--decks", str(self.decks), "--dump", str(DUMP),
                                     "--markdown", str(md), "--json", str(js))
        self.assertEqual(code, 0, err)
        self.assertIn("review list (10)", md.read_text(encoding="utf-8"))
        self.assertEqual(len(json.loads(js.read_text(encoding="utf-8"))
                             ["languages"]["zz"]["review"]), 10)
        self.assertEqual(digest(self.decks), before)

    def test_every_vowel_letter_counts_as_a_vowel(self) -> None:
        self.assertEqual(cw.difference("bʌt", "bst")[0], "vowel and consonant")
        self.assertEqual(cw.difference("bʌt", "bɐt")[0], "vowel quality")
        self.assertEqual(cw.difference("sɿ", "sʅ")[0], "vowel quality")
        self.assertEqual(cw.difference("tʌ", "tʰʌ")[0], "contrastive mark")

    def test_marks_are_contrastive_or_cosmetic(self) -> None:
        for ours, theirs in [("kat", "kʰat"), ("kat", "kãt"), ("tat", "t̪at"),
                             ("ɑ", "ɑ˞"), ("pa", "pa̤")]:
            self.assertEqual(cw.difference(ours, theirs)[0], "contrastive mark", theirs)
        for ours, theirs in [("tʃ", "t͡ʃ"), ("n", "n̩"), ("kat", "kat̚")]:
            self.assertEqual(cw.difference(ours, theirs)[0], "cosmetic mark", theirs)
        self.assertLess(cw.KINDS.index("contrastive mark"), cw.KINDS.index("multiple Wiktionary variants"))
        self.assertGreater(cw.KINDS.index("cosmetic mark"), cw.KINDS.index("stress"))

    def test_tone_letters_are_their_own_kind(self) -> None:
        self.assertEqual(cw.difference("ma˥", "ma˩")[0], "tone")
        self.assertEqual(cw.difference("ma", "ma˥")[0], "tone")
        self.assertIsNone(cw.difference("ma˥˩", "ma˥˩")[0])
        self.assertEqual(cw.difference("ma˥", "na˥")[0], "consonant")
        self.assertLess(cw.KINDS.index("tone"), cw.KINDS.index("multiple Wiktionary variants"))

    def test_the_report_is_never_written_over_a_deck(self) -> None:
        before = digest(self.decks)
        deck = self.decks / "zz" / "zz-home.yaml"
        for flag, target in [("--markdown", deck), ("--json", deck),
                             ("--markdown", self.decks / "zz" / "report.md"),
                             ("--json", self.tmp / "other.yml")]:
            code, _, err = self.run_main("zz", "--decks", str(self.decks), "--dump",
                                         str(DUMP), flag, str(target))
            self.assertEqual(code, 2, target)
            self.assertIn("error", err)
        self.assertEqual(digest(self.decks), before)
        self.assertFalse((self.tmp / "other.yml").exists())

    def test_bad_arguments_are_refused_before_anything_is_fetched(self) -> None:
        with mock.patch.object(ip, "ensure_dump") as fetch:
            self.assertEqual(self.run_main("qq", "--decks", str(self.decks))[0], 2)
            self.assertEqual(self.run_main("zz", "bn", "--dump", str(DUMP))[0], 2)
            self.assertEqual(self.run_main("zz", "--decks", str(self.decks),
                                           "--limit", "0")[0], 2)
        fetch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
