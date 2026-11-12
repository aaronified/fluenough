# Topic page: self-check and notes

Companion to `topic-page.html` (#1137). Topics are language specific, deck-owned data on `decks-live` (Plan-Deck-Owned-Data), never app code. Examples: Japanese te-form, Spanish ser vs estar, Hindustani ne. Controls: theme, topic, learner level (A1, A2, B1), highlight, and three design choices.

## Screens
1. The topic page: name, language, level marker, coverage, a short intro, its units, decks and cards (each with level and mastery), and a Drill this topic action. 2. The drill chooser (how many, which skills). 3. Reached from the Search Topics tab. 4. Reached from the unit screen ("Topics in this unit" chips, at most four). 5. An above-level topic when a setting hides it.

## Rules shown
- Level-aware: a topic above the learner's level is shown with a lock and "above your level"; the drill uses only cards at or below the level and says how many; or the topic is hidden by a setting (B).
- Each result and row names the topic and language.

## Design choices (tweaks)
Layout A one scroll or B segments; drill action A sticky button or B header action plus sheet; above-level A shown and limited or B hidden.

## Open questions for the owner
1. Above-level default. 2. Sticky button or header action. 3. Layout. 4. Does a topic drill count toward unit progress? 5. How many chips per unit?

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
