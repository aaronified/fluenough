// "The sounds of this word" (ADR-0041): on a card with an IPA, it opens a
// recorded session of the IPA cards whose symbols occur in it; for a learner
// not learning the IPA, it first offers to add the course.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/features/drill/sounds_of_word.dart';

import '../../support/harness.dart';
import '../../support/ipa_course.dart';

Future<(AppState, Card)> pumpWord(
  WidgetTester tester,
  List<String> learning, {
  String card = 'hi-0001',
}) async {
  usePhone(tester);
  final state = ipaApp(learning);
  addTearDown(state.dispose);
  await state.load();
  final word = state
      .deckById('hi-en-words')!
      .cards
      .firstWhere((c) => c.id == card);
  await pumpScreen(
    tester,
    Scaffold(
      body: Center(child: SoundsOfWordButton(card: word)),
    ),
    state: state,
  );
  return (state, word);
}

void main() {
  testWidgets('a learner who is not learning the IPA is offered the course, '
      'and adding it opens the session', (tester) async {
    final (state, _) = await pumpWord(tester, <String>['hi']);
    await tester.tap(find.byTooltip('The sounds of this word'));
    await tester.pumpAndSettle();
    expect(find.text('Add the IPA course?'), findsOneWidget);
    expect(state.learnsIpa, isFalse);

    await tester.tap(find.text('Add the course'));
    await tester.pumpAndSettle();
    expect(state.learnsIpa, isTrue);
    expect(state.learningCodes, {'hi', 'ipa'});
    // The session: the first symbol of the word is taught.
    expect(find.text('ɳ'), findsWidgets);
  });

  testWidgets('not now leaves the course out and opens nothing', (
    tester,
  ) async {
    final (state, _) = await pumpWord(tester, <String>['hi']);
    await tester.tap(find.byTooltip('The sounds of this word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(state.learnsIpa, isFalse);
    expect(find.text('ɳ'), findsNothing);
  });

  testWidgets('a learner of the IPA goes straight to the session', (
    tester,
  ) async {
    await pumpWord(tester, <String>['hi', 'ipa']);
    await tester.tap(find.byTooltip('The sounds of this word'));
    await tester.pumpAndSettle();
    expect(find.text('Add the IPA course?'), findsNothing);
    expect(find.text('ɳ'), findsWidgets);
  });

  testWidgets('a word whose sounds the course has no card for says so', (
    tester,
  ) async {
    await pumpWord(tester, <String>['hi', 'ipa'], card: 'hi-0002');
    await tester.tap(find.byTooltip('The sounds of this word'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The IPA course has no symbols for the sounds of this word yet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a card with no IPA has no button', (tester) async {
    usePhone(tester);
    final state = ipaApp(<String>['hi', 'ipa']);
    addTearDown(state.dispose);
    await state.load();
    final symbol = state.deckById('ipa-en-basics')!.cards.first;
    await pumpScreen(
      tester,
      Scaffold(body: SoundsOfWordButton(card: symbol)),
      state: state,
    );
    expect(find.byTooltip('The sounds of this word'), findsNothing);
  });
}
