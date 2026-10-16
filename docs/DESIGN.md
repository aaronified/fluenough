# Architecture

## Layers

```
lib/
  core/              pure Dart, no Flutter imports, fully unit-testable
    models/          Card, Deck, GrammarPattern, ReviewEvent, CardState
    scheduling/      FSRS and the Scheduler interface
    grading/         answer normalisation and comparison
    tts/             TtsEngine interface (implementations may touch platform)
    data/            drift database, deck repository, review log
    decks/           the deck index, SHA-256, fetching decks from GitHub
  features/          UI, one directory per screen area
    drill/  decks/  stats/  settings/
  ui/                theme, shared widgets
```

The rule that matters: **`core/models`, `core/scheduling` and `core/grading`
import nothing from Flutter.** They are plain Dart, so they run under
`dart test` in milliseconds with no device or emulator. That is where the
logic worth testing lives, and keeping it framework-free is what makes it
cheap to test.

## Data model

Seven tables, in one SQLite database per profile (`lib/core/data/database.dart`,
which also says how a migration is added). Times are stored as milliseconds
since the epoch.

**`decks`** — metadata for each loaded deck, keyed by deck id.

**`cards`** — the content, keyed by `(deck_id, card_id)`. Rebuilt from the YAML
whenever a deck is loaded or updated. Contains no user data, so it can always
be discarded and regenerated.

**`card_states`** — scheduling state, keyed by `(card_id, mode)`: a card listed
in several decks, or learned from several languages, has one schedule
(ADR-0018).
Holds FSRS's state (ADR-0033): `stability`, `difficulty`, `interval_days`,
`repetitions`, `due_at`, `last_review_at`, `lapses`. This is a **derived
cache**: it can be rebuilt in full by replaying `reviews`.

**`reviews`** — the append-only log. One row per answered card, never updated
or deleted:

```
id, ts, deck_id, card_id, mode, grade, elapsed_ms, answer_given,
interval_before, interval_after, stability_after, difficulty_after
```

`stability_after` and `difficulty_after` came with migration 5 and are null
on older rows. Migration 6 dropped SM-2's `ease_before` and `ease_after` and
kept every row (ADR-0033), so the log still replays by grade and time, which
is all FSRS needs.

Everything the app knows about a user's progress derives from this table. It is
the only table whose loss would be irreparable, which makes it the only one
export has to protect. SQLite itself refuses an UPDATE or DELETE on it: migration
1 adds triggers that abort both. See [ADR-0005](adr/0005-scheduling.md).

**`settings`** — the learner's settings, one row per setting by a permanent
name, as text (migration 2). Per profile, like progress.

**`leech_actions`** — what the learner did about leeches: Reset, Undo, Set
aside, Bring back (migration 3). Append-only and guarded like `reviews`.
Replaying the log reads it: a pair restarts after a reset that still holds,
and a set-aside pair is left out of every session. No review is touched.

**`fsrs_parameters`** — FSRS's parameters fitted to the learner, one row per
language and skill (migration 7, ADR-0035): the 21 values, when the fit ran,
the review count it ran at, and the log loss before and after. Not a cache:
each fit starts from the one before, so it cannot be rebuilt from `reviews`.
A pair is scheduled with its skill's set in its language, else that skill's
set in the language studied most recently, else the defaults.

**Backup.** Settings → Export review log writes both logs, and the fitted
parameters, as one JSONL file, and Import merges such a file back, adding
only the reviews not already there and rebuilding `card_states` from the
whole log. The log replays by
time, so older history imported onto a new phone takes its place. See
[LOG-FORMAT.md](LOG-FORMAT.md).

## The review cycle

1. `Scheduler.dueCards(deck, mode, limit)` queries `card_states` for
   `due_at <= now`, plus the new skills of words already taught; new words
   come in daily lessons (ADR-0024).
2. The drill presents the card according to its mode.
3. The user answers. Machine-graded modes run the answer through
   `AnswerGrader`; `recognition` asks the user to self-assess.
4. The outcome maps to a grade of 0–5, which FSRS reads as a rating.
5. `Fsrs.next(state, grade)` returns the new state — a pure function, which is
   what makes the scheduler trivially testable.
6. A `ReviewEvent` is appended to `reviews` **and** `card_states` is updated,
   in one transaction. Both, or neither.

## Grading

