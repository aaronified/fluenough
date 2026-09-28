import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/models/deck.dart';

const String miniDeck = '''
schema: 1
id: xx-mini
name: Mini
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - id: xx-mini-0001
    target: ñu
    native: gnu
''';

const String factsFile = '''
schema: 1
kind: facts
language: { code: es, iso639_3: spa, name: Spanish }
facts:
  - id: es-fact-0001
    text: { en: "Spanish has two verbs for to be." }
''';

/// Line 10 has an unquoted `no`, the bug rule 2 is about.
const String brokenDeck = '''
schema: 1
id: xx-broken
name: Broken
language: { code: ja, iso639_3: jpn, name: Japanese, script: kana }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: xx-broken-0001
    target: の
    native: no
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled decks', () {
    late Catalog catalog;

    setUpAll(() async {
      catalog = await DeckCatalog.bundled().load();
    });

    test('every bundled deck file is listed and parses', () {
      final onDisk = Directory('decks')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where(AssetDeckSource.isDeckPath)
          .where((p) => !DeckCatalog.isFactsFile(File(p).readAsStringSync()))
          .toSet();
      expect(onDisk, isNotEmpty);
      expect(catalog.broken, isEmpty, reason: '${catalog.broken}');
      expect(catalog.decks.map((d) => d.path).toSet(), onDisk);
    });

    test('includes the known decks, in path order', () {
      final ids = catalog.decks.map((d) => d.id).toList();
      expect(
        ids,
        containsAll(['es-core-100', 'es-grammar-present-ar', 'ja-hiragana']),
      );
      final paths = catalog.decks.map((d) => d.path).toList();
      expect(paths, [...paths]..sort());
    });

    test('a grammar deck is listed with its pattern, expanded to cards', () {
      final grammar = catalog.byId('es-grammar-present-ar')!;
      expect(grammar.deck.kind, DeckKind.grammar);
      expect(grammar.deck.pattern, isNotNull);
      expect(grammar.cards, hasLength(30), reason: '5 lemmas x 6 slots');
      expect(grammar.itemCount, 30);
      expect(grammar.glyph, 'h', reason: 'first grapheme of the first lemma');
    });

    test('script decks are the ones tagged script', () {
      expect(catalog.byId('ja-hiragana')!.isScript, isTrue);
      expect(catalog.byId('es-core-100')!.isScript, isFalse);
      expect(catalog.byId('ja-hiragana')!.glyph, 'あ');
    });

    test('languages come one per code', () {
      final codes = catalog.languages.map((l) => l.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
      expect(codes, containsAll(['es', 'ja']));
    });
  });

  group('parseAll', () {
    test('skips a facts file, by its kind rather than its name', () {
      final catalog = DeckCatalog.parseAll({
        'decks/es/es-mini.yaml': miniDeck,
        'decks/es/whatever.yaml': factsFile,
      });
      expect(catalog.decks.map((d) => d.id), ['xx-mini']);
      expect(catalog.broken, isEmpty);
    });

    test('turns a file that fails to parse into a row, with its line', () {
      final catalog = DeckCatalog.parseAll({
        'decks/es/es-mini.yaml': miniDeck,
        'decks/ja/ja-broken.yaml': brokenDeck,
      });
      expect(catalog.decks, hasLength(1));
      expect(catalog.broken, hasLength(1));
      final broken = catalog.broken.single;
      expect(broken.path, 'decks/ja/ja-broken.yaml');
      expect(broken.fileName, 'ja-broken.yaml');
      expect(broken.error.source, 'ja-broken.yaml');
      expect(broken.error.line, 10);
      expect(broken.error.message, contains('boolean'));
    });

    test('a second deck with the same id is reported, not merged', () {
      final catalog = DeckCatalog.parseAll({
        'decks/es/a.yaml': miniDeck,
        'decks/es/b.yaml': miniDeck,
      });
      expect(catalog.decks.map((d) => d.path), ['decks/es/a.yaml']);
      expect(catalog.broken.single.path, 'decks/es/b.yaml');
      expect(catalog.broken.single.error.message, contains('decks/es/a.yaml'));
    });

    test('an empty or non-YAML file is a broken deck, not a crash', () {
      final catalog = DeckCatalog.parseAll({
        'decks/x/empty.yaml': '',
        'decks/x/junk.yaml': '{ not: yaml',
      });
      expect(catalog.decks, isEmpty);
      expect(catalog.broken, hasLength(2));
    });

    test('the glyph is the first grapheme, not the first code unit', () {
      final catalog = DeckCatalog.parseAll({'decks/es/m.yaml': miniDeck});
      expect(catalog.decks.single.glyph, 'ñ');
      expect(catalog.decks.single.isScript, isTrue);
    });
  });

  group('sources', () {
    test('a memory source loads like the bundle does', () async {
      final catalog = await DeckCatalog(
        MemoryDeckSource({'decks/es/m.yaml': miniDeck}),
      ).load();
      expect(catalog.byId('xx-mini'), isNotNull);
      expect(catalog.byId('nope'), isNull);
    });

    test('load() is memoised until invalidated', () async {
      final catalog = DeckCatalog(MemoryDeckSource({'decks/m.yaml': miniDeck}));
      final first = await catalog.load();
      expect(identical(await catalog.load(), first), isTrue);
      catalog.invalidate();
      expect(identical(await catalog.load(), first), isFalse);
    });

    test('only YAML under decks/ counts as a deck path', () {
      expect(AssetDeckSource.isDeckPath('decks/es/es-core-100.yaml'), isTrue);
      expect(AssetDeckSource.isDeckPath('decks/README.md'), isFalse);
      expect(AssetDeckSource.isDeckPath('fonts/x.yaml'), isFalse);
    });

    test('the asset manifest lists the bundled decks', () async {
      final paths = await AssetDeckSource(rootBundle).list();
      expect(paths, contains('decks/es/es-core-100.yaml'));
      expect(paths.every(AssetDeckSource.isDeckPath), isTrue);
    });
  });
}
