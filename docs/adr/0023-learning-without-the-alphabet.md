# ADR-0023: A language can be learned without its alphabet

- **Status:** Accepted
- **Date:** 2026-10-03

## Context

The owner asked for "a path in both the path files and onboarding for when
the user doesn't want to learn the alphabet", and for transliterated
answers, "as no script cannot work without it" (ADR-0022). They decided:

- script units are marked in the existing paths, and the script, spelling
  and reading decks are skipped;
- cards show both, the romanisation first;
- onboarding asks per language, right after it is chosen, Japanese too;
- a per-language switch in Settings;
- no-alphabet learners get full credit for answers in Latin letters.

Japanese has only its hiragana deck. Asked, the owner chose to ask anyway
and say there is nothing yet without the alphabet.

## Decision

- **The path marks the decks.** A path file's `alphabet` lists the decks
  that need the alphabet: the script, spelling and reading decks. Each must
  be on the path; the validator and the parser check it.
- **The setting is per language.** `SettingsNotifier.noAlphabet` holds the
  codes learned without their alphabet, stored as `no_alphabet`.
- **The course leaves those decks out.** `AppState.courseUnits` drops them,
  so Today, placement and the pending units never teach them, and Today's
  deck list does not show them. They can still be opened and studied.
- **Asked at placement.** For a language whose path marks decks, placement
  first asks "Learn the alphabet?" and places the course as answered.
  Nothing is saved until placement ends, as before. A course left with
  nothing, Japanese today, says so.
- **Settings > Alphabets** has a switch for each language learned whose
  course marks decks.
- **In drills:** typed answers start in Latin letters, and a right one
  counts in full. The Script choice stays. Recognition, the answer once
  given, and placement's check show the reading first, as large as the
  word, then the script.

## Consequences

- A new path must list its script, spelling and reading decks in
  `alphabet`, or a learner without the alphabet is taught them.
- Switching the alphabet on later puts the script decks back at the start
  of the course: Today teaches them next.
