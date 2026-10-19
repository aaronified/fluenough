import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/decks/deck_index.dart';
import '../core/decks/sha256.dart';
import 'card_media.dart';
import 'deck_catalog.dart';

/// The deck files downloaded from GitHub (#210, ADR-0037), kept in the
/// app's own storage under `downloaded/`, which an app update leaves alone.
///
/// A file keeps its path from the repository, `decks/hi/hi-en-family.yaml`,
/// so that the catalog reads it as it read the bundled one. Beside the
/// files, the store keeps what the index said of each when it was
/// downloaded ([manifest]), the last index read, and a little state of its
/// own ([readNote]). The script fonts of the courses on the phone
/// (ADR-0042) are kept the same way, under `decks/fonts/`, with a manifest
/// of their own ([fontManifest]): a font is shared by the courses in its
/// script, so it belongs to no one language's files.
///
/// Every file put here has been checked against the index's SHA-256 first
/// ([DeckDownloads]); [putAll] then writes each beside its place and moves
/// it in only once all are written, so that a download cut short never
/// leaves half a file, or half a language's update, in use.
abstract interface class DownloadedDecks implements DeckSource, CardMedia {
  /// Every deck file on the phone, sorted: `decks/...`. Its cards'
  /// recordings and images are not deck files: [manifest] lists them, and
  /// [localPath] finds them.
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
  /// the review log, stays. Fonts are not its files: [removeFonts] deletes
  /// those no course needs.
  Future<void> removeLanguage(String language);

  /// What the index said of each font on the phone when it was downloaded,
  /// by path (ADR-0042).
  Future<Map<String, IndexFont>> fontManifest();

  /// Keeps [fonts], each with its bytes, replacing any font at its path.
  Future<void> putFonts(Map<IndexFont, List<int>> fonts);

  /// The bytes of the font at [path], or null if it is not on the phone.
  Future<Uint8List?> readFont(String path);

  /// Deletes the fonts at [paths].
  Future<void> removeFonts(Iterable<String> paths);

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
  static const String _fontsNote = 'fonts.json';
  static const String _partial = '.part';

  Map<String, IndexFile>? _files;
  Map<String, IndexFont>? _fontFiles;

  File _file(String path) => File('${directory.path}/$path');

  /// Refuses a path that is not a deck file's, or a card's recording's or
  /// image's, so nothing is written or read outside [directory].
  static String _checked(String path) {
    if (!isDeckFilePath(path) && !mediaPathPattern.hasMatch(path)) {
      throw ArgumentError.value(path, 'path', 'not a deck file');
    }
    return path;
  }

  @override
  String? localPath(String path) {
    if (!mediaPathPattern.hasMatch(path)) return null;
    final file = _file(path);
    return file.existsSync() ? file.path : null;
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
        if (entity is File &&
            (entity.path.endsWith('.yaml') ||
                mediaPathPattern.hasMatch(
                  entity.path.substring(prefix.length),
                )))
          entity.path.substring(prefix.length),
    ]..sort();
  }

  @override
  Future<List<String>> list() async =>
      (await manifest()).keys.where(isDeckFilePath).toList()..sort();

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

  /// Refuses a path that is not a font's, so nothing is written or read
  /// outside [directory].
  static String _checkedFont(String path) {
    if (!fontPathPattern.hasMatch(path)) {
      throw ArgumentError.value(path, 'path', 'not a font file');
    }
    return path;
  }

  @override
  Future<Map<String, IndexFont>> fontManifest() async {
    final known = _fontFiles;
    if (known != null) return Map<String, IndexFont>.of(known);
    final fonts = <String, IndexFont>{};
    final text = await readNote(_fontsNote);
    if (text != null) {
      try {
        final json = jsonDecode(text);
        if (json is Map && json['fonts'] is List) {
          for (final entry in json['fonts'] as List<Object?>) {
            final font = IndexFont.tryParse(entry);
            // A font the manifest knows but the disk does not was deleted.
            if (font != null && await _file(font.path).exists()) {
              fonts[font.path] = font;
            }
          }
        }
      } on Object {
        // A manifest that cannot be read: the fonts are downloaded again.
      }
    }
    _fontFiles = fonts;
    return Map<String, IndexFont>.of(fonts);
  }

  @override
  Future<void> putFonts(Map<IndexFont, List<int>> fonts) async {
    final known = await fontManifest();
    for (final MapEntry(key: font, value: bytes) in fonts.entries) {
      final target = _file(_checkedFont(font.path));
      await target.parent.create(recursive: true);
      final part = File('${target.path}$_partial');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(target.path);
      known[font.path] = font;
    }
    await _saveFonts(known);
  }

  @override
  Future<Uint8List?> readFont(String path) async {
    final file = _file(_checkedFont(path));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> removeFonts(Iterable<String> paths) async {
    final known = await fontManifest();
    for (final path in paths) {
      final file = _file(_checkedFont(path));
      if (await file.exists()) await file.delete();
      known.remove(path);
    }
    await _saveFonts(known);
  }

  Future<void> _saveFonts(Map<String, IndexFont> fonts) async {
    _fontFiles = fonts;
    await writeNote(
      _fontsNote,
      jsonEncode(<String, Object?>{
        'fonts': <Object?>[for (final font in fonts.values) font.toJson()],
      }),
    );
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
  /// With [seed] on the phone already: each file as the index listed it,
  /// with its text.
  MemoryDownloadedDecks([Map<IndexFile, String> seed = const {}]) {
    for (final MapEntry(key: file, value: text) in seed.entries) {
      files[file.path] = Uint8List.fromList(utf8.encode(text));
      _manifest[file.path] = file;
    }
  }

  /// Each file's text by path.
  final Map<String, Uint8List> files = <String, Uint8List>{};
  final Map<String, IndexFile> _manifest = <String, IndexFile>{};
  final Map<String, String> notes = <String, String>{};

  /// Each font's bytes by path, and what the index said of it.
  final Map<String, Uint8List> fontFiles = <String, Uint8List>{};
  final Map<String, IndexFont> _fonts = <String, IndexFont>{};

  /// How many times [putAll] was called.
  int puts = 0;

  /// While set, [putAll] throws it: a phone that is full.
  Object? failPut;

  @override
  Future<List<String>> list() async =>
      files.keys.where(isDeckFilePath).toList()..sort();

  /// Not on a disk: a recording or an image has no file to play or show.
  @override
  String? localPath(String path) => null;

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
  Future<Map<String, IndexFont>> fontManifest() async =>
      Map<String, IndexFont>.of(_fonts);

  @override
  Future<void> putFonts(Map<IndexFont, List<int>> fonts) async {
    if (failPut case final error?) throw error;
    for (final MapEntry(key: font, value: bytes) in fonts.entries) {
      fontFiles[font.path] = Uint8List.fromList(bytes);
      _fonts[font.path] = font;
    }
  }

  @override
  Future<Uint8List?> readFont(String path) async => fontFiles[path];

  @override
  Future<void> removeFonts(Iterable<String> paths) async {
    for (final path in paths) {
      fontFiles.remove(path);
      _fonts.remove(path);
    }
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
