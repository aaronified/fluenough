import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/settings_controls.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import '../../support/harness.dart';
import 'support.dart';

void main() {
  testWidgets('in this version the theme is live and every other control is '
      'incoming', (tester) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    final state = await pumpScreen(tester, const AppearancePage());
    final l10n = l10nOf(tester);
    final settings = state.settings;

    for (final label in <String>[
      l10n.appearanceWallpaper,
      l10n.appearanceColour,
      l10n.appearanceContrast,
      l10n.appearanceCardSize,
    ]) {
      final node = find.bySemanticsLabel(l10n.incomingSemanticsLabel(label));
      await scrollTo(tester, node);
      expect(node, findsOneWidget, reason: label);
      expect(
        tester.getSemantics(node),
        matchesSemantics(
          label: l10n.incomingSemanticsLabel(label),
          hint: l10n.incomingSemanticsHint,
          isButton: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
        reason: label,
      );
      await tester.tap(node, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(l10n.incomingSnackBar), findsOneWidget, reason: label);
      await clearSnackBars(tester);
    }

    await tester.ensureVisible(find.text(l10n.appearanceThemeDark));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.appearanceThemeDark));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.seed, ThemeSeed.forest);
    semantics.dispose();
  });

  testWidgets('with every feature on, each control changes SettingsNotifier', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const AppearancePage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    final l10n = l10nOf(tester);
    final settings = state.settings;

    Future<void> tapText(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    await tapText(l10n.appearanceThemeDark);
    expect(settings.themeMode, ThemeMode.dark);
    await tapText(l10n.appearanceThemeLight);
    expect(settings.themeMode, ThemeMode.light);

    await tapText(l10n.appearanceSeedOcean);
    expect(settings.seed, ThemeSeed.ocean);

    await tapText(l10n.appearanceContrastHigh);
    expect(settings.highContrast, isTrue);

    final slider = find.descendant(
      of: find.byType(SettingsSlider),
      matching: find.byType(Slider),
    );
    await scrollTo(tester, slider);
    await tapSlider(tester, slider, 1);
    await tester.pumpAndSettle();
    expect(settings.cardTextScale, SettingsNotifier.maxCardTextScale);
    expect(find.text(l10n.commonPercent(1.4)), findsOneWidget);

    // Wallpaper colours on: the seeds no longer apply.
    await tapText(l10n.appearanceWallpaper);
    expect(settings.dynamicColour, isTrue);
    await tapText(l10n.appearanceSeedClay);
    expect(settings.seed, ThemeSeed.ocean);
  });

  testWidgets('the preview draws a real card at the chosen size', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const AppearancePage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    final sample = AppearancePage.previewCard(state)!;
    expect(
      state.decks.any((d) => d.cards.contains(sample.card)),
      isTrue,
      reason: 'the preview card comes from a loaded deck',
    );
    TargetText target() => tester.widget<TargetText>(
      find.widgetWithText(TargetText, sample.card.target),
    );
    expect(target().fontSize, 40);
    state.settings.cardTextScale = 1.2;
    await tester.pumpAndSettle();
    expect(target().fontSize, closeTo(48, 1e-9));
    if (sample.card.reading != null) {
      expect(find.text(sample.card.reading!), findsOneWidget);
    }
  });
}
