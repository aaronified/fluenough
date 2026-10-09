# Plan: hours spent, and hours left, for each language

Written 2026-10-05.

## What the owner asked

> for each language, also show a hours spent learning it (only count time
> spent on cards), and approx hours left to complete learning (as per the
> app). this is another plan.

Decided with the owner:

- **"Complete"** means finishing the course content: every card on the
  language's path taught, and reviewed until it is remembered. It does not
  mean the FSI hours to fluency, or the end of the path's phases.
- **The course ends at CEFR B1, about ILR 1+** (`language-paths.md`, "Target
  level"). Hours left therefore count down to B1. Until the courses are
  extended, they count down to the end of today's smaller content.
- **Idle time** is capped: each answer counts for at most 60 seconds, so a
  question left open does not add hours.

## What exists

- **Every answer's time is logged.** Each row of the review log has
  `elapsed_ms`. The drill's stopwatch starts when a question shows and stops
  at the answer, so reading the feedback is not counted. Reading a passage
  before its questions is not counted either.
- **A card being taught (`Ask.teach`) records nothing**, so its time is not
  in the log.
- **Progress** (`stats_page.dart`) shows, per language, through the language
  chips:
  - reviews;
  - the share remembered;
  - the streak;
  - cards learned.

  It shows no time.
- **Today** estimates its session at a flat 20 seconds a card
  (`secondsPerCard`).

## What it takes

1. **Hours spent:** the sum, over the language's reviews, of each answer's
   time capped at 60 seconds. On Progress, under the language chip, it
   follows the range chosen (7 days, 30 days, all).
2. **Hours left:** for every pair of a card on the path and a skill it is
   drilled in that is not yet remembered:

   hours left = Σ (reviews it still needs × this learner's time per answer in
   that skill) ÷ 3,600

   - **Remembered:** an interval of 21 days or more, Anki's "mature".
   - **Reviews it still needs:** from its schedule, the right answers it
     takes to reach 21 days, raised by this learner's share of misses.
     - Under FSRS, it is simulated from the pair's stability.
   - **Time per answer:** the learner's median for that skill, capped. Until
     there are 20 answers in a skill, it uses the 20 seconds Today uses.
   - **The cards counted:** the path's decks. The script decks are left out
     for a learner without the alphabet. Skills switched off, or that the
     phone cannot do, are left out too.
3. **Shown** on Progress for the chosen language: "12.4 hours spent" and
   "About 140 hours left". It reads "About" because it changes as decks are
   added and as the learner's times change.
4. **Tests** for the cap, the sum by language and range, the count of
   reviews needed, the defaults, and the skills left out.

## To decide

- Whether teach cards should be timed too. That needs a log of their own,
  since a review row needs a grade.
- Whether the "remembered" threshold is 21 days.
- Whether hours appear anywhere besides Progress, such as each language's
  row on the Decks tab.

## Estimate

About 3–4 hours. Confidence: medium.
