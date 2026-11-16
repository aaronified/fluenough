# Deck work queue: Gujarati completion plan

Status: audit and plan of 2026-11-15. Nothing here is built yet; the audit is the only work done. Owner instruction (2026-11-15): one session per language; this session owns Gujarati (`gu`) and takes it to full completeness "as fast as possible, by delegating to agents". It **overrides rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md)** for Gujarati. The shape is that of [Deck-Work-Queue-HI](Deck-Work-Queue-HI.md), [Deck-Work-Queue-MR](Deck-Work-Queue-MR.md), [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) and [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md). Rules 1 to 15 and rule 17 of the Deck-Work-Queue apply to every task (read Gujarati for "Japanese"). Gujarati readings are ISO 15919-based, written by `tools/transcribe.py gu`, never by hand.

State was read from `origin/decks-live` on 2026-11-15 with PyYAML over every `decks/gu/**` file and `gu-path.yaml`, plus `decks/sections.yaml`, `decks/creators/`, `decks/recommendations/`, `docs/review-queue/` and `tools/phonetic_languages.yaml` on main.

## 1. Audit against the completeness checklist

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | **BIG GAP** | `gu-path.yaml`: 117 entries, 41 built, **76 planned** (about 49 word units and 27 grammar units). A1 mark at entry 45, A2 at 72, B1 at 113. Entries 4, 10 to 13, 15, 21, 22, 27, 36 to 38, 43, 44 (A1); 47 to 72 (A2); 74 to 113 (B1) have no deck. Each planned entry carries its words count, a listening passage and a reading passage | GU-100..GU-3xx |
| 2 | Cores and English layers | **GAP** | 59 core files (42 vocab, 11 grammar, plus numbers, sounds, facts, script, romanisation, reading), 55 layers; 713 cards, highest id `gu-0695` | rides on row 1 |
| 3 | Sentences decks | **GAP** | only `gu-grammar-sentences`; none of the 42 vocab decks has a `-sentences` deck | GU-400..GU-4xx |
| 4 | Reading decks | **GAP** | `gu-en-reading-keri` and `gu-script-reading`; the planned entries name about 76 reading passages | rides on row 1, GU-420 |
| 5 | Script decks | **DONE** | vowels, consonants, vowel signs, conjuncts, digits, reading, `gu-script`, `gu-spelling`, `gu-romanisation` (counts not re-read; conjunct coverage to check) | GU-090 checks |
| 6 | Phrasebook | **DONE** | `gu-phrasebook`: 20 cards (limit 25) | none |
| 7 | Situations | **MISSING** | no `gu-situations.yaml` | GU-050 |
| 8 | Topics incl. script topics | **MISSING** | no `gu-topics.yaml` | GU-040, GU-041 |
| 9 | Culture decks | **MISSING** | no `gu-culture-*` | GU-001, GU-010..013 |
| 10 | Creators, eras, legacy | **MISSING** | no `decks/creators/gu.yaml` | rides on GU-010..013, 060, 061 |
| 11 | Proverbs | **MISSING** | none (owner 2026-11-13: built for every priority language) | GU-020..022 |
| 12 | Multi-word verbs | **MISSING** | rules decks `gu-grammar-compound-verbs` and `gu-grammar-conjunct-verbs` exist (not genre decks) | GU-030..033 |
| 13 | Professional | HELD | `professions: []` | none (needs the owner) |
| 14 | Recommendations | **MISSING** | no `decks/recommendations/gu.yaml` | GU-060, GU-061 |
| 15 | Narrow IPA and broad `ipa` | **GAP** | no `gu` entry in `tools/phonetic_languages.yaml`, no `decks/gu/gu-phonetics.yaml`; 0 of 713 cards have `phonetic`; 683 have a broad `ipa`, 30 do not | GU-110..112 |
| 16 | Review-queue rows | **MISSING** | no `docs/review-queue/gu.md` | GU-120..122 |
| 17 | Sourcing list | **MISSING** | no `Plan-Culture-Gujarati` | GU-001 |
| 18 | Facts file | **DONE** | `gu-facts.yaml`: 38 entries | none |
| + | Notes gap | PARTLY | 523 of 713 cards have notes, 190 none | GU-130..132 |
| + | Grammar tables | NOT AUDITED | 11 grammar cores; the full-table rule (owner, 2026-10-23) needs a read by a Sonnet | GU-093G |

## 2. Conventions every GU task carries

