#!/usr/bin/env python3
"""Tests for tools/import_wiktionary.py (#518, #523), on the fixture in
tools/fixtures/wiktionary: a small core and layer in Devanagari as the
language zz, and a kaikki.org extract of a few Hindi entries. The network
and ffmpeg are replaced, so the tests download and convert nothing.

Stdlib `unittest` plus PyYAML, like the tool.
"""

from __future__ import annotations

import contextlib
import io
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

import import_wiktionary as iw  # noqa: E402
import validate_decks as vd  # noqa: E402

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "wiktionary"
DUMP = FIXTURE / "Testlang.jsonl"
CORE = "zz/zz-home.yaml"
LAYER = "zz/en/zz-en-home.yaml"
SRC = "https://en.wiktionary.org/wiki/{}"


def commons_reply(name: str, licence: str = "CC BY-SA 4.0",
                  artist: str = '<a href="https://x">A. Speaker</a>') -> bytes:
    """What Commons' API says of a file."""
    return json.dumps({"query": {"pages": {"1": {"imageinfo": [{
        "url": f"https://upload.wikimedia.org/{name}",
        "thumburl": f"https://upload.wikimedia.org/thumb/{name}.png",
        "descriptionurl": f"https://commons.wikimedia.org/wiki/File:{name}",
        "extmetadata": {"LicenseShortName": {"value": licence},
                        "Artist": {"value": artist}}}]}}}}).encode()


class Network:
    """A stand-in for the network: canned replies by a part of the URL, and
    every URL asked for."""

    def __init__(self, replies: dict[str, bytes]) -> None:
        self.replies = replies
        self.asked: list[str] = []

    def __call__(self, url: str) -> bytes:
        self.asked.append(url)
        for part, body in self.replies.items():
            if part in url:
                return body
        raise OSError(f"no reply for {url}")


def fake_convert(args: list[str]) -> None:
    """ffmpeg's stand-in: writes its output, the last argument."""
    Path(args[-1]).write_bytes(b"converted")


