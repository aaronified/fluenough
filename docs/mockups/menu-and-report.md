# Menu and report: self-check and notes

Companion to `menu-and-report.html`. Owner brief, 2026-11-16: "Your languages menu should open the language list which is in languages. All the rest of the menu should go into a three dot menu in the languages screen (top right). Remove the bug report to accomodate the dots. The menu will open a dropdown with the options. We will use this same rule to simplify the app's other screens too. The necessity for having bug reports on every page is gone now. We need only a easy reporting mechanism for content. So content screens will keep the bug report, but it will be tailored towards content only. Kinda like how duolingo does it."

Controls: theme, language (Telugu, Hindustani, Bengali: the language list, the drill card and the report context follow it), where Learn from sits (language sheet or menu), highlight changes, IPA switch (greys "IPA replaces transliteration" in the menu, as today), and how the report goes (in the app, or by the mail app as today).

## What exists today (read from the code)
- **The bug icon** is `ReportButton` (`lib/ui/widgets/report_button.dart`, label "Get support or report a problem", `hintReport` "Report"), put on about 45 screens: the language bar (`language_bar.dart`), `TabHeader` and `PlaceholderPage` (`page_parts.dart`), the drill header (`drill_frame.dart`), and the app bars of most pages. Its doc comment says every screen has one (ADR-0021).
- **"Your languages"** is the first row of the Settings tab (`settingsRowLanguages`). It opens `LanguagesSettingsPage` (`features/settings/languages_page.dart`), a page of rows. Its first row, "Languages", opens the real list (`LanguagesPage`, `features/languages/languages_page.dart`, title "Languages", with "+ Add a language" and the bug icon in its bar).
- **The report mechanism**: `ReportButton.open` builds a `ReportRequest` (screen route, `detail` such as a card id, device info). With `Feature.feedbackMail` on it opens `ReportPage` (kind Support, Bug or Feedback, title, details, optional device info and app log) and hands a mail to the mail app (`ReportSender`, `ReportInMailApp`); a bug or feedback mail becomes a public GitHub issue through `tools/mail_to_issues.py`. Otherwise it opens a sheet and then a new GitHub issue (`issueBody`). Support has a second entry, "Send a bug report" (`supportSendBugReport`), and the word sheet and the unchecked-deck notice already have content-flavoured entries ("Report" with a flag icon, `cardReport`; "Report a mistake", `deckUnreviewedReport`) that call the same `ReportButton.open(detail: id)`.

