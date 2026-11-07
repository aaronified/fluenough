// The level and the placement write after the placed layer (owner,
// 2026-11-07): the V3 readout is written by its lower edge, never above what
// was proven, and a skill that was not tested or only self-rated writes
// nothing and never pulls the course's placed decks down; the level is
// "Placed" until a unit of its milestone has an earned review; the tiles say
// "+M placed"; and a real answer is never written in the shape of credit.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/placement_run_setup.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placed_outcome.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/progress/mastery.dart';
import 'package:fluenough/core/progress/unlocks.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:fluenough/features/stats/progress_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

JointItem _item(
  PlacementSkill skill,
  int deck,
  String card, {
  bool selfRated = false,
}) => JointItem(
  skills: <PlacementSkill>{skill},
  deck: deck,
  slip: 0.05,
  guess: 0.25,
  selfRated: selfRated,
  cardId: card,
);

/// Four clean right answers at [deck] for [skill]: a proven band.
void _prove(JointPlacement m, PlacementSkill skill, int deck) {
  for (var i = 0; i < 4; i++) {
    m.observe(_item(skill, deck, '$skill-$deck-$i'), AnswerOutcome.right);
  }
}

void main() {
  group('the V3 readout as the placement write reads it', () {
    final levels = PlacementLevels(100, maxParts: 20);

    test('a scored skill is placed at its lower edge, never above what was '
        'proven', () {
      final m = JointPlacement(
        levels: levels,
        skills: const <PlacementSkill>[PlacementSkill.read],
      );
      _prove(m, PlacementSkill.read, 40);
      final readout = m.readout();
      final a = assurancesFromJoint(readout, levels)[PlacementSkill.read]!;
      final r = readout.skills[PlacementSkill.read]!;
      expect(a.label, isNot(AssuranceLabel.notTested));
      expect(a.label, isNot(AssuranceLabel.verified));
      expect(a.placedClass, r.startClass);
      expect(a.placedClass, lessThanOrEqualTo(r.provenClass!));
      expect(a.placedLevel, levels.levelOf(r.startClass));
      expect(a.questions, 4);
    });

    test('a skill with no proven band is placed at the start, however sure '
        'the posterior', () {
      final m = JointPlacement(
        levels: levels,
        skills: const <PlacementSkill>[PlacementSkill.read],
      );
      for (var i = 0; i < 3; i++) {
        m.observe(_item(PlacementSkill.read, 70, 'c$i'), AnswerOutcome.right);
      }
      final a = assurancesFromJoint(m.readout(), levels)[PlacementSkill.read]!;
      expect(a.placedClass, 0);
      expect(a.placedLevel, -1);
    });

    test('Say that was only self-rated, and a skill never asked, are not '
        'tested: no level, no label', () {
      final m = JointPlacement(
        levels: levels,
        skills: const <PlacementSkill>[
          PlacementSkill.read,
          PlacementSkill.hear,
          PlacementSkill.say,
        ],
      );
      _prove(m, PlacementSkill.read, 40);
      for (var i = 0; i < 6; i++) {
        m.observe(
          _item(PlacementSkill.say, 90, 'say$i', selfRated: true),
          AnswerOutcome.right,
        );
      }
      final out = assurancesFromJoint(m.readout(), levels);
      expect(out[PlacementSkill.read]!.label, isNot(AssuranceLabel.notTested));
      for (final skill in <PlacementSkill>[
        PlacementSkill.say,
        PlacementSkill.hear,
      ]) {
        expect(out[skill]!.label, AssuranceLabel.notTested, reason: skill.name);
        expect(out[skill]!.placedLevel, -1, reason: skill.name);
        expect(out[skill]!.questions, 0, reason: skill.name);
      }
    });
  });

  group('the write at the end of a V3 run', () {
    late AppState state;
    late PlacementRunPlan plan;
    late PlacementLevels levels;

    setUp(() async {
      state = AppState.test();
      await state.load();
      plan = state.placementRunPlan('hi')!;
      levels = PlacementLevels(plan.data.deckCount, maxParts: 20);
    });
    tearDown(() => state.dispose());

    test('Say self-rated does not pull the placed decks down, and credits '
        'nothing in its own drills', () {
      final m = JointPlacement(
        levels: levels,
        skills: const <PlacementSkill>[
          PlacementSkill.read,
          PlacementSkill.write,
          PlacementSkill.say,
        ],
      );
      final deck = plan.data.deckCount ~/ 3;
      _prove(m, PlacementSkill.read, deck);
      _prove(m, PlacementSkill.write, deck);
      for (var i = 0; i < 4; i++) {
        m.observe(
          _item(PlacementSkill.say, deck, 'say$i', selfRated: true),
          AnswerOutcome.right,
        );
      }
      final readout = m.readout();
      final floor = <int>[
        readout.skills[PlacementSkill.read]!.startClass,
        readout.skills[PlacementSkill.write]!.startClass,
      ].reduce((a, b) => a < b ? a : b);
      expect(floor, greaterThan(0), reason: 'a proven band places above none');

      state.writePlacementJoint('hi', plan, readout, levels);

      // The decks up to the lower of Read and Write's edges are placed; had
      // Say counted at its unplaced level, nothing would be.
      expect(state.settings.placedDecks, contains(plan.decks.first.id));
      final top = levels.levelOf(floor);
      expect(state.settings.placedDecks, contains(plan.decks[top].id));
      final labels = state.settings.skillLabelsOf('hi');
      expect(labels.containsKey('read'), isTrue);
      expect(labels.containsKey('say'), isFalse);
      for (final card in plan.decks.first.cards) {
        expect(
          state.progress.stateOf(card.id, DrillMode.speaking),
          isNull,
          reason: 'Say was not placed from a self-rating',
        );
      }
    });

    test('nothing proven writes nothing above the start', () {
      final m = JointPlacement(
        levels: levels,
        skills: const <PlacementSkill>[PlacementSkill.read],
      );
      for (var i = 0; i < 3; i++) {
        m.observe(_item(PlacementSkill.read, 60, 'c$i'), AnswerOutcome.right);
      }
      state.writePlacementJoint('hi', plan, m.readout(), levels);
      expect(
        state.settings.placedDecks.where(
          (id) => plan.decks.any((d) => d.id == id),
        ),
        isEmpty,
      );
    });
  });

  group('a real answer is never credit-shaped', () {
    test(
      'AppState.record gives a grade 5 with no time the smallest time',
      () async {
        final state = AppState.test(
          decks: MemoryDeckSource(<String, String>{
            'decks/es/es-en-tiny.yaml': '''
schema: 1
id: es-en-tiny
name: "Tiny"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: es-en-tiny-0001, target: "hola", native: "hello" }
''',
          }),
        );
        addTearDown(state.dispose);
        await state.load();
        final item = state
            .buildSession(DrillRequest.deck('es-en-tiny'))
            .items
            .first;
        final event = state.record(item, 5);
        expect(event.hasCreditShape, isFalse);
        expect(event.isPlaced, isFalse);
        expect(event.elapsed, const Duration(microseconds: 1));
        // A time that was taken is kept as it was.
        final other = state.record(
          item,
          5,
          elapsed: const Duration(seconds: 3),
        );
        expect(other.elapsed, const Duration(seconds: 3));
        expect(other.isPlaced, isFalse);
      },
    );

    test('placement credit is still written in that shape', () async {
      final p = MemoryProgress();
      final e = p.record(
        deckId: 'xx-words',
        cardId: 'a',
        mode: DrillMode.recognition,
        grade: 5,
        now: DateTime(2026, 9, 1),
        asked: Ask.own,
      );
      expect(e.hasCreditShape, isTrue);
      expect(e.isPlaced, isTrue);
    });
  });

  group('script skills from placed word reviews', () {
    final at = DateTime(2026, 9, 1, 9);
    const map = SkillMap(
      scriptDecks: <String>{'xx-alpha'},
      primaryScripts: <String, String>{'xx': 'xx-script'},
    );

    LoggedReview review(
      String deck,
      String card, {
      Duration elapsed = Duration.zero,
      String? script,
    }) => (
      key: (cardId: card, mode: DrillMode.recognition),
      deckId: deck,
      at: at,
      grade: 5,
      elapsed: elapsed,
      answerGiven: null,
      script: script,
      asked: Ask.own,
    );

    Mastery scripts(List<LoggedReview> reviews) {
      final replayed = replayReviews(reviews, skills: map);
      return masteryAt(
        replayed.events,
        replayed.scriptEvents,
        totals: const <MasterySkill, int>{MasterySkill.script: 10},
        scriptCards: <String>{for (final r in reviews) r.key.cardId},
      );
    }

    test('a word credit has no script, so it feeds no script skill', () {
      final replayed = replayReviews(<LoggedReview>[
        review('xx-words', 'a'),
      ], skills: map);
      expect(replayed.scriptEvents, isEmpty);
    });

    test('a script deck\'s credit is a PLACED script pair: placement placed '
        'the script, so it is fine, and counted as placed', () {
      final star = scripts(<LoggedReview>[
        review('xx-alpha', 'a', script: 'xx-script'),
      ])[MasterySkill.script];
      expect(star.placed, 1);
      expect(star.taught, 0);
      expect(star.known, 0);
    });

    test('a real word review shown in the script feeds the script skill at '
        'half a review, earned, never placed', () {
      final star = scripts(<LoggedReview>[
        review(
          'xx-words',
          'a',
          elapsed: const Duration(seconds: 3),
          script: 'xx-script',
        ),
      ])[MasterySkill.script];
      expect(star.placed, 0);
      expect(star.taught, 1);
    });
  });

  group('the level is placed until a unit of its milestone is earned', () {
    CoursePath path() => const CoursePath(
      id: 'xx-path',
      language: 'xx',
      native: 'en',
      units: <List<String>>[
        <String>['xx-en-a'],
        <String>['xx-en-b'],
        <String>['xx-en-c'],
      ],
      plan: <PlanUnit>[
        PlanUnit(decks: <String>['xx-en-a'], milestone: Milestone.a1),
        PlanUnit(decks: <String>['xx-en-b'], milestone: Milestone.a2),
        PlanUnit(decks: <String>['xx-en-c'], milestone: Milestone.b1),
      ],
    );
    final start = DateTime(2026, 9, 1, 9);

    test('credit alone: placed; an earned review in the milestone: not', () {
      final p = MemoryProgress()
        ..record(
          deckId: 'xx-en-a',
          cardId: 'a',
          mode: DrillMode.recognition,
          grade: 5,
          now: start,
          asked: Ask.own,
        );
      expect(levelPlaced(path(), Milestone.a1, p.log), isTrue);
      p.record(
        deckId: 'xx-en-a',
        cardId: 'b',
        mode: DrillMode.recognition,
        grade: 4,
        now: start,
        elapsed: const Duration(seconds: 3),
      );
      expect(levelPlaced(path(), Milestone.a1, p.log), isFalse);
    });

    test('each milestone looks at its own units', () {
      final p = MemoryProgress()
        ..record(
          deckId: 'xx-en-a',
          cardId: 'a',
          mode: DrillMode.recognition,
          grade: 4,
          now: start,
          elapsed: const Duration(seconds: 3),
        )
        ..record(
          deckId: 'xx-en-b',
          cardId: 'b',
          mode: DrillMode.recognition,
          grade: 5,
          now: start,
          asked: Ask.own,
        );
      expect(levelPlaced(path(), Milestone.a1, p.log), isFalse);
      expect(
        levelPlaced(path(), Milestone.a2, p.log),
        isTrue,
        reason: 'only credit in the A2 unit, whatever A1 earned',
      );
    });

    test('before A1 there is nothing placed', () {
      expect(levelPlaced(path(), null, const []), isFalse);
    });
  });

  group('the tiles say what is placed', () {
    Future<void> pumpTiles(
      WidgetTester tester, {
      required UnlockCounts counts,
      bool levelPlaced = false,
    }) async {
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        Scaffold(
          body: ProgressTiles(
            counts: counts,
            level: Milestone.a2,
            started: DateTime(2026, 8, 3),
            allLanguages: false,
            levelPlaced: levelPlaced,
          ),
        ),
      );
    }

    const counts = (
      wordsKnown: 312,
      wordsTaught: 540,
      rulesKnown: 14,
      rulesTaught: 22,
      sentencesOpen: 86,
      sentencesTotal: 210,
      wordsPlaced: 90,
      rulesPlaced: 6,
    );

    testWidgets('Words and Rules read "+M placed", the Level tile "Placed"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpTiles(tester, counts: counts, levelPlaced: true);
      expect(find.text('of 540 taught (+90 placed)'), findsOneWidget);
      expect(find.text('of 22 taught (+6 placed)'), findsOneWidget);
      expect(find.text('Placed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel('Words: 312 known of 540 taught, and 90 placed'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Level A2, placed, started')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('with nothing placed they read as before', (tester) async {
      await pumpTiles(
        tester,
        counts: (
          wordsKnown: 312,
          wordsTaught: 540,
          rulesKnown: 14,
          rulesTaught: 22,
          sentencesOpen: 86,
          sentencesTotal: 210,
          wordsPlaced: 0,
          rulesPlaced: 0,
        ),
      );
      expect(find.text('of 540 taught'), findsOneWidget);
      expect(find.text('of 22 taught'), findsOneWidget);
      expect(find.text('Placed'), findsNothing);
    });
  });
}
