#!/usr/bin/env python3
"""Tests for tools/fetch_sound_audio.py (ADR-0059, #734), on a small
sound-inventory deck as the language zz and a fake Wikimedia: no network, and
no ffmpeg (the encode step is replaced by a stub that builds Ogg Opus streams
by hand with `ogg_opus_testlib`). One optional test uses the real ffmpeg and
is skipped without it.

Stdlib `unittest` plus PyYAML, like the tool.
"""

from __future__ import annotations

import contextlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import urllib.parse
from pathlib import Path
from unittest import mock

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fetch_sound_audio as fsa  # noqa: E402
import validate_decks as vd  # noqa: E402
import wikimedia_client as wc  # noqa: E402
from ogg_opus_testlib import make_opus  # noqa: E402

DECK = '''\
# The sounds of Zedish. A comment the tool must leave alone.
schema: 1
id: "zz-sound-inventory"
part: "core"
kind: "vocab"
language: { code: "zz", iso639_3: "zzz", name: "Zedish", script: "latin", icon: "Z" }
license: "CC-BY-SA-4.0"
cards:
  - id: "zz-0001"
    target: "p"
    reading: "pa"
    ipa: "p"
    tags: ["stops"]
    notes:
      - { id: "n1", kind: "note" }
    modes: ["production"]
  - id: "zz-0002"
    target: "b"
    reading: "ba"
    ipa: "b"
    phonetic: "[b]"
    phonetic_source: "rules"
    examples:
      - { target: "bab", reading: "bab", ipa: "bab" }
  - id: "zz-0003"
    target: "t"
    reading: "ta"
    ipa: "t"
  - id: "zz-0004"
    target: "d"
    reading: "da"
    ipa: "d"
  - id: "zz-0005"
    target: "k"
    reading: "ka"
    ipa: "k"
  - id: "zz-0006"
    target: "g"
    reading: "ga"
    ipa: "ɡ"
  - id: "zz-0007"
    target: "q"
    reading: "qa"
    ipa: "q"
  - id: "zz-0008"
    target: "m"
    reading: "ma"
    ipa: "m"
    audio: "decks/zz/audio/zz-0008.opus"
    audio_credit: { source: "https://commons.wikimedia.org/wiki/File:Old.ogg", license: "CC0-1.0", credit: "Earlier" }
  - id: "zz-0009"
    target: "kʰ"
    reading: "kha"
    ipa: "kʰ"
  - id: "zz-0010"
    target: "ʃ"
    reading: "sha"
    ipa: "ʃ"
'''

FILE = "File:{}.ogg"


def title(name: str) -> str:
    return FILE.format(name)


# What the fake Commons knows: title to (licence short name, artist HTML, seconds).
FILES = {
    title("Voiceless bilabial plosive"): ("CC BY-SA 4.0", '<a href="https://x">Jane Speaker</a>', 1.5),
    title("Voiced bilabial plosive"): ("CC BY 3.0", "John Q. Voice", 1.0),
    title("Voiceless alveolar plosive"): ("CC BY-NC-SA 3.0", "Nina NC", 1.0),
    title("Voiced alveolar plosive"): ("CC BY-ND 4.0", "Nick ND", 1.0),
    title("Voiceless velar plosive"): ("GFDL", "Gina Gfdl", 1.0),
    title("Voiced velar plosive"): ("CC BY-SA 3.0", "", 1.0),            # no author
    title("Voiced alveolar nasal"): ("CC BY-SA 4.0", "Someone", 1.0),
    title("Bilabial nasal"): ("CC BY-SA 4.0", "Someone", 1.0),
    title("Voiceless postalveolar fricative"): ("Public domain", "Unknown author", 1.0),
    title("ʃ-zz"): ("CC0", "Lena Letter", 1.0),
}
CATEGORIES = {"Category:Zedish pronunciation": [title("ʃ-zz"), title("other-zz")]}


