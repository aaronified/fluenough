# Plan: say when speech can't be recognised offline

Written 2026-10-05.

## What the owner asked

> also, the app doesnt outright tell me that my voice recognition is not
> working offline for my chosen language. there should be an alert that
> takes me to the settings page.

Asked whether to build it now or plan it, the owner chose to plan it.

## What exists

- `AppState.speechStatus(language)` already knows the answer. For a
  language the phone's recogniser does not list, Android 13 and later list
  only on-device languages, so the status is `onlineOnly`. Until the learner
  allows online recognition, `canHear` is false.
- Then every speaking question in that language is left out of lessons and
  reviews, without a word.
- Where it is said today:
  - the Voices page shows "Only online. Allow it to send what you say to
    your phone's speech service";
  - a deck's page shows its Speaking row greyed, with "Set up voice".

  A learner has to go looking for either.
- The drill asks about going online only when a listen finds that a
  *listed* language cannot be heard on the device. Never for one the
  recogniser did not list.

## What it takes

1. **The alert.** When speaking is on and a language being learnt is
   `onlineOnly` or `missing`, the app says so the first time a session would
   have asked it a speaking question:
   - "Your phone can't recognise Telugu offline, so speaking questions are
     skipped."
   - **Open settings** goes to the Voices page, at that language's row.
   - **Not now** closes it.
2. **Once per language**, until its status changes. A setting remembers
   when it was shown. Whether it comes back later is to decide.
3. **On Today, while it lasts:** a line under the session card says the
   same, with the same button.
4. **Missing**, where the phone can't recognise the language at all, even
   online, says so plainly, and points to Settings > Learning > Speaking to
   switch speaking off for that language.
5. **Tests** for each status, the once-per-language rule, the line on
   Today, and the button opening the right row.

## To decide

- The alert's place: when a session starts, or on Today at launch.
- How often it comes back: weekly, never, or each launch.

## Estimate

About 2–3 hours. Confidence: medium. It needs a check on a phone whose
recogniser lacks the language.
