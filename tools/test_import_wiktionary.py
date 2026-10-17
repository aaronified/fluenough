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

    def test_without_write_nothing_changes(self) -> None:
        before = self.text(CORE), self.text(LAYER)
        code, out, _ = self.run_tool(write=False)
        self.assertEqual(code, 0)
        self.assertEqual((self.text(CORE), self.text(LAYER)), before)
        self.assertIn("# Wiktionary import: zz (zz)", out)

    def test_the_report_pins_the_dump_and_counts(self) -> None:
        _, out, _ = self.run_tool(write=False)
        self.assertIn("- Dump: kaikki.org Testlang.jsonl, 2026-10-13, sha256 ", out)
        self.assertIn("- Core vocab cards: 6", out)
        self.assertIn("- Matched one entry: 4 (66%)", out)
        self.assertIn("- Ambiguous (more than one entry fits): 1 (16%)", out)
        self.assertIn("- Not in Wiktionary: 1 (16%)", out)
        self.assertIn("- Written in flow style, left alone: zz-9006", out)
        self.assertIn("| `ipa` | 4 |", out)
        self.assertIn("- `ipa` (1): zz-9007 रसोईघर", out)
        self.assertIn("Examples left out because a word is not taught: 1.", out)
        self.assertIn("Recordings Wiktionary links for exactly a card's text: 1.", out)

    def test_the_dump_date_is_in_the_report_only(self) -> None:
        self.run_tool()
        self.assertNotIn("kaikki.org", self.text(CORE) + self.text(LAYER))
        self.assertNotIn("2026-10-13", self.text(CORE) + self.text(LAYER))

    def test_the_report_to_a_file(self) -> None:
        path = self.tmp / "report.md"
        code, out, _ = self.run_tool("--report", str(path), write=False)
        self.assertEqual(code, 0)
        self.assertIn("## Still missing", path.read_text(encoding="utf-8"))
        self.assertEqual(out, f"wrote {path}\n")