class FakeWiki:
    """A stand-in for Commons and its file server; records every request."""

    def __init__(self, files: dict | None = None) -> None:
        self.files = dict(FILES if files is None else files)
        self.api: list[dict[str, str]] = []
        self.downloads: list[str] = []
        self.fail_downloads = 0

    def __call__(self, url: str, headers: dict[str, str]) -> wc.Response:
        parts = urllib.parse.urlsplit(url)
        q = {k: v[0] for k, v in urllib.parse.parse_qs(parts.query).items()}
        if parts.hostname == "upload.wikimedia.org":
            self.downloads.append(url)
            if self.fail_downloads:
                self.fail_downloads -= 1
                return wc.Response(429, {"retry-after": "1"}, b"")
            return wc.Response(200, {}, b"OggS-original:" + parts.path.encode())
        self.api.append(q)
        if q.get("list") == "categorymembers":
            members = [{"title": t} for t in CATEGORIES.get(q["cmtitle"], [])]
            return self.json({"query": {"categorymembers": members}})
        pages = []
        for t in q["titles"].split("|"):
            if t not in self.files:
                pages.append({"title": t, "missing": True})
                continue
            licence, artist, seconds, *rest = self.files[t]
            name = t.split(":", 1)[1].replace(" ", "_")
            pages.append({"title": t, "imageinfo": [{
                "url": f"https://upload.wikimedia.org/x/{urllib.parse.quote(name)}",
                "descriptionurl": f"https://commons.wikimedia.org/wiki/{urllib.parse.quote(t.replace(' ', '_'), safe=':')}",
                "duration": seconds,
                **({"size": rest[0]} if rest else {}),
                **({"mime": rest[1]} if len(rest) > 1 else {}),
                "extmetadata": {"LicenseShortName": {"value": licence},
                                "Artist": {"value": artist}}}]})
        return self.json({"query": {"pages": pages}})

    @staticmethod
    def json(obj: object) -> wc.Response:
        return wc.Response(200, {}, json.dumps(obj).encode())

    def titles_asked(self) -> list[str]:
        return [t for q in self.api for t in q.get("titles", "").split("|") if t]


def stub_encode(data: bytes, suffix: str, kbps: int) -> bytes:
    return make_opus(seconds=1.0, kbps=kbps)


