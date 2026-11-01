import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/data/database.dart';
import '../core/data/replay_isolate.dart';
import '../core/data/review_log.dart';
import '../core/models/drill_mode.dart';
import '../core/scheduling/ask.dart';
import '../core/scheduling/replay.dart';
import '../core/scheduling/fsrs.dart';
import '../core/scheduling/skill_map.dart';
import 'app_info.dart';
import 'memory_progress.dart';

/// A profile's progress, kept in its own database file (#3, #5) and read
/// into memory when the app opens ([open], or [opening] to read in the
/// background).
///
/// Screens read synchronously, so reads come from memory. The database is
/// the record: opening rebuilds its state cache from the review log and
/// replays the log into memory, so log, cache and memory agree. Each
/// [record] updates memory at once and is written to the database in the
/// order it was recorded. An answer given in the instant before the app is
/// killed can be lost; nothing already written can be.
class DatabaseProgress extends ChangeNotifier implements ProgressStore {
  DatabaseProgress._(
    this._db,
    this._log,
    this._memory,
    this._replayer,
    this._snapshotter,
    this._app,
    this._snapshotAfter,
    this._stage,
  ) {
    _memory.addListener(notifyListeners);
  }

  /// Progress over [db], read from the review log: completes once it has
  /// been. [close] closes the database.
  static Future<DatabaseProgress> open(
    AppDatabase db, {
    ReplayRunner replayer = replayInIsolate,
    SnapshotRunner snapshotter = snapshotInIsolate,
    String app = AppInfo.version,
    Duration? snapshotAfter,
    void Function(String stage)? onStage,
  }) async {
    final progress = DatabaseProgress.opening(
      db,
      replayer: replayer,
      snapshotter: snapshotter,
      app: app,
      snapshotAfter: snapshotAfter,
      onStage: onStage,
    );
    await progress.ready;
    return progress;
  }

  /// Progress over [db] at once, read from the review log in the background
  /// so that the first frame need not wait for it (#857). Until [ready]
  /// completes it holds nothing: whatever reads it waits for [ready] first
  /// (`AppState` does before it shows anything), and no write reaches the
  /// database before the log has been read. If the log cannot be read,
  /// [ready] still completes and this falls back to what a profile whose
  /// database cannot be opened has: progress kept in memory only, [persists]
  /// false so that Today says it is not saved, and nothing written to the
  /// database, whose log is left as it is.
  ///
  /// The log is sorted and replayed by [replayer], on an isolate by default
  /// (#857), so that a long log does not freeze the app: only reading rows
  /// and writing the state cache stay here, in the order they always had.
  /// When the database holds a snapshot of the replay made from this very
  /// log, fitted parameters and app version (`ReviewLog.openCached`,
  /// ADR-0051), it is read, on an isolate by [snapshotter], in place of the
  /// replay, and the result is the same; anything else replays and then
  /// keeps a new snapshot, queued behind the read. After a change a new one
  /// is made once the learner has paused for [snapshotAfter] (never, when it
  /// is null) and by [saveSnapshot].
  ///
  /// [onStage] hears when the replay is back ('review log replayed') or the
  /// snapshot is ('snapshot loaded'), and when the state cache is written
  /// ('state cache written'), for the startup timing.
  factory DatabaseProgress.opening(
    AppDatabase db, {
    ReplayRunner replayer = replayInIsolate,
    SnapshotRunner snapshotter = snapshotInIsolate,
    String app = AppInfo.version,
    Duration? snapshotAfter,
    void Function(String stage)? onStage,
  }) {
    final progress = DatabaseProgress._(
      db,
      ReviewLog(db),
      MemoryProgress(),
      replayer,
      snapshotter,
      app,
      snapshotAfter,
      onStage,
    );
    final ready = progress._read();
    progress._ready = ready;
    // Every write is queued behind the read, whether it succeeds or not.
    progress._writes = ready.then<void>((_) {}, onError: (_) {});
    return progress;
  }

  /// Completes once the review log has been read into memory, and the state
  /// cache rebuilt from it, or once reading it has failed ([persists]). Never
  /// throws: a failed read must not leave the catalog failed for good.
  @override
  Future<void> get ready => _ready;
  late final Future<void> _ready;

