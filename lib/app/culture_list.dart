import '../core/decks/weave.dart' show cultureGenres;
import '../core/models/recommendation.dart';
import '../core/search/query.dart' show CultureFilter;
import '../core/search/search_items.dart' show foldForSearch, searchWords;
import 'app_state.dart';
import 'deck_catalog.dart';
import 'item_search.dart' show coreIdOfDeck;

/// One section of the culture list on the Decks screen (approved mockup
/// `culture-in-decks`): the culture decks, or the recommended works of one
/// kind (books, films, songs ...).
class CultureListSection {
  const CultureListSection({
    this.medium,
    this.decks = const <DeckEntry>[],
    this.works = const <Recommendation>[],
  });

  /// The kind of work the section holds, or null for the culture decks.
  final RecommendationMedium? medium;

  final List<DeckEntry> decks;
  final List<Recommendation> works;

  /// How many rows the section has: shown next to its header.
  int get count => decks.length + works.length;
}

/// The culture list of a language: its culture and proverbs decks, then its
/// recommended works by kind. Nothing is left out for the learner's level or
/// script (owner, 2026-11-16).
extension CultureListState on AppState {
  /// The culture and proverbs decks of [language], one for each core deck,
  /// taught from the course's native language where there is a choice.
  List<DeckEntry> cultureDecksIn(String language) {
    try {
      final native = courseNative(language);
      final entries = <DeckEntry>[
        for (final entry in catalogView.decks)
          if (entry.language.code == language &&
              cultureGenres.contains(entry.deck.genre))
            entry,
      ];
      final ordered = <DeckEntry>[
        for (final entry in entries)
          if (entry.deck.native.code == native) entry,
        for (final entry in entries)
          if (entry.deck.native.code != native) entry,
      ];
      final seen = <String>{};
      return <DeckEntry>[
        for (final entry in ordered)
          if (seen.add(coreIdOfDeck(entry) ?? entry.id)) entry,
      ];
    } on Object catch (error, stack) {
      log.error('Culture decks of $language failed: $error\n$stack');
      return const <DeckEntry>[];
    }
  }

  /// The sections of [language]'s culture list that match [query] (every word
  /// of it, accents and case ignored, against the title, reading, deck name,
  /// kind and year); all of them for an empty query. A section with no match
  /// is left out. [mediumName] and [decksName] are the kinds' names as the
  /// learner reads them, which the search also matches.
  List<CultureListSection> cultureListOf(
    String language, {
    String query = '',
    CultureFilter filter = const CultureFilter(),
    required String Function(RecommendationMedium medium) mediumName,
    required String decksName,
  }) {
    try {
      final words = searchWords(query);
      bool matches(Iterable<String?> fields) {
        if (words.isEmpty) return true;
        final haystack = foldForSearch(<String>[
          for (final field in fields) ?field,
        ].join(' '));
        return words.every(haystack.contains);
      }

      final file = catalogView.creators[language];
      final spoken = <String>['en', ...settings.spokenLanguages];
      final creatorWords = searchWords(filter.creator ?? '');
      bool byCreator(Iterable<String> ids) {
        if (creatorWords.isEmpty) return true;
        for (final id in ids) {
          final creator = file?.byId(id);
          final name = foldForSearch(
            '$id ${creator?.nameFor(spoken, target: language).text ?? ''}',
          );
          if (creatorWords.every(name.contains)) return true;
        }
        return false;
      }

      // A deck has no year and no completion: those chips leave decks out.
      final decksAllowed =
          filter.yearFrom == null &&
          filter.done == null &&
          (filter.kind == null || filter.kind == 'proverb');
      bool deckAllowed(DeckEntry entry) {
        if (!decksAllowed) return false;
        if (filter.kind == 'proverb' && entry.deck.genre != 'proverbs') {
          return false;
        }
        return byCreator(<String>{
          for (final card in entry.deck.cards) ...card.creators,
          for (final passage in entry.deck.passages) ...passage.creators,
        });
      }

      bool workAllowed(Recommendation work) {
        if (filter.kind != null && filter.kind != work.medium.name) {
          return false;
        }
        final year = work.year;
        if (filter.yearFrom != null &&
            (year == null ||
                year < filter.yearFrom! ||
                year > filter.yearTo!)) {
          return false;
        }
        if (filter.done != null &&
            recommendationProgress.isCompleted(work.id) != filter.done) {
          return false;
        }
        return byCreator(work.creators);
      }

      final decks = <DeckEntry>[
        for (final entry in cultureDecksIn(language))
          if (deckAllowed(entry) &&
              matches(<String?>[
                entry.deck.name,
                decksName,
                entry.deck.level?.label,
              ]))
            entry,
      ];
      final works = catalogView.recommendations[language]?.recommendations;
      return <CultureListSection>[
        if (decks.isNotEmpty) CultureListSection(decks: decks),
        for (final medium in RecommendationMedium.values)
          if (<Recommendation>[
            for (final work in works ?? const <Recommendation>[])
              if (work.medium == medium &&
                  workAllowed(work) &&
                  matches(<String?>[
                    work.title,
                    work.titleReading,
                    mediumName(medium),
                    work.year?.toString(),
                  ]))
                work,
          ] case final found when found.isNotEmpty)
            CultureListSection(medium: medium, works: found),
      ];
    } on Object catch (error, stack) {
      log.error('Culture list of $language failed: $error\n$stack');
      return const <CultureListSection>[];
    }
  }
}
