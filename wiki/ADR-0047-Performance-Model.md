# ADR-0047: The performance model: per-language versions, incremental aggregates and batching

Source of truth: this wiki page.

- **Status:** Accepted.
- **Date:** 2026-10-25

## Context

A learner may keep up to 40 languages for over two years: about 300,000
logged reviews and 200,000 loaded cards. Every answer and tap used to
rebuild every language's session, scan the whole log and rebuild both
themes, so the app froze for about a second (#850, #852, #853, #854, #856).
The owner's bar (2026-10-25): the app must not lag from calculations, using
saved calculations, approximations and batching, so that work is not
clumped.

## Decision

- **Scale target:** 40 languages by 2 years. No work done per answer may
  scale with the whole log or with all cards, only with the answered
  language.
- **Per-language versions.** Progress keeps a version for each language and
  one for everything (`ProgressStore.versionOf`). `AppState` adds counters
  for settings and structure (decks, voices, the profile). Anything kept
  for a language is stamped with its language's version and those
  counters, and is used only while the stamp holds. An answer in Telugu
  leaves Hindi's sessions, deck counts and finished flags cached.
- **Kept values.** Sessions (`buildSession`), `isFinished`, `notStudiedIn`
  and the light and dark themes are kept by what they read. A queue is
  immutable, so sharing one is safe.
- **Incremental aggregates.** Anything read from the log is added to as
  answers come, never recounted: the answer times, the words first drilled
  today and the progress index. A restore or an import, which change the
  log other than at its end, read it again once.
- **Batching.** Today works out the first four languages at once; the
  others are worked out one per idle slot, the last known value showing
  until then, so no frame works out forty languages. The path is a lazy
  sliver, building only the rows on screen.
- **Approximations**, where the exact value is not user-critical: a kept
  queue's clock counts in 30 second steps (a card falling due shows up to
  30 seconds late); the median answer time that sizes a day's budget is
  worked out again every 25 answers.
- **Isolates** are for work that cannot be made incremental, such as fitting
  FSRS parameters or reading a restored backup; it never runs on the UI
  isolate while the learner answers.

## Consequences

- Each new aggregate must say what it is stamped with, and a test counts
  operations (builds per language), not time.
- A due-time index per language would make due counts cost only what is
  due; it is not built: sessions are already per language, and the queue
  still reads every card of the language it rebuilds.
