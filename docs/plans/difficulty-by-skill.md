# Plan: difficulty by skill and by card

Written 2026-10-05.

## What the owner asked

> separate difficulty by skill and card (eg. recognition and reproduction
> of a word are different skills, and so are listening and speaking)

Then, on how: "2 will then build upon 1 only". Asked what to keep, the owner
chose **FSRS's difficulty only**. This plan comes after `fsrs.md`, and adds
no estimate of its own from length or sounds.

## What exists

- **Schedules are already separate by skill.** Since ADR-0005 each
  `(card, mode)` pair has its own state: recognition, production,
  listening, speaking, grammar and reading. Each has its own SM-2 ease.
- **Lesson difficulty is not.** `Difficulty.of(card)` in
  `lib/core/scheduling/lesson.dart` gives one difficulty per card, for every
  skill, from length alone:
  - hard: a phrase, a sentence of three words or more, or a grammar cell;
  - medium: two words, or seven letters or more, counted in the reading;
  - easy: the rest.
- Lessons use it to pick three new cards of each difficulty, and to choose
  each card's questions (`lessonQuestions`). Nothing else uses it.

## What FSRS brings

With FSRS (`fsrs.md`), every pair has a **difficulty** D from 1 to 10,
learned from its own answers. Each pair is a card and a skill, so D is
already separate by skill and by card. పాలు missed by ear gets a high D for
listening and keeps a low one for recognition.

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
3. **Parameters per skill**, optionally: FSRS can keep one set of 21
   parameters per skill, so that listening can forget faster than
   recognition. Each set needs its own history to fit, so this waits for
   the optimiser (`fsrs.md`, "Later").
4. **Tests:** D stays separate per skill. A miss in one skill leaves the
   others' D alone. Reviews and quick revision read D as decided.

## To decide

- Whether a review session orders its pairs by D, spreads them, or ignores
  it.
- Whether quick revision picks the hardest words first, or keeps picking at
  random.
- Whether to replace `Difficulty.of(card)` for new words, which have no D
  yet, or keep it.
- One set of FSRS parameters for all skills, or one per skill.

## Estimate

About 2–3 hours after `fsrs.md` lands. Confidence: medium.
