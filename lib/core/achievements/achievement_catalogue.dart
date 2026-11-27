/// The achievement catalogue as data (#322): which badges a language has, the
/// rule parameters of each, and the position each takes on the language's
/// path under the pacing rule. Pure Dart, no Flutter.
///
/// The catalogue follows the owner-approved mockup (decisions 1 to 11):
///
/// - **Levels** A1, A2 and B1, one per mark the path has.
/// - **Word counts** 100, 500, 1,000 and 2,500.
/// - **Skills** a Start and a Master for each skill the language has. Read
///   and Write Master end at the A1 mark, Hear, Speak and Gestures Master at
///   the A2 mark (decision 6). Old Firsts are folded into these (decision
///   10); there is no "first deck".
/// - **Sets** the path's chosen `achievement_sets`; none chosen, none shown.
/// - **Other** the first lesson of the language, streaks (3, 7, 30, 100,
///   365 days) and answer counts (1,000, 10,000), the last two for the app
///   as a whole (decision 3).
///
/// A path with only part of its plan written places only that part: a badge
/// whose position lies past a unit still to be written is left out, so
/// nothing promises what is not there.
library;

import 'dart:math' as math;

import '../data/course_path.dart' show Milestone;
import '../languages/language_skills.dart';
import 'achievement.dart';
import 'achievement_facts.dart';
import 'achievement_pacing.dart';

/// The app-wide badges: streaks and answer counts (decision 3).
List<AchievementDef> appAchievementDefs() => <AchievementDef>[
  for (final days in kStreakTargets) AchievementDef.streak(days),
  for (final answers in kAnswerTargets) AchievementDef.answers(answers),
];

/// The order skills are placed in, and so who yields when two land on one
/// unit: Masters, then Starts.
const List<SkillKind> _masterOrder = <SkillKind>[
  SkillKind.read,
  SkillKind.write,
  SkillKind.hear,
  SkillKind.speak,
  SkillKind.gesture,
];
const List<SkillKind> _startOrder = <SkillKind>[
  SkillKind.hear,
  SkillKind.speak,
  SkillKind.read,
  SkillKind.write,
  SkillKind.gesture,
];

/// Where a word count sits, as a share of the plan: the sizes the plan holds
/// (about 700, 900 and 1,200 words a level) reach 100 words at about 5%, 500
/// at 27%, 1,000 at 46% and 2,500 at 90%.
const Map<int, double> _wordShare = <int, double>{
  100: 0.05,
  500: 0.27,
  1000: 0.46,
  2500: 0.90,
};

/// Where a skill's Start first becomes possible, as a share of the A1 mark:
/// Hear after the first audio units, Read once the script units begin, Speak
/// when the first speaking cards appear, Write after Read.
const Map<SkillKind, double> _startShare = <SkillKind, double>{
  SkillKind.hear: 0.10,
  SkillKind.read: 0.20,
  SkillKind.speak: 0.55,
  SkillKind.write: 0.60,
  SkillKind.gesture: 0.10,
};

/// Where the A1 mark stands in a plan that does not mark it, as a share of
/// the plan: only the Starts use it.
const double _unmarkedA1 = 0.38;

/// Whether a skill's Master ends at the A1 mark (the script skills) rather
/// than the A2 mark (decision 6).
bool _endsAtA1(SkillKind kind) => kind.isScript;

/// How many lags after its mark a Master sits: Write and Speak follow Read
/// and Hear, which sit one lag after theirs.
int _lagsAfterMark(SkillKind kind) =>
    kind == SkillKind.write || kind == SkillKind.speak ? 2 : 1;

List<SkillKey> _inOrder(List<SkillKey> skills, List<SkillKind> order) {
  final found = <SkillKey>[];
  for (final kind in order) {
    found.addAll(skills.where((s) => s.kind == kind));
  }
  return found;
}