- **Header of a deck:** copy the exact block from `decks/gu/gu-first-words.yaml`: `language: { code: "gu", iso639_3: "guj", name: "Gujarati", script: "gujarati", tts: "gu-IN", icon: "ગુ" }`, `part: "core"`, `kind: "vocab"` (or `grammar`), `license: "CC-BY-SA-4.0"`, `tags: [..., "unreviewed"]`; layer `decks/gu/en/gu-en-<name>.yaml`. Read the build-deck skill and one built unit of the same kind first.
- **Readings and IPA:** `reading` and broad `ipa` from `python3 tools/transcribe.py gu "<text>" <hint>` (hint: the word as typed in Latin letters), run from `origin/main`'s `tools/` checked out into the worker's worktree, never committed. Never hand-written. No `phonetic` on a new card: GU-110/111 write them.
- **Ids:** highest today `gu-0695`. Reserved: path A1 `gu-1000..1999`, A2 `gu-2000..3499`, B1 `gu-3500..5499`, genre kinds `gu-6000..6999`, sentences `gu-7000..8499`, notes and fixes none new. Sub-ranges per task, ascending, never reused.
- **Rights floor for culture:** author died 1955 or earlier; anonymous works first published before 1900. Every text, date and lifespan is read from gu.wikipedia, gu.wikisource or a cited dictionary page; what cannot be read is dropped, never filled from memory. Excerpt at most 25 words.
- **Validator traps (CI failures seen so far):** confusable ids are `[a-z0-9-]+`; a base word appears once per card (case-insensitive); `words` joins exactly to the whole target with no spaces inside entries; `bases[].word` is one word of the target; an entry has `ref` OR `base`, never both, and a ref entry has no `reading`; layer `bases` gloss only inline words, never an empty `bases`; every layer note needs a matching core `notes: [{id, kind}]` with kind one of behaviour, culture, homograph, lookalike, note, pair, usage; a layer meaning is ONE sentence (join clauses with `;`); sentence cards need 2 to 3 confusables (existing word-card ids, layer keys equal core ids); every non-Latin word in layer text, descriptions and base meanings is followed by its reading in half-width parentheses; creators `born`/`died` is a plain year or `{ year, circa: true }` (never `circa: false`), `source.author` equals the creator's exact `name.en.text`, `legacy` has 1 to 6 items with sources; `source.date` is a year, a range or `c. year` only; at most 25 `phrasebook: true` cards per course; a grammar unit writes no reading deck; every word of a kind in every B1 deck needs a row in every rules table of that kind; indentation errors can nest cards as examples.
- **Branches and PRs (rule 17):** each wave has ONE shared integration branch, ONE PR to `decks-live`, ONE Sonnet review (report-only, BLOCKING or NIT), fixes applied by the workers. Workers use their own worktrees, merge `origin/decks-live` and the shared branch before each fast-forward push, never force, no tags, never open PRs, never use session-management tools. No agent runs the validator or the tests.
- **Haiku guard (owner, 2026-11-10):** code a Haiku writes is in try/catch and reports every caught issue to the app logger and the report. Haiku never improvises: it stops and reports.
- **Shared files, one owner per wave:** `gu-path.yaml` (the architect flips each entry from `planned` to its `decks` list after the unit merges, in the wave PR), `gu-topics.yaml` (GU-040/041), `gu-situations.yaml` (GU-050), `decks/creators/gu.yaml` (culture tasks in order, then recommendations), `decks/recommendations/gu.yaml` (GU-060/061), `docs/review-queue/gu.md` (GU-120..122).

## 3. Task table

### 3.1 Wave P: the path (three shared branches, one per level)

| Id | Model | Branch | Spec |
|---|---|---|---|
| GU-100..GU-1xx | Haiku (grammar units: Sonnet draft rules, Haiku fill) | `decks/gu-a1-wave1` | The 14 planned A1 entries (pronouns, everyday verbs, adverbs, quantities, describing words, more verbs, food, body, places, things, clothes, animals, grammar-present, grammar-imperatives): core, English layer, sentences deck (word units), reading deck (word units) |
| GU-200..GU-2xx | Haiku | `decks/gu-a2-wave1` | The planned A2 entries 47 to 72 (weather, habitual past, perfect, ordinals, festivals, shopping, illness, cooking, comparison, school, hobbies, past continuous, chores, appearance, verbs-3, phone, journey, nature, conjunctive, adjectives-2, workplace, geography) |
| GU-300..GU-3xx | Haiku | `decks/gu-b1-wave1` | The planned B1 entries 74 to 113, 40 units, each word unit with its sentences and reading decks, each grammar unit its rules core and layer only |
| GU-093G | Sonnet | none (report) | Audit the 11 existing grammar decks against the full-table rule; list gaps as new tasks |

