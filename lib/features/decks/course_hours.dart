import 'package:flutter/foundation.dart';

import '../../app/app_state.dart';
import '../../core/models/drill_mode.dart';
import '../../core/models/review_event.dart';
import '../../core/scheduling/fsrs.dart';
import '../../core/scheduling/study_hours.dart';

/// Hours spent learning a language, and about how many are left in its
/// course's decks: the course card's hours row (#227).
typedef CourseHours = ({double spent, double left});

/// How many times [courseHours] has worked the hours out, rather than
/// reading them from [AppState.derived].
@visibleForTesting
int courseHoursComputed = 0;

/// [language]'s hours, from [state]'s log and the decks its course has.
/// Worked out once, and again only after progress, settings or the decks
/// change ([AppState.derived]).
///
/// Spent counts every review of the language, each capped at a minute
/// ([StudyHours.capped]), and the time on its teach cards (#886). Left counts only the units whose decks exist,
/// not the units planned to B1 (owner, 2026-10-10): each pair of a card in
/// them and a mode it can be drilled in now (`AppState.drillableModes`, so
/// skills switched off, those the phone cannot do and pairs set aside are
/// left out), not yet remembered. Script decks are in the course only for
/// a learner of the alphabet (`AppState.courseUnits`).
CourseHours courseHours(AppState state, String language) => state.derived((
  #courseHours,
  language,
), () => _courseHours(state, language));

List<ReviewEvent> _reviewsOf(AppState state, String language) => <ReviewEvent>[
  for (final review in state.progress.log)
    if ((state.deckById(review.deckId)?.language.code ??
            review.cardId.split('-').first) ==
        language)
      review,
];

CourseHours _courseHours(AppState state, String language) {
  courseHoursComputed++;
  final reviews = _reviewsOf(state, language);
  final pairs = <(DrillMode, FsrsState?)>[];
  final seen = <ProgressKey>{};
  final modesOf = state.drillableModesNow();
  for (final unit in state.courseUnits(language)) {
    for (final entry in unit) {
      for (final card in entry.cards) {
        for (final mode in modesOf(card)) {
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
    // Teach cards are timed too (#886), in the settings beside the log.
    spent: StudyHours.hours(
      StudyHours.spent(reviews) +
          state.settings.teachTimeTotal(language: language).time,
    ),
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

/// About how many hours are left to the end of B1 in [language]'s course
/// (#227; owner, 2026-10-23: "Hours left" counts "To the end of B1"): the
/// hours left in the decks written so far ([courseHours]), plus for each
/// unit up to B1 with no decks yet the average of what a written unit takes
/// from new, at the learner's own time per answer. Null where the language
/// has no decks to take the average from. Kept like [courseHours].
double? hoursLeftToB1(AppState state, String language) => state.derived((
  #hoursLeftToB1,
  language,
), () => _hoursLeftToB1(state, language));

double? _hoursLeftToB1(AppState state, String language) {
  final units = state.courseUnits(language);
  if (units.isEmpty) return null;
  final inDecks = courseHours(state, language).left;
  final coming = state.pathOf(units.first.first)?.unitsToWrite ?? 0;
  if (coming == 0) return inDecks;
  final reviews = _reviewsOf(state, language);
  final modesOf = state.drillableModesNow();
  final fresh = <(DrillMode, FsrsState?)>[];
  final seen = <ProgressKey>{};
  for (final unit in units) {
    for (final entry in unit) {
      for (final card in entry.cards) {
        for (final mode in modesOf(card)) {
          if (seen.add((cardId: card.id, mode: mode))) fresh.add((mode, null));
        }
      }
    }
  }
  final parameters = state.progress.parameters;
  final perUnit =
      StudyHours.hours(
        StudyHours.left(
          fresh,
          times: StudyHours.answerTimes(reviews),
          missShare: StudyHours.missShare(reviews),
          parametersOf: (mode) => parameters.of(language, mode),
        ),
      ) /
      units.length;
  return inDecks + perUnit * coming;
}
