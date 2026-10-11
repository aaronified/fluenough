import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/review_sheets.dart';
import 'package:fluenough/l10n/app_localizations.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

/// "Suggest a change" (#468): a card a part, each edited in its own field
/// with its own why; the tick saves every part edited, the cross none.

/// A phone tall enough for every part of the sheet to be built.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
}

/// Opens Suggest a change on the plain word, అమ్మ (amma), mother.
Future<AppState> openSheet(
  WidgetTester tester, {
  List<Suggestion> saved = const <Suggestion>[],
}) async {
  useTallPhone(tester);
  final state = await reviewState(reviewing: true);
  final words = state.deckById(wordsDeck)!;
  if (saved.isNotEmpty) {
    state.reviewing.suggest(words, words.cards.last, saved);
  }
  await pumpScreen(tester, const ReviewPage(deckId: wordsDeck), state: state);
  final l10n = l10nOf(tester);
  await tester.tap(find.text('mother'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, l10n.reviewSuggest));
  await tester.pumpAndSettle();
  expect(find.byType(SuggestSheet), findsOneWidget);
  return state;
}

Future<void> pencil(WidgetTester tester, String part) async {
  final l10n = l10nOf(tester);
  await tester.tap(find.byTooltip(l10n.reviewSuggestEditPart(part)));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

List<Suggestion> savedOn(AppState state) {
  final words = state.deckById(wordsDeck)!;
  return state.reviewing.reviewOf(words, words.cards.last)?.suggestions ??
      const <Suggestion>[];
}

void main() {
  testWidgets('every part has its card, in small capitals, with what it '
      'says now; an empty part is not set', (tester) async {
    await openSheet(tester);
    final AppLocalizations l10n = l10nOf(tester);
    for (final part in <String>[
      l10n.reviewPartWord,
      l10n.reviewPartReading,
      l10n.reviewPartIpa,
      l10n.reviewPartMeaning,
      l10n.reviewPartNotes,
      l10n.reviewPartExample,
      l10n.reviewPartPicture,
    ]) {
      expect(find.text(part.toUpperCase()), findsOneWidget);
      expect(find.byTooltip(l10n.reviewSuggestEditPart(part)), findsOneWidget);
    }
    // No IPA, example or picture on this card.
    expect(find.text(l10n.reviewSuggestNotSet), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(SuggestSheet),
        matching: find.text('amma'),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.reviewSuggestKept), findsOneWidget);
  });

  testWidgets('editing two parts saves both, each with its own why', (
    tester,
  ) async {
    final state = await openSheet(tester);
    final l10n = l10nOf(tester);
    await pencil(tester, l10n.reviewPartMeaning);
    await pencil(tester, l10n.reviewPartIpa);
    expect(find.byType(TextField), findsNWidgets(4));
    await tester.enterText(
      find.byKey(SuggestSheet.textKey(CardPart.meaning)),
      'mother, mum',
    );
    await tester.enterText(
      find.byKey(SuggestSheet.whyKey(CardPart.meaning)),
      'Mum is common',
    );
    await tester.enterText(
      find.byKey(SuggestSheet.textKey(CardPart.ipa)),
      'amma',
    );
    await tester.enterText(
      find.byKey(SuggestSheet.whyKey(CardPart.ipa)),
      'It had none',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.reviewSuggestSaveAll));
    await tester.pumpAndSettle();
    expect(find.byType(SuggestSheet), findsNothing);

    final saved = savedOn(state);
    expect(
      <(CardPart, String, String, String)>[
        for (final s in saved) (s.part, s.now, s.text, s.why),
      ],
      <(CardPart, String, String, String)>[
        (CardPart.ipa, '', 'amma', 'It had none'),
        (CardPart.meaning, 'mother', 'mother, mum', 'Mum is common'),
      ],
    );
  });

  testWidgets('editing one part never changes another\'s text, and a part '
      'opened later starts from its own value', (tester) async {
    await openSheet(tester);
    final l10n = l10nOf(tester);
    await pencil(tester, l10n.reviewPartWord);
    final word = SuggestSheet.textKey(CardPart.word);
    expect(textOf(tester, word), 'అమ్మ');
    await tester.enterText(find.byKey(word), 'అమ్మా');
    await tester.pumpAndSettle();

    // The bug in #468: IPA showed the word's suggestion.
    await pencil(tester, l10n.reviewPartIpa);
    final ipa = SuggestSheet.textKey(CardPart.ipa);
    expect(textOf(tester, ipa), '');
    await pencil(tester, l10n.reviewPartReading);
    final reading = SuggestSheet.textKey(CardPart.reading);
    expect(textOf(tester, reading), 'amma');

    await tester.enterText(find.byKey(reading), 'ammā');
    await tester.enterText(
      find.byKey(SuggestSheet.whyKey(CardPart.reading)),
      'Long a',
    );
    await tester.pumpAndSettle();
    expect(textOf(tester, word), 'అమ్మా');
    expect(textOf(tester, ipa), '');
    expect(textOf(tester, SuggestSheet.whyKey(CardPart.word)), '');
  });

  testWidgets('a saved suggestion shows marked as yours, starts the field '
      'when edited, and can be removed', (tester) async {
    const notes = Suggestion(
      part: CardPart.notes,
      now: 'Also అమ్మా (ammā) when calling her.',
      text: 'Said to elders too.',
      why: 'Common',
    );
    const meaning = Suggestion(
      part: CardPart.meaning,
      now: 'mother',
      text: 'mum',
    );
    final state = await openSheet(
      tester,
      saved: const <Suggestion>[meaning, notes],
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewSuggestYours), findsNWidgets(2));
    expect(find.text('Said to elders too.'), findsOneWidget);
    // What the part says now stays shown beside it.
    expect(find.text('Also అమ్మా (ammā) when calling her.'), findsOneWidget);

    await pencil(tester, l10n.reviewPartNotes);
    expect(
      textOf(tester, SuggestSheet.textKey(CardPart.notes)),
      'Said to elders too.',
    );
    expect(textOf(tester, SuggestSheet.whyKey(CardPart.notes)), 'Common');

    // Removing the meaning's waits for the tick, and can be undone.
    final remove = find.byTooltip(
      l10n.reviewSuggestRemove(l10n.reviewPartMeaning),
    );
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewSuggestRemoved), findsOneWidget);
    expect(savedOn(state), hasLength(2));
    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(find.text('mum'), findsOneWidget);
    await tester.tap(remove);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.reviewSuggestSaveAll));
    await tester.pumpAndSettle();
    final saved = savedOn(state);
    expect(saved.single.part, CardPart.notes);
    expect(saved.single.text, 'Said to elders too.');
  });

  testWidgets('the cross discards every edit and removal', (tester) async {
    const meaning = Suggestion(
      part: CardPart.meaning,
      now: 'mother',
      text: 'mum',
    );
    final state = await openSheet(tester, saved: const <Suggestion>[meaning]);
    final l10n = l10nOf(tester);
    await tester.tap(
      find.byTooltip(l10n.reviewSuggestRemove(l10n.reviewPartMeaning)),
    );
    await pencil(tester, l10n.reviewPartWord);
    await tester.enterText(
      find.byKey(SuggestSheet.textKey(CardPart.word)),
      'అమ్మా',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.reviewSuggestDiscard));
    await tester.pumpAndSettle();
    expect(find.byType(SuggestSheet), findsNothing);
    final saved = savedOn(state);
    expect(saved.single.part, CardPart.meaning);
    expect(saved.single.text, 'mum');
  });

  testWidgets('the tick waits for a change: a part edited back to what it '
      'says now saves nothing', (tester) async {
    await openSheet(tester);
    final l10n = l10nOf(tester);
    IconButton tick() => tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(l10n.reviewSuggestSaveAll),
        matching: find.byType(IconButton),
      ),
    );
    expect(tick().onPressed, isNull);
    await pencil(tester, l10n.reviewPartMeaning);
    expect(tick().onPressed, isNull);
    final meaning = find.byKey(SuggestSheet.textKey(CardPart.meaning));
    await tester.enterText(meaning, 'mum');
    await tester.pumpAndSettle();
    expect(tick().onPressed, isNotNull);
    await tester.enterText(meaning, 'mother');
    await tester.pumpAndSettle();
    expect(tick().onPressed, isNull);
  });
}
