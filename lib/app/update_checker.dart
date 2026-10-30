import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/updates/apk_install.dart';
import '../core/updates/release_check.dart';
import 'app_info.dart';
import 'links.dart';
import 'settings.dart';

/// Where Settings' "Check for updates" is (ADR-0017).
enum UpdateStatus {
  /// Not checked since launch, and no newer version known.
  idle,
  checking,

  /// The newest release is this version, or an earlier one.
  upToDate,

  /// A newer version is out: found now, or by a check before this launch.
  available,

  /// The last check failed; [UpdateChecker.failure] says why.
  failed,

  /// The newer version is downloading; [UpdateChecker.percent] says how far.
  downloading,

  /// Android's installer is open on the download. Whether the learner
  /// installs it, the next launch finds out; if they come back to the app
  /// first, it is [downloaded].
  installing,

  /// The download is kept and not installed: the learner closed Android's
  /// installer (#487). Install opens it again on the same file, with no
  /// download.
  downloaded,

  /// The download or the install stopped; [UpdateChecker.installFailure]
  /// says why.
  installFailed,
}

/// Asks GitHub whether a newer version is out, and installs it (ADR-0017):
/// a check when the learner taps "Check for updates", and at launch, at most
/// once a day, if they have switched on `SettingsNotifier.autoUpdateCheck`;
/// a check and then an install when they tap Download.
///
/// What a check finds is kept in [settings], so that a newer version stays
/// marked after a restart without asking again. A check that reached
/// GitHub, whatever it answered, counts towards the day; one that could not
/// reach it does not, so the next launch tries again.
///
/// A download starts a backup of the app too, in parallel (#470), so that
/// what the update does to the app can be undone; if the backup fails, the
/// update goes on and [backupFailed] says so.
///
/// An install downloads the APK into the app's own storage as
/// [apkFileName] and records its version in [settings]. The first launch
/// at that version or later deletes the file. Until then it is kept: a
/// cancelled install leaves it there, [installDownloaded] opens the installer
/// on it again once it checks out (#487), and a download of another version,
/// or of one that does not check out, replaces it.
class UpdateChecker extends ChangeNotifier {
  UpdateChecker({
    required this._engine,
    required this.settings,
    required this._clock,
    this._installer = const NullApkInstaller(),
    this._downloads = const NullDownloadStore(),
    this._backUp,
    this.current = AppInfo.version,
  });

  /// How long after the last check an automatic one is due.
  static const Duration interval = Duration(days: 1);

  /// The download's name in the app's own storage. Always the same, so that
  /// a newer download replaces an older one.
  static const String apkFileName = 'fluenough-update.apk';

  final SettingsNotifier settings;

  /// This build's version.
  final String current;

  final ReleaseCheckEngine _engine;
  final DateTime Function() _clock;
  final ApkInstaller _installer;
  final DownloadStore _downloads;

  /// Starts a backup of the app, for the version about to download (#470).
  final Future<void> Function(String version)? _backUp;

  UpdateStatus _status = UpdateStatus.idle;
  ReleaseCheckFailure? _failure;
  InstallFailure? _installFailure;
  int _percent = 0;
  ({String version, String? sha256})? _checked;

  /// The download that finished and reached Android's installer in this
  /// launch: its version and size, which a reuse checks the file against.
  ({String version, int? size})? _downloaded;
  Future<void>? _checking;
  Future<void>? _installing;
  bool _cancelling = false;
  bool _disposed = false;
  bool _backupFailed = false;

  UpdateStatus get status => _status == UpdateStatus.idle && updateAvailable
      ? UpdateStatus.available
      : _status;

  /// Why the last check failed, when [status] is [UpdateStatus.failed].
  ReleaseCheckFailure? get failure => _failure;

  /// Why the last install stopped, when [status] is
  /// [UpdateStatus.installFailed].
  InstallFailure? get installFailure => _installFailure;

  /// Whether the backup made with this download failed. The update goes on
  /// without it: a failed backup never blocks an update.
  bool get backupFailed => _backupFailed;

  /// How much of the download is done, from 0 to 100.
  int get percent => _percent;

  /// The newest version a check has found, now or before this launch.
  String? get latest => settings.latestRelease;

