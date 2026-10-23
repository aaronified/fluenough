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

Run in both courses, once with a mouse and once with touch emulation (`hasTouch`, `isMobile`, a 400 px wide viewport, drags sent as CDP `Input.dispatchTouchEvent` touchStart, touchMove and touchEnd). No page errors and no console errors; one phone, 360x740.

| Check | Mouse | Touch |
|---|---|---|
| Click or tap a word: the sheet opens; its handle closes it | pass | pass |
| Every word opens a sheet | 14 / 13 words | 14 / 13 words |
| + Learn opens the teach cards | pass | pass |
| Drag the card left 200 px | lands on 2 / 2 | lands on 2 / 2 |
| Drag it right 200 px | back on 1 / 2 | back on 1 / 2 |
| Tap the right chevron while it is hidden | card 2 / 2, chevrons revealed (`touch` on after 160 ms), hidden again 0.3 s after the tap ends | same |
| IPA popup and dictionary popup: visible, `document.elementFromPoint` at the centre hits the popup, close on Escape, the scrim and Close | pass | pass |
| Badge shows 3; the Calendar tag leaves only taught words and the button reads Relearn with no badge | pass | pass |

**The swipe works on a phone.** The cause on a real touch screen was `touch-action`: the cards sit in a scroll container, so the effective value stops there and `pan-y` on the track was ignored. The card track and each slide now have `touch-action: none` (the teach card never scrolls, so each slide is also `overflow: hidden`), and the drag is tracked with pointer events on the track itself, with `setPointerCapture` once the drag passes the slop. Buttons are not preventDefault-ed.

**No word wraps.** Every headword, meaning, list word, list reading and popup title is a single line (the Range `getClientRects` line count is 1 and `scrollWidth <= clientWidth`) in both courses, on the list, both teach cards, the dictionary popup and the sheet. A word that is too wide for its box scales its font down to fit; every other keeps its normal size. Measured: list words stay at 28px except the Bengali long word (25.5px); the list meaning 19.6px scales to 16.8px for "yesterday; tomorrow"; teach headword 72.8px (Bengali long word 51.3px); teach meaning 30.8px scales to 18.8px ("yesterday; tomorrow"), 26.3px ("representation") and 23.8px ("of the situations"). There are no soft hyphens.

**The image is a square tile**, 104 x 104 dp (`aspect-ratio: 1`), beside the meaning block. The teach card shows one note and one warning (four blocks including the headword and the meaning row), spread evenly; the blocks fill 67 percent (Hindustani and Bengali, normal word) and 67 and 63 percent (long word) of the card's height. Each slide has `scrollHeight` 688 = `clientHeight` 688 (no scroll).

**The IPA breakdown lists every symbol, in order, of the word's IPA** (each distinct symbol once, in order of first appearance), generated from the IPA string with a symbol table (`SYM` in the page) that has an entry for every segment used. A segment with no entry is reported with `console.error` and counted in `window.__ipaMissing`; it is 0 here.
- Hindustani प्रतिनिधित्व `/pɾət̪ɪnɪd̪ʱɪt̪ʋ/`: p, ɾ, ə, t̪, ɪ, n, d̪ʱ, ʋ (8 rows, including ə, ɪ, n, t̪ and d̪ʱ).
- Bengali পরিস্থিতিগুলোর `/pɔɾist̪ʰit̪iɡuloɾ/`: p, ɔ, ɾ, i, s, t̪ʰ, t̪, ɡ, u, l, o (11 rows).

## Notes

