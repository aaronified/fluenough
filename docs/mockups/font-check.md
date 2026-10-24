# The font check: self-check, notes and open questions

Companion to `font-check.html` (#611). Owner, 2026-10-23: "Offer to download the fonts, ask user if they can read a sample. Otherwise download. Same shit for everything." and "Bundle means it downloads with the deck" (ADR-0042; fonts in `decks/fonts`, downloaded per course). Owner, 2026-10-24: "Mockup first". Nothing below is decided; the open choices are tweak controls where a screen can show them.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed (the tokens of the Today chain mockup), light and dark. Samples: Hindustani in Perso-Arabic (with Devanagari as the second script), Bengali, Chinese and Korean, each with its reading and meaning. What is new is outlined in red; the Decks tab behind the sheets and the Settings rows around the new one are as built.

## Screens

1. **At course start** (the first download of a course), a bottom sheet over the Decks tab, before the decks download:
   1. *Check how Hindustani looks*: a sample in the phone's own font, its reading and meaning, "Yes, I can read it" and "No, it shows boxes", a line saying what "No" costs (the font's name and size, downloaded with the course), and "Ask me later".
   2. *Downloading*: after "No", "Downloading decks and the Hindustani font…" (ADR-0042's wording) with a bar for the font and one for the decks; it may be left, and "Cancel the font" keeps the course on the phone's font.
   3. *Can you read it now?*: the sample again, drawn in the downloaded font, "Yes" or "No, it still shows boxes".
   4. *Done* with the downloaded font, and 5. *Done* after "Yes" (nothing downloaded). Both say where to change it later.
   6. *Still boxes*: even the downloaded font did not draw the script; the course still works with readings, "Report this phone", "Continue with readings only".
2. **In Settings**: one new row, *Script fonts*, in Your decks or in Look (control "The row lives in"). It opens a page with "Check all scripts" and one row per script of the learner's courses: the script, a sample line, its state (Not checked, Phone's font, Downloaded, Downloading with a percentage, Shows boxes) and an action (Check, Check again, Download). Tapping a row opens the course-start sheet as "check again"; for a downloaded script it also offers "Remove the downloaded font" (in the error colour). Hindustani's two scripts are two rows.

The "This phone" control draws the sample as letters or as boxes (one box per character), since a mockup cannot show a missing font. The downloaded font's sample is always letters.

## Open questions (not decided)

