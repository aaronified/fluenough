/// The one language the whole app shows (#461): Today, Decks and Progress
/// show that language's lessons, reviews, decks and numbers, or every
/// language's together under "All languages". Settings keeps the choice
/// (`SettingsNotifier.languageChoice`); `AppState.shownLanguage` reads it.
///
/// Plain Dart, with no Flutter, so that it is tested on its own.
abstract final class LanguageChoice {
  /// What Settings stores for "All languages" chosen on purpose. Not a
  /// language code, which is two or three letters: `all` is one.
  static const String all = '*';

  /// The languages the menu offers, by code: those of [available] the
  /// learner chose to learn, in the order they chose them ([learning]),
  /// then the rest of [available] in its own order. [available] is the
  /// languages the profile learns that have a deck on the phone; one chosen
  /// but not on the phone yet has nothing to show, and is not offered.
  static List<String> options({
    required List<String> learning,
    required Iterable<String> available,
  }) {
    final on = <String>{...available};
    return <String>[
      for (final code in learning)
        if (on.contains(code)) code,
      for (final code in on)
        if (!learning.contains(code)) code,
    ];
  }

  /// The language shown, by code, or null for every language.
  ///
  /// [chosen] is as Settings stores it: null before the learner has chosen,
  /// [all] for All, else a code. Before they choose, and when what they
  /// chose is no longer among [options], it is All, unless there is only
  /// one language to show: then that one, which shows the same.
  static String? shown(String? chosen, List<String> options) {
    if (chosen == all) return null;
    if (chosen != null && options.contains(chosen)) return chosen;
    return options.length == 1 ? options.single : null;
  }

  /// Whether [code]'s content shows while [shown] is the language shown.
  static bool shows(String? shown, String code) =>
      shown == null || shown == code;

  /// Whether [text] is something Settings may store as a choice: [all], or
  /// a language code.
  static bool isValid(String text) =>
      text == all || RegExp(r'^[a-z]{2,3}$').hasMatch(text);
}
