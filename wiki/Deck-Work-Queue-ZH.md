# Deck work queue: Mandarin Chinese completion plan

Status: audit and plan of 2026-11-15. Owner instruction (2026-11-15): one session per language; this session owns Mandarin Chinese (`zh`) and takes it to full completeness "as fast as possible, by delegating to agents". It **overrides rule 16 of the [Deck-Work-Queue](Deck-Work-Queue.md)** for Chinese. The shape is that of [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md), [Deck-Work-Queue-HI](Deck-Work-Queue-HI.md) and [Deck-Work-Queue-ES-TE](Deck-Work-Queue-ES-TE.md). Rules 1 to 15 and rule 17 of the Deck-Work-Queue apply to every task (read Chinese for "Japanese"). Readings are pinyin with tone marks, based on Hanyu Pinyin and written as said (not strictly following it). Hanzi are basic only, nothing ambitious (as for Japanese kanji): an example word uses only taught words, and every character written is taught.

State was read from `origin/decks-live` (`09e2a6d6`) on 2026-11-15 with PyYAML over every `decks/zh/**` file and `zh-path.yaml`, plus `decks/sections.yaml`, `decks/creators/`, `decks/recommendations/`, `docs/review-queue/` and `tools/phonetic_languages.yaml` on main.

## 1. Audit against the completeness checklist

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | **DONE** | `zh-path.yaml`: 130 units, no unit planned, every deck it names has a file; A1 mark at unit 43, A2 at 83, B1 at 129; the resume list of the older queue (emergencies to grammar-politeness) is all built | none |
| 2 | Cores and English layers | **DONE** | 377 core files and 287 layers in `decks/zh/en/`: 173 vocab-style decks, 75 grammar cores, 89 reading decks (single file, no layer), sounds, script, path; 4,366 cards, highest id `zh-4888` | none |
| 3 | Sentences decks | **NEAR DONE** | each word unit has `-sentences`, except `zh-emergencies` (a B1 word unit), `zh-first-words` and the script decks (by precedent) | ZH-020 |
| 4 | Reading decks | **DONE, WITH A FLAW** | 89 single-file reading decks, every unit named by the path has one. The skill (build-deck, "Chinese, Japanese and Korean") records that the zh reading decks written before #814 offer English meanings as options of "which word means X" questions, which gives the answer away | ZH-200..ZH-2xx |
| 5 | Script decks | **DONE** | `zh-pinyin`, `zh-tones`, `zh-strokes-radicals`, `zh-script`, `zh-characters-1` to `-7` | none (ZH-040 makes them topics) |
| 6 | Phrasebook | **DONE** | `zh-phrasebook` | ZH-091 counts the `phrasebook: true` cards (limit 25) |
| 7 | Situations | **MISSING** | no `zh-situations.yaml` | ZH-050 |
| 8 | Topics incl. script topics | **MISSING** | no `zh-topics.yaml` | ZH-040 |
| 9 | Culture decks | **MISSING** | no `zh-culture-*` | ZH-001, ZH-010..013 |
| 10 | Creators, eras, legacy | **MISSING** | no `decks/creators/zh.yaml` | rides on ZH-010..013, 060 |
| 11 | Proverbs (including chengyu) | **MISSING** | none (`zh-idioms` is a B1 word unit, not a genre deck) | ZH-025..027 |
| 12 | Multi-word verbs | **MISSING** | none | ZH-030..032 |
| 13 | Professional | HELD | `professions: []` in `decks/sections.yaml` | none (needs the owner) |
| 14 | Recommendations | **MISSING** | no `decks/recommendations/zh.yaml` | ZH-060 |
| 15 | Narrow IPA and broad `ipa` | **BIG GAP** | 0 of 4,366 cards have `ipa` or `phonetic`; `tools/transcribe.py` has `mandarin()`, which returns the pinyin hint and an empty IPA; no `zh` entry in `tools/phonetic_languages.yaml`, no `decks/zh/zh-phonetics.yaml` | ZH-110..113 |
| 16 | Review-queue rows | **PARTLY** | `docs/review-queue/zh.md`: 105 lines, written 2026-11-05 and 2026-11-06 | ZH-120 |
| 17 | Sourcing list | **MISSING** | no `Plan-Culture-Chinese` | ZH-001 |
| 18 | Facts file | **MISSING** | no `decks/zh/zh-facts.yaml` | ZH-070 |

## 2. Conventions every ZH task carries