class Case(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.decks = self.tmp / "decks"
        (self.decks / "zz" / "audio").mkdir(parents=True)
        self.deck = self.decks / "zz" / "zz-sound-inventory.yaml"
        self.deck.write_text(DECK, encoding="utf-8")
        # Card 8 already has valid audio.
        (self.decks / "zz" / "audio" / "zz-0008.opus").write_bytes(make_opus(1.0, 32))
        self.wiki = FakeWiki()
        self.encode = mock.patch.object(fsa, "encode_clip", side_effect=stub_encode)
        self.encode_mock = self.encode.start()
        self.addCleanup(self.encode.stop)

    def client(self, wiki: object | None = None, **kw: object) -> wc.Client:
        args = dict(cache_dir=self.tmp / "cache", sleep=lambda s: None,
                    api_interval=0.0, download_interval=0.0)
        args.update(kw)
        return wc.Client(wiki or self.wiki, **args)  # type: ignore[arg-type]

    def run_tool(self, client: wc.Client | None = None, **kw: object) -> fsa.Report:
        return fsa.run(client or self.client(), fsa.Options(decks=self.decks, **kw))

    def cards(self) -> dict[str, dict]:
        data = yaml.safe_load(self.deck.read_text(encoding="utf-8"))
        return {c["id"]: c for c in data["cards"]}

    def files(self) -> list[str]:
        return sorted(p.name for p in (self.decks / "zz" / "audio").iterdir())

    def snapshot(self) -> dict[str, bytes]:
        return {str(p.relative_to(self.decks)): p.read_bytes()
                for p in sorted(self.decks.rglob("*")) if p.is_file()}


class Licences(Case):
    def test_nc_nd_gfdl_only_and_no_author_are_skipped_and_reported(self) -> None:
        report = self.run_tool(langs=["zz"])
        lr = report.langs["zz"]
        self.assertEqual(lr.ids["skipped-licence"], ["zz-0003", "zz-0004", "zz-0005"])
        self.assertEqual(lr.ids["skipped-no-author"], ["zz-0006"])
        self.assertEqual((lr.skipped_licence, lr.skipped_no_author), (3, 1))
        cards = self.cards()
        for cid in ("zz-0003", "zz-0004", "zz-0005", "zz-0006"):
            self.assertNotIn("audio", cards[cid], cid)
            self.assertNotIn("audio_credit", cards[cid], cid)
        self.assertNotIn("zz-0003.opus", self.files())
        reasons = {s["card"]: s["reason"] for s in lr.skipped_files}
        self.assertIn("licence", reasons["zz-0003"])
        self.assertIn("author", reasons["zz-0006"])

    def test_unknown_author_is_no_author_even_for_public_domain(self) -> None:
        # ADR-0059 decision 8: skip, do not credit "Unknown author".
        v = fsa.judge(title("x"), {"extmetadata": {"LicenseShortName": {"value": "Public domain"},
                                                     "Artist": {"value": "Unknown author"}}})
        self.assertEqual(v.status, "no-author")
        for artist in ("", "Anonymous", "unknown", "N/A", "?"):
            v = fsa.judge(title("x"), {"extmetadata": {"LicenseShortName": {"value": "CC0"},
                                                         "Artist": {"value": artist}}})
            self.assertEqual(v.status, "no-author", artist)

    def test_an_author_and_an_allowed_licence_are_fetched_with_the_credit(self) -> None:
        self.run_tool(langs=["zz"])
        cards = self.cards()
        p = cards["zz-0001"]
        self.assertEqual(p["audio"], "decks/zz/audio/zz-0001.opus")
        self.assertEqual(p["audio_credit"], {
            "source": "https://commons.wikimedia.org/wiki/File:Voiceless_bilabial_plosive.ogg",
            "license": "CC-BY-SA-4.0", "credit": "Jane Speaker"})
        self.assertEqual(cards["zz-0002"]["audio_credit"]["license"], "CC-BY-3.0")
        self.assertEqual(cards["zz-0002"]["audio_credit"]["credit"], "John Q. Voice")
        for cid in ("zz-0001", "zz-0002", "zz-0010"):
            self.assertIn(f"{cid}.opus", self.files())

    def test_the_output_passes_the_validators_audio_checks(self) -> None:
        self.run_tool(langs=["zz"])
        for cid in ("zz-0001", "zz-0002", "zz-0010"):
            data = (self.decks / "zz" / "audio" / f"{cid}.opus").read_bytes()
            r = vd.Report(self.deck)
            vd.check_audio_file(r, cid, f"decks/zz/audio/{cid}.opus", data)
            self.assertEqual(r.errors, [])
            credit = self.cards()[cid]["audio_credit"]
            self.assertRegex(credit["source"], r"^https?://\S+$")
            self.assertRegex(credit["license"], vd.MEDIA_LICENSE_RE)
            self.assertEqual(set(credit), vd.MEDIA_CREDIT_KEYS)


class Letters(Case):
    def test_letter_titles_match_the_cards_letter_or_reading_by_file_stem(self) -> None:
        cards = fsa.read_cards(self.decks, "zz")
        files = CATEGORIES["Category:Zedish pronunciation"]
        self.assertEqual(fsa.letter_titles(cards[9], files), [title("ʃ-zz")])
        self.assertEqual(fsa.letter_titles(cards[0], files), [])

    def test_the_symbol_clip_comes_first_and_a_no_author_clip_falls_through_to_the_letter(
            self) -> None:
        report = self.run_tool(langs=["zz"])
        card = self.cards()["zz-0010"]       # its symbol clip names no author
        self.assertEqual(card["audio_credit"]["credit"], "Lena Letter")
        self.assertEqual(card["audio_credit"]["license"], "CC0-1.0")
        self.assertEqual(report.langs["zz"].sources["letter"], 1)
        self.assertEqual(report.langs["zz"].sources["ipa-symbol"], 2)

    def test_no_letters_skips_the_category(self) -> None:
        report = self.run_tool(langs=["zz"], letters=False)
        self.assertFalse(any(q.get("list") for q in self.wiki.api))
        self.assertNotIn("audio", self.cards()["zz-0010"])
        self.assertEqual(report.langs["zz"].ids["skipped-no-author"], ["zz-0006", "zz-0010"])

    def test_the_example_words_recording_is_the_last_resort(self) -> None:
        dump = self.tmp / "dump.jsonl"
        dump.write_text(json.dumps({"word": "bab", "sounds": [{"audio": "Bab-zz.ogg"}]}) + "\n",
                        encoding="utf-8")
        files = dict(FILES)
        files[title("Voiced bilabial plosive")] = ("CC BY-NC 3.0", "NC", 1.0)
        files[title("Bab-zz")] = ("CC BY-SA 4.0", "Wanda Word", 1.0)
        wiki = FakeWiki(files)
        report = self.run_tool(self.client(wiki), langs=["zz"], example_words=True, dump=dump)
        self.assertEqual(self.cards()["zz-0002"]["audio_credit"]["credit"], "Wanda Word")
        self.assertEqual(report.langs["zz"].sources["example-word"], 1)


class Missing(Case):
    def test_a_card_with_no_recording_keeps_no_audio_field(self) -> None:
        report = self.run_tool(langs=["zz"])
        cards = self.cards()
        for cid in ("zz-0007", "zz-0009"):             # q has no file; kʰ is no single symbol
            self.assertNotIn("audio", cards[cid])
        self.assertEqual(report.langs["zz"].ids["missing"], ["zz-0007", "zz-0009"])
        self.assertEqual(report.langs["zz"].missing, 2)

    def test_untouched_cards_and_text_are_byte_identical(self) -> None:
        self.run_tool(langs=["zz"])
        before = DECK.split("\n")
        after = self.deck.read_text(encoding="utf-8").split("\n")
        self.assertEqual(after[0], before[0])                    # the comment
        added = [line for line in after if line not in before]
        self.assertTrue(all(line.startswith("    audio") for line in added), added)
        self.assertEqual([line for line in before if line not in after], [])

    def test_the_audio_lines_follow_the_cards_ipa_lines(self) -> None:
        self.run_tool(langs=["zz"])
        lines = self.deck.read_text(encoding="utf-8").split("\n")
        i = lines.index('    phonetic_source: "rules"')        # card zz-0002's last ipa line
        self.assertTrue(lines[i + 1].startswith("    audio: "))
        self.assertTrue(lines[i + 2].startswith("    audio_credit: "))


class Idempotent(Case):
    def test_a_second_run_changes_nothing_and_asks_for_nothing(self) -> None:
        self.run_tool(langs=["zz"])
        first = self.snapshot()
        api, downloads = len(self.wiki.api), len(self.wiki.downloads)
        report = self.run_tool(langs=["zz"])
        self.assertEqual(self.snapshot(), first)
        self.assertEqual(report.langs["zz"].fetched, 0)
        self.assertEqual(report.langs["zz"].already, 4)     # zz-0001, 0002, 0008, 0010
        self.assertEqual((len(self.wiki.api), len(self.wiki.downloads)), (api, downloads))

    def test_a_card_with_valid_audio_is_skipped(self) -> None:
        before = (self.decks / "zz" / "audio" / "zz-0008.opus").read_bytes()
        report = self.run_tool(langs=["zz"])
        self.assertEqual((self.decks / "zz" / "audio" / "zz-0008.opus").read_bytes(), before)
        self.assertEqual(self.cards()["zz-0008"]["audio_credit"]["credit"], "Earlier")
        self.assertNotIn("zz-0008", sum(report.langs["zz"].ids.values(), []))

    def test_refresh_redoes_a_card_that_has_audio_and_replaces_its_lines(self) -> None:
        self.run_tool(langs=["zz"])
        report = self.run_tool(langs=["zz"], refresh=True)
        text = self.deck.read_text(encoding="utf-8")
        self.assertEqual(text.count('audio: "decks/zz/audio/zz-0001.opus"'), 1)
        self.assertEqual(text.count("\n    audio_credit:"), text.count("\n    audio: "))
        cards = self.cards()
        self.assertEqual(cards["zz-0008"]["audio_credit"]["credit"], "Someone")  # redone from Commons
        self.assertEqual(report.langs["zz"].fetched, 4)

    def test_resumable_after_the_request_cap_stops_a_run(self) -> None:
        # Two API calls and two downloads fit; the third download does not.
        report = self.run_tool(self.client(max_requests=4), langs=["zz"])
        self.assertTrue(report.stopped)
        done = [c for c, v in self.cards().items() if v.get("audio") and c != "zz-0008"]
        self.assertTrue(set(done) <= {"zz-0001", "zz-0002"})
        files_before = self.snapshot()
        report = self.run_tool(langs=["zz"])           # a fresh client, the same cache
        self.assertEqual(report.stopped, "")
        self.assertEqual({c for c, v in self.cards().items() if v.get("audio")},
                         {"zz-0001", "zz-0002", "zz-0008", "zz-0010"})
        for rel, data in files_before.items():
            if rel.endswith(".opus"):
                self.assertEqual((self.decks / rel).read_bytes(), data)   # nothing redone

    def test_a_stopped_run_leaves_no_file_without_its_card_line(self) -> None:
        self.run_tool(self.client(max_requests=4), langs=["zz"])
        cards = self.cards()
        on_disk = {n[:-5] for n in self.files() if n.endswith(".opus")}
        named = {c for c, v in cards.items() if v.get("audio")}
        self.assertEqual(on_disk, named)


class SizeCap(Case):
    def test_a_clip_over_16_kb_is_reencoded_lower(self) -> None:
        self.encode_mock.side_effect = lambda d, s, k: make_opus(seconds=6, kbps=k)
        self.run_tool(langs=["zz"], limit=1)
        data = (self.decks / "zz" / "audio" / "zz-0001.opus").read_bytes()
        self.assertLessEqual(len(data), vd.AUDIO_MAX_BYTES)
        self.assertEqual([c.args[2] for c in self.encode_mock.call_args_list], [32, 24, 16])

    def test_a_clip_that_never_fits_is_skipped_and_reported(self) -> None:
        self.encode_mock.side_effect = lambda d, s, k: make_opus(seconds=30, kbps=k)
        report = self.run_tool(langs=["zz"], limit=1)
        lr = report.langs["zz"]
        self.assertEqual(lr.over_size, 1)
        self.assertEqual(lr.ids["over-size"], ["zz-0001"])
        self.assertNotIn("audio", self.cards()["zz-0001"])
        self.assertNotIn("zz-0001.opus", self.files())
        self.assertEqual([c.args[2] for c in self.encode_mock.call_args_list], [32, 24, 16, 12])

    def test_the_bitrate_target_is_32_kbps_and_never_above_the_cap(self) -> None:
        self.run_tool(langs=["zz"], limit=1)
        self.assertEqual(self.encode_mock.call_args_list[0].args[2], 32)
        self.encode_mock.reset_mock()
        fsa.encode_fitting(b"x", ".ogg", 200)        # a target over the ladder starts at 32
        self.assertEqual(self.encode_mock.call_args_list[0].args[2], 32)
        self.assertLessEqual(max(fsa.KBPS_LADDER), vd.AUDIO_MAX_KBPS)

    def test_a_stereo_encode_is_refused(self) -> None:
        self.encode_mock.side_effect = lambda d, s, k: make_opus(seconds=1, kbps=k, channels=2)
        report = self.run_tool(langs=["zz"], limit=1)
        self.assertEqual(report.langs["zz"].errors, 1)
        self.assertNotIn("zz-0001.opus", self.files())


class SurveyAndDryRun(Case):
    def test_survey_writes_nothing_and_downloads_no_audio(self) -> None:
        before = self.snapshot()
        report = self.run_tool(langs=["zz"], survey=True)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.wiki.downloads, [])
        self.encode_mock.assert_not_called()
        lr = report.langs["zz"]
        self.assertEqual(lr.available, 3)
        self.assertGreater(lr.estimated_bytes, 0)
        self.assertEqual(lr.bytes, 0)
        self.assertEqual(lr.licences["CC-BY-SA-4.0"], 1)
        self.assertIn("CC BY-NC-SA 3.0", lr.licences)      # licences seen, even those skipped
        self.assertTrue(lr.skipped_files)

    def test_survey_estimates_bytes_from_the_duration(self) -> None:
        v = fsa.Verdict("ok", "t", duration=1.5)
        self.assertEqual(fsa.estimate_bytes(v), round(1.5 * 32 * 125) + 1000)
        self.assertEqual(fsa.estimate_bytes(fsa.Verdict("ok", "t")), fsa.ESTIMATE_BYTES)
        self.assertEqual(fsa.estimate_bytes(fsa.Verdict("ok", "t", duration=600)),
                         vd.AUDIO_MAX_BYTES)

    def test_dry_run_encodes_but_writes_nothing_to_the_decks(self) -> None:
        before = self.snapshot()
        report = self.run_tool(langs=["zz"], dry_run=True)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(report.langs["zz"].fetched, 3)
        self.assertGreater(report.langs["zz"].bytes, 0)
        self.assertEqual(report.mode, "dry-run")

    def test_limit_counts_cards_asked(self) -> None:
        report = self.run_tool(langs=["zz"], limit=1)
        self.assertEqual(report.langs["zz"].asked, 1)
        self.assertEqual(report.langs["zz"].fetched, 1)
        self.assertEqual(self.files(), ["zz-0001.opus", "zz-0008.opus"])


