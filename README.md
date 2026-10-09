<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="fluenough-brand/fluenough-lockup-dark.svg">
  <img src="fluenough-brand/fluenough-lockup.svg" alt="Fluenough" width="320">
</picture>

<br>

*Fluent enough.*

A language-agnostic drilling app for basic language skills — vocabulary,
production, listening and grammar — scheduled by spaced repetition, running
offline on your phone once a language's decks are downloaded.

<p>
  <a href="https://github.com/aaronified/fluenough/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/aaronified/fluenough/ci.yml?branch=main&amp;label=CI&amp;logo=github" alt="CI status"></a>
  <a href="https://github.com/aaronified/fluenough/releases/latest"><img src="https://img.shields.io/github/v/release/aaronified/fluenough?label=release" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/aaronified/fluenough" alt="Licence: GPL-3.0"></a>
  <a href="https://github.com/aaronified/fluenough/releases/latest"><img src="https://img.shields.io/badge/platform-Android-3DDC84?logo=android&amp;logoColor=white" alt="Platform: Android"></a>
  <a href="docs/DEVELOPMENT.md"><img src="https://img.shields.io/badge/Flutter-3.47%2B-02569B?logo=flutter&amp;logoColor=white" alt="Flutter 3.47 or later"></a>
  <a href="#why-fluenough-is-different"><img src="https://img.shields.io/badge/works_offline-once_decks_are_in-2E7D32" alt="Works offline once decks are in"></a>
  <a href="#courses"><img src="https://img.shields.io/badge/languages-8-C2621D" alt="8 languages"></a>
  <a href="https://github.com/aaronified/fluenough/issues"><img src="https://img.shields.io/github/issues/aaronified/fluenough" alt="Open issues"></a>
</p>

<p>
  <a href="https://github.com/aaronified/fluenough/releases/latest"><b>Download</b></a> ·
  <a href="#courses">Courses</a> ·
  <a href="#decks">Decks</a> ·
  <a href="#contributing">Contribute</a> ·
  <a href="docs/ROADMAP.md">Roadmap</a>
</p>

</div>

> **Status: early development.** The architecture, deck format, example
> decks, deck parser and validator are in, and the app's screens are built
> from the design. Progress is saved on the phone, one database per profile,
> and features not built yet are shown disabled, marked "Feature incoming". See
> [docs/ROADMAP.md](docs/ROADMAP.md).

## Why Fluenough is different

Most drilling apps are built around one language and then stretched to fit
others. Fluenough inverts that: **a language is just data.** A deck is a text
file, the card model is a superset that accommodates Latin, syllabic and
logographic scripts alike, and grammar is described by pattern tables rather
than hard-coded rules. Adding a language means adding files, never code.

- **Each skill is scheduled separately.** Seen, heard, spoken and written
  words, and grammar, each have their own schedule for each word: you can
  recognise a word long before you can produce it.
- **FSRS is fitted on the phone.** The scheduler learns how you forget, per
  language and skill, from your own answers.
- **Your learning stays on the phone.** There is no account, progress is
  saved on the phone, and nothing is sent anywhere to fit your schedule. The
  app goes online only to download decks, to check for updates and to send a
  report you choose to send. Downloading decks, like the update check, tells
  GitHub the phone's IP address and which files it asked for; nothing else.
  Once a day at most, at launch, the app asks GitHub whether its decks have
  changed; Settings > Deck downloads turns that off.

## Courses

Taught from English: Assamese, Bengali, Gujarati, Hindi, Kannada, Marathi and
Telugu, each starting with its script decks and a script guide. Spanish is
started. Japanese (`decks/ja/`) is kept in the repository but not offered in
the app for now. See [docs/ROADMAP.md](docs/ROADMAP.md).

The app comes with no decks. It downloads a language's decks from this
repository's `main` branch when you choose it, and you can start once its
first five are in; after that it works offline. Fixed and new decks arrive
without an app update: once a day at most it asks whether to fetch them, and
Settings > Deck downloads lists each language, with Update and Remove, and
can turn the daily check off
([ADR-0037](docs/adr/0037-decks-download-from-main.md)).

<!--
Screenshots: the owner will add the app screenshots here (a "Screenshots"
heading and a row of images) once all the visuals are complete. Nothing is
shown until then.
-->

