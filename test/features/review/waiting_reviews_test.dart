import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/proposal.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/sent_state.dart';
import 'package:fluenough/features/review/review_waiting.dart';
import 'package:fluenough/features/review/reviewed_not_sent_page.dart';
import 'package:fluenough/features/review/reviewed_sent_page.dart';
import 'package:fluenough/features/review/waiting_page.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

/// Waiting for review's three parts (#471, docs/mockups/reviewer-mode.html,
/// section 1): "Your reviews" with Reviewed, not sent and Reviewed and sent,
/// then the languages, folded.

/// The plain word's meaning, "mother", proposed as "mum" by this reviewer,
/// with no acceptance yet.
const String proposed =
    '[{ id: "aaaaaaaaaa", field: "native", now: "mother", text: "mum", '
    'by: "$reviewerCode", date: "2026-10-09" }]';

Future<AppState> reviewerState() => reviewState(
  proposed: proposed,
  reviewing: true,
  share: FixedMailShare(),
  settings:
      SettingsNotifier(
          spokenLanguages: const <String>['en', 'te'],
          learningLanguages: const <String>['te'],
          learningChosen: true,
        )
        ..raterCode = reviewerCode
        ..reviewLanguages = const <String>{'te'}
        ..scriptsRead = const <String, bool>{'en': true, 'te': true},
);

/// Suggestions on the plain word, one in each state, and a picture, and
/// "Looks right" on the word like a rude one.
Future<void> reviewAndSend(AppState state, {bool send = true}) async {
  final words = state.deckById(wordsDeck)!;
  final plain = words.cards.last;
  state.reviewing.suggest(words, plain, const <Suggestion>[
    // Still a proposal in the deck, with nothing accepted: waiting.
    Suggestion(
      part: CardPart.meaning,
      now: 'mother',
      text: 'mum',
      why: 'Less formal.',
    ),
    // The field says it now, and no proposal: accepted.
    Suggestion(part: CardPart.reading, now: 'ammaa', text: 'amma'),
    // The field says something else, and no proposal: rejected.
    Suggestion(part: CardPart.ipa, now: 'old', text: 'new'),
    // The field is as it was: the deck has not got it yet.
    Suggestion(
      part: CardPart.notes,
      now: 'Also అమ్మా (ammā) when calling her.',
      text: 'Said to elders.',
    ),
    // A part the bot does not turn into proposals.
    Suggestion(part: CardPart.picture, now: '', text: 'A mother.'),
  ]);
  state.reviewing.markRight(words, words.cards.first);
  if (send) {
    await state.reviewing.send(state.reviewing.unsent, body: '');
  }
}