`AnswerGrader` returns `exact`, `closeDiacritics`, `closeTypo` or `wrong`
rather than a boolean. The distinction drives both the UI ("right, but watch
the accent") and the grade, and keeps the policy decision out of the
comparison code. The pipeline is specified in
[DECK-FORMAT.md](DECK-FORMAT.md#grading).

Article stripping is per-language data, not code: `["el","la","los","las"]` for
Spanish, `["der","die","das"]` for German. A language with no articles supplies
an empty list and the pass is a no-op.

## TTS

```dart
abstract interface class TtsEngine {
  Future<bool> isLanguageAvailable(String bcp47);
  Future<List<TtsVoice>> voicesFor(String bcp47);
  Future<void> speak(String text, {required String bcp47, double rate});
  Future<void> stop();
}
```

`SystemTtsEngine` wraps `flutter_tts`. Nothing outside `core/tts` refers to
`flutter_tts`, so a second implementation is additive. When
`isLanguageAvailable` is false, listening is shown disabled with the reason and
a way to set up a voice, and no session contains a listening card
([ADR-0008](adr/0008-unbuilt-features-are-shown-disabled.md)) — a
language-agnostic app must degrade gracefully on a device lacking a voice.

## Deck loading

The app bundles no deck, only `decks/themes.yaml`. Decks are downloaded from
the repository's `main` branch into `downloaded/` in the app's own storage,
each under its repository path (#210,
[ADR-0037](adr/0037-decks-download-from-main.md)); a learner's own decks are
copied into `decks/` there. All go through one path:

```
bundled themes + downloaded/ + added/  →  DeckSources  →  DeckCatalog
YAML text → DeckParser → Deck → (grammar: PatternExpander) → List<Card> → cards table
```

Parse failures are reported with file and line, never swallowed. A deck that
fails to parse is skipped and surfaced in the UI; it must not take the app down.

## Deck downloads

```
GitHub main                     the phone
decks/index.json  ──fetch──▶    DeckDownloads ──check──▶ FileDownloadedDecks
decks/<lang>/…    ──fetch──▶      size + SHA-256,         downloaded/decks/…
                                  then DeckCatalog.checkFile  files.json, index.json, state.json
```

- **`lib/core/decks/`**, pure Dart: `DeckIndex` reads `decks/index.json`
  and works out what a learner downloads (`filesFor`), what makes a
  language ready (`firstFiles`: its own files and the first five decks of
  its path), and what an update changes (`changesFor`, which keeps a file
  GitHub dropped unless a new one takes its role). `DeckFetcher` gets a
  file; `GitHubDeckFetcher` asks `raw.githubusercontent.com` with dart:io's
  client and no token. `sha256Hex` hashes, with no package.
- **`DeckDownloads`** (`lib/app/`) runs it: the first five decks, then the
  rest in writes of ten decks; at most one check a day; the question, and
  "Not now" remembered; removing a language. It says why a download
  failed: offline, rate-limited, a file that does not match, one that does
  not parse, a full phone, an index too new, a language no longer offered.
  A batch with any bad file is not kept.
- **`FileDownloadedDecks`** writes every file of a batch beside its place,
  then moves each in, so no half file is ever read; a part-file left by a
  crash is deleted at launch. It keeps what the index said of each file
  (`files.json`), the last index, and its own state.
- **`AppState`** reads the downloads before the catalog, then, in the
  background, finishes downloads cut short and looks for updates.
  `missingLanguages` sends the app to `DownloadPage` while a language the
  learner learns has none of its first decks, as after updating from a
  version that bundled them.
- **Screens** (`lib/features/downloads/`): `DownloadPage`, the first decks
  with their progress and Try again; the learn page's list, from the index,
  which from Settings also checks for deck updates at its top and shows on
  each downloaded language's card its size and state with Update and Remove
  (#467), as Languages you review does for each course on the phone; and
  `DeckUpdatePrompt`, the daily question. There is no separate Deck
  downloads page.

Progress is never part of a deck file. It is keyed by card id in the
database, so replacing, removing and downloading decks again leaves it
whole.

## Daily facts

Each language has a facts file (`<code>-facts.yaml`, see "Facts files" in
`DECK-FORMAT.md`) alongside its decks. Once a day the app shows the learner one
fact about each language they are studying, in each language they speak.
Those are the languages they picked and ranked on first launch (#53), which
are kept apart from the interface language.

A fact is shown in a spoken language when its `text` has an entry in it. A
contrast fact is shown only to a learner who speaks the language it contrasts
with. So a learner of Hindi who speaks Bengali and English sees the general
facts in Bengali and in English, and the contrasts with Bengali and with
English, their best-known language first. Facts without a contrast are the
guaranteed pool, at least 30 per language, so a learner gets a month of facts
whatever they speak.

Seen facts are remembered by id, like review history keyed on card ids, so fact
ids are permanent. Facts are not drilled and never enter `reviews`.

- **Order:** the file's. Today's fact is the first eligible fact not yet
  shown; one shown today stays today's fact.
- **After the last fact** the cycle starts again, with the one shown longest
  ago.
- **Which languages:** each language the profile learns that has a facts file,
  one card each on Today. A language not studied is never shown.
- **Where seen ids live:** with the profile's settings, as
  `<language>/<fact id>` and when it was shown, since they are small, per
  profile and read as the screen draws.
