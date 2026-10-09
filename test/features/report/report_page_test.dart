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

/// Mail reports on, as shipped since the Gmail exists (#160).
const FeatureRegistry withMail = FeatureRegistry.only(Feature.available);

/// Mail reports off: every report button opens GitHub instead.
final FeatureRegistry noMail = FeatureRegistry.only(
  Feature.available.difference(<Feature>{Feature.feedbackMail}),
);

/// What the device box adds, as the bug icon would hand it on.
const Map<String, String> device = <String, String>{
  'App': 'fluenough 0.2.0',
  'System': 'Android 14 (API 34)',
};

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
  test('mail reports ship, to the Fluenough Gmail; the app log is still '
      'incoming (#160, #162)', () {
    expect(Feature.available, contains(Feature.feedbackMail));
    expect(AppLinks.feedbackEmail, 'fluenough@gmail.com');
    expect(Feature.available, isNot(contains(Feature.logs)));
  });

  testWidgets('while mail is incoming, the bug icon asks first, with the '
      'device box unticked, then opens GitHub with only the screen', (
    tester,
  ) async {
    usePhone(tester);
    final links = FixedLinks();
    await pumpScreen(
      tester,
      const DecksPage(),
      state: AppState.test(links: links, features: noMail),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.byType(ReportButton));
    await tester.pumpAndSettle();
    expect(find.byType(ReportPage), findsNothing);
    expect(find.text(l10n.reportGitHubTitle), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    // The exact lines the box would add are shown before anything opens.
    expect(find.textContaining('App: fluenough '), findsOneWidget);
    expect(find.textContaining('Text scale: 1.00'), findsOneWidget);
    expect(links.asked, isEmpty);

    await tester.tap(find.text(l10n.reportOpenGitHub));
    await tester.pumpAndSettle();
    final url = links.asked.single;
    expect(
      url,
      startsWith('https://github.com/aaronified/fluenough/issues/new'),
    );
    final body = issueBodyOf(url);
    expect(body, startsWith(l10n.reportIssuePrompt));
    expect(body, endsWith('---\nScreen: /\nShowing: ${l10n.decksTitle}'));
  });

  testWidgets('ticked, the issue carries the device lines shown', (
    tester,
  ) async {
    usePhone(tester);
    final links = FixedLinks();
    await pumpScreen(
      tester,
      const DecksPage(),
      state: AppState.test(links: links, features: noMail),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.byType(ReportButton));
    await tester.pumpAndSettle();
    final shown = tester
        .widget<Text>(find.textContaining('App: fluenough '))
        .data!;
    await tester.tap(find.text(l10n.reportDeviceInfo));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reportOpenGitHub));
    await tester.pumpAndSettle();
    final body = issueBodyOf(links.asked.single);
    expect(body, contains('Showing: ${l10n.decksTitle}\n$shown'));
    for (final key in <String>[
      'App',
      'System',
      'Screen size',
      'Text scale',
      'App language',
      'Learning',
    ]) {
      expect(shown, contains('$key: '));
    }
  });

  testWidgets('dismissing the sheet opens nothing', (tester) async {
    usePhone(tester);
    final links = FixedLinks();
    await pumpScreen(
      tester,
      const DecksPage(),
      state: AppState.test(links: links, features: noMail),
    );
    await tester.tap(find.byType(ReportButton));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text(l10nOf(tester).reportGitHubTitle), findsNothing);
    expect(links.asked, isEmpty);
  });

  testWidgets('a card in Inspect is reported with its id and deck, from '
      'beside its id, unopened', (tester) async {
    usePhone(tester);
    final links = FixedLinks();
    final state = await pumpScreen(
      tester,
      const InspectPage(deckId: 'hi-en-market'),
      state: AppState.test(links: links, features: noMail),
    );
    final l10n = l10nOf(tester);
    final card = state.deckById('hi-en-market')!.cards.first;
    // On the row's id line, without opening the row.
    await tapInList(
      tester,
      find.descendant(
        of: find.widgetWithText(Row, l10n.inspectId(card.id)),
        matching: find.text(l10n.inspectReport),
      ),
    );
    await tester.tap(find.text(l10n.reportOpenGitHub));
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
      state: AppState.test(links: FixedLinks(opens: false), features: noMail),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.byType(ReportButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.reportOpenGitHub));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reportLinkCopied), findsOneWidget);
    expect(copied, startsWith('https://github.com/aaronified/fluenough/'));
  });

  testWidgets('once mail is on, the bug icon opens the report, with what '
      'its screen showed and the device lines', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const DecksPage(),
      state: AppState.test(features: withMail),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.byType(ReportButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reportGitHubTitle), findsNothing);
    final page = tester.widget<ReportPage>(find.byType(ReportPage));
    expect(page.request.screen, '/');
    expect(page.request.detail, l10n.decksTitle);
    expect(page.request.device['App'], startsWith('fluenough '));
  });

  testWidgets('a report needs a title, then goes to the mail app with its '
      'screen and what it showed, and no device lines unless ticked', (
    tester,
  ) async {
    usePhone(tester);
    final reports = FakeReportSender();
    await pumpScreen(
      tester,
      const ReportPage(
        request: ReportRequest(
          screen: '/deck',
          detail: 'hi-en-market',
          device: device,
        ),
      ),
      state: AppState.test(reports: reports, features: withMail),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reportPublic), findsOneWidget);
    expect(find.text(contextLines(device)), findsOneWidget);

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
    expect(report.subject, '[Fluenough] Bug: The card shows twice');
    expect(report.details, 'After Check');
    expect(report.context, <String, String>{
      'Screen': '/deck',
      'Showing': 'hi-en-market',
    });
    expect(find.text(l10n.reportInMailApp), findsOneWidget);
  });

  testWidgets('the kind is chosen, and the device box adds what it shows', (
    tester,
  ) async {
    usePhone(tester);
    final reports = FakeReportSender();
    await pumpScreen(
      tester,
      const ReportPage(
        request: ReportRequest(screen: '/', device: device),
      ),
      state: AppState.test(reports: reports, features: withMail),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.reportKindFeature));
    await tester.enterText(
      find.widgetWithText(TextField, l10n.reportTitleLabel),
      'Dark cards',
    );
    await tapInList(tester, find.text(l10n.reportDeviceInfo));
    await tapInList(tester, find.text(l10n.reportSend));
    final report = reports.sent.single;
    expect(report.kind, ReportKind.feature);
    expect(report.context, <String, String>{'Screen': '/', ...device});
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
