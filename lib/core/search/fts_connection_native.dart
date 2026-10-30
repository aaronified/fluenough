import 'package:sqlite3/sqlite3.dart';

import 'fts_connection.dart';

/// An in-memory SQLite database, through the `sqlite3` package, which the
/// app already carries for drift. Null if it cannot be opened.
FtsConnection? openFtsConnection() {
  try {
    return _Native(sqlite3.openInMemory());
  } on Object {
    return null;
  }
}

class _Native implements FtsConnection {
  _Native(this._db);

  final Database _db;

  @override
  void execute(String sql, [List<Object?> parameters = const <Object?>[]]) =>
      _db.execute(sql, parameters);

  @override
  void executeMany(String sql, Iterable<List<Object?>> rows) {
    final statement = _db.prepare(sql);
    try {
      for (final row in rows) {
        statement.execute(row);
      }
    } finally {
      statement.close();
    }
  }

  @override
  List<List<Object?>> select(
    String sql, [
    List<Object?> parameters = const <Object?>[],
  ]) => _db.select(sql, parameters).rows;

  @override
  void close() => _db.close();
}
