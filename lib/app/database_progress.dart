import 'package:flutter/foundation.dart';

import '../core/data/database.dart';
import '../core/data/review_log.dart';
import '../core/models/drill_mode.dart';
import '../core/scheduling/replay.dart';
import '../core/scheduling/fsrs.dart';
import '../core/scheduling/skill_map.dart';
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
    final fitted = await log.fitted();
    final parameters = SkillParameters(
      fitted: fitted,
      lastStudied: SkillParameters.lastStudiedIn(
        <({String cardId, DateTime at})>[
          for (final r in await log.reviews()) (cardId: r.key.cardId, at: r.at),
        ],
      ),
    );
    await log.rebuildStates(parameters: parameters);
    final memory = MemoryProgress.replaying(
      await log.events(parameters: parameters),
      leechActions: await log.leechActions(),
      fitted: fitted,
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
  FsrsState? stateOf(String cardId, DrillMode mode) =>
      _memory.stateOf(cardId, mode);

  @override
  Map<ProgressKey, FsrsState> get states => _memory.states;

  @override
  List<ReviewEvent> get log => _memory.log;

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
    await _memory.putFitted(key, value);
    final parameters = _memory.parameters;
    _write(
      () => _log.putFitted(key, value, parameters: parameters),
      'while saving fitted parameters',
    );
    await _writes;
  }

  @override
  LeechAction actOnLeech(
    ProgressKey key,
    LeechActionKind kind, {
    required DateTime now,
  }) {
    final action = _memory.actOnLeech(key, kind, now: now);
    final parameters = _memory.parameters;
    _write(
      () => _log.act(action, parameters: parameters),
      'while saving a leech action',
    );
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
    final chosen = _memory.parameters;
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
    List<LeechAction> leechActions, {
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
  }) async {
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
    return imported.added;
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
