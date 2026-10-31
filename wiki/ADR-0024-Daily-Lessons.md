# ADR-0024: New words come in a daily lesson, and every drill has more kinds of question

Source of truth: this wiki page.


- **Status:** Accepted. Amends ADR-0010 (phrases are produced, by
  rearranging), ADR-0013 (the pending units feed lessons) and ADR-0019 (no
  daily cap for a passage to pass). Amended by ADR-0034: how listening is
  asked, and what a right choice records. Amended by
  [ADR-0046](ADR-0046-Lessons-Take-The-Next-Eligible-Items): a lesson has no
  fixed quota of each difficulty, and a sentence waits for its words and
  rules. Amended 2026-10-31 (#694): a deck page learns by a card-by-card
  walkthrough that logs a view row; Today's lesson is unchanged (see
  "Amendment, 2026-10-31" at the end).
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
  - **Difficulty by the exercise:** each item is taught on the one-screen
    teach card (#691: word, reading, IPA, meaning, played aloud; a swipe or
    a chevron goes on), then checked at once: an easy one by choosing
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

## Amendment, 2026-10-31: a deck page learns by walkthrough (#694)

### Context

The deck page's + Learn started a drilled lesson of the deck's words (this
ADR's Decision). The owner asked for a guided, repeatable card-by-card
walkthrough instead (#694), and decided on 2026-10-31:

> A: Walkthrough replaces + Learn

> Oh, then start fsrs anyway, with the lowest window.

> Consistency is key. If all fsrs is via logs, this must also be via logs.

> We anyway only teach recognition when we first test.

> Yes, skip them.

### Decision

- **The deck and unit pages learn by walkthrough.** Learn, and Relearn once
  every card is taught, open the same card-by-card walkthrough on the teach
  card, one walk with only the label differing. It covers every card, taught
  or not (taught status is information only, owner, 2026-10-31): the deck
  page's cards in view (as the tag chips filter them), the unit page's every
  deck in the deck order, the deck's name shown on each card. It replaces
  the drilled lesson on the deck page and the Continue bar on the unit page,
  whose one control is Learn or Relearn with "N new · M due" under it (no
  tag chips on a unit); it is off for a unit with no card to walk (readings
  only).
- **The first view teaches.** The first view of a card not taught yet appends
  one review-log row through the usual write path: `asked: teach`, grade 0 (the
  lowest window: `Fsrs.ratingOf` maps it to Again), no answer given, in the
  card's first drillable mode, which is recognition where it has it, and no
  other skill. FSRS schedules the pair from that row. A repeat view and a
  view of a card taught already write nothing, as does a card with no mode to
  drill. A sentence still waiting for its words and rules is walked and
  recorded like any other first view (owner, 2026-10-31: "Walk it, and mark as
  usual on fsrs"). The row makes the card count as taught for the Learn and
  Relearn labels, but it does not open the sentence: a view is no answer, so
  the sentence stays closed (`Unlocks.isOffered` is false) until a real answer
  opens it. A rules-table cell whose word is not yet known is walked and logged
  the same way.
- **A view is not an answer.** Every reader that counts answers skips rows
  with `asked == teach`: accuracy and remembered shares, lapses and leeches
  (a first Again starts no lapse; the next miss after a right answer is the
  pair's first), the FSRS fit, abilities, study hours and answer times,
  streaks, the heatmap, mastery and what counts as known. Your data lists the
  row as "Seen". No schema change: `asked` is already a column of the log.
- **Today's lesson is unchanged.** It still teaches each word on the teach
  card and then asks it at once, and records only the asks.

### Consequences

- A learner who walks through a deck has every viewed card out of New, due
  again after the lowest window, and no answer on record.
- The log holds rows that are not answers, so a reader of the log must skip
  them (`ReviewEvent.isView`).

See also: [Contributing](Contributing) · [ADR-Index](ADR-Index) · [Home](Home)
