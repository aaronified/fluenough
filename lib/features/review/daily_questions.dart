import '../../app/app_state.dart';
import '../../core/models/deck.dart';
import '../../core/review/question_generator.dart';
import '../../core/review/review_question.dart';
import 'review_waiting.dart';

/// The daily questions the reviewer could be asked now, the weakest data
/// first (#519): written from the decks of the courses they review, less
/// what they answered, and what they put off today. Empty with reviewing
/// off or no course ticked.
///
/// The Wiktionary import lists picture proposals (#523) in its report and
/// nothing keeps them in the decks yet, so there are none to ask about:
/// whatever persists them hands them to [generateQuestions] as `images`.
List<ReviewQuestion> dailyQuestionsOf(AppState state) {
  final reviewing = state.reviewing;
  if (!reviewing.on) return const <ReviewQuestion>[];
  final pairs = reviewPairsOf(state);
  return generateQuestions(<Deck>[
    for (final entry in state.decks)
      if (pairs.contains(pairOf(entry))) entry.deck,
  ], skip: reviewing.questions.hiddenOn(reviewing.today));
}
