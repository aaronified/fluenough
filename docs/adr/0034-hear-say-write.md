# ADR-0034: Recognition, Hear, Say and Write: four schedules per word

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

- **Four schedules per word: Recognition, Hear, Say and Write,** and
  grammar's. Hear is the `listening` mode, Write `production`, Say
  `speaking`. Recognition was first made a lesson step only; the owner
  then ruled it "a skill on its own right. The research says it is
  important" (2026-10-09), so it is scheduled like the others, and the
  recognition-only decks are reviewed. The names stay
  as they were: they are stored in the review log, which is never
  rewritten.
- **Hear asks for the meaning.** The word is played; its meaning is chosen
  while the pair is new or was last missed, and typed once it was last
  remembered. Where what is heard is the form itself, it is still typed as
  heard: script practice (a deck that teaches the alphabet) and generated
  numbers.
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
- **One answer judges its own skill, and in part the skills it implies**
  (`SkillMap`, a Q-matrix; owner, from `docs/research/skill-evidence.md`).
  Write and Say imply Recognition; Hear implies Recognition, and in script
  practice, where what is heard is written, Write. A right answer counts
  for half a review there (Pan & Rickard 2018, d 0.28 against 0.58;
  low confidence, to be fitted on the phone from the learner's own log):
  FSRS moves the implied pair's stability half way to a Good review, never
  its due date, and never starts a pair not yet asked; the ability layer
  moves the
  implied skill by half its own surprise. A miss counts against its own
  pair alone in FSRS; in the ability layer its blame is split the same way
  (owner, 2026-10-09: "a miss's blame split", Park et al. 2019).
- **The ability layer.** An Elo rating per language and schedule, and a
  difficulty per pair, each moved after every answer by how surprising it
  was, by K = 1 ÷ (1 + 0.05 n) after n answers (Pelánek 2016). Like the
  scheduling state it is rebuilt from the log. Progress shows it as "Your
  strengths": the chance of a right answer on a word of average
  difficulty, per skill, for one language. A pair never asked in Hear
  starts at recall rather than choice once the learner's Hear strength
  there is 80% or more over at least 20 answers.
- **Pictures** (owner: Noto Emoji, Apache-2.0): a card may name one emoji
  (`picture:`) for a concrete word. Write shows it above the meaning, and
  Hear beside each meaning it offers (Carpenter & Olson 2012). Only the
  images the decks use are bundled (`tools/pictures.py`). Each picture was
  matched by an agent and checked by another; abstract words, kinship and
  near misses get none.
- **A minimal-pair partner** can be named on a card (`pair:`); Hear offers
  its meaning among the options. కలం (pen) and కాలం (time) name each
  other.

## Consequences

- A word practised in Write comes due for Recognition later than it
  would alone, but no sooner.
- Hear's typed recall is in the language the learner speaks, so a near
  homophone (కలం pen, కాలం time) is caught by its meaning, not passed by
  its sound.
- A word chosen right in Hear or Write comes back sooner than one recalled.

## Alternatives considered

- **Renaming the modes** to `hear`, `say` and `write`: every row of
  `reviews` and `leech_actions` holds the old names, and both tables are
  append-only.
- **Recognition as Write's first rung:** it tests the opposite direction to
  Write.
- **Recognition as a lesson step only:** chosen first, then reversed by
  the owner: it is a skill of its own.
- **One weight, .68, between every pair of skills:** a correlation of
  vocabulary sizes across learners (Milton & Hopkins 2006), not of one
  word's skills; other studies give .46 to .88.
- **No credit across skills,** or **a full review for every skill a
  question touches:** the research finds transfer real but partial.
- **Dictation kept as Hear's recall:** it tests the form, not the meaning,
  so pen and time could not be told apart.
