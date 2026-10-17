import 'package:flutter/foundation.dart';

import '../core/backup/app_backup.dart';
import '../core/data/database.dart';
import 'app_info.dart';
import 'app_log.dart';
import 'backup_files.dart';
import 'backup_store.dart';
import 'memory_progress.dart';
import 'settings.dart';

export '../core/backup/app_backup.dart'
    show AppBackup, BackupKind, NewerBackupException;
export 'backup_store.dart' show StoredBackup;

/// Backing up and restoring the whole app (#470; docs/BACKUP-FORMAT.md):
/// Back up now, Restore from a file, and the recent backups kept in the
/// app's own storage, which include the one made as each app update
/// downloads ([UpdateChecker]'s hook is [keep]).
///
/// A restore replaces what the learner has, after the screen has asked, and
/// keeps a copy of what it replaced first. It reads and checks the whole
/// file before it changes anything, so a damaged one leaves the app as it
/// was.
class Backups extends ChangeNotifier {
  Backups({
    required this.settings,
    required this.progress,
    required this._store,
    required this._files,
    required this._clock,
    required this._log,
    this._languagesOnPhone = _noLanguages,
    this._restored = _nothing,
    this.appVersion = AppInfo.version,
  });

  /// How many backups are kept on the phone, whatever made them (owner,
  /// 2026-10-12: "the five newest on the phone, of any kind").
  static const int keepRecent = 5;

  /// How many of those may be the ones an app update made (#470: "keeping
  /// the last three").
  static const int keepUpdate = 3;

  final SettingsNotifier settings;
  final ProgressStore progress;
  final BackupStore _store;
  final BackupFiles _files;
  final DateTime Function() _clock;
  final AppLog _log;
  final Set<String> Function() _languagesOnPhone;
  final void Function(List<String> languages) _restored;

  /// This build's version, which a backup records.
  final String appVersion;

  List<StoredBackup> _recent = const <StoredBackup>[];

  static Set<String> _noLanguages() => const <String>{};
  static void _nothing(List<String> _) {}

  /// The backups kept on the phone, newest first. Empty until [load].
  List<StoredBackup> get recent => _recent;

  /// Reads which backups are kept.
  Future<void> load() async {
    _recent = await _store.list();
    notifyListeners();
  }

  /// The app as it is now.
  AppBackup snapshot(BackupKind kind, {String? forVersion}) => AppBackup(
    appVersion: appVersion,
    schemaVersion: AppDatabase.currentSchemaVersion,
    createdAt: _clock(),
    log: progress.exportJsonl(),
    settings: settings.toStored(),
    downloads: (_languagesOnPhone().toList()..sort()),
    kind: kind,
    forVersion: forVersion,
  );

  /// Keeps a backup of the app as it is in the app's own storage, made as
  /// [kind], and forgets those past the last [keepRecent], and the last
  /// [keepUpdate] of the ones an update made. Throws if it cannot be
  /// written; an update's caller catches that, since a failed backup never
  /// stops an update.
  Future<StoredBackup> keep(BackupKind kind, {String? forVersion}) async {
    final stored = await _store.add(snapshot(kind, forVersion: forVersion));
    await _prune();
    _log.event('Backup kept: ${kind.name}');
    return stored;
  }

  Future<void> _prune() async {
    final all = await _store.list();
    var updates = 0;
    for (final (i, backup) in all.indexed) {
      final tooMany = i >= keepRecent;
      final tooManyUpdates =
          backup.kind == BackupKind.update && ++updates > keepUpdate;
      if (tooMany || tooManyUpdates) await _store.delete(backup);
    }
    _recent = await _store.list();
    notifyListeners();
  }

  /// Back up now: offers the file to the learner to save where they
  /// choose, and keeps a copy here. False if they did not save it.
  Future<bool> backUpNow() async {
    final backup = snapshot(BackupKind.you);
    final saved = await _files.save(
      AppBackup.fileName(backup.createdAt),
      backup.encode(),
    );
    if (!saved) return false;
    await _store.add(backup);
    await _prune();
    _log.event('Backup saved');
    return true;
  }

  /// Download: offers the kept [backup]'s file to save, as it was made.
  Future<bool> download(StoredBackup backup) async {
    final saved = await _files.save(
      AppBackup.fileName(backup.createdAt),
      await _store.read(backup),
    );
    if (saved) _log.event('Backup downloaded');
    return saved;
  }

  /// Restore from a file: asks for one, and reads it whole. Null if none
  /// was picked. Throws [FormatException] for a file that is not a backup
  /// or is damaged, and [NewerBackupException] for one a newer app made;
  /// nothing has changed either way.
  Future<AppBackup?> pick({required String title}) async {
    final bytes = await _files.open(title: title);
    return bytes == null ? null : AppBackup.decode(bytes);
  }

  /// The kept [backup], read whole, to show and restore.
  Future<AppBackup> read(StoredBackup backup) async =>
      AppBackup.decode(await _store.read(backup));

  /// Replaces everything the learner has with [backup]: the review log,
  /// the settings (a setting it lacks goes back to its default), and the
  /// reviewer's code and answers. A copy of what it replaces is kept first.
  /// A [fromFile] backup is kept as it was read. Then the languages it
  /// lists download again.
  ///
  /// Throws, with the app as it was, if the copy cannot be kept or the log
  /// cannot be replaced.
  Future<void> restore(AppBackup backup, {required bool fromFile}) async {
    await keep(BackupKind.restore);
    await progress.replaceAll(
      backup.reviews,
      backup.leechActions,
      fitted: backup.fitted,
    );
    final defaults = SettingsNotifier();
    final stored = <String, String>{...defaults.toStored(), ...backup.settings};
    defaults.dispose();
    settings.restore(stored);
    _log.event('Restored from a backup: ${backup.reviews.length} reviews');
    if (fromFile) {
      try {
        await _store.add(backup.copyAs(BackupKind.file, _clock()));
        await _prune();
      } on Object catch (e) {
        _log.warning('Restored file not kept: ${e.runtimeType}');
      }
    }
    _restored(backup.downloads);
  }
}
