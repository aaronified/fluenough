# Language level and verification markers: self-check, notes and open questions

Companion to `language-level-verification.html` (owner, 2026-11-06: "In the language screen, add two markers for each language. 1) level: no decks, pre-alpha, alpha, beta, complete (use the a1-a2-b1 line as everywhere else, below the texts). 2) whether it is verified by native speakers (three flags, not at all, somewhat, completely). The language list after selection here will also show the verification status. Build a mockup first." and "The a1-a2-b1 line will be the same as it is elsewhere. The empty part is the only new thing to add there."). The page holds only the screens and their tweak controls, with what is new or changed outlined in red. Nothing here is decided.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the four seeds (the tokens of `settings.html`), light and dark, Hindustani and Bengali examples. **All levels and verification states on the page are placeholders.** Real verification data does not exist yet, so every language starts at Not at all; the button "Real starting state" on the page sets that.

## Screens

- **A. Add a language** (`language_pick_list.dart`). Each row keeps its glyph, names, Added badge or "No course yet" and chevron, and gains two markers under its texts, indented to the names: the A1 A2 B1 Culture line (`CourseLine`, unchanged: 4 dp bars, labels under) and the verification mark. A short key above the list names the three verification states. Three views of one scrolling list; the list is the owner's screenshot (Bengali and Hindustani added, Assamese, Dogri "No course yet", Gujarati, Kashmiri, Konkani, Maithili, Marathi, Nepali, Odia).
- **B. Languages, after selection** (`languages_page.dart`). Rows keep their skill chips and gain the verification mark under them. The line is not drawn here (the owner asked only for verification on this list); a tweak turns it on to compare. The existing chip key gains the three verification entries.
- **C. States.** One language (Hindustani or Bengali) in all five levels and all three verification states, and the i dialog (`_InfoDialog`) with the long wording.

## The verification mark

A flag icon with a word, never colour alone. Three shapes: **Not at all** an outlined flag, **Somewhat** a half-filled flag, **Completely** a solid flag; the word is always drawn ("Verified: Somewhat"). Only the icon's colour differs (muted for Not at all, primary for the others) and it is not needed to tell them apart. A tweak swaps the flag for a person, same three fills. The mark is minimal on purpose: one 20 dp icon and one line of text, no chip, so a list of eleven rows stays calm.

Screen reader: the mark reads "Verified by native speakers: somewhat" (one `Semantics` label, icon and text excluded). A long press shows a tooltip of two words, "Native-checked"; proposed, see question 7. IPA and English Braille show no mark (no native speakers; the per-language selector has a "Hidden" option).

## The level line

Reused as the app draws it elsewhere. The only new state is the **empty line**: all four bars at their track, labels kept, for a language with no decks (and, by default, pre-alpha). The line's screen-reader label is "Course written: A1 55%, ..."; for the empty states proposed labels are "No decks yet" and "First words only". The level name is not written (default, owner asked whether names appear); a tweak shows the app's existing `StageTag` look (Alpha, Beta, Complete, plus No decks and Pre-alpha) above the line for comparison. It does not fit beside the line at 1.4x: four labelled bars need the whole text column.

### How a level maps to path progress

| Level | What exists | A1 | A2 | B1 | Line | Row text |
|---|---|---|---|---|---|---|
| No decks | no deck of any kind | 0 | 0 | 0 | empty | "No course yet" (existing, `!canLearn`) |
| Pre-alpha | first-words deck, path not begun | 0 | 0 | 0 | empty, or a sliver of A1 (tweak) | none (the course is learnable, so "No course yet" goes) |
| Alpha | path exists, A1 being written | in progress | 0 | 0 | A1 part filled | none |
| Beta | A1 written, B1 being written | full | in progress | in progress | A1 full, A2 and B1 part | none |
| Complete | every unit up to B1 written | full | full | full | three full, Culture empty | none |

Alpha, Beta and Complete are the app's existing `CourseStage` (`language_catalog.dart`): Alpha until every A1 unit of the plan is written, Beta until every B1 unit is, Complete after. Pre-alpha and No decks are the two new values below Alpha. The tweak "Bar fills: Whole bars" draws the owner's wording literally (Alpha = A1 filled, Beta = A1 and A2 filled).

## Where the verification data would come from (proposal)

