# Language picker: self-check and notes

Companion to `language-picker.html`. It redesigns the Add a language screen (`lib/features/languages/language_pick_list.dart`, `CourseLine` in `lib/features/placement/course_line.dart`, `VerificationMark` and `VerificationFlag` in `lib/features/languages/verification_mark.dart`) so that a new user is not lost in one long alphabetical list. Controls: theme, which language is already added (Telugu, Hindustani, Bengali, or none for the first launch), Coming soon collapsed or expanded, and highlight. Tiles, rows, the Coming soon header and the flags are live (tap a flag for its label). Everything is drawn at 1.4x text, the app's cap, 360 dp. The figures (how much of each part is written) and verification states are illustrative; the app reads them from `progressFor` and the language entry. These bars describe the course, never the learner's own progress, so the wording avoids "progress" for them.

## Screens
- a. First screen, "What do you want to learn?": a search field, nine tiles (the `popular: true` languages of `assets/languages.yaml`: Spanish, French, Telugu, Hindustani, Bengali, Marathi, Kannada, Japanese, Mandarin Chinese), then a "See all languages" link. A tile has the native-script name large, the English name, and one status line.
- b. "All languages", the top: search, one key (how much of the course is made, and verification, shown once), then "Languages", A to Z, only languages that have a course.
- c. The bottom of the same list: "Scripts and sounds" (IPA, English Braille: no bars, no flag), then a "Coming soon" header, folded by default, with the languages that have no course inside it.
- d. Find my level, unchanged, with its four real options: How well do you know {language}? Expert (I use it easily), Advanced (I follow most of it and can say what I need), Amateur (I know some words and phrases), Beginner (I am starting from nothing). The app shows only the answers the course's built path supports (`declarationOptionsFor`), so a short course shows fewer.

A tap on a tile or a row goes straight to d. There is no new step and no "Start from the basics" screen. ("Start at the beginning" on the first-launch questions is the existing button on the first placement question, also unchanged.)

