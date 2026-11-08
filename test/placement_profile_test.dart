// The calibration profile of Find my level V3: the built-in default is the
// constants the gates were measured with, a file may override any value for a
// language or a level band within strict clamps, a kill switch puts the
// default back, a malformed file is never an error, and a run reads its
// constants from the profile it is given.
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/placement/item_generators.dart';
import 'package:fluenough/core/placement/placement_profile.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/v3_grading.dart';
import 'package:fluenough/core/placement/v3_picker.dart';
import 'package:fluenough/core/placement/v3_session.dart';
import 'package:fluenough/core/placement/item_registry.dart';

import 'dart:convert';
import 'dart:io';

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
          def: '{"version": 2, "temper": 0.8}',
          langs:
              '{"es": {"version": 3, "declarationWeight": 0.5, '
              '"bands": {"A1": {"temper": 0.75}}}}',
        ),
      );
      expect(profiles.resolve('fr', PlacementBand.a1).version, 2);
      final es = profiles.resolve('es', PlacementBand.b1);
      expect(es.version, 3);
      expect(es.declarationWeight, 0.5);
      expect(es.temper, 0.8);
      expect(profiles.resolve('es', PlacementBand.a1).temper, 0.75);
    });

    test('a language whose gates were not run at an edge cannot move a value '
        'at all (Hindustani: no headroom in its time gate)', () {
      final profiles = PlacementProfiles.parse(
        _file(
          def: '{"temper": 0.7, "standApartItems": 16}',
          langs:
              '{"hi": {"version": 4, "declarationWeight": 0.1, '
              '"slipScale": {"F2": 1.2}}}',
        ),
      );
      final hi = profiles.resolve('hi', PlacementBand.a1);
      expect(hi.version, 4);
      expect(
        hi.toJson()..remove('version'),
        PlacementProfile.defaults.toJson()..remove('version'),
      );
      // Spanish takes the same default up to its edge.
      expect(profiles.resolve('es', PlacementBand.a1).temper, 0.7);
      expect(kGatedEdges.keys, <String>['es']);
    });

    test('is clamped one-sided: never bolder than the default, never past '
        'the edge the gates ran at', () {
      final bold = PlacementProfiles.parse(
        _file(
          def:
              '{"declarationWeight": 5, "togetherShare": 0.95, "temper": 1, '
              '"climbQuantile": 0.05, "standApartItems": 4, "mixedBonus": 3, '
              '"cognateThreshold": 0.9, "f4DecoyKey": true, '
              '"guessScale": {"F2": 0.8}, "slipScale": {"F2": 0.5}, '
              '"secondsScale": {"F4": 0.5}}',
        ),
      ).resolve('es', PlacementBand.a1);
      // Bolder than the default: brought back to it.
      expect(bold.declarationWeight, 0.7);
      expect(bold.togetherShare, 0.7);
      expect(bold.temper, 0.85);
      expect(bold.climbQuantile, 0.12);
      expect(bold.standApartItems, 14);
      expect(bold.mixedBonus, 0.3);
      expect(bold.cognateThreshold, 0.58);
      expect(bold.f4DecoyKey, isFalse);
      expect(bold.guessScale['F2'] ?? 1, 1);
      expect(bold.slipScale['F2'] ?? 1, 1);
      expect(bold.secondsScale['F4'] ?? 1, 1);
      // More careful than the default, but past the edge: held at the edge,
      // which is where the gates were run.
      final past = PlacementProfiles.parse(
        _file(
          def:
              '{"declarationWeight": -1, "togetherShare": 0.1, "temper": 0, '
              '"standApartItems": 99, "mixedBonus": -1, '
              '"guessScale": {"F7": 9, "F2": 9}, '
              '"slipScale": {"F2": 9}, "secondsScale": {"F2": 9}}',
        ),
      ).resolve('es', PlacementBand.a1);
      const edge = PlacementProfile.safestEdge;
      expect(past.declarationWeight, edge.declarationWeight);
      expect(past.togetherShare, edge.togetherShare);
      expect(past.temper, edge.temper);
      expect(past.standApartItems, edge.standApartItems);
      expect(past.mixedBonus, edge.mixedBonus);
      expect(past.guessScale['F7'], edge.guessScale['F7']);
      expect(past.slipScale['F2'], edge.slipScale['F2']);
      // A pick format is already at its clean limit: no raise at all.
      expect(past.guessScale['F2'] ?? 1, 1);
      // The time and the climb may not be raised at all (the time gate has no
      // headroom), nor the cognate line (it is not read at run start).
      expect(past.secondsScale['F2'] ?? 1, 1);
      expect(edge.secondsScale, isEmpty);
      expect(edge.climbQuantile, 0.12);
      expect(edge.cognateThreshold, 0.58);
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

  group('the default profile through a run', () {
    test('gives the model exactly the posterior the unscaled path gave', () {
      final run = V3Run(
        data: findLevelData(),
        skills: const <PlacementSkill>{
          PlacementSkill.read,
          PlacementSkill.write,
        },
        audio: false,
        recogniser: false,
        seed: 4,
        scriptStart: V3ScriptStart.skip,
        items: smallV3Bank(),
      );
      // The run's model, and one fed the way the code did before the profile
      // existed (the item's own view of itself, no scaling).
      final baseline = JointPlacement(
        levels: run.levels,
        skills: run.skillsInPlay,
      );
      var step = 0;
      while (!run.finished && step < 30) {
        if (run.atCheckpoint) {
          run.keepGoing();
          continue;
        }
        final item = run.question!.item!;
        final AnswerOutcome outcome;
        if (run.question!.mode == V3Mode.pick) {
          final right = step.isEven;
          outcome = right ? AnswerOutcome.right : AnswerOutcome.wrong;
          run.answerPick(
            right ? item.correct : (item.correct + 1) % item.options.length,
          );
        } else {
          outcome = AnswerOutcome.dontKnow;
          run.dontKnow();
        }
        baseline.observe(item.toJointItem(), outcome);
        for (final skill in run.skillsInPlay) {
          expect(
            run.model!.marginal(skill),
            baseline.marginal(skill),
            reason: 'step $step $skill',
          );
        }
        step++;
      }
      expect(step, greaterThan(5));
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

  group('the shipped file', () {
    Map<String, Map<String, Object?>> resolved() {
      final text = File('assets/placement_profiles.json').readAsStringSync();
      final profiles = PlacementProfiles.parse(text);
      final langs =
          (jsonDecode(text) as Map)['languages'] as Map<String, dynamic>;
      return <String, Map<String, Object?>>{
        'default': profiles.resolve('xx', PlacementBand.a1).toJson(),
        for (final l in langs.keys)
          for (final b in PlacementBand.values)
            '$l/${b.name}': profiles.resolve(l, b).toJson(),
      };
    }

    final snapshot = (jsonDecode(
      File('test/fixtures/placement/profile_snapshot.json').readAsStringSync(),
    ) as Map).cast<String, Map<String, dynamic>>();

    test('changes no profile without a version bump', () {
      for (final e in resolved().entries) {
        final before = snapshot[e.key];
        if (before == null) continue;
        final values = Map<String, Object?>.of(e.value)..remove('version');
        final old = Map<String, Object?>.of(before)..remove('version');
        if (jsonEncode(values) != jsonEncode(old)) {
          expect(
            e.value['version'] as int,
            greaterThan(before['version'] as int),
            reason: '${e.key} changed without a higher version',
          );
        }
      }
    });

    test(
      'matches the snapshot of what was shipped (update it with the bump)',
      () {
        expect(jsonEncode(resolved()), jsonEncode(snapshot));
      },
    );

    test('the kill switch is off', () {
      final text = File('assets/placement_profiles.json').readAsStringSync();
      expect(PlacementProfiles.parse(text).killSwitch, isFalse);
    });
  });

  group('another word order of a sentence, from the course', () {
    SentenceInfo sentence(String id, List<String> words, String english) =>
        SentenceInfo(
          card: Card(
            id: id,
            deckId: 'd',
            target: words.join(' '),
            native: english,
          ),
          deck: 0,
          words: words,
          leadingMark: '',
          trailingMark: '.',
          english: english,
          nonCognateContent: 3,
          cognateScore: 0,
          lemmas: <String>{},
          inner: false,
        );

    test(
      'a role reversal is never accepted: the same words say the opposite',
      () {
        final a = sentence('a', <String>[
          'dog',
          'bites',
          'man',
        ], 'The dog bites the man');
        final b = sentence('b', <String>[
          'man',
          'bites',
          'dog',
        ], 'The man bites the dog');
        expect(alternativeOrders(a, <SentenceInfo>[a, b]), isEmpty);
        expect(alternativeOrders(b, <SentenceInfo>[a, b]), isEmpty);
      },
    );

    test('a true free-order pair, with the same translation, is accepted', () {
      final a = sentence('a', <String>[
        'ram',
        'ne',
        'ghar',
        'dekha',
      ], 'Ram saw the house.');
      final b = sentence('b', <String>[
        'ghar',
        'ram',
        'ne',
        'dekha',
      ], 'Ram saw the house');
      expect(alternativeOrders(a, <SentenceInfo>[a, b]), <List<String>>[
        <String>['ghar', 'ram', 'ne', 'dekha'],
      ]);
    });

    test('a language listed free-order accepts the same words in any order '
        'the course shows; the list is empty until a reviewer flags one', () {
      final a = sentence('a', <String>['x', 'y', 'z'], 'One');
      final b = sentence('b', <String>['z', 'y', 'x'], 'Two');
      expect(alternativeOrders(a, <SentenceInfo>[a, b]), isEmpty);
      expect(
        alternativeOrders(a, <SentenceInfo>[a, b], freeOrder: true),
        hasLength(1),
      );
      expect(kFreeOrderLanguages, isEmpty);
    });
  });
}
