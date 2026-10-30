#!/usr/bin/env python3
"""Tests for tools/import_phonetic.py and tools/derive_phonetic.py, and the
patching they share (tools/phonetic_patch.py). A fake Wiktionary dump and a
tiny language, zz, stand in for the real ones: nothing is downloaded.

Stdlib `unittest` plus PyYAML, like the tools.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

import derive_phonetic as dp  # noqa: E402
import import_phonetic as ip  # noqa: E402
import phonetic_patch as pp  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

CORE = '''schema: 1
id: "zz-home"
part: "core"
kind: "vocab"
language: { code: "zz", iso639_3: "zzz", name: "Zed", script: "latin" }
license: "CC-BY-SA-4.0"
theme: "home"
cards:
  - id: "zz-0001"
    target: "kat"
    ipa: "kat"
    pos: "noun"
    tags: ["animal"]
  - id: "zz-0002"
    target: "dog"
    ipa: "dɔɡ"
    phonetic: "[dɔɡ̊]"
    phonetic_source: "wiktionary"
    pos: "noun"
  - id: "zz-0003"
    target: "bat"
    ipa: "bat"
    pos: "noun"
  - id: "zz-0004"
    target: "nobody"
    pos: "noun"
  - id: "zz-0005"
    target: "pen"
    ipa: "pen"
    pos: "noun"
    notes:
      - { id: "n1", kind: "note" }
  - id: "zz-0006"
    target: "tin"
    ipa: "tin"
    pos: "noun"
'''


def sound(ipa: str, **extra: object) -> dict:
    return {"ipa": ipa, **extra}


def entry(word: str, *sounds: dict, pos: str = "noun") -> str:
    return json.dumps({"word": word, "pos": pos, "senses": [{"glosses": ["x"]}],
                       "sounds": list(sounds)}, ensure_ascii=False)


class Tree(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.decks = self.tmp / "decks"
        (self.decks / "zz").mkdir(parents=True)
        self.core = self.decks / "zz" / "zz-home.yaml"
        self.core.write_text(CORE, encoding="utf-8")

    def dump(self, *lines: str) -> Path:
        path = self.tmp / "dump.jsonl"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path


class Patching(Tree):
    def test_the_two_lines_go_in_after_ipa_and_nothing_else_changes(self) -> None:
        new, left = pp.patch(CORE, {"zz-0001": ("[kʰat]", "wiktionary")})
        self.assertEqual(left, {})
        old_lines, new_lines = CORE.split("\n"), new.split("\n")
        self.assertEqual(len(new_lines), len(old_lines) + 2)
        at = old_lines.index('    ipa: "kat"')
        self.assertEqual(new_lines[at + 1:at + 3],
                         ['    phonetic: "[kʰat]"', '    phonetic_source: "wiktionary"'])
        self.assertEqual(new_lines[:at + 1] + new_lines[at + 3:], old_lines)

    def test_a_card_that_has_a_phonetic_is_skipped(self) -> None:
        new, left = pp.patch(CORE, {"zz-0002": ("[dɔɡ]", "rules")})
        self.assertEqual(new, CORE)
        self.assertEqual(left, {"zz-0002": "has phonetic"})

    def test_a_card_without_an_ipa_line_or_not_in_the_file_is_left_alone(self) -> None:
        new, left = pp.patch(CORE, {"zz-0004": ("[x]", "rules"), "zz-9999": ("[x]", "rules")})
        self.assertEqual(new, CORE)
        self.assertEqual(left, {"zz-0004": "no ipa line", "zz-9999": "not in file"})

    def test_a_card_is_patched_inside_its_own_block_only(self) -> None:
        new, _ = pp.patch(CORE, {"zz-0003": ("[bat]", "rules"), "zz-0006": ("[tin]", "rules")})
        self.assertEqual(new.count("phonetic_source"), 3)  # the existing card too
        self.assertIn('    ipa: "bat"\n    phonetic: "[bat]"\n    phonetic_source: "rules"\n'
                      '    pos: "noun"\n  - id: "zz-0004"', new)
        self.assertTrue(new.endswith('    ipa: "tin"\n    phonetic: "[tin]"\n'
                                     '    phonetic_source: "rules"\n    pos: "noun"\n'))

    def test_a_form_that_is_not_narrow_ipa_in_brackets_is_refused(self) -> None:
        for bad in ("kat", "[]", "[kat!]", "/kat/", "[ka:t]", "[ ]"):
            with self.subTest(bad):
                self.assertIsNone(pp.normalise(bad))

    def test_a_form_is_written_as_the_decks_write_ipa(self) -> None:
        self.assertEqual(pp.normalise("[ˈgɾa.t̪is]"), "[ˈɡɾat̪is]")  # g, dots
        self.assertEqual(pp.normalise("[ã]"), "[ã]")  # NFC


class Importing(Tree):
    def run_import(self, *lines: str, write: bool = False):
        with mock.patch.dict(ip.VARIETIES, {"zz": ip.Variety(
                "Zed standard", notes=frozenset({"Std"}))}):
            return ip.run("zz", self.dump(*lines), self.decks, write)

    def test_a_form_of_the_courses_variety_is_taken_and_written(self) -> None:
        cov, fills = self.run_import(
            entry("kat", sound("[kʰat]", note="Std")), write=True)
        self.assertEqual(fills[self.core]["zz-0001"], ("[kʰat]", "wiktionary"))
        text = self.core.read_text(encoding="utf-8")
        self.assertIn('    ipa: "kat"\n    phonetic: "[kʰat]"\n'
                      '    phonetic_source: "wiktionary"\n', text)
        self.assertEqual(cov.decks["zz-home"]["filled"], 1)

    def test_the_marked_variety_beats_an_untagged_form_and_others_are_not_taken(self) -> None:
        _, fills = self.run_import(entry(
            "kat", sound("[kat]"), sound("[kʰat]", note="Std"), sound("[kat̚]", note="Other")))
        self.assertEqual(fills[self.core]["zz-0001"][0], "[kʰat]")

    def test_only_another_variety_is_counted_and_not_written(self) -> None:
        cov, fills = self.run_import(entry("kat", sound("[kat̚]", note="Other")))
        self.assertNotIn("zz-0001", fills.get(self.core, {}))
        self.assertEqual(cov.decks["zz-home"]["other variety"], 1)

    def test_a_form_that_is_not_ipa_is_counted_and_not_written(self) -> None:
        cov, fills = self.run_import(entry("kat", sound("[ka t!]", note="Std")))
        self.assertEqual(fills, {})
        self.assertEqual(cov.decks["zz-home"]["invalid"], 1)

    def test_entries_that_disagree_are_ambiguous(self) -> None:
        cov, fills = self.run_import(entry("kat", sound("[kat]")), entry("kat", sound("[kʰat]")))
        self.assertEqual(fills, {})
        self.assertEqual(cov.decks["zz-home"]["ambiguous"], 1)

    def test_a_card_with_a_phonetic_is_not_looked_up_again(self) -> None:
        cov, fills = self.run_import(entry("dog", sound("[dɔɡ]")))
        self.assertEqual(fills, {})
        self.assertEqual(cov.decks["zz-home"]["has phonetic"], 1)

    def test_coverage_counts_every_card_once(self) -> None:
        cov, _ = self.run_import(entry("kat", sound("[kʰat]")),
                                 entry("bat", sound("/bat/")))
        row = cov.decks["zz-home"]
        self.assertEqual(sum(row.values()), 6)
        self.assertEqual((row["filled"], row["has phonetic"], row["no ipa line"]), (1, 1, 1))
        # bat's only form is a phonemic /bat/: no narrow form, so not read at
        # all; pen, tin and bat count as having no entry.
        self.assertEqual(row["no entry"], 3)
        self.assertIn("| **zz total** | 6 |", cov.render("zz", ip.OUTCOMES, title="t"))

    def test_nothing_is_written_without_write(self) -> None:
        self.run_import(entry("kat", sound("[kʰat]")))
        self.assertEqual(self.core.read_text(encoding="utf-8"), CORE)

    def test_the_dump_is_downloaded_once_and_then_read_from_the_cache(self) -> None:
        calls: list[str] = []

        def fake(url: str, dest: Path) -> None:
            calls.append(url)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text("{}\n", encoding="utf-8")

        cache = self.tmp / "cache"
        with mock.patch.dict(ip.DUMP_NAMES, {"zz": "Zed"}):
            first = ip.ensure_dump("zz", cache=cache, fetch=fake)
            second = ip.ensure_dump("zz", cache=cache, fetch=fake)
            ip.ensure_dump("zz", cache=cache, refresh=True, fetch=fake)
        self.assertEqual(first, second)
        self.assertEqual(len(calls), 2)  # the first run, and the refresh
        self.assertTrue(calls[0].endswith("/Zed/kaikki.org-dictionary-Zed.jsonl"))


class Deriving(Tree):
    @staticmethod
    def rules(*pairs: tuple[str, str]) -> list[dp.Rule]:
        import re
        return [dp.Rule(f"zz-r{i}", re.compile(a), b, "A source, 2000")
                for i, (a, b) in enumerate(pairs)]

    def write_rules(self, *pairs: tuple[str, str]) -> None:
        body = "".join(f'  - id: "zz-r{i}"\n    pattern: \'{a}\'\n    replace: \'{b}\'\n'
                       f'    source: "A source, 2000"\n' for i, (a, b) in enumerate(pairs))
        (self.decks / "zz" / "zz-phonetics.yaml").write_text(
            'schema: 1\nkind: "phonetics"\nid: "zz-phonetics"\nlanguage: "zz"\n'
            f'variety: "Zed"\nrules:\n{body}', encoding="utf-8")

    def test_rules_apply_in_order_each_to_the_result_of_the_last(self) -> None:
        in_order = dp.apply_rules("kat", self.rules(("k", "kʰ"), ("kʰa", "kʰɑ")))
        reversed_ = dp.apply_rules("kat", self.rules(("kʰa", "kʰɑ"), ("k", "kʰ")))
        self.assertEqual(in_order, "kʰɑt")
        self.assertEqual(reversed_, "kʰat")

    def test_a_card_the_rules_change_is_filled_and_marked_rules(self) -> None:
        self.write_rules(("t$", "t̚"))
        cov, fills = dp.run("zz", self.decks, write=True)
        self.assertEqual(fills[self.core]["zz-0001"], ("[kat̚]", "rules"))
        self.assertIn('    ipa: "kat"\n    phonetic: "[kat̚]"\n'
                      '    phonetic_source: "rules"\n', self.core.read_text(encoding="utf-8"))
        # Existing phonetic skipped (Wiktionary's wins); no ipa; others by rule.
        row = cov.decks["zz-home"]
        self.assertEqual((row["filled"], row["has phonetic"], row["no ipa line"]), (2, 1, 1))
        self.assertEqual(row["unchanged"], 2)  # pen and tin: no t at their end

    def test_a_card_the_rules_leave_alone_gets_nothing_unless_asked(self) -> None:
        self.write_rules(("t$", "t̚"))
        _, fills = dp.run("zz", self.decks, write=False)
        self.assertNotIn("zz-0005", fills[self.core])
        _, fills = dp.run("zz", self.decks, write=False, bracket_unchanged=True)
        self.assertEqual(fills[self.core]["zz-0005"], ("[pen]", "rules"))

    def test_a_result_that_is_not_ipa_is_counted_and_never_written(self) -> None:
        self.write_rules(("k", "K!"))
        cov, fills = dp.run("zz", self.decks, write=True)
        self.assertNotIn("zz-0001", fills.get(self.core, {}))
        self.assertEqual(cov.decks["zz-home"]["invalid"], 1)
        self.assertNotIn("K!", self.core.read_text(encoding="utf-8"))

    def test_nothing_is_written_without_write(self) -> None:
        self.write_rules(("t$", "t̚"))
        dp.run("zz", self.decks, write=False)
        self.assertEqual(self.core.read_text(encoding="utf-8"), CORE)


class TheRulesFiles(unittest.TestCase):
    """The shipped rules, on words whose narrow form is well known."""

    def derive(self, lang: str, ipa: str) -> str:
        rules = dp.load_rules(ROOT / "decks" / lang / f"{lang}-phonetics.yaml").rules
        form, _ = dp.derive(ipa, rules)
        return form

    def test_spanish_nasals_stops_and_s(self) -> None:
        self.assertEqual(self.derive("es", "ˈtenɡo"), "[ˈt̪eŋɡo]")
        self.assertEqual(self.derive("es", "la ˈbota"), "[la ˈβot̪a]")
        self.assertEqual(self.derive("es", "un ˈbeso"), "[un ˈbeso]")
        self.assertEqual(self.derive("es", "ˈmismo"), "[ˈmizmo]")
        self.assertEqual(self.derive("es", "ˈkomɾo"), "[ˈkomɾo]")
        self.assertEqual(self.derive("es", "ˈandaɾ"), "[ˈan̪d̪aɾ]")

    def test_spanish_n_before_tesh_is_palatal_and_before_t_is_dental(self) -> None:
        self.assertEqual(self.derive("es", "ˈmuntʃo"), "[ˈmuɲtʃo]")
        self.assertEqual(self.derive("es", "ˈunto"), "[ˈun̪t̪o]")

    def test_every_shipped_rule_has_a_source_and_a_valid_file(self) -> None:
        for lang in ("bn", "hi", "es"):
            with self.subTest(lang):
                ruleset = dp.load_rules(ROOT / "decks" / lang / f"{lang}-phonetics.yaml")
                self.assertTrue(all(r.source for r in ruleset.rules))
                self.assertTrue(all(r.id.startswith(f"{lang}-") for r in ruleset.rules))


if __name__ == "__main__":
    unittest.main()
