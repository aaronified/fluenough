import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/features/settings/backup_section.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:fluenough/ui/widgets/snack.dart';

import '../../support/harness.dart';
import 'support.dart';

void main() {
  test('cloud backup waits for #112, and local backup for #470', () {
    expect(Feature.cloudBackup.issue, 112);
    expect(Feature.available, isNot(contains(Feature.cloudBackup)));
    expect(Feature.localBackup.issue, 470);
    expect(Feature.available, isNot(contains(Feature.localBackup)));
  });

  testWidgets('Backup and restore is the first group of Your data: Back up '
      'now, Restore from a file, Cloud, Recent backups, and what a backup '
      'holds, in that order', (tester) async {
    usePhone(tester);
    tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
    await pumpScreen(tester, const YourDataPage());
    final l10n = l10nOf(tester);
    expect(BackupSection.services(l10n).toSet(), hasLength(5));

    var above = -1.0;
    for (final text in <String>[
      l10n.settingsDataBackup,
      l10n.settingsDataBackupIntro,
      l10n.settingsDataBackupNow,
      l10n.settingsDataRestore,
      l10n.settingsDataCloud,
      l10n.settingsDataConnect,
      l10n.settingsDataRecentNote,
      l10n.settingsDataBackupPrivacy,
      l10n.settingsDataLog,
    ]) {
      final finder = find.text(text).first;
      expect(finder, findsOneWidget, reason: text);
      final top = tester.getTopLeft(finder).dy;
      expect(top, greaterThan(above), reason: text);
      above = top;
    }
  });

  testWidgets('every row reads as incoming, and tapping one only says so', (
    tester,
  ) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    final links = FixedLinks();
    final state = await pumpScreen(
      tester,
      const YourDataPage(),
      state: AppState.test(links: links),
    );
    final l10n = l10nOf(tester);
    final before = state.settings.toStored();

    for (final title in <String>[
      l10n.settingsDataBackupNow,
      l10n.settingsDataRestore,
      l10n.settingsDataConnect,
      l10n.settingsDataRecent,
    ]) {
      final node = find.bySemanticsLabel(l10n.incomingSemanticsLabel(title));
      await scrollTo(tester, node);
      expect(node, findsOneWidget, reason: title);
      expect(
        tester.getSemantics(node),
        isSemantics(
          label: l10n.incomingSemanticsLabel(title),
          hint: l10n.incomingSemanticsHint,
          isButton: true,
          hasTapAction: true,
        ),
        reason: title,
      );
      await tester.tap(node, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(l10n.incomingSnackBar), findsOneWidget, reason: title);
      await clearSnackBars(tester);
    }

    // Nothing opened, asked or changed.
    expect(find.byType(YourDataPage), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    expect(links.asked, isEmpty);
    expect(state.settings.toStored(), before);
    semantics.dispose();
  });

  testWidgets('with the features on, the rows are live and do nothing yet', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const YourDataPage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    final l10n = l10nOf(tester);
    final connect = find.text(l10n.settingsDataConnect);
    await scrollTo(tester, connect);
    expect(
      find.ancestor(of: connect, matching: find.byType(GroupedTile)),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        l10n.incomingSemanticsLabel(l10n.settingsDataConnect),
      ),
      findsNothing,
    );
    await tester.tap(connect);
    await tester.pumpAndSettle();
    expect(find.byType(AppToast), findsNothing);
  });
}
