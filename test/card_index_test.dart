// The Decks search's FTS5 index (#527, ADR-0049): what it retrieves, that it
// never leaves out a card the matcher would accept, and that a SQLite
// without FTS5 means no index rather than a failure.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/search/card_index.dart';
import 'package:fluenough/core/search/fts_connection.dart';
import 'package:fluenough/core/search/fuzzy.dart';

/// A SQLite that has no FTS5: creating the virtual table fails.
class _NoFts implements FtsConnection {
  bool closed = false;

  @override
  void execute(String sql, [List<Object?> parameters = const <Object?>[]]) {
    if (sql.contains('VIRTUAL TABLE')) throw StateError('no such module: fts5');
  }

  @override
  void executeMany(String sql, Iterable<List<Object?>> rows) {}

  @override
  List<List<Object?>> select(
    String sql, [
    List<Object?> parameters = const <Object?>[],
  ]) => const <List<Object?>>[];

  @override
  void close() => closed = true;
}

void main() {
  final cards = <IndexedFields>[
    (card: 'a', fields: <String>['water', 'pani', 'to drink water']),
    (card: 'b', fields: <String>['later', 'you']),
    (card: 'c', fields: <String>['cut', 'kaatna']),
    (card: 'd', fields: <String>['travel', 'safar']),
  ];

  group('without FTS5', () {
    test('there is no index, and the connection is closed', () {
      final fake = _NoFts();
      expect(CardSearchIndex.tryOpen(connection: fake), isNull);
      expect(fake.closed, isTrue);
    });
  });

  // A host SQLite older than 3.34 has no trigram tokenizer: the fallback
  // above is what the app does there, and there is nothing to retrieve.
  final probe = CardSearchIndex.tryOpen();
  final skip = probe == null ? 'no FTS5 trigram on this SQLite' : null;
  probe?.close();

  group('the FTS5 trigram index', () {
    late CardSearchIndex index;
    setUp(() {
      index = CardSearchIndex.tryOpen()!;
      index.addDeck('deck', cards);
    });
    tearDown(() => index.close());

    test('an exact word finds the cards holding it', () {
      expect(index.candidates(<String>['water'], typos: false), <String>{'a'});
      // A piece of a word is found too, as the matcher finds it.
      expect(index.candidates(<String>['ater'], typos: false), <String>{
        'a',
        'b',
      });
    });

    test('every word must be held, in any field', () {
      expect(
        index.candidates(<String>['water', 'pani'], typos: false),
        <String>{'a'},
      );
      expect(
        index.candidates(<String>['water', 'safar'], typos: false),
        isEmpty,
      );
    });

    test('a typo finds the card by shared pieces or by edit distance', () {
      expect(index.candidates(<String>['travl'], typos: true), contains('d'));
      // Swapped letters share no three-letter piece with the word.
      expect(index.candidates(<String>['wtaer'], typos: true), contains('a'));
      expect(index.candidates(<String>['wtaer'], typos: false), isEmpty);
    });

    test('a word too short to hold a piece does not narrow', () {
      expect(index.candidates(<String>['wa'], typos: false), isNull);
      expect(index.candidates(<String>['cat'], typos: true), isNull);
    });

    test('a deck added again replaces its cards', () {
      index.addDeck('deck', <IndexedFields>[
        (card: 'z', fields: <String>['river']),
      ]);
      expect(index.hasDeck('deck'), isTrue);
      expect(index.candidates(<String>['water'], typos: false), isEmpty);
      expect(index.candidates(<String>['river'], typos: false), <String>{'z'});
    });

    test('quotes in a word are only text', () {
      expect(index.candidates(<String>['wa"ter'], typos: false), isEmpty);
    });

    test('it never leaves out a card the matcher accepts', () {
      final queries = <String>[
        'water',
        'ater',
        'wate',
        'later',
        'travl',
        'trvel',
        'wtaer',
        'yuo',
        'you',
        'drink',
        'drnk',
        'kaatna',
        'katna',
        'cut',
        'cat',
        'safr',
        'pani',
        'pnai',
      ];
      for (final typos in <bool>[false, true]) {
        for (final word in queries) {
          final accepted = <String>{
            for (final c in cards)
              if (matchWord(word, c.fields, typos: typos) != null) c.card,
          };
          final found = index.candidates(<String>[word], typos: typos);
          if (found != null) {
            expect(
              found.containsAll(accepted),
              isTrue,
              reason: '"$word" typos=$typos: $accepted not in $found',
            );
          }
        }
      }
    });
  }, skip: skip);
}
