import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/stats/leeches.dart';
import 'package:fluenough/features/stats/leeches_page.dart';

import '../../support/harness.dart';

Future<AppState> fixture({
  FeatureRegistry? features,
  bool history = true,
}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(
    app,
    features: features ?? FeatureRegistry.all(),
    history: history,
  );
}

/// The first fixture leech: el pan, es-en-core-100, production, 5 lapses.
Finder firstCard() => find.byType(LeechCard).first;

Finder inFirst(Finder f) => find.descendant(of: firstCard(), matching: f);

void main() {
  testWidgets('lists the fixture leeches with their lapses', (tester) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const LeechesPage(),
      state: await fixture(),
    );
    final l10n = l10nOf(tester);
    final deck = state.deckById('es-en-core-100')!.deck.name;

    expect(find.text(l10n.leechesIntro(kLeechThreshold)), findsOneWidget);
    expect(find.byType(LeechCard), findsNWidgets(2));
    expect(inFirst(find.text('el pan')), findsOneWidget);
    expect(inFirst(find.text('the bread')), findsOneWidget);
    expect(
      inFirst(find.text(l10n.leechesMeta(deck, l10n.skillProduction))),
      findsOneWidget,
    );
    expect(inFirst(find.text(l10n.leechesLapses(5))), findsOneWidget);
    // Each card reads as one node, the count spelled out rather than "5×".
    final spoken = find.bySemanticsLabel(
      RegExp(RegExp.escape(l10n.leechesLapsesSemantics(5))),
    );
    expect(spoken, findsNWidgets(2));
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(l10n.leechesLapses(5)))),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('Reset, Undo, Set aside and Bring back append, never delete', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const LeechesPage(),
      state: await fixture(),
    );
    final l10n = l10nOf(tester);
    final deck = state.deckById('es-en-core-100')!.deck.name;
    final skill = l10n.skillProduction;
    final before = List<ReviewEvent>.of(state.progress.log);
    final statesBefore = Map.of(state.progress.states);
    final actions = LeechActions.of(state.progress);

    Future<void> tap(String label) async {
      await tester.tap(inFirst(find.text(label)));
      await tester.pumpAndSettle();
    }

    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: firstCard(),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    await tap(l10n.leechesReset);
    expect(
      inFirst(find.text(l10n.leechesMetaReset(deck, skill))),
      findsOneWidget,
    );
    expect(inFirst(find.text(l10n.commonUndo)), findsOneWidget);
    expect(opacity(), lessThan(1));

    await tap(l10n.commonUndo);
    expect(inFirst(find.text(l10n.leechesMeta(deck, skill))), findsOneWidget);
    expect(opacity(), 1);

    await tap(l10n.leechesSetAside);
    expect(
      inFirst(find.text(l10n.leechesMetaSetAside(deck, skill))),
      findsOneWidget,
    );
    expect(inFirst(find.text(l10n.leechesReset)), findsOneWidget);

    await tap(l10n.leechesBringBack);
    expect(inFirst(find.text(l10n.leechesSetAside)), findsOneWidget);

    expect(actions.log.map((a) => a.kind), <LeechActionKind>[
      LeechActionKind.reset,
      LeechActionKind.undoReset,
      LeechActionKind.setAside,
      LeechActionKind.bringBack,
    ]);
    expect(state.progress.log, orderedEquals(before), reason: 'rule 9');
    expect(state.progress.states, statesBefore);
  });

  testWidgets('with no leeches it says so', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const LeechesPage(),
      state: await fixture(history: false),
    );
    expect(find.text(l10nOf(tester).leechesEmpty), findsOneWidget);
    expect(find.byType(LeechCard), findsNothing);
  });

  testWidgets('while Feature.leeches is incoming the actions are disabled', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const LeechesPage(),
      state: await fixture(
        features: const FeatureRegistry.only(<Feature>{Feature.stats}),
      ),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.incomingBadge), findsOneWidget);
    await tester.tap(
      inFirst(find.text(l10n.leechesReset)),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(LeechActions.of(state.progress).log, isEmpty);
    expect(find.text(l10n.incomingSnackBar), findsOneWidget);
  });
}
