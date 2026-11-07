import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:flutter_test/flutter_test.dart';

// The joint model of Find my level V3 (wiki/Plan-Placement-V3.md). These
// tests check what the model does with answers, not how it is built.

const _read = PlacementSkill.read;
const _hear = PlacementSkill.hear;
const _say = PlacementSkill.say;
const _write = PlacementSkill.write;

PlacementLevels _levels() => PlacementLevels(100, maxParts: 20);

JointItem _pick(
  PlacementSkill skill,
  int deck, {
  String? card,
  double guess = 0.25,
  double weight = 1,
  bool clean = true,
}) => JointItem(
  skills: <PlacementSkill>{skill},
  deck: deck,
  slip: 0.05,
  guess: guess,
  weight: weight,
  clean: clean,
  cardId: card,
);

JointItem _realWord(int deck, String card) => JointItem(
  skills: const <PlacementSkill>{_read},
  deck: deck,
  slip: 0.1,
  guess: 0,
  yesNo: YesNoRole.realWord,
  cardId: card,
);

JointItem _pseudo(String card) =>
    JointItem.pseudoword(skills: const <PlacementSkill>{_read}, cardId: card);

void _askRight(JointPlacement m, PlacementSkill skill, int deck, int count) {
  for (var i = 0; i < count; i++) {
    m.observe(_pick(skill, deck, card: '$skill-$deck-$i'), AnswerOutcome.right);
  }
}

