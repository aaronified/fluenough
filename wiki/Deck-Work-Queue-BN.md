# Deck work queue: Bengali completion plan

**Status 2026-11-21:** Bengali is Complete on the app's completeness measure (every planned word unit through B1 written, grammar topics and culture shelves full). What follows is the plan and audit of 2026-11-14 to 2026-11-17, kept as written: where it says something is missing or not built, the measure is the newer reading. Review status is not part of the measure.

Status (2026-11-17: section 10 is the close-out plan for the owner directive of the same day; 2026-11-15, after the BN wave): the plan below was built and merged to `decks-live` in 14 pull requests, #1401 to #1458; see section 9 for what is done, what is short and what remains. The rest of this page is the original plan of 2026-11-15, kept as written: its counts and gap lists are the state before the wave. Original status: planning output of 2026-11-15. Nothing here was built, run or pushed. The state was read from `origin/decks-live` (c57783c5, 2026-11-15) with PyYAML over every `decks/bn/*.yaml` and `decks/bn/en/*.yaml`, the path, `decks/sections.yaml`, `decks/creators`, `decks/recommendations`, `docs/review-queue/bn.md`, `tools/phonetic_languages.yaml` and `decks/bn/bn-phonetics.yaml` (the audit scripts read, they did not run the validator or the tests). Task ids: `BN-001` to `BN-069`. Reserved id ranges: `bn-5000` to `bn-6349` (section 2). Highest bn id in use: `bn-4554` on a card, `bn-4560` on a reading question (the two share one namespace); `bn-4561` to `bn-4999` stay free for repairs. Blockers: none (BL-1 and BL-2 of [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) section 4 are closed; every tool a task needs is on `main`).

This page follows the shape of [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) and obeys the rules of the [Deck-Work-Queue](Deck-Work-Queue.md). It fills the Bengali column of the grid of [Plan-Language-Completeness](Plan-Language-Completeness.md). Under rule 16 of the Deck-Work-Queue no Bengali build starts before Japanese, Spanish and Telugu are complete: this page is a plan, and the two tasks that touch no deck content, BN-001 (the sourcing page, docs) and BN-032 (the tense-table design), are the only ones the audit suggests may run ahead.

## 0. Reading guide

- Task ids: `BN-001` to `BN-069`. Rules 1 to 15 of the Deck-Work-Queue ("Rules that every task carries") apply to every task. Rule 9 (one owner per shared file) and rule 10 (genre decks are not on the path; any other deck is listed on the path in the same PR) shape the rows. Rule 17: every kind below has ONE shared integration branch; its workers commit to it, each in its own worktree, merging the branch and `decks-live` before every fast-forward push; the architect opens ONE pull request per branch to `decks-live`, with ONE Sonnet review.
- Tool runs (`tools/transcribe.py`, `tools/topic_chars.py`, `tools/import_phonetic.py`, `tools/derive_phonetic.py`) use `main`'s `tools/`, not the stale copy on `decks-live`. A builder checks out `origin/main`'s `tools/` into its working tree and never commits it. No builder runs the validator or the tests.
- Size: S = under 25 cards or one small file; M = 25 to 60 new cards or one 90-card edit; L = more.
- "Wave" and "lane" are in section 5. File ownership is in section 5.3.
- Every candidate list names works, creators and seed phrases only. No date, text, lifespan or rights status in it was verified: each rights cell is **to be read**. The builder reads the source page, drops what it could not read, and replaces it from the reserve. Nothing is filled in from memory.

## 1. Counts and status grid

### 1.1 Counts

| | Bengali |
|---|---|
| Tasks in this plan | 69 (BN-001 to BN-069) |
| Haiku tasks (builders, tool run, docs close-out) | 67 |
| Sonnet tasks (sourcing page, tense-table design and pilot) | 2 (BN-001, BN-032) |
| Docs-only tasks (straight to main, no PR) | 2 (BN-001, BN-069) |
| Optional tasks (outside the 18 deliverables, default taken: built last) | 13 (BN-052 to BN-064, the examples wave) |
| Tool-run tasks | 1 (BN-065) |
| BLOCKED by code | 0 |
| Held (no task: needs the owner) | professional decks |

