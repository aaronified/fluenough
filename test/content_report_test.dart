// The content report (owner, 2026-11-16): the bug icon stays only where
// something is taught, and opens a five-row sheet about the content.
// Behaviour only: what the learner sees and what the report carries.
import 'dart:io';
import 'dart:typed_data';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/feedback/content_report.dart';
import 'package:fluenough/core/feedback/report.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/features/settings/app_log_page.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/release_notes_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/sources_page.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:fluenough/features/stats/over_time_page.dart';
import 'package:fluenough/ui/widgets/content_report.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// Records what it is sent; the mail app always takes it.
class _Sender implements ReportSender {
  final List<Report> sent = <Report>[];

  @override
  Future<ReportOutcome> send(Report report) async {
    sent.add(report);
    return const ReportInMailApp();
  }
}

final Finder _bug = find.byIcon(Icons.bug_report_outlined);

const ContentTarget _choice = ContentTarget(
  subject: ContentSubject.card,
  id: 'hi-0042',
  deckId: 'hi-en-words',
  pair: 'hi from en',
  listsOptions: true,
);

const ContentTarget _plain = ContentTarget(
  subject: ContentSubject.card,
  id: 'te-0384',
  deckId: 'te-en-family',
  pair: 'te from en',
);

/// Loads the app's own Roboto: a widget test draws every glyph as a
/// full-width box until a font is loaded, which wraps text far more than a
/// phone does, so the fit is measured with the real font.
Future<void> _loadRoboto(WidgetTester tester) async {
  await tester.runAsync(() async {
    final loader = FontLoader('Roboto');
    for (final style in <String>['Regular', 'Medium', 'Bold']) {
      final bytes = File('assets/fonts/Roboto-$style.ttf').readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });
}

/// The phone of the mockup's measurement: 360 x 740 dp, text at 1.4x.
void _smallPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(360 * 3, 740 * 3)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = 1.4;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<_Sender> _pumpButton(
  WidgetTester tester,
  ContentTarget target, {
  bool open = true,
}) async {
  final sender = _Sender();
  await pumpScreen(
    tester,
    Scaffold(
      appBar: AppBar(actions: <Widget>[ContentReportButton(target: target)]),
    ),
    state: AppState.test(reports: sender),
  );
  if (open) {
    await tester.tap(_bug);
    await tester.pumpAndSettle();
  }
  return sender;
}

Finder _row(ContentCategory category) =>
    find.byKey(ValueKey<String>('content-report-${category.name}'));

void main() {
  group('the sheet', () {
    testWidgets('shows five rows and fits at 1.4x on 360 x 740 without '
        'scrolling, even with a reason chosen', (tester) async {
      _smallPhone(tester);
      await _loadRoboto(tester);
      await _pumpButton(tester, _choice);
      final l10n = l10nOf(tester);
      for (final category in ContentCategory.values) {
        expect(_row(category), findsOneWidget);
      }

      // The tallest state: a reason chosen shows its line under the row.
      await tester.tap(_row(ContentCategory.wrongOptions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.contentReasonNoCorrect));
      await tester.pumpAndSettle();
      expect(find.text(l10n.contentReasonNoCorrect), findsOneWidget);

      final scrollable = find
          .descendant(
            of: find.byType(ContentReportSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        0,
      );
      expect(
        tester.getBottomLeft(find.text(l10n.contentReportSend)).dy,
        lessThanOrEqualTo(740),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a drill that lists options offers three wrong-options '
        'reasons in a popup; every other screen has the one reason as its '
        'own row', (tester) async {
      usePhone(tester);
      await _pumpButton(tester, _choice);
      final l10n = l10nOf(tester);
      expect(
        find.descendant(
          of: _row(ContentCategory.wrongOptions),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
      await tester.tap(_row(ContentCategory.wrongOptions));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('content-report-popup')),
        findsOneWidget,
      );
      expect(find.text(l10n.contentReasonTranslation), findsOneWidget);
      expect(find.text(l10n.contentReasonNoCorrect), findsOneWidget);
      expect(find.text(l10n.contentReasonMoreThanOne), findsOneWidget);

      await _pumpButton(tester, _plain);
      expect(
        find.descendant(
          of: _row(ContentCategory.wrongOptions),
          matching: find.text(l10n.contentReasonTranslation),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row(ContentCategory.wrongOptions),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );
      await tester.tap(_row(ContentCategory.wrongOptions));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('content-report-popup')),
        findsNothing,
      );
    });

    testWidgets('sends the ids, the language pair and the app version, '
        'a note, and nothing about the screen or the device', (tester) async {
      usePhone(tester);
      final sender = await _pumpButton(tester, _plain);
      final l10n = l10nOf(tester);
      final send = find.widgetWithText(FilledButton, l10n.contentReportSend);
      expect(tester.widget<FilledButton>(send).onPressed, isNull);

      await tester.tap(_row(ContentCategory.readingOrSound));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.contentReasonAudio));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'No sound at all');
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();

      final report = sender.sent.single;
      expect(report.kind, ReportKind.content);
      expect(
        report.subject,
        '[Fluenough] Content: Reading or sound: The audio is wrong or '
        'missing',
      );
      expect(report.details, 'No sound at all');
      expect(report.context, <String, String>{
        'Card': 'te-0384',
        'Deck': 'te-en-family',
        'Languages': 'te from en',
        'App': 'fluenough ${AppInfo.version}',
      });
      expect(report.files, isEmpty);
      expect(report.context.containsKey('Screen'), isFalse);

      // The mail app has it: the honest wording, then Done.
      expect(find.text(l10n.contentReportDoneBody), findsOneWidget);
      await tester.tap(find.text(l10n.commonDone));
      await tester.pumpAndSettle();
      expect(find.byType(ContentReportSheet), findsNothing);
    });

    testWidgets('Something else needs its note before it can be sent', (
      tester,
    ) async {
      usePhone(tester);
      final sender = await _pumpButton(tester, _plain);
      final l10n = l10nOf(tester);
      final send = find.widgetWithText(FilledButton, l10n.contentReportSend);
      await tester.tap(_row(ContentCategory.somethingElse));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'The card is a duplicate');
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(sender.sent.single.subject, '[Fluenough] Content: Something else');
      expect(sender.sent.single.details, 'The card is a duplicate');
    });
  });

  group('where the bug icon is', () {
    testWidgets('a drill header with a card has it, one without has none', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const Scaffold(
          body: DrillHeader(
            progress: 0,
            position: 1,
            total: 8,
            onClose: null,
            report: _choice,
          ),
        ),
      );
      expect(_bug, findsOneWidget);
      await pumpScreen(
        tester,
        const Scaffold(
          body: DrillHeader(progress: 0, position: 1, total: 8, onClose: null),
        ),
      );
      expect(_bug, findsNothing);
    });

    testWidgets('the deck page and the unit page have it and report their '
        'own id', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const DeckDetailPage(deckId: 'te-en-family'));
      expect(_bug, findsOneWidget);
      await tester.tap(_bug);
      await tester.pumpAndSettle();
      expect(find.textContaining('Deck: te-en-family'), findsOneWidget);
      expect(find.textContaining('Card:'), findsNothing);

      await pumpScreen(tester, const UnitPage(deckId: 'te-en-family'));
      expect(_bug, findsOneWidget);
    });

    testWidgets('the word sheet reports its card with the bug icon', (
      tester,
    ) async {
      usePhone(tester);
      final state = AppState.test();
      await state.load();
      final entry = state.deckById('te-en-family')!;
      await pumpScreen(
        tester,
        Scaffold(
          body: WordSheet(card: entry.cards.first, language: entry.language),
        ),
        state: state,
      );
      expect(_bug, findsOneWidget);
      await tester.tap(find.text(l10nOf(tester).cardReport));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Card: ${entry.cards.first.id}'),
        findsOneWidget,
      );
      expect(find.textContaining('Deck: te-en-family'), findsOneWidget);
    });

    for (final (name, page) in <(String, Widget)>[
      ('the app log', const AppLogPage()),
      ('your data', const YourDataPage()),
      ('sources', const SourcesPage()),
      ('appearance', const AppearancePage()),
      ('release notes', const ReleaseNotesPage()),
      ('progress over time', const OverTimePage()),
      ('the Settings tab', const SettingsPage()),
    ]) {
      testWidgets('$name has no bug icon', (tester) async {
        usePhone(tester);
        await pumpScreen(tester, page);
        expect(find.byType(Scaffold), findsWidgets);
        expect(_bug, findsNothing);
      });
    }
  });

  testWidgets('the Settings three-dot menu has Report a problem, which opens '
      'the general report', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const SettingsPage());
    final l10n = l10nOf(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsReportProblem), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    await tester.tap(find.text(l10n.settingsReportProblem));
    await tester.pumpAndSettle();
    expect(find.byType(ReportPage), findsOneWidget);
    // The general report lists support, bug and feedback; content has its
    // own sheet.
    expect(find.byType(Radio<ReportKind>), findsNWidgets(3));
  });
}
