# Deck work queue: German A1 plan

Status (2026-11-28): owner orders: "A1 only, one at a time." and "Do all of them one by one." (Italian done; German next, then Russian, Greek, Polish). Scope is German (`de`, tracker #361) to the A1 mark of `de-path.yaml` only, then stop (second-list languages other than Classical Sanskrit and Tamil go to A1 only, owner 2026-11-20; one language session at a time, owner 2026-11-17). No A2/B1, no genre decks (culture, proverbs, situations, topics, facts, recommendations), no other language. Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task; the conventions and validator traps of section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) apply word for word (read German for Kannada, `de` for `kn`, `iso639_3: "deu"`). The shape is that of [Deck-Work-Queue-IT](Deck-Work-Queue-IT.md), the closest worked example, with [Deck-Work-Queue-SW](Deck-Work-Queue-SW.md), [Deck-Work-Queue-KO](Deck-Work-Queue-KO.md), [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) and [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md).

State was read from `origin/decks-live` (PyYAML over `decks/de/**` and `decks/de/de-path.yaml`) and from main's `tools/` and `assets/languages.yaml` on 2026-11-28.

## 1. Audit

| What | State |
|---|---|
| Language entry | `assets/languages.yaml`: `de`, `iso639_3: deu`, script `latin`, TTS `de-DE`. No script decks (Latin) |
| decks-live | `de-phrasebook` (20 cards `de-0011..0030`), `de-first-words` (10 cards `de-0001..0010`), their English layers, `decks/de/de-path.yaml` with 111 units: unit 1 built (10 words), 110 planned, `alphabet: []`, `genders: 3`; no facts file, no `docs/review-queue/de.md` |
| A1 mark | unit 40 (`de-help`, `milestone: A1`): 39 units still to build (2 to 40): 24 theme units and 15 grammar units |
| Units to A1 | 2 grammar sound-differences, 3 questions, 4 addressing, 5 pronouns, 6 family, 7 numbers-1-20, 8 about-me, 9 everyday-verbs, 10 adverbs, 11 quantities, 12 describing, 13 location, 14 more-verbs, 15 grammar articles-gender+nominative, 16 grammar plural, 17 grammar sein-haben, 18 grammar present-regular, 19 grammar present-irregular (stem change), 20 grammar word-order (verb-second, questions), 21 grammar negation (nicht, kein), 22 grammar accusative, 23 grammar possessives, 24 work, 25 numbers-big, 26 market, 27 groceries, 28 food, 29 grammar modals, 30 transport, 31 directions, 32 grammar dative, 33 grammar prepositions (accusative, dative), 34 body, 35 places, 36 home, 37 grammar coordinating conjunctions, 38 time, 39 grammar separable verbs, 40 help |
| Engine | none: no `de` branch in `tools/transcribe.py`, no `de` in `tools/phonetic_languages.yaml`, no `de-phonetics.yaml`, 0 `phonetic`. The 30 existing broad `ipa` are hand-written (stress marks missing: `fɛɐ̯ʃteːə`) |
| Sources | kaikki.org German dump and en.wiktionary pages (CC BY-SA 4.0, one item per source); no NC source (owner) |

## 2. Findings that shape the plan

- **Engine first.** Every card's `ipa` is written by the repo's tools, never by hand (owner, 2026-10-30). DE-110 adds `german_ipa()` to `tools/transcribe.py` and the `de` dispatch; the 30 existing cards are checked against it and a disagreement becomes a review-queue row, never a silent edit. German stress (prefixed, foreign and separable-prefix words), vowel length before consonant clusters and schwa elision are lexical: the engine states its limits in its docstring, takes a hint argument, and a Wiktionary-hint pass (as Italian IT-140) runs over every card.
- **Nouns.** Every noun carries its gender (`m`, `f`, `n`) and its plural from a read source; a noun with a plural-only, uncountable or irregular plural says so in a note. A base that changes its stem (umlaut plurals, ablaut and stem-changing verbs) says so in the note.
- **Verbs.** The lemma is the infinitive; a separable verb names its prefix in a note; a stem-changing verb gives its du/er forms.
- **Source discipline.** Every card word is a headword of a read Wiktionary entry. A gloss written from memory is not allowed. A word with no readable source is a shortfall listed in `docs/review-queue/de.md` for a German speaker.
- **Sentences.** The biggest source of review errors in earlier languages was example sentences without a verified frame: build sentences only from taught words and frames that can be cited; state the source of every grammar table row. Grammar units use only words earlier on the path teach (unit order matters: a grammar unit placed before a word it needs is a path problem to report, not a card to invent).

## 3. Task table

Ids (never reused, ascending inside a task; highest in use `de-0030`): grammar units `de-0400..1299`, 60 per unit in path order (sound-differences 0400, articles-gender 0460, plural 0520, sein-haben 0580, present-regular 0640, present-irregular 0700, word-order 0760, negation 0820, accusative 0880, possessives 0940, modals 1000, dative 1060, prepositions 1120, conjunctions 1180, separable-verbs 1240); word units `de-1300..2979`, 70 per unit in path order (questions 1300, addressing 1370, pronouns 1440, family 1510, numbers-1-20 1580, about-me 1650, everyday-verbs 1720, adverbs 1790, quantities 1860, describing 1930, location 2000, more-verbs 2070, work 2140, numbers-big 2210, market 2280, groceries 2350, food 2420, transport 2490, directions 2560, body 2630, places 2700, home 2770, time 2840, help 2910); sentences `de-4000..4999`.

| Id | Model | Branch | Spec |
|---|---|---|---|
| DE-110 | Sonnet | `tools/de-transcribe` (PR to main) | `german_ipa()` engine with hint, its tests, the `de` dispatch; check against the 30 existing cards; registry entry measured against Wiktionary |
| DE-050 | Haiku | none (a report in the scratchpad) | candidate words per planned A1 theme from the kaikki dump, with gloss, part of speech, gender, plural, sources; shortfalls named |
| DE-100.. | Haiku (Sonnet specs the grammar tables) | `decks/de-a1-wave1` | the 15 grammar units and 24 word units with layers; path entries move from `planned` to `decks` in the same commit |
| DE-150 | Haiku | rides on the wave | `docs/review-queue/de.md` rows for every uncertain card |
| DE-160 | Sonnet | `decks/de-phonetics-wave1` | `de-phonetics.yaml` and the `de` entry of `tools/phonetic_languages.yaml`, `derive_phonetic.py de --bracket-unchanged --write` after the content merges |

## 4. Progress

2026-11-28: audit done, this page written; DE-110 and DE-050 launching.
