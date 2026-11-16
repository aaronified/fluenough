import 'assurance_readout.dart';
import 'assurance_model.dart';
import 'joint_model.dart';
import 'placement_questions.dart';

// What a V3 readout writes to a learner's data (wiki/Plan-Placement-V3.md):
// each skill's LOWER EDGE, never above the level its items proved, and nothing
// for a skill that was not tested or was only self-rated (Say without a
// recogniser). The write itself is `AppState.writePlacementReadout`
// (lib/app/placement_run_setup.dart), which reads the carrier below.
//
// Pure Dart.

/// The V3 readout as the placement write reads a run: a [SkillAssurance] per
/// skill. A skill that was scored carries its lower edge as the placed class
/// (the readout's start, which the proven-level ceiling already caps; capped
/// again here, so a caller cannot write more than was proven) and a label
/// from its honest confidence ("Verified" does not exist in V3). A skill that
/// was not tested, or only self-rated, carries [AssuranceLabel.notTested] and
/// no level: the write skips it, and it never pulls the course's placed
/// decks down.
Map<PlacementSkill, SkillAssurance> assurancesFromJoint(
  JointReadout readout,
  PlacementLevels levels,
) {
  final out = <PlacementSkill, SkillAssurance>{};
  for (final e in readout.skills.entries) {
    final r = e.value;
    if (r.state != EvidenceState.tested) {
      out[e.key] = SkillAssurance(
        skill: e.key,
        label: AssuranceLabel.notTested,
        mass: 0,
        leadingClass: 0,
        placedLevel: -1,
        questions: 0,
      );
      continue;
    }
    final ceiling = r.provenClass ?? 0;
    final placed = r.startClass < ceiling ? r.startClass : ceiling;
    out[e.key] = SkillAssurance(
      skill: e.key,
      label: switch (r.confidence) {
        PlacementConfidence.high => AssuranceLabel.sure,
        PlacementConfidence.medium => AssuranceLabel.fairlySure,
        PlacementConfidence.low => AssuranceLabel.notSureYet,
      },
      mass: r.nearMass,
      leadingClass: r.medianClass,
      placedClass: placed,
      placedLevel: levels.levelOf(placed),
      questions: r.cleanItems,
    );
  }
  return out;
}
