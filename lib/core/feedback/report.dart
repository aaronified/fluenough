import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// What a report is about. Its [name] is what the relay is sent, and the
/// relay labels the issue by it (ADR-0021).
enum ReportKind { bug, feature, suggestion }

/// A bug, a feature asked for, or a suggestion, from the screen it was
/// raised on (ADR-0021). Becomes a public GitHub issue.
class Report {
  const Report({
    required this.kind,
    required this.title,
    this.details = '',
    this.context = const <String, String>{},
    this.screenshot,
  });

  final ReportKind kind;

  /// A line, which becomes the issue's title.
  final String title;

  /// What happened, or what would help. May be empty.
  final String details;

  /// What the app adds, such as its version and the screen, by name.
  final Map<String, String> context;

  /// The screen the report was raised on, as PNG, if the learner kept it.
  final Uint8List? screenshot;

  /// The body sent to the relay.
  Map<String, Object> toJson() => <String, Object>{
    'kind': kind.name,
    'title': title,
    'details': details,
    'context': context,
    if (screenshot case final png?) 'screenshot': base64Encode(png),
  };
}

/// Why a report was not sent.
enum ReportFailure {
  /// This build has nowhere to send reports: no relay was given to it.
  notSetUp,

  /// The relay was not reached, or did not answer in time.
  offline,

  /// The relay answered, and refused the report or could not file it.
  refused,
}

/// What became of a report: an issue, or why not.
sealed class ReportOutcome {
  const ReportOutcome();
}

final class ReportSent extends ReportOutcome {
  const ReportSent({this.issueUrl});

  /// The issue it became, when the relay says.
  final String? issueUrl;
}

final class ReportFailed extends ReportOutcome {
  const ReportFailed(this.reason);

  final ReportFailure reason;
}

/// Where reports go. An interface so that tests need no network.
abstract interface class ReportSender {
  Future<ReportOutcome> send(Report report);
}

/// A build with no relay: every report fails as [ReportFailure.notSetUp].
class NullReportSender implements ReportSender {
  const NullReportSender();

  @override
  Future<ReportOutcome> send(Report report) async =>
      const ReportFailed(ReportFailure.notSetUp);
}

/// Sends a report to the relay at [endpoint] (`tools/report-relay`), which
/// holds the GitHub token and files the issue (ADR-0021). The app holds no
/// token. Through dart:io's own client, like the update check.
class RelayReportSender implements ReportSender {
  RelayReportSender(
    this.endpoint, {
    required this.userAgent,
    this.timeout = const Duration(seconds: 30),
  });

  final Uri endpoint;

  /// `fluenough/0.2.0`.
  final String userAgent;

  /// How long sending may take, from connecting to the last byte.
  final Duration timeout;

  @override
  Future<ReportOutcome> send(Report report) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await _post(client, report).timeout(timeout);
    } on FormatException {
      return const ReportFailed(ReportFailure.refused);
    } catch (_) {
      return const ReportFailed(ReportFailure.offline);
    } finally {
      client.close(force: true);
    }
  }

  Future<ReportOutcome> _post(HttpClient client, Report report) async {
    final request = await client.postUrl(endpoint);
    request.headers
      ..set(HttpHeaders.userAgentHeader, userAgent)
      ..contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode(report.toJson())));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return outcomeOf(response.statusCode, body);
  }

  /// What the relay's answer means: 201 with the issue's address, or a
  /// refusal.
  static ReportOutcome outcomeOf(int status, String body) {
    if (status != 201) return const ReportFailed(ReportFailure.refused);
    final reply = jsonDecode(body);
    final url = reply is Map ? reply['url'] : null;
    return ReportSent(issueUrl: url is String ? url : null);
  }
}

/// What the bug icon hands the report: the screen it was tapped on.
class ReportRequest {
  const ReportRequest({required this.screen, this.detail, this.screenshot});

  /// The screen's route name, `/deck`, or `/` for the tabs.
  final String screen;

  /// What the screen showed, such as a card's id.
  final String? detail;

  /// The screen as it was, as PNG, or null if no picture could be taken.
  final Uint8List? screenshot;
}
