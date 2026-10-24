// Settings and reports: every row opens its page and the version is
// pubspec's; a skill switch turns its skill off; speech rate reaches the
// voice; theme and high contrast apply to the whole app; adult content asks
// once; the app log keeps 7 days or 2,000 lines, survives a restart and
// exports; a report goes by share, else mail, else says why, with the log
// only when ticked; an incoming feature is dimmed and does nothing; the PIN.

import 'dart:io';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_log.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/log_files.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/report_mail.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/app/system_settings.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/feedback/report.dart';
import 'package:fluenough/core/logs/log_entry.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/profiles/pin_page.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/features/settings/activities_page.dart';
import 'package:fluenough/features/settings/app_log_page.dart';
import 'package:fluenough/features/settings/daily_minutes.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/languages_page.dart';
import 'package:fluenough/features/settings/reviewing_page.dart';
import 'package:fluenough/features/settings/settings_controls.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/support_page.dart';
import 'package:fluenough/features/settings/updates_page.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:fluenough/features/settings/your_decks_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:fluenough/ui/widgets/incoming.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/profiles.dart';
import 'support/settings_pages.dart';
import 'support/harness.dart';

// From settings_page_test.dart.
Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(GroupedTile));
// From section_pages_test.dart.
Finder _slider(String title) => find.descendant(
  of: find.ancestor(
    of: find.text(title),
    matching: find.byType(SettingsSlider),
  ),
  matching: find.byType(Slider),
);

Switch _switchOf(WidgetTester tester, Finder row) => tester.widget<Switch>(
  find.descendant(of: row, matching: find.byType(Switch)),
);

/// Saves into [saved] and opens [picked], in place of the phone's dialogs.
class _FakeLogFiles implements LogFiles {
  _FakeLogFiles({this.picked});

  final Map<String, String> saved = <String, String>{};
  String? picked;
  String? title;

  @override
  Future<bool> save(
    String fileName,
    String contents, {
    String mimeType = 'application/jsonl',
  }) async {
    saved[fileName] = contents;
    return true;
  }

  @override
  Future<String?> open({required String title}) async {
    this.title = title;
    return picked;
  }
}

// From adult_content_test.dart.
// Settings' "Adult content (18+)" (#96): off by default, asks the learner to
// confirm their age as it is switched on, and while on shows rude words
// where a warning would hide them, and offensive cards to rate.

Finder _adultRow(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(GroupedTile));

// From log_entry_test.dart.
// From app_log_test.dart.
class _FailingStore implements LogStore {
  @override
  Future<void> append(String line) async =>
      throw const FileSystemException('full');

  @override
  Future<List<String>> read() async => throw const FileSystemException('gone');

  @override
  Future<void> write(List<String> lines) async =>
      throw const FileSystemException('full');
}

// From logs_section_test.dart.
/// Saves into [saved], or throws [error], in place of the phone's dialog.
class _FakeLogFilesLogsSection implements LogFiles {
  final Map<String, ({String text, String type})> saved =
      <String, ({String text, String type})>{};
  Exception? error;

  @override
  Future<bool> save(
    String fileName,
    String contents, {
    String mimeType = 'application/jsonl',
  }) async {
    final thrown = error;
    if (thrown != null) throw thrown;
    saved[fileName] = (text: contents, type: mimeType);
    return true;
  }

  @override
  Future<String?> open({required String title}) async => null;
}

/// The app log over a log holding [lines] events, and what it saves to.
Future<({AppLog log, _FakeLogFilesLogsSection files})> _pump(
  WidgetTester tester, {
  List<String> lines = const <String>['Opened /deck', 'Opened /inspect'],
  double textScale = 1.0,
}) async {
  usePhone(tester, textScale: textScale);
  final log = AppLog(clock: () => DateTime.utc(2026, 10, 9, 12));
  final files = _FakeLogFilesLogsSection();
  await pumpScreen(
    tester,
    const AppLogPage(),
    state: AppState.test(log: log, logFiles: files),
  );
  await log.clear();
  lines.forEach(log.event);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  return (log: log, files: files);
}

