import '../scheduling/ask.dart';
import '../scheduling/fsrs.dart';
import 'drill_mode.dart';

/// Identifies one scheduling state: a card, in one mode. Not a deck: a card
/// listed in several decks, or learned from several native languages, has
/// one schedule (ADR-0018).
typedef ProgressKey = ({String cardId, DrillMode mode});

/// Identifies one script skill's state (#653): a card, a script skill
/// ([DrillMode.readScript] or [DrillMode.writeScript]) and the script it is
/// in, so that Hindustani's Devanagari and Perso-Arabic are each read and
/// written apart.
typedef ScriptKey = ({String cardId, DrillMode mode, String script});

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
    this.script,
    this.asked,
    this.share = 1,
  });

  final DateTime at;

  /// The deck the card was answered in. Not part of its [key].
  final String deckId;
  final String cardId;
  final DrillMode mode;

  /// The grade recorded, 0–5 ([Fsrs.ratingOf]).
  final int grade;

  /// How long the learner took to answer.
  final Duration elapsed;

  /// What was typed, for a machine-graded mode. Null for recognition.
  final String? answerGiven;

  /// The script the card was shown in, or the answer typed in (#653): one
  /// the learner learns. Null when it was shown or typed in transliteration,
  /// in a script not learned, and for reviews from before it was kept.
  final String? script;

  /// How the card was asked (ADR-0024): typed, chosen, matched or put in
  /// order. Null for reviews from before it was kept (#653).
  final Ask? asked;

  /// For a script skill's review, the share of a review it counts for
  /// (#653): 1 in a script deck, `SkillMap.implied` elsewhere. 1 for every
  /// other review.
  final double share;

  /// The state going in, or null if this was the pair's first review.
  final FsrsState? before;

  final FsrsState after;

  ProgressKey get key => (cardId: cardId, mode: mode);

  /// A script skill's review's key ([script] is set on every one).
  ScriptKey get scriptKey => (cardId: cardId, mode: mode, script: script ?? '');

  /// Whether this review introduced a new pair.
  bool get wasNew => before == null;

  /// Whether this row is a card's first view in a walkthrough (#694,
  /// ADR-0024), not an answer: graded 0 so that FSRS schedules the card at
  /// its lowest window, and skipped by every reader that counts answers
  /// (accuracy, lapses, the FSRS fit, study time, streaks, mastery).
  bool get isView => asked == Ask.teach;

  /// Whether this review counts as remembered: not Again.
  bool get passed => grade >= Fsrs.passingGrade;

  @override
  String toString() => 'ReviewEvent($deckId/$cardId ${mode.name}, $grade)';
}

/// Reading the log as what the learner answered.
extension ReviewEventAnswers on Iterable<ReviewEvent> {
  /// The reviews that are answers: those that are not a walkthrough's view of
  /// a card ([ReviewEvent.isView]).
  Iterable<ReviewEvent> get answered => where((event) => !event.isView);
}
