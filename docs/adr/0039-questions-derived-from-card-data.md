# ADR-0039: Questions are derived from card data

- **Status:** Accepted (owner, 2026-10-13, #506). The owner approved, one by one: the principle that questions are derived from card data, whatever the card's kind; the answers to the open questions of `docs/plans/question-engine.md`; the ability rule ("This is approved as proposed"); the set card shape (kind `set`, members by card id, explanation in the layer, closed groups listed per language); and the exam answers on reading passages (#509), which replace the earlier "scheduled as a whole" decision. What the plan marks **Proposed** (the step order, the registry's names and the other card data fields) is not part of what was approved.
- **Date:** 2026-10-13
- **Amends:** ADR-0024 (which question each skill is asked as), ADR-0034
  (Hear asks for the meaning; the skills stay as they are).
- **Plan:** `docs/plans/question-engine.md`. The card data it relies on is
  listed in `docs/plans/card-data.md`.

## Context

The owner decided on 2026-10-13 (#506): "a simple card should be able to
generate all kinds of questions", so questions must be agnostic of card
type. The card data is to grow to match: "not just example sentences. we
need also synonyms, antonyms, root word, meaning, minimal pairs, phonemic
contrasts, facts, images, etc on each card, as applicable. some would be
mandatory, others will be optional."

Today the question follows the card's kind, not its data:

- the grammar questions (`chooseForm`, `chooseFormMeaning`) exist only for
  a rules cell (`card.rule != null`);
- `lessonQuestions` is a switch on the card's kind;
- rearranging is gated by word count or by `pos == phrase`;
- `modes` is written by the author and doubles as the marker of a kind;
- reading questions are a `QuestionCard` with a mode of their own, scheduled
  like cards (they move to exams, below);
- numbers are a special card class;
- whether Hear asks for the form or the meaning depends on the deck being
  in the path's alphabet list;
- the wrong options are drawn by the card's kind and class;
- a pattern carries an author-written question template (`prompt`).

So each planned type (cloze, sentence bank, word-order extras, listening
in context, explaining mistakes, the IPA course, handwriting, audio
drills) would add one more special case. The audit is in
`docs/plans/question-engine.md`.

## Decision

- **A `QuestionType` registry.** Each type is one entry. It declares:
  - its **skill**: one of the existing `DrillMode` values. `DrillMode` is
    the skill label and nothing more. The review log is append-only, so a
    `DrillMode` name never changes and no value is removed;
  - **`eligible(card)`**: true when the card has the data the question
    needs. Nothing else decides it;
  - **how it grades**: choice, typed, ordered, spoken or matched, and what
    a right answer records (ADR-0034's grades stay);
  - its **distractor source**, drawn from card data: the same `pos`, the
    same theme or tags, the `pair` partner, `bases`, confusables, the other
    forms of the same word.
- **Selection is by data.** The engine asks the registry for the types
  eligible for a card in a skill, and picks one. No question is selected
  by a deck's kind, a card's class, or the deck's membership of a path.
- **`modes` becomes an opt-out.** It lists the skills a card is excluded
  from, and nothing more. It no longer marks a kind of card, and an
  absent `modes` means every skill the data allows. A script converts the
  existing decks, then a review reads the result (owner: "A script
  converts, then a review").
- **A type is asked wherever its data exists.** There is no coverage floor
  per language (owner: "Ask it where the data exists").
- **The type is picked by ability.** The same card and skill may be asked as
  different types: easier ones while the card is new or failing, harder
  ones as it gets stable, a miss stepping back one, the pick seeded per card
  and day. All grade the same skill schedule (owner: "Yes, picked by
  ability"; the rule "approved as proposed", 2026-10-13).
- **A reading passage is an exam item, never reviewed or scheduled.**
  Owner, 2026-10-13: "All passages are part of "exams", for placements and
  for milestones. User can retake them, but not via review." Reading
  questions are asked only in exams (placement, #481, and the B1 milestones,
  #509). Exam answers move the words' FSRS schedules like any practice, a
  milestone exam is required to continue, a pass is 80% overall with each
  skill at least 60%, and on a fail the missed units and words are pushed to
  review and the retake opens the next day after those reviews. Learners
  already past a milestone when it ships are offered the exam, not blocked.
  The registry's review types never return a reading question.
- **Fields first.** The format and validator for the new card data come
  first so decks can be filled; the engine follows (owner: "Fields first").
- **Neutral card data, not per-question fields.** A card does not carry
  "its cloze", "its Hear options" or "its question". It carries what is
  true of the word (`docs/plans/card-data.md`), and each type reads that.
  Where a type needs something nobody can derive, such as the wrong
  alternatives of a sentence, the field is a shared one with a neutral
  name that several types read: `confusables` (owner: "One shared list"),
  whose shape is in the card data plan. A card without it gets confusables
  generated from its card data.
- **Numbers and rules cells are cards with data.** A number is a card whose
  forms are generated. A rules cell is a card with a `rule`. Each is
  eligible for a type because of what it has, not because of what it is.
  Reading passages are not cards of review: they are exam data (above).
- **A set card is taught, never scheduled or asked.** A closed group (the
  articles, the pronouns) is introduced by one card that lists its members
  (owner, 2026-10-13: "Teach only"; "Every closed group"; "Show the whole
  set; drill only new ones"). No question type is eligible for it, and it
  has no schedule entry or log key. The lesson builder shows it before its
  members, marks the ones already taught, and drills only the new ones, with
  known ones as review when due. Its members are ordinary cards. The shape
  is approved (owner, 2026-10-13): kind `set`, members by card id, the
  explanation in the layer, closed groups listed per language, in
  `docs/plans/card-data.md`.
- **Nothing is rewritten.** Existing cards, ids and log entries stay valid;
  card ids are permanent.
- **`lib/core` stays free of Flutter.** The registry is plain Dart; pages
  only draw the question a type returns.

## Consequences

- A new question type is one registry entry and its tests, plus its page.
  It reaches every card that has its data, without a change to the decks.
- Richer cards make more questions without being touched again. A card
  with an antonym can be asked its opposite; one with a pair, a minimal
  pair question.
- Coverage decides what is asked. Today examples are 0 on hi/bn/te, audio
  is 0, bases are 17 to 28%, so some types stay silent on most cards until
  the data is filled. The registry makes the gaps countable.
- `reviewAsks` and `lessonQuestions` get smaller, then go. During the
  migration both run, and every step keeps all tests passing.
- The `Ask` values are the pages' contract and stay until each page is
  moved.

## Alternatives considered

- **Keep the kind switches and add a case per new type:** each planned
  type adds a branch to six places, and a card of another kind can never
  be asked it.
- **Author a question list on each card** (`questions:` with prompt and
  options): it is what `pattern.prompt` already does, and it is the cost
  the owner's decision removes. It cannot be reviewed in bulk and cannot
  change when a type improves.
- **New `DrillMode` per question type:** the log would hold names the
  scheduler must keep for ever, and the skills (ADR-0035) are fitted per
  mode. A type belongs to a skill; it is not one.
- **Generate questions with a model at run time:** not offline, not
  checked by reviewers, and not repeatable.