void main() {
  group('what became of a sent suggestion, from the deck files', () {
    const own = Proposal(
      id: 'aaaaaaaaaa',
      card: plainCard,
      field: ProposalField.native,
      now: 'mother',
      text: 'mum',
      by: reviewerCode,
      date: '2026-10-09',
    );
    const mum = Suggestion(part: CardPart.meaning, now: 'mother', text: 'mum');
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

    test('waiting while the proposal is in the deck, with the acceptances '
        'still needed; only this reviewer\'s own proposal counts', () {
      expect(
        of(mum, 'mother', <Proposal>[own]),
        const SentState(SentOutcome.waiting, moreNeeded: 2),
      );
      final once = Proposal(
        id: own.id,
        card: own.card,
        field: own.field,
        now: own.now,
        text: own.text,
        by: own.by,
        date: own.date,
        accepted: const <String>[otherCode],
      );
      expect(
        of(mum, 'mother', <Proposal>[once]),
        const SentState(SentOutcome.waiting, moreNeeded: 1),
      );
      final other = Proposal(
        id: 'bbbbbbbbbb',
        card: own.card,
        field: own.field,
        now: own.now,
        text: own.text,
        by: otherCode,
        date: own.date,
      );
      expect(of(mum, 'mother', <Proposal>[other]).outcome, SentOutcome.unknown);
    });

    test('accepted when the field says it, rejected when it says something '
        'else, not known while it is as it was', () {
      expect(of(mum, 'mum').outcome, SentOutcome.accepted);
      expect(of(mum, 'mom').outcome, SentOutcome.rejected);
      expect(
        of(mum, 'mother'),
        const SentState(SentOutcome.unknown, unknown: SentUnknown.notInDeckYet),
      );
      expect(of(mum, null).unknown, SentUnknown.notInDeckYet);
    });

    test('a picture or an example is for the owner: not known', () {
      const picture = Suggestion(part: CardPart.picture, now: '', text: 'x');
      expect(
        of(picture, ''),
        const SentState(SentOutcome.unknown, unknown: SentUnknown.notTracked),
      );
    });
  });

  group('the Waiting for review page', () {
    for (final scale in <double>[1.0, 1.4]) {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        final at = '${scale}x, ${mode.name}';

        testWidgets('your reviews first with their counts, then the '
            'languages, folded; the header unfolds one ($at)', (tester) async {
          usePhone(tester, textScale: scale);
          tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
          final handle = tester.ensureSemantics();
          final state = await reviewerState();
          await reviewAndSend(state, send: false);
          await pumpScreen(
            tester,
            const WaitingForReviewPage(),
            state: state,
            themeMode: mode,
          );
          final l10n = l10nOf(tester);
          expect(find.text(l10n.reviewYoursHeading), findsOneWidget);
          expect(find.text(l10n.reviewUnsentTitle), findsOneWidget);
          expect(find.text(l10n.reviewUnsentCount(1, 2)), findsOneWidget);
          expect(find.text(l10n.reviewSentTitle), findsOneWidget);
          expect(find.text(l10n.reviewSentNone), findsOneWidget);
          // The reviewed rows sit above the languages' heading.
          expect(
            tester.getTopLeft(find.text(l10n.reviewSentTitle)).dy,
            lessThan(
              tester.getTopLeft(find.text(l10n.reviewLanguagesHeading)).dy,
            ),
          );
          expect(
            tester.getTopLeft(find.text(l10n.reviewLanguagesHeading)).dy,
            lessThan(tester.getTopLeft(find.text('Telugu')).dy),
          );
          // The per-language "not sent" row is gone.
          expect(find.textContaining('reviewed, not sent'), findsNothing);

          // Folded: the counts in the header, no unit, no offensive row.
          expect(find.text(l10n.reviewLanguageCounts(1, 0)), findsOneWidget);
          expect(
            find.text(l10n.reviewWaitingUnit(1, 'Family words')),
            findsNothing,
          );
          expect(find.text(l10n.reviewOffensiveTitle), findsNothing);
          expect(
            tester.getSemantics(find.text('Telugu')),
            matchesSemantics(
              label: 'Telugu\n${l10n.reviewLanguageCounts(1, 0)}',
              isButton: true,
              hasTapAction: true,
              hasEnabledState: false,
              hasExpandedState: true,
              isExpanded: false,
              hasFocusAction: true,
              isFocusable: true,
            ),
          );

          await tester.tap(find.text('Telugu'));
          await tester.pumpAndSettle();
          expect(
            find.text(l10n.reviewWaitingUnit(1, 'Family words')),
            findsOneWidget,
          );
          expect(find.text(l10n.reviewOffensiveTitle), findsOneWidget);
          expect(
            tester.getSemantics(find.text('Telugu')),
            matchesSemantics(
              label: 'Telugu\n${l10n.reviewLanguageCounts(1, 0)}',
              isButton: true,
              hasTapAction: true,
              hasEnabledState: false,
              hasExpandedState: true,
              isExpanded: true,
              hasFocusAction: true,
              isFocusable: true,
            ),
          );
          await tester.tap(find.text('Telugu'));
          await tester.pumpAndSettle();
          expect(find.text(l10n.reviewOffensiveTitle), findsNothing);
          expect(tester.takeException(), isNull);
          handle.dispose();
        });
      }
    }

    testWidgets('before any review, the header counts the decks and cards '
        'to check', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const WaitingForReviewPage(),
        state: await reviewerState(),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewLanguageCounts(1, 2)), findsOneWidget);
      expect(find.text(l10n.reviewUnsentNone), findsOneWidget);
    });

    testWidgets('Reviewed and sent counts the decks and those waiting for a '
        'second review, and opens its page', (tester) async {
      usePhone(tester);
      final state = await reviewerState();
      await reviewAndSend(state);
      await pumpScreen(tester, const WaitingForReviewPage(), state: state);
      final l10n = l10nOf(tester);
      expect(
        find.text(
          '${l10n.reviewSentCount(1)} · ${l10n.reviewSentWaitingCount(1)}',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.reviewUnsentNone), findsOneWidget);
      await tester.tap(find.text(l10n.reviewSentTitle));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewedSentPage), findsOneWidget);
    });
  });

  group('what is unfolded on Waiting for review is remembered', () {
    test('per language, across a restart', () {
      final settings = SettingsNotifier()
        ..setWaitingLanguageOpen('te', true)
        ..setWaitingLanguageOpen('hi', true)
        ..setWaitingLanguageOpen('hi', false);
      final again = SettingsNotifier()..restore(settings.toStored());
      expect(again.isWaitingLanguageOpen('te'), isTrue);
      expect(again.isWaitingLanguageOpen('hi'), isFalse);
      expect(again.isWaitingLanguageOpen('bn'), isFalse);
    });

    testWidgets('a language stays unfolded when the page is opened again', (
      tester,
    ) async {
      usePhone(tester);
      final state = await reviewerState();
      await pumpScreen(tester, const WaitingForReviewPage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewOffensiveTitle), findsNothing);
      await tester.tap(find.text('Telugu'));
      await tester.pumpAndSettle();
      expect(state.settings.isWaitingLanguageOpen('te'), isTrue);
      // Away and back: a new page on the same state.
      await pumpScreen(tester, const SizedBox(), state: state);
      await pumpScreen(tester, const WaitingForReviewPage(), state: state);
      expect(find.text(l10n.reviewOffensiveTitle), findsOneWidget);
    });
  });

  group('Reviewed, not sent', () {
    for (final scale in <double>[1.0, 1.4]) {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        testWidgets('by deck: a card with its suggestions as Now, Yours and '
            'Why, the cards that look right folded in one row, Send review '
            'in the bar (${scale}x, ${mode.name})', (tester) async {
          usePhone(tester, textScale: scale);
          tester.view.physicalSize = const Size(390 * 3, 2800 * 3);
          final state = await reviewerState();
          await reviewAndSend(state, send: false);
          await pumpScreen(
            tester,
            const ReviewedNotSentPage(),
            state: state,
            themeMode: mode,
          );
          final l10n = l10nOf(tester);
          expect(
            find.text(l10n.reviewDeckHeader('Telugu', 'Family words')),
            findsOneWidget,
          );
          // The card with suggestions, and each part under it.
          expect(find.text('అమ్మ'), findsOneWidget);
          expect(find.text(l10n.reviewPartMeaning), findsOneWidget);
          expect(find.textContaining('Less formal.'), findsOneWidget);
          expect(find.textContaining('mum'), findsOneWidget);
          expect(find.text(l10n.reviewPartPicture), findsOneWidget);
          // The word that looks right is one folded row, not listed.
          expect(find.text(l10n.reviewUnsentLooksRight(1)), findsOneWidget);
          expect(find.text('విధవ'), findsNothing);
          await tester.tap(find.text(l10n.reviewUnsentLooksRight(1)));
          await tester.pumpAndSettle();
          expect(find.text('విధవ'), findsOneWidget);
          await tester.tap(find.text(l10n.reviewUnsentLooksRight(1)));
          await tester.pumpAndSettle();
          expect(find.text('విధవ'), findsNothing);
          expect(find.text(l10n.reviewSend), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('once sent, nothing is left here', (tester) async {
      usePhone(tester);
      final state = await reviewerState();
      await reviewAndSend(state);
      await pumpScreen(tester, const ReviewedNotSentPage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.reviewUnsentNone), findsOneWidget);
      expect(find.text(l10n.reviewSend), findsNothing);
    });
  });

  group('Reviewed and sent', () {
    for (final scale in <double>[1.0, 1.4]) {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        testWidgets('each suggestion in its state, a tally on top, and no '
            'rater code anywhere (${scale}x, ${mode.name})', (tester) async {
          usePhone(tester, textScale: scale);
          tester.view.physicalSize = const Size(390 * 3, 3200 * 3);
          final handle = tester.ensureSemantics();
          final state = await reviewerState();
          await reviewAndSend(state);
          await pumpScreen(
            tester,
            const ReviewedSentPage(),
            state: state,
            themeMode: mode,
          );
          final l10n = l10nOf(tester);
          expect(
            find.text(
              '${l10n.reviewSentTallyAccepted(1)} · '
              '${l10n.reviewSentTallyRejected(1)} · '
              '${l10n.reviewSentTallyWaiting(1)} · '
              '${l10n.reviewSentTallyUnknown(2)}',
            ),
            findsOneWidget,
          );
          expect(find.text(l10n.reviewSentAccepted), findsOneWidget);
          expect(find.text(l10n.reviewSentAcceptedLine), findsOneWidget);
          expect(find.text(l10n.reviewSentRejected), findsOneWidget);
          expect(find.text(l10n.reviewSentRejectedLine), findsOneWidget);
          expect(find.text(l10n.reviewSentWaiting), findsOneWidget);
          expect(find.text(l10n.reviewSentWaitingLine(1)), findsOneWidget);
          expect(find.text(l10n.reviewSentUnknown), findsNWidgets(2));
          expect(find.text(l10n.reviewSentUnknownOwner), findsOneWidget);
          expect(find.text(l10n.reviewSentUnknownDeck), findsOneWidget);
          // Rejected is not drawn in the error colour.
          final rejected = tester.widget<Text>(
            find.text(l10n.reviewSentRejected),
          );
          expect(
            rejected.style!.color,
            isNot(
              Theme.of(tester.element(find.byType(Scaffold).first))
                  .colorScheme
                  .error,
            ),
          );

          // No rater code, the reviewer's or another's, on the page or in
          // its semantics.
          for (final code in <String>[reviewerCode, otherCode, 'FL-']) {
            expect(find.textContaining(code), findsNothing);
            expect(find.bySemanticsLabel(RegExp(code)), findsNothing);
          }
          expect(tester.takeException(), isNull);
          handle.dispose();
        });
      }
    }

    testWidgets('nothing sent says so', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const ReviewedSentPage(),
        state: await reviewerState(),
      );
      expect(find.text(l10nOf(tester).reviewSentNone), findsOneWidget);
    });
  });

  test('sent suggestions read from the phone, deck by deck', () async {
    final state = await reviewerState();
    await reviewAndSend(state);
    final sent = sentSuggestionsOf(state);
    expect(sent.map((s) => s.state.outcome), <SentOutcome>[
      SentOutcome.waiting,
      SentOutcome.accepted,
      SentOutcome.rejected,
      SentOutcome.unknown,
      SentOutcome.unknown,
    ]);
    expect(sent.every((s) => s.review.deckId == wordsDeck), isTrue);
  });
}
