#!/usr/bin/env python3
"""Tests for deck_index.py, which writes decks/index.json (#210).

Each test builds a throwaway repository with the tools copied in, and runs
the tool as a subprocess against it, as test_validate_decks.py does: the
tool reads decks/ beside itself, never the working directory's.
"""

from __future__ import annotations

import hashlib
import json
import os
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
        for name in ("validate_decks.py", "deck_index.py", "rater_codes.py",
                     "offensive_alikes.py", "pick_warning.py"):
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

    def _lists_each_language_with_its_files(self) -> None:
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

    def _recordings_are_listed_under_media(self) -> None:
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

    def _images_are_listed_under_media(self) -> None:
        # #523: a card's image ships with the deck as a recording does.
        images = self.tmp / "decks" / "es" / "images"
        images.mkdir()
        (images / "es-0001.webp").write_bytes(b"RIFF")
        es = self.language(self.index(), "es")
        self.assertEqual(es["media"], [{
            "path": "decks/es/images/es-0001.webp", "size": 4,
            "sha256": hashlib.sha256(b"RIFF").hexdigest(), "kind": "image"}])
        self.assertEqual(es["size"], sum(f["size"] for f in es["files"]) + 4)


    def _the_situations_file_is_listed_apart_from_files(self) -> None:
        # #724: the released app has no case for `kind: situations`, so the
        # file is listed under `situations`, which it passes by.
        es = self.tmp / "decks" / "es"
        (es / "es-situations.yaml").write_text(
            'schema: 1\nid: "es-situations"\nkind: "situations"\n',
            encoding="utf-8")
        lang = self.language(self.index(), "es")
        self.assertEqual([f["path"] for f in lang["situations"]],
                         ["decks/es/es-situations.yaml"])
        self.assertEqual(lang["situations"][0]["kind"], "situations")
        self.assertFalse(any(f["kind"] == "situations" for f in lang["files"]))
        every = lang["files"] + lang["situations"]
        self.assertEqual(lang["size"], sum(f["size"] for f in every))

    def _a_guide_of_another_script_is_listed_apart(self) -> None:
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

    def _fonts_are_listed_per_language_apart_from_files(self) -> None:
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


    def _the_resources_file_is_listed_apart_from_files(self) -> None:
        # #832: a language's resources file is no deck, under a key of its
        # own that the released app ignores, and not in the language's size.
        text = ('schema: 1\nkind: "resources"\nid: "es-resources"\n'
                'language: "es"\nresources:\n  - id: "es-res-x"\n'
                '    name: "X"\n    url: "https://example.org/"\n'
                '    kind: "site"\n    why: "A site."\n')
        (self.tmp / "decks" / "es" / "es-resources.yaml").write_text(
            text, encoding="utf-8")
        es = self.language(self.index(), "es")
        self.assertEqual([r["path"] for r in es["resources"]],
                         ["decks/es/es-resources.yaml"])
        self.assertEqual(es["resources"][0]["kind"], "resources")
        self.assertNotIn("decks/es/es-resources.yaml",
                         [f["path"] for f in es["files"]])
        self.assertEqual(es["size"], sum(f["size"] for f in es["files"]))

    def _the_phonetic_rules_are_not_listed(self) -> None:
        # The rules are for tools/derive_phonetic.py alone: the app never
        # fetches them, so they are in no list and not in the size.
        text = ('schema: 1\nkind: "phonetics"\nid: "es-phonetics"\n'
                'language: "es"\nvariety: "Standard"\nrules:\n'
                '  - id: "es-n-velar"\n    pattern: "n"\n    replace: "n"\n'
                '    source: "A source, 2000"\n')
        (self.tmp / "decks" / "es" / "es-phonetics.yaml").write_text(
            text, encoding="utf-8")
        es = self.language(self.index(), "es")
        listed = [f["path"] for f in es["files"]]
        self.assertNotIn("decks/es/es-phonetics.yaml", listed)
        self.assertNotIn("resources", es)
        self.assertEqual(es["size"], sum(f["size"] for f in es["files"]))

    def _the_fonts_folder_is_not_a_language(self) -> None:
        self.add_font("devanagari", "NotoSansDevanagari.ttf", b"deva-font")
        codes = [lang["code"] for lang in self.index()["languages"]]
        self.assertNotIn("fonts", codes)


    def _a_hidden_language_is_left_out(self) -> None:
        tool = self.tmp / "tools" / "deck_index.py"
        text = tool.read_text(encoding="utf-8")
        tool.write_text(text.replace("HIDDEN: set[str] = set()",
                                     'HIDDEN: set[str] = {"ja"}'),
                        encoding="utf-8")
        shutil.copytree(REPO / "decks" / "ja", self.tmp / "decks" / "ja")
        codes = [lang["code"] for lang in self.index()["languages"]]
        self.assertNotIn("ja", codes)

    def _a_language_with_no_written_deck_is_left_out(self) -> None:
        zz = self.tmp / "decks" / "zz"
        zz.mkdir()
        (zz / "zz-path.yaml").write_text(
            "schema: 1\nkind: path\nid: zz-path\nlanguage: zz\n"
            "units:\n  - planned: { id: \"zz-health\", theme: \"health\", words: 60 }\n", encoding="utf-8")
        codes = [lang["code"] for lang in self.index()["languages"]]
        self.assertNotIn("zz", codes)
        self.assertIn("es", codes)

    def _a_language_with_one_written_deck_is_listed(self) -> None:
        shutil.copytree(B1, self.tmp / "decks" / "zz")
        codes = [lang["code"] for lang in self.index()["languages"]]
        self.assertIn("zz", codes)

    def _a_core_and_its_layers(self) -> None:
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

    def _a_file_with_proposals_counts_them(self) -> None:
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

    def _the_content_hash_leaves_proposals_out(self) -> None:
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


    def _one_file_to_a_line(self) -> None:
        self.index()
        text = (self.tmp / "decks" / "index.json").read_text(encoding="utf-8")
        lines = [line for line in text.splitlines() if '"sha256"' in line]
        self.assertEqual(len(lines), 2)

    def _check_says_whether_it_is_current(self) -> None:
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

    BADGE = ('<a href="#courses"><img src="https://img.shields.io/badge/'
             'languages-%s-C2621D" alt="%s languages"></a>')

    def readme(self) -> str:
        return (self.tmp / "README.md").read_text(encoding="utf-8")

    def _the_readme_badge_follows_the_language_count(self) -> None:
        (self.tmp / "README.md").write_text(
            "# App\n" + self.BADGE % (8, 8) + "\n", encoding="utf-8")
        self.index()
        self.assertEqual(self.readme(), "# App\n" + self.BADGE % (1, 1) + "\n")
        shutil.copytree(B1, self.tmp / "decks" / "zz")
        self.index()
        self.assertIn(self.BADGE % (2, 2), self.readme())

    def _the_readme_badge_does_not_count_an_ipa_course(self) -> None:
        shutil.copytree(B1, self.tmp / "decks" / "zz")
        # Every file of the course, since the index takes its script from one.
        for deck in (self.tmp / "decks" / "zz").rglob("*.yaml"):
            deck.write_text(deck.read_text(encoding="utf-8").replace(
                'script: "telugu"', 'script: "ipa"'), encoding="utf-8")
        (self.tmp / "README.md").write_text(self.BADGE % (8, 8), encoding="utf-8")
        codes = [lang["code"] for lang in self.index()["languages"]]
        self.assertIn("zz", codes)
        self.assertEqual(self.readme(), self.BADGE % (1, 1))

    def _a_missing_readme_or_badge_is_skipped(self) -> None:
        self.index()
        self.assertFalse((self.tmp / "README.md").exists())
        (self.tmp / "README.md").write_text("no badge\n", encoding="utf-8")
        self.index()
        self.assertEqual(self.readme(), "no badge\n")


    def test_lists_each_language_with_its_files(self) -> None:
        cases = (
            self._lists_each_language_with_its_files,
            self._a_core_and_its_layers,
            self._one_file_to_a_line,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()

    def test_media_guides_and_fonts_are_listed_apart(self) -> None:
        cases = (
            self._recordings_are_listed_under_media,
            self._images_are_listed_under_media,
            self._a_guide_of_another_script_is_listed_apart,
            self._fonts_are_listed_per_language_apart_from_files,
            self._the_resources_file_is_listed_apart_from_files,
            self._the_situations_file_is_listed_apart_from_files,
            self._the_phonetic_rules_are_not_listed,
            self._the_fonts_folder_is_not_a_language,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()

    def test_hidden_or_unwritten_languages_are_left_out(self) -> None:
        cases = (
            self._a_hidden_language_is_left_out,
            self._a_language_with_no_written_deck_is_left_out,
            self._a_language_with_one_written_deck_is_listed,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()

    def _a_file_without_proposals_is_unchanged(self) -> None:
        data = self.BASE.encode()
        self.assertEqual(self.content(data), data)

    def _proposed_lines_are_left_out(self) -> None:
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

    def _items_at_the_keys_own_indent_are_left_out(self) -> None:
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

    def _only_proposals_go(self) -> None:
        # A field named like it, or text that says it, stays.
        data = ('cards:\n  - id: "zz-0001"\n    notes: "proposed: no"\n'
                '    proposed_by: "x"\n').encode()
        self.assertEqual(self.content(data), data)

    def _crlf_line_ends(self) -> None:
        line = '      - { id: "3f9c0a1b2d", field: "native" }\r\n'
        base = self.BASE.replace("\n", "\r\n")
        text = base.replace('    native: "one"\r\n',
                            f'    native: "one"\r\n    proposed:\r\n{line}')
        self.assertEqual(self.content(text.encode()), base.encode())

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

    def test_the_content_hash_leaves_proposals_out(self) -> None:
        cases = (
            self._a_file_with_proposals_counts_them,
            self._the_content_hash_leaves_proposals_out,
            self._a_file_without_proposals_is_unchanged,
            self._proposed_lines_are_left_out,
            self._items_at_the_keys_own_indent_are_left_out,
            self._only_proposals_go,
            self._crlf_line_ends,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()

    def test_check_says_whether_it_is_current_and_the_badge_follows_the_count(self) -> None:
        cases = (
            self._check_says_whether_it_is_current,
            self._the_readme_badge_follows_the_language_count,
            self._the_readme_badge_does_not_count_an_ipa_course,
            self._a_missing_readme_or_badge_is_skipped,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


    # min_app (ADR-0052): the oldest app that can read a language or a file.

    def min_app(self, data: object) -> None:
        text = data if isinstance(data, str) else json.dumps(data)
        (self.tmp / "decks" / "min_app.json").write_text(text, encoding="utf-8")

    def test_min_app_is_written_to_the_language_and_to_a_file(self) -> None:
        self.min_app({"languages": {"es": "0.7.1"},
                      "files": {"decks/es/es-en-core-100.yaml": "0.7.2"}})
        es = self.language(self.index(), "es")
        self.assertEqual(es["min_app"], "0.7.1")
        by_path = {f["path"]: f for f in es["files"]}
        self.assertEqual(by_path["decks/es/es-en-core-100.yaml"]["min_app"], "0.7.2")
        self.assertNotIn("min_app", by_path["decks/es/es-path.yaml"])
        # One file to a line still: the key is on the file's own line.
        text = (self.tmp / "decks" / "index.json").read_text(encoding="utf-8")
        line = next(l for l in text.splitlines() if "es-en-core-100.yaml" in l)
        self.assertIn('"min_app": "0.7.2"', line)

    def test_without_min_app_the_index_has_no_such_key(self) -> None:
        for data in (None, {"languages": {}, "files": {}}):
            with self.subTest(data=data):
                path = self.tmp / "decks" / "min_app.json"
                path.unlink(missing_ok=True)
                if data is not None:
                    self.min_app(data)
                text = json.dumps(self.index())
                self.assertNotIn("min_app", text)

    def test_a_bad_min_app_file_fails_and_names_the_problem(self) -> None:
        cases = {
            "not json": "{nope",
            "not an object": "[]",
            "unknown key": {"langs": {}},
            "a version with a letter": {"languages": {"es": "0.7.x"}},
            "a two-part version": {"languages": {"es": "0.7"}},
            "a number": {"languages": {"es": 0.7}},
            "a language that is not listed": {"languages": {"pt": "0.7.1"}},
            "a file that is not listed": {"files": {"decks/es/nope.yaml": "0.7.1"}},
            "a media file, which the language covers": {
                "files": {"decks/es/audio/es-0001.opus": "0.7.1"}},
        }
        for name, data in cases.items():
            with self.subTest(name):
                self.min_app(data)
                result = self.run_tool()
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("min_app.json", result.stdout + result.stderr)
                # --check says the same, so CI's validator fails too.
                checked = self.run_tool("--check")
                self.assertEqual(checked.returncode, 1)
                self.assertIn("min_app.json", checked.stdout)

    def test_a_hidden_language_cannot_be_given_a_min_app(self) -> None:
        text = (self.tmp / "tools" / "deck_index.py").read_text(encoding="utf-8")
        (self.tmp / "tools" / "deck_index.py").write_text(
            text.replace("HIDDEN: set[str] = set()", 'HIDDEN: set[str] = {"es"}'),
            encoding="utf-8")
        self.min_app({"languages": {"es": "0.7.1"}})
        result = self.run_tool()
        self.assertEqual(result.returncode, 1)
        self.assertIn("not in the index", result.stderr)


class MinAppAgainstTheRelease(unittest.TestCase):
    """A min_app is refused for what the latest release already ships
    (ADR-0052): the app that cannot know the key would show it all the same."""

    # The sample repository and its helpers are DeckIndex's.
    setUp = DeckIndex.setUp
    run_tool = DeckIndex.run_tool
    index = DeckIndex.index
    language = DeckIndex.language

    def min_app(self, data: object) -> None:
        (self.tmp / "decks" / "min_app.json").write_text(
            json.dumps(data), encoding="utf-8")

    def git(self, *args: str) -> None:
        subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c",
             "commit.gpgsign=false", "-C", str(self.tmp), *args],
            check=True, capture_output=True)

    def release(self, shipped: list[str], files: list[str],
                tag: str | None = "v0.7.0") -> None:
        """Commit what release [tag] shipped: a languages.yaml listing the
        [shipped] codes, and the decks [files]. The working tree keeps its
        own languages.yaml (es)."""
        working = self.tmp / "assets" / "languages.yaml"
        keep = working.read_text(encoding="utf-8")
        working.write_text(
            "schema: 1\nkind: languages\nlanguages:\n" + "".join(
                f'  - {{ code: {c}, iso639_3: xxx, name: "X", own_name: "X" }}\n'
                for c in shipped), encoding="utf-8")
        self.git("init", "-q")
        self.git("add", "assets/languages.yaml", *files)
        self.git("commit", "-q", "-m", "release")
        if tag:
            self.git("tag", tag)
        working.write_text(keep, encoding="utf-8")

    def refused(self, *args: str) -> str:
        result = self.run_tool(*args)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        return result.stderr

    def test_a_shipped_language_cannot_be_gated(self) -> None:
        self.release(["es"], [])
        self.min_app({"languages": {"es": "0.7.1"}})
        error = self.refused()
        self.assertIn("'es'", error)
        self.assertIn("v0.7.0", error)

    def test_a_new_language_can_be_gated(self) -> None:
        self.release(["en"], [])
        self.min_app({"languages": {"es": "0.7.1"}})
        self.assertEqual(self.language(self.index(), "es")["min_app"], "0.7.1")

    def test_a_new_file_of_a_shipped_language_can_be_gated(self) -> None:
        self.release(["es"], ["decks/es/es-path.yaml"])
        self.min_app({"files": {"decks/es/es-en-core-100.yaml": "0.7.1"}})
        es = self.language(self.index(), "es")
        by_path = {f["path"]: f for f in es["files"]}
        self.assertEqual(by_path["decks/es/es-en-core-100.yaml"]["min_app"], "0.7.1")

    def test_a_file_the_release_already_reads_cannot_be_gated(self) -> None:
        self.release(["es"], ["decks/es/es-path.yaml", "decks/es/es-en-core-100.yaml"])
        self.min_app({"files": {"decks/es/es-en-core-100.yaml": "0.7.1"}})
        error = self.refused()
        self.assertIn("es-en-core-100.yaml", error)
        self.assertIn("v0.7.0", error)

    def test_without_a_tag_it_warns_and_strict_fails(self) -> None:
        self.release(["es"], [], tag=None)
        self.min_app({"languages": {"es": "0.7.1"}})
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("warning", result.stderr)
        self.assertIn("v* tag", result.stderr)
        self.assertIn("v* tag", self.refused("--strict-released"))

    def test_without_git_it_warns_and_the_env_var_is_strict(self) -> None:
        self.min_app({"languages": {"es": "0.7.1"}})
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("warning", result.stderr)
        strict = subprocess.run(
            [sys.executable, str(self.tmp / "tools" / "deck_index.py")],
            cwd=self.tmp, capture_output=True, text=True, check=False,
            env=dict(os.environ, FLUENOUGH_STRICT_RELEASED="1"))
        self.assertEqual(strict.returncode, 1)

    def test_nothing_gated_needs_no_release(self) -> None:
        result = self.run_tool("--strict-released")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("warning", result.stderr)


class ScriptFonts(unittest.TestCase):
    """The fonts the repository offers (ADR-0042, #611): every Chinese and
    Japanese script has one, each with its licence and a sample line the
    font check can show."""

    @classmethod
    def setUpClass(cls) -> None:
        sys.path.insert(0, str(TOOLS))
        import deck_index
        cls.fonts = deck_index.FONTS
        cls.dart = (REPO / "lib" / "core" / "decks" / "font_check.dart"
                    ).read_text(encoding="utf-8")

    def test_every_chinese_and_japanese_script_has_a_font(self) -> None:
        for script in ("han_simplified", "han_traditional", "han", "kana"):
            self.assertIn(script, self.fonts)

    def test_each_font_is_in_its_scripts_folder_with_its_licence(self) -> None:
        for script, (_family, name) in self.fonts.items():
            folder = REPO / "decks" / "fonts" / script
            with self.subTest(script):
                self.assertTrue((folder / name).is_file())
                self.assertTrue((folder / "OFL.txt").is_file())

    def test_each_font_has_a_sample_for_the_font_check(self) -> None:
        for script in self.fonts:
            with self.subTest(script):
                self.assertIn(f"  '{script}': ScriptSample(", self.dart)

    def test_japanese_kanji_use_noto_sans_jp(self) -> None:
        self.assertEqual(self.fonts["han"][0], "Noto Sans JP")
        self.assertEqual(self.fonts["han_traditional"][0], "Noto Sans TC")


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


if __name__ == "__main__":
    unittest.main()
