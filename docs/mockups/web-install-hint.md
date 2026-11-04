# Web install hint: self-check, notes and open questions

Companion to `web-install-hint.html` (issue #1012, finding "Storage eviction"; owner, 2026-11-04: "Web needs to cover iOS fully... complete all web jobs"). The page holds only the screens and tweak controls, with what is new outlined in red. The checks and notes are here. Nothing below is decided.

Safari may clear a site's data after 7 days of non-use unless the web app is on the Home Screen, and nothing tells the learner. Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark, Telugu, Bengali and Hindustani examples (Telugu writes a final anusvara as ṁ; Bengali has no final a).

## Screens

Starting layout: `lib/features/today/today_page.dart` (a header, then `_sections`, where `_NotSavedBanner` already sits first) inside `webPhoneFrame` (`lib/app/web_frame.dart`, 430 dp wide at most).

1. **Today, iPhone Safari, not installed.** The hint card sits under the greeting, in the slot and container of `_NotSavedBanner` (`surfaceContainerHighest`, `AppRadii.field`, a leading icon, one title, one body), above the daily card. Title "Add Fluenough to your Home Screen", body "Safari keeps your decks and progress when Fluenough is on your Home Screen.", a how-to line on an inset with the Share glyph, "Tap Share, then Add to Home Screen", then "Got it" (tonal) and "Later" (text). Safari's bar is drawn at the bottom.
2. **Today, Android Chrome.** The same card, titled "Install Fluenough", with an "Install" filled button (it calls the browser's native install prompt), then "Later" and "Got it". No how-to line, as the prompt is native. Chrome's bar is drawn at the top.
3. **Today, installed (standalone).** No hint, and no browser bar. The Hint state control is disabled.
4. **Settings, Your data, Storage group.** The closest existing section: Your data is the backup page. A new group at its top, web only. Row one is "Storage: kept (persistent)" when installed, else "Storage: may be cleared by the browser" with a caption naming the learner's course in its script and the browser's rule, and the existing info dot. Row two is the how-to ("Add to Home Screen, Tap Share, then Add to Home Screen" on iOS; "Install Fluenough" with a tonal Install button on Android). Row three, "Remind me on Today" with a Show button, appears only after the hint was dismissed.
5. **Dismissed.** The card is gone from Today. Tapping Got it or Later on the page shows a snackbar "Hint hidden. It stays in Settings, Your data." with Undo, so the learner is told where it went.

Reused, nothing new: the `_NotSavedBanner` container, filled, tonal and text buttons, the `GroupedList` group with its `GroupedTile` rows, the info dot (the 20 px `info_outline` icon in a 48 px target, as in `_Hint` in `due_card.dart`), the snackbar, and the `Hint` one-word tooltip.

## Accessibility and rules

- **Icon-only buttons.** The info dot has the one-word hint "Info" (shown on hover, focus or long press) and the full phrase as its screen-reader label: "Why Safari may clear your data" (Chrome on Android). The profile avatar ("Profiles", label "Switch profile") and Back ("Back", label "Back to Settings") follow the same rule. Every other control has text.
- **Tokens only.** The page defines `AppRadii` as `--r-*` custom properties on `:root` and every rule I wrote uses `var(--r-*)`, no numeric radius. Colours are the scheme's tokens only.
- **Strings.** Every string on the screens is meant to be an `app_en.arb` token (rule 10 of AGENTS.md), one per state, so a translator controls the order. `Share` and `Add to Home Screen` are bold in the how-to line, as iOS names them; the token needs placeholders for them.
- **Logical layout.** The card uses start and end padding in the build (`EdgeInsetsDirectional`); the mock only draws left to right.

## Remembered per device (screen 5, for the build, not drawn)

The dismissal is stored in the browser, on the device, not in the profile or a backup. Use the settings store drift already keeps in the browser (so it is gone when the data is). Two keys: `installHintDismissed` (Got it: never again) and `installHintLaterUntil` (Later: hidden until that date). A learner who clears the browser's data sees the hint again, which is right: they have lost their decks anyway. Standalone is detected with `display-mode: standalone` (and `navigator.standalone` on iOS), and Storage's state with `navigator.storage.persisted()`. Chrome's native prompt comes from the `beforeinstallprompt` event; Install is shown only while the event is held. iOS has no such event, which is why it only gets the how-to.

## Open questions for the owner (numbered, each with the option I drew)

1. **How long does "Later" hide the hint?** Drawn: not decided. Options: 3 days, 7 days (the length of Safari's clean-up, so the reminder comes before the risk), or until the next visit. Downside of short: it nags; of long: the data may already be gone. I suggest 7 days.
2. **Does "Got it" mean never again, even on a new profile?** Drawn: yes, per device, as asked. The Storage row in Settings is the way back, with "Remind me on Today".
3. **Android: are Later and Got it both needed beside Install?** Drawn: three buttons (Install, Later, Got it), as asked for iOS, so the two cards match. Downside: three choices on a small card. Option: Install and Not now only.
4. **Android with no native prompt** (Chrome already dismissed it, or another browser): drawn with no Install button, and so no card on Android. Option: a how-to line "Open the menu, then Install app", as iOS has. Which?
5. **Other browsers** (Firefox, desktop Chrome and Safari): drawn as no hint, since they have no 7-day rule that matters here, or no install flow. Does the owner want a hint on desktop?
6. **The 7 days claim.** It is Safari's rule (Intelligent Tracking Prevention) for a site not used for 7 days of browser use, and the card says "Safari may clear". I kept it a "may", not a promise. Is the plain wording right, or is the day count too much detail on the card? The card does not say 7; the info dot and the Settings caption do.
7. **Where does the hint sit?** Drawn: under the greeting, above the daily card, the slot the not-saved banner uses. If both apply, which comes first? Drawn: the not-saved banner first, since it is about this session. The alternative is a hint above the tabs, which hides it behind the browser's bar on iOS.
8. **Persistent storage request.** The build would also call `navigator.storage.persist()` where the browser allows it. On Chrome this often succeeds without asking, and the row would then say "kept (persistent)" without the app being installed. The row's wording is the browser's answer, not whether the app is installed. Is that what the owner wants? It changes when the Android hint is shown (it would not be, once persistence is granted).
9. **Is "Storage" the right section?** Drawn: Your data, at its top, web only. The alternative is a row in Look and language. I picked Your data as it holds backup, and the hint is about keeping data.

## Self-check results

Chromium (Playwright), `window.__contrast`, both themes. Text 4.5:1, icons and outlines 3:1. All 56 checks pass.

| Pair | Colours | Needs | Light | Dark |
|---|---|---|---|---|
| body text | onS on s | 4.5 :1 | 16.33 :1 | 14.33 :1 |
| captions, readings | onSv on s | 4.5 :1 | 8.9 :1 | 10.88 :1 |
| text on cards | onS on sLow | 4.5 :1 | 15.5 :1 | 13.28 :1 |
| captions on cards | onSv on sLow | 4.5 :1 | 8.45 :1 | 10.08 :1 |
| hint title | onS on sHighest | 4.5 :1 | 13.28 :1 | 9.55 :1 |
| hint body, icons | onSv on sHighest | 4.5 :1 | 7.24 :1 | 7.25 :1 |
| how-to line on its inset | onS on sLow | 4.5 :1 | 15.5 :1 | 13.28 :1 |
| Share glyph on inset | p on sLow | 3 :1 | 5.85 :1 | 10.05 :1 |
| hint buttons: tonal | onSc on sc | 4.5 :1 | 7.25 :1 | 7.25 :1 |
| hint buttons: filled Install | onP on p | 4.5 :1 | 6.46 :1 | 7.68 :1 |
| hint buttons: text on hint | p on sHighest | 4.5 :1 | 5.01 :1 | 7.23 :1 |
| text button on card (Show) | p on sLow | 4.5 :1 | 5.85 :1 | 10.05 :1 |
| popover text | onS on sLowest | 4.5 :1 | 17.13 :1 | 14.98 :1 |
| group heading on page | p on s | 4.5 :1 | 6.16 :1 | 10.86 :1 |
| settings row title | onS on sLow | 4.5 :1 | 15.5 :1 | 13.28 :1 |
| settings row caption | onSv on sLow | 4.5 :1 | 8.45 :1 | 10.08 :1 |
| selected pill | onSc on sc | 4.5 :1 | 7.25 :1 | 7.25 :1 |
| unselected pill text on page | onSv on s | 4.5 :1 | 8.9 :1 | 10.88 :1 |
| pill outline against page | ol on s | 3 :1 | 4.28 :1 | 5.84 :1 |
| nav label | onSv on sCont | 4.5 :1 | 8.01 :1 | 9.64 :1 |
| nav label selected | onSc on sc | 4.5 :1 | 7.25 :1 | 7.25 :1 |
| browser bar text | onS on sHighest | 4.5 :1 | 13.28 :1 | 9.55 :1 |
| one-word hint (tooltip) | onInvS on invS | 4.5 :1 | 11.55 :1 | 10.17 :1 |
| snackbar text | onInvS on invS | 4.5 :1 | 11.55 :1 | 10.17 :1 |
| snackbar action | invP on invS | 4.5 :1 | 7.7 :1 | 5.01 :1 |
| change tag | onE on E | 4.5 :1 | 6.46 :1 | 7.72 :1 |
| change outline on page | E on s | 3 :1 | 6.16 :1 | 10.89 :1 |
| change outline on card | E on sLow | 3 :1 | 5.85 :1 | 10.09 :1 |

Layout, checked in Chromium at 1.4x for Telugu, Bengali and Hindustani, light and dark, iOS, Android and installed, hint shown and dismissed, popover open and closed (72 states): no element wider than its phone, no clipped text. One state scrolls: Android, hint dismissed, Settings, where the Back up group is below the first screen.