class Fill(Case):

    def setUp(self) -> None:
        super().setUp()
        self.assertEqual(self.run_tool()[0], 0)

    def test_the_files_still_validate(self) -> None:
        for rel in (CORE, LAYER):
            self.assertEqual(vd.validate(self.decks / rel).errors, [], rel)

    def test_ipa_gender_and_own_root(self) -> None:
        house = self.card(CORE, "zz-9001")
        self.assertEqual(house["ipa"], "ɡʱəɾ")
        self.assertEqual(house["gender"], "m")
        self.assertEqual(house["bases"], "self")

    def test_what_is_there_is_kept(self) -> None:
        building = self.card(CORE, "zz-9002")
        self.assertEqual(building["ipa"], "məkaːn")
        self.assertEqual(building["synonyms"], [{"id": "home", "ref": "zz-9001"}])

    def test_a_meaning_never_changes(self) -> None:
        for cid, native in (("zz-9001", "house; home"), ("zz-9004", "big"),
                            ("zz-9003", "yesterday; tomorrow")):
            self.assertEqual(self.card(LAYER, cid)["native"], native)

    def test_synonyms_by_ref_or_word_with_source(self) -> None:
        src = SRC.format("घर")
        self.assertEqual(self.card(CORE, "zz-9001")["synonyms"], [
            {"id": "syn1", "ref": "zz-9002", "source": src},
            {"id": "nivas", "word": "निवास", "reading": "nivās", "source": src}])
        self.assertEqual(self.card(LAYER, "zz-9001")["synonyms"],
                         {"nivas": "abode, dwelling"})

    def test_antonyms(self) -> None:
        self.assertEqual(self.card(CORE, "zz-9004")["antonyms"], [
            {"id": "chota", "word": "छोटा", "reading": "chōṭā",
             "source": SRC.format("बड़ा")}])
        self.assertEqual(self.card(LAYER, "zz-9004")["antonyms"], {"chota": "small, little"})

    def test_examples_only_of_taught_words(self) -> None:
        examples = self.card(CORE, "zz-9001")["examples"]
        self.assertEqual([e["target"] for e in examples], ["घर बड़ा है।", "घर बड़े हैं।"])
        self.assertEqual(examples[1]["bases"], [{"word": "बड़े", "ref": "zz-9004"},
                                                {"word": "हैं", "ref": "zz-9005"}])
        self.assertEqual(examples[0]["source"], SRC.format("घर"))
        self.assertEqual(self.card(LAYER, "zz-9001")["examples"],
                         {"घर बड़ा है।": "The house is big.",
                          "घर बड़े हैं।": "The houses are big."})

    def test_forms(self) -> None:
        self.assertEqual([(f["kind"], f["word"]) for f in self.card(CORE, "zz-9001")["forms"]],
                         [("oblique-plural", "घरों")])
        self.assertEqual([(f["kind"], f["word"]) for f in self.card(CORE, "zz-9004")["forms"]],
                         [("feminine", "बड़ी")])

    def test_senses_with_their_meanings(self) -> None:
        self.assertEqual([s["id"] for s in self.card(CORE, "zz-9004")["senses"]],
                         ["big", "elder"])
        self.assertEqual(self.card(LAYER, "zz-9004")["senses"],
                         {"big": {"native": "big, large"}, "elder": {"native": "elder"}})

    def test_an_ambiguous_card_gets_only_an_agreed_ipa(self) -> None:
        self.assertEqual(self.card(CORE, "zz-9003"), {
            "id": "zz-9003", "target": "कल", "reading": "kal", "ipa": "kəl", "pos": "adv"})
        self.assertNotIn("wiktionary", self.card(LAYER, "zz-9003"))

    def test_an_inflected_form_is_not_its_own_root(self) -> None:
        self.assertNotIn("bases", self.card(CORE, "zz-9005"))

    def test_a_flow_style_card_is_left_alone(self) -> None:
        self.assertIn('  - { id: "zz-9006", target: "पानी", reading: "pānī", pos: "noun" }',
                      self.text(CORE))

    def test_the_wiktionary_link(self) -> None:
        self.assertIs(self.card(LAYER, "zz-9001")["wiktionary"], True)

    def test_a_second_run_adds_nothing(self) -> None:
        before = self.text(CORE), self.text(LAYER)
        self.run_tool()
        self.assertEqual((self.text(CORE), self.text(LAYER)), before)


