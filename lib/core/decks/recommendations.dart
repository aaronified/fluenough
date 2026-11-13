/// Which recommended works a learner is offered, and when their questions are
/// asked (wiki/Plan-Deck-Kinds-And-Topics.md, D13, T24). Pure functions over
/// data, free of Flutter, so that the rules are tested in milliseconds.
///
/// * A recommendation above the learner's level is not offered (D2).
/// * Books and scripts (owner's rule, open question 11): a `book` is
///   recommended only when the learner's course includes script learning in
///   that language (the path has an `alphabet`, or the learner is on a
///   script-only course); a language whose only script is Latin counts as
///   script learning already done. A script-only learner sees only books in a
///   script they are learning. Films, series, songs, plays, podcasts and comics
///   are not gated by script.
/// * Questions are asked only on a work the learner marked completed.
library;

import '../models/level.dart';
import '../models/reading.dart' show ReadingQuestion;
import '../models/recommendation.dart';

/// What the gate needs to know of a learner's course in one language.
class RecommendationCourse {
  const RecommendationCourse({
    this.pathHasAlphabet = false,
    this.scriptOnly = false,
    this.latinOnly = false,
    this.scriptsLearned = const <String>{},
  });

  /// The course's path has an `alphabet`: it teaches the script.
  final bool pathHasAlphabet;

  /// The learner is on a script-only course.
  final bool scriptOnly;

  /// The language is written only in the Latin alphabet.
  final bool latinOnly;

  /// The scripts the learner is learning (`telugu`, `perso_arabic`).
  final Set<String> scriptsLearned;

  /// Whether the course includes script learning, for the books rule.
  bool get learnsScripts => pathHasAlphabet || scriptOnly || latinOnly;
}

/// Whether [recommendation] is offered to a learner on [course] at [level]
/// (null for a language with no levels, which is offered no levelled work).
/// A recommendation with no level of its own is open to everyone.
bool recommendationOffered(
  Recommendation recommendation,
  RecommendationCourse course,
  Level? level,
) {
  if (!LevelGate.allows(recommendation.level, level)) return false;
  if (!recommendation.isBook) return true;
  if (!course.learnsScripts) return false;
  if (course.scriptOnly) {
    final script = recommendation.script;
    return script != null && course.scriptsLearned.contains(script);
  }
  return true;
}

/// The recommendations of [all] offered to the learner, in order.
List<Recommendation> offeredRecommendations(
  Iterable<Recommendation> all,
  RecommendationCourse course,
  Level? level,
) => <Recommendation>[
  for (final r in all)
    if (recommendationOffered(r, course, level)) r,
];

/// The questions of [recommendation] that may be asked: all of them when the
/// learner marked it completed ([completed] holds its id), none otherwise.
/// Un-marking stops them.
List<ReadingQuestion> openQuestions(
  Recommendation recommendation,
  Set<String> completed,
) => completed.contains(recommendation.id)
    ? recommendation.questions
    : const <ReadingQuestion>[];
