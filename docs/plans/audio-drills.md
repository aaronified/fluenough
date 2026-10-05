# Plan: hands-free audio drills

Written 2026-10-05.

## What the owner asked

> Hands-free audio drills (Pimsleur): prompt → pause → native answer,
> playable with screen off. an on-demand feature.

Decided with the owner:

- **Answers are graded** for the listening and speaking skills. If grading
  does not work with the screen off, the app says so and offers the choice.
  I read "provide option to keep screen off" as offering both:
  - keep the screen on, dimmed, and graded;
  - or keep it off, and not graded.
- **New words too:** the drill introduces new words by ear, Pimsleur-style,
  and repeats them at growing gaps within the session.
- **Background playback** uses the `audio_service` plugin (MIT, 0.18.19),
  which the owner approved.

## What exists

- **Speech** is the phone's own: `flutter_tts` for voices, `speech_to_text`
  for recognition (ADR-0014). Both run while the app is open; nothing plays
  in the background.
- **The listening and speaking skills** each have their own schedule. The
  speaking drill already grades what the recogniser heard, and names the
  sound when the learner said the word next to it.
- The Sound switch, the volume message and autoplay (ADR-0026) all apply.
- There is no media notification, and no lock-screen or headphone control.

## The drill

Started on demand, from Today or a language's page, for a chosen length,
such as 10, 20 or 30 minutes. It mixes two kinds of item:

- **Speaking:**
  1. a prompt in the learner's language: "How do you say: milk?";
  2. a pause while the learner says it, and the phone listens;
  3. the answer in the language's voice, said twice.
- **Listening:**
  1. the word or phrase in the language's voice;
  2. a pause while the learner says what it means, and the phone listens in
     the learner's language;
  3. the meaning.

**New words** are introduced by ear: heard twice, then said after the
voice. Each is then asked again at growing gaps within the session, roughly
seconds, then a minute, then several minutes, as Pimsleur's graduated
recall does.

## What it takes

1. **`audio_service`:**
   - a foreground service with a media notification;
   - controls for pause, skip and stop, from the lock screen and from
     headphones;
   - started while the app is open, as Android requires.
2. **The queue:** due listening and speaking pairs first, then new words, to
   the chosen length.
3. **Grading:**
   - each answer is heard by the recogniser and graded as the speaking drill
     grades it, in the target language for speaking and in the learner's
     language for listening;
   - grades are recorded as those skills' reviews;
   - a new word introduced counts as taught.
4. **With the screen off:** Android limits the microphone in the
   background. The service declares that it uses the microphone, and the
   app checks once whether recognition works with the screen off.
   - If it does not, the app says so and offers the choice above.
   - Ungraded items are not recorded.
5. **Voices:** a voice is needed in the learner's language too, for the
   prompts. Without one, or without a voice for the language learnt, the
   drill says so and does not start.
6. **Tests** for the queue, the gaps for new words, grading both ways, the
   ungraded fallback, and the controls.

## To decide

- How long the pause before the answer is, fixed or growing with the item.
- Where it is started: Today, a language's page, or both.
- Whether it stops at the end of a time, or after a number of items.

## Estimate

About 12–16 hours. Confidence: low, until it is tried on phones of
different Android versions with the screen off.