class Recordings(Case):

    def run_audio(self, network: Network) -> tuple[int, str, str]:
        with mock.patch.object(iw, "http_get", network), \
                mock.patch.object(iw, "convert", fake_convert), \
                mock.patch.object(iw.shutil, "which", return_value="/usr/bin/ffmpeg"):
            return self.run_tool("--audio")

    def test_a_recording_of_exactly_the_word(self) -> None:
        network = Network({"commons.wikimedia.org/w/api.php": commons_reply("Hi-घर.ogg"),
                           "upload.wikimedia.org/Hi-": b"OggS"})
        code, out, _ = self.run_audio(network)
        self.assertEqual(code, 0)
        house = self.card(CORE, "zz-9001")
        self.assertEqual(house["audio"], "decks/zz/audio/zz-9001.opus")
        self.assertEqual(house["audio_credit"], {
            "source": "https://commons.wikimedia.org/wiki/File:Hi-घर.ogg",
            "license": "CC-BY-SA-4.0", "credit": "A. Speaker"})
        self.assertEqual((self.decks / "zz/audio/zz-9001.opus").read_bytes(), b"converted")
        self.assertIn("| `audio` | 1 |", out)
        self.assertEqual(vd.validate(self.decks / CORE).errors, [])

    def test_a_licence_that_cannot_ship_is_skipped(self) -> None:
        network = Network({"commons.wikimedia.org/w/api.php":
                           commons_reply("Hi-घर.ogg", licence="GFDL")})
        code, out, _ = self.run_audio(network)
        self.assertEqual(code, 0)
        self.assertNotIn("audio", self.card(CORE, "zz-9001"))
        self.assertFalse((self.decks / "zz/audio").exists())
        self.assertIn("zz-9001 घर: Hi-घर.ogg: licence 'GFDL' cannot ship in a CC BY-SA "
                      "4.0 deck", out)

    def test_no_speaker_to_credit_is_skipped(self) -> None:
        network = Network({"commons.wikimedia.org/w/api.php":
                           commons_reply("Hi-घर.ogg", artist="")})
        _, out, _ = self.run_audio(network)
        self.assertNotIn("audio", self.card(CORE, "zz-9001"))
        self.assertIn("Commons names no speaker to credit", out)

    def test_without_ffmpeg_a_clear_error(self) -> None:
        with mock.patch.object(iw.shutil, "which", return_value=None):
            code, _, err = self.run_tool("--audio")
        self.assertEqual(code, 2)
        self.assertIn("error: ffmpeg is not installed", err)
        self.assertNotIn("ipa", self.card(CORE, "zz-9001"))

    def test_without_write_nothing_is_downloaded(self) -> None:
        network = Network({})
        with mock.patch.object(iw, "http_get", network), \
                mock.patch.object(iw.shutil, "which", return_value="/usr/bin/ffmpeg"):
            self.run_tool("--audio", write=False)
        self.assertEqual(network.asked, [])


SECTIONS = json.dumps({"parse": {"sections": [
    {"level": "2", "line": "Nepali", "index": "1"},
    {"level": "2", "line": "Testlang", "index": "4"}]}}).encode()


class Images(Case):
    """A card's own image (#523): the Wiktionary page's one Commons picture,
    then OpenMoji, for a card with a picture; never Wikidata."""

    def run_images(self, network: Network, *extra: str) -> tuple[int, str, str]:
        with mock.patch.object(iw, "http_get", network), \
                mock.patch.object(iw, "convert", fake_convert), \
                mock.patch.object(iw.shutil, "which", return_value="/usr/bin/ffmpeg"):
            return self.run_tool("--images", *extra)

    def test_the_wiktionary_page_first(self) -> None:
        network = Network({
            "prop=sections": SECTIONS,
            "prop=images": json.dumps({"parse": {"images": [
                "Wiktionary-logo.svg", "A house.jpg"]}}).encode(),
            "commons.wikimedia.org/w/api.php": commons_reply(
                "A house.jpg", artist="<span>A. Photographer</span>"),
            "upload.wikimedia.org/thumb/": b"PNG"})
        code, out, _ = self.run_images(network)
        self.assertEqual(code, 0)
        house = self.card(CORE, "zz-9001")
        self.assertEqual(house["image"], "decks/zz/images/zz-9001.webp")
        self.assertEqual(house["image_credit"], {
            "source": "https://commons.wikimedia.org/wiki/File:A house.jpg",
            "license": "CC-BY-SA-4.0", "credit": "A. Photographer"})
        self.assertTrue(any("section=4" in url for url in network.asked))
        self.assertTrue(any(url.startswith("https://upload.wikimedia.org/thumb/")
                            for url in network.asked))
        self.assertEqual((self.decks / "zz/images/zz-9001.webp").read_bytes(), b"converted")
        self.assertIn("Images by source: wiktionary 1.", out)
        self.assertEqual(vd.validate(self.decks / CORE).errors, [])

    def test_never_wikidata(self) -> None:
        network = Network({"openmoji": b"PNG"})
        self.run_images(network)
        self.assertFalse(any("wikidata" in url for url in network.asked))
        self.assertFalse(hasattr(iw, "wikidata_image"))

    def test_two_pictures_on_the_page_are_none(self) -> None:
        network = Network({
            "prop=sections": SECTIONS,
            "prop=images": json.dumps({"parse": {"images": [
                "A house.jpg", "Another house.jpg"]}}).encode(),
            "openmoji@15.1.0/color/618x618/1F3E0.png": b"PNG"})
        _, out, _ = self.run_images(network)
        self.assertEqual(self.card(CORE, "zz-9001")["image_credit"]["credit"], "OpenMoji")
        self.assertFalse(any("commons.wikimedia.org" in url for url in network.asked))

    def test_then_openmoji(self) -> None:
        network = Network({
            "prop=sections": SECTIONS,
            "prop=images": json.dumps({"parse": {"images": ["House.jpg"]}}).encode(),
            "commons.wikimedia.org/w/api.php": commons_reply("House.jpg", licence="GFDL"),
            "openmoji@15.1.0/color/618x618/1F3E0.png": b"PNG"})
        _, out, _ = self.run_images(network)
        self.assertEqual(self.card(CORE, "zz-9001")["image_credit"], {
            "source": "https://openmoji.org/library/emoji-1F3E0/",
            "license": "CC-BY-SA-4.0", "credit": "OpenMoji"})
        self.assertIn("Images by source: openmoji 1.", out)

    def test_none_and_the_card_keeps_its_noto_picture(self) -> None:
        _, out, _ = self.run_images(Network({}))
        house = self.card(CORE, "zz-9001")
        self.assertNotIn("image", house)
        self.assertEqual(house["picture"], "🏠")
        self.assertIn("Images not imported (the card keeps its Noto picture):", out)
        self.assertIn("- zz-9001 घर: ", out)

    def test_only_for_a_card_with_a_picture(self) -> None:
        network = Network({"openmoji": b"PNG"})
        self.run_images(network)
        for cid in ("zz-9002", "zz-9003", "zz-9004", "zz-9005", "zz-9007"):
            self.assertNotIn("image", self.card(CORE, cid))

    def test_the_emoji_names(self) -> None:
        self.assertEqual(iw.emoji_hex("🏠"), ["1F3E0"])
        self.assertEqual(iw.emoji_hex("\u2764\ufe0f"), ["2764", "2764-FE0F"])


