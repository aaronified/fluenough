// The run controller of "Find my level" (wiki/Plan-Placement-V2.md, sections
// 1, 3, 5 and 7): what it asks next, how it checks a miss, when it stops, and
// the plan's published costs. The costs came from the plan's own simulation;
// where this controller differs the test says by how much and why.
import 'dart:math';

import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/placement_run.dart';
import 'package:fluenough/core/placement/question_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

const _read = PlacementSkill.read;
const _hear = PlacementSkill.hear;
const _say = PlacementSkill.say;
const _write = PlacementSkill.write;
const _script = PlacementSkill.script;

/// Bengali: every skill and one script.
const Set<PlacementSkill> _bengali = <PlacementSkill>{
  _read,
  _hear,
  _say,
  _write,
  _script,
};

PlacementRunConfig configFor(
  Set<PlacementSkill> skills, {
  PlacementDeclaration? declaration = PlacementDeclaration.expert,
  bool? expertTrack,
  int deckCount = 100,
  bool floorFirst = true,
  bool recheck = true,
  bool microphone = true,
  bool promote = true,
  bool verifiable = true,
  bool extraScript = false,
  List<int> grammarUnits = const <int>[],
  int seed = 0,
}) => PlacementRunConfig(
  deckCount: deckCount,
  skills: skills,
  declaration: declaration,
  expertTrack: expertTrack,
  floorFirst: floorFirst,
  recheckInPositioning: recheck,
  microphone: microphone,
  promoteToExpert: promote,
  pathCompleteToB1: verifiable,
  allDecksDownloaded: verifiable,
  extraScriptQuestion: extraScript,
  grammarUnitDecks: grammarUnits,
  seed: seed,
);

class Played {
  Played(this.run, this.reached);

  final PlacementRun run;

  /// The question number at which each skill was first placed in its most
  /// probable class with 95% or more.
  final Map<PlacementSkill, int> reached;

  int get asked => run.asked;

  List<String> get variants => <String>[
    for (final a in run.history) a.request.variant.label,
  ];
}

/// Plays a run to its end (or [cap] questions), answering with [oracle].
Played play(
  PlacementRunConfig config,
  bool Function(PlacementQuestionRequest) oracle, {
  int cap = 400,
}) {
  var run = PlacementRun(config);
  final reached = <PlacementSkill, int>{};
  while (!run.isDone && run.asked < cap) {
    run = run.answer(oracle(run.next!));
    for (final skill in config.tested) {
      if (reached.containsKey(skill)) continue;
      final found = run.readout[skill];
      if (found != null &&
          found.questions > 0 &&
          !found.lowerBound &&
          reachesTarget(found.mass)) {
        reached[skill] = run.asked;
      }
    }
  }
  return Played(run, reached);
}

/// A learner who answers everything right except the questions numbered in
/// [wrong] (1 is the first).
Played playWrong(PlacementRunConfig config, Set<int> wrong) =>
    play(config, (q) => !wrong.contains(q.number));

/// A learner who knows every deck up to [level] (-1 for none) and none above.
Played playLevel(PlacementRunConfig config, int level) =>
    play(config, (q) => q.deck <= level);

String label(PlacementRun run, PlacementSkill skill) =>
    run.readout[skill]!.label.name;

