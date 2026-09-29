import 'package:drift/drift.dart';

/// Deck content, keyed by `(deck_id, card_id)`.
///
/// Holds no user data: a deck's rows are replaced outright whenever the deck
/// loads, and the whole table can be dropped and rebuilt from the deck files.
@DataClassName('CardRow')
class Cards extends Table {
  TextColumn get deckId => text()();

  TextColumn get cardId => text()();

  /// Where the card sits in its deck, from 0. New cards are introduced in
  /// this order.
  IntColumn get position => integer()();

  /// The text in the language learned.
  TextColumn get target => text()();

  /// Its meaning, in the language the deck is taught from.
  TextColumn get native => text()();

  @override
  Set<Column<Object>> get primaryKey => {deckId, cardId};
}
