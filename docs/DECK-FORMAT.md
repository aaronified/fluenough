# Deck format, schema 1

A deck is a single UTF-8 YAML file. Filenames are `<deck-id>.yaml` and live
under `decks/<language-code>/`.

Three kinds of deck exist: `vocab` (a list of cards), `grammar` (a pattern
table that expands into cards) and `reading` (passages with questions about
them). Another kind of file, `facts`, holds a language's daily facts rather
than anything drilled. All four share the same header. Beside them sit files that are not decks: the shared
[themes](#themes), each language's [number rules](#number-rules), and each
course's [path](#course-paths).

Validate before committing:

```sh
python3 tools/validate_decks.py decks/
```

---

## Header

Common to every kind.

| Field | Required | Notes |
|---|---|---|
| `schema` | yes | Must be `1`. |
| `id` | yes | Unique, `[a-z0-9-]+`, must equal the filename stem. A vocab or grammar deck's id starts with the language learned and then the language it is taught from: `hi-en-market` is Hindi from English. A facts file is about one language: `hi-facts`. |
| `name` | yes | Human-readable title. |
| `kind` | no | `vocab` (default), `grammar`, `reading` for [passages](#reading-decks), or `facts` for a [facts file](#facts-files). The files beside the decks have their own: `themes`, `numbers`, `path`, `sounds` and `script`. |
| `language` | yes | The language being learned. See below. |
| `native` | yes, except on a facts file | The language explanations are written in. |
| `license` | yes | SPDX identifier, or `CC0-1.0` for public domain. |
| `authors` | no | List of `{name, url?}`. |
| `source` | no | Where the content comes from: a URL, or for a book its title, author, year and licence, as in `"Sahaj Path, part 1, by Rabindranath Tagore (1930), in the public domain"`. The app shows it on the deck's page, and Settings lists it under Sources. |
| `description` | no | One or two sentences. |
| `tags` | no | Deck-level tags, e.g. `[beginner, core]`. The tag `unreviewed` marks a deck no native speaker has checked: the app says so on the deck's screen. |
| `theme` | no | On a vocab deck: the theme it teaches, by its id in [`decks/themes.yaml`](#themes). |

### `language`

| Field | Required | Notes |
|---|---|---|
| `code` | yes | BCP-47 primary subtag, e.g. `es`, `ja`, `pt`. This is the tag voices and the app key on. |
| `iso639_3` | yes | Three-letter ISO 639-3 code, e.g. `spa`, `jpn`, `hin`, `eng`. It names the language unambiguously, including languages with no two-letter code, and sits beside `code` rather than replacing it. |
| `name` | yes | English name of the language. |
| `script` | yes | A lowercase script name. The validator knows `latin`, `cyrillic`, `greek`, `arabic`, `hebrew`, `devanagari`, `bengali`, `gujarati`, `gurmukhi`, `odia`, `telugu`, `tamil`, `kannada`, `malayalam`, `sinhala`, `kana`, `han`, `hangul`, `thai` and `other`. Any other name is accepted with a warning ([ADR-0009](adr/0009-scripts-are-open.md)). Every script but `latin`, `cyrillic` and `greek` expects a `reading` on each card. |
| `tts` | no | BCP-47 tag handed to the TTS engine, e.g. `es-ES`, `pt-BR`. Defaults to `code`. Omitting it on a language with major regional variation is a mistake. |
| `rtl` | no | `true` for right-to-left scripts. Defaults to `false`. |

### `native`

`{code, iso639_3, name}` — same meaning, for the learner's own language. Every
language named anywhere, learned or native, carries its ISO 639-3 code.

---

## Vocab decks

```yaml
schema: 1
id: es-en-core-100
name: Spanish Core 100
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [beginner, core]
cards:
  - id: es-0001
    target: la casa
    native: the house
    pos: noun
    tags: [noun, home]
```

### Card fields

| Field | Required | Notes |
|---|---|---|
| `id` | yes | The language learned and a number, `es-0001`: unique in the language, across every deck and course. **Never reuse or renumber** — review history is keyed on it. |
| `target` | yes | The text in the language being learned. |
| `native` | yes | The meaning, in the learner's language. |
| `reading` | no | Romanisation, as the language's [romanisation file](#romanisation) says: for the Indic languages, ISO 15919 letters as the word is said. Required in practice for non-Latin scripts. |
| `ipa` | no | How the word is said, in the IPA: broad, without the slashes, which the app adds, as `"paːlu"` ([ADR-0025](adr/0025-iso-15919-and-ipa.md)). `tools/transcribe.py` writes one. |
| `alt_target` | no | Additional answers accepted in production drills. |
| `alt_native` | no | Additional answers accepted in recognition drills. |
| `pos` | no | Part of speech: `noun`, `verb`, `adj`, `adv`, `phrase`, `particle`, `other`. |
| `gender` | no | Grammatical gender, free text (`m`, `f`, `n`, `c`…). |
| `tags` | no | Card-level tags. Drills can be filtered by tag. |
| `notes` | no | Usage note shown after answering. |
| `audio` | no | Asset path or URL overriding TTS for this card. |
| `examples` | no | List of `{target, native}` sentence pairs. An example may also give its `reading` and `ipa`. |
| `modes` | no | Which drills this card participates in. Defaults to all applicable, except that a `pos: phrase` card is not typed: it defaults to recognition, listening and speaking, and production by rearranging its words when it has two or more (ADR-0024). |

### A note on `id`

Card ids are the primary key of the user's entire review history. Changing an
id orphans that card's history; reusing one silently attaches old history to
new content. Treat ids as immutable once published. To retire a card, delete
it — do not repurpose it.

An id names the language, not the deck or the course
([ADR-0018](adr/0018-card-ids-name-the-language.md)). Numbers are shared by
every deck of the language, so take the next free one:

```sh
python3 tools/validate_decks.py --next-id es
```

### A word in more than one deck: `ref`

A word is one card, written once. Another deck that teaches it lists it by
its id, and the learner has one schedule for it, whichever deck they meet it
in, and whichever language they learn it from:

```yaml
cards:
  - ref: es-0001
    notes: "In this deck: the house you live in."
```

A ref may give the card's native side for this deck: `native`, `alt_native`,
`reading`, `notes`, `tags`, `examples` and `modes`. What the card is in the
language learned, its `target`, `alt_target`, `pos`, `gender` and `audio`,
stays where it is written.

- **The same native language:** what the ref does not give comes from the
  card.
- **Another native language,** say an `es-bn` deck listing a card written in
  an `es-en` one: the ref gives its own `native`. The card's `notes`, `tags`,
  `alt_native` and `examples`, written for English speakers, do not come
  across; its `reading` and `modes`, which belong to the word, do unless the
  ref gives its own.
- The validator checks that each ref names a card written in another deck
  of the language, and that no card is written twice.

---

## Grammar decks

A grammar deck describes an inflection table and expands into one production
card per cell. This keeps the app free of per-language grammar logic.

```yaml
schema: 1
id: es-en-grammar-present-ar
name: Spanish present tense, regular -ar verbs
kind: grammar
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
pattern:
  name: Present tense, regular -ar verbs
  slot_name: person
  slots: [yo, tú, él/ella, nosotros, vosotros, ellos]
  prompt: "{lemma} ({gloss}) — {slot}"
  entries:
    - lemma: hablar
      gloss: to speak
      forms:
        yo: hablo
        tú: hablas
        él/ella: habla
        nosotros: hablamos
        vosotros: habláis
        ellos: hablan
```

### `pattern` fields

| Field | Required | Notes |
|---|---|---|
| `name` | yes | Describes the inflection. |
| `slot_name` | yes | What the slots are: `person`, `case`, `tense`, `number`… |
| `slots` | yes | Ordered list of slot labels. |
| `prompt` | yes | Template. `{lemma}`, `{gloss}` and `{slot}` are substituted. |
| `entries` | yes | List of `{lemma, gloss, forms}`, each with an optional `key`, and in a script that needs them `reading` and `readings`. Each may give `ipa`, the lemma in the IPA, and `ipas`, the form shown in each slot in the IPA, one per slot that has a form. |
| `notes` | no | Shown after answering. |

`forms` must supply a key for every slot. A cell with no valid form (a
defective verb, say) may be `null` and is skipped rather than drilled. A cell
with more than one right form lists them: the first is shown, and every one
is accepted (#144).

```yaml
      forms:
        "আমি / আমরা": ["এলাম", "আসলাম"]   # two forms, both accepted
```

### Entry keys

A lemma goes into every card id its row expands to, and card ids are
lowercase ASCII. A lemma that is not, such as Hindi जाना, needs a `key`: an
ASCII name for the row, used in the ids in its place. The drill still shows
the lemma. The validator requires a `key` whenever the lemma is not
`[a-z0-9-]+`, and like a card id, **a key is permanent**.

```yaml
  entries:
    - lemma: "जाना"
      key: jaanaa
      gloss: "to go"
      forms: { ... }
```

### A table that varies in more than one way

The slots are one list. A form that varies by person and gender together,
like the Hindi past tense, has one slot per combination: `"मैं (m)"`,
`"मैं (f)"`, and so on.

### Expansion

Each `(entry, slot)` pair becomes one production card:

- **id** — `<language>-<deck name>-<key>-<slot-index>`, where the deck name
  is the deck id without its course: `es-en-grammar-present-ar` expands to
  `es-grammar-present-ar-hablar-0`, and so would the same table in a deck
  taught from another language (ADR-0018). It is stable as long as `slots`
  keeps its order and the key is unchanged. The key is the entry's `key`,
  or its `lemma` when it has none. **Reordering `slots` rewrites every id in
  the deck and orphans its history.** Append new slots at the end.
- **target** — `forms[slot]`, the first form where a cell lists several, and
  **alt_target** the rest
- **native** — `prompt` with substitutions applied
- **modes** — `grammar` only

---

## Reading decks

Short passages, each with questions about it (#98,
[ADR-0019](adr/0019-reading-comprehension.md)). The learner reads a
passage, or hears it read aloud, and answers its questions by choosing.
Each question is scheduled like a card, in the `reading` mode, and heard in
`listening` where the phone has a voice.

```yaml
schema: 1
id: bn-en-reading-home
name: "Bengali reading: going home"
kind: reading
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
source: "Written for this example"
passages:
  - id: bn-going-home
    title: "Going home"
    theme: market
    sentences:
      - text: "সে কাজ ক’রে বাড়ি যায়।"
        reading: "she kaj kore bari jay."
      - text: "বাড়িতে সে ভাত খায়।"
        reading: "barite she bhat khay."
    glossary:
      - word: "ক’রে"
        modern: "করে"
        reading: "kore"
        meaning: { en: "having done" }
        note: { en: "older spelling; the apostrophe marks a dropped ই" }
    questions:
      - id: bn-0901
        prompt:
          en: "They eat rice at home."
          hi: "वे घर पर चावल खाते हैं।"
        answer: true
      - id: bn-0902
        prompt: { en: "Where do they go after work?" }
        options:
          - { en: "Home" }
          - { en: "To the market" }
        answer: 1
```

A reading deck has the usual header, with `passages` in place of `cards`,
and no `theme` of its own: each passage names the theme it follows.

### Passage fields

| Field | Required | Notes |
|---|---|---|
| `id` | yes | The language and a name, `bn-going-home`: unique in the deck among its passages and questions. Permanent. |
| `title` | yes | The passage's name, in the language the deck is taught from, as the deck's `name` is. |
| `sentences` | yes | A non-empty list of sentences, below. |
| `questions` | yes | 2 to 4 questions, below. |
| `source` | no | Where this passage comes from, shown with it on every screen of the drill and on the deck's page. Without one, the deck's `source` is shown. |
| `theme` | no | The theme whose words it uses, by its id in [`decks/themes.yaml`](#themes). |
| `glossary` | no | Older or unusual words in it, below. |

### Sentences

| Field | Required | Notes |
|---|---|---|
| `text` | yes | The sentence in the language learned, exactly as written. Quote it. |
| `reading` | yes, in a script that needs one | Its romanisation, written as [`decks/README.md`](../decks/README.md) says. Shown when Show romanisation is on. |
| `ipa` | no | How it is said, in the IPA, without punctuation or slashes. |

**A passage's text is kept letter for letter.** Passages may quote a book,
so nothing in the app or the validator trims, normalises or corrects
`text`, a glossary's `word` or `modern`, or their readings: no Unicode
normalisation, and no straightening of ’ or ‘. Write the text exactly as
the source has it. The validator only warns of leading or trailing spaces,
which are kept.

### Questions

| Field | Required | Notes |
|---|---|---|
| `id` | yes | A card id of the language, `bn-0901` ([ADR-0018](adr/0018-card-ids-name-the-language.md)): a question is a card. **Never reuse or renumber**: it keys the question's review history. |
| `prompt` | yes | The question, or for true or false the statement, keyed by language code as a [fact's](#fact-fields) `text` is: `{ en: ..., bn: ..., hi: ... }`. `en` is required. |
| `options` | no | 2 to 4 choices, each keyed by language like `prompt` and in exactly its languages. Leave it out for a true-or-false question. |
| `answer` | yes | The number of the right option, counting from 1. For a true-or-false question, `true` or `false`, unquoted. |

A question is shown in the best language the learner speaks that it is
written in, as facts are (#53), else in English. Its true and false are the
app's own words.

### Glossary

Older Bengali, in its sadhu and chalit forms, reads differently from the
language the decks teach. A glossary gives today's form of a passage's
older or unusual words. The drill opens it from Words, wherever the
passage's text shows.

| Field | Required | Notes |
|---|---|---|
| `word` | yes | The word exactly as the passage writes it. It must occur in the passage's sentences, character for character. |
| `modern` | yes | Today's standard colloquial form. |
| `reading` | yes, in a script that needs one | `modern` in the Latin alphabet, as in a sentence's `reading`. |
| `ipa` | no | `modern` in the IPA. |
| `meaning` | yes | What it means, keyed by language, `en` required. |
| `note` | no | More about it, keyed by language, `en` required: "older colloquial; the apostrophe marks a dropped ই". |

### Rules

- **On its course's path, after its theme.** A reading deck is an ordinary
  deck: it is listed on the Decks tab, and its path puts it in a unit after
  the theme decks its passages use, so that its new questions come once
  their words are taught. The validator warns of a passage whose theme's
  deck is in the same unit or a later one.
- **Words no deck teaches are warned of.** Validating a course's decks
  together, the validator lists each passage's words that no vocab or
  grammar deck of the course contains, its glossary's aside. This is a
  warning, not an error: a passage has inflected forms and names.
- **The validator checks the rest:** ids unique and well formed, 2 to 4
  questions and options, an answer that is an option or true or false,
  `en` in every text keyed by language, a reading on every sentence in a
  script that needs one, and every glossary word in its passage.

---

## Themes

Vocabulary is taught along one shared path of themes, like the units of a
course ([ADR-0010](adr/0010-themes.md)). `decks/themes.yaml` lists them, in
order:

```yaml
schema: 1
kind: themes
themes:
  - { id: first-words, name: "First words" }
  - { id: market, name: "Market" }
```

A theme deck is an ordinary vocab deck with a `theme`, and its id is the
course plus the theme: `hi-en-market` is Hindi from English, Market. Every
language teaches the themes in the same order, with its own words. A course
need not have a deck for every theme yet: Bengali has Family, Work, Home and
A day, and Hindi and Telugu do not.

- **Theme ids are permanent**, like card ids: decks name their theme by it.
- **One deck per theme per course.** The validator fails a second
  `hi-en` deck for `market`, and a `theme` that `themes.yaml` does not list.
- **New cards follow the path.** A course's theme decks are drilled in the
  file's order unless the learner picks a theme. Nothing is locked. A
  course with a [path](#course-paths) is ordered by that instead.
- **Phrases are not typed.** Mark a card of more than one word `pos: phrase`:
  a whole sentence is too hard to grade fairly when typed, so it is
  produced by putting its words in order instead (ADR-0024). Any card of
  three words or more is produced that way too.
- **Grammar decks are not themes.** A course's path places them beside the
  theme decks they go with.

## Course paths

A course is taught along a curated path ([ADR-0013](adr/0013-course-paths.md)):
its decks in teaching order, in **units**. `decks/hi/hi-en-path.yaml` is
Hindi from English:

```yaml
schema: 1
kind: path
id: hi-en-path
language: hi
native: en
units:
  - [hi-en-first-words, hi-en-grammar-sentences, "*"]
  - [hi-en-questions, hi-en-grammar-questions, "*"]
  - [hi-en-addressing, hi-en-grammar-pronouns, "*"]
  - ["*"]
```

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `<language>-<native>-path`, and the filename stem. |
| `language` | yes | The code of the language learned, such as `hi`. |
| `native` | yes | The code of the language it is taught from, such as `en`. |
| `units` | yes | A non-empty list. Each unit is a non-empty list of deck ids, which may end in the wildcard `"*"`. |
| `alphabet` | no | The decks that need the alphabet: the script, spelling and reading decks. Each must be on the path. A learner who learns the language without its alphabet is not taught them. |
| `description` | no | Free text. |

- **A unit is what is taught together**: a theme deck and the grammar that
  goes with it, or a script. Today takes new cards from the first unit not
  yet finished and the one after it, mixing the two, and placement passes
  or places a unit whole (ADR-0013), so keep a unit to what a learner would
  take in together.
- **Every deck of the course is on its path, exactly once,** and only the
  course's decks. The validator fails a deck left out, one listed twice, one
  from another course, and an id that is no deck. Adding a deck means adding
  it to its course's path.
- **One path per course,** and every course with a deck in `decks/` has
  one: the validator fails a course without. A deck added in the app to a
  course with no path is taught in its course's theme order, and then its
  other decks.
- **The wildcard `"*"` takes decks the path does not list,** such as a deck
  a learner adds in the app ([ADR-0020](adr/0020-added-decks.md)). Quote
  it: a bare `*` is YAML for an alias. It may only end a unit, and a unit
  of `"*"` alone may only be the last. A deck the path does not list goes
  at the bottom of the first unit ending in `"*"` that holds a theme deck
  of its theme, and otherwise into the unit of `"*"` alone, at the end of
  the course. So a unit ending in `"*"` needs a theme deck, which the
  validator checks. Every bundled path ends each unit that has a theme deck
  in `"*"`, and has a last unit of `"*"` alone.
- **Order is a teaching decision.** Grammar goes with the theme that first
  needs it, and a [reading deck](#reading-decks) in a unit after the themes
  it uses.
- **A course opens with words, not letters.** Its first units are a few
  words and basic sentences, the sounds English lacks and how the grammar
  differs from English, then five more themes; the script comes after
  those six themes, before the rest. Until the learner is past the script
  units, answers typed in Latin letters count in full (ADR-0022), and
  readings show beside the script. The sound and grammar units are typed
  too: their short sentences leave out `pos: phrase`. A letter
  that sounds exactly like another, such as Bengali ন and ণ, or whose
  sound a recogniser writes another way (ঋ is written রি), is drilled by
  reading and writing only (`modes: [recognition, production]`), since no
  ear and no recogniser can tell them apart; so is a mark that is not a
  sound of its own, written on a host letter (কং).

## Adding your own deck

In the app, Decks > Add a deck > From a file saves a template,
[`assets/deck-template.yaml`](../assets/deck-template.yaml), and adds a deck
written from it. It is a [vocab deck](#vocab-decks) like any other, and any
deck the app can read can be added, grammar and reading decks too. The app
checks it first, and refuses:

- a file that is not a deck, or that does not parse: the file, line and
  message are shown, as for a bundled deck;
- the id of a deck that comes with the app;
- a card id that another deck has. Write `<language>-my-NNNN`, which no
  bundled deck uses, and list a word another deck has by `ref`.

Adding a deck with the id of one added before replaces it. Its `theme` puts
it at the bottom of that theme's unit, through the path's wildcards; a deck
with no theme, or one the course does not have, goes at the end. An added
deck can be removed from its page; what was learned from it stays.

## Romanisation

Every `reading` in a language with its own script is written in one scheme
per language, so that a learner sees the same spelling everywhere (#47). For
the Indic languages the scheme is **ISO 15919's letters, spelled as the word
is said** ([ADR-0025](adr/0025-iso-15919-and-ipa.md)); the
[README](../README.md#how-words-are-written-in-latin-letters-iso-15919) has
the table.

- Lowercase ISO 15919 letters, with spaces and the sentence's own
  punctuation: ā ī ū ē ō for long vowels, ṭ ḍ ṇ ḷ for the retroflex
  consonants, ś ṣ ṅ ñ, ṛ for ड़, ṁ for an anusvara that nasalises, m̐ for a
  nasal vowel. Composed letters (NFC), no capitals.
- Spelled as the word is said, not letter for letter: Hindi, Marathi and
  Gujarati leave out the inherent vowel where speakers do (*kitnā*,
  *samajh*); Bengali and Assamese write it as the *ô* or *o* it is said as
  (*kôthā*). A letter said as another is written as that one: Bengali ঈ is
  *i*, Assamese স is *x*, an anusvara is the nasal said (*aṇḍā*).
- Length is marked where the language says it long: Hindi, Telugu and
  Kannada mark ī and ū; Bengali, Assamese, Marathi and Gujarati, which say
  the two alike, do not.
- A letter card for ङ or ञ on its own reads *ṅa* or *ña*.
- A grammar row whose lemma is English, such as a demonstratives table's
  "this, that", has no `reading`; its forms do.
- Each language's romanisation file says its own conventions in its
  `scheme`. `tools/transcribe.py <code> "<word>" <as typed>` writes a
  reading and IPA, taking the word as people type it as the hint to what is
  said.

A typed answer never needs the marks: they are folded away, and the file's
`typed` list spells each reading as people type it before an answer is
compared with it, so *palu*, *paalu* and *pālu* are all right for పాలు.

A grammar row gives its lemma's `reading` and a `readings` map beside
`forms`, a reading per slot that has a form, or a list of them for a cell
that lists several forms, and an `ipas` map, the form shown in each slot in
the IPA:

```yaml
    - lemma: "जाना"
      key: jaanaa
      reading: "jānā"
      ipa: "dʒaːnaː"
      gloss: "to go"
      forms:
        "मैं (m)": "जाता हूँ"
        "तुम (m)": "जाते हो"
      readings:
        "मैं (m)": "jātā hūm̐"
        "तुम (m)": "jātē hō"
      ipas:
        "मैं (m)": "dʒaːt̪aː ɦũː"
        "तुम (m)": "dʒaːt̪eː ɦoː"
```

### Romanisation files

`decks/<code>/<code>-romanisation.yaml` names the scheme and the spellings a
learner may type for the same sound, which grading treats as one:

```yaml
schema: 1
kind: romanisation
id: hi-romanisation
language: hi
scheme: "ISO 15919 letters, spelled as said: …"
standard: "ISO 15919"
typed:
  - ["ch", "chh"]
  - ["c", "ch"]
  - ["ś", "sh"]
  - ["m̐", "n"]
equivalents:
  - ["i", "ee", "ii"]
  - ["u", "oo", "uu"]
  - ["v", "w"]
```

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `<code>-romanisation`, and the filename stem. |
| `language` | yes | The language's code. |
| `scheme` | yes | How the language is romanised, in a paragraph, with its own conventions. |
| `standard` | no | `"ISO 15919"` when the readings use its letters. Without it, readings are lowercase ASCII. |
| `typed` | no, and only with `standard` | Pairs of the standard's letters and how they are typed: `["ś", "sh"]`. Each reading is spelled so, read from the left, the longest letters first, before an answer is compared with it. An empty second item means the letters are not typed, as Assamese chat leaves out m̐. |
| `equivalents` | yes | Groups of two or more lowercase spellings. The first of each group is the one the decks use. A spelling is in one group only. |

Once a language has the file, the validator checks every reading in that
language's files, cards, refs, grammar rows, passages, glossaries, sounds and
script guides, is in the scheme: lowercase, no capitals, and no diacritics
but ISO 15919's letters where the file names that standard. It checks every
`ipa` anywhere is broad IPA without slashes.

## Sounds files

A language's sound contrasts ([ADR-0015](adr/0015-sound-contrasts.md)):
the pairs of sounds it tells apart and English doesn't, and how each is
written. When a spoken answer is wrong and the word heard is the answer
with one pair swapped, the speaking drill names the contrast.
`decks/bn/bn-sounds.yaml`:

```yaml
schema: 1
kind: sounds
id: bn-sounds
language: bn
contrasts:
  - id: aspiration
    name: "a breath after the consonant"
    pairs: [["ক", "খ"], ["ব", "ভ"]]
  - id: inherent-vowel
    name: "the open o against a"
    within_word: true
    pairs: [["", "া"]]
```

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `<language>-sounds`, and the filename stem. |
| `language` | yes | The code of the language, which is also its folder. |
| `contrasts` | yes | A non-empty list. |
| `description` | no | Free text. |

Each contrast:

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `[a-z0-9-]+`, unique in the file. A sound-differences deck tags each minimal pair with it. |
| `name` | yes | Completes "The difference is …", in the learner's language. |
| `pairs` | yes | A non-empty list of two different quoted strings, letters or signs, at most one of them empty (a sign there or not). |
| `within_word` | no | `true`: a sign added or taken away counts only inside a word, for a language that drops a word's final vowel (Bengali, Hindi), where a vowel sign added at the end adds a syllable. Swaps always count. |

## Script guides

How a script works, before its letters ([ADR-0016](adr/0016-script-guides.md)):
the features a learner from English misses because their own script has
nothing like them. The drill shows the guide once, before a language's
first script card; a session with two such languages shows both guides,
in the order it reaches them. A script deck's Tips opens it again.
`decks/bn/bn-script.yaml`:

```yaml
schema: 1
kind: script
id: bn-script
language: bn
name: "How Bengali script works"
intro: "A few ideas come back in letter after letter."
features:
  - id: headline
    name: "The headline"
    term: "মাত্রা"
    reading: "matra"
    example: "ক"
    text: "Most letters hang from a line along the top."
    letters: ["ক", "ঘ", "ত", "ন"]
```

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `<language>-script`, and the filename stem. |
| `language` | yes | The code of the language, which is also its folder. |
| `name` | yes | The page's title. |
| `intro` | yes | A paragraph before the features. |
| `features` | yes | A non-empty list. |

Each feature:

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `[a-z0-9-]+`, unique in the guide. |
| `name` | yes | The feature in plain English. |
| `term` | no | Its name in the language: `"মাত্রা"`. |
| `reading` | no | The term in the Latin alphabet, shown under it when Show romanisation is on. Only with a `term`. |
| `ipa` | no | The term in the IPA. Only with a `term`. |
| `example` | yes | One letter or short word that shows it, drawn large. |
| `text` | yes | What to look for, for a beginner from English. |
| `letters` | no | More letters that share it, each quoted. |

## Facts files

One short, true and surprising thing about the language, shown to the learner
once a day. Each language has one facts file, `decks/<code>/<code>-facts.yaml`,
beside its decks:

```yaml
schema: 1
id: hi-facts
name: Hindi facts
kind: facts
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
license: CC0-1.0
facts:
  - id: hi-fact-001
    tags: [script]
    text:
      en: "No Hindi word begins with ड़ or ढ़. These dotted letters only occur
        inside or at the end of a word, as in सड़क (sarak, road) and पढ़ना
        (parhna, to read)."
  - id: hi-fact-002
    tags: [script, conjuncts]
    text:
      en: "Two consonants with no vowel between them join into one conjunct
        (संयुक्ताक्षर, sanyuktakshar): क + ष = क्ष, त + र = त्र, ज + ञ = ज्ञ. Some
        look nothing like the letters they are made of."
  # ...at least 30 facts without a contrast...
  - id: hi-fact-101
    contrast: en
    tags: [pronunciation]
    text:
      en: "English writes the sh sound with two letters. Hindi gives it letters
        of its own, श and ष (most speakers now say them alike), so 'sh' in a
        romanisation stands for one sound, not s followed by h."
  - id: hi-fact-102
    contrast: bn
    tags: [pronunciation]
    text:
      bn: "হিন্দিতে স সবসময় 's' — বাংলার মতো 'শ' নয়।"
```

A facts file has the usual header, except that it has **no `native`**: each
fact carries its own text in every language it is written in. It has
`facts` in place of `cards`.

### Fact fields

| Field | Required | Notes |
|---|---|---|
| `id` | yes | Unique within the file, `[a-z0-9-]+`, conventionally `<code>-fact-NNN`. **Never reuse or renumber**: the app remembers which facts a learner has seen by id. |
| `text` | yes | The fact, keyed by language code (the same codes as `code`): `{ en: ..., bn: ... }`. A learner sees it in each language they speak that it is written in. |
| `contrast` | no | A language code. Set it when the fact compares this language with that one, as the `bn` fact above does. Such a fact is shown only to learners who speak that language, and `text` must have an entry for it. |
| `tags` | no | What the fact is about, e.g. `[script]`, `[pronunciation]`, `[grammar]`, `[history]`. |
| `source` | no | Where the fact can be checked. Give one whenever the fact is not common knowledge. |

### Rules

- **At least 30 facts without a `contrast`.** These are true whatever the
  learner speaks, a month of one fact a day, and the
  validator fails a file with fewer. Facts with a `contrast` are extra.
- **Write every fact in every language a learner can say they speak
  (`assets/languages.yaml`: English, Bengali and Hindi), English first.**
  English, and any other language a fact is written in, gets a warning when
  fewer than 30 contrast-free facts are written in it, since its learners see
  only that many.
- **Facts are about the language:** its script, sounds, grammar, words and
  history. Good material includes letters that never start a word, how
  conjuncts form, sounds the learner's language lacks (these usually want a
  `contrast`), schwa deletion, loanwords, numerals, and related languages.
- **True before interesting.** One to three sentences, no exaggeration, and a
  `source` for anything a reader could doubt.
- **The YAML quoting rule applies**, to keys too: Norwegian's code is `no`, so
  write it `"no":`.

---

## Number rules

The number generator (#54, [ADR-0011](adr/0011-number-generator.md)) makes
practice cards for 4-digit numbers, spelled from the words a language's
number decks teach. Each language that has them gives its rules in
`decks/<code>/<code>-numbers.yaml`:

```yaml
schema: 1
id: te-numbers
name: "Telugu numbers"
kind: numbers
language: { code: te, iso639_3: tel, name: Telugu, script: telugu, tts: te-IN }
license: CC0-1.0
tens_and_units: true
words:
  1: "ఒకటి"
  5: ["ఐదు", "అయిదు"]
  20: "ఇరవై"
hundreds:
  1: ["వంద", "నూరు"]
  2: "రెండు వందలు"
hundreds_before:
  1: "నూట"
  2: "రెండు వందల"
thousands:
  1: "వెయ్యి"
  2: "రెండు వేలు"
thousands_before:
  1: "వెయ్యి"
  2: "రెండు వేల"
```

| Field | Required | Notes |
|---|---|---|
| `words` | yes | The numbers from 1 to 99 the decks teach a word for. |
| `tens_and_units` | no | `true` when a number from 21 to 99 without a word is its tens word and its units word, as Telugu's ఇరవై ఆరు is 26. Defaults to `false`: Hindi and Bengali have a word of their own for each. |
| `hundreds`, `thousands` | yes | 100–900 and 1,000–9,000 on their own, keyed 1 to 9. |
| `hundreds_before`, `thousands_before` | no | The same with more digits after them, where the word changes. Default to `hundreds` and `thousands`. |
| `join` | no | What goes between the parts. Defaults to a space. |

A value is a spelling or a list of spellings, the usual one first; every
one is accepted as an answer. A number whose last two digits have no word is
never generated. **Every word used must be taught:** the validator fails a
rules file that spells with a word that no card in the language's
`numbers-1-20` or `numbers-big` deck contains.

## Drill modes

| Mode | Prompt | Expected answer | Graded |
|---|---|---|---|
| `recognition` | `target` | `native` | self-assessed |
| `production` | `native` | `target` | automatically |
| `listening` | TTS audio of `target` | `target` | automatically |
| `grammar` | expanded `prompt` | inflected form | automatically |
| `speaking` | `native` | `target`, said aloud | automatically, from what the phone's speech recogniser heard |
| `reading` | a passage, then a question about it | the right choice | automatically |

A reading question is also heard, in `listening`: the passage is read aloud
and its text is hidden until the question is answered. A card cannot take
`reading`; only a [reading deck](#reading-decks)'s questions do.

`listening` is offered only when a TTS voice for `language.tts` is available on
the device. `speaking` is offered only once the learner has switched it on,
which asks for the microphone, and only for a language the phone's speech
recogniser hears ([ADR-0014](adr/0014-speaking.md)). Matching is exact once
normalised: a near miss in speech is a different word, not a typo.
`recognition` is self-graded because judging a free-text translation is beyond
what an offline app should attempt.

---

## Grading

Automatically graded answers are normalised before comparison:

1. one spelling for text that looks the same: precomposed letters are
   decomposed (Devanagari and Bengali nukta letters such as क़ and য়, and
   Bengali and Telugu two-part vowel signs such as ো), Indic digits read as
   0–9, and zero-width joiners are ignored. This is a table for the scripts
   the app ships, not full Unicode NFC, which needs a package (#28); a new
   script adds its rows to `lib/core/grading/canonical.dart`
2. trim, collapse internal whitespace
3. case folding
4. strip terminal punctuation

If that does not match, a second pass **also** strips diacritics (the Latin
accents, and the Devanagari and Bengali nukta) and leading articles declared
for the language. A match at
this stage counts as correct but the UI flags what was missed — the answer was
right, the accent was not.

Finally, an answer within a Levenshtein distance of 1 (for targets of 8
characters or more, distance 2) is reported as a near miss and offered for
self-assessment rather than marked wrong outright.

`alt_target` and `alt_native` entries are each run through the same pipeline;
matching any one of them is a match.

---

## A YAML trap worth knowing about

YAML resolves the bare words `no`, `yes`, `on`, `off`, `true` and `false` to
**booleans**, not strings. This bites romanisation decks immediately — the
hiragana `の` romanises to `no`:

```yaml
- id: ja-en-hiragana-025
  target: の
  native: no          # WRONG: parses as the boolean false
  native: "no"        # correct
```

The same applies to values that look numeric: a card whose target is `007` or
`1.0` will arrive as a number. **Quote any value that is not obviously prose.**

`tools/validate_decks.py` detects both cases and says so explicitly. This is
the main reason deck validation runs in CI rather than being left to reviewers
to spot by eye.

---

## Licensing deck content

Every deck declares its own `license`, independent of the app's GPL-3.0.

Only contribute content you may legally relicense. Wordlists derived from
copyrighted textbooks or commercial courses **are not acceptable** even when
reworded. Good sources are public-domain frequency lists, Wiktionary
(CC-BY-SA-4.0), Tatoeba (CC-BY-2.0-FR) and original work.
