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

    def test_toki_pona_words_next_to_punctuation_are_kept(self) -> None:
        self.assertEqual(transcribe("toki pona! sina pilin seme?", "tok").ipa,
                         "ˈtoki ˈpona ˈsina ˈpilin ˈseme")
        self.assertEqual(transcribe("\"mi moku\": o kama.", "tok").ipa,
                         "mi ˈmoku o ˈkama")


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


if __name__ == "__main__":
    unittest.main()
