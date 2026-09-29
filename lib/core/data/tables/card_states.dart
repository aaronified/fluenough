import 'package:drift/drift.dart';

import '../../models/drill_mode.dart';
import 'converters.dart';

/// SM-2 scheduling state, keyed by `(deck_id, card_id, mode)`: each skill is
/// scheduled on its own (ADR-0005).
///
/// A derived cache. Every row can be rebuilt by replaying `reviews`, which is
/// why this table may be emptied and refilled and `reviews` may not.
@DataClassName('CardStateRow')
class CardStates extends Table {
  TextColumn get deckId => text()();

  TextColumn get cardId => text()();

  /// Stored by name, so renaming a [DrillMode] value needs a migration.
  TextColumn get mode => textEnum<DrillMode>()();

  IntColumn get intervalDays => integer()();

  RealColumn get easeFactor => real()();

  IntColumn get repetitions => integer()();

  IntColumn get dueAt => integer().map(const EpochMs())();

  IntColumn get lapses => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {deckId, cardId, mode};
}
