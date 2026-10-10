# Plan: difficulty by skill and by card

Written 2026-10-05.

## What the owner asked

> separate difficulty by skill and card (eg. recognition and reproduction
> of a word are different skills, and so are listening and speaking)

Then, on how: "2 will then build upon 1 only". Asked what to keep, the owner
chose **FSRS's difficulty only**. This plan comes after FSRS (done: ADR-0033),
and adds no estimate of its own from length or sounds.

## What exists

- **Schedules are already separate by skill.** Since ADR-0005 each
  `(card, mode)` pair has its own state: recognition, production,
  listening, speaking, grammar and reading. Each has its own FSRS
  difficulty and stability.
- **Lesson difficulty is not.** `Difficulty.of(card)` in
  `lib/core/scheduling/lesson.dart` gives one difficulty per card, for every
  skill, from length alone:
  - hard: a phrase, a sentence of three words or more, or a grammar cell;
  - medium: two words, or seven letters or more, counted in the reading;
  - easy: the rest.
- Lessons use it to pick three new cards of each difficulty, and to choose
  each card's questions (`lessonQuestions`). Nothing else uses it.

## What FSRS brings

With FSRS (ADR-0033), which landed with the skill model (ADR-0034), every
word has a **difficulty** D from 1 to 10 in each of its schedules (Hear, Say,
Write; grammar understood and produced), learned from its own answers. So D
is already separate by skill and by word. పాలు missed by ear gets a high D for
Hear and keeps a low one for Write.

A pair has no D until its first answer in that skill. New words are
therefore still picked by today's `Difficulty.of(card)`, until it is
replaced.

## What it takes

1. **Difficulty is FSRS's D**, per card and skill, read from the pair's
   state. There is no other measure.
2. **Where it is used:**
   - **Reviews:** a session can order or spread its pairs by D, so that the
     hardest skills of a word do not all come at once.
   - **Quick revision:** words can be picked by D.
   - **Inspect** shows a card's D in each skill it has been answered in.

   Lessons teach new words, which have no D yet, so lessons do not use it.
3. **Parameters per skill:** done. FSRS keeps one set of 21 parameters per
   language and skill, fitted from the learner's own history, so that
   listening can forget faster than recognition (ADR-0035, owner,
   2026-10-09).
4. **Tests:** D stays separate per skill. A miss in one skill leaves the
   others' D alone. Reviews and quick revision read D as decided.

## Decided (owner, 2026-10-10)

- **Reviews ignore D** ("Ignore it"): a review session stays ordered by
  due date.
- **Quick revision stays random** ("Keep random").
- **New words keep `Difficulty.of(card)`** ("Keep it"), until FSRS has a
  D for them.
- One set of FSRS parameters per language and skill (ADR-0035).

So what is built is the reading of D per card and skill, and **Inspect
showing a card's D in each skill it has been answered in**, with the tests
that D stays separate per skill. It goes into v0.4 (owner, 2026-10-10).

## Estimate

About 1–2 hours, with the decisions above. Confidence: medium.

## Built (2026-10-10)

`SkillDifficulty` in `lib/core/scheduling/skill_difficulty.dart` reads D
per card and skill from the pair states, none for a skill not answered.
Inspect lists it under "How hard, for you" when a card is opened, as
"Hear: 7 of 10, harder" (easier up to 4, harder from 7). Tests:
`test/skill_difficulty_test.dart` (D separate per skill; a miss, or a right
answer implying another skill, leaves the others' D alone) and
`test/features/decks/inspect_page_test.dart` (values shown, nothing for an
unanswered skill, heading and contrast).
