// Repairing placements an earlier version wrote (wiki/Plan-Placement-V2.md,
// point 17): migration 11 and its append-only table, the database progress
// with a withdrawal (states, export, restore, snapshot), and the owner's own
// profile end to end in the app layer.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/placement_recheck.dart';
import 'package:fluenough/app/placement_run_setup.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/data/replay_isolate.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/placement/placement_check.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/placement_withdrawal.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/v3_write.dart';

/// The credit's moment: a whole second with 250 ms in it.
final DateTime _t = DateTime.utc(2026, 11, 7, 12, 0, 0, 250);

const String _app = 'test-app';

PlacementWithdrawal _withdrawal({
  Set<String> decks = const <String>{'es-en-b', 'es-en-c'},
  String language = 'es',
}) => PlacementWithdrawal(
  at: _t.add(const Duration(days: 3)),
  language: language,
  creditAt: momentOf(_t),
  modes: const <DrillMode>{DrillMode.recognition},
  script: null,
  deckIds: decks,
);

RestoreRecord _restore() => RestoreRecord(
  at: _t.add(const Duration(days: 9)),
  backupCreatedAt: _t,
  backupKind: 'you',
  backupAppVersion: '0.9.2',
  fromFile: true,
  keptCopy: 'kept',
);

/// A log as 0.9.0 left it: credit on decks A, B and C, a real review of a B
/// card two days later, and a real review of a D card.
Future<AppDatabase> _creditedDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  final log = ReviewLog(db);
  for (final (deck, card) in <(String, String)>[
    ('es-en-a', 'es-0001'),
    ('es-en-b', 'es-0002'),
    ('es-en-c', 'es-0003'),
  ]) {
    await log.record(
      deckId: deck,
      cardId: card,
      mode: DrillMode.recognition,
      grade: 5,
      now: _t,
      asked: Ask.own,
    );
  }
  await log.record(
    deckId: 'es-en-b',
    cardId: 'es-0002',
    mode: DrillMode.recognition,
    grade: 4,
    now: _t.add(const Duration(days: 2)),
    elapsed: const Duration(seconds: 4),
    asked: Ask.own,
  );
  await log.record(
    deckId: 'es-en-d',
    cardId: 'es-0004',
    mode: DrillMode.recognition,
    grade: 3,
    now: _t.add(const Duration(days: 2, hours: 1)),
    elapsed: const Duration(seconds: 4),
    asked: Ask.own,
  );
  return db;
}

Future<int> _count(AppDatabase db, String sql) async =>
    (await db.customSelect(sql).getSingle()).read<int>('n');