  Future<void> _read() async {
    try {
      await _readLog();
    } catch (error, stack) {
      // Fall back to in-memory progress, unsaved, rather than no app: the
      // empty memory is never written over the database's log.
      _readFailed = true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'fluenough progress',
          context: ErrorDescription('while reading the review log'),
        ),
      );
    } finally {
      _isReady = true;
    }
  }

  Future<void> _readLog() async {
    final log = _log;
    final fitted = await log.fitted();
    // Reading the kept snapshot, or else sorting, replaying (twice) and
    // indexing the whole log, is one job on an isolate; its result is what
    // the state cache and memory both come from.
    final opening = await log.openCached(
      fitted: fitted,
      app: _app,
      run: _replayer,
      fromSnapshot: _snapshotter,
    );
    final opened = opening.opened;
    _stage?.call(
      opening.fromSnapshot ? 'snapshot loaded' : 'review log replayed',
    );
    await log.putStates(opened.cacheStates);
    _stage?.call('state cache written');
    final stamp = opening.stamp;
    final bytes = opening.bytes;
    if (stamp != null && bytes != null) {
      // Kept for the next launch, behind this read and before every write
      // after it; a failure costs only that launch's replay.
      _snapshotTask(() => log.putSnapshot(stamp, bytes, app: _app));
    }
    final memory = MemoryProgress.opened(opened, fitted: fitted);
    final discarded = _memory;
    discarded.removeListener(notifyListeners);
    _memory = memory..addListener(notifyListeners);
    discarded.dispose();
    notifyListeners();
  }

  final AppDatabase _db;
  final ReviewLog _log;
  final ReplayRunner _replayer;
  final SnapshotRunner _snapshotter;
  final String _app;
  final Duration? _snapshotAfter;
  final void Function(String stage)? _stage;
  Timer? _snapshotTimer;
  Future<void>? _snapshotRun;
  bool _snapshotAgain = false;
  bool _snapshotKept = false;
  bool _disposed = false;
  MemoryProgress _memory;
  late Future<void> _writes;
  Object? _writeError;
  bool _isReady = false;

  /// Whether reading the log failed: progress is then in memory only.
  bool _readFailed = false;

  @override
  bool get persists => !_readFailed;

  @override
  int get version => _memory.version;

  @override
  int versionOf(String language) => _memory.versionOf(language);

  @override
  ProgressIndex get index => _memory.index;

  @override
  FsrsState? stateOf(String cardId, DrillMode mode) =>
      _memory.stateOf(cardId, mode);

  @override
  Map<ProgressKey, FsrsState> get states => _memory.states;

  @override
  List<ReviewEvent> get log => _memory.log;

  @override
  Map<ScriptKey, FsrsState> get scriptStates => _memory.scriptStates;

  @override
  List<ReviewEvent> get scriptLog => _memory.scriptLog;

  @override
  List<LeechAction> get leechActions => _memory.leechActions;

  /// Kept in memory only: `card_states` caches each pair's own reviews, and
  /// what other skills imply is worked out again from the log when the app
  /// opens.
  @override
  SkillMap get skills => _memory.skills;

  @override
  set skills(SkillMap value) => _memory.skills = value;

  @override
  SkillParameters get parameters => _memory.parameters;

  /// Kept in the database with `card_states` rebuilt from it, in the order
  /// of every write before it.
  @override
  Future<void> putFitted(SkillKey key, FittedParameters value) async {
    assert(_isReady, 'putFitted before ready');
    await _memory.putFitted(key, value);
    if (_readFailed) return;
    final parameters = _memory.parameters;
    _write(
      () => _log.putFitted(key, value, parameters: parameters),
      'while saving fitted parameters',
    );
    _scheduleSnapshot();
    await _writes;
  }

  @override
  LeechAction actOnLeech(
    ProgressKey key,
    LeechActionKind kind, {
    required DateTime now,
  }) {
    assert(_isReady, 'actOnLeech before ready');
    final action = _memory.actOnLeech(key, kind, now: now);
    final parameters = _memory.parameters;
    _write(
      () => _log.act(action, parameters: parameters),
      'while saving a leech action',
    );
    _scheduleSnapshot();
    return action;
  }

  @override
  ReviewEvent record({
    required String deckId,
    required String cardId,
    required DrillMode mode,
    required int grade,
    required DateTime now,
    Duration elapsed = Duration.zero,
    String? answerGiven,
    String? script,
    Ask? asked,
  }) {
    assert(_isReady, 'record before ready');
    final chosen = _memory.parameters;
    final event = _memory.record(
      deckId: deckId,
      cardId: cardId,
      mode: mode,
      grade: grade,
      now: now,
      elapsed: elapsed,
      answerGiven: answerGiven,
      script: script,
      asked: asked,
    );
    _write(
      () => _log.record(
        deckId: deckId,
        cardId: cardId,
        mode: mode,
        grade: grade,
        now: now,
        elapsed: elapsed,
        answerGiven: answerGiven,
        script: script,
        asked: asked,
        parameters: chosen.forPair((cardId: cardId, mode: mode)),
      ),
      'while saving a review',
    );
    // This review changed which set schedules some pairs: the cache is
    // rebuilt with the new choice, as memory was.
    final current = _memory.parameters;
    if (!current.sameAs(chosen)) {
      _write(
        () => _log.rebuildStates(parameters: current),
        'while rescheduling',
      );
    }
    _scheduleSnapshot();
    return event;
  }

  /// Queues [write] after every write before it. A failure is reported
  /// through [FlutterError] and kept for [flush].
  void _write(Future<Object?> Function() write, String context) {
    // After a failed read memory holds only what was recorded since: it is
    // never written to a database whose log it does not match.
    if (_readFailed) return;
    _writes = _writes
        .then((_) => write())
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            _writeError ??= error;
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                library: 'fluenough progress',
                context: ErrorDescription(context),
              ),
            );
          },
        );
  }

  @override
  Future<int> importLog(
    List<LoggedReview> reviews,
    List<LeechAction> leechActions, {
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
  }) async {
    if (_readFailed) {
      return _memory.importLog(reviews, leechActions, fitted: fitted);
    }
    await _writes;
    final imported = await _log.importAll(
      reviews,
      leechActions,
      fitted: fitted,
    );
    _memory.replaceWith(
      await _log.events(),
      await _log.leechActions(),
      fitted: imported.fitted,
    );
    _scheduleSnapshot();
    return imported.added;
  }

  /// Restores a backup: the one exception to `reviews` and `leech_actions`
  /// being append-only (AGENTS.md rule 9; owner, 2026-10-17: "Logged
  /// exception"), kept in `restores` as [restore], in the transaction that
  /// replaces them ([ReviewLog.replaceAll]). Then memory is read again from
  /// the database. A failure leaves both as they were.
  @override
  Future<void> replaceAll(
    List<LoggedReview> reviews,
    List<LeechAction> leechActions, {
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
    required RestoreRecord restore,
  }) async {
    if (_readFailed) {
      return _memory.replaceAll(
        reviews,
        leechActions,
        fitted: fitted,
        restore: restore,
      );
    }
    await _writes;
    await _log.replaceAll(
      reviews,
      leechActions,
      fitted: fitted,
      restore: restore,
    );
    _memory.replaceWith(
      await _log.events(),
      await _log.leechActions(),
      fitted: await _log.fitted(),
    );
    _scheduleSnapshot();
  }

  /// Runs [task] after every write queued so far. Keeping the snapshot is a
  /// cache: if it fails, nothing is reported to the learner and the next
  /// launch replays the log, so the failure is only printed.
  void _snapshotTask(Future<Object?> Function() task) {
    _writes = _writes.then<void>((_) async {
      try {
        await task();
      } on Object catch (error) {
        debugPrint('Could not keep the review-log snapshot: $error');
      }
    });
  }

  /// Arms the snapshot to be made once the learner pauses: each change
  /// restarts the wait, so a session is one snapshot, not one per answer.
  void _scheduleSnapshot() {
    final after = _snapshotAfter;
    if (after == null || _readFailed || _disposed) return;
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer(after, () {
      unawaited(saveSnapshot());
    });
  }

  /// Makes and keeps a snapshot of the log as it is now, after every write
  /// queued so far, by replaying the log from the database
  /// (`ReviewLog.saveSnapshot`), not from memory: the snapshot is the
  /// replay's result and can be nothing else. One runs at a time; a change
  /// during one starts another after it. Returns whether the last one kept
  /// its snapshot. Never throws.
  Future<bool> saveSnapshot() async {
    if (_readFailed || _disposed) return false;
    final running = _snapshotRun;
    if (running != null) {
      _snapshotAgain = true;
      await running;
      return _snapshotKept;
    }
    final run = () async {
      do {
        _snapshotAgain = false;
        try {
          await _writes;
          _snapshotKept = await _log.saveSnapshot(app: _app, run: _replayer);
        } on Object catch (error) {
          _snapshotKept = false;
          debugPrint('Could not make the review-log snapshot: $error');
        }
      } while (_snapshotAgain && !_disposed);
    }();
    _snapshotRun = run;
    await run;
    _snapshotRun = null;
    return _snapshotKept;
  }

  /// Completes once every review recorded so far is in the database.
  /// Throws the first write that failed, if one did.
  Future<void> flush() async {
    await _writes;
    final error = _writeError;
    if (error != null) throw error;
  }

  /// Finishes the writes in flight and closes the database.
  Future<void> close() async {
    _snapshotTimer?.cancel();
    _disposed = true;
    await _writes;
    await _snapshotRun;
    await _db.close();
  }

  @override
  void dispose() {
    _snapshotTimer?.cancel();
    _disposed = true;
    _memory.removeListener(notifyListeners);
    _memory.dispose();
    super.dispose();
  }
}
