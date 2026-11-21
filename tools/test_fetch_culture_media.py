#!/usr/bin/env python3
"""Tests for tools/fetch_culture_media.py (ADR-0060, work package 2), on a
small creators and recommendations pair of files as the language zz and a fake
Wikimedia (Wikidata, Commons and the file server): no network, and no ffmpeg
(the encode step is replaced by a stub that builds small WebP headers by hand).
One optional test uses the real ffmpeg and is skipped without it.

Stdlib `unittest` plus PyYAML, like the tool.
"""

from __future__ import annotations

import contextlib
import copy
import datetime
import hashlib
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

import fetch_culture_media as fcm  # noqa: E402
import import_wiktionary as iw  # noqa: E402
import validate_decks as vd  # noqa: E402
import wikimedia_client as wc  # noqa: E402

TODAY = datetime.date(2025, 1, 1)

CREATORS = '''\
# The people of Zedish. A comment the tool must leave alone.
schema: 1
kind: "creators"
id: "creators-zz"
language: "zz"
license: "CC-BY-SA-4.0"
creators:
  - id: "zz-ada"
    name:
      en: { text: "Ada Zed" }
    born: 1815
    died: 1852
    bio:
      en: "A poet."
  - id: "zz-bob"
    name:
      en: { text: "Bob Zed" }
    born: 1800
    died: 1860
  - id: "zz-cy"
    name:
      en: { text: "Cy Zed" }
    born: 1801
    died: 1861
  - id: "zz-dee"
    name:
      en: { text: "Dee Zed" }
    born: 1970
    living: true
  - id: "zz-eve"
    name:
      en: { text: "Eve Zed" }
    born: 1820
    died: 1880
  - id: "zz-fay"
    name:
      en: { text: "Fay Zed" }
    born: 1830
    died: 1890
    wikidata: "Q160"
  - id: "zz-gus"
    name:
      en: { text: "Gus Zed" }
    born: 1900
    died: 2024
  - id: "zz-hal"
    name:
      en: { text: "Hal Zed" }
    born: 1810
    died: 1870
  - id: "zz-ian"
    name:
      en: { text: "Ian Zed" }
    born: 1812
    died: 1872
  - id: "zz-joy"
    name:
      en: { text: "Joy Zed" }
    born: 1840
    died: 1900
'''

RECS = '''\
# The works of Zedish.
schema: 1
kind: "recommendations"
id: "recommendations-zz"
language: "zz"
license: "CC-BY-SA-4.0"
recommendations:
  - id: "zz-rec-song"
    medium: "book"
    title: { text: "The Zed Song" }
    creator: ["zz-ada"]
    year: 1850
    level: "B1"
  - id: "zz-rec-lost"
    medium: "film"
    title: { text: "The Lost Reel" }
    creator: ["zz-ada"]
    year: 1920
    level: "B1"
  - id: "zz-rec-wrong"
    medium: "book"
    title: { text: "The Wrong Year" }
    creator: ["zz-ada"]
    year: 1851
    level: "B1"
'''


def webp(width: int, height: int, pad: int = 100) -> bytes:
    """A WebP header (lossy `VP8 ` chunk) that vd.image_size reads."""
    body = b"\x00\x00\x00\x9d\x01\x2a" + width.to_bytes(2, "little") \
        + height.to_bytes(2, "little") + b"\x00" * pad
    return b"RIFF" + (4 + 8 + len(body)).to_bytes(4, "little") + b"WEBP" + b"VP8 " \
        + len(body).to_bytes(4, "little") + body


def claim(value: object) -> dict:
    return {"rank": "normal", "mainsnak": {"snaktype": "value",
                                           "datavalue": {"value": value}}}


def when(year: int) -> dict:
    return {"time": f"+{year:04d}-01-01T00:00:00Z", "precision": 9}


def person(qid: str, label: str, born: int | None, died: int | None,
           files: list[str] | None = None) -> dict:
    claims: dict = {"P31": [claim({"id": "Q5"})]}
    if born is not None:
        claims["P569"] = [claim(when(born))]
    if died is not None:
        claims["P570"] = [claim(when(died))]
    if files:
        claims["P18"] = [claim(f) for f in files]
    return {"id": qid, "labels": {"en": {"value": label}}, "descriptions":
            {"en": {"value": "a person"}}, "claims": claims}


def work(qid: str, label: str, kind: str, year: int, creator: str, **props: list[str]
         ) -> dict:
    claims: dict = {"P31": [claim({"id": kind})], "P577": [claim(when(year))],
                    "P50": [claim({"id": creator})]}
    for prop, names in props.items():
        claims[prop] = [claim(n) for n in names]
    return {"id": qid, "labels": {"en": {"value": label}}, "claims": claims}


def info(name: str, licence: str = "CC BY-SA 4.0", artist: str | None = "Jo <b>Doe</b>",
         width: int = 800, height: int = 600, size: int = 50000, url: str | None = None,
         restrictions: str = "") -> dict:
    meta = {"LicenseShortName": {"value": licence},
            "LicenseUrl": {"value": "http://creativecommons.org/licenses/by-sa/4.0"},
            "Restrictions": {"value": restrictions}}
    if artist is not None:
        meta["Artist"] = {"value": artist}
    path = name.replace(" ", "_")
    return {"url": url or f"https://upload.wikimedia.org/wikipedia/commons/a/ab/{path}",
            "descriptionurl": f"https://commons.wikimedia.org/wiki/File:{path}",
            "mime": "image/jpeg", "size": size, "width": width, "height": height,
            "extmetadata": meta}


