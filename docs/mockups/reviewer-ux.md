# Reviewer screens: self-check and notes

Companion to `reviewer-ux.html` (Plan-Reviewer-UX, decisions 1 to 9c; no issue yet). Build exactly the decisions in `wiki/Plan-Reviewer-UX.md`; this page invents none. Controls: theme, example course (Hindustani or Bengali), text size (1.0x, 1.2x, 1.4x; 1.4x is the app's cap and the default), and a highlight of what changed on existing screens. Screens that are entirely new carry no highlight.

Open the page: open `docs/mockups/reviewer-ux.html` in a browser (it needs only the Google Fonts stylesheet).

## Shell
The facet questions reuse the daily-questions shell (`daily_questions_page.dart`): app bar, "Card n of total" with a progress line, the word, reading and meaning, a filled primary button and an outlined one, a text button, and the reason sheet for "not right" (`_ReasonSheet`, here the pointer tags sheet). Rows are cards on `surfaceContainerLow`, as in the app.

## Screens
1. Review queue: 1a entry (Session tab, Flagged and contested tab, "Check flagged and contested only" mode, resume); 1b the flagged tab; 1c a card with every facet (word, reading, IPA, meaning, example, note, unit placement, offence rating, audio) and the one-tap shortcut; 1d midway with a tag; 1e the end of 20 and "Continue with all cards", with closing at any time.
2. Pointer tags: 2a reading (engine candidates, prefilled field, paste, the card's reading, tags combinable), 2b spelling (lexicon variant chips, reading beside the field, one-line keyboard hint), 2c plain keyboard field fallback (note).
3. Second speaker: 3a blind verdict, 3b open proposal check (Accept, Reject, Offer another), 3c rival fixes pick-one, 3d per-unit digest with the reason shown only after the verdict.
4. Deck view: 4a "Review this unit", 4b "Review this card", 4c the all-details screen.
5. Settings > Reviewing: 5a the two new rows, 5b paste the key, 5c accepted (courses, tier), 5d "Take the check", 5e the quiet offer after a top-band placement ("No thanks", once per course).
6. Card detail: the small "Checked by 3 speakers" line.

## Owner rules checked on the page
- The quorum number appears nowhere, and no "2 of 2" or "needs 2" wording. Reviewer screens say "Needs another speaker's check". The only count is the card-level "Checked by 3 speakers" (3 on purpose, never the quorum value).
- No course-level reviewer count anywhere; the file-level reviewed or unreviewed notice is not shown (decision 4, reading to confirm).
- The shortcut covers word, meaning and example only. Reading, IPA and audio each show "Confirm separately" and have their own Right or tag.
- The eleven tags are exactly the plan's list. The replacement is optional; a tag alone sends the card to Flagged (1d, 2a).
- Blind verdict shows no earlier answer; the proposal view shows original beside proposal; "Why" text is advisory and shown after the verdict.

## Choices I made that the plan does not fix (confirm)
1. Where the entry tabs live: a "Reviewing" page with Session and "Flagged and contested" tabs, reached from Settings > Reviewing. The plan says only "separate tab".
2. Per-facet buttons are "Right" and a tag button whose label fits the facet ("Not right", "Wrong unit", "Offensive", "Audio wrong"); the tag sheet then offers all eleven tags, the facet's own first.
3. A card is shown with all nine facets on one scroll rather than one facet at a time.
4. The key sheet's "Remove the key from this phone" and the key string shown masked.
5. The check page shows a per-course cooldown ("retake in 5 days"), and a course with no check says "Ask for a reviewer key" (plan decisions 1 and 8).
6. Example words are illustrative. The Hindustani spelling variants and the reading candidates are not taken from a real engine or lexicon.
7. The "checked by" line is placed under the note, in small muted text.

## Contrast self-check (WCAG 2.1)

Computed from the app palette in the page (`ColorScheme.fromSeed`, forest seed; same tokens as `topic-page.html`).

| Pair | Light | Dark |
|---|---|---|
| Body text on the screen | 16.3:1 | 14.3:1 |
| Body text on a facet card | 15.5:1 | 13.3:1 |
| Muted text on a facet card | 8.4:1 | 10.1:1 |
| Muted text on the high container | 7.6:1 | 8.5:1 |
| "Right" state and links (primary) on a facet card | 5.8:1 | 10.1:1 |
| Filled button text on primary | 6.5:1 | 7.7:1 |
| Shortcut text on its tonal box | 7.2:1 | 7.2:1 |
| Tagged state and amber chip text (amber) on a facet card | 5.4:1 | 7.8:1 |
| Amber chip text on amber | 5.9:1 | 7.7:1 |
| Flagged tag text on blue | 5.7:1 | 7.8:1 |
| Outline on a facet card (graphic, needs 3:1) | 4.1:1 | 5.4:1 |

Text needs 4.5:1. No cue is colour alone: "Right" has a tick and the word, "Tagged" a flag icon and the word, tag chips a flag icon and their names, "Flagged" and "Contested" are words. Buttons and rows are at least 48 dp high. Checked in Chromium (Playwright): light and dark, Hindustani and Bengali, 360 dp phone frames, 1.4x text, no script errors and no horizontal page scroll at 390 px wide.
