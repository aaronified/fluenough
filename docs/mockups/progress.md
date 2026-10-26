# Progress: self-check, notes and open questions

Companion to `progress.html` (owner, 2026-10-26: "Redesign the progress screen. The overall structure is fine, just think on the colours, accents, etc. Each skill should have one colour associated with it always (maybe use the home icon colours). The skills will always be written in that colour (also helps differentiate between Say skill and the verb say). Also, the tiles need better designs. Show me a mockup."). The page holds only the screens and their tweak controls, with what changed outlined. Nothing below is decided.

Phone 360 dp at 1.4x text (#505). Colours are `ColorScheme.fromSeed` of the clay seed (the owner's phone) and the forest seed (the default), generated with `material_color_utilities`; light and dark. Theme, course and highlight are global controls. Progress has little deck text, so the Hindustani and Bengali examples are the language chip's glyph (ह, ব), the course names and the numbers, which are made up. Today's screen is drawn from the owner's screenshot (Telugu there).

## What the proposal changes

1. **One colour per skill, the same in every theme** (owner, 2026-10-26: "The skill colours must not change with theme"). The six skills use the hues of the Today tile icons: Read blue, Write orange, Hear purple, Say green, Grammar teal, Script pink (or yellow, a tweak). Each is one fixed colour, the same on light and dark and on every seed: the pill's hue at HCT tone 53 and chroma 56 (`#2f80d9`, `#c06800`, `#7e70db`, `#518d2c`, `#008f7c`, `#bc5ca6`; yellow `#977c00`). The skill's name is written in it wherever it appears, with its icon. The *Per theme* control shows today's pill pairs instead (dark ink on light, pale ink on dark) to compare. **Downside:** no single colour can reach 4.5:1 on both a light and a dark surface, so a fixed colour gets 3.05 to 3.8:1; that is the WCAG bar for large bold text (the names are 14 dp bold at 1.4x, about 19.6 px), icons and bars, and the figures stay in the neutral text colour. The Today tiles' pills change with the theme today and would need these colours too, for the skill to look the same everywhere.
2. **Mastery by skill:** the radar labels carry the skill icon and colour, and each corner's dot is the skill's colour; the area stays the theme's primary. A **Bars** variant gives each skill a row of its own colour. The numbers are unchanged.
3. **Top tiles** (owner, 2026-10-26: "keep just 2 tiles on top, not 3. 3 tiles becomes too tall and thin. Keep 3 if you can stop making them taller."): two tiles by default, so each is wide and about 130 dp tall at 1.4x, against 180 dp today. *2: Words, Rules* (default) or *2: Words, Sentences*; *3, shorter* keeps all three at about 165 dp (title, figure with "known" beside it, bar, "of N taught"). Each has a bar of how much of what is taught is known. *One accent* is neutral tiles with the primary bar; *Tile colours: Three accents* uses the seed's primary, secondary and tertiary containers.
4. **Level** is the one filled tile (primary container), with a trophy, "Not yet" and the A1, A2, B1 ladder with the current level filled once reached, and the start date.
5. **This week** gets a title and "5 of 7 days" (the dots are unchanged).
6. **Hours spent and Hours left** get icons; "About" stays small, the number big.
7. **No leeches** shows a check, not a warning triangle, when there are none.
8. Weakest tags is unchanged but for the heading sizes matching the other cards.

## Open questions

1. **Script's colour.** It has no `ModeColors` entry; today its tile follows the seed. Pink is the match-pairs set (a drill mode, not a skill) and yellow is the reading set (Reading is a skill not shown on Progress yet). Pink now, and yellow reserved for Reading, avoids a clash later. The page has both.
2. **Skill names elsewhere.** The same ink would apply to every place a skill is named (Over time, the drill's skill chip, Settings > skills). Out of scope for this page; stated here so that it is built once, as a helper.
3. **Which two tiles.** Words and Rules are shown; Sentences ("open of taught") is a different measure and the one dropped. The other pair is a control. Or all three, shorter.
4. **Radar or bars.** The owner said the structure is fine, so Radar is the default; Bars reads better at 1.4x and lists all six without crowded corners, and costs a taller card.
5. **Tile colours: one accent or three.** Three adds colour but those colours are the seed's, so they change with the theme, while skill colours never do. That is a reason for One accent, so that only the skills carry colour.
6. **"First number · second number"** under each skill is unchanged and still unexplained on the screen (taught share and known share, as built); worth a caption later, not part of this.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) for clay and forest, light and dark, and run in Chromium. Text 4.5:1; icons, bars and large bold text 3:1. The lowest ratio across the 4 theme and seed combinations is shown; all 256 pairs pass. The skill rows are the worst of 28 each (7 colours, including both Script choices, on 4 themes).

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
| skill name, fixed, on card (large bold) | 3.63 : 1 | 3 : 1 | 28 | pass |
| skill name, fixed, on page (large bold) | 3.83 : 1 | 3 : 1 | 28 | pass |
| skill name, fixed, on a tile (large bold) | 3.27 : 1 | 3 : 1 | 28 | pass |
| skill bar or icon, fixed, on its track | 3.05 : 1 | 3 : 1 | 28 | pass |
| skill name, per theme, on card | 8.17 : 1 | 4.5 : 1 | 28 | pass |
| skill name, per theme, on page | 8.61 : 1 | 4.5 : 1 | 28 | pass |
| skill bar, per theme, on its track | 7.00 : 1 | 3 : 1 | 28 | pass |

Checked in Chromium at 1.4x, light and dark, Hindustani and Bengali, radar and bars: no page errors, no overflow. Not checked: other text sizes (the app caps at 1.4x), the high-contrast and pure-black themes, and a real phone.
