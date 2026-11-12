import '../core/data/course_path.dart' show LanguagePath, PlanUnit;
import '../core/decks/deck_index.dart' show IndexShelf;
import '../core/models/card.dart';
import '../core/models/deck.dart';
import '../core/models/situation.dart';
import '../core/search/search_items.dart';
import '../core/logs/log_entry.dart' show describeError;
import 'app_state.dart';
import 'deck_catalog.dart';
import 'learner_levels.dart';

/// The typed search's items of one language (deck-kinds plan, D10, T16, T18),
/// built from the catalog: its decks, hidden decks the index lists, path,
/// topics, situation sheets and creators, in an [ItemCorpus]. The Decks tab's
/// own word search finds the plain words, so the corpus holds only what that
/// search does not ([SearchSource.plainCards] is off).
///
/// Built from the catalog with what is above the learner's level still in it
/// ([AppState.catalogWithAboveLevel]): the search lists such an item marked
/// with its level, and the corpus itself never gives a card above the level.
class ItemSearchIndex {
  ItemSearchIndex._({
    required this.language,
    required this.source,
    required this.corpus,
    required this.shelves,
    required this.problems,
    required this._catalog,
  });

  /// Builds the items of [language] from [catalog], for a course taught from
  /// [native] (null: every native language's decks). Never throws: a group
  /// that cannot be indexed is named in [problems] and the rest is used.
  factory ItemSearchIndex.of(
    Catalog catalog,
    String language, {
    String? native,
    List<IndexShelf> shelves = const <IndexShelf>[],
  }) {
    bool ofCourse(DeckEntry entry) =>
        entry.language.code == language &&
        (native == null || entry.deck.native.code == native);
    final source = SearchSource(
      language: language,
      decks: <Deck>[
        for (final entry in catalog.decks)
          if (ofCourse(entry)) entry.deck,
      ],
      addedHidden: <Deck>[
        for (final entry in catalog.hidden)
          if (ofCourse(entry)) entry.deck,
      ],
      shelves: <IndexShelf>[
        for (final shelf in shelves)
          if (shelf.file.language == language) shelf,
      ],
      path: catalog.languagePaths[language],
      topics: catalog.topics[language],
      situations: catalog.situations[language],
      creators: catalog.creators[language],
      sections: catalog.sections,
      themeNames: <String, String>{
        for (final theme in catalog.themes) theme.id: theme.name,
      },
      plainCards: false,
    );
    final corpus = ItemCorpus();
    var problems = const <String>[];
    try {
      problems = indexLanguage(corpus, source);
    } on Object catch (error) {
      problems = <String>['$language search could not be indexed: $error'];
    }
    return ItemSearchIndex._(
      language: language,
      source: source,
      corpus: corpus,
      shelves: source.shelves,
      problems: problems,
      catalog: catalog,
    );
  }

  final String language;
  final SearchSource source;
  final ItemCorpus corpus;
  final List<IndexShelf> shelves;

  /// What could not be indexed, one line each, for the app log.
  final List<String> problems;
  final Catalog _catalog;

  Map<String, Card>? _cards;
  Map<String, DeckEntry>? _cardDecks;

  void _readCards() {
    final cards = <String, Card>{};
    final decks = <String, DeckEntry>{};
    for (final entry in <DeckEntry>[..._catalog.decks, ..._catalog.hidden]) {
      if (entry.language.code != language || entry.deck.genre == null) continue;
      for (final card in entry.deck.cards) {
        cards.putIfAbsent(card.id, () => card);
        decks.putIfAbsent(card.id, () => entry);
      }
    }
    _cards = cards;
    _cardDecks = decks;
  }

  /// The card of a genre deck (culture, proverbs, multi-word verbs, a hidden
  /// deck) by id, or null.
  Card? cardOf(String id) {
    if (_cards == null) _readCards();
    return _cards![id];
  }

  /// The deck a genre deck's card [id] is in, or null.
  DeckEntry? deckOfCard(String id) {
    if (_cardDecks == null) _readCards();
    return _cardDecks![id];
  }

  /// The deck [id] of the course, loaded or added, or null.
  DeckEntry? deckEntry(String id) {
    for (final entry in <DeckEntry>[..._catalog.decks, ..._catalog.hidden]) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// The index's entry for the hidden deck [deckId] (`te-en-health`), or null.
  IndexShelf? shelfOf(String deckId) {
    for (final shelf in shelves) {
      final native = shelf.file.native;
      final core = shelf.deckKey;
      final id = native != null && core.startsWith('$language-')
          ? '$language-$native-${core.substring(language.length + 1)}'
          : core;
      if (id == deckId) return shelf;
    }
    return null;
  }

  /// The language's path, or null.
  LanguagePath? get path => source.path;

  /// The unit of the path an item row's id (`te:3`) names, or null.
  (int, PlanUnit)? unitOf(ItemRow row) {
    final plan = path?.plan;
    if (plan == null) return null;
    final i = int.tryParse(row.id.substring(row.id.indexOf(':') + 1));
    if (i == null || i < 0 || i >= plan.length) return null;
    return (i, plan[i]);
  }

  /// The situation sheet an item row's id (`te:taxi`) names, or null.
  Situation? situationOf(ItemRow row) =>
      source.situations?.byId(row.id.substring(row.id.indexOf(':') + 1));

  /// The grammar concept id an item row's id (`te:te-form`) names.
  String conceptIdOf(ItemRow row) => row.id.substring(row.id.indexOf(':') + 1);
}

/// One search over the typed items, with what the screen says about it.
class ItemSearchResult {
  const ItemSearchResult({
    required this.outcome,
    this.hiddenAbove = 0,
    this.close = false,
  });

