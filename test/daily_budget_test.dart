// The daily budget (#485): minutes to cards, and the day's split of reviews
// and new words, as the issue's worked example gives them.
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/daily_budget.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('minutes to cards', () {
    test('5 minutes at 17.5 seconds a card is 17 cards, 15 minutes 51', () {
      expect(DailyBudget.cardsFor(5), 17);
      expect(DailyBudget.cardsFor(15), 51);
    });

    test('the learner\'s own median replaces 17.5 seconds after 20 answers, '
        'capped at 60', () {
      expect(
        DailyBudget.secondsPerCard(List<double>.filled(19, 30)),
        DailyBudget.defaultSecondsPerCard,
      );
      expect(DailyBudget.secondsPerCard(List<double>.filled(20, 30)), 30);
      expect(DailyBudget.secondsPerCard(List<double>.filled(20, 200)), 60);
      expect(DailyBudget.cardsFor(10, secondsPerCard: 30), 20);
    });
  });

  group('the split of a 5 minute day, 17 cards', () {
    DailySplit day(int due) => DailyBudget.split(due: due, budget: 17);

    test('10 due: 10 reviews and 7 new', () {
      final split = day(10);
      expect((split.reviews, split.newWords, split.catchingUp), (10, 7, false));
    });

    test('30 due, within 3 days of budget (51): 14 reviews and 3 new', () {
      final split = day(30);
      expect((split.reviews, split.newWords, split.catchingUp), (14, 3, false));
    });

    test('80 due, over 51: 17 reviews, no new, and it is catching up', () {
      final split = day(80);
      expect((split.reviews, split.newWords, split.catchingUp), (17, 0, true));
    });

    test('with no new word left to teach, reviews fill the day', () {
      final split = DailyBudget.split(due: 30, budget: 17, newAvailable: 0);
      expect((split.reviews, split.newWords), (17, 0));
    });
  });

  test('what is left of a part-done day is split against the whole day\'s '
      'backlog line', () {
    // 8 of 17 cards left, 40 due: over 3 x 17 would be 51, so not catching up.
    final split = DailyBudget.split(due: 40, budget: 8, dayBudget: 17);
    expect(split.catchingUp, isFalse);
    expect(split.newWords, 3);
    expect(split.reviews, 5);
  });

  test('days to catch up: 80 reviews at 17 a day take 5', () {
    expect(DailyBudget.daysToCatchUp(80, 17), 5);
    expect(DailyBudget.daysToCatchUp(0, 17), 0);
  });

  test('reviews come most forgotten first: lowest recall, then most '
      'overdue', () {
    final now = DateTime(2026, 10, 23, 9);
    SessionItem due(String id, int reviewedDaysAgo, double stability) =>
        SessionItem(
          card: Card(
            id: id,
            deckId: 'd',
            target: id,
            native: id,
            modes: const {DrillMode.recognition},
          ),
          mode: DrillMode.recognition,
          state: FsrsState(
            stability: stability,
            difficulty: 5,
            intervalDays: 10,
            dueAt: now.subtract(const Duration(days: 1)),
            lastReviewAt: now.subtract(Duration(days: reviewedDaysAgo)),
            repetitions: 3,
          ),
        );
    final ranked = DailyBudget.mostForgottenFirst(<SessionItem>[
      due('strong', 12, 30),
      due('weak', 12, 5),
      due('middling', 12, 10),
    ], now);
    expect(ranked.map((i) => i.card.id), <String>[
      'weak',
      'middling',
      'strong',
    ]);
    // A taught word's new skill has no state and comes last.
    final fresh = SessionItem(
      card: ranked.first.card,
      mode: DrillMode.production,
      state: null,
    );
    expect(
      DailyBudget.mostForgottenFirst(<SessionItem>[fresh, ...ranked], now).last,
      fresh,
    );
  });
}
