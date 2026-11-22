// The Decks tab's search (#527): typo tolerance, the kind chip on a result,
// the kind:, status: and theme: tokens, suggestions and the script offers.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/models/deck.dart' show DeckKind, LanguageInfo;
import 'package:fluenough/core/models/reading.dart' show QuestionCard;
import 'package:fluenough/core/search/query.dart';
import 'package:fluenough/features/decks/course_card.dart' show CourseCard;
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/unit_search.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:fluenough/ui/widgets/language_bar.dart';

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

    testWidgets('the end button is tappable with the path scrolled, at 1.4x '
        'on 360 dp', (tester) async {
      usePhone(tester, textScale: 1.4);
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      await pumpTelugu(tester);
      // The path opened at the unit up next, the bar scrolled away: put it
      // half under the language bar, as a learner can leave it.
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      scroll.jumpTo(40);
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      await type(tester, 'kind:grammar ');
      final l10n = l10nOf(tester);
      final bar = tester.getBottomLeft(find.byType(LanguageBar)).dy;
      final clear = find.byTooltip(l10n.decksSearchClear);
      // The end button is clear of the language bar, so a tap reaches it.
      expect(tester.getCenter(clear).dy, greaterThan(bar));
      await tester.tap(clear);
      await tester.pumpAndSettle();
      final close = find.byTooltip(l10n.decksSearchClose);
      expect(tester.getCenter(close).dy, greaterThan(bar));
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(close, findsNothing);
    });

    // The owner's sequence: type a search with many results, scroll them,
    // Clear, then Close. The path must be back, with its rows in view.
    Future<void> clearThenClose(
      WidgetTester tester, {
      required bool scrolled,
    }) async {
      usePhone(tester);
      await pumpTelugu(tester);
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      if (scrolled) {
        // Down the path, then back up until the bar is partly in view, as
        // a learner does to reach it.
        scroll.jumpTo(600);
        await tester.pumpAndSettle();
        scroll.jumpTo(40);
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
      }
      await type(tester, 'kind:words ');
      if (scroll.position.maxScrollExtent > 0) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        // Back up to the bar, whose buttons are built only while in view.
        scroll.jumpTo(40);
        await tester.pumpAndSettle();
      }
      final l10n = l10nOf(tester);
      await tester.tap(find.byTooltip(l10n.decksSearchClear));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.decksSearchClose));
      await tester.pumpAndSettle();
      expect(find.byTooltip(l10n.decksSearchClose), findsNothing);
      expect(find.byType(CourseCard), findsOneWidget);
      expect(scroll.offset, 0);
      final path = tester.renderObject<RenderSliver>(
        find.byType(SliverList).first,
      );
      expect(path.geometry!.paintExtent, greaterThan(100));
      final card = tester.getBottomLeft(find.byType(CourseCard)).dy;
      final viewport = tester.getBottomLeft(find.byType(CustomScrollView)).dy;
      expect(card, lessThan(viewport));
    }

    testWidgets('closing a search brings the path back, scrolled', (
      tester,
    ) async {
      await clearThenClose(tester, scrolled: true);
    });

    testWidgets('closing a search brings the path back, unscrolled', (
      tester,
    ) async {
      await clearThenClose(tester, scrolled: false);
    });

    testWidgets('plain text is searched by type, in tabs', (tester) async {
      usePhone(tester);
      await pumpTelugu(tester);
      await type(tester, 'why');
      expect(find.byType(TabBar), findsOneWidget);
      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text('Words')),
        findsOneWidget,
      );
    });

    testWidgets('a kind chip narrows the search to one list, with no tabs', (
      tester,
    ) async {
      usePhone(tester);
      await pumpTelugu(tester);
      await type(tester, 'kind:words ');
      await type(tester, 'why');
      expect(find.widgetWithText(InputChip, 'kind: Words'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Words'), findsWidgets);
    });

    testWidgets('nothing found says what the search looks in', (tester) async {
      usePhone(tester);
      await pumpTelugu(tester);
      await type(tester, 'qzxvbnm');
      final l10n = l10nOf(tester);
      expect(find.text(l10n.searchNothing('qzxvbnm')), findsOneWidget);
      expect(find.text(l10n.searchNothingTypedBody('Telugu')), findsOneWidget);
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
      // The test font draws every glyph a full em wide, so a chip is wider
      // here than on a phone: a wider screen leaves the text its room.
      tester.view.physicalSize = const Size(600 * 3, 844 * 3);
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
        // The menu and the offers make the bar's header tall: scroll so the
        // gap under the course card (the scrim starts there) is on screen,
        // then tap it.
        final controller = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        final cardBottom = tester.getRect(find.byType(CourseCard)).bottom;
        if (cardBottom > 600) {
          controller.jumpTo(controller.offset + cardBottom - 400);
          await tester.pumpAndSettle();
        }
        final card = tester.getRect(find.byType(CourseCard));
        await tester.tapAt(Offset(195, card.bottom + 10));
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
