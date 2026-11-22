// The review log is replayed under the catalog's skill map (#1699): opening
// with the map gives what the old path gave (replay without it, then set it),
// an equal map afterwards replays nothing, a different one replays on an
// isolate's runner and gives the setter's result, and a snapshot made under
// another map is never used.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/replay_isolate.dart';
import 'package:fluenough/core/data/replay_snapshot.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _at = DateTime(2026, 9, 28, 19);

/// A log where one card hears a form, one deck is a script deck, and the
/// answers to both imply other skills.
List<LoggedReview> _reviews() => <LoggedReview>[
  for (var i = 0; i < 24; i++)
    (
      key: (
        cardId: i.isEven ? 'es-0001' : 'es-0002',
        mode: i % 3 == 0
            ? DrillMode.production
            : (i % 3 == 1 ? DrillMode.listening : DrillMode.recognition),
      ),
      deckId: i % 4 == 0 ? 'es-en-script' : 'es-en-core',
      at: _at.add(Duration(days: i ~/ 2, hours: i)),
      grade: i % 5 == 0 ? 1 : 4,
      elapsed: const Duration(seconds: 3),
      answerGiven: null,
      script: i % 4 == 0 ? 'latin' : null,
      asked: Ask.own,
    ),
];

SkillMap _map() => SkillMap(
  formHeardCards: <String>{'es-0001'},
  scriptDecks: <String>{'es-en-script'},
  primaryScripts: <String, String>{'es': 'latin'},
);

/// What a store holds, as plain values to compare.
List<Object?> _held(ProgressStore p) => <Object?>[
  for (final e in p.log)
    (e.cardId, e.mode, e.grade, e.at, e.after.stability, e.share),
  for (final MapEntry(:key, :value)
      in p.states.entries.toList()
        ..sort((a, b) => '${a.key}'.compareTo('${b.key}')))
    (key, value.stability, value.difficulty, value.dueAt, value.repetitions),
  for (final e in p.scriptLog) (e.cardId, e.mode, e.grade, e.at, e.script),
  for (final MapEntry(:key, :value)
      in p.scriptStates.entries.toList()
        ..sort((a, b) => '${a.key}'.compareTo('${b.key}')))
    (key, value.stability, value.dueAt),
];

OpenJob _job({SkillMap skills = const SkillMap()}) => OpenJob(
  reviews: _reviews(),
  leechActions: const [],
  fitted: const {},
  skills: skills,
);