class Politeness(Case):
    def test_titles_are_asked_once_in_batches_and_the_cache_serves_a_rerun(self) -> None:
        self.run_tool(langs=["zz"], survey=True)
        asked = self.wiki.titles_asked()
        self.assertEqual(len(asked), len(set(asked)))
        self.assertTrue(all(len(q["titles"].split("|")) <= 50
                            for q in self.wiki.api if "titles" in q))
        n = len(self.wiki.api)
        self.run_tool(langs=["zz"], survey=True)
        self.assertEqual(len(self.wiki.api), n)

    def test_a_429_with_retry_after_is_waited_out_and_the_run_completes(self) -> None:
        self.wiki.fail_downloads = 1
        sleeps: list[float] = []
        client = self.client(sleep=sleeps.append)
        report = self.run_tool(client, langs=["zz"], limit=1)
        self.assertEqual(report.langs["zz"].fetched, 1)
        self.assertIn(1.0, sleeps)

    def test_a_run_the_server_will_not_serve_stops_cleanly_with_what_it_has(self) -> None:
        def refuse(url: str, headers: dict[str, str]) -> wc.Response:
            return wc.Response(429, {"retry-after": "9999"}, b"")
        before = self.snapshot()
        report = self.run_tool(self.client(refuse), langs=["zz"])
        self.assertIn("9999", report.stopped)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(report.to_json()["stopped"], report.stopped)


