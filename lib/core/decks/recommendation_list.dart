/// What the recommendations list shows a learner (wiki
/// Plan-Deck-Kinds-And-Topics.md, D13, T26; the approved mockup
/// `culture-recommendations.html`): the works offered, by kind with counts, how
/// many are above the learner's level and where they unlock, and how many books
/// a script-only learner is not shown for another script. Built on
/// [recommendationOffered], the one gate; pure and free of Flutter.
library;

import '../models/level.dart';
import '../models/recommendation.dart';
import 'recommendations.dart';

/// The browse list of one language for one learner.
class RecommendationList {
  const RecommendationList({
    this.offered = const <Recommendation>[],
    this.hiddenAbove = 0,
    this.unlocksAt,
    this.otherScript = 0,
  });

  /// The works offered, in the file's order.
  final List<Recommendation> offered;

  /// How many works are hidden because they are above the learner's level.
  final int hiddenAbove;

  /// The lowest level a hidden work unlocks at, or null when none is hidden.
  final Level? unlocksAt;

  /// How many books a script-only learner is not shown because they are in a
  /// script the learner is not learning.
  final int otherScript;

  /// The kinds present among [offered], in the order of the medium list.
  List<RecommendationMedium> get media => <RecommendationMedium>[
    for (final medium in RecommendationMedium.values)
      if (offered.any((r) => r.medium == medium)) medium,
  ];

  /// How many of [offered] are of [medium].
  int count(RecommendationMedium medium) =>
      offered.where((r) => r.medium == medium).length;

  /// [offered] narrowed to [medium], or all of them when it is null.
  List<Recommendation> of(RecommendationMedium? medium) => <Recommendation>[
    for (final r in offered)
      if (medium == null || r.medium == medium) r,
  ];
}

/// The list of [all] for a learner on [course] at [level]. A work is offered
/// by [recommendationOffered], and a script-only learner is shown only books
/// (the approved mockup: the rest appears when they start the language); one
/// it refuses is counted as above the level
/// when its level is above, else as another script when it is a book of a
/// script the script-only learner is not learning.
RecommendationList recommendationList(
  Iterable<Recommendation> all,
  RecommendationCourse course,
  Level? level,
) {
  final offered = <Recommendation>[];
  var hidden = 0;
  var otherScript = 0;
  Level? lowest;
  for (final r in all) {
    // The approved mockup: a learner who learns only the script is shown
    // books, in that script, and nothing else until they start the language.
    if (course.scriptOnly && !r.isBook) continue;
    if (recommendationOffered(r, course, level)) {
      offered.add(r);
    } else if (LevelGate.isAbove(r.level, level) &&
        recommendationOffered(r, course, Level.c2)) {
      hidden++;
      final at = r.level;
      if (at != null && (lowest == null || at.index < lowest.index)) {
        lowest = at;
      }
    } else if (r.isBook && course.scriptOnly) {
      otherScript++;
    }
  }
  return RecommendationList(
    offered: List<Recommendation>.unmodifiable(offered),
    hiddenAbove: hidden,
    unlocksAt: lowest,
    otherScript: otherScript,
  );
}

/// Whether [recommendation] carries the public-domain badge: its legal routes
/// say it is in the public domain, or a culture deck quotes it (only a work
/// whose rights allow it is quoted, D13).
bool isPublicDomainWork(Recommendation recommendation) =>
    recommendation.quotedIn != null ||
    recommendation.legal.any((route) => route.kind == 'public-domain');
