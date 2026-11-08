// The isolating drill-down of Find my level V3 (lib/core/placement/
// drill_down.dart, wiki/Plan-Placement-V3.md "Phase 2"): when it starts, whom
// it asks, when it stops, and the gate that, for a learner with exactly one
// failing skill, it names the right skill within 4 isolating items in at
// least 90% of the runs in which it started.
@Timeout(Duration(minutes: 15))
library;

import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/drill_down.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/v3_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_v3_harness.dart';

const _read = PlacementSkill.read;
const _hear = PlacementSkill.hear;
const _write = PlacementSkill.write;
const _all = <PlacementSkill>[_read, _hear, _write];

JointItem _item(
  Set<PlacementSkill> skills,
  int deck,
  String id, {
  double slip = 0.05,
  double guess = 0.25,
}) => JointItem(
  skills: skills,
  deck: deck,
  slip: slip,
  guess: guess,
  weight: 1,
  clean: true,
  cardId: id,
);

void main() {
  late SimBank bank;
  late PlacementLevels levels;

  setUpAll(() {
    bank = leakLanguages()['es']!.bank();
    levels = bank.levels;
  });

  JointPlacement model() => JointPlacement(levels: levels, skills: _all);

  group('the state machine', () {
    test('a wrong answer on a mixed item implicates the skills that failed '
        'it, the likeliest first, and asks one of them next', () {
      final m = model();
      final d = DrillDown(m);
      final item = _item({_hear, _write}, 76, 'a');
      final pre = (
        known: <PlacementSkill, double>{
          _hear: m.probabilityKnown([_hear], 76),
          _write: m.probabilityKnown([_write], 76),
        },
        all: m.probabilityKnown([_hear, _write], 76),
      );
      m.observe(item, AnswerOutcome.wrong);
      final started = d.onAnswer(
        itemSkills: [_hear, _write],
        deck: 76,
        band: 5,
        right: false,
        preKnown: pre.known,
        preAll: pre.all,
        seconds: 10,
        testable: _all,
      );
      expect(started, isNotNull);
      expect(started!.trigger, DrillTrigger.mixedWrong);
      expect(started.skills.toSet(), {_hear, _write});
      expect(d.active, same(started));
      expect(d.next(), isIn(<PlacementSkill>[_hear, _write]));
    });

    test('a right answer a skill was unlikely to give is a lucky guess and '
        'implicates that skill', () {
      final m = model();
      // The learner has failed Hear high up, so Hear at 140 is unlikely.
      for (var i = 0; i < 4; i++) {
        m.observe(_item({_hear}, 140, 'h$i'), AnswerOutcome.wrong);
      }
      final d = DrillDown(m);
      final pre = m.probabilityKnown([_hear], 140);
      expect(pre, lessThan(0.2));
      m.observe(_item({_hear}, 140, 'lucky'), AnswerOutcome.right);
      final started = d.onAnswer(
        itemSkills: [_hear],
        deck: 140,
        band: 8,
        right: true,
        preKnown: {_hear: pre},
        preAll: pre,
        seconds: 10,
        testable: _all,
      );
      expect(started?.trigger, DrillTrigger.luckyRight);
      expect(started?.skills, [_hear]);
    });

    test('each trigger is processed once per skill and band, a drill-down '
        'asks at most 4 isolating items, and a run has at most 3', () {
      final m = model();
      final d = DrillDown(m);
      DrillCase? start(int deck, int band, String id) {
        final pre = m.probabilityKnown([_read, _write], deck);
        m.observe(_item({_read, _write}, deck, id), AnswerOutcome.wrong);
        return d.onAnswer(
          itemSkills: [_read, _write],
          deck: deck,
          band: band,
          right: false,
          preKnown: {
            _read: m.probabilityKnown([_read], deck),
            _write: m.probabilityKnown([_write], deck),
          },
          preAll: pre,
          seconds: 10,
          testable: _all,
        );
      }

      final first = start(60, 4, 'a');
      expect(first, isNotNull);
      // Four isolating items end it whatever they say.
      var asked = 0;
      while (d.next() != null && asked < 10) {
        final s = d.next()!;
        m.observe(_item({s}, 60, 'i$asked'), AnswerOutcome.wrong);
        d.onIsolating(s, right: false, slip: 0.05, guess: 0.25);
        asked++;
      }
      expect(first!.isolating, lessThanOrEqualTo(4));
      expect(first.closed, isTrue);
      // The same skills at the same band do not start another.
      expect(start(61, 4, 'b'), isNull);
      // Another band does, up to two in all.
      expect(start(100, 6, 'c'), isNotNull);
      d.active?.end = DrillEnd.budget;
      d.active = null;
      expect(start(130, 8, 'd'), isNull);
      expect(d.cases.length, 2);
    });

    test('no drill-down starts late in the run, or when it is turned off', () {
      final m = model();
      final late = DrillDown(m);
      m.observe(_item({_read, _write}, 60, 'a'), AnswerOutcome.wrong);
      expect(
        late.onAnswer(
          itemSkills: [_read, _write],
          deck: 60,
          band: 4,
          right: false,
          preKnown: {_read: 0.5, _write: 0.5},
          preAll: 0.3,
          seconds: 250,
          testable: _all,
        ),
        isNull,
      );
      final off = DrillDown(m, config: const DrillConfig(enabled: false));
      expect(
        off.onAnswer(
          itemSkills: [_read, _write],
          deck: 60,
          band: 4,
          right: false,
          preKnown: {_read: 0.5, _write: 0.5},
          preAll: 0.3,
          seconds: 10,
          testable: _all,
        ),
        isNull,
      );
    });

    test('the failing skill is named only after two checks of it (a slip is '
        'forgiven), and a skill that was asked right twice is cleared', () {
      final m = model();
      final d = DrillDown(m);
      m.observe(_item({_read, _write}, 70, 'a'), AnswerOutcome.wrong);
      final c = d.onAnswer(
        itemSkills: [_read, _write],
        deck: 70,
        band: 5,
        right: false,
        preKnown: {_read: 0.6, _write: 0.6},
        preAll: 0.5,
        seconds: 10,
        testable: _all,
      )!;
      // One wrong check of Write alone does not name it.
      d.onIsolating(_write, right: false, slip: 0.08, guess: 0.10);
      expect(c.closed, isFalse);
      d.onIsolating(_read, right: true, slip: 0.05, guess: 0.25);
      expect(c.closed, isFalse);
      // The second wrong check does.
      d.onIsolating(_write, right: false, slip: 0.08, guess: 0.10);
      expect(c.closed, isTrue);
      expect(c.end, DrillEnd.identified);
      expect(c.verdict, _write);
      expect(c.isolating, 3);
    });
  });

  group('the picker with the drill-down', () {
    ({RunResult result, V3SimPicker sim}) run(
      Map<PlacementSkill, int> truth, {
      Variant variant = Variant.full,
      int seed = 1,
      PickerConfig? config,
    }) {
      final p = V3SimPicker(config: config);
      final r = runOnce(
        bank: bank,
        persona: Persona('p', truth: truth),
        picker: p,
        declaration: null,
        variant: variant,
        seed: seed,
      );
      return (result: r, sim: p);
    }

    Map<PlacementSkill, int> truth(double read, double hear, double write) {
      int c(double t) => t <= 0 ? 0 : classAtTenth(levels, t);
      return {_read: c(read), _hear: c(hear), _write: c(write)};
    }

    test('the isolating items are single-skill items of the admitted '
        'formats and no card is asked twice', () {
      for (var seed = 1; seed <= 30; seed++) {
        final p = run(truth(9, 9, 2), seed: seed).sim.picker!;
        final keys = <String>[for (final c in p.asked) ...c.conflictKeys];
        expect(keys.toSet().length, keys.length, reason: 'seed $seed');
        for (final c in p.asked) {
          expect(kAdmittedFormats, contains(c.format));
        }
      }
    });

    test('Read and Write are isolated with no audio at all', () {
      for (var seed = 1; seed <= 30; seed++) {
        final r = run(truth(2, 0, 9), variant: Variant.noAudio, seed: seed);
        final p = r.sim.picker!;
        for (final c in p.asked) {
          expect(c.needsAudio, isFalse);
        }
        for (final k in p.drillDown.cases) {
          expect(k.skills, everyElement(isNot(_hear)));
        }
        expect(r.result.skills.containsKey(_hear), isFalse);
      }
    });

    test('Say is isolated only with a recogniser', () {
      for (var seed = 1; seed <= 10; seed++) {
        final p = run(truth(7, 7, 2), seed: seed).sim.picker!;
        for (final k in p.drillDown.cases) {
          expect(k.skills, everyElement(isNot(PlacementSkill.say)));
        }
      }
    });

    test('a run with the drill-down turned off has no case', () {
      final p = run(
        truth(9, 9, 2),
        config: const PickerConfig(drill: DrillConfig(enabled: false)),
      ).sim.picker!;
      expect(p.drillDown.cases, isEmpty);
    });

    test('the drill-down stays inside the caps', () {
      for (var seed = 1; seed <= 40; seed++) {
        final r = run(truth(9, 9, 2), seed: seed);
        expect(r.result.items, lessThanOrEqualTo(40));
        expect(r.result.seconds, lessThanOrEqualTo(300));
        for (final k in r.sim.picker!.drillDown.cases) {
          expect(k.isolating, lessThanOrEqualTo(4));
        }
      }
    });
  });

  // The gate: a learner with exactly one failing skill, the other two strong.
  for (final code in <String>['es', 'hi']) {
    group('the drill-down gate ($code)', () {
      late SimBank b;
      late PlacementLevels lv;
      setUpAll(() {
        b = leakLanguages()[code]!.bank();
        lv = b.levels;
      });

      for (final weak in _all) {
        for (final strong in <double>[7, 9]) {
          test('names $weak within 4 isolating items in at least 90% of the '
              'runs it started in (others at $strong tenths)', () {
            int c(double t) => classAtTenth(lv, t);
            final t = <PlacementSkill, int>{
              for (final s in _all) s: c(s == weak ? 2 : strong),
            };
            var withCase = 0;
            var ok = 0;
            for (var seed = 1; seed <= 100; seed++) {
              final p = V3SimPicker();
              runOnce(
                bank: b,
                persona: Persona('w', truth: t),
                picker: p,
                declaration: null,
                variant: Variant.full,
                seed: seed,
              );
              final cases = p.picker!.drillDown.cases
                  .where((k) => k.skills.length >= 2)
                  .toList();
              if (cases.isEmpty) continue;
              withCase++;
              // A drill-down names the weak skill when it was implicated, and
              // clears them all when it was not (a slip on a mixed item).
              final good = cases.every(
                (k) =>
                    k.isolating <= 4 &&
                    (k.skills.contains(weak)
                        ? k.verdict == weak
                        : k.verdict == null),
              );
              if (good) ok++;
            }
            // It started in nearly every run (a mixed item opens each one).
            expect(withCase, greaterThanOrEqualTo(90));
            expect(ok / withCase, greaterThanOrEqualTo(0.9));
          });
        }
      }
    });
  }
}
