import '../core/feedback/report.dart';
import 'links.dart';
import 'mail_share.dart';

/// Sends a report through the reporter's own mail app (#160, ADR-0021),
/// addressed to [address], its subject and body filled in. The app never
/// sends mail itself; the reporter sees the mail, can change it, and sends
/// it.
///
/// A report without files goes as a mailto link, opened through [links].
/// One with files, such as the app log, goes through [share], Android's
/// share, as a link cannot carry a file. If sharing fails, the report goes
/// as a link without its files, and the outcome says they were left out.
class MailReportSender implements ReportSender {
  const MailReportSender({
    required this.address,
    required this.links,
    this.share = const NullMailShare(),
  });

  /// The Fluenough inbox. Empty until it exists, and then every report
  /// fails as [ReportFailure.notSetUp].
  final String address;

  final LinkOpener links;

  final MailShare share;

  @override
  Future<ReportOutcome> send(Report report) async {
    if (address.isEmpty) return const ReportFailed(ReportFailure.notSetUp);
    if (report.files.isNotEmpty) {
      bool shared;
      try {
        shared = await share.share(
          to: <String>[address],
          subject: report.subject,
          body: report.body,
          files: report.files,
        );
      } catch (_) {
        // Whatever went wrong, the report still goes, as a link.
        shared = false;
      }
      if (shared) return const ReportInMailApp();
    }
    final opened = await links.open(reportMailto(address, report).toString());
    if (!opened) return const ReportFailed(ReportFailure.noMailApp);
    return ReportInMailApp(filesLeftOut: report.files.isNotEmpty);
  }
}
