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
/// OFF by default. W7 (signed reviewer keys, `reviewer_key.dart`) built what
/// turning it on needs, but turning it on also leaves every card with no
/// Verified reviewer unable to settle, so it is the owner's switch, in both
/// files, once Verified reviewers exist. `tools/review_quorum.py` has the
/// matching switch; the bot knows each code's tier privately.
const bool kQuorumNeedsVerified = false;

/// What a reviewer's checks are worth (decision 8).
enum ReviewerTier {
  /// Passed the reviewer check, or an FL code with no signed key.
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

/// Whether [checks] give a facet the quorum. The one rule, here only:
/// [facetStatus] settles a facet exactly when this is true.
///
/// [checks] are in the order they were made. Each rater code counts once,
/// by its latest answer (a reviewer who changes right to flag stops
/// counting). If any rater's latest answer is a flag the facet is not
/// settled, whatever the others say: that is a contested or flagged facet.
/// Otherwise it needs [quorum] distinct raters, and with [needsVerified]
/// (the W7 switch, [kQuorumNeedsVerified] today) at least one of them
/// Verified or Trusted, a rater counting at the best tier it was seen at.
bool facetReachedQuorum(
  Iterable<ReviewCheck> checks, {
  int quorum = kReviewQuorum,
  bool needsVerified = kQuorumNeedsVerified,
}) {
  final endorsing = <String, bool>{};
  final tiers = <String, ReviewerTier>{};
  for (final check in checks) {
    if (check.key.isEmpty) continue;
    endorsing[check.key] = check.endorses;
    final seen = tiers[check.key];
    if (seen == null || check.tier.index > seen.index) {
      tiers[check.key] = check.tier;
    }
  }
  if (endorsing.values.any((ok) => !ok)) return false;
  if (endorsing.length < quorum) return false;
  return !needsVerified || tiers.values.any((tier) => tier.isVerified);
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
///
/// Two fixes are the same when [comparisonKey] says so for [language] (the
/// language the facet's text is in; null means NFC and white space only) and
/// [caseInsensitive]. The comparison never changes the stored text.
FacetStatus facetStatus(
  Iterable<ReviewCheck> checks, {
  int quorum = kReviewQuorum,
  bool needsVerified = kQuorumNeedsVerified,
  String? language,
  bool caseInsensitive = false,
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
  final same = withFix.every(
    (c) => c.answer!.sameReplacement(
      first,
      language: language,
      caseInsensitive: caseInsensitive,
    ),
  );
  if (!same) return FacetStatus.contested;
  return FacetStatus.agreedFix;
}
