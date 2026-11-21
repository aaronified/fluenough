// The reviewer screens (ADR-0058, W3) at the app's 1.4x text on a 360 dp
// phone: the card screen and its one button, the queue and its resume, the
// Reviewing page, the flagged-only mode, the second-speaker views, and the
// deck-view entries.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/flagged_queue.dart';
import 'package:fluenough/core/review/review_pairs.dart';
import 'package:fluenough/core/review/review_quorum.dart';
import 'package:fluenough/core/review/review_receipt.dart';
import 'package:fluenough/core/review/review_session.dart';
import 'package:fluenough/core/review/second_speaker.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/review/facet_labels.dart';
import 'package:fluenough/features/review/facet_tags_sheet.dart';
import 'package:fluenough/features/review/flagged_page.dart';
import 'package:fluenough/features/review/review_card_view.dart';
import 'package:fluenough/features/review/review_flow_page.dart';
import 'package:fluenough/features/review/review_queue_page.dart';
import 'package:fluenough/features/review/second_speaker_views.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/review_fixture.dart';

const ReviewPair _te = ReviewPair('te', 'en');

/// A 360 dp phone, tall enough for a card, at the app's 1.4x text cap.
void _narrow(WidgetTester tester) {
  usePhone(tester, textScale: 1.4);
  tester.view.physicalSize = const Size(360 * 3, 900 * 3);
}

/// A reviewer of the Telugu course, whose words are two units when
/// [twoUnits] is set: the family words, then "More family words".
Future<AppState> _reviewer({
  bool twoUnits = false,
  bool reviewing = true,
  List<String> checkedBy = const <String>[],
}) async {
  final files = reviewCourse(more: twoUnits, checkedBy: checkedBy);
  if (twoUnits) {
    final path = files['decks/te/te-path.yaml']!;
    files['decks/te/te-path.yaml'] = path.replaceAll(
      '  - [te-review-words, te-review-more]\n  - [te-review-rude]',
      '  - [te-review-words]\n  - [te-review-more]\n  - [te-review-rude]',
    );
  }
  final state = AppState.test(
    decks: MemoryDeckSource(files),
    settings:
        SettingsNotifier(
            spokenLanguages: const <String>['en', 'te'],
            learningLanguages: const <String>['te'],
            learningChosen: true,
          )
          ..reviewLanguages = const <String>{'te'}
          ..scriptsRead = const <String, bool>{'en': true, 'te': true},
  );
  await state.load();
  state.settings.adultContent = true;
  if (reviewing) state.reviewing.turnOn();
  return state;
}

Card _word(AppState state, String id) =>
    state.deckById(wordsDeck)!.cards.firstWhere((c) => c.id == id);

CardReview _reviewOf(AppState state, Card card) =>
    state.reviewing.reviewOf(state.deckById(wordsDeck)!, card)!;

/// Taps [key] after bringing it into view.
Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
}

