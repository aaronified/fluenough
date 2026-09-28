import 'package:flutter/foundation.dart';

import '../core/data/log_jsonl.dart';
import '../core/models/drill_mode.dart';
import '../core/models/leech_action.dart';
import '../core/models/review_event.dart';
import '../core/scheduling/replay.dart';
import '../core/scheduling/sm2.dart';

export '../core/models/leech_action.dart';
export '../core/models/review_event.dart';

/// Scheduling state and the review log, as the interface reads them.
///
/// [MemoryProgress] keeps it in memory, and `DatabaseProgress` in the
/// profile's database; nothing that reads through this interface can tell
/// them apart but [persists]. Listeners are told after every [record].
abstract interface class ProgressStore implements Listenable {
  /// Whether this store outlives the app: false for [MemoryProgress].
  bool get persists;

  /// The state of one pair, or null if it has never been reviewed.
  Sm2State? stateOf(String deckId, String cardId, DrillMode mode);

  /// Every pair that has been reviewed, with its current state.
  Map<ProgressKey, Sm2State> get states;

  /// Every review, oldest first. Append-only: nothing is ever removed.
  List<ReviewEvent> get log;

  /// Records a review: runs [Sm2.next] on the pair's state, appends the
  /// event, and returns it. Call it the moment the answer is given.
  ReviewEvent record({
    required String deckId,
    required String cardId,
    required DrillMode mode,
    required int grade,
    required DateTime now,
    Duration elapsed = Duration.zero,
    String? answerGiven,
  });

  /// What the learner has done about leeches, oldest first. Append-only.
  List<LeechAction> get leechActions;

  /// Records [kind] for [key] and applies it: a reset restarts the pair's
  /// scheduling, and a set-aside keeps it out of sessions. No review is
  /// touched. Returns the action.
  LeechAction actOnLeech(
    ProgressKey key,
    LeechActionKind kind, {
    required DateTime now,
  });

  /// Merges a backup (#20): adds the [reviews] and [leechActions] not
  /// already here, then rebuilds every state from the whole log. Importing
  /// the same backup twice adds nothing. Returns how many reviews were new.
  Future<int> importLog(
    List<LoggedReview> reviews,
    List<LeechAction> leechActions,
  );
}

/// Progress held in memory: an SM-2 state per `(deck, card, mode)` and the
/// review log, both gone when the app closes.
///
/// For tests and fixtures, and the fallback when the database cannot be
/// opened, in which case Today says that progress is not saved.
class MemoryProgress extends ChangeNotifier implements ProgressStore {
  MemoryProgress();

  /// Progress rebuilt from [events], oldest first, and [leechActions], by
  /// replaying them as the database does (ADR-0005, [replayReviews]).
  factory MemoryProgress.replaying(
    Iterable<ReviewEvent> events, {
    Iterable<LeechAction> leechActions = const <LeechAction>[],
  }) {
    final actions = leechActions.toList();
    final replayed = replayReviews(
      events.map(logged),
      effects: LeechEffects(actions),
    );
    return MemoryProgress()
      .._log.addAll(replayed.events)
      .._states.addAll(replayed.states)
      .._leechActions.addAll(actions);
  }

  final Map<ProgressKey, Sm2State> _states = <ProgressKey, Sm2State>{};
  final List<ReviewEvent> _log = <ReviewEvent>[];
  final List<LeechAction> _leechActions = <LeechAction>[];

  @override
  bool get persists => false;

  @override
  Sm2State? stateOf(String deckId, String cardId, DrillMode mode) =>
      _states[(deckId: deckId, cardId: cardId, mode: mode)];

  @override
  Map<ProgressKey, Sm2State> get states =>
      Map<ProgressKey, Sm2State>.unmodifiable(_states);

  @override
  List<ReviewEvent> get log => List<ReviewEvent>.unmodifiable(_log);

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
    final key = (deckId: deckId, cardId: cardId, mode: mode);
    final before = _states[key];
    final after = Sm2.next(before ?? Sm2State.fresh(now), grade, now: now);
    final event = ReviewEvent(
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
    _states[key] = after;
    _log.add(event);
    notifyListeners();
    return event;
  }

  @override
  List<LeechAction> get leechActions =>
      List<LeechAction>.unmodifiable(_leechActions);

  @override
  LeechAction actOnLeech(
    ProgressKey key,
    LeechActionKind kind, {
    required DateTime now,
  }) {
    final action = LeechAction(at: now, key: key, kind: kind);
    _leechActions.add(action);
    final replayed = replayReviews(
      _log.map(logged),
      effects: LeechEffects(_leechActions),
    );
    _states
      ..clear()
      ..addAll(replayed.states);
    notifyListeners();
    return action;
  }