def page_with(name: str, licence: str = "CC BY 2.0") -> Network:
    """Every Wiktionary page with one picture, [name], under [licence]."""
    return Network({
        "prop=sections": SECTIONS,
        "prop=images": json.dumps({"parse": {"images": [name]}}).encode(),
        "commons.wikimedia.org/w/api.php": commons_reply(name, licence=licence),
        "upload.wikimedia.org/thumb/": b"PNG",
        "openmoji": b"PNG"})


class Proposals(Case):
    """A noun card without a picture (#523, owner, 2026-10-16: "Also mark
    concrete", "Importer proposes"): its image is proposed in the report,
    and written only once approved."""

    run_images = Images.run_images

    def test_proposed_not_written(self) -> None:
        network = page_with("A building.jpg")
        code, out, _ = self.run_images(network)
        self.assertEqual(code, 0)
        self.assertNotIn("image", self.card(CORE, "zz-9002"))
        self.assertFalse((self.decks / "zz/images/zz-9002.webp").exists())
        self.assertIn("## Image proposals", out)
        self.assertIn("| zz-9002 | मकान | A building.jpg | CC-BY-2.0 | A. Speaker "
                      "| https://commons.wikimedia.org/wiki/File:A building.jpg "
                      "| https://en.wiktionary.org/wiki/मकान |", out)
        # Only zz-9001's picture is downloaded, not the proposed one.
        self.assertEqual(len([u for u in network.asked if "upload.wikimedia.org" in u]), 1)

    def test_nouns_verbs_and_adjectives(self) -> None:
        """"Nouns, verbs, adjectives" (owner, 2026-10-16): zz-9004 is an
        adjective and zz-9005 a verb; a card with a picture or an adverb
        gets none."""
        _, out, _ = self.run_images(page_with("A building.jpg"))
        for cid in ("zz-9002", "zz-9004", "zz-9005"):
            self.assertIn(f"| {cid} |", out)
        for cid in ("zz-9001", "zz-9003"):
            self.assertNotIn(f"| {cid} |", out)

    def test_a_pronoun_gets_no_proposal(self) -> None:
        dump = self.tmp / "Testlang.jsonl"
        rows = [json.loads(x) for x in DUMP.read_text(encoding="utf-8").splitlines()]
        for row in rows:
            if row["word"] == "मकान":
                row["pos"] = "pron"
        dump.write_text("\n".join(json.dumps(x, ensure_ascii=False) for x in rows),
                        encoding="utf-8")
        core = self.decks / CORE
        core.write_text(core.read_text(encoding="utf-8").replace(
            'target: "मकान"\n    reading: "makān"\n    ipa: "məkaːn"\n    pos: "noun"',
            'target: "मकान"\n    reading: "makān"\n    ipa: "məkaːn"\n    pos: "pronoun"'),
            encoding="utf-8")
        self.assertEqual(self.card(CORE, "zz-9002")["pos"], "pronoun")
        argv = ["import_wiktionary.py", "zz", str(dump), "--decks", str(self.decks),
                "--dump-date", "2026-10-13", "--images"]
        out = io.StringIO()
        with mock.patch.object(iw, "http_get", page_with("A building.jpg")), \
                mock.patch.object(iw.shutil, "which", return_value="/usr/bin/ffmpeg"), \
                contextlib.redirect_stdout(out):
            self.assertEqual(iw.main(argv), 0)
        self.assertNotIn("| zz-9002 |", out.getvalue())
        self.assertIn("| zz-9004 |", out.getvalue())

    def test_proposed_without_write(self) -> None:
        network = page_with("A building.jpg")
        with mock.patch.object(iw, "http_get", network), \
                mock.patch.object(iw, "convert", fake_convert), \
                mock.patch.object(iw.shutil, "which", return_value="/usr/bin/ffmpeg"):
            _, out, _ = self.run_tool("--images", write=False)
        self.assertIn("| zz-9002 | मकान | A building.jpg |", out)
        self.assertFalse((self.decks / "zz/images").exists())

    def test_a_picture_that_cannot_ship_is_not_proposed(self) -> None:
        _, out, _ = self.run_images(page_with("A building.jpg", licence="GFDL"))
        self.assertNotIn("## Image proposals", out)
        self.assertIn("Pictures not proposed:", out)
        self.assertIn("- zz-9002 मकान: A building.jpg: licence 'GFDL' cannot ship", out)

    def test_approved_is_written(self) -> None:
        code, out, _ = self.run_images(page_with("A building.jpg"),
                                    "--approve", "zz-9002=A building.jpg")
        self.assertEqual(code, 0)
        building = self.card(CORE, "zz-9002")
        self.assertEqual(building["image"], "decks/zz/images/zz-9002.webp")
        self.assertEqual(building["image_credit"], {
            "source": "https://commons.wikimedia.org/wiki/File:A building.jpg",
            "license": "CC-BY-2.0", "credit": "A. Speaker"})
        self.assertNotIn("picture", building)
        self.assertNotIn("| zz-9002 |", out)
        self.assertEqual(vd.validate(self.decks / CORE).errors, [])

    def test_an_approval_that_fits_no_proposal(self) -> None:
        _, out, _ = self.run_images(page_with("A building.jpg"), "--approve",
                                    "zz-9001=A building.jpg,zz-9003=A building.jpg")
        self.assertIn("Approved images not imported:", out)
        self.assertIn("- zz-9001: not a noun, verb or adjective card without a picture", out)
        self.assertIn("- zz-9003: not a noun, verb or adjective card without a picture", out)
        self.assertNotIn("image", self.card(CORE, "zz-9003"))

    def test_an_approval_pins_the_file(self) -> None:
        code, out, _ = self.run_images(page_with("A building.jpg"),
                                       "--approve", "zz-9002=Another.jpg")
        self.assertEqual(code, 0)
        self.assertNotIn("image", self.card(CORE, "zz-9002"))
        self.assertFalse((self.decks / "zz/images/zz-9002.webp").exists())
        self.assertIn("Approved images not imported:", out)
        self.assertIn("- zz-9002 मकान: approved Another.jpg but the proposal is "
                      "A building.jpg", out)
        self.assertIn("| zz-9002 | मकान | A building.jpg |", out)

    def test_a_bare_id_is_refused(self) -> None:
        for item in ("zz-9002", "zz-9002=", "=A building.jpg"):
            code, _, err = self.run_images(page_with("A building.jpg"), "--approve", item)
            self.assertEqual(code, 2)
            self.assertIn("a pinned file is required", err)
            self.assertNotIn("image", self.card(CORE, "zz-9002"))

    def test_verbs_and_adjectives_are_approved(self) -> None:
        code, _, _ = self.run_images(page_with("A big.jpg"), "--approve",
                                     "zz-9004=A big.jpg", "--approve", "zz-9005=A big.jpg")
        self.assertEqual(code, 0)
        for cid in ("zz-9004", "zz-9005"):
            self.assertEqual(self.card(CORE, cid)["image"], f"decks/zz/images/{cid}.webp")

    def test_approve_needs_images_and_write(self) -> None:
        for extra, write in ((("--approve", "zz-9002=A building.jpg"), True),
                             (("--images", "--approve", "zz-9002=A building.jpg"), False)):
            with mock.patch.object(iw.shutil, "which", return_value="/usr/bin/ffmpeg"):
                code, _, err = self.run_tool(*extra, write=write)
            self.assertEqual(code, 2)
            self.assertIn("--approve needs --images and --write", err)


