import 'dart:math';

import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';

/// Simulated review logs, for the tests of fitting FSRS to a learner.

LoggedReview review(String card, DrillMode mode, DateTime at, int grade) => (
  key: (cardId: card, mode: mode),
  deckId: 'deck',
  at: at,
  grade: grade,
  elapsed: Duration.zero,
  answerGiven: 'typed',
);

/// A learner who remembers each word with chance [recall] when it comes
/// due on FSRS-6's defaults, over [cards] words of [language], each first
/// seen on a day of the first [spread] days after [start], until [until].
List<LoggedReview> simulate({
  required String language,
  required DateTime start,
  required DateTime until,
  int cards = 60,
  int spread = 20,
  double recall = 0.97,
  DrillMode mode = DrillMode.production,
  int seed = 1,
}) {
  final random = Random(seed);
  final reviews = <LoggedReview>[];
  for (var c = 0; c < cards; c++) {
    final card = '$language-${(c + 1).toString().padLeft(4, '0')}';
    var at = start.add(Duration(days: random.nextInt(spread), minutes: c));
    FsrsState? state;
    while (at.isBefore(until)) {
      final grade = state == null || random.nextDouble() < recall ? 4 : 1;
      reviews.add(review(card, mode, at, grade));
      state = Fsrs.next(state, grade, now: at, rated: false);
      at = state.dueAt;
    }
  }
  return inTimeOrder(reviews);
}
