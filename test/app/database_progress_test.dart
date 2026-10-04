import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/profile_storage.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/sm2.dart';

(int, double, int, DateTime, int) fields(Sm2State s) =>
    (s.repetitions, s.easeFactor, s.intervalDays, s.dueAt, s.lapses);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final at = DateTime(2026, 9, 28, 19);
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('fluenough'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// A database in a real file, so that it can be closed and opened again.
  AppDatabase fileDb() =>
      AppDatabase(NativeDatabase(File('${dir.path}/progress.sqlite')));

  void answer(ProgressStore p, String card, int grade, DateTime now) =>
      p.record(
        deckId: 'hi-en-market',
        cardId: card,
        mode: DrillMode.production,
        grade: grade,
        now: now,
      );

  test('answers survive closing the app and opening it again', () async {
    final first = await DatabaseProgress.open(fileDb());
    answer(first, 'hi-0231', 4, at);
    answer(first, 'hi-0232', 1, at);
    answer(first, 'hi-0231', 5, at.add(const Duration(days: 1)));
    final before = {
      for (final e in first.states.entries) e.key: fields(e.value),
    };
    await first.close();
    first.dispose();

    final again = await DatabaseProgress.open(fileDb());
    addTearDown(again.dispose);
    addTearDown(again.close);
    expect(again.persists, isTrue);
    expect(again.log.map((e) => (e.cardId, e.grade)), [
      ('hi-0231', 4),
      ('hi-0232', 1),
      ('hi-0231', 5),
    ]);
    expect({
      for (final e in again.states.entries) e.key: fields(e.value),
    }, before);
  });

  test('reads change at once; writes reach the database in order', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final progress = await DatabaseProgress.open(db);
    addTearDown(progress.dispose);
    addTearDown(progress.close);
    var told = 0;
    progress.addListener(() => told++);

    for (var i = 1; i <= 3; i++) {
      answer(progress, 'hi-023$i', 4, at.add(Duration(minutes: i)));
      expect(progress.log, hasLength(i), reason: 'before any write lands');
    }
    expect(told, 3);
    await progress.flush();
    expect((await db.reviewsDao.all()).map((r) => r.cardId), [
      'hi-0231',
      'hi-0232',
      'hi-0233',
    ]);
    expect(await db.cardStatesDao.all(), hasLength(3));
  });

  test('a write that fails is reported, and flush throws it', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final progress = await DatabaseProgress.open(db);
    addTearDown(progress.dispose);
    addTearDown(progress.close);
    await db.customStatement(
      'CREATE TRIGGER fail BEFORE INSERT ON reviews '
      "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    answer(progress, 'hi-0231', 4, at);
    await expectLater(progress.flush(), throwsA(anything));
    expect(reported.single.library, 'fluenough progress');
  });

  test('opening repairs a state cache that disagrees with the log', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await ReviewLog(db).record(
      deckId: 'hi-en-market',
      cardId: 'hi-0231',
      mode: DrillMode.recognition,
      grade: 5,
      now: at,
    );
    await db.cardStatesDao.clear();

    final progress = await DatabaseProgress.open(db);
    addTearDown(progress.dispose);
    addTearDown(progress.close);
    expect(await db.cardStatesDao.all(), hasLength(1));
    expect(progress.states, hasLength(1));
  });

  test(
    'a session over a seeded database has exactly its due reviews',
    () async {
      final probe = AppState.test();
      await probe.load();
      final deck = probe.decks.firstWhere(
        (d) => d.language.code == 'es' && d.cards.length >= 4,
      );
      probe.dispose();
      final cards = deck.cards.take(4).toList();
      final now = at;

      // Seed: two recognition pairs due by now, one due in the future.
      final db = AppDatabase(NativeDatabase.memory());
      final seed = ReviewLog(db);
      final day = const Duration(days: 1);
      for (final (card, grade, time) in [
        (cards[0], 4, now.subtract(day * 3)), // interval 1: due 2 days ago
        (cards[1], 1, now.subtract(day * 2)), // failed: due yesterday
        (cards[2], 5, now.subtract(const Duration(hours: 2))), // due tomorrow
      ]) {
        await seed.record(
          deckId: deck.id,
          cardId: card.id,
          mode: DrillMode.recognition,
          grade: grade,
          now: time,
        );
      }

      final progress = await DatabaseProgress.open(db);
      addTearDown(progress.dispose);
      addTearDown(progress.close);
      final state = AppState.test(progress: progress, now: now);
      addTearDown(state.dispose);
      await state.load();
      expect(state.progressIsSaved, isTrue);

      final queue = state.buildSession(DrillRequest.deck(deck.id));
      final due = queue.due.where((i) => i.mode == DrillMode.recognition);
      expect(due.map((i) => i.card.id).toSet(), {cards[0].id, cards[1].id});
      expect(
        queue.items.any(
          (i) => i.card.id == cards[2].id && i.mode == DrillMode.recognition,
        ),
        isFalse,
        reason: 'reviewed and not yet due',
      );
      // New pairs are new skills of the words taught, those three.
      expect(
        queue.fresh.map((i) => i.card.id),
        everyElement(isIn(<String>{for (final c in cards.take(3)) c.id})),
      );
    },
  );

  test('saved needs both the database and persistence switched on', () async {
    final progress = await DatabaseProgress.open(
      AppDatabase(NativeDatabase.memory()),
    );
    addTearDown(progress.dispose);
    addTearDown(progress.close);
    final on = AppState.test(progress: progress);
    final off = AppState.test(
      progress: progress,
      features: const FeatureRegistry.only(<Feature>{}),
    );
    final memory = AppState.test(progress: MemoryProgress());
    addTearDown(on.dispose);
    addTearDown(off.dispose);
    addTearDown(memory.dispose);
    expect(
      (on.progressIsSaved, off.progressIsSaved, memory.progressIsSaved),
      (true, false, false),
    );
  });

  test('each profile has its own file', () {
    expect(
      databaseFileName(const Profile(id: 'mira', name: 'Mira')),
      isNot(databaseFileName(Profile.defaultProfile)),
    );
  });

  test('leech actions are saved, and a reset holds after reopening', () async {
    const key = (cardId: 'hi-0231', mode: DrillMode.production);
    final first = await DatabaseProgress.open(fileDb());
    answer(first, key.cardId, 4, at);
    answer(first, key.cardId, 1, at.add(const Duration(days: 1)));
    first.actOnLeech(
      key,
      LeechActionKind.reset,
      now: at.add(const Duration(days: 2)),
    );
    expect(first.stateOf(key.cardId, key.mode), isNull);
    answer(first, key.cardId, 5, at.add(const Duration(days: 3)));
    first.actOnLeech(
      key,
      LeechActionKind.setAside,
      now: at.add(const Duration(days: 3, hours: 1)),
    );
    final memory = first.stateOf(key.cardId, key.mode)!;
    await first.close();
    first.dispose();

    final db = fileDb();
    final again = await DatabaseProgress.open(db);
    addTearDown(again.dispose);
    addTearDown(again.close);
    expect(again.leechActions.map((a) => a.kind), [
      LeechActionKind.reset,
      LeechActionKind.setAside,
    ]);
    expect(again.log, hasLength(3), reason: 'no review is removed');
    final restored = again.stateOf(key.cardId, key.mode)!;
    expect(fields(restored), fields(memory));
    expect(restored.repetitions, 1, reason: 'restarted at the reset');
    expect(again.leechEffects.isSetAside(key), isTrue);

    final rows = await db.reviewsDao.all();
    expect(rows.last.intervalBefore, isNull, reason: 'fresh after the reset');
    final cached = (await db.cardStatesDao.of(key.cardId, key.mode))!;
    expect(cached.repetitions, restored.repetitions);
  });

  test(
    'a set-aside pair leaves the session; brought back, it returns',
    () async {
      final progress = await DatabaseProgress.open(
        AppDatabase(NativeDatabase.memory()),
      );
      addTearDown(progress.dispose);
      addTearDown(progress.close);
      final state = AppState.test(progress: progress, now: at);
      addTearDown(state.dispose);
      await state.load();
      final deck = state.decks.firstWhere((d) => d.cards.length >= 2);
      final card = deck.cards.first;
      const mode = DrillMode.recognition;
      progress.record(
        deckId: deck.id,
        cardId: card.id,
        mode: mode,
        grade: 1,
        now: at.subtract(const Duration(days: 2)),
      );
      bool queued() => state
          .buildSession(DrillRequest.deck(deck.id))
          .items
          .any((i) => i.card.id == card.id && i.mode == mode);
      expect(queued(), isTrue);

      final key = (cardId: card.id, mode: mode);
      progress.actOnLeech(key, LeechActionKind.setAside, now: at);
      expect(queued(), isFalse);
      expect(progress.log, hasLength(1), reason: 'its history stays');

      progress.actOnLeech(key, LeechActionKind.bringBack, now: at);
      expect(queued(), isTrue);
      await progress.flush();
    },
  );
}