- **Header of a deck:** copy the exact block from `decks/zh/zh-family.yaml` (language code `zh`, `iso639_3: "cmn"`, `script: "han_simplified"`, `scripts: [han_simplified, han_traditional]`, `tts: "zh-CN"`, `icon: "中"`), `part: "core"`, `kind`, `license: "CC-BY-SA-4.0"`, `tags: [..., "unreviewed"]`; layer `decks/zh/en/zh-en-<name>.yaml`. Read the build-deck skill (Chinese sections) and one built unit of the same kind first.
- **Readings:** pinyin as said (不 is `bú` before a fourth tone; the 不 in 是不是 is neutral; third-tone sandhi is not written). Pinyin cannot be derived from characters, so a new card's `reading` is Wiktionary's pinyin read for that word, never invented; what cannot be verified goes to `docs/review-queue/zh.md`. Broad `ipa` and `phonetic` are written by the ZH-110..113 tools, never by hand; no new card carries them.
- **Ids:** highest today `zh-4888`; the validator's `--next-id` is not run locally, so ranges are reserved, ascending, never reused: situations phrase cards `zh-5000..5499`, genre kinds `zh-6000..6999` (culture 6000, proverbs 6200, multi-word 6400), sentences for `zh-emergencies` `zh-7000..7499`, reading questions of the ZH-2xx fixes keep their ids.
- **Rights floor for culture:** author died 1955 or earlier; anonymous works first published before 1900. Every text, date and lifespan is read from Wikipedia (en or zh), Wikisource or a cited dictionary page; what cannot be read is dropped, never filled from memory. Excerpt at most 25 words (characters count as words for the tool's check).
- **Validator traps (CI failures seen so far):** confusable ids are `[a-z0-9-]+`; a base word appears once per card (case-insensitive); `words` joins exactly to the whole target with no spaces inside entries; `bases[].word` is one word of the target; an entry has `ref` OR `base`, never both, and a ref entry has no `reading`; layer `bases` gloss only inline words, never an empty `bases`; every layer note needs a matching core `notes: [{id, kind}]` with kind one of behaviour, culture, homograph, lookalike, note, pair, usage; a layer meaning is ONE sentence (join clauses with `;`); sentence cards need 2 to 3 confusables (existing word-card ids, layer keys equal core ids); every non-Latin word in layer text, descriptions and base meanings is followed by its reading in half-width parentheses (never fullwidth), the card's reading letter for letter; creators `born`/`died` is a plain year or `{ year, circa: true }` (never `circa: false`), `source.author` equals the creator's exact `name.en.text`, `legacy` has 1 to 6 items with sources; `source.date` is a year, a range or `c. year` only; at most 25 `phrasebook: true` cards per course; excerpts at most 25 words; a grammar unit writes no reading deck; every word of a kind in every B1 deck needs a row in every rules table of that kind; indentation errors can nest cards as examples; a path topic counts as taught only through a rule id or a listed grammar deck.
- **Branches and PRs (rule 17):** each wave has ONE shared integration branch, ONE PR to `decks-live`, ONE Sonnet review (report-only, BLOCKING or NIT), fixes applied by the workers. Workers use their own worktrees, merge `origin/decks-live` and the shared branch before each fast-forward push, never force, no tags, never open PRs, never use session-management tools. No agent runs the validator or the tests.
- **Haiku guard (owner, 2026-11-10):** code a Haiku writes is in try/catch and reports every caught issue to the app logger and the report. Haiku never improvises: it stops and reports.
- **Shared files, one owner per wave:** `zh-topics.yaml` (ZH-040), `zh-situations.yaml` (ZH-050), `decks/creators/zh.yaml` (culture tasks in order, then recommendations), `decks/recommendations/zh.yaml` (ZH-060), `docs/review-queue/zh.md` (ZH-120).

## 3. Task table

| Id | Model | Branch | Spec |
|---|---|---|---|
| ZH-001 | Sonnet | main (docs) | `Plan-Culture-Chinese`: verified sourcing list for culture (4 decks, about 18 items each; classical texts, poems, philosophy, chengyu stories, festival texts), proverbs and chengyu (3 decks, `basis: oral-tradition`), multi-word families (the right ones for Chinese: verb-object separable compounds, resultative and directional compounds, light-verb and idiomatic verb phrases; the builder decides), recommendations (public-domain and source-it-yourself), creators and eras; nothing from memory |
| ZH-110..113 | Sonnet design, then tools | `phonetics/zh` (tools PR to main), `decks/zh-phonetics-wave1` | `zh` entry in `tools/phonetic_languages.yaml`; `mandarin()` of `tools/transcribe.py` gives a broad `ipa` from the pinyin it already has; `decks/zh/zh-phonetics.yaml` rules for the narrow `phonetic` (tone letters, neutral tone, retroflex and apical vowels, aspiration, sandhi decisions recorded); then `import_phonetic.py` / `derive_phonetic.py` over all cards. Lessons of #1369, Telugu #1390 and Kannada KN-110. A shared-code change goes to the parent by issue plus message |
| ZH-020 | Haiku | `decks/zh-b1-wave1` | `zh-emergencies-sentences` core and layer, 2 to 3 confusables per card, ids `zh-7000..` |
| ZH-040 | Haiku | `decks/zh-topics-wave1` | `zh-topics.yaml`: script topics (pinyin, tones, strokes and radicals, characters 1 to 7), grammar, word and culture topics |
| ZH-050 | Haiku | `decks/zh-situations-wave1` | `zh-situations.yaml`: 10 sheets, widely used phrases only, marked draft |
| ZH-010..013 | Haiku | `decks/zh-culture-wave1` | `zh-culture-1` to `-4` with creators and eras, from ZH-001 only |
| ZH-025..027 | Haiku | `decks/zh-proverbs-wave1` | `zh-proverbs-1` to `-3`, 20 cards each, from ZH-001 only |
| ZH-030..032 | Haiku | `decks/zh-multiword-wave1` | `zh-multiword-*` families from ZH-001 |
| ZH-060 | Haiku | `decks/zh-recs-wave1` | `decks/recommendations/zh.yaml`, public-domain and source-it-yourself, from ZH-001 |
| ZH-070 | Haiku | `decks/zh-facts-wave1` | `decks/zh/zh-facts.yaml`: path facts, each with a source read, as `decks/ja/ja-facts.yaml` |
| ZH-091 | Sonnet | report only | count `phrasebook: true` cards; check the 75 grammar cores against the full-table rule |
| ZH-200..2xx | Haiku | `decks/zh-readings-fix-wave1` | In each reading deck, a question that asks "which word means X" offers the Chinese words with their pinyin, never the English meanings (question ids unchanged); a grammar unit still gets no reading deck |
| ZH-120 | Haiku | rides on each wave | Review-queue rows for every uncertain card |

## 4. Log

| Date | What |
|---|---|
| 2026-11-15 | Audit written. Path, cores, sentences, readings and script decks are done; every genre kind, topics, situations, facts, creators, recommendations and all IPA are missing |
