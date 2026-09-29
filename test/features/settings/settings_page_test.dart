import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/profiles/profiles_page.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/settings_controls.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/fluenough_mark.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';
import 'support.dart';

Finder _slider(String title) => find.descendant(
  of: find.ancestor(
    of: find.text(title),
    matching: find.byType(SettingsSlider),
  ),
  matching: find.byType(Slider),
);

Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(GroupedTile));

void main() {
  group('live settings change SettingsNotifier', () {
    testWidgets('new cards per day', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      expect(state.settings.newCardsPerDay, 20);

      await tapSlider(tester, _slider(l10n.settingsNewCardsPerDay), 1);
      await tester.pumpAndSettle();
      expect(state.settings.newCardsPerDay, SettingsNotifier.maxNewCardsPerDay);
      expect(find.text('${SettingsNotifier.maxNewCardsPerDay}'), findsOne);

      await tapSlider(tester, _slider(l10n.settingsNewCardsPerDay), 0.5);
      await tester.pumpAndSettle();
      expect(state.settings.newCardsPerDay, 25);
    });

    testWidgets('each live skill switch, and romanisation', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      final settings = state.settings;

      for (final skill in <Skill>[
        Skill.recognition,
        Skill.production,
        Skill.listening,
      ]) {
        final row = _row(skill.label(l10n));
        await scrollTo(tester, row);
        expect(settings.isEnabled(skill), isTrue);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(settings.isEnabled(skill), isFalse, reason: '$skill');
        expect(
          tester
              .widget<Switch>(
                find.descendant(of: row, matching: find.byType(Switch)),
              )
              .value,
          isFalse,
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(settings.isEnabled(skill), isTrue, reason: '$skill');
      }

      final romanisation = _row(l10n.settingsRomanisation);
      await scrollTo(tester, romanisation);
      await tester.tap(romanisation);
      await tester.pumpAndSettle();
      expect(settings.showRomanisation, isFalse);
    });

    testWidgets('speech rate, which sets the rate the voice is given', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      final slider = _slider(l10n.settingsSpeechRate);
      await scrollTo(tester, slider);

      await tapSlider(tester, slider, 1);
      await tester.pumpAndSettle();
      expect(state.settings.speechRate, SettingsNotifier.maxSpeechRate);
      expect(state.settings.ttsRate(), closeTo(0.75, 1e-9));
      expect(find.text(l10n.settingsSpeechRateValue(1.5)), findsOne);

      await tapSlider(tester, slider, 0);
      await tester.pumpAndSettle();
      expect(state.settings.speechRate, SettingsNotifier.minSpeechRate);
      expect(state.settings.ttsRate(), closeTo(0.25, 1e-9));
      expect(
        state.settings.ttsRate(slower: true),
        closeTo(0.25 * SettingsNotifier.slowerFactor, 1e-9),
      );
    });

    testWidgets('the Voices row counts voiced languages and opens Voices', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const SettingsPage(),
        state: AppState.test(tts: FixedTtsEngine(const <String>{'es'})),
      );
      final l10n = l10nOf(tester);
      final voiced = state.languages.where(state.hasVoice).length;
      expect(voiced, 1);
      final summary = find.text(
        l10n.settingsVoicesSummary(voiced, state.languages.length),
      );
      await scrollTo(tester, summary);
      await tester.tap(summary);
      await tester.pumpAndSettle();
      expect(find.byType(VoicesPage), findsOneWidget);
    });
  });

  testWidgets('every disabled row reads as incoming and says so when tapped', (
    tester,
  ) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    final state = await pumpScreen(tester, const SettingsPage());
    final l10n = l10nOf(tester);
    final settings = state.settings;

    final labels = <String>[
      l10n.settingsSwitchProfile,
      l10n.skillGrammar,
      l10n.skillPair,
      l10n.settingsAppearance,
      l10n.settingsAppLanguage,
      l10n.settingsReminder,
      l10n.settingsPinLock,
      l10n.settingsExport,
      l10n.settingsImport,
      l10n.settingsDeleteProfile,
    ];
    for (final label in labels) {
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

    // Nothing opened and nothing changed.
    expect(find.byType(ProfilesPage), findsNothing);
    expect(find.byType(AppearancePage), findsNothing);
    expect(settings.isEnabled(Skill.grammar), isTrue);
    expect(settings.reminder, isFalse);
    semantics.dispose();
  });

  testWidgets('the app language picker lists every translation by its own '
      'name and code', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    final l10n = l10nOf(tester);
    final picker = find.byType(DropdownButton<Locale>);
    await scrollTo(tester, picker);

    final items = tester.widget<DropdownButton<Locale>>(picker).items!;
    expect(
      items.map((i) => i.value),
      orderedEquals(AppLocalizations.supportedLocales),
    );
    for (final locale in AppLocalizations.supportedLocales) {
      final own = lookupAppLocalizations(locale);
      expect(
        find.text(
          l10n.settingsAppLanguageOption(
            own.localeOwnName,
            own.localeOwnIso639_3,
          ),
        ),
        findsWidgets,
      );
    }

    await tester.tap(picker);
    await tester.pumpAndSettle();
    final english = lookupAppLocalizations(const Locale('en'));
    await tester.tap(
      find
          .text(
            l10n.settingsAppLanguageOption(
              english.localeOwnName,
              english.localeOwnIso639_3,
            ),
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.settingsAppLanguageChanged(english.localeOwnName)),
      findsOneWidget,
    );
  });

  testWidgets('the picker cannot change while the feature is incoming', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final picker = find.byType(DropdownButton<Locale>);
    await scrollTo(tester, picker);
    expect(tester.widget<DropdownButton<Locale>>(picker).onChanged, isNull);
  });

  testWidgets('with every feature on, the rest of Settings works', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    final l10n = l10nOf(tester);

    // The reminder switch, and its time once it is on.
    final reminder = _row(l10n.settingsReminder);
    await scrollTo(tester, reminder);
    expect(find.text(l10n.settingsReminderTime), findsNothing);
    await tester.tap(reminder);
    await tester.pumpAndSettle();
    expect(state.settings.reminder, isTrue);
    expect(find.text(l10n.settingsReminderTime), findsOneWidget);

    // Grammar's switch is live too.
    final grammar = _row(l10n.skillGrammar);
    await scrollTo(tester, grammar);
    await tester.tap(grammar);
    await tester.pumpAndSettle();
    expect(state.settings.isEnabled(Skill.grammar), isFalse);

    final appearance = _row(l10n.settingsAppearance);
    await scrollTo(tester, appearance);
    await tester.tap(appearance);
    await tester.pumpAndSettle();
    expect(find.byType(AppearancePage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final switchProfile = find.text(l10n.settingsSwitchProfile);
    await tester.ensureVisible(switchProfile);
    await tester.pumpAndSettle();
    await tester.tap(switchProfile);
    await tester.pumpAndSettle();
    expect(find.byType(ProfilesPage), findsOneWidget);
  });

  testWidgets('the footer shows the version in pubspec.yaml', (tester) async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(AppInfo.version, version);

    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final footer = find.text(l10nOf(tester).settingsFooter(AppInfo.version));
    await scrollTo(tester, footer);
    expect(footer, findsOneWidget);
  });

  testWidgets('the footer carries the brand mark, beside the name', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final footer = find.text(l10nOf(tester).settingsFooter(AppInfo.version));
    await scrollTo(tester, footer);
    final mark = find.byType(FluenoughMark);
    expect(mark, findsOneWidget);
    expect(tester.getSize(mark), const Size.square(32));
    expect(tester.getCenter(mark).dy, closeTo(tester.getCenter(footer).dy, 12));
  });
}
