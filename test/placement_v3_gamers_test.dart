// The adversarial gates of Find my level V3 (wiki/Plan-Placement-V3.md,
// "Revised validation gates"): learners that cannot know the language but try
// to be placed high. Each persona plays 100 runs per declaration (flat,
// amateur, advanced), in Spanish and Hindi, on the bank as the adversary found
// it ("legacy") and as the amended generators must make it ("fixed"), through
// the joint model of lib/core and the stand-in picker of the harness. The
// counts are per skill result (Read, Hear, Write), so a cell holds 300.
//
// Gates: TOP100+RULES (weak and strong solver) over by more than 1/10 in at
// most 3% and by more than 2/10 in at most 1%; COGNATE-ONLY, TESTWISE-ONLY and
// RANDOM over by more than 1/10 in at most 2%. A cheater that answers
// everything right is the control: the gates must see it.
@Timeout(Duration(minutes: 20))
library;

import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_v3_harness.dart';

const int _runs = 100;

const _words = <PlacementSkill>[
  PlacementSkill.read,
  PlacementSkill.hear,
  PlacementSkill.write,
];

/// The worst share over the three declarations of skill results over by more
/// than [classes] classes (2 classes are 1/10 of the path).
double _worstOver(
  SimBank bank,
  Persona persona,
  int classes, {
  int runs = _runs,
}) {
  var worst = 0.0;
  for (final d in kDeclarations) {
    final results = runCell(
      bank: bank,
      persona: persona,
      picker: BaselinePicker.new,
      declaration: d,
      variant: Variant.full,
      runs: runs,
    );
    final all = results.expand((r) => r.skills.values);
    final over = share(all, (SkillResult x) => x.over > classes);
    if (over > worst) worst = over;
  }
  return worst;
}

void main() {
  for (final code in <String>['es', 'hi']) {
    group('$code adversaries', () {
      late LeakLanguage lang;
      late SimBank bank;
      late Map<PlacementSkill, int> gamerTruth;
      late Map<PlacementSkill, int> none;

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
          test('TOP100+RULES ($kind solver, ${profile.name} bank) is not '
              'placed high', () {
            final persona = Persona(
              'top100',
              truth: gamerTruth,
              language: lang,
              leak: true,
              strongSolver: strong,
              profile: profile,
            );
            expect(
              _worstOver(bank, persona, 2),
              lessThanOrEqualTo(0.03),
              reason: 'over by more than 1/10',
            );
            expect(
              _worstOver(bank, persona, 4),
              lessThanOrEqualTo(0.01),
              reason: 'over by more than 2/10',
            );
          });
        }

        test('COGNATE-ONLY (${profile.name} bank) is not placed high', () {
          final persona = Persona(
            'cognate-only',
            truth: none,
            language: lang,
            cognateOnly: true,
            profile: profile,
          );
          expect(_worstOver(bank, persona, 2), lessThanOrEqualTo(0.02));
        });

        test('TESTWISE-ONLY (${profile.name} bank) is not placed high', () {
          final persona = Persona(
            'testwise-only',
            truth: none,
            language: lang,
            leak: true,
            cognateLeak: false,
            profile: profile,
          );
          expect(_worstOver(bank, persona, 2), lessThanOrEqualTo(0.02));
        });
      }

      test('RANDOM is not placed high', () {
        final persona = Persona('random', truth: none, random: true);
        expect(_worstOver(bank, persona, 2), lessThanOrEqualTo(0.02));
      });

      test('control: a cheater that answers everything right is seen', () {
        final cheater = Persona('cheater', truth: none, cheater: true);
        // Every declaration places it far above its (zero) true position: a
        // harness that cannot see that would pass the gates above for no
        // reason.
        expect(_worstOver(bank, cheater, 2, runs: 20), greaterThan(0.9));
      });
    });
  }
}
