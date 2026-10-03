import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/feedback/report.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/ui/widgets/report_button.dart';

import '../../support/harness.dart';

/// A 1×1 PNG, so that the preview has something real to decode.
final Uint8List png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Records what it is sent, and answers with [outcome].
class FakeReportSender implements ReportSender {
  FakeReportSender([this.outcome = const ReportSent()]);

  ReportOutcome outcome;
  final List<Report> sent = <Report>[];

  @override
  Future<ReportOutcome> send(Report report) async {
    sent.add(report);
    return outcome;
  }
}

Future<void> tapInList(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the bug icon opens a report with a picture of its screen', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const DecksPage());
    final l10n = l10nOf(tester);
    // The picture is taken by the engine, outside the test's fake clock.
    await tester.runAsync(() async {
      await tester.tap(find.byType(ReportButton));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final page = tester.widget<ReportPage>(find.byType(ReportPage));
    expect(page.request.detail, l10n.decksTitle);
    expect(page.request.screen, '/');
    final shot = page.request.screenshot!;
    expect(shot.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47]);
    expect(find.text(l10n.reportTitle), findsOneWidget);
  });

  testWidgets('a report needs a title, then is sent with its screen, what it '
      'showed and the screenshot', (tester) async {
    usePhone(tester);
    final reports = FakeReportSender();
    await pumpScreen(
      tester,
      ReportPage(
        request: ReportRequest(
          screen: '/deck',
          detail: 'hi-en-market',
          screenshot: png,
        ),
      ),
      state: AppState.test(reports: reports),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reportPublic), findsOneWidget);

    await tapInList(tester, find.text(l10n.reportSend));
    expect(find.text(l10n.reportTitleMissing), findsOneWidget);
    expect(reports.sent, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextField, l10n.reportTitleLabel),
      '  The card shows twice ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reportDetailsLabel),
      'After Check',
    );
    await tapInList(tester, find.text(l10n.reportSend));
    final report = reports.sent.single;
    expect(report.kind, ReportKind.bug);
    expect(report.title, 'The card shows twice');
    expect(report.details, 'After Check');
    expect(report.screenshot, png);
    expect(report.context['Screen'], '/deck');
    expect(report.context['Showing'], 'hi-en-market');
    expect(report.context['App'], startsWith('fluenough '));
    expect(report.context['Learning'], isNotEmpty);
    expect(find.text(l10n.reportSent), findsOneWidget);
  });

  testWidgets('the kind is chosen, and the screenshot can be left out', (
    tester,
  ) async {
    usePhone(tester);
    final reports = FakeReportSender();
    await pumpScreen(
      tester,
      ReportPage(
        request: ReportRequest(screen: '/', screenshot: png),
      ),
      state: AppState.test(reports: reports),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.reportKindFeature));
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reportTitleLabel),
      'Dark cards',
    );
    expect(find.bySemanticsLabel(l10n.reportScreenshotPreview), findsOneWidget);
    await tapInList(tester, find.text(l10n.reportScreenshot));
    expect(find.bySemanticsLabel(l10n.reportScreenshotPreview), findsNothing);
    await tapInList(tester, find.text(l10n.reportSend));
    final report = reports.sent.single;
    expect(report.kind, ReportKind.feature);
    expect(report.screenshot, isNull);
    expect(report.context.containsKey('Showing'), isFalse);
  });

  testWidgets('a failure says why, and Send works again', (tester) async {
    usePhone(tester);
    final reports = FakeReportSender(const ReportFailed(ReportFailure.offline));
    await pumpScreen(
      tester,
      const ReportPage(request: ReportRequest(screen: '/')),
      state: AppState.test(reports: reports),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reportScreenshot), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reportTitleLabel),
      'Crash',
    );
    await tapInList(tester, find.text(l10n.reportSend));
    expect(find.text(l10n.reportOffline), findsOneWidget);
    expect(find.text(l10n.reportSent), findsNothing);

    reports.outcome = const ReportSent();
    await tapInList(tester, find.text(l10n.reportSend));
    expect(reports.sent, hasLength(2));
    expect(find.text(l10n.reportOffline), findsNothing);
  });

  testWidgets('a build with no relay says it cannot send', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const ReportPage(request: ReportRequest(screen: '/')),
    );
    final l10n = l10nOf(tester);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reportTitleLabel),
      'Crash',
    );
    await tapInList(tester, find.text(l10n.reportSend));
    expect(find.text(l10n.reportNotSetUp), findsOneWidget);
  });
}
