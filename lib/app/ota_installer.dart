import 'package:ota_update/ota_update.dart';

import '../core/updates/apk_install.dart';

/// [ApkInstaller] through ota_update (ADR-0017). It downloads into
/// `files/ota_update/<fileName>` in the app's own storage, which needs no
/// storage permission, deletes a file of that name first, and opens
/// Android's installer on it through its FileProvider, which
/// `tools/brand_android.py` declares.
class OtaApkInstaller implements ApkInstaller {
  const OtaApkInstaller();

  @override
  Stream<InstallEvent> install(
    String url, {
    required String fileName,
    String? sha256,
  }) async* {
    final Stream<OtaEvent> events;
    try {
      // A new OtaUpdate each time: one keeps its first stream and hands it
      // back, already closed, to every later call.
      events = OtaUpdate().execute(
        url,
        destinationFilename: fileName,
        sha256checksum: sha256,
      );
    } on Exception {
      yield const InstallEvent.failed(InstallFailure.internal);
      return;
    }
    try {
      await for (final event in events) {
        final next = eventOf(event);
        if (next == null) continue;
        yield next;
        // The last event of an install through Android's own installer.
        if (next.installing || next.failure != null) return;
      }
    } on Exception {
      yield const InstallEvent.failed(InstallFailure.internal);
    }
  }

  /// What [event] means for the update, or null for one that says nothing
  /// new.
  static InstallEvent? eventOf(OtaEvent event) => switch (event.status) {
    OtaStatus.DOWNLOADING => InstallEvent.downloading(
      (int.tryParse(event.value ?? '') ?? 0).clamp(0, 100),
    ),
    OtaStatus.INSTALLING => const InstallEvent.installing(),
    // Reported only by the PackageInstaller method, which is not used.
    OtaStatus.INSTALLATION_DONE => null,
    OtaStatus.PERMISSION_NOT_GRANTED_ERROR => const InstallEvent.failed(
      InstallFailure.notAllowed,
    ),
    OtaStatus.DOWNLOAD_ERROR => const InstallEvent.failed(
      InstallFailure.download,
    ),
    OtaStatus.CHECKSUM_ERROR => const InstallEvent.failed(
      InstallFailure.checksum,
    ),
    // ota_update 7.1.0's Java and Dart lists these two in opposite
    // orders, so either one may be the other; both mean Android did not
    // start installing.
    OtaStatus.ALREADY_RUNNING_ERROR || OtaStatus.INSTALLATION_ERROR =>
      const InstallEvent.failed(InstallFailure.install),
    OtaStatus.INTERNAL_ERROR => const InstallEvent.failed(
      InstallFailure.internal,
    ),
    OtaStatus.CANCELED => const InstallEvent.failed(InstallFailure.cancelled),
  };
}
