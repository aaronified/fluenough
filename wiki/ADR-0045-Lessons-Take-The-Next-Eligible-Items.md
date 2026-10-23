# ADR-0045: A lesson takes the next eligible items, and a sentence waits until its words and rules are known

Source of truth: this wiki page.


- **Status:** Accepted. Amends ADR-0024: the fixed quota of three items of
  each difficulty goes.
- **Date:** 2026-10-23

## Context

ADR-0024 made a lesson nine new items, the first three of each difficulty.
Every sentence came from the first lesson on, with its words untaught: on
Telugu, 0% of the words of the first six lessons' sentences were known
([Plan: Words, Rules, Sentences](Plan-Words-Rules-Sentences)). The owner
decided (2026-10-16 to 2026-10-23, #414, #416):

- a word or a rule is **known** when 9 of its last 10 answers are right;
- a sentence is offered once every word in it, by its base word, and every
  rule it uses are known; a phrasebook chunk is never held back;
- a lesson adds **fewer new items until those in progress reach the bar**;
  everyone changes at once, and nothing learnt is lost;
- **closed sentences** are greyed with what they wait for, and a tap opens a
  sheet saying why; there is no lesson plan screen.

## Decision

- **Known** is read from the review log (`RecentAnswers`), never stored:
  9 of the last 10 answers right, over any skill of a word; a rule over all
  the cells of its table.
- **The gate** (`Unlocks`, `lib/core/progress/unlocks.dart`):
  - a sentence naming words (`bases` by card) and rules (`rules`) is closed
    while any of them is not known; a word or rule its course has no card
    or cell for is not waited for;
  - a phrasebook chunk, and a sentence naming nothing, are never closed;
  - a rules table's cell is taught only for a word that is known, so a
    table grows as words are learned.
- **A closed sentence is not new.** It is left out of a lesson's new cards
  and of a deck's count of what is left to learn, so it does not hold back
  its unit. A sentence already taught stays open. Reviews never wait: the
  gate decides only when a new sentence appears.
- **A lesson** takes the next eligible items in the path's order: at most
  nine, less the words and rules taught and not known yet, never fewer than
  two, and at most three cells of a rules table (owner, 2026-10-16: "3 per
  lesson"). They are taught easy first.

## Consequences

- A learner who has not met a word's reviews often enough sees few sentences
  at first; that is the owner's aim. The floor of two new items keeps a
  lesson from being only reviews.
- Existing learners continue from the next eligible item; nothing is
  removed.
- The unit page shows the gate: sentences open of its sentences, a closed
  one greyed with what it waits for.

## Alternatives considered

- **A lesson plan screen** before each lesson: explains the smaller lessons
  but costs a tap every time. Not chosen (owner, 2026-10-23).
- **Hiding closed sentences:** a shorter page, but a unit looks smaller than
  it is.
- **The B1 plan as the denominator** for counts: a tiny share early on
  (86 of 900). Counts are of what is taught so far.

See also: [ADR-0024](ADR-0024-Daily-Lessons) · [Plan: Words, Rules, Sentences](Plan-Words-Rules-Sentences) · [ADR-Index](ADR-Index) · [Home](Home)
