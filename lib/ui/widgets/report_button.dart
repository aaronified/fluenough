import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/features.dart';
import '../../app/links.dart';
import '../../app/routes.dart';
import '../../core/feedback/report.dart';
import '../../l10n/app_localizations.dart';
import 'report_capture.dart';
import 'snack.dart';

/// What the app adds to a report from [screen], which showed [detail]: its
/// version, the system's, the app language, the languages learned. Keys are
/// for the issue's reader, not interface text.
Map<String, String> reportContext(
  BuildContext context, {
  required String screen,
  String? detail,
}) {
  final state = AppScope.read(context);
  return <String, String>{
    'App': 'fluenough ${AppInfo.version}',
    'System': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'App language': Localizations.localeOf(context).toLanguageTag(),
    'Learning': <String>[
      for (final language in state.languages)
        if (state.currentProfile.learns(language.code)) language.code,
    ].join(', '),
    'Screen': screen,
    'Showing': ?detail,
  };
}

/// The bug icon on every screen (ADR-0021). `test/gallery_test.dart` checks
/// that every screen in the gallery has one.
///
/// While mail reports are incoming (#160), it opens a new GitHub issue with
/// the screen, what it showed and the app's version filled in. Once they
/// are on, it takes a picture of the screen and opens the report, where the
/// picture can be added.
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
    if (!AppScope.read(context).features.isAvailable(Feature.feedbackMail)) {
      final l10n = AppLocalizations.of(context)!;
      final body = issueBody(
        l10n.reportIssuePrompt,
        reportContext(context, screen: screen, detail: detail),
      );
      await openLink(
        context,
        AppLinks.newIssue(body).toString(),
        copied: l10n.reportLinkCopied,
      );
      return;
    }
    final screenshot = await ReportCapture.capture(context);
    if (!context.mounted) return;
    await AppNavigator.openReport(
      context,
      ReportRequest(screen: screen, detail: detail, screenshot: screenshot),
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context)!.reportOpen,
    icon: const Icon(Icons.bug_report_outlined),
    onPressed: () => open(context, detail: detail),
  );
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
