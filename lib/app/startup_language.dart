import 'language_choice.dart';

/// Which language the app opens on, worked out without the catalog
/// (ADR-0062, Plan-Lazy-Language-Loading, 3.5): the same answer that
/// `AppState.shownLanguage` gives once the decks are loaded, from the
/// settings, the profile and the codes of the languages on the phone alone,
/// so that only that language has to be read to start. Plain Dart, with no
/// Flutter, so that it is tested on its own.
abstract final class StartupLanguage {
  /// The language to open on, or null when none is on the phone.
  ///
  /// [chosen] is `SettingsNotifier.languageChoice`, [learning] the order the
  /// learner chose their languages in (the settings' list, then the
  /// profile's), [learns] whether the current profile learns a language, and
  /// [available] the languages on the phone, in the order the catalog lists
  /// them. It is the language bar's language: the one chosen while it is still
  /// learned and on the phone, else the first of the options
  /// ([LanguageChoice.options]).
  static String? resolve({
    required String? chosen,
    required List<String> learning,
    required bool Function(String code) learns,
    required Iterable<String> available,
  }) {
    final options = LanguageChoice.options(
      learning: learning,
      available: <String>[
        for (final code in available)
          if (learns(code)) code,
      ],
    );
    return LanguageChoice.shown(chosen, options);
  }
}
