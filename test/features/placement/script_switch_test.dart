import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';

import '../../support/harness.dart';
import '../../support/picker.dart';

/// The scripts of a language learned, in its sheet in Languages I'm learning
/// (#555, #626): named for the script, the one learned with its progress,
/// the others with "Add this script".

AppState learning({Set<String> noAlphabet = const <String>{}}) => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['hi', 'bn', 'es'],
    learningChosen: true,
    noAlphabet: noAlphabet,
  ),
);

Finder learnedScript(String script) =>
    find.byKey(ValueKey<String>('sheet-learned-$script'));

void main() {
  for (final scale in <double>[1.0, 1.4]) {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('each learned language shows its scripts in its sheet, '
          'named for the script, and Spanish none (text $scale, $mode)', (
        tester,
      ) async {
        usePhone(tester, textScale: scale);
        tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
        await pumpScreen(
          tester,
          LanguagePickerPage(spokenList: pickerSpokenList),
          state: learning(),
          themeMode: mode,
        );
        final l10n = l10nOf(tester);

        // Hindustani writes two scripts: one learned, one to add.
        await openSheet(tester, 'hi');
        expect(
          find.descendant(
            of: learnedScript('devanagari'),
            matching: find.text(l10n.pickerScriptLearning('Devanagari')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: learnedScript('perso_arabic'),
            matching: find.text(l10n.pickerScriptNotLearning),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: learnedScript('perso_arabic'),
            matching: find.byKey(const ValueKey<String>('sheet-add-script')),
          ),
          findsOneWidget,
        );
        await closeSheet(tester);

        await openSheet(tester, 'bn');
        expect(
          find.descendant(
            of: learnedScript('bengali'),
            matching: find.text(l10n.pickerScriptLearning('Eastern Nagari')),
          ),
          findsOneWidget,
        );
        await closeSheet(tester);

        await openSheet(tester, 'es');
        expect(
          find.byWidgetPredicate(
            (w) => switch (w.key) {
              final ValueKey<String> key => key.value.startsWith(
                'sheet-learned-',
              ),
              _ => false,
            },
          ),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('sheet-add-script')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('adding a script goes through its two screens, Back returns, '
      'and Continue saves it', (tester) async {
    usePhone(tester);
    tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
    final state = await pumpScreen(
      tester,
      LanguagePickerPage(spokenList: pickerSpokenList),
      state: learning(noAlphabet: const <String>{'hi'}),
    );
    final l10n = l10nOf(tester);
    expect(state.settings.noAlphabet, <String>{'hi'});

    await openSheet(tester, 'hi');
    expect(
      find.descendant(
        of: learnedScript('devanagari'),
        matching: find.text(l10n.pickerScriptNotLearning),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('sheet-add-script')).first,
    );
    await tester.pumpAndSettle();
    // The scripts screen: Back to the course and in again.
    expect(
      find.byKey(const ValueKey<String>('sheet-script-devanagari')),
      findsOneWidget,
    );
    await tapSheet(tester, 'sheet-back');
    expect(find.byKey(const ValueKey<String>('sheet-scroll')), findsOneWidget);
    expect(learnedScript('devanagari'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('sheet-add-script')).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('sheet-script-devanagari')),
    );
    await tester.pumpAndSettle();
    await finishSheet(tester);
    // Nothing is saved until Continue.
    expect(state.settings.noAlphabet, <String>{'hi'});
    await tester.tap(find.text(l10n.commonContinue));
    await tester.pumpAndSettle();
    expect(state.settings.noAlphabet, isEmpty);
    expect(state.settings.learnsAlphabet('bn'), isTrue);
  });

  testWidgets('a language learned can stop its script: Change scripts opens '
      'the screen with it ticked, and Continue saves the change', (
    tester,
  ) async {
    usePhone(tester);
    tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
    final state = await pumpScreen(
      tester,
      LanguagePickerPage(spokenList: pickerSpokenList),
      state: learning(),
    );
    final l10n = l10nOf(tester);
    expect(state.settings.learnsAlphabet('bn'), isTrue);

    // Bengali has one script, learned: no "Add this script", but the way
    // in is there.
    await openSheet(tester, 'bn');
    expect(
      find.byKey(const ValueKey<String>('sheet-add-script')),
      findsNothing,
    );
    await tapSheet(tester, 'sheet-change-scripts');
    CheckboxListTile script() => tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey<String>('sheet-script-bengali')),
    );
    expect(script().value, isTrue);
    await tapSheet(tester, 'sheet-script-bengali');
    expect(script().value, isFalse);
    await finishSheet(tester);
    // Nothing is saved until Continue, and no confirmation was asked.
    expect(find.byType(AlertDialog), findsNothing);
    expect(state.settings.learnsAlphabet('bn'), isTrue);
    await tester.tap(find.text(l10n.commonContinue));
    await tester.pumpAndSettle();
    expect(state.settings.learnsAlphabet('bn'), isFalse);
    expect(state.settings.noAlphabet, <String>{'bn'});
  });

  testWidgets('adding Perso-Arabic and stopping Devanagari saves the '
      'Perso-Arabic choice, not a yes or no about Devanagari', (
    tester,
  ) async {
    usePhone(tester);
    tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
    final state = await pumpScreen(
      tester,
      LanguagePickerPage(spokenList: pickerSpokenList),
      state: learning(),
    );
    final l10n = l10nOf(tester);
    expect(state.settings.hasScriptsChosen('hi'), isFalse);

    await openSheet(tester, 'hi');
    await tester.tap(
      find.byKey(const ValueKey<String>('sheet-add-script')).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('sheet-script-perso_arabic')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('sheet-script-devanagari')),
    );
    await tester.pumpAndSettle();
    await finishSheet(tester);
    await tester.tap(find.text(l10n.commonContinue));
    await tester.pumpAndSettle();
    expect(state.settings.scriptsLearned('hi', primary: 'devanagari'), <String>{
      'perso_arabic',
    });
    expect(state.settings.learnsAlphabet('hi'), isTrue);
    expect(state.settings.learnsAlphabet('bn'), isTrue);
  });
}
