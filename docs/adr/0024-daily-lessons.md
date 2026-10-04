# ADR-0024: New words come in a daily lesson, and every drill has more kinds of question

- **Status:** Accepted. Amends ADR-0010 (phrases are produced, by
  rearranging), ADR-0013 (the pending units feed lessons) and ADR-0019 (no
  daily cap for a passage to pass).
- **Date:** 2026-10-04

## Context

The owner asked: "add more speech and hearing cards from the beginning. I
have seen none yet. And add more mcqs, drag n drop, rearrange etc questions.
Add a learning set with easy medium hard each day, followed by an exercise
on those. Like duolingo does." They decided:

- a lesson teaches **3 easy, 3 medium and 3 hard** new items, then an
  **exercise** on them; what makes an item easy, medium or hard is **both**
  the word and the exercise;
- the new question kinds are **multiple choice**, **match pairs** (drag and
  drop) and **rearrange words**, and **listening and speaking are on from
  lesson 1**;
- **one lesson a day** for each language learned, then an optional
  **"Another lesson"**;
- each new word is checked in **two skills** in its lesson; its other
  skills join its reviews from the next day;
- a reading deck comes as **a reading lesson**: one passage and its
  questions;
- **new items come only through lessons**: Start review is reviews only,
  and the new-cards-per-day setting goes;
- **reviews mix in the new kinds**: recognition becomes multiple choice or
  match pairs instead of rating oneself; sentences get rearrange; typing,
  listening and speaking stay.

Until now Today's session took up to 20 new `(card, mode)` pairs a day from
the pending units, one per card, in `DrillMode` order. Recognition comes
first, so a new learner saw only recognition for days, and no listening or
speaking. Phrases were never produced (ADR-0010).

## Decision

- **A lesson** is 9 new cards from the pending units (ADR-0013), in path
  order, up to the first reading question: the first 3 of each difficulty,
  a short list filled from the others, taught easy first.
  - **Difficulty by the word:** hard is a phrase, a sentence of three or more
    words, or a grammar cell; medium is two words, or one of seven letters
    or more, counted in the reading where there is one; easy is the rest.
  - **Difficulty by the exercise:** each item is taught (word, reading,
    meaning, played aloud), then checked at once: an easy one by choosing
    its meaning; a medium one by hearing it and choosing it, or without a
    voice by choosing the word; a hard one by typing it, or by rearranging
    it when it has three words or more, or is a phrase of two.
  - **The exercise** then asks each item once more, in a second skill, in
    a mixed order: easy ones are said aloud, medium ones matched in pairs,
    hard ones said aloud; where the phone cannot hear, heard and chosen
    instead.
- **A reading lesson.** When the next new card on the path is a reading
  question, the lesson is its passage and its questions, read and heard.
- **What a lesson records.** Each check records one `(card, mode)` pair:
  choosing the meaning or matching it records recognition; hearing it
  records listening; typing, rearranging or choosing the word records
  production; saying it records speaking. A right choice is graded 4, a
  right typed or said answer 5, a near miss as before, a wrong one 1. A
  grammar cell has one skill, so it is asked once, typed.
- **Today** shows each language's lesson ("Learn 9 new words") above the
  reviews, then "Another lesson" once it is done. Start review is due
  reviews only, and the new skills of words already met: a word is new
  once, in its lesson. The new-cards-per-day slider is removed.
- **Reviews** ask a due recognition pair by multiple choice, or, four at a
  time, by match pairs; a due production pair of a sentence of three words
  or more, or of a phrase of two or more, by rearranging it. So phrases are
  produced after all, by rearranging, never typed (ADR-0010). Typing,
  listening and speaking are unchanged.
- **Listening and speaking from lesson 1:** a lesson asks to hear and say
  its words wherever the phone can. Speaking stays as first launch's sound
  check set it.

## Consequences

- A learner gets 9 new words a day by default, in every skill, rather than up
  to 20 new pairs, mostly recognition.
- Self-rating survives only where a choice cannot be made: a language with
  fewer than two other cards to choose from.
- Placement, paths and the scheduler are unchanged: a lesson draws on the
  pending units (ADR-0013), and what it records is scheduled as before.
  Today's session no longer takes new cards from the pending units, and
  there is no daily cap, so the shares between languages and the cap ADR-0019
  lets a passage pass are gone.
- A deck is finished once every word in it is taught, so the path moves on
  then; the words' other skills come with their reviews. A deck's "New"
  count is its words not taught yet.
- Nothing past the day's lesson is offered as new on a deck's screen: with
  nothing due, it offers a lesson of that deck's words instead of "Learn
  anyway".

## Alternatives considered

- **Keep the new-card cap beside lessons:** the owner chose lessons only.
- **Every skill of every word in its lesson:** about 40 screens a lesson;
  the owner chose two skills a word, about 27.
- **Passages as a hard item in the word lesson:** the owner chose a reading
  lesson of its own.
- **One lesson a day in all:** the owner chose one for each language.
