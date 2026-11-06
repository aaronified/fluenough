import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'blob_store.dart';

/// IndexedDB, through `dart:js_interop` alone (no package, AGENTS.md rule
/// 6): one database with one object store, every value a byte array.
///
/// Only the browser compiles this file; see `browser_blob_store.dart`.
Future<BlobStore?> openBrowserBlobStore() async {
  try {
    if (_indexedDb == null) return null;
    final store = _IndexedDbStore();
    // Some browsers never answer when storage is denied: give up and keep
    // the decks in memory rather than hold the app at its start.
    await store._handle().timeout(_openTimeout);
    return store;
  } on Object {
    return null;
  }
}

/// Opens the database. [onClosed] is called when the browser closes it
/// (another tab upgrading it, or the browser freeing it), after which the
/// handle is useless.
Future<_Database> _openDatabase(void Function() onClosed) async {
  final request = _indexedDb!.open(_databaseName, 1);
  request.onupgradeneeded = ((JSObject _) {
    (request.result! as _Database).createObjectStore(_storeName);
  }).toJS;
  final database = await _wait(request) as _Database?;
  if (database == null) throw StateError('IndexedDB: no database');
  void closed(JSObject _) {
    try {
      database.close();
    } on Object {
      // Already closed.
    }
    onClosed();
  }

  database.onversionchange = closed.toJS;
  database.onclose = closed.toJS;
  return database;
}

const String _databaseName = 'fluenough_downloads';
const String _storeName = 'blobs';
const Duration _openTimeout = Duration(seconds: 5);

@JS('indexedDB')
external _Factory? get _indexedDb;

extension type _Factory._(JSObject _) implements JSObject {
  external _Request open(String name, int version);
}

extension type _Request._(JSObject _) implements JSObject {
  external JSAny? get result;
  external JSAny? get error;
  external set onsuccess(JSFunction? handler);
  external set onerror(JSFunction? handler);
  external set onupgradeneeded(JSFunction? handler);
}

extension type _Database._(JSObject _) implements JSObject {
  external _Transaction transaction(String store, String mode);
  external _ObjectStore createObjectStore(String name);
  external void close();
  external set onversionchange(JSFunction? handler);
  external set onclose(JSFunction? handler);
}

extension type _Transaction._(JSObject _) implements JSObject {
  external _ObjectStore objectStore(String name);
  external JSAny? get error;
  external void abort();
  external set oncomplete(JSFunction? handler);
  external set onerror(JSFunction? handler);
  external set onabort(JSFunction? handler);
}

extension type _ObjectStore._(JSObject _) implements JSObject {
  external _Request getAllKeys();
  external _Request get(String key);
  external _Request put(JSAny value, String key);
  external _Request delete(String key);
  external _Request clear();
}

/// The request's result, once it succeeds; its error if it fails.
Future<JSAny?> _wait(_Request request) {
  final done = Completer<JSAny?>();
  request.onsuccess = ((JSObject _) {
    if (!done.isCompleted) done.complete(request.result);
  }).toJS;
  request.onerror = ((JSObject _) {
    if (!done.isCompleted) {
      done.completeError(StateError('IndexedDB: ${request.error}'));
    }
  }).toJS;
  return done.future;
}

/// Runs [body] in a read-write transaction, and completes once the browser
/// has committed it. A transaction that is aborted, as when the storage is
/// full, throws and changes nothing.
Future<void> _commit(_Database database, void Function(_ObjectStore) body) {
  final done = Completer<void>();
  final transaction = database.transaction(_storeName, 'readwrite');
  void fail(JSObject _) {
    if (!done.isCompleted) {
      done.completeError(StateError('IndexedDB: ${transaction.error}'));
    }
  }

  transaction.oncomplete = ((JSObject _) {
    if (!done.isCompleted) done.complete();
  }).toJS;
  transaction.onerror = fail.toJS;
  transaction.onabort = fail.toJS;
  try {
    body(transaction.objectStore(_storeName));
  } on Object catch (e) {
    // Part of the body ran: none of it may commit.
    try {
      transaction.abort();
    } on Object {
      // Already finished.
    }
    if (!done.isCompleted) done.completeError(e);
  }
  return done.future;
}

class _IndexedDbStore implements BlobStore {
  _Database? _database;

  /// The open database, opened again if the browser closed it since: one
  /// transient closure does not end the storage for the visit.
  Future<_Database> _handle() async =>
      _database ??= await _openDatabase(() => _database = null);

  Future<_ObjectStore> _readOnly() async => (await _handle())
      .transaction(_storeName, 'readonly')
      .objectStore(_storeName);

  @override
  Future<List<String>> keys() async {
    final result = await _wait((await _readOnly()).getAllKeys());
    if (result == null || !result.isA<JSArray<JSAny?>>()) {
      return const <String>[];
    }
    return <String>[
      for (final key in (result as JSArray<JSAny?>).toDart)
        if (key.isA<JSString>()) (key! as JSString).toDart,
    ];
  }

  @override
  Future<Uint8List?> read(String key) async {
    final result = await _wait((await _readOnly()).get(key));
    if (result == null || !result.isA<JSUint8Array>()) return null;
    return (result as JSUint8Array).toDart;
  }

  @override
  Future<void> write(
    Map<String, Uint8List> puts, {
    Iterable<String> deletes = const <String>[],
  }) async => _commit(await _handle(), (store) {
    for (final key in deletes) {
      store.delete(key);
    }
    for (final MapEntry(:key, :value) in puts.entries) {
      store.put(value.toJS, key);
    }
  });

  @override
  Future<void> clear() async =>
      _commit(await _handle(), (store) => store.clear());
}
