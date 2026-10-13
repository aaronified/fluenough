# Plan: what data a card carries

Written 2026-10-13. Issue #506. **This is the first piece of work; the
question-types ADR waits for it.**

**Status:** the owner answered eleven questions, and then three more on
set cards, one by one, on 2026-10-13 (quoted under "Decisions" and in the
sections they decide), and approved the drafts one by one the same day
(see "Approvals"). What is still open is under "Still open" at the end.

**How to read this plan.** Only what is in a quotation marked "owner", and
what the "Approvals" section lists, is decided. Everything else is a
proposal, whether or not it is marked: every new field name and shape not
approved there, every mandatory / recommended / optional cell beyond the
owner's mandatory set, every validator check beyond the approved ones, and
every ordering. Places where a proposal could be mistaken for a
decision are marked **Proposed:**.

## What the owner asked

> not just example sentences. we need also synonyms, antonyms, root word,
> meaning, minimal pairs, phonemic contrasts, facts, images, etc on each
> card, as applicable. some would be mandatory, others will be optional.
> create a list and plan this first.

And on the neighbouring decisions (#506, 2026-10-13):

> validator is the test. deck-format is the guide. b1-format-spec is to be
> folded into deck-format

> a simple card should be able to generate all kinds of questions

So a question type is not tied to a card's kind. It asks for **data**, and
any card that has the data can be asked it. This plan lists the data. The
ADR then maps question types to it.

## Decisions (owner, 2026-10-13, #506)

| # | Question | Answer |
|---|---|---|
| 1 | Mandatory fields | "Example sentence, Root word / base, Gender (where it exists), Confusables on word-order sentences", besides meaning and the reading for non-Latin scripts |
| 2 | Examples per word card | "At least 2". Before cloze and listening in context ship: "Ship; use cards that have them" |
| 3 | Wrong alternatives (#348, #329, #342) | "One shared list" (`confusables`) |
| 4 | A card with no confusables | "Generated from card data" |
| 5 | Synonyms and antonyms naming an untaught word | "Yes, with reading + meaning" |
| 6 | Licences | "Relicense decks to CC BY-SA" |
| 7 | Frequency | "Yes, optional, from an open list" |
| 8 | Facts on a card | "Yes, a fact can name cards" |
| 9 | Gender | "One field, per-language values" |
| 10 | Learner-language text of the new data | "In each native layer" |
| 11 | Fill order | "Hindi, Bengali, Telugu, then path order" |
| 12 | Is the set card reviewed later? | "Teach only" (shown once in its lesson as the introduction; only its members are reviewed afterwards) |
| 13 | Which groups need a set card? | "Every closed group" (any small fixed group, in each language where it applies; the validator warns when a closed group in the B1 plan has members but no set card) |
| 14 | Members taught in earlier lessons | "Show the whole set; drill only new ones" (every member shown, known ones marked; only members not yet taught are drilled; known ones are added only as review if they are due) |

## Approvals (owner, 2026-10-13, #506)

The owner approved the drafts one by one on #506. What each approval made
decided is marked in its section; the rest stays **Proposed**.

1. **Gender classes.** "[Gender classes, hi m/f; mr, gu, kn m/f/n; te
   mahat/amahat; bn, as none:] Decided as listed". See "Gender, number and
   forms".
2. **Set card shape.** "[Approval 2, set card shape: kind `set`, members by
   card id, explanation in the layer, closed groups listed per language:]
   Approve as proposed". See "Set cards".
3. **Confusables shape.** "[Approval 3, confusables shape: `id`, `word` or
   `ref`, `reading`, `kind` (form, word, sound or mark), "why" in the
   layer:] Approve as proposed". See "Confusables".
4. **Relicensing.** "[Approval 4, relicensing: CC BY-SA 4.0, a new ADR
   superseding ADR-0003, one change updating every deck and doc and the
   validator and app attribution, made before any Wiktionary or Tatoeba
   data; GPL-3.0 code unchanged:] Approve as proposed". See "Licences".
