"""Tests for transcribe.py: readings in ISO 15919 letters as said, and IPA
(ADR-0025)."""

import re
import tempfile
import unittest
from pathlib import Path

import transcribe_decks
import validate_decks
from transcribe import (BLOCKS, CannotRead, french_ipa, german_ipa,
                        greek_ipa, italian_ipa, polish_ipa, russian_ipa,
                        spanish_ipa, swahili_ipa, transcribe)


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

    def test_telugu_writes_the_anusvara_as_the_course_does(self) -> None:
        # Readings and IPA of existing Telugu cards (decks/te).
        for word, hint, reading, ipa in (
            ("దీపం", "deepam", "dīpaṁ", "d̪iːpam"),
            ("ప్రసాదం", "prasadam", "prasādaṁ", "prasaːd̪am"),
            ("తోరణం", "toranam", "tōraṇaṁ", "t̪oːraɳam"),
            ("ఆహ్వానం", "ahvanam", "āhvānaṁ", "aːhʋaːnam"),
            ("ఆనందం", "anandam", "ānandaṁ", "aːnand̪am"),
            ("నృత్యం", "nrutyam", "nrutyaṁ", "nrut̪jam"),
            ("ఉత్సాహం", "utsaham", "utsāhaṁ", "ut̪saːham"),
            ("పవిత్రం", "pavitram", "pavitraṁ", "paʋit̪ram"),
            ("సంగీతం", "sangeetam", "saṅgītaṁ", "saŋɡiːt̪am"),
            ("ఆలయం", "alayam", "ālayaṁ", "aːlajam"),
            ("ఉదయం", "udayam", "udayaṁ", "ud̪ajam"),
            ("అన్నం", "annam", "annaṁ", "annam"),
            # Before s or v the course keeps the anusvara.
            ("మాంసం", "mamsam", "māṁsaṁ", "maːmsam"),
            ("సంవత్సరం", "samvatsaram", "saṁvatsaraṁ", "samʋat̪saram"),
            ("సింహం", "simham", "simhaṁ", "simham"),
        ):
            with self.subTest(word):
                self.check("te", word, hint, reading, ipa)

    def test_telugu_anusvara_before_a_stop_is_that_stops_nasal(self) -> None:
        self.check("te", "కారంగా", "karanga", "kāraṅgā", "kaːraŋɡaː")
        self.check("te", "గంట", "ganta", "gaṇṭa", "ɡaɳʈa")
        self.check("te", "పంపండి", "pampandi", "pampaṇḍi", "pampaɳɖi")

    def test_telugu_medial_anusvara_rule(self) -> None:
        # The rule (Plan-Ipa-Revamp-And-Language-Phonology, "Telugu medial
        # anusvara", #1295): the nasal of the next stop; ṁ word-final and
        # before s, v, l; m before another letter. With a hint or without.
        for hint in ("sanchi", None):
            with self.subTest(hint):
                t = transcribe("సంచి", "te", hint)
                self.assertEqual((t.reading, t.ipa), ("sañci", "saɲtʃi"))
        for word, reading, ipa in (
            ("ఉందా", "undā", "und̪aː"),              # dental stop: n
            ("సంపాదన", "sampādana", "sampaːd̪ana"),  # labial: m
            ("పంట", "paṇṭa", "paɳʈa"),               # retroflex: ṇ
            ("మంచి", "mañci", "maɲtʃi"),              # palatal: ñ
            ("అన్నంలో", "annaṁlō", "annamloː"),       # final anusvara + -lō
            ("సంయోగం", "samyōgaṁ", "samjoːɡam"),      # before y: m
            ("సంస్థ", "saṁstha", "samst̪ʰa"),         # s of the cluster: ṁ
            ("సంశయం", "samśayaṁ", "samʃajam"),        # before ś: m
            ("సంహారం", "samhāraṁ", "samhaːram"),      # before h: m
            ("సంరక్షణ", "samrakṣaṇa", "samrakʂaɳa"),  # before r: m
            ("సంక్షేపం", "saṅkṣēpaṁ", "saŋkʂeːpam"),  # before the k of kṣ
            ("ఎస్‌ఎంఎస్", "esemes", "esemes"),        # before a vowel: m
        ):
            with self.subTest(word):
                t = transcribe(word, "te")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))

    def test_telugu_anusvara_does_not_follow_the_typed_hint(self) -> None:
        # A hint typed with m before a dental stop does not make it m.
        t = transcribe("ఉందా", "te", "umda")
        self.assertEqual(t.reading, "undā")

    def test_telugu_suffixes_and_bare_endings(self) -> None:
        # #1357: a suffix written with a hyphen, and a bare ending, read as
        # the vowel they stand for: no consonant, no inherent a, no script
        # left in the reading.
        for word, reading, ipa in (
            ("-ిన", "-ina", "ina"),
            ("-ఇన", "-ina", "ina"),
            ("-అం", "-aṁ", "am"),
            ("-ాం", "-āṁ", "aːm"),
            ("ాం", "āṁ", "aːm"),
            ("ా", "ā", "aː"),
            ("ుంది", "undi", "und̪i"),
        ):
            with self.subTest(word):
                t = transcribe(word, "te")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))
        self.check("te", "-ిన", "-ina", "-ina", "ina")

    def test_telugu_rare_letters(self) -> None:
        # #1361: ఱ is ṟa (IPA as ర), ఌ ౡ read ISO l̥ and l̥̄, ౘ ౙ are ts
        # and dz (ISO 15919 has no letter for them), ఁ is silent.
        for word, reading, ipa in (
            ("ఱ", "ṟa", "ra"),
            ("ఱు", "ṟu", "ru"),
            ("ఌ", "l\u0325", "lu"),
            ("ౡ", "l\u0325\u0304", "luː"),
            ("ౢ", "l\u0325", "lu"),
            ("ౣ", "l\u0325\u0304", "luː"),
            ("ౠ", "rū", "ruː"),
            ("ౘ", "tsa", "tsa"),
            ("ౙ", "dza", "dza"),
            ("కౢ", "kl\u0325", "klu"),
            ("కౣ", "kl\u0325\u0304", "kluː"),
            ("కౢప్తి", "kl\u0325pti", "klupt\u032ai"),
            ("ఁ", "", ""),
            ("ః", "ḥ", "h"),
        ):
            with self.subTest(word):
                t = transcribe(word, "te")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))

    def test_other_languages_keep_their_anusvara(self) -> None:
        self.check("hi", "संसार", "sansar", "saṁsār", "sə̃saːr")

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


class MarathiAnusvaraAndSchwaTest(unittest.TestCase):
    """Marathi's final anusvara and its medial schwa (#1476, owner
    2026-11-21)."""

    def read(self, word, hint=None):
        return transcribe(word, "mr", hint)

    def test_a_word_final_anusvara_is_m_dot_above_as_in_telugu(self) -> None:
        # The owner's "1. Standardize": the same ṁ Telugu writes.
        self.assertEqual(self.read("सागरां").reading, "sāgrāṁ")
        self.assertEqual(self.read("अंधळं").reading, "andhaḷaṁ")
        self.assertEqual(transcribe("అన్నం", "te").reading, "annaṁ")

    def test_the_final_anusvara_is_the_same_with_a_typed_hint(self) -> None:
        self.assertEqual(self.read("अंधळं", "andhalan").reading, "andhaḷaṁ")

    def test_a_final_anusvara_before_punctuation_or_a_space_is_still_final(
            self) -> None:
        self.assertEqual(self.read("सागरां, आणि").reading, "sāgrāṁ, āṇi")
        self.assertEqual(self.read("आम्ही सागरां आहोत").reading.split()[1],
                         "sāgrāṁ")

    def test_the_final_anusvara_ipa_is_unchanged(self) -> None:
        self.assertEqual(self.read("अंधळं").ipa, "ənd̪ʱəɭə̃")

    def test_a_medial_anusvara_is_not_changed(self) -> None:
        self.assertEqual(self.read("मुलांपासून").reading, "mulāmpāsun")
        self.assertEqual(self.read("सांगा").reading, "sāṅgā")
        # Before y, r, l, v, a sibilant or h it was ṁ already.
        self.assertEqual(self.read("आम्हांला").reading, "āmhāṁlā")

    def test_a_chandrabindu_is_not_changed(self) -> None:
        self.assertEqual(self.read("आँ").reading, "ām̐")

    # Hand-typed readings of the course (decks-live, decks/mr), word to the
    # card's reading and id. The engine's rule must keep reproducing them:
    # the regression corpus for #1476 (1,483 of the 1,572 single-word cards
    # matched before this change, and still do, bar the m̐ cards).
    TYPED = {
        "निवडणे": ("nivḍṇe", "mr-1480"), "हरवणे": ("harvṇe", "mr-1174"),
        "समजणे": ("samjṇe", "mr-0719"), "आठवणे": ("āṭhvṇe", "mr-1176"),
        "उगवणे": ("ugvṇe", "mr-1241"), "निवडणूक": ("nivḍṇuk", "mr-1428"),
        "नवरदेव": ("navrdev", "mr-1588"),
        "साखरपुडा": ("sākhrpuḍā", "mr-1590"),
        "सहनशीलता": ("sahnśiltā", "mr-1729"),
        "असहमत": ("ashmat", "mr-1364"), "पुरणपोळी": ("purṇpoḷi", "mr-0925"),
        "सुपरमार्केट": ("suprmārkeṭ", "mr-0982"),
        "चित्रपटगृह": ("citrapṭgruh", "mr-1000"),
        "गैरसमज": ("gairsmaj", "mr-1637"), "खोडरबर": ("khoḍrbar", "mr-1119"),
        "धबधबा": ("dhabdhbā", "mr-0991"), "मेहनती": ("mehnti", "mr-1258"),
        "गणपती": ("gaṇpti", "mr-1041"),
        # Unchanged by the fix.
        "कमळ": ("kamaḷ", "mr-0050"), "सरकार": ("sarkār", "mr-1423"),
        "मित्र": ("mitra", "mr-0213"), "घर": ("ghar", "mr-0048"),
        "सकाळ": ("sakāḷ", "mr-0477"), "माणूस": ("māṇus", "mr-0686"),
        "पुस्तक": ("pustak", "mr-0384"), "चहा": ("cahā", "mr-0559"),
    }

    def test_the_courses_typed_readings_are_still_reproduced(self) -> None:
        for word, (typed, card) in self.TYPED.items():
            self.assertEqual(self.read(word).reading, typed,
                             f"{word} ({card})")

    def test_a_long_chain_of_dropped_schwas_is_cut_back(self) -> None:
        # The cause of #1476: Hindi's rule dropped every schwa side by side
        # in a long word. A chain of three or more is cut to every other
        # schwa, from the right. The check counts an aspirate (dh) as one
        # consonant: no run of three consonants remains.
        for word in ("स्वजनजनधनाचा", "सकलमति", "सकलजनमन"):
            reading = self.read(word).reading
            flat = re.sub("([kgcjṭḍtdpb])h", "\\1", reading)
            self.assertNotRegex(flat, "[^aāiīuūeoêôṛ ]{3}",
                                f"{word} read {reading}")

    def test_the_two_words_of_the_issue(self) -> None:
        # OWNER TO CONFIRM: no source in the repository says how a speaker
        # says either word; the readings follow the rule's alternation from
        # the right. गजवदन is cut because j, v, d (obstruent, glide,
        # obstruent) occurs in no card of the course.
        self.assertEqual(self.read("गजवदन").reading, "gajavdan")
        self.assertEqual(self.read("स्वजनजनधनाचा").reading,
                         "svajnajnadhnācā")
        self.assertEqual(self.read("सकलमति").reading, "saklamti")

    def test_other_schwa_cases_keep_their_old_reading(self) -> None:
        # OWNER TO CONFIRM: the engine's old values, kept so that this fix
        # does not move them. The course types śetkari (शेतकरी mr-0239),
        # krupayā (कृपया), kāhitari (काहीतरी); a reviewer puts लवकरच at
        # lavkarac (about 75 percent).
        self.assertEqual(self.read("शेतकरी").reading, "śetkri")
        self.assertEqual(self.read("कृपया").reading, "krupyā")
        self.assertEqual(self.read("काहीतरी").reading, "kāhitri")
        self.assertEqual(self.read("लवकरच").reading, "lavkrac")
        self.assertEqual(self.read("आदरणीय").reading, "ādrṇiy")

    def test_a_chain_ending_before_ne_is_kept_whole(self) -> None:
        # The course's -णे and -णूक convention: nivḍṇe, ugvṇe, mirvṇuk.
        self.assertEqual(self.read("मिरवणूक").reading, "mirvṇuk")
        self.assertEqual(self.read("वाचवणे").reading, "vācvṇe")

    def test_hindi_keeps_its_own_rule(self) -> None:
        self.assertEqual(transcribe("जनता", "hi").reading, "jantā")
        self.assertEqual(transcribe("कमल", "hi").reading, "kamal")


class TeluguReadingRulesTest(unittest.TestCase):
    """Telugu's anusvara before a postposition, ఋ and ఫ (#1295; defaults the
    owner can reverse, wiki/Plan-Ipa-Revamp-And-Language-Phonology.md,
    "Telugu clitics, ఋ and ఫ")."""

    # Hand-typed readings of the course (decks-live, decks/te, 2026-11-21),
    # target to the card's reading and id. The engine, given the stored
    # reading as its hint (as tools/transcribe_decks.py does), must keep
    # reproducing them: the regression corpus for #1295.
    CORPUS = {
        # An anusvara before a postposition joined to the word is the nasal
        # of the postposition's first letter, ṁ before l: never annaṁtō.
        "ఉలవచారు అన్నంలో కలుపుకోండి.":
            ("ulavacāru annaṁlō kalupukōṇḍi.", "te-6447"),
        "పులుసు అన్నంతో బాగుంటుంది.":
            ("pulusu annantō bāguṇṭundi.", "te-6444"),
        "కోడి పులుసు కారంగా ఉంది.": ("kōḍi pulusu kāraṅgā undi.", "te-6442"),
        "లేపనం చర్మంపై మాత్రమే రాయాలి.":
            ("lēpanaṁ carmampai mātramē rāyāli.", "te-3216"),
        "తాత ముఖంలో ముడతలు ఎక్కువ.":
            ("tāta mukhaṁlō muḍatalu ekkuva.", "te-0731"),
        "ఆ సినిమా ముగింపు చూసి విచారంతో బయటకు వచ్చాం.":
            ("ā sinimā mugimpu cūsi vicārantō bayaṭaku vaccāṁ.", "te-3303"),
        "భూగోళం గుండ్రంగా ఉంటుంది.":
            ("bhūgōḷaṁ guṇḍraṅgā uṇṭundi.", "te-3002"),
        "బ్యాంకు నుంచి అప్పు తీసుకున్నాడు.":
            ("byāṅku nuñci appu tīsukunnāḍu.", "te-3912"),
        # ఋ and ృ are ru (the course rule, Readings-ISO-15919).
        "కృతజ్ఞత": ("krutajñata", "te-3313"), "వృథా": ("vruthā", "te-4613"),
        "అభివృద్ధి": ("abhivruddhi", "te-6309"),
        "దృశ్యం": ("druśyaṁ", "te-3606"), "బృందం": ("brundaṁ", "te-2935"),
        "ఋ": ("ru", "te-0007"), "కృ": ("kru", "te-0068"),
        "ప్రకృతి సౌందర్యాన్ని ఆస్వాదించాం.":
            ("prakruti saundaryānni āsvādiñcāṁ.", "te-6311"),
        # ఫ is ph by default (250 stored readings against 11, which
        # is 138 cards against 8), f where the
        # card types f.
        "ఫోన్": ("phōn", "te-0872"),
        "పోస్టాఫీసు": ("pōsṭāphīsu", "te-0771"),
        "వచ్చినప్పుడు నాకు ఫోన్ చేయండి.":
            ("vaccinappuḍu nāku phōn cēyaṇḍi.", "te-grammar-when"),
        "ఫోటోలు డిలీట్ చేయకండి.": ("phōṭōlu ḍilīṭ cēyakaṇḍi.", "te-0895"),
    }

    def test_the_courses_typed_readings_are_still_reproduced(self) -> None:
        for word, (typed, card) in self.CORPUS.items():
            self.assertEqual(transcribe(word, "te", typed).reading, typed,
                             f"{word} ({card}), with its reading as the hint")
            self.assertEqual(transcribe(word, "te").reading, typed,
                             f"{word} ({card}), with no hint")

    def test_a_clitic_is_written_as_the_nasal_not_as_m_dot(self) -> None:
        # The hint that types ṁ before a postposition does not win: the
        # stored annaṁtō became annantō, annaṁki annaṅki.
        self.assertEqual(transcribe("అన్నంతో", "te", "annaṁtō").reading,
                         "annantō")
        self.assertEqual(transcribe("అన్నంకి", "te", "annaṁki").reading,
                         "annaṅki")
        self.assertEqual(transcribe("అన్నంలో", "te", "annamlō").reading,
                         "annaṁlō")

    def test_a_clitic_ṁ_stays_before_s_and_v(self) -> None:
        # The default: ṁ, not m, before s and v, as before l.
        self.assertEqual(transcribe("అన్నంసు", "te").reading, "annaṁsu")
        self.assertEqual(transcribe("అన్నంవి", "te").reading, "annaṁvi")
        self.assertEqual(transcribe("సంవత్సరం", "te").reading, "saṁvatsaraṁ")

    def test_a_vocalic_r_is_ru_whatever_the_hint_spells(self) -> None:
        for hint in ("krṛtajñata", "kr̥tajñata", "krutajñata"):
            self.assertEqual(
                transcribe("కృతజ్ఞత", "te", hint).reading, "krutajñata")

    def test_a_loanword_f_is_kept_only_when_typed(self) -> None:
        self.assertEqual(transcribe("ఫోన్", "te").reading, "phōn")
        self.assertEqual(transcribe("ఫోన్", "te", "fōn").reading, "fōn")
        self.assertEqual(transcribe("ఫోన్", "te", "fōn").ipa, "foːn")


