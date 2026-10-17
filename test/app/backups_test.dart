import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/backup_files.dart';
import 'package:fluenough/app/backup_store.dart';
import 'package:fluenough/app/backups.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/backup/zip_files.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';

/// Monday 28 September 2026, 19:00: `AppState.test`'s clock.
final DateTime _now = DateTime(2026, 9, 28, 19);

/// A progress store whose replacing fails part-way, after the settings have
/// not been touched.
class _FailingProgress extends MemoryProgress {
  @override
  Future<void> replaceAll(
    List<LoggedReview> reviews,
    List<LeechAction> leechActions, {
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
  }) => throw StateError('disk full');
}

void answer(ProgressStore p, String card, int grade, DateTime at) => p.record(
  deckId: 'hi-en-market',
  cardId: card,
  mode: DrillMode.production,
  grade: grade,
  now: at,
  elapsed: const Duration(seconds: 2),
);

Map<ProgressKey, (double, double, int, DateTime, int)> byValue(
  Map<ProgressKey, FsrsState> states,
) => <ProgressKey, (double, double, int, DateTime, int)>{
  for (final e in states.entries)
    e.key: (
      e.value.stability,
      e.value.difficulty,
      e.value.intervalDays,
      e.value.dueAt,
      e.value.lapses,
    ),
};

({AppState state, FixedBackupFiles files, MemoryBackupStore store}) app({
  ProgressStore? progress,
  DateTime? now,
}) {
  final files = FixedBackupFiles();
  final store = MemoryBackupStore();
  final state = AppState.test(
    progress: progress,
    backupFiles: files,
    backupStore: store,
    now: now ?? _now,
  );
  addTearDown(state.dispose);
  return (state: state, files: files, store: store);
}

