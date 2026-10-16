# ADR-0012: Revising a finished deck is not logged

- **Status:** Accepted. Amended by ADR-0033: revisions from Today and by
  skill are recorded; a deck's Revise still records nothing.
- **Date:** 2026-10-02

## Context

A deck's badge said Done whenever a session on it would drill nothing right
now. New cards are held to one daily cap shared by every deck, so on the
first day every deck read Done and none could be started again (#120). The
fix shows Not done until every card is learned, and the learner asked that a
finished deck can still be opened "for revision".

Revising means drilling cards before they are due. SM-2 as implemented in
`Sm2.next` sets the next interval from the day of the review, as the last
interval times the ease, without asking how early the review is. A card
learned yesterday with a six-day interval, revised today and rated Good,
would next be due in about fifteen days, as if it had been remembered for
the whole six.

## Decision

A deck with every card learned and nothing due offers **Revise**. It drills
each learned card once, in its skill due soonest, through the ordinary drill
screens, and records nothing: no row in `reviews`, no change to card state.
`SessionQueue.build(reviseAll: true)` builds the queue; `DrillSession` runs it
with `recorded: false`, as number practice already does (ADR-0011).

## Consequences

- Revising never moves a card's schedule, so revision cannot make the
  schedule look better than the learner's memory is.
- Revision does not count towards the streak, the heatmap or any statistic,
  and the summary's numbers for it are not saved. A learner who only revises
  on a day keeps no streak for it.
- The drill shows no next-due intervals during revision, and ending a
  revision part-way says nothing is recorded.

## Alternatives considered

- **Log revision as ordinary reviews.** Stretches intervals as above, and
  changing `Sm2.next` to account for early reviews replaces the scheduling
  rule, which needs its own decision (AGENTS.md).
- **Log revision with a flag that replay ignores.** Keeps the streak honest
  about practice, but adds a column to the append-only `reviews` table,
  a coordinated migration, for a beta that does not need it yet.
