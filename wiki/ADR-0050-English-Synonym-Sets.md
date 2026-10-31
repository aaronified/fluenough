# ADR-0050: Typed English meanings accept words from a curated file of synonym sets

Source of truth: this wiki page.

- **Status:** Accepted (owner, 2026-10-30, on #924) for: bundled delivery,
  typo tolerance, the match scope, the `not_synonyms` field and the reviewer
  proposal fields. Details still open (plan questions 6, 7, 8, 10, 11) stay
  Proposed and have recommendations.
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

The owner's answers on this ADR (2026-10-30, on #924):

- **Delivery:** bundled in the app first.
- **Typos:** yes, the same tolerance as the card's own answer.
- **Match scope:** "Whole answer, or when preceded by an article or verb and
  without anything succeeding (add the phrasal verbs as exceptions). Think
  of what else. Think only in context of English."
- **Schema:** both `not_synonyms` (0.6.x) and the reviewer proposal fields
  `alt_native_add` and `not_synonyms_add` (0.7.0) are approved.

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

The synonym pass sits **after** the existing exact and diacritic passes (a
card's own answers always win), and its typo pass after the card's own typo
pass. The owner's scope (2026-10-30, on #924): "Whole answer, or when
preceded by an article or verb and without anything succeeding (add the
phrasal verbs as exceptions). Think of what else. Think only in context of
English." The precise rules are in
[Plan-Synonym-Dictionary](Plan-Synonym-Dictionary#the-match-scope-in-detail),
with the behaviour table; in short:

1. **Keys.** Both sides are put in `meaningKey` form (rules 1 to 7 stay as
   they are: case, punctuation, contractions, brackets, a leading "to",
   "ok", "please"). Every accepted form of the card counts (the `native`
   text's `;` parts and `alt_native`, brackets dropped), each tried alone.
2. **Frame.** A typed answer is `[lead] core`, with at most one lead word
   and nothing after the core. The lead is an article (a, an, the) or the
   infinitive "to", free on either side; or a possessive, demonstrative or
   copula (my, your, this, that, is, are, be and the like), which must be
   the same on both sides. The core must be a whole member of a set (or an
   inflection of one, below). A synonym is never a word inside a longer
   sentence, so nothing after the core is ever tolerated: "give up" is not
   "give", "put off" is not "delay", "very big" is not "big", "not big" is
   not "small". A phrasal verb matches only when a set lists the phrasal
   verb itself.
3. **Inflection.** The core is split into a lemma and a regular ending
   (`-s`, `-es`, `-ies`, `-ed`, `-ing`, `-er`, `-est`, doubled consonant,
   dropped `e`) and matches when the endings are equal and the lemmas are
   in one set; a form that is itself a member is read as that member
   first. A phrasal verb is split on its verb, not on its particle. Irregular
   forms are sets of their own.
   **British and American -l-/-ll- spellings** (cancelled / canceled,
   travelling / traveling, labelled / labeled) are one word by rule, for a
   closed list of lemmas truly spelled both ways (bevel, cancel, channel,
   chisel, counsel, dial, duel, enamel, equal, fuel, funnel, grovel, jewel,
   label, level, libel, marvel, medal, model, panel, pedal, pencil, quarrel,
   rival, shovel, signal, snorkel, swivel, total, travel, trowel, tunnel,
   yodel): a doubled l before -ed, -ing, -er, -ers, -or or -ors is optional
   on both sides, whatever the sets hold, so no lemma set is needed for
   them. A word whose lemma is not on the list is never matched by the rule
   (never pulled, filled, rebel, control), so a slip such as `teling` for
   `telling` is graded by the card's own typo pass, a close typo, not exact.
   Other regional spellings
   (organise / organize, colour / color) are lemma sets, and their inflections
   follow from rule 3: `organised` is `organise` with -ed, so it matches
   `organized` when both sides carry the same ending.
4. **Typos: yes, the same tolerance as the card's own answer** (owner,
   2026-10-30; this replaces the earlier "no typo distance on synonyms").
   After the card's own typo pass fails, the typed core is compared with
   each member of the matching sets using the grader's own thresholds
   (`typoDistance`, `longTypoDistance`, `longThreshold`, `shortThreshold`),
   counted in the letters of the member's lemma: none under three, one for
   three to seven, two from eight. Two safeguards keep the short-word risk
   (car / cat) at the card's own level: a typed word that is itself a member
   of any set is a real word and is never typo-matched to another set, and a
   typo match is only ever `closeTypo`, never exact (below). Nothing else
   stacks: a typo is tried on the core after the lead is removed, the
   ending must be equal, and the lead rules are not relaxed.
5. **Result.** An exact match is `AnswerOutcome.exact` (grade 5) with a new
   flag on `GradedAnswer`, `viaSynonym`, the way `droppedArticle` is a flag
   and not an outcome, so no switch over the outcomes changes. A typo match
   is `closeTypo` (grade 3, as for the card's own typos) with the same
   flag. `matched` is the card's own answer, not the typed word.
6. **Which side leads.** The "to" lead counts only when the card's own
   answer also starts with "to" (a verb card); an article lead on one side
   and "to" on the other is a part-of-speech clash and refuses ("a run" is
   not "to sprint").

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
  nod (AGENTS.md, "What an agent must not decide alone"), given on
  2026-10-30; the field ships in 0.6.x.
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
`tools/review_bot.py` and reviewer mode, and the owner approved
both (2026-10-30); it ships with the reviewer-mode overhaul (0.7.0). A
reviewer never edits the shared file: a word proposed for the same card
answer on several cards becomes a candidate set, reported to the owner by a
tool, and goes through the seeding workflow below.

Built (2026-10-31, plan step 9, tools only; the app's reviewer mode is the
overhaul's): the format is as above, with `now` always `""` (the proposal
adds, it replaces nothing). The review file names the parts `alt_native` and
`not_synonyms` with `action: "add"`; the bot puts a `not_synonyms` word in
comparison form. Applying appends to the list, closes only proposals of the
same item, and serialises the rest (two agreements cannot both edit one
line). The bot refuses what CI's `validate_synonyms.py` would reject: a
refused word that is one of the card's own answers, is in no set with
another of its answers, or whose set another card already escapes.
`tools/synonym_candidates.py` is the candidate-set report.

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
screen reader reads the hint. The grade is the same as an exact answer. For a typo match
(`closeTypo`) the hint shows the member spelled right, not the typed misspelling,
and the grade is the card's own typo grade.

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
`not_synonyms` entry blocks; a typo of a member is `closeTypo` and flagged, and not
accepted under three letters or when the typed word is a member of another
set; a leading article is free and a possessive must match; a phrasal verb
or a trailing word refuses; a malformed file grades as before. The Python
tests give the validator fixtures with made-up words and check each refusal
(a word in two sets, an unsorted file, a dead `not_synonyms`). Roughly ten
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
  the owner chose this first (2026-10-30); following the decks can come once the file grows.
- Nothing about target-language synonyms is decided here.

## Alternatives considered

- **A dictionary (words mapped to senses, with transitive groups):** the
  owner chose sets; a dictionary invites sense-dependent matches, which the
  owner ruled out.
- **WordNet synsets taken whole:** large, and synsets hold near-synonyms
  and hypernyms; far too loose for "absolutely synonymous".
- **Accepting synonyms as "close":** the owner chose right, with a hint.
- **No typo tolerance on synonyms** (the first recommendation): the owner
  chose the card's own tolerance instead, with the safeguards above.
- **Word-by-word substitution inside sentences:** rejected by the owner's scope (a lead and nothing after).
- **Letting the model grade meanings (the AI-conversation plan):** not
  offline, and not deterministic.
- **JSON or one word per line:** a list of lists in YAML matches the decks'
  and the owner's wording, reads well in a diff, and the subset needs
  no package.

See also: [Plan-Synonym-Dictionary](Plan-Synonym-Dictionary) ·
[ADR-0034](ADR-0034-Hear-Say-Write) · [ADR-0038](ADR-0038-Review-Proposals) ·
[ADR-Index](ADR-Index) · [Home](Home)
