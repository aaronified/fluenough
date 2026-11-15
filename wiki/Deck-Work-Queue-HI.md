# Deck work queue: Hindustani completion plan

Status: audit and plan of 2026-11-15, re-read on 2026-11-15 from `origin/decks-live` after the waves merged (PRs [#1394](https://github.com/aaronified/fluenough/pull/1394) Urdu spelling, [#1411](https://github.com/aaronified/fluenough/pull/1411) sentences, [#1409](https://github.com/aaronified/fluenough/pull/1409) kinds, [#1423](https://github.com/aaronified/fluenough/pull/1423) notes, [#1449](https://github.com/aaronified/fluenough/pull/1449) recommendations, [#1470](https://github.com/aaronified/fluenough/pull/1470) review-queue rows; all merged 2026-11-15). Rows marked *re-counted* were measured in that re-read; *not re-counted* rows were not measured in it. Still open: **IPA is BLOCKED** on issue [#1466](https://github.com/aaronified/fluenough/issues/1466) (`IPA_RE` rejects precomposed `ä`; the issue reports 475 of 3,443 forms invalid, quoted from the issue and not re-counted here), so the HI-110 rerun is pending; **culture 4 was not built** (no pre-1900 source readable on a page); culture 1 to 3 hold 6, 7 and 8 cards against a planned 18 each; compound-verbs multi-word has 5 of 20; **professional decks are held**. Owner instruction (2026-11-15): one session per language; this session owns Hindustani (`hi`) and takes it to full completeness "as fast as possible, by delegating to agents". It **overrides rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md)** for Hindustani. The shape is that of [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) and [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md). Rules 1 to 15 and rule 17 of the Deck-Work-Queue apply to every task (read Hindustani for "Japanese": Devanagari readings are ISO 15919 as `tools/transcribe.py hi` writes them, never by hand).

Hindustani is ONE course with two scripts (owner, 2026-10-18): `script: "devanagari"`, `scripts: ["devanagari", "perso_arabic"]`; a card's Urdu spelling is `target_scripts: { perso_arabic: "..." }`. Every deliverable that depends on script covers both. Grammar tables are full tables covering every word (owner, 2026-10-23).

State was read from `origin/decks-live` (2026-11-15) with PyYAML over every `decks/hi/**` file, `hi-path.yaml`, `decks/sections.yaml`, `decks/creators`, `decks/recommendations`, `docs/review-queue/hi.md`, `tools/phonetic_languages.yaml` on main.

## 1. Audit against the completeness checklist

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | not re-counted | last audit: `hi-path.yaml`, 120 units | none recorded |
| 2 | Cores and English layers | not re-counted | last audit: 128 vocab and 34 grammar cores. Own cards now 3,448 (re-counted; top-level `vocab` or `grammar` decks, cards with `id` and no `ref`; 70 `ref` cards excluded) | none recorded |
| 3 | Sentences decks | PRESENT (re-counted) | 74 of 74 word decks have a `-sentences` deck. 76 sentences decks in all, 919 sentence cards; 2 of them (`hi-grammar-sentences`, `hi-grammar-comparison-sentences`) belong to no word deck. Per-deck size against the 10 to 25 spec not re-counted | none for the gap; size check not re-counted |
| 4 | Reading decks | PARTLY (re-counted) | 52 `hi-en-reading-*` decks at the top of `decks/hi/`. 45 of 74 word decks have one; 29 do not | HI-092 (audit first) |
| 5 | Script decks | not re-counted | last audit: Devanagari and Perso-Arabic script decks present | none recorded |
| 6 | Phrasebook | not re-counted | last audit: 20 cards (limit 25) | none recorded |
| 7 | Situations | PRESENT (re-counted) | `hi-situations.yaml`: 10 sheets, 8 to 9 phrases each (sheet content not re-checked) | sheet count matches HI-050; content not re-checked |
| 8 | Topics incl. script topics | PARTLY (re-counted) | `hi-topics.yaml`: 12 topics (kinds: 6 grammar, 3 verbs, 2 script, 1 words). No topic has kind `other`, so the HI-041 additions are absent | HI-041 |
| 9 | Culture decks | PARTLY (re-counted) | `hi-culture-1` 6 cards, `hi-culture-2` 7, `hi-culture-3` 8 (planned 18 each). `hi-culture-4` is not built: no pre-1900 source readable on a page | HI-010..012 short; HI-013 not built |
| 10 | Creators, eras, legacy | PRESENT (re-counted) | `decks/creators/hi.yaml`: 38 creators, 5 eras. Legacy rule not re-counted | creators against culture cards not re-counted |
| 11 | Proverbs | PARTLY (re-counted) | `hi-proverbs-1` 17 cards, `hi-proverbs-2` 18, `hi-proverbs-3` 20 (planned 20 each) | HI-020..022 short by 3 and 2 on 1 and 2 |
| 12 | Multi-word verbs | PARTLY (re-counted) | `hi-multiword-compound-verbs` 5 of 20; `hi-multiword-conjunct-verbs` 18, `hi-multiword-ko-experiencer` 9, `hi-multiword-muhavare` 17 (planned 20 each) | HI-030..033: compound-verbs to 20 and the other three families short |
| 13 | Professional | HELD (not re-counted) | `professions: []` not re-counted | none (needs the owner) |
| 14 | Recommendations | PARTLY (re-counted) | `decks/recommendations/hi.yaml`: 16 entries (planned 20) | 4 more to reach the plan |
| 15 | Narrow IPA and broad `ipa` | **BLOCKED** on #1466 | `phonetic` on 1,403 of 3,448 own cards; broad `ipa` on 3,432 (16 cards without). Invalid-form count from #1466 (475 of 3,443), not re-counted here | HI-110 rerun after #1466 is fixed; HI-112 for the 16 cards without broad `ipa` |
| 16 | Review-queue rows | PARTLY (re-counted) | `docs/review-queue/hi.md`: 90 table rows (10 dated 2026-11-07, 80 dated 2026-11-15) | HI-120..122 as waves land |
| 17 | Sourcing list | **MISSING** (checked) | `wiki/Plan-Culture-Hindustani.md` is not on `origin/main` | HI-001 |
| 18 | Facts file | not re-counted | last audit: `hi-facts.yaml`, 42 entries | none recorded |
| + | Urdu spelling (`target_scripts.perso_arabic`) | PARTLY (re-counted) | 2,271 of 3,448 own cards have it (1,177 without). Set-like script and phonology decks are not split out in this count | HI-100..105 for the remaining word cards |
| + | Notes gap | PARTLY (re-counted) | 2,611 of 3,448 own cards have `notes` (837 without) | HI-130..137 for the remaining gap |
| + | Grammar tables | NOT AUDITED | 34 grammar decks; the full-table rule (owner, 2026-10-23) needs a read by a Sonnet | HI-093 |

## 2. Conventions every HI task carries

- **Header of a genre deck:** as `es-culture-1` with `language: { code: "hi", iso639_3: "hin", name: "Hindustani", script: "devanagari", scripts: ["devanagari", "perso_arabic"], tts: "hi-IN", icon: "हि" }`, `part: "core"`, `kind: "vocab"`, `genre`, `level`, `tags: ["unreviewed"]`, `license: "CC-BY-SA-4.0"`; layer `decks/hi/en/hi-en-<name>.yaml`.
- **Readings and IPA:** `reading` and broad `ipa` come from `python3 tools/transcribe.py hi "<text>" <hint>` (the hint is the word as typed in Latin letters, which tells the tool what is said). Never hand-written. No `phonetic` and no `phonetic_source` on a new card: HI-110 writes them. The tool is run from `origin/main`'s `tools/`, which a worker checks out into its worktree and never commits.
- **Urdu spelling:** every new card with a Hindustani word has `target_scripts: { perso_arabic: "..." }`, read from ur.wiktionary or the Rekhta dictionary page; a spelling not read goes to the review queue and the card gets none (never guessed). Set-like script and phonology decks are skipped.
- **Ids:** the course's reserved range is `hi-4000` to `hi-6999` (highest id today `hi-3084`), sub-ranges per task below, ascending, never reused.
- **Rights floor for culture:** an author who died in 1955 or earlier (the validator floor); anonymous works need a first publication before 1900. Texts, dates and lifespans are read by the builder from hi.wikipedia, ur.wikipedia, hi.wikisource, ur.wikisource or Rekhta; what could not be read is dropped (never filled in) and replaced from the reserve. Excerpt at most 25 words. Both Devanagari text and its `perso_arabic` form when the work is in both traditions.
- **Review queue:** every row goes into the task's report; the batch's HI-12x task collects them into `docs/review-queue/hi.md`.
- **Validator traps** (CI failures seen so far): confusable ids are `[a-z0-9-]+`; a base word appears once per card (case-insensitive); `words` joins exactly to the whole target with no spaces inside entries; `bases[].word` is one word of the target; an entry has `ref` OR `base`, never both, and a ref entry has no `reading`; layer `bases` gloss only inline words, never an empty `bases`; every layer note needs a matching core `notes: [{id, kind}]` with one of the seven valid kinds (no `register`); a layer meaning is ONE sentence (join clauses with `;`); sentence cards need 2 to 3 confusables (existing word-card ids, layer keys equal core ids); every non-Latin word in layer text, descriptions and base meanings is followed by its reading in half-width parentheses; creators `born`/`died` is a plain year or `{ year, circa: true }` (never `circa: false`), `source.author` equals the creator's exact `name.en.text`, `legacy` has 1 to 6 items with sources; at most 25 `phrasebook: true` cards per course; a grammar unit writes no reading deck; every word of a kind in every B1 deck needs a row in every rules table of that kind; indentation errors can nest cards as examples.
- **Branches and PRs (rule 17):** each wave has ONE shared integration branch, one PR to `decks-live`, ONE Sonnet review (report-only), fixes applied by the workers. Workers use their own worktrees, merge `origin/decks-live` and the shared branch before each fast-forward push, never force, no tags, never open PRs. No agent runs the validator or the tests.
- **Shared files, one owner per wave:** `decks/hi/hi-topics.yaml` (HI-040/041), `decks/hi/hi-situations.yaml` (HI-050/051), `decks/creators/hi.yaml` (the culture tasks in order, then recommendations), `decks/recommendations/hi.yaml` (HI-060/061), `docs/review-queue/hi.md` (HI-120..122).

## 3. Task table

### 3.1 Wave A: the genre kinds (branch `decks/hi-kinds-wave1`)

| Id | Model | Creates / edits | Spec | Ids | Depends on |
|---|---|---|---|---|---|
| HI-001 | Sonnet, docs to main | `wiki/Plan-Culture-Hindustani.md` | The sourcing list, as `Plan-Culture-Spanish`: candidates for culture 1 to 4 (4 x 18 plus reserves), proverbs 1 to 3 (3 x 20), multiword (4 x 20), recommendations (20), each verified on a named page; both traditions (Hindi and Urdu authors, Bhakti, Sufi, ghazal, modern prose and verse, folk) | none | none |
| HI-010..013 | Haiku | `hi-culture-1..4` + layers, `creators/hi.yaml` | RULE-CULT as in 2. Culture 1 bhakti and sant poets; 2 classical Urdu poets; 3 modern Hindi and Urdu prose and verse to 1955; 4 anonymous and traditional pre-1900 (lullabies, paheliyan, folk songs, tales). 18 items each, fewer rather than padded | `hi-4000..4199` | HI-001; serial on `creators/hi.yaml` |
| HI-020..022 | Haiku | `hi-proverbs-1..3` + layers | `genre: "proverbs"`, `basis: "oral-tradition"`, 20 cards each (kahavatein and lokoktiyan); `source` with `collection`, `date`, `edition`, `jurisdiction`, `rights_checked`; one `literal` note per card; only text read on the cited page | `hi-4200..4349` | HI-001 |
| HI-030..033 | Haiku | `hi-multiword-*` + layers | `genre: "multiword"`, `pattern_family`, a `usage` note on every card. Families: conjunct verbs (noun + karnā/honā), compound or vector verbs (V + jānā, lenā, denā...), idiomatic muhāvare, ko-experiencer constructions; parts already taught by `ref` | `hi-4350..4549` | HI-001 |
| HI-040 | Haiku | `hi-topics.yaml` | As `es-topics`: 12 topics (kind `grammar`/`words`/`verbs`), real deck ids only: postpositions, ne and ergativity, honorifics, gender, the verb to be, tenses, conditionals, subjunctive, compound verbs, Persian and Arabic loanwords, both scripts (script topics: Devanagari, Perso-Arabic) | none | none |
| HI-041 | Haiku | edit `hi-topics.yaml` | 8 `kind: "other"` topics over the merged culture, proverbs, multiword decks | none | HI-010..033 merged |
| HI-050 | Haiku | `hi-situations.yaml` | Deck-Format "Situations files", rules of #1145; 10 sheets (taxi, shops, eat, doctor, traffic, rail, hotel, post and bank, greetings and apologies, emergencies), icon keys each once, 8 to 12 phrases and at most 12 words per sheet, ids real `hi-` cards; at most 12 new cards where a phrase is missing | `hi-4550..4599` | none |
| HI-060 | Haiku | `recommendations/hi.yaml` (10), `creators/hi.yaml` | Shape of `recommendations/es.yaml`: films, series and books in Hindi and Urdu, 3 questions each, no quote, no link, creators added | strings | HI-013 merged |
| HI-061 | Haiku | edit both | 10 more: books, songs, podcast, comic | strings | HI-060 |

### 3.2 Wave C-1: Urdu spelling (branch `decks/hi-urdu-spelling`)

HI-100..105: add `target_scripts.perso_arabic` to the word-deck cards that lack it (about 350 cards). Files and counts: hi-school 50, hi-illness 50, hi-hobbies 50, hi-cooking 50, hi-food 47, hi-body 32, hi-places 30, hi-animals 25, hi-things 18, hi-clothes 18, hi-pronouns 3, hi-describing 1; the `-sentences` decks carry the same gap (school, illness, hobbies, cooking 10 each, comparison 9, phone 3, chores 3, appearance 3). Each worker takes about 60 cards; source ur.wiktionary or Rekhta; unread goes to the queue.

### 3.3 Wave B: sentences decks (branch `decks/hi-sentences-wave1`)

HI-080..091: sentences decks for the 56 word decks without one, 12 workers of about 4 or 5 decks each, 10 to 25 sentences per deck by the verb-pool rule of the existing hi decks (look at `hi-food-sentences`), ids `hi-4600..4999` and `hi-5000..5999`. Decks: sound-differences, questions, addressing, family, numbers-1-20, about-me, time, numbers-big, groceries, market, transport, body, places, things, home, clothes, animals, daily-life, weather, calendar, festivals, eating-out, help, verbs-3, journey, nature, adjectives-2, workplace, geography, registers, arabic-words, feelings, slang, news, opinions, travel, services, government, technology, careers, environment, agriculture, cinema, arts, history, weddings, sports, relationships, housing, emergencies, law, verbs-4, abstract-words, money, literature, verbs-5. A deck whose unit teaches no verb the pool allows is reported, not forced.

### 3.4 Wave C-2: notes (branch `decks/hi-notes`)

HI-130..137: typed notes only where a card has one teachable point; ids in the core, text in the layer. Files with the most gaps (cards without a note): hi-numbers-big 77, hi-health-sentences 25, hi-food-sentences 25, hi-directions-sentences 25, hi-work-sentences 24, hi-shopping-sentences 20, hi-home 19, hi-numbers-1-20 18, hi-daily-life 13, then 40 more files with 11 or fewer.

### 3.5 Other tasks

| Id | Model | Spec |
|---|---|---|
| HI-092 | Haiku | List the 29 word decks without a reading deck and report which have a natural passage; builds nothing |
| HI-093 | Sonnet | Audit the 34 grammar decks against the full-table rule (every word of a kind has a row in every table of that kind); report gaps as new tasks |
| HI-110 | tool run | After all content PRs merge: `python3 tools/import_phonetic.py hi --write`, then `python3 tools/derive_phonetic.py hi --bracket-unchanged --write`; report counts; no hand edit. Read issue #1369 first (rule fixes and `--rederive` of PR #1372) |
| HI-111 | Sonnet | If HI-110's report shows rule gaps (Urdu-origin sounds q, x, ɣ, z; nukta consonants), extend `decks/hi/hi-phonetics.yaml` with sourced rules; one coder at a time |
| HI-112 | Haiku | Broad `ipa` for the 5 non-set cards that lack it, from `tools/transcribe.py`; the 11 phonology cards are checked first |
| HI-120..122 | Haiku | Append review-queue rows from each wave's reports to `docs/review-queue/hi.md` |
| HI-140 | Haiku, docs to main | Update the Hindustani row of [Plan-Language-Completeness](Plan-Language-Completeness.md) and issue #1167 from a re-read, claiming only what is verified |

## 4. Order

1. HI-001 (docs, main) first; HI-040, HI-050, HI-092, HI-093 and wave C-1 have no dependency and run at once.
2. Wave A culture tasks run serial on `creators/hi.yaml`; proverbs and multiword in parallel with them.
3. Waves B and C-2 touch disjoint files from wave A and run in parallel on their own branches.
4. HI-110 last, after every content PR has merged.

## 5. Open questions

- Professional decks need the owner's profession list.
- A source-it-yourself mode for recommendations is specified in [Plan-Language-Completeness](Plan-Language-Completeness.md) but not implemented; HI-060 and HI-061 use the shape of `recommendations/es.yaml`.
