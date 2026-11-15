# Plan: deck kinds, levels, hidden decks, sources, creators, recommendations, topics and search kinds as data

Owner requests of 2026-11-12: #1133 (culture decks from real works, with the
people behind them and their legacy), #1134 (culture woven through the
courses), #1135 (proverbs), #1136 (phrasal and multi-word verbs), #1137
(topics, and search that covers situations), #1139 (professional decks), #1140
(search results by type). Under them: #107 (new deck topics are data, question
types fixed), #99, #94, #95, #527.

This page is the design of the **scaffolding only**: the fields, files, rules
and code that let every one of those decks arrive as data on `decks-live`, with
no code change per deck. No deck content is written here, and no deck agent
starts (CLAUDE.md: deck work is paused). The field reference is in
[Deck-Format](Deck-Format#deck-kinds-levels-hidden-decks-sources-creators-and-topics).

## What is true today (checked in the code, 2026-11-12)

- `kind` in a deck header is the **file's structure** (`vocab`, `grammar`,
  `reading`, `layer`, `rules`, ...). The released app shows a `kind` it does
  not know as a broken deck. So a deck's topic cannot reuse `kind`.
- **A "situations deck" is not a deck.** `kind: situations` is one file per
  language (`decks/<code>/<code>-situations.yaml`) of sheets that list ids of
  cards that live in ordinary decks; at most six icons, each once, which are
  Today's six buttons. It is listed in the index under its own key,
  `situations`, apart from `files`. #1137 and #1139 say "situations decks":
  this plan covers both the sheets and the new professional **decks**.