Each worker takes one unit by path entry number, builds it from its path words count, listening and reading passages, and reports. Parallel workers on one branch never edit the same file; `gu-path.yaml` is edited by the architect only.

### 3.2 Wave A: the genre kinds (branch `decks/gu-kinds-wave1`)

| Id | Model | Creates / edits | Spec |
|---|---|---|---|
| GU-001 | Sonnet, docs to main | `wiki/Plan-Culture-Gujarati.md` | Sourcing list as `Plan-Culture-Telugu`: candidates for culture 1 to 4 (4 x 18 plus reserves), proverbs 1 to 3 (3 x 20), multiword (4 x 20), recommendations (20), each verified on a named page: bhakti poets (Narsinh Mehta, Mirabai, Akho, Premanand), Dayaram, Narmad, Govardhanram, Kalapi, Mahatma Gandhi's Gujarati writing, Zaverchand Meghani folk collections, garba and bhajan, anonymous folk songs and kahevato |
| GU-010..013 | Haiku | `gu-culture-1..4` + layers, `creators/gu.yaml` | As the Telugu culture batches; 18 items each, fewer rather than padded; serial on `creators/gu.yaml` |
| GU-020..022 | Haiku | `gu-proverbs-1..3` + layers | `genre: "proverbs"`, `basis: "oral-tradition"`, 20 cards each (kahevat); `source` with collection, date, edition, jurisdiction, rights_checked; one literal note per card |
| GU-030..033 | Haiku | `gu-multiword-*` + layers | `genre: "multiword"`, `pattern_family`, a usage note per card: conjunct verbs, compound verbs, idiomatic verbs, dative-subject constructions |
| GU-040 / 041 | Haiku | `gu-topics.yaml` | 12 grammar, word and script topics over real deck ids (script topic included); then 8 `other` topics over the merged culture, proverbs and multiword decks |
| GU-050 | Haiku | `gu-situations.yaml` | 10 sheets per Deck-Format and issue #1145; at most 12 new cards |
| GU-060 / 061 | Haiku | `recommendations/gu.yaml`, `creators/gu.yaml` | 10 + 10 entries, shape of `recommendations/es.yaml`, 3 questions each, no quote, no link |

### 3.3 Waves C and D