void main() {
  group('a backup of the app as it is', () {
    test('holds the log, every setting and the reviewer, byte for byte', () {
      final a = app();
      answer(a.state.progress, 'hi-0231', 4, _now);
      a.state.settings
        ..raterCode = 'FL-7K3M-Q9TD-6'
        ..reviewDecks = true
        ..speechRate = 0.8;
      final backup = a.state.backups.snapshot(BackupKind.you);
      expect(backup.log, a.state.progress.exportJsonl());
      expect(backup.settings, a.state.settings.toStored());
      expect(backup.settings['rater_code'], 'FL-7K3M-Q9TD-6');
      expect(backup.appVersion, isNotEmpty);
      expect(backup.schemaVersion, 7);
      final back = AppBackup.decode(backup.encode());
      expect(back.settings, a.state.settings.toStored());
      expect(back.reviews.single.key.cardId, 'hi-0231');
    });

    test('Back up now offers the dated file and keeps a copy here', () async {
      final a = app();
      expect(await a.state.backups.backUpNow(), isTrue);
      expect(a.files.saved.single.name, 'fluenough-backup-2026-09-28.fnbackup');
      expect(AppBackup.decode(a.files.saved.single.bytes).kind, BackupKind.you);
      expect(a.store.length, 1);
      expect(a.state.backups.recent.single.kind, BackupKind.you);
    });

    test('Back up now, cancelled in the dialog, keeps nothing', () async {
      final a = app();
      a.files.saves = false;
      expect(await a.state.backups.backUpNow(), isFalse);
      expect(a.store.length, 0);
    });

    test('Download offers a kept backup as it was made', () async {
      final a = app();
      final kept = await a.state.backups.keep(BackupKind.you);
      expect(await a.state.backups.download(kept), isTrue);
      expect(a.files.saved.single.bytes, await a.store.read(kept));
    });
  });

  group('the last ones are kept', () {
    test('five of any kind, newest first', () async {
      final a = app();
      var t = _now;
      Future<void> make(BackupKind kind) async {
        final one = AppState.test(
          backupStore: a.store,
          now: t = t.add(const Duration(minutes: 1)),
        );
        addTearDown(one.dispose);
        await one.backups.keep(kind);
      }

      for (var i = 0; i < 8; i++) {
        await make(BackupKind.you);
      }
      final list = await a.store.list();
      expect(list, hasLength(Backups.keepRecent));
      expect(Backups.keepRecent, 5);
      expect(list.first.createdAt, t);
      expect(
        list.map((b) => b.createdAt),
        orderedEquals(<DateTime>[
          for (var i = 0; i < 5; i++) t.subtract(Duration(minutes: i)),
        ]),
      );
    });

    test('only the last three an update made, whatever else is kept', () async {
      final a = app();
      var t = _now;
      Future<void> make(BackupKind kind, [String? version]) async {
        final one = AppState.test(
          backupStore: a.store,
          now: t = t.add(const Duration(minutes: 1)),
        );
        addTearDown(one.dispose);
        await one.backups.keep(kind, forVersion: version);
      }

      await make(BackupKind.update, '0.5.1');
      await make(BackupKind.update, '0.5.2');
      await make(BackupKind.update, '0.5.3');
      await make(BackupKind.you);
      await make(BackupKind.update, '0.5.4');
      final list = await a.store.list();
      expect(Backups.keepUpdate, 3);
      expect(list, hasLength(4), reason: 'the oldest update went, not yours');
      expect(
        list
            .where((b) => b.kind == BackupKind.update)
            .map((b) => b.info.forVersion),
        <String?>['0.5.4', '0.5.3', '0.5.2'],
      );
      expect(list.where((b) => b.kind == BackupKind.you), hasLength(1));
    });
  });

  group(
    'restoring replaces everything, and keeps a copy of what it replaced',
    () {
      /// A learner with progress and settings, backed up, then another app.
      Future<
        (
          AppBackup,
          ({AppState state, FixedBackupFiles files, MemoryBackupStore store}),
        )
      >
      original() async {
        final source = app();
        for (var i = 0; i < 6; i++) {
          answer(
            source.state.progress,
            'hi-02${30 + i}',
            i.isEven ? 4 : 1,
            _now.add(Duration(days: i)),
          );
        }
        source.state.settings
          ..raterCode = 'FL-7K3M-Q9TD-6'
          ..reviewDecks = true
          ..speechRate = 0.7
          ..autoAdjust = false;
        final backup = AppBackup.decode(
          source.state.backups.snapshot(BackupKind.you).encode(),
        );
        final other = app();
        answer(other.state.progress, 'bn-0001', 3, _now);
        answer(other.state.progress, 'bn-0002', 3, _now);
        other.state.settings
          ..speechRate = 1.4
          ..showIpa = !other.state.settings.showIpa;
        return (backup, other);
      }

      test(
        'the log, the schedules and every setting are the backup\'s',
        () async {
          final (backup, other) = await original();
          final source = AppBackup.decode(backup.encode());
          final reference = MemoryProgress()
            ..skills = other.state.progress.skills;
          await reference.replaceAll(
            source.reviews,
            source.leechActions,
            fitted: source.fitted,
          );
          await other.state.backups.restore(backup, fromFile: true);
          final progress = other.state.progress;
          expect(
            progress.log.map((e) => e.cardId),
            isNot(contains('bn-0001')),
            reason: 'what was there is gone',
          );
          expect(progress.log, hasLength(6));
          expect(byValue(progress.states), byValue(reference.states));
          expect(other.state.settings.toStored(), backup.settings);
          expect(other.state.settings.raterCode, 'FL-7K3M-Q9TD-6');
          expect(other.state.settings.reviewDecks, isTrue);
        },
      );

      test('a setting the backup lacks goes back to its default', () async {
        final (backup, other) = await original();
        final older = AppBackup(
          appVersion: '0.4.0',
          schemaVersion: 7,
          createdAt: _now,
          log: backup.log,
          settings: <String, String>{
            for (final e in backup.settings.entries)
              if (e.key != 'speech_rate') e.key: e.value,
          },
        );
        expect(other.state.settings.speechRate, 1.4);
        await other.state.backups.restore(
          AppBackup.decode(older.encode()),
          fromFile: false,
        );
        expect(other.state.settings.speechRate, SettingsNotifier().speechRate);
        expect(other.state.settings.autoAdjust, isFalse);
      });

      test('a copy of what it replaced is kept first, and a file restored '
          'from is kept as it was read', () async {
        final (backup, other) = await original();
        final before = other.state.progress.exportJsonl();
        await other.state.backups.restore(backup, fromFile: true);
        final kept = await other.store.list();
        expect(
          kept.map((b) => b.kind),
          unorderedEquals(<BackupKind>[BackupKind.restore, BackupKind.file]),
        );
        final copy = AppBackup.decode(
          await other.store.read(
            kept.firstWhere((b) => b.kind == BackupKind.restore),
          ),
        );
        expect(copy.log, before, reason: 'the copy is of what was replaced');
        final file = AppBackup.decode(
          await other.store.read(
            kept.firstWhere((b) => b.kind == BackupKind.file),
          ),
        );
        expect(file.log, backup.log);
      });

      test('restoring from a kept backup keeps only the copy of what it '
          'replaced', () async {
        final (backup, other) = await original();
        await other.state.backups.restore(backup, fromFile: false);
        expect((await other.store.list()).map((b) => b.kind), <BackupKind>[
          BackupKind.restore,
        ]);
      });

      test(
        'the languages it lists are queued, and no deck file is in it',
        () async {
          final source = app();
          final backup = AppBackup(
            appVersion: '0.5.0',
            schemaVersion: 7,
            createdAt: _now,
            log: source.state.progress.exportJsonl(),
            settings: source.state.settings.toStored(),
            downloads: const <String>['bn', 'hi'],
          );
          final queued = <List<String>>[];
          final backups = Backups(
            settings: SettingsNotifier(),
            progress: MemoryProgress(),
            store: MemoryBackupStore(),
            files: FixedBackupFiles(),
            clock: () => _now,
            log: source.state.log,
            restored: queued.add,
          );
          await backups.restore(
            AppBackup.decode(backup.encode()),
            fromFile: false,
          );
          expect(queued.single, <String>['bn', 'hi']);
        },
      );

      test(
        'a failure while replacing leaves the settings as they were',
        () async {
          final (backup, _) = await original();
          final failing = app(progress: _FailingProgress());
          failing.state.settings.speechRate = 1.4;
          final before = failing.state.settings.toStored();
          await expectLater(
            failing.state.backups.restore(backup, fromFile: false),
            throwsStateError,
          );
          expect(failing.state.settings.toStored(), before);
          expect(failing.state.progress.log, isEmpty);
        },
      );
    },
  );

  group('a file that cannot be restored changes nothing', () {
    test('a file that is not a backup', () async {
      final a = app();
      a.files.toOpen = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final before = a.state.settings.toStored();
      await expectLater(
        a.state.backups.pick(title: 'Pick'),
        throwsFormatException,
      );
      expect(a.state.settings.toStored(), before);
      expect(a.store.length, 0);
    });

    test('a file from a newer Fluenough says so', () async {
      final a = app();
      final newer = AppBackup(
        appVersion: '0.7.0',
        schemaVersion: 7,
        createdAt: _now,
        log: a.state.progress.exportJsonl(),
        settings: const <String, String>{},
      ).encode();
      // Raise the manifest's version the way a newer app would.
      a.files.toOpen = _withVersion(newer, 2);
      await expectLater(
        a.state.backups.pick(title: 'Pick'),
        throwsA(isA<NewerBackupException>()),
      );
    });

    test('no file picked is no backup', () async {
      final a = app();
      expect(await a.state.backups.pick(title: 'Pick'), isNull);
      expect(a.files.opened, 1);
    });
  });
}

Uint8List _withVersion(Uint8List bytes, int version) {
  final files = ZipFiles.decode(bytes);
  final manifest =
      jsonDecode(utf8.decode(files['manifest.json']!)) as Map<String, Object?>;
  return ZipFiles.encode(<String, List<int>>{
    ...files,
    'manifest.json': utf8.encode(
      jsonEncode(<String, Object?>{...manifest, 'version': version}),
    ),
  });
}