void main() {
  group('migration 11', () {
    test('a new database has the table, and it is append-only', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.placementWithdrawalsDao.append(_withdrawal());
      final back = await db.placementWithdrawalsDao.all();
      expect(back, hasLength(1));
      expect(
        withdrawalIdentity(back.single),
        withdrawalIdentity(_withdrawal()),
      );
      for (final sql in <String>[
        "UPDATE placement_withdrawals SET language = 'hi'",
        'DELETE FROM placement_withdrawals',
      ]) {
        await expectLater(db.customStatement(sql), throwsA(anything));
      }
      expect(await db.placementWithdrawalsDao.all(), hasLength(1));
    });

    test('a version 10 database gains the table and keeps its reviews, and '
        'running the step again leaves one table with its triggers', () async {
      final dir = Directory.systemTemp.createTempSync('fluenough');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/ten.sqlite');

      final old = AppDatabase(NativeDatabase(file));
      await ReviewLog(old).record(
        deckId: 'es-en-a',
        cardId: 'es-0001',
        mode: DrillMode.recognition,
        grade: 4,
        now: _t,
      );
      await old.customStatement('DROP TABLE placement_withdrawals');
      await old.customStatement('PRAGMA user_version = 10');
      await old.close();

      Future<void> check(AppDatabase db) async {
        expect(await db.reviewsDao.all(), hasLength(1));
        expect(
          await _count(
            db,
            "SELECT COUNT(*) AS n FROM sqlite_master WHERE type = 'table' "
            "AND name = 'placement_withdrawals'",
          ),
          1,
        );
        expect(
          await _count(
            db,
            "SELECT COUNT(*) AS n FROM sqlite_master WHERE type = 'trigger' "
            "AND tbl_name = 'placement_withdrawals'",
          ),
          2,
        );
        await expectLater(
          db.customStatement('DELETE FROM reviews'),
          throwsA(anything),
          reason: 'the reviews triggers are untouched',
        );
      }

      final upgraded = AppDatabase(NativeDatabase(file));
      await upgraded.placementWithdrawalsDao.append(_withdrawal());
      await check(upgraded);
      // Cut off part-way: the step runs again on a database that has it.
      await upgraded.customStatement('PRAGMA user_version = 10');
      await upgraded.close();

      final again = AppDatabase(NativeDatabase(file));
      addTearDown(again.close);
      await check(again);
      expect(await again.placementWithdrawalsDao.all(), hasLength(1));
      expect(AppDatabase.currentSchemaVersion, 12);
    });

    test(
      'a step cut off after the table gives the table its triggers',
      () async {
        final dir = Directory.systemTemp.createTempSync('fluenough');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/half.sqlite');

        final old = AppDatabase(NativeDatabase(file));
        await old.customStatement(
          'DROP TRIGGER placement_withdrawals_no_update',
        );
        await old.customStatement(
          'DROP TRIGGER placement_withdrawals_no_delete',
        );
        await old.customStatement('PRAGMA user_version = 10');
        await old.close();

        final upgraded = AppDatabase(NativeDatabase(file));
        addTearDown(upgraded.close);
        await upgraded.placementWithdrawalsDao.append(_withdrawal());
        await expectLater(
          upgraded.customStatement('DELETE FROM placement_withdrawals'),
          throwsA(anything),
        );
        await expectLater(
          upgraded.customStatement(
            "UPDATE placement_withdrawals SET language = 'hi'",
          ),
          throwsA(anything),
        );
      },
    );
  });

  group('a withdrawal in the database progress', () {
    Future<DatabaseProgress> open(
      AppDatabase db, {
      void Function(String)? on,
    }) => DatabaseProgress.open(
      db,
      app: _app,
      replayer: replayInPlace,
      snapshotter: snapshotInPlace,
      onStage: on,
    );

    test('removes only that credit from every state, keeps every review in '
        'the database and the export, and survives a reopen', () async {
      final db = await _creditedDb();
      addTearDown(db.close);
      final progress = await open(db);
      addTearDown(progress.dispose);
      expect(progress.stateOf('es-0003', DrillMode.recognition), isNotNull);

      progress.withdrawCredit(_withdrawal());
      await progress.flush();

      // Gone, as if never placed.
      expect(progress.stateOf('es-0003', DrillMode.recognition), isNull);
      // A real review is the first review now.
      final real = progress.stateOf('es-0002', DrillMode.recognition)!;
      expect(real.repetitions, 1);
      // Credit that was not withdrawn stays.
      expect(progress.stateOf('es-0001', DrillMode.recognition), isNotNull);
      expect(progress.stateOf('es-0004', DrillMode.recognition), isNotNull);
      // `card_states` follows.
      final cached = <String>{
        for (final row in await db.cardStatesDao.all()) row.cardId,
      };
      expect(cached, <String>{'es-0001', 'es-0002', 'es-0004'});
      // Nothing is deleted.
      expect(await db.reviewsDao.all(), hasLength(5));
      final exported = LogJsonl.decode(progress.exportJsonl());
      expect(exported.reviews, hasLength(5));
      expect(exported.withdrawals, hasLength(1));

      final reopened = await open(db);
      addTearDown(reopened.dispose);
      expect(reopened.stateOf('es-0003', DrillMode.recognition), isNull);
      expect(reopened.withdrawals, hasLength(1));
      expect(reopened.withdrawnReviews, hasLength(2));
      expect(LogJsonl.decode(reopened.exportJsonl()).reviews, hasLength(5));
    });

    test('a snapshot made before a withdrawal is not used after it, and one '
        'made after it is', () async {
      final db = await _creditedDb();
      addTearDown(db.close);
      final first = await open(db);
      addTearDown(first.dispose);
      expect(await first.saveSnapshot(), isTrue);
      final log = ReviewLog(db);
      final before = await log.currentStamp(app: _app);

      await log.withdraw(_withdrawal());
      expect((await log.currentStamp(app: _app)).text, isNot(before.text));

      final stages = <String>[];
      final second = await open(db, on: stages.add);
      addTearDown(second.dispose);
      expect(stages.first, 'review log replayed');
      expect(second.stateOf('es-0003', DrillMode.recognition), isNull);
      await second.flush();

      final againStages = <String>[];
      final third = await open(db, on: againStages.add);
      addTearDown(third.dispose);
      expect(againStages.first, 'snapshot loaded');
      expect(third.stateOf('es-0003', DrillMode.recognition), isNull);
      expect(third.stateOf('es-0002', DrillMode.recognition)!.repetitions, 1);
    });

    test(
      'a restore empties the withdrawals and writes the backup\'s',
      () async {
        final db = await _creditedDb();
        addTearDown(db.close);
        final progress = await open(db);
        addTearDown(progress.dispose);
        progress.withdrawCredit(_withdrawal());
        await progress.flush();

        final rows = ReviewLog(db);
        final reviews = await rows.reviews();
        // The backup has the credit, and withdrew only deck C.
        await progress.replaceAll(
          reviews,
          const [],
          withdrawals: <PlacementWithdrawal>[
            _withdrawal(decks: {'es-en-c'}),
          ],
          restore: _restore(),
        );
        final kept = await db.placementWithdrawalsDao.all();
        expect(kept, hasLength(1));
        expect(kept.single.deckIds, <String>{'es-en-c'});
        expect(progress.stateOf('es-0003', DrillMode.recognition), isNull);
        expect(progress.stateOf('es-0002', DrillMode.recognition), isNotNull);

        // A backup from 0.9.1 has none: the credit is all there again.
        await progress.replaceAll(reviews, const [], restore: _restore());
        expect(await db.placementWithdrawalsDao.all(), isEmpty);
        expect(progress.stateOf('es-0003', DrillMode.recognition), isNotNull);
        expect(await db.reviewsDao.all(), hasLength(5));
      },
    );

    test(
      'merging a backup twice adds neither reviews nor withdrawals twice',
      () async {
        final db = await _creditedDb();
        addTearDown(db.close);
        final progress = await open(db);
        addTearDown(progress.dispose);
        progress.withdrawCredit(_withdrawal());
        await progress.flush();
        final text = progress.exportJsonl();

        for (var i = 0; i < 2; i++) {
          final backup = LogJsonl.decode(text);
          final added = await progress.importLog(
            backup.reviews,
            backup.leechActions,
            withdrawals: backup.withdrawals,
          );
          expect(added, 0);
        }
        expect(await db.placementWithdrawalsDao.all(), hasLength(1));
        expect(progress.stateOf('es-0003', DrillMode.recognition), isNull);
        expect(await db.reviewsDao.all(), hasLength(5));
      },
    );
  });

  group('the owner\'s profile, end to end', () {
    late AppState state;
    late PlacementRunPlan plan;
    late int credited;

    /// The moment of 0.9.0's credit, and the clock of the app after it.
    final t1 = DateTime.utc(2026, 11, 7, 6, 0, 0, 125);

    setUp(() async {
      state = AppState.test(
        now: DateTime.utc(2026, 11, 8, 9),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        ),
      );
      await state.load();
      plan = state.placementRunPlan('es')!;
      credited = plan.decks.length < 12 ? plan.decks.length : 12;
    });
    tearDown(() => state.dispose());

    void credit090(Set<DrillMode> modes, {int decks = 0}) {
      for (final deck in plan.decks.take(decks == 0 ? credited : decks)) {
        for (final card in deck.cards) {
          for (final mode in modes) {
            if (state.progress.stateOf(card.id, mode) != null) continue;
            state.progress.record(
              deckId: deck.id,
              cardId: card.id,
              mode: mode,
              grade: 5,
              now: t1,
              asked: Ask.own,
            );
          }
        }
      }
      state.settings
        ..addPlacedAt('es', momentOf(t1))
        ..setSkillLabels('es', <String, String>{'read': 'notSureYet'})
        ..setVerifiedSkills('es', <String>{'read'})
        ..placedDecks = <String>{
          for (final deck in plan.decks.take(credited)) deck.id,
        };
    }

    FinishedV3 finished(Set<PlacementSkill> skills, bool right) =>
        FinishedV3(plan, skills, right);

    const readModes = <DrillMode>{
      DrillMode.recognition,
      DrillMode.reading,
      DrillMode.grammarUnderstood,
    };

    test('0.9.0\'s credit is unconfirmed, with Read credited up to the '
        'decks it was written for', () {
      credit090(readModes);
      expect(state.unconfirmedMomentsOf('es'), <int>{momentOf(t1)});
      final before = state.creditedLevelsOf('es', plan);
      expect(before[PlacementSkill.read], credited - 1);
      expect(before.containsKey(PlacementSkill.hear), isFalse);
    });

    test('Check again, then Use the new level, withdraws the credit and the '
        'placed decks while every real review stays', () {
      credit090(readModes);
      // A card of deck 0 reviewed for real two days later, and another of a
      // deck the placement did not reach.
      final real = plan.decks.first.cards.first;
      final unreached = plan.decks.last.cards.first;
      state.progress.record(
        deckId: plan.decks.first.id,
        cardId: real.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: t1.add(const Duration(days: 2)),
        elapsed: const Duration(seconds: 4),
        asked: Ask.own,
      );
      state.progress.record(
        deckId: plan.decks.last.id,
        cardId: unreached.id,
        mode: DrillMode.recognition,
        grade: 3,
        now: t1.add(const Duration(days: 2)),
        elapsed: const Duration(seconds: 4),
        asked: Ask.own,
      );
      final total = state.progress.log.length;

      final run = finished(<PlacementSkill>{PlacementSkill.read}, false);
      expect(run.readout[PlacementSkill.read]!.placedLevel, -1);
      run.write(state, 'es', plan, recheck: true);

      // No state for a credited, never reviewed card of the credited decks.
      for (final deck in plan.decks.take(credited)) {
        for (final card in deck.cards) {
          if (card.id == real.id) continue;
          for (final mode in readModes) {
            expect(
              state.progress.stateOf(card.id, mode),
              isNull,
              reason: '${deck.id}/${card.id} ${mode.name}',
            );
          }
        }
      }
      // A card with a real review keeps it, as its first review.
      final kept = state.progress.stateOf(real.id, DrillMode.recognition)!;
      expect(kept.repetitions, 1);
      expect(
        state.progress.log.where(
          (e) => e.cardId == real.id && e.mode == DrillMode.recognition,
        ),
        hasLength(1),
      );
      expect(
        state.progress.stateOf(unreached.id, DrillMode.recognition),
        isNotNull,
      );
      // One withdrawal: the moment, the decks credited, the three modes.
      expect(state.progress.withdrawals, hasLength(1));
      final w = state.progress.withdrawals.single;
      expect(w.language, 'es');
      expect(w.creditAt, momentOf(t1));
      expect(w.modes, readModes);
      final creditedIds = <String>{
        for (final deck in plan.decks.take(credited)) deck.id,
      };
      expect(w.deckIds, contains(plan.decks.first.id));
      expect(w.deckIds.difference(creditedIds), isEmpty);
      // The export still holds every review.
      expect(
        LogJsonl.decode(state.progress.exportJsonl()).reviews,
        hasLength(total),
      );
      // No Spanish deck is placed, the label is the new one, and Verified for
      // Read is cleared.
      expect(
        state.settings.placedDecks.where((id) => id.startsWith('es-')),
        isEmpty,
      );
      expect(
        state.settings.skillLabelsOf('es')['read'],
        run.readout[PlacementSkill.read]!.label.name,
      );
      expect(state.settings.verifiedSkillsOf('es'), isNot(contains('read')));
      // The row is no longer "Check your level again".
      expect(state.unconfirmedMomentsOf('es'), isEmpty);
      expect(state.settings.placementRunOf('es'), isNull);
    });

    test('Keep the old level changes nothing but the choice', () {
      credit090(readModes);
      final log = state.progress.log.length;
      final states = state.progress.states.length;
      final labels = state.settings.skillLabelsOf('es');
      final decks = state.settings.placedDecks;
      expect(state.unconfirmedMomentsOf('es'), isNotEmpty);

      state.keepOldLevel('es');

      expect(state.progress.log.length, log);
      expect(state.progress.states.length, states);
      expect(state.progress.withdrawals, isEmpty);
      expect(state.settings.skillLabelsOf('es'), labels);
      expect(state.settings.placedDecks, decks);
      expect(state.settings.verifiedSkillsOf('es'), <String>{'read'});
      expect(state.settings.placementKeptOf('es'), <int>{momentOf(t1)});
      expect(state.unconfirmedMomentsOf('es'), isEmpty);
    });

    test('a check that proves more withdraws nothing and adds credit between '
        'the levels at a stamped moment', () {
      credit090(readModes, decks: 1);
      final run = finished(<PlacementSkill>{PlacementSkill.read}, true);
      final found = run.readout[PlacementSkill.read]!;
      expect(found.placedLevel, greaterThan(0));
      run.write(state, 'es', plan, recheck: true);

      expect(state.progress.withdrawals, isEmpty);
      final at = momentOf(state.now());
      expect(state.settings.placedByOf('es'), contains(at));
      final upTo = plan.decks.take(found.placedLevel + 1).toList();
      final second = upTo[upTo.length > 1 ? 1 : 0];
      expect(
        second.cards.any(
          (c) => state.progress.stateOf(c.id, DrillMode.recognition) != null,
        ),
        isTrue,
        reason: 'credit is added on the decks between the levels',
      );
      expect(state.unconfirmedMomentsOf('es'), isEmpty);
    });

    test('a skill the run did not test keeps its credit', () {
      credit090(readModes);
      credit090(const <DrillMode>{DrillMode.listening}, decks: 3);
      final run = finished(<PlacementSkill>{PlacementSkill.read}, false);
      run.write(state, 'es', plan, recheck: true);

      final hear = <bool>[
        for (final deck in plan.decks.take(3))
          for (final card in deck.cards)
            state.progress.stateOf(card.id, DrillMode.listening) != null,
      ];
      expect(hear, isNotEmpty);
      expect(hear.every((x) => x), isTrue);
      expect(
        state.progress.withdrawals.every(
          (w) => !w.modes.contains(DrillMode.listening),
        ),
        isTrue,
      );
    });

    test('a new run\'s credit is stamped with the model, so it is never '
        'flagged', () {
      final run = finished(<PlacementSkill>{PlacementSkill.read}, true);
      run.write(state, 'es', plan);
      final moment = momentOf(state.now());
      expect(state.settings.placedAtOf('es'), contains(moment));
      expect(state.settings.placedByOf('es'), contains(moment));
      expect(state.unconfirmedMomentsOf('es'), isEmpty);
    });

    test('placement credit never enters a fit through a withdrawal: the '
        'withdrawn reviews are not in the log the fits read', () {
      credit090(readModes);
      final run = finished(<PlacementSkill>{PlacementSkill.read}, false);
      run.write(state, 'es', plan, recheck: true);
      expect(
        state.progress.skillLog.where((e) => e.at == t1),
        isEmpty,
        reason: 'a fit reads the log without the credit taken back',
      );
    });

    test('the credit shape is exactly what creditPlacement writes', () {
      credit090(readModes, decks: 1);
      final first = state.progress.log.first;
      expect(hasCreditShape(logged(first)), isTrue);
      expect(first.grade, 5);
      expect(first.answerGiven, isNull);
      expect(first.elapsed, Duration.zero);
      expect(first.asked, Ask.own);
    });
  });

  test('the placement model and the cut-off are the ones of the plan', () {
    expect(kPlacementModel, 3);
    expect(kPlacementCheckFrom, 1793995687);
    expect(
      DateTime.fromMillisecondsSinceEpoch(
        kPlacementCheckFrom * 1000,
        isUtc: true,
      ).toIso8601String(),
      startsWith('2026-11-06T20:08:07'),
    );
  });
}
