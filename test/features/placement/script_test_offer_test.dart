import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/language_offer.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:fluenough/features/placement/script_test_page.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import '../../support/harness.dart';
import '../../support/picker.dart';

/// The script test's offer in a language's sheet (#554, #626): for a learner
/// who reads the language's script through another language they know.

final List<SpokenLanguage> spokenList = parseSpokenLanguages(
  File('assets/languages.yaml').readAsStringSync(),
);

/// A learner who speaks English and Bengali, reading both, learning
/// [learning] (none chosen yet when empty).
AppState bengaliReader({
  List<String> learning = const <String>[],
  bool reads = true,
}) => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en', 'bn'],
    learningLanguages: learning,
    learningChosen: learning.isNotEmpty,
  )..scriptsRead = <String, bool>{'en': true, 'bn': reads},
);

Finder offerOf(String code) =>
    find.byKey(ValueKey<String>('script-test-$code'));

/// Answers every question of the script test on screen: rightly, but for
/// [wrong], which are answered "I don't know".
Future<void> takeTest(
  WidgetTester tester,
  AppState state, {
  Set<String> wrong = const <String>{},
}) async {
  final l10n = l10nOf(tester);
  final meanings = <String, String>{
    for (final entry in state.scriptLessons('as'))
      for (final card in entry.cards) card.target: card.native,
  };
  while (find.text(l10n.scriptTestQuestion).evaluate().isNotEmpty) {
    final target = tester
        .widget<TargetText>(
          find.descendant(
            of: find.byType(ScriptTestPage),
            matching: find.byType(TargetText),
          ),
        )
        .text;
    final choice = wrong.contains(target)
        ? find.text(l10n.placementDontKnow)
        : find.widgetWithText(OutlinedButton, meanings[target]!);
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();
  }
}

/// Taps [finder] in the open sheet, scrolling it into view first.
Future<void> tapIn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Learns [code] in its sheet as far as its scripts screen, with its own
/// script ticked: where the offer of the test is.
Future<void> toScripts(WidgetTester tester, String code, String script) async {
  await openSheet(tester, code);
  await tapSheet(tester, 'sheet-learn');
  final box = find.byKey(ValueKey<String>('sheet-script-$script'));
  if (!tester.widget<CheckboxListTile>(box).value!) {
    await tapIn(tester, box);
  }
}