### 1.2 Bengali checklist grid (decks-live c57783c5, verified 2026-11-15)

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | **DONE** | `decks/bn/bn-path.yaml`: 173 entries (172 units plus the closing `*`), 0 planned, 2,833 words listed; milestones A1 (unit 51, `bn-grammar-future`), A2 (91, `bn-geography`), B1 (169, `bn-grammar-honorifics`); after B1: `bn-reading-honorifics`, `bn-spelling` and the six `bn-phonology-*` decks; `alphabet` lists the six script decks, `bn-reading-sahaj-path-1` and `bn-spelling`. Regions: six dialect groups | none (the path edits ride on the build tasks) |
| 2 | Cores and English layers | PARTLY | 204 cores (167 vocab, 30 grammar, 5 rules, `bn-script`, `bn-sounds`), 204 layers, **0 cores without a layer, 0 layers without a core**; 52 reading decks are single files; 4,054 card entries: 3,909 own cards (3,882 non-set, 27 set) and 145 `ref` entries; no duplicate id; highest card id `bn-4554`, highest id of any kind `bn-4560` (reading question). The gap: the tense tables are small pattern decks, not rules tables (see "Tense tables" below) | BN-032..040 |
| 3 | Sentences decks | PARTLY | 66 `-sentences` decks, 758 own sentence cards (5 to 23 per deck, 10 to 12 usual). Themed word units with no sentences deck (verb pool P taught by then in brackets): `bn-adverbs` (29), `bn-time` (30), `bn-location` (30), `bn-work` (54), `bn-numbers-big` (54), `bn-groceries` (54), `bn-market` (55), `bn-directions` (56), `bn-transport` (57), `bn-home` (57), `bn-daily-life` (78), `bn-calendar` (78), `bn-eating-out` (81), `bn-cooking` (93), `bn-help` (93), `bn-school` (94), `bn-hobbies` (101) = **17**. Skipped by the verb-pool rule (P of 1, before `bn-verbs`): `bn-questions`, `bn-addressing`, `bn-family`, `bn-numbers-1-20`, `bn-about-me`. Not themed (never get one): `bn-phrasebook`, `bn-first-words`, `bn-sound-differences`, `bn-sadhu-cholito`, `bn-spelling`, the 12 grammar vocab decks (`-postpositions`, `-conjunctions`, `-adjectives`, `-likes`, `-needs`, `-differences`, `-articles`, `-gender-number`, `-conjunct-verbs`, `-pitfalls`, `-can-must`, `-questions`; `bn-grammar-sentences` covers them) | BN-002..006 |
| 4 | Reading decks | PARTLY | 52 `bn-en-reading-*` files (110 passages: 100 with a `theme`, 318 questions, 5 sentences and 3 questions the usual). 72 units name `reading_passages`; **21 units name passages and have no reading deck** (22 reading passages, 22 listening passages): units 31 `pronouns-sentences`, 32 `verbs-sentences`, 33 `noun-forms-sentences`, 37 `food-sentences`, 40 `body`, 41 `places`, 44 `things-sentences` (two passages each), 46 `quantities-sentences`, 48 `clothes`, 49 `describing-sentences`, 50 `animals`, 72 `grammar-comparison`, 78 `grammar-imperatives`, 79 `grammar-past-continuous`, 80 `chores`, 81 `appearance`, 82 `verbs-3`, 83 `phone`, 84 `journey`, 85 `nature`, 86 `grammar-conjunctive`. Not a gap: unit 161's listening passage `he-said-that` is `bn-friends-talk` in its deck (ids differ, deck present) | BN-007..011 |
| 5 | Script decks | PARTLY | `bn-script-vowels` 11, `bn-script-consonants` 39 (32 letters, ড় ঢ় য় ৎ, and ং ঃ ঁ on ক), `bn-script-vowel-signs` 18 (the signs on ক, then the same on ম, and the hasanta ক্), `bn-script-conjuncts` 25 (ক্ষ জ্ঞ ক্ত ক্র প্র ত্র র্ম ন্ত ন্দ স্ত স্থ শ্র ষ্ট ঙ্গ ঞ্চ ন্ন ত্ত দ্ধ ল্প স্ব ব্য স্ত্র ত্ম ম্ব ঙ্ক), `bn-script-digits` 10, `bn-script-reading` 16 entries (10 own words, 6 refs); `bn-script` and `bn-sounds` are guide files with no cards. Missing: the other common conjuncts (about 50: only 25 are taught), more reading words, nothing for the rare vowels ঌ ৡ (not planned: not used in Bengali words) | BN-012..014 |
| 6 | Phrasebook | **DONE** | `bn-phrasebook`: 20 cards with `phrasebook: true` (the limit is 25); no other deck has the flag | none |
| 7 | Situations | MISSING | no `decks/bn/bn-situations.yaml` | BN-015, BN-016 |
| 8 | Topics incl. script topics | MISSING | no `decks/bn/bn-topics.yaml`; the five script decks and the grammar decks are free to be topics | BN-030, BN-031 |
| 9 | Culture decks | MISSING | no deck with `genre: culture` | BN-017..020 |
| 10 | Creators, eras, legacy | MISSING | no `decks/creators/bn.yaml` (only es, ja, te exist) | rides on BN-017..020, 028, 029 |
| 11 | Proverbs | MISSING | no deck with `genre: proverbs` | BN-021..023 |
| 12 | Multi-word verbs | MISSING | no deck with `genre: multiword`; the rules decks `bn-grammar-compound-verbs` (9 rows tagged `compound`) and the vocab decks `bn-grammar-conjunct-verbs` (21 cards) exist and are not genre decks | BN-024..027 |
| 13 | Professional | HELD | `professions: []` in `decks/sections.yaml`; the owner supplies the list first | none |
| 14 | Recommendations | MISSING | no `decks/recommendations/bn.yaml` | BN-028, BN-029 |
| 15 | Narrow IPA and broad `ipa` | PARTLY | registry entry `"bn"` in `tools/phonetic_languages.yaml` (Kolkata standard, Wiktionary's Rarh) and rules file `decks/bn/bn-phonetics.yaml` (2 rules: `bn-n-velar`, `bn-n-palatal`) both exist. **`phonetic` is on 1,763 of 3,882 non-set cards, all `phonetic_source: "rules"`; it is on every card of the 69 decks whose cards have ids from `bn-2549` up and on none of the 98 older files (2,119 cards lack it)**: the run of PR #984 covered only the decks of that batch. Broad `ipa` is on every non-set card except 9 cards that name a sound concept (`bn-phonology-prosody` 4, `-syllables` 4, `-spelling` 1: Intonation, Vː, Cː, Tone, CVC, CCV, CC#, VV, ঁ), which by design carry none. No open issue or PR for Bengali IPA (open: #1369 es, #1390 te rules, #1386 fr) | BN-065 |
| 16 | Review-queue rows | PARTLY | `docs/review-queue/bn.md` on decks-live: 9 rows (8 card rows from 2026-11-07 and one `bn-systemic` row about 83 examples whose IPA drops vowels); the file is not on main | BN-066..068 |
| 17 | Sourcing list | MISSING | no `wiki/Plan-Culture-Bengali.md` | BN-001 |
| 18 | Facts file | **DONE** | `bn-facts.yaml`: 41 facts (33 plain facts with `en`, `bn`, `hi` text, plus 8 contrast facts `bn-fact-101` to `-108` that carry `en` only or `en` and `hi`: they are contrast facts by design); 7 of 41 give a `source`. The plan's 30 is met | none |
| + | Notes gap | PARTLY | **1,035 non-set own cards have no note** in 97 files (750 are sentence cards); the 27 set cards are not counted. The validator warns of it in B1 decks | BN-041..051 |
| + | Examples gap (card data) | PARTLY | 568 of 2,678 word cards (non-sentence, non-script, non-phrase) have fewer than 2 examples (issue #1074 "in progress"). `FILLED_LANGUAGES` in the validator is empty, so it is not an error today | BN-052..064 (optional) |
| + | Tense tables as rules tables | OPEN | see below | BN-032..040 |
| + | Stale branch | n/a | `origin/deck/bn-b1-3` (last commit 2026-10-23) is not an open PR and shares no history with `decks-live` (2,281 commits not on it). Left over: listed for the owner to delete (agents cannot) | none |
| + | Resources file (`bn-resources.yaml`) | not on the grid | `ja-resources.yaml` exists | not planned; add only if the owner asks |

### 1.3 Grammar units, the tense tables and "every table covers every word"

The path has 47 `bn-grammar-*` cores (not counting sentences): 30 `kind: "grammar"` pattern decks, 12 vocab decks, 5 `kind: "rules"` decks, and 16 `bn-grammar-*-sentences` decks.

| Rules table (`kind: "rules"`) | Slots | Rows | Excepted | Words of its kind in path vocab decks | Missing | Verdict |
|---|---|---|---|---|---|---|
| `bn-grammar-noun-forms` | plural, gen, loc, ke, theke, sathe | 1,634 | 1 | 1,635 nouns | 0 | full |
| `bn-grammar-pronoun-forms` | gen, obj, with | 23 | 0 | 23 pronouns | 0 | full |
| `bn-grammar-verb-present` | ami, tui, tumi, apni, se, tini, please | 418 | 7 | 425 verbs | 0 | full |
| `bn-grammar-conjunctive` | conjunctive, negative | 420 | 5 | 425 verbs | 0 | full |
| `bn-grammar-compound-verbs` | conj, past, pres (verbs tagged `compound`) | 9 | 0 | 9 tagged verbs | 0 | full |

So the owner's rule of 2026-10-23 ("full tables covering every word", CLAUDE.md, Hindustani) holds for the noun, pronoun and present-verb tables. It does **not** hold for the tense tables, which are `kind: "grammar"` pattern decks that list a few chosen lemmas, as `kind: "grammar"` is meant to ("a few chosen rows"; Deck-Format, "Grammar decks": "a grammar table whose rows are the words of one kind ... is better written as a rules deck"):

| Pattern deck (unit) | Slots | Entries |
|---|---|---|
| `bn-grammar-present` (23) | 6 persons | 10 (করা যাওয়া খাওয়া বলা লেখা দেখা বোঝা থাকা দেওয়া হওয়া); the rules deck `bn-grammar-verb-present` already covers every verb |
| `bn-grammar-continuous` (38) | 6 persons | 4 |
| `bn-grammar-future` (51, A1) | 6 persons | 4 |
| `bn-grammar-past` (57) | 6 persons | 4 |
| `bn-grammar-perfect` (61) | 6 persons | 8 |
| `bn-grammar-past-negative` (61) | 6 persons | 8 |
| `bn-grammar-past-more` (64) | 18 (was doing, had done, used to; 6 persons each) | 3 |
| `bn-grammar-imperatives` (78) | tui, tumi, apni | 13 |
| `bn-grammar-past-continuous` (79) | 6 persons | 4 |
| `bn-grammar-habitual-past` (165) | simple past, habitual past | 9 |
| `bn-grammar-irregular` (73) | 4 | 6 (stays as it is: a chosen set by design) |

The open item "Bengali tense tables to become rules tables with their verb sets" is not written in any wiki page, the CLAUDE.md or the skills (grep of `wiki/`, `docs/`, `.claude/` and the instructions found only the Deck-Format paragraph above, the Audit-Tense-Number-Gender page, which lists the bn tense units, and the 2026-10-23 owner rule). **Meaning taken (default, recorded, owner may change it):** for each tense of the table above write a new `kind: "rules"` deck, one table with a row for **every verb the course teaches** (the 425 verb cards of the path decks; the verbs that have no such form go in `applies_to.except`, as the present table does for 7), rule ids and layer text as `bn-grammar-verb-present`. The pattern decks stay: card ids are permanent (their cells have ids `bn-grammar-past-kora-0` and the like), and the course already pairs a pattern deck with a rules deck (`bn-grammar-present` with `bn-grammar-verb-present`, `bn-grammar-pronouns` with `-pronoun-forms`, `bn-grammar-nouns` with `-noun-forms`). The clause forms (conditional, purpose, before-after, while, concessive, relative, causative, passive, reported speech, honorifics: 8 to 11 chosen verbs each) are not tense tables and are **not planned** (open question Q3). Every later noun, verb or adjective card added to a path deck owes a row in every rules table of its kind; section 3 says which tasks avoid that duty.

## 2. Reserved id ranges

Highest existing: `bn-4554` (card), `bn-4560` (reading question). Four digits, ascending, never reused. No other plan reserves a `bn-` range (the Deck-Work-Queue and the ES, TE and FR pages reserve other languages' ranges only).

| Range | Tasks | Use |
|---|---|---|
| bn-5000 to bn-5249 | BN-002 to BN-006 | new sentence cards, 50 per task |
| bn-5300 to bn-5549 | BN-007 to BN-011 | reading-question ids (the same namespace as cards), 50 per task |
| bn-5550 to bn-5699 | BN-012 to BN-014 | script cards |
| bn-5700 to bn-5899 | BN-017 to BN-020 | culture cards, 50 per task |
| bn-5900 to bn-6049 | BN-021 to BN-023 | proverb cards |
| bn-6050 to bn-6249 | BN-024 to BN-027 | multi-word cards |
| bn-6250 to bn-6349 | BN-015, BN-016 | new situation phrase cards (at most 12 each) |
| bn-4561 to bn-4999, bn-6350 to bn-6999 | none | free for repairs |

Recommendations take string ids (`bn-rec-<name>`), creators `bn-<name>`, topics `bn-<name>`, the new rules decks cell ids from their own keys: no numbers. Tasks that add no card (notes, examples, tense tables, IPA, queue rows, docs) reserve none.

## 3. Bengali conventions every BN task below carries

### 3.1 Cards, layers, ids

- **Header of a core** (as `bn-weather-sentences`): `schema: 1`, `id`, `part: "core"`, `kind: "vocab"`, `language: { code: "bn", iso639_3: "ben", name: "Bengali", script: "bengali", tts: "bn-IN", icon: "বা" }`, `license: "CC-BY-SA-4.0"`, `authors: [{ name: "Fluenough contributors" }]`, `tags: ["beginner", "unreviewed"]` (a genre deck: `genre`, `level`, `tags: ["unreviewed"]`, as `es-culture-3`). **Layer** `decks/bn/en/bn-en-<name>.yaml`: `kind: "layer"`, `core`, `native: { code: "en", iso639_3: "eng", name: "English" }`, `name`, `description` (ending "Not yet checked by a Bengali speaker: please report any mistake."), `cards:` keyed by id with `native`, `bases` (meanings), `notes`, `examples`, `confusables`. **Reading deck**: a single file `decks/bn/bn-en-reading-<stem>.yaml` with `kind: reading`, `source: "Written for the Fluenough Bengali course"`, `tags: [reading, unreviewed]`.
- **Every new card has `reading` and `ipa`** from `python3 tools/transcribe.py bn "<Bengali>" "<typed Latin hint of how it is said>"` (for example `python3 tools/transcribe.py bn "আজ আকাশে মেঘ আছে।" "aj akashe megh ache"`). Readings are based on ISO 15919 as said (`ô` for the open o, `ś` for শ ষ স, `ṅ` ...; [Readings-ISO-15919](Readings-ISO-15919.md), never "strictly"); `ipa` is the Kolkata standard. A hint is a Latin spelling of what is said; the tool says when it fell back on rules, and a doubtful reading or spelling goes to `docs/review-queue/bn.md`, never guessed. **No `phonetic` and no `phonetic_source` on any new card**: BN-065 writes them.
- **Sentence cards** (shape of `bn-weather-sentences`): `id`, `target` ending `।` or `?`, `reading`, `ipa`, `pos: "phrase"`, `rules` naming only rule ids that already exist on decks-live when the task starts (today `bn-rule-plural`, `-gen`, `-loc`, `-ke`, `-theke`, `-sathe`, `-pronoun-gen`, `-pronoun-obj`, `-pronoun-with`, `-present-first`, `-present-second`, `-present-third`, `-polite-request`, `-conjunctive`, `-compound-verbs`), `bases` with `ref` for every word that is a card (`{ word, ref }`) and `{ word, base, reading }` (and `ipa`) for an inflected form or a closed-class word; **2 or 3 `confusables`** (`{ id: "c1", ref: "bn-NNNN" }` or `{ id, word, reading, kind }` with `kind` one of form, word, sound, mark; a wrong alternative a learner would plausibly pick, never a needed tile; the layer gives each a `why` by id); layer: `native` (one plain English sentence), `bases` (a plain meaning for every word of the card's `bases` that is written in full), `confusables` keyed by the same ids, notes where the sentence has one point.
- **Sentence gate for Bengali** (the Deck-Work-Queue's variety rules, adapted): a whole sentence with a finite verb (or a complete nominal sentence with the copula dropped), 3 to 8 words counted by spaces; faithful full translation, same mood both sides; taught words only (every stem is a card of a deck listed on the path at or before the task's unit, every inflection one the rules decks teach; a word not taught is never used and never added); Bengali script only in the target; unique target and meaning across the course (the builder searches the language's decks first); no two sentences of a deck share a skeleton or differ by one word; verb cap by the pool P of verbs taught up to the unit (P of 13 or more: no verb more than twice); 10 sentences per deck (8 if the unit lists under 20 words), never padded, about 2 questions and 8 statements, at least 3 shapes and 5 different verbs, no content noun more than twice, shuffled so no run of three shares a shape or mood. The tense and person of a sentence use the forms of the present, past, future and continuous decks as they are.
- **Reading decks** (shape of `bn-en-reading-adverbs`): `passages:` for the unit's listening passage (written to be heard: a short dialogue or talk) and its reading passage (written to be read: a notice, list, letter, message), each `id` the path's id with the language prefix (`bn-who-is-who`), `title`, `theme`, `sentences` (usually 5, each `{ text, reading, ipa }`), `questions` (3 each: `id` from the task's range, `prompt { en }`, either `answer: true/false` or two options `[{ en }, { en }]` and a 1-based `answer`); all words taught up to the unit. The path gets a new unit entry directly after the unit that names the passages, as units 11 and 12 do: `- decks: ["bn-reading-<stem>"]` then `words: 0`; the file is `bn-en-reading-<stem>`, and its `id` and name copy the existing decks. A passage never repeats an existing passage id or title.
- **Rules tables (the duty of every new word card).** A new `pos: "noun"`, `"verb"`, `"adj"` or `"pronoun"` card in a deck **listed on the path** owes a row in every rules table of its kind (`bn-grammar-noun-forms`, `-verb-present`, `-conjunctive`, `-pronoun-forms`, and the tense tables once BN-033 to BN-040 merge), or a line in its `applies_to.except`; the validator checks it. Genre decks are not on the path and owe nothing. **So no task below adds a new noun, verb or adjective to a path deck**: situations add `pos: "phrase"` cards only, script and reading tasks use refs only, and a missing word is reported, never added.
- **Notes (RULE-NOTE-BN).** A typed note only where the card has one teachable point: a case ending, a verb ending, a person or respect form, a classifier (ṭā, ṭi, khānā, jon), a postposition, a conjunct or sound change, a pair or look-alike, a word's origin or register. Note id and `kind` in the core (`notes: [{ id: "n1", kind: "usage" }]`), the text in the layer under the same id; **the kind is one of the seven the validator knows: `behaviour`, `culture`, `homograph`, `lookalike`, `note`, `pair`, `usage`** (`register` is not one; register goes in a `usage` note or the card's own `register` field). Every non-Latin word in layer prose is followed by its reading in half-width parentheses, copied from the card: `আমি (āmi)`, and in a phrase the words spaced. A card with nothing to teach gets no note and is listed in the report. Ids and every existing field stay.

### 3.2 Validator failure lessons (every builder reads them before pushing)

Copied from `.claude/skills/build-deck/SKILL.md` "Validator lessons" and from the failed Haiku runs:

- **Confusable ids** are `[a-z0-9-]+`. A confusable is not a card of the sentence's own words.
- **A base word appears once per card** (case-insensitive): `bases` lists a word once even if the text repeats it; a repeated `word` is an error.
- **`words` join exactly to the whole target** with no spaces inside entries; `bases[].word` is one word of the target. A `bases` or `examples` entry has `ref` **or** `base`, never both, and a `ref` entry has no `reading`.
- **A layer's `bases` gloss only inline words** (the ones written in full in the core); never an empty `bases`. A word that is a `ref` gets no gloss.
- **Every layer note needs a matching core `notes: [{ id, kind }]`**, with one of the seven kinds above; a core note id with no layer text, or the reverse, is an error.
- **A layer meaning is one sentence**: join clauses with `;`.
- **A sentence card needs 2 or 3 confusables** (word cards: where one fits); a layer's keys equal the core's ids.
- **Every non-Latin word in layer text, descriptions or base meanings is followed by its reading** in half-width parentheses (`আমি (āmi)`); a base `meaning` is plain English with no Bengali letters.
- **Creators**: `born` and `died` are a plain year or `{ year, circa: true }` (never `circa: false`); `source.author` equals the creator's exact `name.en.text`; `legacy` has 1 to 6 items, each with a source; a creator's `died` is at most 120 years from `born` (`MAX_LIFESPAN`).
- **At most 25 `phrasebook: true` cards per course** (Bengali has 20: no task sets the flag).
- **An excerpt is at most 25 words**, one verse, sentence or line.
- **A grammar unit writes no reading deck of its own**: a grammar deck stays a rules or pattern deck. Where a grammar unit names passages (72, 78, 79, 86), the reading deck is a separate `bn-en-reading-<stem>` file with its own path entry `bn-reading-<stem>`, as unit 12 shows for `bn-adverbs`.
- **The validator requires every word of a kind in every B1 deck to have a row in every rules table of that kind** (section 3.1, "Rules tables").
- **Indentation errors can nest cards as examples**: a card at the wrong indent becomes an example of the card above and fails far from the mistake. Keep two spaces per level and check the first and last card of each batch by reading.
- **YAML**: quote every scalar except `true`, `false` and whole numbers; a `ref` entry is `- ref: "bn-NNNN"`; a conjunct or a letter written alone is a quoted string.
- **Guarded scripts** (rule 2): a script wraps its loop bodies in try/catch, logs each failure to the app's logger and repeats it in the report.

### 3.3 Genre rules

- **RULE-CULT-BN** (template `decks/ja/ja-culture-1.yaml`, `decks/es/es-culture-3.yaml`; [Plan-Culture-Japanese](Plan-Culture-Japanese.md), "Rules applied"): 18 items per deck, short first, level A2 or B1 per item; basis `public-domain` only, no `quotation` items; the `source` block as in the cited decks: `author`, `work`, `date` (a year, `c. YEAR` or `A-B`), `edition`, `url` (the Wikisource or Wikipedia page read), `basis`, `author_died`, `jurisdiction`, `rights_checked`; the excerpt is one verse, one sentence or one line, at most 25 words, shown **as on the cited edition** (Wikisource) in Bengali script, `edition` naming the edition and saying where the spelling was modernised (the 1936 Calcutta University spelling reform changed many older spellings; do not silently modernise). Text, dates and lifespans are read by the builder from bn.wikisource and bn.wikipedia first, en.wikipedia second; what could not be read is dropped and replaced from the reserve. **Rights floor:** an author's death year must be **1955 or earlier** (the validator floor); an anonymous or traditional work needs a first publication before 1900. India's term is life plus 60 years from the year after death, so for `jurisdiction: "IN"` an author who died in 1955 is out of copyright since 2016 and the floor is also the legal line; no stricter floor is needed (unlike Spain's life plus 80). Bangladesh's term is also life plus 60 as the builder reads it; the builder records `IN` or `BD` for the author's country and writes any doubt (a death year in 1941 to 1955 with a disputed edition, a work first published after the author died, or a modern editor's apparatus) to the review queue with "to be read". Kazi Nazrul Islam (died 1976), Tarashankar Bandyopadhyay (1971) and Manik Bandyopadhyay (1956) are **not** eligible: they appear in recommendations only. Each creator: short A2-level English bio, `born`/`died` (`circa` if uncertain), era, one `legacy` line with a checkable item and a source link, no image; `name: { bn: { text, ipa }, en: { text } }`. Cards: `genre: "culture"`, `level`, `creator`, `notes` (one `note` or `culture` note), `modes: ["recognition", "listening"]`, `bases` as in `es-culture-3`; the Bengali target has `reading` and `ipa` by the tool.
- **RULE-PV-BN** (template `ja-proverbs-1`): `genre: "proverbs"`, `basis: "oral-tradition"`, a `source` block with `collection`, `date` (the collection's), `edition`, `jurisdiction`, `rights_checked`; a `literal` note and a meaning on every card (the literal word-for-word sense, then what it is said of), level A2 or B1; standard colloquial (cholito) spelling, no archaic or dialect form unless the source gives it and the note says so; a proverb whose text the builder did not read on the cited page is dropped. Sources the builder tries in this order and cites by page and date: bn.wikiquote's proverb pages, bn.wikisource's proverb collections, en.wikipedia "Bengali proverbs" if it exists, the attributed sayings of Khana (Khanar Bachan) and Dak (Dakar Bachan) as anonymous pre-1900 oral tradition. A Bengali collection whose compiler died after 1955 is used for nothing but the check that a proverb is attested.
- **RULE-MW-BN** (template `ja-multiword-te-auxiliaries`, `es-multiword-periphrases`): `genre: "multiword"`, a `pattern_family`, `level`, a `usage` note on every card, `words` and `bases` for each part, parts already taught written by `ref`, a part not yet a card gets a card (a genre deck is not on the path, so it owes no rules rows). The citation form is the verbal noun in -ā (`করা`, `খেয়ে ফেলা`); `words` join exactly to `target`. A pattern is kept only if attested on bn.wiktionary or en.wiktionary or a cited dictionary page; fewer than 20 found: report the count, do not fill.
- Rights judgements in this page and in BN-001 are marked **to be read**; the rights reviewer is the orchestrator with a Sonnet review per PR (owner, 2026-11-13), and everything ships `unreviewed` (no named bilingual reviewer; doubts go to `docs/review-queue/bn.md`).

## 4. Task table

Common fields: branch `decks/bn-<kind>` off `decks-live` (one shared integration branch per kind, section 5); "Not touched" always includes every file not named, `decks/min_app.json` and the path outside the entries a row names. Words of a unit are "taught" if a deck listed on the path at or before that unit has them.

### 4.1 Plan page (docs)

| Id | Branch | Creates / edits | Content rules and exact spec | Ids | Size | Depends on | Notes |
|---|---|---|---|---|---|---|---|
| BN-001 | main, docs (Sonnet) | create `wiki/Plan-Culture-Bengali.md` | The sourcing list the Plan-Language-Completeness "plan before build" rule asks for, in the shape of `Plan-Culture-Spanish`: the candidate lists of BN-017..020 (culture, 4 x 18 plus reserves), BN-021..023 (proverbs, 3 x 20), BN-024..027 (multiword, 4 x 20), BN-028, 029 (recommendations, 10 + 10), each rights cell "to be read", the rights floor and the India life-plus-60 note of RULE-CULT-BN, the spelling-reform note, the Bengali Wikisource and Wikipedia reading order, the review-queue rule. Take the candidate names from section 6 of this page (corrected where the Sonnet knows better; a name it cannot place is dropped, not invented). Straight to main (docs only), no PR | none | S | none | the soft "plan first" gate of BN-017..029 |

### 4.2 Sentences, BN-002 to BN-006 (branch `decks/bn-sentences`)

Each task creates `decks/bn/bn-<theme>-sentences.yaml` and `decks/bn/en/bn-en-<theme>-sentences.yaml` per deck listed, and edits `decks/bn/bn-path.yaml` only to add `"bn-<theme>-sentences"` after the unit's word deck in the unit's `decks` list (the same way `bn-weather` is followed by `bn-weather-sentences`). Content rules: section 3.1 "Sentence gate for Bengali" and sentence card shape; 10 sentences per deck, 8 where the unit lists under 20 words (marked *); the layer description says how many; a unit whose pool P is under 8 is skipped (none of these is); no existing card is touched. Review-queue rows go in the report.

| Id | Branch | Creates / edits | Units (path unit number, words) | Ids | Cards | Size | Depends on | Notes |
|---|---|---|---|---|---|---|---|---|
| BN-002 | decks/bn-sentences | `bn-adverbs-sentences`, `bn-time-sentences`, `bn-location-sentences`, `bn-work-sentences` and layers; path units 11, 15, 16, 26 | 11 adverbs (44 words), 15 time (27), 16 location (14)*, 26 work (21) | bn-5000 to bn-5049 | 4 decks, 38 sentences | M | none | PARALLEL |
| BN-003 | decks/bn-sentences | `bn-numbers-big-sentences`, `bn-groceries-sentences`, `bn-market-sentences`, `bn-directions-sentences`; path units 27, 29, 30, 38 | 27 numbers-big (93), 29 groceries (23), 30 market (16)*, 38 directions (12)* | bn-5050 to bn-5099 | 4 decks, 36 sentences | M | none | PARALLEL. `numbers-big` sentences may use the number words as taught |
| BN-004 | decks/bn-sentences | `bn-transport-sentences`, `bn-home-sentences`, `bn-daily-life-sentences`; path units 39, 43, 52 | 39 transport (9)*, 43 home (21), 52 daily-life (26) | bn-5100 to bn-5149 | 3 decks, 28 sentences | M | none | PARALLEL |
| BN-005 | decks/bn-sentences | `bn-calendar-sentences`, `bn-eating-out-sentences`, `bn-cooking-sentences`; path units 57, 69, 70 | 57 calendar (27), 69 eating-out (9)*, 70 cooking (50) | bn-5150 to bn-5199 | 3 decks, 28 sentences | M | none | PARALLEL |
| BN-006 | decks/bn-sentences | `bn-help-sentences`, `bn-school-sentences`, `bn-hobbies-sentences`; path units 73, 74, 76 | 73 help (14)*, 74 school (50), 76 hobbies (50) | bn-5200 to bn-5249 | 3 decks, 28 sentences | M | none | PARALLEL |

### 4.3 Reading, BN-007 to BN-011 (branch `decks/bn-reading`)

Each task creates `decks/bn/bn-en-reading-<stem>.yaml` per deck listed (section 3.1 "Reading decks": the unit's listening passage and its reading passage, from the path's ids; two of each for `things`) and edits `decks/bn/bn-path.yaml` only to insert the new unit entry `- decks: ["bn-reading-<stem>"]` / `words: 0` directly after the unit named. Path units are named by their first deck id, because inserting entries shifts numbers. The passage text uses only words taught up to the unit; the early units 31 to 33 use only the pronouns, verbs and noun forms taught by then.

| Id | Branch | Creates / edits | Passages by the path's ids (listening / reading) | Ids | Cards | Size | Depends on | Notes |
|---|---|---|---|---|---|---|---|---|
| BN-007 | decks/bn-reading | `bn-en-reading-pronouns`, `-verbs`, `-noun-forms`, `-food`, `-body`; units after `bn-pronouns-sentences`, `bn-verbs-sentences`, `bn-noun-forms-sentences`, `bn-food-sentences`, `bn-body` (and its sentences deck) | pronouns: who-is-who / seating-chart; verbs: morning-routine / fridge-note; noun-forms: way-to-school / school-notice; food: at-the-sweet-shop / menu-card; body: at-the-doctors / stretching-chart | bn-5300 to bn-5349 (questions only) | 5 decks, 10 passages x 3 questions | M | none | PARALLEL |
| BN-008 | decks/bn-reading | `bn-en-reading-places`, `-things`, `-quantities`, `-clothes`; units `bn-places`, `bn-things-sentences`, `bn-quantities-sentences`, `bn-clothes` | places: walk-to-the-market / street-signs; things: packing-for-a-trip and kitchen-help / lost-property-list and how-to-make-tea; quantities: at-the-grocers / recipe-amounts; clothes: choosing-a-shirt / shop-offer-sign | bn-5350 to bn-5399 | 4 decks, 10 passages (`things` has 4) | M | none | PARALLEL |
| BN-009 | decks/bn-reading | `bn-en-reading-describing`, `-animals`, `-comparison`, `-imperatives`; units `bn-describing-sentences`, `bn-animals`, `bn-grammar-comparison`, `bn-grammar-imperatives` | describing: how-are-you-feeling / postcard-from-the-hills; animals: village-visit / zoo-board; comparison: which-is-better / two-cities; imperatives: class-instructions / signs-and-rules | bn-5400 to bn-5449 | 4 decks, 8 passages | M | none | PARALLEL |
| BN-010 | decks/bn-reading | `bn-en-reading-past-continuous`, `-chores`, `-appearance`, `-verbs-3`; units `bn-grammar-past-continuous`, `bn-chores`, `bn-appearance`, `bn-verbs-3` | past-continuous: what-was-happening / power-cut-story; chores: cleaning-day / chore-list; appearance: describing-a-friend / lost-and-found-notice; verbs-3: a-busy-day / diary-entry | bn-5450 to bn-5499 | 4 decks, 8 passages | M | none | PARALLEL |
| BN-011 | decks/bn-reading | `bn-en-reading-phone`, `-journey`, `-nature`, `-conjunctive`; units `bn-phone`, `bn-journey`, `bn-nature`, `bn-grammar-conjunctive` | phone: phone-call / text-messages; journey: ticket-counter / train-timetable; nature: walk-by-the-river / park-signs; conjunctive: what-i-did-today / travel-diary | bn-5500 to bn-5549 | 4 decks, 8 passages | M | none | PARALLEL. Adds no edit to `bn-en-reading-reported-speech` (its listening passage exists under another id) |

### 4.4 Script, BN-012 to BN-014 (branch `decks/bn-script`)

| Id | Branch | Creates / edits | Content rules and exact spec | Ids | Size | Depends on | Notes |
|---|---|---|---|---|---|---|---|
| BN-012 | decks/bn-script | create `bn-script-conjuncts-2` and layer `bn-en-script-conjuncts-2`; edit `bn-path.yaml` (`alphabet` and the unit entry that lists `bn-script-conjuncts`) | Header and shape of `bn-script-conjuncts`: tags `["beginner", "unreviewed", "script"]`, `pos: "letter"`, `target` the cluster only, `reading`, `ipa`, an `examples` entry using a real taught word where one exists. Up to 25 more conjuncts not yet taught. Candidates, in this order, which the builder checks against bn.wikipedia's Bengali-alphabet page (the conjunct table) and against a taught word: ক্ক ক্ট ক্ল ক্স গ্ন গ্র গ্ধ ঘ্ন চ্চ চ্ছ জ্জ জ্ব ঞ্জ ট্ট ট্র ড্র ণ্ড ণ্ঠ ত্ন ত্ব থ্য দ্দ দ্ব দ্ভ দ্য দ্র ধ্ব. A cluster the page does not show, or whose reading the builder cannot confirm, is reported, not invented; a cluster with no taught word gets no example and a review-queue row "no example". Layer: how the cluster is drawn (a stacked or a side-by-side form; the হসন্ত joins the two) in Latin prose with readings | bn-5550 to bn-5599 | S | none | PARALLEL |
| BN-013 | decks/bn-script | create `bn-script-conjuncts-3` and layer; edit `bn-path.yaml` as BN-012 | As BN-012, clusters not in the first two decks. Candidates: ন্ধ ন্ম প্ত প্ল প্স ফ্ল ব্দ ব্ধ ব্র ভ্র ম্প ম্ফ ম্ভ ম্র ম্ল ম্ম ল্ক ল্ল শ্চ শ্ন শ্ব শ্ম শ্ল ষ্ক ষ্ণ ষ্প ষ্ম স্ক স্খ স্ট স্ন স্প স্ফ স্ম স্র স্ল হ্ন হ্ম হ্র হ্ল ক্ষ্ম ক্ষ্ণ ন্ত্র ন্দ্র. At most 25 | bn-5600 to bn-5649 | S | BN-012 merged | serial after BN-012 (the same path lines) |
| BN-014 | decks/bn-script | create `bn-script-reading-2` and layer; edit `bn-path.yaml` (`alphabet` and the script unit entry) | Up to 30 words for reading practice after `bn-script-reading` (16 entries): only letters, vowel signs and conjuncts taught by the `bn-script-*` decks and BN-012, 013; **every word is a `ref` to an existing card** (no new noun, verb or adjective: section 3.1 "Rules tables"); the deck holds the ref entries and an own card only for `pos: "other"` items none of the course teaches (none expected). A word with no card is dropped; fewer than 20 refs found: report the count, never pad. Layer: how to read each word aloud | bn-5650 to bn-5699 | S | BN-012, BN-013 merged | serial |

### 4.5 Situations, BN-015 and BN-016 (branch `decks/bn-situations`)

| Id | Branch | Creates / edits | Content rules and exact spec | Ids | Size | Depends on | Notes |
|---|---|---|---|---|---|---|---|
| BN-015 | decks/bn-situations | create `decks/bn/bn-situations.yaml`; append at most 12 new `pos: "phrase"` cards (core and layer) to the decks of their theme | Deck-Format "Situations files" and "What new situations teach (owner, 2026-11-12)": header as `te-situations` (`kind: situations`, `language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN, icon: "বা" }`, no `native`, `tags: ["unreviewed"]`); the six sheets `taxi` (icon `taxi`, title "Taxi and rickshaw"), `shops`, `eat`, `doctor`, `traffic`, `rail` (each icon once), `title { en, bn }` (the Bengali title with its reading in parentheses where the title is prose), 8 to 12 phrases and at most 12 words per sheet, every id a real `bn-` card (look in `bn-transport`, `bn-shopping`, `bn-market`, `bn-eating-out`, `bn-food`, `bn-health`, `bn-illness`, `bn-directions`, `bn-journey`, `bn-travel`, `bn-help`), one natural phrase per idea, the common register only (cholito, not sadhu). A needed phrase with no card becomes a new `pos: "phrase"` card at the end of the best-fit deck and its layer (at most 12 in all), `ipa` from the tool, no `phonetic`; a needed noun, verb or adjective with no card is reported, never added | bn-6250 to bn-6299 | S | none | lane D. Uses six keys the released app draws |
| BN-016 | decks/bn-situations | edit `bn-situations.yaml`, plus at most 12 new cards | 4 more sheets: `hotel` (icon `hotel`), `post-bank` (icon `post`), `greetings` (icon `greeting`), `emergencies` (icon `emergency`); same rules as BN-015. The index gives the file `min_app` 0.10.3 by the tool (no line in `decks/min_app.json`) | bn-6300 to bn-6349 | S | BN-015 merged | lane D |

### 4.6 Culture, BN-017 to BN-020, and the creators file (branch `decks/bn-culture`)

All four: RULE-CULT-BN, 18 items per deck, candidates in order (work, creator), the first 18 that pass are the deck and the rest the reserve; fewer than 18 may pass, say so in the report, never pad. Names only: each rights cell is **to be read**. Section 6.1 has the lists; the BN-001 page wins where it differs.

| Id | Branch | Creates / edits | Content rules and exact spec | Ids | Size | Depends on | Notes |
|---|---|---|---|---|---|---|---|
| BN-017 | decks/bn-culture | create `bn-culture-1`, layer `bn-en-culture-1`; **create `decks/creators/bn.yaml`** | RULE-CULT-BN. **Early and medieval Bengali, to 1800.** `creators/bn.yaml` is created here: `kind: "creators"`, `id: "creators-bn"`, `language: "bn"`, license, eras (charyapada period, medieval, Bengal Renaissance, Tagore's age, the twentieth century) with `from` and `to` read from the builder's sources, and the creators of the deck, ids `bn-<name>`. Owns `creators/bn.yaml` for batch 1 | bn-5700 to bn-5749 | M | BN-001 | lane A, first |
| BN-018 | decks/bn-culture | create `bn-culture-2`, layer; edit `creators/bn.yaml` | RULE-CULT-BN. **The nineteenth century: prose, drama and verse.** Adds only creators and eras not yet in the file | bn-5750 to bn-5799 | M | BN-017 merged | lane A |
| BN-019 | decks/bn-culture | create `bn-culture-3`, layer; edit `creators/bn.yaml` | RULE-CULT-BN. **Tagore, his circle and children's classics.** Authors who died by 1955 only | bn-5800 to bn-5849 | M | BN-018 merged | lane A |
| BN-020 | decks/bn-culture | create `bn-culture-4`, layer; edit `creators/bn.yaml` | RULE-CULT-BN. **Twentieth-century fiction and poetry by authors who died by 1955.** Nazrul, Tarashankar and Manik Bandyopadhyay are ineligible (section 3.3) | bn-5850 to bn-5899 | M | BN-019 merged | lane A |

### 4.7 Proverbs and multiword (branches `decks/bn-proverbs`, `decks/bn-multiword`)

| Id | Branch | Creates / edits | Content rules and exact spec | Ids | Size | Depends on | Notes |
|---|---|---|---|---|---|---|---|
| BN-021 | decks/bn-proverbs | create `bn-proverbs-1`, layer `bn-en-proverbs-1` | RULE-PV-BN, 20 cards. Themes in order: animals, food and drink, money, work and effort, family, friends and neighbours, weather and seasons (short first). Seeds the builder checks first (section 6.2). Each card: `target`, `words`, `reading`, `ipa`, `pos: "phrase"`, `level`, `notes` `literal` (and a `usage` note where the proverb is said of something), `source` | bn-5900 to bn-5949 | M | BN-001 | lane C, PARALLEL |
| BN-022 | decks/bn-proverbs | create `bn-proverbs-2`, layer | RULE-PV-BN, 20 cards not in proverbs-1 (the builder lists its targets first); themes: pride and greed, patience and time, luck and fate, speech and silence, learning, the home, justice | bn-5950 to bn-5999 | M | BN-021 merged | lane C |
| BN-023 | decks/bn-proverbs | create `bn-proverbs-3`, layer | RULE-PV-BN, 20 cards not in 1 or 2; themes: love, age, honesty, appearances, cleverness, neighbours, travel, the fields (Khana's sayings on farming and weather are anonymous pre-1900) | bn-6000 to bn-6049 | M | BN-022 merged | lane C |
| BN-024 | decks/bn-multiword | create `bn-multiword-conjunct-kora`, layer | RULE-MW-BN, `pattern_family: "conjunct-verb"`, 20 cards of noun plus করা. Selection by procedure: scan the cores `bn-grammar-conjunct-verbs`, `bn-work`, `bn-school`, `bn-health`, `bn-hobbies`, `bn-phone`, `bn-workplace` in that order, nouns in id order, and take each noun whose bn.wiktionary entry (or a cited dictionary page) lists a noun-plus-করা compound, until 20; seeds the builder checks first in section 6.3. The noun is written by `ref`; the existing `bn-grammar-conjunct-verbs` cards are not repeated (the builder searches the course) | bn-6050 to bn-6099 | M | none | lane C |
| BN-025 | decks/bn-multiword | create `bn-multiword-conjunct-other`, layer | RULE-MW-BN, `pattern_family: "conjunct-verb-other"`, 20 cards of noun or adjective plus হওয়া, পাওয়া, লাগা, দেওয়া, আসা (the verbs of feeling, need, illness and weather: ভয় পাওয়া, ঘুম পাওয়া, ঠান্ডা লাগা, রাগ হওয়া ...); same procedure and seeds | bn-6100 to bn-6149 | M | none | lane C |
| BN-026 | decks/bn-multiword | create `bn-multiword-aspectual`, layer | RULE-MW-BN, `pattern_family: "aspectual-compound"`, 20 cards: a verb's -ে or -য়ে form plus ফেলা, পড়া, ওঠা, দেওয়া, নেওয়া, রাখা, যাওয়া, আসা, বসা or দেখা; pair each auxiliary with 2 or 3 verbs taught by `bn-verbs`, `bn-more-verbs`, `bn-verbs-3`, `bn-verbs-4`; keep only compounds attested on bn.wiktionary or a cited page; skip the 9 compounds the rules deck `bn-grammar-compound-verbs` already teaches; the verb is written by `ref`. Fewer than 20: report | bn-6150 to bn-6199 | M | none | lane C |
| BN-027 | decks/bn-multiword | create `bn-multiword-idiomatic`, layer | RULE-MW-BN, `pattern_family: "idiomatic-verb-phrase"`, 20 cards of a body or mind noun with a verb whose meaning is not the sum of its parts (মনে পড়া, মনে রাখা, মন দেওয়া, ধরা পড়া, মাথা ঘামানো ...); same procedure and seeds; a `usage` note says what it means and when it is said | bn-6200 to bn-6249 | M | none | lane C |

### 4.8 Recommendations and topics

| Id | Branch | Creates / edits | Content rules and exact spec | Ids | Size | Depends on | Notes |
|---|---|---|---|---|---|---|---|
| BN-028 | decks/bn-recommendations | create `decks/recommendations/bn.yaml` (10 entries); edit `creators/bn.yaml` | Shape of the entries of `recommendations/es.yaml` and `ja.yaml`: `id: "bn-rec-<name>"`, `medium`, `title { text }` (Bengali with the reading by the tool where the title is Bengali), `creator`, `year`, `level`, `briefing { en }` (own words), 3 questions each answerable only by someone who watched it, `tags: ["unreviewed"]`; no quote, no link, no excerpt (the source-it-yourself mode, Plan-Language-Completeness). 10 audiovisual works not in the public domain: section 6.4. Year and creator read from the work's Wikipedia page; a work whose facts the builder could not read is replaced from the reserve. Creators added where missing (directors) with the RULE-CULT-BN bio shape; a living creator has `born` and no `died` | strings | M | BN-020 merged (file ownership of `creators/bn.yaml`) | lane A, after the culture lane |
| BN-029 | decks/bn-recommendations | edit `recommendations/bn.yaml`, `creators/bn.yaml` | 10 more: books, comics, songs, a radio programme (section 6.4). Same rules; `medium` among book, comic, song, radio | strings | M | BN-028 merged | lane A |
| BN-030 | decks/bn-topics | create `decks/bn/bn-topics.yaml`; edit nothing else | Shape of `ja-topics.yaml` and `es-topics.yaml`: header `kind: "topics"`, `id: "bn-topics"`, `language: "bn"`. **5 `kind: "script"` topics** (vowels, consonants, vowel signs, conjuncts, digits), each with `decks` (`bn-script-vowels`; `bn-script-consonants`; `bn-script-vowel-signs`; `bn-script-conjuncts`, `-2`, `-3`; `bn-script-digits`) and `chars` written by `python3 tools/topic_chars.py bn --write` (never by hand); **9 `kind: "grammar"` topics**: case endings (`bn-grammar-noun-forms`, `bn-grammar-nouns`), postpositions, the present (`bn-grammar-present`, `-verb-present`, `-continuous`), the past (`-past`, `-past-more`, `-past-negative`, `-past-continuous`, `-perfect`, `-habitual-past`), the future, the three words for you and respect (`-pronouns`, `-pronoun-forms`, `-honorifics`), questions and indefinites, clause linking (`-relative`, `-conditional`, `-purpose`, `-before-after`, `-while`, `-concessive`), passive and causative. Each: `name { en }`, `summary { en }` (one or two English sentences, no card text), `term { text, reading }` where it has a Bengali name, `level`, `decks` (existing deck ids only), `grammar` (the path's topics) | none | S | BN-012..014 merged | lane B |
| BN-031 | decks/bn-topics | edit `bn-topics.yaml` | 8 more: kinship terms (`kind: "words"`, `bn-family`), food and dishes, numbers and counting, formal and colloquial Bengali (`bn-sadhu-cholito`, `kind: "words"`), culture topics (early and medieval, the nineteenth century, Tagore and the twentieth century, `kind: "other"`; each lists the `decks` of the merged culture decks), proverbs (`kind: "words"`), multi-word verbs (`kind: "verbs"`, the four multiword decks and `bn-grammar-conjunct-verbs`, `-compound-verbs`) | none | S | BN-017..027 merged | lane B, last of the topics |

### 4.9 Tense tables as rules tables, BN-032 to BN-040 (branch `decks/bn-tenses`)

| Id | Branch | Creates / edits | Content rules and exact spec | Ids | Size | Depends on | Notes |
|---|---|---|---|---|---|---|---|
| BN-032 | decks/bn-tenses | **Sonnet.** create `decks/bn/bn-grammar-verb-past.yaml` and layer `bn-en-grammar-verb-past`; edit `bn-path.yaml` (unit 57) | **Design and pilot.** Read the shape of `bn-grammar-verb-present` (core and layer) and `bn-grammar-verb-classes`; decide in one report, for all nine tables: the deck id (`bn-grammar-verb-<tense>`: `past`, `continuous`, `future`, `perfect`, `past-negative`, `past-continuous`, `past-perfect`, `habitual-past`, `imperative`), the slots (the six persons of the present table: ami, tui, tumi, apni, se, tini; imperative: tui, tumi, apni, and the negative where the course teaches it), the rule ids (`bn-rule-<tense>-first`, `-second`, `-third`, three per tense, two for the imperative), their names and explanations in the present table's wording, the `applies_to.except` list (the 7 of the present table plus any verb with no such form) and the path topics (a rules deck's topics are its rule ids' names). Then write a **deterministic generator** (a scratch script, never committed: the Deck-Work-Queue keeps builders' scripts in the session scratch folder) that derives each form from the verb's stem as it shows in the present table's `se` and `tumi` forms, by verb class (the 20 entries of `bn-grammar-verb-classes`, the irregulars of `bn-grammar-irregular`: যাওয়া আসা দেওয়া নেওয়া খাওয়া হওয়া, and the vowel-changing stems), with every exception listed by hand in the report and every row's readings by the same rules; build the past deck with it as the pilot (418 rows) and hand the architect the script path, the exception list and the report. Each new deck is listed after its pattern deck in the same unit (for example `["bn-calendar", "bn-grammar-past", "bn-grammar-verb-past", "*"]`) and the unit's `grammar` list gains the rule topics | none (rows reference existing cards) | L | none | **Sonnet.** PARALLEL with the content lanes. Everything BN-033..040 waits on its merge |
| BN-033 | decks/bn-tenses | create `bn-grammar-verb-continuous` and layer; path unit 38 | The BN-032 design and generator: one table, a row for **every verb the course teaches**, forms and readings from the generator, the exceptions of the report; layer `table.slot_name`, a label for every slot, a name and an explanation for every rule (`{1}`, `{2}` placeholders, Bengali words followed by their readings); `applies_to.pos: ["verb"]`; the row count equals the verb pool minus the `except` list (the builder prints both numbers) | none | L | BN-032 merged | PARALLEL with BN-034..040 |
| BN-034 | decks/bn-tenses | create `bn-grammar-verb-future` and layer; path unit 51 | as BN-033 | none | L | BN-032 merged | PARALLEL |
| BN-035 | decks/bn-tenses | create `bn-grammar-verb-perfect` and layer; path unit 61 | as BN-033 | none | L | BN-032 merged | PARALLEL |
| BN-036 | decks/bn-tenses | create `bn-grammar-verb-past-negative` and layer; path unit 61 | as BN-033; the negative forms (করিনি, করোনি ...) | none | L | BN-032 merged | PARALLEL |
| BN-037 | decks/bn-tenses | create `bn-grammar-verb-past-continuous` and layer; path unit 79 | as BN-033; also the "was doing" forms of `bn-grammar-past-more` | none | L | BN-032 merged | PARALLEL |
| BN-038 | decks/bn-tenses | create `bn-grammar-verb-past-perfect` and layer; path unit 64 | as BN-033; the "had done" forms of `bn-grammar-past-more` | none | L | BN-032 merged | PARALLEL |
| BN-039 | decks/bn-tenses | create `bn-grammar-verb-habitual-past` and layer; path unit 165 | as BN-033; the "used to" forms (যেতাম, যেতিস, যেতে ...); the table has the six persons, not the pattern deck's two slots | none | L | BN-032 merged | PARALLEL |
| BN-040 | decks/bn-tenses | create `bn-grammar-verb-imperative` and layer; path unit 78 | as BN-033; slots tui, tumi, apni (and the negative if BN-032 decides it); the polite request `-ুন` is already a rule of the present table and is not repeated | none | L | BN-032 merged | PARALLEL |

### 4.10 Notes, BN-041 to BN-051 (branch `decks/bn-notes`)

RULE-NOTE-BN (section 3.1). Edit the cores and layers named: only cards **without a note** are in scope (the counts in brackets are of 2026-11-15; the builder recounts and lists the card ids first); set cards are not in scope; a card with nothing to teach is listed in the report. No file listed here is a new deck: the sentence decks of BN-002..006 are written with their notes.

| Id | Branch | Edits (cards without a note in brackets) | Size | Depends on | Notes |
|---|---|---|---|---|---|
| BN-041 | decks/bn-notes | bn-first-words 3, bn-questions 7, bn-addressing 2, bn-family 8, bn-numbers-1-20 14, bn-about-me 12, bn-time 17, bn-grammar-conjunctions 1, bn-grammar-adjectives 17, bn-work 8 (89) | M | BN-016 merged | PARALLEL with the other notes tasks |
| BN-042 | decks/bn-notes | bn-numbers-big 81, bn-groceries 15 (96) | M | BN-016 | PARALLEL |
| BN-043 | decks/bn-notes | bn-market 12, bn-pronouns-sentences 16, bn-verbs-sentences 23, bn-noun-forms-sentences 13, bn-grammar-questions 4, bn-grammar-likes 1, bn-grammar-sentences 2, bn-food-sentences 12, bn-directions 6, bn-transport 9 (98) | M | BN-016 | PARALLEL |
| BN-044 | decks/bn-notes | bn-body-sentences 11, bn-places-sentences 14, bn-home 11, bn-things-sentences 19, bn-more-verbs-sentences 16, bn-grammar-needs 1, bn-quantities-sentences 18, bn-grammar-articles 1, bn-grammar-gender-number 1 (92) | M | BN-016 | PARALLEL |
| BN-045 | decks/bn-notes | bn-clothes-sentences 14, bn-describing-sentences 19, bn-animals-sentences 14, bn-daily-life 5, bn-grammar-conjunct-verbs 10, bn-weather-sentences 7, bn-calendar 20, bn-festivals-sentences 10 (99) | M | BN-016 | PARALLEL |
| BN-046 | decks/bn-notes | bn-shopping-sentences 16, bn-illness-sentences 20, bn-grammar-compound-verbs-sentences 6, bn-eating-out 5, bn-help 14, bn-chores-sentences 12, bn-appearance-sentences 12, bn-verbs-3-sentences 12 (97) | M | BN-016 | PARALLEL |
| BN-047 | decks/bn-notes | bn-phone-sentences 12, bn-journey-sentences 12, bn-nature-sentences 12, bn-grammar-conjunctive-sentences 10, bn-adjectives-2-sentences 10, bn-workplace-sentences 10, bn-geography-sentences 10, bn-health-sentences 10, bn-feelings-sentences 10 (96) | M | BN-016 | PARALLEL |
| BN-048 | decks/bn-notes | bn-grammar-relative-sentences 5, bn-news-sentences 11, bn-opinions-sentences 10, bn-grammar-conditional-sentences 6, bn-travel-sentences 10, bn-services-sentences 10, bn-government-sentences 10, bn-grammar-purpose-sentences 6, bn-technology-sentences 11, bn-careers-sentences 11, bn-grammar-before-after-sentences 6 (96) | M | BN-016 | PARALLEL |
| BN-049 | decks/bn-notes | bn-environment-sentences 11, bn-agriculture-sentences 11, bn-grammar-while-sentences 6, bn-cinema-sentences 11, bn-arts-sentences 11, bn-grammar-causative-sentences 10, bn-history-sentences 11, bn-weddings-sentences 11, bn-grammar-concessive-sentences 10 (92) | M | BN-016 | PARALLEL |
| BN-050 | decks/bn-notes | bn-sports-sentences 11, bn-relationships-sentences 11, bn-grammar-indefinites-sentences 10, bn-housing-sentences 12, bn-emergencies-sentences 11, bn-grammar-emphasis-sentences 10, bn-law-sentences 12, bn-verbs-4-sentences 12, bn-grammar-passive-sentences 11 (100) | M | BN-016 | PARALLEL |
| BN-051 | decks/bn-notes | bn-abstract-words-sentences 12, bn-money-sentences 12, bn-grammar-reported-speech-sentences 10, bn-literature-sentences 12, bn-grammar-habitual-past-sentences 10, bn-verbs-5-sentences 13, bn-grammar-honorifics-sentences 11 (80) | M | BN-016 | PARALLEL |

Together 1,035 cards. Cards without a note are 750 sentence cards and 285 word cards.

### 4.11 Examples (optional), BN-052 to BN-064 (branch `decks/bn-examples`)

Outside the 18 deliverables; default taken: built after the notes wave, because the skill's mandatory set says "at least 2 examples on a word card" and issue #1074 started it. The owner may drop the wave (open question Q2). Edit the cores and layers named: for each word card (a card of pos noun, verb, adj, adv, pronoun, particle or other, not a sentence, script or phrase card) with fewer than 2 examples, add examples up to 2: short sentences of **taught words** (the shape of the examples of `bn-food`: `target`, `reading`, `ipa` by the tool, `bases` with `ref` for cards and `{ word, base, reading }` for an inflected or untaught form; the layer gives `native` and `bases` meanings by target); a base once per example; a word with no taught word to build an example on keeps its count and goes in the report. Counts in brackets are cards with fewer than 2 examples.

| Id | Branch | Edits | Size | Depends on |
|---|---|---|---|---|
| BN-052 | decks/bn-examples | bn-first-words 5, bn-sound-differences 1, bn-questions 12, bn-addressing 6, bn-pronouns 14 (38) | M | BN-041..051 merged |
| BN-053 | decks/bn-examples | bn-family 18, bn-numbers-1-20 18, bn-about-me 7 (43) | M | as BN-052 |
| BN-054 | decks/bn-examples | bn-verbs 28, bn-quantities 17 (45) | M | as BN-052 |
| BN-055 | decks/bn-examples | bn-describing 15, bn-time 14, bn-location 11 (40) | M | as BN-052 |
| BN-056 | decks/bn-examples | bn-more-verbs 24, bn-grammar-postpositions 8, bn-grammar-conjunctions 7, bn-grammar-adjectives 6 (45) | M | as BN-052 |
| BN-057 | decks/bn-examples | bn-work 9 (9) | S | as BN-052 |
| BN-058 | decks/bn-examples | bn-numbers-big 90 (90; number words in examples as taught) | M | as BN-052 |
| BN-059 | decks/bn-examples | bn-food 46 (46) | M | as BN-052 |
| BN-060 | decks/bn-examples | bn-groceries 16, bn-market 3, bn-grammar-likes 1, bn-directions 6, bn-transport 3, bn-body 15 (44) | M | as BN-052 |
| BN-061 | decks/bn-examples | bn-places 19, bn-things 11, bn-home 5, bn-grammar-articles 1, bn-clothes 14 (50) | M | as BN-052 |
| BN-062 | decks/bn-examples | bn-animals 18, bn-daily-life 2, bn-grammar-conjunct-verbs 19 (39) | M | as BN-052 |
| BN-063 | decks/bn-examples | bn-sadhu-cholito 22, bn-calendar 23 (45) | M | as BN-052 |
| BN-064 | decks/bn-examples | bn-eating-out 7, bn-help 8, bn-adjectives-2 1, bn-grammar-can-must 2, bn-history 1, bn-spelling 15 (34) | M | as BN-052 |

Total 568 cards.

### 4.12 IPA, review queue, docs

| Id | Branch | Creates / edits | Content rules and exact spec | Ids | Size | Depends on | Notes |
|---|---|---|---|---|---|---|---|
| BN-065 | decks/bn-ipa | edit every `decks/bn/**` file through the tools | After every content PR (BN-002..064, whichever are built) has merged: `python3 tools/import_phonetic.py bn --write` (Wiktionary's narrow form where there is one; if the kaikki.org dump cannot be fetched, report it and run the next step alone, which the Telugu plan allows as the fallback), then `python3 tools/derive_phonetic.py bn --bracket-unchanged --write` (the owner's "every card gets the full [] notation"; the tools skip cards that already have a form). Report the counts (filled, unchanged, invalid, no ipa line). Expected: 2,119 existing cards plus the new genre, sentence, situation and script cards all get `phonetic` (the 9 sound-concept cards without a broad `ipa` are reported, not touched); no hand edit. Whether the two rules of `bn-phonetics.yaml` need widening is a separate question for the plan's reviewer, not for this run | none | tool run | all content merged | last, serial |
| BN-066 | decks/bn-queue | edit `docs/review-queue/bn.md` | Append the rows from the reports of the batch, one line each in the file's table shape (`card id`, `unit`, `question for the reviewer`, `raised by`, `date`): 066 after sentences, reading, script and tense tables (BN-002..014, 032..040) | none | S | their batches | the file's owner per batch |
| BN-067 | decks/bn-queue | edit `docs/review-queue/bn.md` | after culture, proverbs, multiword and recommendations (BN-017..029): every unread date, doubtful text or rights judgement | none | S | their batches | |
| BN-068 | decks/bn-queue | edit `docs/review-queue/bn.md` | after situations, topics, notes, examples (BN-015, 016, 030, 031, 041..064) | none | S | their batches | |
| BN-069 | main, docs (Haiku) | the #1166 checklist (issue comment), the Bengali column of `wiki/Plan-Language-Completeness.md`, the Bengali part of the build-deck skill's list if any | Straight to main, docs only: tick the boxes decks-live proves (counts from a re-read), no claim that is not verified | none | S | everything merged | docs |

Not planned for Bengali, and why: **professional decks** (`professions` is empty, the owner supplies the list first); **a Bangladeshi (Dhaka) pronunciation variety** (the course is the Kolkata standard; not on the grid; an owner question, not a blocker); **resources file** (not on the grid); **clause-form tables** as rules tables (Q3); **a facts file** (done, 41 facts; the 26 facts without a `source` are a quality matter for a later pass, not a task); **sentences for the 5 early units** (verb pool of 1); **sentences for `bn-sadhu-cholito`** (a register deck: nominal sentences only if the owner asks).

## 5. Dependency order and lanes

### 5.1 Waves

1. **Wave 1, all independent:** BN-001 (Sonnet, docs), BN-002..006, BN-007..011, BN-012, BN-015, BN-021, BN-024..027, BN-032 (Sonnet).
2. **Wave 2:** BN-013 (after BN-012), BN-014 (after BN-013), BN-016 (after BN-015), BN-017 (after BN-001), BN-022 (after BN-021), BN-033..040 (after BN-032), BN-041..051 (after BN-016).
3. **Wave 3:** BN-018, BN-023, BN-030 (after BN-012..014), BN-052..064 (after BN-041..051; optional).
4. **Wave 4:** BN-019, BN-020, then BN-028, BN-029; BN-031 (after the genre decks); BN-066, 067, 068.
5. **Last:** BN-065 (the IPA run, after every content PR), then BN-069.

### 5.2 Lanes (one shared integration branch per kind, one PR per branch, one Sonnet review per PR)

| Lane | Branch | Tasks | Notes |
|---|---|---|---|
| A, culture and creators | `decks/bn-culture` then `decks/bn-recommendations` | BN-017, 018, 019, 020, then 028, 029 | **serial**: one owner of `creators/bn.yaml` at a time; recommendations ride after the culture PR merges |
| B, topics | `decks/bn-topics` | BN-030, then 031 | serial: one file |
| C, proverbs and multiword | `decks/bn-proverbs`, `decks/bn-multiword` | BN-021, 022, 023; BN-024..027 | proverbs serial; the four multiword decks are separate files, PARALLEL |
| D, situations | `decks/bn-situations` | BN-015, 016 | serial: one file |
| E, sentences | `decks/bn-sentences` | BN-002..006 | PARALLEL (separate files; the path lines differ) |
| F, reading | `decks/bn-reading` | BN-007..011 | PARALLEL (as E) |
| G, script | `decks/bn-script` | BN-012, 013, 014 | serial: the path lines are the same |
| H, tense tables | `decks/bn-tenses` | BN-032 first, then BN-033..040 | PARALLEL after BN-032; each its own deck |
| I, notes | `decks/bn-notes` | BN-041..051 | PARALLEL with each other (disjoint files) |
| J, examples (optional) | `decks/bn-examples` | BN-052..064 | PARALLEL; after notes (same files) |
| K, IPA, queue, docs | `decks/bn-ipa`, `decks/bn-queue`, main | BN-065 serial and last; BN-066..068; BN-069 | |

### 5.3 File ownership

`decks/creators/bn.yaml`: lane A only (serial). `decks/recommendations/bn.yaml`: BN-028 then BN-029. `decks/bn/bn-topics.yaml`: BN-030 then BN-031. `decks/bn/bn-situations.yaml`: BN-015 then BN-016. `docs/review-queue/bn.md`: BN-066, 067, 068 (batch owners). `decks/bn/bn-path.yaml`: edited by BN-002..014 and BN-032..040, each only on the lines its row names; if two PRs touch adjacent lines the second rebases on `decks-live`, keeping both sides in order. `decks/bn/bn-phonetics.yaml`, `decks/min_app.json`, `decks/themes.yaml`, `decks/sections.yaml`, `decks/index.json`, the rules decks other than the new ones: no task edits them. A task that adds a new `bn-` card in a themed deck (BN-015, 016) must be merged before the notes tasks that name the same decks (BN-041..051).

### 5.4 The first six tasks to launch

| Order | Task | Agent | Why first |
|---|---|---|---|
| 1 | BN-001 (plan page) | Sonnet, docs to main | the "plan before build" gate for 14 later tasks; no PR |
| 2 | BN-032 (tense-table design and pilot) | Sonnet | the one design job; unblocks eight Haiku tasks |
| 3 | BN-002 (sentences) | Haiku | the 17-deck sentences gap; BN-003..006 follow |
| 4 | BN-007 (reading) | Haiku | the 21-unit reading gap; BN-008..011 follow |
| 5 | BN-012 (conjuncts) | Haiku | script gap; unblocks BN-013, 014, 030 |
| 6 | BN-015 (situations) | Haiku | one file, no dependency, opens the notes wave |

## 6. Candidate lists (names and seeds only; every row "rights basis, dates and text: to be read")

Nothing in this section is a verified date, text or rights status. A builder drops any entry it cannot read on its cited page. BN-001 turns these into the wiki sourcing page; if the page and a row differ, the page wins.

### 6.1 Culture (BN-017 to BN-020)

**BN-017, `bn-culture-1`: early and medieval Bengali** (bn-5700 to 5749). Candidates in order (work, creator): 1 Charyapada (Charyagiti), anonymous, several siddhas; 2 Shrikrishnakirtana, Baru Chandidas; 3 a Vaishnava pada ("Sai keba sunaila shyam naam"), Chandidas; 4 a Vaishnava pada, Govindadas; 5 Krittivasi Ramayan, Krittibas Ojha; 6 Mahabharat, Kashiram Das; 7 Chandimangal, Mukundaram Chakrabarti; 8 Manasamangal, Bijay Gupta; 9 Annadamangal, Bharatchandra Ray; 10 Padmavati, Alaol; 11 Chaitanya Charitamrita, Krishnadas Kaviraj; 12 Shyama sangeet ("Mon re krishikaj jano na"), Ramprasad Sen; 13 Baul song ("Khanchar bhitor ochin pakhi"), Lalon Fakir; 14 a folk song, Hason Raja; 15 Khanar Bachan, anonymous attributed; 16 Dakar Bachan, anonymous attributed; 17 Maymansingha Gitika, a ballad such as Mahua, anonymous; 18 a nursery rhyme or lullaby ("Khoka ghumalo para juralo"), anonymous traditional. Reserve: Dasarathi Ray (Panchali), Nidhu Babu (Ramnidhi Gupta, tappa), a Bhatiyali song, Gopal Bhar anecdotes (oral).

**BN-018, `bn-culture-2`: the nineteenth century** (bn-5750 to 5799). 1 Barnaparichay, Ishwar Chandra Vidyasagar; 2 Betal Panchavimshati, Vidyasagar; 3 Sitar Banabas, Vidyasagar; 4 Meghnad Badh Kavya, Michael Madhusudan Dutt; 5 Kapotaksha Nad (sonnet), Madhusudan Dutt; 6 Bangabhasha (sonnet), Madhusudan Dutt; 7 Anandamath, including Vande Mataram, Bankim Chandra Chattopadhyay; 8 Durgeshnandini, Bankim; 9 Kapalkundala, Bankim; 10 Kamalakanter Daptar, Bankim; 11 Alaler Gharer Dulal, Peary Chand Mitra; 12 Hutom Pyanchar Naksha, Kaliprasanna Singha; 13 Nil Darpan, Dinabandhu Mitra; 14 Bishad Sindhu, Mir Mosharraf Hossain; 15 Palashir Yuddha, Nabinchandra Sen; 16 Padmini Upakhyan, Rangalal Bandyopadhyay; 17 Alo o Chhaya, Kamini Roy; 18 Parivrajak, Swami Vivekananda. Reserve: Kulin Kulasarbaswa (Ramnarayan Tarkaratna), Swarnalata (Tarakanath Gangopadhyay), Girish Chandra Ghosh (a play), Rameshchandra Dutt.

**BN-019, `bn-culture-3`: Tagore, his circle and children's classics** (bn-5800 to 5849). 1 Amar Sonar Bangla, Rabindranath Tagore; 2 Ekla Cholo Re, Tagore; 3 Jana Gana Mana, the original Bengali words, Tagore; 4 Chitto Jetha Bhayshunyo, Tagore; 5 Sonar Tari, Tagore; 6 Dui Bigha Jomi, Tagore; 7 Birpurush, Tagore; 8 Kabuliwala, Tagore; 9 Postmaster, Tagore; 10 Chhuti, Tagore; 11 Shesher Kobita, Tagore; 12 Gora, Tagore; 13 Dhana Dhanya Pushpa Bhara, Dwijendralal Roy; 14 Moder Gorob Moder Asha, Atulprasad Sen; 15 Abol Tabol, Sukumar Ray; 16 Hajabarala, Sukumar Ray; 17 Tuntunir Boi, Upendrakishore Ray Chowdhury; 18 Kheerer Putul, Abanindranath Tagore. Reserve: Rajanikanta Sen (a song), Satyendranath Dutta (Jharna), Jagadish Chandra Bose (Abyakta), a second Tagore song or story. Tagore's items are capped at 12 of the 18 so the deck is not all one author.

**BN-020, `bn-culture-4`: twentieth-century fiction and poetry by authors who died by 1955** (bn-5850 to 5899). 1 Pather Panchali, Bibhutibhushan Bandyopadhyay; 2 Aparajito, Bibhutibhushan; 3 Aranyak, Bibhutibhushan; 4 Chander Pahar, Bibhutibhushan; 5 Ichhamati, Bibhutibhushan (rights to be read closely: the date of first publication); 6 Devdas, Sarat Chandra Chattopadhyay; 7 Srikanta, Sarat Chandra; 8 Pather Dabi, Sarat Chandra; 9 Mahesh, Sarat Chandra; 10 Parineeta, Sarat Chandra; 11 Ramer Sumati, Sarat Chandra; 12 Banalata Sen, Jibanananda Das (died 1954: to be read); 13 Abar Asibo Phire, Jibanananda Das; 14 Runner (Ranar), Sukanta Bhattacharya; 15 Abarodhbasini, Begum Rokeya; 16 Abyakta, Jagadish Chandra Bose; 17 Char-iyari Katha, Pramatha Chaudhuri; 18 Ruposhi Bangla, Jibanananda Das (rights and first-publication date to be read: expect it to be dropped). Not eligible: Kazi Nazrul Islam, Tarashankar Bandyopadhyay, Manik Bandyopadhyay (recommendations only).

### 6.2 Proverbs seeds (BN-021 to BN-023)

The builder checks these first on bn.wikiquote and bn.wikisource and keeps only what it reads: অতি লোভে তাঁতি নষ্ট; অতি দর্পে হত লঙ্কা; এক হাতে তালি বাজে না; যত গর্জে তত বর্ষে না; চোরের মায়ের বড় গলা; নাচতে না জানলে উঠান বাঁকা; যেমন কুকুর তেমন মুগুর; অল্প বিদ্যা ভয়ংকরী; ঢেঁকি স্বর্গে গেলেও ধান ভানে; দশের লাঠি একের বোঝা; যার শেষ ভালো তার সব ভালো; কাক কাকের মাংস খায় না; গাছে কাঁঠাল গোঁফে তেল; রাখে হরি মারে কে; দুধ কলা দিয়ে কালসাপ পোষা; পরের ধনে পোদ্দারি. Plus the proverbs the cited pages list under the themes of each task. Candidates are seeds only: none is yet read on a page.

### 6.3 Multiword seeds (BN-024 to BN-027)

- Noun plus করা: সাহায্য করা, কাজ করা, চেষ্টা করা, ফোন করা, স্নান করা, রান্না করা, শুরু করা, ব্যবহার করা, বিশ্বাস করা, অপেক্ষা করা, চিন্তা করা, পছন্দ করা, যোগাযোগ করা, প্রশংসা করা, ক্ষমা করা.
- Noun or adjective plus another verb: ভয় পাওয়া, ঘুম পাওয়া, খিদে পাওয়া, কষ্ট পাওয়া, ঠান্ডা লাগা, জ্বর হওয়া, রাগ হওয়া, দেরি হওয়া, মনে হওয়া, ঘুম আসা.
- Aspectual compounds: খেয়ে ফেলা, করে ফেলা, হারিয়ে ফেলা, পড়ে যাওয়া, ভুলে যাওয়া, উঠে পড়া, ঘুমিয়ে পড়া, বসে পড়া, জেগে ওঠা, বলে দেওয়া, দিয়ে দেওয়া, রেখে দেওয়া, ধরে রাখা, দেখে নেওয়া, লিখে নেওয়া, নিয়ে আসা, বেরিয়ে যাওয়া.
- Idiomatic: মনে পড়া, মনে রাখা, মন দেওয়া, ধরা পড়া, মাথা ঘামানো, চুপ করা, কান পাতা, পা বাড়ানো.

### 6.4 Recommendations (BN-028, BN-029)

Creators named are the works' creators as the builder reads them; none is checked here. **Batch 1, audiovisual (10):** Pather Panchali (film, Satyajit Ray), Charulata (film, Ray), Sonar Kella (film, Ray), Goopy Gyne Bagha Byne (film, Ray), Meghe Dhaka Tara (film, Ritwik Ghatak), Jalsaghar (film, Ray), Matir Moina (film, Tareque Masud), Autograph (film, Srijit Mukherji), Chokher Bali (film, Rituparno Ghosh), Hawa (film, Mejbaur Rahman Sumon). Reserve: Apur Sansar, Ghare Baire, Bhooter Bhabishyat. **Batch 2, books, comics, songs and radio (10):** Shei Samay (Sunil Gangopadhyay), Hajar Churashir Maa (Mahasweta Devi), Debi (Humayun Ahmed), Himu stories (Humayun Ahmed), Ganadevata (Tarashankar Bandyopadhyay), Padma Nadir Majhi (Manik Bandyopadhyay), Nonte Phonte (comic strip, Narayan Debnath), Bantul the Great (comic strip, Narayan Debnath), Ami Banglay Gaan Gai (song), Mahishasuramardini (radio programme, Birendra Krishna Bhadra). Reserve: a Feluda story (Satyajit Ray), Byomkesh stories (Saradindu Bandyopadhyay). A `medium` is one of film, series, book, comic, song, podcast, radio, play; nothing of a work is quoted.

## 7. Open questions for the owner (defaults taken, none blocks)

- **Q1. Tense tables: add or replace?** Default taken: add rules decks beside the pattern decks (ids permanent; the course already pairs the two kinds). The alternative, replacing a pattern deck, would retire its cell ids and orphan their history.
- **Q2. The examples wave** (BN-052..064, 568 cards): it is not one of the 18 deliverables and not yet a validator error. Default taken: built last; the owner may drop it.
- **Q3. Clause forms as rules tables** (conditional, purpose, before-after, while, concessive, relative, causative, passive, reported speech, honorifics): not tense tables, each a small chosen set today; default taken: not planned.
- **Q4. Rights.** The plan applies the validator's floor (died 1955 or earlier). Because India's term is life plus 60, an author who died in 1955 is out of copyright since 2016; items from authors who died 1941 to 1955 are flagged **to be read** rather than excluded. Jibanananda Das (died 1954) and Bibhutibhushan Bandyopadhyay (died 1950) are the cases the builder reads closely.
- **Q5. Bangladeshi pronunciation** is not on the grid and not planned; the course is the Kolkata standard, as the registry says.
- **Leftover branch:** `origin/deck/bn-b1-3` is not an open PR and shares no history with `decks-live`; agents cannot delete a remote branch, so it is listed for the owner.
- **Q6. Existing Bengali readings and the transcribe tool.** Decision (parent session, 2026-11-15, default; the owner can overturn): after the ba-phala fix (#1398, #1399), `tools/transcribe_decks.py --check decks/bn bn` reports about 7,300 differences, mostly where the course's hand conventions (schwa kept, ś, final -o, ব-ফলা written as v) differ from the tool. The course's hand conventions stay; `--fix --all` is not run for Bengali and the tool stays advisory for bn. Only clear ba-phala and garble fixes were applied (PR #1434). The র্ব and য-ফলা garbles are fixed in the tool under #1402; schwa and ś tuning is out of scope. New cards are still written with the tool, using hints that match the course convention.

## 8. Notes for the architect

- `decks/sections.yaml`, `decks/themes.yaml`, `decks/min_app.json` and `decks/index.json` are not edited by any task (no new theme is needed because genre decks carry `genre`, not `theme`; the index is regenerated; a new situation card goes into an existing themed deck).
- Culture, proverbs and multiword decks are woven into the app only once the language-list culture setting exists; building them does not wait for it.
- Under rule 17 the architect runs as many Haiku workers as the work needs, minus two for each running Sonnet review. BN-001 and BN-032 are the two Sonnet jobs besides the reviews.
- No task here sets a `phrasebook` flag, changes a card id, or adds a noun, verb or adjective to a path deck.

## 9. Progress 2026-11-15

Re-read from `origin/decks-live` (a2e24af3, 2026-11-15) with read-only PyYAML scripts; the counts below are of files, not of quality. Nothing was run through the validator or the tests (CI only). The grid in [Plan-Language-Completeness](Plan-Language-Completeness.md) section (b) carries the same numbers.

### 9.1 Pull requests merged to decks-live

#1401 script (conjuncts 2 and 3, reading 2), #1403 situations, #1404 reading decks for 21 units, #1405 sentences decks for 17 units, #1410 tense tables as rules tables, #1415 proverbs 1 to 3, #1416 multi-word verbs, #1420 notes, #1430 culture 1 to 4 and creators, #1434 readings (ba-phala and garble fixes), #1447 topics, #1448 review-queue rows, #1454 recommendations, #1458 narrow IPA.

### 9.2 Done per task range

| Tasks | State | Verified count |
|---|---|---|
| BN-001 | done | `Plan-Culture-Bengali` on main |
| BN-002 to 006 sentences | done | 83 sentence decks (was 66), 916 own cards; the 17 themed word units that had none now have one |
| BN-007 to 011 reading | done | 73 reading files, 154 passages; all 72 path units that name reading passages have a reading deck (was 21 without) |
| BN-012 to 014 script | done | conjuncts 25 + 25 + 25, reading words 16 + 30, plus vowels 11, consonants 39, signs 18, digits 10 |
| BN-015, 016 situations | done | `bn-situations`, 10 sheets; 18 new phrase cards bn-6250 to bn-6267 |
| BN-017 to 020 culture | partly short | `bn-culture-1` to `-4` hold 13, 15, 15 and 15 cards instead of 18 each; 38 creators and 5 eras in `decks/creators/bn.yaml` |
| BN-021 to 023 proverbs | done | 20, 20, 20 |
| BN-024 to 027 multi-word | done, one short | 19 (`conjunct-kora`, BN-024), 20 (`conjunct-other`, BN-025), 20 (`aspectual`), 20 (`idiomatic`) |
| BN-028, 029 recommendations | done | 20 entries (10 films, 6 books, 2 comics, 1 song, 1 podcast) |
| BN-030, 031 topics | done | 23 topics |
| BN-032 to 040 tense tables | done | 10 rules decks (`bn-grammar-verb-*`, 417 to 418 verb rows each), added beside the pattern decks (Q1 default) |
| BN-041 to 051 notes | done for the planned decks | 640 own non-set cards still have no `notes` in their core file (638 when a note in the English layer counts; 476 of them are sentence cards); the plan counted 1,035 |
| BN-052 to 064 examples | not built | owner question Q2; about 600 of 2,780 word cards still have fewer than 2 examples (counted as vocab cards that are not genre, sentence, script or phrase cards) |
| BN-065 IPA | rules-derived only | `phonetic` and `ipa` on 4,296 of 4,305 non-set cards, all `phonetic_source: "rules"`; the 9 without are sound-concept cards (bn-2055 to bn-2062, bn-2089) |
| BN-066 to 068 review queue | done | 77 rows in `docs/review-queue/bn.md` (9 from 2026-11-07, 68 from 2026-11-15) |
| BN-069 | this section, the grid and the #1166 comment | |

Other counts: path 173 entries, every deck it names has a file, 2,833 words; 244 cores (198 vocab, 30 grammar, 14 rules, `bn-script`, `bn-sounds`) and 244 layers, none orphaned; 4,305 non-set own cards, 27 set cards, 175 refs, no duplicate id; phrasebook 20 cards; facts 41.

### 9.3 Decisions taken by default (the owner may overturn)

- **Readings:** the course's hand conventions stay (Q6); `transcribe_decks.py --fix --all` was not run for Bengali; only the ba-phala and garble fixes were applied (#1434), and four stale cards were rederived.
- **Narrow IPA:** the Wiktionary narrow form was dropped; every `phonetic` is from the rules (`derive_phonetic.py`).
- **Tense tables:** rules decks added beside the pattern decks, nothing replaced (Q1).

### 9.4 Gaps that remain

- **Professional decks:** held, `professions` is empty until the owner supplies the list.
- **Examples wave** (BN-052 to 064): not built.
- **Culture:** 58 of 72 planned cards exist (13, 15, 15 and 15); the missing items are those whose text or date could not be read on a cited page, so they were dropped instead of filled in from memory.
- **Recommendations:** 20 entries, no links checked.
- **Reviewer decisions:** every deck is `unreviewed`; the situations sheets are draft; the 77 queue rows wait for a bilingual reviewer.
- **Notes:** 640 cards without a note (see the table).

### 9.5 Open owner questions

Q2 (examples wave: build or drop), Q3 (clause forms as rules tables: not planned), Q4 (rights for authors who died 1941 to 1955), Q5 (Dhaka pronunciation), Q6 (hand conventions in readings), and the professional list. Q1 was taken by default (above).

### 9.6 Leftover remote branches for the owner to delete

Agents cannot delete a remote branch. On the remote (`git ls-remote --heads origin`, 2026-11-15) only one Bengali branch is left: `deck/bn-b1-3` (last commit 2026-10-23, not an open PR, no shared history with `decks-live`). All 14 branches of this wave (`decks/bn-sentences`, `-reading`, `-readings`, `-script`, `-situations`, `-culture`, `-proverbs`, `-multiword`, `-recommendations`, `-topics`, `-tenses`, `-notes`, `-ipa`, `-queue`) were merged by PRs #1401 to #1458 and are no longer on the remote (the local remote-tracking refs are stale until `git fetch --prune`).

## 10. App-measure close-out (owner directive 2026-11-17)

Owner directive, relayed 2026-11-17: complete every A and B list language with no accepted gaps; close everything on [Plan-Language-Completeness](Plan-Language-Completeness.md) for Bengali, measured the way the app measures it: stage Complete, completeness 100%, grammar written, culture 72 of 72, then every genre deck (creators, recommendations, proverbs, multi-word verbs, topics, situations, professional on the shared professions list), a note on every card with a teachable point, examples, narrow IPA, readings, and the Bengali "oo" typos fixed. This section replaces the "held" and "dropped" defaults of sections 7 and 9 where they conflict (professional decks, the examples wave, the short culture decks). Task ids `BN-100` to `BN-152`. Nothing here is built.

All numbers were read on 2026-11-17 from `origin/decks-live` (f10c4bc2f) with read-only PyYAML scripts over `decks/bn/**`, `decks/index.json`, `decks/sections.yaml`, `decks/creators/bn.yaml` and `decks/recommendations/bn.yaml`; no validator, no tests. The app's own formulas were read in `lib/core/decks/language_catalog.dart` (`B1Progress.of`, `CourseStage`, `cultureCardTarget = 72`) and `tools/deck_index.py` with `tools/validate_decks.py` (`_unit_words`, `counts_as_word`) on `origin/main` (f374df0fa).

### 10.1 How the app measures, and what Bengali scores

- **Completeness** = Σ min(`has`, `words`) over the units up to the one marked B1, divided by Σ `words`; a unit not written counts 0; the app shows the whole percent **rounded down**, so 100% needs every unit full.
- **`has`** of a unit (`_unit_words`) = the distinct cards, in the unit's core decks and listed by `ref`, of a `vocab` deck, that count as words (`counts_as_word`: not `phrasebook`, **not `pos: "phrase"`**, a one-word target or a `pos` of noun, verb, adj, adv or pronoun). Script (alphabet) decks and grammar tables are left out. A multi-word card typed `phrase` therefore adds nothing.
- **Stage:** Alpha until every unit up to A1 is written, Beta until every unit up to B1 is, Complete after. **Grammar** = topics taught over topics planned up to B1. **Levels** A1, A2, B1 = the same sum over each level's units. **Culture** = cards of the language's `genre: culture` core decks over 72, capped at 1.

| Measure | Now on decks-live | Needed | State |
|---|---|---|---|
| Units to the B1 mark | 190 (path entries 0 to 189), 0 planned, all written | all written | done |
| Planned words to B1 | 2,833 | | |
| Words counted (Σ min) | 2,816 | 2,833 | **99.4%, the app shows 99%**, 17 short |
| Stage | Complete | Complete | done |
| A1 / A2 / B1 share | 809 of 809 (100%) / 805 of 822 (97%) / 1,202 of 1,202 (100%) | 100% each | A2 short |
| Grammar written | 83 of 83 | all | done |
| Culture | 58 of 72 (13 + 15 + 15 + 15) = 80% | 72 | 14 short |
| Units short (has < words) | **1** | 0 | see below |

**The one unit short:** path entry 75 (A2), decks `bn-illness`, `bn-illness-sentences` and `"*"`: planned 50, has 33, **missing 17 words**. `bn-illness` holds 50 cards but 17 of them are `pos: "phrase"` (bn-1777, 1788 to 1790, 1793 to 1805: verb phrases, noun phrases and adverbials such as `ওষুধ খাওয়া`, `খালি পেটে`), which the app does not count. Every other unit is at or above its plan. No planned count looks unreachable: 17 more single-word illness nouns are reachable (the course has none yet for infection, allergy, virus, burn, itch, boil, symptom, capsule, ointment, antibiotic, kidney, cancer and others, checked against every bn target on 2026-11-17).

**The index agrees.** `decks/index.json` on decks-live carries `has` per unit (`units[i].has.en`); my recompute from the YAML equals it on every unit with words. The only differences are units the app leaves out by rule: the two alphabet units (6 and 7: my count included script cards, the index says 0) and `bn-spelling` (unit 191, past the B1 mark, index 0). The same index gives the culture count: 58 cards (13, 15, 15, 15), proverbs 60, multi-word 79.

### 10.2 State of every other deliverable (decks-live, 2026-11-17)

| Item | Now | Target and state |
|---|---|---|
| Culture | 58 cards in `bn-culture-1` to `-4` | 72 (18 each): **14 missing** (5 in `-1`, 3 in each of `-2`, `-3`, `-4`); free ids bn-5713 to 5749, 5765 to 5799, 5815 to 5849, 5865 to 5899 |
| Creators and eras | 38 creators, 5 eras in `decks/creators/bn.yaml` | each new culture card needs its creator (BN-102 to 105 add them) |
| Recommendations | 20 entries (`decks/recommendations/bn.yaml`) | 20 is the target of the Kannada, Spanish and French pages: **done** (links unchecked, an old doubt) |
| Proverbs | 60 (20, 20, 20) | 60: done |
| Multi-word verbs | 79 (20, 19, 20, 20) | 80: **1 short** in `bn-multiword-conjunct-kora` (19); the builder reported fewer than 20 attested |
| Topics | 23 in `bn-topics.yaml` | done |
| Situations | 10 sheets in `bn-situations.yaml` (draft) | done |
| **Professional** | **none**: no file with `genre: professional` | **6 decks to build** (10.4); `professions` is no longer empty: `decks/sections.yaml` on decks-live lists `medicine`, `hospitality`, `business` |
| Notes | **640** own non-set cards have no note, in the core or the layer (476 sentence cards, 164 word cards: bn-numbers-big 66, bn-calendar 15, bn-groceries 13, bn-home 10, bn-help 9, bn-numbers-1-20 8 and 52 others) | a note on every card **with a teachable point** (10.5) |
| Examples | 2,780 word cards; **599** have fewer than 2 examples in 48 decks; 568 once the 31 sound-inventory cards of `bn-phonology-*` are left out | at least 2 on every word card (build-deck skill, mandatory set) |
| Narrow IPA | `phonetic` on every card that has `ipa`: 0 missing; 9 cards have neither (bn-2055 to 2062, bn-2089: sound concepts, no reading) | new cards written below get theirs from the tools (BN-151) |
| **"oo" typos** | 9 cards, 4 grammar rows, 2 reading passages, 1 layer note (10.6) | fix |
| **"rr" for র্ব** | 23 cards read `rr` where the same course reads `durbol` and `purbo` (10.6) | fix (found in this audit; the cause is #1402's র্ব bug, which #1436 fixed in the tool) |
| #1402 | closed; #1436 fixed র্ব and the য-ফলা final vowel; a follow-up is open in its last comment: reph + য words (কার্য, সূর্য, আর্য) lose their last vowel in `bn` (`kārj`), plus a docstring wording | not blocking: the deck readings of these words are hand-entered and correct (`surjo`, `kārjāloy`); no Bengali task depends on it |

### 10.3 Reserved id ranges for section 10

Highest bn id on decks-live: `bn-6267`. Section 2's ranges stay as they are; the new ones start at `bn-7000` so that nothing collides. Ids are four digits, ascending, never reused. The unused parts of the culture ranges of section 2 are used by the culture tasks.

| Range | Task | Use |
|---|---|---|
| bn-7000 to bn-7049 | BN-100 | the 17 new illness nouns (ids 7000 to 7016; the rest spare) |
| bn-7100 to bn-7149, 7150 to 7199, 7200 to 7249 | BN-106, 107, 108 | professional decks: medicine, hospitality, business (about 9 new phrase cards per deck; each task takes two decks, 25 ids each) |
| bn-5713 to 5717, 5765 to 5767, 5815 to 5817, 5865 to 5869 | BN-102 to 105 | the 14 missing culture cards (spare ids stay unused) |
| bn-7300 to bn-7399 | none | spare for repairs found in review |

Tasks that add no card (notes, examples, repairs, IPA, queue rows, docs) reserve none. The multi-word card for `conjunct-kora` and any new situation card come from the free repair ranges of section 2 (bn-6350 up).

### 10.4 Professional decks: the Kannada pattern (#1540), copied for Bengali

Read on decks-live: `decks/kn/kn-medicine-clinic.yaml` and its layer `decks/kn/en/kn-en-medicine-clinic.yaml`, the other five `kn-*` professional decks, the Spanish and Marathi ones, `decks/sections.yaml`, the PR #1540 commit (38e337672) and `wiki/Plan-Deck-Kinds-And-Topics.md` D1, D3, D8.

- **The list of professions is one shared list**, `professions:` in `decks/sections.yaml` (deck-owned data on decks-live, mirrored on main): `medicine`, `hospitality`, `business`. A language does not add a profession; a deck names one in `professional:`; the validator refuses an unlisted id.
- **Six decks per language, two situations per profession** (Kannada, Spanish and Marathi all have exactly these): `medicine-clinic` (level B1), `medicine-pharmacy` (A2), `hospitality-reception` (A2), `hospitality-restaurant` (A2), `business-email` (B1), `business-meeting` (B1). Marathi has all six at B1; Kannada's and Spanish's levels are the ones used here.
- **Files:** core `decks/bn/bn-<profession>-<situation>.yaml` (for example `bn-medicine-clinic.yaml`) and layer `decks/bn/en/bn-en-<profession>-<situation>.yaml`. Header of the core: `schema: 1`, `id`, `part: "core"`, `kind: "vocab"`, `language` block as `bn-weather`, `license: "CC-BY-SA-4.0"`, **`genre: "professional"`, `professional: "<profession id>"`, `hidden: true`, `level: "A2"` or `"B1"`**, `tags: ["unreviewed"]`; no `theme`, **no entry on the path** (a path may not name a hidden deck; the deck is reached by search under Situations and from its profession), no `weave`. Layer: `kind: "layer"`, `core`, `native: { code: "en", ... }`, `name` such as "Medicine: a clinic appointment", a one-sentence `description`, `cards:` keyed by id with `native` (one plain English sentence) and `notes`, keyed `n1`.
- **Cards: 16 to 20 per deck, about half new and half `ref`.** Kannada: 18 to 23 cards per deck, 9 to 13 of them `- ref: "kn-NNNN"` to already-taught words (the field's words a learner has met) and the rest **new cards, `pos: "phrase"`**, whole sentences or fixed phrases said in that setting, with `modes: ["recognition", "production", "listening"]`, `reading`, `ipa` and `phonetic` from the tools, a `usage` note where one point is teachable (the polite imperative, a case ending, a form of address). 56 new phrase cards in all six Kannada decks; Spanish 5 to 9 refs each. New words that are not yet cards are not added as word cards (a genre deck owes no rules rows, but this plan adds only phrases): a needed word the course does not teach is reported, never coined.
- **Register:** the polite `আপনি` (āpni) forms throughout the clinic, reception, restaurant and business decks (a doctor to a patient, staff to a guest); the pharmacy deck uses the same. Doubts of register or field go to `docs/review-queue/bn.md`, as Kannada did (11 rows in `docs/review-queue/kn.md`). A field reviewer is recorded later as `checked_by` with `role: field`.
- **Not built by hand:** readings and `ipa` from `python3 tools/transcribe.py bn "<text>" "<hint>"`, `phonetic` from BN-151. `decks/index.json` is regenerated by decks-live's workflow; `min_app` is the kinds gate set by the tools, not by the task.
- **Cards that reuse refs** must name ids that exist on decks-live when the task starts; the builder lists every ref with its target in its report.

### 10.5 Notes on every card with a teachable point (BN-110 to BN-117)

The earlier pass left 640 cards without a note as "nothing to teach". The audit samples 60 of them (seed 7: 46 sentence cards, 12 number words, 2 word cards) and finds a teachable point on all but a few. The classes in which a note is possible (counts are of a heuristic scan of the 640 targets; the remaining 81 are plain first-person or third-person statements and bare nouns, listed for BN-110 to decide):

| Class | Cards | The point | Note kind |
|---|---|---|---|
| N1 numbers | 84 (`bn-numbers-big` 66, `bn-numbers-1-20` 8, sentences 10) | from 21 to 99 the tens and units fuse into forms to learn whole (`ছত্রিশ` chotriś, `আটানব্বই` āṭānobboi); the 1 to 20 forms are irregular | `usage` |
| N2 locative `-e`/`-te` | about 131 | place and time take `-এ` or `-তে` (`বাজারে` bājāre, `জানালা` ...) | `usage` |
| N3 genitive `-r`/`-er` | about 119 | `-র`/`-এর` for of and the possessor (`আপেলের দাম`, `মাসের প্রথম দিন`) | `usage` |
| N4 classifier / definite | about 103 | `-টা` (ṭā), `-টি` (ṭi), `-গুলো`: the definite or counted noun (`হাতিটা`, `খবরটা`) | `usage` |
| N5 object `-ke` | about 43 | `-কে` marks the person or the specific object (`ছেলেকে`) | `usage` |
| N6 verb endings and respect | about 45 | `-েন` for `তিনি` and `আপনি`; `-ও` with `তুমি`; `-ো` for `তুই`; imperatives `দাও`, `দিন`; past `-ল`/`-লো`; perfect `-েছে` | `usage` |
| N7 compound and conjunctive verbs | about 4 | `উঠে গেল`, `করে`, `নিয়ে` | `usage` |
| N8 calendar | 15 | month and day names: the Bengali months and the English ones in use, `অক্টোবর` | `culture` or `note` |
| N9 loan words and word origin | the word cards without a class above (`bn-groceries`, `bn-home`, `bn-help`) | a word borrowed from English or Persian, or with a surprising plural or form | `note` |

- **Sentence cards** carry one note on the single most notable form of the sentence; a card is left without a note only if none of the classes applies, and is listed in the worker's report with its id (expected under 5%).
- **BN-110 (Sonnet)** first writes the exact note wording for each class (one English template per class, with the reading of each Bengali word copied from the card, using only the seven note kinds the validator knows) as a table appended to this page, so the Haiku tasks fill templates and never invent a rule. Facts about a form (a number's fusion, a month's origin) are read on a cited source page or left out.
- RULE-NOTE-BN of section 3.1 applies unchanged: id and `kind` in the core, text in the layer, every non-Latin word followed by its reading in half-width parentheses.

### 10.6 Reading repairs: "oo" and "rr" (BN-120)

**"oo" in the readings of ওয়-loanwords.** The rules fallback of `tools/transcribe.py` writes the glide of `ওয়` as `ooy`; with a hint that fits it writes `oy`. Searching every `reading`, `ipa` and `phonetic` of `decks/bn/**` for a doubled vowel finds 136 occurrences; the intentional ones are the course's hand conventions (`dii`, `nii`, `tumii`, `āmii` for ই after ি; `āroo`, `jôroo`, `ājoo`, `rānoo`, `pāṭoo` for ও, also, after r, n, j, ṭ; `dhoo`, `śoo`, `hôoyā`) and the vowel-concept card `oo̯`; they stay. The typos are four words: `সফটওয়্যার`, `পাসওয়ার্ড`, `নেটওয়ার্ক`, `মাইক্রোওয়েভ`, in nine cards, four grammar rows and two passages:

| Cards and places | Now | Expected, from `tools/transcribe.py` with a fitting hint |
|---|---|---|
| bn-3246 (`bn-technology`, card, `n1` and 2 examples), `bn-grammar-noun-forms` row of the word | `sôphoṭooyyār` (also an extra `o`: `sôphoṭ`) | `python3 tools/transcribe.py bn "সফটওয়্যার" "sophtoyyar"` gives `sôphṭoyyār` |
| bn-2404 (`bn-phone`), bn-3261 (example in `bn-technology`), bn-3299 (`bn-technology-sentences`), bn-0065 (`bn-script-vowel-signs`, example), bn-2399 (example), row in noun-forms, passages `bn-fixing-a-phone`, `bn-app-instructions` (`bn-en-reading-technology`) | `pāsooyārḍ` | `... bn "পাসওয়ার্ড" "pasoyard"` gives `pāsoyārḍ` |
| bn-2400 (`bn-phone`, 2 examples), noun-forms row | `neṭooyārk` | `... bn "নেটওয়ার্ক" "netoyark"` gives `neṭoyārk` |
| bn-3973 (`bn-housing`, `n1` and 2 examples), bn-0084 (`bn-script-conjuncts`, example), noun-forms row | `māikrooyebh` | **doubtful: the tool accepts `maikrooyebh` and refuses `maikroyebh` ("hint did not fit"), so it stays; BN-120 adds a review-queue row and changes nothing** |

Also `bn-en-grammar-verb-classes` line 35 (note text mentions one of these words) is checked.

**"rr" for র্ব, found in this audit.** 23 cards read `rr` for র্ব, though the same course reads `bn-1763` `durbol` and `bn-1079` `purbo`; the cause is the old tool bug of #1402, fixed by #1436. The tool now gives `durbolotā` for `"দুর্বলতা" "durbolota"` and `nirbācon` for `"নির্বাচন" "nirbacon"`. Cards (id, target, now): bn-4502 `নির্বাচন করা` nirrācon kôrā; bn-4271 `দুর্বলতা` durrolotā; bn-2721 `পূর্বে` purre; bn-3205 `নির্বাচিত` nirrācit; bn-3210 `নির্বাচিত হওয়া` nirrācit hôoyā; bn-3447 `কার্বন কমানো দরকার।`; bn-3449 `এই মাটি উর্বর।`; bn-5918, bn-5919 (proverbs); bn-5026 `পূর্ব দিকে আমার বাড়ি।` (`purr dike`); bn-3397, bn-3434 `পুনর্ব্যবহার` (and `করা`); bn-3403 `কার্বন`; bn-3429 `উর্বর`; bn-3439 `সর্বত্র`; bn-5855 (`অপূর্ব্বর`, a sadhu spelling: check); bn-2894 `নির্বাচন`; bn-2822 `গর্বিত`; bn-3223 `নির্বাচিত মেয়র আজ এসেছেন।`; bn-3757, bn-3796, bn-3801 `আশীর্বাদ` forms; bn-2766 `চর্বি`. BN-120 reruns the tool with a hint that spells the `b` (`dur-bo-lo-ta`) for each card, copies the tool's reading and `ipa`, deletes the card's `phonetic` and `phonetic_source` (BN-151 rewrites them), and lists any card where the tool still gives `rr` instead of guessing. The reading of a word inside an example, a base or a grammar row of the same word is fixed with it.

### 10.7 Task table (section 10)

Rules as sections 3 and 5.2: one shared integration branch per kind, one PR to `decks-live` per branch with one Sonnet review, Haiku tasks never improvise and report, readings and IPA tool-written only, no tests or validator run locally.

| Id | Branch | Creates / edits | Exact content rules | Ids | Size | Depends on | Model |
|---|---|---|---|---|---|---|---|
| BN-100 | decks/bn-close-words | edit `decks/bn/bn-illness.yaml`, `decks/bn/en/bn-en-illness.yaml` | Add **17 new single-word nouns** (`pos: "noun"`, one-word target) of the illness and doctor theme the course does not have: from this seed list of 20 English meanings, each looked up on bn.wiktionary or a cited dictionary page, 17 kept: infection, allergy, virus, germ, operation (surgery), blood pressure (one word if attested), burn, itch, boil, a patient's diet, capsule, ointment, drops, symptom, cancer, heart disease, kidney, antibiotic, painkiller. A word not found on a page is dropped; fewer than 17 found: report the count. Shape of the existing cards (`bases: "self"`, `reading`, `ipa` by the tool with a fitting hint, `pos`, 2 `examples` of taught words only, a `usage` or `note` where one point is teachable, `synonyms` by `ref` where a card exists). Layer: `native`, `bases`, example meanings, notes. Path file untouched (`words: 50` stays). | bn-7000 to bn-7016 | M | none | Haiku |
| BN-101 | decks/bn-close-words | edit `decks/bn/bn-grammar-noun-forms.yaml` | One row for each of the 17 new nouns in the table's slots (`plural`, `gen`, `loc`, `ke`, `theke`, `sathe`), forms by the pattern of the existing rows (mass or abstract nouns: `plural: null`; `-গুলো`, `-র`/`-এর`, `-এ`/`-তে`, `থেকে`, `-র সঙ্গে`), readings from the tool, never by hand; **after** BN-120 has fixed the file's `ooy` rows. Check no other path-listed rules table owes a row for a noun. | none | S | BN-100, BN-120 | Haiku |
| BN-102 | decks/bn-close-culture | edit `bn-culture-1.yaml`, layer, `decks/creators/bn.yaml` | **5 more items** (13 to 18). RULE-CULT-BN (section 3.3): public-domain, one verse or line of at most 25 words as on the cited Wikisource edition, `source` block with a page read by the builder. Candidates not yet in the deck, in order (names only, nothing verified here): Khanar Bachan, Dakar Bachan, Maymansingha Gitika (a ballad such as Mahua), the lullaby "Khoka ghumalo para juralo", Charyapada, Shrikrishnakirtana (Baru Chandidas), Mahabharat (Kashiram Das), Chandimangal (Mukundaram), Manasamangal (Bijay Gupta), Padmavati (Alaol). An item whose text or date is not read on a cited page is dropped and the next one tried; every creator or era new to `decks/creators/bn.yaml` gets its entry (bio and legacy each sourced). | bn-5713 to bn-5717 | M | none | Sonnet |
| BN-103 | decks/bn-close-culture | edit `bn-culture-2.yaml`, layer, creators | **3 more** (15 to 18), the nineteenth century. Candidates: Bishad Sindhu (Mir Mosharraf Hossain), Kulin Kulasarbaswa (Ramnarayan Tarkaratna), Swarnalata (Tarakanath Gangopadhyay), Alo o Chhaya (Kamini Roy), Parivrajak (Vivekananda), Rameshchandra Dutt, a play of Girish Chandra Ghosh. Rules as BN-102. | bn-5765 to bn-5767 | S | BN-102 (creators file) | Sonnet |
| BN-104 | decks/bn-close-culture | edit `bn-culture-3.yaml`, layer, creators | **3 more** (15 to 18), Tagore's circle and children's classics. Candidates: Jharna (Satyendranath Dutta), a song of Rajanikanta Sen, Birpurush (Tagore), Gora (Tagore), a second Tagore story; Tagore stays at 12 or fewer of 18. Rules as BN-102. | bn-5815 to bn-5817 | S | BN-103 | Sonnet |
| BN-105 | decks/bn-close-culture | edit `bn-culture-4.yaml`, layer, creators | **3 more** (15 to 18), authors who died by 1955. Candidates: Char-iyari Katha (Pramatha Chaudhuri), Abarodhbasini (Begum Rokeya), Mahesh or Ramer Sumati (Sarat Chandra Chattopadhyay), Aranyak or Aparajito (Bibhutibhushan; rights and first-publication date read closely). Rules as BN-102; every doubt on rights goes to the review queue, the item is dropped if not cleared. | bn-5865 to bn-5869 | S | BN-104 | Sonnet |
| BN-106 | decks/bn-close-professional | create `bn-medicine-clinic.yaml`, `bn-medicine-pharmacy.yaml` and their layers | The pattern of 10.4: `professional: "medicine"`, clinic B1 and pharmacy A2, 16 to 20 cards each, about half `ref` to taught words, the rest new `pos: "phrase"` cards the speaker of the setting says (a doctor to a patient in `আপনি` forms; at the pharmacy: the dose, before or after food, a prescription); a `usage` note where one point is teachable; layer with `native` and notes. Phrases are common and attested usage, not literal translations of English; doubts of register go to the queue (BN-150). | bn-7100 to bn-7149 | M | none | Sonnet |
| BN-107 | decks/bn-close-professional | create `bn-hospitality-reception.yaml`, `bn-hospitality-restaurant.yaml`, layers | As BN-106: `professional: "hospitality"`, both A2. Reception: booking, check-in, room, key, check-out; restaurant: table, order, bill. | bn-7150 to bn-7199 | M | none | Sonnet |
| BN-108 | decks/bn-close-professional | create `bn-business-email.yaml`, `bn-business-meeting.yaml`, layers | As BN-106: `professional: "business"`, both B1. Email: salutation, request, attachment, closing, in the formal register; meeting: agenda, deadline, agree and disagree, next steps. | bn-7200 to bn-7249 | M | none | Sonnet |
| BN-109 | decks/bn-close-professional | edit `docs/review-queue/bn.md` | Row for every doubt of register, field word or phrase of BN-106 to 108, in the file's table shape. | none | S | BN-106 to 108 | Haiku |
| BN-110 | main, docs | append to this page, subsection 10.5 | The note template per class N1 to N9 and the decision on the 81 unclassified cards; no card edited. Facts about the cited points are read on pages, not written from memory. | none | S | none | Sonnet |
| BN-111 | decks/bn-close-notes | bn-clothes-sentences 7, bn-places-sentences 1, bn-arts-sentences 3, bn-numbers-1-20 8, bn-quantities-sentences 1, bn-numbers-big-sentences 10, bn-calendar-sentences 10, bn-grammar-honorifics-sentences 3, bn-workplace-sentences 5, bn-noun-forms-sentences 4, bn-work-sentences 10, bn-literature-sentences 9, bn-housing-sentences 7, bn-journey 1, bn-services 3, bn-geography-sentences 8, bn-animals-sentences 10 (100) | RULE-NOTE-BN and the BN-110 templates (10.5): only cards without a note (the builder recounts and lists the ids first); a card none of the classes fits is listed in the report | none | M | BN-110, BN-120 merged | Haiku |
| BN-112 | decks/bn-close-notes | bn-environment-sentences 3, bn-home-sentences 10, bn-weather-sentences 4, bn-feelings-sentences 2, bn-sports-sentences 5, bn-things-sentences 3, bn-location-sentences 8, bn-adverbs-sentences 10, bn-grammar-compound-verbs-sentences 5, bn-law-sentences 5, bn-home 10, bn-nature-sentences 10, bn-grammar-concessive-sentences 5, bn-careers-sentences 4, bn-directions-sentences 8, bn-market-sentences 8 (100) | RULE-NOTE-BN and the BN-110 templates (10.5): only cards without a note (the builder recounts and lists the ids first); a card none of the classes fits is listed in the report | none | M | BN-110, BN-120 merged | Haiku |
| BN-113 | decks/bn-close-notes | bn-shopping-sentences 14, bn-services-sentences 6, bn-technology-sentences 7, bn-phone-sentences 5, bn-groceries 13, bn-agriculture-sentences 3, bn-help 9, bn-eating-out 5, bn-transport 2, bn-family 1, bn-verbs-sentences 13, bn-daily-life 2, bn-grammar-conjunct-verbs 4, bn-grammar-habitual-past-sentences 4, bn-calendar 15 (103) | RULE-NOTE-BN and the BN-110 templates (10.5): only cards without a note (the builder recounts and lists the ids first); a card none of the classes fits is listed in the report | none | M | BN-110, BN-120 merged | Haiku |
| BN-114 | decks/bn-close-notes | bn-government-sentences 2, bn-questions 2, bn-appearance-sentences 10, bn-relationships-sentences 1, bn-describing-sentences 10, bn-time 3, bn-cooking-sentences 10, bn-weddings-sentences 2, bn-grammar-passive-sentences 7, bn-help-sentences 8, bn-journey-sentences 7, bn-verbs-5-sentences 10, bn-grammar-conjunctions 1, bn-illness-sentences 14, bn-groceries-sentences 10 (97) | RULE-NOTE-BN and the BN-110 templates (10.5): only cards without a note (the builder recounts and lists the ids first); a card none of the classes fits is listed in the report | none | M | BN-110, BN-120 merged | Haiku |
| BN-115 | decks/bn-close-notes | bn-news-sentences 5, bn-adjectives-2-sentences 6, bn-body-sentences 1, bn-emergencies-sentences 3, bn-cinema-sentences 2, bn-money-sentences 8, bn-abstract-words-sentences 10, bn-work 5, bn-school-sentences 10, bn-eating-out-sentences 8, bn-health-sentences 5, bn-time-sentences 10, bn-hobbies-sentences 10, bn-grammar-reported-speech-sentences 8, bn-grammar-adjectives 4 (95) | RULE-NOTE-BN and the BN-110 templates (10.5): only cards without a note (the builder recounts and lists the ids first); a card none of the classes fits is listed in the report | none | M | BN-110, BN-120 merged | Haiku |
| BN-116 | decks/bn-close-notes | bn-grammar-conditional-sentences 1, bn-about-me 3, bn-history-sentences 4, bn-market 2, bn-directions 2, bn-travel 3, bn-pronouns-sentences 3, bn-daily-life-sentences 10, bn-festivals-sentences 6, bn-grammar-indefinites-sentences 3, bn-travel-sentences 7, bn-opinions-sentences 5, bn-food-sentences 5, bn-verbs-4-sentences 5, bn-transport-sentences 8, bn-verbs-3-sentences 4, bn-chores-sentences 8 (79) | RULE-NOTE-BN and the BN-110 templates (10.5): only cards without a note (the builder recounts and lists the ids first); a card none of the classes fits is listed in the report | none | M | BN-110, BN-120 merged | Haiku |
| BN-117 | decks/bn-close-notes | bn-numbers-big 66 (class N1 only) | RULE-NOTE-BN and the BN-110 templates (10.5): only cards without a note (the builder recounts and lists the ids first); a card none of the classes fits is listed in the report | none | S | BN-110, BN-120 merged | Haiku |
| BN-120 | decks/bn-close-repair | the cards, examples, grammar rows and passages of 10.6 | Rerun `python3 tools/transcribe.py bn "<text>" "<hint>"` for every place listed in 10.6 (the "oo" words except the microwave; the 23 র্ব cards), copy the tool's `reading` and `ipa`, delete the card's `phonetic` and `phonetic_source`, change nothing else; a place where the tool still says `rr` or `ooy` is listed, not guessed; also the review-queue row for the microwave. | none | M | none | Haiku |
| BN-130 | decks/bn-close-examples | bn-first-words 5, bn-sound-differences 1, bn-questions 12, bn-addressing 6, bn-pronouns 14 (38) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-131 | decks/bn-close-examples | bn-family 18, bn-numbers-1-20 18, bn-about-me 7 (43) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-132 | decks/bn-close-examples | bn-verbs 28, bn-quantities 17 (45) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-133 | decks/bn-close-examples | bn-describing 15, bn-time 14, bn-location 11 (40) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-134 | decks/bn-close-examples | bn-more-verbs 24, bn-grammar-postpositions 8, bn-grammar-conjunctions 7, bn-grammar-adjectives 6 (45) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-135 | decks/bn-close-examples | bn-work 9 (9) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | S | BN-111..117 and BN-120 merged | Haiku |
| BN-136 | decks/bn-close-examples | bn-numbers-big 90 (90; number words in examples as taught) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-137 | decks/bn-close-examples | bn-food 46 (46) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-138 | decks/bn-close-examples | bn-groceries 16, bn-market 3, bn-grammar-likes 1, bn-directions 6, bn-transport 3, bn-body 15 (44) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-139 | decks/bn-close-examples | bn-places 19, bn-things 11, bn-home 5, bn-grammar-articles 1, bn-clothes 14 (50) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-140 | decks/bn-close-examples | bn-animals 18, bn-daily-life 2, bn-grammar-conjunct-verbs 19 (39) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-141 | decks/bn-close-examples | bn-sadhu-cholito 22, bn-calendar 23 (45) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-142 | decks/bn-close-examples | bn-eating-out 7, bn-help 8, bn-adjectives-2 1, bn-grammar-can-must 2, bn-history 1, bn-spelling 15 (34) | Bring every listed word card to 2 examples (shape of the examples of `bn-food`: short sentences of taught words, `reading` and `ipa` by the tool, `bases` by `ref` or `{ word, base, reading }`; layer `native` and `bases`); counts are of 2026-11-17, recounted first; sound-inventory cards of `bn-phonology-*` are out of scope | none | M | BN-111..117 and BN-120 merged | Haiku |
| BN-150 | decks/bn-close-queue | edit `docs/review-queue/bn.md` | Rows from the reports of BN-100 to 108, 110 to 120 and 130 to 142: culture dates, professional register, the notes' open cases, examples the builder doubted. | none | S | the batches | Haiku |
| BN-151 | decks/bn-close-ipa | edit every new or changed `decks/bn/**` card | After every content PR has merged: `python3 tools/derive_phonetic.py bn --bracket-unchanged --write` (and `import_phonetic.py` first only if the dump can be fetched, as BN-065). Report the counts; expected: `phonetic` on every new card and on every card BN-120 edited; the 9 sound-concept cards stay without. | none | S | all content PRs merged | Haiku |
| BN-152 | main, docs | the Bengali column of [Plan-Language-Completeness](Plan-Language-Completeness.md), section 9 of this page, the #1166 comment | Re-read `decks/index.json` and the files on decks-live and record the measured numbers: completeness 100% (2,833 of 2,833, every unit has at least its plan), stage Complete, grammar 83 of 83, culture 72 of 72, professional 6 decks, notes and examples counts, narrow IPA, the typos fixed; only what the re-read proves. | none | S | BN-151 | Haiku |

Counts: **35 tasks**: Sonnet 8 (BN-102 to 108 and BN-110), Haiku 27 (BN-100, 101, 109, 111 to 117, 120, 130 to 142, 150 to 152); plus one Sonnet review for each of the seven branches. Cards to add: 17 words, 14 culture items, about 55 professional phrase cards plus about 60 refs; edits: 640 notes, 568 examples (2 each, about 1,100 new examples), about 40 reading repairs.

### 10.8 Order, lanes and what stays outside the plan

1. **Wave 1, parallel (disjoint files):** BN-100; BN-102 to 105 (serial, the creators file); BN-106 to 108; BN-110; BN-120. BN-101 after BN-100 and BN-120 (the noun-forms file).
2. **Wave 2:** BN-111 to 117 (notes) once BN-110 and BN-120 have merged. They edit the same cores and layers as the examples, so the notes PR merges first.
3. **Wave 3:** BN-130 to 142 (examples) after the notes.
4. **Wave 4:** BN-150, then BN-151, then BN-152. The closing re-measurement stands only if `decks/index.json` shows `has` at or above `words` on every unit up to the B1 mark and 72 culture cards.
- **Lanes under rule 17 and the two-agent limit:** the Haiku tasks of a branch share one worktree-per-worker, one integration branch and one PR; deck-worker numbers follow the architect's rule (two fewer deck workers per running Sonnet review).
- **One more `multiword` card** (80 of 80) is left to the builder of the next multi-word batch only if a pattern is attested on a cited page; it is not a task, because 79 does not enter any app measure.
- **Not in this plan:** the 26 facts without a `source`, the Dhaka pronunciation variety, links of the 20 recommendations (still unchecked), the reviewers' decisions (everything ships `unreviewed`).

### 10.9 Questions for the owner (defaults taken, none blocks)

1. **Illness unit:** the plan says 50 words, the deck has 33 countable ones. Default taken: add 17 nouns (BN-100). The alternative, lowering `words` to 33, was rejected as moving the goalposts.
2. **Professional list:** taken from the shared `professions` list already on decks-live (medicine, hospitality, business); no Bengali-only profession is added.
3. **`māikrooyebh`:** the tool's own reading is kept and queued for a bilingual reviewer.
4. **Notes:** a card is left without a note only if none of the nine classes applies; the owner may widen or narrow the classes after BN-110 shows its templates.

