import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logs/log_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/report_button.dart';

/// The app's own log (#162), a line an entry, oldest at the top and the
/// newest at the foot, where it opens. The text can be selected. Opened
/// from Settings' Logs section, and from a report's log box, which shows
/// what would be attached.
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
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
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
