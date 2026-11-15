# Deck work queue: Tamil completion plan

Status: audit and plan of 2026-11-15. Owner instruction (2026-11-15): one session per language; this session owns Tamil (`ta`, tracker #354) and takes it as far toward completeness as is verifiable, "by delegating to agents": audit, then path units to A1 (B1 if time allows), then the other deliverables of [Plan-Language-Completeness](Plan-Language-Completeness.md). Tamil is on the second list (A1 minimum, first deck for sure; owner 2026-11-02 and 2026-11-06). The shape is that of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md), [Deck-Work-Queue-GU](Deck-Work-Queue-GU.md) and [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md). Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task. The conventions and validator traps of section 2 of the Kannada queue apply word for word (read Tamil for Kannada, `ta` for `kn`, `iso639_3: "tam"`).

State was read from `origin/decks-live` on 2026-11-15 with PyYAML over every `decks/ta/**` file and `ta-path.yaml`, plus `decks/sections.yaml`, `decks/creators/`, `decks/recommendations/`, `docs/review-queue/ta.md` and `tools/` on main.

## 1. Audit against the completeness checklist

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | **PARTIAL** | `ta-path.yaml`: 115 entries; 27 units built, 87 planned (A1 mark at unit 45, A2 at 78, B1 at 114); `alphabet: []` | TA-100..TA-1xx (A1 first) |
| 2 | Cores and English layers | **PARTIAL** | 43 vocab cores directly in `decks/ta/` plus `ta-path`, 44 layers in `decks/ta/en/`; 332 cards, highest id `ta-0332`; no grammar core at all | TA-100.. |
| 3 | Sentences decks | **GAP** | 16 `-sentences` decks; none for time, location, work, numbers-big, groceries, market, directions, transport, home, first-words | TA-130..139 |
| 4 | Reading decks | **MISSING** | no `ta-en-reading-*` | TA-200.. |
| 5 | Script decks | **MISSING** | no `ta-script-*`, no `ta-spelling`; units 7 and 8 are planned | TA-070..075 |
| 6 | Phrasebook | **DONE** | `ta-phrasebook`: 20 cards (limit 25) | none |
| 7 | Situations | **MISSING** | no `ta-situations.yaml` | TA-050 |
| 8 | Topics incl. script topics | **MISSING** | no `ta-topics.yaml` | TA-040 |
| 9 | Culture decks | **MISSING** (sourcing list DONE 2026-11-15) | no `ta-culture-*` on decks-live; [Plan-Culture-Tamil](Plan-Culture-Tamil.md) lists 25 works read to the text (deck 1: 9, deck 2: 6, deck 3: 6, deck 4: 4, so deck 4 ships short) and 40 dropped items | TA-010..013 (after TA-110 for readings) |
| 10 | Creators, eras, legacy | **MISSING** | no `decks/creators/ta.yaml` | rides on TA-010..013, TA-060 |
| 11 | Proverbs | **MISSING** | none (owner 2026-11-13: built for every priority language) | TA-020..022 |
| 12 | Multi-word verbs | **MISSING** | planned units 57 and 65 (compound and conjunct verbs) are rules units, not genre decks | TA-030..032 |
| 13 | Professional | HELD | `professions: []` in `decks/sections.yaml` | none (needs the owner) |
| 14 | Recommendations | **MISSING** | no `decks/recommendations/ta.yaml` | TA-060 |
| 15 | Narrow IPA and broad `ipa` | **BLOCKED** | no Tamil engine in `tools/transcribe.py` (Malayalam has one), no `ta` entry in `tools/phonetic_languages.yaml`, no `ta-phonetics.yaml`; broad `ipa` on 327 of 332 cards, **hand-written**; 0 `phonetic` | TA-110 first, then TA-111, TA-112 |
| 16 | Review-queue rows | **PARTLY** | `docs/review-queue/ta.md`: 46 lines, all 2026-11-05 to 2026-11-07, including "course-wide: every reading and broad IPA is hand-written" | TA-120 |
| 17 | Sourcing list | **DONE** (2026-11-15, TA-001) | `wiki/Plan-Culture-Tamil.md`: culture 25 works read (4 decks), proverbs 60 from Percival 1874 (3 decks of 20), multi-word verbs 66 attested headwords (3 families), recommendations 20 (18 films, 2 novels), 40 dropped unverifiable; every entry read on a cited page, none from memory | none |
| 18 | Facts file | **MISSING** | no `ta-facts.yaml` | TA-080 |

### A1 gap, from the path (units 1 to 45)

| What | Units |
|---|---|
| Built (word units) | 1 to 6, 9 to 16, 23 to 26, 28, 33, 35 to 39, 43, 44 |
| Script, planned | 7 (`ta-script-vowels`), 8 (`ta-script-vowel-signs`) |
| Grammar, planned (words 0 unless noted) | 17 noun forms, 18 conjunctions (8 words), 19 pronoun forms, 20 be, 21 verb present, 22 demonstratives, 27 needs, 29 noun classes, 30 questions, 31 likes (2), 32 sentences, 34 continuous, 40 differences (6), 41 postpositions (2), 42 gender-number (10), 45 future (A1 mark) |
| Word units built with no sentences deck | time (14), location (15), work (23), numbers-big (24), groceries (26), market (28), directions (33), transport (35), home (39), first-words (1) |

## 2. Findings that shape the plan

- **No Tamil transcription engine.** Every existing Tamil reading and broad `ipa` was written by hand (review-queue row "course-wide"). New cards must not be hand-written (CLAUDE.md: readings and IPA are tool-written). TA-110 designs and builds `tamil()` in `tools/transcribe.py` first, on the pattern of `malayalam()` (script block 0x0B80, pulli, no conjunct ligatures, ழ ḻ, ற ṟ, the ன ந ண trio, voicing of stops between vowels and after nasals, Grantha letters), with its own tests. A shared-tool change goes through the parent session: issue plus `send_message` (this session does not merge it).
- **Spoken first, written later** (path header): the course teaches spoken forms (போறேன் pōṟēṉ), written forms in unit 79. Every grammar unit states which register its forms are.
- **No conjunct ligatures** in Tamil script: script decks are vowels, consonants incl. Grantha, vowel signs and the pulli, digits, reading words (path header, "What is Tamil's own").
- **Word-final and sandhi.** Tamil doubles a stop after the oblique stem (வீடு → வீட்டு): grammar tasks say so on the card and in the layer note.

## 3. Task table

Ids: highest today `ta-0332`; reserved ranges (never reused, ascending inside a task): grammar words `ta-0400..0999`, new vocab `ta-1000..2999`, sentences `ta-3000..3999`, genre kinds `ta-6000..6999`.

| Id | Model | Branch | Spec |
|---|---|---|---|
| TA-110 | Sonnet | `tools/ta-transcribe` (tools PR to main, via parent) | `tamil()` engine in `tools/transcribe.py` and its tests; verified against `ta-phrasebook` and the 327 existing broad `ipa` forms (a disagreement goes to the review queue, never silently "fixed" by editing) |
| TA-001 | Sonnet | main (docs) | **DONE 2026-11-15.** `Plan-Culture-Tamil`: verified sourcing list for culture (4 decks), proverbs (3), multi-word families, recommendations; nothing from memory |
| TA-070..075 | Haiku | `decks/ta-a1-wave1` | `ta-script-vowels`, `-consonants`, `-vowel-signs`, `-grantha`, `-digits`, `-reading`; set `alphabet` in the path; from TA-110 only |
| TA-100..TA-1xx | Haiku (Sonnet specs the grammar tables first) | `decks/ta-a1-wave1` | A1 grammar rules units 17 to 22, 27, 29 to 32, 34, 40 to 42, 45 and their layers, in path order; path entries move from `planned` to `decks` in the same commit |
| TA-130..139 | Haiku | `decks/ta-a1-wave1` | the 10 missing `-sentences` decks, 2 to 3 confusables per card |
| TA-040 | Haiku | `decks/ta-topics-wave1` | `ta-topics.yaml`: script topics plus grammar, word and culture topics |
| TA-050 | Haiku | `decks/ta-situations-wave1` | `ta-situations.yaml`: 10 sheets, widely used phrases only, marked draft |
| TA-080 | Haiku | `decks/ta-a1-wave1` | `ta-facts.yaml`, only facts with a read source |
| TA-010..013, 020..022, 030..032, 060 | Haiku | one branch each kind | culture, proverbs, multi-word, recommendations, from TA-001 only |
| TA-111..112 | Sonnet design, then tools | `phonetics/ta` | registry entry, `ta-phonetics.yaml`, `derive_phonetic.py` over all cards, after the content PRs |
| TA-120 | Haiku | rides on each wave | review-queue rows for every uncertain card |
| TA-2xx | Haiku | `decks/ta-readings-wave1` | reading decks for word units, after their sentences exist |
| B1 | Haiku | `decks/ta-a2-wave1`, `decks/ta-b1-wave1` | units 46 to 114, only if A1 has merged and time allows |

Work order: TA-110 and TA-001 (Sonnet, parallel) first; A1 wave once TA-110 is merged; then the rest by the order in Plan-Language-Completeness (c).
