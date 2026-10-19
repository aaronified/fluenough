import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/backup_files.dart';
import 'package:fluenough/app/backup_store.dart';
import 'package:fluenough/app/backups.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/backup/zip_files.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/replay.dart';

/// A backup of a learner with [reviews] answers in Bengali and Hindi,
/// made at [at] as [kind].
AppBackup fixtureBackup({
  required DateTime at,
  BackupKind kind = BackupKind.you,
  String? forVersion,
  int reviews = 3,
  String appVersion = '0.5.0',
  Map<String, String> settings = const <String, String>{
    'learning_languages': 'bn,hi',
    'speech_rate': '0.6',
  },
  List<String> downloads = const <String>['bn', 'hi'],
}) => AppBackup(
  appVersion: appVersion,
  schemaVersion: 7,
  createdAt: at,
  log: LogJsonl.encode(<LoggedReview>[
    for (var i = 0; i < reviews; i++)
      (
        key: (cardId: 'bn-${1000 + i}', mode: DrillMode.recognition),
        deckId: 'bn-en-water',
        at: at.subtract(Duration(minutes: i + 1)),
        grade: 3,
        elapsed: const Duration(seconds: 2),
        answerGiven: null,
        script: null,
        asked: null,
      ),
  ], const <LeechAction>[]),
  settings: settings,
  downloads: downloads,
  kind: kind,
  forVersion: forVersion,
);

/// An app with every feature on and the recent backups the mockup draws:
/// made by the learner, before an update, before a restore, from a file.
Future<({AppState state, MemoryBackupStore store, FixedBackupFiles files})>
stateWithBackups({FeatureRegistry? features}) async {
  final store = MemoryBackupStore();
  final files = FixedBackupFiles();
  final at = DateTime(2026, 9, 28, 18, 40);
  for (final backup in <AppBackup>[
    fixtureBackup(
      at: at.subtract(const Duration(days: 20)),
      kind: BackupKind.update,
      forVersion: '0.5.2',
      reviews: 2,
    ),
    fixtureBackup(
      at: at.subtract(const Duration(days: 10)),
      kind: BackupKind.file,
      reviews: 4,
    ),
    fixtureBackup(
      at: at.subtract(const Duration(days: 10, minutes: -1)),
      kind: BackupKind.restore,
      reviews: 3,
    ),
    fixtureBackup(
      at: at.subtract(const Duration(days: 2)),
      kind: BackupKind.update,
      forVersion: '0.5.3',
      reviews: 5,
    ),
    fixtureBackup(at: at, reviews: 6),
  ]) {
    await store.add(backup);
  }
  final state = AppState.test(
    features: features ?? FeatureRegistry.all(),
    backupStore: store,
    backupFiles: files,
    now: at.add(const Duration(minutes: 5)),
  );
  return (state: state, store: store, files: files);
}

/// A backup file as a newer Fluenough [madeBy] would write it: the same
/// parts, a manifest whose version is one this app does not read.
Uint8List newerFile(String madeBy) {
  final files = ZipFiles.decode(
    fixtureBackup(at: DateTime(2026, 9, 1)).encode(),
  );
  final manifest =
      jsonDecode(utf8.decode(files['manifest.json']!)) as Map<String, Object?>;
  return ZipFiles.encode(<String, List<int>>{
    ...files,
    'manifest.json': utf8.encode(
      jsonEncode(<String, Object?>{
        ...manifest,
        'version': AppBackup.version + 1,
        'appVersion': madeBy,
      }),
    ),
  });
}

/// A progress store that cannot replace its log.
class FailingProgress extends MemoryProgress {
  @override
  Future<void> replaceAll(
    List<LoggedReview> reviews,
    List<LeechAction> leechActions, {
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
    required RestoreRecord restore,
  }) => throw StateError('disk full');
}

/// A store that cannot write, as with a full disk.
class FullBackupStore implements BackupStore {
  @override
  Future<StoredBackup> add(AppBackup backup) => throw StateError('disk full');

  @override
  Future<List<StoredBackup>> list() async => const <StoredBackup>[];

  @override
  Future<Uint8List> read(StoredBackup backup) => throw StateError('none');

  @override
  Future<void> delete(StoredBackup backup) async {}
}
