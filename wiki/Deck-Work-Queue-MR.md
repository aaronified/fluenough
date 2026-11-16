# Deck work queue: Marathi completion plan

Status: audit and plan of 2026-11-15. Nothing here is built yet; the audit is the only work done. Owner instruction (2026-11-15): one session per language; this session owns Marathi (`mr`) and takes it to full completeness "as fast as possible, by delegating to agents". It **overrides rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md)** for Marathi. The shape is that of [Deck-Work-Queue-HI](Deck-Work-Queue-HI.md), [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) and [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md). Rules 1 to 15 and rule 17 of the Deck-Work-Queue apply to every task (read Marathi for "Japanese"; Devanagari readings are ISO 15919-based, written by `tools/transcribe.py mr`, never by hand).

State was read from `origin/decks-live` on 2026-11-15 with PyYAML over every `decks/mr/**` file, `mr-path.yaml`, `decks/sections.yaml`, `decks/creators/`, `decks/recommendations/`, `docs/review-queue/mr.md`, and from `origin/main`'s `tools/phonetic_languages.yaml`.

## 1. Audit against the completeness checklist

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | **DONE** (one check) | `mr-path.yaml`: 116 entries, none planned; A1, A2 and B1 milestones present. It lists `mr-reading-who-is-who`, which has no file under that id (the files on disk are `mr-en-reading-who-is-who` and `mr-en-reading-sunitacha-ravivar`, the latter listed as `mr-reading-sunitacha-ravivar`) | MR-090 |
| 2 | Cores and English layers | **DONE** | 130 core files, 130 layers in `decks/mr/en/`; 77 vocab cores, 51 grammar cores; 1,899 cards | none |
| 3 | Sentences decks | **GAP** | Only `mr-pronouns-sentences` and `mr-grammar-sentences`; none of the other 75 word decks has a `-sentences` deck | MR-080..091 (wave B) |
| 4 | Reading decks | **GAP** | Two (`mr-en-reading-who-is-who`, `mr-en-reading-sunitacha-ravivar`), for a path that names about 25 reading passages | MR-092 (audit), MR-093..095 |
| 5 | Script decks | **DONE** | Vowels, consonants, vowel signs, conjuncts, digits, reading, `mr-script`, `mr-spelling` | none |
| 6 | Phrasebook | **DONE** | `mr-phrasebook` | MR-090 checks the count (limit 25) |
| 7 | Situations | **MISSING** | no `mr-situations.yaml` | MR-050, MR-051 |
| 8 | Topics incl. script topics | **MISSING** | no `mr-topics.yaml` | MR-040, MR-041 |
| 9 | Culture decks | **MISSING** | no `mr-culture-*` | MR-001, MR-010..013 |
| 10 | Creators, eras, legacy | **MISSING** | no `decks/creators/mr.yaml` | rides on MR-010..013, 060, 061 |
| 11 | Proverbs | **MISSING** | none | MR-020..022 |
| 12 | Multi-word verbs | **MISSING** | rules decks `mr-grammar-compound-verbs` and `mr-grammar-conjunct-verbs` exist (not genre decks) | MR-030..033 |
| 13 | Professional | HELD | `professions: []` in `decks/sections.yaml` | none (needs the owner) |
| 14 | Recommendations | **MISSING** | no `decks/recommendations/mr.yaml` | MR-060, MR-061 |
| 15 | Narrow IPA and broad `ipa` | **GAP** | no `mr` entry in `tools/phonetic_languages.yaml` (only bn, hi, es, te, ja, fr), no `decks/mr/mr-phonetics.yaml`; 0 of 1,899 cards have `phonetic`; 1,796 have a broad `ipa`, 103 do not | MR-110..112 |
| 16 | Review-queue rows | PARTLY | `docs/review-queue/mr.md`: 18 lines, all 2026-11-07 | MR-120..122 |
| 17 | Sourcing list | **MISSING** | no `Plan-Culture-Marathi` | MR-001 |
| 18 | Facts file | **DONE** | `mr-facts.yaml` exists (count not re-read) | MR-090 checks 30+ |
| + | Notes gap | PARTLY | 242 of 1,899 cards have no `notes` | MR-130..134 |
| + | Grammar tables | NOT AUDITED | 51 grammar cores; the full-table rule (owner, 2026-10-23) needs a read by a Sonnet | MR-093G |

## 2. Conventions every MR task carries

