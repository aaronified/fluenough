# ADR-0050: Typed English meanings accept words from a curated file of synonym sets

Source of truth: this wiki page.

- **Status:** Proposed (the file format of a new card field and of reviewer
  proposals needs the owner's nod: see the plan's questions)
- **Date:** 2026-10-30
- **Builds on:** ADR-0034 (Hear types the meaning), ADR-0038 (review
  proposals), ADR-0040 (decks are CC BY-SA). Plan:
  [Plan-Synonym-Dictionary](Plan-Synonym-Dictionary). Issue: #924.

## Context

The owner's Hear drill showed జాగ్రత్త! with the meaning "Take care!
Careful!". Typing "take care" was marked wrong, because only `;`
alternatives are accepted (`lib/core/grading/meaning_rules.dart`). The
owner: "This is extremely bad experience." Part 1 of #924 rewrites the decks'
unseparated alternatives. This ADR is part 2: a typed word that means the
same as the card's answer should be right, without the deck author having
listed it.

The owner's decisions of 2026-10-30, on #924:

- **Scope:** English answers first, shared by every course. Target-language
  synonyms come later, per course.
- **Source:** all three: a shared file, per-card alternates in the decks,
  and reviewers adding through the review flow (#508, #922).
- **Grading:** a synonym is right, not "close", not silent. The reveal shows
  the card's own answer, with a short hint ("Also: take care").
- **The data is sets** (not a dictionary): each set is a list of English
  words or phrases, and every member accepts every other member.
- **Only absolute synonyms,** words interchangeable in all situations. No
  sense-dependent pairs (bank / shore; big / large, which differ in some
  contexts). Regional spelling variants (colour / color, grey / gray,
  favourite / favorite, organise / organize) are included, and are the
  first and safest kind of set, seeded first (owner, 2026-10-30).
- **Every list is poked for holes** by an independent Sonnet pass before it
  ships.

## Decision

### The file

- **One file, `assets/synonyms/en.yaml`,** a YAML list of lists, in a
  restricted subset a small parser reads (below). Bundled in the app, so
  it works offline from the first launch. Target size: a few thousand sets,
  well under 300 KB; the builder is told to stop at the course
  vocabulary's most frequent meanings, not to fill the language.

```yaml
# Synonym sets for typed English meanings (ADR-0050).
# Licence: CC BY-SA 4.0. Attribution: see the Sources screen.
version: 1
sets:
  - ["colour", "color"]
  - ["take care", "be careful", "look out"]
```

- **Each member is quoted** (AGENTS.md rule 2) and written in its
  comparison form: lower case, no punctuation, no bracketed qualifier, no
  leading "to", contractions expanded, "ok" for okay: the form
  `meaningKey` produces. The validator refuses a member whose key differs
  from what is written.
- **Sorted:** members within a set, then sets by first member, so a diff
  shows what changed and a merge conflict is a line.
- **No word is in two sets.** A word that two sets both want means they are
  one set (merge them) or one of them is wrong (it is not absolutely
  synonymous). Sets are never transitive by accident: only members of the
  same set accept each other.
- **No set of fewer than two members, no empty member, no repeat.**
- **A phrase is a member** ("take care"). Inflected forms are not listed:
  see matching. An irregular verb's forms are sets of their own (["began",
  "started"]), kept to the verbs that have sets.
- **Header:** a comment saying what the file is, its licence and where to
  read the attribution, and `version`. A set carries no per-set comment
  or source, so that the file stays a list of lists.

### Where the code lives

- `lib/core/grading/synonym_sets.dart` (new, **no Flutter import**, AGENTS.md
  rule 3): `SynonymSets.parse(String text)` reads the restricted subset (a
  `sets:` line, then one `- ["a", "b"]` per line, comments and blank lines
  skipped; anything else is a `FormatException`, which the loader treats as
  "no sets", never as a crash). It exposes `Set<String> equivalents(String
  key)`. The package `yaml` is not needed, and no dependency is added
  (rule 6).
- The bundle is read in the app layer (`lib/app/`), once, on the first
  typed-meaning answer, and given to the `AnswerGrader` through its
  constructor as an optional `synonyms` argument. Without it, grading is as
  before. The web build reads the same asset.
- `pubspec.yaml` gains one `assets:` line, in its own small PR with the
  loader (the file is a contention point; no dependency changes).

### How matching works

The synonym pass sits **after** the existing exact and diacritic passes and
**before** the typo pass, so a card's own answers always win and a typo is
only ever forgiven against the card's own answers.

