// Reviewers see and correct every card field (#508): Looks right on each
// item of a list, moved below the unchecked ones; an item changed or added;
// a missing field flagged; the teach-card warning picked from the card's own
// warnings alone; and what is kept reads back from the review file.

import 'dart:convert';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/review/card_fields.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/features/review/review_sheets.dart';
import 'package:fluenough/features/review/review_warning_sheet.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/labelled.dart';
import 'support/review_fixture.dart';

/// The plain word with two synonyms, one from Wiktionary, a pair note that
/// is a warning the teach card can show, and no other meanings.
const Card _mother = Card(
  id: plainCard,
  deckId: wordsDeck,
  target: 'అమ్మ',
  native: 'mother',
  reading: 'amma',
  pos: 'noun',
  synonyms: <CardItem>[
    CardItem(id: 'a', word: 'తల్లి', reading: 'talli', text: 'mother, formal'),
    CardItem(
      id: 'b',
      word: 'మాత',
      reading: 'māta',
      text: 'mother, in prayer',
      source: 'Wiktionary',
    ),
  ],
  notes: <CardNote>[
    CardNote(
      id: 'pair-1',
      kind: NoteKind.pair,
      text: 'Not అమ్మా (ammā).',
      ref: alikeCard,
    ),
  ],
);

/// Opens Suggest a change on [_mother], which is not in the deck's files:
/// the sheet needs only the card and the deck's course.
Future<AppState> _open(WidgetTester tester) async {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 4800 * 3);
  final state = await reviewState(reviewing: true);
  final words = state.deckById(wordsDeck)!;
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showSuggestSheet(context, deck: words, card: _mother),
          child: const Text('open'),
        ),
      ),
    ),
    state: state,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.enterText(find.byKey(key), text);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) =>
    _tap(tester, find.byTooltip(l10nOf(tester).reviewSuggestSaveAll));

CardReview? _kept(AppState state) {
  final words = state.deckById(wordsDeck)!;
  return state.reviewing.reviewOf(words, _mother);
}

