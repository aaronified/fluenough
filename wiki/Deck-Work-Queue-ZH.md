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
| 15 | Narrow IPA and broad `ipa` | **BIG GAP** (built on two branches, section 4, not merged) | 0 of 4,366 cards have `ipa` or `phonetic`; `tools/transcribe.py` has `mandarin()`, which returns the pinyin hint and an empty IPA; no `zh` entry in `tools/phonetic_languages.yaml`, no `decks/zh/zh-phonetics.yaml` | ZH-110..113 |
| 16 | Review-queue rows | **PARTLY** | `docs/review-queue/zh.md`: 105 lines, written 2026-11-05 and 2026-11-06 | ZH-120 |
| 17 | Sourcing list | **DONE** (2026-11-15) | [Plan-Culture-Chinese](Plan-Culture-Chinese.md): culture 4 decks (60 verified items), 3 proverb and chengyu decks, 4 multi-word families, 21 recommendations, 35 creators; open date question for BCE works | ZH-001 done |
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

## 4. ZH-110..113: broad and narrow IPA for Mandarin (design and runbook, 2026-11-15)

Status: designed and built on two branches, not merged. No pull request is open. **The tools branch changes shared code** (`tools/transcribe.py`, `tools/phonetic_patch.py`), so it goes to the parent by issue and message before any merge.

| Part | Branch | Head | What |
|---|---|---|---|
| Tools | `tools/zh-phonetics` (off main `6e373c164`) | `0416835b1` | `mandarin()` writes the broad `ipa`; new `tools/fill_ipa.py`; one-line flow cards patchable; `zh` registry entry; tests |
| Cards | `decks/zh-phonetics-wave1` (off decks-live `24cb5213e`) | `9289edc6e` | `decks/zh/zh-phonetics.yaml` (12 rules); `ipa`, `phonetic` and `phonetic_source: "rules"` on all 4,366 cards; 4 lines of a reading fixed |

### Diff summary of the shared code

| File | Change |
|---|---|
| `tools/transcribe.py` | `mandarin()` still returns the hint as the reading and now also the broad IPA, from the new `mandarin_ipa(pinyin)`: tables `ZH_INITIAL_IPA`, `ZH_FINAL_IPA`, `ZH_ERHUA_IPA`, `ZH_TONE_LETTERS`, a syllable splitter (`_zh_segment`, `_zh_full_final`) and `_zh_word_ipa`. Zh-specific; no other language's function is touched. No hint still raises `CannotRead`. Pinyin it cannot read returns an empty IPA, `fitted` false and a note naming the word (it does not raise, so `import_wiktionary.py`, which only reads `.reading`, is unaffected) |
| `tools/phonetic_patch.py` | additive: `_flow_keys`, `_flow_line`, `flow_insert`, `_patch_flow`; `patch()` falls back to them when a card is not in a block layout; `core_cards()` marks such a card writable. Block, quoted-key and JSON layouts take exactly the old path |
| `tools/fill_ipa.py` | new, 223 lines: adds the broad `ipa` after the `reading` line of core vocab cards that have a reading and no `ipa`, by text patching (same discipline as `phonetic_patch.py`); report, `--write`, `--report`; every card guarded; exit 1 on a card it could not write. Generic over languages through `transcribe(target, lang, reading)`; only Chinese was run |
| `tools/phonetic_languages.yaml` | `zh` entry, `dump: "Chinese"`, `untagged: false` (rules only). The Kannada branch `tools/kn-phonetics` appends its entry at the same end of the file: a trivial conflict on whichever merges second |
| `tools/test_transcribe.py`, `test_phonetic.py`, `test_fill_ipa.py` | added tests (not run locally: CI only); the real rules file is tested only where it is on disk, so on main they skip |

### Why the broad `ipa` had to come first, and why a new tool

0 of 4,366 cards had an `ipa`, and `derive_phonetic.py` derives from it. `import_wiktionary.py` writes an `ipa` only for new cards, and `transcribe_decks.py` only corrects a stored one, so no tool added one to a card that has a reading and none. `fill_ipa.py` is that tool. Nine of the 210 core files (`zh-market`, `zh-numbers-big`, `zh-work` and their sentences decks, the three measure and money sentences decks) write each card on one line (`- {"id": "zh-0644", ..., "reading": "gōngsī", ...}`), a layout the patcher did not know (160 cards); it now does. Spliced text goes after the top-level `reading` (or `ipa`) value, found by a small scanner that skips nested lists, so an example's own `reading` or `ipa` is never mistaken for the card's.

### The broad `ipa` convention (decided by the architect, the owner can overturn)

