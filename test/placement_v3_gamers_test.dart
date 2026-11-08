// The adversarial gates of Find my level V3 (wiki/Plan-Placement-V3.md,
// "Revised validation gates"): learners that cannot know the language but try
// to be placed high. Each persona plays 100 runs per declaration (flat,
// amateur, advanced) and per device variant (audio and mic, no mic, no
// audio), in Spanish and Hindi, on the bank as the adversary found it
// ("legacy") and as the amended generators must make it ("fixed"), through the
// joint model of lib/core and the real picker (v3_picker.dart) over the admitted formats (the mutation controls keep the stand-in).
//
// Gates are PER SKILL: the share of runs over by more than 1/10 (2 classes)
// is computed for Read, Hear and Write separately and every skill must pass,
// in every declaration and variant. TOP100+RULES: at most 3% over by 1/10 and
// at most 1% over by 2/10. COGNATE-ONLY, TESTWISE-ONLY and RANDOM: at most 2%
// over by 1/10. Every run also gives every skill in play four clean items.
//
// The controls show the gates can fail (a gate that cannot fail proves
// nothing): a cheater that answers everything right; V3 as it was before the
// adversarial review ("V3 literal": no calibration, no proof ceiling, a picker
// that asks every format and lets cognates in); each protection removed in
// the setting where it is load-bearing; and a gamer that is better than the
// adversary measured. The model defends in layers, so removing ONE protection
// while the others stand may still pass; the controls therefore remove a
// protection together with the layers that would hide its absence, and
// assert both that the gate then fails and that restoring the protection makes
// it pass.
@Timeout(Duration(minutes: 25))
library;

import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_v3_harness.dart';

const int _runs = 100;

/// What a cell of runs came to, worst over its skills and declarations.
class _Worst {
  double over1 = 0;
  double over2 = 0;
  double lowOver1 = 0;
  double coverage = 1;
  String where = '';

  @override
  String toString() =>
      'over 1/10 ${over1.toStringAsFixed(3)}, over 2/10 '
      '${over2.toStringAsFixed(3)}, p10 over 1/10 '
      '${lowOver1.toStringAsFixed(3)}, four clean items '
      '${coverage.toStringAsFixed(2)} (worst at $where)';
}

/// The worst per-skill shares of [persona] over every declaration and each of
/// [variants].
_Worst _measure(
  SimBank bank,
  Persona persona, {
  List<Variant> variants = const <Variant>[Variant.full],
  SimPicker Function() picker = V3SimPicker.new,
  Mutation mutation = const Mutation(),
  int runs = _runs,
}) {
  final worst = _Worst();
  for (final variant in variants) {
    for (final d in kDeclarations) {
      final results = runCell(
        bank: bank,
        persona: persona,
        picker: picker,
        declaration: d,
        variant: variant,
        runs: runs,
        mutation: mutation,
      );
      final here = '${variant.label} ${declarationName(d)}';
      final clean = share(
        results,
        (RunResult r) => r.skills.values.every((s) => s.clean >= 4),
      );
      if (clean < worst.coverage) worst.coverage = clean;
      final skills = results.first.skills.keys;
      for (final skill in skills) {
        final xs = results.map((r) => r.skills[skill]!).toList();
        final o1 = share(xs, (SkillResult x) => x.over > 2);
        final o2 = share(xs, (SkillResult x) => x.over > 4);
        final lo = share(xs, (SkillResult x) => x.lowOver > 2);
        if (o1 > worst.over1) {
          worst.over1 = o1;
          worst.where = '$here ${skill.name}';
        }
        if (o2 > worst.over2) worst.over2 = o2;
        if (lo > worst.lowOver1) worst.lowOver1 = lo;
      }
    }
  }
  // ignore: avoid_print
  print(
    'gamer ${persona.name} ${persona.profile.name} seeds from $kSeedBase: $worst',
  );
  return worst;
}

const _words = <PlacementSkill>[
  PlacementSkill.read,
  PlacementSkill.hear,
  PlacementSkill.write,
];

const List<Variant> _variants = <Variant>[
  Variant.full,
  Variant.noMic,
  Variant.noAudio,
];

const GuessCalibration _noCalibration = GuessCalibration(<String, double>{});

