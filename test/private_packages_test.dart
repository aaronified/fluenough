import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/private_import.dart';
import 'package:fluenough/app/private_store.dart';
import 'package:fluenough/core/backup/zip_files.dart';
import 'package:fluenough/core/private/private_manifest.dart';
import 'package:fluenough/core/private/private_package.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/private_fixture.dart';
import 'support/private_zip.dart';

// Private packages, second slice (#1017, Plan-Private-Languages tasks 10 to
// 13): a `.fnzip` opened and checked, a private path that replaces the
// built-in one, retired ids, and the cap of three active packages.

Future<Catalog> _catalogOf(
  PrivateStore store, [
  Map<String, String> builtIn = const <String, String>{},
]) => DeckCatalog(MemoryDeckSource(builtIn), privateStore: store).load();

Future<PrivateImportResult> _import(
  Map<String, String> files,
  PrivateStore store, {
  Map<String, String> builtIn = const <String, String>{},
  bool allowLowerRevision = false,
  bool? active,
}) => importPrivatePackage(
  files,
  store: store,
  appVersion: '0.10.0',
  builtIn: builtIn,
  allowLowerRevision: allowLowerRevision,
  active: active,
);

Map<String, String> _revision(Map<String, String> files, int n) => {
  ...files,
  'manifest.yaml': files['manifest.yaml']!.replaceFirst(
    'revision: 1',
    'revision: $n',
  ),
};

/// [files] without the food card `fnpd-qaa-0006`, in its core and its layer.
Map<String, String> _withoutSalt(Map<String, String> files) => {
  ...files,
  'qaa/fnpd-qaa-food.yaml': files['qaa/fnpd-qaa-food.yaml']!.replaceFirst(
    RegExp(r'  - id: "fnpd-qaa-0006"[\s\S]*$'),
    '',
  ),
  'qaa/en/fnpd-qaa-en-food.yaml': files['qaa/en/fnpd-qaa-en-food.yaml']!
      .replaceFirst(RegExp(r'  "fnpd-qaa-0006":[\s\S]*$'), ''),
};