- Phonemic, no brackets, no tie bars, no syllable dots (the plan's convention); a pinyin word is one IPA word and words stay separated by one space; punctuation is dropped, as in the other courses.
- Every syllable ends in its tone, so the string needs no dots: Chao tone letters `˥˥ ˧˥ ˨˩˦ ˥˩` for tones 1 to 4 (the Cantonese and Vietnamese decks write tone letters after the syllable too), and `˙` (U+02D9, the light-tone mark) for the neutral tone. The validator's IPA test allows all of them; it refuses the superscript digits Wiktionary uses (U+2070 to U+2079).
- Initials: b p m f d t n l g k h = p pʰ m f t tʰ n l k kʰ x; j q x = tɕ tɕʰ ɕ; zh ch sh = ʈʂ ʈʂʰ ʂ; r = ɻ; z c s = ts tsʰ s. Finals: a o e ê = a o ɤ ɛ; ai ei ao ou = ai ei au ou; an en ang eng ong = an ən aŋ əŋ ʊŋ; er = ɚ; ie üe ian üan with ɛ; glides j w ɥ (y and w are spellings: ya = ja, wo = wo, yue = ɥɛ); the spellings are undone (ü written u after j q x y, `bo` = pwo, iu ui un = iou uei uen, apostrophes divide syllables); neutral e = ə.
- Apical vowels of zhi chi shi ri zi ci si are `ɨ` (Wikipedia's alternative analysis: one symbol, since they are in complementary distribution); the narrow rules write ɹ̩ and ɻ̩.
- Erhua follows the chart of Wikipedia, Erhua (coda i and n deleted, ŋ nasalises, rhotic ɻ or ɚ): shìr = ʂɚ˥˩, yìdiǎnr = i˥˩tjɐɻ˨˩˦, nǎr = naɻ˨˩˦. Rhotic mark ʵ is written ɻ.
- Citation tones: third-tone sandhi is not in the broad form (the readings do not write it); 不 and 一 are written as said in the readings and so in the `ipa`.

### The narrow rules (`decks/zh/zh-phonetics.yaml`, 12 rules, in order)

| Ids | Change |
|---|---|
| `zh-neutral-after-1` to `-4` | a neutral syllable (`˙`) takes the contourless pitch of the tone before it: after tone 1 `˨`, 2 `˧`, 3 `˦`, 4 `˩`; they run first because they read the original tone 3 |
| `zh-tone3-sandhi` | tone 3 before tone 3 becomes `˧˥` |
| `zh-tone3-half` | any other tone 3 followed by a syllable becomes the half-third `˨˩`; alone or last it keeps the full `˨˩˦` |
| `zh-apical-dental`, `zh-apical-retroflex` | ɨ after ts tsʰ s becomes ɹ̩; after ʈʂ ʈʂʰ ʂ ɻ becomes ɻ̩ |
| `zh-a-fronted`, `zh-a-backed` | /a/ is a̟ before i n and a̠ before u ŋ |
| `zh-schwa-fronted`, `zh-schwa-backed` | /ə/ is ə̟ before n and ə̠ before ŋ |

Sources: Wikipedia, Standard Chinese phonology (Vowels, Apical vowels, Tones), and Erhua, read 2026-11-15 through a page summary; the text ended at the Notes (the last 74,000 characters of the first page were not read). The primary works the page cites (Lee and Zee 2003 in the JIPA, and others) were not read. Left out on purpose, and why, are in the file's `description`: length of open syllables, voicing of unaspirated stops in weak syllables, tone 2 and 4 changes in connected speech, h as [x] or [h], r as [ʐ] or [ɻ], creaky tone 3, labiodental [ʋ] for w, coda nasals without closure, vowel reduction in weak syllables.

Two decisions inside the rules, for the owner or a phonetician: (1) the tone rules look across a single space (a pinyin word boundary is not a pause) and the broad `ipa` has no punctuation, so a pair of third tones across a comma or full stop is wrongly changed: counted on the cards, 346 pairs across a space, about 20 of them across punctuation; (2) a neutral syllable after another neutral one (one card, 孩子们 in a sentence) and a neutral-tone card on its own (four cards) keep `˙`.

### Why no Wiktionary import

The registry entry is `untagged: false`, nothing imported. The kaikki.org dump `Chinese` is one 1.2 GB file for every variety (`Content-Length` 1,214,692,243, modified 2026-10-30): a first `import_phonetic.py zh` would fetch all of it into `.cache/phonetic/`. The first 6 MB (291 entries, 5,213 sounds) hold no `[ ]` form at all; the 465 sounds tagged Mandarin are phonemic `/ /` forms with Chao tone digits as superscripts (`/t͡ɕi̯ɛn⁵⁵/`), which the zh-pron template generates from the pinyin, and which the validator's IPA test refuses. Only 6 MB were read: the rest of the dump was not counted, and it is possible, not likely, that later entries carry hand-entered `[ ]` forms. Run `import_phonetic.py zh` never: it would only report 0 filled after a 1.2 GB download.

### What the data branch holds (counted 2026-11-15)

| Commit | What |
|---|---|
| `10a1cfa64` | the reading of 导航 was `dǎováng` (not pinyin) in 4 lines of `zh-journey` and `zh-journey-sentences` (cards zh-2507, zh-2550); changed to `dǎoháng` and a review-queue row asks a reviewer to confirm. The only change to a reading |
| `4adbae5f9` | `decks/zh/zh-phonetics.yaml` |
| `bbc79afa6` | `python3 tools/fill_ipa.py zh --write`: 4,366 cards filled, 0 unreadable after the fix, 6 entries with no `target` skipped (ids zh-0136, 0599, 0226, 0597, 0105, 0598: `kind: "set"` entries, which have members and no reading). 210 files touched, one line added per card (a spliced `"ipa"` in the 160 one-line cards) |
| `9289edc6e` | `python3 tools/derive_phonetic.py zh --bracket-unchanged --write`: 3,265 filled, 1,101 unchanged and bracketed (no rule applies to them: no tone 3 next to another syllable, no neutral tone, no apical vowel, no a or ə before a coda), 0 invalid, 0 could not write; `phonetic_source: "rules"` on every card |

Examples (sentence cards carry no `ipa` of their own, as in the other languages' cards: only the 4,366 cards were filled; the 6,788 card examples are not): `你好` `ni˨˩˦ xau˨˩˦` and `[ni˧˥ xa̠u˨˩˦]`; `妈妈` `ma˥˥ma˙` and `[ma˥˥ma˨]`; `十` `ʂɨ˧˥` and `[ʂɻ̩˧˥]`.

### Runbook

Run last, serially, after every Chinese content PR (sentences, readings, culture, topics, situations, proverbs) has merged, because a new card has no `ipa`. Worktree off `origin/decks-live` with main's `tools/` (after the tools PR has merged) laid over it; never in the main checkout; no tests and no validator locally.

1. Tools PR to main (shared code: parent decides; Sonnet review). Then `decks/zh-phonetics-wave1` to decks-live (deck-only CI: "Validate decks" and "Released app reads the decks").
2. Cards added since: `python3 tools/fill_ipa.py zh --write`, then `python3 tools/derive_phonetic.py zh --bracket-unchanged --write`. Expected: only new cards filled, `cannot read` 0 (a pinyin the tool cannot read is listed on stderr: fix the reading, or open an issue about the table), `could not write (layout)` 0.
3. After any change to the rules file: `python3 tools/derive_phonetic.py zh --rederive --bracket-unchanged --write`.
4. Never run `import_phonetic.py zh` (see above). Do not hand-write `ipa` or `phonetic` on any new Chinese card (rule of the plan).

### Unverified

- No test, validator or `deck_index.py` was run (rule): the new tests, the validator's acceptance of the new `ipa` and `phonetic` values and of the rules file, and "Released app reads the decks" are CI's to say. The values were checked outside CI against the validator's own `IPA_RE` and NFC with a script (4,366 of 4,366 pass) and the word count of each `ipa` equals that of its `reading`.
- Not read: the primary phonetic sources; only Wikipedia summaries. Every rule ships `unreviewed`; the open points for a phonetician are the broad conventions above (ɻ or ʐ for r, ɨ for the apical vowels, `˙` for the neutral tone, ɐ in erhua), the cross-space sandhi, and the a/ə backness diacritics.
- Pinyin was not re-checked: the broad form is only as right as the 4,366 readings. One typo was found (导航); a card that is wrong in another way (a missing tone, a wrong tone) passes unnoticed. No reading was compared against a dictionary.
- Whether the app, the speaking drill or the checker expects `˙` or tone letters in `ipa` is not known; `lib/` was not read for this.

## 5. Log

| Date | What |
|---|---|
| 2026-11-15 | Audit written. Path, cores, sentences, readings and script decks are done; every genre kind, topics, situations, facts, creators, recommendations and all IPA are missing |
| 2026-11-15 | ZH-110..113 designed and built on `tools/zh-phonetics` and `decks/zh-phonetics-wave1` (section 4); not merged, no PR |
| 2026-11-15 | ZH-001 done: Plan-Culture-Chinese written with every item read on a named page; culture decks 2 and 3 wait on the BCE `source.date` question |
