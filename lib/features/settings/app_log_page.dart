import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/logs/log_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/card_text_scale.dart';

/// The app's own log (#162), a line an entry, oldest at the top and the
/// newest at the foot, where it opens. The text can be selected. Opened
/// from Settings' App log row, and from a report's log box, which shows
/// what would be attached.
///
/// Its actions are in a bottom bar, icon over word: Copy, Export and Clear,
/// which deletes and so is in the error colour (docs/mockups/settings.html,
/// 3b). From a text scale of 1.4 the words go, and the icons stay, named by
/// their tooltips.
class AppLogPage extends StatelessWidget {
  const AppLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final log = AppScope.of(context).log;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall!.copyWith(
      fontFamily: 'monospace',
      color: theme.colorScheme.onSurface,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appLogTitle),
        actions: const <Widget>[ReportButton()],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: log,
        builder: (context, _) => _ActionBar(empty: log.isEmpty),
      ),
      body: ListenableBuilder(
        listenable: log,
        builder: (context, _) {
          final entries = log.entries;
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(24),
                child: Text(
                  l10n.appLogEmpty,
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return Semantics(
            container: true,
            label: l10n.appLogLabel,
            child: SelectionArea(
              // Reversed, so that it opens at the newest; built newest
              // first, so that the oldest is still at the top.
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  16,
                  8,
                  16,
                  24,
                ).clearingSystemBar(context),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final entry = entries[entries.length - 1 - i];
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 6),
                    child: Text(
                      entry.line,
                      style: entry.level == LogLevel.event
                          ? style
                          : style.copyWith(
                              color: entry.level == LogLevel.error
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.tertiary,
                            ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Copy, Export and Clear, in a bar above Android's buttons.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.empty});

  /// Whether the log has nothing to act on.
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    final iconsOnly = isLargeText(context);
    Widget action({
      required IconData icon,
      required String word,
      required String tooltip,
      required VoidCallback? onPressed,
      Color? color,
    }) {
      final enabled = onPressed != null;
      final tint = enabled
          ? color ?? scheme.onSurfaceVariant
          : scheme.onSurface.withValues(alpha: 0.38);
      return Expanded(
        child: Semantics(
          container: true,
          button: true,
          enabled: enabled,
          label: tooltip,
          excludeSemantics: true,
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: InkWell(
              onTap: onPressed,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(icon, color: tint),
                    if (!iconsOnly)
                      Text(
                        word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge!
                            .copyWith(color: tint),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            action(
              icon: Icons.copy_outlined,
              word: l10n.appLogCopy,
              tooltip: l10n.settingsLogCopy,
              onPressed: empty ? null : () => _copyLog(context, state),
            ),
            action(
              icon: Icons.file_download_outlined,
              word: l10n.appLogExport,
              tooltip: l10n.settingsLogExport,
              onPressed: empty ? null : () => _exportLog(context, state),
            ),
            action(
              icon: Icons.delete_outline,
              word: l10n.appLogClear,
              tooltip: l10n.settingsLogClear,
              color: scheme.error,
              onPressed: empty ? null : () => _clearLog(context, state),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _copyLog(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: state.log.text));
    if (context.mounted) showAppSnackBar(context, l10n.settingsLogCopied);
  }

  /// Saves the app log as [appLogFileName], where the learner picks.
  static Future<void> _exportLog(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    final bool saved;
    try {
      saved = await state.logFiles.save(
        appLogFileName,
        state.log.text,
        mimeType: 'text/plain',
      );
    } on Exception catch (e) {
      state.log.warning('App log not exported: ${e.runtimeType}');
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsLogExportFailed);
      }
      return;
    }
    if (!saved) return;
    state.log.event('App log exported');
    if (context.mounted) {
      showAppSnackBar(context, l10n.settingsExported(appLogFileName));
    }
  }

  /// Asks, then clears the app log.
  static Future<void> _clearLog(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsLogClearTitle),
        content: Text(l10n.settingsLogClearBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsLogClearConfirm),
          ),
        ],
      ),
    );
    if (clear != true) return;
    await state.log.clear();
    if (context.mounted) showAppSnackBar(context, l10n.settingsLogCleared);
  }
}
