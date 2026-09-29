import 'package:drift/drift.dart';

import '../../models/drill_mode.dart';
import '../../models/leech_action.dart';
import 'converters.dart';

/// What the learner did about each leech: Reset, Undo, Set aside, Bring
/// back (#19). Added by migration 3.
///
/// Append-only, like `reviews`, and guarded by the same kind of triggers:
/// undoing an action appends another. Replaying the review log reads it to
/// know which pairs restart and which stay out of sessions.
@DataClassName('LeechActionRow')
class LeechActions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get ts => integer().map(const EpochMs())();

  TextColumn get deckId => text()();

  TextColumn get cardId => text()();

  /// Stored by name, so renaming a [DrillMode] value needs a migration.
  TextColumn get mode => textEnum<DrillMode>()();

  /// Stored by name, so renaming a [LeechActionKind] needs a migration.
  TextColumn get kind => textEnum<LeechActionKind>()();
}
