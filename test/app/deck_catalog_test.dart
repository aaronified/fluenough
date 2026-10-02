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
          // Facts, themes, number rules, course paths and sounds files sit
          // beside the decks but are not decks.
          .where(
            (p) => !{
              'facts',
              'themes',
              'numbers',
              'path',
              'sounds',
              'script',
            }.contains(DeckCatalog.kindOf(File(p).readAsStringSync())),
          )
          .toSet();
      expect(onDisk, isNotEmpty);
      expect(catalog.broken, isEmpty, reason: '${catalog.broken}');
      expect(catalog.decks.map((d) => d.path).toSet(), onDisk);
    });

    test('each language with number decks has its number rules (#54)', () {
      expect(catalog.numberRules.keys, containsAll(<String>['hi', 'bn', 'te']));
      expect(catalog.numberRules['te']!.tensAndUnits, isTrue);
      expect(catalog.numberRules['hi']!.tensAndUnits, isFalse);
    });

    test('the shared theme path is bundled and read', () {
      expect(catalog.themes.first.id, 'first-words');
      expect(catalog.themes.map((t) => t.id), contains('market'));
      expect(catalog.themeById('groceries')!.name, 'Groceries');
    });

    test('includes the known decks, in path order, each course\'s theme '
        'decks in theme order', () {
      final ids = catalog.decks.map((d) => d.id).toList();
      expect(
        ids,
        containsAll([
          'es-en-core-100',
          'es-en-grammar-present-ar',
          'ja-en-hiragana',
        ]),
      );
      final paths = catalog.decks.map((d) => d.path).toList();
      expect(paths.toSet(), hasLength(paths.length));

      final path = [for (final t in catalog.themes) t.id];
      final courses = <String, List<String>>{};
      for (final d in catalog.decks) {
        final theme = d.deck.theme;
        if (theme == null) continue;
        courses
            .putIfAbsent('${d.language.code}-${d.deck.native.code}', () => [])
            .add(theme);
      }
      expect(courses, contains('hi-en'));
      for (final MapEntry(key: course, value: themes) in courses.entries) {
        expect(themes, [
          for (final t in path)
            if (themes.contains(t)) t,
        ], reason: course);
      }
    });

    test('every course has a path, which lists all its decks and only '
        'them, and its decks come in that order (#117)', () {
      final byCourse = <String, List<String>>{};
      for (final d in catalog.decks) {
        byCourse
            .putIfAbsent('${d.language.code}/${d.deck.native.code}', () => [])
            .add(d.id);
      }
      expect(catalog.paths.keys.toSet(), byCourse.keys.toSet());
      for (final MapEntry(key: course, value: ids) in byCourse.entries) {
        expect(ids, catalog.paths[course]!.deckIds.toList(), reason: course);
      }
      final hindi = catalog.byId('hi-en-addressing')!;
      expect(catalog.pathOf(hindi)!.id, 'hi-en-path');
      expect(
        catalog.pathOf(hindi)!.units[catalog.pathOf(hindi)!.unitOf(hindi.id)!],
        contains('hi-en-grammar-pronouns'),
      );
    });

    test('a grammar deck is listed with its pattern, expanded to cards', () {
      final grammar = catalog.byId('es-en-grammar-present-ar')!;
      expect(grammar.deck.kind, DeckKind.grammar);
      expect(grammar.deck.pattern, isNotNull);
      expect(grammar.cards, hasLength(30), reason: '5 lemmas x 6 slots');
      expect(grammar.itemCount, 30);
      expect(grammar.glyph, 'h', reason: 'first grapheme of the first lemma');
    });

    test('script decks are the ones tagged script', () {
      expect(catalog.byId('ja-en-hiragana')!.isScript, isTrue);
      expect(catalog.byId('es-en-core-100')!.isScript, isFalse);
      expect(catalog.byId('ja-en-hiragana')!.glyph, 'あ');
    });

    test('languages come one per code', () {
      final codes = catalog.languages.map((l) => l.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
      expect(codes, containsAll(['es', 'ja']));
    });
  });

  group('parseAll', () {
    test('a broken numbers file is a broken row, not a crash', () {
      final catalog = DeckCatalog.parseAll({
        'decks/es/es-mini.yaml': miniDeck,
        'decks/xx/xx-numbers.yaml': 'schema: 1\nkind: numbers\nid: xx\n',
      });
      expect(catalog.decks.map((d) => d.id), ['xx-mini']);
      expect(catalog.numberRules, isEmpty);
      expect(catalog.broken.single.fileName, 'xx-numbers.yaml');
    });

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
      expect(
        AssetDeckSource.isDeckPath('decks/es/es-en-core-100.yaml'),
        isTrue,
      );
      expect(AssetDeckSource.isDeckPath('decks/README.md'), isFalse);
      expect(AssetDeckSource.isDeckPath('fonts/x.yaml'), isFalse);
    });

    test('the asset manifest lists the bundled decks', () async {
      final paths = await AssetDeckSource(rootBundle).list();
      expect(paths, contains('decks/es/es-en-core-100.yaml'));
      expect(paths.every(AssetDeckSource.isDeckPath), isTrue);
    });
  });

  group('themes', () {
    const themes = '''
schema: 1
kind: themes
themes:
  - { id: first-words, name: "First words" }
  - { id: market, name: "Market" }
  - { id: help, name: "Help" }
''';

    String deck(String id, {String? theme, String lang = 'hi'}) =>
        '''
schema: 1
id: $id
name: "$id"
${theme == null ? '' : 'theme: $theme'}
language: { code: $lang, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: $id-0001
    target: "नमस्ते"
    native: "hello"
''';

    test('without a path, a course\'s theme decks come first, in theme order, '
        'then its other decks (#80)', () {
      final catalog = DeckCatalog.parseAll({
        'decks/themes.yaml': themes,
        'decks/hi/hi-en-core.yaml': deck('hi-en-core'),
        'decks/hi/hi-en-help.yaml': deck('hi-en-help', theme: 'help'),
        'decks/hi/hi-en-first-words.yaml': deck(
          'hi-en-first-words',
          theme: 'first-words',
        ),
        'decks/hi/hi-en-market.yaml': deck('hi-en-market', theme: 'market'),
        'decks/ja/ja-en-kana.yaml': deck('ja-en-kana', lang: 'ja'),
      });
      expect(catalog.broken, isEmpty);
      expect(catalog.themes.map((t) => t.id), [
        'first-words',
        'market',
        'help',
      ]);
      expect(catalog.decks.map((d) => d.id), [
        'hi-en-first-words',
        'hi-en-market',
        'hi-en-help',
        'hi-en-core',
        'ja-en-kana',
      ]);
      expect(catalog.paths, isEmpty);
    });

    group('with a path', () {
      Map<String, String> files(String units) => <String, String>{
        'decks/themes.yaml': themes,
        'decks/hi/hi-en-core.yaml': deck('hi-en-core'),
        'decks/hi/hi-en-help.yaml': deck('hi-en-help', theme: 'help'),
        'decks/hi/hi-en-first-words.yaml': deck(
          'hi-en-first-words',
          theme: 'first-words',
        ),
        'decks/hi/hi-en-market.yaml': deck('hi-en-market', theme: 'market'),
        'decks/hi/hi-en-path.yaml': '''
schema: 1
kind: path
id: hi-en-path
language: hi
native: en
units:
$units''',
        'decks/ja/ja-en-kana.yaml': deck('ja-en-kana', lang: 'ja'),
      };

      test('the course\'s decks come in the path\'s order, whatever their '
          'themes', () {
        final catalog = DeckCatalog.parseAll(
          files(
            '  - [hi-en-first-words, hi-en-core]\n'
            '  - [hi-en-help]\n'
            '  - [hi-en-market]\n',
          ),
        );
        expect(catalog.broken, isEmpty);
        expect(catalog.decks.map((d) => d.id), [
          'hi-en-first-words',
          'hi-en-core',
          'hi-en-help',
          'hi-en-market',
          'ja-en-kana',
        ]);
        expect(catalog.paths['hi/en']!.units, [
          ['hi-en-first-words', 'hi-en-core'],
          ['hi-en-help'],
          ['hi-en-market'],
        ]);
        expect(catalog.pathOf(catalog.byId('ja-en-kana')!), isNull);
      });

      test('a deck the path leaves out comes after it, and a deck it names '
          'that does not exist is ignored', () {
        final catalog = DeckCatalog.parseAll(
          files('  - [hi-en-market, hi-en-gone]\n  - [hi-en-help]\n'),
        );
        expect(catalog.decks.map((d) => d.id), [
          'hi-en-market',
          'hi-en-help',
          'hi-en-core',
          'hi-en-first-words',
          'ja-en-kana',
        ]);
      });

      test('a broken path is reported, and the course falls back to its '
          'themes', () {
        final catalog = DeckCatalog.parseAll(files('  - []\n'));
        expect(catalog.broken.single.path, 'decks/hi/hi-en-path.yaml');
        expect(catalog.paths, isEmpty);
        expect(catalog.decks.map((d) => d.id).take(4), [
          'hi-en-first-words',
          'hi-en-market',
          'hi-en-help',
          'hi-en-core',
        ]);
      });
    });

    test('a broken themes file is reported, not fatal', () {
      final catalog = DeckCatalog.parseAll({
        'decks/themes.yaml': 'schema: 1\nkind: themes\nthemes: []\n',
        'decks/hi/hi-en-market.yaml': deck('hi-en-market', theme: 'market'),
      });
      expect(catalog.broken.single.path, 'decks/themes.yaml');
      expect(catalog.decks.single.deck.theme, 'market');
      expect(catalog.themes, isEmpty);
    });
  });
}