class Reports(Case):
    def test_report_shapes(self) -> None:
        report = self.run_tool(langs=["zz"])
        data = report.to_json()
        self.assertEqual(data["mode"], "write")
        self.assertEqual({"mode", "stopped", "error", "requests", "total", "existing_bytes",
                          "ceiling_bytes", "ceiling_share_percent", "languages"}, set(data))
        lang = data["languages"][0]
        self.assertEqual({"lang", "cards", "already", "asked", "available", "fetched",
                          "missing", "skipped_no_author", "skipped_licence", "over_size",
                          "errors", "bytes", "estimated_bytes", "sources", "licences",
                          "ids", "skipped_files", "symbols_not_found"}, set(lang))
        self.assertEqual(lang["cards"], 10)
        self.assertEqual(lang["fetched"], 3)
        self.assertEqual(data["total"]["fetched"], 3)
        self.assertEqual(data["ceiling_bytes"], 50 * 1024 * 1024)
        written = sum(p.stat().st_size for p in (self.decks / "zz" / "audio").glob("*.opus"))
        self.assertAlmostEqual(data["ceiling_share_percent"],
                               100 * written / data["ceiling_bytes"], places=1)
        json.dumps(data)

    def test_markdown_names_the_counts_and_the_share_of_the_ceiling(self) -> None:
        text = self.run_tool(langs=["zz"]).to_markdown()
        self.assertIn("| zz | 10 |", text)
        self.assertIn("50 MB ceiling", text)
        self.assertIn("skipped-no-author: zz-0006", text)
        self.assertIn("missing: zz-0007, zz-0009", text)

    def test_the_command_line_writes_both_reports(self) -> None:
        md, js = self.tmp / "r.md", self.tmp / "r.json"
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = fsa.main(["--decks", str(self.decks), "--lang", "zz", "--survey",
                             "--report", str(md), "--json", str(js)], client=self.client())
        self.assertEqual(code, 0)
        self.assertIn("survey", md.read_text(encoding="utf-8"))
        self.assertEqual(json.loads(js.read_text(encoding="utf-8"))["mode"], "survey")

    def test_exit_code_3_when_the_run_stops_at_the_cap(self) -> None:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = fsa.main(["--decks", str(self.decks), "--lang", "zz"],
                            client=self.client(max_requests=1))
        self.assertEqual(code, 3)

    def test_bad_arguments_are_exit_code_2(self) -> None:
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertEqual(fsa.main(["--survey", "--dry-run"]), 2)
            self.assertEqual(fsa.main(["--example-words"]), 2)
            self.assertEqual(fsa.main(["--kbps", "999"]), 2)

    def test_an_unknown_language_is_an_error(self) -> None:
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            code = fsa.main(["--decks", str(self.decks), "--lang", "qq"], client=self.client())
        self.assertEqual(code, 1)
        self.assertIn("sound-inventory", err.getvalue())