void main() {
  for (final (name, mode) in <(String, ThemeMode)>[
    ('light', ThemeMode.light),
    ('dark', ThemeMode.dark),
  ]) {
    group('the card screen, $name, 1.4x text on 360 dp', () {
      Future<(AppState, Widget, List<int>)> open(WidgetTester tester) async {
        _narrow(tester);
        final state = await _reviewer();
        final deck = state.deckById(wordsDeck)!;
        final done = <int>[];
        final view = Scaffold(
          body: ReviewCardView(
            deck: deck,
            card: _word(state, alikeCard),
            placeText: 'Unit 1 · card 1 of 2',
            onDone: () => done.add(1),
          ),
        );
        await pumpScreen(tester, view, state: state, themeMode: mode);
        return (state, view, done);
      }

      testWidgets('plain facets have a flag only; reading and IPA a tick '
          'too, outlined while unanswered', (tester) async {
        await open(tester);
        for (final facet in <Facet>[
          Facet.word,
          Facet.meaning,
          Facet.unitPlacement,
        ]) {
          expect(find.byKey(ReviewCardView.flagKey(facet)), findsOneWidget);
          expect(find.byKey(ReviewCardView.tickKey(facet)), findsNothing);
        }
        for (final facet in <Facet>[Facet.reading, Facet.ipa]) {
          expect(find.byKey(ReviewCardView.flagKey(facet)), findsOneWidget);
          expect(find.byKey(ReviewCardView.tickKey(facet)), findsOneWidget);
        }
        // The card has no note, example or audio.
        for (final facet in <Facet>[Facet.note, Facet.example, Facet.audio]) {
          expect(find.byKey(ReviewCardView.rowKey(facet)), findsNothing);
        }
        double outline(Facet facet) {
          final box = tester.widget<Container>(
            find
                .descendant(
                  of: find.byKey(ReviewCardView.rowKey(facet)),
                  matching: find.byType(Container),
                )
                .first,
          );
          return ((box.decoration! as BoxDecoration).border! as Border)
              .top
              .width;
        }

        expect(outline(Facet.reading), 2);
        expect(outline(Facet.meaning), 1);
        await _tap(tester, ReviewCardView.tickKey(Facet.reading));
        expect(outline(Facet.reading), 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the one button waits for reading and IPA, says All good, '
          'and says Done once a facet is flagged', (tester) async {
        final (state, _, done) = await open(tester);
        final l10n = l10nOf(tester);
        FilledButton button() =>
            tester.widget<FilledButton>(find.byKey(ReviewCardView.doneKey));
        expect(button().onPressed, isNull);
        expect(find.text(l10n.reviewAllGood), findsOneWidget);
        await _tap(tester, ReviewCardView.tickKey(Facet.reading));
        expect(button().onPressed, isNull, reason: 'the IPA is not answered');
        await _tap(tester, ReviewCardView.tickKey(Facet.ipa));
        expect(button().onPressed, isNotNull);
        expect(find.text(l10n.reviewAllGood), findsOneWidget);

        // The flag opens the tags sheet; saving flags the facet.
        await _tap(tester, ReviewCardView.flagKey(Facet.meaning));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(FacetTagsSheet.saveKey));
        await tester.pumpAndSettle();
        expect(find.text(l10n.commonDone), findsOneWidget);
        expect(find.text(l10n.reviewAllGood), findsNothing);
        expect(
          find.text(l10n.reviewTagMeaningWrong),
          findsOneWidget,
          reason: 'the flagged row names its tag',
        );

        await _tap(tester, ReviewCardView.doneKey);
        expect(done, hasLength(1));
        final facets = _reviewOf(state, _word(state, alikeCard)).facets;
        expect(facets[Facet.word]!.isRight, isTrue);
        expect(facets[Facet.unitPlacement]!.isRight, isTrue);
        expect(facets[Facet.reading]!.isRight, isTrue);
        expect(facets[Facet.meaning]!.tags, <PointerTag>{
          PointerTag.meaningWrong,
        });
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('the icon buttons are named for the screen reader without the '
      'card\'s text', (tester) async {
    _narrow(tester);
    final handle = tester.ensureSemantics();
    final state = await _reviewer();
    await pumpScreen(
      tester,
      Scaffold(
        body: ReviewCardView(
          deck: state.deckById(wordsDeck)!,
          card: _word(state, alikeCard),
          placeText: '',
          onDone: () {},
        ),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(
      find.bySemanticsLabel(l10n.reviewRightFacet(l10n.reviewFacetReading)),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(l10n.reviewFlagFacet(l10n.reviewFacetMeaning)),
      findsOneWidget,
    );
    await _tap(tester, ReviewCardView.tickKey(Facet.reading));
    expect(
      find.bySemanticsLabel(l10n.reviewRightFacetOn(l10n.reviewFacetReading)),
      findsOneWidget,
    );
    handle.dispose();
  });

  group('the queue', () {
    testWidgets('walks the unit, keeps the run as it goes, then offers the '
        'pool, and ends when nothing is left', (tester) async {
      _narrow(tester);
      final state = await _reviewer(twoUnits: true);
      await pumpScreen(
        tester,
        const ReviewFlowPage.queue(pair: _te),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text('Family words'), findsOneWidget);
      expect(find.text(l10n.reviewCardOf(1, 2)), findsOneWidget);
      expect(state.reviewing.run, isNotNull, reason: 'kept from the start');

      await _tap(tester, ReviewCardView.tickKey(Facet.reading));
      await _tap(tester, ReviewCardView.tickKey(Facet.ipa));
      await _tap(tester, ReviewCardView.doneKey);
      await tester.pumpAndSettle();
      expect(find.text(l10n.reviewCardOf(2, 2)), findsOneWidget);

      await _tap(tester, ReviewCardView.tickKey(Facet.reading));
      await _tap(tester, ReviewCardView.doneKey);
      await tester.pumpAndSettle();
      expect(find.byKey(ReviewFlowPage.endKey), findsOneWidget);
      expect(find.text(l10n.reviewEndContinue), findsOneWidget);
      expect(
        state.reviewing.run,
        isNull,
        reason: 'a finished session is not resumed',
      );

      await tester.tap(find.byKey(ReviewFlowPage.continueKey));
      await tester.pumpAndSettle();
      expect(find.text('More family words'), findsOneWidget);
      expect(find.text(l10n.reviewCardOf(1, 1)), findsOneWidget);
      expect(state.reviewing.run!.phase, ReviewPhase.pool);

      await _tap(tester, ReviewCardView.tickKey(Facet.reading));
      await _tap(tester, ReviewCardView.doneKey);
      await tester.pumpAndSettle();
      expect(find.byKey(ReviewFlowPage.endKey), findsOneWidget);
      expect(find.byKey(ReviewFlowPage.continueKey), findsNothing);
      expect(find.byKey(ReviewFlowPage.endCloseKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a closed review resumes at the card it stopped on', (
      tester,
    ) async {
      _narrow(tester);
      final state = await _reviewer(twoUnits: true);
      await pumpScreen(
        tester,
        const ReviewFlowPage.queue(pair: _te),
        state: state,
      );
      await _tap(tester, ReviewCardView.tickKey(Facet.reading));
      await _tap(tester, ReviewCardView.tickKey(Facet.ipa));
      await _tap(tester, ReviewCardView.doneKey);
      await tester.pumpAndSettle();
      // Close: a fresh screen on the same phone.
      await pumpScreen(
        tester,
        const ReviewFlowPage.queue(pair: _te),
        state: state,
      );
      expect(find.text(l10nOf(tester).reviewCardOf(2, 2)), findsOneWidget);
    });

    testWidgets('the Reviewing page: a unit line and one button, and the '
        'flagged tab with its Review all', (tester) async {
      _narrow(tester);
      final state = await _reviewer(twoUnits: true);
      await pumpScreen(tester, const ReviewQueuePage(), state: state);
      final l10n = l10nOf(tester);
      expect(
        find.descendant(
          of: find.byKey(ReviewQueuePage.unitKey),
          matching: find.text('Family words'),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.reviewCardOf(1, 2)), findsOneWidget);
      expect(find.text(l10n.reviewQueueStart), findsOneWidget);

      // A flag makes the second tab list the card and offer Review all 1.
      final deck = state.deckById(wordsDeck)!;
      state.reviewing.answerFacet(
        deck,
        _word(state, plainCard),
        Facet.reading,
        FacetAnswer.flagged(<PointerTag>{PointerTag.readingWrong}),
      );
      await tester.pump();
      await tester.tap(find.byKey(ReviewQueuePage.flaggedTabKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reviewFlaggedAll(1)), findsOneWidget);
      expect(
        find.byKey(FlaggedList.rowKey(wordsDeck, plainCard)),
        findsOneWidget,
      );

      // Review all opens the flagged-only mode: the card's flag, to call
      // right or to fix.
      await tester.tap(find.byKey(FlaggedList.reviewAllKey));
      await tester.pumpAndSettle();
      expect(find.byKey(SecondSpeakerStepView.rightKey), findsOneWidget);
      expect(find.text(l10n.reviewCardOf(1, 1)), findsOneWidget);
      await tester.tap(find.byKey(SecondSpeakerStepView.rightKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ReviewFlowPage.endKey), findsOneWidget);
      expect(
        _reviewOf(
          state,
          _word(state, plainCard),
        ).facets[Facet.reading]!.isRight,
        isTrue,
      );
    });
  });

  group('a second speaker', () {
    Future<(AppState, DeckEntry, Card)> words(WidgetTester tester) async {
      _narrow(tester);
      final state = await _reviewer();
      return (state, state.deckById(wordsDeck)!, _word(state, plainCard));
    }

    Widget view(
      DeckEntry deck,
      Card card,
      SecondSpeakerStep step,
      List<int> done,
    ) => Scaffold(
      body: SecondSpeakerStepView(
        step: step,
        deck: deck,
        card: card,
        onDone: () => done.add(1),
      ),
    );

    QueueCardRef ref() =>
        const QueueCardRef(deckId: wordsDeck, cardId: plainCard);

    ReceiptDecision decisionOf(AppState state, Card card, Facet facet) =>
        _reviewOf(
          state,
          card,
        ).receipts.firstWhere((r) => r.facet == facet).decision;

    testWidgets('checks a proposal with the original beside it: Accept', (
      tester,
    ) async {
      final (state, deck, card) = await words(tester);
      final done = <int>[];
      await pumpScreen(
        tester,
        view(
          deck,
          card,
          ProposalStep(
            ref: ref(),
            facet: Facet.meaning,
            original: card.native,
            tags: const <PointerTag>[PointerTag.meaningWrong],
            proposed: 'mum',
          ),
          done,
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(card.native), findsOneWidget);
      expect(find.text('mum'), findsOneWidget);
      expect(find.text(l10n.reviewSecondNow.toUpperCase()), findsOneWidget);
      expect(
        find.text(l10n.reviewSecondProposed.toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(find.byKey(SecondSpeakerStepView.acceptKey));
      await tester.pump();
      final answer = _reviewOf(state, card).facets[Facet.meaning]!;
      expect(answer.replacement, 'mum');
      expect(answer.tags, <PointerTag>{PointerTag.meaningWrong});
      expect(decisionOf(state, card, Facet.meaning), ReceiptDecision.accepted);
      expect(done, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reject says the card is right as it is', (tester) async {
      final (state, deck, card) = await words(tester);
      await pumpScreen(
        tester,
        view(
          deck,
          card,
          ProposalStep(
            ref: ref(),
            facet: Facet.meaning,
            original: card.native,
            tags: const <PointerTag>[PointerTag.meaningWrong],
            proposed: 'mum',
          ),
          <int>[],
        ),
        state: state,
      );
      await tester.tap(find.byKey(SecondSpeakerStepView.rejectKey));
      await tester.pump();
      expect(_reviewOf(state, card).facets[Facet.meaning]!.isRight, isTrue);
      expect(decisionOf(state, card, Facet.meaning), ReceiptDecision.rejected);
    });

    testWidgets('Offer another opens the tags sheet; the new fix is another '
        'fix', (tester) async {
      final (state, deck, card) = await words(tester);
      await pumpScreen(
        tester,
        view(
          deck,
          card,
          ProposalStep(
            ref: ref(),
            facet: Facet.meaning,
            original: card.native,
            tags: const <PointerTag>[PointerTag.meaningWrong],
            proposed: 'mum',
          ),
          <int>[],
        ),
        state: state,
      );
      await tester.tap(find.byKey(SecondSpeakerStepView.offerKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(FacetTagsSheet.fieldKey), 'mama');
      await tester.pump();
      await tester.tap(find.byKey(FacetTagsSheet.saveKey));
      await tester.pumpAndSettle();
      expect(_reviewOf(state, card).facets[Facet.meaning]!.replacement, 'mama');
      expect(
        decisionOf(state, card, Facet.meaning),
        ReceiptDecision.offeredOther,
      );
    });

    testWidgets('rival fixes are a pick-one: Choose waits for a pick', (
      tester,
    ) async {
      final (state, deck, card) = await words(tester);
      await pumpScreen(
        tester,
        view(
          deck,
          card,
          RivalStep(
            ref: ref(),
            facet: Facet.meaning,
            original: card.native,
            tags: const <PointerTag>[PointerTag.meaningWrong],
            fixes: const <String>['mum', 'mama'],
          ),
          <int>[],
        ),
        state: state,
      );
      FilledButton choose() => tester.widget<FilledButton>(
        find.byKey(SecondSpeakerStepView.chooseKey),
      );
      expect(choose().onPressed, isNull);
      await tester.tap(find.byKey(SecondSpeakerStepView.fixKey(1)));
      await tester.pump();
      expect(choose().onPressed, isNotNull);
      await tester.tap(find.byKey(SecondSpeakerStepView.chooseKey));
      await tester.pump();
      expect(_reviewOf(state, card).facets[Facet.meaning]!.replacement, 'mama');
      expect(decisionOf(state, card, Facet.meaning), ReceiptDecision.accepted);
    });

    testWidgets('"None of these" flags the facet with no fix', (tester) async {
      final (state, deck, card) = await words(tester);
      await pumpScreen(
        tester,
        view(
          deck,
          card,
          RivalStep(
            ref: ref(),
            facet: Facet.meaning,
            original: card.native,
            tags: const <PointerTag>[PointerTag.meaningWrong],
            fixes: const <String>['mum', 'mama'],
          ),
          <int>[],
        ),
        state: state,
      );
      await tester.tap(find.byKey(SecondSpeakerStepView.noneKey));
      await tester.pump();
      await tester.tap(find.byKey(SecondSpeakerStepView.chooseKey));
      await tester.pump();
      final answer = _reviewOf(state, card).facets[Facet.meaning]!;
      expect(answer.isFlagged, isTrue);
      expect(answer.hasReplacement, isFalse);
      expect(decisionOf(state, card, Facet.meaning), ReceiptDecision.rejected);
    });

    testWidgets('the digest shows the reason only after the verdict', (
      tester,
    ) async {
      final (state, deck, card) = await words(tester);
      final source = ReviewSource(
        pair: _te,
        units: <QueueUnit>[
          QueueUnit(
            number: 1,
            title: 'Family words',
            decks: <FlaggedSourceDeck>[
              FlaggedSourceDeck(
                deckId: wordsDeck,
                pair: _te,
                cards: deck.cards,
                others: <String, Map<Facet, List<ReviewCheck>>>{
                  card.id: <Facet, List<ReviewCheck>>{
                    Facet.reading: <ReviewCheck>[
                      ReviewCheck(
                        rater: otherCode,
                        answer: FacetAnswer.flagged(<PointerTag>{
                          PointerTag.readingWrong,
                        }, replacement: 'ammā'),
                      ),
                    ],
                    Facet.meaning: <ReviewCheck>[
                      const ReviewCheck(
                        rater: otherCode,
                        answer: FacetAnswer.right(),
                      ),
                      ReviewCheck(
                        rater: 'FL-1111-1111-1',
                        answer: FacetAnswer.flagged(<PointerTag>{
                          PointerTag.meaningWrong,
                        }),
                      ),
                    ],
                  },
                },
              ),
            ],
          ),
        ],
      );
      final items = digestOf(
        source,
        1,
        reasons: <String, Map<Facet, String>>{
          card.id: <Facet, String>{Facet.reading: 'It was too formal.'},
        },
      );
      await pumpScreen(
        tester,
        Scaffold(
          body: ReviewDigestView(items: items, source: source, onDone: () {}),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewDigestChanged), findsOneWidget);
      expect(find.text(l10n.reviewFlaggedPillContested), findsOneWidget);
      expect(
        find.text(l10n.reviewDigestChange('amma', 'ammā')),
        findsOneWidget,
      );
      expect(find.text('It was too formal.'), findsNothing);

      await tester.tap(find.byKey(ReviewDigestView.tickKey(items.first)));
      await tester.pump();
      expect(find.text('It was too formal.'), findsOneWidget);
      final answer = _reviewOf(state, card).facets[Facet.reading]!;
      expect(answer.replacement, 'ammā');
      expect(decisionOf(state, card, Facet.reading), ReceiptDecision.accepted);
      // The contested row still waits for its own verdict.
      expect(find.byKey(ReviewDigestView.tickKey(items.last)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the card screen says another speaker has to check it, and '
        'shows nothing another speaker said', (tester) async {
      _narrow(tester);
      final state = await _reviewer();
      await pumpScreen(
        tester,
        Scaffold(
          body: ReviewCardView(
            deck: state.deckById(wordsDeck)!,
            card: _word(state, plainCard),
            placeText: '',
            needsAnother: true,
            onDone: () {},
          ),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.byKey(ReviewCardView.needsKey), findsOneWidget);
      expect(find.text(l10n.reviewNeedsAnother), findsOneWidget);
      expect(
        RegExp(r'\d').hasMatch(l10n.reviewNeedsAnother),
        isFalse,
        reason: 'no number of checks',
      );
      // Every tag label is a word of the sheet, never of this screen.
      for (final tag in PointerTag.values) {
        expect(find.text(pointerTagLabel(l10n, tag)), findsNothing);
      }
    });
  });

  group('from the deck view', () {
    testWidgets('a reviewer is offered Review this unit and it opens the '
        'cards with every detail', (tester) async {
      _narrow(tester);
      final state = await _reviewer();
      await pumpScreen(tester, const UnitPage(deckId: wordsDeck), state: state);
      expect(find.byKey(UnitPage.reviewUnitKey), findsOneWidget);
      expect(find.text(l10nOf(tester).reviewThisUnit), findsOneWidget);
      await tester.tap(find.byKey(UnitPage.reviewUnitKey));
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      expect(find.text('Family words'), findsWidgets);
      expect(find.text(l10n.reviewCardNumber(1)), findsOneWidget);
      expect(find.byKey(ReviewCardView.rowKey(Facet.reading)), findsOneWidget);
    });

    testWidgets('someone who does not review is not offered it', (
      tester,
    ) async {
      _narrow(tester);
      final state = await _reviewer(reviewing: false);
      await pumpScreen(tester, const UnitPage(deckId: wordsDeck), state: state);
      expect(find.byKey(UnitPage.reviewUnitKey), findsNothing);
    });

    testWidgets('a card shows how many speakers checked it under its '
        'meaning, and a reviewer can review it', (tester) async {
      _narrow(tester);
      final state = await _reviewer(checkedBy: <String>[otherCode]);
      final deck = state.deckById(wordsDeck)!;
      final card = _word(state, plainCard);
      await pumpScreen(
        tester,
        Scaffold(
          body: WordSheet(card: card, language: deck.language),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      final line = find.text(l10n.cardCheckedBy(1));
      expect(line, findsOneWidget);
      expect(
        tester.getTopLeft(line).dy,
        greaterThan(tester.getTopLeft(find.text(card.native).first).dy),
      );
      expect(find.byKey(WordSheet.reviewCardKey), findsOneWidget);
      expect(find.text(l10n.reviewThisCard), findsOneWidget);
    });

    testWidgets('a learner sees no review entry on the card', (tester) async {
      _narrow(tester);
      final state = await _reviewer(reviewing: false);
      final deck = state.deckById(wordsDeck)!;
      await pumpScreen(
        tester,
        Scaffold(
          body: WordSheet(
            card: _word(state, plainCard),
            language: deck.language,
          ),
        ),
        state: state,
      );
      expect(find.byKey(WordSheet.reviewCardKey), findsNothing);
    });
  });
}
