import 'assurance_model.dart';
import 'assurance_readout.dart';
import 'joint_model.dart';
import 'placed_outcome.dart';
import 'placement_questions.dart' show PlacementSkill;
import 'script_gate.dart';
import 'v3_picker.dart' show EndReason;
import 'v3_session.dart';

// What a V3 run found, in the words of the result screen (wiki/
// Plan-Placement-V3.md, step 7): per skill a start unit with the range the
// run is 80% sure of, a confidence word, or the reason the skill was not
// placed. Pure Dart.

/// How a skill stands at the end of a run.
enum V3Status {
  /// Placed: a start unit and its range.
  placed,

  /// Not tested ([V3SkillResult.why] says why).
  notTested,

  /// Only rated by the learner: no unit.
  selfRated,

  /// Read or Write while the script is not read yet.
  needsScript,
}

/// One skill of the result.
class V3SkillResult {
  const V3SkillResult({
    required this.skill,
    required this.status,
    this.why,
    this.startUnit = 0,
    this.lowUnit = 0,
    this.highUnit = 0,
    this.startClass = 0,
    this.confidence,
    this.cappedByProof = false,
    this.rangeShown = false,
  });

  final PlacementSkill skill;
  final V3Status status;
  final V3Why? why;

  /// The unit the learner starts at: the lower edge of the range, never above
  /// what the items proved. 0 is the very beginning. A unit is a deck of the
  /// path (1 for the first).
  final int startUnit;
  final int lowUnit;
  final int highUnit;
  final int startClass;

  /// The word from how likely the true level is within a tenth of the
  /// middle; null when the skill was not placed.
  final PlacementConfidence? confidence;
  final bool cappedByProof;

  /// Whether the range may be shown (the skill has the clean items for it).
  final bool rangeShown;

  bool get placed => status == V3Status.placed;

  /// The 80% range as percents of a path of [totalUnits] units; the start
  /// alone when the range may not be shown.
  V3PercentRange percentRange(int totalUnits) {
    int pct(int unit) =>
        totalUnits <= 0 ? 0 : (unit * 100 / totalUnits).round().clamp(0, 100);
    return rangeShown
        ? V3PercentRange(pct(lowUnit), pct(highUnit))
        : V3PercentRange(pct(startUnit), pct(startUnit));
  }
}

/// The level names of a placed skill, by how much of the whole language path
/// it covers (wiki/Plan-Placement-V3.md, "The result card").
enum V3LevelName { beginner, amateur, fluent, expert }

/// Where each level name begins, in percent of the path: Amateur from 20,
/// Fluent from 45, Expert from 75.
const List<int> v3LevelCutoffs = <int>[20, 45, 75];

/// The level name of a skill whose range is [percent] of the path (its middle).
V3LevelName v3LevelNameOf(double percent) {
  var i = 0;
  for (final cut in v3LevelCutoffs) {
    if (percent >= cut) i++;
  }
  return V3LevelName.values[i];
}

/// A placed skill's range as whole percents of the path ([low] to [high]).
class V3PercentRange {
  const V3PercentRange(this.low, this.high);

  final int low;
  final int high;

  /// The level name, from the middle of the range.
  V3LevelName get level => v3LevelNameOf((low + high) / 2);
}

/// A whole run's result.
class V3Result {
  const V3Result({
    required this.skills,
    required this.levels,
    required this.readout,
    required this.script,
    required this.items,
    required this.seconds,
    required this.endReason,
  });

  /// The skills the learner had in play, in the order Read, Hear, Say, Write.
  final List<V3SkillResult> skills;
  final PlacementLevels levels;

  /// The model's readout (null when no item was asked).
  final JointReadout? readout;

  /// What the script gate found (null without one).
  final ScriptGateResult? script;
  final int items;
  final double seconds;
  final EndReason? endReason;

  V3SkillResult? of(PlacementSkill skill) {
    for (final s in skills) {
      if (s.skill == skill) return s;
    }
    return null;
  }

  /// Whether Read and Write were left out because the script cannot be read.
  /// How many units the whole path has (the last level's unit).
  int get totalUnits => levels.levelOf(levels.topClass) + 1;

  bool get needsScript => skills.any((s) => s.status == V3Status.needsScript);

