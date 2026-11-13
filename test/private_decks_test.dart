import 'dart:io';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_import.dart';
import 'package:fluenough/app/private_import.dart';
import 'package:fluenough/app/private_store.dart';
import 'package:fluenough/core/private/private_ids.dart';
import 'package:fluenough/core/private/private_manifest.dart';
import 'package:fluenough/core/private/private_package.dart';
import 'package:flutter_test/flutter_test.dart';

// Private language packages, first slice (#1017, Plan-Private-Languages,
// tasks 1 to 6): the id rules, the manifest, the catalog reading `private/`,
// the store, and an import that ends with the first unit on screen.

const String _fixture = 'test/fixtures/private/qaa-tiny';

Future<Map<String, String>> _tiny() async {
  final files = await readPackageFolder(Directory(_fixture));
  return files ?? (throw StateError('the fixture could not be read'));
}

Future<Catalog> _catalogOf(PrivateStore store) => DeckCatalog(
  MemoryDeckSource(const <String, String>{}),
  privateStore: store,
).load();

void main() {
  group('private ids', () {
    test('only an id that starts fnpd-<code>- is private to that code', () {
      expect(hasPrivatePrefix('fnpd-qaa-0001', 'qaa'), isTrue);
      expect(hasPrivatePrefix('fnpd-te-home', 'te'), isTrue);
      expect(hasPrivatePrefix('qaa-0001', 'qaa'), isFalse);
      expect(hasPrivatePrefix('fnpd-QAA-0001', 'qaa'), isFalse);
      expect(hasPrivatePrefix('fnpd-qaa-', 'qaa'), isFalse);
      expect(hasPrivatePrefix('fnpd-qab-0001', 'qaa'), isFalse);
      expect(hasPrivatePrefix('', 'qaa'), isFalse);
      expect(packageCode('fnpd-qaa-0001'), 'qaa');
      expect(packageCode('te-0001'), isNull);
      expect(languageOfId('fnpd-qaa-0001'), 'qaa');
      expect(languageOfId('te-0001'), 'te');
    });

    test('the private-use codes are qaa to qtz', () {
      expect(isPrivateCode('qaa'), isTrue);
      expect(isPrivateCode('qtz'), isTrue);
      expect(isPrivateCode('qua'), isFalse);
      // A real code would sit beside the built-in language of that code, so
      // slice 1 refuses it (modified-language packages are plan task 11).
      expect(isPrivateCode('te'), isFalse, reason: 'te is a built-in code');
      expect(isPrivateCode('en'), isFalse);
      expect(isPrivateCode('abc'), isFalse);
      expect(isPrivateCode('QAA'), isFalse);
    });

    test('languageOfId is the first segment of every public id', () {
      const ids = <String>[
        'te-0001',
        'bn-0002',
        'zz-en-words',
        'hi-en-core-100',
        'hi-perso-arabic-script',
        'zz-en-a-b-c-d',
        'zz-',
        'nodash',
        'te',
        '-x',
        'fnp-1',
        'fnpd',
      ];
      for (final id in ids) {
        expect(languageOfId(id), id.split('-').first, reason: id);
      }
      expect(languageOfId('fnpd-qaa-0001'), 'qaa');
      expect(languageOfId('fnpd-qaa-en-words'), 'qaa');
    });

    test('a code a built-in language uses is not private', () {
      final yaml = File('assets/languages.yaml').readAsStringSync();
      final used = RegExp(r'code: "(q[a-z]{2})"')
          .allMatches(yaml)
          .map((m) => m[1]!)
          .toSet();
      expect(used, isNotEmpty);
      for (final code in used) {
        expect(isPrivateCode(code), isFalse, reason: code);
      }
    });
  });

  group('the manifest', () {
    Future<String> text() async =>
        File('$_fixture/manifest.yaml').readAsString();

    test('reads the fixture', () async {
      final manifest = PrivateManifest.parse(await text());
      expect(manifest.package, 'fnpd-qaa');
      expect(manifest.revision, 1);
      expect(manifest.kind, PrivateKind.newLanguage);
      expect(manifest.language.code, 'qaa');
    });

    test('names the field that is wrong', () async {
      final good = await text();
      void refuses(String edited, String field) => expect(
        () => PrivateManifest.parse(edited),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(field),
          ),
        ),
      );
      refuses(good.replaceFirst('package: "fnpd-qaa"\n', ''), '"package"');
      refuses(good.replaceFirst('"fnpd-qaa"', '"qaa"'), '"package"');
      refuses(
        good.replaceFirst('code: "qaa"', 'code: "qua"'),
        '"language.code"',
      );
      refuses(good.replaceFirst('CC-BY-SA-4.0', 'MIT'), '"license"');
    });
  });

  group('importing a private language', () {
    test('installs the fixture and shows unit 1 with its cards', () async {
      final store = MemoryPrivateStore();
      final result = await importPrivatePackage(
        await _tiny(),
        store: store,
        appVersion: '0.9.0',
      );
      expect(result.problems, isEmpty);
      expect(result.installed, isTrue);

      final catalog = await _catalogOf(store);
      expect(catalog.broken, isEmpty);
      expect(catalog.languages.map((l) => l.code), contains('qaa'));
      final path = catalog.paths['qaa/en']!;
      expect(path.units.first, <String>['fnpd-qaa-en-home']);
      final home = catalog.byId('fnpd-qaa-en-home')!;
      expect(home.private, isTrue);
      expect(home.bundled, isFalse);
      expect(
        home.cards.map((c) => (c.id, c.target, c.native)),
        <(String, String, String)>[
          ('fnpd-qaa-0001', 'kolu', 'house'),
          ('fnpd-qaa-0002', 'mira', 'door'),
          ('fnpd-qaa-0003', 'tepa', 'roof'),
        ],
      );
    });

    test('an inactive package is not read at all', () async {
      final store = MemoryPrivateStore();
      await importPrivatePackage(
        await _tiny(),
        store: store,
        appVersion: '0.9.0',
      );
      await store.deactivate('fnpd-qaa');
      expect((await _catalogOf(store)).decks, isEmpty);
      expect((await store.packages()).single.active, isFalse);
    });

    test('a built-in-shaped id is refused, and nothing is installed', () async {
      final files = <String, String>{
        for (final e in (await _tiny()).entries)
          e.key: e.value.replaceAll('fnpd-qaa-0001', 'qaa-0001'),
      };
      final store = MemoryPrivateStore();
      final result = await importPrivatePackage(
        files,
        store: store,
        appVersion: '0.9.0',
      );
      expect(result.installed, isFalse);
      expect(result.problems.join(' '), contains('must start with fnpd-qaa-'));
      expect(await store.packages(), isEmpty);
    });

    test(
      'a package without a manifest, or for a newer app, is refused',
      () async {
        final store = MemoryPrivateStore();
        final files = await _tiny();
        final bare = Map<String, String>.of(files)..remove('manifest.yaml');
        expect(
          (await importPrivatePackage(
            bare,
            store: store,
            appVersion: '0.9.0',
          )).installed,
          isFalse,
        );
        expect(
          (await importPrivatePackage(
            files,
            store: store,
            appVersion: '0.8.0',
          )).installed,
          isFalse,
        );
        expect(await store.packages(), isEmpty);
      },
    );
  });

  group('private decks keep their mark and their place', () {
    String deck(String id, String cards) =>
        '''
schema: 1
id: "$id"
name: "Lines"
language: { code: "qaa", iso639_3: "qaa", name: "Tiny", script: "latin" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
cards:
$cards''';

    test('a deck that lists a card by ref is still private', () {
      final catalog = DeckCatalog.parseAll(<String, String>{
        'private/fnpd-qaa/qaa/fnpd-qaa-words.yaml': deck(
          'fnpd-qaa-words',
          '  - { id: "fnpd-qaa-0001", target: "kolu", native: "house" }\n',
        ),
        'private/fnpd-qaa/qaa/fnpd-qaa-lines.yaml': deck(
          'fnpd-qaa-lines',
          '  - { id: "fnpd-qaa-0002", target: "mira", native: "door" }\n'
              '  - { ref: "fnpd-qaa-0001" }\n',
        ),
      });
      expect(catalog.broken, isEmpty);
      final lines = catalog.byId('fnpd-qaa-lines')!;
      expect(lines.cards, hasLength(2));
      expect(lines.private, isTrue);
      expect(lines.bundled, isFalse);
    });

    test(
      'a private path of another language does not take over its course',
      () async {
        final files = <String, String>{
          for (final e in (await _tiny()).entries)
            e.key: e.key == 'qaa-path.yaml'
                ? e.value
                      .replaceAll('language: "qaa"', 'language: "te"')
                      .replaceAll('id: "qaa-path"', 'id: "te-path"')
                      .replaceAll('fnpd-qaa-', 'te-')
                : e.value,
        };
        final result = await importPrivatePackage(
          files,
          store: MemoryPrivateStore(),
          appVersion: '0.9.0',
        );
        expect(result.installed, isFalse);
        expect(result.problems.join(' '), contains('is for qaa'));
      },
    );

    test('a private id cannot be added or downloaded outside a package', () {
      const text = '''
schema: 1
id: "fnpd-qaa-x"
name: "X"
language: { code: "qaa", iso639_3: "qaa", name: "Tiny", script: "latin" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
cards:
  - { id: "fnpd-qaa-0001", target: "kolu", native: "house" }
''';
      expect(
        checkAddedDeck(text, fileName: 'x.yaml', decks: const <DeckEntry>[]),
        isA<DeckUnreadable>(),
      );
      expect(DeckCatalog.checkFile('decks/qaa/x.yaml', text), isNotNull);
    });
  });

  group('a private package cannot take a built-in code or guide', () {
    test('a package with code te is refused at import', () async {
      final files = <String, String>{
        for (final e in (await _tiny()).entries)
          if (e.key == 'manifest.yaml')
            e.key: e.value
                .replaceAll('"qaa"', '"te"')
                .replaceAll('fnpd-qaa', 'fnpd-te')
          else
            e.key: e.value,
      };
      final store = MemoryPrivateStore();
      final result = await importPrivatePackage(
        files,
        store: store,
        appVersion: '0.9.0',
      );
      expect(result.installed, isFalse);
      expect(result.problems.join(' '), contains('language.code'));
      expect(await store.packages(), isEmpty);
    });

    test('a package cannot take a code a built-in language uses', () {
      for (final code in builtInPrivateUseCodes) {
        expect(isPrivateCode(code), isFalse, reason: code);
      }
    });

    test('a private sounds or script layer does not replace the built-in '
        'one', () {
      String read(String path) => File(path).readAsStringSync();
      final builtIn = <String, String>{
        'decks/te/te-sounds.yaml': read('decks/te/te-sounds.yaml'),
        'decks/te/en/te-en-sounds.yaml': read('decks/te/en/te-en-sounds.yaml'),
        'decks/te/te-script.yaml': read('decks/te/te-script.yaml'),
        'decks/te/en/te-en-script.yaml': read('decks/te/en/te-en-script.yaml'),
      };
      final alone = DeckCatalog.parseAll(builtIn);
      expect(alone.sounds['te'], isNotNull);
      final soundName = alone.sounds['te']!.contrasts.first.name;
      final guideName = alone.scriptGuides.values.first.name;

      // The same files again under a private package of the built-in code,
      // with their text changed, which sort after the built-in ones.
      final both = <String, String>{
        ...builtIn,
        for (final e in builtIn.entries)
          'private/fnpd-te/${e.key.substring('decks/'.length)}': e.value
              .replaceAll('a short or a long vowel', 'PRIVATE SOUND')
              .replaceAll('How Telugu script works', 'PRIVATE GUIDE'),
      };
      final catalog = DeckCatalog.parseAll(both);
      expect(catalog.sounds['te']!.contrasts.first.name, soundName);
      expect(catalog.scriptGuides.values.first.name, guideName);
      expect(soundName, isNot('PRIVATE SOUND'));
      expect(guideName, isNot('PRIVATE GUIDE'));
    });
  });

  group('the file store', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('fnpd-store'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('keeps a package across launches, and replaces it whole', () async {
      final files = await _tiny();
      final first = FilePrivateStore(dir);
      expect(
        await first.install(
          'fnpd-qaa',
          files,
          revision: 1,
          kind: 'new-language',
        ),
        PrivateInstall.installed,
      );
      final again = FilePrivateStore(dir);
      final paths = await again.list();
      expect(paths, contains('private/fnpd-qaa/qaa/fnpd-qaa-home.yaml'));
      expect(paths.any((p) => p.endsWith('manifest.yaml')), isFalse);
      expect((await _catalogOf(again)).paths['qaa/en'], isNotNull);

      final fewer = Map<String, String>.of(files)
        ..remove('qaa/fnpd-qaa-food.yaml')
        ..remove('qaa/en/fnpd-qaa-en-food.yaml');
      await again.install('fnpd-qaa', fewer, revision: 2, kind: 'new-language');
      expect((await again.list()).any((p) => p.contains('food')), isFalse);
      expect((await again.packages()).single.revision, 2);
      expect(Directory('${dir.path}/staging').existsSync(), isFalse);
    });

    test(
      'refuses a file named outside its folder and keeps what was there',
      () async {
        final store = FilePrivateStore(dir);
        await store.install(
          'fnpd-qaa',
          await _tiny(),
          revision: 1,
          kind: 'new-language',
        );
        final bad = <String, String>{'../escape.yaml': 'x: 1'};
        expect(
          await store.install(
            'fnpd-qaa',
            bad,
            revision: 2,
            kind: 'new-language',
          ),
          PrivateInstall.failed,
        );
        expect((await store.packages()).single.revision, 1);
        expect(File('${dir.path}/escape.yaml').existsSync(), isFalse);
      },
    );

    test(
      'puts a package back after a crash while it was moved aside',
      () async {
        final store = FilePrivateStore(dir);
        await store.install(
          'fnpd-qaa',
          await _tiny(),
          revision: 1,
          kind: 'new-language',
        );
        // The crash: the package was moved to staging, the new one not yet in.
        Directory('${dir.path}/staging').createSync();
        Directory('${dir.path}/fnpd-qaa')
            .renameSync('${dir.path}/staging/fnpd-qaa.old');
        final restarted = FilePrivateStore(dir);
        expect(await restarted.list(), isNotEmpty);
        expect(Directory('${dir.path}/staging').existsSync(), isFalse);
      },
    );

    test('keeps no package under the name staging', () async {
      final store = FilePrivateStore(dir);
      expect(
        await store.install(
          'staging',
          await _tiny(),
          revision: 1,
          kind: 'new-language',
        ),
        PrivateInstall.failed,
      );
    });
  });
}
