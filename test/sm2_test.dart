import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/scheduling/sm2.dart';

void main() {
  final now = DateTime(2026, 1, 1, 9);

  group('Sm2.next', () {
    test('a fresh card is due immediately', () {
      final state = Sm2State.fresh(now);
      expect(state.isDue(now), isTrue);
      expect(state.repetitions, 0);
      expect(state.easeFactor, Sm2.defaultEase);
    });

    test('follows the 1 then 6 day ladder on perfect recall', () {
      var state = Sm2State.fresh(now);

      state = Sm2.next(state, 5, now: now);
      expect(state.intervalDays, 1);
      expect(state.repetitions, 1);

      state = Sm2.next(state, 5, now: now);
      expect(state.intervalDays, 6);
      expect(state.repetitions, 2);

      // Third review multiplies by the ease factor as it stood going in.
      state = Sm2.next(state, 5, now: now);
      expect(state.intervalDays, 16);
      expect(state.repetitions, 3);
    });

    test('grade 4 leaves the ease factor untouched', () {
      final state = Sm2.next(Sm2State.fresh(now), 4, now: now);
      expect(state.easeFactor, closeTo(Sm2.defaultEase, 1e-9));
    });

    test('grade 5 raises and grade 3 lowers the ease factor', () {
      expect(
        Sm2.next(Sm2State.fresh(now), 5, now: now).easeFactor,
        closeTo(2.6, 1e-9),
      );
      expect(
        Sm2.next(Sm2State.fresh(now), 3, now: now).easeFactor,
        closeTo(2.36, 1e-9),
      );
    });

    test('a failed review resets the card to a one day interval', () {
      var state = Sm2State.fresh(now);
      for (var i = 0; i < 4; i++) {
        state = Sm2.next(state, 5, now: now);
      }
      expect(state.intervalDays, greaterThan(6));

      final lapsed = Sm2.next(state, 1, now: now);
      expect(lapsed.repetitions, 0);
      expect(lapsed.intervalDays, 1);
      expect(lapsed.lapses, 1);
      // The ease penalty survives the reset, so the card stays harder.
      expect(lapsed.easeFactor, lessThan(state.easeFactor));
    });

    test('failing a card that was never learned is not counted as a lapse', () {
      final state = Sm2.next(Sm2State.fresh(now), 0, now: now);
      expect(state.lapses, 0);
    });

    test('the ease factor never falls below the floor', () {
      var state = Sm2State.fresh(now);
      for (var i = 0; i < 20; i++) {
        state = Sm2.next(state, 0, now: now);
      }
      expect(state.easeFactor, Sm2.minEase);
    });

    test('intervals always advance, even at minimum ease', () {
      final state = Sm2State(
        repetitions: 5,
        easeFactor: Sm2.minEase,
        intervalDays: 1,
        dueAt: now,
      );
      final next = Sm2.next(state, 3, now: now);
      expect(next.intervalDays, greaterThan(state.intervalDays));
    });

    test('rejects grades outside 0 to 5', () {
      final state = Sm2State.fresh(now);
      expect(() => Sm2.next(state, -1, now: now), throwsArgumentError);
      expect(() => Sm2.next(state, 6, now: now), throwsArgumentError);
    });

    test('dueAt advances by the new interval', () {
      final state = Sm2.next(Sm2State.fresh(now), 5, now: now);
      expect(state.dueAt.difference(now).inDays, 1);
      expect(state.isDue(now), isFalse);
    });
  });

  group('Sm2.replay', () {
    test(
      'reproduces the state reached by stepping through the same reviews',
      () {
        final grades = <int>[5, 4, 3, 5, 1, 4, 5];

        var stepped = Sm2State.fresh(now);
        final reviews = <({int grade, DateTime at})>[];
        for (var i = 0; i < grades.length; i++) {
          final at = now.add(Duration(days: i));
          stepped = Sm2.next(stepped, grades[i], now: at);
          reviews.add((grade: grades[i], at: at));
        }

        final replayed = Sm2.replay(reviews, createdAt: now);

        expect(replayed.repetitions, stepped.repetitions);
        expect(replayed.intervalDays, stepped.intervalDays);
        expect(replayed.easeFactor, closeTo(stepped.easeFactor, 1e-9));
        expect(replayed.lapses, stepped.lapses);
      },
    );

    test('an empty history replays to a fresh card', () {
      final replayed = Sm2.replay(
        const <({int grade, DateTime at})>[],
        createdAt: now,
      );
      expect(replayed.repetitions, 0);
      expect(replayed.easeFactor, Sm2.defaultEase);
    });
  });
}