  /// What the placement write reads: [assurancesFromJoint] with the skills
  /// the run left out as not tested, and a learner's [overrides] (a class
  /// per skill) replacing a skill's start.
  Map<PlacementSkill, SkillAssurance> assurances({
    Map<PlacementSkill, int> overrides = const <PlacementSkill, int>{},
    int scripts = 0,
  }) {
    final out = <PlacementSkill, SkillAssurance>{
      if (readout != null) ...assurancesFromJoint(readout!, levels),
    };
    for (final s in skills) {
      if (!out.containsKey(s.skill)) {
        out[s.skill] = SkillAssurance(
          skill: s.skill,
          label: AssuranceLabel.notTested,
          mass: 0,
          leadingClass: 0,
          placedLevel: -1,
          questions: 0,
        );
      }
    }
    // The script: a learner who passed the letter check ("all") is credited
    // as reading the course's scripts (their decks are placed); one who
    // failed it is recorded as new to them. A check that was skipped, or
    // that ended in between ("partly"), says nothing and writes nothing.
    final gate = script;
    if (gate != null && !gate.skipped && scripts > 0) {
      final top = levels.topClass;
      final cls = switch (gate.level) {
        ScriptLevel.all => top,
        ScriptLevel.none => 0,
        ScriptLevel.partly => null,
      };
      if (cls != null) {
        for (final (i, skill) in const <PlacementSkill>[
          PlacementSkill.script,
          PlacementSkill.secondScript,
        ].indexed) {
          if (i >= scripts) break;
          out[skill] = SkillAssurance(
            skill: skill,
            label: AssuranceLabel.sure,
            mass: 1,
            leadingClass: cls,
            placedClass: cls,
            placedLevel: cls == 0 ? -1 : levels.levelOf(cls),
            questions: gate.items,
          );
        }
      }
    }
    for (final e in overrides.entries) {
      final c = e.value.clamp(0, levels.topClass);
      final was = out[e.key];
      out[e.key] = SkillAssurance(
        skill: e.key,
        // A start at the very beginning is a placement too (it takes back any
        // credit above it on a re-check).
        label: AssuranceLabel.sure,
        mass: was?.mass ?? 0,
        leadingClass: c,
        placedClass: c,
        placedLevel: levels.levelOf(c),
        questions: was?.questions ?? 0,
      );
    }
    return out;
  }

  /// The result of [run].
  factory V3Result.of(V3Run run) {
    final model = run.model;
    final readout = model?.readout();
    final levels = run.levels;
    int unit(int c) => c == 0 ? 0 : levels.levelOf(c) + 1;
    final gate = run.scriptResult;
    final blocked = gate != null && !gate.readable;
    final out = <V3SkillResult>[];
    for (final skill in const <PlacementSkill>[
      PlacementSkill.read,
      PlacementSkill.hear,
      PlacementSkill.say,
      PlacementSkill.write,
    ]) {
      if (!run.wanted.contains(skill)) continue;
      final r = readout?.skills[skill];
      if (r != null && r.state == EvidenceState.tested) {
        out.add(
          V3SkillResult(
            skill: skill,
            status: V3Status.placed,
            startUnit: unit(
              r.startClass < (r.provenClass ?? 0)
                  ? r.startClass
                  : (r.provenClass ?? 0),
            ),
            lowUnit: unit(r.lowClass),
            highUnit: unit(r.highClass),
            startClass: r.startClass,
            confidence: r.confidence,
            cappedByProof: r.cappedByProof,
            rangeShown: r.rangeShown,
          ),
        );
        continue;
      }
      if (skill == PlacementSkill.say) {
        out.add(
          V3SkillResult(
            skill: skill,
            status: run.audio && !run.audioDropped && !run.microphoneGivenUp
                ? V3Status.selfRated
                : V3Status.notTested,
            why: run.audio && !run.audioDropped && !run.microphoneGivenUp
                ? V3Why.selfRated
                : V3Why.noDevice,
          ),
        );
        continue;
      }
      if (skill == PlacementSkill.hear && (!run.audio || run.audioDropped)) {
        out.add(
          const V3SkillResult(
            skill: PlacementSkill.hear,
            status: V3Status.notTested,
            why: V3Why.noDevice,
          ),
        );
        continue;
      }
      if (blocked &&
          (skill == PlacementSkill.read || skill == PlacementSkill.write)) {
        out.add(
          V3SkillResult(
            skill: skill,
            status: V3Status.needsScript,
            why: V3Why.needsScript,
          ),
        );
        continue;
      }
      out.add(
        V3SkillResult(
          skill: skill,
          status: V3Status.notTested,
          why: V3Why.notEnough,
        ),
      );
    }
    return V3Result(
      skills: out,
      levels: levels,
      readout: readout,
      script: gate,
      items: run.answered,
      seconds: run.seconds,
      endReason: run.picker?.endReason,
    );
  }
}
