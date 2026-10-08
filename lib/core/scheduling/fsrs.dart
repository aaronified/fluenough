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
/// A port of `py-fsrs` 6.3.2's scheduler, with fuzzing off so that replaying
/// the log always gives the same dates (`docs/plans/fsrs.md`). Pure: nothing
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

  static final double _decay = -w[20];

  static final double _factor = math.pow(0.9, 1 / _decay) - 1;

  /// The rating a logged grade (0–5) stands for: below 3 is Again, 3 Hard,
  /// and 4 and 5 Good. An answer typed exactly, 5, is Good rather than Easy
  /// (owner's decision): Easy is for the learner to choose.
  static Rating ratingOf(int grade) {
    if (grade < 0 || grade > 5) {
      throw ArgumentError.value(grade, 'grade', 'must be between 0 and 5');
    }
    return switch (grade) {
      < 3 => Rating.again,
      3 => Rating.hard,
      _ => Rating.good,
    };
  }

  /// Applies a review [grade] (0–5) to [state], null for a pair never
  /// reviewed, and returns the new state.
  ///
  /// Throws [ArgumentError] if [grade] is outside 0–5.
  static FsrsState next(FsrsState? state, int grade, {required DateTime now}) =>
      review(state, ratingOf(grade), now: now);

  /// Applies [rating] to [state] at [now]. [next] for a rating chosen
  /// directly, such as Easy on the rating buttons.
  static FsrsState review(
    FsrsState? state,
    Rating rating, {
    required DateTime now,
  }) {
    final double stability;
    final double difficulty;
    if (state == null) {
      stability = _initialStability(rating);
      difficulty = _clampDifficulty(_initialDifficulty(rating));
    } else {
      final elapsed = _elapsedDays(state.lastReviewAt, now);
      stability = elapsed < 1
          ? _shortTermStability(state.stability, rating)
          : _nextStability(
              state.difficulty,
              state.stability,
              _retrievability(elapsed, state.stability),
              rating,
            );
      difficulty = _nextDifficulty(state.difficulty, rating);
    }
    final interval = intervalFor(stability);
    final missed = rating == Rating.again;
    return FsrsState(
      stability: stability,
      difficulty: difficulty,
      intervalDays: interval,
      dueAt: _addDays(now, interval),
      lastReviewAt: now,
      repetitions: missed ? 0 : (state?.repetitions ?? 0) + 1,
      lapses:
          (state?.lapses ?? 0) +
          (missed && state != null && state.repetitions > 0 ? 1 : 0),
    );
  }

  /// The chance, from 0 to 1, that [state] is recalled at [now]: 0 for a
  /// pair never reviewed.
  static double retrievability(FsrsState? state, DateTime now) => state == null
      ? 0
      : _retrievability(_elapsedDays(state.lastReviewAt, now), state.stability);

  /// Whole days until a pair of this [stability] falls to the desired
  /// retention, from 1 to [maximumInterval].
  static int intervalFor(double stability) {
    final days =
        (stability / _factor) * (math.pow(desiredRetention, 1 / _decay) - 1);
    return days.round().clamp(1, maximumInterval);
  }

  /// Rebuilds a pair's state from its `(grade, time)` reviews, oldest first.
  static FsrsState? replay(Iterable<({int grade, DateTime at})> reviews) {
    FsrsState? state;
    for (final review in reviews) {
      state = next(state, review.grade, now: review.at);
    }
    return state;
  }

  static double _retrievability(int elapsedDays, double stability) =>
      math.pow(1 + _factor * elapsedDays / stability, _decay).toDouble();

  static double _initialStability(Rating rating) =>
      math.max(w[rating.value - 1], minStability);

  static double _initialDifficulty(Rating rating) =>
      w[4] - math.exp(w[5] * (rating.value - 1)) + 1;

  static double _clampDifficulty(double d) =>
      d.clamp(minDifficulty, maxDifficulty);

  static double _shortTermStability(double stability, Rating rating) {
    var increase =
        math.exp(w[17] * (rating.value - 3 + w[18])) *
        math.pow(stability, -w[19]);
    if (rating != Rating.again) increase = math.max(increase, 1);
    return math.max(stability * increase, minStability);
  }

  static double _nextDifficulty(double difficulty, Rating rating) {
    final delta = -(w[6] * (rating.value - 3));
    final damped = difficulty + (10 - difficulty) * delta / 9;
    final reverted =
        w[7] * _initialDifficulty(Rating.easy) + (1 - w[7]) * damped;
    return _clampDifficulty(reverted);
  }

  static double _nextStability(
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
  /// rounded down, never below zero.
  static int _elapsedDays(DateTime from, DateTime to) =>
      math.max(0, to.toUtc().difference(from.toUtc()).inDays);

  /// Adds whole days without tripping over daylight saving transitions, which
  /// [DateTime.add] does not handle for local time.
  static DateTime _addDays(DateTime from, int days) =>
      (from.isUtc ? DateTime.utc : DateTime.new)(
        from.year,
        from.month,
        from.day + days,
        from.hour,
        from.minute,
        from.second,
        from.millisecond,
      );
}