class NoHintTest(unittest.TestCase):
    """The three fixes that apply only with no hint (#315)."""

    def read(self, lang, word):
        return transcribe(word, lang).reading

    def test_a_words_last_vowel_after_a_cluster_ending_in_r_is_said(self) -> None:
        self.assertEqual(self.read("hi", "मित्र"), "mitra")
        self.assertEqual(self.read("mr", "मित्र"), "mitra")
        self.assertEqual(self.read("gu", "મિત્ર"), "mitra")
        # A last vowel after a single consonant is still dropped.
        self.assertEqual(self.read("hi", "कमल"), "kamal")

    def test_bengali_drops_an_inherent_vowel_inside_a_word(self) -> None:
        self.assertEqual(self.read("bn", "আপনার"), "āpnār")

    def test_a_bengali_conjunct_on_its_own_holds_its_consonant(self) -> None:
        # The ব-ফলা is not dropped on a card of its own (#1398).
        for word, reading in (("জ্ব", "jjô"), ("ত্ব", "ttô"),
                              ("দ্ব", "ddô"), ("ধ্ব", "ddhô"),
                              ("শ্ব", "śśô")):
            self.assertEqual(self.read("bn", word), reading)

    def test_a_bengali_ba_phala_inside_a_word_holds_the_consonant(self) -> None:
        self.assertEqual(self.read("bn", "বিশ্ব"), "biśśo")
        self.assertEqual(self.read("bn", "বিদ্বান"), "biddān")
        self.assertEqual(self.read("bn", "অশ্ব"), "ôśśo")

    def test_a_bengali_ba_phala_at_a_words_start_says_nothing(self) -> None:
        self.assertEqual(self.read("bn", "স্বামী"), "śāmi")
        self.assertEqual(self.read("bn", "দ্বার"), "dār")
        self.assertEqual(self.read("bn", "ধ্বনি"), "dhoni")
        self.assertEqual(self.read("bn", "জ্বর"), "jôr")

    def test_a_doubled_consonant_with_a_ba_phala_is_held_twice_only(self) -> None:
        self.assertEqual(self.read("bn", "উজ্জ্বল"), "ujjol")
        self.assertEqual(self.read("bn", "সত্ত্ব"), "śôtto")
        self.assertEqual(self.read("bn", "তত্ত্ব"), "tôtto")

    def test_reph_and_ba_is_r_and_b_not_a_ba_phala(self) -> None:
        # র্ব says both letters, and its last vowel (#1402).
        self.assertEqual(self.read("bn", "পূর্ব"), "purbo")
        self.assertEqual(self.read("bn", "গর্ব"), "gôrbo")
        self.assertEqual(self.read("bn", "দুর্বলতা"), "durboltā")

    def test_a_bengali_ya_phala_word_keeps_its_last_vowel(self) -> None:
        self.assertEqual(self.read("bn", "বাক্য"), "bākko")
        self.assertEqual(self.read("bn", "সত্য"), "śotto")
        self.assertEqual(self.read("bn", "অসাম্য"), "ôśāmmo")

    def test_a_doubled_consonant_with_a_ya_phala_is_held_twice_only(
            self) -> None:
        self.assertEqual(self.read("bn", "উজ্জ্য"), "ujjo")

    def test_an_assamese_ba_phala_holds_the_consonant_and_ends_the_word(
            self) -> None:
        # The course writes bixx and razôtt: no vowel after the held
        # consonant, where Bengali says one (বিশ্ব biśśo).
        self.assertEqual(self.read("as", "বিশ্ব"), "bixx")
        self.assertEqual(self.read("as", "ৰাজত্ব"), "rāzôtt")
        self.assertEqual(transcribe("ভ্ৰাতৃত্ব", "as").ipa, "bʱɹatritt")
        self.assertEqual(self.read("bn", "বিশ্ব"), "biśśo")

    def test_an_assamese_word_ending_in_r_ba_has_no_last_vowel(self) -> None:
        self.assertEqual(self.read("as", "গৰ্ব"), "gôrb")
        self.assertEqual(self.read("bn", "গর্ব"), "gôrbo")

    def test_an_assamese_ya_phala_still_ends_in_its_vowel(self) -> None:
        # The course is mixed here (ৰাজ্য rāzjô, নৃত্য nritj), so the shared
        # rule stays.
        self.assertEqual(transcribe("ৰাজ্য", "as").ipa, "ɹazjɔ")

    def test_an_assamese_conjunct_on_a_card_of_its_own_keeps_its_vowel(
            self) -> None:
        # All 23 such cards of the course: ক্ত ktô, স্থ sthô, ল্ল llô.
        self.assertEqual(transcribe("ক্ত", "as").ipa, "ktɔ")
        self.assertEqual(transcribe("স্থ", "as").ipa, "stʰɔ")
        self.assertEqual(transcribe("ল্ল", "as").ipa, "llɔ")
        self.assertEqual(self.read("as", "ব্ব"), "bbô")
        # A word that ends in a conjunct but has a vowel before it does not.
        self.assertEqual(transcribe("শক্ত", "as").ipa, "xɔkt")

    def test_assamese_digits_are_read_as_the_number_cards_read_them(
            self) -> None:
        self.assertEqual(transcribe("০", "as").ipa, "xunjɔ")
        self.assertEqual(transcribe("৫", "as").ipa, "pãs")
        self.assertEqual(self.read("as", "৭"), "xāt")

    def test_sibilants_follow_the_table_unless_before_a_stop(self) -> None:
        self.assertEqual(self.read("bn", "সকাল"), "śôkāl")
        self.assertEqual(self.read("as", "সকাল"), "xôkāl")
        self.assertEqual(self.read("bn", "স্টেশন"), "sṭeśon")
        self.assertEqual(self.read("as", "স্কুল"), "skul")

    def test_a_hint_still_decides_the_sibilant(self) -> None:
        self.assertEqual(transcribe("সকাল", "bn", "sokal").reading, "sôkāl")


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

    def test_the_voiced_velar_before_a_small_ya_yu_yo_is_the_ipa_letter(self) -> None:
        # #1428: the stem was Hepburn's ASCII g (U+0067); the house IPA
        # writes the script ɡ (U+0261).
        for kana, reading, ipa in (
            ("ぎゃ", "gya", "\u0261ja"),
            ("ぎゅ", "gyu", "\u0261j\u026f"),
            ("ぎょ", "gyo", "\u0261jo"),
            ("ギョーザ", "gyooza", "\u0261joːdza"),
            ("いっぎょう", "iggyou", "i\u0261\u0261joː"),
        ):
            with self.subTest(kana):
                t = transcribe(kana, "ja")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))

    def test_no_japanese_kana_reading_has_an_ascii_g_in_its_ipa(self) -> None:
        from transcribe import _KANA, _SMALL_VOWELS, _YOON
        for c in _KANA:
            for small in ("", *_YOON, *_SMALL_VOWELS):
                with self.subTest(c + small):
                    ipa = transcribe(c + small, "ja").ipa
                    self.assertNotIn("g", ipa)

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

    def test_hangul_ipa_is_broad_phonemic_with_the_same_sound_changes(self) -> None:
        for hangul, ipa in (
            ("한국어", "hankukʌ"),           # liaison
            ("감사합니다", "kamsahamnita"),   # ㅂ before ㄴ is m
            ("좋다", "tɕotʰa"),              # ㅎ aspirates the ㄷ
            ("학교", "hakk͈jo"),              # tensing after an obstruent coda
            ("먹다", "mʌkt͈a"),
            ("신라", "silla"),               # ㄹㄹ
            ("종로", "tɕoŋno"),
            ("괜찮아요", "kwentɕʰanajo"),    # ㅐ is e, ㅊ aspirated, glide j
            ("위", "wi"),
            ("희망", "himaŋ"),               # ㅢ after a consonant is i
            ("안녕하세요 커피", "annjʌŋhasejo kʰʌpʰi"),
        ):
            with self.subTest(hangul):
                self.assertEqual(transcribe(hangul, "ko").ipa, ipa)

    def test_hangul_final_h_is_silent_alone_and_before_a_space(self) -> None:
        for hangul, reading, ipa in (
            ("좋", "jo", "tɕo"),
            ("좋 다", "jo da", "tɕo ta"),
        ):
            with self.subTest(hangul):
                t = transcribe(hangul, "ko")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))

    def test_hangul_punctuation_only_token_leaves_no_extra_space(self) -> None:
        for hangul, ipa in (
            ("한 - 국", "han kuk"),
            ("한국 ?", "hankuk"),
            ("한국 ... 어", "hankuk ʌ"),
        ):
            with self.subTest(hangul):
                self.assertEqual(transcribe(hangul, "ko").ipa, ipa)

    def test_hangul_reading_is_unchanged_by_the_ipa(self) -> None:
        for hangul, reading in (
            ("학교", "hakgyo"),
            ("먹다", "meokda"),
            ("닭", "dalk"),
            ("안녕하세요 커피", "annyeonghaseyo keopi"),
        ):
            with self.subTest(hangul):
                self.assertEqual(transcribe(hangul, "ko").reading, reading)

    def test_mandarin_is_the_hint_and_nothing_without_one(self) -> None:
        self.assertEqual(
            transcribe("你好", "zh", "nǐ hǎo").reading, "nǐ hǎo")
        with self.assertRaises(CannotRead):
            transcribe("你好", "zh")

    def test_mandarin_ipa_is_derived_from_the_pinyin(self) -> None:
        for pinyin, ipa in (
            ("nǐ hǎo", "ni˨˩˦ xau˨˩˦"),          # citation tones, no sandhi
            ("shì", "ʂɨ˥˩"),                    # apical vowels are ɨ
            ("zì", "tsɨ˥˩"),
            ("rì", "ɻɨ˥˩"),
            ("xué", "ɕɥɛ˧˥"),                   # ü is written u after j q x
            ("jiǔ", "tɕjou˨˩˦"),                # iu is iou
            ("huì", "xwei˥˩"),                  # ui is uei
            ("dūn", "twən˥˥"),                  # un is uen
            ("bó", "pwo˧˥"),                    # o after b p m f is uo
            ("yuè", "ɥɛ˥˩"),                    # y and w are spellings
            ("wǒ", "wo˨˩˦"),
            ("lǜ", "ly˥˩"),
            ("wǒmen", "wo˨˩˦mən˙"),            # neutral tone ends in ˙
            ("de", "tə˙"),                      # e is ə when neutral
            ("xiān", "ɕjɛn˥˥"),                 # not xi + an
            ("Xī'ān", "ɕi˥˥an˥˥"),             # the apostrophe divides
            ("èr", "ɚ˥˩"),
            ("shìr", "ʂɚ˥˩"),                  # erhua
            ("yìdiǎnr", "i˥˩tjɐɻ˨˩˦"),
            ("gēr", "kɤɻ˥˥"),                  # ger is not g + er
            ("hǎo ma?", "xau˨˩˦ ma˙"),          # punctuation is dropped
        ):
            with self.subTest(pinyin):
                self.assertEqual(transcribe("x", "zh", pinyin).ipa, ipa)

    def test_mandarin_pinyin_that_cannot_be_read_gives_no_ipa_and_a_note(self) -> None:
        t = transcribe("导航", "zh", "dǎováng")
        self.assertEqual((t.reading, t.ipa, t.fitted), ("dǎováng", "", False))
        self.assertIn("dǎováng", t.notes[0])

    def test_toki_pona_stress_is_on_the_first_syllable(self) -> None:
        self.assertEqual(transcribe("jan suli li toki.", "tok").ipa,
                         "jan ˈsuli li ˈtoki")

    def test_toki_pona_words_next_to_punctuation_are_kept(self) -> None:
        self.assertEqual(transcribe("toki pona! sina pilin seme?", "tok").ipa,
                         "ˈtoki ˈpona ˈsina ˈpilin ˈseme")
        self.assertEqual(transcribe("\"mi moku\": o kama.", "tok").ipa,
                         "mi ˈmoku o ˈkama")


class FrenchTest(unittest.TestCase):
    """French (FR-120): standard Parisian pronunciation, broad, in the
    notation of the decks. One word per rule, each checked against Wiktionary
    (en.wiktionary through kaikki.org; fr.wiktionary for femme, monsieur,
    travail, oiseau, famille). The phrases follow the rules in the tool's
    notes. The tool does not drop the schwa inside a word (a documented
    limit), so no test asserts such a word."""

    def test_words_whose_pronunciation_is_attested(self) -> None:
        for word, ipa in (
            ("pain", "pɛ̃"),  # nasal vowel
            ("lundi", "lœ̃di"),  # nasal œ̃
            ("oiseau", "wazo"),  # oi, eau, s between vowels
            ("heureux", "øʁø"),  # eu open
            ("cœur", "kœʁ"),  # œu closed
            ("famille", "famij"),  # ill after a consonant
            ("travail", "tʁavaj"),  # ail
            ("bouteille", "butɛj"),  # eill
            ("nuit", "nɥi"),  # ui
            ("chien", "ʃjɛ̃"),  # ien
            ("nation", "nasjɔ̃"),  # tion
            ("question", "kɛstjɔ̃"),  # stion keeps t
            ("mangeons", "mɑ̃ʒɔ̃"),  # ge before o
            ("garçon", "ɡaʁsɔ̃"),  # ç
            ("musique", "myzik"),  # qu and mute e
            ("petit", "pəti"),  # schwa in the first syllable
            ("février", "fevʁije"),  # i after obstruent plus liquid
            ("voyage", "vwajaʒ"),  # oy before a vowel
            ("exemple", "ɛɡzɑ̃pl"),  # initial ex before a vowel
            ("coûter", "kute"),  # oû
            ("femme", "fam"),  # irregular
            ("monsieur", "məsjø"),  # irregular
            ("beaucoup", "boku"),  # silent final p
        ):
            with self.subTest(word):
                self.assertEqual(french_ipa(word), ipa)

    def test_the_language_code_reaches_the_french_rules(self) -> None:
        t = transcribe("Bonjour, Madame !", "fr")
        self.assertEqual(t.ipa, "bɔ̃ʒuʁ madam")
        self.assertEqual(t.reading, "Bonjour, Madame !")

    def test_an_elided_word_is_joined_to_the_next(self) -> None:
        for text, ipa in (
            ("l'arrivée", "laʁive"),
            ("je m'appelle", "ʒə mapɛl"),
            ("qu'il", "kil"),
            ("j'ai", "ʒe"),
            ("d'accord", "dakɔʁ"),
            ("s'il vous plaît", "sil vu plɛ"),
            ("aujourd'hui", "oʒuʁdɥi"),
        ):
            with self.subTest(text):
                self.assertEqual(french_ipa(text), ipa)

    def test_obligatory_liaison_is_written_and_nothing_else_is_guessed(self) -> None:
        for text, ipa in (
            ("les enfants", "le zɑ̃fɑ̃"),
            ("les hôtels", "le zotɛl"),
            ("vous êtes ici", "vu zɛt isi"),
            ("mon ami", "mɔ̃n ami"),
            ("vingt ans", "vɛ̃t ɑ̃"),
            ("deux ans", "døz ɑ̃"),
            ("dix heures", "diz œʁ"),
            ("six livres", "si livʁ"),
            ("un petit ami", "œ̃ pətit ami"),
            ("un grand homme", "œ̃ ɡʁɑ̃t ɔm"),
            ("c'est un accident", "sɛt œ̃n aksidɑ̃"),
            # an h aspiré blocks the liaison; est + vowel is optional, so
            # it is not guessed
            ("les haricots", "le aʁiko"),
            ("il est ici", "il ɛ isi"),
        ):
            with self.subTest(text):
                self.assertEqual(french_ipa(text), ipa)

    def test_no_liaison_consonant_before_et_or_ou(self) -> None:
        for text, ipa in (
            ("grand et fort", "ɡʁɑ̃ e fɔʁ"),
            ("deux et deux", "dø e dø"),
            ("un et deux", "œ̃ e dø"),
            ("il est petit et gentil", "il ɛ pəti e ʒɑ̃ti"),
            ("petit ou grand", "pəti u ɡʁɑ̃"),
        ):
            with self.subTest(text):
                self.assertEqual(french_ipa(text), ipa)

    def test_compound_numbers(self) -> None:
        for text, ipa in (
            ("vingt-deux", "vɛ̃tdø"),
            ("vingt-et-un", "vɛ̃teœ̃"),
            ("quatre-vingts", "katʁəvɛ̃"),
            ("quatre-vingt-dix-neuf", "katʁəvɛ̃diznœf"),
        ):
            with self.subTest(text):
                self.assertEqual(french_ipa(text), ipa)

    def test_listed_verbs_in_ment_are_silent(self) -> None:
        self.assertEqual(french_ipa("ils dorment"), "il dɔʁm")
        self.assertEqual(french_ipa("ils ferment"), "il fɛʁm")
        self.assertEqual(french_ipa("vraiment"), "vʁɛmɑ̃")

    def test_a_pause_blocks_the_liaison(self) -> None:
        self.assertEqual(french_ipa("Nous, étudiants."), "nu etydjɑ̃")

    def test_hyphenated_words_are_read_whole(self) -> None:
        self.assertEqual(french_ipa("est-ce"), "ɛs")
        self.assertEqual(french_ipa("peut-être"), "pøtɛtʁ")

    def test_a_verb_ending_in_ent_is_silent_and_a_listed_noun_is_not(self) -> None:
        self.assertEqual(french_ipa("ils parlent anglais"), "il paʁl ɑ̃ɡlɛ")
        self.assertEqual(french_ipa("souvent"), "suvɑ̃")

    def test_text_that_is_not_french_letters_cannot_be_read(self) -> None:
        with self.assertRaises(CannotRead):
            transcribe("3 pommes", "fr")

    def test_spanish_is_untouched(self) -> None:
        self.assertEqual(transcribe("la casa", "es").ipa, spanish_ipa("la casa"))


