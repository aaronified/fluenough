// The calibration profile of Find my level V3: the built-in default is the
// constants the gates were measured with, a file may override any value for a
// language or a level band within strict clamps, a kill switch puts the
// default back, a malformed file is never an error, and a run reads its
// constants from the profile it is given.
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_profile.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/v3_grading.dart';
import 'package:fluenough/core/placement/v3_picker.dart';
import 'package:fluenough/core/placement/v3_session.dart';
import 'package:fluenough/core/placement/item_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/find_level_fixture.dart';
import 'support/v3_small_bank.dart';

String _file({
  bool kill = false,
  String def = '{"version": 1}',
  String langs = '{}',
}) =>
    '{"schema": 1, "killSwitch": $kill, "default": $def, "languages": $langs}';

void main() {
  group('the built-in default', () {
    test('is the constants the gates were measured with', () {
      const p = PlacementProfile.defaults;
      expect(p.declarationWeight, kMaxDeclarationWeight);
      expect(p.togetherShare, kTogetherShare);
      expect(p.temper, kTemper);
      expect(p.guessScale, isEmpty);
      expect(p.slipScale, isEmpty);
      expect(p.secondsScale, isEmpty);
      expect(p.climbQuantile, const PickerConfig().climbQuantile);
      expect(p.standApartItems, const PickerConfig().standApartItems);
      expect(p.mixedBonus, const PickerConfig().mixedBonus);
      expect(p.f4DecoyKey, isFalse);
      expect(PlacementProfiles.builtIn.resolve('es', PlacementBand.a1), p);
    });

    test('gives the picker and the model exactly what they had', () {
      final a = PickerConfig.forRun(audio: true, mic: true, recogniser: false);
      final b = PickerConfig.forRun(
        audio: true,
        mic: true,
        recogniser: false,
        profile: PlacementProfile.defaults,
      );
      expect(b.mixedBonus, a.mixedBonus);
      expect(b.standApartItems, a.standApartItems);
      expect(b.climbQuantile, a.climbQuantile);
      final gated = PickerConfig.forRun(
        audio: true,
        mic: true,
        recogniser: false,
        gateItems: 3,
        gateSeconds: 12,
      );
      expect(gated.mixedBonus, kScriptRunMixedBonus);
      expect(gated.standApartItems, kScriptRunStandApartItems);
      for (final item in smallV3Bank()) {
        final c = PickerCandidate.fromItem(item);
        final d = PickerCandidate.fromItem(
          item,
          profile: PlacementProfile.defaults,
        );
        expect(
          <Object>[d.guess, d.slip, d.seconds, d.clean],
          <Object>[c.guess, c.slip, c.seconds, c.clean],
        );
      }
    });
  });

  group('a profile file', () {
    test('overrides a language and a band, each over the one before', () {
      final profiles = PlacementProfiles.parse(
        _file(
          def: '{"version": 2, "temper": 0.9}',
          langs:
              '{"hi": {"version": 3, "declarationWeight": 0.5, '
              '"bands": {"A1": {"temper": 0.8}}}}',
        ),
      );
      expect(profiles.resolve('es', PlacementBand.a1).temper, 0.9);
      expect(profiles.resolve('es', PlacementBand.a1).version, 2);
      final hi = profiles.resolve('hi', PlacementBand.b1);
      expect(hi.version, 3);
      expect(hi.declarationWeight, 0.5);
      expect(hi.temper, 0.9);
      expect(profiles.resolve('hi', PlacementBand.a1).temper, 0.8);
    });

    test('is clamped to the ranges the gates ran over', () {
      final p = PlacementProfiles.parse(
        _file(
          def:
              '{"declarationWeight": 5, "togetherShare": -1, "temper": 0, '
              '"climbQuantile": 9, "standApartItems": 99, "mixedBonus": 3, '
              '"cognateThreshold": 0.1, '
              '"guessScale": {"F2": 9, "F3": 0.1}, '
              '"slipScale": {"F2": 9}, "secondsScale": {"F4": 0}}',
        ),
      ).resolve('es', PlacementBand.a1);
      expect(p.declarationWeight, 0.7);
      expect(p.togetherShare, 0.3);
      expect(p.temper, 0.6);
      expect(p.climbQuantile, 0.3);
      expect(p.standApartItems, 20);
      expect(p.mixedBonus, 0.6);
      expect(p.cognateThreshold, 0.4);
      expect(p.guessScale, <String, double>{'F2': 1.5, 'F3': 0.8});
      expect(p.slipScale['F2'], 2.0);
      expect(p.secondsScale['F4'], 0.5);
    });

    test('the kill switch puts the default back for everyone', () {
      final p = PlacementProfiles.parse(
        _file(
          kill: true,
          def: '{"temper": 0.7}',
          langs: '{"es": {"temper": 0.7}}',
        ),
      );
      expect(p.killSwitch, isTrue);
      expect(p.resolve('es', PlacementBand.b1), PlacementProfile.defaults);
    });

    test('a malformed file is the default, never an error', () {
      for (final text in <String?>[
        null,
        '',
        'not json',
        '[]',
        '{"schema": 2}',
        '{"schema": 1, "default": 5, "languages": 7}',
      ]) {
        expect(
          PlacementProfiles.parse(text).resolve('es', PlacementBand.a1),
          PlacementProfile.defaults,
          reason: '$text',
        );
      }
      // A value of the wrong kind is left as it was.
      final p = PlacementProfiles.parse(
        _file(def: '{"temper": "high", "f4DecoyKey": 1, "version": 0}'),
      ).resolve('es', PlacementBand.a1);
      expect(p.temper, kTemper);
      expect(p.f4DecoyKey, isFalse);
      expect(p.version, 1);
    });
  });

  group('a run reads the profile it is given', () {
    const profile = PlacementProfile(
      version: 7,
      declarationWeight: 0.2,
      temper: 0.7,
      togetherShare: 0.4,
    );

    test('the model gets its prior and its temper from it', () {
      final run = V3Run(
        data: findLevelData(),
        skills: const <PlacementSkill>{PlacementSkill.read},
        audio: false,
        recogniser: false,
        seed: 1,
        scriptStart: V3ScriptStart.skip,
        profile: profile,
        items: smallV3Bank(),
      );
      expect(run.model!.declarationWeight, 0.2);
      expect(run.model!.temper, 0.7);
      expect(run.model!.togetherShare, 0.4);
      expect(run.profile.version, 7);
    });

    test('a format\'s multipliers reach the candidates', () {
      final f2 = smallV3Bank(formats: <String>{'F2'}).first;
      final base = PickerCandidate.fromItem(f2);
      final scaled = PickerCandidate.fromItem(
        f2,
        profile: const PlacementProfile(
          guessScale: <String, double>{'F2': 1.2},
          slipScale: <String, double>{'F2': 2},
          secondsScale: <String, double>{'F2': 0.5},
        ),
      );
      expect(scaled.guess, closeTo(base.guess * 1.2, 1e-12));
      expect(scaled.slip, base.slip * 2);
      expect(scaled.seconds, base.seconds * 0.5);
    });

    test('word tiles take the decoy calibration only when it is asked', () {
      final tiles = RegItem(
        id: 't:F4',
        format: 'F4',
        cardId: 't',
        deck: 0,
        prompt: 'x',
        tiles: const <String>['a', 'b', 'c'],
        answerTiles: const <String>['a', 'b'],
        accepted: const <String>['ab'],
        decoyCount: 2,
      );
      expect(PickerCandidate.fromItem(tiles).clean, isFalse);
      expect(
        PickerCandidate.fromItem(
          tiles,
          profile: const PlacementProfile(f4DecoyKey: true),
        ).clean,
        isTrue,
      );
    });
  });

  group('another word order of a sentence', () {
    final item = RegItem(
      id: 's:F8',
      format: 'F8',
      cardId: 's',
      deck: 0,
      prompt: 'I eat bread',
      tiles: const <String>['roti', 'main', 'khata', 'hun', 'ghar'],
      answerTiles: const <String>['main', 'roti', 'khata', 'hun'],
      alternatives: const <List<String>>[
        <String>['roti', 'main', 'khata', 'hun'],
      ],
    );

    test('is as right as the sentence\'s own, and another is not', () {
      // tiles: roti 0, main 1, khata 2, hun 3, ghar 4
      expect(gradeTiles(item, <int>[1, 0, 2, 3]).name, 'right');
      expect(gradeTiles(item, <int>[0, 1, 2, 3]).name, 'right');
      expect(gradeTiles(item, <int>[3, 2, 1, 0]).name, 'wrong');
      expect(gradeTiles(item, <int>[1, 0, 2, 4]).name, 'wrong');
    });
  });
}
