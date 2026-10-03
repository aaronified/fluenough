import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';

import '../core/feedback/report.dart';

/// Sends a report through the reporter's own mail app (#160, ADR-0021):
/// addressed to [address], its screenshot attached. The app never sends
/// mail itself; the reporter sees the mail and sends it.
class MailReportSender implements ReportSender {
  const MailReportSender({required this.address});

  /// The Fluenough inbox. Empty until it exists, and then every report
  /// fails as [ReportFailure.notSetUp].
  final String address;

  @override
  Future<ReportOutcome> send(Report report) async {
    if (address.isEmpty) return const ReportFailed(ReportFailure.notSetUp);
    final attachments = <String>[];
    if (report.screenshot case final png?) {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/fluenough-screenshot-'
        '${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png, flush: true);
      attachments.add(file.path);
    }
    try {
      await FlutterEmailSender.send(
        Email(
          recipients: <String>[address],
          subject: report.subject,
          body: report.body,
          attachmentPaths: attachments,
        ),
      );
      return const ReportInMailApp();
    } on FlutterEmailSenderException {
      return const ReportFailed(ReportFailure.noMailApp);
    }
  }
}