void main() {
  group('opening under the skill map', () {
    test('equals the old path: replay without it, then set it', () {
      final old = MemoryProgress.opened(
        openLog(_job()),
        fitted: const {},
      )..skills = _map();
      final opened = MemoryProgress.opened(
        openLog(_job(skills: _map())),
        fitted: const {},
        skills: _map(),
      );
      addTearDown(old.dispose);
      addTearDown(opened.dispose);
      expect(opened.scriptLog, isNotEmpty, reason: 'the fixture reaches it');
      expect(_held(opened), _held(old));
    });

    test('equals replaying the events under the map directly', () {
      final direct = MemoryProgress.replaying(
        openLog(_job()).memory.events,
        skills: _map(),
      );
      final opened = MemoryProgress.opened(
        openLog(_job(skills: _map())),
        fitted: const {},
        skills: _map(),
      );
      addTearDown(direct.dispose);
      addTearDown(opened.dispose);
      expect(_held(opened), _held(direct));
    });

    test('an equal map set afterwards replays nothing', () {
      final opened = MemoryProgress.opened(
        openLog(_job(skills: _map())),
        fitted: const {},
        skills: _map(),
      );
      addTearDown(opened.dispose);
      final before = MemoryProgress.replaces;
      final version = opened.version;
      opened.skills = _map();
      expect(MemoryProgress.replaces, before);
      expect(opened.version, version);
    });

    test('a different map set afterwards replays once', () {
      final opened = MemoryProgress.opened(
        openLog(_job(skills: _map())),
        fitted: const {},
        skills: _map(),
      );
      addTearDown(opened.dispose);
      final before = MemoryProgress.replaces;
      opened.skills = const SkillMap();
      expect(MemoryProgress.replaces, before + 1);
    });
  });

  group('replaceSkills', () {
    test('gives the setter\'s result without replaying in place', () async {
      final a = MemoryProgress.opened(openLog(_job()), fitted: const {});
      final b = MemoryProgress.opened(openLog(_job()), fitted: const {})
        ..skills = _map();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final before = MemoryProgress.replaces;
      await a.replaceSkills(_map(), run: skillsInPlace);
      expect(MemoryProgress.replaces, before, reason: 'no _replace here');
      expect(_held(a), _held(b));
      expect(a.skills, _map());
    });

    test('finishing after dispose applies nothing and notifies nothing',
        () async {
      final a = MemoryProgress.opened(openLog(_job()), fitted: const {});
      var notified = 0;
      a.addListener(() => notified++);
      await a.replaceSkills(
        _map(),
        run: (job) async {
          a.dispose();
          return replayWithSkills(job);
        },
      );
      expect(notified, 0);
      expect(a.skills, const SkillMap());
    });

    test('an answer recorded while it works is not lost: it replays '
        'again', () async {
      final a = MemoryProgress.opened(openLog(_job()), fitted: const {});
      final b = MemoryProgress.opened(openLog(_job()), fitted: const {});
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final now = _at.add(const Duration(days: 30));
      void answer(MemoryProgress p) => p.record(
        deckId: 'es-en-core',
        cardId: 'es-0001',
        mode: DrillMode.recognition,
        grade: 4,
        now: now,
        elapsed: const Duration(seconds: 2),
        asked: Ask.own,
      );
      var runs = 0;
      await a.replaceSkills(
        _map(),
        run: (job) async {
          runs++;
          if (runs == 1) answer(a);
          return replayWithSkills(job);
        },
      );
      answer(b);
      b.skills = _map();
      expect(runs, 2);
      expect(_held(a), _held(b));
    });
  });

  group('the snapshot stamp', () {
    LogStamp stamp(SkillMap skills) => LogStamp(
      app: 'x',
      reviews: 5,
      firstId: 1,
      lastId: 5,
      sumIds: 15,
      latest: 9,
      sumTimes: 9,
      sumGrades: 9,
      sumElapsed: 9,
      leechActions: const [],
      fitted: const {},
      skills: skills,
    );

    test('holds the skill map: another map is another stamp', () {
      expect(stamp(_map()), equals(stamp(_map())));
      expect(stamp(_map()), isNot(equals(stamp(const SkillMap()))));
      expect(
        stamp(_map()),
        isNot(
          equals(
            stamp(
              SkillMap(
                formHeardCards: <String>{'es-0001', 'es-0002'},
                scriptDecks: <String>{'es-en-script'},
                primaryScripts: <String, String>{'es': 'latin'},
              ),
            ),
          ),
        ),
      );
    });

    test('does not depend on the order of the sets', () {
      final one = SkillMap(
        formHeardCards: <String>{'a', 'b', 'c'},
        scriptDecks: <String>{'x', 'y'},
        primaryScripts: <String, String>{'es': 'latin', 'hi': 'deva'},
      );
      final other = SkillMap(
        formHeardCards: <String>{'c', 'a', 'b'},
        scriptDecks: <String>{'y', 'x'},
        primaryScripts: <String, String>{'hi': 'deva', 'es': 'latin'},
      );
      expect(skillsDigest(one), skillsDigest(other));
    });
  });

  group('a kept snapshot', () {
    Future<AppDatabase> loggedDb() async {
      final db = AppDatabase(NativeDatabase.memory());
      final log = ReviewLog(db);
      for (final r in _reviews()) {
        await log.record(
          deckId: r.deckId,
          cardId: r.key.cardId,
          mode: r.key.mode,
          grade: r.grade,
          now: r.at,
          elapsed: r.elapsed,
          script: r.script,
          asked: r.asked,
        );
      }
      return db;
    }

    test('is used under the map it was made under and replayed under '
        'another', () async {
      final db = await loggedDb();
      addTearDown(db.close);
      final log = ReviewLog(db);
      final fitted = await log.fitted();
      final first = await log.openCached(
        fitted: fitted,
        app: 'x',
        run: replayInPlace,
        fromSnapshot: snapshotInPlace,
        skills: _map(),
      );
      expect(first.fromSnapshot, isFalse);
      expect(
        await log.putSnapshot(
          first.stamp!,
          first.bytes!,
          app: 'x',
          skills: _map(),
        ),
        isTrue,
      );
      final same = await log.openCached(
        fitted: fitted,
        app: 'x',
        run: replayInPlace,
        fromSnapshot: snapshotInPlace,
        skills: _map(),
      );
      expect(same.fromSnapshot, isTrue);
      expect(same.opened.memory.scriptEvents, isNotEmpty);
      List<Object?> script(OpenedLog o) => <Object?>[
        for (final e in o.memory.scriptEvents) (e.share, e.after.stability),
      ];
      final other = await log.openCached(
        fitted: fitted,
        app: 'x',
        run: replayInPlace,
        fromSnapshot: snapshotInPlace,
      );
      expect(other.fromSnapshot, isFalse, reason: 'a stale snapshot');
      expect(script(other.opened), isNot(equals(script(same.opened))));
    });
  });

  group('DatabaseProgress that waits for the skill map', () {
    Future<AppDatabase> loggedDb() async {
      final db = AppDatabase(NativeDatabase.memory());
      final log = ReviewLog(db);
      for (final r in _reviews()) {
        await log.record(
          deckId: r.deckId,
          cardId: r.key.cardId,
          mode: r.key.mode,
          grade: r.grade,
          now: r.at,
          elapsed: r.elapsed,
          script: r.script,
          asked: r.asked,
        );
      }
      return db;
    }

    DatabaseProgress open(AppDatabase db, List<String> stages) =>
        DatabaseProgress.opening(
          db,
          replayer: replayInPlace,
          snapshotter: snapshotInPlace,
          skillsRunner: skillsInPlace,
          awaitSkills: true,
          app: 'x',
          onStage: stages.add,
        );

    /// What the old path gives for the same log and map.
    Future<MemoryProgress> reference(AppDatabase db) async {
      final log = ReviewLog(db);
      final opened = await log.openReplay(
        fitted: await log.fitted(),
        run: replayInPlace,
      );
      return MemoryProgress.opened(opened, fitted: const {})..skills = _map();
    }

    test('is not ready until the map is given, then equals the old path with '
        'no replay in place', () async {
      final db = await loggedDb();
      addTearDown(db.close);
      final want = await reference(db);
      addTearDown(want.dispose);
      final before = MemoryProgress.replaces;
      final progress = open(db, <String>[]);
      addTearDown(progress.dispose);
      var ready = false;
      progress.ready.then((_) => ready = true).ignore();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ready, isFalse, reason: 'it waits for the catalog\'s map');
      progress.skills = _map();
      await progress.ready;
      expect(_held(progress), _held(want));
      expect(progress.skills, _map());
      expect(MemoryProgress.replaces, before, reason: 'nothing replayed here');
    });

    test('an equal map afterwards does nothing; a different one replays '
        'through the runner and equals the setter\'s result', () async {
      final db = await loggedDb();
      addTearDown(db.close);
      final progress = open(db, <String>[]);
      addTearDown(progress.dispose);
      progress.skills = _map();
      await progress.ready;
      final version = progress.version;
      progress.skills = _map();
      await progress.skillsSettled;
      expect(progress.version, version);
      final other = SkillMap(
        formHeardCards: <String>{'es-0001', 'es-0002'},
        scriptDecks: <String>{'es-en-script'},
        primaryScripts: <String, String>{'es': 'latin'},
      );
      final before = MemoryProgress.replaces;
      progress.skills = other;
      await progress.skillsSettled;
      expect(MemoryProgress.replaces, before, reason: 'replayed by the runner');
      final want = await reference(db);
      addTearDown(want.dispose);
      want.skills = other;
      expect(progress.skills, other);
      expect(_held(progress), _held(want));
    });

    test('the next launch opens from the snapshot made under the '
        'map', () async {
      final db = await loggedDb();
      addTearDown(db.close);
      final first = <String>[];
      final one = open(db, first);
      one.skills = _map();
      await one.ready;
      expect(first, contains('review log replayed'));
      await one.flush();
      one.dispose();
      final second = <String>[];
      final two = open(db, second);
      addTearDown(two.dispose);
      two.skills = _map();
      await two.ready;
      expect(second, contains('snapshot loaded'));
      final want = await reference(db);
      addTearDown(want.dispose);
      expect(_held(two), _held(want));
      // Another map is not the snapshot's.
      final third = <String>[];
      final three = open(db, third);
      addTearDown(three.dispose);
      three.skills = const SkillMap();
      await three.ready;
      expect(third, contains('review log replayed'));
    });

    test('map X replaying then the old map Y asked for ends on Y', () async {
      final db = await loggedDb();
      addTearDown(db.close);
      final gate = Completer<void>();
      final ran = <SkillMap>[];
      final progress = DatabaseProgress.opening(
        db,
        replayer: replayInPlace,
        snapshotter: snapshotInPlace,
        awaitSkills: true,
        app: 'x',
        skillsRunner: (job) async {
          ran.add(job.skills);
          await gate.future;
          return replayWithSkills(job);
        },
      );
      addTearDown(progress.dispose);
      progress.skills = _map();
      await progress.ready;
      final x = SkillMap(
        formHeardCards: <String>{'es-0001', 'es-0002'},
        scriptDecks: <String>{'es-en-script'},
        primaryScripts: <String, String>{'es': 'latin'},
      );
      progress.skills = x;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      progress.skills = _map(); // back to Y while X is replaying
      gate.complete();
      await progress.skillsSettled;
      expect(progress.skills, _map());
      final want = await reference(db);
      addTearDown(want.dispose);
      expect(_held(progress), _held(want));
    });

    test('an empty map is a map: the log is read and held', () async {
      final db = await loggedDb();
      addTearDown(db.close);
      final progress = open(db, <String>[]);
      addTearDown(progress.dispose);
      progress.skills = const SkillMap();
      await progress.ready;
      expect(progress.skills, const SkillMap());
      expect(progress.log, isNotEmpty);
    });
  });
}
