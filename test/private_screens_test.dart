// Private languages, third slice (#1017, Plan-Private-Languages tasks 8, 14
// to 18): the language directory with private packages merged in, the
// capability check, the "privately modified" tag, Your decks with a group for
// each package (the cap of three, Remove with its second choice), the import
// review with its refusals, and the update summary. The approved mockups are
// private-your-decks, private-import-review and private-update-summary.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_import.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/private_import.dart';
import 'package:fluenough/app/private_languages.dart';
import 'package:fluenough/app/private_store.dart';
import 'package:fluenough/core/backup/zip_files.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/review_erasure.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/decks/language_directory.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/private/private_manifest.dart';
import 'package:fluenough/core/private/private_update.dart';
import 'package:fluenough/features/private/private_import_page.dart';
import 'package:fluenough/features/private/private_notes.dart';
import 'package:fluenough/features/settings/your_decks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/accessibility_shared.dart';
import 'support/harness.dart';
import 'support/private_fixture.dart';

const String _appVersion = '9.9.9';

late Map<String, String> _tiny;

/// The fixture as the private-use language [code], called [name].
Map<String, String> _pkg(
  String code,
  String name, {
  int revision = 1,
  Map<String, String> Function(Map<String, String>)? edit,
}) {
  var files = <String, String>{
    for (final e in asCode(_tiny, code).entries)
      e.key: e.value
          .replaceAll('"Tiny"', '"$name"')
          .replaceAll('revision: 1', 'revision: $revision'),
  };
  if (edit != null) files = edit(files);
  return files;
}

Uint8List _zip(Map<String, String> files) =>
    ZipFiles.encode(<String, List<int>>{
      for (final e in files.entries) e.key: utf8.encode(e.value),
    });

/// A package whose first card has no private prefix: an error.
Map<String, String> _withBadId(Map<String, String> files) => <String, String>{
  for (final e in files.entries)
    e.key: e.value.replaceFirst('id: "fnpd-qab-0001"', 'id: "qab-0001"'),
};

final List<SpokenLanguage> _builtIn = parseSpokenLanguages(
  File(spokenLanguagesAsset).readAsStringSync(),
);

/// Answers the file chooser from memory.
class _Files implements DeckFiles {
  _Files(this.bytes);

  final Uint8List? bytes;

  @override
  Future<bool> save(String fileName, String contents) async => true;

  @override
  Future<({String name, String text})?> open({required String title}) async =>
      null;

  @override
  Future<({String name, List<int> bytes})?> openBytes({
    required String title,
  }) async => bytes == null ? null : (name: 'package.fnzip', bytes: bytes!);
}

class _World {
  _World(this.state, this.store);

  final AppState state;
  final MemoryPrivateStore store;
}

/// A phone with the packages [codes] installed (Alpha, Beta, Gamma, Delta in
/// that order, [off] of them switched off), no built-in decks, and the file
/// chooser answering [picked].
Future<_World> _world({
  List<String> codes = const <String>[],
  Set<String> off = const <String>{},
  MemoryProgress? progress,
  Uint8List? picked,
}) async {
  const names = <String, String>{
    'qaa': 'Alpha',
    'qab': 'Beta',
    'qac': 'Gamma',
    'qad': 'Delta',
  };
  final store = MemoryPrivateStore();
  for (final code in codes) {
    final result = await importPrivatePackage(
      _pkg(code, names[code]!),
      store: store,
      appVersion: _appVersion,
      active: off.contains(code) ? false : null,
    );
    expect(result.installed, isTrue, reason: code);
  }
  final state = AppState.test(
    decks: MemoryDeckSource(const <String, String>{}),
    privateStore: store,
    progress: progress,
    deckFiles: _Files(picked),
  );
  return _World(state, store);
}

void _answer(MemoryProgress progress, String cardId, DateTime at) =>
    progress.record(
      deckId: 'x',
      cardId: cardId,
      mode: DrillMode.recognition,
      grade: 4,
      now: at,
    );

Future<void> _open(WidgetTester tester, Widget page, _World world) =>
    pumpScreen(tester, page, state: world.state).then((_) {});

