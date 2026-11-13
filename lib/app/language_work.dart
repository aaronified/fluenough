import 'app_state.dart';
import 'session.dart';

/// What the language bar shows on a language (#681).
extension LanguageWork on AppState {
  /// Whether [language] has any review due now or any new card waiting to be
  /// taught, as Today counts them: the dot on the language bar. A queue that
  /// cannot be built is logged and counts as nothing to do, so one language
  /// cannot break the bar.
  bool languageHasWork(String language) =>
      derived<bool>(('languageHasWork', language), () {
        try {
          final queue = buildSession(DrillRequest.today(language: language));
          return queue.due.isNotEmpty || queue.fresh.isNotEmpty;
        } on Object catch (error) {
          log.error(
            'Language bar: could not count the work of $language: $error',
          );
          return false;
        }
      });
}
