import 'package:drift/drift.dart';

import 'converters.dart';

/// Placement credit the learner took back (wiki, Plan-Placement-V2, point
/// 17). Added by migration 11.
///
/// Append-only, like `reviews` and `leech_actions`, and guarded by the same
/// kind of triggers: the review log is never edited, so a withdrawal is a
/// record beside it that the replay reads to leave out exactly the credit it
/// names (`isWithdrawnCredit`). Emptied only by a restore, with the log.
@DataClassName('PlacementWithdrawalRow')
class PlacementWithdrawals extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// When it was withdrawn.
  IntColumn get ts => integer().map(const EpochMs())();

  /// The language whose credit it is, by code.
  TextColumn get language => text()();

  /// The credit's moment: the `placed_at` second.
  IntColumn get creditAt => integer()();

  /// The drills of the credit, comma-separated [DrillMode] names.
  TextColumn get modes => text()();

  /// The script of a script skill's credit; null for the word skills'.
  TextColumn get script => text().nullable()();

  /// The decks whose credit it takes back, comma-separated, sorted.
  TextColumn get deckIds => text()();
}
