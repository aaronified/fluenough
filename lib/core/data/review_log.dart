import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import '../models/leech_action.dart';
import '../models/review_event.dart';
import '../scheduling/replay.dart';
import '../scheduling/sm2.dart';
import 'card_state_repository.dart';
import 'log_jsonl.dart';
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
  /// before and after it, worked out from the log alone by replaying it,
  /// with the leech actions' resets (see [replayReviews]).
  Future<List<ReviewEvent>> events() async => (await _replay()).events;

  /// Every leech action, in the order it was taken.
  Future<List<LeechAction>> leechActions() => _db.leechActionsDao.all();

  /// Rebuilds `card_states` from `reviews` and `leech_actions` alone: every
  /// pair's reviews in order through [Sm2.next], restarting a pair at a reset
  /// that still holds. In one transaction, so the cache is never seen
  /// half-built. This is the proof that the log is enough, and the path a
  /// change of algorithm will take.
  Future<void> rebuildStates() => _db.transaction(_rebuild);

  Future<void> _rebuild() async {
    final states = (await _replay()).states;
    await _db.cardStatesDao.clear();
    await _db.batch((b) {
      b.insertAll(_db.cardStates, <CardStatesCompanion>[
        for (final MapEntry(:key, :value) in states.entries) value.toRow(key),
      ]);
    });
  }

  /// Merges a backup (#20): appends the reviews and leech actions the log
  /// does not already hold, then rebuilds `card_states` from the whole log,
  /// in one transaction. A review is the same review when its pair and
  /// moment match ([reviewIdentity]), so importing a backup twice adds
  /// nothing the second time. Returns how many reviews were new.
  ///
  /// A new row's interval and ease columns are what replaying the merged
  /// log gives at that review. Rows already there keep theirs: those
  /// columns record what was computed when the row was written, and the
  /// state is always rebuilt from the grades.
  Future<int> importAll(
    List<LoggedReview> reviews,
    List<LeechAction> leechActions,
  ) => _db.transaction(() async {
    final existing = inTimeOrder(<LoggedReview>[
      for (final row in await _db.reviewsDao.all()) _logged(row),
    ]);
    final known = <String>{for (final r in existing) reviewIdentity(r)};
    final fresh = <LoggedReview>[
      for (final r in reviews)
        if (known.add(reviewIdentity(r))) r,
    ];
    final knownActions = <String>{
      for (final a in await _db.leechActionsDao.all()) leechIdentity(a),
    };
    for (final a in leechActions) {
      if (knownActions.add(leechIdentity(a))) {
        await _db.leechActionsDao.append(a);
      }
    }
    if (fresh.isNotEmpty) {
      final merged = replayReviews(
        inTimeOrder(<LoggedReview>[...existing, ...fresh]),
        effects: LeechEffects(await _actions()),
      );
      final isFresh = <String>{for (final r in fresh) reviewIdentity(r)};
      for (final event in merged.events) {
        if (!isFresh.contains(reviewIdentity(logged(event)))) continue;
        await _db.reviewsDao.append(
          ReviewsCompanion.insert(
            ts: event.at,
            deckId: event.deckId,
            cardId: event.cardId,
            mode: event.mode,
            grade: event.grade,
            elapsedMs: event.elapsed.inMilliseconds,
            answerGiven: Value(event.answerGiven),
            intervalBefore: Value(event.before?.intervalDays),
            intervalAfter: event.after.intervalDays,
            easeBefore: Value(event.before?.easeFactor),
            easeAfter: event.after.easeFactor,
          ),
        );
      }
    }
    await _rebuild();
    return fresh.length;
  });

  /// Appends [action] and brings its pair's state in `card_states` in line
  /// with it, in one transaction. No review is touched.
  Future<void> act(LeechAction action) => _db.transaction(() async {
    await _db.leechActionsDao.append(action);
    final key = action.key;
    final state = (await _replay()).states[key];
    if (state == null) {
      await (_db.delete(_db.cardStates)..where(
            (s) =>
                s.deckId.equals(key.deckId) &
                s.cardId.equals(key.cardId) &
                s.mode.equalsValue(key.mode),
          ))
          .go();
    } else {
      await _db.cardStatesDao.put(state.toRow(key));
    }
  });

  Future<({List<ReviewEvent> events, Map<ProgressKey, Sm2State> states})>
  _replay() async => replayReviews(
    inTimeOrder(<LoggedReview>[
      for (final row in await _db.reviewsDao.all()) _logged(row),
    ]),
    effects: LeechEffects(await _actions()),
  );

  /// Every leech action, oldest first.
  Future<List<LeechAction>> _actions() async =>
      actionsInTimeOrder(await _db.leechActionsDao.all());
}

LoggedReview _logged(ReviewRow row) => (
  key: (deckId: row.deckId, cardId: row.cardId, mode: row.mode),
  at: row.ts,
  grade: row.grade,
  elapsed: Duration(milliseconds: row.elapsedMs),
  answerGiven: row.answerGiven,
);
