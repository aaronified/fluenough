import 'package:flutter/foundation.dart';

import '../core/data/database.dart';
import '../core/data/review_log.dart';
import '../core/models/drill_mode.dart';
import '../core/scheduling/replay.dart';
import '../core/scheduling/sm2.dart';
import 'memory_progress.dart';

/// A profile's progress, kept in its own database file (#3, #5) and read
/// into memory when the app opens.
///
/// Screens read synchronously, so reads come from memory. The database is
/// the record: opening rebuilds its state cache from the review log and
/// replays the log into memory, so log, cache and memory agree. Each
/// [record] updates memory at once and is written to the database in the
/// order it was recorded. An answer given in the instant before the app is
/// killed can be lost; nothing already written can be.
class DatabaseProgress extends ChangeNotifier implements ProgressStore {
  DatabaseProgress._(this._db, this._log, this._memory) {
    _memory.addListener(notifyListeners);
  }

  /// Progress over [db]. [close] closes the database.
  static Future<DatabaseProgress> open(AppDatabase db) async {
    final log = ReviewLog(db);
    await log.rebuildStates();
    final memory = MemoryProgress.replaying(
      await log.events(),
      leechActions: await log.leechActions(),
    );
    return DatabaseProgress._(db, log, memory);
  }

  final AppDatabase _db;
  final ReviewLog _log;
  final MemoryProgress _memory;
  Future<void> _writes = Future<void>.value();
  Object? _writeError;

  @override
  bool get persists => true;

  @override
  Sm2State? stateOf(String cardId, DrillMode mode) =>
      _memory.stateOf(cardId, mode);

  @override
  Map<ProgressKey, Sm2State> get states => _memory.states;

  @override
  List<ReviewEvent> get log => _memory.log;

  @override
  List<LeechAction> get leechActions => _memory.leechActions;

  @override
  LeechAction actOnLeech(
    ProgressKey key,
    LeechActionKind kind, {
    required DateTime now,
  }) {
    final action = _memory.actOnLeech(key, kind, now: now);
    _write(() => _log.act(action), 'while saving a leech action');
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
  }) {
    final event = _memory.record(
      deckId: deckId,
      cardId: cardId,
      mode: mode,
      grade: grade,
      now: now,
      elapsed: elapsed,
      answerGiven: answerGiven,
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
      ),
      'while saving a review',
    );
    return event;
  }

  /// Queues [write] after every write before it. A failure is reported
  /// through [FlutterError] and kept for [flush].
  void _write(Future<Object?> Function() write, String context) {
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
    List<LeechAction> leechActions,
  ) async {
    await _writes;
    final added = await _log.importAll(reviews, leechActions);
    _memory.replaceWith(await _log.events(), await _log.leechActions());
    return added;
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
    await _writes;
    await _db.close();
  }

  @override
  void dispose() {
    _memory.removeListener(notifyListeners);
    _memory.dispose();
    super.dispose();
  }
}
