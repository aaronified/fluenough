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
/// wrote (#445), and can suggest a change to one (#410), its form, reading
/// and meaning since #476. A base by ref has its box too, its form, reading
/// and meaning those of the card it names.

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
    // A box for each base, its name in capitals but the base as the deck
    // writes it: the one by ref is named by the card it names (#476).
    final name = l10n.reviewPartBaseOf('అమ్మ');
    expect(find.text(name.toUpperCase()), findsOneWidget);
    expect(
      find.text(l10n.reviewPartBaseOf('విధవ').toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(l10n.reviewBaseByCard('widow', alikeCard)), findsOne);

    await tester.tap(find.byTooltip(l10n.reviewSuggestEditPart(name)));
    await tester.pumpAndSettle();
    // Now shows the base, and its fields start from it.
    expect(
      find.descendant(
        of: find.byType(MergeSemantics),
        matching: find.text('mum'),
      ),
      findsOneWidget,
    );
    String field(String f) => tester
        .widget<TextField>(find.byKey(SuggestSheet.baseKey('అమ్మ', f)))
        .controller!
        .text;
    expect(
      <String>[field('form'), field('reading'), field('meaning')],
      <String>['అమ్మ', 'amma', 'mum'],
    );
    final save = find.byTooltip(l10n.reviewSuggestSaveAll);
    await tester.enterText(
      find.byKey(SuggestSheet.baseKey('అమ్మ', 'meaning')),
      'mother',
    );
    await tester.enterText(
      find.byKey(SuggestSheet.baseKey('అమ్మ', 'why')),
      'Mum is informal',
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final words = state.deckById(wordsDeck)!;
    final mother = words.cards.firstWhere((c) => c.id == plainCard);
    final suggestion = state.reviewing
        .reviewOf(words, mother)!
        .suggestions
        .single;
    expect(suggestion.part, CardPart.base);
    expect(suggestion.word, 'అమ్మ');
    expect(suggestion.action, BaseAction.edit);
    expect(
      suggestion.was,
      const BaseForm(base: 'అమ్మ', reading: 'amma', meaning: 'mum'),
    );
    expect(
      suggestion.base,
      const BaseForm(base: 'అమ్మ', reading: 'amma', meaning: 'mother'),
    );
    expect(suggestion.why, 'Mum is informal');

    // The review file carries which base and what it does, so it stands on
    // its own.
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
      'action': 'edit',
      'was': <String, Object?>{
        'base': 'అమ్మ',
        'reading': 'amma',
        'meaning': 'mum',
      },
      'base': <String, Object?>{
        'base': 'అమ్మ',
        'reading': 'amma',
        'meaning': 'mother',
      },
      'now': l10n.cardBaseReadingMeaning('అమ్మ', 'amma', 'mum'),
      'text': l10n.cardBaseReadingMeaning('అమ్మ', 'amma', 'mother'),
      'why': 'Mum is informal',
    });
  });

  testWidgets('opened again, the base shows the suggestion on it, one kept '
      'before #476 read as a change to the base, and a change to another '
      'part keeps it', (tester) async {
    useTallPhone(tester);
    final state = await reviewState(reviewing: true, bases: bases);
    final words = state.deckById(wordsDeck)!;
    final mother = words.cards.firstWhere((c) => c.id == plainCard);
    state.reviewing.suggest(words, mother, const <Suggestion>[
      Suggestion(part: CardPart.base, word: 'అమ్మ', now: 'mum', text: 'mother'),
    ]);
    await pumpScreen(
      tester,
      Scaffold(
        body: SuggestSheet(deck: words, card: mother),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    final name = l10n.reviewPartBaseOf('అమ్మ');
    // Marked as the reviewer's, with a way to remove it.
    expect(find.text(l10n.reviewSuggestYours), findsOneWidget);
    expect(find.byTooltip(l10n.reviewSuggestRemove(name)), findsOneWidget);

    await tester.tap(
      find.byTooltip(l10n.reviewSuggestEditPart(l10n.reviewPartMeaning)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SuggestSheet.textKey(CardPart.meaning)),
      'mother dear',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.reviewSuggestSaveAll));
    await tester.pumpAndSettle();
    final saved = state.reviewing.reviewOf(words, mother)!.suggestions;
    expect(saved.first.text, 'mother dear');
    expect(saved.last.action, BaseAction.edit);
    expect(saved.last.base!.meaning, 'mother');
    expect(saved.last.was!.meaning, 'mum');
  });

  testWidgets('two words with the same base and meaning show one base, '
      'and each still has its own card, named by its word', (tester) async {
    useTallPhone(tester);
    final handle = tester.ensureSemantics();
    const twice =
        '[{ word: "అమ్మ", base: "అమ్మ", reading: "amma", meaning: "mum" }, '
        '{ word: "అమ్మా", base: "అమ్మ", reading: "amma", meaning: "mum" }]';
    final state = await pumpScreen(
      tester,
      const ReviewPage(deckId: wordsDeck),
      state: await reviewState(reviewing: true, bases: twice),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text('mother'));
    await tester.pumpAndSettle();
    // The line names the base once.
    expect(
      find.descendant(
        of: find.byType(CardFace),
        matching: find.text(
          l10n.cardBases(1, l10n.cardBaseReadingMeaning('అమ్మ', 'amma', 'mum')),
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, l10n.reviewSuggest));
    await tester.pumpAndSettle();
    // Two cards, which the base alone would not tell apart.
    expect(
      find.text(l10n.reviewPartBaseOf('అమ్మ').toUpperCase()),
      findsNothing,
    );
    final first = l10n.reviewPartBaseOfWord('అమ్మ', 'అమ్మ');
    final second = l10n.reviewPartBaseOfWord('అమ్మా', 'అమ్మ');
    expect(find.text(first.toUpperCase()), findsOneWidget);
    expect(find.text(second.toUpperCase()), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

    await tester.tap(find.byTooltip(l10n.reviewSuggestEditPart(second)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(SuggestSheet.baseKey('అమ్మా', 'meaning')),
      'mother',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.reviewSuggestSaveAll));
    await tester.pumpAndSettle();

    final words = state.deckById(wordsDeck)!;
    final mother = words.cards.firstWhere((c) => c.id == plainCard);
    final suggestion = state.reviewing
        .reviewOf(words, mother)!
        .suggestions
        .single;
    expect(suggestion.part, CardPart.base);
    expect(suggestion.word, 'అమ్మా');
    expect(suggestion.was!.meaning, 'mum');
    expect(suggestion.base!.meaning, 'mother');
    handle.dispose();
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
