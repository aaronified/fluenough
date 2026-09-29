import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import 'database.dart';
import 'tables/card_states.dart';
import 'tables/cards.dart';
import 'tables/decks.dart';
import 'tables/reviews.dart';

part 'daos.g.dart';

/// The loaded decks' metadata.
@DriftAccessor(tables: [Decks])
class DecksDao extends DatabaseAccessor<AppDatabase> with _$DecksDaoMixin {
  DecksDao(super.attachedDatabase);

  /// Adds [deck], or replaces the row with its id.
  Future<void> put(DecksCompanion deck) =>
      into(decks).insertOnConflictUpdate(deck);

  Future<DeckRow?> byId(String id) =>
      (select(decks)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// Every deck, by id.
  Future<List<DeckRow>> all() =>
      (select(decks)..orderBy([(d) => OrderingTerm.asc(d.id)])).get();
}

/// Deck content. It holds no user data, so a deck's cards are replaced
/// outright rather than merged.
@DriftAccessor(tables: [Cards])
class CardsDao extends DatabaseAccessor<AppDatabase> with _$CardsDaoMixin {
  CardsDao(super.attachedDatabase);

  /// Makes [rows] the whole of [deckId]'s content, in one transaction.
  Future<void> replaceDeck(String deckId, List<CardsCompanion> rows) =>
      transaction(() async {
        await (delete(cards)..where((c) => c.deckId.equals(deckId))).go();
        await batch((b) => b.insertAll(cards, rows));
      });

  /// [deckId]'s cards, in deck order.
  Future<List<CardRow>> ofDeck(String deckId) =>
      (select(cards)
            ..where((c) => c.deckId.equals(deckId))
            ..orderBy([(c) => OrderingTerm.asc(c.position)]))
          .get();
}

/// Scheduling state per `(deck, card, mode)`: a cache that replaying
/// `reviews` rebuilds.
@DriftAccessor(tables: [CardStates])
class CardStatesDao extends DatabaseAccessor<AppDatabase>
    with _$CardStatesDaoMixin {
  CardStatesDao(super.attachedDatabase);

  /// Adds [state], or replaces the row for its pair.
  Future<void> put(CardStatesCompanion state) =>
      into(cardStates).insertOnConflictUpdate(state);

  /// One pair's state, or null if it has never been reviewed.
  Future<CardStateRow?> of(String deckId, String cardId, DrillMode mode) =>
      (select(cardStates)..where(
            (s) =>
                s.deckId.equals(deckId) &
                s.cardId.equals(cardId) &
                s.mode.equalsValue(mode),
          ))
          .getSingleOrNull();

  Future<List<CardStateRow>> all() => select(cardStates).get();

  /// Empties the cache, for a rebuild from `reviews`. Never call it without
  /// refilling it in the same transaction.
  Future<void> clear() => delete(cardStates).go();
}

/// The review log. It can add a review and read them, and has no way to
/// change or remove one (AGENTS.md rule 9); the schema refuses that too.
@DriftAccessor(tables: [Reviews])
class ReviewsDao extends DatabaseAccessor<AppDatabase> with _$ReviewsDaoMixin {
  ReviewsDao(super.attachedDatabase);

  /// Appends [review] and returns its id.
  Future<int> append(ReviewsCompanion review) => into(reviews).insert(review);

  /// Every review, in the order it was appended.
  Future<List<ReviewRow>> all() =>
      (select(reviews)..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
}
