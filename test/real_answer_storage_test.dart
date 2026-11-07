// A real answer is never stored in the shape of placement credit
// (`realElapsed`): through the REAL stores (the database and its review log,
// the JSONL backup and the replay snapshot), not only in memory. Elapsed time
// is stored in whole milliseconds, so the distinguisher is one millisecond:
// a self-graded flip (grade 5, no time, no answer) keeps 1 ms and credit
// keeps 0 ms, after a reload, a backup and a snapshot. Placed, the level and
// the FSRS skip read the reloaded rows the same way.

import 'package:drift/native.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/data/replay_snapshot.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/review_event.dart';
import 'package:fluenough/core/progress/mastery.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/placement_withdrawal.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _at = DateTime.utc(2026, 9, 1, 9);

void main() {
  late AppDatabase db;
  late ReviewLog log;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    log = ReviewLog(db);
  });
  tearDown(() => db.close());

  /// A real self-graded flip, written the way the app writes it, and
  /// placement credit, written the way `creditPlacement` writes it.
  Future<void> writeBoth() async {
    await log.record(
      deckId: 'xx-en-a',
      cardId: 'xx-real',
      mode: DrillMode.recognition,
      grade: 5,
      now: _at,
      elapsed: realElapsed(grade: 5, elapsed: Duration.zero),
    );
    await log.record(
      deckId: 'xx-en-a',
      cardId: 'xx-credit',
      mode: DrillMode.recognition,
      grade: 5,
      now: _at,
      asked: Ask.own,
    );
  }

  LoggedReview byCard(List<LoggedReview> rows, String card) =>
      rows.firstWhere((r) => r.key.cardId == card);

  group('through the database and its review log', () {
    test('a real flip reloads with 1 ms and is not credit; credit reloads '
        'with 0 ms and is', () async {
      await writeBoth();
      // A fresh log over the same database: what is read back is what is
      // stored, not what was written in memory.
      final rows = await ReviewLog(db).reviews();
      final real = byCard(rows, 'xx-real');
      final credit = byCard(rows, 'xx-credit');
      expect(real.elapsed, kRealAnswerMinimum);
      expect(credit.elapsed, Duration.zero);
      expect(hasCreditShape(real), isFalse);
      expect(hasCreditShape(credit), isTrue);
    });

    test(
      'after a reload Progress counts the flip as earned and the credit as '
      'placed, and the level is placed only while nothing is earned',
      () async {
        await writeBoth();
        final events = await ReviewLog(db).events();
        final real = events.firstWhere((e) => e.cardId == 'xx-real');
        final credit = events.firstWhere((e) => e.cardId == 'xx-credit');
        expect(real.isPlaced, isFalse);
        expect(credit.isPlaced, isTrue);
        final star = masteryAt(
          events,
          const <ReviewEvent>[],
          totals: const <MasterySkill, int>{MasterySkill.read: 10},
          scriptCards: const <String>{},
        )[MasterySkill.read];
        expect(star.placed, 1);
        expect(star.taught, 1);
        const path = CoursePath(
          id: 'xx-path',
          language: 'xx',
          native: 'en',
          units: <List<String>>[
            <String>['xx-en-a'],
          ],
          plan: <PlanUnit>[
            PlanUnit(decks: <String>['xx-en-a'], milestone: Milestone.a1),
          ],
        );
        expect(levelPlaced(path, Milestone.a1, events), isFalse);
        expect(levelPlaced(path, Milestone.a1, <ReviewEvent>[credit]), isTrue);
      },
    );

    test('rows already stored with 0 ms cannot be told from credit, and are '
        'not reinterpreted', () async {
      // Before realElapsed a real self-graded flip was stored as 0 ms.
      await log.record(
        deckId: 'xx-en-a',
        cardId: 'xx-old',
        mode: DrillMode.recognition,
        grade: 5,
        now: _at,
      );
      final old = byCard(await ReviewLog(db).reviews(), 'xx-old');
      expect(old.elapsed, Duration.zero);
      expect(hasCreditShape(old), isTrue, reason: 'nothing marks it real');
    });
  });

  group('through the backup and the snapshot', () {
    test('the JSONL backup round trip keeps the distinction', () async {
      await writeBoth();
      final rows = await log.reviews();
      final text = LogJsonl.encode(rows, const []);
      final back = LogJsonl.decode(text).reviews;
      expect(hasCreditShape(byCard(back, 'xx-real')), isFalse);
      expect(hasCreditShape(byCard(back, 'xx-credit')), isTrue);
      expect(byCard(back, 'xx-real').elapsed, kRealAnswerMinimum);
    });

    test('the replay snapshot round trip keeps the distinction', () async {
      await writeBoth();
      final replayed = replayReviews(await log.reviews());
      final bytes = encodeSnapshot(memory: replayed, cacheStates: const {});
      final events = decodeSnapshot(bytes).memory.events;
      expect(events.firstWhere((e) => e.cardId == 'xx-real').isPlaced, isFalse);
      expect(
        events.firstWhere((e) => e.cardId == 'xx-credit').isPlaced,
        isTrue,
      );
    });
  });
}
