/// One reading of a character, by kind (`character.readings`, DECK-FORMAT.md,
/// Character data): the kind is one the deck's [CharacterScheme] names, such
/// as a language's two ways of reading a Han character, and [text] is written
/// in that kind's script.
class CharacterReading {
  const CharacterReading({
    required this.kind,
    required this.text,
    this.reading,
  });

  /// The id of a [CharacterReadingKind] of the deck's scheme.
  final String kind;

  /// The reading, in the kind's script.
  final String text;

  /// [text] romanised, where the learner needs it.
  final String? reading;
}

/// Structured data about the character a card of a script deck teaches
/// (`character`, #1226): its readings by kind, its level in each named
/// scheme, its strokes and its radical. All of it is optional, and none of it
/// is language-specific: the kinds and the schemes are the deck's own data.
class CardCharacter {
  const CardCharacter({
    this.readings = const <CharacterReading>[],
    this.levels = const <String, String>{},
    this.strokes,
    this.radical,
  });

  /// Its readings, in the order the deck gives them.
  final List<CharacterReading> readings;

  /// Its level by scheme id (`level`), the value as text: `{ grade: "1" }`.
  final Map<String, String> levels;

  /// How many strokes it is written with, from 1.
  final int? strokes;

  /// Its radical, one character.
  final String? radical;

  /// The readings of [kind], in order.
  List<CharacterReading> readingsOf(String kind) =>
      List.unmodifiable(readings.where((reading) => reading.kind == kind));
}

/// A kind of reading a deck's characters have (`character_scheme.readings`):
/// its id, its name for each interface language, and the script its readings
/// are written in.
class CharacterReadingKind {
  const CharacterReadingKind({
    required this.id,
    required this.name,
    required this.script,
  });

  final String id;

  /// The kind's name by language code; `en` is always there.
  final Map<String, String> name;

  /// The script id the kind's [CharacterReading.text] is written in.
  final String script;

  /// The name in [language], or English.
  String nameIn(String language) => name[language] ?? name['en'] ?? id;
}

/// A scheme a deck grades its characters by (`character_scheme.levels`): its
/// id, its name for each interface language, and the values it allows, in
/// order, as text. Empty [values] means any.
class CharacterLevelScheme {
  const CharacterLevelScheme({
    required this.id,
    required this.name,
    this.values = const <String>[],
  });

  final String id;
  final Map<String, String> name;
  final List<String> values;

  /// The name in [language], or English.
  String nameIn(String language) => name[language] ?? name['en'] ?? id;
}

/// What a deck says its characters' readings and levels are
/// (`character_scheme`, in the deck's header): the data every card's
/// [CardCharacter] is read against. A language supplies its own kinds and
/// schemes; nothing about any language is in the app.
class CharacterScheme {
  const CharacterScheme({
    this.readings = const <CharacterReadingKind>[],
    this.levels = const <CharacterLevelScheme>[],
  });

  final List<CharacterReadingKind> readings;
  final List<CharacterLevelScheme> levels;

  /// The reading kind with [id], or null.
  CharacterReadingKind? readingKind(String id) =>
      readings.where((kind) => kind.id == id).firstOrNull;

  /// The level scheme with [id], or null.
  CharacterLevelScheme? levelScheme(String id) =>
      levels.where((scheme) => scheme.id == id).firstOrNull;
}
