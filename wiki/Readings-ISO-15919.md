# Readings and ISO 15919

Source of truth: this wiki page.

## How words are written in Latin letters: ISO 15919


Every word in an Indian language has a reading, its Latin letters, shown on the
card. The readings are **based on the letters of ISO 15919**, the international
standard for writing Indian scripts in Latin letters, and they **depart from it
wherever a learner is better served**
([ADR-0025](ADR-0025-Iso-15919-And-Ipa)). They are not a strict
ISO 15919 transliteration: the [list of departures](#where-the-readings-depart-from-iso-15919)
follows the table of letters.

ISO 15919 was chosen because its marks show what plain letters cannot: పాలు,
milk, is **pālu** and పలు, many, is **palu**; పాట, song, is **pāṭa** and పాత,
old, is **pāta**. One standard covers all the Indian scripts, so a learner of
a second Indian language meets the same letters again.

ISO 15919 writes letters, so कितना is *kitanā* letter for letter. The decks
write each word **as it is said**, in ISO 15919's letters: *kitnā*, without the
a that Hindi does not say. Where a language says two letters alike, the reading
writes the sound: Bengali ঈ is *i*, as ই is.

| Letters | Sound | Example |
|---|---|---|
| a | the short vowel every consonant carries: *u* in *but* in Hindi, *a* in Telugu | कल *kal* |
| ā ī ū | long a, i, u: held about twice as long | పాలు *pālu*, नहीं *nahīm̐* |
| e ē, o ō | short and long e and o, where a language has both (Telugu, Kannada) | నేను *nēnu* |
| ē ō | the long e and o of Hindi, which has no short ones | मेरा *mērā* |
| ai au | the vowels of ऐ and औ | है *hai* |
| ô | Bengali's and Assamese's own vowel, as in *law* | কথা *kôthā* |
| ê | the vowel of *cat*, in Bengali, and in words from English | ব্যাগ *bêg* |
| ṭ ṭh ḍ ḍh ṇ | tongue curled back to the roof of the mouth (retroflex) | పాట *pāṭa*, अंडा *aṇḍā* |
| t th d dh n | tongue on the back of the upper teeth (dental) | పాత *pāta* |
| kh gh ch jh th dh ph bh | an h after a letter is a puff of breath, never one sound: *th* is not *thin*, *ph* is not *phone* | खाना *khānā* |
| c ch | *ch* of *church*; ch with a puff of breath | चाय *cāy*, छह *chah* |
| ś ṣ | *sh*; ṣ with the tongue curled back | शादी *śādī* |
| ṅ ñ | *ng* of *sing*; *ny* of *canyon* | বাংলা *bāṅlā* |
| ḷ | an l with the tongue curled back | ನಾಳೆ *nāḷe* |
| ṛ ṛh | a flap with the tongue curled back | लड़का *laṛkā* |
| ṁ | the anusvara where it nasalises the vowel before y, r, l, v, s or h | संसार *saṁsār* |
| m̐ | the vowel before is said through the nose | हाँ *hām̐* |
| k͟h q ġ z f | sounds from Persian, Arabic and English, written with a dot (nukta) | ख़त्म *k͟hatm* |
| x | Assamese's own sound, as in Scottish *loch*; ISO 15919 has no letter for it | অসম *ôxôm* |


<a id="where-the-readings-depart-from-iso-15919"></a>

## Where the readings depart from ISO 15919


Each row is a deliberate departure, made because the learner is better served
by the sound than by the spelling. "ISO 15919 writes" is the letter-for-letter
reading of the script, as the tables in `tools/transcribe.py` give it. The
last column is the file that shows it: a card id, or the language's
`decks/<code>/<code>-romanisation.yaml`, which says the same in a paragraph.

| What | ISO 15919 writes | Fluenough writes | Why | Shown by |
|---|---|---|---|---|
| Inherent a, where it is not said (Hindi, Marathi, Gujarati, Bengali, Assamese) | कितना *kitanā* | *kitnā* | Letter for letter suggests a syllable nobody says | hi-0163; `hi-romanisation.yaml` |
| Inherent a in Bengali and Assamese | কত *kata* | *kôto*: ô where it is said [ɔ], o where it is said [o] | The vowel is not [a]. ô is ISO 15919's letter for ऑ, reused | bn-0417, as-0377; `bn-romanisation.yaml`, `as-romanisation.yaml` |
| য-ফলা, ব-ফলা and ম-ফলা (Bengali, Assamese); ê for [æ] (Bengali) | স্যার *syāra*, আত্মীয় *ātmīẏa* | *sêr*, *āttiyo* | The mark holds the consonant or changes the vowel; it does not say y, v or m | bn-0187, bn-0443; `bn-romanisation.yaml` |
| Conjuncts said otherwise than their letters | ज्ञ *jña*, क्ष *kṣa* | ज्ञ: Hindi *gya*, Marathi *dnya*, Gujarati *gna*, Bengali *gg*; क्ष: Hindi *kśa*, Gujarati *kśa*, Bengali and Assamese *kkh* (Marathi क्ष stays *kṣa*, as ISO 15919 writes it) | The letters are not how the conjunct sounds | hi-0083, hi-0085, mr-0089, gu-0085, bn-0081, as-0085 |
| Anusvara ं and the nasal vowel | always ṁ: अंडा *aṁḍā*, नहीं *nahīṁ* | the nasal said, *aṇḍā*; m̐ for a nasal vowel, *nahīm̐*; ṁ only before y, r, l, v, a sibilant or h, *kiṁvā*; Bengali and Assamese ং is ṅ, *bāṅlādeśi*. The same in Gujarati, Telugu and Kannada: *dukāṇam*, *tiṅgaḷu*, *navembar* (ISO 15919: ṁ) | Anusvara is whichever nasal comes next | hi-0258, hi-0156, mr-0577, bn-0422, te-0246, kn-0451, kn-0464; `hi-romanisation.yaml`, `bn-romanisation.yaml`, `te-romanisation.yaml`, `kn-romanisation.yaml`, `gu-romanisation.yaml`, `as-romanisation.yaml` |
| Telugu's half nasal ఁ | *teravam̐baḍalēdu* | *teravabaḍalēdu*, left out | It is no longer said | `te-en-reading-diddubatu.yaml`; `te-romanisation.yaml` |
| Long ī ū, where the language does not tell them from i u (Marathi, Gujarati, Bengali, Assamese) | मी *mī*, কী *kī* | *mi*, *ki* | A mark would suggest a contrast the language does not make. Bengali ঈ is *i* | mr-0206, bn-0193, gu-0310 |
| ए and ओ in those four languages | ē ō: आहे *āhē*, মোড় *mōṛa* | *e*, *o*: *āhe*, *moṛ* | No short e or o to tell them from | mr-0205, bn-0314 |
| Bengali ঐ ঔ; Assamese ঐ ঔ and the vowel sign ো | ai au; Assamese মোৰ *mōra* | Bengali *oi*, *ou*; Assamese *ôi*, *ôu*, and *u* for ো in words, said [ʊ] (*mur*, *muk*). The letter ও alone still reads *o* | They are said so | bn-0775, bn-0011, as-0188, as-0167, as-2064 |
| Bengali স and ষ (শ is ś in both) | s and ṣ: সে *se*, পরিষ্কার *pariṣkāra* | *ś* where said sh: *śe*, *poriśkār*; *s* where said s (*strī*) | Said alike, as sh or as s, by the word | bn-0126, bn-0683; `bn-romanisation.yaml` |
| Assamese স শ ষ | s ś ṣ: দেশ *dēśa* | *x*: *dex* | One sound, as in Scottish *loch*; ISO 15919 has no letter for it | as-0173 |
| Other Assamese letters said alike | ছাৰ *chāra*, জানুৱাৰী *jānuvārī*, ভাইটি *bhāiṭi*, ভণ্টি *bhaṇṭi* | *sār*, *zānuwāri*, *bhāiti*, *bhonti*: চ ছ as s; জ ঝ য as z; ৱ as w; ṭ ṭh ḍ ḍh as t th d dh; ণ as n | Assamese says them alike | as-0162, as-0393, as-0155, as-0156 |
| Other Bengali letters said alike | কারণ *kāraṇa*; য y, ঢ় ṛh, য় ẏ | *kāron*; j for য, ṛ for ড় and ঢ়, y for য় | Bengali says them alike | bn-0365, bn-0739; `bn-romanisation.yaml` |
| ष in Hindi and Gujarati | भाषा *bhāṣā*, શિક્ષક *śikṣaka* | *bhāśā*, *śikśak* | Said as श | hi-0197, gu-0322 |
| ऋ | *r̥*: कृपया *kr̥payā* | Hindi *kri*, Marathi, Gujarati, Kannada and Telugu *ru*, Bengali and Assamese *ri* | How it is said, in letters every keyboard and font has | hi-0616, mr-0157, te-0007, as-0007 |
| Kannada ೞ; Kannada ಱ and Telugu ఱ | ಮೞೆ *maḻe*; ṟ | *maḷe*; *r* | No longer said differently from ಳ and ర | kn-0580; `kn-romanisation.yaml`, `te-romanisation.yaml` |
| ಫ in words from English | ಕಾಫಿ *kāphi* | *kāfi* | Said f | kn-0494 |

Each language's file in `decks/<code>/<code>-romanisation.yaml` says how its
readings are written, in a paragraph. Each card also records how the word is
said in the **IPA**, the International Phonetic Alphabet: /paːlu/. The app
does not show it yet.

A typed answer needs none of the marks. *palu*, *paalu* and *pālu* are all
right for పాలు, as *kitna* and *kitnaa* are for कितना: answers are compared
after the marks are taken away, and each romanisation file lists the spellings
people type for one sound. To write a reading and IPA for a new card, run
`python3 tools/transcribe.py <code> "<word>" <how it is typed>`.

See also: [Learner-Guide](Learner-Guide) · [Home](Home)
