# Private languages, update summary: self-check and notes

Companion to `private-update-summary.html` (#1017, `wiki/Plan-Private-Languages.md` task 18; sections 2.2, 2.6, 2.7, risk 1). Awaiting the owner's approval. All screens are new, so there is no highlight control. Controls: theme, example (Bengali or Hindi changed course, Tolu new language), and three design choices.

## Screens
1a and 1b. The summary after a newer `.fnzip` of an installed package passes the import review: revision change, the file, the path change in one line, four counts (New, Changed, Removed, Retired ids), what happens to progress, the retired-ids explanation, and Update to revision N or Cancel.
2. The lists: new, changed (with the reason), removed, each with a few cards (word, reading, meaning, id) and Show all.
3. How your progress is kept, case by case.
4. What a retired id is (sheet, retired ids B).

## Rules shown (the orchestrator defaults of 2026-11-11, plan risk 1)
- Progress belongs to the card id, and an id never changes in an update (2.6).
- An unchanged built-in card stays in the private unit by `ref`; its progress is untouched.
- An edited built-in card gets a new `fnpd-` id with `replaces`: the built-in card keeps its progress and is hidden in this learner's path only; the new card starts new.
- A private card that changes keeps its id, so progress is kept. A new card starts new.
- A removed card leaves the path; its history is kept and its id is retired. A later revision may not give a retired id to a different card; the app refuses that file (2.2, task 12).
- A new language with no built-in course (Tolu) omits the built-in rows.

## Design choices (tweaks)
Summary: A four counts then lists, B filter chips over one list. Progress: A one block with How it works, B a line on each row. Retired ids: A explained on the page, B a one-line row that opens a sheet.

## Open questions for the owner
1. A later edit keeps the id even if the meaning changed. Right, or must a meaning change take a new id as in the course rule? The app cannot tell a fix from a new meaning.
2. An edited course card starts new. Offer "carry my progress over from the course card"?
3. For one update Removed and Retired ids are the same cards; the summary adds earlier retired ids to give a total. Merge into one count?
4. Counts first (A) or chips over one list (B)? One block (A) or a line per row (B)?
5. List units and decks as well, or only cards?

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