void main() {
  group('the declaration', () {
    test('Beginner produces no question and writes nothing', () {
      final run = PlacementRun(
        configFor(_bengali, declaration: PlacementDeclaration.beginner),
      );
      expect(run.next, isNull);
      expect(run.isDone, isTrue);
      expect(run.isSkipped, isTrue);
      expect(run.asked, 0);
      expect(run.checkpointDue, isFalse);
      for (final skill in _bengali) {
        expect(label(run, skill), 'notTested');
      }
    });

    test('Expert starts the expert track at the last deck', () {
      final first = PlacementRun(configFor(_bengali)).next!;
      expect(first.number, 1);
      expect(first.role, PlacementQuestionRole.base);
      expect(first.deck, 99);
      expect(first.percentile, 100);
    });

    test('Advanced and Amateur position first, where the prior splits', () {
      PlacementQuestionRequest first(PlacementDeclaration d) =>
          PlacementRun(configFor(_bengali, declaration: d)).next!;
      final advanced = first(PlacementDeclaration.advanced);
      expect(advanced.role, PlacementQuestionRole.probe);
      expect(advanced.deck, 79); // unit 80
      final amateur = first(PlacementDeclaration.amateur);
      expect(amateur.role, PlacementQuestionRole.probe);
      expect(amateur.deck, 40); // unit 41
    });

    test('with no declaration positioning starts at the 50th percentile', () {
      final run = PlacementRun(
        configFor(
          <PlacementSkill>{_read},
          declaration: null,
          expertTrack: false,
        ),
      );
      expect(run.next!.deck, 50);
      expect(run.next!.percentile, closeTo(50.5, 0.6));
    });

    test('it is never evidence: the same answers, the same assurance', () {
      // Expert and no declaration run the same expert track, so the same
      // answers must leave the same posterior in every skill.
      final answers = <bool>[
        true, true, true, false, true, true, true, true, //
        true, true, true, true, true, true, true, true,
      ];
      final withDeclaration = PlacementRun(
        configFor(_bengali),
        results: answers,
      );
      final without = PlacementRun(
        configFor(_bengali, declaration: null),
        results: answers,
      );
      for (final skill in _bengali) {
        expect(
          withDeclaration.posteriorOf(skill)!.probabilities,
          without.posteriorOf(skill)!.probabilities,
          reason: skill.name,
        );
      }
    });

    test(
      'the reporting posterior is the flat prior times the answers only',
      () {
        for (final declaration in <PlacementDeclaration?>[
          PlacementDeclaration.advanced,
          PlacementDeclaration.amateur,
          PlacementDeclaration.expert,
          null,
        ]) {
          final config = configFor(
            <PlacementSkill>{_read, _hear},
            declaration: declaration,
            expertTrack:
                declaration == null ||
                    declaration == PlacementDeclaration.expert
                ? null
                : false,
          );
          final played = playLevel(config, 40);
          for (final skill in <PlacementSkill>[_read, _hear]) {
            var expected = PlacementPosterior.flat(played.run.levels);
            for (final answer in played.run.history) {
              if (!answer.request.skills.contains(skill)) continue;
              final request = answer.request;
              expected = expected.updateCredit(
                deck: request.deck,
                kind: request.kind,
                correct: answer.correct,
              );
            }
            final actual = played.run.posteriorOf(skill)!.probabilities;
            for (var c = 0; c < actual.length; c++) {
              expect(
                actual[c],
                closeTo(expected.probabilities[c], 1e-9),
                reason: '$declaration ${skill.name} class $c',
              );
            }
          }
        }
      },
    );
  });

  group('the expert track', () {
    test('asks the mastery topics in order, hard, at the last deck', () {
      final played = playWrong(configFor(_bengali), <int>{});
      expect(played.variants, <String>[
        'K1', 'K2', // long-sentence recognition
        'W1', 'W2', // complex words
        'G1', 'G2', // late grammar
        'R1', 'R2', // long-sentence reproduction
        'P1', 'P2', // minimal pairs
        'Y1', 'Y2', 'Y3', // Say by the meaning of a word
        'SR', 'SW', // script read and write
      ]);
      for (final answer in played.run.history) {
        expect(answer.request.deck, 99);
        expect(answer.request.role, PlacementQuestionRole.base);
      }
    });

    test(
      'questions name the skills a right answer evidences (section 2.1)',
      () {
        final byVariant = <String, List<PlacementSkill>>{
          for (final a in playWrong(configFor(_bengali), <int>{}).run.history)
            a.request.variant.label: a.request.skills,
        };
        expect(byVariant['K1'], <PlacementSkill>[_read, _script]);
        expect(byVariant['K2'], <PlacementSkill>[_hear]);
        expect(byVariant['G2'], <PlacementSkill>[_write, _read]);
        expect(byVariant['R1'], <PlacementSkill>[_hear, _write]);
        expect(byVariant['Y1'], <PlacementSkill>[_say]);
        expect(byVariant['SW'], <PlacementSkill>[_script, _write]);
      },
    );

    test('the seed makes the run reproducible and varies the item pick', () {
      List<String> trace(int seed) {
        final played = playWrong(configFor(_bengali, seed: seed), <int>{});
        return <String>[
          for (final a in played.run.history)
            '${a.request.variant.label}:${a.request.shortlistPick}',
        ];
      }

      expect(trace(7), trace(7));
      expect(trace(7), isNot(trace(8)));
      for (final pick in trace(7).map((s) => int.parse(s.split(':').last))) {
        expect(pick, inInclusiveRange(0, 4));
      }
    });

    test('a left-out skill is not asked: no Say question without Say', () {
      final played = playWrong(
        configFor(<PlacementSkill>{_read, _hear, _write}),
        <int>{},
      );
      expect(played.variants, isNot(contains('Y1')));
      expect(played.variants, isNot(contains('SR')));
    });

    test('no mic: Say is Not tested, K1 and K2 become picks', () {
      final played = playWrong(configFor(_bengali, microphone: false), <int>{});
      expect(played.variants, isNot(contains('Y1')));
      final kinds = <String, PlacementQuestionKind>{
        for (final a in played.run.history)
          a.request.variant.label: a.request.kind,
      };
      expect(kinds['K1'], PlacementQuestionKind.pickMany);
      expect(kinds['K2'], PlacementQuestionKind.pickMany);
      expect(label(played.run, _say), 'notTested');
    });
  });

  group('a miss is checked', () {
    test('a single-skill miss is rechecked once; a right check is a slip', () {
      // Question 9 is the first pair.
      final played = playWrong(configFor(_bengali), <int>{9});
      final roles = played.run.history.map((a) => a.request.role).toList();
      expect(played.variants.sublist(8, 11), <String>['P1', 'P1', 'P2']);
      expect(roles[9], PlacementQuestionRole.recheck);
      expect(played.run.closedTopics, isEmpty);
      expect(played.run.closedSkills, isEmpty);
    });

    test('a wrong first check gets a second', () {
      final played = playWrong(configFor(_bengali), <int>{9, 10});
      expect(played.variants.sublist(8, 12), <String>['P1', 'P1', 'P1', 'P2']);
      expect(played.run.closedTopics, isEmpty);
    });

    test('a miss and both checks wrong close the case', () {
      final played = playWrong(configFor(_bengali), <int>{9, 10, 11});
      expect(played.run.closedTopics, <PlacementTopic>{
        PlacementTopic.minimalPairs,
      });
      expect(played.run.closedSkills, contains(_hear));
      // The second pair is skipped, and one isolating question tells hearing
      // from spelling: a tile with the swapped letter.
      expect(played.variants.sublist(8, 12), <String>['P1', 'P1', 'P1', 'I1']);
      expect(played.variants, isNot(contains('P2')));
      final isolating = played.run.history[11].request;
      expect(isolating.role, PlacementQuestionRole.isolating);
      expect(isolating.skills, <PlacementSkill>[_write]);
    });

    test('a composite miss is split in two, both asked', () {
      // Question 7 is R1 (Hear and Write).
      final played = playWrong(configFor(_bengali), <int>{7});
      expect(played.variants.sublist(6, 10), <String>['R1', 'S1', 'S2', 'R2']);
      expect(played.run.history[7].request.role, PlacementQuestionRole.split);
      expect(played.run.history[7].request.skills, <PlacementSkill>[_hear]);
      expect(played.run.history[8].request.skills, <PlacementSkill>[_write]);
      expect(played.run.gaps, isEmpty);
    });

    test('both splits right: a slip, nothing is recorded', () {
      final played = playWrong(configFor(_bengali), <int>{2});
      expect(played.run.gaps, isEmpty);
      expect(played.run.closedTopics, isEmpty);
      expect(played.run.closedSkills, isEmpty);
    });

    test('one split wrong: a gap in the part it isolates', () {
      final played = playWrong(configFor(_bengali), <int>{7, 9});
      expect(played.run.gaps, hasLength(1));
      final gap = played.run.gaps.single;
      expect(gap.topic, PlacementTopic.longReproduction);
      expect(gap.part, PlacementPart.spelling);
      expect(gap.skills, <PlacementSkill>[_write]);
      expect(played.run.closedTopics, isEmpty);
    });

    test(
      'both splits wrong close the topic; the second question is skipped',
      () {
        final played = playWrong(configFor(_bengali), <int>{7, 8, 9});
        expect(played.run.closedTopics, <PlacementTopic>{
          PlacementTopic.longReproduction,
        });
        expect(played.variants, isNot(contains('R2')));
      },
    );

    test('a closed topic 1 means the last deck is not known: all position', () {
      final played = playWrong(configFor(_bengali), <int>{1, 2, 3});
      expect(played.run.closedTopics, contains(PlacementTopic.longRecognition));
      expect(played.run.expertSkills, isEmpty);
      // The next question is a positioning probe at a deck below the last.
      final next = played.run.history[3].request;
      expect(next.role, PlacementQuestionRole.probe);
      expect(next.deck, lessThan(99));
    });

    test('"I do not know" is a miss: nothing answered closes cases', () {
      // A learner who answers nothing: the run asks checks, then closes.
      final played = play(configFor(_bengali), (q) => false, cap: 60);
      expect(played.run.closedTopics, isNotEmpty);
    });
  });

  group('the expert track, as a learner meets it', () {
    final spanish = <PlacementSkill>{_read, _hear, _write};

    test('a clean native is Verified in every skill', () {
      final played = playWrong(configFor(_bengali), <int>{});
      expect(played.run.isDone, isTrue);
      for (final skill in _bengali) {
        expect(label(played.run, skill), 'verified', reason: skill.name);
      }
    });

    test('Spanish without a microphone takes 35 questions or fewer', () {
      final played = playWrong(configFor(spanish, microphone: false), <int>{});
      expect(played.run.isDone, isTrue);
      expect(played.asked, lessThanOrEqualTo(35));
    });

    test('one slip costs at most four questions more and stays Verified', () {
      final config = configFor(spanish, microphone: false);
      final clean = playWrong(config, <int>{});
      final slip = playWrong(config, <int>{9});
      expect(slip.asked, lessThanOrEqualTo(clean.asked + 4));
      for (final skill in spanish) {
        expect(label(slip.run, skill), 'verified', reason: skill.name);
      }
    });

    test('a gapped skill is Very sure but not Verified; the others are', () {
      final played = playWrong(configFor(_bengali), <int>{7, 9});
      expect(label(played.run, _write), 'verySure');
      for (final skill in <PlacementSkill>[_read, _hear, _say, _script]) {
        expect(label(played.run, skill), 'verified', reason: skill.name);
      }
    });

    test('the credit posterior is the flat prior times the floors', () {
      // A reference of the model (plan section 13), written from the
      // numbers of the plan and not from the implementation: a class that
      // knows the deck is right with 1 - slip, any other at the floor
      // (base + 0.10); a miss counts in full.
      const slip = <PlacementQuestionKind, double>{
        PlacementQuestionKind.pickOne: 0.15,
        PlacementQuestionKind.pickMany: 0.15,
        PlacementQuestionKind.pair: 0.10,
        PlacementQuestionKind.english: 0.15,
        PlacementQuestionKind.tilesSentence: 0.15,
        PlacementQuestionKind.tilesWord: 0.10,
        PlacementQuestionKind.say: 0.20,
      };
      const base = <PlacementQuestionKind, double>{
        PlacementQuestionKind.pickOne: 0.25,
        PlacementQuestionKind.pickMany: 0.25,
        PlacementQuestionKind.pair: 0.50,
        PlacementQuestionKind.english: 0.03,
        PlacementQuestionKind.tilesSentence: 0.05,
        PlacementQuestionKind.tilesWord: 0.10,
        PlacementQuestionKind.say: 0.03,
      };
      final played = playWrong(configFor(_bengali), <int>{2, 7});
      final levels = played.run.levels;
      for (final skill in _bengali) {
        final weights = List<double>.filled(levels.classCount, 1);
        for (final answer in played.run.history) {
          final r = answer.request;
          if (!r.skills.contains(skill)) continue;
          for (var c = 0; c < weights.length; c++) {
            final right = levels.knows(c, r.deck)
                ? 1 - slip[r.kind]!
                : min(1.0, base[r.kind]! + 0.10);
            weights[c] *= answer.correct ? right : 1 - right;
          }
        }
        final total = weights.fold<double>(0, (a, b) => a + b);
        final actual = played.run.posteriorOf(skill)!.probabilities;
        for (var c = 0; c < weights.length; c++) {
          expect(
            actual[c],
            closeTo(weights[c] / total, 1e-9),
            reason: '${skill.name} class $c',
          );
        }
      }
    });

    test('a heritage speaker (Hear and Say) is asked no reproduction', () {
      final played = playWrong(
        configFor(<PlacementSkill>{_hear, _say}),
        <int>{},
      );
      expect(played.variants.where((v) => v.startsWith('R')), isEmpty);
      expect(label(played.run, _hear), 'verified');
      expect(label(played.run, _say), 'verified');
      expect(label(played.run, _read), 'notTested');
    });

    test('a closed pair topic leaves Hear to be positioned', () {
      final config = configFor(_bengali);
      final played = playWrong(config, <int>{9, 10, 11});
      expect(played.run.expertSkills, isNot(contains(_hear)));
      expect(played.variants, contains('V'));
      expect(label(played.run, _hear), isNot('verified'));
      expect(label(played.run, _read), 'verified');
    });
  });

  group('Verified (section 4.3)', () {
    test('needs the path complete to B1 and every deck downloaded', () {
      final played = playWrong(configFor(_bengali, verifiable: false), <int>{});
      expect(played.run.isDone, isTrue);
      for (final skill in _bengali) {
        expect(label(played.run, skill), 'verySure', reason: skill.name);
      }
    });

    test('a skill that left the expert track is placed, never Verified', () {
      final played = playLevel(
        configFor(_bengali, declaration: PlacementDeclaration.advanced),
        80,
      );
      for (final skill in _bengali) {
        expect(
          played.run.readout[skill]!.isVerified,
          isFalse,
          reason: skill.name,
        );
      }
    });

    test('a closed case in a skill blocks Verified for that skill', () {
      final played = playWrong(configFor(_bengali), <int>{9, 10, 11});
      expect(played.run.readout[_hear]!.isVerified, isFalse);
    });

    test('a skill the learner did not mark is Not tested', () {
      final played = playWrong(
        configFor(<PlacementSkill>{_read, _hear}),
        <int>{},
      );
      expect(played.run.readout[_say]!.label, AssuranceLabel.notTested);
      expect(played.run.readout[_write]!.label, AssuranceLabel.notTested);
      expect(played.run.readout[_script]!.label, AssuranceLabel.notTested);
      expect(played.run.readout, isNot(contains(PlacementSkill.secondScript)));
      final heritage = playWrong(configFor(<PlacementSkill>{_hear}), <int>{});
      expect(heritage.run.readout[_hear]!.label, AssuranceLabel.verified);
    });
  });

  group('positioning (section 5.3)', () {
    Played position(
      int level, {
      bool recheck = true,
      PlacementDeclaration? declaration,
    }) => playLevel(
      configFor(
        <PlacementSkill>{_read},
        declaration: declaration,
        expertTrack: false,
        recheck: recheck,
        floorFirst: false,
        promote: false,
      ),
      level,
    );

    // A learner who knows decks up to a level is placed in the class of that
    // level (the levels of 100 decks are every tenth), never above it.
    for (final (name, level, lowest) in <(String, int, int)>[
      ('knows nothing', -1, -1),
      ('A2, about 30% of the path', 30, 20),
      ('advanced, about 80%', 80, 70),
      ('native, the whole path', 99, 99),
    ]) {
      test('$name is placed at $lowest to $level', () {
        final played = position(level);
        expect(played.run.isDone, isTrue);
        final found = played.run.readout[_read]!;
        expect(found.placedLevel, inInclusiveRange(lowest, level));
      });
    }

    test('the first miss moves the next probe at once, then it halves', () {
      final decks = <int>[
        for (final a in position(-1).run.history) a.request.deck,
      ];
      expect(decks.first, 50);
      expect(decks.toSet().length, greaterThan(3));
      expect(decks.last, 0);
    });

    test('stops for the skill as soon as 95% is reached, inside a recheck', () {
      final played = position(-1, recheck: true);
      expect(played.asked, played.reached[_read]);
    });

    test('floor first: a closed first probe sends the next to deck 0', () {
      final config = configFor(
        <PlacementSkill>{_read},
        declaration: null,
        expertTrack: false,
      );
      final played = playLevel(config, -1);
      final decks = <int>[for (final a in played.run.history) a.request.deck];
      // 50 asked three times (a miss and its two checks), then the floor.
      expect(decks.sublist(0, 4), <int>[50, 50, 50, 0]);
      expect(played.run.readout[_read]!.placedLevel, -1);
    });

    test('declared Amateur and knowing nothing: placed at the start', () {
      final played = playLevel(
        configFor(<PlacementSkill>{
          _read,
        }, declaration: PlacementDeclaration.amateur),
        -1,
      );
      expect(played.run.isDone, isTrue);
      expect(played.run.readout[_read]!.placedLevel, -1);
    });

    test(
      'Example 4: an advanced learner, Advanced declared, is placed at unit 80',
      () {
        final played = playLevel(
          configFor(
            <PlacementSkill>{_read, _hear},
            declaration: PlacementDeclaration.advanced,
            grammarUnits: <int>[5, 20, 40, 60, 77, 87, 95],
          ),
          80,
        );
        expect(played.run.isDone, isTrue);
        for (final skill in <PlacementSkill>[_read, _hear]) {
          final assurance = played.run.readout[skill]!;
          expect(assurance.placedLevel, 79);
          expect(assurance.placedUnit, 80);
          expect(assurance.label, AssuranceLabel.verySure);
        }
        expect(played.run.checkpointDue, isFalse);
      },
    );

    test('Example 4: the grammar bisection goes up once, then stops', () {
      final played = playLevel(
        configFor(
          <PlacementSkill>{_read, _hear},
          declaration: PlacementDeclaration.advanced,
          grammarUnits: <int>[5, 20, 40, 60, 77, 87, 95],
        ),
        80,
      );
      final grammar = <PlacementQuestionRequest>[
        for (final a in played.run.history)
          if (a.request.topic == PlacementTopic.grammarLevel) a.request,
      ];
      // At the unit at or before deck 79 (77), then halfway up (87, asked
      // three times: a miss and its two checks).
      expect(grammar.map((r) => r.deck), <int>[77, 87, 87, 87]);
      expect(played.run.grammarDeck, 77);
    });

    test('grammar goes halfway down when the first probe fails', () {
      final played = play(
        configFor(
          <PlacementSkill>{_read},
          declaration: PlacementDeclaration.advanced,
          grammarUnits: <int>[5, 20, 40, 60, 77, 87, 95],
        ),
        (q) => q.topic == PlacementTopic.grammarLevel
            ? q.deck <= 40
            : q.deck <= 80,
      );
      final decks = <int>[
        for (final a in played.run.history)
          if (a.request.topic == PlacementTopic.grammarLevel) a.request.deck,
      ];
      // Wrong at 77 (a miss and two checks), then halfway between the first
      // unit and 77: the unit at 40, which is right.
      expect(decks, <int>[77, 77, 77, 40]);
      expect(played.run.grammarDeck, 40);
    });

    test(
      'a second probe that cannot be built keeps the first one\'s level',
      () {
        var run = PlacementRun(
          configFor(
            <PlacementSkill>{_read, _hear},
            declaration: PlacementDeclaration.advanced,
            grammarUnits: <int>[5, 20, 40, 60, 77, 87, 95],
          ),
        );
        var unavailable = 0;
        while (!run.isDone && run.asked < 200) {
          final q = run.next!;
          if (q.topic == PlacementTopic.grammarLevel && q.deck == 87) {
            unavailable++;
            run = run.markUnavailable(
              PlacementUnavailableReason.noGrammarFamily,
            );
            continue;
          }
          run = run.answer(q.deck <= 80);
        }
        expect(unavailable, 1);
        expect(run.grammarDeck, 77, reason: 'the stage-0 result is kept');
      },
    );

    test('a learner who knows nothing is not asked grammar', () {
      final played = playLevel(
        configFor(
          <PlacementSkill>{_read},
          declaration: PlacementDeclaration.amateur,
          grammarUnits: <int>[5, 20, 40],
        ),
        -1,
      );
      expect(played.run.grammarDeck, isNull);
    });
  });

  group('short paths finish (N of 1, 2, 5 and 10)', () {
    const skills = <PlacementSkill>{_read, _hear};

    for (final n in <int>[1, 2, 5, 10]) {
      group('N = $n', () {
        test('a clean expert is done, and Verified when the plan allows', () {
          final played = playWrong(configFor(skills, deckCount: n), <int>{});
          expect(played.run.isDone, isTrue);
          expect(played.asked, lessThan(60));
          for (final skill in skills) {
            expect(label(played.run, skill), 'verified', reason: skill.name);
          }
          // Without the preconditions the same answers are only Very sure.
          final unverified = playWrong(
            configFor(skills, deckCount: n, verifiable: false),
            <int>{},
          );
          expect(unverified.run.isDone, isTrue);
          for (final skill in skills) {
            expect(label(unverified.run, skill), 'verySure');
          }
        });

        test('a learner who knows nothing is placed at none, done', () {
          final played = playLevel(
            configFor(
              skills,
              deckCount: n,
              declaration: PlacementDeclaration.amateur,
            ),
            -1,
          );
          expect(played.run.isDone, isTrue);
          expect(played.asked, lessThan(100));
          for (final skill in skills) {
            expect(played.run.readout[skill]!.placedLevel, -1);
            expect(played.run.readout[skill]!.isVerified, isFalse);
          }
        });

        test('a mid learner is placed and done; Verified only at the top', () {
          // For one deck "mid" is the whole path: the one level is the top,
          // so a learner who proves it goes on the expert track and can be
          // Verified, as for any path. Below the top he never is.
          final level = (n - 1) ~/ 2;
          final played = playLevel(
            configFor(
              skills,
              deckCount: n,
              declaration: PlacementDeclaration.advanced,
            ),
            level,
          );
          expect(played.run.isDone, isTrue);
          expect(played.asked, lessThan(100));
          for (final skill in skills) {
            final assurance = played.run.readout[skill]!;
            expect(assurance.placedLevel, level);
            if (level < n - 1) {
              expect(assurance.isVerified, isFalse, reason: skill.name);
            }
          }
        });

        test('a Beginner declaration asks nothing', () {
          final run = PlacementRun(
            configFor(
              skills,
              deckCount: n,
              declaration: PlacementDeclaration.beginner,
            ),
          );
          expect(run.isDone, isTrue);
        });
      });
    }

    test('one deck has one level: none or the whole path', () {
      expect(PlacementLevels(1).classCount, 2);
      final run = PlacementRun(configFor(skills, deckCount: 1));
      expect(run.next!.deck, 0);
      expect(run.next!.percentile, 100);
    });
  });

  group('the configuration and the state', () {
    test('the sets and lists of a configuration cannot be changed', () {
      final units = <int>[3, 5];
      final config = configFor(_bengali, grammarUnits: units);
      expect(
        () => config.skills.add(PlacementSkill.secondScript),
        throwsA(anything),
      );
      expect(() => config.tested.clear(), throwsA(anything));
      units.add(9);
      expect(config.grammarUnitDecks, <int>[3, 5]);
      expect(() => config.grammarUnitDecks.add(1), throwsA(anything));
    });

    test('answering a finished run is an error', () {
      final done = playWrong(configFor(_bengali), <int>{}).run;
      expect(done.isDone, isTrue);
      expect(() => done.answer(true), throwsStateError);
    });

    test('a gap in meaning blocks Verified for its skill too (4.3 d)', () {
      // Q3 W1 missed, S1 (meaning, Read) wrong, S2 right.
      final played = playWrong(configFor(_bengali), <int>{3, 4});
      expect(played.run.gaps.single.part, PlacementPart.meaning);
      expect(played.run.gaps.single.skills, <PlacementSkill>[_read]);
      expect(label(played.run, _read), isNot('verified'));
      expect(label(played.run, _hear), 'verified');
    });
  });

  group('the checkpoint (section 5.4)', () {
    PlacementRun after(PlacementRunConfig config, int questions) {
      var run = PlacementRun(config);
      while (run.asked < questions && !run.isDone) {
        run = run.answer(false);
      }
      return run;
    }

    final config = configFor(
      <PlacementSkill>{_read, _hear},
      declaration: PlacementDeclaration.amateur,
      floorFirst: false,
    );

    test('is flagged at 25 questions and not before', () {
      expect(after(config, 24).checkpointDue, isFalse);
      final run = after(config, 25);
      expect(run.asked, 25);
      expect(run.checkpointDue, isTrue);
      expect(run.isDone, isFalse);
    });

    test('Keep going clears it until the next 25', () {
      final kept = after(config, 25).keepGoing();
      expect(kept.checkpointDue, isFalse);
      expect(kept.next, isNotNull);
      expect(after(config, 26).keepGoing().checkpointDue, isFalse);
      // A learner who answers nothing on five skills is still being asked at
      // 50 (the run only stops at 95% in every skill).
      final deep = configFor(_bengali, floorFirst: false);
      var run = after(deep, 25).keepGoing();
      while (run.asked < 50) {
        run = run.answer(false);
      }
      expect(run.isDone, isFalse);
      expect(run.checkpointDue, isTrue);
      expect(run.keepGoing().checkpointDue, isFalse);
    });

    test('shows where the learner stands, per skill, at 25', () {
      // A learner who knows nothing: nothing is credited, and no result at
      // the checkpoint is above the start.
      final run = after(config, 25);
      for (final skill in <PlacementSkill>[_hear, _read]) {
        expect(run.readout[skill]!.placedLevel, -1, reason: skill.name);
      }
    });

    test('a learner who knows nothing is placed at the start', () {
      final played = play(config, (q) => false);
      expect(played.run.isDone, isTrue);
    });

    test('a run that is done shows no checkpoint', () {
      final played = playWrong(configFor(_bengali), <int>{});
      expect(played.run.isDone, isTrue);
      expect(played.run.checkpointDue, isFalse);
    });
  });

  group('no fixed cap', () {
    test('a run keeps asking past 50 until each skill is at 95%', () {
      final played = play(
        configFor(_bengali, floorFirst: false),
        (q) => false,
        cap: 300,
      );
      // The controller does not stop a learner by itself: it ends when every
      // skill is placed at 95%, here "none" in all five.
      expect(played.asked, greaterThan(50));
      expect(played.run.isDone, isTrue);
      for (final skill in _bengali) {
        expect(played.run.readout[skill]!.placedLevel, -1);
      }
    });
  });

  group('a pure guesser (section 6.2)', () {
    test('almost never reaches Verified, and is placed low', () {
      final random = Random(2026);
      var verified = 0;
      var topAtTarget = 0;
      const runs = 400;
      for (var i = 0; i < runs; i++) {
        var run = PlacementRun(configFor(_bengali, seed: i));
        while (!run.isDone && run.asked < 150) {
          run = run.answer(
            random.nextDouble() <
                min(1.0, run.next!.kind.creditBase() + creditKappa),
          );
        }
        for (final assurance in run.readout.values) {
          if (assurance.isVerified) verified++;
          if (assurance.placedClass == run.levels.topClass) {
            topAtTarget++;
          }
        }
      }
      // The plan: about 1 in 500 to 4,000 for a skill; none in 60,000 for
      // every skill together.
      expect(verified, 0);
      expect(topAtTarget, lessThanOrEqualTo(runs * _bengali.length ~/ 500));
    });
  });
}
