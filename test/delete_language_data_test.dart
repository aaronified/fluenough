// Delete a language's data from its sheet (#861): the Delete button waits for
// the language's name; the reviews of one language go and no other's; a range
// of days is inclusive by the local day; placement's credit is not a review;
// the placement can be deleted so the course asks again; states and progress
// are what a fresh replay of the remaining log gives; a backup is kept first
// and restores; the log's guards are back afterwards.

import 'package:drift/native.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/backup_files.dart';
import 'package:fluenough/app/backup_store.dart';
import 'package:fluenough/app/backups.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/language_data_deletion.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/review_erasure.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/placed_review.dart';
import 'package:fluenough/features/languages/delete_language_data_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

final DateTime _now = DateTime(2026, 11, 7, 12);

DateTime _at(int day, [int hour = 10, int minute = 0, int second = 0]) =>
    DateTime(2026, 11, day, hour, minute, second);

void _answer(
  ProgressStore progress,
  String language,
  int n,
  DateTime at, {
  int grade = 4,
}) => progress.record(
  deckId: '$language-en-words',
  cardId: '$language-${1000 + n}',
  mode: DrillMode.recognition,
  grade: grade,
  now: at,
);

Future<({AppDatabase db, DatabaseProgress progress})> _open() async {
  final db = AppDatabase(NativeDatabase.memory());
  final progress = await DatabaseProgress.open(db);
  addTearDown(progress.dispose);
  addTearDown(progress.close);
  return (db: db, progress: progress);
}

Map<String, (double, double, int, int)> _byValue(ProgressStore p) => {
  for (final e in p.states.entries)
    '${e.key.cardId}|${e.key.mode.name}': (
      e.value.stability,
      e.value.difficulty,
      e.value.repetitions,
      e.value.intervalDays,
    ),
};

Future<List<String>> _cards(AppDatabase db) async => <String>[
  for (final r in await db.reviewsDao.all()) r.cardId,
];

