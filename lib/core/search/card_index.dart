/// The Decks search's SQLite FTS5 index (#527, ADR-0049), free of Flutter.
///
/// It is the first of the mockup's two steps, retrieval: an FTS5 table with
/// the `trigram` tokenizer holds each card's searchable text, so that "which
/// cards hold this word" is an index lookup and not a scan of every card.
/// The second step, the decision, stays in Dart (`fuzzy.dart`): the index
/// only ever narrows the cards to those that *could* match, a superset of
/// what the matcher accepts, and the matcher then ranks and filters them
/// exactly as it does without an index. So the results are the same with or
/// without it; the index only makes them cheaper.
///
/// * Exact words: a trigram table finds any substring of three letters or
///   more, which is what the matcher's exact steps are.
/// * Typos: the cards that share a trigram with the word, and the cards
///   holding a known word within the allowed edit distance of it (the
///   known words are kept in a `vocab` table), by [allowedTypos].
/// * A word of fewer than three letters, which a trigram cannot hold, does
///   not narrow anything, nor does a three-letter word with typos allowed,
///   which may mean a word of two letters.
///
/// The index lives in memory, is built from the decks as they are searched
/// and is never a source of truth: it is rebuilt from the decks on every
/// launch, and a deck added again replaces its rows.
///
/// Since the deck kinds (wiki/Plan-Deck-Kinds-And-Topics.md, D10, T16) its one
/// table is `items(text, item, kind, parent, language, level)`: a row is a card
/// (kind `cards`, or the genre's search kind for a culture, proverbs or
/// multi-word card) or any other searchable item (a deck, a unit, a grammar
/// concept, a topic, a situation sheet), told apart by a search kind that is
/// data (`decks/sections.yaml`). Card rows keep their text and trigram
/// behaviour: [candidates] with no kinds is what it always was, and with
/// [kinds] it narrows to those kinds.
library;

import '../models/level.dart';
import 'fts_connection.dart';
import 'fuzzy.dart';

/// One card's searchable text, in the search's folded form.
typedef IndexedFields = ({String card, List<String> fields});

/// The kind of an ordinary card's rows: the search's "Words" tab.
const String cardsKind = 'cards';

/// One row to put in the index: an item of a search kind, with its text in
/// the search's folded form, one string per field.
class IndexRow {
  const IndexRow({
    required this.item,
    required this.kind,
    required this.fields,
    this.language = '',
    this.level,
  });

  /// The item's id, unique within its parent (a card id, or a prefixed id such
  /// as `deck:es-en-words`).
  final String item;

  /// The search kind (tab) it is found under.
  final String kind;
  final List<String> fields;

  /// The language it belongs to, by code; empty for none.
  final String language;

  /// The lowest level it suits, or null.
  final Level? level;
}

class CardSearchIndex {
  CardSearchIndex._(this._db);

  final FtsConnection _db;
  final Set<String> _decks = <String>{};

  /// Opens an index on [connection] (default: a new in-memory one), or
  /// returns null where FTS5 or its trigram tokenizer is missing, which the
  /// probe finds out by building and querying a one-row table: the search
  /// then runs on the pure-Dart matcher alone.
  static CardSearchIndex? tryOpen({FtsConnection? connection}) {
    final db = connection ?? openFtsConnection();
    if (db == null) return null;
    try {
      db.execute(
        'CREATE VIRTUAL TABLE items USING fts5('
        'text, item UNINDEXED, kind UNINDEXED, parent UNINDEXED, '
        'language UNINDEXED, level UNINDEXED, tokenize = \'trigram\')',
      );
      db.execute(
        'CREATE TABLE vocab(word TEXT PRIMARY KEY, len INTEGER NOT NULL) '
        'WITHOUT ROWID',
      );
      db.execute(
        'INSERT INTO items(text, item, kind, parent, language, level) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['probe', 'probe', cardsKind, 'probe', '', null],
      );
      final found = db.select(
        'SELECT item FROM items WHERE items MATCH ?',
        <Object?>['"rob"'],
      );
      if (found.length != 1) throw StateError('trigram probe failed');
      db.execute('DELETE FROM items WHERE parent = ?', <Object?>['probe']);
      return CardSearchIndex._(db);
    } on Object {
      try {
        db.close();
      } on Object {
        // Nothing to do: there is no index.
      }
      return null;
    }
  }

