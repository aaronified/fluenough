# Teach screen: self-check, notes and open questions

Companion to `teach-screen.html` (owner, 2026-10-29: "Every teach screen, regardless of content depth or breadth, looks like this", and, later the same day, that the review screens are perfect and the teach card must align with them). The page holds only the screens and their tweak controls, with what changed outlined in red. The checks and notes are here. Nothing below is decided; every open choice is a tweak control on the page.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark, Telugu, Hindustani and Bengali examples. Readings follow the courses: Telugu writes a word-final anusvara as `ṁ`; Bengali has `ô` and no final a (`jôl`, `bāṛi`, `sôtti`). Theme, course and highlight are global controls.

## What the screen is today

`lib/features/drill/teach_card.dart`, in `teach_drill.dart` under a `TeachSwipe` (#691, ADR-0024). A `Column` with `MainAxisAlignment.spaceEvenly` inside a scroll view laid out to the screen's height, with 14 dp between blocks: the word large and left-aligned with its speaker and IPA pill (and a 104 dp picture tile), a meaning tile that opens the dictionary, one note clamped to 4 lines, one warning. No foot: a swipe or an end-edge chevron goes on. Whatever the content, the same three blocks are spread over the full height, so a short card is mostly gaps and a long note is cut at 4 lines. Examples, forms and every note after the first are only in the dictionary popup.

## What the review screens do (the reference, drawn as built)

`RecognitionDrill` in `DrillFrame` (`lib/ui/widgets/drill_frame.dart`): a 64 dp header; a scrolling body (16 dp sides, 4 on top) holding a row with the skill pill and the deck name, 16 dp, then one `DrillCard` (40 dp corners, `surfaceContainerHigh`, 20 x 28 padding) as tall as its content with its children centred 12 apart; a fixed foot (16, 12, 16, 20). The question page's foot is the tall "Show answer" button. The answer page has the card with the answer in it as `TaughtDetails` draws it (the divider, the meaning at 28 sp, notes at 15/22, the first example in a `surfaceContainerLowest` box), and in the foot "How well did you know it?" over the four ratings, each with its interval.

**Owner decision, 2026-10-29: "Option b. But make the ratings four buttons in one row. Exactly replacing continue in the question screen. And retain all the current features of the question and answer sheet. Change absolutely nothing else."** The question page is drawn exactly as built. The answer page is drawn as built with two changes, outlined on the page: (a) Again, Hard, Good and Easy are four buttons in one row, in the foot where the Continue button sits (same 64 dp height, same 16 dp margins, 4 dp apart), instead of the built 2 x 2 grid at 1.4x; they keep their colours, labels and intervals, and the outer corners are rounded as in the built single-row layout; (b) a swipe on the card, with the end-edge chevron tab of `TeachSwipe`, continues as Good, exactly as tapping Good does (same grade, same recorded answer and interval).

## What the proposal changes

The teach card becomes the review's answer screen with the teach card's extras, so the two read as one family:

1. **One card, as tall as its content**, in the review's body: the same pill row (a tertiary "New word" or "New phrase" pill, the deck name), the same 40 dp card, content centred 12 apart. No `spaceEvenly`, no blocks pinned to the top and bottom.
2. **Word first, then everything the card knows**, in the card, in the review's order and type scale: reading and script (reading first as built, or script first by the 96/64/48 rule), the IPA, the speaker, the meaning at 28 sp with its dictionary icon and part of speech, notes at 15/22 (every note, in full, no 4-line cut), up to three examples in the review's inner box (with the reading), and a short form table in the same box.
3. **No button and no ratings, as built and as decided on 2026-10-22**: teaching is not graded; a swipe or the end-edge chevron tab goes on, as the review answer screen's swipe does. Content longer than the screen scrolls in the body, with a soft fade.
4. **IPA and speaker share one row** (speaker 56 dp, IPA with a dotted underline, still opening the pronunciation popup), and the picture is a 56 dp tile beside the meaning, so a bare word and the screenshot's card fit one screen at 1.4x. Review keeps its own stack.
5. The review screens change in two places only, both on the answer page (outlined on the page): the ratings in one row, and the swipe that records Good.

## Variants (tweak controls)

- **Card**: bare word, word with a note, phrase with a grammar note (the screenshot), word with examples, word with forms, long note. The depth controls (picture, speaker, IPA, note, 0 to 3 examples, forms) hide parts of the chosen card; a control is disabled where the card has nothing.
- **Word shows**: reading first (as built) or script first. **Short card sits**: top, as the review, or centred.
- The page's second section shows all six cards, After or as built.

## Decisions taken (owner, 2026-10-29) and open questions

Decided: the review question page is as built; the answer page is as built with the four ratings in one row where Continue sits and a swipe that records Good (2026-10-29, quoted above); the teach card has no button and keeps its swipe and chevron (2026-10-22).

Open:

1. **Four buttons at 1.4x.** They fit one row (about 79 dp each) in Telugu, Hindustani and Bengali alike, since the labels are the app's English strings; a longer translated label may need the 2 x 2 grid back.
2. **The pill.** "New word" and "New phrase" are new strings, and the deck name is shown as in review. Options: the pill, or no pill row (the downside: the card then starts higher than the review's).
3. **Dictionary and pronunciation popups** stay, opened from the meaning (book icon) and the IPA (dotted underline). Whether the icon is enough of a cue is for the owner.
4. **Warning block** (a rude or similar word) is not drawn: it would follow the notes as the review's `TaughtDetails` places it, one block, unchanged.
5. **Pictures** are not on the review screens. Here a picture is a small tile beside the meaning.
6. **Script first** at 96 sp is as large as the review's; a long word shrinks to fit.
7. **The chevron tab** sits over the card's end edge, as built, and can cover a few pixels of a long line while shown.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, icons 3:1. All 34 pairs pass.

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text, header | onS on s | 16.33 :1 | 4.5 :1 | pass |
| light | meaning, word on card | onS on sHigh | 14.01 :1 | 4.5 :1 | pass |
| light | script, IPA, notes, pos line on card | onSv on sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | deck name, rating prompt | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | example text on its box | onS on sLowest | 17.13 :1 | 4.5 :1 | pass |
| light | example translation, reading, form labels | onSv on sLowest | 9.33 :1 | 4.5 :1 | pass |
| light | Show answer, Good | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | Again | onEC on eC | 13.26 :1 | 4.5 :1 | pass |
| light | Hard | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | speaker icon on its cookie | onPc on pc | 13.28 :1 | 3 :1 | pass |
| light | New pill, Easy | onTC on tC | 7.24 :1 | 4.5 :1 | pass |
| light | Recognition pill | onRc on rc | 13.28 :1 | 4.5 :1 | pass |
| light | chevron tab icon | onSc on sc | 7.25 :1 | 3 :1 | pass |
| light | book icon on card | p on sHigh | 5.29 :1 | 3 :1 | pass |
| light | IPA chip outline on page (Before) | ol on s | 4.28 :1 | 3 :1 | pass |
| light | change outline on page | E on s | 6.16 :1 | 3 :1 | pass |
| light | change tag text | onE on E | 6.46 :1 | 4.5 :1 | pass |
| dark | body text, header | onS on s | 14.33 :1 | 4.5 :1 | pass |
| dark | meaning, word on card | onS on sHigh | 11.17 :1 | 4.5 :1 | pass |
| dark | script, IPA, notes, pos line on card | onSv on sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | deck name, rating prompt | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | example text on its box | onS on sLowest | 14.98 :1 | 4.5 :1 | pass |
| dark | example translation, reading, form labels | onSv on sLowest | 11.37 :1 | 4.5 :1 | pass |
| dark | Show answer, Good | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | Again | onEC on eC | 7.24 :1 | 4.5 :1 | pass |
| dark | Hard | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | speaker icon on its cookie | onPc on pc | 7.27 :1 | 3 :1 | pass |
| dark | New pill, Easy | onTC on tC | 7.24 :1 | 4.5 :1 | pass |
| dark | Recognition pill | onRc on rc | 7.22 :1 | 4.5 :1 | pass |
| dark | chevron tab icon | onSc on sc | 7.25 :1 | 3 :1 | pass |
| dark | book icon on card | p on sHigh | 8.46 :1 | 3 :1 | pass |
| dark | IPA chip outline on page (Before) | ol on s | 5.84 :1 | 3 :1 | pass |
| dark | change outline on page | E on s | 10.89 :1 | 3 :1 | pass |
| dark | change tag text | onE on E | 7.72 :1 | 4.5 :1 | pass |

Notes: `pc`/`onPc` (the speaker), `sLowest`, the error container and the Recognition pill colours are approximated from the seed and `ModeColors`; check them against the app's `ColorScheme` when building. The progress wave is drawn straight.

## Behaviour checks (Chromium, Playwright)

- Loaded at 1560 px wide: no page errors, no console errors, no horizontal page scroll.
- Swept in both themes, all three courses, all six cards and both word modes (72 renders, run twice): no error and no horizontal overflow inside any phone. The four rating buttons fit one row at 1.4x in all three courses.
- Screenshots of light and dark, each course and several cards were looked at.
- A card too tall for the screen scrolls in the body (long note, word with three examples, word with forms); a soft fade shows there is more below.
- Fonts: Roboto, Noto Sans Telugu, Devanagari and Bengali from Google Fonts; where offline the system fallback is used.
