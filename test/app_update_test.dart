// App update: checked at most once a day and off at first; a newer release
// kept, a failure says why; the download fails after a minute of silence
// and Cancel ends it; the old APK is deleted after the update; release
// notes asked for only when opened.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/ota_installer.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/update_checker.dart';
import 'package:fluenough/core/updates/apk_install.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/core/updates/release_notes.dart';
import 'package:fluenough/features/settings/release_notes_page.dart';
import 'package:fluenough/features/settings/settings_fixtures.dart';
import 'package:fluenough/features/settings/update_section.dart';
import 'package:fluenough/features/settings/updates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';

import 'support/settings_pages.dart';
import 'support/harness.dart';

// From update_checker_test.dart.
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

// From release_check_test.dart.
/// Answers one request in place of the network: [reply] gives the status and
/// the body's bytes, and never answers if it never completes.
class _FakeClient implements HttpClient {
  _FakeClient(this.reply);

  final Future<(int, List<int>)> Function() reply;
  Uri? asked;
  final Map<String, Object> sent = <String, Object>{};
  bool closed = false;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    asked = url;
    return _FakeRequest(this);
  }

  @override
  void close({bool force = false}) => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.client);

  final _FakeClient client;

  @override
  HttpHeaders get headers => _FakeHeaders(client.sent);

  @override
  Future<HttpClientResponse> close() async {
    final (status, bytes) = await client.reply();
    return _FakeResponse(status, bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  _FakeHeaders(this.sent);

  final Map<String, Object> sent;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      sent[name] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode, this.bytes);

  @override
  final int statusCode;
  final List<int> bytes;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// From ota_installer_test.dart.
/// ota_update, in place of the plugin: [execute] reports [events] and then
/// never another word, as a download the server reset does.
class _FakeOta extends OtaUpdate {
  _FakeOta(this.events);

  final List<OtaEvent> events;

  final List<({String url, String? fileName, String? sha256})> executed =
      <({String url, String? fileName, String? sha256})>[];
  int cancels = 0;

  @override
  Stream<OtaEvent> execute(
    String url, {
    Map<String, String> headers = const <String, String>{},
    String? androidProviderAuthority,
    String? destinationFilename,
    String? sha256checksum,
    bool usePackageInstaller = false,
  }) {
    executed.add((
      url: url,
      fileName: destinationFilename,
      sha256: sha256checksum,
    ));
    final controller = StreamController<OtaEvent>();
    events.forEach(controller.add);
    return controller.stream;
  }

  @override
  Future<void> cancel() async => cancels++;
}

/// ota_update whose [execute] hands back [stream].
class _StreamOta extends OtaUpdate {
  _StreamOta(this.stream);

  final Stream<OtaEvent> stream;

  @override
  Stream<OtaEvent> execute(
    String url, {
    Map<String, String> headers = const <String, String>{},
    String? androidProviderAuthority,
    String? destinationFilename,
    String? sha256checksum,
    bool usePackageInstaller = false,
  }) => stream;

  @override
  Future<void> cancel() async {}
}

// From update_section_test.dart.

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
    const UpdatesPage(),
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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// From release_notes_page_test.dart.
/// The lines the release workflow puts above every release's notes.
const String _boiler =
    'Fluenough is GPL-3.0 with an App Store Distribution Exception.\n'
    'Source for this exact build is the tag it was made from.\n\n\n';

final String _newerTag = 'v${SettingsFixtures.newerVersion}';
final String _installedTag = 'v${AppInfo.version}';
const String _olderTag = 'v0.0.1';

/// GitHub's reply for three releases, newest first: one newer than this
/// build, this build's, and an old one with no notes of its own, with a
/// draft and a pre-release among them. Their bodies are as the release
/// workflow writes them, and the page gets them through the same reading
/// as the app does. Published at midday UTC, so that the date is the same
/// in every time zone that matters.
String _reply() {
  Map<String, Object?> release(
    String tag,
    String published,
    String body, {
    bool draft = false,
    bool prerelease = false,
  }) => <String, Object?>{
    'tag_name': tag,
    'name': tag,
    'draft': draft,
    'prerelease': prerelease,
    'published_at': published,
    'body': body,
  };
  return jsonEncode(<Object?>[
    release('v9.9.9', '2026-10-20T12:00:00Z', 'Draft notes', draft: true),
    release(
      _newerTag,
      '2026-10-12T12:00:00Z',
      "$_boiler## What's Changed\n"
          '* **Review by skill** on Today by @aaronified in '
          'https://github.com/aaronified/fluenough/pull/191\n'
          '* Read [the guide](https://example.org/guide) first by @aaronified '
          'in https://github.com/aaronified/fluenough/pull/195\n'
          '\n'
          '**Full Changelog**: https://github.com/aaronified/fluenough/compare/'
          'v0.3.3...v0.4.0',
    ),
    release(
      '$_newerTag-rc1',
      '2026-10-10T12:00:00Z',
      'Pre-release notes',
      prerelease: true,
    ),
    release(
      _installedTag,
      '2026-10-05T12:00:00Z',
      '$_boiler### Fixed\n- Speaking cards keep listening',
    ),
    release(_olderTag, '2026-09-01T12:00:00Z', _boiler),
  ]);
}

/// An engine that answers [_reply], after [gate] if given.
FixedReleaseNotes _listing({Completer<void>? gate}) =>
    FixedReleaseNotes(releaseNotesFromReply(200, _reply()), gate: gate);

FixedReleaseNotes _failing([
  ReleaseCheckFailure failure = ReleaseCheckFailure.offline,
]) => FixedReleaseNotes(ReleaseNotes.failed(failure));

/// The page, settled, on an engine that answers at once.
Future<({AppState state, FixedLinks links})> _pumpNotes(
  WidgetTester tester,
  FixedReleaseNotes engine, {
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
  double height = 844,
}) async {
  usePhone(tester, textScale: textScale);
  tester.view.physicalSize = Size(390 * 3, height * 3);
  final links = FixedLinks();
  final state = await pumpScreen(
    tester,
    const ReleaseNotesPage(),
    state: AppState.test(releaseNotes: engine, links: links),
    themeMode: themeMode,
  );
  return (state: state, links: links);
}

Finder _inAppBar(String text) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(text));

