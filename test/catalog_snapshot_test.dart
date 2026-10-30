// The catalog's snapshot (#875, ADR-0048): the decks' YAML kept as JSON, read
// again only for a file that changed, and never trusted when it is damaged.
import 'dart:convert';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:flutter_test/flutter_test.dart';

/// A few real files: one language's decks, the themes, and a numbers file,
/// whose keys are numbers and so test that they survive JSON.
Future<Map<String, String>> _files() async {
  final source = RepositoryDeckSource();
  final files = <String, String>{};
  var numbers = false;
  for (final path in await source.list()) {
    final text = await source.read(path);
    if (path.startsWith('decks/tok/') || path == 'decks/themes.yaml') {
      files[path] = text;
    } else if (!numbers && DeckCatalog.kindOf(text) == 'numbers') {
      numbers = true;
      files[path] = text;
    }
  }
  return files;
}

String _describe(Catalog c) => jsonEncode(<String, Object?>{
  'decks': [
    for (final d in c.decks)
      [
        d.path,
        d.id,
        d.deck.name,
        [
          for (final card in d.cards) [card.id, card.target, card.native],
        ],
      ],
  ],
  'broken': [
    for (final b in c.broken) [b.path, b.error.message, b.error.line],
  ],
  'themes': [for (final t in c.themes) t.id],
  'paths': c.paths.keys.toList(),
  'languagePaths': c.languagePaths.keys.toList(),
  'numbers': {
    for (final e in c.numberRules.entries)
      e.key: [
        e.value.join,
        e.value.words.entries.map((w) => '${w.key}:${w.value}').toList(),
      ],
  },
});

Map<String, String> _shas(Map<String, String> files) => {
  for (final path in files.keys) path: '${path.hashCode}'.padLeft(64, '0'),
};

DeckCatalog _catalog(
  Map<String, String> files,
  MemorySnapshotStore store, {
  Map<String, String>? shas,
  String app = '0.6.8',
}) => DeckCatalog(
  MemoryDeckSource(files),
  snapshots: CatalogSnapshots(
    store: store,
    app: app,
    knownShas: () async => shas ?? _shas(files),
  ),
);

void main() {
  test('the snapshot gives the catalog the YAML gives', () async {
    final files = await _files();
    final fromYaml = DeckCatalog.parseAll(files);
    expect(fromYaml.decks, isNotEmpty);
    expect(fromYaml.numberRules, isNotEmpty);

    final store = MemorySnapshotStore();
    final first = await _catalog(files, store).load();
    expect(store.text, isNotNull, reason: 'the first launch keeps a snapshot');
    expect(_describe(first), _describe(fromYaml));

    // The second launch is given YAML it could not parse: it can only be
    // right if it read the snapshot, which the same SHA-256s vouch for.
    final spoiled = {for (final p in files.keys) p: ': : not yaml ['};
    final second = await _catalog(spoiled, store, shas: _shas(files)).load();
    expect(_describe(second), _describe(fromYaml));
  });

  test('a file whose SHA-256 changed is read from YAML again', () async {
    final files = await _files();
    final store = MemorySnapshotStore();
    await _catalog(files, store).load();
    final changed = files.keys.firstWhere((p) => p.startsWith('decks/tok/'));
    final edited = {...files, changed: ': : not yaml ['};
    final shas = _shas(files)..[changed] = 'f' * 64;

    final catalog = await _catalog(edited, store, shas: shas).load();
    expect(catalog.broken.map((b) => b.path), contains(changed));
    expect(_describe(catalog), _describe(DeckCatalog.parseAll(edited)));
    final kept = jsonDecode(store.text!) as Map<String, dynamic>;
    expect(kept['files'], isNot(contains(changed)));
  });

  test('a removed file leaves the snapshot and the catalog', () async {
    final files = await _files();
    final store = MemorySnapshotStore();
    await _catalog(files, store).load();
    final gone = files.keys.firstWhere((p) => p.startsWith('decks/tok/'));
    final fewer = {...files}..remove(gone);

    await _catalog(fewer, store).load();
    expect(jsonDecode(store.text!)['files'], isNot(contains(gone)));
  });

  test('a damaged snapshot is ignored and replaced', () async {
    final files = await _files();
    final fromYaml = DeckCatalog.parseAll(files);
    for (final damaged in <String>[
      '{"format": 1, "app": "0.6.8", "files": {"decks/themes.yaml": ',
      'not json at all',
      '[]',
      '{"format": 1, "app": "0.6.8", "files": {"decks/themes.yaml": 7}}',
      '',
    ]) {
      final store = MemorySnapshotStore(damaged);
      final catalog = await _catalog(files, store).load();
      expect(_describe(catalog), _describe(fromYaml), reason: damaged);
      expect(store.text, isNot(damaged));
      expect(jsonDecode(store.text!)['format'], isNotNull);
    }
  });

  test('a new app version ignores the old one\'s snapshot', () async {
    final files = await _files();
    final store = MemorySnapshotStore();
    await _catalog(files, store, app: '0.6.8').load();
    final spoiled = {for (final p in files.keys) p: ': : not yaml ['};

    // Same SHA-256s, other version: the spoiled YAML must be read, and fail.
    final catalog = await _catalog(spoiled, store, app: '0.6.9').load();
    expect(catalog.decks, isEmpty);
    expect(catalog.broken, isNotEmpty);
    expect(jsonDecode(store.text!)['files'], isEmpty);
  });

  test('a file that is not valid YAML is broken, never a crash', () async {
    final files = {...await _files(), 'decks/tok/x.yaml': ': : not yaml ['};
    final store = MemorySnapshotStore();
    final first = await _catalog(files, store).load();
    final second = await _catalog(files, store).load();
    expect(first.broken.map((b) => b.path), contains('decks/tok/x.yaml'));
    expect(_describe(second), _describe(first));
  });
}
