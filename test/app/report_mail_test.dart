import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/report_mail.dart';
import 'package:fluenough/core/feedback/report.dart';

void main() {
  const report = Report(kind: ReportKind.bug, title: 'The card shows twice');
  const withLog = Report(
    kind: ReportKind.support,
    title: 'No sound',
    files: <AttachedFile>[
      AttachedFile(name: 'fluenough-app-log.txt', text: 'a line'),
    ],
  );

  test('a report opens the mail app as a mailto link to the inbox', () async {
    final links = FixedLinks();
    final share = FixedMailShare();
    final outcome = await MailReportSender(
      address: 'reports@example.org',
      links: links,
      share: share,
    ).send(report);
    expect(
      outcome,
      isA<ReportInMailApp>().having((o) => o.filesLeftOut, 'left out', false),
    );
    expect(
      links.asked.single,
      reportMailto('reports@example.org', report).toString(),
    );
    expect(share.shared, isEmpty, reason: 'nothing to attach');
  });

  test('a report with the log goes through the share, addressed, with its '
      'subject, body and file', () async {
    final links = FixedLinks();
    final share = FixedMailShare();
    final outcome = await MailReportSender(
      address: 'reports@example.org',
      links: links,
      share: share,
    ).send(withLog);
    expect(
      outcome,
      isA<ReportInMailApp>().having((o) => o.filesLeftOut, 'left out', false),
    );
    final mail = share.shared.single;
    expect(mail.to, <String>['reports@example.org']);
    expect(mail.subject, '[Fluenough] Support: No sound');
    expect(mail.body, withLog.body);
    expect(mail.body, contains('Attached: fluenough-app-log.txt'));
    expect(mail.files.single.text, 'a line');
    expect(links.asked, isEmpty);
  });

  test('if the share fails, or throws, the report goes as a link without '
      'the log, and says the log was left out', () async {
    for (final share in <FixedMailShare>[
      FixedMailShare(shares: false),
      FixedMailShare(error: PlatformException(code: 'failed')),
      FixedMailShare(error: MissingPluginException()),
      FixedMailShare(error: StateError('not an Exception')),
    ]) {
      final links = FixedLinks();
      final outcome = await MailReportSender(
        address: 'reports@example.org',
        links: links,
        share: share,
      ).send(withLog);
      expect(
        outcome,
        isA<ReportInMailApp>().having((o) => o.filesLeftOut, 'left out', true),
        reason: '${share.error}',
      );
      final url = links.asked.single;
      expect(
        url,
        reportMailto('reports@example.org', withLog.withoutFiles()).toString(),
      );
      expect(
        Uri.parse(url).queryParameters['body'],
        isNot(contains('Attached')),
      );
    }
  });

  test('if neither the share nor a mail app can take it, it fails', () async {
    expect(
      await MailReportSender(
        address: 'reports@example.org',
        links: FixedLinks(opens: false),
        share: FixedMailShare(shares: false),
      ).send(withLog),
      isA<ReportFailed>().having(
        (f) => f.reason,
        'reason',
        ReportFailure.noMailApp,
      ),
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
    final share = FixedMailShare();
    expect(
      await MailReportSender(
        address: '',
        links: links,
        share: share,
      ).send(withLog),
      isA<ReportFailed>().having(
        (f) => f.reason,
        'reason',
        ReportFailure.notSetUp,
      ),
    );
    expect(links.asked, isEmpty);
    expect(share.shared, isEmpty);
  });
}