ENTITIES = {
    "Q100": person("Q100", "Ada Zed", 1815, 1852, ["Ada.jpg"]),
    "Q101": person("Q101", "Bob Zed", 1800, 1860, ["Bob.jpg"]),
    "Q102": person("Q102", "Cy Zed", 1801, 1861, ["Cy.jpg"]),
    "Q103": person("Q103", "Dee Zed", 1970, None, ["Dee.jpg"]),
    "Q104": person("Q104", "Eve Zed", 1820, 1880, ["Eve1.jpg"]),
    "Q1041": person("Q1041", "Eve Zed", 1820, 1880, ["Eve2.jpg"]),
    "Q160": person("Q160", "Fay Zed", 1830, 1890, ["Fay.jpg"]),
    "Q107": person("Q107", "Gus Zed", 1900, 2024, ["Gus.jpg"]),
    "Q108": person("Q108", "Hal Zed", 1700, 1770, ["Hal.jpg"]),     # wrong dates
    "Q109": person("Q109", "Ian Zed", 1812, 1872, ["Missing.jpg"]),
    "Q110": person("Q110", "Joy Zed", 1840, 1900, ["Joy Tall.jpg"]),
    "Q300": work("Q300", "The Zed Song", "Q571", 1850, "Q100",
                 P996=["Song page.jpg"], P18=["Song cover.jpg"]),
    "Q301": work("Q301", "The Lost Reel", "Q11424", 1920, "Q100",
                 P996=["Reel scan.jpg"], P18=["Reel still.jpg"], P3383=["Reel poster.jpg"]),
    "Q302": work("Q302", "The Wrong Year", "Q571", 1899, "Q100", P18=["Wrong.jpg"]),
}
SEARCH = {"ada zed": ["Q100"], "bob zed": ["Q101"], "cy zed": ["Q102"],
          "dee zed": ["Q103"], "eve zed": ["Q104", "Q1041"], "gus zed": ["Q107"],
          "hal zed": ["Q108"], "ian zed": ["Q109"], "joy zed": ["Q110"],
          "the zed song": ["Q300"], "the lost reel": ["Q301"],
          "the wrong year": ["Q302"]}
FILES = {
    "File:Ada.jpg": info("Ada.jpg"),
    "File:Bob.jpg": info("Bob.jpg", artist=None),
    "File:Cy.jpg": info("Cy.jpg", licence="CC BY-NC 4.0"),
    "File:Dee.jpg": info("Dee.jpg"),
    "File:Eve1.jpg": info("Eve1.jpg"),
    "File:Eve2.jpg": info("Eve2.jpg"),
    "File:Fay.jpg": info("Fay.jpg", url="https://upload.wikimedia.org/wikipedia/en/f/fa/Fay.jpg"),
    "File:Gus.jpg": info("Gus.jpg"),
    "File:Hal.jpg": info("Hal.jpg"),
    "File:Joy Tall.jpg": info("Joy Tall.jpg", width=3000, height=6000, size=9_000_000),
    "File:Song page.jpg": info("Song page.jpg", licence="Public domain", artist=None),
    "File:Song cover.jpg": info("Song cover.jpg", licence="CC BY 2.0", width=3000, height=2000),
    "File:Reel poster.jpg": info("Reel poster.jpg", licence="CC0"),
    "File:Wrong.jpg": info("Wrong.jpg"),
}
CATEGORIES: dict[str, list[str]] = {}


class FakeWiki:
    """A stand-in for Wikidata, Commons and the file server; records every
    request."""

    def __init__(self) -> None:
        self.entities = copy.deepcopy(ENTITIES)
        self.search = copy.deepcopy(SEARCH)
        self.files = copy.deepcopy(FILES)
        self.categories = dict(CATEGORIES)
        self.api: list[dict[str, str]] = []
        self.downloads: list[str] = []
        self.reject_thumbs = False

    def __call__(self, url: str, headers: dict[str, str]) -> wc.Response:
        parts = urllib.parse.urlsplit(url)
        q = {k: v[0] for k, v in urllib.parse.parse_qs(parts.query).items()}
        if parts.hostname in ("upload.wikimedia.org", "thumb.wikimedia.org"):
            self.downloads.append(url)
            if "/thumb/" in parts.path:
                if parts.hostname != "thumb.wikimedia.org":
                    return wc.Response(404, {}, b"")
                width = parts.path.rsplit("/", 1)[1].split("px-", 1)[0]
                if self.reject_thumbs or not width.isdigit() \
                        or int(width) not in fcm.STANDARD_WIDTHS:
                    return wc.Response(400, {}, b"Use thumbnail sizes listed on "
                                                b"https://w.wiki/GHai")
            elif parts.hostname != "upload.wikimedia.org":
                return wc.Response(404, {}, b"")
            return wc.Response(200, {}, b"RAW:" + parts.path.encode())
        self.api.append(q)
        action = q.get("action")
        if action == "wbsearchentities":
            hits = self.search.get(q["search"].lower(), [])
            return self.json({"search": [{"id": h} for h in hits]})
        if action == "wbgetentities":
            return self.json({"entities": {i: self.entities[i] for i in q["ids"].split("|")
                                           if i in self.entities}})
        titles = q["titles"].split("|")
        if q.get("prop") == "categories":
            return self.json({"query": {"pages": [
                {"title": t, "categories": [{"title": c} for c in self.categories.get(t, [])]}
                for t in titles]}})
        if "iiurlwidth" in q:
            name = titles[0].split(":", 1)[1].replace(" ", "_")
            return self.json({"query": {"pages": [{"title": titles[0], "imageinfo": [{
                "thumburl": f"https://thumb.wikimedia.org/wikipedia/commons/thumb/a/ab/"
                            f"{name}/{q['iiurlwidth']}px-{name}?utm_source=x"}]}]}})
        pages = []
        for t in titles:
            if t in self.files:
                pages.append({"title": t, "imageinfo": [self.files[t]]})
            else:
                pages.append({"title": t, "missing": True})
        return self.json({"query": {"pages": pages}})

    @staticmethod
    def json(obj: object) -> wc.Response:
        return wc.Response(200, {}, json.dumps(obj).encode())


