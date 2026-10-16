import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_log.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/report_mail.dart';
import 'package:fluenough/core/feedback/report.dart';
import 'package:fluenough/core/logs/log_entry.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/features/settings/app_log_page.dart';

import '../../support/harness.dart';
import '../settings/support.dart';

/// Records what it is sent; its mail app always takes it.
class _Sender implements ReportSender {
  final List<Report> sent = <Report>[];

  @override
  Future<ReportOutcome> send(Report report) async {
    sent.add(report);
    return const ReportInMailApp();
  }
}

const Map<String, String> _device = <String, String>{
  'App': 'fluenough 0.2.0',
  'System': 'Android 14 (API 34)',
};

/// The report page over a log holding [lines] events, sending to
/// [reports].
Future<AppLog> _pump(
  WidgetTester tester, {
  required ReportSender reports,
  List<String> lines = const <String>[
    'Opened /deck',
    'Decks loaded: 40',
    'Opened /drill',
    'Opened /summary',
  ],
  FeatureRegistry features = const FeatureRegistry.shipped(),
}) async {
  usePhone(tester);
  final log = AppLog(clock: () => DateTime.utc(2026, 10, 9, 12));
  await pumpScreen(
    tester,
    const ReportPage(
      request: ReportRequest(screen: '/deck', device: _device),
    ),
    state: AppState.test(reports: reports, log: log, features: features),
  );
  await log.clear();
  lines.forEach(log.event);
  await tester.enterText(
    find.widgetWithText(TextField, l10nOf(tester).reportTitleLabel),
    'It froze',
  );
  await tester.pumpAndSettle();
  return log;
}

CheckboxListTile _box(WidgetTester tester, String title) => tester
    .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, title));

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Sends the report, titled "It froze" by [_pump].
Future<void> _send(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  await _scrollTo(tester, find.text(l10n.reportSend));
  await tester.tap(find.text(l10n.reportSend));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the log box is beside the device box, unticked like it, and '
      'shows what would be sent', (tester) async {
    final log = await _pump(tester, reports: _Sender());
    final l10n = l10nOf(tester);
    await _scrollTo(tester, find.text(l10n.reportLog));
    expect(_box(tester, l10n.reportDeviceInfo).value, isFalse);
    expect(_box(tester, l10n.reportLog).value, isFalse);
    // Under the device box, which comes first.
    expect(
      tester.getTopLeft(find.text(l10n.reportDeviceInfo)).dy,
      lessThan(tester.getTopLeft(find.text(l10n.reportLog)).dy),
    );
    expect(find.text(l10n.reportLogSummary(4)), findsOneWidget);
    // The newest lines, as they would be sent.
    final newest = log.entries.sublist(1).map((e) => e.line).join('\n');
    expect(find.text(newest), findsOneWidget);
  });

  testWidgets('unticked, no file goes', (tester) async {
    final reports = _Sender();
    await _pump(tester, reports: reports);
    await _send(tester);
    expect(reports.sent.single.files, isEmpty);
    expect(reports.sent.single.body, isNot(contains('Attached')));
  });

  testWidgets('ticked, the whole log goes as a file, and the mail says so', (
    tester,
  ) async {
    final reports = _Sender();
    final log = await _pump(tester, reports: reports);
    final text = log.text;
    final l10n = l10nOf(tester);
    await _scrollTo(tester, find.text(l10n.reportLog));
    await tester.tap(find.text(l10n.reportLog));
    await tester.pumpAndSettle();
    expect(_box(tester, l10n.reportLog).value, isTrue);
    await _send(tester);
    final file = reports.sent.single.files.single;
    expect(file.name, appLogFileName);
    expect(file.text, text);
    expect(file.mimeType, 'text/plain');
    expect(
      reports.sent.single.body,
      contains('Attached: fluenough-app-log.txt'),
    );
    expect(find.text(l10n.reportInMailApp), findsOneWidget);
  });

  testWidgets('ticked, the log goes through the phone\'s share to the inbox', (
    tester,
  ) async {
    final share = FixedMailShare();
    final links = FixedLinks();
    final log = await _pump(
      tester,
      reports: MailReportSender(
        address: AppLinks.feedbackEmail,
        links: links,
        share: share,
      ),
    );
    final l10n = l10nOf(tester);
    await _scrollTo(tester, find.text(l10n.reportLog));
    await tester.tap(find.text(l10n.reportLog));
    await _send(tester);
    final mail = share.shared.single;
    expect(mail.to, <String>['fluenough@gmail.com']);
    expect(mail.subject, '[Fluenough] Bug: It froze');
    expect(mail.files.single.name, appLogFileName);
    expect(links.asked, isEmpty);
    expect(find.text(l10n.reportInMailApp), findsOneWidget);
    expect(
      log.entries.last.message,
      'Report in mail app (Bug), the log attached',
    );
  });

  testWidgets('if the share fails, the mail app opens without the log, and '
      'the reporter is told', (tester) async {
    final links = FixedLinks();
    final log = await _pump(
      tester,
      reports: MailReportSender(
        address: AppLinks.feedbackEmail,
        links: links,
        share: FixedMailShare(shares: false),
      ),
    );
    final l10n = l10nOf(tester);
    await _scrollTo(tester, find.text(l10n.reportLog));
    await tester.tap(find.text(l10n.reportLog));
    await _send(tester);
    final url = Uri.parse(links.asked.single);
    expect(url.scheme, 'mailto');
    expect(url.queryParameters['body'], isNot(contains('Attached')));
    expect(find.text(l10n.reportInMailAppNoLog), findsOneWidget);
    expect(find.text(l10n.reportInMailApp), findsNothing);
    expect(log.entries.last.level, LogLevel.warning);
  });

  testWidgets('an empty log cannot be ticked, and says so', (tester) async {
    final reports = _Sender();
    await _pump(tester, reports: reports, lines: const <String>[]);
    final l10n = l10nOf(tester);
    await _scrollTo(tester, find.text(l10n.reportLog));
    expect(_box(tester, l10n.reportLog).onChanged, isNull);
    expect(find.text(l10n.reportLogEmpty), findsOneWidget);
    expect(find.text(l10n.reportLogSeeAll), findsNothing);
  });

  testWidgets('"See the whole log" opens it', (tester) async {
    await _pump(tester, reports: _Sender());
    final l10n = l10nOf(tester);
    await _scrollTo(tester, find.text(l10n.reportLogSeeAll));
    await tester.tap(find.text(l10n.reportLogSeeAll));
    await tester.pumpAndSettle();
    expect(find.byType(AppLogPage), findsOneWidget);
  });

  testWidgets('at twice the text size, the kinds and both boxes lay out '
      'without overflowing', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, reports: _Sender());
    await scrollThrough(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the log incoming, there is no box', (tester) async {
    await _pump(
      tester,
      reports: _Sender(),
      features: FeatureRegistry.only(
        Feature.available.difference(<Feature>{Feature.logs}),
      ),
    );
    await _scrollTo(tester, find.text(l10nOf(tester).reportSend));
    expect(find.text(l10nOf(tester).reportLog), findsNothing);
  });
}
