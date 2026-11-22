# ADR-0061: Builder questions are facets, never prose

Source of truth: this wiki page.

- **Status:** Accepted (owner, 2026-11-22). Package 1 of the plan is built; package 2 (the app's screens) is not. The reasoning, the formats and the work packages are in [Plan-Builder-Questions-V2](Plan-Builder-Questions-V2).
- **Date:** 2026-11-22

## Context

A deck builder that doubts a card wrote a free-text question into `docs/review-queue/<lang>.md`, and the app asked it as a Yes or No ("go B", 2026-11-06). The 844 rows written that way are LLM prose, and many cannot be answered Yes or No ("Should the note go?" on a word whose answer depends on gender), ask two things, name another card, or quote a gloss that has since changed. A No only raised a flag note for the owner.

## Decision

Owner, 2026-11-22: "Yes, go with option A and add the checker. Also, the questions should be more about is this facet on this card correct? Yes / options + free text. Do not try to invent questions from the free text fields. That is inviting disaster."

1. **A builder question is a facet of a card, not a sentence.** A queue row names a card id, one facet of the reviewer UX vocabulary (`word`, `reading`, `ipa`, `meaning`, `example`, `note`, `unit`, `offence`, `audio`; for `example`, optionally which one by the hash of its text) and an optional concern of at most 140 characters that is a plain statement and is shown only as "The deck builder was unsure: ...".
2. **The app asks one fixed question per facet**, "Is the <facet> on this card correct?", from the app's strings only. Answers: Yes (correct as it is, never "remove"), or Needs a change with the facet's fixed options (the facet's pointer tags, then Something else) and a free-text line. No question text is authored by a builder or generated from a card's notes, glosses, examples or the concern.
3. **A checker enforces the rows** (`tools/check_review_queue.py`): the card exists, the facet exists on the card, the concern is short, has no `?` and names no other card, one row per card and facet. The feed generator refuses to publish while a v2 row fails it.
4. **The old per-card free-text rows are deleted** from the queue files (by a separate change on decks-live), never converted, rewritten or re-derived. The `unit-level` and `course-wide` rows stay and stay unasked.
5. **The feed adds, never changes.** `version` stays 1 (a released app ignores a file whose version it does not know, so a bump would blind it); `asks_version` 2 and a per-card `asks` list are new keys; `cards` and `unit_level` keep their shape.
6. **Answers reuse the existing record**: `kind: builder`, `point: builder:<facet>`, `answer: yes` or `no` with the option as `reason`. Quorum is unchanged: two codes agreeing settle it (Yes: correct; the same option on a No: the owner's flag note, with no deck edit by any bot).

## Consequences

- Builders can no longer say anything a reviewer must interpret: the cost is that they cannot express a doubt that is not about a facet (such a doubt goes in the unit's notes or an issue).
- A facet's option list is the pointer-tag list: a new pointer tag appears in builder questions with its facet, and `tools/question_answers.py` and its test keep the two equal.
- Until package 2 ships, the app asks no builder question from v2 rows; the rows wait in the feed.

See also: [Plan-Builder-Questions-V2](Plan-Builder-Questions-V2) · [ADR-0058](ADR-0058-Reviewer-UX) · [ADR-Index](ADR-Index)
