import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/decks/deck_index.dart';
import '../core/decks/sha256.dart';
import 'blob_store.dart';
import 'downloaded_decks.dart';

/// [DownloadedDecks] that survive a reload: the web build's downloaded decks
/// and script fonts, kept in a [BlobStore] (the browser's IndexedDB) as well
/// as in memory (#1012).
///
/// The working copy is a [MemoryDownloadedDecks], read whole when the app
/// starts ([load]); every change is written through to the store. The store
/// is only ever a copy, so it can fail in any way without breaking the app:
///
/// - **No store, or one that is denied or full** (a private window, a quota):
///   the first failed read or write turns persisting off for the rest of the
///   session and the decks stay in memory, as before this existed. A write is
///   one step ([BlobStore.write]), so a failure leaves the store as it was.
/// - **Another version's data**: what is stored carries a [schemaVersion]; a
///   store with any other is emptied, and the decks are downloaded again.
/// - **A damaged entry**: a file or font whose bytes are missing, or do not
///   match the size and SHA-256 the index gave it, is dropped, and so is
///   what the manifest does not list. The downloads see it as never
///   downloaded and fetch it again.
/// - **Too much**: the files and fonts kept are bounded by [maxBytes]; the
///   oldest written are removed from the store first. They stay in memory
///   for the session.
///
/// What DeckDownloads keeps in notes (the index it last read, when it
/// checked, which languages are complete) is kept too, so a reload opens
/// with the index it had, checks it against GitHub at most once a day as
/// ever, and downloads only the files whose SHA-256 changed.
class StoredDownloadedDecks implements DownloadedDecks {
  StoredDownloadedDecks._(this._store, this.maxBytes, this._onProblem);

  /// The version of what is stored. Bump it when the layout changes: older
  /// data is then dropped, not read.
  static const int schemaVersion = 1;

  /// How many bytes of deck files and fonts are kept, by default.
  static const int defaultMaxBytes = 64 * 1024 * 1024;

  static const String _schemaKey = 'schema';
  static const String _manifestKey = 'manifest';
  static const String _filePrefix = 'file/';
  static const String _fontPrefix = 'font/';
  static const String _notePrefix = 'note/';

  /// Reads what [store] holds into memory. With a null [store], or any
  /// failure of it, the decks are kept in memory only. [onProblem] hears of
  /// each failure, in words for the log.
  static Future<StoredDownloadedDecks> load(
    BlobStore? store, {
    int maxBytes = defaultMaxBytes,
    void Function(String problem)? onProblem,
  }) async {
    final decks = StoredDownloadedDecks._(store, maxBytes, onProblem);
    if (store == null) return decks;
    try {
      await decks._read(store);
    } on Object catch (e) {
      decks._giveUp('could not read the stored decks: $e');
    }
    return decks;
  }

  final BlobStore? _store;
  final void Function(String problem)? _onProblem;

  /// The most bytes of files and fonts kept in the store.
  final int maxBytes;

  final MemoryDownloadedDecks _memory = MemoryDownloadedDecks();

  /// What the store holds, by path: the index's entry for it, and its
  /// order of writing, for [maxBytes]. A file evicted from the store is not
  /// here, and is still in [_memory].
  final Map<String, IndexFile> _storedFiles = <String, IndexFile>{};
  final Map<String, IndexFont> _storedFonts = <String, IndexFont>{};
  final Map<String, int> _order = <String, int>{};
  int _sequence = 0;

  bool _persisting = true;
  bool _schemaWritten = false;
  Future<void> _tail = Future<void>.value();

  /// Whether changes are still being written to the store.
  bool get persisting => _persisting && _store != null;

  void _giveUp(String problem) {
    _persisting = false;
    _onProblem?.call(problem);
  }

  // ---------------------------------------------------------------------------
  // Reading what is stored

