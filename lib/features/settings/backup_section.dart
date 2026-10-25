import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/backups.dart';
import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/snack.dart';
import 'restore_sheet.dart';
import 'settings_controls.dart';
import '../../ui/card_text_scale.dart';

/// Backup and restore, the first group of Your data (#470, #473;
/// docs/BACKUP-FORMAT.md): Back up now and Restore from a file, the Cloud
/// group, Recent backups, and what a backup holds.
///
/// Recent backups are the five newest kept on the phone, of any kind: the
/// ones the learner made, the one made as each app update began to
/// download, and the copy a restore keeps of what it replaced. Each has
/// Download, Send to cloud and Restore. The cloud waits for #112
/// (`Feature.cloudBackup`): its rows and each backup's Send to cloud are
/// incoming. Restore (`Feature.localRestore`) replaces the append-only
/// review log once the learner confirms: the one logged exception to
/// AGENTS.md rule 9 (owner, 2026-10-17).
class BackupSection extends StatefulWidget {
  const BackupSection({super.key});

  /// The services, in the order the Connect a cloud line names them.
  static List<String> services(AppLocalizations l10n) => <String>[
    l10n.settingsBackupDropbox,
    l10n.settingsBackupBox,
    l10n.settingsBackupGoogleDrive,
    l10n.settingsBackupOneDrive,
    l10n.settingsBackupNextcloud,
  ];

  /// How a kept backup is named: how it was made, and when.
  static String nameOf(
    BuildContext context,
    AppLocalizations l10n,
    StoredBackup backup,
  ) {
    final date = MaterialLocalizations.of(context)
        .formatShortMonthDay(backup.createdAt);
    return switch (backup.kind) {
      BackupKind.you => l10n.settingsBackupMadeByYou(date),
      BackupKind.update =>
        backup.info.forVersion == null
            ? l10n.settingsBackupMadeByYou(date)
            : l10n.settingsBackupBeforeUpdate(backup.info.forVersion!, date),
      BackupKind.restore => l10n.settingsBackupBeforeRestore(date),
      BackupKind.file => l10n.settingsBackupFromFile(date),
    };
  }

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(AppScope.read(context).backups.load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final help = settingsHelpStyle(Theme.of(context));
    Widget line(String text) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: Text(text, style: help),
    );
    return ListenableBuilder(
      listenable: state.backups,
      builder: (context, _) {
        final recent = state.backups.recent;
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
                  onTap: () => _backUpNow(context, state),
                ),
                GroupedTile(
                  leading: const Icon(Icons.restore_page_outlined),
                  title: l10n.settingsDataRestore,
                  subtitle: l10n.settingsDataRestoreDesc,
                  trailing: const Icon(Icons.chevron_right),
                  feature: Feature.localRestore,
                  onTap: () => _restoreFromFile(context, state),
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
            if (recent.isEmpty)
              line(l10n.settingsDataRecentDesc)
            else
              GroupedList.settings(
                children: <Widget>[
                  for (final backup in recent)
                    _BackupRow(
                      key: ValueKey<String>('backup-${backup.id}'),
                      backup: backup,
                      name: BackupSection.nameOf(context, l10n, backup),
                      onDownload: () => _download(context, state, backup),
                      onRestore: () => _restoreKept(context, state, backup),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            line(l10n.settingsDataRecentNote),
            const SizedBox(height: 8),
            line(l10n.settingsDataBackupPrivacy),
          ],
        );
      },
    );
  }

