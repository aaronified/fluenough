import '../../app/app_state.dart';
import '../../core/models/drill_mode.dart';
import '../../core/models/review_event.dart';
import '../../core/scheduling/fsrs.dart';
import '../../core/scheduling/study_hours.dart';

/// Hours spent learning a language, and about how many are left in its
/// course's decks: the course card's hours row (#227).
typedef CourseHours = ({double spent, double left});

/// [language]'s hours, from [state]'s log and the decks its course has.
///
/// Spent counts every review of the language, each capped at a minute
/// ([StudyHours.capped]). Left counts only the units whose decks exist,
/// not the units planned to B1 (owner, 2026-10-10): each pair of a card in
/// them and a mode it can be drilled in now (`AppState.drillableModes`, so
/// skills switched off, those the phone cannot do and pairs set aside are
/// left out), not yet remembered. Script decks are in the course only for
/// a learner of the alphabet (`AppState.courseUnits`).
CourseHours courseHours(AppState state, String language) {
  final reviews = <ReviewEvent>[
    for (final review in state.progress.log)
      if ((state.deckById(review.deckId)?.language.code ??
              review.cardId.split('-').first) ==
          language)
        review,
  ];
  final pairs = <(DrillMode, FsrsState?)>[];
  final seen = <ProgressKey>{};
  for (final unit in state.courseUnits(language)) {
    for (final entry in unit) {
      for (final card in entry.cards) {
        for (final mode in state.drillableModes(card)) {
          final key = (cardId: card.id, mode: mode);
          if (seen.add(key)) {
            pairs.add((mode, state.progress.stateOf(card.id, mode)));
          }
        }
      }
    }
  }
  final parameters = state.progress.parameters;
  return (
    spent: StudyHours.hours(StudyHours.spent(reviews)),
    left: StudyHours.hours(
      StudyHours.left(
        pairs,
        times: StudyHours.answerTimes(reviews),
        missShare: StudyHours.missShare(reviews),
        parametersOf: (mode) => parameters.of(language, mode),
      ),
    ),
  );
}