void main() {
  group('the review data', () {
    test('an item, a flag and the checked items survive the review file', () {
      final review = CardReview(
        at: DateTime.utc(2026, 10, 30),
        suggestions: const <Suggestion>[
          Suggestion(
            part: CardPart.synonyms,
            word: 'a',
            action: BaseAction.edit,
            now: 'తల్లి (talli)',
            text: 'తల్లి (talli)\nmother',
            why: 'It says what it means',
          ),
          Suggestion(
            part: CardPart.antonyms,
            word: 'new-1',
            action: BaseAction.add,
            now: '',
            text: 'పిల్ల (pilla)',
          ),
          Suggestion(part: CardPart.gender, now: '', text: '', flag: true),
        ],
        itemsRight: <String>{CardReview.itemKey(CardPart.synonyms, 'b')},
      );
      final back = CardReview.fromJson(
        jsonDecode(jsonEncode(review.toJson())),
      )!;
      expect(back.itemsRight, <String>{'synonyms:b'});
      expect(
        back.suggestions.map((s) => (s.part, s.word, s.action, s.flag)),
        <Object>[
          (CardPart.synonyms, 'a', BaseAction.edit, false),
          (CardPart.antonyms, 'new-1', BaseAction.add, false),
          (CardPart.gender, null, null, true),
        ],
      );
      // Only items checked is something to send.
      expect(
        CardReview(
          at: DateTime.utc(2026, 10, 30),
          itemsRight: <String>{'synonyms:b'},
        ).isEmpty,
        isFalse,
      );
    });

    test(
      'a suggestion on an item that names none, or removes it, is dropped',
      () {
        Map<String, Object?> json(Map<String, Object?> more) =>
            <String, Object?>{
              'part': 'synonyms',
              'now': '',
              'text': 'x',
              ...more,
            };
        expect(Suggestion.fromJson(json(<String, Object?>{})), isNull);
        expect(
          Suggestion.fromJson(
            json(<String, Object?>{'word': 'a', 'action': 'remove'}),
          ),
          isNull,
        );
        expect(
          Suggestion.fromJson(json(<String, Object?>{'word': 'a'})),
          isNotNull,
        );
      },
    );

    test('items still to check come first, and Wiktionary\'s come last', () {
      final items = itemsOf(_mother, CardPart.synonyms, (_) => null);
      expect(items.map((i) => i.key), <String>['a', 'b']);
      expect(items.last.wiktionary, isTrue);
      expect(
        inReviewOrder(items, CardPart.synonyms, <String>{
          'synonyms:a',
        }).map((i) => i.key),
        <String>['b', 'a'],
      );
    });

    test('the warnings offered are the card\'s own, with no automatic one', () {
      final options = warningOptionsOf(_mother);
      expect(options.map((o) => o.id), <String>['pair-1', 'senses', 'none']);
      expect(options.firstWhere((o) => o.id == 'senses').enabled, isFalse);
    });
  });

  group('the Suggest a change sheet', () {
    testWidgets('Looks right counts an item off and moves it below the rest, '
        'and is kept', (tester) async {
      final state = await _open(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewItemsToCheck(2)), findsOneWidget);
      double top(String text) =>
          tester.getTopLeft(find.text(text, findRichText: true)).dy;
      expect(top('తల్లి (talli)'), lessThan(top('మాత (māta)')));
      expect(find.text(l10n.reviewWiktionary), findsOneWidget);

      await _tap(
        tester,
        find.byKey(SuggestSheet.itemRightKey(CardPart.synonyms, 'a')),
      );
      // Synonyms have one left, and so do the minimal pairs.
      expect(find.text(l10n.reviewItemsToCheck(1)), findsNWidgets(2));
      expect(find.text(l10n.reviewItemChecked), findsOneWidget);
      expect(top('మాత (māta)'), lessThan(top('తల్లి (talli)')));

      await _save(tester);
      expect(_kept(state)!.itemsRight, <String>{'synonyms:a'});
      expect(_kept(state)!.suggestions, isEmpty);
    });

    testWidgets('an item changed and an item added are kept with their why', (
      tester,
    ) async {
      final state = await _open(tester);
      final l10n = l10nOf(tester);
      await _tap(
        tester,
        byButtonLabel(l10n.reviewSuggestEditPart(l10n.reviewPartSynonyms))
            .first,
      );
      await _type(
        tester,
        SuggestSheet.textKey(CardPart.synonyms, word: 'a'),
        'తల్లి (talli)\nmother',
      );
      await _type(
        tester,
        SuggestSheet.whyKey(CardPart.synonyms, word: 'a'),
        'Say what it means',
      );
      await _tap(
        tester,
        find.byKey(SuggestSheet.addItemKey(CardPart.antonyms)),
      );
      await _type(
        tester,
        SuggestSheet.newItemKey(CardPart.antonyms, 0, 'text'),
        'పిల్ల (pilla)',
      );
      await _save(tester);

      final kept = _kept(state)!.suggestions;
      final changed = kept.singleWhere((s) => s.part == CardPart.synonyms);
      expect(changed.word, 'a');
      expect(changed.action, BaseAction.edit);
      expect(changed.now, 'తల్లి (talli)\nmother, formal');
      expect(changed.why, 'Say what it means');
      final added = kept.singleWhere((s) => s.part == CardPart.antonyms);
      expect(added.action, BaseAction.add);
      expect(added.now, isEmpty);
      expect(added.text, 'పిల్ల (pilla)');
    });

    testWidgets('a field with no data is flagged as missing, and taken back', (
      tester,
    ) async {
      final state = await _open(tester);
      final l10n = l10nOf(tester);
      final flag = find.byKey(SuggestSheet.flagKey(CardPart.antonyms));
      await _tap(tester, flag);
      expect(find.text(l10n.reviewFlagged), findsOneWidget);
      await _tap(tester, find.text(l10n.commonUndo));
      expect(find.text(l10n.reviewFlagged), findsNothing);
      await _tap(tester, flag);
      await _save(tester);
      final kept = _kept(state)!.suggestions.single;
      expect((kept.part, kept.flag, kept.text), (CardPart.antonyms, true, ''));
    });

    testWidgets('the warning picker offers only the card\'s warnings, and '
        'the pick is kept as a suggestion', (tester) async {
      final state = await _open(tester);
      final l10n = l10nOf(tester);
      await _tap(tester, find.byKey(SuggestSheet.warningKey));
      expect(find.byKey(WarningSheet.rowKey('pair-1')), findsOneWidget);
      expect(find.byKey(WarningSheet.rowKey('senses')), findsOneWidget);
      expect(find.byKey(WarningSheet.rowKey('none')), findsOneWidget);
      // Other meanings cannot be picked on a card that has none.
      expect(find.text(l10n.reviewWarningNoSenses), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      await _tap(tester, find.byKey(WarningSheet.rowKey('pair-1')));
      await _type(tester, WarningSheet.whyKey, 'Learners mix them up');
      await _tap(tester, find.byTooltip(l10n.reviewSuggestSaveAll).last);
      await _save(tester);

      final pick = _kept(state)!.suggestions.single;
      expect(pick.part, CardPart.warning);
      expect(pick.text, 'pair-1');
      expect(pick.now, isEmpty);
      expect(pick.why, 'Learners mix them up');
    });
  });
}
