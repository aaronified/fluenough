# Deck work queue: Russian A1 plan

Status (2026-11-28): owner orders: "A1 only, one at a time." and "Do all of them one by one." (Italian and German done; Russian next, then Greek, Polish). Scope is Russian (`ru`, tracker #365) to the A1 mark of `ru-path.yaml` only, then stop (second-list languages other than Classical Sanskrit and Tamil go to A1 only, owner 2026-11-20; one language session at a time, owner 2026-11-17). No A2/B1, no genre decks (culture, proverbs, situations, topics, facts, recommendations), no other language (Ukrainian is a separate language: not reused, not started). Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task; the conventions and validator traps of section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) apply word for word (read Russian for Kannada, `ru` for `kn`, `iso639_3: "rus"`). The shape is that of [Deck-Work-Queue-DE](Deck-Work-Queue-DE.md) and [Deck-Work-Queue-IT](Deck-Work-Queue-IT.md), with the script units of [Deck-Work-Queue-KO](Deck-Work-Queue-KO.md).

State was read from `origin/decks-live` (PyYAML over `decks/ru/**` and `decks/ru/ru-path.yaml`) and from main's `tools/` and `assets/languages.yaml` on 2026-11-28.

## 1. Audit

| What | State |
|---|---|
| Language entry | `assets/languages.yaml`: `ru`, `iso639_3: rus`, Русский, script `cyrillic`, family `slavic`, TTS `ru-RU`, icon Ру |
| decks-live | `ru-phrasebook` (cards `ru-0011..`), `ru-first-words` (10 cards `ru-0001..0010`), their English layers, `decks/ru/ru-path.yaml` with 88 units: unit 1 built (10 words), 87 planned, `alphabet: []`, genders `m f n`; no script decks, no facts file, no `docs/review-queue/ru.md` |
| A1 mark | unit 33 (`ru-animals`, `milestone: A1`): 32 units still to build (2 to 33): 25 theme units and 7 grammar or script units |
| Units to A1 | 2 grammar sound-differences (and stress), 3 questions, 4 pronouns, 5 family, 6 numbers-1-20, 7 script letters (`cyrillic-letters`), 8 script reading-and-spelling, 9 about-me, 10 everyday-verbs, 11 adverbs, 12 quantities, 13 describing, 14 grammar gender, 15 time, 16 location, 17 more-verbs, 18 work, 19 grammar present-tense, 20 numbers-big, 21 food, 22 groceries, 23 market, 24 grammar cases-1 (nominative, accusative, prepositional), 25 directions, 26 transport, 27 body, 28 places, 29 grammar be-verb, 30 things, 31 home, 32 clothes, 33 animals |
| Engine | none: no `ru` branch in `tools/transcribe.py`, no `ru` in `tools/phonetic_languages.yaml`, no `ru-phonetics.yaml`, 0 `phonetic`. Existing `ipa` and `reading` (BGN/PCGN style, soft sign `'`, `ya`, `yu`) are hand-written; stress is not marked in `target` |
| Sources | kaikki.org Russian dump and en.wiktionary pages (CC BY-SA 4.0, one item per source); no NC source (owner) |

## 2. Findings that shape the plan

- **Engine first.** Every card's `ipa` is written by the repo's tools, never by hand (owner, 2026-10-30). RU-110 adds `russian_ipa()` (and the reading transliteration, keeping the repo's existing scheme unchanged) to `tools/transcribe.py` with the `ru` dispatch; the existing cards are checked against it and a disagreement becomes a review-queue row, never a silent edit. Russian stress is lexical: the engine takes a stressed-form hint (as German and Italian) and a Wiktionary hint pass runs over every card; vowel reduction (akanye, ikanye), palatalisation and final devoicing are rules.
- **Script units.** Unit 7 (the letters) and unit 8 (reading and spelling) are script units: the path's `alphabet:` list names the script decks, as Korean's.
- **Nouns** carry gender (`m`, `f`, `n`) and, where the stem changes, a note; **verbs** give the aspect partner where a read source gives it. Stress is shown from a read source on every word.
- **Source discipline.** Every card word is a headword of a read Wiktionary entry. A gloss written from memory is not allowed. Unverifiable rows go to `docs/review-queue/ru.md`.
- **Sentences.** Build them only from taught words and frames that can be cited; state the source of every grammar table row. Grammar units use only words earlier on the path teach.

## 3. Task table

Ids (never reused, ascending inside a task; highest in use `ru-0030`s range to be read from the deck): script `ru-0300..0399`, grammar units `ru-0400..0999` (60 per unit in path order), word units `ru-1300..3049` (70 per unit in path order), sentences `ru-4000..4999`.

| Id | Model | Branch | Spec |
|---|---|---|---|
| RU-110 | Sonnet | `tools/ru-transcribe` (PR to main) | `russian_ipa()` engine with stress hint, tests, the `ru` dispatch; check against the existing cards; registry entry |
| RU-050 | Haiku | none (a report in the scratchpad) | candidate words per planned A1 theme from the kaikki dump: gloss, pos, gender, stressed form, aspect partner; shortfalls named |
| RU-070 | Haiku | `decks/ru-a1-wave1` | script decks (letters, reading-and-spelling) and layers; path `alphabet` |
| RU-100.. | Haiku (Sonnet specs the grammar tables) | `decks/ru-a1-wave1` | the grammar units and 25 word units with layers; path entries move from `planned` to `decks` in the same commit |
| RU-150 | Haiku | rides on the wave | `docs/review-queue/ru.md` rows for every uncertain card |
| RU-160 | Sonnet | `decks/ru-phonetics-wave1` | `ru-phonetics.yaml`, the `ru` entry of `tools/phonetic_languages.yaml`, `derive_phonetic.py ru --bracket-unchanged --write` after the content merges |

## 4. Progress

2026-11-28: audit done, this page written; RU-110 and RU-050 launching.
