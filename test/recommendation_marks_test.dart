// Completed marks for recommended works (wiki Plan-Deck-Kinds-And-Topics.md,
// D13, T25): a learner marks a work completed, and that is learner state in
// the progress database (schema 12) and the backups, never in a deck. Its
// questions are asked only while the mark is there. Moving from schema 11
// only adds the table; the review log is not touched.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:fluenough/app/recommendation_progress.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/data/recommendations.dart';
import 'package:fluenough/core/models/completed_work.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kinds_fixture.dart';

final DateTime _at = DateTime(2026, 11, 12, 9, 30, 15, 250);

CompletedWork _work(String id, {String language = 'zz', DateTime? at}) =>
    CompletedWork(
      recommendationId: id,
      language: language,
      completedAt: at ?? _at,
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('the table', () {
    test(
      'keeps a mark with its language and date, and un-marking removes it',
      () async {
        await db.recommendationMarksDao.mark(_work('zz-rec-uno'));
        await db.recommendationMarksDao.mark(
          _work(
            'te-rec-dos',
            language: 'te',
            at: _at.add(const Duration(days: 1)),
          ),
        );
        final all = await db.recommendationMarksDao.all();
        expect(all.map((w) => w.recommendationId), <String>[
          'zz-rec-uno',
          'te-rec-dos',
        ]);
        expect(all.first.completedAt, _at);
        expect(
          (await db.recommendationMarksDao.forLanguage('te'))
              .single
              .recommendationId,
          'te-rec-dos',
        );
        expect(await db.recommendationMarksDao.unmark('zz-rec-uno'), isTrue);
        expect(await db.recommendationMarksDao.unmark('zz-rec-uno'), isFalse);
        expect(await db.recommendationMarksDao.all(), hasLength(1));
      },
    );

    test('marking again keeps the first date', () async {
      await db.recommendationMarksDao.mark(_work('zz-rec-uno'));
      await db.recommendationMarksDao.mark(
        _work('zz-rec-uno', at: _at.add(const Duration(days: 5))),
      );
      expect((await db.recommendationMarksDao.all()).single.completedAt, _at);
    });

    test('merging a backup adds only what is missing', () async {
      await db.recommendationMarksDao.mark(_work('zz-rec-uno'));
      final added = await db.recommendationMarksDao.addMissing(<CompletedWork>[
        _work('zz-rec-uno', at: _at.add(const Duration(days: 9))),
        _work('zz-rec-dos'),
      ]);
      expect(added, 1);
      final all = await db.recommendationMarksDao.all();
      expect(all, hasLength(2));
      expect(
        all.firstWhere((w) => w.recommendationId == 'zz-rec-uno').completedAt,
        _at,
      );
    });
  });

  group('moving from schema 11', () {
    test('adds the table and leaves the review log alone', () async {
      expect(AppDatabase.currentSchemaVersion, 12);
      final dir = Directory.systemTemp.createTempSync('fluenough');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/eleven.sqlite');

      final old = AppDatabase(NativeDatabase(file));
      await old.reviewsDao.append(
        ReviewsCompanion.insert(
          ts: _at,
          deckId: 'zz-en-words',
          cardId: 'zz-9001',
          mode: DrillMode.production,
          grade: 4,
          elapsedMs: 3000,
          intervalAfter: 6,
        ),
      );
      await old.customStatement('DROP TABLE recommendation_marks');
      await old.customStatement('PRAGMA user_version = 11');
      await old.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      expect(await upgraded.reviewsDao.all(), hasLength(1));
      expect(await upgraded.recommendationMarksDao.all(), isEmpty);
      await upgraded.recommendationMarksDao.mark(_work('zz-rec-uno'));
      expect(await upgraded.recommendationMarksDao.all(), hasLength(1));
      // The review log is still append-only.
      await expectLater(
        upgraded.customStatement('DELETE FROM reviews'),
        throwsA(anything),
      );
    });

    test(
      'a step cut off after the table runs again and keeps its marks',
      () async {
        final dir = Directory.systemTemp.createTempSync('fluenough');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/cut.sqlite');

        final first = AppDatabase(NativeDatabase(file));
        await first.recommendationMarksDao.mark(_work('zz-rec-uno'));
        await first.customStatement('PRAGMA user_version = 11');
        await first.close();

        final again = AppDatabase(NativeDatabase(file));
        addTearDown(again.close);
        expect(await again.recommendationMarksDao.all(), hasLength(1));
      },
    );
  });

  group('the backup', () {
    test(
      'carries the marks in the log, and an older reader still reads the log',
      () {
        final text = LogJsonl.encode(
          const [],
          const [],
          completedWorks: <CompletedWork>[
            _work('zz-rec-dos', at: _at.add(const Duration(days: 1))),
            _work('zz-rec-uno'),
          ],
        );
        final back = LogJsonl.decodeCompletedWorks(text);
        expect(back.map((w) => w.recommendationId), <String>[
          'zz-rec-uno',
          'zz-rec-dos',
        ]);
        expect(back.first.language, 'zz');
        expect(back.first.completedAt, _at);
        // Reviews, leech actions and the rest read as before, the new lines
        // skipped like any line of a type the reader does not know.
        final decoded = LogJsonl.decode(text);
        expect(decoded.reviews, isEmpty);
        expect(decoded.withdrawals, isEmpty);
      },
    );

    test(
      'skips a mark that does not read, and keeps the earliest of a work',
      () {
        final back = LogJsonl.decodeCompletedWorks(
          '{"format":"fluenough-review-log","version":1}\n'
          '{"type":"completed","recommendation":"zz-rec-uno","language":"zz","at":"2026-11-12T09:00:00Z"}\n'
          '{"type":"completed","recommendation":"zz-rec-uno","language":"zz","at":"2026-11-10T09:00:00Z"}\n'
          '{"type":"completed","recommendation":"","language":"zz","at":"2026-11-10T09:00:00Z"}\n'
          '{"type":"completed","recommendation":"zz-rec-dos","language":"zz","at":"yesterday"}\n'
          'not json "completed"\n',
        );
        expect(back, hasLength(1));
        expect(back.single.completedAt.toUtc(), DateTime.utc(2026, 11, 10, 9));
      },
    );
  });

  group('the learner\'s completed works', () {
    final book = parseRecommendations(
      kindsFixtureFiles()['decks/recommendations/zz.yaml']!,
      source: 'zz.yaml',
    ).byId('zz-rec-cartas-de-prueba')!;

    test(
      'open the questions while marked, and stop them when un-marked',
      () async {
        final progress = RecommendationProgress(
          MemoryRecommendationMarkStore(),
        );
        addTearDown(progress.dispose);
        await progress.load();
        expect(progress.questionsOf(book), isEmpty);
        progress.complete(book, 'zz', _at);
        expect(progress.isCompleted(book.id), isTrue);
        expect(progress.questionsOf(book), hasLength(3));
        progress.unmark(book.id);
        expect(progress.questionsOf(book), isEmpty);
        expect(progress.completed, isEmpty);
      },
    );

    test('are kept in the database and come back on the next launch', () async {
      final first = RecommendationProgress(
        DatabaseRecommendationMarkStore(db.recommendationMarksDao),
      );
      addTearDown(first.dispose);
      first.complete(book, 'zz', _at);
      await first.settled;

      final second = RecommendationProgress(
        DatabaseRecommendationMarkStore(db.recommendationMarksDao),
      );
      addTearDown(second.dispose);
      await second.load();
      expect(second.completedIds, <String>{book.id});
      expect(second.completed.single.completedAt, _at);
      second.unmark(book.id);
      await second.settled;
      expect(await db.recommendationMarksDao.all(), isEmpty);
    });

    test('merge in from a backup without changing what is marked', () async {
      final progress = RecommendationProgress(MemoryRecommendationMarkStore());
      addTearDown(progress.dispose);
      progress.complete(book, 'zz', _at);
      final added = await progress.importMarks(<CompletedWork>[
        _work(book.id, at: _at.add(const Duration(days: 3))),
        _work('zz-rec-dos'),
      ]);
      expect(added, 1);
      expect(progress.completedIds, <String>{book.id, 'zz-rec-dos'});
      expect(progress.completed.first.completedAt, _at);
    });
  });
}