  /// Whether [parent]'s rows are in the index: a deck's cards under its id.
  bool hasDeck(String parent) => _decks.contains(parent);

  /// Puts [cards] in the index as [deck]'s, in place of any it held before.
  void addDeck(String deck, Iterable<IndexedFields> cards) => replace(deck, [
    for (final c in cards)
      IndexRow(item: c.card, kind: cardsKind, fields: c.fields),
  ]);

  /// Puts [rows] in the index under [parent], in place of any it held before:
  /// a deck's cards under the deck's id, or any other group of items under the
  /// name its caller gives it, such as `group:units:te`.
  void replace(String parent, Iterable<IndexRow> rows) {
    final list = rows.toList();
    _db.execute('BEGIN');
    try {
      if (_decks.contains(parent)) {
        _db.execute('DELETE FROM items WHERE parent = ?', <Object?>[parent]);
      }
      _db.executeMany(
        'INSERT INTO items(text, item, kind, parent, language, level) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <List<Object?>>[
          for (final r in list)
            <Object?>[
              r.fields.join('\n'),
              r.item,
              r.kind,
              parent,
              r.language,
              r.level?.label,
            ],
        ],
      );
      final vocabulary = <String>{
        for (final r in list)
          for (final field in r.fields)
            if (isLatinText(field))
              for (final word in wordsOf(field))
                if (word.length >= 3) word,
      };
      _db.executeMany(
        'INSERT OR IGNORE INTO vocab(word, len) VALUES (?, ?)',
        <List<Object?>>[
          for (final w in vocabulary) <Object?>[w, w.runes.length],
        ],
      );
      _db.execute('COMMIT');
      _decks.add(parent);
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// The ids of the items that could hold every word of [words] (all in
  /// search form), a superset of the items the matcher accepts; null when
  /// no word can narrow the search. With [typos] the items a typo of a word
  /// could mean are included. With [kinds] only the rows of those search
  /// kinds are considered; without, every row, as it was when every row was a
  /// card.
  Set<String>? candidates(
    List<String> words, {
    required bool typos,
    Set<String>? kinds,
  }) {
    Set<String>? result;
    for (final word in words) {
      final found = _forWord(word, typos, kinds);
      if (found == null) continue;
      result = result == null ? found : result.intersection(found);
      if (result.isEmpty) break;
    }
    return result;
  }

  Set<String>? _forWord(String word, bool typos, Set<String>? kinds) {
    if (word.runes.length < 3) return null;
    final found = _match(<String>[word], kinds);
    if (!typos || !isLatinText(word)) return found;
    // A word of three letters may mean one of two, which no trigram holds.
    if (word.runes.length == 3) return null;
    found.addAll(_match(trigrams(word), kinds));
    final limit = allowedTypos(word.length);
    final near = <String>[];
    for (final row in _db.select(
      'SELECT word FROM vocab WHERE len BETWEEN ? AND ?',
      <Object?>[word.runes.length - limit, word.runes.length + limit],
    )) {
      final known = row.first as String;
      if (known != word && editDistance(word, known, max: limit) <= limit) {
        near.add(known);
      }
    }
    found.addAll(_match(near, kinds));
    return found;
  }

  /// The items holding any of [pieces], each as a phrase, of [kinds] when
  /// given.
  Set<String> _match(Iterable<String> pieces, Set<String>? kinds) {
    final query = <String>[
      for (final p in pieces) '"${p.replaceAll('"', '""')}"',
    ].join(' OR ');
    if (query.isEmpty) return <String>{};
    final kindList = kinds?.toList() ?? const <String>[];
    final filter = kinds == null
        ? ''
        : ' AND kind IN (${List<String>.filled(kindList.length, '?').join(', ')})';
    if (kinds != null && kinds.isEmpty) return <String>{};
    return <String>{
      for (final row in _db.select(
        'SELECT DISTINCT item FROM items WHERE items MATCH ?$filter',
        <Object?>[query, ...kindList],
      ))
        row.first as String,
    };
  }

  void close() => _db.close();
}
