# Today: minutes budgeted. Self-check, notes and open questions

Companion to `today-minutes.html` (owner spec of 2026-11-04). The page holds only the screens and their tweak controls, with what is new, changed, kept or removed outlined in red. The checks and notes are here.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark, Telugu, Bengali and Hindustani examples (readings follow the course: no final a in Bengali; Telugu word-final anusvara as `ṁ`). Starting point: `lib/features/today/daily_card.dart` and `due_card.dart` on main after #1008, and `lib/ui/widgets/drill_frame.dart` (`DrillHeader`, the clock) and `wave_progress.dart`. Tweak controls: language, theme, screen (Today, In session, In session with Keep going, both sessions), Today state (normal, finished day), hint wording, highlight. New CSS corners use the `--r-*` tokens, which are `AppRadii` (a circle is `--r-round`); no numeric radius.

## What the screens draw

1. **Quick revision is removed** from Today: shown struck through, outlined "removed", where it sits now (under the streak card).
2. **Keep going is kept**, as today: a text button directly under "8 of 15 min", above the minutes chips. Today it appears only once the budget is spent (`plan.canKeepGoing`); the owner asked for it on the normal day too ("continuing to work whenever the learner wants more"), so it is drawn on both days. Always available; it never says "nothing more due".
3. **Minutes budgeted** in the ring's chips: "12 min review" and "3 min new", the old badge shape (`_Badge`: secondary container, and primary when new is above 0, outlined when 0). They are the day's whole budget (15 min, an 80 / 20 split drawn), not what is left. No card counts in the ring (#1009). On a finished day no chips, 15 of 15 min (#1007, #1008).
4. **Hint above the skill tiles**, inside the Due now card: "Tap a skill to practise only that skill". At 1.4x it wraps to two lines and nothing clips. A shorter alternative is a tweak control ("Tap a skill to practise it alone"; also wraps at 1.4x).
5. **Skill tiles** show all pending cards (12, 24, 44, 22, 6, 31: more than 15 min buys) with their pace arrows exactly as today. Outlined "unchanged". At 1.4x the name "Recognition" is scaled to fit its tile, as the app's `FittedBox` does.
6. **Finished-day ring** (#1007, #1008): greyed (surface container high button, outline-variant arc), a tick, "Done for today", still tappable (opens the end-of-session summary; screen-reader label "Done for today. Opens the summary.").
7. **In session** (`DrillHeader`, 64 dp): close, the wave, the clock, the sounds of the card's word, report. Normal: wave 35 percent full, the clock counts down the time left (9:48). **Keep going** (owner, 2026-11-04: "When user keeps going, the timer bar will not show any timer, but the time taken. The progress bar will also be full."): the wave is full for the whole stretch and the clock counts up the time taken (3:12). The page writes the clock as the app does (`clockText`: m:ss), not 03:12.

## Answered by the owner

- Keep going when nothing is due (owner, 2026-11-04): "If user keeps going, let them review closest to due cards and teach them new cards. Change the ratio as needed to not teaching too much and not reviewing too far into the future." So Keep going always has something to serve and never says "nothing more due today". (Build note: this reverses #1008's rule that a card reviewed today is never a filler, for Keep going only.)
- No add-minutes arrows, no step control (owner, 2026-11-04: "they do not need to add minutes, they can keep going"). Removed from this page.
- Keep going's timer (owner, 2026-11-04): quoted above, drawn in screen 7.

## Open questions for the owner

1. Keep going on the normal day: it is drawn under the ring on both days. Today it shows only after the budget is spent. Should it show all day, or only once the day is done?
2. Chips: the whole day's budget (12 and 3 of 15), or what is left of it? Drawn: the whole budget, so they do not move as the learner answers.
3. The split of the budget: 80 percent review, 20 percent new is drawn. What is the planner's real split, and should a day with no new words show "0 min new" outlined, as "0 new" is today?
4. After Keep going starts, the ring goes back to "Continue" with a larger budget on Today? Or does the ring stay full and greyed while the stretch runs (drawn in the session only)? Where does the time taken go afterwards: added to the day's total on Today and on the summary?
5. The clock when counting up: "3:12" (the app's m:ss) or "03:12" (as the brief wrote it)? Past an hour it would read 62:10.
6. The hint wording and its place (inside the Due now card, above the tiles): this or the shorter line? Should it go away once the learner has tapped a tile a few times?
7. The greyed ring's arc fails 3:1 (self-check below). It is #1008's design (outline variant on the page), and "15 of 15 min" says the same in text. Should the done arc be stronger (outline instead of outline variant)?

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, icons and outlines 3:1. All pairs pass except the greyed done-ring arc (question 7).

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text, minutes | onS on s | 16.33 : 1 | 4.5 : 1 | pass |
| light | captions | onSv on s | 8.9 : 1 | 4.5 : 1 | pass |
| light | ring button label | onP on p | 6.46 : 1 | 4.5 : 1 | pass |
| light | done ring label, check | onSv on sHigh | 7.64 : 1 | 4.5 : 1 | pass |
| light | Keep going text button | p on s | 6.16 : 1 | 4.5 : 1 | pass |
| light | review chip | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| light | new chip | onP on p | 6.46 : 1 | 4.5 : 1 | pass |
| light | new chip at 0 min, text | onSv on s | 8.9 : 1 | 4.5 : 1 | pass |
| light | new chip at 0 min, outline | ol on s | 4.28 : 1 | 3 : 1 | pass |
| light | hint on the due card | onPc on pc | 7.21 : 1 | 4.5 : 1 | pass |
| light | tile number | onS on sLowest | 17.13 : 1 | 4.5 : 1 | pass |
| light | tile name | onSv on sLowest | 9.33 : 1 | 4.5 : 1 | pass |
| light | tile pace arrow | onSv on sLowest | 9.33 : 1 | 3 : 1 | pass |
| light | ring progress arc, active | p on s | 6.16 : 1 | 3 : 1 | pass |
| light | ring progress arc, greyed (done) | olv on s | 1.62 : 1 | 3 : 1 | FAIL |
| light | language pill | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| light | streak card text | onS on sLow | 15.5 : 1 | 4.5 : 1 | pass |
| light | streak card caption | onSv on sLow | 8.45 : 1 | 4.5 : 1 | pass |
| light | quick revision (removed, struck) | onSv on sLow | 8.45 : 1 | 4.5 : 1 | pass |
| light | session clock | onS on s | 16.33 : 1 | 4.5 : 1 | pass |
| light | wave and end dot | p on s | 6.16 : 1 | 3 : 1 | pass |
| light | header icons (close, sound, report) | onSv on s | 8.9 : 1 | 3 : 1 | pass |
| light | drill card text | onS on sLow | 15.5 : 1 | 4.5 : 1 | pass |
| light | drill card reading, question | onSv on sLow | 8.45 : 1 | 4.5 : 1 | pass |
| light | answer option | onS on sLowest | 17.13 : 1 | 4.5 : 1 | pass |
| light | change tag | onE on E | 6.46 : 1 | 4.5 : 1 | pass |
| light | change outline on page | E on s | 6.16 : 1 | 3 : 1 | pass |
| light | tile icon rec | #001B3E on #D6E3FF | 13.28 : 1 | 3 : 1 | pass |
| light | tile icon hear | #21005D on #EADDFF | 13.32 : 1 | 3 : 1 | pass |
| light | tile icon say | #002203 on #BDF0B3 | 13.23 : 1 | 3 : 1 | pass |
| light | tile icon write | #2E1500 on #FFDCC2 | 13.3 : 1 | 3 : 1 | pass |
| light | tile icon gram | #00201B on #B8F0E4 | 13.6 : 1 | 3 : 1 | pass |
| dark | body text, minutes | onS on s | 14.33 : 1 | 4.5 : 1 | pass |
| dark | captions | onSv on s | 10.88 : 1 | 4.5 : 1 | pass |
| dark | ring button label | onP on p | 7.68 : 1 | 4.5 : 1 | pass |
| dark | done ring label, check | onSv on sHigh | 8.48 : 1 | 4.5 : 1 | pass |
| dark | Keep going text button | p on s | 10.86 : 1 | 4.5 : 1 | pass |
| dark | review chip | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| dark | new chip | onP on p | 7.68 : 1 | 4.5 : 1 | pass |
| dark | new chip at 0 min, text | onSv on s | 10.88 : 1 | 4.5 : 1 | pass |
| dark | new chip at 0 min, outline | ol on s | 5.84 : 1 | 3 : 1 | pass |
| dark | hint on the due card | onPc on pc | 7.21 : 1 | 4.5 : 1 | pass |
| dark | tile number | onS on sLowest | 14.98 : 1 | 4.5 : 1 | pass |
| dark | tile name | onSv on sLowest | 11.37 : 1 | 4.5 : 1 | pass |
| dark | tile pace arrow | onSv on sLowest | 11.37 : 1 | 3 : 1 | pass |
| dark | ring progress arc, active | p on s | 10.86 : 1 | 3 : 1 | pass |
| dark | ring progress arc, greyed (done) | olv on s | 1.98 : 1 | 3 : 1 | FAIL |
| dark | language pill | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| dark | streak card text | onS on sLow | 13.28 : 1 | 4.5 : 1 | pass |
| dark | streak card caption | onSv on sLow | 10.08 : 1 | 4.5 : 1 | pass |
| dark | quick revision (removed, struck) | onSv on sLow | 10.08 : 1 | 4.5 : 1 | pass |
| dark | session clock | onS on s | 14.33 : 1 | 4.5 : 1 | pass |
| dark | wave and end dot | p on s | 10.86 : 1 | 3 : 1 | pass |
| dark | header icons (close, sound, report) | onSv on s | 10.88 : 1 | 3 : 1 | pass |
| dark | drill card text | onS on sLow | 13.28 : 1 | 4.5 : 1 | pass |
| dark | drill card reading, question | onSv on sLow | 10.08 : 1 | 4.5 : 1 | pass |
| dark | answer option | onS on sLowest | 14.98 : 1 | 4.5 : 1 | pass |
| dark | change tag | onE on E | 7.72 : 1 | 4.5 : 1 | pass |
| dark | change outline on page | E on s | 10.89 : 1 | 3 : 1 | pass |
| dark | tile icon rec | #D6E3FF on #284777 | 7.22 : 1 | 3 : 1 | pass |
| dark | tile icon hear | #EADDFF on #4F378B | 7.23 : 1 | 3 : 1 | pass |
| dark | tile icon say | #BDF0B3 on #255023 | 7.23 : 1 | 3 : 1 | pass |
| dark | tile icon write | #FFDCC2 on #6E3900 | 7.24 : 1 | 3 : 1 | pass |
| dark | tile icon gram | #B8F0E4 on #00504A | 7.4 : 1 | 3 : 1 | pass |

Also checked in Chromium (Playwright, 1000 px wide page): no page-level horizontal scroll, no JavaScript errors, the hint and the minutes line wrap at 1.4x without clipping, Telugu, Bengali and Devanagari render with Noto Sans.
