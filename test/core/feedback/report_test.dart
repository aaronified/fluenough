import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/feedback/report.dart';

void main() {
  const report = Report(
    kind: ReportKind.feedback,
    title: 'Dark mode for cards',
    details: 'Please',
    context: <String, String>{'App': 'fluenough 0.2.0', 'Screen': '/deck'},
  );

  test('three kinds, in the order the owner named them; only support is '
      'private', () {
    expect(ReportKind.values, <ReportKind>[
      ReportKind.support,
      ReportKind.bug,
      ReportKind.feedback,
    ]);
    expect(
      <String>[for (final kind in ReportKind.values) kind.label],
      <String>['Support', 'Bug', 'Feedback'],
    );
    expect(
      <bool>[for (final kind in ReportKind.values) kind.public],
      <bool>[false, true, true],
    );
  });

  test('a report mail is subjected for the Action, which reads only those, '
      'each kind with its own subject', () {
    expect(report.subject, '[Fluenough] Feedback: Dark mode for cards');
    expect(report.subject, startsWith(reportSubjectPrefix));
    for (final (kind, subject) in <(ReportKind, String)>[
      (ReportKind.support, '[Fluenough] Support: x'),
      (ReportKind.bug, '[Fluenough] Bug: x'),
      (ReportKind.feedback, '[Fluenough] Feedback: x'),
    ]) {
      expect(Report(kind: kind, title: 'x').subject, subject);
    }
  });

  test('its body is the details, then what the app added, a line each, the '
      'kind first', () {
    expect(
      report.body,
      'Please\n\n---\nKind: Feedback\nApp: fluenough 0.2.0\nScreen: /deck',
    );
    expect(
      const Report(
        kind: ReportKind.bug,
        title: 't',
        context: <String, String>{'App': 'x'},
      ).body,
      '---\nKind: Bug\nApp: x',
    );
  });

  test("the kind's questions come under the details, with room to answer", () {
    expect(
      const Report(
        kind: ReportKind.bug,
        title: 't',
        details: 'It froze',
        prompts: <String>['Steps?', 'Expected?'],
      ).body,
      'It froze\n\nSteps?\n\n\nExpected?\n\n\n---\nKind: Bug',
    );
  });

  test('files are named last in the body, and left out of a mail link', () {
    const withLog = Report(
      kind: ReportKind.support,
      title: 't',
      files: <AttachedFile>[
        AttachedFile(name: 'fluenough-app-log.txt', text: 'line'),
      ],
    );
    expect(withLog.body, '---\nKind: Support\nAttached: fluenough-app-log.txt');
    expect(withLog.withoutFiles().files, isEmpty);
    expect(withLog.withoutFiles().body, '---\nKind: Support');
    expect(
      reportMailto('a@example.org', withLog).queryParameters['body'],
      '---\nKind: Support',
    );
    expect(withLog.files.single.mimeType, 'text/plain');
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
