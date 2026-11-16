# Menu and report: self-check and notes

Companion to `menu-and-report.html`. Owner brief, 2026-11-16: "Your languages menu should open the language list which is in languages. All the rest of the menu should go into a three dot menu in the languages screen (top right). Remove the bug report to accomodate the dots. The menu will open a dropdown with the options. We will use this same rule to simplify the app's other screens too. The necessity for having bug reports on every page is gone now. We need only a easy reporting mechanism for content. So content screens will keep the bug report, but it will be tailored towards content only. Kinda like how duolingo does it."

Controls: theme, language (Telugu, Hindustani, Bengali: the language list, the drill card and the report context follow it), where Learn from sits (language sheet or menu), highlight changes, IPA switch (greys "IPA replaces transliteration" in the menu, as today), and how the report goes (in the app, or by the mail app as today).

## What exists today (read from the code)
- **The bug icon** is `ReportButton` (`lib/ui/widgets/report_button.dart`, label "Get support or report a problem", `hintReport` "Report"), put on about 45 screens: the language bar (`language_bar.dart`), `TabHeader` and `PlaceholderPage` (`page_parts.dart`), the drill header (`drill_frame.dart`), and the app bars of most pages. Its doc comment says every screen has one (ADR-0021).
- **"Your languages"** is the first row of the Settings tab (`settingsRowLanguages`). It opens `LanguagesSettingsPage` (`features/settings/languages_page.dart`), a page of rows. Its first row, "Languages", opens the real list (`LanguagesPage`, `features/languages/languages_page.dart`, title "Languages", with "+ Add a language" and the bug icon in its bar).
- **The report mechanism**: `ReportButton.open` builds a `ReportRequest` (screen route, `detail` such as a card id, device info). With `Feature.feedbackMail` on it opens `ReportPage` (kind Support, Bug or Feedback, title, details, optional device info and app log) and hands a mail to the mail app (`ReportSender`, `ReportInMailApp`); a bug or feedback mail becomes a public GitHub issue through `tools/mail_to_issues.py`. Otherwise it opens a sheet and then a new GitHub issue (`issueBody`). Support has a second entry, "Send a bug report" (`supportSendBugReport`), and the word sheet and the unchecked-deck notice already have content-flavoured entries ("Report" with a flag, `cardReport`; "Report a mistake", `deckUnreviewedReport`) that call the same `ReportButton.open(detail: id)`.

## Screens in the mockup
- **a. Top bar.** The bug icon is gone from the language bar (Today, Decks, Progress) and from `TabHeader`. The right slot stays an empty 48 dp, as the left one already is off Progress, so the wheel stays centred.
- **b. Settings.** The row is still "Your languages", its line still names the languages learned. It now opens Languages directly. `LanguagesSettingsPage` and its "Languages" row are deleted.
- **c. Languages.** The bar has "+ Add a language" (unchanged) and a three-dot icon at the top end in the bug's place.
- **d. The three-dot menu**, a native popup (`PopupMenuButton`), in two groups told apart by their marks, not only by a divider:
  | Group | Item | Mark | Was |
  |---|---|---|---|
  | Show (toggles) | Latin-letter readings | leading box, empty when off, ticked when on | switch |
  | | IPA pronunciations | same | switch |
  | | IPA replaces transliteration | same, disabled while IPA is off | switch |
  | | Adult content (18+) | same; switching on still asks for age (`settingsAdultConfirmTitle`) | switch |
  | | Hide what is above my level | same | switch |
  | Open (buttons) | Fact languages (line: All known languages) | trailing chevron, no box; opens `FactLanguagesSheet` | row |
  | | Sources | trailing chevron; opens Sources | row |
  | | Your decks | trailing chevron; opens Your decks | row |
  | (variant) | Learn {language} from | trailing chevron; only in the "The menu" variant, see below | row |
  A divider and two small labels (Show, Open) separate the groups. A toggle has the box in both states and no chevron; a button has a chevron and no box, so a row's kind is readable without trying it. Both groups keep the app's 1.4x text; long labels wrap in the 280 dp menu.