Future<void> _tap(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

/// What a file dialog throws when it cannot save.
class FileSystemLikeException implements Exception {
  const FileSystemLikeException();
}

// From report_page_test.dart.
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

/// What the device box adds, as the bug icon would hand it on.
const Map<String, String> device = <String, String>{
  'App': 'fluenough 0.2.0',
  'System': 'Android 14 (API 34)',
};

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

// From report_log_test.dart.
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
Future<AppLog> _pumpReportLog(
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

// From incoming_test.dart.
/// A button whose own label the incoming wrapper must replace.
class _Live extends StatelessWidget {
  const _Live({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    child: Text(AppLocalizations.of(context)!.settingsReminder),
  );
}

Future<void> pumpWrapped(
  WidgetTester tester, {
  required FeatureRegistry features,
  required VoidCallback onPressed,
}) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => IncomingFeature(
            feature: Feature.reminder,
            label: AppLocalizations.of(context)!.settingsReminder,
            child: _Live(onPressed: onPressed),
          ),
        ),
      ),
    ),
    state: AppState.test(features: features),
  );
}

// From pin_page_test.dart.
/// Aro's PIN pad, with Mira current.
Future<AppState> _pumpPinPage(WidgetTester tester, {bool wrongPin = false}) =>
    pumpProfiles(
      tester,
      PinPage(profileId: 'aro', wrongPin: wrongPin),
      currentProfileId: 'mira',
    );

Finder _key(String digit) => find.widgetWithText(TextButton, digit);

