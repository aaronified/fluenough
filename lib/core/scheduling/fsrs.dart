import 'dart:math' as math;

/// FSRS's four ratings, in the order its parameters use them.
enum Rating {
  again,
  hard,
  good,
  easy;

  /// 1 for [again] to 4 for [easy], as FSRS's formulas count them.
  int get value => index + 1;
}

/// Scheduling state for one pair: a card in one schedule.
///
/// A derived cache, like every scheduling state here. The authoritative
/// record is the append-only review log; every field can be rebuilt by
/// replaying it. See `docs/adr/0005-scheduling.md` and its successor.
class FsrsState {
  const FsrsState({
    required this.stability,
    required this.difficulty,
    required this.intervalDays,
    required this.dueAt,
    required this.lastReviewAt,
    this.repetitions = 0,
    this.lapses = 0,
  });

  /// Days until the chance of recall falls to 90%.
  final double stability;

  /// How hard the pair is for this learner, from 1 to 10.
  final double difficulty;

  /// Days from the last review to [dueAt].
  final int intervalDays;

  final DateTime dueAt;

  final DateTime lastReviewAt;

  /// Consecutive reviews that were not Again. Reset to zero by a miss.
  final int repetitions;

  /// How many times the pair was missed after a review that was not.
  /// Not used by FSRS itself; surfaced in statistics to identify leeches.
  final int lapses;

  bool isDue(DateTime now) => !dueAt.isAfter(now);

  @override
  String toString() =>
      'FsrsState(S: ${stability.toStringAsFixed(2)}, '
      'D: ${difficulty.toStringAsFixed(2)}, interval: ${intervalDays}d, '
      'due: $dueAt, reps: $repetitions, lapses: $lapses)';
}

/// FSRS-6, the Free Spaced Repetition Scheduler, with its default
/// parameters and no learning steps: every pair is in review from its first
/// answer, and a second answer the same day takes FSRS-6's same-day formula.
///
/// Every method that schedules takes an optional `parameters`, 21 values in
/// the order of [w], for a set fitted to one learner (`FsrsFit`). Left out,
/// it is [w], and the method behaves exactly as it always has.
///
/// A port of `py-fsrs` 6.3.2's scheduler, with fuzzing off so that replaying
/// the log always gives the same dates (ADR-0033). Pure: nothing
/// here imports Flutter.
abstract final class Fsrs {
  /// FSRS-6's default parameters, w0 to w20.
  static const List<double> w = <double>[
    0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, //
    1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014,
    1.8729, 0.5425, 0.0912, 0.0658, 0.1542,
  ];

  /// The chance of recall at which a pair comes due.
  static const double desiredRetention = 0.9;

  static const int maximumInterval = 36500;

  static const double minStability = 0.001;

  static const double minDifficulty = 1;

  static const double maxDifficulty = 10;

  static double _decay(List<double> w) => -w[20];

  /// Chosen so that the chance of recall is 90% when the days elapsed equal
  /// the stability.
  static double _factor(List<double> w) =>
      math.pow(0.9, 1 / _decay(w)).toDouble() - 1;

  static List<double> _checked(List<double> parameters) {
    if (parameters.length != w.length) {
      throw ArgumentError.value(
        parameters.length,
        'parameters',
        'must hold ${w.length} values, w0 to w20',
      );
    }
    return parameters;
  }

  /// Grades below this are Again: forgotten.
  static const int passingGrade = 3;

  /// The rating a logged grade (0–5) stands for: below 3 is Again, 3 Hard,
  /// 4 Good, and 5 Good too, unless [rated]: an answer typed exactly is Good
  /// (owner's decision), and Easy is only ever the learner's own rating.
  /// A rated review is one the learner graded with the rating buttons, which
  /// the log tells by its having no answer given.
  static Rating ratingOf(int grade, {bool rated = false}) {
    if (grade < 0 || grade > 5) {
      throw ArgumentError.value(grade, 'grade', 'must be between 0 and 5');
    }
    return switch (grade) {
      < passingGrade => Rating.again,
      3 => Rating.hard,
      5 when rated => Rating.easy,
      _ => Rating.good,
    };
  }

  /// Applies a review [grade] (0–5) to [state], null for a pair never
  /// reviewed, and returns the new state. [rated] as for [ratingOf].
  ///
  /// Throws [ArgumentError] if [grade] is outside 0–5, or if [parameters]
  /// does not hold 21 values.
  static FsrsState next(
    FsrsState? state,
    int grade, {
    required DateTime now,
    bool rated = false,
    List<double> parameters = w,
  }) => review(
    state,
    ratingOf(grade, rated: rated),
    now: now,
    parameters: parameters,
  );

  /// Applies [rating] to [state] at [now]. [next] for a rating chosen
  /// directly, such as Easy on the rating buttons.
  static FsrsState review(
    FsrsState? state,
    Rating rating, {
    required DateTime now,
    List<double> parameters = w,
  }) {
    final w = _checked(parameters);
    final double stability;
    final double difficulty;
    if (state == null) {
      stability = _initialStability(w, rating);
      difficulty = _clampDifficulty(_initialDifficulty(w, rating));
    } else {
      final elapsed = elapsedDays(state.lastReviewAt, now);
      stability = elapsed < 1
          ? _shortTermStability(w, state.stability, rating)
          : _nextStability(
              w,
              state.difficulty,
              state.stability,
              _retrievability(w, elapsed, state.stability),
              rating,
            );
      difficulty = _nextDifficulty(w, state.difficulty, rating);
    }
    final interval = intervalFor(stability, parameters: w);
    final missed = rating == Rating.again;
    return FsrsState(
      stability: stability,
      difficulty: difficulty,
      intervalDays: interval,
      dueAt: now.add(Duration(days: interval)),
      lastReviewAt: now,
      repetitions: missed ? 0 : (state?.repetitions ?? 0) + 1,
      lapses:
          (state?.lapses ?? 0) +
          (missed && state != null && state.repetitions > 0 ? 1 : 0),
    );
  }

