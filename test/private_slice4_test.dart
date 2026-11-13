// Private languages, last slice (#1017, Plan-Private-Languages tasks 19 to
// 21 and the leftovers of slice 3): the deflate writer, a package written
// out as a `.fnzip` and read back, a built-in course turned into a package
// to change, the starter package, the private packages in a backup and their
// restore (retired ids and tombstones honoured), the export and download
// screens, the Yours tag in the language lists, the note about cards that
// replace built-in ones, and the no-voice notice on the course card.

import 'dart:convert';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/backup_files.dart';
import 'package:fluenough/app/backup_store.dart';
import 'package:fluenough/app/backups.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/private_import.dart';
import 'package:fluenough/app/private_languages.dart';
import 'package:fluenough/app/private_store.dart';
import 'package:fluenough/core/backup/zip_files.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/private/private_check.dart';
import 'package:fluenough/core/private/private_export.dart';
import 'package:fluenough/core/private/private_manifest.dart';
import 'package:fluenough/core/private/private_package.dart';
import 'package:fluenough/core/private/private_starter.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/course_card.dart';
import 'package:fluenough/features/decks/path_model.dart';
import 'package:fluenough/features/languages/language_pick_list.dart';
import 'package:fluenough/features/languages/language_views.dart';
import 'package:fluenough/features/private/private_download_page.dart';
import 'package:fluenough/features/private/private_import_page.dart';
import 'package:fluenough/features/private/private_widgets.dart';
import 'package:fluenough/features/settings/your_decks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/private_fixture.dart';

const String _appVersion = '9.9.9';

/// The log of a learner who has answered nothing.
final String _emptyLog = LogJsonl.encode(
  const <LoggedReview>[],
  const <LeechAction>[],
);

late Map<String, String> _tiny;

/// The tiny Telugu course as the app holds it: `decks/te/...` with its path
/// where a real course keeps it.
Map<String, String> _course() {
  final files = tinyBuiltInTelugu(_tiny);
  final path = files.remove('decks/te-path.yaml')!;
  return <String, String>{...files, 'decks/te/te-path.yaml': path};
}

const LanguageInfo _te = LanguageInfo(
  code: 'te',
  iso639_3: 'tel',
  name: 'Tiny',
  script: 'latin',
);

/// The tiny package with its third card dropped, as revision 2.
Map<String, String> _withoutThird(Map<String, String> files) =>
    <String, String>{
      for (final e in files.entries)
        e.key: e.value
            .replaceAll('revision: 1', 'revision: 2')
            .replaceAll(
              '  - id: "fnpd-qaa-0003"\n    target: "tepa"\n'
                  '    ipa: "ˈtepa"\n    pos: "noun"\n    tags: ["home"]\n',
              '',
            )
            .replaceAll('  "fnpd-qaa-0003":\n    native: "roof"\n', ''),
    };

class _Phone {
  _Phone(this.state, this.store, this.files, this.backups);

  final AppState state;
  final MemoryPrivateStore store;
  final FixedBackupFiles files;
  final MemoryBackupStore backups;
}

/// A phone with a private store, a file dialog that saves into memory, and
/// [decks] as its built-in decks.
_Phone _phone({
  Map<String, String> decks = const <String, String>{},
  MemoryPrivateStore? store,
  Set<String> voices = const <String>{},
}) {
  final privateStore = store ?? MemoryPrivateStore();
  final files = FixedBackupFiles();
  final backups = MemoryBackupStore();
  final state = AppState.test(
    decks: MemoryDeckSource(decks),
    privateStore: privateStore,
    backupFiles: files,
    backupStore: backups,
    progress: MemoryProgress(),
    tts: FixedTtsEngine(voices),
  );
  addTearDown(state.dispose);
  return _Phone(state, privateStore, files, backups);
}

