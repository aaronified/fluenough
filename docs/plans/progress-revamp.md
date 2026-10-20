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

## The design

| Chart | Shows | Source |
|---|---|---|
| 6-point star (radar) | Mastery now, one axis per skill | Recall per skill |
| Line chart | Scores over time for taught words, phrases, script and grammar, one line each | Recall per card kind, by day |
| Area chart | Overall proficiency over time | Combined from the six axes |

- A score is the share of taught items that are currently remembered
  (0 to 100). Items not yet taught do not count against it.
- These charts are drawn per language, for the chosen language.

## Open questions

1. **The star's six axes.** Seven were named: words, grammar, script,
   read, write, hear, say. Which six? Suggested: words, grammar, read,
   write, hear, say, with script folded into read/write, since those are
   already credited per script (#656).
2. **Overall proficiency.** A weighted mean of the six axes, or mapped to
   CEFR (A1 to B1)?
3. **Mockup first?** `docs/mockups/README.md` says yes.

## Order

Not started before the deck work is done (owner, 2026-10-18). Related:
#411, a shareable progress image.
