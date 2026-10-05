# Plan: pronunciation, pass or retry

Written 2026-10-05.

## What the owner asked

> Pronunciation feedback (Rosetta Stone): record and compare via platform
> speech-to-text; pass/retry. if this does not exist, plan this

Decided with the owner: **the first attempt counts** for the word's
schedule. Retries are practice, so a word that needed them comes back
sooner.

## What exists

Most of it:

- **Record and compare:** the speaking drill (#89, ADR-0014) sends what the
  learner says to the phone's speech recogniser. It grades the text like a
  typed answer and records it.
- **Feedback:** when the word heard is the answer with one sound changed, it
  names the sound from the language's sounds file. For example: "You said
  …, which means …. The difference is …".
- **Nothing heard** asks again, unrecorded.

What is missing:

- **Retry after a wrong answer.** The drill records it and moves on.
- **Hearing yourself** beside the voice.

## What it takes

1. **Pass or retry:** after a wrong or almost-right answer, **Try again**
   lets the learner say it again, as often as they like, and **Continue**
   moves on.
   - The first attempt's grade is the one recorded.
   - A retry that passes says so, but changes nothing.
2. **Hear yourself, then the voice:** play the learner's attempt, then the
   model.
   - Android's recogniser holds the microphone while it listens. Whether
     the `record` plugin (already in the app) can record at the same time
     is to check on a phone.
   - If it cannot, "hear yourself" records a second take after the
     recogniser is done.
   - Recordings stay in memory and are never saved, as in the first-launch
     sound check.
3. **Tests** for retry, the first attempt counting, and playback, with fake
   engines.

## To decide

- Whether retry is offered on an almost-right answer, or only on a wrong
  one.

## Estimate

About 3–4 hours. Confidence: medium. Playback alongside recognition needs a
phone to check.