class Licences(unittest.TestCase):

    def test_licence_ids(self) -> None:
        for short, want in (("CC BY-SA 4.0", "CC-BY-SA-4.0"), ("CC BY 2.0", "CC-BY-2.0"),
                            ("CC BY-SA 3.0 de", "CC-BY-SA-3.0-DE"), ("CC0", "CC0-1.0"),
                            ("Public domain", "public-domain"), ("GFDL", None),
                            ("CC BY-NC-SA 4.0", None), ("CC BY-ND 4.0", None)):
            self.assertEqual(iw.licence_id(short), want, short)

    def test_a_gloss_quoting_the_language_is_left_out(self) -> None:
        self.assertIsNone(iw._gloss({"glosses": ["then; तो"]}))
        self.assertEqual(iw._gloss({"glosses": ["café."]}), "café")

    def test_a_reconstruction_is_no_word(self) -> None:
        self.assertFalse(iw._plain_word("* मार्ग"))
        self.assertTrue(iw._plain_word("मार्ग"))

    def test_html_credit(self) -> None:
        self.assertEqual(iw.strip_html('<a href="x">A&amp;B</a>  <span>C</span>'), "A&B C")


class Arguments(Case):

    def test_no_decks_for_the_language(self) -> None:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = iw.main(["x", "qq", str(DUMP), "--decks", str(self.decks)])
        self.assertEqual(code, 2)
        self.assertIn("error: no decks for 'qq'", err.getvalue())

    def test_no_dump(self) -> None:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = iw.main(["x", "zz", str(self.tmp / "none.jsonl"), "--decks",
                            str(self.decks)])
        self.assertEqual(code, 2)
        self.assertIn("does not exist", err.getvalue())

    def test_a_bad_date(self) -> None:
        code, _, err = self.run_tool("--dump-date", "13/10/2026", write=False)
        self.assertEqual(code, 2)
        self.assertIn("--dump-date must be YYYY-MM-DD", err)


if __name__ == "__main__":
    unittest.main()
