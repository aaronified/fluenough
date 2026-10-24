import '../models/review_event.dart';

/// How well a word, a rule or a sentence is known, from the learner's recent
/// answers to it (docs/plans/words-rules-sentences.md, "Known means
/// mastered"). Read from the review log, never stored, so it needs no
/// migration and survives a backup.

/// How many of a card's latest answers, in any skill, are counted.
const int recentAnswerCount = 10;

/// How many of those must be right for a card to count as known: 9 of the
/// last 10 (owner, 2026-10-16: "Make that 90% of 10").
const int knownRight = 9;

/// The share of recent answers that must be right: [knownRight] of
/// [recentAnswerCount].
const double knownShare = knownRight / recentAnswerCount;

/// How many of a rule's latest answers, over all its cells, are counted:
/// the same ten as a card's.
const int recentRuleAnswerCount = 10;

/// Where a card stands.
enum MasteryLevel {
  /// Never answered.
  fresh,

  /// Answered, but right on less than [knownShare] of its recent answers.
  learning,

  /// Right on at least [knownShare] of its recent answers.
  known,
}

/// A card's or a rule's standing, and the share of its recent answers that
/// were right, 0–1 (0 when it has none).
typedef Mastery = ({MasteryLevel level, double share});

/// Every card's answers in [log], oldest first, for asking how well a card
/// or a group of cards is known.
class RecentAnswers {
  RecentAnswers(Iterable<ReviewEvent> log) {
    for (final event in log) {
      (_byCard[event.cardId] ??= <({DateTime at, bool passed})>[]).add((
        at: event.at,
        passed: event.passed,
      ));
    }
    for (final answers in _byCard.values) {
      answers.sort((a, b) => a.at.compareTo(b.at));
    }
  }

  final Map<String, List<({DateTime at, bool passed})>> _byCard =
      <String, List<({DateTime at, bool passed})>>{};

  /// How well the card [cardId] is known, over its last
  /// [recentAnswerCount] answers.
  Mastery of(String cardId) => _mastery(
    _byCard[cardId] ?? const <({DateTime at, bool passed})>[],
    recentAnswerCount,
  );

  /// How well [cardIds] are known together, over their last [window]
  /// answers between them: a rule, over the cells of its table.
  Mastery ofAll(
    Iterable<String> cardIds, {
    int window = recentRuleAnswerCount,
  }) {
    final answers = <({DateTime at, bool passed})>[
      for (final id in cardIds.toSet()) ...?_byCard[id],
    ]..sort((a, b) => a.at.compareTo(b.at));
    return _mastery(answers, window);
  }

  /// How many of [cardId]'s last [recentAnswerCount] answers were right.
  int rightOf(String cardId) => _right(
    _byCard[cardId] ?? const <({DateTime at, bool passed})>[],
    recentAnswerCount,
  );

  /// How many of the last [window] answers between [cardIds] were right.
  int rightOfAll(
    Iterable<String> cardIds, {
    int window = recentRuleAnswerCount,
  }) {
    final answers = <({DateTime at, bool passed})>[
      for (final id in cardIds.toSet()) ...?_byCard[id],
    ]..sort((a, b) => a.at.compareTo(b.at));
    return _right(answers, window);
  }

  static int _right(List<({DateTime at, bool passed})> all, int window) {
    final recent = all.length > window ? all.sublist(all.length - window) : all;
    return recent.where((a) => a.passed).length;
  }

  /// When [cardId] was first answered, right or wrong, or null if never.
  DateTime? firstAnswered(String cardId) => _byCard[cardId]?.first.at;

  /// When [cardId] was first answered right, or null if it never was.
  DateTime? firstPassed(String cardId) {
    for (final answer
        in _byCard[cardId] ?? const <({DateTime at, bool passed})>[]) {
      if (answer.passed) return answer.at;
    }
    return null;
  }

  static Mastery _mastery(List<({DateTime at, bool passed})> all, int window) {
    if (all.isEmpty) return (level: MasteryLevel.fresh, share: 0);
    final recent = all.length > window ? all.sublist(all.length - window) : all;
    final share = recent.where((a) => a.passed).length / recent.length;
    return (
      level: share >= knownShare ? MasteryLevel.known : MasteryLevel.learning,
      share: share,
    );
  }
}
