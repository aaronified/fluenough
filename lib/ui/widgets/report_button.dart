import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/feedback/report.dart';
import '../../l10n/app_localizations.dart';
import 'report_capture.dart';

/// The bug icon on every screen (ADR-0021): takes a picture of the screen as
/// it is, then opens the report with it. `test/gallery_test.dart` checks
/// that every screen in the gallery has one.
class ReportButton extends StatelessWidget {
  const ReportButton({super.key, this.detail});

  /// What the screen is showing, sent with the report: a card's id, a deck's,
  /// a tab's name. The screen's route name is sent anyway.
  final String? detail;

  /// Takes a picture of the screen [context] is on and opens a report from
  /// it, saying it showed [detail]. For a button of a screen's own, such as
  /// an unchecked deck's "Report a mistake".
  static Future<void> open(BuildContext context, {String? detail}) async {
    final screen = ModalRoute.of(context)?.settings.name ?? '';
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
