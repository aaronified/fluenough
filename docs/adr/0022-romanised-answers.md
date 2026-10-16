# ADR-0022: Answers typed in Latin letters are graded against the reading, in the language's scheme

- **Status:** Accepted. Superseded in part by ADR-0025: readings are
  ISO 15919 letters as said; typed answers are graded as this ADR says.
- **Date:** 2026-10-03

> **Note, 2026-10-09.** The readings ADR-0025 introduced are based on ISO
> 15919's letters, with deliberate deviations, not strictly ISO 15919; see
> the [list of deviations](../../README.md#where-the-readings-depart-from-iso-15919).

## Context

The owner asked for "transliteration support for answers, as no script
cannot work without it", in production, listening and grammar. A learner
who types `kitnaa` for कितना knows the word; one who types `kitna` does
too. Comparing letters as typed would fail one of them, and every Indic
language is typed several ways in chat.

Each language's readings now follow one popular, unmarked scheme, and
`decks/<code>/<code>-romanisation.yaml` lists the spellings learners also
type for the same sound (`ee` for `i`, `w` for `v`).

The owner decided the grade: "No-alphabet learners by default. Alphabet
learners can toggle it", and a right romanised answer from an alphabet
learner is graded 3.

## Decision

- **Where:** a production, listening or grammar card with a reading, in a
  script that needs one, offers Script or Latin letters above the answer
  field. Number practice types digits and does not.
- **How it is compared:** `RomanisedSpelling` writes both the answer and
  each reading one way before `AnswerGrader` compares them:
  - lowercase, accents stripped, letters and digits only, so spaces,
    hyphens and apostrophes do not count;
  - each spelling in an `equivalents` group written as the group's first,
    read from the left, longest first, each written once.

  A grammar cell that lists several forms accepts each form's reading
  (`Card.altReading`).
- **What counts:** exact, a near miss to judge, or wrong, as for the script.
  A near miss that is another card's reading is that other word, and wrong.
  The script is still accepted in Latin mode, and counts in full.
- **The grade:** a right answer in Latin letters records 3 for a learner
  learning the alphabet who is past its script units: they recalled the
  word, not how it is written. A near miss they judge "I knew it" is 3
  already. Before the script units, which a course reaches after its first
  six themes, answers start in Latin letters and count in full: the owner
  asked that "even for script learners, the initial writing exercises
  should be romanised". The no-alphabet path gives full credit throughout.

## Consequences

- A language with no romanisation file still accepts Latin answers, folded
  only for case, accents and spacing.
- Equivalence groups that overlap the decks' own spellings, such as Hindi
  `ch` for छ, make grading more lenient, never stricter: both sides are
  written the same way.
- The scheme drops length and retroflex marks, so a few different words
  share a reading (दिन and दीन are both `din`). In Latin letters either is
  accepted for the other; the script still tells them apart.
