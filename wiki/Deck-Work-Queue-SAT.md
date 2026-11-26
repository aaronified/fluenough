# Deck work queue: Santali A1 plan

Status (2026-11-26): owner order: "Resume the deck work". Scope is Santali (`sat`, tracker #1178) to the A1 mark of `sat-path.yaml` only, then stop (second-list languages other than Classical Sanskrit and Tamil go to A1 only, owner 2026-11-20; one language session at a time, owner 2026-11-17). No A2/B1, no genre decks (culture, proverbs, situations, topics, facts, recommendations), no other language. Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task; the conventions and validator traps of section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) apply word for word (read Santali for Kannada, `sat` for `kn`, `iso639_3: "sat"`). The shape is that of [Deck-Work-Queue-ML](Deck-Work-Queue-ML.md) and [Deck-Work-Queue-TA](Deck-Work-Queue-TA.md).

State was read from `origin/decks-live` with PyYAML over every `decks/sat/**` file and `sat-path.yaml`, from main's `tools/` and `assets/languages.yaml`, and from the kaikki.org Santali dump (2026-11-26).

## 1. Audit

| What | State |
|---|---|
| Language entry | `assets/languages.yaml`: `sat`, `iso639_3: sat`, own name ᱥᱟᱱᱛᱟᱲᱤ (Santāṛi), scripts `ol_chiki`, `latin`, `devanagari`, `bengali`, family `austroasiatic`; script question and answers marked `unchecked` |
| Script support | `ol_chiki` is in `tools/deck_index.py` (Noto Sans Ol Chiki, `NotoSansOlChiki.ttf`), `lib/core/decks/font_check.dart`, `script_of.dart`, `language_views.dart` and the `scriptName` token. No Ol Chiki font file is bundled under `assets/fonts` (the app downloads it, as for other scripts) |
| decks-live | `sat-phrasebook` (14 cards, ids `sat-9001..`), `sat-first-words` (36 cards `sat-0101..0136`), their English layers, `sat-path.yaml` with 87 units: unit 1 built (36 words), 86 planned, `alphabet: []`. No script decks, no grammar decks, no sentences decks, no `sat-romanisation.yaml`, no facts file, no `docs/review-queue/sat.md` |
| A1 mark | unit 34 (`sat-animals`, `milestone: A1`): 34 units; 26 theme units plus 8 grammar and script units; 690 planned words in the 25 planned theme units, plus the 36 of unit 1 |
| Units to A1 | 2 sound-differences (grammar), 3 questions, 4 pronouns, 5 family, 6 numbers-1-20, 7 to 9 script (letters, signs, other scripts), 10 about-me, 11 everyday-verbs, 12 adverbs, 13 quantities, 14 describing, 15 grammar pronouns-number (dual, inclusive/exclusive), 16 time, 17 location, 18 more-verbs, 19 work, 20 grammar word-order, 21 numbers-big, 22 food, 23 groceries, 24 market, 25 grammar verb-endings, 26 directions, 27 transport, 28 body, 29 places, 30 grammar postpositions, 31 things, 32 home, 33 clothes, 34 animals |
| Engine | none: no `santali()` in `tools/transcribe.py`; no `sat` entry in `tools/phonetic_languages.yaml`; no `sat-phonetics.yaml`; 0 `phonetic`. The 50 existing readings and broad `ipa` are hand-written, with `tags: ["doubtful"]` on `sat-0105`, `sat-0106` |
| Sources reachable | kaikki.org Santali dump: 989 headwords (534 nouns, 140 verbs, 75 adjectives, 52 numerals, 36 pronouns, 33 characters), 545 with a sound; en.wiktionary pages; Wikimedia sites answer 429 without a polite client (pace and back off). The dump is smaller than the 726 planned words: shortfalls are expected and are listed, never invented |
| Open PR #1650 | `decks/fw-source-gaps` (first-words completion for Santali, Manipuri, Bodo) is red (a non-Latin word without its reading in a note: `sat-0138` `চা` needs `(cā)`). It belongs to the first-words work: not merged and not pushed to here. A fix of the same note goes in this session's own PR |
| Licence | Wiktionary text is CC BY-SA 4.0 (compatible, one item per source). Nothing from an NC source (owner) |

## 2. Findings that shape the plan

- **Spellings.** The course teaches Ol Chiki. The readings are Latin, based on ISO 15919 as the repo defines it, with `'` for the glottal stop of a checked final consonant (`ac'`, `mit'`) as the existing cards write it. Latin, Devanagari and Bengali spellings used by the community are taught in unit 9 only, each from a read source.
- **Engine first.** New cards are never hand-written for reading or IPA (CLAUDE.md, Plan-Ipa-Revamp). SAT-110 builds `santali()` in `tools/transcribe.py` and a registry entry, verified against the 50 existing cards and Wiktionary's sounds; a disagreement is a review-queue row, never a silent edit.
- **Source discipline.** Every card word is a headword of a read Wiktionary entry (or another named source read on the page). A gloss written from memory is not allowed. A word with no readable source is listed as a shortfall in `docs/review-queue/sat.md` for a Santali speaker.
- **Grammar units** (sound differences, dual number and inclusive/exclusive pronouns, word order, verb endings, postpositions): taught only from sources read to the page (Campbell's Santal Grammar 1866 and Bodding's Santal Grammar are public domain; Wikipedia, Wiktionary appendices). A table row that cannot be checked is left out and queued.

## 3. Task table

Ids (never reused, ascending inside a task): script `sat-1000..1299`, grammar words `sat-0400..0999`, new vocab `sat-1300..2999`, sentences `sat-3000..3999`.

| Id | Model | Branch | Spec |
|---|---|---|---|
| SAT-110 | Sonnet | `tools/sat-transcribe` (main) | `santali()` engine, its tests, the `sat` registry entry; check against `sat-phrasebook` and `sat-first-words` |
| SAT-050 | Haiku | none (a report) | candidate words per planned A1 theme from the kaikki dump, with gloss, part of speech and sound; shortfalls named |
| SAT-070..075 | Haiku | `decks/sat-a1-wave1` | `sat-script-letters`, `-signs`, `-other-scripts`; `alphabet` in the path |
| SAT-100.. | Haiku (Sonnet specs the tables) | `decks/sat-a1-wave1` | the 5 grammar units, and 25 word units, with layers; path entries move from `planned` to `decks` in the same commit |
| SAT-130.. | Haiku | `decks/sat-a1-wave1` | sentences decks for word units with enough taught words |
| SAT-150 | Haiku | rides on the wave | `docs/review-queue/sat.md` rows for every uncertain card |
| SAT-160 | Sonnet | `decks/sat-phonetics-wave1` | `sat-phonetics.yaml`, `derive_phonetic.py sat --bracket-unchanged --write` after the content merges |

## 4. Progress

2026-11-26: audit done, this page written. SAT-110 and SAT-050 started.
