import 'dart:math' as math;

import '../core/models/deck.dart';
import '../core/scheduling/daily_budget.dart';
import '../core/scheduling/daily_timer.dart';

/// One language's day on Today (#521, #485): the minutes it is given, how
/// many are spent, what is waiting, and how the app divides the rest of the
/// day between reviews and new words.
class DailyPlan {
  const DailyPlan({
    required this.language,
    required this.goalMinutes,
    required this.extraMinutes,
    required this.spent,
    required this.secondsPerCard,
    required this.due,
    required this.newAvailable,
    required this.split,
  });

  final LanguageInfo language;

  /// The minutes a day the learner chose for this language (15 at first).
  final int goalMinutes;

  /// Minutes added to today with "+ 5 min" or "Keep going", or taken off
  /// with a long press: gone tomorrow.
  final int extraMinutes;

  /// Time spent today on this language's cards, each answer capped as hours
  /// spent caps it (#227).
  final Duration spent;

  /// Seconds a card takes this learner, for turning minutes to cards.
  final double secondsPerCard;

  /// Reviews waiting, whatever today's budget.
  final int due;

  /// New words a session could teach.
  final int newAvailable;

  /// What the rest of today's budget buys. With the budget spent, what
  /// "Keep going" would buy: one step of minutes.
  final DailySplit split;

  /// The minutes today's session is for: the goal and what was added.
  int get minutes =>
      math.max(DailyBudget.minMinutes, goalMinutes + extraMinutes);

  /// Whole minutes done, rounded down and never more than [minutes], for
  /// "12 of 15 min": it reads "15 of 15" only once the budget is spent and
  /// the button reads Done for today.
  int get minutesDone => math.min(minutes, spent.inSeconds ~/ 60);

  /// How much of today's budget is spent, from 0 to 1: the ring.
  double get fraction => math.min(1.0, spent.inSeconds / (minutes * 60));

  /// Today's minutes are all spent.
  bool get budgetDone => spent.inSeconds >= minutes * 60;

  /// Some of today's minutes are spent, and some are left.
  bool get inProgress => spent > Duration.zero && !budgetDone;

  /// Nothing waits and nothing can be taught.
  bool get nothingLeft => split.cards == 0;

  /// The button reads "Done for today": the budget is spent, or there is
  /// nothing left to ask.
  bool get done => budgetDone || nothingLeft;

  /// "Keep going" is offered: the budget is spent and there is more to do.
  bool get canKeepGoing => budgetDone && !nothingLeft;

  /// About how many minutes the waiting reviews take, for the catching-up
  /// line.
  int get dueMinutes =>
      DailyBudget.minutesFor(due, secondsPerCard: secondsPerCard);

  /// How many days at the goal it takes to clear the waiting reviews.
  int get daysToCatchUp => DailyBudget.daysToCatchUp(
    due,
    DailyBudget.cardsFor(goalMinutes, secondsPerCard: secondsPerCard),
  );

  /// Reviews and new words are shown only while there is something to do.
  bool get showsSplit => !done;
}

/// One day's session while it runs (#886): its clock, and what it has asked
/// and taught so far, so that each round is planned on what is left.
class DailyRun {
  DailyRun({required this.language, required this.clock});

  final String language;
  final DailyCountdown clock;

  /// The cards asked or taught so far this session: none is asked twice
  /// as a review.
  final Set<String> asked = <String>{};

  /// How many new words the session has taught.
  int taught = 0;
}
