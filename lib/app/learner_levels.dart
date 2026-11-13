import '../core/data/course_path.dart';
import '../core/decks/levels.dart';
import '../core/private/private_ids.dart';
import 'deck_catalog.dart';

/// A language's path and what its decks hold, as [LearnerLevels] keeps it.
typedef _LanguageUnits = ({
  List<PlanUnit> plan,
  Set<String> natives,
  Map<String, int> firstUnit,
});

/// The level a learner has reached in each language (wiki
/// Plan-Deck-Kinds-And-Topics.md, D2): the level of the furthest unit of the
/// language's path with a card they have studied, or a unit placement passed
/// whole. Worked out from the catalog as it was loaded, never from the decks a
/// learner is given, so that the level gate over them can never feed back into
/// the level. The cards and units of a catalog are worked out once, and each
/// [levels] call reads only the learner's own progress.
class LearnerLevels {
  LearnerLevels(this.catalog) {
    for (final MapEntry(key: code, value: path)
        in catalog.languagePaths.entries) {
      if (!path.plan.any((unit) => unit.milestone != null)) continue;
      final natives = <String>{};
      final cardsOfCore = <String, Set<String>>{};
      for (final entry in catalog.decks) {
        if (entry.language.code != code) continue;
        final native = entry.deck.native.code;
        natives.add(native);
        final core = coreIdOf(entry.id, code, native);
        if (core == null) continue;
        (cardsOfCore[core] ??= <String>{}).addAll(<String>[
          for (final card in entry.deck.cards) card.id,
        ]);
      }
      _languages[code] = (
        plan: path.plan,
        natives: natives,
        firstUnit: firstUnitOfCards(path.plan, cardsOfCore),
      );
    }
  }

  /// The catalog the units and cards were read from.
  final Catalog catalog;

  final Map<String, _LanguageUnits> _languages = <String, _LanguageUnits>{};

  /// The core id `te-home` of the deck `te-en-home` of [language] taught from
  /// [native], or null for a deck id that does not follow that form.
  static String? coreIdOf(String deckId, String language, String native) {
    final lead = idLanguagePrefix(deckId, language);
    final prefix = '$lead-$native-';
    if (!deckId.startsWith(prefix) || deckId.length == prefix.length) {
      return null;
    }
    return '$lead-${deckId.substring(prefix.length)}';
  }

  /// The level reached in each language that has a path with levels, by code:
  /// [studied] the ids of the cards the learner has a review or a schedule
  /// for, [placedDecks] the ids of the decks placement credited. A language
  /// not in the result has no levels, and no levelled item is offered in it.
  Map<String, Level?> levels({
    required Iterable<String> studied,
    required Set<String> placedDecks,
  }) {
    // A card id starts with its language's code (ADR-0018), or with
    // `fnpd-<code>-` when it is private: group by it once.
    final byLanguage = <String, List<String>>{};
    for (final id in studied) {
      if (id.indexOf('-') <= 0) continue;
      (byLanguage[languageOfId(id)] ??= <String>[]).add(id);
    }
    return <String, Level?>{
      for (final MapEntry(key: code, value: language) in _languages.entries)
        code: learnerLevel(
          language.plan,
          furthestUnit(
            language.plan,
            firstUnit: language.firstUnit,
            studied: byLanguage[code] ?? const <String>[],
            placed: <String>{
              for (final id in placedDecks)
                for (final native in language.natives)
                  ?coreIdOf(id, code, native),
            },
          ),
        ),
    };
  }
}

/// Whether [a] and [b] give every language the same level.
bool sameLevels(Map<String, Level?> a, Map<String, Level?> b) {
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    if (!b.containsKey(key) || b[key] != value) return false;
  }
  return true;
}
