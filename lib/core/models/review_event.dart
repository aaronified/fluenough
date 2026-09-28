import '../scheduling/sm2.dart';
import 'drill_mode.dart';

/// Identifies one scheduling state: a card, in one mode, in one deck.
typedef ProgressKey = ({String deckId, String cardId, DrillMode mode});

/// One answered card: a row of the review log (docs/DESIGN.md, ADR-0005).
class ReviewEvent {
  const ReviewEvent({
    required this.at,
    required this.deckId,
    required this.cardId,
    required this.mode,
    required this.grade,
    required this.elapsed,
    required this.before,
    required this.after,
    this.answerGiven,
  });

  final DateTime at;
  final String deckId;
  final String cardId;
  final DrillMode mode;

  /// The SM-2 grade recorded, 0–5.
  final int grade;

  /// How long the learner took to answer.
  final Duration elapsed;

  /// What was typed, for a machine-graded mode. Null for recognition.
  final String? answerGiven;

  /// The state going in, or null if this was the pair's first review.
  final Sm2State? before;

  final Sm2State after;

  ProgressKey get key => (deckId: deckId, cardId: cardId, mode: mode);

  /// Whether this review introduced a new pair, which the daily cap counts.
  bool get wasNew => before == null;

  /// Whether SM-2 counts this review as remembered.
  bool get passed => grade >= Sm2.passingGrade;

  @override
  String toString() => 'ReviewEvent($deckId/$cardId ${mode.name}, $grade)';
}
