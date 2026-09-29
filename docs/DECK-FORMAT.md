# Deck format, schema 1

A deck is a single UTF-8 YAML file. Filenames are `<deck-id>.yaml` and live
under `decks/<language-code>/`.

Two kinds of deck exist: `vocab` (a list of cards) and `grammar` (a pattern
table that expands into cards). A third kind of file, `facts`, holds a
language's daily facts rather than anything drilled. All three share the same
header.

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
| `id` | yes | Unique, `[a-z0-9-]+`, must equal the filename stem. |
| `name` | yes | Human-readable title. |
| `kind` | no | `vocab` (default), `grammar`, or `facts` for a [facts file](#facts-files). |
| `language` | yes | The language being learned. See below. |
| `native` | yes, except on a facts file | The language explanations are written in. |
| `license` | yes | SPDX identifier, or `CC0-1.0` for public domain. |
| `authors` | no | List of `{name, url?}`. |
| `source` | no | URL the content was derived from. |
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
id: es-core-100
name: Spanish Core 100
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [beginner, core]
cards:
  - id: es-core-0001
    target: la casa
    native: the house
    pos: noun
    tags: [noun, home]
```

### Card fields

| Field | Required | Notes |
|---|---|---|
| `id` | yes | Unique within the deck, `[a-z0-9-]+`. **Never reuse or renumber** — review history is keyed on it. |
| `target` | yes | The text in the language being learned. |
| `native` | yes | The meaning, in the learner's language. |
| `reading` | no | Romanisation or phonetic reading. Required in practice for non-Latin scripts. |
| `alt_target` | no | Additional answers accepted in production drills. |
| `alt_native` | no | Additional answers accepted in recognition drills. |
| `pos` | no | Part of speech: `noun`, `verb`, `adj`, `adv`, `phrase`, `particle`, `other`. |
| `gender` | no | Grammatical gender, free text (`m`, `f`, `n`, `c`…). |
| `tags` | no | Card-level tags. Drills can be filtered by tag. |
| `notes` | no | Usage note shown after answering. |
| `audio` | no | Asset path or URL overriding TTS for this card. |
| `examples` | no | List of `{target, native}` sentence pairs. |
| `modes` | no | Which drills this card participates in. Defaults to all applicable, except that a `pos: phrase` card is not typed: it defaults to recognition and listening. |

### A note on `id`

Card ids are the primary key of the user's entire review history. Changing an
id orphans that card's history; reusing one silently attaches old history to
new content. Treat ids as immutable once published. To retire a card, delete
it — do not repurpose it.

---

## Grammar decks

A grammar deck describes an inflection table and expands into one production
card per cell. This keeps the app free of per-language grammar logic.

```yaml
schema: 1
id: es-grammar-present-ar
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
| `entries` | yes | List of `{lemma, gloss, forms}`, each with an optional `key`. |
| `notes` | no | Shown after answering. |

`forms` must supply a key for every slot. A cell with no valid form (a
defective verb, say) may be `null` and is skipped rather than drilled.

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

- **id** — `<deck-id>-<key>-<slot-index>`, stable as long as `slots` keeps
  its order and the key is unchanged. The key is the entry's `key`, or its
  `lemma` when it has none. **Reordering `slots` rewrites every id in
  the deck and orphans its history.** Append new slots at the end.
- **target** — `forms[slot]`
- **native** — `prompt` with substitutions applied
- **modes** — `grammar` only

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
language teaches the same themes in the same order, with its own words.

- **Theme ids are permanent**, like card ids: decks name their theme by it.
- **One deck per theme per course.** The validator fails a second
  `hi-en` deck for `market`, and a `theme` that `themes.yaml` does not list.
- **New cards follow the path.** A course's theme decks are drilled in the
  file's order unless the learner picks a theme. Nothing is locked.
- **Phrases are not typed.** Mark a card of more than one word `pos: phrase`:
  it gets recognition and listening, and no production drill, since a whole
  sentence is too hard to grade fairly.
- **Grammar decks are not themes.** They stay separate from the path.

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
        inside or at the end of a word, as in सड़क (sadak, road) and पढ़ना
        (padhna, to read)."
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

`listening` is offered only when a TTS voice for `language.tts` is available on
the device. `recognition` is self-graded because judging a free-text
translation is beyond what an offline app should attempt.

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
- id: ja-hiragana-025
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
