// The tags sheet, the flagged list and the facet answer a reviewer saves
// (ADR-0058, W4), at the app's 1.4x text on a narrow phone.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/review_receipt.dart';
import 'package:fluenough/features/review/facet_tags_sheet.dart';
import 'package:fluenough/features/review/flagged_page.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/review_fixture.dart';

const Card _hindi = Card(
  id: 'hi-0001',
  deckId: 'hi-core',
  target: 'ज़िंदगी',
  native: 'life',
  reading: 'zindagī',
  altTarget: <String>['ज़िन्दगी', 'जिंदगी'],
  altReading: <String>['zindagi'],
  examples: <CardExample>[
    CardExample(
      target: 'ज़िंदगी बहुत लंबी है और हर दिन कुछ नया सिखाती है',
      native: 'Life is long and teaches something new every day',
      reading:
          'zindagī bahut lambī hai aur har din kuchh nayā sikhātī hai aur '
          'hamesha naye raaste dikhātī hai',
    ),
  ],
  notes: <CardNote>[
    CardNote(id: '1', kind: NoteKind.note, text: 'A plain English note'),
  ],
);

/// A 360 dp phone, tall enough for the sheet, at the app's 1.4x text cap.
void _narrow(WidgetTester tester) {
  usePhone(tester, textScale: 1.4);
  tester.view.physicalSize = const Size(360 * 3, 900 * 3);
}

/// Opens the sheet for [facet] of [card]; the answer it resolves to is read
/// from [result] once the sheet is closed.
Future<void> _open(
  WidgetTester tester,
  Card card,
  Facet facet,
  List<FacetAnswer?> result,
) async {
  _narrow(tester);
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result.add(
            await showFacetTagsSheet(
              context,
              card: card,
              facet: facet,
              languageName: 'Hindustani',
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

List<Key?> _tagKeys(WidgetTester tester) => <Key?>[
  for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip)))
    chip.key,
];

String _fieldText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(FacetTagsSheet.fieldKey))
    .controller!
    .text;

