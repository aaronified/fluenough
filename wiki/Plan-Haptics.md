# Plan: haptic feedback, one vocabulary for the whole app

Source of truth: this wiki page.

Written 2026-11-02. A plan and a mockup only: no app code is written by it. The mockup of the Settings switch is `docs/mockups/haptics-settings.html` on the branch `mockup/haptics-settings`, with its notes and self-check in `haptics-settings.md` beside it. The owner wants this in the next release.

## What the owner asked

> Also, all buttons should give haptic feedback, including cycling the pills. Use different feedbacks for each pill value (the language skill pills). And different for every type of action. Plan this well, must be logical and consistent and easy to follow for further UI development. A button in the UI settings section will turn on or off haptic feedback.
>
> Also standardize the existing haptics under this plan.

(owner, 2026-11-02)

## Summary

- Today the app has **one** deliberate haptic (a tick for each language the language bar passes, `language_bar.dart:273`) and a pile of **accidental** ones: Flutter's Material widgets play a click sound on Android taps and `HapticFeedback.vibrate()` on every long press (`Feedback.forTap`, `Feedback.forLongPress`), by default, with no way for a learner to turn it off. Nothing is consistent and nothing is switchable.
- The plan: **seven feels**, built only from Flutter's built-in `HapticFeedback` (no plugin), named by **meaning** (`tap`, `select`, `toggle`, `confirm`, `danger`, `success`, `error`, `pill`, ...). Code says what happened; one file says how it feels.
- One `Haptics` service, owned by `AppState` like every other service (ADR-0007), gated by one setting, with a recording test double.
- A button gets its haptic **by being the app's button**: `AppFilledButton`, `AppTextButton`, `AppIconButton`, `AppInkWell` and the shared tiles carry it. A test fails the build on a raw Material button or a direct `HapticFeedback` call.
- Settings: **Look and language**, one switch row, **"Vibrate on touch"**, on by default.
- One pull request, about 140 files, most of them a mechanical rename (step 5).

## What exists

### Deliberate haptics (every one)

`grep -rn "HapticFeedback\|haptic" lib test`, which found three lines and no other use:

| File:line | What it is | Action it serves |
|---|---|---|
| `lib/ui/widgets/language_bar.dart:273` | `HapticFeedback.selectionClick()` in `_setPos` | The language wheel crosses a detent, in a drag and in a fling. |
| `lib/ui/widgets/language_bar.dart:94` | A doc comment naming that call | Documentation of the same. |
| `test/languages_and_scripts_test.dart:2749` and `:2768` | Mocks `SystemChannels.platform`, expects three `HapticFeedbackType.selectionClick` | The test of the detent tick. |

### Accidental haptics and sounds (Flutter's own, switch-less)

