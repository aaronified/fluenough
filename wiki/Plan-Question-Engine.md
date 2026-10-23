# Plan: the question engine, derived from card data

Source of truth: this wiki page.


Written 2026-10-13. Decision: ADR-0039. The card data it asks for is
in `docs/DECK-FORMAT.md`, "Card data" and "Set cards" (folded in from the
card data plan, 2026-10-13, #506).

**Status:** the owner answered the six open questions one by one on
2026-10-13 (recorded under "Decisions") and approved the drafts the same
day (#506): the ability rule as proposed, and reading passages moved to
exams (see "Reading passages"). ADR-0039 is Accepted.

## Decisions (owner, 2026-10-13, #506)

| # | Question | Answer |
|---|---|---|
| 1 | `modes` to an opt-out | "A script converts, then a review" |
| 2 | A type with little data in a language | "Ask it where the data exists" |
| 3 | Different types for the same card and skill | "Yes, picked by ability" |
| 4 | Reading passages | replaced: exam-only, see Reading passages below |
| 5 | Build order | "Fields first" |

The wrong-alternatives question (old 1) was decided with the card data
(DECK-FORMAT, "Card data"):
one shared `confusables` list, generated from card data when a card has none.

The owner also decided on set cards (2026-10-13, #506, recorded in
`docs/DECK-FORMAT.md`, "Set cards"): "Teach only"; "Every closed group"; "Show the
whole set; drill only new ones". See "Set cards" below.

Only the quotations above, the approvals below and the exam answers
(#509) are decided. The step list is **Proposed**, derived from the owner's
words, and is marked where it could pass for a decision.

Approvals (owner, 2026-10-13, #506): "[Approval 7, question types picked by
ability: easy to hard per skill, harder as stability grows, a miss steps back
one, the pick seeded per card and day:] This is approved as proposed." The
owner also changed approval 6 (reading passages scheduled as a whole); see
"Reading passages".

## What the owner asked

> validator is the test. deck-format is the guide. b1-format-spec is to
> be folded into deck-format

(#506, 2026-10-13). On questions, in the same issue: "a simple card should
be able to generate all kinds of questions", so a question must not depend
on the type of the card. And on the data: "not just example sentences. we
need also synonyms, antonyms, root word, meaning, minimal pairs, phonemic
contrasts, facts, images, etc on each card, as applicable. some would be
mandatory, others will be optional. create a list and plan this first."

## Where a question depends on the card's type today

| # | Where | What it does |
|---|---|---|
| 1 | `lib/core/scheduling/ask.dart:31-103` | `chooseForm` and `chooseFormMeaning` exist only when `card.rule != null` |
| 2 | `lib/core/scheduling/lesson.dart:71-107` | `lessonQuestions` is a switch on the card's kind; `Difficulty.of` reads `pos == phrase` |
| 3 | `lib/core/models/card.dart:328-368` | rearrange is allowed by three words or more, or by `pos == phrase` |
| 4 | `docs/DECK-FORMAT.md:490`, `pattern_expander.dart:52`, `rule_expander.dart:57-59` | `modes` is set by the author and by the expanders, and doubles as the marker of the kind |
| 5 | `reading.dart`, `drill_page.dart:290-345` | a reading question is a `QuestionCard` subclass with its own mode and page, scheduled like a card today; it moves to exams (see Reading passages) |
| 6 | `number_practice.dart:14-40`, `app_state.dart:1596` | `NumberCard` is special-cased |
| 7 | `app_state.dart:1557-1565`, `1693-1697` | Hear asks for the form or the meaning by whether the deck is in the path's alphabet list |
| 8 | `app_state.dart:1588-1610` | the wrong options are drawn by kind and class |
| 9 | `ask.dart:122-185` | `reviewAsks` is a table from `DrillMode` to `Ask` |
| 10 | `docs/DECK-FORMAT.md:849-861` | `pattern.prompt` is a question the author wrote |

Already independent of the card's type: `chooseMeaning`, `chooseWord`,
`hearAndChoose`, `matchPairs`, typed Write and Hear, and speaking.

## The target

One registry (ADR-0039). A `QuestionType` has a skill (a `DrillMode`),
`eligible(card)`, a grader, and a distractor source. The engine, given a
card and a skill, lists the eligible types and picks one. Nothing else
chooses.

Plain Dart in `lib/core`, no Flutter. The pages draw an `Ask`; they do not
decide which.

## Steps (approved order, owner, 2026-10-18: "approve the #522 step order")

Each step is one pull request or push to main, and every step ends with
`flutter analyze` clean and the full `flutter test` passing. A step moves
code and adds a test that the old and the new choose the same question for
every card in the shipped decks, then deletes the old.

1. **Pin today's behaviour.** A test that records, for every card in the
   decks and every skill, which `Ask` is chosen now. No code changes. It is
   the safety net for every step after. It reads a frozen copy of the decks
   kept under `test/fixtures/ask_pin/` (te, es and ipa, whole), so that it
   fails only when code changes the asks, never when a deck changes, and a
   deck-only pull request cannot turn main red (#524). Owner, 2026-10-17,
   asked "What should it read?": "Frozen deck copy". Refresh it, with the
   golden, only for an intended change:
   `python3 tools/snapshot_ask_pin.py`, then `UPDATE_ASK_PIN=1 flutter test
   test/core/scheduling/ask_pin_test.dart`; never in a deck pull request.
   `test/features/decks/decks_page_test.dart` reads the same copy for
   Telugu's path numbers (#567), so a refresh updates those too.
2. **The registry, with the agnostic types.** Add `QuestionType` and move
   `chooseMeaning`, `chooseWord`, `hearAndChoose`, `matchPairs`, typed
   production and listening, and speaking into it. `reviewAsks` (#9) asks
   the registry. Same output as step 1.
   **Built (#522):** `lib/core/scheduling/question_type.dart` holds `QuestionType`,
   `QuestionContext` and the ordered `questionTypes`; `reviewAsks` asks
   `questionTypeFor`. The two grammar types moved in with their current
   eligibility, which step 4 changes. Typed production and listening, and
   speaking, are what no type claims, so they stay `Ask.own`.
3. **Distractor sources by data (#8).** Replace the pool by kind and class
   with sources named by data: same `pos`, same theme or tags, `pair`,
   `bases`. Where a pool is too small, fall back as today. The test checks
   no pool gets smaller for a shipped card.
   **Built (#522):** `lib/core/scheduling/distractors.dart` ranks a pool by
   what its cards share with the answer, read from data: its word family
   (`bases`), `pos`, then tags. A choice question takes its wrong options
   from the best rank first, at random within a rank (`DrillSession`). The
   pool's membership is unchanged (it is still the deck's cards, then the
   course's, as `choicePool` builds it), so no pool gets smaller and every
   ask stays as pinned; the ranking only changes which of the pool is shown.
   `pair` still leads in Hear, and the card's own `confusables` still come
   before the pool.
4. **Grammar by data (#1, #2).** `chooseForm` and `chooseFormMeaning` become
   types whose `eligible` is "the card has other forms of its word"
   (`bases` or the rule row), not `rule != null`. `lessonQuestions` for a
   rules cell comes from the registry.
   **Built (#522):** `chooseFormMeaning` is eligible when another form of
   the word means something else (`Card.choosesMeaning`) and `chooseForm`
   when the word has other forms (`Card.hasOtherForms`), not when the card
   is a rules cell; `lessonQuestions` asks the registry
   (`grammarLessonQuestions`) for a rules cell. Same questions as pinned.
   **Forms named by `bases`** (owner, 2026-10-23, asked what a base-word
   card's other forms are: "Sibling cards"): the other cards whose `bases`
   ref the same base card, with a different target (`formSiblings`), supply
   the wrong options (`formChoices`) and make the types eligible; a card
   with no sibling stays ineligible. The review gets them through
   `reviewAsks(siblingsOf:)`. A card still reaches a grammar skill only by
   its `modes` (step 6 changes that), and `grammarUnderstood` is still
   refused by the parser on a card that is not a rules cell, so no shipped
   card gains a form question yet. A lesson does not read siblings yet
   (step 8).
   **Narrowed to "Same single base"** (owner, 2026-10-23: "Two cards are
   siblings only when each has exactly one base and that base is the same
   card."): measured on the shipped decks, the literal rule caught about 600
   multi-word sentences that share any word. `formSiblings` now requires
   exactly one base on each card, the same card.
5. **Rearrange by data (#3).** `eligible` is "the target has three or more
   tokens", whatever `pos` is. A two-word phrase stays eligible so that the
   1,098 cards keep it (word-order-tiles.md).
6. **`modes` as an opt-out (#4).** Read `modes` as "excluded from". The
   expanders stop writing it as a marker. A card with no `modes` is asked
   every skill its data allows. The validator reports any `modes` that
   excludes every skill. **A script converts the existing `modes`, then a
   review reads the result** (owner: "A script converts, then a review"):
   the script lists every deck it changed and each card whose `modes`
   changed meaning, and a reviewer checks that list. Card ids and meanings
   do not change.
7. **Hear form or meaning by the card (#7).** Whether the heard form is
   typed is a property of the card's data (a letter, a digit, a number),
   not of the deck's presence on the path. Script practice stays as it
   is, found by the card.
8. **Lessons from the registry (#2).** `lessonQuestions` and `Difficulty`
   read the registry and the card's data; the switch on kind is deleted.
9. **Numbers as cards, reading as exam items (#5, #6).** `NumberCard`
   becomes a card with data, asked through the registry. Reading questions
   leave review: they are exam items, drawn by the exam screen (see
   Reading passages). The reading page stays, for exams.
10. **Retire `pattern.prompt` (#10).** A pattern's cards are asked by the
    types their data allows. The field is read for old decks and flagged
    by the validator, and removed from DECK-FORMAT.md in the same step.

## Build order: fields first

The owner's order (2026-10-13: "Fields first"): the format and validator for
the new card data (`docs/DECK-FORMAT.md`, "Card data"; see "Filling the
decks" below) land first, so filling the decks can start. The engine,
steps 1 to 10, comes after.
Step 1 (pinning today's behaviour) can be done at any time, as it changes no
code.

## Filling the decks

From the card data plan, kept here because it is still to build. Only the
language order is the owner's (2026-10-13: "Hindi, Bengali, Telugu, then
path order"); the rest is **Proposed**.

1. **Format and validator,** one change per field family: (a) confusables,
   (b) examples (at least 2) and gender classes per language, (c) synonyms
   and antonyms, (d) register, forms, frequency, collocations, senses, facts
   links. The relicensing change set (DECK-FORMAT, "Licensing deck content")
   goes before any Wiktionary or Tatoeba data. Each change lands with its
   DECK-FORMAT entry and tests.
2. **One issue per language:** Hindi, Bengali, Telugu, then the rest in the
   path order (`docs/ROADMAP.md`), each "blocked by" the previous one and by
   the format issues, with the `blocked` label, and `direct-code` once its
   questions are answered.
3. **Per language:** examples (the largest gap, needed by cloze and
   listening); confusables for sentences (word order, #329); `gender` and
   `pos`; `bases` to the B1 rule; pair notes; synonyms and antonyms; the
   optional rest.
4. Agents write the content in the layers' own languages, validated and
   marked `unreviewed`. Reviewers are bilingual and never change a card's
   meaning (`reviewing-scope.md`). Card ids are permanent.

Coverage when this was written: reading and IPA about 99% for hi, bn, te;
`gender` 20% hi, 0 bn and te; `bases` 17-28%; examples 0.
Estimate (mine, not the owner's): format, validator and tests 8-12 hours;
examples 40 hours per language (about 1,100 cards); confusables for
sentences 8-16; other fields 6-10.

## Choosing a type: coverage and ability

- **Coverage** (owner: "Ask it where the data exists"). A type is asked for a
  card whenever the card has its data, whatever share of the language's
  cards that is. There is no coverage floor and no silence per language.
  A type whose data is rare simply appears rarely.
- **Ability** (owner: "Yes, picked by ability"). **Rule approved** (owner,
  2026-10-13, approval 7: "This is approved as proposed"): the same card and
  skill may be asked as different types, easy to hard per skill, harder as
  stability grows, a miss stepping back one, the pick seeded per card and
  day. While a card is new or failing, the easier
  types are picked (choice before typing); as it becomes stable, the
  harder ones. All types of a skill grade the same skill schedule
  (ADR-0034's grades stay), so the schedule does not fork. The pick uses
  the card's stability and the learner's skill rating, with a seeded
  choice among the types of the right difficulty so that it is repeatable.

## Set cards

Owner, 2026-10-13 (#506): the set card is "Teach only"; every closed group
needs one; "Show the whole set; drill only new ones". How it meets the engine
(the mechanism is **Proposed**; the three behaviours are the owner's):

- A set card is **taught, never scheduled or asked.** It has no log key, no
  schedule entry and no question type is eligible for it. It is shown once,
  in its lesson, as the introduction.
- The **lesson builder shows it before its members** and marks the members
  already taught. It drills only the members not yet taught, and adds a known
  member only as review if it is due. This is part of step 8 (lessons from
  the registry) and needs no new question type.
- Its members are ordinary cards, asked by the types their own data allows.

## Reading passages

Owner, 2026-10-13, on #506:

> All passages are part of "exams", for placements and for milestones. User
> can retake them, but not via review.

And on exams, filed as #509 (answers asked one by one, 2026-10-13):

1. **Do exam answers move the words' FSRS schedules?** "Yes, like any
   practice".
2. **When is a milestone exam taken?** "Required to continue". The units
   after a milestone stay locked until its exam is passed.
3. **On a fail:** "Review the weak units, then retake". The result names the
   units and words that were missed, and those are pushed into review.
4. **Pass mark:** "80% overall, each skill at least 60%".
5. **Retake wait:** "Next day, after the pushed reviews".
6. **Learners already past a milestone when this ships:** "Offered, not
   blocking". Only milestones reached after the update block.

So **reading passages are not reviewed and not scheduled.** They appear only
in exams: placement (#481) and the B1 plan's milestones (#509). A learner
can retake an exam, but a passage never comes back through review. This
replaces the earlier answer 4 and the "scheduled as a whole" design.

What this means for the engine (derived from those answers; the owner
decided the answers, the wording of the mechanism is mine):

- **A reading question is an exam item, not a review question.** It has no
  review `Ask`, no log key of its own in review and no schedule entry. The
  registry's review types never return one. The reading page and the
  passage data (`reading_passages`, in DECK-FORMAT) are drawn by the exam
  screen.
- **Exam answers move FSRS like any practice** (answer 1): an exam answer on
  a word is logged against that word's skills, so its schedule moves as if
  the learner had practised it. The passage itself has nothing to schedule.
- **Pass** is 80% overall and at least 60% in each skill (answer 4).
- **A milestone exam is required to continue** (answer 2): the units after
  the milestone stay locked until it is passed. Learners already past a
  milestone when it ships are offered the exam, and are not blocked (answer
  6).
- **On a fail** the result names the units and words that were missed, and
  they are pushed into review (answer 3). **The retake opens the next day,
  after those reviews** (answer 5).
- What an exam holds besides passages, its screens and its place in the
  `<lang>-path.yaml` milestones are still to plan (#509).

## Tests to add

- Step 1's table, kept as a golden file.
- For each type: `eligible` true and false on small fixed cards; grading;
  that distractors come from the named source and never include the
  answer, or an accepted answer.
- A property test: for every shipped card and every skill that has any
  eligible type, exactly one is chosen, and it is the same on every run
  with the same seed.
- A test that `lib/core` imports no Flutter (exists; keep it).
- A log replay test: an old review log replays to the same schedule after
  each step.
- For ability: a new or failing card gets an easier type than a stable one,
  with the same seed; all types of a skill update the same schedule.
- For exams: reading questions are never returned by the review registry;
  an exam answer moves the word's schedule like practice; pass needs 80%
  overall and 60% in every skill; a fail pushes the missed units to review
  and opens the retake the next day.

## What each step makes possible

| After step | Possible |
|---|---|
| 2 | a new type is one entry; audio drills (#325-326) and the IPA course sounds (#335-337) that need no new card data |
| 3 | listening in context options (#342-344) and word-order extras (#348-349), once their wrong alternatives are decided in the card data list; known mistakes (#329-330) |
| 4 | cloze (#321) and the sentence bank (#318-320), which need a card with a sentence |
| 5 | word-order tiles for any sentence-like card |
| 6 | cards without an author's `modes`; placement v2 (#481) over all skills |
| 7 | the same word asked in Hear in any deck |
| 8 | match rows and sort (#93) as types over any group of cards |
| 9, 10 | handwriting (#331-334) and the explain-mistakes questions on any card |

Cloze, sentence bank and listening in context also need data most cards do
not have yet: examples are 0 on hi, bn and te. They arrive as the data is
filled, not as code.

## Card data still open

The questions about card data are listed in `docs/DECK-FORMAT.md`, "Card data
still open" and "Set cards". Also **Proposed** and about questions: what a
question type needs from each data item (a type is eligible when its card has
the data; it is asked for any card that has it):

| Question | Needs |
|---|---|
| chooseMeaning, Hear, matchPairs, Write, Say | meaning, target |
| chooseWord, chooseForm distractors | confusables, else generated from card data |
| cloze | an example, or the card's own text with 2+ words |
| word order | 3+ words, 2-3 tile confusables |
| listening in context | an example, and confusables with a meaning |
| explain a wrong answer | confusables with `why`, rule ids, else cell siblings |
| sounds of this word | `ipa`, the sounds file |
| picture options | `picture` |
| synonym, antonym match and sort | synonyms, antonyms, word family |

`modes` stays as an author's switch off, not as the kind marker.

## Still open

The owner's six questions, and three on set cards, are answered. Left:

1. **Exams (#509):** what an exam holds besides passages, its mockups and
   its place in the B1 plan.
2. **The ability rule's numbers:** the thresholds of stability and rating
   that move a card from the easier to the harder types (the rule itself is
   approved). Built from the skill model (ADR-0035) and tuned.

See also: [Roadmap](Roadmap) · [Plans-Index](Plans-Index) · [Home](Home)