class Bounds(Case):
    """A source file or an answer too big to read is stopped, not buffered."""

    @staticmethod
    def info(**kw: object) -> dict:
        return {"mime": "audio/ogg", "size": 20000, "duration": 1.0,
                "extmetadata": {"LicenseShortName": {"value": "CC BY-SA 4.0"},
                                "Artist": {"value": "A. Speaker"}}, **kw}

    def test_judge_skips_a_file_over_the_size_or_the_duration_limit(self) -> None:
        self.assertEqual(fsa.judge("File:a.ogg", self.info()).status, "ok")
        self.assertEqual(fsa.judge("File:a.ogg", self.info(size=6 * 1024 * 1024)).status,
                         "over-size")
        self.assertEqual(fsa.judge("File:a.ogg", self.info(duration=45)).status, "over-size")

    def test_judge_skips_a_file_that_is_not_audio(self) -> None:
        for mime in ("text/html", "image/png", "application/pdf"):
            self.assertEqual(fsa.judge("File:a.ogg", self.info(mime=mime)).status, "bad-type")
        for mime in ("audio/ogg", "application/ogg", "audio/x-wav", "audio/mpeg"):
            self.assertEqual(fsa.judge("File:a.ogg", self.info(mime=mime)).status, "ok")

    def test_an_oversize_file_is_reported_and_never_downloaded(self) -> None:
        files = dict(FILES)
        files[title("Voiced bilabial plosive")] = ("CC BY 3.0", "J. Voice", 1.0, 9_000_000)
        wiki = FakeWiki(files)
        report = self.run_tool(self.client(wiki), langs=["zz"])
        lr = report.langs["zz"]
        self.assertEqual(lr.ids["over-size"], ["zz-0002"])
        self.assertEqual(lr.over_size, 1)
        self.assertNotIn("audio", self.cards()["zz-0002"])
        self.assertFalse([u for u in wiki.downloads if "Voiced_bilabial_plosive" in u])

    def test_ffmpeg_gets_a_bounded_input_and_no_stream_buffering_filter(self) -> None:
        calls: list[list[str]] = []

        def convert(args: list[str]) -> None:
            calls.append(list(args))
            Path(args[-1]).write_bytes(b"x")

        def volume(args: list[str]) -> str:
            calls.append(list(args))
            return "max_volume: -6.0 dB"
        with mock.patch.object(fsa.iw, "convert", side_effect=convert), \
                mock.patch.object(fsa, "_ffmpeg_text", side_effect=volume):
            self.encode.stop()
            try:
                fsa.encode_clip(b"data", ".ogg", 32)
            finally:
                self.encode.start()
        self.assertEqual(len(calls), 3)
        for args in calls:
            self.assertEqual(args[:2], ["-protocol_whitelist", "file"])
            self.assertLess(args.index("-protocol_whitelist"), args.index("-i"))
        first = calls[0]
        self.assertLess(first.index("-t"), first.index("-i"))        # input option
        self.assertEqual(first[first.index("-t") + 1], str(fsa.MAX_SOURCE_SECONDS))
        self.assertGreater(len(first) - 1 - first[::-1].index("-t"), first.index("-i"))  # and on the output
        for args in calls:
            self.assertNotIn("areverse", " ".join(args))

    def test_the_report_lists_the_symbol_titles_tried_and_not_found(self) -> None:
        report = self.run_tool(langs=["zz"], survey=True)
        missing = report.langs["zz"].symbols_not_found
        self.assertEqual(missing["q"], ["File:Voiceless uvular plosive.ogg",
                                        "File:Voiceless uvular plosive.oga"])
        self.assertNotIn("p", missing)
        self.assertIn("IPA symbol clips not found", report.to_markdown())
        self.assertIn("symbols_not_found", report.to_json()["languages"][0])


