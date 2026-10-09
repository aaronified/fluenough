import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/decks/deck_index.dart';
import '../core/decks/sha256.dart';
import 'deck_catalog.dart';

/// The deck files downloaded from GitHub (#210, ADR-0037), kept in the
/// app's own storage under `downloaded/`, which an app update leaves alone.
///
/// A file keeps its path from the repository, `decks/hi/hi-en-family.yaml`,
/// so that the catalog reads it as it read the bundled one. Beside the
/// files, the store keeps what the index said of each when it was
/// downloaded ([manifest]), the last index read, and a little state of its
/// own ([readNote]).
///
/// Every file put here has been checked against the index's SHA-256 first
/// ([DeckDownloads]); [putAll] then writes each beside its place and moves
/// it in only once all are written, so that a download cut short never
/// leaves half a file, or half a language's update, in use.
abstract interface class DownloadedDecks implements DeckSource {
  /// Every deck file on the phone, sorted: `decks/...`.
  @override
  Future<List<String>> list();

  @override
  Future<String> read(String path);

  /// What the index said of each file on the phone when it was
  /// downloaded, by path.
  Future<Map<String, IndexFile>> manifest();

  /// Keeps [files], each with its bytes, replacing any file at its path,
  /// and removes [remove]. All are written first; only then is any moved
  /// into place.
  Future<void> putAll(
    Map<IndexFile, List<int>> files, {
    Iterable<String> remove = const <String>[],
  });

  /// Deletes every file of [language]. Its learner's progress, which is in
  /// the review log, stays.
  Future<void> removeLanguage(String language);

  /// A note the downloads keep, such as `index.json` or `state.json`, or
  /// null if there is none.
  Future<String?> readNote(String name);

  Future<void> writeNote(String name, String text);

  /// Deletes what a download cut short left: files written but never moved
  /// into place.
  Future<void> clean();
}

/// [DownloadedDecks] in a directory of the app's own storage.
class FileDownloadedDecks implements DownloadedDecks {
  FileDownloadedDecks(this.directory);

  final Directory directory;

  static const String _manifest = 'files.json';
  static const String _partial = '.part';

  Map<String, IndexFile>? _files;

  File _file(String path) => File('${directory.path}/$path');

  /// Refuses a path that is not a deck file's, so nothing is written or
  /// read outside [directory].
  static String _checked(String path) {
    if (!RegExp(
      r'^decks/[a-z]{2,3}/(?:[a-z]{2,3}/)?[a-z0-9]+(?:-[a-z0-9]+)*\.yaml$',
    ).hasMatch(path)) {
      throw ArgumentError.value(path, 'path', 'not a deck file');
    }
    return path;
  }

  @override
  Future<Map<String, IndexFile>> manifest() async {
    final known = _files;
    if (known != null) return Map<String, IndexFile>.of(known);
    final text = await readNote(_manifest);
    final files = <String, IndexFile>{};
    if (text != null) {
      try {
        final index = DeckIndex.parse(text);
        files.addAll(index.filesByPath);
      } on Object {
        // A manifest that cannot be read is rebuilt from the files below.
      }
    }
    // A file on disk the manifest does not know, as after a crash between
    // moving a file in and writing the manifest, is known by its hash.
    for (final path in await _onDisk()) {
      if (files.containsKey(path)) continue;
      final bytes = await _file(path).readAsBytes();
      files[path] = IndexFile(
        path: path,
        size: bytes.length,
        sha256: sha256Hex(bytes),
      );
    }
    // A file the manifest knows but the disk does not was deleted.
    final disk = (await _onDisk()).toSet();
    files.removeWhere((path, _) => !disk.contains(path));
    _files = files;
    return Map<String, IndexFile>.of(files);
  }

  Future<List<String>> _onDisk() async {
    final decks = Directory('${directory.path}/decks');
    if (!await decks.exists()) return const <String>[];
    final prefix = '${directory.path}/';
    return <String>[
      await for (final entity in decks.list(recursive: true))
        if (entity is File && entity.path.endsWith('.yaml'))
          entity.path.substring(prefix.length),
    ]..sort();
  }

  @override
  Future<List<String>> list() async => (await manifest()).keys.toList()..sort();

  @override
  Future<String> read(String path) => _file(_checked(path)).readAsString();

