/// Which files the app made as temporary or cache are junk (#493). Pure: it
/// sees names and ages, never the disk, so the policy is tested without a
/// file system. Nothing here can name the learner's data: progress,
/// settings, the backups in `backups/`, downloaded decks, or a backup the
/// learner saved elsewhere. A file no rule names is kept.
library;

/// Where the app keeps files it may clean.
enum JunkArea {
  /// `ota_update/`: update APKs the updater downloaded.
  updates,

  /// `downloaded/`, the decks fetched from GitHub, and the folders beside
  /// it: only half-written `.part` files are ever junk here.
  downloads,

  /// The cache folder: report attachments in `shared/`, and any copy of a
  /// backup file made for a restore.
  cache,
}

/// A file the cleanup may judge: its path relative to its area's folder,
/// when it was last changed, and its size.
class JunkFile {
  const JunkFile(this.path, this.modified, this.size);

  final String path;
  final DateTime modified;
  final int size;

  String get name => path.split('/').last;
}

abstract final class JunkPolicy {
  /// A temporary restore file, or a half-written file, goes after a day.
  static const Duration tempAge = Duration(days: 1);

  /// Report attachments and share images go after a few days.
  static const Duration sharedAge = Duration(days: 3);

  /// A download that waited to be installed this long is stale.
  static const Duration staleApkAge = Duration(days: 30);

  /// Cleanup runs at most this often.
  static const Duration every = Duration(days: 1);

  /// The one APK name the updater keeps: the download waiting to install.
  static const String pendingApk = 'fluenough-update.apk';

  /// Whether [file], in [area] and judged at [now], is junk. [hasPending]
  /// is whether an update is downloaded and waiting to install.
  static bool isJunk(
    JunkArea area,
    JunkFile file,
    DateTime now, {
    bool hasPending = false,
  }) {
    final age = now.difference(file.modified);
    final name = file.name.toLowerCase();
    switch (area) {
      case JunkArea.updates:
        if (name.endsWith('.apk')) {
          // Any APK but the one the updater waits on is left over.
          if (file.name != pendingApk) return true;
          // The waiting one is kept, unless nothing waits on it any more
          // (a day's grace for a download just finished) or it is stale.
          if (age >= staleApkAge) return true;
          return !hasPending && age >= tempAge;
        }
        return _isPartial(name) && age >= tempAge;
      case JunkArea.downloads:
        return _isPartial(name) && age >= tempAge;
      case JunkArea.cache:
        if (file.path.startsWith('shared/')) return age >= sharedAge;
        // A copy of a backup file made to restore from. The learner's own
        // backups are never in the cache folder.
        if (name.endsWith('.fnbackup') || _isPartial(name)) {
          return age >= tempAge;
        }
        return false;
    }
  }

  static bool _isPartial(String name) =>
      name.endsWith('.part') || name.endsWith('.tmp');

  /// Whether a cleanup is due: never run, last run a day ago or more, last
  /// run in the future (a clock set back), or the app is a different
  /// version from the one that last ran it (an update just installed).
  static bool isDue({
    required DateTime now,
    required String version,
    DateTime? lastRun,
    String? lastVersion,
  }) {
    if (lastRun == null) return true;
    if (lastVersion != version) return true;
    if (lastRun.isAfter(now)) return true;
    return now.difference(lastRun) >= every;
  }

  /// The line for the app log, such as "Removed 2 old update files, 70 MB",
  /// or null when nothing was removed.
  static String? summary(int files, int bytes) {
    if (files <= 0) return null;
    final what = files == 1 ? 'old file' : 'old files';
    return 'Removed $files $what, ${_size(bytes)}';
  }

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).round()} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }
}
