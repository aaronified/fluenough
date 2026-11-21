#!/usr/bin/env python3
"""Images of the culture decks (ADR-0060, wiki/Plan-Culture-Media.md, package
1): the caps per kind of image, the one licence rule shared with audio, a
work's `image` on a recommendation, `wikidata` and `image.kind`, orphans, the
budget lint and `--image-report`, and the index's `shared_media` for work
images.

The fixtures are tiny WebP and PNG headers built by hand (`webp`, `png`), so
nothing needs ffmpeg or the network. Stdlib `unittest` plus PyYAML.
"""

from __future__ import annotations

import contextlib
import io
import os
import struct
import sys
import unittest
import zlib
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks  # noqa: E402
from kinds_testlib import KindsCase, RECS, CREATORS  # noqa: E402
from test_validate_b1 import CORE, B1Case, card  # noqa: E402
from test_validate_creators import png  # noqa: E402

BOOK = "zz-rec-cartas-de-prueba"
FILM = "zz-rec-una-pelicula"
BOOK_FILE = f"decks/recommendations/images/{BOOK}.webp"
COMMONS = "https://commons.wikimedia.org/wiki/File:Cartas_de_prueba_1895.webp"
WORK_IMAGE = {
    "file": BOOK_FILE,
    "credit": "Title page of the 1895 edition",
    "author": "Imprenta Nacional",
    "licence": "public-domain",
    "source_url": COMMONS,
    "retrieved": "2026-11-12",
    "kind": "title-page",
}
BY_SA = dict(WORK_IMAGE, licence="CC-BY-SA-3.0", author="A. Photographer",
             licence_url="https://creativecommons.org/licenses/by-sa/3.0/")


def webp(width: int, height: int, size: int = 0) -> bytes:
    """A WebP (VP8X) header of the given dimensions, padded with zeros to at
    least [size] bytes: what the validator reads, no pixels."""
    body = (b"VP8X" + struct.pack("<I", 10) + b"\x00\x00\x00\x00"
            + (width - 1).to_bytes(3, "little") + (height - 1).to_bytes(3, "little"))
    data = b"RIFF" + struct.pack("<I", 4 + len(body)) + b"WEBP" + body
    return data + bytes(max(0, size - len(data)))


def rec(data: dict, rid: str = BOOK) -> dict:
    return next(r for r in data["recommendations"] if r["id"] == rid)