class Failures(Case):
    def test_another_wikimedia_error_still_writes_the_report_and_exits_4(self) -> None:
        def broken(url: str, headers: dict[str, str]) -> wc.Response:
            return wc.Response(404, {}, b"")
        md = self.tmp / "r.md"
        with contextlib.redirect_stdout(io.StringIO()):
            code = fsa.main(["--decks", str(self.decks), "--lang", "zz", "--report", str(md)],
                            client=self.client(broken))
        self.assertEqual(code, 4)
        self.assertIn("**Error:**", md.read_text(encoding="utf-8"))


class Safety(Case):
    def test_it_writes_only_the_audio_folder_and_the_deck_file(self) -> None:
        before = set(self.snapshot())
        self.run_tool(langs=["zz"])
        after = set(self.snapshot())
        new = after - before
        self.assertEqual(new, {"zz/audio/zz-0001.opus", "zz/audio/zz-0002.opus",
                               "zz/audio/zz-0010.opus"})
        # No stray temporary file anywhere under the decks.
        self.assertFalse([p for p in self.decks.rglob("*") if p.suffix == ".part"])

    def test_a_wrong_edit_is_caught_by_the_read_back(self) -> None:
        with self.assertRaises(Exception):
            fsa.read_back(DECK, DECK.replace('target: "p"', 'target: "P"'), "zz-0001",
                          "decks/zz/audio/zz-0001.opus", {"source": "s", "license": "l", "credit": "c"})
        good = fsa.edit_card(DECK, "zz-0001", "decks/zz/audio/zz-0001.opus",
                             {"source": "https://x", "license": "CC0-1.0", "credit": "A"})
        fsa.read_back(DECK, good, "zz-0001", "decks/zz/audio/zz-0001.opus",
                      {"source": "https://x", "license": "CC0-1.0", "credit": "A"})

    def test_the_symbol_table_maps_single_symbols_only(self) -> None:
        self.assertEqual(fsa.symbol_titles("p")[0], title("Voiceless bilabial plosive"))
        self.assertEqual(fsa.symbol_titles("/p/"), fsa.symbol_titles("p"))
        self.assertEqual(fsa.symbol_titles("kʰ"), [])
        self.assertEqual(fsa.symbol_titles("aː"), [])
        self.assertEqual(fsa.symbol_titles(None), [])


