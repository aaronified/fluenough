# Backlog triage, 2026-11-13

Source of truth: this wiki page.

Owner request (2026-11-13): "add the bugfix type issues. and all small issues as reported. we need to trim down the issue backlog as well". This page triages every open issue (208 on 2026-11-13, pull requests excluded). It is an audit: no issue was closed, edited, labelled or commented on. Evidence is from `origin/main` at `6b921c16` (code, CHANGELOG, wiki) and `origin/decks-live` (`decks/index.json`).

Rules applied: deck work is held until the code is done (CLAUDE.md, 2026-11-13); #850 and #1012 are deferred by the owner (2026-11-13); private decks (#1017), the deck-kinds scaffold (#1132-#1146 range) and on-device speech (#1004, #1158) are already queued. Sizes: XS under 30 minutes, S about an hour, M a few hours, L more than a day. "Device" means a physical phone or browser is needed to finish.

## Summary

| Bucket | Meaning | Count |
|---|---|---|
| A | Bug (labelled `bug`, or a clear defect) | 3 |
| B | Small code issue (about an hour to a few hours, one area) | 9 |
| C | Medium or large code issue | 39 |
| D | Deck or content work (held) | 75 |
| E | Plan, epic or umbrella (not directly buildable) | 29 |
| F | Blocked or waiting on the owner | 31 |
| G | Close candidates (done, obsolete, superseded or duplicate) | 22 |
| | Total | 208 |

