# Progress and stats

The Progress tab shows how you are doing. It is recomputed from your review log, so nothing here is ever lost ([Log format](Log-Format)).

## What it shows

The numbers are for the language picked in the language bar at the top, or for every language together. From the top:

- **Words, Rules and Sentences**: three tiles in a row, counted against what is taught so far (#418). **Words** is the words you know, by base word, so two forms of one word are one, out of the words you have been taught, such as **312** known, of 540 taught. **Rules** is the rules you know, of the rules you have been asked. **Sentences** is the sentences open, of the sentences in the decks you have begun: a sentence opens once every word and rule in it is known ([ADR-0046](ADR-0046-Lessons-Take-The-Next-Eligible-Items)). Known is the same everywhere: your last review of the word in each skill was right, and the app judged you at least 85% likely to remember it at that moment (#680).
- **Level**: below them, alone, the course's level, A1, A2 or B1, from the path's milestones you have reached, with the day you started, the day of your first answer. The tile is bronze for A1, silver for A2 and gold for B1, and plain before A1. On All languages it shows only the earliest start date, since levels differ by course.
- **The last 7 days**, oldest first, today last, with no legend. One mark a day: a filled flame when you met the day's quota, two overlapping flames (only the front one filled) at twice the quota or more, a filled dot for some practice, an empty dot for none. A line joins days you practised, which is your streak; on All languages any practice counts. The quota is 15 minutes a day until the daily commitment (#485) is built.
- **Mastery by skill**: a six-point star of grammar, script, read, write, hear and say. The shaded shape is what you know of the whole B1 plan; the solid blue outline is what you know of what you have been taught, and sits at the centre for a skill with nothing taught yet. It grows once when you open the tab, and not at all with reduced motion. Tap it for **Over time**: two charts of the last 12 weeks, "Mastery over time" and "Taught over time", one line per skill, told apart by colour, dash and marker. Below them, **How you learn** opens the page on your pacing.
- **Hours spent** and **Hours left**: a row of two tiles under the star. Hours spent is the time of every answer, each counted for at most 60 seconds, for all time. Hours left is about how many hours are left to the end of B1: the hours left in the decks written so far, plus, for each planned unit up to B1 without decks, the average of what a written unit takes from new, at your own time per answer; "–" for a language with no decks. Tapping the row opens a popup with each language's hours spent and left, and the total (#227). The Decks tab's course card keeps "in the decks so far".
- **Weakest tags**: the three topics with the largest share of their taught words and forms that you do not know now (the star's rule), with "All tags" to the rest. Ties go to the tag with the lower recall now, then to its name. It does not depend on the range.
- **Leeches**: cards you keep missing.

A card is **known** when its last review was right and FSRS predicted at least 85% recall at that review (#680), by the parameters that schedule that skill, so Progress and the scheduler agree. The B1 total is the whole B1 plan: the planned words (or the words written, if more) for read, write, hear and say, the grammar cells written for grammar, and both skills of every letter of the alphabet decks for script.

## Placed (owner decisions, 2026-11-07)

Find my level credits words, forms and letters you already know. Progress shows that credit apart from what you earned:

- **Placed** is a word, form or letter that placement credited and that you have not answered since. It is never counted as known and never as taught, so the star's outline (known of taught) stays earned-only. The star draws placed as a **hatched layer under the solid fill**, reaching as far as placed and earned together; the Words tile reads "312 known of 540 taught (+90 placed)", and Rules likewise.
- Once you answer a placed pair it is earned: known if the answer was right and recalled at 85%, else taught and not known. A placed pair you lapsed drops out of the placed layer into taught, not known.
- Credit you took back (Languages sheet, "Check your level again") is not placed.
- The course's level shows with a **Placed** mark until a unit of that milestone has an earned review.
- Credit written by Find my level in 0.9.0 and 0.9.1 that is not yet confirmed counts as placed like the rest on Progress; only the Languages sheet marks it unconfirmed.
- Progress shows only the lower-edge point of a placement, never its range.
- Whether the credit was set in stone or left to be reviewed as usual does not change what Progress shows: placement is reflected either way.
- Placed words do not hold back new lessons (they are not "in progress"), and they do not open sentences that wait for known words.

The core is built (`lib/core/progress/mastery.dart`, `unlocks.dart`: `SkillScore.placed`, `WordCounts.placed`, `UnlockCounts.wordsPlaced` and `rulesPlaced`); the drawing (the hatched layer, the legend, the tile wording, the Placed mark) follows with the placement screens.

Until you finish a session, it says there are no reviews yet.

## Leeches

Open the leeches list to see cards you missed again and again. Drilling them harder rarely helps. Read the card's note, then either reset a card to new, or set it aside.

## Your pace

"Learn more about your pacing" explains how each skill's pace is worked out from your answers. For each skill it shows how many days a word waits, for you and at the start, and about how many reviews are due in the next 30 days. Nothing is adjusted until a skill has enough answers. See [Drills and skills](Drills-and-Skills).

## Per course

The Decks tab shows each course's units done and the hours left in the units written so far ([Courses and paths](Courses-and-Paths)).

## Not built

Achievements are planned ([Plan: Achievements](Plan-Achievements)). They are not in the app yet.

See also: [Learner guide](Learner-Guide), [Home](Home).
