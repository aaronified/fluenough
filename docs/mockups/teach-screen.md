# Teach screen: self-check, notes and open questions

Companion to `teach-screen.html` (owner, 2026-10-29: "Every teach screen, regardless of content depth or breadth, looks like this", and, later the same day, that the review screens are perfect and the teach card must align with them). The page holds only the screens and their tweak controls, with what changed outlined in red. The checks and notes are here. Nothing below is decided; every open choice is a tweak control on the page.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark, Telugu, Hindustani and Bengali examples. Readings follow the courses: Telugu writes a word-final anusvara as `ṁ`; Bengali has `ô` and no final a (`jôl`, `bāṛi`, `sôtti`). Theme, course and highlight are global controls.

## What the screen is today

`lib/features/drill/teach_card.dart`, in `teach_drill.dart` under a `TeachSwipe` (#691, ADR-0024). A `Column` with `MainAxisAlignment.spaceEvenly` inside a scroll view laid out to the screen's height, with 14 dp between blocks: the word large and left-aligned with its speaker and IPA pill (and a 104 dp picture tile), a meaning tile that opens the dictionary, one note clamped to 4 lines, one warning. No foot: a swipe or an end-edge chevron goes on. Whatever the content, the same three blocks are spread over the full height, so a short card is mostly gaps and a long note is cut at 4 lines. Examples, forms and every note after the first are only in the dictionary popup.

## What the review screens do (the reference, drawn as built)

`RecognitionDrill` in `DrillFrame` (`lib/ui/widgets/drill_frame.dart`): a 64 dp header; a scrolling body (16 dp sides, 4 on top) holding a row with the skill pill and the deck name, 16 dp, then one `DrillCard` (40 dp corners, `surfaceContainerHigh`, 20 x 28 padding) as tall as its content with its children centred 12 apart; a fixed foot (16, 12, 16, 20) with the tall filled button, or, once answered, "How well did you know it?" over the rating buttons (a 2 x 2 grid at 1.4x). The answer screen adds the divider, the meaning at 28 sp, notes at 15/22, and the first example in a `surfaceContainerLowest` box. The two review phones on the page are that, drawn from the real card. At 1.4x the answer screen scrolls under its foot, as built.

## What the proposal changes

The teach card becomes the review's answer screen with the teach card's extras, so the two read as one family:

1. **One card, as tall as its content**, in the review's body: the same pill row (a tertiary "New word" or "New phrase" pill, the deck name), the same 40 dp card, content centred 12 apart. No `spaceEvenly`, no blocks pinned to the top and bottom.
2. **Word first, then everything the card knows**, in the card, in the review's order and type scale: reading and script (reading first as built, or script first by the 96/64/48 rule), the IPA, the speaker, the meaning at 28 sp with its dictionary icon and part of speech, notes at 15/22 (every note, in full, no 4-line cut), up to three examples in the review's inner box (with the reading), and a short form table in the same inner box.
3. **The foot is the review's foot**: a tall Continue button (swipe still works). Content longer than the screen scrolls in the body under the fixed foot.
4. **IPA and speaker share one row** (speaker 56 dp, IPA with a dotted underline, still opening the pronunciation popup), and the picture is a 56 dp tile beside the meaning, so a bare word and the screenshot's card fit one screen at 1.4x. Review keeps its own stack.
5. Review screens change only in one place, and only if the owner turns it on: the swipe on the answer screen (outlined "swipe, the one change"; a tab on the end edge as the teach card's).

## Variants (tweak controls)

- **Card**: bare word, word with a note, phrase with a grammar note (the screenshot), word with examples, word with forms, long note. The depth controls (picture, speaker, IPA, note, 0 to 3 examples, forms) hide parts of the chosen card; a control is disabled where the card has nothing.
- **Word shows**: reading first (as built) or script first. **Short card sits**: top, as the review, or centred. **Teach foot**: Continue button, or the chevron tab only (as built, no foot). **Swipe on the review answer**: off or on.
- The page's second section shows all six cards, After or as built.

## Open questions

1. **Continue button or not.** The owner decided on 2026-10-22 that the teach card has no Continue button, only a swipe and chevrons. The proposal adds one because the review's foot is the family's bottom action. Options: (a) Continue as drawn (the downside: it reverses that decision and takes about 96 dp from the card); (b) chevron tab only, as built (the downside: the teach card then has no foot and the two screens differ at the bottom).
2. **Swipe on the review answer.** The review answer has only the four ratings, so a swipe has to mean something. Options: not shown by default; if wanted, it must say what it records (for example Good, or a skip with no rating). Not decided here.
3. **The pill.** "New word" and "New phrase" are new strings, and the deck name is shown as in review. Options: the pill, or no pill row (the downside: the card then starts higher than the review's).
4. **Dictionary and pronunciation popups** stay, opened from the meaning (book icon) and the IPA (dotted underline). Whether the icon is enough of a cue is for the owner.
5. **Warning block** (a rude or similar word) is not drawn: it would follow the notes as the review's `TaughtDetails` places it, one block, unchanged.
6. **Pictures** are not on the review screens. Here a picture is a small tile beside the meaning.
7. **Script first** at 96 sp is as large as the review's; a long word shrinks to fit.

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
| light | Continue, Good | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | speaker icon on its cookie | onPc on pc | 13.28 :1 | 3 :1 | pass |
| light | New pill, Easy | onTC on tC | 7.24 :1 | 4.5 :1 | pass |
| light | Recognition pill | onRc on rc | 13.28 :1 | 4.5 :1 | pass |
| light | Hard | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | Again | onEC on eC | 13.26 :1 | 4.5 :1 | pass |
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
| dark | Continue, Good | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | speaker icon on its cookie | onPc on pc | 7.27 :1 | 3 :1 | pass |
| dark | New pill, Easy | onTC on tC | 7.24 :1 | 4.5 :1 | pass |
| dark | Recognition pill | onRc on rc | 7.22 :1 | 4.5 :1 | pass |
| dark | Hard | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | Again | onEC on eC | 7.24 :1 | 4.5 :1 | pass |
| dark | chevron tab icon | onSc on sc | 7.25 :1 | 3 :1 | pass |
| dark | book icon on card | p on sHigh | 8.46 :1 | 3 :1 | pass |
| dark | IPA chip outline on page (Before) | ol on s | 5.84 :1 | 3 :1 | pass |
| dark | change outline on page | E on s | 10.89 :1 | 3 :1 | pass |
| dark | change tag text | onE on E | 7.72 :1 | 4.5 :1 | pass |

Notes: `pc`/`onPc` (the speaker), `sLowest`, the error container and the Recognition pill colours are approximated from the seed and `ModeColors`; check them against the app's `ColorScheme` when building. The progress wave is drawn straight.

## Behaviour checks (Chromium, Playwright)

- Loaded at 1560 px wide: no page errors, no console errors, no horizontal page scroll.
- Swept in both themes and all three courses: 6 cards x 2 word modes x 2 foot modes (144 combinations): no error and no horizontal overflow inside any phone.
- Screenshots of light and dark, each course and several cards were looked at.
- A card too tall for the screen scrolls under the fixed foot (long note, word with three examples, word with forms); a soft fade shows there is more below.
- Fonts: Roboto, Noto Sans Telugu, Devanagari and Bengali from Google Fonts; where offline the system fallback is used.
