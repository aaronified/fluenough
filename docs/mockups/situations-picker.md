# Situations picker: self-check and notes

Companion to `situations-picker.html` (#1145). It redesigns the "Choose situations" dialog behind the pencil on Today's Situations card (`lib/features/situations/situations_editor.dart`, strings `situationsEdit*` in `lib/l10n/app_en.arb`). Controls: theme, language chip (Telugu, Hindustani, Bengali), highlight, remove cue (x on the tile or tap only), and whether the dialog grows or scrolls inside 740 dp. The tiles are live (tap to move, Reset restores the first six).

## Screens
Three states side by side, real Telugu labels (Taxi, Shopping, Eating out, Doctor and pharmacy, Greetings and apologies, Emergencies, Traffic stop, Rail station, Post and bank, Hotel):
- a. 4 of 6: two dashed empty slots, every other tile can be added.
- b. 6 of 6: the counter turns solid, the rest are disabled with "Remove one to add another".
- c. 5 of 6 with a tile lifted mid-drag over a drop place.

## What changed and why
| Owner's complaint | Change |
|---|---|
| No visual separation of selected and unselected | Two sections in the one dialog. "On Today" tiles are filled in their own colours with an x. "More situations" tiles are muted: neutral surface, thin outline, coloured icon only, a small + corner. |
| Only 6 show on Today, yet everyone can be numbered | At most 6 can be selected. The counter ("4 of 6") sits in the section header, empty slots are dashed outlines, and at 6 the unselected tiles are disabled with one line of help. No tile is ever "selected but not shown". |
| Why numbers exist is unclear | The per-tile numbers are dropped. Position is the order, and the grid reads left to right, top to bottom. "Hold and drag to reorder" appears only under "On Today", with a drag icon. |

Buttons are unchanged: Reset to defaults, Cancel, Done. The help line becomes "Tap a situation to move it between the two lists. Up to 6 are shown on Today." (the hold-and-drag sentence moved into the section). The language chip names which language's situations are being edited (they are per language).

Tiles are text at 12 sp x 1.4 (down from labelLarge 14), because "Emergencies" does not fit a 3-column tile at 14 sp x 1.4 without breaking mid-word. Longer labels clamp to two lines with an ellipsis, as today.

## Contrast self-check (WCAG 2.1)

Computed from the app palette (`ColorScheme.fromSeed`, forest seed, and the `ModeColors` pairs of `lib/ui/theme.dart`; same tokens as the other mockups).

| Pair | Light | Dark | Needed |
|---|---|---|---|
| Title and labels on the dialog (`onSurface` on `surfaceContainerHigh`) | 14.0:1 | 11.2:1 | 4.5:1 |
| Help and hints (`onSurfaceVariant` on the dialog) | 7.6:1 | 8.5:1 | 4.5:1 |
| Selected tile label on its container (worst of seven) | 13.2:1 | 7.0:1 | 4.5:1 |
| x glyph on its badge on the tile (worst of seven) | 9.5:1 | 4.9:1 | 3:1 (graphic) |
| Muted tile label on the surface | 16.3:1 | 14.3:1 | 4.5:1 |
| Muted tile icon (colour from the opposite scheme) on the surface, worst | 8.6:1 | 14.3:1 | 3:1 (graphic) |
| Counter text on `secondaryContainer` | 7.2:1 | 7.2:1 | 4.5:1 |
| Full counter and Done (`onPrimary` on `primary`) | 6.5:1 | 7.7:1 | 4.5:1 |
| Text buttons (`primary` on the dialog) | 5.3:1 | 8.5:1 | 4.5:1 |
| Outline of dashed slots (`outline` on the dialog) | 3.7:1 | 4.5:1 | 3:1 (graphic) |
| Disabled tile label and icon | 4.4:1 and 3.7:1 | 5.7:1 and 5.0:1 | exempt (disabled), kept near 4.5 anyway |

No cue is colour alone: filled against outlined, the x against the +, the words "On Today" and "More situations", the counter text, and the help line on disabled tiles. Checked in Chromium (Playwright) at deviceScaleFactor 2, light and dark, 1.4x text, 360 dp, with no horizontal page scroll.

## Implementation notes
- Change only `situations_editor.dart` (`_SituationsEditorState.build`, `_tile`, `_TileFace`). No new data model: the stored value is still the ordered list of ids per language (`setSituationsShown`), and "chosen" is now capped at `situationsOnCard` (6). Anything stored with more than 6 is cut to the first 6 when the dialog opens.
- Two grids instead of one `Wrap`: an `ol`-like grid of chosen tiles (drag and drop as now, `LongPressDraggable` and `DragTarget`) with `situationsOnCard - chosen.length` dashed placeholders, then a grid of the rest. `_toggle` refuses to add at 6. Disabled tiles use `onTap: null` and keep the semantics label.
- `_TileFace` loses `position` (and the number); it gains an `x` badge (on) or a `+` badge (off) and a muted variant: `scheme.surface` fill, `outlineVariant` border, icon in the situation colour.
- The muted icon colour is the tile's colour from the opposite brightness (deep in light, pale in dark). A small helper next to `situationColor` would do it, or use `onContainer` if the owner prefers a plain icon.
- Strings: new `situationsEditOnToday` ("On Today"), `situationsEditCount` ("{count} of {max}"), `situationsEditMore` ("More situations"), `situationsEditFull` ("Remove one to add another"), `situationsEditReorder` ("Hold and drag to reorder"), `situationsEditAddHint` ("Tap to add to Today"); the help string is reworded; `situationsEditShown` loses "number {position}" (keeps the place in the section for screen readers) and the earlier/later custom actions stay.
- The counter is a polite live region; the Done button stays disabled with 0 chosen.

## Open questions for the owner
1. Keep drag to reorder, or drop it and keep only the earlier/later actions (simpler, fewer gestures)?
2. Tap only to remove, or a separate x target (the tweak shows both; the tile is the tap target either way)?
3. At 6 of 6, should a tap on a disabled tile shake and flash the hint instead of doing nothing?
4. Muted icon colour: opposite-scheme colour (shown) or the plain `onContainer`?
5. Stored lists longer than 6 are cut on open: acceptable?
