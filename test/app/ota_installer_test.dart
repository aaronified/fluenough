import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';

import 'package:fluenough/app/ota_installer.dart';
import 'package:fluenough/core/updates/apk_install.dart';

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
}