class Case(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.decks = self.tmp / "decks"
        shutil.copytree(FIXTURE / "decks", self.decks)

    def text(self, rel: str) -> str:
        return (self.decks / rel).read_text(encoding="utf-8")

    def card(self, rel: str, cid: str) -> dict:
        data = vd._load_raw(self.decks / rel)
        cards = data["cards"]
        if isinstance(cards, dict):
            return cards[cid]
        return next(c for c in cards if c.get("id") == cid)

    def run_tool(self, *extra: str, write: bool = True) -> tuple[int, str, str]:
        argv = ["import_wiktionary.py", "zz", str(DUMP), "--decks", str(self.decks),
                "--dump-date", "2026-10-13", *(["--write"] if write else []), *extra]
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = iw.main(argv)
        return code, out.getvalue(), err.getvalue()


class Report(Case):

    def _without_write_nothing_changes(self) -> None:
        before = self.text(CORE), self.text(LAYER)
        code, out, _ = self.run_tool(write=False)
        self.assertEqual(code, 0)
        self.assertEqual((self.text(CORE), self.text(LAYER)), before)
        self.assertIn("# Wiktionary import: zz (zz)", out)


    def test_without_write_nothing_changes(self) -> None:
        cases = (
            self._without_write_nothing_changes,
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


class Fill(Case):

    def setUp(self) -> None:
        super().setUp()
        self.assertEqual(self.run_tool()[0], 0)

    def _the_files_still_validate(self) -> None:
        for rel in (CORE, LAYER):
            self.assertEqual(vd.validate(self.decks / rel).errors, [], rel)


    def _a_meaning_never_changes(self) -> None:
        for cid, native in (("zz-9001", "house; home"), ("zz-9004", "big"),
                            ("zz-9003", "yesterday; tomorrow")):
            self.assertEqual(self.card(LAYER, cid)["native"], native)


    def _a_second_run_adds_nothing(self) -> None:
        before = self.text(CORE), self.text(LAYER)
        self.run_tool()
        self.assertEqual((self.text(CORE), self.text(LAYER)), before)

    def test_the_files_still_validate_a_meaning_never_changes_and_a_second_run_adds_nothing(self) -> None:
        cases = (
            self._the_files_still_validate,
            self._a_meaning_never_changes,
            self._a_second_run_adds_nothing,
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


class Recordings(Case):

    def run_audio(self, network: Network) -> tuple[int, str, str]:
        with mock.patch.object(iw, "http_get", network), \
                mock.patch.object(iw, "convert", fake_convert), \
                mock.patch.object(iw.shutil, "which", return_value="/usr/bin/ffmpeg"):
            return self.run_tool("--audio")


    def _a_licence_that_cannot_ship_is_skipped(self) -> None:
        network = Network({"commons.wikimedia.org/w/api.php":
                           commons_reply("Hi-घर.ogg", licence="GFDL")})
        code, out, _ = self.run_audio(network)
        self.assertEqual(code, 0)
        self.assertNotIn("audio", self.card(CORE, "zz-9001"))
        self.assertFalse((self.decks / "zz/audio").exists())
        self.assertIn("zz-9001 घर: Hi-घर.ogg: licence 'GFDL' cannot ship in a CC BY-SA "
                      "4.0 deck", out)


    def test_a_licence_that_cannot_ship_is_skipped(self) -> None:
        cases = (
            self._a_licence_that_cannot_ship_is_skipped,
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


SECTIONS = json.dumps({"parse": {"sections": [
    {"level": "2", "line": "Nepali", "index": "1"},
    {"level": "2", "line": "Testlang", "index": "4"}]}}).encode()


def page_with(name: str, licence: str = "CC BY 2.0") -> Network:
    """Every Wiktionary page with one picture, [name], under [licence]."""
    return Network({
        "prop=sections": SECTIONS,
        "prop=images": json.dumps({"parse": {"images": [name]}}).encode(),
        "commons.wikimedia.org/w/api.php": commons_reply(name, licence=licence),
        "upload.wikimedia.org/thumb/": b"PNG",
        "openmoji": b"PNG"})


class NewLanguageReadings(unittest.TestCase):
    """What the importer reads for the courses beyond the Indic ones (#612)."""

    def test_korean_and_kana_are_read_and_mandarin_takes_the_hint(self) -> None:
        self.assertEqual(iw.reading("학생", "ko", "hangul", None), "haksaeng")
        self.assertEqual(iw.reading("わたし", "ja", "kana", None), "watashi")
        self.assertEqual(iw.reading("日本", "ja", "kana", "nihon"), "nihon")
        self.assertEqual(iw.reading("你好", "zh", "han_simplified", "nǐ hǎo"),
                         "nǐ hǎo")

    def test_a_word_with_nothing_to_read_it_by_is_left_out(self) -> None:
        for word, code, script, hint in (
            ("你好", "zh", "han_simplified", None),
            ("日本", "ja", "kana", None),
        ):
            with self.subTest(word), self.assertRaises(iw.NoReading):
                iw.reading(word, code, script, hint)

    def test_maithili_is_not_read_by_hindis_rules(self) -> None:
        with self.assertRaises(iw.NoReading):
            iw.reading("देखलहुँ", "mai", "devanagari", "dekhalahũ")

    def test_chinese_ipa_is_the_mandarin_one(self) -> None:
        entry = {"sounds": [{"ipa": "/kɐu̯²⁵/", "tags": ["Cantonese"]},
                            {"ipa": "/ni²¹⁴/", "tags": ["Mandarin"]}]}
        self.assertEqual(iw.ipa_of(entry, "zh"), "ni²¹⁴")
        self.assertIsNone(iw.ipa_of({"sounds": entry["sounds"][:1]}, "zh"))


if __name__ == "__main__":
    unittest.main()
