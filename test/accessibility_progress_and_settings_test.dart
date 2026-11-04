// Split out of accessibility_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: Progress and settings.

import 'dart:ui' show LocaleStringAttribute;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/core/feedback/report.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/features/settings/activities_page.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:fluenough/features/stats/how_you_learn_page.dart';
import 'package:fluenough/features/stats/over_time_page.dart';

import 'support/backup_fixture.dart';
import 'support/harness.dart';
import 'support/paced_learner.dart';
import 'support/accessibility_shared.dart';

void main() {
  group('Progress and settings', () {
    screen('Progress', tab(ShellTab.progress));
    screen(
      'Progress, over time',
      page(
        const OverTimePage(),
        state: () =>
            pacedLearner(Paced.fewer, also: <Paced>{Paced.more, Paced.same}),
      ),
    );
    screen(
      'How you learn',
      page(
        const HowYouLearnPage(),
        state: () =>
            pacedLearner(Paced.fewer, also: <Paced>{Paced.more, Paced.same}),
      ),
    );
    screen('leeches', gallery('leeches'));
    screen('Settings', gallery('settings'));
    screen('Activities and memory', page(const ActivitiesPage()));
    screen('Appearance', page(const AppearancePage()));
    screen('Voices', gallery('voices-speaking'));
    screen('backup, the restore sheet open', (tester, mode) async {
      tester.view.physicalSize = const Size(390 * 3, 5000 * 3);
      final app = await stateWithBackups(
        features: const FeatureRegistry.shipped(),
      );
      await pumpScreen(
        tester,
        const YourDataPage(),
        state: app.state,
        themeMode: mode,
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.byTooltip(l10n.settingsBackupRestore).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsRestoreTitle), findsOneWidget);
    }, onTop: find.byType(BottomSheet));
    screen('the app log', gallery('settings-app-log'));
    screen('release notes', gallery('release-notes'));
    screen(
      'Report a problem',
      page(
        const ReportPage(
          request: ReportRequest(screen: '/deck', detail: 'hi-en-market'),
        ),
        state: () async => AppState.test(
          features: const FeatureRegistry.only(Feature.available),
        ),
      ),
    );
  });
}