- **Header of a genre deck:** as `es-culture-1` with `language: { code: "mr", iso639_3: "mar", name: "Marathi", script: "devanagari", tts: "mr-IN", icon: "म" }` (copy the exact block from `decks/mr/mr-first-words.yaml`), `part: "core"`, `kind: "vocab"`, `genre`, `level`, `tags: ["unreviewed"]`, `license: "CC-BY-SA-4.0"`; layer `decks/mr/en/mr-en-<name>.yaml`.
- **Readings and IPA:** `reading` and broad `ipa` come from `python3 tools/transcribe.py mr "<text>" <hint>`, run from `origin/main`'s `tools/` (checked out into the worker's worktree, never committed). Never hand-written. No `phonetic` on a new card: MR-110 writes them.
- **Ids:** the course's reserved range for new cards is `mr-4000` to `mr-6999` after `python3 tools/validate_decks.py --next-id mr` is checked by the architect (highest existing id to be read before the first task), sub-ranges per task, ascending, never reused.
- **Rights floor for culture:** an author who died in 1955 or earlier (the validator floor); anonymous works need a first publication before 1900. Texts, dates and lifespans are read by the builder from mr.wikipedia, mr.wikisource or a cited dictionary page; what could not be read is dropped (never filled in) and replaced from the reserve. Excerpt at most 25 words. Never write culture or facts from memory.
- **Review queue:** every uncertain row goes into the task's report; MR-12x collects them into `docs/review-queue/mr.md`.
- **Validator traps** (CI failures seen so far): confusable ids are `[a-z0-9-]+`; a base word appears once per card (case-insensitive); `words` joins exactly to the whole target with no spaces inside entries; `bases[].word` is one word of the target; an entry has `ref` OR `base`, never both, and a ref entry has no `reading`; layer `bases` gloss only inline words, never an empty `bases`; every layer note needs a matching core `notes: [{id, kind}]` with one of the seven valid kinds (behaviour, culture, homograph, lookalike, note, pair, usage); a layer meaning is ONE sentence (join clauses with `;`); sentence cards need 2 to 3 confusables (existing word-card ids, layer keys equal core ids); every non-Latin word in layer text, descriptions and base meanings is followed by its reading in half-width parentheses; creators `born`/`died` is a plain year or `{ year, circa: true }` (never `circa: false`), `source.author` equals the creator's exact `name.en.text`, `legacy` has 1 to 6 items with sources; `source.date` is a year, a range or `c. year` only; at most 25 `phrasebook: true` cards per course; excerpts at most 25 words; a grammar unit writes no reading deck; every word of a kind in every B1 deck needs a row in every rules table of that kind; indentation errors can nest cards as examples.
- **Branches and PRs (rule 17):** each wave has ONE shared integration branch, ONE PR to `decks-live`, ONE Sonnet review (report-only, BLOCKING or NIT), fixes applied by the workers. Workers use their own worktrees, merge `origin/decks-live` and the shared branch before each fast-forward push, never force, no tags, never open PRs, never use session-management tools. No agent runs the validator or the tests.
- **Haiku guard (owner, 2026-11-10):** any code a Haiku writes is in try/catch and reports every caught issue to the app logger and to the report. Haiku never improvises: it stops and reports.
- **Shared files, one owner per wave:** `decks/mr/mr-topics.yaml` (MR-040/041), `decks/mr/mr-situations.yaml` (MR-050/051), `decks/creators/mr.yaml` (the culture tasks in order, then recommendations), `decks/recommendations/mr.yaml` (MR-060/061), `docs/review-queue/mr.md` (MR-120..122).

## 3. Task table

### 3.1 Wave A: the genre kinds (branch `decks/mr-kinds-wave1`)

