import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/report_mail.dart';
import 'package:fluenough/core/feedback/report.dart';

void main() {
  const report = Report(kind: ReportKind.bug, title: 'The card shows twice');

  test('a report opens the mail app as a mailto link to the inbox', () async {
    final links = FixedLinks();
    final outcome = await MailReportSender(
      address: 'reports@example.org',
      links: links,
    ).send(report);
    expect(outcome, isA<ReportInMailApp>());
    expect(
      links.asked.single,
      reportMailto('reports@example.org', report).toString(),
    );
  });

  test('no mail app, or no address yet, fails and says which', () async {
    expect(
      await MailReportSender(
        address: 'reports@example.org',
        links: FixedLinks(opens: false),
      ).send(report),
      isA<ReportFailed>().having(
        (f) => f.reason,
        'reason',
        ReportFailure.noMailApp,
      ),
    );
    final links = FixedLinks();
    expect(
      await MailReportSender(address: '', links: links).send(report),
      isA<ReportFailed>().having(
        (f) => f.reason,
        'reason',
        ReportFailure.notSetUp,
      ),
    );
    expect(links.asked, isEmpty);
  });
}