  /// Whether a check has found a version newer than [current]. Settings'
  /// tab carries a dot while it is true. Read it inside a builder that
  /// listens to [settings], which keeps it.
  bool get updateAvailable => isNewerVersion(settings.latestRelease, current);

  /// Whether an automatic check is due: switched on, and none reached
  /// GitHub in the last [interval]. A last check later than now, as after
  /// the clock was set back, counts as long ago.
  bool get due {
    if (!settings.autoUpdateCheck) return false;
    final last = settings.lastUpdateCheck;
    final now = _clock();
    return last == null ||
        last.isAfter(now) ||
        now.difference(last) >= interval;
  }

  /// What the app does about updates as it opens: deletes the download of
  /// an update that has installed since, then checks if one is [due].
  Future<void> atLaunch() async {
    await forgetInstalledDownload();
    if (!_disposed) await checkIfDue();
  }

  /// Asks GitHub for the newest release. A check already under way is
  /// joined rather than repeated, and none starts during an install.
  Future<void> check() {
    if (_installing != null) return Future<void>.value();
    return _checking ??= _check().whenComplete(() => _checking = null);
  }

  /// Checks if one is [due].
  Future<void> checkIfDue() => due ? check() : Future<void>.value();

  Future<void> _check() async {
    _status = UpdateStatus.checking;
    _failure = null;
    notifyListeners();
    final release = await _engine.latest();
    if (_disposed) return;
    if (release.failure != ReleaseCheckFailure.offline) {
      settings.lastUpdateCheck = _clock();
    }
    if (release.version case final version? when release.hasApk) {
      settings.latestRelease = version;
      _checked = (version: version, sha256: release.apkSha256);
      _status = isNewerVersion(version, current)
          ? UpdateStatus.available
          : UpdateStatus.upToDate;
    } else if (release.version != null) {
      // The newest release has no APK yet, so the latest-download path has
      // nothing to install, not even an older release's: nothing is newer
      // for now. A check once the workflow has uploaded it finds it.
      settings.latestRelease = null;
      _checked = null;
      _status = UpdateStatus.upToDate;
    } else {
      _failure = release.failure;
      _status = UpdateStatus.failed;
    }
    notifyListeners();
  }

  /// Downloads the newest release's APK and opens Android's installer on
  /// it, checked against the checksum this launch's check found for that
  /// version, if any. An install already under way is joined. Download and
  /// Try again use [checkAndInstall], so that a check always comes first.
  Future<void> install() =>
      _installing ??= _install().whenComplete(() => _installing = null);

  Future<void> _install() async {
    final version = latest;
    if (version == null || !isNewerVersion(version, current)) return;
    final checked = _checked;
    settings.pendingUpdate = version;
    _status = UpdateStatus.downloading;
    _percent = 0;
    _installFailure = null;
    _cancelling = false;
    _backupFailed = false;
    notifyListeners();
    final backUp = _backUp;
    if (backUp != null) {
      // At the same moment as the download, in parallel with it (#470).
      unawaited(_backup(backUp, version));
    }
    _downloaded = null;
    await _run(
      _installer.install(
        AppLinks.latestApk,
        fileName: apkFileName,
        sha256: checked != null && checked.version == version
            ? checked.sha256
            : null,
      ),
      version,
    );
  }

  /// Follows [events] of an install of [version] into the status.
  Future<void> _run(Stream<InstallEvent> events, String version) async {
    await for (final event in events) {
      if (_disposed) return;
      if (event.failure case final failure?) {
        if (failure == InstallFailure.cancelled && _cancelling) {
          _status = UpdateStatus.available;
        } else {
          _installFailure = failure;
          _status = UpdateStatus.installFailed;
        }
      } else if (event.installing) {
        _status = UpdateStatus.installing;
        _downloaded = (
          version: version,
          size: await _downloads.size(apkFileName),
        );
      } else {
        _percent = event.percent ?? _percent;
      }
      notifyListeners();
    }
    // The download stopped without saying why.
    if (!_disposed && _status == UpdateStatus.downloading) {
      if (_cancelling) {
        _status = UpdateStatus.available;
      } else {
        _installFailure = InstallFailure.download;
        _status = UpdateStatus.installFailed;
      }
      notifyListeners();
    }
  }

