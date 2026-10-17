import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import 'settings_controls.dart';

/// Backup and restore, the first group of Your data (#470, #473; docs/plans/
/// app-backup.md): Back up now and Restore from a file, the Cloud group, the
/// recent backups, and what a backup holds.
///
/// None of it is built yet, so every row is incoming and has no action:
/// local backup waits for #470 (`Feature.localBackup`) and the cloud for
/// #112 (`Feature.cloudBackup`). The five services the cloud offers sit
/// under one row, Connect a cloud. Recent backups is one row that stands
/// for the list, which has nothing to list until a backup can be made.
class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  /// The services, in the order the Connect a cloud line names them.
  static List<String> services(AppLocalizations l10n) => <String>[
    l10n.settingsBackupDropbox,
    l10n.settingsBackupBox,
    l10n.settingsBackupGoogleDrive,
    l10n.settingsBackupOneDrive,
    l10n.settingsBackupNextcloud,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final help = settingsHelpStyle(Theme.of(context));
    Widget line(String text) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: Text(text, style: help),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsHeading(l10n.settingsDataBackup),
        const SizedBox(height: 8),
        line(l10n.settingsDataBackupIntro),
        const SizedBox(height: 12),
        GroupedList.settings(
          children: <Widget>[
            GroupedTile(
              leading: const Icon(Icons.backup_outlined),
              title: l10n.settingsDataBackupNow,
              subtitle: l10n.settingsDataBackupNowDesc,
              trailing: const Icon(Icons.chevron_right),
              feature: Feature.localBackup,
            ),
            GroupedTile(
              leading: const Icon(Icons.restore_page_outlined),
              title: l10n.settingsDataRestore,
              subtitle: l10n.settingsDataRestoreDesc,
              trailing: const Icon(Icons.chevron_right),
              feature: Feature.localBackup,
            ),
          ],
        ),
        const SizedBox(height: 20),
        SettingsHeading(l10n.settingsDataCloud),
        const SizedBox(height: 8),
        GroupedList.settings(
          children: <Widget>[
            GroupedTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: l10n.settingsDataConnect,
              subtitle: l10n.settingsDataConnectDesc,
              trailing: const Icon(Icons.chevron_right),
              feature: Feature.cloudBackup,
            ),
          ],
        ),
        const SizedBox(height: 20),
        SettingsHeading(l10n.settingsDataRecent),
        const SizedBox(height: 8),
        GroupedList.settings(
          children: <Widget>[
            GroupedTile(
              leading: const Icon(Icons.history),
              title: l10n.settingsDataRecent,
              subtitle: l10n.settingsDataRecentDesc,
              feature: Feature.localBackup,
            ),
          ],
        ),
        const SizedBox(height: 8),
        line(l10n.settingsDataRecentNote),
        const SizedBox(height: 8),
        line(l10n.settingsDataBackupPrivacy),
      ],
    );
  }
}
