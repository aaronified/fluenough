import 'package:drift/drift.dart';

import '../../models/drill_mode.dart';
import 'converters.dart';

/// FSRS's parameters as fitted to the learner, one row per language and
/// skill (`docs/plans/skill-model.md`). Added by migration 7.
///
/// Not a cache: each fit starts from the one before, so a row cannot be
/// rebuilt from `reviews`. It goes into the backup with the log
/// (docs/LOG-FORMAT.md). A row is replaced by the next fit of its skill.
@DataClassName('FsrsParametersRow')
class FsrsParameters extends Table {
  /// The language learned, as card ids name it: `te` for `te-0053`.
  TextColumn get language => text()();

  /// Stored by name, so renaming a [DrillMode] value needs a migration.
  TextColumn get mode => textEnum<DrillMode>()();

  /// w0 to w20, comma-separated, each as Dart writes a double, which reads
  /// back as the same double.
  TextColumn get parameters => text()();

  IntColumn get fittedAt => integer().map(const EpochMs())();

  /// The skill's reviews in the language when it was fitted.
  IntColumn get reviewCount => integer()();

  /// The log loss on the fit's window of the set in use before, and of the
  /// set fitted. The fitted set is the one kept when its loss is lower.
  RealColumn get lossBefore => real().nullable()();

  RealColumn get lossAfter => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {language, mode};
}