A `verification` field on each language in `assets/languages.yaml`, set by the owner by hand, one of `none`, `some`, `full`; absent means `none`, so every language starts at Not at all and nothing needs filling in first. It is read with the language, no network, no deck change, no card id touched. Per-language, not per-deck, to begin with; per-deck data (a `verified` field in a deck's metadata, rolled up to the language) is the later step if "somewhat" should mean something measurable. Proposed meaning (tweak the wording): Not at all, no native speaker has checked the course; Somewhat, some decks or units have been read by native speakers; Completely, every deck up to its level has.

## Self-check results

**Contrast** (WCAG, computed in the page's JS, `window.__contrast`, run in Chromium; all four seeds, light and dark; the table shows the lowest ratio over the seeds and which seed). Text 4.5:1, icons and bars 3:1.

| Pair | Needs | Light | Dark | Result |
|---|---|---|---|---|
| name text onSurface on surface | 4.5 | 16.2 (iris) | 14.31 (ocean) | pass |
| own name, line labels, onSurfaceVariant on surface | 4.5 | 8.88 (iris) | 10.88 (forest) | pass |
| verification word onSurface on surface | 4.5 | 16.2 (iris) | 14.31 (ocean) | pass |
| verification word, Not at all, onSurfaceVariant on surface | 4.5 | 8.88 (iris) | 10.88 (forest) | pass |
| flag icon Somewhat and Completely, primary on surface | 3 | 6.13 (iris) | 10.86 (forest) | pass |
| flag icon Not at all, onSurfaceVariant on surface | 3 | 8.88 (iris) | 10.88 (forest) | pass |
| line fill, primary on its track | 3 | 4.99 (iris) | 7.23 (forest) | pass |
| search hint on surfaceContainerHigh | 4.5 | 7.63 (clay) | 8.42 (iris) | pass |
| level name onTertiaryContainer on tertiaryContainer | 4.5 | 7.24 (forest) | 7.24 (forest) | pass |
| Added badge | 4.5 | 7.21 (forest) | 7.21 (forest) | pass |
| family heading, primary on surface | 4.5 | 6.13 (iris) | 10.86 (forest) | pass |
| key text | 4.5 | 16.2 (iris) | 14.31 (ocean) | pass |
| dialog text, caption and flag on surfaceContainerHigh | 4.5 / 3 | 13.92, 7.63, 5.26 | 11.09, 8.42, 8.43 | pass |
| chips Learn, Know, Level found, Leave | 4.5 | 7.24 to 11.88 | 5.13 to 9.84 | pass |
| **empty track on surface** | 3 | **1.23** | **1.5** | **fails, inherited** |

The empty track fails 3:1 in every seed, and it fails the same way in the app today (`CourseLine`: `surfaceContainerHighest` on `surface`). It matters more now: the empty line is the new state and is nearly invisible, so on a no-decks row the labels A1 A2 B1 Culture do the work. Not changed, because the owner asked for the line "the same as it is elsewhere". Question 5.

**1.4x wrapping.** Run in Chromium at 1.4x and 1x, light and dark, Hindustani and Bengali selected, with "Name as well" and "Level line on Languages too" on (the widest case): no marker, name, badge or dialog text extends beyond its phone, and no list scrolls sideways. The verification text ("Verified: Completely") and the key wrap to a second line instead of clipping. A row is about 120 dp tall at 1.4x (about 56 before this change), so Add a language shows about 5 languages in 740 dp instead of 9; cost, see question 6.

**Tap targets.** Each row stays one target, as today: the smallest row is 120 dp high, full width (minimum 48 dp). The markers are not separate targets and have no tap of their own.

**Semantics.** Each row reads names, then the line's label, then "Verified by native speakers: somewhat". Icons are excluded from the tree; nothing relies on colour (level: bar fill and labels, optionally the name; verification: the shape and the word).

**Text in widgets.** On build, every string is an ARB token (rule 10): `languagesVerifiedLabel` ("Verified by native speakers: {state}"), the three state words, the key heading, the empty line's two labels, the two new level names.

## Open questions for the owner

1. **Level names.** Line only (default), or the name as well? The page shows the name above the line. At 1.4x it cannot sit beside the line.
2. **Does Alpha mean A1 being written or A1 filled?** The app's `CourseStage` is Alpha until A1 is written and Beta until B1 is; your list reads as A1, then A1 and A2, then all three. The page draws the app's rule by default and your reading under "Whole bars". Which should the new markers follow?
3. **Pre-alpha line.** Empty (default; told from No decks only by the missing "No course yet"), or a sliver of A1, which tells them apart by the line alone?
4. **Where does "first words only" show?** Now only through the line. Does it need a word on the row?
5. **The empty track is almost invisible** (1.23:1 light). Leave it as everywhere else, or give the track an outline (everywhere, as its own change)?
6. **Row height.** Two markers make a row twice as tall. Is that right for Add a language, or should the verification mark sit on the name's line, to the right (it then drops the Added badge's space)?
7. **Words.** "Verified: Somewhat" with the key above, or the full "Verified by native speakers" on every row (two lines)? Flag icon or person?
8. **Pills called Verified already exist.** The dark-green double tick on a skill chip means "Level found" by placement (`pillVerified`). The new mark is a different kind of verification; the page uses a flag and the word "Verified" next to "native speakers" in the key. Rename one?
9. **Languages page.** Verification only, as asked, or the line too? Which rows get the flag: courses only (proposed), with none on IPA and Braille?
10. **Data.** A hand-set `verification` field per language in `assets/languages.yaml` (proposed), or per deck from the start?
