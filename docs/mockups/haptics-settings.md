# Haptics settings: self-check, notes and open questions

Companion to `haptics-settings.html` (owner, 2026-11-02: "A button in the UI settings section will turn on or off haptic feedback."). The page holds only the screens, the pill reference panel and their tweak controls, with what changed outlined in red and tagged "new". The checks and notes are here. The plan is [Plan-Haptics](https://github.com/aaronified/fluenough/wiki/Plan-Haptics); nothing below is decided.

Phone 360 dp, `ColorScheme.fromSeed` of each of the app's four seeds (the schemes copied from `settings.html`), light and dark, 1x and 1.4x text (the app's cap, #505), Hindustani and Bengali examples. Tweak controls: theme, text size, colour, example language, the switch's state, highlight, and "Compare with today".

## What the screen is today

`lib/features/settings/appearance_page.dart`, "Look and language" (`settingsRowLook`): the card preview, Theme, Pure black, Wallpaper colours (incoming), Colour, Contrast, Card text size, App language, Script fonts. The page draws each as built; the Hindustani or Bengali word is the preview card's, as the app draws a real card.

## What the proposal changes

One row, in its own 24 dp block after Card text size and before App language, so App language and Script fonts stay together at the end:

| | |
|---|---|
| Widget | `GroupedTile.toggle`, padding 20 and 16 as Pure black, no `Feature` gate (it is live) |
| Icon | `vibration` |
| Title | Vibrate on touch |
| On | Buttons, pills and answers buzz a little |
| Off | No buzz when you tap |

The line changes with the switch (settings-wording rule): tap the row on the page. Hidden on web and desktop, where the phone cannot vibrate (not drawn). Under each phone a line says what flipping it plays (`toggle on`, a press; flipping off is silent because the switch is already off).

The reference panel is not a screen: the four pill feels (Leave tick, Learn tap, Know press, Learnt rise), each drawn as `SkillBadge` draws it in `ModeColors`, with the cycle and its end.

## Open choices

1. Title: "Vibrate on touch" (the Android words for the phone's own setting) or "Haptic feedback" (jargon) or "Touch feedback".
2. Placement: after Card text size (drawn), or straight after Pure black.
3. The pill feels: the plan's ladder (drawn), or a wider one. See the plan's open question 1.
4. Where the phone's own touch feedback is off, nothing buzzes whatever the row says (Flutter cannot read that setting). The line does not promise more than "a little buzz".

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast()`, console only) in Chromium, for each of the four seeds in light and dark (116 pairs). Text 4.5:1, icons, switch parts, outlines and fills 3:1. All pass. Lowest ratio over the four seeds:

| Pair | Light | Dark | Needs | Result |
|---|---|---|---|---|
| new row title (onSurface on surfaceContainerLow) | 15.44 | 13.17 | 4.5 | pass |
| new row line (onSurfaceVariant on surfaceContainerLow) | 8.45 | 10.01 | 4.5 | pass |
| new row icon | 8.45 | 10.01 | 3 | pass |
| switch on: thumb on track | 6.45 | 7.68 | 3 | pass |
| switch off: outline on the row | 4.06 | 5.4 | 3 | pass |
| switch off: thumb on track | 3.46 | 3.89 | 3 | pass |
| Pill Leave icon on container | 7.24 | 7.24 | 4.5 | pass |
| Pill Leave dashed outline on the page | 8.88 | 14.31 | 3 | pass |
| Pill Learn icon on container | 11.88 | 8.12 | 4.5 | pass |
| Pill Know icon on container | 10.26 | 9.84 | 4.5 | pass |
| Pill Learnt icon on container | 7.87 | 5.13 | 4.5 | pass |
| "new" tag text on its fill | 6.46 | 7.72 | 4.5 | pass |
| change outline on the row | 5.83 | 10.06 | 3 | pass |
| page, muted, table and tweak text | 5.73 and up | 7.68 and up | 4.5 | pass |

Notes: the pill colours are the `ModeColors` constants (`pillLeave`, `pillLearn`, `pillKnow`, `pillVerified`); the "Wallpaper colours" row is incoming and drawn at 38%, exempt from the ratio, as in the app.

## Behaviour checks (Chromium, Playwright)

- Loaded at 1500 px wide: no page errors and no console errors; no horizontal page scroll.
- Both themes at 1x and at 1.4x, then both themes and both sizes with "Compare with today", in Hindustani and Bengali: no element outside any phone's width, no sideways scroll inside a phone, the title never meets the switch, the row never clips. At 1.4x the line wraps to three lines and the row grows; nothing is cut.
- Tapping the new row flips the switch and its line ("Buttons, pills and answers buzz a little" and "No buzz when you tap"), and the line under the phone follows. The Switch tweak does the same on every phone.
- All four seeds were set in both themes.
- Screenshots of the light and dark phones at 1x and 1.4x were taken and read.
- Fonts: Roboto, Noto Sans Devanagari and Noto Sans Bengali from Google Fonts; where offline the system fallback is used. Material Icons are embedded, as in `settings.html`.
