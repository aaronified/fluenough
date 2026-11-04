import 'dart:typed_data';

/// A small key-value store of bytes that keeps what it is given across
/// restarts: the browser's IndexedDB on the web (`browser_blob_store.dart`),
/// and a plain map in tests. [StoredDownloadedDecks] keeps the downloaded
/// decks and fonts in one (#1012).
///
/// It knows nothing of decks. Any call may throw, as a browser's storage
/// does when it is denied or full; the caller decides what that means.
abstract interface class BlobStore {
  /// Every key held.
  Future<List<String>> keys();

  /// The bytes at [key], or null if there are none.
  Future<Uint8List?> read(String key);

  /// Writes [puts] and removes [deletes] as one step: afterwards either
  /// all of it is held or, if this throws, none of it.
  Future<void> write(
    Map<String, Uint8List> puts, {
    Iterable<String> deletes = const <String>[],
  });

  /// Removes everything.
  Future<void> clear();
}
