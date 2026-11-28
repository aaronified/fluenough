# Deck work queue: Italian A1 plan

Status (2026-11-27): owner orders: "A1 only, one at a time." and "Do all of them one by one." (Italian first, then German, Russian, Greek, Polish). Scope is Italian (`it`, tracker #358) to the A1 mark of `it-path.yaml` only, then stop (second-list languages other than Classical Sanskrit and Tamil go to A1 only, owner 2026-11-20; one language session at a time, owner 2026-11-17). No A2/B1, no genre decks (culture, proverbs, situations, topics, facts, recommendations), no other language. Rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task; the conventions and validator traps of section 2 of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md) apply word for word (read Italian for Kannada, `it` for `kn`, `iso639_3: "ita"`). The shape is that of [Deck-Work-Queue-SW](Deck-Work-Queue-SW.md), [Deck-Work-Queue-KO](Deck-Work-Queue-KO.md) and [Deck-Work-Queue-ML](Deck-Work-Queue-ML.md); the closest Romance worked examples are [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) and [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md).

State was read from `origin/decks-live` (PyYAML over `decks/it/**` and `it-path.yaml`) and from main's `tools/` and `assets/languages.yaml` on 2026-11-27.

## 1. Audit

| What | State |
|---|---|
| Language entry | `assets/languages.yaml`: `it`, `iso639_3: ita`, Italiano, script `latin`, family `romance`. No script decks (Latin) |
| decks-live | `it-phrasebook` (22 cards `it-0011..0031`), `it-first-words` (10 cards `it-0001..0010`), their English layers, `it-path.yaml` with 86 units: unit 1 built (10 words), 85 planned, `alphabet: []`; no facts file, no `docs/review-queue/it.md` |
| A1 mark | unit 32 (`it-animals`, `milestone: A1`): 31 units still to build (2 to 32): 25 theme units (690 planned words) and 6 grammar units |
| Units to A1 | 2 grammar sound-differences (and double-consonants), 3 questions, 4 pronouns, 5 family, 6 numbers-1-20, 7 about-me, 8 everyday-verbs, 9 adverbs, 10 quantities, 11 grammar articles and gender-number, 12 describing, 13 time, 14 location, 15 grammar be-verbs, 16 more-verbs, 17 work, 18 numbers-big, 19 food, 20 grammar present-regular, 21 groceries, 22 market, 23 directions, 24 grammar present-irregular, 25 transport, 26 body, 27 places, 28 things, 29 grammar prepositions, 30 home, 31 clothes, 32 animals |
| Engine | none: no `it` branch in `tools/transcribe.py`, no `it` in `tools/phonetic_languages.yaml`, no `it-phonetics.yaml`, 0 `phonetic`. The 32 existing broad `ipa` are hand-written |
| Sources | kaikki.org Italian dump and en.wiktionary pages (CC BY-SA 4.0, one item per source); no NC source (owner) |

## 2. Findings that shape the plan

- **Engine first.** Every card's `ipa` is written by the repo's tools, never by hand (owner, 2026-10-30). IT-110 adds `italian_ipa()` to `tools/transcribe.py` and the `it` dispatch; the 32 existing cards are checked against it and a disagreement becomes a review-queue row, never a silent edit. Italian stress and the openness of e and o are lexical: the engine states its limits and its mechanism in its docstring.
- **Source discipline.** Every card word is a headword of a read Wiktionary entry. A gloss written from memory is not allowed. A word with no readable source is a shortfall listed in `docs/review-queue/it.md` for an Italian speaker. Gender and irregular forms go in notes.
- **Sentences.** The biggest source of review errors in earlier languages was example sentences without a verified frame: build sentences only from taught words and frames that can be cited; state the source of every grammar table row.

## 3. Task table

Ids (never reused, ascending inside a task; highest in use `it-0031`): grammar `it-0400..0899` (100 per unit: sound-differences 0400, articles-gender 0500, be-verbs 0600, present-regular 0700, present-irregular 0800, prepositions 0850 for 49), word units `it-1300..3049` (70 per unit in path order: questions 1300, pronouns 1370, family 1440, numbers-1-20 1510, about-me 1580, everyday-verbs 1650, adverbs 1720, quantities 1790, describing 1860, time 1930, location 2000, more-verbs 2070, work 2140, numbers-big 2210, food 2280, groceries 2350, market 2420, directions 2490, transport 2560, body 2630, places 2700, things 2770, home 2840, clothes 2910, animals 2980), sentences `it-4000..4999`.

| Id | Model | Branch | Spec |
|---|---|---|---|
| IT-110 | Sonnet | `tools/it-transcribe` (PR to main) | `italian_ipa()` engine, its tests, the `it` dispatch; check against the 32 existing cards; registry entry measured against Wiktionary |
| IT-050 | Haiku | none (a report in the scratchpad) | candidate words per planned A1 theme from the kaikki dump, with gloss, part of speech, gender; shortfalls named |
| IT-100.. | Haiku (Sonnet specs the grammar tables) | `decks/it-a1-wave1` | the 6 grammar units and 25 word units with layers; path entries move from `planned` to `decks` in the same commit |
| IT-130.. | Haiku | `decks/it-a1-wave1` | sentences decks for word units with enough taught words |
| IT-150 | Haiku | rides on the wave | `docs/review-queue/it.md` rows for every uncertain card |
| IT-160 | Sonnet | `decks/it-phonetics-wave1` | `it-phonetics.yaml` and the `it` entry of `tools/phonetic_languages.yaml`, `derive_phonetic.py it --bracket-unchanged --write` after the content merges |

## 4. Progress

2026-11-27: audit done, this page written; IT-110 and IT-050 launched.

2026-11-28: IT-110 merged, #1755 (`italian_ipa` engine; stress by written accent, penultimate default, a hint argument and a small table of everyday words for openness; the review found six wrong test values and an elision bug, all fixed before the merge). IT-050 done (690 candidates, all 25 themes full; numbers-big extras miliardo, centinaio, migliaio to be dropped). Shared branch `decks/it-a1-wave1` created; Haiku workers it101 to it105 (word units, five each) and the Sonnet grammar builder IT-100 (six grammar units) are building and pushing after every unit. Path edits (IT-120) come last, by the architect, so that workers never conflict on `it-path.yaml`. No sentences decks for word units (no read source of Italian sentences; examples are composed from verified frames and queued).

## 5. Final state, 2026-11-28

A1 stops here by the owner's order. Merged, each with CI green and one Sonnet review: #1755 (main, `italian_ipa` engine), #1756 on decks-live (25 word units, 6 grammar units with their words and sentences decks, 4 set cards, the path to unit 32, `docs/review-queue/it.md`, 19 words re-added after the first pass dropped them) and #1757 on decks-live (`decks/it/it-phonetics.yaml`, `phonetic` on 823 cards). The review of #1756 found wrong frames for plural-only nouns, an article rule contradicting the grammar unit, a wrong verb form and non-idiomatic age; all repaired before the merge. The review of #1757 found dental marks on geminate affricates; repaired.

Left for the owner: Italian speaker review of `docs/review-queue/it.md` (composed examples throughout, stress and open e/o of the engine, the velar nasal and vowel-length narrow rules); sentences decks for word units (no read source of Italian sentences); object clitics (unit 36, A2); units 33 to 87 (A2 and B1) and every genre deck, out of scope. Word units are under their planned sizes where the Wiktionary extract or untaught example words limited them. Branches `decks/it-a1-wave1`, `decks/it-phonetics-wave1` and `tools/it-transcribe` are left for the owner to delete.

Lessons: the engine cannot know lexical stress, so a hint pass from Wiktionary-marked forms must run over every card (IT-140); a candidate list built by keyword must be checked against the entry that carries the learner sense (a fifth of the first drops were adjective-first entries); templated example frames need a plural-only and uncountable noun check; push the shared branch after every worker commit (a container restart lost five workers' unpushed work once); `prep` and `num` are not allowed `pos` values (use `other`), and a homograph note needs a partner card.