class SpanishCqTest(unittest.TestCase):
    def test_cqu_is_one_k(self) -> None:
        self.assertEqual(spanish_ipa("Bécquer"), "ˈbekeɾ")
        self.assertEqual(spanish_ipa("Jacquelin"), "xaˈkelin")

    def test_real_doubled_c_and_plain_que_are_unchanged(self) -> None:
        self.assertEqual(spanish_ipa("acción"), "akˈθjon")
        self.assertEqual(spanish_ipa("que"), "ke")
        self.assertEqual(spanish_ipa("quiero"), "ˈkjeɾo")
        self.assertEqual(spanish_ipa("Bécquer"), transcribe("Bécquer", "es").ipa)


class SwahiliTest(unittest.TestCase):
    def test_consonant_digraphs_and_prenasalised(self):
        self.assertEqual(swahili_ipa("chai"), "ˈtʃai")
        self.assertEqual(swahili_ipa("ngoma"), "ˈŋɡoma")
        self.assertEqual(swahili_ipa("ng'ombe"), "ˈŋombe")
        self.assertEqual(swahili_ipa("nyumba"), "ˈɲumba")
        self.assertEqual(swahili_ipa("shule"), "ˈʃule")
        self.assertEqual(swahili_ipa("jambo"), "ˈdʒambo")

    def test_glide_and_nasal_before_consonant(self):
        self.assertEqual(swahili_ipa("mwalimu"), "mwaˈlimu")
        self.assertEqual(swahili_ipa("mbili"), "ˈmbili")
        # A word-initial m before another consonant is a syllable.
        self.assertEqual(swahili_ipa("mtu"), "ˈmtu")

    def test_stress_is_penultimate_and_vowels_stay_apart(self):
        self.assertEqual(swahili_ipa("asante"), "aˈsante")
        self.assertEqual(swahili_ipa("hii"), "ˈhii")
        self.assertEqual(swahili_ipa("kiswahili"), "kiswaˈhili")
        self.assertEqual(swahili_ipa("na"), "na")

    def test_dispatch_and_punctuation(self):
        t = transcribe("Habari yako?", "sw")
        self.assertEqual(t.ipa, "haˈbaɾi ˈjako")
        self.assertTrue(t.fitted)

    def test_other_scripts_and_digits_cannot_be_read(self):
        for bad in ("café", "a1", "ಕನ್ನಡ"):
            with self.assertRaises(CannotRead):
                swahili_ipa(bad)


class ItalianTest(unittest.TestCase):
    """Italian (it), broad, as decks/it writes it. The expected forms agree
    with Wiktionary's pronunciations of the same words."""

    def check(self, pairs):
        for text, ipa in pairs:
            with self.subTest(text=text):
                self.assertEqual(italian_ipa(text), ipa)

    def test_soft_and_hard_c_g_and_the_silent_i(self):
        self.check((("ciao", "ˈtʃao"), ("giorno", "ˈdʒorno"),
                    ("chiesa", "ˈkjɛza"), ("ghiaccio", "ˈɡjattʃo"),
                    ("spaghetti", "spaˈɡetti"), ("lingua", "ˈlinɡwa"),
                    ("cinque", "ˈtʃinkwe"), ("che", "ke")))

    def test_sounds_long_between_vowels_are_written_long(self):
        self.check((("gnocchi", "ˈɲɔkki"), ("famiglia", "faˈmiʎʎa"),
                    ("scena", "ˈʃɛna"), ("pesce", "ˈpeʃʃe"),
                    ("sciare", "ˈʃare"), ("gli amici", "ʎi aˈmitʃi"),
                    ("bagno", "ˈbaɲɲo")))

    def test_doubled_letters_are_doubled_and_split_the_syllable(self):
        self.check((("acqua", "ˈakkwa"), ("oggi", "ˈɔddʒi"),
                    ("grazie", "ˈɡrattsje"), ("pizza", "ˈpittsa"),
                    ("stazione", "statˈtsjone"), ("caffè", "kafˈfɛ"),
                    ("ottobre", "otˈtobre")))

    def test_s_and_z_voicing(self):
        self.check((("casa", "ˈkaza"), ("rosa", "ˈrɔza"),
                    ("scusi", "ˈskuzi"), ("studente", "stuˈdɛnte"),
                    ("zero", "ˈdzɛro"), ("pranzo", "ˈprandzo"),
                    ("organizzare", "orɡanidˈdzare"),
                    ("colazione", "kolatˈtsjone")))

    def test_i_and_u_before_a_vowel_are_glides_unless_stressed(self):
        self.check((("piano", "ˈpjano"), ("storia", "ˈstɔrja"),
                    ("nuovo", "ˈnwɔvo"), ("uomo", "ˈwɔmo"),
                    ("dieci", "ˈdjɛtʃi"), ("aiuto", "aˈjuto"),
                    ("mio", "ˈmio"), ("zio", "ˈtsio"), ("due", "ˈdue"),
                    ("riunione", "riuˈnjone"), ("riempire", "riemˈpire")))

    def test_a_written_accent_stresses_the_last_vowel_and_sets_openness(self):
        self.check((("città", "tʃitˈta"), ("perché", "perˈke"),
                    ("università", "universiˈta"), ("può", "pwɔ"),
                    ("più", "pju"), ("è", "ɛ")))

    def test_penultimate_stress_is_the_default(self):
        self.check((("parlare", "parˈlare"), ("italiano", "itaˈljano"),
                    ("buonasera", "bwonaˈsera"),
                    ("arrivederci", "arriveˈdertʃi")))

    def test_endings_that_fix_the_stress(self):
        self.check((("possibile", "posˈsibile"), ("facile", "ˈfatʃile"),
                    ("musica", "ˈmuzika"), ("bellissimo", "belˈlissimo"),
                    ("farai", "faˈraj"), ("farmacologia", "farmakoloˈdʒia"),
                    ("libreria", "libreˈria")))

    def test_frequent_exceptions_to_those_endings(self):
        self.check((("amico", "aˈmiko"), ("gentile", "dʒenˈtile")))

    def test_open_e_and_o_by_ending_and_by_table(self):
        self.check((("bello", "ˈbɛllo"), ("stella", "ˈstɛlla"),
                    ("senza", "ˈsɛntsa"), ("medico", "ˈmɛdiko"),
                    ("bene", "ˈbɛne"), ("otto", "ˈɔtto"),
                    ("tavolo", "ˈtavolo"), ("telefono", "teˈlɛfono"),
                    ("sera", "ˈsera")))

    def test_a_hint_marks_what_the_letters_do_not(self):
        self.assertEqual(italian_ipa("leggo"), "ˈleɡɡo")
        self.assertEqual(italian_ipa("leggo", "lèggo"), "ˈlɛɡɡo")
        # Marked per word, with the punctuation of the text.
        self.assertEqual(italian_ipa("Che leggo!", "che lèggo"),
                         "ke ˈlɛɡɡo")

    def test_a_hint_that_is_not_the_text_is_ignored_and_says_so(self):
        t = transcribe("leggo", "it", "cena")
        self.assertEqual(t.ipa, "ˈleɡɡo")
        self.assertFalse(t.fitted)
        self.assertTrue(transcribe("leggo", "it", "lèggo").fitted)

    def test_sentences_and_elision(self):
        self.check((("Mi chiamo Marco.", "mi ˈkjamo ˈmarko"),
                    ("Dov'è il bagno?", "doˈvɛ il ˈbaɲɲo"),
                    ("Parla più lentamente, per favore.",
                     "ˈparla pju lentaˈmente per faˈvore"),
                    ("Quanto costa?", "ˈkwanto ˈkɔsta"),
                    ("L'acqua è fredda.", "ˈlakkwa ɛ ˈfredda"),
                    ("Un caffè, per favore.", "un kafˈfɛ per faˈvore"),
                    ("Io non capisco.", "ˈio non kaˈpisko"),
                    ("Tu parli inglese?", "tu ˈparli inˈɡleze")))

    def test_the_decks_existing_cards_that_are_right_come_out_the_same(self):
        self.check((("Sì, grazie.", "si ˈɡrattsje"),
                    ("Sì, parlo italiano.", "si ˈparlo itaˈljano"),
                    ("Non parlo inglese.", "non ˈparlo inˈɡleze"),
                    ("Pane e vino.", "ˈpane e ˈvino"),
                    ("Acqua, per favore.", "ˈakkwa per faˈvore"),
                    ("mi dispiace", "mi disˈpjatʃe"),
                    ("come si chiama?", "ˈkome si ˈkjama"),
                    ("piacere", "pjaˈtʃere"), ("aiuto!", "aˈjuto")))

    def test_so_is_open_and_cui_is_one_syllable(self):
        self.check((("non lo so", "non lo sɔ"), ("cui", "kui"),
                    ("sui", "sui")))

    def test_everyday_words_with_open_vowels_and_dz(self):
        self.check((("dopo", "ˈdɔpo"), ("nonna", "ˈnɔnna"),
                    ("destra", "ˈdɛstra"), ("prezzo", "ˈprɛttso"),
                    ("pezzo", "ˈpɛttso"), ("zucchero", "ˈdzukkero"),
                    ("gnocco", "ˈɲɔkko"), ("America", "aˈmɛrika")))

    def test_voiceless_s_after_a_compound_part(self):
        self.check((("girasole", "dʒiraˈsole"), ("risalire", "risaˈlire")))

    def test_elision_reads_the_host_word_with_its_own_stress(self):
        self.check((("l'amico", "laˈmiko"), ("un'amica", "unaˈmika"),
                    ("un'idea", "uniˈdɛa"), ("l'acqua", "ˈlakkwa"),
                    ("dell'acqua", "delˈlakkwa"), ("un'ora", "uˈnora")))

    def test_dispatch(self):
        t = transcribe("Grazie mille", "it")
        self.assertEqual(t.ipa, "ˈɡrattsje ˈmille")
        self.assertTrue(t.fitted)

    def test_other_letters_and_words_without_a_vowel_cannot_be_read(self):
        for bad in ("naïve", "a1", "ಕನ್ನಡ", "pkt"):
            with self.assertRaises(CannotRead):
                italian_ipa(bad)


