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

State is for Japanese (`ja`), read from `origin/decks-live` and `origin/main` on 2026-11-13. "Done" means the files are on decks-live. Counts are of files, not of quality or coverage.

| # | Deliverable | Specified in | State for `ja` |
|---|---|---|---|
| 1 | Path to B1 (`<code>-path.yaml`, units, regions, alphabet, grammar) | [Deck-Format](Deck-Format.md) "Paths", "Writing a B1 course" | Partial. `decks/ja/ja-path.yaml` exists with about 138 units. Built units against planned units: not audited. Main has 40 `decks/ja` files (frozen); decks-live has 442 |
| 2 | Cores and English layers (vocab and grammar) | Deck-Format "Core and layer files" | Partial: 190 non-layer files in `decks/ja/` on decks-live, each with a layer in `decks/ja/en/`. Gaps against the path: not audited |
| 3 | Sentences decks | Deck-Format "Vocab decks" | Partial: most word units have a `-sentences` file; sentence and reading decks for units 17 to 36 were still owed on 2026-11-02, not re-checked |
| 4 | Reading decks | Deck-Format "Reading decks" | Partial: six `ja-en-reading-*` files at the top of `decks/ja/`. Not audited further |
| 5 | Script decks (hiragana, katakana, marks, combos, basic kanji) | Deck-Format "Japanese kanji"; issue #1146 | Partial: hiragana, katakana, their combos and marks, and `ja-kanji-1` are done. Basic kanji only; about 1000 kanji by B1 is deferred (#1146) |
| 6 | Phrasebook | Deck-Format "The phrasebook" | Done: `ja-phrasebook` with its layer |
| 7 | Situations (one file per language, only widely used words and phrases, no over-translation) | Issue #1145; `lib/core/data/situations_parser.dart`; CLAUDE.md "Situations" | None for `ja`. Only `decks/te/te-situations.yaml` exists, on decks-live. Japanese sheets (#1124, draft) no longer wait for 0.10.0 (released, owner 2026-11-13), then their own PR |
| 8 | Topics, including script topics (`<code>-topics.yaml`, scripts are topics) | D6 | Built, not merged: `decks/ja/ja-topics.yaml` on branch `decks/ja-culture-1` |
| 9 | Culture decks (`genre: culture`) | D1, D4; Plan-Culture-Japanese | Built, not merged: `ja-culture-1` with 18 items, branch `decks/ja-culture-1` (one commit, 2026-11-13) |
| 10 | Creators, eras and legacy | D5, D5b, D5c | Built, not merged: `decks/creators/ja.yaml` (16 creators, 7 eras, no images) on the same branch |
| 11 | Proverbs (`genre: proverbs`, `basis: oral-tradition`) | D1, D4, #1135 | None. Named in Plan-Culture-Japanese as batch 2 |
| 12 | Multi-word verbs (`genre: multiword`) | D1, #1136 | None |
| 13 | Professional situations (`genre: professional`, hidden) | D1, D3, D8, #1139 | None. `professions: []` in `decks/sections.yaml` |
| 14 | Recommendations, public-domain and source-it-yourself, with quiz questions | D13, this page | None. `decks/recommendations/ja.yaml` is named in Plan-Culture-Japanese as a later file. The source-it-yourself mode is new (below) |
| 15 | Narrow IPA (`phonetic`) and a broad `ipa` on every card | [Plan-Ipa-Revamp-And-Language-Phonology](Plan-Ipa-Revamp-And-Language-Phonology.md) | Not done: no `phonetic:` key in any `decks/ja` file on decks-live. Broad `ipa` coverage: not audited. Written by the plan's tools, never by hand |
| 16 | Review-queue entries for everything uncertain | [Plan-Reviewing-Scope](Plan-Reviewing-Scope.md); `decks/review-queue.json` (generated on decks-live) | Partial: `docs/review-queue/ja.md` on the culture branch (21 lines). Queue for the rest: not audited |
| 17 | Sourcing list (the works, rights basis and checks) | Plan-Culture-Japanese; [Sources-and-Attributions](Sources-and-Attributions.md) | Batch 1 done in Plan-Culture-Japanese (18 items, candidates for next batches). None for proverbs, multi-word verbs or recommendations |
| 18 | Facts file (path facts, issue-held) | Deck-Format "Writing a B1 course" | Not audited |

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
| Path to B1 | partial | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Cores and layers | partial | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Sentences, readings | partial | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Script decks | partial (basic kanji only) | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Phrasebook | done | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Situations | none | not audited | not audited | file exists (`te-situations`), coverage not audited | not audited | not audited | not audited | not audited |
| Topics incl. script topics | on branch | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Culture, creators, legacy | on branch | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Proverbs | none | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Multi-word verbs | none | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Professional | none | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Recommendations, source-it-yourself | none | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Narrow IPA | none | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Review-queue entries | partial | not audited | not audited | not audited | not audited | not audited | not audited | not audited |
| Sourcing list | batch 1 | not audited | not audited | not audited | not audited | not audited | not audited | not audited |

Counts on decks-live of all files under `decks/<code>/`, layers included, for orientation only (2026-11-13): ja 442, es 442, fr 380, te 302, mr 266, bn 465, as 436, gu 115. A file count says nothing about coverage.

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
