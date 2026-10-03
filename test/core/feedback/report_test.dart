import 'dart:typed_data';

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

  test('a build with nowhere to send reports says so', () async {
    expect(
      await const NullReportSender().send(
        Report(kind: ReportKind.bug, title: 't', screenshot: Uint8List(1)),
      ),
      isA<ReportFailed>().having(
        (f) => f.reason,
        'reason',
        ReportFailure.notSetUp,
      ),
    );
  });
}
