# Plan: a B1 plan in every path

Written 2026-10-06. **After the skill model (done: ADR-0034), before deck
downloads** (owner's order).

## What the owner asked

> Every deck path will have a B1 plan from now on. The app will use this
> explicitly.

Asked what it should entail, the owner decided:

- **Completeness:** words drive the percentage, and grammar topics are shown
  beside it: "18% of B1 · 12 of 30 grammar topics".
- **Themes per level** come from the current CEFR descriptors.
- **Units not written yet** show to learners as "Coming".
- **When:** the plans are written before deck downloads, so the deck index
  is designed around them.

## What exists

- A path (`decks/<lang>/<lang>-<native>-path.yaml`, ADR-0013) is a list of
  units, each a list of existing deck ids in teaching order, plus the decks
  that need the alphabet. Telugu's has 30 units. Paths become one per
  language learnt, `<lang>-path.yaml`, naming core ids (owner,
  2026-10-09; below).
- Nothing marks a level, and nothing records what is still to write.
- `language-paths.md` sets B1 as the target, about 2,500–3,000 words, and
  estimates 280–420 hours of content for the seven Indian languages to get
  there. Today they teach 450–680 vocabulary cards each, and Spanish 41.

## What a B1 plan is

Written in the path, by whoever writes the course, and read by the app
unchanged:

1. **Every unit up to B1**, written or not, in teaching order.
2. **A unit not written yet** is `planned`, with its future deck id and its
   theme or grammar topic.
3. **Each unit's planned size** in words (`words`). A grammar unit names its
   topic (`grammar`), which counts toward the grammar figure, not the words.
4. **Milestones:** `milestone: A1`, `A2` and `B1` on the unit where each
   level ends.

```yaml
units:
  - decks: ["te-family", "te-grammar-be", "*"]
    words: 45
    grammar: ["be"]
  - decks: ["te-work", "te-grammar-demonstratives", "*"]
    words: 45
    grammar: ["demonstratives"]
    milestone: "A1"
  - planned: { id: "te-health", theme: "health", words: 60 }
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
```

The path names each deck by its core id (`te-family`), and a learner is
taught their own native language's deck for it (`te-en-family` from
English); the exact format is `b1-format-spec.md`, section 10.

Units after the B1 mark, if any, are written as today. Units with the
alphabet stay where they are; they count neither words nor grammar.

## The skeleton, from the CEFR descriptors

The CEFR's global scale describes each level by what a learner can do
(Council of Europe, 2001, kept in the 2020 Companion Volume). Paraphrased:

| Level | Can do | Themes and grammar it implies |
|---|---|---|
| A1 | Use everyday expressions for concrete needs; introduce themselves and others; ask and answer about where they live, people they know and what they have | Greetings, self and family, home, numbers, basic needs; present tense, questions, pronouns |
| A2 | Understand frequent expressions on personal and family information, shopping, local geography and work; exchange information on routine matters; describe their background and surroundings | Shopping, directions, work, daily routine, time and calendar; past, future, comparison |
| B1 | Follow the main points of clear standard speech on work, school and leisure; handle most situations while travelling; write simple connected text; describe experiences, hopes and plans, and give reasons and opinions | Travel, health, services, feelings, opinions, events and news; subordinate clauses, conditionals, reported speech, the language's own B1 grammar |

The descriptors describe abilities, not word lists, so the skeleton turns
each into themes and grammar topics. It is written once and shared. Each
language adds its family's grammar in the scheme's order
(`language-paths-scheme.md`).

## Films, songs and books: off the path

The owner first asked for films and songs "near the bottom" of the path,
then chose to make them, with books, an optional shelf the learner picks
from by interest: `books-films-songs.md`.

- They are **not units** of the B1 plan and never hold back the path.
- Each item on the shelf carries a level, A1, A2 or B1. Songs and films come
  at every level; books only at B1, for learners who learn the script. The
  finale, a great film without subtitles, is offered at the B1 mark.