  /// The chance, from 0 to 1, that [state] is recalled at [now]: 0 for a
  /// pair never reviewed.
  static double retrievability(
    FsrsState? state,
    DateTime now, {
    List<double> parameters = w,
  }) => state == null
      ? 0
      : _retrievability(
          _checked(parameters),
          elapsedDays(state.lastReviewAt, now),
          state.stability,
        );

  /// Whole days until a pair of this [stability] falls to the desired
  /// retention, from 1 to [maximumInterval].
  static int intervalFor(double stability, {List<double> parameters = w}) {
    final w = _checked(parameters);
    final days =
        (stability / _factor(w)) *
        (math.pow(desiredRetention, 1 / _decay(w)) - 1);
    return days.round().clamp(1, maximumInterval);
  }

  /// [state] after a right answer in another skill that implies this one
  /// (`SkillMap`): its stability moves [share] of the way to what a Good
  /// review at [now] would give. Its difficulty, due date and last review
  /// stay as they were, so it is never asked sooner or later because of it;
  /// only the next review of its own starts from more.
  static FsrsState implied(
    FsrsState state,
    double share, {
    required DateTime now,
    List<double> parameters = w,
  }) {
    final good = review(
      state,
      Rating.good,
      now: now,
      parameters: parameters,
    ).stability;
    if (good <= state.stability) return state;
    return FsrsState(
      stability: state.stability + share * (good - state.stability),
      difficulty: state.difficulty,
      intervalDays: state.intervalDays,
      dueAt: state.dueAt,
      lastReviewAt: state.lastReviewAt,
      repetitions: state.repetitions,
      lapses: state.lapses,
    );
  }

  /// Rebuilds a pair's state from its `(grade, time)` reviews, oldest first.
  static FsrsState? replay(
    Iterable<({int grade, DateTime at, bool rated})> reviews, {
    List<double> parameters = w,
  }) {
    FsrsState? state;
    for (final review in reviews) {
      state = next(
        state,
        review.grade,
        now: review.at,
        rated: review.rated,
        parameters: parameters,
      );
    }
    return state;
  }

  static double _retrievability(
    List<double> w,
    int elapsedDays,
    double stability,
  ) => math.pow(1 + _factor(w) * elapsedDays / stability, _decay(w)).toDouble();

  static double _initialStability(List<double> w, Rating rating) =>
      math.max(w[rating.value - 1], minStability);

  static double _initialDifficulty(List<double> w, Rating rating) =>
      w[4] - math.exp(w[5] * (rating.value - 1)) + 1;

  static double _clampDifficulty(double d) =>
      d.clamp(minDifficulty, maxDifficulty);

  static double _shortTermStability(
    List<double> w,
    double stability,
    Rating rating,
  ) {
    var increase =
        math.exp(w[17] * (rating.value - 3 + w[18])) *
        math.pow(stability, -w[19]);
    if (rating != Rating.again) increase = math.max(increase, 1);
    return math.max(stability * increase, minStability);
  }

  static double _nextDifficulty(
    List<double> w,
    double difficulty,
    Rating rating,
  ) {
    final delta = -(w[6] * (rating.value - 3));
    final damped = difficulty + (10 - difficulty) * delta / 9;
    final reverted =
        w[7] * _initialDifficulty(w, Rating.easy) + (1 - w[7]) * damped;
    return _clampDifficulty(reverted);
  }

  static double _nextStability(
    List<double> w,
    double difficulty,
    double stability,
    double retrievability,
    Rating rating,
  ) {
    final double next;
    if (rating == Rating.again) {
      final longTerm =
          w[11] *
          math.pow(difficulty, -w[12]) *
          (math.pow(stability + 1, w[13]) - 1) *
          math.exp((1 - retrievability) * w[14]);
      final shortTerm = stability / math.exp(w[17] * w[18]);
      next = math.min(longTerm, shortTerm);
    } else {
      final hardPenalty = rating == Rating.hard ? w[15] : 1;
      final easyBonus = rating == Rating.easy ? w[16] : 1;
      next =
          stability *
          (1 +
              math.exp(w[8]) *
                  (11 - difficulty) *
                  math.pow(stability, -w[9]) *
                  (math.exp((1 - retrievability) * w[10]) - 1) *
                  hardPenalty *
                  easyBonus);
    }
    return math.max(next, minStability);
  }

  /// Whole days elapsed, as `py-fsrs` counts them: the duration's days,
  /// rounded down, never below zero. The due date is whole days of 24 hours
  /// too, so a pair is never due before its interval has passed, even
  /// across a change to daylight saving time, when it falls an hour off the
  /// clock time it was answered at. Fitting counts days the same way
  /// (`FsrsFit`), so that it fits the model this scheduler runs.
  static int elapsedDays(DateTime from, DateTime to) =>
      math.max(0, to.toUtc().difference(from.toUtc()).inDays);
}
