import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/data/card_state_repository.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/sm2.dart';

/// Every field of [s], so two states compare by value.
(int, double, int, DateTime, int) fields(Sm2State s) =>
    (s.repetitions, s.easeFactor, s.intervalDays, s.dueAt, s.lapses);

Map<ProgressKey, (int, double, int, DateTime, int)> byValue(
  Map<ProgressKey, Sm2State> states,
) => {for (final e in states.entries) e.key: fields(e.value)};

void main() {
  late AppDatabase db;
  late ReviewLog log;
  late CardStateRepository states;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    log = ReviewLog(db);
    states = CardStateRepository(db);
  });
  tearDown(() => db.close());

  final start = DateTime(2026, 9, 29, 8, 30);

  /// Twenty reviews over three pairs in two decks, with passes, lapses and
  /// relearning, a day or so apart.
  Future<List<ReviewEvent>> recordTwenty() async {
    const pairs = <(String, String, DrillMode)>[
      ('hi-en-market', 'hi-en-market-0001', DrillMode.recognition),
      ('hi-en-market', 'hi-en-market-0001', DrillMode.production),
      ('bn-en-market', 'bn-en-market-0004', DrillMode.recognition),
    ];
    const grades = <int>[
      4,
      5,
      3,
      1,
      4,
      2,
      5,
      4,
      0,
      3,
      4,
      5,
      1,
      4,
      4,
      3,
      5,
      2,
      4,
      5,
    ];
    return <ReviewEvent>[
      for (var i = 0; i < grades.length; i++)
        await log.record(
          deckId: pairs[i % 3].$1,
          cardId: pairs[i % 3].$2,
          mode: pairs[i % 3].$3,
          grade: grades[i],
          now: start.add(Duration(hours: 20 * i, minutes: i)),
          elapsed: Duration(milliseconds: 1500 + i),
          answerGiven: pairs[i % 3].$3 == DrillMode.production ? 'kitna' : null,
        ),
    ];
  }

  test('recording appends the review and stores the new state', () async {
    final event = await log.record(
      deckId: 'hi-en-market',
      cardId: 'hi-en-market-0001',
      mode: DrillMode.production,
      grade: 4,
      now: start,
      answerGiven: 'kitna',
    );
    expect(event.before, isNull);
    expect(
      fields(event.after),
      fields(Sm2.next(Sm2State.fresh(start), 4, now: start)),
    );

    final rows = await db.reviewsDao.all();
    expect(rows.single.intervalAfter, event.after.intervalDays);
    expect(rows.single.answerGiven, 'kitna');
    final stored = await states.stateOf(
      'hi-en-market',
      'hi-en-market-0001',
      DrillMode.production,
    );
    expect(fields(stored!), fields(event.after));

    final second = await log.record(
      deckId: 'hi-en-market',
      cardId: 'hi-en-market-0001',
      mode: DrillMode.production,
      grade: 5,
      now: start.add(const Duration(days: 1)),
    );
    expect(fields(second.before!), fields(event.after), reason: 'read back');
    expect((await db.reviewsDao.all()).last.intervalBefore, 1);
  });

  test(
    'both, or neither: a failed state write takes the review with it',
    () async {
      await db.customStatement(
        'CREATE TRIGGER fail_state BEFORE INSERT ON card_states '
        "BEGIN SELECT RAISE(ABORT, 'state write failed'); END",
      );
      await expectLater(
        log.record(
          deckId: 'hi-en-market',
          cardId: 'hi-en-market-0001',
          mode: DrillMode.recognition,
          grade: 4,
          now: start,
        ),
        throwsA(anything),
      );
      expect(await db.reviewsDao.all(), isEmpty);
      expect(await states.all(), isEmpty);
    },
  );

  test('a grade outside 0 to 5 writes nothing', () async {
    await expectLater(
      log.record(
        deckId: 'hi-en-market',
        cardId: 'hi-en-market-0001',
        mode: DrillMode.recognition,
        grade: 6,
        now: start,
      ),
      throwsArgumentError,
    );
    expect(await db.reviewsDao.all(), isEmpty);
  });

  test('20 reviews, rebuilt from the log, give the same states', () async {
    await recordTwenty();
    final recorded = byValue(await states.all());
    expect(recorded, hasLength(3));

    // Wreck the cache: drop one pair, corrupt another.
    await db.cardStatesDao.clear();
    await db.cardStatesDao.put(
      Sm2State.fresh(start).toRow((
        deckId: 'hi-en-market',
        cardId: 'hi-en-market-0001',
        mode: DrillMode.recognition,
      )),
    );

    await log.rebuildStates();
    expect(byValue(await states.all()), recorded);
  });

  test('the log alone replays to the events that were recorded', () async {
    final recorded = await recordTwenty();
    final replayed = await log.events();
    expect(replayed, hasLength(20));
    for (var i = 0; i < 20; i++) {
      final (a, b) = (recorded[i], replayed[i]);
      expect(b.key, a.key);
      expect(
        (b.at, b.grade, b.elapsed, b.answerGiven),
        (a.at, a.grade, a.elapsed, a.answerGiven),
      );
      expect(
        b.before == null ? null : fields(b.before!),
        a.before == null ? null : fields(a.before!),
      );
      expect(fields(b.after), fields(a.after));
    }
  });

  test('the database and the in-memory store agree', () async {
    final recorded = await recordTwenty();
    final memory = MemoryProgress.replaying(recorded);
    expect(byValue(await states.all()), byValue(memory.states));
  });
}
