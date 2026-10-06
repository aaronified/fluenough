# Plan: choosing languages to learn, redesigned

Written 2026-10-06.

## What the owner asked

> Languages i am learning should be redesigned to match world class
> standards. It should have a search option for languages, show the deck
> completeness percentage (target B1) and the native languages available,
> users can select any for learning and choose whether they want to learn
> the script right there as well.

Asked whether to build it or plan it: "plan it in a way that can adapt to
the deck download feature" (`decks-from-github.md`).

## What exists

- `LearnLanguagesPage` (`lib/features/placement/`) is a list of checkboxes,
  one per language in the loaded decks, with only the English name. It opens
  on first launch, after the languages the learner speaks, and from Settings.
- Continue sends each newly ticked language to placement (ADR-0013).
  Placement's first stage asks whether to learn the alphabet, for a course
  with script decks (ADR-0023). Nothing is saved until placement ends.
- The list comes from `state.languages`, built from the bundled decks. Every
  deck today is taught from English.
- A language's own name is known only for spoken languages
  (`assets/languages.yaml`, `own_name`). A deck's language block has its
  icon, the first letter of its own name.
- The target level is B1, about 2,500–3,000 words a language
  (`language-paths.md`). Today's courses teach 450–680 vocabulary cards.

## The design

Patterned on the course pickers of Duolingo and Babbel, and on Material 3's
search and list guidance.

1. **Search** at the top, always visible. It matches the English name, the
   own name and the code, ignoring case and accents. With no match, it says
   so.
2. **Two groups:** "Learning", the languages chosen, then "Available". Within
   each, languages taught from a language the learner speaks come first.
3. **A card per language:**
   - its icon and both names, "Telugu · తెలుగు";
   - **course completeness**, a thin bar with "18% of B1": the words the
     course teaches ÷ the language's B1 target, at most 100%;
   - **taught from**, the native languages it has decks for, the learner's
     own ones highlighted. Where none is one the learner speaks: "Taught from
     English", as the deck-downloads plan decides;
   - once downloads exist, its size and whether it is on the phone.
4. **Selecting a card expands it in place:**
   - **"Learn the Telugu script"**, a switch, for a course with script decks.
     It replaces placement's alphabet stage, which is skipped when the answer
     is already given;
   - **"Taught from"**, a choice, only when the language has decks for more
     than one of the learner's languages.
5. **Continue** works as today: placement for the newly chosen, then save.
   Deselecting a language asks before it removes it, since its progress
   stays but its decks leave Today.
6. **Accessibility:** each card is a checkbox to a screen reader, with its
   name, completeness and native languages in its label. It works at twice
   the text size, and in both themes.

## Adapting to deck downloads

The page reads a **language catalog**, not the loaded decks:

- `LanguageCatalog` in `lib/core`, free of Flutter, lists `CatalogLanguage`
  entries:
  - code, English name, own name, icon, script;
  - native languages taught from;
  - words taught, B1 target, script decks or not;
  - and later size and whether it is on the phone.
- **Today** it is built from the bundled decks.
- **With downloads** it is built from `decks/index.json`, so the page lists
  every language on GitHub before any is downloaded. The index gains the
  fields above. `tools/deck_index.py` counts the words, and the validator
  checks the counts.
- Selecting a language then starts its download (the deck-downloads plan's
  "ready after five decks"). The page itself does not change.

## What the data needs

- **Own names** for learned languages: an `own_name` in each language
  block, or read from `assets/languages.yaml` by code. Both can be filled
  from what exists.
- **A B1 target** per language: a default of 2,500 words, overridable per
  language in its language block, `b1_words`.
- **Words taught:** distinct vocabulary cards on the language's path, script
  decks and grammar tables excluded.

## Tests

- Search: names, own names, codes, accents, no match.
- Ordering: chosen first, then taught from a spoken language, then English.
- Completeness: the count, the cap at 100%, a language with no target.
- Script switch: shown only for courses with script decks; its answer is
  saved and placement skips its alphabet stage.
- Taught-from: highlighted, the English fallback line, and the choice only
  when there are two or more.
- Removal asks first; first launch has no back.
- Twice the text size, both themes, screen-reader labels.
- The catalog built from decks and from an index fixture gives the same
  page.

## To decide

- **The B1 target:** 2,500 words by default, or another number.
- **What counts:** vocabulary only, or grammar and passages too.
- **Learner progress:** show the learner's own progress on the card as
  well, or only on Progress.
- **A mockup first:** I can make a design to approve before building.

## Estimate

- About 8–12 hours for the page, the catalog and the tests.
- About 1 hour more in the deck-downloads work, for the index fields.

Confidence: medium.
