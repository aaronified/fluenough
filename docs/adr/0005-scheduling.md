# ADR-0005: SM-2 scheduling over an append-only review log

- **Status:** Accepted
- **Date:** 2026-09-19

## Context

Spaced repetition needs two things: an algorithm deciding when a card is next
due, and somewhere to keep the state it operates on.

## Decision

Implement SM-2. Persist **every review event** to an append-only log, and treat
per-card scheduling state as a derived cache.

Schedule **per (card, drill mode)**, not per card.

## Consequences

**The log is the important half of this decision.** Storing only the current
interval — which is what most implementations do — permanently discards the
data needed to evaluate or change the algorithm. With a full log, FSRS or
anything else can be swapped in later and the entire history replayed through
it. Statistics that were never anticipated remain computable.

The cost is storage, and it is negligible: a review record is well under 200
bytes, so a decade of heavy daily use stays in single-digit megabytes.

**Per-mode scheduling reflects how language learning actually works.**
Recognising a word is easier than producing it, which is easier than
recognising it by ear. One shared interval would over-drill the easy direction
and under-drill the hard one. The cost is up to four scheduling rows per card.

**SM-2 over FSRS** because it is ~100 lines with no dependency, is well
understood, and is good enough. FSRS gives better retention per review, and the
log means adopting it later loses nothing.

**SM-2 over Leitner** because Leitner's fixed buckets ignore how hard a card is
for the individual learner.

The scheduler is pure Dart with no Flutter dependency, so it is unit-testable
without a device.
