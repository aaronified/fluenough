# Deck work queue: Malayalam A1 plan

Status (2026-11-23): owner order: "Do malayalam A1 and then stop. Other languages will be left for next week." Scope is Malayalam (`ml`, tracker #355) to the A1 mark of `ml-path.yaml` only, then stop. No B1, no genre decks (culture, proverbs, situations, topics, facts, recommendations, readings) unless already built. Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task; the conventions and validator traps of section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) apply word for word (read Malayalam for Kannada, `ml` for `kn`, `iso639_3: "mal"`). The shape is that of [Deck-Work-Queue-TA](Deck-Work-Queue-TA.md).

State was read from `origin/decks-live` (371e50d67) with PyYAML over every `decks/ml/**` file and `ml-path.yaml`, and from the old draft PR #1062 (branch `decks/ml-a1`, 2026-11-07).

## 1. Audit

| What | State |
|---|---|
| decks-live | `ml-phrasebook` (20 cards), `ml-first-words` (10), their English layers, `ml-path.yaml` with 118 units, 1 built, rest planned. `alphabet: []`. No script decks, no grammar decks |
| A1 mark | unit 46 (`ml-grammar-future`, `milestone: A1`): 46 units, 686 planned words |
| Draft PR #1062 | "6,324 changed files" is a stale base, not content: the Malayalam part is 107 files (`decks/ml/**` only), card ids `ml-0001..ml-0738`, which extend decks-live's `ml-0001..0030` with the same content for those ids. 689 of 693 cards have a `reading` and broad `ipa` identical to `tools/transcribe.py ml` output (the other 4 are phrasebook cards, below) |
| Decision | Salvage: its `decks/ml/**` is checked out over a fresh branch `decks/ml-a1-wave1` from decks-live (not merged as is; PR #1062 stays a draft and is left for the owner to close). Its `ml-path.yaml` is not taken (old base): the planned-to-built edits are redone on decks-live's path |

### A1 gap, from the path (units 1 to 46)

| What | Units |
|---|---|
| Built on the branch (word units) | 1 to 6, 10 to 17, 24 to 27, 29, 34, 36 to 40, 44, 45 (557 of 686 planned words) |
| Built, grammar | be and have (21), present (22), demonstratives (23), needs (28), likes (32), continuous (35), future (46); their files are `ml-grammar-*` (the present deck is `ml-grammar-present`, the path says `ml-grammar-verb-present`) |
| Script decks built | vowels, consonants, vowel signs, chillu, conjuncts; the path's `alphabet` and units 7 to 9 are not yet edited |
| Grammar, not built | 18 noun forms, 19 conjunctions (8 words), 20 pronoun forms, 30 noun classes, 31 questions, 33 sentences, 41 differences (6), 42 postpositions (2), 43 gender-number (10) |
| Sentences decks built | pronouns, verbs, quantities, describing, more-verbs, food, body, places, things, clothes, animals, noun-forms |
| Sentences decks missing | questions, family, numbers-1-20, about-me, adverbs, time, location, work, numbers-big, groceries, market, directions, transport, home (those with too few earlier words are listed, not forced) |
| Words under plan | pronouns 17 of 33, verbs 15 of 33, adverbs 25 of 50, places 19 of 42, food 47 of 64, things 30 of 39, describing 31 of 40, time 12 of 18, quantities 23 of 30, family 18 of 25, sound-differences 8 of 12, and a few more by 1 to 6 |
| Narrow IPA | no `ml` entry in `tools/phonetic_languages.yaml`, no `ml-phonetics.yaml`, 0 `phonetic` |
| Engine | `malayalam()` in `tools/transcribe.py` exists |

Phrasebook readings to fix (shipped cards, ids unchanged): ml-0015, ml-0021, ml-0022 write `eṉikku` where the engine writes `enikk` (ṉ is wrong for ന്), and ml-0019 writes `śauccālayaṁ` where the engine writes `śaucālayaṁ` (ശൗചാലയം has one ച).

## 2. Task table

Ids reserved (never reused, ascending inside a task): grammar words `ml-0739..0999`, new vocab top-ups `ml-1000..1999`, sentences `ml-3000..3999`.

| Id | Model | Branch | Spec |
|---|---|---|---|
| ML-000 | Sonnet architect (this session) | `decks/ml-a1-wave1` | salvage commit, path edits, one PR to decks-live, CI reading |
| ML-110..118 | Haiku (Sonnet specs the tables) | `decks/ml-a1-wave1` | the 9 grammar units, with their layers; path entries move from `planned` to `decks` in the same commit |
| ML-130 | Haiku | `decks/ml-a1-wave1` | the missing sentences decks, 2 to 3 confusables per card |
| ML-140 | Haiku | `decks/ml-a1-wave1` | top up word units to their planned size; only words with a read dictionary page; shortfalls left are listed |
| ML-150 | Haiku | rides on the wave | review-queue rows (`docs/review-queue/ml.md`) for every uncertain card |
| ML-160 | Sonnet design, then tools | `tools/ml-phonetics` (main), `decks/ml-phonetics-wave1` | registry entry, `ml-phonetics.yaml`, `derive_phonetic.py ml --bracket-unchanged --write` after the content has merged |

## 3. Progress

(to be filled as the waves merge)
