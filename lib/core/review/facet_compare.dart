/// The blind-pass comparison (ADR-0058, decision 7, work package W5): given
/// what two or more reviewers said about a card's facets, each without
/// seeing the others, what do their answers add up to. Pure Dart.
///
/// Per facet the answer is one of [FacetStatus]: settled (agree it is
/// right), agreed fix (flags that propose the same text once compared by
/// [comparisonKey]: no human step), contested (right against a flag, or
/// different fixes: a third speaker decides), flagged (a tag, no fix two
/// agree on). This file reuses [facetStatus] for that and adds only what it
/// lacks: the list of distinct fixes, kept in the order proposed, and the
/// language a facet's text is in, so that the per-script folds apply.
///
/// Nothing here shows a count or a reviewer; the data is for the screens that
/// ask a second or third speaker, and for the tools.
library;

import 'facets.dart';
import 'review_pairs.dart';
import 'review_quorum.dart';
import 'script_folds.dart';

/// What the blind passes add up to for one facet.
class FacetComparison {
  const FacetComparison({
    required this.status,
    this.fixes = const <String>[],
    this.agreedFix,
  });

  final FacetStatus status;

  /// Every distinct fix the latest flags propose, each once after
  /// [comparisonKey] (the text of the first to propose it), in the order
  /// proposed. Empty when no flag has a fix.
  final List<String> fixes;

  /// The fix the flags agree on, when [status] is [FacetStatus.agreedFix].
  final String? agreedFix;

  /// Two or more rival fixes: the facet goes to a third speaker's pick.
  bool get needsPick => fixes.length >= 2;

  /// A tag and no fix at all.
  bool get isFlaggedNoFix => status == FacetStatus.flagged && fixes.isEmpty;

  /// Whether a human still has a step to take on this facet.
  bool get needsHuman =>
      status == FacetStatus.flagged || status == FacetStatus.contested;
}

/// The language the text of [facet] is in, for [pair], or null for a facet
/// with no script rules: the word and the example are in the language
/// learned, the meaning and the note in the learner's; readings, IPA, the
/// unit, the offence rating and audio get none.
String? languageOfFacet(Facet facet, ReviewPair pair) => switch (facet) {
  Facet.word || Facet.example => pair.target,
  Facet.meaning || Facet.note => pair.native,
  _ => null,
};

/// The distinct fixes in [checks]: one per rater's latest flag, each once
/// after [comparisonKey], in the order proposed. [exceptRater] (a rater code
/// as given) is left out: a reviewer's own fix is not a rival to themselves.
List<String> distinctFixesOf(
  Iterable<ReviewCheck> checks, {
  String? exceptRater,
  String? language,
  bool caseInsensitive = false,
}) {
  final latest = <String, ReviewCheck>{};
  for (final check in checks) {
    if (check.key.isNotEmpty) {
      latest.remove(check.key);
      latest[check.key] = check;
    }
  }
  final skip = exceptRater?.trim().toUpperCase();
  final out = <String>[];
  final keys = <String>{};
  for (final check in latest.values) {
    if (check.key == skip || check.endorses) continue;
    final fix = check.answer!.replacement;
    if (fix == null || fix.isEmpty) continue;
    final key = comparisonKey(
      fix,
      language: language,
      caseInsensitive: caseInsensitive,
    );
    if (keys.add(key)) out.add(fix);
  }
  return out;
}

/// The [FacetComparison] of one facet's [checks] (the latest answer of each
/// rater counts).
FacetComparison compareFacet(
  Iterable<ReviewCheck> checks, {
  String? language,
  bool caseInsensitive = false,
  int quorum = kReviewQuorum,
  bool needsVerified = kQuorumNeedsVerified,
}) {
  final list = checks.toList();
  final status = facetStatus(
    list,
    quorum: quorum,
    needsVerified: needsVerified,
    language: language,
    caseInsensitive: caseInsensitive,
  );
  final fixes = distinctFixesOf(
    list,
    language: language,
    caseInsensitive: caseInsensitive,
  );
  return FacetComparison(
    status: status,
    fixes: fixes,
    agreedFix: status == FacetStatus.agreedFix ? fixes.firstOrNull : null,
  );
}

/// The comparison of every facet any reviewer answered. [byRater] maps a
/// rater code to that reviewer's answers (a blind pass each); a facet nobody
/// answered is not in the result. [pair] gives each facet its text's language.
Map<Facet, FacetComparison> compareAnswers(
  Map<String, Map<Facet, FacetAnswer>> byRater, {
  ReviewPair? pair,
  bool Function(Facet facet)? caseInsensitive,
  int quorum = kReviewQuorum,
  bool needsVerified = kQuorumNeedsVerified,
}) {
  final out = <Facet, FacetComparison>{};
  for (final facet in Facet.values) {
    final checks = <ReviewCheck>[
      for (final entry in byRater.entries)
        if (entry.value[facet] != null)
          ReviewCheck(rater: entry.key, answer: entry.value[facet]),
    ];
    if (checks.isEmpty) continue;
    out[facet] = compareFacet(
      checks,
      language: pair == null ? null : languageOfFacet(facet, pair),
      caseInsensitive: caseInsensitive?.call(facet) ?? false,
      quorum: quorum,
      needsVerified: needsVerified,
    );
  }
  return out;
}