void main() {
  late Map<String, String> tiny;
  setUp(() async => tiny = await tinyPackage());

  group('a .fnzip to staging (task 10)', () {
    test('opens a deflated archive, counts it and installs it', () async {
      final store = MemoryPrivateStore();
      final result = await importPrivateArchive(
        buildZip(specsOf(tiny)),
        store: store,
        appVersion: '0.10.0',
      );
      expect(result.problems, isEmpty);
      expect(result.installed, isTrue);
      expect(result.manifest!.package, 'fnpd-qaa');
      final c = result.counts!;
      expect((c.files, c.decks, c.layers, c.cards, c.units), (6, 2, 2, 6, 2));
      final catalog = await _catalogOf(store);
      expect(catalog.broken, isEmpty);
      expect(catalog.paths['qaa/en']!.units.first, <String>[
        'fnpd-qaa-en-home',
      ]);
    });

    test('staging checks and counts without installing', () async {
      final store = MemoryPrivateStore();
      final staging = await stagePrivateArchive(
        ZipFiles.encode({
          for (final e in tiny.entries) e.key: utf8.encode(e.value),
        }),
        store: store,
        appVersion: '0.10.0',
      );
      expect(staging.canInstall, isTrue);
      expect(staging.files.keys, containsAll(tiny.keys));
      expect(await store.packages(), isEmpty);
    });

    test('an archive over 10 MB is refused before it is opened', () async {
      final store = MemoryPrivateStore();
      final result = await importPrivateArchive(
        Uint8List(10 * 1024 * 1024 + 1),
        store: store,
        appVersion: '0.10.0',
      );
      expect(result.installed, isFalse);
      expect(result.findings.single.token, 'archiveTooBig');
      expect(await store.packages(), isEmpty);
    });

    test('an unsafe or a damaged archive is refused', () async {
      final store = MemoryPrivateStore();
      final traversal = await importPrivateArchive(
        buildZip(<ZipSpec>[
          ...specsOf(tiny),
          ZipSpec('../escape.yaml', utf8.encode('a: 1')),
        ]),
        store: store,
        appVersion: '0.10.0',
      );
      expect(traversal.installed, isFalse);
      expect(traversal.findings.single.token, 'zipUnsafe');
      final junk = await importPrivateArchive(
        utf8.encode('this is not a zip file at all, just text'),
        store: store,
        appVersion: '0.10.0',
      );
      expect(junk.findings.single.token, 'zipUnsafe');
      expect(await store.packages(), isEmpty);
    });

    test(
      'a file of the wrong type or encoding is refused at level 0',
      () async {
        final store = MemoryPrivateStore();
        final result = await importPrivateArchive(
          buildZip(<ZipSpec>[
            ...specsOf(tiny),
            const ZipSpec('qaa/logo.png', <int>[1, 2, 3]),
          ]),
          store: store,
          appVersion: '0.10.0',
        );
        expect(result.findings.map((f) => f.token), contains('fileType'));
        expect(result.installed, isFalse);
      },
    );

    test('a lower revision of an installed package is refused', () async {
      final store = MemoryPrivateStore();
      expect((await _import(_revision(tiny, 3), store)).installed, isTrue);
      final lower = await _import(_revision(tiny, 2), store);
      expect(lower.installed, isFalse);
      expect(lower.findings.single.token, 'revisionLower');
      expect((await store.packages()).single.revision, 3);
      // The same revision again is a reinstall; a lower one needs the
      // learner's confirm.
      expect((await _import(_revision(tiny, 3), store)).installed, isTrue);
      expect(
        (await _import(
          _revision(tiny, 2),
          store,
          allowLowerRevision: true,
        )).installed,
        isTrue,
      );
      expect((await store.packages()).single.revision, 2);
    });

    test('warnings are told and the package is installed', () async {
      final files = {
        ...tiny,
        'manifest.yaml': tiny['manifest.yaml']!.replaceFirst(
          'script: "latin"',
          'script: "devanagari"',
        ),
      };
      final result = await _import(files, MemoryPrivateStore());
      expect(result.installed, isTrue);
      expect(result.warnings.map((f) => f.token), contains('readingMissing'));
      expect(result.problems, isEmpty);
    });

    test('level 2 findings refuse a package that parses', () async {
      final files = {
        ...tiny,
        'qaa-path.yaml': tiny['qaa-path.yaml']!.replaceFirst(
          '"fnpd-qaa-food"',
          '"fnpd-qaa-nope"',
        ),
      };
      final store = MemoryPrivateStore();
      final result = await _import(files, store);
      expect(result.installed, isFalse);
      expect(result.findings.single.token, 'pathUnitDeck');
      expect(await store.packages(), isEmpty);
    });
  });

  group('a private path replaces the built-in one (task 11)', () {
    late Map<String, String> builtIn;
    late Map<String, String> te;
    setUp(() {
      builtIn = tinyBuiltInTelugu(tiny);
      // The private path puts the built-in food unit first, then its own
      // home deck.
      te = asTelugu(tiny);
      te['te-path.yaml'] = te['te-path.yaml']!
          .replaceFirst('"fnpd-te-home"', '"te-food"')
          .replaceFirst('"fnpd-te-food"', '"fnpd-te-home"');
    });

    test('a modified te path wins while active, marked, and inactive falls '
        'back', () async {
      final alone = await _catalogOf(MemoryPrivateStore(), builtIn);
      expect(alone.broken, isEmpty);
      expect(alone.paths['te/en']!.units, [
        ['te-en-home'],
        ['te-en-food'],
      ]);
      expect(alone.paths['te/en']!.privatelyModified, isFalse);

      final store = MemoryPrivateStore();
      final result = await _import(te, store, builtIn: builtIn);
      expect(result.problems, isEmpty);
      expect(result.manifest!.kind, PrivateKind.modifiedLanguage);

      final both = await _catalogOf(store, builtIn);
      expect(both.broken, isEmpty);
      final path = both.paths['te/en']!;
      expect(path.units, [
        ['te-en-food'],
        ['fnpd-te-en-home'],
      ]);
      expect(path.privatelyModified, isTrue);
      expect(both.languagePaths['te']!.privatelyModified, isTrue);
      // The built-in decks and the package's are all there, each its own.
      expect(both.byId('te-en-home')!.private, isFalse);
      expect(both.byId('fnpd-te-en-home')!.private, isTrue);

      await store.deactivate('fnpd-te');
      final off = await _catalogOf(store, builtIn);
      expect(off.paths['te/en']!.units, alone.paths['te/en']!.units);
      expect(off.paths['te/en']!.privatelyModified, isFalse);
    });

    test('a new language\'s own path is not marked as modified', () async {
      final store = MemoryPrivateStore();
      await _import(tiny, store);
      final path = (await _catalogOf(store)).paths['qaa/en']!;
      expect(path.privatelyModified, isFalse);
    });

    test('a real language code is for a modified language only', () async {
      final asNew = asTelugu(tiny, kind: 'new-language');
      final refused = await _import(asNew, MemoryPrivateStore());
      expect(refused.installed, isFalse);
      expect(refused.problems.join(' '), contains('language.code'));
      // And a free private-use code modifies nothing.
      final qaaModified = {
        ...tiny,
        'manifest.yaml': tiny['manifest.yaml']!.replaceFirst(
          'new-language',
          'modified-language',
        ),
      };
      final nothing = await _import(qaaModified, MemoryPrivateStore());
      expect(nothing.installed, isFalse);
      expect(nothing.problems.join(' '), contains('language.code'));
    });

    test('a language the app does not teach cannot be modified', () async {
      final result = await importPrivatePackage(
        te,
        store: MemoryPrivateStore(),
        appVersion: '0.10.0',
        builtIn: builtIn,
        builtInLanguages: const <String>{'hi', 'bn'},
      );
      expect(result.installed, isFalse);
      expect(result.findings.single.token, 'languageUnknown');
    });

    test('a modified language without its path is refused', () async {
      final noPath = {...te}..remove('te-path.yaml');
      final result = await _import(
        noPath,
        MemoryPrivateStore(),
        builtIn: builtIn,
      );
      expect(result.installed, isFalse);
      expect(result.findings.map((f) => f.token), contains('pathMissing'));
    });

    test('a package can never reach a built-in card id', () async {
      final builtInShaped = {
        for (final e in te.entries)
          e.key: e.value.replaceAll('fnpd-te-0001', 'te-0001'),
      };
      final store = MemoryPrivateStore();
      final result = await _import(builtInShaped, store, builtIn: builtIn);
      expect(result.installed, isFalse);
      expect(result.problems.join(' '), contains('must start with fnpd-te-'));
      expect(await store.packages(), isEmpty);
    });

    test('a package that sneaks in a second path breaks only itself', () {
      final catalog = DeckCatalog.parseAll(<String, String>{
        ...builtIn,
        for (final e in te.entries)
          if (e.key != 'manifest.yaml') 'private/fnpd-te/${e.key}': e.value,
        'private/fnpd-te/te/extra-path.yaml': te['te-path.yaml']!,
      });
      expect(catalog.broken, hasLength(1));
      expect(
        catalog.broken.single.error.message,
        contains('already has a path'),
      );
      expect(catalog.paths['te/en']!.privatelyModified, isTrue);
    });
  });

  group('retired ids (task 12)', () {
    test('an update that drops a card records its id', () async {
      final store = MemoryPrivateStore();
      expect((await _import(tiny, store)).installed, isTrue);
      expect((await store.packages()).single.retired, isEmpty);

      final staging = await stagePrivateFiles(
        _revision(_withoutSalt(tiny), 2),
        store: store,
        appVersion: '0.10.0',
      );
      expect(staging.dropped, ['fnpd-qaa-0006']);
      final done = await installStaged(staging, store: store);
      expect(done.installed, isTrue);
      expect((await store.packages()).single.retired, ['fnpd-qaa-0006']);
      // The retired list survives an update that drops nothing more.
      await _import(_revision(_withoutSalt(tiny), 3), store);
      expect((await store.packages()).single.retired, ['fnpd-qaa-0006']);
    });

    test('a later revision that gives the id to a card is an error', () async {
      final store = MemoryPrivateStore();
      await _import(tiny, store);
      await _import(_revision(_withoutSalt(tiny), 2), store);
      // Revision 3 puts a different card under the retired id.
      final reused = _revision(tiny, 3);
      final result = await _import({
        ...reused,
        'qaa/fnpd-qaa-food.yaml': reused['qaa/fnpd-qaa-food.yaml']!
            .replaceFirst('"sika"', '"other"'),
      }, store);
      expect(result.installed, isFalse);
      final f = result.findings.single;
      expect(f.token, 'retiredReused');
      expect(f.params['id'], 'fnpd-qaa-0006');
      expect((await store.packages()).single.revision, 2);
    });

    test('a file store keeps the retired ids across launches', () async {
      final dir = await Directory.systemTemp.createTemp('fnpd-retired');
      addTearDown(() => dir.delete(recursive: true));
      final first = FilePrivateStore(dir);
      await _import(tiny, first);
      await _import(_revision(_withoutSalt(tiny), 2), first);
      final again = FilePrivateStore(dir);
      expect((await again.packages()).single.retired, ['fnpd-qaa-0006']);
      expect(await again.readPackage('fnpd-qaa'), isNotNull);
    });
  });

  group('the active cap and activate or deactivate (task 13)', () {
    Future<void> three(PrivateStore store) async {
      for (final code in <String>['qaa', 'qab', 'qac']) {
        final r = await _import(asCode(tiny, code), store);
        expect(r.installed, isTrue, reason: code);
      }
    }

    test(
      'a fourth install returns NeedsDeactivation and writes nothing',
      () async {
        final store = MemoryPrivateStore();
        await three(store);
        final fourth = await _import(asCode(tiny, 'qad'), store);
        expect(fourth.outcome, PrivateImportOutcome.needsDeactivation);
        expect(fourth.active.map((p) => p.id), [
          'fnpd-qaa',
          'fnpd-qab',
          'fnpd-qac',
        ]);
        expect(await store.packages(), hasLength(3));
        // The learner deactivates one, and the install goes through.
        expect(await store.deactivate('fnpd-qab'), isTrue);
        expect((await _import(asCode(tiny, 'qad'), store)).installed, isTrue);
        expect(
          (await store.packages()).where((p) => p.active).map((p) => p.id),
          ['fnpd-qaa', 'fnpd-qac', 'fnpd-qad'],
        );
      },
    );

    test('a package can be installed inactive past the cap', () async {
      final store = MemoryPrivateStore();
      await three(store);
      final result = await _import(asCode(tiny, 'qad'), store, active: false);
      expect(result.installed, isTrue);
      expect(
        (await store.packages()).firstWhere((p) => p.id == 'fnpd-qad').active,
        isFalse,
      );
      // Activating it asks again, until one is deactivated.
      expect(
        await store.activate('fnpd-qad'),
        PrivateActivation.needsDeactivation,
      );
      await store.deactivate('fnpd-qaa');
      expect(await store.activate('fnpd-qad'), PrivateActivation.done);
      expect(await store.activate('fnpd-nope'), PrivateActivation.notInstalled);
    });

    test('updating an active package is not a fourth', () async {
      final store = MemoryPrivateStore();
      await three(store);
      final again = await _import(_revision(asCode(tiny, 'qab'), 2), store);
      expect(again.installed, isTrue);
      expect(
        (await store.packages()).firstWhere((p) => p.id == 'fnpd-qab').revision,
        2,
      );
    });

    test('the file store enforces the cap and keeps what is active', () async {
      final dir = await Directory.systemTemp.createTemp('fnpd-cap');
      addTearDown(() => dir.delete(recursive: true));
      final store = FilePrivateStore(dir);
      await three(store);
      final fourth = await _import(asCode(tiny, 'qad'), store);
      expect(fourth.outcome, PrivateImportOutcome.needsDeactivation);
      expect(Directory('${dir.path}/fnpd-qad').existsSync(), isFalse);
      await store.deactivate('fnpd-qaa');
      final restarted = FilePrivateStore(dir);
      expect(
        (await _catalogOf(restarted)).languages.map((l) => l.code),
        unorderedEquals(<String>['qab', 'qac']),
      );
      expect(await restarted.activate('fnpd-qaa'), PrivateActivation.done);
      expect((await restarted.packages()).every((p) => p.active), isTrue);
    });
  });
}
