/// How many reviews a facet needs, who counts, and what state a facet is in
/// (ADR-0058, decisions 8 and 12; work package W2). Pure Dart.
///
/// **The number is never shown in the app.** No screen, string or message
/// carries [kReviewQuorum]; screens say "needs another speaker's check".
/// The same number lives in `tools/review_quorum.py`
/// (`REVIEW_QUORUM`); `test/review_quorum_test.dart` keeps the two equal.
/// This supersedes the GitHub variable or secret `REVIEW_AGREEMENTS_NEEDED`
/// of ADR-0038: changing the number is a code change in both files.
library;

import 'facets.dart';

/// Reviews by distinct reviewers a facet needs.
const int kReviewQuorum = 2;

/// Whether the quorum also needs a Verified reviewer among the checks.
/// Off until W7 (signed reviewer keys) turns it on: every reviewer is
/// [ReviewerTier.provisional] today, and turning it on now would leave no
/// card reviewable. `tools/review_quorum.py` has the matching switch.
const bool kQuorumNeedsVerified = false;

/// What a reviewer's checks are worth (decision 8).
enum ReviewerTier {
  /// Passed the reviewer check, or an FL code with no key. Everyone is this
  /// until W7.
  provisional,

  /// A signed key for the course, or calibration cards. Counts fully.
  verified,

  /// Sustained agreement with Verified reviewers; breaks ties on contested
  /// cards.
  trusted;

  /// Whether this tier satisfies a "needs a Verified reviewer" rule.
  bool get isVerified => this != provisional;
}

/// One reviewer's check of one facet.
class ReviewCheck {
  const ReviewCheck({
    required this.rater,
    this.tier = ReviewerTier.provisional,
    this.answer,
  });

  /// The rater code, as written in the review (`FL-XXXX-XXXX-C`). Compared
  /// as given after trimming and upper-casing.
  final String rater;
  final ReviewerTier tier;

  /// What the reviewer said, or null for a bare check (for instance a code
  /// listed in `checked_by`), which counts as "right".
  final FacetAnswer? answer;

  String get key => rater.trim().toUpperCase();

  /// Whether this check endorses the facet: a bare check or a right answer.
  /// A flag is not an endorsement.
  bool get endorses => answer == null || answer!.isRight;
}

/// Whether [checks] give a facet the quorum.
///
/// Counted: the distinct raters among the checks that endorse the facet
/// (a flag does not count; two checks by one code are one). Needs
/// [quorum] of them. With [needsVerified] (the W7 switch, [kQuorumNeedsVerified]
/// today) at least one of them must be Verified or Trusted.
bool facetReachedQuorum(
  Iterable<ReviewCheck> checks, {
  int quorum = kReviewQuorum,
  bool needsVerified = kQuorumNeedsVerified,
}) {
  final byRater = <String, ReviewerTier>{};
  for (final check in checks) {
    if (check.key.isEmpty || !check.endorses) continue;
    final seen = byRater[check.key];
    // One code counts once, at the best tier it has been seen at.
    if (seen == null || check.tier.index > seen.index) {
      byRater[check.key] = check.tier;
    }
  }
  if (byRater.length < quorum) return false;
  return !needsVerified || byRater.values.any((tier) => tier.isVerified);
}

/// Whether a card's facets all have the quorum: [applicable] facets are each
/// in [checksByFacet] with [facetReachedQuorum]. Replaces ADR-0038's
/// file-level rule (W9 moves the bot to it).
bool cardReachedQuorum(
  Set<Facet> applicable,
  Map<Facet, List<ReviewCheck>> checksByFacet, {
  int quorum = kReviewQuorum,
  bool needsVerified = kQuorumNeedsVerified,
}) =>
    applicable.isNotEmpty &&
    applicable.every(
      (facet) => facetReachedQuorum(
        checksByFacet[facet] ?? const <ReviewCheck>[],
        quorum: quorum,
        needsVerified: needsVerified,
      ),
    );

/// Where a facet stands, from its checks.
enum FacetStatus {
  /// No check.
  unchecked,

  /// Checks that all say right, fewer than the quorum.
  checking,

  /// The quorum of right checks.
  settled,

  /// A reviewer's tag with no resolution: one flag, or flags with no
  /// proposed fix, and nobody disagreeing.
  flagged,

  /// Two or more flags that agree on one proposed text (after
  /// normalisation): nothing for a human to decide, the fix can be applied.
  agreedFix,

  /// Two checks disagree: one says right and another flags, or two propose
  /// different texts. Goes to a third speaker.
  contested,
}

/// The [FacetStatus] of [checks]. One answer per rater code counts (the
/// latest in the list wins), so a reviewer who changes their mind does not
/// contest themselves.
FacetStatus facetStatus(
  Iterable<ReviewCheck> checks, {
  int quorum = kReviewQuorum,
  bool needsVerified = kQuorumNeedsVerified,
}) {
  final latest = <String, ReviewCheck>{};
  for (final check in checks) {
    if (check.key.isNotEmpty) latest[check.key] = check;
  }
  if (latest.isEmpty) return FacetStatus.unchecked;
  final all = latest.values.toList();
  final flagged = all.where((c) => !c.endorses).toList();
  if (flagged.isEmpty) {
    return facetReachedQuorum(all, quorum: quorum, needsVerified: needsVerified)
        ? FacetStatus.settled
        : FacetStatus.checking;
  }
  if (flagged.length < all.length) return FacetStatus.contested;
  final withFix = flagged.where((c) => c.answer!.hasReplacement).toList();
  if (withFix.length < quorum) return FacetStatus.flagged;
  // Enough flags with a fix: they agree when each proposes the same text.
  final first = withFix.first.answer!;
  final same = withFix.every((c) => c.answer!.sameReplacement(first));
  if (!same) return FacetStatus.contested;
  return FacetStatus.agreedFix;
}
