/// The few things the search index asks of SQLite, free of Flutter and of
/// `dart:ffi` (#527, ADR-0049).
///
/// The native implementation is `fts_connection_native.dart`, chosen where
/// `dart:ffi` exists; on the web [openFtsConnection] has none to give and the
/// search runs on the pure-Dart matcher alone.
library;

import 'fts_connection_stub.dart'
    if (dart.library.ffi) 'fts_connection_native.dart'
    as impl;

/// A synchronous connection to a throwaway SQLite database.
abstract interface class FtsConnection {
  /// Runs [sql] with [parameters] and discards what it returns.
  void execute(String sql, [List<Object?> parameters = const <Object?>[]]);

  /// Runs [sql] with each of [rows] as its parameters, in one prepared
  /// statement.
  void executeMany(String sql, Iterable<List<Object?>> rows);

  /// The rows [sql] returns with [parameters], each as its column values.
  List<List<Object?>> select(
    String sql, [
    List<Object?> parameters = const <Object?>[],
  ]);

  /// Closes the database.
  void close();
}

/// An in-memory database, or null where the platform has no native SQLite
/// (the web) or it cannot be opened.
FtsConnection? openFtsConnection() => impl.openFtsConnection();
