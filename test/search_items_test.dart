// Search items and kinds (wiki/Plan-Deck-Kinds-And-Topics.md, D10, T16): the
// search finds situations, topics, decks, grammar concepts, units, words,
// culture, proverbs and multi-word verbs, each under a search kind that comes
// from the sections file; typos are tolerated; what is above the learner's
// level is marked (or hidden by the setting) and a card above it never shows;
// a hidden deck is found, before it is added, as a scene of its profession.

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/data/sections.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/level.dart';
import 'package:fluenough/core/models/situation.dart';
import 'package:fluenough/core/search/card_index.dart';
import 'package:fluenough/core/search/search_items.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/kinds_fixture.dart';

final Map<String, String> _files = kindsFixtureFiles();
final Catalog _catalog = DeckCatalog.parseAll(_files);
final DeckSections _sections = _catalog.sections;

/// A sheet and nothing else of the situations file's.
const SituationsFile _sheets = SituationsFile(
  languageCode: 'zz',
  situations: <Situation>[
    Situation(
      id: 'taxi',
      icon: 'taxi',
      title: <String, String>{'en': 'Hailing a cab'},
      phrases: <String>['zz-9001'],
    ),
  ],
);

SearchSource _source({
  bool added = false,
  List<IndexShelf> shelves = const <IndexShelf>[],
}) {
  final decks = <Deck>[for (final e in _catalog.decks) e.deck];
  return SearchSource(
    language: 'zz',
    decks: decks,
    addedHidden: added
        ? <Deck>[for (final e in _catalog.hidden) e.deck]
        : const <Deck>[],
    shelves: shelves,
    path: _catalog.languagePaths['zz'],
    topics: _catalog.topics['zz'],
    situations: _sheets,
    creators: _catalog.creators['zz'],
    sections: _sections,
  );
}

ItemCorpus _corpus(SearchSource source, {required bool fts}) {
  final corpus = ItemCorpus(index: fts ? CardSearchIndex.tryOpen() : null);
  expect(indexLanguage(corpus, source), isEmpty);
  return corpus;
}

Level? Function(String) _level(Level? level) =>
    (_) => level;

