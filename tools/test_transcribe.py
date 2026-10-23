"""Tests for transcribe.py: readings in ISO 15919 letters as said, and IPA
(ADR-0025)."""

import unittest

from transcribe import CannotRead, spanish_ipa, transcribe


class ReadingTest(unittest.TestCase):
    def check(self, lang, word, hint, reading, ipa):
        t = transcribe(word, lang, hint)
        self.assertTrue(t.fitted, f"{word} did not fit {hint}")
        self.assertEqual(t.reading, reading)
        self.assertEqual(t.ipa, ipa)

    def _length_is_marked(self):
        # The owner's example: పాలు, milk, and పలు, many, read alike before.
        self.check("te", "పాలు", "palu", "pālu", "paːlu")
        self.check("te", "పలు", "palu", "palu", "palu")

    def _retroflex_is_marked(self):
        self.check("te", "పాట", "pata", "pāṭa", "paːʈa")
        self.check("te", "పాత", "pata", "pāta", "paːt̪a")


    def _bengali_inherent_vowel(self):
        self.check("bn", "কথা", "kotha", "kôthā", "kɔt̪ʰa")
        self.check("bn", "ঘর", "ghor", "ghôr", "ɡʱɔr")
        self.check("bn", "আসি", "ashi", "āśi", "aʃi")


    def _a_hint_that_does_not_fit_says_so(self):
        t = transcribe("पाट", "hi", "xyz")
        self.assertFalse(t.fitted)

    def test_length_and_retroflex_are_marked(self) -> None:
        cases = (
            self._length_is_marked,
            self._retroflex_is_marked,
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

    def test_the_bengali_inherent_vowel_and_a_hint_that_does_not_fit(self) -> None:
        cases = (
            self._bengali_inherent_vowel,
            self._a_hint_that_does_not_fit_says_so,
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


class NewLanguagesTest(unittest.TestCase):
    """Japanese, Korean, Mandarin and Toki Pona (#612), read the way the
    decks write them."""

    def test_kana_are_read_in_hepburn_with_long_vowels_doubled(self) -> None:
        for kana, reading, ipa in (
            ("わたし", "watashi", "wataɕi"),
            ("おはよう", "ohayou", "ohajoː"),
            ("おおきい", "ookii", "oːkiː"),
            ("コーヒー", "koohii", "koːçiː"),
            ("がっこう", "gakkou", "ɡakkoː"),
            ("きょう", "kyou", "kjoː"),
            ("ほんや", "hon'ya", "hoɴja"),
            ("ファイル", "fairu", "ɸaiɾɯ"),
        ):
            with self.subTest(kana):
                t = transcribe(kana, "ja")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))

    def test_han_cannot_be_read_from_their_shape(self) -> None:
        with self.assertRaises(CannotRead):
            transcribe("日本語", "ja")

    def test_hangul_sound_changes_between_syllables(self) -> None:
        for hangul, reading in (
            ("선생님", "seonsaengnim"),
            ("한국어", "hangugeo"),       # liaison
            ("학문", "hangmun"),          # nasalisation
            ("신라", "silla"),
            ("종로", "jongno"),
            ("좋다", "jota"),             # ㅎ aspirates
            ("좋아요", "joayo"),          # ㅎ is silent
            ("괜찮아요", "gwaenchanayo"),
            ("읽어요", "ilgeoyo"),
            ("감사합니다", "gamsahamnida"),
            ("안녕하세요 커피", "annyeonghaseyo keopi"),
        ):
            with self.subTest(hangul):
                self.assertEqual(transcribe(hangul, "ko").reading, reading)

    def test_mandarin_is_the_hint_and_nothing_without_one(self) -> None:
        self.assertEqual(
            transcribe("你好", "zh", "nǐ hǎo").reading, "nǐ hǎo")
        with self.assertRaises(CannotRead):
            transcribe("你好", "zh")

    def test_toki_pona_stress_is_on_the_first_syllable(self) -> None:
        self.assertEqual(transcribe("jan suli li toki.", "tok").ipa,
                         "jan ˈsuli li ˈtoki")


if __name__ == "__main__":
    unittest.main()
