// The assurance model of "Find my level" (wiki/Plan-Placement-V2.md, section
// 4): the twelve classes, the update from an answer, the priors of the
// declaration and the names. The figures are the plan's, which came from a
// simulation; where one is a rounded published number the tolerance says so.
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:flutter_test/flutter_test.dart';

PlacementPosterior afterAnswers(
  PlacementLevels levels,
  List<(PlacementQuestionKind, bool)> answers, {
  int? deck,
}) {
  var posterior = PlacementPosterior.flat(levels);
  for (final (kind, correct) in answers) {
    posterior = posterior.update(
      deck: deck ?? levels.lastDeck,
      kind: kind,
      correct: correct,
    );
  }
  return posterior;
}

void main() {
  final hundred = PlacementLevels(100);

  group('the classes', () {
    test('a path of 100 decks has none and the ten tenths', () {
      expect(hundred.classCount, 12);
      expect(hundred.levels, <int>[0, 10, 20, 30, 40, 50, 59, 69, 79, 89, 99]);
      expect(hundred.levelOf(0), -1);
      expect(hundred.levelOf(hundred.topClass), 99);
    });

    test('a short path has fewer, equal parts and ends at the last deck', () {
      final five = PlacementLevels(5);
      expect(five.parts, 5);
      expect(five.levels.first, 0);
      expect(five.levels.last, 4);
      expect(PlacementLevels(1).levels, <int>[0, 0]);
      expect(PlacementLevels(0).deckCount, 1);
    });

    test('a class knows every deck up to its level and none above', () {
      expect(hundred.knows(0, 0), isFalse);
      expect(hundred.knows(1, 0), isTrue);
      expect(hundred.knows(1, 1), isFalse);
      expect(hundred.knows(6, 50), isTrue);
      expect(hundred.knows(6, 51), isFalse);
      expect(hundred.knows(hundred.topClass, 99), isTrue);
    });
  });

  group('the update', () {
    test('the reporting prior is flat and sums to one', () {
      final flat = PlacementPosterior.flat(hundred);
      expect(flat.probabilities, everyElement(closeTo(1 / 12, 1e-12)));
      expect(flat.probabilities.reduce((a, b) => a + b), closeTo(1, 1e-12));
    });

    test('a right answer multiplies the odds by (1 - slip) / guess', () {
      for (final kind in PlacementQuestionKind.values) {
        final after = afterAnswers(hundred, [(kind, true)]);
        final top = after.probabilities[hundred.topClass];
        final none = after.probabilities[0];
        expect(top / none, closeTo(kind.oddsPerRight, 1e-9), reason: '$kind');
      }
      expect(PlacementQuestionKind.pickOne.oddsPerRight, closeTo(3.8, 1e-9));
      expect(PlacementQuestionKind.pair.oddsPerRight, closeTo(1.9, 1e-9));
      expect(PlacementQuestionKind.english.oddsPerRight, closeTo(30, 1e-9));
    });

    test('a miss at the last deck hurts the class that knows it', () {
      final after = afterAnswers(hundred, [
        (PlacementQuestionKind.pickOne, false),
      ]);
      expect(after.probabilities[hundred.topClass], lessThan(1 / 12));
      expect(after.probabilities[0], greaterThan(1 / 12));
      expect(after.leadingClass, isNot(hundred.topClass));
    });

    test('a miss counts against every class that knows the deck', () {
      final after = PlacementPosterior.flat(
        hundred,
      ).update(deck: 40, kind: PlacementQuestionKind.pickOne, correct: false);
      // Classes l_4 (deck 40) and up are the ones that should have known it.
      final knowers = <int>[for (var c = 5; c < 12; c++) c];
      for (final c in knowers) {
        expect(after.probabilities[c], lessThan(after.probabilities[0]));
      }
    });

    test(
      'a composite miss counts at half strength (likelihood to the half)',
      () {
        const kind = PlacementQuestionKind.tilesSentence;
        final flat = PlacementPosterior.flat(hundred);
        double ratio(double weight) {
          final after = flat.update(
            deck: hundred.lastDeck,
            kind: kind,
            correct: false,
            missWeight: weight,
          );
          return after.probabilities[hundred.topClass] / after.probabilities[0];
        }

        final full = ratio(1);
        final half = ratio(0.5);
        // top: slip 0.10; none: 1 - guess 0.95.
        expect(full, closeTo(0.10 / 0.95, 1e-9));
        expect(half * half, closeTo(full, 1e-9));
      },
    );

    test('three right Say answers take Say from 8% to 99.9% (plan, 4.2)', () {
      var posterior = PlacementPosterior.flat(hundred);
      final masses = <double>[posterior.topMass];
      for (var i = 0; i < 3; i++) {
        posterior = posterior.update(
          deck: hundred.lastDeck,
          kind: PlacementQuestionKind.say,
          correct: true,
        );
        masses.add(posterior.topMass);
      }
      expect(masses[0], closeTo(0.083, 0.001));
      expect(masses[1], closeTo(0.72, 0.01));
      expect(masses[2], closeTo(0.986, 0.001));
      expect(masses[3], greaterThan(0.999));
    });

    test('the placed level is the leading class, its assurance its mass', () {
      final after = afterAnswers(hundred, [
        (PlacementQuestionKind.english, true),
        (PlacementQuestionKind.english, true),
      ]);
      expect(after.leadingClass, hundred.topClass);
      expect(after.placedLevel, 99);
      expect(after.leadingMass, closeTo(900 / 911, 1e-9));
    });

    test('five right four-option answers at the top reach 95% (plan, 5.3)', () {
      double top(int rights) => afterAnswers(hundred, [
        for (var i = 0; i < rights; i++) (PlacementQuestionKind.pickOne, true),
      ]).topMass;
      expect(top(4), lessThan(0.95));
      expect(top(5), greaterThanOrEqualTo(0.95));
      // Three would give 80%: "Sure", not the target.
      expect(top(3), inInclusiveRange(0.80, 0.94));
    });
  });

  group('the declaration priors (section 4.5)', () {
    double mass(PlacementDeclaration d, int c) {
      final weights = askingPriorWeights(hundred, d);
      return weights[c] / weights.reduce((a, b) => a + b);
    }

    test('Fluent leans to the top and sums to one', () {
      expect(mass(PlacementDeclaration.fluent, 11), closeTo(0.55, 1e-9));
      expect(mass(PlacementDeclaration.fluent, 10), closeTo(0.15, 1e-9));
      expect(mass(PlacementDeclaration.fluent, 9), closeTo(0.08, 1e-9));
      expect(mass(PlacementDeclaration.fluent, 8), closeTo(0.05, 1e-9));
      expect(mass(PlacementDeclaration.fluent, 0), closeTo(0.02125, 1e-9));
    });

    test('Advanced is a triangle around l7.5 on a floor', () {
      // none to l4 0.006, l5 0.058, l6 0.16, l7 and l8 0.263, l9 0.16, l10
      // 0.058 (published to three places).
      const d = PlacementDeclaration.advanced;
      expect(mass(d, 0), closeTo(0.006, 0.001));
      expect(mass(d, 5), closeTo(0.006, 0.001)); // l4
      expect(mass(d, 6), closeTo(0.058, 0.001)); // l5
      expect(mass(d, 7), closeTo(0.16, 0.002)); // l6
      expect(mass(d, 8), closeTo(0.263, 0.002)); // l7
      expect(mass(d, 9), closeTo(0.263, 0.002)); // l8
      expect(mass(d, 10), closeTo(0.16, 0.002)); // l9
      expect(mass(d, 11), closeTo(0.058, 0.001)); // l10
    });

    test('Amateur is the same triangle around l3.5', () {
      const d = PlacementDeclaration.amateur;
      expect(mass(d, 0), closeTo(0.006, 0.001)); // none
      expect(mass(d, 1), closeTo(0.006, 0.001)); // l0
      expect(mass(d, 2), closeTo(0.058, 0.001)); // l1
      expect(mass(d, 3), closeTo(0.16, 0.002)); // l2
      expect(mass(d, 4), closeTo(0.263, 0.002)); // l3
      expect(mass(d, 5), closeTo(0.263, 0.002)); // l4
      expect(mass(d, 6), closeTo(0.16, 0.002)); // l5
      expect(mass(d, 7), closeTo(0.058, 0.001)); // l6
      expect(mass(d, 8), closeTo(0.006, 0.001)); // l7
    });

    test('the first question lands where the prior is split in half', () {
      int first(PlacementDeclaration? d) => askingDeck(
        PlacementPosterior(hundred, askingPriorWeights(hundred, d)),
      );
      expect(first(null), 50); // the 50th percentile
      expect(first(PlacementDeclaration.advanced), 79); // unit 80
      expect(first(PlacementDeclaration.amateur), 40); // unit 41
      expect(first(PlacementDeclaration.fluent), 99); // unit 100
    });
  });

  group('the names (section 4.3)', () {
    test('Not sure yet under 50%, Fairly sure, Sure, Very sure at 95%', () {
      expect(labelForMass(0.10), AssuranceLabel.notSureYet);
      expect(labelForMass(0.499), AssuranceLabel.notSureYet);
      expect(labelForMass(0.50), AssuranceLabel.fairlySure);
      expect(labelForMass(0.79), AssuranceLabel.fairlySure);
      expect(labelForMass(0.80), AssuranceLabel.sure);
      expect(labelForMass(0.94), AssuranceLabel.sure);
      expect(labelForMass(0.95), AssuranceLabel.verySure);
      expect(labelForMass(0.999), AssuranceLabel.verySure);
    });

    test('the target of a fit is 95% and 80% is only a line between names', () {
      expect(kAssuranceTarget, 0.95);
      expect(reachesTarget(0.9499), isFalse);
      expect(reachesTarget(0.95), isTrue);
      expect(reachesTarget(0.80), isFalse);
    });

    test('the names are ordered from not tested to verified', () {
      expect(AssuranceLabel.values, <AssuranceLabel>[
        AssuranceLabel.notTested,
        AssuranceLabel.notSureYet,
        AssuranceLabel.fairlySure,
        AssuranceLabel.sure,
        AssuranceLabel.verySure,
        AssuranceLabel.verified,
      ]);
    });
  });
}
