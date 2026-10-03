import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/features.dart';
import '../../app/links.dart';
import '../../app/routes.dart';
import '../../core/feedback/report.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'snack.dart';

/// The device's details as [context] sees them, given its [system]: the
/// app's version and language, the system's version, the screen's size, the
/// text scale and the languages learned. A report carries them only if the
/// reporter ticks [DeviceInfoConsent] (ADR-0021). Keys are for the issue's
/// reader, not interface text.
Map<String, String> deviceInfo(BuildContext context, {required String system}) {
  final state = AppScope.read(context);
  final size = MediaQuery.sizeOf(context);
  return <String, String>{
    'App': 'fluenough ${AppInfo.version}',
    'System': system,
    'Screen size': '${size.width.round()} × ${size.height.round()} dp',
    'Text scale': MediaQuery.textScalerOf(context).scale(1).toStringAsFixed(2),
    'App language': Localizations.localeOf(context).toLanguageTag(),
    'Learning': <String>[
      for (final language in state.languages)
        if (state.currentProfile.learns(language.code)) language.code,
    ].join(', '),
  };
}

/// The bug icon on every screen (ADR-0021). `test/gallery_test.dart` checks
/// that every screen in the gallery has one.
///
/// While mail reports are incoming (#160), it asks first whether to add the
/// device's details, then opens a new GitHub issue with the screen and what
/// it showed filled in. Once they are on, it opens the report.
class ReportButton extends StatelessWidget {
  const ReportButton({super.key, this.detail});

  /// What the screen is showing, sent with the report: a card's id, a deck's,
  /// a tab's name. The screen's route name is sent anyway.
  final String? detail;

  /// A report from the screen [context] is on, saying it showed [detail].
  /// For a button of a screen's own too, such as an unchecked deck's
  /// "Report a mistake" or a card's Report in Inspect.
  static Future<void> open(BuildContext context, {String? detail}) async {
    final screen = ModalRoute.of(context)?.settings.name ?? '';
    final system = await AppInfo.system();
    if (!context.mounted) return;
    final request = ReportRequest(
      screen: screen,
      detail: detail,
      device: deviceInfo(context, system: system),
    );
    if (AppScope.read(context).features.isAvailable(Feature.feedbackMail)) {
      await AppNavigator.openReport(context, request);
      return;
    }
    final withDevice = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _GitHubSheet(device: request.device),
    );
    if (withDevice == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final body = issueBody(l10n.reportIssuePrompt, <String, String>{
      ...request.always,
      if (withDevice) ...request.device,
    });
    await openLink(
      context,
      AppLinks.newIssue(body).toString(),
      copied: l10n.reportLinkCopied,
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context)!.reportOpen,
    icon: const Icon(Icons.bug_report_outlined),
    onPressed: () => open(context, detail: detail),
  );
}

/// The box that adds the device's details to a report, and under it exactly
/// what it adds. Unticked until the reporter ticks it (ADR-0021).
class DeviceInfoConsent extends StatelessWidget {
  const DeviceInfoConsent({
    super.key,
    required this.device,
    required this.value,
    required this.onChanged,
  });

  final Map<String, String> device;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CheckboxListTile(
          value: value,
          onChanged: (ticked) => onChanged(ticked ?? false),
          title: Text(AppLocalizations.of(context)!.reportDeviceInfo),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          child: Text(
            contextLines(device),
            style: theme.textTheme.bodySmall!.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Asked before GitHub opens while mail reports are incoming: what the issue
/// will carry, and whether to add the device's details. Pops whether to add
/// them, or nothing if dismissed.
class _GitHubSheet extends StatefulWidget {
  const _GitHubSheet({required this.device});

  final Map<String, String> device;

  @override
  State<_GitHubSheet> createState() => _GitHubSheetState();
}

class _GitHubSheetState extends State<_GitHubSheet> {
  bool _withDevice = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.reportGitHubTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.reportGitHubBody,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            DeviceInfoConsent(
              device: widget.device,
              value: _withDevice,
              onChanged: (value) => setState(() => _withDevice = value),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              onPressed: () => Navigator.of(context).pop(_withDevice),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.reportOpenGitHub),
            ),
          ],
        ),
      ),
    );
  }
}

/// A screen with no bar of its own, such as the summary: [child] with the
/// bug icon at its top end, where the screen leaves room for it.
class WithReportButton extends StatelessWidget {
  const WithReportButton({super.key, required this.child, this.detail});

  final Widget child;

  /// As [ReportButton.detail].
  final String? detail;

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      child,
      PositionedDirectional(
        top: 4,
        end: 4,
        child: ReportButton(detail: detail),
      ),
    ],
  );
}
