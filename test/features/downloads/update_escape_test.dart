import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/features/downloads/download_page.dart';
import 'package:fluenough/features/downloads/update_escape.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';

import '../../support/deck_remote.dart';
import '../../support/harness.dart';
import '../../support/picker.dart';

/// The way out of a failed download (0.4.0 failed every one, and left the
/// learner where Settings' update check could not be reached): "Check for
/// an app update" under every failure that traps the learner, and, once
/// it keeps failing, a line suggesting it or a report.

final DateTime _now = DateTime(2026, 10, 10, 9);

/// A version later than this build's.
const String _newer = '99.0.0';

/// The app on a faked GitHub [remote], with a release check that answers
/// [release]: on first launch past the languages spoken, or as the app's
/// home downloading [learning] if given.
AppState _app({
  required FakeDeckRemote remote,
  required FixedReleaseCheck release,
  List<String>? learning,
  ThemeMode themeMode = ThemeMode.light,
}) {
  final phone = MemoryDownloadedDecks();
  final settings = SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: learning ?? const <String>[],
  )..themeMode = themeMode;
  if (learning != null) settings.learningChosen = true;
  return AppState.test(
    decks: DeckSources(<DeckSource>[
      MemoryDeckSource(<String, String>{
        'decks/themes.yaml': File('decks/themes.yaml').readAsStringSync(),
      }),
      phone,
    ]),
    deckDownloads: DeckDownloads(
      fetcher: remote,
      files: phone,
      clock: () => _now,
    ),
    settings: settings,
    releases: release,
    now: _now,
  );
}

Future<AppState> _pump(
  WidgetTester tester,
  AppState state, {
  double textScale = 1.0,
}) async {
  usePhone(tester, textScale: textScale);
  addTearDown(state.dispose);
  await tester.pumpWidget(FluenoughApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // Not built yet: further down a list, at a large text size.
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Finder _check(AppLocalizations l10n) => find.text(l10n.downloadsCheckAppUpdate);

/// Taps "Check for an app update" and expects the sheet to show what
/// [release] answered: the newer version and Download, or up to date.
Future<void> _expectCheckWorks(
  WidgetTester tester,
  FixedReleaseCheck release, {
  required bool newer,
}) async {
  final l10n = l10nOf(tester);
  final before = release.checks;
  await _tap(tester, _check(l10n));
  expect(release.checks, before + 1);
  final sheet = find.byType(BottomSheet);
  expect(sheet, findsOneWidget);
  if (newer) {
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(l10n.settingsUpdateAvailable(_newer)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.widgetWithText(
          FilledButton,
          l10n.settingsUpdateDownload,
        ),
      ),
      findsOneWidget,
    );
  } else {
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(l10n.settingsUpdateUpToDate(AppInfo.version)),
      ),
      findsOneWidget,
    );
  }
}

