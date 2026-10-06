# Plan: choosing languages to learn, redesigned

Written 2026-10-06.

## What the owner asked

> Languages i am learning should be redesigned to match world class
> standards. It should have a search option for languages, show the deck
> completeness percentage (target B1) and the native languages available,
> users can select any for learning and choose whether they want to learn
> the script right there as well.

Asked whether to build it or plan it: "plan it in a way that can adapt to
the deck download feature" (`decks-from-github.md`). Then: "Language picker
will be built after the deck download feature."

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

## Built on deck downloads

It comes after `decks-from-github.md`, so it reads the deck index from the
start, with no version built on the bundled decks:

- `LanguageCatalog` in `lib/core`, free of Flutter, lists `CatalogLanguage`
  entries from `decks/index.json`:
  - code, English name, own name, icon, script;
  - native languages taught from;
  - words taught, B1 target, script decks or not;
  - size, and whether it is on the phone.
- The page lists every language on GitHub before any is downloaded.
- Selecting a language starts its download, and the app is ready after its
  first five decks, as the deck-downloads plan decides.
- **A download progress indicator** on the language's card while it
  downloads (owner's request):
  - a bar with the share downloaded, by bytes, and "12 of 58 decks";
  - a mark on the bar where the first five decks end, with "Ready to start
    after 5 decks", which turns to "Ready to start" once they are in. The
    rest keep downloading behind it;
  - a Cancel button, which keeps what is in and stops the rest;
  - with no connection, or a failed file, the bar stops, says why and
    offers Try again;
  - Continue waits only for the first five decks of each newly chosen
    language;
  - for a screen reader, the start, the ready point, the end and any failure
    are announced once each, not every percent, as the app update download
    does.
- The deck-downloads plan's index gains the fields above.
  `tools/deck_index.py` counts the words, and the validator checks the
  counts. That is easiest done when the index is first written.

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
- The catalog read from an index fixture; a language on the phone and one
  not yet downloaded.
- Download progress, with a fake downloader:
  - the bar and deck count advance;
  - "Ready to start" appears after five decks, and Continue is enabled then;
  - Cancel keeps what is in;
  - a failure shows its reason and Try again resumes;
  - the screen-reader announcements happen once each.

## To decide

- **The B1 target:** 2,500 words by default, or another number.
- **What counts:** vocabulary only, or grammar and passages too.
- **Learner progress:** show the learner's own progress on the card as
  well, or only on Progress.
- **A mockup first:** I can make a design to approve before building.

## Estimate

- About 9–13 hours for the page, the catalog, the download progress and
  the tests, after deck downloads.
- About 1 hour more in the deck-downloads work, for the index fields.

Confidence: medium.
