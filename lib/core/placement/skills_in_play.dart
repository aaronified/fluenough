import '../languages/language_skills.dart';
import 'placement_questions.dart';

// Which of the skills of a run a learner's Languages-page skills mean
// (wiki/Plan-Placement-V2.md, section 1: "A run tests only the skills the
// learner marks as known").

/// The placement skills for the Languages-page skills [keys]: Speak is Say,
/// Hear is Hear, Read and Write are Read and Write; the Read of a script the
/// language has of its own ([scripts], in path order, at most two) is also
/// that script's skill.
Set<PlacementSkill> placementSkillsOf(
  Iterable<SkillKey> keys, {
  List<String> scripts = const <String>[],
}) {
  final out = <PlacementSkill>{};
  for (final key in keys) {
    switch (key.kind) {
      case SkillKind.speak:
        out.add(PlacementSkill.say);
      case SkillKind.hear:
        out.add(PlacementSkill.hear);
      case SkillKind.write:
        out.add(PlacementSkill.write);
      case SkillKind.read:
        out.add(PlacementSkill.read);
        final at = scripts.indexOf(key.script ?? '');
        if (at == 0) out.add(PlacementSkill.script);
        if (at == 1) out.add(PlacementSkill.secondScript);
      case SkillKind.gesture:
        break;
    }
  }
  return out;
}

/// The skills one tap of Find my level checks, and what the tap is called.
class FindLevelSkills {
  const FindLevelSkills({required this.skills, required this.verifying});

  /// The skills the run asks about; empty when there is nothing to check.
  final Set<PlacementSkill> skills;

  /// True for "Verify what you know" (the skills marked Know that are not
  /// Verified yet), false for "Fit my level" (the skills marked Learn, once
  /// every known one is Verified; owner, 2026-11-05: "Let it show verify
  /// knowledge first for known parts. And then after that or if all the
  /// known parts are verified, change it to fit my level").
  final bool verifying;
}

/// The skills to check for a language whose skills are [states] (the state
/// of each key of [shape]), given the skills already [verified] (by name).
/// A run never changes a state: Know and Learn are only read here.
FindLevelSkills selectFindLevelSkills(
  SkillState Function(SkillKey key) states,
  List<SkillKey> shape, {
  required Set<String> verified,
  List<String> scripts = const <String>[],
}) {
  Set<PlacementSkill> skillsIn(SkillState state) =>
      placementSkillsOf(<SkillKey>[
        for (final key in shape)
          if (states(key) == state) key,
      ], scripts: scripts);
  final known = skillsIn(SkillState.know);
  final unverified = <PlacementSkill>{
    for (final skill in known)
      if (!verified.contains(skill.name)) skill,
  };
  if (unverified.isNotEmpty) {
    return FindLevelSkills(skills: unverified, verifying: true);
  }
  final learning = skillsIn(SkillState.learn);
  if (learning.isNotEmpty) {
    return FindLevelSkills(skills: learning, verifying: false);
  }
  // Everything known is verified and nothing is being learned: check what is
  // known again. With nothing known either there is nothing to check, and the
  // row reads "Fit my level" (or "Find my level"), never "Verify".
  return FindLevelSkills(skills: known, verifying: known.isNotEmpty);
}

/// [skills] without those this phone cannot ask: Hear needs sound on and a
/// [voice] for the language, or its questions could not be heard and would
/// count as misses. Empty when nothing is left to check.
Set<PlacementSkill> placementSkillsForDevice(
  Set<PlacementSkill> skills, {
  required bool voice,
}) => <PlacementSkill>{
  for (final skill in skills)
    if (skill != PlacementSkill.hear || voice) skill,
};