5. **Validator rollout.** "[Approval 5, validator rollout:] Confusables or
   other stuff are mandatory when available. But when they aren't available
   we have no way to verfiy and will need to depend on the deck builder. The
   reviewer will have access to each and every field anyway (will need to
   enhance the review pipeline yet again)." Confirmed by the owner: the
   validator enforces only what it can check (meaning, reading, 2 examples
   per word card, gender on nouns in gendered languages), as errors once a
   language is filled in. Data that is "mandatory when available" is never
   a validator error: the deck builder adds it and reviewers check it. The
   review pipeline work is #508. See "Validator rollout".
6. **Reading passages** (replaces the first answer). "All passages are part
   of "exams", for placements and for milestones. User can retake them, but
   not via review." Passages are not reviewed or scheduled; see #509 and
   `question-engine.md`.
7. **Ability rule.** "This is approved as proposed." See
   `question-engine.md`.

Questions 12 to 14 follow the owner's request (#506, 2026-10-13): "a
language's grammar decks must cover adjectives, genders, pronouns, etc. not
just as cards, but also together. like a card with "English has three
articles, a, an, and the", and then drill each one separately in the same
lesson." See "Set cards".

## Why a list first

Questions today depend on the card's kind: `chooseForm` only on rules cells,
`lessonQuestions` is a switch on kind, `rearrange` is gated by word count
and `pos: phrase`, `modes` is author-set and doubles as a kind marker.
Readings and numbers have question classes of their own. Planned types ask
for more data than a card has: cloze (#321), word-order extras (#348),
listening in context (#342), explain mistakes (#329), sounds of this word
(#335-337), match rows and sort (#93), placement v2 (#481).

Coverage today (cores): reading and IPA about 99% for hi, bn, te; `pos`
78-87%; `gender` 20% hi, 0 bn and te; notes 59-69%; `bases` 17-28%;
`alt_target` 3-11%; `picture` 4-6%; `modes` 4-7%; examples 0 on hi, bn, te;
`audio` 0; `pair` 2 cards and 44 pair notes.

## Card types

| Type | What it is |
|---|---|
| **word** | A vocab card of one word, or a noun, verb, adjective, adverb or pronoun of several. |
| **phrase** | `pos: phrase`, and phrasebook cards. |
| **sentence** | A sentence card (`rules` names its rules). |
| **cell** | A grammar or rules cell: one form of one word. |
| **sound** | A letter or an IPA card. |
| **number** | A generated number. |
| **set** | A closed group (the articles, the pronouns) introduced as a whole, taught once. **Proposed** name; see "Set cards". |

M = mandatory, R = recommended (a warning when missing, once the language is
past its migration step), O = optional, `-` = not applicable.
**Proposed:** this scale, and the M, R or O in each cell of the list below,
except where an owner quotation sits beside it. Mandatory means the
validator fails the deck; **Proposed:** per language, once its fill issue
is closed (see "Validator rollout"). The mandatory set the owner decided is
the one in Decisions #1: "Example sentence, Root word / base, Gender (where
it exists), Confusables on word-order sentences", besides meaning and the
reading for non-Latin scripts. How that set applies to each card type is
**Proposed** (for example "At least 2" examples is decided for a word card;
the others are not decided).

## The list

"Layer" says where it lives in a [core and layer](../DECK-FORMAT.md#core-and-layer-files):
**core** for a fact about the language, the same for every learner;
**layer** for text in the learner's language.

### 1. Meaning and senses

- **Definition:** what the card means in the learner's language, and each
  other sense it has.
- **Types:** word M, phrase M, sentence M, cell M (the form's meaning), sound
  R (a word that has it), number M (generated).
- **Layer:** layer. **Field:** `native` and `alt_native` exist. NEW:
  `senses`, a list of `{ id, native, pos?, example? }`, only when a word has
  senses that are not near-synonyms; today `usage` notes carry them.
- **Questions:** chooseMeaning, Hear (meaning), Write, matchPairs.
- **Coverage:** 100% `native`; `alt_native` low.
- **Source:** original work, or Wiktionary senses (CC BY-SA, allowed with attribution: see Licences).
- **Validator:** `native` error (exists). `senses` ids unique: error.

### 2. Examples

- **Definition:** a sentence using the word: `target`, `native`, `reading`,
  `ipa`, its `bases`.
- **Types:** word **M** (at least 2; owner, 2026-10-13: "At least 2"), phrase O, sentence `-` (it is one),
  cell R (one with the form in it), sound R, number `-`.
- **Layer:** the target, reading, ipa in the core; `native` in the layer.
- **Field:** `examples` (exists).
- **Questions:** cloze (#321, the gap is the card's word or any known one),
  word order from the example (#349), listening in context (as its
  sentence), speaking, sentence bank (#318-320). The new types ship before
  the examples are filled and appear only for cards that have them (owner:
  "Ship; use cards that have them").
- **Coverage:** 0 on hi, bn, te. This is the largest gap.
- **Source:** original work, or Tatoeba (CC BY 2.0 FR), with attribution
  per sentence; allowed once the decks are CC BY-SA (see Licences).
- **Validator:** every word of an example is taught or has a `bases` entry
  (exists, B1 decks); NEW: fewer than 2 examples on a word card is a
  warning, then an error per language (Validator rollout).

### 3. Synonyms

- **Definition:** words of the language with nearly the same meaning.
- **Types:** word R, phrase O, others `-`.
- **Layer:** core (`ref`), layer for a text saying how they differ.
- **Field:** NEW `synonyms`: `[{ ref }]`, or for a word no card teaches
  `[{ word, reading }]` with its meaning in the layer (owner, 2026-10-13:
  "Yes, with reading + meaning").
- **Questions:** chooseWord with a synonym accepted as right (cuts the false
  misses of typed production, which `alt_target` does by hand today), matchPairs
  rows (#93), sort.
- **Coverage:** none structured; `alt_target` 3-11% holds some.
- **Source:** original work, or the Wiktionary thesaurus (CC BY-SA, allowed with attribution).
- **Validator:** `ref` is a card of the language: error; a `word` entry
  has a reading (non-Latin) and, in the layer, a meaning: error; a synonym equal to
  the target: error; a synonym is also in `alt_target`: warning.

### 4. Antonyms

- **Definition:** words of the language with the opposite meaning.
- **Types:** word O (R for adjectives and verbs that have one), others `-`.
- **Field:** NEW `antonyms`, shaped as `synonyms` (an untaught word takes
  reading and meaning too). **Layer:** core, meanings in the layer.
- **Questions:** matchPairs (opposites), sort, chooseWord distractor that is
  never accepted.
- **Coverage:** none. **Source:** original work.
- **Validator:** `ref` exists: error; symmetric (the antonym lists this card
  back): warning.

### 5. Root word, derivations and word family

- **Definition:** the base a word comes from, and the words made from it.
- **Types:** word **M** (owner, 2026-10-13: "Root word / base"; a word that is
  its own root names itself or says so, form to be fixed in DECK-FORMAT).
  **Proposed:** cell M (its lemma), phrase and sentence R (`bases` of each
  word). The owner did not decide these types.
- **Field:** `bases` (exists, root of a word in a text). NEW: `family`, the
  other words from the same root, `[{ ref }]`; derivable from `bases`
  across the language, so **do not store it**: the tool builds it.
- **Questions:** chooseForm (lemma to form), cloze with the lemma shown,
  sort by family, match rows.
- **Coverage:** `bases` 17-28%. **Source:** original work.
- **Validator:** exists (B1 coverage error, stem-change warning). NEW:
  no more fields.

### 6. Register and formality

- **Definition:** how formal or polite the word is: `formal`, `neutral`,
  `informal`, `honorific`, `vulgar`, `literary`, `dated`.
- **Types:** word R, phrase R, sentence O, cell R (honorific forms).
- **Layer:** core (a closed list); a layer may explain in a note.
- **Field:** NEW `register`, one value of the closed list.
- **Questions:** choose the polite form for a person (cell), sort by
  register, chooseMeaning distractors of another register.
- **Coverage:** in `usage` notes and the offensive-word ratings
  (`offensive-words.md`); not structured. Join these two.
- **Validator:** value in the list: error; M for a card with an offensive
  rating (exists as a rating, not as this field).

### 7. Gender, number and forms

- **Definition:** grammatical gender; plural and other forms a word takes.
- **Types:** owner: "Gender (where it exists)". **Proposed:** word M for
  nouns and pronouns of a language with gender, R for adjectives (the owner
  said only "Gender (where it exists)", not which parts of speech); cell `-`
  (it is a form); sentence `-`.
- **Field:** `gender` exists. NEW: `forms`, `{ plural?, feminine?, oblique? }`
  as `{ word, reading, ipa? }`, only for forms a rules deck has no cell for.
- **Questions:** chooseForm for a word with no cell, word-order extras
  (#348: the wrong gender or number is the best extra), Write.
- **One field, per-language values** (owner, 2026-10-13: "One field,
  per-language values"). **Decided as listed** (owner, 2026-10-13, approval
  1: "Decided as listed"): the values per language below. **Proposed:**
  that each language declares its classes once, in its language file:

  | Language | Values |
  |---|---|
  | hi | `m`, `f` |
  | mr, gu, kn | `m`, `f`, `n` |
  | te | `mahat`, `amahat` (Telugu does have grammatical gender; this draft said it had none) |
  | bn, as | none: the field is not used |

  es and ja are not decided (see Still open).
- **Coverage:** `gender` 20% hi, 0 bn and te.
- **Validator:** decided (approval 5): gender on nouns in a language that
  has gender is an error once the language is filled in, and never for a
  language with none. **Proposed:** the mechanism: the language file lists
  its classes and the poses that need `gender`, and a value outside the
  list is an error.

### 8. Collocations

- **Definition:** words that go with it: a verb that takes it, a postposition.
- **Types:** word O, phrase O, others `-`.
- **Field:** NEW `collocations`: `[{ word, reading, ref? }]`, text in the
  layer.
- **Questions:** cloze (the gap is the partner), chooseWord with the
  partner in the stem.
- **Coverage:** in `usage` notes. **Source:** original work.
- **Validator:** words need readings in a script that needs them: error.

### 9. Minimal pairs

- **Definition:** a word that sounds almost the same, and what tells them
  apart.
- **Types:** word R (M where the language file lists a contrast the word
  has), sound R, others `-`.
- **Field:** `pair` and the `pair` note (exist); `contrast`: NEW on a pair
  note, the id of a contrast in the sounds file, so the "difference is..."
  line comes from data.
- **Questions:** Hear with the partner among the options (exists), minimal
  pair drill, Say's contrast message (ADR-0015).
- **Coverage:** `pair` 2 cards, 44 pair notes.
- **Validator:** exists (partner taught, warning without note). NEW:
  `contrast` names a contrast of the language's sounds file: error; a pair
  that differs by a known contrast and has none: warning.

### 10. Phonemic contrasts

- **Definition:** the sound pairs a word contains that English does not
  tell apart (`<code>-sounds.yaml`).
- **Types:** sound M (names its contrast), word O (derived from `ipa`),
  others `-`.
- **Field:** the sounds file exists. NEW: nothing on the card; the app
  finds the contrasts of a word from its `ipa` and the file. The "sounds of
  this word" button (#335-337) uses the same.
- **Questions:** sounds of this word, minimal pair, Say.
- **Coverage:** `ipa` 99%, so every word has them; the sounds file covers
  some languages. **Validator:** a language's sounds file lists every
  contrast its IPA cards teach: warning.

### 11. Confusables (the shared wrong-alternatives field)

- **Definition:** things a learner mixes up with this card, each with an
  optional reason. One list serves three planned features:
  word-order extra tiles (#348), known mistakes (#329), and the options of
  listening in context (#342). The three plans each wanted their own
  fields (`extra_tiles` and `extra_readings`, `known_mistakes`, `context.question.options`).
  It is one field.
- **Decided** (owner, 2026-10-13: "One shared list"): one field for #348,
  #329 and #342. Mandatory on sentences used for word order (owner:
  "Confusables on word-order sentences"). **Shape approved** (owner,
  2026-10-13, approval 3: "Approve as proposed"): an `id`, a `word` or card
  `ref`, its `reading`, a `kind` (form, word, sound or mark), and an
  optional "why" in the layer.
- **A card with no confusables** (owner: "Generated from card data").
  **Proposed:** the engine builds them from the same part of speech and
  theme, the card's pair partner, its other forms and words sharing its
  root, then the deck's other cards. Nothing is stored for them.
- **Types:** sentence M for word order (2-3), word R, cell R (the other
  forms of the table are confusables by default: no data), phrase O.
- **Layer:** the confusable's text is the language's (core); its `why` is
  the learner's language (layer), by id, as notes are.
- **Field:** NEW (name and shape approved, approval 3) `confusables`:

  ```yaml
  confusables:
    - { id: "masc", word: "पिया", reading: "piyā", kind: "form" }
    - { id: "no-ne", word: "मैं", reading: "maim̐", kind: "word" }
    - { id: "mark", word: "?", kind: "mark" }
  ```
  and in the layer `confusables: { "masc": { why: "चाय is feminine, so पी." } }`.
  `kind` is `form`, `word`, `mark` or `sound`; `ref` replaces `word` where a
  card teaches it (the meaning then comes free for #342). `use` is not a
  field: a question type picks the kinds it can use (tiles take `form`,
  `word`, `mark`; options take cards with a meaning).
- **Questions:** word-order extras, explain a wrong answer, listening
  options, chooseWord distractors, chooseForm distractors.
- **Coverage:** none. **Source:** original work, by agents, marked for a
  speaker's check.
- **Validator:** for word order, 2 or 3 tile-kind confusables, none equal
  to a needed tile, each with `reading` in a script that needs one: error;
  `why` missing: warning (error for a card named in #329).

### 12. Facts and culture notes

- **Definition:** a true, short thing about the word or the language.
- **Types:** word O, phrase O, sound O (a script fact), sentence O.
- **Field:** `notes` of kind `culture` (exist); the facts file (exists, per
  language, not per card). Decided (owner: "Yes, a fact can name cards"). NEW, **Proposed** name: `facts: ["hi-fact-014"]` on a card, linking
  a language fact to the words it is about, so the fact shows beside them.
- **Questions:** none directly: shown on teach and after answers. Maybe true
  or false later.
- **Coverage:** notes 59-69% (all kinds). **Validator:** id in the facts
  file: error; culture note without `source`: error (exists).

### 13. Images

- **Definition:** a picture that means exactly the word.
- **Types:** word O (concrete nouns only), others `-`.
- **Field:** `picture` (exists, one emoji, Noto Emoji, Apache-2.0).
- **Questions:** chooseMeaning and Hear options shown as pictures, matchPairs
  picture to word, a picture-prompt Write.
- **Coverage:** 4-6%. **Validator:** exists. No more than O: never every
  card has a picture that fits.

### 14. Audio

- **Definition:** a recording of the card, in place of TTS.
- **Types:** word, phrase, sentence O; sound R.
- **Field:** `audio` (exists). **Questions:** audio drills (#325-326),
  Hear, speaking.
- **Coverage:** 0. **Source:** recordings by a speaker under CC0, or
  Wikimedia Commons (licences vary: CC BY and CC BY-SA need attribution).
- **Validator:** the file exists and its licence is in the deck: error.

### 15. Usage notes, regional variants

- **Definition:** how it is used; where it differs by region.
- **Types:** all O except word R for a word with a regional variant.
- **Field:** `notes` kinds `usage`, `behaviour`, `note`, with `region`
  (exist). **Questions:** none; shown after answers.
- **Coverage:** notes 59-69%. **Validator:** exists (word card with no note,
  warning, B1).

### 16. Frequency and level

- **Definition:** how common the word is, and the course step that teaches
  it.
- **Types:** word R, phrase O.
- **Field:** the level is the B1 plan's unit (exists, in paths); NEW
  `frequency`: a rank in a named list, `{ rank, list }`, from an open list (owner, 2026-10-13: "Yes, optional, from an open list"); which
  list per language is not chosen.
- **Questions:** none; orders new words, placement v2 (#481) and the
  difficulty model.
- **Coverage:** none structured. **Source:** frequency lists; check the
  licence of each.
- **Validator:** `rank` is a positive integer: error.

### 17. Reading and IPA

- **Definition:** the Latin-letter reading (based on ISO 15919 for the
  Indic languages) and the IPA.
- **Types:** every type with a non-Latin script M (reading), word, phrase,
  sentence, cell R (ipa), sound M (ipa).
- **Field:** `reading`, `ipa` (exist). **Coverage:** about 99%.
- **Source:** `tools/transcribe.py` (generated), or Wiktionary IPA (CC
  BY-SA, `wiktionary-ipa.md`; allowed with attribution).
- **Validator:** exists.

**Learner-language text** of all the new data (a `why`, a synonym's
meaning, sense text, collocation text) lives in each native layer (owner:
"In each native layer"), keyed by id as notes are, so a language that
has a layer needs its own text.

## Set cards

Owner, 2026-10-13 (#506), the request: "a language's grammar decks must cover
adjectives, genders, pronouns, etc. not just as cards, but also together.
like a card with "English has three articles, a, an, and the", and then drill
each one separately in the same lesson." Today a rules table teaches the
forms of one word and a pattern deck one inflection table; nothing teaches a
closed set as a whole.

**Decided** (owner, 2026-10-13, Decisions #12 to #14):

- **Teach only.** The set card is shown once in its lesson as the
  introduction. Only its members are reviewed afterwards.
- **Every closed group** needs one, in each language where the group
  applies: articles, pronouns (by person, number and formality), genders,
  cases and postpositions, demonstratives, question words, conjunctions,
  days, months, number words 1-10 and colours. The validator **warns** when a
  closed group in the B1 plan has members but no set card.
- **Show the whole set; drill only new ones.** The set card shows every
  member, the known ones marked. The lesson drills only the members not yet
  taught, and adds known ones only as review if they are due.

**Status: mandatory** in the sense the owner gave: each closed group the B1
plan teaches needs a set card, and its absence is a validator warning.
**Proposed:** that the warning becomes an error per language by the same
rollout as the other fields ("Validator rollout"); the owner did not say.

**Shape approved** (owner, 2026-10-13, approval 2: "Approve as proposed"):
kind `set`, members by card id, the explanation in the layer, closed groups
listed per language. The details below are as proposed; those not in that
list stay **Proposed**:

- A set card is a card of a new kind, called here `set`. It is a card, so its
  id is permanent like every other.
- Its **members are cards, by reference**: `members: [{ ref: "<card id>" }]`.
  The members are ordinary cards (a word, a cell) and are drilled as they are
  today, by the questions their own data allows. The set card has no
  question data of its own.
- Its **explanation is text in the layer**, keyed by the set card's id, in the
  learner's language, as a note is: for example the English sentence "English
  has three articles, a, an, and the". The core holds only the members; it
  has no `native`.
- A lesson shows a set card **before its members**. The lesson builder marks
  the members already taught (they are known) and puts only the others into
  the lesson's drills. It adds a known member only as review, when its
  schedule says it is due.
- To let the validator find closed groups (approved: closed groups listed
  per language): the language file lists its closed groups by id (`articles`, `pronouns`, ...), and a set card
  names the group it covers. The check warns for a B1 plan unit whose cards
  fall in a listed group with no set card for it. How a card is placed in a
  group is **Proposed**, not decided (see Still open).
- A set card is never scheduled, never asked and never logged (see
  `question-engine.md`).

## Summary table

Core or layer: C, L, or both. Status: have, partial, NEW.

| Data | word | phrase | sentence | cell | sound | number | Where | Status | Field |
|---|---|---|---|---|---|---|---|---|---|
| Meaning | M | M | M | M | R | M | L | have | `native` |
| Senses | O | - | - | - | - | - | L | NEW | `senses` |
| Reading | M | M | M | M | M | - | C | have | `reading` |
| IPA | R | R | R | R | M | - | C | have | `ipa` |
| Examples | M (2) | O | - | R | R | - | both | partial | `examples` |
| Synonyms | R | O | - | - | - | - | C+L | NEW | `synonyms` |
| Antonyms | O | - | - | - | - | - | C | NEW | `antonyms` |
| Root, bases | M | R | R | M | - | - | both | have | `bases` |
| Word family | derived | - | - | - | - | - | tool | NEW | none stored |
| Register | R | R | O | R | - | - | C | NEW | `register` |
| Gender | M if it has | - | - | - | - | - | C | partial | `gender` |
| Forms | O | - | - | - | - | - | C | NEW | `forms` |
| Collocations | O | O | - | - | - | - | C+L | NEW | `collocations` |
| Minimal pair | R | - | - | - | R | - | C | partial | `pair`, note |
| Contrasts | derived | - | - | - | M | - | file | have | sounds file |
| Confusables | R | O | M (word order) | R | - | - | C+L | NEW | `confusables` |
| Facts | O | O | O | - | O | - | file | NEW link | `facts` |
| Culture note | O | O | O | - | O | - | C+L | have | `notes` |
| Picture | O | - | - | - | - | - | C | have | `picture` |
| Audio | O | O | O | - | R | - | C | have | `audio` |
| Usage, region | O | O | O | O | - | - | C+L | have | `notes` |
| Frequency | R | O | - | - | - | - | C | NEW | `frequency` |

The set card has no row: it is taught, never asked ("Set cards"). The M, R
and O in the table are **Proposed**, except the mandatory set the owner
named (Decisions #1) and "At least 2" examples.

## Questions follow data, not kind

ADR-0039 writes this; the list shows what it needs. Where the data exists a
type is asked; where it does not, it is not (owner, 2026-10-13). A question type
declares the data it needs, and a card is eligible when it has it:

| Question | Needs |
|---|---|
| chooseMeaning, Hear, matchPairs, Write, Say | meaning, target (every card) |
| chooseWord, chooseForm distractors | confusables, else generated from card data (see Confusables) |
| cloze | an example, or the card's own text with 2+ words |
| word order | 3+ words, 2-3 tile confusables |
| listening in context | an example, and confusables with a meaning |
| explain a wrong answer | confusables with `why`, rule ids, else cell siblings |
| sounds of this word | `ipa`, the sounds file |
| picture options | `picture` |
| synonym, antonym match and sort | `synonyms`, `antonyms`, `register`, `family` |

`modes` stays as an author's switch off, not as the kind marker.

## Licences

**Decided** (owner, 2026-10-13: "Relicense decks to CC BY-SA"): every deck
moves from CC0-1.0 to CC BY-SA. The details were approved (owner,
2026-10-13, approval 4: "Approve as proposed"): the version is **CC BY-SA
4.0**; a new ADR supersedes ADR-0003; one change updates every deck, doc,
the validator and the app's attribution, made before any Wiktionary or
Tatoeba data; the GPL-3.0 code licence is unchanged.

Following from it: data from
**Wiktionary** (CC BY-SA 4.0: senses, synonyms, IPA, etymology) and
**Tatoeba** (CC BY 2.0 FR: attribution per sentence) may then go into decks,
each with its source named. The bot already fetches Wiktionary IPA
(`tools/review_bot.py`, `wiktionary-ipa.md`). **Noto Emoji** stays
Apache-2.0. ADR-0003 (CC0) is superseded by a new ADR that records the owner's
decision (approved).

What the relicensing touches, as one change set (approved), landing before
any such data does:

- every deck's `license` field (`CC0-1.0` to `CC-BY-SA-4.0`), in cores,
  layers, fixtures and the templates (`assets/deck-template.yaml`);
- `docs/DECK-FORMAT.md`: the `license` row ("or `CC0-1.0` for public
  domain") and every example that shows it;
- `CONTRIBUTING.md`: the licensing section, what a contributor agrees to;
- `README.md`: the licence statement;
- the app's licence and attribution screen (and its text in `app_en.arb`
  and the other languages): attribution of Wiktionary and Tatoeba, and the
  share-alike terms of the decks;
- `tools/validate_decks.py`: the accepted licence list, and a check that a
  card taken from a source carries its attribution (`source`);
- ADR-0003 and the attribution notes in each language's file.

**Proposed:** contributors who gave CC0 deck content keep that grant;
adding it to a CC BY-SA deck is allowed. The owner has not said so. App
code is not part of this: its licence (GPL-3.0) is unchanged (approved).

## Validator rollout

The validator is the test (owner, 2026-10-13). The owner's rule (approval 5,
2026-10-13), in the owner's words: "Confusables or other stuff are mandatory
when available. But when they aren't available we have no way to verfiy and
will need to depend on the deck builder. The reviewer will have access to
each and every field anyway (will need to enhance the review pipeline yet
again)." Confirmed by the owner:

- **The validator enforces only what it can check:** the meaning, the
  reading, at least 2 examples on a word card, and gender on nouns in a
  language that has gender. These become **errors once a language is filled
  in.**
- **Data that is "mandatory when available" is never a validator error:**
  confusables, root word, synonyms, antonyms, minimal pairs and the rest.
  The validator cannot tell whether such data was available. The **deck
  builder adds it** (the build-deck skill says so), and **reviewers check
  it**; they see every field.
- **The review pipeline** work this needs is #508 (0.6.0), blocked by #476,
  #477 and #506.

**Proposed** mechanism for the checks the validator does enforce (the owner
decided the rule above, not these steps):

1. **Warnings first,** for each check, in the language's decks. A warning
   names the card and the field. CI prints them and does not fail.
2. **Error per language,** once the language's fill issue is closed: the
   language's file in `tools/` lists the checks that are errors for it.
3. **Format changes** (new fields) land with their validator check, where
   there is one, and a DECK-FORMAT.md entry in the same change, with tests.

The checks on a field's content when it is present (a `ref` that exists, a
reading in a script that needs one, and so on, in the list above) are errors
as the list says; only the *presence* of data that is "mandatory when
available" is never checked.

A deck marked for a speaker's check stays `unreviewed` until one has.

## Migration

**Fields first** (owner, 2026-10-13, question engine): the format and
validator for the new card data come first, so filling decks can start; the
engine comes after. The order of the steps below is **Proposed**, except
the language order in step 2, which is the owner's.

1. **Format and validator,** one change per field family, so each is
   reviewable (**Proposed** grouping and order): (a) confusables, (b) examples (at least 2) and gender classes
   per language, (c) synonyms and antonyms, (d) register, forms, frequency,
   collocations, senses, facts links. The relicensing change set goes
   before any Wiktionary or Tatoeba data.
2. **One issue per language,** in this order (owner: "Hindi, Bengali,
   Telugu, then path order"): Hindi, Bengali, Telugu, then the rest in the
   path order (`docs/ROADMAP.md`), each "blocked by" the previous one and
   by the format issues, with the `blocked` label.
3. **Per language, in this order (Proposed):** examples (the largest gap, needed by
   cloze and listening); confusables for sentences (word order, #329);
   `gender` and `pos`; `bases` to the B1 rule; pair notes with `contrast`;
   synonyms and antonyms; the optional rest.
4. Content is written by agents in the layers' own languages, validated and
   marked `unreviewed`. Reviewers are bilingual and never change a card's
   meaning (`reviewing-scope.md`). Card ids are permanent: new cards take new
   ids.
5. Each issue is blocked by its format issue (set "blocked by" and the
   `blocked` label on GitHub), and labelled `direct-code` once its
   questions are answered.

## Estimate (mine, not the owner's)

| Part | Hours |
|---|---|
| Format, validator, tests for the new fields | 8-12 |
| Examples, about 1,100 cards per language, 2 hours per 50 | 40 per language |
| Confusables for sentences, about 1-2 hours per language | 8-16 |
| Other fields, per language | 6-10 |

Confidence: medium for the format, low for the content.

## Still open

The owner's eleven questions, three on set cards and the seven approvals
are answered. These details are not, and each needs the owner (ask them one by one):

1. **Language classes for es and ja:** es is m/f in the usual way and ja has
   none; confirm.
2. **Which open frequency list** per language, and its licence.
3. **A word that is its own root:** does `bases` name itself, or does a
   flag say so? (Decided: root is mandatory; the form is a format detail.)
4. **Wiktionary and Tatoeba data:** one `source` field on the card, or per
   field? (Attribution is decided; its shape is not.)
5. **Is the new licence ADR written by the owner's hand or by us,** and
   which milestone does the relicensing change set land in? (Decided: it
   lands before any Wiktionary or Tatoeba data.)
6. **Set cards, groups:** the names (`set`, `members`) and listing closed
   groups per language are approved; how a card is placed in a group is not
   (see "Set cards").
7. **Set cards, after the lesson:** the owner said "Teach only". Can the
   learner open a set card again from a card list or the course map?
