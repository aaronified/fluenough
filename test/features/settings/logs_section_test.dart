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

/// The app log over a log holding [lines] events, and what it saves to.
Future<({AppLog log, _FakeLogFiles files})> _pump(
  WidgetTester tester, {
  List<String> lines = const <String>['Opened /deck', 'Opened /inspect'],
  double textScale = 1.0,
}) async {
  usePhone(tester, textScale: textScale);
  final log = AppLog(clock: () => DateTime.utc(2026, 10, 9, 12));
  final files = _FakeLogFiles();
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

  testWidgets('the Settings tab has an App log row that says how many lines '
      'it holds and opens the log', (tester) async {
    usePhone(tester);
    final log = AppLog(clock: () => DateTime.utc(2026, 10, 9, 12));
    await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(log: log),
    );
    await log.clear();
    log.event('Opened /deck');
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    expect(find.text(l10n.settingsSumLog(1)), findsOneWidget);
    final row = find.text(l10n.settingsRowLog);
    await scrollTo(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(AppLogPage), findsOneWidget);
  });

  testWidgets('shows the log a line an entry, newest at the foot, with the '
      'bug icon, and Copy, Export and Clear in a bottom bar', (tester) async {
    final (:log, files: _) = await _pump(tester);
    final l10n = l10nOf(tester);
    final first = tester.getTopLeft(find.text(log.entries.first.line));
    final last = tester.getTopLeft(find.text(log.entries.last.line));
    expect(first.dy, lessThan(last.dy));
    // Icon over word, in that order, below the log.
    final bottom = tester.getBottomLeft(find.text(log.entries.last.line)).dy;
    var left = -1.0;
    for (final (icon, word) in <(IconData, String)>[
      (Icons.copy_outlined, l10n.appLogCopy),
      (Icons.file_download_outlined, l10n.appLogExport),
      (Icons.delete_outline, l10n.appLogClear),
    ]) {
      final text = find.text(word);
      expect(text, findsOneWidget, reason: word);
      expect(tester.getTopLeft(text).dy, greaterThan(bottom));
      expect(
        tester.getTopLeft(find.byIcon(icon)).dy,
        lessThan(tester.getTopLeft(text).dy),
      );
      expect(tester.getTopLeft(text).dx, greaterThan(left));
      left = tester.getTopLeft(text).dx;
    }
  });

  testWidgets('Clear is in the error colour, text and icon', (tester) async {
    await _pump(tester);
    final l10n = l10nOf(tester);
    final error = Theme.of(tester.element(find.byType(AppLogPage)))
        .colorScheme
        .error;
    expect(
      tester.widget<Text>(find.text(l10n.appLogClear)).style!.color,
      error,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.delete_outline)).color, error);
  });

  testWidgets('at 2.0 text the words go and the icons stay, named by their '
      'tooltips', (tester) async {
    await _pump(tester, textScale: 2.0);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.appLogCopy), findsNothing);
    expect(find.byTooltip(l10n.settingsLogCopy), findsOneWidget);
    expect(find.byTooltip(l10n.settingsLogExport), findsOneWidget);
    expect(find.byTooltip(l10n.settingsLogClear), findsOneWidget);
    for (final icon in <IconData>[
      Icons.copy_outlined,
      Icons.file_download_outlined,
      Icons.delete_outline,
    ]) {
      expect(tester.getSize(find.byIcon(icon)).width, greaterThan(0));
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.byIcon(icon),
                matching: find.byType(InkWell),
              ),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets('an empty log says so', (tester) async {
    await _pump(tester, lines: const <String>[]);
    expect(find.text(l10nOf(tester).appLogEmpty), findsOneWidget);
  });

  testWidgets('Copy puts the whole log on the clipboard', (tester) async {
    final copied = _clipboard(tester);
    final (:log, files: _) = await _pump(tester);
    final text = log.text;
    await _tap(tester, l10nOf(tester).appLogCopy);
    expect(copied, <String>[text]);
    expect(text.split('\n'), hasLength(2));
    expect(find.text(l10nOf(tester).settingsLogCopied), findsOneWidget);
  });

  testWidgets('Export saves it as a text file, and logs that it did', (
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
  });

  testWidgets('an export that fails says so, and is logged as a warning', (
    tester,
  ) async {
    final (:log, :files) = await _pump(tester);
    files.error = const FileSystemLikeException();
    await _tap(tester, l10nOf(tester).appLogExport);
    expect(find.text(l10nOf(tester).settingsLogExportFailed), findsOneWidget);
    expect(log.entries.last.level, LogLevel.warning);
  });

  testWidgets('Clear asks first; Cancel keeps the log, Clear empties it', (
    tester,
  ) async {
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
  });

  testWidgets('with the log empty, Copy, Export and Clear do nothing', (
    tester,
  ) async {
    final copied = _clipboard(tester);
    final (log: _, :files) = await _pump(tester, lines: const <String>[]);
    final l10n = l10nOf(tester);
    for (final title in <String>[
      l10n.appLogCopy,
      l10n.appLogExport,
      l10n.appLogClear,
    ]) {
      await tester.tap(find.text(title), warnIfMissed: false);
      await tester.pumpAndSettle();
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
