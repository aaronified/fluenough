import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/stats/leeches.dart';
import 'package:fluenough/features/stats/leeches_page.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/ui/widgets/segmented.dart';
import 'package:fluenough/ui/widgets/stat_tile.dart';

import '../../support/harness.dart';

/// The gallery's history: twelve days ending yesterday, 22 reviews in each
/// of es-en-core-100 and ja-en-hiragana (12 recognition, all remembered; 10
/// production on one leech, half remembered).
Future<AppState> fixture({FeatureRegistry? features}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(
    app,
    features: features ?? FeatureRegistry.all(),
  );
}

Finder tile(String value, String label) => find.byWidgetPredicate(
  (w) => w is StatTile && w.value == value && w.label == label,
);

/// Builds [finder] in the lazy list, then brings it fully on screen:
/// `scrollUntilVisible` stops once it is built in the cache extent.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Taps the language chip [label], scrolling the row to it first.
Future<void> tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Counts every language together, as the tab did before it named one.
Future<void> showAll(WidgetTester tester) =>
    tapChip(tester, l10nOf(tester).statsLanguageAll);

void main() {
  testWidgets('with stats switched off, the tab shows that they are incoming', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const StatsPage(),
      state: await fixture(features: const FeatureRegistry.only(<Feature>{})),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.statsIncomingTitle), findsOneWidget);
    expect(find.text(l10n.statsIncomingBody), findsOneWidget);
    expect(find.text(l10n.incomingBadge), findsOneWidget);
    expect(find.byType(StatTile), findsNothing);
  });

  testWidgets('as shipped, the tab shows the numbers from the log', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const StatsPage(),
      state: await fixture(features: const FeatureRegistry.shipped()),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.statsIncomingTitle), findsNothing);
    expect(find.byType(StatTile), findsWidgets);
  });

  testWidgets('with no reviews it says so', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const StatsPage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    expect(find.text(l10nOf(tester).statsNoReviews), findsOneWidget);
    expect(find.byType(Segmented<Object>), findsNothing);
  });

  testWidgets('the tiles are computed from the log, and follow the range', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const StatsPage(), state: await fixture());
    await showAll(tester);
    final l10n = l10nOf(tester);
    final all = l10n.commonPercent(34 / 44);

    // 30 days, the default: the whole twelve-day history.
    expect(tile('44', l10n.statsReviews), findsOneWidget);
    expect(tile(all, l10n.statsRemembered), findsOneWidget);
    expect(tile('12', l10n.statsDayStreak), findsOneWidget);
    expect(tile('26', l10n.statsNewCardsLearned), findsOneWidget);

    await tester.tap(find.text(l10n.statsRangeDays(7)));
    await tester.pumpAndSettle();
    expect(tile('24', l10n.statsReviews), findsOneWidget);
    expect(
      tile(l10n.commonPercent(18 / 24), l10n.statsRemembered),
      findsOneWidget,
    );
    expect(tile('12', l10n.statsNewCardsLearned), findsOneWidget);

    await tester.tap(find.text(l10n.statsRangeAll));
    await tester.pumpAndSettle();
    expect(tile('44', l10n.statsReviews), findsOneWidget);
    expect(tile('12', l10n.statsLongestStreak), findsOneWidget);
    expect(tile('26', l10n.statsCardsLearned), findsOneWidget);
    expect(find.text(l10n.statsDayStreak), findsNothing);
  });

  testWidgets('the grid, bars and tags read as computed values', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await pumpScreen(tester, const StatsPage(), state: await fixture());
    await showAll(tester);
    final l10n = l10nOf(tester);

    expect(
      find.bySemanticsLabel(l10n.statsHeatmapLabel),
      findsOneWidget,
      reason: 'the grid is one node',
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(l10n.statsHeatmapLabel)),
      isSemantics(
        label: l10n.statsHeatmapLabel,
        value: l10n.statsHeatmapSummary(12, 84, 44),
      ),
    );

    for (final label in <String>[
      l10n.statsBarSemantics(l10n.skillRecognition, 1),
      l10n.statsBarSemantics(l10n.skillProduction, 0.5),
      // Weakest first: el agua and el pan (6 of 11), then hiragana (17/22).
      l10n.statsBarSemantics('food', 6 / 11),
      l10n.statsBarSemantics('hiragana', 17 / 22),
    ]) {
      final bar = find.bySemanticsLabel(label);
      await scrollTo(tester, bar);
      expect(bar, findsOneWidget, reason: label);
    }
    handle.dispose();
  });

  testWidgets('the leeches row counts the fixture leeches and opens them', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const StatsPage(),
      state: await fixture(),
    );
    await showAll(tester);
    final l10n = l10nOf(tester);
    await scrollTo(tester, find.text(l10n.statsLeeches(2)));

    // One set aside no longer counts.
    final leech = findLeeches(
      state.progress,
      cardOf: cardLookupOf(state),
    ).first;
    LeechActions.of(state.progress).toggleSetAside(leech.key, now: state.now());
    await tester.pumpAndSettle();
    final row = find.text(l10n.statsLeeches(1));
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(LeechesPage), findsOneWidget);
  });

  testWidgets('before #19 the leeches row is incoming and stays put', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    await pumpScreen(
      tester,
      const StatsPage(),
      state: await fixture(
        features: const FeatureRegistry.only(<Feature>{Feature.stats}),
      ),
    );
    await showAll(tester);
    final l10n = l10nOf(tester);
    final row = find.bySemanticsLabel(
      l10n.incomingSemanticsLabel(l10n.statsLeeches(2)),
    );
    await scrollTo(tester, row);
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(LeechesPage), findsNothing);
    expect(find.text(l10n.incomingSnackBar), findsOneWidget);
    handle.dispose();
  });

  group('by language', () {
    /// The fixture, plus one Spanish review this morning: Spanish is the
    /// language reviewed last, and only its streak reaches today.
    Future<AppState> spanishToday() async {
      final state = await fixture();
      await state.load();
      final deck = state.deckById('es-en-core-100')!;
      state.progress.record(
        deckId: deck.id,
        cardId: deck.cards.first.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: dateOnly(state.now()).add(const Duration(hours: 9)),
      );
      return state;
    }

    String nameOf(AppState state, String code) =>
        state.languages.singleWhere((l) => l.code == code).name;

    testWidgets('opens on the language reviewed last, and each chip counts '
        'only its own', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const StatsPage(),
        state: await spanishToday(),
      );
      final l10n = l10nOf(tester);
      bool chosen(String label) => tester
          .widget<FilterChip>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(FilterChip),
            ),
          )
          .selected;

      final spanish = nameOf(state, 'es');
      final japanese = nameOf(state, 'ja');
      // Most recently reviewed first, so that the chip the tab opens on is
      // on screen; All languages last.
      final chips = find.byType(FilterChip);
      double startOf(String label) => tester
          .getRect(find.ancestor(of: find.text(label), matching: chips))
          .left;
      expect(startOf(spanish), lessThan(startOf(japanese)));
      expect(startOf(japanese), lessThan(startOf(l10n.statsLanguageAll)));
      expect(
        tester.getRect(find.ancestor(of: find.text(spanish), matching: chips)),
        isA<Rect>().having((r) => r.right, 'right', lessThanOrEqualTo(390)),
      );
      expect(chosen(spanish), isTrue);
      expect(chosen(japanese), isFalse);
      expect(chosen(l10n.statsLanguageAll), isFalse);
      expect(tile('23', l10n.statsReviews), findsOneWidget);
      expect(tile('13', l10n.statsDayStreak), findsOneWidget);
      expect(tile('13', l10n.statsNewCardsLearned), findsOneWidget);

      await tapChip(tester, japanese);
      expect(chosen(japanese), isTrue);
      expect(tile('22', l10n.statsReviews), findsOneWidget);
      // Japanese was last reviewed yesterday: its own streak, not Spanish's.
      expect(tile('12', l10n.statsDayStreak), findsOneWidget);
      expect(
        tile(l10n.commonPercent(17 / 22), l10n.statsRemembered),
        findsOneWidget,
      );
      await scrollTo(tester, find.text(l10n.statsLeeches(1)));
      expect(find.text(l10n.statsLeeches(1)), findsOneWidget);
      await tester.fling(
        find.byType(Scrollable).last,
        const Offset(0, 3000),
        3000,
      );
      await tester.pumpAndSettle();

      await tapChip(tester, l10n.statsLanguageAll);
      expect(tile('45', l10n.statsReviews), findsOneWidget);
      expect(tile('13', l10n.statsDayStreak), findsOneWidget);
      expect(tile('26', l10n.statsNewCardsLearned), findsOneWidget);

      // The choice holds as the range changes.
      await tester.tap(find.text(l10n.statsRangeDays(7)));
      await tester.pumpAndSettle();
      expect(chosen(l10n.statsLanguageAll), isTrue);
    });

    testWidgets('the leeches row opens that language\'s leeches only', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const StatsPage(),
        state: await spanishToday(),
      );
      final l10n = l10nOf(tester);
      final japanese = nameOf(state, 'ja');
      await tapChip(tester, japanese);

      final row = find.text(l10n.statsLeeches(1));
      await scrollTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text(l10n.leechesTitleIn(japanese)), findsOneWidget);
      final cards = tester.widgetList<LeechCard>(find.byType(LeechCard));
      expect(cards, hasLength(1));
      expect(cards.single.leech.card.deckId, 'ja-en-hiragana');
    });

    testWidgets('one language is named by its chip, with no All', (
      tester,
    ) async {
      usePhone(tester);
      final base = AppState.test();
      await base.load();
      final progress = MemoryProgress();
      final deck = base.deckById('es-en-core-100')!;
      progress.record(
        deckId: deck.id,
        cardId: deck.cards.first.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: base.now(),
      );
      final state = await pumpScreen(
        tester,
        const StatsPage(),
        state: AppState.test(progress: progress),
      );
      final l10n = l10nOf(tester);
      expect(find.byType(FilterChip), findsOneWidget);
      expect(find.text(nameOf(state, 'es')), findsOneWidget);
      expect(find.text(l10n.statsLanguageAll), findsNothing);
      expect(tile('1', l10n.statsReviews), findsOneWidget);
    });

    testWidgets('a review that cannot be placed in a language still counts, '
        'under All languages', (tester) async {
      usePhone(tester);
      final base = AppState.test();
      await base.load();
      final progress = MemoryProgress();
      final deck = base.deckById('es-en-core-100')!;
      for (final deckId in <String>[deck.id, 'xx-en-gone']) {
        progress.record(
          deckId: deckId,
          cardId: deckId == deck.id ? deck.cards.first.id : 'xx-en-gone-0001',
          mode: DrillMode.recognition,
          grade: 4,
          now: base.now(),
        );
      }
      await pumpScreen(
        tester,
        const StatsPage(),
        state: AppState.test(progress: progress),
      );
      final l10n = l10nOf(tester);
      expect(tile('1', l10n.statsReviews), findsOneWidget);
      await showAll(tester);
      expect(tile('2', l10n.statsReviews), findsOneWidget);
    });
  });
}
