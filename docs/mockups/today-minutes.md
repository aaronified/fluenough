# Today: review end, quota over, Keep going. Self-check, notes and open questions

Companion to `today-minutes.html` (owner spec of 2026-11-04). The page holds only the four screens and their tweak controls (language, theme, screen picker, hint wording, highlight), with what is new, changed, unchanged or removed outlined in red. The checks and notes are here.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark, Telugu, Bengali and Hindustani examples (readings follow the course: no final a in Bengali; Telugu word-final anusvara as `ṁ`). Starting points: `lib/features/summary/summary_page.dart`, `lib/features/today/daily_card.dart` and `due_card.dart` (main after #1008), `lib/ui/widgets/drill_frame.dart` (`DrillHeader`, the clock) and `wave_progress.dart`. New CSS corners use the `--r-*` tokens (`AppRadii`; a circle is `--r-round`, a stadium button `--r-stadium`); no numeric radius.

## The four screens

1. **Review end screen** (`SummaryPage`, as built): the sunny tick, "You've completed {language} for today", a pill and "N right of M" per skill, the streak tile, "Next due: N cards tomorrow", then Done, and the lesson button. New: a **Keep going** button (tonal, between Done and "Today's lesson"). It is THE end screen (owner answer below). Quick revision has no place on it.
2. **Today, review not completed**: the ring "Continue", "8 of 15 min", minutes budgeted in the chips ("12 min review", "3 min new": the day's whole budget, an 80 / 20 split drawn; the old badge shape; no card counts, #1009), the hint above the skill tiles ("Tap a skill to practise only that skill"; it wraps to two lines at 1.4x, nothing clips; a shorter wording is a tweak), the tiles with all pending cards (12, 24, 44, 22, 6, 31: more than 15 min buys) and their pace arrows as today, no Quick revision (shown struck through and outlined "removed" under the streak card; the highlight control hides it).
3. **Today, daily quota over**: the ring is greyed, a tick, "Done for today" (the app's words), "15 of 15 min", no chips, and still presses: it opens screen 1 (#1007, #1008). The Keep going text button under the ring is as built today (`plan.canKeepGoing`: shown once the budget is spent) and is outlined "unchanged". Tiles and hint as on screen 2.
4. **In session after Keep going**: the drill's own `DrillHeader` (close, wave, clock, the word's sounds, report). The bar is full for the whole stretch and the clock counts up the time taken (`3:12`), not down. A small **reference frame** below shows the normal session: bar 35 percent, the time left counting down (`9:48`).

## What the blank end screen is today (scrapped)

When a session ends or a finished day is opened with nothing to serve, the learner gets one of two near-empty screens: the drill's empty state ("Nothing to drill right now / Everything here is scheduled for later. New words come in lessons.", `drillEmptyTitle` and `drillEmptyBody` in `lib/features/drill/drill_page.dart`), and the summary's empty variant ("Session done / No cards answered.", `SummaryPage` with `result.total == 0`). Per the owner's answer the summary with Keep going replaces them as the end screen. (Build note: that means the summary must be built for a day with few or no answers in the log, with the by-skill rows left out, and Keep going always present.)

## Answered by the owner

- Keep going when nothing is due (owner, 2026-11-04): "If user keeps going, let them review closest to due cards and teach them new cards. Change the ratio as needed to not teaching too much and not reviewing too far into the future." Keep going always has something to serve and never says "nothing more due today". (Build note: this lifts #1008's rule that a card reviewed today is never a filler, for Keep going only.)
- Keep going's timer (owner, 2026-11-04): "When user keeps going, the timer bar will not show any timer, but the time taken. The progress bar will also be full." Drawn on screen 4.
- Ring tap on the finished day (owner, 2026-11-04): "the summary with keep going option is the end screen. the current blank end screen is to be scrapped". The greyed ring opens the summary (screens 3 to 1), and the summary carries Keep going.
- No add-minutes arrows, no step control (owner, 2026-11-04: "they do not need to add minutes, they can keep going"). Not on the page.

## Open questions for the owner

1. Keep going on Today: it exists there today (under the ring once the day is done) and now also on the summary. Keep it on both, or only on the summary, so the finished-day ring is the single way on? Drawn: kept on both, as built.
2. Keep going on a normal day (before the budget is spent): the brief once asked for it all day. Drawn: not shown, as today, because the ring's "Continue" already does that. Show it anyway?
3. Chips: the whole day's budget (12 and 3 of 15), or what is left of it? Drawn: the whole budget, so they do not move as the learner answers. And what is the planner's real split; should a day with no new words show "0 min new" outlined, as "0 new" is today?
4. After Keep going starts, the time taken: added to the day's total on Today and on the next summary, or kept apart? Does Today's ring then stay full and greyed?
5. The clock when counting up: `3:12` (the app's m:ss, drawn) or `03:12`? Past an hour it would read `62:10`.
6. The hint's wording and place (inside the Due now card, above the tiles): this line or the shorter "Tap a skill to practise it alone"? Should it go once the learner has tapped a tile a few times?
7. The greyed ring's arc fails 3:1 (self-check below). It is #1008's design (outline variant on the page), and "15 of 15 min" says the same in text. Make the done arc stronger?

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
| light | summary title, score text | onS on s | 16.33 : 1 | 4.5 : 1 | pass |
| light | summary tick | onTc on tc | 7.24 : 1 | 3 : 1 | pass |
| light | streak tile value | onS on sHigh | 14.01 : 1 | 4.5 : 1 | pass |
| light | streak tile label | onSv on sHigh | 7.64 : 1 | 4.5 : 1 | pass |
| light | Done button | onP on p | 6.46 : 1 | 4.5 : 1 | pass |
| light | Keep going and lesson buttons | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
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
| dark | summary title, score text | onS on s | 14.33 : 1 | 4.5 : 1 | pass |
| dark | summary tick | onTc on tc | 7.24 : 1 | 3 : 1 | pass |
| dark | streak tile value | onS on sHigh | 11.17 : 1 | 4.5 : 1 | pass |
| dark | streak tile label | onSv on sHigh | 8.48 : 1 | 4.5 : 1 | pass |
| dark | Done button | onP on p | 7.68 : 1 | 4.5 : 1 | pass |
| dark | Keep going and lesson buttons | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| dark | change tag | onE on E | 7.72 : 1 | 4.5 : 1 | pass |
| dark | change outline on page | E on s | 10.89 : 1 | 3 : 1 | pass |
| dark | tile icon rec | #D6E3FF on #284777 | 7.22 : 1 | 3 : 1 | pass |
| dark | tile icon hear | #EADDFF on #4F378B | 7.23 : 1 | 3 : 1 | pass |
| dark | tile icon say | #BDF0B3 on #255023 | 7.23 : 1 | 3 : 1 | pass |
| dark | tile icon write | #FFDCC2 on #6E3900 | 7.24 : 1 | 3 : 1 | pass |
| dark | tile icon gram | #B8F0E4 on #00504A | 7.4 : 1 | 3 : 1 | pass |

Also checked in Chromium (Playwright, a 2100 px wide page): no page-level horizontal scroll, no JavaScript errors, the title, hint, minutes, chips and buttons do not clip at 1.4x (the "Recognition" tile name is scaled to fit its tile, as the app's `FittedBox` does), Telugu, Bengali and Devanagari render with Noto Sans.
