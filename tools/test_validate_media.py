#!/usr/bin/env python3
"""A card's own recording (#518), shipped with the deck: `audio` naming
`decks/<lang>/audio/<card id>.opus`, the file there, and its credit,
`audio_credit: { source, license, credit }`.

Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
PyYAML, like the validator itself.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_validate_b1 import CAT, CORE, EXTRA, B1Case, card, single  # noqa: E402

HOUSE = "zz-9001"
CREDIT = {"source": "https://commons.wikimedia.org/wiki/File:Te-ఇల్లు.ogg",
          "license": "CC-BY-SA-4.0", "credit": "A. Speaker"}


class Case(B1Case):

    def core(self, cid: str, **fields: object) -> None:
        self.edit(CORE, lambda d: card(d, cid).update(fields))

    def file(self, rel: str) -> None:
        path = self.dir / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"OggS")


class Audio(Case):

    def test_a_recording_with_its_credit(self) -> None:
        self.file(f"audio/{HOUSE}.opus")
        self.core(HOUSE, audio=f"decks/zz/audio/{HOUSE}.opus", audio_credit=CREDIT)
        self.assertNoError(CORE)
        self.assertNotIn(f"error: decks/zz/audio/{HOUSE}.opus: no card names it as its "
                         f"audio; remove it, or name it on the card {HOUSE}",
                         self.run_main())

    def test_in_a_single_file_deck(self) -> None:
        self.file("audio/zz-9501.opus")
        self.put(EXTRA, single(cards=[dict(CAT, audio="decks/zz/audio/zz-9501.opus",
                                           audio_credit=CREDIT)]))
        self.assertNoError(EXTRA)

    def test_named_by_its_card(self) -> None:
        self.file("audio/zz-9002.opus")
        self.core(HOUSE, audio="decks/zz/audio/zz-9002.opus", audio_credit=CREDIT)
        self.assertError(CORE, f"card {HOUSE}", f"audio must be decks/zz/audio/{HOUSE}"
                         f".opus: the file is named by its card, got "
                         f"'decks/zz/audio/zz-9002.opus'")

    def test_the_file_is_there(self) -> None:
        self.core(HOUSE, audio=f"decks/zz/audio/{HOUSE}.opus", audio_credit=CREDIT)
        self.assertError(CORE, f"card {HOUSE}", f"audio decks/zz/audio/{HOUSE}.opus has "
                                                f"no file")

    def test_the_credit_is_required(self) -> None:
        self.file(f"audio/{HOUSE}.opus")
        self.core(HOUSE, audio=f"decks/zz/audio/{HOUSE}.opus")
        self.assertError(CORE, f"card {HOUSE}", "audio_credit is required with audio: "
                                                "the file's { source, license, credit }")

    def test_the_credit_shape(self) -> None:
        self.file(f"audio/{HOUSE}.opus")
        self.core(HOUSE, audio=f"decks/zz/audio/{HOUSE}.opus",
                  audio_credit={"source": "x", "license": "GFDL", "by": "y"})
        errors = self.errors(CORE)
        w = f"card {HOUSE}"
        for msg in ("audio_credit: unknown field 'by'",
                    "audio_credit.credit is required and must be a non-empty string",
                    "audio_credit.license 'GFDL' cannot ship in a CC BY-SA 4.0 deck: "
                    "CC0-1.0, public-domain, or CC-BY or CC-BY-SA 2.0 to 4.0, such as "
                    "CC-BY-SA-4.0"):
            self.assertIn(f"{w}: {msg}", errors)

    def test_licences_that_ship(self) -> None:
        self.file(f"audio/{HOUSE}.opus")
        for licence in ("CC0-1.0", "public-domain", "CC-BY-2.5", "CC-BY-SA-3.0-DE",
                        "CC-BY-SA-4.0"):
            with self.subTest(licence=licence):
                self.core(HOUSE, audio=f"decks/zz/audio/{HOUSE}.opus",
                          audio_credit=dict(CREDIT, license=licence))
                self.assertNoError(CORE)
        for licence in ("CC-BY-NC-4.0", "CC-BY-SA-1.0", "GFDL-1.2"):
            with self.subTest(licence=licence):
                self.core(HOUSE, audio=f"decks/zz/audio/{HOUSE}.opus",
                          audio_credit=dict(CREDIT, license=licence))
                self.assertEqual([e for e in self.errors(CORE) if "cannot ship" in e],
                                 [f"card {HOUSE}: audio_credit.license {licence!r} cannot "
                                  f"ship in a CC BY-SA 4.0 deck: CC0-1.0, public-domain, "
                                  f"or CC-BY or CC-BY-SA 2.0 to 4.0, such as CC-BY-SA-4.0"])

    def test_a_credit_only_with_a_shipped_file(self) -> None:
        self.core(HOUSE, audio="https://example.org/house.ogg", audio_credit=CREDIT)
        self.assertError(CORE, f"card {HOUSE}", "audio_credit is only for a file shipped "
                         "with the deck, audio: decks/zz/audio/<card id>.opus")
        self.core(HOUSE, audio="https://example.org/house.ogg")
        self.edit(CORE, lambda d: card(d, HOUSE).pop("audio_credit"))
        self.assertNoError(CORE)

    def test_not_in_a_layer(self) -> None:
        self.edit("en/zz-en-home.yaml",
                  lambda d: d["cards"][HOUSE].update(audio_credit=CREDIT))
        self.assertTrue(any("audio_credit" in e for e in self.errors("en/zz-en-home.yaml")))

    def test_a_file_no_card_names(self) -> None:
        self.file("audio/zz-9002.opus")
        self.file("audio/notes.txt")
        lines = self.run_main()
        self.assertIn("error: decks/zz/audio/zz-9002.opus: no card names it as its audio; "
                      "remove it, or name it on the card zz-9002", lines)
        self.assertIn("error: decks/zz/audio/notes.txt: a card's audio file ends in .opus",
                      lines)


IMAGE_CREDIT = {"source": "https://openmoji.org/library/emoji-1F3E0/",
                "license": "CC-BY-SA-4.0", "credit": "OpenMoji"}


class Image(Case):
    """A card's own image (#523): `image` naming
    `decks/<lang>/images/<card id>.webp`, the file there, and its
    `image_credit`."""

    def test_an_image_with_its_credit(self) -> None:
        self.file(f"images/{HOUSE}.webp")
        self.core(HOUSE, image=f"decks/zz/images/{HOUSE}.webp", image_credit=IMAGE_CREDIT)
        self.assertNoError(CORE)
        self.assertFalse(any("images/" in line for line in self.run_main()
                             if line.startswith("error")))

    def test_in_a_single_file_deck(self) -> None:
        self.file("images/zz-9501.webp")
        self.put(EXTRA, single(cards=[dict(CAT, image="decks/zz/images/zz-9501.webp",
                                           image_credit=IMAGE_CREDIT)]))
        self.assertNoError(EXTRA)

    def test_only_a_file_shipped_with_the_deck(self) -> None:
        self.core(HOUSE, image="https://example.org/house.jpg", image_credit=IMAGE_CREDIT)
        self.assertError(CORE, f"card {HOUSE}", "image must be decks/zz/images/<card id>"
                         ".webp, got 'https://example.org/house.jpg'")

    def test_named_by_its_card_and_there(self) -> None:
        self.core(HOUSE, image="decks/zz/images/zz-9002.webp", image_credit=IMAGE_CREDIT)
        self.assertError(CORE, f"card {HOUSE}", f"image must be decks/zz/images/{HOUSE}"
                         f".webp: the file is named by its card, got "
                         f"'decks/zz/images/zz-9002.webp'")
        self.core(HOUSE, image=f"decks/zz/images/{HOUSE}.webp")
        self.assertError(CORE, f"card {HOUSE}", f"image decks/zz/images/{HOUSE}.webp has "
                                                f"no file")

    def test_the_credit_is_required_and_ships(self) -> None:
        self.file(f"images/{HOUSE}.webp")
        self.core(HOUSE, image=f"decks/zz/images/{HOUSE}.webp")
        self.assertError(CORE, f"card {HOUSE}", "image_credit is required with image: "
                                                "the file's { source, license, credit }")
        self.core(HOUSE, image_credit=dict(IMAGE_CREDIT, license="GFDL"))
        self.assertError(CORE, f"card {HOUSE}", "image_credit.license 'GFDL' cannot ship "
                         "in a CC BY-SA 4.0 deck: CC0-1.0, public-domain, or CC-BY or "
                         "CC-BY-SA 2.0 to 4.0, such as CC-BY-SA-4.0")

    def test_not_in_a_layer_nor_on_a_ref(self) -> None:
        self.edit("en/zz-en-home.yaml",
                  lambda d: d["cards"][HOUSE].update(image="decks/zz/images/x.webp"))
        self.assertTrue(any("image" in e for e in self.errors("en/zz-en-home.yaml")))

    def test_a_file_no_card_names(self) -> None:
        self.file("images/zz-9002.webp")
        self.file("images/zz-9001.png")
        lines = self.run_main()
        self.assertIn("error: decks/zz/images/zz-9002.webp: no card names it as its image; "
                      "remove it, or name it on the card zz-9002", lines)
        self.assertIn("error: decks/zz/images/zz-9001.png: a card's image file ends in "
                      ".webp", lines)


if __name__ == "__main__":
    unittest.main()
