import 'dart:convert';
import 'dart:io';

import '../core/decks/language_unit.dart';
import 'deck_catalog.dart';
import 'deck_files.dart';

/// Decks a learner added from a file (#22), kept apart from the bundled
/// ones: one file per deck, named by its id. They are read with the bundled
/// decks, under [addedDeckPrefix], and marked as not bundled.
abstract interface class DeckStore implements DeckSource {
  /// Keeps [text], the file of the deck with [deckId], replacing any file
  /// that deck had.
  Future<void> save(String deckId, String text);

  /// Forgets the deck with [deckId]. Its review history stays.
  Future<void> remove(String deckId);
}

/// Where an added deck's path starts, so the catalog can tell it from a
/// bundled one.
const String addedDeckPrefix = 'added/';

/// A store of added decks that knows which language each teaches, so that
/// the catalog can give a deck to its language's unit without reading it
/// (ADR-0062).
abstract interface class AddedLanguages {
  /// The language the added deck at [path] teaches, or null when it cannot be
  /// told.
  Future<String?> languageOf(String path);
}

/// [DeckStore] in a directory of the app's own storage, which an update
/// leaves alone. It keeps `added-index.json` beside the decks: each deck
/// file's language, a few bytes, so that no deck is read to find it. A deck
/// the index lacks is read once, and entered.
class FileDeckStore implements DeckStore, DiskLocated, AddedLanguages {
  FileDeckStore(this.directory);

  final Directory directory;

  static const String _indexName = 'added-index.json';

  Map<String, String>? _languages;

  File get _indexFile => File('${directory.path}/$_indexName');

  Future<Map<String, String>> _index() async {
    final known = _languages;
    if (known != null) return known;
    final languages = <String, String>{};
    try {
      final file = _indexFile;
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map) {
          for (final e in json.entries) {
            if (e.key is String && e.value is String) {
              languages[e.key as String] = e.value as String;
            }
          }
        }
      }
    } on Object {
      // A damaged index is rebuilt from the decks.
      languages.clear();
    }
    return _languages = languages;
  }

  Future<void> _saveIndex(Map<String, String> languages) async {
    try {
      await directory.create(recursive: true);
      await _indexFile.writeAsString(jsonEncode(languages), flush: true);
    } on Object {
      // The index is a cache: the next call reads the decks again.
    }
  }

  @override
  Future<String?> languageOf(String path) async {
    final name = path.substring(addedDeckPrefix.length);
    final index = await _index();
    final known = index[name];
    if (known != null) return known;
    try {
      final code = languageCodeOfDeckText(await read(path));
      if (code != null) {
        index[name] = code;
        await _saveIndex(index);
      }
      return code;
    } on Object {
      return null;
    }
  }

  @override
  String? locate(String path) => path.startsWith(addedDeckPrefix)
      ? '${directory.path}/${path.substring(addedDeckPrefix.length)}'
      : null;

  File _file(String deckId) => File('${directory.path}/$deckId.yaml');

  @override
  Future<List<String>> list() async {
    if (!await directory.exists()) return const <String>[];
    return <String>[
      await for (final entity in directory.list())
        if (entity is File && entity.path.endsWith('.yaml'))
          '$addedDeckPrefix${entity.uri.pathSegments.last}',
    ]..sort();
  }

  @override
  Future<String> read(String path) =>
      File('${directory.path}/${path.substring(addedDeckPrefix.length)}')
          .readAsString();

  @override
  Future<void> save(String deckId, String text) async {
    await directory.create(recursive: true);
    await _file(deckId).writeAsString(text, flush: true);
    final code = languageCodeOfDeckText(text);
    final index = await _index();
    if (code == null) {
      index.remove('$deckId.yaml');
    } else {
      index['$deckId.yaml'] = code;
    }
    await _saveIndex(index);
  }

  @override
  Future<void> remove(String deckId) async {
    final file = _file(deckId);
    if (await file.exists()) await file.delete();
    final index = await _index();
    if (index.remove('$deckId.yaml') != null) await _saveIndex(index);
  }
}

/// [DeckStore] in memory, for tests and the gallery.
class MemoryDeckStore implements DeckStore {
  MemoryDeckStore([Map<String, String> decks = const <String, String>{}])
    : _decks = Map<String, String>.of(decks);

  /// Deck file text by deck id.
  final Map<String, String> _decks;

  @override
  Future<List<String>> list() async =>
      <String>[for (final id in _decks.keys) '$addedDeckPrefix$id.yaml']
        ..sort();

  @override
  Future<String> read(String path) async =>
      _decks[path.substring(
        addedDeckPrefix.length,
        path.length - '.yaml'.length,
      )] ??
      (throw StateError('no added deck at $path'));

  @override
  Future<void> save(String deckId, String text) async => _decks[deckId] = text;

  @override
  Future<void> remove(String deckId) async => _decks.remove(deckId);
}
