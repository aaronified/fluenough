import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/app_scope.dart';
import '../../app/links.dart';
import '../../app/update_checker.dart';
import '../../core/updates/apk_install.dart';
import '../../core/updates/release_check.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/snack.dart';

/// Settings' Updates group, above the version line (ADR-0017): "Check for
/// updates", which says what the check found, downloads it with its
/// progress and opens Android's installer, and "Check automatically", once
/// a day at launch, off until switched on.
///
/// The row's text is a live region, so a screen reader hears each answer
/// arrive. A download is not, or it would be read out at every percent:
/// its start is announced once instead, since the Download button that had
/// the focus is gone.
class UpdateSection extends StatelessWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final settings = state.settings;
    final updates = state.updates;
    return _DownloadAnnouncer(
      updates: updates,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[updates, settings]),
        builder: (context, _) => GroupedList.settings(
          header: l10n.settingsSectionUpdates,
          children: <Widget>[
            _checkRow(context, updates),
            GroupedTile.toggle(
              leading: const Icon(Icons.update),
              title: l10n.settingsUpdateAuto,
              subtitle: l10n.settingsUpdateAutoDesc,
              value: settings.autoUpdateCheck,
              onChanged: (on) => settings.autoUpdateCheck = on,
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkRow(BuildContext context, UpdateChecker updates) {
    final l10n = AppLocalizations.of(context)!;
    final current = updates.current;
    final latest = updates.latest ?? '';
    Widget tile(String subtitle, {VoidCallback? onTap}) => MergeSemantics(
      child: Semantics(
        liveRegion: true,
        child: GroupedTile(
          leading: const Icon(Icons.system_update_outlined),
          title: l10n.settingsUpdateCheck,
          subtitle: subtitle,
          onTap: onTap,
        ),
      ),
    );
    return switch (updates.status) {
      UpdateStatus.idle => tile(
        l10n.settingsUpdateCurrent(current),
        onTap: updates.check,
      ),
      // No spinner: the line says it, and the answer comes in seconds.
      UpdateStatus.checking => tile(l10n.settingsUpdateChecking),
      UpdateStatus.upToDate => tile(
        l10n.settingsUpdateUpToDate(current),
        onTap: updates.check,
      ),
      UpdateStatus.available => _ActionRow(
        icon: Icons.system_update,
        iconColor: Theme.of(context).colorScheme.primary,
        title: l10n.settingsUpdateAvailable(latest),
        subtitle: l10n.settingsUpdateAvailableDesc(current),
        actions: <Widget>[
          FilledButton.tonal(
            onPressed: updates.checkAndInstall,
            child: Text(l10n.settingsUpdateDownload),
          ),
        ],
      ),
      UpdateStatus.failed => _ActionRow(
        icon: Icons.sync_problem_outlined,
        title: l10n.settingsUpdateCheck,
        subtitle: switch (updates.failure) {
          ReleaseCheckFailure.rateLimited => l10n.settingsUpdateRateLimited,
          ReleaseCheckFailure.badReply => l10n.settingsUpdateBadReply,
          ReleaseCheckFailure.offline || null => l10n.settingsUpdateOffline,
        },
        actions: <Widget>[
          TextButton(onPressed: updates.check, child: Text(l10n.commonRetry)),
        ],
      ),
      // Not a live region: it would read out every percent. Its start is
      // announced by _DownloadAnnouncer.
      UpdateStatus.downloading => _ActionRow(
        icon: Icons.downloading,
        iconColor: Theme.of(context).colorScheme.primary,
        title: l10n.settingsUpdateDownloading(latest),
        subtitle: l10n.settingsUpdatePercent(updates.percent),
        progress: updates.percent / 100,
        live: false,
        actions: <Widget>[
          TextButton(
            onPressed: updates.cancelInstall,
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
      UpdateStatus.installing => _ActionRow(
        icon: Icons.install_mobile,
        iconColor: Theme.of(context).colorScheme.primary,
        title: l10n.settingsUpdateInstalling(latest),
        subtitle: l10n.settingsUpdateInstallingDesc,
        actions: <Widget>[
          TextButton(
            onPressed: updates.checkAndInstall,
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
      UpdateStatus.installFailed => _ActionRow(
        icon: Icons.error_outline,
        iconColor: Theme.of(context).colorScheme.error,
        title: l10n.settingsUpdateInstallFailed(latest),
        subtitle: installFailureText(l10n, updates.installFailure),
        actions: <Widget>[
          TextButton(
            onPressed: updates.checkAndInstall,
            child: Text(l10n.commonRetry),
          ),
          TextButton(
            onPressed: () => openLink(
              context,
              AppLinks.latestRelease,
              copied: l10n.settingsUpdatePageCopied,
            ),
            child: Text(l10n.settingsUpdateOpenPage),
          ),
        ],
        below: true,
      ),
    };
  }

  /// What went wrong with an install, and what to do about it.
  static String installFailureText(
    AppLocalizations l10n,
    InstallFailure? failure,
  ) => switch (failure) {
    InstallFailure.notAllowed => l10n.settingsUpdateNotAllowed,
    InstallFailure.download => l10n.settingsUpdateDownloadFailed,
    InstallFailure.checksum => l10n.settingsUpdateChecksumFailed,
    InstallFailure.install => l10n.settingsUpdateInstallError,
    InstallFailure.cancelled => l10n.settingsUpdateCancelled,
    InstallFailure.internal || null => l10n.settingsUpdateInternalError,
  };
}

/// Announces "Downloading 0.2.0" once, as a download starts.
class _DownloadAnnouncer extends StatefulWidget {
  const _DownloadAnnouncer({required this.updates, required this.child});

  final UpdateChecker updates;
  final Widget child;

  @override
  State<_DownloadAnnouncer> createState() => _DownloadAnnouncerState();
}

class _DownloadAnnouncerState extends State<_DownloadAnnouncer> {
  late UpdateStatus _last = widget.updates.status;

  @override
  void initState() {
    super.initState();
    widget.updates.addListener(_changed);
  }

  @override
  void didUpdateWidget(_DownloadAnnouncer old) {
    super.didUpdateWidget(old);
    if (old.updates == widget.updates) return;
    old.updates.removeListener(_changed);
    widget.updates.addListener(_changed);
    _last = widget.updates.status;
  }

  @override
  void dispose() {
    widget.updates.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final status = widget.updates.status;
    if (mounted &&
        status == UpdateStatus.downloading &&
        _last != UpdateStatus.downloading) {
      final l10n = AppLocalizations.of(context)!;
      SemanticsService.sendAnnouncement(
        View.of(context),
        l10n.settingsUpdateDownloading(widget.updates.latest ?? ''),
        Directionality.of(context),
      );
    }
    _last = status;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A row with buttons of its own, laid out as a [GroupedTile] is: the icon,
/// then the title and subtitle as one screen-reader node, a live region
/// unless [live] is false, and each of [actions] as another. One action
/// goes beside the text, or under it when the text is large or [below] is
/// true; more go under it.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions = const <Widget>[],
    this.iconColor,
    this.progress,
    this.live = true,
    this.below = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  /// Defaults to `onSurfaceVariant`, as a [GroupedTile]'s icon.
  final Color? iconColor;

  /// A bar under the subtitle, from 0 to 1. The subtitle says it in words.
  final double? progress;

  final bool live;
  final bool below;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Beside the text at normal sizes; under it when the text is large, as
    // the profile card's Switch button goes.
    final stacked =
        below ||
        actions.length > 1 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final bar = progress;
    final text = MergeSemantics(
      child: Semantics(
        liveRegion: live,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleMedium),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (bar != null) ...<Widget>[
              const SizedBox(height: 8),
              ExcludeSemantics(child: LinearProgressIndicator(value: bar)),
            ],
          ],
        ),
      ),
    );
    final buttons = Wrap(spacing: 8, runSpacing: 4, children: actions);
    return Padding(
      padding: GroupedTile.defaultPadding,
      child: Row(
        crossAxisAlignment: stacked
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: iconColor ?? scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: stacked && actions.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      text,
                      const SizedBox(height: 8),
                      buttons,
                    ],
                  )
                : text,
          ),
          if (!stacked && actions.isNotEmpty) ...<Widget>[
            const SizedBox(width: 16),
            buttons,
          ],
        ],
      ),
    );
  }
}
