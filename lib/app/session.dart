import '../core/scheduling/sm2.dart';
import 'skill.dart';

/// What a drill session should cover. Passed to the drill route, which asks
/// `AppState.buildSession` for the matching queue.
class DrillRequest {
  const DrillRequest({
    this.deckIds,
    this.skill,
    this.tags = const <String>{},
    this.newOnly = false,
    this.newLimit,
    this.numbers = false,
  });

  /// Today's review: every deck the current profile learns, in every skill
  /// the learner has switched on. What "Start review" runs.
  const DrillRequest.today() : this();

  /// One deck: "Review all due", or with [skill] "Practise one skill", or
  /// with [tags] "Only these tags".
  DrillRequest.deck(
    String deckId, {
    Skill? skill,
    Set<String> tags = const <String>{},
  }) : this(deckIds: <String>{deckId}, skill: skill, tags: tags);

  /// Only new pairs, at most [count]: the summary's "Learn 5 new cards".
  const DrillRequest.learnNew(int count) : this(newOnly: true, newLimit: count);

  /// Number practice in the language of [deckId], a number deck: generated
  /// numbers, drilled and not recorded (#54, ADR-0011).
  DrillRequest.numbers(String deckId)
    : this(deckIds: <String>{deckId}, numbers: true);

  /// The decks to draw from, or null for every deck the current profile
  /// learns.
  final Set<String>? deckIds;

  /// One skill only, or null for every skill the learner has switched on.
  final Skill? skill;

  /// Only cards carrying at least one of these tags; empty means every card.
  final Set<String> tags;

  /// Leave out due reviews and drill only new pairs.
  final bool newOnly;

  /// At most this many new pairs, within what the daily cap still allows.
  final int? newLimit;

  /// Generated numbers instead of the decks' cards; nothing is recorded.
  final bool numbers;

  @override
  String toString() =>
      'DrillRequest(decks: ${deckIds ?? 'all'}, skill: ${skill?.name}, '
      'tags: $tags, newOnly: $newOnly, newLimit: $newLimit, '
      'numbers: $numbers)';
}

/// One answer in a finished session, for the summary.
class SessionAnswer {
  const SessionAnswer({required this.skill, required this.grade});

  final Skill skill;

  /// The SM-2 grade recorded, 0–5. Minimal pairs, which the scheduler does
  /// not know yet, use the same scale.
  final int grade;

  /// Whether the answer counts as correct in the score: the same line SM-2
  /// draws, so "I knew it" on a near miss counts and "Again" does not.
  bool get correct => grade >= Sm2.passingGrade;
}

/// A skill's line in the summary: how many of its answers were correct.
typedef SkillScore = ({Skill skill, int correct, int total});

/// A finished session, handed from the drill to the summary.
///
/// The answers themselves were already recorded, one at a time, as they were
/// given; this is only what the summary shows.
class SessionResult {
  SessionResult({
    required List<SessionAnswer> answers,
    required this.startedAt,
    required this.endedAt,
  }) : answers = List<SessionAnswer>.unmodifiable(answers);

  final List<SessionAnswer> answers;
  final DateTime startedAt;
  final DateTime endedAt;

  int get total => answers.length;

  int get correct => answers.where((a) => a.correct).length;

  /// Correct answers as a fraction, 0–1, or 0 for an empty session.
  double get accuracy => total == 0 ? 0 : correct / total;

  Duration get elapsed => endedAt.difference(startedAt);

  /// Whole minutes spent, rounded, and at least 1 for any session.
  int get minutes => total == 0
      ? 0
      : (elapsed.inSeconds / 60).round().clamp(1, 1 << 30).toInt();

  /// One score per skill drilled, in [Skill] order; skills not drilled are
  /// left out.
  List<SkillScore> get bySkill => <SkillScore>[
    for (final skill in Skill.values)
      if (answers.any((a) => a.skill == skill))
        (
          skill: skill,
          correct: answers.where((a) => a.skill == skill && a.correct).length,
          total: answers.where((a) => a.skill == skill).length,
        ),
  ];
}
