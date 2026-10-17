import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/profiles/profiles_page.dart';
import 'package:fluenough/features/settings/activities_page.dart';
import 'package:fluenough/features/settings/app_log_page.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/languages_page.dart';
import 'package:fluenough/features/settings/profiles_privacy_page.dart';
import 'package:fluenough/features/settings/reminders_page.dart';
import 'package:fluenough/features/settings/reviewing_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/updates_page.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:fluenough/features/settings/your_decks_page.dart';
import 'package:fluenough/ui/widgets/fluenough_mark.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';
import 'support.dart';

Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(GroupedTile));

void main() {
  group('the Settings tab is the profile card and a list of pages', () {
    testWidgets('has one row per section, in the mockup\'s two groups and '
        'order, and no other control', (tester) async {
      usePhone(tester);
      // Tall enough to lay the whole list out at once, so that every
      // position below is measured in one frame.
      tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
      await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);

      final titles = <String>[
        l10n.settingsRowLanguages,
        l10n.settingsRowActivities,
        l10n.settingsRowLook,
        l10n.settingsRowReviewing,
        l10n.settingsRowDecks,
        l10n.settingsRowReminders,
        l10n.settingsRowData,
        l10n.settingsRowLog,
        l10n.settingsRowUpdates,
      ];
      final tops = <double>[];
      for (final title in titles) {
        expect(_row(title), findsOneWidget, reason: title);
        tops.add(tester.getTopLeft(_row(title)).dy);
      }
      expect(tops, orderedEquals(<double>[...tops]..sort()));
      // Nothing but those nine rows is a row of the tab.
      expect(find.byType(GroupedTile), findsNWidgets(titles.length));
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Slider), findsNothing);
      // Two groups: the second starts after a gap the first does not have.
      final gap =
          tester.getTopLeft(_row(l10n.settingsRowReminders)).dy -
          tester.getBottomLeft(_row(l10n.settingsRowDecks)).dy;
      final within =
          tester.getTopLeft(_row(l10n.settingsRowActivities)).dy -
          tester.getBottomLeft(_row(l10n.settingsRowLanguages)).dy;
      expect(gap, greaterThan(within));
    });

    testWidgets('each row says what is set', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
      final state = await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      String under(String title) =>
          tester.widget<GroupedTile>(_row(title)).subtitle!;

      // Spoken words starts off, so some activity shows off from the start.
      final off = _incomingSwitches(state, includeProduction: true);
      expect(
        under(l10n.settingsRowActivities),
        off == 0
            ? l10n.settingsSumActivitiesAllOn
            : l10n.settingsSumActivitiesSomeOff(off),
      );
      expect(under(l10n.settingsRowReviewing), l10n.settingsSumReviewingOff);
      expect(under(l10n.settingsRowDecks), l10n.settingsSumDecks(0));
      expect(under(l10n.settingsRowReminders), l10n.settingsReminderOff);
      expect(under(l10n.settingsRowData), l10n.settingsSumData(0));
      expect(
        under(l10n.settingsRowLog),
        l10n.settingsSumLog(state.log.entries.length),
      );
      expect(
        under(l10n.settingsRowUpdates),
        l10n.settingsUpdateCurrent(AppInfo.version),
      );
      expect(
        under(l10n.settingsRowLook),
        l10n.settingsSumLook(
          appearanceSummary(l10n, state.settings),
          'English',
        ),
      );

      // A switch turned off changes the line, and says what is always asked.
      state.settings.setSkillEnabled(Skill.production, false);
      await tester.pumpAndSettle();
      expect(
        under(l10n.settingsRowActivities),
        l10n.settingsSumActivitiesSomeOff(
          _incomingSwitches(state, includeProduction: true),
        ),
      );
    });

    testWidgets('every row opens its page', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      final pages = <String, Type>{
        l10n.settingsRowLanguages: LanguagesSettingsPage,
        l10n.settingsRowActivities: ActivitiesPage,
        l10n.settingsRowLook: AppearancePage,
        l10n.settingsRowReviewing: ReviewingPage,
        l10n.settingsRowDecks: YourDecksPage,
        l10n.settingsRowData: YourDataPage,
        l10n.settingsRowLog: AppLogPage,
        l10n.settingsRowUpdates: UpdatesPage,
      };
      for (final MapEntry(key: title, value: page) in pages.entries) {
        final row = find.text(title);
        await scrollTo(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget, reason: title);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(
          find.byType(SettingsPage),
          findsOneWidget,
          reason: 'back from $title',
        );
      }
    });

    testWidgets('Reminders is incoming, with its badge, and still opens its '
        'page, whose controls are incoming (mockup decision 1a); with the '
        'feature on it opens its page', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      final node = find.bySemanticsLabel(
        l10n.incomingSemanticsLabel(l10n.settingsRowReminders),
      );
      await scrollTo(tester, node);
      expect(node, findsOneWidget);
      expect(find.text(l10n.incomingBadge), findsWidgets);
      await tester.tap(node, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(l10n.incomingSnackBar), findsNothing);
      expect(find.byType(RemindersPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RemindersPage),
          matching: find.text(l10n.incomingBadge),
        ),
        findsWidgets,
      );
      semantics.dispose();

      await pumpScreen(
        tester,
        const SettingsPage(),
        state: AppState.test(features: FeatureRegistry.all()),
      );
      await scrollTo(tester, find.text(l10n.settingsRowReminders));
      await tester.tap(find.text(l10n.settingsRowReminders));
      await tester.pumpAndSettle();
      expect(find.byType(RemindersPage), findsOneWidget);
    });
  });

  group('the profile card', () {
    testWidgets('is one target with a chevron, named for screen readers, '
        'and opens Profiles and privacy', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final state = await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      final name = state.currentProfile.name ?? l10n.commonUnnamedProfile;
      final learning = l10n.settingsLearningLanguages(
        <String>[
          for (final language in state.languages)
            if (state.currentProfile.learns(language.code)) language.name,
        ].join(l10n.commonListSeparator),
      );
      final label = l10n.settingsProfileCardLabel(
        '$name${l10n.commonListSeparator}$learning',
      );
      final card = find.bySemanticsLabel(label);
      expect(card, findsOneWidget);
      expect(
        tester.getSemantics(card),
        isSemantics(label: label, isButton: true, hasTapAction: true),
      );
      expect(find.byIcon(Icons.chevron_right), findsWidgets);

      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilesPrivacyPage), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('keeps Switch as its own target, under the name', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const SettingsPage(),
        state: AppState.test(features: FeatureRegistry.all()),
      );
      final l10n = l10nOf(tester);
      final name = find.text(
        state.currentProfile.name ?? l10n.commonUnnamedProfile,
      );
      final button = find.text(l10n.settingsSwitchProfile);
      expect(
        tester.getTopLeft(button).dy,
        greaterThan(tester.getBottomLeft(name).dy),
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(ProfilesPage), findsOneWidget);
      expect(find.byType(ProfilesPrivacyPage), findsNothing);
    });

    testWidgets('Switch is incoming until profiles land, and the card still '
        'opens its page', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      expect(find.text(l10n.incomingBadge), findsWidgets);
      await tester.tap(
        find.text(l10n.settingsSwitchProfile),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfilesPage), findsNothing);
    });
  });

  group('the footer', () {
    testWidgets('shows the version in pubspec.yaml', (tester) async {
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

    testWidgets('carries the brand mark, beside the name', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const SettingsPage());
      final footer = find.text(l10nOf(tester).settingsFooter(AppInfo.version));
      await scrollTo(tester, footer);
      final mark = find.byType(FluenoughMark);
      expect(mark, findsOneWidget);
      expect(tester.getSize(mark), const Size.square(32));
      expect(
        tester.getCenter(mark).dy,
        closeTo(tester.getCenter(footer).dy, 12),
      );
    });
  });

  // The tab and every page it opens, as the mockup draws them: no overflow
  // at 1x or 1.4x text, light or dark, from top to bottom.
  final pages = <String, Widget>{
    'Settings': const SettingsPage(),
    'Your languages': const LanguagesSettingsPage(),
    'Activities and memory': const ActivitiesPage(),
    'Look and language': const AppearancePage(),
    'Reviewing': const ReviewingPage(),
    'Your decks': const YourDecksPage(),
    'Reminders': const RemindersPage(),
    'Your data': const YourDataPage(),
    'App log': const AppLogPage(),
    'Updates': const UpdatesPage(),
    'Profiles and privacy': const ProfilesPrivacyPage(),
  };
  for (final MapEntry(key: name, value: page) in pages.entries) {
    for (final scale in <double>[1.0, 1.4]) {
      for (final dark in <bool>[false, true]) {
        testWidgets(
          '$name at text scale $scale${dark ? ', dark' : ''}, this version '
          'and with every feature on',
          (tester) async {
            usePhone(tester, textScale: scale);
            for (final all in <bool>[false, true]) {
              await pumpScreen(
                tester,
                page,
                state: AppState.test(
                  features: all
                      ? FeatureRegistry.all()
                      : const FeatureRegistry.shipped(),
                  settings: SettingsNotifier(reminder: all),
                ),
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              );
              expect(tester.takeException(), isNull);
              await scrollThrough(tester);
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }
}

/// How many of the activity switches show off because their feature is
/// incoming, which the tab's line counts as off too.
int _incomingSwitches(AppState state, {bool includeProduction = false}) =>
    <Skill>[
      for (final skill in Skill.values)
        if (skill.hasSwitch &&
            (includeProduction || skill != Skill.production) &&
            !(state.features.isAvailable(skill.feature) &&
                state.settings.isEnabled(skill)))
          skill,
    ].length;