Future<void> _enter(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(_key(digit));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings', () {
    group('the Settings tab is the profile card and a list of pages', () {
      testWidgets(
        'every row opens its page, and the version shown is pubspec.yaml\'s',
        (tester) async {
          usePhone(tester);
          await pumpScreen(tester, const SettingsPage());
          final l10n = l10nOf(tester);
          final pages = <String, Type>{
            l10n.settingsRowLanguages: LanguagesSettingsPage,
            l10n.settingsRowActivities: ActivitiesPage,
            l10n.settingsRowLook: AppearancePage,
            l10n.settingsRowReviewing: ReviewingPage,
            l10n.settingsRowDecks: YourDecksPage,
            l10n.settingsRowData: YourDataPage,
            l10n.settingsRowLog: AppLogPage,
            l10n.settingsRowUpdates: UpdatesPage,
            l10n.settingsRowSupport: SupportPage,
          };
          for (final MapEntry(key: title, value: page) in pages.entries) {
            final row = find.text(title);
            await scrollTo(tester, row);
            await tester.tap(row);
            await tester.pumpAndSettle();
            expect(find.byType(page), findsOneWidget, reason: title);
            tester.state<NavigatorState>(find.byType(Navigator)).pop();
            await tester.pumpAndSettle();
            expect(
              find.byType(SettingsPage),
              findsOneWidget,
              reason: 'back from $title',
            );
          }

          final pubspec = File('pubspec.yaml').readAsStringSync();
          final version = RegExp(
            r'^version:\s*([^+\s]+)',
            multiLine: true,
          ).firstMatch(pubspec)!.group(1);
          expect(AppInfo.version, version);

          usePhone(tester);
          await pumpScreen(tester, const SettingsPage());
          final footer = find.text(
            l10nOf(tester).settingsFooter(AppInfo.version),
          );
          await scrollTo(tester, footer);
          expect(footer, findsOneWidget);
        },
      );
    });
  });

  group('the section pages', () {
    group('Activities and memory (#243)', () {
      testWidgets(
        'a skill\'s switch turns its skill off; speech rate reaches the '
        'voice',
        (tester) async {
          usePhone(tester);
          final state = await pumpScreen(tester, const ActivitiesPage());
          final l10n = l10nOf(tester);
          final settings = state.settings;
          for (final skill in <Skill>[
            Skill.production,
            Skill.listening,
            Skill.reading,
          ]) {
            final row = _row(skill.settingsLabel(l10n));
            await scrollTo(tester, row);
            expect(settings.isEnabled(skill), isTrue);
            expect(
              find.descendant(
                of: row,
                matching: find.textContaining(skill.settingsOn(l10n)),
              ),
              findsOneWidget,
            );
            await tester.tap(row);
            await tester.pumpAndSettle();
            expect(settings.isEnabled(skill), isFalse, reason: '$skill');
            expect(_switchOf(tester, row).value, isFalse);
            expect(
              find.descendant(
                of: row,
                matching: find.textContaining(skill.settingsOff(l10n)),
              ),
              findsOneWidget,
            );
            await tester.tap(row);
            await tester.pumpAndSettle();
            expect(settings.isEnabled(skill), isTrue, reason: '$skill');
          }
          // Heard words' off line says words still play from a speaker.
          expect(
            Skill.listening.settingsOff(l10n),
            'No listening questions. Words still play when you tap a speaker',
          );

          {
            usePhone(tester);
            final state = await pumpScreen(tester, const ActivitiesPage());
            final l10n = l10nOf(tester);
            final slider = _slider(l10n.settingsSpeechRate);
            await scrollTo(tester, slider);

            await tapSlider(tester, slider, 1);
            await tester.pumpAndSettle();
            expect(state.settings.speechRate, SettingsNotifier.maxSpeechRate);
            expect(state.settings.ttsRate(), closeTo(0.75, 1e-9));
            expect(find.text(l10n.settingsSpeechRateValue(1.5)), findsOne);

            await tapSlider(tester, slider, 0);
            await tester.pumpAndSettle();
            expect(state.settings.speechRate, SettingsNotifier.minSpeechRate);
            expect(state.settings.ttsRate(), closeTo(0.25, 1e-9));
          }
        },
      );
    });

    group('Your data', () {
      void answer(ProgressStore p, String card, int grade, int day) => p.record(
        deckId: 'hi-en-market',
        cardId: card,
        mode: DrillMode.production,
        grade: grade,
        now: DateTime(2026, 9, 20 + day, 19),
      );

      Future<void> tapRow(WidgetTester tester, String title) async {
        final row = find.text(title);
        await scrollTo(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
      }

      testWidgets(
        'Export saves the log as the profile\'s file; Import merges a backup '
        'and says how many reviews were new',
        (tester) async {
          usePhone(tester);
          final files = _FakeLogFiles();
          final progress = MemoryProgress();
          answer(progress, 'hi-0231', 4, 0);
          answer(progress, 'hi-0232', 1, 1);
          final state = await pumpScreen(
            tester,
            const YourDataPage(),
            state: AppState.test(progress: progress, logFiles: files),
          );
          final l10n = l10nOf(tester);
          await scrollTo(tester, find.text(l10n.settingsExportDesc(2)));
          expect(find.text(l10n.settingsExportDesc(2)), findsOneWidget);

          await tapRow(tester, l10n.settingsExport);
          final name = 'fluenough-${state.currentProfile.id}-reviews.jsonl';
          expect(files.saved.keys, [name]);
          expect(LogJsonl.decode(files.saved[name]!).reviews, hasLength(2));
          expect(find.text(l10n.settingsExported(name)), findsOneWidget);

          {
            usePhone(tester);
            final old = MemoryProgress();
            answer(old, 'hi-0231', 4, 0);
            answer(old, 'hi-0231', 5, 1);
            answer(old, 'hi-0232', 3, 1);
            final files = _FakeLogFiles(picked: old.exportJsonl());
            final progress = MemoryProgress();
            answer(progress, 'hi-0231', 5, 1);
            await pumpScreen(
              tester,
              const YourDataPage(),
              state: AppState.test(progress: progress, logFiles: files),
            );
            final l10n = l10nOf(tester);

            await tapRow(tester, l10n.settingsImport);
            expect(files.title, l10n.settingsImportPick);
            expect(
              progress.log,
              hasLength(3),
              reason: 'one review was already here',
            );
            expect(find.text(l10n.settingsImported(2)), findsOneWidget);
            expect(find.text(l10n.settingsExportDesc(3)), findsOneWidget);

            await clearSnackBars(tester);
            await tapRow(tester, l10n.settingsImport);
            expect(progress.log, hasLength(3));
            expect(find.text(l10n.settingsImported(0)), findsOneWidget);
          }
        },
      );
    });
  });

  group('Appearance', () {
    testWidgets('a colour and high contrast picked here theme the whole app', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpApp(
        tester,
        state: AppState.test(
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningChosen: true,
          ),
        ),
      );
      final l10n = l10nOf(tester);
      Future<void> tapText(String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.pumpAndSettle();
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }

      await tapText(l10n.navSettings);
      await tapText(l10n.settingsRowLook);
      expect(find.byType(AppearancePage), findsOneWidget);

      // Below the preview, which a longer first card makes taller.
      await tester.scrollUntilVisible(
        find.text(l10n.appearanceSeedClay),
        200,
        scrollable: find
            .descendant(
              of: find.byType(AppearancePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tapText(l10n.appearanceSeedClay);
      await tapText(l10n.appearanceContrastHigh);
      await tester.pageBack();
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SettingsPage));
      expect(
        Theme.of(context).colorScheme.primary,
        ColorScheme.fromSeed(
          seedColor: Color(ThemeSeed.clay.argb),
          contrastLevel: 1.0,
        ).primary,
      );
      expect(ModeColors.of(context).listening, ModeColors.lightHigh.listening);
      expect(
        find.text(
          l10n.settingsSumLook(
            l10n.settingsAppearanceSummaryHigh(
              l10n.appearanceThemeSystem,
              l10n.appearanceSeedClay,
            ),
            'English',
          ),
        ),
        findsOneWidget,
      );

      state.settings.highContrast = false;
      await tester.pumpAndSettle();
      expect(
        ModeColors.of(tester.element(find.byType(SettingsPage))).listening,
        ModeColors.light.listening,
      );
    });
  });

  group('minutes a day', () {
    test('a language starts at 15, takes 5 to 60, and keeps it after a '
        'restart', () {
      final settings = SettingsNotifier();
      expect(settings.dailyMinutesFor('hi'), 15);
      settings.setDailyMinutes('hi', 25);
      settings.setDailyMinutes('bn', 2);
      settings.setDailyMinutes('te', 90);
      final restored = SettingsNotifier()..restore(settings.toStored());
      expect(restored.dailyMinutesFor('hi'), 25);
      expect(restored.dailyMinutesFor('bn'), 5);
      expect(restored.dailyMinutesFor('te'), 60);
      expect(restored.dailyMinutesFor('es'), 15, reason: 'untouched');
      // Existing learners, from before the setting, start at 15.
      expect(
        (SettingsNotifier()..restore(const <String, String>{})).dailyMinutesFor(
          'hi',
        ),
        15,
      );
    });

    testWidgets('the row sets it with a preset or a custom value', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const Scaffold(body: DailyMinutes(language: 'hi')),
      );
      final l10n = l10nOf(tester);
      expect(state.settings.dailyMinutesFor('hi'), 15);
      expect(find.text(l10n.minutesValue(15)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('minutes-hi-20')));
      await tester.pumpAndSettle();
      expect(state.settings.dailyMinutesFor('hi'), 20);
      expect(find.text(l10n.minutesValue(20)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('minutes-hi-custom')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.minutesMore));
      await tester.pump();
      await tester.tap(find.text(l10n.minutesSave));
      await tester.pumpAndSettle();
      expect(state.settings.dailyMinutesFor('hi'), 21);
      expect(find.text(l10n.minutesCustomValue(21)), findsOneWidget);
    });
  });

  group('adult content', () {
    testWidgets('adult content is off by default, and switching it on asks '
        'once', (tester) async {
      final settings = SettingsNotifier();
      expect(settings.adultContent, isFalse);
      expect(settings.toStored()['adult_content'], 'false');
      settings.adultContent = true;
      final restored = SettingsNotifier()..restore(settings.toStored());
      expect(restored.adultContent, isTrue);
      // A store from before the setting keeps it off.
      expect(
        (SettingsNotifier()..restore(const <String, String>{})).adultContent,
        isFalse,
      );

      usePhone(tester);
      final state = await pumpScreen(tester, const LanguagesSettingsPage());
      final l10n = l10nOf(tester);
      final row = _adultRow(l10n.settingsAdult);
      await scrollTo(tester, row);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(state.settings.adultContent, isFalse);
      expect(adultContentOn(state), isFalse);
      expect(
        find.descendant(of: row, matching: find.text(l10n.settingsAdultOff)),
        findsOneWidget,
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsAdultConfirmTitle), findsOneWidget);
      expect(find.text(l10n.settingsAdultConfirmBody), findsOneWidget);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(state.settings.adultContent, isFalse);
      expect(find.text(l10n.settingsAdultOff), findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsAdultConfirm));
      await tester.pumpAndSettle();
      expect(state.settings.adultContent, isTrue);
      expect(adultContentOn(state), isTrue);
      expect(find.text(l10n.settingsAdultConfirmTitle), findsNothing);
      expect(
        find.descendant(of: row, matching: find.text(l10n.settingsAdultOn)),
        findsOneWidget,
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsAdultConfirmTitle), findsNothing);
      expect(state.settings.adultContent, isFalse);
      expect(find.text(l10n.settingsAdultOff), findsOneWidget);
    });
  });

  group('the app log\'s cap', () {
    final now = DateTime.utc(2026, 10, 9, 12);

    LogEntry at(DateTime time, [String message = 'Opened /deck']) =>
        LogEntry(time, LogLevel.event, message);

    group('the cap', () {
      test('the log keeps 7 days or 2,000 lines, whichever is fewer', () {
        final old = at(
          now.subtract(const Duration(days: 7, seconds: 1)),
          'old',
        );
        final edge = at(now.subtract(const Duration(days: 7)), 'edge');
        final fresh = at(now.subtract(const Duration(hours: 1)), 'fresh');
        expect(capLog(<LogEntry>[old, edge, fresh], now), <LogEntry>[
          edge,
          fresh,
        ]);

        final many = <LogEntry>[
          for (var i = 0; i < 2500; i++)
            at(now.subtract(Duration(seconds: 2500 - i)), '$i'),
        ];
        final kept = capLog(many, now);
        expect(kept, hasLength(logMaxLines));
        expect(kept.first.message, '500');
        expect(kept.last.message, '2499');

        {
          // 3,000 lines over 10 days: the 7-day cut leaves 2,100, more than
          // 2,000, so the line cap decides.
          final busy = <LogEntry>[
            for (var i = 0; i < 3000; i++)
              at(now.subtract(Duration(minutes: (3000 - i) * 4.8 ~/ 1)), '$i'),
          ];
          expect(capLog(busy, now), hasLength(logMaxLines));
          // 100 lines over 10 days: the line cap leaves them all, and the
          // 7-day cut decides.
          final quiet = <LogEntry>[
            for (var i = 0; i < 100; i++)
              at(now.subtract(Duration(hours: (100 - i) * 24 * 10 ~/ 100))),
          ];
          expect(capLog(quiet, now), hasLength(70));
          expect(logMaxAge, const Duration(days: 7));
          expect(logMaxLines, 2000);
        }
      });
    });
  });

  group('the app log', () {
    final start = DateTime.utc(2026, 10, 9, 12);

    /// A clock that reads [now], which a test moves on.
    DateTime now = start;
    DateTime clock() => now;
    setUp(() => now = start);

    group('the app log', () {
      test('the log survives a restart in its file, and a store that fails '
          'never stops the app', () async {
        final folder = await Directory.systemTemp.createTemp('fluenough-log');
        addTearDown(() => folder.delete(recursive: true));
        final file = File('${folder.path}/logs/app.log');
        final before = AppLog(store: FileLogStore(file), clock: clock);
        await before.open();
        before
          ..event('Opened /drill')
          ..error('Uncaught: crash');
        await before.idle;

        final after = AppLog(store: FileLogStore(file), clock: clock);
        await after.open();
        expect(
          <String>[for (final e in after.entries) e.message],
          <String>['Opened /drill', 'Uncaught: crash'],
        );
        expect(after.entries.last.level, LogLevel.error);

        final log = AppLog(store: _FailingStore(), clock: clock);
        await log.open();
        log.event('x');
        await log.idle;
        expect(log.entries, hasLength(1));
      });
    });
  });

  group('the App log page', () {
    testWidgets('Export saves the log as a text file; Clear asks first', (
      tester,
    ) async {
      final (:log, :files) = await _pump(tester);
      final text = log.text;
      await _tap(tester, l10nOf(tester).appLogExport);
      expect(files.saved.keys, <String>[appLogFileName]);
      expect(files.saved[appLogFileName]!.text, text);
      expect(files.saved[appLogFileName]!.type, 'text/plain');
      expect(
        find.text(l10nOf(tester).settingsExported(appLogFileName)),
        findsOneWidget,
      );
      expect(log.entries.last.message, 'App log exported');

      {
        final (:log, files: _) = await _pump(tester);
        final l10n = l10nOf(tester);
        await _tap(tester, l10n.appLogClear);
        expect(find.text(l10n.settingsLogClearTitle), findsOneWidget);
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();
        expect(log.entries, hasLength(2));

        await _tap(tester, l10n.appLogClear);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.settingsLogClearConfirm),
          ),
        );
        await tester.pumpAndSettle();
        expect(log.isEmpty, isTrue);
        expect(find.text(l10n.settingsLogCleared), findsOneWidget);
        expect(find.text(l10n.appLogEmpty), findsOneWidget);
      }
    });
  });

  group('sending a report', () {
    const withLog = Report(
      kind: ReportKind.support,
      title: 'No sound',
      files: <AttachedFile>[
        AttachedFile(name: 'fluenough-app-log.txt', text: 'a line'),
      ],
    );

    test('a report goes by the share, else as a mail link, else fails saying '
        'why', () async {
      final links = FixedLinks();
      final share = FixedMailShare();
      final outcome = await MailReportSender(
        address: 'reports@example.org',
        links: links,
        share: share,
      ).send(withLog);
      expect(
        outcome,
        isA<ReportInMailApp>().having((o) => o.filesLeftOut, 'left out', false),
      );
      final mail = share.shared.single;
      expect(mail.to, <String>['reports@example.org']);
      expect(mail.subject, '[Fluenough] Support: No sound');
      expect(mail.body, withLog.body);
      expect(mail.body, contains('Attached: fluenough-app-log.txt'));
      expect(mail.files.single.text, 'a line');
      expect(links.asked, isEmpty);

      {
        for (final share in <FixedMailShare>[
          FixedMailShare(shares: false),
          FixedMailShare(error: PlatformException(code: 'failed')),
          FixedMailShare(error: MissingPluginException()),
          FixedMailShare(error: StateError('not an Exception')),
        ]) {
          final links = FixedLinks();
          final outcome = await MailReportSender(
            address: 'reports@example.org',
            links: links,
            share: share,
          ).send(withLog);
          expect(
            outcome,
            isA<ReportInMailApp>().having(
              (o) => o.filesLeftOut,
              'left out',
              true,
            ),
            reason: '${share.error}',
          );
          final url = links.asked.single;
          expect(
            url,
            reportMailto(
              'reports@example.org',
              withLog.withoutFiles(),
            ).toString(),
          );
          expect(
            Uri.parse(url).queryParameters['body'],
            isNot(contains('Attached')),
          );
        }
      }

      expect(
        await MailReportSender(
          address: 'reports@example.org',
          links: FixedLinks(opens: false),
          share: FixedMailShare(shares: false),
        ).send(withLog),
        isA<ReportFailed>().having(
          (f) => f.reason,
          'reason',
          ReportFailure.noMailApp,
        ),
      );
    });
  });

  group('the share', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late Directory folder;

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('fluenough-share');
      addTearDown(() => folder.delete(recursive: true));
    });

    /// Answers the channel as MainActivity would, with [answer], and records
    /// each call.
    List<MethodCall> answer(Object? answer) {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(ChannelSystemSettings.defaultChannel, (
        call,
      ) async {
        calls.add(call);
        return answer;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          ChannelSystemSettings.defaultChannel,
          null,
        ),
      );
      return calls;
    }

    void onAndroid() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    }

    ChannelMailShare share() =>
        ChannelMailShare(folder: Directory('${folder.path}/shared'));

    test('it asks MainActivity, on the channel tools/brand_android.py writes, '
        'with the files written to the shared folder', () async {
      onAndroid();
      final calls = answer(true);
      final shared = await share().share(
        to: <String>['fluenough@gmail.com'],
        subject: '[Fluenough] Bug: x',
        body: 'It froze',
        files: const <AttachedFile>[
          AttachedFile(
            name: 'fluenough-app-log.txt',
            text: 'line one\nline two',
          ),
        ],
      );
      expect(shared, isTrue);
      expect(ChannelSystemSettings.defaultChannel.name, 'app.fluenough/system');
      final call = calls.single;
      expect(call.method, 'shareFiles');
      final args = call.arguments as Map<Object?, Object?>;
      expect(args['to'], <String>['fluenough@gmail.com']);
      expect(args['subject'], '[Fluenough] Bug: x');
      expect(args['text'], 'It froze');
      expect(args['mimeType'], 'text/plain');
      final path = (args['files']! as List<Object?>).single! as String;
      expect(path, '${folder.path}/shared/fluenough-app-log.txt');
      expect(File(path).readAsStringSync(), 'line one\nline two');
    });
  });

  group('Report a problem', () {
    testWidgets(
      'a report needs a title, then goes to the mail app; with no mail app '
      'it says why',
      (tester) async {
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
        expect(find.text(contextLines(device)), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(l10n.reportEditable),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(l10n.reportPublic), findsOneWidget);
        expect(find.text(l10n.reportPrivate), findsNothing);

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
        expect(report.prompts, <String>[
          l10n.reportPromptBugSteps,
          l10n.reportPromptBugExpected,
        ]);
        expect(report.files, isEmpty);
        expect(report.context, <String, String>{
          'Screen': '/deck',
          'Showing': 'hi-en-market',
        });
        expect(find.text(l10n.reportInMailApp), findsOneWidget);

        {
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
        }
      },
    );
  });

  group('the log in a report', () {
    testWidgets('ticked, the whole log goes as a file; unticked, none', (
      tester,
    ) async {
      final reports = _Sender();
      await _pumpReportLog(tester, reports: reports);
      await _send(tester);
      expect(reports.sent.single.files, isEmpty);
      expect(reports.sent.single.body, isNot(contains('Attached')));

      {
        final reports = _Sender();
        final log = await _pumpReportLog(tester, reports: reports);
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
      }
    });
  });

  group('incoming features', () {
    Future<List<bool>> pumpToggle(
      WidgetTester tester,
      FeatureRegistry features,
    ) async {
      final changes = <bool>[];
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return GroupedList.settings(
                header: l10n.settingsSectionReminder,
                children: <Widget>[
                  GroupedTile.toggle(
                    title: l10n.settingsReminder,
                    subtitleOn: l10n.settingsReminderOn('7:30 PM'),
                    subtitleOff: l10n.settingsReminderOff,
                    value: false,
                    onChanged: changes.add,
                    feature: Feature.reminder,
                  ),
                ],
              );
            },
          ),
        ),
        state: AppState.test(features: features),
      );
      return changes;
    }

    group('IncomingFeature', () {
      testWidgets('an incoming feature is dimmed, badged, and does nothing', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        var pressed = 0;
        await pumpWrapped(
          tester,
          features: const FeatureRegistry.shipped(),
          onPressed: () => pressed++,
        );
        final l10n = l10nOf(tester);

        expect(find.text(l10n.incomingBadge), findsOneWidget);
        final opacity = tester.widget<Opacity>(
          find.ancestor(of: find.byType(_Live), matching: find.byType(Opacity)),
        );
        expect(opacity.opacity, kIncomingOpacity);

        expect(
          tester.getSemantics(find.byType(IncomingFeature)),
          matchesSemantics(
            label: l10n.incomingSemanticsLabel(l10n.settingsReminder),
            hint: l10n.incomingSemanticsHint,
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: true,
          ),
        );

        await tester.tap(find.byType(IncomingFeature));
        await tester.pump();
        expect(pressed, 0, reason: 'the child gets no touches');
        expect(find.text(l10n.incomingSnackBar), findsOneWidget);
        handle.dispose();

        {
          final handle = tester.ensureSemantics();
          final changes = await pumpToggle(
            tester,
            const FeatureRegistry.shipped(),
          );
          final l10n = l10nOf(tester);

          expect(find.text(l10n.incomingBadge), findsOneWidget);
          expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
          expect(
            tester.getSemantics(find.byType(GroupedTile)),
            matchesSemantics(
              label: l10n.incomingSemanticsLabel(l10n.settingsReminder),
              hint: l10n.incomingSemanticsHint,
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              hasTapAction: true,
            ),
          );
          await tester.tap(find.byType(GroupedTile));
          await tester.pump();
          expect(changes, isEmpty);
          expect(find.text(l10n.incomingSnackBar), findsOneWidget);
          handle.dispose();
        }
      });
    });
  });

  group('the PIN', () {
    testWidgets('the right PIN opens the profile; a wrong one opens nothing', (
      tester,
    ) async {
      final state = await _pumpPinPage(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.pinGreeting('Aro')), findsOneWidget);
      expect(find.text(l10n.pinPrompt(4)), findsOneWidget);

      await _enter(tester, '1234');

      expect(state.currentProfile.id, 'aro');
      expect(find.text(l10n.pinWrong), findsNothing);

      {
        final semantics = tester.ensureSemantics();
        final state = await _pumpPinPage(tester);
        final l10n = l10nOf(tester);

        await _enter(tester, '1111');

        expect(state.currentProfile.id, 'mira');
        expect(find.text(l10n.pinWrong), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.pinEntered(0, 4)), findsOneWidget);

        // The next digit starts again, and the prompt comes back.
        await _enter(tester, '1');
        expect(find.text(l10n.pinPrompt(4)), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.pinEntered(1, 4)), findsOneWidget);
        semantics.dispose();
      }
    });
  });
}
