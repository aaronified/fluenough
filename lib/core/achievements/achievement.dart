/// The achievements (#322, plan #223): badges that are rules over the review
/// log, never stored. This file holds the data: the definitions the
/// catalogue lists and the results the evaluator returns. Pure Dart, no
/// Flutter.
library;

import 'dart:math' as math;

import '../data/course_path.dart' show Milestone;
import '../languages/language_skills.dart';

/// The categories of the Progress grid, as the approved mockup draws them.
enum AchievementKind {
  /// A1, A2 and B1, bronze, silver and gold.
  level,

  /// 100, 500, 1,000 and 2,500 words known.
  wordCount,

  /// The first real step of a skill.
  skillStart,

  /// A skill's high, defined bar.
  skillMaster,

  /// A chosen set of the path (a word set or a grammar table) mastered.
  deckSet,

  /// First lesson, streaks and answer counts: not on the path.
  other,
}

/// The achievements that belong to no skill, set or level.
enum AchievementOther {
  /// The first lesson of a language.
  firstLesson,

  /// Days in a row, for the app as a whole (decision 3).
  streak,

  /// Answers in all.
  answers,
}

/// Where one achievement stands.
enum AchievementStatus { locked, inProgress, earned }

/// The word counts of the Levels tab.
const List<int> kWordCountTargets = <int>[100, 500, 1000, 2500];

/// The streaks, in days in a row (decision 2).
const List<int> kStreakTargets = <int>[3, 7, 30, 100, 365];

/// The answer counts (decision 2).
const List<int> kAnswerTargets = <int>[1000, 10000];

/// Letters a Read or Write Start asks for.
const int kLettersForStart = 5;

/// Audio cards a Hear Start asks to be answered, and signs a Gestures Start
/// asks to be recognised and made.
const int kCardsForStart = 10;

/// One achievement of the catalogue: what earns it, and where it sits on the
/// path.
class AchievementDef {
  const AchievementDef._({
    required this.id,
    required this.kind,
    this.position,
    this.level,
    this.target = 0,
    this.skill,
    this.setId,
    this.grammarSet = false,
    this.other,
  });

  /// A level badge, earned when every card up to its mark has been known.
  factory AchievementDef.forLevel(Milestone level, {int? position}) =>
      AchievementDef._(
        id: 'level-${level.name}',
        kind: AchievementKind.level,
        position: position,
        level: level,
      );

  /// A word-count badge: [words] distinct words known.
  factory AchievementDef.words(int words, {int? position}) => AchievementDef._(
    id: 'words-$words',
    kind: AchievementKind.wordCount,
    position: position,
    target: words,
  );

  /// The Start of [skill].
  factory AchievementDef.skillStart(SkillKey skill, {int? position}) =>
      AchievementDef._(
        id: 'skill-${_skillSlug(skill)}-start',
        kind: AchievementKind.skillStart,
        position: position,
        skill: skill,
      );

  /// The Master of [skill].
  factory AchievementDef.skillMaster(SkillKey skill, {int? position}) =>
      AchievementDef._(
        id: 'skill-${_skillSlug(skill)}-master',
        kind: AchievementKind.skillMaster,
        position: position,
        skill: skill,
      );

  /// The set [setId], a grammar table when [grammar].
  factory AchievementDef.deckSet(
    String setId, {
    required bool grammar,
    int? position,
  }) => AchievementDef._(
    id: 'set-$setId',
    kind: AchievementKind.deckSet,
    position: position,
    setId: setId,
    grammarSet: grammar,
  );

  /// The first lesson of the language.
  factory AchievementDef.firstLesson() => const AchievementDef._(
    id: 'other-first-lesson',
    kind: AchievementKind.other,
    target: 1,
    other: AchievementOther.firstLesson,
  );

  /// A streak of [days] in a row.
  factory AchievementDef.streak(int days) => AchievementDef._(
    id: 'other-streak-$days',
    kind: AchievementKind.other,
    target: days,
    other: AchievementOther.streak,
  );

  /// [answers] answers in all.
  factory AchievementDef.answers(int answers) => AchievementDef._(
    id: 'other-answers-$answers',
    kind: AchievementKind.other,
    target: answers,
    other: AchievementOther.answers,
  );

  /// Permanent: `level-a1`, `words-500`, `skill-hear-start`,
  /// `skill-read-devanagari-master`, `set-pronouns`, `other-streak-7`.
  final String id;

  final AchievementKind kind;

  /// The unit number (1 is the first unit) the pacing rule gives it on the
  /// language's path, or null for one not on the path (the Other category)
  /// and for a course whose path has no B1 plan.
  final int? position;

  /// A level's milestone.
  final Milestone? level;

  /// The count a word, streak, answers or first-lesson badge asks for.
  final int target;

  /// A skill badge's skill.
  final SkillKey? skill;

  /// A set badge's set, by the id the path file gives it.
  final String? setId;

  /// Whether a set badge is a grammar table.
  final bool grammarSet;

  /// What an Other badge is.
  final AchievementOther? other;

  /// Whether the badge belongs to the app as a whole, not to one language:
  /// streaks and answer counts (decision 3).
  bool get isAppWide =>
      other == AchievementOther.streak || other == AchievementOther.answers;

  @override
  String toString() => 'AchievementDef($id)';
}

String _skillSlug(SkillKey skill) => skill.id.replaceAll(':', '-');

/// One achievement and where it stands.
class AchievementResult {
  const AchievementResult({
    required this.def,
    required this.status,
    required this.have,
    required this.need,
    this.earnedAt,
    this.earnable = true,
  });

  final AchievementDef def;
  final AchievementStatus status;

  /// How far the rule has got: cards known, words known, days, answers.
  final int have;

  /// What the rule asks for: [have] reaches it when earned.
  final int need;

  /// The first time the rule was met, from the log: a past review is
  /// celebrated once, at that date. Null unless [status] is
  /// [AchievementStatus.earned].
  final DateTime? earnedAt;

  /// False for a skill the learner marked Leave (decision 11): shown dimmed,
  /// never earned.
  final bool earnable;

  /// [have] over [need], 0 to 1.
  double get fraction => need <= 0 ? 0 : math.min(1.0, have / need);

  bool get isEarned => status == AchievementStatus.earned;
}

/// Every achievement of one language and the app, evaluated.
class AchievementReport {
  AchievementReport(List<AchievementResult> results)
    : results = List<AchievementResult>.unmodifiable(results),
      _byId = <String, AchievementResult>{
        for (final r in results) r.def.id: r,
      };

  /// In the catalogue's order: by position on the path, then the others.
  final List<AchievementResult> results;

  final Map<String, AchievementResult> _byId;

  /// The result of the badge [id], or null if the catalogue has none.
  AchievementResult? operator [](String id) => _byId[id];

  /// The earned badges, earliest first.
  List<AchievementResult> get earned =>
      results.where((r) => r.isEarned).toList()..sort(
        (a, b) => a.earnedAt!.compareTo(b.earnedAt!) != 0
            ? a.earnedAt!.compareTo(b.earnedAt!)
            : a.def.id.compareTo(b.def.id),
      );

  /// The results of one category.
  List<AchievementResult> ofKind(AchievementKind kind) => <AchievementResult>[
    for (final r in results)
      if (r.def.kind == kind) r,
  ];

  /// The ids and dates of the earned badges: what a later evaluation may be
  /// given as `earnedBefore`.
  Map<String, DateTime> get earnedDates => <String, DateTime>{
    for (final r in results)
      if (r.isEarned) r.def.id: r.earnedAt!,
  };
}