  static const ItemSearchResult empty = ItemSearchResult(
    outcome: ItemSearchOutcome.empty,
  );

  /// The results, best first, of every kind but plain words.
  final ItemSearchOutcome outcome;

  /// With "Hide what is above my level" on, how many results it left out.
  final int hiddenAbove;

  /// Everything was found despite a typo.
  final bool close;
}

final Expando<Map<String, _Kept>> _indexes = Expando<Map<String, _Kept>>(
  'itemSearchIndexes',
);

class _Kept {
  _Kept(this.shelves, this.index);

  final List<IndexShelf> shelves;
  final ItemSearchIndex index;
}

/// The typed search over a language's items (T18).
extension ItemSearchState on AppState {
  /// The index of [language]'s items for the course it is learned from. Kept
  /// until the catalog or the index's shelves change.
  ItemSearchIndex itemSearchFor(String language) {
    final catalog = catalogWithAboveLevel;
    final shelves =
        deckDownloads?.index?.language(language)?.shelves ??
        const <IndexShelf>[];
    final byLanguage = _indexes[catalog] ??= <String, _Kept>{};
    final native = courseNative(language);
    final key = '$language|$native';
    final kept = byLanguage[key];
    if (kept != null && identical(kept.shelves, shelves)) return kept.index;
    final index = ItemSearchIndex.of(
      catalog,
      language,
      native: native,
      shelves: shelves,
    );
    for (final problem in index.problems) {
      log.warning('Search items: $problem');
    }
    byLanguage[key] = _Kept(shelves, index);
    return index;
  }

  /// Searches [query] in [language]'s items: exact matches first, and those
  /// found despite a typo only when none is found exactly, unless [exact].
  /// Plain words are not in it (the Decks tab's word search finds them).
  /// Never throws.
  ItemSearchResult searchItems(
    String language,
    String query, {
    bool exact = false,
  }) {
    try {
      final index = itemSearchFor(language);
      final level = levelIn(language);
      final hide = settings.hideAboveLevel;
      ItemSearchOutcome run({required bool typos, required bool hideAbove}) {
        final found = index.corpus.search(
          query,
          languages: <String>{language},
          levelOf: (_) => level,
          hideAbove: hideAbove,
          typos: typos,
          sections: catalogWithAboveLevel.sections,
        );
        return withoutWords(found);
      }

      var typos = false;
      var shown = run(typos: false, hideAbove: hide);
      var all = hide ? run(typos: false, hideAbove: false) : shown;
      if (all.results.isEmpty && !exact) {
        typos = true;
        shown = run(typos: true, hideAbove: hide);
        all = hide ? run(typos: true, hideAbove: false) : shown;
      }
      return ItemSearchResult(
        outcome: shown,
        hiddenAbove: all.results.length - shown.results.length,
        close: typos && all.results.isNotEmpty,
      );
    } on Object catch (error, stack) {
      log.error(describeError('Typed search failed', error, stack));
      return ItemSearchResult.empty;
    }
  }
}

/// [found] without the plain words (`cards` kind), its tabs worked out again.
ItemSearchOutcome withoutWords(ItemSearchOutcome found) {
  final results = <ItemResult>[
    for (final r in found.results)
      if (r.row.kind != ResultKind.cards) r,
  ];
  if (results.length == found.results.length) return found;
  if (results.isEmpty) return ItemSearchOutcome.empty;
  final counts = <String, int>{};
  for (final r in results) {
    counts[r.row.kind] = (counts[r.row.kind] ?? 0) + 1;
  }
  final order = <String>[
    results.first.row.kind,
    for (final tab in found.tabs)
      if (tab.kind != results.first.row.kind && counts.containsKey(tab.kind))
        tab.kind,
  ];
  final rows = <String, String?>{
    for (final tab in found.tabs) tab.kind: tab.row,
  };
  return ItemSearchOutcome(
    results: List<ItemResult>.unmodifiable(results),
    tabs: <SearchTab>[
      for (final kind in order)
        SearchTab(kind: kind, count: counts[kind]!, row: rows[kind]),
    ],
  );
}

/// The core id of a deck of the course (`te-health` for `te-en-health`).
String? coreIdOfDeck(DeckEntry entry) => LearnerLevels.coreIdOf(
  entry.id,
  entry.language.code,
  entry.deck.native.code,
);
