import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/feedback/report.dart';

void main() {
  const report = Report(
    kind: ReportKind.feature,
    title: 'Dark mode for cards',
    details: 'Please',
    context: <String, String>{'App': 'fluenough 0.2.0', 'Screen': '/deck'},
  );

  test('a report mail is subjected for the Action, which reads only those', () {
    expect(report.subject, '[Fluenough] Feature: Dark mode for cards');
    expect(report.subject, startsWith(reportSubjectPrefix));
    for (final kind in ReportKind.values) {
      expect(kind.label, isNotEmpty);
    }
  });

  test('its body is the details, then what the app added, a line each', () {
    expect(report.body, 'Please\n\n---\nApp: fluenough 0.2.0\nScreen: /deck');
    expect(
      const Report(
        kind: ReportKind.bug,
        title: 't',
        context: <String, String>{'App': 'x'},
      ).body,
      '---\nApp: x',
    );
  });

  test('a GitHub issue is the prompt, room to write, then the context', () {
    expect(
      issueBody('What happened?', <String, String>{'Screen': '/'}),
      'What happened?\n\n\n---\nScreen: /',
    );
  });

  test('a mail link is addressed, its spaces written %20, not +', () {
    final url = reportMailto('reports@example.org', report);
    expect(url.scheme, 'mailto');
    expect(url.path, 'reports@example.org');
    expect(url.queryParameters['subject'], report.subject);
    expect(url.queryParameters['body'], report.body);
    expect(url.toString(), isNot(contains('+')));
    expect(url.toString(), contains('Dark%20mode'));
  });

  test('a request always carries its screen and what it showed', () {
    expect(const ReportRequest(screen: '/deck', detail: 'x').always, {
      'Screen': '/deck',
      'Showing': 'x',
    });
    expect(const ReportRequest(screen: '/').always, {'Screen': '/'});
  });

  test('a build with nowhere to send reports says so', () async {
    expect(
      await const NullReportSender().send(
        const Report(kind: ReportKind.bug, title: 't'),
      ),
      isA<ReportFailed>().having(
        (f) => f.reason,
        'reason',
        ReportFailure.notSetUp,
      ),
    );
  });
}