  @override
  Future<void> putAll(
    Map<IndexFile, List<int>> files, {
    Iterable<String> remove = const <String>[],
  }) async {
    final known = await manifest();
    // Written beside their place first, flushed, then moved in: a rename in
    // one directory is atomic, so each file is the old or the new, whole.
    final written = <File, File>{};
    for (final MapEntry(key: file, value: bytes) in files.entries) {
      final target = _file(_checked(file.path));
      await target.parent.create(recursive: true);
      final part = File('${target.path}$_partial');
      await part.writeAsBytes(bytes, flush: true);
      written[part] = target;
    }
    for (final MapEntry(key: part, value: target) in written.entries) {
      await part.rename(target.path);
    }
    for (final file in files.keys) {
      known[file.path] = file;
    }
    for (final path in remove) {
      final file = _file(_checked(path));
      if (await file.exists()) await file.delete();
      known.remove(path);
    }
    await _save(known);
  }

  @override
  Future<void> removeLanguage(String language) async {
    final folder = Directory('${directory.path}/decks/$language');
    if (await folder.exists()) await folder.delete(recursive: true);
    final known = await manifest()
      ..removeWhere((_, file) => file.language == language);
    await _save(known);
  }

  Future<void> _save(Map<String, IndexFile> files) async {
    _files = files;
    await writeNote(_manifest, manifestJson(files.values));
  }

  @override
  Future<String?> readNote(String name) async {
    final file = File('${directory.path}/$name');
    if (!await file.exists()) return null;
    try {
      return await file.readAsString();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> writeNote(String name, String text) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}/$name');
    final part = File('${file.path}$_partial');
    await part.writeAsString(text, flush: true);
    await part.rename(file.path);
  }

  @override
  Future<void> clean() async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith(_partial)) {
        await entity.delete();
      }
    }
  }
}

/// [DownloadedDecks] in memory, for tests and the gallery.
class MemoryDownloadedDecks implements DownloadedDecks {
  MemoryDownloadedDecks();

  /// Each file's text by path.
  final Map<String, Uint8List> files = <String, Uint8List>{};
  final Map<String, IndexFile> _manifest = <String, IndexFile>{};
  final Map<String, String> notes = <String, String>{};

  /// How many times [putAll] was called.
  int puts = 0;

  /// While set, [putAll] throws it: a phone that is full.
  Object? failPut;

  @override
  Future<List<String>> list() async => files.keys.toList()..sort();

  @override
  Future<String> read(String path) async {
    final bytes = files[path];
    if (bytes == null) throw StateError('no downloaded file at $path');
    return utf8.decode(bytes);
  }

  @override
  Future<Map<String, IndexFile>> manifest() async =>
      Map<String, IndexFile>.of(_manifest);

  @override
  Future<void> putAll(
    Map<IndexFile, List<int>> files, {
    Iterable<String> remove = const <String>[],
  }) async {
    puts++;
    if (failPut case final error?) throw error;
    for (final MapEntry(key: file, value: bytes) in files.entries) {
      this.files[file.path] = Uint8List.fromList(bytes);
      _manifest[file.path] = file;
    }
    for (final path in remove) {
      this.files.remove(path);
      _manifest.remove(path);
    }
  }

  @override
  Future<void> removeLanguage(String language) async {
    files.removeWhere((path, _) => path.split('/')[1] == language);
    _manifest.removeWhere((_, file) => file.language == language);
  }

  @override
  Future<String?> readNote(String name) async => notes[name];

  @override
  Future<void> writeNote(String name, String text) async => notes[name] = text;

  @override
  Future<void> clean() async {}
}

/// [files] as the manifest keeps them: an index of one language per
/// folder, so that [DeckIndex.parse] reads it back.
String manifestJson(Iterable<IndexFile> files) {
  final byLanguage = <String, List<IndexFile>>{};
  for (final file in files) {
    (byLanguage[file.language] ??= <IndexFile>[]).add(file);
  }
  final codes = byLanguage.keys.toList()..sort();
  return jsonEncode(<String, Object?>{
    'version': supportedIndexVersion,
    'languages': <Object?>[
      for (final code in codes)
        <String, Object?>{
          'code': code,
          'name': code,
          'files': <Object?>[
            for (final file
                in byLanguage[code]!..sort((a, b) => a.path.compareTo(b.path)))
              file.toJson(),
          ],
        },
    ],
  });
}
