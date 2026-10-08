# ADR-0034: Hear, Say and Write: three schedules per word

- **Status:** Accepted
- **Date:** 2026-10-08
- **Amends:** ADR-0005 (which pairs are scheduled) and ADR-0024 (how
  listening is asked, and what a right choice records).

## Context

The owner asked that the listening test ask for the meaning, not the
transliterated word, "otherwise we cannot know whether the user understands
pen and time in telugu separately", and that the app learn the learner's
strengths per skill. `docs/plans/skill-model.md` sets out the research and
the design; its decisions were settled in #235.

Until now each word was scheduled in four modes: recognition (choose or rate
the meaning), production (type the word), listening (hear the word, type
it) and speaking (say it).

## Decision

- **Three schedules per word: Hear, Say and Write,** and grammar's. Hear is
  the `listening` mode, Write `production`, Say `speaking`. The names stay
  as they were: they are stored in the review log, which is never
  rewritten.
- **Hear asks for the meaning.** The word is played; its meaning is chosen
  while the pair is new or was last missed, and typed once it was last
  remembered. Where what is heard is the form itself, it is still typed as
  heard: script practice (a deck that teaches the alphabet) and generated
  numbers.
- **Recognition is a lesson step, not a schedule.** Choosing the meaning
  and matching pairs still teach and check a word in its lesson, and are
  logged, but recognition is never due and never introduced as a new pair.
  Understanding in writing is taken from Write.
- **A right choice counts for less than a right recall:** a right choice in
  Hear or Write records 3 (Hard); recalling records as before. A right
  choice of a meaning seen, recognition, records 4, as it did.
- **Typed meanings** are graded by the answer grader, with the articles of
  the language the deck is taught from, against `Card.meanings`: the
  meaning whole, each part of it between `/`, `;` and `,` outside brackets,
  and `alt_native`.
- **The old log replays as it is:** dictation answers into Hear, production
  into Write, speaking into Say, grammar into grammar. Recognition answers
  stay in the log and schedule nothing.
- **No spill-over.** No schedule counts another's answers: the research
  supports nothing from sound to writing, or from saying to hearing.

## Consequences

- A learner's recognition reviews stop coming due. Their history stays.
- Hear's typed recall is in the language the learner speaks, so a near
  homophone (కలం pen, కాలం time) is caught by its meaning, not passed by
  its sound.
- A word chosen right in Hear or Write comes back sooner than one recalled.

## Alternatives considered

- **Renaming the modes** to `hear`, `say` and `write`: every row of
  `reviews` and `leech_actions` holds the old names, and both tables are
  append-only.
- **Recognition as Write's first rung:** it tests the opposite direction to
  Write. The owner chose lesson steps.
- **Dictation kept as Hear's recall:** it tests the form, not the meaning,
  so pen and time could not be told apart.