class WorkImages(KindsCase):

    def image(self, data: bytes, rid: str = BOOK, ext: str = "webp") -> Path:
        path = self.root / "recommendations" / "images" / f"{rid}.{ext}"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def give(self, rid: str = BOOK, **change: object) -> None:
        """The recommendation names its image, WORK_IMAGE with [change]."""
        image = {**WORK_IMAGE, **change}
        self.edit(RECS, lambda d: rec(d, rid).__setitem__("image", image))

    def problems(self) -> str:
        return "\n".join(self.errors(RECS))

    def test_a_work_with_a_small_webp_image_is_valid(self) -> None:
        self.image(webp(1400, 2048, 200 * 1024))
        self.give()
        self.assertEqual(self.errors(RECS), [])
        self.assertValid()

    def test_a_work_without_an_image_is_still_valid(self) -> None:
        self.assertNotIn("image", rec(self.data(RECS)))
        self.assertEqual(self.errors(RECS), [])

    def test_the_licence_url_is_needed_unless_public_domain(self) -> None:
        self.image(webp(100, 100))
        self.give(**BY_SA)
        self.assertEqual(self.errors(RECS), [])
        self.edit(RECS, lambda d: rec(d)["image"].pop("licence_url"))
        self.assertIn("licence_url is required", self.problems())

    def test_a_credit_needs_every_key(self) -> None:
        self.image(webp(100, 100))
        for key in ("file", "credit", "author", "licence", "source_url", "retrieved"):
            with self.subTest(key):
                self.give()
                self.edit(RECS, lambda d, key=key: rec(d)["image"].pop(key))
                self.assertIn(f"{key} is required", self.problems())

    def test_the_file_is_named_for_its_recommendation_in_its_folder(self) -> None:
        self.image(webp(100, 100))
        self.give(file=f"decks/recommendations/images/{FILM}.webp")
        self.assertIn("file is named for its recommendation", self.problems())
        self.give(file=f"decks/creators/images/{BOOK}.webp")
        self.assertIn("file must be decks/recommendations/images/", self.problems())

    def test_the_file_must_exist(self) -> None:
        self.give()
        self.assertIn(f"{BOOK_FILE} does not exist", self.problems())

    def test_a_png_or_jpg_is_still_accepted(self) -> None:
        # `.webp` is what the fetch tool writes; the creators' older rule keeps
        # `.jpg` and `.png` valid.
        self.image(png(8, 8), ext="png")
        self.give(file=f"decks/recommendations/images/{BOOK}.png")
        self.assertEqual(self.errors(RECS), [])

    def test_a_file_that_is_not_an_image_is_refused(self) -> None:
        self.image(b"not a webp")
        self.give()
        self.assertIn("is not a readable webp image", self.problems())

    # Caps

    def test_a_work_image_may_be_2048_pixels_on_a_side(self) -> None:
        for width, height in ((2048, 1448), (1448, 2048), (2048, 2048)):
            with self.subTest((width, height)):
                self.image(webp(width, height))
                self.give()
                self.assertEqual(self.errors(RECS), [])

    def test_a_work_image_over_2048_pixels_is_refused(self) -> None:
        for width, height in ((2049, 100), (100, 2049), (4000, 3000)):
            with self.subTest((width, height)):
                self.image(webp(width, height))
                self.give()
                self.assertIn(f"{width} x {height} px; at most 2048 on a side",
                              self.problems())

    def test_a_work_image_may_be_500_kb_and_no_more(self) -> None:
        self.image(webp(100, 100, 500 * 1024))
        self.give()
        self.assertEqual(self.errors(RECS), [])
        self.image(webp(100, 100, 500 * 1024 + 1))
        self.assertIn("at most 500", self.problems())

    def test_the_caps_are_the_plans(self) -> None:
        self.assertEqual(validate_decks.SHARED_IMAGE_MAX_SIDE, 2048)
        self.assertEqual(validate_decks.SHARED_IMAGE_MAX_BYTES, 500 * 1024)
        self.assertEqual(validate_decks.CARD_IMAGE_MAX_SIDE, 1024)
        self.assertEqual(validate_decks.CARD_IMAGE_MAX_BYTES, 300 * 1024)

    # The licence and the credit

    def test_the_licence_rule_is_the_one_audio_has(self) -> None:
        self.image(webp(100, 100))
        for licence in ("CC0-1.0", "public-domain", "CC-BY-2.0", "CC-BY-3.0",
                        "CC-BY-4.0", "CC-BY-SA-2.0", "CC-BY-SA-4.0", "CC-BY-SA-3.0-DE"):
            with self.subTest(licence):
                self.give(licence=licence, licence_url="https://creativecommons.org/x")
                self.assertEqual(self.errors(RECS), [])

    def test_nc_nd_gfdl_and_fair_use_are_refused(self) -> None:
        self.image(webp(100, 100))
        for licence in ("CC-BY-NC-4.0", "CC-BY-ND-4.0", "CC-BY-NC-SA-3.0", "GFDL-1.3",
                        "fair-use", "all-rights-reserved", "CC-BY-SA-1.0"):
            with self.subTest(licence):
                self.give(licence=licence, licence_url="https://example.org/x")
                self.assertIn("cannot ship in a CC BY-SA 4.0 deck", self.problems())
        self.give(licence="CC-BY-NC-4.0", licence_url="https://example.org/x")
        self.assertIn("NonCommercial (NC) and NoDerivatives (ND) licences are never "
                      "allowed", self.problems())

    def test_the_source_is_a_link_not_prose_and_never_generated(self) -> None:
        self.image(webp(100, 100))
        for source in ("Wikimedia Commons",
                       "Generated by tools/signwriting_image.py (drawn)"):
            with self.subTest(source):
                self.give(source_url=source, licence="CC0-1.0",
                          licence_url="https://creativecommons.org/publicdomain/zero/1.0/")
                self.assertIn("source_url must be the link of the image's page",
                              self.problems())

    def test_a_works_source_is_a_commons_page(self) -> None:
        self.image(webp(100, 100))
        self.give(source_url="https://en.wikipedia.org/wiki/File:Poster.jpg")
        self.assertIn("source_url must be the file's page on commons.wikimedia.org",
                      self.problems())
        self.give(source_url="https://commons.wikimedia.org/wiki/File:Poster.jpg")
        self.assertEqual(self.errors(RECS), [])

    def test_the_links_are_https(self) -> None:
        self.image(webp(100, 100))
        self.give(source_url="http://commons.wikimedia.org/wiki/File:X.jpg")
        self.assertIn("source_url must be an https link", self.problems())

    def test_an_author_is_plain_text_of_at_most_300_characters(self) -> None:
        self.image(webp(100, 100))
        self.give(author="<a href='x'>Someone</a>")
        self.assertIn("author is plain text, with no markup", self.problems())
        self.give(author="x" * 301)
        self.assertIn("author is 301 characters; at most 300", self.problems())
        self.give(author="x" * 300)
        self.assertEqual(self.errors(RECS), [])

    def test_an_unknown_author_only_with_public_domain(self) -> None:
        self.image(webp(100, 100))
        self.give(author="Unknown author")
        self.assertEqual(self.errors(RECS), [])
        self.give(**{**BY_SA, "author": "Unknown author"})
        self.assertIn("only for a public-domain image", self.problems())

    def test_a_date_that_is_not_a_date_is_refused(self) -> None:
        self.image(webp(100, 100))
        self.give(retrieved="last week")
        self.assertNotEqual(self.errors(RECS), [])

    def test_unknown_image_keys_are_refused(self) -> None:
        self.image(webp(100, 100))
        self.give(colour="red")
        self.assertIn("unknown field 'colour'", self.problems())

    # image.kind and wikidata

    def test_the_kinds_of_picture(self) -> None:
        self.image(webp(100, 100))
        for kind in validate_decks.IMAGE_KINDS:
            with self.subTest(kind):
                self.give(kind=kind)
                self.assertEqual(self.errors(RECS), [])
        self.give(kind="logo")
        self.assertIn("kind must be one of portrait, photograph, painting, statue, "
                      "depiction, title-page, poster", self.problems())

    def test_the_kind_is_optional(self) -> None:
        self.image(webp(100, 100))
        self.edit(RECS, lambda d: rec(d).__setitem__(
            "image", {k: v for k, v in WORK_IMAGE.items() if k != "kind"}))
        self.assertEqual(self.errors(RECS), [])

    def test_a_wikidata_item_on_a_work_and_a_creator(self) -> None:
        self.edit(RECS, lambda d: rec(d).__setitem__("wikidata", "Q42"))
        self.assertEqual(self.errors(RECS), [])
        self.edit(CREATORS, lambda d: d["creators"][0].__setitem__("wikidata", "Q7241"))
        self.assertEqual(self.errors(CREATORS), [])

    def test_a_wikidata_item_is_q_and_digits(self) -> None:
        for bad in ("42", "q42", "Q", "Q0", "Q01", "Q42x", 42, None):
            with self.subTest(bad):
                self.edit(RECS, lambda d, bad=bad: rec(d).__setitem__("wikidata", bad))
                self.assertIn("wikidata must be a Wikidata item such as 'Q123'",
                              self.problems())
                self.edit(CREATORS, lambda d, bad=bad:
                          d["creators"][0].__setitem__("wikidata", bad))
                self.assertIn("wikidata must be a Wikidata item such as 'Q123'",
                              "\n".join(self.errors(CREATORS)))

    # Orphans

    def test_a_work_image_no_recommendation_cites_is_an_error(self) -> None:
        self.image(webp(100, 100), rid="zz-rec-sobra")
        self.assertIn("decks/recommendations/images/zz-rec-sobra.webp is cited by no "
                      "recommendation", self.problems())
        self.assertRejected("zz-rec-sobra.webp is cited by no recommendation")

    def test_a_cited_work_image_is_no_orphan(self) -> None:
        self.image(webp(100, 100))
        self.give()
        self.assertNotIn("cited by no", self.problems())

    def test_a_creator_image_no_creator_cites_is_still_an_error(self) -> None:
        (self.root / "creators" / "images" / "zz-sobra.webp").write_bytes(webp(8, 8))
        self.assertIn("zz-sobra.webp is cited by no creator",
                      "\n".join(self.errors(CREATORS)))


