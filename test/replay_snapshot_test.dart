// The kept replay (#857, ADR-0051): opening from a snapshot gives exactly what
// replaying the log gives, and anything that makes the snapshot not the log's
// gives the replay instead.

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/replay_isolate.dart';
import 'package:fluenough/core/data/replay_snapshot.dart';
import 'package:fluenough/core/data/restore_record.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/leech_action.dart';
import 'package:fluenough/core/models/review_event.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:flutter_test/flutter_test.dart';

const String _app = 'test-app';

List<Object?> _state(FsrsState? s) => s == null
    ? <Object?>[null]
    : <Object?>[
        s.stability,
        s.difficulty,
        s.intervalDays,
        s.dueAt,
        s.lastReviewAt,
        s.repetitions,
        s.lapses,
        s.recallAtReview,
      ];

List<Object?> _event(ReviewEvent e) => <Object?>[
  e.at,
  e.deckId,
  e.cardId,
  e.mode,
  e.grade,
  e.elapsed,
  e.answerGiven,
  e.script,
  e.asked,
  e.share,
  ..._state(e.before),
  ..._state(e.after),
];

/// A map's entries in the order it holds them, with states as plain values:
/// the order is part of what must be equal.
List<Object?> _states<K>(Map<K, FsrsState> states) => <Object?>[
  for (final MapEntry(:key, :value) in states.entries)
    <Object?>['$key', ..._state(value)],
];

/// Everything an opened log holds, as lists, so that `equals` compares it.
List<Object?> _opened(OpenedLog o) {
  final languages = o.index.languages.toList()..sort();
  return <Object?>[
    o.memory.events.map(_event).toList(),
    _states(o.memory.states),
    o.memory.scriptEvents.map(_event).toList(),
    _states(o.memory.scriptStates),
    _states(o.cacheStates),
    <Object?>[
      for (final MapEntry(:key, :value) in o.lastStudied.entries) [key, value],
    ],
    <Object?>[
      for (final a in o.leechActions) [a.at, '${a.key}', a.kind],
    ],
    o.index.length,
    <Object?>[
      for (final l in languages)
        <Object?>[
          l,
          o.index.reviewsIn(l),
          o.index.latestIn(l),
          o.index.leechCount(l),
          <Object?>[
            for (final MapEntry(:key, :value)
                in o.index.perDay(l).entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key)))
              [key, value],
          ],
        ],
    ],
    <Object?>[
      for (final e in o.memory.events) ...<Object?>[
        o.index.lapsesOf(e.key),
        o.index.positionsOf(e.cardId),
      ],
    ],
    <Object?>[
      for (final l in o.index.leeches()) ['${l.key}', l.deckId, l.lapses],
    ],
  ];
}

final DateTime _at = DateTime(2026, 9, 28, 19);

/// A log with what a replay has to get right: answers out of time order and
/// in a tie, three languages and several modes, a walkthrough's view, a
/// reset, an answer typed rather than rated, a script and misses enough for a
/// leech.
Future<AppDatabase> _loggedDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  final log = ReviewLog(db);
  const days = <int>[3, 0, 5, 1, 2, 9, 4, 4, 7, 6, 8, 10, 12, 11, 13, 14];
  for (final (i, day) in days.indexed) {
    final language = const <String>['es', 'hi', 'te'][i % 3];
    await log.record(
      deckId: '$language-en-core',
      cardId: '$language-000${i % 4 + 1}',
      mode: i % 4 == 0
          ? DrillMode.production
          : (i % 5 == 0 ? DrillMode.listening : DrillMode.recognition),
      grade: i % 6,
      now: _at.add(Duration(days: day, minutes: i == 6 || i == 7 ? 0 : i)),
      asked: i == 3 ? Ask.teach : (i == 8 ? Ask.chooseWord : null),
      answerGiven: i == 5 ? 'agua' : null,
      script: i == 8 ? 'deva' : null,
    );
  }
  for (var i = 0; i < 12; i++) {
    await log.record(
      deckId: 'te-en-core',
      cardId: 'te-0099',
      mode: DrillMode.recognition,
      grade: i.isEven ? 4 : 0,
      now: _at.add(Duration(days: 20 + i)),
    );
  }
  await db.leechActionsDao.append(
    LeechAction(
      at: _at.add(const Duration(days: 4, hours: 12)),
      key: (cardId: 'es-0001', mode: DrillMode.production),
      kind: LeechActionKind.reset,
    ),
  );
  return db;
}

