# Deck page and teach card: self-check and notes

Companion to `deck-page-and-teach-card.html` (#693 the deck page, #691 the teach card). The page holds only the screens; the checks and notes are here (owner, 2026-10-22). This is a complete overhaul of the 2026-10-21 mockup, so nothing is highlighted as changed.

Frames: Hindustani in light and Bengali in dark, 360 dp wide, 1.4x text, ColorScheme.fromSeed of the forest seed, tertiaryContainer panel `tC` / `onTC`. Each language has the deck page, the word sheet open, the teach card, the pronunciation popup open and the dictionary popup open. Bengali readings follow the course: kāl, āj, no final a.

## Self-check results

WCAG contrast, computed in the page's JS (printed to the console only) and run once in Chromium. Text 4.5:1, icons and outlines 3:1. All 42 pairs pass.

| Theme | Pair | Ratio | Needs | Result |
|---|---|---|---|---|
| light | body text: onS on s | 16.33:1 | 4.5:1 | pass |
| light | reading, captions: onSv on s | 8.9:1 | 4.5:1 | pass |
| light | captions on bottom bar: onSv on sLow | 8.45:1 | 4.5:1 | pass |
| light | meaning button and note text: onS on sHigh | 14.01:1 | 4.5:1 | pass |
| light | dictionary icon and note icon: p on sHigh | 5.29:1 | 3:1 | pass |
| light | IPA button text: onS on s | 16.33:1 | 4.5:1 | pass |
| light | IPA button outline: ol on s | 4.28:1 | 3:1 | pass |
| light | warning: onTC on tC | 7.24:1 | 4.5:1 | pass |
| light | chip selected, Learning, Practice, play button, image tile: onSc on sc | 7.25:1 | 4.5:1 | pass |
| light | chip unselected and New: onSv on s | 8.9:1 | 4.5:1 | pass |
| light | chip and New outline: ol on s | 4.28:1 | 3:1 | pass |
| light | Known chip and + Learn / Relearn: onP on p | 6.46:1 | 4.5:1 | pass |
| light | badge: onE on E | 6.46:1 | 4.5:1 | pass |
| light | badge against bottom bar: E on sLow | 5.85:1 | 3:1 | pass |
| light | popup text: onS on sHigh | 14.01:1 | 4.5:1 | pass |
| light | popup buttons, IPA symbols: p on sHigh | 5.29:1 | 4.5:1 | pass |
| light | Practise outline: ol on sHigh | 3.67:1 | 3:1 | pass |
| light | popup captions: onSv on sHigh | 7.64:1 | 4.5:1 | pass |
| light | example rule: p on s | 6.16:1 | 3:1 | pass |
| light | sheet text: onS on sLow | 15.5:1 | 4.5:1 | pass |
| light | IPA symbols and buttons on sheet: p on sLow | 5.85:1 | 4.5:1 | pass |
| dark | body text: onS on s | 14.33:1 | 4.5:1 | pass |
| dark | reading, captions: onSv on s | 10.88:1 | 4.5:1 | pass |
| dark | captions on bottom bar: onSv on sLow | 10.08:1 | 4.5:1 | pass |
| dark | meaning button and note text: onS on sHigh | 11.17:1 | 4.5:1 | pass |
| dark | dictionary icon and note icon: p on sHigh | 8.46:1 | 3:1 | pass |
| dark | IPA button text: onS on s | 14.33:1 | 4.5:1 | pass |
| dark | IPA button outline: ol on s | 5.84:1 | 3:1 | pass |
| dark | warning: onTC on tC | 7.24:1 | 4.5:1 | pass |
| dark | chip selected, Learning, Practice, play button, image tile: onSc on sc | 7.25:1 | 4.5:1 | pass |
| dark | chip unselected and New: onSv on s | 10.88:1 | 4.5:1 | pass |
| dark | chip and New outline: ol on s | 5.84:1 | 3:1 | pass |
| dark | Known chip and + Learn / Relearn: onP on p | 7.68:1 | 4.5:1 | pass |
| dark | badge: onE on E | 7.72:1 | 4.5:1 | pass |
| dark | badge against bottom bar: E on sLow | 10.09:1 | 3:1 | pass |
| dark | popup text: onS on sHigh | 11.17:1 | 4.5:1 | pass |
| dark | popup buttons, IPA symbols: p on sHigh | 8.46:1 | 4.5:1 | pass |
| dark | Practise outline: ol on sHigh | 4.55:1 | 3:1 | pass |
| dark | popup captions: onSv on sHigh | 8.48:1 | 4.5:1 | pass |
| dark | example rule: p on s | 10.86:1 | 3:1 | pass |
| dark | sheet text: onS on sLow | 13.28:1 | 4.5:1 | pass |
| dark | IPA symbols and buttons on sheet: p on sLow | 10.05:1 | 4.5:1 | pass |

## Layout checks (Chromium, Playwright)

- No page errors.
- **The teach card fits one screen.** In a 360x740 frame at 1.4x, with the progress bar at the top and no bottom bar, each slide has `scrollHeight` 688 = `clientHeight` 688 (no scroll). The content is 471 px (Hindustani) and 471 px (Bengali) tall for the first card, and 428 px and 466 px for the long-word card, so there is room to spare.
- **The IPA popup and the dictionary popup open** from the IPA text and the meaning area, in both languages, and close with Close or the scrim.
- **The badge shows** (3) on the deck page. Selecting the Calendar tag leaves only taught words: the badge goes and the button reads Relearn.
- **Chevrons.** 0 opacity when idle and at 50 ms after a touch starts; visible (0.92) after 250 ms; still visible 150 ms after release and hidden 650 ms after. A left swipe goes to card 2 of 2, a right swipe back to 1 of 2, a chevron tap to 2 of 2, where the right chevron is gone.
- **The long word is never clipped.** No headword, meaning or list word overflows its box (0 clipped), in both languages.

## Notes

**Deck page (#693).** One row per word: word and reading left, meaning right with a mastery chip (New, Learning, Known). Tag chips filter the list (Proposed: a word shows when it has any selected tag; none selected shows all). The count line says how many words are shown. The per-skill buttons and Inspect are gone.

**+ Learn and Relearn (owner, 2026-10-22, #693).** The bottom bar has Practice and **+ Learn**. A small badge on the top-right corner of + Learn counts the untaught words in view, for example 3. When every word in view is taught, the button becomes **Relearn** with no badge. Relearn goes through every card in view, as the tag chips filtered the list at the moment it was tapped. Try the Calendar tag.

**Practice.** Opens a popup of skills with All (all on by default; unchecking All clears the rest; Start is off when none is ticked).

**Teach card (#691, #694).** Shared by lessons and the walkthrough. Word, reading, audio and the IPA text; the meaning area with a small image tile; one note; one warning. Part of speech and gender sit on one line inside the meaning area. No examples on the card.
- **The IPA text is a button.** It opens the pronunciation popup, which refers to the IPA course and lists each IPA symbol in the word with a short description, an example, a play button and a Practise control (a button here; it opens that symbol's practice in the IPA course).
- **The meaning area is the dictionary button** (book icon at its right). It opens the dictionary popup: the senses, the etymology and the example sentences, which have moved off the card.
- **Warnings have no title** on the card, only the icon and the text: sounds like another word keeps the hearing icon on the tertiary panel, other meanings the translate icon. At most one note and one warning, each clamped to two lines; a card with no sounds-like warning shows other meanings in its place.
- **One screen, no scroll.** Spacing is trimmed, the image is a small tile beside the meaning, and there is no Back and Continue bar.

**Swipe and chevrons (owner, 2026-10-22).** There is no Back and Continue bar. Cards swipe left and right like the app's tab screens: the card follows the finger and springs to the next card, the previous one or back, with the approved tab-swipe spring (stiffness 400, damping ratio 0.75, mass 1, so c = 2 x 0.75 x sqrt(400) = 30), the integration copied from `tab-swipe.html` (#702): rubber band at the ends, one card per fling, minimum fling 200 px/s, and a slow release that damps critically, ramping to 0.75 as the release speed rises to 1500 px/s. A chevron tap uses the same spring from rest at damping ratio 0.75. Two chevrons, ‹ and ›, sit on either side of the card, vertically centred; there is no ‹ on the first card and no › on the last. They are hidden when the screen is not touched: they appear 0.1 s after a touch starts and disappear 0.3 s after the last touch ends. On appearing they wiggle: a horizontal shake of about 3 px, 2 to 3 cycles, over 250 ms. The mockup uses pointer events; mouse down counts as a touch. The progress bar stays at the top.

**The long word.** Each course has an unusually long word as its second teach card, so the swipe reaches it: Hindustani प्रतिनिधित्व (pratinidhitva), "representation", and Bengali পরিস্থিতিগুলোর (pôristhitigulor), "of the situations". The headword is one line and scales down to its width (the Bengali word to 51 px from 56 px; the Hindustani one fits at full size in the font used here), never clipped and never wrapped. The same rule shrinks a long meaning, and the list word on the deck page. The app should do the same with a fit-to-width headword. Notes say that the Bengali word keeps its stem পরিস্থিতি, with the plural -গুলো and the genitive -র added.

**Word sheet (the inspect version).** Everything is inline, with no folding and no popups, in the order: word, reading, audio and IPA; the IPA breakdown on the card itself, one row per symbol with description, example, play and Practise, as in the pronunciation popup; meaning, other meanings, accepted answers; image; note; the warning blocks **with their titles** (sounds like, other meanings); the dictionary (senses, etymology) inline; every example; tags, card id and Report. The word sheet may scroll.

**Proposed**
- The mastery chips: New is an outline, Learning the secondaryContainer, Known the primary.
- The tag filter rule above (any selected tag).
- The badge colours: the error role on the surface, with the white or dark on-error text.
- The IPA text drawn as an outlined pill, and the meaning area as a surfaceContainerHigh button with a book icon.
- The translate icon for other meanings (sounds like uses the hearing icon, as the app's word sheet does).
- The chevron drawing: a secondaryContainer tab on each edge at 92 percent opacity.
- The dictionary, IPA and example content is invented for the mockup (the real content comes from #692 and the IPA course).

Readings are transliteration, based on ISO 15919. Text size is 1.4x only (owner, 2026-10-17). Hindi कल is a card with a base-word note: it means both yesterday and tomorrow.
