# Deck work queue: Tamil completion plan

Status (2026-11-21): Tamil is Alpha on the app's completeness measure: 260 of 2,380 planned words and 27 of 114 units up to B1 are written, no culture shelves, as on 2026-11-15; Tamil is set aside for now (owner, 2026-11-06, in CLAUDE.md). The rest of this page is the audit and plan of 2026-11-15 as written. Earlier status: audit and plan of 2026-11-15. Owner instruction (2026-11-15): one session per language; this session owns Tamil (`ta`, tracker #354) and takes it as far toward completeness as is verifiable, "by delegating to agents": audit, then path units to A1 (B1 if time allows), then the other deliverables of [Plan-Language-Completeness](Plan-Language-Completeness.md). Tamil is on the second list (A1 minimum, first deck for sure; owner 2026-11-02 and 2026-11-06). The shape is that of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md), [Deck-Work-Queue-GU](Deck-Work-Queue-GU.md) and [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md). Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task. The conventions and validator traps of section 2 of the Kannada queue apply word for word (read Tamil for Kannada, `ta` for `kn`, `iso639_3: "tam"`).

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

## 4. Pause and resume plan (2026-11-16)

Owner directive via the parent (token budget): at most 4 language sessions at once; Tamil is paused. State at the pause:

| Item | State |
|---|---|
| Audit, queue, `Plan-Culture-Tamil` | on main |
| TA-110 Tamil engine | **merged** (#1488, tracker #1483); `python3 tools/transcribe.py ta "<text>"` is on main |
| Shared branch `decks/ta-a1-wave1` | pushed, at decks-live `f20a3094`, **no commits**; no PR open |
| Workers ta-gram (Sonnet), ta-script, ta-sent (Haiku) | all three stopped by the 5-hour API rate limit (HTTP 429, reset 21:30 UTC) before committing anything; no files written or pushed |

Engine findings for the builders: bare digits (௦ to ௯) give an empty IPA, and the aytam ஃ gives `ḵ` [x]; both are for a Sonnet to settle with the tool owner, never hand-written. Fourteen old cards write `ʧ` where the engine writes `tʃ` (ta-0022, 0158, 0200, 0213, 0217, 0219, 0223, 0240, 0250, 0269, 0293, 0294, 0316, 0325): a deck fix in the first wave.

**Resume, in this order** (same briefs as the 2026-11-15 session; the common brief is rebuilt from section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) plus this page; use the engine from main, no branch fetch needed):

