import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/backup_store.dart';
import 'package:fluenough/app/backups.dart';
import 'package:fluenough/app/update_checker.dart';
import 'package:fluenough/core/updates/apk_install.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/features/settings/settings_fixtures.dart';

/// A store that cannot write, as with a full disk.
class _FullStore implements BackupStore {
  @override
  Future<StoredBackup> add(AppBackup backup) => throw StateError('disk full');

  @override
  Future<List<StoredBackup>> list() async => const <StoredBackup>[];

  @override
  Future<Uint8List> read(StoredBackup backup) => throw StateError('none');

  @override
  Future<void> delete(StoredBackup backup) async {}
}

final String _newer = SettingsFixtures.newerVersion;

void main() {
  /// An app with a newer version offered, an installer that reports [events]
  /// after [gate], and [store] for the backups.
  (AppState, FixedApkInstaller) app({
    BackupStore? store,
    List<InstallEvent> events = const <InstallEvent>[
      InstallEvent.downloading(10),
      InstallEvent.installing(),
    ],
    Completer<void>? gate,
    DateTime? now,
  }) {
    final installer = FixedApkInstaller(events, gate: gate);
    final state = AppState.test(
      releases: FixedReleaseCheck(LatestRelease(_newer)),
      installer: installer,
      backupStore: store,
      now: now,
    );
    addTearDown(state.dispose);
    return (state, installer);
  }

  test('the backup starts with the download, not after it', () async {
    final gate = Completer<void>();
    final store = MemoryBackupStore();
    final (state, installer) = app(store: store, gate: gate);
    final done = state.updates.checkAndInstall();
    // The download is held at its first event; the backup is already kept.
    await pumpEventQueue();
    expect(state.updates.status, UpdateStatus.downloading);
    expect(installer.asked, hasLength(1));
    expect(store.length, 1);
    gate.complete();
    await done;
    expect(state.updates.status, UpdateStatus.installing);
  });

  test('it lands in the app\'s own storage, named for the version it was '
      'made for, and holds the app as it was', () async {
    final store = MemoryBackupStore();
    final (state, _) = app(store: store);
    state.settings.speechRate = 0.7;
    await state.updates.checkAndInstall();
    await pumpEventQueue();
    final kept = (await store.list()).single;
    expect(kept.kind, BackupKind.update);
    expect(kept.info.forVersion, _newer);
    final backup = AppBackup.decode(await store.read(kept));
    expect(backup.settings['speech_rate'], '0.7');
    expect(state.updates.backupFailed, isFalse);
  });

  test('only the last three of them are kept', () async {
    final store = MemoryBackupStore();
    var t = DateTime(2026, 9, 28, 19);
    for (var i = 0; i < 5; i++) {
      t = t.add(const Duration(hours: 1));
      final (state, _) = app(store: store, now: t);
      await state.updates.checkAndInstall();
      await pumpEventQueue();
    }
    final kept = await store.list();
    expect(kept, hasLength(3));
    expect(kept.every((b) => b.kind == BackupKind.update), isTrue);
    expect(kept.first.createdAt, t);
  });

  test('a failed backup never blocks the update, and says it failed', () async {
    final (state, installer) = app(store: _FullStore());
    await state.updates.checkAndInstall();
    await pumpEventQueue();
    expect(installer.asked, hasLength(1));
    expect(state.updates.status, UpdateStatus.installing);
    expect(state.updates.backupFailed, isTrue);
  });

  test('a new download forgets the last one\'s failure', () async {
    final (state, _) = app(store: _FullStore());
    await state.updates.checkAndInstall();
    await pumpEventQueue();
    expect(state.updates.backupFailed, isTrue);
    final gate = Completer<void>();
    final (other, _) = app(gate: gate);
    final done = other.updates.checkAndInstall();
    await pumpEventQueue();
    expect(other.updates.backupFailed, isFalse);
    gate.complete();
    await done;
  });

  test('the list shows it and restores from it', () async {
    final store = MemoryBackupStore();
    final (state, _) = app(store: store);
    state.settings.speechRate = 0.7;
    await state.updates.checkAndInstall();
    await pumpEventQueue();
    await state.backups.load();
    final listed = state.backups.recent.single;
    expect(listed.kind, BackupKind.update);
    state.settings.speechRate = 1.4;
    await state.backups.restore(
      await state.backups.read(listed),
      fromFile: false,
    );
    expect(state.settings.speechRate, 0.7);
  });
}
