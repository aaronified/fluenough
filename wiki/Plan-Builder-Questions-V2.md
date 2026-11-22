# Plan: builder questions v2 (one fixed question per facet)

Source of truth: this wiki page.

Written 2026-11-22. Decision record: [ADR-0061](ADR-0061-Builder-Questions-Are-Facets-Not-Prose). Builds on [Plan-Reviewer-UX](Plan-Reviewer-UX) and [ADR-0058](ADR-0058-Reviewer-UX) (the facets and the pointer tags), [Plan-Reviewing-Scope](Plan-Reviewing-Scope) ("Builder questions") and `docs/review-queue/README.md`. Package 1 of 2 (queue format, checker, feed, answer records, Dart parsing) is in this change; package 2 (the app's screens) is specified below and not built.

## Owner decision

2026-11-22, on the choice between keeping builders' free-text questions and a structured form (option A): "Yes, go with option A and add the checker. Also, the questions should be more about is this facet on this card correct? Yes / options + free text. Do not try to invent questions from the free text fields. That is inviting disaster."

Second message the same day: the old per-card free-text rows will be **deleted** from `docs/review-queue/<lang>.md` on `decks-live` in a separate change. They are never converted, rewritten or re-derived into v2 rows. The `unit-level` and `course-wide` rows stay (and stay unasked).

## Why

A builder (an LLM) wrote the question text, and 844 offered rows show what that gives: "Should the note go?" on a word whose answer depends on gender (a Yes or No cannot answer it); a row on `hi-0335` that asks two things, names another card (`hi-0406`) and quotes a gloss that is already stale. Prose from a builder, or prose derived from any free-text field of a card, can be wrong in ways nobody sees. So no question text is ever authored or generated. The app asks a fixed question for a facet; the builder only says which facet of which card it doubts.

## The row (queue file format v2)

`docs/review-queue/<lang>.md` keeps its tables. A table whose header's third cell is `facet` holds v2 rows; any other header (or none) is the old table. A file may hold both while old rows remain.

```
| card id | unit | facet | concern (optional) | raised by | date |
|---|---|---|---|---|---|
| hi-0335 | hi-nouns-3 | ipa | the vowel length is a guess | Haiku builder | 2026-11-22 |
| hi-0340 | hi-nouns-3 | example:3f2a9c1d | | Haiku builder | 2026-11-22 |
```

- **facet**: exactly one of the nine of `lib/core/review/facets.dart` (`Facet.wire`): `word`, `reading`, `ipa`, `meaning`, `example`, `note`, `unit`, `offence`, `audio`. For `example` an optional `:<8 hex>` names one example: the `pointHash` (FNV-1a over the UTF-16 units of the trimmed text) of that example's `target`, the same hash the example question's point uses. Without it the facet means the card's examples as a whole. The key is the text hash, never a position, so reordering examples does not move a doubt.
- **concern**: optional, at most 140 characters, a plain statement (no `?`), no other card's id. It is context, shown as "The deck builder was unsure: ...", and is never turned into a question.
- A builder adds a row **only for a facet it doubts**. One row at most for a (card, facet). No question prose anywhere.
- Unit-level and course-wide doubts are not v2: they go in the unit's notes or an issue.

## The checker

`tools/check_review_queue.py` (tests: `tools/test_check_review_queue.py`) enforces, for every v2 row:

| Rule | Message names |
|---|---|
| six cells | the line, "exactly six cells" |
| card id is a card of the language's decks (`decks/<lang>/**.yaml`), not `unit-level` / `course-wide` | "is not a card of the zz decks", "only in the old table" |
| facet in the set | "is not one of: ..." |
| the card has the facet: `reading`, `ipa`, `example`, `note`, `audio` only when the card has one; `offence` only for `register: offensive`; `word`, `meaning`, `unit` always (the unit's path is not part of the card, so `unit` checks only the card) | "has no ipa to doubt" |
| `:ref` only on `example`, 8 hex, one of the card's examples | "is not an example of" |
| concern at most 140, no `?` or `？`, no `[a-z]{2,3}-\d{4}` other than the row's own card | each its own message |
| `raised by` set, date `YYYY-MM-DD` | |
| no second row for a (card, facet) | "second row for ..." |

The old rows are parsed, never checked, and counted in the report. Exit 0 clean, 1 on any violation, with messages of the form `docs/review-queue/zz.md line 7: ...`.

**Where it runs.** `tools/review_queue.py` (the feed generator, run by the review-queue workflow on `decks-live`) calls the checker first and, on any violation, prints the messages, exits 1 and writes **no** feed (no partial feed). That needs no new workflow: the decks-live job that already runs `tools/review_queue.py` fails. The tests run on main's CI with the other tools' tests (pytest over `tools/`). A decks-live pull request's own "Validate decks" job does not run the review-queue tool, so a follow-up (decks-live only, by hand, as that branch's workflows are) adds `python3 tools/check_review_queue.py` as a step of its CI beside the validator; until then a bad row fails the generator after merge, not before.

## The feed

`decks/review-queue.json`:

```
{"format": "fluenough-review-queue", "version": 1, "asks_version": 2,
 "languages": {"hi": {
   "cards": {},                       // the old shape: card -> [{question, by, date}]
   "unit_level": [],                  // old shape, unchanged
   "asks": {"hi-0335": [{"facet": "ipa", "ref": "3f2a9c1d", "concern": "...", "by": "...", "date": "..."}]}}}}
```

**`version` stays 1** (a decision of this package, not in the brief): released apps read `version`, and `ReviewQueue.parse` returns *empty* for any `version` above what it knows, so bumping it would blind every released app, including to the old notes it shows today. The new data is additive: `asks_version: 2` and `languages.<lang>.asks`, which a released app ignores. `cards` and `unit_level` keep their shape; once the old per-card rows are deleted `cards` is `{}`, and a language with only asks still carries `"cards": {}` (released apps require the key to be a map). `tools/test_check_review_queue.py` pins the old keys and values, and `test/review_queue_feed_test.dart` pins that the app reads old files and an unknown `asks_version`.

`asks` per card: facet, optional `ref` (example only), optional `concern`, `by`, `date`, in file order. The Dart side (`lib/core/review/review_queue.dart`) reads it into `BuilderAsk` (`ReviewQueue.asksFor(language, card)`), at most one per facet, concern cut at 140. No UI uses it yet.

## The question the app asks (package 2)

One fixed question per ask, from ARB only: "Is the <facet> on this card correct?" Nine strings (no placeholders, so every language can word the facet properly):

| Facet | ARB key (proposed) | English |
|---|---|---|
| word | `builderAskWord` | Is the word on this card correct? |
| reading | `builderAskReading` | Is the reading on this card correct? |
| ipa | `builderAskIpa` | Is the IPA on this card correct? |
| meaning | `builderAskMeaning` | Is the meaning on this card correct? |
| example | `builderAskExample` | Is the example on this card correct? |
| note | `builderAskNote` | Is the note on this card correct? |
| unit | `builderAskUnit` | Is this card in the right unit? |
| offence | `builderAskOffence` | Is the offence rating on this card correct? |
| audio | `builderAskAudio` | Is the recording on this card correct? |

With a `ref`, the same question is asked and the one example is highlighted in the card view; the question does not quote it.

**Screen.** The existing step "Question from the deck builder" (`daily_questions_page.dart`), asked first for cards that have asks, keeps its layout: heading = the fixed question; the card in full beneath (word, reading, meaning, every example), the asked facet visually marked; when the ask has a concern, one quiet line above the answers, `builderAskConcern`: "The deck builder was unsure: {concern}" (the concern is shown as given and is never parsed or turned into anything). Buttons:

1. **Yes, it is correct** (`builderAskYes`): answer `yes`. Always means "correct as it is", never "remove".
2. **Needs a change** (`builderAskNeedsChange`): opens the sheet with the facet's fixed options (list below) as single-choice rows, then an optional one-line free text (`why`, the same field and channel as every other kind, 200 characters as now), then Send.
3. Skip, as now.

Every non-Yes answer has the free-text line. A non-Yes needs exactly one option; the last is always `something_else` ("Something else", `builderAskSomethingElse`).

**Options per facet** (the reviewer UX's pointer tags for that facet, in `PointerTag` order, then `something_else`; labels are the existing `reviewTag*` ARB strings, so no new option strings except `something_else`):

| Facet | Options (reason keys) |
|---|---|
| word | `spelling_wrong`, `unnatural_or_rare`, `wrong_register`, `offensive`, `something_else` |
| reading | `reading_wrong`, `something_else` |
| ipa | `ipa_wrong`, `something_else` |
| meaning | `meaning_wrong`, `unnatural_or_rare`, `wrong_register`, `offensive`, `something_else` |
| example | `spelling_wrong`, `unnatural_or_rare`, `wrong_register`, `offensive`, `example_wrong`, `something_else` |
| note | `note_wrong`, `something_else` |
| unit | `wrong_unit`, `something_else` |
| offence | `offensive`, `something_else` |
| audio | `audio_wrong`, `something_else` |

`tools/question_answers.py` `BUILDER_OPTIONS` holds the same lists, and a test keeps them equal to `review_facets.TAG_FACETS` plus `something_else`. In the app, build them from `PointerTag` (`tags.where((t) => t.facets.contains(facet))`) so the two cannot drift. Open for the owner: the label "Offensive" on the offence facet reads oddly (the rating, not the word, is in doubt); package 2 may show it as "The rating does not fit" without changing the key.

**Answer record.** The mail's `fluenough-questions` file keeps its shape and `version: 1`:

```
{"card": "hi-0335", "point": "builder:ipa", "kind": "builder",
 "answer": "yes" | "no", "reason": "<option key>", "why": "<free text>"}
```

- `kind: builder`, `point: builder:<facet>` (the facet's wire name). The point is derived from the card and facet, so one (card, facet) is one point and the bot's key is `hi-0335|builder:ipa`. The old `builder:<8 hex>` points stay readable.
- `answer`: `yes` is "it is correct"; `no` is "Needs a change" (the wire value stays `no`: `QuestionAnswer` and every released bot parser know `yes` and `no`, and a new wire name would be dropped by them). `reason` is present only on `no`, one of the facet's keys; one from another facet is dropped and the answer kept. `why` stays in the mail, never in the record.
- In Dart: `QuestionKind.builder.reasons` is `[]` today; package 2 makes the reasons depend on the point's facet (a function of the facet, not a per-kind constant), and `ReviewQuestion.point` for a v2 ask is `builder:<facet>`. `ReviewQuestion.asked` is not used for v2 (nothing authored is displayed as the question); the concern goes in a new field.

**Server side** (built in this package, `tools/question_answers.py`): the quorum is unchanged (`REVIEW_QUORUM` 2, `agreements + 1`). Two different rater codes saying `yes` settle the point as correct (`settled: "yes"`, never written to a card's `verified`). A first `no` flags the point; a second code's `no` with the **same option** merges the flag (`settle_no`: `settled: "no"`, a flag note for the owner, and no deck edit by any bot for a builder question); a `no` with a different option waits open for a code that agrees; a `yes` from another code closes it for good, as for every kind.

## What is built where

| Package | Content | Status |
|---|---|---|
| 1 (this change) | this page and ADR-0061; `docs/review-queue/README.md` and `build-deck` step 7a; `tools/review_queue.py` (v2 parse, feed, refuses a rejected row), `tools/check_review_queue.py`, `tools/question_answers.py`; their tests; the Dart parsing (`BuilderAsk`, `asksFor`) | built |
| 2 | the screens, ARB strings, buttons, `ReviewQuestion` fields, the question generator reading `asksFor` and the mail's new points (the old per-card builder path can go once the old rows are deleted) | to do, from this page |
| Separate | delete the old per-card rows on decks-live (never convert); add the checker to decks-live's CI by hand; deck builders write v2 rows | owner / deck work (paused) |

No CHANGELOG line: nothing here is visible to a learner or a reviewer yet (docs, tools and a parser nothing calls).

See also: [ADR-0061](ADR-0061-Builder-Questions-Are-Facets-Not-Prose) · [Plan-Reviewer-UX](Plan-Reviewer-UX) · [Plan-Reviewing-Scope](Plan-Reviewing-Scope) · [Plans-Index](Plans-Index) · [Home](Home)
