# Plan: one core per deck, and a layer per native language

Written 2026-10-06. **With the B1 plans** (`b1-plans.md`), owner's choice:
decks are split as their B1 plans are written, so that deck downloads
(`decks-from-github.md`) design their index around cores and layers.

## What the owner asked

> BTW, the native language part in each deck can be kept modular as well. To
> some extent (some cards will only be relevant in certain native languages).
> Discuss. I am thinking of easy lateral expansion later via translations (and
> minimal additions to the deck containing the learning language content).

Decided with the owner:

- **A core plus a layer per native language,** not translations inline.
- **A card a layer does not translate is skipped** when learning from that
  language. It is not shown in English.
- **When:** with the B1 plans.

## What exists

- **A card's id names only the language learnt** (`hi-0042`, ADR-0005), so
  one word is one schedule whatever language teaches it. That stays.
- **The learner's own language is inline:** `native`, `notes`, the examples'
  translations, `description` and `name`, and a grammar deck's `prompt`,
  `gloss` and slot labels. Every deck is `<lang>-en-*`; teaching Hindi from
  Bengali would mean copying every deck.
- **Two parts are already modular:** facts (`text: { en, bn, hi }`) and
  reading questions (keyed by language, `en` required).
- **Paths** are per pair: `hi-en-path.yaml`.

## The design

- **The core,** `decks/hi/hi-family.yaml`: what belongs to the language
  learnt, the same for every learner:
  - ids, `target`, `reading`, `ipa`, `alt_target`, `pos`, `gender`, `audio`;
  - the examples' targets;
  - a grammar deck's entries, forms and their readings and IPA, with its slot
    keys.
- **A layer,** `hi-family.en.yaml` (where it lives is to decide): what belongs to the learner's
  language, keyed by card id:
  - `native`, `notes`, the examples' translations;
  - the deck's `name` and `description`;
  - a grammar deck's `prompt`, `gloss` and slot labels.
- **Cards for some native languages only** live in that layer, with their
  own ids from the language's sequence: Bengali false friends for a Bengali
  speaker learning Hindi, or the contrasts only they need. The core stays
  shared.
- **A missing translation skips the card** for that native language. The
  layer's coverage of its core shows on the language picker, beside B1
  completeness.
- **Transliteration** ("Script in prose", `docs/DECK-FORMAT.md`) applies in
  every layer. A reading in the reader's own script also counts: a Bengali
  layer may write হ্যাঁ for हाँ.
- **Paths and B1 plans** are per language learnt (`hi-path.yaml`), shared by
  every layer.

## Adding a native language later

1. Copy the English layers, and translate `native`, `notes`, names and
   labels.
2. Add or drop the cards only that language needs.
3. No core file changes.

## What it takes

1. **Format:** the core and layer files, `docs/DECK-FORMAT.md`, and an ADR.
2. **The parser:** merge a core with the learner's layer, skipping cards the
   layer lacks.
3. **The validator:**
   - every layer card names a core card, or is a layer-only card;
   - a layer's coverage is reported;
   - transliteration holds in every layer.
4. **A tool** that splits today's `<lang>-en-*` decks into cores and English
   layers, keeping every id. It runs once per language, as each B1 plan is
   written.
5. **Paths** move to one per language learnt.
6. **Deck downloads:** the index lists cores and layers; a learner gets the
   cores and their own layers.
7. **Tests:**
   - the merge;
   - skipping untranslated cards;
   - layer-only cards;
   - ids unchanged by the split;
   - the validator's rules.

## To decide

Settled 2026-10-09 (owner): layers live in `decks/<lang>/<native>/`; notes
about the language learnt keep their language facts in the core, and each
layer writes the explanation around them.

## Estimate

| Part | Hours |
|---|---|
| Format, parser, validator, ADR | 4–6 |
| Split tool, and splitting the eight courses | 3–5 |
| Paths per language, index changes | 2–3 |

Confidence: medium.
