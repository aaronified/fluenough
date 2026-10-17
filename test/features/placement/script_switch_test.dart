import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/placement/language_card.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';

import '../../support/harness.dart';
import '../../support/picker.dart';

/// The switch for learning a language's script, in Languages I'm learning
/// (#555): named for the script, and the same setting as the card's choice
/// when the language was first chosen.

AppState learning() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['hi', 'bn', 'es'],
    learningChosen: true,
  ),
);

Finder switchOf(WidgetTester tester, String code) =>
    find.descendant(of: languageCard(code), matching: find.byType(Switch));

void main() {
  for (final scale in <double>[1.0, 1.4]) {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('each learned language shows its script switch, named '
          'for the script, and Spanish none (text $scale, $mode)', (
        tester,
      ) async {
        usePhone(tester, textScale: scale);
        tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
        await pumpScreen(
          tester,
          const LanguagePickerPage(),
          state: learning(),
          themeMode: mode,
        );
        final l10n = l10nOf(tester);
        expect(
          find.descendant(
            of: languageCard('hi'),
            matching: find.text(l10n.pickerLearnScript('Devanagari')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: languageCard('bn'),
            matching: find.text(l10n.pickerLearnScript('Eastern Nagari')),
          ),
          findsOneWidget,
        );
        expect(switchOf(tester, 'hi'), findsOneWidget);
        expect(switchOf(tester, 'bn'), findsOneWidget);
        expect(switchOf(tester, 'es'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('toggling the switch changes noAlphabet, and the card says '
      'so, both ways', (tester) async {
    usePhone(tester);
    tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
    final state = await pumpScreen(
      tester,
      const LanguagePickerPage(),
      state: learning(),
    );
    final l10n = l10nOf(tester);
    expect(state.settings.noAlphabet, isEmpty);
    expect(
      find.descendant(
        of: languageCard('hi'),
        matching: find.text(l10n.pickerScriptOff),
      ),
      findsNothing,
    );
    await tester.tap(switchOf(tester, 'hi'));
    await tester.pumpAndSettle();
    expect(state.settings.noAlphabet, <String>{'hi'});
    expect(state.settings.learnsAlphabet('bn'), isTrue);
    expect(tester.widget<Switch>(switchOf(tester, 'hi')).value, isFalse);
    expect(
      find.descendant(
        of: languageCard('hi'),
        matching: find.text(l10n.pickerScriptOff),
      ),
      findsOneWidget,
    );
    await tester.tap(switchOf(tester, 'hi'));
    await tester.pumpAndSettle();
    expect(state.settings.noAlphabet, isEmpty);
    expect(tester.widget<Switch>(switchOf(tester, 'hi')).value, isTrue);
  });

  testWidgets('a language chosen without its script shows the switch off', (
    tester,
  ) async {
    usePhone(tester);
    tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
    await pumpScreen(
      tester,
      const LanguagePickerPage(),
      state: AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi'],
          learningChosen: true,
          noAlphabet: const <String>{'hi'},
        ),
      ),
    );
    expect(tester.widget<Switch>(switchOf(tester, 'hi')).value, isFalse);
    expect(find.byType(ScriptChoice), findsOneWidget);
  });
}
