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
skill model's pull request (ADR-0034; the owner's words are in the record
below). `FsrsFit`, a port of `fsrs-rs`'s optimiser, was already written and
checked against `fsrs-rs`.

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

## Record of the owner's decisions, moved from the deleted plan

`docs/plans/skill-model.md` and `docs/plans/fsrs.md` were deleted when #207
and #113 closed (the rule in `docs/ROADMAP.md`). The owner's words about
fitting and how it is shown, with their dates, are kept here. The research
is `docs/research/skill-evidence.md`.

### What the owner decided, 2026-10-09

- **Fitted per skill, in the skill model's pull request:** "Option 3 in this
  PR". Asked to "progressively adjust to the user's aptitudes in terms of
  the skills ... if the user remembers all too easily then less reviews
  until he starts forgetting", the owner chose to fit FSRS's parameters from
  each learner's own reviews, separately for each skill, over seeding new
  words from the ability layer or one fit for all skills. This reverses
  ADR-0033's "one set". Defaults hold until a skill has enough reviews to
  fit.
- **When fitting runs:** "By a button, and when a skill increases by 10%.
  The button will have an automatic option for this. And this happens via a
  hook, do not crowd the opening." So: a button in Settings refits now;
  beside it, an automatic option refits a skill whenever its reviews have
  grown by 10% since its last fit, set off by recording a review, never at
  app start, and run off the main thread. The automatic option is on by
  default (owner, 2026-10-09).
- **Each fit starts from the last** (owner: "Absolutely"): a refit warm
  starts from the skill's previous parameters, so it needs fewer passes.
- **Per language too** (owner: "the fit on one language should be used as
  the baseline on the next language (the latest learnt one), but each
  language will eventually get their own learning fits"). Parameters are
  kept per language and skill. A language with no fit of its own for a skill
  starts from that skill's fit in the language most recently studied (by its
  last review; owner confirmed), not the defaults; once it has enough
  reviews it is fitted on its own, starting from that baseline. Each skill's
  parameters are therefore kept, not recomputed: in the profile's database
  and in the JSONL backup, so a restored phone schedules exactly as before
  (owner).
- **What a fit learns from** (owner: "don't use fixed row count. Use last 3
  month's data, or last 1,000 rows, whichever is longer"): a skill's reviews
  from the last three months, or its last 1,000, whichever is more. Earlier
  reviews still build each word's memory state up to that window; only the
  window's answers are what the fit learns from.
- **Nothing is gathered** (owner: "We do not gather any data at all"). Every
  fit runs on the phone, from that learner's own review log; nothing leaves
  it. Where a plan or the research says a figure could be "fitted from the
  app's logs", it means the learner's own log, on the phone.
- **Shown prominently** (owner: "Yes. Prominently. Figure out how"). Three
  designs were mocked up (moment, ambient, story; `docs/mockups/`); the
  owner chose, 2026-10-09:
  - **Wording:** as the judge proposed: "You remember Hear words well: fewer
    reviews", "Write words slip faster: more reviews" ("slip", never
    "fade"); "comes back in 6 days, not 4"; "About 120 reviews in the next
    30 days, was 160"; "more reviews" never in the error colour. (The
    examples' "Hear words" and "Write words" are superseded by the skill
    names below.)
  - **Settings:** moment's "Adjust to me" button, the automatic option and
    the result sheet, with a progress bar while adjusting. The button is
    disabled, "Needs more answers first", until a skill can be fitted;
    "Worked out on this phone from your answers. Nothing is sent anywhere."
  - **Progress:** a card like ambient's strip, "How you learn" or "Learn
    more about your pacing", that opens story's page: per skill, how fast
    the learner forgets against the default.
  - **Today:** ambient's strip on the due card and the marks on the skill
    tiles, aligned properly ("your render has everything misaligned. That
    won't do").
  - **Revised mockups before any of it is built**
    (`docs/mockups/adapted-to-you.html`). The owner then refined them:
    - **Today always uses the settled strip;** the larger "just refitted"
      one goes.
    - **Progress keeps one skills section:** "Correct, by skill" and "Weakest
      tags", as before; the "Your strengths" section, which said the same
      thing, goes. The "How you learn" card stays.
    - **Skills named by what the words were:** "seen words" (Recognition;
      not "read", which is the script's and passages'), "heard words",
      "spoken words", "written words" ("You remember heard words well: fewer
      reviews"), not "Hear words".

### Settled while building the fit

The builder's readings, 2026-10-09. **The owner may overrule any of them.**
Most are in the Decision above; the list is kept whole.

- **Baseline:** of the other languages with a fit for the skill, the one
  studied last (latest review in any skill). A set equal to FSRS-6's
  defaults is never a baseline.
- **States follow the current choice:** when studying another language
  changes a baseline, every state is replayed, as a leech action does.
- **A fit that loses** stores the set in use with the new count, so the next
  automatic refit waits for 10% more answers.
- **Restore:** when a backup and the phone both hold a fit for a skill, the
  later fit wins. A restored set must lie in fitting's clip ranges.
- **A window with no first long-term review** keeps the start's w0 to w3 and
  trains w4 to w20.
- **Result sheet figures:** "comes back in N days" is the median interval a
  right answer would give now; "reviews in the next 30 days" assumes each is
  answered right on its day; within 5% is "about the same".
- **The fit sees each word's own reviews only;** the half credit from
  implied skills is not modelled.

### Settled while building the display

The builder's readings, 2026-10-09. **The owner may overrule any of them.**

- **"At the start" is FSRS-6's defaults.** How you learn and Today's marks
  compare the set that schedules a skill with them, using the result
  sheet's figures (`SkillFit.outlook` and `direction`). A skill paced by
  another language's fit is adjusted, and says so; a stored copy of the
  defaults is not.
- **Today shows once a fit has kept a set other than the defaults.** The
  strip counts every skill of the languages learned; a tile's mark adds its
  skill's languages together. The Progress card and How you learn's "Nothing
  is adjusted yet" go by the same test, so a learner whose every fit lost
  to the defaults is told nothing is adjusted on all three screens.
- **A skill not adjusted says how many answers it has,** not how many it
  needs: the gate counts reviews a day or more apart and first ratings, so
  no answer count is the threshold ("Needs 400 answers" in the mockup is not
  shown). A skill whose fit lost says instead that its answers fitted the
  starting pace best, so it stays.
- **The figures are worked out, not stored:** on an isolate, when a screen
  asks, again when the log, the fits or the day change. Storing them would
  need a migration, and they move with the day. One job runs at a time, and
  Today asks only while it is on view, so for an adjusted learner a job runs
  as the app opens and when Today comes back after a drill, not after every
  answer.
- **The Progress card** sits at the foot of "Correct, by skill", for the
  language chosen; from Today and the result sheet the page shows every
  language learned.
- **Large text:** from text scale 1.3 a tile's mark is its arrow and one
  word; in one column, from 1.5, the full words again.

### The optimiser, and what is left

- **The optimiser is done:** `FsrsFit` is in Dart, so it needs neither the
  Rust optimiser through FFI nor an offline fit, as `docs/plans/fsrs.md`
  expected.
- **Per-skill parameter sets** were `docs/plans/difficulty-by-skill.md`'s
  item 3, waiting for the optimiser: done here. That plan (#208) is still
  open for the rest.
