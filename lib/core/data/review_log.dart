import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import '../models/review_event.dart';
import '../scheduling/sm2.dart';
import 'card_state_repository.dart';
import 'database.dart';

/// The review log, and the scheduling state it drives, in the database
/// (docs/DESIGN.md, "The review cycle"; ADR-0005).
///
/// Recording a review appends it to `reviews` and updates `card_states` in
/// one transaction: both, or neither, so the log stays authoritative. The
/// state can always be rebuilt from the log alone ([rebuildStates]). There is
/// no way here to change or remove a review (AGENTS.md rule 9).
class ReviewLog {
  ReviewLog(this._db);

  final AppDatabase _db;

  /// Records a review of one pair: runs [Sm2.next] on its stored state,
  /// appends the review and stores the new state, atomically. Returns the
  /// event. Throws [ArgumentError], writing nothing, for a grade outside 0–5.
  Future<ReviewEvent> record({
    required String deckId,
    required String cardId,
    required DrillMode mode,
    required int grade,
    required DateTime now,
    Duration elapsed = Duration.zero,
    String? answerGiven,
  }) => _db.transaction(() async {
    final key = (deckId: deckId, cardId: cardId, mode: mode);
    final before = await CardStateRepository(_db).stateOf(deckId, cardId, mode);
    final after = Sm2.next(before ?? Sm2State.fresh(now), grade, now: now);
    await _db.reviewsDao.append(
      ReviewsCompanion.insert(
        ts: now,
        deckId: deckId,
        cardId: cardId,
        mode: mode,
        grade: grade,
        elapsedMs: elapsed.inMilliseconds,
        answerGiven: Value(answerGiven),
        intervalBefore: Value(before?.intervalDays),
        intervalAfter: after.intervalDays,
        easeBefore: Value(before?.easeFactor),
        easeAfter: after.easeFactor,
      ),
    );
    await _db.cardStatesDao.put(after.toRow(key));
    return ReviewEvent(
      at: now,
      deckId: deckId,
      cardId: cardId,
      mode: mode,
      grade: grade,
      elapsed: elapsed,
      answerGiven: answerGiven,
      before: before,
      after: after,
    );
  });

  /// Every review, in the order it was recorded, with each pair's state
  /// before and after it, worked out from the log alone by replaying it
  /// through [Sm2.next].
  Future<List<ReviewEvent>> events() async {
    final states = <ProgressKey, Sm2State>{};
    return <ReviewEvent>[
      for (final row in await _db.reviewsDao.all()) _replay(row, states),
    ];
  }

  /// Rebuilds `card_states` from `reviews`: each pair's reviews, in order,
  /// through [Sm2.replay]. In one transaction, so the cache is never seen
  /// half-built. This is the proof that the log is enough, and the path a
  /// change of algorithm will take.
  Future<void> rebuildStates() => _db.transaction(() async {
    final byPair = <ProgressKey, List<ReviewRow>>{};
    for (final row in await _db.reviewsDao.all()) {
      (byPair[(deckId: row.deckId, cardId: row.cardId, mode: row.mode)] ??=
              <ReviewRow>[])
          .add(row);
    }
    await _db.cardStatesDao.clear();
    await _db.batch((b) {
      b.insertAll(_db.cardStates, <CardStatesCompanion>[
        for (final MapEntry(key: key, value: rows) in byPair.entries)
          Sm2.replay(
            rows.map((r) => (grade: r.grade, at: r.ts)),
            createdAt: rows.first.ts,
          ).toRow(key),
      ]);
    });
  });

  /// [row] as an event, advancing its pair's entry in [states].
  ReviewEvent _replay(ReviewRow row, Map<ProgressKey, Sm2State> states) {
    final key = (deckId: row.deckId, cardId: row.cardId, mode: row.mode);
    final before = states[key];
    final after = Sm2.next(
      before ?? Sm2State.fresh(row.ts),
      row.grade,
      now: row.ts,
    );
    states[key] = after;
    return ReviewEvent(
      at: row.ts,
      deckId: row.deckId,
      cardId: row.cardId,
      mode: row.mode,
      grade: row.grade,
      elapsed: Duration(milliseconds: row.elapsedMs),
      answerGiven: row.answerGiven,
      before: before,
      after: after,
    );
  }
}
