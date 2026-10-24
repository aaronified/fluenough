// Where else to learn a language (#832): the card in a language's sheet,
// from the language's resources file. A language with a file shows the card,
// one without shows nothing new, at most three are shown, the learner of a
// language already learned can hide one for good, and its button opens the
// right address.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/decks/language_resources.dart';
import 'package:fluenough/features/placement/language_sheet.dart';

import 'support/deck_remote.dart';
import 'support/harness.dart';

const CatalogLanguage _japanese = CatalogLanguage(code: 'ja', name: 'Japanese');

/// The repository's own Japanese resources file.
final String _jaFile = File('decks/ja/ja-resources.yaml').readAsStringSync();

String _file(int count) =>
    'schema: 1\nkind: "resources"\nid: "ja-resources"\nlanguage: "ja"\n'
    'resources:\n${[for (var i = 0; i < count; i++) '  - id: "ja-res-a$i"\n    name: "App $i"\n'
          '    url: "https://example.org/$i"\n    kind: "app"\n'
          '    why: "Line $i."\n'].join()}';

/// The sheet of Japanese, on its own, with [resources] and [state]'s
/// settings behind its hide button.
Future<void> _pumpSheet(
  WidgetTester tester,
  AppState state, {
  required List<LanguageResource> resources,
  bool learned = false,
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view
    ..physicalSize = const Size(360 * 3, 780 * 3)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpScreen(
    tester,
    Scaffold(
      body: LanguageSheet(
        language: _japanese,
        spoken: const <String>['en'],
        learned: learned,
        chosen: false,
        knows: false,
        scripts: const <SheetScript>[],
        initialScripts: const <String>{},
        storage: '',
        resources: Future<List<LanguageResource>>.value(resources),
        hiddenResources: state.settings.hiddenResources,
        onHideResource: state.settings.hideResource,
      ),
    ),
    state: state,
    themeMode: themeMode,
  );
}

Finder _card() => find.byKey(const ValueKey<String>('sheet-resources'));
Finder _visit(String id) => find.byKey(ValueKey<String>('sheet-resource-$id'));
Finder _hide(String id) =>
    find.byKey(ValueKey<String>('sheet-resource-hide-$id'));

void main() {
  group('the card in a language\'s sheet', () {
    testWidgets('Japanese shows Wagotabi, and its button opens its site', (
      tester,
    ) async {
      final links = FixedLinks();
      final state = AppState.test(links: links);
      addTearDown(state.dispose);
      await _pumpSheet(
        tester,
        state,
        resources: parseLanguageResources(_jaFile),
      );
      expect(_card(), findsOneWidget);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.resourceTitle('Japanese')), findsOneWidget);
      expect(find.textContaining('Wagotabi is a fun game'), findsOneWidget);
      // Picking a language: nothing to hide yet.
      expect(_hide('ja-res-wagotabi'), findsNothing);

      await tester.tap(_visit('ja-res-wagotabi'));
      await tester.pumpAndSettle();
      expect(links.asked, <String>['https://www.wagotabi.com/']);
    });

    testWidgets('a language with no file shows nothing new', (tester) async {
      final state = AppState.test();
      addTearDown(state.dispose);
      await _pumpSheet(tester, state, resources: const <LanguageResource>[]);
      expect(_card(), findsNothing);
    });

    testWidgets('three are shown, and no more, whatever the file holds', (
      tester,
    ) async {
      final state = AppState.test();
      addTearDown(state.dispose);
      final found = parseLanguageResources(_file(5));
      expect(found, hasLength(3));
      await _pumpSheet(tester, state, resources: found);
      for (var i = 0; i < 3; i++) {
        expect(_visit('ja-res-a$i'), findsOneWidget);
      }
      expect(_visit('ja-res-a3'), findsNothing);
    });

    testWidgets('hiding one on a language learned is kept for good', (
      tester,
    ) async {
      final state = AppState.test();
      addTearDown(state.dispose);
      final found = parseLanguageResources(_file(2));
      await _pumpSheet(tester, state, resources: found, learned: true);
      await tester.tap(_hide('ja-res-a0'));
      await tester.pumpAndSettle();
      expect(_visit('ja-res-a0'), findsNothing);
      expect(_visit('ja-res-a1'), findsOneWidget);

      // Kept across a restart, and not shown again on any sheet.
      final again = SettingsNotifier()..restore(state.settings.toStored());
      expect(again.hiddenResources, <String>{'ja-res-a0'});
      final next = AppState.test(settings: again);
      addTearDown(next.dispose);
      await _pumpSheet(tester, next, resources: found, learned: true);
      expect(_visit('ja-res-a0'), findsNothing);
      expect(_visit('ja-res-a1'), findsOneWidget);

      await tester.tap(_hide('ja-res-a1'));
      await tester.pumpAndSettle();
      expect(_card(), findsNothing);
    });

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('fits a 360 dp phone at 1.4x text in ${mode.name}', (
        tester,
      ) async {
        final state = AppState.test();
        addTearDown(state.dispose);
        await _pumpSheet(
          tester,
          state,
          resources: parseLanguageResources(_file(3)),
          learned: true,
          textScale: 1.4,
          themeMode: mode,
        );
        expect(_card(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the app gets the resources file', () {
    DeckDownloads downloadsOf(FakeDeckRemote remote) => DeckDownloads(
      fetcher: remote,
      files: MemoryDownloadedDecks(),
      clock: () => DateTime(2026, 10, 24),
    );

    test(
      'from the index, once, and only for a language that has one',
      () async {
        final remote = FakeDeckRemote(<String, String>{
          'decks/ja/ja-resources.yaml': _jaFile,
          'decks/es/es-path.yaml':
              'schema: 1\nkind: path\nid: es-path\nlanguage: es\nunits: []\n',
        });
        final downloads = downloadsOf(remote);
        await downloads.open();
        await downloads.refreshIndex();

        final found = await downloads.resourcesFor('ja');
        expect(found.single.url, 'https://www.wagotabi.com/');
        expect(await downloads.resourcesFor('es'), isEmpty);
        expect(await downloads.resourcesFor('xx'), isEmpty);
        await downloads.resourcesFor('ja');
        expect(
          remote.asked.where((p) => p == 'decks/ja/ja-resources.yaml'),
          hasLength(1),
        );
        // It is no deck of the language: its decks never include it.
        expect(downloads.index!.language('ja')!.files, isEmpty);
      },
    );

    test('a file that does not match the index gives nothing', () async {
      final remote = FakeDeckRemote(<String, String>{
        'decks/ja/ja-resources.yaml': _jaFile,
      });
      final downloads = downloadsOf(remote);
      await downloads.open();
      await downloads.refreshIndex();
      remote.served['decks/ja/ja-resources.yaml'] = _file(1);
      expect(await downloads.resourcesFor('ja'), isEmpty);
    });
  });
}