void main() {
  for (final code in <String>['es', 'hi']) {
    group('$code adversaries', () {
      late LeakLanguage lang;
      late SimBank bank;
      late Map<PlacementSkill, int> gamerTruth;
      late Map<PlacementSkill, int> none;

      Persona gamer({
        bool strong = true,
        BankProfile profile = BankProfile.legacy,
        double bump = 0,
      }) => Persona(
        'top100',
        truth: gamerTruth,
        language: lang,
        leak: true,
        strongSolver: strong,
        profile: profile,
        leakBump: bump,
      );

      setUpAll(() {
        lang = leakLanguages()[code]!;
        bank = lang.bank();
        final t = classKnowingUpTo(bank.levels, lang.knownDeck);
        gamerTruth = {for (final s in _words) s: t};
        none = {for (final s in _words) s: 0};
      });

      for (final profile in BankProfile.values) {
        for (final strong in <bool>[false, true]) {
          final kind = strong ? 'strong' : 'weak';
          test(
            'TOP100+RULES ($kind solver, ${profile.name} bank) is not placed '
            'high in any skill',
            () {
              final w = _measure(
                bank,
                gamer(strong: strong, profile: profile),
                variants: _variants,
              );
              expect(w.over1, lessThanOrEqualTo(0.03), reason: '$w');
              expect(w.over2, lessThanOrEqualTo(0.01), reason: '$w');
              expect(w.coverage, 1.0, reason: '$w');
            },
          );
        }

        test('COGNATE-ONLY (${profile.name} bank) is not placed high', () {
          final w = _measure(
            bank,
            Persona(
              'cognate-only',
              truth: none,
              language: lang,
              cognateOnly: true,
              profile: profile,
            ),
            variants: _variants,
          );
          expect(w.over1, lessThanOrEqualTo(0.02), reason: '$w');
          expect(w.coverage, 1.0, reason: '$w');
        });

        test('TESTWISE-ONLY (${profile.name} bank) is not placed high', () {
          final w = _measure(
            bank,
            Persona(
              'testwise-only',
              truth: none,
              language: lang,
              leak: true,
              cognateLeak: false,
              profile: profile,
            ),
            variants: _variants,
          );
          expect(w.over1, lessThanOrEqualTo(0.02), reason: '$w');
          expect(w.coverage, 1.0, reason: '$w');
        });
      }

      test('RANDOM is not placed high', () {
        final w = _measure(
          bank,
          Persona('random', truth: none, random: true),
          variants: _variants,
        );
        expect(w.over1, lessThanOrEqualTo(0.02), reason: '$w');
        expect(w.coverage, 1.0, reason: '$w');
      });

      group('controls: the gates can fail', () {
        test('a cheater is over by 1/10 in every skill and declaration', () {
          // The MINIMUM over declarations and skills: every one sees it.
          var least = 1.0;
          for (final d in kDeclarations) {
            final results = runCell(
              bank: bank,
              persona: Persona('cheater', truth: none, cheater: true),
              picker: V3SimPicker.new,
              declaration: d,
              variant: Variant.full,
              runs: 30,
            );
            for (final skill in results.first.skills.keys) {
              final over = share(
                results.map((r) => r.skills[skill]!),
                (SkillResult x) => x.over > 2,
              );
              if (over < least) least = over;
            }
          }
          expect(least, greaterThan(0.9));
        });

        // The mutation controls run in Spanish, where the adversary found the
        // strong leaks; Hindi's gamer leaks little (about 0.30 on a clean
        // item), so removing a protection there moves the share by too little
        // to be a robust control (V3 literal: 4%).
        if (code == 'es') {
          test('V3 literal (no calibration, no ceiling, a naive picker) fails '
              'on the legacy bank', () {
            final w = _measure(
              bank,
              gamer(),
              picker: () => BaselinePicker(naive: true),
              mutation: const Mutation(
                calibration: _noCalibration,
                noCeiling: true,
                label: 'V3 literal',
              ),
            );
            expect(w.over1, greaterThan(0.03), reason: '$w');
          });

          test('calibration is load-bearing: without it the gamer fails, with '
              'it the gamer passes (naive picker, no ceiling)', () {
            final without = _measure(
              bank,
              gamer(),
              picker: () => BaselinePicker(naive: true),
              mutation: const Mutation(
                calibration: _noCalibration,
                noCeiling: true,
              ),
            );
            final withIt = _measure(
              bank,
              gamer(),
              picker: () => BaselinePicker(naive: true),
              mutation: const Mutation(noCeiling: true),
            );
            expect(without.over1, greaterThan(0.03), reason: '$without');
            expect(withIt.over1, lessThanOrEqualTo(0.03), reason: '$withIt');
          });

          test('a flat guess of 0.30 does not replace calibration (naive '
              'picker, no ceiling)', () {
            final w = _measure(
              bank,
              gamer(),
              picker: () => BaselinePicker(naive: true),
              mutation: const Mutation(fixedGuess: 0.30, noCeiling: true),
            );
            expect(w.over1, greaterThan(0.03), reason: '$w');
          });

          test('the proven-level ceiling is load-bearing: removing it fails, '
              'restoring it passes (naive picker, flat guess 0.30)', () {
            final without = _measure(
              bank,
              gamer(),
              picker: () => BaselinePicker(naive: true),
              mutation: const Mutation(fixedGuess: 0.30, noCeiling: true),
            );
            final withIt = _measure(
              bank,
              gamer(),
              picker: () => BaselinePicker(naive: true),
              mutation: const Mutation(fixedGuess: 0.30),
            );
            expect(without.over1, greaterThan(0.03), reason: '$without');
            expect(withIt.over1, lessThanOrEqualTo(0.03), reason: '$withIt');
          });
        }
        test('the margin: a gamer 0.05 to 0.07 better than measured (the '
            'admission bound) still passes, a far better one fails', () {
          for (final bump in <double>[0.05, 0.07]) {
            final w = _measure(bank, gamer(bump: bump));
            expect(w.over1, lessThanOrEqualTo(0.03), reason: 'bump $bump: $w');
            expect(w.over2, lessThanOrEqualTo(0.01), reason: 'bump $bump: $w');
          }
          final far = _measure(bank, gamer(bump: 0.45));
          expect(far.over1, greaterThan(0.03), reason: '$far');
        });
      });
    });
  }
}
