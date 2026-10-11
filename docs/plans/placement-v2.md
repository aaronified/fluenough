# Plan: placement, script first, then a three-skill check

Written 2026-10-11, for 0.5.0. Tracks #481. **Top priority** (owner: "Any change here
will also be top priority"). Replaces the placement in ADR-0013 and keeps
ADR-0023's no-alphabet path.

## What exists (origin/main)

- **Order:** for each newly ticked language, the learner picks the language
  to learn from, answers "Learn the alphabet?" yes or no, then "Find my
  level" or "I'm new" (`lib/features/placement/placement_page.dart`).
- **The check** (`lib/app/placement.dart`): units in path order, up to 4
  questions each. Each question is the target word, with a choice of 4
  meanings. A unit passes with at most 1 wrong. The **first failed unit
  stops** the check, and every unit before it is placed.
- **Placed decks** (`settings.placedDecks`) read Done, and Today skips them.
  **No review and no FSRS state** is created, so placed cards are never
  reviewed again.
- **Recognition only.** The alphabet is a self-reported yes or no.
- **No retake**, short of unticking and adding the language again.

## What the owner decided (2026-10-11)

> All cards in placed decks should get reviews as currently known.
>
> Stop after 2 fails in a row.
>
> Meaning + listening + typing.
>
> Retake from Settings. Short letter check. The script placement should
> come first. If the script is known previously (e.g. Spanish shares same
> script with English) then it is skipped. If script placement fails
> conclusively, then all word checking will be via latin (ISO). The 6
> letters will be randomly chosen and can have vowel marks or mixed letters.
> Or better, ask 3 letters and if those are all correct, ask 2 complicated
> words. Add a placement deck for languages as part of the B1 route.

## The new flow, per language

1. **Learn from:** pick the native language, as now, when there is a choice.
2. **Script check, first.**
   - **Skipped** when the language's script is one the learner already
     reads, from Languages you know (#462). For example, Spanish's Latin
     script for someone who knows English. The answer is then "with
     the script".
   - **Otherwise, three letters.** Pick three letters at random from the
     placement deck's script set: plain letters, letters with vowel marks,
     or conjuncts. For each, the learner chooses its sound (ISO reading)
     from 4 options.
     - **All 3 right:** two **harder words**, each with vowel marks and a
       conjunct, again choosing the reading from 4 options.
     - **Both words right:** the learner reads the script. They learn
       with it, and the script units are placed.
     - **One letter wrong, or one word wrong:** they are offered the
       alphabet, and the script units are taught. The words below are
       still shown in script, with the reading beside them.
     - **Two or more letters wrong (fails conclusively):** the
       no-alphabet path (ADR-0023). From here on every word is shown
       and typed in Latin letters (ISO 15919 reading).
   - "I don't know" counts as wrong, and the learner can choose to skip
     the check and start with the alphabet.
3. **Find my level or I'm new,** as now.
4. **Word check, by unit, in path order.** Each unit asks:
   - **Meaning:** 2 questions. The word is shown in script, or in Latin
     after a failed script check, and the learner picks its meaning from 4.
   - **Listening:** 1 question. The word is heard, and the learner picks
     its meaning from 4. It runs only when the phone has a voice for the
     language; otherwise it becomes a Meaning question.
   - **Typing:** 1 question. The meaning is shown, and the learner types
     the word, in script or in Latin (ISO) by the script check's answer.
     It is graded as reviews grade it, with alternatives and folded
     diacritics. If the keyboard for the script is missing, the
     HeliBoard hint shows, or the learner can type Latin.
   - **Pass:** at most 1 of the 4 wrong.
   - **Stop rule:** the check stops after **two failed units in a row**.
     Every passed unit is placed; failed units, and those after the
     stop, are taught.
5. **Result:** "From unit N", and which units were placed and which will be
   taught.

## Placed cards get reviews (owner: "as currently known")

- Every card of every placed deck gets an FSRS state, for each skill the
  learner has switched on, as if answered **Good** once on the day of
  placement.
- The first due dates are **spread over the next 2 to 4 weeks**, so
  placement doesn't make a pile of reviews on one day.
- A card answered wrong later is a normal lapse, so a wrong placement
  corrects itself.
- These first states are written as **placement entries** in the review
  log. They are marked as placement, are not counted in stats or streaks,
  and are exported with the log so a backup keeps them.

## The placement deck (part of the B1 route)

- Each language gets one deck, `decks/<lang>/<lang>-placement.yaml`, made
  with the B1 plan. It holds:
  - the **script set**, letters and harder words tagged by difficulty, for
    the script check;
  - for each unit of the path, **chosen questions**: the clearest words
    and sentences, reviewed like any deck.
- When a unit has no chosen questions, the check falls back on the unit's
  own cards, as now.
- The placement deck is never taught. It isn't on the path or in Today.
- The deck format gets `kind: placement`, and the validator checks it:
  - every unit of the path is covered;
  - each script-set entry has a reading;
  - every unit ref resolves.

## Retake from Settings

- In Languages I'm learning, each language gets **Find my level again**.
- It runs the same flow from step 2.
- It replaces that language's placement. Cards placed before keep their
  reviews, and newly placed cards get reviews as above. Real reviews are
  never removed.

## Tests

- Script check:
  - skipped for a known script;
  - 3 letters, then 2 words, then each outcome (reads the script, offered
    the alphabet, no-alphabet path);
  - picks letters at random, with a seed in tests.
- Word check:
  - meaning, listening and typing per unit;
  - listening falls back without a voice;
  - typing in Latin after a failed script check.
- Stop rule: one failed unit doesn't stop, two in a row do, and each
  passed unit is placed.
- Placed cards:
  - get states for every skill switched on;
  - due dates spread over 2 to 4 weeks;
  - left out of stats and streaks;
  - kept in exports.
- Placement deck:
  - the validator rules;
  - the fallback to unit cards.
- Retake: replaces the placement and keeps real reviews.
- Accessibility at 2x text, in light and dark.

## Estimate

About 5 to 7 days for the app and tools, plus writing a placement deck for
each language: about half a day each, with Sonnet writing and a review.
Confidence is medium; seeding FSRS states and typing in the check are the
larger parts.

## Open

- How many harder words count as "complicated" for each script: one
  conjunct and one vowel mark, or a per-language list in the placement
  deck. The plan uses the deck's list.
