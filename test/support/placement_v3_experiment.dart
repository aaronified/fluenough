// A temporary parameter sweep of the drill-down, run in CI (never locally): it
// prints, per variant, the three numbers the placement gates read.
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/drill_down.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'placement_v3_harness.dart';

const _read = PlacementSkill.read;
const _hear = PlacementSkill.hear;
const _write = PlacementSkill.write;
const _all = <PlacementSkill>[_read, _hear, _write];

void experiment(Map<String, DrillConfig> variants) {
  for (final e in variants.entries) {
    test('variant ${e.key}', () {
      kHarnessDrill = e.value;
      final out = StringBuffer('EXPERIMENT ${e.key}\n');
      try {
        // Gate 1: one failing skill, the other two at 9 tenths.
        for (final code in <String>['es', 'hi']) {
          final lang = leakLanguages()[code]!;
          final b = lang.bank();
          for (final weak in _all) {
            final t = <PlacementSkill, int>{
              for (final s in _all)
                s: classAtTenth(b.levels, s == weak ? 2 : 9),
            };
            var withCase = 0;
            var ok = 0;
            var ok100 = 0;
            var with100 = 0;
            for (var seed = 1; seed <= 300; seed++) {
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
              final good = cases.every(
                (k) =>
                    k.isolating <= 4 &&
                    (k.skills.contains(weak)
                        ? k.verdict == weak
                        : k.verdict == null),
              );
              withCase++;
              if (good) ok++;
              if (seed <= 100) {
                with100++;
                if (good) ok100++;
              }
            }
            out.writeln(
              'G1 $code ${weak.name}: ${(ok / withCase).toStringAsFixed(3)} '
              '(first 100: ${(ok100 / with100).toStringAsFixed(2)}, '
              'cases-runs $withCase)',
            );
          }
        }
        // Gate 2: the honest hi amateur declared advanced cells.
        for (final code in <String>['hi', 'es']) {
          final lang = leakLanguages()[code]!;
          final b = lang.bank();
          for (final v in <Variant>[Variant.noMic, Variant.full]) {
            final made = <V3SimPicker>[];
            final results = runCell(
              bank: b,
              persona: Persona(
                'amateur',
                truth: {for (final s in _all) s: classAtTenth(b.levels, 3)},
              ),
              picker: () {
                final p = V3SimPicker();
                made.add(p);
                return p;
              },
              declaration: PlacementDeclaration.advanced,
              variant: v,
              runs: 200,
              scriptLetters: code == 'hi' ? devanagariLetters() : null,
            );
            final items = results.map((r) => r.items).toList();
            var iso = 0;
            var cases = 0;
            for (final p in made) {
              iso += p.picker!.drillDown.isolatingTotal;
              cases += p.picker!.drillDown.cases.length;
            }
            out.writeln(
              'G2 $code amateur-advanced ${v.label}: median '
              '${percentile(items, 0.5)} mean '
              '${(items.reduce((a, b) => a + b) / items.length).toStringAsFixed(2)} '
              'p95 ${percentile(items, 0.95)} isolating/run '
              '${(iso / made.length).toStringAsFixed(2)} cases/run '
              '${(cases / made.length).toStringAsFixed(2)}',
            );
          }
        }
        // Gate 3: the gamer, 0.07 better than measured, seeds from 2000.
        for (final code in <String>['es', 'hi']) {
          final lang = leakLanguages()[code]!;
          final b = lang.bank();
          final tk = classKnowingUpTo(b.levels, lang.knownDeck);
          for (final bump in <double>[0.07]) {
            var n = 0;
            var o2 = 0;
            var o1 = 0;
            var worst = 0.0;
            for (final d in kDeclarations) {
              final results = runCell(
                bank: b,
                persona: Persona(
                  'top100',
                  truth: {for (final s in _all) s: tk},
                  language: lang,
                  leak: true,
                  strongSolver: true,
                  leakBump: bump,
                ),
                picker: V3SimPicker.new,
                declaration: d,
                variant: Variant.full,
                runs: 300,
                seedBase: 2000,
              );
              for (final s in _all) {
                final xs = results.map((r) => r.skills[s]!).toList();
                final c2 = xs.where((x) => x.over > 4).length;
                n += xs.length;
                o2 += c2;
                o1 += xs.where((x) => x.over > 2).length;
                if (c2 / xs.length > worst) worst = c2 / xs.length;
              }
            }
            out.writeln(
              'G3 $code bump $bump: over2 pooled '
              '${(o2 / n).toStringAsFixed(4)} over1 pooled '
              '${(o1 / n).toStringAsFixed(4)} worst-cell-over2 '
              '${worst.toStringAsFixed(4)}',
            );
          }
        }
      } finally {
        kHarnessDrill = const DrillConfig();
        // ignore: avoid_print
        print(out);
      }
    }, timeout: const Timeout(Duration(minutes: 30)));
  }
}