- **e. A card in a drill.** The flag (outlined, "Report a problem with this card") takes the bug's place in the drill header (`DrillFrame`, one place for every drill and the walkthrough).
- **f. Report sheet** (modal bottom sheet, drag handle): title "Report a problem with this card"; a monospace box showing exactly what goes with it (card id, deck id, language pair, app version); six single-choice reasons: The translation is wrong, The reading or IPA is wrong, The audio is wrong or missing, The picture or example is wrong, Offensive or inappropriate, Something else; an optional one-line note (140 characters); Cancel and Send. No screenshot, no device log, no device details.
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
**Reused**: `Report` / `ReportRequest` / `ReportSender` / `ReportOutcome`, the mail subject prefix and `mail_to_issues.py`, `contextLines`, the GitHub fallback, `AppInfo.version`, the `Feature.feedbackMail` switch, the word sheet's flag and "Report a mistake" (both become this sheet). A new `ReportKind.content` (label `Content`, public, so it becomes a public issue) with the reason as the title (`[Fluenough] Content: The translation is wrong`), the note as details, and context `Card`, `Deck`, `Languages`, `App`. The mail-to-issue Action reads the kind, so it needs one more label (`content`) and nothing else. `ReportRequest` gains `cardId`, `deckId`, `pair`; `always` prints them (replacing `Screen` and `Showing` for a content report).
**New**: one widget, `ContentReportButton` (flag) and `ContentReportSheet`, used by `DrillFrame`, the word sheet, the deck and unit pages and culture item page. Strings: the six reasons, the title, the note hint, Send, the two confirmation texts.
**Removed**: `ReportButton` from every non-content screen, `WithReportButton`, the bug in `TabHeader`, `PlaceholderPage` and the language bar, `hintReport`'s use there, and the rule that "every screen has one" (comment in `report_button.dart`; `test/languages_and_scripts_bar_test.dart` and `test/languages_page_test.dart` look for the bug icon and change to look for the dots or the flag). The device-info box and the app-log box leave the content report; they stay in `ReportPage` for the general report.
**What stays general**: `ReportPage` (Support, Bug, Feedback with the optional log) stays, reached from Settings > Support ("Send a bug report") and from the two error links that call `ReportButton.open` directly (`update_escape.dart`, `spoken_languages_picker.dart`). So a bug in the app still has a home; it is one step deeper instead of on every screen.
**What the screens lose**: the one-tap route to a general bug report from any screen, and the route name `Screen:` that came with it. A bug filed from Support carries no screen; the app log (opt in) is the replacement.

## Every screen that shows the bug icon today, and the proposal
| Screen (file) | Proposal |
|---|---|
| Language bar on Today, Decks, Progress (`language_bar.dart`) | remove |
| Tab header and placeholder pages (`page_parts.dart`) | remove |
| Languages (`languages_page.dart`) | remove; the three dots take its place |
| Drill header: recognition, reading, speaking, picture choice, rearrange, sets, grammar (`drill_frame.dart`) and walkthrough | keep as content report, flag, card id plus deck id |
| Drill page (`drill_page.dart`, the shell around a drill) | remove (the card has the flag) |
| Word sheet (`word_sheet.dart`, already a "Report" flag) | keep as content report, same sheet |
| Deck page (`deck_detail_page.dart`) and its "Report a mistake" notice (`unreviewed_notice.dart`) | keep as content report, deck-level (no card id) |
| Unit page (`unit_page.dart`) | keep as content report, deck-level |
| Topic page (`topic_page.dart`) | keep as content report, deck-level |
| Culture item page (`culture_item_page.dart`) | keep as content report, item id |
| Culture deck, timeline, recommendations, work questions (`culture_deck_page.dart`, `culture_timeline.dart`, `recommendations_page.dart`, `work_questions_page.dart`) | remove; reached through the item page, which has the flag |
| Summary after a session (`summary_page.dart`) | remove |
| Progress sub-pages: leeches, all tags, how you learn, over time (`features/stats/`) | remove |
| Reviewer mode: review, waiting, reviewed sent and not sent, review languages, daily questions, how reviewing works, offensive review (`features/review/`) | remove; reviewers have Suggest a change |
| Profiles, new profile, PIN (`features/profiles/`) | remove |
| Downloads page (`download_page.dart`) | remove |
| Update failure and spoken-languages picker error links (`update_escape.dart`, `spoken_languages_picker.dart`) | keep the link, it opens the general report |
| Settings > Support, "Send a bug report" | keep, the one general entry |

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
| Flag and dots icons (`onSurfaceVariant` on `surface`) | 8.9:1 | 10.9:1 | 3:1 (graphic) |
| Disabled "IPA replaces transliteration" | 38 percent, exempt | | exempt (disabled) |

