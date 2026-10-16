/// The one language the whole app shows (#461), chosen in the language bar
/// at the top of Today, Decks and Progress (#528): those show that
/// language's lessons, reviews, decks and numbers. Only Progress can count
/// every language together, with its All button
/// (`SettingsNotifier.progressAll`). Settings keeps the choice
/// (`SettingsNotifier.languageChoice`); `AppState.shownLanguage` reads it.
///
/// Plain Dart, with no Flutter, so that it is tested on its own.
abstract final class LanguageChoice {
  /// What Settings stored for "All languages" chosen on purpose, before
  /// All became Progress's alone (#528). Not a language code, which is two
  /// or three letters: `all` is one. Still read, as the first language.
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

  /// The language shown, by code, or null only when [options] is empty.
  ///
  /// [chosen] is as Settings stores it: null before the learner has chosen,
  /// [all] from before #528, else a code. Before they choose, and when
  /// what they chose is no longer among [options], it is the first of
  /// [options]: the bar always shows one language (#528).
  static String? shown(String? chosen, List<String> options) {
    if (chosen != null && options.contains(chosen)) return chosen;
    return options.firstOrNull;
  }

  /// The language [step] places after (1) or before (-1) [shown] among
  /// [options], as a swipe on the language bar moves (#528); null at
  /// either end, where it does not wrap round.
  static String? step(String? shown, List<String> options, int step) {
    final i = shown == null ? -1 : options.indexOf(shown);
    if (i < 0) return null;
    final j = i + step;
    return j < 0 || j >= options.length ? null : options[j];
  }

  /// Whether [code]'s content shows while [shown] is the language shown,
  /// null for every language.
  static bool shows(String? shown, String code) =>
      shown == null || shown == code;

  /// Whether [text] is something Settings may store as a choice: [all], or
  /// a language code.
  static bool isValid(String text) =>
      text == all || RegExp(r'^[a-z]{2,3}$').hasMatch(text);
}
