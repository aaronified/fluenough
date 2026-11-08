# Progress placement: self-check and notes

Companion to `progress-placement.html` (owner, 2026-11-07: build the placed layer without waiting for approval; owner, 2026-10-22: the self-checks and notes live in a Markdown file of the same name). The page holds the screens and their tweak controls, with what is new or changed outlined in red.

Phone 360 dp at 1.4x text (the app's cap, #505), the app's own palette (`ColorScheme.fromSeed` of the forest seed), light and dark, Hindustani and Bengali examples. Controls: theme, course, highlight, how much is placed (none, some, most) and motion (grows once, reduced).

## Screens

1. **Progress star** (`lib/features/stats/skill_star.dart`). The solid fill is known ÷ the B1 total; the blue outline is known ÷ taught and is earned only; the new hatched layer is (known + placed) ÷ the B1 total, drawn under the fill with no edge, in amber (`#8A5A00` light, `#E0A458` dark) so it is never read as earned. The legend under the star ("Placed and earned 31%") appears only while something is placed. The star's one screen-reader label gains "N% with placed" per skill that holds placement credit and a line saying what the hatched layer is. Under reduced motion the star is drawn at once, as before.
2. **Languages sheet.** Under each skill row, the line of the last V3 check: "Read: unit 14, likely 11 to 17 · Fairly sure". An older run has no range, so only its word shows; a skill an earlier version marked Verified reads "Earlier check (not verified)" and carries no tick. Say without a recogniser reads "self-rated, not placed" in the result and is not stored as placed.
3. **Result** (built in the placement PR before this one; shown here for the whole set): start unit, the 80% range, the confidence word, Change, and Read and Write that need the script first with "I do read it: check again".

## Contrast self-check (WCAG 2.1)

| Pair | Ratio | Needed |
|---|---|---|
| Hatch `#8A5A00` on the light card `#F0F5EE` | 5.4:1 | 3:1 (graphic) |
| Hatch `#E0A458` on the dark card `#171D19` | 7.9:1 | 3:1 (graphic) |
| Legend and line text `#404942` on `#F0F5EE` (light) | 8.5:1 | 4.5:1 |
| Legend and line text `#C0C9C0` on `#171D19` (dark) | 10.1:1 | 4.5:1 |
| Earned outline `#1565C0` on the light card | 5.2:1 | 3:1 (graphic) |

The hatch is never the only cue: the legend says "Placed and earned N%", the semantics label says it, and the hatched layer differs in texture, not only in colour, from the solid fill and the outline.

## Notes

- Placed is never known: it does not move the outline, hold back lessons or count as practice. A real review of a placed pair makes it earned from that answer on.
- Nothing here is a probability of "none" or a "Verified" claim.
- The star's legend names only placement. A skill's "Not tested" and "Self-rated" words are on the Languages sheet and in the result, where there is room for the reason.