  static Future<void> _backUpNow(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final saved = await state.backups.backUpNow();
      if (saved && context.mounted) {
        showAppSnackBar(context, l10n.settingsDataBackedUp);
      }
    } on Exception catch (e) {
      state.log.warning('Backup not made: ${e.runtimeType}');
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsDataBackupFailed);
      }
    }
  }

  static Future<void> _download(
    BuildContext context,
    AppState state,
    StoredBackup backup,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final saved = await state.backups.download(backup);
      if (saved && context.mounted) {
        showAppSnackBar(
          context,
          l10n.settingsBackupSaved(AppBackup.fileName(backup.createdAt)),
        );
      }
    } on Exception catch (e) {
      state.log.warning('Backup not downloaded: ${e.runtimeType}');
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsDataBackupFailed);
      }
    }
  }

  static Future<void> _restoreFromFile(
    BuildContext context,
    AppState state,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final AppBackup? backup;
    try {
      backup = await state.backups.pick(title: l10n.settingsDataRestorePick);
    } on NewerBackupException catch (newer) {
      state.log.warning('Backup refused: made by a newer app');
      if (context.mounted) await showNewerBackupSheet(context, newer: newer);
      return;
    } on Exception catch (e) {
      state.log.warning('Backup not read: ${e.runtimeType}');
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsDataRestoreNotBackup);
      }
      return;
    }
    if (backup == null || !context.mounted) return;
    await _confirmAndRestore(
      context,
      state,
      backup,
      name: BackupSection.nameOf(
        context,
        l10n,
        StoredBackup(
          id: '',
          info: BackupInfo(
            appVersion: backup.appVersion,
            createdAt: backup.createdAt,
            kind: backup.kind,
            forVersion: backup.forVersion,
            reviews: backup.reviews.length,
          ),
        ),
      ),
      fromFile: true,
    );
  }

  static Future<void> _restoreKept(
    BuildContext context,
    AppState state,
    StoredBackup stored,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final AppBackup backup;
    try {
      backup = await state.backups.read(stored);
    } on Exception catch (e) {
      state.log.warning('Kept backup not read: ${e.runtimeType}');
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsDataRestoreNotBackup);
      }
      return;
    }
    if (!context.mounted) return;
    await _confirmAndRestore(
      context,
      state,
      backup,
      name: BackupSection.nameOf(context, l10n, stored),
      fromFile: false,
    );
  }

  static Future<void> _confirmAndRestore(
    BuildContext context,
    AppState state,
    AppBackup backup, {
    required String name,
    required bool fromFile,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showRestoreSheet(
      context,
      backup: backup,
      name: name,
    );
    if (!confirmed) return;
    try {
      await state.backups.restore(backup, fromFile: fromFile);
    } on Object catch (e) {
      state.log.error('Restore failed: ${e.runtimeType}');
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsDataRestoreFailed);
      }
      return;
    }
    if (context.mounted) showAppSnackBar(context, l10n.settingsDataRestored);
  }
}

/// One kept backup: how and when it was made, how many reviews it holds,
/// and its three actions, Download, Send to cloud and Restore, each an
/// icon over its word, a third of the row wide and 56 tall. Above 1.3x text
/// the words would not fit, so the three are icons alone, 48 tall and wide,
/// named by tooltips and to screen readers (the Settings mockup, decision
/// 4).
class _BackupRow extends StatelessWidget {
  const _BackupRow({
    super.key,
    required this.backup,
    required this.name,
    required this.onDownload,
    required this.onRestore,
  });

  final StoredBackup backup;
  final String name;
  final VoidCallback onDownload;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final large = isLargeText(context);
    Widget action(
      IconData icon,
      String label,
      VoidCallback? onTap, {
      Feature? feature,
    }) {
      final Widget built = large
          ? Tooltip(
              message: label,
              child: Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                onTap: onTap,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Icon(icon, color: scheme.primary),
                  ),
                ),
              ),
            )
          : Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              onTap: onTap,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(icon, color: scheme.primary),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge!.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
      final wrapped = feature == null
          ? built
          : IncomingFeature(
              feature: feature,
              label: label,
              badge: IncomingBadgePlacement.none,
              child: built,
            );
      return large ? wrapped : Expanded(child: wrapped);
    }

    final actions = <Widget>[
      action(Icons.download, l10n.settingsBackupDownload, onDownload),
      action(
        Icons.cloud_upload_outlined,
        l10n.settingsBackupSendToCloud,
        null,
        feature: Feature.cloudBackup,
      ),
      action(
        Icons.settings_backup_restore,
        l10n.settingsBackupRestore,
        onRestore,
        feature: Feature.localRestore,
      ),
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: theme.textTheme.titleMedium),
                Text(
                  l10n.settingsBackupReviews(backup.info.reviews),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              for (final (i, a) in actions.indexed) ...<Widget>[
                if (i > 0) SizedBox(width: large ? 8 : 4),
                a,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
