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
| #575 (0.6.0) | A second "Toward B1" bar per skill | Its decisions give the scores below |
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

| Chart | Shows | Source |
|---|---|---|
| 6-point star (radar) | Mastery now, one axis per skill | Recall per skill |
| Line chart | Scores over time for taught words, phrases, script and grammar, one line each | Recall per card kind, by day |
| Area chart | Overall proficiency over time | Combined from the six axes |

- A score is the share of the B1 total that is known (as #575 defines
  it), from 0 to 100.
- These charts are drawn per language, for the chosen language.

## Open questions

1. **The star's six axes.** Seven were named: words, grammar, script,
   read, write, hear, say. Which six? Suggested: words, grammar, read,
   write, hear, say, with script folded into read/write, since those are
   already credited per script (#656).
2. **Overall proficiency.** A weighted mean of the six axes, or mapped to
   CEFR (A1 to B1)?
3. **Mockup first?** `docs/mockups/README.md` says yes.
4. **#575's bars**: does the star replace them, or do the two sit
   together?

## Order

Not started before the deck work is done (owner, 2026-10-18). Related:
#411, a shareable progress image.
