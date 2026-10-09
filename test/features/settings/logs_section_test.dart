import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_log.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/log_files.dart';
import 'package:fluenough/core/logs/log_entry.dart';
import 'package:fluenough/features/settings/app_log_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:fluenough/ui/widgets/report_button.dart';

import '../../support/harness.dart';
import 'support.dart';

/// Saves into [saved], or throws [error], in place of the phone's dialog.
class _FakeLogFiles implements LogFiles {
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

/// Settings over a log holding [lines] events, and what it saves to.
Future<({AppLog log, _FakeLogFiles files})> _pump(
  WidgetTester tester, {
  List<String> lines = const <String>['Opened /deck', 'Opened /inspect'],
}) async {
  usePhone(tester);
  final log = AppLog(clock: () => DateTime.utc(2026, 10, 9, 12));
  final files = _FakeLogFiles();
  await pumpScreen(
    tester,
    const SettingsPage(),
    state: AppState.test(log: log, logFiles: files),
  );
  await log.clear();
  lines.forEach(log.event);
  await tester.pumpAndSettle();
  return (log: log, files: files);
}

Future<void> _tapRow(WidgetTester tester, String title) async {
  final row = find.text(title);
  await scrollTo(tester, row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

/// Records what is copied, in place of the phone's clipboard.
List<String> _clipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add(
          (call.arguments as Map<Object?, Object?>)['text']! as String,
        );
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
  return copied;
}

void main() {
  test('the app log ships (#162)', () {
    expect(Feature.available, contains(Feature.logs));
  });

  testWidgets('the Logs section is live: view, copy, export and clear, and '
      'says what the log holds', (tester) async {
    await _pump(tester);
    final l10n = l10nOf(tester);
    final section = find.byWidgetPredicate(
      (w) => w is GroupedList && w.header == l10n.settingsSectionLogs,
    );
    await scrollTo(tester, section);
    for (final title in <String>[
      l10n.settingsLogView,
      l10n.settingsLogCopy,
      l10n.settingsLogExport,
      l10n.settingsLogClear,
    ]) {
      expect(
        find.descendant(of: section, matching: find.text(title)),
        findsOneWidget,
        reason: title,
      );
    }
    expect(find.text(l10n.settingsLogViewDesc(2)), findsOneWidget);
    await scrollTo(tester, find.text(l10n.settingsLogAbout));
    expect(find.text(l10n.settingsLogAbout), findsOneWidget);
  });

  testWidgets('View opens the log, a line an entry, newest at the foot, '
      'with the bug icon', (tester) async {
    final (:log, files: _) = await _pump(tester);
    await _tapRow(tester, l10nOf(tester).settingsLogView);
    expect(find.byType(AppLogPage), findsOneWidget);
    expect(find.byType(ReportButton), findsOneWidget);
    final first = tester.getTopLeft(find.text(log.entries.first.line));
    final last = tester.getTopLeft(find.text(log.entries.last.line));
    expect(first.dy, lessThan(last.dy));
  });

  testWidgets('an empty log says so', (tester) async {
    await _pump(tester, lines: const <String>[]);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.settingsLogViewDesc(0)), findsOneWidget);
    await _tapRow(tester, l10n.settingsLogView);
    expect(find.text(l10n.appLogEmpty), findsOneWidget);
  });

  testWidgets('Copy puts the whole log on the clipboard', (tester) async {
    final copied = _clipboard(tester);
    final (:log, files: _) = await _pump(tester);
    final text = log.text;
    await _tapRow(tester, l10nOf(tester).settingsLogCopy);
    expect(copied, <String>[text]);
    expect(text.split('\n'), hasLength(2));
    expect(find.text(l10nOf(tester).settingsLogCopied), findsOneWidget);
  });

  testWidgets('Export saves it as a text file, and logs that it did', (
    tester,
  ) async {
    final (:log, :files) = await _pump(tester);
    final text = log.text;
    await _tapRow(tester, l10nOf(tester).settingsLogExport);
    expect(files.saved.keys, <String>[appLogFileName]);
    expect(files.saved[appLogFileName]!.text, text);
    expect(files.saved[appLogFileName]!.type, 'text/plain');
    expect(
      find.text(l10nOf(tester).settingsExported(appLogFileName)),
      findsOneWidget,
    );
    expect(log.entries.last.message, 'App log exported');
  });

  testWidgets('an export that fails says so, and is logged as a warning', (
    tester,
  ) async {
    final (:log, :files) = await _pump(tester);
    files.error = const FileSystemLikeException();
    await _tapRow(tester, l10nOf(tester).settingsLogExport);
    expect(find.text(l10nOf(tester).settingsLogExportFailed), findsOneWidget);
    expect(log.entries.last.level, LogLevel.warning);
  });

  testWidgets('Clear asks first; Cancel keeps the log, Clear empties it', (
    tester,
  ) async {
    final (:log, files: _) = await _pump(tester);
    final l10n = l10nOf(tester);
    await _tapRow(tester, l10n.settingsLogClear);
    expect(find.text(l10n.settingsLogClearTitle), findsOneWidget);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(log.entries, hasLength(2));

    await _tapRow(tester, l10n.settingsLogClear);
    await tester.tap(find.text(l10n.settingsLogClearConfirm));
    await tester.pumpAndSettle();
    expect(log.isEmpty, isTrue);
    expect(find.text(l10n.settingsLogCleared), findsOneWidget);
    expect(find.text(l10n.settingsLogViewDesc(0)), findsOneWidget);
  });

  testWidgets('with the log empty, Copy, Export and Clear do nothing', (
    tester,
  ) async {
    final copied = _clipboard(tester);
    final (log: _, :files) = await _pump(tester, lines: const <String>[]);
    final l10n = l10nOf(tester);
    for (final title in <String>[
      l10n.settingsLogCopy,
      l10n.settingsLogExport,
      l10n.settingsLogClear,
    ]) {
      await _tapRow(tester, title);
    }
    expect(copied, isEmpty);
    expect(files.saved, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

/// What a file dialog throws when it cannot save.
class FileSystemLikeException implements Exception {
  const FileSystemLikeException();
}
