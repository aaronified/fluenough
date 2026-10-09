// Reviewer mode shows other reviewers' proposed changes on a card, with
// Accept, Edit and Reject, and keeps the answer with the card's review
// (ADR-0038). A learner never sees a proposal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/features/review/proposal_card.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/review_sheets.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

/// A phone tall enough for every card and sheet to be built.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
}

/// Two proposals on the plain word's meaning, "mother": one by another
/// reviewer, one by this one; and one whose field has changed since.
const proposed =
    '[{ id: "aaaaaaaaaa", field: "native", now: "mother", text: "mum", '
    'by: "$otherCode", date: "2026-10-09", why: "Less formal." }, '
    '{ id: "bbbbbbbbbb", field: "native", now: "mother", text: "mom", '
    'by: "$reviewerCode", date: "2026-10-09", accepted: ["$otherCode"] }, '
    '{ id: "cccccccccc", field: "native", now: "mum", text: "mama", '
    'by: "$otherCode", date: "2026-10-09" }]';

Future<dynamic> open(WidgetTester tester) async {
  useTallPhone(tester);
  final state = await pumpScreen(
    tester,
    const ReviewPage(deckId: wordsDeck),
    state: await reviewState(
      proposed: proposed,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['te'],
        learningChosen: true,
      )..raterCode = reviewerCode,
      reviewing: true,
    ),
  );
  return state;
}

void main() {
  testWidgets('a card shows the proposals waiting on it; Accept and Reject '
      'are kept with its review, and tapped again taken back', (tester) async {
    final state = await open(tester);
    final l10n = l10nOf(tester);
    // The row says how many wait: not the outdated one.
    expect(find.text(l10n.reviewProposalsWaiting(2)), findsOneWidget);

    await tester.tap(find.text('mother'));
    await tester.pumpAndSettle();
    expect(find.byType(ProposalCard), findsNWidgets(2));
    expect(
      find.text(l10n.reviewProposalTitle(l10n.reviewPartMeaning)),
      findsNWidgets(2),
    );
    expect(find.text('mum'), findsOneWidget);
    expect(find.text('mama'), findsNothing);
    expect(find.text(l10n.reviewProposalWhy('Less formal.')), findsOneWidget);
    expect(find.text(l10n.reviewProposalBy(otherCode, 0)), findsOneWidget);
    // This reviewer's own: no buttons, and who accepted it.
    expect(find.text(l10n.reviewProposalYours(1)), findsOneWidget);
    expect(find.text(l10n.reviewProposalAccept), findsOneWidget);

    await tester.tap(find.text(l10n.reviewProposalAccept));
    await tester.pumpAndSettle();
    final words = state.deckById(wordsDeck)!;
    final mother = words.cards.last;
    final answer = state.reviewing.reviewOf(words, mother)!.answers.values;
    expect(answer.single.id, 'aaaaaaaaaa');
    expect(answer.single.verdict, ProposalVerdict.accept);
    expect(answer.single.field, 'native');
    expect(answer.single.text, 'mum');
    expect(find.text(l10n.reviewProposalAccepted), findsOneWidget);
    expect(state.reviewing.unsent.single.deckId, wordsDeck);

    await tester.tap(find.text(l10n.reviewProposalReject));
    await tester.pumpAndSettle();
    expect(
      state.reviewing.reviewOf(words, mother)!.answers['aaaaaaaaaa']!.verdict,
      ProposalVerdict.reject,
    );
    expect(find.text(l10n.reviewProposalRejected), findsOneWidget);

    await tester.tap(find.text(l10n.reviewProposalReject));
    await tester.pumpAndSettle();
    expect(state.reviewing.reviewOf(words, mother), isNull);
  });

  testWidgets('Edit opens Suggest a change with the proposal, and saving it '
      'is the reviewer\'s own suggestion; the answer is "edit"', (
    tester,
  ) async {
    final state = await open(tester);
    final l10n = l10nOf(tester);
    await tester.tap(find.text('mother'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reviewProposalEdit));
    await tester.pumpAndSettle();
    expect(find.byType(SuggestSheet), findsOneWidget);
    final yours = find.widgetWithText(TextField, l10n.reviewSuggestYours);
    expect(tester.widget<TextField>(yours).controller!.text, 'mum');
    await tester.enterText(yours, 'mum, mother');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, l10n.reviewSave));
    await tester.pumpAndSettle();

    final words = state.deckById(wordsDeck)!;
    final review = state.reviewing.reviewOf(words, words.cards.last)!;
    expect(review.suggestion!.part, CardPart.meaning);
    expect(review.suggestion!.now, 'mother');
    expect(review.suggestion!.text, 'mum, mother');
    expect(review.answers['aaaaaaaaaa']!.verdict, ProposalVerdict.edit);
    expect(find.text(l10n.reviewProposalEdited), findsOneWidget);
  });

  testWidgets('without proposals a card shows none', (tester) async {
    useTallPhone(tester);
    await pumpScreen(
      tester,
      const ReviewPage(deckId: wordsDeck),
      state: await reviewState(reviewing: true),
    );
    await tester.tap(find.text('mother'));
    await tester.pumpAndSettle();
    expect(find.byType(ProposalCard), findsNothing);
  });
}