**Deck page (#693).** One row per word: word and reading left, meaning right with a mastery chip (New, Learning, Known). Tag chips filter the list (Proposed: a word shows when it has any selected tag; none selected shows all). The count line says how many words are shown. The per-skill buttons and Inspect are gone. Hindustani has बाल (bāl, "hair") as a word with no tag, to show the looks-like warning on the sheet.

**+ Learn and Relearn (owner, 2026-10-22, #693).** The bottom bar has Practice and **+ Learn**. A badge on the top-right corner of + Learn counts the untaught words in view, for example 3. When every word in view is taught, the button becomes **Relearn** with no badge. Relearn goes through every card in view, as the tag chips filtered the list at the moment it was tapped. Try the Calendar tag.

**Practice.** Opens a popup of skills with All (all on by default; unchecking All clears the rest; Start is off when none is ticked).

**Teach card (#691, #694).** Shared by lessons and the walkthrough. A large headword, the reading, audio and the IPA text; the meaning block beside a square image tile; one note; one warning (the most useful; the card data names it, and the word sheet shows the rest). No examples on the card.
- **The IPA text is a button.** It opens the pronunciation popup, which refers to the IPA course and lists each symbol in the word with a short description, an example, a play button and a Practise control (a button here; it opens that symbol's practice in the IPA course).
- **The meaning area is the dictionary button** (book icon at its right). It opens the dictionary popup: the senses, the etymology and the example sentences, which have moved off the card.
- **Popups** open over the teach card, inside the phone, above everything, with a scrim. They close on the scrim, on Close, or on Escape. Escape closes the popup first, then the teach cards, then the sheet.
- **Warnings have no title** on the card, only the icon and the text, on the tertiary panel (owner, 2026-10-22):
  - **Ear-off, "Looks like another word", is about spelling.** Its text says how the spelling differs and says little about sound: "काल has the ā sign (ा) after क; कल has none." The Hindustani बाल sheet says "बाल has the ā sign (ा) after ब; बल has none." The Bengali card says "কাল has the ā sign (া) after ক; কল has none." Icon: hearing-disabled (an ear with a slash).
  - **Ear-on, "Sounds like another word", is about pronunciation.** It is only for words whose IPA differs by exactly one segment, and only for very close pairs: short and long vowels (e/eː, i/iː, a/aː), aspirated and unaspirated consonants (k/kʰ, t̪/t̪ʰ), dental and retroflex consonants (t̪/ʈ), and similar. Its text names that one sound difference. The demo pairs obey this: कल /kəl/ and काल /kaːl/ (ə against aː) and Bengali কাল /kal/ and খাল /kʰal/ (k against kʰ). The earlier কাল / কালো pair broke the rule (an extra segment), so it was swapped.
  - **Other meanings** uses the translate icon. Notes, and base words that change their stem, such as the Bengali long word, are said in the card's note.
  - Which warning the teach card shows is part of the card (`pick`): the Hindustani first card shows ear-on, the Bengali first card ear-off, and each long word shows its other meanings.
- Proposed: the mockup draws the hearing-disabled icon as the hearing icon plus a slash; the app uses Material's `hearing_disabled`.

**Swipe and chevrons (owner, 2026-10-22).** There is no Back and Continue bar; the progress bar stays at the top. Cards swipe left and right like the app's tab screens, by mouse drag or touch (see the swipe note above): the card follows the pointer, then springs to the next card, the previous one or back with the approved tab-swipe spring (stiffness 400, damping ratio 0.75, mass 1, so c = 2 x 0.75 x sqrt(400) = 30), the integration copied from `lib/ui/widgets/tab_pager.dart` (#702): rubber band at the ends, one card per fling, minimum fling 200 px/s, and a slow release that damps critically, ramping to 0.75 as the release speed rises to 1500 px/s. A chevron tap uses the same spring from rest at 0.75. Two chevrons, ‹ and ›, sit on either side of the card, vertically centred; no ‹ on the first card and no › on the last. **They are tappable whether shown or not** (pointer events stay on while they are invisible). They appear 0.1 s after a touch starts (mouse down counts), with a wiggle of about 3 px for 2 to 3 cycles over 250 ms, and stay for 0.3 s after the touch ends; a quick tap on a hidden chevron both moves the card and reveals them.

**The long word.** The second teach card in each course is an unusually long word: Hindustani प्रतिनिधित्व (pratinidhitva), "representation", and Bengali পরিস্থিতিগুলোর (pôristhitigulor), "of the situations". The headword is one line and scales down to the card's width (the Bengali word to 51.3 px from 72.8 px; the Hindustani one fits at full size in the font used here), never clipped and never wrapped.

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
