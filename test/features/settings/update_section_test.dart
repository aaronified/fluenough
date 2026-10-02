import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/update_checker.dart';
import 'package:fluenough/core/updates/apk_install.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/features/settings/settings_fixtures.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/update_section.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';
import 'support.dart';

final String _newer = SettingsFixtures.newerVersion;

/// What [_pump] builds Settings on.
typedef _Fakes = ({
  AppState state,
  FixedReleaseCheck engine,
  FixedLinks links,
  FixedApkInstaller installer,
});

/// Settings on a release check that answers [answer] and an installer that
/// reports [events], scrolled to Updates.
Future<_Fakes> _pump(
  WidgetTester tester,
  LatestRelease answer, {
  Completer<void>? gate,
  List<InstallEvent> events = const <InstallEvent>[
    InstallEvent.downloading(100),
    InstallEvent.installing(),
  ],
  Completer<void>? installGate,
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  usePhone(tester, textScale: textScale);
  final engine = FixedReleaseCheck(answer, gate: gate);
  final links = FixedLinks();
  final installer = FixedApkInstaller(events, gate: installGate);
  final state = await pumpScreen(
    tester,
    const SettingsPage(),
    state: AppState.test(releases: engine, links: links, installer: installer),
    themeMode: themeMode,
  );
  await _show(tester);
  return (state: state, engine: engine, links: links, installer: installer);
}

/// Scrolls Settings until the Updates group is built, then to its top.
Future<void> _show(WidgetTester tester) async {
  await scrollTo(tester, find.byType(UpdateSection));
  await tester.ensureVisible(find.byType(UpdateSection));
  await tester.pumpAndSettle();
}

Finder _autoRow(AppLocalizations l10n) => find.ancestor(
  of: find.text(l10n.settingsUpdateAuto),
  matching: find.byType(GroupedTile),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Records what is copied to the clipboard, until the test ends.
ValueGetter<String?> _clipboard(WidgetTester tester) {
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
  return () => copied;
}

void main() {
  testWidgets('Updates sits just above the version line, after backup', (
    tester,
  ) async {
    await _pump(tester, const LatestRelease(AppInfo.version));
    final l10n = l10nOf(tester);
    final heading = find.text(l10n.settingsSectionUpdates);
    final footer = find.text(l10n.settingsFooter(AppInfo.version));
    await scrollTo(tester, footer);
    expect(heading, findsOneWidget);
    expect(
      tester.getTopLeft(footer).dy,
      greaterThan(tester.getBottomLeft(_autoRow(l10n)).dy),
    );
    expect(
      tester.getTopLeft(heading).dy,
      greaterThan(tester.getBottomLeft(find.text(l10n.settingsBackupHelp)).dy),
    );
  });

  testWidgets('before a check it says which version this is, and asks '
      'nothing until tapped', (tester) async {
    final fakes = await _pump(tester, const LatestRelease(AppInfo.version));
    final l10n = l10nOf(tester);
    expect(find.text(l10n.settingsUpdateCheck), findsOneWidget);
    expect(find.text(l10n.settingsUpdateCurrent(AppInfo.version)), findsOne);
    expect(fakes.engine.checks, 0);
    expect(fakes.state.settings.lastUpdateCheck, isNull);
  });

  testWidgets('checking, then up to date; tapped again, it checks again', (
    tester,
  ) async {
    final gate = Completer<void>();
    final fakes = await _pump(
      tester,
      const LatestRelease(AppInfo.version),
      gate: gate,
    );
    final l10n = l10nOf(tester);

    await tester.tap(find.text(l10n.settingsUpdateCheck));
    await tester.pump();
    expect(find.text(l10n.settingsUpdateChecking), findsOneWidget);
    // Tapping while it checks does not ask twice.
    await tester.tap(find.text(l10n.settingsUpdateCheck));
    await tester.pump();
    expect(fakes.engine.checks, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsUpdateChecking), findsNothing);
    final upToDate = find.text(l10n.settingsUpdateUpToDate(AppInfo.version));
    expect(upToDate, findsOneWidget);

    await _tap(tester, upToDate);
    expect(fakes.engine.checks, 2);
    expect(upToDate, findsOneWidget);
  });

  testWidgets('a newer version shows its number; Download fetches the newest '
      'APK into the app, with progress, then opens the installer', (
    tester,
  ) async {
    final sha = 'cd' * 32;
    final installGate = Completer<void>();
    final fakes = await _pump(
      tester,
      LatestRelease(_newer, apkSha256: sha),
      events: const <InstallEvent>[
        InstallEvent.downloading(45),
        InstallEvent.installing(),
      ],
      installGate: installGate,
    );
    final l10n = l10nOf(tester);

    await _tap(tester, find.text(l10n.settingsUpdateCheck));
    expect(find.text(l10n.settingsUpdateAvailable(_newer)), findsOneWidget);
    expect(
      find.text(l10n.settingsUpdateAvailableDesc(AppInfo.version)),
      findsOneWidget,
    );

    await _tap(tester, find.text(l10n.settingsUpdateDownload));
    expect(find.text(l10n.settingsUpdateDownloading(_newer)), findsOneWidget);
    expect(find.text(l10n.settingsUpdatePercent(45)), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.45, 1e-9));
    expect(fakes.state.settings.pendingUpdate, _newer);

    installGate.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsUpdateInstalling(_newer)), findsOneWidget);
    expect(find.text(l10n.settingsUpdateInstallingDesc), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    final asked = fakes.installer.asked.single;
    expect(asked.url, AppLinks.latestApk);
    expect(
      AppLinks.latestApk,
      'https://github.com/aaronified/fluenough/releases/latest/download/'
      'app-release.apk',
    );
    expect(asked.fileName, UpdateChecker.apkFileName);
    expect(asked.sha256, sha);
    expect(fakes.links.asked, isEmpty, reason: 'not through the browser');
  });

  testWidgets('closed the installer? Try again checks and downloads again', (
    tester,
  ) async {
    final fakes = await _pump(tester, LatestRelease(_newer));
    final l10n = l10nOf(tester);
    await _tap(tester, find.text(l10n.settingsUpdateCheck));
    await _tap(tester, find.text(l10n.settingsUpdateDownload));
    expect(find.text(l10n.settingsUpdateInstalling(_newer)), findsOneWidget);
    expect(fakes.engine.checks, 2, reason: 'Download checks first');

    await _tap(tester, find.text(l10n.commonRetry));
    expect(fakes.engine.checks, 3);
    expect(fakes.installer.asked, hasLength(2));
    expect(find.text(l10n.settingsUpdateInstalling(_newer)), findsOneWidget);
  });

  testWidgets('each install failure says why, with Try again and the '
      'download page', (tester) async {
    final fakes = await _pump(
      tester,
      LatestRelease(_newer),
      events: const <InstallEvent>[
        InstallEvent.failed(InstallFailure.notAllowed),
      ],
    );
    final l10n = l10nOf(tester);
    await _tap(tester, find.text(l10n.settingsUpdateCheck));
    await _tap(tester, find.text(l10n.settingsUpdateDownload));

    for (final (failure, says) in <(InstallFailure, String)>[
      (InstallFailure.notAllowed, l10n.settingsUpdateNotAllowed),
      (InstallFailure.download, l10n.settingsUpdateDownloadFailed),
      (InstallFailure.checksum, l10n.settingsUpdateChecksumFailed),
      (InstallFailure.install, l10n.settingsUpdateInstallError),
      (InstallFailure.internal, l10n.settingsUpdateInternalError),
      (InstallFailure.cancelled, l10n.settingsUpdateCancelled),
    ]) {
      if (failure != InstallFailure.notAllowed) {
        fakes.installer.events = <InstallEvent>[
          const InstallEvent.downloading(20),
          InstallEvent.failed(failure),
        ];
        await _tap(tester, find.text(l10n.commonRetry));
      }
      expect(
        find.text(l10n.settingsUpdateInstallFailed(_newer)),
        findsOneWidget,
        reason: '$failure',
      );
      expect(find.text(says), findsOneWidget, reason: '$failure');
      expect(find.text(l10n.commonRetry), findsOneWidget);
      expect(find.text(l10n.settingsUpdateOpenPage), findsOneWidget);
    }
    expect(fakes.installer.asked, hasLength(InstallFailure.values.length));
    // Not allowed says where to allow it.
    expect(l10n.settingsUpdateNotAllowed, contains('Install unknown apps'));
    // The record stays, for the launch after a later install.
    expect(fakes.state.settings.pendingUpdate, _newer);

    fakes.installer.events = const <InstallEvent>[InstallEvent.installing()];
    await _tap(tester, find.text(l10n.commonRetry));
    expect(find.text(l10n.settingsUpdateInstalling(_newer)), findsOneWidget);
  });

  testWidgets('Open download page opens the release in the browser, or '
      'copies its link', (tester) async {
    final copied = _clipboard(tester);
    final fakes = await _pump(
      tester,
      LatestRelease(_newer),
      events: const <InstallEvent>[
        InstallEvent.failed(InstallFailure.download),
      ],
    );
    final l10n = l10nOf(tester);
    await _tap(tester, find.text(l10n.settingsUpdateCheck));
    await _tap(tester, find.text(l10n.settingsUpdateDownload));

    await _tap(tester, find.text(l10n.settingsUpdateOpenPage));
    expect(fakes.links.asked, <String>[AppLinks.latestRelease]);
    expect(
      AppLinks.latestRelease,
      'https://github.com/aaronified/fluenough/releases/latest',
    );
    expect(copied(), isNull);
    expect(find.text(l10n.settingsUpdatePageCopied), findsNothing);

    fakes.links.opens = false;
    await _tap(tester, find.text(l10n.settingsUpdateOpenPage));
    expect(copied(), AppLinks.latestRelease);
    expect(find.text(l10n.settingsUpdatePageCopied), findsOneWidget);
  });

  testWidgets('Download after a restart checks first, and passes GitHub\'s '
      'checksum', (tester) async {
    usePhone(tester);
    final sha = 'ef' * 32;
    final engine = FixedReleaseCheck(LatestRelease(_newer, apkSha256: sha));
    final installer = FixedApkInstaller(const <InstallEvent>[
      InstallEvent.installing(),
    ]);
    final state = AppState.test(releases: engine, installer: installer);
    // The dot from before this launch; no check has run since.
    state.settings.latestRelease = _newer;
    await pumpScreen(tester, const SettingsPage(), state: state);
    final l10n = l10nOf(tester);
    await _tap(tester, find.text(l10n.settingsUpdateDownload));
    expect(engine.checks, 1);
    expect(installer.asked.single.sha256, sha);
    expect(find.text(l10n.settingsUpdateInstalling(_newer)), findsOneWidget);
  });

  testWidgets('Cancel stops a download that never ends, and offers it again', (
    tester,
  ) async {
    final fakes = await _pump(
      tester,
      LatestRelease(_newer),
      events: const <InstallEvent>[
        InstallEvent.downloading(30),
        InstallEvent.installing(),
      ],
      // Never completes.
      installGate: Completer<void>(),
    );
    final l10n = l10nOf(tester);
    await _tap(tester, find.text(l10n.settingsUpdateCheck));
    await _tap(tester, find.text(l10n.settingsUpdateDownload));
    expect(find.text(l10n.settingsUpdatePercent(30)), findsOneWidget);

    await _tap(tester, find.text(l10n.commonCancel));
    expect(fakes.installer.cancels, 1);
    expect(find.text(l10n.settingsUpdateAvailable(_newer)), findsOneWidget);
    expect(find.text(l10n.settingsUpdateDownload), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text(l10n.settingsUpdateCancelled), findsNothing);
  });

  testWidgets('a version found before this launch is offered straight away', (
    tester,
  ) async {
    usePhone(tester);
    final engine = FixedReleaseCheck(const LatestRelease(AppInfo.version));
    final state = AppState.test(releases: engine);
    state.settings.latestRelease = _newer;
    await pumpScreen(tester, const SettingsPage(), state: state);
    final l10n = l10nOf(tester);
    await scrollTo(tester, find.text(l10n.settingsUpdateDownload));
    expect(find.text(l10n.settingsUpdateAvailable(_newer)), findsOneWidget);
    expect(engine.checks, 0);
  });

  testWidgets('each check failure says why, and Try again checks again', (
    tester,
  ) async {
    final fakes = await _pump(
      tester,
      const LatestRelease.failed(ReleaseCheckFailure.offline),
    );
    final engine = fakes.engine;
    final l10n = l10nOf(tester);
    await _tap(tester, find.text(l10n.settingsUpdateCheck));

    for (final (failure, says) in <(ReleaseCheckFailure, String)>[
      (ReleaseCheckFailure.offline, l10n.settingsUpdateOffline),
      (ReleaseCheckFailure.rateLimited, l10n.settingsUpdateRateLimited),
      (ReleaseCheckFailure.badReply, l10n.settingsUpdateBadReply),
    ]) {
      engine.answer = LatestRelease.failed(failure);
      await _tap(tester, find.text(l10n.commonRetry));
      expect(find.text(says), findsOneWidget, reason: '$failure');
      expect(find.text(l10n.commonRetry), findsOneWidget);
    }
    expect(engine.checks, 4);

    engine.answer = LatestRelease(_newer);
    await _tap(tester, find.text(l10n.commonRetry));
    expect(find.text(l10n.settingsUpdateAvailable(_newer)), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsNothing);
  });

  testWidgets('Check automatically is off at first, and switches', (
    tester,
  ) async {
    final fakes = await _pump(tester, const LatestRelease(AppInfo.version));
    final settings = fakes.state.settings;
    final l10n = l10nOf(tester);
    final row = _autoRow(l10n);
    Switch toggle() => tester.widget<Switch>(
      find.descendant(of: row, matching: find.byType(Switch)),
    );
    expect(find.text(l10n.settingsUpdateAutoDesc), findsOneWidget);
    expect(settings.autoUpdateCheck, isFalse);
    expect(toggle().value, isFalse);

    await _tap(tester, row);
    expect(settings.autoUpdateCheck, isTrue);
    expect(toggle().value, isTrue);
    expect(fakes.engine.checks, 0, reason: 'it checks at the next launch');

    await _tap(tester, row);
    expect(settings.autoUpdateCheck, isFalse);
  });

  testWidgets("the row's text is a live region, its buttons are their own, "
      'and a download is announced once, as it starts', (tester) async {
    final semantics = tester.ensureSemantics();
    final installGate = Completer<void>();
    await _pump(
      tester,
      LatestRelease(_newer),
      events: const <InstallEvent>[
        InstallEvent.downloading(30),
        InstallEvent.downloading(80),
        InstallEvent.installing(),
      ],
      installGate: installGate,
    );
    final l10n = l10nOf(tester);
    // One node for the row, a button, heard as its line changes.
    expect(
      tester.getSemantics(find.text(l10n.settingsUpdateCheck)),
      isSemantics(
        label:
            '${l10n.settingsUpdateCheck}\n'
            '${l10n.settingsUpdateCurrent(AppInfo.version)}',
        isButton: true,
        isLiveRegion: true,
        hasTapAction: true,
      ),
    );
    await _tap(tester, find.text(l10n.settingsUpdateCheck));

    // The text, then Download on its own.
    final text = find.text(l10n.settingsUpdateAvailable(_newer));
    expect(
      tester.getSemantics(text),
      isSemantics(
        label:
            '${l10n.settingsUpdateAvailable(_newer)}\n'
            '${l10n.settingsUpdateAvailableDesc(AppInfo.version)}',
        isLiveRegion: true,
        isButton: false,
      ),
    );
    final download = find.text(l10n.settingsUpdateDownload);
    expect(
      tester.getSemantics(download),
      isSemantics(
        label: l10n.settingsUpdateDownload,
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(download).id,
      isNot(tester.getSemantics(text).id),
    );

    // Downloading: the row is not a live region, so the percent is not read
    // out as it changes. Its start is announced, once.
    tester.takeAnnouncements();
    await _tap(tester, download);
    expect(
      tester.getSemantics(find.text(l10n.settingsUpdateDownloading(_newer))),
      isSemantics(
        label:
            '${l10n.settingsUpdateDownloading(_newer)}\n'
            '${l10n.settingsUpdatePercent(30)}',
        isLiveRegion: false,
      ),
    );
    expect(tester.takeAnnouncements(), <Matcher>[
      isAccessibilityAnnouncement(l10n.settingsUpdateDownloading(_newer)),
    ]);
    installGate.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsUpdatePercent(80)), findsNothing);
    expect(tester.takeAnnouncements(), isEmpty, reason: 'no more percents');
    expect(
      tester.getSemantics(find.text(l10n.settingsUpdateInstalling(_newer))),
      isSemantics(isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('at twice the text size, the button goes under the text', (
    tester,
  ) async {
    await _pump(tester, LatestRelease(_newer), textScale: 2.0);
    final l10n = l10nOf(tester);
    await _tap(tester, find.text(l10n.settingsUpdateCheck));
    final desc = find.text(l10n.settingsUpdateAvailableDesc(AppInfo.version));
    final download = find.text(l10n.settingsUpdateDownload);
    await scrollTo(tester, download);
    expect(
      tester.getTopLeft(download).dy,
      greaterThan(tester.getBottomLeft(desc).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('every state fits at twice the text size and meets the '
      'tap-target, label and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    Future<void> check(String what) async {
      await _show(tester);
      expect(tester.takeException(), isNull, reason: what);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    for (final scale in <double>[1.0, 2.0]) {
      for (final dark in <bool>[false, true]) {
        final gate = Completer<void>();
        final installGate = Completer<void>();
        await tester.pumpWidget(const SizedBox.shrink());
        final fakes = await _pump(
          tester,
          LatestRelease(_newer),
          gate: gate,
          events: const <InstallEvent>[
            InstallEvent.downloading(45),
            InstallEvent.installing(),
          ],
          installGate: installGate,
          textScale: scale,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        final l10n = l10nOf(tester);
        final where = '$scale${dark ? ', dark' : ''}';
        await check('idle $where');

        await tester.tap(find.text(l10n.settingsUpdateCheck));
        await tester.pump();
        expect(find.text(l10n.settingsUpdateChecking), findsOne);
        await check('checking $where');
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text(l10n.settingsUpdateDownload), findsOne);
        await check('available $where');

        await _tap(tester, find.text(l10n.settingsUpdateDownload));
        expect(find.text(l10n.settingsUpdatePercent(45)), findsOne);
        await check('downloading $where');
        installGate.complete();
        await tester.pumpAndSettle();
        expect(find.text(l10n.settingsUpdateInstallingDesc), findsOne);
        await check('installing $where');

        fakes.installer
          ..gate = null
          ..events = const <InstallEvent>[
            InstallEvent.failed(InstallFailure.notAllowed),
          ];
        await _tap(tester, find.text(l10n.commonRetry));
        expect(find.text(l10n.settingsUpdateNotAllowed), findsOne);
        await check('install failed $where');

        fakes.engine.answer = const LatestRelease.failed(
          ReleaseCheckFailure.rateLimited,
        );
        await _tap(tester, find.text(l10n.commonRetry));
        expect(find.text(l10n.settingsUpdateRateLimited), findsOne);
        await check('check failed $where');

        fakes.engine.answer = const LatestRelease(AppInfo.version);
        await _tap(tester, find.text(l10n.commonRetry));
        expect(
          find.text(l10n.settingsUpdateUpToDate(AppInfo.version)),
          findsOne,
        );
        await check('up to date $where');
      }
    }
    handle.dispose();
  });
}
