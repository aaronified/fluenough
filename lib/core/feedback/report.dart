/// What a report is (ADR-0021): a question for support, a bug, or feedback,
/// which takes in feature requests. [label] starts its mail's subject,
/// which the mail-to-issue Action reads.
enum ReportKind {
  support('Support', public: false),
  bug('Bug', public: true),
  feedback('Feedback', public: true);

  const ReportKind(this.label, {required this.public});

  /// English, whatever the app's language: the Action and the issue read it.
  final String label;

  /// Whether the mail becomes a public GitHub issue. A support mail stays
  /// private in the Fluenough inbox: `tools/mail_to_issues.py` skips it.
  final bool public;
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

/// A file a report carries, such as the app log, sent only if the reporter
/// agrees. A mailto link cannot carry one; the phone's share can
/// (ADR-0021).
class AttachedFile {
  const AttachedFile({
    required this.name,
    required this.text,
    this.mimeType = 'text/plain',
  });

  /// The file's name, without a folder: `fluenough-app-log.txt`.
  final String name;

  final String text;

  final String mimeType;
}

/// A question for support, a bug or feedback, from the screen it was raised
/// on (ADR-0021). Sent as a mail, text only. Bugs and feedback become
/// public GitHub issues; support stays private in the inbox.
class Report {
  const Report({
    required this.kind,
    required this.title,
    this.details = '',
    this.prompts = const <String>[],
    this.context = const <String, String>{},
    this.files = const <AttachedFile>[],
  });

  final ReportKind kind;

  /// A line, which ends the mail's subject and becomes the issue's title.
  final String title;

  /// What happened, or what would help. May be empty.
  final String details;

  /// The kind's own questions, in the reporter's language, such as "What
  /// did you expect instead?": set under the details with room to answer
  /// them in the mail app, or to delete them.
  final List<String> prompts;

  /// What the app adds, by name: the screen, and the device's details if
  /// the reporter agreed to send them.
  final Map<String, String> context;

  /// Files to attach, such as the app log, if the reporter agreed.
  final List<AttachedFile> files;

  /// `[Fluenough] Bug: The card shows twice`.
  String get subject => '$reportSubjectPrefix ${kind.label}: $title';

  /// The details, the kind's questions, then what the app added, as
  /// [contextLines]: the kind first, which the Action reads as well as the
  /// subject, and the names of the files attached last.
  String get body => <String>[
    if (details.isNotEmpty) ...<String>[details, ''],
    for (final prompt in prompts) ...<String>[prompt, '', ''],
    '---',
    contextLines(<String, String>{
      'Kind': kind.label,
      ...context,
      if (files.isNotEmpty)
        'Attached': <String>[for (final file in files) file.name].join(', '),
    }),
  ].join('\n');

  /// This report without its files: for a mailto link, which cannot carry
  /// them.
  Report withoutFiles() => Report(
    kind: kind,
    title: title,
    details: details,
    prompts: prompts,
    context: context,
  );
}

/// A mailto link (RFC 6068) to [address], with [report]'s subject and
/// body filled in. Spaces are written `%20`: some mail apps show the `+` of
/// form encoding as it is. Files are left out: a link cannot carry them.
Uri reportMailto(String address, Report report) => Uri.parse(
  'mailto:$address'
  '?subject=${Uri.encodeComponent(report.subject)}'
  '&body=${Uri.encodeComponent(report.withoutFiles().body)}',
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
  const ReportInMailApp({this.filesLeftOut = false});

  /// Whether the report's files could not be attached, so that the mail
  /// app has the report without them.
  final bool filesLeftOut;
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
