# All tags: self-check, notes and open questions

Companion to `all-tags.html` (owner, 2026-10-24: "Beautify the all tags page. This needs a small mockup, as not much is happening here anyway."). The page holds only the screens and their tweak controls, with what changed outlined in red. The checks and notes are here. Nothing below is decided; every open choice is a tweak control on the page.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed (the tokens of the other mockups; the bar colour is the scheme's tertiary, as `AllTagsPage` draws it), light and dark, Hindustani and Bengali examples (Bengali readings follow the course: no final a). Theme, course and highlight are global controls.

## What the screen is today

`lib/features/stats/all_tags_page.dart`, opened from Progress, Weakest tags, "All tags ›" (#499). Each row is a `BarRow` (tag name in a 100 dp column, a 12 dp bar, the percentage) plus a `TextButton` "Practise" right-aligned on its own line, so a row is about 2 lines tall and only 6 to 7 tags fit a screen at 1.4x. Rows are the tags with answers, weakest first (the share of taught pairs known), then the tags with no answer, A to Z, shown "–". Practise starts `DrillRequest.tag(tag, count: 20)`; it is disabled, with a tooltip, when no word with the tag is taught.

The left phone on the page is that, drawn from the real data.

## What the proposal changes

1. **Practise moves inline** as a round play icon (36 dp circle in a 48 dp target) at the end of the row, labelled "Practise <tag>" for screen readers. The text button on its own line goes.
2. **The bar thins** from 12 dp to 6 dp.
3. **A tag with nothing taught says so in the row** ("No word taught yet") instead of in a tooltip, which a finger cannot show (Two lines only; One line keeps the disabled ring and the tooltip).
4. Everything else is unchanged: the same percentage, the same "–", the same order by default, the same drill.

## Variants (tweak controls)

- **Row.** *One line*: tag, a thin bar, the percentage, the play icon; 10 tags fit where 7 did. *Two lines*: the tag in a larger size with a facts line under it ("64 words taught", and an example word with its reading), the percentage and the play icon at the end, the thin bar full width underneath; about 5 tags per screen, but long tag names and the example word have room. Example word is a sub-control.
- **Grouping.** *No groups*, or *By kind* with a heading per kind and its average (Level, Part of speech, Politeness, Theme).
- **Sort.** *Weakest first* (today's), *A to Z*, *Most words*. With a sort other than weakest first, tags with no answer are mixed in by that sort rather than put last.

## Open questions

1. **Kinds are not in the data.** A card's tags are plain strings (`noun`, `honorific`, `family`, `beginner`); the deck format has no tag kinds. "By kind" on the page infers them. Options: (a) a small shared `decks/tag-kinds.yaml` mapping a tag to a kind, like `themes.yaml`, with a validator check that every tag in use has one (the downside: every new tag needs an entry, and a deck contributor must know it); (b) infer in the app from a fixed list (the downside: wrong for any tag the list lacks, and hidden from deck authors); (c) leave grouping out and keep only the sort.
2. **One line or two?** One line shows the most tags and is the smallest change; Two lines reads better with long tag names and says more per tag, but halves the tags per screen.
3. **Example word per tag.** It needs one pick per tag per course (the most-known word? the first taught?). Not available today; the page draws a fixed one. Hide it if the answer is no.
4. **Sort control.** Where does it live, if kept: an app bar action opening a menu, or a chip row under the app bar? The page draws neither, only the result.
5. **Disabled Practise** in One line has no visible reason. Options: leave the tooltip, or show a short second line only for such tags.
6. The percentage's meaning is unchanged (the share of taught pairs known now, not the range's).

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, icons and bar fills 3:1. All 22 pairs pass.

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text, tag name, percentage | onS on s | 16.33 :1 | 4.5 :1 | pass |
| light | facts line, group heading, disabled Practise | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | Practise text button | p on s | 6.16 :1 | 4.5 :1 | pass |
| light | play icon on its circle | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | bar fill on its track | tt on sc | 5 :1 | 3 :1 | pass |
| light | bar fill on page | tt on s | 6.17 :1 | 3 :1 | pass |
| light | disabled play ring | onSv on s | 8.9 :1 | 3 :1 | pass |
| light | change outline on page | E on s | 6.16 :1 | 3 :1 | pass |
| light | change tag text | onE on E | 6.46 :1 | 4.5 :1 | pass |
| light | toast text | s on onS | 16.33 :1 | 4.5 :1 | pass |
| dark | body text, tag name, percentage | onS on s | 14.33 :1 | 4.5 :1 | pass |
| dark | facts line, group heading, disabled Practise | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | Practise text button | p on s | 10.86 :1 | 4.5 :1 | pass |
| dark | play icon on its circle | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | bar fill on its track | tt on sc | 5.52 :1 | 3 :1 | pass |
| dark | bar fill on page | tt on s | 10.88 :1 | 3 :1 | pass |
| dark | disabled play ring | onSv on s | 10.88 :1 | 3 :1 | pass |
| dark | change outline on page | E on s | 10.89 :1 | 3 :1 | pass |
| dark | change tag text | onE on E | 7.72 :1 | 4.5 :1 | pass |
| dark | toast text | s on onS | 14.33 :1 | 4.5 :1 | pass |

Notes: the tertiary colour is approximated from the seed (light `#3b6470`, dark `#a4cddd`); check it against the app's `ColorScheme` when building. Disabled controls are drawn at 70% opacity and are exempt from the ratio, but the reason is given in words in Two lines. The percentage carries the value, so the bar is a redundant cue and needs only 3:1.

## Behaviour checks (Chromium, Playwright)

- Loaded in Chromium at 1280 px wide: no page errors, no console errors, no horizontal page scroll, and no horizontal overflow inside either phone.
- Every combination was set in both themes and both courses: Row (2) x Grouping (2) x Sort (3) x Example word (2), 48 per theme and course: no errors.
- Practise pressed: the toast "Starts 20 words tagged ..." shows in the right phone; a disabled button does nothing.
- Screenshots of each theme and course were taken of the full page.
- Fonts: Roboto, Noto Sans Devanagari and Noto Sans Bengali from Google Fonts; where offline the system fallback is used.
