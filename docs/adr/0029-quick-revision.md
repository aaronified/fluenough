# ADR-0029: Quick revision revises known words, and records only the misses

- **Status:** Accepted. Amended by ADR-0033: a revision from Today records
  every answer.
- **Date:** 2026-10-04

## Context

Today showed what was due, a lesson, and "Your decks". The owner: "I need a
way to quickly revise all that I know. The review section only shows what
are pending. Instead of the your decks, the app should have a bunch of quick
revision (5,10,15,20 cards) buttons followed by a fact of the day card."

Asked which words, they chose random words from what the learner knows.
Asked whether answers are recorded, they asked what SM-2 says. SM-2
(Woźniak, 1990) grades a card only when it is due, and has no rule for an
early review. Its step 7 repeats, the same day, items graded below 4 until
they reach it, and those extra repetitions change no interval. This app's
SM-2 also multiplies the interval on a right answer as if the card had been
due, so recording an early right answer would push the card out too far.
Told this, the owner chose to record the misses only.

## Decision

- **Where:** "Your decks" on Today gives way to Quick revision: buttons for
  5, 10, 15 and 20 words. The fact of the day follows it, as before. The
  Decks tab still lists every deck.
- **Which words:** words the learner has been taught, from every language
  they learn, picked at random each time. Each is asked in a skill it has
  been reviewed in and can be drilled in now, the way reviews ask it. Asking
  for more than are known revises all of them. With none known, the buttons
  are off, and a line says that revision opens up after a lesson.
- **What is recorded:** a wrong answer, as a review with its failing grade.
  It is a lapse, and brings the word back sooner. A right answer is not
  recorded, and its word's schedule stays as it was.
- `DrillRequest.revision(count)` asks for it. It is a revise request, so
  every reviewed pair counts as due, limited to [count] words picked at
  random.

## Consequences

- A learner can revise as much as they like without stretching any word's
  interval.
- A word missed in revision comes back in reviews sooner, which goes
  beyond SM-2: early failures count, early successes do not. The log shows
  the miss like any other review.
- One session mixes the languages learned, where Start review takes them
  one at a time (#153). Each card still names its deck.
- Today no longer lists decks; the Decks tab does.

## Alternatives considered

- **Strict SM-2, nothing recorded**: a forgotten word would wait for its
  date. The owner chose to record the misses.
- **Record everything**: an early right answer would stretch the interval
  as if the word had been remembered for all of it.
- **Weakest first, or not seen longest first**: the owner chose random.
