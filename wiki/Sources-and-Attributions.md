# Sources and attributions

Source of truth: this wiki page.

Where the words, sounds, pictures, fonts, books and code of Fluenough come from, and the licence each one carries. Written 2026-11-21 against `main` and `decks-live`, replacing an older version from when the app had three languages and no culture decks. The app's own list is Settings > Sources; an app change mirrors the "Thank you" section below there. The licences of the decks and the quoted books are also on [Deck-Licences-and-Quoted-Books](Deck-Licences-and-Quoted-Books).

## Thank you

Fluenough stands on the work of many people who shared theirs freely. Thank you:

- To the volunteers who write and keep **Wiktionary**, **Wikipedia**, **Wikisource**, **Wikiquote** and **Wikimedia Commons**: much of what the decks know about words, sounds, books and places is theirs.
- To the contributors of **Tatoeba**, who wrote and translated sentences for anyone to learn from.
- To the team behind **Open English WordNet**, for the sets of English words that mean the same.
- To **Google and the Noto Project**, and to the **Roboto** authors, whose fonts let every script on the app be drawn properly; and to **Valerie Sutton**, **Adam Frost**, **Stephen E Slevinski Jr** and the **Center for Sutton Movement Writing**, for SignWriting and its fonts.
- To the creators of the **OpenMoji** drawings and the **Noto Emoji** pictures that show what words mean.
- To **AI4Bharat**, for the IndicConformer model and the IndicVoices recordings behind the AI listener, and to the people who recorded them; and to the makers of **ONNX Runtime**.
- To the authors of the open-source **Flutter and Dart packages** the app is built from.
- To the writers whose works are in the public domain and are quoted here: Tagore, Sukumar Ray, Premchand, Gurajada Apparao and the many classical authors named below.
- To the **reviewers**, who check the decks as a community. They are anonymous by design, so they are thanked here as a group: every card is better for them.
- To the **contributors and learners** who report problems, send fixes and ask for languages.

## Deck content and its licence

