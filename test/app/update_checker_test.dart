import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/update_checker.dart';
import 'package:fluenough/core/updates/apk_install.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/features/settings/settings_fixtures.dart';

import '../support/harness.dart';

/// Monday 28 September 2026, 19:00: `AppState.test`'s clock.
final DateTime _now = DateTime(2026, 9, 28, 19);

final String _newer = SettingsFixtures.newerVersion;

/// An app whose release check answers [answer], after [gate] if given, and
/// that check.
(AppState, FixedReleaseCheck) _app(
  LatestRelease answer, {
  Completer<void>? gate,
}) {
  final engine = FixedReleaseCheck(answer, gate: gate);
  return (AppState.test(releases: engine, now: _now), engine);
}

AppState _state(LatestRelease answer) => _app(answer).$1;

void main() {
  test('the newer version used in these tests is newer', () {
    expect(isNewerVersion(_newer, AppInfo.version), isTrue);
  });

  group('the automatic check is due at most once a day', () {
    test('never while switched off, which it is at first', () {
      final state = _state(LatestRelease(_newer));
      addTearDown(state.dispose);
      expect(state.settings.autoUpdateCheck, isFalse);
      expect(state.updates.due, isFalse);
      state.settings.lastUpdateCheck = _now.subtract(const Duration(days: 9));
      expect(state.updates.due, isFalse);
    });

    test('on: due if never checked, or a day or more ago', () {
      final state = _state(LatestRelease(_newer));
      addTearDown(state.dispose);
      final settings = state.settings..autoUpdateCheck = true;
      expect(state.updates.due, isTrue, reason: 'never checked');

      for (final (ago, due) in <(Duration, bool)>[
        (Duration.zero, false),
        (const Duration(hours: 2), false),
        (const Duration(hours: 23, minutes: 59), false),
        (const Duration(days: 1), true),
        (const Duration(days: 3), true),
      ]) {
        settings.lastUpdateCheck = _now.subtract(ago);
        expect(state.updates.due, due, reason: '$ago ago');
      }

      // The clock was set back since: the last check is in the future.
      settings.lastUpdateCheck = _now.add(const Duration(days: 30));
      expect(state.updates.due, isTrue);
    });

    test(
      'a check that reached GitHub counts; one that could not does not',
      () async {
        final (state, engine) = _app(
          const LatestRelease.failed(ReleaseCheckFailure.offline),
        );
        addTearDown(state.dispose);
        state.settings.autoUpdateCheck = true;

        await state.updates.checkIfDue();
        expect(engine.checks, 1);
        expect(state.settings.lastUpdateCheck, isNull);
        expect(
          state.updates.due,
          isTrue,
          reason: 'the next launch tries again',
        );

        engine.answer = const LatestRelease.failed(
          ReleaseCheckFailure.rateLimited,
        );
        await state.updates.checkIfDue();
        expect(state.settings.lastUpdateCheck, _now);
        expect(state.updates.due, isFalse);

        await state.updates.checkIfDue();
        expect(engine.checks, 2, reason: 'not again the same day');
      },
    );
  });

  group('a check', () {
    test('that finds a newer version keeps it, and says so', () async {
      final state = _state(LatestRelease(_newer));
      addTearDown(state.dispose);
      final updates = state.updates;
      expect(updates.status, UpdateStatus.idle);

      final checking = updates.check();
      expect(updates.status, UpdateStatus.checking);
      await checking;
      expect(updates.status, UpdateStatus.available);
      expect(updates.latest, _newer);
      expect(updates.updateAvailable, isTrue);
      expect(state.settings.latestRelease, _newer);
      expect(state.settings.lastUpdateCheck, _now);
    });

    test('that finds this version, or an earlier one, is up to date', () async {
      for (final version in <String>[AppInfo.version, '0.0.1']) {
        final state = _state(LatestRelease(version));
        await state.updates.check();
        expect(state.updates.status, UpdateStatus.upToDate, reason: version);
        expect(state.updates.updateAvailable, isFalse);
        state.dispose();
      }
    });

    test('that finds a newer release without its APK is up to date, and '
        'forgets a version the latest path no longer serves', () async {
      final (state, engine) = _app(
        const LatestRelease('99.0.0', hasApk: false),
      );
      addTearDown(state.dispose);
      // Found before, when it was the newest.
      state.settings.latestRelease = _newer;
      expect(state.updates.updateAvailable, isTrue);

      await state.updates.check();
      expect(state.updates.status, UpdateStatus.upToDate);
      expect(state.updates.updateAvailable, isFalse, reason: 'no dot');
      expect(state.settings.latestRelease, isNull);
      expect(state.settings.lastUpdateCheck, _now, reason: 'GitHub answered');

      // Once the workflow has uploaded it.
      engine.answer = const LatestRelease('99.0.0');
      await state.updates.check();
      expect(state.updates.status, UpdateStatus.available);
      expect(state.settings.latestRelease, '99.0.0');
    });

    test('that fails says why, and forgets no version it knew', () async {
      final state = _state(
        const LatestRelease.failed(ReleaseCheckFailure.badReply),
      );
      addTearDown(state.dispose);
      state.settings.latestRelease = _newer;
      await state.updates.check();
      expect(state.updates.status, UpdateStatus.failed);
      expect(state.updates.failure, ReleaseCheckFailure.badReply);
      expect(state.updates.updateAvailable, isTrue);
    });

    test('already under way is joined, not repeated', () async {
      final gate = Completer<void>();
      final (state, engine) = _app(LatestRelease(_newer), gate: gate);
      addTearDown(state.dispose);
      final first = state.updates.check();
      final second = state.updates.check();
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(engine.checks, 1);
    });

    test('found before this launch still shows, until this build catches '
        'up', () {
      final state = _state(const LatestRelease(AppInfo.version));
      addTearDown(state.dispose);
      state.settings.latestRelease = _newer;
      expect(state.updates.status, UpdateStatus.available);
      expect(state.updates.latest, _newer);

      final caughtUp = UpdateChecker(
        engine: const NullReleaseCheck(),
        settings: state.settings,
        clock: state.now,
        current: _newer,
      );
      addTearDown(caughtUp.dispose);
      expect(caughtUp.updateAvailable, isFalse);
      expect(caughtUp.status, UpdateStatus.idle);
    });
  });

  group('at launch', () {
    /// Launches the app with automatic checks [on], the last check [since]
    /// ago, and returns how many checks it made.
    Future<(AppState, int)> launch(
      WidgetTester tester, {
      required bool on,
      Duration? since,
    }) async {
      final (state, engine) = _app(LatestRelease(_newer));
      state.settings
        ..autoUpdateCheck = on
        ..lastUpdateCheck = since == null ? null : _now.subtract(since);
      await pumpApp(tester, state: state);
      return (state, engine.checks);
    }

    testWidgets('switched off, the app never asks', (tester) async {
      final (state, checks) = await launch(tester, on: false);
      expect(checks, 0);
      expect(state.settings.lastUpdateCheck, isNull);
    });

    testWidgets('on, the first launch asks', (tester) async {
      final (state, checks) = await launch(tester, on: true);
      expect(checks, 1);
      expect(state.settings.latestRelease, _newer);
    });

    testWidgets('on, a launch within a day of the last check does not ask', (
      tester,
    ) async {
      final (_, checks) = await launch(
        tester,
        on: true,
        since: const Duration(hours: 5),
      );
      expect(checks, 0);
    });

    testWidgets('on, a launch a day after the last check asks', (tester) async {
      final (_, checks) = await launch(
        tester,
        on: true,
        since: const Duration(hours: 25),
      );
      expect(checks, 1);
    });
  });

  group('the Settings tab', () {
    Badge badge(WidgetTester tester) => tester.widget<Badge>(
      find.descendant(
        of: find.byType(NavigationDestination).last,
        matching: find.byType(Badge),
      ),
    );

    testWidgets('carries a dot while a newer version is known, and says so', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final state = _state(LatestRelease(_newer));
      await pumpApp(tester, state: state);
      final l10n = l10nOf(tester);
      expect(badge(tester).isLabelVisible, isFalse);
      expect(
        find.bySemanticsLabel(RegExp(l10n.navSettingsUpdate)),
        findsNothing,
      );

      await state.updates.check();
      await tester.pumpAndSettle();
      expect(badge(tester).isLabelVisible, isTrue);
      expect(
        find.bySemanticsLabel(RegExp(l10n.navSettingsUpdate)),
        findsOneWidget,
      );

      // This build is the newest: no dot.
      state.settings.latestRelease = AppInfo.version;
      await tester.pumpAndSettle();
      expect(badge(tester).isLabelVisible, isFalse);
      semantics.dispose();
    });

    testWidgets('carries no dot from an automatic check that found nothing '
        'newer', (tester) async {
      final state = _state(const LatestRelease(AppInfo.version));
      state.settings.autoUpdateCheck = true;
      await pumpApp(tester, state: state);
      expect(state.updates.status, UpdateStatus.upToDate);
      expect(badge(tester).isLabelVisible, isFalse);
    });
  });

  group('installing', () {
    final sha = 'ab' * 32;

    /// A checker at [current] on fresh settings, whose check answers
    /// [answer] and whose installer reports [events].
    (UpdateChecker, FixedReleaseCheck, FixedApkInstaller) checker(
      LatestRelease answer,
      List<InstallEvent> events, {
      Completer<void>? gate,
      String current = AppInfo.version,
      MemoryDownloadStore? files,
    }) {
      final engine = FixedReleaseCheck(answer);
      final installer = FixedApkInstaller(events, gate: gate, files: files);
      final updates = UpdateChecker(
        engine: engine,
        settings: SettingsNotifier(),
        clock: () => _now,
        installer: installer,
        downloads: files ?? MemoryDownloadStore(),
        current: current,
      );
      addTearDown(updates.dispose);
      addTearDown(updates.settings.dispose);
      return (updates, engine, installer);
    }

    test('Download records the version, shows its progress, then opens the '
        'installer, with the checksum the check found', () async {
      final gate = Completer<void>();
      final (updates, _, installer) = checker(
        LatestRelease(_newer, apkSha256: sha),
        const <InstallEvent>[
          InstallEvent.downloading(10),
          InstallEvent.downloading(60),
          InstallEvent.installing(),
        ],
        gate: gate,
      );
      await updates.check();
      expect(updates.status, UpdateStatus.available);

      final installing = updates.install();
      await Future<void>.delayed(Duration.zero);
      expect(updates.status, UpdateStatus.downloading);
      expect(updates.percent, 10);
      expect(updates.settings.pendingUpdate, _newer);

      gate.complete();
      await installing;
      expect(updates.status, UpdateStatus.installing);
      expect(updates.percent, 60);
      expect(installer.asked, hasLength(1));
      expect(installer.asked.single.url, AppLinks.latestApk);
      expect(installer.asked.single.fileName, UpdateChecker.apkFileName);
      expect(installer.asked.single.sha256, sha);
    });

    test(
      'Download after a restart checks first, so it has the checksum',
      () async {
        final (updates, engine, installer) = checker(
          LatestRelease(_newer, apkSha256: sha),
          const <InstallEvent>[InstallEvent.installing()],
        );
        // Found before this launch: the dot is on, and no check has run.
        updates.settings.latestRelease = _newer;
        expect(updates.status, UpdateStatus.available);
        await updates.checkAndInstall();
        expect(engine.checks, 1);
        expect(installer.asked.single.sha256, sha);
        expect(updates.status, UpdateStatus.installing);
      },
    );

    test('the install step alone, with no check of that version this launch, '
        'has no checksum to give', () async {
      final (updates, _, installer) = checker(
        LatestRelease(_newer, apkSha256: sha),
        const <InstallEvent>[InstallEvent.installing()],
      );
      updates.settings.latestRelease = _newer;
      await updates.install();
      expect(installer.asked.single.sha256, isNull);
    });

    test('Download installs nothing when the check fails', () async {
      final (updates, _, installer) = checker(
        const LatestRelease.failed(ReleaseCheckFailure.rateLimited),
        const <InstallEvent>[InstallEvent.installing()],
      );
      updates.settings.latestRelease = _newer;
      await updates.checkAndInstall();
      expect(updates.status, UpdateStatus.failed);
      expect(installer.asked, isEmpty);
    });

    test(
      'Cancel stops a download that never ends, and offers it again',
      () async {
        final (updates, _, installer) = checker(
          LatestRelease(_newer),
          const <InstallEvent>[
            InstallEvent.downloading(30),
            InstallEvent.installing(),
          ],
          // Never completes: the download stalls.
          gate: Completer<void>(),
        );
        await updates.check();
        final installing = updates.install();
        await Future<void>.delayed(Duration.zero);
        expect(updates.status, UpdateStatus.downloading);

        await updates.cancelInstall();
        await installing;
        expect(installer.cancels, 1);
        expect(updates.status, UpdateStatus.available);
        expect(updates.installFailure, isNull);
        expect(updates.settings.pendingUpdate, _newer, reason: 'replaced next');

        // Nothing to cancel now.
        await updates.cancelInstall();
        expect(installer.cancels, 1);
      },
    );

    test('a cancel the learner did not ask for is a failure', () async {
      final (updates, _, _) = checker(
        LatestRelease(_newer),
        const <InstallEvent>[InstallEvent.failed(InstallFailure.cancelled)],
      );
      await updates.check();
      await updates.install();
      expect(updates.status, UpdateStatus.installFailed);
      expect(updates.installFailure, InstallFailure.cancelled);
    });

    test(
      'a failure says why and keeps the record; Try again checks first',
      () async {
        final (updates, engine, installer) = checker(
          LatestRelease(_newer, apkSha256: sha),
          const <InstallEvent>[
            InstallEvent.downloading(5),
            InstallEvent.failed(InstallFailure.checksum),
          ],
        );
        await updates.check();
        await updates.install();
        expect(updates.status, UpdateStatus.installFailed);
        expect(updates.installFailure, InstallFailure.checksum);
        expect(updates.settings.pendingUpdate, _newer);

        installer.events = const <InstallEvent>[InstallEvent.installing()];
        await updates.checkAndInstall();
        expect(engine.checks, 2);
        expect(installer.asked, hasLength(2));
        expect(updates.status, UpdateStatus.installing);
        expect(updates.installFailure, isNull);
      },
    );

    test('Try again installs nothing once nothing newer is out', () async {
      final (updates, engine, installer) = checker(
        LatestRelease(_newer),
        const <InstallEvent>[InstallEvent.failed(InstallFailure.download)],
      );
      await updates.check();
      await updates.install();
      engine.answer = const LatestRelease(AppInfo.version);
      await updates.checkAndInstall();
      expect(updates.status, UpdateStatus.upToDate);
      expect(installer.asked, hasLength(1));
    });

    test('a download that stops without a word has failed', () async {
      final (updates, _, _) = checker(
        LatestRelease(_newer),
        const <InstallEvent>[InstallEvent.downloading(30)],
      );
      await updates.check();
      await updates.install();
      expect(updates.status, UpdateStatus.installFailed);
      expect(updates.installFailure, InstallFailure.download);
    });

    test('nothing installs without a newer version, and an install under way '
        'is joined', () async {
      final (updates, _, installer) = checker(
        const LatestRelease(AppInfo.version),
        const <InstallEvent>[InstallEvent.installing()],
      );
      await updates.install();
      await updates.check();
      await updates.install();
      expect(installer.asked, isEmpty);
      expect(updates.settings.pendingUpdate, isNull);

      updates.settings.latestRelease = _newer;
      await Future.wait(<Future<void>>[updates.install(), updates.install()]);
      expect(installer.asked, hasLength(1));
    });

    test(
      'a newer download replaces the one before: one file, one name',
      () async {
        final files = MemoryDownloadStore();
        final (updates, engine, installer) = checker(
          LatestRelease(_newer),
          const <InstallEvent>[
            InstallEvent.downloading(100),
            InstallEvent.installing(),
          ],
          files: files,
        );
        await updates.check();
        await updates.install();
        engine.answer = const LatestRelease('99.0.0');
        await updates.checkAndInstall();
        expect(installer.asked.map((a) => a.fileName), <String>[
          UpdateChecker.apkFileName,
          UpdateChecker.apkFileName,
        ]);
        expect(files.names, <String>{UpdateChecker.apkFileName});
        expect(updates.settings.pendingUpdate, '99.0.0');
      },
    );
  });

  group('the download, after the update', () {
    /// A checker at [current], with the download of [pending] on the phone.
    (UpdateChecker, MemoryDownloadStore) after({
      required String current,
      required String? pending,
    }) {
      final files = MemoryDownloadStore(<String>[UpdateChecker.apkFileName]);
      final settings = SettingsNotifier()..pendingUpdate = pending;
      final updates = UpdateChecker(
        engine: const NullReleaseCheck(),
        settings: settings,
        clock: () => _now,
        downloads: files,
        current: current,
      );
      addTearDown(updates.dispose);
      addTearDown(settings.dispose);
      return (updates, files);
    }

    test('is deleted once this build is that version', () async {
      final (updates, files) = after(current: '0.2.0', pending: '0.2.0');
      await updates.forgetInstalledDownload();
      expect(files.deleted, <String>[UpdateChecker.apkFileName]);
      expect(files.names, isEmpty);
      expect(updates.settings.pendingUpdate, isNull);
    });

    test('is deleted once a later version has installed', () async {
      final (updates, files) = after(current: '0.3.0', pending: '0.2.0');
      await updates.forgetInstalledDownload();
      expect(files.names, isEmpty);
      expect(updates.settings.pendingUpdate, isNull);
    });

    test('is kept while not installed: cancelled, or not yet', () async {
      final (updates, files) = after(current: '0.1.0', pending: '0.2.0');
      await updates.forgetInstalledDownload();
      expect(files.deleted, isEmpty);
      expect(files.names, <String>{UpdateChecker.apkFileName});
      expect(updates.settings.pendingUpdate, '0.2.0');
    });

    test('is not touched when no update was downloaded', () async {
      final (updates, files) = after(current: '0.2.0', pending: null);
      await updates.forgetInstalledDownload();
      expect(files.deleted, isEmpty);
    });

    testWidgets('goes as the app opens after the update', (tester) async {
      final files = MemoryDownloadStore(<String>[UpdateChecker.apkFileName]);
      final state = AppState.test(downloads: files, now: _now);
      state.settings.pendingUpdate = AppInfo.version;
      await pumpApp(tester, state: state);
      expect(files.names, isEmpty);
      expect(state.settings.pendingUpdate, isNull);
    });

    testWidgets('stays as the app opens before the update', (tester) async {
      final files = MemoryDownloadStore(<String>[UpdateChecker.apkFileName]);
      final state = AppState.test(downloads: files, now: _now);
      state.settings.pendingUpdate = _newer;
      await pumpApp(tester, state: state);
      expect(files.names, <String>{UpdateChecker.apkFileName});
      expect(state.settings.pendingUpdate, _newer);
    });
  });
}
