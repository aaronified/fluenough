"""Tests for tools/offensive_alikes.py (#629): the close pairs a reviewer
sees, the notes that explain them, and the validator's warning for one left
unexplained."""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import offensive_alikes  # noqa: E402
import validate_decks  # noqa: E402

DECK = """\
schema: 1
id: te-en-words
name: "Words"
language: {{ code: te, iso639_3: tel, name: Telugu, script: telugu }}
native: {{ code: en, iso639_3: eng, name: English }}
license: CC0-1.0
{tags}
cards:
{cards}
"""


def card(cid: str, target: str, reading: str, ipa: str, extra: str = "") -> str:
    return (f'  - {{ id: {cid}, target: "{target}", native: "w", '
            f'reading: "{reading}", ipa: "{ipa}"{extra} }}')


# The offensive word వెధవ (vedhava), and a word one segment from it, a word
# a mark from it, and one far from it.
RUDE = card("te-9951", "వెధవ", "vedhava", "ʋed̪ʱaʋa")
NEAR_SOUND = card("te-9901", "విధవ", "vidhava", "ʋid̪ʱaʋa")
FAR = card("te-9902", "అమ్మ", "amma", "amma")


class Alikes(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        (self.tmp / "te").mkdir()

    def write(self, name: str, cards: list[str], tags: str = "") -> Path:
        path = self.tmp / "te" / f"{name}.yaml"
        path.write_text(DECK.format(tags=tags, cards="\n".join(cards)),
                        encoding="utf-8")
        return path

    def words(self, *paths: Path) -> list[offensive_alikes.Word]:
        return offensive_alikes.load_words(list(paths))

    def test_a_word_one_segment_from_an_offensive_word_sounds_like_it(self) -> None:
        rude = self.write("rude", [RUDE], 'tags: ["offensive"]')
        plain = self.write("plain", [NEAR_SOUND, FAR])
        found = offensive_alikes.find_alikes(self.words(rude, plain))
        sound = [a for a in found if a.kind == "sound"]
        self.assertEqual([(a.word.id, a.rude.id, a.distance) for a in sound],
                         [("te-9901", "te-9951", 1)])

    def test_a_word_far_from_every_offensive_word_is_not_listed(self) -> None:
        rude = self.write("rude", [RUDE], 'tags: ["offensive"]')
        plain = self.write("plain", [FAR])
        self.assertEqual(offensive_alikes.find_alikes(self.words(rude, plain)), [])

    def test_a_length_mark_makes_a_look_alike_in_the_reading(self) -> None:
        # No IPA on either: only the writing is compared. vedhava and
        # vedhāva differ by the length mark alone.
        rude = self.write("rude", [card("te-9951", "వెధవ", "vedhava", "")],
                          'tags: ["offensive"]')
        plain = self.write("plain", [card("te-9903", "వెధావ", "vedhāva", "")])
        found = offensive_alikes.find_alikes(self.words(rude, plain))
        self.assertEqual([(a.kind, a.word.id, a.distance) for a in found],
                         [("look", "te-9903", 1)])

    def test_the_script_is_compared_too(self) -> None:
        rude = self.write("rude", [card("te-9951", "వెధవ", "", "")],
                          'tags: ["offensive"]')
        plain = self.write("plain", [card("te-9904", "వెధవా", "", "")])
        found = offensive_alikes.find_alikes(self.words(rude, plain))
        self.assertEqual([(a.kind, a.basis) for a in found], [("look", "script")])

    def test_a_short_word_is_left_out(self) -> None:
        rude = self.write("rude", [card("te-9951", "కక", "ka", "ka")],
                          'tags: ["offensive"]')
        plain = self.write("plain", [card("te-9905", "కగ", "ga", "ga")])
        self.assertEqual(offensive_alikes.find_alikes(self.words(rude, plain)), [])

    def test_offensive_words_are_not_paired_with_each_other(self) -> None:
        both = self.write("rude", [RUDE, NEAR_SOUND], 'tags: ["offensive"]')
        self.assertEqual(offensive_alikes.find_alikes(self.words(both)), [])

    def test_a_card_registered_offensive_in_an_ordinary_deck_counts(self) -> None:
        deck = self.write("mixed", [
            card("te-9951", "వెధవ", "vedhava", "ʋed̪ʱaʋa", ', register: "offensive"'),
            NEAR_SOUND,
        ])
        found = offensive_alikes.find_alikes(self.words(deck))
        self.assertEqual([a.word.id for a in found if a.kind == "sound"],
                         ["te-9901"])

    def test_another_language_is_not_compared(self) -> None:
        rude = self.write("rude", [RUDE], 'tags: ["offensive"]')
        other = self.tmp / "kn"
        other.mkdir()
        path = other / "kn-en-words.yaml"
        path.write_text(
            DECK.format(tags="", cards=NEAR_SOUND).replace("code: te", "code: kn"),
            encoding="utf-8")
        self.assertEqual(offensive_alikes.find_alikes(self.words(rude, path)), [])

    def test_a_pair_note_explains_a_sound_alike_and_a_lookalike_note_a_look_alike(
            self) -> None:
        rude = self.write("rude", [RUDE], 'tags: ["offensive"]')
        pair = self.write("pair", [card(
            "te-9901", "విధవ", "vidhava", "ʋid̪ʱaʋa",
            ', notes: [{ kind: "pair", ref: "te-9951", text: "Keep the e." }]')])
        found = offensive_alikes.find_alikes(self.words(rude, pair))
        sound = [a for a in found if a.kind == "sound"]
        look = [a for a in found if a.kind == "look"]
        self.assertTrue(sound and all(a.explained for a in sound))
        # The pair note says nothing of the writing.
        self.assertTrue(look and not any(a.explained for a in look))

        both = self.write("both", [card(
            "te-9901", "విధవ", "vidhava", "ʋid̪ʱaʋa",
            ', notes: [{ kind: "pair", ref: "te-9951", text: "a" }, '
            '{ kind: "lookalike", ref: "te-9951", text: "b" }]')])
        found = offensive_alikes.find_alikes(self.words(rude, both))
        self.assertTrue(found and all(a.explained for a in found))

    def test_a_note_on_the_offensive_word_explains_it_too(self) -> None:
        rude = self.write("rude", [card(
            "te-9951", "వెధవ", "vedhava", "ʋed̪ʱaʋa",
            ', notes: [{ kind: "pair", ref: "te-9901", text: "a" }]')],
            'tags: ["offensive"]')
        plain = self.write("plain", [NEAR_SOUND])
        found = offensive_alikes.find_alikes(self.words(rude, plain))
        self.assertTrue([a for a in found if a.kind == "sound" and a.explained])

    def test_the_command_lists_the_pairs_and_the_unexplained_flag_filters(self) -> None:
        self.write("rude", [RUDE], 'tags: ["offensive"]')
        self.write("plain", [NEAR_SOUND])
        import contextlib
        import io
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = offensive_alikes.main([str(self.tmp), "--language", "te"])
        self.assertEqual(code, 0)
        self.assertIn("sounds like", out.getvalue())
        self.assertIn("UNEXPLAINED", out.getvalue())
        self.assertIn("te-9901", out.getvalue())


class ValidatorWarning(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        (self.tmp / "te").mkdir()

    def reports(self, plain: list[str]) -> list[validate_decks.Report]:
        paths = []
        for name, cards, tags in (("rude", [RUDE], 'tags: ["offensive"]'),
                                  ("plain", plain, "")):
            path = self.tmp / "te" / f"{name}.yaml"
            path.write_text(DECK.format(tags=tags, cards="\n".join(cards)),
                            encoding="utf-8")
            paths.append(path)
        return [validate_decks.Report(path=p) for p in paths]

    def test_a_close_pair_left_unexplained_is_a_warning_not_an_error(self) -> None:
        reports = self.reports([NEAR_SOUND])
        validate_decks.warn_alikes_across(reports)
        warned = [w for r in reports for w in r.warnings]
        self.assertTrue(any("sounds like the offensive word te-9951" in w
                            for w in warned), warned)
        self.assertTrue(all(not r.errors for r in reports))

    def test_the_warning_is_on_the_word_and_not_the_offensive_word(self) -> None:
        reports = self.reports([NEAR_SOUND])
        validate_decks.warn_alikes_across(reports)
        self.assertEqual(reports[0].warnings, [])
        self.assertTrue(reports[1].warnings[0].startswith("card te-9901"))

    def test_a_pair_note_silences_the_sound_warning(self) -> None:
        explained = card(
            "te-9901", "విధవ", "vidhava", "ʋid̪ʱaʋa",
            ', notes: [{ kind: "pair", ref: "te-9951", text: "Keep the e." }, '
            '{ kind: "lookalike", ref: "te-9951", text: "One mark differs." }]')
        reports = self.reports([explained])
        validate_decks.warn_alikes_across(reports)
        self.assertEqual([w for r in reports for w in r.warnings], [])

    def test_a_language_with_no_offensive_word_has_no_warning(self) -> None:
        path = self.tmp / "te" / "plain.yaml"
        path.write_text(DECK.format(tags="", cards="\n".join([NEAR_SOUND, FAR])),
                        encoding="utf-8")
        report = validate_decks.Report(path=path)
        validate_decks.warn_alikes_across([report])
        self.assertEqual(report.warnings, [])


class RatedTag(unittest.TestCase):
    def check(self, tags: str) -> list[str]:
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, True)
        path = tmp / "te-en-probe.yaml"
        path.write_text(DECK.format(tags=tags, cards=FAR), encoding="utf-8")
        return validate_decks.validate(path).errors

    def test_only_a_deck_of_offensive_words_is_rated(self) -> None:
        self.assertTrue(any('"rated"' in e for e in self.check('tags: ["rated"]')))

    def test_a_rated_deck_of_offensive_words_is_valid(self) -> None:
        errors = self.check('tags: ["offensive", "rated"]')
        self.assertFalse([e for e in errors if "rated" in e], errors)

    def test_an_unrated_deck_of_offensive_words_is_valid(self) -> None:
        errors = self.check('tags: ["offensive"]')
        self.assertFalse([e for e in errors if "rated" in e], errors)


if __name__ == "__main__":
    unittest.main()
