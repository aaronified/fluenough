"""Tests for tools/tok_sitelen.py: Toki Pona in sitelen pona (ADR-0055)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tok_sitelen as ts  # noqa: E402
import validate_decks as vd  # noqa: E402

REPO = Path(__file__).resolve().parent.parent

BLOCK = '''"schema": 1
"id": "tok-things"
"part": "core"
"kind": "vocab"
"language":
  "code": "tok"
  "iso639_3": "tok"
  "name": "Toki Pona"
  "script": "latin"
  "icon": "Tp"
"license": "CC-BY-SA-4.0"
"cards":
- "id": "tok-0001"
  "target": "toki"
  "examples":
  - "target": "jan Ali li toki."
    "ipa": "x"
'''

FLOW = '''schema: 1
id: "tok-x"
part: "core"
kind: "vocab"
language: { code: "tok", iso639_3: "tok", name: "Toki Pona", script: "latin", icon: "Tp" }
license: "CC-BY-SA-4.0"
cards:
  - id: "tok-0002"
    target: "pona"
    examples:
      - { target: "mi pona.", ipa: "x", bases: [{ word: "mi", ref: "tok-0003" }] }
'''


def g(word: str) -> str:
    return chr(ts.WORDS[word])


class Conversion(unittest.TestCase):
    def test_a_word_is_its_registry_glyph(self) -> None:
        self.assertEqual(ts.sitelen_pona("toki"), chr(0xF196C))
        self.assertEqual(ts.sitelen_pona("a"), chr(0xF1900))
        self.assertEqual(ts.sitelen_pona("ale"), ts.sitelen_pona("ali"))

    def test_words_are_spaced_and_punctuation_stays(self) -> None:
        self.assertEqual(ts.sitelen_pona("mi toki, sina pona!"),
                         f"{g('mi')} {g('toki')}, {g('sina')} {g('pona')}!")
        self.assertEqual(ts.sitelen_pona("ni li pona ala?"),
                         f"{g('ni')} {g('li')} {g('pona')} {g('ala')}?")

    def test_a_name_is_in_a_cartouche(self) -> None:
        name = ts.sitelen_pona("jan Ali.")
        self.assertEqual(name, g("jan") + " " + chr(0xF1990) + g("akesi") + g("lipu")
                         + g("ijo") + chr(0xF1991) + ".")

    def test_an_unknown_word_or_letter_stops_the_tool(self) -> None:
        with self.assertRaises(ts.UnknownWord):
            ts.sitelen_pona("mi lukin e zzz")
        with self.assertRaises(ts.UnknownWord):
            ts.sitelen_pona("jan Bob")

    def test_every_glyph_is_in_the_registry_block(self) -> None:
        for word, code in ts.WORDS.items():
            with self.subTest(word=word):
                self.assertTrue(0xF1900 <= code <= 0xF19FF)
        # pu's 120 words and ku suli's 17 are F1900 to F1988, no code twice but ali/ale.
        main = {c for c in ts.WORDS.values() if c <= 0xF1988}
        self.assertEqual(len(main), 137)

    def test_the_letters_are_toki_pona_words(self) -> None:
        for letter, word in ts.LETTERS.items():
            self.assertTrue(word.startswith(letter))
            self.assertIn(word, ts.WORDS)
        self.assertEqual(len(ts.LETTERS), 14)


class Files(unittest.TestCase):
    def run_on(self, text: str) -> str:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "tok-x.yaml"
            path.write_text(text, encoding="utf-8")
            self.assertGreater(ts.convert_file(path), 0)
            out = path.read_text(encoding="utf-8")
            # A second run changes nothing.
            self.assertEqual(ts.convert_file(path), 0)
            self.assertEqual(path.read_text(encoding="utf-8"), out)
            return out

    def test_block_style_gets_the_spelling_on_card_and_example(self) -> None:
        out = self.run_on(BLOCK)
        self.assertIn('  "scripts": ["latin", "sitelen_pona"]', out)
        self.assertIn(f'  "target_scripts":\n    "sitelen_pona": "{g("toki")}"', out)
        self.assertIn('    "target_scripts":\n      "sitelen_pona": "', out)
        self.assertIn(chr(0xF1990), out)

    def test_flow_style_gets_the_spelling_too(self) -> None:
        out = self.run_on(FLOW)
        self.assertIn('script: "latin", scripts: ["latin", "sitelen_pona"],', out)
        self.assertIn(f'target_scripts: {{ sitelen_pona: "{g("mi")} {g("pona")}." }}', out)

    def test_the_converted_deck_passes_the_validator_checks(self) -> None:
        for text in (BLOCK, FLOW):
            out = self.run_on(text)
            import yaml
            raw = yaml.safe_load(out)
            scripts = raw["language"]["scripts"]
            for card in raw["cards"]:
                r = vd.Report(Path("x.yaml"))
                vd._check_target_scripts(r, "card", card["target_scripts"],
                                         card["target"], scripts)
                for ex in card["examples"]:
                    vd._check_target_scripts(r, "ex", ex["target_scripts"],
                                             ex["target"], scripts)
                self.assertEqual(r.errors, [], r.errors)

    def test_a_latin_letter_left_in_the_spelling_is_refused(self) -> None:
        r = vd.Report(Path("x.yaml"))
        vd._check_target_scripts(r, "card", {"sitelen_pona": "mi"}, "mi", ["latin", "sitelen_pona"])
        self.assertTrue(r.errors)

    def test_other_files_are_left_alone(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "tok-reading.yaml"
            path.write_text('"schema": 1\n"kind": "reading"\n"language":\n  "code": "tok"\n',
                            encoding="utf-8")
            self.assertEqual(ts.convert_file(path), 0)


PATH = """schema: 1
kind: "path"
id: "tok-path"
language: "tok"
alphabet: ["tok-script-sitelen-pona"]
units:
  - ["tok-script-sitelen-pona"]
  - decks: ["tok-b", "tok-a", "*"]
    words: 3
