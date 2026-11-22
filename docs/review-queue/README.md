# Review queue

The wiki is the source of truth for documentation: https://github.com/aaronified/fluenough/wiki

The review queue is a list of facets a deck builder doubts, kept beside the
decks and asked of a bilingual reviewer. It is a sidecar: the rows are not
part of any deck.

**Decision** (owner, 2026-11-06). Asked: "Questions for a bilingual reviewer:
will these be in the decks? and asked to the reviewer when they review?"
Answer: "go B". That is option B: one sidecar list per language that the
review bot reads. No deck-format change, and nothing ships to learners.

**Decision, builder questions v2** (owner, 2026-11-22): "Yes, go with option A
and add the checker. Also, the questions should be more about is this facet on
this card correct? Yes / options + free text. Do not try to invent questions
from the free text fields. That is inviting disaster." A builder no longer
writes a question: it names a card and the facet it doubts, and the app asks
one fixed question for that facet. The old free-text per-card rows are deleted
from the queue files by a separate change, never converted. Plan and formats:
[Plan-Builder-Questions-V2](../../wiki/Plan-Builder-Questions-V2.md).

## The files

- One file per language: `docs/review-queue/<lang>.md`, where `<lang>` is the
  deck code (`ta`, `zh`, `ja`, ...).
- Each file is a plain Markdown table with these columns, in this order. The
  header's third cell, `facet`, marks the v2 table; use exactly this header:

  | card id | unit | facet | concern (optional) | raised by | date |
  |---|---|---|---|---|---|

- **One row per doubted facet of a card**, never one per card and never a
  question. The facet is one of `word`, `reading`, `ipa`, `meaning`,
  `example`, `note`, `unit`, `offence`, `audio` (the facets of a card in
  review, `lib/core/review/facets.dart`). For one example write
  `example:<8 hex>`, the hash of that example's text (leave it off to doubt
  the examples as a whole). A facet the card does not have cannot be doubted:
  no `ipa` row for a card without an IPA, no `example` row without examples,
  no `note` without a note, no `audio` without a recording, and `offence` only
  for a card whose register is `offensive`.
- The **concern** is optional and short: at most 140 characters, a plain
  statement of what you are unsure of ("the vowel length is a guess"), never
  a question (no `?`) and never another card's id. The app shows it only as
  "The deck builder was unsure: ...". Leave it empty when the facet says it.
  Do not put a `|` inside a cell (write `\|`).
- At most one row for a card and facet.
- Use the card's real id. Never invent one.
- `raised by` names who raised it (`Haiku builder`, `Sonnet reviewer`, ...).
  `date` is the day it was raised, `YYYY-MM-DD`.
- A doubt about a unit or the whole course is not a row: write it in the
  unit's notes or an issue. (Old `unit-level` and `course-wide` rows may
  remain in the old table; they are never asked.)

## Who does what

- **Builders** add a v2 row for each facet they doubt when they finish a unit.
  The step is in [build-deck](../../.claude/skills/build-deck/SKILL.md), step
  7a. The rows go in the same commit as the deck.
- **The checker** (`tools/check_review_queue.py`) enforces the rules above
  for every v2 row: the card exists in the language's decks, the facet is
  allowed and the card has it, the concern is short and has no `?` or other
  card id, no card and facet twice. It exits 1 with a message naming the file
  and line. The feed generator runs it first and writes no feed while a row
  fails.
- **Reviewers** answer in the app. For a row, the app asks one fixed question,
  "Is the <facet> on this card correct?", with the card in full: Yes (it is
  correct as it is), or Needs a change with the facet's fixed options and a
  free-text line. The words of a question never come from a builder or from a
  card's text.
- **The review bot reads these files** (`tools/review_queue.py`, run by
  `.github/workflows/review-queue.yml` on decks-live after a change to a queue
  file or a deck). It writes `decks/review-queue.json`, which the app downloads
  from decks-live, as it does the deck index, when the daily questions open,
  and keeps for offline. v2 rows become the card's `asks` (`facet`, `ref`,
  `concern`, `by`, `date`); the file's `version` stays 1 and `asks_version` is
  2, so a released app that reads the file keeps reading it and ignores
  `asks`. Old rows still in a file keep their old places (`cards`,
  `unit_level`). A line that is not a row is skipped and reported.
- **Unknown ids** (not a card in the language's decks) are left out of the
  feed and listed in the run's summary, and the checker rejects a v2 row with
  one: fix the id or delete the row.

## How a row leaves the queue

A person removes it; the bot never edits these files. Two reviewers who agree
settle a row's question (the record in `review-answers/`: Yes means correct;
the same "Needs a change" option twice raises a flag note for the owner, and no
bot edits a deck for it). Delete the row once the answer is in the deck, or
the reviewer or the owner marks it answered (a pull request that deletes the
row, docs only). The run's summary lists the old rows' cards that two
reviewers signed off, which the app no longer asks about.

## What never goes in a deck

Deck builders and reviewers never put these flags in the deck YAML. Released
apps reject unknown card keys, so a flag written into a deck breaks the app
for learners. The queue is the only place a question lives.