Cues are never colour alone: checkmark against blank, the dividers, and the filled Send. Both icons are 48 dp targets with labels for screen readers ("More options", "Report a problem with this card"); the sheet's reasons are a `radiogroup`, the confirmation is a live region. Checked in Chromium (Playwright) at deviceScaleFactor 2, light and dark, Telugu, Hindustani and Bengali, 1.4x text, 360 dp, no horizontal page scroll.

## Implementation notes
- The menu is a `PopupMenuButton`, but `CheckedPopupMenuItem` shows its check only when on, so it cannot draw the empty box. Build the toggles as plain `PopupMenuItem`s (with `onTap` flipping the setting) whose child is a `Row` of `Icon(on ? Icons.check_box : Icons.check_box_outline_blank)` (primary colour when on, `onSurfaceVariant` when off), then the label, and `Semantics(checked: on, inMutuallyExclusiveGroup: false)` around it (`menuitemcheckbox` for screen readers). Because a `PopupMenuItem` closes the menu on tap, either accept that (every toggle closes the menu, as Android's own overflow menus do) or use `MenuAnchor` with `CheckboxMenuButton` for the toggles (it stays open and draws its own box in both states), and `MenuItemButton` with `trailingIcon: Icon(Icons.chevron_right)` for the buttons. The mockup shows the `MenuAnchor` look; the choice is free, the marks are the spec. The two groups are separated by a `PopupMenuDivider` (or `Divider` in a `MenuAnchor`) and two small `labelSmall` headers.\n- Settings: `AppNavigator.openSettingsPage(settingsLanguages)` points at `LanguagesPage`; delete `LanguagesSettingsPage` and its route. Its rows move into a `_LanguagesMenu` (`PopupMenuButton<_Item>`) in `LanguagesPage`'s bar. Toggle state is the same `SettingsNotifier` fields; the menu rebuilds from `state.settings`. The explanatory lines of the switches (`settingsIpaOn`, `settingsRomanisationOn` and the like) have no room in a menu; they move to the item's tooltip and screen-reader hint, not dropped.
- Everything else follows the rule "Remove `ReportButton`": the removal is mechanical (about 45 call sites) and is best done in one pull request with the new sheet.
- The same rule for other screens (owner: "We will use this same rule to simplify the app's other screens too"): not designed here, see the questions.
- Card ids stay permanent; the report carries them as they are.

## Resolved (owner, 2026-11-16)
1. **Learn {language} from** lives inside each language's own sheet. The menu has no Learn row (the page default is that variant).
2. **Reports** keep the mail hand-off for now, with no in-app endpoint. The confirmation shown by default is the mail-app wording ("Your report is ready. Your mail app has the report. Send it from there."). The "In the app" wording stays as a tweak for later.
3. **The content flag** sits in the drill header, where the bug icon was.

## Open questions for the owner (still open)
1. **Deck-level pages** (deck, unit, topic): keep the flag there, or only on a card and the word sheet? Without a card the reasons such as "The audio is wrong" are vaguer.
2. **Reviewer screens**: remove as proposed, or keep the content report there too?
3. **A general bug** now lives only in Settings > Support. Is that enough, or should the three-dot menu of Settings carry "Report a problem"?
4. **Menu lines**: the switches' one-line explanations are lost in the menu (tooltips only). Acceptable, or should IPA and Adult content keep a page?
5. **Other screens' rule.** Which screens get the same three-dot treatment next (Decks, Progress, Settings pages)?
6. Does "Your languages menu" mean the Settings row (assumed here), and not the language bar's tap menu, which stays a language picker?
