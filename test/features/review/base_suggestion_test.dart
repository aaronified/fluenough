import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/rater_code.dart';
import 'package:fluenough/core/review/review_file.dart';
import 'package:fluenough/features/decks/card_bases.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/review_sheets.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

/// A reviewer sees a card's base words with their meanings, which agents
/// wrote (#445), and can suggest a change to the meaning of one written in
/// full (#410). A base by ref takes its meaning from the card it names, so
/// it has no chip here.

/// The plain word's bases: one written in full, one by ref to the word
/// that sounds like a rude one.
const String bases =
    '[{ word: "అమ్మ", base: "అమ్మ", reading: "amma", meaning: "mum" }, '
    '{ word: "విధవ", ref: $alikeCard }]';

/// A phone tall enough for every card and sheet to be built.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
}

void main() {
  testWidgets('the card under review shows its bases, and Suggest a change '
      "saves a base's meaning with its word", (tester) async {
    useTallPhone(tester);
    final state = await pumpScreen(
      tester,
      const ReviewPage(deckId: wordsDeck),
      state: await reviewState(reviewing: true, bases: bases),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text('mother'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewCardSheet), findsOneWidget);
    final line = l10n.cardBases(
      2,
      l10n.cardBasesJoin(
        l10n.cardBaseReadingMeaning('అమ్మ', 'amma', 'mum'),
        l10n.cardBaseReadingMeaning('విధవ', 'vidhava', 'widow'),
      ),
    );
    expect(
      find.descendant(of: find.byType(CardFace), matching: find.text(line)),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, l10n.reviewSuggest));
    await tester.pumpAndSettle();
    expect(find.byType(SuggestSheet), findsOneWidget);
    // One chip for the base written in full; none for the base by ref.
    expect(find.text(l10n.reviewPartBaseOf('అమ్మ')), findsOneWidget);
    expect(find.text(l10n.reviewPartBaseOf('విధవ')), findsNothing);

    await tester.tap(find.text(l10n.reviewPartBaseOf('అమ్మ')));
    await tester.pumpAndSettle();
    // Now shows the meaning, and the field starts from it.
    expect(
      find.descendant(
        of: find.byType(MergeSemantics),
        matching: find.text('mum'),
      ),
      findsOneWidget,
    );
    final save = find.widgetWithText(FilledButton, l10n.reviewSave);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reviewSuggestYours),
      'mother',
    );
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reviewSuggestWhy),
      'Mum is informal',
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final words = state.deckById(wordsDeck)!;
    final mother = words.cards.firstWhere((c) => c.id == plainCard);
    final suggestion = state.reviewing.reviewOf(words, mother)!.suggestion!;
    expect(suggestion.part, CardPart.base);
    expect(suggestion.word, 'అమ్మ');
    expect(suggestion.now, 'mum');
    expect(suggestion.text, 'mother');
    expect(suggestion.why, 'Mum is informal');

    // The review file carries which base, so it stands on its own.
    final file = jsonDecode(
      ReviewFile.encode(
        state.reviewing.reviews.of(wordsDeck)!,
        code: RaterCode.tryParse(reviewerCode)!,
        appVersion: '0.4.0',
        made: DateTime.utc(2026, 10, 10),
      ),
    ) as Map<String, Object?>;
    final card = (file['cards']! as List<Object?>).single as Map;
    expect(card['suggestion'], <String, Object?>{
      'part': 'base',
      'word': 'అమ్మ',
      'now': 'mum',
      'text': 'mother',
      'why': 'Mum is informal',
    });
  });

  testWidgets('opened again, the sheet is on the base, and a change to '
      'another part says it replaces the base suggestion', (tester) async {
    useTallPhone(tester);
    final state = await reviewState(reviewing: true, bases: bases);
    final words = state.deckById(wordsDeck)!;
    final mother = words.cards.firstWhere((c) => c.id == plainCard);
    state.reviewing.suggest(
      words,
      mother,
      const Suggestion(
        part: CardPart.base,
        word: 'అమ్మ',
        now: 'mum',
        text: 'mother',
      ),
    );
    await pumpScreen(
      tester,
      Scaffold(
        body: SuggestSheet(deck: words, card: mother),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    final chip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text(l10n.reviewPartBaseOf('అమ్మ')),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(chip.selected, isTrue);
    expect(find.textContaining(l10n.reviewPartBaseOf('అమ్మ')), findsOneWidget);

    await tester.tap(find.text(l10n.reviewPartMeaning));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        l10n.reviewSuggestReplaces(l10n.reviewPartBaseOf('అమ్మ'), 'mother'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a card without bases offers no base chip and shows no base '
      'line', (tester) async {
    useTallPhone(tester);
    await pumpScreen(
      tester,
      const ReviewPage(deckId: wordsDeck),
      state: await reviewState(reviewing: true),
    );
    await tester.tap(find.text('mother'));
    await tester.pumpAndSettle();
    expect(find.byType(BaseLine), findsNothing);
  });
}
