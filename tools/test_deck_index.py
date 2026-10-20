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
        for name in ("validate_decks.py", "deck_index.py", "rater_codes.py"):
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

    def test_recordings_are_listed_under_media(self) -> None:
        # #518: a card's recording ships with the deck; the index lists it
        # apart from the deck files, and the language's size counts it.
        audio = self.tmp / "decks" / "es" / "audio"
        audio.mkdir()
        (audio / "es-0001.opus").write_bytes(b"OggS-not-really")
        index = self.index()
        es = self.language(index, "es")
        self.assertEqual(es["media"], [{
            "path": "decks/es/audio/es-0001.opus", "size": 15,
            "sha256": hashlib.sha256(b"OggS-not-really").hexdigest(),
            "kind": "audio"}])
        self.assertNotIn("decks/es/audio/es-0001.opus",
                         [f["path"] for f in es["files"]])
        self.assertEqual(es["size"], sum(f["size"] for f in es["files"]) + 15)
        text = (self.tmp / "decks" / "index.json").read_text(encoding="utf-8")
        self.assertIn('\n        {"kind": "audio", "path": "decks/es/audio/es-0001.opus"',
                      text)

    def test_images_are_listed_under_media(self) -> None:
        # #523: a card's image ships with the deck as a recording does.
        images = self.tmp / "decks" / "es" / "images"
        images.mkdir()
        (images / "es-0001.webp").write_bytes(b"RIFF")
        es = self.language(self.index(), "es")
        self.assertEqual(es["media"], [{
            "path": "decks/es/images/es-0001.webp", "size": 4,
            "sha256": hashlib.sha256(b"RIFF").hexdigest(), "kind": "image"}])
        self.assertEqual(es["size"], sum(f["size"] for f in es["files"]) + 4)

    def test_no_media_key_without_media(self) -> None:
        self.assertNotIn("media", self.language(self.index(), "es"))

    def test_a_guide_of_another_script_is_listed_apart(self) -> None:
        # ADR-0016: a released app reads only `<code>-script` as a script
        # guide and rejects any other id, so the guides of a language's other
        # scripts are listed under `script_guides`, which it passes by, as it
        # does `media`; the default guide stays in `files`.
        es = self.tmp / "decks" / "es"
        (es / "en").mkdir()
        (es / "es-script.yaml").write_text(
            'schema: 1\nkind: "script"\nid: "es-script"\n', encoding="utf-8")
        (es / "es-arabic-script.yaml").write_text(
            'schema: 1\nkind: "script"\npart: "core"\nid: "es-arabic-script"\n',
            encoding="utf-8")
        (es / "en" / "es-en-arabic-script.yaml").write_text(
            'schema: 1\nid: "es-en-arabic-script"\nkind: "layer"\n'
            'core: "es-arabic-script"\n', encoding="utf-8")
        (es / "en" / "es-en-script.yaml").write_text(
            'schema: 1\nid: "es-en-script"\nkind: "layer"\ncore: "es-script"\n',
            encoding="utf-8")
        lang = self.language(self.index(), "es")
        self.assertEqual([f["path"] for f in lang["script_guides"]],
                         ["decks/es/es-arabic-script.yaml",
                          "decks/es/en/es-en-arabic-script.yaml"])
        listed = [f["path"] for f in lang["files"]]
        self.assertIn("decks/es/es-script.yaml", listed)
        self.assertIn("decks/es/en/es-en-script.yaml", listed)
        self.assertFalse(any("arabic" in path for path in listed))
        every = lang["files"] + lang["script_guides"]
        self.assertEqual(lang["size"], sum(f["size"] for f in every))
        text = (self.tmp / "decks" / "index.json").read_text(encoding="utf-8")
        self.assertLess(text.index('"files"'), text.index('"script_guides"'))

    def test_no_script_guides_key_without_one(self) -> None:
        self.assertNotIn("script_guides", self.language(self.index(), "es"))

    def add_font(self, script: str, name: str, data: bytes) -> None:
        folder = self.tmp / "decks" / "fonts" / script
        folder.mkdir(parents=True)
        (folder / name).write_bytes(data)
        (folder / "OFL.txt").write_text("licence", encoding="utf-8")

    def spanish_in_scripts(self, scripts: str) -> None:
        (self.tmp / "assets" / "languages.yaml").write_text(
            'schema: 1\nkind: languages\nlanguages:\n'
            '  - { code: es, iso639_3: spa, name: "Spanish", own_name: "Español",'
            f' scripts: [{scripts}] }}\n', encoding="utf-8")

    def test_fonts_are_listed_per_language_apart_from_files(self) -> None:
        # ADR-0042: the font of each script a language's decks are shown
        # in, under a key of its own, which the released app ignores.
        self.spanish_in_scripts('"latin", "devanagari", "perso_arabic"')
        self.add_font("devanagari", "NotoSansDevanagari.ttf", b"deva-font")
        self.add_font("perso_arabic", "NotoNastaliqUrdu.ttf", b"nast")
        index = self.index()
        es = self.language(index, "es")
        self.assertEqual(es["fonts"], [{
            "path": "decks/fonts/devanagari/NotoSansDevanagari.ttf",
            "size": 9, "sha256": hashlib.sha256(b"deva-font").hexdigest(),
            "script": "devanagari", "family": "Noto Sans Devanagari"}, {
            "path": "decks/fonts/perso_arabic/NotoNastaliqUrdu.ttf",
            "size": 4, "sha256": hashlib.sha256(b"nast").hexdigest(),
            "script": "perso_arabic", "family": "Noto Nastaliq Urdu"}])
        listed = [f["path"] for f in es["files"] + es.get("media", [])]
        self.assertFalse([p for p in listed if "fonts" in p])
        # The language's size is what the released app shows: no fonts in it.
        self.assertEqual(es["size"], sum(f["size"] for f in es["files"]))
        self.assertEqual([lang["code"] for lang in index["languages"]], ["es"])
        text = (self.tmp / "decks" / "index.json").read_text(encoding="utf-8")
        self.assertIn('\n      "fonts": [\n        {"family": "Noto Sans Devanagari"',
                      text)

    def test_a_language_with_no_font_script_has_no_fonts(self) -> None:
        # Latin has no font in the table, so even with a file under fonts/
        # nothing is listed; a script with a font but no file is passed by.
        self.add_font("latin", "NotoSans.ttf", b"x")
        self.spanish_in_scripts('"latin", "telugu"')
        self.assertNotIn("fonts", self.language(self.index(), "es"))

    def test_the_fonts_folder_is_not_a_language(self) -> None:
        self.add_font("devanagari", "NotoSansDevanagari.ttf", b"deva-font")
        codes = [lang["code"] for lang in self.index()["languages"]]
        self.assertNotIn("fonts", codes)

    def test_fonts_the_repository_holds(self) -> None:
        # Every font of the table is in decks/fonts/ with its licence and
        # under 2 MB, and the index lists it for a language that needs it.
        sys.path.insert(0, str(TOOLS))
        try:
            import deck_index
        finally:
            sys.path.remove(str(TOOLS))
        for script, (family, name) in deck_index.FONTS.items():
            folder = REPO / "decks" / "fonts" / script
            self.assertTrue((folder / name).is_file(), script)
            self.assertTrue((folder / "OFL.txt").is_file(), script)
            self.assertLess((folder / name).stat().st_size, 2 * 1024 * 1024)
            self.assertTrue(family.startswith("Noto "), family)
        index = json.loads((REPO / "decks" / "index.json").read_text(encoding="utf-8"))
        scripts = {
            lang["code"]: [f["script"] for f in lang.get("fonts", [])]
            for lang in index["languages"]}
        self.assertEqual(scripts["te"], ["telugu"])
        self.assertEqual(scripts["hi"], ["devanagari", "perso_arabic"])
        self.assertEqual(scripts["as"], ["bengali"])
        self.assertEqual(scripts["es"], [])

    def test_the_theme_list_stays_bundled(self) -> None:
        index = self.index()
        self.assertEqual(index["bundled"], ["decks/themes.yaml"])
        every = [f["path"] for lang in index["languages"] for f in lang["files"]]
        self.assertNotIn("decks/themes.yaml", every)

    def test_a_hidden_language_is_left_out(self) -> None:
        tool = self.tmp / "tools" / "deck_index.py"
        text = tool.read_text(encoding="utf-8")
        tool.write_text(text.replace("HIDDEN: set[str] = set()",
                                     'HIDDEN: set[str] = {"ja"}'),
                        encoding="utf-8")
        shutil.copytree(REPO / "decks" / "ja", self.tmp / "decks" / "ja")
        codes = [lang["code"] for lang in self.index()["languages"]]
        self.assertNotIn("ja", codes)

    def test_a_language_with_no_written_deck_is_left_out(self) -> None:
        zz = self.tmp / "decks" / "zz"
        zz.mkdir()
        (zz / "zz-path.yaml").write_text(
            "schema: 1\nkind: path\nid: zz-path\nlanguage: zz\n"
            "units:\n  - planned: { id: \"zz-health\", theme: \"health\", words: 60 }\n", encoding="utf-8")
        codes = [lang["code"] for lang in self.index()["languages"]]
        self.assertNotIn("zz", codes)
        self.assertIn("es", codes)

    def test_a_language_with_one_written_deck_is_listed(self) -> None:
        shutil.copytree(B1, self.tmp / "decks" / "zz")
        codes = [lang["code"] for lang in self.index()["languages"]]
        self.assertIn("zz", codes)

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

    def test_a_file_with_proposals_counts_them(self) -> None:
        # ADR-0038: reviewers' proposals, which learners never see.
        shutil.copytree(B1, self.tmp / "decks" / "zz")
        layer = self.tmp / "decks" / "zz" / "en" / "zz-en-home.yaml"
        sys.path.insert(0, str(TOOLS))
        import proposals
        p = proposals.Proposal("zz-9004", "native", "mother", "mum",
                               "FL-7K3M-Q9TD-6", "2026-10-09")
        text = layer.read_text(encoding="utf-8").replace(
            '    native: "mother"\n',
            f'    native: "mother"\n    proposed:\n      {p.line()}\n')
        layer.write_text(text, encoding="utf-8")
        files = {f["path"]: f for f in self.language(self.index(), "zz")["files"]}
        self.assertEqual(files["decks/zz/en/zz-en-home.yaml"]["proposed"], 1)
        self.assertNotIn("proposed", files["decks/zz/zz-home.yaml"])

    def test_the_content_hash_leaves_proposals_out(self) -> None:
        # #444: a proposal changes the file's sha256, which every download
        # is checked against, but not its content_sha256, which decides
        # whether a learner is offered an update.
        shutil.copytree(B1, self.tmp / "decks" / "zz")
        layer = self.tmp / "decks" / "zz" / "en" / "zz-en-home.yaml"
        rel = "decks/zz/en/zz-en-home.yaml"
        original = layer.read_bytes()
        before = {f["path"]: f for f in self.language(self.index(), "zz")["files"]}[rel]
        self.assertEqual(before["content_sha256"], before["sha256"])
        sys.path.insert(0, str(TOOLS))
        import proposals
        p = proposals.Proposal("zz-9004", "native", "mother", "mum",
                               "FL-7K3M-Q9TD-6", "2026-10-09")
        layer.write_text(original.decode("utf-8").replace(
            '    native: "mother"\n',
            f'    native: "mother"\n    proposed:\n      {p.line()}\n'),
            encoding="utf-8")
        proposed = {f["path"]: f for f in self.language(self.index(), "zz")["files"]}[rel]
        self.assertNotEqual(proposed["sha256"], before["sha256"])
        self.assertNotEqual(proposed["size"], before["size"])
        self.assertEqual(proposed["content_sha256"], before["content_sha256"])
        # A change a learner sees changes it.
        layer.write_text(layer.read_text(encoding="utf-8").replace(
            '    native: "mother"\n', '    native: "mum"\n'), encoding="utf-8")
        changed = {f["path"]: f for f in self.language(self.index(), "zz")["files"]}[rel]
        self.assertNotEqual(changed["content_sha256"], before["content_sha256"])

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


