/// What a report is about. [label] starts its mail's subject, which the
/// mail-to-issue Action reads to label the issue (ADR-0021).
enum ReportKind {
  bug('Bug'),
  feature('Feature'),
  suggestion('Suggestion');

  const ReportKind(this.label);

  /// English, whatever the app's language: the Action and the issue read it.
  final String label;
}

/// What a report button hands on: the screen it was pressed on, and the
/// device's details, which go only if the reporter agrees.
class ReportRequest {
  const ReportRequest({
    required this.screen,
    this.detail,
    this.device = const <String, String>{},
  });

  /// The screen's route name, `/deck`, or `/` for the tabs.
  final String screen;

  /// What the screen showed, such as a card's id and deck.
  final String? detail;

  /// The device's details, by name, as [contextLines] shows them.
  final Map<String, String> device;

  /// What every report from this screen carries: the screen, and what it
  /// showed.
  Map<String, String> get always => <String, String>{
    'Screen': screen,
    'Showing': ?detail,
  };
}

/// [context] as a report shows it: one `Name: value` line each.
String contextLines(Map<String, String> context) => <String>[
  for (final MapEntry(:key, :value) in context.entries) '$key: $value',
].join('\n');

/// Every report mail's subject starts with this; the Action that files
/// issues reads no other mail (#160).
const String reportSubjectPrefix = '[Fluenough]';

/// A bug, a feature asked for, or a suggestion, from the screen it was
/// raised on (ADR-0021). Sent as a mail, text only; it becomes a public
/// GitHub issue.
class Report {
  const Report({
    required this.kind,
    required this.title,
    this.details = '',
    this.context = const <String, String>{},
  });

  final ReportKind kind;

  /// A line, which becomes the issue's title.
  final String title;

  /// What happened, or what would help. May be empty.
  final String details;

  /// What the app adds, by name: the screen, and the device's details if
  /// the reporter agreed to send them.
  final Map<String, String> context;

  /// `[Fluenough] Bug: The card shows twice`.
  String get subject => '$reportSubjectPrefix ${kind.label}: $title';

  /// The details, then what the app added, as [contextLines].
  String get body => <String>[
    if (details.isNotEmpty) ...<String>[details, ''],
    '---',
    contextLines(context),
  ].join('\n');
}

/// A mailto link (RFC 6068) to [address], with [report]'s subject and
/// body filled in. Spaces are written `%20`: some mail apps show the `+` of
/// form encoding as it is.
Uri reportMailto(String address, Report report) => Uri.parse(
  'mailto:$address'
  '?subject=${Uri.encodeComponent(report.subject)}'
  '&body=${Uri.encodeComponent(report.body)}',
);

/// The body of a new GitHub issue, opened while mail reports are not set
/// up: [prompt], room to write, then what the app adds, as [Report.body].
String issueBody(String prompt, Map<String, String> context) =>
    <String>[prompt, '', '', '---', contextLines(context)].join('\n');

/// Why a report did not reach a mail app.
enum ReportFailure {
  /// This build has no address to send reports to.
  notSetUp,

  /// The phone has no mail app that can take it.
  noMailApp,
}

/// What became of a report.
sealed class ReportOutcome {
  const ReportOutcome();
}

/// The reporter's mail app has the report, ready to send. Whether they send
/// it is theirs to do.
final class ReportInMailApp extends ReportOutcome {
  const ReportInMailApp();
}

final class ReportFailed extends ReportOutcome {
  const ReportFailed(this.reason);

  final ReportFailure reason;
}

/// Where reports go. An interface so that tests need no mail app.
abstract interface class ReportSender {
  Future<ReportOutcome> send(Report report);
}

/// A build with nowhere to send reports.
class NullReportSender implements ReportSender {
  const NullReportSender();

  @override
  Future<ReportOutcome> send(Report report) async =>
      const ReportFailed(ReportFailure.notSetUp);
}