## Screens in the mockup
- **a. Top bar.** The bug icon is gone from the language bar (Today, Decks, Progress) and from `TabHeader`. The width it freed is used: no empty slot is left, the wheel runs the whole 360 dp bar with its pill at the centre, and more neighbouring languages show at each side. The wheel is the same width on every tab and nothing moves between them (Progress has no All button, see Resolved 13). The page shows before and after.
- **b. Settings.** The row is still "Your languages", its line still names the languages learned. It now opens Languages directly. `LanguagesSettingsPage` and its "Languages" row are deleted.
- **c. Languages.** Under the last language (after the Know group) sits a full-width list row, "Your decks" (`settingsRowDecks`, line `settingsSumDecks`: "No decks of your own"), with the link icon at its end: it opens `YourDecksPage`, a different screen. The bar has "+ Add a language" (unchanged) and a three-dot icon at the top end in the bug's place.
- **d. The three-dot menu**, a native popup (`PopupMenuButton`), in two groups told apart by their marks, not only by a divider:
  | Group | Item and second line (existing strings) | Mark | Was |
  |---|---|---|---|
  | Show (toggles) | Latin-letter readings: `settingsRomanisationOn` / `Off` | leading box, empty when off, ticked when on | switch |
  | | IPA pronunciations: `settingsIpaOn` / `Off` | same | switch |
  | | IPA replaces transliteration: `settingsIpaReplacesOn` / `Off`, or `settingsIpaReplacesNeedsIpa` while IPA is off | same, disabled while IPA is off | switch |
  | | Adult content (18+): `settingsAdultOn` / `Off`; switching on still asks for age (`settingsAdultConfirmTitle`) | same | switch |
  | | Hide what is above my level: `settingsHideAboveOn` / `Off` | same | switch |
  | Open (buttons) | Fact languages (line: the languages checked, or All known languages) | chevron: its choices open in place inside the dropdown (frame d2), no sheet | row, was a bottom sheet |
  | | Sources | link icon: opens a different screen | row |
  | (variant) | Learn {language} from | only in the "The menu" variant, see below; link icon (opens `NativeChoicePage`) | row |
  Each toggle keeps the one-line explanation it had as a second, muted line under its label, showing the line for its current state, exactly as the row did on the old page. A toggle row is therefore two or three lines at 1.4x; a button stays one line (Fact languages keeps its value line). The menu is about 300 dp wide and taller than the screen at 1.4x, so it scrolls, as a Flutter popup does when it does not fit (the page shows it clipped and scrollable). A divider and two small labels (Show, Open) separate the groups. A toggle has the box in both states and no trailing icon; a button has a trailing icon and no box.

  **Icon rule (owner, 2026-11-16).** A chevron means "more choices inside this same dropdown" (a submenu, or a list that expands in place). A link icon (open-in-new) means "opens a different screen", or the mail app. Row by row, from the code:
  | Row | What it does today | Icon |
  |---|---|---|
  | Fact languages | `FactLanguagesSheet.show`: a modal bottom sheet, a checklist of the known languages, "At least one stays checked". It is a choice list, not a screen | chevron (right when closed, down when open): build it as a `SubmenuButton` whose children are `CheckboxMenuButton`s, so the checklist expands in place (frame d2) and the sheet is dropped |
  | Sources | `AppNavigator.openSources`: a page | link icon |
  | Your decks (now outside the dropdown, a row below the language list) | settings route `settingsDecks`: a page | link icon |
  | Learn {language} from (language sheet, not this menu) | `NativeChoicePage`: a page | link icon |
  | Report a problem (Settings menu) | `ReportPage`, then the mail app | link icon |
  | Latin-letter readings, IPA pronunciations, IPA replaces transliteration, Adult content, Hide above level | flip a setting | none (the box) |
  Only Fact languages qualifies for the chevron. The Settings tab's own list rows keep their chevrons: they are list rows, not dropdown rows.
- **e. The content report icon.** The app's existing bug glyph (`Icons.bug_report_outlined`) stays, now as the content report: in the drill header where it already is (`DrillFrame`, one place for every drill and the walkthrough), on the deck, unit and topic pages' app bars, and on the word sheet's Report button (whose `Icons.flag_outlined` becomes the bug glyph). Its label becomes "Report a problem with this card" (or deck).
- **f. Report sheet** (modal bottom sheet, drag handle): title "Report a problem with this card" (deck on deck pages); a monospace box of exactly what goes with it (card id, deck id, language pair, app version); five single-choice rows, all visible without scrolling; an optional one-line note (140 characters); Cancel and Send. No screenshot, no device log, no device details. A category with specifics shows a chevron and, once chosen, its choice as a second line.
  | Top-level row | Specifics (second-level popup, f2) | Shown on |
  |---|---|---|
  | Wrong options | The translation is wrong; No correct option is listed; More than one option is correct | choice drills show all three (recognition, picture choice, match, pair, set, reading questions: every exercise that lists options); every other drill, the word sheet and deck, unit and topic pages show only "The translation is wrong", as a direct row without a popup |
  | Reading or sound | The reading or IPA is wrong; The audio is wrong or missing | every screen |
  | Picture or example | The picture is wrong; The example sentence is wrong | every screen |
  | Offensive or inappropriate | none | every screen |
  | Something else | none; the note is where to say it | every screen |
  The two option reasons are the only exercise-only ones. The reason picked (with its category) becomes the report's title, `Content: Wrong options: No correct option is listed`; the note is the details. Card id, deck id (unit or topic id on those pages), language pair and app version go automatically.
  **Height.** The top-level sheet at 1.4x on a 360 dp screen measures 655 dp at its tallest (Hindustani, choice drill: the language-pair line wraps) and 614 to 634 dp otherwise, against a 740 dp screen: it needs no scrolling (measured in Chromium by the page, shown in the frame caption).
