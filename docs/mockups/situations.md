# Situations: self-check, notes and open questions

Companion to `situations.html` (#724; owner answers, 2026-10-30: "Everything, unlearned marked"; first situations taxi / getting around, groceries / shopping, restaurant, doctor / pharmacy, traffic stop, rail station; "Telugu first. Other decks show the Situations card blank, with the upcoming pill"). It replaces the #724 section of `today-chain.html`, which can lose that section once this is approved. The page holds only the screens and their tweak controls; new things are outlined in red.

Phone 360 dp at 1.4x text (#505), `ColorScheme.fromSeed` of the forest seed (tokens as in the other mockups), light and dark. Telugu is the course with sheets; Hindustani and Bengali show the blank state, and a "Preview sheets in other courses" control draws a sheet in their scripts only to check layout.

## Screens

1. **Today.** Under the daily button, a Situations heading with six situation buttons (3 by 2): icon, one word (Taxi, Shops, Eat, Doctor, Traffic, Rail), and the count of items not learnt yet in small type under it. Icons are Material ones in the tonal circle used by the Today cards, one accent for all (not skill colours: situations are not skills). A small Offline mark sits beside the heading. For a course without sheets the same buttons are dimmed to 38% (the feature-incoming opacity) with an "Upcoming" pill and no counts.
2. **Sheet** (Taxi). Phrases, then words; each row has script, reading, meaning, a play button and an optional info icon. A dot marks items not learnt yet; every item is shown. "Practise this sheet" at the bottom drills the sheet, teaching the new items first. Icon-only controls have long-press hints (#913).
3. **Inspect.** One card in full: script, reading, audio, notes, example, IPA, type, card id, deck and unit, audio file, the other sheets it is on, and the learner's progress. Numbered chips jump to a card (dot = not learnt), Previous and Next step, "Open in deck" goes to the card's deck. An alternative lists every card in one scroll.

## Tweak controls

Entry (3 by 2 grid, scrolling row, one card opening a list), unlearned count (shown, hidden), shown items (everything, learned only), mark (dot, "New" chip), inspect opens from (icon per row, app bar), inspect shows (one card, all cards), course, preview, highlight, theme.

## Open questions for the owner

1. Entry on Today: six buttons in a 3 by 2 grid (default), a scrolling row, or the one "Situations" card of today with a list inside? Six buttons cost about 170 dp of Today's height.
2. Labels are one word: Taxi, Shops, Eat, Doctor, Traffic, Rail. Are these right for "taxi / getting around", "groceries / shopping", "restaurant", "doctor / pharmacy", "traffic stop" and "rail station"? Does "Traffic" read as "traffic stop"?
3. Is the count of unlearned items wanted on the buttons at all, and is "N new" the right word (the app's mastery chip says New)?
4. "Unlearned" is read as mastery New. Are items that are Learning unmarked? Or is a card "learned" only when Known?
5. Should the mark be a dot (default, quiet) or a "New" chip? A dot is colour plus shape only; its long-press hint and screen-reader label say "Not learnt yet".
6. Where do unlearned items sit: in the sheet's order (drawn) or after the learned ones?
7. Practise this sheet: does it teach only the new cards first and then revise (drawn in the toast), or always the whole sheet? When nothing is new, does it become "Revise this sheet"?
8. Do the sheet's phrases and words stay two groups (Phrases, Words) or one list in the file's order? Does the sheet file let an author add their own groups within a situation?
9. Is the Offline mark needed, since every sheet is offline? Does it only show after the audio is downloaded?
10. Inspect: one card with steps (drawn) or all cards in one scroll; entry from an icon per row or from the app bar? Inspect for learners at all, or only in a developer or reviewer setting as the decks' /inspect is?
11. Blank state: dimmed buttons with the "Upcoming" pill (as drawn), or the existing "Feature incoming" badge text? The issue says "upcoming pill"; the app's badge reads "Feature incoming".
12. Tapping a dimmed button: the "Feature incoming" toast, or nothing?
13. The six sheets are drawn only for Taxi; the other five share its structure. Is that enough? Counts on the other buttons are invented.
14. Telugu text, readings (no final ṁ occurs), IPA and card ids are my drafts for layout and need a Telugu reviewer; card ids here (`te.phr...`) are placeholders, since the real ids come from the decks. A sheet repeats existing cards by id; some situations (Taxi, Traffic) would share cards.
15. Hindustani and Bengali sheets are a layout preview only (Hindustani in Devanagari). Are the Perso-Arabic script sheets for Hindustani to be drawn when its sheets come?
16. Where is the sheet title translated: "the title and order go in each native layer" is the decision, so a Hindi learner sees "Taxi" in the English layer here (the app's one language). Right?
17. Situation buttons and #723's focus tracks: does a track (script, vocabulary layer) filter the sheets' cards? Not drawn.
18. Format (file place and fields, DECK-FORMAT, validator) is not a screen question and is not decided here.

## Self-check results

WCAG contrast computed in the page's JS (`window.__contrast`) and run in Chromium for both themes. Text 4.5:1, icons and outlines 3:1. All 48 pairs pass. The dimmed buttons at 38% are disabled content, exempt as in M3, and carry the Upcoming pill at full contrast.

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text | onS on s | 16.33 :1 | 4.5 :1 | pass |
| light | readings, captions on page | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | situation tile label | onS on sLow | 15.5 :1 | 4.5 :1 | pass |
| light | tile count, sheet captions | onSv on sLow | 8.45 :1 | 4.5 :1 | pass |
| light | tile icon | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | Upcoming pill text | onSv on sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | filled button | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | playing audio button | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | audio button | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | not-learnt dot on page | p on s | 6.16 :1 | 3 :1 | pass |
| light | not-learnt dot on card | p on sLow | 5.85 :1 | 3 :1 | pass |
| light | New chip text | onSv on sLow | 8.45 :1 | 4.5 :1 | pass |
| light | New chip outline | ol on sLow | 4.06 :1 | 3 :1 | pass |
| light | Learning chip | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | Known chip | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | text on raised block | onS on sHigh | 14.01 :1 | 4.5 :1 | pass |
| light | caption on raised block | onSv on sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | card strip outline | ol on sLow | 4.06 :1 | 3 :1 | pass |
| light | strip number, current | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | toast | s on onS | 16.33 :1 | 4.5 :1 | pass |
| light | change tag | onE on E | 6.46 :1 | 4.5 :1 | pass |
| light | change outline on page | E on s | 6.16 :1 | 3 :1 | pass |
| light | change outline on card | E on sLow | 5.85 :1 | 3 :1 | pass |
| light | icons (info, offline) | onSv on sLow | 8.45 :1 | 3 :1 | pass |
| dark | body text | onS on s | 14.33 :1 | 4.5 :1 | pass |
| dark | readings, captions on page | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | situation tile label | onS on sLow | 13.28 :1 | 4.5 :1 | pass |
| dark | tile count, sheet captions | onSv on sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | tile icon | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | Upcoming pill text | onSv on sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | filled button | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | playing audio button | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | audio button | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | not-learnt dot on page | p on s | 10.86 :1 | 3 :1 | pass |
| dark | not-learnt dot on card | p on sLow | 10.05 :1 | 3 :1 | pass |
| dark | New chip text | onSv on sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | New chip outline | ol on sLow | 5.4 :1 | 3 :1 | pass |
| dark | Learning chip | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | Known chip | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | text on raised block | onS on sHigh | 11.17 :1 | 4.5 :1 | pass |
| dark | caption on raised block | onSv on sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | card strip outline | ol on sLow | 5.4 :1 | 3 :1 | pass |
| dark | strip number, current | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | toast | s on onS | 14.33 :1 | 4.5 :1 | pass |
| dark | change tag | onE on E | 7.72 :1 | 4.5 :1 | pass |
| dark | change outline on page | E on s | 10.89 :1 | 3 :1 | pass |
| dark | change outline on card | E on sLow | 10.09 :1 | 3 :1 | pass |
| dark | icons (info, offline) | onSv on sLow | 10.08 :1 | 3 :1 | pass |


## Behaviour checks (Chromium, Playwright)

- Loaded at 1280 px wide in light and dark with each course: no page errors, no console errors, no horizontal page scroll.
- Every tweak control pressed in all three courses, and the play, info, Practise and step buttons clicked: no errors.
- Screenshots of full pages were taken for light and dark (Telugu, Hindustani).
- Fonts: Roboto, Noto Sans Devanagari, Bengali and Telugu from Google Fonts; offline, the system fallback is used.
- Not checked: a real device, TalkBack and VoiceOver.