class Stub:
    """Replaces encode_webp: records the calls, sizes the output by quality."""

    def __init__(self, sizes: dict[int, int] | None = None, dims: tuple[int, int] = (600, 400)
                 ) -> None:
        self.sizes = sizes or {}
        self.dims = dims
        self.calls: list[tuple[int, int]] = []

    def __call__(self, data: bytes, suffix: str, max_side: int, quality: int) -> bytes:
        self.calls.append((max_side, quality))
        return webp(*self.dims, pad=self.sizes.get(quality, 200))


class Case(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.decks = self.root / "decks"
        (self.decks / "creators").mkdir(parents=True)
        (self.decks / "recommendations").mkdir(parents=True)
        (self.decks / "creators" / "zz.yaml").write_text(CREATORS, encoding="utf-8")
        (self.decks / "recommendations" / "zz.yaml").write_text(RECS, encoding="utf-8")
        self.wiki = FakeWiki()
        self.stub = Stub()
        patch = mock.patch.object(fcm, "encode_webp", self.stub)
        patch.start()
        self.addCleanup(patch.stop)

    def client(self) -> wc.Client:
        return wc.Client(self.wiki, cache_dir=self.root / "cache", api_interval=0,
                         download_interval=0, sleep=lambda s: None, max_requests=1000)

    def run_tool(self, **kw: object) -> fcm.Report:
        kw.setdefault("today", TODAY)
        return fcm.run(self.client(), fcm.Options(decks=self.decks, **kw))  # type: ignore[arg-type]

    def creators(self) -> dict[str, dict]:
        data = yaml.safe_load((self.decks / "creators" / "zz.yaml").read_text("utf-8"))
        return {c["id"]: c for c in data["creators"]}

    def recs(self) -> dict[str, dict]:
        data = yaml.safe_load((self.decks / "recommendations" / "zz.yaml").read_text("utf-8"))
        return {c["id"]: c for c in data["recommendations"]}

    def snapshot(self) -> dict[str, str]:
        return {str(p.relative_to(self.decks)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(self.decks.rglob("*")) if p.is_file()}


class LicenceAndAuthor(Case):
    def verdict(self, **kw: object) -> fcm.Verdict:
        return fcm.judge(fcm.Candidate("File:X.jpg", "P18"), info("X.jpg", **kw))  # type: ignore[arg-type]

    def test_allowed_licences_pass_through_the_validators_rule(self) -> None:
        for name, ident in (("CC BY-SA 4.0", "CC-BY-SA-4.0"), ("CC BY-SA 2.0", "CC-BY-SA-2.0"),
                            ("CC BY 3.0", "CC-BY-3.0"), ("CC0", "CC0-1.0"),
                            ("Public domain", "public-domain")):
            v = self.verdict(licence=name)
            self.assertEqual((v.status, v.licence), ("ok", ident), name)

    def test_nc_nd_gfdl_and_fair_use_are_refused(self) -> None:
        for name in ("CC BY-NC 4.0", "CC BY-ND 4.0", "CC BY-NC-SA 3.0", "GFDL",
                     "Fair use", "All rights reserved", ""):
            self.assertEqual(self.verdict(licence=name).status, "licence", name)

    def test_gate_is_the_validators_function(self) -> None:
        with mock.patch.object(vd, "check_licence_and_source") as gate:
            fcm.gate_error("CC-BY-4.0", "https://commons.wikimedia.org/wiki/File:X.jpg")
        gate.assert_called_once()
        self.assertEqual(gate.call_args.args[2:4], ("licence", "CC-BY-4.0"))

    def test_no_author_is_skipped_but_public_domain_is_unknown_author(self) -> None:
        for artist in (None, "", "Unknown author", "Anonymous", "?"):
            self.assertEqual(self.verdict(artist=artist).status, "no-author", artist)
        v = self.verdict(licence="Public domain", artist="Unknown")
        self.assertEqual((v.status, v.author), ("ok", "Unknown author"))

    def test_author_is_plain_text_and_credit_data_are_read(self) -> None:
        v = self.verdict()
        self.assertEqual((v.author, v.licence_url), ("Jo Doe",
                                                     "https://creativecommons.org/licenses/by-sa/4.0"))
        self.assertTrue(v.page.startswith("https://commons.wikimedia.org/wiki/File:"))

    def test_restrictions_and_types_and_big_sources_are_skipped(self) -> None:
        self.assertEqual(self.verdict(restrictions="Personality rights").status, "restricted")
        self.assertEqual(self.verdict(size=20 * 1024 * 1024).status, "over-size")
        bad = info("X.jpg")
        bad["mime"] = "image/svg+xml"
        self.assertEqual(fcm.judge(fcm.Candidate("File:X.jpg", "P18"), bad).status, "bad-type")


class Refusals(Case):
    def test_fair_use_and_other_hosts_are_refused_by_path(self) -> None:
        self.assertIsNone(fcm.file_url_refusal(
            "https://upload.wikimedia.org/wikipedia/commons/a/ab/X.jpg"))
        self.assertIsNone(fcm.file_url_refusal(
            "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/X.jpg/800px-X.jpg"))
        for url in ("https://upload.wikimedia.org/wikipedia/en/a/ab/X.jpg",
                    "https://upload.wikimedia.org/wikipedia/de/a/ab/X.jpg",
                    "https://en.wikipedia.org/wiki/File:X.jpg",
                    "https://example.org/wikipedia/commons/X.jpg",
                    "http://upload.wikimedia.org/wikipedia/commons/a/ab/X.jpg"):
            self.assertIsNotNone(fcm.file_url_refusal(url), url)

    def test_a_fair_use_file_is_skipped_and_never_downloaded(self) -> None:
        report = self.run_tool(langs=["zz"], kinds=("creators",), limit=6)
        fay = [s for s in report.lang("zz").skipped_files if s["id"] == "zz-fay"]
        self.assertEqual(len(fay), 1)
        self.assertIn("/wikipedia/commons/", fay[0]["reason"])
        self.assertFalse([u for u in self.wiki.downloads if "/wikipedia/en/" in u])
        self.assertNotIn("image", self.creators()["zz-fay"])

    def test_no_wikipedia_rest_is_ever_called(self) -> None:
        self.run_tool(langs=["zz"])
        actions = {u["action"] for u in self.wiki.api}
        self.assertLessEqual(actions, {"wbsearchentities", "wbgetentities", "query"})


class Candidates(Case):
    def test_work_order_is_poster_then_p18_then_scan(self) -> None:
        entry = fcm.read_entries(self.decks, "zz", "works")[1]
        got = fcm.candidates(entry, ENTITIES["Q301"])
        self.assertEqual([(c.prop, c.title) for c in got], [
            ("P3383", "File:Reel poster.jpg"), ("P18", "File:Reel still.jpg"),
            ("P996", "File:Reel scan.jpg")])

    def test_creator_takes_p18_only(self) -> None:
        entity = person("Q1", "X", 1, 2, ["A.jpg"])
        entity["claims"]["P3383"] = [claim("Poster.jpg")]
        entry = fcm.read_entries(self.decks, "zz", "creators")[0]
        self.assertEqual([c.prop for c in fcm.candidates(entry, entity)], ["P18"])

    def test_a_deprecated_statement_is_ignored_and_preferred_comes_first(self) -> None:
        entity = person("Q1", "X", 1, 2)
        old, best = claim("Old.jpg"), claim("Best.jpg")
        old["rank"], best["rank"] = "deprecated", "preferred"
        entity["claims"]["P18"] = [old, claim("Normal.jpg"), best]
        entry = fcm.read_entries(self.decks, "zz", "creators")[0]
        self.assertEqual([c.title for c in fcm.candidates(entry, entity)],
                         ["File:Best.jpg", "File:Normal.jpg"])

    def test_first_usable_candidate_wins_the_order(self) -> None:
        self.run_tool(langs=["zz"], kinds=("works",))
        image = self.recs()["zz-rec-lost"]["image"]
        self.assertEqual(image["source_url"],
                         "https://commons.wikimedia.org/wiki/File:Reel_poster.jpg")
        self.assertEqual(image["kind"], "poster")


class Identity(Case):
    def test_a_creator_is_found_by_search_and_the_qid_is_written_back(self) -> None:
        report = self.run_tool(langs=["zz"], kinds=("creators",))
        ada = self.creators()["zz-ada"]
        self.assertEqual(ada["wikidata"], "Q100")
        self.assertEqual(ada["image"]["file"], "decks/creators/images/zz-ada.webp")
        self.assertIn("fetched", report.lang("zz").ids)

    def test_two_fitting_items_are_ambiguous_and_get_no_image(self) -> None:
        report = self.run_tool(langs=["zz"], kinds=("creators",))
        self.assertNotIn("image", self.creators()["zz-eve"])
        review = {r["id"]: r for r in report.lang("zz").review}
        self.assertIn("zz-eve", review)
        self.assertEqual(len(review["zz-eve"]["candidates"]), 2)
        self.assertIn("Q104", review["zz-eve"]["candidates"][0])

    def test_a_name_that_matches_with_the_wrong_dates_is_ambiguous_not_taken(self) -> None:
        report = self.run_tool(langs=["zz"], kinds=("creators",))
        self.assertNotIn("image", self.creators()["zz-hal"])
        self.assertIn("zz-hal", {r["id"] for r in report.lang("zz").review})

    def test_the_wrong_year_work_is_not_taken(self) -> None:
        report = self.run_tool(langs=["zz"], kinds=("works",))
        self.assertNotIn("image", self.recs()["zz-rec-wrong"])
        self.assertIn("zz-rec-wrong", {r["id"] for r in report.lang("zz").review})

    def test_a_work_is_checked_against_type_and_creator(self) -> None:
        song = fcm.read_entries(self.decks, "zz", "works")[0]
        self.assertTrue(fcm.work_fits(song, ENTITIES["Q300"], {"Q100"}))
        self.assertFalse(fcm.work_fits(song, ENTITIES["Q300"], {"Q999"}))   # other creator
        self.assertFalse(fcm.work_fits(song, ENTITIES["Q301"], {"Q100"}))   # film, not book
        film = work("Q9", "The Zed Song", "Q11424", 1850, "Q100")
        self.assertFalse(fcm.work_fits(song, film, {"Q100"}))

    def test_an_item_with_no_creator_does_not_match_a_work_that_has_one(self) -> None:
        song = fcm.read_entries(self.decks, "zz", "works")[0]
        bare = work("Q9", "The Zed Song", "Q571", 1850, "Q100")
        del bare["claims"]["P50"]
        self.assertFalse(fcm.work_fits(song, bare, {"Q100"}))
        song.creators = []                  # the deck names none either: label, year, type
        self.assertTrue(fcm.work_fits(song, bare, set()))

    def test_a_deck_wikidata_that_does_not_fit_is_ambiguous(self) -> None:
        self.wiki.entities["Q160"] = person("Q160", "Fay Zed", 1700, 1760, ["Fay.jpg"])
        report = self.run_tool(langs=["zz"], kinds=("creators",))
        self.assertIn("zz-fay", {r["id"] for r in report.lang("zz").review})

    def test_a_creator_must_be_human(self) -> None:
        ada = fcm.read_entries(self.decks, "zz", "creators")[0]
        thing = person("Q1", "Ada Zed", 1815, 1852)
        thing["claims"]["P31"] = [claim({"id": "Q4167410"})]
        self.assertFalse(fcm.creator_fits(ada, thing))
        self.assertTrue(fcm.creator_fits(ada, ENTITIES["Q100"]))

    def test_circa_widens_the_year_tolerance(self) -> None:
        self.assertTrue(fcm._agree((1800, False), [1801]))
        self.assertFalse(fcm._agree((1800, False), [1802]))
        self.assertTrue(fcm._agree((1800, True), [1805]))
        self.assertIsNone(fcm._agree(None, [1800]))

    def test_no_search_hit_is_missing(self) -> None:
        self.wiki.search.clear()
        report = self.run_tool(langs=["zz"], kinds=("creators",))
        lr = report.lang("zz")
        self.assertEqual((lr.fetched, lr.ambiguous), (0, 0))
        self.assertEqual(lr.missing, lr.asked - 1)      # all but Fay, who has a QID

    def test_the_decks_wikidata_key_is_used_without_a_search(self) -> None:
        self.run_tool(langs=["zz"], kinds=("creators",))
        searched = [q["search"] for q in self.wiki.api if q.get("action") == "wbsearchentities"]
        self.assertNotIn("Fay Zed", searched)


class SkipsAndLiving(Case):
    def test_skip_reasons_are_counted_and_listed(self) -> None:
        report = self.run_tool(langs=["zz"], kinds=("creators",))
        lr = report.lang("zz")
        self.assertEqual(lr.skipped_no_author, 1)       # Bob
        self.assertEqual(lr.skipped_licence, 1)         # Cy (NC)
        self.assertEqual(lr.skipped_other, 1)           # Fay (fair-use path)
        self.assertEqual(lr.missing, 1)                 # Ian: file not on Commons
        self.assertEqual(lr.living, 2)                  # Dee, Gus
        self.assertEqual(lr.ambiguous, 2)               # Eve, Hal
        self.assertIn("zz-bob", lr.ids["skipped-no-author"])
        reasons = {s["id"]: s["reason"] for s in lr.skipped_files}
        self.assertIn("author", reasons["zz-bob"])

    def test_a_living_creator_and_a_recent_death_get_no_portrait(self) -> None:
        self.run_tool(langs=["zz"], kinds=("creators",))
        creators = self.creators()
        self.assertNotIn("image", creators["zz-dee"])      # no date of death
        self.assertNotIn("image", creators["zz-gus"])      # died 2024, today 2025
        self.assertIn("image", creators["zz-ada"])

    def test_include_living_lifts_it(self) -> None:
        self.run_tool(langs=["zz"], kinds=("creators",), include_living=True)
        self.assertIn("image", self.creators()["zz-dee"])
        self.assertIn("image", self.creators()["zz-gus"])

    def test_min_years_dead_is_configurable(self) -> None:
        self.run_tool(langs=["zz"], kinds=("creators",), min_years_dead=1)
        self.assertIn("image", self.creators()["zz-gus"])

    def test_a_disputed_category_goes_to_review(self) -> None:
        self.wiki.categories["File:Ada.jpg"] = ["Category:Alleged portraits of poets"]
        report = self.run_tool(langs=["zz"], kinds=("creators",))
        self.assertNotIn("image", self.creators()["zz-ada"])
        self.assertIn("zz-ada", {r["id"] for r in report.lang("zz").review})


class Resizing(Case):
    def test_the_scale_never_upscales(self) -> None:
        f = fcm.scale_filter(2048)
        self.assertIn("min(2048,iw)", f)
        self.assertIn("min(2048,ih)", f)
        self.assertIn("force_original_aspect_ratio=decrease", f)
        self.assertNotIn("scale=2048:2048", f)
        args = fcm.ffmpeg_args(Path("in.jpg"), Path("out.webp"), 1024, 70)
        self.assertEqual(args[args.index("-vf") + 1], fcm.scale_filter(1024))
        self.assertEqual(args[args.index("-quality") + 1], "70")
        self.assertIn("-map_metadata", args)

    def test_thumbnail_width_is_a_width_for_a_tall_picture(self) -> None:
        self.assertEqual(fcm.thumb_width(3000, 2000, 2048), 2048)      # wide: the width
        self.assertEqual(fcm.thumb_width(3000, 6000, 2048), 1024)      # tall: 2048 high
        self.assertEqual(fcm.thumb_width(500, 300, 2048), 500)         # small: never up
        self.assertEqual(fcm.thumb_width(500, 1000, 1024), 500)

    def test_targets_are_1024_for_portraits_and_2048_for_works(self) -> None:
        self.run_tool(langs=["zz"])
        sides = {c[0] for c in self.stub.calls}
        self.assertEqual(sides, {1024, 2048})
        self.assertEqual(fcm.PORTRAIT_PX, 1024)
        self.assertEqual(fcm.WORK_PX, 2048)

    def test_the_download_is_a_thumbnail_only_when_the_original_is_bigger(self) -> None:
        self.run_tool(langs=["zz"], kinds=("creators",))
        small = [u for u in self.wiki.downloads if u.endswith("/Ada.jpg")]
        self.assertEqual(len(small), 1)                      # 800 x 600: the original
        tall = [u for u in self.wiki.downloads if "Joy_Tall" in u]
        self.assertEqual(len(tall), 1)
        self.assertIn("/thumb/", tall[0])
        self.assertTrue(tall[0].startswith("https://thumb.wikimedia.org/"))
        self.assertIn("/960px-", tall[0])        # 512 needed: the next standard width

    def test_standard_widths_round_up_and_never_pass_the_original(self) -> None:
        self.assertEqual(fcm.standard_width(512, 3000), 960)
        self.assertEqual(fcm.standard_width(1024, 3000), 1280)
        self.assertIsNone(fcm.standard_width(2048, 3000))       # 3840 is above the original
        self.assertEqual(fcm.standard_width(1920, 3000), 1920)
        self.assertIsNone(fcm.standard_width(500, 499))
        self.assertTrue(set(fcm.STANDARD_WIDTHS) >= {960, 1280, 1920})

    def test_a_refused_thumbnail_falls_back_to_a_small_original(self) -> None:
        self.wiki.files["File:Ada.jpg"] = info("Ada.jpg", width=3000, height=2000,
                                               size=100000)
        self.wiki.reject_thumbs = True
        report = self.run_tool(langs=["zz"], kinds=("creators",))
        self.assertIn("image", self.creators()["zz-ada"])
        self.assertTrue(any(u.endswith("/a/ab/Ada.jpg") for u in self.wiki.downloads))
        lr = report.lang("zz")
        self.assertIn("zz-joy", lr.ids.get("skipped-bad-thumb", []))     # 9 MB original
        reason = next(s["reason"] for s in lr.skipped_files if s["id"] == "zz-joy")
        self.assertTrue(reason.startswith("bad-thumb"))
        self.assertNotIn("image", self.creators()["zz-joy"])

    def test_thumb_host_is_allowed_but_fair_use_paths_and_other_hosts_are_not(self) -> None:
        self.assertIsNone(fcm.file_url_refusal(
            "https://thumb.wikimedia.org/wikipedia/commons/thumb/a/ab/X.jpg/960px-X.jpg?utm_a=b"))
        self.assertIsNotNone(fcm.file_url_refusal(
            "https://thumb.wikimedia.org/wikipedia/en/thumb/a/ab/X.jpg/960px-X.jpg"))
        c = self.client()
        self.assertTrue(c.get_bytes("https://thumb.wikimedia.org/wikipedia/commons/thumb/"
                                    "a/ab/X.jpg/960px-X.jpg"))
        with self.assertRaises(wc.WikimediaError):
            c.get_bytes("https://example.org/wikipedia/commons/thumb/a/ab/X.jpg/960px-X.jpg")

    def test_quality_ladder_stops_at_the_first_fit(self) -> None:
        limit = vd.SHARED_IMAGE_MAX_BYTES
        stub = Stub({80: limit + 10, 75: limit + 10, 70: 1000})
        with mock.patch.object(fcm, "encode_webp", stub):
            out, why = fcm.encode_fitting(b"raw", ".jpg", 1024)
        self.assertIsNotNone(out)
        self.assertEqual([q for _, q in stub.calls], [80, 75, 70])

    def test_over_size_after_the_last_rung_is_skipped_and_reported(self) -> None:
        limit = vd.SHARED_IMAGE_MAX_BYTES
        self.stub.sizes = {q: limit + 10 for q in fcm.QUALITY_LADDER}
        report = self.run_tool(langs=["zz"], kinds=("creators",))
        lr = report.lang("zz")
        self.assertEqual((lr.fetched, lr.over_size), (0, 2))   # Ada and Joy
        self.assertEqual([q for _, q in self.stub.calls][:5], list(fcm.QUALITY_LADDER))
        self.assertNotIn("image", self.creators()["zz-ada"])
        self.assertFalse((self.decks / "creators" / "images").exists())

    def test_an_encoded_picture_over_the_side_cap_is_refused(self) -> None:
        stub = Stub(dims=(3000, 100))
        with mock.patch.object(fcm, "encode_webp", stub):
            out, why = fcm.encode_fitting(b"raw", ".jpg", 2048)
        self.assertIsNone(out)
        self.assertIn("3000", why)


class WritingAndIdempotence(Case):
    def test_written_entry_passes_the_validators_image_check(self) -> None:
        self.run_tool(langs=["zz"])
        path = self.decks / "creators" / "zz.yaml"
        for cid, entry in self.creators().items():
            if "image" in entry:
                r = vd.Report(path)
                vd.check_image(r, cid, entry["image"], cid, bool(entry.get("living")), path)
                self.assertEqual(r.errors, [], cid)
        image = self.creators()["zz-ada"]["image"]
        self.assertEqual(image["author"], "Jo Doe")
        self.assertEqual(image["licence"], "CC-BY-SA-4.0")
        self.assertEqual(image["retrieved"], "2025-01-01")
        self.assertNotIn("kind", image)
        self.assertTrue((self.decks / "creators" / "images" / "zz-ada.webp").is_file())
        self.assertTrue((self.decks / "recommendations" / "images"
                         / "zz-rec-lost.webp").is_file())

    def test_the_rest_of_the_file_is_untouched(self) -> None:
        self.run_tool(langs=["zz"])
        text = (self.decks / "creators" / "zz.yaml").read_text("utf-8")
        self.assertIn("# The people of Zedish. A comment the tool must leave alone.", text)
        stripped = yaml.safe_load(text)
        for c in stripped["creators"]:
            c.pop("image", None)
            c.pop("wikidata", None)
        original = yaml.safe_load(CREATORS)
        for c in original["creators"]:
            c.pop("wikidata", None)
        self.assertEqual(stripped, original)

    def test_second_run_is_idempotent_and_asks_for_nothing_new(self) -> None:
        self.run_tool(langs=["zz"])
        before = self.snapshot()
        downloads = len(self.wiki.downloads)
        report = self.run_tool(langs=["zz"])
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(len(self.wiki.downloads), downloads)
        self.assertEqual(report.lang("zz").fetched, 0)
        self.assertEqual(report.lang("zz").already, 4)      # Ada, Joy, the song, the reel

    def test_an_entry_with_a_missing_file_is_flagged_not_redone(self) -> None:
        self.run_tool(langs=["zz"], kinds=("creators",))
        (self.decks / "creators" / "images" / "zz-ada.webp").unlink()
        report = self.run_tool(langs=["zz"], kinds=("creators",))
        self.assertIn("zz-ada", [i for k, ids in report.lang("zz").ids.items()
                                 if k.startswith("invalid") for i in ids])
        self.assertFalse((self.decks / "creators" / "images" / "zz-ada.webp").exists())

    def test_refresh_redoes_one_entry(self) -> None:
        self.run_tool(langs=["zz"], kinds=("creators",))
        report = self.run_tool(langs=["zz"], kinds=("creators",),
                               refresh=frozenset({"zz-ada"}))
        self.assertEqual(report.lang("zz").ids["fetched"], ["zz-ada"])
        self.assertEqual(self.creators()["zz-ada"]["wikidata"], "Q100")

    def test_refresh_never_loses_a_valid_image(self) -> None:
        self.run_tool(langs=["zz"], kinds=("creators",))
        before = self.snapshot()
        with mock.patch.object(vd, "check_image",
                               lambda r, *a, **k: r.error("image", "refused")):
            report = self.run_tool(langs=["zz"], kinds=("creators",),
                                   refresh=frozenset({"zz-ada"}))
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(report.lang("zz").errors, 1)
        self.assertEqual(list((self.decks / "creators" / "images").glob("*.part")), [])

    def test_edit_entry_replaces_an_existing_block(self) -> None:
        image = {"file": "decks/creators/images/zz-ada.webp", "credit": "c", "author": "a",
                 "licence": "CC-BY-4.0", "licence_url": "https://x.org/l",
                 "source_url": "https://commons.wikimedia.org/wiki/File:A.jpg",
                 "retrieved": "2025-01-01"}
        once = fcm.edit_entry(CREATORS, "zz-ada", image, "Q100")
        twice = fcm.edit_entry(once, "zz-ada", {**image, "author": "b"}, "Q100")
        self.assertEqual(twice.count("    image:"), 1)
        self.assertEqual(twice.count("    wikidata:"), 2)         # Fay's and Ada's
        fcm.read_back(CREATORS, twice, "creators", "zz-ada", {**image, "author": "b"}, "Q100")

    def test_read_back_catches_a_wrong_or_wider_edit(self) -> None:
        image = {"file": "decks/creators/images/zz-ada.webp", "credit": "c", "author": "a",
                 "licence": "CC-BY-4.0", "licence_url": "https://x.org/l",
                 "source_url": "https://commons.wikimedia.org/wiki/File:A.jpg",
                 "retrieved": "2025-01-01"}
        after = fcm.edit_entry(CREATORS, "zz-ada", image, None)
        with self.assertRaises(iw.ImportError_):
            fcm.read_back(CREATORS, after, "creators", "zz-ada", {**image, "author": "z"}, None)
        with self.assertRaises(iw.ImportError_):
            fcm.read_back(CREATORS, after.replace('"A poet."', '"A pet."'), "creators",
                          "zz-ada", image, None)
        with self.assertRaises(iw.ImportError_):
            fcm.edit_entry(CREATORS, "zz-nobody", image, None)

    def test_a_failed_validator_check_leaves_no_file_and_no_edit(self) -> None:
        before = self.snapshot()
        with mock.patch.object(vd, "check_image",
                               lambda r, *a, **k: r.error("image", "refused")):
            report = self.run_tool(langs=["zz"], kinds=("creators",))
        self.assertEqual(self.snapshot(), before)
        self.assertGreater(report.lang("zz").errors, 0)


class ReadOnlyModes(Case):
    def test_survey_writes_nothing_and_downloads_no_image(self) -> None:
        before = self.snapshot()
        report = self.run_tool(langs=["zz"], survey=True)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.wiki.downloads, [])
        self.assertEqual(self.stub.calls, [])
        lr = report.lang("zz")
        self.assertEqual(report.mode, "survey")
        self.assertEqual(lr.available, 4)       # Ada, Joy, the song, the reel
        self.assertGreater(lr.estimated_bytes, 0)
        self.assertEqual(lr.by_kind["creators"]["available"], 2)
        self.assertIn("CC-BY-SA-4.0", lr.licences)

    def test_dry_run_downloads_and_encodes_but_writes_nothing(self) -> None:
        before = self.snapshot()
        report = self.run_tool(langs=["zz"], dry_run=True)
        self.assertEqual(self.snapshot(), before)
        self.assertTrue(self.wiki.downloads)
        self.assertTrue(self.stub.calls)
        self.assertEqual(report.lang("zz").fetched, 4)
        self.assertGreater(report.lang("zz").bytes, 0)

    def test_facts_prints_wikidata_next_to_the_deck_and_writes_nothing(self) -> None:
        before = self.snapshot()
        self.wiki.entities["Q100"]["claims"]["P19"] = [claim({"id": "Q900"})]
        self.wiki.entities["Q900"] = {"id": "Q900", "labels": {"en": {"value": "Zedtown"}}}
        report = self.run_tool(langs=["zz"], facts=True)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual((self.wiki.downloads, self.stub.calls), ([], []))
        line = next(f for f in report.lang("zz").facts if f.startswith("zz-ada"))
        self.assertIn("born deck 1815 / Wikidata 1815", line)
        self.assertIn("Zedtown", line)
        self.assertEqual(report.mode, "facts")

    def test_limit_and_kind_and_lang_select_entries(self) -> None:
        report = self.run_tool(langs=["zz"], kinds=("works",), limit=1)
        self.assertEqual(report.lang("zz").asked, 1)
        self.assertNotIn("image", self.creators()["zz-ada"])


class ReportAndExit(Case):
    def test_report_shapes(self) -> None:
        report = self.run_tool(langs=["zz"])
        data = report.to_json()
        self.assertEqual(set(data), {"mode", "stopped", "error", "requests", "total",
                                     "existing_bytes", "ceiling_bytes",
                                     "ceiling_share_percent", "languages"})
        lang = data["languages"][0]
        for key in ("lang", "entries", "fetched", "missing", "skipped_no_author",
                    "skipped_licence", "over_size", "ambiguous", "living", "bytes",
                    "licences", "ids", "skipped_files", "ambiguous_review", "by_kind"):
            self.assertIn(key, lang)
        self.assertEqual(data["total"]["fetched"], 4)
        self.assertEqual(data["ceiling_bytes"], vd.IMAGE_TOTAL_MAX_BYTES)
        self.assertGreater(data["total"]["bytes"], 0)
        text = report.to_markdown()
        self.assertIn("# Culture media fetch report (write)", text)
        self.assertIn("| zz |", text)
        self.assertIn("Ambiguous, for a human to settle", text)
        self.assertIn("MB ceiling", text)
        json.dumps(data)

    def run_main(self, wiki: object, *argv: str) -> tuple[int, str]:
        client = wc.Client(wiki, cache_dir=self.root / "c2", api_interval=0,  # type: ignore[arg-type]
                           download_interval=0, sleep=lambda s: None, max_tries=1)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = fcm.main(["--decks", str(self.decks), "--lang", "zz", *argv], client)
        return code, out.getvalue()

    def test_exit_3_at_the_rate_limit_and_the_report_is_written(self) -> None:
        report = self.root / "r.md"
        code, out = self.run_main(lambda url, h: wc.Response(429, {"retry-after": "9999"}, b""),
                                  "--report", str(report), "--json", str(self.root / "r.json"))
        self.assertEqual(code, 3)
        self.assertIn("Stopped early", report.read_text("utf-8"))
        self.assertTrue(json.loads((self.root / "r.json").read_text("utf-8"))["stopped"])

    def test_exit_4_for_another_wikimedia_error(self) -> None:
        report = self.root / "r.md"
        code, _ = self.run_main(lambda url, h: wc.Response(400, {}, b""), "--report", str(report))
        self.assertEqual(code, 4)
        self.assertIn("**Error:**", report.read_text("utf-8"))

    def test_a_fatal_error_mid_run_still_writes_the_report(self) -> None:
        report = self.root / "r.md"
        with mock.patch.object(fcm, "_write", side_effect=iw.ImportError_("boom")):
            code, _ = self.run_main(self.wiki, "--report", str(report))
        self.assertEqual(code, 1)
        self.assertIn("boom", report.read_text("utf-8"))

    def test_exit_0_and_exit_2(self) -> None:
        code, _ = self.run_main(self.wiki, "--survey")
        self.assertEqual(code, 0)
        self.assertEqual(self.run_main(self.wiki, "--survey", "--dry-run")[0], 2)
        self.assertEqual(self.run_main(self.wiki, "--work-px", "4096")[0], 2)

    def test_exit_1_for_an_unknown_language(self) -> None:
        client = wc.Client(self.wiki, cache_dir=self.root / "c3", api_interval=0,
                           sleep=lambda s: None)
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(fcm.main(["--decks", str(self.decks), "--lang", "qq"], client), 1)


def have_libwebp() -> bool:
    if not shutil.which("ffmpeg"):
        return False
    done = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], capture_output=True,
                          text=True)
    return "libwebp" in done.stdout


@unittest.skipUnless(have_libwebp(), "needs ffmpeg with libwebp")
class RealFfmpeg(unittest.TestCase):
    def png(self, size: str) -> bytes:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "t.png"
            subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "lavfi",
                            "-i", f"testsrc=size={size}", "-frames:v", "1", str(out)],
                           check=True)
            return out.read_bytes()

    def test_resizes_down_and_never_up(self) -> None:
        big = fcm.encode_webp(self.png("300x100"), ".png", 100, 80)
        w, h = vd.image_size(big)
        self.assertEqual(w, 100)
        self.assertIn(h, (33, 34))
        small = fcm.encode_webp(self.png("50x20"), ".png", 2048, 80)
        self.assertEqual(vd.image_size(small), (50, 20))          # never upscaled
        tall = fcm.encode_webp(self.png("100x300"), ".png", 150, 80)
        w, h = vd.image_size(tall)
        self.assertEqual(h, 150)
        self.assertIn(w, (50, 51))


if __name__ == "__main__":
    unittest.main()
