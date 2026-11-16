#!/usr/bin/env python3
"""Tests for tools/fill_ipa.py (the broad ipa written from a card's reading) and
for the one-line flow cards that tools/phonetic_patch.py can now patch, with the
Chinese rules file when it is on disk. A tiny Chinese deck stands in for the real
ones: nothing is downloaded.

Stdlib `unittest` plus PyYAML, like the tools.
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

import derive_phonetic as dp  # noqa: E402
import fill_ipa as fi  # noqa: E402
import phonetic_patch as pp  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

HEAD = '''schema: 1
"id": "zh-test"
"part": "core"
"kind": "vocab"
"language":
  "code": "zh"
  "iso639_3": "cmn"
  "name": "Mandarin Chinese"
  "script": "han_simplified"
"license": "CC-BY-SA-4.0"
"theme": "test"
"cards":
'''

BLOCK = '''- "id": "zh-0001"
  "target": "你好"
  "words":
  - "你好"
  "reading": "nǐ hǎo"
  "pos": "phrase"
  "examples":
  - "target": "你好吗？"
    "reading": "nǐ hǎo ma?"
- "id": "zh-0002"
  "target": "爸爸"
  "reading": "bàba"
  "ipa": "already"
'''

FLOW = '''- {"id": "zh-0003", "target": "公司", "words": ["公司"], "reading": "gōngsī", "pos": "noun", "examples": [{"target": "我们公司很大。", "reading": "wǒmen gōngsī hěn dà.", "ipa": "nested"}]}
- {"id": "zh-0004", "target": "导航", "reading": "dǎováng", "pos": "noun"}
- {"id": "zh-0005", "target": "好"}
'''


class FillIpaTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        (self.tmp / "zh").mkdir()
        self.block = self.tmp / "zh" / "zh-test.yaml"
        self.flow = self.tmp / "zh" / "zh-flow.yaml"
        self.block.write_text(HEAD + BLOCK, encoding="utf-8")
        self.flow.write_text(HEAD.replace("zh-test", "zh-flow") + FLOW,
                             encoding="utf-8")

    def cards(self, path: Path) -> dict[str, dict]:
        return {c["id"]: c for c in yaml.safe_load(path.read_text("utf-8"))["cards"]}

    def test_a_report_run_writes_nothing(self) -> None:
        before = (self.block.read_text("utf-8"), self.flow.read_text("utf-8"))
        cov = fi.run("zh", self.tmp, write=False)
        self.assertEqual(before, (self.block.read_text("utf-8"), self.flow.read_text("utf-8")))
        total = cov.total()
        self.assertEqual(total["filled"], 2)
        self.assertEqual(total["has ipa"], 1)
        self.assertEqual(total["cannot read"], 1)   # dǎováng is not pinyin
        self.assertEqual(total["no reading"], 1)

    def test_the_ipa_goes_after_the_reading_line_and_nothing_else_changes(self) -> None:
        fi.run("zh", self.tmp, write=True)
        text = self.block.read_text("utf-8")
        self.assertEqual(
            text, (HEAD + BLOCK).replace(
                '  "reading": "nǐ hǎo"\n',
                '  "reading": "nǐ hǎo"\n  "ipa": "ni˨˩˦ xau˨˩˦"\n'))
        cards = self.cards(self.block)
        self.assertEqual(cards["zh-0001"]["ipa"], "ni˨˩˦ xau˨˩˦")
        self.assertEqual(cards["zh-0002"]["ipa"], "already")   # never replaced
        self.assertNotIn("ipa", cards["zh-0001"]["examples"][0])

    def test_a_card_on_one_line_gets_its_own_ipa_not_a_nested_one(self) -> None:
        fi.run("zh", self.tmp, write=True)
        line = next(ln for ln in self.flow.read_text("utf-8").split("\n")
                    if '"zh-0003"' in ln)
        self.assertIn('"reading": "gōngsī", "ipa": "kʊŋ˥˥sɨ˥˥", "pos": "noun"', line)
        cards = self.cards(self.flow)
        self.assertEqual(cards["zh-0003"]["ipa"], "kʊŋ˥˥sɨ˥˥")
        self.assertEqual(cards["zh-0003"]["examples"][0]["ipa"], "nested")
        self.assertNotIn("ipa", cards["zh-0004"])     # unreadable pinyin: left alone
        self.assertNotIn("ipa", cards["zh-0005"])     # no reading

    def test_a_second_run_changes_nothing(self) -> None:
        fi.run("zh", self.tmp, write=True)
        once = (self.block.read_text("utf-8"), self.flow.read_text("utf-8"))
        cov = fi.run("zh", self.tmp, write=True)
        self.assertEqual(once, (self.block.read_text("utf-8"), self.flow.read_text("utf-8")))
        self.assertEqual(cov.total().get("filled", 0), 0)

    def test_derive_then_patches_phonetic_after_ipa_in_both_layouts(self) -> None:
        fi.run("zh", self.tmp, write=True)
        (self.tmp / "zh" / "zh-phonetics.yaml").write_text(
            'schema: 1\nkind: "phonetics"\nid: "zh-phonetics"\nlanguage: "zh"\n'
            'variety: "test"\nrules:\n  - id: "zh-apical-dental"\n'
            '    pattern: \'(?:(?<=ts)|(?<=tsʰ)|(?<=s))ɨ\'\n'
            '    replace: "ɹ\\u0329"\n    source: "a test, 2026"\n',
            encoding="utf-8")
        cov, fills = dp.run("zh", self.tmp, write=True, bracket_unchanged=True)
        self.assertEqual(cov.total().get(pp.UNWRITABLE, 0), 0)
        flow = self.cards(self.flow)["zh-0003"]
        self.assertEqual((flow["phonetic"], flow["phonetic_source"]),
                         ("[kʊŋ˥˥sɹ̩˥˥]", "rules"))
        self.assertEqual(flow["examples"][0]["ipa"], "nested")
        block = self.cards(self.block)["zh-0001"]
        self.assertEqual(block["phonetic"], "[ni˨˩˦ xau˨˩˦]")
        # rederive replaces a rules card on one line and leaves the rest of it as it was
        before = self.flow.read_text("utf-8")
        dp.run("zh", self.tmp, write=True, bracket_unchanged=True, rederive=True)
        self.assertEqual(before, self.flow.read_text("utf-8"))


class ChineseRulesTest(unittest.TestCase):
    """The real rules file lives on decks-live, so this runs only where it is
    on disk (CI lays main's tools over decks-live)."""

    path = ROOT / "decks" / "zh" / "zh-phonetics.yaml"

    def setUp(self) -> None:
        if not self.path.is_file():
            self.skipTest("decks/zh/zh-phonetics.yaml is not in this checkout")
        self.rules = dp.load_rules(self.path).rules

    def narrow(self, broad: str) -> str:
        form, _ = dp.derive(broad, self.rules)
        return form

    def test_third_tone_sandhi_and_the_half_third(self) -> None:
        self.assertEqual(self.narrow("ni˨˩˦ xau˨˩˦"), "[ni˧˥ xa̠u˨˩˦]")
        self.assertEqual(self.narrow("xau˨˩˦ ma˙"), "[xa̠u˨˩ ma˦]")
        self.assertEqual(self.narrow("mi˨˩˦"), "[mi˨˩˦]")   # alone: the full rise

    def test_the_neutral_tone_takes_its_pitch_from_the_tone_before(self) -> None:
        for broad, narrow in (("ma˥˥ma˙", "[ma˥˥ma˨]"), ("pa˥˩pa˙", "[pa˥˩pa˩]"),
                              ("tʰa˥˥ tə˙", "[tʰa˥˥ tə˨]"), ("ma˙", "[ma˙]")):
            with self.subTest(broad):
                self.assertEqual(self.narrow(broad), narrow)

    def test_the_apical_vowels(self) -> None:
        self.assertEqual(self.narrow("sɨ˥˥"), "[sɹ̩˥˥]")
        self.assertEqual(self.narrow("ʈʂɨ˥˥"), "[ʈʂɻ̩˥˥]")
        self.assertEqual(self.narrow("ʈʂʰɨ˧˥"), "[ʈʂʰɻ̩˧˥]")
        self.assertEqual(self.narrow("ɻɨ˥˩"), "[ɻɻ̩˥˩]")

    def test_every_rule_names_its_source(self) -> None:
        raw = yaml.safe_load(self.path.read_text("utf-8"))
        for rule in raw["rules"]:
            self.assertGreaterEqual(len(rule["source"]), 20, rule["id"])


if __name__ == "__main__":
    unittest.main()
