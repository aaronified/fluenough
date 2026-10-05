# Plan: more speaking exercises

Written 2026-10-05.

## What the owner asked

> Increase speech recognition exercises (i have not encountered any in two
> days).

## What I found

This comes from the code. I could not check a phone from here.

- **Speaking starts off.** `Skill.onByDefault` is false for speaking alone
  (ADR-0014): the microphone is asked for only when speaking is switched
  on. It switches on in two ways:
  - the first-launch sound check, if the recording worked and the phone has
    a speech recogniser;
  - Settings > Learning > Speaking.

  Otherwise it stays off, and no speaking question is ever asked.
- **The phone must be able to hear the language.** Even with speaking on,
  a language is asked by mouth only while `canHear` is true:
  - on the device, if the phone's recogniser lists the language;
  - online, if the learner allowed it on the Voices page.

  Android 13 and later list only the languages on the device. Telugu and
  other Indian languages may be online only, and then every speaking
  question is left out until the learner allows it. Nothing on Today says
  so.
- **When it can, speaking is common:**
  - A lesson asks a speaking question in the exercise for each easy and each
    hard card, about two in three of its cards, but never for a medium card
    (`lessonQuestions`, ADR-0024).
  - Reviews bring speaking pairs as they fall due.

So none in two days points to speaking being off, or to the language not
being heard on the phone, rather than to too few questions. The first step
is to check the phone: the Speaking switch in Settings > Learning, and the
language's row on the Voices page.

## What it takes

1. **Say why speaking is missing.** When speaking is off, or the language
   cannot be heard, Today or the end of a lesson says so once, with the way
   to fix it:
   - "Speaking is off. Switch it on?"
   - "This phone can't hear Telugu on the device. Allow it online?"

   Either message can be dismissed.
2. **Ask the owner whether speaking should start on.** It would then ask
   for the microphone at the first speaking question, not at launch. That
   changes ADR-0014.
3. **More speaking where it can be heard:**
   - Medium cards get a speaking question too.
   - A lesson can add "say it after me" straight after teaching a word: the
     phone says it, the learner repeats it, the recogniser checks.
   - Quick revision (ADR-0029) asks a word by mouth when it has been
     reviewed that way, rather than in one of its skills picked at random.
4. **A target share**, such as at least one speaking question for every
   three cards in a lesson, which the tests check.
5. **Tests** for the message, the share, and "say it after me".

## To decide

- Whether speaking starts on for new learners.
- The share of speaking questions in a lesson.
- Whether to add "say it after me", which needs both a voice and a
  recogniser.

## Estimate

About 3–4 hours. Confidence: medium. How it behaves needs checking on a
phone, which I don't have.
