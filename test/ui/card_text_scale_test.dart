import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/settings_controls.dart';
import 'package:fluenough/ui/card_text_scale.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import '../features/settings/support.dart';
import '../support/harness.dart';

const LanguageInfo hindi = LanguageInfo(
  code: 'hi',
  iso639_3: 'hin',
  name: 'Hindi',
  script: 'devanagari',
);

const LanguageInfo bengali = LanguageInfo(
  code: 'bn',
  iso639_3: 'ben',
  name: 'Bengali',
  script: 'bengali',
);

/// The card scale's top with the phone at each scale the tests try (#505).
const List<(double, double)> expectedMax = <(double, double)>[
  (1.0, 1.4),
  (1.2, 1.4 / 1.2),
  (1.4, 1.0),
  (2.0, 1.0),
];

void main() {
  group('maxCardTextScaleFor', () {
    test('keeps a card within 1.4x in all', () {
      expect(maxCardTextScaleFor(1.0), 1.4);
      expect(maxCardTextScaleFor(1.2), closeTo(1.1667, 0.0001));
      expect(maxCardTextScaleFor(1.4), 1.0);
      expect(maxCardTextScaleFor(2.0), 1.0, reason: 'phone taken at the cap');
    });

    test('never goes below 1.0 or above the slider\'s own top', () {
      expect(maxCardTextScaleFor(0.85), SettingsNotifier.maxCardTextScale);
      expect(maxCardTextScaleFor(0), SettingsNotifier.maxCardTextScale);
      for (var phone = 0.5; phone <= 3; phone += 0.05) {
        final max = maxCardTextScaleFor(phone);
        expect(max, inInclusiveRange(1.0, SettingsNotifier.maxCardTextScale));
        expect(
          max * phone.clamp(0, AppSizes.maxTextScale),
          lessThanOrEqualTo(AppSizes.maxTextScale + 1e-9),
          reason: 'phone $phone',
        );
      }
    });
  });

  Finder slider() => find.descendant(
    of: find.byType(SettingsSlider),
    matching: find.byType(Slider),
  );

  for (final (phone, max) in expectedMax) {
    testWidgets('with the phone at ${phone}x the slider stops at '
        '${(max * 100).round()}%', (tester) async {
      usePhone(tester, textScale: phone);
      final state = await pumpScreen(tester, const AppearancePage());
      final l10n = l10nOf(tester);
      final settings = state.settings;
      await scrollTo(tester, slider());

      final widget = tester.widget<Slider>(slider());
      expect(widget.min, SettingsNotifier.minCardTextScale);
      expect(widget.max, SettingsNotifier.maxCardTextScale);
      if (max < SettingsNotifier.maxCardTextScale) {
        expect(widget.secondaryTrackValue, closeTo(max, 1e-9));
      } else {
        expect(widget.secondaryTrackValue, isNull);
      }
      final atLimit = find.text(l10n.appearanceCardSizeAtLimit);
      expect(atLimit, phone >= 1.4 ? findsOneWidget : findsNothing);

      await tapSlider(tester, slider(), 1);
      await tester.pumpAndSettle();
      expect(settings.cardTextScale, closeTo(max, 1e-9));
      expect(tester.widget<Slider>(slider()).value, closeTo(max, 1e-9));
      expect(find.text(l10n.commonPercent(max)), findsOneWidget);

      // The minimum is the same at every phone scale.
      await tapSlider(tester, slider(), 0);
      await tester.pumpAndSettle();
      expect(settings.cardTextScale, SettingsNotifier.minCardTextScale);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a size saved above the top is used at the top, and kept', (
    tester,
  ) async {
    usePhone(tester, textScale: 1.2);
    final settings = SettingsNotifier(cardTextScale: 1.4);
    addTearDown(settings.dispose);
    await pumpScreen(
      tester,
      const AppearancePage(),
      state: AppState.test(settings: settings),
    );
    final l10n = l10nOf(tester);
    await scrollTo(tester, slider());
    expect(tester.widget<Slider>(slider()).value, closeTo(1.4 / 1.2, 1e-9));
    expect(find.text(l10n.commonPercent(1.4 / 1.2)), findsOneWidget);
    expect(settings.cardTextScale, 1.4, reason: 'the saved value is kept');

    // The phone's text gets smaller again: the saved size comes back.
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    await tester.pumpAndSettle();
    await scrollTo(tester, slider());
    expect(tester.widget<Slider>(slider()).value, 1.4);
    expect(find.text(l10n.commonPercent(1.4)), findsOneWidget);
  });

  for (final phone in <double>[1.0, 1.2, 1.4, 2.0]) {
    testWidgets('with the phone at ${phone}x card text stays within 1.4x', (
      tester,
    ) async {
      usePhone(tester, textScale: phone);
      final settings = SettingsNotifier(cardTextScale: 1.4);
      addTearDown(settings.dispose);
      await pumpScreen(
        tester,
        const Scaffold(
          body: Column(
            children: <Widget>[
              TargetText.hero('घर', language: hindi),
              TargetText.card('বাড়ি', language: bengali, fontSize: 20),
            ],
          ),
        ),
        state: AppState.test(settings: settings),
      );
      for (final (text, base) in <(String, double)>[
        ('घर', 96),
        ('বাড়ি', 20),
      ]) {
        final element = tester.element(find.text(text));
        final size = tester.widget<Text>(find.text(text)).style!.fontSize!;
        final drawn = MediaQuery.textScalerOf(element).scale(size);
        expect(
          drawn / base,
          lessThanOrEqualTo(AppSizes.maxTextScale + 1e-9),
          reason: text,
        );
        expect(
          drawn / base,
          closeTo(AppSizes.maxTextScale, 1e-9),
          reason: '$text: card text at its top reaches 1.4x in all',
        );
      }
      expect(settings.cardTextScale, 1.4, reason: 'the saved value is kept');
    });
  }
}
