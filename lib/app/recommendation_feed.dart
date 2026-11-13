import '../core/decks/recommendations.dart';
import '../core/models/deck.dart' show LanguageInfo;
import '../core/models/recommendation.dart';
import 'app_state.dart';

/// Recommended works fed from the catalog (deck-kinds plan, D13, T24 glue):
/// the language's file, the learner's course and level, and the gate between
/// them. The homepage that lists them is the culture track's (T26).
extension RecommendationFeed on AppState {
  /// What the books rule needs to know of the learner's course in [language]:
  /// whether its path teaches an alphabet, whether the language is written in
  /// the Latin alphabet alone, and the scripts the learner is learning. No
  /// course is "script only" yet, so that flag is never set.
  RecommendationCourse recommendationCourseOf(String language) {
    LanguageInfo? info;
    for (final candidate in languages) {
      if (candidate.code == language) info = candidate;
    }
    final path = catalogWithAboveLevel.languagePaths[language];
    return RecommendationCourse(
      pathHasAlphabet: path != null && path.alphabet.isNotEmpty,
      latinOnly: info != null && info.allScripts.every((s) => s == 'latin'),
      scriptsLearned: scriptsLearnedOf(language),
    );
  }

  /// The works of [language]'s file the learner is offered at their level and
  /// in their course, in the file's order; none without a file.
  List<Recommendation> recommendationsFor(String language) {
    final file = catalogWithAboveLevel.recommendations[language];
    if (file == null) return const <Recommendation>[];
    return offeredRecommendations(
      file.recommendations,
      recommendationCourseOf(language),
      levelIn(language),
    );
  }
}
