# Deck work queue: German A1 plan

Status (2026-11-28, final state in section 5): owner orders: "A1 only, one at a time." and "Do all of them one by one." (Italian done; German next, then Russian, Greek, Polish). Scope is German (`de`, tracker #361) to the A1 mark of `de-path.yaml` only, then stop (second-list languages other than Classical Sanskrit and Tamil go to A1 only, owner 2026-11-20; one language session at a time, owner 2026-11-17). No A2/B1, no genre decks (culture, proverbs, situations, topics, facts, recommendations), no other language. Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task; the conventions and validator traps of section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) apply word for word (read German for Kannada, `de` for `kn`, `iso639_3: "deu"`). The shape is that of [Deck-Work-Queue-IT](Deck-Work-Queue-IT.md), the closest worked example, with [Deck-Work-Queue-SW](Deck-Work-Queue-SW.md), [Deck-Work-Queue-KO](Deck-Work-Queue-KO.md), [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) and [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md).

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

2026-11-28: DE-110 merged, #1758 (`german_ipa` engine; the review found eight blocking rule errors, stress inside consonant onsets, ç read as x after diphthongs, be-/ge-/er- prefix guards, -tag vowels, all repaired). DE-050 done (722 of 735 candidates, all 24 themes). Shared branch `decks/de-a1-wave1`: Haiku workers de1 to de6 (four word units each) and the Sonnet grammar builder DE-100 (15 grammar units) pushed after every unit; the architect did the path edits and the review queue last. Engine follow-ups #1760 (é, letter compounds, a respell table for loanwords) and #1761 (stress before a whole initial cluster) merged.

## 5. Final state, 2026-11-28

A1 stops here by the owner's order. Merged, each with CI green: #1758, #1760, #1761 and #1762 (main: engine, loanword respells, initial clusters, `de` registry entry rules-only), #1759 on decks-live (24 word units, 15 grammar units with words and sentences decks, the path to unit 40, `docs/review-queue/de.md`) and #1763 (decks-live: `decks/de/de-phonetics.yaml`, 13 rules, `phonetic` on 1,081 cards). One Sonnet review each for #1758, #1759, #1760 and #1763; #1761 and #1762 (about 20 and 10 lines) were read by the architect, not by a separate review. The review of #1759 found Rind, Schwein and Kalb taught as the meats, objectless verb examples (besuchen, treffen, kommen), a wrong Rat plural, a Gleis gloss, the aber/sondern wording, an st/sp rule that was too broad and 39 nouns missing their plural entry; all repaired before the merge. The review of #1763 found the -chen diminutive read as n̩, a pf affricate across ab+fahren, an unsourced n-velar rule and inconsistent aspiration and glottal stops; all repaired.

Left for the owner: German speaker review of `docs/review-queue/de.md` (about 155 rows: stiff composed examples such as time nouns in a where-frame, doubtful plurals, 66 cards whose broad IPA differs from Wiktionary, the narrow rules); the hint pass covers only words Wiktionary has (983 of 1,166 forms; the unhinted engine agrees with Wiktionary on 79.2% of single-word cards); E-Mail, U-Bahn and S-Bahn (the validator cannot split hyphenated words), Café and a few stopped cards (wohin, womit, gestern, holen, gefallen, abbiegen, überqueren, ihr, man, sich); no question-word set card or `picture_ask`; pronouns has 13 of 20 planned words; example frame words are base entries, not refs; sentences decks for word units; units 41 to 111 (A2 and B1) and every genre deck, out of scope. Branches `decks/de-a1-wave1`, `decks/de-phonetics-wave1`, `tools/de-transcribe`, `tools/de-transcribe-2`, `tools/de-transcribe-3` and `tools/de-phonetic-registry` are left for the owner to delete.

Lessons: the brief's pos list must be copied from the validator (`adj`, `adv`; I wrote adjective and adverb and had to fix 98 cards); a hyphenated word cannot be a card; a draft PR runs no CI and each push cancels the running one, so push the shared branch in bursts and read CI once the workers are done; review fixes can themselves break the validator (sourced examples need bases): read CI after the fix round; a follow-up engine edit can land in the wrong language's function (Italian's `_it_stress`): read the diff.

