# Reviews to send: self-check and notes

Companion to `reviews-to-send.html`. One home for sending reviews. Controls: theme, example course (Bengali or Hindustani, which deck is expanded), text size (1.4x, the app's cap, is the default) and a highlight of what changed on existing screens (frames 4 and 5; frames 1 to 3 are new and carry none).

## What it replaces

Today there are six entry points: the Settings > Reviewing row "Reviews to send", the row "Send the last mail again", the "Send reviews" sheet, the "Send review" button on the unit review and Offensive words review, the bottom bar of the "Reviewed, not sent" page, and "Send answers" on Daily questions. The two rows were one row in two states: tapping "Send the last mail again" moves the decks back to waiting, so it vanishes and "Reviews to send" appears. The app cannot know that a mail went, so the "last mail" row also showed for drafts that were discarded.

Now: one page, "Reviews to send". The Reviewing page keeps one row for it. The "last mail" row and the sheet go. The unit review button, the Offensive words button and "Send answers" only open the page. The "Reviewed, not sent" page becomes this page.

## Frames
1. The page: a tickable group per deck (deck, language, cards, a signed-off mark), expanded to every item that will be sent; daily answers as one group per language with their own tick; one primary "Send" whose label counts only what is ticked (1b: Hindustani daily answers unticked, so 2 answers); 1c a tap on a card offers Change or Drop from this mail.
2. Nothing to send and no mail ever opened: the Reviewing page without the row; the page, if reached, shows one short message.
3. After sending: the Sent section, by date, with "Send again" on each mail. 3b: Send again puts that mail's decks back in the unsent list; it sends nothing itself.
4. Settings > Reviewing: one row, the "last mail" row removed.
5. Entries: the unit review foot and Daily questions, each opens the page.

## Owner rules checked
- One primary action per screen (the Send button); "Send again" and "Change" are secondary. State is shown by icon (box, tick, flag, signed-off seal), no repeated headings, no helper sentence restating a control.
- No quorum wording, no course-level counts beyond today's ("N decks waiting", "N answers").
- Sent mails say "Send again" only, no "last mail" text. "Send again" is shown only for a mail that was opened.

## Choices I made that you did not fix (confirm)
1. The Reviewing row's single sub-line is "2 decks · 2 answers" (replaces the two sub-lines).
2. Send count label: "Send 2 decks and 2 answers"; only ticked groups count.
3. Items per card: facet answers (Correct, or tags plus fix text), suggestions as Now / Yours / Why, word rating, answer to a proposal, alike check. Their exact wording ("Sound differs", "Easy", "Accepted", "Different from") is illustrative.
4. Tapping a card opens a sheet with Change and Drop from this mail; "drop" means not sent and kept as reviewed on the device (guess; could also discard the review).
5. Honest wording: the app opened your mail app and cannot tell if it went. The page shows this only as the mail icon and the "Send again" control, not a sentence; say if you want the sentence.
6. Send again removes that mail from Sent until it is sent again (3b).
7. A mail lists its decks and answers count; decks sent in several mails appear in each.
8. The empty page is only the icon and "Nothing to send".
9. Daily answers group: question, Answer, Reason, Why; one group per language.
10. Mail still marks everything sent when the mail app opens (unchanged).
11. The "Waiting for review" row in 2a stays as today (not redesigned here).

## Contrast self-check (WCAG 2.1)

Same app palette tokens as `reviewer-ux.html` (`ColorScheme.fromSeed`, forest seed); the pairs are the same classes of pairs, so the numbers are the ones in `reviewer-ux.md`.

| Pair | Light | Dark |
|---|---|---|
| Body text on the screen | 16.3:1 | 14.3:1 |
| Muted text on a card (group counts, labels) | 8.4:1 | 10.1:1 |
| Tick, seal and links (primary) on a card | 5.8:1 | 10.1:1 |
| Filled button text on primary | 6.5:1 | 7.7:1 |
| Flag and tag text (amber) on a card | 5.4:1 | 7.8:1 |
| Tag text on amber | 5.9:1 | 7.7:1 |

Text needs 4.5:1. State is never colour alone: ticks, flags, the seal and the box carry it. Rows and icon buttons are at least 48 dp high. Checked in Chromium (Playwright): light and dark, Bengali and Hindustani, 1.4x text, no script errors, no horizontal scroll at 390 px wide.
