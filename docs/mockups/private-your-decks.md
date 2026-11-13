# Private languages, Your decks: self-check and notes

Companion to `private-your-decks.html` (#1017, `wiki/Plan-Private-Languages.md` tasks 13, 14, 15, 16; sections 2.3, 2.7, 2.11). Awaiting the owner's approval; build nothing from it before. Controls: theme, example language (Bengali or Hindi for the changed course), packages (three active, or a fourth installed), highlight, and four design choices.

## Screens
1a and 1b (and 1c with a fourth package). Your decks: the Add a private language action, Download a course to change, Get a starter package, then a group per package. Each group: name and own name, package id and revision, tags in words (Changed course or New language, Privately modified, Active or Not active, Needs a free slot), size against the 10 MB limit with a bar, what it holds, what it is based on, an Active switch, and Update, Export and Remove.
2. The fourth package: "Turn one off first" with the least recently studied preselected.
3. Remove asks first (alert dialog, Remove in the error colour); progress is kept.
4. The no-voice notice where the learner meets it (Tolu, six cards, no voice).
5a, 5b, 5c. The "privately modified" marker on the course page, the path page and the Today header.
6. The empty state with Add a private language.

## Content used
A private Bengali variant package `fnpd-bn` (41 cards changed, a path of 38 units, 2.4 MB), a tiny constructed language `qaa`, named Tolu (6 cards, 2 units, 6 KB), a Hindustani exam path `fnpd-hi`, and a Telugu short path `fnpd-te` as the fourth. Hindi and Bengali show in the headers and groups.

## Rules shown
- At most three active; the fourth is installed but off, tagged "Needs a free slot" in words, and nothing is deleted (2.11, task 13).
- The wording of the capability notice is the owner's: "This language has no voice on your phone: speaking and sound drills are hidden." Reading and writing drills stay (decision 5, task 14). The learner can turn the language off and on to check again.
- Remove deletes the files, not the review history (ADR-0020); the built-in course returns with its own path.
- Export writes the same `.fnzip` through the system file dialog; Update opens the file chooser and then the update summary (`private-update-summary.html`).
- Disk use is shown on the page (2.11). No cue is colour alone: every tag has a word and an icon.

## Design choices (tweaks)
Group: A all open, B first open and the rest folded (header is a native button with `aria-expanded`). Fourth package: A sheet at once, B banner and the same sheet from the switch. No-voice notice: A block in the group, B a "No voice" tag with a Why? sheet. Modified tag: A tag under the title (needs a 48 dp hit area around a small tag), B a one-line row that opens Your decks.

## Open questions for the owner
1. Fourth package: sheet at once (A) or banner first (B)? Preselect the least recently studied?
2. Fold the groups (B) or keep every action visible (A)?
3. No-voice notice: block (A) or tag and sheet (B)?
4. Modified marker: tag (A) or one-line row (B)?
5. Remove keeps the progress for good; add "Remove and delete my progress"?
6. Plan section 2.2 says an unchanged built-in card stays by `ref`; the Download a course to change action is offered only for courses already on the phone (risk 10).

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
