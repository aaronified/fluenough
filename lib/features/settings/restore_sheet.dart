import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/backups.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// The names of [codes], as a list a sentence can hold: "Bengali and Hindi",
/// or "Bengali, Hindi, Tamil". A code the catalog does not know is its own
/// name.
String languageNames(
  BuildContext context,
  AppLocalizations l10n,
  Iterable<String> codes,
) {
  final known = <String, String>{
    for (final language in AppScope.read(context).languages)
      language.code: language.name,
  };
  final names = <String>[for (final code in codes) known[code] ?? code];
  return names.length == 2
      ? l10n.setListPair(names.first, names.last)
      : names.join(l10n.commonListSeparator);
}

/// What a backup holds, and the question before it replaces everything
/// (the Settings mockup, restore sheet): when it was made and by which
/// version, its progress, what else comes back, the decks that do not and
/// download again, and that a copy of what it replaces is kept first.
/// Resolves to true once the learner taps Replace and restore.
Future<bool> showRestoreSheet(
  BuildContext context, {
  required AppBackup backup,
  required String name,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _RestoreSheet(backup: backup, name: name),
  );
  return confirmed ?? false;
}

/// The sheet for a file a newer Fluenough made: nothing was read, nothing
/// has changed, and it says to update first. Check for updates asks for the
/// check the update row makes.
Future<void> showNewerBackupSheet(
  BuildContext context, {
  required NewerBackupException newer,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _NewerSheet(newer: newer),
);

class _RestoreSheet extends StatelessWidget {
  const _RestoreSheet({required this.backup, required this.name});

  final AppBackup backup;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final made = backup.createdAt;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(made),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final learning = (backup.settings['learning_languages'] ?? '')
        .split(',')
        .where((code) => code.isNotEmpty)
        .toList();
    final progress = learning.isEmpty
        ? l10n.settingsRestoreProgressOnly(backup.reviews.length)
        : l10n.settingsRestoreProgressIn(
            backup.reviews.length,
            languageNames(context, l10n, learning),
          );
    Widget fact(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsetsDirectional.only(top: 16),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 2),
              child: Icon(icon, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(value, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSizes.gutter,
          0,
          AppSizes.gutter,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.settingsRestoreTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            fact(
              Icons.event,
              l10n.settingsRestoreMade,
              l10n.settingsRestoreMadeAt(
                DateFormat.yMMMd(locale).format(made),
                time,
              ),
            ),
            if (backup.appVersion.isNotEmpty)
              fact(
                Icons.phone_android,
                l10n.settingsRestoreBy,
                l10n.settingsRestoreByApp(backup.appVersion),
              ),
            fact(Icons.history, l10n.settingsRestoreProgress, progress),
            fact(
              Icons.tune,
              l10n.settingsRestoreAlso,
              l10n.settingsRestoreAlsoText,
            ),
            if (backup.downloads.isNotEmpty)
              fact(
                Icons.download,
                l10n.settingsRestoreNotRestored,
                l10n.settingsRestoreDecks(
                  languageNames(context, l10n, backup.downloads),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(Icons.warning_amber, color: scheme.error),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.settingsRestoreWarning,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Wraps, so that at large text the buttons stack rather than
            // stick out sideways (#470's build note).
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  key: const ValueKey<String>('restore-confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    l10n.settingsRestoreConfirm,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewerSheet extends StatelessWidget {
  const _NewerSheet({required this.newer});

  final NewerBackupException newer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.read(context);
    final current = state.updates.current;
    final made = newer.appVersion;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSizes.gutter,
          0,
          AppSizes.gutter,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.settingsRestoreNewerTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              made == null || made.isEmpty
                  ? l10n.settingsRestoreNewerBodyUnknown(current)
                  : l10n.settingsRestoreNewerBody(made, current),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.settingsRestoreNewerClose),
                ),
                FilledButton(
                  onPressed: () {
                    state.updates.check();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    l10n.settingsRestoreNewerCheck,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