Close candidates with clear evidence: 11 strong (#924, #1140, #1137, #1142, #1134, #1101, #107, #91, #95, #94, #96) and 11 probable (owner to confirm).

Bugs: only four open issues are defects (three in A, one in G). #850 and #1012 are labelled `bug` but deferred by the owner; #1101 is labelled `bug` and is obsolete (listed in G). That leaves #1132 as the one bug to build now. The real backlog of small items is B.

## A. Bugs

Not for the build order unless marked. Sorted bugs first.

| Order | Issue | Title | Size | Area | Mockup or decision? | Device? | Notes |
|---|---|---|---|---|---|---|---|
| 1 | #1132 | Placement: make the sentence fill-in (F28) pass the audit so it can be asked | M | lib/core/placement (item_generators, item_audit); regenerate verdict with `dart run tool/placement_audit.dart` | No / no (bound must not be loosened) | No | Defect: F28 sentence fill-in fails the audit in es and hi, so it is never asked. Choose distractors so no solver passes 0.32. May prove impossible for hi (n=66); then the owner decides whether F28 stays off. |
| - | #850 | App is sluggish: about 1 s before every interaction responds | M | whole app (ADR-0047/0048/0051) | Owner verdict needed | Yes (profile build on the owner's Samsung) | DEFERRED by owner 2026-11-13 ("not important right now"). All sub-issues #851-#857, #875 already closed; only the on-phone measurement is missing. Not in the build order. |
| - | #1012 | Check the web app (PWA): installability, offline, and core flows | M | web build (PWA) | No / no | Yes (real browsers, microphone) | DEFERRED by owner 2026-11-13. Findings already built (#1018, #1019, #1038, #1039); what is left is a check on Safari, Firefox and a real mic. Not in the build order. |

## B. Small code issues

Ordered by suggested build order: smallest first, batched by area so one PR can take several items. Batch 1 is tools, docs and CI (one PR, or two); batch 2 is the deck tools (one PR); batch 3 is UI (one PR each, or #681 with #1145); batch 4 is speech.

| Order | Batch | Issue | Title | Size | Area | Mockup or decision? | Device? | Notes |
|---|---|---|---|---|---|---|---|---|
| 2 | 1 tools/CI | #425 | Remove the analyzer bound once build_runner supports 14.5.0 | XS | pubspec.yaml (analyzer bound, lines 61-64) | No / no | No | Try removing `analyzer: ">=14.0.0 <14.5.0"`. build_runner 2.17.1 was published 2026-10-14 (newer than the 2.16.1 the issue names); analyzer is now 14.7.0. CI is the test: if build_runner still fails, leave the bound and close nothing. |
| 3 | 1 docs | #30 | Script decks: document their conventions; positional forms for Arabic-script languages | XS | wiki/Deck-Format.md (docs only, straight to main) | No / no | No | Only the docs part is left: a section on building script decks. Positional forms for Arabic-script languages come with Urdu work, so write that as "not yet". |
| 4 | 2 deck tools | #315 | In-app readings: the three no-hint fixes in tools/transcribe.py | S | tools/transcribe.py (no-hint path), tools/test_transcribe.py | No / no (fixes are listed in wiki/Plan-In-App-Readings.md) | No | Three no-hint fixes in the Python tool only; the Dart port is #316 (separate, C). |
| 5 | 2 deck tools/CI | #92 | Sample deck pack: one example of every deck kind, as a download | S | CI release workflow, test/fixtures/sample-decks, docs | Small: is the existing CI sample deck (es, te) enough, or a pack with one of every kind? | No | The sample deck exists for CI (tools/validate_sample_decks.py, tools/check_sample_contract.py). Missing: a downloadable zip attached to releases and linked from Your decks and DECK-FORMAT. Labelled good first issue. |
| 6 | 2 deck tools | #348 | Word-order tiles: extra tiles per card | M | tools/validate_decks.py, lib/core deck parser, drill_session (tiles) | No / no (plan accepted: wiki/Plan-Word-Order-Tiles.md) | No | Format, validator and checking of extra tiles per card. Content (#349, 1,098 cards) is D. Deck format change: ship the reader a release before decks use it. |
| 7 | 3 UI | #681 | Language bar: a dot on languages with something to do, and a full-height IPA glyph | S | lib/ui/widgets/language_bar.dart, language_glyph.dart | No (wheel mockup approved) / no | No | direct-code. Nothing in lib/ draws a "has cards to do" dot (grep confirmed 2026-11-13); blocker #703 closed. Dot when due or new cards; IPA glyph at full height. Check light/dark at 1.0x and 1.4x. |
| 8 | 3 UI | #1145 | Situations screen: the learner chooses which situations to show; new situations teach only widely used words and phrases | M | lib/features/situations, lib/features/today/situations_card.dart, settings storage per language | No: owner 2026-11-13 "no mockup needed" (pencil icon top right, popup grid of tiles, top 6 shown, faded when unselected, drag to reorder) / no | No | direct-code, every decision made. Default selection = current first 6; stored per language. The "new situations teach only widely used phrases" half is a deck rule (D) plus a wiki/Deck-Format.md note (docs). |
| 9 | 3 UI | #836 | An IPA keyboard for typed answers in the IPA course | M | lib/ui/widgets/answer_field.dart (ScriptKeyboard), new ipa_keyboard.dart modelled on braille_keyboard.dart | Yes, small: grid layout (tabs by kind or one scrolling grid); owner said "planned for next week" | No | ScriptKeyboard knows only `braille`; an IPA answer opens the phone keyboard, which cannot type IPA. Read-only field, symbols from the IPA course only. Widget test for the grid. |
| 10 | 4 speech | #233 | Plan: say when speech works only online | M | lib/app/app_state.dart (SpeechStatus.onlineOnly exists), lib/features/today, voices_page.dart | No / no (decisions in wiki/Plan-Speech-Offline-Alert.md) | No | Voices page already says "only online" and has the switch. Not built: the one-time alert per language and the line on Today with a button to the right row. Dart-only; fake speech engine in tests. |

Overall build order across A and B (bugs first): #1132, #425, #30, #315, #92, #348, #681, #1145, #836, #233. The order column above numbers this list from 1.

## C. Medium and large code issues

| Issue | Title | Size | Area | Notes |
|---|---|---|---|---|
| #22 | Add a deck from a link | M | lib/app/deck_import.dart, import_page.dart (Feature.importUrl incoming) | Add a deck from a link. File import shipped (0.3.0); link import still disabled. Overlaps the private-decks work (#1017 stage 2): decide the order first. |
| #31 | Phonemic contrasts: the sounds of the language learnt that the learner's languages lack | L | new lib/features/drill/minimal_pair_drill.dart, per-contrast stats | Phonemic-contrast drill. `pair:` partner already offered in Hear (PR #432); the drill and statistics are not built. Needs a TTS check on a device first and an ADR. |
| #93 | Grammar exercises: match rows and sort into groups | M | lib/features/drill (match_drill.dart exists for pairs) | Grammar exercises: match table rows to slots, sort words into groups. Neither exists (no sort drill in lib/features/drill). |
| #108 | Home-screen widget: cards due and the streak | L | Android native (AppWidget), needs a plugin or Kotlin | Home-screen widget, due count and streak. Nothing in lib, pubspec or android. Needs a device. |
| #204 | Profiles and a PIN lock | L | lib/app/profile.dart, lib/features/profiles (UI exists; Feature.profiles, pinLock incoming) | Profiles and PIN: the screens are drawn but profiles are held in memory; per-profile log, schedules, settings and PIN storage are not built. See wiki/Plan-Profiles.md. #97 waits on it. |
| #286 | Research and standards: the citations file and parser | M | lib/core (citations file and parser) | Research and standards: citations file and parser. Part of #214; nothing in lib or tools yet. |
| #287 | Research and standards: the page, in place of Sources | M | lib/features/settings/sources_page.dart | Research and standards page in place of Sources. After #286. |
| #288 | Research and standards: the README section, kept in step | S | README, a test against the citations file | README section kept in step with the citations file. After #286. |
| #292 | Shelf: the shelf format and validator | M | tools/validate_decks.py, lib/core | `kind: shelf` format and validator (the "Beyond the course" shelf). Feature.beyondCourse exists as a flag; no shelf format found. |
| #293 | Shelf: the carousel and interest picker | M | lib/features/decks | Shelf carousel and interest picker. After #292. |
| #294 | Shelf: item page, chapter progress and questions | L | lib/features | Shelf item page, chapter progress and questions. After #293. |
| #305 | Wiktionary IPA: compare and list disagreements | M | tools/import_wiktionary.py (exists) | Wiktionary IPA compare and list disagreements, for review. Needs network at run time, so not CI-testable beyond fixtures. |
| #313 | Import text: the reader and matching words to cards | L | lib/features, lib/core | Import text: the reader and matching words to cards. |
| #314 | Import text: the card maker | L | lib/features, lib/core | Import text: the card maker. After #313 and #316. |
| #316 | In-app readings: a Dart port in lib/core | L | lib/core (Dart port of transcribe.py no-hint path) | In-app readings: Dart port with parity tests. After #315. |
| #320 | Sentence building: unlocking, the drill and grading | L | lib/core/scheduling, lib/features/drill | Sentence building: unlocking, drill and grading. Needs #317 answered and #318/#319 content. |
| #321 | Sentence building: cloze | M | lib/features/drill | Cloze: meaning on top, one learnt word left out. After #317. |
| #322 | Achievements: rules over the log | M | lib/core/stats | Achievements: rules over the log. |
| #323 | Achievements: summary, Progress grid and badges | M | lib/features/stats | Achievements: summary, Progress grid and badges. After #322. |
| #324 | Achievements: level badges from the B1 marks | S | lib/features/stats | Achievements: level badges from the B1 marks. After #322. |
| #325 | Audio drills: the audio service, controls and queue | L | lib/app (audio service), lib/features/drill | Audio drills: audio service, controls, queue. Needs a device for screen-off. |
| #326 | Audio drills: grading by the recogniser and the screen-off fallback | L | lib/app, speech engine | Audio drills: grading by recogniser and the screen-off fallback. After #325; device. |
| #327 | Explain mistakes: read the mistake from the tables | M | lib/core/grading, lib/features/drill | Explain mistakes: read the mistake from the tables. |
| #328 | Explain mistakes: rules a card can name | M | tools/validate_decks.py, lib/core | Explain mistakes: rules a card can name. A deck format change. |
| #342 | Listening in context: a context field and the validator | M | tools/validate_decks.py, lib/core deck parser | Listening in context: a `context` field and the validator. After #341. |
| #343 | Listening in context: scheduling and the drill | L | lib/core/scheduling, lib/features/drill | Listening in context: scheduling and the drill. After #341, #342. |
| #411 | Shareable progress image or summary, built from the review log | M | lib/features/stats (share summary or image) | Shareable progress image or text summary from the review log. Low priority per the issue. Nothing built (no share plugin in pubspec). |
| #472 | Language themes: a colour, icon and background image for each language | L | lib/core (LanguageLook), validator, decks/<code>/<code>-look.yaml | Language themes: colour, icon and background per language. Nothing built (no look file or LanguageLook found). See wiki/Plan-Language-Themes.md. (decks/themes.yaml is a different thing.) |
| #474 | Onboarding journey: where the major functions live and what they do, replayable from Settings | M | lib/features/onboarding, settings | Onboarding journey: the first-launch flow (skills, languages) shipped in 0.7.2; the guided tour that highlights real controls and is replayable from Settings is not found in settings_page.dart. |
| #523 | Card images: Wikimedia Commons and OpenMoji, shipped with decks | L | tools/pictures.py, lib/ui/widgets/card_picture.dart, validator | Card images from Wikimedia Commons and OpenMoji, shipped with decks. Only Noto emoji pictures exist. |
| #612 | Transcriber and Wiktionary importer: readings and IPA for the new languages and scripts | L | tools/transcribe.py, tools/import_wiktionary.py | Readings and IPA for new scripts. Reopened after #784 did part. Several tables need a native check (D-like). |
| #616 | Answer grading for transliteration letters and punctuation-letters | M | lib/core/grading (diacritics.dart, romanised.dart) | Grading for transliteration letters: still open after #783: Lojban, Arabic harakat, Mycenaean typing, Egyptian fold, Sumerian determinatives. Owner parked some. |
| #617 | Courses with no audio: listening passages are required on every unit | L | new tool using eSpeak NG at deck build, CI, app "approximate sound" mark | Courses with no audio: pre-rendered approximate audio. Owner-approved design 2026-10-24. |
| #618 | Format gaps for planning: script units, one core id per unit, nothing after B1, empty regions | M | tools/validate_decks.py, lib/core path parser (PLANNED_KEYS) | Format gaps: planned `script` unit, list of core ids per planned unit, no `regions: []`. Owner answered each gap 2026-10-24. App must read the key a release before any path uses it. |
| #692 | Deck tool: similarity warnings, and a Wiktionary import of meanings, dictionary and example sentences | M | tools/deck_similarity.py (sound-alike exists), validator, import_wiktionary.py | Similarity warnings for spelling and meaning, Wiktionary senses. Sound-alike part exists; look-alike (nukta short list) and Wiktionary senses remain. "Tool only warns". |
| #952 | Skill switches: matching and choosing switches (remainder of #243) | M | lib/features/settings/activities_page.dart or languages_page.dart | Matching and choosing skill switches. Skill pills changed on 2026-11-01 (Speak and Hear one pill); re-read the issue against the current pills before building. |
| #1004 | On-device Telugu speech recognition (IndicConformer, int8, opt-in) for 0.9.0 | L | lib/core/speech, android Kotlin ONNX channel, tools/asr | On-device Telugu recogniser. Install UI, runtime, log-mel, CTC decoder merged (0.10.0); remaining: make it the primary Say listener with system fallback, and verify on phones. Priority item after the placement release. Device needed. |
| #1143 | English Braille as a script of English, not a separate course (the IPA stays separate) | M | assets/languages.yaml, decks/qbe, language picker, ADR-0043 | English Braille as a script option of English, not a separate course (owner 2026-11-12). Touches card ids and progress migration (card ids are permanent); needs an ADR first. |
| #1158 | Offline speech recognisers for every priority language (Indic, European, East Asian) | L | lib/core/speech, tools/asr, models release | Offline recognisers for every priority language (AI4Bharat for Indic, Whisper for European, something else for East Asian). Already queued by the owner. Depends on #1004. |

## D. Deck and content work (held)

Held until the code is done. Counts of built units are from `decks/index.json` on decks-live.

### D1. New course issues (#351 to #388)

Each asks for a language's path and B1 plan (owner, 2026-10-17). Every language but Nepali (#353) and Sanskrit (#356) now has a planned path on decks-live; what remains is the full deck build. See owner question 2.

| Issue | Title | State on decks-live |
|---|---|---|
| #351 | New course: Punjabi | `pa`: path of 121 units, 1 built |
| #352 | New course: Odia | `or`: path of 120 units, 1 built |
| #353 | New course: Nepali | `ne`: no path or decks on decks-live |
| #354 | New course: Tamil | `ta`: path of 115 units, 27 built |
| #355 | New course: Malayalam | `ml`: path of 118 units, 1 built |
| #356 | New course: Sanskrit | `sa`: no path or decks on decks-live |
| #357 | New course: Portuguese | `pt`: path of 87 units, 1 built |
| #358 | New course: Italian | `it`: path of 87 units, 1 built |
| #359 | New course: French | `fr`: path of 113 units, 77 built |
| #360 | New course: Catalan | `ca`: path of 88 units, 1 built |
| #361 | New course: German | `de`: path of 111 units, 1 built |
| #362 | New course: Swedish | `sv`: path of 85 units, 1 built |
| #363 | New course: Norwegian | `nb`: path of 85 units, 1 built |
| #364 | New course: Yiddish | `yi`: path of 86 units, 1 built |
| #365 | New course: Russian | `ru`: path of 88 units, 1 built |
| #366 | New course: Polish | `pl`: path of 87 units, 1 built |
| #367 | New course: Serbian/Croatian | `hbs`: path of 90 units, 1 built |
| #368 | New course: Greek | `el`: path of 87 units, 1 built |
| #369 | New course: Turkish | `tr`: path of 84 units, 1 built |
| #370 | New course: Finnish | `fi`: path of 85 units, 1 built |
| #371 | New course: Hungarian | `hu`: path of 85 units, 1 built |
| #372 | New course: Basque | `eu`: path of 83 units, 1 built |
| #373 | New course: Irish | `ga`: path of 85 units, 1 built |
| #374 | New course: Arabic | `ar`: path of 91 units, 1 built |
| #375 | New course: Hebrew | `he`: path of 90 units, 1 built |
| #376 | New course: Mandarin | `zh`: path of 130 units, 129 built |
| #377 | New course: Cantonese | `yue`: path of 86 units, 1 built |
| #378 | New course: Japanese | `ja`: path of 138 units, 95 built |
| #379 | New course: Korean | `ko`: path of 136 units, 7 built |
| #380 | New course: Vietnamese | `vi`: path of 83 units, 1 built |
| #381 | New course: Thai | `th`: path of 86 units, 1 built |
| #382 | New course: Filipino | `fil`: path of 81 units, 1 built |
| #383 | New course: Malay | `ms`: path of 82 units, 1 built |
| #384 | New course: Swahili | `sw`: path of 84 units, 1 built |
| #385 | New course: Hausa | `ha`: path of 83 units, 1 built |
| #386 | New course: Somali | `so`: path of 82 units, 1 built |
| #387 | New course: Quechua | `qu`: path of 82 units, 1 built |
| #388 | New course: Esperanto | `eo`: path of 112 units, 1 built |

### D2. Other deck and content issues

| Issue | Title | Notes |
|---|---|---|
| #39 | Telugu and Kannada: refit to the Dravidian order | Telugu and Kannada: refit to the Dravidian order. Deck structure; part of the B1 plans. |
| #58 | Review the unreviewed Hindi and Bengali grammar decks | 11 of 26 Hindi and 12 of 26 Bengali grammar decks still `unreviewed`; reviewer work. |
| #101 | Culture deck: local mythology and folklore | Culture deck: mythology and folklore. Sits under the culture work (#1133); content. |
| #102 | Culture deck: cuisine | Culture deck: cuisine. Content; fits the topics/culture model. |
| #105 | Slang decks: add current (Gen Z) slang | Add current slang to each language's slang deck. Content. |
| #106 | Culture deck: love | Culture deck: love. Content. |
| #110 | Dialogue decks: short role-plays, one side each | Dialogue decks. Existing question types only (#107), so mostly content. |
| #169 | Lessons that start from songs and films learners already know | Songs and films as path vocabulary. Content; first instance #170. |
| #170 | Bengali: start the course with Ekla Chalo Re | Bengali: start the course with Ekla Chalo Re. Not found in decks/bn/bn-phrasebook.yaml on decks-live (0 hits). |
| #289 | Research and standards: check every citation | Check every citation against the publisher record. Research task, not code. |
| #290 | Research and standards: more sources | More sources and research. Content. |
| #295 | Shelf: first items per course, and the B1 finale | Shelf: first items per course, B1 finale. Content, sourced and reviewed. |
| #318 | Sentence building: the English sentence bank | Sentence building: the English sentence bank (200-300 sentences). Content. |
| #319 | Sentence building: each course's answers | Sentence building: each course's accepted orders. Content. |
| #329 | Explain mistakes: known mistakes per sentence | Explain mistakes: known mistakes per sentence. Content. |
| #330 | Explain mistakes: in every grammar drill, with content | Explain mistakes in every grammar drill, with content. Content. |
| #340 | ISO 15919 decks: one per Indian language, on the path | ISO 15919 decks, one per Indian language. Only hi has perso-arabic letters; no ISO 15919 deck found on decks-live. Deck work with path changes. |
| #344 | Listening in context: content, in phases | Listening in context: content, in phases. |
| #349 | Word-order tiles: content for 1,098 cards | Word-order tiles: content for 1,098 cards. |
| #419 | Words, rules, sentences: Telugu content | Words, rules, sentences: Telugu content (te has 120 of 121 units built on decks-live). |
| #420 | Words, rules, sentences: content for the other courses | Words, rules, sentences: content for the other courses. |
| #587 | Course: Klingon (tlhIngan Hol), licence check first | Klingon course; licence check first. |
| #588 | Course: Sindarin (Tolkien's Elvish), licence check first | Sindarin course; licence check first. |
| #589 | Course: Quenya (Tolkien's High-Elven), licence check first | Quenya course; licence check first. |
| #590 | Course: Dothraki, licence check first | Dothraki course; licence check first. |
| #591 | Course: High Valyrian, licence check first | High Valyrian course; licence check first. |
| #592 | Course: Indian Sign Language (ISL), with its path and plan | Indian Sign Language course; needs the sign-language format (#579). |
| #593 | Course: American Sign Language (ASL), with its path and plan | American Sign Language course; needs the sign-language format (#579). |
| #631 | Offensive-words decks for the priority languages | Offensive-words decks for the other priority languages. Follows #630. |
| #665 | English Braille: a facts file (qbe-facts.yaml) | English Braille facts file (qbe-facts.yaml). Not on decks-live. |
| #734 | Sounds deck for every language: its sounds, and how they differ from the learner's native sounds | Sounds deck for every language. |
| #959 | Paths and starter decks (first words and phrases) for every planned language | Paths and starter decks for every planned language. Largely done (#965: 35 paths; index now lists 59 languages, most with first-words only). Remaining is the per-language full build. |
| #1133 | Culture decks from real-world works (public domain first), for every first-list language | Culture decks from real works for the ten first-list languages. App side built (0.10.0); content outstanding (ja-culture-1/2 on branches, not merged). |
| #1135 | Proverb decks, levelled, for every first-list language | Proverb decks, levelled, first list. Validator support built; content none. |
| #1136 | Phrasal and multi-word verb decks, levelled, in the languages that have them | Multi-word verb decks, levelled. Validator support built; content none. |
| #1139 | Professional decks: targeted situations for academia, engineering, computer science, medicine, archaeology and other travelling professions (hidden from the main screen, found by search) | Professional decks (hidden situations). `professions: []` in decks/sections.yaml; content none. |
| #1146 | Japanese: about 1000 kanji by B1 (deferred) | Japanese about 1000 kanji by B1. DEFERRED by owner 2026-11-12. |

## E. Plans, epics and umbrellas

| Issue | Title | Notes |
|---|---|---|
| #99 | Culture decks: beyond the basics (tracking) | Culture decks tracker (sub-issues #100-#106). |
| #209 | Plan: a B1 plan in every path | Plan tracker: a B1 plan in every path. All 59 languages now have planned paths on decks-live; close when #257-style leftovers are decided. |
| #214 | Plan: a Research and standards page, with the sources | Tracker: Research and standards (#285-#290). |
| #215 | Plan: books, films and songs you bring, with questions on them | Tracker: books, films, songs shelf (#291-#295). |
| #216 | Plan: a path for every language, by family | Tracker: a path for every language (#296-#302, #350). |
| #217 | Plan: IPA from Wiktionary | Tracker: IPA from Wiktionary (#305). |
| #218 | Plan: Fluenough on the web, installable | Tracker: web PWA. Built and released in 0.9.0 (#1018, #1019, #1038, #1039); only the real-browser check (#1012, deferred) remains. Candidate to close once the owner agrees. |
| #219 | Plan: conversation practice with an AI, within what you know | Tracker: AI conversation. Long-term, no spec. |
| #220 | Plan: read your own text, and make cards from it | Tracker: import text (#313, #314). |
| #221 | Plan: readings made in the app | Tracker: in-app readings (#315, #316). |
| #222 | Plan: building sentences by reasoning, and cloze | Tracker: sentence building (#317-#321). |
| #223 | Plan: achievements, not as aggressive as Duolingo | Tracker: achievements (#322-#324). |
| #224 | Plan: hands-free audio drills | Tracker: audio drills (#325, #326). |
| #225 | Plan: explain a grammar mistake | Tracker: explain mistakes (#327-#330). |
| #226 | Plan: writing the script by hand | Tracker: handwriting. Build issue is #638. |
| #229 | Plan: an ISO 15919 letters deck | Tracker: ISO 15919 letters deck (#340). |
| #230 | Plan: a listening tier in context | Tracker: listening in context (#341-#344). |
| #232 | Plan: Play Protect and developer verification | Tracker: Play Protect and developer verification (#345, #346). |
| #234 | Plan: word-order tiles without giveaways, and with extra tiles | Tracker: word-order tiles (#348, #349). |
| #310 | AI conversation: the learner's limits, and keeping the model within them | AI conversation: the learner's limits. No spec; long-term plan part. |
| #311 | AI conversation: scenarios, feedback and optional speech | AI conversation: scenarios, feedback, optional speech. No spec. |
| #312 | AI conversation: privacy, and tests with a fake model | AI conversation: privacy and fake-model tests. No spec. |
| #350 | Language paths: new languages, one full course each | Umbrella for the new-language course issues #351-#388. |
| #403 | Plan: reviewing decks in the app, sent by mail | Tracker: review decks in the app by mail. Mail bot and reviewer mode shipped; remaining sub-issues are reworded per the 2026-10-09 comment. |
| #413 | Plan: a phrasebook, then words, then rules, then sentences | Plan tracker: phrasebook, words, rules, sentences. Content parts #419, #420. |
| #506 | Deck format review: card data list, questions from card data, DECK-FORMAT as the one guide | Deck format review (ADR-0039 accepted 2026-10-24; question engine #522 built in steps). Close when #522 closes. |
| #509 | Milestone exams: reading passages and questions at each B1 milestone, required to continue | Plan: milestone exams. Phase 0 (shared shell) built (#1003, #1005, #1006); the exam variant and exam screen are not built. Large; needs a mockup first. |
| #579 | Sign languages: a deck format and drills built on images and video | Sign languages tracker: deck format and drills on images and video. Needs the owner's design. |
| #1017 | Plan: build entire languages as private decks (Your decks) | Plan: private decks. IN BUILD (owner approved mockups 2026-11-13): .fnzip core, import review and Your decks screens merged under [Unreleased]; later slices ship as 0.10.x. |

## F. Blocked or waiting on the owner

| Issue | Title | Waiting on |
|---|---|---|
| #25 | F-Droid metadata and submission | F-Droid submission. The `blocked` label is stale (#24 closed, releases exist; comment 2026-10-09). Needs the owner to want it and to submit; F-Droid builds from source. |
| #26 | Accessibility: a TalkBack pass on a phone | TalkBack pass on a real phone with voices installed. Needs a physical device and the owner or a tester. |
| #32 | Grapheme-level TTS fallback for script decks | Grapheme-level TTS fallback. First step is to test what engines do with a bare letter on a real device, per language. |
| #33 | Right-to-left: check on a device with a real Urdu deck | Right-to-left device check with a real Urdu deck (#40/#602) and keyboard. Device. |
| #34 | Complex script rendering: Nastaliq, conjuncts, matras | Nastaliq and complex-script rendering on real devices; fonts collected under #611. Device. |
| #46 | Let the user choose the interface language, with translations in plain txt files | App-language choice with translations in plain txt files. Recorded, not scheduled: "Do not start without the maintainer's go-ahead". Settings row exists with English only. |
| #97 | Parental supervision: child profiles with no abuse-related content, and admin controls | Parental supervision. Blocked by #204 (profiles and PIN); plan in wiki/Plan-Profiles.md. `blocked` label is correct. |
| #285 | Research and standards: owner decisions before building | Owner decisions before building Research and standards: sources first, file kind, confidence display. |
| #291 | Shelf: owner decisions before building | Owner decisions before building the shelf: first items, finale sources, interest themes, film parts. |
| #296 | Language paths: owner decisions | Owner decisions for language paths: order of new languages, variants (Brazilian/European Portuguese), Serbian/Croatian, time split. |
| #299 | Language paths: variants and the common start | Language path variants and the common start. Needs #296 decisions first. |
| #317 | Sentence building: owner decisions before building | Owner decisions before building sentence building: typed/tiles/spoken, bank size, bank file format, cloze typed or chosen. |
| #331 | Handwriting: owner decisions before building | Handwriting owner decisions: stroke-order convention per Indian script and who checks it; KanjiVG CC BY-SA beside CC0 decks. Blocks #332-#334 and #638. |
| #332 | Handwriting: stroke data | Handwriting stroke data (new file kind). Blocked by #331. |
| #333 | Handwriting: the stroke animation | Handwriting stroke animation. Blocked by #331 (data) and #332. |
| #334 | Handwriting: tracing and drawing blind, recorded as Write | Handwriting tracing and drawing blind, recorded as Write. Blocked by #331-#333. |
| #341 | Listening in context: owner decisions before building | Owner decisions before building listening in context: harder Hear vs own schedule, thresholds, question language. |
| #345 | Release signing: developer console account and registration | Release signing: developer console account and registration of app.fluenough with the release key SHA-256. Needs the owner's account. |
| #346 | Release signing: prove ownership in the APK | Release signing: ownership snippet in the APK. Needs the SHA-256 and registration from #345. |
| #495 | Your decks: custom decks, templates, and an upload review that validates and fixes | Your decks: custom decks, templates, upload review. Owner 2026-11-04 "keep it aside". Overlaps #1017 stage 2 (built now: import review, Your decks, packages). Ask whether to merge into #1017. |
| #520 | Regional flavours: a deck per language after A2, noting major regional variations | Regional flavours deck per language after A2. Labelled blocked; open design: how a regional note is marked (map-marker icon decided 2026-10-22), plus owner processes contributions by hand. |
| #522 | Question engine: questions derived from card data (ADR-0039) | Question engine. Steps 1-9a and 6-7 shipped (CHANGELOG). Remaining step 9b and ability thresholds wait on the #509 exam screen (owner 2026-10-31). |
| #614 | A second reading field on cards: transliteration and normalised or vocalised form | Second reading field on cards. Owner 2026-10-24: "Later, with ancient courses". |
| #638 | Build handwriting: stroke files, stroke animation, tracing and drawing | Build handwriting. `direct-code` label is inconsistent: #331 is unanswered (comment 2026-11-07 suggests removing the label). |
| #722 | Conversation mode: transcribe two people talking, in real time | Conversation mode (live two-person transcription). Idea only; no spec; needs speech work (#1004/#1158) first. |
| #723 | Focused tracks: learn only one part of a course (a script, a grammar primer, verb forms, a theme) | Focused tracks. Owner 2026-10-31: deferred, "will think of them later". |
| #842 | Voices page: complete redesign, with a mockup | Voices page redesign. Owner 2026-10-25: "complete redesign with mockup next week"; needs the Sonnet mockup and approval first. |
| #881 | Speaking: "Hear yourself" replays the answer the learner spoke, not a new recording | Hear yourself replays the answer spoken. Blocked on #1004: the system recogniser returns no audio, and concurrent capture was removed in 0.10.0 (#1107). Owner comment 2026-11-04 says the audio waits on on-device recognition. |
| #1095 | Review shell: Again / Hard / Okay / Easy self-rating buttons | Again/Hard/Okay/Easy self-raters. Recognition already shows Again, Hard, Good, Easy (lib/features/drill/rating_buttons.dart, recognition_drill.dart). Open: which other item types, "Okay" vs "Good" wording; needs a mockup per the issue. |
| #1096 | Reviews: use the new placement question types | Placement question types in reviews. Open decisions on formats per skill, letter counts, Say/Hear fallbacks; needs a mockup. Reuse lib/core/placement generators. |
| #1103 | Play Store release: paid colour themes, pure black and wallpaper colours (free on GitHub) | Play Store build: paid colour themes, pure black, wallpaper colours. Needs the owner's choice of one-time purchase vs subscription, a Play account and a build flavour. |

## G. Close candidates

Strong means the code, data or the owner's own words prove it; Probable means the evidence is good but a person should look before closing. Nothing was closed by this audit.

| Issue | Title | Strength | Evidence |
|---|---|---|---|
| #924 | Typed meaning answers: accept equivalent words (synonym dictionary) and unseparated alternatives | Strong | Built: ADR-0050; synonym grader lib/core/grading/synonym_sets.dart; assets/synonyms/en.yaml (208 lines of sets) checked by tools/validate_synonyms.py; part 1 validator rule; reviewer proposals. CHANGELOG [Unreleased] entries cite #924. Adding more sets is content. |
| #1140 | Search results by type, each with its own tab: situations, topics, decks, grammar concepts and more (mockup first) | Strong | Built in 0.10.0: "Search results by type" tabs (CHANGELOG [0.10.0]); lib/features/decks/search_tabs.dart, search_item_rows.dart. Owner approved mockup 2026-11-12. |
| #1137 | Topics for deck search: language-specific grammar topics, and search must cover situations decks | Strong | Built in 0.10.0: topic pages and search (lib/features/topics/topic_page.dart, lib/app/topics.dart, lib/core/decks/topic_resolver.dart). Per-language topic files are deck content (ja-topics.yaml on a branch). |
| #1142 | Culture recommendations: popular works not reproduced here, "I've done this" on the homepage, questions and briefings about them | Strong | Built in 0.10.0: culture recommendations (lib/features/culture/recommendations_page.dart; CHANGELOG [0.10.0] "Culture in the course, and recommended works"). Recommendation content is under #1133. |
| #1134 | Culture items woven through the courses at the right level (not a separate shelf only) | Strong | Built in 0.10.0: culture woven into units and Today with creator card and timeline (lib/features/culture/culture_cards.dart, culture_timeline.dart, creator_sheet.dart). Content is under #1133. |
| #1101 | Say: recording at recognition is untested on a real device | Strong | Obsolete: the concurrent record-while-recognising design it asks to test was removed in 0.10.0 (CHANGELOG [0.10.0] Fixed: "Say works again: recording no longer runs at the same time as online recognition; #1107"). Labelled bug. A real-phone check of Say stays useful but belongs to #1004/#881. |
| #107 | New deck topics are data: a section field, and question types after the skill model | Strong | Built: `section` and `genre` deck header fields, decks/sections.yaml, validator checks (CHANGELOG [0.10.0], #1133-#1140); question types are derived from card data (#522, ADR-0039). Topics are data as the issue asked. |
| #91 | Pictures as cues: image format, licence and validator, for Write and Hear | Strong | Built: `picture:` per card (PR #432), lib/features/drill/picture_choice_drill.dart (owner 2026-10-30: picture choice is a form of Recognition), lib/ui/widgets/card_picture.dart, `picture_ask` (#707). Photographs are #523; screen-reader descriptions are not tracked here. |
| #95 | Bengali compound-verb deck; phrasal verbs if English becomes a course | Strong | Bengali compound-verb deck exists on decks-live (decks/bn/bn-grammar-compound-verbs.yaml, its sentences, bn-en-reading-compound-verbs.yaml). English phrasal verbs are covered by #1136. |
| #94 | Proverb and idiom decks | Strong | Duplicate: #1135 "Extends #94" and covers Hindi, Bengali and Telugu inside the first list, with levels. Close in favour of #1135. |
| #96 | Offensive words behind an adult gate | Strong | Split by the owner on 2026-10-18 into #628 (adult gate, merged #772), #629, #630, #631. Umbrella with nothing left of its own. |
| #630 | Telugu offensive-words deck (te-offensive), rated before it ships | Probable | Deck exists on decks-live: decks/te/te-offensive.yaml and its English layer. Check it carries the rating the issue asks for before closing. |
| #111 | Native-speaker audio for cards, where TTS is weak | Probable | Card `audio` and `audioCredit` (lib/core/models/card.dart), clip player (lib/core/tts/system_clip_player.dart), Wiktionary recording import (tools/import_wiktionary.py). Landed on decks-next per #506 comment 2026-10-16. Recordings themselves are content. |
| #257 | B1 plans: the CEFR skeleton of themes and grammar per level | Probable | The CEFR skeleton is written in wiki/Plan-B1-Plans.md ("The skeleton, from the CEFR descriptors") and every path on decks-live has its A1/A2/B1 marks. |
| #297 | Language paths: tiers and phases | Probable | Hours per language and path level sizes shipped: ADR-0045, Feature.hoursLeft (#227), lib/features/decks/course_hours.dart, wiki/Plan-Hours-Per-Language.md. |
| #298 | Language paths: pacing and the 30-minute day | Probable | Pacing by a daily time budget (not nine words a day): lib/features/settings/daily_minutes.dart, ADR-0024/0046, wiki/Today-and-Daily-Lessons.md. |
| #300 | Language paths: Indo-Aryan reorder | Probable | Indo-Aryan paths are in the new order on decks-live (hi 119 of 120 units built, bn 172/173, mr 115/116, as 172/173, gu 42/117); owner ordered every path rebuilt 2026-10-17. |
| #301 | Language paths: a full Spanish course | Probable | Spanish course: 102 of 103 units built on decks-live (decks/index.json), 269 decks. |
| #302 | Language paths: what new scripts need | Probable | Split by the owner on 2026-10-18 into #611 (fonts), #612, #613, #614, #615, #616, #617, #618, #619; nothing of its own is left. |
| #100 | Culture deck: cultural heroes | Probable | Cultural heroes: superseded by the creator profiles, legacy and timeline of #1133/#1134 (built). Owner to confirm. |
| #103 | Culture deck: famous films | Probable | Famous films: superseded by culture recommendations (#1142, built) for films that cannot be reproduced. Owner to confirm. |
| #104 | Culture deck: classic literature | Probable | Classic literature: superseded by #1133 (culture decks from real works, public domain first). Owner to confirm. |

## Owner questions

1. Close candidates (bucket G): may the strong ones be closed now, and the probable ones after a look? Say which.
2. New-course issues #351-#388: their stated scope (path and B1 plan) is done for every language except Nepali (#353) and Sanskrit (#356). Close those 36, keep #353 and #356, and track the full deck builds in one tracker (or in #350)? Deck work stays held either way.
3. #1095 and #1096: recognition already shows Again, Hard, Good, Easy. Should the raters spread to other self-judged item types, and is "Okay" a rename of "Good"? Both issues also want a mockup; shall one be commissioned after the small items?
4. #1132: if the sentence fill-in (F28) cannot pass the audit for Hindi (66 clean items), is it acceptable to leave F28 off for Hindi only?
5. #1145: the owner's 2026-11-13 comment settles it; OK to build as one PR with #681 (both touch the language and situations UI)?
6. #46 (UI language): go-ahead or keep parked? #204 and #97 (profiles, PIN, child profiles): schedule after the private-decks slices, or later?
7. #495: merge into #1017 (Your decks, stage 2) and close, since the private-decks work now covers import review and Your decks?
8. #842 (Voices page redesign) and #836 (IPA keyboard): do you want the Sonnet mockups made now, or after the code backlog?
9. #1103 (Play Store paid themes): one-time purchase or subscription, and when is the Play account ready?
10. #331 (handwriting): the stroke-order convention per Indian script and the KanjiVG licence. Until answered, remove `direct-code` from #638?
11. #425: allow trying the analyzer bound removal in CI now that build_runner 2.17.1 exists?
12. #25 (F-Droid), #345/#346 (release signing), #722 (conversation mode), #723 (focus tracks): keep, or close as not planned to trim the backlog?

See also: [Roadmap](Roadmap), [Plans Index](Plans-Index), [Plan Deck Kinds And Topics](Plan-Deck-Kinds-And-Topics).
