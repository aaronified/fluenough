# ADR-0030: Today's skill tiles start a review of their skill, and quick revision can take one

- **Status:** Accepted. Amended by ADR-0033: a skill's revision records
  every answer.
- **Date:** 2026-10-05

## Context

Today's due card showed four skill tiles, recognition, production, listening
and grammar, each with its count of today's cards. The tiles started
nothing. Only Start review did, for everything due. The owner asked: "let
the user review stuff by skills in the homepage. e.g. want to revise all
spoken skills".

Asked how, they decided:

- A tile reviews **everything due** in its skill. With nothing due, it
  **asks whether to revise everything known** in it.
- **"Spoken"** means listening and speaking together.
- **Speaking gets a tile** of its own. A sentence tile will follow later.
- **Quick revision gets a choice of skills.**

## Decision

- **A tile with something due** starts `DrillRequest(skill:)`: that skill's
  due cards, and the new skills of words already taught, in every language
  learned. It is recorded like any review.
- **What is due in a skill** is counted by building that skill's own
  session, not read from the tile's number. Today's session asks a word in
  one skill, so a word due in recognition and speaking counts only under
  recognition. The speaking tile can read 0 and still review those words.
  The tiles keep today's counts, which add up to the total.
- **A tile with nothing due** asks "Nothing due in Speaking. Revise all 42
  words you know in it?". Revise starts `DrillRequest.reviseSkill(skill)`:
  every word known in that skill, due or not, recording the misses and not
  the right answers, as quick revision does (ADR-0029). With nothing known
  in the skill, or the skill switched off, the tile starts nothing.
- **Speaking has a tile** while it is switched on, between listening and
  grammar. With five tiles, the last keeps its half of the row. This
  replaces ADR-0019's note that the tiles do not count speaking.
- **Quick revision** has a row of choices above its sizes:
  - All;
  - Spoken (listening and speaking), while both are on;
  - each skill with a tile that is switched on.

  `DrillRequest.revision(count, skills:)` carries the choice. A choice with
  nothing known turns the buttons off and says so.
- **A drill request names its skills** with `skills`, a set, or `skill`,
  one. `named` reads either.
- `recordsMisses` is now true for any revision from Today, which is any
  revise request over every deck. A deck's Revise still records nothing.

## Consequences

- A learner can drill one skill from Today, due or not, in a tap or two.
- Revising every word known in a skill can be a long session. It can be
  ended at any time, and the misses so far are kept.
- Today builds one session per tile to know what each tile starts. That is
  a little more work each time Today is drawn.
- The quick revision choice is not remembered between visits.

## Alternatives considered

- **Tiles revise everything known, due or not:** the owner chose what is due
  first.
- **Speaking reached through quick revision only:** the owner chose a tile
  as well.
- **Tile counts per skill alone:** the counts would no longer add up to
  Today's total.
