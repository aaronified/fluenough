// Junk cleanup (#493): an old update APK goes and the waiting one stays, a
// half-written file goes when a day old, the learner's backups and decks are
// never touched, it runs once a day and after an update, and failures are
// swallowed.

import 'package:fluenough/app/app_log.dart';
import 'package:fluenough/app/junk_cleanup.dart';
import 'package:fluenough/core/cleanup/junk_policy.dart';
import 'package:flutter_test/flutter_test.dart';

class _Files implements JunkFiles {
  _Files(this.areas);
  final Map<JunkArea, List<JunkFile>> areas;
  final List<String> deleted = <String>[];
  bool failList = false;
  bool failDelete = false;

  @override
  Future<List<JunkFile>> list(JunkArea area) async {
    if (failList) throw StateError('no disk');
    return List<JunkFile>.of(areas[area] ?? const <JunkFile>[]);
  }

  @override
  Future<void> delete(JunkArea area, String path) async {
    if (failDelete) throw StateError('in use');
    deleted.add('${area.name}/$path');
  }
}

class _Stamp implements JunkStamp {
  ({DateTime at, String version})? value;
  bool failWrite = false;

  @override
  Future<({DateTime at, String version})?> read() async => value;

  @override
  Future<void> write(DateTime at, String version) async {
    if (failWrite) throw StateError('read only');
    value = (at: at, version: version);
  }
}

void main() {
  final now = DateTime(2026, 10, 30, 12);
  JunkFile aged(String path, Duration age, [int size = 1048576]) =>
      JunkFile(path, now.subtract(age), size);

  late AppLog log;
  late _Stamp stamp;

  setUp(() {
    log = AppLog(store: MemoryLogStore());
    stamp = _Stamp();
  });

  JunkCleanup cleanup(
    _Files files, {
    bool pending = false,
    String version = '0.6.0',
  }) => JunkCleanup(
    files: files,
    stamp: stamp,
    log: log,
    version: version,
    hasPending: () => pending,
    clock: () => now,
  );

  test('an old update APK is removed and the waiting one is kept', () async {
    final files = _Files({
      JunkArea.updates: [
        aged('fluenough-0.5.0.apk', const Duration(days: 2)),
        aged(JunkPolicy.pendingApk, const Duration(days: 2)),
      ],
    });
    await cleanup(files, pending: true).runIfDue();
    expect(files.deleted, ['updates/fluenough-0.5.0.apk']);
  });

  test('the pending APK goes when nothing waits on it, or when stale', () {
    bool junk(Duration age, bool pending) => JunkPolicy.isJunk(
      JunkArea.updates,
      aged(JunkPolicy.pendingApk, age),
      now,
      hasPending: pending,
    );
    expect(junk(const Duration(hours: 1), false), isFalse);
    expect(junk(const Duration(days: 2), false), isTrue);
    expect(junk(const Duration(days: 2), true), isFalse);
    expect(junk(const Duration(days: 31), true), isTrue);
  });

  test('a user backup, the decks and the snapshot are never removed', () async {
    final files = _Files({
      JunkArea.downloads: [
        aged('decks/te/te-01.yaml', const Duration(days: 400)),
        aged('catalog-snapshot.json', const Duration(days: 400)),
      ],
      JunkArea.cache: [
        aged('shared/../x', const Duration(days: 0)),
        aged('notes.txt', const Duration(days: 400)),
      ],
    });
    await cleanup(files).runIfDue();
    expect(files.deleted, isEmpty);
    expect(
      JunkPolicy.isJunk(
        JunkArea.updates,
        aged('backups/fluenough-backup-1.fnbackup', const Duration(days: 90)),
        now,
      ),
      isFalse,
    );
  });

  test('temporary files go once a day old, not before', () async {
    final files = _Files({
      JunkArea.downloads: [
        aged('decks/te/a.yaml.part', const Duration(days: 2)),
        aged('decks/te/b.yaml.part', const Duration(hours: 2)),
        aged('catalog-snapshot.json.part', const Duration(days: 2)),
      ],
      JunkArea.cache: [
        aged('restore.fnbackup', const Duration(days: 2)),
        aged('shared/log.txt', const Duration(days: 5)),
        aged('shared/new.png', const Duration(days: 1)),
      ],
    });
    await cleanup(files).runIfDue();
    expect(files.deleted, [
      'downloads/decks/te/a.yaml.part',
      'downloads/catalog-snapshot.json.part',
      'cache/restore.fnbackup',
      'cache/shared/log.txt',
    ]);
  });

  test(
    'it logs what it removed, and nothing when it removed nothing',
    () async {
      final files = _Files({
        JunkArea.updates: [
          aged('a.apk', const Duration(days: 2), 35 * 1048576),
          aged('b.apk', const Duration(days: 2), 35 * 1048576),
        ],
      });
      await cleanup(files).runIfDue();
      expect(
        log.entries.map((e) => e.message),
        contains(startsWith('Removed 2 old files, 70 MB')),
      );
      final quiet = AppLog(store: MemoryLogStore());
      stamp.value = null;
      await JunkCleanup(
        files: _Files({}),
        stamp: stamp,
        log: quiet,
        version: '0.6.0',
        clock: () => now,
      ).runIfDue();
      expect(quiet.entries, isEmpty);
    },
  );

  test('it runs once a day, and again after an update', () async {
    final files = _Files({
      JunkArea.updates: [aged('a.apk', const Duration(days: 2))],
    });
    expect(await cleanup(files).runIfDue(), 1);
    files.areas[JunkArea.updates] = [aged('b.apk', const Duration(days: 2))];
    expect(await cleanup(files).runIfDue(), 0, reason: 'ran today');
    expect(await cleanup(files, version: '0.6.1').runIfDue(), 1);
    stamp.value = (
      at: now.subtract(const Duration(hours: 25)),
      version: '0.6.1',
    );
    expect(await cleanup(files, version: '0.6.1').runIfDue(), 1);
  });

  test('errors are swallowed', () async {
    final files = _Files({
      JunkArea.updates: [aged('a.apk', const Duration(days: 2))],
    })..failDelete = true;
    expect(await cleanup(files).runIfDue(), 0);
    files.failList = true;
    stamp.value = null;
    expect(await cleanup(files).runIfDue(), 0);
    stamp.failWrite = true;
    stamp.value = null;
    expect(await cleanup(_Files({})).runIfDue(), 0);
  });
}