class Budget(KindsCase):
    """The ceiling on the shared culture images (ADR-0060): 100 MB in all, 75
    MB a warning, 10 MB for a language, 8 MB a warning. The ceilings are
    patched small so the fixtures stay tiny."""

    def setUp(self) -> None:
        super().setUp()
        self.give(BOOK, webp(100, 100, 1000))
        self.give(FILM, webp(100, 100, 3000))
        # The creator image of the fixture is a few hundred bytes of PNG.
        self.creator_bytes = (self.root / "creators" / "images"
                              / "zz-ejemplo-autora.png").stat().st_size

    def give(self, rid: str, data: bytes) -> None:
        path = self.root / "recommendations" / "images" / f"{rid}.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        image = dict(WORK_IMAGE, file=f"decks/recommendations/images/{rid}.webp")
        self.edit(RECS, lambda d: rec(d, rid).__setitem__("image", image))

    def limits(self, **values: int):
        patches = [mock.patch.object(validate_decks, name, value)
                   for name, value in values.items()]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)

    def total(self) -> int:
        return 1000 + 3000 + self.creator_bytes

    def test_under_every_limit_is_silent(self) -> None:
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertNotIn("culture images", out)

    def test_over_the_total_ceiling_fails(self) -> None:
        self.limits(IMAGE_TOTAL_MAX_BYTES=self.total() - 1)
        self.assertRejected(f"the shared culture images together are {self.total()} bytes")

    def test_exactly_the_total_ceiling_passes(self) -> None:
        self.limits(IMAGE_TOTAL_MAX_BYTES=self.total())
        self.assertValid()

    def test_over_the_total_warning_level_warns_and_passes(self) -> None:
        self.limits(IMAGE_TOTAL_WARN_BYTES=self.total() - 1)
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertIn("warning: the shared culture images together are", out)

    def test_over_a_languages_ceiling_fails(self) -> None:
        self.limits(IMAGE_LANG_MAX_BYTES=self.total() - 1)
        self.assertRejected(f"the shared culture images of zz are {self.total()} bytes")

    def test_over_a_languages_warning_level_warns_and_passes(self) -> None:
        self.limits(IMAGE_LANG_WARN_BYTES=self.total() - 1)
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertIn("warning: the shared culture images of zz are", out)

    def test_the_plans_numbers(self) -> None:
        mib = 1024 * 1024
        self.assertEqual(validate_decks.IMAGE_TOTAL_MAX_BYTES, 100 * mib)
        self.assertEqual(validate_decks.IMAGE_TOTAL_WARN_BYTES, 75 * mib)
        self.assertEqual(validate_decks.IMAGE_LANG_MAX_BYTES, 10 * mib)
        self.assertEqual(validate_decks.IMAGE_LANG_WARN_BYTES, 8 * mib)

    def test_a_file_is_counted_once_across_reports(self) -> None:
        reports = [validate_decks.validate(self.p(RECS)),
                   validate_decks.validate(self.p(RECS))]
        self.assertEqual(validate_decks.image_totals(reports),
                         {"zz": {"recommendations": 4000}})

    def test_the_languages_are_counted_apart(self) -> None:
        rep = validate_decks.Report(Path("decks/recommendations/te.yaml"))
        rep.shared_image_bytes = {"decks/creators/images/te-a.webp": 5,
                                  "decks/recommendations/images/te-rec-b.webp": 7,
                                  "decks/creators/images/es-a.webp": 11}
        self.assertEqual(validate_decks.image_totals([rep]),
                         {"te": {"creators": 5, "recommendations": 7},
                          "es": {"creators": 11}})

    def test_the_image_report_prints_bytes_per_language_and_never_fails(self) -> None:
        self.limits(IMAGE_LANG_WARN_BYTES=1)
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = validate_decks.main(["validate_decks.py", "--image-report",
                                        str(self.root)])
        text = out.getvalue()
        self.assertEqual(code, 0, text)
        self.assertIn("Image report (shared culture images, bytes):", text)
        self.assertIn(f"  zz: 3 files, {self.total()} bytes (creators "
                      f"{self.creator_bytes}, works 4000;", text)
        self.assertIn(f"  all: 3 files, {self.total()} bytes of", text)

    def test_without_the_flag_there_is_no_report(self) -> None:
        self.assertNotIn("Image report", self.run_main()[1])