| Id | Model | Spec |
|---|---|---|
| GU-090 | Haiku | Read-only: script-deck counts and missing common conjuncts; `gu-phrasebook` and `gu-facts` counts |
| GU-400..GU-4xx | Haiku | Sentences decks for the 42 existing vocab decks without one (branch `decks/gu-sentences-wave1`) |
| GU-420 | Haiku | Reading decks for existing units that have none (after GU-090 list) |
| GU-130..132 | Haiku | Typed notes for the 190 cards without a note (branch `decks/gu-notes`) |
| GU-110 | Sonnet | Design the Gujarati variety and rules: registry entry `"gu"` in `tools/phonetic_languages.yaml` and `decks/gu/gu-phonetics.yaml` (lessons of issue #1369). The registry is shared code: raised with the parent by a GitHub issue |
| GU-111 | tool run | After content PRs merge: `import_phonetic.py gu --write`, then `derive_phonetic.py gu --bracket-unchanged --write`; no hand edit |
| GU-112 | Haiku | Broad `ipa` for the 30 cards that lack one, from `tools/transcribe.py` |
| GU-120..122 | Haiku | Append review-queue rows from each wave's reports to `docs/review-queue/gu.md` |
| GU-140 | Haiku, docs to main | Update the Gujarati row of Plan-Language-Completeness and issue #1171 from a re-read |

## 4. Order

1. GU-001, GU-090, GU-093G now; wave P (A1 first), GU-040 and GU-050 have no dependency.
2. Wave P is the critical path: the three level branches run in parallel with many workers.
3. Culture tasks run serial on `creators/gu.yaml`; proverbs and multiword in parallel.
4. GU-111 last, after every content PR has merged.

## 5. Open questions

- Professional decks need the owner's profession list.
- The `gu` registry entry is shared tooling; GU-110 goes through the parent.

## 6. Status and resume plan (2026-11-16)

Owner directive (2026-11-16, token budget): at most four language sessions run at once. Gujarati is **paused**: running workers finish, open PRs are merged when green after one review, nothing new starts. Resume when the parent session says so.

### 6.1 Done

| Item | State |
|---|---|
| Audit, this queue page, grid row | Done (main) |
| GU-001 sourcing list | Done: `Plan-Culture-Gujarati` (main). Poem lines were not readable by the page reader; see 6.4 |
| A1 path (14 units) | **Merged**: PR #1453 into decks-live |
| A2 path (22 units) | PR #1485 (`decks/gu-a2-wave1`), CI fixes pushed; merge when green after the one Sonnet review |
| Proverbs 1 to 3 | On `decks/gu-kinds-wave1`: 60 cards, three uncertain literals (gu-6317, 6326, 6355) |
| Situations | On `decks/gu-kinds-wave1`: `gu-situations.yaml`, 10 sheets, 6 new cards (gu-6600..6606) |
| Multiword | On `decks/gu-kinds-wave1`: 11 verified cards of 80 planned (conjunct 4, compound 1, idiomatic 3, dative 3) |
| Culture | On `decks/gu-kinds-wave1`: culture-1 4 cards, culture-2 2 cards, creators 2. A background fetch of about 530 gu.wikisource pages was running (`scratchpad/gk`, session-local) |

### 6.2 To do, in order

1. Merge PR #1485 (read CI with `gh api repos/aaronified/fluenough/commits/<sha>/check-runs`; one Sonnet review, report only; fixes by the workers). Then open ONE PR for `decks/gu-kinds-wave1` (base decks-live), one review, merge.
2. **B1 wave (38 planned entries, positions 74 to 113)**, branch `decks/gu-b1-wave1` (never merge another work branch into it; start only after A2 is merged, so workers see the A2 cards). Ids: `gu-3500..5499` (A2 used 3200..3349 and 5500..5692; do not reuse), grammar units: relative, subjunctive, conditional, purpose, before-after, while, causative, concessive, indefinites, emphasis, passive, reported-speech, honorifics (13); the rest are word units (25) with a sentences deck and one reading deck each. Match path entries by `planned.id`, not position.
3. **Notes** (GU-130..132, owner directive 2026-11-15): a note on every card with any real teachable point; only plainly self-explanatory cards stay without. About 190 old cards plus the new ones.
4. **Culture, multiword, proverb gaps**: retry every reachable source before dropping an item (en/gu Wikipedia, Wikidata, Wikiquote, Wikisource, Britannica, national library pages), 3 s pacing, raw wikitext via curl (`index.php?title=...&action=raw` with a User-Agent header; the page reader refuses verse and `api.php` answers 429); a one-line reason for every dropped item.
5. **Narrow IPA**: after tools PR #1493 (gu registry entry and hint handling) merges and all content PRs are merged: `python3 tools/import_phonetic.py gu --write`, then `python3 tools/derive_phonetic.py gu --bracket-unchanged --write`; GU-110 designs `decks/gu/gu-phonetics.yaml`. Convention (parent, 2026-11-15): Gujarati readings write short i and u; the engine stays short.
6. **Review queue**: write `docs/review-queue/gu.md` on decks-live from the workers' uncertain items (genders: પનીર, ચટણી, છાશ, શાક, શર્ટ, સ્વેટર, ચંપલ, ધોતી, મોજાં, ગાદલું, પ્રોજેક્ટ, ઇનામ, ઓળખપત્ર, ચર્ચા, સપ્તાહાંત, ગૃહકાર્ય, નોંધ, the six situations nouns; પછી and કંઈ readings; ધોવું third-person present, missing from the tables; ઝાડા, કમળો, ચોપડો, બટવો, મેથી, ભાખરી, રાયતું glosses; Premanand and Narsinh dates; scan-only sources).
7. **Known table gaps**: perfect table lacks જમવું, બોલવું, રમવું, સૂવું; gu-phone has 34 of 40 words, chores 39 of 40, appearance 49 of 50; every adjective taught later needs a row in `gu-grammar-comparison` (the validator checks it); sentences decks carry no confusables (precedent `gu-grammar-sentences`).
8. Update the Gujarati row of Plan-Language-Completeness and issue #1171 from a re-read (GU-140).

### 6.3 Lessons for every worker (CI failures seen)

Sentences decks (core and layer) have no `theme`; layer `bases` gloss only inline bases; every example word is a card, a ref base or an inline base `{ word, base, reading }`; no example base refs its own card; reading deck question ids are `gu-` plus four digits; `reading` lines are lowercase ISO 15919 without quotes; no duplicate cards across decks (the earliest deck on the path keeps the card, later ones use `ref`); never leave a ref to a removed id; a rules table needs a row for every word of its kind taught anywhere (adjectives for comparison). `/tmp/.../gu-dupcheck.py` style PyYAML sanity check before every push (not the validator).

### 6.4 Sourcing blockers

The WebFetch page reader refuses verse; curl on raw wikitext works (see 6.2 item 4). Most Wikisource poem pages are scans without transcribed text. Mirabai's poems are Rajasthani on en.wikipedia, so Gujarati attribution is unsupported.
