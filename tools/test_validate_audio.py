#!/usr/bin/env python3
"""A shipped recording is compressed Ogg Opus with a credit that can ship
(ADR-0059, #734): the validator reads the file's own bytes, so these tests
build tiny Ogg Opus streams by hand (`ogg_opus_testlib`), with no ffmpeg and
no network.

Uses the B1 fixture of test_validate_b1. Stdlib `unittest` plus PyYAML.
"""

from __future__ import annotations

import contextlib
import io
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ogg_opus_testlib import make_opus, make_vorbis  # noqa: E402
from test_validate_b1 import CORE, B1Case, card  # noqa: E402
import validate_decks  # noqa: E402

CID = "zz-9001"
PATH = f"decks/zz/audio/{CID}.opus"
CREDIT = {"source": "https://commons.wikimedia.org/wiki/File:Voiceless_bilabial_plosive.ogg",
          "license": "CC-BY-SA-4.0", "credit": "A. Speaker"}


class Audio(B1Case):

    def clip(self, data: bytes, cid: str = CID) -> None:
        path = self.dir / "audio" / f"{cid}.opus"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def give(self, **credit: object) -> None:
        """The card names its recording, with CREDIT changed by [credit]."""
        self.edit(CORE, lambda d: card(d, CID).update(
            audio=PATH, audio_credit={**CREDIT, **credit}))

    def audio_errors(self) -> list[str]:
        return [e for e in self.errors(CORE) if "audio" in e]

    def test_a_small_mono_opus_clip_is_valid(self) -> None:
        self.clip(make_opus(1.0, 32))
        self.give()
        self.assertEqual(self.audio_errors(), [])

    def test_a_card_with_no_audio_is_valid(self) -> None:
        # The phone's text-to-speech says it, as before.
        self.assertEqual(self.audio_errors(), [])
        self.assertNoError(CORE)
        self.assertEqual(validate_decks.audio_totals([validate_decks.validate(self.p(CORE))]), {})

    def test_the_fixture_streams_are_what_the_validator_reads(self) -> None:
        self.assertEqual(validate_decks.ogg_opus_facts(make_opus(0.5, 24)), (1, 0.5))
        self.assertEqual(validate_decks.ogg_opus_facts(make_opus(0.5, 24, channels=2)),
                         (2, 0.5))

    def test_another_container_is_refused(self) -> None:
        for name, data in (("a RIFF wave file", b"RIFF" + bytes(100)),
                           ("mp3", b"ID3" + bytes(100)),
                           ("the old stub", b"OggS")):
            with self.subTest(name):
                self.clip(data)
                self.give()
                self.assertNotEqual(self.audio_errors(), [])
                self.assertTrue(any(f"audio {PATH}:" in e for e in self.audio_errors()))

    def test_ogg_vorbis_is_refused_as_not_opus(self) -> None:
        self.clip(make_vorbis())
        self.give()
        self.assertTrue(any("Ogg Vorbis" in e and "Ogg Opus" in e
                            for e in self.audio_errors()), self.audio_errors())

    def test_a_cut_short_stream_is_refused(self) -> None:
        self.clip(make_opus(1.0, 32)[:-7])
        self.give()
        self.assertTrue(any("damaged or cut short" in e for e in self.audio_errors()))

    def test_stereo_is_refused(self) -> None:
        self.clip(make_opus(0.5, 24, channels=2))
        self.give()
        self.assertTrue(any("2 channels; recordings are mono" in e
                            for e in self.audio_errors()), self.audio_errors())

    def test_over_128_kbps_is_refused(self) -> None:
        self.clip(make_opus(0.1, 160))
        self.give()
        errors = self.audio_errors()
        self.assertTrue(any("kbps" in e and "at most 128 kbps" in e for e in errors), errors)
        self.assertFalse(any("bytes" in e for e in errors), errors)  # small enough

    def test_exactly_the_cap_and_a_little_under_pass_the_bitrate_check(self) -> None:
        self.clip(make_opus(0.1, 110))
        self.give()
        self.assertEqual([e for e in self.audio_errors() if "kbps" in e], [])

    def test_over_the_size_cap_is_refused(self) -> None:
        self.clip(make_opus(5.0, 32))   # about 20 kB, at a fine bitrate
        self.give()
        errors = self.audio_errors()
        self.assertTrue(any("at most 16384 bytes" in e for e in errors), errors)
        self.assertFalse(any("kbps" in e for e in errors), errors)

    def test_a_missing_file_is_refused(self) -> None:
        self.give()
        self.assertTrue(any(f"audio {PATH} has no file" in e for e in self.audio_errors()))

    def test_a_missing_credit_is_refused(self) -> None:
        self.clip(make_opus(0.5, 24))
        self.edit(CORE, lambda d: card(d, CID).update(audio=PATH))
        self.assertTrue(any("audio_credit is required with audio" in e
                            for e in self.audio_errors()))

    def test_an_incomplete_credit_names_what_is_missing(self) -> None:
        self.clip(make_opus(0.5, 24))
        for key in ("source", "license", "credit"):
            with self.subTest(key):
                self.edit(CORE, lambda d: card(d, CID).update(
                    audio=PATH,
                    audio_credit={k: v for k, v in CREDIT.items() if k != key}))
                self.assertTrue(any(f"audio_credit.{key} is required" in e
                                    for e in self.audio_errors()), self.audio_errors())

    def test_the_source_must_be_a_link(self) -> None:
        self.clip(make_opus(0.5, 24))
        self.give(source="Wikimedia Commons")
        self.assertTrue(any("audio_credit.source must be the link" in e
                            for e in self.audio_errors()))

    def test_noncommercial_and_noderivatives_licences_are_refused_by_name(self) -> None:
        self.clip(make_opus(0.5, 24))
        for licence in ("CC-BY-NC-4.0", "CC-BY-NC-SA-3.0", "CC-BY-ND-4.0", "CC-BY-NC-ND-2.0"):
            with self.subTest(licence):
                self.give(license=licence)
                errors = self.audio_errors()
                self.assertTrue(any("NonCommercial (NC) and NoDerivatives (ND) licences are "
                                    "never allowed" in e for e in errors), errors)

    def test_other_licences_that_cannot_ship_are_refused(self) -> None:
        self.clip(make_opus(0.5, 24))
        for licence in ("GFDL-1.2", "CC-BY-SA-1.0", "all-rights-reserved"):
            with self.subTest(licence):
                self.give(license=licence)
                self.assertTrue(any("cannot ship in a CC BY-SA 4.0 deck" in e
                                    for e in self.audio_errors()))

    def test_the_licences_on_the_allow_list_pass(self) -> None:
        self.clip(make_opus(0.5, 24))
        for licence in ("CC0-1.0", "public-domain", "CC-BY-3.0", "CC-BY-4.0",
                        "CC-BY-SA-2.5", "CC-BY-SA-3.0-DE", "CC-BY-SA-4.0"):
            with self.subTest(licence):
                self.give(license=licence)
                self.assertEqual(self.audio_errors(), [])


