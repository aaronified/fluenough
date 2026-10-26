# Plan: question engine revamp and milestone exams

Source of truth: this wiki page.

Written 2026-10-26, for **0.7.0** (owner, 2026-10-23: "This week is 0.6.x, next week is 0.7.x"). Builds on [Plan-Question-Engine](Plan-Question-Engine), whose approvals stand and are not repeated here; also [ADR-0022](ADR-0022-Romanised-Answers), [ADR-0034](ADR-0034-Hear-Say-Write), [ADR-0035](ADR-0035-Fsrs-Fitted-Per-Skill), [ADR-0039](ADR-0039-Questions-Derived-From-Card-Data), [Plan-Word-Order-Tiles](Plan-Word-Order-Tiles), [Plan-Sentence-Building](Plan-Sentence-Building), [Plan-Placement-V2](Plan-Placement-V2) and [Plan-B1-Plans](Plan-B1-Plans).

**Status:** the owner's decisions below are recorded. Everything marked **Proposed** or "(mine)" is the plan author's and not decided. No issues are filed yet.

## What the owner asked

Problem (owner, 2026-10-26): typed English meaning answers reject valid synonyms ("with mother" for "with mom") and rephrased sentences. The owner's idea: give the learner the letters instead of the system keyboard, QWERTY-shaped, full width like system keyboards, a budget number on each key, spent keys greyed, and a few extra letters.

> replace types with tiles till we can add llm (cannot be done next week)

> dictation must only be for script. otherwise no point.

> i agree on the other question types

> 5 questions each skill, and extra 2 each skill in case the algo needs it

> speaking or listening shouldnt gate, but in their absence, other skills need better testing. they will also be present, and graded if working.

And on the card UI (owner, 2026-10-26):

> the question cards will need to be merged better with the teach cards, they follow different UI now. this needs the revamp of questions and also another revamp of the teach cards before being taken up

## Decisions

