import 'package:flutter/material.dart';

import '../../app/app_log.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// How many of the log's newest lines the box shows.
const int logPreviewLines = 3;

/// The box that attaches the app log to a report, beside the device box,
/// and under it what the log holds, its newest lines, and the way to see
/// all of it. Unticked until the reporter ticks it (ADR-0021, #162). With
/// the log empty there is nothing to attach, and it cannot be ticked.
class LogConsent extends StatelessWidget {
  const LogConsent({
    super.key,
    required this.log,
    required this.value,
    required this.onChanged,
  });

  final AppLog log;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final entries = log.entries;
        final empty = entries.isEmpty;
        final newest = entries.length <= logPreviewLines
            ? entries
            : entries.sublist(entries.length - logPreviewLines);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CheckboxListTile(
              value: value && !empty,
              onChanged: empty ? null : (ticked) => onChanged(ticked ?? false),
              title: Text(l10n.reportLog),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    empty
                        ? l10n.reportLogEmpty
                        : l10n.reportLogSummary(entries.length),
                    style: muted,
                  ),
                  if (!empty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      <String>[for (final e in newest) e.line].join('\n'),
                      style: muted.copyWith(fontFamily: 'monospace'),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => AppNavigator.openAppLog(context),
                        child: Text(l10n.reportLogSeeAll),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
