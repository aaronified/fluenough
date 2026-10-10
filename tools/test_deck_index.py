#!/usr/bin/env python3
"""Tests for deck_index.py, which writes decks/index.json (#210).

Each test builds a throwaway repository with the tools copied in, and runs
the tool as a subprocess against it, as test_validate_decks.py does: the
tool reads decks/ beside itself, never the working directory's.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TOOLS = REPO / "tools"
SAMPLE_DECK = REPO / "tools" / "fixtures" / "index" / "es-en-core-100.yaml"
B1 = TOOLS / "fixtures" / "b1" / "zz"


class DeckIndex(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        (self.tmp / "tools").mkdir()
        for name in ("validate_decks.py", "deck_index.py"):
            shutil.copy(TOOLS / name, self.tmp / "tools" / name)
        shutil.copytree(REPO / "assets" / "pictures", self.tmp / "assets" / "pictures")
        (self.tmp / "assets" / "languages.yaml").write_text(
            'schema: 1\nkind: languages\nlanguages:\n'
            '  - { code: es, iso639_3: spa, name: "Spanish", own_name: "Español" }\n',
            encoding="utf-8")
        es = self.tmp / "decks" / "es"
        es.mkdir(parents=True)
        shutil.copy(SAMPLE_DECK, es)
        (es / "es-path.yaml").write_text(
            "schema: 1\nkind: path\nid: es-path\nlanguage: es\n"
            "units:\n  - [es-core-100]\n", encoding="utf-8")
        (self.tmp / "decks" / "themes.yaml").write_text(
            "schema: 1\nkind: themes\nthemes:\n  - { id: market, name: Market }\n",
            encoding="utf-8")

    def run_tool(self, *args: str, cwd: Path | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(self.tmp / "tools" / "deck_index.py"), *args],
            cwd=cwd or self.tmp, capture_output=True, text=True, check=False)

    def index(self) -> dict:
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads((self.tmp / "decks" / "index.json").read_text(encoding="utf-8"))

    def language(self, index: dict, code: str) -> dict:
        return next(lang for lang in index["languages"] if lang["code"] == code)

    def test_lists_each_language_with_its_files(self) -> None:
        index = self.index()
        self.assertEqual(index["version"], 1)
        self.assertEqual(index["schema"], 1)
        es = self.language(index, "es")
        self.assertEqual(es["name"], "Spanish")
        self.assertEqual(es["own_name"], "Español")
        self.assertEqual(es["natives"], [{"code": "en", "name": "English"}])
        self.assertEqual(es["path"], ["es-core-100"])
        paths = [f["path"] for f in es["files"]]
        self.assertEqual(paths, ["decks/es/es-en-core-100.yaml", "decks/es/es-path.yaml"])
        deck = es["files"][0]
        data = SAMPLE_DECK.read_bytes()
        self.assertEqual(deck["sha256"], hashlib.sha256(data).hexdigest())
        self.assertEqual(deck["size"], len(data))
        self.assertEqual(deck["schema"], 1)
        self.assertEqual(deck["kind"], "vocab")
        self.assertEqual(deck["native"], "en")
        self.assertEqual(deck["deck"], "es-core-100")
        path = es["files"][1]
        self.assertEqual(path["kind"], "path")
        self.assertNotIn("deck", path)
        self.assertNotIn("native", path)
        self.assertEqual(es["size"], sum(f["size"] for f in es["files"]))

    def test_the_theme_list_stays_bundled(self) -> None:
        index = self.index()
        self.assertEqual(index["bundled"], ["decks/themes.yaml"])
        every = [f["path"] for lang in index["languages"] for f in lang["files"]]
        self.assertNotIn("decks/themes.yaml", every)

    def test_a_hidden_language_is_left_out(self) -> None:
        shutil.copytree(REPO / "decks" / "ja", self.tmp / "decks" / "ja")
        codes = [lang["code"] for lang in self.index()["languages"]]
        self.assertNotIn("ja", codes)

    def test_a_core_and_its_layers(self) -> None:
        shutil.copytree(B1, self.tmp / "decks" / "zz")
        zz = self.language(self.index(), "zz")
        files = {f["path"]: f for f in zz["files"]}
        core = files["decks/zz/zz-home.yaml"]
        self.assertEqual(core["part"], "core")
        self.assertEqual(core["deck"], "zz-home")
        self.assertNotIn("native", core)
        layer = files["decks/zz/en/zz-en-home.yaml"]
        self.assertEqual(layer["kind"], "layer")
        self.assertEqual(layer["native"], "en")
        self.assertEqual(layer["deck"], "zz-home")
        self.assertEqual(zz["natives"], [{"code": "en", "name": "English"}])

    def test_units_carry_their_planned_and_counted_words(self) -> None:
        shutil.copytree(B1, self.tmp / "decks" / "zz")
        zz = self.language(self.index(), "zz")
        units = zz["units"]
        self.assertTrue(any("milestone" in u for u in units))
        written = [u for u in units if "zz-home" in u["decks"]]
        self.assertEqual(len(written), 1)
        self.assertIn("en", written[0]["has"])
        self.assertGreater(written[0]["has"]["en"], 0)
        self.assertTrue(all(u.get("planned") for u in units if not u["decks"]))

    def test_one_file_to_a_line(self) -> None:
        self.index()
        text = (self.tmp / "decks" / "index.json").read_text(encoding="utf-8")
        lines = [line for line in text.splitlines() if '"sha256"' in line]
        self.assertEqual(len(lines), 2)

    def test_check_says_whether_it_is_current(self) -> None:
        self.assertEqual(self.run_tool("--check").returncode, 1)
        self.index()
        self.assertEqual(self.run_tool("--check").returncode, 0)
        # Written twice, it is the same: the check compares text.
        before = (self.tmp / "decks" / "index.json").read_bytes()
        self.index()
        self.assertEqual((self.tmp / "decks" / "index.json").read_bytes(), before)
        deck = self.tmp / "decks" / "es" / "es-en-core-100.yaml"
        deck.write_text(deck.read_text(encoding="utf-8") + "\n", encoding="utf-8")
        result = self.run_tool("--check", cwd=self.tmp.parent)
        self.assertEqual(result.returncode, 1)
        self.assertIn("out of date", result.stdout)

    def test_bad_arguments(self) -> None:
        self.assertEqual(self.run_tool("--wrong").returncode, 2)


if __name__ == "__main__":
    unittest.main()
