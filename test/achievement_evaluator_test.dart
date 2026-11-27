// The achievements as rules over the review log (#322): levels, word counts,
// the Start and Master of each skill, sets, first lesson, streaks and answer
// counts, each worked out from in-memory logs. A card counts once it has been
// known at any time (decision 1), so a later lapse never takes a badge away
// and the date a badge is earned is the first time its rule was met.

import 'package:fluenough/app/achievements_holder.dart';
import 'package:fluenough/core/achievements/achievement.dart';
import 'package:fluenough/core/achievements/achievement_evaluator.dart';
import 'package:fluenough/core/achievements/achievement_facts.dart';
import 'package:fluenough/core/achievements/known_history.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/progress/recent_answers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/achievement_fixture.dart';

final DateTime _start = DateTime.utc(2026, 3, 2);

AchievementReport _evaluate(
  FixtureLog log,
  AchievementFacts? facts, {
  Map<String, DateTime> earnedBefore = const <String, DateTime>{},
}) => evaluateAchievements(
  log: log.events,
  facts: facts,
  earnedBefore: earnedBefore,
);

/// Whether [id] is a passage's question of the fixture's reading deck.
bool _isQuestion(String id) => id.startsWith('zz-q');

/// Knows each of [ids] in turn, one a day from day [from]; a passage's
/// question is answered right once instead. The card at index i is known at
/// day from + i + 1.
void _knowAll(FixtureLog log, Iterable<String> ids, {int from = 0}) {
  var day = from;
  for (final id in ids) {
    if (_isQuestion(id)) {
      log.answer(id, log.day(day), mode: DrillMode.reading);
    } else {
      log.know(id, day);
    }
    day++;
  }
}

/// Knows [ids] in [mode], one a day from day [from].
void _knowIn(
  FixtureLog log,
  Iterable<String> ids,
  DrillMode mode, {
  int from = 0,
}) {
  var day = from;
  for (final id in ids) {
    log.know(id, day, mode: mode);
    day++;
  }
}

