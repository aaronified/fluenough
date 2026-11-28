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

import yaml

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

QUOTED = '''"schema": !!int "1"
"id": "zz-quoted"
"part": "core"
"kind": "vocab"
"cards":
- "id": "zz-0001"
  "target": "kat"
  "words":
  - "kat"
  "ipa": "kat"
  "pos": "noun"
  "examples":
  - "target": "a kat"
    "ipa": "a kat"
- "id": "zz-0002"
  "target": "dog"
  "ipa": "dɔɡ"
  "phonetic": "[dɔɡ̊]"
  "phonetic_source": "rules"
  "pos": "noun"
- "id": "zz-0003"
  "target": "bat"
  "pos": "noun"
  "examples":
  - "target": "a bat"
    "ipa": "a bat"
'''

JSONISH = '''{
  "schema": 1,
  "id": "zz-json",
  "part": "core",
  "kind": "vocab",
  "cards": [
    {
      "id": "zz-0001",
      "target": "kat",
      "notes": [
        {
          "id": "n1",
          "kind": "usage"
        }
      ],
      "ipa": "kat",
      "pos": "noun",
      "examples": [
        {
          "target": "a kat",
          "ipa": "a kat"
        }
      ]
    },
    {
      "id": "zz-0002",
      "target": "bat",
      "pos": "noun",
      "ipa": "bat"
    },
    {
      "id": "zz-0003",
      "target": "tin",
      "ipa": "tin",
      "phonetic": "[tʰin]",
      "phonetic_source": "wiktionary",
      "pos": "noun"
    }
  ]
}
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

    def test_quoted_key_yaml_at_column_0_gets_quoted_keys_and_nothing_else_changes(self) -> None:
        new, left = pp.patch(QUOTED, {"zz-0001": ("[kʰat]", "rules")})
        self.assertEqual(left, {})
        old_lines, new_lines = QUOTED.split("\n"), new.split("\n")
        at = old_lines.index('  "ipa": "kat"')
        self.assertEqual(new_lines[at + 1:at + 3],
                         ['  "phonetic": "[kʰat]"', '  "phonetic_source": "rules"'])
        self.assertEqual(new_lines[:at + 1] + new_lines[at + 3:], old_lines)
        self.assertEqual(yaml.safe_load(new)["cards"][0]["phonetic"], "[kʰat]")

    def test_quoted_key_yaml_skips_has_phonetic_missing_ipa_and_example_ipa(self) -> None:
        # zz-0003 has an ipa only inside an example: it has no card-level line.
        new, left = pp.patch(QUOTED, {"zz-0002": ("[dɔɡ]", "rules"),
                                      "zz-0003": ("[bat]", "rules")})
        self.assertEqual(new, QUOTED)
        self.assertEqual(left, {"zz-0002": "has phonetic", "zz-0003": "no ipa line"})

    def test_quoted_key_yaml_replaces_a_rules_phonetic_in_place(self) -> None:
        new, left = pp.patch(QUOTED, {"zz-0002": ("[dɔɡ]", "rules")}, replace_rules=True)
        self.assertEqual(left, {})
        self.assertEqual(new, QUOTED.replace('"phonetic": "[dɔɡ̊]"', '"phonetic": "[dɔɡ]"'))

    def test_quoted_key_yaml_with_the_list_indented_is_patched_too(self) -> None:
        indented = "\n".join(("  " + ln if ln.startswith("- ") or ln.startswith("  ") else ln)
                             for ln in QUOTED.split("\n"))
        new, left = pp.patch(indented, {"zz-0001": ("[kʰat]", "rules")})
        self.assertEqual(left, {})
        self.assertIn('    "ipa": "kat"\n    "phonetic": "[kʰat]"\n'
                      '    "phonetic_source": "rules"\n    "pos": "noun"', new)
        self.assertEqual(len(new.split("\n")), len(indented.split("\n")) + 2)

    def test_quoted_key_yaml_keeps_crlf(self) -> None:
        crlf = QUOTED.replace("\n", "\r\n")
        new, _ = pp.patch(crlf, {"zz-0001": ("[kʰat]", "rules")})
        self.assertIn('  "ipa": "kat"\r\n  "phonetic": "[kʰat]"\r\n'
                      '  "phonetic_source": "rules"\r\n  "pos"', new)
        self.assertEqual(new.count("\n"), crlf.count("\n") + 2)
        self.assertEqual(new.count("\r\n"), new.count("\n"))

    def test_json_style_gets_two_comma_terminated_lines_after_the_card_ipa(self) -> None:
        new, left = pp.patch(JSONISH, {"zz-0001": ("[kʰat]", "rules")})
        self.assertEqual(left, {})
        old_lines, new_lines = JSONISH.split("\n"), new.split("\n")
        at = old_lines.index('      "ipa": "kat",')
        self.assertEqual(new_lines[at + 1:at + 3],
                         ['      "phonetic": "[kʰat]",', '      "phonetic_source": "rules",'])
        self.assertEqual(new_lines[:at + 1] + new_lines[at + 3:], old_lines)
        card = json.loads(new)["cards"][0]
        self.assertEqual((card["phonetic"], card["phonetic_source"]), ("[kʰat]", "rules"))
        self.assertNotIn("phonetic", card["examples"][0])

    def test_json_style_ipa_as_last_key_is_reported_not_patched(self) -> None:
        new, left = pp.patch(JSONISH, {"zz-0002": ("[bat]", "rules")})
        self.assertEqual(new, JSONISH)
        self.assertEqual(left, {"zz-0002": "unsupported layout"})

    def test_json_style_skips_has_phonetic_and_ignores_note_ids(self) -> None:
        new, left = pp.patch(JSONISH, {"zz-0003": ("[tin]", "rules"), "n1": ("[x]", "rules")})
        self.assertEqual(new, JSONISH)
        self.assertEqual(left, {"zz-0003": "has phonetic", "n1": "not in file"})

    # --- A plain id line over quoted field keys (decks-live's te files) ----

    MIXED2 = ('"cards":\n- id: "zz-0001"\n  "target": "kat"\n  "ipa": "kat"\n'
              '  "pos": "noun"\n  "examples":\n  - "target": "a kat"\n    "ipa": "a kat"\n')
    MIXED4 = ('"cards":\n  - id: "zz-0001"\n    "target": "kat"\n    "ipa": "kat"\n'
              '    "pos": "noun"\n    "examples":\n    - "target": "a kat"\n'
              '      "ipa": "a kat"\n')

    def test_plain_id_with_quoted_keys_is_patched_in_the_ipa_lines_style(self) -> None:
        for name, text, pad in (("2", self.MIXED2, "  "), ("4", self.MIXED4, "    ")):
            with self.subTest(indent=name):
                new, left = pp.patch(text, {"zz-0001": ("[kʰat]", "rules")})
                self.assertEqual(left, {})
                self.assertIn(f'{pad}"ipa": "kat"\n{pad}"phonetic": "[kʰat]"\n'
                              f'{pad}"phonetic_source": "rules"\n{pad}"pos"', new)
                self.assertEqual(len(new.split("\n")), len(text.split("\n")) + 2)
                self.assertEqual(new.count('"phonetic"'), 1)  # not the example's

    def test_plain_id_with_quoted_keys_skips_and_replaces_like_the_others(self) -> None:
        has = self.MIXED4.replace('    "pos"', '    "phonetic": "[kat̚]"\n'
                                  '    "phonetic_source": "rules"\n    "pos"', 1)
        new, left = pp.patch(has, {"zz-0001": ("[kʰat]", "rules")})
        self.assertEqual((new, left), (has, {"zz-0001": "has phonetic"}))
        new, left = pp.patch(has, {"zz-0001": ("[kʰat]", "rules")}, replace_rules=True)
        self.assertEqual(left, {})
        self.assertEqual(new, has.replace("[kat̚]", "[kʰat]"))

    def test_quoted_id_with_plain_keys_is_patched_plain(self) -> None:
        text = 'cards:\n  - "id": "zz-0001"\n    target: "kat"\n    ipa: "kat"\n    pos: "noun"\n'
        new, left = pp.patch(text, {"zz-0001": ("[kʰat]", "rules")})
        self.assertEqual(left, {})
        self.assertIn('    ipa: "kat"\n    phonetic: "[kʰat]"\n    phonetic_source: "rules"\n', new)

    def test_all_plain_and_all_quoted_files_are_unchanged_by_the_fix(self) -> None:
        new, _ = pp.patch(CORE, {"zz-0001": ("[kʰat]", "rules")})
        self.assertIn('    ipa: "kat"\n    phonetic: "[kʰat]"\n    phonetic_source: "rules"\n', new)
        new, _ = pp.patch(QUOTED, {"zz-0001": ("[kʰat]", "rules")})
        self.assertIn('  "ipa": "kat"\n  "phonetic": "[kʰat]"\n  "phonetic_source": "rules"\n', new)

    def test_a_single_file_deck_with_no_part_is_seen_but_a_layer_is_not(self) -> None:
        # #1428: ja-en-hiragana is a vocab deck with no `part`; derive and
        # import skipped its cards. A layer (`kind: "layer"`) and a deck of
        # another kind stay out.
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: __import__("shutil").rmtree(tmp, True))
        (tmp / "zz").mkdir()
        single = QUOTED.replace('"part": "core"\n', "")
        self.assertNotIn('"part"', single)
        (tmp / "zz" / "zz-en-single.yaml").write_text(single, encoding="utf-8")
        (tmp / "zz" / "zz-en-layer.yaml").write_text(
            QUOTED.replace('"part": "core"', '"kind": "layer"').replace(
                '"kind": "vocab"', '"core": "zz-x"'), encoding="utf-8")
        (tmp / "zz" / "zz-en-sounds.yaml").write_text(
            QUOTED.replace('"kind": "vocab"', '"kind": "sounds"').replace(
                '"part": "core"\n', ""), encoding="utf-8")
        cards = pp.core_cards(tmp, "zz")
        self.assertEqual([(c.file.name, c.cid) for c in cards],
                         [("zz-en-single.yaml", f"zz-000{i}") for i in (1, 2, 3)])

    def test_derive_fills_the_cards_of_a_single_file_deck(self) -> None:
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: __import__("shutil").rmtree(tmp, True))
        (tmp / "zz").mkdir()
        single = CORE.replace('part: "core"\n', "")
        (tmp / "zz" / "zz-en-home.yaml").write_text(single, encoding="utf-8")
        (tmp / "zz" / "zz-phonetics.yaml").write_text(
            'schema: 1\nkind: "phonetics"\nid: "zz-phonetics"\nlanguage: "zz"\n'
            'variety: "Zed"\nrules:\n  - id: "zz-r0"\n    pattern: \'t$\'\n'
            '    replace: \'t\u031a\'\n    source: "A source, 2000"\n', encoding="utf-8")
        dp.run("zz", tmp, write=True)
        self.assertIn('phonetic: "[kat\u031a]"',
                      (tmp / "zz" / "zz-en-home.yaml").read_text(encoding="utf-8"))

    def test_a_card_in_every_layout_is_seen_by_core_cards(self) -> None:
        for name, text in (("zz-quoted", QUOTED), ("zz-json", JSONISH)):
            with self.subTest(name):
                tmp = Path(tempfile.mkdtemp())
                self.addCleanup(lambda t=tmp: __import__("shutil").rmtree(t, True))
                (tmp / "zz").mkdir()
                (tmp / "zz" / f"{name}.yaml").write_text(text, encoding="utf-8")
                cards = pp.core_cards(tmp, "zz")
                self.assertEqual([c.cid for c in cards], ["zz-0001", "zz-0002", "zz-0003"])
                # A JSON-style card whose ipa is its last key cannot be patched.
                self.assertEqual({c.cid: c.block for c in cards},
                                 {"zz-0001": True, "zz-0002": name != "zz-json",
                                  "zz-0003": True})

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


class Registry(Tree):
    """The languages are data (tools/phonetic_languages.yaml, #1285): a new
    language needs an entry, never a change of the tool."""

    def test_the_first_three_languages_keep_their_dump_and_variety(self) -> None:
        self.assertEqual(
            {k: ip.DUMP_NAMES[k] for k in ("bn", "hi", "es")},
            {"bn": "Bengali", "hi": "Hindi", "es": "Spanish"})
        bn, hi, es = (ip.VARIETIES[k] for k in ("bn", "hi", "es"))
        self.assertEqual((bn.notes, bn.tags, bn.untagged),
                         (frozenset({"Rarh"}), frozenset(), True))
        self.assertEqual((hi.notes, hi.tags, hi.untagged),
                         (frozenset(), frozenset({"Hindi", "Standard"}), True))
        self.assertEqual((es.notes, es.tags, es.untagged),
                         (frozenset(), frozenset(), True))

    def test_gujarati_takes_wiktionarys_standard_form_only(self) -> None:
        self.assertEqual(ip.DUMP_NAMES["gu"], "Gujarati")
        gu = ip.VARIETIES["gu"]
        self.assertEqual((gu.notes, gu.tags, gu.untagged),
                         (frozenset(), frozenset({"Gujarati", "Standard"}),
                          False))
        self.assertTrue(gu.normalise and gu.align)  # see Normalising

    def test_telugu_and_japanese_are_registered_with_their_dumps(self) -> None:
        self.assertEqual(ip.DUMP_NAMES["te"], "Telugu")
        self.assertEqual(ip.DUMP_NAMES["ja"], "Japanese")
        self.assertEqual(ip.DUMP_NAMES["fr"], "French")
        self.assertEqual(set(ip.DUMP_NAMES), set(ip.VARIETIES))

    def test_chinese_is_registered_but_takes_no_wiktionary_form(self) -> None:
        # The dump is one 1.2 GB file for every variety and holds no `[ ]` form
        # for Mandarin in its first 6 MB; the narrow form comes from the rules.
        self.assertEqual(ip.DUMP_NAMES["zh"], "Chinese")
        zh = ip.VARIETIES["zh"]
        self.assertEqual((zh.notes, zh.tags, zh.untagged, zh.normalise),
                         (frozenset(), frozenset(), False, ()))

    def test_italian_is_registered_but_takes_no_wiktionary_form(self) -> None:
        # Only 50 of the dump's 114,267 Italian forms are narrow, all regional
        # or connected speech: the narrow form comes from the rules file.
        self.assertEqual(ip.DUMP_NAMES["it"], "Italian")
        it = ip.VARIETIES["it"]
        self.assertEqual((it.notes, it.tags, it.untagged, it.normalise),
                         (frozenset(), frozenset(), False, ()))

    def test_german_is_registered_but_takes_no_wiktionary_form(self) -> None:
        # No standard narrow German form is worth importing: the narrow form
        # comes from the rules file.
        self.assertEqual(ip.DUMP_NAMES["de"], "German")
        de = ip.VARIETIES["de"]
        self.assertEqual((de.notes, de.tags, de.untagged, de.normalise),
                         (frozenset(), frozenset(), False, ()))

    def test_russian_is_registered_but_takes_no_wiktionary_form(self) -> None:
        # Rules only, as German: the narrow form comes from the rules file.
        self.assertEqual(ip.DUMP_NAMES["ru"], "Russian")
        ru = ip.VARIETIES["ru"]
        self.assertEqual((ru.notes, ru.tags, ru.untagged, ru.normalise),
                         (frozenset(), frozenset(), False, ()))

    def test_greek_is_registered_but_takes_no_wiktionary_form(self) -> None:
        # Rules only, as German and Russian: the narrow form comes from the
        # rules file.
        self.assertEqual(ip.DUMP_NAMES["el"], "Greek")
        el = ip.VARIETIES["el"]
        self.assertEqual((el.notes, el.tags, el.untagged, el.normalise),
                         (frozenset(), frozenset(), False, ()))

    def test_polish_is_registered_but_takes_no_wiktionary_form(self) -> None:
        # Rules only, as German, Russian and Greek: the narrow form comes
        # from the rules file.
        self.assertEqual(ip.DUMP_NAMES["pl"], "Polish")
        pl = ip.VARIETIES["pl"]
        self.assertEqual((pl.notes, pl.tags, pl.untagged, pl.normalise),
                         (frozenset(), frozenset(), False, ()))

    def test_marathi_is_registered_but_takes_no_wiktionary_form(self) -> None:
        # #1476: the kaikki.org dump covers about 9% of the course and uses
        # another convention, so the narrow form comes from the rules file.
        self.assertEqual(ip.DUMP_NAMES["mr"], "Marathi")
        mr = ip.VARIETIES["mr"]
        self.assertEqual((mr.notes, mr.tags, mr.untagged, mr.normalise, mr.align),
                         (frozenset(), frozenset(), False, (), ()))
        self.assertIsNone(mr.agree)

    def test_a_marathi_card_is_not_filled_from_an_untagged_wiktionary_form(self) -> None:
        mr_dir = self.decks / "mr"
        mr_dir.mkdir()
        (mr_dir / "mr-home.yaml").write_text(
            CORE.replace("zz", "mr").replace('"Zed"', '"Marathi"'), encoding="utf-8")
        cov, fills = ip.run("mr", self.dump(entry("kat", sound("[kat\u02b0]"))),
                            self.decks, True)
        self.assertEqual(fills, {})
        self.assertNotIn("kat\u02b0", (mr_dir / "mr-home.yaml").read_text(encoding="utf-8"))

    def test_a_new_language_in_a_registry_file_is_imported_with_no_code_change(self) -> None:
        reg = self.tmp / "registry.yaml"
        reg.write_text(
            "zz:\n  dump: Zed\n  variety:\n    name: \"Zed standard\"\n"
            "    notes: [\"Std\"]\n    untagged: false\n", encoding="utf-8")
        dumps, varieties = ip.load_registry(reg)
        self.assertEqual(dumps, {"zz": "Zed"})
        with mock.patch.dict(ip.DUMP_NAMES, dumps), \
                mock.patch.dict(ip.VARIETIES, varieties):
            self.assertTrue(str(ip.dump_path("zz", self.tmp)).endswith(
                "kaikki.org-dictionary-Zed.jsonl"))
            cov, fills = ip.run(
                "zz", self.dump(
                    entry("kat", sound("[kat]"), sound("[kʰat]", note="Std"))),
                self.decks, False)
        # The marked variety is taken; the untagged form is not (untagged: false).
        self.assertEqual(fills[self.core]["zz-0001"][0], "[kʰat]")

    def test_a_registry_that_is_not_a_mapping_or_not_yaml_names_the_file(self) -> None:
        reg = self.tmp / "list.yaml"
        reg.write_text('- "zz"\n', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "list.yaml.*must map"):
            ip.load_registry(reg)
        bad = self.tmp / "broken.yaml"
        bad.write_text('zz: [unclosed\n', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "broken.yaml"):
            ip.load_registry(bad)

    def test_an_entry_without_a_dump_or_variety_names_itself_in_the_error(self) -> None:
        reg = self.tmp / "bad.yaml"
        reg.write_text("qq:\n  dump: Qux\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "qq"):
            ip.load_registry(reg)


class Normalising(Tree):
    """A language may opt in to `normalise` pairs (#1369, gap 5), so
    Wiktionary's forms read in the conventions of the course's rules."""

    PAIRS = (("([\u00f0\u03b2\u0263])\u031e", "\\1"),
             ("([td])[\u0361\u035c]([\u0283\u0292])", "\\1\\2"),
             ("n\u031f(?=\u02c8?\u03b8)", "n\u032a"))

    def zz(self, normalise=()):
        return {"zz": ip.Variety("Zed", normalise=normalise)}

    def run_import(self, *lines: str, normalise=PAIRS, write: bool = False):
        with mock.patch.dict(ip.VARIETIES, self.zz(normalise)):
            return ip.run("zz", self.dump(*lines), self.decks, write)

    def form(self, ipa: str, **kw) -> str:
        _, fills = self.run_import(entry("kat", sound(ipa)), **kw)
        return fills[self.core]["zz-0001"][0]

    def test_spanish_conventions_are_applied_to_an_imported_form(self) -> None:
        self.assertEqual(self.form("[ˈkað̞β̞ɣ̞]"), "[ˈkaðβɣ]")
        self.assertEqual(self.form("[t͡ʃa d͡ʒa]"), "[tʃa dʒa]")
        self.assertEqual(self.form("[ˈan̟θo]"), "[ˈan̪θo]")

    def test_the_tie_barred_palatal_and_nasal_vowels_are_left_alone(self) -> None:
        for kept in ("[ˈkaɟ͡ʝo]", "[ˈkãn]", "[ˈan̟to]"):
            self.assertEqual(self.form(kept), kept)

    def test_a_language_without_pairs_keeps_the_form_as_wiktionary_wrote_it(self) -> None:
        self.assertEqual(self.form("[ˈkað̞]", normalise=()), "[ˈkað̞]")

    def test_the_real_registry_normalises_spanish_and_gujarati_only(self) -> None:
        es = ip.VARIETIES["es"]
        self.assertEqual(es.normalised("[t͡ʃan̟θβ̞]"),
                         "[tʃan̪θβ]")
        for lang, v in ip.VARIETIES.items():
            if lang not in ("es", "gu"):
                self.assertEqual((v.normalise, v.align), ((), ()), lang)

    def test_a_registry_entry_loads_its_pairs_and_a_bad_pattern_names_the_language(self) -> None:
        reg = self.tmp / "r.yaml"
        reg.write_text('zz:\n  dump: Zed\n  variety:\n    name: "Zed"\n  normalise:\n'
                       '    - pattern: \'x\\u031e\'\n      replace: "y"\n', encoding="utf-8")
        _, varieties = ip.load_registry(reg)
        self.assertEqual(varieties["zz"].normalised("[ax̞]"), "[ay]")
        reg.write_text('zz:\n  dump: Zed\n  variety:\n    name: "Zed"\n  normalise:\n'
                       '    - pattern: "("\n      replace: ""\n', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "zz"):
            ip.load_registry(reg)

    def test_renormalise_rewrites_wiktionary_cards_in_place_and_only_those(self) -> None:
        text = CORE.replace('"[dɔɡ̊]"', '"[ˈdɔð̞]"')
        text = text.replace('    ipa: "bat"\n',
                            '    ipa: "bat"\n    phonetic: "[baβ̞]"\n'
                            '    phonetic_source: "rules"\n')
        self.core.write_text(text, encoding="utf-8")
        with mock.patch.dict(ip.VARIETIES, self.zz(self.PAIRS)):
            cov, fills = ip.renormalise("zz", self.decks, write=False)
            self.assertEqual(self.core.read_text(encoding="utf-8"), text)  # report only
            self.assertEqual(fills[self.core], {"zz-0002": ("[ˈdɔð]", "wiktionary")})
            self.assertEqual(cov.decks["zz-home"]["renormalised"], 1)
            ip.renormalise("zz", self.decks, write=True)
            again, _ = ip.renormalise("zz", self.decks, write=True)
        out = self.core.read_text(encoding="utf-8")
        self.assertIn('    phonetic: "[ˈdɔð]"\n    phonetic_source: "wiktionary"\n', out)
        self.assertEqual(out, text.replace("[ˈdɔð̞]", "[ˈdɔð]"))  # the rules card is untouched
        self.assertEqual(again.decks["zz-home"].get("renormalised", 0), 0)
        self.assertEqual(again.decks["zz-home"]["unchanged"], 1)


class GujaratiNormalising(unittest.TestCase):
    """Gujarati's registry rules put Wiktionary's forms in the deck's style:
    ʃ, r, ʋ and pʰ as the broad `ipa` writes them, no murmur marks; a genuine
    /s/ or /f/ is never rewritten (the rules align against the broad ipa)."""

    gu = ip.VARIETIES["gu"]

    def norm(self, form: str, broad: str | None) -> str:
        # As the import does: the rules, then NFC.
        return pp.normalise(self.gu.normalised(form, broad))

    def test_wiktionarys_s_for_sh_becomes_sh_where_the_broad_ipa_has_it(self) -> None:
        self.assertEqual(self.norm("[ˈsũ]", "ʃũ"), "[ʃũ]")
        self.assertEqual(self.norm("[ˈkʰuɾsi]", "kʰurʃi"), "[kʰurʃi]")
        self.assertEqual(self.norm("[ˈsukɾəʋɑɾ]", "ʃukrəʋar"), "[ʃukrəʋar]")

    def test_a_genuine_s_or_f_is_never_rewritten(self) -> None:
        self.assertEqual(self.norm("[ˈsɑɽɑ]", "saɖa"), "[saɽa]")
        self.assertEqual(self.norm("[ˈsɑːɾu]", "saːru"), "[saru]")
        self.assertEqual(self.norm("[ˈfɑ]", "fa"), "[fa]")
        # Only the position the broad ipa writes ʃ at changes.
        self.assertEqual(self.norm("[ˈsɑrsu]", "sarʃu"), "[sarʃu]")
        self.assertEqual(self.norm("[ˈsɑrsu]", "ʃarsu"), "[ʃarsu]")

    def test_f_becomes_aspirated_p_only_where_the_broad_ipa_has_it(self) -> None:
        self.assertEqual(self.norm("[ˈfoi]", "pʰoi"), "[pʰoi]")

    def test_a_form_that_does_not_line_up_with_the_broad_ipa_is_left_alone(self) -> None:
        # Wiktionary's ɦ for s, or another unit count: no guess.
        self.assertEqual(self.norm("[ˈɦəʋɑr]", "səʋar"), "[ɦəʋar]")
        self.assertEqual(self.norm("[ˈsũ]", "ʃũʃ"), "[sũ]")
        self.assertEqual(self.norm("[ˈsũ]", None), "[sũ]")

    def test_the_murmur_mark_goes_and_the_broad_ipas_h_comes_back(self) -> None:
        self.assertEqual(self.norm("[ˈmə̤ino]", "məɦino"), "[məɦino]")
        self.assertEqual(self.norm("[ˈṳ̃]", "ɦũ"), "[ɦũ]")
        self.assertEqual(self.norm("[ˈə̤ĩ]", "əɦĩ"), "[əɦĩ]")  # not ɦəĩ
        self.assertEqual(self.norm("[ˈd̪ə̤ĩ]", "d̪əɦĩ"), "[d̪əɦĩ]")
        self.assertEqual(self.norm("[ˈə̤ɭd̪əɾ]", "ɦəɭd̪ər"), "[ɦəɭd̪ər]")
        # With no broad ipa the mark is only dropped.
        self.assertEqual(self.norm("[ˈmə̤ino]", None), "[məino]")

    def test_tap_w_vowel_stress_length_and_ties_follow_the_deck(self) -> None:
        self.assertEqual(self.norm("[ˈpəɽwũ]", None), "[pəɽʋũ]")
        self.assertEqual(self.norm("[ˈsɑɽɑ]", "saɖa"), "[saɽa]")
        self.assertEqual(self.norm("[ˈseːɾi]", "ʃeri"), "[ʃeri]")
        self.assertEqual(self.norm("[ˈud͡ʒo]", None), "[udʒo]")

    def test_wiktionarys_open_e_is_the_decks_e_unless_the_broad_ipa_has_it(self) -> None:
        self.assertEqual(self.norm("[bɛn]", "ben"), "[ben]")
        self.assertEqual(self.norm("[bɛɡ]", "bɛɡ"), "[bɛɡ]")

    def test_real_allophony_stays(self) -> None:
        for kept in ("[təɽko]", "[ãɡ]", "[əʈʰʋaɽijũ]"):
            self.assertEqual(self.norm(kept, None), kept)

    def test_the_guard_accepts_the_forms_that_agree_with_the_broad_ipa(self) -> None:
        for form, broad in (("[ˈsũ]", "ʃũ"), ("[ˈkʰuɾsi]", "kʰurʃi"),
                            ("[ˈmə̤ino]", "məɦino"), ("[ˈt̪əɽko]", "t̪əɖko"),
                            ("[ˈfoi]", "pʰoi"), ("[ˈsɑɽɑ]", "saɖa")):
            out = self.norm(form, broad)
            self.assertTrue(self.gu.agrees(out, broad), (form, out))

    def test_the_two_imports_that_contradict_the_broad_ipa_are_refused(self) -> None:
        # gu-0486 સવાર: Wiktionary's colloquial s > ɦ. gu-0264 આવજો: ɑu for aʋ.
        for form, broad in (("[ˈɦəʋɑɾ]", "səʋar"), ("[ˈɑud͡ʒo]", "aʋdʒo")):
            out = self.norm(form, broad)
            self.assertFalse(self.gu.agrees(out, broad), (form, out))

    def test_a_language_without_the_guard_accepts_everything(self) -> None:
        self.assertTrue(ip.VARIETIES["es"].agrees("[xyz]", "abc"))
        self.assertTrue(self.gu.agrees("[xyz]", None))


class AgreeGuard(Tree):
    """The `agree` guard: an imported form is accepted only if its sounds
    agree with the card's broad ipa; the card keeps its rules form otherwise
    and the run lists it (#1627)."""

    AGREE = ("", (("z", "t"),))

    def zz(self):
        return {"zz": ip.Variety("Zed", agree=self.AGREE)}

    def test_a_disagreeing_form_is_not_filled_and_is_listed(self) -> None:
        # CORE: zz-0001 has ipa "kat". [kaz] agrees (z maps to t); [kab] does not.
        for form, outcome in (("[kaz]", "filled"), ("[kab]", "disagrees")):
            skipped: list[str] = []
            with mock.patch.dict(ip.VARIETIES, self.zz()):
                cov, fills = ip.run("zz", self.dump(entry("kat", sound(form))),
                                    self.decks, False, skipped)
            self.assertEqual(cov.decks["zz-home"][outcome], 1, form)
            if outcome == "disagrees":
                self.assertNotIn("zz-0001", fills.get(self.core, {}))
                self.assertEqual(len(skipped), 1)
                self.assertTrue(skipped[0].startswith("zz-0001 "))
            else:
                self.assertEqual(skipped, [])

    def test_another_agreeing_form_of_the_word_is_still_taken(self) -> None:
        with mock.patch.dict(ip.VARIETIES, self.zz()):
            _, fills = ip.run("zz", self.dump(entry("kat", sound("[kab]"), sound("[kaz]"))),
                              self.decks, False)
        self.assertEqual(fills[self.core]["zz-0001"][0], "[kaz]")

    def test_the_registry_loads_agree_and_restore(self) -> None:
        reg = self.tmp / "r.yaml"
        reg.write_text('zz:\n  dump: Zed\n  variety:\n    name: "Zed"\n  agree:\n'
                       '    ignore: "h"\n    restore: true\n    map: { "z": "t" }\n',
                       encoding="utf-8")
        _, v = ip.load_registry(reg)
        self.assertEqual(v["zz"].skeleton("[ˈkaːh z]"), "kat")
        self.assertEqual(v["zz"].normalised("[kat]", "kaht"), "[kaht]")
        self.assertIsNone(ip.VARIETIES["es"].agree)

    def test_renormalise_gives_a_disagreeing_card_its_rules_form(self) -> None:
        text = CORE.replace('"[dɔɡ̊]"', '"[dɔb]"')
        self.core.write_text(text, encoding="utf-8")
        (self.decks / "zz" / "zz-phonetics.yaml").write_text(
            'schema: 1\nkind: "phonetics"\nid: "zz-phonetics"\nlanguage: "zz"\n'
            'variety: "v"\nrules:\n  - id: "zz-x"\n    pattern: \'o\'\n'
            '    replace: \'ɔ\'\n    source: \'s\'\n', encoding="utf-8")
        with mock.patch.dict(ip.VARIETIES, self.zz()):
            skipped: list[str] = []
            cov, _ = ip.renormalise("zz", self.decks, write=True, skipped=skipped)
        out = self.core.read_text(encoding="utf-8")
        self.assertEqual(cov.decks["zz-home"]["disagrees"], 1)
        self.assertEqual(len(skipped), 1)
        self.assertNotIn("[dɔb]", out)
        self.assertIn('phonetic_source: "rules"', out)


class ReplacingTheSource(unittest.TestCase):
    """A fill under `replace_rules` may also change the card's source, as
    when a Wiktionary card is given the rules' form instead."""

    def test_block_and_flow_cards_get_the_form_and_the_new_source(self) -> None:
        text = ('cards:\n'
                '  - {"id": "zz-1", "ipa": "kat", "phonetic": "[kab]", '
                '"phonetic_source": "wiktionary", "pos": "n"}\n'
                '  - id: "zz-2"\n    ipa: "kat"\n    phonetic: "[kab]"\n'
                '    phonetic_source: "wiktionary"\n')
        new, left = pp.patch(text, {"zz-1": ("[kat]", "rules"), "zz-2": ("[kat]", "rules")},
                             replace_rules=True, replace_source="wiktionary")
        self.assertEqual(left, {})
        self.assertEqual(new, text.replace("[kab]", "[kat]").replace('"wiktionary"', '"rules"'))

    def test_the_same_source_leaves_the_source_line_alone(self) -> None:
        text = 'cards:\n  - id: "zz-2"\n    ipa: "kat"\n    phonetic: "[kab]"\n    phonetic_source: "wiktionary"\n'
        new, _ = pp.patch(text, {"zz-2": ("[kat]", "wiktionary")},
                          replace_rules=True, replace_source="wiktionary")
        self.assertEqual(new, text.replace("[kab]", "[kat]"))


class Aligning(Tree):
    """`align` pairs read the card's broad ipa in a run and in --renormalise."""

    ALIGN = (("s|\u0283", (("s", "\u0283"),)),)

    def zz(self):
        return {"zz": ip.Variety("Zed", align=self.ALIGN)}

    def test_a_run_aligns_the_imported_form_to_the_cards_broad_ipa(self) -> None:
        # CORE's card zz-0001 has ipa "kat"; give it a broad ipa with ʃ.
        text = self.core.read_text(encoding="utf-8").replace('ipa: "kat"', 'ipa: "kaʃ"')
        self.core.write_text(text, encoding="utf-8")
        with mock.patch.dict(ip.VARIETIES, self.zz()):
            _, fills = ip.run("zz", self.dump(entry("kat", sound("[ˈkas]"))),
                              self.decks, False)
        self.assertEqual(fills[self.core]["zz-0001"][0], "[ˈkaʃ]")

    def test_a_registry_align_entry_loads_and_a_bad_units_regex_names_the_language(self) -> None:
        reg = self.tmp / "r.yaml"
        reg.write_text('zz:\n  dump: Zed\n  variety:\n    name: "Zed"\n  normalise:\n'
                       '    - align: "s|ʃ"\n      map: { "s": "ʃ" }\n', encoding="utf-8")
        _, varieties = ip.load_registry(reg)
        self.assertEqual(varieties["zz"].normalised("[as]", "aʃ"), "[aʃ]")
        reg.write_text('zz:\n  dump: Zed\n  variety:\n    name: "Zed"\n  normalise:\n'
                       '    - align: "("\n      map: { "s": "ʃ" }\n', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "zz"):
            ip.load_registry(reg)


class Unwritable(Tree):
    """A card the patcher cannot write is counted and fails a --write run."""

    MIXED = ('schema: 1\n"id": "zz-mix"\n"part": "core"\n"kind": "vocab"\n'
             '"language": { "code": "zz", "iso639_3": "zzz", "name": "Zed", "script": "latin" }\n'
             '"license": "CC-BY-SA-4.0"\n"theme": "mix"\n"cards":\n'
             '  - id: "zz-0101"\n    "target": "mat"\n    "ipa": "mat"\n    "pos": "noun"\n')

    def setUp(self) -> None:
        super().setUp()
        (self.decks / "zz" / "zz-mix.yaml").write_text(self.MIXED, encoding="utf-8")
        self.mix = self.decks / "zz" / "zz-mix.yaml"
        (self.decks / "zz" / "zz-phonetics.yaml").write_text(
            'schema: 1\nkind: "phonetics"\nid: "zz-phonetics"\nlanguage: "zz"\n'
            'variety: "Zed"\nrules:\n  - id: "zz-r0"\n    pattern: \'t$\'\n'
            '    replace: \'t̚\'\n    source: "A source, 2000"\n', encoding="utf-8")

    def refuse(self):
        return mock.patch.object(pp, "patch", lambda text, fills, replace_rules=False, **kw: (
            text, {cid: "no ipa line" for cid in fills}))

    def test_the_mixed_file_is_now_written_and_nothing_is_unwritable(self) -> None:
        cov, _ = dp.run("zz", self.decks, write=True)
        self.assertEqual(cov.total().get(pp.UNWRITABLE, 0), 0)
        self.assertIn('"ipa": "mat"\n    "phonetic": "[mat̚]"\n    "phonetic_source": "rules"\n',
                      self.mix.read_text(encoding="utf-8"))
        self.assertEqual(dp.main(["derive", "zz", "--decks", str(self.decks), "--write"]), 0)

    def test_derive_counts_a_miss_in_its_own_row_with_and_without_write(self) -> None:
        for write in (False, True):
            with self.subTest(write=write), self.refuse():
                cov, _ = dp.run("zz", self.decks, write=write)
                self.assertEqual(cov.decks["zz-mix"], {pp.UNWRITABLE: 1})
                self.assertNotIn("filled", cov.decks["zz-mix"])
                self.assertIn(pp.UNWRITABLE, cov.render("zz", dp.OUTCOMES, title="t"))

    def test_derive_exits_1_under_write_and_0_without(self) -> None:
        args = ["derive", "zz", "--decks", str(self.decks)]
        with self.refuse():
            self.assertEqual(dp.main(args), 0)
            self.assertEqual(dp.main(args + ["--write"]), 1)

    def test_import_counts_a_miss_and_exits_1_under_write(self) -> None:
        dump = self.dump(entry("mat", sound("[kʰat]", note="Std")))
        variety = {"zz": ip.Variety("Zed standard", notes=frozenset({"Std"}))}
        with mock.patch.dict(ip.VARIETIES, variety), self.refuse():
            cov, _ = ip.run("zz", dump, self.decks, False)
            self.assertEqual(cov.decks["zz-mix"].get(pp.UNWRITABLE), 1)
            self.assertEqual(ip.main(["import", "zz", "--decks", str(self.decks),
                                      "--dump", str(dump)]), 0)
            self.assertEqual(ip.main(["import", "zz", "--decks", str(self.decks),
                                      "--dump", str(dump), "--write"]), 1)


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

    def seed_sources(self) -> None:
        """zz-0001 rules-sourced, zz-0003 wiktionary-sourced, zz-0005 with a
        phonetic and no source; zz-0004 has no ipa and no phonetic."""
        text = self.core.read_text(encoding="utf-8")
        text = text.replace(
            '    ipa: "kat"\n', '    ipa: "kat"\n    phonetic: "[kat̚]"\n'
            '    phonetic_source: "rules"\n')
        text = text.replace(
            '    ipa: "bat"\n', '    ipa: "bat"\n    phonetic: "[bat]"\n'
            '    phonetic_source: "wiktionary"\n')
        text = text.replace(
            '    ipa: "pen"\n', '    ipa: "pen"\n    phonetic: "[pen]"\n')
        self.core.write_text(text, encoding="utf-8")

    def test_rederive_updates_a_rules_card_when_the_rule_changed(self) -> None:
        self.seed_sources()
        self.write_rules(("t$", "t̪"))
        cov, _ = dp.run("zz", self.decks, write=True, rederive=True)
        text = self.core.read_text(encoding="utf-8")
        self.assertIn('    phonetic: "[kat̪]"\n    phonetic_source: "rules"\n', text)
        self.assertNotIn("[kat̚]", text)
        self.assertEqual(cov.decks["zz-home"]["rederived"], 1)

    def test_rederive_never_touches_wiktionary_or_unsourced_or_empty(self) -> None:
        self.seed_sources()
        before = self.core.read_text(encoding="utf-8")
        self.write_rules(("t$", "t̪"), ("n$", "ŋ"))
        dp.run("zz", self.decks, write=True, rederive=True, bracket_unchanged=True)
        after = self.core.read_text(encoding="utf-8")
        self.assertIn('    phonetic: "[bat]"\n    phonetic_source: "wiktionary"\n', after)
        self.assertIn('    ipa: "pen"\n    phonetic: "[pen]"\n    pos:', after)
        self.assertIn('    phonetic: "[dɔɡ̊]"\n    phonetic_source: "wiktionary"\n', after)
        card4 = after.split('id: "zz-0004"')[1].split('id: "zz-0005"')[0]
        self.assertNotIn("phonetic", card4)
        self.assertNotEqual(before, after)

    def test_without_rederive_a_rules_card_keeps_its_old_phonetic(self) -> None:
        self.seed_sources()
        self.write_rules(("t$", "t̪"))
        cov, _ = dp.run("zz", self.decks, write=True)
        text = self.core.read_text(encoding="utf-8")
        self.assertIn('    phonetic: "[kat̚]"\n', text)
        self.assertNotIn("rederived", {k for r in cov.decks.values() for k, v in r.items() if v})

    def test_rederive_is_a_no_op_without_write(self) -> None:
        self.seed_sources()
        before = self.core.read_text(encoding="utf-8")
        self.write_rules(("t$", "t̪"))
        _, fills = dp.run("zz", self.decks, write=False, rederive=True)
        self.assertEqual(fills[self.core]["zz-0001"], ("[kat̪]", "rules"))
        self.assertEqual(self.core.read_text(encoding="utf-8"), before)

    def test_rederive_leaves_a_now_unchanged_card_unless_bracket_unchanged(self) -> None:
        self.seed_sources()
        self.write_rules(("x$", "y"))
        dp.run("zz", self.decks, write=True, rederive=True)
        self.assertIn('"[kat̚]"', self.core.read_text(encoding="utf-8"))
        dp.run("zz", self.decks, write=True, rederive=True, bracket_unchanged=True)
        self.assertIn('    phonetic: "[kat]"\n    phonetic_source: "rules"\n',
                      self.core.read_text(encoding="utf-8"))

    def test_rederive_does_not_give_a_first_phonetic(self) -> None:
        self.write_rules(("t$", "t̪"))
        cov, fills = dp.run("zz", self.decks, write=True, rederive=True)
        self.assertEqual(self.core.read_text(encoding="utf-8"), CORE)
        self.assertEqual(fills, {})
        self.assertEqual(cov.decks["zz-home"]["no phonetic"], 4)

    def test_rederive_reads_an_unquoted_rules_source(self) -> None:
        self.seed_sources()
        text = self.core.read_text(encoding="utf-8").replace(
            'phonetic_source: "rules"', "phonetic_source: rules  # derived")
        self.core.write_text(text, encoding="utf-8")
        self.write_rules(("t$", "t̪"))
        dp.run("zz", self.decks, write=True, rederive=True)
        self.assertIn('    phonetic: "[kat̪]"\n    phonetic_source: rules',
                      self.core.read_text(encoding="utf-8"))

    def test_rederive_twice_changes_nothing_the_second_time(self) -> None:
        self.seed_sources()
        self.write_rules(("t$", "t̪"))
        dp.run("zz", self.decks, write=True, rederive=True)
        once = self.core.read_text(encoding="utf-8")
        cov, _ = dp.run("zz", self.decks, write=True, rederive=True)
        self.assertEqual(self.core.read_text(encoding="utf-8"), once)
        self.assertEqual(cov.decks["zz-home"].get("rederived", 0), 0)


class SpanishRuleKinds(unittest.TestCase):
    """The engine already supports the rule kinds of #1369, gaps 1 to 4,
    with no code change: a lookahead that crosses a word boundary, a rule
    placed after another that rewrote its context, and a rule that adds a
    diacritic. Fixture rules, so the test needs no deck data."""

    RULES = [
        ("es-n-palatal", r"n(?=[ ˈ]*(?:tʃ|ʝ))", "ɲ"),
        ("es-y-palatal-stop", r"(^ˈ?|[nlɲ][ ˈ]*)ʝ", r"\1ɟ͡ʝ"),
        ("es-n-dental", r"n(?=[ ˈ]*[tdθ])", "n̪"),
        ("es-l-dental", r"l(?=ˈ?[tdθ])", "l̪"),
        ("es-s-voiced", r"s(?=[ ˈ]*[bdɡβðɣmnɲlʝɾr])", "z"),
    ]

    def derive(self, ipa: str) -> str:
        import re
        rules = [dp.Rule(i, re.compile(p), r, "A source, 2000") for i, p, r in self.RULES]
        return dp.apply_rules(ipa, rules)

    def test_n_assimilates_across_a_word_boundary(self) -> None:
        self.assertEqual(self.derive("un ˈtʃiko"), "uɲ ˈtʃiko")
        self.assertEqual(self.derive("son ˈtodos"), "son̪ ˈtodos")

    def test_s_is_voiced_before_a_voiced_word(self) -> None:
        self.assertEqual(self.derive("es la ˈbase"), "ez la ˈbase")
        self.assertEqual(self.derive("es ˈkasa"), "es ˈkasa")

    def test_initial_or_post_n_l_palatal_becomes_the_affricate(self) -> None:
        self.assertEqual(self.derive("ˈʝo"), "ˈɟ͡ʝo")
        self.assertEqual(self.derive("en ˈʝo"), "eɲ ˈɟ͡ʝo")
        self.assertEqual(self.derive("ˈkonʝ"), "ˈkoɲɟ͡ʝ")
        self.assertEqual(self.derive("ˈkaʝe"), "ˈkaʝe")  # between vowels: stays

    def test_l_before_a_dental_is_dental_and_before_other_sounds_plain(self) -> None:
        self.assertEqual(self.derive("ˈalto"), "ˈal̪to")
        self.assertEqual(self.derive("ˈfalda"), "ˈfal̪da")
        self.assertEqual(self.derive("ˈalma"), "ˈalma")
        self.assertEqual(self.derive("el ˈtiempo"), "el ˈtiempo")  # across words: plain


class TheRulesFiles(unittest.TestCase):
    """The shipped rules, on words whose narrow form is well known."""

    def derive(self, lang: str, ipa: str) -> str:
        rules = dp.load_rules(ROOT / "decks" / lang / f"{lang}-phonetics.yaml").rules
        form, _ = dp.derive(ipa, rules)
        return form

    def test_spanish_nasals_stops_and_s(self) -> None:
        self.assertEqual(self.derive("es", "ˈtenɡo"), "[ˈt̪eŋɡo]")
        self.assertEqual(self.derive("es", "la ˈbota"), "[la ˈβot̪a]")
        self.assertEqual(self.derive("es", "ˈbeso"), "[ˈbeso]")
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