- `section` (#107) and `audience` (#96) are in no parser or validator yet.
  `level` exists only as a path's `milestone` marks (A1, A2, B1) and `levels`
  word counts. `themes.yaml` is the only `shared` file.
- Search (`lib/core/search/card_index.dart`) indexes **cards only**: an FTS5
  trigram table `cards(text, card UNINDEXED, deck UNINDEXED)`; the `kind:`
  token (`words`, `grammar`, `script`, `reading`) is the card's deck kind.
  Decks, units, topics, concepts and situations are not searched as items.
- A path's `"*"` takes every deck of the course that the path does not list.
- The index's `files` list is read by every released app; anything new that an
  old app must not see goes under its own key (as `situations`,
  `script_guides`, `media`, `resources` do) or behind `min_app` (ADR-0052).

## Decisions

Each is the default taken so no one waits; the open ones are at the end.

### D1. Deck kinds: a new header field `genre`, not `kind`

`genre` is one of `culture`, `proverbs`, `multiword`, `professional`. It is
**optional** (a deck without it is an ordinary path deck) and lives on a core
or a single-file deck, never on a layer (a layer may not repeat it; the
validator says so as it does for `part`). Genre-less decks are unchanged.

The genre list is **code in the validator** (the table `GENRES`, below, the
one place a rule is written) and **data for the app**: the app reads only the
string and looks it up in the shared file `decks/sections.yaml` (D8) for its
name, section and search kind; an unknown genre in that file is a generic
"Beyond the basics" deck with the level, hidden and source rules still
applied. So a new genre is: a row in `sections.yaml`, a row in `GENRES`, no app
release. (If the owner wants the name `kind` kept: a rename is a one-line
change; it would need `min_app` for every genre deck, which D9 does anyway.)

| Genre | Header `kind` it may have | Cards | Modes a card may carry (#107's shipped set) | Required beyond the header |
|---|---|---|---|---|
| `culture` | `vocab` (quotes, lines, names: `pos: phrase`), `reading` (a passage with its questions) | A real work's text, or a name of a work or person | `recognition`, `listening`; a reading deck's questions take `reading`. Never `production` or `grammar`: a poem is not typed, and proper names are recognition and listening only (#99). `speaking` joins when #89 ships. | `level` on deck and cards; `source` block on every card or passage; `creator` on every card (D5); `tags` has `unreviewed` or `reviewed` |
| `proverbs` | `vocab` | The proverb (`target`, `pos: phrase`), the meaning (`native`), the literal in `notes`, one example, a `register` | `recognition`, `listening` (#94: phrases are not typed). | `level`; `source` block on every card (`basis: oral-tradition` with a `collection` is allowed); `register` on every card |
| `multiword` | `vocab`, `grammar` (a pattern table: main verb x light verb) | The verb phrase, meaning, literal parts in `notes`, an example | `recognition`, `production`, `listening` (a phrase is produced by word order, ADR-0024), and `grammar` on a grammar deck's cells | `level`; a `notes` entry of kind `usage` on every card (separable or not, which particle or case follows: #1136). Optional `pattern_family` string on the deck (`compound-verb`, `te-form-auxiliary`, `resultative`, `prepositional`, `pronominal`, `phrasal`), shown on the deck page, never read by code. |
| `professional` | `vocab`, `reading` | The field's vocabulary and phrases | `recognition`, `production` (words), `listening`; `speaking` when #89 ships | `professional` (a profession id, D8); `hidden: true`; `level`; tag `unreviewed` or `reviewed`; a second reviewer for the field is recorded as `checked_by` with `role: field` |

The question types stay the fixed set of #107; a genre only **narrows** which
a card may carry, never adds one. The validator refuses a card whose `modes`
names a type its deck's genre does not list. The app never checks genre to
decide a mode: it reads `modes` and `pos` as it does today.

A **professional deck is one situation of one profession in one language**
(`ja-medicine-conference-registration`), not a translation of another
language's deck. A profession is the set of decks that share `professional`;
the deck's `name` is the scene (introducing yourself, registering, presenting
and Q&A, asking for clarification, a site visit, safety, email and calls,
core vocabulary, formal register: #1139). No scene field is needed.

### D2. Levels: `level` on decks and cards, one rule

- Values, in order: `A1 < A2 < B1 < B2 < C1 < C2`. The paths reach B1, so a
  learner's level tops out at B1 today; B2 and above are valid data that
  nobody sees until a path grows (never rejected, never shown early).
- `level` on the deck header is the **lowest level the deck suits**: a deck is
  offered when the learner's level is at or above it. A card's `level`
  (optional; default the deck's) may not be **below** the deck's (validator).
  A reading passage and a creator's bio tier take `level` the same way.
- **Learner's level, per language** (pure function, `lib/core/decks/levels.dart`):
  the level of the path unit the learner has reached. A path unit's level is
  the first milestone (`A1`, `A2`, `B1`) at or after it; units after the B1
  mark are B1. The furthest unit the learner has unlocked or been placed at
  (placement, `lib/app/unlocks.dart`) gives the level. A language whose path
  has no milestones (a notation course) has no level: levelled items are not
  offered in it.
- **The rule, one gate** (`LevelGate` in `lib/core/decks/levels.dart`, called
  from every place a levelled item reaches the learner): an item above the
  learner's level is **never drilled, never shown as content, and never put in
  a result with its text**. Concretely:
  - Today, the Decks tab, lessons, reviews, weaving: not offered.
  - Search: **decks, topics, situations and units above the level are listed,
    marked with their level and not startable** (#1137, #1140: "marked"); the
    setting "Hide what is above my level" removes them (default off).
    **Culture and proverb cards above the level are not indexed for that
    learner at all** (#1133: never show an item above the level).
  - A culture item may be shown "in a supported form" only where the deck's
    data holds it: a card's `notes` gloss at the lower level is a different
    card with a lower `level`; the app never simplifies text itself.
- Genre-less path decks keep their position as their level: nothing changes
  for them, and they never carry `level` unless the deck wants it.

### D3. `hidden: true`

A deck-header flag (core or single file; not on a layer). A hidden deck is:

- **Not** in the Decks tab's lists or sections, **not** in Today (no new
  cards, no due cards, no daily plan), **not** on or placed by a path (the
  `"*"` wildcard skips it; the validator refuses a path that names one), **not**
  in placement banks, language completeness ("% of B1"), stats denominators or
  a course's deck counts.
- **Searchable**: it and its cards are indexed (as the `situations` kind for a
  professional deck, D6) and listed from the moment the index is read, before
  its file is downloaded: the index entry carries its title, genre,
  `professional`, level, language, native and card count (D9).
- **Addable**: "Add to my courses" on a result downloads it on demand
  (`DeckDownloads`, hash checked like any file) and puts it in the learner's
  added decks. **Default decision**: once added, its cards are drilled and due
  reviews join Today (the learner chose it), and the deck is listed on the
  Decks tab under a collapsed "Added from search" group for that course, which
  is the only place it shows without a search. A learner can remove it again.
- `hidden: true` is **required** on `professional` decks and allowed on any
  other genre; on a genre-less deck it is allowed too (a niche deck) and acts
  the same. `audience: adult` (#96) is separate and untouched by this plan.

### D4. `source` block on every culture and proverb card

A mapping on the **core's** card (the source of the target text is the
language's, not a translation's). The existing string `source` (header, note,
fact, example, passage) is untouched; this block is the card's.

```yaml
source:
  author: "Gurajada Apparao"          # "anonymous" allowed (proverbs, folk)
  work: "Kanyasulkam"                 # a proverb: `collection:` in its place
  date: 1892                          # a year, or "1892-1909", or "c. 1750"
  edition: "Visalandhra, 1962 ed."    # edition or url: one of the two
  url: "https://example.org/..."
  basis: "public-domain"              # public-domain | licensed | quotation | oral-tradition
  author_died: 1915                   # public-domain basis, a year
  jurisdiction: "IN"                  # ISO 3166-1 alpha-2, where the status was judged
  licence: "CC-BY-4.0"                # licensed basis: SPDX id; quotation: a short note
  licence_url: "https://..."          # licensed basis
  rights_checked: "2026-11-12"        # date, ISO
```

Validator rules (genres `culture` and `proverbs`; any other deck may carry a
block and gets the same shape check):

1. Every card (or passage) has a `source` mapping. Missing is an error.
2. Required: `date`, `basis`, `jurisdiction`, `rights_checked`; `author` and
   `work` (proverbs: `author` and `collection`, or `basis: oral-tradition`
   with a `collection`); one of `edition` and `url` (`url` must be `https`).
3. `basis: public-domain` needs `author_died` (or `author: "anonymous"` and a
   `date` before 1900) and passes a **mechanical floor**: died + term < this
   year, the term from a table in the tool (life + 60 for IN and BD, 70 for ES,
   FR and JP, 50 for CN, 70 otherwise; anonymous: publication + 70). The floor
   catches typos; it is not a legal opinion, which the reviewer owns (D10).
4. `basis: licensed` needs `licence` (an SPDX id that allows copying and
   adapting: `CC0-1.0`, `CC-BY-4.0`, `CC-BY-SA-4.0`) and `licence_url`.
5. `basis: quotation` (a work not in the public domain, #1133: "only short
   quotation that the law allows") needs `licence` (the note naming the
   exception, such as `"short quotation, Berne Convention art. 10(1)"`) and the
   card's `target` of at most 25 words, and the deck may hold at most 5 such
   cards. Anything longer is an error: leave it out.
6. `basis: oral-tradition` is allowed for `proverbs` only (and for a folk
   `culture` item with `author: "anonymous"`), with `collection` or `region`.
7. `rights_checked` is not in the future; `date` is not after `rights_checked`;
   `date` is not before the creator's `born` (D5).
8. The deck's `license` (CC-BY-SA-4.0) must be compatible: a `licensed` card
   whose licence is not on the allow list above is refused (no NC, no ND).
9. A deck tagged `reviewed` needs the card's `checked_by` (existing field).

The app shows the block on the card's page ("Source": author, work, date,
edition or link, the basis in words) and Settings lists the deck under Sources
(already does for a header `source`). Parsing: `Card.source` as a typed
`CardSource` (all fields optional in the parser, which never refuses on rights:
that is the validator's job, so an old deck still loads).

### D5. Creators: the people behind the works

A culture card names its creator by id: card field `creator: "te-gurajada"`
(one id; a list for a work by several). **A creator appears once**, however
many cards and decks cite them, in a **deck-owned shared file per language**,
`decks/creators/<code>.yaml` (`kind: creators`), listed in the index `shared`
list, downloaded with the decks, never bundled (Plan-Deck-Owned-Data's rule:
entirely about decks, changes with them). It is per language only so that no
single file grows past the 512 KB shared limit; a creator belongs to the file
of the language of their works and an id is unique across all files.

```yaml
schema: 1
kind: creators
id: "creators-te"
language: "te"
license: "CC-BY-SA-4.0"
eras:                                  # the language's own tradition (not a world scheme)
  - id: "adhunika"
    name: { te: "ఆధునిక యుగం", en: "The Modern Age" }
    reading: { te: "ādhunika yugaṁ" }
    from: 1850
    to: null                           # null: still running (the timeline's "today")
creators:
  - id: "te-gurajada"                  # permanent, `<language>-<slug>`
    name:
      te: { text: "గురజాడ అప్పారావు", reading: "gurajāḍa appārāvu", ipa: "ɡʊɾɐdʒɐːɖɐ ɐpːɐːɾɐːʋʊ" }
      en: { text: "Gurajada Apparao" }
    born: 1862
    died: 1915                         # absent: also `living: true`
    era: "adhunika"
    region: "coastal-andhra"           # a region id of the language's path
    bio:                               # per UI language, plain prose
      en: "A playwright and poet who ..."
    bio_target:                        # optional: in the language learned, by level
      A2: { text: "...", reading: "...", ipa: "..." }
    image:                             # optional; absent means the app draws a placeholder
      file: "decks/creators/images/te-gurajada.jpg"
      credit: "Photographer or archive name"
      author: "Person or body"
      licence: "public-domain"         # public-domain | CC0-1.0 | CC-BY-4.0 | CC-BY-SA-4.0
      licence_url: "https://..."
      source_url: "https://..."
      retrieved: "2026-11-12"
    legacy:                            # D5b
      text: { en: "Taught in ... today." }
      items:
        - { kind: "curriculum", year: 1990, text: { en: "..." }, source: { url: "https://...", accessed: "2026-11-12" } }
    related: [ { creator: "te-gidugu", relation: "influence" } ]
    checked_by: [ ... ]                # the existing field, D10
```

Rules:

- **Name** per language with `text`, `reading` and `ipa` for every script the
  language needs a reading for (the same rule as card text: Deck-Format
  "Script in prose"); an `en` name always.
- **Dates**: `born` and `died` are years (negative for BCE; `{ year, circa:
  true }` for an uncertain one). `born < died`; `died` no later than this year;
  a lifespan of at most 120; `died` absent needs `living: true` (and a living
  creator's image must be `licence` `CC0-1.0`/`CC-BY-4.0`/`CC-BY-SA-4.0`, never
  `public-domain` by age, and the owner's rule of no living politicians or
  contested figures is a reviewer check). A creator's `era` must exist in the
  file's `eras` and contain the creator's active years (`born + 15` to `died`)
  within 50 years of its `from` and `to`. Era ranges: `from < to`, and eras of
  one file may overlap (a tradition's eras do).
- **Image**: optional. If present: `file` exists under `decks/creators/images/`,
  one of jpg, png or webp, at most 300 KB, at most 1024 px on a side; **all of**
  `credit`, `author`, `licence`, `licence_url` (not for `public-domain`: then a
  `source_url` showing the date), `source_url` (https) and `retrieved` are
  required; `licence` is on the allow list (no NC, ND or "fair use"). No
  image: the app draws a placeholder (initials in the language's script), and
  the card says nothing about it. The card page shows the credit under the
  picture. A file in `creators/images/` that no creator cites is an error.
- **Ids**: permanent, like card ids; never reused; a retired creator is
  deleted, and a card naming a missing creator is an error.
- **Referenced from cards**: `creator` on a culture card must name a creator
  of the card's language; the card's `source.author` must equal one of that
  creator's names (any script) or be `"anonymous"` (then no `creator`).
  Every creator in the file is cited by at least one card (a warning, not an
  error, while a deck is in progress).
- **Bio and legacy are claims** and follow D5b.

#### D5b. Legacy: how the person and the work still shape the culture today

`legacy` on a creator, and optionally on a culture card where the work's
afterlife differs from its creator's.

- `legacy.text`: a short text per UI language (at most 60 words), and
  optionally `legacy.text_target` by level (`A1`, `A2`, `B1`, each with
  `reading` and `ipa`): the app shows the highest level at or below the
  learner's.
- `legacy.items`: **required** for any `legacy` (a summary alone is an error):
  one to six concrete, checkable examples, each `{ kind, text, year?, source }`.
  `kind` is one of `curriculum`, `festival`, `film`, `music`, `saying`,
  `commemoration`, `adaptation`, `place`, `other`; `text` is per UI language;
  `year` (optional) places it on the timeline's "today" end; `source` is a
  mapping with an https `url` or a `work`, and `accessed` (a date) or
  `date`. A legacy claim without a source fails the validator exactly as a
  culture note's claim must carry one.
- `related`: optional echoes: `{ creator | card: <id>, relation:
  adaptation | influence | response | echo }`; the ids must exist.
- The reviewer checks each item (D10). A living politician or contested
  claim is left out (CLAUDE.md, #99 rules).

#### D5c. The timeline is derived, not stored twice

The timeline needs no file of its own. The app builds it from the data above:
a **creator** is a span (`born` to `died`, an open end for `living`), a
**work** is a point (a card's `source.date`, a range drawn as a span), grouped
by the creator's `era`, with the eras as the axis bands, and a legacy item's
`year` as a mark after the span, so the line **runs to the present year**:
"today" is its right end. The learner's level limits it exactly as D2 does:
only works at or below the level are points. The pure function
`buildTimeline(creators, cards, level)` lives in `lib/core/decks/timeline.dart`
(no Flutter) and is tested without a device. Its screen waits for the mockup.

### D6. Topics: language-specific, deck-owned, searchable

A topic is something a learner would search for in one language: a grammar
peculiarity, a verb form, a class of words, a profession, a situation. It
**holds no card text**, like a situations file; it names what already exists.

- **File**: `decks/<code>/<code>-topics.yaml`, `kind: topics`, one per language
  (a file `<code>-topics.yaml`, `id: <code>-topics`), beside the language's
  other files and downloaded with the language. It is **not** in `shared`,
  because Plan-Deck-Owned-Data's rule keeps a language's own files out of
  `shared` (they already download with the language); the index lists it under
  a per-language key `topics`, apart from `files`, because the released app
  would show an unknown `kind` as a broken deck. It is edited on decks-live,
  with the decks, and never needs a release.
- **Ids**: `<code>-<slug>`, `[a-z0-9-]+`, permanent, unique across the file
  (`ja-wa-vs-ga`, `es-ser-vs-estar`, `hi-ergative-ne`); a retired topic is
  deleted.
- **Names**: `name` and `summary` keyed by UI language code, `en` required (the
  learner sees the first spoken language it is written in, as a situation's
  `title`). Names of the thing in the target language go in `term`
  (`{ text, reading }`: は vs が, ser / estar).
- **What it covers** (all optional lists, at least one required):

| Key | Names | Resolved against |
|---|---|---|
| `decks` | core ids of the language's decks (any genre, hidden ones included) | the language's decks |
| `units` | a path unit by **any core id on it**, or its `planned` id | the language's path |
| `cards` | card ids of the language | the language's decks |
| `grammar` | path `grammar:` concept ids (`be`, `lo`, `conditional`) and rules-table names | the path's `grammar` lists |
| `situations` | a situation sheet's `id` | the language's situations file |
| `topics` | related topic ids of the same file | this file |
| `script_units` | feature ids of the language's script guides (`features[].id` of `<code>-script`, or `<code>-<script>-script`) | the language's script guides |
| `chars` | letters, signs, conjuncts or glyphs, each a string, or `{ text, reading?, ipa? }` | nothing: the list is the data |

- `level`: the lowest level the topic suits (D2); `kind` of the topic is
  `grammar`, `verbs`, `words`, `script`, `register`, `profession` or `other`
  (display grouping only; an unknown value is `other`).
- **Scripts are topics too** (owner, 2026-11-12, comment on #1137): the
  alphabet, Bengali juktakkhor (ya-phala and ra-phala included), Devanagari
  conjuncts and matras, hiragana and katakana, kanji groups, Chinese radicals,
  Arabic positional forms, Braille groupsigns and shortforms. All of it is
  **data, with no per-script code**: a script topic has `kind: "script"`, names
  the script guide's features by `script_units` (the guide already lists each
  feature's `letters`), and/or lists its own `chars` (a string of at most 12
  code points, no spaces, NFC, each once; a mapping `{ text, reading, ipa }`
  where a reading is wanted, which a non-Latin text needs). It may also name
  the decks (the language's script decks) and cards that teach those
  characters. The validator resolves `script_units` against the language's
  script guides and never reads a character list for meaning; the app draws
  `chars` as tiles and drills the topic's decks and cards as for any other
  topic. A character list is how a topic names glyphs that no card carries yet, but once a topic lists `decks` its `chars` must be the targets of those decks' cards (#1228, `tools/topic_chars.py` writes them; see Deck-Format, "Script topics").
  The fixture is `test/fixtures/deck-kinds/decks/zz/zz-topics.yaml`
  (`zz-juktakkhor`, a script guide's two features and five conjuncts).
- **A topic page** lists its decks, units, concepts, situations and the count
  of its cards, and **starts a drill on its cards** (the cards of `decks`,
  `cards` and the decks of its `units`, at or below the learner's level,
  hidden decks included only if added). The page waits for the mockup.
- The validator checks every reference (decks, units, cards, grammar,
  situations, topics and script units) resolves across the language's files
  (as a situations file's card ids are), ids unique, a hidden deck allowed, a
  `level` valid, and that a topic does not list itself.

### D7. Sections: the Decks tab's lists, as data

The `section` header field of #107, optional, defaulting to the genre's
section in `sections.yaml`, then to `path`. `path` is the 14-theme path; the
others are listed after it: `beyond-basics` (culture, proverbs, multiword) and
`professional` (not listed on the Decks tab at all: hidden). A deck of a
section the app's `sections.yaml` does not list goes under `beyond-basics`.

### D8. `decks/sections.yaml`: one shared file for genres, sections, professions and search kinds

`kind: sections`, schema 1, listed in the index `shared` list (add
`decks/sections.yaml` to `SHARED`), edited on decks-live like `themes.yaml`,
with main's copy as the bundled fallback for an offline first start. It holds:

```yaml
schema: 1
kind: sections
sections:
  - { id: "path", name: { en: "Course" }, listed: true }
  - { id: "beyond-basics", name: { en: "Beyond the basics" }, listed: true }
  - { id: "professional", name: { en: "Professional" }, listed: false }
genres:
  - { id: "culture", name: { en: "Culture" }, section: "beyond-basics", search_kind: "culture", weave: true }
  - { id: "proverbs", name: { en: "Proverbs" }, section: "beyond-basics", search_kind: "proverbs", weave: true }
  - { id: "multiword", name: { en: "Multi-word verbs" }, section: "beyond-basics", search_kind: "multiword", weave: true }
  - { id: "professional", name: { en: "Professional" }, section: "professional", search_kind: "situations", weave: false }
professions:
  - { id: "medicine", name: { en: "Medicine" } }
search_kinds:                        # D10
  - { id: "situations", name: { en: "Situations" }, row: "scene", order: 1 }
  - { id: "topics", name: { en: "Topics" }, row: "topic", order: 2 }
  - { id: "decks", name: { en: "Decks" }, row: "deck", order: 3 }
  - { id: "concepts", name: { en: "Grammar concepts" }, row: "concept", order: 4 }
  - { id: "cards", name: { en: "Words" }, row: "card", order: 5 }
  - { id: "units", name: { en: "Units" }, row: "unit", order: 6 }
  - { id: "culture", name: { en: "Culture" }, row: "card", order: 7 }
  - { id: "proverbs", name: { en: "Proverbs" }, row: "card", order: 8 }
  - { id: "multiword", name: { en: "Multi-word verbs" }, row: "card", order: 9 }
```

Ids are permanent. The validator checks it (unique ids, `en` names, a genre's
`section` and `search_kind` exist, `row` is one of the six templates,
`order` unique) and that every `genre` and `professional` a deck uses is listed
(a deck using an unlisted genre or profession is an error, so a new profession
is "add a row, then add decks" in one decks-live PR). Size well under 512 KB.

`weave` on a genre is the default for the deck header's optional `weave:
true|false` (D11).

### D9. The index: `shelves` and `topics` per language, `creators` in `shared`

`tools/deck_index.py` writes, all under keys an older app ignores:

- **`shelves`** (per language): every deck file with a `genre`, **hidden ones
  too**, apart from `files`. An entry is a `files` entry plus `genre`,
  `level`, `hidden`, `professional` (if any), `section`, `weave`, `title` (the
  deck's `name`), `cards` (count), and `native` and `core` as a deck's. The
  language's `size` counts the non-hidden entries only; a hidden entry is
  fetched on demand ("Add to my courses") and is in `size` of nothing. A deck
  that had a genre moved out of `files` the same run, so a release that reads
  `files` never sees it.
- **`topics`** (per language): the language's topics file as `situations` is
  listed, counted in `size`.
- **`shared`**: `decks/sections.yaml` (add to `SHARED`; the app's
  `sharedKinds` gains `sections`) and every `decks/creators/<code>.yaml`
  (`SHARED` becomes patterns; `sharedKinds` matches by pattern, kind
  `creators`, schema 1). Creator **images** are listed under a top-level
  `shared_media` list (`path`, `size`, `sha256`, `kind: "image"`, `language`),
  downloaded on demand when a creator is shown, checked by hash alone.
- **`min_app`** is written automatically for every `shelves`, `topics`,
  `sections` and `creators` entry from one constant, `MIN_APP_KINDS`, in
  `deck_index.py` (the release that holds task T10): no per-deck chore in
  `decks/min_app.json`, which stays for hand gates. `check_released` already
  refuses a gate on a file a release ships. Version stays 1.
- A search entry **needs no `kind` field of its own**: the index's entries
  already use `kind` for the file's structure, so the app derives a result's
  search kind from the entry's `genre` through `sections.yaml`
  (`genres[].search_kind`), and from the item type for everything else (D10).

### D10. Search kinds (tabs) as data

An indexed item has an **item type** (code: `card`, `deck`, `unit`, `concept`,
`topic`, `situation`, from where it comes) and a **search kind** (data:
`sections.yaml` `search_kinds`), which is a tab. The mapping:

| Item | Search kind |
|---|---|
| a card of a deck with a `genre` | the genre's `search_kind` (`culture`, `proverbs`, `multiword`) |
| a card of a hidden `professional` deck | shown as its deck's row under `situations` (the best matching card is the snippet); never in `cards` |
| any other card | `cards` |
| a visible deck without a genre, or a genre deck | `decks` |
| a `professional` deck | `situations`, row `scene`, with the profession and level |
| a situation sheet of a situations file | `situations` |
| a path unit | `units` |
| a path `grammar` concept or rules table | `concepts` |
| a topic | `topics` |

A **new kind is data** when it reuses one of the six row templates (`scene`,
`topic`, `deck`, `concept`, `card`, `unit`): add the row to `search_kinds` and
set a genre's `search_kind` to it. A **new row template** is a code change
with an ADR, like a new question type. The tab shows only with results, its
count in its label, the best match's tab opens first, and the last tab is kept
for the session (#1140). Level marking is D2's.

The existing `kind:` search token (`words`, `grammar`, `script`, `reading`,
`SearchKind` in `query.dart`) is the card's deck structure and stays as a
**filter chip** inside the `cards` tab; the tabs are the new
`ResultKind` (a string id from the data), so the two never mix.

In the FTS5 index the single table becomes `items(text, item UNINDEXED, kind
UNINDEXED, parent UNINDEXED, language UNINDEXED, level UNINDEXED)`; card rows
keep today's text and trigram behaviour; a deck row's text is its name,
description, profession and the names of its cards' themes; a topic's is its
names, term and summary; a unit's its deck names; a concept's its name and
term. `candidates()` gains an optional set of kinds. The matcher (`fuzzy.dart`)
is unchanged: the index only narrows.

### D11. Weaving (#1134): data now, rules in the mockup

Data a weaving needs, all above: the deck's `genre` and `weave` (default from
the genre), its `level`, each card's `level`, the learner's level (D2) and the
setting "Culture items" (on by default; off hides `culture`, `proverbs` and
`multiword` items from lessons and Today, never from search or the section).
How many per unit, whether they count toward progress, and the order are
**owner questions** and belong to the mockup (#1134 says so). The data model
does not change with the answers: they are app settings. A path may also place
a genre deck explicitly by naming its core id in a unit (allowed unless the
deck is hidden), which weaves it at that unit with no new field.

### D12. Reviewer checks (what a reviewer signs, #1133, #1135, Plan-Reviewing-Scope)

Recorded with the existing `checked_by` on each card and each creator
(Deck-Format "Who checked it"), `role` of `language` (bilingual) or `field`
(a worker in the profession, for professional decks). Checklist, per item:
the text is the work's text and the meaning is unchanged; the source block is
true and the rights basis is right for the jurisdiction (the validator's term
table is only a floor); the creator's dates, era and region; every bio and
every `legacy` item (the claim is true and the source says it); the image is
the person, and the licence matches the source page; no living politician or
contested figure; more than one tradition where the region has them; the
`level` suits the text. A `reviewed` tag on a culture deck needs all of its
cards and every creator it cites to be checked, and the validator says so.

### D13. Recommendations: popular works that are not reproduced

Culture decks quote works whose rights allow it (D4). **Recommendations** point
at works the learner should find elsewhere and teach **about** them, never
reproducing them. A `recommendation` is a record in a deck-owned shared file
per language, `decks/recommendations/<code>.yaml` (`kind: recommendations`,
listed in `shared` like `creators`):

```yaml
schema: 1
kind: recommendations
id: "recommendations-te"
language: "te"
license: "CC-BY-SA-4.0"
recommendations:
  - id: "te-rec-kanyasulkam"        # permanent, `<language>-rec-<slug>`
    medium: "book"                  # book | film | series | song | play | podcast | comic
    title: { text: "కన్యాశుల్కం", reading: "kanyāśulkaṁ", ipa: "..." }
    creator: ["te-gurajada"]        # ids of the creators file (D5); required
    year: 1892
    level: "B1"                     # a suggestion of the level it suits (D2)
    script: "telugu"                # books only: the script the work is printed in
    briefing: { en: "What it is, why it matters, what to expect." }
    questions:                      # authored, 3 to 8, in the reading-deck shape
      - { id: "q1", prompt: { en: "..." }, options: { en: ["...", "...", "..."] }, answer: 1 }
    legal:                          # optional; never a pirate or unlicensed link
      - { kind: "library", url: "https://...", note: { en: "Free: public domain" } }
    quoted_in: "te-culture-kanyasulkam"   # optional: a culture deck that quotes it
    checked_by: [ ... ]
```

- **Not reproduced**: no `target` text of the work, no excerpts beyond a title.
  The questions test comprehension of the work (plot, people, ideas), are in
  the learner's spoken language, and have `level`-neutral wording. A
  recommendation holds no `source` block because it quotes nothing; a quote is
  a culture card.
- **Legal route**: `legal` is optional. Allowed `kind`: `library`, `publisher`,
  `store`, `stream`, `archive`, `public-domain`. The validator accepts `https`
  only and refuses a host on a deny list in the tool (`tools/pirate_hosts.txt`)
  and any URL whose basis it cannot name; a reviewer confirms each link is the
  rights-holder's or a library's (D12).
- **Public-domain works** may be both recommended and quoted: `quoted_in` links
  a recommendation to the culture deck that quotes it (the id must exist and
  that deck's cards must cite the same `creator`); the app shows "Read the
  excerpts in the deck" beside "Read the whole work".
- **Levels** are D2's: a recommendation above the learner's level is not
  offered (not listed on the homepage, not indexed as a card); searched like a
  deck: search kind `recommendations`, row template `card`, added to
  `sections.yaml` as data.
- **Learner state is not deck data.** A learner marks a work **completed**; the
  mark (`recommendation id`, date) is stored in the learner's progress
  database and backups (`lib/core/data/`), never in a deck or the index. The
  homepage lists completed works. **Questions are asked only on a completed
  work**: they enter lessons and reviews as `reading`-mode items (the existing
  mode, #98) only after the mark, graded like a reading deck's, scheduled with
  FSRS under the question's id (permanent like a card id). Un-marking stops them.
- **Books and scripts** (owner's rule, recorded as read; owner question 11):
  a `book` is recommended **only when the learner's course includes script
  learning** in that language (the course's path has an `alphabet`, or the
  learner is on a script-only course), and a **script-only learner** sees only
  books whose `script` is one they are learning. Films, series, songs, plays,
  podcasts and comics are not gated by script. The gate is a pure function in
  `lib/core/decks/recommendations.dart` over the course, so the data needs only
  `medium` and `script`.
- Validator: ids unique and permanent; `creator` ids resolve; `year` sane
  (not before the creator's `born`, not after this year); `questions` 3 to 8
  with a valid `answer` (reading-deck rules); `script` required for `book`
  and one of the language's `scripts`; `title` has a reading where the
  language needs one; `quoted_in` resolves; `reviewed` needs `checked_by`.

### D14. Private decks use the same model

A private package (`wiki/Plan-Private-Languages.md`, `.fnzip`) holds ordinary
deck files, so it may carry `genre`, `level`, `hidden`, `source`, creators,
topics and recommendations like any other deck. **The private-decks slice must
not hard-code the kinds**: its validator and importer reuse `Catalog.parseAll`
and the same checks (its section 2.4 already says to reuse the app's readers),
read `sections.yaml` for genres, professions and search kinds, and take the
`GENRES` table from the one tool, with no second list. Its `manifest.min_app`
covers the new keys. A private deck's ids sit in the `fnpd-<code>` namespace
(its section 2.2), so a creator or recommendation id of a package is namespaced
too, and the rights rules of D4 apply to a private deck's own `source` as a
reviewer's note only: a private deck is never published, so the public-domain
floor is a warning there, not an error (owner question 12). Search indexes
active packages' items under the same kinds.

## Tasks

Order is the order to build. Each row is **one pull request** (T1 is docs, to
main). Tests run in CI only. "H" means a Haiku task (fully specified below, no
improvisation, guarded and logged per CLAUDE.md); "S" Sonnet. Code and tools
go to main; deck data later goes to decks-live. Tasks marked **MOCKUP** wait
for an approved mockup (docs/mockups/README.md); every other task can start now.

| # | Task | Files | Behaviour | Tests | Who | Needs |
|---|---|---|---|---|---|---|
| T1 | ADR-0055 and the format text | `wiki/ADR-0055-Deck-Kinds-As-Data.md`, `wiki/ADR-Index.md`, `wiki/Deck-Format.md` | The ADR records: `genre` beside `kind`, the closed question-type set (#107), the six row templates, topics per language, creators shared. Docs, straight to main | none | S | this plan |
| T2 | Level model | `lib/core/decks/levels.dart` | `enum Level` A1..C2 with parse and compare; `levelOfUnit(path, i)`, `learnerLevel(path, furthestUnit)`; `LevelGate.allows(item, learner)`; no Flutter import | `test/levels_test.dart`: order, a unit after B1 mark, no milestones means no level, an item above is refused | H | none |
| T3 | Validator: header fields | `tools/validate_decks.py` | Add `genre`, `level`, `hidden`, `professional`, `section`, `weave` to `HEADER_KEYS`; refuse them on a layer; table `GENRES` (D1) checks `kind`, `modes`, `pos` and required fields; `professional` needs `hidden: true`; card `level` not below deck `level`; a path may not name a hidden deck; reads `sections.yaml` when present to check ids | `tools/test_validate_kinds.py` (one failing deck per rule) | S | T7 for the ids check (skip when no file) |
| T4 | Validator: `source` block | `tools/validate_decks.py`, `tools/pd_terms.py` (the term table) | Rules 1 to 9 of D4; `CARD_KEYS` gains `source`, `level`, `creator`, `legacy`; passage `source` may be a mapping | same test file, a case per rule | S | T3 |
| T5 | Validator: creators file | `tools/validate_decks.py` | New kind `creators` (`KINDS`, `NOT_DECK_KINDS`, filename `decks/creators/<code>.yaml`): D5 and D5b rules, image file checks, uncited image, card `creator` resolves, `source.author` matches, dates sane, reviewed-deck rule | `tools/test_validate_creators.py` | S | T4 |
| T6 | Validator: topics file | `tools/validate_decks.py` | New kind `topics`, `<code>-topics.yaml`, one per language, D6 reference checks across the language's files | `tools/test_validate_topics.py` | S | T3 |
| T7 | Validator: sections file | `tools/validate_decks.py` | New kind `sections`, `decks/sections.yaml`, D8 rules, every used genre and profession listed | `tools/test_validate_sections.py` | H | T3 |
| T8 | Starter shared data | `decks/sections.yaml` on decks-live, main's bundled copy `decks/sections.yaml` and `pubspec.yaml` asset | The file as in D8, with the four genres and the nine search kinds, no professions yet | validator (CI) | H | T7 |
| T9 | Index tool | `tools/deck_index.py`, `tools/test_deck_index.py` | `shelves`, `topics` keys, `shared` patterns for `sections` and `creators`, `shared_media`, auto `min_app` from `MIN_APP_KINDS`, `check_released`, size rules (D9) | extend `tools/test_deck_index.py` with a fixture per key | S | T3 to T7 |
| T10 | App: deck and card fields | `lib/core/models/deck.dart`, `lib/core/models/card.dart`, `lib/core/data/deck_parser.dart`, new `lib/core/models/card_source.dart` | `Deck.genre/level/hidden/professional/section/weave`, `Card.level/creator`, `CardSource`; parsed leniently (never refuses on rights); a layer's copies ignored; no Flutter in `core/models` | `test/deck_parser_kinds_test.dart` | H | T2 |
| T11 | App: sections file | `lib/core/decks/shared_data.dart`, `lib/core/data/sections.dart` (new), `lib/app/deck_downloads.dart`, `lib/app/shared_deck_source.dart`, `lib/app/deck_catalog.dart` | `sharedKinds` gains `decks/sections.yaml`; `parseSections`; kept like `shared-themes.yaml`; bundled fallback; `Catalog.sections` | extend `test/deck_shared_data_test.dart` | S | T8, T10 |
| T12 | App: shelves and on-demand download | `lib/core/decks/deck_index.dart`, `lib/app/deck_downloads.dart`, `lib/app/downloaded_decks.dart` | Parse `shelves` (a bad entry costs itself); download the visible ones with the language; `fetchHidden(entry)` on "add"; `min_app` respected | `test/deck_index_shelves_test.dart` | S | T9, T10 |
| T13 | App: hidden and level filters | `lib/app/deck_catalog.dart`, `lib/app/daily_plan.dart`, `lib/app/unlocks.dart`, `lib/app/placement_bank.dart`, `lib/features/decks/decks_page.dart` | One `visibleDecks` and one `LevelGate` call site per surface: Decks tab, Today and lessons, path `"*"`, placement, completeness, stats; added hidden decks join Today and show under "Added from search" | `test/hidden_decks_test.dart`, `test/level_gate_test.dart` | S | T10, T11, T12 |
| T14 | App: topics | `lib/core/models/topic.dart`, `lib/core/data/topics.dart`, `lib/app/deck_catalog.dart`, `lib/app/topics.dart` | Parse `topics` (as `situations` is); resolve references to decks, units, cards, concepts, sheets; a topic's drill cards (level-gated); no UI | `test/topics_test.dart` | S | T9, T13 |
| T15 | App: creators | `lib/core/models/creator.dart`, `lib/core/data/creators.dart`, `lib/core/decks/timeline.dart`, `lib/core/decks/shared_data.dart` | Parse `creators` (shared, per language), image on demand, `Creator.nameFor/bioFor/legacyFor(level, spoken)`, `buildTimeline(creators, cards, level)` with the "today" end; no UI | `test/creators_test.dart`, `test/timeline_test.dart` | S | T11 |
| T16 | App: search items and kinds | `lib/core/search/card_index.dart`, new `lib/core/search/search_items.dart`, `lib/core/search/query.dart`, `lib/app/repository_decks.dart` | `items` table with `kind`; item builders for decks, units, concepts, topics, situation sheets, creators' works; the kind mapping of D10 from `sections.yaml`; `candidates(..., kinds)`; counts per kind; level marks; culture and proverb cards above the level not indexed; the `kind:` token untouched | `test/search_items_test.dart`, extend the card index tests | S | T13, T14 |
| T17 | **MOCKUP** search tabs (#1140), topic page (#1137), culture weaving (#1134), creator card and timeline screens, "Added from search" group | `docs/mockups/search-tabs.html`/`.md`, `topic-page`, `culture-in-course` | Four mockups to the README's rules (real theme, light and dark, 1.4x, Hindi and Bengali examples, self-checks in the `.md`); the creator card (picture or placeholder, credit, dates, era, bio, legacy), the timeline and the weaving share the culture-in-course mockup | Chromium check | S | owner approval before T18 to T20 |
| T18 | UI: search tabs | `lib/features/decks/*search*`, `lib/l10n/app_en.arb` | `TabBar` from the data, rows per template, remembered tab, level marks, "Add to my courses" on a hidden result | widget tests at 1.4x | S | T16, T17 |
| T19 | UI: topic page | `lib/features/topics/` | The page and its drill | widget tests | S | T14, T17 |
| T20 | UI: culture in the course | `lib/features/culture/`, `lib/app/daily_plan.dart` | Weaving, the setting, the creator card and the timeline | widget tests | S | T13, T15, T17 |
| T21 | Fixtures | `test/fixtures/deck-kinds/decks/` (own root; the sample deck's snapshot tool never touches it), `tools/test_validate_kinds.py`, `test/deck_kinds_fixture_test.dart` | One small Spanish (`es`) set with its own `index.json` made by `deck_index.py` over it: a culture deck (vocab and reading, two creators, one with a licensed image, one placeholder, legacy items, a `quotation` card), a proverbs deck, a multiword deck (vocab) and one grammar deck, a hidden professional deck, `sections.yaml`, `creators/es.yaml`, `es-topics.yaml`, a path naming one genre deck; plus a failing copy of each for the validator tests (under `invalid/`, not validated by CI's whole-tree run) | Python and Dart tests read it | H | T3 to T7 (written alongside them, file by file) |
| T22 | Release note and check | `CHANGELOG.md`, `tools/check_sample_contract.py` | A line per code PR under Unreleased; the contract check learns the new keys (`shelves`, `topics`, `shared_media`) so decks-live's CI accepts them | existing | H | T9 |
| T23 | Validator: recommendations file | `tools/validate_decks.py`, `tools/pirate_hosts.txt` | New kind `recommendations`, `decks/recommendations/<code>.yaml`, D13 rules | `tools/test_validate_recommendations.py` | S | T5 |
| T24 | Index and app parsing: recommendations | `tools/deck_index.py`, `lib/core/models/recommendation.dart`, `lib/core/data/recommendations.dart`, `lib/core/decks/shared_data.dart` | A `shared` pattern for the file; `parseRecommendations`; the script and level gate `lib/core/decks/recommendations.dart` (pure) | `tools/test_deck_index.py`, `test/recommendations_test.dart` | S | T9, T15 |
| T25 | Completed marks and questions | `lib/core/data/` (a table and a migration), `lib/app/recommendation_progress.dart`, `lib/app/session.dart` | Store completed marks in the progress database and backups; questions join lessons as `reading` items only for completed works; un-mark stops them | `test/recommendation_progress_test.dart`, a backup round trip | S | T24 (drift schema change: high-conflict file, coordinate) |
| T26 | **MOCKUP** then UI: recommendations on the homepage and the work page | `docs/mockups/culture-in-course.*`, `lib/features/culture/` | The "Completed" mark, the homepage list, the briefing, the legal links, the link to the quoting deck; part of the culture-in-course mockup with the creator card and timeline | widget tests | S | T17, T25 |
| T27 | Private decks use the kinds | `wiki/Plan-Private-Languages.md` (a cross-reference line), the private importer task of that plan | The importer calls the same parse and validator paths and reads `sections.yaml`; no kind list of its own; a test that a private package with a `genre: proverbs` deck imports and is searchable | `test/private_decks_kinds_test.dart` | S | that plan's importer task, T11, T16 |
| T28 | Fixtures: creators, recommendations | `test/fixtures/deck-kinds/decks/` | Two creators, a book (with `script`) and a film recommendation, one quoted in a culture deck, one failing copy per rule; a private-package fixture with a genre deck | Python and Dart tests | H | T5, T23 |

Starts without a mockup: T2 to T16, T21 to T25, T27, T28 (data model, validator, index,
hidden flag, search item indexing). Waits for the mockup: T17 itself first,
then T18 to T20 and T26. Order of the first wave: T1, T2, T3, T7, T4, T5, T6, T8, T9,
T10, T11, T12, T13, T14, T15, T16 with T21 written beside each validator task.
Deck content (works, creators, proverbs, professional decks) starts only when
the owner resumes deck work, and arrives on decks-live.

### What is safe for an installed or old app

Old apps ignore `shelves`, `topics`, `shared_media` and the new `shared` files
(they do not know the kinds), so no genre deck, hidden deck, topic or creator
reaches them; no existing file changes. A deck with `genre` is never in `files`.
`decks/min_app.json` is not needed per deck: the tool gates every new-key
entry. An app that knows the keys but not a later `genre` shows it under
"Beyond the basics" with the level and hidden rules applied.

## Open owner questions

1. **Field name**: `genre` for the deck topic (kept apart from the file `kind`
   that a released app would call broken), or rename it `kind` and gate every
   genre deck by `min_app`? Default: `genre`.
2. **After "Add to my courses"** a hidden deck joins Today and sits in an
   "Added from search" group (the default taken), or stays reachable only by
   search?
3. **Culture off switch and weaving**: items per unit, whether they count toward
   path progress or are bonus, whether the switch hides proverbs and multi-word
   verbs too (#1134; answered with the mockup).
4. **Above-level results**: decks, topics and situations shown marked (the
   default, per #1137 and #1140) with a "Hide what is above my level"
   setting off by default; and culture and proverb cards above the level not
   shown at all. Right?
5. **Topics file location**: per language and in the language's own index key
   (taken, because Plan-Deck-Owned-Data keeps language files out of `shared`),
   or a shared topics file across all languages?
6. **Professions**: the list to start with, and which languages first (#1139).
7. **Public-domain terms**: is the validator's floor table (life + 60 for IN
   and BD, 70 for ES, FR and JP, 50 for CN) the one the owner wants, and who
   is the named rights reviewer for a `basis: public-domain` card?
8. **Creator images**: are `CC-BY` and `CC-BY-SA` images acceptable beside
   public-domain and CC0 ones (the credit shows on the card), and may a living
   creator be shown at all (default: allowed with a free licence, never a
   politician)?
9. **`quotation` limit**: 25 words and 5 cards per deck: right, or should the
   owner want none at all unless a rights reviewer signs?
10. **Release number** for `MIN_APP_KINDS`: the release that holds T10 to T12.
11. **Books and scripts** (D13, as the owner said it): books are recommended only
    when the course includes script learning, and a script-only learner sees only
    books in a script they learn. Is that the whole rule, and does a learner on a
    Latin-script language (Spanish, French) with no script course see books?
    Default taken: yes, a language whose only script is Latin counts as script
    learning already done.
12. **Private decks and rights**: the public-domain floor and the `source` rules
    are warnings, not errors, in a private package (taken, because it is never
    published)?
13. **Recommended works**: may the legal links include stores and streams or
    only libraries and publishers (default: both, reviewer-confirmed)?