class GermanTest(unittest.TestCase):
    """German (de), broad. Every expected form is a form that the entry's
    pronunciation section on en.wiktionary lists for the word (read
    2026-11-28), in Wiktionary's symbols with its syllable dots, secondary
    stress marks, glottal stops and non-syllabic marks left out, r written ʁ
    and the diphthong of Deutsch written ɔɪ, as the engine writes them."""

    def check(self, pairs):
        for text, ipa in pairs:
            with self.subTest(text=text):
                self.assertEqual(german_ipa(text), ipa)

    def test_ch_is_ç_after_front_vowels_and_x_after_back_ones(self):
        self.check((("Nacht", "naxt"), ("ich", "ɪç"), ("Küche", "ˈkʏçə"),
                    ("Milch", "mɪlç"), ("Buch", "buːx"),
                    ("machen", "ˈmaxən"), ("Tochter", "ˈtɔxtɐ"),
                    ("Kirche", "ˈkɪʁçə"), ("wichtig", "ˈvɪçtɪç"),
                    ("König", "ˈkøːnɪç")))

    def test_sch_sp_st_tsch_z_w_v_qu_ng_nk(self):
        self.check((("schön", "ʃøːn"), ("Fisch", "fɪʃ"),
                    ("Mensch", "mɛnʃ"), ("Deutsch", "dɔɪtʃ"),
                    ("sprechen", "ˈʃpʁɛçən"), ("Stadt", "ʃtat"),
                    ("Straße", "ˈʃtʁaːsə"), ("zwei", "tsvaɪ"),
                    ("Zahl", "tsaːl"), ("drei", "dʁaɪ"),
                    ("Quelle", "ˈkvɛlə"), ("Englisch", "ˈɛŋlɪʃ"),
                    ("Bank", "baŋk"), ("trinken", "ˈtʁɪŋkən"),
                    ("Vater", "ˈfaːtɐ"), ("Sonne", "ˈzɔnə")))

    def test_final_obstruents_are_voiceless(self):
        self.check((("Tag", "taːk"), ("gut", "ɡuːt"), ("Rad", "ʁaːt"),
                    ("und", "ʊnt"), ("Hand", "hant"), ("Zug", "tsuːk"),
                    ("Abend", "ˈaːbənt"), ("Ordnung", "ˈɔʁtnʊŋ")))

    def test_a_vowel_is_long_before_one_consonant_short_before_more(self):
        self.check((("Glas", "ɡlaːs"), ("Brot", "bʁoːt"),
                    ("Kopf", "kɔpf"), ("Mutter", "ˈmʊtɐ"),
                    ("Butter", "ˈbʊtɐ"), ("Zimmer", "ˈtsɪmɐ"),
                    ("Nummer", "ˈnʊmɐ"), ("Bruder", "ˈbʁuːdɐ"),
                    ("Wasser", "ˈvasɐ"), ("Hilfe", "ˈhɪlfə"),
                    ("Schule", "ˈʃuːlə"), ("Käse", "ˈkɛːzə"),
                    ("können", "ˈkœnən"), ("Löffel", "ˈlœfəl"),
                    ("Zucker", "ˈtsʊkɐ"), ("Fenster", "ˈfɛnstɐ")))

    def test_function_words_with_a_short_vowel(self):
        self.check((("das", "das"), ("es", "ɛs"), ("in", "ɪn"),
                    ("man", "man"), ("bis", "bɪs"), ("mit", "mɪt"),
                    ("bin", "bɪn"), ("hat", "hat"), ("ist", "ɪst"),
                    ("du", "duː")))

    def test_r_is_ʁ_before_a_vowel_ɐ̯_after_a_long_vowel_ɐ_in_er(self):
        self.check((("hier", "hiːɐ̯"), ("Jahr", "jaːɐ̯"), ("Uhr", "uːɐ̯"),
                    ("Tür", "tyːɐ̯"), ("Natur", "naˈtuːɐ̯"),
                    ("Kultur", "kʊlˈtuːɐ̯"), ("Lehrer", "ˈleːʁɐ"),
                    ("Lehrerin", "ˈleːʁəʁɪn"), ("Morgen", "ˈmɔʁɡən"),
                    ("Arbeit", "ˈaʁbaɪt"), ("Freund", "fʁɔɪnt")))

    def test_an_unstressed_prefix_leaves_the_stress_to_the_stem(self):
        self.check((("besuchen", "bəˈzuːxən"), ("vergessen", "fɛɐ̯ˈɡɛsən"),
                    ("Gesundheit", "ɡəˈzʊnthaɪt"),
                    ("Entschuldigung", "ɛntˈʃʊldiɡʊŋ")))

    def test_endings_that_carry_the_stress(self):
        self.check((("diskutieren", "dɪskuˈtiːʁən"),
                    ("Information", "ɪnfɔʁmaˈtsjoːn"),
                    ("Universität", "univɛʁziˈtɛːt"),
                    ("Studentin", "ʃtuˈdɛntɪn"), ("Natur", "naˈtuːɐ̯")))

    def test_second_part_of_a_compound_takes_the_stress(self):
        self.check((("zurück", "tsuˈʁʏk"), ("zusammen", "tsuˈzamən"),
                    ("wofür", "voˈfyːɐ̯")))

    def test_the_first_syllable_is_the_default_stress(self):
        self.check((("Bitte", "ˈbɪtə"), ("heißen", "ˈhaɪsən"),
                    ("kostet", "ˈkɔstət"), ("Kinder", "ˈkɪndɐ"),
                    ("gehen", "ˈɡeːən"), ("Zeitung", "ˈtsaɪtʊŋ"),
                    ("Wiedersehen", "ˈviːdɐzeːən"),
                    ("Auto", "ˈaʊto"), ("anfangen", "ˈanfaŋən"),
                    ("Mädchen", "ˈmɛːtçən")))

    def test_words_the_table_marks(self):
        self.check((("Hallo", "haˈloː"), ("Kaffee", "kaˈfeː"),
                    ("Hotel", "hoˈtɛl"), ("Kino", "ˈkiːnoː"),
                    ("damit", "daˈmɪt"), ("langsam", "ˈlaŋzaːm")))

    def test_sch_and_zw_stay_together_when_the_stress_is_marked(self):
        self.check((("Schwester", "ˈʃvɛstɐ"), ("zwanzig", "ˈtsvantsɪç"),
                    ("schlafen", "ˈʃlaːfən"), ("Schlüssel", "ˈʃlʏsəl"),
                    ("Zwiebel", "ˈtsviːbəl"), ("schwierig", "ˈʃviːʁɪç"),
                    ("Schlafzimmer", "ˈʃlaːftsɪmɐ"),
                    ("schreiben", "ˈʃʁaɪbən")))

    def test_ch_after_a_diphthong_or_ie_is_ç(self):
        self.check((("leicht", "laɪçt"), ("weich", "vaɪç"),
                    ("gleich", "ɡlaɪç"), ("Zeichen", "ˈtsaɪçən"),
                    ("euch", "ɔɪç"), ("riechen", "ˈʁiːçən"),
                    ("vielleicht", "fiˈlaɪçt")))

    def test_stems_that_look_like_prefixed_words(self):
        self.check((("gestern", "ˈɡɛstɐn"), ("Beere", "ˈbeːʁə"),
                    ("Berlin", "bɛɐ̯ˈliːn"), ("Erdbeere", "ˈeːɐ̯tbeːʁə"),
                    ("Erdgeschoss", "ˈeːɐ̯tɡəʃɔs")))

    def test_n_before_k_across_a_separable_prefix_is_not_ŋ(self):
        self.check((("einkaufen", "ˈaɪnkaʊfən"), ("ankommen", "ˈankɔmən")))

    def test_the_days_and_other_long_vowels_of_a_compounds_second_part(self):
        self.check((("Montag", "ˈmoːntaːk"), ("Sonntag", "ˈzɔntaːk"),
                    ("Dienstag", "ˈdiːnstaːk"), ("Freitag", "ˈfʁaɪtaːk"),
                    ("Samstag", "ˈzamstaːk"), ("Mittag", "ˈmɪtaːk"),
                    ("Donnerstag", "ˈdɔnɐstaːk"),
                    ("Nachmittag", "ˈnaːxmɪtaːk"),
                    ("Vormittag", "ˈfoːɐ̯mɪtaːk"), ("Mittwoch", "ˈmɪtvɔx"),
                    ("Bahnhof", "ˈbaːnhoːf"), ("Flughafen", "ˈfluːkhaːfən"),
                    ("Flugzeug", "ˈfluːktsɔɪk")))

    def test_a_long_vowel_before_r_and_a_consonant(self):
        self.check((("Arzt", "aːɐ̯tst"), ("Urlaub", "ˈuːɐ̯laʊp"),
                    ("erste", "ˈeːɐ̯stə"), ("Fahrrad", "ˈfaːɐ̯ʁaːt"),
                    ("Geburtstag", "ɡəˈbuːɐ̯tstaːk")))

    def test_loan_words_and_months_the_table_marks(self):
        self.check((("natürlich", "naˈtyːɐ̯lɪç"),
                    ("Apotheke", "apoˈteːkə"), ("Kartoffel", "kaʁˈtɔfəl"),
                    ("Tomate", "toˈmaːtə"), ("Salat", "zaˈlaːt"),
                    ("Gitarre", "ɡiˈtaʁə"), ("Minute", "miˈnuːtə"),
                    ("Januar", "ˈjanuaːɐ̯"), ("Februar", "ˈfeːbʁuaːɐ̯"),
                    ("April", "aˈpʁɪl"), ("Oktober", "ɔkˈtoːbɐ"),
                    ("Dezember", "deˈtsɛmbɐ"), ("Brötchen", "ˈbʁøːtçən"),
                    ("Obst", "oːpst"), ("vierzig", "ˈfɪʁtsɪç"),
                    ("nämlich", "ˈnɛːmlɪç")))

    def test_a_hint_gives_stress_and_length(self):
        # Wiktionary: Banane baˈnaːnə, Sprache ˈʃpʁaːxə, Bücher ˈbyːçɐ,
        # Mond moːnt, Telefon (ˌ)teːləˈfoːn.
        self.assertEqual(german_ipa("Banane", "Banáne"), "baˈnaːnə")
        self.assertEqual(german_ipa("Sprache", "Spra:che"), "ˈʃpʁaːxə")
        self.assertEqual(german_ipa("Bücher", "Bü:cher"), "ˈbyːçɐ")
        self.assertEqual(german_ipa("Mond", "Mo:nd"), "moːnt")
        self.assertEqual(german_ipa("Telefon", "Te:lefón"), "teːləˈfoːn")

    def test_a_hint_is_used_only_if_it_is_the_text(self):
        self.assertEqual(german_ipa("Mond", "Tag"), german_ipa("Mond"))
        t = transcribe("Mond", "de", "Tag")
        self.assertFalse(t.fitted)
        t = transcribe("Mond", "de", "Mo:nd")
        self.assertTrue(t.fitted)
        self.assertEqual(t.ipa, "moːnt")

    def test_a_phrase_and_the_dispatch(self):
        t = transcribe("Hier ist das Wasser.", "de")
        self.assertEqual(t.ipa, "hiːɐ̯ ɪst das ˈvasɐ")
        self.assertTrue(t.fitted)

    def test_é_is_stressed_and_long(self):
        # Wiktionary: Café /kaˈfeː/.
        self.check((("Café", "kaˈfeː"),))
        self.assertEqual(german_ipa("Hier ist das Café"),
                         "hiːɐ̯ ɪst das kaˈfeː")

    def test_a_letter_and_a_word_read_the_letter_by_its_name(self):
        # Wiktionary: S-Bahn ˈɛsˌbaːn, U-Bahn ˈʔuːbaːn.
        self.check((("S-Bahn", "ˈɛsbaːn"), ("U-Bahn", "ˈuːbaːn")))

    def test_respelled_loan_words_and_exceptions_and_two_in_the_marks(self):
        # Each is the first form of the word's en.wiktionary entry.
        self.check((
            ("Handy", "ˈhɛndi"), ("Chef", "ʃɛf"), ("Ferien", "ˈfeːʁiən"),
            ("China", "ˈçiːna"), ("Chance", "ˈʃãːsə"),
            ("Computer", "kɔmˈpjuːtɐ"), ("Restaurant", "ʁɛstoˈʁãː"),
            ("Familie", "faˈmiːliə"), ("Banane", "baˈnaːnə"),
            ("Telefon", "teːləˈfoːn"), ("November", "noˈvɛmbɐ"),
            ("Museum", "muˈzeːʊm"), ("Toilette", "toaˈlɛtə"),
            ("Job", "dʒɔp"), ("Team", "tiːm"), ("Sport", "ʃpɔʁt"),
            ("Pizza", "ˈpɪtsa"), ("Tee", "teː"), ("Taxi", "ˈtaksi"),
            ("Bus", "bʊs"), ("Foto", "ˈfoːto"), ("Hotel", "hoˈtɛl"),
            ("Kino", "ˈkiːnoː")))

    def test_the_stress_mark_goes_before_a_whole_initial_cluster(self):
        # Wiktionary: Kneipe ˈknaɪ̯pə, Knödel ˈknøːdl̩, Knoblauch
        # ˈknoːˌblaʊ̯x, Pflaume ˈpflaʊ̯mə, Pfeffer ˈpfɛfɐ, Pflanze
        # [ˈpflantsə], Psalm /psalm/.
        self.check((("Kneipe", "ˈknaɪpə"), ("Knödel", "ˈknøːdəl"),
                    ("Knoblauch", "ˈknoːblaʊx"), ("Pflaume", "ˈpflaʊmə"),
                    ("Pfeffer", "ˈpfɛfɐ"), ("Pflanze", "ˈpflantsə"),
                    ("Psalm", "psalm")))

    def test_a_respelled_word_with_its_plural(self):
        # Wiktionary: Fotos ˈfoːtos, Jobs dʒɔps, Familien faˈmiːliən.
        self.check((("Fotos", "ˈfoːtos"), ("Jobs", "dʒɔps"),
                    ("Familien", "faˈmiːliən")))

    def test_a_hint_beats_a_respelled_word(self):
        self.assertEqual(german_ipa("Job", "Jo^b"), "jɔp")

    def test_a_letter_compound_in_brackets_or_with_a_hint(self):
        self.check((("(S-Bahn)", "ˈɛsbaːn"), ("S-Bahn.", "ˈɛsbaːn")))
        self.assertEqual(german_ipa("S-Bahn", "S-Ba:hn"), "ˈɛsbaːn")
        self.assertEqual(german_ipa("Die U-Bahn", "Die U-Ba:hn"),
                         "diː ˈuːbaːn")

    def test_other_letters_and_words_without_a_vowel_cannot_be_read(self):
        for bad in ("naïve", "a1", "ಕನ್ನಡ", "pkt"):
            with self.assertRaises(CannotRead):
                german_ipa(bad)


