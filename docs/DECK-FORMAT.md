# Deck format, schema 1

A deck is a single UTF-8 YAML file, or a core and its layers (see
[Core and layer files](#core-and-layer-files)). Filenames are
`<deck-id>.yaml` and live under `decks/<language-code>/`; a layer lives one
folder down, in `decks/<language-code>/<native-code>/`.

Four kinds of deck exist: `vocab` (a list of cards), `grammar` (a pattern
table that expands into cards), `rules` (a table of a rule's forms over the
words of one kind, which expands into cards; see [Rules decks](#rules-decks))
and `reading` (passages with questions about them). Another kind of file,
`facts`, holds a language's daily facts rather than anything drilled. All
five share the same header, with the differences a core and a layer make. Beside them sit files that are not decks: the shared
[themes](#themes), each language's [number rules](#number-rules), and each
language's [path](#paths).

Validate before committing:

```sh
python3 tools/validate_decks.py decks/
```

## Script in prose: always with its reading

The owner: "Always keep the transliteration, even in descriptions or
labels." A learner reads a card's notes, meanings, descriptions, labels and
facts long before they can read the script. So wherever deck text other than
the word itself quotes a word, a letter or a sign in a script other than
Latin, its reading (in letters based on ISO 15919) follows it in parentheses:

```yaml
notes: "లేదు (lēdu) is 'there is not', the opposite of ఉంది (undi)."   # right
notes: "లేదు is 'there is not', the opposite of ఉంది."                  # rejected
```

- A suffix keeps its hyphen, `-ने (-ne)`; a vowel sign reads as its vowel,
  `ा (ā)`; a digit as its number, `३ (3)`.
- The reading may come first instead: `lēdu (లేదు)`.
- **Not needed** in the fields that are the word itself (`target`,
  `reading`, `ipa`, `forms`, `letters`, `term`, `example`, a passage's
  `text`), for signs with no sound of their own (the virama and the nukta),
  or, in text written for speakers of another language (a fact's `hi` or
  `bn`), for words in that reader's own script. A word in a third script
  there still takes one, in Latin or in the reader's script.
- **In a [core and its layers](#core-and-layer-files),** every string of a
  layer is read as written for the layer's native language, whatever its
  key, and every string of a core is the language learnt's. So a Bengali
  layer's own Bengali words need no reading, and a Telugu word in it does.
  A key never decides the language there: the slot keys `"lo"` and `"to"`
  are not Lao and Tongan.
- **The new prose fields** are held to it as every other: a note's `text`
  and a layer's note texts, a base's `meaning`, example translations, a
  rules layer's `slot_name`, slot labels, `prompts`, and each rule's `name`
  and `explanation`, a grammar layer's `name`, `slot_name`, `prompt`,
  glosses and `notes`, a layer's `name` and `description`, and a path's
  passage descriptions and region names, each read as written for its
  key's language, as a facts file's texts are. The language facts beside
  them (`word`, `base`, `ref`, `words`, `region`, a passage's `id`, a
  core's slot keys) are the word itself and need none.
- **Placeholders are checked before they are filled.** A layer that quotes
  its core's words as `{1}`, `{2}` (see [Notes](#notes)) holds no script at
  that point, so it needs no reading there: the reading comes with the word
  from the core.

`tools/transcribe.py` gives the reading, and `tools/validate_decks.py`
rejects a word without one.

---

## Header

Common to every kind.

| Field | Required | Notes |
|---|---|---|
| `schema` | yes | Must be `1`. |
| `id` | yes | Unique, `[a-z0-9-]+`, must equal the filename stem. A vocab or grammar deck's id starts with the language learned and then the language it is taught from: `hi-en-market` is Hindi from English. A facts file is about one language: `hi-facts`. A core's id is the language and a name, `te-home`; its layer's is the language, the native language and the same name, `te-en-home`, which is also the merged deck's id ([Core and layer files](#core-and-layer-files)). |
| `name` | yes, except on a core | Human-readable title. A core has none: each layer gives it, in its own language. |
| `kind` | no | `vocab` (default), `grammar`, `rules` for a [rules deck](#rules-decks) (a core and layers only), `reading` for [passages](#reading-decks), `layer` for a [layer](#a-layer), or `facts` for a [facts file](#facts-files). The files beside the decks have their own: `themes`, `numbers`, `path`, `sounds` and `script`. |
| `part` | on a core | `"core"`, and only on a core ([A core](#a-core)). Left out everywhere else. |
| `core` | on a layer | The id of the core the layer translates, `"te-home"`. |
| `language` | yes, except on a layer | The language being learned. See below. A layer takes its core's. |
| `native` | yes, except on a facts file or a core | The language explanations are written in. A core has none: each layer names its own. |
| `license` | yes | SPDX identifier, or `CC0-1.0` for public domain. |
| `authors` | no | List of `{name, url?}`. |
| `source` | no | Where the content comes from: a URL, or for a book its title, author, year and licence, as in `"Sahaj Path, part 1, by Rabindranath Tagore (1930), in the public domain"`. The app shows it on the deck's page, and Settings lists it under Sources. |
| `description` | no | One or two sentences. |
| `tags` | no | Deck-level tags, e.g. `[beginner, core]`. The tag `unreviewed` marks a deck no native speaker has checked: the app says so on the deck's screen. `reviewed` marks one a speaker has checked; a deck is one or the other, never both. A file with a [culture note](#notes) must carry one of them. |
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
| `icon` | no | What the language's chip shows: the first letter of its own name, as `"हि"` for Hindi or `"Es"` for Spanish ([ADR-0027](adr/0027-language-icons.md)). Give the same one on every deck of the language; the validator checks that they agree. Without one, a chip shows the first letter of the language's first card. |

### `native`

`{code, iso639_3, name}` — same meaning, for the learner's own language. Every
language named anywhere, learned or native, carries its ISO 639-3 code.

### YAML values

The validator and the app read a plain (unquoted) value the same way, as
YAML 1.2 does:

| Plain value | Read as |
|---|---|
| `true`, `True`, `TRUE`, `false`, `False`, `FALSE` | a boolean |
| `[-+]?[0-9]+` | a whole number, in base 10: `060` is 60 |
| `0o17`, `0x1F` | a whole number in base 8 or 16 |
| `1.5`, `.5`, `1e3`, `.inf`, `.nan` | a number with a fraction |
| `null`, `Null`, `NULL`, `~`, nothing | null |
| anything else: `yes`, `no`, `on`, `off`, `y`, `n`, `1_000`, `1:30`, `0b101` | text |

So `phrasebook: yes` is the text `"yes"`, not true, and is refused. Do not
lean on the table: **quote every value that is text, and every key that is
text too** (`"lo":`, `"stem":`, `"te-9001":`), as the examples below do.
Only three kinds of value stay unquoted, because they are meant as what
they are: booleans (`phrasebook: true`, `rtl: true`), whole numbers
(`schema: 1`, `words: 45`) and `null` for an empty grammar cell. A quoted
`"true"` is refused where a boolean is wanted. In a layer, and in a rules
core's `table` and `rules`, a key that is not text is an error: `1:` is the
number 1, and must be written `"1":`.

---

## Core and layer files

A deck may be written as two kinds of file instead of one
([ADR-0036](adr/0036-b1-deck-format.md)):

- **The core** holds what belongs to the language learnt, the same for
  every learner: card ids, targets, readings, IPA, parts of speech,
  pictures, forms, [base words](#base-words-bases), the
  [rules](#sentences-and-their-rules-rules) a sentence uses, and the
  language facts of [notes](#notes).
- **A layer** holds what belongs to one native language: the deck's name
  and description, each card's meaning, its note texts, its examples'
  translations, and a grammar or rules deck's labels and explanations, keyed
  by card id.
- **Merged, they are one deck,** whose id is the layer's. A card the layer
  does not translate is not taught from that language: it is left out, not
  shown in English.

So teaching a language from Bengali as well as English means adding Bengali
layers; the core does not change. Every deck in a [B1 plan](#the-b1-plan)
is split into a core and its layers as the plan is written. A single-file
deck stays valid in every form it has, and may use every new card field.
[Rules decks](#rules-decks) exist only as a core and layers; reading decks
stay single-file, since their questions are already keyed by language; a
deck a learner adds in the app is single-file.

The ids in the examples below, `te-9001` and on, are made up. Take real ones
from `python3 tools/validate_decks.py --next-id te`.

### Files and ids

| File | Where | Id |
|---|---|---|
| Core | `decks/<lang>/<lang>-<name>.yaml` | `<lang>-<name>`: `te-home` |
| Layer | `decks/<lang>/<native>/<lang>-<native>-<name>.yaml` | `<lang>-<native>-<name>`: `te-en-home` |
| The merged deck | (none) | the layer's id, `te-en-home` |

- **`<name>`** matches `[a-z0-9]+(-[a-z0-9]+)*`, and is the same in the core
  and every layer of it.
- **The merged deck's id is the id a single-file deck of that course has
  today,** so placement, a learner's added deck and the review log all know
  it unchanged, and the language's path, which lists the core id
  (`te-home`), does not change. Splitting `decks/te/te-en-home.yaml` into
  `decks/te/te-home.yaml` and `decks/te/en/te-en-home.yaml` keeps the deck id
  and every card id.
- **Reserved names:** a core is never `<lang>-facts`, `<lang>-numbers`,
  `<lang>-romanisation`, `<lang>-script`, `<lang>-sounds` or `<lang>-path`,
  the files beside the decks.
- **A core's name never starts with a native language's code,** nor with the
  name of a folder beside it: a core `te-en-x` would read as a deck of the
  `te-en` course. Nor is a core's id the id of any other file of the
  language.
- **A grammar or rules core's cells** take the core's id as their deck name:
  `te-grammar-past` expands to `te-grammar-past-<key>-<i>`, exactly as the
  single-file `te-en-grammar-past` does ([Expansion](#expansion)). Splitting
  a grammar deck keeps every cell id as long as the core's id is the old
  deck id without its native language, and the slots keep their order.
- **One namespace of card ids per language.** A card is written once in the
  language, in a core, a layer or a single-file deck, and
  `--next-id` sees all three.

### A core

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
  - id: "te-9001"
    target: "ఇల్లు"
    reading: "illu"
    ipa: "illu"
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

| Field | Required | Notes |
|---|---|---|
| `schema` | yes | `1`. |
| `id` | yes | `<lang>-<name>`, the filename stem. |
| `part` | yes | `"core"`. It is what marks the file as a core. |
| `kind` | no | `"vocab"` (default), `"grammar"` or `"rules"`. Not `"reading"`: a reading deck stays a single-file deck. |
| `language` | yes | The full language block, `icon` included where the language's other decks give one. |
| `license` | yes | SPDX, for the core's content. |
| `authors`, `source`, `tags` | no | As on any deck. |
| `theme` | no | On a vocab core: the theme it teaches. |
| `cards` | on a vocab core | A non-empty list, below. |
| `pattern` | on a grammar core | [A grammar core](#a-grammar-core). |
| `table`, `rules` | on a rules core | [Rules decks](#rules-decks). |
| `native`, `name`, `description` | **not allowed** | They are the learner's language: each layer gives them. |

The file sits in `decks/<language.code>/`. A core no layer names is warned
of: no learner is taught it.

**A core card** has the language side only. It may give `id`, `target`,
`reading`, `ipa`, `alt_target`, `pos`, `gender`, `tags`, `audio`,
`examples`, `modes`, `picture`, `notes` (the core form, below),
`phrasebook`, `bases` and `rules`. It may **not** give `native`,
`alt_native` or `wiktionary`, which are the native language's and go in each
layer, nor `pair`: in a core a [pair note](#notes) names the partner, and
the card's sound-alike is taken from it.

**A core example** is `{ target, reading?, ipa?, bases? }`. Its translation
is in each layer, keyed by its target, so two examples of one card may not
have the same target, and the target is written in Unicode's composed form
(NFC), as every layer key that names it is.

**A core ref**, `- ref: "te-9010"`, lists a card written in another deck. It
may give `reading`, `ipa`, `tags`, `modes`, and `examples` and `notes` in the
core form; not `native`, `alt_native` or `wiktionary`.

### A grammar core

The core keeps the table's language side, and the slot labels stay the keys
of `forms`:

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

A core `pattern` gives `slots` and `entries`, and each entry `lemma`, `key`,
`forms`, `reading`, `readings`, `ipa` and `ipas`, under every rule of
[Grammar decks](#grammar-decks). Its `name`, `slot_name`, `prompt` and
`notes`, and each entry's `gloss`, are in each layer.

### A layer

```yaml
schema: 1
id: "te-en-home"
kind: "layer"
core: "te-home"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Home and neighbourhood"
description: "Rooms, the house and the street."
license: "CC0-1.0"
tags: ["unreviewed"]
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
    bases:
      - { word: "ఇంటి", ref: "te-9001" }
      - { word: "పేరు", base: "పేరు", reading: "pēru", meaning: "name" }
    notes:
      - { kind: "culture", text: "A Telugu surname often comes first, before the given name.", source: "https://en.wikipedia.org/wiki/Telugu_people#Names" }
```

| Field | Required | Notes |
|---|---|---|
| `schema` | yes | `1`. |
| `id` | yes | `<lang>-<native>-<name>`, the filename stem, where the core is `<lang>-<name>`. |
| `kind` | yes | `"layer"`. |
| `core` | yes | The core's id. The core is `<core>.yaml` in the folder above the layer's. |
| `native` | yes | The native language block, `{ code, iso639_3, name }`. |
| `name` | yes | The deck's title, in this language. |
| `license` | yes | SPDX, for the layer's text. |
| `description`, `authors`, `source`, `tags` | no | As on any deck. |
| `cards` | on a layer of a vocab core | A **mapping** from card id to what this language gives the card. |
| `pattern` | on a layer of a grammar core | Below. |
| `table`, `rules` | on a layer of a rules core | [The layer of a rules core](#the-layer-of-a-rules-core). |
| `language`, `theme`, `part` | **not allowed** | They are the core's. |

The file sits in `decks/<lang>/<native.code>/`. The validator reads the core
beside it even when the layer is validated alone, and checks the layer's
readings against the core's language and its
[romanisation file](#romanisation-files).

**An entry for a card the core writes:**

| Field | Notes |
|---|---|
| `native` | **Required.** The meaning. A card with no entry, or an entry with no `native`, is not taught from this language. |
| `alt_native` | As on any card. |
| `notes` | A mapping from the core note's `id` to its text in this language ([Notes](#notes)). |
| `examples` | A mapping from a core example's `target`, exactly as the core writes it, to its translation: text, or `{ native, bases }`, where `bases` gives the example's inline bases their meanings as the card's `bases` below does. |
| `bases` | A mapping from the `word` of one of the core card's inline bases to its meaning: text, or `{ meaning, wiktionary }` ([Base words](#base-words-bases)). |
| `wiktionary` | `true` ([The Wiktionary link](#the-wiktionary-link)). |

Anything else, `target`, `reading`, `ipa`, `pos`, `tags`, `modes` and the
rest, is an error on such an entry: a layer cannot change the word.

**An entry for a card the core lists by `ref`:** the same fields, but
`native` is optional. With it, the card has its own meaning in this deck, as
a ref with `native` has today. Without it, the card takes the meaning of
the card it names, through a deck of the same native language, as
[a ref](#a-word-in-more-than-one-deck-ref) does; the entry may still give
`alt_native` and `wiktionary`. It gives `notes` and `examples` only where
the core's ref gives core-form ones for it to key on.

**A card only this layer has** is an entry whose id the core does not have:
a whole single-file card without its `id` line, since the key is its id.
`target` and `native` are required and every card field is allowed, `pair`
included, with notes in the [single-file form](#notes) and bases written in
full. Its id is taken from the language's sequence like any other. Use it
for what only these learners need: Bengali false friends for a Bengali
speaker learning Hindi, say. A layer whose own card has a culture note is
tagged `unreviewed`, as the one above is, since the claim is in the layer.

**A layer of a grammar core** gives the learner's side of the pattern:

```yaml
pattern:
  name: "Past tense"
  slot_name: "person"
  prompt: "{lemma} ({gloss}) — {slot}"
  slots: { "నేను": "I, నేను (nēnu)", "నువ్వు": "you, నువ్వు (nuvvu)" }
  entries: { "vellu": "to go" }
  notes: "The past adds -ఆ- (-ā-) before the person ending."
```

`name`, `slot_name`, `prompt` and `entries` are required; `entries` maps each
core entry's `key`, or its lemma where it has none, to its gloss, and an
entry without one is left out. `slots` is optional: it maps a core slot to
the label `{slot}` shows, and a slot without one shows its key. `notes` is
optional.

**What the validator checks on a layer:**

- **Errors:** an entry that names nothing in the core (a note id, an
  example's target, an inline base's word or a grammar entry the core does
  not have), so that a core edit cannot silently lose a translation; a
  missing `native` on a card the core writes; a field that belongs to the
  word; a text key that is not in Unicode's composed form (NFC), since a
  key must match the core's text letter for letter.
- **Warnings:** a core note with no text here, an example with no
  translation, and an inline base with no meaning: learners from this
  language do not see them, or see the base without one.
- **One info line:** `covers n of m cards of te-home (p%)`, how much of the
  core this layer teaches.

### What the merged deck is

The app merges each layer with its core into one deck, and the validator
checks the same deck:

- **The deck:** the layer's id, `name` and `description`; the core's `kind`,
  `language` and `theme`; the layer's `native`. Its `license` is the core's
  when the two agree, else `"<core's> AND <layer's>"`. Its tags are the
  core's, then the layer's, and `reviewed` is dropped when either says
  `unreviewed`, so a deck reads as unreviewed until both files are checked.
  Its authors are the core's then the layer's.
- **Its cards,** in the core's order: each written card the layer gives a
  `native`, and each ref that has a meaning in this language, by the layer
  or through a deck of the same native language. The layer's own cards
  follow, in the layer's order.
- **A merged card** takes the word from the core and the meaning,
  `alt_native` and `wiktionary` from the layer. Its notes are the core's, in
  order, each with the layer's text, its placeholders filled; a note with
  no text in this layer is left out. Its examples are the core's, each with
  the layer's translation; one without is left out. Its `pair` is the
  partner of its first pair note.

### Splitting a deck

1. The core is `decks/<lang>/<lang>-<name>.yaml`, its id the old deck id
   without the native language: `te-en-home` gives `te-home`.
2. The layer is `decks/<lang>/<native>/<old id>.yaml`, with the old id.
3. **Every card id stays as it is.** A card the old deck wrote is written in
   the core, with its meaning, notes and translations in the layer; a ref
   stays a ref.
4. A grammar deck keeps every entry's `key` and the order of its slots, so
   its cells keep their ids.
5. **The old file is deleted in the same change.** The validator refuses the
   two side by side: they have the same id.
6. **The first layer folder of a language** needs its line in
   `pubspec.yaml`, `- decks/<lang>/<native>/`, under `flutter.assets`, in a
   one-line commit of its own: the app bundles only the folders listed
   there, and the validator fails a folder of decks that is not.
7. The path does not change: it lists the deck's core id, `te-home`, which
   the single-file deck had too. Once a language has a core, its path needs
   its [B1 plan](#the-b1-plan).

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
| `reading` | no | Romanisation, as the language's [romanisation file](#romanisation) says: for the Indic languages, letters based on ISO 15919, as the word is said. Required in practice for non-Latin scripts. |
| `ipa` | no | How the word is said, in the IPA: broad, without the slashes, which the app adds, as `"paːlu"` ([ADR-0025](adr/0025-iso-15919-and-ipa.md)). `tools/transcribe.py` writes one. |
| `alt_target` | no | Additional answers accepted in production drills. |
| `alt_native` | no | Additional meanings accepted when the meaning is typed, in Hear (ADR-0034). |
| `pos` | no | Part of speech: `noun`, `verb`, `adj`, `adv`, `pronoun`, `phrase`, `particle`, `other`. A [rules deck](#rules-decks) picks its rows by it, so give every word its own: a pronoun is `pronoun`, not `other`. |
| `gender` | no | Grammatical gender, free text (`m`, `f`, `n`, `c`…). |
| `tags` | no | Card-level tags. Drills can be filtered by tag. |
| `notes` | no | Text, or a list of typed notes: see [Notes](#notes). Shown when the word is taught and after answering. |
| `audio` | no | Asset path or URL overriding TTS for this card. |
| `examples` | no | List of `{target, native}` sentence pairs. An example may also give its `reading`, `ipa` and [`bases`](#base-words-bases). |
| `phrasebook` | no | `true` on a survival phrase taught whole, first: see [The phrasebook](#the-phrasebook). Leave it out otherwise. |
| `bases` | no | The base word of each inflected or derived word in the target and its examples: see [Base words](#base-words-bases). |
| `rules` | no | On a sentence: the ids of the rules it uses, `["te-rule-ki"]`. See [Sentences and their rules](#sentences-and-their-rules-rules). |
| `wiktionary` | no | `true` where the learner's language's Wiktionary has an entry for the target: see [The Wiktionary link](#the-wiktionary-link). |
| `modes` | no | Which drills this card participates in. Defaults to all applicable, except that a `pos: phrase` card is not typed: it defaults to recognition, listening and speaking, and production by rearranging its words when it has two or more (ADR-0024). |
| `pair` | no | The id of a word of the language that sounds almost the same, its minimal-pair partner: `te-0111`, కాలం (kālam), time, on కలం (kalam), pen. Hear offers the partner's meaning among its options, to catch a learner who confuses the two ([ADR-0034](adr/0034-hear-say-write.md)). It belongs to the word, so a ref cannot give it. A [pair note](#notes) gives it too: a card without `pair` takes its first pair note's partner, and a core card has no `pair` at all, only pair notes. |
| `picture` | no | One emoji, quoted, showing what a concrete word means: `"🏠"` on house. Its picture, from [Noto Emoji](https://github.com/googlefonts/noto-emoji) (Apache-2.0), is a cue beside the meaning in Write and beside each meaning Hear offers ([ADR-0034](adr/0034-hear-say-write.md)). Only for a picture that means exactly the word: not for abstract words, kinship, or near misses. Run `python3 tools/pictures.py path/to/noto-emoji` to bundle its image; the validator checks it is there. It belongs to the word, so a ref cannot give it. |

In a [core and its layers](#core-and-layer-files), the core card gives
every field above but `native`, `alt_native`, `wiktionary` and `pair`; the
layer gives `native`, `alt_native` and `wiktionary`, and the texts of the
core's notes and examples.

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
`reading`, `notes`, `tags`, `examples`, `modes` and `wiktionary`. What the
card is in the language learned, its `target`, `alt_target`, `pos`,
`gender` and `audio`, stays where it is written, and so do `phrasebook`,
`bases`, `rules`, `pair` and `picture`: a ref cannot give them.

- **The same native language:** what the ref does not give comes from the
  card.
- **Another native language,** say an `es-bn` deck listing a card written in
  an `es-en` one: the ref gives its own `native`. The card's `notes`, `tags`,
  `alt_native` and `examples`, written for English speakers, do not come
  across; its `reading` and `modes`, which belong to the word, do unless the
  ref gives its own.
- **A card written in a core** has its meaning in each layer. A ref to it
  from a single-file `te-en` deck takes the meaning the core's English layer
  gives it; with no English layer that translates it, the ref gives its own
  `native`.
- `wiktionary` on a ref is its own where given; otherwise it comes from the
  card, as `notes` does, when the deck has the card's native language.
- The validator checks that each ref names a card written in another deck
  of the language, and that no card is written twice.

### The phrasebook

A course starts with a small phrasebook: 15 to 25 survival phrases, taught
whole from the first lesson, never held back until their words are known
([ADR-0036](adr/0036-b1-deck-format.md)). Greetings, thanks and sorry, yes
and no, "I don't know Telugu", "I don't understand", "please speak slowly",
and the like.

```yaml
  - id: "te-9100"
    target: "నాకు తెలుగు రాదు."
    reading: "nāku telugu rādu."
    native: "I don't know Telugu."
    pos: "phrase"
    phrasebook: true
    bases:
      - { word: "నాకు", ref: "te-9101" }
      - { word: "తెలుగు", ref: "te-9102" }
      - { word: "రాదు", base: "రా", reading: "rā", meaning: "to come; here, to know (a language)" }
```

That is the single-file form. In a core the card has no `native`, and the
inline base no `meaning`: the layer gives both.

- **`phrasebook: true`, unquoted,** or nothing. `false`, `"true"` and `yes`
  are refused. It goes on a card where the card is written, never on a ref.
- **15 to 25 per course,** counted over every deck of the course, by
  distinct card id. The validator checks the count once a course has one
  phrasebook card, or a [B1 plan](#the-b1-plan). A Bengali layer's own
  phrasebook cards count for Bengali learners only.
- **In the course's first unit.** In a course with a B1 plan, every
  phrasebook card is taught by a deck of the course's first unit on the
  path, the first it has a deck in. A later
  deck may list one by `ref`, as long as a first-unit deck teaches it too.
- **Its words are not counted as taught by it.** Each word of a phrase comes
  again later as a word card, and its `bases` say which. A phrasebook card
  is never counted as a word of the course: not in a unit's words, not as a
  row of a rule's table, and not as the card that covers a word of another
  text ([Base words](#base-words-bases)).

### Base words: `bases`

A card names the base word of every inflected or derived word in its target
and its examples. For "He went to our school" the card also gives "go" and
"we". They are shown with the taught details: on the lesson's teach card,
and in reviews once the question is answered, never before, since on a
Write question they would give the answer away.

**Single-file deck, or a layer's own card:**

```yaml
    bases:
      - { word: "ఇంటికి", ref: "te-9001" }
      - { word: "రాదు", base: "రా", reading: "rā", meaning: "to come", wiktionary: true }
```

**In a core,** the meaning and the Wiktionary mark of a base written in full
are in each layer:

```yaml
    bases:
      - { word: "ఇంటికి", ref: "te-9001" }
      - { word: "రాదు", base: "రా", reading: "rā" }
```

```yaml
  "te-9100":
    native: "I don't know Telugu."
    bases:
      "రాదు": { meaning: "to come; here, to know (a language)", wiktionary: true }
```

| Field | Required | Notes |
|---|---|---|
| `word` | yes | The word as it stands in the text, ఇంటికి (iṇṭiki): one of the text's words, compared in Unicode's composed form and ignoring case. |
| `ref` | one of `ref` and `base` | The card that teaches the base, ఇల్లు (illu). Its target, reading and meaning are shown, in the learner's language. Prefer it. |
| `base` | one of `ref` and `base` | The base written in full, when no card teaches it. |
| `reading` | with `base`, in a script that needs one | The base's reading. A missing one is an error here, not a warning: the app shows it. |
| `ipa` | no, with `base` | The base in the IPA. |
| `meaning` | with `base`, single-file only | Its meaning. In a core it is in the layer. |
| `wiktionary` | no, with `base`, single-file only | `true` ([The Wiktionary link](#the-wiktionary-link)). In a core it is in the layer. |

- **Examples** take `bases` the same way, on the example:
  `examples: [{ target: "...", reading: "...", bases: [...] }]`. A layer
  gives an example's inline bases their meanings under
  `examples: { "<target>": { native: "...", bases: { "<word>": ... } } }`.
- **Not on a ref:** a base belongs to the text it is a word of.
- A `word` is given once per text, and is a word of that text. A `ref` names
  a card of the language, not the card itself. `reading`, `ipa`, `meaning`
  and `wiktionary` are only for a base written in full.
- **Words** are the text split at spaces and punctuation (an apostrophe
  inside a word is kept), with digits dropped.

**In a [B1 deck](#the-b1-plan), every word is covered.** Each word of a
target, and of each example's target, is either the target, or an
`alt_target`, of a word card the course teaches (a vocab card that is
neither a phrasebook card nor a phrase), or has a `bases` entry. A grammar
or rules cell does not count, since an inflected form taught as a cell is
still a derived word that names its base, and nor does a card taught only
from another native language. Phrasebook cards are checked too. Decks on no
B1 plan are not checked: they gain their bases as their language's plan is
written. A language written without spaces (`han`, `kana`, `thai`) cannot
have a B1 deck until the format can give its words.

### Notes

Notes are a list of facts about the word, each of a kind. The app shows one
at a time, when the word is taught and after an answer: shuffled, never
repeated until every note of the card has been shown once.

| Kind | What it says |
|---|---|
| `pair` | A minimal pair: a word of the language that sounds almost the same. It names that word, the partner, by `ref`. |
| `culture` | The word's cultural significance. It names its `source`. |
| `usage` | Another context it is used in, or another sense. |
| `behaviour` | How it behaves unlike similar words: an irregular form, a gender, a use. |
| `note` | Anything else worth knowing. |

**Single-file deck, or a layer's own card:**

```yaml
    notes:
      - { kind: "pair", ref: "te-9007", text: "Not కాలం (kālam), time: the a is long there." }
      - { kind: "culture", text: "A pen was a gift for the first day at school.", source: "https://example.org/telugu-school-customs" }
      - { kind: "usage", text: "Also a pen-name, in old usage." }
      - { kind: "behaviour", id: "plural", text: "Its plural is {1}.", words: [{ word: "కలాలు", reading: "kalālu" }] }
      - { kind: "note", text: "A word from Arabic, through Persian." }
```

| Field | Required | Notes |
|---|---|---|
| `kind` | yes | `pair`, `culture`, `usage`, `behaviour` or `note`. |
| `text` | yes | The note, in the deck's native language. [Script in prose](#script-in-prose-always-with-its-reading) applies. |
| `id` | no | The note's id: starts with a letter, `[a-z0-9-]+`, not one of `yes`, `no`, `on`, `off`, `true`, `false`, `y`, `n`, and unique in the card. Without one, a note's id is its place, `"1"`, `"2"`. The app remembers which notes it has shown by card and note id, so give ids once a card's notes may be reordered. |
| `ref` | on a `pair` note, and only there | The partner: another card of the language that sounds almost the same. |
| `source` | on a `culture` note; optional on the rest | Where the claim can be checked: a URL, or a book with its author and year. |
| `words` | no | The words of the language the text quotes, `{ word, reading, ipa? }`, `reading` required in a script that needs one. The text names them `{1}`, `{2}` (below). |
| `region` | no | On a note of any kind: the [regions](#regions) of the language it is about, a region id or a list of them, each a region of the language's path. |

`notes` may still be text, as every deck had it: it reads as one note of
kind `note`. An empty string is no notes. A list may not be empty.

**A region note** says how the word is used, or heard, in some of the
language's regions: regional vocabulary, or an offensive word whose raters
from different regions differ by a band or more. On ఉల్లిపాయ (ullipāya),
onion:

```yaml
    notes:
      - { kind: "usage", region: "telangana", text: "In Telangana often {1}.", words: [{ word: "ఉల్లిగడ్డ", reading: "ulligaḍḍa" }] }
```

A region is a fact about the language, the same for every learner, so in a
core it is on the core's note, `{ id: "telangana", kind: "usage", region:
"telangana", words: [...] }`, and each layer gives the text by the note's
id.

**In a core,** a note keeps its language facts, and each layer writes the
explanation around them. A core note has an `id`, required, and no `text`;
a culture note's `source` is in the core, shared by every layer:

```yaml
    notes:
      - { id: "pair", kind: "pair", ref: "te-9007" }
      - { id: "school", kind: "culture", source: "https://example.org/telugu-school-customs" }
      - { id: "plural", kind: "behaviour", words: [{ word: "కలాలు", reading: "kalālu" }] }
```

The layer gives each note's text by its id:

```yaml
  "te-9005":
    native: "pen"
    notes:
      "pair": "Not to be confused with కాలం (kālam), time: the a is long there."
      "school": "A new pen was a gift for the first day at school."
      "plural": "Its plural is {1}."
```

**Placeholders.** In a note's text, and in a rule's explanation, `{1}`,
`{2}` … `{12}` stand for the first, second and twelfth of the note's (or the
rule's) `words`, shown as the word and its reading in brackets: `{1}` above
reads కలాలు (kalālu). So the word and its reading are written once, in the
core, and every layer shows the same. `{0}` and `{01}` are errors, and so is
a number past the last word; a word the text never uses is warned of. Any
other brace is just a brace. A layer may still quote a word directly, with
its reading.

**What the validator checks on notes:**

- **A warning on a word card with no notes,** in a [B1 deck](#the-b1-plan):
  every word card should have one or more. A word card is a vocab card that
  is not a phrasebook card or a phrase, and is one word, or a noun, verb,
  adjective, adverb or pronoun of several.
- **A pair note's partner is taught in the same course,** so that it has a
  meaning in the learner's language: the minimal-pair panel shows the two
  words side by side, each with its reading and meaning. It is an error
  when no deck of the course teaches the partner. A layer that cannot
  teach the partner leaves that note's text out. When the panel is built,
  it shows its button only where the partner is in the catalog in the
  learner's native language, so a deck a learner adds cannot open a panel
  on a word with no meaning.
- **A warning on a card with `pair` and no pair note naming the partner,**
  in a B1 deck: the minimal-pair button needs the note.
- **Culture notes keep a deck marked.** A file that holds a culture note's
  claim (a core with one, a single-file deck with one, a layer whose own
  card has one) carries `unreviewed` until a speaker checks it, then
  `reviewed`: one of the two, never both (#99).

### The Wiktionary link

The app links a word to its Wiktionary entry, with its etymology, in the
learner's own language's edition:
`https://en.wiktionary.org/wiki/ఇల్లు#Telugu` for ఇల్లు (illu), taught from
English. The link is built from the word, not stored. What is stored is that
the entry exists:

```yaml
  "te-9001":
    native: "home; house"
    wiktionary: true
```

- **`true`, or left out where that Wiktionary has no entry.** Nothing else
  is accepted. Many words of the Indian languages have none yet.
- **It belongs with the native language,** since en.wiktionary may have a
  Telugu word that bn.wiktionary lacks: on a single-file card or ref, in a
  layer's entry, or on a base written in full. Never in a core.
- **The title is the target.** For a base given by `ref`, it is that card's
  target; for a base written in full, its `base`. A card whose target is not
  an entry's title, such as a sentence or an inflected form, is not marked:
  its bases carry the mark for their words.
- **Mark only an entry you have seen:** the word's own page, with a section
  for the language. A tool will mark them from Wiktionary's extracts; until
  then, check each one.

### Sentences and their rules: `rules`

A sentence names the rules it uses, by their ids:

```yaml
  - id: "te-9002"
    target: "నేను ఇంటికి వెళ్తాను."
    reading: "nēnu iṇṭiki veḷtānu."
    pos: "phrase"
    rules: ["te-rule-ki"]
    bases:
      - { word: "ఇంటికి", ref: "te-9001" }
      - { word: "వెళ్తాను", ref: "te-9003" }
```

With `bases`, it is what decides when the sentence is offered: once every
word in it, by its base, and every rule it names are known. Until then it
does not hold back its unit.

- A list of rule ids, each `<lang>-rule-<name>`, none twice, each defined by
  a [rules deck](#rules-decks) of the language.
- Written where the sentence is written: a single-file card, a core card or
  a layer's own card. Not on a ref.

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

A grammar deck may also be written as [a core and its
layers](#a-grammar-core). Split, it keeps every cell id, as long as the
core's id is the old deck id without its native language and every entry
keeps its `key` and the slots their order. A grammar table whose rows are
the words of one kind, a noun's case endings or a verb's persons, is better
written as a [rules deck](#rules-decks): its rows are then every word of
that kind the course teaches, not a few chosen ones.

---

## Rules decks

Grammar taught as rules, practised over the words the learner knows
([ADR-0036](adr/0036-b1-deck-format.md)). A rules deck is **one table**:
its rows are the words of one kind, each with every form listed; its
columns are the forms, and each column belongs to a **rule**, which has an
id, a name and an explanation. A case-endings table has a rule for each
ending; a tense table may have one rule for all its persons. Each cell is a
card, and its questions test the rule, never the word: the word is always
one the learner was taught.

A rules deck is a core and its layers; there is no single-file form.

### The core

`decks/te/te-grammar-case-endings.yaml`:

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

The header is a core's, `kind: "rules"`, with `table` and `rules` in place
of `cards`, and no `theme`.

**`table`:**

| Field | Required | Notes |
|---|---|---|
| `applies_to` | yes | Which words are its rows. `pos`, required: a non-empty list of parts of speech, not `phrase`. `tags`, optional: a word qualifies only with one of them. `except`, optional: card ids of words of that kind the rule does not apply to, such as an indeclinable loanword. |
| `slots` | yes | The column keys, in order: distinct **slot keys**. **Permanent in order:** a cell's id holds its slot's place. Add new slots at the end. |
| `rows` | yes | A non-empty list, below. |

**A slot key** starts with a letter and matches `[a-z0-9-]+`, as `"lo"` or
`"past-1"`, and is none of `yes`, `no`, `on`, `off`, `true`, `false`, `y` and
`n`. Quote it wherever it is a key.

**A row:**

| Field | Required | Notes |
|---|---|---|
| `word` | yes | The id of the vocab card that teaches the word. |
| `key` | no | The row's part of its cells' ids, `[a-z0-9-]+`. Only to keep the cell ids of a grammar deck being turned into rules: the old entry's `key`, or its lemma. Without it, the row's part is the number of `word`, `9001` for `te-9001`. |
| `forms` | yes | Every slot: a form, a list of forms (the first shown, all accepted), or `null` where the word has no such form. At least one is not null. |
| `readings` | in a script that needs one | Every filled slot's reading, as a [grammar entry's](#romanisation). |
| `ipas` | no | As a grammar entry's. |

**`rules`,** a non-empty list:

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `<lang>-rule-<name>`, `<name>` matching `[a-z0-9]+(-[a-z0-9]+)*`, unique in the language. **Permanent:** sentences and a path's grammar topics name it, and its mastery is counted from its cells. |
| `slots` | yes | The table's slots this rule makes. Every slot belongs to exactly one rule. |
| `words` | no | The words of the language its explanation quotes, `{ word, reading, ipa? }`: the layer's explanation names them `{1}`, `{2}` ([placeholders](#notes)). |

### Every word of its kind has its row

The validator holds the table to the course, not to a list someone keeps:

- each row's `word` is a vocab card of the language, of a part of speech in
  `applies_to.pos` (with one of its `tags`, when given), not a phrasebook
  card, not in `except`, and with a reading where the script needs one,
  since every typed cell shows the word with its reading;
- each `except` id is a card of the language;
- **every word of the kind that a [B1 deck](#the-b1-plan) of the language
  teaches has its row,** or is in `except`. It is an error, naming the word
  and the deck that teaches it. So a noun added to a B1 deck needs its row
  in every noun table in the same change. A noun only a Bengali layer
  teaches needs its row too; English learners never see that row.

A row with one form only is warned of: its questions cannot offer a choice.

### The layer of a rules core

`decks/te/en/te-en-grammar-case-endings.yaml`:

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

- **`table`,** required: `slot_name`, what the columns are; `slots`, a label
  for **every** core slot, which is also its cells' prompt; and `prompts`,
  optional, the whole prompt of a cell the label gets wrong, by row `word`
  and slot.
- **A label's only placeholder is `{meaning}`,** the word's meaning in this
  language. The word itself is never written into a label: the app shows it,
  with its reading, on every typed cell. A label without `{meaning}` is shown
  after the meaning, as `mother: plural`.
- **`rules`,** required: each rule id with its `name` and `explanation`.
  **A rule the layer leaves out is not taught from this language,** and its
  cells are not asked. The validator's info line counts the rules covered.

### Its cells

For each row whose word is taught in the learner's language, and each slot
with a form whose rule the layer explains, the deck has one card:

- **id:** `<core id>-<row part>-<slot index>`: `te-grammar-case-endings-9001-0`
  is ఇంట్లో (iṇṭlō). It stays the same while the core's id, the row's word
  or key, and the order of the slots stay the same. A row or slot left out
  shifts no other cell's id.
- **target:** the slot's first form, and the rest as alternatives, with
  their readings and IPA.
- **native:** the layer's `prompts` for the cell, or else the slot's label
  with `{meaning}` filled. The meaning is the first meaning of the word's
  card in this language, up to its first `/`, `;` or `,`: "with mother".
- **modes:** `grammarUnderstood` and `grammar` (below).

A rule itself is not a card. It is taught before its cells, with its name
and explanation, and it counts as known once its cells are.

**What each question shows:**

| Mode | Shown | Answer |
|---|---|---|
| `grammarUnderstood` | The form and its reading: అమ్మతో (ammatō) | Its meaning, "with mother", chosen among the meanings of the same word's other forms in the table: "in mother", "to mother", "from mother". Never another word's, and never one of a rule this layer leaves out. |
| `grammar` | The word and its reading, then the meaning: "అమ్మ (amma): with mother" | The form, chosen among the same word's forms while the cell is new or was last missed, typed once it was last remembered |

These are the two grammar schedules: **grammar understood**, shown a form
and choosing what it means, and **grammar produced**, giving the form.
`grammar` keeps its name and meaning, so every grammar answer already logged
keeps its meaning. A card or ref cannot list `grammarUnderstood` in its
`modes`: only a rules table's cells take it. A cell whose row has no other
form is only typed, and one whose row's other forms all mean the same as it
is not asked its meaning.

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

- **On its language's path, after its theme.** A reading deck is an ordinary
  deck: it is listed on the Decks tab, and the path puts it in a unit after
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
  course with a [path](#paths) is ordered by that instead.
- **Phrases are not typed.** Mark a card of more than one word `pos: phrase`:
  a whole sentence is too hard to grade fairly when typed, so it is
  produced by putting its words in order instead (ADR-0024). Any card of
  three words or more is produced that way too.
- **Grammar decks are not themes.** A course's path places them beside the
  theme decks they go with.

## Paths

A language is taught along a curated path
([ADR-0013](adr/0013-course-paths.md), [ADR-0036](adr/0036-b1-deck-format.md)):
its decks in teaching order, in **units**. There is **one path per language
learnt**, shared by every native language it is taught from:
`decks/hi/hi-path.yaml` is Hindi's, for learners from English and from any
other language alike. It names each deck by its **core id**:

```yaml
schema: 1
kind: "path"
id: "hi-path"
language: "hi"
units:
  - ["hi-first-words", "hi-grammar-sentences", "*"]
  - ["hi-questions", "hi-grammar-questions", "*"]
  - ["hi-addressing", "hi-grammar-pronouns", "*"]
  - ["*"]
```

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `<language>-path`, and the filename stem. |
| `language` | yes | The code of the language learned, such as `hi`, the name of its folder. |
| `native` | **not allowed** | The path is every native language's. A path still written for one course, `<lang>-<native>-path.yaml` with `native`, is refused, with what to do. |
| `units` | yes | A non-empty list. Each unit is a non-empty list of core ids, which may end in the wildcard `"*"`, or a mapping (see [The B1 plan](#the-b1-plan)). |
| `alphabet` | no | The core ids of the decks that need the alphabet: the script, spelling and reading decks. Each must be on the path. A learner who learns the language without its alphabet is not taught them. |
| `regions` | no | The language's regions ([Regions](#regions)). |
| `description` | no | Free text. |

**A deck's core id** is `<lang>-<name>`: a core's own id, a layer's core
(`te-en-home` is `te-home`), or a single-file deck's id without its native
(`hi-en-addressing` is `hi-addressing`). A deck split into a core and its
layers keeps its core id, so the path does not change when a deck is split.

**How a course reads its language's path.** For learners from a native
language `n`, each core id `<lang>-<name>` stands for the deck
`<lang>-<n>-<name>`: the layer merged with its core, or the single-file deck
of that id. A core id with no deck in `n` is skipped for that course, and a
written unit left with no deck is "Coming" for its learners, as a planned
unit is: lessons and placement skip it. `alphabet` maps the same way, and
`"*"` takes the course's decks the path does not list. A deck only one
native language needs, such as English learners' "sounds English lacks",
has a core id like any other, `te-sound-differences`; a Bengali course gives
its own deck for it, `te-bn-sound-differences`, or none.

**Which native language a learner is taught from** is the learner's choice.
When more than one of the languages they speak teaches a language, the app
asks, showing how many of the path's written units each one teaches ("From
English: 30 of 34 units"), with the most covered chosen already. They can
change it in Settings ("Learn Telugu from"). A unit with no deck in the
chosen language is "Coming", never taught from another language's decks.
Progress is kept by card id, so changing loses nothing the cores share.

- **A unit is what is taught together**: a theme deck and the grammar that
  goes with it, or a script. Today takes new cards from the first unit not
  yet finished and the one after it, mixing the two, and placement passes
  or places a unit whole (ADR-0013), so keep a unit to what a learner would
  take in together.
- **Every deck of the language is on its path, exactly once,** by its core
  id, in every course: a single-file deck and a layer of any native
  language alike. A core is on the path through its id. The validator fails
  a deck left out, an id listed twice, a course's deck id listed in place
  of its core id (`hi-en-market` for `hi-market`), and a core id with no
  core and no deck in any course. Adding a deck means adding its core id to
  the path, once; a second native language's deck for a core id already
  listed adds nothing.
- **One path per language,** and every language with a deck in `decks/`
  has one: the validator fails a language without, and a second path file
  of the language, such as a course's path left beside the new one. A new
  course of a language that has a path adds no path. A deck added in the app
  to a course with no path is taught in its course's theme order, and then
  its other decks.
- **The wildcard `"*"` takes decks the path does not list,** such as a deck
  a learner adds in the app ([ADR-0020](adr/0020-added-decks.md)). Quote
  it: a bare `*` is YAML for an alias. It may only end a unit, and a unit
  of `"*"` alone may only be the last. A deck the path does not list goes
  at the bottom of the first unit ending in `"*"` that holds a theme deck
  of its theme, and otherwise into the unit of `"*"` alone, at the end of
  the course. So a unit ending in `"*"` needs a theme deck in some course,
  which the validator checks. Every bundled path ends each unit that has a
  theme deck in `"*"`, and has a last unit of `"*"` alone.
- **Order is a teaching decision.** Grammar goes with the theme that first
  needs it, and a [reading deck](#reading-decks) in a unit after the themes
  it uses.
- **A course opens with words, not letters.** Its first units are a few
  words and basic sentences, the sounds the learner's language lacks and how
  the grammar differs from it, then five more themes; the script comes after
  those six themes, before the rest. Until the learner is past the script
  units, answers typed in Latin letters count in full (ADR-0022), and
  readings show beside the script. The sound and grammar units are typed
  too: their short sentences leave out `pos: phrase`. A letter
  that sounds exactly like another, such as Bengali ন and ণ, or whose
  sound a recogniser writes another way (ঋ is written রি), is drilled by
  reading and writing only (`modes: [recognition, production]`), since no
  ear and no recogniser can tell them apart; so is a mark that is not a
  sound of its own, written on a host letter (কং).
- **The move from course paths.** Until ADR-0036 a path was one course's,
  `hi-en-path.yaml`, with `native` and deck ids. The nine bundled paths
  were moved once: renamed `<lang>-path.yaml`, `native` taken out, and each
  deck id's native taken out (`hi-en-market` became `hi-market`). No deck,
  card id or deck id changed.

### The B1 plan

Every path is to carry a plan of the language up to B1, written once for
every native language and read by the app
([ADR-0036](adr/0036-b1-deck-format.md)). The app shows from it how far a
course reaches ("18% of B1 · 12 of 30 grammar topics"), shows the units not
written yet as "Coming", and skips them in lessons.

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

A unit is a list of core ids, as before, or a mapping:

| Field | Notes |
|---|---|
| `decks` | A written unit's core ids, as the list form, wildcard and all. |
| `planned` | A unit not written yet: `{ id, theme, words }` for a theme unit, `{ id, grammar, words? }` for a grammar unit. `id` is the core id its decks will have (`te-health`; each course's deck for it is then `te-en-health`, `te-bn-health`, …), which must not exist yet: no core of that id, and no deck `te-<native>-health` in any course. When the first of them is written, the unit turns into `decks` in the same change; the courses still without a deck for it see it as "Coming". |
| `words` | The unit's planned size in words, a whole number: 0 or more on a written unit (a unit of grammar or reading decks gives 0), 1 or more on a planned theme unit. One size for every native language. On a planned unit, inside `planned` or beside it, not both. |
| `grammar` | The grammar topics it teaches, below: a list, or one as text. On a planned unit, inside `planned` or beside it, not both. |
| `milestone` | `"A1"`, `"A2"` or `"B1"`, on the unit where that level ends. A unit of `"*"` alone carries none. |
| `listening_passages`, `reading_passages` | The unit's listening and reading passages, each `{ id, text }`. **Both are required on every planned unit.** A written unit's passages are its [reading decks](#reading-decks), and it need not list them. |

**A passage** is named once, in the path, and described in each native
language:

| Field | Notes |
|---|---|
| `id` | `[a-z0-9-]+`, unique in the path across both lists. It names the passage for every native language: reword a description and the id stays. |
| `text` | The description, keyed by native language code as a facts file's texts are: `{ "en": "...", "bn": "..." }`. At least one; [Script in prose](#script-in-prose-always-with-its-reading) applies to each as written for its key's language. A native language a course of the language is taught from, with no text here, is warned of, once per passage: its learners see the passage without a description. |

So a Bengali course written after the English one adds `"bn":` beside
`"en":` on each passage, and nothing else in the path: its units, sizes and
milestones are already there.

- **A path has a B1 plan** when some unit is a mapping with `planned`,
  `words`, `grammar` or `milestone`. Then it has the three milestones, `A1`,
  `A2` and `B1`, each once and in that order. **A path needs one** once its
  language has a core file; every path will need one once every language
  has its plan.
- **Up to B1** is every unit before the one marked `B1`, and that one. Every
  unit up to B1 is a mapping with `words` or `grammar`, except two kinds
  that may stay lists and count nothing: a unit all of whose core ids are
  in `alphabet`, and the unit of `"*"` alone. A planned unit after the B1
  mark is an error: the units after it are written as before.
- **A grammar topic** counts once toward the plan's figure, and is listed
  once up to B1. On a written unit, a topic names one of:
  - **a rule** of a rules deck the unit lists, by the rule id's name: topic
    `ki` is `te-rule-ki`, so a table of four rules is four topics;
  - **a grammar deck** the unit lists, by its core id's name, if it is not a
    rules deck: topic `be` is `te-grammar-be` (today the single-file
    `te-en-grammar-be`). A grammar deck not yet turned into rules counts as
    one topic; once it is, its topics are its rules, and its own name is no
    topic unless a rule has it: `case-endings` next to `lo`, `ki`, `to` and
    `nunci` would count the table twice, and is an error.

  A planned unit's topic is any name, `[a-z0-9-]+`, checked once the unit is
  written.
- **Words are counted per course** from a unit's decks in that course, as
  distinct card ids written or listed by ref: the vocab cards that are not
  phrasebook cards, not `pos: phrase`, and are one word, or a noun, verb,
  adjective, adverb or pronoun of several. Alphabet decks, grammar and rules
  decks, reading decks and `"*"` count none. Each course's count is held to
  the unit's one size.
- **The B1 decks** of a course are its decks for the core ids the plan's
  units list, less the alphabet decks and reading decks. They are held to
  the B1 checks: every word covered by a word card or a
  [base](#base-words-bases), every word card with a [note](#notes) (a
  warning), every word of a rule's kind with its
  [row](#every-word-of-its-kind-has-its-row), and the
  [phrasebook](#the-phrasebook)'s size and place. A B1 deck still
  single-file is warned of: it is split into a core and its layers as the
  plan is written.
- **The sizes:** about 700 words for A1, 900 more for A2 and 1,200 more for
  B1, about 2,800 in all (owner, 2026-10-09; low confidence). The
  validator's info line gives each level's words, the grammar topics and the
  units planned. It warns of a level outside half to one and a half times
  its size, of planned words up to B1 outside 2,000–3,500, of a written unit
  with more words than it plans for learners from some native language
  (raise `words`), and of a planned theme not yet in `decks/themes.yaml`.

### Regions

A language's regions are listed in its path, since they are the language's
and every native language shares them. The app asks a rater "Where you
speak Telugu", offering the regions and then Elsewhere, and a card's
[region note](#notes) names the regions it is about.

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
| `id` | A region id: starts with a letter, `[a-z0-9-]+`, not one of YAML 1.1's boolean words, unique in the path, and not `elsewhere`, which the app keeps for its own answer. **Permanent, as a card id is:** a rater's answers and the cards' region notes name it. Rename a region's `name`, never its `id`; retire one only when nothing names it. |
| `name` | The region's name, keyed by language code as a facts text is: `en` required, any other beside it. The app shows the learner's (or rater's) language where given, else English. [Script in prose](#script-in-prose-always-with-its-reading) applies per key: a Telugu name under `"en"` gives its reading, తెలంగాణ (telaṅgāṇa). |

The list is in the order the app shows it. The app adds **Elsewhere** after
it, an interface string, never deck data, stored as `elsewhere`. A language
with no `regions` asks no region question.

The validator checks the list's shape, and that every region a note names
is a region of its language's path, given or on disk: a note naming one the
path does not list, or a language whose path lists none, is an error.

Telugu's regions are Telangana, Coastal Andhra and Rayalaseema, the three
its dialects are usually grouped by. Bengali's are its dialect groups, each
named with example districts so that a rater who does not know the terms
can still place themselves: Rāṛhī, Vaṅgīya, Varendrī, Kāmarūpī, Mānbhūmī
and south-eastern. A native reviewer checks both lists before any rating
names a region.

## Writing a B1 course

The checklist for writing a course up to B1, deck by deck, in the order
below. Each step is one or more small commits that validate on their own:
run `python3 tools/validate_decks.py decks/` after every one, and fix every
error before moving on. Read the warnings; do not leave them unexplained.

**Before you start:**

- Read [AGENTS.md](../AGENTS.md), `docs/plans/b1-plans.md`,
  `docs/plans/words-rules-sentences.md` and `docs/plans/native-layers.md`,
  and this file through.
- **Card ids are permanent.** Splitting, moving or converting a deck keeps
  every id it has. A new card takes
  `python3 tools/validate_decks.py --next-id <lang>`, and nothing else does.
- **Quote every text value and every text key** ([YAML values](#yaml-values)).
- **Every word of the script quoted in prose carries its ISO 15919 reading**
  ([Script in prose](#script-in-prose-always-with-its-reading)): in
  meanings, notes, labels, explanations, descriptions and passage
  descriptions. `python3 tools/transcribe.py <code> "<word>" <as typed>`
  writes the reading and the IPA.
- **Each deck is a core and its English layer**
  ([Core and layer files](#core-and-layer-files)): the phrasebook, theme,
  sound, script, number, rules and sentence decks alike. Reading decks stay
  single-file, and so do the files beside the decks (facts, number rules,
  romanisation, sounds, script guide, path).

**In this order:**

1. **The romanisation file**, `<lang>-romanisation.yaml`
   ([Romanisation files](#romanisation-files)). Every reading you write is
   checked against it, so settle it first. Where it exists, check it rather
   than rewrite it.
2. **The path's B1 plan**, in the language's path, `<lang>-path.yaml`
   ([The B1 plan](#the-b1-plan)), by core id, with the language's
   [regions](#regions). Write every unit up to B1 in teaching order: the
   written units as mappings with `words` and `grammar`, the rest as
   `planned` units with their listening and reading passages, each with an
   `id` and its English description, and the three milestones, about 700,
   1,600 and 2,800 words in. Take the themes
   and grammar of each level from the CEFR skeleton in `b1-plans.md`, and
   their order from `docs/plans/language-paths-scheme.md` for the language's
   family. The first unit holds the phrasebook. The plan comes before the
   first core: once the language has one, the path must have its plan. A
   new theme goes into `decks/themes.yaml` in a small change of its own,
   agreed with whoever is writing the other courses, since every course
   shares the file and theme ids are permanent.
3. **Split the existing decks** the plan lists into a core and an English
   layer ([Splitting a deck](#splitting-a-deck)), one deck per commit, each
   old file deleted in the same commit. The first commit adds
   `- decks/<lang>/en/` to `pubspec.yaml`, alone. Give each word its `pos`
   as you go (a pronoun is `pronoun`): rules decks select their rows by it.
4. **The sounds file and the script guide**, `<lang>-sounds.yaml` and
   `<lang>-script.yaml` ([Sounds files](#sounds-files),
   [Script guides](#script-guides)): every contrast of sounds the language
   has and English lacks, with its pairs, and every feature of the script a
   learner from English misses. Check them where they exist.
5. **The phrasebook**, the core `<lang>-phrasebook` and its layer
   `<lang>-en-phrasebook` ([The phrasebook](#the-phrasebook)): 15 to 25
   survival phrases, `pos: "phrase"` and `phrasebook: true`, listed in the
   first unit. Every word of each has a `bases` entry: by `ref` where a
   word card teaches it, else written in full, and turned into a `ref`
   when its word card is written. A phrase moved out of `first-words` keeps
   its id.
6. **Sounds and minimal pairs**, the sound-differences deck and its layer:
   pairs of everyday words that differ in one contrast of the sounds file,
   each card tagged with the contrast's `id`. Each word of a pair has a
   `pair` note naming the other ([Notes](#notes)), and both are taught in
   the course: in this deck, or in a theme deck by `ref`.
7. **Then each unit, in the path's order,** and within it:
   1. **Its theme's words**, the theme core `<lang>-<theme>` and its layer
      `<lang>-en-<theme>`: single words first, each with
      - its `reading` and `ipa`, and a `pos`;
      - **one or more typed notes** (`behaviour`, `usage`, `culture`,
        `note`, `pair`): their words and readings in the core, their texts
        in the layer. A culture note names its `source`, and the file that
        holds it is tagged `unreviewed`;
      - **`wiktionary: true` in the layer** only where you have seen
        en.wiktionary's page for the target, with a section for the
        language ([The Wiktionary link](#the-wiktionary-link));
      - **a `picture`** only from `tools/data/picture-mapping.json`: an
        emoji whose `kept` meaning is the card's meaning, never one of its
        `dropped` matches, and only for a concrete word. Its image must be in
        `assets/pictures/`, or the validator fails;
        `python3 tools/pictures.py path/to/noto-emoji` copies it there. A
        card that has a picture keeps it;
      - **a `pair` note** where a word of the course sounds almost the same
        (a short or a long vowel, the tongue on the teeth or curled back,
        a single or a double consonant), naming the partner, which must be
        taught in the course; the partner gets the note naming this word;
      - **`bases`** on every inflected or derived word, in the target and
        in each example.
   2. **Its rules**, a rules core `<lang>-grammar-<topic>` and its layer
      ([Rules decks](#rules-decks)): word forms first (a noun's plural,
      oblique stem, case endings and postpositions; pronouns and their
      forms; a verb's person and tense endings), then conjunctions. **Every
      form is listed for every word,** and every word of the table's kind
      that a B1 deck teaches has its row: the words of this unit and of
      every earlier one. A word added later adds its row to every table of
      its kind in the same change; only a word the rule does not apply to,
      such as an indeclinable loanword, goes in `applies_to.except`
      instead. Each rule's explanation quotes its words
      through `{1}`, `{2}`. The unit's `grammar` lists the rules' names. A
      grammar deck turned into rules keeps its cell ids: the core's id is
      the old id without `en`, each row's `key` is the old entry's key, and
      the slots keep their order. An old grammar deck of fixed phrases
      becomes words, a rules deck and sentences instead.
   3. **Its sentences**, a core `<lang>-<theme>-sentences` and its layer,
      with no `theme`, since a course has one deck per theme: sentences
      built from the words and rules taught so far, `pos: "phrase"`, each
      with `rules` naming every rule it uses
      ([Sentences and their rules](#sentences-and-their-rules-rules)), and
      `bases` for every word that is not a word card's target. An old
      deck's sentences move here with their ids.
   4. **Its passages**, when the unit has any: a
      [reading deck](#reading-decks) `<lang>-en-reading-<name>`,
      single-file, in a unit after the themes its words come from, its
      questions' ids from `--next-id`, every prompt in English (and in
      Bengali and Hindi where you can). It is also the unit's listening
      passage: a reading question is heard in `listening`, its text hidden
      until it is answered, so a passage written to be heard, a
      conversation or an announcement, is a reading deck too. Use the
      words the course teaches: the validator lists those it does not. A
      reading deck that needs the script is listed in `alphabet`; a unit of
      reading decks that are not gives `words: 0`.

   When a planned unit's deck is written, the unit's `planned` becomes
   `decks` in the same change, and its `words` is checked against what it
   now counts.
8. **Numbers**, in their place on the path: the `numbers-1-20` and
   `numbers-big` decks and their layers, then `<lang>-numbers.yaml`
   ([Number rules](#number-rules)), which may spell only with the words
   those decks teach.
9. **Script decks**, in their place on the path: the letters, vowel signs,
   conjuncts and script reading decks, each listed in `alphabet`, split like
   the rest. A letter that sounds exactly like another is drilled by reading
   and writing only ([Paths](#paths)). The B1 checks pass them
   by.
10. **The facts file**, `<lang>-facts.yaml` ([Facts files](#facts-files)):
    at least 30 facts without a `contrast`, each in English, Bengali and
    Hindi, with a `source` for anything a reader could doubt, and every word
    they quote carrying its reading in each language's text.
11. **Last, across the course:**
    - every pair note's partner taught in the course, and every pair noted
      on both of its words;
    - every word card with a note, and every word of every text covered by
      a word card or a base: the validator lists what is missing;
    - each unit's `words` at least what it counts, and the levels near 700,
      900 and 1,200 words;
    - every deck on the path once, and every split deck's old file gone;
    - `python3 tools/validate_decks.py decks/` with no error, and
      `flutter test`, which parses every bundled deck;
    - the work rated by an independent rater, as
      [AGENTS.md](../AGENTS.md) asks.

## Adding your own deck

In the app, Decks > Add a deck > From a file saves a template,
[`assets/deck-template.yaml`](../assets/deck-template.yaml), and adds a deck
written from it. It is a [vocab deck](#vocab-decks) like any other, and any
deck the app can read can be added, grammar and reading decks too. An added
deck is single-file: cores, layers and rules decks are for the repository.
The app checks it first, and refuses:

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
the Indic languages the scheme is **letters based on ISO 15919's, spelled as
the word is said** ([ADR-0025](adr/0025-iso-15919-and-ipa.md)). It is not
strict ISO 15919: where a learner is better served, it departs from the
standard. The
[README](../README.md#how-words-are-written-in-latin-letters-iso-15919) has
the table of letters and the
[list of departures](../README.md#where-the-readings-depart-from-iso-15919).

- Lowercase letters of ISO 15919, with spaces and the sentence's own
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
scheme: "Based on ISO 15919's letters, spelled as said: …"
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
| `standard` | no | `"ISO 15919"` when the readings are based on its letters, with the departures the `scheme` names. Without it, readings are lowercase ASCII. |
| `typed` | no, and only with `standard` | Pairs of the standard's letters and how they are typed: `["ś", "sh"]`. Each reading is spelled so, read from the left, the longest letters first, before an answer is compared with it. An empty second item means the letters are not typed, as Assamese chat leaves out m̐. |
| `equivalents` | yes | Groups of two or more lowercase spellings. The first of each group is the one the decks use. A spelling is in one group only. |

Once a language has the file, the validator checks every reading in that
language's files, cards, refs, grammar rows, passages, glossaries, sounds and
script guides, is in the scheme: lowercase, no capitals, and no diacritics
but the letters of ISO 15919 where the file names that standard. It checks every
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
| `grammarUnderstood` | a form of a [rules deck](#rules-decks)'s table, with its reading | its meaning, chosen among the meanings of the same word's forms: grammar understood | automatically |
| `grammar` | expanded `prompt`; on a rules deck's cell, the word with its reading and the meaning to express | the form, chosen among the same word's forms or typed: grammar produced | automatically |
| `speaking` | `native` | `target`, said aloud | automatically, from what the phone's speech recogniser heard |
| `reading` | a passage, then a question about it | the right choice | automatically |

A reading question is also heard, in `listening`: the passage is read aloud
and its text is hidden until the question is answered. A card cannot take
`reading`; only a [reading deck](#reading-decks)'s questions do. Nor can it
take `grammarUnderstood`; only a rules table's cells do.

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
