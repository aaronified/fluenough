# Progress mastery: self-check, notes and open questions

Companion to `progress-mastery.html` (#678). The page holds only the screens and their tweak controls, with what is new or changed outlined in red. The checks and notes are here. Nothing marked open is decided; every open choice is a tweak control on the page.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, Hindustani in light and Bengali in dark. Numbers are plausible, not real.

## What the page shows, from the owner's decisions

- **Row 1** (2026-10-23, on f924c2b3: "Total words, and one strek tile will be the top row in the page"; later the same day, recorded on #678): the Words tile reads "Words mastered", then **312** / 540 taught on one line, with the type and spacing shrunk to fit at 1.4x text on a 360 px phone (checked in both courses and both themes, and also on a 328 px phone, the page at 360 px wide: no wrap, no overflow). The Streak tile shows the current streak for this course big, with the highest streak small under it ("best 21"). The tiles are 3:2 wide. (2026-10-20: "Words is not a skill. It is a number.")
- **Row 2** (same comment: "followed by a horizontal 7 day running calendar (no need for legends in the calendar, it will be a fire icon for meeting the quota, a filled dot for some practice, unfilled dot for missing conpletely, and double fire for 2x+ or more practice / learning."): the last 7 days, oldest first, today last, day initials under the marks, no legend. One mark a day: a flame, the daily quota (#485's minutes a day) met; two flames, 2x the quota or more (owner, 2026-10-23: two icons overlapping, slightly offset and stacked, not side by side, in the same footprint as the single flame); a filled dot, some practice under the quota; an unfilled dot, none. Each day is a labelled image for screen readers, such as "Tuesday: twice the quota or more, 34 of 15 minutes" (today's says "today"); the initials are hidden from them. Hindustani (quota 15 min) and Bengali (10 min) each show all the states. This replaces the 12-week heatmap and the two-tile streaks.
- **The star** (2026-10-20, 2026-10-23): six axes (grammar, script, read, write, hear, say). The **filled shape is a fill only, with no edge stroke** and no vertex dots: known / B1 total, whose area is overall mastery. The **outline is solid blue** (2026-10-23: "Solid, blue"), no fill: known / taught on the same axes, with hollow markers. The style and colour controls are gone. "Known" means recall of at least 90% at the last review (#680, 2026-10-23). The outline is never inside the fill, since taught is at most the B1 total; they meet where a skill is fully taught (Hindustani's script). A skill with nothing taught has its outline point at the centre (Bengali's Say, `0% · -`). On open both shapes grow from the centre together, once, in 400 ms (2026-10-21), then stay still; no motion with reduced motion. Each axis reads "filled · outline". **Nothing is written under the star**: no legend and no paragraph (owner, 2026-10-23, recorded on #678).
- **The star is tappable** (owner, 2026-10-23, recorded on #678): its card has an "Over time >" button in the title and is a button for screen readers ("Mastery by skill, overall 22%. Opens known over time").
- **Second screen, "Over time"** (owner, 2026-10-23: the line chart leaves the main page and the star opens it; later the same day, recorded on #678): a pushed screen with a back arrow and no tab bar, drawn for both courses beside the Progress screens. It has **two separate charts**, each with one line per skill (grammar, script, read, write, hear, say): "Mastery over time" (known / B1 total, ending at the star's filled values) and "Taught over time" (known / taught, ending at the outline's values; a skill with nothing taught stays at 0 and reads "-"). Each skill has its own colour, dash and marker (grammar blue, solid, circle; script amber, dashed, square; read green, dotted, diamond; write rose, dash-dot, triangle; hear purple, long dash, down triangle; say grey, short dash, hollow circle), with markers on the lines every third week and at now, and a legend of marker, name and current value under each chart, so colour is never the only cue.
- **Icons** (owner, 2026-10-23: "don't use emoji; use Tabler icons"): no emoji anywhere. The calendar's flame and the streak tile's flame are Tabler `flame`, the filled dot is Tabler `circle-filled` and the unfilled dot is Tabler `circle`, drawn as inline SVG paths, not a font or CDN, in the theme's colours (a fire colour for flames, primary for the filled dot, onSurfaceVariant for the ring). The two flames are two `flame` icons, the front one filled with the card colour so it stacks on the back one. The app has no Tabler package: `lib/ui/skill_visuals.dart` maps the design's Tabler icons onto Material ones, and the streak card already uses `Icons.local_fire_department_outlined`. The build does the same: flame is `local_fire_department_outlined`, circle-filled is `Icons.circle`, circle is `Icons.circle_outlined`; the two flames in Flutter are two of them in a `Stack`, offset.
- **Weakest tags and leeches** (2026-10-23: "we need the weak tags, leeches, and calendar as well."), kept from today's tab: Weakest tags is a panel of bars with the "All tags >" button (#720); Leeches is the row that opens the Leeches page, in the error container when there are leeches (Hindustani: 4) and a plain card with none (Bengali). The calendar is the 7-day row above.
- **Page order:** Words and Streak, the 7-day calendar, the star, weakest tags, leeches.

## Open questions

1. **Section order** of the star, weakest tags and leeches (the one tweak control): star, tags, leeches (shown by default); star, leeches, tags; or tags, leeches, star.
2. **Streak for All languages.** The tile shows this course's current and best streak; whether All languages sums or takes the longest is not decided.
3. **Not owner-decided, shown as drawn:** a day with any minutes is a filled dot, minutes at or above the quota is a fire and at or above twice the quota a double fire, learning and practice both counting towards the minutes; the quota shown is the course's from #485; weekday initials are English letters; "Over time >" as the star's tap hint; the second screen's 12-week window, 0 to 100% axis, the six line colours, dashes and markers, the weekly curves (made-up numbers) and lack of a tab bar; "best" counted over the whole course; the axes reading "filled · outline" with nothing to explain them on the page; the leeches row's count only.

## Not mocked

Other states (All languages, a new course with no data, a day with no quota set, the achievements grid #323, the share image #411), right-to-left, the tab icons' exact glyphs, the transition into the second screen. Readings in decks stay based on ISO 15919, though none show here. The star's axis labels are English; Hindi and Bengali appear in the language pill (the course names and tags are English, as in the app).

## Self-check results

WCAG contrast computed in the page's JS (`window.__check`, console only) and run in Chromium in both themes. Text 4.5:1, icons and lines 3:1. At 360 px wide the page has no sideways scroll. Two data rules are asserted in the same script and hold for both courses: the outline is never inside the fill (at the centre only where nothing is taught), and the calendar shows at least three of the four states, one state a day. The second screen's six line colours are each checked on the card in both themes (3:1 or more). The solid blue outline is checked against the card and against the filled star (3:1 or more in both themes). The star's fill, now without an edge, is only about 1.8 to 2.6:1 against the card: the fill is informational, with the exact values written as the axis percentages and the outline's markers giving the edge; this is flagged for the owner. The calendar's marks differ by shape (flame, two flames, filled dot, ring), and the chart's lines by dash and marker, not colour alone. The Words and Streak tiles' one-line fit is measured in Chromium, not by contrast.

| Theme | Pair | Ratio | Needs | Result |
|---|---|---|---|---|
| light | text (onSurface) on card | 15.50 :1 | 4.5 :1 | pass |
| light | secondary text (onSurfaceVariant) on card | 8.45 :1 | 4.5 :1 | pass |
| light | All, off: onSurface at 64% on surface | 5.05 :1 | 4.5 :1 | pass |
| light | language pill: onSecondaryContainer on secondaryContainer | 7.25 :1 | 4.5 :1 | pass |
| light | selected nav label: onSurface on navigation bar | 14.69 :1 | 4.5 :1 | pass |
| light | unselected nav label: onSurfaceVariant on navigation bar | 8.01 :1 | 4.5 :1 | pass |
| light | selected nav icon on its pill | 7.25 :1 | 3 :1 | pass |
| light | Over time chevron (primary) on card | 5.85 :1 | 3 :1 | pass |
| light | back arrow on surface | 8.90 :1 | 3 :1 | pass |
| light | bug report icon on surface | 8.90 :1 | 3 :1 | pass |
| light | star fill (primary at 38%) vs card, informational: the fill has no edge, the exact values are the axis percentages and the markers | 1.77 :1 | 1 :1 | pass |
| light | axis text (onSurface) on the filled star | 8.78 :1 | 4.5 :1 | pass |
| light | axis percentages (onSurfaceVariant) on card | 8.45 :1 | 4.5 :1 | pass |
| light | outline (solid blue) on card | 5.84 :1 | 3 :1 | pass |
| light | outline (solid blue) on the filled star | 3.31 :1 | 3 :1 | pass |
| light | outline point (surface fill) vs blue ring | 6.16 :1 | 3 :1 | pass |
| light | chart line “Grammar” (k1) on card | 5.84 :1 | 3 :1 | pass |
| light | chart line “Script” (k2) on card | 5.36 :1 | 3 :1 | pass |
| light | chart line “Read” (k3) on card | 5.85 :1 | 3 :1 | pass |
| light | chart line “Write” (k4) on card | 5.81 :1 | 3 :1 | pass |
| light | chart line “Hear” (k5) on card | 6.08 :1 | 3 :1 | pass |
| light | chart line “Say” (k6) on card | 5.79 :1 | 3 :1 | pass |
| light | best streak and legend text (onSurfaceVariant) on card | 8.45 :1 | 4.5 :1 | pass |
| light | weakest tags bar (tertiary) on its track (secondaryContainer) | 5.00 :1 | 3 :1 | pass |
| light | tag name and percent (onSurface) on card | 15.50 :1 | 4.5 :1 | pass |
| light | leeches, some: onErrorContainer on errorContainer | 13.26 :1 | 4.5 :1 | pass |
| light | leeches, none: onSurfaceVariant on card | 8.45 :1 | 4.5 :1 | pass |
| light | Words and Streak labels (onSurfaceVariant) on card | 8.45 :1 | 4.5 :1 | pass |
| light | Words and Streak values (onSurface) on card | 15.50 :1 | 4.5 :1 | pass |
| light | All tags button (primary) on card | 5.85 :1 | 4.5 :1 | pass |
| light | streak and calendar fire icon on card | 5.48 :1 | 3 :1 | pass |
| light | calendar filled dot (primary) on card | 5.85 :1 | 3 :1 | pass |
| light | calendar unfilled dot ring (onSurfaceVariant) on card | 8.45 :1 | 3 :1 | pass |
| light | calendar day initials (onSurfaceVariant) on card | 8.45 :1 | 4.5 :1 | pass |
| light | calendar today initial (onSurface) on card | 15.50 :1 | 4.5 :1 | pass |
| dark | text (onSurface) on card | 13.28 :1 | 4.5 :1 | pass |
| dark | secondary text (onSurfaceVariant) on card | 10.08 :1 | 4.5 :1 | pass |
| dark | All, off: onSurface at 64% on surface | 6.41 :1 | 4.5 :1 | pass |
| dark | language pill: onSecondaryContainer on secondaryContainer | 7.25 :1 | 4.5 :1 | pass |
| dark | selected nav label: onSurface on navigation bar | 12.70 :1 | 4.5 :1 | pass |
| dark | unselected nav label: onSurfaceVariant on navigation bar | 9.64 :1 | 4.5 :1 | pass |
| dark | selected nav icon on its pill | 7.25 :1 | 3 :1 | pass |
| dark | Over time chevron (primary) on card | 10.05 :1 | 3 :1 | pass |
| dark | back arrow on surface | 10.88 :1 | 3 :1 | pass |
| dark | bug report icon on surface | 10.88 :1 | 3 :1 | pass |
| dark | star fill (primary at 38%) vs card, informational: the fill has no edge, the exact values are the axis percentages and the markers | 2.57 :1 | 1 :1 | pass |
| dark | axis text (onSurface) on the filled star | 5.16 :1 | 4.5 :1 | pass |
| dark | axis percentages (onSurfaceVariant) on card | 10.08 :1 | 4.5 :1 | pass |
| dark | outline (solid blue) on card | 9.51 :1 | 3 :1 | pass |
| dark | outline (solid blue) on the filled star | 3.69 :1 | 3 :1 | pass |
| dark | outline point (surface fill) vs blue ring | 10.27 :1 | 3 :1 | pass |
| dark | chart line “Grammar” (k1) on card | 9.51 :1 | 3 :1 | pass |
| dark | chart line “Script” (k2) on card | 10.22 :1 | 3 :1 | pass |
| dark | chart line “Read” (k3) on card | 10.05 :1 | 3 :1 | pass |
| dark | chart line “Write” (k4) on card | 9.09 :1 | 3 :1 | pass |
| dark | chart line “Hear” (k5) on card | 8.93 :1 | 3 :1 | pass |
| dark | chart line “Say” (k6) on card | 9.28 :1 | 3 :1 | pass |
| dark | best streak and legend text (onSurfaceVariant) on card | 10.08 :1 | 4.5 :1 | pass |
| dark | weakest tags bar (tertiary) on its track (secondaryContainer) | 5.51 :1 | 3 :1 | pass |
| dark | tag name and percent (onSurface) on card | 13.28 :1 | 4.5 :1 | pass |
| dark | leeches, some: onErrorContainer on errorContainer | 7.24 :1 | 4.5 :1 | pass |
| dark | leeches, none: onSurfaceVariant on card | 10.08 :1 | 4.5 :1 | pass |
| dark | Words and Streak labels (onSurfaceVariant) on card | 10.08 :1 | 4.5 :1 | pass |
| dark | Words and Streak values (onSurface) on card | 13.28 :1 | 4.5 :1 | pass |
| dark | All tags button (primary) on card | 10.05 :1 | 4.5 :1 | pass |
| dark | streak and calendar fire icon on card | 10.04 :1 | 3 :1 | pass |
| dark | calendar filled dot (primary) on card | 10.05 :1 | 3 :1 | pass |
| dark | calendar unfilled dot ring (onSurfaceVariant) on card | 10.08 :1 | 3 :1 | pass |
| dark | calendar day initials (onSurfaceVariant) on card | 10.08 :1 | 4.5 :1 | pass |
| dark | calendar today initial (onSurface) on card | 13.28 :1 | 4.5 :1 | pass |