void main() {
  group('the database', () {
    test('deleting one language removes its reviews and states, and no other '
        "language's; the log's guards are back", () async {
      final (:db, :progress) = await _open();
      for (var i = 0; i < 3; i++) {
        _answer(progress, 'te', i, _at(1 + i));
        _answer(progress, 'hi', i, _at(1 + i));
      }
      await progress.flush();
      final hiBefore = _byValue(progress)
        ..removeWhere((k, _) => k.startsWith('te-'));

      final removed = await progress.eraseReviews(
        const ReviewErasure(language: 'te', answers: true),
      );

      expect(removed, 3);
      expect(await _cards(db), everyElement(startsWith('hi-')));
      expect((await _cards(db)).length, 3);
      expect(await db.cardStatesDao.all(), hasLength(3));
      expect(
        (await db.cardStatesDao.all()).map((s) => s.cardId),
        everyElement(startsWith('hi-')),
      );
      expect(_byValue(progress), hiBefore);
      expect(progress.log.every((e) => e.cardId.startsWith('hi-')), isTrue);
      // Still append-only for everything else.
      await expectLater(
        db.customStatement('DELETE FROM reviews'),
        throwsA(anything),
      );
      await expectLater(
        db.customStatement("UPDATE reviews SET grade = 1"),
        throwsA(anything),
      );
    });

    test('a prefix of another code is not the language: only te- cards go', () async {
      final (:db, :progress) = await _open();
      _answer(progress, 'te', 1, _at(1));
      _answer(progress, 'tel', 1, _at(1));
      _answer(progress, 'tet', 1, _at(1));
      await progress.flush();
      await progress.eraseReviews(
        const ReviewErasure(language: 'te', answers: true),
      );
      expect(await _cards(db), unorderedEquals(<String>['tel-1001', 'tet-1001']));
    });

    test('a range of days is inclusive on both ends, by the local day', () async {
      final (:db, :progress) = await _open();
      _answer(progress, 'te', 1, _at(1, 0, 0, 0)); // first moment of day 1
      _answer(progress, 'te', 2, _at(2, 23, 59, 59)); // last moment of day 2
      _answer(progress, 'te', 3, _at(3, 0, 0, 0)); // first moment of day 3
      _answer(progress, 'te', 4, DateTime(2026, 10, 20, 12));
      await progress.flush();

      final removed = await progress.eraseReviews(
        ReviewErasure(
          language: 'te',
          answers: true,
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 2),
        ),
      );

      expect(removed, 2);
      expect(
        await _cards(db),
        unorderedEquals(<String>['te-1003', 'te-1004']),
      );
    });

    test('placement is not a review: deleting reviews leaves its credit, '
        'deleting placement takes only it', () async {
      for (final (answers, placement, left) in <(bool, bool, List<String>)>[
        (true, false, <String>['te-1001']),
        (false, true, <String>['te-2000']),
      ]) {
        final (:db, :progress) = await _open();
        final placed = _at(5, 9);
        _answer(progress, 'te', 1, _at(5, 9, 0, 0).add(const Duration(milliseconds: 300)),
            grade: 5);
        _answer(progress, 'te', 2000 - 1000, _at(6));
        await progress.flush();
        final erased = await progress.eraseReviews(
          ReviewErasure(
            language: 'te',
            answers: answers,
            placement: placement,
            placedAtSeconds: <int>{placed.millisecondsSinceEpoch ~/ 1000},
          ),
        );
        expect(erased, 1);
        expect(await _cards(db), left);
      }
    });

    test('fits of the language go with its reviews; other languages keep theirs, '
        'and states match a fresh replay of what is left', () async {
      final (:db, :progress) = await _open();
      for (var i = 0; i < 4; i++) {
        _answer(progress, 'te', i, _at(1 + i), grade: i.isEven ? 4 : 2);
        _answer(progress, 'hi', i, _at(1 + i), grade: 3);
      }
      final fit = FittedParameters(
        values: <double>[for (final w in Fsrs.w) w * 1.01],
        fittedAt: _at(5),
        reviewCount: 4,
        lossBefore: 0.7,
        lossAfter: 0.6,
      );
      await progress.putFitted((language: 'te', mode: DrillMode.recognition), fit);
      await progress.putFitted((language: 'hi', mode: DrillMode.recognition), fit);
      await progress.flush();

      await progress.eraseReviews(
        ReviewErasure(
          language: 'te',
          answers: true,
          from: _at(3),
          to: _at(4),
        ),
      );

      final fits = await db.fsrsParametersDao.all();
      expect(fits.map((f) => f.language), <String>['hi']);
      // A fresh app on the same database reads the same progress as memory.
      final again = await DatabaseProgress.open(db);
      addTearDown(again.dispose);
      expect(_byValue(again), _byValue(progress));
      expect(again.log.length, progress.log.length);
      // And the cache table agrees with it.
      expect(
        {
          for (final s in await db.cardStatesDao.all())
            '${s.cardId}|${s.mode.name}': s.repetitions,
        },
        {
          for (final e in progress.states.entries)
            '${e.key.cardId}|${e.key.mode.name}': e.value.repetitions,
        },
      );
    });

    test('memory progress deletes the same way', () async {
      final progress = MemoryProgress();
      _answer(progress, 'te', 1, _at(1));
      _answer(progress, 'hi', 1, _at(1));
      final removed = await progress.eraseReviews(
        const ReviewErasure(language: 'te', answers: true),
      );
      expect(removed, 1);
      expect(progress.log.map((e) => e.cardId), <String>['hi-1001']);
      expect(progress.states.keys.map((k) => k.cardId), <String>['hi-1001']);
    });
  });

  group('deleting from the app', () {
    ({AppState state, MemoryBackupStore store, FixedBackupFiles files}) app(
      ProgressStore progress,
    ) {
      final files = FixedBackupFiles();
      final store = MemoryBackupStore();
      final state = AppState.test(
        progress: progress,
        backupFiles: files,
        backupStore: store,
        now: _now,
      );
      addTearDown(state.dispose);
      return (state: state, store: store, files: files);
    }

    test('a backup is kept first, holds what was deleted, and restores it',
        () async {
      final (:db, :progress) = await _open();
      _answer(progress, 'te', 1, _at(1));
      _answer(progress, 'hi', 1, _at(1));
      await progress.flush();
      final (:state, :store, :files) = app(progress);
      final before = progress.exportJsonl();

      final removed = await state.deleteLanguageData(
        'te',
        const LanguageDataChoice(reviews: true),
      );

      expect(removed, 1);
      final kept = await store.list();
      expect(kept.map((b) => b.kind), <BackupKind>[BackupKind.delete]);
      final backup = await state.backups.read(kept.single);
      expect(backup.log, before);
      expect(progress.log.map((e) => e.cardId), <String>['hi-1001']);

      await state.backups.restore(backup, fromFile: false);
      expect(progress.log.map((e) => e.cardId), unorderedEquals(<String>['te-1001', 'hi-1001']));
      expect(await _cards(db), hasLength(2));
    });

    test('nothing is deleted when the backup cannot be kept', () async {
      final progress = MemoryProgress();
      _answer(progress, 'te', 1, _at(1));
      final state = AppState.test(
        progress: progress,
        backupStore: _FailingStore(),
        now: _now,
      );
      addTearDown(state.dispose);
      await expectLater(
        state.deleteLanguageData('te', const LanguageDataChoice(reviews: true)),
        throwsA(anything),
      );
      expect(progress.log, hasLength(1));
    });

    test('deleting the placement makes the course ask again, for that language '
        'only; other languages and their settings stay', () async {
      final progress = MemoryProgress();
      final (:state, :store, :files) = app(progress);
      final settings = state.settings;
      for (final code in <String>['te', 'hi']) {
        settings.addPlacedAt(code, 1700000000);
        settings.setSkillLabels(code, <String, String>{'read': 'sure'});
        settings.setVerifiedSkills(code, <String>{'read'});
        settings.setPlacementRun(code, '{}');
        settings.setDailyMinutes(code, 30);
        settings.setPlacedReview(code, PlacedReview.keepReviewing);
      }
      settings.placedDecks = <String>{'te-en-words', 'hi-en-words'};

      await state.deleteLanguageData(
        'te',
        const LanguageDataChoice(placement: true),
      );

      expect(settings.placedAtOf('te'), isEmpty);
      expect(settings.skillLabelsOf('te'), isEmpty);
      expect(settings.verifiedSkillsOf('te'), isEmpty);
      expect(settings.placementRunOf('te'), isNull);
      expect(settings.placedDecks, <String>{'hi-en-words'});
      expect(settings.dailyMinutesFor('te'), 30, reason: 'settings not ticked');
      expect(settings.placedAtOf('hi'), isNotEmpty);
      expect(settings.dailyMinutesFor('hi'), 30);

      await state.deleteLanguageData(
        'te',
        const LanguageDataChoice(settings: true),
      );
      expect(settings.dailyMinutesFor('te'), isNot(30));
      expect(settings.dailyMinutesFor('hi'), 30);
    });

    test('study time of the deleted days goes, other days and languages stay',
        () async {
      final progress = MemoryProgress();
      final (:state, :store, :files) = app(progress);
      final settings = state.settings;
      for (final code in <String>['te', 'hi']) {
        settings.addTeachTime(code, _at(1), const Duration(minutes: 1));
        settings.addTeachTime(code, _at(5), const Duration(minutes: 1));
      }
      await state.deleteLanguageData(
        'te',
        LanguageDataChoice(reviews: true, from: _at(1), to: _at(2)),
      );
      expect(settings.teachTimeOn(_at(1), language: 'te'), Duration.zero);
      expect(settings.teachTimeOn(_at(5), language: 'te'), isNot(Duration.zero));
      expect(settings.teachTimeOn(_at(1), language: 'hi'), isNot(Duration.zero));
    });
  });

  group('the dialog', () {
    Future<void> open(WidgetTester tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        Scaffold(
          body: DeleteLanguageDataDialog(name: 'Telugu', today: _now),
        ),
      );
    }

    bool enabled(WidgetTester tester) =>
        tester
            .widget<TextButton>(find.byKey(const ValueKey<String>('delete-confirm')))
            .onPressed !=
        null;

    testWidgets('Delete stays disabled until the name is typed exactly and '
        'something is ticked', (tester) async {
      await open(tester);
      expect(enabled(tester), isFalse);

      await tapKey(tester, 'delete-reviews');
      await tester.pump();
      expect(enabled(tester), isFalse, reason: 'no name yet');

      for (final wrong in <String>['telugu', 'Telug', 'Telugu ', 'Hindustani']) {
        await tester.enterText(
          find.byKey(const ValueKey<String>('delete-name')),
          wrong,
        );
        await tester.pump();
        expect(enabled(tester), isFalse, reason: wrong);
      }
      await tester.enterText(
        find.byKey(const ValueKey<String>('delete-name')),
        'Telugu',
      );
      await tester.pump();
      expect(enabled(tester), isTrue);

      await tapKey(tester, 'delete-reviews');
      await tester.pump();
      expect(enabled(tester), isFalse, reason: 'nothing ticked');
    });

    testWidgets('a range with the first day after the last says so and '
        'cannot be deleted', (tester) async {
      await open(tester);
      await tapKey(tester, 'delete-reviews');
      await tester.pump();
      await tapKey(tester, 'delete-some-dates');
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('delete-from')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('delete-to')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('delete-name')),
        'Telugu',
      );
      await tester.pump();
      expect(enabled(tester), isTrue, reason: 'today to today');
    });
  });
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

class _FailingStore extends MemoryBackupStore {
  @override
  Future<StoredBackup> add(AppBackup backup) =>
      throw StateError('storage full');
}
