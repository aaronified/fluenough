/// One short, true thing about a language, shown once a day (#48;
/// docs/DECK-FORMAT.md, "Facts files").
class Fact {
  const Fact({
    required this.id,
    required this.text,
    this.contrast,
    this.tags = const <String>[],
    this.source,
  });

  /// Permanent, like a card id: the app remembers seen facts by it.
  final String id;

  /// The fact in each language it is written in, keyed by language code.
  final Map<String, String> text;

  /// The language this fact compares the learned one with, if any. Shown
  /// only to a learner who speaks it.
  final String? contrast;

  final List<String> tags;
  final String? source;
}

/// A language's facts file: its facts, in the file's order.
class FactsFile {
  const FactsFile({required this.languageCode, required this.facts});

  /// The language the facts are about, by its `language.code`.
  final String languageCode;

  final List<Fact> facts;
}
