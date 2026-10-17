import 'dart:io';
import 'dart:typed_data';

import '../core/backup/app_backup.dart';

/// A backup the app keeps in its own storage (#470): what made it, when,
/// and how much it holds. [id] names it to its [BackupStore].
class StoredBackup {
  const StoredBackup({required this.id, required this.info});

  final String id;
  final BackupInfo info;

  BackupKind get kind => info.kind;
  DateTime get createdAt => info.createdAt;
}

/// The backups kept on the phone: the ones the learner made, the ones the
/// app made as an update began to download, and the copies a restore kept.
/// In the app's own storage, which an app update leaves alone.
abstract interface class BackupStore {
  /// Every backup kept, newest first. A file that is not a backup is not
  /// listed.
  Future<List<StoredBackup>> list();

  /// Keeps [backup], and says what it was kept as.
  Future<StoredBackup> add(AppBackup backup);

  /// The file of [backup].
  Future<Uint8List> read(StoredBackup backup);

  Future<void> delete(StoredBackup backup);
}

/// [BackupStore] in a directory, one `.fnbackup` file per backup.
class FileBackupStore implements BackupStore {
  FileBackupStore(this.directory);

  final Directory directory;

  int _count = 0;

  @override
  Future<List<StoredBackup>> list() async {
    if (!await directory.exists()) return const <StoredBackup>[];
    final found = <StoredBackup>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.${AppBackup.extension}')) {
        continue;
      }
      try {
        found.add(
          StoredBackup(
            id: entity.uri.pathSegments.last,
            info: BackupInfo.peek(await entity.readAsBytes()),
          ),
        );
      } on Object {
        // Not a backup, or one a newer app made: left alone, not listed.
      }
    }
    return _newestFirst(found);
  }

  @override
  Future<StoredBackup> add(AppBackup backup) async {
    await directory.create(recursive: true);
    final at = backup.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${at.year}${two(at.month)}${two(at.day)}-'
        '${two(at.hour)}${two(at.minute)}${two(at.second)}-'
        '${at.millisecond.toString().padLeft(3, '0')}-${_serial(_count++)}';
    final name =
        'fluenough-backup-$stamp-${backup.kind.name}.'
        '${AppBackup.extension}';
    final file = File('${directory.path}/$name');
    // Written beside, then moved in: a backup cut short is never listed.
    final partial = File('${file.path}.part');
    await partial.writeAsBytes(backup.encode(), flush: true);
    await partial.rename(file.path);
    return StoredBackup(
      id: name,
      info: BackupInfo.peek(await file.readAsBytes()),
    );
  }

  @override
  Future<Uint8List> read(StoredBackup backup) =>
      File('${directory.path}/${backup.id}').readAsBytes();

  @override
  Future<void> delete(StoredBackup backup) async {
    final file = File('${directory.path}/${backup.id}');
    if (await file.exists()) await file.delete();
  }
}

/// [BackupStore] in memory, for tests and the gallery.
class MemoryBackupStore implements BackupStore {
  final Map<String, Uint8List> _files = <String, Uint8List>{};
  int _count = 0;

  /// How many are kept.
  int get length => _files.length;

  @override
  Future<List<StoredBackup>> list() async => _newestFirst(<StoredBackup>[
    for (final MapEntry(:key, :value) in _files.entries)
      StoredBackup(id: key, info: BackupInfo.peek(value)),
  ]);

  @override
  Future<StoredBackup> add(AppBackup backup) async {
    final id = 'backup-${_serial(_count++)}';
    final bytes = backup.encode();
    _files[id] = bytes;
    return StoredBackup(id: id, info: BackupInfo.peek(bytes));
  }

  @override
  Future<Uint8List> read(StoredBackup backup) async => _files[backup.id]!;

  @override
  Future<void> delete(StoredBackup backup) async => _files.remove(backup.id);
}

/// Newest first; made in the same instant, the one added later first.
List<StoredBackup> _newestFirst(List<StoredBackup> backups) =>
    backups..sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });

/// [n] as a fixed-width number, so that names sort in the order made.
String _serial(int n) => n.toString().padLeft(6, '0');
