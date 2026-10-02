import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import '../models/leech_action.dart';
import 'database.dart';
import 'tables/card_states.dart';
import 'tables/cards.dart';
import 'tables/decks.dart';
import 'tables/leech_actions.dart';
import 'tables/reviews.dart';
import 'tables/settings.dart';

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
  Future<CardStateRow?> of(String cardId, DrillMode mode) =>
      (select(cardStates)
            ..where((s) => s.cardId.equals(cardId) & s.mode.equalsValue(mode)))
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

/// The learner's settings, by name.
@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  /// Every stored setting, by name.
  Future<Map<String, String>> all() async => <String, String>{
    for (final row in await select(settings).get()) row.name: row.value,
  };

  /// Stores [value] under [name], replacing what was there.
  Future<void> put(String name, String value) => into(
    settings,
  ).insertOnConflictUpdate(SettingsCompanion.insert(name: name, value: value));
}

/// What the learner did about leeches. Append-only: it can add an action and
/// read them, and nothing else; the schema refuses the rest.
@DriftAccessor(tables: [LeechActions])
class LeechActionsDao extends DatabaseAccessor<AppDatabase>
    with _$LeechActionsDaoMixin {
  LeechActionsDao(super.attachedDatabase);

  /// Appends [action].
  Future<void> append(LeechAction action) => into(leechActions).insert(
    LeechActionsCompanion.insert(
      ts: action.at,
      // The pair is a card and a mode, in whichever deck (ADR-0018); the
      // column stays, unused, since this table is append-only.
      deckId: '',
      cardId: action.key.cardId,
      mode: action.key.mode,
      kind: action.kind,
    ),
  );

  /// Every action, in the order it was appended.
  Future<List<LeechAction>> all() async => <LeechAction>[
    for (final row in await (select(
      leechActions,
    )..orderBy([(a) => OrderingTerm.asc(a.id)])).get())
      LeechAction(
        at: row.ts,
        key: (cardId: row.cardId, mode: row.mode),
        kind: row.kind,
      ),
  ];
}
