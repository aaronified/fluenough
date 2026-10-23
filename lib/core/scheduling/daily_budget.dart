import 'dart:math';

import 'fsrs.dart';
import 'session_queue.dart';

/// The learner's daily time budget and what it buys (#485): minutes a day
/// to cards, and how the day's cards divide between reviews and new words.
/// Pure functions, so they test with no device.
abstract final class DailyBudget {
  /// Minutes a day a language starts at (owner, 2026-10-20: "a default now
  /// (15 minutes per language)").
  static const int defaultMinutes = 15;

  /// The least and the most a learner may choose, in minutes.
  static const int minMinutes = 5;
  static const int maxMinutes = 60;

  /// The minutes offered as presets.
  static const List<int> presets = <int>[5, 10, 15, 20, 30];

  /// The step of "+ 5 min" and of quick revision's - and +, in minutes.
  static const int stepMinutes = 5;

  /// Seconds a card takes until the learner has [ownTimeAnswers] answers:
  /// the middle of the owner's 15 to 20 (2026-10-11).
  static const double defaultSecondsPerCard = 17.5;

  /// Answers before the learner's own median replaces the default.
  static const int ownTimeAnswers = 20;

  /// The most one answer counts for, as hours spent caps it (#227).
  static const double maxSecondsPerCard = 60;

  /// New words kept in a day while the backlog is small enough.
  static const int newSlots = 3;

  /// A backlog of more than this many days of budget is catching up: reviews
  /// only.
  static const int backlogDays = 3;

  /// [minutes], held between [minMinutes] and [maxMinutes].
  static int clampMinutes(int minutes) => minutes < minMinutes
      ? minMinutes
      : (minutes > maxMinutes ? maxMinutes : minutes);

  /// Seconds a card takes this learner: the median of [answerSeconds] once
  /// there are [ownTimeAnswers] of them, capped at [maxSecondsPerCard];
  /// else [defaultSecondsPerCard].
  static double secondsPerCard(List<double> answerSeconds) {
    if (answerSeconds.length < ownTimeAnswers) return defaultSecondsPerCard;
    final sorted = <double>[...answerSeconds]..sort();
    final middle = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
    final capped = median > maxSecondsPerCard ? maxSecondsPerCard : median;
    return capped <= 0 ? defaultSecondsPerCard : capped;
  }

  /// Cards [minutes] buy, at [secondsPerCard] a card, rounded down.
  static int cardsFor(
    int minutes, {
    double secondsPerCard = defaultSecondsPerCard,
  }) => (minutes * 60 / secondsPerCard).floor();

  /// About how many whole minutes [cards] take, rounded, at least 1 for any
  /// card, 0 for none.
  static int minutesFor(
    int cards, {
    double secondsPerCard = defaultSecondsPerCard,
  }) => cards <= 0 ? 0 : max(1, (cards * secondsPerCard / 60).round());

  /// The day's split (#485, owner, 2026-10-12: "what you recommended").
  ///
  /// [due] reviews are waiting and [budget] cards are left to spend today;
  /// [dayBudget] is the whole day's, which the backlog is measured against
  /// (the same as [budget] before anything is done). [newAvailable] is how
  /// many new words could be taught.
  ///
  /// - Due reviews come first.
  /// - While the backlog is within [backlogDays] days of budget,
  ///   [newSlots] are kept for new words; reviews take the rest.
  /// - Over that, reviews only, and the split says it is catching up.
  /// - When reviews take less than the budget, new words fill the rest.
  static DailySplit split({
    required int due,
    required int budget,
    int? dayBudget,
    int newAvailable = 1 << 20,
  }) {
    final spend = budget < 0 ? 0 : budget;
    final day = dayBudget ?? spend;
    final catching = due > backlogDays * day;
    if (catching) {
      return DailySplit(
        reviews: due < spend ? due : spend,
        newWords: 0,
        catchingUp: true,
      );
    }
    final kept = newSlots < spend ? newSlots : spend;
    final room = spend - kept;
    var reviews = due < room ? due : room;
    var fresh = spend - reviews;
    if (fresh > newAvailable) {
      // Nothing more to teach: reviews fill the rest.
      fresh = newAvailable < 0 ? 0 : newAvailable;
      reviews = due < spend - fresh ? due : spend - fresh;
    }
    return DailySplit(reviews: reviews, newWords: fresh, catchingUp: false);
  }

  /// [items] with the most forgotten first (#485): the lowest predicted
  /// recall at [now], then the most overdue. A new skill of a taught word,
  /// which has no state, comes last.
  static List<SessionItem> mostForgottenFirst(
    Iterable<SessionItem> items,
    DateTime now,
  ) {
    double recall(SessionItem item) =>
        item.state == null ? 2 : Fsrs.retrievability(item.state, now);
    return List<SessionItem>.of(items)..sort((a, b) {
      final byRecall = recall(a).compareTo(recall(b));
      if (byRecall != 0) return byRecall;
      return (a.state?.dueAt ?? now).compareTo(b.state?.dueAt ?? now);
    });
  }

  /// Days of [budget] cards a day it takes to clear [due] reviews: at least
  /// 1 for any, 0 for none.
  static int daysToCatchUp(int due, int budget) =>
      due <= 0 || budget <= 0 ? 0 : (due + budget - 1) ~/ budget;
}

/// One day's reviews and new words, as [DailyBudget.split] divides them.
class DailySplit {
  const DailySplit({
    required this.reviews,
    required this.newWords,
    required this.catchingUp,
  });

  final int reviews;
  final int newWords;

  /// The backlog is over [DailyBudget.backlogDays] days of budget: no new
  /// words today.
  final bool catchingUp;

  int get cards => reviews + newWords;
}
