// The Learn and Relearn walk (#694), drawn in the shared drill shell: the
// first card has no back chevron, going on shows the next card and its
// position, back returns, and going on from the last card leaves the walk.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/features/drill/walkthrough_page.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const String _deck = 'es-en-walk';

MemoryDeckSource _twoCards() => MemoryDeckSource(const <String, String>{
  'decks/es/es-en-walk.yaml': '''
schema: 1
id: es-en-walk
name: Walk
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-9101
    target: "gato"
    native: "cat"
  - id: es-9102
    target: "perro"
    native: "dog"
''',
  'decks/es/es-path.yaml': '''
schema: 1
kind: path
id: es-path
language: es
units:
  - [es-walk]
''',
});

/// Opens the walk over a first route, so that going on from the last card
/// has a route to leave.
Future<void> _openWalk(WidgetTester tester) async {
  usePhone(tester);
  await pumpScreen(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const WalkthroughPage(
                request: WalkthroughRequest(deckIds: <String>[_deck]),
              ),
            ),
          ),
          child: const Text('open'), // ui-literal-ok: a test's own button
        ),
      ),
    ),
    state: AppState.test(decks: _twoCards()),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Taps a chevron and lets the card's slide, and the chevrons' one-second
/// wait, run out.
Future<void> _tapChevron(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('walks two cards: no back chevron on the first, next shows the '
      'second and its position, back returns, next on the last leaves', (
    tester,
  ) async {
    await _openWalk(tester);
    final l10n = l10nOf(tester);

    expect(find.byType(WalkthroughPage), findsOneWidget);
    expect(find.text('gato'), findsWidgets);
    expect(find.text('perro'), findsNothing);
    expect(find.text(l10n.drillPositionShort(1, 2)), findsOneWidget);
    expect(find.byTooltip(l10n.drillPreviousCard), findsNothing);
    expect(find.byTooltip(l10n.drillNextCard), findsOneWidget);

    await _tapChevron(tester, l10n.drillNextCard);
    expect(find.text('perro'), findsWidgets);
    expect(find.text('gato'), findsNothing);
    expect(find.text(l10n.drillPositionShort(2, 2)), findsOneWidget);
    expect(find.byTooltip(l10n.drillPreviousCard), findsOneWidget);

    await _tapChevron(tester, l10n.drillPreviousCard);
    expect(find.text('gato'), findsWidgets);
    expect(find.text('perro'), findsNothing);
    expect(find.text(l10n.drillPositionShort(1, 2)), findsOneWidget);
    expect(find.byTooltip(l10n.drillPreviousCard), findsNothing);

    await _tapChevron(tester, l10n.drillNextCard);
    await _tapChevron(tester, l10n.drillNextCard);
    expect(find.byType(WalkthroughPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