Future<void> _install(
  MemoryPrivateStore store,
  Map<String, String> files, {
  bool allowLower = false,
}) async {
  final result = await importPrivatePackage(
    files,
    store: store,
    appVersion: _appVersion,
    allowLowerRevision: allowLower,
  );
  expect(result.installed, isTrue, reason: result.problems.join('; '));
}

Future<PrivateStaging> _stage(
  Map<String, String> files, {
  MemoryPrivateStore? store,
  Map<String, String> builtIn = const <String, String>{},
}) => stagePrivateFiles(
  files,
  store: store ?? MemoryPrivateStore(),
  appVersion: _appVersion,
  builtIn: builtIn,
  builtInLanguages: builtIn.isEmpty ? null : const <String>{'te'},
);

void main() {
  setUpAll(() async => _tiny = await tinyPackage());

  group('the deflate writer', () {
    test('compresses what shrinks and gives the same files back', () {
      final text = <String>[
        for (var i = 0; i < 2000; i++)
          '  - id: "fnpd-qaa-$i"\n    target: "w$i"',
      ].join('\n');
      final files = <String, List<int>>{
        'big.yaml': utf8.encode(text),
        'tiny.yaml': utf8.encode('a: 1\n'),
        'empty.yaml': const <int>[],
      };
      final stored = ZipFiles.encode(files);
      final deflated = ZipFiles.encode(files, deflate: true);
      expect(deflated.length, lessThan(stored.length ~/ 2));
      // The package limits (ratio, size) still read it.
      final back = ZipFiles.decode(deflated, limits: ZipLimits.privatePackage);
      expect(utf8.decode(back['big.yaml']!), text);
      expect(utf8.decode(back['tiny.yaml']!), 'a: 1\n');
      expect(back['empty.yaml'], isEmpty);
    });

    test('is the same bytes for the same files', () {
      final files = <String, List<int>>{
        'a.yaml': utf8.encode('x: ${"y" * 500}'),
      };
      expect(
        ZipFiles.encode(files, deflate: true),
        ZipFiles.encode(files, deflate: true),
      );
    });
  });

  group('a package as a .fnzip', () {
    test('is stable: read back and written again, the same bytes', () {
      final bytes = PrivateExport.archive(_tiny);
      final back = ZipFiles.decode(bytes, limits: ZipLimits.privatePackage);
      expect(back.keys.first, privateManifestFile);
      expect(<String, String>{
        for (final e in back.entries) e.key: utf8.decode(e.value),
      }, _tiny);
      expect(
        PrivateExport.archive(<String, String>{
          for (final e in back.entries) e.key: utf8.decode(e.value),
        }),
        bytes,
      );
    });

    test('imports with no error, and names its file', () async {
      final staging = await stagePrivateArchive(
        PrivateExport.archive(_tiny),
        store: MemoryPrivateStore(),
        appVersion: _appVersion,
      );
      expect(staging.errors, isEmpty);
      expect(staging.canInstall, isTrue);
      expect(staging.counts!.decks, 2);
      expect(PrivateExport.fileName('fnpd-qaa', 3), 'fnpd-qaa-rev3.fnzip');
    });

    test('the starter package imports with no error', () async {
      final staging = await stagePrivateArchive(
        privateStarterArchive(),
        store: MemoryPrivateStore(),
        appVersion: _appVersion,
      );
      expect(staging.errors, isEmpty, reason: staging.errors.join('; '));
      expect(staging.canInstall, isTrue);
      expect(staging.counts!.cards, 6);
      expect(staging.manifest!.package, 'fnpd-qaa');
    });
  });

  group('a built-in course to change', () {
    test('every id is rewritten and the package imports as a changed '
        'course', () async {
      final course = _course();
      final result = PrivateExport.fromBuiltIn(
        language: _te,
        files: <String, String>{
          ...course,
          'decks/te/te-facts.yaml':
              'schema: 1\nkind: "facts"\nlanguage: "te"\n',
        },
        basedOn: 'te-0.10.0',
      );
      expect(result.files.keys.first, privateManifestFile);
      expect(
        result.files.keys,
        containsAll(<String>[
          'te/fnpd-te-home.yaml',
          'te/fnpd-te-food.yaml',
          'te/en/fnpd-te-en-home.yaml',
          'te/en/fnpd-te-en-food.yaml',
          'te-path.yaml',
        ]),
      );
      expect(result.decks, 2);
      expect(result.cards, 6);
      expect(result.skipped, 1, reason: 'the facts file belongs to the app');
      final ids = PrivateCheck.cardIds(result.files);
      expect(ids, hasLength(6));
      expect(ids.every((id) => id.startsWith('fnpd-te-')), isTrue);
      // The path stays the course's own: it still names the built-in decks.
      expect(result.files['te-path.yaml'], course['decks/te/te-path.yaml']);

      final staging = await _stage(result.files, builtIn: course);
      expect(staging.errors, isEmpty, reason: staging.errors.join('; '));
      expect(staging.canInstall, isTrue);
      expect(staging.manifest!.kind, PrivateKind.modifiedLanguage);
      expect(staging.manifest!.basedOn, 'te-0.10.0');
    });

    test('a deck that cannot be rewritten safely is left out with its '
        'layers', () {
      final course = _course();
      const loose =
          'schema: 1\nid: te-loose\npart: "core"\nkind: "vocab"\n'
          'language: { code: "te", iso639_3: "tel", name: "Tiny" }\n'
          'cards:\n  - id: "te-9001"\n    target: "x"\n';
      const layer =
          'schema: 1\nid: "te-en-loose"\nkind: "layer"\ncore: te-loose\n'
          'native: { code: "en", iso639_3: "eng", name: "English" }\n'
          'cards:\n  "te-9001":\n    native: "x"\n';
      final result = PrivateExport.fromBuiltIn(
        language: _te,
        files: <String, String>{
          ...course,
          'decks/te/te-loose.yaml': loose,
          'decks/te/en/te-en-loose.yaml': layer,
        },
        basedOn: 'te-0.10.0',
      );
      expect(result.decks, 2);
      expect(result.skipped, 2);
      expect(result.files.keys.any((k) => k.contains('loose')), isFalse);
    });

    test('a layer that uses YAML aliases is written out in full, so the '
        'package imports', () async {
      final course = _course();
      const layer =
          'schema: 1\nid: "te-en-home"\nkind: "layer"\ncore: "te-home"\n'
          'native: { code: "en", iso639_3: "eng", name: "English" }\n'
          'name: "Home"\nlicense: "CC-BY-SA-4.0"\ncards:\n'
          '  "te-0001":\n    native: "house"\n    notes: &n\n      n1: "a"\n'
          '  "te-0002":\n    native: "door"\n    notes: *n\n'
          '  "te-0003":\n    native: "roof"\n';
      final result = PrivateExport.fromBuiltIn(
        language: _te,
        files: <String, String>{
          ...course,
          'decks/te/en/te-en-home.yaml': layer,
        },
        basedOn: 'te-0.10.0',
      );
      final out = result.files['te/en/fnpd-te-en-home.yaml']!;
      expect(out, isNot(contains('&n')));
      expect(out, isNot(contains('*n')));
      expect(out, contains('fnpd-te-0002'));
      final staging = await _stage(result.files, builtIn: course);
      expect(staging.errors, isEmpty, reason: staging.errors.join('; '));
    });

    test('a course with no copyable deck makes no decks', () {
      final result = PrivateExport.fromBuiltIn(
        language: _te,
        files: const <String, String>{},
        basedOn: 'te-0.10.0',
      );
      expect(result.decks, 0);
    });
  });

  group('cards that replace built-in cards', () {
    test('are counted for the review note, and the parser accepts the '
        'field', () async {
      final course = _course();
      final changed = asTelugu(_tiny);
      final home = changed.keys.firstWhere(
        (k) => k.endsWith('fnpd-te-home.yaml'),
      );
      changed[home] = changed[home]!.replaceFirst(
        '  - id: "fnpd-te-0001"\n',
        '  - id: "fnpd-te-0001"\n    replaces: "te-0001"\n',
      );
      final staging = await _stage(changed, builtIn: course);
      expect(staging.errors, isEmpty, reason: staging.errors.join('; '));
      expect(staging.counts!.replacing, 1);
      expect(staging.counts!.byReference, 0);
    });
  });

  group('private packages in a backup', () {
    BackupPrivatePackage package({
      String id = 'fnpd-qaa',
      bool active = true,
      List<String> retired = const <String>[],
    }) => BackupPrivatePackage(
      id: id,
      name: 'Tiny',
      revision: 2,
      kind: 'new-language',
      active: active,
      archive: PrivateExport.archive(_tiny),
      retired: retired,
    );

    AppBackup backup({
      List<BackupPrivatePackage> packages = const <BackupPrivatePackage>[],
      Map<String, List<String>> tombstones = const <String, List<String>>{},
    }) => AppBackup(
      appVersion: '0.10.0',
      schemaVersion: 12,
      createdAt: DateTime.utc(2026, 11, 13, 9),
      log: _emptyLog,
      settings: const <String, String>{},
      privatePackages: packages,
      privateTombstones: tombstones,
    );

    test('are written, named in the manifest and read back', () {
      final bytes = backup(
        packages: <BackupPrivatePackage>[
          package(active: false, retired: const <String>['fnpd-qaa-0003']),
        ],
        tombstones: const <String, List<String>>{
          'fnpd-qab': <String>['fnpd-qab-0001'],
        },
      ).encode();
      final names = ZipFiles.decode(bytes).keys;
      expect(names, contains('own-decks.json'));
      expect(names, contains('own-decks/fnpd-qaa.fnzip'));
      final back = AppBackup.decode(bytes);
      final p = back.privatePackages.single;
      expect(p.id, 'fnpd-qaa');
      expect(p.name, 'Tiny');
      expect(p.revision, 2);
      expect(p.active, isFalse);
      expect(p.retired, <String>['fnpd-qaa-0003']);
      expect(p.archive, PrivateExport.archive(_tiny));
      expect(back.privateTombstones, <String, List<String>>{
        'fnpd-qab': <String>['fnpd-qab-0001'],
      });
      expect(BackupInfo.peek(bytes).privateLanguages, <String>['Tiny']);
      expect(
        back.copyAs(BackupKind.restore, DateTime.utc(2026)).privatePackages,
        hasLength(1),
      );
    });

    test('a backup without any has no part, and an older reader would '
        'ignore it', () {
      final bytes = backup().encode();
      final names = ZipFiles.decode(bytes).keys;
      expect(names.any((n) => n.startsWith('own-decks')), isFalse);
      expect(AppBackup.decode(bytes).privatePackages, isEmpty);
      // An old reader reads the parts it knows and skips the rest: the
      // backup with packages still decodes to the same log and settings.
      final withPackages = AppBackup.decode(
        backup(packages: <BackupPrivatePackage>[package()]).encode(),
      );
      expect(withPackages.settings, isEmpty);
    });

    test('an index entry naming a path, or a file that is not there, is '
        'ignored', () {
      final good = backup(packages: <BackupPrivatePackage>[package()]).encode();
      final files = <String, List<int>>{...ZipFiles.decode(good)};
      files['own-decks.json'] = utf8.encode(
        jsonEncode(<String, Object?>{
          'packages': <Object?>[
            <String, Object?>{
              'id': '../evil',
              'revision': 1,
              'file': 'own-decks/../evil.fnzip',
            },
            <String, Object?>{'id': 'fnpd-qaz', 'revision': 1},
            <String, Object?>{'id': 'fnpd-qaa', 'revision': 1},
          ],
          'tombstones': <String, Object?>{
            '../x': <String>['a'],
          },
        }),
      );
      final back = AppBackup.decode(ZipFiles.encode(files));
      expect(back.privatePackages.map((p) => p.id), <String>['fnpd-qaa']);
      expect(back.privateTombstones, isEmpty);
    });
  });

  group('backing up and restoring private languages', () {
    test('Back up now carries the package, and a restore on another phone '
        'brings it back as it was', () async {
      final a = _phone();
      await _install(a.store, _tiny);
      await _install(a.store, _withoutThird(_tiny));
      await a.state.setPrivateActive('fnpd-qaa', active: false);
      expect(await a.state.backups.backUpNow(), isTrue);

      final saved = AppBackup.decode(a.files.saved.single.bytes);
      expect(saved.privatePackages.single.retired, <String>['fnpd-qaa-0003']);
      expect(saved.privatePackages.single.active, isFalse);

      final b = _phone();
      await b.state.backups.restore(saved, fromFile: true);
      final back = (await b.store.packages()).single;
      expect(back.id, 'fnpd-qaa');
      expect(back.revision, 2);
      expect(back.active, isFalse);
      expect(back.retired, <String>['fnpd-qaa-0003']);
      expect(
        (await b.store.readPackage('fnpd-qaa'))!['manifest.yaml'],
        contains('revision: 2'),
      );
    });

    test('a removed package keeps its tombstone through a restore, so a '
        'retired id stays retired', () async {
      final a = _phone();
      await _install(a.store, _tiny);
      await _install(a.store, _withoutThird(_tiny));
      await a.store.remove('fnpd-qaa');
      expect(await a.store.tombstone('fnpd-qaa'), <String>['fnpd-qaa-0003']);
      await a.state.backups.backUpNow();
      final saved = AppBackup.decode(a.files.saved.single.bytes);
      expect(saved.privatePackages, isEmpty);
      expect(saved.privateTombstones['fnpd-qaa'], <String>['fnpd-qaa-0003']);

      final b = _phone();
      await b.state.backups.restore(saved, fromFile: true);
      expect(await b.store.tombstone('fnpd-qaa'), <String>['fnpd-qaa-0003']);
      // The first revision gives 0003 to a card again: refused.
      final staging = await _stage(_tiny, store: b.store);
      expect(staging.canInstall, isFalse);
      expect(staging.findings.map((f) => f.token), contains('retiredReused'));
    });

    test('a backup with no private part leaves the packages on the phone '
        'alone', () async {
      final a = _phone();
      await _install(a.store, _tiny);
      final plain = AppBackup(
        appVersion: '0.10.0',
        schemaVersion: 12,
        createdAt: DateTime.utc(2026, 11, 13),
        log: _emptyLog,
        settings: const <String, String>{},
      );
      await a.state.backups.restore(plain, fromFile: false);
      expect((await a.store.packages()).single.id, 'fnpd-qaa');
    });

    test('a package whose manifest is another package than the backup says '
        'is left out', () async {
      final b = _phone();
      final backup = AppBackup(
        appVersion: '0.10.0',
        schemaVersion: 12,
        createdAt: DateTime.utc(2026, 11, 13),
        log: _emptyLog,
        settings: const <String, String>{},
        privatePackages: <BackupPrivatePackage>[
          BackupPrivatePackage(
            id: 'fnpd-qab',
            name: 'Tiny',
            revision: 1,
            kind: 'new-language',
            active: true,
            archive: PrivateExport.archive(_tiny),
          ),
        ],
      );
      await b.state.backups.restore(backup, fromFile: false);
      expect(await b.store.packages(), isEmpty);
    });

    test('a package that no longer passes the checks is left out and the '
        'rest come back', () async {
      final b = _phone();
      final broken = ZipFiles.encode(<String, List<int>>{
        'manifest.yaml': utf8.encode('format: "other"\n'),
      });
      final backup = AppBackup(
        appVersion: '0.10.0',
        schemaVersion: 12,
        createdAt: DateTime.utc(2026, 11, 13),
        log: _emptyLog,
        settings: const <String, String>{},
        privatePackages: <BackupPrivatePackage>[
          BackupPrivatePackage(
            id: 'fnpd-qab',
            name: 'Broken',
            revision: 1,
            kind: 'new-language',
            active: true,
            archive: broken,
          ),
          BackupPrivatePackage(
            id: 'fnpd-qaa',
            name: 'Tiny',
            revision: 1,
            kind: 'new-language',
            active: true,
            archive: PrivateExport.archive(_tiny),
          ),
        ],
      );
      await b.state.backups.restore(backup, fromFile: false);
      expect((await b.store.packages()).map((p) => p.id), <String>['fnpd-qaa']);
    });
  });

  group('Export and Download a course to change', () {
    testWidgets('Export saves the package as a .fnzip that imports again', (
      tester,
    ) async {
      usePhone(tester);
      final phone = _phone();
      await _install(phone.store, _tiny);
      await pumpScreen(tester, const YourDecksPage(), state: phone.state);
      final l10n = l10nOf(tester);
      await tester.ensureVisible(find.text(l10n.privateExport));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.privateExport));
      await tester.pumpAndSettle();
      final saved = phone.files.saved.single;
      expect(saved.name, 'fnpd-qaa-rev1.fnzip');
      expect(find.text(l10n.privateExportSaved(saved.name)), findsOneWidget);
      final staging = await stagePrivateArchive(
        saved.bytes,
        store: MemoryPrivateStore(),
        appVersion: _appVersion,
      );
      expect(staging.canInstall, isTrue);
      expect(staging.manifest!.package, 'fnpd-qaa');
    });

    testWidgets('a cancelled save says nothing', (tester) async {
      usePhone(tester);
      final phone = _phone();
      phone.files.saves = false;
      await _install(phone.store, _tiny);
      await pumpScreen(tester, const YourDecksPage(), state: phone.state);
      final l10n = l10nOf(tester);
      await tester.ensureVisible(find.text(l10n.privateExport));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.privateExport));
      await tester.pumpAndSettle();
      expect(find.text(l10n.privateExportFailed), findsNothing);
      expect(phone.files.saved, isEmpty);
    });

    testWidgets('Get a starter package saves the starter', (tester) async {
      usePhone(tester);
      final phone = _phone();
      await pumpScreen(tester, const YourDecksPage(), state: phone.state);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.privateStarter));
      await tester.pumpAndSettle();
      expect(phone.files.saved.single.name, privateStarterFileName);
      expect(
        find.text(l10n.privateStarterSaved(privateStarterFileName)),
        findsOneWidget,
      );
    });

    testWidgets('the download page lists the courses on the phone and saves '
        'one as a package to change', (tester) async {
      usePhone(tester);
      final phone = _phone(decks: _course());
      await pumpScreen(tester, const PrivateDownloadPage(), state: phone.state);
      final l10n = l10nOf(tester);
      expect(find.text('Tiny'), findsOneWidget);
      expect(find.text(l10n.privateDownloadDecks(2)), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('private-download-te')),
      );
      await tester.pumpAndSettle();
      final saved = phone.files.saved.single;
      expect(saved.name, 'fnpd-te-rev1.fnzip');
      expect(find.text(l10n.privateDownloadSaved(saved.name)), findsOneWidget);
      final staging = await stagePrivateArchive(
        saved.bytes,
        store: MemoryPrivateStore(),
        appVersion: _appVersion,
        builtIn: _course(),
        builtInLanguages: const <String>{'te'},
      );
      expect(staging.errors, isEmpty, reason: staging.errors.join('; '));
      expect(staging.canInstall, isTrue);
    });

    testWidgets('with no course on the phone the page says so', (tester) async {
      usePhone(tester);
      final phone = _phone();
      await pumpScreen(tester, const PrivateDownloadPage(), state: phone.state);
      expect(find.text(l10nOf(tester).privateDownloadNone), findsOneWidget);
    });
  });

  group('the Yours tag in language lists', () {
    const own = SpokenLanguage(
      code: 'qaa',
      iso639_3: 'qaa',
      name: 'Alpha',
      ownName: 'Alpha',
      isPrivate: true,
    );
    const changed = SpokenLanguage(
      code: 'te',
      iso639_3: 'tel',
      name: 'Telugu',
      ownName: 'తెలుగు',
      isPrivate: true,
    );
    const builtIn = SpokenLanguage(
      code: 'en',
      iso639_3: 'eng',
      name: 'English',
      ownName: 'English',
    );

    testWidgets('a language of the learner’s own is Yours, a changed course '
        'is Privately modified, any other has none', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const Scaffold(
          body: Column(
            children: <Widget>[
              PrivateLanguageTag(language: own),
              PrivateLanguageTag(language: changed),
              PrivateLanguageTag(language: builtIn),
            ],
          ),
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.privateYours), findsOneWidget);
      expect(find.text(l10n.privateModified), findsOneWidget);
    });

    testWidgets('the Add a language list shows it on the private language '
        'only', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        Scaffold(
          body: LanguagePickList(
            views: const <LanguageView>[
              LanguageView(own, null),
              LanguageView(builtIn, null),
            ],
            onPick: (_) {},
            isAdded: (_) => false,
          ),
        ),
      );
      expect(find.text(l10nOf(tester).privateYours), findsOneWidget);
    });
  });

  group('the no-voice notice on the course card', () {
    Future<CourseView> view(AppState state) async {
      final v = courseView(state, 'qaa');
      expect(v, isNotNull);
      return v!;
    }

    testWidgets('is on the card of a private language with no voice', (
      tester,
    ) async {
      usePhone(tester);
      final phone = _phone();
      await _install(phone.store, _tiny);
      await pumpScreen(tester, const SizedBox(), state: phone.state);
      await pumpScreen(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: CourseCard(view: await view(phone.state), glyph: 'T'),
          ),
        ),
        state: phone.state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.privateNoVoiceTitle), findsOneWidget);
      expect(find.textContaining(l10n.privateNoVoiceBody), findsOneWidget);
    });

    testWidgets('is not there when the phone has the voice', (tester) async {
      usePhone(tester);
      final phone = _phone(voices: const <String>{'qaa'});
      await _install(phone.store, _tiny);
      await pumpScreen(tester, const SizedBox(), state: phone.state);
      await pumpScreen(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: CourseCard(view: await view(phone.state), glyph: 'T'),
          ),
        ),
        state: phone.state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.privateNoVoiceTitle), findsNothing);
      expect(find.textContaining(l10n.privateNoVoiceBody), findsNothing);
    });
  });

  group('the import review note', () {
    testWidgets('says how many cards replace built-in ones, for a changed '
        'course only', (tester) async {
      usePhone(tester);
      final course = _course();
      final changed = asTelugu(_tiny);
      final home = changed.keys.firstWhere(
        (k) => k.endsWith('fnpd-te-home.yaml'),
      );
      changed[home] = changed[home]!.replaceFirst(
        '  - id: "fnpd-te-0001"\n',
        '  - id: "fnpd-te-0001"\n    replaces: "te-0001"\n',
      );
      final phone = _phone(decks: course);
      await pumpScreen(
        tester,
        PrivateImportPage(
          fileName: 'te.fnzip',
          bytes: ZipFiles.encode(<String, List<int>>{
            for (final e in changed.entries) e.key: utf8.encode(e.value),
          }),
        ),
        state: phone.state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.privateNoteReplaces(1, 0)), findsOneWidget);
    });
  });
}
