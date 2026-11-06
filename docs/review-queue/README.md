# Review queue

The wiki is the source of truth for documentation: https://github.com/aaronified/fluenough/wiki

The review queue is a list of questions a deck builder could not settle, kept
beside the decks and asked of a bilingual reviewer. It is a sidecar: the
questions are not part of any deck.

**Decision** (owner, 2026-11-06). Asked: "Questions for a bilingual reviewer:
will these be in the decks? and asked to the reviewer when they review?"
Answer: "go B". That is option B: one sidecar list per language that the
review bot reads. No deck-format change, and nothing ships to learners.

## The files

- One file per language: `docs/review-queue/<lang>.md`, where `<lang>` is the
  deck code (`ta`, `zh`, `ja`, ...).
- Each file is a plain Markdown table with these columns, in this order:

  | card id | unit | question for the reviewer | raised by | date |
  |---|---|---|---|---|

- One row per card the builder is unsure of: gender, part of speech, reading
  or tone, a doubtful note, a traditional form, naturalness, a missing phrase.
- Keep each row to one line. Do not put a `|` inside a cell (write `\|`).
- The question is one line that a bilingual reviewer can answer.
- Use the card's real id. Never invent an id.
- A question about a unit or a deck, not one card, uses `unit-level` in the
  card id column, and the unit column names the unit (with its id range where
  known). A question about the whole course uses `course-wide`.
- `raised by` names who raised it (`Haiku builder`, `Sonnet reviewer`, ...).
  `date` is the day it was raised, `YYYY-MM-DD`.

## Who does what

- **Builders** add a row for each doubtful card when they finish a unit. The
  step is in [build-deck](../../.claude/skills/build-deck/SKILL.md), step 7a.
  The rows go in the same commit as the deck.
- **Reviewers** answer in the app, as they do now. A card a reviewer settles
  loses its row: delete the row when the answer is in the deck.
- **The review bot** (a later code change, not yet built) reads these files,
  asks the listed cards first, and attaches the question to each. Until it
  exists, the files are a list for people to work through.

## What never goes in a deck

Deck builders and reviewers never put these flags in the deck YAML. Released
apps reject unknown card keys, so a flag written into a deck breaks the app
for learners. The queue is the only place a question lives.
