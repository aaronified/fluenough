import 'dart:convert';
import 'dart:io';

import '../core/decks/deck_index.dart';
import 'deck_catalog.dart';

/// The repository's own `decks/`, read from a checkout as a phone would
/// have it after downloading every language: the files `decks/index.json`
/// lists, and the theme list the app bundles (#210, ADR-0037). Hidden
/// languages, such as Japanese, are left out, as the index leaves them out.
///
/// For tests, now that the app bundles no decks: `AppState.test` reads
/// these by default. Read synchronously and kept once read, so that it
/// works inside a widget test, where real file reads never complete.
class RepositoryDeckSource implements DeckSource {
  RepositoryDeckSource([this.root = '.']);

  /// The checkout's root: the working directory, where `flutter test` runs.
  final String root;

  static final Map<String, Map<String, String>> _read =
      <String, Map<String, String>>{};

  Map<String, String> get _files => _read[root] ??= _load(root);

  static Map<String, String> _load(String root) {
    final text = File('$root/decks/index.json').readAsStringSync();
    final json = jsonDecode(text);
    final bundled = <String>[
      if (json is Map && json['bundled'] is List)
        for (final path in json['bundled'] as List<Object?>)
          if (path is String) path,
    ];
    final index = DeckIndex.parse(text);
    return <String, String>{
      for (final path in <String>[...bundled, ...index.filesByPath.keys])
        path: File('$root/$path').readAsStringSync(),
    };
  }

  @override
  Future<List<String>> list() async => _files.keys.toList()..sort();

  @override
  Future<String> read(String path) async =>
      _files[path] ?? (throw StateError('no deck file at $path'));
}
