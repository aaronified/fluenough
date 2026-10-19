import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';

/// Reading and writing the script are skills of their own (#556; owner,
/// 2026-10-17: "Both" and "Rebuild from the log"): the answers to the script
/// decks count for the word skills as today and, in full, for Read script and
/// Write script, which are worked out from the log.
void main() {
  final day = DateTime(2026, 10, 1, 9);
  const script = 'hi-script-vowels';
  const words = 'hi-first-words';
  const map = SkillMap(
    formHeardIn: <String>{script},
    scriptDecks: <String>{script},
    primaryScripts: <String, String>{'hi': 'devanagari'},
  );

  // Script-deck answers from before the script was kept per answer count
  // for the course's primary script (#653).
  const read = (
    cardId: 'hi-0001',
    mode: DrillMode.readScript,
    script: 'devanagari',
  );
  const write = (
    cardId: 'hi-0001',
    mode: DrillMode.writeScript,
    script: 'devanagari',
  );
  const recognition = (cardId: 'hi-0001', mode: DrillMode.recognition);
  const production = (cardId: 'hi-0001', mode: DrillMode.production);

  LoggedReview review(
    DrillMode mode,
    int grade,
    DateTime at, {
    String deck = script,
    String card = 'hi-0001',
  }) => (
    key: (cardId: card, mode: mode),
    deckId: deck,
    at: at,
    grade: grade,
    elapsed: Duration.zero,
    answerGiven: mode == DrillMode.recognition ? null : 'x',
    script: null,
    asked: null,
  );

  group('SkillMap.scriptOf', () {
    test('recognition and write feed the script skills in full', () {
      expect(map.scriptOf(review(DrillMode.recognition, 4, day)), (
        skill: DrillMode.readScript,
        script: 'devanagari',
        share: 1.0,
      ));
      expect(map.scriptOf(review(DrillMode.production, 4, day)), (
        skill: DrillMode.writeScript,
        script: 'devanagari',
        share: 1.0,
      ));
    });

    test('say and hear feed neither: the owner gave no other feed', () {
      expect(map.scriptOf(review(DrillMode.speaking, 4, day)), isNull);
      expect(map.scriptOf(review(DrillMode.listening, 4, day)), isNull);
    });

    test('an old answer outside the script decks, or grammar, feeds none', () {
      for (final mode in DrillMode.drills) {
        expect(map.scriptOf(review(mode, 4, day, deck: words)), isNull);
      }
      expect(map.scriptOf(review(DrillMode.grammar, 4, day)), isNull);
      expect(map.scriptOf(review(DrillMode.reading, 4, day)), isNull);
    });

    test('the script skills are not drills', () {
      expect(DrillMode.readScript.isScript, isTrue);
      expect(DrillMode.writeScript.isScript, isTrue);
      expect(DrillMode.drills, isNot(contains(DrillMode.readScript)));
      expect(DrillMode.drills, hasLength(DrillMode.values.length - 2));
    });
  });

  group('rebuilt from the log', () {
    final log = <LoggedReview>[
      review(DrillMode.recognition, 4, day),
      review(DrillMode.production, 3, day.add(const Duration(hours: 1))),
      review(DrillMode.recognition, 5, day.add(const Duration(days: 3))),
      review(DrillMode.recognition, 3, day, deck: words, card: 'hi-0002'),
    ];

    test('script-deck answers give both skills a state of their own', () {
      final replayed = replayReviews(log, skills: map);
      expect(replayed.scriptStates.keys.toSet(), {read, write});
      expect(replayed.scriptStates[read]!.repetitions, 2);
      expect(replayed.scriptStates[write]!.repetitions, 1);
      expect(replayed.scriptEvents, hasLength(3));
      expect(replayed.scriptEvents.first.mode, DrillMode.readScript);
      expect(replayed.scriptEvents.first.wasNew, isTrue);
      expect(replayed.scriptEvents.last.before, isNotNull);
    });

    test('a read-script state is what recognition alone would give', () {
      final replayed = replayReviews(log, skills: map);
      final alone = Fsrs.replay(<({int grade, DateTime at, bool rated})>[
        (grade: 4, at: day, rated: true),
        (grade: 5, at: day.add(const Duration(days: 3)), rated: true),
      ]);
      expect(replayed.scriptStates[read]!.stability, alone!.stability);
      expect(replayed.scriptStates[read]!.dueAt, alone.dueAt);
    });

    test('"Both": the word skills keep their own schedules', () {
      final withScript = replayReviews(log, skills: map);
      final without = replayReviews(log, skills: const SkillMap());
      expect(without.scriptStates, isEmpty);
      expect(without.scriptEvents, isEmpty);
      for (final key in <ProgressKey>[recognition, production]) {
        expect(
          withScript.states[key]!.stability,
          without.states[key]!.stability,
        );
        expect(withScript.states[key]!.dueAt, without.states[key]!.dueAt);
      }
      // Never one schedule: the log's pairs are not the script's.
      expect(
        withScript.states.containsKey((cardId: read.cardId, mode: read.mode)),
        isFalse,
      );
      expect(withScript.events, hasLength(4));
    });

    test('a word deck feeds no script skill', () {
      final replayed = replayReviews(<LoggedReview>[
        review(DrillMode.recognition, 4, day, deck: words),
      ], skills: map);
      expect(replayed.scriptStates, isEmpty);
    });

    test('each skill is scheduled with its own fit', () {
      final fitted = FittedParameters(
        values: <double>[
          for (final (i, w) in Fsrs.w.indexed) i == 8 ? w + 0.6 : w,
        ],
        fittedAt: day,
        reviewCount: 30,
      );
      final parameters = SkillParameters(
        fitted: <SkillKey, FittedParameters>{
          (language: 'hi', mode: DrillMode.readScript): fitted,
        },
      );
      final replayed = replayReviews(log, skills: map, parameters: parameters);
      final plain = replayReviews(log, skills: map);
      expect(
        replayed.scriptStates[read]!.stability,
        isNot(plain.scriptStates[read]!.stability),
      );
      expect(
        replayed.scriptStates[write]!.stability,
        plain.scriptStates[write]!.stability,
      );
      expect(
        replayed.states[recognition]!.stability,
        plain.states[recognition]!.stability,
      );
    });
  });

  group('MemoryProgress', () {
    MemoryProgress learner() {
      final progress = MemoryProgress()..skills = map;
      for (final r in <LoggedReview>[
        review(DrillMode.recognition, 4, day),
        review(DrillMode.production, 3, day.add(const Duration(hours: 1))),
        review(DrillMode.recognition, 5, day, deck: words, card: 'hi-0002'),
      ]) {
        progress.record(
          deckId: r.deckId,
          cardId: r.key.cardId,
          mode: r.key.mode,
          grade: r.grade,
          now: r.at,
          answerGiven: r.answerGiven,
        );
      }
      return progress;
    }

    test('script reviews are kept apart from the log and the states', () {
      final progress = learner();
      expect(progress.log, hasLength(3));
      expect(progress.states.keys.any((k) => k.mode.isScript), isFalse);
      expect(progress.scriptLog, hasLength(2));
      expect(progress.skillLog, hasLength(5));
      expect(progress.stateOf('hi-0001', DrillMode.readScript), isNull);
      expect(progress.scriptStates.keys.toSet(), {read, write});
    });

    test('recording is what replaying the log gives (upgrade)', () {
      final recorded = learner();
      // A phone from before the skills: the same log, replayed once the
      // decks say which are script decks.
      final upgraded = MemoryProgress.replaying(recorded.log);
      expect(upgraded.scriptStates, isEmpty);
      upgraded.skills = map;
      expect(
        upgraded.scriptStates.keys.toSet(),
        recorded.scriptStates.keys.toSet(),
      );
      for (final key in recorded.scriptStates.keys) {
        expect(
          upgraded.scriptStates[key]!.stability,
          recorded.scriptStates[key]!.stability,
        );
        expect(
          upgraded.scriptStates[key]!.dueAt,
          recorded.scriptStates[key]!.dueAt,
        );
      }
      expect(upgraded.scriptLog, hasLength(recorded.scriptLog.length));
    });

    test('a fit of a script skill reschedules it alone', () async {
      final progress = learner();
      // A second review: a pair's first does not depend on the parameters.
      progress.record(
        deckId: script,
        cardId: 'hi-0001',
        mode: DrillMode.recognition,
        grade: 4,
        now: day.add(const Duration(days: 3)),
      );
      final before = progress.scriptStates[read]!.stability;
      final word = progress.states[recognition]!.stability;
      await progress.putFitted(
        (language: 'hi', mode: DrillMode.readScript),
        FittedParameters(
          values: <double>[
            for (final (i, w) in Fsrs.w.indexed) i == 8 ? w + 0.6 : w,
          ],
          fittedAt: day,
          reviewCount: 30,
        ),
      );
      expect(progress.scriptStates[read]!.stability, isNot(before));
      expect(progress.states[recognition]!.stability, word);
    });
  });

  group('DatabaseProgress', () {
    test(
      'past script-deck answers give the skills their state on upgrade',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        final first = await DatabaseProgress.open(db);
        first.record(
          deckId: script,
          cardId: 'hi-0001',
          mode: DrillMode.recognition,
          grade: 4,
          now: day,
        );
        first.record(
          deckId: script,
          cardId: 'hi-0001',
          mode: DrillMode.production,
          grade: 4,
          now: day.add(const Duration(hours: 1)),
          answerGiven: 'x',
        );
        await first.flush();
        // Opened again, as after the update: nothing of the script skills is
        // stored, and the log alone gives them once the decks are read.
        final again = await DatabaseProgress.open(db);
        expect(again.scriptStates, isEmpty);
        again.skills = map;
        expect(again.scriptStates.keys.toSet(), {read, write});
        expect(again.log, hasLength(2));
        expect(again.states.keys.any((k) => k.mode.isScript), isFalse);
        await again.close();
      },
    );
  });
}