class MalayalamTest(unittest.TestCase):
    """Malayalam (ml), read from its letters the way the decks write it
    (decks/ml, and the review queue's notes on its conventions)."""

    # Words and phrases of the Malayalam decks, with the card's own reading
    # and broad IPA: the transcriber gives both back exactly.
    WORDS = (
        ('ഇപ്പോഴും', 'ippōḻuṁ', 'ippoːɻum'),
        ('ശരിക്കും', 'śarikkuṁ', 'ʃəɾikkum'),
        ('തീരെ', 'tīre', 't̪iːɾe'),
        ('ഏകദേശം', 'ēkadēśaṁ', 'eːkəd̪eːʃam'),
        ('കാക്ക', 'kākka', 'kaːkka'),
        ('കുതിര', 'kutira', 'kut̪iɾa'),
        ('പൂച്ച', 'pūcca', 'puːtʃtʃa'),
        ('കൈ', 'kai', 'kai'),
        ('മുഖം', 'mukhaṁ', 'mukʰam'),
        ('എല്ല്', 'ell', 'ell'),
        ('നഖം', 'nakhaṁ', 'nəkʰam'),
        ('തൊലി', 'toli', 't̪oli'),
        ('മരുന്ന്', 'marunn', 'məɾunn'),
        ('തോൾ', 'tōḷ', 't̪oːɭ'),
        ('തല', 'tala', 't̪əla'),
        ('ബ്ലൗസ്', 'blaus', 'blaus'),
        ('മഞ്ഞ', 'mañña', 'məɲɲa'),
        ('വിലകുറഞ്ഞ', 'vilakuṟañña', 'ʋiləkuɾəɲɲa'),
        ('ഇടുങ്ങിയ', 'iṭuṅṅiya', 'iʈuŋŋija'),
        ('വൃത്തിയുള്ള', 'vṛttiyuḷḷa', 'ʋɾɯt̪t̪ijuɭɭa'),
        ('വേഗത്തിലുള്ള', 'vēgattiluḷḷa', 'ʋeːɡət̪t̪iluɭɭa'),
        ('പ്രകാശമുള്ള', 'prakāśamuḷḷa', 'pɾəkaːʃəmuɭɭa'),
        ('ചൂടുള്ള', 'cūṭuḷḷa', 'tʃuːʈuɭɭa'),
        ('വീതിയുള്ള', 'vītiyuḷḷa', 'ʋiːt̪ijuɭɭa'),
        ('മൂല', 'mūla', 'muːla'),
        ('മകൾ', 'makaḷ', 'məkaɭ'),
        ('മകൻ', 'makaṉ', 'məkan'),
        ('ഭാര്യ', 'bhārya', 'bʱaːɾja'),
        ('നല്ല', 'nalla', 'nəlla'),
        ('ഭക്ഷണം', 'bhakṣaṇaṁ', 'bʱəkʂəɳam'),
        ('വെളുത്തുള്ളി', 'veḷuttuḷḷi', 'ʋeɭut̪t̪uɭɭi'),
        ('ഇഡ്ഡലി', 'iḍḍali', 'iɖɖəli'),
        ('ബിരിയാണി', 'biriyāṇi', 'biɾijaːɳi'),
        ('മോര്', 'mōr', 'moːɾ'),
        ('മസാല', 'masāla', 'məsaːla'),
        ('ചോറ്', 'cōṟ', 'tʃoːɾ'),
        ('അരി', 'ari', 'əɾi'),
        ('സോഫ', 'sōpha', 'soːpʰa'),
        ('കോണിൽ', 'kōṇil', 'koːɳil'),
        ('മുകളിൽ', 'mukaḷil', 'mukəɭil'),
        ('അടുത്ത്', 'aṭutt', 'əʈut̪t̪'),
        ('ഇറച്ചി', 'iṟacci', 'iɾətʃtʃi'),
        ('പഴങ്ങൾ', 'paḻaṅṅaḷ', 'pəɻəŋŋaɭ'),
        ('ഉണ്ടാക്കൂ', 'uṇṭākkū', 'uɳʈaːkkuː'),
        ('പഠിക്കൂ', 'paṭhikkū', 'pəʈʰikkuː'),
        ('കാണിക്കൂ', 'kāṇikkū', 'kaːɳikkuː'),
        ('പറയൂ', 'paṟayū', 'pəɾəjuː'),
        ('പതിനേഴ്', 'patinēḻ', 'pət̪ineːɻ'),
        ('പന്ത്രണ്ട്', 'pantraṇṭ', 'pənt̪ɾaɳʈ'),
        ('ലക്ഷം', 'lakṣaṁ', 'ləkʂam'),
        ('എൺപത്', 'eṇpat', 'eɳpat̪'),
        ('തൊണ്ണൂറ്', 'toṇṇūṟ', 't̪oɳɳuːɾ'),
        ('മുപ്പത്', 'muppat', 'muppat̪'),
        ('ഇരുനൂറ്', 'irunūṟ', 'iɾunuːɾ'),
        ('നമസ്കാരം', 'namaskāraṁ', 'nəməskaːɾam'),
        ('ശരി', 'śari', 'ʃəɾi'),
        ('പാർക്ക്', 'pārkk', 'paːɾkk'),
        ('കളിസ്ഥലം', 'kaḷisthalaṁ', 'kəɭist̪ʰəlam'),
        ('ഹോട്ടൽ', 'hōṭṭal', 'hoːʈʈal'),
        ('അവന്റെ', 'avanṟe', 'əʋənt̪ɾe'),
        ('പകുതി', 'pakuti', 'pəkut̪i'),
        ('എന്ത്', 'ent', 'ent̪'),
        ('ഉണ്ടോ', 'uṇṭō', 'uɳʈoː'),
        ('നല്ലതാണോ?', 'nallatāṇō?', 'nəllət̪aːɳoː'),
        ('ജനൽ', 'janal', 'dʒənal'),
        ('കണ്ണാടി', 'kaṇṇāṭi', 'kəɳɳaːʈi'),
        ('തരൂ', 'tarū', 't̪əɾuː'),
    )
    SENTENCES = (
        ('ഈ മാങ്ങ പുളിയാണ്.', 'ī māṅṅa puḷiyāṇ.', 'iː maːŋŋa puɭijaːɳ'),
        ('നിങ്ങളുടെ വീട് വലുതാണ്.', 'niṅṅaḷuṭe vīṭ valutāṇ.', 'niŋŋəɭuʈe ʋiːʈ ʋəlut̪aːɳ'),
        ('നാവ് വേദനിക്കുന്നു.', 'nāv vēdanikkunnu.', 'naːʋ ʋeːd̪ənikkunnu'),
        ('ഒരുപാട് ആളുകൾ.', 'orupāṭ āḷukaḷ.', 'oɾupaːʈ aːɭukaɭ'),
        ('നിനക്ക് അച്ചാർ ഇഷ്ടമാണോ?', 'ninakk accār iṣṭamāṇō?', 'ninakk ətʃtʃaːɾ iʂʈəmaːɳoː'),
        ('പട്ടണം അടുത്ത്.', 'paṭṭaṇaṁ aṭutt.', 'pəʈʈəɳam əʈut̪t̪'),
        ('ആയിരം രൂപ.', 'āyiraṁ rūpa.', 'aːjiɾam ɾuːpa'),
        ('അടുപ്പിൽ ചട്ടി വെക്കൂ.', 'aṭuppil caṭṭi vekkū.', 'əʈuppil tʃəʈʈi ʋekkuː'),
        ('നാല് ആളുകൾ.', 'nāl āḷukaḷ.', 'naːl aːɭukaɭ'),
        ('ആപ്പിൾ ഒന്ന്.', 'āppiḷ onn.', 'aːppiɭ onn'),
        ('ബാഗ് കൊണ്ടുവരൂ.', 'bāg koṇṭuvarū.', 'baːɡ koɳʈuʋəɾuː'),
        ('എന്റെ ചെവി വേദനിക്കുന്നു.', 'enṟe cevi vēdanikkunnu.', 'ent̪ɾe tʃeʋi ʋeːd̪ənikkunnu'),
        ('ചെരിപ്പ് ഇവിടെ.', 'ceripp iviṭe.', 'tʃeɾipp iʋiʈe'),
        ('ചായക്കട ഇവിടെ ഉണ്ട്.', 'cāyakkaṭa iviṭe uṇṭ.', 'tʃaːjəkkəʈa iʋiʈe uɳʈ'),
        ('ജോലി തുടങ്ങൂ.', 'jōli tuṭaṅṅū.', 'dʒoːli t̪uʈəŋŋuː'),
        ('എളുപ്പമുള്ള ചോദ്യം.', 'eḷuppamuḷḷa cōdyaṁ.', 'eɭuppəmuɭɭa tʃoːd̪jam'),
        ('അടുപ്പ് ചൂടാണ്.', 'aṭupp cūṭāṇ.', 'əʈupp tʃuːʈaːɳ'),
        ('വൃത്തികെട്ട കൈ.', 'vṛttikeṭṭa kai.', 'ʋɾɯt̪t̪ikeʈʈa kai'),
    )

    def test_deck_words_are_read_as_the_decks_write_them(self) -> None:
        for word, reading, ipa in self.WORDS:
            with self.subTest(word):
                t = transcribe(word, "ml")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))

    def test_deck_sentences_are_read_as_the_decks_write_them(self) -> None:
        for text, reading, ipa in self.SENTENCES:
            with self.subTest(text):
                t = transcribe(text, "ml")
                self.assertEqual(
                    (t.reading, t.ipa), (reading, ipa.rstrip(".")))

    def check(self, word, reading, ipa, hint=None):
        t = transcribe(word, "ml", hint)
        self.assertEqual((t.reading, t.ipa), (reading, ipa))

    def test_a_geminate_is_written_and_said_doubled(self) -> None:
        self.check("ഇക്ക", "ikka", "ikka")
        self.check("അമ്മ", "amma", "əmma")
        self.check("മഞ്ഞ", "mañña", "məɲɲa")
        self.check("ഭക്ഷണം", "bhakṣaṇaṁ", "bʱəkʂəɳam")

    def test_long_vowels_take_a_length_mark_and_consonants_never(self) -> None:
        self.check("പാല്", "pāl", "paːl")
        self.check("പല", "pala", "pəla")
        self.check("തൂക്കം", "tūkkaṁ", "t̪uːkkam")
        self.check("ഏത്", "ēt", "eːt̪")
        self.check("എന്ത്", "ent", "ent̪")

    def test_the_inherent_a_is_a_schwa_unless_it_is_the_last_vowel(
            self) -> None:
        # അവൻ: the first a is [ə], the a of വ is the last vowel, [a].
        self.check("അവൻ", "avaṉ", "əʋan")
        self.check("അത്", "at", "at̪")
        self.check("ഇല്ല", "illa", "illa")
        self.check("കടല", "kaṭala", "kəʈəla")

    def test_the_vowel_less_virama_ending_a_word_is_not_said(self) -> None:
        self.check("ഇത്", "it", "it̪")
        self.check("കുറച്ച്", "kuṟacc", "kuɾatʃtʃ")
        self.check("വീട്", "vīṭ", "ʋiːʈ")

    def test_chillu_letters_are_a_consonant_with_no_vowel(self) -> None:
        self.check("ഞാൻ", "ñāṉ", "ɲaːn")
        self.check("വിരൽ", "viral", "ʋiɾal")
        self.check("വെള്ളം", "veḷḷaṁ", "ʋeɭɭam")
        self.check("തോൾ", "tōḷ", "t̪oːɭ")
        self.check("കണ്", "kaṇ", "kaɳ")
        self.check("പാർക്ക്", "pārkk", "paːɾkk")

    def test_na_is_n_and_the_chillu_na_is_n_with_a_line(self) -> None:
        self.check("എനിക്ക്", "enikk", "enikk")
        self.check("മകൻ", "makaṉ", "məkan")

    def test_the_two_r_letters_are_both_a_tap(self) -> None:
        self.check("അരി", "ari", "əɾi")
        self.check("ചോറ്", "cōṟ", "tʃoːɾ")
        self.check("ചോർ", "cōr", "tʃoːɾ")

    def test_the_retroflex_and_the_lateral_letters_are_told_apart(
            self) -> None:
        self.check("മുഴു", "muḻu", "muɻu")
        self.check("മുളു", "muḷu", "muɭu")
        self.check("മുലു", "mulu", "mulu")
        self.check("കണ", "kaṇa", "kəɳa")
        self.check("കന", "kana", "kəna")

    def test_nta_is_n_and_a_stop_and_a_tap(self) -> None:
        self.check("എന്റെ", "enṟe", "ent̪ɾe")
        self.check("നിന്റെ", "ninṟe", "nint̪ɾe")
        self.check("പന്ത്", "pant", "pant̪")

    def test_tta_is_a_held_alveolar_stop_and_stta_is_st(self) -> None:
        self.check("മുറ്റം", "muṟṟaṁ", "muttam")
        self.check("ഒറ്റ", "oṟṟa", "otta")
        self.check("സ്റ്റേഷൻ", "sṭēṣaṉ", "sʈeːʂan")
        self.check("പോസ്റ്റ്", "pōsṭ", "poːsʈ")

    def test_cchha_is_said_as_a_held_ca_with_no_breath(self) -> None:
        self.check("അച്ഛൻ", "acchaṉ", "ətʃtʃan")
        self.check("ഖ", "kha", "kʰa")

    def test_aspirates_are_breathy_and_a_held_one_is_said_doubled(
            self) -> None:
        self.check("പഠിക്കൂ", "paṭhikkū", "pəʈʰikkuː")
        self.check("ധനം", "dhanaṁ", "d̪ʱənam")
        self.check("ഭാര്യ", "bhārya", "bʱaːɾja")
        self.check("ഇക്ഖ", "ikkha", "ikkʰa")
        self.check("വിദ്യാർത്ഥി", "vidyārtthi", "ʋid̪jaːɾt̪t̪ʰi")

    def test_a_hint_with_an_f_makes_pha_an_f(self) -> None:
        self.check("ഓഫീസ്", "ōphīs", "oːpʰiːs")
        self.check("ഓഫീസ്", "ōfīs", "oːfiːs", "ofis")
        self.check("ഫാൻ ഓഫീസ്", "phāṉ ōfīs", "pʰaːn oːfiːs", "phan ofis")
        # A hint that does not pair with the words changes nothing.
        self.check("ഫാൻ ഓഫീസ്", "phāṉ ōphīs", "pʰaːn oːpʰiːs", "fan")

    def test_the_anusvara_is_m_and_the_visarga_is_h(self) -> None:
        self.check("സിംഹം", "siṁhaṁ", "simham")
        self.check("ദുഃഖം", "duḥkhaṁ", "d̪uhkʰam")

    def test_the_vowel_signs_and_independent_vowels(self) -> None:
        self.check("ഐസ്", "ais", "ais")
        self.check("ഔഷധം", "auṣadhaṁ", "auʂəd̪ʱam")
        self.check("കൈ", "kai", "kai")
        self.check("ബ്ലൗസ്", "blaus", "blaus")
        self.check("വൃത്തി", "vṛtti", "ʋɾɯt̪t̪i")
        self.check("ഒരു", "oru", "oɾu")
        self.check("ഓരോ", "ōrō", "oːɾoː")
        self.check("എഴുതൂ", "eḻutū", "eɻut̪uː")

    def test_punctuation_is_kept_in_the_reading_and_not_in_the_ipa(
            self) -> None:
        self.check("എന്ത്?", "ent?", "ent̪")
        self.check("അതെ, ഞാൻ.", "ate, ñāṉ.", "ət̪e ɲaːn")

    def test_a_word_in_malayalam_script_is_all_the_transcriber_needs(
            self) -> None:
        t = transcribe("ഞാൻ വരുന്നു", "ml")
        self.assertTrue(t.fitted)
        self.assertEqual(t.ipa, "ɲaːn ʋəɾunnu")


DECK = """# a comment that must survive
schema: 1
id: "te-x"
part: "core"
kind: "vocab"
language: { code: "te", iso639_3: "tel", name: "Telugu" }
cards:
  - id: "te-9001"
    target: "పొలంలో"   # trailing comment
    reading: "polamlō"
    ipa: "polamloː"
  - id: "te-9002"
    target: "చేను"
    reading: 'cēnu'
    ipa: "t͡ɕeːnu"
  - id: "te-9003"
    target: "దూరంగా"
    reading: "dūraṅgā"
    ipa: "d̪uːraŋɡaː"
"""

AMBIGUOUS = """schema: 1
id: "te-y"
part: "core"
cards:
  - id: "te-9101"
    target: "పొలంలో"
    reading: "polamlō"
    reading: "polamlō"
  - id: "te-9102"
    target: "పొలంలో"
    reading: "polamlō"
  - id: "te-9102"
    target: "పొలంలో"
    reading: "polamlō"
"""


class TamilTest(unittest.TestCase):
    """Tamil (ta), read from its letters the way the decks write it
    (decks/ta on decks-live)."""

    # Cards of the Tamil decks: reading and broad IPA, as the cards have
    # them (the decks' ʧ is written tʃ, as in the other courses).
    WORDS = (
        ("வணக்கம்", "vaṇakkam", "ʋaɳakkam"),
        ("நன்றி", "naṉṟi", "nanri"),
        ("தமிழ்", "tamiḻ", "t̪amiɻ"),
        ("கழிவறை எங்கே?", "kaḻivaṟai eṅkē?", "kaɻiʋarai eŋkeː"),
        ("சாப்பாடு", "cāppāṭu", "saːppaːʈu"),
        ("கொஞ்சம்", "koñcam", "koɲtʃam"),
        ("இறைச்சி", "iṟaicci", "iraitʃtʃi"),
        ("பென்சில்", "peṉcil", "pentʃil"),
        ("டாக்சி", "ṭākci", "ʈaːktʃi"),
        ("ஜன்னல்", "jaṉṉal", "dʒannal"),
        ("மகள்", "makaḷ", "makaɭ"),
        ("போய் வருகிறேன்", "pōy varukiṟēṉ", "poːj ʋaɾukireːn"),
        ("ரசம்", "racam", "ɾasam"),
        ("எண்ணெய்", "eṇṇey", "eɳɳej"),
        ("ஆம்", "ām", "aːm"),
    )

    def test_deck_words_are_read_as_the_decks_write_them(self) -> None:
        for word, reading, ipa in self.WORDS:
            with self.subTest(word):
                t = transcribe(word, "ta")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))

    def test_no_inherent_vowel_after_a_pulli(self) -> None:
        self.assertEqual(transcribe("க்", "ta").reading, "k")
        self.assertEqual(transcribe("கல்", "ta").reading, "kal")

    def test_a_stop_is_voiceless_between_vowels_in_the_broad_ipa(
            self) -> None:
        self.assertEqual(transcribe("அகம்", "ta").ipa, "akam")
        self.assertEqual(transcribe("அபாடு", "ta").ipa, "apaːʈu")

    def test_grantha_letters_and_aytam(self) -> None:
        self.assertEqual(transcribe("க்ஷமை", "ta").ipa, "kʂamai")
        self.assertEqual(transcribe("ஸ்ரீ", "ta").reading, "srī")
        self.assertEqual(transcribe("ஃபோன்", "ta").reading, "ḵpōṉ")

    def test_c_is_s_alone_and_tʃ_after_a_stop_or_nasal(self) -> None:
        self.assertEqual(transcribe("சரி", "ta").ipa, "saɾi")
        self.assertEqual(transcribe("பச்சை", "ta").ipa, "patʃtʃai")
        self.assertEqual(transcribe("மஞ்சள்", "ta").ipa, "maɲtʃaɭ")


class SantaliTest(unittest.TestCase):
    """Santali (sat): Ol Chiki is an alphabet, read letter for letter. Letter
    values are Wiktionary's; the cards' hand-written readings are checked
    against the engine (the ones that differ are queued for a speaker)."""

    # Cards of decks/sat on decks-live whose reading and broad `ipa` the
    # letters give (the decks' ʧ is written tʃ, as in the other courses).
    WORDS = (
        ("ᱦᱮᱸ", "hẽ", "hẽ"),
        ("ᱤᱧ", "iñ", "iɲ"),
        ("ᱟᱢ", "am", "am"),
        ("ᱟᱡ", "ac'", "atʃ"),
        ("ᱢᱤᱫ", "mit'", "mit"),
        ("ᱫᱟᱜ", "dak'", "dak"),
        ("ᱡᱚᱢᱟᱜ", "jo̠mak'", "dʒɔmak"),
        ("ᱨᱩᱴᱤ", "ruṭi", "ruʈi"),
        ("ᱪᱮᱫ", "cet'", "tʃet"),
        ("ᱚᱲᱟᱜ", "o̠ṛak'", "ɔɽak"),
        ("ᱧᱩᱛᱩᱢ", "ñutum", "ɲutum"),
        ("ᱢᱟᱨᱟᱝ", "maraṅ", "maraŋ"),
    )

    def test_deck_words_are_read_from_their_letters(self) -> None:
        for word, reading, ipa in self.WORDS:
            with self.subTest(word):
                t = transcribe(word, "sat")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))

    def test_voiced_stops_are_checked_at_the_end_of_a_word_only(self) -> None:
        self.assertEqual(transcribe("ᱵᱩᱜᱤ", "sat").reading, "bugi")
        self.assertEqual(transcribe("ᱵᱟᱜ", "sat").reading, "bak'")
        self.assertEqual(transcribe("ᱵᱟᱜ", "sat").ipa, "bak")
        # ᱼ keeps the checked sound inside a word; ᱽ keeps it plain at the end.
        self.assertEqual(transcribe("ᱵᱟᱜᱼᱛᱮ", "sat").reading, "bak'te")
        self.assertEqual(transcribe("ᱵᱟᱜᱽ", "sat").reading, "bag")

    def test_marks_nasalise_and_lengthen_the_vowel_before_them(self) -> None:
        self.assertEqual(transcribe("ᱟᱹ", "sat").ipa, "aː")
        self.assertEqual(transcribe("ᱟᱹ", "sat").reading, "ā")
        self.assertEqual(transcribe("ᱟᱸ", "sat").ipa, "ã")
        both = transcribe("ᱟᱺ", "sat")
        self.assertEqual((both.reading, both.ipa), ("ā̃", "ãː"))

    def test_oh_aspirates_the_stop_before_it(self) -> None:
        self.assertEqual(transcribe("ᱵᱷᱟ", "sat").ipa, "bʱa")
        self.assertEqual(transcribe("ᱠᱷᱟ", "sat").ipa, "kʰa")
        self.assertEqual(transcribe("ᱠᱷᱟ", "sat").reading, "kha")

    def test_a_digit_is_the_digit_and_has_no_ipa(self) -> None:
        t = transcribe("᱑᱒", "sat")
        self.assertEqual((t.reading, t.ipa), ("12", ""))
        self.assertTrue(t.notes)
        self.assertEqual(transcribe("ᱥᱳ᱾", "sat").reading, "so.")

    def test_a_mark_with_nothing_to_attach_to_cannot_be_read(self) -> None:
        for bad in ("ᱸ", "ᱛᱸ", "ᱼ", "ᱟᱽ", "abc"):
            with self.subTest(bad):
                with self.assertRaises(CannotRead):
                    transcribe(bad, "sat")


