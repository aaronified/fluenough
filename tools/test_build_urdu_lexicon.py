"""Tests for build_urdu_lexicon.py (the Urdu lexicon made from the kaikki.org
dump) and for how transcribe.py reads the lexicon. No network: the dump is a
tiny fixture, tools/testdata/urdu_kaikki_sample.jsonl."""

import tempfile
import unittest
from pathlib import Path

import build_urdu_lexicon as b
import transcribe as tr

SAMPLE = Path(__file__).with_name("testdata") / "urdu_kaikki_sample.jsonl"


def build_sample():
    with SAMPLE.open(encoding="utf-8") as f:
        return b.build(f)


class RomanToReadingTest(unittest.TestCase):
    def test_conversion_table(self) -> None:
        for roman, reading in [
                ("kitāb", "kitāb"),             # long vowels stay
                ("kare", "karē"),               # plain e and o are long
                ("go", "gō"),
                ("hai", "hai"),                 # ai and au are not e and o
                ("aur", "aur"),
                ("kinhẽ", "kinhēm̐"),            # a nasal vowel: vowel and m̐
                ("kitābõ", "kitābōm̐"),
                ("zubā̃", "zubām̐"),
                ("karū̃", "karūm̐"),
                ("ma͠i", "maim̐"),               # double tilde over ai
                ("h͠ai", "haim̐"),
                ("hū̃ṅgā", "hūm̐gā"),            # ṅ repeating the nasal goes
                ("śams", "śams"),
                ("xudā", "k͟hudā"),              # x is خ
                ("ġazal", "ġazal"),
                ("ġāliban", "ġāliban"),
                ("choṭā", "chōṭā"),
                ("baṛā", "baṛā"),
                ("ḍāk", "ḍāk"),
                ("ʻīsā", "īsā"),                # ʿain is not written
                ("asmā'", "asmā'"),             # hamza is
                ("ṣabr", "sabr"),
                ("Lālī", "lālī"),
                ("bañā", "banā"),
        ]:
            self.assertEqual(b.roman_to_reading(roman), reading, roman)

    def test_anything_unknown_gives_none(self) -> None:
        for roman in ["kyā hai", "-bāz", "ik-hattar", "alif madda ", "ma(r)",
                      "chūṭỹ", "2", "wadera", "mŏrmaniyat"]:
            self.assertIsNone(b.roman_to_reading(roman), roman)

    def test_a_nasal_mark_with_no_vowel_to_carry_it_gives_none(self) -> None:
        self.assertIsNone(b.roman_to_reading("k̃"))


class ConsistentTest(unittest.TestCase):
    def test_the_consonants_must_match(self) -> None:
        self.assertTrue(b.consistent("کتاب", "kitāb"))
        self.assertFalse(b.consistent("کیا", "kaun"))
        self.assertFalse(b.consistent("کتاب", "kitāp"))

    def test_glides_aspirates_and_the_nasal_are_forgiven(self) -> None:
        self.assertTrue(b.consistent("کیا", "kyā"))
        self.assertTrue(b.consistent("کھانا", "khānā"))
        self.assertTrue(b.consistent("ہَن٘سی", "ham̐sī"))
        self.assertTrue(b.consistent("بچہ", "baccā"))


