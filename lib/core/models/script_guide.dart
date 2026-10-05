/// One recurring feature of a script: the thing a native reader sees at
/// once and a learner from English misses, such as Bengali's headline (#30,
/// ADR-0016).
class ScriptFeature {
  const ScriptFeature({
    required this.id,
    required this.name,
    required this.example,
    required this.text,
    this.term,
    this.reading,
    this.ipa,
    this.letters = const <String>[],
  });

  /// Stable, unique in its guide.
  final String id;

  /// The feature in plain English: "The headline".
  final String name;

  /// Its name in the language: "মাত্রা". Null if it has none worth
  /// learning.
  final String? term;

  /// The [term] in the Latin alphabet, "matra", shown under it when Show
  /// romanisation is on, as on a card.
  final String? reading;

  /// How the [term] is said, in the IPA, broad, without slashes (ADR-0025).
  final String? ipa;

  /// One letter, or a short word, that shows it, drawn large.
  final String example;

  /// What to look for, for a beginner from English.
  final String text;

  /// More letters that share it.
  final List<String> letters;
}

/// How a script works, before its letters: read from
/// `decks/<lang>/<lang>-script.yaml`.
class ScriptGuide {
  const ScriptGuide({
    required this.language,
    required this.name,
    required this.intro,
    required this.features,
  });

  /// The language's code, such as `bn`.
  final String language;

  /// The guide's title: "How Bengali script works".
  final String name;

  /// A paragraph before the features.
  final String intro;

  final List<ScriptFeature> features;
}
