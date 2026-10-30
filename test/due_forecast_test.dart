// The per-day due forecast the daily reminder is planned from (#90): cards
// due by the end of each of the next seven days, a card counted once however
// many skills it is due in, overdue cards from today on, and only the pairs
// the app counts as due.

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/drill_mode.dart';

void main() {
  final now = DateTime(2026, 10, 30, 10);
  const r = DrillMode.recognition;
  const p = DrillMode.production;

  MemoryProgress learner() {
    final progress = MemoryProgress();
    void answer(String card, DrillMode mode, int daysAgo, int grade) =>
        progress.record(
          deckId: 'd',
          cardId: card,
          mode: mode,
          grade: grade,
          now: now.subtract(Duration(days: daysAgo)),
        );
    answer('a', r, 60, 3); // long overdue
    answer('b', r, 0, 3); // just answered
    answer('b', p, 90, 3); // and overdue in another skill
    answer('c', r, 0, 1); // just failed: soon
    answer('d', r, 2, 4);
    return progress;
  }

  /// The same forecast worked out the other way round, day by day.
  List<int> expected(MemoryProgress progress, List<String> cards) {
    final today = DateTime(now.year, now.month, now.day);
    return <int>[
      for (var i = 0; i < 7; i++)
        cards
            .where(
              (id) => <DrillMode>[r, p].any((mode) {
                final due = progress.stateOf(id, mode)?.dueAt;
                return due != null &&
                    due.isBefore(
                      DateTime(today.year, today.month, today.day + i + 1),
                    );
              }),
            )
            .length,
    ];
  }

  test('counts the cards due by the end of each day, today first', () {
    final progress = learner();
    final forecast = progress.dueByDay(now);
    expect(forecast, hasLength(7));
    expect(forecast, expected(progress, <String>['a', 'b', 'c', 'd']));
  });

  test('an overdue card is due today, and the list never falls', () {
    final forecast = learner().dueByDay(now);
    expect(forecast.first, greaterThanOrEqualTo(2), reason: 'a and b');
    for (var i = 1; i < forecast.length; i++) {
      expect(forecast[i], greaterThanOrEqualTo(forecast[i - 1]));
    }
  });

  test('a card due in two skills is counted once', () {
    final progress = MemoryProgress()
      ..record(
        deckId: 'd',
        cardId: 'x',
        mode: r,
        grade: 3,
        now: now.subtract(const Duration(days: 50)),
      )
      ..record(
        deckId: 'd',
        cardId: 'x',
        mode: p,
        grade: 3,
        now: now.subtract(const Duration(days: 50)),
      );
    expect(progress.dueByDay(now), everyElement(1));
  });

  test('only the pairs asked for are counted', () {
    final progress = learner();
    final all = progress.dueByDay(now);
    final none = progress.dueByDay(now, counts: (_) => false);
    final onlyA = progress.dueByDay(now, counts: (key) => key.cardId == 'a');
    expect(none, everyElement(0));
    expect(onlyA.first, 1);
    expect(onlyA.last, lessThan(all.last));
  });

  test('a learner with no reviews has nothing due on any day', () {
    expect(MemoryProgress().dueByDay(now), everyElement(0));
  });

  test('the number of days is the length of the list', () {
    expect(learner().dueByDay(now, days: 3), hasLength(3));
  });
}
