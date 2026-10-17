import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/updates/apk_install.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/features/settings/settings_fixtures.dart';
import 'package:fluenough/features/settings/updates_page.dart';

import '../../support/backup_fixture.dart';
import '../../support/harness.dart';

final String _newer = SettingsFixtures.newerVersion;

void main() {
  for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    for (final scale in <double>[1.0, 1.4]) {
      testWidgets('the update row says a backup is made with the download, '
          'and, if it fails, that the update goes on, at $scale text, '
          '${themeMode.name}', (tester) async {
        usePhone(tester, textScale: scale);
        final gate = Completer<void>();
        final state = await pumpScreen(
          tester,
          const UpdatesPage(),
          state: AppState.test(
            releases: FixedReleaseCheck(LatestRelease(_newer)),
            installer: FixedApkInstaller(const <InstallEvent>[
              InstallEvent.downloading(40),
              InstallEvent.installing(),
            ], gate: gate),
            backupStore: FullBackupStore(),
          ),
          themeMode: themeMode,
        );
        final l10n = l10nOf(tester);
        await tester.tap(find.text(l10n.settingsUpdateCheck));
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.settingsUpdateAvailableDesc(AppInfo.version)),
          findsOneWidget,
        );
        expect(
          l10n.settingsUpdateAvailableDesc(AppInfo.version),
          contains('backup'),
        );
        expect(find.text(l10n.settingsUpdateBackupFailed), findsNothing);

        await tester.tap(find.text(l10n.settingsUpdateDownload));
        await tester.pumpAndSettle();
        // The download is held at 40%; the backup failed on its own.
        expect(state.updates.backupFailed, isTrue);
        expect(
          find.textContaining(l10n.settingsUpdateBackupFailed),
          findsOneWidget,
        );
        expect(
          find.text(l10n.settingsUpdateDownloading(_newer)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        gate.complete();
        await tester.pumpAndSettle();
      });
    }
  }
}
