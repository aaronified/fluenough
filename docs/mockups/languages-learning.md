# Delete a language's data (#861)

The wiki is the source of truth for documentation: https://github.com/aaronified/fluenough/wiki

Notes and self-check for `languages-learning.html`. This is a new revision of
the page removed when Languages I'm learning was built (`git show
4e094b9:docs/mockups/languages-learning.html`): it draws only what #861 adds,
and awaits the owner's approval in review of its pull request.

## What it shows

1. The sheet: a round bin with a red icon to the left of the bottom button,
   labelled Delete data for screen readers and One word, Delete, on a long
   press (owner, 2026-10-27: "to the left ... so it stays out of hand").
2. The dialog: what will go, one tick for each item: Reviews (with All dates or
   Only these days, From and To, both days included, by the learner's local
   day; for a period when someone else tested the app), Placement (the course
   asks again), Language settings, Deck data. A line says a backup is kept
   first and where. The language's name is typed; Delete stays off until it
   matches exactly and one item is ticked.
3. After: a toast says the data is deleted and where the backup is.

## Tweak controls

Theme (light, dark), text (1x, 1.4x), language (Hindustani, Bengali), range
(All dates, Only these days) and whether the name is typed.

## Self-check

- Contrast: the page computes the ratio of every text and control pair for the
  theme on screen and prints it above the screens (all at 4.5:1 or more; the
  disabled Delete is dimmed to 38% as Material does).
- Text up to 1.4x: the dialog scrolls inside the screen and no row is cut off;
  the page has no horizontal scroll at phone width.
- Not run in Chromium by this agent (no browser in the build container): the
  owner is asked to look at it in review.

## Choices made while building

- Fitted FSRS parameters of the language are dropped when any of its reviews
  go (they were learned from them); other languages keep theirs. Card states
  are rebuilt by replaying the remaining log, for every language, since a
  language's fit can be another's baseline.
- Placement's credit is stored in the log as reviews but is not an answer: Reviews
  never deletes it, Placement deletes only it.
- The backup is the app's own backup (kind `delete`), in Recent backups.
