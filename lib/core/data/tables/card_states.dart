import 'package:drift/drift.dart';

import '../../models/drill_mode.dart';
import 'converters.dart';

/// FSRS scheduling state, keyed by `(card_id, mode)`: each skill is
/// scheduled on its own (ADR-0005), and a card has one schedule in every deck
/// that lists it (ADR-0018).
///
/// A derived cache. Every row can be rebuilt by replaying `reviews`, which is
/// why this table may be emptied and refilled and `reviews` may not.
@DataClassName('CardStateRow')
class CardStates extends Table {
  TextColumn get cardId => text()();

  /// Stored by name, so renaming a [DrillMode] value needs a migration.
  TextColumn get mode => textEnum<DrillMode>()();

  RealColumn get stability => real()();

  RealColumn get difficulty => real()();

  IntColumn get intervalDays => integer()();

  IntColumn get repetitions => integer()();

  IntColumn get dueAt => integer().map(const EpochMs())();

  IntColumn get lastReviewAt => integer().map(const EpochMs())();

  IntColumn get lapses => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {cardId, mode};
}
