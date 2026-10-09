# ADR-0035: FSRS fitted to each learner, per language and skill

- **Status:** Accepted
- **Date:** 2026-10-09
- **Amends:** ADR-0033's "one set of parameters for every schedule, until
  the optimiser": the optimiser is here, and fits a set per language and
  skill.

## Context

ADR-0033 scheduled every pair with FSRS-6's default parameters. The owner
asked the app to "progressively adjust to the user's aptitudes in terms of
the skills ... if the user remembers all too easily then less reviews until
he starts forgetting", and chose to fit FSRS's parameters from each
learner's own reviews, separately for each skill and each language, in the
skill model's pull request (`docs/plans/skill-model.md`, "FSRS fitted to
the learner, per skill"). `FsrsFit`, a port of `fsrs-rs`'s optimiser, was
already written and checked against `fsrs-rs`.

## Decision

- **Which set schedules a pair:** its skill's own fit in its card's
  language; else that skill's fit in the language most recently studied,
  by its last review, of those that have one; else FSRS-6's defaults
  (`SkillParameters`). A stored set equal to FSRS-6's defaults, which a
  lost first fit leaves when no language had a fit yet, is not a
  baseline. `record()` and the replay use the same choice for
  the whole log, so the replay stays deterministic; when a review makes
  another language the baseline, or a fit is stored, every state is
  replayed with the new choice.
- **Kept, not recomputed.** A fit starts from the set in use (the skill's
  last fit, else the baseline's), so it cannot be worked out again from
  the log. It is stored in `fsrs_parameters` (migration 7): the 21 values,
  when it ran, the review count it ran at, and the log loss before and
  after. The JSONL backup carries it as a `parameters` line
  (`docs/LOG-FORMAT.md`), so a restored phone schedules exactly as before;
  a set outside the ranges fitting clips to refuses the file, since it
  could make the scheduler divide by zero.
- **What a fit learns from:** the skill's reviews of the last three months
  or its last 1,000, whichever is more. Earlier reviews still build each
  pair's history; only the window is predicted (`FsrsFit`'s `from`). A
  window can hold no pair's first long-term review, as when the learner
  has stopped adding words, so there is nothing to fit w0 to w3 from: they
  stay the start's, and w4 to w20 are trained if the window holds enough.
  `FsrsFit.gate` says so, so "Adjust to me" is enabled only when a fit
  will give something.
- **Warm start:** `FsrsFit.fit`'s `start` replaces the defaults as what
  training starts from and what its L2 term pulls towards, as `fsrs-rs`
  does with the parameters its model starts from; the search for the first
  stabilities is pulled towards the start's too.
- **Kept only if better:** a new set replaces the set in use only if its
  log loss on the same window is lower, as `fsrs-rs` and Anki do.
  Otherwise the set in use is stored again with the new review count, so
  the automatic refit waits for 10% more answers.
- **When:** Settings' "Adjust to me", and, with "Adjust automatically" on
  (the default), after recording a review whose skill has 10% more reviews
  than at its last fit or can be fitted for the first time. Never at app
  open. One fit at a time, on another isolate (`Isolate.run`). A skill is
  looked at again only once it has 10% more answers than when last looked
  at, too, so that a fit that gives nothing is not retried after every
  answer. 10% is counted in whole numbers: 110 is 10% more than 100.
- **Nothing is gathered.** Every fit runs on the phone, from the learner's
  own log.

## Consequences

- The backup is no longer only "what happened": it holds the one piece of
  scheduling state that cannot be rebuilt. An old backup has none, and
  restores onto the defaults.
- Due dates move after a fit, and when the learner switches to another
  language that becomes a third language's baseline. Both replay the whole
  log on the main thread, as a leech action already does.
- A fit that loses still makes the skill's set its own: a copy of the
  baseline's, or of the defaults, which later fits of the baseline language
  no longer change.
- The fit models a pair's own reviews. The partial credit a right answer
  gives the skills it implies (ADR-0034) moves states the fit does not see.
- A fit costs seconds on a long log, off the main thread; the window keeps
  it bounded.

## Alternatives considered

- **One set for every skill:** the owner chose one per skill: "Option 3 in
  this PR".
- **Seeding new words from the ability layer** instead of fitting: the
  owner chose fitting.
- **Recomputing the parameters from the log** on every launch, with no
  table: impossible with a warm start, and a fit on every launch is what
  the owner ruled out ("do not crowd the opening").
- **A fixed row count** for the window: "don't use fixed row count. Use
  last 3 month's data, or last 1,000 rows, whichever is longer".
