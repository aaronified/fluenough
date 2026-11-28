# Deck work queue: Modern Greek A1 plan

Status (2026-11-28): owner orders: "A1 only, one at a time." and "Do all of them one by one." (Italian, German and Russian done; Greek next, then Polish). Scope is Modern Greek (`el`, tracker #368) to the A1 mark of `el-path.yaml` only, then stop (second-list languages other than Classical Sanskrit and Tamil go to A1 only, owner 2026-11-20; one language session at a time, owner 2026-11-17). No A2/B1, no genre decks, no other language. The ancient Greek varieties (Classical, Koine, Archaic, Mycenaean) are separate ancient languages (owner, 2026-11-27) and are not touched. Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task; the conventions of section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) apply (read Greek for Kannada, `el` for `kn`, `iso639_3: "ell"`). The shape is that of [Deck-Work-Queue-RU](Deck-Work-Queue-RU.md) (non-Latin script plus lexical stress), with the script units of [Deck-Work-Queue-KO](Deck-Work-Queue-KO.md).

State read from `origin/decks-live` and main's `tools/` on 2026-11-28.

## 1. Audit

| What | State |
|---|---|
| Language entry | `assets/languages.yaml`: `el`, `iso639_3: ell`, Ελληνικά, script `greek`, family `hellenic`, TTS `el-GR` |
| decks-live | `el-phrasebook` (41 cards), `el-first-words`, English layers, `decks/el/el-path.yaml` with 87 units: unit 1 built (10 words), 86 planned, `alphabet: []`, genders `m f n`; no script decks, no facts file, no `docs/review-queue/el.md` |
| A1 mark | unit 32 (`el-animals`, `milestone: A1`): 31 units to build (2 to 32): 24 theme units and 7 grammar or script units |
| Units to A1 | 2 sound-differences, 3 questions, 4 pronouns, 5 family, 6 numbers-1-20, 7 script letters, 8 script stress-marks, 9 about-me, 10 everyday-verbs, 11 adverbs, 12 quantities, 13 describing, 14 grammar articles-gender, 15 time, 16 location, 17 more-verbs, 18 work, 19 grammar present, 20 numbers-big, 21 food, 22 groceries, 23 market, 24 grammar cases-1 (nominative, accusative), 25 directions, 26 transport, 27 body, 28 places, 29 grammar be-verb, 30 things, 31 home, 32 clothes, 33 animals (the A1 milestone is on `el-animals`; count by id, not by this list) |
| Engine | none: no `el` branch in `tools/transcribe.py`, no `el` in `tools/phonetic_languages.yaml`, no `el-phonetics.yaml`; existing `ipa` and `reading` are hand-written. Reading scheme of the existing cards: Latin with the acute for the stress (naí, óchi, efcharistó, ya for γεια, ch for χ), kept unchanged |
| Validator | `greek` is in `NO_READING` and the script list, but not in `_SCRIPT_BLOCK`; a Greek core's own script and Greek's two blocks (U+0370..U+03FF) need the check Cyrillic got in #1766 |
| Sources | kaikki.org Greek dump and en.wiktionary pages (CC BY-SA 4.0); no NC source (owner) |

## 2. Findings that shape the plan

- **Engine first** (owner, 2026-10-30: every card's IPA is written by the tools). EL-110 adds `greek_ipa()` to `tools/transcribe.py` with the `el` dispatch; stress comes from the written tonos, so no hint is needed. Rules to check: velars palatalised before front vowels (κ γ χ ɣ before e i), γ/ν/μπ/ντ/γκ variants, voicing before voiced consonants (σ before μ β γ δ ζ ν ρ), digraphs αι ει οι ου υι αυ ευ, diaeresis, ΐ ΰ.
- **Script units** (7 and 8) go in the path's `alphabet:` list, as Korean's and Russian's.
- **Nouns** carry gender and article; **verbs** their conjugation class; stress is on every polysyllabic word from a read source.
- **Source discipline.** Every card word is a headword of a read Wiktionary entry. Unverifiable rows go to `docs/review-queue/el.md`.
- **Sentences** only from taught words and frames that can be cited; the source of every grammar table row is stated.

## 3. Task table

Ids (never reused): script `el-0300..0399`, grammar units `el-0400..0999`, word units `el-1300..3049`, sentences `el-4000..4999`; highest in use at the start: read from decks-live.

| Id | Model | Branch | Spec |
|---|---|---|---|
| EL-110 | Sonnet | `tools/el-transcribe` (PR to main) | `greek_ipa()` engine, tests, `el` dispatch; check against existing cards; validator: Greek own script |
| EL-050 | Haiku | none (scratchpad report) | candidate words per planned A1 theme from the kaikki dump |
| EL-070 | Haiku | `decks/el-a1-wave1` | script decks and layers; path `alphabet` |
| EL-100.. | Haiku (Sonnet specs the grammar tables) | `decks/el-a1-wave1` | grammar units and word units with layers; path entries move from `planned` to `decks` in the same commit |
| EL-150 | Haiku | rides on the wave | `docs/review-queue/el.md` |
| EL-160 | Sonnet | `decks/el-phonetics-wave1` | `el-phonetics.yaml`, the `el` entry of `tools/phonetic_languages.yaml`, `derive_phonetic.py el --bracket-unchanged --write` |

## 4. Progress

2026-11-28: audit done, this page written; EL-110 and EL-050 launching.
