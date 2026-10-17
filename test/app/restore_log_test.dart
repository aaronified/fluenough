import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/backup_store.dart';
import 'package:fluenough/app/backups.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/replay.dart';

/// A restore is the one exception to `reviews` and `leech_actions` being
/// append-only (AGENTS.md rule 9; owner, 2026-10-17: "Logged exception"):
/// it replaces both, in one transaction, and keeps a record of itself in
/// `restores`. Nothing else can delete from them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final at = DateTime(2026, 9, 28, 19);
  late AppDatabase db;
  late ReviewLog log;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    log = ReviewLog(db);
  });
  tearDown(() => db.close());

  LoggedReview logged(String card, int grade, DateTime when) => (
    key: (cardId: card, mode: DrillMode.production),
    deckId: 'hi-en-market',
    at: when,
    grade: grade,
    elapsed: const Duration(seconds: 2),
    answerGiven: null,
  );

  RestoreRecord record() => RestoreRecord(
    at: at.add(const Duration(days: 10)),
    backupCreatedAt: at.add(const Duration(days: 3)),
    backupKind: 'you',
    backupAppVersion: '0.5.0',
    fromFile: true,
    keptCopy: 'fluenough-backup-20261008-190000-000-0-restore.fnbackup',
  );

  /// The learner's own progress: two reviews of Bengali and a leech set
  /// aside.
  Future<void> ownProgress() async {
    for (final card in <String>['bn-0001', 'bn-0002']) {
      await log.record(
        deckId: 'bn-en-core',
        cardId: card,
        mode: DrillMode.production,
        grade: 3,
        now: at,
      );
    }
    await log.act(
      LeechAction(
        at: at,
        key: (cardId: 'bn-0001', mode: DrillMode.production),
        kind: LeechActionKind.setAside,
      ),
    );
  }

  /// The backup's: three reviews of Hindi and a leech reset.
  final backupReviews = <LoggedReview>[
    logged('hi-0231', 4, at.add(const Duration(days: 1))),
    logged('hi-0232', 1, at.add(const Duration(days: 1, hours: 1))),
    logged('hi-0231', 5, at.add(const Duration(days: 2))),
  ];
  final backupActions = <LeechAction>[
    LeechAction(
      at: at.add(const Duration(days: 2, hours: 1)),
      key: (cardId: 'hi-0232', mode: DrillMode.production),
      kind: LeechActionKind.reset,
    ),
  ];

  Future<List<String>> triggers() => db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' ORDER BY name",
      )
      .map((r) => r.read<String>('name'))
      .get();

  const guards = <String>[
    'leech_actions_no_delete',
    'leech_actions_no_update',
    'restores_no_delete',
    'restores_no_update',
    'reviews_no_delete',
    'reviews_no_update',
  ];

  Matcher appendOnly(String table) =>
      throwsA(predicate((Object e) => '$e'.contains('$table is append-only')));

  /// A trigger runs once per row, so each table checked holds a row;
  /// `restores` is checked once a restore is in it.
  Future<void> expectEveryDeleteRefused({required bool restored}) async {
    for (final table in <String>[
      'reviews',
      'leech_actions',
      if (restored) 'restores',
    ]) {
      await expectLater(
        db.customStatement('DELETE FROM $table'),
        appendOnly(table),
        reason: table,
      );
    }
    await expectLater(db.delete(db.reviews).go(), appendOnly('reviews'));
    await expectLater(
      db.delete(db.leechActions).go(),
      appendOnly('leech_actions'),
    );
    await expectLater(
      db.update(db.reviews).write(const ReviewsCompanion(grade: Value(0))),
      appendOnly('reviews'),
    );
    if (!restored) return;
    await expectLater(
      db
          .update(db.restores)
          .write(const RestoresCompanion(keptCopy: Value('elsewhere'))),
      appendOnly('restores'),
    );
  }

  test('a confirmed restore clears both logs and puts the backup\'s in '
      'their place', () async {
    await ownProgress();
    await log.replaceAll(backupReviews, backupActions, restore: record());

    final reviews = await db.reviewsDao.all();
    expect(
      reviews.map((r) => (r.cardId, r.grade, r.ts)),
      backupReviews.map((r) => (r.key.cardId, r.grade, r.at)),
    );
    expect(reviews.first.intervalBefore, isNull);
    final actions = await db.leechActionsDao.all();
    expect(actions.map((a) => (a.key.cardId, a.kind, a.at)), <Object>[
      ('hi-0232', LeechActionKind.reset, backupActions.single.at),
    ]);
    // hi-0232 was reset after its last review, so only hi-0231 has a
    // schedule; Bengali has none.
    expect(
      (await db.cardStatesDao.all()).map((s) => s.cardId).toSet(),
      <String>{'hi-0231'},
      reason: 'the schedules are rebuilt from the backup\'s log alone',
    );
  });

  test('the restore is logged: when, from which backup, where the copy of '
      'what it replaced is, and how many reviews before and after', () async {
    await ownProgress();
    await log.replaceAll(backupReviews, backupActions, restore: record());
    final kept = (await db.restoresDao.all()).single;
    expect(kept.at, at.add(const Duration(days: 10)));
    expect(kept.backupCreatedAt, at.add(const Duration(days: 3)));
    expect(kept.backupKind, 'you');
    expect(kept.backupAppVersion, '0.5.0');
    expect(kept.fromFile, isTrue);
    expect(kept.keptCopy, record().keptCopy);
    expect((kept.reviewsBefore, kept.reviewsAfter), (2, 3));

    // A second restore adds a second record; the first is still there.
    await log.replaceAll(
      const <LoggedReview>[],
      const <LeechAction>[],
      restore: record(),
    );
    final both = await db.restoresDao.all();
    expect(both, hasLength(2));
    expect((both.last.reviewsBefore, both.last.reviewsAfter), (3, 0));
  });

  test('every other delete or update is still refused, before and after a '
      'restore, and the restore log itself is append-only', () async {
    await ownProgress();
    expect(await triggers(), guards);
    await expectEveryDeleteRefused(restored: false);

    await log.replaceAll(backupReviews, backupActions, restore: record());
    expect(await triggers(), guards, reason: 'the guards are back');
    await expectEveryDeleteRefused(restored: true);
    expect(await db.reviewsDao.all(), hasLength(3));
    expect(await db.leechActionsDao.all(), hasLength(1));
    expect(await db.restoresDao.all(), hasLength(1));
  });

  test('a restore that fails part-way leaves both logs, their guards and the '
      'restore log as they were', () async {
    await ownProgress();
    final reviewsBefore = await db.reviewsDao.all();
    final actionsBefore = await db.leechActionsDao.all();
    final statesBefore = await db.cardStatesDao.all();

    // Grade 9 is refused as the backup's reviews are written: after both
    // logs were emptied, inside the same transaction.
    await expectLater(
      log.replaceAll(
        <LoggedReview>[...backupReviews, logged('hi-0233', 9, at)],
        backupActions,
        restore: record(),
      ),
      throwsA(anything),
    );

    final reviewsAfter = await db.reviewsDao.all();
    expect(
      reviewsAfter.map((r) => (r.id, r.cardId, r.grade)),
      reviewsBefore.map((r) => (r.id, r.cardId, r.grade)),
    );
    expect(
      (await db.leechActionsDao.all()).map((a) => (a.key.cardId, a.kind)),
      actionsBefore.map((a) => (a.key.cardId, a.kind)),
    );
    expect(
      (await db.cardStatesDao.all()).map((s) => s.cardId),
      statesBefore.map((s) => s.cardId),
    );
    expect(await db.restoresDao.all(), isEmpty, reason: 'nothing is logged');
    expect(await triggers(), guards, reason: 'the dropped guard comes back');
    await expectEveryDeleteRefused(restored: false);
  });

  test('restoring a backup in the app replaces the database\'s log, and '
      'the record names the copy kept first', () async {
    // The backup: a learner's Hindi.
    final source = AppState.test(now: at);
    addTearDown(source.dispose);
    for (final r in backupReviews) {
      source.progress.record(
        deckId: r.deckId,
        cardId: r.key.cardId,
        mode: r.key.mode,
        grade: r.grade,
        now: r.at,
      );
    }
    final backup = AppBackup.decode(
      source.backups.snapshot(BackupKind.you).encode(),
    );

    // This phone: its own Bengali, in the database.
    await ownProgress();
    final progress = await DatabaseProgress.open(db);
    final store = MemoryBackupStore();
    final state = AppState.test(
      progress: progress,
      backupStore: store,
      now: at.add(const Duration(days: 10)),
    );
    addTearDown(state.dispose);

    await state.backups.restore(backup, fromFile: true);

    expect(
      (await db.reviewsDao.all()).map((r) => r.cardId),
      backupReviews.map((r) => r.key.cardId),
    );
    expect(progress.log.map((e) => e.cardId), isNot(contains('bn-0001')));
    expect(progress.log, hasLength(3));
    expect(await db.leechActionsDao.all(), isEmpty);

    final copy = (await store.list()).firstWhere(
      (b) => b.kind == BackupKind.restore,
    );
    final kept = (await db.restoresDao.all()).single;
    expect(kept.keptCopy, copy.id);
    expect(
      AppBackup.decode(await store.read(copy)).reviews.map((r) => r.key.cardId),
      <String>['bn-0001', 'bn-0002'],
      reason: 'the copy is of what was replaced',
    );
    expect(kept.backupCreatedAt, backup.createdAt);
    expect(kept.backupKind, 'you');
    expect(kept.fromFile, isTrue);
    expect((kept.reviewsBefore, kept.reviewsAfter), (2, 3));
  });
}
