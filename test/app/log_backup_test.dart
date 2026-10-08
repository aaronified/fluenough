import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';

Map<ProgressKey, (double, double, int, DateTime, int)> byValue(
  Map<ProgressKey, FsrsState> states,
) => {
  for (final e in states.entries)
    e.key: (
      e.value.stability,
      e.value.difficulty,
      e.value.intervalDays,
      e.value.dueAt,
      e.value.lapses,
    ),
};

List<(String, int, int)> reviewsOf(ProgressStore p) => [
  for (final e in p.log) (e.cardId, e.grade, e.at.millisecondsSinceEpoch),
];

/// Imports [p]'s own export into [into]. How many reviews were new.
Future<int> restore(ProgressStore p, ProgressStore into) {
  final backup = LogJsonl.decode(p.exportJsonl());
  return into.importLog(backup.reviews, backup.leechActions);
}

void main() {
  // Each test opens two databases, each on its own in-memory executor, which
  // is what drift's warning is about.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final at = DateTime(2026, 9, 28, 19);
  DateTime day(int n) => at.add(Duration(days: n));

  const key = (cardId: 'hi-0231', mode: DrillMode.production);

  void answer(ProgressStore p, String card, int grade, DateTime now) =>
      p.record(
        deckId: 'hi-en-market',
        cardId: card,
        mode: DrillMode.production,
        grade: grade,
        now: now,
        answerGiven: 'बाज़ार',
      );

  /// Reviews on two cards with a lapse, a reset and a set-aside.
  void history(ProgressStore p) {
    answer(p, key.cardId, 4, day(0));
    answer(p, 'hi-0232', 5, day(0));
    answer(p, key.cardId, 1, day(1));
    p.actOnLeech(key, LeechActionKind.reset, now: day(2));
    answer(p, key.cardId, 4, day(3));
    answer(p, 'hi-0232', 3, day(4));
    p.actOnLeech(key, LeechActionKind.setAside, now: day(5));
  }

  Future<DatabaseProgress> openDb([AppDatabase? db]) async {
    final progress = await DatabaseProgress.open(
      db ?? AppDatabase(NativeDatabase.memory()),
    );
    addTearDown(progress.dispose);
    addTearDown(progress.close);
    return progress;
  }

  test('a profile exported and imported into an empty one is the same '
      'profile', () async {
    final source = await openDb();
    history(source);

    final db = AppDatabase(NativeDatabase.memory());
    final target = await openDb(db);
    expect(await restore(source, target), 5);

    expect(reviewsOf(target), reviewsOf(source));
    expect(target.log.map((e) => e.answerGiven), everyElement('बाज़ार'));
    expect(byValue(target.states), byValue(source.states));
    expect(target.leechActions.map((a) => (a.key, a.kind, a.at)), [
      for (final a in source.leechActions) (a.key, a.kind, a.at),
    ]);
    expect(target.leechEffects.isSetAside(key), isTrue);

    // What the database holds says the same once reopened.
    await target.flush();
    final rows = await db.reviewsDao.all();
    expect(rows, hasLength(5));
    expect(await db.leechActionsDao.all(), hasLength(2));
    expect(
      rows.map((r) => (r.intervalBefore, r.intervalAfter)),
      source.log.map((e) => (e.before?.intervalDays, e.after.intervalDays)),
    );
    final cached = await db.cardStatesDao.of(key.cardId, key.mode);
    expect(cached!.repetitions, source.states[key]!.repetitions);
  });

  test(
    'importing the same backup twice adds nothing the second time',
    () async {
      final source = await openDb();
      history(source);
      final target = await openDb();
      await restore(source, target);
      final states = byValue(target.states);

      expect(await restore(source, target), 0);
      expect(target.log, hasLength(5));
      expect(target.leechActions, hasLength(2));
      expect(byValue(target.states), states);
    },
  );

  test('older history merged in takes its place in time, on the database and '
      'in memory', () async {
    // The phone that was lost answered on days 0 and 1; the new one on day 3.
    final old = MemoryProgress();
    answer(old, key.cardId, 4, day(0));
    answer(old, key.cardId, 5, day(1));

    // What one phone would hold had it answered all three.
    final whole = MemoryProgress();
    answer(whole, key.cardId, 4, day(0));
    answer(whole, key.cardId, 5, day(1));
    answer(whole, key.cardId, 2, day(3));

    for (final ProgressStore target in <ProgressStore>[
      await openDb(),
      MemoryProgress(),
    ]) {
      answer(target, key.cardId, 2, day(3));
      var told = 0;
      target.addListener(() => told++);

      expect(await restore(old, target), 2);
      expect(told, greaterThan(0), reason: '${target.runtimeType} notifies');
      expect(reviewsOf(target), reviewsOf(whole));
      expect(byValue(target.states), byValue(whole.states));
      expect(
        target.log.map((e) => e.before?.intervalDays),
        whole.log.map((e) => e.before?.intervalDays),
      );
    }
  });

  test(
    'a review answered after an import is recorded on the merged state',
    () async {
      final old = MemoryProgress();
      answer(old, key.cardId, 5, day(0));
      answer(old, key.cardId, 5, day(1));
      final target = await openDb();
      await restore(old, target);

      answer(target, key.cardId, 5, day(8));
      expect(target.log.last.before!.repetitions, 2);
      expect(target.states[key]!.repetitions, 3);
    },
  );
}
