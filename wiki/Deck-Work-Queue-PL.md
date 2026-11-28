# Deck work queue: Polish A1 plan

Status (2026-11-28): owner orders: "A1 only, one at a time." and "Do all of them one by one." (Italian, German, Russian and Greek done; Polish is the last). Scope is Polish (`pl`, tracker #366) to the A1 mark of `pl-path.yaml` only, then stop (second-list languages other than Classical Sanskrit and Tamil go to A1 only, owner 2026-11-20; one language session at a time, owner 2026-11-17). No A2/B1, no genre decks (culture, proverbs, situations, topics, facts, recommendations), no other language. Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task; the conventions of section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) apply (read Polish for Kannada, `pl` for `kn`, `iso639_3: "pol"`). The shape is that of [Deck-Work-Queue-RU](Deck-Work-Queue-RU.md) (Slavic: cases, aspect, gender), without script units, and of [Deck-Work-Queue-DE](Deck-Work-Queue-DE.md) and [Deck-Work-Queue-IT](Deck-Work-Queue-IT.md) (Latin script).

State read from `origin/decks-live` and main's `tools/` on 2026-11-28.

## 1. Audit

| What | State |
|---|---|
| Language entry | `assets/languages.yaml`: `pl`, `iso639_3: pol`, Polski, script `latin`, family `slavic`, TTS `pl-PL`, icon P |
| decks-live | `pl-phrasebook` (cards `pl-0011..0030`), `pl-first-words` (10 cards `pl-0001..0010`), their English layers, `decks/pl/pl-path.yaml` with 87 units: unit 1 built (10 words), 86 planned, `alphabet: []`, genders `m f n`; no facts file, no `docs/review-queue/pl.md` |
| A1 mark | `pl-animals` (`milestone: A1`): 30 units to build: 25 theme units and 5 grammar units. Latin script: no script decks |
| Units to A1 | sound-differences, questions, pronouns, family, numbers-1-20, about-me, everyday-verbs, adverbs, quantities, describing, grammar gender, time, location, more-verbs, work, grammar present-tense, numbers-big, food, groceries, market, grammar cases-1 (nominative, accusative, locative), directions, transport, body, places, grammar be-verb, things, home, clothes, animals |
| Engine | none: no `pl` branch in `tools/transcribe.py`, no `pl` in `tools/phonetic_languages.yaml`, no `pl-phonetics.yaml`; existing `ipa` is hand-written; no `reading` field (Latin script) |
| Sources | kaikki.org Polish dump and en.wiktionary pages (CC BY-SA 4.0, one item per source); no NC source (owner) |

## 2. Findings that shape the plan

- **Engine first.** Every card's `ipa` is written by the repo's tools (owner, 2026-10-30). PL-110 adds `polish_ipa()` to `tools/transcribe.py` with the `pl` dispatch; stress is almost always penultimate, so a stress hint handles the exceptions (as Russian). Rules: digraphs sz cz rz dz dź dż ch, ś ć ź dź ń, i as softness mark before a vowel (ia -> ʲa/ja), nasal vowels ą ę (ɔ̃ ɛ̃ and their breakdown before stops), ó = u, y = ɨ, ł = w, final and cluster devoicing.
- **Nouns** carry gender (m, f, n; masculine animate or inanimate in a note); **verbs** give the aspect partner where a read source gives it. Stem changes (ręka/rękę/ręce, ó/o, ą/ę) are said in a note.
- **Source discipline.** Every card word is a headword of a read Wiktionary entry. Unverifiable rows go to `docs/review-queue/pl.md`.
- **Sentences** only from taught words and frames that can be cited; the source of every grammar table row is stated.

## 3. Task table

Ids (never reused): grammar units `pl-0400..0999` (60 per unit in path order), word units `pl-1300..3049` (70 per unit), sentences `pl-4000..4999`; highest in use at the start `pl-0030`.

| Id | Model | Branch | Spec |
|---|---|---|---|
| PL-110 | Sonnet | `tools/pl-transcribe` (PR to main) | `polish_ipa()` engine with stress hint, tests, the `pl` dispatch; check against existing cards; any validator change |
| PL-050 | Haiku | none (a report in the scratchpad) | candidate words per planned A1 theme from the kaikki dump: gloss, pos, gender, aspect partner, stress; shortfalls named |
| PL-100.. | Haiku (Sonnet specs the grammar tables) | `decks/pl-a1-wave1` | the 5 grammar units and 25 word units with layers; path entries move from `planned` to `decks` in the same commit |
| PL-150 | Haiku | rides on the wave | `docs/review-queue/pl.md` rows for every uncertain card |
| PL-160 | Sonnet | `decks/pl-phonetics-wave1` | `pl-phonetics.yaml`, the `pl` entry of `tools/phonetic_languages.yaml`, `derive_phonetic.py pl --bracket-unchanged --write` after the content merges |

## 4. Progress

2026-11-28: audit done, this page written; PL-110 and PL-050 launching.

2026-11-28: PL-110 merged, #1772 (`polish_ipa` engine; stress hint for non-penultimate words; no palatal mark before i, a glide j after k, g and the lip consonants; an affricate before one of the same place is one sound). PL-050 done (793 candidates, 25 themes; pronouns, quantities and places were short). Shared branch `decks/pl-a1-wave1`: five Haiku workers pl1 to pl5 wrote the 25 word units, the Sonnet builder PL-100 the 5 grammar units. No file was lost to stale indexes (workers merged before each push; the tree was checked after every push).

## 5. Final state, 2026-11-28

A1 stops here by the owner's order. Merged, each with CI green and one Sonnet review: #1772 (main, engine) and #1773 (decks-live: 25 word units, 5 grammar units with word and sentences decks, the path to the A1 mark, `docs/review-queue/pl.md`) and #1774 (decks-live, `decks/pl/pl-phonetics.yaml`, 16 rules, `phonetic` on 800 cards). 800 cards. The review of #1773 found English translations with the wrong article (an underwear, a wood, a glass, a aunt), comma-joined glosses, a wrong note for dwa/dwie, placeholder genders on plural-only nouns and misplaced stress marks; all repaired before the merge. The first CI run failed on `pos` values (`num`, `pron`, `prep`, `conj` are not allowed: `other` and `pronoun`). The review of #1774 found `l` before `i` or `j` marked apical against its source; fixed before the merge. 29 words were carded twice (grammar units and word units) and the later copies were removed.

Left for the owner: Polish speaker review of `docs/review-queue/pl.md` (composed frames such as "To jest X" and all grammar sentences; senses of homographs; perfective partners; stress exceptions; the narrow rules are the builder's from Wikipedia); verbs, adverbs, adjectives and numerals have no examples where no citable frame was read; the pronoun `to` is used as a base but has no card (and `im`, `was`, `ta`, `na` are not carded); pronouns, numbers 1 to 20, quantities and places are under their planned sizes; the 30 older phrasebook and first-words cards were regenerated by the engine (cześć and zobaczenia `tʂ`, Przepraszam and Pomocy stress, jeszcze, `z Polski` assimilation); sentences decks for word units; units 32 to 87 (A2 and B1) and every genre deck, out of scope. Branches `decks/pl-a1-wave1`, `decks/pl-phonetics-wave1` and `tools/pl-transcribe` are left for the owner to delete.

Lessons: the review's A-class findings were again English articles and glosses (check "a" against mass nouns and plural-only words); a stress hint must be applied by the engine, not by moving a mark in the string (a regeneration script that moved marks by vowel count put them inside syllables: caught by the review); `pos` allows only adj adv digit letter noun other particle phrase pronoun verb; a gloss from a candidate list must be read on the entry; the CI log of a failed validate job lists only the first errors in its tail, so fix a whole class (all `pos` values) at once.
