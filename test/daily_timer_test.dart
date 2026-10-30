import 'package:fluenough/core/scheduling/daily_budget.dart';
import 'package:fluenough/core/scheduling/daily_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 30, 9);
  DateTime at(int seconds) => start.add(Duration(seconds: seconds));

  group('the countdown', () {
    test('ticks while the screen is new, and pauses after 30 seconds on it', () {
      final clock = DailyCountdown(budget: const Duration(minutes: 5), now: start);
      expect(clock.remainingAt(at(10)), const Duration(seconds: 290));
      expect(clock.pausedAt(at(10)), isFalse);
      // Away: a minute on one screen counts for 30 seconds only.
      expect(clock.remainingAt(at(60)), const Duration(seconds: 270));
      expect(clock.pausedAt(at(60)), isTrue);
      // The learner comes back and moves on: it runs again.
      clock.screenShown(at(60));
      expect(clock.remainingAt(at(70)), const Duration(seconds: 260));
    });

    test('is used up when the budget is spent, and never goes below zero', () {
      final clock = DailyCountdown(budget: const Duration(seconds: 40), now: start);
      expect(clock.expiredAt(at(20)), isFalse);
      clock.screenShown(at(25));
      clock.screenShown(at(50));
      expect(clock.expiredAt(at(55)), isTrue);
      expect(clock.remainingAt(at(500)), Duration.zero);
    });
  });

  group('the next round', () {
    DailyRound next({
      int minutes = 15,
      int due = 0,
      int fresh = 40,
      int closest = 100,
      int taught = 0,
      bool catchingUp = false,
    }) => DailyPlanner.next(
      left: Duration(minutes: minutes),
      due: due,
      newAvailable: fresh,
      closest: closest,
      secondsPerReview: 20,
      secondsPerTeach: 10,
      taughtSoFar: taught,
      catchingUp: catchingUp,
    );

    test('scales the reviews to the new words with what is due', () {
      final heavy = next(due: 200);
      final light = next(due: 10);
      // Many due: many reviews to each new word; few due: few.
      expect(heavy.reviews / heavy.newWords,
          greaterThan(light.reviews / light.newWords));
      expect(heavy.newWords, greaterThan(0));
      expect(heavy.fillers, 0);
    });

    test('a backlog that is being caught up has reviews only', () {
      final round = next(due: 200, catchingUp: true);
      expect(round.newWords, 0);
      expect(round.reviews, greaterThan(0));
    });

    test('with nothing due teaches at most 15, and fills the time', () {
      final round = next(minutes: 30, fresh: 40);
      expect(round.newWords, DailyPlanner.newCap);
      expect(round.fillers, greaterThan(0));
      // The cap is for the whole session.
      expect(next(minutes: 30, taught: 15).newWords, 0);
      expect(next(minutes: 30, taught: 12).newWords, 3);
    });

    test('with nothing due and nothing new, reviews the closest to due', () {
      final round = next(fresh: 0, closest: 4);
      expect(round.newWords, 0);
      expect(round.fillers, 4);
      expect(next(fresh: 0, closest: 0).isEmpty, isTrue);
    });

    test('a short time teaches fewer words than the cap', () {
      expect(next(minutes: 3).newWords, lessThan(15));
    });

    test('no time left is no round', () {
      expect(
        DailyPlanner.next(
          left: Duration.zero,
          due: 5,
          newAvailable: 5,
          closest: 5,
          secondsPerReview: 20,
          secondsPerTeach: 10,
        ).isEmpty,
        isTrue,
      );
    });
  });

  group('the order of a round', () {
    test('words are asked twice, never at once, with older reviews between', () {
      final order = DailyPlanner.arrange<String>(
        older: <String>['o1', 'o2', 'o3', 'o4', 'o5', 'o6'],
        taught: <String>['teach-a', 'teach-b'],
        firstPass: <String>['a1', 'b1'],
        secondPass: <String>['a2', 'b2'],
      );
      expect(order.toSet().length, order.length);
      expect(order.length, 12);
      for (final word in <String>['a', 'b']) {
        final teach = order.indexOf('teach-$word');
        final one = order.indexOf('${word}1');
        final two = order.indexOf('${word}2');
        expect(teach < one && one < two, isTrue);
        expect(one - teach, greaterThan(1));
        expect(two - one, greaterThan(1));
      }
    });

    test('with no new words it is the older reviews', () {
      expect(
        DailyPlanner.arrange<int>(
          older: <int>[1, 2, 3],
          taught: <int>[],
          firstPass: <int>[],
          secondPass: <int>[],
        ),
        <int>[1, 2, 3],
      );
    });
  });

  test('a teach card takes the default until the learner has timed ten', () {
    expect(
      DailyBudget.secondsPerTeach(const Duration(seconds: 90), 9),
      DailyBudget.defaultSecondsPerTeach,
    );
    expect(DailyBudget.secondsPerTeach(const Duration(seconds: 200), 10), 20);
  });
}