class CardImages(B1Case):
    """A card's own image downloads with the course, so it stays at 1024 px
    and 300 KB; the credit follows the one licence rule."""

    CID = "zz-9001"
    PATH = f"decks/zz/images/{CID}.webp"
    CREDIT = {"source": "https://commons.wikimedia.org/wiki/File:House.jpg",
              "license": "CC-BY-SA-4.0", "credit": "A. Photographer"}

    def put_image(self, data: bytes) -> None:
        path = self.dir / "images" / f"{self.CID}.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def give(self, **credit: object) -> None:
        self.edit(CORE, lambda d: card(d, self.CID).update(
            image=self.PATH, image_credit={**self.CREDIT, **credit}))

    def image_errors(self) -> list[str]:
        return [e for e in self.errors(CORE) if "image" in e]

    def test_a_small_image_is_valid(self) -> None:
        self.put_image(webp(256, 195, 12_000))
        self.give()
        self.assertEqual(self.image_errors(), [])

    def test_1024_pixels_and_300_kb_pass_and_a_step_over_fails(self) -> None:
        self.give()
        self.put_image(webp(1024, 768, 300 * 1024))
        self.assertEqual(self.image_errors(), [])
        self.put_image(webp(1025, 768))
        self.assertTrue(any("1025 x 768 px; at most 1024 px on a side for a card's own "
                            "image" in e for e in self.image_errors()))
        self.put_image(webp(256, 256, 300 * 1024 + 1))
        self.assertTrue(any("at most 300 KB for a card's own image" in e
                            for e in self.image_errors()))

    def test_a_card_image_is_not_given_the_shared_cap(self) -> None:
        # 2048 px is for the shared images only.
        self.give()
        self.put_image(webp(2048, 1448))
        self.assertTrue(any("at most 1024 px" in e for e in self.image_errors()))

    def test_one_rule_for_audio_and_images(self) -> None:
        self.put_image(webp(64, 64))
        for licence in ("CC-BY-NC-4.0", "GFDL-1.2", "fair-use", "all-rights-reserved"):
            with self.subTest(licence):
                self.give(license=licence)
                self.assertTrue(any("image_credit.license" in e
                                    and "cannot ship in a CC BY-SA 4.0 deck" in e
                                    for e in self.image_errors()))
        for licence in ("CC0-1.0", "public-domain", "CC-BY-2.0", "CC-BY-SA-3.0-DE"):
            with self.subTest(licence):
                self.give(license=licence)
                self.assertEqual(self.image_errors(), [])

    def test_the_source_is_a_link_for_an_image_too(self) -> None:
        self.put_image(webp(64, 64))
        self.give(source="Wikimedia Commons")
        self.assertTrue(any("image_credit.source must be the link of the image's page" in e
                            for e in self.image_errors()))

    def test_a_generated_image_may_say_so_with_cc0(self) -> None:
        # The SignWriting pictures are drawn by tools/signwriting_image.py.
        self.put_image(webp(256, 256))
        self.give(source="Generated by tools/signwriting_image.py (FSW M507x507S1f720487x492)",
                  license="CC0-1.0", credit="Drawn from the sign's FSW text")
        self.assertEqual(self.image_errors(), [])
        self.give(source="Generated by tools/signwriting_image.py (FSW)",
                  license="CC-BY-SA-4.0")
        self.assertTrue(any("image_credit.source must be the link" in e
                            for e in self.image_errors()))

    def test_the_real_ipa_credits_pass(self) -> None:
        # Copied from decks/ipa/ipa-terms.yaml on decks-live: the three
        # card images that exist today.
        self.put_image(webp(256, 195, 12_074))
        for source, credit in (
                ("https://commons.wikimedia.org/wiki/File:Phoneme-allophone-"
                 "determination-chart.svg", "AnonMoos, released into the public domain"),
                ("https://commons.wikimedia.org/wiki/File:Illu01_head_neck.jpg",
                 "Arcadian (uploader), from an illustration of the U.S. National Cancer "
                 "Institute, SEER Training Modules; a work of the U.S. federal government"),
                ("https://commons.wikimedia.org/wiki/File:Illu_mouth.jpg",
                 "U.S. National Cancer Institute, SEER Training Modules; a work of the "
                 "U.S. federal government")):
            with self.subTest(source):
                self.give(source=source, license="public-domain", credit=credit)
                self.assertEqual(self.image_errors(), [])


