# ADR-0036: Decks are a core and layers, with rules, bases, typed notes and a B1 plan

- **Status:** Accepted
- **Date:** 2026-10-09
- **Amends:** ADR-0013 (one path per language learnt, naming core ids; a
  path's units may be planned), ADR-0018 (a card is written in a core or
  a layer), ADR-0034 (a second grammar schedule; pairs from pair notes).

## Context

The owner asked for a B1 plan in every path (`docs/plans/b1-plans.md`),
for sentences to wait until their words and rules are known, with a
small phrasebook first and grammar taught as rules over known words
(`docs/plans/words-rules-sentences.md`), and for each deck to keep the
learner's language in a layer of its own (`docs/plans/native-layers.md`).
The skill model left grammar understood and produced to this format
(ADR-0034, 2026-10-09). On 2026-10-09 the owner
decided that the format is built in the parser, the validator and
`docs/DECK-FORMAT.md` before any B1 deck is written; that a rule's forms
are listed for every word, and the validator checks every taught word of
the rule's kind has its row; that layers live in `decks/<lang>/<native>/`;
that notes keep their language facts in the core and each layer writes
the explanation around them; that each planned unit names its listening
and reading passages; and the words per level, A1 700, A2 900 more and
B1 1,200 more. Asked the format's open questions, the owner decided the
same day that paths are one per language learnt now, shared by every
layer; that understanding grammar is choosing what a form means, and
choosing or typing the form is producing it; that pairs come from pair
notes; that a plan is required once a language has a core; that every
planned unit names its passages; that a grammar topic is one rule; and
that scripts without spaces wait; and that the learner is asked which
of their languages to learn a course from. The rating screen for
offensive words asks where the rater speaks the language, which needed
the language's regions defined.

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
- **One path per language learnt,** `decks/<lang>/<lang>-path.yaml`,
  shared by every native language. It names each deck by its core id,
  `<lang>-<name>`, and a learner from a native language is taught that
  language's deck for it, `<lang>-<native>-<name>`, merged or
  single-file; a unit with none is "Coming" for them. Its passages are
  named once, with a description per native language; its regions
  likewise. Today's nine course paths move to it once.
- **The learner chooses the native language** a course is taught from,
  when more than one they speak teaches it: asked when the course is
  first opened, and once more when another starts teaching it, with how
  many of the path's written units each teaches and the best covered
  chosen to start with; changed per course in Settings. A unit with no
  deck in the chosen language is "Coming", never taught from another's.
- **B1 decks.** Each course's decks for the core ids a path with a B1
  plan lists, less its alphabet decks, are held to the B1 checks below,
  whether split or not; a plan is required of a path once its language
  has a core.
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
- **Two grammar schedules:** `grammarUnderstood`, new, is shown a form and
  chooses what it means among the meanings of the same word's forms;
  `grammar`, grammar produced, chooses the form among the same word's
  forms or types it with the word and the meaning given, and keeps its
  name and its history. Neither implies the other, nor any word skill:
  the research finds grammar practice skill-specific and gives no
  figure. Each is fitted per language, as every skill is.
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
- **Regions:** a language's path may list its regions, each with an id
  and a name per native language; the app adds "Elsewhere". A rater
  says which region they speak in, and a note may name the regions it is
  about.

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
- Today's nine paths are rewritten once, mechanically, to core ids. A
  second native language adds its layers and its passages' descriptions,
  and never its own copy of a plan.
- A unit can be written for one native language and "Coming" for
  another; words are counted per course against one planned size.
- Region ids are permanent, as card ids are.

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
- **Paths per course until a second native language** (this format's
  first recommendation): every unit line would have been rewritten then,
  and two courses' copies of a plan could drift.
- **Choosing the form as understood:** the owner chose choosing the
  meaning.
- **Passages' descriptions in a path layer per native language:** one
  more kind of file for a few lines of text; they are keyed by native
  code in the path, as a facts file's texts are.
- **Regions in the facts file, or in the app:** the path is already the
  language's shared plan, and the app must stay language-agnostic.
- **Choosing the learner's native language for them,** by the best-known
  language they speak or by coverage alone: the owner chose to ask, since
  a learner may prefer a fuller course in their second language, or their
  first language's however far it has come.
- **B1 checks on cores only:** a deck could escape them by staying
  single-file.
- **A stored Wiktionary title:** the plan builds the link from the word.
