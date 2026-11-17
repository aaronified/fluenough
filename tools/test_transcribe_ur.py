"""Tests for transcribe.py's Urdu (Perso-Arabic script) engine."""

import unittest

import transcribe as tr
from transcribe import reading_to_ipa, transcribe, urdu_lexicon


def read(text, hint=None, lang="ur"):
    return transcribe(text, lang, hint)


class UrduTest(unittest.TestCase):
    """The engine's rules, with the hand-written word list only: the bulk
    lexicon (test_build_urdu_lexicon.py) would answer where these rules are
    what is tested."""

    def setUp(self) -> None:
        self._files, self._lex = tr.UR_LEXICON_FILES, tr._UR_LEXICON
        tr.UR_LEXICON_FILES = ("urdu_words.tsv",)
        tr._UR_LEXICON = None

    def tearDown(self) -> None:
        tr.UR_LEXICON_FILES, tr._UR_LEXICON = self._files, self._lex

    def test_the_couplet_with_the_ezafe(self) -> None:
        t = read("نقش فریادی ہے کس کی شوخیِ تحریر کا")
        self.assertEqual(
            t.reading, "naqś fariyādī hai kis kī śōkhī-e tahrīr kā")
        self.assertEqual(
            t.ipa, "nəqʃ fərɪjaːd̪iː ɦɛː kɪs kiː ʃoːkʰiːɪ t̪əɦriːr kaː")
        self.assertEqual(t.notes, [])

    def test_hi_reads_perso_arabic_but_still_devanagari(self) -> None:
        self.assertEqual(read("کتنا", "kitna", "hi").reading, "kitnā")
        self.assertEqual(read("کتنا", "kitna", "hi").ipa, "kɪt̪naː")
        self.assertEqual(transcribe("कितना", "hi", "kitna").reading, "kitnā")

    def test_devanagari_with_arabic_punctuation_stays_on_the_hi_path(
            self) -> None:
        self.assertTrue(transcribe("कितना ۱", "hi", "kitna").reading
                        .startswith("kitnā "))
        self.assertTrue(transcribe("कितना،", "hi", "kitna").reading
                        .startswith("kitnā"))
        self.assertTrue(transcribe("नमस्ते؟", "hi", "namaste").reading
                        .startswith("namastē"))

    def test_a_urdu_line_with_its_punctuation(self) -> None:
        self.assertEqual(read("دل، جان؟ ہے۔").reading, "dil, jān? hai.")

    def test_marks_written_are_read_as_written(self) -> None:
        t = read("نَقْش")
        self.assertEqual((t.reading, t.ipa), ("naqś", "nəqʃ"))
        t = read("مُحَبَّت")
        self.assertEqual(t.reading, "muhabbat")
        self.assertEqual(t.notes, [])

    def test_a_single_letter_with_a_mark_is_a_vowel_not_an_ezafe(self) -> None:
        self.assertEqual(read("بِ").reading, "bi")
        self.assertEqual(read("ا").reading, "ā")

    def test_unwritten_short_vowels_are_question_marks(self) -> None:
        t = read("کتاب")
        self.assertEqual(t.reading, "k?tāb")
        self.assertIn("?", t.ipa)
        self.assertTrue(any("unvowelled" in n for n in t.notes))
        t = read("لڑکا")
        self.assertEqual(t.reading, "l?ṛ?kā")

    def test_a_lexicon_word_supplies_its_vowels(self) -> None:
        self.assertIn("نقش", urdu_lexicon())
        t = read("نقش")
        self.assertEqual(t.reading, "naqś")
        self.assertNotIn("?", t.reading)
        self.assertEqual(t.notes, [])

    def test_a_hint_supplies_the_vowels_and_is_checked(self) -> None:
        t = read("لڑکا", "laṛkā")
        self.assertTrue(t.fitted)
        self.assertEqual((t.reading, t.ipa), ("laṛkā", "ləɽkaː"))
        t = read("کتاب", "किताब")
        self.assertEqual(t.reading, "kitāb")
        t = read("کتاب", "zzz")
        self.assertFalse(t.fitted)
        self.assertEqual(t.reading, "k?tāb")

    def test_a_hint_for_the_ezafe_keeps_the_linking_vowel(self) -> None:
        t = read("شوخیِ", "śōkhī")
        self.assertEqual(t.reading, "śōkhī-e")
        self.assertTrue(t.ipa.endswith("ɪ"))

    def test_a_hint_with_the_wrong_word_count_is_ignored(self) -> None:
        t = read("دل جان", "dil")
        self.assertEqual(t.reading, "dil jān")
        self.assertTrue(any("different number" in n for n in t.notes))

    def test_aspirates(self) -> None:
        self.assertEqual(read("کھانا").reading, "khānā")
        self.assertEqual(read("کھانا").ipa, "kʰaːnaː")
        self.assertEqual(read("گھر", "ghar").reading, "ghar")
        self.assertEqual(read("ٹھنڈا", "ṭhaṇḍā").reading, "ṭhaṇḍā")
        self.assertEqual(read("ڈھول").reading, "ḍhōl")
        self.assertEqual(read("ڈھول").ipa, "ɖʱoːl")
        self.assertEqual(read("چھوٹا").reading, "chōṭā")
        self.assertEqual(read("چھوٹا").ipa, "tʃʰoːʈaː")

    def test_the_retroflex_and_foreign_letters(self) -> None:
        self.assertEqual(read("ٹ").reading, "ṭ")
        self.assertEqual(read("ڈ").reading, "ḍ")
        self.assertEqual(read("ڑ").ipa, "ɽ")
        self.assertEqual(read("ژ").reading, "z͟h")
        self.assertEqual(read("ژ").ipa, "ʒ")
        self.assertEqual(read("چ").ipa, "tʃ")
        self.assertEqual(read("گ").ipa, "ɡ")
        self.assertEqual(read("خَ").ipa, "xə")
        self.assertEqual(read("قَ").reading, "qa")

    def test_nun_ghunna_nasalises_the_vowel(self) -> None:
        t = read("ہوں")
        self.assertEqual((t.reading, t.ipa), ("hūm̐", "ɦũː"))
        t = read("ہُوں")
        self.assertEqual(t.reading, "hūm̐")
        t = read("جان")
        self.assertEqual((t.reading, t.ipa), ("jān", "dʒaːn"))

    def test_the_hint_may_type_a_nasal_as_n(self) -> None:
        t = read("ہوں", "hoon")
        self.assertTrue(t.fitted)
        self.assertEqual(t.reading, "hūm̐")

    def test_vowel_letters_that_can_be_read_more_than_one_way_are_noted(
            self) -> None:
        t = read("ڈھول")
        self.assertTrue(any("ō" in n for n in t.notes))
        t = read("بڑے")
        self.assertTrue(any("ē or ai" in n for n in t.notes))
        t = read("بَے")
        self.assertEqual(t.reading, "bai")

    def test_hamza_and_the_glide(self) -> None:
        self.assertEqual(read("لائے").reading, "lāyē")
        self.assertEqual(read("آئی").reading, "āyī")
        self.assertEqual(read("جزء").reading, "j?z'")

    def test_shadda_doubles(self) -> None:
        self.assertEqual(read("اَلّٰہ").reading, "allāh")
        self.assertEqual(read("بَچَّہ").reading, "bacca?")

    def test_punctuation_and_words_are_kept(self) -> None:
        t = read("کیا ہے؟")
        self.assertEqual(t.reading, "kyā hai?")
        self.assertEqual(read("دل، جان۔").reading, "dil, jān.")

    def test_the_ipa_of_a_reading(self) -> None:
        self.assertEqual(reading_to_ipa("śōkhī-e"), "ʃoːkʰiːɪ")
        self.assertEqual(reading_to_ipa("vaqt"), "ʋəqt̪")
        self.assertEqual(reading_to_ipa("haim̐"), "ɦɛ̃ː")
        self.assertEqual(reading_to_ipa("k͟hās"), "xaːs")


if __name__ == "__main__":
    unittest.main()
