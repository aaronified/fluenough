import 'dart:collection';
import 'dart:typed_data';

import '../core/decks/sha256.dart';
import 'blob_store.dart';

/// Pictures kept for the culture screens: creators' portraits now, works'
/// posters later (wiki/Plan-Culture-Media.md, work package 4a, ADR-0060).
///
/// Two layers, both bounded:
///
/// - **On disk** (or in the browser's IndexedDB), through a [BlobStore]: one
///   binary entry per picture, named by its SHA-256, so a changed picture is
///   a new entry and an old one is never read for it. With no store, or one
///   that is denied or full, pictures are kept in memory only and fetched
///   again the next session.
/// - **In memory**, a least-recently-used map held to [maxEntries] pictures
///   and [maxBytes] bytes. A picture larger than [maxBytes] is returned but
///   not kept. Eviction only drops the bytes the cache holds: a widget that
///   already has them keeps drawing, and the next request reads the disk.
///
/// Every picture is checked against its size and SHA-256: before it is kept
/// (what [load]'s fetch returns), and when it is read back from the store
/// the first time this session. An entry that does not match is deleted and
/// fetched again. Requests for one picture that overlap share one read and
/// one fetch. Nothing here throws: a failure is reported to [onProblem] and
/// reads as "no picture".
class MediaImageCache {
  MediaImageCache({
    this.store,
    this.maxEntries = 32,
    this.maxBytes = 24 * 1024 * 1024,
    this.onProblem,
  });

  /// Where pictures are kept between sessions, or null for memory only.
  final BlobStore? store;

  /// The most pictures held in memory.
  final int maxEntries;

  /// The most bytes of pictures held in memory.
  final int maxBytes;

  /// Hears of each failure, in words for the log.
  final void Function(String problem)? onProblem;

  /// Where an entry is kept: `media-<sha256>.bin`.
  static String keyOf(String sha256) => 'media-$sha256.bin';

  // Insertion order is recency: the first entry is the least recently used.
  final LinkedHashMap<String, Uint8List> _memory =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List?>> _jobs = <String, Future<Uint8List?>>{};
  int _memoryBytes = 0;
  bool _persisting = true;

  /// How many pictures are held in memory.
  int get entries => _memory.length;

  /// How many bytes the pictures held in memory take.
  int get bytes => _memoryBytes;

  /// Whether [sha256]'s picture is held in memory.
  bool holds(String sha256) => _memory.containsKey(sha256);

  /// The picture with [sha256] and [size] bytes: from memory, else the
  /// store, else [fetch], whose bytes are checked and then kept. Null when
  /// none of these gives a picture that matches.
  Future<Uint8List?> load(
    String sha256,
    int size,
    Future<Uint8List?> Function() fetch,
  ) {
    final held = _memory.remove(sha256);
    if (held != null) {
      _memory[sha256] = held;
      return Future<Uint8List?>.value(held);
    }
    return _jobs[sha256] ??= _read(sha256, size, fetch).whenComplete(() {
      // A block body: returning the removed job would make this wait on
      // itself for ever.
      _jobs.remove(sha256);
    });
  }

  Future<Uint8List?> _read(
    String sha256,
    int size,
    Future<Uint8List?> Function() fetch,
  ) async {
    final kept = store;
    if (kept != null && _persisting) {
      try {
        final bytes = await kept.read(keyOf(sha256));
        if (bytes != null) {
          if (_matches(bytes, sha256, size)) return _hold(sha256, bytes);
          onProblem?.call(
            'Kept picture does not match, fetched again: $sha256',
          );
          await _delete(<String>[keyOf(sha256)]);
        }
      } on Object catch (e) {
        _giveUp('a kept picture could not be read: $e');
      }
    }
    Uint8List? fetched;
    try {
      fetched = await fetch();
    } on Object catch (e) {
      onProblem?.call('A picture could not be fetched: $e');
      return null;
    }
    if (fetched == null) return null;
    if (!_matches(fetched, sha256, size)) {
      onProblem?.call('A fetched picture does not match its hash: $sha256');
      return null;
    }
    if (kept != null && _persisting) {
      try {
        await kept.write(<String, Uint8List>{keyOf(sha256): fetched});
      } on Object catch (e) {
        // Shown this session, fetched again the next.
        _giveUp('a picture could not be kept: $e');
      }
    }
    return _hold(sha256, fetched);
  }

  bool _matches(Uint8List bytes, String sha256, int size) =>
      bytes.length == size && sha256Hex(bytes) == sha256;

  Uint8List _hold(String sha256, Uint8List bytes) {
    if (bytes.length > maxBytes) return bytes;
    final old = _memory.remove(sha256);
    if (old != null) _memoryBytes -= old.length;
    _memory[sha256] = bytes;
    _memoryBytes += bytes.length;
    while (_memory.length > maxEntries || _memoryBytes > maxBytes) {
      // Never the picture just held: it is last, and fits alone.
      if (_memory.length <= 1) break;
      final oldest = _memory.keys.first;
      _memoryBytes -= _memory.remove(oldest)!.length;
    }
    return bytes;
  }

  /// Forgets the pictures with [hashes], in memory and in the store: a
  /// course was removed.
  Future<void> remove(Iterable<String> hashes) async {
    final list = hashes.toList();
    for (final sha in list) {
      final old = _memory.remove(sha);
      if (old != null) _memoryBytes -= old.length;
    }
    await _delete(<String>[for (final sha in list) keyOf(sha)]);
  }

  Future<void> _delete(List<String> keys) async {
    final kept = store;
    if (kept == null || !_persisting || keys.isEmpty) return;
    try {
      await kept.write(const <String, Uint8List>{}, deletes: keys);
    } on Object catch (e) {
      _giveUp('kept pictures could not be removed: $e');
    }
  }

  void _giveUp(String problem) {
    _persisting = false;
    onProblem?.call(problem);
  }
}