  Future<void> _read(BlobStore store) async {
    final keys = await store.keys();
    if (keys.isEmpty) return;
    final schema = await store.read(_schemaKey);
    if (schema == null ||
        utf8.decode(schema, allowMalformed: true) != '$schemaVersion') {
      await store.clear();
      _onProblem?.call('dropped stored decks of another version');
      return;
    }
    _schemaWritten = true;
    final dropped = <String>{};
    final manifest = await _readManifest(store);
    final files = <IndexFile, List<int>>{};
    final fonts = <IndexFont, List<int>>{};
    for (final file in manifest.files) {
      final bytes = await store.read('$_filePrefix${file.path}');
      if (_matches(bytes, file.size, file.sha256)) {
        files[file] = bytes!;
      } else {
        dropped.add('$_filePrefix${file.path}');
      }
    }
    for (final font in manifest.fonts) {
      final bytes = await store.read('$_fontPrefix${font.path}');
      if (_matches(bytes, font.size, font.sha256)) {
        fonts[font] = bytes!;
      } else {
        dropped.add('$_fontPrefix${font.path}');
      }
    }
    await _memory.putAll(files);
    await _memory.putFonts(fonts);
    for (final file in files.keys) {
      _storedFiles[file.path] = file;
      _order['$_filePrefix${file.path}'] =
          manifest.order['$_filePrefix${file.path}'] ?? 0;
    }
    for (final font in fonts.keys) {
      _storedFonts[font.path] = font;
      _order['$_fontPrefix${font.path}'] =
          manifest.order['$_fontPrefix${font.path}'] ?? 0;
    }
    _sequence = manifest.sequence;
    // Every other entry is a note, or something no manifest lists.
    final known = <String>{
      _schemaKey,
      _manifestKey,
      for (final path in _storedFiles.keys) '$_filePrefix$path',
      for (final path in _storedFonts.keys) '$_fontPrefix$path',
    };
    for (final key in keys) {
      if (key.startsWith(_notePrefix)) {
        final bytes = await store.read(key);
        if (bytes == null) continue;
        await _memory.writeNote(
          key.substring(_notePrefix.length),
          utf8.decode(bytes, allowMalformed: true),
        );
      } else if (!known.contains(key)) {
        dropped.add(key);
      }
    }
    final evicted = _evict();
    if (dropped.isNotEmpty || evicted.isNotEmpty) {
      _enqueue(const <String, Uint8List>{}, <String>[...dropped, ...evicted]);
    }
  }