1. Both sides are put in `meaningKey` form (case, punctuation, brackets,
   contractions, "to", "ok", "please": rules 1 to 7 stay as they are).
2. **Inflection.** A typed word and an expected word are each split into a
   lemma and an ending by regular rules only: `-s`, `-es`, `-ies`, `-ed`,
   `-ing`, doubled consonants, a dropped `e`. They match when their endings
   are the same and their lemmas are in one set. So with a set of "florp" and
   "glim", "florped" matches "glim" only as "glimmed": the past form of
   a member accepts the past form of another, and "florps" does not accept
   "glim". The split is tried on the last word of a
   phrase ("takes care" is "take care" plus `-s`). A form that is itself a
   member is read as that member first. Irregular forms are not guessed.
3. The **whole answer** is compared: a synonym replaces the whole answer
   or an entire `;` alternative, never a word inside a longer sentence
   (open question 2).
4. **Every accepted form of the card** counts: the `native` text's `;`
   parts, `alt_native`, with brackets dropped, as `meaningKeys` gives them.
5. **No typo distance on synonyms.** A typed word one letter from a member
   is not accepted: two forgivenesses stacked accept real other words
   (bat, cat). A typo of the card's own answer is forgiven as before
   (open question 3).
6. The result is `AnswerOutcome.exact` (grade 5) with a new flag on
   `GradedAnswer`, `viaSynonym`, the way `droppedArticle` is a flag and
   not an outcome, so no switch over the outcomes changes. `matched` is the
   card's own answer, not the typed word.

### The wrong-sense escape: `not_synonyms`

The sets hold only absolute synonyms, so a wrong match is rare and is a
defect in a set. The rare case still needs an escape that does not wait for
a release of the file: a card's native side (its English layer card, where
`alt_native` lives) may carry `not_synonyms`, a list of typed answers the
sets must not accept for this card. Example: a card for a river's bank
whose set partner is wrongly accepted: `not_synonyms: ["shore"]`.

- Quoted strings, compared in `meaningKey` form; the synonym pass skips a
  typed key listed there. They never block the card's own answers or its
  `alt_native`.
- A card older apps cannot read: a released parser rejects an unknown
  field, so decks use `not_synonyms` only a release after the app that
  reads it (as for `warning`, #691). The schema change needs the owner's
  nod (AGENTS.md, "What an agent must not decide alone"); it is open
  question 4.
- A set that many cards escape is the real fix: the validator reports it
  (below) and the set is removed or split.

### Per-card alternates, as they work now

`;` in `native` and `alt_native` (ADR-0034; docs/DECK-FORMAT.md) are
accepted outright by rule 4 and the grader's `alternates`. They stay the
first tool of a deck author and are unchanged; the sets only add to them.
Part 1 of #924 moves unseparated alternatives into `;`.

### Reviewers

A reviewer who sees a correct typed answer marked wrong, or a wrong one
accepted, proposes it through the review flow (ADR-0038), so the owner's
automation carries it: `field` gains two values for the layer card,
`alt_native_add` (`text` is one extra accepted answer, appended to
`alt_native` when agreed) and `not_synonyms_add` (appended to
`not_synonyms`). This changes the proposal format and `tools/proposals.py`,
`tools/review_bot.py` and reviewer mode, so it needs the owner's nod
(open question 5) and ships with the reviewer-mode overhaul (0.7.0). A
reviewer never edits the shared file: a word proposed for the same card
answer on several cards becomes a candidate set, reported to the owner by a
tool, and goes through the seeding workflow below.

### Seeding and the review gate

1. `tools/english_meanings.py` lists the English meanings of every course
   (`native` and `alt_native` of the layers), normalised by the same rules,
   most frequent first (cards across courses, then the deck priority of
   CLAUDE.md).
2. **Haiku drafts sets**, regional spelling variants first (batch 0), then
   the commonest meanings, in batches of about 200 meanings, writing only
   groups it is sure are interchangeable everywhere, leaving a meaning
   alone when unsure. Drafting may consult Wiktionary and Open English
   WordNet, both CC BY-SA 4.0-compatible (CC BY-SA 4.0 and CC BY 4.0), and
   nothing else (no thesaurus under a more restrictive licence).
3. **A Sonnet pass pokes holes** in every set of the batch: for each, a
   counterexample sentence where the members cannot swap, register
   differences (formal, slang, rude, dated), grammar differences
   (countable, transitive, preposition), and any set it cannot defend is
   struck. Only surviving sets merge. This is the batch PR's one review
   (CLAUDE.md, one review per PR); the PR body lists the sets struck.
   Regional spellings (colour / color) survive.
4. `tools/validate_synonyms.py` runs in CI ("Validate decks" job) on the
   file: format and sorting, quoting and comparison form, no set under two
   members, no word in two sets (it names the sets to merge), no repeat. It
   also reads the decks: every `not_synonyms` entry must be a member of a
   set that has another member among the card's answers (else it does
   nothing and is an error), and a set that is escaped on two or more cards
   is reported as a failure, because "absolutely synonymous" is then false
   (open question 6).
