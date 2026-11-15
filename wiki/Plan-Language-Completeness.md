# Plan: language completeness, everything the app plans for a language, in full

Owner instructions of 2026-11-13, recorded as given:

1. "i want not just culture, but also topics, situations, everything the app now plans for a language, in FULL". For each priority language, in this order, the deck stream builds **every deliverable kind below, to full**: Japanese, Spanish, French, Telugu, Marathi, Bengali, Assamese, Gujarati.
2. "in culture lists, there can be some non public domain works, the learner has to source them themselves. the app will have questions on them after they have watched / read / heard them". See [Source-it-yourself works](#source-it-yourself-works-and-the-rights-floor).
3. "the culture deck settings should reside within the language list". No separate culture settings screen: the culture settings (on or off, weaving, level) are a part of the language's entry in the language list. This replaces the "setting" of T20 in [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md) and the open question 3 there, as far as the place of the setting goes.
4. "this will later be covered under the onboarding". A later onboarding item (the first-run flow offers the culture setting). **Nothing to build now.**

This page is a checklist and a plan. It builds nothing. The data model is
[Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics.md) (D-numbers below are
its sections); the Japanese culture batch is
[Plan-Culture-Japanese](Plan-Culture-Japanese.md).

## (a) Deliverables per language

State is for Japanese (`ja`). The Japanese rows are re-read from `origin/decks-live` and `origin/main` on 2026-11-15 (the other rows on 2026-11-13). "Done" means the files are on decks-live. Counts are of files, not of quality or coverage.

| # | Deliverable | Specified in | State for `ja` |
|---|---|---|---|
| 1 | Path to B1 (`<code>-path.yaml`, units, regions, alphabet, grammar) | [Deck-Format](Deck-Format.md) "Paths", "Writing a B1 course" | Partial. `decks/ja/ja-path.yaml` on decks-live has 170 units. Built units against planned units: not audited. Main has 40 files under `decks/ja/` (frozen); decks-live has 703 (319 directly in `decks/ja/`, 384 in `decks/ja/en/`; verified 2026-11-15) |
| 2 | Cores and English layers (vocab and grammar) | Deck-Format "Core and layer files" | Partial: 319 files directly in `decks/ja/` on decks-live, with 384 layers in `decks/ja/en/`. Grammar: 47 `ja-grammar-*` core files on decks-live, including the nine grammar units of JA-030 to 038 (PR #1378) (verified 2026-11-15). Its rule and example counts were not re-counted. Gaps against the path: not audited |
| 3 | Sentences decks | Deck-Format "Vocab decks" | Partial: most word units have a `-sentences` file; sentence and reading decks for units 17 to 36 were still owed on 2026-11-02, not re-checked. The seven word units of JA-023 to 029 (PR #1379) each have their `-sentences` file and their reading layer on decks-live (verified 2026-11-15) |
| 4 | Reading decks | Deck-Format "Reading decks" | Partial: six `ja-en-reading-*` files at the top of `decks/ja/`, and 80 `ja-en-reading-*` layers in `decks/ja/en/` on decks-live (verified 2026-11-15), including the seven word units of JA-023 to 029. Not audited further |
| 5 | Script decks (hiragana, katakana, marks, combos, basic kanji) | Deck-Format "Japanese kanji"; issue #1146 | Partial: `ja-en-hiragana` (46 cards), hiragana and katakana combos and marks, katakana, and `ja-kanji-1` to `ja-kanji-38`: 1,026 cards, one per character, the same set as the six grade topics. Basic kanji only; about 1000 kanji by B1 is deferred (#1146). On decks-live, 588 of the 1,026 kanji cards carry examples: JA-048 to 050 added 94 example pairs (PR #1388). Cards with no taught word using the kanji keep none, listed in `docs/review-queue/ja.md` (verified 2026-11-15) |
| 6 | Phrasebook | Deck-Format "The phrasebook" | Done: `ja-phrasebook` with its layer |
| 7 | Situations (one file per language, only widely used words and phrases, no over-translation) | Issue #1145; `lib/core/data/situations_parser.dart`; CLAUDE.md "Situations" | `ja-situations` on decks-live has 10 sheets (JA-013, PR #1356, merged). `decks/te/te-situations.yaml` exists, on decks-live, at 10 sheets (TE-004, PR #1354). Japanese sheets (#1124, draft) no longer wait for 0.10.0 (released, owner 2026-11-13), then their own PR |
| 8 | Topics, including script topics (`<code>-topics.yaml`, scripts are topics) | D6 | On decks-live: `decks/ja/ja-topics.yaml`, 22 topics: the two kana scripts, six kanji grades (`ja-kanji-grade-1` to `-6`), and 14 grammar, word and culture topics |
| 9 | Culture decks (`genre: culture`) | D1, D4; Plan-Culture-Japanese | On decks-live: `ja-culture-1` to `ja-culture-4`, with 18, 18, 4 and 18 cards (`genre: culture`) |
| 10 | Creators, eras and legacy | D5, D5b, D5c | On decks-live: `decks/creators/ja.yaml` with 59 creators and 10 eras |
| 11 | Proverbs (`genre: proverbs`, `basis: oral-tradition`) | D1, D4, #1135 | Partial: `ja-proverbs-1` to `-3` on decks-live, with 12, 20 and 20 cards. Named in Plan-Culture-Japanese as batch 2 |
| 12 | Multi-word verbs (`genre: multiword`) | D1, #1136 | Partial: five families on decks-live, 58 cards: `ja-multiword-compound-verbs` 8, `-compound-verbs-2` 13, `-idiomatic-verbs` 8, `-suru-verbs` 20, `-te-auxiliaries` 9 (verified 2026-11-15). The idiomatic-verb file's header says eight of twenty planned idioms are in it (JA-009, PR #1374) |
| 13 | Professional situations (`genre: professional`, hidden) | D1, D3, D8, #1139 | None. `professions: []` in `decks/sections.yaml` |
| 14 | Recommendations, public-domain and source-it-yourself, with quiz questions | D13, this page | Partial: `decks/recommendations/ja.yaml` on decks-live has 29 entries. The source-it-yourself mode is new (below) |
| 15 | Narrow IPA (`phonetic`) and a broad `ipa` on every card | [Plan-Ipa-Revamp-And-Language-Phonology](Plan-Ipa-Revamp-And-Language-Phonology.md) | Partial: `phonetic` on 5,691 of the 5,737 cards that have a broad `ipa` (verified 2026-11-15; JA-041, PRs #1422 and #1426, written by the tools). The 46 cards of `decks/ja/ja-en-hiragana.yaml` have none, because the tool skips that file's shape. The 16 entries with no `ipa` are reference-only (10 `set` entries and 6 `ref` entries; JA-039 is a no-op). The rules file is `decks/ja/ja-phonetics.yaml` (8 rules, JA-040, PR #1377) |
| 16 | Review-queue entries for everything uncertain | [Plan-Reviewing-Scope](Plan-Reviewing-Scope.md); `decks/review-queue.json` (generated on decks-live) | Partial: `docs/review-queue/ja.md` on decks-live (436 lines, verified 2026-11-15), including the rows of PRs #1388 and #1396 (JA-042 to 044). Queue for the rest: not audited |
| 17 | Sourcing list (the works, rights basis and checks) | Plan-Culture-Japanese; [Sources-and-Attributions](Sources-and-Attributions.md) | Batch 1 done in Plan-Culture-Japanese (18 items, candidates for next batches). None for proverbs, multi-word verbs or recommendations |
| 18 | Facts file (path facts, issue-held) | Deck-Format "Writing a B1 course" | Done: `decks/ja/ja-facts.yaml` on decks-live, 30 facts (JA-046, PR #1377; verified 2026-11-15) |

## Source-it-yourself works and the rights floor

A culture list may name a work that is **not** in the public domain. The
learner finds it, watches, reads or hears it, and marks it **completed**; the
app then asks the quiz questions. This extends D13 (recommendations: never
reproduced, questions asked only after the completed mark) to the culture
list, and gives the validator one more `basis`.

**Mode: `basis: "source-yourself"`** (on a recommendation, and on a culture-list
item that is a work of this kind). The validator **accepts** an item that has:

| Required | Rule |
|---|---|
| Identity | `title` (with reading where the language needs one), `medium` (book, film, series, song, play, podcast, comic), `creator` ids that resolve, `year` (not before the creator's `born`, not in the future) |
| Briefing | `briefing` in the learner's language, in the builder's own words: what it is, why it matters |
| Questions | 3 to 8 authored questions in the reading-deck shape, in the learner's language, with a valid `answer`, scheduled only after the completed mark (D13) |
| Rights note | `rights_checked` date and `jurisdiction`, so a reviewer can see when the status was judged; no `author_died` and no public-domain floor |
| Review | `reviewed` needs `checked_by` |

It **refuses** an item that has any of these:

| Refused | Why |
|---|---|
| A `target` field, an excerpt, lyrics, a line of dialogue or a passage from the work | Nothing of the work is shipped |
| Any run of target-language text longer than the title and character or place names (the tool counts words, or characters for a language written without spaces) | A quote hidden in a question or a briefing |
| An `image`, `audio` or video file | No media is shipped |
| A `legal` link that is not `https`, is on `tools/pirate_hosts.txt`, or whose host the tool cannot name | Never a pirate or unlicensed link (D13). A `legal` link stays optional |
| `basis: "quotation"` or `public-domain` on the same item | One basis per item. A public-domain work that is quoted is an ordinary culture card (D4) and may also be recommended through `quoted_in` |
| A question answerable without the work (the reviewer's check, not the tool's) | The questions test that the learner watched, read or heard it |

Learner state is unchanged from D13: the completed mark lives in the progress
database and backups, never in a deck. The mark's wording follows the medium
(watched, read, heard). The mode is specified here and **not implemented**.
Task T23 of the kinds plan is where it lands.

## (b) Status grid for the eight languages

"Not audited" means no one has listed the files; no guess is made. Japanese is the row with state, from (a).

| Deliverable | ja | es | fr | te | mr | bn | as | gu |
|---|---|---|---|---|---|---|---|---|
| Path to B1 | partial | done: 102 of 102 units built (verified 2026-11-15) | done: 112 of 112 units have their core, sentence and reading decks on decks-live, all present (A1 41, A2 31, B1 40); the header of `fr-path.yaml` still says A2 and B1 are planned (verified 2026-11-15) | not audited | not audited | done: 173 entries, 0 planned; A1 at unit 51, A2 at 91, B1 at 169 (verified 2026-11-15) | not audited | not audited |
| Cores and layers | partial | done: 71 core and 32 grammar decks (verified 2026-11-15) | done: 133 cores (77 vocab, 56 grammar), each with a layer; 82 more layers for sentence, culture, proverb and multi-word decks (verified 2026-11-15) | not audited | not audited | partial: 204 cores and 204 layers, none without a layer; the tense tables are small pattern decks, not rules tables (verified 2026-11-15) | not audited | not audited |
| Sentences, readings | partial | done: 68 sentence and 98 reading decks (verified 2026-11-15) | done for word units: 71 sentence decks (548 cards), named by the path; grammar units have none, by precedent. 111 reading decks (197 passages, 592 questions), one for every unit but the phrasebook; notes missing on 326 of 548 sentence cards (verified 2026-11-15) | not audited | not audited | partial: 66 sentence decks (17 themed word units have none) and 52 reading decks (21 units name passages with no reading deck) (verified 2026-11-15) | not audited | not audited |
| Script decks | partial: kana (`ja-en-hiragana`, combos, marks, katakana), kanji `ja-kanji-1` to `-38` (1,026 cards; basic kanji only) | n/a (Latin script) | n/a (Latin script) | partial: `te-script-conjuncts-2` (9 cards) and `te-script-archaic` (1 card), PR #1360 | not audited | partial: vowels 11, consonants 39, vowel signs 18, conjuncts 25, digits 10, reading words 16; about 50 common conjuncts and more reading words missing (verified 2026-11-15) | not audited | not audited |
| Phrasebook | done | done: 15 cards (verified 2026-11-15) | done: 24 cards in `fr-phrasebook`; 4 have no notes (verified 2026-11-15) | not audited | not audited | done: 20 cards (limit 25) (verified 2026-11-15) | not audited | not audited |
| Situations | partial: `ja-situations` at 10 sheets on decks-live | partial: 10 sheets in `es-situations.yaml` (verified 2026-11-15) | partial: 10 sheets in `fr-situations.yaml`, marked draft and unreviewed by a French speaker (verified 2026-11-15) | partial: `te-situations` at 10 sheets (TE-004, PR #1354) | not audited | none: no `bn-situations.yaml` (verified 2026-11-15) | not audited | not audited |
| Topics incl. script topics | partial: `ja-topics` on decks-live, 22 topics incl. the two kana and six kanji-grade script topics | partial: 22 topics in `es-topics.yaml` (verified 2026-11-15) | partial: 21 topics in `fr-topics.yaml`; no script topics (Latin script) (verified 2026-11-15) | partial: 12 topics in `te-topics.yaml` on decks-live (TE-048 partly) (verified 2026-11-15) | not audited | none: no `bn-topics.yaml` (verified 2026-11-15) | not audited | not audited |
| Culture, creators, legacy | partial: culture 1 to 4 on decks-live; `creators/ja.yaml` on decks-live (59 creators) | partial: 21 culture items of a target of 72 (`es-culture-1` to `-4`: 6, 2, 9, 4); 34 creators; es-4004, es-4150 and es-4151 have no creator (verified 2026-11-15) | partial: 71 of 72 planned items (`fr-culture-1` to `-4`: 18, 18, 18, 17); 66 creators in `decks/creators/fr.yaml`, where the review queue says 44 (verified 2026-11-15) | partial: `te-culture-1` to `-4` on decks-live; culture 1 has 4 verified items (PR #1381); `decks/creators/te.yaml` has 20 creators (verified 2026-11-15) | not audited | none: no culture deck and no `decks/creators/bn.yaml` (verified 2026-11-15) | not audited | not audited |
| Proverbs | partial: proverbs 1 to 3 on decks-live (52 cards) | partial: 60 items (verified 2026-11-15) | partial: 60 cards in `fr-proverbs-1` to `-3` (20 each); the files have no theme field, and a keyword check finds no 'santé' or 'saint' and no 'famil' in them (verified 2026-11-15) | partial: proverbs 1 to 3 on decks-live, 60 cards (verified 2026-11-15) | not audited | none (verified 2026-11-15) | not audited | not audited |
| Multi-word verbs | partial: five families on decks-live (58 cards, verified 2026-11-15) | partial: 80 items (verified 2026-11-15) | partial: 80 cards in four `fr-multiword-*` decks (verified 2026-11-15) | partial: three families on decks-live, 11, 20 and 20 cards (verified 2026-11-15) | not audited | none (the rules deck `bn-grammar-compound-verbs` and the vocab deck `bn-grammar-conjunct-verbs` are not genre decks) (verified 2026-11-15) | not audited | not audited |
| Professional | none | held: empty (verified 2026-11-15) | held: empty (`professions: []` in `decks/sections.yaml`) (verified 2026-11-15) | not audited | not audited | held: empty (verified 2026-11-15) | not audited | not audited |
| Recommendations, source-it-yourself | partial: 29 entries in `decks/recommendations/ja.yaml` | partial: 20 entries in `decks/recommendations/es.yaml` (verified 2026-11-15) | partial: 19 entries of 20 planned in `decks/recommendations/fr.yaml` (verified 2026-11-15) | partial: 15 entries in `decks/recommendations/te.yaml` on decks-live (verified 2026-11-15) | not audited | none: no `decks/recommendations/bn.yaml` (verified 2026-11-15) | not audited | not audited |
| Narrow IPA | partial: `phonetic` on 5,691 of 5,737 cards; the 46 cards of `ja-en-hiragana` have none (verified 2026-11-15, JA-041) | done: narrow and broad IPA on all 2,917 non-set cards (verified 2026-11-15); issue #1369 follow-up (PR #1372) open | partial: `phonetic` and `ipa` on 3,102 of 3,116 cards (the 14 set cards have neither); not checked by a French speaker (verified 2026-11-15) | partial: `te-phonetics.yaml` merged (PR #1390); 0 `phonetic` fields yet, TE-058 waits on PR #1397; 7 of 2,967 cards lack broad `ipa` (verified 2026-11-15) | not audited | partial: `phonetic` on 1,763 of 3,882 non-set cards (ids bn-2549 up), 2,119 lack it; broad `ipa` on all but 9 sound-concept cards; registry entry and `bn-phonetics.yaml` (2 rules) exist (verified 2026-11-15) | not audited | not audited |
| Review-queue entries | partial: 436 lines in `docs/review-queue/ja.md` on decks-live (verified 2026-11-15) | partial: 12 rows in `docs/review-queue/es.md` on decks-live, all for es-core-100 (verified 2026-11-15) | partial: 154 rows in `docs/review-queue/fr.md` (86 dated 2026-11-15, 68 dated 2026-11-06); 21 rows on the culture decks, 4 on public-domain or wartime basis; none on recommendations (verified 2026-11-15) | partial: 38 rows in `docs/review-queue/te.md`, on decks-live only (verified 2026-11-15) | not audited | partial: 9 rows in `docs/review-queue/bn.md` on decks-live (verified 2026-11-15) | not audited | not audited |
| Sourcing list | batch 1 | partial: `Plan-Culture-Spanish` (candidates only, nothing verified) | done: `Plan-Culture-French` on main (FR-001) | done: `Plan-Culture-Telugu` on main (TE-001) | not audited | none: no `Plan-Culture-Bengali` (task BN-001 of [Deck-Work-Queue-BN](Deck-Work-Queue-BN.md)) (verified 2026-11-15) | not audited | not audited |

**Hindustani (`hi`), verified 2026-11-15 on decks-live** (full audit in [Deck-Work-Queue-HI](Deck-Work-Queue-HI.md)): path, cores, script decks, phrasebook and facts done; sentences partly (20 of 74 word decks have one); readings partly (52 decks); situations, topics, culture, creators, proverbs, multi-word verbs, recommendations and the sourcing list missing; professional held; narrow IPA partly (1,403 of 2,635 own cards); Urdu spelling on 1,975 of 2,635 own cards; review queue 10 rows.

Counts on decks-live of all files under `decks/<code>/`, layers included, for orientation only (2026-11-13; ja re-counted 2026-11-15): ja 703, es 442, fr 380, te 302, mr 266, bn 465, as 436, gu 115. A file count says nothing about coverage.

**First task of the stream, before any build:** one audit per language filling the grid, from decks-live, one Haiku agent for the reads. Nothing is built for a language on a guess.

## (c) Batch order and size rules

All consistent with [CLAUDE.md](../CLAUDE.md): one Haiku deck builder and one Sonnet coder (never a second of either), an extra Sonnet only while a review runs, at most two agents at once, one Sonnet review per pull request, deck PRs target `decks-live`, never run the tests or the validator locally, no new branch after a merge.

| Rule | Value |
|---|---|
| Language order | Japanese, Spanish, French, Telugu, Marathi, Bengali, Assamese, Gujarati. A language is complete when its whole column of the grid is done; the next starts only then, except the audit, which may run ahead |
| Order inside a language | 1. audit; 2. path and cores to B1 (the gaps); 3. sentences and readings; 4. culture with creators; 5. proverbs; 6. multi-word verbs; 7. topics with script topics; 8. recommendations, including source-it-yourself; 9. situations (own file, own PR); 10. professional; 11. narrow IPA by the plan's tools; 12. review-queue and sourcing list, kept up with every batch rather than last |
| One batch, one PR | One kind per PR, to `decks-live`, with its creators, topics and review-queue lines. Larger PRs to spare CI (owner, 2026-10-30): a culture, proverb or multi-word batch of about 15 to 25 items. Path batches follow the existing 20-unit minimum, except Japanese |
| Japanese | Small batches, one at a time, merged when CI is green and the owner approves (owner, 2026-11-13). Basic kanji only |
| Plan before build | Each batch has its sourcing list in the wiki first, as Plan-Culture-Japanese has, and the stream builds only that list |
| No invention | Real works only; nothing from memory asserted as checked; uncertain items go to the review queue (the rule of Plan-Culture-Japanese) |
| Release | Deck content never needs a release. Code (the source-it-yourself validator mode, the language-list setting) is a separate code PR, with its CHANGELOG line |
| Not in this stream | Onboarding (later), a culture settings screen (not at all: the setting is in the language list), private decks, on-device voice |

## (d) Open questions

1. **Is deck work resumed?** CLAUDE.md says deck content stays paused until the owner resumes it, and ranks private decks and on-device voice next. The 2026-11-13 instruction reads as the resume for these eight languages. **Answer (owner, 2026-11-13: "hold the deck work. first complete all the code work. everything that is listed for 0.10.0 along with the scaffold and private decks."): deck work is held.** No deck agents run and the Japanese stream's batch 2 (PR #1160) stays open until the 0.10.0 code issues, the deck-kinds scaffold issues and private decks (#1017) are done. CLAUDE.md, "Deck work held until the code is done".
2. **"In FULL" for the path.** Does it mean the path to B1 for all eight (Gujarati has 115 files and no path audit), or only the kinds beyond the basics? Default taken: B1, except Japanese kanji (#1146).
3. **Languages without all kinds.** A proverb or multi-word-verb deck may not suit every language (Assamese, Gujarati). **Answer (owner, 2026-11-13): proverbs and multi-word decks are built for all priority-list languages.** "Not applicable" is no longer an outcome for these two rows of the grid; it is not allowed for them.
4. **Source-it-yourself and the 25-word rule.** The mode refuses all text of the work. Is a title and a character's name in the target script enough, or should a reviewer sign each item?
5. **Who is the rights reviewer** for a `basis: public-domain` card (question 7 of the kinds plan)? The stream's first culture batch is blocked on a named person. **Answer (owner, 2026-11-13):** the rights reviewer for non-public-domain culture items is the orchestrator ("YOU"), with a Sonnet review in the PR. The owner's answer names non-public-domain items; the public-domain case is not separately answered.
6. **Setting in the language list.** What does the entry hold: one culture switch, or also the weaving amount and the level? Needs a mockup (T17 and T20 of the kinds plan). **Answer (owner, 2026-11-13): the culture settings mockup for the language list is wanted ("yes"), queued behind the code work.**
7. **Situations for Japanese** wait for 0.10.0 (CLAUDE.md). **Answer (owner, 2026-11-13): situations no longer wait for 0.10.0, which is released.** This holds for all eight languages.
8. **Non-Latin-script sourcing.** For Telugu, Marathi, Bengali, Assamese and Gujarati the sourcing list needs a bilingual reviewer first. Who, and may Wikipedia stay the only source for dates (question 4 of Plan-Culture-Japanese)? **Answer (owner, 2026-11-13): every deck of every language, not just the Indic ones, ships unreviewed and is reviewed through the app's review mechanism (`docs/review-queue/<code>.md`). No named reviewer.**

## (e) Language tracking issues (2026-11-13)

Owner (2026-11-13): "Deck work issues to be updated with the full deck format as we have planned for all languages. So every language that the app has planned so far will have open issues (japanese and telugu are the closest to completion but not complete yet)." Each language below has exactly one open tracking issue carrying the checklist of section (a). Existing 'New course' issues were reused (one comment each); the others are new issues titled 'Language: <Name>: full deck format'. Japanese (#378) and Telugu (#419) are the closest to complete, not complete; the missing items are in their issues. English, the IPA course and English Braille have no tracker here (English is the base language; the IPA and Braille are #836 and #1143). Deck work is held. State is read from decks-live on 2026-11-13: units built are units with decks, and 'core files' excludes English layers.

| Language | Code | Issue | List | Priority | State |
|---|---|---|---|---|---|
| Bengali | bn | #1166 | first list (to B1) | deck priority 2 of the first list, culture priority 6 of 8 | path of 173 units, 172 built; 261 core files |
| Hindustani | hi | #1167 | first list (to B1) | deck priority 8 of the first list | path of 120 units, all built; 128 vocab and 34 grammar cores; audit and task plan in [Deck-Work-Queue-HI](Deck-Work-Queue-HI.md) (2026-11-15) |
| Assamese | as | #1168 | first list (to B1) | deck priority 6 of the first list, culture priority 7 of 8 | path of 173 units, 172 built; 250 core files |
| Bodo | brx | #1169 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Dogri | doi | #1170 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Gujarati | gu | #1171 | not on a numbered list; owner's culture-priority language (8th) | culture priority 8 of 8 | path of 117 units, 42 built; 60 core files |
| Kannada | kn | #1172 | first list (to B1) | deck priority 5 of the first list | path of 115 units, 114 built; 133 core files |
| Kashmiri | ks | #1173 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Konkani | kok | #1174 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Maithili | mai | #1175 | third list and others (first words only) | no ranked priority | path of 121 units, 1 built; 3 core files |
| Malayalam | ml | #355 | second list (to A1; Classical Sanskrit to B1) | second-list position 2 | path of 118 units, 1 built; 3 core files |
| Manipuri | mni | #1176 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Marathi | mr | #1177 | first list (to B1) | deck priority 4 of the first list, culture priority 5 of 8 | path of 116 units, 115 built; 136 core files |
| Nepali | ne | #353 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Odia | or | #352 | third list and others (first words only) | no ranked priority | path of 120 units, 1 built; 3 core files |
| Punjabi | pa | #351 | third list and others (first words only) | no ranked priority | path of 121 units, 1 built; 3 core files |
| Classical Sanskrit | sa | #356 | second list (Classical Sanskrit: to B1) | second-list position 9 | no path or decks yet (language entry only) |
| Santali | sat | #1178 | second list (to A1; Classical Sanskrit to B1) | second-list position 3 | no path or decks yet (language entry only) |
| Sindhi | sd | #1179 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Tamil | ta | #354 | second list (to A1; Classical Sanskrit to B1) | second-list position 1 | path of 115 units, 27 built; 45 core files |
| Telugu | te | #419 | first list (to B1) | deck priority 1 of the first list, culture priority 4 of 8 | path of 121 units, 120 built; 154 core files (closest to complete, not complete) |
| Bhojpuri | bho | #1180 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Tulu | tcy | #1181 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Rajasthani | raj | #1182 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Magahi | mag | #1183 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Chhattisgarhi | hne | #1184 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Awadhi | awa | #1185 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Haryanvi | bgc | #1186 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Kumaoni | kfy | #1187 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Garhwali | gbm | #1188 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Mizo | lus | #1189 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Khasi | kha | #1190 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Goan Konkani | gom | #1191 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| French | fr | #359 | first list (to B1) | deck priority 10 of the first list, culture priority 3 of 8 | path of 113 units, 77 built; 229 core files |
| Spanish | es | #1192 | first list (to B1) | deck priority 3 of the first list, culture priority 2 of 8 | path of 102 units, all built; 271 core files |
| German | de | #361 | second list (to A1; Classical Sanskrit to B1) | second-list position 7 | path of 111 units, 1 built; 3 core files |
| Mandarin Chinese | zh | #376 | first list (to B1) | deck priority 7 of the first list | path of 130 units, 129 built; 377 core files |
| Japanese | ja | #378 | first list (to B1) | deck priority 9 of the first list, culture priority 1 of 8 | path of 138 units, 95 built; 193 core files (closest to complete, not complete) |
| Korean | ko | #379 | second list (to A1; Classical Sanskrit to B1) | second-list position 4 | path of 136 units, 7 built; 16 core files |
| Esperanto | eo | #388 | third list and others (first words only) | no ranked priority | path of 112 units, 1 built; 3 core files |
| Toki Pona | tok | #1193 | 11th in the 2026-10-18 deck priority | no ranked priority | path of 46 units, 45 built; 152 core files |
| Lojban | jbo | #1194 | third list and others (first words only) | no ranked priority | path of 114 units, 1 built; 3 core files |
| Interslavic | isv | #1195 | third list and others (first words only) | no ranked priority | path of 113 units, 1 built; 3 core files |
| Portuguese | pt | #357 | third list and others (first words only) | no ranked priority | path of 87 units, 1 built; 3 core files |
| Italian | it | #358 | second list (to A1; Classical Sanskrit to B1) | second-list position 6 | path of 87 units, 1 built; 3 core files |
| Catalan | ca | #360 | third list and others (first words only) | no ranked priority | path of 88 units, 1 built; 3 core files |
| Swedish | sv | #362 | third list and others (first words only) | no ranked priority | path of 85 units, 1 built; 3 core files |
| Norwegian (Bokmål) | nb | #363 | third list and others (first words only) | no ranked priority | path of 85 units, 1 built; 3 core files |
| Yiddish | yi | #364 | third list and others (first words only) | no ranked priority | path of 86 units, 1 built; 3 core files |
| Russian | ru | #365 | second list (to A1; Classical Sanskrit to B1) | second-list position 8 | path of 88 units, 1 built; 3 core files |
| Polish | pl | #366 | second list (to A1; Classical Sanskrit to B1) | second-list position 11 | path of 87 units, 1 built; 3 core files |
| Serbo-Croatian | hbs | #367 | third list and others (first words only) | no ranked priority | path of 90 units, 1 built; 3 core files |
| Greek (Modern) | el | #368 | second list (to A1; Classical Sanskrit to B1) | second-list position 10 | path of 87 units, 1 built; 3 core files |
| Hebrew | he | #375 | third list and others (first words only) | no ranked priority | path of 90 units, 1 built; 3 core files |
| Finnish | fi | #370 | third list and others (first words only) | no ranked priority | path of 85 units, 1 built; 3 core files |
| Hungarian | hu | #371 | third list and others (first words only) | no ranked priority | path of 85 units, 1 built; 3 core files |
| Turkish | tr | #369 | third list and others (first words only) | no ranked priority | path of 84 units, 1 built; 3 core files |
| Basque | eu | #372 | third list and others (first words only) | no ranked priority | path of 83 units, 1 built; 3 core files |
| Irish | ga | #373 | third list and others (first words only) | no ranked priority | path of 85 units, 1 built; 3 core files |
| Arabic | ar | #374 | third list and others (first words only) | no ranked priority | path of 91 units, 1 built; 3 core files |
| Cantonese | yue | #377 | third list and others (first words only) | no ranked priority | path of 86 units, 1 built; 3 core files |
| Thai | th | #381 | third list and others (first words only) | no ranked priority | path of 86 units, 1 built; 3 core files |
| Vietnamese | vi | #380 | third list and others (first words only) | no ranked priority | path of 83 units, 1 built; 3 core files |
| Filipino | fil | #382 | third list and others (first words only) | no ranked priority | path of 81 units, 1 built; 3 core files |
| Malay | ms | #383 | third list and others (first words only) | no ranked priority | path of 82 units, 1 built; 3 core files |
| Afrikaans | af | #1196 | second list (to A1; Classical Sanskrit to B1) | second-list position 5 | no path or decks yet (language entry only) |
| Dutch | nl | #1197 | third list (first words only) | third-list position 4 | no path or decks yet (language entry only) |
| Ukrainian | uk | #1198 | third list (first words only) | third-list position 5 | no path or decks yet (language entry only) |
| Indonesian | id | #1199 | third list (first words only) | third-list position 1 | no path or decks yet (language entry only) |
| Persian | fa | #1200 | third list (first words only) | third-list position 2 | no path or decks yet (language entry only) |
| Pashto | ps | #1201 | third list (first words only) | third-list position 3 | no path or decks yet (language entry only) |
| Swahili | sw | #384 | third list and others (first words only) | no ranked priority | path of 84 units, 1 built; 3 core files |
| Hausa | ha | #385 | third list and others (first words only) | no ranked priority | path of 83 units, 1 built; 3 core files |
| Somali | so | #386 | third list and others (first words only) | no ranked priority | path of 82 units, 1 built; 3 core files |
| Quechua | qu | #387 | third list and others (first words only) | no ranked priority | path of 82 units, 1 built; 3 core files |
| Mycenaean Greek | gmy | #1202 | third list and others (first words only) | no ranked priority | 1 deck files, no path |
| Sumerian | sux | #1203 | third list and others (first words only) | no ranked priority | 1 deck files, no path |
| Egyptian | egy | #1204 | third list and others (first words only) | no ranked priority | 1 deck files, no path |
| Proto-Indo-European | ine | #1205 | third list and others (first words only) | no ranked priority | 1 deck files, no path |
| Vedic Sanskrit | vsn | #1206 | third list and others (first words only) | no ranked priority | path of 60 units, 1 built; 3 core files |
| Latin | la | #1207 | third list and others (first words only) | no ranked priority | path of 60 units, 1 built; 3 core files |
| Old English | ang | #1208 | third list and others (first words only) | no ranked priority | path of 59 units, 1 built; 3 core files |
| Middle English | enm | #1209 | third list and others (first words only) | no ranked priority | path of 57 units, 1 built; 3 core files |
| Classical Greek | grc | #1210 | third list and others (first words only) | no ranked priority | path of 63 units, 1 built; 3 core files |
| Archaic Greek | qgh | #1211 | third list and others (first words only) | no ranked priority | path of 60 units, 1 built; 3 core files |
| Koine Greek | qgk | #1212 | third list and others (first words only) | no ranked priority | path of 64 units, 1 built; 3 core files |
| Pali | pli | #1213 | third list and others (first words only) | no ranked priority | path of 61 units, 1 built; 3 core files |
| Aramaic (Imperial) | arc | #1214 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Ashokan Prakrit | qap | #1215 | third list and others (first words only) | no ranked priority | path of 61 units, 1 built; 3 core files |
| Indian Sign Language | ins | #592 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| American Sign Language | ase | #593 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Klingon | tlh | #587 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Sindarin | sjn | #588 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Quenya | qya | #589 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| Dothraki | qdo | #590 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
| High Valyrian | qhv | #591 | third list and others (first words only) | no ranked priority | no path or decks yet (language entry only) |
