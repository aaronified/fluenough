import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import 'settings_controls.dart';

/// Settings' "Back up to the cloud", under Your data: Dropbox, Box, Google
/// Drive, OneDrive and Nextcloud, each incoming until #112 lands, and a
/// line saying that progress stays on the phone.
///
/// The services have no action yet even with the feature on: #112 decides
/// how each signs in and what it stores.
class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  /// The services, in the order Settings lists them.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GroupedList.settings(
          header: l10n.settingsSectionBackup,
          children: <Widget>[
            for (final service in services(l10n))
              GroupedTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: service,
                feature: Feature.cloudBackup,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: Text(
            l10n.settingsBackupHelp,
            style: settingsHelpStyle(Theme.of(context)),
          ),
        ),
      ],
    );
  }
}
