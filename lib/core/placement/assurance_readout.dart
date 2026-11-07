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
