# Deck format, schema 1

A deck is a single UTF-8 YAML file. Filenames are `<deck-id>.yaml` and live
under `decks/<language-code>/`.

Two kinds of deck exist: `vocab` (a list of cards) and `grammar` (a pattern
table that expands into cards). They share the same header.

Validate before committing:

```sh
python3 tools/validate_decks.py decks/
```

---

## Header

Common to both kinds.

| Field | Required | Notes |
|---|---|---|
| `schema` | yes | Must be `1`. |
| `id` | yes | Unique, `[a-z0-9-]+`, must equal the filename stem. |
| `name` | yes | Human-readable title. |
| `kind` | no | `vocab` (default) or `grammar`. |
| `language` | yes | The language being learned. See below. |
| `native` | yes | The language explanations are written in. |
| `license` | yes | SPDX identifier, or `CC0-1.0` for public domain. |
| `authors` | no | List of `{name, url?}`. |
| `source` | no | URL the content was derived from. |
| `description` | no | One or two sentences. |
| `tags` | no | Deck-level tags, e.g. `[beginner, core]`. |

### `language`

| Field | Required | Notes |
|---|---|---|
| `code` | yes | BCP-47 primary subtag, e.g. `es`, `ja`, `pt`. |
| `name` | yes | English name of the language. |
| `script` | yes | One of `latin`, `cyrillic`, `greek`, `arabic`, `hebrew`, `devanagari`, `kana`, `han`, `hangul`, `thai`, `other`. |
| `tts` | no | BCP-47 tag handed to the TTS engine, e.g. `es-ES`, `pt-BR`. Defaults to `code`. Omitting it on a language with major regional variation is a mistake. |
| `rtl` | no | `true` for right-to-left scripts. Defaults to `false`. |

### `native`

`{code, name}` — same meaning, for the learner's own language.

---

## Vocab decks

```yaml
schema: 1
id: es-core-100
name: Spanish Core 100
kind: vocab
language: { code: es, name: Spanish, script: latin, tts: es-ES }
native:   { code: en, name: English }
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
| `modes` | no | Which drills this card participates in. Defaults to all applicable. |

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
language: { code: es, name: Spanish, script: latin, tts: es-ES }
native:   { code: en, name: English }
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
| `entries` | yes | List of `{lemma, gloss, forms}`. |
| `notes` | no | Shown after answering. |

`forms` must supply a key for every slot. A cell with no valid form (a
defective verb, say) may be `null` and is skipped rather than drilled.

### Expansion

Each `(entry, slot)` pair becomes one production card:

- **id** — `<deck-id>-<lemma>-<slot-index>`, stable as long as `slots` keeps
  its order and `lemma` is unchanged. **Reordering `slots` rewrites every id in
  the deck and orphans its history.** Append new slots at the end.
- **target** — `forms[slot]`
- **native** — `prompt` with substitutions applied
- **modes** — `grammar` only

---

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

1. Unicode NFC normalisation
2. trim, collapse internal whitespace
3. case folding
4. strip terminal punctuation

If that does not match, a second pass **also** strips diacritics (NFD, drop
combining marks) and leading articles declared for the language. A match at
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
