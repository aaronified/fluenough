import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';
import 'support.dart';

// Settings' "Adult content (18+)" (#96): off by default, asks the learner to
// confirm their age as it is switched on, and while on shows rude words
// where a warning would hide them, and offensive cards to rate.

Finder _adultRow(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(GroupedTile));

void main() {
  test('off by default, and kept as set', () {
    final settings = SettingsNotifier();
    expect(settings.adultContent, isFalse);
    expect(settings.toStored()['adult_content'], 'false');
    settings.adultContent = true;
    final restored = SettingsNotifier()..restore(settings.toStored());
    expect(restored.adultContent, isTrue);
    // A store from before the setting keeps it off.
    expect(
      (SettingsNotifier()..restore(const <String, String>{})).adultContent,
      isFalse,
    );
  });

  testWidgets('switching it on asks once for the learner\'s age; Cancel '
      'keeps it off; switching it off asks nothing', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(tester, const SettingsPage());
    final l10n = l10nOf(tester);
    final row = _adultRow(l10n.settingsAdult);
    await scrollTo(tester, row);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(state.settings.adultContent, isFalse);
    expect(adultContentOn(state), isFalse);
    expect(
      find.descendant(of: row, matching: find.text(l10n.settingsAdultOff)),
      findsOneWidget,
    );

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsAdultConfirmTitle), findsOneWidget);
    expect(find.text(l10n.settingsAdultConfirmBody), findsOneWidget);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(state.settings.adultContent, isFalse);
    expect(find.text(l10n.settingsAdultOff), findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsAdultConfirm));
    await tester.pumpAndSettle();
    expect(state.settings.adultContent, isTrue);
    expect(adultContentOn(state), isTrue);
    expect(find.text(l10n.settingsAdultConfirmTitle), findsNothing);
    expect(
      find.descendant(of: row, matching: find.text(l10n.settingsAdultOn)),
      findsOneWidget,
    );

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsAdultConfirmTitle), findsNothing);
    expect(state.settings.adultContent, isFalse);
    expect(find.text(l10n.settingsAdultOff), findsOneWidget);
  });

  testWidgets('on or off, a unit\'s review never shows a rude word: it is '
      'reviewed apart, on purpose', (tester) async {
    usePhone(tester);
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    final state = await pumpScreen(
      tester,
      const ReviewPage(deckId: rudeDeck),
      state: await reviewState(reviewing: true),
    );
    final l10n = l10nOf(tester);
    final rate = find.widgetWithText(FilledButton, l10n.reviewRateShort);
    for (final on in <bool>[false, true, false]) {
      state.settings.adultContent = on;
      await tester.pumpAndSettle();
      expect(find.text(l10n.reviewOffensiveApart(1)), findsOneWidget);
      expect(find.text('idiot, good-for-nothing'), findsNothing);
      expect(find.text('వెధవ'), findsNothing);
      expect(rate, findsNothing);
    }
  });

  testWidgets('with it on, the warning on a word like a rude one names it; '
      'off again hides it at once', (tester) async {
    usePhone(tester);
    final state = await reviewState(reviewing: true);
    final deck = state.deckById(wordsDeck)!;
    final word = deck.cards.firstWhere((c) => c.id == alikeCard);
    await pumpScreen(
      tester,
      Scaffold(
        body: WordSheet(card: word, language: deck.language),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.alikeCarefulSpeaking), findsOneWidget);
    expect(find.text(l10n.alikeHidden), findsOneWidget);
    expect(find.textContaining('వెధవ', findRichText: true), findsNothing);

    state.settings.adultContent = true;
    await tester.pumpAndSettle();
    expect(find.text(l10n.alikeHidden), findsNothing);
    expect(find.textContaining('వెధవ', findRichText: true), findsWidgets);

    state.settings.adultContent = false;
    await tester.pumpAndSettle();
    expect(find.text(l10n.alikeHidden), findsOneWidget);
    expect(find.textContaining('వెధవ', findRichText: true), findsNothing);
  });
}
