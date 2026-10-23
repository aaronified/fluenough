# Placement review choice: self-check, notes and open questions

Companion to `placement-review-choice.html` (#761; related #481, #680, #678, #723). The page holds only the screens and their tweak controls, with what is new or changed outlined in red. Nothing marked open is decided; every open choice is a tweak control on the page.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, Hindustani in light and Bengali in dark. Numbers are plausible, not real.

## What the page shows, from the owner's decisions (2026-10-23, #761)

- **End-of-placement screen**: one question, three choices, one line each: Counted as known (no reviews, counts as known on Progress), Sampled (a few checked now and then, more if gaps show, as #680's escalation does), Normal (reviewed as usual). Hindustani is the owner's case: everything placed except the script decks. Bengali has 36 placed script words, so the script-deck tweak has something to act on.
- **Per-course setting** in Languages I'm learning: a "Placed words" row on each course card showing the current choice, and the bottom sheet that changes it. The sheet says that switching back from Counted as known returns the placed words to reviews, and that words learned from now on are always reviewed as usual (both decided).
- **Icons**: Tabler icons drawn as inline paths, no emoji (circle-check, list-search, refresh, circle-dot, chevron-right, arrow-left). In Flutter: `Icons.check_circle_outline`, `Icons.manage_search`, `Icons.refresh`, `Icons.radio_button_checked` and `Icons.radio_button_unchecked`, `Icons.chevron_right`, `Icons.arrow_back`. The "Placed words" row's layers icon is `Icons.layers_outlined`.

## Open questions (tweak controls, not decided)

1. **Default choice.** None (the learner must pick; Start here waits), Counted as known, Sampled or Normal. Normal is today's behaviour; Counted as known matches the owner's own wish; Sampled sits between. The page opens on None, so nothing is preselected.
2. **Script decks exempt?** Exempt means placed script words stay Normal because the learner is actively learning them (the summary and the setting row say "script decks stay Normal"); Follow the choice means they obey it. In the Hindustani example no script word was placed, so only Bengali changes.
3. **Wording.** A is the owner's own words (Counted as known, Sampled, Normal). B is plainer (Set in stone, Spot-check, Keep reviewing) with the question "Do you want to keep reviewing what you already know?".

## Not owner-decided, shown as drawn

The summary card (placed count, decks, sample words); the screen title "Hindustani: your level"; picking a row in the sheet applying at once and closing it (no Save button, no confirmation); the section's position under Find my level; the row's subtitle; the disabled look of Start here with no default. The icon per choice. Light and dark sheet scrim at 50%.

## Not mocked

Right-to-left, courses with several scripts placed separately (#481), the one-question screen when only a few words were placed, snack bars, transitions.

## Self-check results

WCAG contrast computed in the page's JS (`window.__check`, console only) and run in Chromium (`/opt/pw-browsers/chromium`) in both themes: text 4.5:1, icons and rings 3:1. No sideways scroll at 360 px, nothing runs past a phone's edge at 1.4x, no emoji in the page text. The disabled Start here (shown with no default) is exempt from contrast, as a disabled control. Selection is never colour alone: the filled radio dot and a thicker outline.

| Theme | Pair | Ratio | Needs | Result |
|---|---|---|---|---|
| light | question and option titles (onSurface) on surface/card | 15.50 :1 | 4.5 :1 | pass |
| light | option explanation (onSurfaceVariant) on card | 8.45 :1 | 4.5 :1 | pass |
| light | selected option title and explanation (onSecondaryContainer) on secondaryContainer | 7.25 :1 | 4.5 :1 | pass |
| light | selected radio dot and ring (primary) on secondaryContainer | 4.99 :1 | 3 :1 | pass |
| light | unselected radio ring (onSurfaceVariant) on card | 8.45 :1 | 3 :1 | pass |
| light | selected option outline (primary) on surface | 6.16 :1 | 3 :1 | pass |
| light | option icon (onSecondaryContainer) on secondaryContainer | 7.25 :1 | 3 :1 | pass |
| light | option icon (onSurface) on card | 15.50 :1 | 3 :1 | pass |
| light | Start here: onPrimary on primary | 6.46 :1 | 4.5 :1 | pass |
| light | footnote and summary values (onSurfaceVariant) on surface | 8.90 :1 | 4.5 :1 | pass |
| light | row title (onSurface) on card | 15.50 :1 | 4.5 :1 | pass |
| light | row subtitle (onSurfaceVariant) on card | 8.45 :1 | 4.5 :1 | pass |
| light | row chevron and icons (onSurfaceVariant) on card | 8.45 :1 | 3 :1 | pass |
| light | language pill: onSecondaryContainer on secondaryContainer | 7.25 :1 | 4.5 :1 | pass |
| light | sheet text (onSurface) on sheet (surfaceContainer) | 14.69 :1 | 4.5 :1 | pass |
| light | sheet footnote (onSurfaceVariant) on sheet | 8.01 :1 | 4.5 :1 | pass |
| dark | question and option titles (onSurface) on surface/card | 13.28 :1 | 4.5 :1 | pass |
| dark | option explanation (onSurfaceVariant) on card | 10.08 :1 | 4.5 :1 | pass |
| dark | selected option title and explanation (onSecondaryContainer) on secondaryContainer | 7.25 :1 | 4.5 :1 | pass |
| dark | selected radio dot and ring (primary) on secondaryContainer | 5.51 :1 | 3 :1 | pass |
| dark | unselected radio ring (onSurfaceVariant) on card | 10.08 :1 | 3 :1 | pass |
| dark | selected option outline (primary) on surface | 10.86 :1 | 3 :1 | pass |
| dark | option icon (onSecondaryContainer) on secondaryContainer | 7.25 :1 | 3 :1 | pass |
| dark | option icon (onSurface) on card | 13.28 :1 | 3 :1 | pass |
| dark | Start here: onPrimary on primary | 7.68 :1 | 4.5 :1 | pass |
| dark | footnote and summary values (onSurfaceVariant) on surface | 10.88 :1 | 4.5 :1 | pass |
| dark | row title (onSurface) on card | 13.28 :1 | 4.5 :1 | pass |
| dark | row subtitle (onSurfaceVariant) on card | 10.08 :1 | 4.5 :1 | pass |
| dark | row chevron and icons (onSurfaceVariant) on card | 10.08 :1 | 3 :1 | pass |
| dark | language pill: onSecondaryContainer on secondaryContainer | 7.25 :1 | 4.5 :1 | pass |
| dark | sheet text (onSurface) on sheet (surfaceContainer) | 12.70 :1 | 4.5 :1 | pass |
| dark | sheet footnote (onSurfaceVariant) on sheet | 9.64 :1 | 4.5 :1 | pass |
