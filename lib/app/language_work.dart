import 'app_state.dart';
import 'session.dart';

/// What the language bar shows on a language (#681).
extension LanguageWork on AppState {
  /// Whether [language] has any review due now or any new card waiting to be
  /// taught, as Today counts them: the dot on the language bar. Kept for 30 seconds at most, so a card that falls due with the
  /// clock shows its dot soon after. A count that
  /// cannot be made is logged and counts as nothing to do, so one language
  /// cannot break the bar.
  bool languageHasWork(String language) =>
      keptFor<bool>(language, 'languageHasWork', () {
        try {
          final queue = buildSession(DrillRequest.today(language: language));
          if (queue.due.isNotEmpty || queue.fresh.isNotEmpty) return true;
          // New cards not taught yet, as Today's lesson counts them.
          return untaughtCards(language).isNotEmpty;
        } on Object catch (error) {
          log.error(
            'Language bar: could not count the work of $language: $error',
          );
          return false;
        }
      });
}
