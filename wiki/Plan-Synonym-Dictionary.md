# Plan: synonym sets for typed English meanings

Source of truth: this wiki page.

Decision record: [ADR-0050](ADR-0050-English-Synonym-Sets). Issue: #924 (part 2).
Part 1 (rewriting unseparated alternatives as `;`, then a validator rule) is
not this plan.

## Owner's decisions (2026-10-30, #924)

1. Scope: English answers first; target-language synonyms later, per course.
2. Source: all three: a shared file, per-card alternates in the decks,
   reviewers through the review flow.
3. Grading: a synonym is right; the reveal shows the card's own answer with
   a short hint ("Also: take care"). Not close, not silent.
4. The data is sets: each set a list of English words or phrases, every
   member accepting every other.
5. Only words absolutely synonymous in all situations. No sense-dependent
   pairs. Regional spelling variants (colour / color, grey / gray,
   favourite / favorite, organise / organize) must be included: they are the
   first and safest kind of set, so they are seeded first. The poke-holes
   pass still checks each.
6. Every list gets a Sonnet "poke holes" pass before it ships.

## What exists

- `lib/core/grading/meaning_rules.dart`: seven rules (case and punctuation,
  contractions, bracketed qualifiers, `;` alternatives, leading "to", ok,
  please). `AnswerGrader(meaning: true)` uses them in pass 1, then
  diacritics, then typo distance (1, or 2 from eight letters, none under
  three).
- `alt_native` on a layer card, and `;` in `native`: per-card alternates,
  already accepted.
- Reviewer proposals (ADR-0038) with fields `target`, `reading`, `ipa`,
  `native`, `notes`.
- Sources screen lines for Wiktionary (`sourcesPhoneticLine`).

## Design in one page

