import 'package:flutter/foundation.dart';

import '../core/data/log_jsonl.dart';
import '../core/models/drill_mode.dart';
import '../core/models/leech_action.dart';
import '../core/models/review_event.dart';
import '../core/scheduling/replay.dart';
import '../core/scheduling/fsrs.dart';
import '../core/scheduling/skill_map.dart';
import '../core/scheduling/skill_parameters.dart';

export '../core/models/leech_action.dart';
export '../core/models/review_event.dart';
export '../core/scheduling/skill_parameters.dart'
    show FittedParameters, SkillKey, SkillParameters, skillOf;

/// Scheduling state and the review log, as the interface reads them.
///
/// [MemoryProgress] keeps it in memory, and `DatabaseProgress` in the
/// profile's database; nothing that reads through this interface can tell
/// them apart but [persists]. Listeners are told after every [record].
abstract interface class ProgressStore implements Listenable {
  /// Whether this store outlives the app: false for [MemoryProgress].
  bool get persists;

  /// The state of one pair, or null if it has never been reviewed. A pair is
  /// a card and a mode, in whichever deck lists the card (ADR-0018).
  FsrsState? stateOf(String cardId, DrillMode mode);

  /// Every pair that has been reviewed, with its current state.
  Map<ProgressKey, FsrsState> get states;

  /// Every review, oldest first. Append-only: nothing is ever removed.
  List<ReviewEvent> get log;

  /// Records a review: runs [Fsrs.next] on the pair's state, with the
  /// parameters that schedule its skill ([parameters]), appends the event,
  /// and returns it. Call it the moment the answer is given.
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

  /// Which skills a right answer implies (ADR-0034). Setting it rebuilds
  /// every state from the log with it.
  SkillMap get skills;
  set skills(SkillMap value);

  /// Records [kind] for [key] and applies it: a reset restarts the pair's
  /// scheduling, and a set-aside keeps it out of sessions. No review is
  /// touched. Returns the action.
  LeechAction actOnLeech(
    ProgressKey key,
    LeechActionKind kind, {
    required DateTime now,
  });

  /// FSRS's parameters fitted to the learner, by language and skill, and
  /// which set schedules each pair (`SkillParameters`).
  SkillParameters get parameters;

  /// Keeps [value] as the fit of [key], replacing the one before, and
  /// rebuilds every state with the parameters it gives: the skill's pairs
  /// in that language, and those of any language that takes its fit as a
  /// baseline.
  Future<void> putFitted(SkillKey key, FittedParameters value);

  /// Merges a backup (#20): adds the [reviews] and [leechActions] not
  /// already here, and each of the [fitted] parameters unless this store
  /// has a later fit of its skill, then rebuilds every state from the
  /// whole log. Importing the same backup twice adds nothing. Returns how
  /// many reviews were new.
  Future<int> importLog(
    List<LoggedReview> reviews,
    List<LeechAction> leechActions, {
    Map<SkillKey, FittedParameters> fitted,
  });
}

/// Progress held in memory: an FSRS state per `(card, mode)` and the
/// review log, both gone when the app closes.
///
/// For tests and fixtures, and the fallback when the database cannot be
/// opened, in which case Today says that progress is not saved.
class MemoryProgress extends ChangeNotifier implements ProgressStore {
  MemoryProgress();

  /// Progress rebuilt from [events], oldest first, [leechActions] and the
  /// [fitted] parameters, by replaying them as the database does
  /// (ADR-0005, [replayReviews]).
  factory MemoryProgress.replaying(
    Iterable<ReviewEvent> events, {
    Iterable<LeechAction> leechActions = const <LeechAction>[],
    SkillMap skills = const SkillMap(),
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
  }) {
    final actions = leechActions.toList();
    final reviews = events.map(logged).toList();
    final parameters = SkillParameters(
      fitted: fitted,
      lastStudied: _lastStudied(reviews),
    );
    final replayed = replayReviews(
      reviews,
      effects: LeechEffects(actions),
      skills: skills,
      parameters: parameters,
    );
    return MemoryProgress()
      .._skills = skills
      .._parameters = parameters
      .._log.addAll(replayed.events)
      .._states.addAll(replayed.states)
      .._leechActions.addAll(actions);
  }

  final Map<ProgressKey, FsrsState> _states = <ProgressKey, FsrsState>{};
  final List<ReviewEvent> _log = <ReviewEvent>[];
  final List<LeechAction> _leechActions = <LeechAction>[];
  SkillMap _skills = const SkillMap();
  SkillParameters _parameters = SkillParameters.none;

  @override
  SkillParameters get parameters => _parameters;

  static Map<String, DateTime> _lastStudied(Iterable<LoggedReview> reviews) =>
      SkillParameters.lastStudiedIn(<({String cardId, DateTime at})>[
        for (final r in reviews) (cardId: r.key.cardId, at: r.at),
      ]);

  @override
  Future<void> putFitted(SkillKey key, FittedParameters value) async {
    _parameters = _parameters.withFit(key, value);
    _replace(_log.map(logged).toList(), _leechActions.toList());
  }

  @override
  bool get persists => false;

  @override
  SkillMap get skills => _skills;

