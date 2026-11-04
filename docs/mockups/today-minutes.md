# Today: review end, quota over, Keep going. Self-check, notes and open questions

Companion to `today-minutes.html` (owner spec of 2026-11-04). The page holds only the four screens and their tweak controls (language, theme, screen picker, highlight), with what is new, changed, unchanged or removed outlined in red. The checks and notes are here.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark, Telugu, Bengali and Hindustani examples (readings follow the course: no final a in Bengali; Telugu word-final anusvara as `ṁ`). Starting points: `lib/features/summary/summary_page.dart`, `lib/features/today/daily_card.dart` and `due_card.dart` (main after #1008), `lib/ui/widgets/drill_frame.dart` (`DrillHeader`, the clock) and `wave_progress.dart`. New CSS corners use the `--r-*` tokens (`AppRadii`; a circle is `--r-round`, a stadium button `--r-stadium`); no numeric radius.

## The four screens

1. **Review end screen** (`SummaryPage`, as built): the sunny tick, "You've completed {language} for today", a pill and "N right of M" per skill, the streak tile, "Next due: N cards tomorrow", then Done and the lesson button. New: **Keep going** (tonal, between Done and "Today's lesson"), its only home, and the **day's total** ("23 min today", Keep going time included). It is THE end screen (owner answers below). Quick revision has no place on it.
2. **Today, review not completed**: the ring "Continue", "8 of 15 min", and chips that show **what is left** of the budget: "5 min review" and "2 min new" (7 min left, split about 70 / 30; illustrative), counting down with the clock (near the end, "1 min review"). The old badge shape, no card counts (#1009). The empty-chip rule follows today's chips (the new chip is outlined and grey at 0, "0 min new" as "0 new" is today); the owner did not decide this one. The hint "Tap a skill to practise only that" with its info dot (always shown), the tiles with all pending cards (12, 24, 44, 22, 6, 31) and their pace arrows as today, no Quick revision (struck through and outlined "removed" under the streak card; the highlight control hides it), no Keep going.
3. **Today, daily quota over**: the ring is full and greyed, a tick, "Done for today" (the app's words), the day's total "23 min today" (above the 15 min goal; the ring stays full and greyed), no chips, no Keep going button. The ring presses and opens screen 1. The greyed arc now uses the `outline` token (see the self-check).
4. **In session after Keep going**: the drill's own `DrillHeader` (close, wave, clock, the word's sounds, report). The bar is full for the whole stretch and the clock counts up the time taken (`3:12`, the app's m:ss). A small **reference frame** shows the normal session: bar 35 percent, the time left counting down (`9:48`).

## The info dot on the hint (owner, 2026-11-04)

The hint line "Tap a skill to practise only that" ends in an info dot that shows how the skills are fitted to the learner. It reuses the app's existing pattern, `IpaInfoDot` (`lib/features/decks/ipa_info_dot.dart`): an `Icons.info_outline` `IconButton`, 20 dp icon, 48 dp target, the tooltip "Info" (the existing `hintInfo` string, one word; icon colour is the icon button default). Its screen-reader label is the new phrase "How skills are fitted to you".

**Tapped state: a short popover**, the app's convention for these dots: `showPronunciation` opens an `AlertDialog` (`_Popup` in `lib/features/drill/teach_card.dart`): a title, a small subtitle in on-surface-variant, a body that scrolls (`SingleChildScrollView` in a `Flexible`), and a "Close" text button; no link out, so none is drawn. Here: title "How you learn", the page's intro as the subtitle, and as the body only the current language's part of `HowYouLearnPage`: the legend (You, At the start), one row per fitted skill (pill, name, "A seen word you get right comes back in 12 days, not 9.", the track, the verdict chip, "About 118 reviews in the next 30 days, was 160") and the foot "Adjusted today, from 214 of your answers." The page's language heading appears only when several languages are shown, so a one-language popover has none; its privacy line is left on the page. Numbers are examples and differ for Telugu, Bengali and Hindustani. At 1.4x the body scrolls inside the dialog; nothing clips. The "Info dot tapped" control shows or hides this frame and the dot's pressed state with its tooltip.

## What the blank end screen is today (scrapped)

When a session ends or a finished day is opened with nothing to serve, the learner gets one of two near-empty screens: the drill's empty state ("Nothing to drill right now / Everything here is scheduled for later. New words come in lessons.", `drillEmptyTitle` and `drillEmptyBody` in `lib/features/drill/drill_page.dart`), and the summary's empty variant ("Session done / No cards answered.", `SummaryPage` with `result.total == 0`). Per the owner's answer the summary with Keep going replaces them as the end screen. (Build note: that means the summary must be built for a day with few or no answers in the log, with the by-skill rows left out, and Keep going always present.)

## Answered by the owner

- Keep going when nothing is due (owner, 2026-11-04): "If user keeps going, let them review closest to due cards and teach them new cards. Change the ratio as needed to not teaching too much and not reviewing too far into the future." Keep going always has something to serve and never says "nothing more due today". (Build note: this lifts #1008's rule that a card reviewed today is never a filler, for Keep going only.)
- Keep going's timer (owner, 2026-11-04): "When user keeps going, the timer bar will not show any timer, but the time taken. The progress bar will also be full." Drawn on screen 4; the clock reads `3:12`, the app's format (answered 2026-11-04).
- Ring tap on the finished day (owner, 2026-11-04): "the summary with keep going option is the end screen. the current blank end screen is to be scrapped". The greyed ring opens the summary, which carries Keep going.
- Keep going on Today (owner, 2026-11-04, answer "Summary only"): Keep going lives only on the summary. The text button under the finished-day ring is removed.
- Keep going on a normal day (owner, 2026-11-04, answer "No"): not shown, as drawn.
- Chips (owner, 2026-11-04, answer "What is left"): the chips show what is left of the budget and count down with the clock.
- Keep going's time (owner, 2026-11-04, answer "Add to the day's total"): added to the day's total on Today and on the next summary; the ring stays full and greyed. Drawn as "23 min today" on screens 1 and 3.
- Hint wording (owner, 2026-11-04): the line reads "Tap a skill to practise only that", always shown, with the info dot after it.
- Greyed done arc (owner, 2026-11-04): strengthen it to at least 3:1 in light and dark, still clearly greyed. Now the `outline` token, light 4.28 : 1, dark 5.84 : 1 (was 1.62 and 1.98 with outline variant).
- Info dot on the hint (owner, 2026-11-04): reuse the app's info dot, one-word tooltip, screen-reader label "How skills are fitted to you", showing how the skills are fitted; see the section above.
- Info dot: page or popover (owner, 2026-11-04): "Short popover: with only that language's part of the how to learn page". Drawn as the app's dialog, as above.
- No add-minutes arrows, no step control (owner, 2026-11-04: "they do not need to add minutes, they can keep going"). Not on the page.

## Open questions for the owner

None remain.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, icons and outlines 3:1. All pairs pass.

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
| light | ring progress arc, greyed (done) | ol on s | 4.28 : 1 | 3 : 1 | pass |
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
| light | summary title, score text, day total | onS on s | 16.33 : 1 | 4.5 : 1 | pass |
| light | summary tick | onTc on tc | 7.24 : 1 | 3 : 1 | pass |
| light | streak tile value | onS on sHigh | 14.01 : 1 | 4.5 : 1 | pass |
| light | streak tile label | onSv on sHigh | 7.64 : 1 | 4.5 : 1 | pass |
| light | Done button | onP on p | 6.46 : 1 | 4.5 : 1 | pass |
| light | Keep going and lesson buttons | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| light | info dot icon on due card | onSv on pc | 7.25 : 1 | 3 : 1 | pass |
| light | info dot pressed (16% of onPc) icon | onSv on pc | 7.25 : 1 | 3 : 1 | pass |
| light | page text | onS on sLow | 15.5 : 1 | 4.5 : 1 | pass |
| light | page captions, axis | onSv on sLow | 8.45 : 1 | 4.5 : 1 | pass |
| light | intro on page | onS on s | 16.33 : 1 | 4.5 : 1 | pass |
| light | legend | onSv on s | 8.9 : 1 | 4.5 : 1 | pass |
| light | seen verdict | onPc on pc | 7.21 : 1 | 4.5 : 1 | pass |
| light | slip verdict | onTc on tc | 7.24 : 1 | 4.5 : 1 | pass |
| light | track fill on track | p on sHighest | 5.01 : 1 | 3 : 1 | pass |
| light | start marker on track | onS on sHighest | 13.28 : 1 | 3 : 1 | pass |
| light | popover title, text | onS on sHigh | 14.01 : 1 | 4.5 : 1 | pass |
| light | popover subtitle | onSv on sHigh | 7.64 : 1 | 4.5 : 1 | pass |
| light | popover Close | p on sHigh | 5.29 : 1 | 4.5 : 1 | pass |
| light | popover rows text | onS on sLow | 15.5 : 1 | 4.5 : 1 | pass |
| light | same verdict chip | onSv on sHighest | 7.24 : 1 | 4.5 : 1 | pass |
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
| dark | ring progress arc, greyed (done) | ol on s | 5.84 : 1 | 3 : 1 | pass |
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
| dark | summary title, score text, day total | onS on s | 14.33 : 1 | 4.5 : 1 | pass |
| dark | summary tick | onTc on tc | 7.24 : 1 | 3 : 1 | pass |
| dark | streak tile value | onS on sHigh | 11.17 : 1 | 4.5 : 1 | pass |
| dark | streak tile label | onSv on sHigh | 8.48 : 1 | 4.5 : 1 | pass |
| dark | Done button | onP on p | 7.68 : 1 | 4.5 : 1 | pass |
| dark | Keep going and lesson buttons | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| dark | info dot icon on due card | onSv on pc | 5.46 : 1 | 3 : 1 | pass |
| dark | info dot pressed (16% of onPc) icon | onSv on pc | 5.46 : 1 | 3 : 1 | pass |
| dark | page text | onS on sLow | 13.28 : 1 | 4.5 : 1 | pass |
| dark | page captions, axis | onSv on sLow | 10.08 : 1 | 4.5 : 1 | pass |
| dark | intro on page | onS on s | 14.33 : 1 | 4.5 : 1 | pass |
| dark | legend | onSv on s | 10.88 : 1 | 4.5 : 1 | pass |
| dark | seen verdict | onPc on pc | 7.21 : 1 | 4.5 : 1 | pass |
| dark | slip verdict | onTc on tc | 7.24 : 1 | 4.5 : 1 | pass |
| dark | track fill on track | p on sHighest | 7.23 : 1 | 3 : 1 | pass |
| dark | start marker on track | onS on sHighest | 9.55 : 1 | 3 : 1 | pass |
| dark | popover title, text | onS on sHigh | 11.17 : 1 | 4.5 : 1 | pass |
| dark | popover subtitle | onSv on sHigh | 8.48 : 1 | 4.5 : 1 | pass |
| dark | popover Close | p on sHigh | 8.46 : 1 | 4.5 : 1 | pass |
| dark | popover rows text | onS on sLow | 13.28 : 1 | 4.5 : 1 | pass |
| dark | same verdict chip | onSv on sHighest | 7.25 : 1 | 4.5 : 1 | pass |
| dark | change tag | onE on E | 7.72 : 1 | 4.5 : 1 | pass |
| dark | change outline on page | E on s | 10.89 : 1 | 3 : 1 | pass |
| dark | tile icon rec | #D6E3FF on #284777 | 7.22 : 1 | 3 : 1 | pass |
| dark | tile icon hear | #EADDFF on #4F378B | 7.23 : 1 | 3 : 1 | pass |
| dark | tile icon say | #BDF0B3 on #255023 | 7.23 : 1 | 3 : 1 | pass |
| dark | tile icon write | #FFDCC2 on #6E3900 | 7.24 : 1 | 3 : 1 | pass |
| dark | tile icon gram | #B8F0E4 on #00504A | 7.4 : 1 | 3 : 1 | pass |

Also checked in Chromium (Playwright, a 2100 px wide page): no page-level horizontal scroll, no JavaScript errors, the title, hint, minutes, chips and buttons do not clip at 1.4x (the "Recognition" tile name is scaled to fit its tile, as the app's `FittedBox` does), Telugu, Bengali and Devanagari render with Noto Sans.