Every Material tappable (`InkWell`, `InkResponse`, `TextButton`, `FilledButton`, `OutlinedButton`, `IconButton`, `ListTile`, chips, `Switch`, `Checkbox`) has `enableFeedback` true by default. On Android a tap plays the system click sound (if the phone's touch sounds are on) and a long press calls `HapticFeedback.vibrate()`. The app never sets `enableFeedback`, so:

| File:line | What | Today |
|---|---|---|
| `lib/ui/widgets/hint.dart:32`, `lib/ui/theme.dart:101` | `Tooltip` with `TooltipTriggerMode.longPress` (every icon-only button's tooltip and every pill's long press) | Android long press: `vibrate()`. No setting. |
| `lib/ui/widgets/speaker.dart:125,172,180`, `lib/ui/widgets/play_button.dart:72,97` | `onLongPress` (slow speech) | The same implicit `vibrate()`. |
| `lib/features/today/daily_card.dart:403` | `onLongPress` repeating a stepper | The same, on each repeat. |
| 306 button sites in 110 files, 59 `InkWell`, 25 list tiles, 16 chips, 5 switches and checkboxes | Every tap | Android click sound; none on iOS. |

These are what "standardize the existing haptics" has to reach: the plan turns Flutter's feedback off (`enableFeedback: false`) in the app's own widgets and the theme, and replaces it by the one vocabulary below. The Android click sound goes with it (see Risks).

### What has no haptic and needs one

The skill pills (`SkillBadge`, `lib/features/languages/skill_widgets.dart`; cycled in `language_skills_sheet.dart`), the answer verdict (`lib/features/drill/answer_feedback.dart`), the session summary, backups and restores, the PIN keypad (`lib/features/profiles/pin_page.dart:242`), destructive confirmations, switches, segmented controls, tab swipes, and the slider's steps.

## Principles

1. **Meaning, not hardware.** Call sites say `confirm`, never `heavyImpact`.
2. **Intensity rises with consequence.** Light tick, then tap, then press, then thud. A destructive action is the heaviest single pulse the app has.
3. **Rhythm survives, intensity may not.** The cheapest Android actuators play every impact the same. Only the number and spacing of pulses always reaches the finger, so success and error differ by rhythm first and by intensity second.
4. **One gesture, one haptic.** A control whose outcome has its own haptic (an answer, a save that can fail) is silent itself (`haptic: Haptic.none`), and the outcome speaks when it is known.
5. **Quiet when right.** A correct answer is the lightest touch. Being right is not rewarded with a buzz every three seconds; the one reward is finishing a session.
6. **Only for what the learner just did.** Haptics answer a touch, or a result the learner is waiting for on screen. Never for a background event (a download finishing, a reminder, an update).
7. **Never the only cue.** Every haptic duplicates something visible (a colour, an icon, a line of text). Nothing is communicated by touch alone.

## 1. The vocabulary

### The seven feels

Only Flutter's built-in `HapticFeedback`. Two feels are a sequence of two built-in calls with a pause; each is defined once, in `SystemHapticEngine`.

| Feel | Built-in call | Reads as |
|---|---|---|
| tick | `selectionClick()` | A detent. Lightest. |
| tap | `lightImpact()` | A finger touched something. |
| press | `mediumImpact()` | A firm press, a thing engaged. |
| thud | `heavyImpact()` | A heavy stamp. Consequence. |
| buzz | `vibrate()` | The platform's own long-press feel. |
| rise | `lightImpact()`, 70 ms, `mediumImpact()` | A quick double, climbing: it worked. |
| knock | `mediumImpact()`, 160 ms, `mediumImpact()` | A slow double, level: no. |

Rise and knock are the only sequences. The second pulse is dropped if haptics are switched off in the gap.

### The semantic actions

One method on `Haptics` for each, one feel for each. Several actions share a feel where they never happen at the same moment and cannot be confused by context (a press on a button and a caution sheet opening are not the same instant).

| Action | Method | Feel | When | Why this feel |
|---|---|---|---|---|
| Tap, press | `tap()` | tap | Any button, row, icon button, chip that does something. The default. | The baseline everything else is measured against. |
| Selection | `select()` | tick | Picking one of several: segmented control, choice tile, radio, filter chip, tab change, page snap, wheel detent, slider step, stepper step. | A pick is lighter than a press: nothing is committed. |
| Switch on | `toggle(true)` | press | A switch, checkbox or star turns on. | Engaging is firmer than disengaging. |
| Switch off | `toggle(false)` | tap | The same, turning off. | The pair is felt as on/off. |
| Pill value | `pill(mark)` | see section 2 | A skill pill lands on a value. | One feel per value. |
| Confirm | `confirm()` | press | A button that completes the task: Start, Check, Done, Save, Send, Continue, the four rating buttons. By default every `AppFilledButton`. | Primary actions deserve more than a tap. |
| Danger | `danger()` | thud | A destructive action is confirmed: Delete this profile, Delete data, Restore over current progress. By default `AppFilledButton.danger`. | The heaviest pulse the app has, and rare. |
| Warning | `warning()` | press | A caution appears (the age question, "this replaces your progress" sheet), or a tap is refused (a feature that is incoming). | Firm but not final. Fires on appearance, so it never meets a button press. |
| Success | `success()` | rise | A thing the learner was waiting for finished: session complete, backup made, restore done, a level verified. | Climbing double. The one reward. |
| Error | `error()` | knock | A thing failed or was refused: the wrong PIN, a deck that fails its check, a restore that cannot read the file. | Level slow double. Cannot be mistaken for rise, on any actuator. |
| Correct answer | `correct()` | tap | The drill grades an answer right. | Quiet when right (principle 5). |
| Wrong answer | `wrong()` | knock | The drill grades an answer wrong. | The same knock as an error: the learner learns one "no". |
| Long press | `longPress()` | buzz | A long press is recognised: a pill's or icon's tooltip, the speaker's slow speech. | It is Flutter's own long-press feel on Android today, now behind the switch. |
| Drag start | `dragStart()` | press | The start of a drag that picks something up (none today; for reorder). | Picked up. |
| Drop | `drop()` | tap | The drop. | Put down. |
| None | `Haptic.none` | none | A control whose outcome speaks (principle 4). | |

Not given a haptic, on purpose:

- **Text entry, the keyboard.** The phone's keyboard has its own. The braille keyboard's keys are ordinary buttons (tap).
- **Back and the system back gesture.** Android and iOS do their own. The AppBar's back arrow is Flutter's `BackButton`, not the app's: it is left out of v1 (open question 5).
- **Disabled controls.** Nothing happened, so nothing is felt.
- **Scrolling, a snackbar appearing, a dialog opening** (except a caution: `warning`).
- **Background events** (principle 6).

### Intensity ladder

```
tick  <  tap  <  press  <  thud            single pulses, rising consequence
buzz                                       the platform's long press
rise (light-medium, quick)                 success
knock (medium-medium, slow)                error
```

### Throttle: repeated actions do not buzz excessively

`Haptics` drops any call that arrives less than **50 ms** after the previous one started (at most 20 a second), and any call that arrives while a rise or knock is still playing. This covers a fast fling of the language wheel (today uncapped), a braille chord, a long-press repeat on a stepper, and a pop that follows a button press in the same frame. A caller never counts.

### Platform limits, honestly

- **Android.** Flutter's `HapticFeedback` goes through `View.performHapticFeedback`, which the phone's own "Touch feedback" / "Vibrate on touch" setting turns off, and battery saver and Do Not Disturb can suppress. Flutter cannot read that setting, so the app cannot show it; if it is off, nothing buzzes whatever our switch says. Which Android constant each built-in call uses differs between Flutter versions and phones, and cheap actuators play all impacts alike (principle 3). To be checked on a device before release: each of the seven feels, on a Pixel and on one low-end phone.
- **iOS.** `lightImpact`, `mediumImpact`, `heavyImpact` and `selectionClick` use the Taptic Engine and are off when the phone's System Haptics are off; iOS also suppresses them while the microphone is recording (the speaking drill). `vibrate()` is a plain buzz, not a haptic. Flutter exposes no iOS "notification" feedback (success, warning, error), which is why success and error are sequences. The iOS folder is not generated yet (AGENTS.md), so none of this has been tried.
- **Web, desktop.** `HapticFeedback` does nothing. The switch is **hidden** where the engine says it is unavailable (`HapticEngine.available`), so the app never shows a setting that does nothing.
- **Accessibility.** (a) The switch is the learner's way out, for sensory sensitivity or a phone that buzzes too hard. (b) Principle 7: nothing is touch-only. (c) TalkBack and VoiceOver vibrate on activation themselves. With a screen reader on (`MediaQuery.accessibleNavigation`), the plan keeps `tap`, `select`, `toggle` and `confirm` silent, because the reader already speaks for them, and keeps `danger`, `warning`, `success`, `error`, `correct`, `wrong` and the pills, which carry meaning the reader does not. To be checked with TalkBack (open question 4). (d) The switch row itself is an ordinary labelled switch; its on and off lines are read by the screen reader like every other.

## 2. The skill pills

The approved pill design (`pillColors` in `skill_widgets.dart`, owner 2026-11-01): **Leave** red with a dashed outline and the block icon; **Learn** light yellow with a ring and the cap; **Know** yellow with the ticked circle (both levels, "Read" and "Read and Write", "Hear" and "Hear and Speak", look the same colour); **Learnt** dark green with the double tick, the Know level when placement verified it.

| Pill value | Feel | Method | Why |
|---|---|---|---|
| Leave | tick | `pill(leave)` | Stepping out: the lightest touch, a let-go. |
| Learn | tap | `pill(learn)` | Starting. |
| Know | press | `pill(know)` | Claiming. Both levels of Know (Read, Read and Write; Hear, Hear and Speak) share it because they share a colour and a meaning; the second skill's icon appearing is the difference the eye sees. |
| Learnt | rise | `pill(learnt)` | Earned, so it feels like success: the same rise as `success()`. |

Rules:

1. **The feel is the mark the pill now draws.** `Haptics.pill(SkillMark)` takes the mark (`SkillMark.leave | learn | know | knowBoth | knowCovered | knowBothCovered`) and maps the two covered marks to `learnt`. What the learner feels is what the learner sees.
2. **It fires when the pill lands**, after the change is applied, not when the finger goes down: in `_change` (`language_skills_sheet.dart`, after `setState`). `SkillBadge` itself is silent (`AppInkWell(haptic: Haptic.none)`).
3. **Cycling order is unchanged**: Leave, Learn, Know, Leave on a skill; Leave, Learn, Read, Read and Write, Leave on a script; Leave, Learn, Hear, Hear and Speak, Leave on Spoken (`lib/core/languages/language_skills.dart:119-195`). Learn is skipped where the language has no decks to learn, so the feels go Leave tick, Know press.
4. **Learnt cannot be chosen.** No tap targets it. The code draws Learnt when the pill is at Know **and** the placement level covers it (`covered` in the sheet), so cycling onto a Know that placement already verified lands on a pill drawn as Learnt, and rule 1 gives it the rise. This is how the code behaves today; the plan keeps it.
5. **The end of the cycle** wraps: from the top level (Know, or Read and Write, or Hear and Speak, or Learnt) the next tap goes to Leave and feels the tick. There is no end-stop bump: the lightest feel after the heaviest is the "let go".
6. **A placement result that newly verifies a level** (a pill turning Learnt without a tap) fires `success()` once, which is the same rise, when its result is shown. Not for a pill changed in the background.
7. **A tap that is cancelled gives nothing.** Choosing Learn the first time asks to confirm a download (`_confirmDownload`); the pill only changes, and only buzzes, after "Download". Cancel is silent.
8. **A locked pill** (`_locked`, no `onTap`) and the read-only chips on the Languages list are silent. A pill's **long press** gives `longPress` (its tooltip), as every tooltip does.
9. **All skills reach Leave**: the sheet closes after the change. The Leave tick is the only haptic; the pop is absorbed by the throttle.

On a low-end phone the single pulses may feel alike (principle 3). The pill's colour, icon and the toast ("Hindi: Spoken, learning") stay the real cue; the haptic is the second channel. Learnt, a double, always stands out.

## 3. API design

### Layers (AGENTS.md rule 3, ADR-0007)

| File | Holds | Imports Flutter? |
|---|---|---|
| `lib/core/haptics/haptic.dart` | `enum Haptic` (every action in the table, plus `none`), `abstract interface class HapticEngine { bool get available; void play(Haptic haptic); }`, `NullHapticEngine` | No |
| `lib/core/haptics/system_haptic_engine.dart` | `SystemHapticEngine`: the table action to feel, the two sequences, the built-in calls | `package:flutter/services.dart` only |
| `lib/app/haptics.dart` | `Haptics`: the semantic methods, the on/off flag, the screen-reader flag, the 50 ms throttle | No (takes the engine, a flag function and a clock) |
| `lib/app/app_state.dart` | `AppState.haptics`, built from `hapticEngine` (default `NullHapticEngine`) and `settings` | |
| `lib/main.dart` | Passes `SystemHapticEngine()`, the only place that names it, like `SystemTtsEngine` | |
| `lib/ui/widgets/app_buttons.dart` | `AppFilledButton`, `AppOutlinedButton`, `AppTextButton`, `AppIconButton`, `AppInkWell`, `AppSwitch`, `AppCheckbox` | Yes |

`lib/core/haptics/` joins `lib/core/tts`, `lib/core/speech` and `lib/core/sound` in the list of directories rule 3 exempts: it wraps a platform channel by definition. AGENTS.md says so in the pull request.

### The service

```dart
class Haptics {
  Haptics({required HapticEngine engine, required bool Function() enabled,
           DateTime Function() clock = DateTime.now});

  bool get available => _engine.available;     // the Settings row is hidden when false
  set screenReader(bool on);                    // from the root widget's MediaQuery

  void tap();          void select();         void toggle(bool on);
  void confirm();      void danger();         void warning();
  void success();      void error();
  void correct();      void wrong();
  void longPress();    void dragStart();      void drop();
  void pill(SkillMark mark);

  void play(Haptic haptic);                    // for a wrapper's `haptic:` argument
}
```

- **Reached through `AppScope`**, like every service: `AppScope.read(context).haptics.confirm()`. No static, no singleton.
- **The flag is read in one place.** `enabled` is `() => settings.haptics`, given once in `AppState`. Nothing else reads the setting. The check is at call time, so a switch flipped in the middle of a sequence silences its second pulse.
- Every method is `play(Haptic.x)`. `play` checks the flag, the screen-reader rule, the throttle, and then calls `engine.play`.
- `SystemHapticEngine.play` is a `switch` over `Haptic` returning a feel: **the one table that says how anything feels**. Changing a feel is a one-line change there.

### The test double

`test/fixtures/recording_haptic_engine.dart`: `RecordingHapticEngine implements HapticEngine`, with `final List<Haptic> played` and `available` settable. A test builds its `AppState` with it; any test that does not mention haptics gets `NullHapticEngine`, so **no test ever reaches a platform channel**. The old mock of `SystemChannels.platform` in `languages_and_scripts_test.dart` goes.

### How tests check behaviour (AGENTS.md, "Tests check behaviour")

A test says what a learner feels, in meaning: "pressing Start gives confirm", "the wheel passing three languages gives three selects", "with the switch off, nothing", "the pill cycled Leave, Learn, Know gives pill-learn then pill-know", not which method was called inside. Full list in section 6 and section 4.

## 4. How every button gets it by default

### The mechanism

**The app's own button widgets carry the haptic; the raw Material ones are not used.** `lib/ui/widgets/app_buttons.dart`:

| Use | Instead of | Default haptic |
|---|---|---|
| `AppFilledButton` (and `.icon`) | `FilledButton` | `confirm` |
| `AppFilledButton.tonal`, `AppOutlinedButton`, `AppTextButton`, `AppIconButton`, `AppInkWell` (and `.icon` variants) | `FilledButton.tonal`, `OutlinedButton`, `TextButton`, `IconButton`, `InkWell`, `InkResponse` | `tap` |
| `AppFilledButton.danger` | a `FilledButton` styled with the error colour | `danger` (and the error colours) |
| `AppSwitch`, `AppCheckbox`, `GroupedTile.toggle` | `Switch`, `Checkbox`, `SwitchListTile`, `CheckboxListTile` | `toggle(new value)` |
| `Segmented`, `ChoiceTile`, `AppChoiceChip` | `ChoiceChip`, `FilterChip` | `select` |

Each wrapper forwards the parameters `lib/` actually uses to the Material widget it wraps (an audit in step 4; a parameter missed is a compile error that CI's `flutter analyze` reports), sets `enableFeedback: false` (Flutter's own click and long-press buzz off), and in its press handler does exactly this:

```dart
final haptics = AppScope.read(context).haptics;  // taken before the callback: it may leave the screen
onPressed!();
haptics.play(haptic);                            // after: a switch's new value, a failed callback, are already known
```

The haptic fires **after** the callback returns, so the Settings switch turning itself on is felt (the flag is already true) and turning itself off is silent (the flag is already false), and a callback that throws gives none.

Shared widgets already used everywhere carry it inside, so most screens need no edit: `GroupedTile` (every Settings row, one place: its `InkWell` becomes `AppInkWell`, its switch `AppSwitch`), `Segmented`, `SkillBadge`, `ChoiceTile`, `RatingButtons`, `PlayButton`, `Speaker`, `Hint`, `TabPager`, `TeachSwipe`, `LanguageBar`, the bottom `NavigationBar`, `SettingsSlider`.

The theme turns Flutter's feedback off for everything left: `TooltipThemeData(enableFeedback: false)`, and `Hint` fires `longPress` itself when its tooltip triggers. (To verify against Flutter 3.47: that `Tooltip.onTriggered` exists, else `Hint` wraps its child in a `GestureDetector(onLongPress:)`.)

### Why not something more automatic

| Option | Rejected because |
|---|---|
| A root `Listener` that buzzes on every pointer-up | Cannot tell a button from a scroll, a disabled button, or a refused tap, and cannot carry a meaning. |
| A custom `splashFactory` in the theme (it runs on every enabled ink response) | Fires on touch-down, before the app knows whether it was a tap, a scroll start or a long press; cannot carry a meaning; leans on an undocumented side effect. |
| Intercepting `Feedback.forTap` on the platform channel | Android only, tap only, and a hack on a private channel. |
| Callback wrappers at each of the 578 `onPressed`/`onTap` sites (`onPressed: haptics.wrap(...)`) | The same number of edits, but the developer has to remember it each time. A widget the developer already has to choose cannot be forgotten. |

### The developer rule

Put this in AGENTS.md ("Haptics") and the wiki's developer page:

> **Use the app's widgets, never Material's raw ones.** `AppFilledButton`, `AppTextButton`, `AppIconButton`, `AppInkWell`, `GroupedTile`, `Segmented`. They give the right haptic with no argument.
> Override only with a meaning: `haptic: Haptic.confirm` (finishes the task), `Haptic.select` (picks one of several), `Haptic.danger` (destroys something; use `AppFilledButton.danger`), or `Haptic.none` when the outcome speaks for itself (an answer, a save that can fail) and call `haptics.correct()`, `.success()` or `.error()` when you know the result.
> Never call `HapticFeedback` or `Feedback`. Never buzz for something the learner did not just do.
> What does it do? Picks: select. Finishes: confirm. Destroys: danger. Anything else: the default.

### Enforcement

`test/haptics_rules_test.dart` reads `lib/` as text (dart:io, no widgets) and fails with the file and line:

1. **`HapticFeedback.` and `Feedback.`** appear only in `lib/core/haptics/system_haptic_engine.dart`.
2. **No raw Material tappable** outside `lib/ui/widgets/app_buttons.dart` and the allow-list: `FilledButton`, `OutlinedButton`, `TextButton`, `IconButton`, `InkWell`, `InkResponse`, `ListTile`, `SwitchListTile`, `CheckboxListTile`, `ChoiceChip`, `FilterChip`, `Switch`, `Checkbox`, `GestureDetector`, `MenuItemButton`. (`styleFrom` and the `...Theme` classes are not constructors of these and are ignored.)
3. **`enableFeedback: true`** appears nowhere.
4. **The allow-list cannot rot.** `test/haptics_allowlist.txt` has one line per exception, `path | widget | reason`, for example `lib/ui/widgets/tab_pager.dart | GestureDetector | a drag, the page snap gives select`. The test fails on a line whose file no longer contains the widget, so an entry cannot outlive its need.

Known limit, said plainly: the test knows a list of widgets. A new Material tappable the list lacks (a `PopupMenuButton`, say) is added to the list when it is first used; the review checklist in AGENTS.md gets a line for it.

## 5. Migration of the existing calls

### Deliberate and implicit haptics

| File:line | Old | New |
|---|---|---|
| `lib/ui/widgets/language_bar.dart:273` | `HapticFeedback.selectionClick()` | `AppScope.read(context).haptics.select()` |
| `lib/ui/widgets/language_bar.dart:94` | doc: "a tick (`HapticFeedback.selectionClick`)" | doc: "a tick (`Haptics.select`)" |
| `test/languages_and_scripts_test.dart:2749-2768` | Mocks `SystemChannels.platform`, expects `HapticFeedbackType.selectionClick` three times | `RecordingHapticEngine`: expects `[select, select, select]` and the same language moved |
| `lib/ui/theme.dart:101` | `TooltipThemeData` with long-press trigger, Flutter's implicit `vibrate()` on Android | add `enableFeedback: false` |
| `lib/ui/widgets/hint.dart:32-36` | `Tooltip(triggerMode: longPress)` | the same, `enableFeedback: false`, fires `longPress` when triggered |
| `lib/ui/widgets/speaker.dart:125,172,180` | `onLongPress` on an `InkWell`/`Semantics`, implicit `vibrate()` | `AppInkWell(onLongPress:)`, fires `longPress` |
| `lib/ui/widgets/play_button.dart:72,97` | The same | The same |
| `lib/features/today/daily_card.dart:403` | `onLongPress: () => add(-step)` repeats, implicit `vibrate()` per repeat | each step `select` (the throttle thins a fast repeat) |
| `lib/app.dart:264` | `NavigationBar(onDestinationSelected: ...)` | add `haptics.select()` |
| `lib/ui/widgets/grouped_list.dart:370` and its `InkWell` | `Switch(...)`, `InkWell(onTap: change)` | `AppSwitch`, `AppInkWell`; one `_flip` path fires `toggle(!value)` |
| `lib/ui/widgets/segmented.dart:81,169` | `InkWell(onTap: ...)` | `AppInkWell(haptic: Haptic.select)` |
| `lib/ui/widgets/tab_pager.dart:336`, `lib/ui/widgets/teach_swipe.dart:243`, `lib/features/decks/decks_page.dart:316` | `onHorizontalDragEnd` changing the page | `select` when the page changes (checked per file; allow-list entries for the raw `GestureDetector`) |
| `lib/features/settings/settings_controls.dart:161` | `Slider` | `select` each time the stepped value changes |
| `lib/features/placement/language_card.dart:150,529`, `lib/features/review/suggest_bases.dart:152` | raw `Checkbox`, `Switch` | `AppCheckbox`, `AppSwitch` |
| every other raw button and `InkWell` (306 button sites in 110 files, 59 `InkWell`, 25 list tiles, 16 chips) | Material's, with implicit click sound | the `App*` widget of the same shape, mechanical rename (step 5) |

### New call sites (nothing to migrate; this is where the vocabulary is first used by meaning)

| Where | Call |
|---|---|
| `lib/features/languages/language_skills_sheet.dart`, in `_change` after `setState` (about line 265) | `pill(mark the pill now draws)`; `SkillBadge` is `Haptic.none` |
| `lib/features/drill/answer_feedback.dart:24` (the verdict) and the drills' Check buttons | `correct()` or `wrong()`; the Check and choice tiles (`choice_tile.dart:68`) are `Haptic.none` |
| `lib/features/drill/rating_buttons.dart:92` | `_RatingButton` is `confirm` |
| `lib/features/summary/summary_page.dart` | `success()` once, when the summary first shows |
| `lib/features/settings/backup_section.dart`, `restore_sheet.dart`, `your_data_page.dart` | `success()` when a backup or restore completes; `error()` when it fails; the restore and delete buttons are `danger` |
| `lib/features/profiles/pin_page.dart:242` | digits are `tap` (the default); a wrong PIN `error()` |
| `lib/features/settings/your_decks_page.dart` | a deck that fails its check `error()` |
| the Look row | `toggle` as above |

## 6. The Settings switch

### Wording

A switch row follows `docs/plans/settings-wording.md`: a plain title, and one line that says what happens now and changes the moment the switch is flipped. Not an icon-only button, so the one-word tooltip rule does not apply.

| | |
|---|---|
| Title | **Vibrate on touch** |
| On | Buttons, pills and answers buzz a little |
| Off | No buzz when you tap |
| Icon | `Icons.vibration` |

"Haptic" is jargon; "Vibrate on touch" is the Android words for the phone's own setting, and says what the learner feels. The line does not promise more than a buzz because, when the phone's own touch feedback is off, nothing buzzes whatever this says (Android; Flutter cannot read it). The mockup draws the row.

### Where

**Look and language** (`appearance_page.dart`; the Settings row "Look and language", `settingsRowLook`): the owner's "UI settings section". Its own block, 24 px corners, after **Card text size** and before **App language**, so App language and Fonts stay together at the end. A `GroupedTile.toggle` with the same padding as Pure black (20 and 16). No `Feature` gate: it is live. **Hidden** when `haptics.available` is false (web, desktop).

### Default

**On**, and it **respects the phone's own setting for free**. On: the owner asked for haptics on every button, a learner who never opens Settings should feel the feature, and the Android constants Flutter calls already obey the phone's "Touch feedback" setting, so a person who turned buzzing off system-wide does not get it from us. Off by default would hide the feature and need a trip to Settings. Downside of on: a learner who dislikes buzz feels it until they find the switch; the switch is one tap, on the Look page.

### Persistence and backup

- `SettingsNotifier` (`lib/app/settings.dart`): field `_haptics = true`, `bool get haptics`, `set haptics(bool)` through `_set`, like `pureBlack` (lines 56, 113, 989).
- Stored key: **`haptics`**, `'$_haptics'` in `toStored()`, `pick('haptics', flag)` in the reader. Stored names are permanent.
- Per profile, like every setting (the owner's note in `settings.dart`: "Per profile, like every setting").
- Backup: `settings.json` already holds "every setting", so it rides along with no format change and no version bump (`docs/BACKUP-FORMAT.md`). A backup from before this has no key, `pick` returns null, and the setting stays on. One line is added to the existing round trip in `test/backup_and_restore_test.dart:254` (`..haptics = false`), not a new test.

### l10n

In `lib/l10n/app_en.arb`, with translator descriptions, next to `appearancePureBlack`:

- `appearanceHaptics`: "Vibrate on touch"
- `appearanceHapticsOn`: "Buttons, pills and answers buzz a little"
- `appearanceHapticsOff`: "No buzz when you tap"

### Tests

New behaviours only (AGENTS.md):

1. `haptics_test.dart`, the service: with the setting off, every action plays nothing; a burst of selects inside 50 ms plays one; rise and knock play as one action and stop if switched off between pulses; with a screen reader on, `tap` is silent and `error` plays.
2. `haptics_test.dart`, the system engine: one table-driven test with `SystemChannels.platform` mocked, each action gives its feel's built-in calls (this is the only test that reaches the channel, and it documents the vocabulary table).
3. A widget test of the wrappers: `AppFilledButton` gives `confirm`, `AppTextButton` `tap`, `AppFilledButton.danger` `danger`, a button with `Haptic.none` and a disabled button nothing.
4. A widget test of the Look page: the row shows "Vibrate on touch"; switching it on gives one `toggle(true)` and the line changes; switching it off gives nothing, and a button pressed after gives nothing; the row is absent when the engine is unavailable.
5. A widget test of the pill: cycling a Spoken pill Leave, Learn, Hear, Hear and Speak, Leave records `pill-learn, pill-know, pill-know, pill-leave`; a locked pill and a cancelled download record nothing; a Know that placement covers records `pill-learnt`.
6. The language bar test (existing, rewritten): three languages passed give three `select`.
7. `haptics_rules_test.dart`, the enforcement test above.
8. The round trip (one added line, above).

## 7. Rollout

One pull request (`feature/haptics`, committed and pushed to `wip/haptics` in small steps), because the vocabulary, the setting, the widgets and the enforcement test are one change that is wrong in parts. Build order inside it:

| Step | Work | Size |
|---|---|---|
| 0 | This plan and the mockup approved by the owner; answers to the open questions recorded here, quoted and dated. ADR-0054 "Haptics are named by meaning" written (docs, straight to main). | S |
| 1 | `lib/core/haptics/` (enum, engine interface, null and system engines, the two sequences), `lib/app/haptics.dart`, `AppState.haptics`, `main.dart`, `RecordingHapticEngine`. Tests 1 and 2. | M |
| 2 | The setting (`haptics`), the Look row, the three l10n tokens, the backup test line. Tests 4 and 8. | S |
| 3 | `app_buttons.dart`: the wrappers, audited against the parameters used in `lib/`. `TooltipThemeData` and `Hint`. Test 3. | M |
| 4 | The shared widgets carry it inside: `GroupedTile`, `Segmented`, `SkillBadge`, `ChoiceTile`, `RatingButtons`, `PlayButton`, `Speaker`, `TabPager`, `TeachSwipe`, `LanguageBar` (migrating `:273` and its test, test 6), `NavigationBar`, `SettingsSlider`. | M |
| 5 | The sweep: a one-off script (not committed, written and run by a Sonnet agent, idempotent) renames `FilledButton(` to `AppFilledButton(` and so on, and adds the import, in about 140 files. `dart format`, CI's `flutter analyze` catches any parameter a wrapper lacks. | L but mechanical |
| 6 | The meaning call sites: pills (test 5), verdicts, summary, backup and restore, PIN, destructive buttons to `.danger`. | M |
| 7 | `haptics_rules_test.dart` and its allow-list, last, so it passes on the finished tree. | S |
| 8 | AGENTS.md ("Haptics" rule, rule 3's exemption, the review checklist line), the wiki developer page, one CHANGELOG line under Unreleased, the mockup removed (owner, 2026-10-16: "Remove when built"), the plan marked built. | S |

The Sonnet coder takes steps 1 to 8; one Sonnet review of the pull request (CLAUDE.md). CI runs the tests; nobody runs them locally.

### Risks

- **A 140-file diff.** It conflicts with every open branch (AGENTS.md rule 8 says not to touch files you are not changing; this is the exception, and every touched line is a rename). Mitigation: do step 5 last, after the others are pushed; the script is idempotent, so on a conflict, rebase onto main and run it again instead of merging by hand. If the owner would rather not, open question 3.
- **Feels differ by phone.** Section 1, Platform limits. The seven feels are only checked in the table-driven test, which cannot feel. A device check before release is a step of the review, not of CI.
- **The Android click sound goes.** Setting `enableFeedback: false` also removes Flutter's click sound on taps, which today follows the phone's touch-sound setting. This is deliberate (one switch governs touch feedback, no double cue). If the owner wants the sound kept, it is one argument in `app_buttons.dart`.
- **A destructive button left as `confirm`.** The default for a filled button is `confirm`; a delete button not built with `.danger` buzzes press, not thud. The review checklist names it; step 6 greps `colorScheme.error` near every filled button.
- **A wrapper missing a parameter** is a compile error, not a silent bug; CI finds it.
- **Throttle too strict or too loose** (50 ms). One constant, in one file.
- **Excess.** Principle 5 and the throttle are the guard. If the drills still feel busy, `correct()` is the one to silence: one line.

## Open questions for the owner

1. **How far apart do the pills feel?** The plan: Leave tick, Learn tap, Know press, Learnt rise: a ladder up, and Learnt a double. Tick and tap are close, and on a low-end phone the three singles may feel alike. *Wider* (Leave tick, Learn press, Know thud, Learnt rise) makes the singles easier to tell apart. Main downside of wider: a thud on Know, the pill cycled most, is heavy, and thud is also the destructive feel.
2. **Per profile or per phone?** The plan: per profile, saved in the backup, like every other setting. A phone shared by a family could instead keep the switch for the whole phone, off for a child's profile or on for all. Main downside of per phone: it would be the one setting that is not per profile and not in the backup.
3. **One pull request or two?** One: everything lands together, "all buttons" is true on merge. Two: the service, setting, shared widgets and pills first (small, reviewable), then the 140-file sweep and the enforcement test. Main downside of two: until the second merges, most plain buttons are still silent, and the owner's release would have to wait for both.
4. **With a screen reader on, what do we play?** The plan: keep the meaningful ones (success, error, danger, pills), drop tap, select, toggle and confirm because TalkBack and VoiceOver already vibrate. *Everything*: simple, and the learner can turn it off. Main downside of everything: a double buzz on every tap for the people who rely on the reader most.
5. **The AppBar's back arrow.** The plan leaves it silent in v1 (it is Flutter's `BackButton`; the system back gesture has its own). *Give it a tick*: a small `AppBackButton` set as `leading` in about 50 AppBars. Main downside: another 50-file edit for a control that already has the OS's feel, and the owner said "all buttons".

## Mockup

`docs/mockups/haptics-settings.html` (branch `mockup/haptics-settings`): the Look and language screen in the real theme, light and dark, 1x and 1.4x, with the new row highlighted among the existing ones, and a reference panel of the pill feels. Notes, tweak controls and the contrast self-check are in `haptics-settings.md` beside it.
