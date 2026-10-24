import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/links.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import 'settings_section_page.dart';

/// Settings' Support page (owner, 2026-10-24): an optional tip by UPI, said
/// to be a show of support that buys nothing extra, with reviewing and bug
/// reports named as helping as much or more.
///
/// "Open my UPI app" opens [AppLinks.supportUpi] with no amount; when no app
/// can, the page says so and the copy button under it is the way. "Copy UPI
/// ID" puts [AppLinks.supportUpiId] on the clipboard.
class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  bool _noUpiApp = false;

  Future<void> _openUpi() async {
    final opened = await AppScope.read(context).links.open(AppLinks.supportUpi);
    if (mounted) setState(() => _noUpiApp = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge;
    final buttonSize = Size.fromHeight(AppSizes.primaryButton);
    return SettingsSectionPage(
      title: l10n.settingsRowSupport,
      builder: (context) => <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.supportIntro, style: body),
              const SizedBox(height: 12),
              Text(l10n.supportNoPerks, style: body),
              const SizedBox(height: 12),
              Text(l10n.supportOtherWays, style: body),
            ],
          ),
        ),
        GroupedList.settings(
          children: <Widget>[
            GroupedTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: l10n.supportReviewDecks,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => AppNavigator.openSettingsPage(
                context,
                AppRoutes.settingsReviewing,
              ),
            ),
            GroupedTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: l10n.supportSendBugReport,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ReportButton.open(context),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
              child: Text(
                l10n.supportPayee(AppLinks.supportName, AppLinks.supportUpiId),
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: buttonSize),
              onPressed: _openUpi,
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.supportOpenUpi),
            ),
            if (_noUpiApp)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 0),
                child: Text(
                  l10n.supportNoUpiApp,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: buttonSize),
              onPressed: () => copyToClipboard(
                context,
                AppLinks.supportUpiId,
                confirmation: l10n.supportIdCopied,
              ),
              icon: const Icon(Icons.copy),
              label: Text(l10n.supportCopyId),
            ),
          ],
        ),
      ],
    );
  }
}