class SanskritTest(unittest.TestCase):
    """Classical Sanskrit (sa): IAST letters and broad IPA, from the
    Devanagari alone; every inherent a is said (no Hindi schwa deletion)."""

    WORDS = (
        ("संस्कृतम्", "saṃskṛtam", "sə̃skr\u0329t̪əm"),
        ("रामः", "rāmaḥ", "raːməh"),
        ("धर्मक्षेत्रे", "dharmakṣetre", "d̪ʱərməkʂeːt̪reː"),
        ("गच्छति", "gacchati", "ɡətʃtʃʰət̪i"),
        ("ऋषि", "ṛṣi", "r\u0329ʂi"),
        ("विद्या", "vidyā", "ʋid̪jaː"),
        ("नमः", "namaḥ", "nəməh"),
        ("कृष्ण", "kṛṣṇa", "kr\u0329ʂɳə"),
        ("ज्ञानम्", "jñānam", "dʒɲaːnəm"),
        ("पितॄणाम्", "pitṝṇām", "pit̪r\u0329ːɳaːm"),
        ("तेऽपि", "te'pi", "t̪eːpi"),
        ("ॐ", "oṃ", "oːm"),
    )

    def test_deck_style_words(self) -> None:
        for word, reading, ipa in self.WORDS:
            with self.subTest(word):
                t = transcribe(word, "sa")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))
                self.assertTrue(t.fitted)

    def test_sa_is_a_registered_indic_block(self) -> None:
        self.assertEqual(BLOCKS["sa"], 0x0900)

    def test_every_inherent_a_is_said_not_deleted_as_in_hindi(self) -> None:
        # Word-final and medial: कमलम् is ka-ma-la-m, not Hindi kamal.
        self.assertEqual(transcribe("कमल", "sa").reading, "kamala")
        self.assertEqual(transcribe("कमलम्", "sa").reading, "kamalam")
        self.assertEqual(transcribe("भवति", "sa").reading, "bhavati")
        self.assertEqual(transcribe("राम", "sa").ipa, "raːmə")

    def test_virama_ends_a_word_and_makes_conjuncts(self) -> None:
        self.assertEqual(transcribe("वाक्", "sa").reading, "vāk")
        self.assertEqual(transcribe("क्ष", "sa").reading, "kṣa")
        self.assertEqual(transcribe("त्र", "sa").ipa, "t̪rə")
        self.assertEqual(transcribe("स्थित", "sa").ipa, "st̪ʰit̪ə")

    def test_jna_is_j_plus_n_palatal_not_hindi_gya(self) -> None:
        self.assertEqual(transcribe("ज्ञ", "sa").reading, "jña")
        self.assertEqual(transcribe("ज्ञ", "sa").ipa, "dʒɲə")

    def test_sibilants_and_retroflexes_are_kept_apart(self) -> None:
        self.assertEqual(transcribe("शषस", "sa").reading, "śaṣasa")
        self.assertEqual(transcribe("शषस", "sa").ipa, "ʃəʂəsə")
        self.assertEqual(transcribe("टठडढण", "sa").ipa, "ʈəʈʰəɖəɖʱəɳə")
        self.assertEqual(transcribe("तथदधन", "sa").ipa, "t̪ət̪ʰəd̪əd̪ʱənə")
        self.assertEqual(transcribe("वह", "sa").ipa, "ʋəɦə")

    def test_vocalic_letters_and_long_vowels_keep_their_marks(self) -> None:
        self.assertEqual(transcribe("ऋ ॠ ऌ ॡ", "sa").reading, "ṛ ṝ ḷ ḹ")
        self.assertEqual(transcribe("कृ कॄ कॢ कॣ", "sa").reading, "kṛ kṝ kḷ kḹ")
        self.assertEqual(transcribe("आ ई ऊ", "sa").reading, "ā ī ū")
        self.assertEqual(transcribe("आ ई ऊ", "sa").ipa, "aː iː uː")

    def test_e_o_ai_au(self) -> None:
        t = transcribe("के को कै कौ", "sa")
        self.assertEqual(t.reading, "ke ko kai kau")
        self.assertEqual(t.ipa, "keː koː kəi kəu")

    def test_anusvara_is_always_written_m_dot_and_said_as_the_next_nasal(
            self) -> None:
        for word, reading, ipa in (
            ("अंक", "aṃka", "əŋkə"),
            ("पंच", "paṃca", "pəɲtʃə"),
            ("कंठ", "kaṃṭha", "kəɳʈʰə"),
            ("अंत", "aṃta", "ənt̪ə"),
            ("कंप", "kaṃpa", "kəmpə"),
            ("पुस्तकं", "pustakaṃ", "pust̪əkəm"),
        ):
            with self.subTest(word):
                t = transcribe(word, "sa")
                self.assertEqual((t.reading, t.ipa), (reading, ipa))

    def test_anusvara_nasalises_the_vowel_before_semivowels_sibilants_h(
            self) -> None:
        self.assertEqual(transcribe("सिंह", "sa").ipa, "sĩɦə")
        self.assertEqual(transcribe("अंश", "sa").ipa, "ə\u0303ʃə")
        self.assertEqual(transcribe("संयोग", "sa").ipa, "sə\u0303joːɡə")
        self.assertEqual(transcribe("सांस", "sa").ipa, "sãːsə")

    def test_candrabindu_visarga_and_avagraha(self) -> None:
        t = transcribe("अँ", "sa")
        self.assertEqual((t.reading, t.ipa), ("am\u0310", "ə\u0303"))
        self.assertEqual(transcribe("कः", "sa").reading, "kaḥ")
        self.assertEqual(transcribe("कः", "sa").ipa, "kəh")
        self.assertEqual(transcribe("सोऽहम्", "sa").reading, "so'ham")

    def test_vedic_accent_marks_are_not_read(self) -> None:
        self.assertEqual(transcribe("अ॒ग्निम्", "sa").reading, "agnim")

    def test_words_punctuation_and_digits(self) -> None:
        t = transcribe("रामः गच्छति ।", "sa")
        self.assertEqual(t.reading, "rāmaḥ gacchati.")
        self.assertEqual(t.ipa, "raːməh ɡətʃtʃʰət̪i")
        self.assertEqual(transcribe("१२", "sa").reading, "12")

    def test_the_hint_is_ignored(self) -> None:
        self.assertEqual(transcribe("रामः", "sa", "ramah").reading, "rāmaḥ")

    def test_nukta_letters_and_latin_cannot_be_read(self) -> None:
        for bad in ("क़", "फ़", "ram"):
            with self.subTest(bad):
                with self.assertRaises(CannotRead):
                    transcribe(bad, "sa")


class VedicTest(unittest.TestCase):
    """Vedic Sanskrit (vsn): the same engine as sa, plus the accent marks,
    ळ and the Vedic diphthongs (wiki/Plan-Vedic-Engine.md)."""

    def test_accents_are_not_in_the_reading_or_ipa_but_are_reported(
            self) -> None:
        plain = transcribe("अग्निः", "vsn")
        for marked, name in (("अ॒ग्निः", "anudātta"), ("अ॑ग्निः", "svarita")):
            with self.subTest(marked):
                t = transcribe(marked, "vsn")
                self.assertEqual((t.reading, t.ipa), (plain.reading, plain.ipa))
                self.assertEqual(t.notes, [f"{name} on syllable 1"])
        # Written between the consonant and its sign, it is the same word.
        t = transcribe("अग्नि॑ः", "vsn")
        self.assertEqual(t.reading, "agniḥ")
        self.assertEqual(t.notes, ["svarita on syllable 2"])
        # A Vedic Extensions tone sign is an accent too.
        t = transcribe("अ\u1cda", "vsn")
        self.assertEqual(t.reading, "a")
        self.assertEqual(len(t.notes), 1)

    def test_the_acute_and_grave_accent_signs_are_not_vedic(self) -> None:
        for bad in ("अ\u0953", "अ\u0954"):
            with self.subTest(bad):
                with self.assertRaises(CannotRead):
                    transcribe(bad, "vsn")

    def test_no_inherent_a_is_dropped(self) -> None:
        t = transcribe("वदामि न", "vsn")
        self.assertEqual((t.reading, t.ipa), ("vadāmi na", "ʋəd̪aːmi nə"))

    def test_la_and_lha(self) -> None:
        t = transcribe("ईळे", "vsn")
        self.assertEqual((t.reading, t.ipa), ("īḷe", "iːɭeː"))
        t = transcribe("गाळ्ह", "vsn")
        self.assertEqual((t.reading, t.ipa), ("gāḷha", "ɡaːɭʱə"))
        with self.assertRaises(CannotRead):
            transcribe("ळ", "sa")

    def test_jihvamuliya_and_upadhmaniya(self) -> None:
        self.assertEqual(transcribe("\u1cf5क", "vsn").ipa, "xkə")
        self.assertEqual(transcribe("\u1cf6प", "vsn").ipa, "ɸpə")

    def test_vedic_ai_and_au_are_long_diphthongs_classical_ones_are_not(
            self) -> None:
        self.assertEqual(transcribe("दैव", "vsn").ipa, "d̪aːiʋə")
        self.assertEqual(transcribe("दैव", "sa").ipa, "d̪əiʋə")
        self.assertEqual(transcribe("गौः", "vsn").ipa, "ɡaːuh")

    def test_om_has_no_vedic_value_yet(self) -> None:
        with self.assertRaises(CannotRead):
            transcribe("ॐ", "vsn")

    def test_readings_and_ipa_pass_the_validators_letters(self) -> None:
        for word in ("ऋतम्", "पितॄणाम्", "ईळे", "गाळ्ह", "अहं जानामि",
                     "ज्ञानम्", "अग्निः", "सँस्कृतम्"):
            with self.subTest(word):
                t = transcribe(word, "vsn")
                self.assertTrue(validate_decks.IAST_ROMAN_RE.fullmatch(t.reading))
                self.assertTrue(validate_decks.IPA_RE.fullmatch(t.ipa))

    def test_a_vedic_tone_sign_does_not_cut_a_devanagari_run(self) -> None:
        # In an English layer, a word with a Vedic Extensions mark in it is
        # one script run, so one reading after it covers it.
        word = "अ\u1cdaग्नि"
        runs = [run for _, run in validate_decks._script_runs(f"{word} (agni)")]
        self.assertEqual(runs, [word])
        self.assertTrue(validate_decks._letters_in(
            word, validate_decks.SCRIPT_BLOCKS["devanagari"]))


class DeckModeTest(unittest.TestCase):
    def deck(self, text: str) -> Path:
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        path = Path(d.name) / "te-x.yaml"
        path.write_bytes(text.encode("utf-8"))
        return path

    def test_a_medial_anusvara_is_corrected_and_nothing_else_moves(
            self) -> None:
        path = self.deck(DECK)
        report = transcribe_decks.run(path.parent, "te")
        anus = [d for d in report.differences if d.anusvara]
        self.assertEqual([(d.entry, d.field, d.stored, d.computed)
                          for d in anus],
                         [("te-9001", "reading", "polamlō", "polaṁlō")])
        changed, refused = transcribe_decks.apply_fixes(report, False)
        self.assertEqual((changed, refused), (1, []))
        after = path.read_bytes().decode("utf-8")
        self.assertEqual(after, DECK.replace('"polamlō"', '"polaṁlō"'))

    def test_another_difference_is_reported_and_kept_without_all(
            self) -> None:
        path = self.deck(DECK)
        report = transcribe_decks.run(path.parent, "te")
        other = [d for d in report.differences if not d.anusvara]
        self.assertIn(("te-9002", "ipa"),
                      [(d.entry, d.field) for d in other])
        self.assertTrue(all(d.entry != "te-9001" for d in other))
        transcribe_decks.apply_fixes(report, False)
        self.assertIn('ipa: "t͡ɕeːnu"', path.read_bytes().decode("utf-8"))

    def test_all_fixes_the_other_differences_and_keeps_quoting(self) -> None:
        path = self.deck(DECK)
        report = transcribe_decks.run(path.parent, "te")
        transcribe_decks.apply_fixes(report, True)
        after = path.read_bytes().decode("utf-8")
        self.assertIn('ipa: "tʃeːnu"', after)
        self.assertIn("reading: 'cēnu'", after)
        self.assertIn('target: "పొలంలో"   # trailing comment', after)
        self.assertTrue(after.startswith("# a comment that must survive\n"))

    def test_check_exit_codes(self) -> None:
        path = self.deck(DECK.replace("'cēnu'", '"cēnu"'))
        self.assertEqual(transcribe_decks.main(
            ["x", "--check", str(path.parent), "te"]), 1)
        self.assertEqual(transcribe_decks.main(
            ["x", "--fix", "--all", str(path.parent), "te"]), 0)
        self.assertEqual(transcribe_decks.main(
            ["x", "--check", str(path.parent), "te"]), 0)

    def test_an_ambiguous_entry_is_reported_and_not_changed(self) -> None:
        path = self.deck(AMBIGUOUS)
        report = transcribe_decks.run(path.parent, "te")
        self.assertEqual(report.differences, [])
        self.assertEqual(len(report.unreadable), 3)
        changed, _ = transcribe_decks.apply_fixes(report, True)
        self.assertEqual(changed, 0)
        self.assertEqual(path.read_bytes().decode("utf-8"), AMBIGUOUS)


    def test_quoted_and_mixed_keys_and_flow_entries_are_read(self) -> None:
        quoted = ('"schema": 1\n"id": "te-q"\n"part": "core"\n"cards":\n'
                  '- id: "te-9201"\n  "target": "పొలంలో"\n'
                  '  "reading": "polamlō"\n  "ipa": "polamloː"\n'
                  '  "examples":\n'
                  '  - { "target": "పొలంలో", "reading": "polamlō" }\n'
                  '  - { "word": "పొలంలో", "reading": "polamlō" }\n'
                  '- id: "te-9202"\n  target: "పొలంలో"\n'
                  '  "reading": "polamlō"\n')
        path = self.deck(quoted)
        report = transcribe_decks.run(path.parent, "te")
        self.assertEqual(report.files, 1)
        self.assertEqual(sorted(d.entry.split("@")[0] for d in
                                report.differences),
                         ["te-9201", "te-9201/target:పొలంలో",
                          "te-9201/word:పొలంలో", "te-9202"])
        transcribe_decks.apply_fixes(report, False)
        self.assertEqual(path.read_bytes().decode("utf-8"),
                         quoted.replace("polamlō", "polaṁlō"))

    def test_crlf_and_a_trailing_comment_survive_byte_for_byte(self) -> None:
        text = DECK.replace("\n", "\r\n").replace(
            'reading: "polamlō"', 'reading: "polamlō"  # reading: "polamlō"')
        path = self.deck(text)
        report = transcribe_decks.run(path.parent, "te")
        transcribe_decks.apply_fixes(report, False)
        self.assertEqual(
            path.read_bytes().decode("utf-8"),
            text.replace('reading: "polamlō"  # reading: "polamlō"',
                         'reading: "polaṁlō"  # reading: "polamlō"'))

    def test_files_without_core_part_are_listed_as_skipped(self) -> None:
        path = self.deck(DECK.replace('part: "core"\n', ""))
        report = transcribe_decks.run(path.parent, "te")
        self.assertEqual(report.files, 0)
        self.assertEqual(report.skipped, ["te-x.yaml (no part key)"])

    def test_unreadable_entries_make_check_fail_and_are_not_changed(
            self) -> None:
        text = DECK.replace('target: "చేను"', "target: 'చేను'", 1)
        path = self.deck(text)
        self.assertTrue(any("target" in u for u in
                            transcribe_decks.run(path.parent, "te")
                            .unreadable))
        path = self.deck(AMBIGUOUS)
        self.assertEqual(transcribe_decks.main(
            ["x", "--check", str(path.parent), "te"]), 1)
        self.assertEqual(path.read_bytes().decode("utf-8"), AMBIGUOUS)

    def test_a_reading_before_its_target_is_reported(self) -> None:
        text = ('part: "core"\ncards:\n  - id: "te-9301"\n'
                '    reading: "polamlō"\n    target: "పొలంలో"\n')
        path = self.deck(text)
        report = transcribe_decks.run(path.parent, "te")
        self.assertTrue(any("before its target" in u
                            for u in report.unreadable))
        self.assertEqual(report.differences, [])

    def test_all_skips_suffixes_and_text_outside_the_script(self) -> None:
        text = ('part: "core"\nlanguage:\n  script: "telugu"\ncards:\n'
                '  - id: "te-9401"\n    target: "p"\n'
                '    reading: "x"\n    ipa: "y"\n'
                '  - id: "te-9402"\n    target: "-ిన"\n'
                '    reading: "x"\n')
        path = self.deck(text)
        report = transcribe_decks.run(path.parent, "te")
        self.assertTrue(report.differences)
        self.assertTrue(all(d.unsafe for d in report.differences))
        changed, _ = transcribe_decks.apply_fixes(report, True)
        self.assertEqual(changed, 0)
        self.assertEqual(path.read_bytes().decode("utf-8"), text)

    def test_a_bad_directory_exits_2_and_fix_prints_what_is_left(
            self) -> None:
        self.assertEqual(transcribe_decks.main(
            ["x", "--check", "/no/such/dir", "te"]), 2)
        path = self.deck(DECK)
        self.assertEqual(transcribe_decks.main(
            ["x", "--fix", str(path.parent), "te"]), 0)

PROP_CORE = """schema: 1
id: "te-p"
part: "core"
language:
  script: "telugu"
cards:
  - id: "te-9501"
    target: "పొలంలో"
    reading: "polamlō"
    ipa: "polamloː"
  - id: "te-9502"
    target: "పొలమ్లో"
    reading: "polamlō"
    ipa: "polamloː"
  - id: "te-9503"
    target: "ఇంకా"
    reading: "iṁka"
    ipa: "iŋkaː"
  - id: "te-9506"
    target: "ఇంకా"
    reading: "iṁkā"
    ipa: "iŋkaː"
  - id: "te-9504"
    target: "ఉందా?"
    reading: "uṇḍā?"
    ipa: "uɳɖaː"
  - id: "te-9505"
    target: "ఎస్‌ఎంఎస్"
    reading: "esemes"
    ipa: "esemes"
paradigm:
  readings: { "lo": "iṁkā", "ki": "iṁkāx" }
"""

PROP_EN = """"schema": 1
"id": "te-en-p"
"cards":
  "te-9503":
    "notes":
      "n1": "ఇంకా (iṁkā) means still. Also iṁkāx."
      "ipa": "iṁkā"
"""

PROP_NOPART = """id: "te-extra"
kind: "reading"
passages:
  - text: "ఇంకా (iṁkā, still)"
    "iṁkā": "key"
"""


