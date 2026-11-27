# Deck work queue: Swahili A1 plan

Status (2026-11-27): owner order: "A1 only, one at a time." Scope is Swahili (`sw`, tracker #384) to the A1 mark of `sw-path.yaml` only, then stop (second-list languages other than Classical Sanskrit and Tamil go to A1 only, owner 2026-11-20; one language session at a time, owner 2026-11-17; Swahili replaced Afrikaans, owner 2026-11-20). No A2/B1, no genre decks (culture, proverbs, situations, topics, facts, recommendations), no other language. Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task; the conventions and validator traps of section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) apply word for word (read Swahili for Kannada, `sw` for `kn`, `iso639_3: "swh"`). The shape is that of [Deck-Work-Queue-SAT](Deck-Work-Queue-SAT.md), [Deck-Work-Queue-ML](Deck-Work-Queue-ML.md) and [Deck-Work-Queue-TA](Deck-Work-Queue-TA.md).

State was read from `origin/decks-live` (PyYAML over `decks/sw/**` and `sw-path.yaml`) and from main's `tools/` and `assets/languages.yaml` on 2026-11-27.

## 1. Audit

| What | State |
|---|---|
| Language entry | `assets/languages.yaml`: `sw`, `iso639_3: swh`, name Swahili, own name Kiswahili, script `latin`, family `niger_congo`. No script decks (Latin) |
| decks-live | `sw-phrasebook` (20 cards `sw-0011..0030`), `sw-first-words` (10 cards `sw-0001..0010`), their English layers, `sw-path.yaml` with 84 units: unit 1 built (10 words), 83 planned, `alphabet: []` |
| A1 mark | unit 31 (`sw-animals`, `milestone: A1`): 31 units, 25 theme units (690 planned words) and 5 grammar units (sound-differences, noun-classes, class-agreement, verb-slots, present-tense), plus unit 1 |
| Units to A1 | 2 sound-differences (grammar), 3 questions, 4 pronouns, 5 family, 6 numbers-1-20, 7 about-me, 8 everyday-verbs, 9 adverbs, 10 quantities, 11 describing, 12 grammar noun-classes, 13 time, 14 location, 15 more-verbs, 16 work, 17 grammar class-agreement, 18 numbers-big, 19 food, 20 groceries, 21 market, 22 grammar verb-slots, 23 directions, 24 transport, 25 body, 26 places, 27 grammar present-tense, 28 things, 29 home, 30 clothes, 31 animals |
| Engine | none: no `sw` branch in `transcribe()`; no `sw` in `tools/phonetic_languages.yaml`; no `sw-phonetics.yaml`; 0 `phonetic`. The 30 existing broad `ipa` are hand-written and some are wrong by the engine's standard (for example `hii` written `hi`) |
| Sources | kaikki.org Swahili dump and en.wiktionary pages (CC BY-SA 4.0, one item per source); public-domain grammars (Steere, Madan) for grammar tables; no NC source (owner) |
| Facts file, review queue | no `sw-facts.yaml` (a genre deck, out of scope), no `docs/review-queue/sw.md` (created by SW-150) |

## 2. Findings that shape the plan

- **Engine first.** Every card's `ipa` is written by the repo's tools, never by hand (owner, 2026-10-30). SW-110 adds `swahili()` to `tools/transcribe.py` and the `sw` dispatch; the 30 existing cards are checked against it and a disagreement becomes a review-queue row, never a silent edit.
- **Noun classes.** Every noun carries its class pair in a note (m-wa, ki-vi, n-n, m-mi, ji-ma, u-n, pa/ku/mu) and the concord it takes. Grammar units are taught only from sources read to the page; a table row that cannot be checked is left out and queued.
- **Source discipline.** Every card word is a headword of a read Wiktionary entry (or another named source read on the page). A gloss written from memory is not allowed. A word with no readable source is a shortfall listed in `docs/review-queue/sw.md` for a Swahili speaker.
- **Stress.** Swahili stress is penultimate and not marked in writing; the broad `ipa` marks it only if the repo's convention for other languages does (decided in SW-110, recorded here).
- **Stress decision (SW-110, 2026-11-27).** `swahili_ipa` (PR #1750) follows the Spanish and Toki Pona convention: the broad `ipa` marks penultimate stress with ˈ on every word of two or more syllables. A word-initial m or n before a non-prenasalising consonant (mtu, nchi) counts as a syllable but is written as a plain m or n. The 30 existing hand-written cards all differ from the engine, almost only by the missing stress mark; other differences: sw-0007 `ʤ` ligature, sw-0017 dh is `ð`, sw-0021 `sjelewi` is `sieˈlewi`, sw-0022/0023/0029 carry a stray `ː`, sw-0025/0029 `ŋg` is `ŋɡ`, `ɛ` is `e`, `r` is `ɾ`, sw-0027 `tʃo` is `ˈtʃoo`. They are re-derived by the engine in the wave, never edited by hand; the full list is in the PR description.

## 3. Task table

Ids (never reused, ascending inside a task): grammar `sw-0400..0899` (noun-classes 0400, agreement 0500, verb-slots 0600, present 0700, sound-differences 0800, 100 each), word units `sw-1300..3049` (70 per unit in path order: questions 1300, pronouns 1370, family 1440, numbers-1-20 1510, about-me 1580, everyday-verbs 1650, adverbs 1720, quantities 1790, describing 1860, time 1930, location 2000, more-verbs 2070, work 2140, numbers-big 2210, food 2280, groceries 2350, market 2420, directions 2490, transport 2560, body 2630, places 2700, things 2770, home 2840, clothes 2910, animals 2980), sentences `sw-4000..4999`.

| Id | Model | Branch | Spec |
|---|---|---|---|
| SW-110 | Sonnet | `tools/sw-transcribe` (PR to main) | `swahili()` engine, its tests, the `sw` dispatch; check against the 30 existing cards |
| SW-050 | Haiku | none (a report in the scratchpad) | candidate words per planned A1 theme from the kaikki dump, with gloss, part of speech, class and sound; shortfalls named |
| SW-100.. | Haiku (Sonnet specs the grammar tables) | `decks/sw-a1-wave1` | the 5 grammar units and 25 word units with layers; path entries move from `planned` to `decks` in the same commit |
| SW-130.. | Haiku | `decks/sw-a1-wave1` | sentences decks for word units with enough taught words |
| SW-150 | Haiku | rides on the wave | `docs/review-queue/sw.md` rows for every uncertain card |
| SW-160 | Sonnet | `decks/sw-phonetics-wave1` | `sw-phonetics.yaml` and the `sw` entry of `tools/phonetic_languages.yaml`, `derive_phonetic.py sw --bracket-unchanged --write` after the content merges |

## 4. Progress

2026-11-27: audit done, this page written.

2026-11-27 (later): SW-110 merged, #1750 (`swahili_ipa` engine; penultimate stress marked, no syllabic-nasal mark). SW-050 and SW-060 (curated lists, 690 words, all 25 themes full; padded: adverbs, numbers-big, quantities; days of the week dropped as proper nouns) done. Shared branch `decks/sw-a1-wave1` created; workers SW-101 to SW-105 (Haiku, word units) and SW-100 (Sonnet, five grammar units) are building and pushing after every commit. Path edits (SW-120) come last, by the architect's task, so that workers never conflict on `sw-path.yaml`.
