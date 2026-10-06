# Plan: one Voices entry per language, with a test for hearing and speaking

Written 2026-10-06. **Part of the settings redesign,** with
`language-picker.md`, `settings-wording.md` and `voices-per-language.md`:
last in the owner's order, after `skill-model.md`, `b1-plans.md` and deck
downloads (`decks-from-github.md`).

## What the owner asked

> In voices>languages page, merge the speaking and listening buttons, and
> add tests for both.

## What exists

`VoicesPage` (`lib/features/settings/voices_page.dart`) lists each language
twice:

1. **Voices**, for listening: one row per language with its text-to-speech
   status, how many voices the phone has for it, and **Test**, which speaks
   a sample phrase. Then "Install voices" and "Check again".
2. **Recognising your speech**, for speaking: one row per language with its
   recogniser status:
   - on this phone;
   - online, as you allowed;
   - only online, with a switch to allow it;
   - not recognised.

   With speaking off, "Switch on speaking" instead.

There is no way to test speech recognition outside a drill. That is why the
Telugu failure had to be found from a speaking card, and why its cause is
still unknown.

## The design

One card per language, in the order the learner learns them:

- **Its name and icon.**
- **Listening:** the voice's status and count, and **Play**: it speaks the
  sample phrase, as Test does today. With no voice, "Install a voice" opens
  the same help as now.
- **Speaking:** the recogniser's status, and **Say something**:
  - it shows a word from the course, with its reading, and listens;
  - it shows what the phone heard ("Heard: నమస్కారం") and whether that
    matches the word;
  - or it gives the reason nothing came back, in the drill's words: nothing
    heard, the recogniser stopped, couldn't reach the online recogniser, or
    not recognised on this phone;
  - where the language is only heard online, the card asks first, as the
    drill does. The online switch moves into the card;
  - with speaking off, the card offers "Switch on speaking" in place of the
    test.
- **Page-level, unchanged:** the intro, "Install voices" and "Check again".

A test records nothing. A speaking test updates what the app knows about
the language, as a drill's listen does: a language found not on the device
moves to "only online".

## What it takes

1. One card widget in place of `_VoiceRow` and `_SpeechSection`'s rows.
2. The speech test reuses `AppState.listenFor`, `SpeechHeard` and the
   drill's failure messages, and the same normalising as grading to say
   whether the word matched.
3. **Tests**, with `FixedTtsEngine` and `FixedSpeechEngine`:
   - Play speaks the sample in the language's tag;
   - Say something shows the heard text and the match;
   - each failure shows its message;
   - the online question appears, and Allow then listens online;
   - speaking off shows "Switch on speaking";
   - a test records nothing;
   - twice the text size, both themes, screen-reader labels.

## To decide

- Whether a failed speaking test also shows the recogniser's own error code
  in small print, such as `error_no_match`. It would let a learner, or a bug
  report, say exactly what failed, which would settle the Telugu question.
- Whether the card shows a word from the course to say, or lets the learner
  say anything.

## Estimate

About 3–5 hours. Confidence: medium.
