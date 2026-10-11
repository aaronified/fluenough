# Plan: placement, script first, then a three-skill check

Written 2026-10-11, for **0.6.0** (owner: too large for 0.5). Tracks #481. It is the top priority of 0.6.0. Replaces the placement in ADR-0013 and keeps
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

Owner, later the same day:

> Without the alphabet, it shows the romanised reading instead: this must
> be via checking the script first (user can skip by saying "I do not know
> the script").
>
> For close scripts like Spanish (when user knows English script), only the
> deviations will be checked.
>
> Thus each deck will have a placement section, and script placement will
> be via the native language.

## The new flow, per language

1. **Learn from:** pick the native language, as now, when there is a choice.
2. **Script check, first, always.** There is no yes-or-no alphabet
   question any more. Romanised (ISO) words are used only as the outcome
   of this check, never as a default.
   - **"I don't know the script"** is a button on **every** script
     question (owner, 2026-10-11). Tapping it on any of them ends the check
     and takes the no-alphabet path at once.
   - **The check is set by the course's native language** (the language it
     is taught from). It asks only what that native language's script
     doesn't already give the learner:
     - **Close scripts** (the target shares the native's script, as
       Spanish does English's Latin): only the **deviations** are
       checked, the letters and marks the native script lacks or reads
       differently (Spanish ñ, á é í ó ú, ü, ll, j, h). Two or three
       questions; if none differ, the check is skipped.
     - **Different scripts:** three letters at random (plain letters,
       letters with vowel marks, or joined letters), then two harder words
       if all three are right.
   - Each question asks for the sound (ISO reading), with 4 options to
     choose from.
   - **All right:** the learner reads the script. They learn with it, and
     the script units are placed.
   - **One wrong:** they are offered the alphabet, and the script units are
     taught. The words below are still shown in script, with the reading
     beside them.
   - **Two or more wrong (fails conclusively):** the no-alphabet path
     (ADR-0023). From here on every word is shown and typed in Latin
     (ISO 15919) letters.
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

## The placement section in every deck (part of the B1 route)

- Each deck gets a `placement:` section, written with the B1 plan and
  reviewed like the rest of the deck. It names the deck's clearest cards to
  ask, by card id: two for meaning, one for listening and one for typing.
  The unit's check draws from its decks' placement sections.
- **The script check lives in the native-language layer**
  (`decks/<lang>/<native>/...`), because what has to be checked depends on
  the script the learner already reads. A `placement: script:` section
  lists:
  - for a different script, the letters, letters with marks and joined
    letters to draw from, and the harder words;
  - for a close script, only the deviations from the native script.

  Each entry has its reading.
- **Fallback:** a deck with no placement section falls back on its own
  cards, as now. A layer with no script section falls back on the script
  decks' cards.
- **Validator:**
  - placement entries point at real card ids;
  - every script entry has a reading;
  - by the B1 milestone, every unit of the path has placement entries.
- **Never taught:** the placement section is never taught as a deck, and
  isn't on the path or in Today.

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
- Placement sections:
  - the validator rules;
  - the fallback to the deck's own cards;
  - the close-script deviations come from the native layer (Spanish from
    English);
  - "I don't know the script" goes straight to Latin.
- Retake: replaces the placement and keeps real reviews.
- Accessibility at 2x text, in light and dark.

## Estimate

About 5 to 7 days for the app and tools, plus the placement sections: about half a day per
language with Sonnet writing them and a review, and the script sections
per native layer.
Confidence is medium; seeding FSRS states and typing in the check are the
larger parts.

## Open

- How many harder words count as "complicated" for each script: one
  joined letter and one vowel mark, or a per-language list. The plan uses
  the native layer's script section.
