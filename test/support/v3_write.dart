import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/placement_run_setup.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/v3_result.dart';

/// A finished V3 run for the tests of the write: every skill of [skills]
/// placed at the top of the course ([right]) or at the very beginning
/// ([right] false: tested and placed at none), as a learner's start.
class FinishedV3 {
  FinishedV3(PlacementRunPlan plan, Set<PlacementSkill> skills, bool right)
    : levels = PlacementLevels(plan.data.deckCount, maxParts: 20),
      skills = skills {
    top = right ? levels.topClass : 0;
    result = V3Result(
      skills: <V3SkillResult>[
        for (final s in skills)
          // Nothing here hears the learner: Say is rated, never placed.
          s == PlacementSkill.say
              ? const V3SkillResult(
                  skill: PlacementSkill.say,
                  status: V3Status.selfRated,
                )
              : V3SkillResult(
                  skill: s,
                  status: V3Status.placed,
                  startClass: top,
                  startUnit: top == 0 ? 0 : levels.levelOf(top) + 1,
                ),
      ],
      levels: levels,
      readout: null,
      script: null,
      items: 20,
      seconds: 100,
      endReason: null,
    );
  }

  final PlacementLevels levels;
  final Set<PlacementSkill> skills;
  late final int top;
  late final V3Result result;

  Map<PlacementSkill, int> get overrides => <PlacementSkill, int>{
    for (final s in skills)
      if (s != PlacementSkill.say) s: top,
  };

  /// What the write reads, by skill.
  Map<PlacementSkill, SkillAssurance> get readout =>
      result.assurances(overrides: overrides);

  void write(
    AppState state,
    String code,
    PlacementRunPlan plan, {
    bool recheck = false,
  }) => state.writePlacementV3(
    code,
    plan,
    result,
    overrides: overrides,
    recheck: recheck,
  );
}
