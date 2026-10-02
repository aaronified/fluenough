import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/settings_controls.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import '../../support/harness.dart';
import 'support.dart';

void main() {
  testWidgets('in this version every control is live but wallpaper colours', (
    tester,
  ) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    final state = await pumpScreen(tester, const AppearancePage());
    final l10n = l10nOf(tester);
    final settings = state.settings;

    final wallpaper = find.bySemanticsLabel(
      l10n.incomingSemanticsLabel(l10n.appearanceWallpaper),
    );
    expect(wallpaper, findsOneWidget);
    await tester.tap(wallpaper, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(l10n.incomingSnackBar), findsOneWidget);
    expect(settings.dynamicColour, isFalse);
    await clearSnackBars(tester);

    for (final label in <String>[
      l10n.appearanceColour,
      l10n.appearanceContrast,
      l10n.appearanceCardSize,
    ]) {
      expect(
        find.bySemanticsLabel(l10n.incomingSemanticsLabel(label)),
        findsNothing,
        reason: label,
      );
    }

    Future<void> tapText(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    await tapText(l10n.appearanceThemeDark);
    expect(settings.themeMode, ThemeMode.dark);
    await tapText(l10n.appearanceSeedIris);
    expect(settings.seed, ThemeSeed.iris);
    await tapText(l10n.appearanceContrastHigh);
    expect(settings.highContrast, isTrue);

    final slider = find.descendant(
      of: find.byType(SettingsSlider),
      matching: find.byType(Slider),
    );
    await scrollTo(tester, slider);
    await tapSlider(tester, slider, 0);
    await tester.pumpAndSettle();
    expect(settings.cardTextScale, SettingsNotifier.minCardTextScale);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('a colour and high contrast picked here theme the whole app', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpApp(
      tester,
      state: AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        ),
      ),
    );
    final l10n = l10nOf(tester);
    Future<void> tapText(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    await tapText(l10n.navSettings);
    await tapText(l10n.settingsAppearance);
    expect(find.byType(AppearancePage), findsOneWidget);

    await tapText(l10n.appearanceSeedClay);
    await tapText(l10n.appearanceContrastHigh);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SettingsPage));
    expect(
      Theme.of(context).colorScheme.primary,
      ColorScheme.fromSeed(
        seedColor: Color(ThemeSeed.clay.argb),
        contrastLevel: 1.0,
      ).primary,
    );
    expect(ModeColors.of(context).listening, ModeColors.lightHigh.listening);
    expect(
      find.text(
        l10n.settingsAppearanceSummaryHigh(
          l10n.appearanceThemeSystem,
          l10n.appearanceSeedClay,
        ),
      ),
      findsOneWidget,
    );

    state.settings.highContrast = false;
    await tester.pumpAndSettle();
    expect(
      ModeColors.of(tester.element(find.byType(SettingsPage))).listening,
      ModeColors.light.listening,
    );
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
    // The preview above grows with the scale, so the label may have moved.
    await scrollTo(tester, find.text(l10n.commonPercent(1.4)));
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