@unittest.skipUnless(shutil.which("ffmpeg"), "needs ffmpeg")
class RealEncode(unittest.TestCase):
    """The real encode step, only where ffmpeg with libopus is installed: its
    output passes the validator's audio checks."""

    def test_the_real_encode_passes_the_validators_audio_checks(self) -> None:
        listing = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], capture_output=True,
                                 text=True).stdout
        if "libopus" not in listing:
            self.skipTest("ffmpeg has no libopus")
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "tone.ogg"
            made = subprocess.run(
                ["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "lavfi", "-i",
                 "anullsrc=r=44100:cl=mono:d=0.3", "-f", "lavfi", "-i",
                 "sine=frequency=440:duration=1.0", "-filter_complex", "[0][1]concat=n=2:v=0:a=1",
                 "-c:a", "libvorbis", str(src)], capture_output=True)
            if made.returncode != 0:
                self.skipTest("ffmpeg cannot make a Vorbis test file")
            opus, why = fsa.encode_fitting(src.read_bytes(), ".ogg")
        self.assertIsNotNone(opus, why)
        r = vd.Report(Path("x.yaml"))
        vd.check_audio_file(r, "card", "decks/zz/audio/zz-0001.opus", opus)
        self.assertEqual(r.errors, [])
        self.assertLessEqual(len(opus), vd.AUDIO_MAX_BYTES)


if __name__ == "__main__":
    unittest.main()