1. Re-create or reuse `decks/ta-a1-wave1` (merge `origin/decks-live`).
2. Wave 1, parallel, one worktree each: ta-script (Haiku: `ta-script-vowels`, `-vowel-signs` for units 7 and 8, then consonants, Grantha, digits, reading; `alphabet` in the path; ids `ta-1000..1299`); ta-sent (Haiku: sentences decks for time, location, work, numbers-big, groceries, market, directions, transport, home, first-words; ids `ta-3000..3999`); ta-gram (Sonnet: grammar units 17 to 22, 27, 29 to 32, 34, 40 to 42, 45 modelled on the Telugu, Kannada and Bengali grammar decks; ids `ta-0400..0899`; each unit's `planned` becomes `decks` in its commit); the `ʧ` to `tʃ` fix on the 14 cards.
3. One PR to `decks-live`, one Sonnet review, merge on green ("Validate decks" and "Released app reads the decks").
4. Then in order: TA-120 notes and review-queue rows (owner directive: a note on every card with a real teachable point), TA-040 topics, TA-050 situations, TA-080 facts, culture, proverbs, multi-word and recommendations from `Plan-Culture-Tamil` (before dropping an item try every reachable source and record a one-line reason), TA-2xx readings, TA-111/112 narrow IPA last, then A2 and B1.

## 5. Progress, 2026-11-23

| Wave | PR | State |
|---|---|---|
| A1 wave 1 (6 script decks, 16 grammar units, 10 sentences decks) | #1710 | merged to decks-live, CI green (10 of 10 checks), one Sonnet review |
| A2 wave 1 (14 grammar units incl. registers, 20 word units with sentences decks, units 46 to 79) | #1714 | merged to decks-live, CI green, one Sonnet review |
| B1 wave (units 80 to 114: 13 grammar units, 22 word units) and culture (`ta-culture-1` to `-4`, creators) | to open | in progress on `decks/ta-b1-wave1` and `decks/ta-culture-wave1` |

Lessons carried into every brief: a word is one card once (grep the merged tree, other workers reserve ranges); a card's table row follows the card's dictionary lemma (en.wiktionary form); stem doubling and -வ- rules in the noun table are checked per row; no card refers to a later unit's card; path units without a theme deck do not end in `*`.
Still to do after B1: topics, situations, facts, proverbs, multi-word verbs, recommendations, reading decks, the `ʧ` to `tʃ` fix on 14 old cards, narrow IPA, review-queue rows kept current.

## 6. Status and exact resume plan, 2026-11-23 (rate limit, resets 07:40 UTC)

Merged to decks-live, each with CI green (10 of 10 checks) and one Sonnet review: #1710 A1; #1714 A2 (units 46 to 79); #1716 B1 (units 80 to 114: the path is complete to the B1 mark, 114 units built, none planned); #1717 culture (62 cards of 72) with `decks/creators/ta.yaml`; #1720 proverbs (60) and multi-word verbs (54 of 60) and the `ʧ` to `tʃ` fix; #1719 situations (10 sheets), facts (37), recommendations (20); #1721 topics (65).

| Open item | State | Resume |
|---|---|---|
| Culture 62 of 72 | `decks/ta-culture-wave2` exists, no commits (ta-culture2 hit the limit) | Re-run ta-culture2: add cards ta-6066..6069 (deck 2), ta-6112..6117 (deck 3), ta-6166..6169 (deck 4) from ta.wikisource (Kannan Pattu, Panchali Sabatham, the novels' own text), ta.wikiquote, archive.org; legacy items for Bharati and Vedanayagam Pillai from en.wikipedia. Wikimedia returned 429 twice: pace and back off |
| Topics nits (PR #1721 review) | merged without them | `ta-first-novel`: say "an early Tamil novel"; `ta-proverbs`: "the builder's own English"; add `ta-pronouns` and `ta-daily-life` decks to a topic; optional: `ta-idiomatic-verbs` level B1 |
| Narrow IPA | `tools/ta-phonetics` (0c6ac5654, one registry entry) waits for the parent to merge it; `decks/ta-phonetics-wave1` (d865ad290: 13 rules, `phonetic` on 3,236 cards, 0 invalid) waits for it | After the parent merges the registry entry and the last content PRs: merge `origin/decks-live` into the branch, run `derive_phonetic.py ta --bracket-unchanged --write` (only new cards fill), one PR, one review, CI |
| Reading decks | none built (about 60 word units named by the path have no `ta-en-reading-*`) | A wave on `decks/ta-readings-wave1`, one Sonnet worker per 20 units, each after its sentences deck exists; a reading deck has no reading for grammar units |
| Plan-word shortfall | six B1 units are a few words under their planned size (services 47 of 50, travel 57 of 60, health 59 of 60, opinions 54 of 55, technology 52 of 55, environment 52 of 55) | Optional top-up of unique words; `words:` in the path was raised for three units that exceeded theirs |
| Multi-word 54 of 60 | aspectual-compound is 14 of 20; the six plan headwords with no readable page were dropped (reasons in the queue) | Optional |
| Review queue | rows appended by every worker; `dropped:` rows are not card ids | Settled by a reviewer through the app |
| Professional | held (needs the owner) | none |

## 7. Progress, 2026-11-23 (after the resume)

Merged to decks-live since section 6, each with CI green (10 of 10 checks) and one Sonnet review: #1724 topics nits; #1725 narrow IPA (`ta-phonetics.yaml` with 13 rules, `phonetic` on 3,236 cards; the registry entry is #1722 on main); #1726 reading decks (67 decks, one passage each, for every word unit; grammar units have none).

| Open item | State |
|---|---|
| Culture top-up (10 cards) | `decks/ta-culture-wave2`, ta-culture2 resumed with the polite Wikimedia client |
| `phonetic` on cards added after #1725 | run `derive_phonetic.py ta --bracket-unchanged --write` once more after the culture top-up merges (new reading and culture cards have a broad `ipa` but no `phonetic`); one PR |
| Plan-word shortfall | six B1 units a few words under plan (services 47 of 50, travel 57 of 60, health 59 of 60, opinions 54 of 55, technology 52 of 55, environment 52 of 55); optional unique-word top-up |
| Multi-word 54 of 60, topics deck-level `ta-multiword-idiomatic` header level A2 | optional |
| Professional | held (needs the owner) |

## 8. Final state, 2026-11-23

Measured on `origin/decks-live` after #1728: path 114 of 114 units built to the B1 mark, 2,394 of 2,394 planned words, culture 72 of 72, 3,271 cards, `phonetic` on 3,254 of 3,254 cards that have a broad `ipa`, 482 files under `decks/ta/`. Merged this session, each with CI green and one Sonnet review: #1710, #1714, #1716, #1717, #1719, #1720, #1721, #1724, #1725, #1726, #1727, #1728 (the engine #1722 and the registry entry are on main).

Left, none needed for the app's B1 measure: multi-word verbs 54 of 60 (six plan headwords have no readable dictionary page); review-queue rows await a bilingual reviewer through the app; the `ta-8606` plural, `ta-8606` note and `ta-8600` gloss nits of #1728; an optional second pass on formal coinages `ta-8602` and `ta-8603` (synonyms of the loanword cards `ta-2110` and `ta-2100`); the professional section (empty `professions`, needs the owner); rerun `derive_phonetic.py ta --bracket-unchanged --write` after any later Tamil card is added.
