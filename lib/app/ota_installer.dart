import 'dart:async';

import 'package:ota_update/ota_update.dart';

import '../core/updates/apk_install.dart';

/// [ApkInstaller] through ota_update (ADR-0017). It downloads into
/// `files/ota_update/<fileName>` in the app's own storage, which needs no
/// storage permission, deletes a file of that name first, and opens
/// Android's installer on it through its FileProvider, which
/// `tools/brand_android.py` declares.
///
/// ota_update's stream can go quiet without ending: 7.1.0 drops a download
/// the server resets (an HTTP/2 RST_STREAM) without a status, and leaves the
/// stream open. So a download that says nothing for [stall] has failed, and
/// [cancel] ends the stream itself rather than wait for the plugin to.
class OtaApkInstaller implements ApkInstaller {
  OtaApkInstaller({
    this.stall = const Duration(seconds: 60),
    this._plugin = OtaUpdate.new,
  });

  /// How long a download may go without an event before it counts as
  /// failed.
  final Duration stall;

  /// A new OtaUpdate each time: one keeps its first stream and hands it
  /// back, already closed, to every later call.
  final OtaUpdate Function() _plugin;

  /// Ends the install under way as cancelled, or null when there is none.
  void Function()? _cancel;

  @override
  Stream<InstallEvent> install(
    String url, {
    required String fileName,
    String? sha256,
  }) {
    final out = StreamController<InstallEvent>();
    StreamSubscription<OtaEvent>? listening;
    Timer? watchdog;
    void end([InstallEvent? last]) {
      if (out.isClosed) return;
      watchdog?.cancel();
      unawaited(listening?.cancel());
      _cancel = null;
      if (last != null) out.add(last);
      unawaited(out.close());
    }

    void watch() {
      watchdog?.cancel();
      watchdog = Timer(stall, () {
        unawaited(_stopPlugin());
        end(const InstallEvent.failed(InstallFailure.download));
      });
    }

    _cancel = () => end(const InstallEvent.failed(InstallFailure.cancelled));
    try {
      final events = _plugin().execute(
        url,
        destinationFilename: fileName,
        sha256checksum: sha256,
      );
      watch();
      listening = events.listen(
        (event) {
          final next = eventOf(event);
          if (next == null) return;
          // The last event of an install through Android's own installer.
          if (next.installing || next.failure != null) {
            end(next);
          } else {
            out.add(next);
            watch();
          }
        },
        onError: (Object _) =>
            end(const InstallEvent.failed(InstallFailure.internal)),
        onDone: end,
      );
    } on Exception {
      end(const InstallEvent.failed(InstallFailure.internal));
    }
    return out.stream;
  }

  @override
  Future<void> cancel() async {
    final cancel = _cancel;
    if (cancel == null) return;
    await _stopPlugin();
    cancel();
  }

  /// Asks ota_update to drop its download, which it may already have.
  Future<void> _stopPlugin() async {
    try {
      await _plugin().cancel();
    } on Exception {
      // Nothing to cancel, or no plugin: the stream ends either way.
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
