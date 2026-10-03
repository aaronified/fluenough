import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/core/feedback/report.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/inspect_page.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/ui/widgets/report_button.dart';

import '../../support/harness.dart';

/// A 1×1 PNG, so that the preview has something real to decode.
final Uint8List png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Records what it is sent, and answers with [outcome].
class FakeReportSender implements ReportSender {
  FakeReportSender([this.outcome = const ReportInMailApp()]);

  ReportOutcome outcome;
  final List<Report> sent = <Report>[];

  @override
  Future<ReportOutcome> send(Report report) async {
    sent.add(report);
    return outcome;
  }
}

/// Mail reports on, as once the Gmail exists (#160).
const FeatureRegistry withMail = FeatureRegistry.only(<Feature>{
  ...Feature.available,
  Feature.feedbackMail,
});

/// The body GitHub was asked to fill in.
String issueBodyOf(String url) => Uri.parse(url).queryParameters['body']!;

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
  test('mail reports are incoming until the Gmail exists (#160)', () {
    expect(Feature.available, isNot(contains(Feature.feedbackMail)));
    expect(AppLinks.feedbackEmail, isEmpty);
  });

  testWidgets('while mail is incoming, the bug icon opens a new GitHub issue '
      'with the screen and the app filled in', (tester) async {
    usePhone(tester);
    final links = FixedLinks();
    await pumpScreen(
      tester,
      const DecksPage(),
      state: AppState.test(links: links),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.byType(ReportButton));
    await tester.pumpAndSettle();
    expect(find.byType(ReportPage), findsNothing);
    final url = links.asked.single;
    expect(
      url,
      startsWith('https://github.com/aaronified/fluenough/issues/new'),
    );
    final body = issueBodyOf(url);
    expect(body, startsWith(l10n.reportIssuePrompt));
    expect(body, contains('Screen: /'));
    expect(body, contains('Showing: ${l10n.decksTitle}'));
    expect(body, contains('App: fluenough '));
  });

  testWidgets('a card in Inspect is reported with its id and deck', (
    tester,
  ) async {
    usePhone(tester);
    final links = FixedLinks();
    final state = await pumpScreen(
      tester,
      const InspectPage(deckId: 'hi-en-market'),
      state: AppState.test(links: links),
    );
    final l10n = l10nOf(tester);
    final card = state.deckById('hi-en-market')!.cards.first;
    await tester.tap(find.byTooltip(l10n.inspectReport).first);
    await tester.pumpAndSettle();
    expect(
      issueBodyOf(links.asked.single),
      contains('Showing: ${card.id} in hi-en-market'),
    );
  });

  testWidgets('if GitHub cannot be opened, the link is copied', (tester) async {
    usePhone(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpScreen(
      tester,
      const DecksPage(),
      state: AppState.test(links: FixedLinks(opens: false)),
    );
    await tester.tap(find.byType(ReportButton));
    await tester.pumpAndSettle();
    expect(find.text(l10nOf(tester).reportLinkCopied), findsOneWidget);
    expect(copied, startsWith('https://github.com/aaronified/fluenough/'));
  });

  testWidgets('once mail is on, the bug icon opens a report with a picture '
      'of its screen, which is not attached until added', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const DecksPage(),
      state: AppState.test(features: withMail),
    );
    final l10n = l10nOf(tester);
    // The picture is taken by the engine, outside the test's fake clock.
    await tester.runAsync(() async {
      await tester.tap(find.byType(ReportButton));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final page = tester.widget<ReportPage>(find.byType(ReportPage));
    expect(page.request.detail, l10n.decksTitle);
    expect(page.request.screenshot!.sublist(0, 4), <int>[
      0x89,
      0x50,
      0x4e,
      0x47,
    ]);
    expect(find.text(l10n.reportAddScreenshot), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.reportScreenshotPreview), findsNothing);
  });

  testWidgets('a report needs a title, then goes to the mail app with its '
      'screen, what it showed, and the screenshot once added', (tester) async {
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
      state: AppState.test(reports: reports, features: withMail),
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
    await tapInList(tester, find.text(l10n.reportAddScreenshot));
    expect(find.bySemanticsLabel(l10n.reportScreenshotPreview), findsOneWidget);
    await tapInList(tester, find.text(l10n.reportSend));
    final report = reports.sent.single;
    expect(report.kind, ReportKind.bug);
    expect(report.subject, '[Fluenough] Bug: The card shows twice');
    expect(report.details, 'After Check');
    expect(report.screenshot, png);
    expect(report.context['Screen'], '/deck');
    expect(report.context['Showing'], 'hi-en-market');
    expect(report.context['App'], startsWith('fluenough '));
    expect(find.text(l10n.reportInMailApp), findsOneWidget);
  });

  testWidgets('the kind is chosen, and a screenshot added can be removed', (
    tester,
  ) async {
    usePhone(tester);
    final reports = FakeReportSender();
    await pumpScreen(
      tester,
      ReportPage(
        request: ReportRequest(screen: '/', screenshot: png),
      ),
      state: AppState.test(reports: reports, features: withMail),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.reportKindFeature));
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reportTitleLabel),
      'Dark cards',
    );
    await tapInList(tester, find.text(l10n.reportAddScreenshot));
    await tapInList(tester, find.text(l10n.reportRemoveScreenshot));
    expect(find.bySemanticsLabel(l10n.reportScreenshotPreview), findsNothing);
    await tapInList(tester, find.text(l10n.reportSend));
    final report = reports.sent.single;
    expect(report.kind, ReportKind.feature);
    expect(report.screenshot, isNull);
    expect(report.context.containsKey('Showing'), isFalse);
  });

  testWidgets('no mail app, or no address, says why; Send works again', (
    tester,
  ) async {
    usePhone(tester);
    final reports = FakeReportSender(
      const ReportFailed(ReportFailure.noMailApp),
    );
    await pumpScreen(
      tester,
      const ReportPage(request: ReportRequest(screen: '/')),
      state: AppState.test(reports: reports, features: withMail),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reportAddScreenshot), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reportTitleLabel),
      'Crash',
    );
    await tapInList(tester, find.text(l10n.reportSend));
    expect(find.text(l10n.reportNoMailApp), findsOneWidget);

    reports.outcome = const ReportFailed(ReportFailure.notSetUp);
    await tapInList(tester, find.text(l10n.reportSend));
    expect(reports.sent, hasLength(2));
    expect(find.text(l10n.reportNotSetUp), findsOneWidget);
  });
}
