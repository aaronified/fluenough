// The Decks tab's search (#527): typo tolerance, the kind chip on a result,
// the kind:, status: and theme: tokens, suggestions and the script offers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/models/deck.dart' show DeckKind, LanguageInfo;
import 'package:fluenough/core/models/reading.dart' show QuestionCard;
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

    group('the FTS5 index and the matcher alone', () {
      tearDown(() => searchIndexEnabled = true);

      String describe(SearchHit hit) => switch (hit) {
        CardHit() => 'card ${hit.card.id} ${hit.rank} ${hit.moreDecks}',
        EntryHit() => 'entry ${hit.entry.lemma} ${hit.rank}',
        UnitHit() => 'unit ${hit.number} ${hit.rank}',
        DeckHit() => 'deck ${hit.entry.id} ${hit.rank}',
        ComingHit() => 'coming ${hit.unit.title} ${hit.rank}',
      };

      test('find the same cards in the same order', () {
        const queries = <String>[
          'why',
          'namaskaram',
          'namaskarm',
          'to go',
          'qzxvbnm',
          'nam',
          'wa',
        ];
        for (final query in queries) {
          searchIndexEnabled = true;
          final indexed = find(query).map(describe).toList();
          searchIndexEnabled = false;
          final plain = find(query).map(describe).toList();
          expect(indexed, plain, reason: query);
        }
      });
    });

    test('a grammar table row is found as a word, by lemma and gloss', () {
      final native = state.courseNative('te');
      final table = state.decks.firstWhere(
        (e) =>
            e.language.code == 'te' &&
            e.deck.native.code == native &&
            (e.deck.pattern?.entries.isNotEmpty ?? false),
      );
      final row = table.deck.pattern!.entries.first;
      for (final query in <String>[row.lemma, row.gloss]) {
        final hits = find(query);
        final rows = hits.whereType<EntryHit>().where(
          (h) => h.entry.lemma == row.lemma,
        );
        final taught = hits.whereType<CardHit>().where(
          (h) => searchForm(h.card.target) == searchForm(row.lemma),
        );
        // Found once: as the table's row, or as the word the course teaches.
        expect(rows.length + taught.length, greaterThan(0), reason: query);
        expect(rows.isEmpty || taught.isEmpty, isTrue, reason: query);
        for (final hit in rows) {
          expect(hit.kind, SearchKind.grammar);
        }
      }
    });

    test(
      'a card taught in several decks is one row with the others counted',
      () {
        final native = state.courseNative('te');
        final decksOf = <String, List<String>>{};
        for (final e in state.decks) {
          if (e.language.code != 'te' ||
              e.deck.native.code != native ||
              e.deck.pattern != null ||
              e.deck.kind == DeckKind.reading ||
              e.deck.kind == DeckKind.rules) {
            continue;
          }
          for (final card in e.cards) {
            if (card is QuestionCard || card.practiceOnly) continue;
            decksOf.putIfAbsent(card.id, () => <String>[]).add(e.id);
          }
        }
        final shared = decksOf.entries.where((e) => e.value.toSet().length > 1);
        if (shared.isEmpty) {
          markTestSkipped('no card of the Telugu course is in two decks');
          return;
        }
        final id = shared.first.key;
        final decks = shared.first.value.toSet();
        final target = state.decks
            .firstWhere((e) => e.id == shared.first.value.first)
            .cards
            .firstWhere((c) => c.id == id)
            .target;
        final rows = find(target)
            .whereType<CardHit>()
            .where((h) => h.card.id == id);
        expect(rows, hasLength(1));
        expect(rows.single.moreDecks, decks.length - 1);
        expect(rows.single.deck.id, shared.first.value.first);
      },
    );
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
      // The path opens at the unit up next, the bar scrolled away: back up.
      tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      expect(find.text(l10n.searchTokensHeader), findsOneWidget);
      await tester.tap(find.text('status:'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.searchStatusForgetting), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the chips and the text share a line', (tester) async {
      usePhone(tester);
      await pumpTelugu(tester);
      await type(tester, 'kind:grammar ');
      final chip = tester.getRect(find.byType(InputChip));
      final field = tester.getRect(find.byType(TextField));
      expect(chip.right, lessThanOrEqualTo(field.left + 1));
      expect(chip.top, lessThan(field.bottom));
      expect(field.top, lessThan(chip.bottom));
    });

    testWidgets(
      'a tap on the scrim closes the search, one on the bar does not',
      (tester) async {
        usePhone(tester);
        await pumpTelugu(tester);
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        final l10n = l10nOf(tester);
        expect(find.byTooltip(l10n.decksSearchClose), findsOneWidget);
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(find.byTooltip(l10n.decksSearchClose), findsOneWidget);
        await tester.tapAt(const Offset(195, 780));
        await tester.pumpAndSettle();
        expect(find.byTooltip(l10n.decksSearchClose), findsNothing);
      },
    );

    testWidgets('a swipe on the bar runs the search in the next course', (
      tester,
    ) async {
      usePhone(tester);
      final s = AppState.test();
      await s.load();
      s.showLanguage('te');
      if (s.languageChoices.length < 2) {
        markTestSkipped('the test profile learns one language');
        return;
      }
      await pumpScreen(tester, const DecksPage(), state: s);
      await type(tester, 'why');
      await tester.fling(
        find.byIcon(Icons.search).first,
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(s.shownLanguage, isNot('te'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'why',
      );
    });
  });
}
