import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/inspect_page.dart';
import 'package:fluenough/features/drill/grammar_cells.dart';

import '../../support/harness.dart';

Future<void> scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

void main() {
  testWidgets('a deck page opens Inspect for that deck', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const DeckDetailPage(deckId: 'hi-en-market'));
    final l10n = l10nOf(tester);
    final button = find.text(l10n.deckInspect);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      tester.widget<InspectPage>(find.byType(InspectPage)).deckId,
      'hi-en-market',
    );
  });

  testWidgets('every card is shown in full, with its id', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const InspectPage(deckId: 'hi-en-market'),
    );
    final l10n = l10nOf(tester);
    final cards = state.deckById('hi-en-market')!.cards;
    final first = cards.first;
    expect(find.text(l10n.inspectTitle('Market')), findsOneWidget);
    expect(find.text(l10n.inspectId(first.id)), findsOneWidget);
    expect(find.text(first.native), findsWidgets);
    expect(find.text(first.reading!), findsWidgets);

    // Two or three lines a card; the rest opens in place.
    final noted = cards.firstWhere((c) => c.notes.isNotEmpty);
    expect(find.textContaining(noted.notes.first.text), findsNothing);
    await scrollTo(tester, find.text(l10n.inspectId(noted.id)));
    await tester.tap(find.text(l10n.inspectId(noted.id)));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.textContaining(noted.notes.first.text));

    await scrollTo(tester, find.text(l10n.inspectId(cards.last.id)));
  });

  testWidgets('a grammar deck shows each table, a cell id per form', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const InspectPage(deckId: 'hi-en-grammar-present'),
    );
    final l10n = l10nOf(tester);
    final entry = state.deckById('hi-en-grammar-present')!;
    final card = entry.cards.first;
    final cell = grammarCellOf(card, entry.deck)!;
    expect(find.text(cell.entry.gloss), findsWidgets);
    expect(find.text('${cell.pattern.slotName}: ${cell.slot}'), findsWidgets);
    expect(find.text(l10n.inspectId(card.id)), findsOneWidget);
    await scrollTo(tester, find.text(l10n.inspectId(entry.cards.last.id)));
  });

  testWidgets('a reading deck shows passages, questions with the right '
      'answer marked, and the glossary', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const InspectPage(deckId: 'bn-en-reading-sahaj-path-1'),
    );
    final l10n = l10nOf(tester);
    final passage = state
        .deckById('bn-en-reading-sahaj-path-1')!
        .deck
        .passages
        .first;
    expect(find.text(l10n.inspectId(passage.id)), findsOneWidget);
    expect(find.text(passage.title), findsOneWidget);
    final question = passage.questions.first;
    await scrollTo(tester, find.text(l10n.inspectId(question.id)));
    await tester.ensureVisible(find.text(l10n.inspectId(question.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.inspectId(question.id)));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(l10n.readingChoiceRight))),
      findsWidgets,
    );
  });

  testWidgets('a deck that is not loaded says so', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const InspectPage(deckId: 'xx-en-nothing'),
      state: AppState.test(),
    );
    expect(find.text(l10nOf(tester).deckNotFound), findsOneWidget);
  });
}
