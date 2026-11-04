// Split out of accessibility_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: First launch, Reviewing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/onboarding/onboarding_flow.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/script_test_page.dart';
import 'package:fluenough/features/review/offensive_review_page.dart';
import 'package:fluenough/features/review/review_page.dart';
import 'package:fluenough/features/review/waiting_page.dart';
import 'support/harness.dart';
import 'support/picker.dart';
import 'support/review_fixture.dart';
import 'support/accessibility_shared.dart';

/// [page] in reviewer mode, then [open] done on it.
DrawScreen review(
  Widget page, [
  Future<void> Function(WidgetTester tester, AppState state)? open,
]) => (tester, mode) async {
  final state = await pumpScreen(
    tester,
    page,
    state: await reviewState(reviewing: true),
    themeMode: mode,
  );
  if (open != null) {
    await open(tester, state);
    await tester.pumpAndSettle();
  }
};

/// A learner who speaks English and Bengali, reading both, learning
/// Assamese: the script test is offered (#554).
AppState bengaliReader() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en', 'bn'],
    learningLanguages: const <String>['as'],
    learningChosen: true,
  )..scriptsRead = <String, bool>{'en': true, 'bn': true},
);

void main() {
  group('First launch', () {
    screen('the tour', page(const OnboardingFlow(startAt: 'tour', page: 1)));
    screen('the sound check', gallery('onboarding-sound'));
    screen('what Know and Learn mean', gallery('onboarding-languages-intro'));
    // The gallery's entry reads the language list from the asset bundle, which
    // a widget test's clock never finishes (the step shows a spinner until it
    // does, so pumpAndSettle times out): the list is handed in instead.
    screen(
      'the languages question',
      page(OnboardingFlow(startAt: 'languages', choices: choices)),
    );
    screen('the languages question, a language\'s Know sheet open', (
      tester,
      mode,
    ) async {
      await pumpScreen(
        tester,
        OnboardingFlow(startAt: 'languages', choices: choices),
        themeMode: mode,
      );
      await tapShown(
        tester,
        find.byKey(const ValueKey<String>('onboarding-add-language')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('languages-add-search')),
        'Hindustani',
      );
      await tester.pumpAndSettle();
      await tapShown(tester, find.byKey(const ValueKey<String>('add-hi')));
      await tester.pumpAndSettle();
    });
    screen(
      'the language picker, a language\'s sheet open',
      gallery('picker-taught-from'),
    );
    screen('a placement question', gallery('placement-check'));
    screen('the script test', (tester, mode) async {
      await pumpScreen(
        tester,
        LanguagePickerPage(spokenList: choices),
        state: bengaliReader(),
        themeMode: mode,
      );
      await openSheet(tester, 'as');
      await tapShown(tester, find.text(l10nOf(tester).scriptTestTake));
      await tester.pumpAndSettle();
      expect(find.byType(ScriptTestPage), findsOneWidget);
    });
  });

  group('Reviewing', () {
    screen(
      'the review page, a card open',
      review(
        const ReviewPage(deckId: wordsDeck),
        (tester, state) async => tapShown(tester, find.text('mother')),
      ),
    );
    screen(
      'Suggest a change',
      review(const ReviewPage(deckId: wordsDeck), (tester, state) async {
        await tapShown(tester, find.text('mother'));
        await tester.pumpAndSettle();
        await tapShown(
          tester,
          find.widgetWithText(OutlinedButton, l10nOf(tester).reviewSuggest),
        );
      }),
    );
    screen(
      'Waiting for review, a language unfolded',
      review(const WaitingForReviewPage(), (tester, state) async {
        state.settings
          ..spokenLanguages = const <String>['en', 'te']
          ..scriptsRead = const <String, bool>{'en': true, 'te': true}
          ..reviewLanguages = const <String>{'te'};
        await tester.pumpAndSettle();
        await tapShown(tester, find.text('Telugu'));
      }),
    );
    screen(
      'the offensive-words gate',
      review(const OffensiveReviewPage(language: 'te')),
    );
  });
}
