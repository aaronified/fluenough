/// What the learner has learned of one language, as the language picker and
/// the Languages page show it: how far they are toward B1 (null where the
/// language's path has no B1 plan) and how many words they have learned.
typedef LearnedFigures = ({double? share, int words});

/// What a [LearnedFigures] was worked out from: the review log's version for
/// the language, what its decks were, and the course it is taught from. A
/// figure whose stamp differs from the current one is stale.
typedef LearnedStamp = (int, Object, String?);

/// The figures of each language, kept with their stamp (ADR-0062,
/// Plan-Lazy-Language-Loading, 4.3): the picker reads them for a language
/// whose unit is not loaded, so that no deck is read to draw a percentage.
class LearnedCache {
  final Map<String, (LearnedStamp, LearnedFigures)> _kept =
      <String, (LearnedStamp, LearnedFigures)>{};

  /// The figures of [language] when they were worked out at [stamp], else
  /// null.
  LearnedFigures? fresh(String language, LearnedStamp stamp) {
    final kept = _kept[language];
    return kept != null && kept.$1 == stamp ? kept.$2 : null;
  }

  /// The figures of [language] as last worked out, stale or not, else null.
  LearnedFigures? last(String language) => _kept[language]?.$2;

  /// Keeps [figures], worked out at [stamp].
  void keep(String language, LearnedStamp stamp, LearnedFigures figures) {
    _kept[language] = (stamp, figures);
  }

  /// How many languages have figures.
  int get length => _kept.length;
}
