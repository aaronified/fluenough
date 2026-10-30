import 'dart:async';
import 'dart:io';

import '../core/cleanup/junk_policy.dart';
import 'app_log.dart';

/// The files the cleanup may look at and remove. An interface so that tests
/// need no disk.
abstract interface class JunkFiles {
  /// Every file under [area]'s folder, paths relative to it.
  Future<List<JunkFile>> list(JunkArea area);

  /// Deletes [path] in [area].
  Future<void> delete(JunkArea area, String path);
}

/// When cleanup last ran, and for which version.
abstract interface class JunkStamp {
  Future<({DateTime at, String version})?> read();

  Future<void> write(DateTime at, String version);
}

/// Cleans junk once a day, and after an update installs (#493). Never
/// throws and never touches a file [JunkPolicy] does not call junk.
class JunkCleanup {
  JunkCleanup({
    required this.files,
    required this.stamp,
    required this.log,
    required this.version,
    this.hasPending = _never,
    this.clock = DateTime.now,
  });

  final JunkFiles files;
  final JunkStamp stamp;
  final AppLog log;
  final String version;

  /// Whether an update is downloaded and waiting to install.
  final bool Function() hasPending;
  final DateTime Function() clock;

  static bool _never() => false;

  /// Runs if due; returns how many files it removed.
  Future<int> runIfDue() async {
    try {
      final now = clock();
      final last = await stamp.read();
      if (!JunkPolicy.isDue(
        now: now,
        version: version,
        lastRun: last?.at,
        lastVersion: last?.version,
      )) {
        return 0;
      }
      var removed = 0;
      var bytes = 0;
      final pending = hasPending();
      for (final area in JunkArea.values) {
        try {
          for (final file in await files.list(area)) {
            if (!JunkPolicy.isJunk(area, file, now, hasPending: pending)) {
              continue;
            }
            try {
              await files.delete(area, file.path);
              removed++;
              bytes += file.size;
            } on Object {
              // In use or already gone: left for the next run.
            }
          }
        } on Object {
          // An area that cannot be read is skipped.
        }
      }
      final line = JunkPolicy.summary(removed, bytes);
      if (line != null) log.event(line);
      await stamp.write(now, version);
      return removed;
    } on Object {
      return 0;
    }
  }
}

/// [JunkFiles] on the phone: one folder per area.
class DiskJunkFiles implements JunkFiles {
  const DiskJunkFiles({
    required this.updates,
    required this.downloads,
    required this.cache,
  });

  final Directory updates;
  final Directory downloads;
  final Directory cache;

  Directory _dir(JunkArea area) => switch (area) {
    JunkArea.updates => updates,
    JunkArea.downloads => downloads,
    JunkArea.cache => cache,
  };

  @override
  Future<List<JunkFile>> list(JunkArea area) async {
    final dir = _dir(area);
    if (!await dir.exists()) return const <JunkFile>[];
    final prefix = '${dir.path}/';
    final found = <JunkFile>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        found.add(
          JunkFile(
            entity.path.startsWith(prefix)
                ? entity.path.substring(prefix.length)
                : entity.path,
            stat.modified,
            stat.size,
          ),
        );
      } on FileSystemException {
        // Gone while listing.
      }
    }
    return found;
  }

  @override
  Future<void> delete(JunkArea area, String path) async {
    if (path.contains('..')) return;
    await File('${_dir(area).path}/$path').delete();
  }
}

/// [JunkStamp] in a small file.
class FileJunkStamp implements JunkStamp {
  const FileJunkStamp(this.file);

  final File file;

  @override
  Future<({DateTime at, String version})?> read() async {
    try {
      if (!await file.exists()) return null;
      final parts = (await file.readAsString()).trim().split('|');
      final at = DateTime.tryParse(parts.first);
      if (at == null || parts.length < 2) return null;
      return (at: at, version: parts[1]);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(DateTime at, String version) async {
    await file.parent.create(recursive: true);
    await file.writeAsString('${at.toIso8601String()}|$version');
  }
}