void main() {
  for (final scale in <double>[1.0, 1.4]) {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('a Bengali reader choosing Assamese is offered the script '
          'test, with ৰ and ৱ; Telugu is not (text $scale, $mode)', (
        tester,
      ) async {
        usePhone(tester, textScale: scale);
        await pumpScreen(
          tester,
          LanguagePickerPage(spokenList: spokenList),
          state: bengaliReader(),
          themeMode: mode,
        );
        final l10n = l10nOf(tester);
        await toScripts(tester, 'as', 'bengali');
        await tester.ensureVisible(offerOf('as'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: offerOf('as'),
            matching: find.text(
              l10n.scriptTestOffer('Eastern Nagari', 'Bengali', 'Assamese'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(l10n.scriptTestOwnLetters('Assamese', 'ৰ (rô), ৱ (wô)')),
          findsOneWidget,
        );
        await closeSheet(tester);
        await toScripts(tester, 'te', 'telugu');
        expect(offerOf('te'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the script test at text $scale, $mode', (tester) async {
        usePhone(tester, textScale: scale);
        final state = bengaliReader(learning: const <String>['as']);
        await pumpScreen(
          tester,
          LanguagePickerPage(spokenList: spokenList),
          state: state,
          themeMode: mode,
        );
        final l10n = l10nOf(tester);
        await openSheet(tester, 'as');
        await tapIn(tester, find.text(l10n.scriptTestTake));
        expect(find.byType(ScriptTestPage), findsOneWidget);
        expect(
          find.text(l10n.scriptTestTitle('Eastern Nagari')),
          findsOneWidget,
        );
        expect(find.text(l10n.scriptTestProgress(1, 8)), findsOneWidget);
        expect(tester.takeException(), isNull);
        await takeTest(tester, state, wrong: const <String>{'ৰ'});
        expect(
          find.text(l10n.scriptTestFailed(7, 8, 'Assamese')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('no offer to a learner who only speaks Bengali', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      LanguagePickerPage(spokenList: spokenList),
      state: bengaliReader(reads: false),
    );
    await toScripts(tester, 'as', 'bengali');
    expect(offerOf('as'), findsNothing);
  });

  testWidgets('learning Assamese: passed, its script lessons are skipped; '
      'retaken and failed, they stay', (tester) async {
    usePhone(tester);
    final state = bengaliReader(learning: const <String>['as']);
    await pumpScreen(
      tester,
      LanguagePickerPage(spokenList: spokenList),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(state.scriptLessonsSkipped('as'), isFalse);

    await openSheet(tester, 'as');
    await tapIn(tester, find.text(l10n.scriptTestTake));
    await takeTest(tester, state);
    expect(find.text(l10n.scriptTestPassed(8, 8, 'Assamese')), findsOneWidget);
    await tester.tap(find.text(l10n.scriptTestDone));
    await tester.pumpAndSettle();
    expect(state.scriptLessonsSkipped('as'), isTrue);
    expect(state.settings.learnsAlphabet('as'), isTrue);
    await tester.ensureVisible(
      find.text(l10n.scriptTestSkippedNote('Assamese')),
    );
    expect(find.text(l10n.scriptTestSkippedNote('Assamese')), findsOneWidget);

    await tapIn(tester, find.text(l10n.scriptTestRetake));
    await takeTest(tester, state, wrong: const <String>{'ৱ'});
    await tester.tap(find.text(l10n.scriptTestDone));
    await tester.pumpAndSettle();
    expect(state.scriptLessonsSkipped('as'), isFalse);
    expect(find.text(l10n.scriptTestTake), findsOneWidget);
  });

  testWidgets('choosing Assamese: a passed test is saved with the choice, '
      'past placement', (tester) async {
    usePhone(tester);
    final state = bengaliReader();
    await pumpScreen(
      tester,
      LanguagePickerPage(spokenList: spokenList),
      state: state,
    );
    final l10n = l10nOf(tester);
    await toScripts(tester, 'as', 'bengali');
    await tapIn(tester, find.text(l10n.scriptTestTake));
    await takeTest(tester, state);
    await tester.tap(find.text(l10n.scriptTestDone));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text(l10n.scriptTestSkippedNote('Assamese')),
    );
    expect(find.text(l10n.scriptTestSkippedNote('Assamese')), findsOneWidget);
    // Nothing is saved until the end.
    expect(state.settings.placedDecks, isEmpty);

    await finishSheet(tester, begin: true);
    await tester.tap(find.text(l10n.commonContinue));
    await tester.pumpAndSettle();
    expect(state.scriptLessonsSkipped('as'), isTrue);
    expect(state.settings.learnsAlphabet('as'), isTrue);
    expect(state.settings.placedDecks, <String>{
      for (final entry in state.scriptLessons('as')) entry.id,
    });
  });

  testWidgets('Find my level on a language learned keeps a passed script '
      'test: its lessons stay skipped', (tester) async {
    usePhone(tester);
    final state = bengaliReader(learning: const <String>['as']);
    await pumpScreen(
      tester,
      LanguagePickerPage(spokenList: spokenList),
      state: state,
    );
    final l10n = l10nOf(tester);
    state.skipScriptLessons('as', true);
    expect(state.scriptLessonsSkipped('as'), isTrue);

    await openSheet(tester, 'as');
    await tapSheet(tester, 'sheet-find');
    expect(find.byType(PlacementPage), findsOneWidget);
    while (find.text(l10n.placementDontKnow).evaluate().isNotEmpty) {
      await tapIn(tester, find.text(l10n.placementDontKnow));
    }
    await tapIn(tester, find.text(l10n.placementDone));
    expect(find.byType(PlacementPage), findsNothing);
    expect(state.scriptLessonsSkipped('as'), isTrue);
  });
}
