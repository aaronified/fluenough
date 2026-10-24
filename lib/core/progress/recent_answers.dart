import '../models/review_event.dart';
import '../scheduling/fsrs.dart';
import 'mastery.dart';

/// How well a word, a rule or a sentence is known, from the learner's answers
/// to it (docs/plans/words-rules-sentences.md, "Known means mastered"). Read
/// from the review log, never stored, so it needs no migration and survives
/// a backup.
///
/// Known is the Progress star's known, one definition everywhere (owner,
/// 2026-10-24: "Align 'known' with FSRS"): a card's skill is known when its
/// last review was right and FSRS predicted at least [kKnownRecall] recall
/// for it at that moment ([leavesKnown]); a card is known when every skill
/// it has been answered in is.

/// Where a card stands.
enum MasteryLevel {
  /// Never answered.
  fresh,

  /// Answered, but not every skill it was answered in is known yet.
  learning,

  /// Every skill it was answered in is known.
  known,
}

/// A card's or a rule's standing, and the share of its skills that are known,
/// 0–1 (0 when it has none).
typedef Mastery = ({MasteryLevel level, double share});

/// How many of a card's skills, or of a rule's cells' skills, are known, out
/// of those answered.
typedef KnownCount = ({int known, int total});

/// The parameters that schedule [event]'s pair.
typedef ParametersOfReview = List<double> Function(ReviewEvent event);

List<double> _defaultParameters(ReviewEvent event) => Fsrs.w;

/// Every card's last review in each skill in [log], for asking how well a
/// card or a group of cards is known.
class RecentAnswers {
  /// [parametersOf] gives the parameters that schedule a review's pair, so
  /// that known here and on Progress agree about a card.
  RecentAnswers(
    Iterable<ReviewEvent> log, {
    ParametersOfReview parametersOf = _defaultParameters,
  }) {
    for (final event in log) {
      (_answers[event.cardId] ??= <({DateTime at, bool passed})>[]).add((
        at: event.at,
        passed: event.passed,
      ));
      if (masterySkillOf(event.mode) == null) continue;
      final bySkill = _last[event.cardId] ??= <String, ReviewEvent>{};
      final key = '${event.mode.name}|${event.script ?? ''}';
      final old = bySkill[key];
      if (old == null || !event.at.isBefore(old.at)) bySkill[key] = event;
    }
    for (final answers in _answers.values) {
      answers.sort((a, b) => a.at.compareTo(b.at));
    }
    for (final MapEntry(key: id, value: bySkill) in _last.entries) {
      _known[id] = <bool>[
        for (final event in bySkill.values)
          leavesKnown(event, parameters: parametersOf(event)),
      ];
    }
  }

  final Map<String, List<({DateTime at, bool passed})>> _answers =
      <String, List<({DateTime at, bool passed})>>{};
  final Map<String, Map<String, ReviewEvent>> _last =
      <String, Map<String, ReviewEvent>>{};
  final Map<String, List<bool>> _known = <String, List<bool>>{};

  /// How well the card [cardId] is known.
  Mastery of(String cardId) => ofAll(<String>[cardId]);

  /// How well [cardIds] are known together: a rule, over the cells of its
  /// table. Known when every skill answered in any of them is.
  Mastery ofAll(Iterable<String> cardIds) {
    final ids = cardIds.toSet();
    if (!ids.any(_answers.containsKey)) {
      return (level: MasteryLevel.fresh, share: 0);
    }
    final (:known, :total) = countOfAll(ids);
    return (
      level: total > 0 && known == total
          ? MasteryLevel.known
          : MasteryLevel.learning,
      share: total == 0 ? 0 : known / total,
    );
  }

  /// How many of [cardId]'s skills are known, of those answered.
  KnownCount countOf(String cardId) => countOfAll(<String>[cardId]);

  /// How many skills of [cardIds] are known, of those answered.
  KnownCount countOfAll(Iterable<String> cardIds) {
    var known = 0;
    var total = 0;
    for (final id in cardIds.toSet()) {
      for (final isKnown in _known[id] ?? const <bool>[]) {
        total++;
        if (isKnown) known++;
      }
    }
    return (known: known, total: total);
  }

  /// When [cardId] was first answered, right or wrong, or null if never.
  DateTime? firstAnswered(String cardId) => _answers[cardId]?.first.at;

  /// When [cardId] was first answered right, or null if it never was.
  DateTime? firstPassed(String cardId) {
    for (final answer
        in _answers[cardId] ?? const <({DateTime at, bool passed})>[]) {
      if (answer.passed) return answer.at;
    }
    return null;
  }
}
