# Culture recommendations: self-check and notes

Companion to `culture-recommendations.html` (owner addition, 2026-11-12). Popular works the app points to but does not reproduce: book, film, series, song, play, podcast. Titles, dates and plot lines are examples for a reviewer to check.

## Screens
1. Browse list with kind chips (counts) and a short briefing per row; the open row shows the briefing, length, "Not included in the app" and the action "I've completed this". Public-domain works carry a badge and, when quoted in a deck, "Also in your culture deck: ...". 2. The briefing as a close-up (A) or a sheet (B). 3. Home: what the learner has completed (cover strip, or one line with a count). 4. The questions screen for a completed work: comprehension questions in the target language at the learner's level. 5. Rules at a glance.

## Rules shown
- Books appear only for learners who learn scripts. A script-only learner sees only books in that script (Devanagari for Hindustani, Bengali script for Bengali; a book in the Perso-Arabic script is not shown to a Devanagari learner). Other kinds follow the level rules and appear once the language starts.
- Above-level works are hidden with a count.
- Public-domain works that are also quoted in a deck say so (Idgah, The Postmaster, Amar Shonar Bangla).

## Open questions for the owner
1. Briefing in the list or a sheet; at whose level. 2. Self-reported completion: enough, or questions first? 3. Progress or home only; strip or one line. 4. A1 learner who reads the script: do books above their language level appear? 5. Hindustani script filter follows the chosen script. 6. Source of the list and whether to link out. 7. Question sets: authoring, three per work, works with none.

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
