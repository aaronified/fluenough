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

Answers on ADR-0050 (2026-10-30, #924):

7. Delivery: bundled in the app first.
8. Typos: yes, the same tolerance as the card's own answer.
9. Schema: `not_synonyms` (0.6.x) and the reviewer proposal fields
   `alt_native_add` and `not_synonyms_add` (0.7.0) are approved.
10. Match scope: "Whole answer, or when preceded by an article or verb and
    without anything succeeding (add the phrasal verbs as exceptions). Think
    of what else. Think only in context of English." Designed below.

Status: ADR-0050 is Accepted for 7 to 10; questions 6, 7, 8, 10 and 11
below stay open, each with a recommendation.

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
| Size / offline | bundled first (owner, 2026-10-30), a few thousand sets, under 300 KB; parsed once on the first typed-meaning answer |
| Matching | after exact and diacritics; whole answer with an optional lead (article, "to") and nothing after; phrasal verbs only when listed; regular inflection with equal endings; typos at the card's own tolerance, as `closeTypo` |
| Wrong sense | sets are absolute only; `not_synonyms` on the layer card as the escape |
| Reviewers | proposals `alt_native_add` and `not_synonyms_add` (needs the owner's nod) |
| Reveal | the card's own answer, hint `Also: {typed}` or "Also right"; for a typo match the member spelled right |
| Licence | CC BY-SA 4.0; a Sources line |

## The match scope in detail

The owner's rule (2026-10-30): a synonym counts "when it is the whole
answer, or when preceded by an article or verb and without anything
succeeding", phrasal verbs as exceptions, English only. This section makes
it exact. Everything below happens on `meaningKey` forms, so case,
punctuation, contractions, bracketed qualifiers, "ok" and "please" are
already handled by the seven existing rules.

### The frame

For each accepted form of the card (each `;` part, `alt_native`, brackets
dropped) and the typed answer, in this order, the first success wins:

1. **Whole key.** The whole typed key is a member of a set containing the
   form, or an inflection of one. ("be careful" is a member as a whole, so it
   is read as that member before any lead is removed.)
2. **Lead and core.** Otherwise remove at most one lead word from the
   front, and the rest, the core, must pass step 1 as a whole. Nothing may
   follow the core. The lead is one of:
   - **Free leads:** the articles a, an, the (a and an are one word), and the
     infinitive "to". A free lead may be present on one side only. "to" is
     free only when the card's own answer starts with "to" (a verb card).
   - **Matching leads:** possessives (my, your, his, her, its, our, their),
     demonstratives (this, that, these, those) and the copula (is, are, am,
     was, were, be). These are part of the meaning, so they must be the same
     on both sides: "my sofa" is "my couch", a bare "sofa" is not "my couch".
   - When both sides carry a free lead, a and an match a and an, and the
     must match the; otherwise refused ("a couch" is not "the sofa").
3. **Nothing else is a lead or a trailer.** No other word is skipped. That
   one rule makes every "very", "not", "never", "more", preposition and
   particle after or before the core a refusal, because the core is then
   not a set member.

### Safeguards, one per risk

| Risk in English | Safeguard |
|---|---|
| Phrasal verbs ("give up", "put off", "look up", "turn off") | The core must be a whole member, so "give up" never matches a set that has only "give", and "put off" never matches "delay" or "postpone" unless a set lists "put off" itself. A phrasal verb that a set lists is inflected on its verb, not its particle (giving up, not give uping); the particles are a short closed list (up, down, off, on, out, in, over, away, back, through, around, about, apart, by, forward, together, along). |
| Trailing preposition or object ("look for", "take care of") | Same rule: a trailing word makes the core a different phrase; it matches only if that phrase is itself a member. |
| a / an agreement | a and an are one word; agreement is not checked ("an car" is accepted: the reveal shows the card's own answer, and an unreliable vowel-sound rule would refuse "an hour", "a university"). |
| Definiteness | a/an and the are not interchangeable when both sides have one. |
| Plurals, tense, -ing, comparatives | Endings must be equal: "cars" accepts "automobiles", not "an automobile"; "started" accepts "began" only because a set lists both, and "begun" is refused unless listed. Lemmas must themselves be set members, which stops "water" being read as "wat" + "er". Irregular forms are sets of their own. |
| "to" + verb versus bare verb | Rule 5 already makes a leading "to" optional. A typed "to" is accepted only when the card starts with "to"; an article on one side and "to" on the other is a part-of-speech clash. |
| Negation ("not big", "never begin", "un-" words) | "not", "never", "no" are not leads, so the core is not a member and the answer is refused. A card whose own answer is negated is matched only against sets that list the negated phrase. |
| Intensifiers and adverbs ("very", "quite", "really", "too", "more") | Refused unless a set lists the phrase ("very big" is not "big"). |
| Whole sentences ("it is a sofa") | Not a frame: three words before the member. Sentences stay with the deck author's `alt_native` (ADR-0050, plan question 2). |
| Multiword members | A phrase is one member and matches whole; inflection splits its last word (its verb if it ends in a particle). |
| Apostrophes and contractions | Contractions are expanded by rule 2 first. A possessive 's is not a plural: it is read from the raw text and only matches another possessive ("mother's" is not "mothers"). |
| The card's own qualifiers in brackets | Dropped from the card's form by rule 3, and from the typed text if typed; the sets never see them. |
| Part of speech (a set of "run", noun or verb) | Sets list only words synonymous in every part of speech (the poke-holes pass tests each reading); the lead check above refuses a noun frame on a verb card and the reverse; `not_synonyms` is the card-level escape. |
| Capitalisation | Ignored by rule 1; proper nouns are not special-cased. |
| Typos and short words (car / cat) | Same thresholds as the card's own answer, applied to the member's lemma: none under three letters, one for three to seven, two from eight. A typed word that is itself a member of a different set is a real word and is never typo-matched. A typo is only `closeTypo`. The card's own "car" already accepts "cat" as `closeTypo` today; the synonym pass adds no new kind of risk. If play-testing shows wrong credit, the one dial is a higher short threshold for the synonym pass only; no owner decision is needed unless it is turned. |
| A typo stacked on the frame | The typo is tried on the core after a lead is removed; the ending must still be equal and the lead rules are not relaxed. |
| Sibling cards (sofa and couch as two cards) | Warned by the tool in step 8; the synonym is accepted. |

### Behaviour table

The sets below are illustrative, real English (made-up words are not
possible here); each still has to survive the poke-holes pass to ship. The
tests in code use test-only sets with made-up words and the real function
words (a, the, to, up) (AGENTS.md, "Tests check behaviour"). Sets: {colour,
color}, {couch, sofa}, {begin, start}, {began, started}, {delay, postpone},
{donate, give}, {take care, be careful}, {car, automobile}, {kitty, cat}.

| # | Card answer | Typed | Result | Why |
|---|---|---|---|---|
| 1 | color | colour | accept, exact, "Also: colour" | whole key in one set |
| 2 | car | an automobile | accept | free article on the typed side |
| 3 | the car | automobile | accept | free article on the card side |
| 4 | to start | to begin | accept | "to" lead, the card starts with "to" |
| 5 | to start | begin | accept | rule 5: "to" optional |
| 6 | couch | to sofa | refuse | "to" lead on a card that is not a verb |
| 7 | to postpone | to put off | refuse | "put off" is not a member of the set; a phrasal verb matches only when listed |
| 8 | to donate | to give up | refuse | the core is "give up", not the member "give"; a trailing particle |
| 9 | to donate | to give | accept | whole core is a member |
| 10 | to start | never begin | refuse | "never" is not a lead |
| 11 | colour | very color | refuse | intensifier: core "very color" is not a member |
| 12 | cars | automobiles | accept | same ending -s, lemmas in one set |
| 13 | cars | an automobile | refuse | endings differ (plural against singular) |
| 14 | started | began | accept | the irregular pair is a set |
| 15 | started | begun | refuse | not listed; irregular forms are not guessed |
| 16 | my couch | my sofa | accept | same possessive on both sides |
| 17 | my couch | your sofa | refuse | possessives differ |
| 18 | my couch | sofa | refuse | the possessive is part of the meaning, so it must match |
| 19 | a couch | the sofa | refuse | a and the differ |
| 20 | Take care! (to someone leaving) | be careful | accept | bracket dropped; whole key is a member |
| 21 | take care | take care of | refuse | a trailing word, "take care of" is not a member |
| 22 | it is a couch | it is a sofa | refuse | whole sentences are not a frame; needs `alt_native` |
| 23 | COLOUR | Color! | accept | case and punctuation (rule 1) |
| 24 | color | colur | accept as `closeTypo`, "Also: colour" | typo of the member "colour", 6 letters, distance 1; the hint spells it right |
| 25 | automobile | cat | refuse | "cat" is a member of the set {kitty, cat}, a real word, so no typo match to "car" |
| 26 | to sprint | a run | refuse | article on one side, "to" on the other: part-of-speech clash |
| 27 | couch (not_synonyms: "sofa") | sofa | refuse | the card's escape |
| 28 | gave up | quit | refuse | unless a set lists "give up"; endings are never guessed across a particle |

Row 25 is the short-word case. Without the cat set, "cat" for the card
"automobile" would be `closeTypo` (grade 3, the answer is revealed), exactly
as "cat" is already `closeTypo` for a card that says "car".

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
| 2 | `synonym_sets.dart` (parse, equivalents) and the grader's synonym pass (frame, inflection, typo, `viaSynonym`); behaviour tests with test-only sets | Sonnet | M (about 300 lines with tests) | 0.6.0 |
| 2-4 | Built together in one pull request (#924): `synonym_sets.dart`, the grader's synonym pass (with an optional `notSynonyms` exclusion the card field will feed), `assets/synonyms/en.yaml` (empty), the loader in `lib/app/`, `tools/validate_synonyms.py` and its CI step, the `Also: ...` hint and the Sources line. Not yet: `tools/english_meanings.py`. | Sonnet | done | 0.6.0 |
| 3 | `tools/english_meanings.py`, `tools/validate_synonyms.py`, tests; an empty-but-valid `assets/synonyms/en.yaml`; the CI job; `pubspec.yaml` assets line and the loader in `lib/app/` (its own small PR for `pubspec.yaml`) | Sonnet | M | 0.6.0 |
| 4 | Reveal hint `Also: ...`, l10n tokens, Sources line (CC BY-SA); mockup of the reveal if the owner wants one | Sonnet | S | 0.6.0 |
| 5 | Seed batch 0 (regional spelling variants), then batch 1 (the 200 commonest meanings), through draft and poke | Haiku, Sonnet | S per batch | 0.6.0 |
| 6 | Seed batches 2 to N, one PR each; content, so it stays out of the CHANGELOG (owner, 2026-10-19) | Haiku, Sonnet | S per batch, as many as the owner wants | rolling |
| 7 | `not_synonyms`: field in the card model and docs/DECK-FORMAT.md, the validator's rules, the cross-check; decks use it a release later | Sonnet | M | 0.6.x (approved 2026-10-30); built: the app reads it, no deck uses it until a release after |
| 8 | Sibling-clash warnings tool (cards of a deck in one set) | Sonnet | S | 0.6.x |
| 9 | Reviewer proposals `alt_native_add`, `not_synonyms_add` in `tools/proposals.py`, `tools/review_bot.py`, reviewer mode UI; candidate-set report | Sonnet | L | 0.7.0 with the reviewer-mode overhaul (approved 2026-10-30); built 2026-10-31: the fields, validator, `tools/proposals.py`, the review file parts and `tools/synonym_candidates.py`; the reviewer-mode UI is the overhaul's |

Steps 2 to 4 (step 3's tools listing aside) are about a week of one Sonnet, in three PRs; each batch of step
5 and 6 is an hour or two of a Haiku plus a Sonnet. Step 9 depends on #508,
#922 and the reviewer-mode overhaul: mark "blocked by" on GitHub when the
issues are made (CLAUDE.md, dependencies are marked).

## Tests

Behaviour only (AGENTS.md, "Tests check behaviour"); words are made up,
never from a real language.

Dart (about ten): a member of a set is accepted for another and the reveal
carries the flag; the card's own answer and `alt_native` still win and are
not flagged; an inflected member matches only with the same ending; a
`not_synonyms` entry blocks; a typo of a member is `closeTypo` at the card's
own thresholds; the frame rules (lead, trailing word, phrasal verb, negation)
as in the behaviour table, one test per kind of row, with test-only sets; a malformed file is no sets and grading is as
before.

Python (about five): each refusal of the validator on a fixture with made-up
words (a word in two sets, a set of one, an unsorted file, a member not in
comparison form, a dead `not_synonyms`); the meanings list counts and orders
by frequency. A shared JSON list of normalisation cases is read by both
suites so the Python `meaningKey` and the Dart one cannot drift.

## Questions for the owner

Answered 2026-10-30 (#924): question 1 (delivery): A, bundled first.
Question 2 (scope): the owner's frame rule, see "The match scope in
detail", replacing both A and B. Question 3 (typos): yes, the card's own
tolerance, with the safeguards in the match scope. Question 4
(`not_synonyms`): A, yes. Question 5 (reviewer fields): A, both. Question 9
(timing): A (`not_synonyms` in 0.6.x, reviewers in 0.7.0). Still open:

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
9. **(Answered: A.) When do steps 7 and 9 go?** Weeks run 0.6.x and 0.7.x (owner,
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
