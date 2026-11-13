# Private languages, import review: self-check and notes

Companion to `private-import-review.html` (#1017, `wiki/Plan-Private-Languages.md` tasks 10 and 17; sections 2.4 and 2.11). Awaiting the owner's approval. All screens are new, so there is no highlight control. Controls: theme, example (Bengali or Hindi changed course, Tolu new language), what the file has (errors, warnings only, notes only), and four design choices.

## Screens
1. While it checks (isolate, four steps, Cancel).
2 and 3. The review: file name and size against 10 MB, language, package id, revision, kind, counts of cards, units and decks, and a summary in words ("3 Errors, 2 Warnings, 2 Notes"). Findings give file, line, card, field and the problem. Add to my decks is a native disabled button while any Error remains; a line above it says why. 3 is the same screen scrolled.
4. A finding in a sheet (detail B).
5. Refused: an older revision (installed 7, file 5).
6. Refused: over the size limit (11.3 MB, limit 10 MB measured on the file).
7. Refused: not safe to open (a `..` name, plus the other level 0 reasons).

## Rules shown
- Severity is a word with an icon shape: **Error** (blocks), **Warning** (never blocks), **Note** (information). Colour only backs it up.
- Findings come from the staged `Catalog.parseAll` and the level 0 to 3 checks of section 2.4; the app never edits the file, so every finding ends with "choose the file again".
- Rights warnings: with option A a box the learner ticks ("I have the right to use this content") gates Add when a rights warning exists; with B they are ordinary Warnings. CC-BY-SA-4.0 is fixed, so the text says what that means on export.
- The three refusals happen before anything is unpacked or installed.

## Open questions for the owner
1. Older revision: refusal only (task 10) or a refusal with a destructive override (section 2.7 says "a lower revision needs a confirm")? The plan disagrees with itself.
2. Rights: a box to tick (A) or warnings only (B)? The app can only detect a source or copyright mark in a note.
3. Findings by severity (A) or by file (B)?
4. Detail in the list (A) or a sheet (B)?
5. Warnings never block, only Errors: confirm.

## Contrast self-check (WCAG 2.1)

Computed from the app palette used in the page (`ColorScheme.fromSeed`, forest seed; the same tokens as `topic-page.html`).

| Pair | Light | Dark | Needed |
|---|---|---|---|
| Body text on the screen | 16.3:1 | 14.3:1 | 3:1 |
| Muted text on the card (sLow) | 8.4:1 | 10.1:1 | 4.5:1 |
| Muted text on the high container | 7.6:1 | 8.5:1 | 4.5:1 |
| Filled button text | 6.5:1 | 7.7:1 | 4.5:1 |
| Link / text button (primary) on the screen | 6.2:1 | 10.9:1 | 4.5:1 |
| Error tag text (Error) | 6.5:1 | 7.7:1 | 4.5:1 |
| Warning tag text (Warning) | 5.9:1 | 7.7:1 | 4.5:1 |
| Note tag text on the screen | 16.3:1 | 14.3:1 | 3:1 |
| Privately modified tag text | 5.7:1 | 7.8:1 | 4.5:1 |
| Remove (error colour) on the card | 5.8:1 | 10.1:1 | 4.5:1 |
| Chip text on secondaryContainer | 7.2:1 | 7.2:1 | 4.5:1 |
| Disabled button text on its fill | 5.5:1 | 5.5:1 | 4.5:1 |
| Outline on the screen (graphic, 3:1) | 4.3:1 | 5.8:1 | 3:1 |
| Switch off outline on the high container (3:1) | 3.7:1 | 4.5:1 | 3:1 |
| Switch on track vs thumb (3:1) | 6.5:1 | 7.7:1 | 3:1 |

Disabled controls (the Add button while errors remain) are exempt from WCAG contrast; the reason line above the button is normal text at full contrast. Checked in Chromium (Playwright) at deviceScaleFactor 2, light and dark, 1.4x text, 360 dp, with no horizontal page scroll. Targets: every button, row, switch and checkbox is at least 48 dp tall (a switch is a native `input type="checkbox" role="switch"` inside a 48 dp label; a checkbox and a radio sit in a 48 dp or 56 dp label). Screenshots of each state are in the session's scratchpad `mock2/` folder; they are not committed.
