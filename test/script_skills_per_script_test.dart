import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/grading/self_grade.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';

import 'support/two_script_course.dart';

/// Each script a course is learned in has a Read and a Write of its own
/// (#653; owner, 2026-10-19: "Yes, per script."): Hindustani has Devanagari
/// and Perso-Arabic Read and Write. Read is fed by the script decks'
/// Recognition, by choosing script text, and by reading a word for its
/// meaning; Write by the script decks' Write and by typing in the script.
/// Outside the script decks an answer counts for half a review; shown or
/// typed in transliteration, it feeds none.
void main() {
  const devanagari = 'devanagari';
  const persoArabic = 'perso_arabic';
  const letters = 'hi-en-letters';
  const words = 'hi-en-words';
  const map = SkillMap(
    formHeardIn: <String>{letters},
    scriptDecks: <String>{letters},
    primaryScripts: <String, String>{'hi': devanagari},
  );
  final day = DateTime(2026, 10, 1, 9);

  LoggedReview review(
    DrillMode mode, {
    String deck = words,
    String card = 'hi-0001',
    int grade = 4,
    DateTime? at,
    String? script,
    Ask? asked,
  }) => (
    key: (cardId: card, mode: mode),
    deckId: deck,
    at: at ?? day,
    grade: grade,
    elapsed: Duration.zero,
    answerGiven: mode == DrillMode.recognition ? null : 'x',
    script: script,
    asked: asked,
  );

  group('SkillMap.scriptOf', () {
    test('reading a word for its meaning, in the script, is half a Read', () {
      for (final asked in <Ask>[Ask.own, Ask.chooseMeaning, Ask.matchPairs]) {
        expect(
          map.scriptOf(
            review(DrillMode.recognition, script: persoArabic, asked: asked),
          ),
          (skill: DrillMode.readScript, script: persoArabic, share: 0.5),
        );
      }
    });

    test('typing in the script is half a Write, in any deck', () {
      expect(
        map.scriptOf(
          review(DrillMode.production, script: devanagari, asked: Ask.own),
        ),
        (skill: DrillMode.writeScript, script: devanagari, share: 0.5),
      );
    });

    test('choosing script text is half a Read', () {
      for (final (mode, asked) in <(DrillMode, Ask)>[
        (DrillMode.production, Ask.chooseWord),
        (DrillMode.production, Ask.rearrange),
        (DrillMode.listening, Ask.hearAndChoose),
        (DrillMode.grammar, Ask.chooseForm),
      ]) {
        expect(map.scriptOf(review(mode, script: persoArabic, asked: asked)), (
          skill: DrillMode.readScript,
          script: persoArabic,
          share: 0.5,
        ), reason: '$mode $asked');
      }
    });

    test('transliteration, or a way that shows no script text, feeds none', () {
      // In Latin letters, the session keeps no script.
      expect(
        map.scriptOf(review(DrillMode.production, asked: Ask.own)),
        isNull,
      );
      expect(
        map.scriptOf(review(DrillMode.recognition, asked: Ask.own)),
        isNull,
      );
      for (final (mode, asked) in <(DrillMode, Ask)>[
        (DrillMode.listening, Ask.hearMeaning),
        (DrillMode.listening, Ask.own),
        (DrillMode.speaking, Ask.own),
        (DrillMode.grammar, Ask.own),
        (DrillMode.grammarUnderstood, Ask.chooseFormMeaning),
        (DrillMode.reading, Ask.own),
      ]) {
        expect(
          map.scriptOf(review(mode, script: devanagari, asked: asked)),
          isNull,
          reason: '$mode $asked',
        );
      }
    });

    test('a script deck counts in full, in the script it was in', () {
      expect(
        map.scriptOf(
          review(
            DrillMode.recognition,
            deck: letters,
            script: persoArabic,
            asked: Ask.chooseMeaning,
          ),
        ),
        (skill: DrillMode.readScript, script: persoArabic, share: 1.0),
      );
      expect(
        map.scriptOf(
          review(
            DrillMode.production,
            deck: letters,
            script: persoArabic,
            asked: Ask.chooseWord,
          ),
        ),
        (skill: DrillMode.writeScript, script: persoArabic, share: 1.0),
      );
      expect(
        map.scriptOf(
          review(
            DrillMode.listening,
            deck: letters,
            script: devanagari,
            asked: Ask.hearAndChoose,
          ),
        ),
        (skill: DrillMode.readScript, script: devanagari, share: 1.0),
      );
    });

    test('older script-deck history goes to the primary script', () {
      expect(map.scriptOf(review(DrillMode.recognition, deck: letters)), (
        skill: DrillMode.readScript,
        script: devanagari,
        share: 1.0,
      ));
      // Kept since, but in no script learned: none.
      expect(
        map.scriptOf(
          review(DrillMode.recognition, deck: letters, asked: Ask.own),
        ),
        isNull,
      );
    });
  });

  group('Fsrs.partial', () {
    test('a whole share is a review', () {
      final full = Fsrs.next(null, 4, now: day);
      final whole = Fsrs.partial(null, 4, 1, now: day);
      expect(whole.stability, full.stability);
      expect(whole.dueAt, full.dueAt);
    });

    test('half a first review starts the pair at half the stability', () {
      final full = Fsrs.next(null, 4, now: day);
      final half = Fsrs.partial(null, 4, 0.5, now: day);
      expect(half.stability, closeTo(full.stability / 2, 1e-9));
      expect(half.intervalDays, Fsrs.intervalFor(half.stability));
      expect(half.repetitions, 1);
    });

    test('half a later review moves halfway, up or down', () {
      final start = Fsrs.next(null, 4, now: day);
      final later = day.add(const Duration(days: 4));
      for (final grade in <int>[1, 4]) {
        final full = Fsrs.next(start, grade, now: later);
        final half = Fsrs.partial(start, grade, 0.5, now: later);
        expect(
          half.stability,
          closeTo((start.stability + full.stability) / 2, 1e-9),
        );
        expect(half.lastReviewAt, later);
      }
    });
  });

  group('replayed per script', () {
    test('one word read in both scripts has a Read of each', () {
      final replayed = replayReviews(<LoggedReview>[
        review(DrillMode.recognition, script: devanagari, asked: Ask.own),
        review(
          DrillMode.recognition,
          script: persoArabic,
          asked: Ask.own,
          at: day.add(const Duration(days: 1)),
        ),
        review(
          DrillMode.production,
          script: persoArabic,
          asked: Ask.own,
          at: day.add(const Duration(days: 2)),
        ),
      ], skills: map);
      expect(replayed.scriptStates.keys.toSet(), <ScriptKey>{
        (cardId: 'hi-0001', mode: DrillMode.readScript, script: devanagari),
        (cardId: 'hi-0001', mode: DrillMode.readScript, script: persoArabic),
        (cardId: 'hi-0001', mode: DrillMode.writeScript, script: persoArabic),
      });
      expect(replayed.scriptEvents.map((e) => e.share), <double>[
        0.5,
        0.5,
        0.5,
      ]);
      expect(replayed.scriptEvents.map((e) => e.script), <String>[
        devanagari,
        persoArabic,
        persoArabic,
      ]);
    });

    test('half a review elsewhere, a whole one in a script deck', () {
      final half = replayReviews(<LoggedReview>[
        review(DrillMode.recognition, script: devanagari, asked: Ask.own),
      ], skills: map);
      final whole = replayReviews(<LoggedReview>[
        review(
          DrillMode.recognition,
          deck: letters,
          script: devanagari,
          asked: Ask.own,
        ),
      ], skills: map);
      const key = (
        cardId: 'hi-0001',
        mode: DrillMode.readScript,
        script: devanagari,
      );
      expect(
        half.scriptStates[key]!.stability,
        closeTo(whole.scriptStates[key]!.stability / 2, 1e-9),
      );
    });

    test('only whole reviews are fitted: skillLog leaves the halves out', () {
      final progress = MemoryProgress()..skills = map;
      progress
        ..record(
          deckId: words,
          cardId: 'hi-0001',
          mode: DrillMode.recognition,
          grade: 4,
          now: day,
          script: devanagari,
          asked: Ask.own,
        )
        ..record(
          deckId: letters,
          cardId: 'hi-0002',
          mode: DrillMode.recognition,
          grade: 4,
          now: day,
          script: devanagari,
          asked: Ask.own,
        );
      expect(progress.scriptLog, hasLength(2));
      expect(progress.skillLog, hasLength(3));
    });
  });

  group('kept in the log', () {
    test('a backup keeps the script and the way of asking', () {
      final text = LogJsonl.encode(<LoggedReview>[
        review(DrillMode.production, script: persoArabic, asked: Ask.rearrange),
        review(DrillMode.recognition),
      ], const []);
      final back = LogJsonl.decode(text).reviews;
      expect(back.first.script, persoArabic);
      expect(back.first.asked, Ask.rearrange);
      expect(back.last.script, isNull);
      expect(back.last.asked, isNull);
    });

    test('the database keeps them, and replays them', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final log = ReviewLog(db);
      await log.record(
        deckId: words,
        cardId: 'hi-0001',
        mode: DrillMode.production,
        grade: 4,
        now: day,
        answerGiven: 'کتاب',
        script: persoArabic,
        asked: Ask.own,
      );
      final reviews = await log.reviews();
      expect(reviews.single.script, persoArabic);
      expect(reviews.single.asked, Ask.own);
      final events = await log.events();
      expect(events.single.script, persoArabic);
      expect(events.single.asked, Ask.own);
    });

    test(
      'a version 8 database gains the columns and keeps its reviews',
      () async {
        final dir = Directory.systemTemp.createTempSync('fluenough');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/v8.sqlite');
        final old = AppDatabase(NativeDatabase(file));
        await ReviewLog(old).record(
          deckId: letters,
          cardId: 'hi-0001',
          mode: DrillMode.recognition,
          grade: 4,
          now: day,
        );
        for (final column in <String>['script', 'asked']) {
          await old.customStatement('ALTER TABLE reviews DROP COLUMN $column');
        }
        await old.customStatement('PRAGMA user_version = 8');
        await old.close();

        final upgraded = AppDatabase(NativeDatabase(file));
        addTearDown(upgraded.close);
        final reviews = await ReviewLog(upgraded).reviews();
        expect(reviews, hasLength(1));
        expect(reviews.single.script, isNull);
        expect(reviews.single.asked, isNull);
        // Older script-deck history goes to the primary script.
        expect(map.scriptOf(reviews.single)?.script, devanagari);
      },
    );
  });

  group('Progress', () {
    test('shows Read and Write per script, in the order first answered', () {
      final progress = MemoryProgress()..skills = map;
      void answer(DrillMode mode, String script, int hours) => progress.record(
        deckId: words,
        cardId: 'hi-0001',
        mode: mode,
        grade: 4,
        now: day.add(Duration(hours: hours)),
        answerGiven: mode == DrillMode.recognition ? null : 'x',
        script: script,
        asked: Ask.own,
      );
      answer(DrillMode.production, persoArabic, 0);
      answer(DrillMode.recognition, devanagari, 1);
      answer(DrillMode.recognition, persoArabic, 2);
      final n = StatsNumbers.of(
        progress,
        now: day.add(const Duration(days: 1)),
        range: StatsRange.all,
        cardOf: (id, {deckId}) => null,
      );
      expect(n.scriptSkills.keys, <ScriptSkill>[
        (script: persoArabic, mode: DrillMode.readScript),
        (script: persoArabic, mode: DrillMode.writeScript),
        (script: devanagari, mode: DrillMode.readScript),
      ]);
      expect(n.reviews, 3);
    });
  });

  group('the drill session keeps the learned script', () {
    Future<AppState> hindustani(Set<String> scripts) async {
      final state = AppState.test(
        decks: MemoryDeckSource(twoScriptCourse()),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi'],
          learningChosen: true,
          scriptsLearned: <String, Set<String>>{'hi': scripts},
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      return state;
    }

    Future<AppState> readOnce(Set<String> scripts) async {
      final state = await hindustani(scripts);
      final card = state.decks.firstWhere((e) => e.id == words).cards.first;
      final session = DrillSession(
        state: state,
        items: <SessionItem>[
          SessionItem(card: card, mode: DrillMode.recognition, state: null),
        ],
      );
      addTearDown(session.dispose);
      session
        ..reveal()
        ..rate(SelfGrade.good);
      return state;
    }

    test('a word read in Perso-Arabic is Perso-Arabic Read', () async {
      final state = await readOnce(<String>{persoArabic});
      final last = state.progress.log.last;
      expect(last.script, persoArabic);
      expect(last.asked, Ask.own);
      expect(state.progress.scriptLog.single.mode, DrillMode.readScript);
      expect(state.progress.scriptLog.single.script, persoArabic);
      expect(state.progress.scriptLog.single.share, SkillMap.implied);
    });

    test('a word read in Devanagari is Devanagari Read', () async {
      final state = await readOnce(<String>{devanagari});
      expect(state.progress.log.last.script, devanagari);
      expect(state.progress.scriptLog.single.script, devanagari);
    });

    test('without the script learned, nothing feeds a script skill', () async {
      final state = await readOnce(const <String>{});
      expect(state.progress.log.last.script, isNull);
      expect(state.progress.scriptLog, isEmpty);
    });
  });
}