void main() {
  group('the tags sheet', () {
    testWidgets('prefills the field, own tag first and chosen, chips shown', (
      tester,
    ) async {
      await _open(tester, _hindi, Facet.reading, <FacetAnswer?>[]);
      expect(_fieldText(tester), 'zindagī');
      expect(
        _tagKeys(tester).first,
        FacetTagsSheet.tagKey(PointerTag.readingWrong),
      );
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(FacetTagsSheet.tagKey(PointerTag.readingWrong)),
            )
            .selected,
        isTrue,
      );
      expect(
        find.byKey(FacetTagsSheet.candidateKey('zindagi')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tags combine, and an unchanged field sends no fix', (
      tester,
    ) async {
      final result = <FacetAnswer?>[];
      await _open(tester, _hindi, Facet.word, result);
      expect(
        _tagKeys(tester).first,
        FacetTagsSheet.tagKey(PointerTag.spellingWrong),
      );
      await tester.tap(
        find.byKey(FacetTagsSheet.tagKey(PointerTag.wrongRegister)),
      );
      await tester.pump();
      await tester.tap(find.byKey(FacetTagsSheet.saveKey));
      await tester.pumpAndSettle();
      final answer = result.single!;
      expect(answer.tags, <PointerTag>{
        PointerTag.spellingWrong,
        PointerTag.wrongRegister,
      });
      expect(answer.replacement, isNull);
    });

    testWidgets('a chip fills the field and the edit is the fix', (
      tester,
    ) async {
      final result = <FacetAnswer?>[];
      await _open(tester, _hindi, Facet.word, result);
      expect(find.byKey(FacetTagsSheet.hintKey), findsOneWidget);
      await tester.tap(find.byKey(FacetTagsSheet.candidateKey('जिंदगी')));
      await tester.pump();
      expect(_fieldText(tester), 'जिंदगी');
      await tester.tap(find.byKey(FacetTagsSheet.saveKey));
      await tester.pumpAndSettle();
      expect(result.single!.replacement, 'जिंदगी');
    });

    testWidgets('a tag alone flags, and no tag cannot be saved', (
      tester,
    ) async {
      await _open(tester, _hindi, Facet.audio, <FacetAnswer?>[]);
      expect(find.byKey(FacetTagsSheet.fieldKey), findsNothing);
      await tester.tap(
        find.byKey(FacetTagsSheet.tagKey(PointerTag.audioWrong)),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(FacetTagsSheet.saveKey))
            .onPressed,
        isNull,
      );
    });

    testWidgets('with no chips and no hint it is a plain field', (
      tester,
    ) async {
      await _open(tester, _hindi, Facet.note, <FacetAnswer?>[]);
      expect(_fieldText(tester), 'A plain English note');
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byKey(FacetTagsSheet.hintKey), findsNothing);
    });

    testWidgets('a sentence reading does not overflow at 360 dp and 1.4x', (
      tester,
    ) async {
      await _open(tester, _hindi, Facet.example, <FacetAnswer?>[]);
      expect(find.byKey(FacetTagsSheet.fieldKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      final field = tester.getSize(find.byKey(FacetTagsSheet.fieldKey));
      expect(field.width, greaterThan(200));
    });

    testWidgets('a word reading beside the field is bounded', (tester) async {
      await _open(tester, _hindi, Facet.word, <FacetAnswer?>[]);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(FacetTagsSheet.fieldKey)).width,
        greaterThan(150),
      );
    });
  });

  group('the flagged list and the facet answer', () {
    Future<AppState> reviewer() async {
      final state = await reviewState(
        reviewing: true,
        settings:
            SettingsNotifier(
                spokenLanguages: const <String>['en', 'te'],
                learningLanguages: const <String>['te'],
                learningChosen: true,
              )
              ..reviewLanguages = const <String>{'te'}
              ..scriptsRead = const <String, bool>{'en': true, 'te': true},
      );
      return state;
    }

    testWidgets('a row is the word, a pill and the reason; one button', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      final state = await reviewer();
      final words = state.deckById(wordsDeck)!;
      final plain = words.cards.firstWhere((c) => c.id == plainCard);
      state.reviewing.answerFacet(
        words,
        plain,
        Facet.reading,
        FacetAnswer.flagged(<PointerTag>{PointerTag.readingWrong}),
      );
      await pumpScreen(tester, const FlaggedPage(), state: state);
      final l10n = l10nOf(tester);
      expect(
        find.byKey(FlaggedPage.rowKey(wordsDeck, plainCard)),
        findsOneWidget,
      );
      expect(find.text(plain.target), findsOneWidget);
      expect(find.text(l10n.reviewFlaggedPillFlagged), findsOneWidget);
      expect(find.text('reading wrong'), findsOneWidget);
      expect(find.text(l10n.reviewFlaggedAll(1)), findsOneWidget);
    });

    testWidgets('nothing flagged shows no button', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await reviewer();
      await pumpScreen(tester, const FlaggedPage(), state: state);
      expect(find.byKey(FlaggedPage.reviewAllKey), findsNothing);
      expect(find.text(l10nOf(tester).reviewFlaggedEmpty), findsOneWidget);
    });

    test(
      'answerFacet replaces the facet, keeps the rest, hashes the text seen',
      () async {
        final state = await reviewer();
        final words = state.deckById(wordsDeck)!;
        final plain = words.cards.firstWhere((c) => c.id == plainCard);
        final reviewing = state.reviewing;
        reviewing.markRight(words, plain);
        reviewing.answerFacet(
          words,
          plain,
          Facet.word,
          const FacetAnswer.right(),
        );
        reviewing.answerFacet(
          words,
          plain,
          Facet.reading,
          FacetAnswer.flagged(<PointerTag>{PointerTag.readingWrong}),
        );
        reviewing.answerFacet(
          words,
          plain,
          Facet.reading,
          FacetAnswer.flagged(<PointerTag>{
            PointerTag.readingWrong,
          }, replacement: 'ammā'),
          decision: ReceiptDecision.offeredOther,
        );
        final review = reviewing.reviewOf(words, plain)!;
        expect(review.right, isTrue, reason: 'the card review is kept');
        expect(review.facets.keys.toSet(), <Facet>{Facet.word, Facet.reading});
        expect(review.facets[Facet.word]!.isRight, isTrue);
        expect(review.facets[Facet.reading]!.replacement, 'ammā');
        final reading = review.receipts
            .where((r) => r.facet == Facet.reading)
            .toList();
        expect(
          reading,
          hasLength(1),
          reason: 'the earlier receipt is replaced',
        );
        expect(reading.single.decision, ReceiptDecision.offeredOther);
        expect(reading.single.isCurrent(plain.reading), isTrue);
        expect(reading.single.isCurrent('other'), isFalse);
        expect(
          review.receipts.where((r) => r.facet == Facet.word),
          hasLength(1),
        );
        expect(
          review.receipts.firstWhere((r) => r.facet == Facet.word).seenHash,
          hashOfSeen(plain.target),
        );
      },
    );
  });
}
