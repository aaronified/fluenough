# ADR-0035: Decks are a core and layers, with rules, bases, typed notes and a B1 plan

- **Status:** Proposed
- **Date:** 2026-10-09
- **Amends:** ADR-0013 (a path's units may be planned), ADR-0018 (a card
  is written in a core or a layer), ADR-0034 (a second grammar schedule;
  pairs from pair notes).

## Context

The owner asked for a B1 plan in every path (`docs/plans/b1-plans.md`),
for sentences to wait until their words and rules are known, with a
small phrasebook first and grammar taught as rules over known words
(`docs/plans/words-rules-sentences.md`), and for each deck to keep the
learner's language in a layer of its own (`docs/plans/native-layers.md`).
The skill model left grammar understood and produced to this format
(`docs/plans/skill-model.md`, 2026-10-09). On 2026-10-09 the owner
decided that the format is built in the parser, the validator and
`docs/DECK-FORMAT.md` before any B1 deck is written; that a rule's forms
are listed for every word, and the validator checks every taught word of
the rule's kind has its row; that layers live in `decks/<lang>/<native>/`;
that notes keep their language facts in the core and each layer writes
the explanation around them; that each planned unit names its listening
and reading passages; and the words per level, A1 700, A2 900 more and
B1 1,200 more.

## Decision

- **A core and its layers.** A core, `decks/<lang>/<lang>-<name>.yaml`,
  `part: core`, holds the language learnt: ids, targets, readings, IPA,
  forms, bases, rules, and the language facts of notes. A layer,
  `decks/<lang>/<native>/<lang>-<native>-<name>.yaml`, `kind: layer`,
  holds one native language: the deck's name and description, meanings,
  note texts, example translations, labels and explanations, keyed by
  card id. Merged, they are the deck `<lang>-<native>-<name>`: the id a
  single-file deck of that course has, which stays valid. A card the
  layer does not translate is not taught from that language. A layer
  may have cards of its own, numbered in the language's sequence.
- **B1 decks.** The decks a path with a B1 plan lists, less its alphabet
  decks, are held to the B1 checks below, whether split or not; a plan
  is required of a path once its language has a core.
- **A phrasebook:** `phrasebook: true` on 15 to 25 cards per course,
  taught whole in the course's first unit, never held back.
- **Base words:** `bases:` names the base of each derived word in a
  target or example, by the card that teaches it (`ref`) or written in
  full. In a B1 deck, every word of a text is a target of one of the
  course's word cards or has a base.
- **Rules decks:** `kind: rules`, a core and layers only. One table per
  deck: its rows are the language's words of one kind, each with every
  form listed, and its columns belong to rules (`<lang>-rule-<name>`),
  each with a name and an explanation. Every word of the kind a B1 deck
  teaches has its row, or is listed as an exception. Each cell is a card,
  `<core>-<word number>-<slot index>`, asked in two schedules.
- **Two grammar schedules:** `grammar`, typing the form with the word and
  the meaning given, keeps its name and its history and is grammar
  produced; `grammarUnderstood`, choosing among the forms of the same
  word, is new, with its choose question.
- **Sentences name their rules:** `rules:` on a card, by rule id, the
  unlock gate's data beside `bases`. A path's grammar topics name rules,
  or grammar decks not yet turned into rules.
- **Typed notes:** a list of `pair`, `culture`, `usage`, `behaviour` or
  `note`, each with its text; a pair note names its partner, taught in
  the same course, and is the source of the card's sound-alike; a culture
  note names its source, and its deck is tagged `unreviewed` until a
  speaker checks it, then `reviewed`. Today's string is one `note`. A
  word card in a B1 deck without one is warned of.
- **The Wiktionary mark:** `wiktionary: true` where the native
  language's Wiktionary has an entry; the link is built, not stored.
- **The B1 plan in the path:** a unit may be a mapping with its planned
  size in words, its grammar topics, its milestone (`A1`, `A2`, `B1`),
  and its listening and reading passages, or a `planned` unit not written
  yet, which lessons skip and which names its passages. A path with a
  plan has all three milestones in order.
- **Paths stay per course for now,** moving to one per language learnt
  before a second native language's layers are written.

## Consequences

- Every existing deck, path and review row stays valid as it is; the new
  checks apply to cores, layers and the decks of a path with a plan.
- A language's B1 plan, its split and its bases are written together: once
  a path has a plan, every deck it lists is held to the B1 checks.
- A noun added to a B1 deck needs its row in every noun table in the same
  change.
- A deck split into core and layer needs its layer folder in
  `pubspec.yaml`, and two files to read where there was one.
- Converting a grammar deck to a rules table keeps its cells' history
  only if each row keeps its old key and the slots their order.
- The language's taught words, rules and rows are checked across every
  file of the language, so validating one file reads the rest from disk.
- The validator reads plain YAML scalars as YAML 1.2 does, as the app
  does.
- Moving to per-language paths will rewrite every path's unit lines.

## Alternatives considered

- **A rule's forms made from a stem and exceptions:** shorter, but
  wrong for Telugu's oblique stems; the owner chose forms listed per
  word.
- **Translations inline, keyed by language,** as facts are: every
  native language would edit the same file.
- **Renaming `grammar` to `grammarProduced`:** the log is append-only
  and holds `grammar`.
- **Inferring a core from a missing `native`:** a forgotten field would
  read as a different kind of file.
- **Paths per language now:** placement, the catalog and the path
  checks would all change before a second native language exists.
- **B1 checks on cores only:** a deck could escape them by staying
  single-file.
- **A stored Wiktionary title:** the plan builds the link from the word.
