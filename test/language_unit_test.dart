// A language read apart (ADR-0062): the units of every language, put
// together, are what reading every file at once gives, member by member.
import 'dart:convert';
import 'dart:io';

import 'package:fluenough/app/added_decks.dart';
import 'package:fluenough/app/catalog_set.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/private_import.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/core/decks/language_unit.dart';
import 'package:flutter_test/flutter_test.dart';

String _deck(
  String id,
  String code,
  String name,
  String iso,
  int from,
  int count,
) =>
    '''
schema: 1
id: $id
name: "$id"
language: { code: $code, iso639_3: $iso, name: $name, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
${[for (var i = 0; i < count; i++) '  - { id: $code-${from + i}, target: "w$i", native: "n$i" }'].join('\n')}
''';

/// Real languages, a private package and an added deck.
Future<Map<String, String>> _files() async {
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
  final tiny = await readPackageFolder(
    Directory('test/fixtures/private/qaa-tiny'),
  );
  for (final e in (tiny ?? const <String, String>{}).entries) {
    if (e.key.endsWith('.yaml') && e.key != 'manifest.yaml') {
      files['private/fnpd-qaa/${e.key}'] = e.value;
    }
  }
  files['added/te-added-test.yaml'] = _deck(
    'te-added-test',
    'te',
    'Telugu',
    'tel',
    90000,
    2,
  );
  return files;
}

Map<String, Catalog> _units(Map<String, String> files) {
  final parts = partitionPaths(
    files.keys,
    addedLanguages: <String, String>{'added/te-added-test.yaml': 'te'},
  );
  return <String, Catalog>{
    for (final code in parts.byLanguage.keys.toList()..sort())
      code: DeckCatalog.parseLanguage(code, <String, String>{
        for (final path in <String>[
          ...parts.shared,
          ...parts.byLanguage[code]!,
        ])
          path: files[path]!,
      }),
  };
}

Map<String, Object?> _sorted(Map<String, Object?> map) => <String, Object?>{
  for (final key in map.keys.toList()..sort()) key: map[key],
};

List<Object?> _entries(List<DeckEntry> entries) => <Object?>[
  for (final e in entries)
    [
      e.path,
      e.id,
      e.bundled,
      e.private,
      [for (final c in e.cards) c.id],
    ],
];

Map<String, Object?> _describe(Catalog c) => <String, Object?>{
  'decks': _entries(c.decks),
  'hidden': _entries(c.hidden),
  'broken': <String>[for (final b in c.broken) '${b.path}: ${b.error.message}']
    ..sort(),
  'themes': <String>[for (final t in c.themes) t.id],
  'facts': c.facts.keys.toList()..sort(),
  'situations': c.situations.keys.toList()..sort(),
  'topics': c.topics.keys.toList()..sort(),
  'creators': c.creators.keys.toList()..sort(),
  'recommendations': c.recommendations.keys.toList()..sort(),
  'numbers': c.numberRules.keys.toList()..sort(),
  'paths': _sorted(<String, Object?>{
    for (final e in c.paths.entries) e.key: e.value.deckIds.toList(),
  }),
  'languagePaths': _sorted(<String, Object?>{
    for (final e in c.languagePaths.entries) e.key: e.value.plan.length,
  }),
  'sounds': c.sounds.keys.toList()..sort(),
  'romanisations': c.romanisations.keys.toList()..sort(),
  'scriptGuides': c.scriptGuides.keys.toList()..sort(),
  'scriptFeatures': _sorted(<String, Object?>{
    for (final e in c.scriptFeatures.entries) e.key: e.value.toList()..sort(),
  }),
  'problems': c.dataProblems.toList()..sort(),
};

void main() {
  test('every file belongs to one unit, found from its path', () {
    expect(languageOfDeckPath('decks/te/te-en-core.yaml'), 'te');
    expect(languageOfDeckPath('decks/te/en/te-en-core.yaml'), 'te');
    expect(languageOfDeckPath('decks/creators/hi.yaml'), 'hi');
    expect(languageOfDeckPath('decks/recommendations/ja.yaml'), 'ja');
    expect(languageOfDeckPath('private/fnpd-qaa/qaa/x.yaml'), 'qaa');
    expect(languageOfDeckPath('private/other/x.yaml'), isNull);
    expect(languageOfDeckPath('added/x.yaml'), isNull);
    expect(languageOfDeckPath('decks/themes.yaml'), isNull);
    expect(isSharedUnitPath('decks/themes.yaml'), isTrue);
    expect(isSharedUnitPath('decks/sections.yaml'), isTrue);
    final parts = partitionPaths(<String>[
      'decks/themes.yaml',
      'decks/te/a.yaml',
      'added/a.yaml',
      'added/b.yaml',
    ], addedLanguages: <String, String>{'added/a.yaml': 'fr'});
    expect(parts.shared, <String>['decks/themes.yaml']);
    expect(parts.byLanguage.keys.toList()..sort(), <String>['fr', 'te']);
    expect(parts.unrouted, <String>['added/b.yaml']);
  });

  test('the units of every language put together are the whole read', () async {
    final files = await _files();
    final whole = DeckCatalog.parseAll(files);
    final units = _units(files);
    expect(units.keys, containsAll(<String>['tok', 'te', 'fr', 'hi', 'qaa']));
    expect(whole.decks, isNotEmpty);
    expect(
      whole.decks.any((e) => e.private) &&
          whole.decks.any((e) => !e.bundled && !e.private),
      isTrue,
      reason: 'the fixture has a private package and an added deck',
    );
    final composed = Catalog.compose(units.values.toList());
    expect(jsonEncode(_describe(composed)), jsonEncode(_describe(whole)));
  });

  test('a lazy catalog loads the same decks as a whole one', () async {
    final files = await _files();
    final added = <String, String>{
      'te-added-test': files.remove('added/te-added-test.yaml')!,
    };
    final whole = await DeckCatalog(
      MemoryDeckSource(files),
      added: MemoryDeckStore(added),
    ).load();
    final lazy = DeckCatalog(
      MemoryDeckSource(files),
      added: MemoryDeckStore(added),
      mode: CatalogMode.lazy,
    );
    final loaded = await lazy.load();
    expect(_entries(loaded.decks), _entries(whole.decks));
    expect(lazy.catalogSet.loadOf('te').isLoaded, isTrue);
    expect(lazy.catalogSet.loadOf('xx').phase, LoadPhase.notLoaded);
  });

  test('a deck filed under one language that teaches another is broken', () {
    final files = <String, String>{
      'decks/te/te-en-odd.yaml': _deck(
        'fr-en-odd',
        'fr',
        'French',
        'fra',
        100,
        1,
      ),
      'decks/te/te-en-fine.yaml': _deck(
        'te-en-fine',
        'te',
        'Telugu',
        'tel',
        200,
        1,
      ),
    };
    final unit = DeckCatalog.parseLanguage('te', files);
    expect(unit.decks.map((e) => e.id), <String>['te-en-fine']);
    expect(unit.broken.map((b) => b.path), <String>['decks/te/te-en-odd.yaml']);
    expect(unit.broken.single.error.message, contains('filed under te'));
  });
}
