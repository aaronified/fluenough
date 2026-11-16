# Culture in Decks: diagnosis, self-check and notes

Companion to `culture-in-decks.html`. Owner feedback, 2026-11-16 (verbatim in the task): with "Show culture decks" on, the recommendations page still says "above level" and lists nothing; it should not be called "culture recommendations"; it acts on the top-bar language while sitting in Settings; the right place is the Decks screen; nothing locked, only "Learn" held back when a deck is too far above the learner. Titles, levels and counts in the page are the real data on decks-live (`decks/recommendations/{te,hi,bn}.yaml`, the culture and proverbs decks); the example verses are from those decks, for a bilingual reviewer to check.

## 1. Diagnosis: why "Show with support" still hides everything

The setting is never read by the recommendations page. Exact path:

1. `CultureSettingsPage` (`lib/features/culture/culture_settings_page.dart`) opens the list with `AppNavigator.openRecommendations(context, state.situationsLanguage)`. `situationsLanguage` (`lib/app/situations.dart`) is `shownLanguage`, the language the top bar shows. So a Settings page acts on whichever language the bar happens to show.
2. `RecommendationsPage._build` (`recommendations_page.dart`) builds the list with `recommendationList(works, course, state.levelIn(language))`. That function and `recommendationOffered` (`lib/core/decks/recommendations.dart`, `recommendation_list.dart`) call `LevelGate.allows(work.level, level)` and nothing else about level. A work above the learner is not offered; it is only counted in `hiddenAbove` and its lowest level in `unlocksAt`.
3. Neither `settings.cultureAboveSupport` nor `settings.cultureItems` is read anywhere in the recommendations page or the two pure functions. (grep: `cultureAboveSupport` is read only by `culture_deck_page.dart` and `culture_item_page.dart`.) The radio on the Settings page therefore changes the culture deck and item pages only.
4. The data explains the exact screen: all 15 Telugu works are A2 (6) or B1 (9) and no culture deck is A1, while the learner is at A1 (`levelIn`: furthest unit studied or placed past). `offered` is empty, `hiddenAbove` is 15, `unlocksAt` is A2, which prints `recHiddenAbove(15, 'A2')` ("15 more works are above your level. They unlock at A2.") and `recNothingAtLevel` ("Nothing yet at this level."). Hindustani has 16 works, 11 of them B2 or C1, which no path reaches (paths end at B1), so they would say "unlocks at B2" and never open.
5. Fix: the level must stop being a filter on this page. Make `recommendationList` keep every work and return its gate (`ok`, `reach`, `far`) instead of dropping it; remove `hiddenAbove`, `unlocksAt` and the two strings above; apply the gate where it matters, which is starting FSRS (below). The book and script rules in `recommendationOffered` (books only for a learner who learns scripts; a script-only learner sees only books) are also hiding rules: turn them into a tag and a note ("Telugu script") so nothing is hidden. The language comes from the page showing it in the Decks screen, for the selected language, not from Settings.

## 2. What changes

Decks screen (screens A): the culture decks and the works of the selected language in one searchable place. Chips are the kinds the data has, in the order of `RecommendationMedium`, and only those present: Telugu has Books 4, Films 9, Plays 1, Songs 1; Hindustani Books 4, Films 9, Series 2, Songs 1; Bengali Books 6, Comics 2, Films 10, Podcasts 1, Songs 1; plus "Decks" for the culture and proverbs decks. A search field filters both (title, reading, deck name, kind, year; accent-insensitive, so "maha" finds Mahanati). Rows carry the level; a deck row shows "With support" or "Learn at A2" when it is not at the learner's level. Nothing is locked, everything opens. Two entries are offered as a tweak: A, a Path and Culture switch under the search; B, a Culture section after the path, filling the "Beyond the course" placeholder (`BeyondTheCourse`, #215, still "Feature incoming").

The work page (screen C, last phone) opens and reads at any level. "I've completed this" is always allowed (someone may have watched the film already); a too-far work simply keeps its questions out of lessons until the learner is in reach, and says so in one line. Today `worksDecks` joins the questions of completed works to drills; that join gets the same gate.

### The Learn gate (deck page, three states)

The code has one level rule today: `LevelGate.allows(item, learner)` is true when the learner is at or above the item, and `isAbove` is its opposite. A deck above the learner already cannot be practised: `culture_item_page.dart` shows `AboveLevelNotice` ("Will not count toward your progress or be scheduled for review") instead of "Practise this item". There is no "how far above" threshold. The design adds one derived from `Level.index`:

| State | Rule | Learn |
|---|---|---|
| Learnable | deck level at or below the learner (`LevelGate.allows`) | enabled; "counts" or "bonus" line from the setting |
| Within reach | deck level exactly one above (`level.index == learner.index + 1`, new) | enabled as "Learn with support": words glossed, not counted toward progress |
| Too far | two or more above, or B2 and up while paths end at B1 | disabled, lock icon, one line: "Learn unlocks at A2. This deck is B1." (the needed level is the deck's level minus one) |
| Culture off | the Culture switch is off | disabled, one line: "Culture is off for Telugu. Turn it on in Telugu details." |

The reading, quoted text, creator and legacy block show in all states. Open question 1 asks whether "within reach" should exist or Learn should open only at the deck's own level.

### Settings > Culture is removed; the options move into the language details

`LanguageSkillsSheet` (`lib/features/languages/language_skills_sheet.dart`, the screen that chooses which skills to learn) gets one `Culture` row after the Learning block (screens B). Collapsed it is a single switch row. Expanded in place it holds: "Items above my level" as a two-way segmented control (Hide, Show with support), "Count toward path progress" (switch), "Show creator and legacy" (switch), and a one-line "Applies to all your languages." Meaning of Hide and Show with support after this change: they control only the path and Today (whether an item one level above is woven in with a lock mark); the Decks screen ignores them.

### "How many" is removed

Today `culturePerUnit` (1 to 3, default 1, `weave.dart`: `defaultCulturePerUnit`, `maxCulturePerUnit`) is read only by `wovenCultureOf` in `lib/app/culture.dart`, which passes it to `weaveCulture`; the unit cards and Today follow from that. Owner: show however many the course has. Proposal: the path computes the number itself, per level: `ceil(items at that level / units of that level)`, minimum 1, so every item at or below the learner's level appears and none piles into the first unit. `weaveCulture` keeps its `perUnit` parameter (pure, tested); `wovenCultureOf` passes the computed value and its cache key loses `per`.

## 3. Removed, moved, strings

Removed: `CultureSettingsPage`, `AppRoutes.settingsCulture` and its route entry, the Culture row in `settings_page.dart` (summary `cultureItems`), the "How many" setting, the name "Culture recommendations".

Strings to remove (`lib/l10n/app_en.arb`): `settingsRowCulture`, `settingsSumCultureOn`, `settingsSumCultureOff`, `cultureSettingHowMany`, `cultureSettingPerUnit`, `cultureSettingPerUnitValue`, `cultureSettingOpenDeck`, `cultureSettingNote`, `recHiddenAbove`, `recNothingAtLevel`, `cultureNotShownTitle`, `cultureNotShownBody` (an item is never "not shown" now), `recScriptOnlyTitle` and `recScriptOnlyBody` (become a tag), and `recTitle` ("Culture recommendations"). Keep and move (reworded for the sheet): `cultureSettingShow`, `...ShowOn`, `...ShowOff`, `cultureSettingAboveHeading`, `cultureSettingAboveHide`, `cultureSettingAboveSupport`, `cultureSettingCounts`, `...CountsOn/Off`, `cultureSettingCreators`, `...CreatorsOn/Off`; `cultureSettingAboveHideBody` and `...SupportBody` become the one line under the control. Keep `recMediumBook` to `recMediumComic` (singular, for tags and the work page).

New strings (proposed keys): `languagesCulture` ("Culture"), `languagesCultureOn`, `languagesCultureOff`, `languagesCultureAll` ("Applies to all your languages."), `decksTabPath`, `decksTabCulture`, `decksCultureSearchHint` ("Search culture in {language}"), `decksCultureDecks` ("Culture decks"), `recKindBooks`, `recKindFilms`, `recKindSeries`, `recKindSongs`, `recKindPlays`, `recKindPodcasts`, `recKindComics`, `learnLockedLevel` ("Learn unlocks at {level}. This deck is {deck}."), `learnLockedCultureOff`, `learnWithSupport`, `learnWithSupportNote`, `recQuestionsHeld` ("Its questions join your lessons at {level}."), `cultureSearchNothing`.

## 4. Data and model

Keep: `culture_items`, `culture_above_support`, `culture_counts`, `culture_creators` (same keys, same meaning, global, so no migration; backups keep restoring). Delete: `culture_per_unit` (stop writing it; the restore code ignores an old value instead of failing; `maxCulturePerUnit` and `culturePerUnit` go). Code: `RecommendationList.hiddenAbove` and `unlocksAt` go; a work gets a gate value; `recommendationOffered` loses its level test.

## 5. Every screen that reads the culture settings

| Screen or place | Reads | After |
|---|---|---|
| Settings list row (`settings_page.dart`) | `cultureItems` | row removed |
| Culture settings page | all five | removed |
| Language details sheet | none | new Culture group: `cultureItems`, `cultureAboveSupport`, `cultureCounts`, `cultureCreators` |
| Path unit culture cards (`culture_cards.dart`) | `cultureItems`, `cultureCounts`, woven via `culturePerUnit` | `culturePerUnit` replaced by the computed number |
| Today culture card (`nextCultureItem`) | `cultureItems` | unchanged |
| `wovenCultureOf` (`culture.dart`) | `culturePerUnit` | computed number |
| Reviews and sessions (`AppState.drillDecks`, `_cultureOff`) | `cultureItems` | unchanged; adds the level gate for Learn |
| Culture item page | `cultureAboveSupport`, `cultureCreators`, `cultureItems`, `cultureCounts` | never hides; Learn gate; same counts and creator reads |
| Culture deck page | `cultureAboveSupport`, `cultureCreators` | folds into the Decks screen's Culture view |
| Recommendations page | none (the bug) | Decks screen; gate per work, no filtering |
| Search (`item_search.dart`) | `hideAboveLevel` (a different setting) | see open question 4 |
| Settings backup (`settings.dart` export and import) | all five keys | four keys |

## Design choices (tweaks in the page)

Theme; language (Telugu, Hindustani, Bengali); learner level (A1, A2, B1) which drives the marks in the Decks lists; Culture items on or off (also the switch in the language details); Decks entry A or B; deck page state (all, learnable, within reach, too far); highlight of what changed (new, changed, removed). The deck page phones show fixed scenarios: Learnable is a proverbs deck at A2 for an A2 learner; Within reach and Too far are the same B1 culture deck for an A2 and an A1 learner. One empty state: a search with no match (Telugu "zzq"), which keeps the chips and offers "Clear search".

## Open questions for the owner

1. Should a deck one level above the learner be learnable with support, as shown, or should Learn open only at the deck's own level?
2. The Culture options in the language details apply to all languages, as the settings do today. Should each language keep its own?
3. Decks entry: A, a Path and Culture switch under the search, or B, a Culture section after the path?
4. Settings > Languages has "Hide what is above my level", which makes search leave out above-level decks, topics and units. Should it go too, so search always shows everything, view-only?
5. Hindustani works are titled in Latin script in the data (Telugu and Bengali are in their scripts). Should the Devanagari titles be added to the file?

## Contrast self-check (WCAG 2.1)

Computed from the app palette used in the page (same tokens as `culture-in-course.html`).

| Pair | Light | Dark | Needed |
|---|---|---|---|
| Body text on the screen | 16.3:1 | 14.3:1 | 4.5:1 |
| Muted text on the card | 8.4:1 | 10.1:1 | 4.5:1 |
| Muted text on the high container | 7.6:1 | 8.5:1 | 4.5:1 |
| Chip text on `secondaryContainer` | 7.2:1 | 7.2:1 | 4.5:1 |
| Filled button text on `primary` | 6.5:1 | 7.7:1 | 4.5:1 |
| "With support" tag (`primary`) on the screen | 6.2:1 | 10.9:1 | 4.5:1 |
| "Learn at A2" tag (amber) on the screen | 5.7:1 | 8.5:1 | 4.5:1 |
| Reason line under a disabled Learn (`onSurface`) on the card | 15.5:1 | 13.3:1 | 4.5:1 |

The disabled Learn button itself is exempt from the contrast rule (inactive control), so its reason is a separate full-contrast line, not text inside the button. No cue is colour alone: the lock icon and the words "Learn at A2", "With support" and "Completed" carry the meaning. Checked in Chromium (Playwright) in light and dark, Telugu, Hindustani and Bengali, 360 dp phones at 1.4x text, no horizontal page scroll and no script errors.