| Id | Model | Creates / edits | Spec | Ids | Depends on |
|---|---|---|---|---|---|
| MR-001 | Sonnet, docs to main | `wiki/Plan-Culture-Marathi.md` | The sourcing list, as `Plan-Culture-Telugu`: candidates for culture 1 to 4 (4 x 18 plus reserves), proverbs 1 to 3 (3 x 20), multiword (4 x 20), recommendations (20), each verified on a named page (mr.wikipedia, mr.wikisource, Wiktionary): sant poetry (Dnyaneshwar, Namdev, Eknath, Tukaram, Ramdas), powada and lavani, Peshwa-era prose, social reformers, modern poets and playwrights to 1955, anonymous folk songs, ovi and proverbs (mhani) | none | none |
| MR-010..013 | Haiku | `mr-culture-1..4` + layers, `creators/mr.yaml` | As the Telugu culture batches. Culture 1 sant poets; 2 powada, lavani, ovi and folk; 3 modern prose, verse and theatre to 1955; 4 anonymous and traditional pre-1900. 18 items each, fewer rather than padded | `mr-4000..4199` | MR-001; serial on `creators/mr.yaml` |
| MR-020..022 | Haiku | `mr-proverbs-1..3` + layers | `genre: "proverbs"`, `basis: "oral-tradition"`, 20 cards each (mhani); `source` with `collection`, `date`, `edition`, `jurisdiction`, `rights_checked`; one `literal` note per card; only text read on the cited page | `mr-4200..4349` | MR-001 |
| MR-030..033 | Haiku | `mr-multiword-*` + layers | `genre: "multiword"`, `pattern_family`, a `usage` note on every card. Families: conjunct verbs (noun + karaṇe/hoṇe), compound verbs (V + ṭākaṇe, ghēṇe, dēṇe, ...), idiomatic verbs (vākprachār), dative-subject constructions; parts already taught by `ref` | `mr-4350..4549` | MR-001 |
| MR-040 | Haiku | `mr-topics.yaml` | As `es-topics`: 12 topics (kind `grammar`, `words` or `verbs`), real deck ids only: postpositions, the oblique, ergativity, gender, the verb to be, tenses, conditionals, subjunctive, compound verbs, honorifics, loanwords, the script (script topic) | none | none |
| MR-041 | Haiku | edit `mr-topics.yaml` | 8 `kind: "other"` topics over the merged culture, proverbs and multiword decks | none | MR-010..033 merged |
| MR-050 | Haiku | `mr-situations.yaml` | Deck-Format "Situations files", rules of #1145; 10 sheets (taxi and rickshaw, shops, eating, doctor, traffic, rail, hotel, post and bank, greetings and apologies, emergencies), icon keys each once, 8 to 12 phrases and at most 12 words per sheet, ids real `mr-` cards; at most 12 new cards where a phrase is missing | `mr-4550..4599` | none |
| MR-060 | Haiku | `recommendations/mr.yaml` (10), `creators/mr.yaml` | Shape of `recommendations/es.yaml`: films, series and books in Marathi, 3 questions each, no quote, no link, creators added | strings | MR-013 merged |
| MR-061 | Haiku | edit both | 10 more: books, songs, podcast, play | strings | MR-060 |

### 3.2 Wave B: sentences decks (branch `decks/mr-sentences-wave1`)

MR-080..091: sentences decks for the 75 word decks without one, 12 workers of about 6 decks each, 10 to 25 sentences per deck by the verb-pool rule of the existing mr decks (read `mr-pronouns-sentences` and the Telugu or Bengali sentence decks for the shape), ids `mr-5000..6999`. A deck whose unit teaches no verb the pool allows is reported, not forced.

### 3.3 Wave C: readings, notes, checks

| Id | Model | Spec |
|---|---|---|
| MR-092 | Haiku | List which of the path's `reading_passages` have no reading deck (the path names about 25); builds nothing |
| MR-093..095 | Haiku | Build the reading decks MR-092 lists, branch `decks/mr-readings-wave1`, passages written from the path's one-line descriptions, 3 to 6 questions each |
| MR-093G | Sonnet | Audit the 51 grammar decks against the full-table rule; report gaps as new tasks |
| MR-090 | Haiku | Read-only check: the two path ids with no file (section 1, row 1), `mr-phrasebook` card count, `mr-facts` count; report |
| MR-130..134 | Haiku | Typed notes for the 242 cards without one, only where a card has one teachable point; ids in the core, text in the layer; branch `decks/mr-notes` |

### 3.4 Wave D: narrow IPA (branch `decks/mr-phonetics`)

| Id | Model | Spec |
|---|---|---|
| MR-110 | Sonnet | Design the Marathi variety and rules: a registry entry `"mr"` in `tools/phonetic_languages.yaml` (dump name "Marathi") and `decks/mr/mr-phonetics.yaml` with sourced rules (Marathi has the ʦ / ʣ affricates, retroflex ɭ, the schwa pattern); read [Plan-Ipa-Revamp-And-Language-Phonology](Plan-Ipa-Revamp-And-Language-Phonology.md) and issue #1369 first. The registry file is shared code: raised with the parent by a GitHub issue |
| MR-111 | tool run | After all content PRs merge: `python3 tools/import_phonetic.py mr --write`, then `python3 tools/derive_phonetic.py mr --bracket-unchanged --write`; report counts; no hand edit |
| MR-112 | Haiku | Broad `ipa` for the 103 cards that lack it, from `tools/transcribe.py`; the set-like phonology cards checked first |

