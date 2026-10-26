# Progress: self-check, notes and open questions

Companion to `progress.html` (owner, 2026-10-26: "Redesign the progress screen. The overall structure is fine, just think on the colours, accents, etc. Each skill should have one colour associated with it always (maybe use the home icon colours). The skills will always be written in that colour (also helps differentiate between Say skill and the verb say). Also, the tiles need better designs. Show me a mockup."). The page holds only the screens and their tweak controls, with what changed outlined. Nothing below is decided.

Phone 360 dp at 1.4x text (#505). Colours are `ColorScheme.fromSeed` of the clay seed (the owner's phone) and the forest seed (the default), generated with `material_color_utilities`; light and dark. Theme, course and highlight are global controls. Progress has little deck text, so the Hindustani and Bengali examples are the language chip's glyph (ह, ব), the course names and the numbers, which are made up. Today's screen is drawn from the owner's screenshot (Telugu there).

## What the proposal changes

1. **One colour per skill, always.** The six skills use the colours of the Today tile icons, which are the existing `ModeColors`: Read blue, Write orange, Hear purple, Say green, Grammar teal, Script pink (or yellow, a tweak). The skill's name is written in its colour wherever it appears, with its icon. On a light theme the ink is the dark set's container (`#284777` for Read); on a dark theme it is the dark set's `onContainer` (`#d6e3ff`). Both are values the app already has, so no new colours.
2. **Mastery by skill:** the radar labels carry the skill icon and colour, and each corner's dot is the skill's colour; the area stays the theme's primary. A **Bars** variant gives each skill a row of its own colour. The numbers are unchanged.
3. **Count tiles (Words, Rules, Sentences):** an icon chip, a bar of how much of what is taught is known, then the figure and "known of N taught" as today. *One accent* is neutral tiles with the primary bar; *Three accents* uses the seed's primary, secondary and tertiary containers.
4. **Level** is the one filled tile (primary container), with a trophy, "Not yet" and the A1, A2, B1 ladder with the current level filled once reached, and the start date.
5. **This week** gets a title and "5 of 7 days" (the dots are unchanged).
6. **Hours spent and Hours left** get icons; "About" stays small, the number big.
7. **No leeches** shows a check, not a warning triangle, when there are none.
8. Weakest tags is unchanged but for the heading sizes matching the other cards.

## Open questions

1. **Script's colour.** It has no `ModeColors` entry; today its tile follows the seed. Pink is the match-pairs set (a drill mode, not a skill) and yellow is the reading set (Reading is a skill not shown on Progress yet). Pink now, and yellow reserved for Reading, avoids a clash later. The page has both.
2. **Skill names elsewhere.** The same ink would apply to every place a skill is named (Over time, the drill's skill chip, Settings > skills). Out of scope for this page; stated here so that it is built once, as a helper.
3. **Radar or bars.** The owner said the structure is fine, so Radar is the default; Bars reads better at 1.4x and lists all six without crowded corners, and costs a taller card.
4. **Count tiles: one accent or three.** Three adds colour but those colours are the seed's, so they change with the theme, while skill colours never do. That is a reason for One accent, so that only the skills carry colour.
5. **"First number · second number"** under each skill is unchanged and still unexplained on the screen (taught share and known share, as built); worth a caption later, not part of this.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) for clay and forest, light and dark, and run in Chromium. Text 4.5:1, icons and bars 3:1. The lowest ratio across the 4 theme and seed combinations is shown; all 144 pairs pass. The skill rows are the worst of 28 each (7 inks, including both Script choices, on 4 themes).

| Pair | Lowest | Needs | Combinations | Result |
|---|---|---|---|---|
| body text on page | 14.33 : 1 | 4.5 : 1 | 4 | pass |
| secondary text on card | 8.45 : 1 | 4.5 : 1 | 4 | pass |
| secondary text on tile | 7.63 : 1 | 4.5 : 1 | 4 | pass |
| tile text on tile | 11.13 : 1 | 4.5 : 1 | 4 | pass |
| Level text on primary container | 7.21 : 1 | 4.5 : 1 | 4 | pass |
| count text on secondary container | 7.23 : 1 | 4.5 : 1 | 4 | pass |
| count text on tertiary container | 7.24 : 1 | 4.5 : 1 | 4 | pass |
| Level icon on its disc | 6.45 : 1 | 3 : 1 | 4 | pass |
| chip icon on primary container | 7.21 : 1 | 3 : 1 | 4 | pass |
| chip icon on secondary container | 7.23 : 1 | 3 : 1 | 4 | pass |
| link text on card | 5.85 : 1 | 4.5 : 1 | 4 | pass |
| count bar on its track | 5.01 : 1 | 3 : 1 | 4 | pass |
| tag bar on its track | 5.01 : 1 | 3 : 1 | 4 | pass |
| week dot on card | 5.85 : 1 | 3 : 1 | 4 | pass |
| week empty ring on card | 4.06 : 1 | 3 : 1 | 4 | pass |
| skill name on card | 8.17 : 1 | 4.5 : 1 | 28 | pass |
| skill name on page | 8.61 : 1 | 4.5 : 1 | 28 | pass |
| skill bar on its track | 7.00 : 1 | 3 : 1 | 28 | pass |

Checked in Chromium at 1.4x, light and dark, Hindustani and Bengali, radar and bars: no page errors, no overflow. Not checked: other text sizes (the app caps at 1.4x), the high-contrast and pure-black themes, and a real phone.
