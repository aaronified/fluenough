# Situations picker: self-check and notes

Companion to `situations-picker.html` (#1145). It redesigns the "Choose situations" dialog behind the pencil on Today's Situations card (`lib/features/situations/situations_editor.dart`, strings `situationsEdit*` in `lib/l10n/app_en.arb`). Controls: theme, language chip (Telugu, Hindustani, Bengali), highlight, remove cue (x on the tile or tap only), and whether the dialog grows or scrolls inside 740 dp. The tiles are live (tap to move, Reset restores the first six).

## Screens
Three states side by side, real Telugu labels (Taxi, Shopping, Eating out, Doctor and pharmacy, Greetings and apologies, Emergency, Traffic stop, Rail station, Post and bank, Hotel):
- a. 4 of 6: two dashed empty slots, every other tile can be added.
- d. A stress row (not a dialog state): the longest labels at 1.4x, proving the fit rule below.
- e. The Today homepage strip: the first six tiles with the same stress labels and their "N new" line, under the same fit rule (owner: the rule applies to Today too).
- b. 6 of 6: the counter turns solid, the rest are disabled with "Remove one to add another".
- c. 5 of 6 with a tile lifted mid-drag over a drop place.

## What changed and why
| Owner's complaint | Change |
|---|---|
| No visual separation of selected and unselected | Two sections in the one dialog. "On Today" tiles are filled in their own colours with an x. "More situations" tiles are muted: neutral surface, thin outline, coloured icon only, a small + corner. |
| Only 6 show on Today, yet everyone can be numbered | At most 6 can be selected. The counter ("4 of 6") sits in the section header, empty slots are dashed outlines, and at 6 the unselected tiles are disabled with one line of help. No tile is ever "selected but not shown". |
| Why numbers exist is unclear | The per-tile numbers are dropped. Position is the order, and the grid reads left to right, top to bottom. The one instruction text is "Drag to order", with a drag icon, only under "On Today". |

Buttons are unchanged: Reset to defaults, Cancel, Done. The help paragraph is removed (owner): the sections, the counter, the x and + marks and the disabled tiles are self-evident, so there is no "Remove one to add another" or "Tap to add" line either. The language chip names which language's situations are being edited (they are per language).

## Tile label fit rule (owner)
The base label size is 13 sp x 1.4 (owner: about 1 sp smaller than the app's 14, so nothing looks close to overflowing). Fit order, each step only if the label does not yet fit its tile, and a word is never broken mid-word:
1. Wrap at word boundaries (up to 3 lines, then an ellipsis).
2. If a single word is still wider than the tile (Emergency, or a Telugu, Hindi or Bengali word), tighten letter-spacing, down to -0.02em and no further.
3. Then shrink the font, by at most 2 sp: 13 sp down to 11 sp at minimum (18.2 px down to 15.4 px at 1.4x), in 0.5 px steps.

The stress row (d) shows it: Doctor and pharmacy, Greetings and apologies and the Hindi and Bengali labels only wrap; Emergency needs steps 2 and 3 and lands on 12.6 sp; the Telugu label lands on 11.9 sp. The page prints the step taken under the row.

## Layout rules added (owner)
- The dashed empty slots in "On Today" are exactly the size of the filled tiles (they stretch to the row's height, minimum the tile's minimum height).
- The icon stays where it is (top, horizontally centred). The label block (and, on Today, the "N new" line under it) is centred vertically in the space between the icon's bottom and the tile's bottom edge, for 1, 2 or 3 lines, with 4 dp of inner side padding so no label touches an edge.

## Rename: Emergencies becomes Emergency
The situation label is "Emergency" everywhere in the mockup. The real strings to rename or check (searched in lib and decks on origin/main):
- `lib/l10n/app_en.arb`: `situationEmergency` is already "Emergency" (Today's fallback button for the emergencies sheet, #1269): no change.
- `lib/features/situations/situation_visuals.dart`: the `'emergency'` key (icon, colour, `situationName`): no text change.
- Situations data: no `decks/*/*-situations.yaml` has an emergencies sheet yet (the files are as, bn, es, fr, hi, ja, kn, mr, te and zh). When a sheet is added, its `title.en` must be "Emergency", not "Emergencies".
- The decks `*-emergencies.yaml` (for example `decks/te/en/te-en-emergencies.yaml`) and `decks/themes.yaml` are deck and theme names, not situation labels, and are out of scope here.

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
- One fit helper for both places (owner): the Today tile is `_SituationButton` in `lib/features/today/situations_card.dart` (a `Text` with `labelLarge`, `maxLines: 2`, ellipsis); the picker tile is `_TileFace` in `lib/features/situations/situations_editor.dart` (same look, copied). Both must use ONE shared widget, `FittedLabel`, in `lib/features/situations/` (for example `fitted_label.dart`), so the rule cannot drift; ideally `_TileFace` is also replaced by one shared tile face. The Today tile's "N new" line stays a separate `Text` under it. Fit helper: a small `FittedLabel` widget used by both (no dependency). Layout: a `LayoutBuilder` gives the tile's text width; a `TextPainter` fit loop (maxLines 3) tries 13 sp at letter-spacing 0, then -0.02em (`letterSpacing: -0.02 * size`), then sizes down in 0.5 sp steps to 11 sp, and uses the first that does not overflow (`didExceedMaxLines` is false and the longest unbreakable word, measured with `TextPainter(text: word)`, is at most the width). Measure with the already text-scaled style (`MediaQuery.textScalerOf`), and set `softWrap: true` only so the break is at spaces; Flutter does not break inside a word unless it overflows the line, so the word-width test is what prevents it. A `FittedBox(fit: BoxFit.scaleDown)` per word is the fallback if the loop is judged too heavy, but it shrinks below 11 sp, so the loop is preferred.
- `_TileFace` loses `position` (and the number); it gains an `x` badge (on) or a `+` badge (off) and a muted variant: `scheme.surface` fill, `outlineVariant` border, icon in the situation colour.
- The muted icon colour is the tile's colour from the opposite brightness (deep in light, pale in dark). A small helper next to `situationColor` would do it, or use `onContainer` if the owner prefers a plain icon.
- Strings: new `situationsEditOnToday` ("On Today"), `situationsEditCount` ("{count} of {max}"), `situationsEditMore` ("More situations"), `situationsEditReorder` ("Drag to order"); `situationsEditHelp` is deleted; the disabled tiles keep a screen-reader label that says to remove one first; `situationsEditShown` loses "number {position}" (keeps the place in the section for screen readers) and the earlier/later custom actions stay.
- The counter is a polite live region; the Done button stays disabled with 0 chosen.

## Open questions for the owner
1. Keep drag to reorder, or drop it and keep only the earlier/later actions (simpler, fewer gestures)?
2. Tap only to remove, or a separate x target (the tweak shows both; the tile is the tap target either way)?
3. At 6 of 6 a disabled tile now has no visible explanation, only the dimmed look (screen readers are told). Is that enough, or should a tap shake the counter?
4. Muted icon colour: opposite-scheme colour (shown) or the plain `onContainer`?
5. Stored lists longer than 6 are cut on open: acceptable?
