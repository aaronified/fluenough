// A temporary sweep of the gamer margin gate (legacy bank), run in CI only.
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'placement_v3_harness.dart';

const _all = <PlacementSkill>[
  PlacementSkill.read,
  PlacementSkill.hear,
  PlacementSkill.write,
];

GuessCalibration withBounds(Map<String, double> extra) => GuessCalibration(
  <String, double>{...GuessCalibration.seed.upperBounds, ...extra},
);

void experiment(Map<String, GuessCalibration> variants) {
  for (final e in variants.entries) {
    test('variant ${e.key}', () {
      final out = StringBuffer('EXPERIMENT ${e.key}\n');
      for (final code in <String>['es', 'hi']) {
        final lang = leakLanguages()[code]!;
        final b = lang.bank();
        final tk = classKnowingUpTo(b.levels, lang.knownDeck);
        for (final bump in <double>[0.05, 0.07]) {
          var n = 0;
          var o2 = 0;
          var o1 = 0;
          final hits = <String>[];
          for (final base in <int>[0, 1000, 2000]) {
            for (final d in kDeclarations) {
              final results = runCell(
                bank: b,
                persona: Persona(
                  'top100',
                  truth: {for (final s in _all) s: tk},
                  language: lang,
                  leak: true,
                  strongSolver: true,
                  profile: BankProfile.legacy,
                  leakBump: bump,
                ),
                picker: V3SimPicker.new,
                declaration: d,
                variant: Variant.full,
                runs: 300,
                seedBase: base,
                mutation: Mutation(calibration: e.value),
              );
              for (final s in _all) {
                final xs = results.map((r) => r.skills[s]!).toList();
                final c2 = xs.where((x) => x.over > 4).length;
                n += xs.length;
                o2 += c2;
                o1 += xs.where((x) => x.over > 2).length;
                if (c2 > 0) {
                  hits.add('$base/${declarationName(d)}/${s.name}=$c2');
                }
              }
            }
          }
          out.writeln(
            'G3 $code bump $bump: over2 ${(o2 / n).toStringAsFixed(4)} '
            '($o2 of $n) over1 ${(o1 / n).toStringAsFixed(4)} hits $hits',
          );
        }
      }
      // ignore: avoid_print
      print(out);
    }, timeout: const Timeout(Duration(minutes: 30)));
  }
}