class Totals(unittest.TestCase):

    def reports(self, sizes: dict[str, int]) -> list[validate_decks.Report]:
        rep = validate_decks.Report(Path("decks/zz/zz-home.yaml"))
        rep.audio_bytes = dict(sizes)
        return [rep]

    def test_under_the_ceiling_passes(self) -> None:
        reports = self.reports({"decks/zz/audio/zz-0001.opus": 10_000})
        self.assertEqual(validate_decks.check_audio_total(reports), [])

    def test_over_the_ceiling_fails_with_the_numbers(self) -> None:
        ceiling = validate_decks.AUDIO_TOTAL_MAX_BYTES
        reports = self.reports({"decks/zz/audio/zz-0001.opus": ceiling,
                                "decks/yy/audio/yy-0001.opus": 1})
        problems = validate_decks.check_audio_total(reports)
        self.assertEqual(len(problems), 1)
        self.assertIn(str(ceiling + 1), problems[0])
        self.assertIn("50 MB", problems[0])

    def test_a_file_two_decks_name_counts_once(self) -> None:
        sizes = {"decks/zz/audio/zz-0001.opus": 100}
        reports = self.reports(sizes) + self.reports(sizes)
        self.assertEqual(validate_decks.audio_totals(reports), {"zz": 100})

    def test_the_report_lists_each_language_and_never_fails(self) -> None:
        reports = self.reports({"decks/zz/audio/zz-0001.opus": 100,
                                "decks/zz/audio/zz-0002.opus": 50,
                                "decks/yy/audio/yy-0001.opus": 7})
        lines = validate_decks.audio_report(reports)
        self.assertIn("  yy: 1 files, 7 bytes", lines)
        self.assertIn("  zz: 2 files, 150 bytes", lines)
        self.assertTrue(lines[-1].startswith("  all: 3 files, 157 bytes of"))


class AudioReportFlag(B1Case):

    def test_the_flag_prints_the_report_and_keeps_the_exit_code(self) -> None:
        path = self.dir / "audio" / f"{CID}.opus"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(make_opus(0.5, 24))
        self.edit(CORE, lambda d: card(d, CID).update(audio=PATH, audio_credit=CREDIT))
        plain = self.run_main()
        plain_code = self.code
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = validate_decks.main(["validate_decks.py", "--audio-report", str(self.dir)])
        lines = out.getvalue().splitlines()
        self.assertTrue(any(ln.startswith("  zz: 1 files,") for ln in lines), lines)
        self.assertEqual(code, plain_code)
        self.assertFalse(any(ln.startswith("  zz: 1 files,") for ln in plain))


if __name__ == "__main__":
    unittest.main()