## What changed and why
| Owner's point | Change |
|---|---|
| A new user sees an endless list and many "No course yet" rows | Nine big tiles first; the full list shows only languages with a course; languages without one are folded under "Coming soon" (collapsed by default, a native button with `aria-expanded`). No "No course yet" chip in the main list. |
| Tiles must say what you get | The status line is derived from the course: "A1 to B1 ready" (B1 fully written), "A1 and A2 ready", "A1 ready", "Beginner course" (A1 partly written), "First words only" (a course, no path yet). |
| Do not lose the information on how much of each course is made | The four A1, A2, B1, Culture bars stay, as one slim bar of four segments (6 dp, 4 dp gaps). Filled, partly filled and empty segments show made, partly made and still to come at a glance. The labels A1, A2, B1, Culture are drawn once, in the key at the top, not per row. A screen reader still reads one line per row ("How much of the course is made: A1 100%, A2 100%, ...", in the style of today's `pickerCourseLineLabel`, "Course written: ..."). |
| "Verified: Not at all" text row is clutter | It becomes the app's own flag glyph at the end of the bar line: outlined (Not at all), half-solid (Somewhat), solid (Completely), muted or primary. Shape carries the state, not colour. A tap (or long-press on a phone) shows a tooltip, "Verified by native speakers: somewhat" plus the detail sentence (`languagesVerifiedNoneDetail` and the others). Its accessible name is `languagesVerifiedLabel`. The key at the top says the three states once (the existing `VerificationKey`, folded into the same card). |
| IPA and English Braille do not belong in the language list | A separate "Scripts and sounds" group, with no bars and no flag (as `isNotation` rows are today). |
| After picking, nothing new | The pick leads to the existing Find my level, with its real strings. |

The "Added" state stays: a filled avatar and an "Added" chip on a row, a filled tile with "Added" in its status on the first screen (so on a later visit the user sees what they already have).

## Contrast self-check (WCAG 2.1)

Computed from the app palette (`ColorScheme.fromSeed`, forest seed, as in the other mockups).

| Pair | Light | Dark | Needed |
|---|---|---|---|
| Names and headings (`onSurface` on `surface`) | 16.3:1 | 14.3:1 | 4.5:1 |
| Own names, key text, one-line status (`onSurfaceVariant` on `surface`) | 8.9:1 | 10.9:1 | 4.5:1 |
| Tile status and key text on `surfaceContainerLow` | 8.4:1 | 10.1:1 | 4.5:1 |
| Tile names on `surfaceContainerLow` | 15.5:1 | 13.3:1 | 4.5:1 |
| "Languages" heading and "See all languages" (`primary` on `surface`) | 6.2:1 | 10.9:1 | 4.5:1 |
| "Added" chip and added tile (`onPrimaryContainer` on `primaryContainer`) | 7.2:1 | 7.2:1 | 4.5:1 |
| Added avatar (`onPrimary` on `primary`) | 6.5:1 | 7.7:1 | 4.5:1 |
| Avatar letter (`onSecondaryContainer` on `secondaryContainer`) | 7.2:1 | 7.2:1 | 4.5:1 |
| Coming soon header (`onSurface` on `surfaceContainerHigh`) | 14.0:1 | 11.2:1 | 4.5:1 |
| Search hint (`onSurfaceVariant` on `surfaceContainerHigh`) | 7.6:1 | 8.5:1 | 4.5:1 |
| Tooltip (`surface` on `onSurface`) | 16.3:1 | 14.3:1 | 4.5:1 |
| Filled bar segment (`primary` on the track `surfaceContainerHighest`) | 5.0:1 | 7.2:1 | 3:1 (graphic) |
| Flag, Not at all (`onSurfaceVariant` on `surface`) | 8.9:1 | 10.9:1 | 3:1 (graphic) |
| Flag, Somewhat and Completely (`primary` on `surface`) | 6.2:1 | 10.9:1 | 3:1 (graphic) |
| Empty track (`surfaceContainerHighest` on `surface`) | 1.2:1 | 1.5:1 | not met |

The empty track is below 3:1, as it is in today's `CourseLine`; the cue is the filled segment against it (5.0:1 and above), and every figure is also in the row's screen-reader label. If the owner wants the empty track to pass, use `outlineVariant` for it (open question 4).

No cue is colour alone: the flag states differ in shape (outline, half, solid), a tile says its status in words, "Added" is a word and a check. Checked in Chromium (Playwright) at deviceScaleFactor 2, light and dark, 1.4x text, 360 dp, with no horizontal page scroll (also at a 360 px viewport). Targets: tiles and rows are at least 56 dp tall, the flag button is 40 x 40 dp (the visible glyph is 22 dp).

## Implementation notes
- Data: no new field is needed. A language has a course when `LanguageView.course != null` (`language_views.dart`); `canLearn` also needs the app to be new enough, so a course the app is too old for stays in the main list greyed with its "needs app" line, as today. "Coming soon" is `course == null && !language.isNotation`. Tile status uses `course.progressFor(...).levels` (already read by `_line`): the highest level whose share is 1.0, "Beginner course" if A1 > 0, else `languagesFirstWordsLabel`. Notations are `language.isNotation`.
- `LanguagePickList`: add a `PopularTiles` first screen (the `popular` set already exists; add Telugu's flag if missing, it is `popular: true` now). "See all languages" pushes or swaps to the list. The search field stays on both; typing on the first screen switches to the list with matches (Popular matches first, as now) and a match inside Coming soon expands that group.
- List: `_row` loses the `VerificationMark` text row and the `CourseLine` labels. A new `CourseLine` variant (a `compact` flag): four segments, no labels, height 6, and a trailing `VerificationFlag` in a 40 dp `IconButton` with `tooltip:` (the tooltip shows on long-press and on hover; a tap opens the same text in a small bubble or a bottom sheet) and `Semantics(label: languagesVerifiedLabel)`. `VerificationKey` gains the one-time key titled "How much of the course is made" with the segment labels (A1, A2, B1, Culture) above its existing flags.
- Groups, in order: Languages (course), Scripts and sounds (notations), Coming soon (a stateful header, collapsed by default, `ExpansionTile`-like, with `Semantics(expanded:)`). The "Popular" heading and note go away from the list (the tiles replace them).
- The pick callback is unchanged (`onPick`), so a pick still ends in the Find my level declaration page (`FindLevelDeclarationPage`).
- Strings: new `languagesAddQuestion` ("What do you want to learn?"), `languagesSeeAll` ("See all languages"), `languagesTileStatusA1B1` and its siblings (or one plural-free function), `languagesScriptsAndSounds`, `languagesScriptsAndSoundsNote`, `languagesComingSoon`, `languagesCourseMadeKey` ("How much of the course is made"), `languagesCourseMadeLabel` ("How much of the course is made: {levels}"). `languagesPopular`, `languagesPopularNote` and `languagesNoCourse` (as a chip) are retired; `languagesAllLanguages` becomes the "Languages" heading.
- The first launch uses the same widget (as today): the user lands on screen a with no "Added" tile.

## Open questions for the owner
1. A tap on a Coming soon language: keep what it does today (adds it as Know only, then the usual flow), or make it non-tappable until it has a course?
2. Resolved (owner): the Coming soon header shows only its label, with no count.
3. Tile status wording for a course with no path ("First words only") and for a partly written A1 ("Beginner course"): keep these two phrases?
4. The empty bar track: keep today's `surfaceContainerHighest` (below 3:1) or move to `outlineVariant`?
5. Tap on the flag: tooltip bubble only, or open the language's details sheet with its Verified row?
6. The ninth tile (Mandarin Chinese) spans the full width because nine is odd. Acceptable, or drop to eight, or use a three-column grid at normal text sizes only?
