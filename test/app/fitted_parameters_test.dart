import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';

/// FSRS-6's defaults with the first Good stability set to [w2]: a set that
/// tells itself apart by a word's first interval.
FittedParameters fitWith(double w2, DateTime at, {int reviews = 500}) =>
    FittedParameters(
      values: <double>[...Fsrs.w]..[2] = w2,
      fittedAt: at,
      reviewCount: reviews,
      lossBefore: 0.4,
      lossAfter: 0.35,
    );

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final at = DateTime(2026, 9, 28, 19);
  DateTime day(int n) => at.add(Duration(days: n));
  const hiWrite = (language: 'hi', mode: DrillMode.production);
  const bnWrite = (language: 'bn', mode: DrillMode.production);

  void answer(ProgressStore p, String card, int grade, DateTime now) =>
      p.record(
        deckId: 'deck',
        cardId: card,
        mode: DrillMode.production,
        grade: grade,
        now: now,
        answerGiven: 'typed',
      );

  /// What replaying [p]'s log afresh, with its fits, gives.
  MemoryProgress replayed(ProgressStore p) => MemoryProgress.replaying(
    p.log,
    leechActions: p.leechActions,
    skills: p.skills,
    fitted: p.parameters.fitted,
  );

  group('in memory', () {
    test(
      'a review is scheduled with its skill\'s set, and the preview too',
      () {
        final p = MemoryProgress();
        p.putFitted(hiWrite, fitWith(9, at));
        answer(p, 'hi-0001', 4, day(0));
        expect(p.stateOf('hi-0001', DrillMode.production)!.stability, 9);
        expect(
          p.preview('hi-0002', DrillMode.production, 4, now: day(0)).stability,
          9,
        );
        answer(p, 'te-0001', 4, day(0));
        // te has no Write fit, and hi is the only language with one.
        expect(p.stateOf('te-0001', DrillMode.production)!.stability, 9);
      },
    );

    test('a fit reschedules the words of its skill at once', () async {
      final p = MemoryProgress();
      answer(p, 'hi-0001', 4, day(0));
      answer(p, 'hi-0001', 4, day(3));
      final before = p.stateOf('hi-0001', DrillMode.production)!;
      await p.putFitted(hiWrite, fitWith(9, day(4)));
      final after = p.stateOf('hi-0001', DrillMode.production)!;
      expect(after.stability, isNot(before.stability));
      expect(byValue(p.states), byValue(replayed(p).states));
      expect(p.log.first.after.stability, 9, reason: 'the log replays too');
    });

    test('recording after a fit matches replaying the log', () async {
      final p = MemoryProgress();
      answer(p, 'hi-0001', 4, day(0));
      await p.putFitted(hiWrite, fitWith(9, day(1)));
      answer(p, 'hi-0001', 3, day(5));
      answer(p, 'hi-0002', 1, day(5));
      answer(p, 'hi-0001', 4, day(20));
      expect(byValue(p.states), byValue(replayed(p).states));
    });

    test(
      'when another language becomes the baseline, every state follows',
      () async {
        final p = MemoryProgress();
        await p.putFitted(hiWrite, fitWith(9, at));
        await p.putFitted(bnWrite, fitWith(2, at));
        answer(p, 'hi-0001', 4, day(0));
        answer(p, 'te-0001', 4, day(1));
        // hi was studied last: te starts from hi's Write.
        expect(p.parameters.sourceOf('te', DrillMode.production), 'hi');
        expect(p.stateOf('te-0001', DrillMode.production)!.stability, 9);

        answer(p, 'bn-0001', 4, day(2));
        // Now bn: te's word is rescheduled with bn's set, as a replay would.
        expect(p.parameters.sourceOf('te', DrillMode.production), 'bn');
        expect(p.stateOf('te-0001', DrillMode.production)!.stability, 2);
        expect(byValue(p.states), byValue(replayed(p).states));
      },
    );

    test(
      'importing a backup brings its fits; a later one here stays',
      () async {
        final source = MemoryProgress();
        answer(source, 'hi-0001', 4, day(0));
        await source.putFitted(hiWrite, fitWith(9, day(1)));
        await source.putFitted(bnWrite, fitWith(3, day(1)));
        final backup = LogJsonl.decode(source.exportJsonl());

        final target = MemoryProgress();
        await target.putFitted(bnWrite, fitWith(5, day(2)));
        await target.importLog(
          backup.reviews,
          backup.leechActions,
          fitted: backup.fitted,
        );
        expect(
          target.parameters.fitted[hiWrite],
          source.parameters.fitted[hiWrite],
        );
        expect(target.parameters.of('bn', DrillMode.production)[2], 5);
        expect(target.stateOf('hi-0001', DrillMode.production)!.stability, 9);
      },
    );
  });

  group('in the database', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('fluenough'));
    tearDown(() => dir.deleteSync(recursive: true));
    AppDatabase fileDb([String name = 'progress']) =>
        AppDatabase(NativeDatabase(File('${dir.path}/$name.sqlite')));

    test(
      'a fit is kept, and the phone schedules with it after a restart',
      () async {
        final db = fileDb();
        final first = await DatabaseProgress.open(db);
        answer(first, 'hi-0001', 4, day(0));
        answer(first, 'hi-0002', 1, day(0));
        final fit = fitWith(9, day(1));
        await first.putFitted(hiWrite, fit);
        answer(first, 'hi-0001', 4, day(4));
        final states = byValue(first.states);
        await first.close();
        first.dispose();

        final again = await DatabaseProgress.open(fileDb());
        addTearDown(again.dispose);
        addTearDown(again.close);
        expect(again.parameters.fitted, {hiWrite: fit});
        expect(byValue(again.states), states);
      },
    );

    test(
      'the state cache is rebuilt with the fit, and records with it',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        final p = await DatabaseProgress.open(db);
        addTearDown(p.dispose);
        addTearDown(p.close);
        answer(p, 'hi-0001', 4, day(0));
        await p.putFitted(hiWrite, fitWith(9, day(1)));
        await p.flush();
        expect(
          (await db.cardStatesDao.of(
            'hi-0001',
            DrillMode.production,
          ))!.stability,
          9,
        );
        answer(p, 'hi-0002', 4, day(2));
        await p.flush();
        final rows = await db.reviewsDao.all();
        expect(rows.last.stabilityAfter, 9);
        final row = (await db.fsrsParametersDao.all()).single;
        expect(row.language, 'hi');
        expect(row.reviewCount, 500);
        expect(row.lossBefore, 0.4);
        expect(row.lossAfter, 0.35);
      },
    );

    test(
      'a backup restored on a new phone schedules exactly as before',
      () async {
        final source = await DatabaseProgress.open(
          AppDatabase(NativeDatabase.memory()),
        );
        addTearDown(source.dispose);
        addTearDown(source.close);
        answer(source, 'hi-0001', 4, day(0));
        answer(source, 'bn-0001', 3, day(1));
        await source.putFitted(hiWrite, fitWith(9, day(2)));
        answer(source, 'hi-0001', 4, day(6));
        answer(source, 'te-0001', 4, day(7));

        final db = fileDb('restored');
        final target = await DatabaseProgress.open(db);
        final backup = LogJsonl.decode(source.exportJsonl());
        expect(backup.fitted, source.parameters.fitted);
        expect(
          await target.importLog(
            backup.reviews,
            backup.leechActions,
            fitted: backup.fitted,
          ),
          4,
        );
        expect(target.parameters.fitted, source.parameters.fitted);
        expect(byValue(target.states), byValue(source.states));
        await target.close();
        target.dispose();

        // And once the restored phone is restarted.
        final reopened = await DatabaseProgress.open(fileDb('restored'));
        addTearDown(reopened.dispose);
        addTearDown(reopened.close);
        expect(reopened.parameters.fitted, source.parameters.fitted);
        expect(byValue(reopened.states), byValue(source.states));
      },
    );

    test('an old backup, without fits, still restores', () async {
      final source = await DatabaseProgress.open(
        AppDatabase(NativeDatabase.memory()),
      );
      addTearDown(source.dispose);
      addTearDown(source.close);
      answer(source, 'hi-0001', 4, day(0));
      final old = source.exportJsonl();
      expect(old, isNot(contains('"parameters"')));

      final target = await DatabaseProgress.open(
        AppDatabase(NativeDatabase.memory()),
      );
      addTearDown(target.dispose);
      addTearDown(target.close);
      final backup = LogJsonl.decode(old);
      expect(await target.importLog(backup.reviews, backup.leechActions), 1);
      expect(target.parameters.fitted, isEmpty);
      expect(byValue(target.states), byValue(source.states));
    });
  });
}
