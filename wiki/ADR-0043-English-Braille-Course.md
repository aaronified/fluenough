# ADR-0043: English Braille is a notation course, typed on the app's own keyboard

Source of truth: this wiki page.


- **Status:** Accepted (owner, 2026-10-20: "Add a course for english braille
  as well, only for the script (including numbers)"; asked which braille,
  "Uncontracted now, contractions later"; then "Braille will need a
  keyboard too. Add that as well."; and, asked about a mockup, "No, go
  ahead. Make sure that the fields which need the keyboard will not trigger
  the normal keyboard.")
- **Date:** 2026-10-20

## Context

The owner asked for a course in English braille, for the script alone,
numbers included. Asked which braille, they chose Unified English Braille
(UEB) uncontracted, grade 1, now, and its contractions, grade 2, later, as
later units of the same course. Then they asked for a keyboard to type it
on.

The IPA was the first notation taught like a language
([ADR-0041](ADR-0041-The-Ipa-Course)): no voice, learned only when chosen,
placed by nothing, Complete once its path is written (#658). Those rules
were written for the IPA alone, as `isIpa` and `code != 'ipa'`. Braille
needs the same ones, but not the IPA's two entries and scopes, and, unlike
the IPA, it is typed.

## Decision

1. **A course like the IPA's.** Its language block is
   `{ code: "qbe", iso639_3: "eng", name: "English Braille", script: "braille", icon: "⠃" }`
   ([DECK-FORMAT.md, The English Braille course](Deck-Format#the-english-braille-course)).
   - The code `qbe` is in ISO 639's range reserved for local use,
     `qaa`–`qtz`, so it can never clash with a real language's code, and
     passes the 2–3 letter rule. A later braille for another language takes
     its own (`qb…`).
   - Its ISO 639-3 code is `eng`: braille writes English, unlike the IPA
     (`zxx`, no linguistic content).
   - Its decks are a core and an English layer each, in a path of six units:
     a to j, k to t, u to z with w, the capital indicators, the numeric
     indicator with the digits and the grade 1 indicator, and the
     punctuation; and a script guide. The path has no B1 plan. Grade 2's
     contractions are units after these, when they are written.
2. **A card's print equivalent is its meaning, not a reading.** `target` is
   the cell or cells, `native` what they stand for in print, and the note
   gives the dots ("Dots 1-2: ⠁ (a) with dot 2 below it"). A `reading`
   beside the cell would give the answer away on every recognition card, and
   would offer to type the print letter in place of the cell, so `braille`
   is, with the IPA, a script that needs none (`NO_READING`,
   `LanguageInfo.needsReading`).
3. **One notion of a notation.** `LanguageInfo.isNotation` (the IPA or
   braille, by script) and `isNotationCode` (by code, `ipa` or `qbe`) replace
   the IPA's own tests wherever the rule is a notation's: no voice
   (`voiceStatus`, `backupVoice`, `voiceLanguages`, Settings' voices), learned
   only when chosen (`Profile.learns`), placed by nothing (the picker), and
   Complete once its path is written (`B1Progress.of(isNotation:)`, from the
   decks and from the index alike). The IPA's two entries, its scope and its
   "sounds of this word" stay the IPA's. The validator has `NOTATION_SCRIPTS`
   for the same rules: no `tts` warning and no B1 plan.
4. **Typed, on the app's own keyboard.** Braille is typed (no `typed:
   false`), so production is the learner's own answer, graded as any typed
   answer is, cell for cell. A language names a keyboard the app draws
   through its script, `LanguageInfo.keyboard`: `braille` gives six dots in
   the Perkins layout (1-2-3 down the left, 4-5-6 down the right), "Enter
   cell", Space and Backspace, under the answer field. That field never
   opens the phone's keyboard (owner, 2026-10-20: "Make sure that the fields
   which need the keyboard will not trigger the normal keyboard"): it is
   read-only, with no input type (`TextInputType.none`), and does not focus
   itself, so neither its appearing, a tap on it, nor the next card asks
   the phone for a keyboard. Every other script keeps the phone's.

## Consequences

- The keyboard is named by the script, not by a new field in the language
  block: the released app refuses a field it does not know, and phones
  download decks from main (#524). So the released app reads the decks, but
  offers them with the phone's keyboard, and, until it is updated, treats
  `qbe` as an ordinary language: it can place it and, for a profile that
  never chose its languages, learns it once its decks are on the phone.
- A recognition card shows the cell and asks for its print equivalent; a
  production card shows the print and asks for the cell, typed. Listening is
  never drilled.
- ⠦ is both the question mark and the opening quotation mark in UEB. It is
  one card, whose meaning names both: two cards with one target would accept
  each other's answer.
- No facts file yet, which a new language should have (AGENTS.md, Definition
  of done).

## Alternatives considered

- **`typed: false`, as the IPA.** The first plan, before the owner asked for
  a keyboard: production chosen among cells. Typing a cell dot by dot is
  what braille is written with, and the stronger test.
- **A `keyboard` field in the language block.** Clearer, but the released
  app would refuse every braille deck.
- **A `reading` on each card, its print letter.** See Decision 2.
- **A real ISO 639 code.** `brl` and the like are, or may become, real
  languages' codes; `bra` is Braj. The local-use range cannot clash.

## Update (2026-10-25, #835): braille is drawn with shadow dots

Owner, 2026-10-25: "get a font with the shadow dot. The UEB manual uses one
too. Otherwise it is impossible to read on a phone." Every cell
(U+2800 to U+28FF) is drawn with all its dot positions: raised dots solid,
unraised ones as thin rings, so that a lone dot's column and row can be read.

- **The font** is `assets/fonts/BrailleShadow.ttf` (about 75 KB, family
  `FluenoughBraille`), built by `tools/make_braille_font.py` (tested by
  `tools/test_braille_font.py`) under the SIL Open Font License
  (`assets/fonts/OFL.txt`). No openly licensed font drawing shadow dots for
  the whole block was found, so it is generated: standard cell proportions
  (dots 2.5 mm apart, cells 6 mm), six positions for a six-dot cell and eight
  for a cell using dot 7 or 8. The rings are outlines, so they show in light
  and dark text alike.
- **It is bundled in the app, not downloaded** as ADR-0042 does for the
  other scripts. It is tiny, braille can appear in any deck's notes, not only
  in the braille course's, and a font the learner must opt into does not suit
  a script that is unreadable without it. The ADR-0042 path would also not
  have shipped without a release: the released app draws only a course's own
  text in a downloaded font, and has no sample for braille. So there is no
  `FONTS` entry, no `decks/fonts/braille/`, and no font check for braille:
  the shadow font always applies.
- **Where it is used:** `TargetText` draws braille text in it, as do the
  typed answer and the braille keyboard's cell; it is also the fallback
  family of the app's theme, so cells in notes and any other text use it
  rather than the phone's font.
- **Cost:** about 75 KB in every install.

See also: [Contributing](Contributing) · [ADR-Index](ADR-Index) · [Home](Home)
