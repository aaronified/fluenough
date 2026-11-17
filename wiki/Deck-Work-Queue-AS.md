# Deck work queue: Assamese completion plan

Status: audit and plan of 2026-11-15. Nothing here is built yet; the audit is the only work done. Owner instruction (2026-11-15): one session per language; this session owns Assamese (`as`) and takes it to full completeness "as fast as possible, by delegating to agents". It **overrides rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md)** for Assamese. The shape is that of [Deck-Work-Queue-HI](Deck-Work-Queue-HI.md), [Deck-Work-Queue-BN](Deck-Work-Queue-BN.md) and [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md). Rules 1 to 15 and rule 17 of the Deck-Work-Queue apply to every task (read Assamese for "Japanese").

Assamese uses the Assamese-Bengali script (`script: "bengali"` as in the existing `as` decks; it has ৰ and ৱ that Bengali lacks). The tools share the Bengali engine (`tools/transcribe.py bn` or `as`, known gaps in issue #1402); readings follow the course's hand convention, new cards are written with the tool using hints that match it (as BN Q6).

State was read from `origin/decks-live` (2026-11-15) with PyYAML over every `decks/as/**` file, `as-path.yaml`, `decks/sections.yaml`, `decks/creators`, `decks/recommendations`, `docs/review-queue/as.md`, and `tools/phonetic_languages.yaml` on main.

## 1. Audit against the completeness checklist

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | **DONE** | `as-path.yaml`: 173 entries (5 are grouped lists: units 7, 8, 171, 172, 173), none planned; milestones A1 at unit 44, A2 at 90, B1 at 169; every deck the path names exists (reading decks are flat files `decks/as/as-en-reading-*.yaml`) | none |
| 2 | Cores and English layers | **DONE** | 155 vocab core files (70 word units, 42 grammar decks, script, phonology and the rest), each with a layer in `decks/as/en/`; 2,172 cards with an id, highest id `as-4080` | none |
| 3 | Sentences decks | **GAP** | 60 `-sentences` decks; 28 word units have none (list in 3.3; the phrasebook is by design whole) | AS-080..087 (wave B) |
| 4 | Reading decks | PARTLY | 60 `as-en-reading-*` decks; 73 units name reading passages; 12 vocabulary units have none (pronouns, verbs, adverbs, quantities, describing, more-verbs, food, body, places, things, clothes, animals); `as-grammar-future` and `-imperatives` name passages but a grammar unit writes no reading deck | AS-092 |
| 5 | Script decks | PARTLY | vowels 11, consonants 40, vowel signs 18, conjuncts 23, digits 10, reading words 15, plus `as-script`, `as-spelling`, `as-romanisation`; common conjuncts and reading words are thin (as `bn`: about 50 conjuncts, more reading words) | AS-094 |
| 6 | Phrasebook | **DONE** | `as-phrasebook`: 20 cards (limit 25) | none |
| 7 | Situations | **MISSING** | no `as-situations.yaml` | AS-050 |
| 8 | Topics incl. script topics | **MISSING** | no `as-topics.yaml` | AS-040, AS-041 |
| 9 | Culture decks | **MISSING** | no `as-culture-*` | AS-001, AS-010..013 |
| 10 | Creators, eras, legacy | **MISSING** | no `decks/creators/as.yaml` | rides on AS-010..013, 060, 061 |
| 11 | Proverbs | **MISSING** | none (owner 2026-11-13: built for every priority language) | AS-020..022 |
| 12 | Multi-word verbs | **MISSING** | rules decks `as-grammar-compound-verbs` and `as-grammar-conjunct-verbs` exist (not genre decks) | AS-030..033 |
| 13 | Professional | HELD | `professions: []` | none (needs the owner) |
| 14 | Recommendations | **MISSING** | no `decks/recommendations/as.yaml` | AS-060, AS-061 |
| 15 | Narrow IPA and broad `ipa` | **MISSING** | no registry entry for `as` in `tools/phonetic_languages.yaml`, no `decks/as/as-phonetics.yaml`; 0 of 2,172 cards have `phonetic`; 99 cards have no broad `ipa` (check each: set-like script and phonology cards are expected) | AS-110..113 |
| 16 | Review-queue rows | PARTLY | `docs/review-queue/as.md`: 20 rows, all 2026-11-07 | AS-120..122 |
| 17 | Sourcing list | **MISSING** | no `Plan-Culture-Assamese` | AS-001 |
| 18 | Facts file | **DONE** | `as-facts.yaml`: 44 entries | none |
| + | Notes gap | PARTLY | 653 of 2,172 cards have no `notes` | AS-130..135 |
| + | Grammar tables | NOT AUDITED | 42 grammar decks; the full-table rule (owner, 2026-10-23) needs a read by a Sonnet | AS-093 |

## 2. Conventions every AS task carries

- **Header of a genre deck:** as `es-culture-1` with `language: { code: "as", iso639_3: "asm", name: "Assamese", script: "bengali", tts: "as-IN", icon: "অ" }` copied from an existing `as` core, `part: "core"`, `kind: "vocab"`, `genre`, `level`, `tags: ["unreviewed"]`, `license: "CC-BY-SA-4.0"`; layer `decks/as/en/as-en-<name>.yaml`. A worker copies the header and script field from `as-first-words`, never from memory.
- **Readings and IPA:** `reading` and broad `ipa` come from `python3 tools/transcribe.py` (Bengali engine, `bn`/`as`), run from `origin/main`'s `tools/`, which a worker checks out into its worktree and never commits. Never hand-written. No `phonetic` and no `phonetic_source` on a new card: AS-110..112 write them.
- **Ids:** the course's reserved range is `as-4100` to `as-9999` (highest id today `as-4080`), sub-ranges per task below, ascending, never reused.
- **Rights floor for culture:** an author who died in 1955 or earlier (the validator floor); anonymous works need a first publication before 1900. Texts, dates and lifespans are read by the builder from as.wikipedia, as.wikisource, en.wikipedia or other cited pages; what could not be read is dropped (never filled in) and replaced from the reserve. Excerpt at most 25 words. Never write culture or facts from memory.
- **Review queue:** every row goes into the task's report; AS-120..122 collect them into `docs/review-queue/as.md`.
- **Validator traps** (CI failures seen so far): confusable ids are `[a-z0-9-]+`; a base word appears once per card (case-insensitive); `words` joins exactly to the whole target with no spaces inside entries; `bases[].word` is one word of the target; an entry has `ref` OR `base`, never both, and a ref entry has no `reading`; layer `bases` gloss only inline words, never an empty `bases`; every layer note needs a matching core `notes: [{id, kind}]` with one of the valid kinds (behaviour, culture, homograph, lookalike, note, pair, usage); a layer meaning is ONE sentence (join clauses with `;`); sentence cards need 2 to 3 confusables (existing word-card ids, layer keys equal core ids); every non-Latin word in layer text, descriptions and base meanings is followed by its reading in half-width parentheses; creators `born`/`died` is a plain year or `{ year, circa: true }` (never `circa: false`), `source.author` equals the creator's exact `name.en.text`, `legacy` has 1 to 6 items with sources; `source.date` accepts year, range or 'c. year' only; at most 25 `phrasebook: true` cards per course; excerpts at most 25 words; a grammar unit writes NO reading deck; every word of a kind in every B1 deck needs a row in every rules table of that kind; indentation errors can nest cards as examples.
- **Branches and PRs (rule 17):** each wave has ONE shared integration branch, one PR to `decks-live`, ONE Sonnet review (report-only), fixes applied by the workers. Workers use their own worktrees, merge `origin/decks-live` and the shared branch before each fast-forward push, never force, no tags, never open PRs, never use session-management tools. No agent runs the validator or the tests. Haiku code is guarded (try/catch, errors to the app logger).
- **Shared files, one owner per wave:** `decks/as/as-topics.yaml` (AS-040/041), `decks/as/as-situations.yaml` (AS-050), `decks/creators/as.yaml` (the culture tasks in order, then recommendations), `decks/recommendations/as.yaml` (AS-060/061), `docs/review-queue/as.md` (AS-120..122).

## 3. Task table

### 3.1 Wave A: the genre kinds (branch `decks/as-kinds-wave1`)

| Id | Model | Creates / edits | Spec | Ids | Depends on |
|---|---|---|---|---|---|
| AS-001 | Sonnet, docs to main | `wiki/Plan-Culture-Assamese.md` | The sourcing list, as `Plan-Culture-Hindustani`: candidates for culture 1 to 4 (4 x 18 plus reserves), proverbs 1 to 3 (3 x 20: phrases and the Assamese saying tradition), multiword (4 x 20), recommendations (20), each verified on a named page; Assamese authors and traditions (charit puthi and the Sankardev and Madhavdev borgeets, Bezbaroa, Hemchandra Barua, Rajanikanta Bordoloi, the Jonaki period, Bihu songs, Bhupen Hazarika, folk tales such as Burhi Aair Sadhu, cinema and music), anonymous and pre-1900 traditional | none | none |
| AS-010..013 | Haiku | `as-culture-1..4` + layers, `creators/as.yaml` | Culture 1 medieval and vaishnava (Sankardev, Madhavdev, borgeets, charit puthi); 2 Jonaki and early modern prose and verse to 1955; 3 folk and oral traditions pre-1900 (bihu, tales, lullabies); 4 history and places. 18 items each, fewer rather than padded | `as-4100..4399` | AS-001; serial on `creators/as.yaml` |
| AS-020..022 | Haiku | `as-proverbs-1..3` + layers | `genre: "proverbs"`, `basis: "oral-tradition"`, 20 cards each; `source` with `collection`, `date`, `edition`, `jurisdiction`, `rights_checked`; a `literal` note per card; only text read on the cited page | `as-4400..4549` | AS-001 |
| AS-030..033 | Haiku | `as-multiword-*` + layers | `genre: "multiword"`, `pattern_family`, a `usage` note on every card. Families: conjunct verbs (noun + কৰা/হোৱা), compound verbs, idiomatic expressions, ক'ব/লাগে experiencer constructions; parts already taught by `ref` | `as-4550..4749` | AS-001 |
| AS-040 | Haiku | `as-topics.yaml` | As `es-topics`: 12 topics over real deck ids (classifiers and articles, pronouns, honorifics, tenses, verbs, postpositions, conditionals, compound verbs, sounds, both scripts topics: the alphabet and conjuncts) | none | none |
| AS-041 | Haiku | edit `as-topics.yaml` | 8 `kind: "other"` topics over the merged culture, proverbs, multiword decks | none | AS-010..033 merged |
| AS-050 | Haiku | `as-situations.yaml` | Deck-Format "Situations files", rules of #1145; 10 sheets (taxi, shops, eat, doctor, traffic, rail, hotel, post and bank, greetings and apologies, emergencies), icon keys each once, 8 to 12 phrases and at most 12 words per sheet, ids real `as-` cards; at most 12 new cards | `as-4750..4799` | none |
| AS-060 | Haiku | `recommendations/as.yaml` (10), `creators/as.yaml` | Shape of `recommendations/es.yaml`: films, songs and books in Assamese, 3 questions each, no quote, no link, creators added | strings | AS-013 merged |
| AS-061 | Haiku | edit both | 10 more: books, songs, series, comic | strings | AS-060 |

### 3.2 Wave B: sentences, readings, scripts (branch `decks/as-sentences-wave1`)

AS-080..087: sentences decks for the 28 word units without one, 8 workers of 3 to 4 decks each, 10 to 25 sentences per deck by the verb-pool rule of the existing `as` decks (read `as-food-sentences` style from a neighbour such as `as-health-sentences`), ids `as-5000..as-6999`, each worker one range of 250. Units: sound-differences, questions, addressing, pronouns, family, numbers-1-20, about-me, verbs, adverbs, quantities, describing, time, more-verbs, work, numbers-big, food, groceries, market, transport, body, places, things, home, clothes, animals, eating-out, registers, slang. A deck whose unit teaches no verb the pool allows is reported, not forced.

| Id | Model | Spec | Ids |
|---|---|---|---|
| AS-092 | Haiku | Reading decks (`as-en-reading-<unit>` with its passages and questions per the path's `reading_passages`) for the 12 vocabulary units without one; builds only passages the path names | `as-7000..7499` |
| AS-094 | Haiku | Script gaps: the missing common conjuncts and reading words, as `bn` (about 50 conjuncts; ৰ and ৱ forms included); ids not reused | `as-7500..7599` |
| AS-093 | Sonnet | Audit the 42 grammar decks against the full-table rule (every word of a kind has a row in every table of that kind); report gaps as new tasks | none |

### 3.3 Wave C: IPA, notes, review queue

| Id | Model | Spec |
|---|---|---|
| AS-110 | Sonnet | Design the registry entry `as` in `tools/phonetic_languages.yaml` and `decks/as/as-phonetics.yaml` (rules, allophones, ৰ ৱ ঙ and the Assamese chx/x sounds, which differ from Bengali), with the lessons of issue #1369 (as `bn-phonetics`, `te-phonetics`); shared tool code goes through the parent by issue and `send_message` |
| AS-111..112 | Haiku | Run the plan's tools (`import_phonetic.py`, `derive_phonetic.py`, `phonetic_patch.py`) over the core and layer files in two halves, once AS-110 is merged; never by hand |
| AS-113 | Haiku | Broad `ipa` for the cards that lack it, after checking which of the 99 are set-like script and phonology cards |
| AS-120..122 | Haiku | Collect every task's review rows into `docs/review-queue/as.md` (one PR per wave, rows for culture, proverbs, recommendations, situations and any non-public-domain item) |
| AS-130..135 | Haiku | Typed notes only where a card has one teachable point; ids in the core, text in the layer; the 653 cards without a note, worst files first |

### 3.4 Order and branches

1. AS-001 (docs to main) and AS-110 (Sonnet) start now. AS-040, AS-050 and the Wave B tasks run in parallel as Haiku workers (their branches as above).
2. AS-010..013 after AS-001 merges, then AS-020..033, then AS-041, AS-060, AS-061.
3. AS-111..113 after AS-110 merges. AS-120..122 and AS-130..135 close each wave.
4. Each wave: one PR to `decks-live`, ONE Sonnet review, fixes by workers, merge when CI is green. While a review runs, two fewer deck workers run (CLAUDE.md).

## 4. Open questions

- None blocking. Defaults taken: ids `as-4100..as-9999`; `script: "bengali"` as in the existing decks; Professional stays held.

## 5. Progress and resume plan (paused 2026-11-16)

Owner directive (token budget, relayed by the parent session 2026-11-16): at most four language sessions at once; Assamese is paused after the workers already running finish and the open PRs merge. No new phase starts until the parent says resume. Assamese is **not complete**.

### 5.1 Done (merged to `decks-live` unless noted)

| What | PR | Result |
|---|---|---|
| Sentences decks for 26 word units | #1455 | 374 cards, ids `as-5000..5836`, path entries added; not built (no natural sentences from taught words): `as-sound-differences`, `as-numbers-1-20` |
| Topics (11), situations (10 sheets), proverbs 1 to 3 (60), multiword 1 to 4 (18, 15, 16, 11), culture 1 to 4 (9, 8, 10, 5), `decks/creators/as.yaml` | #1459 | topics, situations and multiword shortfalls below |
| Reading decks for 11 vocabulary units | #1460 | `as-en-reading-*`, ids `as-7000..7011`, `7150..7158`, `7300..7311`; `describing` not built |
| Registry entry `as` (rules-only narrow IPA) | #1451 | main |
| `as-phonetics.yaml` rules (two vowel-harmony rules) | #1452 | decks-live |
| Sourcing list | straight to main | `Plan-Culture-Assamese` |
| Recommendations (11 of 20), 5 creators, 8 topics of kind other, 23 review-queue rows | #1495 | merged 2026-11-16: 11 recommendations (briefings shortened so they do not answer the questions), 5 creators, 8 topics, 28 review rows |
| Script decks: conjuncts and reading words | #1492 | merged 2026-11-16: 25 conjunct cards `as-7500..7524` (now 48); the 15 reading-word cards `as-7525..7539` were dropped because they duplicated existing cards; example readings aligned to the cards they ref |

### 5.2 Notes wave: partly done, branch `decks/as-notes-wave1` (no PR yet)

944 cards in 114 decks have no note (list: every `-sentences` deck plus a few vocabulary decks; the counts come from `decks-live` on 2026-11-15). Owner directive (2026-11-15, via the parent): write a note on every card with a real teachable point (word order, politeness, collocation, stem change, usage); only plainly self-explanatory cards stay without; one Sonnet review checks accuracy. Six Sonnet workers each took about 150 cards; group 4 (20 sentences decks, 118 notes on 160 cards) finished; groups 1, 2, 3, 5 and 6 were cut off by the usage limit with some commits already pushed. The branch holds a partial result (about 40 files, 476 lines added on 2026-11-16). To resume: list each deck's notes gap again from `decks-live`/the branch with PyYAML, give the remaining decks to Sonnet workers (briefing: `scratchpad` file `notesbrief.md` content is in section 5.4), then open ONE PR for the branch, one Sonnet review. Note rule: say in a card's notes which stem the form takes when the validator warns 'bases: X does not start as its base Y does'.

### 5.3 Remaining work, in order

1. **Notes wave** (5.2).
2. **Data fixes before the narrow IPA run** (parent's list, 2026-11-15, the data decides conventions; the engine stays unchanged where data is mixed):
   - স: about 405 texts have reading `x` but broad `ipa` `s` (for example সমতা xômôtā / sɔmɔta), while about 196 have reading `s`. Assamese স is /x/ except in the clusters স্ক স্ত স্থ স্ন স্প (s in all 37 course words, the engine agrees). Fix the broad `ipa` to `x` where the reading is `x` (tool-assisted, derived from the reading; one Sonnet reviews a sample of 30); do not touch readings.
   - উজ্জ্বল: `uzzzɔl` is a typo, fix by hand to `uzzɔl`.
   - ফোন cards: reading `o` against ipa `ʊ`: make them agree (pick the course majority).
   - র্ব: `ɹɹ` in 6 words against `ɹb` in পৰ্বত: make them `ɹb` by hand.
   - Kept as course values and recorded here as engine exceptions: গাঁও `ɡão` (engine `ɡãʊ`, 20 texts), ঠিক `ʈʰik` (engine `tʰik`, 6), ড় and ঢ় broad ipa `ɹ` (the narrow-IPA limitation: no change), এ stays `e` (the data has no ɛ).
   - Reading conventions to settle with a speaker: পগলা (`pôglā` or `pôgôlā`), একদম (`ekdôm` or `ekôdôm`), বাথৰুম (`bāthrum` or `bāthorum`: the latter in `as-home`, `as-home-sentences`, `as-spelling`), সঁচা (`xôm̐sā` or `sôm̐sā` in `as-adverbs`).
3. **Narrow IPA** (AS-111 to AS-113): `derive_phonetic.py as --bracket-unchanged --write` after notes and data fixes merge (it touches every deck), then the broad-ipa fill for the 99 cards without; run `phonetic_patch.py` as the plan's tools say; one Sonnet review of a sample. The parent's tools PR #1496 (engine for `as`) lands first.
4. **Culture and recommendations retry** (owner directive 2026-11-15): before any item stays dropped, try every reachable source (English and Assamese Wikipedia, Wikidata, Wikiquote, Wikisource, Britannica, national library or university pages) with pace requests; report which hosts were blocked. The drop list with reasons is in 5.5.
5. **Rules tables** (the parent's decision, default): a Sonnet designs a rule-based generator for verbs, pronouns and the regular noun and adjective inflection from cited grammar sources (Wiktionary inflection tables, a published Assamese grammar page); the tables record their source; cells that cannot be sourced stay out and are listed here. The audit (AS-093): Assamese has no `kind: "rules"` core; 916 nouns, 116 adjectives, 21 pronouns, 101 verbs taught; old pattern decks `as-grammar-*` hold 3 to 14 hand-picked entries each; the validator's every-word check never runs for Assamese today. Orphan lemmas (no card): চহৰ, গাড়ী, তই, তাই, তহঁত, অহা, হোৱা, আছে, আছিল, নাছিল, হ'ব. Ids reserved `as-8000..as-8499`.
6. **Other gaps**: new situation phrase cards (which platform; I have a booking; a room please; where does it hurt; show your licence) in a deck with a path entry, then the sheets; the `describing` reading passage (the path says weather and food, taught later: move the passage or change its description); reading-pronouns question as-7001 (answer repeats the prompt); multiword layers: about 25 rare inline bases without a gloss; conjuncts ত্ব, শ্ব, স্ব, শ্চ (tool reads them as Bengali tt, xx, ss: decide the Assamese reading first); `kind: other` and further culture items; professional stays held.
7. Collect every worker's review rows into `docs/review-queue/as.md` (23 rows added; the script-deck rows as-7516, 7532, 7533, 7503, 7505, 7506, 7509, 7538 are still to add).

### 5.4 Notes briefing (for the resume)

Core `notes: [{ id: "n1", kind }]` plus the matching text in the English layer `decks/as/en/as-en-<deck>.yaml`; kinds: note, usage, behaviour, pair, lookalike, homograph, culture; at most two notes per card, one or two plain sentences; say only what the deck, neighbour cards or a source the worker read supports; a non-Latin word in note text is followed by its reading in half-width parentheses; add no new card ids and change no target, reading, ipa, bases, examples or confusables; unsure points go to review rows.

### 5.5 Dropped items and why (one line each)

- **Culture 1**: Kirtan Ghosha, Parijata-harana, Rukmini-harana, Kali-damana (no readable text on as.wikisource); Arjun Bhanjan (broken redirect); Madhavdev borgeet 'Alu moi' (not found); Gunamala (two-column template, text not extractable); Mahiravana Vadha (the Wikisource text is anonymous 1908, not Ananta Kandali's); Parijata Harana 1907 (page empty); Hema Saraswati and Madhava Kandali (era known, no dates); as-4106 and as-4107 (user sandbox pages, not an edition).
- **Culture 2**: O Mur Apunar Dex (not found); Padumkunwari (text garbled); Ramnabami Natak, Kaniyar Kirtan, Pathmala, Hemkosh, Ôxômiya Byakôrôn (no page); Hemchandra Barua and the Joymati film (no readable text).
- **Culture 4**: Charaideo, Kamakhya Temple, Ambubachi Mela, Majuli, the Bihu festivals, Ojapali, Orunodoi, Jonaki, the Buranjis (title-only: no authored text; an owner decision on title-only culture cards is open). Culture 4 has 5 of 18.
- **Multiword**: 2 idioms not on the wikiquote page as written (উগাৰ মাৰা, চকুত ধূলি মাৰা); অচলা ভক্তি and আপুতৰ পুত (noun phrases, not idioms); conjunct verbs already taught elsewhere or with unclear glosses (অনুবাদ কৰা, ভাঙনি কৰা, ধাৰ কৰা, পচন্দ কৰা variant).
- **Proverbs**: বামুণৰো এদিন, শূদিৰৰো এদিন (caste wording).
- **Recommendations** (11 of 20): Village Rockstars (the director's birth year not on her page; the schema needs it); Anamika (medium album not in the schema enum); Bistirno Parore (song page unreachable); Mrityunjay (publication year conflict 1970 or 1979 or 1983); Halodhia Choraye Baodhan Khai (film page has no plot); four Indira Goswami books (pages rate-limited, plot not read).
- **Hosts blocked or unreachable**: archive.org (Gurdon's proverb book), as.wiktionary (404 for every word), Cambridge (Mahanta 2012), the kaikki dump gives few Assamese forms.

### 5.6 Branches left for the owner or the next session

`decks/as-notes-wave1` (partial notes, no PR), plus any branch whose PR merged and was not auto-deleted.

## 6. App lines at 100% (2026-11-17)

Re-measured from the regenerated `decks-live` index: words 1391 of 1391 (PR #1603: the nine missing `as-chores` words `as-8000..8008`), culture 72 of 72 (PR #1604: `as-culture-1..4` at 18 cards each, 42 new cards `as-4110..4120`, `as-4160..4169`, `as-4210..4217`, `as-4260..4272`, sourced in [Plan-Culture-Assamese](Plan-Culture-Assamese.md) "Second sourcing pass (2026-11-17)"), grammar 43 of 43 (already). Open decisions recorded: the 9th chores word is কুটা (chopping counts as a chore; the course already has বিচনা as `as-0338`); culture dates that conflict between the Wikisource index and en.wikipedia use the year of the edition actually read and say the other year in `edition`; `as-4261` has a numeral (`1498`) in its reading that its ipa does not spell (no numeral-in-sentence convention exists). The extras of section 5.3 (notes, data fixes, narrow IPA, rules tables, professional, genre decks) follow as small PRs.