/// The badges of one language, in the order of their position on the path,
/// those not on the path (the first lesson) last.
List<AchievementDef> courseAchievementDefs(AchievementFacts facts) {
  final marks = facts.marks;
  final plan = facts.hasPlan ? facts.units : 0;
  final a1 = marks[Milestone.a1];
  final a2 = marks[Milestone.a2];
  final lag = plan == 0 ? 0 : pacingLag(plan);
  final items = <PaceItem>[];

  final levelDefs = <AchievementDef>[];
  for (final level in Milestone.values) {
    final at = marks[level];
    if (at == null) continue;
    final def = AchievementDef.level(level);
    levelDefs.add(def);
    items.add(PaceItem(def.id, at, PaceMode.fixed));
  }

  final wordDefs = <AchievementDef>[
    for (final words in kWordCountTargets) AchievementDef.words(words),
  ];
  for (final def in wordDefs) {
    final at = roundHalfUp(plan * _wordShare[def.target]!);
    items.add(PaceItem(def.id, math.max(1, at), PaceMode.anchored));
  }

  final startDefs = <AchievementDef>[];
  final masterDefs = <AchievementDef>[];
  for (final skill in _inOrder(facts.skills, _masterOrder)) {
    final end = _endsAtA1(skill.kind) ? a1 : a2;
    if (end == null) continue;
    final def = AchievementDef.skillMaster(skill);
    masterDefs.add(def);
    final at = end + _lagsAfterMark(skill.kind) * lag;
    items.add(PaceItem(def.id, at, PaceMode.anchored));
  }
  final startOf = a1 ?? roundHalfUp(plan * _unmarkedA1);
  for (final skill in _inOrder(facts.skills, _startOrder)) {
    final def = AchievementDef.skillStart(skill);
    startDefs.add(def);
    final at = roundHalfUp(_startShare[skill.kind]! * startOf);
    items.add(PaceItem(def.id, math.max(1, at), PaceMode.anchored));
  }

  // Sets: those with cards, word sets in the file's order, then grammar
  // tables in path order.
  final lastUnit = <String, int>{};
  final wordSets = <AchievementDef>[];
  final grammarSets = <AchievementDef>[];
  for (final chosen in facts.sets) {
    final holds = chosen.decks.any(
      (id) => facts.decks[id]?.cards.isNotEmpty ?? false,
    );
    if (!holds) continue;
    final last = facts.lastUnitOf(chosen.decks);
    if (last == null) continue;
    lastUnit[chosen.id] = last;
    final def = AchievementDef.deckSet(chosen.id, grammar: chosen.grammar);
    (chosen.grammar ? grammarSets : wordSets).add(def);
  }
  int byLastUnit(AchievementDef a, AchievementDef b) {
    final order = lastUnit[a.setId]!.compareTo(lastUnit[b.setId]!);
    return order != 0 ? order : a.id.compareTo(b.id);
  }

  grammarSets.sort(byLastUnit);
  final setDefs = <AchievementDef>[...wordSets, ...grammarSets];
  for (final def in setDefs) {
    final at = lastUnit[def.setId]! + lag;
    items.add(PaceItem(def.id, at, PaceMode.sliding));
  }

  // The path's timeline: where each badge sits, and which are within the
  // written part of the plan.
  final placed = plan == 0 ? const <String, int>{} : placeOnPath(plan, items);
  final defs = <AchievementDef>[];
  for (final def in <AchievementDef>[
    ...levelDefs,
    ...wordDefs,
    ...startDefs,
    ...masterDefs,
    ...setDefs,
  ]) {
    if (plan == 0) {
      defs.add(def);
      continue;
    }
    final position = placed[def.id];
    if (position == null || !facts.isBuiltTo(position)) continue;
    defs.add(_withPosition(def, position));
  }
  defs.sort(_byPosition);
  defs.add(AchievementDef.firstLesson());
  return defs;
}

int _byPosition(AchievementDef a, AchievementDef b) {
  final pa = a.position ?? 1 << 30;
  final pb = b.position ?? 1 << 30;
  if (pa != pb) return pa.compareTo(pb);
  if (a.kind != b.kind) return a.kind.index.compareTo(b.kind.index);
  return a.id.compareTo(b.id);
}

AchievementDef _withPosition(AchievementDef def, int position) {
  switch (def.kind) {
    case AchievementKind.level:
      return AchievementDef.level(def.level!, position: position);
    case AchievementKind.wordCount:
      return AchievementDef.words(def.target, position: position);
    case AchievementKind.skillStart:
      return AchievementDef.skillStart(def.skill!, position: position);
    case AchievementKind.skillMaster:
      return AchievementDef.skillMaster(def.skill!, position: position);
    case AchievementKind.deckSet:
      return AchievementDef.deckSet(
        def.setId!,
        grammar: def.grammarSet,
        position: position,
      );
    case AchievementKind.other:
      return def;
  }
}