1. **Which scripts ask?** The owner said "same for everything", so every script is checked, but ADR-0042 already downloads a Noto font without asking for the scripts it lists (Indic, Nastaliq, Egyptian, cuneiform, Linear B). Does the check replace that automatic download (the app asks first, and downloads only on "No"), or do those scripts keep downloading and only the scripts without a listed font (Han, Hangul, kana) ask? Proposed: the check replaces it, so one rule holds for every script. Downside: a learner who says "Yes" on a phone that draws the script badly (a Nastaliq line in plain Naskh is readable but wrong) gets no font.
2. **Latin, Cyrillic and Greek.** Not drawn: every phone has them, so no sample is shown (Spanish has no check). Confirm, or ask for every script including Latin.
3. **Several scripts in a course.** Hindustani has Devanagari and Perso-Arabic. Control "Scripts checked": only the script the learner reads, or each script of the course in turn ("Script 2 of 2"). ADR-0042 downloads the font of each script today whichever the learner reads. Proposed: only the script the learner reads, the other is checked when they switch to it.
4. **Sizes of the CJK fonts.** Noto Sans SC and KR are large; the figures on the page (about 10 MB and about 6 MB) are estimates to confirm, and ADR-0042 left CJK out because of them. Options: the full variable font, or a subset of the characters the decks use (smaller, but a card added later may show a box). Should the download warn on mobile data?
5. **Which Han font.** Chinese is drawn with Noto Sans SC (simplified). Japanese kanji and Traditional Chinese need their own (JP, TC) families: one font per course, not per script? The font is per script today (`FluenoughScript-<script>`), and Han is one script in three regional shapes.
6. **"Ask me later".** Shown by default (control). What does it do: no font now, and the check is offered again from Settings, or on the next launch? Proposed: Settings only; the row shows "Not checked".
7. **"Still boxes after the download."** Proposed: report the phone (the Report button already exists) and carry on with readings. Is there a fallback font to try instead?
8. **Where the Settings row lives**: Your decks (fonts download with decks) or Look (they are about how text draws). Proposed: Look.
9. **Removing a downloaded font.** Not asked for; drawn as Proposed. ADR-0042 deletes a font only when no course on the phone lists it.
10. **Sitelen pona** (UCSUR): the owner said "Discuss on this separately"; not drawn.
11. **Existing learners.** A learner who already has a course (and its font from ADR-0042, if built) sees every script as "Not checked" in Settings, or is asked once at launch? Proposed: Settings only, no prompt.
12. **Offline.** At course start the sample needs no network, but the download does. If offline, "No" says "Connect to download the font" and keeps the course on the phone's font.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, icons and outlines 3:1. All 46 pairs pass.

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text | onS on s | 16.33 :1 | 4.5 :1 | pass |
| light | captions, readings | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | captions on cards | onSv on sLow | 8.45 :1 | 4.5 :1 | pass |
| light | text on cards | onS on sLow | 15.5 :1 | 4.5 :1 | pass |
| light | text on raised blocks | onS on sHigh | 14.01 :1 | 4.5 :1 | pass |
| light | captions on raised blocks | onSv on sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | sample text on raised block | onS on sHigh | 14.01 :1 | 4.5 :1 | pass |
| light | chip selected, tonal button, Learning chip | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | filled button, Known chip | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | text button and icon on sheet | p on sLow | 5.85 :1 | 4.5 :1 | pass |
| light | text button on page | p on s | 6.16 :1 | 4.5 :1 | pass |
| light | icon on raised block | p on sHigh | 5.29 :1 | 3 :1 | pass |
| light | outline against page | ol on s | 4.28 :1 | 3 :1 | pass |
| light | outline against card | ol on sLow | 4.06 :1 | 3 :1 | pass |
| light | unselected chip text on page | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | unselected chip text on card | onSv on sLow | 8.45 :1 | 4.5 :1 | pass |
| light | change tag | onE on E | 6.46 :1 | 4.5 :1 | pass |
| light | change outline on page | E on s | 6.16 :1 | 3 :1 | pass |
| light | change outline on card | E on sLow | 5.85 :1 | 3 :1 | pass |
| light | sheet title on sheet | onS on sLow | 15.5 :1 | 4.5 :1 | pass |
| light | error text button on sheet | E on sLow | 5.85 :1 | 4.5 :1 | pass |
| light | Shows boxes chip | onE on E | 6.46 :1 | 4.5 :1 | pass |
| light | progress fill on its track | p on sc | 4.99 :1 | 3 :1 | pass |
| dark | body text | onS on s | 14.33 :1 | 4.5 :1 | pass |
| dark | captions, readings | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | captions on cards | onSv on sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | text on cards | onS on sLow | 13.28 :1 | 4.5 :1 | pass |
| dark | text on raised blocks | onS on sHigh | 11.17 :1 | 4.5 :1 | pass |
| dark | captions on raised blocks | onSv on sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | sample text on raised block | onS on sHigh | 11.17 :1 | 4.5 :1 | pass |
| dark | chip selected, tonal button, Learning chip | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | filled button, Known chip | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | text button and icon on sheet | p on sLow | 10.05 :1 | 4.5 :1 | pass |
| dark | text button on page | p on s | 10.86 :1 | 4.5 :1 | pass |
| dark | icon on raised block | p on sHigh | 8.46 :1 | 3 :1 | pass |
| dark | outline against page | ol on s | 5.84 :1 | 3 :1 | pass |
| dark | outline against card | ol on sLow | 5.4 :1 | 3 :1 | pass |
| dark | unselected chip text on page | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | unselected chip text on card | onSv on sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | change tag | onE on E | 7.72 :1 | 4.5 :1 | pass |
| dark | change outline on page | E on s | 10.89 :1 | 3 :1 | pass |
| dark | change outline on card | E on sLow | 10.09 :1 | 3 :1 | pass |
| dark | sheet title on sheet | onS on sLow | 13.28 :1 | 4.5 :1 | pass |
| dark | error text button on sheet | E on sLow | 10.09 :1 | 4.5 :1 | pass |
| dark | Shows boxes chip | onE on E | 7.72 :1 | 4.5 :1 | pass |
| dark | progress fill on its track | p on sc | 5.51 :1 | 3 :1 | pass |

## Behaviour checks (Chromium, Playwright)

- Loaded in Chromium at 1280 px and at 390 px wide, in light and dark: no page errors, no console errors, no horizontal page scroll at either width.
- Every control in every combination (4 courses, boxes or letters, one or every script, Ask me later on or off, Your decks or Look) was pressed in both themes: no errors, and no text spills out of a phone horizontally. Every sheet fits its phone at 1.4x text; only the Script fonts list scrolls, as a list does.
- Screenshots of each theme were checked by eye for Hindustani (boxes) and Korean (letters).
- The page takes Roboto and the Noto families from Google Fonts; offline the samples fall back to the system font, and the "boxes" are drawn on purpose.
