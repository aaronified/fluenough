# Hours per language: self-check, notes and open questions

Companion to `hours-per-language.html` (#227; owner, 2026-10-23: "mockup right away"). The page holds only the screens and their tweak controls, with what is new outlined in red. The checks, notes and questions are here. Nothing below is decided; every open choice is a tweak control on the page.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed (the tokens of the other mockups), light and dark, Hindustani and Bengali examples. All numbers are examples.

## What it replaces

The approved `session-result-and-hours.html` (2026-10-12) drew the hours as a third row of tiles on the old Progress, following a range chip (7 days, 30 days, All time). Progress was rebuilt in #760: there is no range chip now (the star is not ranged, the charts have a fixed 12 weeks), and the page is the language bar, the Words and Level tiles, the week card, the Mastery by skill star, Weakest tags and Leeches. This page redraws the hours for that layout. The 2026-10-12 page stays the spec until the owner approves this one.

## Screens

1. **Progress, one language.** The new element in the place chosen by the "Where" control: **A** a tile row (Hours spent, Hours left) right under Words and Level, in the same tiles; **B** a "Time" card under the week card; **C** the same card after the star.
2. **Progress, All languages.** The language bar's All button on: the figures are sums, with an "Hours by language" panel (a row each: spent and left).
3. **How it is counted** (a bottom sheet from the figures), explaining the 60 s cap, the 21-day line and what is left out.

States: "Few answers (new learner)" shows the 20 s default (plan: until 20 answers in a skill) with a one-line note.

## Open questions for the owner

1. **What "hours left" counts.** The plan says the hours to the end of B1; the owner's 2026-10-10 comment on #227 says only the decks written so far (the Decks course card is built that way: "Hours left in the decks so far"). Control "Hours left counts".
   - Decks so far: always true, but a small number for a new language, and it grows as decks are added. Downside: it reads as "almost done" while the course is mostly unwritten.
   - To the end of B1: the real distance. Downside: it needs an estimate for units without decks (drawn as the average of the units that have them), so it is the least exact figure on the page.
2. **Where it sits.** Control "Where".
   - A, tile row: two big numbers, seen first, same look as Words and Level. Downside: it pushes the week card and star down by one row.
   - B, Time card under the week: groups time with practice. Downside: a third card style next to tiles and panels.
   - C, after the star: out of the way. Downside: below the fold on a phone, so few will see it.
3. **A range for hours spent.** Progress has no range now. Control "Hours spent shows".
   - All time only: simple. Downside: no sense of the recent pace.
   - All time and this week: adds "1.3 this week" under the figure. Downside: one more number, and "this week" is not the same as the week card's 7 days.
4. **All languages.** The panel with a row per language is drawn. Downside: it is one more block; without it the sum alone hides which language the hours went to. Say if the panel should go.
5. **Tap on the figures.** Opens "How it is counted" (drawn) or does nothing. Downside of the sheet: text to translate, and a tappable tile on a page where the tiles are not.
6. **From the plan, still open:** whether teach cards are timed (they record nothing today, so their time is not in the hours; downside of timing them: a separate log, since a review row needs a grade), whether "remembered" is 21 days, and whether hours should appear anywhere else (the Decks tab's course card already has them).
7. **A language with no decks.** Drawn in the notes only: "–" for hours left, as on the Decks card. Say if it should hide the element instead.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) in Chromium, both themes. Text 4.5:1, icons, outlines and chart fills 3:1. All  pairs pass.

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text | onS on s | 16.33 :1 | 4.5 :1 | pass |
| light | captions, readings | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | text on cards | onS on sLow | 15.5 :1 | 4.5 :1 | pass |
| light | captions on cards | onSv on sLow | 8.45 :1 | 4.5 :1 | pass |
| light | text on raised blocks | onS on sHigh | 14.01 :1 | 4.5 :1 | pass |
| light | captions on raised blocks | onSv on sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | tonal button, selected pill | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | filled button | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | link and icon on cards | p on sLow | 5.85 :1 | 4.5 :1 | pass |
| light | leech text | onTC on tC | 7.24 :1 | 4.5 :1 | pass |
| light | star outline, bar fill on card | tC2 on sLow | 5.81 :1 | 3 :1 | pass |
| light | bar fill on track | tC2 on sHigh | 5.25 :1 | 3 :1 | pass |
| light | filled star shape on card | p on sLow | 5.85 :1 | 3 :1 | pass |
| light | flame on card | fire on sLow | 5.48 :1 | 3 :1 | pass |
| light | outline against page | ol on s | 4.28 :1 | 3 :1 | pass |
| light | change tag | onE on E | 6.46 :1 | 4.5 :1 | pass |
| light | change outline on page | E on s | 6.16 :1 | 3 :1 | pass |
| light | change outline on card | E on sLow | 5.85 :1 | 3 :1 | pass |
| dark | body text | onS on s | 14.33 :1 | 4.5 :1 | pass |
| dark | captions, readings | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | text on cards | onS on sLow | 13.28 :1 | 4.5 :1 | pass |
| dark | captions on cards | onSv on sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | text on raised blocks | onS on sHigh | 11.17 :1 | 4.5 :1 | pass |
| dark | captions on raised blocks | onSv on sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | tonal button, selected pill | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | filled button | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | link and icon on cards | p on sLow | 10.05 :1 | 4.5 :1 | pass |
| dark | leech text | onTC on tC | 7.24 :1 | 4.5 :1 | pass |
| dark | star outline, bar fill on card | tC2 on sLow | 10.1 :1 | 3 :1 | pass |
| dark | bar fill on track | tC2 on sHigh | 8.5 :1 | 3 :1 | pass |
| dark | filled star shape on card | p on sLow | 10.05 :1 | 3 :1 | pass |
| dark | flame on card | fire on sLow | 10.04 :1 | 3 :1 | pass |
| dark | outline against page | ol on s | 5.84 :1 | 3 :1 | pass |
| dark | change tag | onE on E | 7.72 :1 | 4.5 :1 | pass |
| dark | change outline on page | E on s | 10.89 :1 | 3 :1 | pass |
| dark | change outline on card | E on sLow | 10.09 :1 | 3 :1 | pass |

## 1.4x fit

- Every size on the phones is `calc(N px * 1.4)`. Checked in Chromium at 1280 px wide: no page error, no console error, no horizontal page scroll, and no element past its phone's edge, with every tweak control pressed in both courses and both themes.
- The Words tile's "/ 540 taught" shrinks as the built tile does (it scales down to one line), so the page draws it at 24 and 12 dp x 1.4.
- "Hours left" is two lines at 1.4x: the figure with a small "About" before it, and "in the decks so far" below, which wraps to two lines in a half-width tile. The label is not clipped. "About" is a separate word so the figure keeps its room (the 2026-10-12 page used the same device).
- The language bar is drawn simplified (the All button, the selected pill and two faded neighbours, the report button). It is the built wheel; only the position of the new element matters here.

## Notes

- Hours spent: the sum of each answer's time, capped at 60 s, to one decimal, per language, for the language the bar shows (every language with All on).
- Hours left: as in `Plan-Hours-Per-Language`: for each card and skill not yet remembered, the reviews it still needs times the learner's median time per answer in that skill, divided by 3,600; rounded up to whole hours on the tile, "About" before it.
- Screen reader labels, proposed: "12.4 hours spent in all" and "About 140 hours left in the decks so far".
- Fonts: Roboto, Noto Sans Devanagari and Noto Sans Bengali from Google Fonts.