5. A second tool listing, as warnings, pairs of cards in one deck whose
   answers are in one set (a deck teaching sofa and couch as two cards),
   so authors can add `not_synonyms` where the contrast is the point
   (open question 7).

### Reveal and hint

On a synonym match the reveal shows the card's own answer, as on any right
answer, and one hint: `Also: {typed}`, the learner's own word in the hint,
for a typed answer of one or two words; "Also right" for a longer one. No
full stop, like every hint (wiki Design-Guidelines, #913). The text is an
ICU token in `lib/l10n/app_en.arb`; no literal in the widget (rule 10). The
screen reader reads the hint. The grade is the same as an exact answer.

### Attribution and licence

The file is CC BY-SA 4.0, like the decks (ADR-0040). The Sources screen
gets a line beside the Wiktionary one: "Synonym sets: adapted from
Wiktionary and Open English WordNet, licensed CC BY-SA 4.0" (a `sources`
token like `sourcesPhoneticLine`), and the file's header says the same.
Whether the credit is owed when sets are written by a model from its own
knowledge and only checked against those sources is open question 8; the
line is added by default, the cheaper wrong.

### Tests

Behaviour, with made-up words, never real language (AGENTS.md, "Tests check
behaviour"): the Dart tests build a `SynonymSets` from a string with words
such as "florp" and "glim", and check what a learner sees: a member accepts
another and the reveal says so; the card's own answer still wins and is
not marked as a synonym; an inflection matches only with its own ending; a
`not_synonyms` entry blocks; a typo of a member is not accepted while a typo
of the card's own answer is; a malformed file grades as before. The Python
tests give the validator fixtures with made-up words and check each refusal
(a word in two sets, an unsorted file, a dead `not_synonyms`). Roughly six
Dart and five Python tests in all; no per-line tests of the parser.

## Consequences

- A learner is no longer marked wrong for "take care" on a card that means
  "Careful!" once the sets hold the pair. Coverage is as large as the
  sets are: small at first, growing with each batch.
- Quality depends on a gate that costs tokens: every batch is drafted and
  poked. The owner chose that over a large, noisy file.
- "Absolute synonym only" leaves out many true near-synonyms (big / large).
  Those stay with the deck author's `alt_native`, which is exact and
  per card.
- A shared file can be wrong for a card; `not_synonyms` fixes one card
  without a release, but only after the deck format carries the field, so
  decks wait a release for it.
- The python validator and `meaningKey` normalise separately. They must
  agree; a shared list of cases (a JSON fixture both test suites read)
  keeps them so.
- Bundling means a new set reaches learners with the next app release;
  open question 1 asks whether it should follow the decks instead.
- Nothing about target-language synonyms is decided here.

## Alternatives considered

- **A dictionary (words mapped to senses, with transitive groups):** the
  owner chose sets; a dictionary invites sense-dependent matches, which the
  owner ruled out.
- **WordNet synsets taken whole:** large, and synsets hold near-synonyms
  and hypernyms; far too loose for "absolutely synonymous".
- **Accepting synonyms as "close":** the owner chose right, with a hint.
- **Typo tolerance on synonyms:** rejected above.
- **Word-by-word substitution inside sentences:** left to open question 2.
- **Letting the model grade meanings (the AI-conversation plan):** not
  offline, and not deterministic.
- **JSON or one word per line:** a list of lists in YAML matches the decks'
  and the owner's wording, reads well in a diff, and the subset needs
  no package.

See also: [Plan-Synonym-Dictionary](Plan-Synonym-Dictionary) ·
[ADR-0034](ADR-0034-Hear-Say-Write) · [ADR-0038](ADR-0038-Review-Proposals) ·
[ADR-Index](ADR-Index) · [Home](Home)
