import '../core/feedback/report.dart';
import 'links.dart';

/// Sends a report through the reporter's own mail app (#160, ADR-0021): a
/// mailto link to [address], its subject and body filled in, opened through
/// [links]. Text only. The app never sends mail itself; the reporter sees
/// the mail and sends it.
class MailReportSender implements ReportSender {
  const MailReportSender({required this.address, required this.links});

  /// The Fluenough inbox. Empty until it exists, and then every report
  /// fails as [ReportFailure.notSetUp].
  final String address;

  final LinkOpener links;

  @override
  Future<ReportOutcome> send(Report report) async {
    if (address.isEmpty) return const ReportFailed(ReportFailure.notSetUp);
    final opened = await links.open(reportMailto(address, report).toString());
    return opened
        ? const ReportInMailApp()
        : const ReportFailed(ReportFailure.noMailApp);
  }
}
