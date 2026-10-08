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

  /// The grade, 0 to 5. FSRS reads it as a rating (`Fsrs.ratingOf`).
  IntColumn get grade => integer()();

  IntColumn get elapsedMs => integer()();

  /// What was typed, for a machine-graded mode. Null for recognition.
  TextColumn get answerGiven => text().nullable()();

  /// Null on the pair's first review.
  IntColumn get intervalBefore => integer().nullable()();

  IntColumn get intervalAfter => integer()();

  /// SM-2's ease, for the rows written before FSRS (migration 5). Since,
  /// [easeBefore] is null and [easeAfter] is 0, meaning "not SM-2".
  RealColumn get easeBefore => real().nullable()();

  RealColumn get easeAfter => real()();

  /// FSRS's stability after this review, in days. Added by migration 5:
  /// null on the rows written before it.
  RealColumn get stabilityAfter => real().nullable()();

  /// FSRS's difficulty after this review, 1 to 10. Added by migration 5:
  /// null on the rows written before it.
  RealColumn get difficultyAfter => real().nullable()();

  @override
  List<String> get customConstraints => const <String>[
    'CHECK (grade BETWEEN 0 AND 5)',
  ];
}
