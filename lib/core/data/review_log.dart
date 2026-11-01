import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import '../models/leech_action.dart';
import '../models/review_event.dart';
import '../scheduling/ask.dart';
import '../scheduling/replay.dart';
import '../scheduling/fsrs.dart';
import '../scheduling/skill_parameters.dart';
import 'card_state_repository.dart';
import 'log_jsonl.dart';
import 'database.dart';
import 'replay_isolate.dart';
import 'replay_snapshot.dart';
import 'restore_record.dart';

/// The review log, and the scheduling state it drives, in the database
/// (docs/DESIGN.md, "The review cycle"; ADR-0005).
///
/// Recording a review appends it to `reviews` and updates `card_states` in
/// one transaction: both, or neither, so the log stays authoritative. The
/// state can always be rebuilt from the log alone ([rebuildStates]). There is
/// no way here to change or remove a review (AGENTS.md rule 9), except the
/// one exception that rule names: a confirmed restore ([replaceAll]).
class ReviewLog {
  ReviewLog(this._db);

  final AppDatabase _db;

  /// Records a review of one pair: runs [Fsrs.next] on its stored state,
  /// with the [parameters] that schedule the pair, appends the review and
  /// stores the new state, atomically. Returns the event. Throws
  /// [ArgumentError], writing nothing, for a grade outside 0–5.
  Future<ReviewEvent> record({
    required String deckId,
    required String cardId,
    required DrillMode mode,
    required int grade,
    required DateTime now,
    Duration elapsed = Duration.zero,
    String? answerGiven,
    String? script,
    Ask? asked,
    List<double> parameters = Fsrs.w,
  }) => _db.transaction(() async {
    final key = (cardId: cardId, mode: mode);
    final before = await CardStateRepository(_db).stateOf(cardId, mode);
    final after = Fsrs.next(
      before,
      grade,
      now: now,
      rated: answerGiven == null,
      parameters: parameters,
    );
    await _db.reviewsDao.append(
      ReviewsCompanion.insert(
        ts: now,
        deckId: deckId,
        cardId: cardId,
        mode: mode,
        grade: grade,
        elapsedMs: elapsed.inMilliseconds,
        answerGiven: Value(answerGiven),
        script: Value(script),
        asked: Value(asked?.name),
        intervalBefore: Value(before?.intervalDays),
        intervalAfter: after.intervalDays,
        stabilityAfter: Value(after.stability),
        difficultyAfter: Value(after.difficulty),
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
      script: script,
      asked: asked,
      before: before,
      after: after,
    );
  });

  /// Every review, in the order it was recorded, with each pair's state
  /// before and after it, worked out from the log alone by replaying it,
  /// with the leech actions' resets (see [replayReviews]), and each skill's
  /// [parameters].
  Future<List<ReviewEvent>> events({SkillParameters? parameters}) async =>
      (await _replay(parameters)).events;

  /// Every review as the log keeps it, oldest first.
  Future<List<LoggedReview>> reviews() async => inTimeOrder(await loggedRows());

  /// Every review as the log keeps it, in the order the database gave them:
  /// not sorted, for a caller that sorts them elsewhere ([openReplay]).
  Future<List<LoggedReview>> loggedRows() async => <LoggedReview>[
    for (final row in await _db.reviewsDao.all()) _logged(row),
  ];

  /// Opening the app (#857): reads the log and its leech actions and has
  /// [run] sort and replay them, with [fitted], on an isolate by default.
  /// The database is read here, on its own isolate or the main one as it
  /// always was; only the pure sorting and replaying move. Nothing is
  /// written: the caller keeps `card_states` equal to what it gives
  /// ([putStates]).
  Future<OpenedLog> openReplay({
    required Map<SkillKey, FittedParameters> fitted,
    ReplayRunner run = replayInIsolate,
  }) async {
    final job = OpenJob(
      reviews: await loggedRows(),
      leechActions: await leechActions(),
      fitted: fitted,
    );
    replays++;
    return run(job);
  }

  /// Opening the app from the kept snapshot if it is good, else by
  /// replaying the log (#857, ADR-0051).
  ///
  /// The snapshot is good only when its stamp is the stamp of the database
  /// now ([currentStamp]): the log, the leech actions, the fitted parameters
  /// and the code are then the ones it was made from, and replaying is a
  /// function of those alone, so its bytes are what a replay gives. It is
  /// read by [fromSnapshot], on an isolate by default. Anything else (no
  /// snapshot, another stamp, a snapshot that cannot be read or the table
  /// missing) is replayed by [run] exactly as [openReplay] does, and the
  /// result carries the bytes of a new snapshot ([OpenJob.encode]) with the
  /// stamp they are for, to be kept by [putSnapshot].
  Future<
    ({OpenedLog opened, bool fromSnapshot, LogStamp? stamp, Uint8List? bytes})
  >
  openCached({
    required Map<SkillKey, FittedParameters> fitted,
    required String app,
    ReplayRunner run = replayInIsolate,
    SnapshotRunner fromSnapshot = snapshotInIsolate,
  }) async {
    final actions = await leechActions();
    LogStamp? stamp;
    try {
      stamp = await currentStamp(
        app: app,
        fitted: fitted,
        leechActions: actions,
      );
      if (await _db.replaySnapshotsDao.stamp() == stamp.text) {
        final bytes = await _db.replaySnapshotsDao.payload();
        if (bytes != null) {
          final opened = await fromSnapshot(
            SnapshotJob(
              bytes: bytes,
              leechActions: actions,
              reviewCount: stamp.reviews,
            ),
          );
          if (opened != null) {
            return (
              opened: opened,
              fromSnapshot: true,
              stamp: stamp,
              bytes: null,
            );
          }
        }
      }
    } on Object {
      // A cache that cannot be read is no cache. A log that cannot be read
      // fails below, as it always has.
    }
    final job = OpenJob(
      reviews: await loggedRows(),
      leechActions: actions,
      fitted: fitted,
      encode: stamp != null,
    );
    replays++;
    final opened = await run(job);
    return (
      opened: opened,
      fromSnapshot: false,
      stamp: stamp,
      bytes: opened.snapshot,
    );
  }

  /// The stamp of the database as it is now: what a snapshot made from it
  /// carries, and the only thing that makes one good ([LogStamp]). Reads a
  /// handful of aggregates, not the log. [fitted] and [leechActions] are read
  /// when not given.
  Future<LogStamp> currentStamp({
    required String app,
    Map<SkillKey, FittedParameters>? fitted,
    List<LeechAction>? leechActions,
  }) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n, COALESCE(MIN(id), 0) AS lo, '
          'COALESCE(MAX(id), 0) AS hi, COALESCE(SUM(id), 0) AS ids, '
          'COALESCE(MAX(ts), 0) AS latest, '
          'COALESCE(SUM(ts % 1000000007), 0) AS times, '
          'COALESCE(SUM(grade), 0) AS grades, '
          'COALESCE(SUM(elapsed_ms), 0) AS elapsed FROM reviews',
        )
        .getSingle();
    return LogStamp(
      app: app,
      reviews: row.read<int>('n'),
      firstId: row.read<int>('lo'),
      lastId: row.read<int>('hi'),
      sumIds: row.read<int>('ids'),
      latest: row.read<int>('latest'),
      sumTimes: row.read<int>('times'),
      sumGrades: row.read<int>('grades'),
      sumElapsed: row.read<int>('elapsed'),
      leechActions: leechActions ?? await this.leechActions(),
      fitted: fitted ?? await this.fitted(),
    );
  }

  /// Keeps [bytes] as the snapshot, made under [stamp], if the database still
  /// has that stamp: checked in the same transaction as the write, so that a
  /// change that landed since [stamp] was taken is never covered by it.
  /// Returns whether it was kept.
  Future<bool> putSnapshot(
    LogStamp stamp,
    Uint8List bytes, {
    required String app,
  }) => _db.transaction(() async {
    if (await currentStamp(app: app) != stamp) return false;
    await _db.replaySnapshotsDao.put(
      stamp: stamp.text,
      payload: bytes,
      at: DateTime.now(),
    );
    return true;
  });

  /// Makes the snapshot from the log as it is, replaying it by [run] (on an
  /// isolate by default), for after the log has changed. It reads the log in
  /// pages, yielding between them, so that a long one does not hold the
  /// frames, and keeps the result only if nothing changed meanwhile
  /// ([putSnapshot]). Returns whether it was kept.
  Future<bool> saveSnapshot({
    required String app,
    ReplayRunner run = replayInIsolate,
    int pageSize = 4000,
  }) async {
    final fitted = await this.fitted();
    final actions = await leechActions();
    final stamp = await currentStamp(
      app: app,
      fitted: fitted,
      leechActions: actions,
    );
    final rows = <LoggedReview>[];
    for (var after = 0; ;) {
      final page = await _db.reviewsDao.page(after: after, limit: pageSize);
      if (page.isEmpty) break;
      rows.addAll(page.map(_logged));
      after = page.last.id;
      if (page.length < pageSize) break;
      await Future<void>.delayed(Duration.zero);
    }
    snapshotBuilds++;
    final opened = await run(
      OpenJob(
        reviews: rows,
        leechActions: actions,
        fitted: fitted,
        encode: true,
      ),
    );
    final bytes = opened.snapshot;
    return bytes != null && await putSnapshot(stamp, bytes, app: app);
  }

  /// How many snapshots have been made from the log after a change, for
  /// tests.
  static int snapshotBuilds = 0;

  /// FSRS's parameters as fitted to the learner, by language and skill.
  Future<Map<SkillKey, FittedParameters>> fitted() async =>
      <SkillKey, FittedParameters>{
        for (final row in await _db.fsrsParametersDao.all())
          (language: row.language, mode: row.mode): ?_fitted(row),
      };

  /// Keeps [value] as the fit of [key], replacing the one before, and
  /// rebuilds `card_states` with [parameters], which hold it, in one
  /// transaction.
  Future<void> putFitted(
    SkillKey key,
    FittedParameters value, {
    required SkillParameters parameters,
  }) => _db.transaction(() async {
    await _putFitted(key, value);
    await _rebuild(parameters);
  });

  Future<void> _putFitted(SkillKey key, FittedParameters value) =>
      _db.fsrsParametersDao.put(
        FsrsParametersCompanion.insert(
          language: key.language,
          mode: key.mode,
          parameters: value.values.join(','),
          fittedAt: value.fittedAt,
          reviewCount: value.reviewCount,
          lossBefore: Value(value.lossBefore),
          lossAfter: Value(value.lossAfter),
        ),
      );

  /// Every leech action, in the order it was taken.
  Future<List<LeechAction>> leechActions() => _db.leechActionsDao.all();

  /// Rebuilds `card_states` from `reviews` and `leech_actions` alone: every
  /// pair's reviews in order through [Fsrs.next], restarting a pair at a reset
  /// that still holds. In one transaction, so the cache is never seen
  /// half-built. This is the proof that the log is enough, and the path a
  /// change of algorithm will take. Each pair is scheduled with the
  /// [parameters] of its skill.
  Future<void> rebuildStates({SkillParameters? parameters}) =>
      _db.transaction(() => _rebuild(parameters));

  Future<void> _rebuild(SkillParameters? parameters) async =>
      _putStates((await _replay(parameters)).states);

  /// `card_states` replaced by [states], in one transaction: opening the app
  /// replays the log once and keeps both its events and these (#857).
  Future<void> putStates(Map<ProgressKey, FsrsState> states) =>
      _db.transaction(() => _putStates(states));

  /// Makes `card_states` equal [states] by writing only the rows that
  /// differ: most launches change none, and rewriting every row each time
  /// was a cost of opening the app (#857).
  Future<void> _putStates(Map<ProgressKey, FsrsState> states) async {
    final stale = <ProgressKey>{};
    final same = <ProgressKey>{};
    for (final row in await _db.cardStatesDao.all()) {
      final key = (cardId: row.cardId, mode: row.mode);
      final want = states[key];
      if (want != null && _sameRow(row, want)) {
        same.add(key);
      } else if (want == null) {
        stale.add(key);
      }
    }
    for (final key in stale) {
      await (_db.delete(_db.cardStates)..where(
            (s) => s.cardId.equals(key.cardId) & s.mode.equalsValue(key.mode),
          ))
          .go();
    }
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(_db.cardStates, <CardStatesCompanion>[
        for (final MapEntry(:key, :value) in states.entries)
          if (!same.contains(key)) value.toRow(key),
      ]);
    });
  }

  static bool _sameRow(CardStateRow row, FsrsState s) =>
      row.stability == s.stability &&
      row.difficulty == s.difficulty &&
      row.intervalDays == s.intervalDays &&
      row.repetitions == s.repetitions &&
      row.dueAt == s.dueAt &&
      row.lastReviewAt == s.lastReviewAt &&
      row.lapses == s.lapses;

  /// Merges a backup (#20): appends the reviews and leech actions the log
  /// does not already hold, then rebuilds `card_states` from the whole log,
  /// in one transaction. A review is the same review when its pair and
  /// moment match ([reviewIdentity]), so importing a backup twice adds
  /// nothing the second time. Returns how many reviews were new.
  ///
  /// A new row's interval, stability and difficulty columns are what
  /// replaying the merged log gives at that review. Rows already there keep
  /// theirs: those columns record what was computed when the row was
  /// written, and the state is always rebuilt from the grades.
  ///
  /// [fitted] are the backup's fitted parameters: each is kept unless the
  /// profile has a later fit of its skill. Every state is then replayed
  /// with [parameters] given the merged log's last studies and the merged
  /// fits; the fits kept are returned with the count.
  Future<({int added, Map<SkillKey, FittedParameters> fitted})> importAll(
    List<LoggedReview> reviews,
    List<LeechAction> leechActions, {
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
  }) => _db.transaction(() async {
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
    final all = inTimeOrder(<LoggedReview>[...existing, ...fresh]);
    final parameters = SkillParameters(
      fitted: await this.fitted(),
      lastStudied: SkillParameters.lastStudiedIn(all.map(_studied)),
    ).merged(fitted);
    for (final MapEntry(:key, :value) in parameters.fitted.entries) {
      await _putFitted(key, value);
    }
    if (fresh.isNotEmpty) {
      final merged = replayReviews(
        all,
        effects: LeechEffects(await _actions()),
        parameters: parameters,
      );
      final isFresh = <String>{for (final r in fresh) reviewIdentity(r)};
      for (final event in merged.events) {
        if (!isFresh.contains(reviewIdentity(logged(event)))) continue;
        await _append(event);
      }
    }
    await _rebuild(parameters);
    return (added: fresh.length, fitted: parameters.fitted);
  });

  /// Restores a backup (#470): the log, the leech actions and the fitted
  /// parameters become [reviews], [leechActions] and [fitted], and
  /// `card_states` is rebuilt from them, in one transaction, with [restore]
  /// kept in `restores`. Through [AppDatabase.replaceLog], the one exception
  /// to the log being append-only (AGENTS.md rule 9): only for a restore
  /// the learner has confirmed, after a copy of what it replaces is kept.
  /// A failure leaves everything as it was.
  ///
  /// Each review's interval, stability and difficulty columns are what
  /// replaying the restored log gives, as for a merge ([importAll]).
  Future<void> replaceAll(
    List<LoggedReview> reviews,
    List<LeechAction> leechActions, {
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
    required RestoreRecord restore,
  }) => _db.replaceLog(restore, () async {
    for (final a in actionsInTimeOrder(leechActions)) {
      await _db.leechActionsDao.append(a);
    }
    await _db.delete(_db.fsrsParameters).go();
    final all = inTimeOrder(reviews);
    final parameters = SkillParameters(
      fitted: fitted,
      lastStudied: SkillParameters.lastStudiedIn(all.map(_studied)),
    );
    for (final MapEntry(:key, :value) in fitted.entries) {
      await _putFitted(key, value);
    }
    final replayed = replayReviews(
      all,
      effects: LeechEffects(await _actions()),
      parameters: parameters,
    );
    for (final event in replayed.events) {
      await _append(event);
    }
    await _rebuild(parameters);
  });

  Future<void> _append(ReviewEvent event) => _db.reviewsDao.append(
    ReviewsCompanion.insert(
      ts: event.at,
      deckId: event.deckId,
      cardId: event.cardId,
      mode: event.mode,
      grade: event.grade,
      elapsedMs: event.elapsed.inMilliseconds,
      answerGiven: Value(event.answerGiven),
      script: Value(event.script),
      asked: Value(event.asked?.name),
      intervalBefore: Value(event.before?.intervalDays),
      intervalAfter: event.after.intervalDays,
      stabilityAfter: Value(event.after.stability),
      difficultyAfter: Value(event.after.difficulty),
    ),
  );

  /// Appends [action] and brings its pair's state in `card_states` in line
  /// with it, in one transaction. No review is touched.
  Future<void> act(LeechAction action, {SkillParameters? parameters}) =>
      _db.transaction(() async {
        await _db.leechActionsDao.append(action);
        final key = action.key;
        final state = (await _replay(parameters)).states[key];
        if (state == null) {
          await (_db.delete(_db.cardStates)..where(
                (s) =>
                    s.cardId.equals(key.cardId) & s.mode.equalsValue(key.mode),
              ))
              .go();
        } else {
          await _db.cardStatesDao.put(state.toRow(key));
        }
      });

  Future<Replayed> _replay(SkillParameters? parameters) async =>
      replay(await reviews(), parameters: parameters);

  /// How many times the whole log has been replayed, for tests to assert
  /// that opening the app does it once.
  static int replays = 0;

  /// [reviews], oldest first and read from this log, replayed with its leech
  /// actions: each pair's own reviews alone, without what other skills imply.
  Future<Replayed> replay(
    List<LoggedReview> reviews, {
    SkillParameters? parameters,
  }) async {
    replays++;
    return replayReviews(
      reviews,
      effects: LeechEffects(await _actions()),
      parameters: parameters,
    );
  }

  /// Every leech action, oldest first.
  Future<List<LeechAction>> _actions() async =>
      actionsInTimeOrder(await _db.leechActionsDao.all());
}

({String cardId, DateTime at}) _studied(LoggedReview r) =>
    (cardId: r.key.cardId, at: r.at);

/// [row]'s fit, or null for one that does not hold 21 numbers.
FittedParameters? _fitted(FsrsParametersRow row) {
  final values = <double>[];
  for (final text in row.parameters.split(',')) {
    final value = double.tryParse(text);
    if (value == null || !value.isFinite) return null;
    values.add(value);
  }
  if (values.length != Fsrs.w.length) return null;
  return FittedParameters(
    values: values,
    fittedAt: row.fittedAt,
    reviewCount: row.reviewCount,
    lossBefore: row.lossBefore,
    lossAfter: row.lossAfter,
  );
}

LoggedReview _logged(ReviewRow row) => (
  key: (cardId: row.cardId, mode: row.mode),
  deckId: row.deckId,
  at: row.ts,
  grade: row.grade,
  elapsed: Duration(milliseconds: row.elapsedMs),
  answerGiven: row.answerGiven,
  script: row.script,
  asked: Ask.values.asNameMap()[row.asked],
);