| Question | Answer |
|---|---|
| Format | `assets/synonyms/en.yaml`: `version: 1`, then `sets:` and one `- ["a", "b"]` per line. Quoted, comparison form, sorted, header with licence |
| Seeding | `tools/english_meanings.py` lists meanings by frequency; Haiku drafts; Sonnet pokes holes; survivors merge |
| Validation | `tools/validate_synonyms.py` in CI |
| Where read | `lib/core/grading/synonym_sets.dart` (pure Dart, no Flutter); loaded from the bundle in `lib/app/` and passed to the grader |
| Size / offline | bundled, a few thousand sets, under 300 KB; parsed once on the first typed-meaning answer |
| Matching | after exact and diacritics, before typo; whole answer; regular inflection with equal endings; no typo on synonyms |
| Wrong sense | sets are absolute only; `not_synonyms` on the layer card as the escape |
| Reviewers | proposals `alt_native_add` and `not_synonyms_add` (needs the owner's nod) |
| Reveal | the card's own answer, hint `Also: {typed}` or "Also right" |
| Licence | CC BY-SA 4.0; a Sources line |

## The seeding workflow (owner's rule)

1. **List** (`tools/english_meanings.py`, no model): every course's English
   meanings, `native` and `alt_native` of the layers, split by `;`,
   normalised as the grader does, counted by cards and ordered by count,
   then by the deck priority in CLAUDE.md. Writes batches of about 200 to
   the scratchpad, not the repo.
2. **Draft** (Haiku, one agent per batch). Batch 0 is the regional
   spelling variants of the course meanings (-our / -or, -ise / -ize,
   -re / -er, doubled l, grey / gray and the like, plus the owner's list),
   seeded before any other batch. From a batch and nothing else but
   Wiktionary and Open English WordNet as references, write sets of words
   or phrases interchangeable in every situation. Leave a meaning out when
   unsure. Output: the YAML lines.
3. **Poke holes** (Sonnet, one agent per batch, independent of the drafter):
   for each set write the best counterexample (a sentence where a member
   cannot replace another), check register (formal, informal, slang, rude,
   dated), grammar (countable or not, transitive or not, the preposition
   that follows), and meaning in British, American and Indian English. A
   set with a counterexample is struck; a set with a doubt is struck. The
   survivors and the struck sets, with the reason, are the output. The
   regional-spelling pairs pass.
4. **Merge** (a batch PR): only survivors go in the file, sorted; the PR body
   lists the struck sets. CI's validator passes; this Sonnet pass is the PR's
   one review (CLAUDE.md), and a second runs only on a breaking bug.
5. **Never by hand and never wholesale:** no import of a thesaurus or of
   WordNet synsets; every set went through 2 and 3.

## Open questions already decided by the owner (not asked again)

The scope, the three sources, the grading, "sets", "absolutely synonymous
only" and the poke-holes gate (above).

## PR-sized steps

| # | Step | Who | Size | Milestone |
|---|---|---|---|---|
| 1 | ADR-0050 and this plan, wiki pages and pointers | Sonnet | done | 0.6.0 |
| 2 | `synonym_sets.dart` (parse, equivalents) and the grader's synonym pass with `viaSynonym`; behaviour tests with made-up words | Sonnet | M (about 300 lines with tests) | 0.6.0 |
| 3 | `tools/english_meanings.py`, `tools/validate_synonyms.py`, tests; an empty-but-valid `assets/synonyms/en.yaml`; the CI job; `pubspec.yaml` assets line and the loader in `lib/app/` (its own small PR for `pubspec.yaml`) | Sonnet | M | 0.6.0 |
| 4 | Reveal hint `Also: ...`, l10n tokens, Sources line (CC BY-SA); mockup of the reveal if the owner wants one | Sonnet | S | 0.6.0 |
| 5 | Seed batch 0 (regional spelling variants), then batch 1 (the 200 commonest meanings), through draft and poke | Haiku, Sonnet | S per batch | 0.6.0 |
| 6 | Seed batches 2 to N, one PR each; content, so it stays out of the CHANGELOG (owner, 2026-10-19) | Haiku, Sonnet | S per batch, as many as the owner wants | rolling |
| 7 | `not_synonyms`: field in the card model and docs/DECK-FORMAT.md, the validator's rules, the cross-check; decks use it a release later | Sonnet | M | 0.6.x, after the owner's nod |
| 8 | Sibling-clash warnings tool (cards of a deck in one set) | Sonnet | S | 0.6.x |
| 9 | Reviewer proposals `alt_native_add`, `not_synonyms_add` in `tools/proposals.py`, `tools/review_bot.py`, reviewer mode UI; candidate-set report | Sonnet | L | 0.7.0 with the reviewer-mode overhaul |

Steps 2 to 4 are about a week of one Sonnet, in three PRs; each batch of step
5 and 6 is an hour or two of a Haiku plus a Sonnet. Step 9 depends on #508,
#922 and the reviewer-mode overhaul: mark "blocked by" on GitHub when the
issues are made (CLAUDE.md, dependencies are marked).

## Tests

Behaviour only (AGENTS.md, "Tests check behaviour"); words are made up,
never from a real language.

Dart (about six): a member of a set is accepted for another and the reveal
carries the flag; the card's own answer and `alt_native` still win and are
not flagged; an inflected member matches only with the same ending; a
`not_synonyms` entry blocks; a typo of a member is not accepted while a typo
of the card's own answer is; a malformed file is no sets and grading is as
before.

Python (about five): each refusal of the validator on a fixture with made-up
words (a word in two sets, a set of one, an unsorted file, a member not in
comparison form, a dead `not_synonyms`); the meanings list counts and orders
by frequency. A shared JSON list of normalisation cases is read by both
suites so the Python `meaningKey` and the Dart one cannot drift.

## Questions for the owner

1. **How does a new set reach learners?**
   - A: bundled in the app, so it ships with a release. Downside: a good
     set waits for the next release.
   - B: kept with the decks and downloaded from `main` (ADR-0037), so it is
     live the next day. Downside: a second thing the index, the validator
     and the offline first launch must handle; an older app needs the
     bundled copy anyway.
   - Recommendation: A first, B once the file grows.
2. **Does a synonym replace only the whole answer, or a word inside a
   longer answer?**
   - A: whole answer only ("mind" for "careful"). Downside: "it is big"
     is not accepted for "it is large".
   - B: also one word of a longer sentence, from the same sets. Downside:
     grammar around the word ("a" / "an", agreement) breaks, and it
     accepts sentences that read oddly.
   - Recommendation: A.
3. **Is a typo of a synonym forgiven?**
   - A: no. Downside: "colur" is wrong for a card "color" typed as
     "colour"; the learner must spell it.
   - B: one letter from five letters up, graded "close". Downside: two
     forgivenesses stacked accept real other words.
   - Recommendation: A.
4. **May a card carry `not_synonyms`?** It is a deck-format field (the
   escape the owner's rule needs), so it needs your nod. Decks use it only
   a release after the app reads it.
   - A: yes, a list of typed answers refused for this card. Downside: a new
     field every older app rejects until the release.
   - B: no field; remove or split the set instead. Downside: one wrong
     card removes a good set for everyone, and waits for a release.
5. **May a reviewer propose accepted answers?** New proposal fields
   `alt_native_add` and `not_synonyms_add` change the ADR-0038 format and
   the review bot.
   - A: yes, both. Downside: more bot code, and an older reviewer app
     cannot send them.
   - B: only `alt_native_add`; wrong accepts go to the owner as issues.
     Downside: a wrong accept is not fixable by reviewers.
   - C: neither; reviewers write to the owner. Downside: the reviewer flow
     of the decision (source three) does not exist.
6. **What does "no word that also appears as a card's `not_synonyms`" mean,
   and how strict?** This plan reads it as: a `not_synonyms` entry must name
   a member of a set that has a partner among the card's answers (else it
   does nothing), and a set escaped on two cards or more fails CI.
   - A: that reading, with the threshold two. Downside: a hard failure on
     two escapes may block an unrelated deck PR; the fix is a PR to the set
     file.
   - B: warn only, never fail. Downside: a bad set stays in the file.
   - C: you meant that no set member may appear in any card's
     `not_synonyms` at all. Downside: then the escape cannot be used for
     any word in a set, and is pointless.
7. **Two cards of one deck whose answers are in one set** (a deck teaching
   sofa and couch separately).
   - A: warn the author; the synonym is accepted anyway. Downside: the
     learner may type the other card's word and be right.
   - B: refuse a synonym that is the answer of a sibling card. Downside:
     the card's answer set depends on the deck, which is harder to test.
   - Recommendation: A.
8. **Is a Wiktionary / WordNet credit owed** for sets a model wrote from
   its own knowledge and checked against them?
   - A: credit anyway, CC BY-SA 4.0. Downside: possibly an unneeded
     credit.
   - B: credit only sets taken from an entry. Downside: nobody can prove
     which they were.
   - Recommendation: A.
9. **When do steps 7 and 9 go?** Weeks run 0.6.x and 0.7.x (owner,
   2026-10-23).
   - A: sets, grading, hint in 0.6.0; `not_synonyms` in 0.6.x; reviewers
     in 0.7.0. Downside: reviewers wait.
   - B: all in 0.7.0. Downside: the "extremely bad experience" stays
     longer.
   - Recommendation: A.
10. **Hint wording for a long typed answer.** "Also: {typed}" is the
    owner's example; a hint is one or two words with no full stop.
    - A: "Also: {typed}" for up to two words, "Also right" beyond.
      Downside: two strings.
    - B: always "Also right". Downside: the learner is not shown which of
      their words counted.
    - C: always "Also: {typed}". Downside: breaks the hint rule when long.
11. **Irregular forms.** Regular endings are found by rule.
    - A: irregular forms of a member are sets of their own. Downside: the
      author remembers them; the Sonnet pass checks them.
    - B: a small irregular table in the file. Downside: a second format in
      a list of lists.
    - Recommendation: A.

See also: [ADR-0050](ADR-0050-English-Synonym-Sets) ·
[Plan-Reviewing-Scope](Plan-Reviewing-Scope) · [Roadmap](Roadmap) ·
[Plans-Index](Plans-Index) · [Home](Home)
