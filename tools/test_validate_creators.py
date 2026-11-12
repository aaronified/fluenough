#!/usr/bin/env python3
"""The creators file, decks/creators/<code>.yaml (wiki/Plan-Deck-Kinds-And-
Topics.md, D5 and D5b): dates, eras, names, images with their credit and
licence, legacy with its sources, and a card's creator against the file."""

from __future__ import annotations

import struct
import unittest
import zlib

from kinds_testlib import KindsCase, CREATORS

AUTORA = "zz-ejemplo-autora"
IMAGES = "creators/images/"


def creator(data: dict, cid: str = AUTORA) -> dict:
    return next(c for c in data["creators"] if c["id"] == cid)


def png(width: int, height: int) -> bytes:
    """A valid PNG of a plain colour, as big as asked."""
    raw = b"".join(b"\x00" + bytes([10, 20, 30]) * width for _ in range(height))

    def chunk(kind: bytes, body: bytes) -> bytes:
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


class Creators(KindsCase):
    def check(self, change, needle: str) -> None:
        self.edit(CREATORS, change)
        self.assertIn(needle, "\n".join(self.errors(CREATORS)))

    def test_the_fixture_file_is_valid(self) -> None:
        self.assertEqual(self.errors(CREATORS), [])
        self.assertValid()

    def test_the_file_is_named_for_its_language(self) -> None:
        self.check(lambda d: d.__setitem__("id", "creators-xx"), "must be creators-zz")

    def test_unknown_keys_are_refused(self) -> None:
        self.check(lambda d: creator(d).__setitem__("nickname", "x"),
                   "unknown field 'nickname'")

    def test_an_id_is_the_languages(self) -> None:
        self.check(lambda d: creator(d).__setitem__("id", "xx-person"), "id must be zz-")

    def test_an_id_is_listed_once(self) -> None:
        self.check(lambda d: d["creators"].append(dict(creator(d))), "is listed twice")

    def test_a_name_has_an_english_entry(self) -> None:
        self.check(lambda d: creator(d)["name"].pop("en"), "has an en entry")

    def test_a_name_in_another_script_needs_its_reading(self) -> None:
        self.check(lambda d: creator(d)["name"].__setitem__("zz", {"text": "అప్పారావు"}),
                   "is in a script other than Latin and needs its reading")

    def test_a_name_with_its_reading_passes(self) -> None:
        self.edit(CREATORS, lambda d: creator(d)["name"].__setitem__(
            "zz", {"text": "అప్పారావు", "reading": "appārāvu"}))
        self.assertEqual(self.errors(CREATORS), [])

    # Dates

    def test_born_is_a_year(self) -> None:
        self.check(lambda d: creator(d).__setitem__("born", "long ago"),
                   "born must be a year")

    def test_a_circa_year_is_allowed(self) -> None:
        def change(d: dict) -> None:
            creator(d)["born"] = {"year": 1850, "circa": True}
        self.edit(CREATORS, change)
        self.assertEqual(self.errors(CREATORS), [])

    def test_born_is_before_died(self) -> None:
        self.check(lambda d: creator(d).__setitem__("died", 1850), "is not before died")

    def test_a_lifespan_is_at_most_120(self) -> None:
        self.check(lambda d: creator(d).__setitem__("died", 1975), "lived 125 years")

    def test_died_is_not_in_the_future(self) -> None:
        self.check(lambda d: creator(d).__setitem__("died", 2030), "died 2030 is in the future")

    def test_a_creator_has_died_or_is_living(self) -> None:
        self.check(lambda d: creator(d).pop("died"), "has no died: add died, or living: true")

    def test_a_living_creator_is_living_true(self) -> None:
        def change(d: dict) -> None:
            c = creator(d, "zz-ejemplo-poeta")
            c.pop("died")
            c["living"] = True
        self.edit(CREATORS, change)
        self.assertEqual(self.errors(CREATORS), [])

    def test_a_creator_is_not_living_and_dead(self) -> None:
        self.check(lambda d: creator(d).__setitem__("living", True),
                   "is living: true and has died")

    # Eras

    def test_an_era_is_one_of_the_files(self) -> None:
        self.check(lambda d: creator(d).__setitem__("era", "antigua"), "is not one of the file's eras")

    def test_an_era_runs_from_before_to(self) -> None:
        def change(d: dict) -> None:
            d["eras"].append({"id": "rara", "name": {"en": "Odd"}, "from": 1900, "to": 1800})
        self.check(change, "from 1900 is not before to 1800")

    def test_a_creator_is_active_within_fifty_years_of_the_era(self) -> None:
        def change(d: dict) -> None:
            d["eras"].append({"id": "antigua", "name": {"en": "Ancient"}, "from": 1000, "to": 1500})
            creator(d)["era"] = "antigua"
        self.check(change, "but era 'antigua' runs 1000 to 1500")

    def test_an_era_still_running_has_no_end(self) -> None:
        self.assertEqual(self.data(CREATORS)["eras"][0]["to"], None)
        self.assertEqual(self.errors(CREATORS), [])

    # Images

    def test_an_image_needs_its_credit_and_licence(self) -> None:
        for key in ("file", "credit", "author", "licence", "licence_url", "source_url",
                    "retrieved"):
            with self.subTest(key=key):
                self.check(lambda d, key=key: creator(d)["image"].pop(key),
                           f"{key} is required")
                self.restore(CREATORS)

    def test_a_public_domain_image_needs_no_licence_url_but_a_source(self) -> None:
        def change(d: dict) -> None:
            img = creator(d)["image"]
            img["licence"] = "public-domain"
            img.pop("licence_url")
        self.edit(CREATORS, change)
        self.assertEqual(self.errors(CREATORS), [])

    def test_a_licence_is_on_the_allow_list(self) -> None:
        self.check(lambda d: creator(d)["image"].__setitem__("licence", "CC-BY-NC-4.0"),
                   "licence must be one of public-domain, CC0-1.0, CC-BY-4.0, CC-BY-SA-4.0")

    def test_fair_use_is_no_licence(self) -> None:
        self.check(lambda d: creator(d)["image"].__setitem__("licence", "fair-use"),
                   "no fair use")

    def test_a_living_creators_image_is_never_public_domain(self) -> None:
        def change(d: dict) -> None:
            c = creator(d)
            c.pop("died")
            c["living"] = True
            c["born"] = 1990
            c["era"] = "moderna"
            c["image"]["licence"] = "public-domain"
            c["image"].pop("licence_url")
        self.check(change, "a living creator's image is never public-domain by age")

    def test_the_image_file_exists(self) -> None:
        (self.root / "creators" / "images" / "zz-ejemplo-autora.png").unlink()
        self.assertIn("does not exist", "\n".join(self.errors(CREATORS)))

    def test_the_image_is_named_for_its_creator(self) -> None:
        self.check(lambda d: creator(d)["image"].__setitem__(
            "file", "decks/creators/images/zz-otro.png"),
            "file is named for its creator")

    def test_the_image_is_a_jpg_png_or_webp_under_creators_images(self) -> None:
        self.check(lambda d: creator(d)["image"].__setitem__("file", "elsewhere/x.gif"),
                   "file must be decks/creators/images/")

    def test_an_image_is_at_most_300_kb(self) -> None:
        # 1024 x 1024 random-looking rows do not compress below 300 KB.
        import os
        raw = b"".join(b"\x00" + os.urandom(3 * 400) for _ in range(400))

        def chunk(kind: bytes, body: bytes) -> bytes:
            return (struct.pack(">I", len(body)) + kind + body
                    + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))
        big = (b"\x89PNG\r\n\x1a\n"
               + chunk(b"IHDR", struct.pack(">IIBBBBB", 400, 400, 8, 2, 0, 0, 0))
               + chunk(b"IDAT", zlib.compress(raw, 0)) + chunk(b"IEND", b""))
        self.assertGreater(len(big), 300 * 1024)
        (self.root / "creators" / "images" / "zz-ejemplo-autora.png").write_bytes(big)
        self.assertIn("at most 300", "\n".join(self.errors(CREATORS)))

    def test_an_image_is_at_most_1024_pixels_on_a_side(self) -> None:
        (self.root / "creators" / "images" / "zz-ejemplo-autora.png").write_bytes(png(1100, 4))
        self.assertIn("1100 x 4 px; at most 1024 on a side", "\n".join(self.errors(CREATORS)))

    def test_an_image_is_a_real_image(self) -> None:
        (self.root / "creators" / "images" / "zz-ejemplo-autora.png").write_bytes(b"not a png")
        self.assertIn("is not a readable png image", "\n".join(self.errors(CREATORS)))

    def test_an_image_no_creator_cites_is_an_error(self) -> None:
        (self.root / "creators" / "images" / "zz-sobra.png").write_bytes(png(8, 8))
        self.assertIn("zz-sobra.png is cited by no creator", "\n".join(self.errors(CREATORS)))

    def test_a_creator_without_an_image_is_a_placeholder(self) -> None:
        self.assertNotIn("image", creator(self.data(CREATORS), "zz-ejemplo-poeta"))
        self.assertEqual(self.errors(CREATORS), [])

    # Legacy

    def test_a_legacy_summary_needs_items(self) -> None:
        self.check(lambda d: creator(d)["legacy"].pop("items"),
                   "items is required: one to six concrete, checkable examples")

    def test_a_legacy_has_at_most_six_items(self) -> None:
        def change(d: dict) -> None:
            legacy = creator(d)["legacy"]
            legacy["items"] = [dict(legacy["items"][0]) for _ in range(7)]
        self.check(change, "items is required")

    def test_a_legacy_item_needs_a_source(self) -> None:
        self.check(lambda d: creator(d)["legacy"]["items"][0].pop("source"),
                   "source must be a mapping with an https url or a work")

    def test_a_legacy_source_is_https_and_dated(self) -> None:
        self.check(lambda d: creator(d)["legacy"]["items"][0]["source"].update(
            {"url": "http://example.org/x"}), "source.url must be an https link")
        self.restore(CREATORS)
        self.check(lambda d: creator(d)["legacy"]["items"][0]["source"].pop("accessed"),
                   "source needs accessed")

    def test_a_legacy_item_has_a_known_kind(self) -> None:
        self.check(lambda d: creator(d)["legacy"]["items"][0].__setitem__("kind", "rumour"),
                   "kind must be one of curriculum, festival")

    def test_a_legacy_text_is_at_most_60_words(self) -> None:
        self.check(lambda d: creator(d)["legacy"].__setitem__(
            "text", {"en": " ".join(["word"] * 61)}), "en text is 61 words; at most 60")

    def test_a_legacy_year_is_not_in_the_future(self) -> None:
        self.check(lambda d: creator(d)["legacy"]["items"][0].__setitem__("year", 2040),
                   "year must be a year, no later than this one")

    # Related, bio, checked_by

    def test_a_related_creator_is_in_the_file(self) -> None:
        self.check(lambda d: creator(d)["related"][0].__setitem__("creator", "zz-nadie"),
                   "which is not in the file")

    def test_a_relation_is_one_of_four(self) -> None:
        self.check(lambda d: creator(d)["related"][0].__setitem__("relation", "rival"),
                   "relation must be one of adaptation, influence, response, echo")

    def test_a_bio_is_needed(self) -> None:
        self.check(lambda d: creator(d).pop("bio"), "text must map language codes to text")

    def test_checked_by_is_a_list_of_rater_codes(self) -> None:
        self.check(lambda d: creator(d).__setitem__("checked_by", ["nope"]),
                   "checked_by must be a non-empty list of rater codes")

    # Across files

    def test_a_related_card_must_exist(self) -> None:
        def change(d: dict) -> None:
            creator(d)["related"].append({"card": "zz-9999", "relation": "echo"})
        self.edit(CREATORS, change)
        self.assertRejected("card zz-9999 is not a card of zz")

    def test_a_region_must_be_on_the_path(self) -> None:
        def path(d: dict) -> None:
            d["regions"] = [{"id": "norte", "name": {"en": "North"}}]
        self.edit("zz/zz-path.yaml", path)
        self.edit(CREATORS, lambda d: creator(d).__setitem__("region", "sur"))
        self.assertRejected("region 'sur' is not a region of zz's path")

    def test_a_creator_no_card_cites_is_only_a_warning(self) -> None:
        def change(d: dict) -> None:
            d["creators"].append({"id": "zz-sin-obra", "name": {"en": {"text": "Sin Obra"}},
                                  "born": 1800, "died": 1860, "bio": {"en": "Made up."}})
        self.edit(CREATORS, change)
        code, text = self.run_main()
        self.assertEqual(code, 0, text)
        self.assertIn("no card cites this creator yet", text)


if __name__ == "__main__":
    unittest.main()
