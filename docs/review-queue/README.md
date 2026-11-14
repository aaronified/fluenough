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
- The question is one line that a bilingual reviewer can answer **with Yes or
  No**, written as a question that ends in `?`, and it names the item it is
  about ("Is the example sentence X right for Y?"). The app shows the card in
  full beside it (word, reading, meaning and every example), but the question
  must still say which part it means. A note that is not a question ("death
  year uncertain: 1890 or 1891", "source unverified") is not offered to
  reviewers: put it in the unit's notes or an issue instead.
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
- **Reviewers** answer in the app, as they do now. A card with a row gets
  the builder's question as a daily question of its own, **Question from the
  deck builder**, asked first: the question is the heading, the card is
  shown in full, and its own Yes and No answer only that question. The
  question also shows as a note in the card's review sheet. Rows whose text
  is not a question ending in `?` are left out of what reviewers see.
- **The review bot reads these files** (`tools/review_queue.py`, run by
  `.github/workflows/review-queue.yml` on decks-live after a change to a queue file
  or a deck). It writes `decks/review-queue.json`, which the app downloads
  from decks-live, as it does the deck index, when the daily questions open, and
  keeps for offline. Rows with a card id become that card's builder
  questions (at most three show per card); `unit-level` and `course-wide`
  rows go in the file's `unit_level` list and never choose a card. Spacing,
  backticks around an id and a missing header are tolerated; a line that is
  not a row with a question is skipped and reported.
- **Unknown ids** (not a card in the language's decks) are left out of the
  feed and listed in the run's summary. The run does not fail. Fix the id or
  delete the row.

## How a row leaves the queue

A person removes it; the bot never edits these files. A builder's question is
free text ("is gender m right?"), and it may be about a field a sign-off does
not cover, so deleting a row because a card was signed off could drop a doubt
nobody answered. The run's summary instead lists the **settled** cards: those
two reviewers signed off (two codes in `checked_by`), which the app no longer
asks about. Delete such a row once the answer is in the deck, or the reviewer
or the owner marks it answered (a pull request that deletes the row, docs
only, straight to main). A card nobody can be asked about any more (every
data point verified) keeps its row until someone deletes it.

## What never goes in a deck

Deck builders and reviewers never put these flags in the deck YAML. Released
apps reject unknown card keys, so a flag written into a deck breaks the app
for learners. The queue is the only place a question lives.
