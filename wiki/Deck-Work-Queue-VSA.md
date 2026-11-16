# Deck work queue: Vedic Sanskrit completion plan

Status: audit and plan of 2026-11-16. Owner instruction (2026-11-15): one session per language; this session owns Vedic Sanskrit (`vsn`, tracker #1206) and takes it to A1 with the completeness checklist of [Plan-Language-Completeness](Plan-Language-Completeness.md) as far as verifiable, by delegating to agents. Owner priority: right after Classical Sanskrit (`sa`, its own session and queue), before the other second-list languages. The shape is that of [Deck-Work-Queue-TA](Deck-Work-Queue-TA.md) and [Deck-Work-Queue-KN](Deck-Work-Queue-KN.md); rules 1 to 15 and 17 of the [Deck-Work-Queue](Deck-Work-Queue.md) apply to every task.

**Owner source rule (2026-11-16):** Vedic content comes from **public-domain works on its grammar and text**: Max Müller's Sanskrit Grammar for Beginners (1866) and Rig-Veda-Sanhita; Whitney's Sanskrit Grammar (1879) and Roots, Verb-forms (1885); Macdonell's Vedic Grammar for Students (1916), A Vedic Reader for Students (1917) and Vedic Mythology (1897); Lanman's Sanskrit Reader (1884); Griffith's Rigveda (1889-92), Atharvaveda (1895-96) and Yajurveda (1899); Muir's Original Sanskrit Texts; Monier-Williams (1899); Bloomfield's Vedic Concordance (1906). Each deck's source block cites the work and page. Verse excerpts follow the 25-word rule. Nothing is written from memory (owner directive 2026-11-15).

State was read from `origin/decks-live` on 2026-11-16 (`git ls-tree` over `decks/vsn/`, `decks/creators/`, `decks/recommendations/`, `docs/review-queue/`, `decks/themes.yaml`) and from `tools/` on main.

## 1. Audit against the completeness checklist

| # | Deliverable | State | Evidence | Tasks |
|---|---|---|---|---|
| 1 | Path to B1 | **PARTIAL** | `vsn-path.yaml`: 60 entries; 1 built (phrasebook + first words, 10 words), 58 planned, closing `*`; A1 mark at unit 30 (corrected 2026-11-16 by Plan-Vedic-Path), A2 and B1 marks per Plan-Vedic-Path; `alphabet: []`; levels A1 300, A2 400, B1 600 words. The planned themes are the generic template (clothes, weather, government, travel...), not a Vedic reading syllabus | VSA-010 re-plans the path, then VSA-1xx |
| 2 | Cores and English layers | **PARTIAL** | 2 vocab cores (`vsn-first-words` 10 cards `vsn-0001..0010`, `vsn-phrasebook` 20 cards `vsn-0011..0030`) and 2 layers; no grammar core | VSA-1xx |
| 3 | Sentences decks | **MISSING** | none | VSA-3xx |
| 4 | Reading decks | **MISSING** | no `vsn-en-reading-*` | VSA-4xx |
| 5 | Script decks | **MISSING** | no script, conjunct or accent-mark deck; path units 6 to 8 are planned (letters, conjuncts, accent marks); the first-words layer says "Vedic accent marks are not shown" | VSA-070..075 |
| 6 | Phrasebook | **DONE, to check** | `vsn-phrasebook`: 20 cards (limit 25). Cards such as `नमः`, `नमस्ते`, `स्वस्ति` need a sourced note each (is `namaste` a Rigvedic form, see RV 10.1 hymns); VSA-005 | VSA-005 |
| 7 | Situations (adapted: ritual and hymn contexts) | **MISSING** | no `vsn-situations.yaml` | VSA-050 |
| 8 | Topics incl. script topics | **MISSING** | no `vsn-topics.yaml` | VSA-040 |
| 9 | Culture decks | **MISSING** | no `vsn-culture-*` | VSA-011..014 (after VSA-001) |
| 10 | Creators, eras, legacy (rishis, editors, translators) | **MISSING** | no `decks/creators/vsn.yaml` | rides on VSA-011.., VSA-060 |
| 11 | Proverbs | **MISSING** | none. Vedic has no proverb tradition as such; only attested sayings in Rigveda/Atharvaveda, each sourced (Bloomfield's Concordance, Muir). Scope may be small | VSA-020 |
| 12 | Multi-word verbs | **MISSING** | none. Vedic preverb + verb with tmesis (the preverb stands apart) is the natural family | VSA-030 |
| 13 | Professional | **HELD** | `professions: []` in `decks/sections.yaml` | none |
| 14 | Recommendations | **MISSING** | no `decks/recommendations/vsn.yaml`; public-domain editions and translations only (source-it-yourself does not apply: these are all public domain) | VSA-060 |
| 15 | Narrow IPA and broad `ipa` | **BLOCKED** | no `vsn` engine in `tools/transcribe.py` (`python3 tools/transcribe.py vsn ...` fails in `parse`); no `vsn` entry in `tools/phonetic_languages.yaml`; no `vsn-phonetics.yaml`. The 30 existing readings and broad IPA were hand-written. 0 `phonetic` | VSA-110 first |
| 16 | Review-queue rows | **MISSING** | no `docs/review-queue/vsn.md` | VSA-120 |
| 17 | Sourcing list | **THIS PAGE, section 4** | host test and candidate works below; the verified list is VSA-001 | VSA-001 |
| 18 | Facts file | **MISSING** | no `vsn-facts.yaml` | VSA-080 |

### A1 gap, from the path (units 1 to 33)

Built: unit 1. Planned: 2 sound differences and pitch accent, 3 questions (5 words), 4 pronouns (16), 5 family (12), 6 numbers 1-20 (10), 7 to 9 script letters, conjuncts, accent marks, 10 about me, 11 everyday verbs, 12 adverbs, 13 quantities, 14 describing, 15 case system (grammar), 16 time, 17 location, 18 more verbs, 19 work, 20 a-stems (grammar), 21 numbers big, 22 food, 23 directions, 24 body, 25 places, 26 present system (grammar), 27 things, 28 home, 29 clothes, 30 animals, 31 weather, 32 calendar, 33 other stems.

## 2. Findings that shape the plan

- **No `vsn` transcription engine.** Readings and IPA are tool-written (CLAUDE.md). Classical Sanskrit (`sa`) needs the same Devanagari-to-ISO 15919 and IPA rules; the two sessions must share one engine (Sanskrit has no inherent-a deletion and writes anusvara and visarga as ṃ, ḥ). Shared code goes through the parent: issue plus `send_message`. Vedic adds pitch accent marks (udātta unmarked, anudātta ॒ U+0952, svarita ॑ U+0951 in the Rigveda tradition, and the Samaveda/Yajurveda systems differ), which the engine must either read (and strip from the reading, keep in `target`) or refuse. Whether the validator accepts these combining marks is checked by VSA-100.
- **Reconstructed pronunciation.** There are no living speakers; `ipa` is a reconstruction (the existing layer says so). Review-queue row: course-wide.
- **Reading course.** Milestones are reading levels (path header). Themes of modern life are left out; VSA-010 replaces the generic theme list with a Vedic one (ritual, cosmos, family, cattle and horse, war, hymn vocabulary).
- **Vedic differs from Classical** in forms the grammar units must state on the card: injunctive and subjunctive, infinitives in -tave, -dhyai, -tum rarely, tmesis, the pitch accent, the augmentless aorist, the instrumental plural -ebhiḥ beside -aiḥ, sandhi at hiatus (Vedic keeps some hiatus that Classical resolves; `ळ` (ḷ) for intervocalic ḍ in the Rigveda). Every one of these is confirmed in Whitney or Macdonell by VSA-001 before a card says it.
- **Sources reachable from the sandbox, tested 2026-11-16:** `sa.wikisource.org` (200; has `ऋग्वेद-पदपाठः/मण्डलम्-१` to `-१०`), `en.wikisource.org` (200; has `The Hymns of the Rigveda` in Griffith's translation, per-hymn pages), `en.wikipedia.org` (200), `commons.wikimedia.org` (200), `wikiquote.org` (200). **Blocked (proxy 403):** `archive.org`, `gutenberg.org`, `sacred-texts.com`, `sanskritdocuments.org`, `gretil.sub.uni-goettingen.de`, `titus.uni-frankfurt.de`, `books.google.com`. Whether Whitney, Macdonell, Müller and Monier-Williams are on Wikisource or Commons (page images or DjVu) is VSA-001's first step; a work that cannot be read from here is not cited.

## 3. Task table

Ids: highest today `vsn-0030`; reserved ranges (never reused, ascending inside a task): grammar words `vsn-0400..0999`, new vocab `vsn-1000..2999`, sentences `vsn-3000..3999`, genre kinds `vsn-6000..6999`.

| Id | Model | Branch | Spec |
|---|---|---|---|
| VSA-001 | Sonnet | main (docs) | Sourcing list: for each public-domain work above, which host serves a readable copy, then verified lists for culture decks, recommendations, proverbs and multi-word verbs; every entry read on a cited page; one-line drop reasons |
| VSA-010 | Sonnet | main (docs) then `decks/vsn-a1-wave1` | Re-plan `vsn-path.yaml` units 2 to 33 as a Vedic reading syllabus, themes drawn from the Rigveda's own vocabulary, with word counts inside `levels` |
| VSA-100 | Sonnet | main (docs) | Validator and app check: do Vedic accent marks (U+0951, U+0952, U+1CDA and others) pass `validate_decks.py` in `target`; does the font cover them (`decks/fonts`); record result |
| VSA-110 | Sonnet | `tools/vsn-transcribe` (tools PR to main, via parent) | `vedic` engine in `tools/transcribe.py`, shared with `sa` if that engine exists by then; accent policy from VSA-100; tests; verified against the 30 existing cards (a disagreement goes to the review queue, never silently edited) |
| VSA-005 | Haiku | `decks/vsn-a1-wave1` | Notes on the 30 existing cards: only teachable points that VSA-001 can source |
| VSA-070..075 | Haiku | `decks/vsn-a1-wave1` | `vsn-script-letters`, `-conjuncts`, `-accent-marks`, `-reading`; set `alphabet` in the path; from VSA-110 only |
| VSA-100.. | Haiku (Sonnet specs the tables first) | `decks/vsn-a1-wave1` | A1 word and grammar units in path order, layers, path entries moved from `planned` to `decks` in the same commit |
| VSA-3xx | Haiku | `decks/vsn-a1-wave1` | `-sentences` decks, 2 to 3 confusables per card, only from attested lines |
| VSA-040 | Haiku | `decks/vsn-topics-wave1` | `vsn-topics.yaml` |
| VSA-050 | Haiku | `decks/vsn-situations-wave1` | ritual and hymn contexts, widely used phrases only, marked draft |
| VSA-080 | Haiku | `decks/vsn-a1-wave1` | `vsn-facts.yaml`, only facts with a read source |
| VSA-011..014, 020, 030, 060 | Haiku | one branch each kind | culture, proverbs, multi-word, recommendations, from VSA-001 only |
| VSA-120 | Haiku | `decks/vsn-a1-wave1` | `docs/review-queue/vsn.md` rows for everything uncertain |

Order: VSA-001, 010, 100 (docs, parallel Sonnets), then VSA-110 through the parent; deck workers start the tool-free work (sourced facts, culture, recommendations) before the engine lands and the readings-bearing work after.

## 4. Open items for the owner

- None yet. Decisions made with defaults are recorded here as they come.