- **Decks**: most are written for Fluenough, by its builders. Their `source` field says so ("Written for this deck", "Written for this course", or a named course). The decks are under **CC BY-SA 4.0** ([ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa)); the app itself is under **GPL-3.0** ([ADR-0003](ADR-0003-Licence)). Content once given as CC0 stays usable.
- **Where a deck takes text from elsewhere** it names the source in `source`, and the app shows it under each passage, on the deck's page and in Settings > Sources. A new source gets a line here, and its decks name it.
- **Sound and script explainers** cite the references they follow: the IPA chart (2020 revision) and Handbook of the International Phonetic Association (1999); the *Illustrations of the IPA* in the Journal of the International Phonetic Association (for example Khan 2010 on Bengali and Bhaskararao and Ray 2017 on Telugu); Ohala (1999) on Hindi; Hualde (2005) on Spanish; and Wikipedia's phonology articles (CC BY-SA 4.0), which the decks adapt and credit by article. Where a reference was only named by Wikipedia and not read, the deck says so.
- **Other standards the course decks follow**: Unified English Braille, third edition, 2024 (International Council on English Braille); Recommendation ITU-R M.1677-1, International Morse code (2009); the International SignWriting Alphabet 2010 by Valerie Sutton, in Unicode's SignWriting block.
- **Culture decks, proverbs, creators and recommendations** (Telugu, Bengali, Spanish, Marathi, Kannada, Assamese, Chinese, Hindustani, Japanese, French, Gujarati and Classical Sanskrit): each fact names its page. The sources are English Wikipedia articles (read on the date given), the language editions of Wikisource and Wikiquote for texts and sayings, Wikidata for dates, and for Sanskrit also GRETIL. Proverbs name their edition and say whether the date is the proverb's or the day the page was read.
- **A deck's `license` field** is `CC-BY-SA-4.0`. No CC BY-NC data is used: it cannot be redistributed under CC BY-SA 4.0 or the GPL (SignBank and SignBank Plus are NC). The owner's question and the options, still open, are recorded on 2026-11-20 in [Owner-Decisions-History](Owner-Decisions-History#cc-by-nc-sources-2026-11-20).

## Words, pronunciations and sentences

| Source | What it gives | Licence | Where |
|---|---|---|---|
| [Wiktionary](https://www.wiktionary.org) | Word data, and the pronunciations in `[ ]` (`phonetic_source: "wiktionary"`), taken from the kaikki.org Wiktextract dumps ([Deck-Tools](Deck-Tools)) | CC BY-SA 4.0 | per item |
| [Wikipedia](https://www.wikipedia.org) | Word frequency counted from each language's Wikipedia; phonology and culture facts | CC BY-SA 4.0 | per card or deck |
| [Open English WordNet](https://en-word.net) | With Wiktionary, the English synonym sets that typed meanings accept ([ADR-0050](ADR-0050-English-Synonym-Sets)) | CC BY 4.0 (WordNet), CC BY-SA 4.0 (Wiktionary) | `assets/synonyms/` |
| [Tatoeba](https://tatoeba.org) | Example sentences | CC BY 2.0 FR | per example |
| [kaikki.org](https://kaikki.org) | The Wiktextract extracts the tools read | the Wiktionary licence | build time only |

IndoWordNet is not used (owner, recorded in [ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa)).

## Recordings and pictures

- **Recordings**: a card names its recording's licence and credit in `audio_credit`. Today the only shipped recordings are the Morse code course's, generated by `tools/make_morse_course.py` (a 600 Hz tone, 15 words per minute, ITU timing), **CC0-1.0**, no speaker. Words are otherwise spoken by the phone's text to speech. Recordings from Wikimedia Commons and Wiktionary are planned, each kept with its own licence and credit: see [Plan-Sounds-Decks](Plan-Sounds-Decks) (Proposed, nothing built).
- **Pictures on cards**: the 86 pictures bundled in `assets/pictures/` are [Noto Emoji](https://github.com/googlefonts/noto-emoji) by Google, **Apache License 2.0**; the licence ships with them in [assets/pictures/LICENSE](https://github.com/aaronified/fluenough/blob/main/assets/pictures/LICENSE).
- **OpenMoji** drawings ([openmoji.org](https://openmoji.org)) are allowed on cards, **CC BY-SA 4.0**, credited per card in `image_credit`.
- **Wikimedia Commons** images are allowed on cards, each under its own licence, credited per card. In use now: three public-domain diagrams in the sounds explainers (a phoneme and allophone chart by AnonMoos; two U.S. National Cancer Institute SEER illustrations of the mouth and the head and neck, works of the U.S. federal government).
- **Creators' portraits** in the culture decks are not shipped: none has a licence checked yet.
- The format is in [Deck-Format](Deck-Format) (card pictures and recordings).

## Fonts

The fonts that download with a course, and the ones in the app, are listed one by one in [Script-Fonts-Inventory](Script-Fonts-Inventory).

- **Noto fonts** (Google, The Noto Project Authors), **SIL OFL 1.1**: Latin, Cyrillic and Greek subsets, and the font of each Indic, East Asian, Perso-Arabic and other script, downloaded per course ([ADR-0042](ADR-0042-Script-Fonts-Download-Per-Course)).
- **Noto Sans SignWriting** (SIL OFL 1.1): the symbols of the sign language decks ([ADR-0056](ADR-0056-SignWriting-For-Sign-Languages)).
- **Sutton SignWriting fonts** (Fill and Line, SIL OFL 1.1; Copyright 1974-2014 Center for Sutton Movement Writing, Inc.; symbols by Valerie Sutton, refined by Adam Frost, encoded by Stephen E Slevinski Jr), from the MIT package `@sutton-signwriting/font-ttf`. Used at build time only, to draw whole signs; not in the repository.
- **Roboto** (Regular, Medium, Bold), The Roboto Project Authors, **Apache License 2.0**: the interface font. The licence is in `assets/fonts/ROBOTO-LICENSE.txt`.
- **Braille shadow-dot font**: made for the app, **SIL OFL 1.1**, Copyright The Fluenough Authors (`assets/fonts/OFL.txt`; [ADR-0043](ADR-0043-English-Braille-Course)).

## The AI listener and speech

- **IndicConformer** by [AI4Bharat](https://ai4bharat.iitm.ac.in): the Telugu AI listener model, **MIT**, converted to run on the phone.
- **IndicVoices** by AI4Bharat: the recordings the model was trained on, **CC BY 4.0**.
- **ONNX Runtime** by Microsoft: runs the model on the phone, **MIT**.
- The system's own speech recognition and text to speech (Android's) are used where the AI listener is not.

## Libraries and tools

Direct dependencies in `pubspec.yaml`: `drift`, `drift_flutter`, `sqlite3`, `http`, `crypto`, `flutter_tts`, `yaml`, `path_provider`, `file_picker`, `speech_to_text`, `record`, `audioplayers`, `flutter_volume_controller`, `url_launcher`, `ota_update`, `flutter_local_notifications`, `timezone`, with Flutter's own `flutter_localizations` and `intl`; for development `flutter_test`, `flutter_lints`, `drift_dev`, `build_runner`. Each is open source under the licence on its pub.dev page (MIT, BSD or Apache 2.0 for these); their licences are collected in the app's licence page by Flutter. The licence of each package was not re-checked for this page. The app is built with [Flutter](https://flutter.dev) (BSD-3-Clause).

The deck tools are Python scripts in `tools/`, using PyYAML, fontTools and ffmpeg, and read kaikki.org and Wikimedia data at build time ([Deck-Tools](Deck-Tools)). FSRS, the scheduling algorithm, is described in [ADR-0033](ADR-0033-Fsrs).

## Quoted books and works

Quoted letter for letter, from the edition named, and never corrected. The full account is on [Deck-Licences-and-Quoted-Books](Deck-Licences-and-Quoted-Books).

- *Sahaj Path*, part 1, by Rabindranath Tagore (1930), Visva-Bharati printing of 1993: Bengali reading passages. Public domain.
- *Abol Tabol* by Sukumar Ray (1923), Shaibya printing: older spellings in the Bengali spelling deck. Public domain.
- *Panch Parmeshwar* by Premchand, in *Prem-Dwadashi* (1926): Hindi reading passages. Public domain.
- *Diddubatu* by Gurajada Apparao (1910), in *Gurujadalu* (MaNaSu Foundation, 2012): Telugu reading passages. Public domain.
- *A Collection of Telugu Proverbs* (supplement) by Captain M. W. Carr (Madras, 1868), on Telugu Wikisource: Telugu proverbs. Public domain.
- *Refranes de la lengua castellana* (anonymous, Barcelona, 1815), on Spanish Wikisource: Spanish proverbs. Public domain.
- Pierre-Marie Quitard, *Dictionnaire ... des proverbes* (Paris, 1842): French proverbs. Public domain.
- *Pravadmala*, edited by James Long (1868), on Bengali Wikisource: Bengali proverbs. Public domain.
- Chinese classics on Chinese Wikisource (the *Analects*, *Mencius*, *Xunzi*, *Han Feizi*, the *Records of the Grand Historian* and Tang and Song poems): each passage links its page.
- Sanskrit works on Sanskrit Wikisource and GRETIL (the Hitopadesha, Meghaduta, Yoga Sutras, Natya Shastra, Upanishads, Ashtadhyayi and more), and Telugu, Kannada, Gujarati, Assamese and Marathi works on their Wikisources (Vemana, Kanyasulkam, Pampa Bharata, *Burhi Aair Sadhu*, *Stri-Jeevan* and more): the edition is named per card.
- Wikiquote proverb lists (Kannada, Gujarati, Assamese, Marathi) and Wiktionary entries for oral proverbs; the Japanese iroha karuta sets as recorded on Japanese Wikipedia.

Wikisource transcriptions are checked against page images where a deck says so; where they differ, the page wins.

## Flutter skill attribution

The `flutter-dart-code-review` skill is copied from another project. Its source and licence:

From [affaan-m/ECC](https://github.com/affaan-m/ECC), `skills/flutter-dart-code-review/SKILL.md`
at b92f181, copied unchanged on 2026-10-12 (owner's request). MIT licence:

MIT License

Copyright (c) 2026 Affaan Mustafa

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

For this repository, AGENTS.md and CLAUDE.md come first wherever this checklist
differs from them (for example, `lib/core` stays free of Flutter imports).

See also: [Home](Home)
