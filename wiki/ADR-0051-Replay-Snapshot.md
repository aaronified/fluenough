# ADR-0051: The replay snapshot: what opening the review log works out, kept and checked against the log

Source of truth: this wiki page.

- **Status:** Accepted.
- **Date:** 2026-10-31

## Context

Every launch replayed the whole review log (sort, replay twice through FSRS,
build the progress index), on the UI isolate until #953 and on an isolate
since. It is still seconds of work on a phone with a long log, repeated on
every launch although the log is the same as at the last one (#857, item 3).
The owner's ask: "review log can be cached from last run".

Two things rule out the obvious shortcuts. `card_states` cannot rebuild the
events: Stats read every event with its state before and after. And "replay
only the reviews newer than the last run" is wrong: a new review changes a
language's last-studied time, which chooses the parameter set that schedules
the pairs of every language without a fit of its own, and leech resets and the
script skills are part of the replay too.

## Decision

- **What is kept.** The result of the replay, in a new table
  `replay_snapshots` (migration 10, one row): the events with the states
  before and after each, the word skills' states, the script skills' events
  and states, and each pair's state from its own reviews (what `card_states`
  caches). Compact binary (`lib/core/data/replay_snapshot.dart`): doubles as
  their 8 bytes, times as microseconds with their zone, card and deck ids once
  in a string table, a state before that is the state the pair's previous
  event ended in as a flag, a checksum at the end. About 50 bytes an event:
  roughly 2.5 MB for 50,000 reviews, plus the script skills' events and the
  state tables, against more than three times that as JSON. The leech
  actions and fitted parameters are read from the database as ever, and the
  progress index and each language's last study are built from the events, so
  a snapshot cannot disagree with a replay about them.
- **The stamp.** A snapshot is used only while its stamp equals the stamp of
  the database now (`LogStamp`): snapshot format, app version, a hash of
  FSRS's default parameters and of the enums the bytes index, the review
  count, lowest, highest and summed ids, latest time and sums of the times,
  grades and elapsed milliseconds, the leech actions hashed whole in order,
  and the fitted parameters hashed bit by bit. The stamp is read with one SQL
  aggregate, not by reading the log.
- **Why that proves equality.** The replay is a function of the reviews (in
  the database's order), the leech actions, the fitted parameters and the
  code. `reviews` and `leech_actions` are append-only (AGENTS.md rule 9), and
  the one thing that replaces them, a confirmed restore, writes new rows whose
  ids, which never repeat, are higher; so equal count, id range and sums mean
  the same rows. Equal stamps therefore mean equal inputs, hence equal
  results, and the snapshot is the result of one such replay, decoded exactly.
- **Replay, never a guess.** Any difference, however small (a new review, a
  leech action, a restore, an import, a changed fit, another app version), a
  missing, damaged or foreign snapshot, a decode that fails or a snapshot whose
  event count is not the log's: the full replay runs, as before, and a new
  snapshot is kept. There is no incremental replay of a newer tail; it cannot
  be shown equal to a full one for the reasons above.
- **When it is written.** After an open that replayed (queued behind the read
  and before any later write, in the same isolate as the replay), and after
  changes, 45 seconds after the learner's last answer, leech action, fit,
  import or restore. The later one is made by replaying the log read from the
  database, never from memory, which differs from a replay in sub-millisecond
  times a log row does not keep; it reads the log in pages, and is kept only if
  the stamp is unchanged in the transaction that writes it.
- **Off the UI isolate.** Decoding runs in an isolate (`snapshotInIsolate`),
  and so does the encoding.
- **Marks.** Startup marks say `snapshot loaded` or `review log replayed`.

## Consequences

- A launch with an unchanged log reads one blob and decodes it, instead of
  replaying the log. A launch after answers whose snapshot was not yet written
  (the app was killed inside the 45 seconds) or after an app update replays
  once.
- The database holds a second copy of the log's derived state, a few MB. It
  is a cache: deleting it is always safe.
- Changing what a replay computes without a version bump (FSRS's code,
  `SkillMap`, the index) would serve a stale snapshot within one app version:
  raise `ReplaySnapshot.format` when the replay's meaning changes. Changing
  FSRS's defaults, `DrillMode` or `Ask` is covered by the stamp.
- `lib/core` keeps its Flutter-free rule; the table is additive and `reviews`
  is untouched.

## Alternatives considered

- **Replay only the reviews after the snapshot.** Rejected: see Context. It
  could be done only when the new reviews are in the latest language and
  change no baseline, and proving that costs more than the replay it saves.
- **JSON.** Simple and inspectable, but more than three times larger and
  slower to decode; the catalog's JSON snapshot (ADR-0048) has no 5 MB of
  floating point numbers to carry.
- **A watermark of the last review id only.** A restore that happens to leave
  the same count would pass; the stamp's sums and the ids that never repeat
  close that.
- **Snapshot from memory at idle.** Cheaper, but memory is built by
  recording, which keeps the microseconds of the moment and not the whole
  milliseconds the log keeps, so it can differ from a replay.
