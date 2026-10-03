/// How a language is romanised, and the spellings a learner may type for
/// the same sound (#47): `decks/<code>/<code>-romanisation.yaml`.
class Romanisation {
  const Romanisation({
    required this.language,
    required this.scheme,
    required this.equivalents,
  });

  /// The language's code, such as `hi`.
  final String language;

  /// The scheme the decks write their readings in, in a line.
  final String scheme;

  /// Groups of spellings typed for one sound, such as `i`, `ee`, `ii`. The
  /// first of each group is the one the decks use.
  final List<List<String>> equivalents;
}
