import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
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

void main() {
  testWidgets('as shipped, the tab shows that Progress is incoming', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const StatsPage(),
      state: await fixture(features: const FeatureRegistry.shipped()),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.statsIncomingTitle), findsOneWidget);
    expect(find.text(l10n.statsIncomingBody), findsOneWidget);
    expect(find.text(l10n.incomingBadge), findsOneWidget);
    expect(find.byType(StatTile), findsNothing);
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
}
