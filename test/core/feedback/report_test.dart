import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/feedback/report.dart';

final Uint8List png = Uint8List.fromList(<int>[0x89, 0x50, 0x4e, 0x47]);

const Report plain = Report(
  kind: ReportKind.feature,
  title: 'Dark mode for cards',
  details: 'Please',
  context: <String, String>{'App': 'fluenough 0.2.0'},
);

void main() {
  test('a report is sent as the relay reads it, the screenshot in base64', () {
    expect(plain.toJson(), <String, Object>{
      'kind': 'feature',
      'title': 'Dark mode for cards',
      'details': 'Please',
      'context': <String, String>{'App': 'fluenough 0.2.0'},
    });
    final withShot = Report(kind: ReportKind.bug, title: 't', screenshot: png);
    expect(withShot.toJson()['screenshot'], base64Encode(png));
  });

  test('only a 201 is sent; its address is the issue', () {
    expect(
      RelayReportSender.outcomeOf(201, '{"url":"https://x/1","number":1}'),
      isA<ReportSent>().having((s) => s.issueUrl, 'url', 'https://x/1'),
    );
    for (final status in <int>[400, 429, 502]) {
      expect(
        RelayReportSender.outcomeOf(status, '{"error":"no"}'),
        isA<ReportFailed>().having(
          (f) => f.reason,
          'reason',
          ReportFailure.refused,
        ),
      );
    }
  });

  test('a build with no relay cannot send', () async {
    expect(
      await const NullReportSender().send(plain),
      isA<ReportFailed>().having(
        (f) => f.reason,
        'reason',
        ReportFailure.notSetUp,
      ),
    );
  });

  test('the relay is posted JSON with the user agent', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    String? agent;
    Object? body;
    server.listen((request) async {
      agent = request.headers.value(HttpHeaders.userAgentHeader);
      body = jsonDecode(await utf8.decodeStream(request));
      request.response
        ..statusCode = 201
        ..write('{"url":"https://github.com/o/r/issues/7"}');
      await request.response.close();
    });
    final sender = RelayReportSender(
      Uri.parse('http://127.0.0.1:${server.port}/'),
      userAgent: 'fluenough/0.2.0',
    );
    final outcome = await sender.send(plain);
    expect(
      outcome,
      isA<ReportSent>().having(
        (s) => s.issueUrl,
        'url',
        'https://github.com/o/r/issues/7',
      ),
    );
    expect(agent, 'fluenough/0.2.0');
    expect(body, plain.toJson());
  });

  test('a relay that cannot be reached is offline', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);
    final sender = RelayReportSender(
      Uri.parse('http://127.0.0.1:$port/'),
      userAgent: 'fluenough/0.2.0',
      timeout: const Duration(seconds: 5),
    );
    expect(
      await sender.send(plain),
      isA<ReportFailed>().having(
        (f) => f.reason,
        'reason',
        ReportFailure.offline,
      ),
    );
  });
}
