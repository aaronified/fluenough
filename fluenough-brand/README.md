# Fluenough logo, direction A: "Enough tick"

A lowercase f whose crossbar is a tick. The wordmark is Roboto Flex (wdth 118, wght 800, opsz 72, tracking -0.035em), converted to outlines, so it needs no installed font. The shared "en" (flu**en**t + **en**ough) takes the accent.

| Role | Light | Dark |
|---|---|---|
| Stem / text | `#085231` / `#171D19` | `#AEF2C6` / `#DFE4DD` |
| Tick and "en" | `#C2621D` | `#FFB68A` |
| Icon background | `#AEF2C6` | |

Files
- `fluenough-mark*.svg`: the mark (light, dark, mono uses currentColor)
- `fluenough-wordmark*.svg`: outlined wordmark
- `fluenough-lockup*.svg`: mark + wordmark
- `fluenough-app-icon.svg`, `png/icon-512.png`: store and F-Droid icon (square, stores apply their own mask)
- `android/`: adaptive icon layers, and `mipmap-*/ic_launcher.png` for Android 7 (API 24 and 25), which has no adaptive icons, rendered from `fluenough-app-icon.svg`. Also the launch screen (`launch_*`, `values*-v31/styles.xml`): the app's own background, near-white or a soft black, with the mark. `python3 tools/brand_android.py` copies all of it into `android/app/src/main/res/` after `flutter create` and sets the launcher label; CI does.

Minimum size: mark 16px, lockup 96px wide. Keep clear space of half the mark's height around it.

Font: Roboto Flex, SIL Open Font License 1.1.