CITE = """# kept
part: "core"
language: { code: "te", name: "Telugu", script: "telugu" }
cards:
  - id: "te-9601"
    target: "అందమైన ఉన్నాయి"
    reading: "andamaina unnāyi"
    ipa: "and̪amaina unnaːji"
    bases:
    - "word": "అందమైన"
      "base": "అందం"
      "reading": "andam"
    - "word": "ఉన్నాయి"
      "base": "ఉండడం"
      "reading": "uṇḍaḍaṁ"
  - id: "te-9602"
    target: "పొలంలో"
    reading: "polamlō"
    ipa: "polamloː"
    bases:
      - { word: "ఖండంలో", base: "ఖండం", reading: "khaṇḍam" }
      - { word: "ఇల్లు", base: "ఇల్లు", reading: "illu" }
      - { word: "పేరు", ref: "te-0001", reading: "pēru" }
      - { word: "ఇంటిలో", base: "ఇల్లు", reading: "illam" }
"""


class CitationTest(unittest.TestCase):
    def deck(self) -> Path:
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        path = Path(d.name) / "te-c.yaml"
        path.write_bytes(CITE.encode("utf-8"))
        return path

    def test_final_m_of_a_base_reading_becomes_anusvara_in_both_forms(
            self) -> None:
        path = self.deck()
        report = transcribe_decks.run(path.parent, "te", True)
        self.assertEqual(
            sorted((d.stored, d.computed) for d in report.differences),
            [("andam", "andaṁ"), ("khaṇḍam", "khaṇḍaṁ")])
        changed, refused = transcribe_decks.apply_fixes(report, False)
        self.assertEqual((changed, refused), (2, []))
        after = path.read_bytes().decode("utf-8")
        expected = (CITE.replace('"reading": "andam"', '"reading": "andaṁ"')
                    .replace('reading: "khaṇḍam"', 'reading: "khaṇḍaṁ"'))
        self.assertEqual(after, expected)

    def test_cards_examples_and_other_base_differences_are_not_touched(
            self) -> None:
        path = self.deck()
        report = transcribe_decks.run(path.parent, "te", True)
        transcribe_decks.apply_fixes(report, False)
        after = path.read_bytes().decode("utf-8")
        self.assertIn('reading: "polamlō"', after)  # a card: other mode
        self.assertIn('reading: "illam"', after)    # not a final-m case

    def test_without_the_flag_base_readings_are_not_read(self) -> None:
        path = self.deck()
        report = transcribe_decks.run(path.parent, "te")
        self.assertTrue(all(d.stored != "andam" for d in report.differences))

    def test_second_run_is_clean_and_cli_codes(self) -> None:
        path = self.deck()
        d = str(path.parent)
        self.assertEqual(transcribe_decks.main(
            ["x", "--check", "--citations", d, "te"]), 1)
        self.assertEqual(transcribe_decks.main(
            ["x", "--fix", "--citations", d, "te"]), 0)
        self.assertEqual(transcribe_decks.main(
            ["x", "--check", "--citations", d, "te"]), 0)
        self.assertEqual(transcribe_decks.main(
            ["x", "--fix", "--citations", "--all", d, "te"]), 2)


LAYER_EN = """# kept
part: "en"
cards:
  - id: "te-9701"
    note: "Telugu says అందం (andam) and చేయడం (cēyaḍam, to do), also ఒకే పుస్తకం (oke pustakam)."
    ipa: "అందం (andam)"
  - id: "te-9702"
    note: "మేడమ్ (mēḍam) keeps m, ఇల్లు (illu) has none, ఇంటికి (inṭiki), and రావడం (rāvaḍaṁ) is done; ఖండం (khandam) differs."
  - { id: "te-9703", note: "ఇది నా పుస్తకం (pustakam)" }
"""


class LayerAnusvaraTest(unittest.TestCase):
    def tree(self, crlf: bool = False) -> Path:
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        root = Path(d.name) / "te"
        (root / "en").mkdir(parents=True)
        text = LAYER_EN.replace("\n", "\r\n") if crlf else LAYER_EN
        (root / "en" / "te-en-l.yaml").write_bytes(text.encode("utf-8"))
        return root

    def test_only_the_final_m_of_a_matching_reading_changes(self) -> None:
        root = self.tree()
        rows = transcribe_decks.layer_anusvara(root, "te", True)
        self.assertEqual([r[3] for r in rows],
                         ["andam", "cēyaḍam", "pustakam"])
        after = (root / "en" / "te-en-l.yaml").read_bytes().decode("utf-8")
        expected = (LAYER_EN.replace("(andam) and", "(andaṁ) and")
                    .replace("(cēyaḍam, to do)", "(cēyaḍaṁ, to do)")
                    .replace("(pustakam)", "(pustakaṁ)"))
        self.assertEqual(after, expected)

    def test_multi_word_reading_and_others_stay(self) -> None:
        root = self.tree()
        transcribe_decks.layer_anusvara(root, "te", True)
        after = (root / "en" / "te-en-l.yaml").read_bytes().decode("utf-8")
        self.assertIn("(oke pustakam)", after)   # okē, not oke: differs
        self.assertIn("(mēḍam)", after)           # the rules keep m
        self.assertIn('ipa: "అందం (andam)"', after)  # ipa never read
        self.assertIn("(khandam)", after)

    def test_check_does_not_write_and_crlf_is_kept(self) -> None:
        root = self.tree(crlf=True)
        path = root / "en" / "te-en-l.yaml"
        before = path.read_bytes()
        d = str(root)
        self.assertEqual(transcribe_decks.main(
            ["x", "--check", "--layer-anusvara", d, "te"]), 1)
        self.assertEqual(path.read_bytes(), before)
        self.assertEqual(transcribe_decks.main(
            ["x", "--fix", "--layer-anusvara", d, "te"]), 0)
        after = path.read_bytes()
        self.assertEqual(after.count(b"\r\n"), before.count(b"\r\n"))
        self.assertEqual(transcribe_decks.main(
            ["x", "--check", "--layer-anusvara", d, "te"]), 0)

    def test_refused_with_the_other_passes(self) -> None:
        d = str(self.tree())
        for other in ("--all", "--propagate", "--citations"):
            self.assertEqual(transcribe_decks.main(
                ["x", "--fix", "--layer-anusvara", other, d, "te"]), 2)


class PropagateTest(unittest.TestCase):
    def tree(self, crlf: bool = False) -> Path:
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        root = Path(d.name) / "te"
        (root / "en").mkdir(parents=True)
        files = {root / "te-p.yaml": PROP_CORE,
                 root / "en" / "te-en-p.yaml": PROP_EN,
                 root / "te-extra.yaml": PROP_NOPART}
        for path, text in files.items():
            path.write_bytes((text.replace("\n", "\r\n") if crlf
                              else text).encode("utf-8"))
        return root

    def read(self, path: Path) -> str:
        return path.read_bytes().decode("utf-8")

    def test_partial_entries_get_their_nasal_fixed_and_the_rest_kept(
            self) -> None:
        root = self.tree()
        report = transcribe_decks.run(root, "te")
        part = [d for d in report.differences if d.partial]
        self.assertEqual([(d.entry, d.field, d.computed) for d in part],
                         [("te-9503", "reading", "iṅka")])
        transcribe_decks.apply_fixes(report, False)
        after = self.read(root / "te-p.yaml")
        self.assertIn('reading: "iṅka"', after)       # the short a stays
        self.assertIn('reading: "undā?"', after)      # ంద: dental n
        self.assertIn('ipa: "und̪aː"', after)
        self.assertIn('reading: "esemes"', after)     # before a vowel: m
        self.assertEqual(after.count('reading: "polamlō"'), 1)

    def test_check_propagate_lists_without_writing(self) -> None:
        root = self.tree()
        before = {p: self.read(p) for p in root.rglob("*.yaml")}
        report = transcribe_decks.run(root, "te")
        mapping, ambiguous = transcribe_decks.token_map(report, False)
        self.assertEqual(mapping["iṁkā"], "iṅkā")
        per_file, _ = transcribe_decks.propagate(root, mapping, ambiguous,
                                                 False)
        self.assertEqual(len(per_file), 3)
        self.assertEqual({p: self.read(p) for p in root.rglob("*.yaml")},
                         before)

    def test_homograph_is_ambiguous_and_left_alone(self) -> None:
        root = self.tree()
        # polamlō is a wrong reading of పొలంలో and the right one of పొలమ్లో.
        report = transcribe_decks.run(root, "te")
        mapping, ambiguous = transcribe_decks.token_map(report, False)
        self.assertNotIn("polamlō", mapping)
        self.assertIn("polamlō", ambiguous)

    def test_propagation_rewrites_other_places_and_keeps_ipa_and_keys(
            self) -> None:
        root = self.tree()
        report = transcribe_decks.run(root, "te")
        mapping, ambiguous = transcribe_decks.token_map(report, False)
        transcribe_decks.apply_fixes(report, False)
        transcribe_decks.propagate(root, mapping, ambiguous, True)
        self.assertIn('readings: { "lo": "iṅkā", "ki": "iṁkāx" }',
                      self.read(root / "te-p.yaml"))
        en = self.read(root / "en" / "te-en-p.yaml")
        self.assertIn("ఇంకా (iṅkā) means still. Also iṁkāx.", en)
        self.assertIn('"ipa": "iṁkā"', en)             # an ipa value
        extra = self.read(root / "te-extra.yaml")
        self.assertIn("ఇంకా (iṅkā, still)", extra)    # a file with no part
        self.assertIn('"iṁkā": "key"', extra)          # a key is not text

    def test_propagation_keeps_crlf_byte_for_byte(self) -> None:
        root = self.tree(crlf=True)
        report = transcribe_decks.run(root, "te")
        mapping, ambiguous = transcribe_decks.token_map(report, False)
        transcribe_decks.apply_fixes(report, False)
        transcribe_decks.propagate(root, mapping, ambiguous, True)
        self.assertEqual(
            self.read(root / "en" / "te-en-p.yaml"),
            PROP_EN.replace("\n", "\r\n").replace("(iṁkā)", "(iṅkā)"))

    def test_main_check_and_fix_with_propagate(self) -> None:
        root = self.tree()
        self.assertEqual(transcribe_decks.main(
            ["x", "--check", "--propagate", str(root), "te"]), 1)
        transcribe_decks.main(["x", "--fix", "--propagate", str(root), "te"])
        report = transcribe_decks.run(root, "te")
        self.assertEqual([d for d in report.differences if d.anusvara], [])


class PropagateSafetyTest(unittest.TestCase):
    tree = PropagateTest.tree
    read = PropagateTest.read

    def test_short_words_in_prose_and_comments_and_ipa_stay(self) -> None:
        root = self.tree()
        text = (
            '"n1": "The 15th-century won\'t c. 1620 say iṁkā."\n'
            '"n2": "iṁkā"  # iṁkā here, t and c too\n'
            '"consonants": ["ŋ", "ɲ", "ɳ"]\n'
            '"row": "iṁkā ŋa th"\n'
            '"ipas": ["iṁkā"]\n')
        path = root / "te-romanisation.yaml"
        path.write_bytes(text.encode("utf-8"))
        mapping = {"t": "t̪", "th": "t̪ʰ", "c": "tʃ", "won": "wän",
                   "iṁkā": "iṅkā"}
        transcribe_decks.propagate(root, mapping, {}, True)
        self.assertEqual(
            path.read_bytes().decode("utf-8"),
            text.replace("say iṁkā", "say iṅkā").replace(
                '"n2": "iṁkā"', '"n2": "iṅkā"'))

    def test_all_with_propagate_is_refused(self) -> None:
        root = self.tree()
        before = {p: self.read(p) for p in root.rglob("*.yaml")}
        self.assertEqual(transcribe_decks.main(
            ["x", "--fix", "--all", "--propagate", str(root), "te"]), 2)
        self.assertEqual({p: self.read(p) for p in root.rglob("*.yaml")},
                         before)

    def test_a_second_fix_propagate_changes_nothing(self) -> None:
        root = self.tree()
        transcribe_decks.main(["x", "--fix", "--propagate", str(root), "te"])
        once = {p: self.read(p) for p in root.rglob("*.yaml")}
        transcribe_decks.main(["x", "--fix", "--propagate", str(root), "te"])
        self.assertEqual({p: self.read(p) for p in root.rglob("*.yaml")},
                         once)

    def test_short_old_words_are_never_in_the_map(self) -> None:
        self.assertFalse(transcribe_decks._eligible("c", "tʃ"))
        self.assertFalse(transcribe_decks._eligible("th", "t̪ʰ"))
        self.assertFalse(transcribe_decks._eligible("amma", "amm"))
        self.assertTrue(transcribe_decks._eligible("iṁkā", "iṅkā"))

    def test_only_an_anusvara_nasal_is_rewritten(self) -> None:
        # న్ద computes nd, but its nasal is a consonant: not changed.
        self.assertIsNone(transcribe_decks._nasal_only(
            "reading", "iṁkā aṇḍā", "iṅkā andā", "ఇంకా అన్దా"))
        # A wrong ṇ for న next to a real anusvara is not rewritten.
        self.assertIsNone(transcribe_decks._nasal_only(
            "reading", "iṅkā paṁkā aṇnā", "iṅkā paṅkā annā",
            "ఇంకా పంకా అన్నా"))
        # The anusvara of ఇంకా is.
        self.assertEqual(transcribe_decks._nasal_only(
            "reading", "iṁka", "iṅkā", "ఇంకా"), "iṅka")


class GujaratiHintTest(unittest.TestCase):
    """A stored reading is passed as the hint (transcribe_decks), so a hint
    in the course's own ISO letters must fit and be followed."""

    def test_gujarati_long_vowels_are_written_short_as_the_course_does(self) -> None:
        # gu-romanisation.yaml: i and u for both the short and the long vowel.
        for word, reading in (("ઠીક", "ṭhik"), ("હિન્દી", "hindi"),
                              ("સૂવું", "suvum̐")):
            with self.subTest(word):
                self.assertEqual(transcribe(word, "gu").reading, reading)

    def test_a_hint_that_writes_the_long_vowel_fits_and_reads_short(self) -> None:
        for word, hint, reading in (("ઠીક", "ṭhīk", "ṭhik"),
                                    ("હિન્દી", "hindī", "hindi"),
                                    ("ગુજરાતી", "gujarātī", "gujarāti")):
            with self.subTest(word):
                t = transcribe(word, "gu", hint)
                self.assertTrue(t.fitted)
                self.assertEqual(t.reading, reading)

    def test_a_hint_in_iso_letters_is_followed_not_dropped(self) -> None:
        # Without the hint the medial a is dropped (śrimti); the hint keeps it.
        self.assertEqual(transcribe("શ્રીમતી", "gu").reading, "śrimti")
        t = transcribe("શ્રીમતી", "gu", "śrimati")
        self.assertTrue(t.fitted)
        self.assertEqual((t.reading, t.ipa), ("śrimati", "ʃrimət̪i"))
        t = transcribe("ઝડપથી", "gu", "jhaḍapthi")
        self.assertTrue(t.fitted)
        self.assertEqual(t.reading, "jhaḍapthi")

    def test_a_hint_keeps_the_nasal_mark_m_candrabindu(self) -> None:
        t = transcribe("ઓગણીસ", "gu", "ogaṇis")
        self.assertEqual(t.reading, "ogaṇis")
        self.assertEqual(transcribe("કયું", "gu", "kayum̐").reading, "kayum̐")


