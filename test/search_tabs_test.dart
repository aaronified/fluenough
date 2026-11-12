// Search results by type (wiki/Plan-Deck-Kinds-And-Topics.md, T18, the
// approved mockup docs/mockups/search-results-tabs.html): the Decks tab's
// search shows a native tab bar of only the kinds that have results, with
// counts and the best match first; a distinct row per type; a professional
// situation found only here, with "Add to my courses"; what is above the
// learner's level marked and not startable (or hidden by the setting); a
// typo put right with a way to search exactly what was typed; and the empty
// and no-result states.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/sections.dart';
import 'package:fluenough/core/search/search_items.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/search_tabs.dart';
import 'package:fluenough/features/topics/topic_page.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/accessibility_shared.dart';
import 'support/deck_remote.dart';
import 'support/harness.dart';
import 'support/kinds_world.dart';

final AppLocalizationsEn _l10n = AppLocalizationsEn();

Finder _tab(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

Future<void> _show(
  WidgetTester tester,
  AppState state,
  String query, {
  ThemeMode mode = ThemeMode.light,
}) async {
  await pumpScreen(
    tester,
    DecksPage(initialQuery: query),
    state: state,
    themeMode: mode,
  );
}

ItemResult _result(String kind, int rank, {String id = 'x'}) => ItemResult(
  row: ItemRow(
    type: SearchItemType.deck,
    id: '$kind-$id',
    kind: kind,
    fields: <String>['te-form'],
  ),
  rank: rank,
);

void main() {
  group('the tabs of a search', () {
    final sections = DeckSections(
      searchKinds: <SearchKindInfo>[
        for (final (i, id) in <String>[
          'situations',
          'topics',
          'decks',
          'cards',
          'units',
        ].indexed)
          SearchKindInfo(
            id: id,
            names: <String, String>{'en': id.toUpperCase()},
            row: 'deck',
            order: i + 1,
          ),
      ],
    );

    List<ResultTab> tabs(List<ItemResult> items, {int words = 0, int? rank}) =>
        resultTabs(
          l10n: _l10n,
          sections: sections,
          spoken: const <String>['en'],
          items: items,
          words: words,
          wordsRank: rank ?? 0,
        );

    test('are only the kinds with results, with their counts', () {
      final found = tabs(
        <ItemResult>[
          _result('topics', 0, id: 'a'),
          _result('topics', 2, id: 'b'),
          _result('units', 2),
        ],
        words: 5,
        rank: 2,
      );
      expect(found.map((t) => t.kind), <String>['topics', 'cards', 'units']);
      expect(found.map((t) => t.count), <int>[2, 5, 1]);
      expect(found.map((t) => t.label), <String>['TOPICS', 'CARDS', 'UNITS']);
    });

    test('open on the kind of the best match, the rest in file order', () {
      final found = tabs(
        <ItemResult>[_result('situations', 4), _result('units', 0)],
        words: 3,
        rank: 2,
      );
      expect(found.map((t) => t.kind), <String>[
        'units',
        'situations',
        'cards',
      ]);
    });

    test('have no tab at all for no result', () {
      expect(tabs(const <ItemResult>[]), isEmpty);
    });
  });

  group('a typo', () {
    test('is put right with the word the results have', () {
      final results = <ItemResult>[_result('topics', 2)];
      expect(correctedQuery('hose', results), 'house');
      expect(correctedQuery('house', results), isNull);
      expect(correctedQuery('zzzzzz', results), isNull);
    });
  });

  group('the searches remembered', () {
    test('keep the newest first, once each, at most five', () {
      final state = AppState.test();
      final session = SearchSession.of(state);
      for (final text in <String>['a1', 'bb', 'cc', 'dd', 'ee', 'ff', 'bb']) {
        session.remember(text);
      }
      expect(session.recent, <String>['bb', 'ff', 'ee', 'dd', 'cc']);
      session.remember(' ');
      expect(session.recent.length, 5);
      expect(SearchSession.of(state), same(session));
    });
  });

  group('the Decks tab, searching', () {
    late AppState state;

    setUp(() async {
      state = await kindsWorldApp();
    });

    testWidgets('has a tab for each kind found, the best match first', (
      tester,
    ) async {
      usePhone(tester);
      await _show(tester, state, 'house');
      expect(find.byType(TabBar), findsOneWidget);
      expect(_tab('Situations'), findsOneWidget);
      expect(_tab('Topics'), findsOneWidget);
      expect(_tab('Words'), findsOneWidget);
      expect(_tab('Units'), findsNothing);
      expect(_tab('Proverbs'), findsNothing);
      // The best match opens first, with its dot.
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
      expect(find.text('House visit'), findsOneWidget);
    });

    testWidgets('lists a topic with its coverage and opens its page', (
      tester,
    ) async {
      usePhone(tester);
      await _show(tester, state, 'house');
      await tester.tap(_tab('Topics'));
      await tester.pumpAndSettle();
      expect(find.text('House words'), findsOneWidget);
      expect(find.text(_l10n.searchTopicKnown(0)), findsOneWidget);
      await tester.tap(find.text('House words'));
      await tester.pumpAndSettle();
      expect(find.byType(TopicPage), findsOneWidget);
    });

    testWidgets('lists the words in the Words tab', (tester) async {
      usePhone(tester);
      await _show(tester, state, 'house');
      await tester.tap(_tab('Words'));
      await tester.pumpAndSettle();
      expect(find.text('casa'), findsOneWidget);
    });

    testWidgets('remembers the last tab used, for the next search', (
      tester,
    ) async {
      usePhone(tester);
      await _show(tester, state, 'last');
      await tester.tap(_tab('Units'));
      await tester.pumpAndSettle();
      await _show(tester, state, 'words');
      // Topics, Decks, Units: the remembered tab is the third.
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
    });

    testWidgets('marks what is above your level and previews it', (
      tester,
    ) async {
      usePhone(tester);
      await _show(tester, state, 'last');
      await tester.tap(_tab('Units'));
      await tester.pumpAndSettle();
      expect(find.text('Unit 3: last'), findsOneWidget);
      expect(find.text(_l10n.searchAboveYourLevel('B1')), findsOneWidget);
      await tester.tap(find.text('Unit 3: last'));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.searchAboveSheetTitle), findsOneWidget);
      expect(
        find.text(_l10n.searchAboveSheetBody('Unit 3: last', 'B1')),
        findsOneWidget,
      );
    });

    testWidgets('marks a topic above your level, which still opens', (
      tester,
    ) async {
      usePhone(tester);
      await _show(tester, state, 'library');
      expect(find.text('Library words'), findsOneWidget);
      expect(find.text(_l10n.searchAboveYourLevel('B1')), findsOneWidget);
    });

    testWidgets('puts a typo right and can search exactly what was typed', (
      tester,
    ) async {
      usePhone(tester);
      await _show(tester, state, 'hose');
      expect(find.text(_l10n.searchShowingResultsFor('house')), findsOneWidget);
      await tester.tap(find.text(_l10n.searchOnlyFor('hose')));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.searchNothing('hose')), findsOneWidget);
    });

    testWidgets('says what the search looks in when nothing is found', (
      tester,
    ) async {
      usePhone(tester);
      await _show(tester, state, 'qzxvbnm');
      expect(find.byType(TabBar), findsNothing);
      expect(find.text(_l10n.searchNothing('qzxvbnm')), findsOneWidget);
      expect(
        find.text(_l10n.searchNothingTypedBody('Testlang')),
        findsOneWidget,
      );
      // A search to try, from the language's own topics.
      expect(find.widgetWithText(ActionChip, 'House words'), findsOneWidget);
    });

    testWidgets('shows a professional situation only here, as added', (
      tester,
    ) async {
      usePhone(tester);
      await _show(tester, state, 'medicine');
      expect(
        find.text(_l10n.searchTagProfessional('Medicine')),
        findsOneWidget,
      );
      expect(find.text(_l10n.searchAddedToCourses), findsOneWidget);
      expect(find.text(_l10n.searchAddToCourses), findsNothing);
    });

    testWidgets('hides what is above your level when the setting says so', (
      tester,
    ) async {
      usePhone(tester);
      state.settings.hideAboveLevel = true;
      await _show(tester, state, 'library');
      expect(find.text('Library words'), findsNothing);
      expect(find.text(_l10n.searchAboveHidden(1)), findsOneWidget);
      await tester.ensureVisible(find.text(_l10n.searchShowAbove));
      await tester.tap(find.text(_l10n.searchShowAbove));
      await tester.pumpAndSettle();
      expect(state.settings.hideAboveLevel, isFalse);
      expect(find.text('Library words'), findsOneWidget);
    });

    testWidgets('shows recent searches and the types before typing', (
      tester,
    ) async {
      usePhone(tester);
      await _show(tester, state, '');
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.searchFindByType), findsOneWidget);
      expect(find.text(_l10n.searchTabsHint), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      await tester.enterText(find.byType(TextField), 'house');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_l10n.decksSearchClear));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.searchRecent), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'house'), findsOneWidget);
    });
  });

  group('adding a professional situation from a result', () {
    testWidgets('downloads it and says it is added', (tester) async {
      usePhone(tester);
      final all = kindsWorld();
      final visible = <String, String>{
        for (final e in all.entries)
          if (!e.key.contains('medicine-registro')) e.key: e.value,
      };
      final remote = FakeDeckRemote(all);
      final phone = MemoryDownloadedDecks();
      final downloads = DeckDownloads(
        fetcher: remote,
        files: phone,
        clock: () => DateTime(2026, 11, 12),
      );
      final state = await kindsWorldApp(
        files: visible,
        build: (files, settings) => AppState.test(
          decks: DeckSources(<DeckSource>[MemoryDeckSource(files), phone]),
          deckDownloads: downloads,
          settings: settings,
        ),
      );
      await tester.runAsync(downloads.refreshIndex);
      await _show(tester, state, 'medicine');
      expect(
        find.text(_l10n.searchTagProfessional('Medicine')),
        findsOneWidget,
      );
      expect(find.text(_l10n.searchProfessionalNote), findsOneWidget);
      await tester.tap(find.text(_l10n.searchAddToCourses));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        (await phone.manifest()).keys,
        contains('decks/zz/zz-medicine-registro.yaml'),
      );
      expect(find.text(_l10n.searchAddedToCourses), findsOneWidget);
    });
  });

  group('the typed search, at 1.4x text, light and dark', () {
    Future<AppState> app() => kindsWorldApp();

    DrawScreen results(String query, {String? tab}) => (tester, mode) async {
      await pumpScreen(
        tester,
        DecksPage(initialQuery: query),
        state: await app(),
        themeMode: mode,
      );
      if (tab != null) {
        await tester.tap(_tab(tab));
        await tester.pumpAndSettle();
      }
    };

    screen('situations tab', results('house'));
    screen('topics tab', results('house', tab: 'Topics'));
    screen('words tab', results('house', tab: 'Words'));
    screen('a professional situation', results('medicine'));
    screen('a unit above your level', results('last', tab: 'Units'));
    screen('a typo', results('hose'));
    screen('no results', results('qzxvbnm'));
  });

  group('the search settings', () {
    test('Hide what is above my level is kept with the settings', () {
      final settings = SettingsNotifier(spokenLanguages: const <String>['en']);
      expect(settings.hideAboveLevel, isFalse);
      settings.hideAboveLevel = true;
      expect(settings.toStored()['hide_above_level'], 'true');
    });
  });
}
