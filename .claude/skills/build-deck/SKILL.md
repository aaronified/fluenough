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
7. **Check.** Run both until clean:

   ```sh
   python3 tools/deck_index.py
   python3 tools/validate_decks.py decks/
   ```

   Errors block; read every warning and fix or explain it. Commit
   `decks/index.json` with the decks. Tools details: `tools/README.md`.
8. **Ship.** Never create tags. For the owner's work, open a pull request
   (owner, 2026-10-16: "Do use PRs for everything"); a deck-only change
   needs only "Validate decks" and "Released app reads the decks" green
   (CLAUDE.md). Contributors open a pull request on a branch
   `deck/<name>` ([CONTRIBUTING.md](../../../CONTRIBUTING.md), AGENTS.md
   "Branches, commits, pull requests"). Get one independent review (Sonnet)
   before finishing; no extra passes. Say what you verified.
