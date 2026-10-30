import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/scheduling/daily_budget.dart';
import 'package:fluenough/core/scheduling/daily_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 30, 9);
  DateTime at(int seconds) => start.add(Duration(seconds: seconds));

  group('the countdown', () {
    test('ticks, and pauses after 30 seconds on one screen', () {
      final clock = DailyCountdown(
        budget: const Duration(minutes: 5),
        now: start,
      );
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
      final clock = DailyCountdown(
        budget: const Duration(seconds: 40),
        now: start,
      );
      expect(clock.expiredAt(at(20)), isFalse);
      clock.screenShown(at(25));
      clock.screenShown(at(50));
      expect(clock.expiredAt(at(55)), isTrue);
      expect(clock.remainingAt(at(500)), Duration.zero);
    });
  });

  group('the whole of the time left', () {
    test('is the first round when nothing is due', () {
      for (final minutes in <int>[1, 5, 15, 40]) {
        for (final closest in <int>[0, 3, 200]) {
          final args = (
            left: Duration(minutes: minutes),
            due: 0,
            newAvailable: 12,
            closest: closest,
          );
          final whole = DailyPlanner.whole(
            left: args.left,
            due: args.due,
            newAvailable: args.newAvailable,
            closest: args.closest,
            secondsPerReview: 17.5,
            secondsPerTeach: 20,
          );
          final first = DailyPlanner.next(
            left: args.left,
            due: args.due,
            newAvailable: args.newAvailable,
            closest: args.closest,
            secondsPerReview: 17.5,
            secondsPerTeach: 20,
          );
          expect(first.toString(), whole.toString());
        }
      }
    });

    test('holds the reviews a session\'s rounds add up to', () {
      final whole = DailyPlanner.whole(
        left: const Duration(minutes: 15),
        due: 40,
        newAvailable: 15,
        closest: 0,
        secondsPerReview: 17.5,
        secondsPerTeach: 20,
      );
      final first = DailyPlanner.next(
        left: const Duration(minutes: 15),
        due: 40,
        newAvailable: 15,
        closest: 0,
        secondsPerReview: 17.5,
        secondsPerTeach: 20,
      );
      expect(first.reviews, lessThanOrEqualTo(whole.reviews));
      expect(first.newWords, lessThanOrEqualTo(whole.newWords));
      expect(whole.isEmpty, isFalse);
    });

    test('still fills the time with reviews when nothing is untaught', () {
      final whole = DailyPlanner.whole(
        left: const Duration(minutes: 5),
        due: 0,
        newAvailable: 0,
        closest: 30,
        secondsPerReview: 17.5,
        secondsPerTeach: 20,
      );
      expect(whole.newWords, 0);
      expect(whole.fillers, greaterThan(0));
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
      expect(
        heavy.reviews / heavy.newWords,
        greaterThan(light.reviews / light.newWords),
      );
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
    test('words are asked twice, not at once, with older reviews between', () {
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

  test('teach card time is kept by day, capped, and survives a restore', () {
    final settings = SettingsNotifier()
      ..addTeachTime('hi', start, const Duration(seconds: 8))
      ..addTeachTime('hi', start, const Duration(minutes: 5))
      ..addTeachTime('es', start, const Duration(seconds: 10));
    final restored = SettingsNotifier()..restore(settings.toStored());
    // The five minutes count as the most one card counts for, a minute.
    expect(
      restored.teachTimeOn(start, language: 'hi'),
      const Duration(seconds: 68),
    );
    expect(restored.teachTimeOn(start), const Duration(seconds: 78));
    expect(
      restored.teachTimeOn(start.add(const Duration(days: 1))),
      Duration.zero,
    );
    expect(restored.teachTimeTotal(language: 'hi').cards, 2);
  });

  test('clock time counts toward the day, not the teach card average', () {
    final settings = SettingsNotifier();
    for (var i = 0; i < 10; i++) {
      settings.addTeachTime('hi', start, const Duration(seconds: 20));
    }
    final before = settings.teachTimeTotal(language: 'hi');
    settings.addClockTime('hi', start, const Duration(minutes: 3));
    final after = settings.teachTimeTotal(language: 'hi');
    expect(
      DailyBudget.secondsPerTeach(after.time, after.cards),
      DailyBudget.secondsPerTeach(before.time, before.cards),
    );
    expect(after.time, before.time);
    expect(
      settings.clockTimeOn(start, language: 'hi'),
      const Duration(minutes: 3),
    );
    final restored = SettingsNotifier()..restore(settings.toStored());
    expect(restored.clockTimeOn(start), const Duration(minutes: 3));
    expect(restored.clockTimeOn(start, language: 'es'), Duration.zero);
  });
}
