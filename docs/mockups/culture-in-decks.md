# Culture in Decks: diagnosis, self-check and notes

> Update 2026-11-16 (owner): the Learn gate described in the first version is dropped; see "No Learn gate" below and `learn-flow.md`. The page `culture-in-decks.html` still draws the locked Learn states and is to be read with this change (its "Too far" phone becomes "Far above": Learn enabled plus the honest hint).

Companion to `culture-in-decks.html`. Owner feedback, 2026-11-16, and the owner's answers to the first version (see Resolved): with "Show culture decks" on, the recommendations page still says "above level" and lists nothing; it should not be called "culture recommendations"; it acts on the top-bar language while sitting in Settings; the right place is the Decks screen; nothing locked, and (owner, later the same day) nothing held back either: everything is learnable under the new definition of "learned" in `learn-flow.md`. Titles, levels and counts in the page are the real data on decks-live (`decks/recommendations/{te,hi,bn}.yaml`, the culture and proverbs decks); the example verses are from those decks, for a bilingual reviewer to check.

## 1. Diagnosis: why "Show with support" still hides everything

The setting is never read by the recommendations page. Exact path:

1. `CultureSettingsPage` (`lib/features/culture/culture_settings_page.dart`) opens the list with `AppNavigator.openRecommendations(context, state.situationsLanguage)`. `situationsLanguage` (`lib/app/situations.dart`) is `shownLanguage`, the language the top bar shows. So a Settings page acts on whichever language the bar happens to show.
2. `RecommendationsPage._build` (`recommendations_page.dart`) builds the list with `recommendationList(works, course, state.levelIn(language))`. That function and `recommendationOffered` (`lib/core/decks/recommendations.dart`, `recommendation_list.dart`) call `LevelGate.allows(work.level, level)` and nothing else about level. A work above the learner is not offered; it is only counted in `hiddenAbove` and its lowest level in `unlocksAt`.
3. Neither `settings.cultureAboveSupport` nor `settings.cultureItems` is read anywhere in the recommendations page or the two pure functions. (grep: `cultureAboveSupport` is read only by `culture_deck_page.dart` and `culture_item_page.dart`.) The radio on the Settings page therefore changes the culture deck and item pages only.
4. The data explains the exact screen: all 15 Telugu works are A2 (6) or B1 (9) and no culture deck is A1, while the learner is at A1 (`levelIn`: furthest unit studied or placed past). `offered` is empty, `hiddenAbove` is 15, `unlocksAt` is A2, which prints `recHiddenAbove(15, 'A2')` ("15 more works are above your level. They unlock at A2.") and `recNothingAtLevel` ("Nothing yet at this level."). Hindustani has 16 works, 11 of them B2 or C1, which no path reaches (paths end at B1), so they would say "unlocks at B2" and never open.
5. Fix: the level must stop being a filter on this page. Make `recommendationList` keep every work and keep every work with its level mark instead of dropping it; remove `hiddenAbove`, `unlocksAt` and the two strings above; a work above the learner is marked with its level only; the safety is the definition of "learned" (`learn-flow.md`), which keeps an item out of FSRS until it is passed twice. The book and script rules in `recommendationOffered` (books only for a learner who learns scripts; a script-only learner sees only books) are also hiding rules: turn them into a tag and a note ("Telugu script") so nothing is hidden. The language comes from the page showing it in the Decks screen, for the selected language, not from Settings.

## 2. What changes (as the owner decided, 2026-11-16)

