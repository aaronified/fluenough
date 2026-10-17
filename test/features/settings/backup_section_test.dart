import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/backup_files.dart';
import 'package:fluenough/app/backups.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/backup/zip_files.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/settings/backup_section.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/backup_fixture.dart';
import '../../support/harness.dart';
import 'support.dart';

/// The shipped registry, in which restore is on (owner, 2026-10-17:
/// "Logged exception").
const FeatureRegistry _restoreOn = FeatureRegistry.shipped();

void main() {
  test('local backup and restore ship; the cloud waits on #112', () {
    expect(Feature.localBackup.issue, 470);
    expect(Feature.available, contains(Feature.localBackup));
    expect(Feature.localRestore.issue, 470);
    expect(Feature.available, contains(Feature.localRestore));
    expect(Feature.cloudBackup.issue, 112);
    expect(Feature.available, isNot(contains(Feature.cloudBackup)));
  });

  testWidgets('Backup and restore is the first group of Your data: Back up '
      'now, Restore from a file, Cloud, Recent backups, and what a backup '
      'holds, in that order', (tester) async {
    usePhone(tester);
    tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
    await pumpScreen(tester, const YourDataPage());
    final l10n = l10nOf(tester);
    expect(BackupSection.services(l10n).toSet(), hasLength(5));

    var above = -1.0;
    for (final text in <String>[
      l10n.settingsDataBackup,
      l10n.settingsDataBackupIntro,
      l10n.settingsDataBackupNow,
      l10n.settingsDataRestore,
      l10n.settingsDataCloud,
      l10n.settingsDataConnect,
      l10n.settingsDataRecentDesc,
      l10n.settingsDataRecentNote,
      l10n.settingsDataBackupPrivacy,
      l10n.settingsDataLog,
    ]) {
      final finder = find.text(text).first;
      expect(finder, findsOneWidget, reason: text);
      final top = tester.getTopLeft(finder).dy;
      expect(top, greaterThan(above), reason: text);
      above = top;
    }
  });

  testWidgets('Back up now and Restore from a file are live; Connect a '
      'cloud reads as incoming, and tapping it only says so', (tester) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    final state = await pumpScreen(tester, const YourDataPage());
    final l10n = l10nOf(tester);
    final before = state.settings.toStored();

    for (final title in <String>[l10n.settingsDataConnect]) {
      final node = find.bySemanticsLabel(l10n.incomingSemanticsLabel(title));
      await scrollTo(tester, node);
      expect(node, findsOneWidget, reason: title);
      await tester.tap(node, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(l10n.incomingSnackBar), findsOneWidget, reason: title);
      await clearSnackBars(tester);
    }
    for (final live in <String>[
      l10n.settingsDataBackupNow,
      l10n.settingsDataRestore,
    ]) {
      expect(
        find.bySemanticsLabel(l10n.incomingSemanticsLabel(live)),
        findsNothing,
        reason: live,
      );
    }
    expect(state.settings.toStored(), before);
    semantics.dispose();
  });

  testWidgets('Back up now saves the file where the learner chooses, keeps a '
      'copy, and lists it', (tester) async {
    usePhone(tester);
    final files = FixedBackupFiles();
    final state = await pumpScreen(
      tester,
      const YourDataPage(),
      state: AppState.test(backupFiles: files),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.settingsDataBackupNow));
    await tester.pumpAndSettle();
    expect(files.saved, hasLength(1));
    expect(files.saved.single.name, endsWith('.fnbackup'));
    expect(find.text(l10n.settingsDataBackedUp), findsOneWidget);
    expect(state.backups.recent, hasLength(1));
    expect(find.text(l10n.settingsBackupMadeByYou('Sep 28')), findsOneWidget);
    expect(find.text(l10n.settingsBackupReviews(0)), findsOneWidget);
    expect(find.text(l10n.settingsDataRecentDesc), findsNothing);
  });

  testWidgets('cancelling the save keeps nothing and says nothing', (
    tester,
  ) async {
    usePhone(tester);
    final files = FixedBackupFiles(saves: false);
    final state = await pumpScreen(
      tester,
      const YourDataPage(),
      state: AppState.test(backupFiles: files),
    );
    await tester.tap(find.text(l10nOf(tester).settingsDataBackupNow));
    await tester.pumpAndSettle();
    expect(state.backups.recent, isEmpty);
    expect(find.text(l10nOf(tester).settingsDataBackedUp), findsNothing);
  });

  group('Recent backups', () {
    testWidgets('are the kept ones, named by how and when, each with '
        'Download, Send to cloud and Restore', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
      final app = await stateWithBackups();
      await pumpScreen(tester, const YourDataPage(), state: app.state);
      final l10n = l10nOf(tester);
      for (final name in <String>[
        l10n.settingsBackupMadeByYou('Sep 28'),
        l10n.settingsBackupBeforeUpdate('0.5.3', 'Sep 26'),
        l10n.settingsBackupBeforeRestore('Sep 18'),
        l10n.settingsBackupFromFile('Sep 18'),
        l10n.settingsBackupBeforeUpdate('0.5.2', 'Sep 8'),
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text(l10n.settingsBackupReviews(6)), findsOneWidget);
      expect(find.text(l10n.settingsBackupDownload), findsNWidgets(5));
      expect(find.text(l10n.settingsBackupSendToCloud), findsNWidgets(5));
      expect(find.text(l10n.settingsBackupRestore), findsNWidgets(5));
    });

    testWidgets('Download saves the backup as it was made', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
      final app = await stateWithBackups();
      await pumpScreen(tester, const YourDataPage(), state: app.state);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.settingsBackupDownload).first);
      await tester.pumpAndSettle();
      expect(app.files.saved, hasLength(1));
      expect(
        ZipFiles.decode(app.files.saved.single.bytes),
        contains('manifest.json'),
      );
      expect(
        find.text(l10n.settingsBackupSaved(app.files.saved.single.name)),
        findsOneWidget,
      );
    });

    testWidgets('above 1.3x text the three are icons alone, 48 dp, named by '
        'tooltips', (tester) async {
      usePhone(tester, textScale: 1.4);
      tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
      final semantics = tester.ensureSemantics();
      final app = await stateWithBackups();
      await pumpScreen(tester, const YourDataPage(), state: app.state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.settingsBackupDownload), findsNothing);
      expect(find.byTooltip(l10n.settingsBackupDownload), findsNWidgets(5));
      expect(find.byTooltip(l10n.settingsBackupRestore), findsNWidgets(5));
      final size = tester.getSize(
        find.byTooltip(l10n.settingsBackupRestore).first,
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel(l10n.settingsBackupRestore),
        findsNWidgets(5),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('Restore', () {
    testWidgets('on a kept backup shows what it holds before anything '
        'changes, and Cancel changes nothing', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
      final app = await stateWithBackups(features: _restoreOn);
      await pumpScreen(tester, const YourDataPage(), state: app.state);
      final l10n = l10nOf(tester);
      final before = app.state.settings.toStored();
      await tester.tap(find.text(l10n.settingsBackupRestore).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsRestoreTitle), findsOneWidget);
      expect(
        find.text(l10n.settingsBackupMadeByYou('Sep 28')),
        findsNWidgets(2),
      );
      expect(find.text(l10n.settingsRestoreByApp('0.5.0')), findsOneWidget);
      expect(
        find.text(l10n.settingsRestoreProgressIn(6, 'Bengali and Hindi')),
        findsOneWidget,
      );
      expect(find.text(l10n.settingsRestoreAlsoText), findsOneWidget);
      expect(find.text(l10n.settingsRestoreNotRestored), findsOneWidget);
      expect(
        find.text(l10n.settingsRestoreDecks('Bengali and Hindi')),
        findsOneWidget,
      );
      expect(find.text(l10n.settingsRestoreWarning), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsRestoreTitle), findsNothing);
      expect(app.state.settings.toStored(), before);
      expect(app.state.progress.log, isEmpty);
      expect(await app.store.list(), hasLength(5), reason: 'no copy kept');
    });

    testWidgets('Replace and restore replaces everything and keeps a copy '
        'first', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
      final app = await stateWithBackups(features: _restoreOn);
      app.state.progress.record(
        deckId: 'hi-en-market',
        cardId: 'hi-0231',
        mode: DrillMode.production,
        grade: 3,
        now: DateTime(2026, 9, 28, 19),
      );
      await pumpScreen(tester, const YourDataPage(), state: app.state);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.settingsBackupRestore).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsRestoreConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsDataRestored), findsOneWidget);
      expect(app.state.progress.log, hasLength(6));
      expect(
        app.state.progress.log.map((e) => e.cardId),
        isNot(contains('hi-0231')),
      );
      expect(app.state.settings.speechRate, 0.6);
      expect(
        find.text(l10n.settingsBackupBeforeRestore('Sep 28')),
        findsOneWidget,
      );
    });

    testWidgets('from a file: the summary first, then the restore, and the '
        'file is kept as it was read', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
      final files = FixedBackupFiles();
      final state = AppState.test(
        features: _restoreOn,
        backupFiles: files,
        progress: MemoryProgress(),
      );
      files.toOpen = fixtureBackup(
        at: DateTime(2026, 8, 1, 9, 5),
        reviews: 4,
        appVersion: '0.4.4',
        settings: const <String, String>{'learning_languages': 'hi'},
        downloads: const <String>['hi'],
      ).encode();
      await pumpScreen(tester, const YourDataPage(), state: state);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.settingsDataRestore));
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsRestoreTitle), findsOneWidget);
      expect(
        find.text(l10n.settingsRestoreProgressIn(4, 'Hindi')),
        findsOneWidget,
      );
      expect(state.progress.log, isEmpty, reason: 'nothing before the ok');
      await tester.tap(find.text(l10n.settingsRestoreConfirm));
      await tester.pumpAndSettle();
      expect(state.progress.log, hasLength(4));
      expect(state.settings.learningLanguages, <String>['hi']);
      expect(find.text(l10n.settingsBackupFromFile('Aug 1')), findsNothing);
      expect(
        state.backups.recent.map((b) => b.kind),
        containsAll(<BackupKind>[BackupKind.restore, BackupKind.file]),
      );
    });

    testWidgets('a file from a newer Fluenough is refused, naming the '
        'version, and nothing changes', (tester) async {
      usePhone(tester);
      tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
      final files = FixedBackupFiles();
      final state = AppState.test(features: _restoreOn, backupFiles: files);
      files.toOpen = newerFile('0.7.0');
      await pumpScreen(tester, const YourDataPage(), state: state);
      final l10n = l10nOf(tester);
      final before = state.settings.toStored();
      await tester.tap(find.text(l10n.settingsDataRestore));
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsRestoreNewerTitle), findsOneWidget);
      expect(
        find.text(
          l10n.settingsRestoreNewerBody('0.7.0', state.updates.current),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.settingsRestoreNewerClose));
      await tester.pumpAndSettle();
      expect(state.settings.toStored(), before);
      expect(state.backups.recent, isEmpty);
    });

    testWidgets('a file that is not a backup says so, and nothing changes', (
      tester,
    ) async {
      usePhone(tester);
      final files = FixedBackupFiles();
      final state = AppState.test(features: _restoreOn, backupFiles: files);
      files.toOpen = Uint8List.fromList(<int>[1, 2, 3]);
      await pumpScreen(tester, const YourDataPage(), state: state);
      final l10n = l10nOf(tester);
      final before = state.settings.toStored();
      await tester.tap(find.text(l10n.settingsDataRestore));
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsDataRestoreNotBackup), findsOneWidget);
      expect(find.text(l10n.settingsRestoreTitle), findsNothing);
      expect(state.settings.toStored(), before);
    });

    for (final scale in <double>[1.0, 1.4]) {
      testWidgets('the sheet at $scale text: Replace and restore wraps or '
          'stacks, and stays inside the screen', (tester) async {
        usePhone(tester, textScale: scale);
        final app = await stateWithBackups(features: _restoreOn);
        await pumpScreen(tester, const YourDataPage(), state: app.state);
        final l10n = l10nOf(tester);
        final restore = find.byTooltip(l10n.settingsBackupRestore);
        final target = scale > 1.3
            ? restore.first
            : find.text(l10n.settingsBackupRestore).first;
        await scrollTo(tester, target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        final confirm = find.byKey(const ValueKey<String>('restore-confirm'));
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        final rect = tester.getRect(confirm);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(390));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a restore that fails leaves the app as it was and says so', (
      tester,
    ) async {
      usePhone(tester);
      final files = FixedBackupFiles();
      final state = AppState.test(
        features: _restoreOn,
        backupFiles: files,
        progress: FailingProgress(),
      );
      files.toOpen = fixtureBackup(at: DateTime(2026, 8, 1)).encode();
      state.settings.speechRate = 1.3;
      await pumpScreen(tester, const YourDataPage(), state: state);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.settingsDataRestore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsRestoreConfirm));
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsDataRestoreFailed), findsOneWidget);
      expect(state.settings.speechRate, 1.3);
    });
  });

  testWidgets('with the cloud on, its rows are live and do nothing yet', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const YourDataPage(),
      state: AppState.test(features: FeatureRegistry.all()),
    );
    final l10n = l10nOf(tester);
    final connect = find.text(l10n.settingsDataConnect);
    await scrollTo(tester, connect);
    expect(
      find.ancestor(of: connect, matching: find.byType(GroupedTile)),
      findsOneWidget,
    );
  });
}
