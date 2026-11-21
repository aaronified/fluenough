import 'placement_data.dart';
import 'placement_questions.dart' show PlacementSkill;
import 'reviewer_check_rules.dart';
import 'reviewer_check_run.dart';
import 'v3_result.dart';

// What the phone remembers of a course's reviewer check (ADR-0058, decision
// 1): that the check was passed and for which facets, when it was last taken
// (the cooldown), whether the quiet offer was made, and which cards were
// asked (so a retake is fresh). Never a score. Pure Dart; the app keeps the
// JSON in its settings.

/// Whether a placement result reached the top band for the reviewer check:
/// the lower bound of the credible range is at or above the B1 milestone on
/// Read and Write. Self-rated Say never counts.
///
/// The B1 milestone is the last level mark of [data] (the whole path when
/// the course marks none).
bool topBandReached(V3Result result, PlacementLanguageData data) {
  final b1Unit = data.levelMarkDecks.isEmpty
      ? data.deckCount
      : data.levelMarkDecks.last + 1;
  bool top(PlacementSkill skill) {
    final r = result.of(skill);
    return r != null && r.placed && r.rangeShown && r.lowUnit >= b1Unit;
  }

  return top(PlacementSkill.read) && top(PlacementSkill.write);
}

/// What a course's row on "Take the check" shows.
enum ReviewerCheckRow {
  /// Tap to start.
  take,

  /// Taken in the last [kReviewerCheckCooldownDays] days.
  cooldown,

  /// Too few eligible items, or a language without placement: ask for a
  /// reviewer key.
  askForKey,
}

/// A course's reviewer check record.
class ReviewerCheckRecord {
  const ReviewerCheckRecord({
    this.eligibility = const ReviewerEligibility(),
    this.lastAttempt,
    this.offered = false,
    this.used = const <String>[],
    this.mailed = false,
  });

  /// What the passed checks made the reviewer eligible for.
  final ReviewerEligibility eligibility;

  /// When the check was last finished, or null.
  final DateTime? lastAttempt;

  /// Whether the quiet offer was made: it is made once per course, and a
  /// "No thanks" or a taken check both end it.
  final bool offered;

  /// Ids of the cards asked about in earlier attempts.
  final List<String> used;

  /// Whether the passed-facets flag has gone in a review mail.
  final bool mailed;

  /// Whether the course has Provisional status from the check.
  bool get passed => eligibility.passed;

  /// The whole days left of the cooldown at [now], 0 when none.
  int cooldownDays(DateTime now) {
    final last = lastAttempt;
    if (last == null) return 0;
    final left = last
        .add(const Duration(days: kReviewerCheckCooldownDays))
        .difference(now);
    if (left <= Duration.zero) return 0;
    return (left.inHours / 24).ceil().clamp(1, kReviewerCheckCooldownDays);
  }

  /// Whether the check may be taken at [now].
  bool canTake(DateTime now) => cooldownDays(now) == 0;

  /// Whether the quiet offer should be made after a top-band placement: once
  /// per course, and not to a reviewer who has passed.
  bool get shouldOffer => !offered && !passed;

  ReviewerCheckRecord withOffered() => ReviewerCheckRecord(
    eligibility: eligibility,
    lastAttempt: lastAttempt,
    offered: true,
    used: used,
    mailed: mailed,
  );

  ReviewerCheckRecord withMailed() => ReviewerCheckRecord(
    eligibility: eligibility,
    lastAttempt: lastAttempt,
    offered: offered,
    used: used,
    mailed: true,
  );

  /// The record after an attempt that ended at [now] with [result]. A retake
  /// only adds eligibility, never takes it (no expiry); the cooldown starts.
  ReviewerCheckRecord afterAttempt(ReviewerCheckResult result, DateTime now) {
    final next = eligibility.union(result.eligibility);
    final all = <String>[...used, ...result.asked];
    final kept = all.length > kReviewerUsedMemory
        ? all.sublist(all.length - kReviewerUsedMemory)
        : all;
    return ReviewerCheckRecord(
      eligibility: next,
      lastAttempt: now,
      offered: true,
      used: kept,
      // New facets are worth a new flag.
      mailed:
          mailed &&
          next.passedFacetsWire.length == eligibility.passedFacetsWire.length,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (eligibility.passed) 'passed': eligibility.passedFacetsWire,
    if (lastAttempt != null) 'at': lastAttempt!.toUtc().millisecondsSinceEpoch,
    if (offered) 'offered': true,
    if (used.isNotEmpty) 'used': used,
    if (mailed) 'mailed': true,
  };

  /// A record read leniently: what is not of the shape is left out.
  static ReviewerCheckRecord fromJson(Object? json) {
    if (json is! Map) return const ReviewerCheckRecord();
    final at = json['at'];
    final used = json['used'];
    return ReviewerCheckRecord(
      eligibility: ReviewerEligibility.fromWire(json['passed']),
      lastAttempt: at is int
          ? DateTime.fromMillisecondsSinceEpoch(at, isUtc: true)
          : null,
      offered: json['offered'] == true,
      used: <String>[
        if (used is List)
          for (final id in used)
            if (id is String) id,
      ],
      mailed: json['mailed'] == true,
    );
  }
}
