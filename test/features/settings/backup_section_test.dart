import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/ui/widgets/snack.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/features/settings/backup_section.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';
import 'support.dart';

void main() {
  test('cloud backup waits for #139', () {
    expect(Feature.cloudBackup.issue, 139);
    expect(Feature.available, isNot(contains(Feature.cloudBackup)));
  });

  testWidgets('Back up to the cloud follows export and import, with the five '
      'services in order and the line that progress stays on the phone', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final l10n = l10nOf(tester);
    await scrollTo(tester, find.text(l10n.settingsBackupHelp));

    final services = BackupSection.services(l10n);
    expect(services, <String>[
      l10n.settingsBackupDropbox,
      l10n.settingsBackupBox,
      l10n.settingsBackupGoogleDrive,
      l10n.settingsBackupOneDrive,
      l10n.settingsBackupNextcloud,
    ]);
    expect(services.toSet(), hasLength(5));

    final heading = find.text(l10n.settingsSectionBackup);
    expect(
      tester.getTopLeft(heading).dy,
      greaterThan(
        tester.getBottomLeft(find.text(l10n.settingsDeleteProfile)).dy,
      ),
      reason: 'right after Your data',
    );
    var above = tester.getBottomLeft(heading).dy;
    for (final service in services) {
      final row = find.text(service);
      expect(row, findsOneWidget, reason: service);
      expect(tester.getTopLeft(row).dy, greaterThan(above), reason: service);
      above = tester.getBottomLeft(row).dy;
    }
    expect(
      tester.getTopLeft(find.text(l10n.settingsBackupHelp)).dy,
      greaterThan(above),
    );
  });

  testWidgets('each service reads as incoming, and tapping one only says so', (
    tester,
  ) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    final links = FixedLinks();
    final state = await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(links: links),
    );
    final l10n = l10nOf(tester);
    final before = state.settings.toStored();

    for (final service in BackupSection.services(l10n)) {
      final node = find.bySemanticsLabel(l10n.incomingSemanticsLabel(service));
      await scrollTo(tester, node);
      expect(node, findsOneWidget, reason: service);
      expect(
        tester.getSemantics(node),
        isSemantics(
          label: l10n.incomingSemanticsLabel(service),
          hint: l10n.incomingSemanticsHint,
          isButton: true,
          hasTapAction: true,
        ),
        reason: service,
      );
      await tester.tap(node, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(l10n.incomingSnackBar), findsOneWidget, reason: service);
      await clearSnackBars(tester);
    }

    // Nothing opened, asked or changed.
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    expect(links.asked, isEmpty);
    expect(state.settings.toStored(), before);
    semantics.dispose();
  });

  testWidgets('with the feature on, the services are live rows that do '
      'nothing yet', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    final l10n = l10nOf(tester);
    final dropbox = find.text(l10n.settingsBackupDropbox);
    await scrollTo(tester, dropbox);
    expect(
      find.ancestor(of: dropbox, matching: find.byType(GroupedTile)),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        l10n.incomingSemanticsLabel(l10n.settingsBackupDropbox),
      ),
      findsNothing,
    );
    await tester.tap(dropbox);
    await tester.pumpAndSettle();
    expect(find.byType(AppToast), findsNothing);
  });
}
