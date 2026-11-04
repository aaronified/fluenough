// Split out of accessibility_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: the first launch meets contrast in every colour, standard and high contrast, light and dark.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/onboarding/tour_step.dart';
import 'support/harness.dart';
import 'support/accessibility_shared.dart';

void main() {
  testWidgets('the first launch meets contrast in every colour, standard and '
      'high contrast, light and dark', (tester) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    for (final seed in ThemeSeed.values) {
      for (final high in <bool>[false, true]) {
        for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
          rootBundle.clear();
          final settings = SettingsNotifier(
            seed: seed,
            highContrast: high,
            themeMode: mode,
          );
          final state = AppState.test(settings: settings);
          addTearDown(state.dispose);
          addTearDown(settings.dispose);
          await tester.pumpWidget(FluenoughApp(key: UniqueKey(), state: state));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          for (var i = 0; i < tourSlides.length; i++) {
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await tester.tap(find.byType(FilledButton));
            await tester.pumpAndSettle();
          }
          // The microphone and sound check (#89), then on.
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          // What Know and Learn mean (owner, 2026-11-01), then the list, the
          // list of languages to add from, the Know sheet, the skills sheet.
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tapShown(
            tester,
            find.byKey(const ValueKey<String>('onboarding-add-language')),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey<String>('languages-add-search')),
            'Bengali',
          );
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byKey(const ValueKey<String>('add-bn')));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.byKey(const ValueKey<String>('know-read')));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
      }
    }
    semantics.dispose();
  });
}
