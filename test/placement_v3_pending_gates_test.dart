// The gates of Find my level V3 that cannot be judged until a later build
// step lands (wiki/Plan-Placement-V3.md, "Revised validation gates" and
// "Build progress"), and the harness's own behaviour.
//
// Each pending gate names the file its prerequisite will add under
// lib/core/placement/. While the prerequisite is absent the gate is only
// documented here. The moment a matching file appears, the gate's test FAILS
// until the gate is enabled (moved into the enforced tests, run against the
// real picker or registry) and its entry is deleted from [_pending]. Every
// file under lib/core/placement/ is matched against the patterns, so a
// prerequisite cannot land unnoticed; the later pull requests must use the
// file names of the plan's build progress (v3_drilldown, script_gate) or
// adjust the patterns.
import 'dart:io';
import 'dart:math' as math;

import 'package:fluenough/core/placement/item_registry.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_v3_harness.dart';

class _PendingGate {
  const _PendingGate(
    this.id,
    this.gate,
    this.reason,
    this.patterns,
    this.step, {
    this.prerequisite,
  });

  final String id;

  /// The gate, as the plan states it.
  final String gate;

  /// Why it cannot be judged now.
  final String reason;

  /// Patterns of file names of lib/core/placement/ whose arrival means the
  /// prerequisite has landed.
  final List<RegExp> patterns;

  /// The build step that lands the prerequisite.
  final String step;

  /// A prerequisite that is not a file name: what the format inventory must
  /// come to hold (judged on [kFormatInventory]). Either this or a matching
  /// file means the prerequisite has landed.
  final bool Function(Iterable<FormatInfo> inventory)? prerequisite;
}

/// Whether the inventory has a generated Write item cheap enough to prove
/// the top bands: at most 6 s, slip at most 0.10, guess at most 0.10 (the
/// item class build step 4b must add; see the experts gate).
bool hasCheapWriteItem(Iterable<FormatInfo> inventory) => inventory.any(
  (f) =>
      f.generated &&
      f.skills.contains(PlacementSkill.write) &&
      f.seconds <= 6 &&
      f.slip <= 0.10 &&
      f.guess <= 0.10,
);

// The file-name patterns of the prerequisites, broad on purpose: any file
// under lib/core/placement/ (any depth) whose name has the word. The picker
// (v3_picker.dart) landed in build step 4 and enabled its gates; what is left
// waits for the later steps' files.
final List<RegExp> _formats4b = <RegExp>[RegExp(r'4b')];
final List<RegExp> _refit = <RegExp>[RegExp(r're_?fit')];
final List<RegExp> _drillDown = <RegExp>[RegExp(r'drill_?down')];
final List<RegExp> _scriptGate = <RegExp>[RegExp(r'script_?gate')];

final List<_PendingGate> _pending = <_PendingGate>[
  _PendingGate(
    'experts-natives-within-a-tenth',
    'Honest experts and natives are within 1/10 of the truth in at least '
        '85% of runs.',
    'The real picker (build step 4) meets the time gate, and with it places '
        'experts and natives safely but low: within 1/10 in 52 to 57% of '
        'runs under a flat declaration, 71 to 76% under an advanced one and '
        '3 to 4% under an amateur one (Spanish and Hindi). Placing them '
        'higher needs proof stages at the top bands (four clean items each, '
        'three skills): measured, a looser stop rule that climbs one more '
        'stage reaches 74 to 90% but costs 250 to 300 s. What is missing is '
        'a cheap item for Write: the admitted Write evidence is typing (F7, '
        '12 s, slip 0.15) or tiles (F4, 15 s) or the mixed F8 and F16 '
        '(15 s), so a Write proof costs 50 to 60 s a stage. A Write item of '
        'at most 6 s with a slip of at most 0.10 and a guess of at most 0.10 '
        '(PR 4b), or a stop rule that is not held down by a low declaration '
        '(PR 8, re-fit), would meet it. Not loosened.',
    _formats4b,
    'step 4b (cheap Write items) and step 8 (re-fit)',
    prerequisite: hasCheapWriteItem,
  ),
  _PendingGate(
    'honest-confidence',
    'The 80% credible range contains the truth in 75 to 88% of runs for '
        'every persona.',
    'The real picker gives 85 to 100% for beginners, amateurs and advanced '
        'learners (too wide), 78 to 96% for experts and natives (too wide '
        'in most cells, too narrow for natives under an amateur '
        'declaration), and 70 to 92% for ear-only learners (too narrow '
        'under an amateur declaration). The posterior\'s calibration is a '
        'joint property of the picker\'s stopping and the likelihood temper, '
        're-fitted from replay at step 8, with the temper and the '
        'declaration weight, not by the picker alone.',
    _refit,
    'step 8 (re-fit)',
  ),
  _PendingGate(
    'ear-only-placed-high-on-hear',
    'An ear-only learner is placed high on Hear and Say and low on Read and '
        'Write.',
    'The low half (Read and Write at the start) is enforced. The high half '
        'is not met: the picker proves Hear, but the joint prior (a learner '
        'is usually at one level in every skill) holds the lower edge of Hear '
        'down: Hear starts at its proven band or lower, within 1/10 of the '
        'truth in 0 to 8% of runs. The picker asks more clean items of the '
        'proven band when the prior still holds Hear at the start (it moved '
        'the median start from 1 to about 6 of 20 classes), but placing Hear '
        'at its level needs the drill-down of step 5, which finds the one '
        'skill that stands apart and spends its items there.',
    _drillDown,
    'step 5 (drill-down)',
  ),
  _PendingGate(
    'drill-down-identifies-the-failing-skill',
    'For a persona with exactly one failing skill, the right skill is '
        'identified in at least 90% of runs within 4 isolating items.',
    'There is no drill-down yet.',
    _drillDown,
    'step 5 (drill-down)',
  ),
  _PendingGate(
    'script-gate',
    'Script-literate-only learners get Read and Write at `none` with the '
        'script passed.',
    'The script gate is a separate latent that does not exist yet. The '
        'words half (no word skill placed) is enforced now.',
    _scriptGate,
    'a later step (script gate)',
  ),
];

