# The B1 deck format: implementation spec

For four builders working in parallel on one branch (`feat/b1-format`):

- **V**, the Python validator: `tools/validate_decks.py` and its tests in `tools/`.
- **D**, the Dart parser and models: `lib/core/models/`, `lib/core/data/`, and
  the few app call sites the type changes reach.
- **W**, the docs: `docs/DECK-FORMAT.md`, `docs/adr/0036-*.md`,
  `decks/README.md`, `assets/deck-template.yaml` (comments only).
- **Q**, the grammar questions: the two grammar schedules' questions in
  the app (section 4.8). Q starts once D's models are on the branch
  **and** the skill model's pull request (aaronified/fluenough#432,
  branch `claude/ecstatic-wright-b1z4x5`) has merged and the branch is
  rebased on it, because both change `lib/core/scheduling/` (OPEN-23,
  settled).

Sources: `docs/plans/b1-plans.md` (owner decisions of 2026-10-06 and
2026-10-09), `docs/plans/words-rules-sentences.md`,
`docs/plans/native-layers.md`, `docs/plans/skill-model.md`, ADR-0013,
ADR-0018 and ADR-0034, the owner's answers of 2026-10-09 (the last
section), and the code as it is on `main` at `81bc89e`. From the skill
model's pull request (#432), not yet on `main`:
`lib/core/scheduling/skill_map.dart`, `docs/adr/0034-hear-say-write.md`,
`docs/research/skill-evidence.md` and `docs/plans/offensive-words.md`.

**How the OPEN items work.** Where the plans leave a choice open, or where
this spec departs from a plan line, it marks the place **OPEN-n**, says
what it recommends, and specifies the recommendation. Every OPEN item is
listed in the last section, "Open for the owner", in two groups:

- **Group A, gaps the plans leave.** The builders build the recommendation.
  An owner answer that differs changes only the section named.
- **Group B, departures from a plan line, or a choice the owner made that
  this spec could not settle** (OPEN-4, 16, 20, 22, 23, 24, 25, 26).
  **The owner has answered every one (2026-10-09),** and the body of this
  spec now says what the owner decided: each is marked *settled* where it
  is used, citing the answer. Two answers differ from what this spec
  first recommended, OPEN-4 (paths per language learnt, now) and OPEN-22
  (understood is choosing the meaning), and sections 2.1, 2.8, 4.6–4.8,
  9.5, 9.6 and 10 were rewritten for them. ADR-0036 is written
  `Status: Accepted` (section 14).

A builder who meets a case this spec does not cover asks, and does not
decide.

