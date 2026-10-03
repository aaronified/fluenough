import 'dart:io';

import 'deck_catalog.dart';

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

/// [DeckStore] in a directory of the app's own storage, which an update
/// leaves alone.
class FileDeckStore implements DeckStore {
  FileDeckStore(this.directory);

  final Directory directory;

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
  }

  @override
  Future<void> remove(String deckId) async {
    final file = _file(deckId);
    if (await file.exists()) await file.delete();
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