## Get it

Fluenough is an Android app, built and run on Android phones for every
release. Download `app-release.apk` from the
[latest release](https://github.com/aaronified/fluenough/releases/latest) and
open it on the phone, allowing installs from your browser or file manager when
Android asks (sideloading).

To build it yourself, see [Building](#building) below.

## Read more

Each part opens in place.

<details>
<summary><b>Skills and drills</b></summary>

| Skill | Direction | Graded by |
|---|---|---|
| **Seen words** (recognition) | see target → recall or choose the meaning | you, or the app for a choice |
| **Heard words** (listening) | hear target → choose, then type, the meaning | the app |
| **Spoken words** (speaking) | see meaning → say target | the app, through the phone's speech recognition |
| **Written words** (production) | see meaning → type target | the app, with diacritic and typo tolerance |
| **Grammar** | understood: see a form → choose what it means; produced: prompt + slot → choose the form, then type it | the app |

Reading passages, match pairs, multiple choice and word order come on top.
Minimal-pair discrimination, for sound contrasts the learner's own language
does not make, is planned; a word can already name its minimal-pair partner,
which listening offers among the meanings.

All share one card model, and each word is scheduled separately in each
skill: you can recognise a word long before you can produce it. A right
answer also counts in part for the skills it implies, as the research finds
([ADR-0034](docs/adr/0034-hear-say-write.md)).

</details>

<details>
<summary><b>Spaced repetition, with a real audit trail</b></summary>

Scheduling is FSRS-6 ([ADR-0033](docs/adr/0033-fsrs.md)), fitted on the
phone to each learner, per language and skill, from their own answers;
nothing is sent anywhere ([ADR-0035](docs/adr/0035-fsrs-fitted-per-skill.md)). The part that
matters more is that **every review is
written to an append-only log** — not just the current interval. That means
your statistics are recomputable, and the scheduling algorithm can be replaced
later without throwing away your history. Most apps store only current state
and can never go back.

</details>

<details>
<summary><b>Text to speech</b></summary>


Listening drills use the **operating system's own TTS** — `android.speech.tts`
on Android, `AVSpeechSynthesizer` on iOS — through a pluggable `TtsEngine`
interface. This adds nothing to the download size, needs no network, and
covers far more languages than any bundled model could. Users install voices
through system settings.

A neural backend (Kokoro) is a candidate for a later release; see
[ADR-0002](docs/adr/0002-system-tts.md) for why it is not in v1.

</details>

<details>
<summary><b>Scripts are first-class</b></summary>


Where a language uses an unfamiliar writing system, learning the script and its
pronunciation *is* the first task, not a preliminary to it. Fluenough treats
script decks as ordinary decks — `decks/hi/hi-en-script-vowels.yaml` is a
worked example. The courses taught from English (Assamese, Bengali, Gujarati,
Hindi, Kannada, Marathi and Telugu) each start with their script decks and a
script guide; Spanish is started. See [docs/ROADMAP.md](docs/ROADMAP.md).

Japanese (`decks/ja/`) is kept in the repository but not offered in the app
for now.

</details>

<details>
<summary><b>How words are written in Latin letters: ISO 15919</b></summary>


Every word in an Indian language has a reading, its Latin letters, shown on the
card. The readings are **based on the letters of ISO 15919**, the international
standard for writing Indian scripts in Latin letters, and they **depart from it
wherever a learner is better served**
([ADR-0025](docs/adr/0025-iso-15919-and-ipa.md)). They are not a strict
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

</details>

<a id="where-the-readings-depart-from-iso-15919"></a>

<details>
<summary><b>Where the readings depart from ISO 15919</b></summary>


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

</details>

## Decks

Decks are YAML files under [`decks/`](decks/), versioned in git like any other
source. They are diffable, reviewable, and contributed as pull requests. The
app downloads them from `main`, by `decks/index.json`, so a merged deck
reaches learners without a release.

<details>
<summary><b>A deck, and how to validate it</b></summary>


```yaml
schema: 1
id: es-en-core-100
name: Spanish Core 100
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native:   { code: en, iso639_3: eng, name: English }
license: CC-BY-SA-4.0
cards:
  - id: es-0001
    target: la casa
    native: the house
    tags: [noun, home]
```

The full specification is in [docs/DECK-FORMAT.md](docs/DECK-FORMAT.md).
Validate any deck before opening a pull request:

```sh
python3 tools/deck_index.py            # write decks/index.json again
python3 tools/validate_decks.py decks/
```

The validator needs only Python 3.11+ and PyYAML — no Flutter toolchain. It
fails while `decks/index.json` is out of date.

</details>

<details>
<summary><b>The Telugu, Marathi, Kannada, Gujarati and Assamese decks have not been checked by a speaker</b></summary>


A deck no speaker has checked yet is tagged unreviewed and says so: some
Hindi and Bengali decks, and all the Telugu, Marathi, Kannada, Gujarati and
Assamese ones. The Telugu decks (`decks/te/`) were written from published
sources; the Marathi (`decks/mr/`), Kannada (`decks/kn/`), Gujarati
(`decks/gu/`) and Assamese (`decks/as/`) decks are a first attempt written for
Fluenough. No speaker has checked any of them
yet. Each one says so in its description and on its screen in the app. If you
speak one of these languages, please
[report mistakes](https://github.com/aaronified/fluenough/issues) or send a
fix; a review by a speaker is the most useful contribution these decks could
get.

</details>

<details>
<summary><b>Sources</b></summary>


Most decks are written for Fluenough. Where a deck's text comes from
elsewhere, the deck names the source in its `source` field, and the app shows
it: under each passage, on the deck's page, and in Settings, under Sources.

The Bengali decks quote two books in the public domain, letter for letter:

- *Sahaj Path*, part 1, by Rabindranath Tagore (1930), in the public domain:
  passages for reading.
- *Abol Tabol* by Sukumar Ray (1923), in the public domain: older
  spellings in the spelling deck, and passages for reading to come.

The Hindi reading deck quotes a story in the public domain, letter for
letter:

- *Panch Parmeshwar* by Premchand, as printed in *Prem-Dwadashi* (1926):
  passages for reading, checked against the page images.

The Telugu reading deck quotes a story in the public domain, letter for
letter:

- *Diddubatu* by Gurajada Apparao (1910), as printed in *Gurujadalu*
  (2012): passages for reading, checked against the page images.

A new source gets a line here, and its decks name it in `source`.

</details>

## Building

<details>
<summary><b>Building from source</b></summary>


You need the Flutter SDK (3.47+) and, for Android, a JDK and the Android SDK.
The platform folders are **not** committed; generate them on first checkout:

```sh
flutter create . --org app --project-name fluenough --platforms=android,ios
rm -f test/widget_test.dart   # generated boilerplate; references MyApp, not ours
flutter pub get
dart run build_runner build
flutter run
```

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for toolchain setup, including
notes for immutable Linux distributions and a warning about Waydroid and TTS.

</details>

## Contributing

Decks are the most useful contribution and need no Flutter toolchain — just a
text editor and Python. Code contributions are welcome too; the roadmap says
what is wanted next.

- [CONTRIBUTING.md](CONTRIBUTING.md) — how to contribute, deck or code
- [AGENTS.md](AGENTS.md) — how to work in this repository without colliding
  with the other people doing so. **Required reading before your first code
  change**, whether or not you use a coding agent.
- [docs/adr/](docs/adr/) — why things are the way they are

Several people build this in parallel, most of them with agents. Claim an issue
before you start, say which files you expect to touch, and keep pull requests
to one concern each.

## Licence

**GPL-3.0, with an App Store Distribution Exception.** See [LICENSE](LICENSE)
and [LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md).

<details>
<summary><b>The licence in detail</b></summary>

Fluenough is free software and every fork must stay free software. The
exception exists solely so the app can be distributed through stores whose
terms would otherwise conflict with the GPL; it grants no permission to close
the source. See [LICENSE](LICENSE) and
[LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md), and
[ADR-0003](docs/adr/0003-licence.md) for the reasoning.

Deck content carries its own licence, declared per file.

</details>

The pictures on cards are from [Noto Emoji](https://github.com/googlefonts/noto-emoji),
by Google, under the Apache License 2.0; the licence ships with them in
[assets/pictures/LICENSE](assets/pictures/LICENSE).
