import 'dart:math' as math;

/// The day's session runs on a clock, not on a count of cards (#886, owner,
/// 2026-10-29 and 2026-10-30). Pure Dart, so it tests with no device.
///
/// [DailyCountdown] is the clock: it ticks while the learner works, and
/// pauses once one screen has been showing for [pauseAfter], the learner
/// being away. [DailyPlanner] says what the next round holds, reviews and
/// new words in the ratio the time left asks for, and [DailyPlanner.arrange]
/// puts a round's cards in order.
class DailyCountdown {
  /// A countdown of [budget] that starts at [now], on its first screen.
  DailyCountdown({required this.budget, required DateTime now})
    : _screenAt = now;

  /// How long one screen counts for: after this it is taken that the
  /// learner is away, and the clock stops (owner, 2026-10-30: "pauses if a
  /// screen is on for more than 30 seconds").
  static const Duration pauseAfter = Duration(seconds: 30);

  /// The time the session is for.
  final Duration budget;

  Duration _used = Duration.zero;
  DateTime _screenAt;

  /// The time counted by [now]: what the earlier screens took, and the
  /// first [pauseAfter] of the screen showing now.
  Duration usedAt(DateTime now) {
    final since = now.difference(_screenAt);
    if (since.isNegative) return _used;
    return _used + (since > pauseAfter ? pauseAfter : since);
  }

