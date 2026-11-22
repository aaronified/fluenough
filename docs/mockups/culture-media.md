# Culture pictures: self-check and notes

Companion to `culture-media.html` (`wiki/Plan-Culture-Media.md` package 3, ADR-0060; owner decision 16 asks for this mockup first). It extends the screens that exist today: the culture list on Decks, the People list, the creator card, Settings > Sources and the Culture group of a language's sheet. Controls: theme, example course (Hindustani or Bengali), text size (1.0x, 1.2x, 1.4x; 1.4x is the cap and the default), Free pictures (Some or None) and a highlight of what is new or changed. The pictures on the page are drawn stand-ins (sepia for old material), not real files; titles, years and credits are examples for a bilingual reviewer to replace.

Open the page: open `docs/mockups/culture-media.html` in a browser (it needs only the Google Fonts stylesheet).

## Screens
1. **Lists.** 1a, Decks > culture list, Films tab: a work with a poster shows it in place of the medium icon; a work without one keeps the medium icon in its box exactly as today. Expected coverage is 10 to 25 per cent of works and most films will have none, so the icon is the normal case, not an error. 1b, People: a portrait in the creator thumb, or the person icon.
2. **Work page.** 2a: poster, credit caption (author, licence short name), a "Licence and source" link that opens the Commons page, then the title, reading, creator and year, kind and level tags, briefing, the legal route and "I've completed this" (the one primary action). 2b: no free picture: no poster block, the medium icon sits beside the title, everything else is the same. No apology text, no "no picture" line.
3. **Viewer.** Full screen, black in both themes, pinch to zoom (3b, pinched in), close at the top, the same credit and link at the bottom over a gradient. The picture is decoded at full size here only.
4. **Creator card.** 4a: portrait (tap to open the viewer), the caption and "Licence and source" as the card shows them today, now for portraits that exist. 4b: the person icon, no caption.
5. **Sources.** The existing "Wikimedia Commons" row under Deck content says "Recordings and pictures of words, people and works, each under its own licence and with its credit" (changed). The credits of the portraits and posters join the existing "Recordings and pictures" row of the language, one line per credit.
6. **Show pictures and Download pictures.** Both sit in the Culture group of the language's sheet, under the two existing switches. 6a: on, with the size at the right; 6b: downloading (ring; when done the ring is a tick); 6c: off, and the download row is gone.

## Lazy loading
A picture is fetched when first shown. Until it arrives, and when offline, the thumb shows the same placeholder icon as "no free picture", so there is no spinner, skeleton or error state to draw; the picture replaces the icon when it is on the phone. That is why no extra frame shows it.

## Where the switch sits, and why
The plan proposes a "Show pictures" switch and a per-course "Download pictures" action. Placed in the Culture group of the language's sheet because the group already holds the course's culture switches, so nothing new is added to Settings (one more row) or to the culture screens, which have no overflow menu today (adding one for a single switch is a new piece of furniture). The download row is under the switch and disappears when the switch is off, so one row less when it cannot apply. The switch has no sub-line, unlike its neighbours, to stay short; the picture or its icon is the state.

## Owner rules checked on the page
- Nothing about reviewers or quorum; no course-level counts anywhere (the size on the download row is bytes, not a count).
- No repeated headings, no helper sentence that restates a control, one primary action per screen, state shown by icon and picture.
- The existing medium icon stays the placeholder; the caption and link reuse today's strings ("Image: ...", "Licence and source").
- A picture is never inverted or themed; a hairline in `outlineVariant` keeps a light poster from floating on a light surface.

## Choices I made that the plan does not fix (confirm)
1. A work page exists. Today a work opens in place as a row in the culture list (`CultureWorkRow`, open state). The plan says "work page", so the poster and its caption need room. The fallback is to put the poster, caption and link at the top of the open row.
2. A poster is 200 by 290 dp (about 0.69), centred; the list thumb is 48 by 68 dp and portraits are 48 dp squares (today's `CreatorThumb`), 96 dp on the card. Pictures are cropped to fill, not letterboxed.
3. The work page has no title in the app bar, to avoid repeating the title below.
4. A small zoom badge (icon only) on the poster and portrait shows they open the viewer.
5. "Show pictures" is per course (in the language's sheet), not one switch in Settings as the plan words it. A single global switch is the alternative.
6. Download size is shown at the right of the row (12 MB, 9 MB are illustrative).
7. The picture credit joins each language's existing "Recordings and pictures" row on Sources instead of a new row.
8. A medium icon box is kept for works, and a book uses the book icon, a film the film icon (today's `recommendationIcon`).
9. Credits, titles, years and creators on the page are examples; the Hindustani and Bengali film pictures stand in for a public-domain silent-film poster.

## Contrast self-check (WCAG 2.1)
Computed from the app palette in the page (`ColorScheme.fromSeed`, forest seed; same tokens as `reviewer-ux.html`).

| Pair | Light | Dark |
|---|---|---|
| Title text on a row | 15.5:1 | 13.3:1 |
| Caption and reading (muted) on a row | 8.4:1 | 10.1:1 |
| Caption on the screen | 8.9:1 | 10.9:1 |
| Link (primary) on the screen | 6.2:1 | 10.9:1 |
| Icon on its placeholder (graphic, needs 3:1) | 7.2:1 | 7.2:1 |
| Filled button text on primary | 6.5:1 | 7.7:1 |
| Muted text on a Sources tile | 8.4:1 | 10.1:1 |
| Switch thumb on its track (graphic, needs 3:1) | 6.5:1 | 7.7:1 |
| Viewer caption (#E6E6E6) on the gradient, worst case a white picture | 9.4:1 | 9.4:1 |
| Viewer link (#A9E5BF) on the same | 8.2:1 | 8.2:1 |

Text needs 4.5:1. The poster's hairline is decoration, not the only cue for the control: the zoom badge and the caption identify it. Targets are at least 48 dp (rows, the link, the close button). Checked in Chromium (Playwright): light and dark, Hindustani and Bengali, Free pictures Some and None, 1.4x text, 360 dp frames, no script errors, no horizontal page scroll at 390 px wide; the only element reaching past a frame is the pinched-in picture, clipped by design.