- **f2. Second-level popup** (a compact `AlertDialog`, surfaceContainerHigh): the title is the category, the specifics are radios, Cancel; picking one closes it and writes the choice under the row. The page shows it open over the sheet.
- **g. Confirmation.** "Thanks for the report" in the same sheet with Done. If reports go by the mail app (today's mechanism) the honest state is "Your report is ready. Your mail app has the report. Send it from there." (the tweak shows both).

## What "Learn {language} from" is, and where it should live
It is the **instruction language of a target language**: which of the languages the learner speaks the course of {language} is explained and taught from (ADR-0036, `NativeChoice`, `AppState.courseNative`). A Telugu course may exist from English and from Hindustani; a learner who speaks both picks one, and each teaches its own share of the course so far (`nativeChoiceCoverage`: "{covered} of {total} units so far"). Placement asks it the first time a course is opened, Today asks again when a language the learner speaks starts teaching a course they learn; the row only lets them change it later (`nativeChoiceBody`: "You can change this in Settings, and keep what you have learned"). It appears only for a language that more than one known language teaches (`offersNativeChoice`), which is why most learners never see it. It is a property of one language, not a setting of the app, so a menu of display switches is the wrong home.

Where it could live:
| Place | For | Against |
|---|---|---|
| **Inside each language's own sheet** (tap a language in the Languages list; `LanguageSkillsSheet`, where the skills of that language are set) | It is per language, next to the other per-language choices (skills, scripts); appears only where it applies; the menu loses its one per-course row and so stays a fixed length | One tap deeper than a menu row |
| At the top of the language's page | Always in view | There is no page per language today, only the sheet; a new page for one row |
| Stay in the three-dot menu | No work | A per-course row among global switches; the menu grows by one row per such language |

**Recommendation: the language's own sheet** (variant "Language sheet" in the mockup, frame h; the menu then has no Learn row). The row is the same tile as today (title "Learn Telugu from", line naming the current native language, chevron) and opens the same `NativeChoicePage`. The variant "The menu" shows the alternative.

## How it maps onto the existing mechanism
**Reused**: `Report` / `ReportRequest` / `ReportSender` / `ReportOutcome`, the mail subject prefix and `mail_to_issues.py`, `contextLines`, the GitHub fallback, `AppInfo.version`, the `Feature.feedbackMail` switch, the word sheet's Report button and "Report a mistake" (both become this sheet). A new `ReportKind.content` (label `Content`, public, so it becomes a public issue) with the reason as the title (`[Fluenough] Content: The translation is wrong`), the note as details, and context `Card`, `Deck`, `Languages`, `App`. The mail-to-issue Action reads the kind, so it needs one more label (`content`) and nothing else. `ReportRequest` gains `cardId`, `deckId`, `pair`; `always` prints them (replacing `Screen` and `Showing` for a content report).
**New**: one widget, `ContentReportButton` (the bug glyph, as before) and `ContentReportSheet` (five rows and a `ContentReportPopup`), used by `DrillFrame`, the word sheet, the deck and unit pages and culture item page. Strings: the five categories and the seven specifics, the title, the note hint, Send, the two confirmation texts.
**Removed**: `ReportButton` from every non-content screen, `WithReportButton`, the bug in `TabHeader`, `PlaceholderPage` and the language bar, `hintReport`'s use there, and the rule that "every screen has one" (comment in `report_button.dart`; `test/languages_and_scripts_bar_test.dart` and `test/languages_page_test.dart` look for the bug icon and change to look for the dots or the content report). The device-info box and the app-log box leave the content report; they stay in `ReportPage` for the general report.
**What stays general**: `ReportPage` (Support, Bug, Feedback with the optional log) stays, reached from Settings > Support ("Send a bug report") and from the two error links that call `ReportButton.open` directly (`update_escape.dart`, `spoken_languages_picker.dart`). So a bug in the app still has a home; it is one step deeper instead of on every screen.
**What the screens lose**: the one-tap route to a general bug report from any screen, and the route name `Screen:` that came with it. A bug filed from Support carries no screen; the app log (opt in) is the replacement.

## Every screen that shows the bug icon today, and the proposal
| Screen (file) | Proposal |
|---|---|
| Language bar on Today, Decks, Progress (`language_bar.dart`) | remove |
| Tab header and placeholder pages (`page_parts.dart`) | remove; the Settings tab header gets the three dots with "Report a problem" (resolved) |
| Languages (`languages_page.dart`) | remove; the three dots take its place |
| Drill header: recognition, reading, speaking, picture choice, rearrange, sets, grammar (`drill_frame.dart`) and walkthrough | keep as content report, bug icon, card id plus deck id |
| Drill page (`drill_page.dart`, the shell around a drill) | remove (the card has the bug icon) |
| Word sheet (`word_sheet.dart`, already a "Report" button, flag icon becomes the bug) | keep as content report, same sheet |
| Deck page (`deck_detail_page.dart`) and its "Report a mistake" notice (`unreviewed_notice.dart`) | keep as content report, same reasons, deck id instead of a card id (resolved) |
| Unit page (`unit_page.dart`) | keep as content report, same reasons, unit (deck) id (resolved) |
| Topic page (`topic_page.dart`) | keep as content report, same reasons, topic id (resolved) |
| Culture item page (`culture_item_page.dart`) | keep as content report, item id |
| Culture deck, timeline, recommendations, work questions (`culture_deck_page.dart`, `culture_timeline.dart`, `recommendations_page.dart`, `work_questions_page.dart`) | remove; reached through the item page, which has the bug icon |
| Summary after a session (`summary_page.dart`) | remove |
| Progress sub-pages: leeches, all tags, how you learn, over time (`features/stats/`) | remove |
| Reviewer mode: review, waiting, reviewed sent and not sent, review languages, daily questions, how reviewing works, offensive review (`features/review/`) | remove; reviewers have Suggest a change |
| Profiles, new profile, PIN (`features/profiles/`) | remove |
| Downloads page (`download_page.dart`) | remove |
| Update failure and spoken-languages picker error links (`update_escape.dart`, `spoken_languages_picker.dart`) | keep the link, it opens the general report |
| Settings > Support, "Send a bug report" | keep; the Settings three-dot menu also has "Report a problem" (resolved) |

## Contrast self-check (WCAG 2.1)
Computed from the app palette (`ColorScheme.fromSeed`, forest seed; same tokens as the other mockups).

| Pair | Light | Dark | Needed |
|---|---|---|---|
| Menu label (`onSurface` on `surfaceContainer`) | 14.7:1 | 12.7:1 | 4.5:1 |
| Menu line (`onSurfaceVariant` on `surfaceContainer`) | 8.0:1 | 9.6:1 | 4.5:1 |
| Menu checkmark (`primary` on `surfaceContainer`) | 5.5:1 | 9.6:1 | 3:1 (graphic) |
| Sheet text (`onSurface` on `surfaceContainerLow`) | 15.5:1 | 13.3:1 | 4.5:1 |
| Context box and hints (`onSurfaceVariant`) | 8.4:1 | 10.1:1 | 4.5:1 |
| Send (`onPrimary` on `primary`) | 6.5:1 | 7.7:1 | 4.5:1 |
| Cancel (`primary` on the sheet) | 5.8:1 | 10.1:1 | 4.5:1 |
| Radio and note-field outline (`outline`) | 4.1:1 | 5.4:1 | 3:1 (graphic) |
| Bug and dots icons (`onSurfaceVariant` on `surface`) | 8.9:1 | 10.9:1 | 3:1 (graphic) |
| Disabled "IPA replaces transliteration" | 38 percent, exempt | | exempt (disabled) |

Cues are never colour alone: checkmark against blank, the dividers, and the filled Send. Both icons are 48 dp targets (the second-level popup keeps its radios at 4.1:1 or better) with labels for screen readers ("More options", "Report a problem with this card"); the sheet's reasons are a `radiogroup`, the confirmation is a live region. Checked in Chromium (Playwright) at deviceScaleFactor 2, light and dark, Telugu, Hindustani and Bengali, 1.4x text, 360 dp, no horizontal page scroll.

## Implementation notes
- The menu is a `PopupMenuButton`, but `CheckedPopupMenuItem` shows its check only when on, so it cannot draw the empty box. Build the toggles as plain `PopupMenuItem`s (with `onTap` flipping the setting) whose child is a `Row` of `Icon(on ? Icons.check_box : Icons.check_box_outline_blank)` (primary colour when on, `onSurfaceVariant` when off), then the label, and `Semantics(checked: on, inMutuallyExclusiveGroup: false)` around it (`menuitemcheckbox` for screen readers). Because a `PopupMenuItem` closes the menu on tap, either accept that (every toggle closes the menu, as Android's own overflow menus do) or use `MenuAnchor` with `CheckboxMenuButton` for the toggles (it stays open and draws its own box in both states), `SubmenuButton` (chevron) for Fact languages and `MenuItemButton` with `trailingIcon: Icon(Icons.open_in_new)` for the three screens. The mockup shows the `MenuAnchor` look; the choice is free, the marks are the spec. The two groups are separated by a `PopupMenuDivider` (or `Divider` in a `MenuAnchor`) and two small `labelSmall` headers.
- Settings: `AppNavigator.openSettingsPage(settingsLanguages)` points at `LanguagesPage`; delete `LanguagesSettingsPage` and its route. Its rows move into a `_LanguagesMenu` (`PopupMenuButton<_Item>`) in `LanguagesPage`'s bar. Toggle state is the same `SettingsNotifier` fields; the menu rebuilds from `state.settings`. Each toggle keeps its explanation line as the item's second line (resolved).
- Everything else follows the rule "Remove `ReportButton`": the removal is mechanical (about 45 call sites) and is best done in one pull request with the new sheet.
- The same rule for other screens (owner: "We will use this same rule to simplify the app's other screens too"): not designed here, see the questions.
- Card ids stay permanent; the report carries them as they are.

## Resolved (owner, 2026-11-16)
1. **Learn {language} from** lives inside each language's own sheet. The menu has no Learn row (the page default is that variant).
2. **Reports** keep the mail hand-off for now, with no in-app endpoint. The confirmation shown by default is the mail-app wording ("Your report is ready. Your mail app has the report. Send it from there."). The "In the app" wording stays as a tweak for later.
3. **The content report affordance** sits in the drill header, where the bug icon was; superseded by 8 (it keeps the bug glyph).
4. **Deck, unit and topic pages** ALSO get the content report icon (not only a card and the word sheet). On those pages the reasons list is the same and the report carries the deck, unit or topic id instead of a card id (the "Deck page" setting of the page's Report from tweak: the context box has no `Card:` line).
5. **A general bug report** ALSO has a "Report a problem" item in the Settings three-dot menu, in addition to Settings > Support. It is a button-type row in the Open group, with the open-external glyph while reports go by the mail app (frame i). The Settings tab header gets the dots in the bug's place.
6. **Menu lines** (owner: "Why? Just add a checkbox, no?"): the toggles' explanations stay as a second muted line under each label in the popup, with the box at the leading edge, visible in both states. Buttons stay single-line with a trailing icon (chevron or link, see 11).
7. **"Your languages menu"** means the Settings row, which now opens the Languages list directly. The language bar's tap menu stays a language picker (default taken). For reference, today: the Settings row "Your languages" opens a page of rows (`LanguagesSettingsPage`) whose first row leads to the Languages list; the language bar's tap menu is the popup that appears when you tap the wheel at the top of Today, Decks or Progress, and only lists your languages to switch between.
8. **Top bar** (owner, 2026-11-16): the width the bug button freed is used. The wheel takes the full bar, centred as the app does, no empty right slot (frame a, before and after).
9. **Icon** (owner, 2026-11-16): the old bug icon is retained for the content report in the drill header and on deck, unit and topic pages, instead of a flag; the content-only reasons sheet stays behind it.
10. **Report sheet** (owner, 2026-11-16): its reasons are completely visible without scrolling at 1.4x on 360 x 740 dp. Five top-level rows; a row with specifics opens a small second-level popup; two reasons added for choice exercises, "No correct option is listed" and "More than one option is correct", under "Wrong options". Heights are in the f section.
11. **Dropdown icons** (owner, 2026-11-16): a chevron means more choices inside the same dropdown, a link icon means a different screen or the mail app. Applied row by row in the icon table above: only Fact languages gets the chevron (opened in place, frame d2); Sources, Learn from and Report a problem get the link icon in menus (Your decks moved out, see 12).
12. **Your decks** (owner, 2026-11-16): it is outside the three-dot dropdown, a visible full-width row below the list of added languages on the Languages screen, with the link icon (opens another screen). It is removed from the dropdown in every frame and variant.
13. **No All button on Progress** (owner, 2026-11-16: "Remove the all option in progress screen, and then build"). The All button (`_AllButton` in `language_bar.dart`, the `progressAll` setting) is gone from the language bar and from frame a. What it did: it counted every language's numbers together on Progress (the start date only, since levels differ by course) instead of the language at the wheel's centre. That all-languages view can no longer be turned on from the app; the setting and `AppState.progressShowsAll` stay as data code (a stored "on" still counts every language until another language is picked on Progress).

## Open questions for the owner (still open)
1. **Reviewer screens**: remove as proposed, or keep the content report there too?
2. **Other screens' rule.** Which screens get the same three-dot treatment next (Decks, Progress, Settings pages)?