Future<void> _fit(
  AppDatabase db,
  String language,
  DrillMode mode,
  double scale,
) => db.fsrsParametersDao.put(
  FsrsParametersCompanion.insert(
    language: language,
    mode: mode,
    parameters: <double>[
      for (var i = 0; i < Fsrs.w.length; i++)
        Fsrs.w[i] * (1 + scale * (i % 3 + 1)),
    ].join(','),
    fittedAt: _at,
    reviewCount: 30,
  ),
);

/// Opens `db`'s log as DatabaseProgress would, in place.
Future<
  ({OpenedLog opened, bool fromSnapshot, LogStamp? stamp, Uint8List? bytes})
>
_open(ReviewLog log, {String app = _app}) async => log.openCached(
  fitted: await log.fitted(),
  app: app,
  run: replayInPlace,
  fromSnapshot: snapshotInPlace,
);

/// What replaying `db`'s log gives, never from a snapshot.
Future<OpenedLog> _replayed(ReviewLog log) async =>
    log.openReplay(fitted: await log.fitted(), run: replayInPlace);

/// Keeps a snapshot of the log as it is, as opening it would.
Future<void> _keep(ReviewLog log) async {
  final opening = await _open(log);
  expect(
    await log.putSnapshot(opening.stamp!, opening.bytes!, app: _app),
    isTrue,
  );
}