| # | Decision | Owner's words / source |
|---|---|---|
| 1 | Typed English meaning answers become word tiles now (meanings and sentences), built on the rearrange machinery | "replace types with tiles till we can add llm" |
| 2 | A small English-only on-device LLM is a later step, for meaning answers only. Not in 0.7.0 | "cannot be done next week" |
| 3 | Romanised (transliteration) answers stay typed and unchanged | owner: "is already fine" (as relayed to the author, 2026-10-26); ADR-0022 |
| 4 | Script typing is retired for letter tiles ("rearranging letters only") where no model supports it | 2026-10-26 |
| 5 | Dictation is script only: hear, then build the script spelling from letter tiles | "dictation must only be for script" |
| 6 | Agreed: cloze (choice then tiles tiers, ADR-0034's tiers), dialogue reply, sentence transformation, odd one out and synonym/antonym sort, error spotting, passage items | "i agree on the other question types" |
| 7 | Reading passages stay exam-only (2026-10-13). Read here as: "longer passages in later sections" means exam items. **Assumption, to confirm** | #506, Plan-Question-Engine "Reading passages" |
| 8 | Milestone exam: 5 scored items per skill, plus 2 spare per skill | "5 questions each skill, and extra 2 each skill" |
| 9 | #509 answers stand: 80% overall, each skill at least 60%, required to continue, retake next day after the pushed reviews, offered-not-blocking for learners already past | Plan-Question-Engine, answers 2 to 6 |
| 10 | Speaking and listening items are present and graded where the device supports them, but never gate; without them the gating skills are tested harder | 2026-10-26 |
| 11 | Teach cards and question cards merge into one card UI. The teach cards are revamped too, and this lands first | 2026-10-26 (quote above) |

Per-skill 60% of 5 scored items means 3 of 5.

## What exists (verified against the code, 2026-10-26)

- **Grader** (`lib/core/grading/answer_grader.dart`): exact after normalisation, then diacritics folded with a leading article dropped, then edit distance (1, or 2 from 8 letters; none under 3 letters). `meaning: true` adds `meaning_rules.dart`: case and punctuation, contractions, bracketed qualifiers optional, `;` alternatives, a leading "to", ok/okay, "please" optional. Its header says what no rule does: paraphrase, which needs an `altNative`. There is **no synonym pass**.
- Alternatives are author-listed: `Card.altNative` and `altTarget` (`lib/core/models/card.dart`).
- `DrillSession.check` builds the grader with `meaning: hearsMeaning && _meaningIsEnglish`, so the rules apply only to English meaning answers.
- **Registry** (`lib/core/scheduling/question_type.dart`): seven types today, `chooseMeaning`, `matchPairs`, `rearrange`, `chooseWord`, `hearMeaning`, `chooseFormMeaning`, `chooseForm`. Typed production, typed listening and speaking are `Ask.own`, claimed by no type. No cloze, dialogue, transformation, odd-one-out or error-spotting type exists.
- **Rearrange** tiles are lowercase words with each mark a tile of its own (`tilesOf`, `Card.tilesOfSpelling`, #347).
- **Extra tiles** (`extra_tiles`) are only in Plan-Word-Order-Tiles; the field is in no code, tool or doc outside that plan (searched `lib`, `tools`, `docs`, `wiki`). Not built.
- **Exams:** reading questions are exam items by decision, but 9b of the engine plan ("reading questions as exam items") is not built; no exam screen exists.
- **Card UI today** (`lib/features/drill/`, `lib/ui/widgets/drill_frame.dart`):

| | Teach (`teach_drill.dart`, `teach_card.dart`, `rule_card.dart`) | Question drills (`typed_drill.dart`, `choice_drill.dart`, `rearrange_drill.dart` and others) | Set (`set_drill.dart`) |
|---|---|---|---|
| Frame | `Scaffold` with `DrillHeader` alone, the card filling the screen with no body to scroll | `DrillFrame`: header, scrolling body with skill pill and deck name, a 40 px `surfaceContainerHigh` card panel, `belowCard`, fixed foot | `DrillFrame` |
| Going on | swipe or two chevrons (`TeachSwipe`), no Continue button | action buttons in the foot | a Continue button in the foot |
| Feedback | none, nothing is recorded | `AnswerFeedback` above the actions | none |
| Content | the word, reading, speaker, IPA, picture, meaning, one note, one warning (#691) | the prompt, an answer area | the set's members as rows |

  So the header is shared and the shell, the going-on gesture, the feedback and the grading area are not.
- **Mockups:** the teach card mockup (#691) was built and removed (`docs/mockups/today-chain.md` names it "now built and removed"; commit 6749c53a is the build). No teach or question mockup is in `docs/mockups/` today.
- **Not found in the code:** a test that distractors never include an accepted answer. `test/distractors_test.dart` tests ranking and pool size only. I did not find the exclusion in `distractors.dart` either (unverified: it may sit in `DrillSession`).

## Phase 0: one card UI for teach and question

**Needs a mockup first** (`docs/mockups/README.md`: real theme, light and dark, 1.4x, Hindi and Bengali examples, self-checks and notes in a Markdown file of the same name). Owner approval before any code.

Revamp the teach cards (`teach_drill.dart`, `set_drill.dart`, `teach_card.dart`, `rule_card.dart`) and the question drills so they share one card shell, one header, one feedback area and one grading area. **Proposed** scope, to settle in the mockup: a teach card becomes a card with no answer area and no grade; a question card is the same shell with its answer area; going on is one gesture or one button across both.

**Dependency (CLAUDE.md, "Dependencies are marked").** Phase 0 gates steps 2 to 9 below. When the issues are filed: each of those is **blocked by** the phase 0 issue, with the `blocked` label, and no one relies on both landing in 0.7.0. Letter tiles, word tiles, cloze and the exam screen are built on the shared shell, never on today's two.

## The ladder

Choose, then tiles, then typed. This is the already-approved ability rule (Plan-Question-Engine, approval 7) applied to the new rungs; typing remains only for romanised answers, with word and letter tiles as the middle rung. (Author's inference.)

| Rung | Meaning answers | Script answers | Romanised answers |
|---|---|---|---|
| Easy | choose | choose | choose |
| Middle | word tiles | letter tiles | n/a |
| Hard | LATER step: free typing assisted by a model (see Still open) | none: letter tiles stay | typed, as today |

## Letter tiles

- **Latin and Cyrillic:** a QWERTY-shaped tray at the full width of a system keyboard, a count badge on each key (the number of times the answer needs it, the owner's "budget"), spent keys greyed, a few extra letters. Accent keys for Spanish (á é í ó ú ñ ü). (Author's design from the owner's idea.)
- **Indic scripts:** a tray of only the answer's pieces plus decoys, not a full keyboard. Whether a piece is a code point or an akshara (consonant plus vowel sign, conjuncts) is **decided by a mockup**, not here.
- Check at 1.4x text and for tap targets (48 dp) before approval; a full-width QWERTY at 360 dp is about 36 dp a key, which is below that (author's arithmetic, to check in the mockup).
- Grading is by the tiles placed, as rearrange does today.

## Word tiles for meanings

- The English meaning or sentence is built from word tiles on the rearrange machinery (`tilesOf`, `DrillSession` tile checks). Tiles are lowercase without edge marks, as #347 decided.
- **Tray rule (author's):** a tray never contains a word that is an accepted alternative of another tray word, and grading accepts any accepted meaning (`meaningKeys` over `Card.meanings` and `altNative`). Reuse the idea of "distractors never include an accepted answer"; that test is **not in the repo today** (see above).
- Duolingo precedent (indicative, company blog): the word bank shows one translation, and a keyboard toggle was added later. <https://blog.duolingo.com/improving-how-duolingo-teaches-chinese-and-other-languages> and <https://blog.duolingo.com/how-machine-learning-helps-duolingo-prioritize-course-improvements>.
- Tiles remove the synonym problem for gating only if the tray is curated; a learner who knows "mom" finds no "mom" tile and is not wrong, but is constrained. Measure first (step 1).

## Dictation (script only)

Hear the word, then build the script spelling from letter tiles. Only where what is heard is the form (`Card.hearsForm`, Plan-Question-Engine step 7). Meaning is not dictated; Hear of a word's meaning stays a choice (ADR-0034).

## New question types

All are registry entries (ADR-0039): eligible by card data, graded as a choice or by tiles.

| Type | Tiers | Needs | Blocked by |
|---|---|---|---|
| Cloze | choice, then tiles (ADR-0034's tiers) | an example, or a card's own text of 2+ words | `examples` are 0 on hi, bn, te (Plan-Question-Engine, "Filling the decks") |
| Dialogue reply | choice | a short exchange: prompt and reply pairs | new deck key; no data anywhere today |
| Sentence transformation | tiles | paired sentences (tense, number, voice) | new deck key; Plan-Sentence-Building's bank |
| Odd one out; synonym/antonym sort | choice, sort | `synonyms`, `antonyms`, word family | synonym and antonym fields (card data step 1c); unverified how many cards have them |
| Error spotting | choice | a sentence with one planted error, and its fix | new deck key; related to `confusables` for sentences |
| Passage items | choice | `reading_passages` | exam screen; exam-only |

Every new deck key follows the two-release rule (released apps reject unknown keys): the code ships in release N, the decks' keys one release later.

**Data target per language (Proposed, mine):** at least 2 examples on every card from A1 up; 300 cloze-ready sentences; 100 dialogue pairs and 100 error-spotting items per milestone. The numbers are my starting point, not the owner's.

## Milestone exams

| Item | Proposed unless marked |
|---|---|
| Items | 5 scored plus 2 spare per skill (owner) |
| Skills | recognition, Hear (listening), Say (speaking), Write (production), grammar; 7 per skill is one draw (author's reading of ADR-0034's skills) |
| Bank | a retake must not repeat, so about 14 per skill per milestone (7 per draw, two draws). Seeded draw without repeats |
| Grading | no free typing: choice, tiles, sort, passage choice. Romanised typing is not used in exams either, so no exam relies on a grader pass or a model |
| Speaking and listening | present and graded where the device supports them (owner); never gate (owner); where absent, the gating skills carry more weight (owner), how much is open, below |
| Pass | 80% overall and at least 60% per skill (#509); 3 of 5 per skill |
| Where | on the unit the path marks `milestone: A1`, `A2`, `B1` (Plan-B1-Plans); the units after it stay locked until it is passed (#509) |
| On a fail | the result names the missed units and words; they are pushed into review; the retake opens the next day after those reviews (#509) |
| Answers | move the words' FSRS schedules like practice (#509) |
| Already past | offered, not blocking (#509) |

Screens needing mockups (after phase 0): exam start, an exam item of each kind, the result with weak units, the locked state on the path, the retake wait.

Assumption to confirm: placement (#481) shares the item types but is not this plan.

## Steps

Each is one pull request. Mockup first for any screen (`docs/mockups/README.md`). Tests are in CI only. The LLM is listed, not scheduled.

| # | Step | Tests that check behaviour |
|---|---|---|
| 0 | Mockup then build: one card UI for teach and question (phase 0) | a teach card and a question card render in the same shell at 1.4x; going on works by the same gesture; a teach card records nothing |
| 1 | Measure: count rejected typed meaning answers from in-app reports (ADR-0021) | none; the count decides the tray's size |
| 2 | Word tiles for meanings, with the tray rule | a tray holds no accepted alternative of another tray word; any accepted meaning is right; a wrong word is wrong |
| 3 | Letter tiles, Latin and Cyrillic | a spent key cannot be tapped; the count matches the answer; an accented answer needs the accent key |
| 4 | Letter tiles, Indic, after the mockup picks the piece | the pieces rejoin to the answer; decoys never rejoin to it |
| 5 | Dictation as letter tiles, script only | only `hearsForm` cards are dictated; a meaning is never dictated |
| 6 | Cloze, choice then tiles | eligible only with an example or a text of 2+ words; the tier steps up with stability and back one on a miss |
| 7 | Dialogue reply, transformation, odd one out and sort, error spotting | each is eligible only with its data and never returned for a card without it |
| 8 | Exam item bank, draw and grading | the draw never repeats an item across retakes; 7 per skill; the same seed gives the same draw |
| 9 | Exam screen, gate, fail and retake | pass is 80% overall and 3 of 5 per skill; speaking and listening never fail an otherwise passing exam; a fail pushes units to review and opens the retake next day; a learner past the milestone is not blocked |
| Later | An English-only on-device model as an advisory step for meaning answers | not scheduled |

## Tests to add

Those in the Steps table, plus: reading questions are never returned by the review registry (exists in the engine plan's list); an exam answer moves the word's schedule; the log replays to the same schedule after each step.

## Estimate (mine, not the owner's)

Phase 0: 12 to 20 hours with its mockup. Word tiles 6 to 8. Letter tiles 12 to 16 with the Indic mockup. Dictation 4. Four new types 20 to 30 as code, plus data per language (examples alone were estimated at 40 hours per language in the engine plan). Exams 16 to 24. Total about 70 to 100 hours of code before data, and more than one week of one coder.

## Still open

1. **Is the teach revamp one plan or part of this one?** (owner not yet decided)
   - Part of this plan: one set of steps and one mockup; the main downside is that this plan then waits on a screen redesign before anything ships.
   - Its own plan: this plan's blocked-by is clearer and the teach work can be reviewed alone; the main downside is two plans edit the same files and the shell is designed twice.
2. **The LLM's fit.** Embedding similarity rates "with mother" and "with father" alike, so any model must be an NLI or judge-style advisory step, never the sole gate, and never in an exam (author's inference). Options: advisory only (a wrong answer is offered for self-judgment as near misses are today; downside: learners may always accept); grades alone (downside: wrong in either direction). Not for 0.7.0.
3. **How much stronger the gating skills are tested when speaking and listening are absent.** Not decided. Options: draw the 2 spares into the scored set (7 scored; downside: no spare when the algorithm needs one, and a retake bank is no larger); raise to 7 scored plus 2 spare (downside: a longer exam and a bank of about 18 per skill); add harder item types (downside: depends on data most languages lack); keep it as is (downside: a learner with no microphone is tested on less).
4. **Slot for this plan's coding.** 0.7.0 also holds the Today chain, focus tracks and cheatsheets. The owner's slots are one Haiku and one Sonnet on decks and reviews, and one Sonnet on the Today chain. Options: take the Today Sonnet after the chain; add a third Sonnet (downside: the rule allows at most two Sonnet at a time); defer some steps to 0.8.0 (downside: the exam gate slips).
5. **Tray size for word tiles.** After step 1's count. Options: the accepted answers plus 2 to 3 decoys; the full accepted set (downside: easier).
6. **Piece granularity for Indic letter tiles.** Code point or akshara; downside of code points is exposing vowel signs alone, of aksharas a larger tray.
7. **Is "longer passages in later sections" an exam item?** Read so here (decision 7); confirm.
8. **Per-language data target.** The numbers above are mine; downside of too high is the plan waits on content.
9. **Exam length in minutes.** About 25 to 35 items depending on skills present; unmeasured.

## Not in this plan

- The on-device model (later step, above).
- Changes to romanised answer grading (ADR-0022).
- New deck content, except the data targets above.
- Placement (Plan-Placement-V2), speaking and listening engines.
- Opening GitHub issues.

See also: [Plan-Question-Engine](Plan-Question-Engine) · [Plans-Index](Plans-Index) · [Roadmap](Roadmap) · [Home](Home)
