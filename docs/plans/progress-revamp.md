# Plan: progress screen revamp — mastery across all skills

Written 2026-10-20. Issue #678.

## What the owner asked

> Progress now just shows the result of tested results. It doesn't take
> into account words known, grammar proficiency, script proficiency,
> overall read, write, hear, say proficiencies. The two can be a 6 point
> star. With a line chart tracing the scores of all taught words/ phrases/
> script/ grammar, and an area chart tracing the overall proficiency.
> (owner, 2026-10-20)

## What exists

- **Progress** (`stats_page.dart`) shows test results per language, and
  hours spent and left (`hours-per-language.md`).
- **The review log** holds every answer, with its card, kind and skill.
  The scores below are computed from it.
- **Read/Write credit per script** (#656, #677).

## Related issues

| Issue | What | Fits here as |
|---|---|---|
| #575 (0.6.0) | A second "Toward B1" bar per skill | Replaced by the star; its scoring is kept |
| #323 | Achievements grid on Progress | Sits below the charts |
| #411 | Shareable progress image | Can share the star |

Decided in #575 (owner, 2026-10-18), reused here:

- **Known**: "FSRS 90%". A card counts once it is past learning in that
  skill and FSRS gives it at least a 90% chance of recall today.
- **The total**: "whole B1 plan", meaning built units plus the planned
  sizes of the units still to come.
- **Script skills**: their total is the letters and conjuncts in the
  path's `alphabet:` decks.

## The design

| Part | Shows | Score |
|---|---|---|
| Words count | Words mastered (bold), then words taught (lighter) | Counts |
| 6-point star (radar) | Mastery per skill: grammar, script, read, write, hear, say. The points are joined and filled; the filled area is overall mastery | Known ÷ B1 total (#575) |
| Line chart | Over time, one line each for words, phrases, script and grammar | Known ÷ taught |

- These are drawn per language, for the chosen language.
- "Known" is as #575 defines it: FSRS 90%, past learning.

## Decided (owner, 2026-10-20)

- **Words are a number, not a skill** ("Words is not a skill. It is a
  number. A mastered number in bold and a lighter coloured total
  taught/known."). Shown like **312** / 540.
- **The star's six axes**: grammar, script, read, write, hear and say.
- **The star replaces #575's bars**; #575 folds into #678.
- **The area is the star itself** ("Area chart is basically the overall
  mastery in skill, pointed on the 6 axis and then joined and filled").
  There is no separate area chart over time.
- **Line chart score**: known ÷ taught.
- **Mockup first, by Sonnet** ("Sonnet mockup"), following
  `docs/mockups/README.md`.

## Order

Milestone "Any order"; the mockup comes "Later. When we pick it up"
(owner, 2026-10-20). Related:
#411, a shareable progress image.
