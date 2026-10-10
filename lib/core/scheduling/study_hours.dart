import '../models/drill_mode.dart';
import '../models/review_event.dart';
import 'fsrs.dart';

/// Hours spent learning a language, and about how many are left in its
/// decks (#227, `docs/plans/hours-per-language.md`).
///
/// Only time on cards counts: each answer's `elapsed`, which runs from the
/// question showing to the answer. Pure functions over the review log and
/// the pairs' states, so they test with no device.
abstract final class StudyHours {
  /// The most one answer counts for, so a question left open adds no hours.
  static const Duration answerCap = Duration(seconds: 60);

  /// The time per answer assumed in a skill until the learner has
  /// [answersForOwnTime] answers in it: the 20 seconds Today assumes.
  static const Duration defaultAnswerTime = Duration(seconds: 20);

  /// Answers in a skill before its own median replaces [defaultAnswerTime].
  static const int answersForOwnTime = 20;

  /// The interval at which a pair counts as remembered: Anki's "mature".
  static const int rememberedDays = 21;

  /// The most reviews one pair is taken to need, so that an estimate stays
  /// finite whatever the parameters.
  static const int maxReviews = 30;

  /// The share of misses above which no more are added to the estimate.
  static const double maxMissShare = 0.5;

  /// [elapsed], capped at [answerCap]. A negative time counts as none.
  static Duration capped(Duration elapsed) => elapsed.isNegative
      ? Duration.zero
      : elapsed > answerCap
      ? answerCap
      : elapsed;

  /// The time spent on [reviews]: the sum of each answer's time, capped.
  static Duration spent(Iterable<ReviewEvent> reviews) => reviews.fold(
    Duration.zero,
    (sum, review) => sum + capped(review.elapsed),
  );

  /// The learner's time per answer in each mode of [reviews]: the median of
  /// their capped times, or [defaultAnswerTime] for a mode with fewer than
  /// [answersForOwnTime] answers. A mode with none is not in the map; ask
  /// [timeIn] for it.
  static Map<DrillMode, Duration> answerTimes(Iterable<ReviewEvent> reviews) {
    final byMode = <DrillMode, List<int>>{};
    for (final review in reviews) {
      (byMode[review.mode] ??= <int>[]).add(
        capped(review.elapsed).inMilliseconds,
      );
    }
    return <DrillMode, Duration>{
      for (final MapEntry(key: mode, value: times) in byMode.entries)
        mode: times.length < answersForOwnTime
            ? defaultAnswerTime
            : Duration(milliseconds: _median(times)),
    };
  }

  /// [mode]'s time in [times], or [defaultAnswerTime].
  static Duration timeIn(Map<DrillMode, Duration> times, DrillMode mode) =>
      times[mode] ?? defaultAnswerTime;

  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : ((sorted[middle - 1] + sorted[middle]) / 2).round();
  }

  /// The share of [reviews] missed, from 0 to [maxMissShare].
  static double missShare(Iterable<ReviewEvent> reviews) {
    var all = 0;
    var missed = 0;
    for (final review in reviews) {
      all++;
      if (!review.passed) missed++;
    }
    if (all == 0) return 0;
    final share = missed / all;
    return share > maxMissShare ? maxMissShare : share;
  }

  /// Whether a pair in [state] is remembered: an interval of
  /// [rememberedDays] or more.
  static bool isRemembered(FsrsState? state) =>
      state != null && state.intervalDays >= rememberedDays;

  /// The right answers a pair in [state] (null: never reviewed) takes to
  /// reach an interval of [rememberedDays], each given on the day it is
  /// due, simulated with FSRS and [parameters]. 0 once remembered; at most
  /// [maxReviews].
  static int rightAnswersToRemember(
    FsrsState? state, {
    List<double> parameters = Fsrs.w,
  }) {
    var current = state;
    var count = 0;
    while (!isRemembered(current) && count < maxReviews) {
      final at = current?.dueAt ?? DateTime.utc(2000);
      current = Fsrs.review(
        current,
        Rating.good,
        now: at,
        parameters: parameters,
      );
      count++;
    }
    return count;
  }

  /// The reviews a pair in [state] still needs: [rightAnswersToRemember],
  /// raised by the learner's [missShare], since each miss is a review more.
  static double reviewsToRemember(
    FsrsState? state, {
    double missShare = 0,
    List<double> parameters = Fsrs.w,
  }) {
    final right = rightAnswersToRemember(state, parameters: parameters);
    final share = missShare.clamp(0.0, maxMissShare);
    return right / (1 - share);
  }

  /// About how long the [pairs] left take: for each pair not remembered,
  /// the reviews it still needs times the learner's time per answer in its
  /// mode, from [times] ([timeIn]). [parametersOf] gives the parameters
  /// that schedule a mode; FSRS-6's defaults without it.
  static Duration left(
    Iterable<(DrillMode mode, FsrsState? state)> pairs, {
    required Map<DrillMode, Duration> times,
    double missShare = 0,
    List<double> Function(DrillMode mode)? parametersOf,
  }) {
    var ms = 0.0;
    for (final (mode, state) in pairs) {
      if (isRemembered(state)) continue;
      final reviews = reviewsToRemember(
        state,
        missShare: missShare,
        parameters: parametersOf?.call(mode) ?? Fsrs.w,
      );
      ms += reviews * timeIn(times, mode).inMilliseconds;
    }
    return Duration(milliseconds: ms.round());
  }

  /// [duration] in hours, as a fraction.
  static double hours(Duration duration) =>
      duration.inMilliseconds / Duration.millisecondsPerHour;
}