**Rework on the branch.** The code and docs already on `feat/b1-format`
were built from this spec's first recommendations, so two parts of them
are now out of date and are redone from the sections named: per-course
paths (D: `course_path.dart`, the catalog and their tests; V:
`check_path_file`, `check_paths_across`, `check_reading_across`'s unit
lookups and the B1 plan checks; W: "Course paths" and "The B1 plan" in
`docs/DECK-FORMAT.md`, ADR-0036; the `zz` fixtures' path files) from
2.1, 2.8, 9.5, 9.6 and 10; and the grammar question (D's `promptFor` and
`acceptedAnswers` for `grammarUnderstood`; W's drill-mode rows) from 4.6
and 4.7. Regions (10.5, 6.1) are new to all three.

---

## 0. Ground rules for all four builders

1. **Compatibility is the first acceptance test.** On today's `decks/`,
   `python3 tools/validate_decks.py decks/` must print byte-for-byte the
   same output before and after V's change: no new error, warning or info
   line. The one exception is the paths: the change that makes paths per
   language (10.6) migrates today's nine course paths in the same commit,
   and the output on the migrated tree must equal today's output on
   today's tree, except for the paths' own file names in it. Every deck in `decks/` must parse in D's parser into the same
   `Deck` as before (D's existing tests stay green unchanged, except where a
   type change in section 9 forces an edit to a test's construction code).
   Section 12 lists what keeps this true.
2. **Parity.** The Dart parser must never reject a file the validator
   accepts (the rule written at the top of `deck_parser.dart`), and the two
   must read every accepted file the same way. Every Dart rejection in this
   spec is a validator error too. The validator may check more.
3. **No card id changes.** Nothing in this spec renumbers or reshapes an
   existing card id, grammar cell id or deck id (AGENTS.md rule 1). New id
   shapes are only for new things (rule ids, rule cells, core ids, region
   ids, passage ids). **Path ids change** once, from
   `<lang>-<native>-path` to `<lang>-path`, by the owner's answer to
   OPEN-4: a path id is stored nowhere (not in `reviews`, `card_states`,
   settings or placement, which keep merged deck ids), so no learner's
   progress moves.
4. **Quoting.** Every string scalar in every example is quoted (AGENTS.md
   rule 2), **mapping keys included**: slot keys, note ids, card ids and
   example targets used as keys are written `"lo":`, `"stem":`,
   `"te-9001":`. Three kinds of value are deliberately unquoted because
   they are typed: booleans (`phrasebook: true`, as `rtl: true` and
   `answer: true` are today), whole numbers (`words: 45`, `schema: 1`), and
   `null` for an empty grammar cell. A quoted `"true"` is an error where a
   boolean is wanted. Deck agents copy the examples, so an example that
   breaks this rule is a bug in this spec.
5. **Message forms.** Exactly three:
   - **Per file:** `r.error(where, msg)`, `r.warn(where, msg)` or
     `r.info(where, msg)`, printed under the file's header as
     `  error   {where}: {msg}`, `  warning {where}: {msg}` or
     `  info    {where}: {msg}`. The tables below give `where`, then the
     message, with Python f-string fields in braces.
   - **Across, error:** a `check_*_across` function returns the string
     `f"{file}: {where}: {msg}"`, which `main` prints as
     `error: {file}: {where}: {msg}`, as `check_cards_across` does today.
     Every across error in this spec is written in that full form,
     `error: {file}: {where}: {msg}`, and always has a `where`.
   - **Across, warning or info:** attached to the report of the file it is
     about with `rep.warn(where, msg)` or `rep.info(where, msg)`, as
     `check_reading_across` attaches its warnings, so it prints under that
     file. Never printed as a bare line.

   Across checks report only on files **given now** (on the command line or
   under a given directory). A file read from disk for context (2.8) is
   never reported on.
6. **Examples are illustrative.** Card ids `te-9xxx` are made up; real
   decks take numbers from `python3 tools/validate_decks.py --next-id te`.
   Real Telugu cards are named only in prose (కలం (kalam) is `te-0053`,
   కాలం (kālam) is `te-0111`, ఇల్లు (illu) is `te-0195`).
7. **Schema stays 1** (OPEN-1). Every addition is optional, so no existing
   file changes meaning.
8. **Plain scalars mean the same to the validator and the app.** PyYAML
   reads YAML 1.1 (`yes`, `no`, `on`, `off` are booleans, `060` is octal 48,
   `1_000` is 1000); `package:yaml` reads YAML 1.2's core schema. V changes
   `DeckLoader` to resolve plain (unquoted) scalars as YAML 1.2's core
   schema does:

   | Plain scalar | Read as |
   |---|---|
   | `true`, `True`, `TRUE`, `false`, `False`, `FALSE` | boolean |
   | `[-+]?[0-9]+` | decimal integer (`060` is 60) |
   | `0o[0-7]+`, `0x[0-9a-fA-F]+` | octal, hexadecimal integer |
   | `[-+]?(\.[0-9]+\|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?`, `[-+]?\.(inf\|Inf\|INF)`, `\.(nan\|NaN\|NAN)` | float |
   | `null`, `Null`, `NULL`, `~`, empty | null |
   | anything else (`yes`, `no`, `on`, `off`, `y`, `n`, `1_000`, `1:30`, `0b101`) | string |

   Implementation: `DeckLoader` gets a resolver class of its own
   (subclassing `yaml.resolver.BaseResolver`, with exactly these implicit
   resolvers) and a `construct_yaml_int` that reads `[-+]?[0-9]+` as base
   10, `0o` as base 8 and `0x` as base 16. Then `phrasebook: yes` is the
   string `'yes'` to both readers and refused by both; `wiktionary: yes`
   likewise; `words: 060` is 60 to both; `words: 1_000` is a string to both
   and refused by both; `on:` as a key is the string `'on'` to both. Today's
   decks hold no such scalar (V confirms it through rule 1). V adds a
   parity case per row of the table to `tools/test_validate_deck_parity.py`;
   if `package:yaml` turns out to read one differently, the resolver
   follows `package:yaml`, and V says so in the pull request.

   **The Dart side retypes with the same patterns.** D's parser does not
   rely on `package:yaml`'s own typing of a plain scalar: `_value` in
   `deck_parser.dart` matches the scalar's text against the table's
   patterns, character for character (the same regular expressions as
   `DeckResolver`), reads `[-+]?[0-9]+` in base 10 even with leading
   zeros, `0o` in base 8 and `0x` in base 16, and keeps an integer too
   long for an `int` whole (Python's `int` has no limit). A scalar tagged
   with the bare `!` is typed by its look with the same patterns, as
   PyYAML types it. So `reading: no` is the text `"no"`, `native: 08` is
   the number 8, and `target: 1:30` is the text `"1:30"`, in both; before
   this, `_value` followed PyYAML's YAML 1.1 rules and read all three the
   other way. The patterns live in two places and change together
   (`DeckResolver`'s docstring says so). D's tests hold one case per row
   of the table, and the cases YAML 1.1 read differently.

---

## 1. What is new, at a glance

| # | Element | Where it is written | Validator | Dart / app |
|---|---|---|---|---|
| 1 | Core and layer files | `decks/<lang>/<core>.yaml`, `decks/<lang>/<native>/<layer>.yaml` | per-file + across | `DeckCore`, `DeckLayer`, `mergeLayer` |
| 2 | `phrasebook: true` | card | per-card + across (15–25 per course, first unit) | `Card.phrasebook` |
| 3 | `bases:` | card, example | per-card + across (B1 decks) | `CardBase`, `Card.bases`, `CardExample.bases` |
| 4 | Rules decks (`kind: rules`) | core + layer only | per-file + across | `Rule`, `RuleTable`, `RuleRow`, `RuleCell`, `expandRules` |
| 4b | `DrillMode.grammarUnderstood` (shown a form, choose its meaning) and the form questions of `grammar` | (not written in decks) | `MODES` | enum value (D); `Ask.chooseFormMeaning`, `Ask.chooseForm` (Q) |
| 5 | `rules:` on a sentence | card | per-card + across | `Card.rules` |
| 6 | Typed notes, and a note's `region` | card, ref; text in layer | per-card + layer + across | `CardNote`, `NoteKind`, `Card.notes`, `CardNote.regions` |
| 7 | `wiktionary: true` | single-file card or ref; layer entry; inline base | per-card | `Card.wiktionary`, `CardBase.wiktionary` (`bool`) |
| 8 | One path per language learnt, naming core ids, with its B1 plan | `decks/<lang>/<lang>-path.yaml` units | per-file + across | `LanguagePath`, `PlanUnit`, `PlannedDeck`, `Passage`, `Milestone`; `CoursePath` as the per-course view |
| 9 | Script in prose for new prose | everywhere | `check_transliterated` | — |
| 10 | `pos: "pronoun"` | card | `POS` | — (the parser does not check `pos` values) |
| 11 | YAML 1.2 plain scalars | everywhere | `DeckLoader` | `_value` retypes by the same patterns |
| 12 | Regions | `regions:` in `<lang>-path.yaml` | per-file + across (a note's `region`) | `Region`, `LanguagePath.regions` |

**B1 decks.** Several checks apply only to the decks of a B1 plan, as
`b1-plans.md` says ("The validator, for every deck in a B1 plan"). Section
2.8 defines them exactly: for each course of a language whose path has a
B1 plan, the course's deck (merged or single-file) for each core id a
unit of the path lists, if it is a vocab, grammar or rules deck, except
the path's alphabet decks.

---
## 2. Core and layer files

### 2.1 Files and ids

- **A core** holds what belongs to the language learnt, the same for every
  learner. It lives in `decks/<lang>/` and its id is `<lang>-<name>`, where
  `<name>` matches `[a-z0-9]+(-[a-z0-9]+)*`: `decks/te/te-home.yaml`,
  id `te-home`.
- **A layer** holds what belongs to one native language. It lives in
  `decks/<lang>/<native>/` and its id is `<lang>-<native>-<name>`, with the
  same `<name>` as its core: `decks/te/en/te-en-home.yaml`, id
  `te-en-home` (OPEN-27 on the file name).
- **The merged deck's id is the layer's id.** It is exactly the id a
  single-file deck of that course has today (`te-en-home`). So splitting
  today's `decks/te/te-en-home.yaml` into `decks/te/te-home.yaml` and
  `decks/te/en/te-en-home.yaml` keeps the deck id that placement
  (`placed_decks`), added-deck replacement and `reviews.deck_id` know, and
  the core id the language's path lists (`te-home`, below), and keeps
  every card id. The split deletes the single-file deck in the same
  change; the validator's existing duplicate-stem check refuses the two side
  by side (`duplicate deck id 'te-en-home'`).
- **A grammar or rules core's cells** expand with the core id as the deck
  name: `te-grammar-past` expands to `te-grammar-past-<key>-<i>`, exactly
  as the single-file `te-en-grammar-past` does today (ADR-0018). Converting a
  single-file grammar deck to a core therefore keeps every cell id, as long
  as the core id is the old deck id without its course and the slots keep
  their order.
- **Reserved core ids:** `<lang>-facts`, `<lang>-numbers`,
  `<lang>-romanisation`, `<lang>-script`, `<lang>-sounds` and `<lang>-path`
  are the names of the files beside the decks (`<lang>-path` is the
  language's path, 10.1).
- **A core's name never starts with a native language's code.** A core
  `te-en-x` would have the layer `te-en-en-x`, and its id reads as a deck of
  the `te-en` course. V refuses a core whose `<name>`'s first segment
  (before the first `-`) is the `native` code of any deck or layer of the
  language, or the name of any subdirectory of the core's directory (2.8,
  "the language's files"). V also refuses a core id equal to the stem of
  any other file in the language's files, so a core `te-en-home` beside
  the single-file `te-en-home` is caught even when only one of them is
  given (today's duplicate-stem check sees only files given together).
- **The single-file deck stays valid** in every form it has today,
  `decks/<lang>/<lang>-<native>-<name>.yaml` with `native` inline. It may
  also use the new card fields (sections 3–8, with their inline forms). A
  rules deck exists only as a core and layers (OPEN-2).

**OPEN-3, how a core is recognised.** Recommended: an explicit header
field, `part: "core"`, on every core; a layer is `kind: "layer"`. Inferring
a core from a missing `native` would turn a forgotten `native` on a
single-file deck into a confusing core error.

**Every deck has a core id, and paths name decks by it (OPEN-4, settled:
owner, 2026-10-09, "one per language learnt now (`<lang>-path.yaml`),
shared by every layer").** `native-layers.md` designs paths and B1 plans
per language learnt: "Paths and B1 plans are per language learnt
(`hi-path.yaml`), shared by every layer" (lines 56–57). This spec first
recommended keeping per-course paths until a second native language came;
the owner chose the per-language path now, before the deck agents start,
so that no unit line has to be rewritten later. So:

- **A deck's core id** is `<lang>-<name>`: for a core, its id; for a layer
  or a merged deck, its core's id (`te-en-home` → `te-home`); for a
  single-file deck `<lang>-<native>-<name>`, the same id without its
  native (`te-en-home` → `te-home`, `te-en-sound-differences` →
  `te-sound-differences`). It is well defined because a core's name never
  starts with a native language's code (below), and a single-file deck's
  native is its `native.code`.
- **The deck a learner is taught for a core id** `<lang>-<name>`, learning
  from the native language `n`, is the deck whose id is
  `<lang>-<n>-<name>`: the layer `decks/<lang>/<n>/<lang>-<n>-<name>.yaml`
  merged with its core, or the single-file deck with that id. A deck not
  yet split and the merged deck it becomes have the same id, so a path
  never changes when a deck is split.
- **A path lists core ids,** never a course's deck ids, in its `alphabet`,
  its units' `decks`, and its planned ids (section 10). One path,
  `decks/<lang>/<lang>-path.yaml`, serves every native language: a
  learner from `n` gets, for each core id it lists, that core id's deck in
  `n` where one exists, and nothing where none does (10.4). A deck that
  only one native language needs, such as English learners' "sounds
  English lacks", has a core id like any other
  (`te-sound-differences`); a Bengali course gives its own deck for it,
  `te-bn-sound-differences`, or none.
- **Card ids and deck ids do not change.** Placement (`placed_decks`),
  added-deck replacement, `reviews.deck_id` and the catalog keep merged
  deck ids (`te-en-home`), as before: the app turns the path's core ids
  into the learner's deck ids (10.4) before any of them sees the path.
- **Today's course paths are migrated** in the change that makes paths per
  language (10.6): mechanical, one file per language.

**OPEN-5, reading decks.** Recommended: reading decks stay single-file;
their questions are already keyed by language. A core with
`kind: "reading"` is refused (2.2).

**OPEN-27, the layer's file name.** `native-layers.md` line 41 sketches
`hi-family.en.yaml`; the owner settled only the folder,
`decks/<lang>/<native>/`. Recommended: `<lang>-<native>-<name>.yaml`
(`decks/te/en/te-en-home.yaml`), so that the layer's stem is the merged
deck's id, which is today's single-file id. Placement, added-deck
replacement, `reviews.deck_id`, the duplicate-stem check and the path's
mapping from core id to deck id (10.4) then keep working unchanged. `te-home.en.yaml` would need a second id rule for every
one of them.

### 2.2 Dispatch, and a core's header

**Dispatch.** `validate()` (and D's catalog, 9.6) decides what a file is in
this order, before any other check:

1. `kind == "layer"`: a layer (2.6). A `part` key on it is an error:
   `part: a layer has no part; only a core is marked part: "core"`.
2. else `part == "core"`: a core (this section).
3. else a `part` key with any other value: the error
   `part: must be "core", or left out on a single-file deck; got {value!r}`,
   and the file is then checked as a single-file deck.
4. else a single-file deck, exactly as today.

```yaml
schema: 1
id: "te-home"
part: "core"
kind: "vocab"
language: { code: "te", iso639_3: "tel", name: "Telugu", script: "telugu", tts: "te-IN", icon: "తె" }
license: "CC0-1.0"
authors:
  - { name: "Fluenough contributors" }
theme: "home"
tags: ["beginner", "unreviewed"]
cards:
  # section 2.3
```

| Field | Required | Notes |
|---|---|---|
| `schema` | yes | `1`. |
| `id` | yes | `<lang>-<name>`, equal to the filename stem, `<lang>` being `language.code` (2.1). |
| `part` | yes | `"core"`. |
| `kind` | no | `"vocab"` (default), `"grammar"` or `"rules"`. |
| `language` | yes | The full language block, as today, `icon` included where the language's other decks give one. |
| `license` | yes | SPDX, for the core's content. |
| `authors`, `source`, `tags` | no | As today. |
| `theme` | no | Vocab only, as today. |
| `cards` | vocab | A non-empty list (2.3). |
| `pattern` | grammar | The core pattern (2.5). |
| `table`, `rules` | rules | Section 4. |
| `native`, `name`, `description` | **not allowed** | They are the learner's language: each layer gives them. |

The file must sit in `decks/<language.code>/` (its parent directory's name is
the language code).

**Key sets.** `HEADER_KEYS` (single-file decks) is **unchanged**. V adds:

```python
CORE_HEADER_KEYS = {"schema", "id", "part", "kind", "language", "license",
                    "authors", "source", "tags", "theme", "cards", "pattern",
                    "table", "rules"}
LAYER_HEADER_KEYS = {"schema", "id", "kind", "core", "native", "name",
                     "description", "license", "authors", "source", "tags",
                     "cards", "pattern", "table", "rules"}
```

A key outside the file's set gets today's `unknown field {key!r}`, except
the keys that have a message of their own in the tables below, which get
that message in its place. `KINDS` gains `rules` and `layer`.

**On a single-file deck,** three keys that are now meaningful elsewhere get
their own message in place of `unknown field` (D's `parse()` refuses them
with the same words):

| where | message |
|---|---|
| `core` | `only a layer names a core (kind: "layer")` |
| `table` | `only a rules core has table; a rules deck is written as a core and layers` |
| `rules` | `only a rules core has rules; a rules deck is written as a core and layers` |
| `kind` | `a rules deck is written as a core and layers; see "Rules decks" in docs/DECK-FORMAT.md` (for `kind: "rules"`, OPEN-2) |

**Validator, per file, on a core** (after `check_transliterated`,
`check_romanised` and `check_ipa`, which run as for any deck):

| where | message |
|---|---|
| `native` | `a core file has no native: the language it is taught from is in each layer, in decks/{lang}/<native>/` |
| `name` | `a core file's name is in each layer, in the learner's language` |
| `description` | `a core file's description is in each layer, in the learner's language` |
| `id` | `must be {lang}- and a name, the filename stem, got {id!r}` |
| `id` | `{id!r} is the name of the language's {facts file / number rules / romanisation file / script guide / sounds file / path}; give the core another name` |
| `id` | `{id!r} reads as a deck of the {lang}-{seg} course; a core's name does not start with a native language's code` (2.1) |
| `id` | `{id!r} is also the id of {other file}; a core's id is its own` (2.1) |
| `root` | `a core file lives in decks/{lang}/, the folder of its language; this one is in {parent!r}` |
| `kind` | `a core is vocab, grammar or rules, got {kind!r}`, and for `"reading"` the same with `; a reading deck stays a single-file deck` appended (OPEN-5). One message, never two. |

**Icon.** A core registers `r.icon` from its language block exactly as a
single-file deck does today (`(code, icon or None)`), so
`check_icons_across` holds cores to the language's other decks. A layer
registers none (it has no language block).

### 2.3 A core: cards

A core card has the language side only:

```yaml
cards:
  - id: "te-9001"
    target: "ఇల్లు"
    reading: "illu"
    pos: "noun"
    picture: "🏠"
    notes:
      - { id: "stem", kind: "behaviour", words: [{ word: "ఇంటి-", reading: "iṇṭi-" }] }
  - id: "te-9002"
    target: "నేను ఇంటికి వెళ్తాను."
    reading: "nēnu iṇṭiki veḷtānu."
    pos: "phrase"
    rules: ["te-rule-ki"]
    bases:
      - { word: "ఇంటికి", ref: "te-9001" }
      - { word: "వెళ్తాను", ref: "te-9003" }
  - ref: "te-9010"
```

Core card fields: `id`, `target`, `reading`, `ipa`, `alt_target`, `pos`,
`gender`, `tags`, `audio`, `examples`, `modes`, `picture`, `notes` (core
form, 6.2), `phrasebook` (3), `bases` (8, core form), `rules` (5). **Not
allowed in a core:** `native`, `alt_native`, `wiktionary` (they are the
native language's) and `pair` (in a core, a pair note names the partner,
OPEN-16).

| where | message |
|---|---|
| `card {id}` | `a core card's {key!r} is in each layer, under cards.{id}` (for `native`, `alt_native`, `wiktionary`) |
| `card {id}` | `pair: in a core file a pair note names the partner, { kind: "pair", ref: ... }; Hear takes its sound-alike from there` |
| `card {id}` | `target is required and must be a non-empty string` (as today) |

A core example is `{ target, reading?, ipa?, bases? }`: its translation is in
each layer, keyed by its target (2.6). Within a card, two examples may not
have the same target after NFC normalisation:
`card {id}: examples[{j}] has the same target as examples[{k}]; a layer names an example by its target`.

A core ref (`- ref: "te-9010"`) may give `reading`, `ipa`, `tags`, `modes`,
`examples` (core form) and `notes` (core form). `native`, `alt_native` and
`wiktionary` on a core ref get the core-card message above, with `ref {id}`
as where.

### 2.4 Card ids across, and what the validator knows of each card

- The language's card ids stay one namespace. A card written in a core, a
  layer (as a layer-only card) or a single-file deck is written once in the
  language (`check_cards_across`'s rule).
- **The code must change for this to hold.** Today `_repo_card_defs` skips
  every report with `native_code is None`, and `check_cards_across` skips
  every report with `native_code is None or lang_code is None`. A core has
  no native, so as the code stands its cards would never reach the card
  definitions: `--next-id` would hand out ids already used (AGENTS.md
  rule 1), a duplicate between a core and a single-file deck would pass,
  and refs, `pair`, pair notes and `bases[].ref` naming core cards would
  fail with `no deck writes card`. V therefore makes both functions key on
  `lang_code` alone, and replaces the per-card tuple with a record:

```python
@dataclass
class CardDef:
    path: Path                 # the file that writes the card
    natives: set[str]          # the native languages it is taught from
    words: list[str]           # what a number deck counts as taught by it (as today)
    target: str
    alt_targets: list[str]
    pos: str | None
    tags: list[str]
    phrasebook: bool
    vocab: bool                # written in a vocab deck (single-file, core, or layer-only)
```

  `Report.card_defs` becomes `dict[str, CardDef]`; `_repo_card_defs(lang)`
  returns `dict[str, CardDef]`.
- **`natives`:** a single-file deck's card: `{its native}`. A layer-only
  card: `{the layer's native}`. A core's written card: empty in the core's
  own report, and filled in the across phase with the native of every
  layer (given now, or among the language's files on disk, 2.8) whose
  entry for the card gives a `native`.
- **The ref native check** becomes
  `rep.native_code not in found.natives and not has_native`, with today's
  message naming `sorted(found.natives)` in place of the one native
  (`the card is written for learners from ['bn']; ...`). For a single-file
  deck's ref to a core card, that is ADR-0018's rule: it resolves through
  a same-native layer.
- **`--next-id`** sees cards written in cores and layer-only cards too:
  `_repo_card_defs` reads `decks/<lang>/*.yaml` **and**
  `decks/<lang>/*/*.yaml`, and keeps every report with a `lang_code`.
- `check_bundled` already asks for a pubspec entry per directory holding
  YAML, so `decks/te/en/` needs `- decks/te/en/` under `flutter.assets`. The
  first change that adds a layer directory adds that line (pubspec is a
  contention file: a one-line commit of its own).

### 2.5 A grammar core

The core keeps the table's language side; slot labels stay the keys of
`forms`, as today.

```yaml
schema: 1
id: "te-grammar-past"
part: "core"
kind: "grammar"
language: { code: "te", iso639_3: "tel", name: "Telugu", script: "telugu", tts: "te-IN", icon: "తె" }
license: "CC0-1.0"
pattern:
  slots: ["నేను", "నువ్వు"]
  entries:
    - lemma: "వెళ్ళు"
      key: "vellu"
      reading: "veḷḷu"
      forms: { "నేను": "వెళ్ళాను", "నువ్వు": "వెళ్ళావు" }
      readings: { "నేను": "veḷḷānu", "నువ్వు": "veḷḷāvu" }
```

Core `pattern` fields: `slots`, `entries`; each entry `lemma`, `key`,
`forms`, `reading`, `readings`, `ipa`, `ipas`. **Not in a core:** `name`,
`slot_name`, `prompt`, `notes`, and an entry's `gloss`. All of
`check_pattern`'s existing rules apply to what is there.

| where | message |
|---|---|
| `pattern` | `a core pattern's {key!r} is in each layer, under pattern` (for `name`, `slot_name`, `prompt`, `notes`) |
| `pattern.entries[{lemma}]` | `a core entry's gloss is in each layer, under pattern.entries.{id part}` |

### 2.6 A layer

```yaml
schema: 1
id: "te-en-home"
kind: "layer"
core: "te-home"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Home and neighbourhood"
description: "Rooms, the house and the street."
license: "CC0-1.0"
cards:
  "te-9001":
    native: "home; house"
    wiktionary: true
    notes:
      "stem": "Before an ending, it becomes {1}: ఇంట్లో (iṇṭlō), at home."
  "te-9002":
    native: "I will go home."
  "te-9010":
    native: "door"
  "te-9020":
    target: "ఇంటి పేరు"
    reading: "iṇṭi pēru"
    native: "surname (literally 'house name')"
    notes:
      - { kind: "culture", text: "A Telugu surname often comes first, before the given name.", source: "https://en.wikipedia.org/wiki/Telugu_people#Names" }
```

Layer header:

| Field | Required | Notes |
|---|---|---|
| `schema` | yes | `1`. |
| `id` | yes | `<lang>-<native>-<name>`, the filename stem, where the core id is `<lang>-<name>`. |
| `kind` | yes | `"layer"`. |
| `core` | yes | The core's id. The core is `{core}.yaml` in the layer's grandparent folder. |
| `native` | yes | The native block (`code`, `iso639_3`, `name`), as on a single-file deck. |
| `name` | yes | The deck's title in that language. |
| `license` | yes | SPDX, for the layer's text. |
| `description`, `authors`, `source`, `tags` | no | As on a deck. |
| `cards` | vocab core | A **mapping** from card id to entry. |
| `pattern` | grammar core | A mapping (below). |
| `table`, `rules` | rules core | Mappings (section 4). |
| `language`, `theme`, `part` | **not allowed** | They are the core's. |

The file sits in `decks/<lang>/<native.code>/`.

**Every mapping key in a layer, and in a rules core's `table` and `rules`,
is a string.** Under ground rule 8 an unquoted `on:` is already the string
`'on'`, but `1:` is the integer 1. Any key that is not a `str` is an error
at the mapping's where: `key {k!r} was read as {type(k).__name__}; quote it`.

**A layer card entry, for a card the core writes:**

| Field | Notes |
|---|---|
| `native` | **Required.** The meaning. Without an entry, the card is not taught from this language. |
| `alt_native` | As today. |
| `notes` | A mapping from the core note's `id` to its text, in this language (6.3). |
| `examples` | A mapping from a core example's `target` to its translation: a string, or `{ native, bases }` where `bases` maps an inline base's `word` to its meaning, in the same forms as the card's `bases` below. |
| `bases` | A mapping from the `word` of one of the core card's inline bases to its meaning: a string, or `{ meaning, wiktionary }` (8.1, 7). |
| `wiktionary` | `true` (7). |

**A layer card entry, for a card the core lists by ref:** the same fields,
but `native` is **optional**. An entry with `native` gives the card its own
meaning in this course, as a ref with `native` does today. An entry
without one takes the home card's native as ADR-0018 resolves a ref
(2.7); it may still give `alt_native` and `wiktionary`. `notes` and
`examples` are allowed only where the core's ref itself gives core-form
`notes` or `examples` (they then key on those); otherwise the referenced
card's own notes and examples are used, as ADR-0018 says, and the layer
cannot address them.

**Keys that are texts** (`examples` targets and `bases` words) are matched
exactly, code point for code point, in both V and D. The Dart side has no
NFC (#28), so instead of normalising, V requires both sides to be NFC
already: a core example's `target`, a core inline base's `word`, and every
such layer key. Exact comparison in D then gives the same answer as an NFC
comparison would.

| where | message |
|---|---|
| `card {id}` | `examples[{j}].target is not NFC-normalised; a layer names the example by it` / `bases[{i}].word is not NFC-normalised` (core) |
| `cards.{id}.examples` / `cards.{id}.bases` | `key {k!r} is not NFC-normalised` (layer) |

Anything else (`target`, `reading`, `ipa`, `pos`, `tags`, `modes`, …) on an
entry whose id is a core card or ref is an error: the layer cannot change
the word.

**A layer-only card** (`native-layers.md`: "Cards for some native languages
only live in that layer") is an entry whose id is not a card or ref of the
core. It is a full single-file card without `id` (the key is its id):
`target` and `native` required, all single-file card fields allowed
(`pair` included), notes in the single-file form (6.1), bases in the inline
form. Its id comes from the language's sequence and is written nowhere
else.

**A layer's grammar `pattern`** (grammar core):

```yaml
pattern:
  name: "Past tense"
  slot_name: "person"
  prompt: "{lemma} ({gloss}) — {slot}"
  slots: { "నేను": "I, నేను (nēnu)", "నువ్వు": "you, నువ్వు (nuvvu)" }
  entries: { "vellu": "to go" }
  notes: "The past adds -ఆ- (-ā-) before the person ending."
```

`name`, `slot_name`, `prompt` (same placeholder rules as today) and
`entries` are required; `entries` maps each core entry's id part (its `key`,
or its lemma) to its gloss. `slots` is optional; it maps a core slot to the
label shown for `{slot}`; a slot without one shows its key. `notes` is
optional.

**Layer validation.** V loads the core inside `validate()`
(`path.parent.parent / f"{core}.yaml"`, read with `DeckLoader`, as
`_uses_iso15919` reads the romanisation file), so a layer validated alone is
checked against its core. **Every check that needs the language block runs
on the layer with the core's**: the script (a layer-only card's missing
`reading` warning, a base's or a note word's missing reading error),
`check_ipa`, and `check_romanised`, which takes the code from the core's
`language` and looks for `{code}-romanisation.yaml` in the **core's**
directory (`path.parent.parent`), not the layer's. V gives
`check_romanised` a `lang` and a `directory` parameter for this; a
single-file deck passes its own, as today. When the core cannot be loaded
(the `core` errors below), these checks are skipped and only the `core`
error is reported.

| where | message |
|---|---|
| `core` | `must be the id of a core file, such as 'te-home', got {value!r}` |
| `core` | `no core file {core}.yaml in {dir}; a layer's core is in the folder above it` |
| `core` | `{core}.yaml is not a core: it has no part: "core"` |
| `id` | `a layer of {core} taught from {native} has id {expected!r}, got {id!r}` |
| `root` | `a layer lives in decks/{lang}/{native}/, the folder of its native language; this one is in {dir!r}` |
| `language` | `a layer takes its language from its core, {core}` |
| `theme` | `a layer takes its theme from its core, {core}` |
| `part` | `a layer has no part; only a core is marked part: "core"` |
| `cards` | `a layer's cards is a mapping of card id to what this language gives it` |
| `cards` | `only a layer of a vocab core has cards` (and the same for `pattern`, `table`, `rules` against the core's kind) |
| `cards.{id}` | `{key!r} belongs to the word, in the core; a layer gives native, alt_native, notes, examples, bases and wiktionary` |
| `cards.{id}` | `native is required: without it the card is not taught from {native name}` (a card the core writes) |
| `cards.{id}.notes` | `the core lists {id} by ref without notes; give them in the core's ref` (and the same for `examples`) |
| `cards.{id}` | `{id} is not a card of {core}; a card only this layer has gives its target too` (an entry with no `target` whose id the core does not have) |
| `cards.{id}` | `id must be {lang}- and at least four digits, such as {lang}-0001, got {id!r}` |
| `cards.{id}.notes` | `a mapping of the core note's id to its text` (for a core card); for a layer-only card the single-file note rules (6.1) |
| `cards.{id}.notes.{nid}` | `the core card has no note {nid!r}` |
| `cards.{id}.examples` | `a mapping of an example's target, as the core writes it, to its translation` |
| `cards.{id}.examples.{target}` | `the core card has no example with this target` |
| `cards.{id}.bases.{word}` | `the core card has no inline base for {word!r}; a base given by ref takes its meaning from that card` |
| `{where}` | `key {k!r} was read as {type}; quote it` |
| `pattern.entries` | `gives no gloss for {id part!r}` (every core entry must have one) and `{key!r} is not an entry of the core` |
| `pattern.slots` | `{key!r} is not a slot of the core` |

Warnings (layer):

| where | message |
|---|---|
| `cards.{id}` | `note {nid!r} has no text here, so learners from {native name} do not see it` |
| `cards.{id}` | `example {target!r} has no translation here, so it is not shown` |
| `cards.{id}` | `the inline base {word!r} has no meaning here; it is shown without one` |

A missing translation stays a warning; a layer key with nothing in the core
to name (an orphan, as after the core changed an example's target) is the
error above, so a core edit cannot silently lose a translation without CI
saying where.

Info (layer, one line): `cards: covers {n} of {m} cards of {core} ({pct}%)`,
with `m` the core's cards (written and ref) and `n` those this layer
includes by 2.7. The ref part of `n` needs the language's other decks, so
this info is attached in the across phase (2.8).

The validator has no info channel today. **V adds one:** `Report.infos`,
`r.info(where, msg)`, printed after the file's warnings as
`  info    {where}: {msg}`. A file with infos and no warnings or errors
prints the header `info {path}`. Infos never change the exit code or the
`N/M decks valid` line. Today's decks produce none.

### 2.7 Merging a core and a layer into today's `Deck`

The merge is defined once here; D implements it (`mergeLayer`, plus the
catalog's ref resolution) and V uses the same rules for its across checks
(2.8).

- **Deck:** `id` = layer id; `name`, `description` = layer's; `kind` =
  core's; `language` = core's; `native` = layer's; `license` = the core's if
  the two are equal, else `"{core} AND {layer}"` (an SPDX expression);
  `tags` = core's, then the layer's not already there, except that
  `reviewed` is dropped when `unreviewed` is among them (6.5); `authors` =
  core's then layer's; `source` = layer's, else core's; `theme` = core's.
- **Cards, in the core's order.** A written core card is included iff the
  layer has an entry for it with `native`. A core ref is included iff the
  layer's entry for it gives `native`, **or** it resolves as a ref does
  today (ADR-0018): its home card is in a merged or single-file deck with
  the same native, which then supplies the native side (and the layer's
  entry, if any, adds `alt_native` and `wiktionary`, and `notes` and
  `examples` where 2.6 allows them). Otherwise it is skipped. Layer-only
  cards follow, in the layer's order (OPEN-6).
- **A merged card** takes from the core: `id`, `target`, `reading`, `ipa`,
  `alt_target`, `pos`, `gender`, `tags`, `audio`, `modes`, `picture`,
  `phrasebook`, `rules`, `bases` (with each inline base's `meaning` and
  `wiktionary` from the layer); from the layer: `native`, `alt_native`,
  `wiktionary`. **Notes:** the core's notes in core order, each with the
  layer's text, placeholders filled (6.4); a note without layer text is
  left out. **Examples:** the core's examples in order, each with the
  layer's translation; an example without one is left out. **`pair`:** the
  `ref` of the first included pair note, else none (OPEN-16).
- **Refs** keep ADR-0018's resolution: a merged deck's refs are
  `CardRef`s whose native-side fields come from the layer entry (null where
  the layer gives none), and `position` counts the entries **included**
  before it (cards and refs; a ref whose inclusion depends on resolution
  counts as included, and is dropped by the catalog with the position of
  every later ref unchanged, exactly as an unresolved ref is today), so
  the catalog's existing resolution (`deck_catalog.dart`, around line 470)
  places them unchanged.
- **Grammar:** the `GrammarPattern` takes `slots`, entries' `lemma`, `key`,
  `forms`, readings and IPA from the core; `name`, `slotName`, `prompt`,
  `notes` and each entry's `gloss` from the layer. An entry without a gloss
  in the layer is left out. The `{slot}` placeholder is filled with the
  layer's slot label, else the slot key; the card id still uses the slot's
  index in the core.
- **Rules:** section 4.6.

### 2.8 What the validator records of cores and layers, and the across model

**Report fields.** V adds `part: str | None` (`"core"`, `"layer"` or
`None`), `core_id: str | None`, `infos: list[str]`, and the fields named in
sections 3–10. Each existing field is filled as follows (a single-file
deck fills them exactly as today):

| Field | A core fills | A layer fills |
|---|---|---|
| `lang_code` | `language.code` | the core's `language.code` |
| `native_code` | `None` | `native.code` |
| `course_deck` | `None` (a core is on no path) | `(lang, native, layer id)` |
| `card_defs` | its written cards (2.4), `natives` empty | its layer-only cards, `natives` `{native}` |
| `refs` | its refs, each with `has_native=True`, so only their existence is checked | `[]` (a core ref's inclusion is the merge's, not an error) |
| `pairs` | `[]` (no `pair:` in a core) | its layer-only cards' `pair:` |
| `note_refs` (new) | its pair notes' refs, `(ref, where, i)` | its layer-only cards' pair notes' refs |
| `icon` | `(code, icon or None)` | `None` |
| `theme_key` | `None` | `(lang, native, core's theme)` when the core has one |
| `number_taught` | `None` | `(lang, words)` when the core's theme is in `NUMBER_THEMES`, words as today from the merged written cards; refs add theirs in the across phase as today |
| `taught_words` | `None` | `(lang, native, _taught(merged))`, `merged` being the deck 2.7 builds from the layer and its core, written cards only (refs are not in `_taught` today either); for a rules layer, every form of every row |
| `translated` (new) | — | the ids of the core's cards and refs whose entry gives `native` |
| `core_cards` (new) | the ids of its cards and refs, in order, each marked written or ref | — |
| `listed_as` (new) | its id | its core's id |

A single-file deck fills `listed_as` too, with its id less its native
(`te-en-home` → `te-home`, 2.1): `listed_as` is what the language's path
lists for the deck, whatever its form.

These are all filled in `validate()`, since a layer loads its core there.

**The language's files.** An across check that needs files not given
reads, once per run and per language, every `*.yaml` directly in the
language's directory and one level below it, in the repository's
`decks/<lang>/` **and** in the directory of every given file of that
language (a layer's grandparent, any other file's parent, so that a
fixture tree in a temporary directory is read like the repository). A file
given now is used as given; a file on disk with the same stem as a given
file is skipped (a draft replaces it), as `check_cards_across` does today.
V implements this once, `_language_reports(lang, dirs) -> list[Report]`,
cached per run, and `_repo_card_defs` becomes a view of it. Those reports
are context: nothing is reported on them (ground rule 5).

**A course** is `(lang, native)`. Its decks are its single-file decks and
its merged decks (one per layer), given now or among the language's files.
**The cards a course teaches** are, for each of its decks: a single-file
deck's written cards, and its refs that resolve; a merged deck's included
cards (2.7). **The vocab cards a course teaches** are those of its vocab
decks.

**A course's path** is its language's path, `decks/<lang>/<lang>-path.yaml`
(2.1, 10.1), read for the course's native language as 10.4 says. **A path
has a B1 plan** as 10.1 defines. **The B1 decks** of a course, when its
language's path has a B1 plan, are, for each core id listed in `decks`
(or in the list form) of any unit, less `"*"` and less the path's
`alphabet` core ids, the course's deck for that core id (2.1) where it
exists and is not a reading deck. A core is a **B1 core** when the path
has a B1 plan and lists its id outside `alphabet`.

**Which checks use what:**

| Check | Over |
|---|---|
| card ids, refs, pairs, pair notes, bases refs (2.4, 6.1, 8.2) | the language's cards |
| layer coverage info (2.6) | the layer's core, and the language's decks for its refs |
| phrasebook count and place (3) | each course's taught cards |
| rows (4.3) | the vocab cards the language's B1 decks teach |
| rule ids, sentence rules (4.4, 5) | the language's rules cores |
| pair note partner taught (6.5) | each course's taught cards |
| notes warning, pair warning (6.5) | the B1 decks' cards |
| culture review tag (6.5) | every deck |
| bases coverage (8.3) | each B1 deck's cards, against its course's vocab cards |
| B1 plan across checks (10.3) | the language's decks, each course's for its words |
| regions named by notes (10.5) | the language's path |

Today no path has a B1 plan and no deck is a core or a layer, and no note
names a region, so none of these prints anything on today's `decks/`.

---
## 3. `phrasebook: true`

`words-rules-sentences.md` §1: 15–25 survival chunks per language, "taught
in the first lessons", whole, never held back by the unlock gate. Their
words are not counted as taught by them. `b1-plans.md` lines 153–154: "A
small phrasebook comes first in the course, taught whole."

```yaml
  - id: "te-9100"
    target: "నాకు తెలుగు రాదు."
    reading: "nāku telugu rādu."
    pos: "phrase"
    phrasebook: true
    bases:
      - { word: "నాకు", ref: "te-9101" }
      - { word: "తెలుగు", ref: "te-9102" }
      - { word: "రాదు", base: "రా", reading: "rā" }
```

(In a single-file deck the card also has `native: "I don't know Telugu."`
and the inline base a `meaning`; in a core, the layer gives both.)

- **Where:** a card in a single-file vocab deck, a core vocab card, a
  layer-only card. Not on a ref: it belongs to the card (a ref gets the
  existing message `a ref cannot give 'phrasebook': it belongs to the card
  itself, where it is written`, because `phrasebook` joins `CARD_KEYS` and
  not `REF_KEYS`).
- **Value:** the boolean `true`. Leaving it out means false.

| where | message |
|---|---|
| `card {id}` | `phrasebook must be true, unquoted, or left out; got {value!r}` (anything but `True`, including `False`, the string `"true"`, and, under ground rule 8, `yes`) |

**Across (V), the size, per course.** For each course (2.8), `n` is the
number of **distinct card ids** of phrasebook cards the course teaches: the
core cards its layers include, its layer-only cards, and its single-file
decks' cards. A course is checked when `n` is not 0, or when its path has a
B1 plan (OPEN-7). If `n` is outside 15–25:

`error: {file}: phrasebook: the {lang}-{native} course has {n} phrasebook cards; a course's phrasebook has 15 to 25 ({first deck}{, and k more decks})`

`{file}` is the language's path when it is given, else the first given
deck of the course that teaches a phrasebook card; when neither is given,
the check is not reported (ground rule 5). Counting per course, not per
language, means a Bengali layer's own phrasebook cards count for Bengali
learners only.

**Across (V), the place.** In a course whose path has a B1 plan, every
phrasebook card the course teaches is taught by the course's deck for a
core id listed in the path's first unit that is not exempt (10.1),
`units[{f}]`:

`error: {path}: units[{i}]: {deck} teaches phrasebook card {id}; the phrasebook comes first, in a deck of units[{f}]`

(`units[{i}]` being the first unit whose decks, in this course, teach the
card, `{deck}` the course's deck id, and `{path}` reported only when
given.) A ref to a phrasebook card from a later deck is fine as long as a
deck of `units[{f}]` teaches it too. Each course is checked on its own:
a phrasebook card a Bengali layer adds must be in the Bengali course's
deck for a first-unit core id.

**Dart:** `Card.phrasebook` (`bool`, default `false`), read with
`optionalBool`; `true` is the only value the parser accepts besides absence
(parity: the validator refuses `false` too).

**Not counted as words** (8.5), **not a taught word for bases** (8.3), and
**not rows of a rule table** (4.3).

---

## 4. Rules decks, rule cards and rule tables

### 4.1 Shape, decided and open

From the plans: a rule card holds the rule's name, its explanation with
readings, and the forms it makes; it is taught, then practised as a table
whose rows are the taught words of the right kind and whose columns are the
rule's forms; every form is **listed per word** (owner, 2026-10-09); the
validator checks every taught word of the rule's kind has its row; a
question tests the rule, never the word, always within the **same** word:
shown a form, choosing what it means (grammar understood), and choosing
the form among the word's forms, or typing it with the word and the
meaning given (grammar produced); and grammar is understood and produced
as two schedules (4.7; OPEN-22, settled by the owner, 2026-10-09).

**OPEN-8, the unit of a rule.** The plans name rules both per ending
(`te-rule-lo`) and as a set of forms ("the columns are the rule's forms
(-లో, -కి, -తో, -నుంచి)"). Recommended, and specified below: **a rules deck
is one table** (one kind of word, its columns); **a rule is one or more of
its columns**, each with its own id, name and explanation. A case-endings
table has one rule per ending (`te-rule-lo`, `te-rule-ki`, …); a tense table
may have one rule for all its persons. A sentence names rule ids. A
grammar question's options are the word's other forms, or their meanings,
**across the whole table**, so a one-column rule still has a choice.

**OPEN-2, single-file rules decks.** Recommended: none. `kind: "rules"`
exists only as a core with layers; the deck agents write new content as
cores. A single-file deck with `kind: rules` is refused (2.2).

### 4.2 The core

```yaml
schema: 1
id: "te-grammar-case-endings"
part: "core"
kind: "rules"
language: { code: "te", iso639_3: "tel", name: "Telugu", script: "telugu", tts: "te-IN", icon: "తె" }
license: "CC0-1.0"
tags: ["grammar", "unreviewed"]
table:
  applies_to:
    pos: ["noun"]
    except: ["te-9030"]
  slots: ["lo", "ki", "to", "nunci"]
  rows:
    - word: "te-9001"
      forms: { "lo": "ఇంట్లో", "ki": "ఇంటికి", "to": "ఇంటితో", "nunci": "ఇంటి నుంచి" }
      readings: { "lo": "iṇṭlō", "ki": "iṇṭiki", "to": "iṇṭitō", "nunci": "iṇṭi nuñci" }
    - word: "te-9004"
      forms: { "lo": "అమ్మలో", "ki": "అమ్మకి", "to": "అమ్మతో", "nunci": "అమ్మ నుంచి" }
      readings: { "lo": "ammalō", "ki": "ammaki", "to": "ammatō", "nunci": "amma nuñci" }
rules:
  - id: "te-rule-lo"
    slots: ["lo"]
    words:
      - { word: "-లో", reading: "-lō" }
      - { word: "ఇల్లు", reading: "illu" }
      - { word: "ఇంట్లో", reading: "iṇṭlō" }
  - id: "te-rule-ki"
    slots: ["ki"]
    words:
      - { word: "-కి", reading: "-ki" }
      - { word: "-కు", reading: "-ku" }
  - id: "te-rule-to"
    slots: ["to"]
    words: [{ word: "-తో", reading: "-tō" }]
  - id: "te-rule-nunci"
    slots: ["nunci"]
    words: [{ word: "నుంచి", reading: "nuñci" }]
```

Header: as a core (2.2), `kind: "rules"`, with `table` and `rules`
required; `cards`, `pattern` and `theme` not allowed.

**`table`:**

| Field | Required | Notes |
|---|---|---|
| `applies_to` | yes | Which words are its rows: `pos` (required, a non-empty list from `POS` except `phrase`), `tags` (optional; a card qualifies only if it has one of them), `except` (optional; card ids of words of that kind the rule does not apply to, such as an indeclinable loanword). |
| `slots` | yes | The column keys, in order: a non-empty list of distinct **slot keys**. **Permanent in order**: a cell's id holds its slot's index. Append new slots at the end. |
| `rows` | yes | A non-empty list. |

**A slot key** matches `[a-z][a-z0-9]*(-[a-z0-9]+)*` (it starts with a
letter, so it is never a number) and is none of `yes`, `no`, `on`, `off`,
`true`, `false`, `y`, `n` (YAML 1.1's booleans, which other tools may still
read as such). Slot keys are written quoted wherever they are mapping keys
(ground rule 4).

**POS gains `pronoun`** (OPEN-28). `words-rules-sentences.md` puts
"pronouns and their forms" among the first rules, and today `POS` has no
pronoun, so a pronoun is `other` (Appendix A's నేను would be). A pronoun
table would then have to select through `applies_to.tags` on `other`,
and nothing would make pronouns carry that tag, so the "every word of the
kind has its row" check could not catch a missing pronoun. V adds
`"pronoun"` to `POS`; the Dart parser does not check `pos` values (it reads
any string), so D changes nothing. Existing cards keep `other` until their
deck is converted.

**A row:**

| Field | Required | Notes |
|---|---|---|
| `word` | yes | The id of the vocab card that teaches the word, a card of the language. |
| `key` | no | The row's id part, `[a-z0-9]+(-[a-z0-9]+)*`. Only to keep the cell ids of a single-file grammar deck when converting it: the old entry's `key` (or lemma). Without it the id part is the number of `word` (`0042` for `te-0042`). Unlike a slot key it may start with a digit, as an old entry key may: it is never a mapping key (`prompts` are keyed by `word`), so YAML cannot misread it. |
| `forms` | yes | Every slot, as in a grammar entry: a form, a list of forms (the first shown, all accepted), or `null` where the word has no such form. At least one non-null. |
| `readings` | yes in a script that needs a reading | As a grammar entry's `readings`: every slot with a form has its reading; a slot whose form is `null` has none, either left out or written `null` (both read it as none, so `{ "lo": null }` under a null form is valid, and a reading given there is an error). |
| `ipas` | no | As a grammar entry's, with the same rule for a null form. |

**`rules`:** a non-empty list.

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `<lang>-rule-<name>`, `<name>` matching `[a-z0-9]+(-[a-z0-9]+)*`. Unique in the language. **Permanent**: sentences name it, a path's grammar topics name it (10.1), and its mastery is counted from its cells. |
| `slots` | yes | The table's slots this rule makes. Every slot belongs to exactly one rule. |
| `words` | no | The language facts its explanation quotes: `{ word, reading, ipa? }`, `reading` required in a script that needs one. The layer's explanation refers to them as `{1}`, `{2}`, … (6.4). |

**Validator, per file:**

| where | message |
|---|---|
| `table` | `is required on a rules deck` / `must be a mapping` / `unknown field {key!r}` |
| `table.applies_to` | `is required: which words are its rows, as { pos: ["noun"] }` |
| `table.applies_to.pos` | `must be a non-empty list of parts of speech from {sorted(POS - {"phrase"})}, got {value!r}` |
| `table.applies_to.tags` | (`_check_str_list`) |
| `table.applies_to.except` | `must list {lang} card ids, got {value!r}` |
| `table.slots` | `must be a non-empty list of slot keys`, `slots[{i}] must start with a letter and match [a-z0-9-]+, and not be a YAML 1.1 boolean word, got {v!r}`, `slots contains duplicates` |
| `table.rows[{i}]` | `must be a mapping`, `unknown field {key!r}`, `word must be the id of a {lang} card, got {v!r}` |
| `table.rows[{word}]` | `{word} has a row already` |
| `table.rows[{word}]` | `{part!r} already names another row; give one of them a key` |
| `table.rows[{word}]` | `key must match [a-z0-9-]+, got {v!r}` |
| `table.rows[{word}]` | the forms, readings and IPA messages of `check_pattern` (reuse `check_pattern_readings` and `check_pattern_ipas`; `forms missing slots: [...]`, `forms has key {k!r} which is not a slot`, `every form is null; nothing to drill`, `forms[{slot!r}] lists a form twice`, …) |
| `table.rows[{word}]` | `readings is required: the script is {script!r}` |
| `{where}` | `key {k!r} was read as {type}; quote it` (2.6) |
| `rules` | `is required on a rules deck: a non-empty list of rules` |
| `rules[{i}]` | `must be a mapping`, `unknown field {key!r}` |
| `rules[{i}]` | `id must be {lang}-rule- and a name, such as {lang}-rule-past, got {v!r}` |
| `rule {id}` | `duplicate rule id` |
| `rule {id}` | `slots must be a non-empty list of the table's slots`, `{slot!r} is not a slot of the table`, `{slot!r} is also in rule {other}; a slot belongs to one rule` |
| `rule {id}` | `words[{k}] needs word, and its reading in a script that needs one` |
| `table.slots` | `{slot!r} belongs to no rule` |

Warning: `table.rows[{word}]: has one form only, so its grammar questions cannot offer a choice`.

### 4.3 Across: every taught word of its kind has its row

For each rules core given now, against the language's cards (2.4, 2.8):

- each row's `word` names a vocab card the language writes: else
  `error: {file}: table.rows[{word}]: no vocab deck writes card {word}`;
- that card's `pos` is in `applies_to.pos` (and it has one of
  `applies_to.tags` when given): else
  `error: {file}: table.rows[{word}]: {word} is a {pos or 'word with no pos'}, not one of {pos list}`;
- it is not a phrasebook card:
  `error: {file}: table.rows[{word}]: {word} is a phrasebook card; its words are taught as words`;
- it is not in `except`:
  `error: {file}: table.rows[{word}]: {word} is both a row and in applies_to.except`;
- it has a reading where the script needs one, since a typed cell shows
  the word with its reading (4.6):
  `error: {file}: table.rows[{word}]: {word} has no reading, but the script is {script!r}; a typed cell shows the word with its reading`;
- each `except` id names a card the language writes:
  `error: {file}: table.applies_to.except: no deck writes card {id}`;
- **every vocab card a B1 deck of the language teaches** (2.8: the cards
  of every course's B1 decks, merged or single-file), that is not
  phrasebook, whose `pos` is in `applies_to.pos` (with one of
  `applies_to.tags` when given) and is not in `except`, has a row:
  `error: {file}: table: {id} ({target}) is a {pos} taught in {deck} but has no row; add its forms, or list it in applies_to.except`
  (`{deck}` the first B1 deck, in path order, that teaches it).

"The rows are the words of the right kind the learner has been taught"
(`words-rules-sentences.md` §3): the words of the B1 decks are what a
learner of the plan is taught, so the requirement follows the plan, as the
other B1 checks do (2.8). A single-file deck on no B1 plan (every deck
today) never needs a row; a row may still name its card. A noun only a
Bengali layer teaches needs its row too, which English learners never see
(4.6 skips a row with no card in their language).

**OPEN-9, error or warning.** The owner's words are "the validator checks".
Recommended: an error, with `except` as the escape, over the B1 decks'
cards as above. It means a noun added to a B1 deck needs its row in every
noun table in the same change, which is the point.

### 4.4 Rule ids across the language

- `error: {file}: rule {id}: is also defined in {other file}` (unique per
  language, across the rules cores given now and among the language's
  files);
- the ids sentences name are checked in 5; the ids a path's grammar topics
  name, in 10.3.

### 4.5 The layer of a rules core

```yaml
schema: 1
id: "te-en-grammar-case-endings"
kind: "layer"
core: "te-grammar-case-endings"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "In, to, with, from: case endings"
license: "CC0-1.0"
table:
  slot_name: "case"
  slots:
    "lo": "in {meaning}"
    "ki": "to {meaning}"
    "to": "with {meaning}"
    "nunci": "from {meaning}"
  prompts:
    "te-9001": { "lo": "at home", "ki": "home (going there)" }
rules:
  "te-rule-lo":
    name: "-లో (-lō): in"
    explanation: "{1} means in. It joins the noun's oblique stem: {2} becomes {3}."
  "te-rule-ki":
    name: "-కి (-ki): to"
    explanation: "{1}, or {2} after some nouns, means to: to a place, or to the person given or told something."
  "te-rule-to":
    name: "-తో (-tō): with"
    explanation: "{1} means with: with a person, or with a tool."
  "te-rule-nunci":
    name: "నుంచి (nuñci): from"
    explanation: "{1} follows the noun as a separate word and means from."
```

**`table`** (required): `slot_name` (required text); `slots` (required: a
mapping giving **every** core slot its label, which is also the cell's
prompt template, 4.6); `prompts` (optional: a mapping from a row's `word` to
a mapping from slot to the whole prompt for that cell, for a phrase the
template gets wrong).

**A label's only placeholder is `{meaning}`.** The word itself is not
written into labels: the app shows it, with its reading, on every typed
cell (4.6), as the owner's typing question gives "the word and the
meaning". A label without `{meaning}` is allowed (4.6 prefixes the
meaning).

**`rules`** (required): a mapping from each rule id to `{ name, explanation }`,
both required text. **A rule the layer leaves out is not taught from this
language, and its cells are not asked** (4.6 skips them); it lowers the
coverage info.

| where | message |
|---|---|
| `table.slot_name` | `is required` |
| `table.slots` | `gives no label for {slot!r}` / `{key!r} is not a slot of the core` |
| `table.slots.{slot}` | `uses unknown placeholder {{{token}}}; a label may use {{meaning}}, and the word is shown with every typed cell` |
| `table.prompts` | `{word!r} is not a row of the core` / `{slot!r} is not a slot of the core` |
| `rules` | `{id!r} is not a rule of the core` |
| `rules.{id}` | `name is required` / `explanation is required` |
| `rules.{id}.explanation` | (the placeholder messages of 6.4) |

Info: `rules: covers {n} of {m} rules of {core}`, followed, when `n < m`,
by `; the cells of {", ".join(missing ids)} are not asked`.

### 4.6 Expansion into cards (D)

For each row (in order) whose word has a card in this native language
(`wordOf`, 9.3; a row without one is skipped), and each slot index `i`
whose form is not null **and whose rule has an entry in the layer's
`rules`**:

- **id:** `{core id}-{part}-{i}`, `part` being the row's `key`, else the
  digits of its `word` (`te-grammar-case-endings-9001-0`). Stable while the
  core id, the row's word or key, and the slot order are unchanged. A
  skipped slot or row does not shift any other cell's id.
- **target:** the first form; **altTarget:** the rest; **reading** and
  **altReading** from `readings`; **ipa** from `ipas`.
- **native:** the layer's `prompts[word][slot]` if given; else the slot's
  label with `{meaning}` replaced by the word's meaning; a label without
  `{meaning}` gives `"{meaning}: {label}"`. **The word's meaning** is the
  first part of its card's `native` in this native language, split as
  `Card.meanings` splits (`/`, `;`, `,` outside brackets), else the whole
  `native`. This is the meaning to express: "with mother".
- **modes:** `{grammarUnderstood, grammar}` (4.7).
- **rule:** a `RuleCell` (9.3) with the rule id owning the slot, the word's
  card id, its `target` and `reading` (from `wordOf`), the slot key, and
  `options`: one `RuleOption(form, prompt)` per **other cell of the same
  row that this expansion makes** (so never a form of a rule this layer
  leaves out), in slot order, `form` being that cell's first form and
  `prompt` its `native`, keeping only the first of equal forms and none
  equal to this cell's target.
- **notes:** none; the rule's explanation is shown with the taught details.

**What the learner is shown** (D, in `Card.promptFor`, so every screen
agrees):

- for `grammarUnderstood` (shown a form, choose its meaning; 4.7): the
  cell's form with its reading, `'{target} ({reading})'`, or `'{target}'`
  when the cell has no reading ("అమ్మతో (ammatō)"); the options are
  meanings (4.8);
- for `grammar` on a card with a `rule` (choose or type the form): the
  word and its reading, then the meaning to express:
  `'{word target} ({word reading}): {native}'`, or
  `'{word target}: {native}'` when the word has no reading
  ("అమ్మ (amma): with mother"); the options, when it is chosen, are forms;
- an existing grammar cell (no `rule`) keeps `native`, as today.

The validator holds every row's word to having a reading where the script
needs one (4.3), and labels to `{meaning}` (4.5), so a produced rule cell
always shows the word: only the rule is tested. A cell's `native` is the
meaning the understood question asks for, so two cells of one row with the
same `native` cannot be told apart by meaning; 4.8 leaves such options
out.

A rule card itself is not a scheduled card. `Deck.rules` carries the rules
the layer gives, for the lesson's teach step; mastery of a rule is counted
from its cells' answers (`words-rules-sentences.md`; not part of this
format).

### 4.7 Two grammar schedules: `DrillMode.grammarUnderstood`

The owner, 2026-10-09: "Choosing the meaning = understood". So, in the
skill model's words since (`skill-model.md` on #432, lines 286–291):
"**Understood is shown a form and choosing what it means;** choosing
among forms of the same word, the rule cards' question, or typing the
form, is produced (owner, 2026-10-09, settling `b1-format-spec.md` #22)."
Both schedules are built with the B1 format, not in the skill model's
pull request (OPEN-23, settled), so both belong to this branch: D adds
the mode and the data (this section), Q the questions and their
scheduling (4.8).

- **`grammar` keeps its name and its meaning: grammar produced.** Its
  questions give the meaning to express and ask for the form: on an
  existing grammar cell, typed, as today; on a rule cell, the form chosen
  among the same word's forms (`Ask.chooseForm`, while the pair is new or
  was last missed) or typed (once it was last remembered), as Hear
  chooses and then types (ADR-0034). Every existing grammar cell stays
  `{grammar}` only, and every existing `reviews` and `leech_actions` row
  with mode `grammar` keeps meaning exactly what it meant, a typed form:
  the skill model's "grammar into grammar produced" is the identity. No
  row is rewritten (AGENTS.md rule 9).
- **New: `grammarUnderstood`, grammar understood:** shown a form,
  అమ్మతో (ammatō), choose what it means among the meanings of the same
  word's forms: "with mother", "to mother", "in mother", "from mother"
  (`Ask.chooseFormMeaning`, 4.8). It is the rule's passive recognition:
  form to meaning, as Recognition is for a word (Laufer & Goldstein
  2004's order, in `docs/research/skill-evidence.md`). It is stored in
  the log by that name, `"grammarUnderstood"`, through drift's
  `textEnum`, so its place in the enum does not matter to storage. D puts
  it immediately before `grammar`, so that a session ordered by
  `DrillMode.values` asks for the meaning before the form, as
  Recognition comes before Write.
- **OPEN-22, settled: reading B** (owner, 2026-10-09). This spec had
  recommended the opposite reading (choosing the form is understood),
  from an earlier line of `skill-model.md` that the owner's answer
  supersedes. **The format did not change for it:** each `RuleOption`
  carries both the form and its prompt (4.6), so no deck, id or stored
  mode name changes; only which question each mode asks.
- **OPEN-10, the name.** `grammarUnderstood`, the skill model's own name
  for the schedule. Rejected: renaming `grammar` to `grammarProduced`
  (the log is append-only and holds `grammar`; ADR-0034 kept old names
  for the same reason), and `grammarChoice` (names a question, and both
  schedules now choose).
- **In decks:** only a rules table's cells take it. V adds it to `MODES`
  and refuses it in a card's or a ref's `modes`:
  `card {id}: grammarUnderstood is only for a rules table's cells` (where
  `ref {id}` for a ref). D's `mode()` refuses it as it refuses `reading`.
- **What it implies in the `SkillMap` (OPEN-11): nothing, either way.**
  `SkillMap.impliedBy(DrillMode.grammarUnderstood, deckId)` returns `{}`,
  and `impliedBy(DrillMode.grammar, deckId)` stays `{}`, as on #432. A
  right answer in either grammar schedule counts for its own pair alone,
  in FSRS and in the ability layer; a miss is blamed on its own skill
  alone, since there is no implied skill to split it over. Only what the
  research supports (`docs/research/skill-evidence.md` and
  `docs/plans/skill-model.md` on #432):
  - **For grammar, practice is skill-specific:** "understanding and
    producing practice build partly separate skills (DeKeyser 1997;
    Shintani et al. 2013)", and "learning to produce helps production
    most, learning to understand helps understanding most (Steinel et al.
    2007; Webb 2009; DeKeyser 1997)" (`skill-model.md`, "The
    research").
  - **The direction that gives Write's credit to Recognition** (production
    implies reception in part: Laufer & Goldstein 2004; Webb 2009;
    Steinel et al. 2007) is evidence about words. `skill-evidence.md`
    gives no study of it, and no figure, for a rule's forms and their
    meanings.
  - **Its one grammar row, "the typed form implies the chosen form"**
    (González-Fernández & Schmitt 2020; González-Fernández 2025; Medium,
    no figure), relates two questions that both record `grammar` now
    (the form chosen and the form typed): one schedule, so it needs no
    `SkillMap` entry. The choose grade (below) is how the two differ.
  - **No word skill either:** its gaps list "grammar practice crediting
    lexical skills" as without evidence, so a rule cell's answer moves
    neither the word's Write nor its Recognition.

  Should evidence for produced implying understood appear, the change is
  one arm, `DrillMode.grammar => {DrillMode.grammarUnderstood:
  SkillMap.implied}`, as Write's is. Q adds the `grammarUnderstood` arm
  (returning `{}`) to `impliedBy`'s switch, which is exhaustive.
- **Grades:** a right `Ask.chooseFormMeaning` records 4 (Good), as a
  right choice of a meaning seen does in Recognition; a right
  `Ask.chooseForm` records 3 (Hard), as a right choice in Write or Hear
  does; a typed form records as today (ADR-0034: "A right choice counts
  for less than a right recall").
- **Fitted per language and skill, like the others.** Nothing new is
  needed, because #432 keys everything by mode: FSRS's parameters are
  fitted and kept per `SkillKey`, `(language, mode)`
  (`skill_parameters.dart`), and the ability layer rates per
  `AbilityKey`, `(language, mode)` (`ability.dart`). So
  `(te, grammarUnderstood)` has its own fitted set beside
  `(te, grammar)`: FSRS-6's defaults until it has enough reviews to fit;
  in a language with no fit of its own for it, the fit of
  `grammarUnderstood` in the language studied most recently; refitted by
  the Settings button, and automatically once its reviews have grown by
  10% since its last fit; learning from its last three months or its
  last 1,000 reviews, whichever is more; kept in the database and the
  backup by its mode's name (`skill-model.md`, "Decided": "FSRS fitted
  to the learner, per skill"). Its Elo rating starts like any skill's. Q checks
  that the fitting, the backup and "How you learn" walk
  `DrillMode.values` (or a list that gains the new mode), not a fixed
  list of today's modes, and adds it where one does not; how its name
  reads on "How you learn" waits for `settings-wording.md`, as the other
  skills' wording does.
- **D's part** (so the app compiles and behaves as before for every
  existing deck): `isMachineGraded` true; `Card.acceptedAnswers` for
  `grammarUnderstood` is the cell's meaning, `native` (what is chosen);
  `promptFor` as 4.6; `Skill.of` maps it to `Skill.grammar`, the tile
  "understood and produced share" (skill model, decided 2026-10-08).
  **Until Q's work lands, `Card.modesIn` leaves `grammarUnderstood` out**
  (a one-line filter beside the voice and recogniser filters, with a
  `// Removed by the grammar questions (spec 4.8).` comment), so a rule
  cell is asked only as `grammar`, typed, and no session can reach a
  question the app cannot show. The cells still declare both modes. The
  branch does not merge with the filter in place.
- **Not added to existing grammar decks** (OPEN-12: recommended later, for
  a `kind: grammar` table whose rows give at least two forms).

### 4.8 The grammar questions and the second schedule (Q)

(OPEN-23, settled: the owner put both schedules in the B1 format.) Q
builds on D's models, after the skill model's pull request (#432) has
merged and the branch is rebased on `main` (the skill model rewrites
`lib/core/scheduling/skill_map.dart`, `ask.dart`, `session_queue.dart`
and the review question kinds; building on their old shapes would be
rework). Behaviour, for reading B (OPEN-22, settled):

1. **`Ask.chooseFormMeaning`** (new, in `lib/core/scheduling/ask.dart`),
   the question of `grammarUnderstood`: shown the cell's
   `promptFor(grammarUnderstood)`, the form with its reading, choose its
   meaning among the cell's `native` and up to three
   `RuleCell.options`' `prompt`s, shuffled, keeping only options whose
   `prompt` differs from the cell's `native` and from each other's;
   `chooses` and `choosesMeaning` are true; the options are meanings
   (strings) of the same row's cells, never another word's. Recorded as
   `grammarUnderstood`.
2. **`Ask.chooseForm`** (new), a question of `grammar` on a rule cell:
   shown `promptFor(grammar)`, choose the target among the target and up
   to three `RuleCell.options`' forms, shuffled; the options are forms,
   never another word's. Recorded as `grammar` (Ask's rule: whichever
   way, it records the item's own mode).
3. **Which cells:** a rule cell with at least one option whose `prompt`
   differs from its own `native` gets `grammarUnderstood` from
   `Card.modesIn`; any other is asked only as `grammar`. Q replaces D's
   temporary filter with this rule.
4. **Reviews:** a `grammarUnderstood` item is asked
   `Ask.chooseFormMeaning`. A `grammar` item on a rule cell with at least
   one option is asked `Ask.chooseForm` while its pair is new or was last
   missed (no repetitions), and typed once it was last remembered, as
   `reviewAsks` asks Hear; one with no option is typed. A typed rule cell
   shows the word and its reading (4.6). An existing grammar cell is
   typed, as today.
5. **Lessons** (`lessonQuestions` in `lib/core/scheduling/lesson.dart`): a
   rule cell's questions are `(grammarUnderstood, chooseFormMeaning)`
   then `(grammar, chooseForm)`, understood before produced; an existing
   grammar cell keeps `[(grammar, own)]`.
6. **The screen:** `ChoiceDrill` (`lib/features/drill/choice_drill.dart`)
   shows both: `Ask.chooseFormMeaning` as the form with its reading, then
   the meanings as `ChoiceTile`s, as `chooseMeaning` shows a word's;
   `Ask.chooseForm` as the prompt, then the forms as `ChoiceTile`s with
   their readings, as `chooseWord` shows words. `drill_page.dart`
   dispatches `grammarUnderstood`, and a `grammar` item asked
   `chooseForm`, to it.
7. **Skills, settings and the scheduler:** the grammar tile and the
   grammar switch cover both modes (`Skill.of` maps both; Q makes a
   grammar-skill session's `modes` include `grammarUnderstood`); the
   `SkillMap` arm, the grades and the fit as 4.7 says.
8. **Tests:** a meaning question offers only meanings of the same row's
   cells, distinct, never one of a rule the layer leaves out, and records
   `grammarUnderstood` with 4 when right; a form question offers only
   forms of the same row, records `grammar` with 3 when right, and gives
   way to typing once the pair was remembered; a one-form row is never
   asked to choose; a row whose other cells share its meaning gets no
   meaning question; `SkillMap.impliedBy` gives nothing for either
   grammar mode; FSRS fits `(language, grammarUnderstood)` on its own;
   an existing grammar deck's sessions, lessons and logs are unchanged;
   the typed rule cell shows the word and its reading.

How the options are held on the session, and the widget's internals, are
Q's choice.

---

## 5. `rules:` on a sentence

```yaml
  - id: "te-9002"
    target: "నేను ఇంటికి వెళ్తాను."
    reading: "nēnu iṇṭiki veḷtānu."
    rules: ["te-rule-ki"]
```

The rules the sentence uses, by rule id: the unlock gate's data (the
sentence is offered once its words, by their bases, and these rules are
mastered; `words-rules-sentences.md` §4). It belongs to the sentence in the
language learnt: written on a single-file card, a core card or a layer-only
card; **not on a ref** (`a ref cannot give 'rules': ...`, as `CARD_KEYS`
gains it and `REF_KEYS` does not).

| where | message |
|---|---|
| `card {id}` | `rules must be a list of rule ids, such as ["{lang}-rule-past"]` |
| `card {id}` | `rules[{i}] must be a {lang} rule id, {lang}-rule- and a name, got {v!r}` |
| `card {id}` | `rules lists {rid!r} twice` |

Across: `error: {file}: card {id}: rules names {rid}, which no rules deck of {lang} defines`
(`cards.{id}` as where for a layer-only card), resolved against the rules
cores given now and among the language's files.

**Dart:** `Card.rules`, `List<String>`, empty by default.

---
## 6. Typed notes

### 6.1 The single-file form

```yaml
    notes:
      - { kind: "pair", ref: "te-9003", text: "Not కాలం (kālam), time: the a is long there." }
      - { kind: "culture", text: "A pen was a gift for the first day at school.", source: "https://example.org/telugu-school-customs" }
      - { kind: "usage", text: "Also a pen-name, in old usage." }
      - { kind: "behaviour", id: "plural", text: "Its plural is {1}.", words: [{ word: "కలాలు", reading: "kalālu" }] }
      - { kind: "note", text: "A word from Arabic, through Persian." }
```

A **region note** names the regions it is about (10.5). On ఉల్లిపాయ
(ullipāya), onion, whose note in `te-en-groceries` today is the prose "In
Telangana often ఉల్లిగడ్డ (ulligaḍḍa).":

```yaml
    notes:
      - { kind: "usage", region: "telangana", text: "In Telangana often {1}.", words: [{ word: "ఉల్లిగడ్డ", reading: "ulligaḍḍa" }] }
```

`notes` is **either** today's string, read as one note of kind `note`
(`id` `"1"`), **or** a non-empty list of notes. On a single-file card, a
layer-only card, and a ref in a single-file deck (a ref's list replaces the
card's, by ADR-0018's rule for `notes`).

**An empty or all-whitespace string** (`notes: ""`) reads as **no notes**,
in both V and D: today's validator accepts it, and it must not become one
empty note.

| Field | Required | Notes |
|---|---|---|
| `kind` | yes | `pair`, `culture`, `usage`, `behaviour` or `note`. |
| `text` | yes | The note, in the deck's native language. Script in prose applies. |
| `id` | no | A **note id**: `[a-z][a-z0-9]*(-[a-z0-9]+)*`, not one of `yes`, `no`, `on`, `off`, `true`, `false`, `y`, `n`; unique in the card. A note without one has its 1-based position as its id, `"1"`, `"2"`, …, which only this single-file form has; since a written id starts with a letter, the two never clash. The app remembers which notes it has shown by card id and note id ("never repeated until every note has been shown once"), so a note keeps its id when others are added: give ids once a card has notes that may be reordered. |
| `ref` | `pair` only, required there | The partner, a card of the language that sounds almost the same. |
| `source` | `culture`: required; others: optional | Where the claim can be checked: a URL, or a book with its author and year. |
| `words` | no | Language facts the text quotes, `{ word, reading, ipa? }`, `reading` required in a script that needs one; the text refers to them as `{1}`, `{2}`, … (6.4). |
| `region` | no | Any kind: the note is about how the word is used, or heard, in these regions of the language (10.5). A region id, or a non-empty list of them, each a region of the language's path. A **region note**: an offensive card's note where raters from different regions differ by a band or more (`docs/plans/offensive-words.md` on #432: "a disagreement of a band or more becomes a region note"), and regional vocabulary, such as `te-facts`' Telangana words. |

| where | message |
|---|---|
| `card {id}` | `notes must be text, or a list of notes, each with a kind and its text` (anything else; `_check_optional_text` keeps its boolean and number messages for a scalar) |
| `card {id}` | `notes must not be an empty list; leave it out` |
| `card {id}` | `notes[{i}] must be a mapping` / `notes[{i}]: unknown field {k!r}` |
| `card {id}` | `notes[{i}].kind must be one of behaviour, culture, note, pair, usage, got {v!r}` |
| `card {id}` | `notes[{i}].text is required and must be non-empty text` |
| `card {id}` | `notes[{i}].id must start with a letter and match [a-z0-9-]+, and not be a YAML 1.1 boolean word, got {v!r}` / `notes[{i}].id {v!r} is used twice` |
| `card {id}` | `notes[{i}].ref: a pair note names its partner, the id of another {lang} card, got {v!r}` / `notes[{i}].ref names the card itself` |
| `card {id}` | `notes[{i}].ref is only for a pair note` |
| `card {id}` | `notes[{i}].source: a culture note names where its claims can be checked` |
| `card {id}` | `notes[{i}].words must be a list of {{ word, reading }}` / `notes[{i}].words[{k}] needs word, and its reading in a script that needs one` |
| `card {id}` | `notes[{i}].region must be a region id, or a list of them, such as "telangana", got {v!r}` / `notes[{i}].region lists {r!r} twice` |
| `card {id}` | (the placeholder messages of 6.4, prefixed `notes[{i}].text `) |

Across: `error: {file}: card {id}: notes[{i}].ref names card {ref}, which no deck writes`
(from `Report.note_refs`, beside today's `pair` check); a region note's
regions against the language's path (10.5); and 6.5.

### 6.2 The core form

A core card's notes hold the language facts only; the text is in each layer.

```yaml
    notes:
      - { id: "pair", kind: "pair", ref: "te-9003" }
      - { id: "school", kind: "culture", source: "https://example.org/telugu-school-customs" }
      - { id: "plural", kind: "behaviour", words: [{ word: "కలాలు", reading: "kalālu" }] }
```

As 6.1, except: `id` is **required** (the layer names the note by it), and
`text` is **not allowed**. A string is not allowed either. `region` is a
fact about the language, the same for every learner, so it is in the
core, never in a layer: `{ id: "telangana", kind: "usage", region:
"telangana", words: [...] }`, with each layer's text keyed by
`"telangana"`.

| where | message |
|---|---|
| `card {id}` | `notes must be a list of notes in a core file; their text is in each layer` (for a string) |
| `card {id}` | `notes[{i}].id is required in a core file: each layer names the note by it` |
| `card {id}` | `notes[{i}].text: a core note's text is in each layer, under cards.{id}.notes.{nid}` |

**OPEN-13, `source` on culture notes.** Recommended in the core, shared by
every layer, since a URL or a book does not change with the reader. A
layer cannot add its own.

### 6.3 The layer form

```yaml
  "te-9005":
    native: "pen"
    notes:
      "pair": "Not to be confused with కాలం (kālam), time: the a is long there."
      "school": "A new pen was a gift for the first day at school."
      "plural": "Its plural is {1}."
```

A mapping from the core note's id to its text (required non-empty text).
Placeholders refer to the **core** note's `words`.

### 6.4 Placeholders

In a note's text and a rule's explanation, a **placeholder** is a match of
`\{([1-9][0-9]*)\}`: `{1}`, `{2}`, … `{12}`. It is replaced by the `n`-th
of the note's (rule's) `words`, written `word (reading)`, or `word` alone
when it has no reading. A match of `\{([0-9]+)\}` that is not a placeholder
(`{0}`, `{01}`) is an error. Every other brace is literal (`{x}`, `{ 1 }`,
a lone `{`). V and D use these two regular expressions, character for
character.

The validator checks the text before substitution (so a layer that quotes
its words through placeholders contains no script and needs no readings).

| Text | where | message |
|---|---|---|
| any | (as below) | `uses {{{n}}}, but the {note / rule} has {k} words` |
| any | (as below) | `{tok} is not a placeholder: placeholders count from {{1}}, without leading zeros` |
| any | (as below) | warning: `never uses {{{n}}}, {word}` (a word in `words` the text does not use) |

The where, and the prefix, for each text:

- a single-file or layer-only note: where `card {id}` (`cards.{id}` for a
  layer-only card), message prefixed `notes[{i}].text `;
- a layer's note text for a core note: where `cards.{id}.notes.{nid}`;
- a layer's rule explanation: where `rules.{id}.explanation`.

D's parser raises the two errors for single-file notes; `mergeLayer`
raises them for layer texts (the `words` are in the core).

**OPEN-14, the placeholder mechanism.** The owner decided "notes about the
language learnt keep their language facts (the words and readings) in the
core; each layer writes the explanation around them". Recommended:
placeholders, as above, so a fact is written once and every layer shows the
same spelling and reading. A layer may still quote a word directly, with its
reading (Script in prose).

### 6.5 What else the validator checks on notes

- **Warning, on the cards of B1 decks** (2.8; `b1-plans.md` lines 221–222:
  "Every word card should have one or more; a word card with none gets a
  validator warning"): a word card with no notes. A word card is one for
  which `counts_as_word` (8.5) is true. Attached in the across phase to the
  file that writes the card: `card {id}: no notes; every word card should
  have one or more (pair, culture, usage, behaviour, note)` on a core or
  single-file deck, with where `cards.{id}` on a layer for a layer-only
  card. A core note with no text in some layer is then a layer warning
  (2.6).
- **Warning, on the cards of B1 decks:** a single-file or layer-only card
  with `pair: X` and no pair note naming `X`:
  `card {id}: pair names {X}, but no pair note does; the minimal-pair button needs a pair note`
  (`cards.{id}` on a layer).
  **OPEN-16, settled: pair notes are the one source** (owner,
  2026-10-09: "derived from the pair notes, as recommended"; `b1-plans.md`
  lines 223–225: "pair notes are proposed by a tool ... The same pairs
  give Hear its sound-alike options"). A core has no `pair:` (2.3); a
  merged card's `pair` is its first included pair note's `ref` (2.7); a
  single-file or layer-only card's `Card.pair` is its `pair:` when
  written, else its first pair note's `ref` (D, 9.4). `pair:` stays valid
  on single-file decks so that today's decks keep their Hear options.
- **Error, a pair note's partner is taught in the course** (`b1-plans.md`
  lines 245–246: the panel shows "the two words side by side, each with
  its reading and meaning"). For every pair note a course shows, its `ref`
  is a card the course teaches (2.8), so the partner has a meaning in the
  learner's language:
  - a single-file deck, or a layer-only card:
    `error: {file}: card {id}: notes[{i}].ref names {ref}, which no {lang}-{native} deck teaches; the minimal-pair panel shows both words with their meanings`
    (`cards.{id}` as where on a layer);
  - a core note a layer gives text to:
    `error: {layer}: cards.{id}.notes.{nid}: the partner {ref} is not taught from {native name}; translate it in a {lang}-{native} deck, or leave this note's text out`.

  The minimal-pair panel is not part of these builds; when it is built, it
  hides its button where the partner is not in the catalog for the
  learner's native language, so a deck added by a learner cannot open a
  panel with a word that has no meaning. W writes this rule into
  `docs/DECK-FORMAT.md`'s Notes section.
- **Error, culture notes stay marked unreviewed** (`b1-plans.md` lines
  228–230: "the deck stays marked unreviewed until a speaker checks it
  (owner's choice)"). The validator cannot tell a checked deck from a
  forgotten tag, so a speaker's check is written as the tag `reviewed`
  (OPEN-29). A file that holds a culture note's claim (a core with a culture
  note, a single-file deck with one, a layer with a layer-only card that
  has one) carries exactly one of `unreviewed` and `reviewed` in `tags`:

  | where | message |
  |---|---|
  | `tags` | `has culture notes, so it is tagged "unreviewed" until a speaker checks them, then "reviewed" (#99)` |
  | `tags` | `"reviewed" and "unreviewed" together; a deck is one or the other` |

  **The tag belongs to the file that holds the claim:** the core for a core
  card's culture note (its `source` and facts are there), the layer for a
  layer-only card's. A layer may also carry `unreviewed` for its own texts;
  the merged deck's tags drop `reviewed` when either file says
  `unreviewed` (2.7), so a learner sees the deck as unreviewed until both
  are checked. Per-file, so no across work; today no deck has a culture
  note.

### 6.6 Dart

```dart
enum NoteKind { pair, culture, usage, behaviour, note }

class CardNote {
  const CardNote({required this.id, required this.kind, required this.text,
      this.ref, this.source, this.regions = const <String>[]});
  final String id;        // the note's id, or its 1-based position
  final NoteKind kind;
  final String text;      // placeholders already filled
  final String? ref;      // a pair note's partner
  final String? source;   // required on a culture note
  final List<String> regions; // a region note's region ids (10.5); a string reads as one
}
```

`Card.notes` becomes `List<CardNote>` (was `String?`); a non-blank string
reads as `[CardNote(id: '1', kind: NoteKind.note, text: s)]`, a blank one
as `[]`. `CardRef.notes` becomes `List<CardNote>?`. D updates the two
readers, `lib/features/drill/taught_details.dart:97` and
`lib/features/decks/inspect_page.dart:360`, to show the first note's text
(the shuffle "one note at a time, never repeated until every note was
shown" is app behaviour, not this format). `PatternEntry`/`GrammarPattern`
notes stay `String?`.

---

## 7. The Wiktionary link: `wiktionary: true`

`b1-plans.md` lines 264–270: the link "is built from the word and the
language, not stored: `en.wiktionary.org/wiki/<word>#Telugu`", and is
"shown only where Wiktionary has an entry"; "a tool checks each word ...
and marks the words that have one". So the only stored datum is that mark:
`wiktionary: true`, set by the tool. The link is
`https://{edition}.wiktionary.org/wiki/{title}#{section}`, the edition being
the learner's native language, the section the language learnt's name in
that edition, and the title the card's `target` (for an inline base, its
`base`; for a base given by `ref`, the referenced card's target).

**OPEN-17, where the mark lives.** An entry exists or not per edition
(en.wiktionary has a Telugu word that bn.wiktionary may lack), so
recommended: **with the native language**: on a single-file card or ref,
in a layer's card entry, and on an inline base. Not in a core. **A stored
title** where the entry's title is not the target (`la casa`, whose entry
is `casa`) is **not** in this format: the plan says the link is not stored.
The owner is asked whether such an override is wanted later; until then a
card whose target is not an entry's title is simply not marked, and its
`bases` (8) can carry the mark for the entry word.

| Value | Meaning |
|---|---|
| left out | No link. |
| `true` | Wiktionary's edition for this native language has an entry for the title above. |

```yaml
  "te-9001":
    native: "home; house"
    wiktionary: true
```

- **For a sentence or an inflected form** the link is built for each base
  word (`bases`): a `ref` base uses the referenced card's mark; an inline
  base its own (a single-file inline base's `wiktionary`, or the layer's
  `{ meaning, wiktionary }` for a core inline base).
- **On a ref** (single-file deck): it may give its own; otherwise it takes
  the card's when the deck has the same native, as `notes` does.

| where | message |
|---|---|
| `card {id}` | `wiktionary must be true, or left out where Wiktionary has no entry; got {v!r}` (for `false`, a string, a number, a list; `cards.{id}` on a layer, `bases[{i}]` prefixes for a base) |
| core `card {id}` | (the core message of 2.3) |

The marking tool (`b1-plans.md`, "What it takes" 8) is not part of these
builds.

**Dart:** `Card.wiktionary` and `CardBase.wiktionary`, `bool`, default
`false`. `CardRef.wiktionary` is `bool?` (null where the ref gives none),
and `CardRef.resolve` treats it as it treats `notes`: the ref's own when
given, else the written card's when the deck has the card's native. The
title is not stored; the app takes it from the target (or base) when it
builds the link.

---

## 8. `bases:` on a card

### 8.1 Shapes

A base names the base word of an inflected or derived word in the card's
target or in one of its examples ("for 'he went to our school', the card
shall also have 'go' and 'we'").

**Single-file deck, or a layer-only card:**

```yaml
    bases:
      - { word: "ఇంటికి", ref: "te-9001" }
      - { word: "రాదు", base: "రా", reading: "rā", meaning: "to come", wiktionary: true }
```

**Core:**

```yaml
    bases:
      - { word: "ఇంటికి", ref: "te-9001" }
      - { word: "రాదు", base: "రా", reading: "rā" }
```

and the layer gives the inline base's meaning:

```yaml
  "te-9100":
    native: "I don't know Telugu."
    bases:
      "రాదు": { meaning: "to come; here, to know (a language)", wiktionary: true }
```

| Field | Required | Notes |
|---|---|---|
| `word` | yes | The word as it stands in the text: one of the text's words as `_words` splits them (8.3), compared NFC-normalised and case-folded. |
| `ref` | either | The card that teaches the base. Its target, reading and meaning are shown, in the learner's language. |
| `base` | or | The base, written in full, when no card teaches it. |
| `reading` | with `base`, in a script that needs one | The base's reading. |
| `ipa` | no, with `base` | The base in the IPA. |
| `meaning` | with `base`, single-file only | Its meaning. In a core it is in the layer. |
| `wiktionary` | no, with `base`, single-file only | `true` (7). In a core it is in the layer. |

**Examples** take `bases` the same way, on the example:
`examples: [{ target: "...", reading: "...", bases: [...] }]`. In a layer,
a core example's inline bases' meanings go under
`examples: { "<target>": { native: "...", bases: { "<word>": ... } } }`,
each value a string or `{ meaning, wiktionary }`, exactly as a card
entry's `bases`. `EXAMPLE_KEYS` gains `bases`.

**Where:** single-file cards, core cards, layer-only cards, examples. **Not
on a ref:** a base belongs to the word's text (`a ref cannot give 'bases'`).

### 8.2 Per-file checks

| where | message |
|---|---|
| `card {id}` | `bases must be a list of {{ word, ref }} or {{ word, base, reading }}` |
| `card {id}` | `bases[{i}] must be a mapping` / `bases[{i}]: unknown field {k!r}` |
| `card {id}` | `bases[{i}].word is required and must be a non-empty string` |
| `card {id}` | `bases[{i}] gives ref or base, not both` / `bases[{i}] needs ref, or base and its reading` |
| `card {id}` | `bases[{i}].ref must be the id of a {lang} card, got {v!r}` / `bases[{i}].ref names the card itself` |
| `card {id}` | `bases[{i}]: no reading, but script is {script!r}; give the base's reading` (an error here, unlike a card's missing reading: the app shows it) |
| `card {id}` | `bases[{i}].meaning is required beside base` (single-file) / `bases[{i}].meaning: a core file's meanings are in each layer, under cards.{id}.bases` (core; also for `wiktionary`) |
| `card {id}` | `bases[{i}].word {w!r} is not a word of the target` (or `of examples[{j}].target`) |
| `card {id}` | `bases[{i}].word {w!r} is given twice` |
| `card {id}` | `bases[{i}].{key} is only for a base written in full` (`reading`, `ipa`, `meaning`, `wiktionary` beside `ref`) |

(`cards.{id}` in place of `card {id}` on a layer-only card.) **"Is a word of
the target"** and **"given twice"** compare `key(w) =
unicodedata.normalize("NFC", w).casefold()` on both sides, the text's words
being `_words(text)`.

Across: `error: {file}: card {id}: bases[{i}].ref names card {ref}, which no deck writes`.

### 8.3 Words, and coverage (B1 decks)

**Splitting:** exactly `_words()` in `validate_decks.py` (split at
whitespace; within a chunk every character of Unicode category P, S or Z
except `’` and `'` becomes a space; split again; strip `’'` from each end;
drop empty and all-digit pieces; NFC), then `casefold()` for comparing.
D ports the split as `wordsForBases` (no NFC, #28; the parser does not
check bases words, so this does not affect parity).

**Coverage, error** (`b1-plans.md` lines 182–185: "The validator, for every
deck in a B1 plan: every word of a target or example that is not itself the
target of a card in the course has a `bases` entry"). For every B1 deck
(2.8) and every card it writes or includes (a core's included cards are
checked once per course whose B1 deck includes them; a layer-only card in
its layer; a single-file deck's written cards; refs are checked where their
card is written), phrasebook cards included ("its base words say which"),
every word `w` of the target, and of each included example's target, is
either

- **a taught word of the course:** some vocab card the course teaches
  (2.8), not phrasebook, has a target or an `alt_target` whose
  `_words` are exactly `[w']` with `key(w') == key(w)`. Grammar and rules
  cells and reading questions do not count: an inflected form taught as a
  cell is still a derived word that names its base. A card taught only
  from another native language does not count. Or
- the `word` of one of that text's `bases` entries (by `key`);

else, attached across:

`error: {file}: card {id}: {w!r} is not a word the {lang}-{native} course teaches as a card, and has no bases entry; add {{ word: "{w}", ref: ... }}, or {{ word: "{w}", base: ..., reading: ... }}`
(`card {id}: examples[{j}]: ...` for an example; `cards.{id}` on a layer;
`{file}` the file that writes the text, a core's error naming the course
whose B1 deck includes it).

- **Decks on no B1 plan are not checked** (OPEN-15), exactly as the plan
  scopes it: "Existing decks gain their bases as each language's B1 plan is
  written." A deck the plan lists is checked whether it is a merged deck or
  still single-file.
- **Scripts without spaces** (`han`, `kana`, `thai`). `b1-plans.md` lines
  187–188: "Scripts without spaces need their words given
  (`language-paths.md`)." This format has no field for that yet (OPEN-26,
  settled: owner, 2026-10-09, "later, as recommended"; a `words` field is
  designed with the first such language's B1 plan). So a B1 deck in such
  a script is an error, not a silent skip:
  `error: {path}: units[{i}]: {deck} is in the {script} script, written without spaces; bases cannot be checked until the format gives its words (OPEN-26)`
  (`{deck}` the course's deck for the listed core id).
  No language being written for B1 now (Telugu, Bengali) uses one.

### 8.4 Dart

```dart
class CardBase {
  const CardBase({required this.word, this.ref, this.base, this.reading,
      this.ipa, this.meaning, this.wiktionary = false});
  final String word;        // as it stands in the text
  final String? ref;        // the card teaching the base, or
  final String? base;       // the base written in full,
  final String? reading;    //   with its reading,
  final String? ipa;
  final String? meaning;    //   and its meaning in the learner's language
  final bool wiktionary;    // Wiktionary has an entry for base (7)
}
```

`Card.bases` and `CardExample.bases`: `List<CardBase>`, empty by default.
Shown with the taught details at teaching and after an answer, never before
one (app behaviour).

### 8.5 Counting words (shared by the validator's B1 checks and the app)

`counts_as_word(card, deck_kind)` (Python, in `validate_decks.py`) and
`bool countsAsWord(Card card, DeckKind kind)` (Dart, a top-level function in
`lib/core/models/deck.dart`) are true iff:

- the card is in a vocab deck (single-file, merged, or a layer-only card;
  not a grammar or rules cell, not a reading question), and
- it is not `phrasebook`, and
- its `pos` is not `phrase`, and
- its target is **one word** by `_words`, **or** its `pos` is `noun`,
  `verb`, `adj`, `adv` or `pronoun` (a several-word lexical item such as a
  compound verb).

**OPEN-18:** the plans count "distinct vocabulary cards"; recommended as
above, so that sentences and phrases do not count as words. A unit's words
**in a course** are the distinct ids of such cards written, included, or
listed by ref in the course's decks for the unit's core ids, leaving out
alphabet decks (the path's `alphabet`), grammar and rules decks, reading
decks and `"*"`. A unit can teach a different number of words to learners
from different native languages (a layer may skip a card, or add its
own), so words are counted per course, against the one planned size.

---
## 9. Dart: parser and models

### 9.1 Files

| File | Change |
|---|---|
| `lib/core/models/drill_mode.dart` | `grammarUnderstood`, before `grammar` (4.7). |
| `lib/core/models/card.dart` | `Card`: `phrasebook`, `bases`, `rules`, `notes` (now `List<CardNote>`, each with its `regions`), `wiktionary` (`bool`), `rule` (`RuleCell?`); `promptFor` as 4.6. `CardExample.bases`. `CardRef`: `notes` as `List<CardNote>?`, plus `wiktionary` (`bool?`); `resolve` carries `phrasebook`, `bases`, `rules`, `rule` from the written card and treats `wiktionary` as it treats `notes`. New: `CardNote`, `NoteKind`, `CardBase`. |
| `lib/core/models/deck.dart` | `DeckKind.rules`; `Deck.table` (`RuleTable?`), `Deck.rules` (`List<Rule>`, empty by default); the top-level function `bool countsAsWord(Card card, DeckKind kind)` (8.5). |
| `lib/core/models/rule.dart` (new) | `AppliesTo`, `RuleRow`, `RuleTable`, `Rule`, `RuleCell`, `RuleOption`, `NoteWord`. |
| `lib/core/data/deck_parser.dart` | The new card fields on single-file decks; the dispatch refusals in `parse()` (9.2); `parseCore`, `parseLayer`. |
| `lib/core/data/deck_layers.dart` (new) | `DeckCore`, `DeckLayer`, `mergeLayer`. |
| `lib/core/data/rule_expander.dart` (new) | `expandRules`. |
| `lib/core/data/course_path.dart` | The language's path: `LanguagePath`, `parseLanguagePath`, mapping units, the B1 plan, passages, regions, and `CoursePath` as the view of it for one native language (9.5). |
| `lib/app/deck_catalog.dart` | Route `part: core` and `kind: layer` files, merge, expand rules; read each language's path and build each course's view of it (9.6). |
| app `switch`es on `DrillMode` / `DeckKind` | One arm each, so `flutter analyze` stays clean (4.7). |

`card.dart` and `lib/core/data/*` are contention files (AGENTS.md): D keeps
these commits small and separate.

### 9.2 Entry points

```dart
abstract final class DeckParser {
  static Deck parse(String yaml, {required String source});        // single-file, as today
  static DeckCore parseCore(String yaml, {required String source});  // part: core
  static DeckLayer parseLayer(String yaml, {required String source}); // kind: layer
}

/// [core] and [layer] as one deck, as section 2.7 of the spec defines.
/// Throws DeckParseException (source: the layer's) when the layer does not
/// fit its core: another core id, a card id that is neither the core's nor
/// a layer-only card, a note id or example target or base word the core
/// lacks, notes or examples on a ref the core gives none, a rule or slot
/// the core lacks, a gloss key that is not an entry, a placeholder past the
/// note's or rule's words or not counting from {1} (6.4).
Deck mergeLayer(DeckCore core, DeckLayer layer, {required String source});
```

**`parse()` dispatches as 2.2 does**, and refuses what is not a single-file
deck, each with the same words as the validator:

| Input | Fails at | Message |
|---|---|---|
| `kind: "layer"` | `kind` | `this is a layer; it is read with DeckParser.parseLayer` |
| `part: "core"` | `part` | `this is a core file; it is read with DeckParser.parseCore and merged with a layer` |
| `part` with another value | `part` | `must be "core", or left out on a single-file deck; got {value}` |
| `core` | `core` | `only a layer names a core (kind: "layer")` |
| `table` / `rules` | `table` / `rules` | `only a rules core has {key}; a rules deck is written as a core and layers` |
| `kind: "rules"` | `kind` | `a rules deck is written as a core and layers` |

The `kind` message for an unknown kind lists `vocab, grammar or reading`
as now. `_headerFields` is unchanged; these keys are checked before
`allowOnly`, so they get their own message rather than "unknown field".

`DeckCore` holds: `id`, `kind`, `language`, `license`, `authors`, `source`,
`tags`, `theme`, `cards` (`List<CoreCard>`, written or ref, in order),
`pattern` (`CorePattern?`), `table` (`RuleTable?`), `rules`
(`List<CoreRule>`). `DeckLayer` holds: `id`, `core`, `native`, `name`,
`description`, `license`, `authors`, `source`, `tags`, `cards`
(`Map<String, LayerCard>`, in file order), `pattern` (`LayerPattern?`),
`table` (`LayerTable?`), `rules` (`Map<String, LayerRule>`). Their exact
private shapes are D's choice; they are not used outside `lib/core/data`.

### 9.3 Rule models

```dart
class NoteWord { final String word; final String? reading; final String? ipa; }

class AppliesTo {
  final List<String> pos;          // non-empty
  final List<String> tags;         // empty: any
  final Set<String> except;        // card ids
}

class RuleRow {
  final String word;                           // card id
  final String? key;                           // id part, else word's digits
  final Map<String, String?> forms;            // slot order, null = no form
  final Map<String, List<String>> alternatives;
  final Map<String, List<String>> readings;
  final Map<String, String> ipas;
  final Map<String, String> prompts;           // from the layer, by slot
  String get idPart;                           // key ?? digits of word
}

class RuleTable {
  final AppliesTo appliesTo;
  final List<String> slots;            // keys; order is load-bearing
  final String slotName;               // layer
  final Map<String, String> labels;    // layer, every slot
  final List<RuleRow> rows;
}

class Rule {
  final String id;                     // te-rule-lo
  final List<String> slots;
  final String name;                   // layer
  final String explanation;            // layer, placeholders filled
  final List<NoteWord> words;          // core
}

class RuleOption {
  final String form;                   // another cell's first form
  final String prompt;                 // that cell's native: "to mother"
}

class RuleCell {
  final String ruleId;
  final String word;                   // the row's card id
  final String wordTarget;             // ఇల్లు, shown with every typed cell
  final String? wordReading;           // illu
  final String slot;
  final List<RuleOption> options;      // the row's other expanded cells (4.6)
}
```

`List<Card> expandRules(Deck deck, {required Card? Function(String cardId) wordOf})`
implements 4.6; `wordOf` returns the word's card in this deck's native
language (from the catalog), or null to skip the row. `deck.rules` holds
only the rules the layer gives (4.5).

### 9.4 Single-file parsing of the new card fields

`_cardFields` gains `phrasebook`, `bases`, `rules`, `wiktionary`;
`_refFields` gains `wiktionary`; `_exampleFields` gains `bases`. The parser
checks shape only (types, required keys, one of `ref`/`base`, note kinds,
note id shape, `ref` on a pair note, `source` on a culture note, the
placeholder rules of 6.4, duplicate note ids, `wiktionary` being `true`,
`phrasebook` being `true`), each also a validator error. It does not check
that refs, rules or bases words resolve: the validator does, and the
catalog skips what does not resolve. A single-file card's `Card.pair` is
its `pair:` when written, else its first pair note's `ref` (OPEN-16). A
blank `notes` string reads as no notes (6.1).

### 9.5 Paths

One file per language learnt, `decks/<lang>/<lang>-path.yaml`, read into
a `LanguagePath`; the app then works, as before, with a `CoursePath` per
course, which is the language's path seen from one native language
(OPEN-4, settled; section 10).

```dart
enum Milestone { a1, a2, b1 }   // written "A1", "A2", "B1"

class PlannedDeck {
  final String id;              // a core id: te-health
  final String? theme;          // a theme unit, or
}                               // a grammar unit (its topics are on PlanUnit)

class Passage {
  final String id;                    // doctor-call, unique in the path
  final Map<String, String> texts;    // native code -> description
  String? textIn(String native);      // texts[native], or null
}

class PlanUnit {
  final List<String> decks;     // written: core ids, or (in a CoursePath) the
                                //   course's deck ids; without "*"
  final bool open;              // ends in "*"
  final PlannedDeck? planned;
  final int? words;             // 0 or more on a written unit, 1 or more planned
  final List<String> grammar;   // topic ids (10.1)
  final Milestone? milestone;
  final List<Passage> listeningPassages;
  final List<Passage> readingPassages;
  bool get isPlanned => planned != null;
  bool get isComing;            // planned, or (in a CoursePath) written but
                                //   with no deck in this native language
}

class Region {
  final String id;                    // telangana
  final Map<String, String> names;    // language code -> name; "en" always
  String nameIn(String code);         // names[code] ?? names['en']!
}

class LanguagePath {
  final String id;                    // te-path
  final String language;              // te
  final Set<String> alphabet;         // core ids
  final List<PlanUnit> plan;          // every unit, in file order; core ids
  final List<Region> regions;         // in file order; the app adds Elsewhere
  bool get hasB1Plan;
  int? milestoneIndex(Milestone m);   // into plan
  List<String> get grammarTopics;     // up to B1, each once
  int get plannedWords;               // up to B1

  /// The path as a learner from [native] is taught it.
  CoursePath forNative(String native, {required bool Function(String deckId) exists});
}
```

`CoursePath` keeps its shape and its meaning to every caller: `id`,
`language`, `native`, `units` and `open` over the units with a deck in
this native language, `alphabet` (deck ids), `plan`, `course`
(`'$language/$native'`), `deckIds`, `unitOf`, `placing`. It is no longer
parsed from a file: `forNative` builds it, and Today, lessons, placement,
the Decks tab and the language picker read it exactly as before:

- **A core id becomes the course's deck id** `<lang>-<native>-<name>`
  (2.1), kept where `exists` says the catalog has that deck, dropped
  where it does not. `alphabet` likewise.
- **A written unit with at least one such deck** is in `units` (and in
  `open` if it ends in `"*"`), with only those decks. **A written unit
  with none** is left out of `units` and `open`, as a planned unit is,
  so Today, lessons and placement skip it, and its `plan` entry is
  `isComing`: the Decks tab shows it as "Coming" for this learner, as it
  shows a planned unit (`b1-plans.md`: "Units not written yet show to
  learners as 'Coming'"). It must not stay in `open` empty, where
  `placing` would take it for the unit of `"*"` alone.
- **A unit of `"*"` alone** stays as it is.
- `plan` keeps every unit in file order, its decks mapped as above, its
  passages and its sizes as written, so `hasB1Plan`, `milestoneIndex`,
  `grammarTopics` and `plannedWords` give the same answer for every
  native language. `placing()` copies `plan` unchanged.

**Which native language a learner is taught from** (OPEN-35, settled by
the owner, 2026-10-09: "ask the user"). When more than one of the
learner's spoken languages teaches a language, the app asks the learner
which to learn from, instead of choosing for them:

- **When:** on opening the course the first time, and once more when a
  new native language starts teaching a course already in progress
  (never again for the same pair after an answer).
- **What it shows:** each native language that teaches the course, with
  its **coverage**, the written units of its `forNative(...).units`, a
  unit of `"*"` alone not counted ("From English: 30 of 34 units"; "From
  Bengali: 1 of 34 units so far"). The one with the highest coverage is
  pre-selected, ties going to the best-known spoken language
  (`settings.spokenLanguages`, in rank order), else the first in the
  catalog.
- **After the answer:** the course is taught from that native language
  alone. A unit with no deck in it is "Coming", never filled from another
  native language's decks. Progress is kept per card id, so changing
  later loses nothing already learned in the cores both share.
- **Changing it:** a per-course choice in Settings ("Learn Telugu from"),
  listing the same options and coverage.
- **Only one native language teaches it,** or the learner speaks only
  one of them: no question; that one is used, as today.
- A language with no path: coverage is not defined; the question lists
  the native languages without counts.

Every course in the repository today is taught from English, so no
learner is asked yet. `AppState.courseUnits` reads the stored choice; the
question and the Settings row are new UI for builder D.

One native language per language learnt: a unit whose deck that native
language lacks is "Coming" for the learner, never filled from another
native language's deck (`native-layers.md`: a card a layer does not
translate "is not shown in English"). Card progress
is keyed by card id (ADR-0018), so a learner whose best native language
changes keeps every card's history. Placement is saved by deck id, in
the course it was taken in, and read across the language's courses: a
deck whose core's deck was placed in another course, or whose unit was
placed whole there, reads as placed (`AppState.isPlaced`), so changing
the course's native language keeps it. (Changed on review, 2026-10-09:
this line first said they are "placed afresh", which nothing built, so
the units placed past came back to be taught.)

`parseLanguagePath(String text, {String source})` replaces
`parseCoursePath`. It reads the file of 10.1 and throws
`DeckParseException` on the shape errors of 10.2 that are about the file
alone: a `native` key (the per-course form, with 10.2's message), an id
other than `<lang>-path`, a listed or planned id that is not a core id of
the language (`<lang>-` and a name; whether its name starts with a native
code is the validator's, 10.3), and the unit, passage and region errors
(unknown field, decks and planned together, a `words` that is not a whole
number in range, a bad milestone, a milestone twice, the order of
milestones, a planned unit without its passages, a passage without id or
text, a duplicate passage or region id, a region without its English
name). The cross-file errors (a listed core id with no deck, a planned
deck that exists, topics that do not resolve, word counts, notes naming
regions) are the validator's.

### 9.6 The catalog (`lib/app/deck_catalog.dart`)

`parseAll` reads files as now, and dispatches as 2.2 does: a file whose
`kind` is `layer` goes to `parseLayer`, else one whose `part` is `core` to
`parseCore`, else to `parse` (each error becomes a `BrokenDeck`, as today).
After the loop, each layer is merged with the core its `core` names
(`BrokenDeck` for the layer if the core is missing or broken; a core with
no layer is not shown). The merged decks then join the single-file decks
before ref resolution and pattern expansion, so ADR-0018's resolution
applies to them unchanged. Rules decks are expanded after ref resolution,
with `wordOf` looking up the resolved card of that native language. A
user-imported deck (`deck_import.dart`) is single-file only (OPEN-19:
recommended).

**Paths.** A `kind: path` file goes to `parseLanguagePath`, one per
language (a second, or a file still in the per-course form, is a
`BrokenDeck`). Once every deck is known, the catalog builds
`paths['<lang>/<native>'] = languagePath.forNative(native, exists: ...)`
for each course that has a deck, `exists` asking whether the catalog
holds that deck id, merged or single-file, bundled or added. So
`Catalog.paths`, `pathOf(entry)` and `_placed` keep their keys and their
meaning. A course whose language has no path has none, as today.

---

## 10. The language's path and its B1 plan

### 10.1 Shape

One path per language learnt, `decks/<lang>/<lang>-path.yaml`, shared by
every native language (OPEN-4, settled: owner, 2026-10-09). It lists core
ids (2.1); each learner is taught, for each, their own native language's
deck (10.4).

```yaml
schema: 1
kind: "path"
id: "te-path"
language: "te"
regions:
  - { id: "telangana", name: { "en": "Telangana" } }
  - { id: "coastal-andhra", name: { "en": "Coastal Andhra" } }
  - { id: "rayalaseema", name: { "en": "Rayalaseema" } }
alphabet:
  - "te-script-vowels"
units:
  - decks: ["te-first-words", "te-grammar-sentences", "*"]
    words: 40
    grammar: ["sentences"]
  - decks: ["te-grammar-differences"]
    words: 0
  - decks: ["te-family", "te-grammar-be", "*"]
    words: 45
    grammar: ["be"]
  - ["te-script-vowels"]
  - decks: ["te-home", "te-grammar-case-endings", "*"]
    words: 45
    grammar: ["lo", "ki", "to", "nunci"]
    milestone: "A1"
  - decks: ["te-market", "*"]
    words: 60
    milestone: "A2"
  - planned:
      id: "te-health"
      theme: "health"
      words: 60
    listening_passages:
      - { id: "doctor-call", text: { "en": "Booking a doctor's appointment by phone" } }
    reading_passages:
      - { id: "clinic-notice", text: { "en": "A notice at the clinic" } }
  - planned: { id: "te-grammar-conditional", grammar: "conditional" }
    listening_passages:
      - { id: "rain-plans", text: { "en": "A friend's plans if it rains" } }
    reading_passages:
      - { id: "late-train", text: { "en": "A message: if the train is late" } }
    milestone: "B1"
  - ["te-registers"]
  - ["*"]
```

**The file:**

| Field | Required | Notes |
|---|---|---|
| `schema`, `kind`, `description` | as today | `kind: "path"`. |
| `id` | yes | `<lang>-path`, the filename stem. |
| `language` | yes | The language learnt, `<lang>`, the folder's name. |
| `native` | **not allowed** | The path is every native language's (10.2 says why it is refused). |
| `regions` | no | The language's regions (10.5). |
| `alphabet` | no | The core ids of the decks that need the alphabet, as today's deck ids did. |
| `units` | yes | As below. |

A unit is **a list** (today's form: core ids, ending in `"*"` or not) **or a
mapping**:

| Field | Notes |
|---|---|
| `decks` | The written unit's core ids, as the list form (the wildcard rules unchanged). |
| `planned` | A unit not written yet: `{ id, theme, words }` for a theme unit, `{ id, grammar, words? }` for a grammar unit. `id` is the core id the unit's decks will have (`te-health`; each course's deck for it is then `te-en-health`, `te-bn-health`, …). |
| `words` | The unit's planned size in words: a whole number, **0 or more on a written unit** (a unit whose decks teach no counted word, such as `te-grammar-differences`, gives 0; OPEN-31), **1 or more on a planned theme unit**. On a planned unit it may be given inside `planned` (as in `b1-plans.md`) or beside it, not both. One size for every native language; each course's count is checked against it (10.3). |
| `grammar` | The grammar topics it teaches: a list of topic ids, or one id as a string (`b1-plans.md` writes `grammar: conditional` in `planned`). Inside `planned` or beside it, not both. |
| `milestone` | `"A1"`, `"A2"` or `"B1"`: the unit where that level ends. |
| `listening_passages`, `reading_passages` | The listening and reading passages the unit will have (owner, 2026-10-09). A non-empty list of passages. **Both are required on every planned unit** (OPEN-24, settled: owner, 2026-10-09, "required on every planned unit, as recommended"); a written unit may give them, and need not (its passages are its reading decks). |

**A passage** is named once, in the path, and described in each native
language:

| Field | Notes |
|---|---|
| `id` | `[a-z0-9]+(-[a-z0-9]+)*`, unique in the path across both lists. It names the passage for every native language: when the description is reworded, the id stays, so no other native language's text comes loose. |
| `text` | A mapping from a native language's code to a short description in that language, keyed as a facts file's texts are (`text: { en, bn, hi }`): at least one entry; each value non-empty text, held to Script in prose as written for its key's language (11.3). A native language a course of the language is taught from, with no text here, is warned of (10.3); its learners see the passage without a description. |

So a Bengali course written after the English one adds `"bn":` beside
`"en":` on each passage, in the one path, and nothing else in the path:
its units, sizes and milestones are already there. The planned and
written units, the sizes, the topics and the milestones are the
language's; only the passages' descriptions, and the regions' names, are
per native language, and those are keyed by native code in place.

**A grammar topic** (OPEN-25, settled: owner, 2026-10-09, "one rule, as
recommended; grammar decks not yet turned into rules count by deck") is
the name of what a unit teaches and counts once toward "12 of 30 grammar
topics": `words-rules-sentences.md` §6, "Each rule counts once toward the
plan's grammar topics". A topic id matches `[a-z0-9]+(-[a-z0-9]+)*` and,
on a written unit, names one of:

- **a rule** of a rules deck the unit lists, by the rule id's name:
  topic `ki` is `te-rule-ki` (so a case-endings table with four rules is
  four topics, and the shared skeleton's "of 30" is counted in rules); or
- **a grammar deck** the unit lists, of any kind **but `rules`**,
  single-file or merged, whose core id is `<lang>-grammar-<topic>`: topic
  `be` is `te-grammar-be` (today the single-file `te-en-grammar-be`, a
  grammar table), topic `sentences` is `te-grammar-sentences` (today
  `te-en-grammar-sentences`, a vocab deck of example sentences). A
  grammar deck not yet turned into rules counts as one topic; once it is
  (`words-rules-sentences.md` §7), its topics become its rules, and its
  own name, unless a rule has it, is no topic: `case-endings` does not name
  `te-grammar-case-endings`, whose topics are `lo`, `ki`, `to` and
  `nunci`. So one rule counts once, never again as its deck (10.3 refuses
  it).

On a planned unit the topic is free, and is checked once the unit is
written. 10.3 checks this.

**Why `listening_passages` and `reading_passages`, not `listening` and
`reading`:** `reading` is a word key everywhere in the validator (a
romanisation, checked against the scheme and skipped by Script in prose).
`check_transliterated` must check these descriptions as prose.

**A path has a B1 plan** iff some unit is a mapping with `planned`,
`words`, `grammar` or `milestone`.

**OPEN-20, settled: which paths must have a plan** (owner, 2026-10-09:
"required on a path whose language has a core, as recommended"). The
owner: "Every deck path will have a B1 plan from now on" (`b1-plans.md`
lines 8–9), with a validator error for "a path without its A1, A2 and B1
marks, in that order" (line 277). Requiring it of every path at once
would turn all nine of today's paths red (ground rule 1) until every plan
is written, so: **a path whose language has a core file** (given now or
among the language's files) needs its plan, which makes the plan
required when the language's first deck is split, as `native-layers.md`
ties the split to the plan; a follow-up switches the rule on for every
path once every language has its plan. A path without a plan whose
language has a core gets:
`error: {path}: units: {lang} has core files ({first core}), so its path needs its B1 plan: the milestones A1, A2 and B1, in that order`.

**Up to B1** means every unit before the one marked `B1`, and that one.

**Exempt units** (no size or topic needed, and may stay lists): a unit all
of whose core ids are in `alphabet`, and the unit of `"*"` alone. "Units
with the alphabet ... count neither words nor grammar." **Every other
unit up to B1, in a path with a plan, is a mapping with `words` or
`grammar`**: a list-form unit up to B1 that is not exempt is an error
(10.2). A unit of reading decks only gives `words: 0`.

### 10.2 Per-file errors (path)

`PATH_KEYS` loses `native` and gains `regions`; `check_path_file` reads
the file of 10.1. A path still in the per-course form is refused with a
message that says what to do:

| where | message |
|---|---|
| `native` | `a path is one per language learnt, decks/{lang}/{lang}-path.yaml, shared by every native language (ADR-0036); list core ids, such as {example!r}, and remove native` (`{example}` the first listed id with its native taken out) |
| `id` | `a path of {lang} has id {lang}-path, the filename stem, got {id!r}` |
| `units[{i}]` | `must be a list of core ids, or a mapping with decks or planned` |
| `units[{i}]` | `unknown field {k!r} in a unit` |
| `units[{i}]` | `has decks or planned, not both` / `has neither decks nor planned` |
| `units[{i}].decks` | (today's list-form messages: `must be a non-empty list of core ids`, the wildcard ones, `{id!r} is listed twice`) |
| `units[{i}].decks` / `alphabet` | `{id!r} is not a core id of {lang}: {lang}- and a name, such as {lang}-home` |
| `units[{i}].words` | `must be a whole number of words, 0 or more, got {v!r}` (written unit) / `must be a whole number of words, 1 or more, got {v!r}` (planned theme unit). A bool is refused; under ground rule 8, `1_000` is a string and refused. |
| `units[{i}]` | `words is given both in planned and beside it` (and the same for `grammar`) |
| `units[{i}].grammar` | `must be a grammar topic id or a list of them, such as ["past"], got {v!r}` / `{t!r} is listed twice` |
| `units[{i}].milestone` | `must be "A1", "A2" or "B1", got {v!r}` |
| `units[{i}].planned` | `must be a mapping with id, and theme or grammar` / `unknown field {k!r}` |
| `units[{i}].planned.id` | `must be a core id of {lang}, {lang}- and a name, such as {lang}-health, got {v!r}` |
| `units[{i}].planned` | `names theme or grammar, not both` / `needs a theme or a grammar topic` |
| `units[{i}].planned.theme` | `must be a theme id, got {v!r}` |
| `units[{i}].planned` | `a planned theme unit gives its size in words` |
| `units[{i}]` | `a planned unit names its listening_passages and its reading_passages (b1-plans.md: each planned unit names its listening and reading passages)` (either missing) |
| `units[{i}].listening_passages` | `must be a non-empty list of passages, each { id, text }` (and the same for `reading_passages`) |
| `units[{i}].listening_passages[{j}]` | `unknown field {k!r}` / `id must match [a-z0-9-]+, got {v!r}` / `passage {id!r} is also in units[{k}]` (or earlier in this unit) |
| `units[{i}].listening_passages[{j}].text` | `must be a mapping of a native language's code to the passage's description, such as {{ "en": "..." }}` / `{k!r} is not a language code` / `{k!r} is not text` (and the same for `reading_passages`) |
| `units[{i}]` | `a unit of "*" alone cannot carry a milestone or a plan` |
| `units` | `the B1 plan needs the milestones A1, A2 and B1, each once and in that order; found {found}` (`found` lists them in file order, or `none`) |
| `units[{i}]` | `milestone {m!r} is already on units[{j}]` |
| `units[{i}]` | `a unit up to B1 gives its planned size (words) or its grammar topics (grammar)` (a non-exempt mapping unit up to B1) |
| `units[{i}]` | `a unit up to B1 is a mapping with its words or grammar; only an alphabet unit or "*" alone stays a list` (a non-exempt list unit up to B1) |
| `units[{i}]` | `grammar topic {t!r} is already planned in units[{j}]` (topics up to B1 are counted once) |
| `units[{i}]` | `a planned unit after the B1 mark; a B1 plan ends at B1` |
| `units[{i}].planned.id` | `{id!r} is planned twice, also in units[{j}]` / `{id!r} is planned and also listed as a deck in units[{j}]` |
| `regions` | (10.5) |

All of these, except the first, the id row, the unit-shape rows and the
`decks` rows, are only possible in a path with a B1 plan, so today's
paths, once migrated (10.6), get none.

### 10.3 Across (path)

Errors, each `error: {path}: {where}: {msg}`, reported when the path is
given:

- **A listed core id is a deck of the language:** for each core id in
  `decks` and `alphabet`, a core with that id, or a single-file deck or
  layer `<lang>-<n>-<name>` for some native language `n`, is given now or
  among the language's files (2.8):
  `units[{i}]: lists {id!r}, which is no deck of {lang}: no core {id}, and no deck {lang}-<native>-{name}`.
  A listed id whose name starts with a native language's code (as 2.1
  defines for cores) is a course's deck id, not a core id:
  `units[{i}]: lists {id!r}, a deck of the {lang}-{n} course; a path lists core ids, here {core!r}`.
- **Every deck of the language is on the path once:** each single-file
  deck and each layer of the language (every course), given now, has its
  core id in exactly one unit:
  `units: does not list {core!r}, the core id of {deck}; every deck of {lang} is on its path`.
  A core is on the path through its id; a core no layer names is 10.4's
  warning.
- **A unit ending in `"*"` needs a theme deck,** to say which added decks
  it takes: some core id of the unit has, in some course, a deck with a
  theme (or a core with a `theme`), when the unit's decks are given now or
  among the language's files.
- **A planned deck must not exist yet:**
  `units[{i}].planned.id: {id} already exists ({file}); list it under decks in place of planned`.
  It exists if a core with that id, or a single-file deck or layer
  `<lang>-<n>-<name>` for any native language `n`, is given now or on
  disk in the path's directory or one level below it. A planned core id
  whose name starts with a native code gets the second message of the
  first bullet, with `units[{i}].planned.id` as where.
  (`b1-plans.md`: "When a planned deck's file appears ... its planned entry
  is turned into decks in the same change.") A unit is written once any
  native language has its deck; the courses still without one see it as
  "Coming" (9.5).
- **Grammar topics resolve** (OPEN-25, settled): each topic of a written
  unit names a rule or a grammar deck of that unit, as 10.1 says:
  `units[{i}].grammar: {t!r} is taught by none of the unit's decks; name a rule ({lang}-rule-{t}) of a rules deck it lists, or a deck {lang}-grammar-{t} it lists`.
  The rules are read from the rules cores the unit lists, given now or
  among the language's files; when a listed core id is neither a rules
  core nor `<lang>-grammar-<t>`, and has no deck to look at, the topic is
  not checked. A topic that is the name of a rules core the unit lists,
  and no rule's name, is refused in place of that message, since the
  deck's rules are its topics (a one-rule table whose rule shares the
  deck's name, `te-rule-past` in `te-grammar-past`, names the rule and
  counts once):
  `units[{i}].grammar: {t!r} names the rules deck {core!r}; its topics are its rules, {rules}`
  (`rules` the rule names in the order the core lists them, such as `"lo", "ki", "to", "nunci"`).
- **The plan is required** where OPEN-20 says (the message is in 10.1).
- **Bases in a script without spaces** (8.3), per course.
- **The phrasebook's size and place** (3), per course.
- **A path for the language already:** a second path file of the language
  (a per-course file left beside the new one, say), given or on disk:
  `root: {lang} already has a path, {other}; a language has one`.

Warnings and the info line, attached to the path's own report
(`rep.warn`, `rep.info`):

- **A B1 deck still single-file** (OPEN-30; `native-layers.md` lines 4–5:
  "decks are split as their B1 plans are written"): for each course's B1
  deck that is a single-file deck,
  `units[{i}]: {deck} is a single-file deck; a deck in a B1 plan is split into a core and its layers as the plan is written`.
  The B1 checks apply to it either way (2.8).
- **More words than planned,** per course: for each written unit with
  `words`, and each course whose decks for the unit's core ids are all
  given or among the language's files, when the course's count (8.5)
  exceeds it:
  `units[{i}]: has {n} words for learners from {native name}, more than the {words} planned; raise words`.
- **A passage without a description in a course's language:** for each
  native language `n` that a deck or layer of the language is taught
  from, each passage whose `text` has no `n`:
  `units[{i}].{list}[{j}]: no description in {native name}, so learners from {native name} see none`.
  One line per passage and language, so a new course sees what it has
  left to write.
- **The total:** planned words up to B1 (`words` of every unit up to B1)
  outside 2,000–3,500:
  `units: plans {n} words up to B1, outside 2,000–3,500; check the sizes`.
- **A planned theme not yet a theme:**
  `units[{i}].planned.theme: {t!r} is not in decks/themes.yaml; add it before the deck is written`
  (only when the themes file is given).
- **Level sizes** (owner, 2026-10-09: A1 700, A2 900 more, B1 1,200 more;
  low confidence). OPEN-21, recommended: one **info** line per plan,
  `units: B1 plan: A1 {a} words (about 700), A2 +{b} (about 900), B1 +{c} (about 1,200); {total} in all; {g} grammar topics; {p} units planned`,
  and a **warning** only for a level outside half to one and a half times
  its size: `units: A2 plans {b} words, far from about 900 (450–1,350)`.
  Here `a` is the words of units up to and including A1's, `b` those after
  A1 up to A2's, `c` those after A2 up to B1's: the planned sizes, which
  are the language's, not a course's count.

### 10.4 Paths, decks and layers together

**How a course reads its language's path.** For the course `(lang, n)`,
each listed core id `<lang>-<name>` stands for the deck `<lang>-<n>-<name>`
(2.1). The validator's across checks and the app's `forNative` (9.5)
read it the same way:

- a core id with a deck in the course is that deck, in its unit;
- a core id without one is skipped for the course; a written unit left
  with no deck is, for that course, as a planned unit is: skipped by
  lessons, shown as "Coming" (which course a learner is given, so that a
  second native language's first layers do not empty their course, is
  the learner's own choice, asked with each course's coverage: 9.5, OPEN-35);
- `alphabet` maps the same way; `"*"` takes the course's decks the path
  does not list, as today.

`check_paths_across` keeps its rules with this reading: a layer's or a
single-file deck's place on the path is its core id's unit; a core is on
no path by itself; the course of "lists X, which is not a deck" is
replaced by 10.3's first two bullets. `check_reading_across` finds a
reading deck's unit and its theme deck's unit through their core ids, in
the course's reading of the path. The B1 checks of 2.8 run per course
over the course's decks.

Two lookups change:

- **"has no path":** for any deck of the language, single-file or layer,
  the path is `decks/<lang>/<lang>-path.yaml`: beside a single-file deck,
  in the folder above a layer (`rep.path.parent.parent` for a layer). The
  message becomes
  `{deck}: {lang} has no path; add {lang}-path.yaml in decks/{lang}/`.
- **A core no layer names** is a warning attached to the core's report,
  `rep.warn("root", "no layer names this core, so no learner is taught it")`,
  looking for layers among the files given now **and** the language's files
  (2.8), so a core validated alone does not get it while its layers are on
  disk.

`check_themes_across` gets each layer's `theme_key` from 2.8's table.

### 10.5 Regions

The owner, 2026-10-09, on the offensive-word rating screen, which asks
"Where you speak Telugu" with Telangana, Coastal Andhra, Rayalaseema and
Elsewhere (`docs/mockups/reviewer-mode.html` on #432): "where will this be
defined? in the decks? that needs an update to the deck plan". Defined
here: **a language's regions are listed in its path**, since they are the
language's and every native language shares them, as the path is shared.

```yaml
regions:
  - id: "telangana"
    name: { "en": "Telangana" }
  - id: "coastal-andhra"
    name: { "en": "Coastal Andhra" }
  - id: "rayalaseema"
    name: { "en": "Rayalaseema" }
```

| Field | Notes |
|---|---|
| `id` | A **region id**: `[a-z][a-z0-9]*(-[a-z0-9]+)*`, as a note id (it starts with a letter, and is not one of YAML 1.1's boolean words); unique in the path; not `elsewhere`, which the app keeps for its own answer. **Permanent, as a card id:** a rater's answers and the cards' region notes name it. Rename a region's `name`, never its `id`; retire one only when nothing names it. |
| `name` | The region's name in each native language, keyed by language code as a facts text is: `en` required (the interface's base locale), any other beside it. The app shows the name in the learner's (or rater's) language where given, else the English one. Script in prose applies per key, as for a facts text: a Telugu name under `"en"` gives its reading, తెలంగాణ (telaṅgāṇa). |

The list is in the order the app shows it. **The app adds "Elsewhere"**
after the language's regions, an interface string (a token in
`lib/l10n/app_en.arb`, AGENTS.md rule 10), never deck data; it is stored
as `elsewhere`. A language with no `regions` shows no region question.

**Where regions are used:**

- **The rater's region, in reviewer mode** (`docs/plans/offensive-words.md`
  on #432: "several native speakers, from more than one region where
  possible, rate each word", and "a disagreement of a band or more
  becomes a region note"): "Where you speak {language}" offers the
  language's regions, then Elsewhere; the answer is kept with the
  rater's ratings by region id. How ratings are stored is the reviewer
  mode's, not this format's.
- **A card's region note** (6.1, 6.2): a note with `region:` naming one
  or more region ids. On an offensive card, where raters from different
  regions differ ("Region: No note yet" on the mockup's card); and, as
  decks are rewritten, on regional vocabulary, such as the Telangana
  words `te-facts` and `te-en-groceries` mention today (చాయ్ (cāy), tea;
  ఉల్లిగడ్డ (ulligaḍḍa), onion). The offensive card's other fields (its
  level, type, "can be friendly among peers") are specified with the
  offensive-words format, not here.

**Validator, per file (path):**

| where | message |
|---|---|
| `regions` | `must be a non-empty list of regions, each { id, name }` |
| `regions[{i}]` | `must be a mapping` / `unknown field {k!r}` |
| `regions[{i}].id` | `must start with a letter and match [a-z0-9-]+, and not be a YAML 1.1 boolean word, got {v!r}` / `{id!r} is used twice` / `elsewhere is the app's own answer; give the region another id` |
| `regions[{i}].name` | `must be a mapping of a language code to the region's name, with "en"` / `has no "en"` / `{k!r} is not a language code` / `{k!r} is not text` |

**Validator, across:** every region a note names is a region of its
language's path, given now or among the language's files:
`error: {file}: card {id}: notes[{i}].region names {r!r}, which is not a region of {lang}; its path lists {known}` (`{known}`
the ids, or `none` when the path has no `regions`), with `cards.{id}` as
where on a layer. A language whose path is neither given nor on disk is
not checked (it gets "has no path" instead).

**Dart:** `Region` and `LanguagePath.regions` (9.5); `CardNote.regions`
(6.6). The parser checks the shape only; whether a note's region exists
is the validator's.

**The regions, for the two languages being written now.** Recommended
lists, for the deck agents to write with each path (OPEN-32; the owner
or the first raters may change them, before any rating names a region):

- **Telugu:** `telangana` (Telangana), `coastal-andhra` (Coastal Andhra),
  `rayalaseema` (Rayalaseema), as on the owner's rating screen. Sources:
  these are the three regions Telugu's dialects are usually grouped by:
  Telangana is a state since 2014, and Coastal Andhra and Rayalaseema
  are the two traditional regions of Andhra Pradesh; `te-facts` already
  says "Telangana and coastal Andhra use some different everyday words".
  Krishnamurti and Gwynn's *A Grammar of Modern Telugu* (1985) divides
  the dialects into four areas, splitting the north-east coast
  (Srikakulam, Vizianagaram, Visakhapatnam, "Uttarandhra") from the
  central coast; I am not certain of that division's details, so it is
  offered only as the place to split Coastal Andhra if its raters differ.
- **Bengali, by dialect group** (owner, 2026-10-09: "By dialect group",
  over the political list): `rarhi` (Rāṛhī, west-central: Kolkata,
  Nadia, Bardhaman; the standard's base), `vangiya` (Vaṅgīya, east:
  Dhaka, Mymensingh, Barishal), `varendri` (Varendrī, north-central:
  Rajshahi, Malda, Dinajpur), `kamrupi` (Kāmarūpī or Rangpuri, north:
  Rangpur, Cooch Behar, Jalpaiguri), `manbhumi` (Mānbhūmī, west: Purulia,
  Bankura, Bengali-speaking Jharkhand) and `south-eastern` (Chittagong,
  Noakhali, Sylhet, Tripura, Assam's Barak Valley). The groups follow
  Chatterji, *The Origin and Development of the Bengali Language*
  (1926), and its successors; each name carries example districts so a
  rater who does not know the dialect terms can still place themselves.
  Low confidence on the districts at each group's edges, and on whether
  Sylheti and Chittagonian, often counted as languages of their own,
  belong in one south-eastern group: a native reviewer checks this list
  before any rating names a region.

### 10.6 Moving today's paths

Today's nine course paths (`as`, `bn`, `es`, `gu`, `hi`, `ja`, `kn`, `mr`,
`te`; each `decks/<lang>/<lang>-en-path.yaml`) move in the same commit as
V's and D's path change, since each refuses the other form. For each
language:

1. Write `decks/<lang>/<lang>-path.yaml`: `id: "<lang>-path"`, `language`
   as before, **no `native`**, `description` and the comments kept (their
   "taught from English" wording made general where it says so).
2. In `alphabet` and every unit, replace each deck id with its core id:
   take out the native, `<lang>-en-<name>` → `<lang>-<name>`
   (`te-en-home` → `te-home`, `te-en-reading-diddubatu` →
   `te-reading-diddubatu`); `"*"` stays. Every id in today's nine paths is
   `<lang>-en-…`, and no name collides with a reserved core id (2.1), so
   the change is one text substitution per file, checked by the
   validator.
3. Delete `decks/<lang>/<lang>-en-path.yaml` (10.3 refuses two paths).

Nothing else moves: no deck, card id, deck id, pubspec line, review row or
setting changes. The tests that write per-course paths (V's
`tools/test_validate_paths.py` and the B1 tests; D's
`test/course_path_test.dart`, `test/b1_format_test.dart` and the
catalog's tests; the `zz` fixtures' `zz-en-path.yaml`, which becomes
`zz-path.yaml`) move with it, and ground rule 1's comparison is made on
the migrated tree. The B1 plans the deck agents write go straight into
`te-path.yaml` and `bn-path.yaml`, with core ids.

---

## 11. Script in prose for the new fields

`check_transliterated` already walks every string. Changes:

1. **In a core or a layer, the language of every string is fixed for the
   whole file, never taken from a key.** In a layer every prose string is
   read as written for the layer's native language (`native.code`); in a
   core every string is the language learnt's (`language.code`). Keys such
   as the slot `"lo"` or `"to"` match `LANG_RE` and would otherwise be
   mistaken for language codes (`lo` is Lao). So a Bengali layer's own
   Bengali words need no reading, and a Telugu word in it does
   (`native-layers.md`: "A reading in the reader's own script also
   counts").
2. **`_WORD_KEYS` gains** `word`, `base`, `ref`, `core`, `except`,
   `rules`, `part`, `region`, and in a core `slots` (core slot keys and
   grammar slot labels are the language's words). `wiktionary` is a boolean and needs
   nothing.
3. **Checked as prose, as before or newly:** a layer's `name`,
   `description`, `native`, `alt_native`, note texts, example
   translations, base meanings, `table.slot_name`, slot labels, `prompts`,
   rule `name` and `explanation`, grammar `name`, `slot_name`, `prompt`,
   `entries` glosses, `notes`; a single-file card's note `text` and base
   `meaning`; a path's passages' `text` and regions' `name`, each value
   read as written for the language its key names, as a facts file's
   texts are (a passage's `id` is a word key, not prose).
4. **Placeholders** are checked unsubstituted (6.4).
5. **Readings** in `notes[].words`, `rules[].words`, `bases` and rule rows
   are romanisations: `_readings_in` already collects every `reading` and
   `readings` key, so `check_romanised` holds them to the scheme, on a
   layer with the core's language and the core's directory (2.6).

---

## 12. Backward compatibility

| Today | Stays valid because |
|---|---|
| Every single-file deck | No new required field; `part` absent means single-file; new card fields are optional; `HEADER_KEYS` is unchanged. |
| `notes: "..."` | A string is still accepted, read as one `note`; a blank string as none. |
| Course paths, `<lang>-<native>-path.yaml` | **Not valid any more** (OPEN-4, settled): all nine are moved to `<lang>-path.yaml` with core ids in the same commit (10.6), mechanically; nothing they decide (units, order, wildcards, alphabet) changes. |
| Path units as lists | Still a unit, of core ids; a path without a mapping unit has no B1 plan, and gets no new message while its language has no core (OPEN-20, settled). |
| `kind: grammar` decks | Unchanged; cells keep `{grammar}` and their ids. |
| `modes:` values | `grammar` keeps its meaning, the form produced; `grammarUnderstood` (a form's meaning chosen) is new and only for rule cells. |
| `pair:` | Still valid on single-file decks, and still Hear's sound-alike; a typed pair note only adds to it. |
| `reviews`, `card_states`, `leech_actions` | No migration: `textEnum` stores names; no row changes. |
| Card ids, deck ids | Unchanged. A split deck keeps its id as the layer's. Path ids change (`te-en-path` → `te-path`), and are stored nowhere (ground rule 3). |
| Placement, added decks, the catalog's course keys | Unchanged: they hold merged deck ids and `lang/native`, and each course's `CoursePath` is built from the language's path (9.5). |
| `--next-id` | Also sees cores and layer-only cards; no existing number changes. |
| `pos` values | `pronoun` is added; no value is removed. |
| Plain YAML scalars | YAML 1.2 resolution (ground rule 8), in the validator and the app alike, changes only `yes`/`no`/`on`/`off`, leading-zero, underscore, binary and sexagesimal numbers, none of which today's decks hold. |
| A null reading or IPA under a null form | Read as none, by both (4.2). |
| The new B1 checks | Bases coverage, the notes warning, the pair warning, the phrasebook's size and place, and rows run on B1 decks only (2.8), and no path has a plan today; the culture tag only where a culture note exists; the partner check only on typed pair notes. |
| Validator output | No info line on today's decks (no layers, no plans, no regions). |

Both V and D add a test that walks today's `decks/` (V: run the validator
and compare its output with `main`'s; D: the existing test that parses every
bundled deck stays green).

---

## 13. Tests each builder adds

**Fixtures.** Use a language with **no decks in the repository**:
`code: "zz"`, `iso639_3: "zzz"`, `name: "Testlang"`, `script: "telugu"`.
The validator resolves refs and counts rows against the repository's own
decks of the language (`_repo_card_defs`, 2.8), so a fixture in `te` would
pull in every Telugu card. Appendix A is a valid set; write it with `te`
replaced by `zz`, **in this tree**, since the validator finds a layer's core
in the layer's grandparent directory, requires a core's directory to be
named for its language and a layer's for its native, and reads the
language's files from the given files' directories (2.8):

```
tmp_path/
  zz/
    zz-home.yaml
    zz-grammar-case-endings.yaml
    zz-path.yaml
    en/
      zz-en-home.yaml
      zz-en-grammar-case-endings.yaml
```

Each test then breaks one thing. A test that validates one file alone
(say `zz/en/zz-en-home.yaml`) still has the rest of the tree on disk as
context, as the repository does. (The existing tests write fixtures flat
into one directory; that still works for single-file decks.)

- **V:** each error, warning and info in sections 2–10 at least once,
  with its exact message and where; ground rule 8's table, one parity case
  per row in `tools/test_validate_deck_parity.py`; non-string keys; the
  dispatch order of 2.2 (a file with both `part: "core"` and
  `kind: "layer"` is a layer with a `part` error; a core with
  `kind: "reading"` gets the one `kind` message); the merge-based checks
  (layer coverage, a single-file ref to a core card resolved through a
  same-native layer, the ref native check against `natives`); the
  phrasebook count per course (14, 15, 25, 26; 0 unchecked without a plan,
  an error with one; a Bengali layer's phrasebook cards not counted for
  English) and its place; rows (a new noun in a B1 deck without a row
  fails; with `except` passes; a noun in a deck on no plan needs none);
  bases coverage per course (a word taught only from another native fails);
  the per-language path (10.2–10.4): a per-course path refused with its
  message, a listed id that is a course's deck id, a core id with no deck
  in any course, a deck of a second native language on the same path
  through its core id, a deck of the language the path leaves out, a
  planned core id that exists as a core, as a layer of another course, or
  as a single-file deck (each an error), passages with ids and texts and
  the missing-description warning for a second course, words counted per
  course; grammar topics resolving to a rule and to a grammar deck by core
  id, and a topic naming a rules deck refused; milestone order; the plan required once the language has a core;
  regions (each per-file message; a note naming a region the path lists,
  one it does not, and one in a language whose path has no `regions`);
  the romanisation check on a layer reading the core's directory; "has no
  path" for a layer validated alone (none, with the path on disk); the
  culture tag; the partner check; byte-identical output on today's
  `decks/` once its paths are moved (10.6); **`--next-id` seeing a core's
  card and a layer-only card**, and a core card duplicated in a
  single-file deck caught.
- **D:** `parseCore`, `parseLayer`, `mergeLayer` (fields from each side,
  skipped cards, layer-only cards appended, a core ref with and without a
  layer `native`, ref positions, notes and examples left out without layer
  text, `pair` from the first pair note, tags dropping `reviewed`, license
  expression); `parse()`'s refusals (9.2); typed notes, the legacy string
  and the blank string; placeholders, `{0}` and `{01}` refused; `bases`;
  `phrasebook`; `wiktionary` as a bool on cards, refs (resolved) and bases;
  a note's `region`, a string or a list;
  `expandRules` (ids with and without `key`, prompts and overrides,
  `{meaning}` as the first part, options distinct, from the same row, never
  from a rule the layer leaves out, rows without a card skipped, cells of
  an omitted rule skipped); `promptFor` on a rule cell for both modes (the
  form for `grammarUnderstood`, the word and the meaning for `grammar`);
  `DrillMode.grammarUnderstood` refused in `modes`; `countsAsWord`;
  `parseLanguagePath` with mapping and planned units, core ids, `words: 0`,
  passages with ids and texts required on planned units, regions, and the
  per-course form refused; `forNative`: core ids to the course's deck ids,
  a unit with no deck in the native language left out of `units` and
  `open` and marked coming, `plan` in order, the same `hasB1Plan`,
  `grammarTopics` and `plannedWords` for every native language;
  `courseUnits` choosing the native language by coverage (9.5): a
  Bengali-first learner is taught from English while the Bengali course
  has one layer, and from Bengali once it has a deck in as many written
  units; the
  catalog building each course's path from the language's; every bundled
  deck still parsing; plain scalars typed as ground rule 8's table, one
  case per row, and a null reading or IPA under a null form read as none
  (both done: `test/deck_parser_test.dart`, "the YAML traps"); the parity
  cases the parser refuses (V owns `tools/test_validate_deck_parity.py`;
  D lists the cases in the pull request).
- **Q:** the tests listed in 4.8.
- **W:** none; the docs' YAML examples are copied from Appendix A and this
  spec, and W runs the validator on them (as `zz` fixtures, in the tree
  above).

---

## 14. ADR-0036 (next free number; 0028 was never used and stays a gap)

File: `docs/adr/0036-b1-deck-format.md`. The owner has answered every
group B item (2026-10-09; see "Open for the owner"), so W writes it as
follows, with `Status: Accepted`, replacing the version on the branch,
which was written `Proposed` from the first recommendations (paths per
course; choosing the form as understood).

```markdown
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
(`docs/plans/skill-model.md`, 2026-10-09). On 2026-10-09 the owner
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
that scripts without spaces wait. The rating screen for offensive words
asks where the rater speaks the language, which needed the language's
regions defined.

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
- **B1 checks on cores only:** a deck could escape them by staying
  single-file.
- **A stored Wiktionary title:** the plan builds the link from the word.
```

---

## 15. `docs/DECK-FORMAT.md`: the sections W adds or changes

In document order. "New" sections are written from this spec's sections
named; "Change" edits an existing passage without rewriting the rest
(AGENTS.md rule 8). Every YAML example quotes its keys (ground rule 4).

1. **Change: the opening paragraph** — four kinds become five (`rules`),
   and "a deck is a single UTF-8 YAML file" gains "or a core and its
   layers (see Core and layer files)".
2. **Change: "Script in prose: always with its reading"** — add the new
   prose fields (11.3), that a layer's prose is read as written for its
   native language (11.1), and that `{1}` placeholders are checked before
   they are filled.
3. **Change: "Header"** — the `kind` row adds `rules` and `layer`; new rows
   `part` and `core`; the `id` row adds the core and layer id forms; the
   `tags` row adds `reviewed` (6.5).
4. **New: "## Core and layer files"**, after "Header": 2.1–2.7 (files and
   ids, the core header, core cards, the grammar core, the layer and its
   entries, layer-only cards, the merge, coverage), and "Splitting a deck"
   (ids kept, the old file deleted in the same change, the pubspec line).
5. **New: "### YAML values"** under Header: ground rule 8's table, and
   that keys are quoted.
6. **Change: "### Card fields"** — rows for `phrasebook`, `bases`,
   `rules`, `wiktionary`; the `notes` row becomes "text, or a list of typed
   notes (see Notes)"; the `examples` row adds `bases`; the `pos` row adds
   `pronoun`; the `pair` row says a pair note also gives it; a line on
   which fields a core card has and which its layer gives.
7. **Change: "### A word in more than one deck: `ref`"** — a ref may give
   `wiktionary`; it cannot give `phrasebook`, `bases` or `rules`; a ref to
   a core card resolves through the same-native layer.
8. **New: "### The phrasebook"** (section 3), under Vocab decks.
9. **New: "### Base words: `bases`"** (section 8).
10. **New: "### Notes"** (section 6: kinds table, single-file, core and
    layer forms, placeholders, what is warned of, the partner rule, the
    culture tag).
11. **New: "### The Wiktionary link"** (section 7).
12. **New: "### Sentences and their rules: `rules`"** (section 5).
13. **Change: "## Grammar decks"** — a closing paragraph: a grammar deck may
    be a core and layers (2.5), and keeps its cell ids when split.
14. **New: "## Rules decks"**, after Grammar decks: section 4 (the table,
    rows, rules, coverage, the layer, expansion and cell ids, what each
    question shows, the two schedules).
15. **Change: "## Course paths"**, renamed "## Paths": one per language
    learnt, `<lang>-path.yaml`, listing core ids (2.1, 10.1, 10.4); how a
    course reads it; the `units` row: "a list of core ids, or a mapping
    (see The B1 plan)"; "every deck of the language", every course's,
    single-file or layer, is on it once; the move from course paths
    (10.6).
16. **New: "### The B1 plan"**, under Paths: section 10 (shape, passages
    and their descriptions per native language, grammar topics, exempt
    units, which paths need one, B1 decks, errors, warnings, info, how
    words are counted per course, 8.5).
17. **New: "### Regions"**, under Paths: section 10.5, and the region
    note in "Notes".
18. **Change: "## Drill modes"** — a row for `grammarUnderstood` (prompt:
    a form of a rules table, with its reading; answer: its meaning,
    chosen among the meanings of the same word's forms; automatically);
    the `grammar` row says "the form, chosen among the same word's forms
    or typed, with the word and the meaning given: grammar produced".
19. **Change: "## Adding your own deck"** — one line: an added deck is
    single-file; cores, layers and rules decks are for the repository.

Also: `decks/README.md` (the tree gains a core and a `te/en/` layer
folder, and the pubspec line per layer folder); `assets/deck-template.yaml`
(comments only, showing a typed note and a base; its cards unchanged);
`AGENTS.md`'s repo map row for `decks/<lang>/` ("one YAML file per deck,
or a core and its layers", and the path is the language's);
`CONTRIBUTING.md`'s "Write it" step 4 (a deck's core id goes in its
language's path, `decks/<lang>/<lang>-path.yaml`, in the unit it is taught
with; a new course of a language that has a path adds no path, and a new
language adds `<lang>-path.yaml`; "Course paths" becomes "Paths");
ADR-0013's
reader is pointed to ADR-0036 by the latter's `Amends` line (an accepted
ADR's reasoning is not edited). `docs/ROADMAP.md` is not W's to edit
(contention file).

---
## Appendix A. A valid set (Telugu; for fixtures, replace `te` with `zz`)

Five files, in the tree of section 13. With `te` → `zz`, `tel` → `zzz` and
`Telugu` → `Testlang`, they validate together with **no errors**: the
layers and the rules layer give their coverage infos, and the path gives
level warnings and its info line, as its sizes are small. `te-9xxx` ids
are made up. The path has a B1 plan, so both layers are B1 decks and every
B1 check of 2.8 applies to them: this set passes them all.

`decks/te/te-home.yaml`:

```yaml
schema: 1
id: "te-home"
part: "core"
kind: "vocab"
language: { code: "te", iso639_3: "tel", name: "Telugu", script: "telugu", tts: "te-IN", icon: "తె" }
license: "CC0-1.0"
tags: ["unreviewed"]
cards:
  - id: "te-9001"
    target: "ఇల్లు"
    reading: "illu"
    pos: "noun"
    notes:
      - { id: "stem", kind: "behaviour", words: [{ word: "ఇంటి-", reading: "iṇṭi-" }] }
  - id: "te-9004"
    target: "అమ్మ"
    reading: "amma"
    pos: "noun"
    notes:
      - { id: "address", kind: "usage" }
  - id: "te-9006"
    target: "నేను"
    reading: "nēnu"
    pos: "pronoun"
    notes:
      - { id: "drop", kind: "note" }
  - id: "te-9003"
    target: "వెళ్ళు"
    reading: "veḷḷu"
    pos: "verb"
    notes:
      - { id: "future", kind: "behaviour", words: [{ word: "వెళ్తాను", reading: "veḷtānu" }] }
  - id: "te-9002"
    target: "నేను ఇంటికి వెళ్తాను."
    reading: "nēnu iṇṭiki veḷtānu."
    pos: "phrase"
    rules: ["te-rule-ki"]
    bases:
      - { word: "ఇంటికి", ref: "te-9001" }
      - { word: "వెళ్తాను", ref: "te-9003" }
  # Fifteen phrasebook cards, te-9101 to te-9115, for k = 1 to 15. The
  # fixture helper writes them; every one's word, అమ్మ (amma), is the
  # target of te-9004, so they need no bases (the digit is not a word).
  - id: "te-91{k:02d}"
    target: "అమ్మ {k}!"
    reading: "amma {k}!"
    pos: "phrase"
    phrasebook: true
```

`decks/te/en/te-en-home.yaml`:

```yaml
schema: 1
id: "te-en-home"
kind: "layer"
core: "te-home"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Home"
license: "CC0-1.0"
cards:
  "te-9001":
    native: "home; house"
    wiktionary: true
    notes:
      "stem": "Before an ending it becomes {1}, as in ఇంట్లో (iṇṭlō), at home."
  "te-9004":
    native: "mother"
    notes:
      "address": "Also how you address an older woman politely."
  "te-9006":
    native: "I"
    notes:
      "drop": "Often left out: the verb's ending already says who."
  "te-9003":
    native: "to go"
    notes:
      "future": "I will go is {1}."
  "te-9002":
    native: "I will go home."
  # And, for k = 1 to 15, written by the fixture helper:
  "te-91{k:02d}":
    native: "Mother {k}!"
```

`decks/te/te-grammar-case-endings.yaml` and
`decks/te/en/te-en-grammar-case-endings.yaml`: exactly as in 4.2 and 4.5,
except that `applies_to` is `{ pos: ["noun"] }` (no `except`), so the rows
are `te-9001` and `te-9004`, the two nouns of the B1 decks, and the layer's
`prompts` name only `"te-9001"`.

`decks/te/te-path.yaml`:

```yaml
schema: 1
kind: "path"
id: "te-path"
language: "te"
regions:
  - { id: "telangana", name: { "en": "Telangana" } }
  - { id: "coastal-andhra", name: { "en": "Coastal Andhra" } }
  - { id: "rayalaseema", name: { "en": "Rayalaseema" } }
units:
  - decks: ["te-home"]
    words: 4
    milestone: "A1"
  - decks: ["te-grammar-case-endings"]
    grammar: ["lo", "ki", "to", "nunci"]
    milestone: "A2"
  - planned: { id: "te-health", theme: "health", words: 60 }
    listening_passages:
      - { id: "doctor-call", text: { "en": "Booking a doctor's appointment by phone" } }
    reading_passages:
      - { id: "clinic-notice", text: { "en": "A notice at the clinic" } }
    milestone: "B1"
```

What each B1 check sees, for the one course, `te` from `en`: the path
lists the core ids `te-home` and `te-grammar-case-endings`, whose English
decks are the merged `te-en-home` and `te-en-grammar-case-endings`; every
deck of the language is on the path; the planned `te-health` has no core
and no deck in any course; both passages have an English description.
`te-en-home` counts 4 words (ఇల్లు, అమ్మ, నేను,
వెళ్ళు; the sentence and the phrasebook cards are not words), as planned;
the course has 15 phrasebook cards, all in the first unit; every word card
has a note with text; every word of every text is a word card's target or
a base; both nouns have a row, and both rows' words have readings; the
four grammar topics are the rules `te-rule-lo`, `-ki`, `-to` and `-nunci`
of a deck the unit lists. No unit ends in `"*"`, so the theme-deck rule for
wildcards does not apply; `te-home` has no `theme`, so no themes file is
needed.

---

## Open for the owner

Every OPEN item in this spec, with the section it changes. Builders build
each answer or recommendation as written.

### Group B: answered by the owner, 2026-10-09

Each departed from a plan line, or was a choice the owner made that this
spec could not settle alone. **All are answered;** none is open, and
ADR-0036 is written `Accepted` (section 14). The body says what each
answer decided, at the section named, marked *settled*.

| # | Question | The owner's answer | What the spec now says | Section |
|---|---|---|---|---|
| 4 | Paths per language now, or per course until a second native language? | "One per language learnt now (`<lang>-path.yaml`), shared by every layer" (not the recommendation, which was per course for now) | Every deck has a core id; one path per language lists core ids; each course reads it through its own decks, a unit with none being "Coming"; passages are named once with a description per native language; today's nine paths move once, mechanically | 2.1, 2.8, 9.5, 9.6, 10 |
| 16 | Should `pair:` be derived from the pair notes, or stay independent? | "Derived from the pair notes, as recommended" | No `pair:` in a core; `Card.pair` is `pair:` or else the first pair note's partner | 2.3, 2.7, 6.5, 9.4 |
| 20 | Which paths must have a B1 plan now? | "Required on a path whose language has a core, as recommended" | (b): a path whose language has a core; every path by a follow-up once all have plans | 10.1 |
| 22 | Which question is "understood"? | "Choosing the meaning = understood" (reading B, not the recommendation): shown a form, choose what it means; choosing among the same word's forms, or typing the form, is produced | `grammarUnderstood` asks `Ask.chooseFormMeaning`; `grammar` asks `Ask.chooseForm` or the typed form; neither implies the other in the `SkillMap`; both fitted per language and skill | 4.1, 4.6, 4.7, 4.8 |
| 23 | Grammar understood and produced on this branch? | Settled earlier: with the B1 format, after the skill model's pull request (`skill-model.md` 286–291) | Builder Q, after #432 merges | 0, 4.7, 4.8 |
| 24 | Passages: required on every planned unit, as an error? | "Required on every planned unit, as recommended" | An error on every planned unit, both lists non-empty; not required on written units | 10.1, 10.2 |
| 25 | What is a grammar topic? | "One rule, as recommended; grammar decks not yet turned into rules count by deck" | A rule by its name, or a grammar deck by its core id's name | 10.1, 10.3 |
| 26 | Scripts without spaces | "Later, as recommended" | A B1 deck in such a script is an error until a `words` field is designed with that language | 8.3 |

### Group A: gaps the plans leave; builders proceed

| # | Question | Recommended | Section |
|---|---|---|---|
| 1 | Schema version | Stay `1`: every addition is optional, and decks ship with the app | 0 |
| 2 | Rules decks single-file too? | No: core and layers only | 4.1, 2.2 |
| 3 | How a core is marked | `part: "core"`; a layer is `kind: "layer"`; dispatch in that order | 2.1, 2.2 |
| 5 | Reading decks split? | No: already keyed by language | 2.1 |
| 6 | Where layer-only cards go | After the core's cards, in the layer's order | 2.7 |
| 7 | When a phrasebook is required | When the language's path has a B1 plan; counted per course | 3 |
| 8 | What one rule is | One or more columns of one table; options across the table's row | 4.1 |
| 9 | Missing row: error or warning | Error, with `applies_to.except`, over the B1 decks' words | 4.3 |
| 10 | Name of the new mode | `grammarUnderstood`; `grammar` stays as produced | 4.7 |
| 11 | What a grammar answer implies in the `SkillMap` | Nothing, either way, and no word skill: the research finds grammar practice skill-specific (DeKeyser 1997; Shintani et al. 2013) and gives no figure for form and meaning; the typed and the chosen form are one schedule now | 4.7 |
| 12 | `grammarUnderstood` on existing grammar tables | Later, for tables whose rows give two forms or more | 4.7 |
| 13 | Culture `source` | In the core, shared | 6.2 |
| 14 | Language facts in notes | `words` in the core, `{1}` placeholders in the layer | 6.4 |
| 15 | B1 checks on decks on no B1 plan | None, as `b1-plans.md` scopes them | 2.8, 8.3 |
| 17 | Where the Wiktionary mark lives; a stored title | With the native language; `true` only, no stored title (the plan builds the link). The owner may ask for a title override later | 7 |
| 18 | What counts as a word | 8.5's `counts_as_word` | 8.5 |
| 19 | Imported decks | Single-file only | 9.6 |
| 21 | Level sizes | Info always; warning outside 50–150% of each level | 10.3 |
| 27 | The layer's file name | `<lang>-<native>-<name>.yaml` in `decks/<lang>/<native>/`, so its stem is the merged deck's id and every id-keyed thing keeps working | 2.1 |
| 28 | Pronouns | Add `pos: "pronoun"` (validator only), so pronoun tables can select by `pos`. **Flagged:** a new part of speech | 4.2, 8.5 |
| 29 | Marking a culture deck checked | The tag `reviewed`, exclusive with `unreviewed`, in the file that holds the claim (core, or the layer for a layer-only card). **Flagged:** a new tag | 6.5, 2.7 |
| 30 | A B1 deck still single-file | A warning on the path; the B1 checks apply either way | 10.3 |
| 31 | A unit with no counted words | `words: 0` on a written unit; only alphabet units and `"*"` stay lists | 10.1 |
| 32 | The regions of Telugu and Bengali | Telugu: Telangana, Coastal Andhra, Rayalaseema (the owner's rating screen). Bengali: by dialect group (owner, 2026-10-09), six groups with example districts, checked by a native reviewer before any rating names a region | 10.5 |
| 33 | Where a passage's description per native language lives | In the path, under the passage's `text`, keyed by native code, with a passage `id`; not a path layer of its own | 10.1 |
| 34 | How a note names its regions | `region:`, one id or a list, on a typed note of any kind, in the core; checked against the path's `regions` | 6.1, 6.2, 10.5 |
| 35 | Which native language teaches the learner | **Settled by the owner, 2026-10-09: "ask the user".** The app asks when more than one of the learner's spoken languages teaches the course, showing each one's coverage, the highest pre-selected; changeable per course in Settings. A unit with no deck in the chosen language is "Coming" | 8.5, 9.5, 10.3, 10.4 |
| 36 | Grades and order of the grammar questions | A right meaning choice records 4, a right form choice 3, a typed form as today; the form is chosen while the pair is new or was last missed, typed once remembered, as Hear | 4.7, 4.8 |

Also left to later work, not this format: the mastery bar and the number of
cells a lesson asks (`words-rules-sentences.md` "To decide"); the
minimal-pair panel; the Wiktionary marking tool; `tools/suggest_bases.py`;
the pair-note tool; the split tool (`native-layers.md` step 4; a deck
agent may write its own).

## Answered by the owner, 2026-10-09

Each answer below is now in the body, at the sections named.

- **#4 Paths:** one per language learnt now (`<lang>-path.yaml`), shared by
  every layer. Sections 2.1, 2.8, 9.5, 9.6 and 10 are rewritten around
  core ids, before the deck agents start.
- **#16 Pair:** derived from the pair notes, as recommended (6.5).
- **#20 B1 plans:** required on a path whose language has a core, as
  recommended (10.1).
- **#24 Passages:** required on every planned unit, as recommended (10.1).
- **#22 Understood:** "Choosing the meaning = understood" (Reading B, not
  the recommendation): shown a form, the learner chooses what it means
  (`Ask.chooseFormMeaning`, schedule `grammarUnderstood`); choosing among
  forms of the same word (ammatō, ammaki, ammalō) or typing the form is
  produced (`grammar`). This supersedes skill-model.md's line that
  "understood" chooses among forms (4.6–4.8; `skill-model.md` on #432
  says the same now).
- **#25 Topic:** one rule, as recommended; grammar decks not yet turned
  into rules count by deck (10.1).
- **#26 Scripts without spaces:** later, as recommended (8.3).
- #23 was settled earlier: grammar understood and produced come with the
  B1 format, after the skill model's pull request (4.8).

Asked by the owner the same day, and answered by this spec:

- **Regions:** the offensive-word rating screen asks "Where you speak
  Telugu" (Telangana, Coastal Andhra, Rayalaseema, Elsewhere): "where
  will this be defined? in the decks? that needs an update to the deck
  plan". In the language's path, `regions:`, each with an id and a name
  per native language; the app adds "Elsewhere"; a rater's region and a
  card's region note name them, and the validator checks each note's
  regions (10.5, 6.1; OPEN-32 to 34 for what is recommended rather than
  decided).
