// The Decks tab's search (#527): typo tolerance, the kind chip on a result,
// the kind:, status: and theme: tokens, suggestions and the script offers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/models/deck.dart' show LanguageInfo;
import 'package:fluenough/core/search/query.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/unit_search.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';

import 'support/harness.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('searching the course', () {
    late AppState state;
    late List<LanguageInfo> telugu;

    setUpAll(() async {
      state = AppState.test();
      await state.load();
      telugu = <LanguageInfo>[
        for (final l in state.languages)
          if (l.code == 'te') l,
      ];
    });

    List<SearchHit> find(
      String query, {
      Map<SearchToken, String> chips = const <SearchToken, String>{},
    }) => searchCourses(state, l10n, query, telugu, chips: chips);

    List<String> cardIds(List<SearchHit> hits) => <String>[
      for (final hit in hits)
        if (hit is CardHit) hit.card.id,
    ];

    test('a typo still finds the word, marked as a close match', () {
      final hits = find('namaskarm');
      expect(cardIds(hits), contains('te-0135'));
      expect(hits.every((h) => h.isClose), isTrue);
      expect(find('namaskaram').any((h) => h.isClose), isFalse);
    });

    test('typos are looked for only when nothing is found exactly', () {
      // "why" is exact in te-0164; a near word such as "who" does not
      // crowd in beside it.
      final hits = find('why');
      expect(hits.where((h) => h.isClose), isEmpty);
    });

    test('nothing close finds nothing', () {
      expect(find('qzxvbnm'), isEmpty);
    });

    test('a kind chip narrows to that kind, on each result', () {
      final words = find(
        'why',
        chips: <SearchToken, String>{SearchToken.kind: 'words'},
      );
      expect(cardIds(words), contains('te-0164'));
      expect(
        words.every((h) => h.kind == SearchKind.words || h.kind == null),
        isTrue,
      );
      final grammar = find(
        'why',
        chips: <SearchToken, String>{SearchToken.kind: 'grammar'},
      );
      expect(cardIds(grammar), isNot(contains('te-0164')));
    });

    test('kind:grammar typed with a space is the same as the chip', () {
      final typed = find('kind:grammar ');
      expect(typed, isNotEmpty);
      expect(
        typed.every((h) => h.kind == SearchKind.grammar),
        isTrue,
        reason: 'only grammar rows',
      );
    });

    test('a chip with no text lists everything it allows, units first', () {
      final hits = find(
        '',
        chips: <SearchToken, String>{SearchToken.kind: 'words'},
      );
      expect(hits.whereType<UnitHit>(), isNotEmpty);
      expect(hits.whereType<CardHit>().length, greaterThan(60));
      final firstCard = hits.indexWhere((h) => h is CardHit);
      expect(hits.take(firstCard).every((h) => h is! CardHit), isTrue);
    });

    test('status: a fresh learner has every card not learnt', () {
      final notLearnt = find(
        'why',
        chips: <SearchToken, String>{SearchToken.status: 'not-learnt'},
      );
      expect(cardIds(notLearnt), contains('te-0164'));
      for (final status in <String>[
        'learning',
        'learnt',
        'forgetting',
        'struggling',
        'set-aside',
      ]) {
        expect(
          find('why', chips: <SearchToken, String>{SearchToken.status: status}),
          isEmpty,
          reason: status,
        );
      }
    });

    test('theme: keeps the theme\'s units and decks, and its words', () {
      final themes = courseThemes(state, 'te');
      expect(themes, isNotEmpty);
      final theme = themes.first;
      final hits = find(
        '',
        chips: <SearchToken, String>{SearchToken.theme: theme.id},
      );
      expect(hits, isNotEmpty);
      for (final hit in hits) {
        final decks = switch (hit) {
          UnitHit() => hit.decks,
          DeckHit() => [hit.entry],
          _ => null,
        };
        if (decks == null) continue;
        expect(decks.any((e) => state.themeOf(e)?.id == theme.id), isTrue);
      }
    });

    test('a theme the course has no deck for is not offered', () {
      final offered = {for (final t in courseThemes(state, 'te')) t.id};
      expect(offered.length, lessThan(state.themes.length + 1));
      expect(offered.difference({for (final t in state.themes) t.id}), isEmpty);
    });

    test('a query in another script is not searched; it is named', () {
      expect(foreignScript('पानी', telugu.first), 'devanagari');
      expect(foreignScript('ఎందుకు', telugu.first), isNull);
      expect(foreignScript('water', telugu.first), isNull);
      final outcome = runSearch(state, l10n, text: 'পানী', languages: telugu);
      expect(outcome.foreign, 'bengali');
      expect(outcome.hits, isEmpty);
    });

    test('suggestions complete the token names and never the typed text', () {
      final tokens = searchSuggestions(state, l10n, 'ki', telugu.first);
      expect(tokens.first.token, SearchToken.kind);
      final words = searchSuggestions(state, l10n, 'nam', telugu.first);
      expect(words.length, lessThanOrEqualTo(3));
      expect(words.every((s) => s.text != 'nam'), isTrue);
      expect(searchSuggestions(state, l10n, 'qzxvbnm', telugu.first), isEmpty);
    });
  });

  group('the Decks tab', () {
    Future<void> pumpTelugu(WidgetTester tester, {AppState? state}) async {
      final s = state ?? AppState.test();
      await s.load();
      s.showLanguage('te');
      await pumpScreen(tester, const DecksPage(), state: s);
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pumpAndSettle();
    }

    testWidgets('a token typed whole becomes a chip inside the bar', (
      tester,
    ) async {
      usePhone(tester);
      await pumpTelugu(tester);
      await type(tester, 'kind:grammar ');
      expect(find.widgetWithText(InputChip, 'kind: Grammar'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('the end button clears the search, then closes it', (
      tester,
    ) async {
      usePhone(tester);
      await pumpTelugu(tester);
      await type(tester, 'kind:grammar ');
      final l10n = l10nOf(tester);
      await tester.tap(find.byTooltip(l10n.decksSearchClear));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      await tester.tap(find.byTooltip(l10n.decksSearchClose));
      await tester.pumpAndSettle();
      expect(find.byTooltip(l10n.decksSearchClose), findsNothing);
    });

    testWidgets('a kind chip on a result narrows the search to that kind', (
      tester,
    ) async {
      usePhone(tester);
      await pumpTelugu(tester);
      await type(tester, 'why');
      final chip = find.text('Words').first;
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'kind: Words'), findsOneWidget);
    });

    testWidgets('nothing found says what the search looks in', (tester) async {
      usePhone(tester);
      await pumpTelugu(tester);
      await type(tester, 'qzxvbnm');
      final l10n = l10nOf(tester);
      expect(find.text(l10n.searchNothing('qzxvbnm')), findsOneWidget);
      expect(find.text(l10n.searchNothingBody), findsOneWidget);
    });

    testWidgets('at 1.4x text the bar, the chips and the menu fit', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      await pumpTelugu(tester);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      expect(find.text(l10n.searchTokensHeader), findsOneWidget);
      await tester.tap(find.text('status:'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.searchStatusForgetting), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