void main() {
  group('opening from the kept snapshot', () {
    test('equals a full replay: events, states, parameters, index and the '
        'cache, with no replay run', () async {
      final db = await _loggedDb();
      addTearDown(db.close);
      final log = ReviewLog(db);
      await _fit(db, 'es', DrillMode.recognition, 0.01);
      await _fit(db, 'hi', DrillMode.recognition, 0.02);
      final reference = await _replayed(log);

      final first = await _open(log);
      expect(first.fromSnapshot, isFalse, reason: 'nothing kept yet');
      await _keep(log);

      final replays = ReviewLog.replays;
      final second = await log.openCached(
        fitted: await log.fitted(),
        app: _app,
      ); // the default runners: the snapshot is read on an isolate
      expect(second.fromSnapshot, isTrue);
      expect(ReviewLog.replays, replays, reason: 'the log was not replayed');
      expect(_opened(second.opened), _opened(reference));
      expect(reference.memory.events, hasLength(28));
      expect(
        reference.index.leechCount('te'),
        1,
        reason: 'the log has a leech, so the index is checked on one',
      );
      expect(
        reference.cacheStates.length,
        isPositive,
        reason: 'and a cache to compare',
      );
    });

    test('a script skill and an implied review round-trip exactly', () {
      final reviews = <LoggedReview>[
        for (final (i, grade) in <int>[4, 5, 0, 3, 4, 5].indexed)
          (
            key: (
              cardId: 'hi-0001',
              mode: i.isEven ? DrillMode.recognition : DrillMode.production,
            ),
            deckId: 'hi-alphabet',
            at: _at.add(Duration(hours: 5 * i)),
            grade: grade,
            elapsed: Duration(milliseconds: 700 + i),
            answerGiven: i == 3 ? 'ka' : null,
            script: i == 4 ? null : 'deva',
            asked: i == 0 ? null : Ask.own,
          ),
      ];
      const skills = SkillMap(
        scriptDecks: <String>{'hi-alphabet'},
        primaryScripts: <String, String>{'hi': 'deva'},
      );
      final memory = replayReviews(reviews, skills: skills);
      final cache = replayReviews(reviews);
      expect(memory.scriptEvents, isNotEmpty, reason: 'script skills ran');
      expect(
        _states(memory.states),
        isNot(_states(cache.states)),
        reason: 'a right production answer moved the recognition state',
      );

      final kept = decodeSnapshot(
        encodeSnapshot(memory: memory, cacheStates: cache.states),
      );
      expect(kept.memory.events.map(_event), memory.events.map(_event));
      expect(
        kept.memory.scriptEvents.map(_event),
        memory.scriptEvents.map(_event),
      );
      expect(_states(kept.memory.states), _states(memory.states));
      expect(_states(kept.memory.scriptStates), _states(memory.scriptStates));
      expect(_states(kept.cacheStates), _states(cache.states));
    });

    test('bytes that are cut short, changed or foreign are refused', () {
      final replayed = replayReviews(<LoggedReview>[
        (
          key: (cardId: 'es-0001', mode: DrillMode.recognition),
          deckId: 'es-en-core',
          at: _at,
          grade: 4,
          elapsed: const Duration(seconds: 2),
          answerGiven: null,
          script: null,
          asked: null,
        ),
      ]);
      final bytes = encodeSnapshot(
        memory: replayed,
        cacheStates: replayed.states,
      );
      expect(decodeSnapshot(bytes).memory.events, hasLength(1));
      expect(
        () => decodeSnapshot(bytes.sublist(0, bytes.length - 3)),
        throwsA(anything),
      );
      final changed = Uint8List.fromList(bytes)..[bytes.length ~/ 2] ^= 0xff;
      expect(() => decodeSnapshot(changed), throwsA(anything));
      expect(() => decodeSnapshot(Uint8List(0)), throwsA(anything));
      expect(
        openFromSnapshot(
          SnapshotJob(
            bytes: bytes,
            leechActions: const <LeechAction>[],
            reviewCount: 2,
          ),
        ),
        isNull,
        reason: 'a snapshot of one event is not the log of two',
      );
    });
  });

  group('whatever changes the log gives a full replay', () {
    /// Keeps a snapshot, changes the database with [change], and expects the
    /// open to replay and to give what replaying gives.
    Future<void> expectReplay(
      Future<void> Function(AppDatabase db, ReviewLog log) change, {
      Future<void> Function(AppDatabase db)? before,
      String app = _app,
      bool differs = true,
    }) async {
      final db = await _loggedDb();
      addTearDown(db.close);
      final log = ReviewLog(db);
      if (before != null) await before(db);
      await _keep(log);
      final old = _opened((await _open(log)).opened);
      await change(db, log);

      final replays = ReviewLog.replays;
      final opening = await _open(log, app: app);
      expect(opening.fromSnapshot, isFalse);
      expect(ReviewLog.replays, replays + 1);
      expect(opening.bytes, isNotNull, reason: 'and a new one is made');
      final reference = _opened(await _replayed(log));
      expect(_opened(opening.opened), reference);
      if (differs) {
        expect(reference, isNot(old), reason: 'the snapshot was out of date');
      }
      // A new snapshot, kept, is then used.
      expect(
        await log.putSnapshot(opening.stamp!, opening.bytes!, app: app),
        isTrue,
      );
      final again = await log.openCached(
        fitted: await log.fitted(),
        app: app,
        run: replayInPlace,
        fromSnapshot: snapshotInPlace,
      );
      expect(again.fromSnapshot, isTrue);
      expect(_opened(again.opened), reference);
    }

    test('new reviews', () async {
      await expectReplay((db, log) async {
        await log.record(
          deckId: 'es-en-core',
          cardId: 'es-0002',
          mode: DrillMode.recognition,
          grade: 4,
          now: _at.add(const Duration(days: 40)),
        );
      });
    });

    test('a review that moves a language\'s last study, which chooses the '
        'parameters of a language without a fit of its own', () async {
      await expectReplay(
        before: (db) async {
          await _fit(db, 'es', DrillMode.recognition, 0.01);
          await _fit(db, 'hi', DrillMode.recognition, 0.5);
        },
        (db, log) async {
          // Telugu has no fit: it takes the one of the language studied last,
          // which this review changes from Spanish to Hindustani.
          await log.record(
            deckId: 'hi-en-core',
            cardId: 'hi-0003',
            mode: DrillMode.recognition,
            grade: 3,
            now: _at.add(const Duration(days: 60)),
          );
        },
      );
    });

    test('a leech action', () async {
      await expectReplay((db, log) async {
        await db.leechActionsDao.append(
          LeechAction(
            at: _at.add(const Duration(days: 25)),
            key: (cardId: 'te-0099', mode: DrillMode.recognition),
            kind: LeechActionKind.reset,
          ),
        );
      });
    });

    test('a changed set of fitted parameters', () async {
      await expectReplay(
        before: (db) => _fit(db, 'es', DrillMode.recognition, 0.01),
        (db, log) => _fit(db, 'es', DrillMode.recognition, 0.2),
      );
    });

    test('a log imported from a backup', () async {
      await expectReplay((db, log) async {
        final added = await log.importAll(<LoggedReview>[
          (
            key: (cardId: 'hi-0007', mode: DrillMode.recognition),
            deckId: 'hi-en-core',
            at: _at.subtract(const Duration(days: 30)),
            grade: 4,
            elapsed: const Duration(seconds: 3),
            answerGiven: null,
            script: null,
            asked: null,
          ),
        ], const <LeechAction>[]);
        expect(added.added, 1);
      });
    });

    test('a log restored from a backup', () async {
      await expectReplay((db, log) async {
        await log.replaceAll(
          <LoggedReview>[
            for (var i = 0; i < 3; i++)
              (
                key: (cardId: 'es-000${i + 1}', mode: DrillMode.recognition),
                deckId: 'es-en-core',
                at: _at.add(Duration(days: i)),
                grade: 4,
                elapsed: const Duration(seconds: 1),
                answerGiven: null,
                script: null,
                asked: null,
              ),
          ],
          const <LeechAction>[],
          restore: RestoreRecord(
            at: _at.add(const Duration(days: 90)),
            backupCreatedAt: _at,
            backupKind: 'you',
            backupAppVersion: '0.7.0',
            fromFile: true,
            keptCopy: 'kept.fnbackup',
          ),
        );
      });
    });

    test('a restore to as many reviews as before is still seen', () async {
      // The same count, replaced: only the ids, which never repeat, differ.
      late List<LoggedReview> same;
      await expectReplay(
        (db, log) async {
          await log.replaceAll(
            same,
            const <LeechAction>[],
            restore: RestoreRecord(
              at: _at.add(const Duration(days: 90)),
              backupCreatedAt: _at,
              backupKind: 'you',
              backupAppVersion: '0.7.0',
              fromFile: true,
              keptCopy: 'kept.fnbackup',
            ),
          );
        },
        before: (db) async {
          same = await ReviewLog(db).reviews();
        },
        differs: false,
      );
    });

    test('another version of the app', () async {
      await expectReplay(
        (db, log) async {},
        app: 'another-app',
        differs: false,
      );
    });

    test('a snapshot that is damaged, cut short, not one, or of another '
        'log', () async {
      final db = await _loggedDb();
      addTearDown(db.close);
      final log = ReviewLog(db);
      await _keep(log);
      final good = (await db.replaySnapshotsDao.payload())!;
      final stamp = (await db.replaySnapshotsDao.stamp())!;
      final reference = _opened(await _replayed(log));

      // A snapshot of fewer reviews, under the stamp of this log.
      final fewer = replayReviews((await log.reviews()).take(5));
      final damaged = <String, Uint8List>{
        'flipped': Uint8List.fromList(good)..[good.length ~/ 3] ^= 0x55,
        'cut short': good.sublist(0, good.length - 10),
        'garbage': Uint8List.fromList(List<int>.generate(64, (i) => i * 7)),
        'empty': Uint8List(0),
        'of fewer reviews': encodeSnapshot(
          memory: fewer,
          cacheStates: fewer.states,
        ),
      };
      for (final MapEntry(:key, :value) in damaged.entries) {
        await db.replaySnapshotsDao.put(stamp: stamp, payload: value, at: _at);
        final opening = await _open(log);
        expect(opening.fromSnapshot, isFalse, reason: key);
        expect(_opened(opening.opened), reference, reason: key);
      }
    });

    test('no snapshot table at all is no snapshot', () async {
      final db = await _loggedDb();
      addTearDown(db.close);
      final log = ReviewLog(db);
      await db.customStatement('DROP TABLE replay_snapshots');
      final opening = await _open(log);
      expect(opening.fromSnapshot, isFalse);
      expect(_opened(opening.opened), _opened(await _replayed(log)));
    });

    test('a snapshot is not kept over a change made since its stamp', () async {
      final db = await _loggedDb();
      addTearDown(db.close);
      final log = ReviewLog(db);
      final opening = await _open(log);
      await log.record(
        deckId: 'es-en-core',
        cardId: 'es-0002',
        mode: DrillMode.recognition,
        grade: 4,
        now: _at.add(const Duration(days: 40)),
      );
      expect(
        await log.putSnapshot(opening.stamp!, opening.bytes!, app: _app),
        isFalse,
      );
      expect(await db.replaySnapshotsDao.stamp(), isNull);
    });
  });

  group('the migration from schema 9', () {
    test('adds the snapshot table, keeps the log, and the first open keeps '
        'a snapshot', () async {
      final dir = Directory.systemTemp.createTempSync('fluenough');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/nine.sqlite');

      final old = AppDatabase(NativeDatabase(file));
      await ReviewLog(old).record(
        deckId: 'es-en-core',
        cardId: 'es-0001',
        mode: DrillMode.recognition,
        grade: 4,
        now: _at,
      );
      await old.customStatement('DROP TABLE replay_snapshots');
      await old.customStatement('PRAGMA user_version = 9');
      await old.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      expect(await upgraded.reviewsDao.all(), hasLength(1));
      expect(await upgraded.replaySnapshotsDao.stamp(), isNull);
      for (final sql in <String>[
        'DELETE FROM reviews',
        'UPDATE reviews SET grade = 1',
      ]) {
        await expectLater(upgraded.customStatement(sql), throwsA(anything));
      }
      expect(AppDatabase.currentSchemaVersion, 10);

      final stages = <String>[];
      final progress = await DatabaseProgress.open(
        upgraded,
        app: _app,
        onStage: stages.add,
      );
      await progress.flush();
      expect(stages, <String>['review log replayed', 'state cache written']);
      expect(await upgraded.replaySnapshotsDao.stamp(), isNotNull);
      expect(await upgraded.reviewsDao.all(), hasLength(1));

      final stagesAgain = <String>[];
      final again = await DatabaseProgress.open(
        upgraded,
        app: _app,
        onStage: stagesAgain.add,
      );
      addTearDown(again.dispose);
      addTearDown(progress.dispose);
      expect(stagesAgain, <String>['snapshot loaded', 'state cache written']);
      expect(again.log, hasLength(1));
    });
  });

  group('DatabaseProgress and the snapshot', () {
    List<Object?> held(DatabaseProgress p) => <Object?>[
      p.log.map(_event).toList(),
      _states(p.states),
      _states(p.scriptStates),
      p.version > 0,
      p.leechActions.length,
      p.parameters.lastStudied.entries.map((e) => [e.key, e.value]).toList(),
    ];

    test('after answers the paused learner\'s next launch loads the snapshot '
        'and holds what a replay holds', () async {
      final db = await _loggedDb();
      addTearDown(db.close);
      final first = await DatabaseProgress.open(db, app: _app);
      addTearDown(first.dispose);
      await first.flush();
      for (var i = 0; i < 4; i++) {
        first.record(
          deckId: 'te-en-core',
          cardId: 'te-000${i + 1}',
          mode: DrillMode.recognition,
          grade: i % 5 + 1,
          now: _at.add(Duration(days: 40 + i, microseconds: 123)),
          elapsed: const Duration(microseconds: 1500),
        );
      }
      first.actOnLeech(
        (cardId: 'te-0099', mode: DrillMode.recognition),
        LeechActionKind.reset,
        now: _at.add(const Duration(days: 50)),
      );
      expect(await first.saveSnapshot(), isTrue);
      await first.flush();

      final builds = ReviewLog.snapshotBuilds;
      final stages = <String>[];
      final loaded = await DatabaseProgress.open(
        db,
        app: _app,
        onStage: stages.add,
      );
      addTearDown(loaded.dispose);
      expect(stages.first, 'snapshot loaded');
      final replayed = await DatabaseProgress.open(
        db,
        app: 'a version with another snapshot',
        replayer: replayInPlace,
      );
      addTearDown(replayed.dispose);
      expect(held(loaded), held(replayed));
      expect(loaded.index.length, replayed.index.length);
      expect(ReviewLog.snapshotBuilds, builds);
    });

    test(
      'a burst of answers makes one snapshot, once the learner pauses',
      () async {
        final db = await _loggedDb();
        addTearDown(db.close);
        final progress = await DatabaseProgress.open(
          db,
          app: _app,
          snapshotAfter: const Duration(milliseconds: 600),
        );
        addTearDown(progress.close);
        await progress.flush();
        final log = ReviewLog(db);
        final builds = ReviewLog.snapshotBuilds;
        for (var i = 0; i < 3; i++) {
          progress.record(
            deckId: 'es-en-core',
            cardId: 'es-0002',
            mode: DrillMode.recognition,
            grade: 4,
            now: _at.add(Duration(days: 40 + i)),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(ReviewLog.snapshotBuilds, builds, reason: 'not while answering');
        await progress.flush();
        final want = (await log.currentStamp(app: _app)).text;
        for (var i = 0; i < 100; i++) {
          if (await db.replaySnapshotsDao.stamp() == want) break;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(await db.replaySnapshotsDao.stamp(), want);
        expect(ReviewLog.snapshotBuilds, builds + 1);
      },
    );

    test('a snapshot that cannot be made never costs the progress', () async {
      final db = await _loggedDb();
      addTearDown(db.close);
      final progress = await DatabaseProgress.open(
        db,
        app: _app,
        replayer: (job) async {
          if (job.encode && job.reviews.length > 28) {
            throw StateError('the isolate failed');
          }
          return openLog(job);
        },
      );
      addTearDown(progress.dispose);
      progress.record(
        deckId: 'es-en-core',
        cardId: 'es-0002',
        mode: DrillMode.recognition,
        grade: 4,
        now: _at.add(const Duration(days: 40)),
      );
      expect(await progress.saveSnapshot(), isFalse);
      await progress.flush(); // does not throw
      expect(progress.persists, isTrue);
      expect(await db.reviewsDao.all(), hasLength(29));
    });
  });
}
