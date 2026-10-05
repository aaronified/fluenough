/// How a language is romanised, and the spellings a learner may type for
/// the same sound (#47): `decks/<code>/<code>-romanisation.yaml`.
class Romanisation {
  const Romanisation({
    required this.language,
    required this.scheme,
    required this.equivalents,
    this.standard,
    this.typed = const <(String, String)>[],
  });

  /// The language's code, such as `hi`.
  final String language;

  /// The scheme the decks write their readings in, in a line.
  final String scheme;

  /// The standard whose letters the readings use, `ISO 15919` for the
  /// Indic languages (ADR-0025), or null for plain ASCII.
  final String? standard;

  /// How a reading's letters are typed, such as `ś` as `sh`: each reading is
  /// spelled so, read from the left, longest first, before an answer is
  /// compared with it (ADR-0025). Empty for a scheme in ASCII.
  final List<(String, String)> typed;

  /// Groups of spellings typed for one sound, such as `i`, `ee`, `ii`. The
  /// first of each group is the one the decks use.
  final List<List<String>> equivalents;
}