  Future<void> _backup(
    Future<void> Function(String version) backUp,
    String version,
  ) async {
    try {
      await backUp(version);
    } on Object {
      if (_disposed) return;
      _backupFailed = true;
      notifyListeners();
    }
  }

  /// The downloading row's Cancel: stops the download, and the row offers
  /// it again. The partial file is replaced by the next download.
  Future<void> cancelInstall() async {
    if (_status != UpdateStatus.downloading) return;
    _cancelling = true;
    await _installer.cancel();
  }

  /// Download, and Try again after an install stopped or Android's installer
  /// was closed: checks first, for the newest version and its checksum, then
  /// installs it if it is still newer. So a download is always checked
  /// against GitHub's checksum when it gives one, even when the version
  /// offered was found before this launch.
  ///
  /// A download kept from before that still checks out is not fetched again
  /// (#487): see [installDownloaded].
  Future<void> checkAndInstall() async {
    await check();
    if (_disposed || status != UpdateStatus.available) return;
    if (await _keptDownloadChecksOut()) {
      await installDownloaded();
    } else {
      await install();
    }
  }

  /// Whether the file kept as [apkFileName] is the newest version's whole
  /// download: it is there, is the size the finished download was in this
  /// launch (or, with none in this launch, its SHA-256 is the one GitHub
  /// gave for that version), and is this version's, not an older one's.
  Future<bool> _keptDownloadChecksOut() async {
    final version = latest;
    if (version == null || !isNewerVersion(version, current)) return false;
    final size = await _downloads.size(apkFileName);
    if (size == null || size <= 0) return false;
    final downloaded = _downloaded;
    if (downloaded != null) {
      if (downloaded.version != version) return false;
      if (downloaded.size != null && downloaded.size != size) return false;
    }
    final checked = _checked;
    final sha = checked != null && checked.version == version
        ? checked.sha256
        : null;
    if (sha != null) return await _downloads.sha256(apkFileName) == sha;
    // No checksum to compare with, and no finished download seen in this
    // launch: a half-written file cannot be told from a whole one.
    return downloaded != null;
  }

  /// Install on the downloaded row, and on Installing's: opens Android's
  /// installer on the file already kept, with no download and no second
  /// backup (#487). If the file no longer checks out (gone, another
  /// version, or not the size or checksum of the download) it is deleted
  /// and the update is downloaded again.
  Future<void> installDownloaded() => _installing ??= _installDownloaded()
      .whenComplete(() => _installing = null);

  Future<void> _installDownloaded() async {
    final version = latest;
    if (version == null || !isNewerVersion(version, current)) return;
    if (!await _keptDownloadChecksOut()) {
      await _downloads.delete(apkFileName);
      _downloaded = null;
      if (!_disposed) await _install();
      return;
    }
    settings.pendingUpdate = version;
    _installFailure = null;
    await _run(_installer.installFile(apkFileName), version);
  }

  /// The learner is back in the app. If Android's installer was open on the
  /// download and the app is still here, it was closed without installing,
  /// so the row is [UpdateStatus.downloaded], not Try again (#487).
  void appResumed() {
    if (_disposed || _status != UpdateStatus.installing) return;
    _status = UpdateStatus.downloaded;
    notifyListeners();
  }

  /// The downloaded row's Delete download: deletes the kept file and
  /// forgets it, and the row offers the update again.
  Future<void> deleteDownload() async {
    if (_status != UpdateStatus.downloaded &&
        _status != UpdateStatus.installFailed) {
      return;
    }
    await _downloads.delete(apkFileName);
    _downloaded = null;
    if (_disposed) return;
    settings.pendingUpdate = null;
    _status = UpdateStatus.idle;
    notifyListeners();
  }

  /// Deletes the APK of `SettingsNotifier.pendingUpdate`, and forgets it,
  /// once this build is that version or later: the update installed, or a
  /// later one did. A download not installed yet is kept.
  Future<void> forgetInstalledDownload() async {
    final pending = settings.pendingUpdate;
    if (pending == null || isNewerVersion(pending, current)) return;
    await _downloads.delete(apkFileName);
    _downloaded = null;
    if (!_disposed) settings.pendingUpdate = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
