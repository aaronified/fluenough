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

    def test_length_is_marked(self):
        # The owner's example: పాలు, milk, and పలు, many, read alike before.
        self.check("te", "పాలు", "palu", "pālu", "paːlu")
        self.check("te", "పలు", "palu", "palu", "palu")

    def test_retroflex_is_marked(self):
        self.check("te", "పాట", "pata", "pāṭa", "paːʈa")
        self.check("te", "పాత", "pata", "pāta", "paːt̪a")

    def test_the_hint_drops_the_silent_a(self):
        self.check("hi", "कितना", "kitna", "kitnā", "kɪt̪naː")
        self.check("hi", "समझ", "samajh", "samajh", "səmədʒʱ")

    def test_anusvara_is_the_nasal_said(self):
        self.check("hi", "अंडा", "anda", "aṇḍā", "əɳɖaː")
        self.check("hi", "हैं", "hain", "haim̐", "ɦɛ̃ː")
        self.check("te", "దూరం", "duram", "dūram", "d̪uːram")
        self.check("bn", "বাংলা", "bangla", "bāṅlā", "baŋla")

    def test_bengali_inherent_vowel(self):
        self.check("bn", "কথা", "kotha", "kôthā", "kɔt̪ʰa")
        self.check("bn", "ঘর", "ghor", "ghôr", "ɡʱɔr")
        self.check("bn", "আসি", "ashi", "āśi", "aʃi")

    def test_bengali_ya_phala(self):
        self.check("bn", "ব্যবসা", "byabsha", "bêbśā", "bæbʃa")
        self.check("bn", "বিদ্যা", "bidda", "biddā", "bid̪d̪a")

    def test_assamese_says_its_own_sounds(self):
        self.check("as", "চাহখিনি বৰ গৰম।", "sahkhini bor gorom.",
                   "sāhkhini bôr gôrôm.", "sahkʰini bɔɹ ɡɔɹɔm")
        self.check("as", "ল'ৰা", "lora", "lorā", "loɹa")

    def test_conjuncts_said_otherwise(self):
        self.check("hi", "ज्ञान", "gyan", "gyān", "ɡjaːn")
        self.check("mr", "ज्ञ", "dnya", "dnya", "d̪ɲə")

    def test_marathi_affricates(self):
        self.check("mr", "चार", "char", "cār", "tsar")

    def test_without_a_hint_the_rules_decide(self):
        t = transcribe("कमरा", "hi")
        self.assertEqual(t.reading, "kamrā")

    def test_a_hint_that_does_not_fit_says_so(self):
        t = transcribe("पाट", "hi", "xyz")
        self.assertFalse(t.fitted)


class SpanishTest(unittest.TestCase):
    def test_castilian_broad(self):
        self.assertEqual(spanish_ipa("la casa"), "la ˈkasa")
        self.assertEqual(spanish_ipa("cinco"), "ˈθinko")
        self.assertEqual(spanish_ipa("llave"), "ˈʝabe")
        self.assertEqual(spanish_ipa("el perro"), "el ˈpero")
        self.assertEqual(spanish_ipa("hablar"), "aˈblaɾ")

    def test_written_accent_and_glides(self):
        self.assertEqual(spanish_ipa("¿Cómo estás?"), "ˈkomo esˈtas")
        self.assertEqual(spanish_ipa("buenos días"), "ˈbwenos ˈdias")
        self.assertEqual(spanish_ipa("la ciudad"), "la θjuˈdad")


if __name__ == "__main__":
    unittest.main()