Finder _spinner() => find.byType(CircularProgressIndicator);

/// The [Text] that has a bold run reading exactly [run].
Finder _boldRun(String run) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.textSpan is TextSpan &&
      ((widget.textSpan! as TextSpan).children ?? const <InlineSpan>[]).any(
        (span) =>
            span is TextSpan &&
            span.text == run &&
            span.style?.fontWeight == FontWeight.w700,
      ),
);

void main() {
  group('the update check', () {
    group('the automatic check is due at most once a day', () {
      test('never while switched off, which it is at first; on, due if never '
          'checked or a day or more ago', () {
        final state = _state(LatestRelease(_newer));
        addTearDown(state.dispose);
        expect(state.settings.autoUpdateCheck, isFalse);
        expect(state.updates.due, isFalse);
        state.settings.lastUpdateCheck = _now.subtract(const Duration(days: 9));
        expect(state.updates.due, isFalse);

        {
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
        }
      });
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
    });

    group('installing', () {
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

      group('a cancelled install (#487)', () {
        const apk = UpdateChecker.apkFileName;

        /// A checker whose first download finished and opened Android's
        /// installer, which the learner then closed.
        Future<(UpdateChecker, FixedApkInstaller, MemoryDownloadStore)>
        cancelled(LatestRelease answer) async {
          final files = MemoryDownloadStore()..sizes[apk] = 5000;
          final (updates, _, installer) = checker(answer, const <InstallEvent>[
            InstallEvent.downloading(100),
            InstallEvent.installing(),
          ], files: files);
          await updates.checkAndInstall();
          expect(updates.status, UpdateStatus.installing);
          updates.appResumed();
          expect(updates.status, UpdateStatus.downloaded);
          return (updates, installer, files);
        }

        test('is Downloaded, not installed, and Install opens the installer '
            'on the same file with no download', () async {
          final (updates, installer, files) = await cancelled(
            LatestRelease(_newer),
          );
          await updates.installDownloaded();
          expect(installer.asked, hasLength(1), reason: 'no second download');
          expect(installer.reopened, <String>[apk]);
          expect(updates.status, UpdateStatus.installing);
          expect(files.deleted, isEmpty);
          expect(updates.settings.pendingUpdate, _newer);
        });

        test('Try again and Download use the kept file too', () async {
          final (updates, installer, _) = await cancelled(
            LatestRelease(_newer),
          );
          await updates.checkAndInstall();
          expect(installer.asked, hasLength(1));
          expect(installer.reopened, <String>[apk]);
        });

        test(
          'the backup runs once, with the download, not on Install',
          () async {
            final backedUp = <String>[];
            final files = MemoryDownloadStore();
            final installer = FixedApkInstaller(const <InstallEvent>[
              InstallEvent.installing(),
            ], files: files);
            final updates = UpdateChecker(
              engine: FixedReleaseCheck(LatestRelease(_newer)),
              settings: SettingsNotifier(),
              clock: () => _now,
              installer: installer,
              downloads: files,
              backUp: (version) async => backedUp.add(version),
            );
            addTearDown(updates.dispose);
            addTearDown(updates.settings.dispose);
            await updates.checkAndInstall();
            updates.appResumed();
            await updates.installDownloaded();
            await updates.installDownloaded();
            expect(backedUp, <String>[_newer]);
            expect(installer.reopened, hasLength(2));
          },
        );

        test(
          'a kept file of another size is deleted and downloaded again',
          () async {
            final (updates, installer, files) = await cancelled(
              LatestRelease(_newer),
            );
            files.sizes[apk] = 12;
            await updates.installDownloaded();
            expect(files.deleted, <String>[apk]);
            expect(installer.asked, hasLength(2));
            expect(installer.reopened, isEmpty);
            expect(updates.status, UpdateStatus.installing);
          },
        );

        test('a kept file that is gone is downloaded again', () async {
          final (updates, installer, files) = await cancelled(
            LatestRelease(_newer),
          );
          files.names.clear();
          await updates.installDownloaded();
          expect(installer.asked, hasLength(2));
          expect(installer.reopened, isEmpty);
        });

        test('a kept file whose SHA-256 is not the release\'s is downloaded '
            'again; one that matches is reused', () async {
          final sha = 'ab' * 32;
          final (updates, installer, files) = await cancelled(
            LatestRelease(_newer, apkSha256: sha),
          );
          files.hashes[apk] = 'cd' * 32;
          await updates.installDownloaded();
          expect(installer.asked, hasLength(2));
          expect(installer.asked.last.sha256, sha);
          expect(installer.reopened, isEmpty);

          files.hashes[apk] = sha;
          await updates.checkAndInstall();
          expect(installer.asked, hasLength(2));
          expect(installer.reopened, <String>[apk]);
        });

        test('after a restart a kept file is reused only if its SHA-256 '
            'matches, and downloaded again otherwise', () async {
          final sha = 'ab' * 32;
          for (final (kept, reused) in <(String?, bool)>[
            (sha, true),
            ('cd' * 32, false),
            (null, false),
          ]) {
            final files = MemoryDownloadStore(<String>[apk]);
            if (kept != null) files.hashes[apk] = kept;
            final (updates, _, installer) = checker(
              LatestRelease(_newer, apkSha256: sha),
              const <InstallEvent>[InstallEvent.installing()],
              files: files,
            );
            await updates.checkAndInstall();
            expect(installer.reopened, reused ? <String>[apk] : isEmpty);
            expect(installer.asked, hasLength(reused ? 0 : 1));
          }
        });

        test('after a restart with no checksum from GitHub a kept file is '
            'reused if it is the asset\'s size, this version\'s, and the file '
            'whose SHA-256 was recorded', () async {
          final recorded = 'ab' * 32;
          for (final (size, hash, pending, reused)
              in <(int, String?, String?, bool)>[
                (5000, recorded, _newer, true),
                (4999, recorded, _newer, false),
                (5000, 'cd' * 32, _newer, false),
                (5000, null, _newer, false),
                (5000, recorded, null, false),
              ]) {
            final files = MemoryDownloadStore(<String>[apk])
              ..sizes[apk] = size
              ..hashes[apk] = recorded;
            if (hash != null) files.texts[apk] = hash;
            final (updates, _, installer) = checker(
              LatestRelease(_newer, apkSize: 5000),
              const <InstallEvent>[InstallEvent.installing()],
              files: files,
            );
            updates.settings.pendingUpdate = pending;
            await updates.checkAndInstall();
            expect(
              installer.reopened,
              reused ? <String>[apk] : isEmpty,
              reason: '$size $hash $pending',
            );
            expect(installer.asked, hasLength(reused ? 0 : 1));
          }
        });

        test('a download that finishes records its SHA-256 for a later '
            'launch', () async {
          final files = MemoryDownloadStore()
            ..sizes[apk] = 5000
            ..hashes[apk] = 'ab' * 32;
          final (updates, _, _) = checker(
            LatestRelease(_newer),
            const <InstallEvent>[InstallEvent.installing()],
            files: files,
          );
          await updates.checkAndInstall();
          expect(files.texts[apk], 'ab' * 32);
        });

        test('a kept file of an older release is replaced by the newer '
            'one\'s download', () async {
          final files = MemoryDownloadStore()..sizes[apk] = 5000;
          final (updates, engine, installer) = checker(
            LatestRelease(_newer),
            const <InstallEvent>[InstallEvent.installing()],
            files: files,
          );
          await updates.checkAndInstall();
          updates.appResumed();
          engine.answer = const LatestRelease('99.0.0');
          await updates.checkAndInstall();
          expect(installer.asked, hasLength(2));
          expect(installer.reopened, isEmpty);
          expect(updates.settings.pendingUpdate, '99.0.0');
        });

        test(
          'Delete download removes the file and offers the update again',
          () async {
            final (updates, _, files) = await cancelled(LatestRelease(_newer));
            await updates.deleteDownload();
            expect(files.names, isEmpty);
            expect(updates.settings.pendingUpdate, isNull);
            expect(updates.status, UpdateStatus.available);
          },
        );

        test('the file is deleted once the update has installed', () async {
          final (updates, _, files) = await cancelled(LatestRelease(_newer));
          final after = UpdateChecker(
            engine: const NullReleaseCheck(),
            settings: updates.settings,
            clock: () => _now,
            downloads: files,
            current: _newer,
          );
          addTearDown(after.dispose);
          await after.forgetInstalledDownload();
          expect(files.deleted, <String>[apk]);
          expect(updates.settings.pendingUpdate, isNull);
        });
      });
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

      test('the old APK is deleted once this build, or a later one, is that '
          'version', () async {
        final (updates, files) = after(current: '0.2.0', pending: '0.2.0');
        await updates.forgetInstalledDownload();
        expect(files.deleted, <String>[UpdateChecker.apkFileName]);
        expect(files.names, isEmpty);
        expect(updates.settings.pendingUpdate, isNull);

        {
          final (updates, files) = after(current: '0.3.0', pending: '0.2.0');
          await updates.forgetInstalledDownload();
          expect(files.names, isEmpty);
          expect(updates.settings.pendingUpdate, isNull);
        }
      });
    });
  });

  group('releases', () {
    group('versions', () {
      test('only a later version is newer, and a release without '
          'app-release.apk has nothing to install', () {
        LatestRelease reply(Object? json) =>
            releaseFromReply(200, jsonEncode(json));
        expect(isNewerVersion('0.2.0', '0.1.0'), isTrue);
        expect(isNewerVersion('v0.1.1', '0.1.0'), isTrue);
        expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
        expect(isNewerVersion('0.0.9', '0.1.0'), isFalse);
        expect(isNewerVersion(null, '0.1.0'), isFalse);
        expect(isNewerVersion('nightly', '0.1.0'), isFalse);
        expect(isNewerVersion('0.2.0', 'dev'), isFalse);

        // As in the minute before the release workflow uploads it, or on a
        // release made by hand.
        for (final assets in <Object?>[
          null,
          <Object?>[],
          <Object?>[
            <String, Object?>{'name': 'app-debug.apk'},
            <String, Object?>{'name': 'notes.txt'},
          ],
          <Object?>['app-release.apk'],
          'app-release.apk',
        ]) {
          final release = reply(<String, Object?>{
            'tag_name': 'v0.2.0',
            'assets': ?assets,
          });
          expect(release.version, '0.2.0', reason: '$assets');
          expect(release.hasApk, isFalse, reason: '$assets');
          expect(release.apkSha256, isNull, reason: '$assets');
        }
      });
    });
  });

  group('the download', () {
    group('on a fake plugin', () {
      testWidgets(
        'a download that never says a word fails after a minute; Cancel ends '
        'one that never would',
        (tester) async {
          final quiet = StreamController<OtaEvent>();
          addTearDown(quiet.close);
          final installer = OtaApkInstaller(
            plugin: () => _StreamOta(quiet.stream),
          );
          final events = <InstallEvent>[];
          var done = false;
          installer
              .install('https://x/app.apk', fileName: 'f.apk')
              .listen(events.add, onDone: () => done = true);
          await tester.pump(const Duration(seconds: 59));
          expect(done, isFalse);
          await tester.pump(const Duration(seconds: 2));
          expect(done, isTrue);
          expect(events.single.failure, InstallFailure.download);

          await tester.runAsync(() async {
            final ota = _FakeOta(<OtaEvent>[
              OtaEvent(OtaStatus.DOWNLOADING, '10'),
            ]);
            final installer = OtaApkInstaller(plugin: () => ota);
            final events = <InstallEvent>[];
            final done = installer
                .install('https://x/app.apk', fileName: 'f.apk')
                .forEach(events.add);
            await Future<void>.delayed(Duration.zero);
            await installer.cancel();
            await done.timeout(const Duration(seconds: 5));
            expect(events.map((e) => e.percent), <int?>[10, null]);
            expect(events.last.failure, InstallFailure.cancelled);
            expect(ota.cancels, 1);

            // Nothing under way: nothing to cancel.
            await installer.cancel();
            expect(ota.cancels, 1);
          });
        },
      );
    });
  });

  group('the update row', () {
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

    testWidgets('the Download action sits beside the text at 1x and under it '
        'at 1.4x text', (tester) async {
      Future<void> pumpAndCheck(double textScale) async {
        await _pump(tester, LatestRelease(_newer), textScale: textScale);
        final l10n = l10nOf(tester);
        await _tap(tester, find.text(l10n.settingsUpdateCheck));
        final text = tester.getRect(
          find.text(l10n.settingsUpdateAvailable(_newer)),
        );
        final action = tester.getRect(find.text(l10n.settingsUpdateDownload));
        if (textScale > 1.3) {
          expect(action.top, greaterThanOrEqualTo(text.bottom));
        } else {
          expect(action.left, greaterThanOrEqualTo(text.right));
        }
      }

      await pumpAndCheck(1.0);
      await pumpAndCheck(1.4);
    });

    testWidgets('a cancelled install shows Downloaded, not installed, with '
        'Install and Delete download, never Try again (#487)', (tester) async {
      final fakes = await _pump(tester, LatestRelease(_newer));
      final l10n = l10nOf(tester);
      await _tap(tester, find.text(l10n.settingsUpdateCheck));
      await _tap(tester, find.text(l10n.settingsUpdateDownload));
      expect(find.text(l10n.settingsUpdateInstalling(_newer)), findsOneWidget);

      // Android's installer closes and the learner is back in the app.
      fakes.state.updates.appResumed();
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsUpdateDownloaded(_newer)), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsNothing);
      expect(find.text(l10n.settingsUpdateDownload), findsNothing);
      expect(find.text(l10n.settingsUpdateDeleteDownload), findsOneWidget);

      await _tap(tester, find.text(l10n.settingsUpdateInstall));
      expect(fakes.installer.asked, hasLength(1), reason: 'no new download');
      expect(fakes.installer.reopened, <String>[UpdateChecker.apkFileName]);
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
  });

  group('release notes', () {
    group('the row in Updates', () {
      testWidgets(
        'opens the page, which asks GitHub then, and the app asks nothing '
        'at launch',
        (tester) async {
          final engine = _listing();
          usePhone(tester);
          await pumpScreen(
            tester,
            const UpdatesPage(),
            state: AppState.test(releaseNotes: engine),
          );
          final l10n = l10nOf(tester);
          final row = find.ancestor(
            of: find.text(l10n.settingsReleaseNotes),
            matching: find.byType(UpdateSection),
          );
          await scrollTo(tester, find.text(l10n.settingsReleaseNotes));
          await tester.ensureVisible(find.text(l10n.settingsReleaseNotes));
          await tester.pumpAndSettle();
          expect(row, findsOneWidget, reason: 'in the Updates group');
          expect(
            find.descendant(
              of: find.byType(UpdateSection),
              matching: find.text(l10n.settingsReleaseNotesDesc),
            ),
            findsOneWidget,
            reason: 'it says that opening it asks GitHub',
          );
          expect(engine.fetches, 0, reason: 'Settings asks nothing');
          expect(find.byType(ReleaseNotesPage), findsNothing);

          await tester.tap(find.text(l10n.settingsReleaseNotes));
          await tester.pumpAndSettle();

          expect(find.byType(ReleaseNotesPage), findsOneWidget);
          expect(_inAppBar(l10n.releaseNotesTitle), findsOneWidget);
          expect(engine.fetches, 1);
          expect(find.text(_newerTag), findsOneWidget);

          {
            final engine = _listing();
            usePhone(tester);
            await pumpApp(tester, state: AppState.test(releaseNotes: engine));
            expect(engine.fetches, 0);
          }
        },
      );
    });

    group('the list', () {
      testWidgets(
        'lists each release, newest first, marks the installed one, and '
        'offline offers Try again',
        (tester) async {
          // Tall enough that every row is built.
          await _pumpNotes(tester, _listing(), height: 3000);
          final l10n = l10nOf(tester);

          final tops = <double>[
            for (final tag in <String>[_newerTag, _installedTag, _olderTag])
              tester.getTopLeft(find.text(tag)).dy,
          ];
          expect(tops, <double>[...tops]..sort(), reason: 'newest first');
          expect(tops.toSet(), hasLength(3));

          expect(find.text('Oct 12, 2026'), findsOneWidget);
          expect(find.text('Oct 5, 2026'), findsOneWidget);
          expect(find.text('Sep 1, 2026'), findsOneWidget);

          // The notes, as the subset reads them.
          expect(find.text("What's Changed"), findsOneWidget);
          expect(
            find.text(
              'Review by skill on Today by @aaronified in '
              'https://github.com/aaronified/fluenough/pull/191',
            ),
            findsOneWidget,
          );
          expect(_boldRun('Review by skill'), findsOneWidget);
          expect(_boldRun('Full Changelog'), findsOneWidget);
          expect(find.text('Fixed'), findsOneWidget, reason: 'a ### heading');
          expect(find.text('Speaking cards keep listening'), findsOneWidget);
          // A draft and a pre-release are not listed.
          expect(find.text('v9.9.9'), findsNothing);
          expect(find.text('$_newerTag-rc1'), findsNothing);
          expect(find.textContaining('Draft notes'), findsNothing);
          expect(find.textContaining('Pre-release notes'), findsNothing);
          // A link reads as its text, with nothing of its address.
          expect(
            find.textContaining(
              'Read the guide first by @aaronified in '
              'https://github.com/aaronified/fluenough/pull/195',
            ),
            findsOneWidget,
          );
          expect(find.textContaining('example.org/guide'), findsNothing);
          expect(find.textContaining('](', findRichText: true), findsNothing);
          // The workflow's lines are not the notes.
          expect(find.textContaining('App Store Distribution'), findsNothing);
          expect(find.textContaining('this exact build'), findsNothing);
          // A release with no notes says so.
          expect(find.text(l10n.releaseNotesNoNotes), findsOneWidget);
          expect(_spinner(), findsNothing);

          {
            await _pumpNotes(tester, _listing(), height: 3000);
            final l10n = l10nOf(tester);

            expect(find.text(l10n.releaseNotesInstalled), findsOneWidget);
            Finder headingOf(String tag) =>
                find.ancestor(of: find.text(tag), matching: find.byType(Wrap));
            expect(
              find.descendant(
                of: headingOf(_installedTag),
                matching: find.text(l10n.releaseNotesInstalled),
              ),
              findsOneWidget,
            );
            for (final tag in <String>[_newerTag, _olderTag]) {
              expect(
                find.descendant(
                  of: headingOf(tag),
                  matching: find.text(l10n.releaseNotesInstalled),
                ),
                findsNothing,
                reason: tag,
              );
            }
          }

          {
            final engine = _failing();
            await _pumpNotes(tester, engine);
            final l10n = l10nOf(tester);

            expect(find.text(l10n.releaseNotesOffline), findsOneWidget);
            expect(find.text(l10n.commonRetry), findsOneWidget);
            expect(_spinner(), findsNothing);
            expect(find.text(_newerTag), findsNothing);
            expect(engine.fetches, 1);

            // Back on the network: Try again finds the notes.
            engine.answer = releaseNotesFromReply(200, _reply());
            await tester.tap(find.text(l10n.commonRetry));
            await tester.pumpAndSettle();

            expect(engine.fetches, 2);
            expect(find.text(l10n.releaseNotesOffline), findsNothing);
            expect(find.text(l10n.commonRetry), findsNothing);
            expect(find.text(_newerTag), findsOneWidget);
          }
        },
      );
    });
  });
}
