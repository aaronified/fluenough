# Search results by type: self-check and notes

Companion to `search-results-tabs.html` (#1140, #1137, #1139). Owner approval is needed before any build. Controls: theme, course (Japanese, Spanish, Hindustani, Bengali), highlight, and three real design choices (tab bar, above-my-level, professional). What is new is outlined in red.

## Screens
1. Results with typed tabs. A native TabBar; only types with results get a tab; the label carries the count; the best-match tab is first (dot) and opens first; the last tab used is remembered for the session. Distinct rows: situation (scene, phrase count, level), topic (language, what it covers, coverage bar), deck (kind), grammar concept (name, example with reading), word (word, reading, meaning, mastery, audio), unit (path position), culture (line, source, level). No Culture tab appears for Japanese because nothing matched.
2. Typo-tolerant: "teform" finds "te-form", with a "Showing results for" line and a way to search the typed text.
3. A professional situation: found only here, marked "Professional", with an "Add to my courses" action and a profession filter. Never on Today, the path or deck lists.
4. Results above the learner's level (A2 here): marked with a lock and the level, or folded under one row.
5. No results, with suggestions. 6. Empty state with recent searches and type hints; no tabs before typing.

## Design choices (tweaks)
- Tab bar: A one scrollable row; B first four plus More.
- Above my level: A shown, dimmed and marked; B folded under "Show N above your level".
- Professional: A inside Situations with a marker; B its own tab.

## Open questions for the owner
1. Tab bar A or B? 2. Above my level: shown and marked, or folded? Default and a setting? 3. Professional inside Situations, or its own tab? Profession as a chip filter? 4. Do Words group by language when the learner has several?

## Notes
- A new type is data (a `kind` field), not a new row widget: the tab list is built from the kinds that have results.
- Search matches only the `decks-live` index and bundled cards; professional decks carry a hidden flag and the `professional` kind (#1139).

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