class ContentBytes(unittest.TestCase):
    """deck_index.content_bytes: a deck file as a learner sees it (#444)."""

    @classmethod
    def setUpClass(cls) -> None:
        sys.path.insert(0, str(TOOLS))
        import deck_index
        cls.content = staticmethod(deck_index.content_bytes)

    BASE = (
        'cards:\n'
        '  - id: "zz-0001"\n'
        '    target: "a"\n'
        '    native: "one"\n'
        '\n'
        '  - id: "zz-0002"\n'
        '    target: "b"\n'
        '    native: "two"\n'
    )

    def test_a_file_without_proposals_is_unchanged(self) -> None:
        data = self.BASE.encode()
        self.assertEqual(self.content(data), data)

    def test_proposed_lines_are_left_out(self) -> None:
        line = ('{ id: "3f9c0a1b2d", field: "native", now: "one", text: "1", '
                'by: "FL-7K3M-Q9TD-6", date: "2026-10-09" }')
        text = self.BASE.replace(
            '    native: "one"\n',
            f'    native: "one"\n    proposed:\n      - {line}\n      - {line}\n',
        ).replace(
            '    native: "two"\n',
            f'    native: "two"\n    proposed:\n      - {line}\n',
        )
        self.assertEqual(self.content(text.encode()), self.BASE.encode())

    def test_items_at_the_keys_own_indent_are_left_out(self) -> None:
        # YAML allows a list under a key at the key's own indent.
        line = '{ id: "3f9c0a1b2d", field: "native", text: "1" }'
        text = self.BASE.replace(
            '    native: "one"\n',
            f'    native: "one"\n    proposed:\n    - {line}\n    - {line}\n'
            '    notes: "kept"\n',
        )
        want = self.BASE.replace(
            '    native: "one"\n', '    native: "one"\n    notes: "kept"\n')
        self.assertEqual(self.content(text.encode()), want.encode())

    def test_only_proposals_go(self) -> None:
        # A field named like it, or text that says it, stays.
        data = ('cards:\n  - id: "zz-0001"\n    notes: "proposed: no"\n'
                '    proposed_by: "x"\n').encode()
        self.assertEqual(self.content(data), data)

    def test_crlf_line_ends(self) -> None:
        line = '      - { id: "3f9c0a1b2d", field: "native" }\r\n'
        base = self.BASE.replace("\n", "\r\n")
        text = base.replace('    native: "one"\r\n',
                            f'    native: "one"\r\n    proposed:\r\n{line}')
        self.assertEqual(self.content(text.encode()), base.encode())


if __name__ == "__main__":
    unittest.main()
