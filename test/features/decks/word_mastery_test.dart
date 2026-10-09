import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/decks/word_mastery.dart';

/// [grades] for [card], a day apart from [start], in alternating skills.
void answer(
  MemoryProgress progress,
  String card,
  List<int> grades, {
  DateTime? start,
}) {
  final from = start ?? DateTime(2026, 9, 1);
  for (final (i, grade) in grades.indexed) {
    progress.record(
      deckId: 'xx-deck',
      cardId: card,
      mode: i.isEven ? DrillMode.recognition : DrillMode.production,
      grade: grade,
      now: from.add(Duration(days: i)),
    );
  }
}

void main() {
  test('a card never answered is new', () {
    final answers = RecentAnswers(MemoryProgress().log);
    expect(answers.of('xx-0001'), (level: MasteryLevel.fresh, share: 0.0));
    expect(answers.firstPassed('xx-0001'), isNull);
  });

  test('known means right on 85% of the last ten answers, in any skill', () {
    final progress = MemoryProgress();
    // Nine right of ten: 90%.
    answer(progress, 'xx-0001', [4, 4, 4, 1, 4, 4, 4, 4, 4, 4]);
    // Eight right of ten: 80%, still learning.
    answer(progress, 'xx-0002', [4, 1, 4, 4, 1, 4, 4, 4, 4, 4]);
    final answers = RecentAnswers(progress.log);
    expect(answers.of('xx-0001').level, MasteryLevel.known);
    expect(answers.of('xx-0001').share, closeTo(0.9, 1e-9));
    expect(answers.of('xx-0002').level, MasteryLevel.learning);
    expect(answers.of('xx-0002').share, closeTo(0.8, 1e-9));
  });

  test('only the recent answers count: old misses fall out of the window', () {
    final progress = MemoryProgress();
    answer(progress, 'xx-0001', [
      1, 1, 1, 1, 1, // five misses long ago
      4, 4, 4, 4, 4, 4, 4, 4, 4, 4, // then ten right
    ]);
    final answers = RecentAnswers(progress.log);
    expect(answers.of('xx-0001'), (level: MasteryLevel.known, share: 1.0));
    // The first right answer, not the first answer.
    expect(
      answers.firstPassed('xx-0001'),
      DateTime(2026, 9, 1).add(const Duration(days: 5)),
    );
  });

  test('a rule is known over its cells\' answers together', () {
    final progress = MemoryProgress();
    answer(progress, 'xx-cell-0', [4, 4, 4, 4]);
    answer(progress, 'xx-cell-1', [1, 4], start: DateTime(2026, 9, 10));
    final answers = RecentAnswers(progress.log);
    // Five right of six.
    final rule = answers.ofAll(<String>['xx-cell-0', 'xx-cell-1']);
    expect(rule.level, MasteryLevel.learning);
    expect(rule.share, closeTo(5 / 6, 1e-9));
    // Over the last two answers only: one miss, one right.
    expect(
      answers.ofAll(<String>['xx-cell-0', 'xx-cell-1'], window: 2).share,
      closeTo(0.5, 1e-9),
    );
    expect(answers.ofAll(const <String>[]).level, MasteryLevel.fresh);
  });
}