/// [page] pushed over a first screen, as the app opens it, so that it can
/// pop.
Future<void> _openOver(WidgetTester tester, Widget page, _World world) async {
  await pumpScreen(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () =>
            Navigator.of(context)
                .push<bool>(MaterialPageRoute<bool>(builder: (_) => page)),
        child: const Text('go'),
      ),
    ),
    state: world.state,
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

Future<AppState> worldForDiag() async {
  _tiny = await tinyPackage();
  return (await _world(
    codes: <String>['qaa', 'qab', 'qac', 'qad'],
    off: <String>{'qad'},
  )).state;
}

void main() {
  setUpAll(() async => _tiny = await tinyPackage());

  group('the language directory', () {
    PrivateManifest manifest(String text) => PrivateManifest.parse(text);

    test('a new private language is added like any other', () {
      final merged = mergeLanguageDirectory(_builtIn, <PrivateManifest>[
        manifest(
          _pkg('qaa', 'Alpha')['manifest.yaml']!.replaceFirst(
            'script: "latin"',
            'own_name: "Alfa"\n  script: "latin"',
          ),
        ),
      ]);
      final added = merged.last;
      expect(added.code, 'qaa');
      expect(added.name, 'Alpha');
      expect(added.ownName, 'Alfa');
      expect(added.scripts, <String>['latin']);
      expect(added.isPrivate, isTrue);
      expect(merged.length, _builtIn.length + 1);
      expect(merged.where((l) => l.isPrivate).length, 1);
    });

    test(
      'a built-in language a package changes keeps its place and family',
      () {
        final base = _builtIn.firstWhere((l) => l.code == 'te');
        final changed = PrivateManifest(
          package: 'fnpd-te',
          revision: 1,
          kind: PrivateKind.modifiedLanguage,
          language: const LanguageInfo(
            code: 'te',
            iso639_3: 'tel',
            name: 'Telugu, short path',
            script: 'telugu',
          ),
          minApp: '0.9.0',
          ownName: 'తెలుగు (short)',
        );
        final merged = mergeLanguageDirectory(_builtIn, <PrivateManifest>[
          changed,
        ]);
        expect(merged.length, _builtIn.length);
        final te = merged.firstWhere((l) => l.code == 'te');
        expect(te.name, 'Telugu, short path');
        expect(te.ownName, 'తెలుగు (short)');
        expect(te.family, base.family);
        expect(te.isPrivate, isTrue);
        expect(
          merged.indexWhere((l) => l.code == 'te'),
          _builtIn.indexWhere((l) => l.code == 'te'),
        );
      },
    );

    test('only an active package is in the app\'s directory', () async {
      final world = await _world(
        codes: <String>['qaa', 'qab'],
        off: <String>{'qab'},
      );
      final all = await world.state.languageDirectory(_builtIn);
      expect(all.any((l) => l.code == 'qaa' && l.name == 'Alpha'), isTrue);
      expect(all.any((l) => l.code == 'qab'), isFalse);
    });
  });

  group('removing and importing again', () {
    test('a removed package keeps its retired ids for a reimport', () async {
      final store = MemoryPrivateStore();
      Map<String, String> without3(Map<String, String> files) => {
        for (final e in files.entries)
          e.key: e.value
              .replaceAll(
                '  - id: "fnpd-qaa-0003"\n    target: "tepa"\n'
                    '    ipa: "ˈtepa"\n    pos: "noun"\n    tags: ["home"]\n',
                '',
              )
              .replaceAll('  "fnpd-qaa-0003":\n    native: "roof"\n', ''),
      };
      expect(
        (await importPrivatePackage(
          _tiny,
          store: store,
          appVersion: _appVersion,
        )).installed,
        isTrue,
      );
      final second = <String, String>{
        for (final e in without3(_tiny).entries)
          e.key: e.value.replaceAll('revision: 1', 'revision: 2'),
      };
      expect(
        (await importPrivatePackage(
          second,
          store: store,
          appVersion: _appVersion,
        )).installed,
        isTrue,
      );
      expect((await store.packages()).single.retired, <String>[
        'fnpd-qaa-0003',
      ]);
      await store.remove('fnpd-qaa');
      // The earliest file brings the id back: refused, though no package is
      // installed any more.
      final staging = await stagePrivateFiles(
        _tiny,
        store: store,
        appVersion: _appVersion,
      );
      expect(staging.canInstall, isFalse);
      expect(staging.findings.map((f) => f.token), contains('retiredReused'));
    });
  });

  group('the update summary', () {
    test('counts what a newer revision adds, changes and drops', () {
      final before = _tiny;
      final after = <String, String>{
        for (final e in before.entries)
          e.key: e.value
              .replaceAll('revision: 1', 'revision: 2')
              .replaceAll(
                '  - id: "fnpd-qaa-0003"\n    target: "tepa"\n'
                    '    ipa: "ˈtepa"\n    pos: "noun"\n    tags: ["home"]\n',
                '',
              )
              .replaceAll('  "fnpd-qaa-0003":\n    native: "roof"\n', '')
              .replaceAll('target: "kolu"', 'target: "kolo"'),
      };
      final summary = PrivateUpdateSummary.compute(
        before: before,
        after: after,
        fromRevision: 1,
        toRevision: 2,
        retired: const <String>['fnpd-qaa-0003', 'fnpd-qaa-0100'],
      );
      expect(summary.removed.map((c) => c.id), <String>['fnpd-qaa-0003']);
      expect(summary.changed.map((c) => c.id), <String>['fnpd-qaa-0001']);
      expect(summary.changed.single.fields, contains('target'));
      expect(summary.added, isEmpty);
      expect(summary.unchanged, 4);
      expect(summary.retiredNow, 1);
      expect(summary.retiredEarlier, 1);
      expect(summary.retiredTotal, 2);
      expect(summary.removed.single.meaning, 'roof');
    });
  });

  group('removing a package with its progress', () {
    test("deletes the package's reviews only, not the course's", () async {
      final db = AppDatabase(NativeDatabase.memory());
      final progress = await DatabaseProgress.open(db);
      addTearDown(progress.dispose);
      addTearDown(progress.close);
      final at = DateTime(2026, 11, 3, 10);
      for (final id in <String>['te-0001', 'fnpd-te-0001', 'fnpd-qaa-0001']) {
        progress.record(
          deckId: 'd',
          cardId: id,
          mode: DrillMode.recognition,
          grade: 4,
          now: at,
        );
      }
      await progress.flush();
      final removed = await progress.eraseReviews(
        ReviewErasure.privatePackage('te'),
      );
      expect(removed, 1);
      expect(
        <String>[for (final r in await db.reviewsDao.all()) r.cardId]..sort(),
        <String>['fnpd-qaa-0001', 'te-0001'],
      );
    });
  });

  group('capabilities', () {
    testWidgets('a private language with no voice has speaking hidden', (
      tester,
    ) async {
      usePhone(tester);
      final world = await _world(codes: <String>['qaa']);
      await _open(tester, const YourDecksPage(), world);
      final language = world.state.languages.firstWhere((l) => l.code == 'qaa');
      final caps = world.state.privateCapabilities(language);
      expect(caps.noVoice, isTrue);
      expect(caps.hidesSound, isTrue);
      expect(caps.hidesSpeaking, isTrue);
      expect(world.state.canHear(language), isFalse);
      expect(world.state.canSpeak(language), isFalse);
      final l10n = l10nOf(tester);
      expect(find.textContaining(l10n.privateNoVoiceBody), findsOneWidget);
      await tapShown(tester, find.text(l10n.privateWhy));
      await tester.pumpAndSettle();
      expect(find.text(l10n.privateWhyTitle('Alpha')), findsOneWidget);
      expect(find.text(l10n.privateCheckAgain), findsOneWidget);
    });
  });

  group('Your decks', () {
    testWidgets('has an empty state with Add a private language', (
      tester,
    ) async {
      usePhone(tester);
      final world = await _world();
      await _open(tester, const YourDecksPage(), world);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.privateEmptyTitle), findsOneWidget);
      expect(find.text(l10n.privateAdd), findsOneWidget);
    });

    testWidgets('lists a group for each package with its facts', (
      tester,
    ) async {
      usePhone(tester);
      final world = await _world(codes: <String>['qaa', 'qab']);
      await _open(tester, const YourDecksPage(), world);
      final l10n = l10nOf(tester);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text(l10n.privateListHeading(2)), findsOneWidget);
      expect(find.textContaining('2 of 3 active'), findsOneWidget);
      expect(find.text(l10n.privateKindNew), findsNWidgets(2));
      expect(find.text(l10n.privateHoldsValue(6, 2, 2)), findsNWidgets(2));
    });

    testWidgets('a fourth package asks which to turn off, the least recently '
        'studied preselected', (tester) async {
      usePhone(tester);
      final progress = MemoryProgress();
      // Beta and Gamma were studied, Alpha never: it is preselected.
      _answer(progress, 'fnpd-qab-0001', DateTime(2026, 11, 1));
      _answer(progress, 'fnpd-qac-0001', DateTime(2026, 11, 5));
      final world = await _world(
        codes: <String>['qaa', 'qab', 'qac', 'qad'],
        off: <String>{'qad'},
        progress: progress,
      );
      await _open(tester, const YourDecksPage(), world);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.privateNeedsSlot), findsOneWidget);
      final fourth = find.byType(Switch).at(3);
      await tapShown(tester, fourth);
      await tester.pumpAndSettle();
      expect(find.text(l10n.privateCapTitle), findsOneWidget);
      expect(
        find.text(l10n.privateCapSwap('Alpha', 'Delta')),
        findsOneWidget,
        reason: 'Alpha, never studied, is preselected',
      );
      await tester.tap(find.text(l10n.privateCapSwap('Alpha', 'Delta')));
      await tester.pumpAndSettle();
      final now = <String, bool>{
        for (final p in await world.store.packages()) p.id: p.active,
      };
      expect(now, <String, bool>{
        'fnpd-qaa': false,
        'fnpd-qab': true,
        'fnpd-qac': true,
        'fnpd-qad': true,
      });
    });

    testWidgets('Remove keeps the progress, and offers to delete it as a '
        'second choice', (tester) async {
      usePhone(tester);
      final progress = MemoryProgress();
      _answer(progress, 'fnpd-qaa-0001', DateTime(2026, 11, 1));
      _answer(progress, 'fnpd-qab-0001', DateTime(2026, 11, 1));
      final world = await _world(
        codes: <String>['qaa', 'qab'],
        progress: progress,
      );
      await _open(tester, const YourDecksPage(), world);
      final l10n = l10nOf(tester);
      await tapShown(tester, find.text(l10n.privateRemove).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.privateRemoveTitle('Alpha')), findsOneWidget);
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(l10n.privateRemoveDelete),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.text(l10n.privateRemoveConfirm),
        ),
      );
      await tester.pumpAndSettle();
      expect((await world.store.packages()).map((p) => p.id), <String>[
        'fnpd-qab',
      ]);
      expect(
        world.state.progress.log.map((e) => e.cardId),
        containsAll(<String>['fnpd-qaa-0001', 'fnpd-qab-0001']),
      );
    });

    testWidgets('Remove and delete my progress deletes only that package\'s '
        'reviews', (tester) async {
      usePhone(tester);
      final progress = MemoryProgress();
      _answer(progress, 'fnpd-qaa-0001', DateTime(2026, 11, 1));
      _answer(progress, 'fnpd-qab-0001', DateTime(2026, 11, 1));
      final world = await _world(
        codes: <String>['qaa', 'qab'],
        progress: progress,
      );
      await _open(tester, const YourDecksPage(), world);
      final l10n = l10nOf(tester);
      await tapShown(tester, find.text(l10n.privateRemove).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.privateRemoveDelete));
      await tester.pumpAndSettle();
      expect((await world.store.packages()).map((p) => p.id), <String>[
        'fnpd-qab',
      ]);
      expect(world.state.progress.log.map((e) => e.cardId), <String>[
        'fnpd-qab-0001',
      ]);
    });

    testWidgets('Add a private language opens the review, and Add installs', (
      tester,
    ) async {
      usePhone(tester);
      final world = await _world(picked: _zip(_pkg('qab', 'Beta')));
      await _open(tester, const YourDecksPage(), world);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.privateAdd));
      await tester.pumpAndSettle();
      expect(find.text(l10n.privateReviewTitle), findsOneWidget);
      expect(find.text(l10n.privateAddButton), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('private-add-confirm')),
      );
      await tester.pumpAndSettle();
      expect((await world.store.packages()).map((p) => p.id), <String>[
        'fnpd-qab',
      ]);
      expect(find.text('Beta'), findsWidgets);
    });
  });

  group('the import review', () {
    Future<_World> review(
      WidgetTester tester,
      Uint8List bytes, {
      List<String> codes = const <String>[],
    }) async {
      usePhone(tester);
      final world = await _world(codes: codes);
      await _open(
        tester,
        PrivateImportPage(fileName: 'package.fnzip', bytes: bytes),
        world,
      );
      return world;
    }

    testWidgets('an error blocks Add, and is told with its file and line', (
      tester,
    ) async {
      await review(tester, _zip(_pkg('qab', 'Beta', edit: _withBadId)));
      final l10n = l10nOf(tester);
      final add = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('private-add-confirm')),
      );
      expect(add.onPressed, isNull);
      expect(find.text(l10n.privateSevError), findsWidgets);
      expect(find.textContaining('qab-0001'), findsWidgets);
    });

    testWidgets('a warning never blocks Add', (tester) async {
      final world = await review(
        tester,
        _zip(
          _pkg(
            'qab',
            'Beta',
            edit: (files) => <String, String>{
              ...files,
              'manifest.yaml': files['manifest.yaml']!.replaceFirst(
                'script: "latin"',
                'script: "devanagari"',
              ),
            },
          ),
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.textContaining('Warning'), findsWidgets);
      expect(find.text(l10n.privateSumErrors(0)), findsOneWidget);
      final add = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('private-add-confirm')),
      );
      expect(add.onPressed, isNotNull);
      expect(await world.store.packages(), isEmpty, reason: 'not yet added');
    });

    testWidgets('the same revision is a reinstall, reviewed as an update', (
      tester,
    ) async {
      await review(tester, _zip(_pkg('qaa', 'Alpha')), codes: <String>['qaa']);
      expect(find.text(l10nOf(tester).privateContinueUpdate), findsOneWidget);
    });

    testWidgets('an older revision is refused, naming both revisions', (
      tester,
    ) async {
      usePhone(tester);
      final world = await _world();
      await importPrivatePackage(
        _pkg('qaa', 'Alpha', revision: 7),
        store: world.store,
        appVersion: _appVersion,
      );
      await _open(
        tester,
        PrivateImportPage(
          fileName: 'old.fnzip',
          bytes: _zip(_pkg('qaa', 'Alpha', revision: 5)),
        ),
        world,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.privateOlderTitle), findsOneWidget);
      expect(find.text(l10n.privateOlderBody('Alpha', 7, 5)), findsOneWidget);
      expect(find.text(l10n.privateRefused), findsOneWidget);
    });

    testWidgets('a file over 10 MB is refused before it is opened', (
      tester,
    ) async {
      await review(tester, Uint8List(10 * 1024 * 1024 + 1));
      final l10n = l10nOf(tester);
      expect(find.text(l10n.privateBigTitle), findsOneWidget);
      expect(find.text(l10n.privateRefused), findsOneWidget);
    });

    testWidgets('a file that is not a zip is refused as unsafe', (
      tester,
    ) async {
      await review(tester, Uint8List.fromList(<int>[1, 2, 3, 4]));
      final l10n = l10nOf(tester);
      expect(find.text(l10n.privateUnsafeTitle), findsOneWidget);
      expect(find.text(l10n.privateRefused), findsOneWidget);
    });

    testWidgets('a newer file of an installed package shows what changes, '
        'and Update installs it', (tester) async {
      usePhone(tester);
      final world = await _world(codes: <String>['qaa']);
      final newer = _pkg(
        'qaa',
        'Alpha',
        revision: 2,
        edit: (files) => <String, String>{
          for (final e in files.entries)
            e.key: e.value
                .replaceAll(
                  '  - id: "fnpd-qaa-0003"\n    target: "tepa"\n'
                      '    ipa: "ˈtepa"\n    pos: "noun"\n    tags: ["home"]\n',
                  '',
                )
                .replaceAll('  "fnpd-qaa-0003":\n    native: "roof"\n', '')
                .replaceAll('target: "kolu"', 'target: "kolo"'),
        },
      );
      await _openOver(
        tester,
        PrivateImportPage(fileName: 'alpha-r2.fnzip', bytes: _zip(newer)),
        world,
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.privateContinueUpdate));
      await tester.pumpAndSettle();
      expect(find.text(l10n.privateUpdateTitle('Alpha')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l10n.privateListRemoved(1)),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.privateListChanged(1)), findsOneWidget);
      expect(find.text(l10n.privateListRemoved(1)), findsOneWidget);
      expect(find.text(l10n.privateUpdateTo(2)), findsOneWidget);
      await tester.tap(find.text(l10n.privateUpdateTo(2)));
      await tester.pumpAndSettle();
      final package = (await world.store.packages()).single;
      expect(package.revision, 2);
      expect(package.retired, contains('fnpd-qaa-0003'));
    });
  });

  group('the privately modified tag', () {
    testWidgets('shows where a package changed the course, and nowhere else', (
      tester,
    ) async {
      usePhone(tester);
      final store = MemoryPrivateStore();
      final result = await importPrivatePackage(
        asTelugu(_tiny),
        store: store,
        appVersion: _appVersion,
      );
      expect(result.installed, isTrue);
      final state = AppState.test(
        decks: MemoryDeckSource(const <String, String>{}),
        privateStore: store,
      );
      await pumpScreen(
        tester,
        Scaffold(
          body: Column(
            children: const <Widget>[
              PrivateModifiedTag(language: 'te'),
              PrivateModifiedTag(language: 'hi'),
            ],
          ),
        ),
        state: state,
      );
      expect(find.text(l10nOf(tester).privateModified), findsOneWidget);
    });
  });

  // Each screen of the mockups at 1.4x text, light and dark, on a phone with
  // the three-button bar.
  group('layout', () {
    DrawScreen yourDecks({
      List<String> codes = const <String>[],
      Set<String> off = const <String>{},
      Future<void> Function(WidgetTester)? then,
    }) => (tester, mode) async {
      final world = await _world(codes: codes, off: off);
      await pumpScreen(
        tester,
        const YourDecksPage(),
        state: world.state,
        themeMode: mode,
      );
      await then?.call(tester);
    };

    DrawScreen pageOf(Uint8List Function() bytes) => (tester, mode) async {
      final world = await _world();
      await pumpScreen(
        tester,
        PrivateImportPage(fileName: 'package.fnzip', bytes: bytes()),
        state: world.state,
        themeMode: mode,
      );
    };

    screen('Your decks, empty', yourDecks());
    screen(
      'Your decks, three active and a fourth waiting',
      yourDecks(
        codes: <String>['qaa', 'qab', 'qac', 'qad'],
        off: <String>{'qad'},
      ),
    );
    screen(
      'the fourth-package sheet',
      yourDecks(
        codes: <String>['qaa', 'qab', 'qac', 'qad'],
        off: <String>{'qad'},
        then: (tester) async {
          await tapShown(tester, find.byType(Switch).at(3));
          await tester.pumpAndSettle();
        },
      ),
      onTop: find.byType(BottomSheet),
    );
    screen(
      'the Remove dialog',
      yourDecks(
        codes: <String>['qaa'],
        then: (tester) async {
          await tapShown(tester, find.text(l10nOf(tester).privateRemove));
          await tester.pumpAndSettle();
        },
      ),
      onTop: find.byType(AlertDialog),
    );
    screen(
      'the no-voice sheet',
      yourDecks(
        codes: <String>['qaa'],
        then: (tester) async {
          await tapShown(tester, find.text(l10nOf(tester).privateWhy));
          await tester.pumpAndSettle();
        },
      ),
      onTop: find.byType(BottomSheet),
    );
    screen(
      'the import review with an error',
      pageOf(() => _zip(_pkg('qab', 'Beta', edit: _withBadId))),
    );
    screen(
      'the import review with a warning',
      pageOf(
        () => _zip(
          _pkg(
            'qab',
            'Beta',
            edit: (files) => <String, String>{
              ...files,
              'manifest.yaml': files['manifest.yaml']!.replaceFirst(
                'script: "latin"',
                'script: "devanagari"',
              ),
            },
          ),
        ),
      ),
    );
    screen(
      'the import review of a clean package',
      pageOf(() => _zip(_pkg('qab', 'Beta'))),
    );
    testWidgets('the checking screen, at 1.4x text, light and dark', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        usePhone(tester, textScale: 1.4, navBar: true);
        final world = await _world();
        await pumpScreen(
          tester,
          const PrivateImportPage(
            fileName: 'package.fnzip',
            bytes: <int>[],
            holdChecking: true,
          ),
          state: world.state,
          themeMode: mode,
          settle: false,
        );
        expect(tester.takeException(), isNull, reason: mode.name);
        await meetsEveryGuideline(tester);
      }
      semantics.dispose();
    });
    screen(
      'the refusal of a file over 10 MB',
      pageOf(() => Uint8List(10485761)),
    );
    screen(
      'the refusal of an unsafe file',
      pageOf(() => Uint8List.fromList(<int>[1, 2, 3])),
    );
    screen('the refusal of an older revision', (tester, mode) async {
      final world = await _world(codes: <String>['qaa']);
      await importPrivatePackage(
        _pkg('qaa', 'Alpha', revision: 7),
        store: world.store,
        appVersion: _appVersion,
      );
      await pumpScreen(
        tester,
        PrivateImportPage(
          fileName: 'old.fnzip',
          bytes: _zip(_pkg('qaa', 'Alpha', revision: 5)),
        ),
        state: world.state,
        themeMode: mode,
      );
    });
    screen('the update summary', (tester, mode) async {
      final world = await _world(codes: <String>['qaa']);
      await pumpScreen(
        tester,
        PrivateImportPage(
          fileName: 'alpha-r2.fnzip',
          bytes: _zip(
            _pkg(
              'qaa',
              'Alpha',
              revision: 2,
              edit: (files) => <String, String>{
                for (final e in files.entries)
                  e.key: e.value.replaceAll('target: "kolu"', 'target: "kolo"'),
              },
            ),
          ),
        ),
        state: world.state,
        themeMode: mode,
      );
      await tester.tap(find.text(l10nOf(tester).privateContinueUpdate));
      await tester.pumpAndSettle();
    });
    screen('how progress is kept', (tester, mode) async {
      final world = await _world(codes: <String>['qaa']);
      await pumpScreen(
        tester,
        PrivateImportPage(
          fileName: 'alpha-r2.fnzip',
          bytes: _zip(_pkg('qaa', 'Alpha', revision: 2)),
        ),
        state: world.state,
        themeMode: mode,
      );
      await tester.tap(find.text(l10nOf(tester).privateContinueUpdate));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nOf(tester).privateHowItWorks));
      await tester.pumpAndSettle();
    });
    screen('the privately modified tag', (tester, mode) async {
      final store = MemoryPrivateStore();
      await importPrivatePackage(
        asTelugu(_tiny),
        store: store,
        appVersion: _appVersion,
      );
      final state = AppState.test(
        decks: MemoryDeckSource(const <String, String>{}),
        privateStore: store,
      );
      await pumpScreen(
        tester,
        const Scaffold(body: PrivateModifiedTag(language: 'te')),
        state: state,
        themeMode: mode,
      );
    });
  });
}
