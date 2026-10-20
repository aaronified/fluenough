# Plan: cut the tests down to behaviour

## Owner's decisions (2026-10-20)

1. Total: "About 469".
2. Accessibility: "One test, light+dark" per screen at 1.4x (42 tests).
3. README GIF tests: "Tool run by hand", out of CI.
4. Tools outside decks and reviews: "A few tests each".
5. Braille (#664): "Before the cut".
6. Landing: "One PR".

Written 2026-10-20. A plan only: no test is changed by it.

The owner, 2026-10-20: "there is no need for 4000+ tests. That can easily be
cut down to about 100-500. You are testing every code change. No point in
that at all. You should only check behaviour." (CLAUDE.md, "Tests check
behaviour".) And, 2026-10-17: "We are now only building for 1.4x text"
(CLAUDE.md, "Text size: 1.4x only").

## Summary

| Suite | Files before | Tests before | Files after | Tests after | CI time before | CI time after (estimate) |
|---|---:|---:|---:|---:|---:|---:|
| Flutter (`test/`) | 240 | 4,320 | 16 | 374 | 50 min | 6 to 9 min |
| Python (`tools/test_*.py`) | 35 | 844 | 19 | 94 | under 1 min | under 1 min |
| Release reader (`tools/release_reader/`) | 1 | 1 | 1 | 1 | its own job | unchanged |
| **Total** | **276** | **5,165** | **36** | **469** | | |

The "Analyse and test" job takes about 59 minutes now (run 39315307756 on
main, 2026-10-19, #647): 50 of them are `flutter test`, the rest `flutter
create`, `pub get`, `build_runner`, `flutter analyze`, the live download and
the format check. After the cut it should take **about 10 to 13 minutes**.

How the numbers were found:

- **Tests before** are the per-test lines in that run's log: 4,228 passed and
  2 skipped (one of them the live test). Twelve test files landed after that
  run; their 90 tests are counted from the source. Python is counted from
  `def test_` lines. Loops that make a test per case are counted as the tests
  they make: `deck_parser_test.dart` runs 1,076, `accessibility_test.dart` 292.
- **CI time** of a file is its share of the 50 minutes: each test line's gap
  from the line before, summed by file. Four files run at once, so this is a
  share of the wall time, not CPU. The estimate after scales each file's
  share by the tests it keeps, gives the new accessibility tests twice the
  old per-test time (each draws light and dark), and adds 2 to 3 minutes for
  compiling 16 files instead of 240.

The slowest files now, and what happens to them:

| File | Tests | Share of CI | After |
|---|---:|---:|---|
| `accessibility_test.dart` | 292 | 8.6 min | 49, one check per screen at 1.4x, light and dark |
| `features/settings/layout_test.dart` | 96 | 3.4 min | deleted; its screens are in the per-screen check |
| `features/profiles/spoken_languages_page_test.dart` | 52 | 1.3 min | 3, in `onboarding_test.dart` |
| `features/settings/settings_page_test.dart` | 53 | 1.2 min | 1, in `settings_test.dart` |
| `features/placement/placement_flow_test.dart` | 14 | 1.1 min | 3, in `languages_and_scripts_test.dart` |
| `features/today/pace_test.dart` | 27 | 1.0 min | 1, in `progress_test.dart` |
| `ui/language_bar_test.dart` | 36 | 1.0 min | 1, in `languages_and_scripts_test.dart` |
| `deck_parser_test.dart` | 1,076 | 8 s | 10, in `deck_format_test.dart` |

## What a kept test is

1. It names something a learner or a deck author sees happen: "a dropped
   article is accepted when the language declares them", not "stripArticle
   returns the tail".
2. One test may check several cases of one behaviour in a loop, so the
   cases a rule needs survive the cut without a test each. Python uses
   `subTest` for this.
3. No test of a private helper, of wording or a string, of a widget's
   internals, of the exact count of a real deck, or of per-language data the
   validator already checks.
4. Layout is checked once per screen, at 1.4x text, in light and dark, by
   the accessibility check. No other test sets a text scale.
5. A change adds a test only for a behaviour no test covers yet (CLAUDE.md).

## The new layout

Sixteen Flutter test files, one per area a learner or author meets. The
helpers in `test/support/` and the fixtures stay; a helper goes with its last
user.

| New file | From files | Tests before (merged in) | Tests after | Est. CI share (s) |
|---|---:|---:|---:|---:|
| `lesson_and_review_test.dart` | 29 | 497 | 60 | 58 |
| `accessibility_test.dart` | 2 | 298 | 50 | 175 |
| `progress_test.dart` | 19 | 252 | 30 | 29 |
| `grading_test.dart` | 12 | 118 | 29 | 11 |
| `deck_format_test.dart` | 10 | 1,217 | 28 | 2 |
| `languages_and_scripts_test.dart` | 18 | 211 | 27 | 40 |
| `deck_downloads_test.dart` | 9 | 150 | 24 | 10 |
| `scheduling_test.dart` | 10 | 266 | 23 | 3 |
| `reviewing_test.dart` | 14 | 150 | 21 | 6 |
| `backup_and_restore_test.dart` | 9 | 99 | 20 | 7 |
| `voices_test.dart` | 11 | 116 | 15 | 10 |
| `settings_test.dart` | 13 | 166 | 14 | 19 |
| `onboarding_test.dart` | 4 | 89 | 11 | 17 |
| `app_update_test.dart` | 5 | 95 | 11 | 8 |
| `database_test.dart` | 1 | 18 | 10 | 1 |
| `live/github_downloads_test.dart` | 1 | 1 | 1 | 1 |
| **16 files** | **167** | | **374** | **about 6.6 min, plus compiling** |

The other 73 Flutter files are deleted outright (the per-file table says why).

Python keeps a file per tool, and folds the nineteen `test_validate_*.py`
files into four: `test_validate_decks.py` (single-file decks, YAML, content,
the index check), `test_validate_card_ids.py`, `test_validate_b1.py` (cores,
layers, paths, sets, rules) and `test_validate_card_data.py` (card data,
media, IPA, ISO, romanisation, reading decks, script guides, target scripts,
examples, gender).

## By area

**Onboarding (11).** The app opens on Today with real decks and the bar
switches tabs; the tour walks, skips, goes back as Android back does, and
claims only what ships; a double tap cannot skip a step; the sound check
asks for the microphone only on Record and saves speaking and listening as
it found them; Languages you know finds a language by its English or its own
name, asks in that language, asks which script where there are several, and
reads saves from before #551.

**Languages and scripts (27).** The picker searches names, own names and
codes, keeps Learning first, goes in steps, and stops a download when the
learner stops the language or cancels; placement places known units, stops
after two wrong, keeps what Stop here found and saves nothing when left;
the taught-from language is asked once per course and a unit without a deck
in it is Coming; without the alphabet, script decks are left out and words
are typed in Latin letters; script choice (Devanagari, Perso-Arabic, both)
decides what a card shows and what Write offers; the script test skips the
script lessons when passed; the IPA course follows the languages learned;
the language bar switches language.

**A lesson and a review (60).** The session queue (due first, most overdue
first, the new-card cap, one mode per card, no voiceless or switched-off
mode); the lesson (easy first, teach then check then ask again, no voice
falls back to choosing); every kind of question records its grade:
recognition, choice, match, rearrange, typed production with a near-miss
judgement, Hear, speaking with its try again and Hear yourself, grammar
cells (meaning, then form), minimal pairs, reading passages and their
glossary, sets, number practice; the path teaches the first two units and
skips placed ones; Today's due count, Start review, Quick revision and the
skill tiles start what they say; Can't now pauses or turns off a skill for
one language; the script guide shows once before the first script card; the
daily fact; the summary.

**Grading (29).** The answer grader (exact, case and punctuation,
alternates, accents flagged, articles, typos short and long, another word
wrong, empty wrong); Indic spellings (danda, nukta, two-part vowel signs,
digits); the rule-based meaning grader (the owner's examples, rules 1 to 5,
paraphrase stays wrong, a typo after the rules is a near miss); romanised
and ISO-based readings typed as people type them; transliteration before and
after the script units; spoken answers (best reading, a sure second reading,
near miss wrong in speech, nothing heard records nothing); the contrast a
mis-heard sound names; self-grades.

**Scheduling (23).** FSRS against py-fsrs sequences and its properties
(grade mapping, a better rating never shorter, a miss is a lapse, DST); the
fit against fsrs-rs on three cases, its gate, window and start, and that it
is deterministic; keeping a new set only when it predicts better; implied
skills; leech reset, undo and set aside; the log replays to the same
states; Adjust to me.

**Progress (30).** Numbers for 7 days, 30 days and all time; streaks per
language and across DST; a word in two decks learned once; Known, Learning
and New; Done decks and Revise; the path's up-next unit and A1 reached;
completeness and stage toward B1; Read and Write per script; hours spent and
left; How you learn and the pace strip after a fit; leeches append and never
delete.

**Backup, restore and the log (20).** A backup round-trips everything and
refuses a newer, damaged or foreign file; five kept, three from updates; a
restore keeps a copy first, replaces both logs through `replaceLog`, logs a
`restores` row, and a failure part-way leaves both; every other delete is
still refused; a log import merges in time order; answers survive a restart
and a stale state cache is repaired from the log; settings survive a
restore.

**Database (10).** Every migration from version 1 keeps its reviews (eight
cases), a grade outside 0 to 5 is refused, `leech_actions` is append-only.

**Deck download and update (24).** First launch lists GitHub's languages and
downloads one; ready after the first decks with the rest behind it; offline
and rate limit keep nothing and say so; a hash mismatch is thrown away; cut
short keeps whole decks and leaves no file in use; an update keeps every
card id, and a failed one leaves the decks as they were; a stale index is
read again; proposals are an update for a reviewer only; a deck GitHub
dropped stays; fonts download with their course; an added deck file joins
its unit or says why not; repeated failures offer the app update.

**Voices (15).** The voice fallback (Hindi voice for Perso-Arabic cards,
Urdu voice for Devanagari decks, none when neither); a voice gone falls
back; one word's error does not fail the next; sound off speaks nothing and
skips listening; a muted phone asks for volume; recordings play in place of
the phone; a tap plays a word and never gives the answer away; Voices
lists languages learned first and Install opens the phone or explains; a
rude word is never offered or played.

**Reviewing (21).** A reviewer's code; Looks right and Suggest a change,
never both; sign off and Send review in one mail, marked sent only when it
goes, and taken back once; base changes; proposals accepted, rejected,
edited; what waits per language; offensive words asked for every time,
never in a unit, regions from the path; the look-alike warning only after
the answer; the app's agreement count matches the review bot's.

**Settings and reports (14).** Every row opens its page and the version is
pubspec's; a skill switch turns its skill off; speech rate reaches the
voice; theme and high contrast apply to the whole app; adult content asks
once; the app log keeps 7 days or 2,000 lines, survives a restart and
exports; a report goes by share, else mail, else says why, with the log
only when ticked; an incoming feature is dimmed and does nothing; the PIN.

**App update (11).** Checked at most once a day and off at first; a newer
release kept, a failure says why; the download fails after a minute of
silence and Cancel ends it; the old APK is deleted after the update;
release notes asked only when opened.

**Accessibility at 1.4x (50).** One test per screen, drawing the screen at
1.4x text in light and in dark, each against the guidelines the current
file uses: nothing overflows or is clipped, nothing sits under the
three-button bar, tap targets are 48 dp, every control is labelled, text
meets contrast. The screens, one state each (the busiest the gallery has):

- Learn: Today, Decks path, unit, deck page, Inspect, Languages on the
  phone, summary (7).
- Drills: teach card, recognition, choice, match, rearrange, typed
  production with the keyboard open and its feedback, listening, speaking
  with try again, grammar, minimal pairs, reading passage with glossary,
  set card, script guide (13).
- First launch: tour, sound check, Languages you know with its sheet,
  language picker with a language's sheet, placement question, script test
  (6).
- Progress and settings: Progress, How you learn, leeches, Settings,
  Activities and memory, Appearance, Voices, backup and the restore sheet,
  app log, release notes, Report a problem (11).
- Reviewing: review page, Suggest a change, Waiting for review, the
  offensive-words gate (4).
- Profiles: the PIN page (1).

Beside them: the screen reader never reads out the answer asked for (four
kinds of question); deck text in an interface string is read in its own
language, Perso-Arabic as Urdu; the first launch in high contrast and every
colour; a phone at 2x text is drawn at 1.4x; a toast is a live region.
That is 42 + 8 = 50.

**Deck format, in the app (28).** What the app's parser does with what a
deck author writes: the YAML traps (bare `false`, `no`, `007`, YAML 1.1 and
1.2), missing and unknown fields with their line and column, id and kind
rules, `iso639_3`; a core merged with its layer, refs through the layer of
their native language, rules expanded to stable cell ids; paths, reading
decks, target scripts, guide layers; every deck the index lists parses (one
test over all of them), a broken file is a row with its line, a duplicate id
is reported.

**Deck format, in the validator (52).** A few cases per rule a deck author
hits, the error and the passing case: YAML typing as the app types it, the
index check, iso639_3, ids and refs and `--next-id`, cores, layers, paths
and sets, facts, themes, card data, media credits, IPA, ISO 15919 readings,
romanisation, reading decks, script guides, target scripts, examples,
gender.

**Tools (42).** Release version check (4) and release preparation (3); the
deck index (5); the review bot (6), proposals (3), base proposals (2) and
checked_by (3); mail to issues, with support mail kept private (3); the
Android branding (2); the Wiktionary importer, which never changes a meaning
(3); split deck, which keeps every id (2); transcription (2), Wikipedia
frequency (1), the UI string gate (2), the IPA course generator, which
keeps its ids (1).

## Behaviours left with no test

None of the behaviours the owner listed to keep is left without a test.
These go untested:

- Layout at 2.0x text, and per-state layouts beyond one state per screen
  (the app caps text at 1.4x).
- Interface wording: switch lines, the offline claims, the checked-by line,
  the update backup row, how grammar understood is named.
- The debug gallery listing every design screen, and the README GIFs.
- Display-only details of deck content: card bases, facts and notes on the
  card sheet, pictures, IPA examples, the course card's hours.
- Library internals with no behaviour of their own: SHA-256, the Rust RNG
  port (reached only through the fsrs-rs parity cases), the Markdown
  subset's edge cases, Levenshtein, the feature registry, the pacing job
  runner, the system-settings channel plumbing, choice shuffling.
- The asks golden (`ask_pin_test.dart`).
- Incoming features: creating a profile, the profiles list, reminders.
- Per-language data: the bundled Hindi, Telugu and Bengali guides and
  contrast files load, the shipped voice-apps list, every path lists its
  gender classes, `assets/languages.yaml` entries. The validator, or the
  app's catalog test, reads these files.
- Folding a level on the path, the Where I am colour, the skill tiles'
  layout, toast timing.
- The minimal-pair (sounds) file's validator shape checks; the app's
  contrast test still reads the bundled files.

The braille keyboard's no-system-keyboard guarantee is not on main yet: it
is on the `braille-course` branch (`braille_keyboard_test.dart`,
`braille_course_test.dart`). When that lands, its "production is typed on
the app's own keyboard, in place of the phone's, and graded as typed" and
"another language keeps the phone's keyboard" go into
`lesson_and_review_test.dart`, and its keyboard screen into the per-screen
check. That branch also edits six files this plan merges, so it should land
before the cut, or be rebased onto it.

## The riskiest cuts

1. **The validator's error branches** (about 650 Python tests to 52). Real
   decks only reach the passing branch, so a rule that stops firing would
   not be noticed. Keeping each rule's bad cases in one `subTest` loop is
   what makes this safe; if a rule has no case left, add one.
2. **The review bot** (52 to 6). It merges pull requests on its own. The
   cases kept are the ones that decide what reaches main: merge only when
   checks pass, apply only with enough agreement, never re-apply an
   owner's revert, close outdated proposals.
3. **The 1,076 per-deck parse tests** become one test that reads every deck
   the index lists. A deck the app cannot read still fails it, and the
   release-reader job reads them with the released code, but the failure
   names one deck at a time.
4. **The 2.0x matrix** goes. If the 1.4x cap (#505) broke, layouts at 2x
   would no longer be checked; the cap's own test guards that.
5. **fsrs-rs parity** drops from every case to three, and the RNG test goes.
   A drift in a rare path (a batch past 256 reviews, the outlier filter)
   could pass. Choose the three cases to reach those paths.
6. **Database table tests** go; migrations stay. A change to how a table is
   written is covered only through the behaviour tests that use it.

## Decisions for the owner

1. **The total.** This plan reaches 469 (374 Flutter, 94 Python, 1 release
   reader). Is that the number, or should it go lower, toward 300? Do the
   Python tools' tests count toward the 100-500?
2. **One test per screen, light and dark inside it** (42 tests), or two per
   screen (84)? One is faster and is what this plan counts.
3. **README GIFs.** `test/tools/readme_gifs_test.dart` makes the README's
   GIFs and `tools/test_make_gif.py` tests the maker. Move the GIFs to a tool
   run by hand, or keep them in CI?
4. **Tools outside decks and reviews** (mail to issues, Android branding,
   Wiktionary importer, Wikipedia frequency, transcription, split deck):
   keep a few tests each, as planned, or none?
5. **Braille first?** Land `braille-course` before the cut, or rebase it
   after?
6. **How to land it.** Proposed below: one pull request per area. Or one
   pull request for all of it?

## How to carry it out

One pull request per area, each green in CI before the next; no new
behaviour and no app code change in any of them.

1. Delete the 73 files marked delete (Sonnet). The quickest win: most of
   the 2.0x layouts go here.
2. Rewrite `accessibility_test.dart` as the per-screen check (Opus, being
   several files' worth of harness).
3. One pull request per new file, merging and trimming its sources
   (Sonnet, reviewed by Opus): deck format, grading, scheduling, database,
   backup, downloads, voices, languages and scripts, lesson and review,
   progress, reviewing, settings, onboarding, app update.
4. Python: fold the validator files, then trim each tool's file (Sonnet).
5. Update the test count in `AGENTS.md` ("over 2,200 now").

## Per-file table: Flutter

Before is the count in run 39315307756 (or from the source for files that
landed after it). Paths are under `test/`.

| File | Before | Decision | After | Why |
|---|---:|---|---:|---|
| `ability_test.dart` | 12 | merge into `scheduling_test.dart` | 1 | Ability decides typed or chosen; one case (right raises, miss lowers). Share arithmetic is internal. |
| `accessibility_test.dart` | 292 | keep | 49 | Rewritten: one 1.4x light+dark guideline check per screen (42), the screen reader never reads the answer (4), deck text read in its language, Perso-Arabic as Urdu (1), first launch in high contrast and every colour (1), a phone at 2x drawn at 1.4x (1). The 2.0x matrix and per-state repeats go. |
| `answer_grader_folds_test.dart` | 9 | merge into `grading_test.dart` | 1 | Missing accent vs missing article flags. The rest restate answer_grader cases. |
| `answer_grader_indic_test.dart` | 16 | merge into `grading_test.dart` | 4 | Danda, nukta spellings equal, two-part vowel signs, missing nukta flagged, Indic digits. |
| `answer_grader_test.dart` | 21 | merge into `grading_test.dart` | 7 | Exact, case and punctuation, alternate, accent flagged, dropped article, typo near miss short/long, other word wrong, empty wrong. Levenshtein internals go. |
| `app_l10n_test.dart` | 3 | delete | 0 | String plumbing; `flutter analyze` and `tools/check_ui_strings.py` already guard it. |
| `app_shell_test.dart` | 5 | merge into `onboarding_test.dart` | 1 | The app opens on Today with real decks; the bar switches tabs and Back returns. The 2x overflow case goes. |
| `ask_test.dart` | 15 | merge into `lesson_and_review_test.dart` | 2 | Recognition by match then choice; a phrase is rearranged; Hear chosen while new, typed once remembered. |
| `b1_format_test.dart` | 57 | merge into `deck_format_test.dart` | 7 | Core + layer merge, refs through the layer, rules expansion, typed notes, malformed refused. Section-by-section restatements go. |
| `card_data_test.dart` | 8 | merge into `deck_format_test.dart` | 1 | Core keeps data, layer gives text. |
| `card_examples_test.dart` | 5 | delete | 0 | The validator checks examples; b1_format's merge test carries one. |
| `card_refs_test.dart` | 7 | merge into `deck_format_test.dart` | 1 | A ref resolves to the written card; a repeated word is one card. |
| `course_path_test.dart` | 12 | merge into `deck_format_test.dart` | 2 | Units in order, wildcards place unlisted decks, a unit with no deck in the native language is Coming. |
| `daily_fact_test.dart` | 10 | merge into `lesson_and_review_test.dart` | 1 | Today shows the next unseen fact in the learner's language and records it. |
| `database_test.dart` | 18 | keep | 10 | Every migration from v1 keeps its reviews (8); reviews refuse a bad grade; leech_actions append-only. Per-table CRUD goes. |
| `deck_parser_test.dart` | 1076 | merge into `deck_format_test.dart` | 10 | YAML traps (bare false/no/007, 1.1 vs 1.2), missing and unknown fields, positions in messages, id rules, kind rules, iso639_3. The 1,000+ per-deck "parses" loop and real-deck counts go (validator, release reader and one catalog test read every deck). |
| `fsrs_fit_test.dart` | 158 | merge into `scheduling_test.dart` | 6 | Gate, three fsrs-rs parity cases, deterministic, window, start, fitted set schedules differently. Per-case parameter loops go. |
| `fsrs_test.dart` | 15 | merge into `scheduling_test.dart` | 5 | py-fsrs sequences (one test, looped), grade mapping, better rating never shorter, miss is a lapse, first review next day, DST. |
| `gallery_test.dart` | 3 | delete | 0 | Debug-only gallery; the accessibility check builds each screen from it. |
| `gender_classes_test.dart` | 6 | delete | 0 | The validator checks gender classes. |
| `grammar_pattern_test.dart` | 6 | delete | 0 | Pins the es -ar deck's table; pattern expansion and the validator cover it. |
| `grammar_questions_test.dart` | 24 | merge into `lesson_and_review_test.dart` | 3 | Meaning question, form question, understood then produced, Grammar switch covers both, log replays. |
| `ipa_asks_test.dart` | 5 | delete | 0 | The IPA course test in languages_and_scripts covers production chosen, not typed. |
| `ipa_examples_test.dart` | 5 | delete | 0 | The validator checks IPA examples. |
| `leech_replay_test.dart` | 7 | merge into `scheduling_test.dart` | 2 | Reset restarts and keeps reviews; undo; set aside holds. |
| `lesson_test.dart` | 16 | merge into `lesson_and_review_test.dart` | 3 | Easy first, nine cards, teach-check-ask again, no voice falls back to choosing, grammar cell typed. |
| `log_jsonl_test.dart` | 16 | merge into `backup_and_restore_test.dart` | 2 | Log round trip, non-log or newer refused, fitted parameters kept, duplicate review merged once. |
| `meaning_rules_test.dart` | 12 | merge into `grading_test.dart` | 5 | Owner examples, rules 1-5 as cases, paraphrase stays wrong, typo after rules is a near miss. |
| `number_practice_test.dart` | 3 | merge into `lesson_and_review_test.dart` | 1 | Heard numbers answered in digits, shown in words; only asked skills. |
| `number_speller_test.dart` | 13 | merge into `lesson_and_review_test.dart` | 2 | Spelling follows each rules file (joined hundreds, form before more digits); malformed refused. |
| `pattern_expander_test.dart` | 7 | merge into `deck_format_test.dart` | 1 | Cell ids follow the documented scheme and are stable; a null form is skipped. The "30 cards" count goes. |
| `reading_parser_test.dart` | 12 | merge into `deck_format_test.dart` | 1 | A reading deck reads; bad answers or options refused. |
| `review_log_test.dart` | 7 | merge into `scheduling_test.dart` | 1 | States rebuilt from the log are the same; bad grade writes nothing. |
| `romanisation_test.dart` | 5 | delete | 0 | The romanised grading test reads the same file. |
| `rust_std_rng_test.dart` | 9 | delete | 0 | Bit-exact RNG is reached through the fsrs-rs parity cases, which fail if it drifts. |
| `script_skills_per_script_test.dart` | 19 | merge into `progress_test.dart` | 2 | Read/Write per script, half a review elsewhere, backup keeps the script, Progress shows each. |
| `script_skills_test.dart` | 13 | merge into `progress_test.dart` | 2 | Script-deck answers feed Read and Write; word decks feed none; own fit. |
| `self_grade_test.dart` | 7 | merge into `grading_test.dart` | 1 | Again/Hard/Good/Easy grades; Again on a new card due tomorrow. |
| `session_queue_reading_test.dart` | 6 | merge into `lesson_and_review_test.dart` | 1 | A passage is read before it is heard. |
| `session_queue_test.dart` | 24 | merge into `lesson_and_review_test.dart` | 4 | Due first, most overdue first; new-card cap; one mode per card; switched-off and voiceless modes never offered; revise all. |
| `set_cards_test.dart` | 22 | merge into `lesson_and_review_test.dart` | 3 | Set read from the layer, shown first in a lesson, known member marked, form taught once, aksharas never broken. |
| `skill_difficulty_test.dart` | 7 | delete | 0 | The Inspect test shows D per skill. |
| `skill_fit_test.dart` | 29 | merge into `scheduling_test.dart` | 3 | Window rule, keep a new set only if it predicts better, a good learner gets longer intervals, too little gives nothing, deterministic. |
| `skill_map_test.dart` | 8 | merge into `scheduling_test.dart` | 1 | Write and Say imply Recognition; a miss does not touch it. |
| `skill_parameters_test.dart` | 12 | merge into `scheduling_test.dart` | 1 | Which set schedules a skill; replay uses it. |
| `study_hours_test.dart` | 15 | merge into `progress_test.dart` | 1 | Hours spent capped per answer; hours left from reviews still needed. |
| `target_scripts_test.dart` | 5 | merge into `deck_format_test.dart` | 1 | A card keeps its second spelling; malformed refused. |
| `themes_test.dart` | 6 | delete | 0 | The validator checks themes; the catalog test reads them. |
| `core/backup/app_backup_test.dart` | 19 | merge into `backup_and_restore_test.dart` | 4 | Everything round-trips, newer format refused naming the maker, not-a-backup refused, damaged entry fails checksum, path that climbs out refused, old backup reads with defaults. |
| `core/data/shared_script_test.dart` | 5 | merge into `languages_and_scripts_test.dart` | 1 | A script read in another language counts as known. |
| `core/decks/deck_fetch_test.dart` | 9 | merge into `deck_downloads_test.dart` | 2 | Downloads from main; says why on rate limit, gone, offline; refuses an oversized file. |
| `core/decks/deck_index_test.dart` | 27 | merge into `deck_downloads_test.dart` | 3 | Refuses a path outside its language or a bad hash; a newer index asks for an app update; fetches changed files only; keeps a deck GitHub dropped. The "five of Hindi" and committed-index data checks go. |
| `core/decks/ipa_course_test.dart` | 7 | delete | 0 | The app IPA course test covers it. |
| `core/decks/language_catalog_test.dart` | 21 | merge into `progress_test.dart` | 2 | Completeness toward B1, stage Alpha/Beta/Complete, search by own name. |
| `core/decks/script_fonts_index_test.dart` | 8 | delete | 0 | The app script fonts test downloads and updates fonts. |
| `core/decks/sha256_test.dart` | 4 | delete | 0 | Library internals; hash-mismatch download tests cover it. |
| `core/feedback/report_test.dart` | 9 | delete | 0 | The report mail test sends a whole report. |
| `core/grading/iso_readings_test.dart` | 4 | merge into `grading_test.dart` | 1 | pālu and palu both right; a reading typed as people type it. |
| `core/grading/romanised_test.dart` | 5 | merge into `grading_test.dart` | 2 | Every spelling a learner may type is accepted; a romanised answer is exact, near or wrong. |
| `core/guide_layers_test.dart` | 6 | merge into `deck_format_test.dart` | 1 | A guide core merges with its layer; a layer without its core is broken. |
| `core/logs/log_entry_test.dart` | 10 | merge into `settings_test.dart` | 1 | The log keeps 7 days or 2,000 lines, whichever is fewer. |
| `core/markdown_subset_test.dart` | 26 | delete | 0 | The release notes page draws a real release body. |
| `core/release_check_test.dart` | 13 | merge into `app_update_test.dart` | 1 | Only a later version is newer; a release without an APK has nothing to install. |
| `core/release_notes_test.dart` | 20 | delete | 0 | The release notes page test covers it. |
| `core/review/checked_by_parse_test.dart` | 4 | delete | 0 | The review page's checked-by thanks test reads it. |
| `core/review/deck_review_test.dart` | 14 | merge into `reviewing_test.dart` | 2 | Right or suggested, never both; a change after sign-off takes it back; last send can be taken back once. |
| `core/review/proposal_parse_test.dart` | 5 | delete | 0 | The proposal card test reads proposals from a merged deck. |
| `core/review/rater_code_test.dart` | 8 | merge into `reviewing_test.dart` | 1 | A code reads loosely and its check catches a wrong symbol or a swap. |
| `core/review/review_pairs_test.dart` | 9 | merge into `reviewing_test.dart` | 1 | A pair is reviewable only when both languages and scripts are known. |
| `core/scheduling/ask_pin_test.dart` | 1 | delete | 0 | Golden of today's asks; breaks on every change to the asks, says nothing about behaviour. |
| `core/sound_contrasts_test.dart` | 12 | merge into `grading_test.dart` | 1 | A word heard with one sound changed names the contrast; nothing for another word. Bundled-file loads go. |
| `core/tts/system_tts_engine_test.dart` | 7 | merge into `voices_test.dart` | 1 | An error fails one word, not the next; a voice gone falls back to the language's. |
| `core/tts/voice_apps_test.dart` | 5 | delete | 0 | The voice apps page test reads the list. |
| `l10n/offline_claims_test.dart` | 1 | delete | 0 | Wording. |
| `tools/readme_gifs_test.dart` | 1 | delete | 0 | Makes README GIFs, tests nothing; becomes a tool run by hand (owner decision 4). |
| `live/github_downloads_test.dart` | 1 | keep | 1 | Real GitHub download; only CI's live step runs it. |
| `app/added_decks_test.dart` | 9 | merge into `deck_downloads_test.dart` | 1 | An added deck joins its unit; a refused file says why. |
| `app/app_log_test.dart` | 13 | merge into `settings_test.dart` | 1 | The log survives a restart; a failing store never stops the app. |
| `app/app_state_test.dart` | 23 | merge into `lesson_and_review_test.dart` | 3 | A fresh day teaches a lesson; taught words join reviews; listening only with a voice; switched-off skill left out; a profile sees its own languages. |
| `app/backups_test.dart` | 15 | merge into `backup_and_restore_test.dart` | 4 | A backup holds log, settings and reviewer; five kept, three from updates; restore keeps a copy first; a bad or newer file changes nothing. |
| `app/card_image_test.dart` | 6 | delete | 0 | Media download is covered by the recording test in voices. |
| `app/card_media_test.dart` | 9 | merge into `voices_test.dart` | 1 | A recording plays in place of the phone's voice; recordings download after the decks. |
| `app/database_progress_test.dart` | 9 | merge into `backup_and_restore_test.dart` | 2 | Answers survive a restart; a disagreeing state cache is repaired from the log; each profile its own file. |
| `app/deck_catalog_test.dart` | 27 | merge into `deck_format_test.dart` | 3 | Every deck the index lists parses (one test); a broken file is a row with its line; a second deck with the same id is reported; path order. |
| `app/deck_downloads_test.dart` | 42 | merge into `deck_downloads_test.dart` | 8 | Ready after first decks; rest behind it; offline/rate limit keep nothing; hash mismatch thrown away; cut short keeps whole decks; update keeps every card id; failed update leaves decks; proposals; stale index re-read; cancel; survives restart. |
| `app/downloaded_decks_test.dart` | 9 | merge into `deck_downloads_test.dart` | 1 | A download cut short leaves no file in use. |
| `app/engine_errors_test.dart` | 7 | merge into `voices_test.dart` | 1 | A listen that never answers fails with a timeout. |
| `app/features_test.dart` | 6 | delete | 0 | Feature registry internals. |
| `app/fitted_parameters_test.dart` | 9 | delete | 0 | The Adjust to me test reschedules after a fit. |
| `app/fsrs_tuner_test.dart` | 13 | merge into `scheduling_test.dart` | 2 | Adjust to me fits what it can and says so; waits with too little; script skills fitted apart. |
| `app/ipa_course_test.dart` | 15 | merge into `languages_and_scripts_test.dart` | 1 | The IPA course follows the languages learned; production is chosen, not typed. |
| `app/language_choice_test.dart` | 20 | merge into `languages_and_scripts_test.dart` | 2 | Languages offered in order; a language no longer learned falls back; quick revision revises the shown language. |
| `app/log_backup_test.dart` | 4 | merge into `backup_and_restore_test.dart` | 1 | Older history merged in takes its place in time. |
| `app/mail_share_test.dart` | 6 | merge into `settings_test.dart` | 1 | The share uses the channel brand_android.py writes. |
| `app/memory_progress_test.dart` | 14 | merge into `progress_test.dart` | 2 | Streak counts days ending today; survives DST; learned counts distinct cards. |
| `app/native_choice_test.dart` | 12 | merge into `languages_and_scripts_test.dart` | 2 | Asked once which language a course is taught from; a unit with no deck in it is Coming; changing it keeps progress. |
| `app/no_alphabet_test.dart` | 7 | merge into `languages_and_scripts_test.dart` | 1 | Without the alphabet, script decks are left out and words are typed in Latin letters. |
| `app/one_language_at_a_time_test.dart` | 4 | delete | 0 | A summary detail; the lesson flow test ends on the summary. |
| `app/ota_installer_test.dart` | 9 | merge into `app_update_test.dart` | 1 | A silent download fails after a minute; Cancel ends it. |
| `app/pacing_test.dart` | 6 | delete | 0 | Job-runner internals; How you learn tests cover what the learner sees. |
| `app/path_teaching_test.dart` | 10 | merge into `lesson_and_review_test.dart` | 3 | New words from the first two units; a placed unit is skipped; a finished unit passes; reviews from every deck. |
| `app/placement_test.dart` | 8 | merge into `languages_and_scripts_test.dart` | 2 | Two wrong ends placement; a beginner starts at unit 1; knowing all places the whole course. |
| `app/report_mail_test.dart` | 5 | merge into `settings_test.dart` | 1 | A report goes by share, else by mail link, else fails saying why. |
| `app/restore_log_test.dart` | 5 | merge into `backup_and_restore_test.dart` | 3 | A confirmed restore replaces both logs and logs a restores row; every other delete still refused; a failure part-way leaves both. |
| `app/reviewing_test.dart` | 9 | merge into `reviewing_test.dart` | 2 | A code is made once; reviews outlive a restart; several decks go in one mail and are marked sent only when it goes. |
| `app/script_fonts_test.dart` | 11 | merge into `deck_downloads_test.dart` | 2 | A course brings its font, checked; a font that fails its hash is thrown away. |
| `app/script_test_test.dart` | 6 | merge into `languages_and_scripts_test.dart` | 1 | A passed script test skips the script lessons; an own letter wrong fails. |
| `app/scripts_learned_test.dart` | 11 | merge into `languages_and_scripts_test.dart` | 1 | By default the primary script is learned; Perso-Arabic only shows right to left. |
| `app/sound_settings_test.dart` | 6 | merge into `voices_test.dart` | 1 | Sound off: nothing spoken, listening skipped. |
| `app/speaking_test.dart` | 17 | merge into `grading_test.dart` | 3 | Best reading right; another reading if the recogniser was sure; a near miss is wrong in speech; nothing heard records nothing. |
| `app/stored_settings_test.dart` | 8 | merge into `backup_and_restore_test.dart` | 1 | Every setting survives a restore; unreadable values keep a sensible setting. |
| `app/system_settings_test.dart` | 6 | delete | 0 | Platform-channel plumbing; the Voices page's Install test covers what the learner sees. |
| `app/update_backup_test.dart` | 6 | merge into `backup_and_restore_test.dart` | 1 | An update starts a backup with the download; a failed backup never blocks the update. |
| `app/update_checker_test.dart` | 33 | merge into `app_update_test.dart` | 5 | Checked at most once a day, off at first; newer found and kept; a failed check says why; the old APK is deleted after the update; nothing installs without a newer version. |
| `app/voice_backup_test.dart` | 6 | merge into `voices_test.dart` | 3 | With the Urdu voice missing the Hindi voice says the card; a card with no backup spelling is silent; neither voice, no backup. |
| `features/decks/card_bases_test.dart` | 6 | delete | 0 | Display of deck content; the validator checks bases. |
| `features/decks/card_facts_test.dart` | 11 | delete | 0 | Display of deck content; the daily fact test covers facts. |
| `features/decks/card_notes_test.dart` | 7 | delete | 0 | Display of deck content; taught details shows notes after the answer. |
| `features/decks/checked_by_line_test.dart` | 3 | delete | 0 | Wording. |
| `features/decks/course_hours_test.dart` | 4 | delete | 0 | Study hours keeps the arithmetic; the card is drawn by the per-screen check. |
| `features/decks/deck_content_test.dart` | 9 | merge into `progress_test.dart` | 1 | Search matches a deck, its language, theme or unit. |
| `features/decks/deck_detail_page_test.dart` | 12 | merge into `progress_test.dart` | 1 | A skill button starts that skill on the deck; chosen tags narrow Review all due. |
| `features/decks/deck_status_test.dart` | 8 | merge into `progress_test.dart` | 2 | Done once every card is learned in every skill on; a finished deck offers Revise, which records nothing. |
| `features/decks/decks_page_test.dart` | 21 | merge into `progress_test.dart` | 2 | The path opens at the unit up next; Where I am; a broken file shows its line; a failed catalog offers Try again. |
| `features/decks/import_page_test.dart` | 5 | delete | 0 | The added-decks test shows a refused file's reason. |
| `features/decks/inspect_page_test.dart` | 10 | merge into `progress_test.dart` | 1 | Inspect shows every card with its id and D per skill. |
| `features/decks/layout_test.dart` | 18 | delete | 0 | 2.0x and dark per state; the per-screen 1.4x check replaces it. |
| `features/decks/path_levels_test.dart` | 3 | delete | 0 | Folding a level is a view preference. |
| `features/decks/path_model_test.dart` | 10 | merge into `progress_test.dart` | 2 | Fresh course: unit 1 up next; learned units done; A1 reached once its units are. |
| `features/decks/path_plan_test.dart` | 6 | merge into `progress_test.dart` | 1 | A unit not yet written in this native language is Coming. |
| `features/decks/reading_deck_test.dart` | 3 | delete | 0 | The reading drill test covers reading decks. |
| `features/decks/unit_page_test.dart` | 19 | merge into `progress_test.dart` | 2 | Word status Known/Learning/New; Continue reviews due, else teaches, else off; Review needs reviewing on. |
| `features/decks/where_i_am_test.dart` | 7 | delete | 0 | The decks page test covers Where I am. |
| `features/decks/word_mastery_test.dart` | 4 | merge into `progress_test.dart` | 1 | Known is 85% of the last ten; old misses fall out. |
| `features/downloads/deck_downloads_flow_test.dart` | 28 | merge into `deck_downloads_test.dart` | 5 | First launch lists GitHub's languages and downloads one; offline and rate-limit messages; old bundled version downloads before opening; Languages on phone update/remove; daily check off; deck removed upstream stays. |
| `features/downloads/update_escape_test.dart` | 11 | merge into `deck_downloads_test.dart` | 1 | After repeated failures the app offers the update check; a language that downloads resets the count. |
| `features/drill/asked_drill_test.dart` | 10 | merge into `lesson_and_review_test.dart` | 3 | Choice right records 4, wrong records 1 and shows the answer; match by tap and drag; rearrange right and wrong. |
| `features/drill/cant_now_test.dart` | 15 | merge into `lesson_and_review_test.dart` | 2 | Pause for an hour skips listening; Turn off for one language only; a pause survives restart. |
| `features/drill/choice_order_test.dart` | 1 | delete | 0 | Shuffle internals. |
| `features/drill/contrast_feedback_test.dart` | 5 | merge into `grading_test.dart` | 1 | Feedback names the sound and what the word heard means. |
| `features/drill/curated_options_test.dart` | 1 | merge into `lesson_and_review_test.dart` | 1 | A card's confusables are its options. |
| `features/drill/drill_page_test.dart` | 35 | merge into `lesson_and_review_test.dart` | 5 | Recognition reveal and rate; production grades recorded on Check; near-miss judgement; listening at speech rate; empty queue; closing asks; right to left; number practice records nothing. |
| `features/drill/hear_test.dart` | 11 | merge into `lesson_and_review_test.dart` | 2 | A new word heard: meaning chosen; typed once remembered, accepting part of the meaning; script practice types what was heard. |
| `features/drill/input_mode_choice_test.dart` | 1 | delete | 0 | A tap-target size; the per-screen check covers it. |
| `features/drill/ipa_examples_test.dart` | 3 | delete | 0 | Display detail of the IPA course. |
| `features/drill/ipa_line_test.dart` | 21 | merge into `lesson_and_review_test.dart` | 1 | IPA shown on recognition from the start; never before the answer when listening. |
| `features/drill/keyboard_test.dart` | 4 | delete | 0 | Folded into the typed-production screen check, drawn with the keyboard open. |
| `features/drill/lesson_flow_test.dart` | 4 | merge into `lesson_and_review_test.dart` | 2 | Today offers the lesson; it teaches then asks; Start review asks taught words in other skills. |
| `features/drill/match_tap_to_hear_test.dart` | 18 | merge into `voices_test.dart` | 1 | A word tile speaks when tapped, unless off; sound off greys the button and says why. |
| `features/drill/near_miss_test.dart` | 2 | merge into `grading_test.dart` | 1 | A slip that is another cell is wrong, not near. |
| `features/drill/picture_test.dart` | 7 | delete | 0 | Display of a picture; the per-screen check draws it. |
| `features/drill/quick_revision_test.dart` | 8 | merge into `lesson_and_review_test.dart` | 1 | Revises N known words once each; every answer is recorded. |
| `features/drill/raise_volume_test.dart` | 7 | merge into `voices_test.dart` | 1 | A heard question asks for volume while the phone is muted. |
| `features/drill/reading_drill_test.dart` | 39 | merge into `lesson_and_review_test.dart` | 3 | Passage then questions; a choice is recorded at once; heard passage hides its text; glossary. Per-theme/scale repeats go. |
| `features/drill/scripts_drill_test.dart` | 4 | merge into `languages_and_scripts_test.dart` | 1 | A card shows in the script learned; Write offers one option per script learned. |
| `features/drill/set_drill_test.dart` | 9 | merge into `lesson_and_review_test.dart` | 1 | The set comes first; a split set shows its parts. |
| `features/drill/sounds_of_word_test.dart` | 5 | delete | 0 | An entry point to the IPA course; its course test stays. |
| `features/drill/speaker_test.dart` | 22 | merge into `voices_test.dart` | 2 | Tap plays the word; no speaker without a voice; words never play before the answer where they would give it away. |
| `features/drill/speaking_drill_test.dart` | 12 | merge into `lesson_and_review_test.dart` | 2 | Heard right says so; wrong says what was heard; nothing heard asks again and records nothing. |
| `features/drill/speaking_retry_test.dart` | 23 | merge into `lesson_and_review_test.dart` | 2 | A wrong answer offers a try again; only a failed first answer brings the word back; Hear yourself plays the recording. |
| `features/drill/taught_details_test.dart` | 78 | merge into `lesson_and_review_test.dart` | 1 | After the answer, a reviewed word shows its note and example. Theme and scale repeats go. |
| `features/drill/translit_test.dart` | 8 | merge into `grading_test.dart` | 2 | Before script units the reading counts in full, after it is hard recall; the script is always accepted. |
| `features/drill_b4/grammar_drill_test.dart` | 11 | merge into `lesson_and_review_test.dart` | 2 | Asks a cell; wrong shows the table with the cell marked; a session card is graded and recorded. |
| `features/drill_b4/pair_drill_test.dart` | 9 | merge into `lesson_and_review_test.dart` | 1 | Play speaks the sound asked; choosing says right or what it was. |
| `features/grammar_understood_display_test.dart` | 8 | delete | 0 | Naming; grammar_questions keeps the behaviour. |
| `features/onboarding/onboarding_flow_test.dart` | 18 | merge into `onboarding_test.dart` | 4 | Tour walk, Skip, Back as Android back, a double tap cannot skip, the tour claims only what ships, right to left mirrors. |
| `features/onboarding/sound_check_test.dart` | 14 | merge into `onboarding_test.dart` | 3 | Mic asked only on Record; heard turns speaking and listening on; refused or silent keeps speaking off; playback failing turns listening off. |
| `features/placement/ipa_entries_test.dart` | 5 | merge into `languages_and_scripts_test.dart` | 1 | Choosing the IPA entry makes it learned. |
| `features/placement/language_picker_page_test.dart` | 33 | merge into `languages_and_scripts_test.dart` | 5 | Search by name, own name, code; Learning first; learning goes in steps; stopping stops its download; download bar, Cancel before and after first decks; failure and Try again. |
| `features/placement/languages_learning_fixes_test.dart` | 4 | merge into `languages_and_scripts_test.dart` | 1 | A spoken language goes through placement when asked; starting at the beginning places nothing. |
| `features/placement/native_choice_test.dart` | 7 | merge into `languages_and_scripts_test.dart` | 1 | The taught-from choice on the card and in placement. |
| `features/placement/placement_flow_test.dart` | 14 | merge into `languages_and_scripts_test.dart` | 3 | First launch asks what to learn; Find my level places units; Stop here keeps them; leaving saves nothing; two languages in turn. |
| `features/placement/script_switch_test.dart` | 6 | merge into `languages_and_scripts_test.dart` | 1 | Adding Perso-Arabic and stopping Devanagari saves both. |
| `features/placement/script_test_offer_test.dart` | 12 | merge into `languages_and_scripts_test.dart` | 1 | A Bengali reader choosing Assamese is offered the script test; passed skips the script lessons. |
| `features/profiles/layout_test.dart` | 13 | delete | 0 | 2.0x per state. |
| `features/profiles/new_profile_page_test.dart` | 5 | delete | 0 | Profiles are incoming; the PIN test stays. |
| `features/profiles/pin_page_test.dart` | 6 | merge into `settings_test.dart` | 1 | The right PIN opens; a wrong one opens nothing. |
| `features/profiles/profiles_page_test.dart` | 5 | delete | 0 | Profiles are incoming; the PIN test stays. |
| `features/profiles/spoken_languages_page_test.dart` | 52 | merge into `onboarding_test.dart` | 3 | Languages you know: search by English or own name, the sheet asks in the language, Save keeps the order, several scripts asked, old saves read. assets/languages.yaml data checks go. |
| `features/report/report_log_test.dart` | 9 | merge into `settings_test.dart` | 1 | Ticked, the whole log goes as a file; unticked, none. |
| `features/report/report_page_test.dart` | 11 | merge into `settings_test.dart` | 1 | A report needs a title and goes to the mail app; no mail app says why. |
| `features/review/alike_warning_test.dart` | 5 | merge into `reviewing_test.dart` | 1 | The look-alike warning comes after the answer, never before; names the rude word only with adult content on. |
| `features/review/base_change_test.dart` | 8 | merge into `reviewing_test.dart` | 1 | A base deleted, added or replaced is saved as a suggestion. |
| `features/review/base_suggestion_test.dart` | 4 | delete | 0 | The base change test covers suggestions on bases. |
| `features/review/how_reviewing_works_test.dart` | 8 | merge into `reviewing_test.dart` | 1 | The app's agreement count matches the review bot's. |
| `features/review/offensive_review_test.dart` | 17 | merge into `reviewing_test.dart` | 2 | Asks every time, shows no word first; regions from the path; a deck of offensive words signs off. |
| `features/review/proposal_card_test.dart` | 6 | merge into `reviewing_test.dart` | 1 | Accept and Reject a proposal; Edit opens Suggest a change. |
| `features/review/review_languages_page_test.dart` | 5 | delete | 0 | Eligibility is kept in review pairs. |
| `features/review/review_page_test.dart` | 14 | merge into `reviewing_test.dart` | 3 | Check marks a card; Suggest a change; offensive words never in a unit; Sign off then Send review. |
| `features/review/review_settings_test.dart` | 7 | merge into `reviewing_test.dart` | 1 | Send the last mail again puts its decks back. |
| `features/review/suggest_sheet_test.dart` | 6 | merge into `reviewing_test.dart` | 1 | Two parts edited save both; the cross discards. |
| `features/review/waiting_reviews_test.dart` | 22 | merge into `reviewing_test.dart` | 2 | A sent suggestion reads waiting, accepted or rejected from the deck files; once sent nothing is left unsent. |
| `features/review/waiting_test.dart` | 17 | merge into `reviewing_test.dart` | 2 | What waits per language; fewer as checked; offensive words never counted. |
| `features/script/hindi_guide_test.dart` | 1 | delete | 0 | Per-language data; the validator checks the guide. |
| `features/script/script_guide_test.dart` | 11 | merge into `lesson_and_review_test.dart` | 1 | A guide is shown once before the first script card; Tips opens it. |
| `features/script/script_per_script_test.dart` | 6 | merge into `languages_and_scripts_test.dart` | 1 | The drill shows the guide of the deck's script. |
| `features/script/telugu_guide_test.dart` | 1 | delete | 0 | Per-language data; the validator checks the guide. |
| `features/settings/adjust_section_test.dart` | 5 | merge into `scheduling_test.dart` | 1 | Adjust waits with too few answers, then shows what changed per skill. |
| `features/settings/adult_content_test.dart` | 4 | merge into `settings_test.dart` | 1 | Off by default; switching on asks once. |
| `features/settings/appearance_page_test.dart` | 6 | merge into `settings_test.dart` | 1 | A colour and high contrast theme the whole app. |
| `features/settings/backup_section_test.dart` | 17 | merge into `backup_and_restore_test.dart` | 2 | Back up now saves where chosen; restore shows what it holds first and keeps a copy; a failed restore leaves the app as it was. |
| `features/settings/layout_test.dart` | 96 | delete | 0 | 96 tests of 2.0x and gallery states; the per-screen 1.4x check replaces it. |
| `features/settings/logs_section_test.dart` | 11 | merge into `settings_test.dart` | 1 | Export saves the log; Clear asks first. |
| `features/settings/release_notes_page_test.dart` | 26 | merge into `app_update_test.dart` | 2 | Asks GitHub only when opened; lists releases and marks this one; offline offers Try again. |
| `features/settings/section_pages_test.dart` | 24 | merge into `settings_test.dart` | 2 | A skill switch turns its skill off; speech rate reaches the voice; Import merges a log and says how many; Export the log. |
| `features/settings/settings_page_test.dart` | 53 | merge into `settings_test.dart` | 1 | Every row opens its page; the version shown is pubspec's. |
| `features/settings/sources_page_test.dart` | 10 | delete | 0 | Credits are content; the validator checks sources. |
| `features/settings/switch_lines_test.dart` | 13 | delete | 0 | Wording of each switch's line. |
| `features/settings/update_backup_row_test.dart` | 4 | delete | 0 | Wording. |
| `features/settings/update_section_test.dart` | 14 | merge into `app_update_test.dart` | 2 | Check, newer, Download, install failure says why with Try again. |
| `features/settings/voice_apps_page_test.dart` | 3 | merge into `voices_test.dart` | 1 | A course lists its voices and the backup, and suggests an app. |
| `features/settings/voice_cards_test.dart` | 18 | merge into `voices_test.dart` | 2 | A card per language; a removed voice falls back; a rude word is never offered or played. |
| `features/settings/voices_page_test.dart` | 13 | merge into `voices_test.dart` | 1 | Languages learned first; Test speaks a real card; Install opens the phone or explains. |
| `features/stats/how_you_learn_page_test.dart` | 12 | merge into `progress_test.dart` | 1 | Before a fit says what will happen; after, slower or faster per skill. |
| `features/stats/layout_test.dart` | 20 | delete | 0 | 2.0x per state. |
| `features/stats/leeches_page_test.dart` | 4 | merge into `progress_test.dart` | 1 | Reset, Undo, Set aside append, never delete. |
| `features/stats/script_skills_page_test.dart` | 10 | delete | 0 | Script skills per script covers Progress. |
| `features/stats/stats_numbers_test.dart` | 13 | merge into `progress_test.dart` | 3 | 7/30/all-time numbers; a card in two decks learned once; per-language streak; leeches from the states. |
| `features/stats/stats_page_test.dart` | 15 | merge into `progress_test.dart` | 2 | Numbers from the log follow the range; empty says so; All counts every language. |
| `features/summary/summary_page_test.dart` | 11 | merge into `lesson_and_review_test.dart` | 1 | Totals and scores from the session; Done returns to Today. |
| `features/today/layout_test.dart` | 18 | delete | 0 | 2.0x per state. |
| `features/today/pace_test.dart` | 27 | merge into `progress_test.dart` | 1 | Before a fit no strip; after a fit the skill is marked slower or faster. |
| `features/today/skill_tiles_test.dart` | 5 | delete | 0 | Tile layout. |
| `features/today/today_page_test.dart` | 23 | merge into `lesson_and_review_test.dart` | 3 | Due count from the session; Start review; Quick revision; a tile reviews its skill; all done. |
| `ui/bottom_actions_test.dart` | 1 | delete | 0 | The per-screen check covers the three-button bar. |
| `ui/card_text_scale_test.dart` | 11 | delete | 0 | The 1.4x cap test in accessibility covers card text. |
| `ui/drill_fit_test.dart` | 3 | delete | 0 | Layout internals. |
| `ui/incoming_test.dart` | 8 | merge into `settings_test.dart` | 1 | An incoming feature is dimmed, badged and does nothing (ADR-0008). |
| `ui/language_bar_test.dart` | 36 | merge into `languages_and_scripts_test.dart` | 1 | A swipe or a tap on the bar switches language; All only on Progress. |
| `ui/nav_bar_decks_fabs_test.dart` | 2 | delete | 0 | The per-screen check covers it. |
| `ui/nav_bar_labels_test.dart` | 2 | delete | 0 | The per-screen check covers it. |
| `ui/nav_bar_screens_large_text_test.dart` | 1 | delete | 0 | 2.0x. |
| `ui/nav_bar_screens_test.dart` | 1 | delete | 0 | The per-screen check covers the three-button bar. |
| `ui/nav_bar_sheets_test.dart` | 43 | delete | 0 | Sheets are screens in the per-screen check. |
| `ui/system_bar_test.dart` | 2 | delete | 0 | The per-screen check covers it. |
| `ui/target_text_font_test.dart` | 4 | merge into `deck_downloads_test.dart` | 1 | A downloaded script font draws TargetText. |
| `ui/text_scale_cap_test.dart` | 2 | delete | 0 | Folded into accessibility's "a phone at 2x is drawn at 1.4x". |
| `ui/theme_test.dart` | 3 | delete | 0 | Contrast is checked per screen. |
| `ui/toast_test.dart` | 6 | merge into `accessibility_test.dart` | 1 | A toast is a live region a screen reader hears. |
| `ui/widgets_test.dart` | 12 | delete | 0 | Folded into accessibility's deck-text-language test. |

## Per-file table: Python

Paths are under `tools/`. Before counts `def test_` lines.

| File | Before | Decision | After | Why |
|---|---:|---|---:|---|
| `test_validate_decks.py` | 12 | keep | 4 | The index check: current passes, stale/missing fails, one deck alone skips it, a language needs a path. |
| `test_validate_content.py` | 62 | merge into `test_validate_decks.py` | 6 | iso639_3 required; id leads with both languages; facts: 30 needed, contrast facts in their language; themes exist and are used once; unknown script warns. Field-by-field shape cases go. |
| `test_validate_deck_parity.py` | 18 | merge into `test_validate_decks.py` | 2 | Duplicate and merge keys refused; YAML 1.2 plain scalars typed as the app types them (booleans, numbers, null, text). |
| `test_validate_card_ids.py` | 14 | keep | 4 | A card is written once; a ref names a written card; a pair is another card; a file alone is held to the repository; --next-id follows the highest. |
| `test_validate_b1.py` | 158 | keep | 12 | Dispatch, core header and cards, layer gives every text, refs through layers, grammar and rules cores, units and words planned, the fixture validates. Restatements per field go. |
| `test_validate_paths.py` | 17 | merge into `test_validate_b1.py` | 3 | A path lists every deck by core id; wildcards; one path per language; a per-course path refused with what to do. |
| `test_validate_sets.py` | 26 | merge into `test_validate_b1.py` | 3 | A set by refs is valid; two members or more; a rule set names a real row and slot; the rules core is unchanged. |
| `test_validate_card_data.py` | 40 | keep | 5 | Own root, word items, confusables never a tile the answer needs, frequency, register, forms, senses, Wiktionary source shape. |
| `test_validate_examples.py` | 9 | merge into `test_validate_card_data.py` | 1 | A layer gives no source; a filled-in language needs two examples per word card. |
| `test_validate_gender.py` | 12 | merge into `test_validate_card_data.py` | 1 | A noun outside the path's classes is an error; a missing gender once filled in. The "every path lists the decided classes" data check goes. |
| `test_validate_ipa.py` | 8 | merge into `test_validate_card_data.py` | 1 | Example language and sounds flag; bracketed IPA only for the IPA course. |
| `test_validate_iso.py` | 7 | merge into `test_validate_card_data.py` | 2 | ISO 15919 is the one standard; typed pairs are ISO letters. |
| `test_validate_media.py` | 17 | merge into `test_validate_card_data.py` | 2 | A recording or image needs its file and a shippable credit; never in a layer; a file no card names. |
| `test_validate_pictures.py` | 4 | merge into `test_validate_card_data.py` | 1 | A picture is an emoji named as the app names it. |
| `test_validate_reading.py` | 17 | merge into `test_validate_card_data.py` | 2 | A reading deck is valid; a glossed word occurs letter for letter; untaught words warn, never fail. |
| `test_validate_romanisation.py` | 6 | merge into `test_validate_card_data.py` | 1 | The file is valid; every reading is in the scheme. |
| `test_validate_script.py` | 12 | merge into `test_validate_card_data.py` | 1 | A guide's id follows language and folder; another script's guide is named for it. |
| `test_validate_sounds.py` | 5 | delete | 0 | Minimal-pair files are read by the app's contrast test; shape errors fail there. |
| `test_validate_target_scripts.py` | 17 | merge into `test_validate_card_data.py` | 1 | The key is another script of the language; letters in that script's blocks; differs from target. |
| `test_deck_index.py` | 29 | keep | 5 | Lists languages and files; media and fonts apart; hidden or unwritten languages left out; content hash leaves proposals out; --check says if current; the README badge follows the count. |
| `test_check_release_version.py` | 13 | keep | 4 | Match, mismatch says what to bump, build number dropped, not a version tag, exit codes. |
| `test_prepare_release.py` | 6 | keep | 3 | Bumps both version files, moves the CHANGELOG body, refuses an empty or not-higher release. |
| `test_review_bot.py` | 52 | keep | 6 | A review becomes one PR merged when checks pass; failed checks left open; never reopens a closed PR; agreement applies and closes rivals; fewer wait; owner's revert never re-applied; outdated closed. |
| `test_proposals.py` | 30 | keep | 3 | A proposal is one line on its card; outdated when the field changed; applying closes rivals; layer meaning goes in the layer; validation of a good and a bad proposal. |
| `test_base_proposals.py` | 22 | keep | 2 | Base add, change, remove round trip; an agreed change closes rivals on its base only. |
| `test_checked_by.py` | 26 | keep | 3 | A sign-off is written once; a layer review checks the core; every card checked tags the deck reviewed; checked_by leaves the content hash alone. |
| `test_mail_to_issues.py` | 56 | keep | 3 | A report becomes a labelled issue; support stays private however written; the sender never appears; a review mail names only code and languages; filed once. |
| `test_brand_android.py` | 38 | keep | 2 | Running twice is running once; mic, TTS, internet and the share provider are declared; another shape is an error that changes nothing. |
| `test_import_wiktionary.py` | 51 | keep | 3 | Without --write nothing changes; files still validate; a meaning never changes; a second run adds nothing; a licence that cannot ship is skipped; approvals pin the file. |
| `test_split_deck.py` | 16 | keep | 2 | A split keeps every id and text; a reading deck is not split; the files validate. |
| `test_transcribe.py` | 13 | keep | 2 | Length and retroflex marked; Bengali inherent vowel; a hint that does not fit says so. |
| `test_wikipedia_frequency.py` | 15 | keep | 1 | Ranks written with their source; without --write nothing changes. |
| `test_check_ui_strings.py` | 8 | keep | 2 | A literal is caught (same line and split); an allowed literal passes. |
| `test_ipa_course.py` | 3 | keep | 1 | Ids are kept; every symbol has examples of both kinds. |
| `test_make_gif.py` | 5 | delete | 0 | README GIF maker; no learner or author behaviour. |
| `release_reader/release_reader_test.dart` | 1 | keep | 1 | The released app reads today's decks (its own CI job). |