  @override
  Future<int> importLog(
    List<LoggedReview> reviews,
    List<LeechAction> leechActions,
  ) async {
    final known = <String>{for (final e in _log) reviewIdentity(logged(e))};
    final fresh = <LoggedReview>[
      for (final r in reviews)
        if (known.add(reviewIdentity(r))) r,
    ];
    final knownActions = <String>{
      for (final a in _leechActions) leechIdentity(a),
    };
    final actions = actionsInTimeOrder(<LeechAction>[
      ..._leechActions,
      for (final a in leechActions)
        if (knownActions.add(leechIdentity(a))) a,
    ]);
    _replace(
      inTimeOrder(<LoggedReview>[..._log.map(logged), ...fresh]),
      actions,
    );
    return fresh.length;
  }

  /// Everything replaced by [events] and [leechActions], and the states
  /// rebuilt from them. For an import (#20).
  void replaceWith(List<ReviewEvent> events, List<LeechAction> leechActions) =>
      _replace(
        inTimeOrder(events.map(logged)),
        actionsInTimeOrder(leechActions),
      );

  /// [reviews] and [actions] are oldest first.
  void _replace(List<LoggedReview> reviews, List<LeechAction> actions) {
    final replayed = replayReviews(reviews, effects: LeechEffects(actions));
    _log
      ..clear()
      ..addAll(replayed.events);
    _states
      ..clear()
      ..addAll(replayed.states);
    _leechActions
      ..clear()
      ..addAll(actions);
    notifyListeners();
  }
}

/// Questions every screen asks of a [ProgressStore], answered the same way
/// everywhere. Pure reads of [ProgressStore.states] and [ProgressStore.log].
extension ProgressQueries on ProgressStore {
  /// The review log and leech actions as a JSONL backup (#20).
  String exportJsonl() => LogJsonl.encode(
    inTimeOrder(log.map(logged)),
    actionsInTimeOrder(leechActions),
  );

  /// What the leech actions add up to: which pairs are reset or set aside.
  LeechEffects get leechEffects => LeechEffects(leechActions);

  /// What [grade] would do to the pair, without recording anything. The
  /// rating buttons label themselves with its `intervalDays`.
  Sm2State preview(
    String deckId,
    String cardId,
    DrillMode mode,
    int grade, {
    required DateTime now,
  }) => Sm2.next(
    stateOf(deckId, cardId, mode) ?? Sm2State.fresh(now),
    grade,
    now: now,
  );

  /// New pairs introduced on [day]'s calendar date, which the daily cap
  /// counts against.
  int newIntroducedOn(DateTime day) =>
      log.where((e) => e.wasNew && isSameDay(e.at, day)).length;

  /// Reviews given on [day]'s calendar date.
  int reviewsOn(DateTime day) => log.where((e) => isSameDay(e.at, day)).length;

  /// Whether any review was given on [day]'s calendar date.
  bool practisedOn(DateTime day) => log.any((e) => isSameDay(e.at, day));

  /// Consecutive days with a review, ending today — or yesterday, if today
  /// has none yet, so that a streak is not broken before the day is over.
  int streakAt(DateTime now) {
    final days = <DateTime>{for (final e in log) dateOnly(e.at)};
    var day = dateOnly(now);
    if (!days.contains(day)) day = addDays(day, -1);
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = addDays(day, -1);
    }
    return streak;
  }

  /// Distinct cards in [deckId] reviewed successfully at least once, in any
  /// mode: the deck's "Learned" count.
  int learnedIn(String deckId) => <String>{
    for (final entry in states.entries)
      if (entry.key.deckId == deckId && entry.value.repetitions > 0)
        entry.key.cardId,
  }.length;

  /// Distinct cards due by the end of the calendar day after [now] and not
  /// due at [now]: "Next due: 14 cards tomorrow".
  int dueTomorrow(DateTime now) {
    final endOfTomorrow = addDays(dateOnly(now), 2);
    return <String>{
      for (final entry in states.entries)
        if (!entry.value.isDue(now) &&
            entry.value.dueAt.isBefore(endOfTomorrow))
          '${entry.key.deckId}/${entry.key.cardId}',
    }.length;
  }
}

/// Midnight at the start of [time]'s calendar day, in its time zone.
DateTime dateOnly(DateTime time) => time.isUtc
    ? DateTime.utc(time.year, time.month, time.day)
    : DateTime(time.year, time.month, time.day);

/// [day] moved by whole calendar days, safe across daylight saving changes.
DateTime addDays(DateTime day, int days) => day.isUtc
    ? DateTime.utc(day.year, day.month, day.day + days)
    : DateTime(day.year, day.month, day.day + days);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
