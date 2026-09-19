# Architecture

## Layers

```
lib/
  core/              pure Dart, no Flutter imports, fully unit-testable
    models/          Card, Deck, GrammarPattern, ReviewEvent, CardState
    scheduling/      SM-2 and the Scheduler interface
    grading/         answer normalisation and comparison
    tts/             TtsEngine interface (implementations may touch platform)
    data/            drift database, deck repository, review log
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

Four tables.

**`decks`** — metadata for each loaded deck, keyed by deck id.

**`cards`** — the content, keyed by `(deck_id, card_id)`. Rebuilt from the YAML
whenever a deck is loaded or updated. Contains no user data, so it can always
be discarded and regenerated.

**`card_states`** — scheduling state, keyed by `(deck_id, card_id, mode)`.
Holds `interval_days`, `ease_factor`, `repetitions`, `due_at`, `lapses`. This
is a **derived cache**: it can be rebuilt in full by replaying `reviews`.

**`reviews`** — the append-only log. One row per answered card, never updated
or deleted:

```
id, ts, deck_id, card_id, mode, grade, elapsed_ms, answer_given,
interval_before, interval_after, ease_before, ease_after
```

Everything the app knows about a user's progress derives from this table. It is
the only table whose loss would be irreparable, which makes it the only one
export has to protect. See [ADR-0005](adr/0005-scheduling.md).

## The review cycle

1. `Scheduler.dueCards(deck, mode, limit)` queries `card_states` for
   `due_at <= now`, plus new cards up to a daily cap.
2. The drill presents the card according to its mode.
3. The user answers. Machine-graded modes run the answer through
   `AnswerGrader`; `recognition` asks the user to self-assess.
4. The outcome maps to an SM-2 grade of 0–5.
5. `Sm2.next(state, grade)` returns the new state — a pure function, which is
   what makes the scheduler trivially testable.
6. A `ReviewEvent` is appended to `reviews` **and** `card_states` is updated,
   in one transaction. Both, or neither.

## Grading

`AnswerGrader` returns `exact`, `closeDiacritics`, `closeTypo` or `wrong`
rather than a boolean. The distinction drives both the UI ("right, but watch
the accent") and the SM-2 grade, and keeps the policy decision out of the
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
`flutter_tts`, so a second implementation is additive. Listening drills are
hidden, not broken, when `isLanguageAvailable` is false — a language-agnostic
app must degrade gracefully on a device lacking a voice.

## Deck loading

Bundled decks ship as Flutter assets. Imported decks are copied into the app's
documents directory. Both go through one path:

```
YAML text → DeckParser → Deck → (grammar: PatternExpander) → List<Card> → cards table
```

Parse failures are reported with file and line, never swallowed. A deck that
fails to parse is skipped and surfaced in the UI; it must not take the app down.
