# ADR-0049: Deck search: FTS5 trigram to retrieve, edit distance to forgive, a pure-Dart matcher as fallback

Source of truth: this wiki page.

- **Status:** Accepted.
- **Date:** 2026-10-30

## Context

The Decks tab's search (#527) must find units, decks and words despite a
typo, offline, over every card of the course with no cap. The issue's title
says FTS5, and the owner confirmed it, 2026-10-30: "FTS5 needs to be there."
The first build (#905) did the mockup's two steps in pure Dart, scanning
every card on every search. The app ships SQLite through drift
(`sqlite3_flutter_libs`, a recent SQLite with FTS5 and the trigram
tokenizer, which needs 3.34 or later), but not on the web, where the build
(`lib/main_web.dart`) must not reach `dart:ffi`.

## Decision

- **Retrieval is FTS5.** `CardSearchIndex` (`lib/core/search/card_index.dart`)
  keeps an FTS5 virtual table with `tokenize = 'trigram'`, one row per card:
  its searchable text (target, other scripts, readings, meanings) in the
  search's folded form, with the card's and the deck's ids stored unindexed.
  A word of three letters or more is looked up as a phrase, which on a
  trigram table is a substring match. A second ordinary table, `vocab`,
  holds the Latin words the cards contain, for the typo step.
- **A typo is retrieved in the mockup's two steps.** The cards that share a
  trigram with the word (an OR of its trigrams), and the cards holding a
  known word within the allowed edit distance of it: the vocabulary's words
  of nearly the same length are compared in Dart by Damerau-Levenshtein
  distance (1 for a word of up to four letters, 2 beyond; a swap counts as
  one), then looked up as phrases. "yuo" shares no trigram with "you" and is
  found by the second step.
- **The index narrows; the matcher decides.** What the index returns is
  always a superset of what `lib/core/search/fuzzy.dart` accepts, and the
  search still runs the matcher over it, so that ranking (whole word, start,
  inside, close), the exact-first rule, the `kind:`, `status:` and `theme:`
  tokens and every result are the same with or without the index. A word the
  index cannot narrow (under three letters, or three letters with typos
  allowed, which may mean a two-letter word) leaves the search unnarrowed.
- **Never a source of truth.** The index is an in-memory SQLite database
  (the `sqlite3` package, already a dependency of drift), built lazily from
  the loaded decks as they are searched, one deck at a time, and rebuilt
  every launch. A deck is added once; a new catalog entry for the same deck
  replaces its rows. There is no file and no migration, so nothing to
  corrupt and nothing to back up. Rows of a deck removed from the catalog
  linger until the app closes and are harmless: the matcher only looks at
  the decks the catalog has.
- **Fallback.** The pure-Dart matcher is the whole search where there is no
  index. `CardSearchIndex.tryOpen` returns null, and the search scans the
  cards as before, when: the platform has no native SQLite (the web: the
  connection is chosen by a conditional import on `dart.library.ffi`, so the
  web build never imports `sqlite3`); the database cannot be opened; or the
  probe fails, that is creating the FTS5 table with the trigram tokenizer
  and finding a probe row by a three-letter piece throws or returns the
  wrong thing (a SQLite older than 3.34 or built without FTS5). An error
  while indexing or querying turns the index off for the session.
- **Native probe timing.** The probe runs on the first search, not at
  launch, so that opening the app costs nothing.

## Consequences

- A search no longer scans every card: the first search of a course pays for
  building its rows (a transaction per deck, on the UI isolate, after the
  card text is folded, which the first search did already), later ones are
  index lookups plus the matcher over the candidates.
- A new direct dependency in `pubspec.yaml`, `sqlite3`, already in the lock
  file through drift; no new package is downloaded.
- Memory: the cards' folded text again, in SQLite pages, while the app runs.
- Two paths must agree. The tests run the same queries with the index and
  without it and compare the results, and check on a real in-memory SQLite
  that the index never leaves out a card the matcher accepts.
- Not built: an on-disk index keyed by deck file SHA-256 like the catalog
  snapshot (ADR-0048). The in-memory build is cheap enough that persistence
  is not worth a file, a version and an invalidation rule; it can follow if
  a measurement says otherwise.

## Alternatives considered

- **Pure Dart only** (#905): no dependency and nothing to probe, but a scan
  of every card per search, and against the owner's answer.
- **An FTS5 table in the profile's drift database:** persistent, but the
  database is per profile and holds the learner's progress; a derived index
  does not belong in it, and a migration would be needed to add it.
- **An index file keyed by SHA-256:** see above.
- **FTS5's own ranking (`bm25`) for ordering:** the mockup orders by match
  quality, then path order, which the matcher already gives.
