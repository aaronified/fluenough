// How placed words are reviewed (#761): each choice's effect on the queue,
// switching back, and that the choice is kept for the course.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/review_event.dart' show ProgressKey;
import 'package:fluenough/core/scheduling/deck_sampling.dart';
import 'package:fluenough/core/scheduling/placed_review.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';

void main() {
  group('placed words follow their course\'s choice', () {
    final placedAt = DateTime.utc(2026, 1, 5, 10);
    final later = placedAt.add(const Duration(days: 90));
    final cards = <Card>[
      for (var i = 0; i < 10; i++)
        Card(
          id: 'p$i',
          deckId: 'd',
          target: 't$i',
          native: 'n$i',
          modes: const {DrillMode.recognition},
        ),
      const Card(
        id: 'later',
        deckId: 'd',
        target: 'tl',
        native: 'nl',
        modes: {DrillMode.recognition},
      ),
    ];

    /// Ten words placed as known, and one the learner learned the day after.
    MemoryProgress progress() {
      final p = MemoryProgress();
      for (final card in cards.take(10)) {
        p.record(
          deckId: 'd',
          cardId: card.id,
          mode: DrillMode.recognition,
          grade: 5,
          now: placedAt,
        );
      }
      p.record(
        deckId: 'd',
        cardId: 'later',
        mode: DrillMode.recognition,
        grade: 4,
        now: placedAt.add(const Duration(days: 1)),
      );
      return p;
    }

    Set<ProgressKey> placedOf(MemoryProgress p) => placedPairs(
      p.log,
      placedAt: (_) => <int>{placedAt.millisecondsSinceEpoch ~/ 1000},
    );

    List<String> due(MemoryProgress p, PlacedReview choice) {
      final placed = placedOf(p);
      return SessionQueue.build(
        cards: cards,
        stateOf: (c, m) => p.stateOf(c.id, m),
        hasVoice: (_) => false,
        now: later,
        newCardLimit: 0,
        sampleKnown: true,
        placedOf: (card, mode) => placed.contains((cardId: card.id, mode: mode))
            ? (choice == PlacedReview.keepReviewing ? null : choice)
            : null,
      ).due.map((i) => i.card.id).toList();
    }

    test('Keep reviewing asks every placed word, as before', () {
      expect(due(progress(), PlacedReview.keepReviewing), hasLength(11));
    });

    test('Set in stone asks none of them, but a word learned after '
        'placement is still reviewed', () {
      expect(due(progress(), PlacedReview.setInStone), <String>['later']);
    });

    test('Spot-check asks only a small sample of them, and a miss widens '
        'it', () {
      final p = progress();
      final sample = due(p, PlacedReview.spotCheck);
      expect(sample, contains('later'));
      expect(sample.length - 1, kSampleSize);

      // One of the sampled words is missed: more of the deck comes back.
      p.record(
        deckId: 'd',
        cardId: sample.firstWhere((id) => id != 'later'),
        mode: DrillMode.recognition,
        grade: 0,
        now: later,
      );
      final more = due(p, PlacedReview.spotCheck).where((id) => id != 'later');
      expect(more.length, greaterThan(kSampleSize));
      expect(more.length, lessThan(9));
    });

    test('switching back from Set in stone returns the words to reviews', () {
      final p = progress();
      expect(due(p, PlacedReview.setInStone), hasLength(1));
      expect(due(p, PlacedReview.spotCheck), hasLength(1 + kSampleSize));
      expect(due(p, PlacedReview.keepReviewing), hasLength(11));
    });
  });

  group('the choice is a setting of each course', () {
    test('Spot-check until chosen, kept per course and across a restart', () {
      final settings = SettingsNotifier();
      expect(settings.placedReviewOf('hi'), PlacedReview.spotCheck);
      settings.setPlacedReview('hi', PlacedReview.setInStone);
      settings.addPlacedAt('hi', 1767607200);
      expect(settings.placedReviewOf('bn'), PlacedReview.spotCheck);

      final again = SettingsNotifier()..restore(settings.toStored());
      expect(again.placedReviewOf('hi'), PlacedReview.setInStone);
      expect(again.placedAtOf('hi'), <int>{1767607200});
      expect(again.placedReviewOf('bn'), PlacedReview.spotCheck);
    });
  });
}
