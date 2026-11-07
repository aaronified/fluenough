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
// file names of the plan's build progress (v3_picker,
// v3_drilldown, script_gate) or adjust the patterns.
import 'dart:io';
import 'dart:math' as math;

import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_v3_harness.dart';

class _PendingGate {
  const _PendingGate(this.id, this.gate, this.reason, this.patterns, this.step);

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
}

// The file-name patterns of the prerequisites, broad on purpose: any file
// under lib/core/placement/ (any depth) whose name has the word.
final List<RegExp> _picker = <RegExp>[
  // The V2 picker, item_picker.dart, is not the V3 one.
  RegExp(r'^(?!item_picker\.dart$).*picker'),
];
final List<RegExp> _drillDown = <RegExp>[RegExp(r'drill_?down')];
final List<RegExp> _scriptGate = <RegExp>[RegExp(r'script_?gate')];

final List<_PendingGate> _pending = <_PendingGate>[
  _PendingGate(
    'time-and-items',
    'Median at most 28 items and 200 s, 95th percentile at most 40 items and '
        '300 s, for every honest persona.',
    'The length of a run is decided by the picker and its stop rules. The '
        'stand-in picker of the harness measured 22 to 30 items and 216 to 301 '
        's medians (95th percentile 30 to 32 items, about 305 s), over the '
        'gate. The time table (tiles 15 s, typing 12 s) makes Write the '
        'costly skill. Not loosened: security needs four clean items a band.',
    _picker,
    'step 4 (picker, rotation, caps)',
  ),
  _PendingGate(
    'experts-natives-within-a-tenth',
    'Honest experts and natives are within 1/10 of the truth in at least '
        '85% of runs.',
    'It needs a picker that climbs to the top band cheaply. The stand-in '
        'places them safely but low (within 1/10 in 0 to 60% of runs) because '
        'its proof stages run out of the 300 s.',
    _picker,
    'step 4 (picker, rotation, caps)',
  ),
  _PendingGate(
    'honest-confidence',
    'The 80% credible range contains the truth in 75 to 88% of runs for '
        'every persona.',
    'The stand-in picker gives 65 to 100% depending on the cell (too '
        'wide for mid learners, too narrow for natives under a low '
        'declaration). The posterior\'s calibration is a joint property of '
        'the picker\'s stopping and the likelihood temper, re-fitted from '
        'replay then.',
    _picker,
    'step 4 (picker) and step 8 (re-fit)',
  ),
  _PendingGate(
    'ear-only-placed-high-on-hear',
    'An ear-only learner is placed high on Hear and Say and low on Read and '
        'Write.',
    'The stand-in proves one band for all skills, so Read and Write failing '
        'holds Hear down. The low half (Read and Write at the start) is '
        'enforced now. Needs a per-skill drill-down.',
    [..._picker, ..._drillDown],
    'step 4 and step 5 (picker, drill-down)',
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

    test('the patterns match what they are meant to and not the V2 picker', () {
      expect(_picker.single.hasMatch('v3_picker.dart'), isTrue);
      expect(_picker.single.hasMatch('item_picker.dart'), isFalse);
      expect(_picker.single.hasMatch('picker_v3.dart'), isTrue);
      expect(_drillDown.single.hasMatch('v3_drill_down.dart'), isTrue);
      expect(_drillDown.single.hasMatch('drilldown.dart'), isTrue);
      expect(_scriptGate.single.hasMatch('script_gate.dart'), isTrue);
      // None matches a file that exists today: the gates are pending.
      for (final f in files) {
        for (final p in [..._picker, ..._drillDown, ..._scriptGate]) {
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
        picker: BaselinePicker(),
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
