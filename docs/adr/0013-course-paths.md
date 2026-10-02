# ADR-0013: Each course is taught along a curated path, as data

- **Status:** Accepted
- **Date:** 2026-10-02

## Context

On a first install the app taught every language in the catalog at once, in
file order. A Bengali speaker was taught Bengali first, starting with words in
a script nobody had taught them (#117). First launch asked which languages the
learner speaks (#53), never which they want to learn or what they already
know. ADR-0010 gave each course's theme decks an order, but a course's grammar
decks kept their alphabetical place in the middle of it, so about 200 grammar
cells came before Market (#80). An order is not a curriculum.

The maintainer decided, on 2 October 2026:

- one path file per course, not an extension of `themes.yaml`;
- a placement drill to find what the learner already knows, rather than
  asking them to say;
- that Today's new cards come from the current unit and the next one, mixed;
- that every course's first three units are its **alphabet**, its **sound
  differences** and its **basic grammar differences** from the language it
  is taught from, and that each is drilled in every skill: recognition,
  listening, speaking and writing. For Hindi, Bengali and Telugu they follow
  as content.

## Decision

- **A course's path is a file of its own,** `decks/<lang>/<lang>-<native>-path.yaml`,
  `kind: path`. It lists the course's decks in teaching order, in **units**:
  a unit is what is taught together, such as a theme deck and the grammar
  that goes with it, or a script. Every deck of the course is on its path
  exactly once, and only the course's decks; the validator checks it. Adding
  a unit is an edit to the file, with no code.
- **The catalog orders a course's decks by its path.** A course without one
  falls back to its theme decks in theme order and then its other decks, so
  grammar no longer lands mid-path (#80).
- **The learner chooses what to learn,** on first launch, and can change it
  in Settings. The default profile stops learning every language.
- **Placement is a short drill per language.** It works through the path a
  unit at a time and stops at the first unit the learner does not know.
  Every unit before that one is **placed**. Placement is not recorded in
  `reviews`, which is append-only (ADR-0005): it stores only which units were
  placed, as a setting. A placed unit is not invented as learned. Its decks
  read Done, and they can still be opened and studied.
- **Pending is the current unit and the next.** The current unit is the
  first one neither placed nor finished. Today takes new cards only from the
  pending units of the languages being learned, mixing the two. Reviews come
  from everything already learned, as before.
- **Nothing is locked.** Any deck can still be opened and started from the
  Decks tab, as ADR-0010 and #53 decided.

## Consequences

- Deck order is a deck-format decision now, made per course. Contributors
  adding a deck must add it to their course's path, and the validator fails
  them until they do.
- Each course orders its own grammar. This supersedes ADR-0010's ordering,
  where every course followed the shared theme order and grammar stayed out
  of it. The theme list itself stands.
- Placement can be wrong. A lucky guess places a unit the learner doesn't
  know, which is why each unit asks more than one question. A placed unit's
  decks can still be studied in full.
- Placement leaves no history to learn from. Statistics and streaks count
  only real reviews.
- A path can only list decks that exist. Until the alphabet, sound and
  grammar-difference decks are written for Hindi, Bengali and Telugu, those
  paths start at their first words, which carry a romanised reading. A
  speaking drill does not exist yet (#89), so until it does those units are
  drilled in the other three skills.

## Alternatives considered

- **Extending `themes.yaml`** with script and grammar units for every
  language. One file is easier to keep in step, but script decks and grammar
  topics differ by language, so it would need per-language exceptions.
- **Asking the learner what they know,** in three answers: complete beginner,
  can read the script, knows some words. It is simpler, but self-report is
  coarse, so the maintainer chose a placement drill.
- **One pending unit at a time.** A stricter order, but a day's new cards
  would all come from one deck. The maintainer chose a window of two.
- **Leaving grammar out of Today's new cards** (#80's alternative). That would
  change what Today means. Placing grammar in units keeps it in the course.
