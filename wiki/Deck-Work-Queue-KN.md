# Deck work queue: Kannada completion plan

Status: audit and plan of 2026-11-15. Owner instruction (2026-11-15): one session per language; this session owns Kannada (`kn`) and takes it to full completeness "as fast as possible, by delegating to agents". It **overrides rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md)** for Kannada. The shape is that of [Deck-Work-Queue-GU](Deck-Work-Queue-GU.md), [Deck-Work-Queue-HI](Deck-Work-Queue-HI.md), [Deck-Work-Queue-MR](Deck-Work-Queue-MR.md), [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) and [Deck-Work-Queue-FR](Deck-Work-Queue-FR.md). Rules 1 to 15 and rule 17 of the Deck-Work-Queue apply to every task (read Kannada for "Japanese"). Kannada readings are ISO 15919-based, written by `tools/transcribe.py kn`, never by hand. Kannada is a Dravidian language close to Telugu in script and phonology: read the Telugu lessons in [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md) (issues #1357, #1361, word-final handling) before the phonetics tasks.

State was read from `origin/decks-live` on 2026-11-15 with PyYAML over every `decks/kn/**` file and `kn-path.yaml`, plus `decks/sections.yaml`, `decks/creators/`, `decks/recommendations/`, `docs/review-queue/` and `tools/phonetic_languages.yaml` on main.

## 1. Audit against the completeness checklist

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | **DONE** | `kn-path.yaml`: 115 entries (110 units plus 5 mark lists), every unit has its deck; A1, A2 and B1 marks present | none (KN-090 checks the grammar tables) |
| 2 | Cores and English layers | **DONE** | 134 files directly in `decks/kn/` (96 vocab, 30 grammar, plus sounds, numbers, script, facts, romanisation, reading, path), 128 layers in `decks/kn/en/`; 2,003 cards, highest id `kn-1733` | none |
| 3 | Sentences decks | **BIG GAP** | only `kn-grammar-sentences`; none of the 96 vocab decks has a `-sentences` deck | KN-100..KN-1xx |
| 4 | Reading decks | **BIG GAP** | `kn-en-reading-ravi` and `kn-script-reading` only | KN-200..KN-2xx |
| 5 | Script decks | **DONE** | vowels, consonants, vowel signs, conjuncts, digits, reading, `kn-script`, `kn-spelling`, `kn-romanisation` (conjunct coverage to check) | KN-091 checks |
| 6 | Phrasebook | **DONE** | `kn-phrasebook`: 20 cards (limit 25) | none |
| 7 | Situations | **MISSING** | no `kn-situations.yaml` | KN-050 |
| 8 | Topics incl. script topics | **MISSING** | no `kn-topics.yaml` | KN-040 |
| 9 | Culture decks | **MISSING** | no `kn-culture-*` | KN-001, KN-010..013 |
| 10 | Creators, eras, legacy | **MISSING** | no `decks/creators/kn.yaml` | rides on KN-010..013, 060 |
| 11 | Proverbs | **MISSING** | none (owner 2026-11-13: built for every priority language) | KN-020..022 |
| 12 | Multi-word verbs | **MISSING** | rules decks `kn-grammar-compound-verbs` and `kn-grammar-conjunct-verbs` exist (not genre decks) | KN-030..032 |
| 13 | Professional | HELD | `professions: []` in `decks/sections.yaml` | none (needs the owner) |
| 14 | Recommendations | **MISSING** | no `decks/recommendations/kn.yaml` | KN-060 |
| 15 | Narrow IPA and broad `ipa` | **GAP** | no `kn` entry in `tools/phonetic_languages.yaml`, no `decks/kn/kn-phonetics.yaml`; 0 of 2,003 cards have `phonetic`; 1,715 have a broad `ipa`, 288 do not | KN-110..112 |
| 16 | Review-queue rows | **PARTLY** | `docs/review-queue/kn.md`: 12 rows, all 2026-11-07 | KN-120 |
| 17 | Sourcing list | **MISSING** | no `Plan-Culture-Kannada` | KN-001 |
| 18 | Facts file | **DONE** | `kn-facts.yaml`: 44 facts | none |

## 2. Conventions every KN task carries

- **Header of a deck:** copy the exact block from `decks/kn/kn-first-words.yaml` (language code `kn`, `iso639_3: "kan"`, script, tts, icon as there), `part: "core"`, `kind: "vocab"` or `grammar`, `license: "CC-BY-SA-4.0"`, `tags: [..., "unreviewed"]`; layer `decks/kn/en/kn-en-<name>.yaml`. Read the build-deck skill and one built unit of the same kind first.
- **Readings and IPA:** `reading` and broad `ipa` from `python3 tools/transcribe.py kn "<text>" <hint>`, run from `origin/main`'s `tools/` checked out into the worker's worktree, never committed. Never hand-written. No `phonetic` on a new card: KN-110..112 write them.
- **Ids:** highest today `kn-1733`; the validator's `--next-id` is not run locally, so ranges are reserved: sentences `kn-7000..8499`, genre kinds `kn-6000..6999`. Sub-ranges per task, ascending, never reused.
- **Rights floor for culture:** author died 1955 or earlier; anonymous works first published before 1900. Every text, date and lifespan is read from kn.wikipedia, kn.wikisource, Wikipedia or a cited dictionary page; what cannot be read is dropped, never filled from memory. Excerpt at most 25 words.
- **Validator traps (CI failures seen so far):** confusable ids are `[a-z0-9-]+`; a base word appears once per card (case-insensitive); `words` joins exactly to the whole target with no spaces inside entries; `bases[].word` is one word of the target; an entry has `ref` OR `base`, never both, and a ref entry has no `reading`; layer `bases` gloss only inline words, never an empty `bases`; every layer note needs a matching core `notes: [{id, kind}]` with kind one of behaviour, culture, homograph, lookalike, note, pair, usage; a layer meaning is ONE sentence (join clauses with `;`); sentence cards need 2 to 3 confusables (existing word-card ids, layer keys equal core ids); every non-Latin word in layer text, descriptions and base meanings is followed by its reading in half-width parentheses; creators `born`/`died` is a plain year or `{ year, circa: true }` (never `circa: false`), `source.author` equals the creator's exact `name.en.text`, `legacy` has 1 to 6 items with sources; `source.date` is a year, a range or `c. year` only; at most 25 `phrasebook: true` cards per course; a grammar unit writes no reading deck; every word of a kind in every B1 deck needs a row in every rules table of that kind; indentation errors can nest cards as examples.
- **Branches and PRs (rule 17):** each wave has ONE shared integration branch, ONE PR to `decks-live`, ONE Sonnet review (report-only, BLOCKING or NIT), fixes applied by the workers. Workers use their own worktrees, merge `origin/decks-live` and the shared branch before each fast-forward push, never force, no tags, never open PRs, never use session-management tools. No agent runs the validator or the tests.
- **Haiku guard (owner, 2026-11-10):** code a Haiku writes is in try/catch and reports every caught issue to the app logger and the report. Haiku never improvises: it stops and reports.
- **Shared files, one owner per wave:** `kn-topics.yaml` (KN-040), `kn-situations.yaml` (KN-050), `decks/creators/kn.yaml` (culture tasks in order, then recommendations), `decks/recommendations/kn.yaml` (KN-060), `docs/review-queue/kn.md` (KN-120).

## 3. Task table

| Id | Model | Branch | Spec |
|---|---|---|---|
| KN-001 | Sonnet | main (docs) | `Plan-Culture-Kannada`: verified sourcing list for culture (4 decks), proverbs (3), multi-word families, recommendations; nothing from memory |
| KN-100..KN-1xx | Haiku | `decks/kn-sentences-wave1` | One `-sentences` core and layer for each of the 96 vocab decks in path order, 2 to 3 confusables per card, notes where a base changes stem; word units only (grammar units have none) |
| KN-200..KN-2xx | Haiku | `decks/kn-readings-wave1` | One reading deck per word unit named by the path, built after its sentences deck exists |
| KN-010..013 | Haiku | `decks/kn-culture-wave1` | `kn-culture-1` to `-4` with creators and eras, from KN-001 only |
| KN-020..022 | Haiku | `decks/kn-proverbs-wave1` | `kn-proverbs-1` to `-3`, 20 cards each, `basis: oral-tradition` |
| KN-030..032 | Haiku | `decks/kn-multiword-wave1` | `kn-multiword-*` families (compound verbs, conjunct verbs, dative-subject, idiomatic) |
| KN-040 | Haiku | `decks/kn-topics-wave1` | `kn-topics.yaml`: script topics (vowels, consonants, conjuncts, digits) plus grammar, word and culture topics |
| KN-050 | Haiku | `decks/kn-situations-wave1` | `kn-situations.yaml`: 10 sheets, widely used phrases only, marked draft |
| KN-060 | Haiku | `decks/kn-recs-wave1` | `decks/recommendations/kn.yaml`, public-domain and source-it-yourself, from KN-001 |
| KN-090..091 | Sonnet | report only | Read the 30 grammar cores against the full-table rule (owner 2026-10-23) and script-conjunct coverage |
| KN-110..112 | Sonnet design, then tools | `phonetics/kn` (tools PR to main) | `kn` entry in `tools/phonetic_languages.yaml`, `decks/kn/kn-phonetics.yaml` rules (lessons of #1369 and Telugu #1390), then `import_phonetic.py`/`derive_phonetic.py` over all cards |
| KN-120 | Haiku | rides on each wave | Review-queue rows for every uncertain card |
