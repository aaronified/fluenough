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
