# Plan: an AI conversation partner, within what the learner knows

Written 2026-10-05. **A long-term plan.**

## What the owner asked

> AI conversation partner (Duolingo Max, Babbel): chat limited to the
> learner's known vocabulary and current grammar.
>
> long term future plan. will use user's API / local AI (downloaded within
> the app, something like gemma 4 E4B)

## What exists

- **Nothing that generates language.** Every word the app shows comes from
  the decks.
- **What the learner knows is in the review log:** every card taught, and
  per skill, how well it is remembered. The grammar steps taught are the
  path's grammar units done. So "known vocabulary and current grammar" can
  be listed exactly.
- **The app holds no secrets and makes no account.** It reaches GitHub only
  for updates and, once planned, decks (`decks-from-github.md`).

## Two ways to run the model

1. **On the phone:** Google's Gemma 4, released on 2 April 2026, has an E4B
   size built to run offline on phones.
   - The Flutter plugin `flutter_edge_ai` 2.0.0 (MIT) runs Gemma and other
     models on the device. It is the new name of `flutter_gemma`, renamed
     on 5 October 2026.
   - The model is a download of several gigabytes, offered inside the app,
     never bundled. Its size and licence terms are to check before
     choosing it.
   - It needs a recent phone, with enough memory.
2. **The learner's own API key:** for example Anthropic's Claude API, where
   `claude-opus-5-5` is the current default model. There is no official
   Anthropic SDK for Dart, so the app would call its HTTP API directly.
   - The key stays on the phone, in the platform's secure storage. It is
     never sent anywhere but to that provider.
   - Messages leave the phone, which the app must say before the first
     chat.

## What it takes

1. **The learner's limits, as data:**
   - the known words, with their forms;
   - the grammar steps taught;
   - the level reached (A1, A2, B1, from aaronified/fluenough#187).

   They are sent to the model as its instructions for each chat.
2. **Keeping the model within them:**
   - each reply is checked against the known words;
   - a reply with unknown words is asked again, or the words are marked and
     offered as cards (`import-text.md`);
   - grammar beyond the learner's steps is flagged, not hidden.
3. **Scenarios** taken from the path's themes, such as market or directions,
   so a chat practises what the unit taught.
4. **Feedback** on the learner's messages, which reuses
   `explain-mistakes.md`'s rules where one applies.
5. **Speech,** optionally: the learner speaks and hears the replies, with
   the recogniser and voices the app already uses.
6. **Privacy:**
   - on the phone, nothing leaves it;
   - with an API key, the learner is told which provider receives what;
   - no chat is saved unless the learner keeps it.
7. **Tests** for the limits, the vocabulary check, and the prompts. They use
   a fake model, since real models cannot run in CI.

## To decide

- On the phone, the API, or both, and which comes first.
- Which providers an API key may be for.
- Whether chats count as practice in the review log, and in which skills.
- The smallest phone the on-device model must run on.

## Estimate

About 20–30 hours for a first version with one of the two ways. Confidence:
low; this depends on the models available when it starts.