**Decks screen (screens A).** The top card of the Decks screen (the course card: course, progress bar, hours left and spent, update button; `CourseCard` in `course_card.dart`) gets a **Culture** button. It is a switch of what the screen lists: tapped, the culture list replaces the deck path and the button reads **Deck path** (with a back arrow); tapped again, the path returns. There is no second search and no tab bar: the one existing Decks search (`decksSearchHintIn`, "Search {language}") searches everything, whichever list shows: while it has text, the screen shows the usual deck, unit and card results and, after them, the culture decks and works that match, grouped by kind as in the culture list; clearing it returns to the current view (owner, 2026-11-16). A kind:, status: or theme: chip narrows the deck part and leaves culture out. The culture list is one list with plain section headers: **Culture decks**, then only the kinds the data has, with their real labels, each with a count. Telugu: Culture decks 7, Books 4, Films 9, Plays 1, Songs 1; Hindustani: Culture decks 6, Books 4, Films 9, Series 2, Songs 1; Bengali: Culture decks 7, Books 6, Comics 2, Films 10, Podcasts 1, Songs 1. Search matches title, reading, deck name, kind and year, ignoring accents ("maha" finds Mahanati); a section with no match disappears, and no match anywhere shows the usual "Nothing found" empty state once. Nothing is hidden or locked: every row opens, and every row can be learnt; a row above the learner shows its level and the honest hint, never a lock. The earlier designs (a Path and Culture switch, a section after the path, a culture view with its own search and tab bar) are dropped; the "Beyond the course" placeholder (`BeyondTheCourse`, #215) is not used for this.

**Implementation notes.** `_DecksPageState` (`decks_page.dart`) holds one mode, `path` or `culture` (reset to `path` when the language in the bar changes; not saved). `CourseCard` takes the mode and a callback for the button. In culture mode the body builds the culture list from the shown language's culture and proverbs decks (`catalogWithAboveLevel`, so decks above the level are in it) and its recommendations (`recommendationCourseOf`, no level filter), and runs the same search the Decks screen runs (`runSearch`, `ItemSearchState`) over them; the `TypedSearchResults` tabs are not used in this mode. The work and deck rows reuse `ResultRow`, `LevelTag` and the culture item and deck pages.

**The work page (screens C, last phone).** Opens and reads at any level. "I've completed this" is always allowed (someone may have watched the film already); its questions join lessons like any other item (the new definition of "learned" keeps them out of FSRS until passed twice), with one honest line that it is above the learner. `worksDecks` needs no gate.

### No Learn gate: everything is learnable (owner, 2026-11-16, replaces the Learn gate)

Resolved (owner): nothing is gated by level any more. Every deck of every kind, culture included, can be opened, read and learnt at any level; Learn is never disabled for being above the learner, and there is no "Unlocks at B1. You are at A1." line, no lock icon and no `deckLearnable` function. The safety is the new definition of "learned" in `learn-flow.md`: an item is learned only when it is shown and then answered correctly in two different question types in one sitting; an item not passed twice never enters FSRS, so a far-too-hard deck cannot pester the learner. The deck page of a deck well above the learner keeps its Learn button enabled and shows one honest line ("This is well above your level: you may need a few tries"), and its progress counts only learned items.

The one rule, for every deck kind: **everything is learnable**. The only remaining reason for a disabled Learn is the culture-only one below (the language's Culture switch is off), because it is about the switch, not the level.

| State | Learn |
|---|---|
| Any level | enabled; for culture, the "counts" or "bonus" line from the language's setting; above the learner, the one-line honest hint |
| Culture off for this language | disabled, one line: "Culture is off for Telugu. Turn it on in Telugu details." |

The reading, quoted text, creator and legacy block show in every state. The old "Show with support" mode is gone for good (no glosses mode, no lock mark): an item above the learner is simply learnable. Where the Learn gate was to be added (`AppState.deckLearnable`, `_ActionBar.learnEnabled`, the culture item page's Practise, `topic_page.dart`'s `startable`), nothing is added: the existing `showAboveLevelSheet` and the "Practise" replacement by a notice on above-level items are removed in the build of `learn-flow.md`.

### What "Items above my level" now decides (language details)

Plainly: it decides whether culture items above the learner's level appear in the **path and on Today** as view-only previews, or are left out of them. **Hide** (the default): the path and Today show only items the learner can learn now. **Show** (was "Show with support"; the string is renamed): the path and Today also list items above the level, marked "Preview · unlocks at B1", which open to read but have no Learn. **Reviews schedule only learned items (see `learn-flow.md`), whichever is chosen.** The Decks culture view and search ignore this option: they always show everything. In code, `weaveCulture` already puts above-level items in `WovenCulture.above` and never weaves them; "Show" lists `above` after the woven items of a unit's own level, and `cultureAboveSupport` is renamed `cultureShowAbove`.

### Settings > Culture is removed; the options live in each language's details

`LanguageSkillsSheet` (`lib/features/languages/language_skills_sheet.dart`, the screen where the learner chooses which skills to learn in a language) gets one `Culture` row after the Learning block (screens B). Collapsed it is a single switch row. Expanded in place it holds "Items above my level" (a two-way Hide / Show control with one explaining line), "Count toward path progress" (switch) and "Show creator and legacy" (switch). The group belongs to that language: there is no "applies to all languages" line.

**Per-language settings and migration.** The four options become per-language, stored like `daily_minutes` is today: one JSON map keyed by language code, `culture_by_language`, with `{items, show_above, counts, creators}` per language. Migration, once at first start after the update (and when an old backup with the global keys is restored): copy each global value (`culture_items`, `culture_above_support`, `culture_counts`, `culture_creators`) into the entry of every language the profile has, then stop reading and writing the global keys. A language added later starts from the defaults (items on, Hide, bonus, creators shown). Accessors become `cultureItemsIn(code)` and so on, and every reader below takes the language it is showing.

### "How many" is removed

Today `culturePerUnit` (1 to 3, default 1, `weave.dart`: `defaultCulturePerUnit`, `maxCulturePerUnit`) is read only by `wovenCultureOf` in `lib/app/culture.dart`, which passes it to `weaveCulture`; the unit cards and Today follow from that. Owner: show however many the course has. The path computes the number itself, per level: `ceil(items at that level / units of that level)`, minimum 1, so every item at or below the learner's level appears and none piles into the first unit. `weaveCulture` keeps its `perUnit` parameter (pure, tested); `wovenCultureOf` passes the computed value and its cache key loses `per`.

### "Hide what is above my level" is removed

Owner: remove it; search always shows everything, view-only when too far. On current main it is a toggle on Settings > Languages (`lib/features/settings/languages_page.dart`, strings `settingsHideAbove`, `settingsHideAboveOn`, `settingsHideAboveOff`); no other menu on main has it (if the Languages three-dot menu build lands one, delete it there too). Delete: that tile; the setting `hideAboveLevel` and its key `hide_above_level` (stop writing it, ignore it on restore); the filtering in `lib/app/item_search.dart` (line 258), `lib/features/topics/topic_page.dart` (703) and `lib/features/topics/unit_topics.dart` (42); the "N results above your level are hidden" row in `search_tabs.dart` (`_HiddenAbove`, `searchAboveHidden`, `searchShowAbove`, `searchHideAboveHint`). Search results above the level keep their level mark and open the preview sheet or page, never a lesson.

### Search tokens and tabs for culture (owner, 2026-11-16)

Culture uses the search's existing parts, with nothing parallel. **Tokens.** `kind:` takes the culture values `book`, `film`, `series`, `song`, `play`, `podcast`, `comic` and `proverb` beside the deck kinds (they do not overlap); `status:` takes `done` (the work is marked "I've completed this") and `todo` for works, beside the card statuses; `creator:<text>` is a case- and accent-insensitive part of a creator's name; `year:<n>` or `year:<a>-<b>` matches a work's year (BCE negative). They are the same chips, menu and parser as `kind:`, `status:` and `theme:` (`SearchToken`, `parseSearch`), and the token menu lists `creator:` and `year:` too. A token narrows the part it applies to: a culture token (a culture kind, `creator:`, `year:`, `done`, `todo`) lists culture only, a deck token (a deck kind, a card status, `theme:`) lists decks only, so the other part leaves the results. Decks have no year and no completion, so `year:` and `done`/`todo` leave them out. A creator with several words in a name is matched by one word. **Tabs.** The strip is the one the deck results use (`ResultTabStrip`, from `resultTabs`' widget). In the combined search the culture kinds (Culture decks, Books, Films ...) follow the deck tabs in the same strip, each with its count, and a kind with no match has no tab. The culture list itself has its own strip of the same widget: All first, which shows every kind under its header, then a tab for each kind the data has. Culture kinds stay in the app, not in the sections file on decks-live.

## 3. Removed, moved, strings

Removed: `CultureSettingsPage`, `AppRoutes.settingsCulture` and its route entry, the Culture row in `settings_page.dart`, the "How many" setting, the name "Culture recommendations", the "Hide what is above my level" setting.

Strings to remove (`lib/l10n/app_en.arb`): `settingsRowCulture`, `settingsSumCultureOn`, `settingsSumCultureOff`, `cultureSettingHowMany`, `cultureSettingPerUnit`, `cultureSettingPerUnitValue`, `cultureSettingOpenDeck`, `cultureSettingNote`, `cultureSettingAboveSupport`, `cultureSettingAboveSupportBody`, `cultureSettingAboveHideBody`, `recHiddenAbove`, `recNothingAtLevel`, `cultureNotShownTitle`, `cultureNotShownBody`, `cultureAboveTitle`, `cultureAboveBody` (removed with the Learn gate), `recScriptOnlyTitle`, `recScriptOnlyBody` (become a tag), `recTitle`, `settingsHideAbove`, `settingsHideAboveOn`, `settingsHideAboveOff`, `searchAboveHidden`, `searchShowAbove`, `searchHideAboveHint`. Keep and move to the language details, reworded: `cultureSettingShow` (`...On`, `...Off`), `cultureSettingAboveHeading`, `cultureSettingAboveHide`, `cultureSettingCounts` (`...On`, `...Off`), `cultureSettingCreators` (`...On`, `...Off`). Keep `recMediumBook` to `recMediumComic` (singular, for tags and the work page) and `cultureUnlocksAt`.

New strings (proposed keys): `languagesCulture`, `languagesCultureOn`, `languagesCultureOff`, `languagesCultureAboveShow` ("Show"), `languagesCultureAboveHideLine`, `languagesCultureAboveShowLine`, `decksCultureButton` ("Culture", the button in path mode), `decksPathButton` ("Deck path", the button in culture mode), `decksCultureDecksHeader` ("Culture decks"), `recKindBooks`, `recKindFilms`, `recKindSeries`, `recKindSongs`, `recKindPlays`, `recKindPodcasts`, `recKindComics` (the section headers; counts are shown next to them), `decksCultureSearchNothing` is not needed: the existing `decksEmptySearch` is reused, `learnLockedCultureOff`, `learnAboveHint` ("This is well above your level: you may need a few tries."), `culturePreviewTag` ("Preview · unlocks at {level}"), `culturePreviewTag` stays only for the path and Today preview setting. (`recQuestionsHeld` is not needed.)

## 4. Data and model

Per-language (new map `culture_by_language`): items, show-above, counts, creators. Deleted: `culture_per_unit`, `hide_above_level`, and, after the migration above, the four global culture keys. `maxCulturePerUnit`, `culturePerUnit` and `hideAboveLevel` go. `RecommendationList.hiddenAbove` and `unlocksAt` go; a work carries its gate; `recommendationOffered` loses its level test. Backups: an old file with global keys migrates as above; a new file carries the map.

**Hindustani titles (data task, not part of this app build).** The Hindustani works file (`decks/recommendations/hi.yaml` on decks-live) has Latin-script titles only; Telugu and Bengali are in their scripts. A task for the Hindustani session: add the Devanagari titles (and readings where the file has them) to the file. The mockup shows the titles as the data has them today.

## 5. Every screen that reads the culture settings (per language after this change)

| Screen or place | Reads | After |
|---|---|---|
| Settings list row (`settings_page.dart`) | `cultureItems` | row removed |
| Culture settings page | all five | removed |
| Language details sheet | none | new Culture group, writes the language's own `items`, `show_above`, `counts`, `creators` |
| Path unit culture cards (`culture_cards.dart`) | `cultureItems`, `cultureCounts`, items via `culturePerUnit` | the language's `items`, `counts`; computed number per unit; Show adds preview items |
| Today culture card (`nextCultureItem`) | `cultureItems` | the shown language's `items` and `show_above` (previews only) |
| `wovenCultureOf` (`culture.dart`) | `culturePerUnit` | computed number; `show_above` |
| Reviews and sessions (`AppState.drillDecks`, `_cultureOff`) | `cultureItems` | the language's `items`; only learned items are scheduled |
| Culture item page | `cultureAboveSupport`, `cultureCreators`, `cultureItems`, `cultureCounts` | never hides; no level gate; the language's `creators`, `counts` |
| Culture deck page | `cultureAboveSupport`, `cultureCreators` | replaced by the culture list on the Decks screen |
| Recommendations page | none (the bug) | replaced by the culture list on the Decks screen; a level mark per work, no filtering, no gate |
| Decks screen (`decks_page.dart`, `course_card.dart`) | none | new path or culture mode behind the Culture button; the one search covers both lists: deck results, then matching culture |
| Search (`item_search.dart`), topics, unit topics | `hideAboveLevel` | setting removed; always shown |
| Settings backup (`settings.dart` export and import) | `hide_above_level` and the five culture keys | `culture_by_language`; old keys migrate |

## Design choices (tweaks in the page)

Theme; language (Telugu, Hindustani, Bengali); learner level (A1, A2, B1), which drives the marks in the lists and the top card; Culture items on or off (also the switch in the language details); deck page state (all, learnable, far above); highlight of what changed. The deck page phones show fixed scenarios: Learnable is a proverbs deck at A2 for an A2 learner; Far above is a B1 culture deck for an A1 learner, with the honest hint and Learn enabled. The path-unit phone follows the Hide / Show control. One empty state: a search with no match (Telugu "zzq").

## Resolved (owner, 2026-11-16)

1. No Learn gate (replaces the earlier gate): everything is learnable at any level; the safety is the definition of "learned" in `learn-flow.md` (show, then two different question types correct in one sitting). No "within reach" tier, no "With support" tag or strings, no lock.
2. Scope: each language keeps its own culture options, in its own details screen; the global values are copied into every language's own setting.
3. Entry: a Culture button on the Decks screen's top card is a switch: it shows the culture list instead of the deck path, and reads Deck path to go back. The one existing Decks search covers everything, whichever list shows (combined results); no separate search and no tab bar. The culture list has plain section headers (Culture decks, then the kinds that exist in the data), nothing hidden, locked or gated.
4. "Hide what is above my level" is removed from the menu, the setting and the search filtering; search always shows everything, view-only when too far.
5. Hindustani works in Latin script: the Devanagari titles are added to the data file as a task for the Hindustani session.

No open questions are left.

## Contrast self-check (WCAG 2.1)

Computed from the app palette used in the page (same tokens as `culture-in-course.html`).

| Pair | Light | Dark | Needed |
|---|---|---|---|
| Body text on the screen | 16.3:1 | 14.3:1 | 4.5:1 |
| Muted text on the card | 8.4:1 | 10.1:1 | 4.5:1 |
| Muted text on the high container | 7.6:1 | 8.5:1 | 4.5:1 |
| Chip text on `secondaryContainer` | 7.2:1 | 7.2:1 | 4.5:1 |
| Filled button text on `primary` | 6.5:1 | 7.7:1 | 4.5:1 |
| Hint line under Learn (`onSurface`) on the card | 15.5:1 | 13.3:1 | 4.5:1 |

The honest hint under Learn is a separate full-contrast line, not text inside the button. No cue is colour alone: the words "Preview" and "Completed" carry the meaning. Checked in Chromium (Playwright) in light and dark, Telugu, Hindustani and Bengali, 360 dp phones at 1.4x text, no horizontal page scroll and no script errors.