void main() {
  late FakeDeckRemote remote;

  setUp(() {
    remote = FakeDeckRemote(repoFiles(const <String>['es', 'hi']));
  });

  group('"Getting your decks", failed', () {
    testWidgets('offers the update check, which finds a newer version', (
      tester,
    ) async {
      remote.failAll = FetchFailure.offline;
      final release = FixedReleaseCheck(const LatestRelease(_newer));
      await _pump(
        tester,
        _app(remote: remote, release: release, learning: const <String>['es']),
      );
      final l10n = l10nOf(tester);
      expect(find.byType(DownloadPage), findsOneWidget);
      expect(_check(l10n), findsOneWidget);
      expect(find.text(l10n.downloadsKeepsFailing), findsNothing);
      expect(release.checks, 0);
      await _expectCheckWorks(tester, release, newer: true);
    });

    testWidgets('says the app is up to date when it is', (tester) async {
      remote.failAll = FetchFailure.offline;
      final release = FixedReleaseCheck(const LatestRelease(AppInfo.version));
      await _pump(
        tester,
        _app(remote: remote, release: release, learning: const <String>['es']),
      );
      await _expectCheckWorks(tester, release, newer: false);
    });

    testWidgets('once Try again has failed twice, suggests updating or '
        'reporting it', (tester) async {
      remote.failAll = FetchFailure.offline;
      await _pump(
        tester,
        _app(
          remote: remote,
          release: FixedReleaseCheck(const LatestRelease(AppInfo.version)),
          learning: const <String>['es'],
        ),
      );
      final l10n = l10nOf(tester);
      await _tap(tester, find.text(l10n.commonRetry));
      expect(find.text(l10n.downloadsKeepsFailing), findsNothing);
      expect(find.text(l10n.downloadsReportProblem), findsNothing);
      await _tap(tester, find.text(l10n.commonRetry));
      expect(find.text(l10n.downloadsKeepsFailing), findsOneWidget);
      expect(find.text(l10n.downloadsReportProblem), findsOneWidget);
      expect(_check(l10n), findsOneWidget);

      // The report is the bug icon's.
      await _tap(tester, find.text(l10n.downloadsReportProblem));
      expect(find.byType(ReportPage), findsOneWidget);
    });

    testWidgets('a language that downloads starts the count again: A fails '
        'twice, then A comes and B fails, and there is no line', (
      tester,
    ) async {
      // The page itself, as when languages are added: as the app's home it
      // is rebuilt for each language still missing.
      remote.failAll = FetchFailure.offline;
      usePhone(tester);
      await pumpScreen(
        tester,
        DownloadPage(languages: const <String>['es', 'hi'], onReady: () {}),
        state: _app(
          remote: remote,
          release: FixedReleaseCheck(const LatestRelease(AppInfo.version)),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      expect(find.byKey(const ValueKey<String>('failure-es')), findsOneWidget);
      await _tap(tester, find.text(l10n.commonRetry));
      expect(find.byKey(const ValueKey<String>('failure-es')), findsOneWidget);

      remote.failAll = null;
      for (final path in remote.files.keys) {
        if (path.startsWith('decks/hi/')) {
          remote.failures[path] = FetchFailure.offline;
        }
      }
      await _tap(tester, find.text(l10n.commonRetry));
      expect(find.byKey(const ValueKey<String>('failure-hi')), findsOneWidget);
      expect(find.text(l10n.downloadsKeepsFailing), findsNothing);
      expect(find.text(l10n.downloadsReportProblem), findsNothing);
      expect(_check(l10n), findsOneWidget);
    });

    testWidgets('at twice the text size, in dark, fits and meets the '
        'guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      remote.failAll = FetchFailure.offline;
      await _pump(
        tester,
        _app(
          remote: remote,
          release: FixedReleaseCheck(const LatestRelease(_newer)),
          learning: const <String>['es'],
          themeMode: ThemeMode.dark,
        ),
        textScale: 2,
      );
      final l10n = l10nOf(tester);
      await _tap(tester, find.text(l10n.commonRetry));
      await _tap(tester, find.text(l10n.commonRetry));
      expect(find.text(l10n.downloadsKeepsFailing), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await _tap(tester, _check(l10n));
      expect(find.text(l10n.settingsUpdateAvailable(_newer)), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });

  group('the language picker', () {
    testWidgets('"Couldn\'t get the list of courses" offers the update '
        'check', (tester) async {
      remote.failAll = FetchFailure.offline;
      final release = FixedReleaseCheck(const LatestRelease(_newer));
      await _pump(tester, _app(remote: remote, release: release));
      final l10n = l10nOf(tester);
      expect(find.text(l10n.downloadsIndexFailed), findsOneWidget);
      expect(_check(l10n), findsOneWidget);
      await _expectCheckWorks(tester, release, newer: true);
    });

    testWidgets('the list of courses, up to date, and failing again and '
        'again', (tester) async {
      remote.failAll = FetchFailure.offline;
      final release = FixedReleaseCheck(const LatestRelease(AppInfo.version));
      await _pump(tester, _app(remote: remote, release: release));
      final l10n = l10nOf(tester);
      await _expectCheckWorks(tester, release, newer: false);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await _tap(tester, find.text(l10n.commonRetry));
      expect(find.text(l10n.downloadsIndexFailed), findsOneWidget);
      expect(find.text(l10n.downloadsKeepsFailing), findsNothing);
      await _tap(tester, find.text(l10n.commonRetry));
      expect(find.text(l10n.downloadsKeepsFailing), findsOneWidget);
      expect(find.text(l10n.downloadsReportProblem), findsOneWidget);
    });

    testWidgets('a language whose decks will not come offers the update '
        'check, and after two more tries the line', (tester) async {
      final release = FixedReleaseCheck(const LatestRelease(_newer));
      await _pump(tester, _app(remote: remote, release: release));
      final l10n = l10nOf(tester);
      expect(_check(l10n), findsNothing);
      remote.failAll = FetchFailure.offline;
      await pickLanguage(tester, 'hi');
      expect(_check(l10n), findsOneWidget);
      expect(find.text(l10n.downloadsKeepsFailing), findsNothing);

      final retry = find.descendant(
        of: languageCard('hi'),
        matching: find.text(l10n.commonRetry),
      );
      for (var i = 0; i < 2; i++) {
        await scrollToInPicker(tester, retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();
      }
      expect(find.text(l10n.downloadsKeepsFailing), findsOneWidget);
      await _expectCheckWorks(tester, release, newer: true);
    });

    testWidgets('a language that fails, fails twice more, then gets its '
        'first decks and fails again, starts the count again', (tester) async {
      final state = await _pump(
        tester,
        _app(
          remote: remote,
          release: FixedReleaseCheck(const LatestRelease(AppInfo.version)),
        ),
      );
      final l10n = l10nOf(tester);
      remote.failAll = FetchFailure.offline;
      await pickLanguage(tester, 'hi');
      final retry = find.descendant(
        of: languageCard('hi'),
        matching: find.text(l10n.commonRetry),
      );
      Future<void> again() async {
        await scrollToInPicker(tester, retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();
      }

      await again();
      await again();
      expect(find.text(l10n.downloadsKeepsFailing), findsOneWidget);

      // The next try gets its first decks in, then fails on the rest.
      remote.failAll = null;
      remote.failAfter =
          remote.asked.where((p) => p != 'decks/index.json').length + 30;
      await again();
      final downloads = state.deckDownloads!;
      expect(downloads.isReady('hi', const <String>['en']), isTrue);
      expect(downloads.failureOf('hi'), isNotNull);
      expect(find.text(l10n.downloadsKeepsFailing), findsNothing);
      expect(_check(l10n), findsOneWidget);
    });

    testWidgets('one language\'s failures do not count for another', (
      tester,
    ) async {
      await _pump(
        tester,
        _app(
          remote: remote,
          release: FixedReleaseCheck(const LatestRelease(AppInfo.version)),
        ),
      );
      final l10n = l10nOf(tester);
      remote.failAll = FetchFailure.offline;
      await pickLanguage(tester, 'hi');
      final retry = find.descendant(
        of: languageCard('hi'),
        matching: find.text(l10n.commonRetry),
      );
      for (var i = 0; i < 2; i++) {
        await scrollToInPicker(tester, retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();
      }
      expect(find.text(l10n.downloadsKeepsFailing), findsOneWidget);

      // Un-chosen, its count goes; Spanish failing once shows no line.
      await pickLanguage(tester, 'hi');
      await pickLanguage(tester, 'es');
      expect(_check(l10n), findsOneWidget);
      expect(find.text(l10n.downloadsKeepsFailing), findsNothing);
    });

    testWidgets('decks that cannot be read offer the update check', (
      tester,
    ) async {
      final release = FixedReleaseCheck(const LatestRelease(AppInfo.version));
      await pumpScreen(
        tester,
        const LanguagePickerPage(firstRun: true),
        state: AppState.test(decks: _FailingDeckSource(), releases: release),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.commonDecksFailed), findsOneWidget);
      expect(find.byType(UpdateEscape), findsOneWidget);
      await _expectCheckWorks(tester, release, newer: false);
    });
  });
}

/// Decks that can never be listed.
class _FailingDeckSource implements DeckSource {
  @override
  Future<List<String>> list() async => throw StateError('no manifest');

  @override
  Future<String> read(String path) async => throw StateError('no deck');
}
