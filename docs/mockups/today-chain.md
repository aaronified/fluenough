# The Today chain: self-check, notes and open questions

Companion to `today-chain.html` (owner, 2026-10-23: "Do all the mockups needed for the today chain together, in one screen."). The page holds only the screens and their tweak controls, with what is new or changed outlined in red. The checks and notes are here. Nothing below is decided; every open choice is a tweak control on the page.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed (the tokens of the deck page and teach card mockup, now built and removed), light and dark, Hindustani and Bengali examples (readings follow the course: no final a in Bengali). Theme, course and highlight are global controls; each section has its own.

## Screens

1. **Today** (#521, #485, #680). The two starts (Start lesson, Review) are removed (shown struck through) and become one ring that fills toward the daily budget, with the button inside ("Ring progress", owner, 2026-10-21). Under it: minutes ("12 of 15 min") and the split of reviews and new words. States: not started, in progress (button reads Continue), done, and Catching up (a banner, "Catching up: no new words today", no new words in the split). The Situations card (#724) and the existing tag practice (#499, built in #720) sit below. Known cards come up a few at a time per deck (#680); the page shows an optional one-line note.
2. **Minutes a day** (#485, "Settings part now"). On each course's card in Languages I'm learning: presets 5, 10, 15, 20, 30 and a custom value from 5 to 60, default 15, with "About 51 cards a day, at 17.5 seconds a card" (minutes x 60 / 17.5). The onboarding step waits for #474 and is not drawn.
3. **Cheatsheets** (#724). A Situations list, one sheet (Hailing a cab: script, reading, meaning, audio, mastery chip, Practise this sheet) and its inspect view (card data, notes, example, IPA, card id, deck, audio file, other sheets the card is on, the learner's progress).
4. **Decks page focus** (#723). A "Learn only..." chooser, one generic feature for every course (owner, 2026-10-23: "These focus groups will need to be present in all languages."). It lists every script the course has, separate vocabulary layers the course defines as data, and the parts every course has (grammar primer, verb forms, a theme). Examples: Hindustani (Devanagari or Perso-Arabic; Persian-leaning and Sanskrit-leaning words), Bengali (one script; one layer, Sanskrit-leaning, as an illustration) and Spanish (no options: only the parts). Script and vocabulary are separate (owner, 2026-10-23: "Script separate, persian vocabulary separate. Same for sanskrit vocab."; "Script will also have all scripts in the language."). The result is a track in the path's order with one Start.
5. **Conversation** (#722). Two speakers' turns transcribed live, script with reading under it, an optional meaning and tap-to-look-up with "Add to my words", turn buttons or a paired phone, and an end sheet with saving.

## Open questions (not decided; each a tweak control)

**Today (#521, #485, #680)**
1. Does "12 of 15 min" mean minutes done so far, or the minutes the day's queue is worth? Control "Ring and 12 of 15 min show".
2. Is the split (reviews and new) shown under the ring, or hidden since the app decides it?
3. Catching up: only the line, or also the estimate ("80 reviews, about 23 min. At 15 min a day you will catch up in 2 days.") and the "Give me 15 minutes this week" button from #485's 2026-10-12 answers?
4. Does Today say anything about sampling of known cards (#680)?
5. Does the Situations card sit on Today at all, or only under Decks?
6. What does the button say when the budget is done (here a check and "Done"), and can the learner keep going?

**Minutes (#485)**
7. Control style: presets plus custom (as #485 wrote it), a slider, or a stepper.
8. Is the "cards a day" line shown, given the 17.5 s assumption changes to the learner's own median after 20 answers?

**Cheatsheets (#724)**
9. Does a sheet show only what the learner has learned, or everything with unlearned items marked (from the issue)?
10. Where does inspect open from: an icon on each row, or one entry in the app bar? Does inspect step through a sheet's cards?
11. Which situations ship first and for which languages; the sheet file's place and fields (from the issue; not a screen question).

**Focus (#723)**
12. Does the script option only show the course in a script, or teach the script itself (letters, reading)? Control "Script option".
13. Does a track change the path's own progress, or is it a view of it?
14. The Decks page only, or Today too? Control "Entry" covers the Decks button only.
15. Several options at once: one script plus both vocabulary layers is drawn; may a part (grammar primer, a theme) be combined with them?
16. Data each course would need (owner, 2026-10-23: all languages). Today's deck data has no field for these, so a course would define:
    - **Scripts:** the list of scripts the course offers, with each one's code and name, which one is the default, and which decks are the script guide and reading decks of each. Hindustani: Devanagari, Perso-Arabic; Punjabi: Gurmukhi, Shahmukhi; Bengali: Bengali only.
    - **Vocabulary layers:** for each layer a key, a name, and which cards belong to it. For Hindustani, the cards' Persian-leaning and Sanskrit-leaning synonyms are on the card (decided 2026-10-18), so a layer is a tag or a synonym kind on a card. Other courses define theirs (an example: Bengali's tatsama words), or none (Spanish here).
    - **Parts every course has:** the rules decks, the verb tables and the themes, already in the deck data.
    - Who writes the layers for each language, and whether a course with no layers simply hides the group (as drawn for Spanish).

**Conversation (#722)**
17. Who talks: two people on one phone, or two phones?
18. Are the speakers told apart by the app, or do people tap to take turns (drawn: tap)?
19. Recognition: on-device only, online, or on-device with online where missing (hi-IN noMatch showed the limits).
20. What is shown: the transcript only, plus meaning, or plus tap-to-look-up and "Add to my words".
21. Is the transcript saved, and may its words feed the learner's reviews?
22. One feature with Plan-Ai-Conversation (a conversation with an AI on the learner's own key), or two?

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, icons and outlines 3:1. All 52 pairs pass.

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
52
| light | body text | onS  on  s | 16.33 :1 | 4.5 :1 | pass |
| light | captions, readings | onSv  on  s | 8.9 :1 | 4.5 :1 | pass |
| light | captions on cards | onSv  on  sLow | 8.45 :1 | 4.5 :1 | pass |
| light | text on cards | onS  on  sLow | 15.5 :1 | 4.5 :1 | pass |
| light | text on raised blocks | onS  on  sHigh | 14.01 :1 | 4.5 :1 | pass |
| light | captions on raised blocks | onSv  on  sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | chip selected, tonal button, audio, Learning, ring button done | onSc  on  sc | 7.25 :1 | 4.5 :1 | pass |
| light | filled button, Known, New split, ring button | onP  on  p | 6.46 :1 | 4.5 :1 | pass |
| light | banner (Catching up) | onTC  on  tC | 7.24 :1 | 4.5 :1 | pass |
| light | text button and info icon on cards | p  on  sLow | 5.85 :1 | 4.5 :1 | pass |
| light | icon on raised block | p  on  sHigh | 5.29 :1 | 3 :1 | pass |
| light | outline against page | ol  on  s | 4.28 :1 | 3 :1 | pass |
| light | outline against card | ol  on  sLow | 4.06 :1 | 3 :1 | pass |
| light | ring fill against track | p  on  sc | 4.99 :1 | 3 :1 | pass |
| light | ring fill against page | p  on  s | 6.16 :1 | 3 :1 | pass |
| light | unselected chip text on page | onSv  on  s | 8.9 :1 | 4.5 :1 | pass |
| light | unselected chip text on card | onSv  on  sLow | 8.45 :1 | 4.5 :1 | pass |
| light | checkbox border on sheet | onSv  on  sLow | 8.45 :1 | 3 :1 | pass |
| light | change tag | onE  on  E | 6.46 :1 | 4.5 :1 | pass |
| light | change outline on page | E  on  s | 6.16 :1 | 3 :1 | pass |
| light | change outline on card | E  on  sLow | 5.85 :1 | 3 :1 | pass |
| light | live dot on card | E  on  s | 6.16 :1 | 3 :1 | pass |
| light | sheet title on sheet | onS  on  sLow | 15.5 :1 | 4.5 :1 | pass |
| light | own turn bubble | onSc  on  sc | 7.25 :1 | 4.5 :1 | pass |
| light | own turn bubble selected word | onP  on  p | 6.46 :1 | 4.5 :1 | pass |
| light | selected word against own bubble | p  on  sc | 4.99 :1 | 3 :1 | pass |
| dark | body text | onS  on  s | 14.33 :1 | 4.5 :1 | pass |
| dark | captions, readings | onSv  on  s | 10.88 :1 | 4.5 :1 | pass |
| dark | captions on cards | onSv  on  sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | text on cards | onS  on  sLow | 13.28 :1 | 4.5 :1 | pass |
| dark | text on raised blocks | onS  on  sHigh | 11.17 :1 | 4.5 :1 | pass |
| dark | captions on raised blocks | onSv  on  sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | chip selected, tonal button, audio, Learning, ring button done | onSc  on  sc | 7.25 :1 | 4.5 :1 | pass |
| dark | filled button, Known, New split, ring button | onP  on  p | 7.68 :1 | 4.5 :1 | pass |
| dark | banner (Catching up) | onTC  on  tC | 7.24 :1 | 4.5 :1 | pass |
| dark | text button and info icon on cards | p  on  sLow | 10.05 :1 | 4.5 :1 | pass |
| dark | icon on raised block | p  on  sHigh | 8.46 :1 | 3 :1 | pass |
| dark | outline against page | ol  on  s | 5.84 :1 | 3 :1 | pass |
| dark | outline against card | ol  on  sLow | 5.4 :1 | 3 :1 | pass |
| dark | ring fill against track | p  on  sc | 5.51 :1 | 3 :1 | pass |
| dark | ring fill against page | p  on  s | 10.86 :1 | 3 :1 | pass |
| dark | unselected chip text on page | onSv  on  s | 10.88 :1 | 4.5 :1 | pass |
| dark | unselected chip text on card | onSv  on  sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | checkbox border on sheet | onSv  on  sLow | 10.08 :1 | 3 :1 | pass |
| dark | change tag | onE  on  E | 7.72 :1 | 4.5 :1 | pass |
| dark | change outline on page | E  on  s | 10.89 :1 | 3 :1 | pass |
| dark | change outline on card | E  on  sLow | 10.09 :1 | 3 :1 | pass |
| dark | live dot on card | E  on  s | 10.89 :1 | 3 :1 | pass |
| dark | sheet title on sheet | onS  on  sLow | 13.28 :1 | 4.5 :1 | pass |
| dark | own turn bubble | onSc  on  sc | 7.25 :1 | 4.5 :1 | pass |
| dark | own turn bubble selected word | onP  on  p | 7.68 :1 | 4.5 :1 | pass |
| dark | selected word against own bubble | p  on  sc | 5.51 :1 | 3 :1 | pass |

## Behaviour checks (Chromium, Playwright)

- Loaded in Chromium at 1280 px wide: no page errors, no console errors, no horizontal page scroll.
- Every tweak control in every section was pressed in both courses, and every option, chip, checkbox, stepper button and tappable word clicked: no errors.
- Screenshots of each theme were taken of the full page (see the report).
- Fonts: Roboto, Noto Sans Devanagari and Noto Sans Bengali from Google Fonts; where offline the system fallback is used.