  /// The manifest as stored, or an empty one if it is missing or damaged.
  Future<_Manifest> _readManifest(BlobStore store) async {
    final bytes = await store.read(_manifestKey);
    if (bytes == null) return _Manifest.empty;
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map) return _Manifest.empty;
      final index = json['files'];
      final files = index is String
          ? DeckIndex.parse(index).filesByPath.values
                .where(_isStoredFile)
                .toList()
          : <IndexFile>[];
      final fonts = <IndexFont>[
        if (json['fonts'] case final List<Object?> list)
          for (final entry in list)
            if (IndexFont.tryParse(entry) case final font?) font,
      ];
      final order = <String, int>{
        if (json['order'] case final Map<Object?, Object?> map)
          for (final MapEntry(:key, :value) in map.entries)
            if (key is String && value is int) key: value,
      };
      final sequence = json['sequence'];
      return _Manifest(files, fonts, order, sequence is int ? sequence : 0);
    } on Object {
      return _Manifest.empty;
    }
  }

  static bool _isStoredFile(IndexFile file) =>
      isDeckFilePath(file.path) || mediaPathPattern.hasMatch(file.path);

  static bool _matches(Uint8List? bytes, int size, String sha256) =>
      bytes != null && bytes.length == size && sha256Hex(bytes) == sha256;

  // ---------------------------------------------------------------------------
  // Writing through

  /// Removes from what the store holds, oldest written first, until the
  /// files and fonts fit [maxBytes]; returns the keys to delete.
  List<String> _evict() {
    final sizes = <String, int>{
      for (final file in _storedFiles.values)
        '$_filePrefix${file.path}': file.size,
      for (final font in _storedFonts.values)
        '$_fontPrefix${font.path}': font.size,
    };
    var total = sizes.values.fold(0, (sum, size) => sum + size);
    final oldest = sizes.keys.toList()
      ..sort((a, b) {
        final byAge = (_order[a] ?? 0).compareTo(_order[b] ?? 0);
        return byAge != 0 ? byAge : a.compareTo(b);
      });
    final evicted = <String>[];
    for (final key in oldest) {
      if (total <= maxBytes) break;
      total -= sizes[key]!;
      evicted.add(key);
      if (key.startsWith(_filePrefix)) {
        _storedFiles.remove(key.substring(_filePrefix.length));
      } else {
        _storedFonts.remove(key.substring(_fontPrefix.length));
      }
      _order.remove(key);
    }
    return evicted;
  }

  /// Writes [puts] and removes [deletes] in the store, with the manifest as
  /// it is by then, after every write before it. Never throws: a failure
  /// turns persisting off.
  void _enqueue(Map<String, Uint8List> puts, Iterable<String> deletes) {
    final store = _store;
    if (store == null || !_persisting) return;
    final removals = deletes.toList();
    _tail = _tail.then((_) async {
      if (!_persisting) return;
      try {
        await store.write(<String, Uint8List>{
          if (!_schemaWritten)
            _schemaKey: Uint8List.fromList(utf8.encode('$schemaVersion')),
          _manifestKey: _manifestBytes(),
          ...puts,
        }, deletes: removals);
        _schemaWritten = true;
      } on Object catch (e) {
        _giveUp('could not write the decks: $e');
      }
    });
  }

  Uint8List _manifestBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'sequence': _sequence,
        'files': manifestJson(_storedFiles.values),
        'fonts': <Object?>[
          for (final font in _storedFonts.values) font.toJson(),
        ],
        'order': _order,
      }),
    ),
  );

  /// Completes once every write so far has reached the store or been given
  /// up on.
  Future<void> flush() => _tail;

  // ---------------------------------------------------------------------------
  // DownloadedDecks

  @override
  Future<List<String>> list() => _memory.list();

  @override
  String? localPath(String path) => _memory.localPath(path);

  @override
  Future<String> read(String path) => _memory.read(path);

  @override
  Future<Map<String, IndexFile>> manifest() => _memory.manifest();

  @override
  Future<void> putAll(
    Map<IndexFile, List<int>> files, {
    Iterable<String> remove = const <String>[],
  }) async {
    await _memory.putAll(files, remove: remove);
    final puts = <String, Uint8List>{};
    final deletes = <String>[];
    for (final path in remove) {
      _storedFiles.remove(path);
      _order.remove('$_filePrefix$path');
      deletes.add('$_filePrefix$path');
    }
    for (final MapEntry(key: file, value: bytes) in files.entries) {
      final key = '$_filePrefix${file.path}';
      _storedFiles[file.path] = file;
      _order[key] = ++_sequence;
      puts[key] = Uint8List.fromList(bytes);
    }
    _written(puts, deletes);
  }

  @override
  Future<void> removeLanguage(String language) async {
    await _memory.removeLanguage(language);
    final deletes = <String>[
      for (final file in _storedFiles.values)
        if (file.language == language) '$_filePrefix${file.path}',
    ];
    for (final key in deletes) {
      _storedFiles.remove(key.substring(_filePrefix.length));
      _order.remove(key);
    }
    _written(const <String, Uint8List>{}, deletes);
  }

  @override
  Future<Map<String, IndexFont>> fontManifest() => _memory.fontManifest();

  @override
  Future<void> putFonts(Map<IndexFont, List<int>> fonts) async {
    await _memory.putFonts(fonts);
    final puts = <String, Uint8List>{};
    for (final MapEntry(key: font, value: bytes) in fonts.entries) {
      final key = '$_fontPrefix${font.path}';
      _storedFonts[font.path] = font;
      _order[key] = ++_sequence;
      puts[key] = Uint8List.fromList(bytes);
    }
    _written(puts, const <String>[]);
  }

  @override
  Future<Uint8List?> readFont(String path) => _memory.readFont(path);

  @override
  Future<void> removeFonts(Iterable<String> paths) async {
    await _memory.removeFonts(paths);
    final deletes = <String>[for (final path in paths) '$_fontPrefix$path'];
    for (final path in paths) {
      _storedFonts.remove(path);
      _order.remove('$_fontPrefix$path');
    }
    _written(const <String, Uint8List>{}, deletes);
  }

  /// Applies the bound to what [puts] changed, then queues the write.
  void _written(Map<String, Uint8List> puts, List<String> deletes) {
    final evicted = _evict();
    _enqueue(
      <String, Uint8List>{
        for (final MapEntry(:key, :value) in puts.entries)
          if (!evicted.contains(key)) key: value,
      },
      <String>[...deletes, ...evicted],
    );
  }

  @override
  Future<String?> readNote(String name) => _memory.readNote(name);

  @override
  Future<void> writeNote(String name, String text) async {
    await _memory.writeNote(name, text);
    _enqueue(<String, Uint8List>{
      '$_notePrefix$name': Uint8List.fromList(utf8.encode(text)),
    }, const <String>[]);
  }

  @override
  Future<void> clean() async {}
}

class _Manifest {
  const _Manifest(this.files, this.fonts, this.order, this.sequence);

  static const _Manifest empty = _Manifest(
    <IndexFile>[],
    <IndexFont>[],
    <String, int>{},
    0,
  );

  final List<IndexFile> files;
  final List<IndexFont> fonts;
  final Map<String, int> order;
  final int sequence;
}
