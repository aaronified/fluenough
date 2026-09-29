import 'package:drift/drift.dart';

import 'converters.dart';

/// Metadata for each loaded deck, keyed by deck id.
///
/// Holds no user data: it is rebuilt from the deck files whenever they load.
@DataClassName('DeckRow')
class Decks extends Table {
  /// The deck id, such as `hi-en-market`.
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// `vocab` or `grammar`.
  TextColumn get kind => text()();

  /// The language learned, by its `language.code`.
  TextColumn get languageCode => text()();

  /// The language the deck is taught from, by its `native.code`.
  TextColumn get nativeCode => text()();

  /// When the deck's files were last read into this database.
  IntColumn get loadedAt => integer().map(const EpochMs())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