  /// The time left at [now], never below zero.
  Duration remainingAt(DateTime now) {
    final left = budget - usedAt(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the time is used up at [now].
  bool expiredAt(DateTime now) => remainingAt(now) == Duration.zero;

  /// Whether the clock is stopped at [now]: the screen has been showing for
  /// [pauseAfter] or more.
  bool pausedAt(DateTime now) => now.difference(_screenAt) >= pauseAfter;

  /// A new screen shows, or the learner does something, at [now]: the clock
  /// runs again.
  void screenShown(DateTime now) {
    _used = usedAt(now);
    _screenAt = now;
  }

  /// How far through the budget the clock is at [now], from 0 to 1.
  double fractionAt(DateTime now) => budget == Duration.zero
      ? 1
      : (usedAt(now).inMilliseconds / budget.inMilliseconds).clamp(0.0, 1.0);
}

/// What one round of the day's session holds.
class DailyRound {
  const DailyRound({
    required this.reviews,
    required this.newWords,
    required this.fillers,
  });

  /// No more rounds: the time is used up or nothing is left to ask.
  static const DailyRound none = DailyRound(
    reviews: 0,
    newWords: 0,
    fillers: 0,
  );

  /// Reviews that are due, the most forgotten first.
  final int reviews;

  /// New words to teach, then ask twice.
  final int newWords;

  /// Reviews of cards not due yet, the closest to due first, to fill the
  /// time when nothing is due.
  final int fillers;

  bool get isEmpty => reviews == 0 && newWords == 0 && fillers == 0;

  @override
  String toString() =>
      'DailyRound(reviews: $reviews, newWords: $newWords, fillers: $fillers)';
}

abstract final class DailyPlanner {
  /// The most new words a session teaches (owner, 2026-10-30: "capped at 15
  /// cards"; "without making them learn too much at once").
  static const int newCap = 15;

  /// The times a taught word is asked after it is taught (owner,
  /// 2026-10-30: "review them twice").
  static const int teachPasses = 2;

  /// The most due reviews one round holds when nothing is taught, so that
  /// the next round is planned on what is left.
  static const int reviewRun = 10;

  /// The least share of the time left that new words get while reviews are
  /// due and the backlog allows them: one card in six, as in five reviews
  /// to one teaching.
  static const double minNewShare = 1 / 6;

  /// What the whole of [left] holds (owner, 2026-10-30), from counts alone:
  /// Today shows it, and the session's rounds are cut from it, so the two
  /// can never disagree (#886).
  ///
  /// - While reviews are [due], the new words' share of the time left is
  ///   what the due reviews leave, never below [minNewShare] (none while
  ///   [catchingUp]).
  /// - With nothing due, as many new words are taught as the time holds, up
  ///   to what [newAvailable] allows and [newCap] less [taughtSoFar], and
  ///   the rest of the time is filled with reviews of the cards [closest]
  ///   to being due (in [DailyRound.fillers]).
  ///
  /// A new word costs [secondsPerTeach] and [teachPasses] reviews.
  static DailyRound whole({
    required Duration left,
    required int due,
    required int newAvailable,
    required int closest,
    required double secondsPerReview,
    required double secondsPerTeach,
    int taughtSoFar = 0,
    bool catchingUp = false,
  }) => _outline(
    left: left,
    due: due,
    newAvailable: newAvailable,
    closest: closest,
    secondsPerReview: secondsPerReview,
    secondsPerTeach: secondsPerTeach,
    taughtSoFar: taughtSoFar,
    catchingUp: catchingUp,
  ).total;

  /// The next round (owner, 2026-10-30): a share of [whole], so that the
  /// next is planned on what is left. See [whole] for the arguments.
  static DailyRound next({
    required Duration left,
    required int due,
    required int newAvailable,
    required int closest,
    required double secondsPerReview,
    required double secondsPerTeach,
    int taughtSoFar = 0,
    bool catchingUp = false,
  }) {
    final outline = _outline(
      left: left,
      due: due,
      newAvailable: newAvailable,
      closest: closest,
      secondsPerReview: secondsPerReview,
      secondsPerTeach: secondsPerTeach,
      taughtSoFar: taughtSoFar,
      catchingUp: catchingUp,
    );
    final total = outline.total;
    if (outline.rounds <= 1) return total;
    return DailyRound(
      reviews: (total.reviews / outline.rounds).ceil(),
      newWords: (total.newWords / outline.rounds).ceil(),
      fillers: 0,
    );
  }

  static ({DailyRound total, int rounds}) _outline({
    required Duration left,
    required int due,
    required int newAvailable,
    required int closest,
    required double secondsPerReview,
    required double secondsPerTeach,
    required int taughtSoFar,
    required bool catchingUp,
  }) {
    final seconds = left.inMilliseconds / 1000;
    if (seconds <= 0) return (total: DailyRound.none, rounds: 1);
    final review = secondsPerReview <= 0 ? 1.0 : secondsPerReview;
    final cost = secondsPerTeach + teachPasses * review;
    final room = catchingUp
        ? 0
        : math.max(0, math.min(newAvailable, newCap - taughtSoFar));

    if (due <= 0) {
      final teach = room == 0
          ? 0
          : (seconds / cost).floor().clamp(1, room).toInt();
      final spare = seconds - teach * cost;
      var fill = math.min(closest, math.max(0, (spare / review).floor()));
      if (teach == 0) fill = math.min(fill, reviewRun);
      return (
        total: DailyRound(reviews: 0, newWords: teach, fillers: fill),
        rounds: 1,
      );
    }

    final dueTime = due * review;
    final share = room == 0
        ? 0.0
        : (1 - dueTime / seconds).clamp(minNewShare, 1.0);
    final teachTotal = room == 0
        ? 0
        : math.min(room, (seconds * share / cost).floor());
    final reviewTotal = math.min(
      due,
      math.max(1, ((seconds - teachTotal * cost) / review).floor()),
    );
    final rounds = teachTotal > 0
        ? math.max(1, math.min(reviewTotal, teachTotal))
        : (reviewTotal / reviewRun).ceil();
    return (
      total: DailyRound(reviews: reviewTotal, newWords: teachTotal, fillers: 0),
      rounds: rounds,
    );
  }

  /// A round's cards in the order asked: some [older] reviews, the new
  /// words [taught], then the first pass of asking them with more [older]
  /// reviews mixed in, then the second pass with the rest, so that a word
  /// is never asked straight after it is taught, nor twice in a row (owner,
  /// 2026-10-30: "not instantly, but with older reviews mixed").
  ///
  /// With no new words, just [older].
  static List<T> arrange<T>({
    required List<T> older,
    required List<T> taught,
    required List<T> firstPass,
    required List<T> secondPass,
  }) {
    if (taught.isEmpty && firstPass.isEmpty && secondPass.isEmpty) {
      return List<T>.of(older);
    }
    final third = (older.length / 3).round();
    final before = older.take(third).toList();
    final middle = older.skip(third).take(third).toList();
    final after = older.skip(2 * third).toList();
    return <T>[
      ...before,
      ...taught,
      ...mix(middle, firstPass),
      ...mix(after, secondPass),
    ];
  }

  /// [base] with [extra] spread evenly through it, so that no two of
  /// [extra] are side by side while [base] has cards to part them.
  static List<T> mix<T>(List<T> base, List<T> extra) {
    if (base.isEmpty) return List<T>.of(extra);
    final out = <T>[];
    final parts = extra.length + 1;
    var from = 0;
    for (var i = 0; i < parts; i++) {
      final to = ((i + 1) * base.length / parts).round();
      out.addAll(base.sublist(from, to));
      from = to;
      if (i < extra.length) out.add(extra[i]);
    }
    return out;
  }
}
