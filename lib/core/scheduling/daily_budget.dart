import 'dart:math';

import 'daily_timer.dart';
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

  /// The step of "+ 5 min" and of the daily minutes' - and +, in minutes.
  static const int stepMinutes = 5;

  /// Seconds a card takes until the learner has [ownTimeAnswers] answers:
  /// the middle of the owner's 15 to 20 (2026-10-11).
  static const double defaultSecondsPerCard = 17.5;

  /// Seconds a teach card takes until the learner has [ownTeachCards] of
  /// them timed (#886).
  static const double defaultSecondsPerTeach = 12;

  /// Teach cards timed before the learner's own average replaces the
  /// default.
  static const int ownTeachCards = 10;

  /// Seconds a teach card takes this learner: the average of [total] over
  /// [cards] once there are [ownTeachCards], capped at [maxSecondsPerCard];
  /// else [defaultSecondsPerTeach].
  static double secondsPerTeach(Duration total, int cards) {
    if (cards < ownTeachCards) return defaultSecondsPerTeach;
    final seconds = total.inMilliseconds / 1000 / cards;
    if (seconds <= 0) return defaultSecondsPerTeach;
    return seconds > maxSecondsPerCard ? maxSecondsPerCard : seconds;
  }

  /// Answers before the learner's own median replaces the default.
  static const int ownTimeAnswers = 20;

  /// The most one answer counts for, as hours spent caps it (#227).
  static const double maxSecondsPerCard = 60;

  /// New words kept in a day while the backlog is small enough.
  static const int newSlots = 3;

  /// A backlog of more than this many days of budget is catching up: reviews
  /// only.
  static const int backlogDays = 3;

  /// Keep going (#1010): the most days a card may be pulled forward. Cards
  /// due later than this are not reviewed early, so Keep going does not
  /// review too far into the future (owner, 2026-11-04). Tunable.
  static const int keepGoingDays = 2;

  /// Keep going (#1010): a card is pulled forward only while the chance of
  /// recalling it now, by the parameters that schedule it, is at most this.
  /// A fixed 0.95, not a per-learner setting: the scheduler aims a review at
  /// 0.9, so this leaves a little room before the review is wasted, the card
  /// being still too fresh whatever its due date. Tunable.
  static const double keepGoingMaxRecall = 0.95;

  /// Keep going (#1010): new words one Keep going stretch may teach beyond
  /// the day's [DailyPlanner.newCap] already counted. Tunable.
  static const int keepGoingNewExtra = 5;

  /// The same while a day's reviews still wait beyond a day's worth, so that
  /// the busy learner is given fewer new words. Tunable.
  static const int keepGoingNewExtraBusy = 2;

  /// Whether Keep going may review [state] early at [now] (#1010): due
  /// within [keepGoingDays] days, and not so fresh that the review is
  /// wasted ([keepGoingMaxRecall]). A card already due always may.
  ///
  /// [parameters] are the ones that schedule the pair, the learner's fitted
  /// set where there is one, so that recall is judged as the scheduler does.
  static bool canPullForward(
    FsrsState state,
    DateTime now, {
    List<double> parameters = Fsrs.w,
  }) {
    if (state.isDue(now)) return true;
    return state.dueAt.difference(now) <= const Duration(days: keepGoingDays) &&
        Fsrs.retrievability(state, now, parameters: parameters) <=
            keepGoingMaxRecall;
  }

  /// The most new words the day may have taught once Keep going has
  /// started (#1010): the day's [DailyPlanner.newCap] plus an allowance for
  /// the stretch, smaller while [due] reviews wait beyond a day's worth
  /// ([dayCards]) and none while the backlog is [DailyBudget.backlogDays]
  /// days deep (catching up). The words already taught today count against
  /// it, so Keep going cannot flood the learner with new words.
  static int keepGoingNewCap({required int due, required int dayCards}) {
    final int extra;
    if (due > backlogDays * dayCards) {
      extra = 0;
    } else if (due > dayCards) {
      extra = keepGoingNewExtraBusy;
    } else {
      extra = keepGoingNewExtra;
    }
    return DailyPlanner.newCap + extra;
  }

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

  /// About how many whole minutes [seconds] take, rounded, at least 1 for
  /// any time, 0 for none.
  static int minutesOfSeconds(double seconds) =>
      seconds <= 0 ? 0 : max(1, (seconds / 60).round());

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