void main() {
  group('pending gates', () {
    final files = Directory('lib/core/placement')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();

    for (final gate in _pending) {
      test('${gate.id} stays pending until ${gate.step}', () {
        final landed = <String>[
          for (final f in files)
            for (final p in gate.patterns)
              if (p.hasMatch(f)) f,
          if (gate.prerequisite?.call(kFormatInventory) ?? false)
            'the format inventory',
        ];
        expect(
          landed,
          isEmpty,
          reason:
              'The prerequisite of the gate "${gate.id}" has landed ($landed). '
              'Enable it: judge "${gate.gate}" with the real implementation '
              'in the enforced tests, then delete its entry from _pending in '
              'test/placement_v3_pending_gates_test.dart.',
        );
        // A pending gate says what it is and why it waits.
        expect(gate.gate, isNotEmpty);
        expect(gate.reason, isNotEmpty);
      });
    }

    test('every pending gate is named in the plan', () {
      final plan = File('wiki/Plan-Placement-V3.md').readAsStringSync();
      expect(plan, contains('Revised validation gates'));
      expect(plan, contains('Pending gates'));
      for (final gate in _pending) {
        expect(
          plan,
          contains('`${gate.id}`'),
          reason: 'the plan\'s Pending gates table must name `${gate.id}`',
        );
      }
    });

    test('the cheap-Write prerequisite is judged on the inventory', () {
      expect(hasCheapWriteItem(kFormatInventory), isFalse);
      const cheap = FormatInfo(
        'F99',
        'cheap write',
        {PlacementSkill.write},
        0.05,
        0.05,
        5,
      );
      expect(hasCheapWriteItem([...kFormatInventory, cheap]), isTrue);
      const slow = FormatInfo(
        'F98',
        'slow write',
        {PlacementSkill.write},
        0.05,
        0.05,
        12,
      );
      expect(hasCheapWriteItem([...kFormatInventory, slow]), isFalse);
      const notBuilt = FormatInfo(
        'F97',
        'not generated',
        {PlacementSkill.write},
        0.05,
        0.05,
        5,
        generated: false,
      );
      expect(hasCheapWriteItem([...kFormatInventory, notBuilt]), isFalse);
    });

    test('the patterns match what they are meant to', () {
      expect(_formats4b.single.hasMatch('item_generators_4b.dart'), isTrue);
      expect(_refit.single.hasMatch('v3_refit.dart'), isTrue);
      expect(_refit.single.hasMatch('v3_re_fit.dart'), isTrue);
      expect(_drillDown.single.hasMatch('v3_drill_down.dart'), isTrue);
      expect(_drillDown.single.hasMatch('drilldown.dart'), isTrue);
      expect(_scriptGate.single.hasMatch('script_gate.dart'), isTrue);
      // None matches a file that exists today: the gates are pending. The
      // picker (v3_picker.dart) has landed and its gates are enforced.
      for (final f in files) {
        for (final p in [
          ..._formats4b,
          ..._refit,
          ..._drillDown,
          ..._scriptGate,
        ]) {
          expect(p.hasMatch(f), isFalse, reason: f);
        }
      }
    });
  });

  group('the harness', () {
    late SimBank bank;
    setUpAll(() => bank = leakLanguages()['es']!.bank());

    test('a run is a function of its seed', () {
      RunResult run(int seed) => runOnce(
        bank: bank,
        persona: Persona(
          'a',
          truth: {
            PlacementSkill.read: 7,
            PlacementSkill.hear: 7,
            PlacementSkill.write: 7,
          },
        ),
        picker: V3SimPicker(),
        declaration: null,
        variant: Variant.full,
        seed: seed,
      );
      final a = run(3);
      final b = run(3);
      expect(a.items, b.items);
      expect(a.seconds, b.seconds);
      for (final skill in a.skills.keys) {
        expect(a.skills[skill]!.start, b.skills[skill]!.start);
        expect(a.skills[skill]!.low, b.skills[skill]!.low);
        expect(a.skills[skill]!.high, b.skills[skill]!.high);
      }
      var differs = false;
      for (var seed = 4; seed < 12; seed++) {
        if (run(seed).items != a.items) differs = true;
      }
      expect(differs, isTrue, reason: 'seeds make runs differ');
    });

    test('any picker can be run, including one that stops at once', () {
      final result = runOnce(
        bank: bank,
        persona: Persona('a', truth: {PlacementSkill.read: 5}),
        picker: _NeverAsks(),
        declaration: null,
        variant: Variant.noAudio,
        seed: 1,
      );
      expect(result.items, 0);
      expect(result.seconds, 0);
      for (final s in result.skills.values) {
        expect(s.state, EvidenceState.notTested);
        expect(s.clean, 0);
        expect(s.rangeShown, isFalse);
        expect(s.start, 0);
      }
    });

    test('a picker that asks one card repeatedly is caught', () {
      final result = runOnce(
        bank: bank,
        persona: Persona('a', truth: {PlacementSkill.read: 5}),
        picker: _AsksOneCard(),
        declaration: null,
        variant: Variant.noAudio,
        seed: 1,
      );
      expect(result.repeatedCard, isTrue);
    });

    test('the simulated bank is deterministic and has its cognate share', () {
      final again = leakLanguages()['es']!.bank();
      expect(again.cards.length, bank.cards.length);
      expect(
        [for (final c in again.cards.take(50)) c.cognate],
        [for (final c in bank.cards.take(50)) c.cognate],
      );
      final share =
          bank.cards.where((c) => c.cognate).length / bank.cards.length;
      expect(share, closeTo(0.35, 0.05));
      expect(bank.deckCount, 171);
    });

    test('truth helpers place a learner on the class grid', () {
      final levels = bank.levels;
      expect(levels.parts, 20);
      expect(classAtTenth(levels, 10), levels.topClass);
      expect(classKnowingUpTo(levels, 11), 2);
      expect(classKnowingUpTo(levels, -1), 0);
      expect(classAtTenth(levels, 3), lessThan(classAtTenth(levels, 7)));
    });

    test('percentile and share', () {
      expect(percentile(<num>[1, 2, 3, 4, 5], 0.5), 3);
      expect(percentile(<num>[1, 2, 3, 4, 5], 0.95), 5);
      expect(percentile(<num>[], 0.5), 0);
      expect(share<int>([1, 2, 3, 4], (v) => v > 2), 0.5);
      expect(share<int>([], (v) => true), 0);
    });

    test('the leak profile has the legacy and the fixed tables', () {
      for (final lang in leakLanguages().values) {
        for (final profile in BankProfile.values) {
          for (final code in <String>['F2', 'F4', 'F5', 'F6', 'F13', 'F17']) {
            for (final cognate in <bool>[false, true]) {
              final r = lang.rate(code, cognate, profile, true);
              expect(r, inInclusiveRange(0, 1));
            }
          }
        }
        // The fixed bank is what the generators must reach: clean accuracy
        // within the admission bound (guess plus 0.07) of the format.
        for (final code in <String>['F2', 'F3', 'F5', 'F6', 'F13', 'F17']) {
          final spec = kFormats[code]!;
          final bound = math.max(spec.guess + 0.07, 0.32);
          expect(
            lang.rate(code, false, BankProfile.fixed, true),
            lessThanOrEqualTo(bound + 1e-9),
            reason: '$code in ${lang.code}',
          );
        }
      }
    });

    test('the legacy bank is the one the adversary beat', () {
      final es = leakLanguages()['es']!;
      // A sentence pick answered 75% right by a gamer beyond its words is far
      // over the 0.9 line only after calibration drops it: the legacy key is
      // unusable.
      expect(
        GuessCalibration.seed.usable(
          formatKey('F5', BankProfile.legacy),
          false,
          0.25,
        ),
        isFalse,
      );
      expect(
        GuessCalibration.seed.usable(
          formatKey('F5', BankProfile.fixed),
          false,
          0.25,
        ),
        isTrue,
      );
      expect(es.rate('F5', false, BankProfile.legacy, true), greaterThan(0.7));
    });
  });
}

class _NeverAsks implements SimPicker {
  @override
  String get name => 'never';

  @override
  SimItem? next(RunState state) => null;
}

class _AsksOneCard implements SimPicker {
  @override
  String get name => 'one-card';

  @override
  SimItem? next(RunState state) {
    if (state.items >= 3) return null;
    return SimItem(state.bank.cards.first, kFormats['F2']!);
  }
}
