// The catalog's snapshot (#875, ADR-0048): the decks' YAML kept as JSON, read
// again only for a file that changed, and never trusted when it is damaged.
import 'dart:convert';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/core/models/card.dart';
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

/// Whole languages' files, so that ref cards, optional fields, planned and
/// native decks of a path, facts, guides, sounds, romanisation, script guides
/// and number rules are all read: the snapshot must give back all of it.
Future<Map<String, String>> _wholeLanguages() async {
  final source = RepositoryDeckSource();
  final files = <String, String>{};
  for (final path in await source.list()) {
    for (final lang in const ['tok', 'te', 'fr', 'hi']) {
      if (path.startsWith('decks/$lang/')) {
        files[path] = await source.read(path);
      }
    }
    if (path == 'decks/themes.yaml') files[path] = await source.read(path);
  }
  return files;
}

List<Object?> _card(Card c) => [
  c.id,
  c.deckId,
  c.target,
  c.native,
  c.reading,
  c.ipa,
  c.phonetic,
  c.phoneticSource,
  c.altReading,
  c.altTarget,
  c.altNative,
  c.targetScripts,
  c.words,
  c.pos,
];

/// Everything the catalog holds, as JSON-able values.
String _describeAll(Catalog c) => jsonEncode(<String, Object?>{
  'decks': [
    for (final d in c.decks)
      [
        d.path,
        d.id,
        d.deck.name,
        d.deck.kind.name,
        d.cards.map(_card).toList(),
      ],
  ],
  'broken': [
    for (final b in c.broken) [b.path, b.error.message, b.error.line],
  ],
  'themes': [for (final t in c.themes) t.id],
  'facts': {
    for (final e in c.facts.entries)
      e.key: [
        for (final f in e.value.facts)
          [f.id, f.text, f.contrast, f.tags, f.source, f.cards],
      ],
  },
  'numbers': {
    for (final e in c.numberRules.entries)
      e.key: [
        e.value.join,
        e.value.tensAndUnits,
        e.value.words.entries.map((w) => '${w.key}:${w.value}').toList(),
      ],
  },
  'paths': {
    for (final e in c.paths.entries)
      e.key: [
        e.value.units,
        e.value.open.toList()..sort(),
        e.value.alphabet.toList()..sort(),
        e.value.plan.length,
        e.value.coveredUnits,
        e.value.writtenUnits,
      ],
  },
  'languagePaths': {
    for (final e in c.languagePaths.entries)
      e.key: [
        e.value.alphabet.toList()..sort(),
        e.value.plan.length,
        e.value.genders,
        [
          for (final r in e.value.regions) [r.id, r.names],
        ],
      ],
  },
  'sounds': {
    for (final e in c.sounds.entries)
      e.key: [
        for (final s in e.value.contrasts)
          [s.id, s.name, s.withinWord, s.pairs.map((p) => '${p.$1}|${p.$2}')],
      ],
  },
  'romanisations': {
    for (final e in c.romanisations.entries)
      e.key: [
        e.value.scheme,
        e.value.standard,
        e.value.typed.map((p) => '${p.$1}|${p.$2}').toList(),
        e.value.equivalents,
      ],
  },
  'scriptGuides': {
    for (final e in c.scriptGuides.entries)
      e.key: [
        e.value.name,
        e.value.intro,
        e.value.script,
        [
          for (final f in e.value.features)
            [
              f.id,
              f.name,
              f.term,
              f.reading,
              f.ipa,
              f.example,
              f.text,
              f.letters,
            ],
        ],
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
    final spoiled = {for (final p in files.keys) p: ': : not yaml [ $p'};
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
    final spoiled = {for (final p in files.keys) p: ': : not yaml [ $p'};

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

  test('a snapshot gives whole languages what their YAML gives', () async {
    final files = await _wholeLanguages();
    final fromYaml = DeckCatalog.parseAll(files);
    expect(fromYaml.decks, isNotEmpty);
    expect(fromYaml.paths, isNotEmpty);
    expect(fromYaml.languagePaths, isNotEmpty);
    expect(fromYaml.facts, isNotEmpty);
    expect(fromYaml.sounds, isNotEmpty);
    expect(fromYaml.romanisations, isNotEmpty);
    expect(fromYaml.scriptGuides, isNotEmpty);
    expect(fromYaml.numberRules, isNotEmpty);

    final store = MemorySnapshotStore();
    final first = await _catalog(files, store).load();
    expect(_describeAll(first), _describeAll(fromYaml));

    // Fed YAML that could only parse into something else, with the same
    // SHA-256s, the second launch is right only by reading kept trees: and
    // those must read as YAML does, optional fields and refs included.
    final spoiled = {for (final p in files.keys) p: ': : not yaml [ $p'};
    final second = await _catalog(spoiled, store, shas: _shas(files)).load();
    expect(_describeAll(second), _describeAll(fromYaml));
  });
}
