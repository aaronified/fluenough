# Culture in the course: self-check and notes

Companion to `culture-in-course.html` (#1134, owner additions on #1133). Culture items are woven through the path and Today at the learner's level, and each item lets the learner meet the person behind it. All quoted texts and facts (dates, eras, legacy lines) are examples for a bilingual reviewer to check, including the Premchand and Tagore passages, the Machado and Bashō lines and every portrait credit.

## Screens
1. A path unit with one culture item between lessons (bonus or counted). 2. The item at the learner's level: a short proverb at A1, a stanza at A2, a passage with gloss at B1; the source line (author, work, date, public-domain basis); inline a creator chip and one legacy line. 3. On tap: the creator card as a bottom sheet: image with credit and licence line (or a placeholder when no licensed image exists), name, dates, era in the language's tradition, a bio at the learner's level, "Still alive today" (one or two concrete modern examples), and a timeline strip. 4. The full timeline screen: works the learner has met, this work, and "Today". 5. Today with a culture row, skippable. 6. Settings: the switch, too-advanced handling, items per unit, counting toward progress, creator and legacy. 7. A too-advanced item: not shown, or shown with support (gloss, lock, not counted, not scheduled). 8. The full culture deck from the course, with people. 9. Creator cards for a poet, a singer, an actor and a speaker across eras (Kabir, Lata Mangeshkar, Toshirō Mifune, Sheikh Mujibur Rahman), with licensed and placeholder images.

## What is inline and what opens on tap
Inline: item text, reading, meaning, source line, creator chip (name, dates, era), one legacy line. On tap: the creator sheet (image, bio, full legacy, timeline strip) and the timeline screen. An anonymous proverb shows "No single author" and no sheet.

## Design choices (tweaks)
Culture on or off; too advanced A not shown or B shown with support; path progress A bonus or B counts; creator image licensed or placeholder; timeline A strip plus screen or B full list in the sheet.

## Open questions for the owner
1. How many items per unit (1 proposed); bonus or counted. 2. Too advanced: hidden or shown with support. 3. The people: chip plus sheet, or a full person page; timeline form. 4. Images: is a placeholder acceptable for living-memory figures, or show none? Who checks licences? 5. Era names in the language's own tradition beside Western dates: always, or some courses. 6. Legacy ("Still alive today"): where it sits (creator sheet and one line inline here), and whether political figures such as a speaker belong. 7. Bios and legacy written at A1, A2 and B1 per person with bilingual review: is that scope acceptable?

## Contrast self-check (WCAG 2.1)

Computed from the app palette used in the page (`ColorScheme.fromSeed`, forest seed; same tokens as `progress-placement.html`).

| Pair | Light | Dark | Needed |
|---|---|---|---|
| Body text on the screen | 16.3:1 | 14.3:1 | 4.5:1 |
| Muted text (`onSurfaceVariant`) on the card | 8.4:1 | 10.1:1 | 4.5:1 |
| Muted text on the high container | 7.6:1 | 8.5:1 | 4.5:1 |
| Selected tab or link (`primary`) on the screen | 6.2:1 | 10.9:1 | 4.5:1 |
| Chip text on `secondaryContainer` | 7.2:1 | 7.2:1 | 4.5:1 |
| Filled button text on `primary` | 6.5:1 | 7.7:1 | 4.5:1 |
| Professional tag (amber) text | 5.9:1 | 7.7:1 | 4.5:1 |
| Above-level tag (amber outline and text) on the screen | 5.7:1 | 8.5:1 | 4.5:1 |
| Public-domain tag text | 5.7:1 | 7.8:1 | 4.5:1 |
| Outline (`outline`) on the screen | 4.3:1 | 5.8:1 | 3:1 (graphic) |

No cue is colour alone: a lock icon and the words "above your level", the word "Professional", the word "Completed" and a tick all carry the meaning. Checked in Chromium (Playwright) at deviceScaleFactor 2, light and dark, 1.4x text, 360 dp, with no horizontal page scroll.
