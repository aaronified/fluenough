import 'placement_questions.dart' show PlacementSkill;

// What a learner is shown per skill (wiki/Plan-Placement-V2.md, section 4.3):
// a name for the assurance, never a score out of 100.

/// The names of section 4.3, lowest to highest.
enum AssuranceLabel {
  /// The skill was not marked, not asked, or could not be tested (no mic):
  /// never a fail.
  notTested,

  /// Under 50%: a first guess.
  notSureYet,

  /// 50% to 79%.
  fairlySure,

  /// 80% to 94%: a good placement a little short of the target.
  sure,

  /// 95% or more: the target of the fit.
  verySure,

  /// Very sure at the top class, with every condition of section 4.3 met.
  verified,
}

/// The assurance a run aims for in every skill (owner, 2026-11-05: "Per
/// skill. Target is 95%").
const double kAssuranceTarget = 0.95;

/// The lower edge of "Sure": it only draws a line between names and is not a
/// stop target.
const double kSureFrom = 0.80;

/// The lower edge of "Fairly sure".
const double kFairlySureFrom = 0.50;

// A hair under the edges, so 0.95 reached by rounding in the last digit
// still reads as 95%.
const double _edge = 1e-9;

/// Whether [mass] has reached the 95% target.
bool reachesTarget(double mass) => mass >= kAssuranceTarget - _edge;

/// The name for a leading class of probability [mass] (not Verified, which
/// needs more than a number).
AssuranceLabel labelForMass(double mass) {
  if (mass >= kAssuranceTarget - _edge) return AssuranceLabel.verySure;
  if (mass >= kSureFrom - _edge) return AssuranceLabel.sure;
  if (mass >= kFairlySureFrom - _edge) return AssuranceLabel.fairlySure;
  return AssuranceLabel.notSureYet;
}

/// What the run knows about one skill (section 4.3 and 5.5).
class SkillAssurance {
  const SkillAssurance({
    required this.skill,
    required this.label,
    required this.mass,
    required this.leadingClass,
    required this.placedLevel,
    required this.questions,
    int? placedClass,
  }) : placedClass = placedClass ?? leadingClass;

  final PlacementSkill skill;

  /// The class the skill is placed in (plan section 13, point 5): the highest
  /// class the learner is at or above with probability `1 - 0.01 / C`, or 0.
  /// What is shown and credited; never the most probable class.
  final int placedClass;

  /// Whether a higher class is more probable than the placed one: the result
  /// reads "at least unit N".
  bool get lowerBound => placedClass < leadingClass;

  /// The name shown to the learner.
  final AssuranceLabel label;

  /// The probability of the placed class, which names the label (0 when not
  /// tested).
  final double mass;

  /// The most probable class (0 is `none`).
  final int leadingClass;

  /// The last deck index known, or -1 for none: the level of [placedClass].
  final int placedLevel;

  /// How many answers were evidence for this skill.
  final int questions;

  /// "Positioned at unit N": the learner knows units up to N and learns from
  /// N + 1; 0 for none.
  int get placedUnit => placedLevel + 1;

  bool get isVerified => label == AssuranceLabel.verified;
}
