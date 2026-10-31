// Cold start (#857): the first frame does not wait for the review log, and
// the counts do not wait for the phone's voices.

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/replay_isolate.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a store holds, as plain values to compare.
List<Object?> _held(ProgressStore p) => <Object?>[
  for (final e in p.log)
    (
      e.cardId,
      e.mode,
      e.grade,
      e.at,
      e.before?.intervalDays,
      e.after.intervalDays,
      e.after.stability,
    ),
  for (final MapEntry(:key, :value)
      in p.states.entries.toList()
        ..sort((a, b) => '${a.key}'.compareTo('${b.key}')))
    (
      key,
      value.stability,
      value.difficulty,
      value.intervalDays,
      value.repetitions,
      value.dueAt,
      value.lastReviewAt,
      value.lapses,
    ),
  p.version > 0,
];

/// A voice answer that waits to be given.
class _SlowTts extends FixedTtsEngine {
  _SlowTts(super.voices);

  final Completer<void> answer = Completer<void>();

  @override
  Future<bool> isLanguageAvailable(String bcp47) async {
    await answer.future;
    return super.isLanguageAvailable(bcp47);
  }
}

void main() {
  group('opening progress in the background', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('fluenough'));
    tearDown(() => dir.deleteSync(recursive: true));

    AppDatabase fileDb() =>
        AppDatabase(NativeDatabase(File('${dir.path}/progress.sqlite')));

    test('holds nothing until ready, then what an eager open holds; '
        'the catalog waits for it', () async {
      final at = DateTime(2026, 9, 28, 19);
      final first = await DatabaseProgress.open(fileDb());
      for (var i = 0; i < 6; i++) {
        first.record(
          deckId: 'es-en-core-100',
          cardId: 'es-000${i % 3 + 1}',
          mode: i.isEven ? DrillMode.recognition : DrillMode.production,
          grade: i % 4 + 1,
          now: at.add(Duration(days: i)),
        );
      }
      await first.flush();
      await first.close();

      final eager = await DatabaseProgress.open(fileDb());
      final lazy = DatabaseProgress.opening(fileDb());
      addTearDown(eager.close);
      addTearDown(lazy.close);
      expect(lazy.log, isEmpty, reason: 'nothing is read before ready');

      final state = AppState.test(progress: lazy);
      addTearDown(state.dispose);
      await state.load();
      expect(
        lazy.log,
        isNotEmpty,
        reason: 'the catalog is not ready before progress is',
      );
      expect(_held(lazy), _held(eager));

      // The cache holds one row for each pair, as an eager open leaves it.
      await lazy.flush();
      final db = fileDb();
      addTearDown(db.close);
      expect((await db.cardStatesDao.all()).length, eager.states.length);
    });
  });

  group('replaying the log on an isolate', () {
    final at = DateTime(2026, 9, 28, 19);

    /// A log with what a replay has to get right: answers out of time order,
    /// several languages and modes, a walkthrough's view, a reset and an
    /// answer typed rather than rated.
    Future<AppDatabase> loggedDb() async {
      final db = AppDatabase(NativeDatabase.memory());
      final log = ReviewLog(db);
      final days = <int>[3, 0, 5, 1, 2, 9, 4, 4, 7, 6, 8, 10];
      for (final (i, day) in days.indexed) {
        await log.record(
          deckId: i.isEven ? 'es-en-core-100' : 'hi-en-market',
          cardId: i.isEven ? 'es-000${i % 3 + 1}' : 'hi-023${i % 2}',
          mode: i % 3 == 0 ? DrillMode.production : DrillMode.recognition,
          grade: i % 5,
          now: at.add(Duration(days: day, minutes: i)),
          asked: i == 3 ? Ask.teach : null,
          answerGiven: i == 5 ? 'agua' : null,
        );
      }
      await db.leechActionsDao.append(
        LeechAction(
          at: at.add(const Duration(days: 4, hours: 12)),
          key: (cardId: 'es-0001', mode: DrillMode.production),
          kind: LeechActionKind.reset,
        ),
      );
      return db;
    }

    test('gives what replaying in place gives: events, states, version, '
        'aggregates and the cache', () async {
      final db = await loggedDb();
      addTearDown(db.close);
      final stages = <String>[];
      final isolate = await DatabaseProgress.open(
        db,
        replayer: replayInIsolate,
        onStage: stages.add,
      );
      final cached = {
        for (final r in await db.cardStatesDao.all()) (r.cardId, r.mode): r,
      };
      final inPlace = await DatabaseProgress.open(db, replayer: replayInPlace);
      addTearDown(isolate.dispose);
      addTearDown(inPlace.dispose);

      expect(isolate.persists, isTrue);
      expect(isolate.log, hasLength(12));
      expect(_held(isolate), _held(inPlace));
      expect(isolate.version, inPlace.version);
      expect(
        isolate.log.map((e) => (e.share, e.isView, e.script)),
        inPlace.log.map((e) => (e.share, e.isView, e.script)),
      );
      expect(isolate.leechActions, hasLength(1));
      expect(isolate.parameters.lastStudied, inPlace.parameters.lastStudied);
      for (final language in <String>['es', 'hi']) {
        expect(isolate.index.reviewsIn(language), isPositive);
        expect(
          isolate.index.reviewsIn(language),
          inPlace.index.reviewsIn(language),
        );
        expect(
          isolate.index.latestIn(language),
          inPlace.index.latestIn(language),
        );
        expect(isolate.index.perDay(language), inPlace.index.perDay(language));
        expect(isolate.versionOf(language), inPlace.versionOf(language));
      }
      expect(isolate.index.length, inPlace.index.length);
      expect(
        isolate.index.length,
        11,
        reason: 'the walkthrough view is no answer',
      );

      // The same as replaying the events here, as MemoryProgress always has.
      final direct = MemoryProgress.replaying(
        isolate.log,
        leechActions: isolate.leechActions,
        fitted: isolate.parameters.fitted,
      );
      addTearDown(direct.dispose);
      expect(_held(isolate), _held(direct));
      expect(isolate.scriptLog.length, direct.scriptLog.length);

      // The state cache is each pair's own reviews alone, what a replay in
      // place gives for it; memory's states also count what answers imply
      // for other skills, so they are not the cache.
      final wanted = (await ReviewLog(db).openReplay(
        fitted: await ReviewLog(db).fitted(),
        run: replayInPlace,
      )).cacheStates;
      expect(cached.length, wanted.length);
      for (final MapEntry(:key, :value) in wanted.entries) {
        final row = cached[(key.cardId, key.mode)]!;
        expect((row.stability, row.dueAt), (value.stability, value.dueAt));
      }
      expect(stages, <String>['review log replayed', 'state cache written']);
    });

    test('a job crosses to the isolate and back as plain data', () async {
      final db = await loggedDb();
      addTearDown(db.close);
      final log = ReviewLog(db);
      final fitted = await log.fitted();
      final viaIsolate = await log.openReplay(fitted: fitted);
      final inPlace = await log.openReplay(fitted: fitted, run: replayInPlace);
      expect(viaIsolate.memory.events, hasLength(12));
      expect(
        viaIsolate.memory.events.map((e) => (e.cardId, e.at, e.after.dueAt)),
        inPlace.memory.events.map((e) => (e.cardId, e.at, e.after.dueAt)),
      );
      expect(
        viaIsolate.cacheStates.keys.toSet(),
        inPlace.cacheStates.keys.toSet(),
      );
      expect(viaIsolate.lastStudied, inPlace.lastStudied);
    });

    test('a replay that fails falls back to unsaved progress and writes '
        'nothing', () async {
      final db = await loggedDb();
      final progress = DatabaseProgress.opening(
        db,
        replayer: (_) async => throw StateError('the isolate failed'),
      );
      addTearDown(progress.close);
      final cachedBefore = (await db.cardStatesDao.all()).length;
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      await progress.ready; // does not throw
      expect(progress.persists, isFalse);
      expect(reported, isNotEmpty);
      expect(progress.log, isEmpty);

      progress.record(
        deckId: 'es-en-core-100',
        cardId: 'es-0001',
        mode: DrillMode.recognition,
        grade: 3,
        now: at.add(const Duration(days: 20)),
      );
      await progress.flush();
      expect(progress.log, hasLength(1));
      expect(await db.reviewsDao.all(), hasLength(12));
      expect(await db.cardStatesDao.all(), hasLength(cachedBefore));
    });
  });

  group('a review log that cannot be read', () {
    test('the app falls back to unsaved progress: the catalog loads, nothing '
        'is written, and Try again works', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.customStatement('DROP TABLE reviews');
      final progress = DatabaseProgress.opening(db);
      addTearDown(progress.close);
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      await progress.ready; // does not throw
      expect(progress.persists, isFalse, reason: 'Today says: not saved');
      expect(reported, isNotEmpty);

      final state = AppState.test(progress: progress);
      addTearDown(state.dispose);
      await state.load();
      expect(state.status, CatalogStatus.ready);

      // Answers still count in memory, and none reaches the database.
      progress.record(
        deckId: 'es-en-core-100',
        cardId: 'es-0001',
        mode: DrillMode.recognition,
        grade: 3,
        now: DateTime(2026, 9, 28, 19),
      );
      expect(progress.log, hasLength(1));
      await progress.flush();

      await state.reload();
      expect(state.status, CatalogStatus.ready);
    });
  });

  group('voices still being asked', () {
    test('Listening stays in the counts, and the answer changes nothing '
        'when the phone has the voice', () async {
      final tts = _SlowTts(const <String>{'es', 'hi'});
      final progress = MemoryProgress();
      final seed = AppState.test();
      await seed.load();
      for (final card in seed.untaughtCards('es').take(4)) {
        progress.record(
          deckId: card.deckId,
          cardId: card.id,
          mode: DrillMode.listening,
          grade: 4,
          now: seed.now().subtract(const Duration(days: 3)),
        );
      }
      seed.dispose();

      final state = AppState.test(tts: tts, progress: progress)
        ..showLanguage('es');
      addTearDown(state.dispose);
      var told = 0;
      final loading = state.load();
      while (state.status != CatalogStatus.ready) {
        await Future<void>.delayed(Duration.zero);
      }
      final spanish = state.deckById('es-en-core-100')!.language;
      expect(state.voiceStatus(spanish), VoiceStatus.checking);

      int listening() => TodayNumbers.of(state).bySkill[Skill.listening] ?? 0;
      final before = listening();
      expect(before, greaterThan(0));

      state.addListener(() => told++);
      tts.answer.complete();
      await loading;
      expect(state.voiceStatus(spanish), VoiceStatus.available);
      expect(listening(), before, reason: 'no jump when the voice answers');
      expect(told, 1, reason: 'the voices notify once');
    });

    test('a phone with no voice loses Listening once it has said so', () async {
      final tts = _SlowTts(const <String>{});
      final progress = MemoryProgress();
      final seed = AppState.test();
      await seed.load();
      for (final card in seed.untaughtCards('es').take(4)) {
        progress.record(
          deckId: card.deckId,
          cardId: card.id,
          mode: DrillMode.listening,
          grade: 4,
          now: seed.now().subtract(const Duration(days: 3)),
        );
      }
      seed.dispose();
      final state = AppState.test(tts: tts, progress: progress)
        ..showLanguage('es');
      addTearDown(state.dispose);
      final loading = state.load();
      while (state.status != CatalogStatus.ready) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        TodayNumbers.of(state).bySkill[Skill.listening] ?? 0,
        greaterThan(0),
      );
      tts.answer.complete();
      await loading;
      expect(TodayNumbers.of(state).bySkill[Skill.listening] ?? 0, 0);
    });
  });
}