class WorkImagesInTheIndex(unittest.TestCase):
    """The index lists a work image under `shared_media`, apart from the
    language's size, with the `min_app` of the release that shows it; a
    creator image stays as it was."""

    def test_the_folders_and_the_gate(self) -> None:
        import deck_index
        self.assertEqual(deck_index.SHARED_MEDIA, "decks/creators/images")
        self.assertEqual(deck_index.SHARED_MEDIA_WORKS, "decks/recommendations/images")
        self.assertRegex(deck_index.MIN_APP_WORK_IMAGES, r"^\d+\.\d+\.\d+$")

    def test_creator_and_work_images_are_listed(self) -> None:
        import hashlib
        import tempfile
        import deck_index
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            (root / "decks" / "creators" / "images").mkdir(parents=True)
            (root / "decks" / "recommendations" / "images").mkdir(parents=True)
            creator = webp(10, 10, 300)
            work = webp(20, 20, 400)
            (root / "decks" / "creators" / "images" / "zz-a.webp").write_bytes(creator)
            (root / "decks" / "recommendations" / "images"
             / "zz-rec-b.webp").write_bytes(work)
            (root / "decks" / "recommendations" / "images" / "notes.txt").write_text("x")
            with mock.patch.object(deck_index, "ROOT", root):
                entries = deck_index._shared_media()
        self.assertEqual(entries, [
            {"path": "decks/creators/images/zz-a.webp", "size": 300,
             "sha256": hashlib.sha256(creator).hexdigest(), "kind": "image",
             "language": "zz"},
            {"path": "decks/recommendations/images/zz-rec-b.webp", "size": 400,
             "sha256": hashlib.sha256(work).hexdigest(), "kind": "image",
             "language": "zz", "min_app": deck_index.MIN_APP_WORK_IMAGES}])


if __name__ == "__main__":
    unittest.main()
