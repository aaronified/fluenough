import 'package:drift/drift.dart';

import 'converters.dart';

/// Each restore that replaced the review log (#470). Added by migration 8.
///
/// A restore is the one exception to `reviews` and `leech_actions` being
/// append-only (AGENTS.md rule 9; owner, 2026-10-17: "Logged exception"),
/// and this table is its log: when, from which backup, and where the copy
/// of what it replaced was kept. Append-only, guarded by the same kind of
/// triggers, and never cleared by a restore.
@DataClassName('RestoreRow')
class Restores extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// When the restore replaced the log.
  IntColumn get ts => integer().map(const EpochMs())();

  /// The backup restored from: when it was made, what made it (its
  /// `kind`), and the app version that made it.
  IntColumn get backupCreatedAt => integer().map(const EpochMs())();

  TextColumn get backupKind => text()();

  TextColumn get backupAppVersion => text()();

  /// Whether the backup came from a file the learner picked, rather than
  /// from the backups kept on the phone.
  BoolColumn get fromFile => boolean()();

  /// The kept copy of what the restore replaced: its name among the
  /// backups kept on the phone.
  TextColumn get keptCopy => text()();

  /// How many reviews the log held before, and after.
  IntColumn get reviewsBefore => integer()();

  IntColumn get reviewsAfter => integer()();
}