class BuildTest(unittest.TestCase):
    def test_headword_and_inflected_forms_get_rows(self) -> None:
        lex, _ = build_sample()
        self.assertEqual(lex["کتاب"], {"kitāb"})
        self.assertEqual(lex["کتابوں"], {"kitābōm̐"})     # an inflected form
        self.assertEqual(lex["کتابیں"], {"kitābēm̐"})
        self.assertEqual(lex["میں"], {"maim̐"})

    def test_a_homograph_keeps_both_readings(self) -> None:
        lex, _ = build_sample()
        self.assertEqual(lex["ہے"], {"hai", "hē"})

    def test_an_entry_with_no_transliteration_is_dropped(self) -> None:
        lex, _ = build_sample()
        self.assertNotIn("بےنام", lex)      # it has IPA but no transliteration

    def test_a_transliteration_of_other_consonants_is_dropped(self) -> None:
        lex, n = build_sample()
        self.assertEqual(lex["کیا"], {"kyā"})
        self.assertEqual(n["mismatch"], 1)

    def test_several_word_forms_are_not_keyed(self) -> None:
        lex, n = build_sample()
        self.assertEqual(n["multi-word"], 1)
        self.assertFalse(any(" " in k for k in lex))

    def test_the_output_is_sorted_and_deterministic(self) -> None:
        lex, _ = build_sample()
        text = b.render(lex, "2026-10-30")
        self.assertEqual(text, b.render(build_sample()[0], "2026-10-30"))
        rows = [ln for ln in text.splitlines() if not ln.startswith("#")]
        self.assertEqual([r.split("\t")[0] for r in rows],
                         sorted(r.split("\t")[0] for r in rows))
        self.assertIn("ہے\thai|hē", rows)
        self.assertIn("CC-BY-SA 4.0", text)
        self.assertIn("dump of 2026-10-30", text)


class EngineLexiconTest(unittest.TestCase):
    """transcribe.py's use of the lexicon files, in a temp folder."""

    def setUp(self) -> None:
        self._dir, self._lex = tr.UR_LEXICON_DIR, tr._UR_LEXICON
        self._tmp = tempfile.TemporaryDirectory()
        tr.UR_LEXICON_DIR = Path(self._tmp.name)
        tr._UR_LEXICON = None
        lex, _ = build_sample()
        (Path(self._tmp.name) / "urdu_lexicon_kaikki.tsv").write_text(
            b.render(lex, "2026-10-30"), encoding="utf-8")
        (Path(self._tmp.name) / "urdu_words.tsv").write_text(
            "# hand\nہے\thai\nکتابوں\tkitābōn\n", encoding="utf-8")

    def tearDown(self) -> None:
        tr.UR_LEXICON_DIR, tr._UR_LEXICON = self._dir, self._lex
        self._tmp.cleanup()

    def test_the_hand_list_wins_over_the_generated_file(self) -> None:
        lex = tr.urdu_lexicon()
        self.assertEqual(lex["ہے"][0], "hai")
        self.assertEqual(lex["کتابوں"][0], "kitābōn")
        self.assertEqual(lex["کتابیں"][0], "kitābēm̐")

    def test_a_generated_word_supplies_its_vowels(self) -> None:
        t = tr.transcribe("کتاب", "ur")
        self.assertEqual(t.reading, "kitāb")
        self.assertEqual(t.notes, [])

    def test_an_ambiguous_word_is_listed_not_picked(self) -> None:
        (Path(self._tmp.name) / "urdu_words.tsv").write_text(
            "# none\n", encoding="utf-8")
        tr._UR_LEXICON = None
        t = tr.transcribe("ہے", "ur")
        self.assertNotEqual(t.reading, "hai")      # neither is picked
        self.assertTrue(any("ambiguous: hai / hē, review" in n
                            for n in t.notes), t.notes)

    def test_a_hint_still_wins(self) -> None:
        t = tr.transcribe("کتاب", "ur", "kitaab")
        self.assertEqual(t.reading, "kitāb")
        self.assertTrue(t.fitted)

    def test_a_word_listed_twice_in_one_file_is_an_error(self) -> None:
        (Path(self._tmp.name) / "urdu_words.tsv").write_text(
            "ہے\thai\nہے\thē\n", encoding="utf-8")
        tr._UR_LEXICON = None
        with self.assertRaises(ValueError):
            tr.urdu_lexicon()


class CommittedLexiconTest(unittest.TestCase):
    def test_the_committed_file_loads_and_the_hand_list_wins(self) -> None:
        saved = tr._UR_LEXICON
        tr._UR_LEXICON = None
        try:
            lex = tr.urdu_lexicon()
            self.assertGreater(len(lex), 5000)
            self.assertEqual(lex["ہے"][0], "hai")        # the hand entry
            self.assertTrue(any("|" in r for r, _ in lex.values()))
        finally:
            tr._UR_LEXICON = saved


if __name__ == "__main__":
    unittest.main()
