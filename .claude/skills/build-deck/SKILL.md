---
name: build-deck
description: Use when building or extending a Fluenough deck, including writing the next planned unit of a language's B1 plan, a word unit or a grammar unit (a core in decks/<lang>/ plus its English layer in decks/<lang>/en/). Not for app code.
---

The wiki is the source of truth for documentation: https://github.com/aaronified/fluenough/wiki

# Build a deck

An ordered checklist. It does not copy the format: [docs/DECK-FORMAT.md](../../../docs/DECK-FORMAT.md)
is the guide and `tools/validate_decks.py` is the test (owner, 2026-10-13,
#506). Where this file and DECK-FORMAT differ, DECK-FORMAT wins. Read it before
writing, and [AGENTS.md](../../../AGENTS.md) and [CLAUDE.md](../../../CLAUDE.md)
for the rules. Section names below are headings in DECK-FORMAT.md.

Before you start:

- Card ids are permanent: never renumber, reuse or tidy one (AGENTS.md rule 1).
- Quote every YAML text value and key ("YAML values"). `true`, `false` and
  whole numbers are the only unquoted values.
- Do not write a card for one question type. The owner's rule (2026-10-13,
  #506) is that a simple card should be able to generate all kinds of
  questions. Questions will be derived from card data (ADR-0039, accepted).
  The owner decided the mandatory set (2026-10-13, #506,
  `docs/DECK-FORMAT.md`, "Card data"): meaning; the reading for a non-Latin script; at
  least 2 examples on a word card; the root word (`bases`); gender where the
  language has it (per-language classes, decided: hi m/f; mr, gu, kn m/f/n;
  te mahat/amahat; es m/f; bn, as and ja none); and confusables on a sentence used for word
  order. **The validator enforces only what it can check** (meaning, reading,
  2 examples per word card, gender on nouns in gendered languages, as errors
  once a language is filled in). Data that is "mandatory when available"
  (confusables, root word, synonyms, antonyms, minimal pairs and the rest) is
  never a validator error, so **you, the builder, must add it whenever it is
  available**, and reviewers check it (owner, 2026-10-13, #506; review
  pipeline work is #508). Fill what DECK-FORMAT allows (reading, ipa,
  alt_target, pos, gender, examples, notes, bases, pair, picture, and the
  card data: synonyms, antonyms, confusables, register, forms,
  collocations, senses, frequency where it fits), at least 2 examples on a
  word card, and do not set modes to restrict a card to one drill unless
  DECK-FORMAT requires it. When a field lands, DECK-FORMAT and this list
  are updated in the same change. New text for the learner goes in each
  native layer.
- Every question-word card (where, when, who, what, why, how, which, how
  many) gets a `picture` plus `picture_ask: true` (DECK-FORMAT, "A question
  word's picture"; owner, 2026-10-22, #707: "So that all future decks can
  start adding them"). A deck can use `picture_ask` only once a release that
  reads it is out: the released parser rejects unknown fields.
- Closed groups (articles, pronouns, genders, cases and postpositions,
  demonstratives, question words, conjunctions, days, months, number words
  1-10, colours) need a set card that introduces the whole set, "Teach only"
  (owner, 2026-10-13, #506), and verb forms too (#515). Every deck that
  teaches such a group writes one: kind `set`, members by ref, its name
  and explanation in each layer (DECK-FORMAT, "Set cards"). It gives the
  learner the set's button after answering a member (owner, 2026-10-20).
- Model: Haiku writes decks, and Sonnet reviews them once (CLAUDE.md, owner, 2026-10-22). Haiku for large reads. Any tool or validator change is Sonnet (CLAUDE.md, owner, 2026-10-22).

## Checklist

1. **Pick the unit.** In `decks/<lang>/<lang>-path.yaml`, take the first
   `planned` unit in teaching order (list order), or the one you were asked
   for. A unit with `grammar` and no `theme` is a grammar unit: follow
   "Grammar units" below in place of steps 3 to 6 for words. Read its planned `id`, `theme` or `grammar`, `words`, and its
   `listening_passages` and `reading_passages` ("Paths", "The B1 plan"). The
   planned size is one number for every native language.
2. **Get ids.** `python3 tools/validate_decks.py --next-id <lang>` gives the
   next free card id of the language. Take ids from it and nothing else. A
   word another deck already teaches is listed by `ref`, not written twice
   ("A word in more than one deck: `ref`").
3. **Write the core and the English layer.**
   - Core: `decks/<lang>/<lang>-<name>.yaml`, `part: "core"` ("A core"). Only
     the language learnt: `target`, `reading` (letters *based on* ISO 15919;
     never write that it strictly follows it), `ipa`, `alt_target`, `pos`,
     `gender`, `picture`, `examples` (`target`, `reading`, `ipa`, `bases`,
     and `source` on one taken from outside, such as Tatoeba),
     `notes` (core form, with ids and `words`), `bases`, `rules`. No `native`.
     `python3 tools/transcribe.py <code> "<word>"` gives reading and IPA.
   - Layer: `decks/<lang>/en/<lang>-en-<name>.yaml`, `kind: "layer"`, keyed by
     card id ("A layer"): `native`, `alt_native`, note texts by note id,
     example translations by example target, base meanings, `wiktionary`, and
     the deck's `name` and `description`.
   - A sentence deck is `<lang>-<theme>-sentences` and names its `rules`; a
     rules deck is core and layer only ("Rules decks"). Reading decks stay
     single-file. See "Writing a B1 course", step 7, for what each part of a
     unit holds.
   - Every vocab and grammar deck is split (#498); only the reading decks
     (owner, 2026-10-14: "Keep reading decks single-file") and Japanese's
     `ja-en-hiragana` (owner, 2026-10-16: "Keep single-file") are single-file. To split a single-file deck, run
     `python3 tools/split_deck.py <file>` ("Splitting a deck"), never by
     hand. A language's script guide and sounds file are a core and an
     English layer too ("Script guides", "Sounds files").
4. **Content rules.**
   - Transliteration in deck prose: every non-Latin word in a note, meaning
     or description is followed by its reading ("Script in prose").
   - When a base word changes its stem in a card's form, say so in that
     card's notes ("Base words"). Every inflected word has a `bases` entry.
   - In a script written without spaces (Chinese, Japanese, Thai), every
     target and example gives its `words` in order ("Base words"):
     `["我", "听不懂"]`, Japanese particles as words of their own.
   - The meaning of a card never changes between layers or edits.
   - Tag the files `"unreviewed"`; a culture note needs a `source`
     ([docs/REVIEWING.md](../../../docs/REVIEWING.md) is how a speaker clears it).
   - Every word card gets at least one typed note ("Notes").
   - Use the `homograph` and `lookalike` note kinds (each with a `ref`) where a
     word shares its spelling with another, or differs only by a dot or mark,
     and a layer's `dictionary` (senses, etymology, `source`) for an entry
     imported from Wiktionary.
   - Set `warning` on a core card that has more than one warning (owner,
     2026-10-23: "Newly written decks will choose the order when building").
     It names the one warning the teach card shows: the `id` of a `pair`,
     `homograph` or `lookalike` note, `"senses"` for its other meanings, or
     `"none"`. Choose the one that matters most to the learner: a rude
     sound-alike only when it is very close (one IPA segment apart) and very
     rude, else a close sound-alike, a homograph or a one-mark look-alike,
     then further ones, then two or more other meanings, then a single one
     ("Which warning the teach card shows" in the Deck-Format wiki page;
     `tools/pick_warning.py` applies the same order). A card with none leaves
     it out. Released apps reject a card key they do not know, so a deck that
     sets `warning` waits for the release whose app reads it.
   - Every word card gets at least 2 examples ("Card data", "Examples"):
     natural sentences that use the word, each with its `reading` and `ipa`
     in the core and its translation in each layer, keyed by the target.
     The validator makes fewer than 2 an error only for a language in
     `FILLED_LANGUAGES` (`tools/validate_decks.py`); write 2 anyway. An
     example taken from outside names its own `source`; one written for the
     deck has none.
   - Every noun (`pos: "noun"`) in a language with gender gets its
     `gender`, one of the language's classes ("Card data", "Gender"): hi
     `"m"`/`"f"`; mr, gu, kn `"m"`/`"f"`/`"n"`; te `"mahat"`/`"amahat"`; es
     `"m"`/`"f"`. In bn, as and ja leave `gender` out. It goes on the core
     card, never in a layer. The validator checks nouns against the
     path's `genders`.
   - Card data, whenever it is available ("Card data"), on the core card
     with its text in each layer by id: a word that is its own root gets
     `bases: "self"`; `synonyms` and `antonyms` name a card by `ref`, or
     give the `word` and `reading` with its meaning in the layer;
     `confusables` (2 to 3 on a sentence put in order, none a tile the
     answer needs, each with its `kind` and a `why` in the layer);
     `register`; `forms` (a label in the layer for kind `other`);
     `collocations`; `senses` (each with its `native` in the layer). Data
     taken from outside names its `source` per item, and any item may
     give its `ipa` (a `word` only, never a `ref`). Never write
     `frequency` by hand: `tools/wikipedia_frequency.py` writes it (step 6).
   - A card's own `audio` and `image` ("A card's own recording", "A card's
     own image") come only from `tools/import_wiktionary.py --audio
     --images` (step 6), never by hand: an image on a card with a
     `picture`, or on a noun without one only once a reviewer approves the
     report's proposal (`--approve <card id>`); a recording only of exactly
     the card's text.
5. **Update the path.** Turn the planned unit into a written one exactly as
   "The B1 plan" says: `planned` becomes `decks` (core ids, ending in `"*"`)
   in the same change, keep `words` at least what the unit now counts, keep
   `grammar` and any `milestone`. Each deck's core id appears on the path
   once. A theme not in `decks/themes.yaml` is added there with the first deck
   ("Writing a B1 course", step 2); theme ids are permanent. The first layer
   folder of a language needs its `pubspec.yaml` line, in a commit of its
   own ("Splitting a deck").
6. **Fill from Wiktionary and Wikipedia** (semi-verified data, each item
   naming its source; `tools/README.md`). Once the cards are written, fill
   their empty fields from the language's kaikki.org extract
   (`https://kaikki.org/dictionary/<Language>/`), then read the report: it
   lists, card by card, what is still missing for you to write (a second
   example, antonyms, confusables), and nothing it adds changes a meaning.

   ```sh
   python3 tools/import_wiktionary.py <lang> <Language>.jsonl --dump-date <YYYY-MM-DD>
   python3 tools/import_wiktionary.py <lang> <Language>.jsonl --dump-date <YYYY-MM-DD> --write --report <lang>-report.md
   ```

   Add `--audio --images` where `ffmpeg` and the network are there. Images
   come from the word's Wiktionary page, then OpenMoji, never Wikidata. A
   noun, verb or adjective without a `picture` gets none: the report's
   "Image proposals" lists its candidate, and a reviewer approves each
   before it lands, as `--approve <card id>=<File name>` (the file is
   pinned; mail-bot approvals come with #519). Each item's
   `source` is its Wiktionary page only. With a
   Wikipedia dump of the language, write the ranks:

   ```sh
   python3 tools/wikipedia_frequency.py <lang> <lang>wiki-<date>-pages-articles.xml.bz2 --write
   ```
7. **Check.** CI runs the validator
   (`python3 tools/validate_decks.py decks/`); read its result, and fix every
   error and each warning or explain it. Do not run `tools/deck_index.py` or
   commit `decks/index.json`: a workflow regenerates it on main after the
   merge (owner, 2026-10-23). Tools details: `tools/README.md`.
8. **Ship.** Never create tags. For the owner's work, open a pull request
   (owner, 2026-10-16: "Do use PRs for everything"); a deck-only change
   needs only "Validate decks" and "Released app reads the decks" green
   (CLAUDE.md). Contributors open a pull request on a branch
   `deck/<name>` ([CONTRIBUTING.md](../../../CONTRIBUTING.md), AGENTS.md
   "Branches, commits, pull requests"). Get one independent review (Sonnet)
   before finishing (CLAUDE.md, "Which model does what"); no extra passes.
   Do not run the validator locally: push and read CI's result, ignoring
   checks irrelevant to a deck. Say what you verified.

## Grammar units

A planned unit such as `{ id: "mr-grammar-imperatives", grammar: "imperatives" }`
has no theme and no new words (`words` 0 or left out). It teaches a pattern
over words the course already teaches (owner, 2026-10-24: "Extend the
skill"). Steps 1, 2, 4, 5 (the path) and 7 to 8 apply as they are; steps 3 and
6 change as below. The forms are in DECK-FORMAT: "Grammar decks", "A
grammar core", "Rules decks", "Sentences and their rules", "Paths".

1. **Name.** The id is `<lang>-grammar-<topic>` and the topic is the
   `grammar` text: `mr-grammar-imperatives` teaches topic `imperatives`. Files:
   core `decks/<lang>/<lang>-grammar-<topic>.yaml`, layer
   `decks/<lang>/en/<lang>-en-grammar-<topic>.yaml` (`kind: "layer"`,
   `core:` the core's id). The planned id must not exist yet.
2. **Pick the kind.**
   - **`kind: "grammar"`**: a few chosen rows, each a lemma with its forms.
     Use it for a pattern over a small, fixed set (`tok-grammar-o-commands`,
     `mr-grammar-present`). Its path topic is the deck's name: `imperatives`.
   - **`kind: "rules"`**: the rows are every word of one `pos` the course
     teaches, with a rule id, name and explanation (`te-grammar-conditional`).
     Use it when the form is made for a whole class of words. Its path topics
     are its rule ids' names (`te-rule-conditional` is topic `conditional`),
     never the deck's own name once it has rules of another name. When the
     plan says nothing, take `grammar`; the plan's topic text decides which.
3. **Grammar core.** Header as a word core, `kind: "grammar"`, `tags:
   ["grammar", "unreviewed"]`, then `pattern` with `slots` (the columns,
   permanent in order) and `entries`. Each entry has a `lemma`, a `key` where the
   lemma is not `[a-z0-9-]+` (permanent), `reading`, `ipa`, and `forms` with a
   form for every slot (`null` for none), with `readings` (and `ipas`)
   for a script that needs them. A cell with two right forms lists both.
   Cell ids come from the core's id, the key and the slot's place, so never
   reorder slots. No `gloss`, `name`, `slot_name` or `prompt` in the core.
4. **Rules core.** `kind: "rules"`, `table` with `applies_to` (`pos`, `except`
   for words the rule does not cover), `slots`, and `rows` (`word` the card id
   of the vocab card, `forms`, `readings`); and `rules`, each with `id`
   `<lang>-rule-<name>`, the `slots` it makes (every slot in exactly one
   rule), and `words` its explanation quotes, `{ word, reading }`. **Every
   word of that `pos` that a B1 deck teaches gets a row**, or goes in
   `except`: the words of this unit and of every earlier one. A word of a
   later unit adds its row in the same change. A rule id is permanent.
5. **Words already taught only.** Every lemma, row `word`, form and example
   uses words a deck earlier on the path teaches. Look each up by its
   card id (`rg '"target": "<word>"' decks/<lang>`), take `ref` for it, and
   add a `bases` entry for any inflected form. Write no new word card:
   a word that is missing means the unit is planned too early; stop and say so.
6. **Layer.** For a grammar core: `pattern` with `name`, `slot_name`, `prompt`
   (`"{lemma} ({gloss}), {slot}"`), `slots` (a label for each slot, optional),
   `entries` (a gloss for **every** entry, by `key` or lemma) and `notes`, the one
   text shown after the answer: say what changes and when the base word changes
   its stem. For a rules core: `table` with `slot_name` and a label for
   **every** slot (the only placeholder is `{meaning}`; the word is never
   written into it), and `rules`, each id with a `name` and `explanation`
   (quote the rule's `words` as `{1}`, `{2}`; a non-Latin word is followed by
   its reading). A rule the layer leaves out is not taught. Both:
   `name`, `description` (ending "Not yet checked by a <Language> speaker:
   please report any mistake."), `tags`, `license`, `native`.
7. **Sentences.** Where the unit has sentences, write a vocab core
   `<lang>-grammar-<topic>-sentences` and its layer: `pos: "phrase"`, `bases`
   (by `ref`) for every word, `confusables`, and on a sentence that uses a
   rule `rules: ["<lang>-rule-<name>"]`. Ids from `--next-id`.
8. **The path.** Turn `planned` into `decks` in the same change, keeping
   `grammar` and any `milestone`, and keep `listening_passages` and
   `reading_passages`. List the core ids only: `decks: ["mr-grammar-imperatives",
   "mr-grammar-imperatives-sentences"]`, then `words: 0` and
   `grammar: ["imperatives"]`. The core is listed once on the path.

**Worked example,** `tok-grammar-o-commands` (the real deck, shortened).
Path (`decks/tok/tok-path.yaml`):

```yaml
  - decks: ["tok-grammar-o", "tok-grammar-o-commands", "tok-grammar-o-address", "tok-grammar-o-sentences", "tok-reading-o"]
    words: 1
    grammar: ["o-commands", "o-address"]
```

Core `decks/tok/tok-grammar-o-commands.yaml`:

```yaml
schema: 1
id: "tok-grammar-o-commands"
part: "core"
kind: "grammar"
language: { code: "tok", iso639_3: "tok", name: "Toki Pona", script: "latin", icon: "Tp" }
license: "CC-BY-SA-4.0"
tags: ["beginner", "grammar", "unreviewed"]
pattern:
  slots: ["statement", "command"]
  entries:
    - lemma: "pali"
      forms:
        "statement": "sina pali"
        "command": "o pali!"
```

Layer `decks/tok/en/tok-en-grammar-o-commands.yaml`:

```yaml
schema: 1
id: "tok-en-grammar-o-commands"
kind: "layer"
core: "tok-grammar-o-commands"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Commands with o"
pattern:
  name: "Commands with o"
  slot_name: "form"
  prompt: "{lemma} ({gloss}), {slot}"
  slots: { "statement": "a statement (you do it)", "command": "a command (do it!)" }
  entries:
    "pali": "to make; to work"
  notes: "Sina pali is you work. O pali! is Work! The command drops the subject and puts o first."
```

The core id is `tok-grammar-o-commands`, so the topic is `o-commands`; the
cell ids are `tok-grammar-o-commands-pali-0` and `-1`. A rules example
is `te-grammar-conditional` and its layer, with the topic `conditional`.

**Validator errors to expect** (CI reads them; do not run it):

- Topic: `'x' is taught by none of the unit's decks` (the `grammar` text is
  neither a rule's name nor a listed `<lang>-grammar-x`); `names the rules
  deck ...; its topics are its rules` (use a rule name).
- Planned: `planned.id: ... already exists` (list it under `decks`);
  `lists ..., a deck of the <lang>-<native> course` (list the core id).
- Rules core: `no vocab deck writes card <id>`; `<id> is a <pos>, not one of
  ...`; `<id> has no reading` (script needs one); `<id> ... has no row; add
  its forms, or list it in applies_to.except`; `<slot> belongs to no rule`;
  `is also in rule` (slot in two rules); `rules names <id>, which no rules
  deck of <lang> defines` (a sentence's `rules`); a rule id not
  `<lang>-rule-<name>`.
- Grammar layer: `gives no gloss for <key>`; a slot label for a key that is
  not a slot; a rules layer with a label for every slot missing, or a
  placeholder other than `{meaning}`.
- Quoting: an unquoted key such as `yes`, `no` or `on` is a boolean; quote
  every slot key.
- Warnings to clear or explain: a row with one form only; a unit with more
  words than `words`; a word in a text covered by no card or base.

## Chinese, Japanese and Korean

Pattern decisions from the first batches (owner, 2026-10-24: "Sonnet writes
the first batch per language, Haiku follows"): zh grammar units shi,
questions and word order (#813), ja and ko sound-differences and questions
units (#814, #815). Copy them: `decks/zh/zh-grammar-shi.yaml`,
`decks/ja/ja-sound-differences.yaml`, `decks/ko/ko-questions.yaml`.

**All three**

- **Readings are "based on" a standard**: pinyin with tone marks (Hanyu
  Pinyin), Hepburn without macrons (`ja-romanisation.yaml`: long vowels
  `ou`, `oo`, `uu`, `ii`, `aa`; を is `wo`), Revised Romanization. Never
  say a reading strictly follows one.
- **Prose rule bites twice.** Every Han, kana or hangul word in a note, a
  `why`, a gloss or a question carries its reading, **including a wrong form
  you quote** ("never 我是忙 (wǒ shì máng)"): CI errors on one without.
- **Words already taught, only.** Check a lemma, form or sentence word by
  its card id. A word that is not a card goes in `bases` written in full, with
  its base, reading and (in the layer) meaning. A word that has a card, once
  you write it later, becomes a `ref`: when a unit writes どこ, いくら,
  얼마예요 or 뭐예요, change the earlier phrasebook and first-words bases to
  `{ word, ref }` in the same PR and delete their meaning lines in the layer.
- **A card cannot `ref` itself.** In its own examples, a particle form
  (달이, 물が) names its base in full. Give a repeated word's base once per text.
- **Sentences decks** (`<lang>-<theme>-sentences`, `pos: "phrase"`) give 2 to 3
  `confusables` each, `kind: "word"` or `"sound"`, none a word of the
  sentence, each with a `why` in the layer; a confusable that is no card is a
  `word` with its `reading`.
- **Reading decks stay single-file** (`<lang>-en-reading-<name>.yaml`, listed
  as `<lang>-reading-<name>`), 2 passages of 4 short lines and 3 questions
  each, question ids from `--next-id`. Word units also get the set card for
  a closed group (question words). A grammar unit keeps its planned
  passages and writes no reading deck.
- **`warning`** goes on every word card with a `pair` note, naming the note's
  id; a card with two partners (a triple) takes the pick of
  `tools/pick_warning.py` (`pick_warning.pick(card, index)` gives it without
  writing files).
- No pictures: a picture needs its emoji in `assets/pictures/`, and the
  question words' `picture_ask` waits for the owner (open question).

**Chinese** (script `han_simplified`, `scripts` also traditional)

- Written without spaces: `words` on every card, sentence and example, joined
  they equal the target without punctuation; compounds the course has no card
  for are one word with a `base` (听不懂, 喜不喜欢 as one word with `ref`).
- Readings show the tone **as said**: 不 is `bú` before a fourth tone, `bù`
  before the others; the 不 in 是不是 or 去不去 is neutral (`shì bu shì`).
  Third-tone sandhi is not written, as in the existing decks.
- Measure words come with their own unit (planned); do not use one in a grammar
  unit before it.
- A grammar unit has **one deck per topic** (`zh-grammar-shi` and
  `zh-grammar-bu-negation` for `["shi", "bu-negation"]`), each a `kind:
  "grammar"` table: lemma = the verb, noun or question word, one slot per
  form; for sentence tables put the whole sentence in each `forms` cell and
  say in the layer's gloss which sentence it is ("to go: I go to school").
  Add a sentences deck with confusables.

**Japanese** (script `kana`)

- Targets are in **hiragana** until the kanji units; katakana only where the
  phrasebook already has it. Particles are words of their own: `["わたし",
  "は", "せんせい", "です"]`; set phrases stay whole. The hiragana letters
  are not word cards: は, の, に still get a `base` entry (`は` reading `wa`).
- `ipa` from `tools/transcribe.py ja`, word by word, joined by spaces.
- Long vowels, double consonants and the voiced mark are the A1 contrasts:
  `ja-sounds.yaml` lists them as kana pairs (an empty side for a vowel or っ
  added). Tag each card with its contrast; a te-form (きて) names its base
  (くる) and says in a note that the stem changes.
- Particles and polite forms are taught by their own planned units; examples
  may use です, か, は, の, に, が, を, と and ください as bases only.

**Korean** (script `hangul`)

- Words are separated by spaces, with the particle joined (물이): each such
  word names its base (`ref` on another card, `base` in full on its own).
  The first verb forms are polite `-요`. Avoid, for now, stems that change
  their first letter (크다, 커요), which the validator warns of.
- No `ipa` in the existing Korean cards: do not add one by hand.
  `tools/transcribe.py ko` gives the reading of a whole sentence.
- Sound contrasts (plain, tense, aspirated) are listed in `ko-sounds.yaml` as
  syllable pairs of the deck's words, since a recogniser returns syllables.
- Honorifics (선생님, 저, 요 and 세요) are taught in the first words and the
  addressing unit; keep examples in the polite style.