void main() {
  final probe = CardSearchIndex.tryOpen();
  final hasFts = probe != null;
  probe?.close();

  group('the kind of an item', () {
    late final ItemCorpus corpus = _corpus(_source(), fts: false);
    String kindOf(String query, SearchItemType type, String id) {
      final found = corpus.search(
        query,
        levelOf: _level(Level.b1),
        sections: _sections,
      );
      return found.results
          .firstWhere((r) => r.row.type == type && r.row.id == id)
          .row
          .kind;
    }

    test('comes from the sections file for a card of a genre deck', () {
      expect(kindOf('agua', SearchItemType.card, 'zz-9002'), 'cards');
      expect(kindOf('darse', SearchItemType.card, 'zz-9501'), 'multiword');
      expect(kindOf('beber', SearchItemType.card, 'zz-9401'), 'proverbs');
      expect(kindOf('ilumina', SearchItemType.card, 'zz-9201'), 'culture');
    });

    test(
      'is decks for a deck, situations for a sheet, topics, units and concepts',
      () {
        expect(
          kindOf('culture', SearchItemType.deck, 'zz-en-culture-ejemplo'),
          'decks',
        );
        expect(
          kindOf('cab', SearchItemType.situation, 'zz:taxi'),
          'situations',
        );
        expect(
          kindOf('conjunct', SearchItemType.topic, 'zz-juktakkhor'),
          'topics',
        );
        expect(kindOf('words', SearchItemType.unit, 'zz:0'), 'units');
      },
    );

    test('finds a culture card by the name of its creator and its work', () {
      expect(
        corpus
            .search('Ejemplo', levelOf: _level(Level.b1), sections: _sections)
            .ofKind('culture')
            .map((r) => r.row.id),
        contains('zz-9201'),
      );
      expect(
        corpus
            .search('Poema', levelOf: _level(Level.b1), sections: _sections)
            .ofKind('culture'),
        isNotEmpty,
      );
    });
  });

  for (final fts in <bool>[false, true]) {
    final how = fts ? 'with the FTS5 index' : 'without an index';
    final skip = fts && !hasFts ? 'no FTS5 trigram on this SQLite' : null;

    group('searching $how', () {
      late ItemCorpus corpus;
      setUp(() => corpus = _corpus(_source(), fts: fts && hasFts));
      tearDown(() => corpus.index?.close());

      test('finds a word despite a typo, and an exact one ranks above it', () {
        final exact = corpus.search(
          'water',
          levelOf: _level(Level.b1),
          sections: _sections,
        );
        final typo = corpus.search(
          'watr',
          levelOf: _level(Level.b1),
          sections: _sections,
        );
        expect(exact.ofKind('cards').map((r) => r.row.id), contains('zz-9002'));
        expect(typo.ofKind('cards').map((r) => r.row.id), contains('zz-9002'));
        expect(typo.ofKind('cards').first.isClose, isTrue);
        expect(exact.ofKind('cards').first.isClose, isFalse);
      }, skip: skip);

      test(
        'gives a tab for each kind with results, the best match\'s first',
        () {
          final found = corpus.search(
            'conjunct',
            levelOf: _level(Level.b1),
            sections: _sections,
          );
          expect(found.openKind, 'topics');
          expect(found.tabs.map((t) => t.kind), <String>['topics']);
          expect(found.tabs.single.row, 'topic');
          expect(found.countOf('topics'), 1);
          expect(found.countOf('cards'), 0);

          final several = corpus.search(
            'words',
            levelOf: _level(Level.b1),
            sections: _sections,
          );
          expect(
            several.tabs.map((t) => t.kind),
            containsAll(<String>['decks', 'units']),
          );
          // The tabs after the first follow the sections file's order.
          final rest = several.tabs.skip(1).map((t) => t.kind).toList();
          expect(
            rest,
            orderedEquals(
              <String>[...rest]..sort((a, b) {
                int order(String k) => _sections.searchKind(k)?.order ?? 1000;
                return order(a).compareTo(order(b));
              }),
            ),
          );
        },
        skip: skip,
      );

      test(
        'marks what is above the level, and never shows a card above it',
        () {
          final a1 = corpus.search(
            'culture',
            levelOf: _level(Level.a1),
            sections: _sections,
          );
          final deck = a1.results.firstWhere(
            (r) =>
                r.row.type == SearchItemType.deck &&
                r.row.id == 'zz-en-culture-ejemplo',
          );
          expect(deck.aboveLevel, isTrue);
          expect(deck.startable, isFalse);
          // A card of a culture deck is never in a result for an A1 learner.
          final cards = corpus.search(
            'ilumina',
            levelOf: _level(Level.a1),
            sections: _sections,
          );
          expect(cards.ofKind('culture'), isEmpty);
          final a2 = corpus.search(
            'culture',
            levelOf: _level(Level.a2),
            sections: _sections,
          );
          expect(
            a2.results
                .firstWhere((r) => r.row.id == 'zz-en-culture-ejemplo')
                .startable,
            isTrue,
          );
          expect(
            corpus
                .search(
                  'ilumina',
                  levelOf: _level(Level.a2),
                  sections: _sections,
                )
                .ofKind('culture'),
            isNotEmpty,
          );
        },
        skip: skip,
      );

      test('removes what is above the level when the setting says so', () {
        final hidden = corpus.search(
          'culture',
          levelOf: _level(Level.a1),
          hideAbove: true,
          sections: _sections,
        );
        expect(
          hidden.results.where((r) => r.row.id == 'zz-en-culture-ejemplo'),
          isEmpty,
        );
        final shown = corpus.search(
          'culture',
          levelOf: _level(Level.a1),
          sections: _sections,
        );
        expect(
          shown.results.where((r) => r.row.id == 'zz-en-culture-ejemplo'),
          isNotEmpty,
        );
      }, skip: skip);

      test(
        'finds nothing for an empty query, and only the kinds asked for',
        () {
          expect(corpus.search('  ', sections: _sections).results, isEmpty);
          expect(
            corpus
                .search(
                  'conjunct',
                  kinds: <String>{'decks'},
                  levelOf: _level(Level.b1),
                  sections: _sections,
                )
                .results,
            isEmpty,
          );
          expect(
            corpus
                .search(
                  'conjunct',
                  kinds: <String>{'topics'},
                  levelOf: _level(Level.b1),
                  sections: _sections,
                )
                .results,
            hasLength(1),
          );
        },
        skip: skip,
      );
    });
  }

  group('a hidden deck', () {
    final shelves = DeckIndex.parse(indexFor(kindsFixtureFiles(language: 'zz')))
        .language('zz')!
        .shelves;
    final notOnPhone = DeckCatalog.parseAll(<String, String>{
      for (final e in _files.entries)
        if (!e.key.contains('medicine-registro')) e.key: e.value,
    });

    ItemCorpus corpusWithoutDeck() {
      final decks = <Deck>[for (final e in notOnPhone.decks) e.deck];
      final corpus = ItemCorpus();
      indexLanguage(
        corpus,
        SearchSource(
          language: 'zz',
          decks: decks,
          shelves: shelves,
          sections: _sections,
        ),
      );
      return corpus;
    }

    test('is found from the index alone, as a scene of its profession', () {
      final found = corpusWithoutDeck().search(
        'medicine',
        levelOf: _level(Level.b1),
        sections: _sections,
      );
      final row = found.ofKind('situations').single;
      expect(row.row.type, SearchItemType.deck);
      expect(row.row.hidden, isTrue);
      expect(row.row.id, 'zz-en-medicine-registro');
      expect(found.ofKind('cards'), isEmpty);
    });

    test('is marked above an A2 learner\'s level, and not startable', () {
      final found = corpusWithoutDeck().search(
        'medicine',
        levelOf: _level(Level.a2),
        sections: _sections,
      );
      expect(found.ofKind('situations').single.aboveLevel, isTrue);
      expect(
        corpusWithoutDeck()
            .search(
              'medicine',
              levelOf: _level(Level.a2),
              hideAbove: true,
              sections: _sections,
            )
            .results,
        isEmpty,
      );
    });

    test(
      'once added is found by its cards, as its own row and never as a word',
      () {
        final corpus = _corpus(
          _source(added: true, shelves: shelves),
          fts: false,
        );
        final found = corpus.search(
          'registrarme',
          levelOf: _level(Level.b1),
          sections: _sections,
        );
        final row = found.results.single;
        expect(row.row.kind, 'situations');
        expect(row.row.type, SearchItemType.deck);
        expect(row.snippetCard, 'zz-9601');
        expect(found.ofKind('cards'), isEmpty);
        // The shelf and the added deck are one row, not two.
        expect(
          corpus
              .search(
                'medicine',
                levelOf: _level(Level.b1),
                sections: _sections,
              )
              .results
              .where((r) => r.row.id == 'zz-en-medicine-registro'),
          hasLength(1),
        );
      },
    );
  });

  group('the index behind it', () {
    final skip = hasFts ? null : 'no FTS5 trigram on this SQLite';

    test(
      'narrows to the kinds asked for and keeps card behaviour as it was',
      () {
        final index = CardSearchIndex.tryOpen()!;
        addTearDown(index.close);
        index.addDeck('deck', <IndexedFields>[
          (card: 'a', fields: <String>['water']),
        ]);
        index.replace('group:topics:zz', <IndexRow>[
          const IndexRow(
            item: 'topic:t',
            kind: 'topics',
            fields: <String>['water cycle'],
          ),
        ]);
        expect(index.candidates(<String>['water'], typos: false), <String>{
          'a',
          'topic:t',
        });
        expect(
          index.candidates(
            <String>['water'],
            typos: false,
            kinds: <String>{'topics'},
          ),
          <String>{'topic:t'},
        );
        expect(
          index.candidates(
            <String>['water'],
            typos: false,
            kinds: <String>{cardsKind},
          ),
          <String>{'a'},
        );
        // A group added again replaces its rows.
        index.replace('group:topics:zz', const <IndexRow>[]);
        expect(index.candidates(<String>['water'], typos: false), <String>{
          'a',
        });
      },
      skip: skip,
    );
  });
}
