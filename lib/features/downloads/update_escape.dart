import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/report_button.dart';
import '../settings/update_section.dart';

/// The way out of a screen a failed download leaves the learner on, with
/// Settings out of reach: the first launch's "Getting your decks", the
/// picker's "Couldn't get the list of courses", and the picker when a
/// language's decks will not come.
///
/// A fault in the app's own downloader can fail every download, as 0.4.0's
/// did. The update that fixes it is in Settings, which those screens cannot
/// reach. So under their Try again, quietly: "Check for an app update",
/// which checks and offers it exactly as Settings does
/// ([showUpdateSheet]). Once the same failure has come back [repeatedAfter]
/// times, a line suggests updating or reporting it, with the bug icon's
/// report beside the check.
class UpdateEscape extends StatelessWidget {
  const UpdateEscape({super.key, required this.failures, this.detail});

  /// How many times in a row the download has failed here.
  final int failures;

  /// What failed, sent with a report: not interface text.
  final String? detail;

  /// How many failures in a row show the line and the report: the first,
  /// and then Try again failing twice.
  static const int repeatedAfter = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final repeated = failures >= repeatedAfter;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (repeated) ...<Widget>[
          Text(
            l10n.downloadsKeepsFailing,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => showUpdateSheet(context),
              icon: const Icon(Icons.system_update_outlined),
              label: Text(l10n.downloadsCheckAppUpdate),
            ),
            if (repeated)
              TextButton.icon(
                onPressed: () => ReportButton.open(context, detail: detail),
                icon: const Icon(Icons.bug_report_outlined),
                label: Text(l10n.downloadsReportProblem),
              ),
          ],
        ),
      ],
    );
  }
}

/// Checks GitHub for a newer version of the app, and shows what it finds in
/// a sheet, as Settings' "Check for updates" row: Download and its
/// progress if there is one, "Up to date" if not. The check is the one
/// Settings runs ([UpdateChecker.check]), so it is joined if under way and
/// skipped during an install.
Future<void> showUpdateSheet(BuildContext context) {
  unawaited(AppScope.read(context).updates.check());
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _UpdateSheet(),
  );
}

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSizes.gutter,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.settingsSectionUpdates,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const UpdateCheckRow(),
          ],
        ),
      ),
    );
  }
}
