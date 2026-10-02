import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';

import 'package:fluenough/app/ota_installer.dart';
import 'package:fluenough/core/updates/apk_install.dart';

/// ota_update, in place of the plugin: [execute] reports [events] and then,
/// unless [ends], never another word, as a download the server reset does.
class _FakeOta extends OtaUpdate {
  _FakeOta(this.events, {this.ends = false});

  final List<OtaEvent> events;
  final bool ends;

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
    if (ends) controller.close();
    return controller.stream;
  }

  @override
  Future<void> cancel() async => cancels++;
}

Future<List<InstallEvent>> _all(Stream<InstallEvent> events) => events.toList();

void main() {
  InstallEvent? of(OtaStatus status, [String? value]) =>
      OtaApkInstaller.eventOf(OtaEvent(status, value));

  test('progress reads as a percent, kept between 0 and 100', () {
    expect(of(OtaStatus.DOWNLOADING, '45')!.percent, 45);
    expect(of(OtaStatus.DOWNLOADING, '')!.percent, 0);
    expect(of(OtaStatus.DOWNLOADING)!.percent, 0);
    expect(of(OtaStatus.DOWNLOADING, '130')!.percent, 100);
    expect(of(OtaStatus.DOWNLOADING, '45')!.failure, isNull);
  });

  test("the installer opening is the install's last step", () {
    final event = of(OtaStatus.INSTALLING)!;
    expect(event.installing, isTrue);
    expect(event.failure, isNull);
    expect(of(OtaStatus.INSTALLATION_DONE), isNull);
  });

  test('every error status is a failure the row can explain', () {
    final failures = <OtaStatus, InstallFailure>{
      OtaStatus.PERMISSION_NOT_GRANTED_ERROR: InstallFailure.notAllowed,
      OtaStatus.DOWNLOAD_ERROR: InstallFailure.download,
      OtaStatus.CHECKSUM_ERROR: InstallFailure.checksum,
      OtaStatus.ALREADY_RUNNING_ERROR: InstallFailure.install,
      OtaStatus.INSTALLATION_ERROR: InstallFailure.install,
      OtaStatus.INTERNAL_ERROR: InstallFailure.internal,
      OtaStatus.CANCELED: InstallFailure.cancelled,
    };
    for (final status in OtaStatus.values) {
      final event = of(status, 'detail');
      final failure = failures[status];
      if (failure == null) {
        expect(event?.failure, isNull, reason: '$status');
      } else {
        expect(event!.failure, failure, reason: '$status');
        expect(event.installing, isFalse);
      }
    }
    expect(
      failures.values.toSet(),
      InstallFailure.values.toSet(),
      reason: 'every failure has a status that reports it',
    );
  });

  group('on a fake plugin', () {
    test(
      'passes the url, file name and checksum, and ends at the installer',
      () async {
        final ota = _FakeOta(<OtaEvent>[
          OtaEvent(OtaStatus.DOWNLOADING, '40'),
          OtaEvent(OtaStatus.INSTALLING, null),
        ]);
        final installer = OtaApkInstaller(plugin: () => ota);
        final events = await _all(
          installer.install(
            'https://x/app.apk',
            fileName: 'f.apk',
            sha256: 'ab',
          ),
        );
        expect(events.map((e) => e.percent), <int?>[40, null]);
        expect(events.last.installing, isTrue);
        expect(ota.executed.single, (
          url: 'https://x/app.apk',
          fileName: 'f.apk',
          sha256: 'ab',
        ));
      },
    );

    test('a download that goes quiet fails once the watchdog runs out, and '
        'is dropped', () async {
      final ota = _FakeOta(<OtaEvent>[OtaEvent(OtaStatus.DOWNLOADING, '10')]);
      final installer = OtaApkInstaller(
        stall: const Duration(milliseconds: 50),
        plugin: () => ota,
      );
      final events = await _all(
        installer.install('https://x/app.apk', fileName: 'f.apk'),
      ).timeout(const Duration(seconds: 5));
      expect(events.map((e) => e.percent), <int?>[10, null]);
      expect(events.last.failure, InstallFailure.download);
      expect(ota.cancels, 1);
    });

    testWidgets('each event resets the watchdog: only a minute of silence '
        'fails', (tester) async {
      // On the test's clock, so the minute is exact.
      final quiet = StreamController<OtaEvent>();
      addTearDown(quiet.close);
      final installer = OtaApkInstaller(plugin: () => _StreamOta(quiet.stream));
      final events = <InstallEvent>[];
      var done = false;
      installer
          .install('https://x/app.apk', fileName: 'f.apk')
          .listen(events.add, onDone: () => done = true);
      for (var i = 1; i <= 4; i++) {
        await tester.pump(const Duration(seconds: 50));
        quiet.add(OtaEvent(OtaStatus.DOWNLOADING, '${i * 20}'));
      }
      await tester.pump(const Duration(seconds: 59));
      expect(done, isFalse, reason: 'four minutes in, never a minute quiet');
      expect(events.map((e) => e.percent), <int?>[20, 40, 60, 80]);

      await tester.pump(const Duration(seconds: 2));
      expect(done, isTrue);
      expect(events.last.failure, InstallFailure.download);
    });

    testWidgets('a download that never says a word fails after a minute too', (
      tester,
    ) async {
      final quiet = StreamController<OtaEvent>();
      addTearDown(quiet.close);
      final installer = OtaApkInstaller(plugin: () => _StreamOta(quiet.stream));
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
    });

    test('Cancel ends a download that never would, as cancelled', () async {
      final ota = _FakeOta(<OtaEvent>[OtaEvent(OtaStatus.DOWNLOADING, '10')]);
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

    test('a stream that ends, or errs, ends the install', () async {
      final ended = await _all(
        OtaApkInstaller(
          plugin: () => _FakeOta(<OtaEvent>[
            OtaEvent(OtaStatus.DOWNLOADING, '10'),
          ], ends: true),
        ).install('https://x/app.apk', fileName: 'f.apk'),
      ).timeout(const Duration(seconds: 5));
      expect(ended.map((e) => e.percent), <int?>[10]);

      final erred = await _all(
        OtaApkInstaller(
          plugin: () => _StreamOta(Stream<OtaEvent>.error(StateError('no'))),
        ).install('https://x/app.apk', fileName: 'f.apk'),
      ).timeout(const Duration(seconds: 5));
      expect(erred.single.failure, InstallFailure.internal);
    });
  });
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
