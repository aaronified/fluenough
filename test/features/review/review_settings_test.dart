import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/review/how_reviewing_works.dart';
import 'package:fluenough/features/review/send_reviews_sheet.dart';
import 'package:fluenough/features/settings/settings_page.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

/// A phone tall enough for Settings' lazy list to build every group.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
}

void main() {
  testWidgets('Review decks asks once, saying several decks go in one mail, '
      'then shows the code and opens How reviewing works by itself, that '
      'one time', (tester) async {
    useTallPhone(tester);
    final state = await pumpScreen(
      tester,
      const SettingsPage(),
      state: await reviewState(),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewSettingsSection), findsOneWidget);
    expect(find.text(l10n.reviewSettingsHow), findsOneWidget);
    expect(find.text(l10n.reviewSettingsCode), findsNothing);

    await tester.tap(find.text(l10n.reviewSettingsSwitch));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewTurnOnTitle), findsOneWidget);
    expect(find.text(l10n.reviewTurnOnMany), findsOneWidget);
    expect(find.text(l10n.reviewTurnOnPublic), findsOneWidget);
    // Cancel leaves it off, with no code made.
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(state.reviewing.on, isFalse);
    expect(state.reviewing.code, isNull);

    await tester.tap(find.text(l10n.reviewSettingsSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reviewTurnOn));
    await tester.pumpAndSettle();
    final code = state.reviewing.code!;
    expect(find.byType(HowReviewingWorks), findsOneWidget);
    expect(find.text(l10n.reviewHowSendBody), findsOneWidget);
    await tester.tap(find.text(l10n.reviewHowGotIt));
    await tester.pumpAndSettle();
    expect(find.byType(HowReviewingWorks), findsNothing);
    expect(find.text(l10n.reviewSettingsCode), findsOneWidget);
    expect(find.text('$code'), findsOneWidget);

    // Off keeps the code; on again shows it, and no sheet.
    await tester.tap(find.text(l10n.reviewSettingsSwitch));
    await tester.pumpAndSettle();
    expect(find.text('$code'), findsNothing);
    await tester.tap(find.text(l10n.reviewSettingsSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reviewTurnOn));
    await tester.pumpAndSettle();
    expect(find.byType(HowReviewingWorks), findsNothing);
    expect(find.text('$code'), findsOneWidget);
  });

  testWidgets('Copy puts the code on the clipboard', (tester) async {
    useTallPhone(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final state = await pumpScreen(
      tester,
      const SettingsPage(),
      state: await reviewState(reviewing: true),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.byTooltip(l10n.reviewSettingsCopy));
    await tester.pump();
    expect(copied, '${state.reviewing.code}');
    expect(find.text(l10n.reviewSettingsCopied), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('How reviewing works opens from Settings with reviewing off', (
    tester,
  ) async {
    useTallPhone(tester);
    await pumpScreen(tester, const SettingsPage(), state: await reviewState());
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.reviewSettingsHow));
    await tester.pumpAndSettle();
    expect(find.byType(HowReviewingWorks), findsOneWidget);
    expect(find.text(l10n.reviewHowAdult), findsOneWidget);
  });

  testWidgets('Reviews to send says how many decks wait, and opens the send '
      'sheet', (tester) async {
    useTallPhone(tester);
    final state = await reviewState(reviewing: true);
    final words = state.deckById(wordsDeck)!;
    final rude = state.deckById(rudeDeck)!;
    state.reviewing.markRight(words, words.cards.first);
    state.reviewing.markRight(rude, rude.cards.first);
    await pumpScreen(tester, const SettingsPage(), state: state);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewSettingsToSend), findsOneWidget);
    expect(find.text(l10n.reviewDecksWaiting(2)), findsOneWidget);
    await tester.tap(find.text(l10n.reviewSettingsToSend));
    await tester.pumpAndSettle();
    expect(find.byType(SendReviewsSheet), findsOneWidget);
  });

  testWidgets('once a mail is sent, Send the last mail again puts its decks '
      'back and opens the send sheet', (tester) async {
    useTallPhone(tester);
    final state = await reviewState(share: FixedMailShare(), reviewing: true);
    final words = state.deckById(wordsDeck)!;
    state.reviewing.markRight(words, words.cards.first);
    await state.reviewing.send(state.reviewing.unsent, body: '');
    await pumpScreen(tester, const SettingsPage(), state: state);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewSettingsToSend), findsNothing);
    expect(find.text(l10n.reviewSettingsSendAgainDesc(1)), findsOneWidget);
    await tester.tap(find.text(l10n.reviewSettingsSendAgain));
    await tester.pumpAndSettle();
    expect(find.byType(SendReviewsSheet), findsOneWidget);
    expect(state.reviewing.unsent.map((d) => d.deckId), <String>[wordsDeck]);
    expect(find.text(l10n.reviewSendButton(1)), findsOneWidget);
  });

  testWidgets('Settings lists the decks the reviewer helped build', (
    tester,
  ) async {
    useTallPhone(tester);
    await pumpScreen(
      tester,
      const SettingsPage(),
      state: await reviewState(
        authors: const <String>[reviewerCode],
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        )..raterCode = reviewerCode,
      ),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewSettingsHelped), findsOneWidget);
    expect(
      find.text(l10n.reviewSettingsHelpedDeck('Family words', 'Telugu')),
      findsOneWidget,
    );
  });
}
