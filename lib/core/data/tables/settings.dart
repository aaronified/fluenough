import 'package:drift/drift.dart';

/// The learner's settings, one row per setting, as text. Added by
/// migration 2.
///
/// Names are permanent, like card ids: renaming one resets it to its
/// default for everyone. The app decides what each value means and falls
/// back to the default for one it cannot read.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get name => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {name};
}
