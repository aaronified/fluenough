import 'app_state.dart';

/// A deck the learner added themselves, as Settings' Your decks lists it.
class OwnDeck {
  const OwnDeck({
    required this.id,
    required this.name,
    required this.cards,
    required this.language,
    required this.native,
  });

  final String id;
  final String name;

  /// How many cards it has.
  final int cards;

  /// The names of the language it teaches and the one it teaches from.
  final String language;
  final String native;
}

/// The decks the learner added (not bundled, not private), from the language
/// directory (ADR-0062, Plan-Lazy-Language-Loading, P-C5): no unit is read to
/// list them.
extension OwnDecksOnState on AppState {
  /// The decks the learner added, in the order the languages and then the
  /// decks come. With Adult content off an adult deck is not one. Read whole,
  /// the decks themselves are listed, as before.
  List<OwnDeck> get ownDecks {
    if (!readsPerLanguage) {
      return <OwnDeck>[
        for (final entry in decks)
          if (!entry.bundled && !entry.private)
            OwnDeck(
              id: entry.id,
              name: entry.deck.name,
              cards: entry.itemCount,
              language: entry.language.name,
              native: entry.deck.native.name,
            ),
      ];
    }
    final adult = settings.adultContent;
    final own = <OwnDeck>[];
    for (final language in languages) {
      final summary = summaryOf(language.code);
      if (summary == null) continue;
      final natives = <String, String>{
        for (final course in summary.courses) course.native: course.nativeName,
      };
      for (final deck in summary.decks) {
        if (deck.hidden || (!adult && deck.adult)) continue;
        if (deck.bundled || deck.private) continue;
        final row = OwnDeck(
          id: deck.id,
          name: deck.name,
          cards: deck.cards,
          language: summary.info.name,
          native: natives[deck.native] ?? deck.native,
        );
        own.add(row);
      }
    }
    return own;
  }
}
