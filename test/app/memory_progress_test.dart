import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/sm2.dart';

void main() {
  final monday = DateTime(2026, 9, 28, 19);

  ReviewEvent answer(
    MemoryProgress progress,
    String card,
    int grade, {
    DateTime? at,
    DrillMode mode = DrillMode.recognition,
    String deck = 'es-en-core-100',
  }) => progress.record(
    deckId: deck,
    cardId: card,
    mode: mode,
    grade: grade,
    now: at ?? monday,
  );

  test('recording runs Sm2.next from a fresh state', () {
    final progress = MemoryProgress();
    final event = answer(progress, 'es-0001', 4);

    expect(event.wasNew, isTrue);
    expect(event.before, isNull);
    final expected = Sm2.next(Sm2State.fresh(monday), 4, now: monday);
    expect(event.after.intervalDays, expected.intervalDays);
    expect(event.after.dueAt, expected.dueAt);
    expect(progress.stateOf('es-0001', DrillMode.recognition)!.repetitions, 1);
  });

  test('state is kept per card and mode, whichever deck lists it', () {
    final progress = MemoryProgress();
    answer(progress, 'a', 5);
    expect(progress.stateOf('a', DrillMode.production), isNull);
    expect(progress.stateOf('a', DrillMode.recognition), isNotNull);
    answer(progress, 'a', 5, mode: DrillMode.production);
    expect(progress.states, hasLength(2));
    // The same card answered in another deck is the same pair (ADR-0018).
    answer(progress, 'a', 5, deck: 'hi-en-script-vowels');
    expect(progress.states, hasLength(2));
    expect(progress.stateOf('a', DrillMode.recognition)!.repetitions, 2);
  });

  test('the log only grows, and each event carries before and after', () {
    final progress = MemoryProgress();
    final first = answer(progress, 'a', 5);
    final second = answer(
      progress,
      'a',
      1,
      at: monday.add(const Duration(days: 1)),
    );
    expect(progress.log, [first, second]);
    expect(second.before!.dueAt, first.after.dueAt);
    expect(second.passed, isFalse);
    expect(second.after.repetitions, 0);
    expect(() => progress.log.clear(), throwsUnsupportedError);
  });

  test('notifies on every record', () {
    final progress = MemoryProgress();
    var calls = 0;
    progress.addListener(() => calls++);
    answer(progress, 'a', 5);
    answer(progress, 'b', 3);
    expect(calls, 2);
  });

  test('preview says what a grade would do, and records nothing', () {
    final progress = MemoryProgress();
    answer(progress, 'a', 5);
    final state = progress.preview('a', DrillMode.recognition, 5, now: monday);
    expect(state.intervalDays, 6);
    expect(progress.log, hasLength(1));
  });

  test('counts new pairs introduced on a day, for the daily cap', () {
    final progress = MemoryProgress();
    answer(progress, 'a', 5, at: monday.subtract(const Duration(days: 1)));
    answer(progress, 'b', 5);
    answer(progress, 'b', 5, mode: DrillMode.production);
    answer(progress, 'a', 5); // a review, not new
    expect(progress.newIntroducedOn(monday), 2);
    expect(progress.reviewsOn(monday), 3);
  });

  group('streak', () {
    MemoryProgress onDays(List<int> daysAgo) {
      final progress = MemoryProgress();
      for (final d in daysAgo) {
        answer(progress, 'c$d', 5, at: monday.subtract(Duration(days: d)));
      }
      return progress;
    }

    test('counts consecutive days ending today', () {
      expect(onDays([0, 1, 2]).streakAt(monday), 3);
    });

    test('is not broken by a today with nothing in it yet', () {
      expect(onDays([1, 2, 3, 5]).streakAt(monday), 3);
    });

    test('is zero with no reviews, or none since before yesterday', () {
      expect(MemoryProgress().streakAt(monday), 0);
      expect(onDays([2, 3]).streakAt(monday), 0);
    });

    test('practisedOn looks at calendar days', () {
      final progress = onDays([1]);
      expect(progress.practisedOn(monday), isFalse);
      expect(progress.practisedOn(DateTime(2026, 9, 27, 1)), isTrue);
    });
  });

  test('learned counts distinct cards remembered at least once', () {
    final progress = MemoryProgress();
    answer(progress, 'a', 5);
    answer(progress, 'a', 5, mode: DrillMode.production);
    answer(progress, 'b', 1);
    answer(progress, 'c', 4, deck: 'hi-en-script-vowels');
    expect(progress.learnedIn(<String>['a', 'b']), 1);
    expect(progress.learnedIn(<String>['c']), 1);
    // A card is learned in every deck that lists it (ADR-0018).
    expect(progress.learnedIn(<String>['c', 'd']), 1);
  });

  test('due tomorrow counts cards whose next review is tomorrow', () {
    final progress = MemoryProgress();
    answer(progress, 'a', 1); // failed: due tomorrow
    answer(progress, 'b', 5); // new, passed: due tomorrow
    answer(progress, 'b', 5, mode: DrillMode.production); // same card
    final c = answer(progress, 'c', 5, at: DateTime(2026, 9, 20));
    answer(progress, 'c', 5, at: c.after.dueAt); // due again already
    expect(progress.dueTomorrow(monday), 2);
  });

  test('replaying a log rebuilds the same states', () {
    final original = MemoryProgress();
    answer(original, 'a', 5, at: DateTime(2026, 9, 20));
    answer(original, 'a', 4, at: DateTime(2026, 9, 21));
    answer(original, 'b', 1);
    final rebuilt = MemoryProgress.replaying(original.log);
    expect(rebuilt.log, hasLength(3));
    for (final key in original.states.keys) {
      expect(
        rebuilt.states[key]!.dueAt,
        original.states[key]!.dueAt,
        reason: '$key',
      );
    }
  });

  test('day helpers survive a daylight saving change', () {
    expect(addDays(DateTime(2026, 10, 24, 12), 1), DateTime(2026, 10, 25));
    expect(dateOnly(DateTime(2026, 9, 28, 23, 59)), DateTime(2026, 9, 28));
    expect(isSameDay(DateTime(2026, 9, 28), DateTime(2026, 9, 28, 23)), isTrue);
  });
}
