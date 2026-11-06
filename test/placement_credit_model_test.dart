// The credit model of Find my level (wiki/Plan-Placement-V2.md, "Make or
// break: the guess-proof strategy", criteria S1 to S4): simulated learners
// answer the run controller's questions with a success rate per question
// kind; the credited level must never be above what the learner knows (at
// most 15 of 3000 runs, the 99% upper bound of which is under 1%), and a
// learner who knows a stretch of the path must still be placed in it. lib/core
// only; seeded, so nothing flakes.
import 'dart:math' as math;

import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/placement_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Spanish path: 269 listed decks, classes at decks 0, 27, 54, 80, 107,
/// 134, 161, 188, 215, 242 and 268.
const int _decks = 269;

const Timeout _long = Timeout(Duration(minutes: 30));

PlacementRunConfig _config(int seed) => PlacementRunConfig(
  deckCount: _decks,
  skills: const <PlacementSkill>{
    PlacementSkill.read,
    PlacementSkill.hear,
    PlacementSkill.write,
  },
  declaration: PlacementDeclaration.amateur,
  microphone: false,
  seed: seed,
  pathCompleteToB1: true,
  allDecksDownloaded: true,
);

/// The guess floor of a question of [kind] with no cue.
double _floor(PlacementQuestionKind kind) =>
    math.min(1.0, kind.creditBase() + creditKappa);

typedef _Answerer = bool Function(PlacementQuestionRequest, math.Random);

/// Knows every deck up to [known] (right with 1 - [slip]); anywhere else it
/// is right at the guess floor of the question.
_Answerer _learner(int known, double slip, {double? flat}) => (request, rng) {
  if (request.deck <= known) return rng.nextDouble() >= slip;
  return rng.nextDouble() < math.min(flat ?? 1, _floor(request.kind));
};

typedef _Result = ({
  Map<PlacementSkill, int> atCheckpoint,
  Map<PlacementSkill, int> atEnd,
  int asked,
});

/// A run to its end or [cap] answers, Keep going at each checkpoint; the
/// placed level of each skill at the first checkpoint and at the end.
_Result _drive(int seed, _Answerer answer, {int cap = 100}) {
  var run = PlacementRun(_config(seed));
  final rng = math.Random(seed * 7919 + 13);
  Map<PlacementSkill, int> placed() => <PlacementSkill, int>{
    for (final e in run.readout.entries)
      if (e.value.questions > 0) e.key: e.value.placedLevel,
  };
  Map<PlacementSkill, int>? first;
  while (run.asked < cap) {
    if (run.checkpointDue) {
      first ??= placed();
      run = run.keepGoing();
      continue;
    }
    final request = run.next;
    if (request == null) break;
    run = run.answer(answer(request, rng));
  }
  final end = placed();
  return (atCheckpoint: first ?? end, atEnd: end, asked: run.asked);
}

void _overPlacements(
  String name,
  int known,
  _Answerer answer, {
  int runs = 3000,
}) {
  test('$name: at most 15 of $runs runs credit a level above deck $known', () {
    final high25 = <PlacementSkill, int>{};
    final highEnd = <PlacementSkill, int>{};
    for (var seed = 0; seed < runs; seed++) {
      final r = _drive(seed, answer);
      for (final e in r.atCheckpoint.entries) {
        if (e.value > known) high25[e.key] = (high25[e.key] ?? 0) + 1;
      }
      for (final e in r.atEnd.entries) {
        if (e.value > known) highEnd[e.key] = (highEnd[e.key] ?? 0) + 1;
      }
    }
    for (final skill in PlacementSkill.values) {
      expect(high25[skill] ?? 0, lessThanOrEqualTo(15), reason: '$skill at 25');
      expect(highEnd[skill] ?? 0, lessThanOrEqualTo(15), reason: '$skill end');
    }
  }, timeout: _long);
}

void main() {
  group('S1: a guesser is never credited above what he knows', () {
    _overPlacements('guessing at the floor', -1, _learner(-1, 0));
    _overPlacements(
      'guessing at 0.30 on every question',
      -1,
      _learner(-1, 0, flat: 0.30),
    );
    // The amateur-100: knows the first path units (deck 29 at the most) and
    // guesses at the floor beyond.
    _overPlacements('the amateur-100', 29, _learner(29, 0.10));
  });

  group('S3 and S4: a learner who knows the first decks is placed in them', () {
    final levels = PlacementLevels(_decks).levels;
    for (final (slip, exact) in <(double, double)>[
      (0.05, 0.97),
      (0.10, 0.95),
    ]) {
      for (var c = 1; c <= levels.length; c++) {
        test('slip $slip, knows to deck ${levels[c - 1]} (class $c)', () {
          const runs = 1000;
          var right = 0;
          var nearOrRight = 0;
          for (var seed = 0; seed < runs; seed++) {
            final r = _drive(seed + 1, _learner(levels[c - 1], slip));
            // The class of the lowest placed skill.
            final level = r.atEnd.values.fold<int>(1 << 30, math.min);
            final placed = levels.indexOf(level) + 1;
            if (placed == c) right++;
            if (placed == c || placed == c - 1) nearOrRight++;
          }
          expect(right / runs, greaterThanOrEqualTo(exact));
          if (slip == 0.05) {
            expect(nearOrRight / runs, greaterThanOrEqualTo(0.995));
          }
        }, timeout: _long);
      }
    }
  });
}
