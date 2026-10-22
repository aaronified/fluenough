# Deck page and teach card: self-check and notes

Companion to `deck-page-and-teach-card.html` (#693 the deck page, #691 the teach card). The page holds only the screen and its tweak controls; the checks and notes are here (owner, 2026-10-22). This is a complete overhaul of the 2026-10-21 mockup, so nothing is highlighted as changed.

**One screen** (owner, 2026-10-22: "Build just one screen"): one phone, 360x740 dp at 1.4x text, ColorScheme.fromSeed of the forest seed, with the tertiaryContainer panel `tC` / `onTC`. It starts on the deck list. Tapping a word opens the word sheet over it; tapping + Learn opens the two teach cards (the normal word and the long word) over it. Closing either returns to the list. Course (Hindustani or Bengali) and Theme (light or dark) are tweak controls above the phone; changing one rebuilds the phone at its start state. Bengali readings follow the course: kāl, āj, no final a.

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
| light | chip selected, Learning, Practice, play button, image tile, chevrons: onSc on sc | 7.25:1 | 4.5:1 | pass |
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
| dark | chip selected, Learning, Practice, play button, image tile, chevrons: onSc on sc | 7.25:1 | 4.5:1 | pass |
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

## Behaviour checks (Chromium, Playwright, driven like a user from the start state)

Run in both courses. No page errors and no console errors; one `.ph` on the page, 360x740.

| Check | Hindustani | Bengali |
|---|---|---|
| Click a word: the sheet opens; its grab handle closes it and the list is back | pass | pass |
| Every word opens a sheet (words without a full card get one built from the list data) | 14 words | 13 words |
| Click + Learn: the teach cards open | pass | pass |
| Mouse-drag the card left 200 px lands on card 2 of 2 | 2 / 2 | 2 / 2 |
| Mouse-drag it right 200 px returns to card 1 of 2 | 1 / 2 | 1 / 2 |
| No text is selected after a drag | pass | pass |
| Tap the IPA text: the popup is visible and `document.elementFromPoint` at its centre hits the popup | pass | pass |
| IPA popup closes on Escape, on the scrim, and on Close | pass | pass |
| Tap the meaning: the dictionary popup is visible and on top; Close closes it | pass | pass |
| The dictionary popup is on top for the long word too | pass | pass |
| Chevron tap (right) from card 1 goes to card 2 | 2 / 2 | 2 / 2 |
| Escape closes the teach cards | pass | pass |
| The badge shows 3 untaught words; the Calendar tag leaves only taught words and the button reads Relearn with no badge | badge 3, then Relearn with no badge | badge 3, then Relearn with no badge |

**The IPA breakdown lists every symbol, in order, of the word's IPA** (each distinct symbol once, in order of first appearance), generated from the IPA string with a symbol table (`SYM` in the page) that has an entry for every segment used. A segment with no entry is reported with `console.error` and counted in `window.__ipaMissing`; it is 0 here.
- Hindustani प्रतिनिधित्व `/pɾət̪ɪnɪd̪ʱɪt̪ʋ/`: p, ɾ, ə, t̪, ɪ, n, d̪ʱ, ʋ (8 rows, including ə, ɪ, n, t̪ and d̪ʱ).
- Bengali পরিস্থিতিগুলোর `/pɔɾist̪ʰit̪iɡuloɾ/`: p, ɔ, ɾ, i, s, t̪ʰ, t̪, ɡ, u, l, o (11 rows).

**The deck list keeps its size.** The list words' computed font-size is 28px (20 px x 1.4), the same as before the last change. Only the teach card's headword shrinks to fit a long word. A long list word wraps inside its column and is never shrunk.

**The teach card fits one screen, with no scroll and no big empty band.** In the 360x740 frame each slide has `scrollHeight` 688 = `clientHeight` 688. The blocks fill 87.4 percent (Hindustani) and 87.4 percent (Bengali) of the card's height on the normal word (at least 85 percent), and 74.4 and 70.8 percent on the long word (never above 100 percent). Fill is the sum of the blocks' heights over the card's height; the remaining space is spread evenly between them.

## Notes

**Deck page (#693).** One row per word: word and reading left, meaning right with a mastery chip (New, Learning, Known). Tag chips filter the list (Proposed: a word shows when it has any selected tag; none selected shows all). The count line says how many words are shown. The per-skill buttons and Inspect are gone. Hindustani has बाल (bāl, "hair") as a word with no tag, to show the looks-like warning on the sheet.

**+ Learn and Relearn (owner, 2026-10-22, #693).** The bottom bar has Practice and **+ Learn**. A badge on the top-right corner of + Learn counts the untaught words in view, for example 3. When every word in view is taught, the button becomes **Relearn** with no badge. Relearn goes through every card in view, as the tag chips filtered the list at the moment it was tapped. Try the Calendar tag.

**Practice.** Opens a popup of skills with All (all on by default; unchecking All clears the rest; Start is off when none is ticked).

**Teach card (#691, #694).** Shared by lessons and the walkthrough. A large headword, the reading, audio and the IPA text; the meaning area beside a bigger image tile; a note and up to two warnings (or three warnings when there is no note). No examples on the card.
- **The IPA text is a button.** It opens the pronunciation popup, which refers to the IPA course and lists each symbol in the word with a short description, an example, a play button and a Practise control (a button here; it opens that symbol's practice in the IPA course).
- **The meaning area is the dictionary button** (book icon at its right). It opens the dictionary popup: the senses, the etymology and the example sentences, which have moved off the card.
- **Popups** open over the teach card, inside the phone, above everything, with a scrim. They close on the scrim, on Close, or on Escape. Escape closes the popup first, then the teach cards, then the sheet.
- **Warnings have no title** on the card, only the icon and the text, on the tertiary panel. Sounds like another word uses the hearing icon; other meanings the translate icon; **looks like another word** (owner, 2026-10-22: "Use ear-off to add words that look similar in script but are different in pronunciation") the hearing-disabled icon (an ear with a slash). Proposed: the mockup draws that icon as the hearing icon plus a slash; the app uses Material's `hearing_disabled`. The sheet title for it is "Looks like another word". Real examples: Hindustani बाल (bāl, hair) / बल (bal, strength), which differ only by the ā sign (on the बाल sheet); Bengali কাল (kāl) / কল (kôl, machine, tap), which differ only by the ā sign (on the first Bengali card). Notes, and base words that change their stem, such as the Bengali long word, are said in the card's note.
- Space is spread evenly down the card and the headword (52 px x 1.4) and the image tile are larger; the card never scrolls.

**Swipe and chevrons (owner, 2026-10-22).** There is no Back and Continue bar; the progress bar stays at the top. Cards swipe left and right like the app's tab screens, by mouse drag or touch: pointer events with `setPointerCapture` once the drag passes the slop, `touch-action: pan-y` on the card track, `user-select: none`, and `preventDefault` on pointerdown in the track (not on buttons, so taps still work). The card follows the pointer, then springs to the next card, the previous one or back with the approved tab-swipe spring (stiffness 400, damping ratio 0.75, mass 1, so c = 2 x 0.75 x sqrt(400) = 30), the integration copied from `tab-swipe.html` (#702): rubber band at the ends, one card per fling, minimum fling 200 px/s, and a slow release that damps critically, ramping to 0.75 as the release speed rises to 1500 px/s. A chevron tap uses the same spring from rest at 0.75. Two chevrons, ‹ and ›, sit on either side of the card, vertically centred; no ‹ on the first card and no › on the last. They are hidden when the screen is not touched: they appear 0.1 s after a touch starts (mouse down counts) and disappear 0.3 s after the last touch ends, and wiggle about 3 px for 2 to 3 cycles over 250 ms when they appear.

**The long word.** The second teach card in each course is an unusually long word: Hindustani प्रतिनिधित्व (pratinidhitva), "representation", and Bengali পরিস্থিতিগুলোর (pôristhitigulor), "of the situations". The headword is one line and scales down to the card's width (the Bengali word to 50.8 px from 72.8 px; the Hindustani one fits at full size in the font used here), never clipped and never wrapped. The long English meaning breaks at a soft hyphen (represen-tation) instead of shrinking.

**Word sheet (the inspect version).** Everything is inline, with no folding and no popups: word, reading, audio and IPA; the IPA breakdown on the card itself, one row per symbol with description, example, play and Practise, as in the pronunciation popup; meaning, other meanings, accepted answers; image; note; every warning **with its title**; the dictionary (senses, etymology); every example; tags, card id and Report. The sheet scrolls and closes on its handle, the scrim or Escape.

**Proposed**
- The mastery chips: New is an outline, Learning the secondaryContainer, Known the primary.
- The tag filter rule above (any selected tag).
- The badge colours: the error role on the surface, with the on-error text.
- The IPA text drawn as an outlined pill, and the meaning area as a surfaceContainerHigh button with a book icon.
- The translate icon for other meanings, and the drawn hearing-disabled icon.
- The chevron drawing: a secondaryContainer tab on each edge at 92 percent opacity.
- The symbol descriptions, examples, dictionary and example content are invented for the mockup (the real content comes from #692 and the IPA course).

Readings are transliteration, based on ISO 15919. Text size is 1.4x only (owner, 2026-10-17). Hindi कल is a card with a base-word note: it means both yesterday and tomorrow.
