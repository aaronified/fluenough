# ADR-0010: Vocabulary is taught along a shared path of themes

- **Status:** Accepted. The ordering of a course's decks is superseded by [ADR-0013](0013-course-paths.md); the theme list stands.
- **Date:** 2026-09-29

## Context

The beta aims at minimal fluency: what a learner needs in a market, a bus or
a cab, taught in a sensible order, as a course is (#52). A deck of 100 mixed
words does not do that. The maintainer decided on themes, one deck per theme,
a shared list of themes for every language, a suggested order with nothing
locked, and grammar kept separate.

## Decision

- **One shared file, `decks/themes.yaml`**, lists the theme ids and English
  names in order. It is a file of its own kind (`kind: themes`), not a deck.
  It is bundled as a single asset.
- **A theme deck is a vocab deck with a `theme`.** Its id is the course plus
  the theme (`hi-en-market`), per the id convention of #51. Each language
  picks its own words for a theme.
- **The catalog orders each course's theme decks by the path**, in the
  places those decks already held, so that everything else keeps its path
  order. Sessions take new cards in deck order, so new cards follow the
  path. The learner can drill any theme deck instead. Nothing is locked.
- **`pos: phrase` means not typed.** A card that declares no `modes` and is a
  phrase gets recognition and listening. The field already existed, so a
  phrase needs no new syntax.
- **The validator** checks the themes file, that every `theme` is on the
  path, and that a course has one deck per theme.

## Consequences

- Adding a theme is a line in `themes.yaml` and a deck in each course that
  teaches it. Theme ids are permanent, like card ids. (Amended 3 October
  2026: Bengali added family, work, home and daily-life before the other
  courses, so a course need not have a deck for every theme.)
- One order for all languages. A language that wants a different order
  cannot have one; that was accepted for a consistent path.
- The Decks tab groups a course's theme decks under the course, a departure
  from the design's flat list. That is a separate change on #52.
