// A reviewer's gender, register, hears and warning suggestions are proposals
// like a reading's (#508): other reviewers see them on the card, with Accept,
// Edit and Reject, the row counts them, and the reviewer's own go through
// "waiting, accepted or rejected" as the others do.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/proposal.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/sent_state.dart';
import 'package:fluenough/features/review/proposal_card.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/review_sheets.dart';
import 'package:flutter/painting.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/review_fixture.dart';

/// Proposals by another reviewer on the plain word, which has none of the
/// four fields: a gender, a register and no warning.
const String _proposed =
    '[{ id: "aaaaaaaaaa", field: "register", now: "", text: "informal", '
    'by: "$otherCode", date: "2026-10-30", why: "Said among friends." }, '
    '{ id: "bbbbbbbbbb", field: "gender", now: "", text: "f", '
    'by: "$otherCode", date: "2026-10-30" }, '
    '{ id: "cccccccccc", field: "warning", now: "", text: "none", '
    'by: "$otherCode", date: "2026-10-30" }, '
    '{ id: "dddddddddd", field: "hears", now: "form", text: "x", '
    'by: "$otherCode", date: "2026-10-30" }]';

Future<AppState> _open(WidgetTester tester) async {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
  final state = await pumpScreen(
    tester,
    const ReviewPage(deckId: wordsDeck),
    state: await reviewState(
      proposed: _proposed,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['te'],
        learningChosen: true,
      )..raterCode = reviewerCode,
      reviewing: true,
    ),
  );
  await tester.tap(find.text('mother'));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  group('scalar proposals', () {
    testWidgets('they show on the card, counted, with the warning as the '
        'warning it names, and one whose field changed is left out', (
      tester,
    ) async {
      await _open(tester);
      final l10n = l10nOf(tester);
      // The hears proposal was made against "form", which the card does not
      // say: outdated, so neither shown nor counted.
      expect(find.byType(ProposalCard), findsNWidgets(3));
      expect(
        find.text(l10n.reviewProposalTitle(l10n.reviewPartRegister)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.reviewProposalTitle(l10n.reviewPartGender)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.reviewProposalTitle(l10n.reviewPartWarning)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.reviewProposalTitle(l10n.reviewPartHears)),
        findsNothing,
      );
      expect(find.text('informal'), findsOneWidget);
      expect(find.text(l10n.reviewWarningNone), findsOneWidget);
      expect(find.text('none'), findsNothing);
      expect(
        find.text(l10n.reviewProposalWhy('Said among friends.')),
        findsOneWidget,
      );
    });

    testWidgets('Accept answers one, kept with the card\'s review', (
      tester,
    ) async {
      final state = await _open(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.reviewProposalAccept).first);
      await tester.pumpAndSettle();
      final words = state.deckById(wordsDeck)!;
      final answers = state.reviewing
          .reviewOf(words, words.cards.last)!
          .answers
          .values;
      expect(answers.single.id, 'aaaaaaaaaa');
      expect(answers.single.verdict, ProposalVerdict.accept);
      expect(answers.single.field, 'register');
      expect(answers.single.text, 'informal');
    });

    testWidgets('Edit on a warning opens it picked, and keeps the pick as a '
        'warning suggestion', (tester) async {
      final state = await _open(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.reviewProposalEdit).at(2));
      await tester.pumpAndSettle();
      expect(find.byType(SuggestSheet), findsOneWidget);
      await tester.tap(find.byTooltip(l10n.reviewSuggestSaveAll));
      await tester.pumpAndSettle();
      final words = state.deckById(wordsDeck)!;
      final review = state.reviewing.reviewOf(words, words.cards.last)!;
      final suggestion = review.suggestions.single;
      expect(suggestion.part, CardPart.warning);
      expect(suggestion.now, '');
      expect(suggestion.text, 'none');
      expect(review.answers['cccccccccc']!.verdict, ProposalVerdict.edit);
    });
  });

  group('what became of a sent scalar suggestion', () {
    SentState of(
      Suggestion s,
      String? current, [
      List<Proposal> proposals = const <Proposal>[],
    ]) => sentStateOf(
      suggestion: s,
      current: current,
      proposals: proposals,
      code: reviewerCode,
      agreementsNeeded: 2,
    );

    test('each of the four reads waiting, accepted or rejected as a reading '
        'does', () {
      const parts = <(CardPart, ProposalField, String, String)>[
        (CardPart.gender, ProposalField.gender, '', 'f'),
        (CardPart.register, ProposalField.register, 'neutral', 'slang'),
        (CardPart.hears, ProposalField.hears, '', 'form'),
        (CardPart.warning, ProposalField.warning, '', 'none'),
      ];
      for (final (part, field, now, text) in parts) {
        final s = Suggestion(part: part, now: now, text: text);
        final own = Proposal(
          id: 'aaaaaaaaaa',
          card: plainCard,
          field: field,
          now: now,
          text: text,
          by: reviewerCode,
          date: '2026-10-30',
        );
        expect(
          of(s, now, <Proposal>[own]),
          const SentState(SentOutcome.waiting, moreNeeded: 2),
          reason: '$part waiting',
        );
        expect(of(s, text).outcome, SentOutcome.accepted, reason: '$part');
        expect(of(s, 'other').outcome, SentOutcome.rejected, reason: '$part');
      }
    });

    test('a flag has nothing to propose, so it is not tracked', () {
      const flag = Suggestion(
        part: CardPart.gender,
        now: '',
        text: '',
        flag: true,
      );
      expect(
        of(flag, ''),
        const SentState(SentOutcome.unknown, unknown: SentUnknown.notTracked),
      );
    });
  });
}
