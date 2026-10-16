# ADR-0020: Decks a learner adds are kept apart, and paths place them by wildcard

- **Status:** Accepted. Amended by ADR-0037: decks are downloaded, not bundled.
- **Date:** 2026-10-03

## Context

#22 asked for decks from outside the app. The owner asked for "the upload
deck feature. That will enable people to make their own decks (from a
downloadable template). Make sure that the path files can accomodate these
via wildcards (these custom decks will always be placed at the bottom of
their chosen themes, and if the theme is not present, then at the end)."

A course is taught along its path (ADR-0013), which lists every deck of the
course; the validator fails a deck left out. A deck written on a phone is
never in a path file. Card ids name the language and a number (ADR-0018),
and a card id is one schedule, so a card written with a bundled card's id
would share that card's history.

## Decision

- **An added deck is a file in the app's own storage,** `decks/<id>.yaml`
  under the support directory, read with the bundled decks under the
  `added/` prefix and marked as not bundled. It is a deck file like any
  other: no new format.
- **It is checked before it is kept.** The app refuses a file that does not
  parse, the id of a bundled deck, and a card id another deck has. The id
  of a deck added before replaces it. A bundled deck is read first, so an
  update that ships a deck with an added deck's id keeps the bundled one,
  and shows the added file as one that could not be read.
- **A path's unit may end in the wildcard `"*"`,** and a last unit may be
  `"*"` alone. When the catalog loads, each deck the path does not list
  goes at the bottom of the first unit ending in `"*"` that holds a theme
  deck of its theme, else into the unit of `"*"` alone. The result is a path
  with no wildcards, so Today, placement and the deck order need no change.
  A path without wildcards leaves such a deck after the path, as before.
- **Every bundled path ends each unit with a theme deck in `"*"`, and ends
  in a unit of `"*"` alone.** The validator requires a unit ending in `"*"`
  to hold a theme deck.
- **The template is Hindi from English, a market deck,** with two cards of
  its own, numbered `hi-my-NNNN`, and one `ref`. The validator would refuse
  `-my-` ids in `decks/`, so no bundled card can ever take one.
- **Removing an added deck deletes its file only.** Its cards' history
  stays, and returns if the deck is added again.

## Consequences

- Adding from a link (#22) needs only the fetch: the check, the store and
  the placement are shared.
- An added deck's theme is not checked against `decks/themes.yaml`: one the
  course does not have goes at the end, as asked.