- The words of famous songs' and films' titles are ordinary path
  vocabulary, in early units (#169; #170 is the first), as the owner
  confirmed. Only whole works stay on the shelf.
- They count toward neither words nor grammar topics. The picker can show
  them apart, e.g. "2 films, 1 book done".

## Where the app uses it

| Where | How |
|---|---|
| Language picker (`language-picker.md`) | "18% of B1 · 12 of 30 grammar topics": words = Σ min(a unit's words, its plan) ÷ Σ planned words up to B1; grammar = topics with a written unit ÷ topics planned |
| Decks tab | Planned units show greyed, with "Coming", in their place; they cannot be started |
| Lessons and Today | Planned units are skipped |
| Achievements (`achievements.md`) | The A1, A2 and B1 badges come from the milestones |
| Hours per language (`hours-per-language.md`) | "Hours left" counts down to the end of the B1 plan |
| Pacing (`language-paths.md`) | The scheme's phases line up with the milestones |
| Deck downloads ([ADR-0037](../adr/0037-decks-download-from-main.md)) | The index carries each plan and the counted words, so the picker shows completeness before a download |

The words a unit has are always counted from its decks: distinct
vocabulary cards. Script decks, grammar tables and learners' own decks
(`"*"`) are left out.

## Writing the planned decks

Every deck written for a B1 plan follows "Script in prose" in
`docs/DECK-FORMAT.md`, as the owner asked: "Always keep the transliteration,
even in descriptions or labels." Each word quoted in a deck's notes,
meanings, labels, descriptions and facts carries its ISO 15919 reading,
లేదు (lēdu), so that a beginner who cannot read the script yet can read
them. The validator rejects a deck that leaves one out.

### Decided, 2026-10-09

- **The format first:** the B1 format (phrasebook, rule cards, `rules:`,
  `bases:`, typed notes, planned units, core and layer) is built in the
  parser, the validator and `docs/DECK-FORMAT.md` before any B1 deck is
  written, so that what is written validates. Then one agent writes the
  Bengali course and another the Telugu one (Sonnet writes the decks;
  CLAUDE.md).
- **A1 decks only, for now** (owner, 2026-10-09: "once B1 plan is done,
  we will only create A1 level decks (if any existing deck goes beyond,
  that's okay) for Bengali and Telugu"). The B1 plan is still written in
  full, every unit to B1 with its passages, but the deck agents write
  decks for the A1 units only; A2 and B1 units stay planned ("Coming").
  An existing deck that already reaches past A1 stays as it is.
- **Pictures:** the agents use `tools/data/picture-mapping.json`, the
  meanings already matched to Noto Emoji pictures and checked, with the
  matches dropped and why. The 330 cards given pictures keep them.
- **Colours:** a shade of the accent colour each for a card's word in the
  script, its ISO reading, its IPA and its meaning, on every screen that
  shows a card, checked for contrast in light and dark.

### Format details, settled 2026-10-09

- **A rule's forms are listed for every word,** not made from a stem with
  exceptions: exact for Telugu's oblique stems (ఇల్లు (illu) → ఇంట్లో
  (iṇṭlō)), and the validator checks every taught word of the rule's kind
  has its row (owner).
- **A layer's files live in `decks/<lang>/<native>/`,** the core in
  `decks/<lang>/` (owner).
- **Notes about the language learnt** keep their language facts (the
  words and readings) in the core; each layer writes the explanation
  around them in its own language (owner).
- **Words per level:** A1 700, A2 900 more, B1 1,200 more (about 700,
  1,600 and 2,800 in all; low confidence, scaled from English, Milton &
  Alexiou 2009), and each planned unit names its listening and reading
  passages too (owner).
- **Paths are one per language learnt now** (`te-path.yaml`, shared by every
  native layer), not one per course (owner).
- **The minimal-pair partner comes from the card's pair notes;** a B1 core
  has no `pair:` of its own; existing decks' `pair:` still works (owner).
- **A B1 plan is required on a path once its language has a core** (written
  in the new format), and on every path once all eight have plans (owner).
- **Planned units must name their listening and reading passages** (an
  error); written units need none (owner).
- The format is built on its own branch, in parallel with the skill model,
  so that the Bengali and Telugu deck agents can start (owner).

### The format's open questions, answered 2026-10-09

The owner's answers to `b1-format-spec.md`'s questions (that spec's last
section has them all):

- **One path per language learnt,** `<lang>-path.yaml`, shared by every
  native layer, now, before the deck agents start: it lists core ids, and
  each passage is named once with a description per native language.
  Today's course paths move to it once.
- **Grammar understood is choosing what a form means;** choosing among the
  same word's forms, or typing the form, is grammar produced.
- **A plan is required** on a path whose language has a core; every
  planned unit names its passages; a grammar topic is one rule; scripts
  without spaces wait; pairs come from pair notes.
- **Regions** (the owner asked where the rating screen's "Where you speak
  Telugu" is defined): in the language's path, `regions:`, each with an
  id and a name per native language; the app adds "Elsewhere". A rater's
  region and a card's region note name them.

### Phrasebook, words, rules, then sentences

Each unit of a B1 plan is written in the order `words-rules-sentences.md`
sets: its theme's words, then the rules they need, then its sentences, which
unlock only once their words and rules are known. A small phrasebook comes
first in the course, taught whole.

### Base words on every card

The owner: "all derived words on a card will also show their base words on
the cards (like for 'he went to our school', card shall also have 'go' and
'we')." So a card names the base of every inflected or derived word in its
target and in its examples:

```yaml
  - id: hi-0712
    target: "वह हमारे स्कूल गया।"
    native: "He went to our school."
    reading: "vah hamāre skūl gayā"
    bases:
      - { word: "गया", ref: hi-0201 }     # जाना (jānā), to go
      - { word: "हमारे", ref: hi-0045 }   # हम (ham), we
```

- **`ref`** names the card that teaches the base, so its target, reading
  and meaning are shown from that card, in the learner's own language
  (`native-layers.md`). A base no card teaches is written in full instead:
  `base`, `reading`, and its meaning in the layer.
- **Shown** on the lesson's teach card, and in reviews once the question is
  answered, with the other taught details: "गया ← जाना (jānā), to go;
  हमारे ← हम (ham), we". Never before an answer, since on a Write question it
  would give the answer away.
- **Examples** carry their own `bases` the same way.
- **The validator,** for every deck in a B1 plan:
  - every word of a target or example that is not itself the target of a
    card in the course has a `bases` entry;
  - every `ref` names a card, and every `word` occurs in its text.

  Words are split at spaces, punctuation dropped. Scripts without spaces
  need their words given (`language-paths.md`).
- **Existing decks** gain their bases as each language's B1 plan is
  written. A tool, `tools/suggest_bases.py`, proposes them from the course's
  own cards, and the writer confirms each one.

### Notes, and a Wiktionary link, on every word card

The owner: "we need to add a wikitionary link to every word card so that the
user can check the word out in detail, including etymology. And add
informative notes in every card when taught ... Multiple notes per card is
fine. The app will randomly pick one note fact when teaching / showing after
answers."

**Notes become a list of facts,** each with its kind:

```yaml
    notes:
      - { kind: pair, ref: te-0412, text: "Not కాలం (kālaṁ), time: the a is long there." }
      - { kind: culture, text: "…", source: "…" }
      - { kind: usage, text: "Also 'pen-name' in old usage." }
```

| Kind | What it says |
|---|---|
| `pair` | A minimal pair: a word of the language that sounds almost the same |
| `culture` | Its cultural significance |
| `usage` | Another context it is used in, or another sense |
| `behaviour` | How it behaves unlike similar words: an irregular form, a gender, a use |
| `note` | Anything else worth knowing |

- **One note at a time,** shown when the word is taught, and after an
  answer with the other taught details. Shuffled, never repeated, until every
  note of the card has been shown once (owner's choice).
- **Every word card should have one or more;** a word card with none gets a
  validator *warning*, not an error (owner's choice).
- **`pair` notes are proposed by a tool:** course words whose readings
  differ by one sound, such as కలం (kalaṁ) and కాలం (kālaṁ). The same pairs
  give Hear its sound-alike options (ADR-0034).
- **A `pair` note names its partner** (`ref`, the card of the word that
  sounds almost the same).
- **`culture` notes follow the culture-deck rules (#99):** each checkable
  claim names its `source`, and the deck stays marked unreviewed until a
  speaker checks it (owner's choice).
- **Transliteration** ("Script in prose") applies to every note. Notes live
  in the native layer (`native-layers.md`).
- **Today's single `notes` string** reads as one note of kind `note`, so
  existing decks keep working until they are rewritten.

**The minimal-pair button.** The owner: "the minimal pairs can be a button
where found and clicking it will show the words side by side and let the
user play their sounds and practice them together (like whether the speech
is detecting kalam or kaalam) in that same card. No logging here, pure
practice."

- **Shown** on a card with a `pair` note, when it is taught and after an
  answer, with the taught details. Never before an answer: there it would
  give the answer away, above all when the partner is among Hear's options.
- **It opens, on the same card, the two words side by side,** each with
  its reading and meaning:
  - **Play each word,** at normal and slow speed;
  - **Say one:** the phone listens and shows what it heard ("Heard: కాలం
    (kālaṁ), time"), and which of the two it matched, or neither. Only
    where speaking is on;
  - **Which did you hear?:** the app plays one of the two at random, and the
    learner taps which. It says right or wrong.
- **Nothing is recorded:** no review, no schedule, no strength. It is
  practice only.
- **The phone's recogniser prefers common words,** and may miss vowel
  length in a single word. So the panel says what was heard, not whether
  the learner said it right.
- With sound off, or no voice for the language, the speakers and "Which did
  you hear?" are greyed out, as elsewhere.

**The Wiktionary link** opens the word's entry, with its etymology, in the
browser:

- It is built from the word and the language, not stored:
  `en.wiktionary.org/wiki/<word>#Telugu`. For a sentence or an inflected
  form, it is built for each base word (`bases`). A learner taught from
  Bengali gets bn.wiktionary, with the native layers.
- **Shown only where Wiktionary has an entry** (owner's choice). A tool
  checks each word against Wiktionary's extracts (kaikki.org, as
  `wiktionary-ipa.md` uses), and marks the words that have one. Many Indian
  language words have none yet.
- Nothing is fetched until the learner taps the link.

## What the validator checks

- **Errors:**
  - a path without its A1, A2 and B1 marks, in that order;
  - a unit up to B1 without a planned size or grammar topic;
  - a planned id that does not follow deck naming, or names a deck that
    already exists.
- **Warnings:**
  - a unit with more words than planned, since then the plan needs raising;
  - planned words up to B1 outside 2,000–3,500, as a sanity check. Nothing
    is stored.
- When a planned deck's file appears, it counts as written. Its `planned`
  entry is turned into `decks` in the same change.

## What it takes

1. **Format:** the path parser, the validator, `docs/DECK-FORMAT.md`, and
   an ADR.
2. **The skeleton**, from the descriptors above.
3. **A plan for each of the eight languages,** in its one path. Telugu and Kannada are written
   together with their reorder to the Dravidian order, which
   `language-paths.md` calls for.
4. **"Coming"** on the Decks tab, and lessons skipping planned units.
5. **Base words:** the `bases` field in the parser, the validator and
   `docs/DECK-FORMAT.md`; showing them with the taught details; and
   `tools/suggest_bases.py`.
6. **Notes:**
   - the list of typed notes, read alongside today's string;
   - shuffled without repeats when teaching and after answers;
   - a tool proposing `pair` notes;
   - the validator's warning, and sources on `culture`.
7. **The minimal-pair button and panel:** play, say one, which did you
   hear; recording nothing.
8. **The Wiktionary link:** marked by a tool from Wiktionary's extracts,
   and shown with the taught details.
9. **Content:** notes for every word card, written with each language's B1
   plan.
10. **Tests:** the parser, each validator rule, the counts, the Decks tab
   and lessons with planned units, base words shown only after an answer,
   every note shown once before any repeats, the minimal-pair panel shown
   only after an answer and recording nothing, and the Wiktionary link only
   where an entry exists.

## To decide

Nothing left: see "Format details, settled" above.

## Estimate

| Part | Hours |
|---|---|
| Format, parser, validator, docs, ADR | 2–3 |
| The skeleton | 2–3 |
| Plans for the seven Indian languages | 7–14 |
| Spanish | 2 |
| "Coming" on the Decks tab, lessons skipping planned units | 1–2 |
| Base words: format, validator, display, suggestion tool | 3–5 |
| Notes: format, shuffle, pair tool, validator | 3–4 |
| Minimal-pair panel: play, say one, which did you hear | 3–4 |
| Wiktionary link: marking tool, display | 2–3 |
| **All** | **25–40** |

Writing the notes themselves is content, per language, outside these hours:
about 3,800 word cards today.

Writing the plans does not write the content. The content to reach B1 is
`language-paths.md`'s estimate. Confidence: medium.
