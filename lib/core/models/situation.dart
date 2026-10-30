/// One everyday situation a learner may need words for: hailing a cab,
/// shopping, the doctor (#724; docs/DECK-FORMAT.md, "Situations files").
///
/// A situation holds no card text. It lists card ids, so a card fixed once
/// is fixed on every sheet that names it, and its title is written in each
/// language it is taught from.
class Situation {
  const Situation({
    required this.id,
    required this.icon,
    required this.title,
    this.phrases = const <String>[],
    this.words = const <String>[],
  });

  /// Permanent, like a card id: `taxi`.
  final String id;

  /// Which of the app's icons and colours draws the situation's button: one
  /// of [situationIcons], such as `taxi`. The validator refuses any other
  /// key, and Today draws the six buttons only: a sheet with another key
  /// has no button.
  final String icon;

  /// The sheet's title, keyed by the language code of the language it is
  /// written in; English is always there.
  final Map<String, String> title;

  /// The sheet's phrases, by card id, in the order they are shown.
  final List<String> phrases;

  /// The sheet's words, by card id, in the order they are shown.
  final List<String> words;

  /// Every card of the sheet, phrases first.
  List<String> get cardIds => <String>[...phrases, ...words];

  /// The title in the first of [spoken] it is written in, else English.
  String titleFor(Iterable<String> spoken) {
    for (final code in spoken) {
      final text = title[code];
      if (text != null) return text;
    }
    return title['en'] ?? title.values.first;
  }
}

/// The icon keys the app draws, which the validator accepts: the six
/// situations the owner chose first (#724, 2026-10-30), in the order of
/// Today's buttons.
const List<String> situationIcons = <String>[
  'taxi',
  'shops',
  'eat',
  'doctor',
  'traffic',
  'rail',
];

/// A language's situations file: its situations, in the file's order.
class SituationsFile {
  const SituationsFile({required this.languageCode, required this.situations});

  /// The language the sheets teach, by its `language.code`.
  final String languageCode;

  final List<Situation> situations;

  /// The situation drawn with [icon], or null.
  Situation? withIcon(String icon) {
    for (final situation in situations) {
      if (situation.icon == icon) return situation;
    }
    return null;
  }

  /// The situation with [id], or null.
  Situation? byId(String id) {
    for (final situation in situations) {
      if (situation.id == id) return situation;
    }
    return null;
  }
}
