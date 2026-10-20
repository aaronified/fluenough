"""Tests for transcribe.py: readings in ISO 15919 letters as said, and IPA
(ADR-0025)."""

import unittest

from transcribe import spanish_ipa, transcribe


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
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()

    def test_the_bengali_inherent_vowel_and_a_hint_that_does_not_fit(self) -> None:
        cases = (
            self._bengali_inherent_vowel,
            self._a_hint_that_does_not_fit_says_so,
        )
        for i, case in enumerate(cases):
            with self.subTest(case.__name__.lstrip("_")):
                if i:
                    self.setUp()
                case()


if __name__ == "__main__":
    unittest.main()
