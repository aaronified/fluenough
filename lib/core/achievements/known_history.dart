/// When each card, and each skill of a card, was first known, replayed from
/// the review log (#322, decision 1 of the achievements mockup).
///
/// "Known" is the app's one rule (`RecentAnswers`, `leavesKnown`): a card's
/// skill is known when its last review was right and FSRS gave at least
/// `kKnownRecall` chance of recall at that moment; a card is known when every
/// skill it has been answered in is. This class replays the log oldest first
/// and notes the first moment each became true. A later lapse never takes a
/// moment back: a card counts once it has EVER been known, so an achievement
/// is never lost. The log itself is never edited (ADR-0005).
library;

import '../models/drill_mode.dart';
import '../models/review_event.dart';
import '../progress/mastery.dart' show leavesKnown, masterySkillOf;
import '../progress/recent_answers.dart' show ParametersOfReview;
import '../scheduling/fsrs.dart';

List<double> _defaultParameters(ReviewEvent event) => Fsrs.w;

/// The first moments of a language's cards, from its reviews.
class KnownHistory {
  KnownHistory._(
    this._cardKnown,
    this._pairKnown,
    this._readingPassed,
    this._passed,
  );

  /// Replays [log], oldest first, whatever the language of its cards; the
  /// caller passes one language's reviews. [parametersOf] gives the
  /// parameters that schedule a review's pair, so that this and Progress
  /// agree about a card.
  factory KnownHistory.of(
    Iterable<ReviewEvent> log, {
    ParametersOfReview parametersOf = _defaultParameters,
  }) {
    final cardKnown = <String, DateTime>{};
    final pairKnown = <String, DateTime>{};
    final readingPassed = <String, DateTime>{};
    final passed = <DrillMode, Map<String, DateTime>>{};
    // For each card, its last review in each skill (mode and script), and
    // whether that review left the skill known.
    final last = <String, Map<String, _Last>>{};
    for (final e in log.answered) {
      if (e.mode == DrillMode.reading) {
        // A passage's question is no skill of a card to know; answering it
        // right is as far as it goes.
        if (e.passed && !e.isPlaced) {
          readingPassed.putIfAbsent(e.cardId, () => e.at);
        }
        continue;
      }
      if (masterySkillOf(e.mode) == null) continue;
      if (e.passed && !e.isPlaced) {
        final byMode = passed[e.mode] ??= <String, DateTime>{};
        byMode.putIfAbsent(e.cardId, () => e.at);
      }
      final bySkill = last[e.cardId] ??= <String, _Last>{};
      final key = '${e.mode.name}|${e.script ?? ''}';
      final known = leavesKnown(e, parameters: parametersOf(e));
      bySkill[key] = _Last(e.mode, known);
      if (bySkill.values.every((l) => l.known)) {
        cardKnown.putIfAbsent(e.cardId, () => e.at);
      }
      final ofMode = bySkill.values.where((l) => l.mode == e.mode);
      if (ofMode.every((l) => l.known)) {
        pairKnown.putIfAbsent('${e.cardId}|${e.mode.name}', () => e.at);
      }
    }
    return KnownHistory._(cardKnown, pairKnown, readingPassed, passed);
  }

  final Map<String, DateTime> _cardKnown;
  final Map<String, DateTime> _pairKnown;
  final Map<String, DateTime> _readingPassed;
  final Map<DrillMode, Map<String, DateTime>> _passed;

  /// When [cardId] was first known, or, for a passage's question, first
  /// answered right; null if it never was.
  DateTime? cardKnownAt(String cardId) =>
      _cardKnown[cardId] ?? _readingPassed[cardId];

  /// When [cardId]'s skill [mode] was first known (every script variant of
  /// it known), or null.
  DateTime? pairKnownAt(String cardId, DrillMode mode) =>
      _pairKnown['$cardId|${mode.name}'];

  /// The cards first answered right in [mode], with the moment each was, in
  /// no order. A placement credit is not an answer.
  Map<String, DateTime> passedIn(DrillMode mode) =>
      _passed[mode] ?? const <String, DateTime>{};
}

class _Last {
  const _Last(this.mode, this.known);

  final DrillMode mode;
  final bool known;
}