"""

CORE_A = """schema: 1
id: "tok-a"
part: "core"
kind: "vocab"
language: { code: "tok", iso639_3: "tok", name: "Toki Pona", script: "latin", icon: "Tp" }
cards:
  - { id: "tok-0007", target: "toki", ipa: "ˈtoki", pos: "noun" }
  - { id: "tok-0008", target: "toki pona", ipa: "x", pos: "phrase" }
"""

CORE_B = """schema: 1
id: "tok-b"
part: "core"
kind: "vocab"
language: { code: "tok", iso639_3: "tok", name: "Toki Pona", script: "latin", icon: "Tp" }
cards:
  - { id: "tok-0003", target: "mi", ipa: "mi", pos: "pronoun" }
  - { id: "tok-0004", target: "toki", ipa: "ˈtoki", pos: "noun" }
"""

LAYER = """schema: 1
id: "tok-en-%s"
kind: "layer"
core: "tok-%s"
native: { code: "en", iso639_3: "eng", name: "English" }
cards:
%s
"""


class GlyphDeck(unittest.TestCase):
    def tree(self, tmp: str) -> Path:
        root = Path(tmp) / "decks" / "tok"
        (root / "en").mkdir(parents=True)
        (root / "tok-path.yaml").write_text(PATH, encoding="utf-8")
        for name, core, cards in (
                ("a", CORE_A, '  "tok-0007":\n    native: "language"\n  "tok-0008":\n    native: "x"'),
                ("b", CORE_B, '  "tok-0003":\n    native: "I"\n  "tok-0004":\n    native: "again"')):
            (root / f"tok-{name}.yaml").write_text(core, encoding="utf-8")
            (root / "en" / f"tok-en-{name}.yaml").write_text(
                LAYER % (name, name, cards), encoding="utf-8")
        return root

    def test_one_card_per_word_in_the_order_the_path_meets_them(self) -> None:
        import yaml
        with tempfile.TemporaryDirectory() as tmp:
            root = self.tree(tmp)
            core, layer = ts.glyph_deck(root)
            deck = yaml.safe_load(core)
            cards = deck["cards"]
            # tok-b comes first on the path: mi, then toki; the phrase and
            # the repeated word are left out.
            self.assertEqual([c["target_scripts"]["latin"] for c in cards], ["mi", "toki"])
            self.assertEqual([c["target"] for c in cards], [g("mi"), g("toki")])
            self.assertEqual(deck["language"]["script"], "sitelen_pona")
            self.assertEqual(deck["language"]["scripts"], ["sitelen_pona", "latin"])
            self.assertEqual(cards[1]["ipa"], "ˈtoki")
            self.assertEqual(cards[0]["pos"], "letter")
            self.assertEqual(cards[0]["modes"], ["listening", "speaking"])
            ids = [c["id"] for c in cards]
            self.assertEqual(ids, ["tok-0009", "tok-0010"], "after the largest id")
            meanings = yaml.safe_load(layer)["cards"]
            self.assertEqual(meanings[ids[0]]["native"], "I")
            # A repeated word keeps the first card the path meets.
            self.assertEqual(meanings[ids[1]]["native"], "again")

    def test_ids_are_kept_when_it_is_run_again(self) -> None:
        import yaml
        with tempfile.TemporaryDirectory() as tmp:
            root = self.tree(tmp)
            core, layer = ts.glyph_deck(root)
            (root / f"{ts.GLYPH_DECK}.yaml").write_text(core, encoding="utf-8")
            (root / "en" / f"{ts.GLYPH_LAYER}.yaml").write_text(layer, encoding="utf-8")
            # A word added to an earlier deck takes a new id; the others keep theirs.
            (root / "tok-a.yaml").write_text(
                CORE_A + '  - { id: "tok-0011", target: "pona", ipa: "ˈpona", pos: "adjective" }\n',
                encoding="utf-8")
            (root / "en" / "tok-en-a.yaml").write_text(
                LAYER % ("a", "a", '  "tok-0007":\n    native: "language"\n  "tok-0011":\n    native: "good"'),
                encoding="utf-8")
            core2, _ = ts.glyph_deck(root)
            ids = {c["target_scripts"]["latin"]: c["id"] for c in yaml.safe_load(core2)["cards"]}
            self.assertEqual(ids, {"mi": "tok-0009", "toki": "tok-0010", "pona": "tok-0012"})


class Languages(unittest.TestCase):
    def test_toki_pona_offers_its_two_scripts(self) -> None:
        import yaml
        langs = yaml.safe_load((REPO / "assets" / "languages.yaml").read_text("utf-8"))["languages"]
        tok = next(e for e in langs if e["code"] == "tok")
        self.assertEqual(tok["scripts"], ["latin", "sitelen_pona"])
        self.assertEqual(set(tok["script_can_read"]), {"latin", "sitelen_pona"})
        self.assertIn("scripts_question", tok)

    def test_the_font_is_registered(self) -> None:
        import deck_index
        family, name = deck_index.FONTS["sitelen_pona"]
        self.assertEqual(name, "SitelenSeliKiwen.ttf")
        self.assertIn("sitelen", family)


if __name__ == "__main__":
    unittest.main()
