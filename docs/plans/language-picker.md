# Plan: choosing languages to learn, redesigned

Written 2026-10-06. **Part of the settings redesign,** with
`language-picker.md`, `settings-wording.md` and `voices-per-language.md`:
last in the owner's order, after the skill model (done), `b1-plans.md` and
deck downloads ([ADR-0037](../adr/0037-decks-download-from-main.md)).

## What the owner asked

> Languages i am learning should be redesigned to match world class
> standards. It should have a search option for languages, show the deck
> completeness percentage (target B1) and the native languages available,
> users can select any for learning and choose whether they want to learn
> the script right there as well.

Asked whether to build it or plan it: "plan it in a way that can adapt to
the deck download feature" ([ADR-0037](../adr/0037-decks-download-from-main.md)). Then: "Language picker
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
   - **course completeness**, a thin bar with "18% of B1 · 12 of 30
     grammar topics": words drive the percentage and grammar topics are
     shown beside it (owner's choice), both calculated from the course's B1
     plan (`b1-plans.md`), never stored;
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

It comes after deck downloads (ADR-0037), so it reads the deck index from the
start, with no version built on the bundled decks:

- `LanguageCatalog` in `lib/core`, free of Flutter, lists `CatalogLanguage`
  entries from `decks/index.json`:
  - code, English name, own name, icon, script;
  - native languages taught from;
  - completeness toward B1, calculated (below), script decks or not;
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
- **Completeness toward B1, calculated from the path** (owner's choice).
  Decks keep changing, so no percentage or target is stored:
  - the path marks where each level ends: `milestone: A1`, `A2`, `B1` on a
    unit, as the achievements plan also needs;
  - every unit up to the B1 mark is listed, including units not written
    yet, each with its **planned** size in words, `words: 40`. A planned
    size describes the course plan, not its content, so a deck update does
    not change it;
  - the words a unit **has** are always counted from its decks: distinct
    vocabulary cards, script decks and grammar tables excluded;
  - completeness = Σ min(words a unit has, its planned words) ÷ Σ planned
    words, over the units up to the B1 mark. A unit not written yet counts
    0;
  - the app calculates it from the decks it has, and from the index for
    languages not yet downloaded. `tools/deck_index.py` counts the words
    each time the index is written, and CI fails when the index is out of
    date, so the count cannot go stale.
- **The validator** checks that a path has a B1 mark and that every unit
  before it has a planned size. It warns when a unit has more words than
  planned, since then the plan needs raising.
- **Every path has a B1 plan** (owner's decision): "Every deck path will
  have a B1 plan from now on. The app will use this explicitly." What it
  holds, and its format, are in `b1-plans.md`.
  - The B1 plan is written in the path: its units up to the B1 mark, with
    their milestones and planned sizes, including units not written yet.
    It is set explicitly by whoever writes the course, not derived in the
    app from the scheme's phase lengths. The scheme and the target of about
    2,500–3,000 words by B1 (`language-paths.md`) guide the author.
  - The app reads the plan as it is, and calculates completeness from it
    and the decks.
  - The validator fails a path without a B1 plan, so every new language
    comes with one. The eight existing courses are given theirs before the
    picker is built. Until then, a path without one shows "Course size: 640
    words" in place of a percentage.

## Tests

- Search: names, own names, codes, accents, no match.
- Ordering: chosen first, then taught from a spoken language, then English.
- Completeness: the sum over units up to B1, a unit over its plan capped
  at its plan, a unit not written counting 0, a path with no B1 mark
  showing the course size instead, and the same figure from the decks and
  from the index.
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

## Decided (owner, 2026-10-09)

- **Built now,** on the bundled decks, ready for deck downloads later
  (the order above is changed: "Do the settings redesign here as well").
- **A mockup first,** to approve before building.
- **The mockup is approved** (owner, 2026-10-09: "The mockups look great",
  `docs/mockups/language-picker.html`), with one change: "a language may
  be available in more than 2 native languages ... It will not be there
  anytime soon, but still." The "taught from" choice must not be a
  two-way switch: up to three options can sit side by side; beyond that
  it becomes a list (a radio list in a sheet), each with its coverage,
  the learner's own languages first.
- **Answers to the mockup's questions** (owner, 2026-10-09): a language
  the learner already learns opens its course at once, and only a newly
  chosen one goes through placement; "Learn the script" starts on; after
  a cancelled download the rest comes from Settings > Deck downloads, the
  course working with what arrived.
- **Alpha and beta, not "Just started"** (owner, 2026-10-09: "It is not
  'just started', start implies starting action by the learner. It is a
  'beta deck', or alpha. I guess till A1, decks should be called alpha.
  Post A1, they will be beta"). A course is tagged **Alpha** until every
  A1 unit of its plan is written, **Beta** from then until every B1 unit
  is written, and carries no tag after that.
- **Both progresses on the card:** the course's completeness ("62% of B1
  written") and, for a language the learner learns, their own ("You: 18%
  of B1").
- **One release with deck downloads** (owner, 2026-10-09: "After the
  picker"): deck downloads (#440) ships in the same release as the picker,
  not on its own.

## Estimate

- About 9–13 hours for the page, the catalog, the download progress and
  the tests, after deck downloads.
- About 1 hour more in the deck-downloads work, for the index fields.
- About 1–2 hours for the path's milestone marks and planned sizes in the
  validator and the index tool, and 2–4 hours to fill them in for the eight
  existing courses.

Confidence: medium.
