// "Checked by N speakers" on a word's card (#449): the reviewers who
// signed the card off, as its deck's `checked_by` lists them; nothing when
// no one has.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/features/decks/checked_by_line.dart';
import 'package:fluenough/features/decks/word_sheet.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

void main() {
  testWidgets('a word\'s card says how many speakers checked it', (
    tester,
  ) async {
    usePhone(tester);
    final state = await reviewState(
      checkedBy: const <String>[reviewerCode, otherCode],
    );
    final words = state.deckById(wordsDeck)!;
    final mother = words.cards.firstWhere((c) => c.id == plainCard);
    expect(checkedByOf(state.decks, mother), <String>{reviewerCode, otherCode});
    await pumpScreen(
      tester,
      Scaffold(
        body: WordSheet(card: mother, language: words.language),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.cardCheckedBy(2)), findsOneWidget);
  });

  testWidgets('a card no one has checked says nothing of it', (tester) async {
    usePhone(tester);
    final state = await reviewState();
    final words = state.deckById(wordsDeck)!;
    await pumpScreen(
      tester,
      Scaffold(
        body: WordSheet(card: words.cards.first, language: words.language),
      ),
      state: state,
    );
    expect(find.byType(CheckedByLine), findsNothing);
  });

  testWidgets('one speaker is singular', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const Scaffold(body: CheckedByLine(count: 1)),
      state: await reviewState(),
    );
    expect(find.text(l10nOf(tester).cardCheckedBy(1)), findsOneWidget);
    expect(find.text('Checked by 1 speaker'), findsOneWidget);
  });
}
