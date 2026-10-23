# ADR-0045: A path sets its own level sizes, and a level counts roots only

Source of truth: this wiki page.


- **Status:** Accepted (owner, 2026-10-23: "Build the 615 next. It's needed
  for stuff like toki pona"; compounds: "No, roots only")
- **Date:** 2026-10-23

## Context

The validator held every language to the same level sizes: `LEVEL_WORDS`
(A1 700, A2 900 more, B1 1,200 more) and `B1_TOTAL` (2,000 to 3,500 words up
to B1). A language with a small vocabulary, such as Toki Pona or Lojban,
got warnings it could never clear. The plan also could not hold a theme unit
that teaches no new roots, which Toki Pona needs, and it was unsettled
whether a compound built from roots counts as a word (#615).

## Decision

- **A path may give `levels:`**, optional, in `<lang>-path.yaml`:
  `levels: { A1: 120, A2: 60, B1: 80 }`. It gives the words per level, as the
  defaults do: A1, then A2 and B1 each in addition. All three are given, each
  a whole number of 1 or more. Without it the defaults apply.
- **The validator reads it.** The levels replace `LEVEL_WORDS` for that path's
  level warnings and its info line, and their sum replaces the fixed B1 total:
  the plan is warned of when outside half to one and a half times the sum.
- **The app reads it** into the course path. B1 holds the sum of the levels,
  and Progress counts toward that; without `levels` it is the sum of the
  units' planned words, as before.
- **Roots only.** A multi-word compound is written `pos: "phrase"` and does
  not count toward a level's words. The count already left out phrases; the
  Progress totals now use the same rule as the validator and the picker
  (`countsAsWord`).
- **A planned theme unit may plan 0 words**, a theme with no new roots. The
  validator and the app's path reader agree on it. The words are still given:
  a unit up to B1 gives its words or its grammar topics.
- **Not now** (owner: "With those courses"): names for the milestones, and
  periods or stages. They wait for the ancient-language courses.

## Consequences

- Released apps reject unknown keys in a path, so no path sets `levels:` in
  the release that adds it to the app. A path sets it one release later;
  Toki Pona's will.
- The levels are a second place for a size, beside the units' own `words`.
  The validator warns when they drift apart, but does not make them equal.
- The language picker's "x% of B1" still comes from the units' words in
  `index.json`, which does not carry `levels`.

## Alternatives considered

- **A per-language table in the validator.** Rejected: the app would need
  the same table, and a language is data, never code.
- **Letting a path give only some levels.** Rejected: half a plan would mix
  its own sizes with the defaults and give a meaningless total.
- **Counting compounds as words.** Rejected by the owner: it would inflate
  a language that builds its vocabulary from phrases.
