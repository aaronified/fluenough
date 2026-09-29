import 'package:drift/drift.dart';

import '../../models/drill_mode.dart';
import 'converters.dart';

/// The review log: one row per answered card, never updated or deleted
/// (AGENTS.md rule 9, ADR-0005).
///
/// Everything the app knows about a learner's progress derives from this
/// table, and it is the only one whose loss cannot be repaired. The schema
/// refuses any UPDATE or DELETE on it (see `AppDatabase`).
@DataClassName('ReviewRow')
class Reviews extends Table {
  /// Rises with every append, so it orders the log even if the phone's
  /// clock moves backwards.
  IntColumn get id => integer().autoIncrement()();

  /// When the answer was given.
  IntColumn get ts => integer().map(const EpochMs())();

  TextColumn get deckId => text()();

  TextColumn get cardId => text()();

  /// Stored by name, so renaming a [DrillMode] value needs a migration.
  TextColumn get mode => textEnum<DrillMode>()();

  /// The SM-2 grade, 0 to 5.
  IntColumn get grade => integer()();

  IntColumn get elapsedMs => integer()();

  /// What was typed, for a machine-graded mode. Null for recognition.
  TextColumn get answerGiven => text().nullable()();

  /// Null on the pair's first review.
  IntColumn get intervalBefore => integer().nullable()();

  IntColumn get intervalAfter => integer()();

  /// Null on the pair's first review.
  RealColumn get easeBefore => real().nullable()();

  RealColumn get easeAfter => real()();

  @override
  List<String> get customConstraints => const <String>[
    'CHECK (grade BETWEEN 0 AND 5)',
  ];
}
