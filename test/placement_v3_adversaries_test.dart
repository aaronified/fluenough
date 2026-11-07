// More adversarial gates of Find my level V3: the yes-sayer, the self-rater
// of Say, a card replay, and the device variants that must still place Read
// and Write fully (wiki/Plan-Placement-V3.md, "Revised validation gates").
@Timeout(Duration(minutes: 20))
library;

import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_v3_harness.dart';

const _read = PlacementSkill.read;
const _hear = PlacementSkill.hear;
const _write = PlacementSkill.write;
const _say = PlacementSkill.say;

void main() {
  for (final code in <String>['es', 'hi']) {
    group(code, () {
      late SimBank bank;
      late PlacementLevels levels;

      setUpAll(() {
        bank = leakLanguages()[code]!.bank();
        levels = bank.levels;
      });

      // A true position in tenths of the path; 0 is `none`.
      Map<PlacementSkill, int> truth(double tenth, {bool say = false}) {
        final c = tenth <= 0 ? 0 : classAtTenth(levels, tenth);
        return {_read: c, _hear: c, _write: c, if (say) _say: c};
      }

      for (final rate in <double>[0.5, 0.7, 0.9]) {
        test('a yes-sayer ($rate) is not placed high by yes/no items', () {
          for (final d in kDeclarations) {
            final results = runCell(
              bank: bank,
              persona: Persona('yes-sayer', truth: truth(0), yesRate: rate),
              picker: () => BaselinePicker(yesNoBlock: true),
              declaration: d,
              variant: Variant.full,
              runs: 100,
            );
            final all = results.expand((r) => r.skills.values);
            // p10 within T + 1/10 in at least 97% of results.
            expect(
              share(all, (SkillResult x) => x.over <= 2),
              greaterThanOrEqualTo(0.97),
              reason: 'yes-rate $rate, ${declarationName(d)}',
            );
            // The run asked the eight pseudowords the model needs.
            expect(
              share(results, (RunResult r) => r.items >= kMinPseudowords),
              1.0,
            );
          }
        });
      }

      test('a Say that is always rated "same" is not placed from it', () {
        for (final d in kDeclarations) {
          final results = runCell(
            bank: bank,
            persona: Persona(
              'self-rater',
              truth: truth(3, say: true),
              selfRatesSame: true,
            ),
            picker: BaselinePicker.new,
            declaration: d,
            variant: Variant.full,
            runs: 20,
            sayInJoint: true,
          );
          // Say starts at most 1/10 above Hear in at least 98% of runs.
          expect(
            share(
              results,
              (RunResult r) =>
                  r.skills[_say]!.start <= r.skills[_hear]!.start + 2,
            ),
            greaterThanOrEqualTo(0.98),
            reason: declarationName(d),
          );
          // And it is never counted: the model never scored it.
          for (final r in results) {
            // Rated by the learner or not asked at all when the time ran out:
            // never scored.
            expect(r.skills[_say]!.state, isNot(EvidenceState.tested));
            expect(r.skills[_say]!.clean, 0);
            expect(r.skills[_say]!.rangeShown, isFalse);
          }
        }
      });

      test('self-rated Say items do not extend the run', () {
        final withSay = runCell(
          bank: bank,
          persona: Persona('a', truth: truth(3), selfRatesSame: true),
          picker: BaselinePicker.new,
          declaration: null,
          variant: Variant.full,
          runs: 40,
        );
        final noMic = runCell(
          bank: bank,
          persona: Persona('a', truth: truth(3), selfRatesSame: true),
          picker: BaselinePicker.new,
          declaration: null,
          variant: Variant.noMic,
          runs: 40,
        );
        // The same Read, Hear and Write items: only the (at most two) Say
        // items are extra.
        final extra =
            percentile(withSay.map((r) => r.items).toList(), 0.5) -
            percentile(noMic.map((r) => r.items).toList(), 0.5);
        expect(extra, lessThanOrEqualTo(2));
      });

      test('no run asks the same card twice (family replay)', () {
        for (final d in kDeclarations) {
          final results = runCell(
            bank: bank,
            persona: Persona('a', truth: truth(5)),
            picker: BaselinePicker.new,
            declaration: d,
            variant: Variant.full,
            runs: 60,
          );
          expect(share(results, (RunResult r) => r.repeatedCard), 0);
        }
      });

      test('without audio Read and Write are fully placed, Hear and Say '
          'are not tested', () {
        for (final d in kDeclarations) {
          final results = runCell(
            bank: bank,
            persona: Persona('a', truth: truth(5)),
            picker: BaselinePicker.new,
            declaration: d,
            variant: Variant.noAudio,
            runs: 60,
          );
          for (final r in results) {
            expect(r.skills.keys, containsAll(<PlacementSkill>[_read, _write]));
            expect(r.skills.containsKey(_hear), isFalse);
            expect(r.skills.containsKey(_say), isFalse);
            expect(r.skills[_read]!.rangeShown, isTrue);
            expect(r.skills[_write]!.rangeShown, isTrue);
            expect(r.skills[_read]!.clean, greaterThanOrEqualTo(4));
            expect(r.skills[_write]!.clean, greaterThanOrEqualTo(4));
          }
        }
      });

      test(
        'without a microphone Say is not tested and nothing else changes',
        () {
          final results = runCell(
            bank: bank,
            persona: Persona('a', truth: truth(5)),
            picker: BaselinePicker.new,
            declaration: null,
            variant: Variant.noMic,
            runs: 40,
          );
          for (final r in results) {
            expect(r.skills.containsKey(_say), isFalse);
            expect(r.skills[_hear]!.rangeShown, isTrue);
          }
        },
      );
    });
  }
}
