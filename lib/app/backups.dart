import 'package:flutter/foundation.dart';

import '../core/backup/app_backup.dart';
import '../core/data/database.dart';
import '../core/models/completed_work.dart';
import 'app_info.dart';
import 'app_log.dart';
import 'backup_files.dart';
import 'backup_store.dart';
import 'memory_progress.dart';
import 'settings.dart';

export '../core/backup/app_backup.dart'
    show
        AppBackup,
        BackupInfo,
        BackupKind,
        BackupPrivatePackage,
        NewerBackupException;
export 'backup_store.dart' show StoredBackup;

/// What a backup carries of the private language packages (#1017): the
/// packages on the phone, and the retired ids of the ones removed.
typedef PrivateSnapshot = ({
  List<BackupPrivatePackage> packages,
  Map<String, List<String>> tombstones,
});

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
    this._completedWorks = _noWorks,
    this._restoreMarks = _keepMarks,
    this._privateSnapshot = _noPrivate,
    this._restorePrivate = _keepPrivate,
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

  /// The recommended works marked completed, for a backup to carry as lines of
  /// its log (deck-kinds plan, D13, T25), and what a restore does with the
  /// marks of the backup it restores.
  final List<CompletedWork> Function() _completedWorks;
  final Future<void> Function(List<CompletedWork> works) _restoreMarks;

  /// The private language packages on the phone, for a backup to carry
  /// (#1017), and what a restore does with the ones of the backup it
  /// restores.
  final Future<PrivateSnapshot> Function() _privateSnapshot;
  final Future<void> Function(
    List<BackupPrivatePackage> packages,
    Map<String, List<String>> tombstones,
  )
  _restorePrivate;

  /// This build's version, which a backup records.
  final String appVersion;

  List<StoredBackup> _recent = const <StoredBackup>[];

  static Set<String> _noLanguages() => const <String>{};
  static void _nothing(List<String> _) {}
  static List<CompletedWork> _noWorks() => const <CompletedWork>[];
  static Future<void> _keepMarks(List<CompletedWork> _) async {}
  static Future<PrivateSnapshot> _noPrivate() async => (
    packages: const <BackupPrivatePackage>[],
    tombstones: const <String, List<String>>{},
  );
  static Future<void> _keepPrivate(
    List<BackupPrivatePackage> _,
    Map<String, List<String>> _,
  ) async {}

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
    log: progress.exportJsonl(completedWorks: _completedWorks()),
    settings: settings.toStored(),
    downloads: (_languagesOnPhone().toList()..sort()),
    kind: kind,
    forVersion: forVersion,
  );

  /// [snapshot] with the private language packages (#1017): they exist
  /// nowhere else, so every backup carries them. One that cannot be read is
  /// logged and left out, never a failed backup.
  Future<AppBackup> _snapshotWithPrivate(
    BackupKind kind, {
    String? forVersion,
  }) async {
    final base = snapshot(kind, forVersion: forVersion);
    try {
      final own = await _privateSnapshot();
      if (own.packages.isEmpty && own.tombstones.isEmpty) return base;
      return base.withPrivate(own.packages, own.tombstones);
    } on Object catch (e) {
      _log.warning('Private languages not in the backup: ${e.runtimeType}');
      return base;
    }
  }

  /// Offers [bytes] to the learner to save as [fileName] (a private language
  /// package, #1017). Whether it was saved.
  Future<bool> saveFile(String fileName, Uint8List bytes) =>
      _files.save(fileName, bytes);

  /// Keeps a backup of the app as it is in the app's own storage, made as
  /// [kind], and forgets those past the last [keepRecent], and the last
  /// [keepUpdate] of the ones an update made. Throws if it cannot be
  /// written; an update's caller catches that, since a failed backup never
  /// stops an update.
  Future<StoredBackup> keep(BackupKind kind, {String? forVersion}) async {
    final stored = await _store.add(
      await _snapshotWithPrivate(kind, forVersion: forVersion),
    );
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
    final backup = await _snapshotWithPrivate(BackupKind.you);
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
  /// Called only once the learner has confirmed. Replacing the log is the
  /// one exception to it being append-only (AGENTS.md rule 9; owner,
  /// 2026-10-17: "Logged exception"), so the database keeps a record of
  /// it: when, from which backup, and the name of the copy kept first.
  ///
  /// Throws, with the app as it was, if the copy cannot be kept or the log
  /// cannot be replaced.
  Future<void> restore(AppBackup backup, {required bool fromFile}) async {
    final copy = await keep(BackupKind.restore);
    await progress.replaceAll(
      backup.reviews,
      backup.leechActions,
      fitted: backup.fitted,
      withdrawals: backup.withdrawals,
      restore: RestoreRecord(
        at: _clock(),
        backupCreatedAt: backup.createdAt,
        backupKind: backup.kind.name,
        backupAppVersion: backup.appVersion,
        fromFile: fromFile,
        keptCopy: copy.id,
      ),
    );
    // The learner's own private language packages come back too, before the
    // settings, which may name one of their languages (#1017). A backup
    // without any leaves the packages on the phone as they are.
    if (backup.privatePackages.isNotEmpty ||
        backup.privateTombstones.isNotEmpty) {
      try {
        await _restorePrivate(backup.privatePackages, backup.privateTombstones);
      } on Object catch (e) {
        _log.warning('Private languages not restored: ${e.runtimeType}');
      }
    }
    // The marks of completed works are not part of the append-only log: the
    // restore makes them those of the backup, which an older one lacks.
    try {
      await _restoreMarks(backup.completedWorks);
    } on Object catch (e) {
      _log.warning('Completed works not restored: ${e.runtimeType}');
    }
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