  @override
  set skills(SkillMap value) {
    if (value == _skills) return;
    _skills = value;
    _replace(_log.map(logged).toList(), _leechActions.toList());
  }

  @override
  FsrsState? stateOf(String cardId, DrillMode mode) =>
      _states[(cardId: cardId, mode: mode)];

  @override
  Map<ProgressKey, FsrsState> get states =>
      Map<ProgressKey, FsrsState>.unmodifiable(_states);

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
    final key = (cardId: cardId, mode: mode);
    final before = _states[key];
    final after = Fsrs.next(
      before,
      grade,
      now: now,
      rated: answerGiven == null,
      parameters: _parameters.forPair(key),
    );
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
    implyReview(_states, _skills, logged(event), parameters: _parameters);
    _log.add(event);
    // A language studied now may become another's baseline: when that
    // changes which set schedules a pair, every state is replayed with the
    // new choice, so that the states are always what the replay gives.
    final studied = _parameters.studied(skillOf(key).language, now);
    if (studied.sameAs(_parameters)) {
      _parameters = studied;
      notifyListeners();
    } else {
      _parameters = studied;
      _replace(_log.map(logged).toList(), _leechActions.toList());
    }
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
      skills: _skills,
      parameters: _parameters,
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
    List<LeechAction> leechActions, {
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
  }) async {
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
    _parameters = _parameters.merged(fitted);
    _replace(
      inTimeOrder(<LoggedReview>[..._log.map(logged), ...fresh]),
      actions,
    );
    return fresh.length;
  }

  /// Everything replaced by [events], [leechActions] and the [fitted]
  /// parameters, and the states rebuilt from them. For an import (#20).
  void replaceWith(
    List<ReviewEvent> events,
    List<LeechAction> leechActions, {
    required Map<SkillKey, FittedParameters> fitted,
  }) {
    _parameters = SkillParameters(fitted: fitted);
    _replace(inTimeOrder(events.map(logged)), actionsInTimeOrder(leechActions));
  }

  /// [reviews] and [actions] are oldest first. The languages' last studies
  /// are taken from [reviews].
  void _replace(List<LoggedReview> reviews, List<LeechAction> actions) {
    _parameters = SkillParameters(
      fitted: _parameters.fitted,
      lastStudied: _lastStudied(reviews),
    );
    final replayed = replayReviews(
      reviews,
      effects: LeechEffects(actions),
      skills: _skills,
      parameters: _parameters,
    );
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
  /// The review log, leech actions and fitted parameters as a JSONL
  /// backup (#20).
  String exportJsonl() => LogJsonl.encode(
    inTimeOrder(log.map(logged)),
    actionsInTimeOrder(leechActions),
    fitted: parameters.fitted,
  );

  /// What the leech actions add up to: which pairs are reset or set aside.
  LeechEffects get leechEffects => LeechEffects(leechActions);

  /// What the learner's rating [grade] would do to the pair, without
  /// recording anything. The rating buttons label themselves with its
  /// `intervalDays`.
  FsrsState preview(
    String cardId,
    DrillMode mode,
    int grade, {
    required DateTime now,
  }) => Fsrs.next(
    stateOf(cardId, mode),
    grade,
    now: now,
    rated: true,
    parameters: parameters.forPair((cardId: cardId, mode: mode)),
  );

  /// New pairs introduced on [day]'s calendar date.
  int newIntroducedOn(DateTime day) =>
      log.where((e) => e.wasNew && isSameDay(e.at, day)).length;

  /// Reviews given on [day]'s calendar date.
  int reviewsOn(DateTime day) => log.where((e) => isSameDay(e.at, day)).length;

  /// Whether any review was given on [day]'s calendar date.
  bool practisedOn(DateTime day) => log.any((e) => isSameDay(e.at, day));

  /// Consecutive days with a review, ending today — or yesterday, if today
  /// has none yet, so that a streak is not broken before the day is over.
  int streakAt(DateTime now) => streakIn(log, now);

  /// Distinct cards of [cardIds], a deck's, reviewed successfully at least
  /// once, in any mode and in any deck: the deck's "Learned" count.
  int learnedIn(Iterable<String> cardIds) {
    final learned = <String>{
      for (final entry in states.entries)
        if (entry.value.repetitions > 0) entry.key.cardId,
    };
    return cardIds.toSet().where(learned.contains).length;
  }

  /// Distinct cards due by the end of the calendar day after [now] and not
  /// due at [now]: "Next due: 14 cards tomorrow". Only the pairs [counts]
  /// accepts, when given.
  int dueTomorrow(DateTime now, {bool Function(ProgressKey key)? counts}) {
    final endOfTomorrow = addDays(dateOnly(now), 2);
    return <String>{
      for (final entry in states.entries)
        if (!entry.value.isDue(now) &&
            entry.value.dueAt.isBefore(endOfTomorrow) &&
            (counts?.call(entry.key) ?? true))
          entry.key.cardId,
    }.length;
  }
}

/// [ProgressQueries.streakAt] over [log], which may be part of a store's:
/// Progress counts one language's streak this way.
int streakIn(Iterable<ReviewEvent> log, DateTime now) {
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
