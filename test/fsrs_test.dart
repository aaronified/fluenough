import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';

/// One review: its rating, the hours since the one before, and the
/// stability, difficulty and interval in days that `py-fsrs` 6.3.2 gives
/// after it, with no learning steps and fuzzing off.
typedef Step = (int rating, int hours, double s, double d, int days);

/// Generated with `py-fsrs` 6.3.2:
/// `Scheduler(learning_steps=(), relearning_steps=(), enable_fuzzing=False)`.
const List<List<Step>> reference = <List<Step>>[
  <Step>[
    (3, 0, 2.3065, 2.118103970459016, 2),
    (3, 24, 7.31530074407728, 2.111214235785395, 7),
    (3, 72, 19.833473465759585, 2.1043313908464483, 20),
    (3, 200, 48.19959255862878, 2.0974554287524403, 48),
    (3, 500, 109.1400821994129, 2.0905863426205262, 109),
  ],
  <Step>[
    (1, 0, 0.212, 6.4133, 1),
    (3, 24, 1.8867876195204154, 6.402115069296838, 2),
    (1, 48, 0.505065042540485, 8.802628058192235, 1),
    (3, 24, 1.5541689995045016, 8.789053799430881, 2),
    (4, 120, 8.161246379564238, 8.369640378590466, 8),
    (2, 400, 15.792853860577507, 8.902919677846832, 16),
  ],
  <Step>[
    (4, 0, 8.2956, 1.0, 8),
    (4, 500, 111.58629207285774, 1.0, 112),
    (1, 2000, 4.174052754309081, 7.0269895692968385, 4),
    (3, 24, 6.367272729551076, 7.0151909490243805, 6),
  ],
  <Step>[
    (3, 0, 2.3065, 2.118103970459016, 2),
    (3, 1, 2.3065, 2.111214235785395, 2),
    (1, 2, 0.7750839828558984, 7.392238132342694, 1),
    (3, 30, 2.6506751734904603, 7.38007426350719, 3),
    (2, 24, 3.876382253483383, 8.24599957687359, 4),
    (3, 10, 3.876382253483383, 8.232981946593554, 4),
  ],
  <Step>[
    (2, 0, 1.2931, 5.112170705601056, 1),
    (2, 30, 3.2494117658571677, 6.7404595108297, 3),
    (2, 80, 6.728346299675288, 7.821393497998797, 7),
    (1, 300, 1.1808515340128602, 9.269135226613255, 1),
    (1, 1, 0.4146889741744458, 9.744998088165074, 1),
    (3, 25, 0.9847047143320571, 9.730481459373747, 1),
    (4, 600, 6.616206228892827, 9.625649291957284, 7),
  ],
  <Step>[
    (3, 0, 2.3065, 2.118103970459016, 2),
    (3, 72, 13.826903694354568, 2.111214235785395, 14),
    (3, 216, 44.818186773368375, 2.1043313908464483, 45),
    (3, 600, 117.94157014125328, 2.0974554287524403, 118),
    (3, 1680, 290.1852328384116, 2.0905863426205262, 290),
    (3, 4800, 700.6513628009862, 2.083724125574744, 701),
    (3, 14400, 1709.9797916391822, 2.0768687707460076, 1710),
  ],
];

void main() {
  final start = DateTime.utc(2026, 1, 5, 9);

  group('matches py-fsrs', () {
    for (final (i, steps) in reference.indexed) {
      test('sequence $i', () {
        FsrsState? state;
        var at = start;
        for (final (rating, hours, s, d, days) in steps) {
          at = at.add(Duration(hours: hours));
          state = Fsrs.review(state, Rating.values[rating - 1], now: at);
          expect(state.stability, closeTo(s, 1e-9));
          expect(state.difficulty, closeTo(d, 1e-9));
          expect(state.intervalDays, days);
          expect(state.dueAt, at.add(Duration(days: days)));
        }
      });
    }
  });

  group('grades', () {
    test('map to ratings: below 3 Again, 3 Hard, 4 and 5 Good', () {
      expect(
        [for (var g = 0; g <= 5; g++) Fsrs.ratingOf(g)],
        [
          Rating.again,
          Rating.again,
          Rating.again,
          Rating.hard,
          Rating.good,
          Rating.good,
        ],
      );
    });

    test('5 is Easy only when the learner rated it', () {
      expect(Fsrs.ratingOf(5, rated: true), Rating.easy);
      expect(Fsrs.ratingOf(4, rated: true), Rating.good);
    });

    test('outside 0-5 are refused', () {
      expect(() => Fsrs.ratingOf(6), throwsArgumentError);
      expect(() => Fsrs.next(null, -1, now: start), throwsArgumentError);
    });
  });

  group('properties', () {
    final later = start.add(const Duration(days: 10));
    final learnt = Fsrs.replay([
      (grade: 4, at: start, rated: false),
      (grade: 4, at: start.add(const Duration(days: 3)), rated: false),
    ])!;

    test('a better rating never gives a shorter interval', () {
      for (final before in <FsrsState?>[null, learnt]) {
        final intervals = [
          for (final r in Rating.values)
            Fsrs.review(before, r, now: later).intervalDays,
        ];
        for (var i = 1; i < intervals.length; i++) {
          expect(intervals[i], greaterThanOrEqualTo(intervals[i - 1]));
        }
      }
    });

    test('a miss lowers stability and counts a lapse', () {
      final missed = Fsrs.next(learnt, 1, now: later);
      expect(missed.stability, lessThan(learnt.stability));
      expect(missed.lapses, 1);
      expect(missed.repetitions, 0);
    });

    test('a miss on a pair never passed is not a lapse', () {
      final first = Fsrs.next(null, 1, now: start);
      final second = Fsrs.next(first, 1, now: later);
      expect(second.lapses, 0);
    });

    test('a first review is due the next day or later', () {
      final first = Fsrs.next(null, 1, now: start);
      expect(first.intervalDays, 1);
      expect(first.isDue(start), isFalse);
      expect(first.isDue(start.add(const Duration(days: 1))), isTrue);
    });

    test('retrievability falls with time, from 1 on the day', () {
      expect(Fsrs.retrievability(null, later), 0);
      expect(Fsrs.retrievability(learnt, learnt.lastReviewAt), 1);
      final atDue = Fsrs.retrievability(learnt, learnt.dueAt);
      expect(atDue, closeTo(Fsrs.desiredRetention, 0.02));
    });

    test('local due dates keep the hour across daylight saving', () {
      final local = DateTime(2026, 3, 28, 9);
      final state = Fsrs.next(null, 4, now: local);
      expect(state.dueAt.hour, 9);
      expect(state.dueAt.isUtc, isFalse);
    });
  });
}