void main() {
  group('the catalogue of a course', () {
    final facts = courseFacts();
    final report = _evaluate(FixtureLog(_start), facts);

    test('lists every category the mockup draws', () {
      int count(AchievementKind kind) => report.ofKind(kind).length;
      expect(count(AchievementKind.level), 3);
      expect(count(AchievementKind.wordCount), 4);
      expect(count(AchievementKind.skillStart), 4);
      expect(count(AchievementKind.skillMaster), 4);
      expect(count(AchievementKind.deckSet), 2);
      // First lesson, five streaks and two answer counts.
      expect(count(AchievementKind.other), 8);
      expect(report.results, hasLength(25));
    });

    test('every badge is locked and nothing earned with no answers', () {
      for (final r in report.results) {
        expect(r.status, AchievementStatus.locked, reason: r.def.id);
        expect(r.earnedAt, isNull, reason: r.def.id);
      }
      expect(report.earned, isEmpty);
    });

    test('is in the order of the path, the badges off it last', () {
      final positions = <int>[
        for (final r in report.results)
          if (r.def.position != null) r.def.position!,
      ];
      expect(positions, hasLength(17));
      expect(positions, orderedEquals(<int>[...positions]..sort()));
      final others = report.results.skip(17).map((r) => r.def.kind);
      expect(others.every((k) => k == AchievementKind.other), isTrue);
    });

    test('the app-wide badges alone, with no language', () {
      final app = _evaluate(FixtureLog(_start), null);
      expect(app.results.map((r) => r.def.id), <String>[
        'other-streak-3',
        'other-streak-7',
        'other-streak-30',
        'other-streak-100',
        'other-streak-365',
        'other-answers-1000',
        'other-answers-10000',
      ]);
    });
  });

  group('levels', () {
    test('A1 is earned when every card up to its mark has been known, dated '
        'when the last was', () {
      final facts = courseFacts();
      final ids = facts.cardIdsUpTo(20).toList();
      expect(ids, hasLength(46));
      final log = FixtureLog(_start);
      _knowAll(log, ids.take(45));
      var report = _evaluate(log, facts);
      final partial = report['level-a1']!;
      expect(partial.status, AchievementStatus.inProgress);
      expect((partial.have, partial.need), (45, 46));
      expect(partial.earnedAt, isNull);
      // A2 asks for the 40 units, so it is further off.
      expect(report['level-a2']!.status, AchievementStatus.inProgress);
      expect(report['level-a2']!.need, 86);

      _knowAll(log, ids.skip(45), from: 45);
      report = _evaluate(log, facts);
      final done = report['level-a1']!;
      expect(done.status, AchievementStatus.earned);
      expect(done.earnedAt, log.day(45));
      expect(report['level-a2']!.status, AchievementStatus.inProgress);
    });

    test('a card counts once it has been known: a later lapse never takes '
        'the level away, and its date stays', () {
      final facts = courseFacts();
      final ids = facts.cardIdsUpTo(20).toList();
      final log = FixtureLog(_start);
      _knowAll(log, ids);
      final before = _evaluate(log, facts)['level-a1']!;
      expect(before.earnedAt, log.day(45));

      // Month later the first letter is forgotten.
      log.answer(ids.first, log.day(120), grade: 0);
      final known = RecentAnswers(log.events).of(ids.first);
      expect(known.level, MasteryLevel.learning, reason: 'lapsed now');
      final after = _evaluate(log, facts)['level-a1']!;
      expect(after.status, AchievementStatus.earned);
      expect(after.earnedAt, before.earnedAt);
    });

    test('a card known, forgotten and known again is dated its first', () {
      final facts = courseFacts();
      final log = FixtureLog(_start);
      log.know('zz-301', 2);
      log.answer('zz-301', log.day(40), grade: 0);
      log.know('zz-301', 60);
      final history = KnownHistory.of(log.events);
      expect(history.cardKnownAt('zz-301'), log.day(3));
      // The family set holds that card and three more.
      _knowAll(log, <String>['zz-302', 'zz-401', 'zz-402'], from: 100);
      final family = _evaluate(log, facts)['set-family']!;
      expect(family.earnedAt, log.day(103));
    });

    test('placement credit is no knowledge and no lesson', () {
      final facts = courseFacts();
      final log = FixtureLog(_start);
      log.credit('zz-201', log.day(1));
      final report = _evaluate(log, facts);
      expect(report['other-first-lesson']!.status, AchievementStatus.locked);
      expect(report['other-answers-1000']!.have, 0);
      expect(report['level-a1']!.have, 0);
    });
  });

  group('word counts', () {
    test('100 words is earned at the moment the 100th word was known', () {
      final facts = courseFacts();
      final words = <String>[
        for (var unit = 2; unit <= 60; unit++) ...unitCards(unit),
      ];
      final log = FixtureLog(_start);
      _knowAll(log, words.take(99));
      var report = _evaluate(log, facts);
      expect(report['words-100']!.status, AchievementStatus.inProgress);
      expect(report['words-100']!.have, 99);

      _knowAll(log, words.skip(99).take(1), from: 99);
      report = _evaluate(log, facts);
      final hundred = report['words-100']!;
      expect(hundred.status, AchievementStatus.earned);
      expect(hundred.earnedAt, log.day(100));
      expect(report['words-500']!.status, AchievementStatus.inProgress);
      expect(report['words-500']!.have, 100);
    });

    test('a letter is no word', () {
      final facts = courseFacts();
      final log = FixtureLog(_start);
      _knowAll(log, letterIds());
      expect(_evaluate(log, facts)['words-100']!.have, 0);
    });
  });

  group('skills', () {
    test('Hear Start: 10 audio cards answered right', () {
      final facts = courseFacts();
      final cards = <String>[
        for (var unit = 2; unit <= 6; unit++) ...unitCards(unit),
      ];
      final log = FixtureLog(_start);
      for (final (i, id) in cards.take(9).indexed) {
        log.answer(id, log.day(i), mode: DrillMode.listening);
      }
      // A wrong answer is no audio card answered.
      log.answer(cards[9], log.day(9), mode: DrillMode.listening, grade: 0);
      var start = _evaluate(log, facts)['skill-hear-start']!;
      expect(start.status, AchievementStatus.inProgress);
      expect(start.have, 9);

      log.answer(cards[9], log.day(10), mode: DrillMode.listening);
      start = _evaluate(log, facts)['skill-hear-start']!;
      expect(start.status, AchievementStatus.earned);
      expect(start.earnedAt, log.day(10));
    });

    test('Speak Start: one answer said aloud and heard', () {
      final facts = courseFacts();
      final log = FixtureLog(_start);
      log.answer('zz-201', log.day(1), mode: DrillMode.speaking, grade: 0);
      expect(
        _evaluate(log, facts)['skill-speak-start']!.status,
        AchievementStatus.locked,
      );
      log.answer('zz-201', log.day(2), mode: DrillMode.speaking);
      final start = _evaluate(log, facts)['skill-speak-start']!;
      expect(start.status, AchievementStatus.earned);
      expect(start.earnedAt, log.day(2));
    });

    test('Read Start and Write Start: the first 5 letters known, each in its '
        'own skill', () {
      final facts = courseFacts();
      final log = FixtureLog(_start);
      _knowIn(log, letterIds().take(4), DrillMode.recognition);
      _knowIn(log, letterIds().take(5), DrillMode.production);
      var report = _evaluate(log, facts);
      const read = 'skill-read-devanagari-start';
      const write = 'skill-write-devanagari-start';
      expect(report[read]!.status, AchievementStatus.inProgress);
      expect(report[read]!.have, 4);
      expect(report[write]!.status, AchievementStatus.earned);
      expect(report[write]!.earnedAt, log.day(5));

      log.know(letterIds()[4], 20);
      report = _evaluate(log, facts);
      expect(report[read]!.status, AchievementStatus.earned);
      expect(report[read]!.earnedAt, log.day(21));
    });

    test('Read Master: every script and word card up to the A1 mark known '
        'in Read; Write Master waits for Write', () {
      final facts = courseFacts();
      final cards = facts
          .cardIdsUpTo(20)
          .where((id) => !_isQuestion(id))
          .toList();
      expect(cards, hasLength(44));
      final log = FixtureLog(_start);
      _knowIn(log, cards.take(43), DrillMode.recognition);
      var report = _evaluate(log, facts);
      const master = 'skill-read-devanagari-master';
      expect(report[master]!.status, AchievementStatus.inProgress);
      expect((report[master]!.have, report[master]!.need), (43, 44));
      expect(
        report['skill-write-devanagari-master']!.status,
        AchievementStatus.locked,
      );

      _knowIn(log, cards.skip(43), DrillMode.recognition, from: 43);
      report = _evaluate(log, facts);
      expect(report[master]!.status, AchievementStatus.earned);
      expect(report[master]!.earnedAt, log.day(44));
    });

    test('Hear Master: every card up to the A2 mark known in Hear', () {
      final facts = courseFacts();
      final cards = facts
          .cardIdsUpTo(40)
          .where((id) => !_isQuestion(id))
          .toList();
      expect(cards, hasLength(84));
      final log = FixtureLog(_start);
      _knowIn(log, cards.take(83), DrillMode.listening);
      var report = _evaluate(log, facts);
      expect(report['skill-hear-master']!.status, AchievementStatus.inProgress);
      _knowIn(log, cards.skip(83), DrillMode.listening, from: 83);
      report = _evaluate(log, facts);
      expect(report['skill-hear-master']!.status, AchievementStatus.earned);
      expect(report['skill-hear-master']!.earnedAt, log.day(84));
    });

    test('a skill marked Leave is shown but never earned', () {
      final left = <SkillKey>{const SkillKey(SkillKind.hear)};
      final facts = courseFacts(leave: left);
      final cards = <String>[
        for (var unit = 2; unit <= 6; unit++) ...unitCards(unit),
      ];
      final log = FixtureLog(_start);
      for (final (i, id) in cards.indexed) {
        log.answer(id, log.day(i), mode: DrillMode.listening);
      }
      final report = _evaluate(log, facts);
      final start = report['skill-hear-start']!;
      expect(start.earnable, isFalse);
      expect(start.status, AchievementStatus.locked);
      expect(start.earnedAt, isNull);
      expect(report['skill-hear-master']!.earnable, isFalse);
      expect(report['skill-speak-start']!.earnable, isTrue);
      // The same answers earn it once the skill is no longer left.
      final back = _evaluate(log, courseFacts());
      expect(back['skill-hear-start']!.status, AchievementStatus.earned);
    });

    test('a sign language has Gestures: 10 signs recognised and made', () {
      const gesture = SkillKey(SkillKind.gesture);
      final facts = courseFacts(skills: const <SkillKey>[gesture]);
      final report = _evaluate(FixtureLog(_start), facts);
      expect(report['skill-gesture-start'], isNotNull);
      expect(report['skill-gesture-master'], isNotNull);
      expect(report['skill-hear-start'], isNull);
      expect(report['skill-read-devanagari-start'], isNull);

      final signs = <String>[
        for (var unit = 2; unit <= 6; unit++) ...unitCards(unit),
      ];
      final log = FixtureLog(_start);
      // Recognised only: no sign is made yet.
      _knowIn(log, signs, DrillMode.recognition);
      expect(
        _evaluate(log, facts)['skill-gesture-start']!.status,
        AchievementStatus.locked,
      );
      _knowIn(log, signs.take(9), DrillMode.production);
      var start = _evaluate(log, facts)['skill-gesture-start']!;
      expect(start.status, AchievementStatus.inProgress);
      expect(start.have, 9);
      _knowIn(log, signs.skip(9), DrillMode.production, from: 9);
      start = _evaluate(log, facts)['skill-gesture-start']!;
      expect(start.status, AchievementStatus.earned);
      // The tenth sign is known in both from day 10.
      expect(start.earnedAt, log.day(10));
    });
  });

  group('sets', () {
    test('a word set is mastered when every card of its decks is known', () {
      final facts = courseFacts();
      final log = FixtureLog(_start);
      _knowAll(log, <String>['zz-301', 'zz-302', 'zz-401']);
      var family = _evaluate(log, facts)['set-family']!;
      expect(family.status, AchievementStatus.inProgress);
      expect((family.have, family.need), (3, 4));

      _knowAll(log, <String>['zz-402'], from: 10);
      family = _evaluate(log, facts)['set-family']!;
      expect(family.status, AchievementStatus.earned);
      expect(family.earnedAt, log.day(11));
    });

    test('a grammar table counts its reading deck: a question answered right '
        'is as far as it goes', () {
      final facts = courseFacts();
      final log = FixtureLog(_start);
      _knowAll(log, unitCards(20));
      // A wrong answer to a question does not count, a right one does.
      log.answer('zz-q1', log.day(5), mode: DrillMode.reading, grade: 0);
      log.answer('zz-q1', log.day(6), mode: DrillMode.reading);
      var past = _evaluate(log, facts)['set-past']!;
      expect(past.status, AchievementStatus.inProgress);
      expect((past.have, past.need), (3, 4));

      log.answer('zz-q2', log.day(8), mode: DrillMode.reading);
      past = _evaluate(log, facts)['set-past']!;
      expect(past.status, AchievementStatus.earned);
      expect(past.earnedAt, log.day(8));
    });

    test('a language that chooses no sets has an empty Sets category', () {
      final facts = courseFacts(sets: const []);
      final report = _evaluate(FixtureLog(_start), facts);
      expect(report.ofKind(AchievementKind.deckSet), isEmpty);
      expect(report.ofKind(AchievementKind.level), hasLength(3));
    });
  });

  group('first lesson, streaks and answers', () {
    test('the first lesson is the first answer in the language, whatever '
        'was answered in another', () {
      final facts = courseFacts();
      final log = FixtureLog(_start);
      log.answer('yy-1', log.day(1));
      expect(
        _evaluate(log, facts)['other-first-lesson']!.status,
        AchievementStatus.locked,
      );
      log.answer('zz-201', log.day(3));
      final lesson = _evaluate(log, facts)['other-first-lesson']!;
      expect(lesson.status, AchievementStatus.earned);
      expect(lesson.earnedAt, log.day(3));
    });

    test('a streak counts days in a row in any language, dated the day it '
        'was reached', () {
      final log = FixtureLog(_start);
      for (var d = 0; d < 8; d++) {
        log.answer(d.isEven ? 'yy-1' : 'zz-201', log.day(d, 20));
      }
      final report = _evaluate(log, null);
      expect(report['other-streak-3']!.earnedAt, log.day(2, 20));
      expect(report['other-streak-7']!.earnedAt, log.day(6, 20));
      final thirty = report['other-streak-30']!;
      expect(thirty.status, AchievementStatus.inProgress);
      expect(thirty.have, 8);
    });

    test('a gap starts the run again, and an earned streak stays', () {
      final log = FixtureLog(_start);
      for (final d in <int>[0, 1, 3, 4, 5, 6, 7, 8, 9]) {
        log.answer('zz-201', log.day(d));
      }
      final report = _evaluate(log, null);
      expect(report['other-streak-3']!.earnedAt, log.day(5));
      expect(report['other-streak-7']!.earnedAt, log.day(9));
      // Quiet for weeks: nothing is taken back.
      log.answer('zz-201', log.day(60));
      final later = _evaluate(log, null);
      expect(later['other-streak-7']!.earnedAt, log.day(9));
    });

    test('1,000 answers is dated the 1,000th; placement credit is not an '
        'answer', () {
      final log = FixtureLog(_start);
      for (var i = 0; i < 5; i++) {
        log.credit('zz-20$i', log.day(0, 8));
      }
      for (var i = 0; i < 999; i++) {
        log.answer('yy-1', log.day(0, 10).add(Duration(minutes: i)));
      }
      var thousand = _evaluate(log, null)['other-answers-1000']!;
      expect(thousand.status, AchievementStatus.inProgress);
      expect(thousand.have, 999);

      final last = log.day(0, 10).add(const Duration(minutes: 999));
      log.answer('yy-1', last);
      final report = _evaluate(log, null);
      thousand = report['other-answers-1000']!;
      expect(thousand.earnedAt, last);
      final ten = report['other-answers-10000']!;
      expect(ten.status, AchievementStatus.inProgress);
    });
  });

  group('never taking a badge back', () {
    test('evaluating again changes nothing, and earnedBefore keeps a badge '
        'even when its deck has grown', () {
      final facts = courseFacts();
      final ids = facts.cardIdsUpTo(20).toList();
      final log = FixtureLog(_start);
      _knowAll(log, ids);
      final first = _evaluate(log, facts);
      final again = _evaluate(log, facts);
      expect(again.earnedDates, first.earnedDates);
      expect(first.earnedDates, contains('level-a1'));

      // A new letter joins the A1 decks, which nobody has met yet.
      final grown = courseFacts(extraCardsInUnitOne: 1);
      final plain = _evaluate(log, grown);
      expect(plain['level-a1']!.status, AchievementStatus.inProgress);
      final kept = _evaluate(log, grown, earnedBefore: first.earnedDates);
      expect(kept['level-a1']!.status, AchievementStatus.earned);
      expect(kept['level-a1']!.earnedAt, first['level-a1']!.earnedAt);
    });

    test('the earned badges are listed earliest first', () {
      final facts = courseFacts();
      final log = FixtureLog(_start);
      log.answer('zz-201', log.day(6), mode: DrillMode.speaking);
      _knowAll(log, <String>['zz-301', 'zz-302', 'zz-401', 'zz-402']);
      final earned = _evaluate(log, facts).earned;
      final ids = earned.map((r) => r.def.id);
      const order = <String>['set-family', 'skill-speak-start'];
      expect(ids, containsAllInOrder(order));
      final dates = earned.map((r) => r.earnedAt!).toList();
      expect(dates, orderedEquals(<DateTime>[...dates]..sort()));
    });
  });

  group('the known rule', () {
    test('is the known rule of Progress, replayed over the log', () {
      final log = FixtureLog(_start);
      log.know('zz-201', 0);
      log.know('zz-201', 0, mode: DrillMode.production);
      log.know('zz-202', 0);
      log.credit('zz-302', log.day(1));
      final history = KnownHistory.of(log.events);
      final progress = RecentAnswers(log.events);
      bool knownNow(String id) => progress.of(id).level == MasteryLevel.known;
      expect(knownNow('zz-201'), isTrue);
      expect(history.cardKnownAt('zz-201'), log.day(1));
      expect(knownNow('zz-202'), isTrue);
      expect(history.cardKnownAt('zz-202'), log.day(1));
      expect(knownNow('zz-302'), isFalse);
      expect(history.cardKnownAt('zz-302'), isNull);
    });

    test('keeps what Progress forgets: a card once known, later lapsed or '
        'begun in a new skill, still counts', () {
      final log = FixtureLog(_start);
      log.know('zz-301', 0);
      log.answer('zz-301', log.day(30), grade: 0);
      log.know('zz-202', 0);
      log.answer('zz-202', log.day(5), mode: DrillMode.production);
      final history = KnownHistory.of(log.events);
      final progress = RecentAnswers(log.events);
      expect(progress.of('zz-301').level, MasteryLevel.learning);
      expect(history.cardKnownAt('zz-301'), log.day(1));
      expect(progress.of('zz-202').level, MasteryLevel.learning);
      expect(history.cardKnownAt('zz-202'), log.day(1));
    });

    test('on an isolate the report is the one worked out in place', () async {
      final facts = courseFacts();
      final log = FixtureLog(_start);
      _knowAll(log, facts.cardIdsUpTo(20));
      log.answer('yy-1', log.day(3));
      final job = AchievementJob(
        language: 'zz',
        facts: facts,
        log: log.events,
        parameters: const <DrillMode, List<double>>{},
      );
      final inPlace = await achievementsInPlace(job);
      final onIsolate = await achievementsInIsolate(job);
      List<Object?> shown(AchievementReport r) => <Object?>[
        for (final x in r.results)
          (x.def.id, x.status, x.have, x.need, x.earnedAt),
      ];
      expect(shown(onIsolate), shown(inPlace));
      expect(inPlace['level-a1']!.status, AchievementStatus.earned);
    });
  });
}