void main() {
  group('the prior', () {
    test('the declaration never weighs more than 70%', () {
      final heavy = JointPlacement(
        levels: _levels(),
        skills: const [_read, _hear],
        declaration: PlacementDeclaration.expert,
        declarationWeight: 1,
      );
      expect(heavy.declarationWeight, kMaxDeclarationWeight);
      final top = heavy.marginal(_read).last;
      // The expert prior puts 0.55 on the top class; at most 70% of it can
      // survive, plus the flat 30%.
      expect(top, lessThanOrEqualTo(0.7 * 0.55 + 0.3 / 22 + 1e-9));
      final flat = JointPlacement(levels: _levels(), skills: const [_read]);
      expect(flat.marginal(_read).last, closeTo(1 / 22, 0.01));
      // The lowest classes keep a real share of the flat part.
      expect(heavy.marginal(_read).first, greaterThan(0.3 / 22 * 0.5));
    });

    test('the posterior always sums to one, and is deterministic', () {
      JointPlacement run() {
        final m = JointPlacement(
          levels: _levels(),
          skills: const [_read, _hear, _write],
        );
        _askRight(m, _read, 50, 3);
        m.observe(_pick(_hear, 80, card: 'h'), AnswerOutcome.wrong);
        return m;
      }

      final a = run();
      final b = run();
      for (final skill in const [_read, _hear, _write]) {
        expect(a.marginal(skill).reduce((x, y) => x + y), closeTo(1, 1e-9));
        expect(a.marginal(skill), b.marginal(skill));
      }
    });

    test('four skills fit in one joint', () {
      final m = JointPlacement(
        levels: _levels(),
        skills: const [_read, _hear, _say, _write],
      );
      m.observe(_pick(_read, 60), AnswerOutcome.right);
      expect(m.massKnowing(_read, 60), greaterThan(0.2));
      expect(
        () => JointPlacement(levels: _levels(), skills: PlacementSkill.values),
        throwsArgumentError,
      );
    });
  });

  group('updating', () {
    test('a right answer raises the skill it asks, a miss lowers it', () {
      final up = JointPlacement(levels: _levels(), skills: const [_read]);
      final down = JointPlacement(levels: _levels(), skills: const [_read]);
      final before = up.massKnowing(_read, 70);
      up.observe(_pick(_read, 70), AnswerOutcome.right);
      down.observe(_pick(_read, 70), AnswerOutcome.wrong);
      expect(up.massKnowing(_read, 70), greaterThan(before));
      expect(down.massKnowing(_read, 70), lessThan(before));
    });

    test('a right mixed answer raises every skill it needs', () {
      final m = JointPlacement(
        levels: _levels(),
        skills: const [_read, _hear, _write],
      );
      final h0 = m.massKnowing(_hear, 70);
      final r0 = m.massKnowing(_read, 70);
      final w0 = m.massKnowing(_write, 70);
      m.observe(
        const JointItem(
          skills: {_read, _hear},
          deck: 70,
          slip: 0.1,
          guess: 0.05,
        ),
        AnswerOutcome.right,
      );
      expect(m.massKnowing(_read, 70), greaterThan(r0));
      expect(m.massKnowing(_hear, 70), greaterThan(h0));
      // Write is not needed but moves with the skills: it must not fall.
      expect(m.massKnowing(_write, 70), greaterThanOrEqualTo(w0));
    });

    test('a miss on a mixed item is blamed on the skill not yet shown', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read, _hear]);
      _askRight(m, _read, 80, 4);
      final r0 = m.massKnowing(_read, 80);
      final h0 = m.massKnowing(_hear, 80);
      m.observe(
        const JointItem(
          skills: {_read, _hear},
          deck: 80,
          slip: 0.1,
          guess: 0.05,
        ),
        AnswerOutcome.wrong,
      );
      final readDrop = r0 - m.massKnowing(_read, 80);
      final hearDrop = h0 - m.massKnowing(_hear, 80);
      expect(hearDrop, greaterThan(readDrop * 3));
    });

    test('a lower weight moves the posterior less', () {
      final full = JointPlacement(levels: _levels(), skills: const [_read]);
      final half = JointPlacement(levels: _levels(), skills: const [_read]);
      full.observe(_pick(_read, 70), AnswerOutcome.right);
      half.observe(_pick(_read, 70, weight: 0.5), AnswerOutcome.right);
      expect(
        half.massKnowing(_read, 70),
        lessThan(full.massKnowing(_read, 70)),
      );
      expect(half.massKnowing(_read, 70), greaterThan(1 / 22));
    });

    test('I do not know carries no guess, so it is stronger than a miss', () {
      final wrong = JointPlacement(levels: _levels(), skills: const [_read]);
      final unsure = JointPlacement(levels: _levels(), skills: const [_read]);
      wrong.observe(_pick(_read, 70), AnswerOutcome.wrong);
      unsure.observe(_pick(_read, 70), AnswerOutcome.dontKnow);
      expect(
        unsure.massKnowing(_read, 70),
        lessThan(wrong.massKnowing(_read, 70)),
      );
    });

    test('an item with a guess of 0.9 or more gives no evidence', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      final before = m.marginal(_read);
      final reason = m.observe(
        _pick(_read, 70, guess: 0.95),
        AnswerOutcome.right,
      );
      expect(reason, IgnoredReason.unusableGuess);
      expect(m.marginal(_read), before);
      expect(m.cleanItemsOf(_read), 0);
      expect(m.ignoredItems, 1);
    });

    test('a card asked twice counts once', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      expect(
        m.observe(_pick(_read, 70, card: 'c1'), AnswerOutcome.right),
        null,
      );
      final once = m.marginal(_read);
      expect(
        m.observe(_pick(_read, 70, card: 'c1'), AnswerOutcome.right),
        IgnoredReason.repeatedCard,
      );
      expect(m.marginal(_read), once);
      expect(m.hasAsked('c1'), isTrue);
      expect(m.cleanItemsOf(_read), 1);
      expect(m.touchesOf(_read), 2);
    });

    test('an item for a skill not in play is refused', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      expect(
        () => m.observe(_pick(_hear, 40), AnswerOutcome.right),
        throwsArgumentError,
      );
    });
  });

  group('the proven level', () {
    PlacementSkillResult run(String pattern) {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      for (var i = 0; i < pattern.length; i++) {
        m.observe(
          _pick(_read, 70 + i % 2, card: '$pattern-$i'),
          pattern[i] == 'r' ? AnswerOutcome.right : AnswerOutcome.wrong,
        );
      }
      return PlacementSkillResult(m);
    }

    test('three right answers prove nothing, however lucky', () {
      final r = run('rrr');
      expect(r.proven, isNull);
      expect(r.start, 0);
    });

    test('4 of 4 and 5 of 6 prove the band, 3 of 4 and 4 of 5 do not', () {
      expect(run('rrrr').proven, isNotNull);
      expect(run('rrrrrw').proven, isNotNull);
      expect(run('rrrw').proven, isNull);
      expect(run('rrrrw').proven, isNull);
    });

    test('the start never goes above the proven band', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      _askRight(m, _read, 40, 4);
      // Two more answers at a much higher level, right, but only two items.
      _askRight(m, _read, 95, 2);
      final read = m.readout().skills[_read]!;
      expect(read.provenClass, isNotNull);
      expect(read.startClass, lessThanOrEqualTo(read.provenClass!));
      expect(read.highClass, greaterThan(read.provenClass!));
      expect(read.cappedByProof, isTrue);
    });

    test('cognate and leaky items do not prove a band', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      for (var i = 0; i < 6; i++) {
        m.observe(
          _pick(_read, 60, card: 'cog$i', clean: false),
          AnswerOutcome.right,
        );
      }
      final read = m.readout().skills[_read]!;
      expect(read.cleanItems, 0);
      expect(read.provenClass, isNull);
      expect(read.startClass, 0);
      expect(read.coveragePassed, isFalse);
    });
  });

  group('the coverage gate and the range', () {
    test('the range is shown only after four clean items', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      _askRight(m, _read, 60, 3);
      expect(m.readout().skills[_read]!.rangeShown, isFalse);
      expect(m.readout().coveragePassed, isFalse);
      _askRight(m, _read, 61, 1);
      expect(m.readout().skills[_read]!.rangeShown, isTrue);
      expect(m.readout().coveragePassed, isTrue);
    });

    test('the start is the lower edge, below the middle', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      _askRight(m, _read, 50, 4);
      for (var i = 0; i < 4; i++) {
        m.observe(_pick(_read, 80, card: 'hi$i'), AnswerOutcome.wrong);
      }
      final read = m.readout().skills[_read]!;
      expect(read.startClass, lessThanOrEqualTo(read.medianClass));
      expect(read.lowClass, lessThanOrEqualTo(read.medianClass));
      expect(read.medianClass, lessThanOrEqualTo(read.highClass));
      expect(read.rangeMass, greaterThanOrEqualTo(kRangeMass - 1e-9));
      expect(read.startDeck, greaterThan(0));
      expect(read.startDeck, lessThanOrEqualTo(_levels().lastDeck));
    });

    test('confidence is about the true level being near the middle', () {
      final few = JointPlacement(levels: _levels(), skills: const [_read]);
      _askRight(few, _read, 60, 4);
      final lots = JointPlacement(levels: _levels(), skills: const [_read]);
      _askRight(lots, _read, 60, 4);
      for (var i = 0; i < 4; i++) {
        lots.observe(_pick(_read, 85, card: 'x$i'), AnswerOutcome.wrong);
      }
      final a = few.readout().skills[_read]!;
      final b = lots.readout().skills[_read]!;
      expect(b.nearMass, greaterThan(a.nearMass));
      expect(b.confidence, PlacementConfidence.high);
      expect(a.confidence, isNot(PlacementConfidence.high));
    });
  });

  group('Say without a recogniser', () {
    test('self-rated answers never reach the joint or the clean count', () {
      final m = JointPlacement(
        levels: _levels(),
        skills: const [_read, _hear, _say],
      );
      _askRight(m, _read, 70, 5);
      _askRight(m, _hear, 40, 5);
      final before = m.marginal(_say);
      for (var i = 0; i < 6; i++) {
        final reason = m.observe(
          JointItem(
            skills: const {_say},
            deck: 95,
            slip: 0.1,
            guess: 0.3,
            selfRated: true,
            cardId: 'say$i',
          ),
          AnswerOutcome.right,
        );
        expect(reason, IgnoredReason.selfRated);
      }
      final after = m.marginal(_say);
      for (var c = 0; c < before.length; c++) {
        expect(after[c], closeTo(before[c], 1e-12));
      }
      final say = m.readout().skills[_say]!;
      expect(say.state, EvidenceState.selfRated);
      expect(say.cleanItems, 0);
      expect(say.coveragePassed, isFalse);
      expect(say.rangeShown, isFalse);
    });

    test('Say is unplaced without a recogniser, whatever Hear shows', () {
      final m = JointPlacement(levels: _levels(), skills: const [_hear, _say]);
      // Hear is proven low; Say is only ever rated "same".
      _askRight(m, _hear, 20, 4);
      for (var i = 0; i < 8; i++) {
        m.observe(
          const JointItem(
            skills: {_say},
            deck: 90,
            slip: 0.1,
            guess: 0.3,
            selfRated: true,
          ),
          AnswerOutcome.right,
        );
      }
      final r = m.readout();
      expect(r.skills[_hear]!.startClass, greaterThan(0));
      expect(r.skills[_say]!.startClass, 0);
      expect(r.skills[_say]!.startDeck, 0);
      expect(r.skills[_say]!.highClass, 0);
    });

    test('a recogniser-scored Say is placed on its own evidence', () {
      final m = JointPlacement(levels: _levels(), skills: const [_hear, _say]);
      _askRight(m, _hear, 20, 4);
      _askRight(m, _say, 70, 4);
      final r = m.readout();
      expect(r.skills[_say]!.state, EvidenceState.tested);
      expect(
        r.skills[_say]!.startClass,
        greaterThan(r.skills[_hear]!.startClass),
      );
    });
  });

  group('yes/no and the yes-bias', () {
    test('a yes-sayer is not placed from a run of yes answers', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      for (var i = 0; i < 8; i++) {
        m.observe(_pseudo('p$i'), AnswerOutcome.right);
      }
      for (var i = 0; i < 6; i++) {
        m.observe(_realWord(70 + i % 2, 'w$i'), AnswerOutcome.right);
      }
      final read = m.readout().skills[_read]!;
      expect(m.falseAlarms, 8);
      expect(read.provenClass, isNull);
      expect(read.startClass, 0);
      // The latent bias is learnt to be high.
      final bias = m.biasPosterior();
      expect(bias.last, greaterThan(0.5));
      // And the answers hardly say the learner knows the words.
      expect(m.massKnowing(_read, 70), lessThan(0.5));
    });

    test('an honest yes/no learner is placed', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      for (var i = 0; i < 8; i++) {
        m.observe(_pseudo('p$i'), AnswerOutcome.wrong);
      }
      for (var i = 0; i < 5; i++) {
        m.observe(_realWord(70 + i % 2, 'w$i'), AnswerOutcome.right);
      }
      final read = m.readout().skills[_read]!;
      expect(read.provenClass, isNotNull);
      expect(m.massKnowing(_read, 70), greaterThan(0.9));
      expect(m.biasPosterior().first + m.biasPosterior()[1], greaterThan(0.8));
    });

    test('real-word answers are not clean until eight pseudowords', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      for (var i = 0; i < 3; i++) {
        m.observe(_pseudo('p$i'), AnswerOutcome.wrong);
      }
      for (var i = 0; i < 5; i++) {
        m.observe(_realWord(70, 'w$i'), AnswerOutcome.right);
      }
      expect(m.cleanItemsOf(_read), 0);
      expect(m.readout().skills[_read]!.provenClass, isNull);
      for (var i = 3; i < kMinPseudowords; i++) {
        m.observe(_pseudo('p$i'), AnswerOutcome.wrong);
      }
      expect(m.cleanItemsOf(_read), 5);
    });

    test('a few false alarms make the proof harder', () {
      PlacementSkillResult run(int falseAlarms, int words) {
        final m = JointPlacement(levels: _levels(), skills: const [_read]);
        for (var i = 0; i < 8; i++) {
          m.observe(
            _pseudo('p$i'),
            i < falseAlarms ? AnswerOutcome.right : AnswerOutcome.wrong,
          );
        }
        for (var i = 0; i < words; i++) {
          m.observe(_realWord(70, 'w$i'), AnswerOutcome.right);
        }
        return PlacementSkillResult(m);
      }

      expect(run(0, 4).proven, isNotNull);
      expect(run(4, 6).proven, isNull);
    });
  });

  group('items that are easy to guess', () {
    test('4 of 4 on items guessed 55% of the time proves nothing', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      for (var i = 0; i < 4; i++) {
        m.observe(
          _pick(_read, 70, card: 'g$i', guess: 0.55),
          AnswerOutcome.right,
        );
      }
      final read = m.readout().skills[_read]!;
      expect(read.provenClass, isNull);
      expect(read.cleanItems, 0);
      expect(read.coveragePassed, isFalse);
    });

    test('4 of 4 on items guessed a quarter of the time does', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      for (var i = 0; i < 4; i++) {
        m.observe(_pick(_read, 70, card: 'g$i'), AnswerOutcome.right);
      }
      expect(m.readout().skills[_read]!.provenClass, isNotNull);
    });

    test('a high-guess item still moves the posterior', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      final before = m.massKnowing(_read, 70);
      m.observe(_pick(_read, 70, guess: 0.55), AnswerOutcome.right);
      expect(m.massKnowing(_read, 70), greaterThan(before));
      expect(m.cleanItemsOf(_read), 0);
    });
  });

  group('cards and degenerate answers', () {
    test('an ignored item does not block a later real item on its card', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      expect(
        m.observe(
          _pick(_read, 70, card: 'c', guess: 0.95),
          AnswerOutcome.right,
        ),
        IgnoredReason.unusableGuess,
      );
      expect(m.hasAsked('c'), isFalse);
      expect(
        m.observe(_pick(_read, 70, card: 'c'), AnswerOutcome.right),
        isNull,
      );
      expect(m.hasAsked('c'), isTrue);
      expect(m.cleanItemsOf(_read), 1);
    });

    test('a self-rated item does not block a later scored item', () {
      final m = JointPlacement(levels: _levels(), skills: const [_say]);
      m.observe(
        const JointItem(
          skills: {_say},
          deck: 50,
          slip: 0.1,
          guess: 0.3,
          selfRated: true,
          cardId: 's',
        ),
        AnswerOutcome.right,
      );
      expect(
        m.observe(_pick(_say, 50, card: 's'), AnswerOutcome.right),
        isNull,
      );
    });

    test('an answer no hypothesis allows changes nothing', () {
      final m = JointPlacement(levels: _levels(), skills: const [_read]);
      final before = m.marginal(_read);
      // Slip 1 and guess 0: a right answer is impossible for every class.
      final reason = m.observe(
        const JointItem(skills: {_read}, deck: 70, slip: 1, guess: 0),
        AnswerOutcome.right,
      );
      expect(reason, IgnoredReason.degenerate);
      expect(m.marginal(_read), before);
    });
  });

  group('calibration', () {
    test('a cognate is unusable in a word format, a clean word is not', () {
      const cal = GuessCalibration.seed;
      expect(cal.usable('F2', true, 0.25), isFalse);
      expect(cal.usable('F2', false, 0.25), isTrue);
      expect(cal.guessFor('F2', false, 0.25), 0.35);
      expect(cal.usable('S2', false, 0.5), isTrue);
      expect(cal.usable('S2legacy', false, 0.5), isFalse);
      expect(cal.guessFor('unknown', false, 0.25), 0.25);
      // The legacy formats are reachable by their own names.
      expect(cal.guessFor('F6endings', false, 0.25), 0.99);
      expect(cal.usable('F6endings', false, 0.25), isFalse);
      expect(cal.usable('F5legacy', true, 0.25), isFalse);
      expect(cal.guessFor('F6hint', true, 0.25), 0.75);
    });

    test('the calibrated guess never falls below the design base', () {
      const cal = GuessCalibration(<String, double>{'X:clean': 0.1});
      expect(cal.guessFor('X', false, 0.25), 0.25);
    });

    test('the 90% upper bound exceeds the observed rate', () {
      expect(GuessCalibration.upperBound90(30, 100), greaterThan(0.30));
      expect(GuessCalibration.upperBound90(30, 100), lessThan(0.40));
      expect(GuessCalibration.upperBound90(0, 0), 1);
      expect(
        GuessCalibration.upperBound90(30, 1000),
        lessThan(GuessCalibration.upperBound90(30, 100)),
      );
    });

    test('shared items are weighted down', () {
      expect(sharedWeight(0), 1);
      expect(sharedWeight(2), closeTo(0.64, 1e-12));
      expect(sharedWeight(-1), 1);
    });

    test('the binomial tail matches the 4-of-4 and 5-of-6 rule', () {
      expect(binomialTail(4, 4, 0.3), lessThanOrEqualTo(kProvenTail));
      expect(binomialTail(5, 6, 0.3), lessThanOrEqualTo(kProvenTail));
      expect(binomialTail(3, 4, 0.3), greaterThan(kProvenTail));
      expect(binomialTail(4, 5, 0.3), greaterThan(kProvenTail));
      expect(binomialTail(0, 5, 0.3), 1);
      expect(binomialTail(6, 5, 0.3), 0);
    });
  });
}

/// A run's readout of Read, with its proven class and start.
class PlacementSkillResult {
  PlacementSkillResult(JointPlacement m)
    : proven = m.readout().skills[_read]!.provenClass,
      start = m.readout().skills[_read]!.startClass;
  final int? proven;
  final int start;
}
