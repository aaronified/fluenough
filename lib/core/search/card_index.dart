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
library;

import 'fts_connection.dart';
import 'fuzzy.dart';

/// One card's searchable text, in the search's folded form.
typedef IndexedFields = ({String card, List<String> fields});

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
        'CREATE VIRTUAL TABLE cards USING fts5('
        'text, card UNINDEXED, deck UNINDEXED, tokenize = \'trigram\')',
      );
      db.execute(
        'CREATE TABLE vocab(word TEXT PRIMARY KEY, len INTEGER NOT NULL) '
        'WITHOUT ROWID',
      );
      db.execute(
        'INSERT INTO cards(text, card, deck) VALUES (?, ?, ?)',
        <Object?>['probe', 'probe', 'probe'],
      );
      final found = db.select(
        'SELECT card FROM cards WHERE cards MATCH ?',
        <Object?>['"rob"'],
      );
      if (found.length != 1) throw StateError('trigram probe failed');
      db.execute('DELETE FROM cards WHERE deck = ?', <Object?>['probe']);
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

  /// Whether [deck]'s cards are in the index.
  bool hasDeck(String deck) => _decks.contains(deck);

  /// Puts [cards] in the index as [deck]'s, in place of any it held before.
  void addDeck(String deck, Iterable<IndexedFields> cards) {
    _db.execute('BEGIN');
    try {
      if (_decks.contains(deck)) {
        _db.execute('DELETE FROM cards WHERE deck = ?', <Object?>[deck]);
      }
      _db.executeMany(
        'INSERT INTO cards(text, card, deck) VALUES (?, ?, ?)',
        <List<Object?>>[
          for (final c in cards) <Object?>[c.fields.join('\n'), c.card, deck],
        ],
      );
      final vocabulary = <String>{
        for (final c in cards)
          for (final field in c.fields)
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
      _decks.add(deck);
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// The ids of the cards that could hold every word of [words] (all in
  /// search form), a superset of the cards the matcher accepts; null when
  /// no word can narrow the search. With [typos] the cards a typo of a word
  /// could mean are included.
  Set<String>? candidates(List<String> words, {required bool typos}) {
    Set<String>? result;
    for (final word in words) {
      final found = _forWord(word, typos);
      if (found == null) continue;
      result = result == null ? found : result.intersection(found);
      if (result.isEmpty) break;
    }
    return result;
  }

  Set<String>? _forWord(String word, bool typos) {
    if (word.runes.length < 3) return null;
    final found = _match(<String>[word]);
    if (!typos || !isLatinText(word)) return found;
    // A word of three letters may mean one of two, which no trigram holds.
    if (word.runes.length == 3) return null;
    found.addAll(_match(trigrams(word)));
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
    found.addAll(_match(near));
    return found;
  }

  /// The cards holding any of [pieces], each as a phrase.
  Set<String> _match(Iterable<String> pieces) {
    final query = <String>[
      for (final p in pieces) '"${p.replaceAll('"', '""')}"',
    ].join(' OR ');
    if (query.isEmpty) return <String>{};
    return <String>{
      for (final row in _db.select(
        'SELECT DISTINCT card FROM cards WHERE cards MATCH ?',
        <Object?>[query],
      ))
        row.first as String,
    };
  }

  void close() => _db.close();
}
