# Reviewer screens: self-check and notes

Companion to `reviewer-ux.html` (Plan-Reviewer-UX, decisions 1 to 9c; no issue yet). Build exactly the decisions in `wiki/Plan-Reviewer-UX.md`; this page invents none. Controls: theme, example course (Hindustani or Bengali), text size (1.0x, 1.2x, 1.4x; 1.4x is the app's cap and the default), and a highlight of what changed on existing screens. Screens that are entirely new carry no highlight.

Open the page: open `docs/mockups/reviewer-ux.html` in a browser (it needs only the Google Fonts stylesheet).

## Design rules (owner feedback on PR #1651: avoid superfluity)
Delete anything that restates the title, the state or the screen; review by exception (a card is fine unless flagged); one primary action per screen; no explanatory text on cards (the first-use "How reviewing works" covers it); state shown by icon and colour, not words.

## Screens
1. Review queue: 1a entry (Session tab, one Resume button); 1b Flagged and contested tab (each row is the pill plus the reason, one primary "Review all 9", which is also the flagged-only mode); 1c to 1e the card; 1f end of 20 ("Continue with all cards", Close).
   - Header is the unit name and one compact "Card 7 of 20" line with its progress bar. Facets are in card order: word, reading, IPA, meaning, example, note, unit, offence, audio.
   - Word, meaning, example, note, unit and offence show their content and a flag icon only. Reading, IPA and audio show a tick and a flag; one not yet answered has an accent outline.
   - One button at the end of the scroll: "All good" when nothing is flagged (marks the unflagged plain facets right), "Done" once any facet is flagged. It is disabled until reading, IPA and audio are answered (1c disabled, 1d "All good", 1e "Done").
2. Pointer tags: 2a reading (engine candidates, prefilled field, paste), 2b spelling (dictionary variants, card reading beside the field, one-line keyboard hint), 2c plain field fallback. The eleven tags, combinable, the facet's own first; a tag alone flags the card. Scrim tap cancels, so there is no Cancel button.
3. Second speaker: 3a blind verdict (the card screen with no earlier answer; here "Needs another speaker's check" informs), 3b open proposal (original beside proposal, Accept, Reject, Offer another), 3c rival fixes (pick one), 3d unit digest (tick or flag icons, a Changed or Contested pill, the reason shown only after the verdict).
4. Deck view: 4a "Review this unit", 4b "Review this card", 4c the all-details review screen (the same card screen, "Card 5").
5. Settings > Reviewing: 5a two new rows, 5b paste the key, 5c tier and assigned courses, 5d pick a course for the check (cooldown and "use a reviewer key" shown as one short line), 5e the quiet offer after a top-band placement ("No thanks", once per course).
6. Card detail: the small "Checked by 3 speakers" line.

## Owner rules checked on the page
- No quorum number and no "2 of 2" or "needs 2" wording. The words "Needs another speaker's check" appear only on the blind verdict (3a). The only count is the card-level "Checked by 3 speakers" (3 on purpose).
- No course-level reviewer count; no file-level reviewed notice (decision 4, reading to confirm).
- The shortcut is gone as a panel: "All good" marks word, meaning and example only; reading, IPA and audio are each answered with their own tick or flag.
- The eleven tags are exactly the plan's list.

## Choices I made that the plan does not fix (confirm)
1. The entry tabs live on a "Reviewing" page reached from Settings > Reviewing. Flagged-only mode is the "Review all 9" button on the Flagged tab.
2. Flagging is a flag icon on the row; it opens the tags sheet. Note, unit and offence rows behave like the plain facets (flag only).
3. A card shows all nine facets on one scroll.
4. Closing mid-session keeps answers (plan decision 9); the page shows this only by the close icon, not in words.
5. The check page shows a per-course cooldown ("Retake in 5 days"); a course with no check says "Use a reviewer key".
6. Example words, spelling variants and reading candidates are illustrative, not real engine or lexicon output.
7. The "checked by" line sits under the example, in small muted text.

## Contrast self-check (WCAG 2.1)

Computed from the app palette in the page (`ColorScheme.fromSeed`, forest seed; same tokens as `topic-page.html`).

| Pair | Light | Dark |
|---|---|---|
| Body text on the screen | 16.3:1 | 14.3:1 |
| Body text on a facet card | 15.5:1 | 13.3:1 |
| Muted text on a facet card | 8.4:1 | 10.1:1 |
| Muted text on the high container | 7.6:1 | 8.5:1 |
| Tick state and links (primary) on a facet card | 5.8:1 | 10.1:1 |
| Filled button text on primary | 6.5:1 | 7.7:1 |
| Shortcut text on its tonal box | 7.2:1 | 7.2:1 |
| Flag state and amber chip text (amber) on a facet card | 5.4:1 | 7.8:1 |
| Amber chip text on amber | 5.9:1 | 7.7:1 |
| Flagged tag text on blue | 5.7:1 | 7.8:1 |
| Outline on a facet card (graphic, needs 3:1) | 4.1:1 | 5.4:1 |

Text needs 4.5:1. No cue is colour alone: answered rows use a tick icon, flagged rows a filled flag and the tag names, and "Flagged", "Contested" and "Changed" are words in their pills; the unanswered outline is accompanied by the disabled button. Icon buttons and rows are at least 48 dp high. Checked in Chromium (Playwright): light and dark, Hindustani and Bengali, 360 dp phone frames, 1.4x text, every frame looked at, no script errors, no horizontal page scroll at 390 px wide.
