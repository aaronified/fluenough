---
name: build-deck
description: Use when building or extending a Fluenough deck, including writing the next planned unit of a language's B1 plan (a core in decks/<lang>/ plus its English layer in decks/<lang>/en/). Not for app code.
---

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
  te mahat/amahat; bn and as none); and confusables on a sentence used for word
  order. **The validator enforces only what it can check** (meaning, reading,
  2 examples per word card, gender on nouns in gendered languages, as errors
  once a language is filled in). Data that is "mandatory when available"
  (confusables, root word, synonyms, antonyms, minimal pairs and the rest) is
  never a validator error, so **you, the builder, must add it whenever it is
  available**, and reviewers check it (owner, 2026-10-13, #506; review
  pipeline work is #508). The new fields (`confusables`, the gender classes, the rest) arrive
  with their format and validator change (fields first), and DECK-FORMAT does
  not allow them yet. Until then, fill what DECK-FORMAT allows (reading, ipa,
  alt_target, pos, gender, examples, notes, bases, pair, picture where it
  fits), at least 2 examples on a word card, and do not set modes to
  restrict a card to one drill unless DECK-FORMAT requires it. When a field
  lands, DECK-FORMAT and this list are updated in the same change. New text
  for the learner goes in each native layer.
- Closed groups (articles, pronouns, genders, cases and postpositions,
  demonstratives, question words, conjunctions, days, months, number words
  1-10, colours) need a set card that introduces the whole set, "Teach only"
  (owner, 2026-10-13, #506); its format is approved (kind `set`,
  members by card id, explanation in the layer; DECK-FORMAT, "Set cards")
  and DECK-FORMAT does not allow it yet.
- Model: Sonnet writes decks (CLAUDE.md). Haiku for large reads. A small
  change to a tool or the validator is Sonnet, reviewed by Opus; only a
  complex change across several files is Opus (owner, 2026-10-16).

## Checklist

1. **Pick the unit.** In `decks/<lang>/<lang>-path.yaml`, take the first
   `planned` unit in teaching order (list order), or the one you were asked
   for. Read its planned `id`, `theme` or `grammar`, `words`, and its
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
   - Bengali and Telugu are partly split: Bengali has cores in `decks/bn`
     with layers in `decks/bn/en`, plus 54 single-file `bn-en-*` decks;
     Telugu has 28 cores and 52 single-file decks. Those single-file decks
     stay until issue #498 is done. New decks there are written split anyway;
     do not convert the old ones in passing.
4. **Content rules.**
   - Transliteration in deck prose: every non-Latin word in a note, meaning
     or description is followed by its reading ("Script in prose").
   - When a base word changes its stem in a card's form, say so in that
     card's notes ("Base words"). Every inflected word has a `bases` entry.
   - The meaning of a card never changes between layers or edits.
   - Tag the files `"unreviewed"`; a culture note needs a `source`
     ([docs/REVIEWING.md](../../../docs/REVIEWING.md) is how a speaker clears it).
   - Every word card gets at least one typed note ("Notes").
   - Every word card gets at least 2 examples ("Card data", "Examples"):
     natural sentences that use the word, each with its `reading` and `ipa`
     in the core and its translation in each layer, keyed by the target.
     The validator makes fewer than 2 an error only for a language in
     `FILLED_LANGUAGES` (`tools/validate_decks.py`); write 2 anyway. An
     example taken from outside names its own `source`; one written for the
     deck has none.
5. **Update the path.** Turn the planned unit into a written one exactly as
   "The B1 plan" says: `planned` becomes `decks` (core ids, ending in `"*"`)
   in the same change, keep `words` at least what the unit now counts, keep
   `grammar` and any `milestone`. Each deck's core id appears on the path
   once. A theme not in `decks/themes.yaml` is added there with the first deck
   ("Writing a B1 course", step 2); theme ids are permanent. The first layer
   folder of a language needs its `pubspec.yaml` line, in a commit of its
   own ("Splitting a deck").
6. **Check.** Run both until clean:

   ```sh
   python3 tools/deck_index.py
   python3 tools/validate_decks.py decks/
   ```

   Errors block; read every warning and fix or explain it. Commit
   `decks/index.json` with the decks. Tools details: `tools/README.md`.
7. **Ship.** Never create tags and never edit CHANGELOG.md. For the owner's
   work, push straight to main; a deck-only change needs only "Validate
   decks" green (CLAUDE.md). Contributors open a pull request on a branch
   `deck/<name>` ([CONTRIBUTING.md](../../../CONTRIBUTING.md), AGENTS.md
   "Branches, commits, pull requests"). Get one independent review (Sonnet)
   before finishing; no extra passes. Say what you verified.
