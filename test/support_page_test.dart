// Settings' Support page (owner, 2026-10-24): the row is on the tab; the page
// says a tip is only a show of support, brings nothing extra, and that
// reviewing and bug reports help as much or more; "Open my UPI app" opens a
// UPI link with no amount and says so when nothing opens it; "Copy UPI ID"
// copies the ID. It fits at 1.4x text, light and dark.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/features/settings/reviewing_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/support_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/settings_pages.dart';

String? _clipboard;

void _fakeClipboard(WidgetTester tester) {
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        _clipboard = (call.arguments as Map)['text'] as String?;
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
}

Future<({AppState state, FixedLinks links, AppLocalizations l10n})> _pump(
  WidgetTester tester, {
  bool opens = true,
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  usePhone(tester, textScale: textScale);
  _fakeClipboard(tester);
  final links = FixedLinks(opens: opens);
  final state = await pumpScreen(
    tester,
    const SupportPage(),
    state: AppState.test(links: links),
    themeMode: themeMode,
  );
  return (state: state, links: links, l10n: l10nOf(tester));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the Support page', () {
    testWidgets('Settings has the row, and it opens the page', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const SettingsPage());
      final l10n = l10nOf(tester);
      final row = find.ancestor(
        of: find.text(l10n.settingsRowSupport),
        matching: find.byType(GroupedTile),
      );
      await scrollTo(tester, row);
      expect(row, findsOneWidget);
      expect(find.text('Support with a cup of tea'), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(SupportPage), findsOneWidget);
    });

    testWidgets('it says a tip is a show of support and nothing more, and '
        'that reviewing and bug reports help as much', (tester) async {
      final p = await _pump(tester);
      expect(find.text(p.l10n.supportIntro), findsOneWidget);
      expect(find.text(p.l10n.supportNoPerks), findsOneWidget);
      expect(find.text(p.l10n.supportOtherWays), findsOneWidget);
      expect(
        p.l10n.supportIntro,
        allOf(contains('simply a show of support'), contains('grateful')),
      );
      expect(p.l10n.supportNoPerks, contains('preferential treatment'));
      expect(p.l10n.supportNoPerks, contains('anything extra'));
      expect(p.l10n.supportOtherWays, contains('just as much, if not more'));
      for (final text in <String>[
        p.l10n.supportIntro,
        p.l10n.supportNoPerks,
        p.l10n.supportOtherWays,
        p.l10n.supportNoUpiApp,
      ]) {
        expect(text, isNot(contains('!')));
      }
      expect(
        find.text(
          p.l10n.supportPayee(AppLinks.supportName, AppLinks.supportUpiId),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Review decks opens Reviewing', (tester) async {
      final p = await _pump(tester);
      await tester.tap(find.text(p.l10n.supportReviewDecks));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewingPage), findsOneWidget);
    });

    testWidgets('the pay action opens the UPI link, with no amount', (
      tester,
    ) async {
      final p = await _pump(tester);
      await tester.tap(find.text(p.l10n.supportOpenUpi));
      await tester.pumpAndSettle();
      expect(
        p.links.asked.single,
        'upi://pay?pa=das.arani@pingpay&pn=Arani%20Das',
      );
      final uri = Uri.parse(p.links.asked.single);
      expect(uri.scheme, 'upi');
      expect(uri.queryParameters['pa'], 'das.arani@pingpay');
      expect(uri.queryParameters['pn'], 'Arani Das');
      expect(uri.queryParameters, isNot(contains('am')));
      expect(find.text(p.l10n.supportNoUpiApp), findsNothing);
    });

    testWidgets('with no app to open it, the page says so and Copy still '
        'works', (tester) async {
      final p = await _pump(tester, opens: false);
      await tester.tap(find.text(p.l10n.supportOpenUpi));
      await tester.pumpAndSettle();
      expect(find.text(p.l10n.supportNoUpiApp), findsOneWidget);
      await tester.tap(find.text(p.l10n.supportCopyId));
      await tester.pumpAndSettle();
      expect(_clipboard, 'das.arani@pingpay');
    });

    testWidgets('Copy UPI ID puts the ID on the clipboard and says so', (
      tester,
    ) async {
      final p = await _pump(tester);
      await tester.tap(find.text(p.l10n.supportCopyId));
      await tester.pumpAndSettle();
      expect(_clipboard, 'das.arani@pingpay');
      expect(find.text(p.l10n.supportIdCopied), findsOneWidget);
      expect(p.links.asked, isEmpty);
    });

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('it fits at 1.4x text, ${mode.name}, even with the notice', (
        tester,
      ) async {
        final p = await _pump(
          tester,
          opens: false,
          textScale: 1.4,
          themeMode: mode,
        );
        await scrollTo(tester, find.text(p.l10n.supportOpenUpi));
        await tester.tap(find.text(p.l10n.supportOpenUpi));
        await tester.pumpAndSettle();
        await scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
