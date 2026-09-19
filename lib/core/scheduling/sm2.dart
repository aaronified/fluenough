import 'dart:math' as math;

/// Scheduling state for one `(card, mode)` pair.
///
/// This is a derived cache. The authoritative record is the append-only review
/// log; every field here can be rebuilt by replaying it. See
/// `docs/adr/0005-scheduling.md`.
class Sm2State {
  const Sm2State({
    required this.repetitions,
    required this.easeFactor,
    required this.intervalDays,
    required this.dueAt,
    this.lapses = 0,
  });

  /// A card that has never been reviewed. Due immediately.
  factory Sm2State.fresh(DateTime now) => Sm2State(
        repetitions: 0,
        easeFactor: Sm2.defaultEase,
        intervalDays: 0,
        dueAt: now,
      );

  /// Consecutive successful reviews. Reset to zero by a lapse.
  final int repetitions;

  /// How easy this card is for this learner. Higher means longer intervals.
  final double easeFactor;

  /// Days until the next review, as of the last one.
  final int intervalDays;

  final DateTime dueAt;

  /// How many times this card has been forgotten after being learned.
  /// Not used by SM-2 itself; surfaced in statistics to identify leeches.
  final int lapses;

  bool isDue(DateTime now) => !dueAt.isAfter(now);

  Sm2State copyWith({
    int? repetitions,
    double? easeFactor,
    int? intervalDays,
    DateTime? dueAt,
    int? lapses,
  }) =>
      Sm2State(
        repetitions: repetitions ?? this.repetitions,
        easeFactor: easeFactor ?? this.easeFactor,
        intervalDays: intervalDays ?? this.intervalDays,
        dueAt: dueAt ?? this.dueAt,
        lapses: lapses ?? this.lapses,
      );

  @override
  String toString() => 'Sm2State(reps: $repetitions, ease: '
      '${easeFactor.toStringAsFixed(2)}, interval: ${intervalDays}d, '
      'due: $dueAt, lapses: $lapses)';
}

/// The SM-2 spaced repetition algorithm.
///
/// Chosen over FSRS for being roughly a hundred lines with no dependency, and
/// over Leitner for adapting to how hard a card is for the individual learner.
/// Because every review is logged, a better algorithm can replace this one
/// later and the entire history replayed through it.
abstract final class Sm2 {
  /// Ease is never allowed below this; SuperMemo's original floor.
  static const double minEase = 1.3;

  static const double defaultEase = 2.5;

  /// Grades below this count as a failure and reset the card.
  static const int passingGrade = 3;

  /// Interval after the first successful review, in days.
  static const int firstInterval = 1;

  /// Interval after the second successful review, in days.
  static const int secondInterval = 6;

  /// Applies a review [grade] (0–5) to [state] and returns the new state.
  ///
  /// A pure function of its arguments, which is what makes the scheduler
  /// testable without a database or a device.
  ///
  /// Throws [ArgumentError] if [grade] is outside 0–5.
  static Sm2State next(
    Sm2State state,
    int grade, {
    required DateTime now,
  }) {
    if (grade < 0 || grade > 5) {
      throw ArgumentError.value(grade, 'grade', 'must be between 0 and 5');
    }

    // The ease factor is adjusted on every review, pass or fail. A grade of 4
    // leaves it unchanged; 5 raises it, anything below 4 lowers it.
    final double adjustment =
        0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02);
    final double newEase =
        math.max(minEase, state.easeFactor + adjustment);

    if (grade < passingGrade) {
      // Forgotten. Relearn from the beginning tomorrow, but keep the ease
      // penalty so the card stays harder than it was.
      return Sm2State(
        repetitions: 0,
        easeFactor: newEase,
        intervalDays: firstInterval,
        dueAt: _addDays(now, firstInterval),
        lapses: state.lapses + (state.repetitions > 0 ? 1 : 0),
      );
    }

    final int newInterval = switch (state.repetitions) {
      0 => firstInterval,
      1 => secondInterval,
      _ => math.max(
          state.intervalDays + 1,
          (state.intervalDays * state.easeFactor).round(),
        ),
    };

    return Sm2State(
      repetitions: state.repetitions + 1,
      easeFactor: newEase,
      intervalDays: newInterval,
      dueAt: _addDays(now, newInterval),
      lapses: state.lapses,
    );
  }

  /// Rebuilds scheduling state from an ordered sequence of `(grade, time)`
  /// reviews.
  ///
  /// This is the payoff of logging every review rather than only the current
  /// interval: state is always reconstructible, so the algorithm above can be
  /// changed without discarding history.
  static Sm2State replay(
    Iterable<({int grade, DateTime at})> reviews, {
    required DateTime createdAt,
  }) {
    var state = Sm2State.fresh(createdAt);
    for (final review in reviews) {
      state = next(state, review.grade, now: review.at);
    }
    return state;
  }

  /// Adds whole days without tripping over daylight saving transitions, which
  /// [DateTime.add] does not handle for local time.
  static DateTime _addDays(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day + days, from.hour, from.minute);
}