### 3.5 Bookkeeping

| Id | Model | Spec |
|---|---|---|
| MR-120..122 | Haiku | Append review-queue rows from each wave's reports to `docs/review-queue/mr.md` |
| MR-140 | Haiku, docs to main | Update the Marathi row of [Plan-Language-Completeness](Plan-Language-Completeness.md) and issue #1177 from a re-read, claiming only what is verified |

## 4. Order

1. MR-001 (docs, main) first; MR-040, MR-050, MR-090, MR-092, MR-093G and wave B have no dependency and run at once.
2. Wave A culture tasks run serial on `creators/mr.yaml`; proverbs and multiword in parallel with them.
3. Waves B and C touch disjoint files from wave A and run in parallel on their own branches.
4. MR-111 last, after every content PR has merged.

## 5. Open questions

- Professional decks need the owner's profession list.
- A source-it-yourself mode for recommendations is specified in [Plan-Language-Completeness](Plan-Language-Completeness.md) but not implemented; MR-060 and MR-061 use the shape of `recommendations/es.yaml`.
- The `mr` registry entry is shared tooling; MR-110 goes through the parent.

## 6. Status (2026-11-16)

### Done and merged into decks-live

| PR | Content |
|---|---|
| #1456 | 72 sentence decks (861 cards), in the path |
| #1457 | `mr-topics` (12), `mr-situations` (10 sheets), `mr-proverbs-1..3` (60), `mr-culture-1` (18), creators |
| #1477 | `mr-multiword-1` (10 conjunct verbs) |
| #1478 | 72 reading decks (216 questions, mr-7000..7535), in the path |
| #1479 | `mr-culture-2` (18), `mr-culture-3` (8), 11 recommendations, creators |
| #1490 | 47 review-queue rows |
| #1497 | 156 notes on word cards (incl. 95 numeral notes), 20 queue rows |

### Merged since (2026-11-16)

| PR | Content |
|---|---|
| #1506 | `mr-multiword-2..5` (23 + 9 + 15 + 13 cards); one Sonnet review, two BLOCKING fixed |
| #1509 | `mr-culture-4` (6 cards), 11 more recommendations, creators; one Sonnet review, IPA slashes fixed |
| #1518 | culture 3 and 4 to 18 cards each (Addendum 1) |
| #1519 | narrow IPA rules `mr-phonetics.yaml` |
| #1520 | `phonetic` on 2,859 cards (tool run) |
| #1521 | review-queue rows 2 (12 rows) |

No PR is open.

### Remaining

a. The registry entry for `tools/phonetic_languages.yaml` (issue #1476, shared tooling: parent or owner) and the `ṁ` vs `m̐` question.
b. Situations: about 30 phrases need Marathi from a reviewer.
c. Items re-openable when a source appears: recommendations (songs, podcasts, Shwaas, Sant Tukaram, Ventilator); multi-word (structure-only entries); culture 4 and 3 are at 18 each, so there is no gap.
d. Owner questions: grammar-unit reading decks, professional decks, set cards with notes.

### Left out, with reasons (not accepted shortfalls: re-open when a source appears)

- Culture 4 and situations: ~30 phrases of `mr-situations` have no card (need Marathi from a reviewer); culture 4 reaches 18 only through step 2.
- Recommendations: songs and podcasts (no page found); Shwaas, Sant Tukaram, Sant Dnyaneshwar film, Ventilator (creator dates unreadable); Natsamrat/Katyar film pages.
- Multi-word: structure-only compound-verb entries (no stated meaning) and five gloss-only dative-subject rows; ten bases without a gloss (404 on both wiktionaries).
- Notes: set cards (mr-0694, mr-0695, mr-1001) cannot carry notes; mr-0474, mr-0606, mr-0393, mr-0562, mr-0403 have no certain note.
- Hosts blocked through the proxy: archive.org, britannica.com, imdb.com, wikibooks (en and mr), gutenberg.org, hathitrust.org, loc.gov, dsal.uchicago.edu, ncert.nic.in, ebalbharati.in, indianculture.gov.in, sahitya-akademi.gov.in, marathivishwakosh.org; the Wikimedia APIs rate-limit (429): pace 10 to 20 s.
- Open owner questions: grammar-unit reading decks (the wiki pages disagree; te and es list them); professional decks; `ṁ` for Marathi; whether set cards may carry notes.
