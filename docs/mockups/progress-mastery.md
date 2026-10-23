# Progress mastery: self-check, notes and open questions

Companion to `progress-mastery.html` (#678). The page holds only the screens and their tweak controls, with what is new or changed outlined in red. The checks and notes are here. Nothing marked open is decided; every open choice is a tweak control on the page.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, Hindustani in light and Bengali in dark. Numbers are plausible, not real.

## What the page shows, from the owner's decisions

- **Words** (2026-10-20): a number, not a skill. Mastered in bold, taught lighter, like **312** / 540.
- **The star** (2026-10-20, 2026-10-23): six axes (grammar, script, read, write, hear, say). Filled shape: known ÷ B1 total, whose area is overall mastery. New: an outline with no fill, known ÷ taught on the same axes. "Known" means recall of at least 90% at the last review (#680, 2026-10-23). Taught is never more than the B1 total, so the outline is always on or outside the filled shape; they meet where a skill is fully taught (Hindustani's script). A skill with nothing taught has no known ÷ taught, so its outline point is at the centre (Bengali's Say, labelled `0% · –`). On open both shapes grow from the centre together, once, in 400 ms (2026-10-21), and stay still; no motion with reduced motion. Each axis reads "filled · outline".
- **Line chart** (2026-10-20): known ÷ taught per week for words, phrases, script and grammar, 12 weeks. Unchanged.
- **Weakest tags, leeches and calendar** (2026-10-23: "we need the weak tags, leeches, and calendar as well."), kept from today's tab (`lib/features/stats/stats_page.dart`): Weakest tags is a panel of bars in the tertiary colour with the "All tags ›" button (#720); Leeches is the row that opens the Leeches page, in the error container when there are leeches (Hindustani: 4) and a plain card with none (Bengali); the calendar is `ReviewHeatmap`, 12 weeks, a column per week, oldest first, today outlined, five shades, Fewer and More, with the streaks. The page marks them "added" because they are new to this mockup, not to the app. Section order under the chart is open (below).

## Open questions (not decided; each a tweak control)

1. **Section order** under the line chart. Calendar, tags, leeches (today's order of those three; the default shown), tags, leeches, calendar, or tags, calendar, leeches. Control "Section order".
2. **Outline style.** Solid or dashed. Dashed lets the filled shape's edge show through where they meet. Control "Outline style".
3. **Outline colour.** A contrast hue (the line chart's blue) or the text colour. Control "Outline colour".
4. **Streaks.** Two tiles above the grid (today's tab shows one tile, longest streak for All, day streak otherwise) or one line under it. Control "Streaks".
5. **Not owner-decided, shown as drawn:** each axis reads "filled · outline" under its name; the legend sentence on the outline rule; the 12-week window and 0 to 100% fixed axis of the line chart; the leeches row's count only (no example cards).
6. The Words, star and line chart come first in that order (as approved before); is that still right, or should the calendar and streaks lead as on today's tab?

## Not mocked

Other states (All languages, a new course with no data, the achievements grid #323, the share image #411), right-to-left, the tab icons' exact glyphs. Readings in decks stay based on ISO 15919, though none show here. The star's axis labels are English; Hindi and Bengali appear in the language pill (the course names and tags are English, as in the app).

## Self-check results

WCAG contrast computed in the page's JS (`window.__check`, console only) and run in Chromium for both themes. Text 4.5:1, icons and lines 3:1. The page was also checked at 360 px wide: no sideways scroll. The data rule (outline at or outside the fill; centre only where nothing is taught) is asserted in the same script and holds for both courses. The outline's two colour options are each checked on the card and on the filled star. The contrast-hue outline against the star's own green edge is near 1:1 by design of the palette: the shapes are told apart by position, the hollow markers and, with the dashed option, the dash, so colour is not the only cue.

| Theme | Pair | Ratio | Needs | Result |
|---|---|---|---|---|
| light | text (onSurface) on card | 15.50 :1 | 4.5 :1 | pass |
| light | secondary text (onSurfaceVariant) on card | 8.45 :1 | 4.5 :1 | pass |
| light | All, off: onSurface at 64% on surface | 5.05 :1 | 4.5 :1 | pass |
| light | language pill: onSecondaryContainer on secondaryContainer | 7.25 :1 | 4.5 :1 | pass |
| light | selected nav label: onSurface on navigation bar | 14.69 :1 | 4.5 :1 | pass |
| light | unselected nav label: onSurfaceVariant on navigation bar | 8.01 :1 | 4.5 :1 | pass |
| light | selected nav icon on its pill | 7.25 :1 | 3 :1 | pass |
| light | bug report icon on surface | 8.90 :1 | 3 :1 | pass |
| light | star fill edge (primary) on card | 5.85 :1 | 3 :1 | pass |
| light | axis text (onSurface) on the filled star | 8.78 :1 | 4.5 :1 | pass |
| light | axis percentages (onSurfaceVariant) on card | 8.45 :1 | 4.5 :1 | pass |
| light | outline, contrast hue, on card | 5.84 :1 | 3 :1 | pass |
| light | outline, contrast hue, on the filled star | 3.31 :1 | 3 :1 | pass |
| light | outline, contrast hue, on the star edge (primary), informational: the two are told apart by hollow markers and, optionally, a dash | 1.00 :1 | 1 :1 | pass |
| light | outline, text colour, on card | 15.50 :1 | 3 :1 | pass |
| light | outline, text colour, on the filled star | 8.78 :1 | 3 :1 | pass |
| light | outline point (surface fill) vs ring, text colour | 16.33 :1 | 3 :1 | pass |
| light | line “Words” on card | 5.85 :1 | 3 :1 | pass |
| light | line “Phrases” on card | 5.84 :1 | 3 :1 | pass |
| light | line “Script” on card | 5.36 :1 | 3 :1 | pass |
| light | line “Grammar” on card | 5.81 :1 | 3 :1 | pass |
| light | weakest tags bar (tertiary) on its track (secondaryContainer) | 5.00 :1 | 3 :1 | pass |
| light | tag name and percent (onSurface) on card | 15.50 :1 | 4.5 :1 | pass |
| light | leeches, some: onErrorContainer on errorContainer | 13.26 :1 | 4.5 :1 | pass |
| light | leeches, none: onSurfaceVariant on card | 8.45 :1 | 4.5 :1 | pass |
| light | tile label (onSurfaceVariant) on tile (surfaceContainer) | 8.01 :1 | 4.5 :1 | pass |
| light | tile value (onSurface) on tile | 14.69 :1 | 4.5 :1 | pass |
| light | All tags button (primary) on card | 5.85 :1 | 4.5 :1 | pass |
| light | calendar: busiest day (primary) on card | 5.85 :1 | 3 :1 | pass |
| light | calendar: today outline (onSurface) on card | 15.50 :1 | 3 :1 | pass |
| light | calendar: no-review cell vs card, decorative | 1.17 :1 | 1 :1 | pass |
| dark | text (onSurface) on card | 13.28 :1 | 4.5 :1 | pass |
| dark | secondary text (onSurfaceVariant) on card | 10.08 :1 | 4.5 :1 | pass |
| dark | All, off: onSurface at 64% on surface | 6.41 :1 | 4.5 :1 | pass |
| dark | language pill: onSecondaryContainer on secondaryContainer | 7.25 :1 | 4.5 :1 | pass |
| dark | selected nav label: onSurface on navigation bar | 12.70 :1 | 4.5 :1 | pass |
| dark | unselected nav label: onSurfaceVariant on navigation bar | 9.64 :1 | 4.5 :1 | pass |
| dark | selected nav icon on its pill | 7.25 :1 | 3 :1 | pass |
| dark | bug report icon on surface | 10.88 :1 | 3 :1 | pass |
| dark | star fill edge (primary) on card | 10.05 :1 | 3 :1 | pass |
| dark | axis text (onSurface) on the filled star | 5.16 :1 | 4.5 :1 | pass |
| dark | axis percentages (onSurfaceVariant) on card | 10.08 :1 | 4.5 :1 | pass |
| dark | outline, contrast hue, on card | 9.51 :1 | 3 :1 | pass |
| dark | outline, contrast hue, on the filled star | 3.69 :1 | 3 :1 | pass |
| dark | outline, contrast hue, on the star edge (primary), informational: the two are told apart by hollow markers and, optionally, a dash | 1.06 :1 | 1 :1 | pass |
| dark | outline, text colour, on card | 13.28 :1 | 3 :1 | pass |
| dark | outline, text colour, on the filled star | 5.16 :1 | 3 :1 | pass |
| dark | outline point (surface fill) vs ring, text colour | 14.33 :1 | 3 :1 | pass |
| dark | line “Words” on card | 10.05 :1 | 3 :1 | pass |
| dark | line “Phrases” on card | 9.51 :1 | 3 :1 | pass |
| dark | line “Script” on card | 10.22 :1 | 3 :1 | pass |
| dark | line “Grammar” on card | 9.09 :1 | 3 :1 | pass |
| dark | weakest tags bar (tertiary) on its track (secondaryContainer) | 5.51 :1 | 3 :1 | pass |
| dark | tag name and percent (onSurface) on card | 13.28 :1 | 4.5 :1 | pass |
| dark | leeches, some: onErrorContainer on errorContainer | 7.24 :1 | 4.5 :1 | pass |
| dark | leeches, none: onSurfaceVariant on card | 10.08 :1 | 4.5 :1 | pass |
| dark | tile label (onSurfaceVariant) on tile (surfaceContainer) | 9.64 :1 | 4.5 :1 | pass |
| dark | tile value (onSurface) on tile | 12.70 :1 | 4.5 :1 | pass |
| dark | All tags button (primary) on card | 10.05 :1 | 4.5 :1 | pass |
| dark | calendar: busiest day (primary) on card | 10.05 :1 | 3 :1 | pass |
| dark | calendar: today outline (onSurface) on card | 13.28 :1 | 3 :1 | pass |
| dark | calendar: no-review cell vs card, decorative | 1.39 :1 | 1 :1 | pass |
