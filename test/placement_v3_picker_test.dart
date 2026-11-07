// The picker of Find my level V3 (lib/core/placement/v3_picker.dart): what it
// may ask, in which order, and where it stops. The gates over many simulated
// learners are in the honest, gamer and adversary tests; these are the
// picker's own rules, on single runs.
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/v3_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_v3_harness.dart';

const _read = PlacementSkill.read;
const _hear = PlacementSkill.hear;
const _write = PlacementSkill.write;
const _say = PlacementSkill.say;

void main() {
  late SimBank bank;
  late PlacementLevels levels;

  setUpAll(() {
    bank = leakLanguages()['es']!.bank();
    levels = bank.levels;
  });

  Persona persona(double tenth) {
    final c = tenth <= 0 ? 0 : classAtTenth(levels, tenth);
    return Persona('p', truth: {_read: c, _hear: c, _write: c});
  }

  ({RunResult result, V3Picker picker}) run(
    double tenth, {
    Variant variant = Variant.full,
    PickerConfig? config,
    int seed = 1,
    bool yesNoBlock = false,
  }) {
    final p = V3SimPicker(config: config, yesNoBlock: yesNoBlock);
    final r = runOnce(
      bank: bank,
      persona: persona(tenth),
      picker: p,
      declaration: null,
      variant: variant,
      seed: seed,
    );
    return (result: r, picker: p.picker!);
  }

  test('no more than two items of one format in a row, over many runs', () {
    for (var seed = 1; seed <= 12; seed++) {
      for (final tenth in <double>[0, 3, 7, 10]) {
        final asked = run(tenth, seed: seed).picker.asked;
        var streak = 1;
        for (var i = 1; i < asked.length; i++) {
          streak = asked[i].format == asked[i - 1].format ? streak + 1 : 1;
          expect(streak, lessThanOrEqualTo(2), reason: 'seed $seed at $tenth');
        }
      }
    }
  });

  test('a card is never asked twice and an item never repeats a key', () {
    for (var seed = 1; seed <= 12; seed++) {
      final asked = run(5, seed: seed).picker.asked;
      final keys = <String>[for (final c in asked) ...c.conflictKeys];
      expect(keys.toSet().length, keys.length, reason: 'seed $seed');
    }
  });

  test('every skill in play gets four clean items', () {
    for (var seed = 1; seed <= 12; seed++) {
      for (final tenth in <double>[0, 4, 9]) {
        final r = run(tenth, seed: seed).result;
        for (final s in r.skills.values) {
          expect(s.clean, greaterThanOrEqualTo(4), reason: '$seed $tenth');
        }
      }
    }
  });

  test('Hear and Say are not asked without audio, Say not without a mic', () {
    final noAudio = run(5, variant: Variant.noAudio).picker.asked;
    expect(noAudio.where((c) => c.needsAudio), isEmpty);
    final noMic = run(5, variant: Variant.noMic).picker.asked;
    expect(noMic.where((c) => c.needsMic), isEmpty);
    expect(noMic.any((c) => c.skills.contains(_hear)), isTrue);
  });

  test('without a recogniser Say is only self-rated and never evidence', () {
    final r = run(7);
    final say = r.picker.asked.where((c) => c.skills.contains(_say)).toList();
    expect(say, isNotEmpty, reason: 'the learner rates Say a little');
    for (final c in say) {
      expect(c.selfRated, isTrue);
      expect(c.clean, isFalse);
    }
    // No Say item is among the clean ones of any word skill, and Say is not
    // placed.
    expect(r.result.skills.containsKey(_say), isFalse);
  });

  test('with a recogniser Say is tested like the other skills', () {
    final p = V3SimPicker();
    final r = runOnce(
      bank: bank,
      persona: Persona(
        'p',
        truth: {
          _read: classAtTenth(levels, 5),
          _hear: classAtTenth(levels, 5),
          _write: classAtTenth(levels, 5),
          _say: classAtTenth(levels, 5),
        },
      ),
      picker: p,
      declaration: null,
      variant: Variant.withRecogniser,
      seed: 3,
      sayInJoint: true,
    );
    expect(r.skills.containsKey(_say), isTrue);
    expect(
      p.picker!.asked.where((c) => c.skills.contains(_say) && !c.selfRated),
      isNotEmpty,
    );
  });

  test('only admitted formats are asked', () {
    for (var seed = 1; seed <= 6; seed++) {
      for (final c in run(6, seed: seed).picker.asked) {
        expect(kAdmittedFormats, contains(c.format));
      }
    }
  });

  test('a beginner is not drilled to the caps', () {
    final r = run(0).result;
    expect(r.items, lessThan(30));
    for (final s in r.skills.values) {
      expect(s.start, lessThanOrEqualTo(2));
    }
  });

  test('the soft stop signal is raised at the configured item count', () {
    final p = V3SimPicker(config: const PickerConfig(softStopItems: 10));
    runOnce(
      bank: bank,
      persona: persona(6),
      picker: p,
      declaration: null,
      variant: Variant.full,
      seed: 2,
    );
    final picker = p.picker!;
    expect(picker.items, greaterThanOrEqualTo(10));
    expect(picker.softStop, isTrue);
    // A short run never reaches it.
    final q = V3SimPicker(config: const PickerConfig(softStopItems: 80));
    runOnce(
      bank: bank,
      persona: persona(6),
      picker: q,
      declaration: null,
      variant: Variant.full,
      seed: 2,
    );
    expect(q.picker!.softStop, isFalse);
  });

  test('the caps bound a run: items, seconds and touches a skill', () {
    final r = run(6, config: const PickerConfig(maxItems: 9, maxSeconds: 60));
    expect(r.result.items, lessThanOrEqualTo(9));
    expect(r.result.seconds, lessThanOrEqualTo(60));
    final tight = run(6, config: const PickerConfig(skillCap: 3));
    expect(tight.result.items, lessThanOrEqualTo(3 * 4));
  });

  test('a run is a function of the seed', () {
    final a = run(5, seed: 7).picker.asked.map((c) => c.id).toList();
    final b = run(5, seed: 7).picker.asked.map((c) => c.id).toList();
    expect(a, b);
    final c = run(5, seed: 8).picker.asked.map((c) => c.id).toList();
    expect(c, isNot(a));
  });

  test('the yes/no block opens with the pseudowords', () {
    final asked = run(5, yesNoBlock: true).picker.asked;
    for (var i = 0; i < kMinPseudowords; i++) {
      expect(asked[i].pseudo, isTrue, reason: 'item $i');
    }
  });

  test('a learner placed high is asked high bands (proof stages climb)', () {
    final asked = run(9.5).picker.asked;
    final top = asked
        .where((c) => !c.pseudo)
        .map((c) => CandidatePool.bandOfDeck(levels, c.deck))
        .reduce((a, b) => a > b ? a : b);
    expect(top, greaterThanOrEqualTo(8));
  });
}