class RussianTest(unittest.TestCase):
    """Russian (ru), broad. The forms of рассказ, нож, ложка, солнце and
    жена are those that en.wikipedia.org's "Russian phonology" gives (read
    2026-11-28), written in this engine's symbols (ɐ for ʌ, ˈ before the
    syllable, ɡ); the rest, счастье included, are the engine's own rules,
    which follow that page and Wiktionary's "Appendix:Russian pronunciation"
    where they state them, and are checked by hand, not against single
    entries."""

    def check(self, triples):
        for text, hint, ipa in triples:
            with self.subTest(text=text):
                self.assertEqual(russian_ipa(text, hint), ipa)

    def test_unstressed_o_and_a_reduce_by_place(self):
        self.check((("молоко", "молоко́", "məlɐˈko"),
                    ("голова", "голова́", "ɡəlɐˈva"),
                    ("вода", "вода́", "vɐˈda"),
                    ("хорошо", "хорошо́", "xərɐˈʂo"),
                    ("мама", "ма́ма", "ˈmamə"),
                    ("город", "го́род", "ˈɡorət")))

    def test_e_ya_and_i_reduce_to_ɪ_and_ж_ш_ц_make_ɨ(self):
        self.check((("язык", "язы́к", "jɪˈzɨk"),
                    ("жена", "жена́", "ʐɨˈna"),
                    ("цена", "цена́", "tsɨˈna"),
                    ("меня", "меня́", "mʲɪˈnʲa"),
                    ("ночи", "но́чи", "ˈnotɕɪ")))

    def test_a_consonant_is_soft_before_a_front_vowel_or_a_soft_sign(self):
        self.check((("привет", "приве́т", "prʲɪˈvʲet"),
                    ("мать", None, "matʲ"),
                    ("семья", "семья́", "sʲɪˈmʲja"),
                    ("школа", "шко́ла", "ˈʂkolə"),
                    ("шесть", None, "ʂɛstʲ"),
                    ("большое", "большо́е", "bɐlʲˈʂojə")))

    def test_final_devoicing_and_voicing_assimilation(self):
        self.check((("друг", None, "druk"), ("нож", None, "noʂ"),
                    ("хлеб", None, "xlʲep"), ("ложка", "ло́жка", "ˈloʂkə"),
                    ("всё", None, "fsʲo"),
                    ("мягкий", "мя́гкий", "ˈmʲaxkʲɪj"),
                    ("легко", "легко́", "lʲɪxˈko"),
                    ("здравствуйте", "здра́вствуйте", "ˈzdrastvʊjtʲɪ")))

    def test_silent_letters_and_changed_consonants(self):
        self.check((("солнце", "со́лнце", "ˈsontsə"),
                    ("сердце", "се́рдце", "ˈsʲertsə"),
                    ("чувство", "чу́вство", "ˈtɕustvə"),
                    ("лестный", "ле́стный", "ˈlʲesnɨj"),
                    ("счастье", "сча́стье", "ˈɕːastʲjɪ"),
                    ("рассказ", "расска́з", "rɐˈskas"),
                    ("что", None, "ʂto"),
                    ("учиться", "учи́ться", "ʊˈtɕitsə")))

    def test_г_is_v_in_ого_and_его(self):
        self.check((("того", "того́", "tɐˈvo"), ("его", "его́", "jɪˈvo"),
                    ("большого", "большо́го", "bɐlʲˈʂovə"),
                    ("много", "мно́го", "ˈmnoɡə")))

    def test_a_doubled_consonant_is_long_only_before_a_vowel(self):
        self.check((("Анна", "А́нна", "ˈanːə"),
                    ("русском", "ру́сском", "ˈruskəm")))

    def test_stress_from_an_acute_in_the_text_beats_the_hint(self):
        self.assertEqual(russian_ipa("приве́т"), "prʲɪˈvʲet")
        self.assertEqual(russian_ipa("приве́т", "при́вет"), "prʲɪˈvʲet")
        self.assertEqual(russian_ipa("ёж"), "joʂ")
        self.assertEqual(russian_ipa("неё"), "nʲɪˈjo")

    def test_a_hint_is_used_only_if_it_is_the_text(self):
        self.assertEqual(russian_ipa("привет", "приве́т"), "prʲɪˈvʲet")
        self.assertEqual(russian_ipa("привет", "пока́"),
                         russian_ipa("привет"))
        self.assertTrue(transcribe("привет", "ru", "приве́т").fitted)
        self.assertFalse(transcribe("привет", "ru", "пока́").fitted)

    def test_a_word_of_one_vowel_needs_no_mark_and_a_guess_is_named(self):
        self.assertEqual(russian_ipa("да"), "da")
        t = transcribe("привет", "ru")
        self.assertEqual(t.ipa, "ˈprʲivʲɪt")
        self.assertEqual(len(t.notes), 1)
        self.assertIn("guessed", t.notes[0])
        self.assertEqual(transcribe("привет", "ru", "приве́т").notes, [])

    def test_a_one_syllable_preposition_is_unstressed_in_a_phrase(self):
        self.assertEqual(russian_ipa("на столе", "на столе́"),
                         "nə stɐˈlʲe")
        self.assertEqual(russian_ipa("не", None), "nʲe")
        self.assertEqual(russian_ipa("я не знаю", "я не зна́ю"),
                         "ja nʲɪ ˈznajʊ")

    def test_the_reading_is_the_decks_transliteration(self):
        # Every reading below is one that a card of decks/ru already has.
        for text, reading in (
                ("привет", "privet"), ("здравствуйте", "zdravstvuyte"),
                ("доброе утро", "dobroye utro"),
                ("спокойной ночи", "spokoynoy nochi"),
                ("до свидания", "do svidaniya"),
                ("пожалуйста", "pozhaluysta"),
                ("большое спасибо", "bolshoye spasibo"),
                ("я не понимаю", "ya ne ponimayu"),
                ("я не говорю на русском", "ya ne govoryu na russkom"),
                ("говорите медленнее, пожалуйста",
                 "govorite medlennee, pozhaluysta"),
                ("сколько стоит?", "skolko stoit?"),
                ("где туалет?", "gde tualet?"),
                ("помогите!", "pomogite!"),
                ("меня зовут Анна", "menya zovut Anna"),
                ("очень приятно", "ochen' priyatno"),
                ("хорошо", "khorosho"), ("вы", "vy"), ("или", "ili"),
                ("добрый", "dobry"), ("ночь", "noch'"),
                ("щи", "shchi"), ("ёж", "yozh"), ("семья", "sem'ya")):
            with self.subTest(text=text):
                self.assertEqual(transcribe(text, "ru").reading, reading)

    def test_the_stress_mark_is_not_written_in_the_reading(self):
        self.assertEqual(transcribe("приве́т", "ru").reading, "privet")

    def test_a_letter_russian_does_not_use_is_refused(self):
        for bad in ("hello", "привет1", "іa"):
            with self.subTest(bad=bad), self.assertRaises(CannotRead):
                russian_ipa(bad)

class GreekTest(unittest.TestCase):
    """Modern Greek (el), broad. The expected forms are the engine's own
    rules (see the section header in transcribe.py), checked by hand against
    the hand-written cards of decks/el and Wiktionary's "Appendix:Greek
    pronunciation", not against single entries."""

    def check(self, pairs):
        for text, ipa in pairs:
            with self.subTest(text=text):
                self.assertEqual(greek_ipa(text), ipa)

    def test_the_stress_is_the_written_tonos(self):
        self.check((("ευχαριστώ", "efxaɾiˈsto"), ("όχι", "ˈoxi"),
                    ("εγώ", "eˈɣo"), ("καλημέρα", "kaliˈmeɾa"),
                    ("καταλαβαίνω", "katalaˈveno")))

    def test_a_word_of_one_syllable_is_unstressed(self):
        self.check((("ναι", "ne"), ("δεν", "ðen"), ("που", "pu"),
                    ("πού", "pu"), ("μου", "mu")))

    def test_vowel_letters_and_digraphs(self):
        self.check((("ήλιος", "ˈiljos"), ("ώμος", "ˈomos"), ("πυρ", "piɾ"),
                    ("είναι", "ˈine"), ("οι", "i"), ("ουρά", "uˈɾa"),
                    ("παιδί", "peˈði")))

    def test_ai_and_ei_are_one_vowel_unless_the_tonos_or_a_diaeresis_parts_them(self):
        self.check((("μάιος", "ˈmaios"), ("ρολόι", "ɾoˈloi"),
                    ("παϊδάκια", "paiˈðakja")))

    def test_av_ev_are_voiced_before_a_vowel_or_a_voiced_consonant(self):
        self.check((("αυτό", "afˈto"), ("ευχαριστώ", "efxaɾiˈsto"),
                    ("ευγενικός", "evʝeniˈkos"), ("αύριο", "ˈavɾjo"),
                    ("ευρώ", "eˈvɾo")))

    def test_gamma_is_palatal_before_a_front_vowel(self):
        self.check((("γεια", "ʝa"), ("για", "ʝa"), ("γιατί", "ʝaˈti"),
                    ("γη", "ʝi"), ("γάλα", "ˈɣala"), ("γκρι", "ɡɾi"),
                    ("εγώ", "eˈɣo")))

    def test_nasal_and_stop_groups(self):
        self.check((("μπαμπάς", "bamˈbas"), ("έμπορος", "ˈemboɾos"),
                    ("ντομάτα", "doˈmata"), ("αντίο", "anˈdio"),
                    ("άγγελος", "ˈaŋɡelos"), ("αγγλικά", "aŋɡliˈka"),
                    ("συγγνώμη", "siŋˈɣnomi"), ("εγκατάσταση", "eŋɡaˈtastasi"),
                    ("συγχωρώ", "siŋxoˈɾo")))

    def test_ts_tz_and_the_double_letters(self):
        self.check((("κάτσε", "ˈkatse"), ("τζάμι", "ˈdzami"),
                    ("ελληνικά", "eliniˈka"), ("Άννα", "ˈana"),
                    ("ξέρω", "ˈkseɾo"), ("ψάρι", "ˈpsaɾi")))

    def test_sigma_is_z_before_a_voiced_consonant_inside_a_word(self):
        self.check((("σημαίνει", "siˈmeni"), ("άσμα", "ˈazma"),
                    ("λογαριασμός", "loɣaɾjazˈmos"),
                    ("στάση", "ˈstasi"), ("Ισλανδία", "izlanˈðia")))

    def test_an_unstressed_i_before_a_vowel_is_the_glide_j(self):
        self.check((("μια", "mja"), ("πιο", "pjo"), ("βοήθεια", "voˈiθja"),
                    ("ιατρός", "jaˈtɾos"), ("ιδιαίτερα", "iˈðjeteɾa"),
                    ("κρύο", "ˈkɾio")))

    def test_a_cluster_is_split_at_the_longest_onset(self):
        self.check((("ταξίδι", "taˈksiði"), ("σταθμός", "staθˈmos"),
                    ("αργά", "aɾˈɣa"), ("εντάξει", "enˈdaksi"),
                    ("κουρασμένος", "kuɾazˈmenos")))

    def test_a_phrase_stresses_each_polysyllable(self):
        self.check((("Δεν καταλαβαίνω.", "ðen katalaˈveno"),
                    ("Ευχαριστώ πολύ.", "efxaɾiˈsto poˈli"),
                    ("Γεια σου, τι κάνεις;", "ʝa su ti ˈkanis"),
                    ("Καλή όρεξη!", "kaˈli ˈoɾeksi")))

    def test_capitals_and_a_final_sigma_are_read_as_lower_case(self):
        self.check((("ΕΛΛΆΔΑ", "eˈlaða"), ("Ελλάδα", "eˈlaða"),
                    ("καλός", "kaˈlos")))

    def test_a_polysyllable_without_a_tonos_is_refused_not_guessed(self):
        for bad in ("ευχαριστω", "ελλαδα", "καλημερα"):
            with self.subTest(bad=bad), self.assertRaises(CannotRead):
                greek_ipa(bad)

    def test_two_tonos_marks_are_refused(self):
        with self.assertRaises(CannotRead):
            greek_ipa("άνθρωπός")

    def test_a_letter_greek_does_not_use_is_refused(self):
        for bad in ("hello", "καλά1", "привет", "ἀγαθός"):
            with self.subTest(bad=bad), self.assertRaises(CannotRead):
                greek_ipa(bad)

    def test_the_el_dispatch_echoes_the_stored_reading(self):
        t = transcribe("ευχαριστώ", "el", "efcharistó")
        self.assertEqual((t.reading, t.ipa, t.fitted, t.notes),
                         ("efcharistó", "efxaɾiˈsto", True, []))
        self.assertEqual(transcribe("ναι", "el").ipa, "ne")


class PolishTest(unittest.TestCase):
    """Polish (pl), broad. The expected forms are the engine's own rules (see
    the section header in transcribe.py), checked by hand against the
    hand-written cards of decks/pl and Wikipedia's "Polish phonology", not
    against single entries."""

    def check(self, pairs):
        for text, ipa in pairs:
            with self.subTest(text=text):
                self.assertEqual(polish_ipa(text), ipa)

    def test_stress_is_penultimate_and_one_syllable_is_unmarked(self):
        self.check((("woda", "ˈvɔda"), ("dobry", "ˈdɔbrɨ"),
                    ("dobranoc", "dɔˈbranɔts"), ("tak", "tak"),
                    ("nie", "ɲɛ"), ("jest", "jɛst")))

    def test_the_digraphs_and_the_acute_letters(self):
        self.check((("szafa", "ˈʂafa"), ("czas", "tʂas"),
                    ("chleb", "xlɛp"), ("dżem", "dʐɛm"),
                    ("cześć", "tʂɛɕtɕ"), ("łódź", "wutɕ"),
                    ("źle", "ʑlɛ"), ("kość", "kɔɕtɕ")))

    def test_i_before_a_vowel_softens_and_makes_no_syllable(self):
        self.check((("ciało", "ˈtɕawɔ"), ("dzień", "dʑɛɲ"),
                    ("siostra", "ˈɕɔstra"), ("zielony", "ʑɛˈlɔnɨ"),
                    ("rozumiem", "rɔˈzumjɛm"),
                    ("angielski", "aŋˈɡʲɛlskʲi")))

    def test_i_before_a_consonant_is_a_vowel(self):
        self.check((("ci", "tɕi"), ("zima", "ˈʑima"), ("mi", "mʲi"),
                    ("niski", "ˈɲiskʲi"), ("ich", "ix")))

    def test_the_nasal_vowels_are_written_by_what_follows(self):
        self.check((("dziękuję", "dʑɛŋˈkujɛ"), ("wodę", "ˈvɔdɛ"),
                    ("ząb", "zɔmp"), ("tęcza", "ˈtɛntʂa"),
                    ("więc", "vjɛnts"), ("pięć", "pjɛɲtɕ"),
                    ("wąs", "vɔ̃s"), ("mąż", "mɔ̃ʂ"),
                    ("wzięli", "ˈvʑɛli"), ("są", "sɔ̃")))

    def test_o_acute_is_u_y_is_ɨ_and_l_stroke_is_w(self):
        self.check((("mówić", "ˈmuvʲitɕ"), ("ty", "tɨ"), ("było", "ˈbɨwɔ"),
                    ("góra", "ˈɡura")))

    def test_final_devoicing_and_voicing_assimilation(self):
        self.check((("zęb", "zɛmp"), ("prawda", "ˈpravda"),
                    ("łódka", "ˈwutka"), ("liczba", "ˈlidʐba"),
                    ("zdrowy", "ˈzdrɔvɨ"), ("mów", "muf")))

    def test_w_and_rz_are_voiceless_after_a_voiceless_consonant(self):
        self.check((("przepraszam", "pʂɛˈpraʂam"), ("trzy", "tʂɨ"),
                    ("dobrze", "ˈdɔbʐɛ"), ("kwiat", "kfjat"),
                    ("swój", "sfuj"), ("wstać", "fstatɕ")))

    def test_the_mark_goes_before_the_longest_onset_that_can_begin_a_word(self):
        self.check((("kosztuje", "kɔʂˈtujɛ"), ("poproszę", "pɔˈprɔʂɛ"),
                    ("smaczne", "ˈsmatʂnɛ"), ("smacznego", "smatʂˈnɛɡɔ"),
                    ("zmęczony", "zmɛnˈtʂɔnɨ"), ("toaleta", "tɔaˈlɛta")))

    def test_a_vowelless_word_joins_the_next_one(self):
        self.check((("w porządku", "f pɔˈʐɔntku"),
                    ("z Polski", "s ˈpɔlskʲi"), ("w domu", "v ˈdɔmu")))

    def test_an_affricate_before_one_of_the_same_place_is_one_sound(self):
        self.check((("pięćdziesiąt", "pjɛɲˈdʑɛɕɔnt"),
                    ("dziewięćdziesiąt", "dʑɛvjɛɲˈdʑɛɕɔnt"),
                    ("sześćdziesiąt", "ʂɛʑˈdʑɛɕɔnt"),
                    ("pięćset", "ˈpjɛɲtsɛt")))

    def test_a_phrase_stresses_each_polysyllable(self):
        self.check((("Dzień dobry.", "dʑɛɲ ˈdɔbrɨ"),
                    ("Nie rozumiem.", "ɲɛ rɔˈzumjɛm"),
                    ("Ile to kosztuje?", "ˈilɛ tɔ kɔʂˈtujɛ"),
                    ("Gdzie jest dworzec?", "ɡdʑɛ jɛst ˈdvɔʐɛts")))

    def test_an_acute_in_the_text_or_a_hint_moves_the_stress(self):
        self.assertEqual(polish_ipa("muzyka"), "muˈzɨka")
        self.assertEqual(polish_ipa("mu\u0301zyka"), "ˈmuzɨka")
        self.assertEqual(polish_ipa("múzyka"), "ˈmuzɨka")
        self.assertEqual(polish_ipa("muzyka", "mu\u0301zyka"), "ˈmuzɨka")
        self.assertEqual(polish_ipa("muzyka", "muzy\u0301ka"), "muˈzɨka")
        self.assertEqual(polish_ipa("mu\u0301zyka", "muzy\u0301ka"),
                         "ˈmuzɨka")

    def test_a_hint_is_used_only_if_it_is_the_text(self):
        self.assertEqual(polish_ipa("muzyka", "pomo\u0301c"),
                         polish_ipa("muzyka"))
        self.assertTrue(transcribe("muzyka", "pl", "mu\u0301zyka").fitted)
        self.assertFalse(transcribe("muzyka", "pl", "pomo\u0301c").fitted)

    def test_the_pl_dispatch_keeps_the_text_as_its_reading(self):
        t = transcribe("Dzień dobry.", "pl")
        self.assertEqual((t.reading, t.ipa, t.fitted, t.notes),
                         ("Dzień dobry.", "dʑɛɲ ˈdɔbrɨ", True, []))

    def test_a_letter_polish_does_not_use_is_refused(self):
        for bad in ("quiz", "xylofon", "привет", "dobry1", "señor"):
            with self.subTest(bad=bad), self.assertRaises(CannotRead):
                polish_ipa(bad)


if __name__ == "__main__":
    unittest.main()
