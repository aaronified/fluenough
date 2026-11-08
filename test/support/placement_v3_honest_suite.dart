// The honest personas of Find my level V3 (wiki/Plan-Placement-V3.md,
// "Revised validation gates"): beginner, amateur, advanced, expert, native,
// script-literate-only, ear-only and cognate-advantaged, with and without
// audio and a microphone, under flat, amateur and advanced declarations, in
// Spanish and Hindi, 100 runs per cell, through the joint model and the
// real picker (lib/core/placement/v3_picker.dart) over the admitted formats.
//
// The suite of one language; the test files placement_v3_honest_es_test.dart
// and placement_v3_honest_hi_test.dart run it (two files, so the CI shards
// can balance them).
//
// Enforced here (they are properties of the estimator and its caps): honest
// learners are never placed more than 2/10 above the truth (at most 3%);
// beginners and script-only learners start at the beginning; a
// cognate-advantaged learner is not placed more than 1/10 above the truth; a
// skill in play gets at least four clean items in every run; Read and Write
// are fully placed without audio or a microphone; no card is asked twice;
// the run is bounded by the plan's caps.
//
// Also enforced: the item and time gates (median at most 28 items and 200 s,
// 95th percentile at most 40 items and 300 s). NOT enforced here: experts and
// natives within 1/10 and the honest confidence of the 80% range; they are
// listed, with the measured numbers, in placement_v3_pending_gates_test.dart.

import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'placement_v3_harness.dart';

const _read = PlacementSkill.read;
const _hear = PlacementSkill.hear;
const _write = PlacementSkill.write;

const int _runs = 100;

typedef _Cell = ({
  String name,
  Variant variant,
  PlacementDeclaration? declaration,
  List<RunResult> results,
});

void honestSuite(String code) {
  {
    group(code, () {
      late SimBank bank;
      late PlacementLevels levels;
      final cells = <_Cell>[];

      Map<PlacementSkill, int> truth(double read, double hear, double write) {
        int c(double t) => t <= 0 ? 0 : classAtTenth(levels, t);
        return {_read: c(read), _hear: c(hear), _write: c(write)};
      }

      setUpAll(() {
        bank = leakLanguages()[code]!.bank();
        levels = bank.levels;
        final personas = <Persona>[
          Persona('beginner', truth: truth(0, 0, 0)),
          // Reads the script, knows no words: no word skill is placed.
          Persona('script-literate-only', truth: truth(0, 0, 0)),
          Persona('amateur', truth: truth(3, 3, 3)),
          Persona('advanced', truth: truth(7, 7, 7)),
          Persona('expert', truth: truth(9.5, 9.5, 9.5)),
          Persona('native', truth: truth(10, 10, 10)),
          Persona('ear-only', truth: truth(0, 7, 0)),
          Persona(
            'cognate-advantaged',
            truth: truth(3, 3, 3),
            cognateRight: true,
          ),
        ];
        for (final variant in <Variant>[
          Variant.full,
          Variant.noAudio,
          Variant.noMic,
        ]) {
          for (final persona in personas) {
            for (final d in kDeclarations) {
              cells.add((
                name: persona.name,
                variant: variant,
                declaration: d,
                results: runCell(
                  bank: bank,
                  persona: persona,
                  picker: V3SimPicker.new,
                  declaration: d,
                  variant: variant,
                  runs: _runs,
                  // Hindustani is written in Devanagari: the script gate runs
                  // first (every honest persona here reads it).
                  scriptLetters: code == 'hi' ? devanagariLetters() : null,
                ),
              ));
            }
          }
        }
      });

      Iterable<_Cell> of(String name) => cells.where((c) => c.name == name);

      test('no honest learner is placed more than 2/10 above the truth', () {
        for (final c in cells) {
          final all = c.results.expand((r) => r.skills.values);
          expect(
            share(all, (SkillResult x) => x.over > 4),
            lessThanOrEqualTo(0.03),
            reason:
                '${c.name} ${c.variant.label} ${declarationName(c.declaration)}',
          );
        }
      });

      test('a cognate-advantaged learner is not placed 1/10 above', () {
        for (final c in of('cognate-advantaged')) {
          final all = c.results.expand((r) => r.skills.values);
          expect(
            share(all, (SkillResult x) => x.over > 2),
            lessThanOrEqualTo(0.03),
            reason: '${c.variant.label} ${declarationName(c.declaration)}',
          );
        }
      });

      test('beginners and script-literate-only learners start at the start', () {
        for (final name in <String>['beginner', 'script-literate-only']) {
          for (final c in of(name)) {
            final all = c.results.expand((r) => r.skills.values);
            expect(
              share(all, (SkillResult x) => x.start <= 2),
              greaterThanOrEqualTo(0.97),
              reason:
                  '$name ${c.variant.label} ${declarationName(c.declaration)}',
            );
          }
        }
      });

      test('an ear-only learner has Read and Write at the start', () {
        for (final c in of('ear-only')) {
          final reads = c.results.map((r) => r.skills[_read]!.start);
          final writes = c.results.map((r) => r.skills[_write]!.start);
          expect(share(reads, (int s) => s <= 2), greaterThanOrEqualTo(0.97));
          expect(share(writes, (int s) => s <= 2), greaterThanOrEqualTo(0.97));
        }
      });

      test('every skill in play gets four clean items in every run', () {
        for (final c in cells) {
          expect(
            share(
              c.results,
              (RunResult r) => r.skills.values.every((s) => s.clean >= 4),
            ),
            1.0,
            reason:
                '${c.name} ${c.variant.label} ${declarationName(c.declaration)}',
          );
        }
      });

      test('Read and Write are fully placed without audio or a microphone', () {
        for (final c in cells) {
          if (c.variant.audio && c.variant.mic) continue;
          for (final r in c.results) {
            for (final skill in <PlacementSkill>[_read, _write]) {
              expect(r.skills[skill]!.state.name, 'tested');
              expect(r.skills[skill]!.rangeShown, isTrue);
            }
            expect(
              r.skills.containsKey(_hear),
              c.variant.audio,
              reason: 'Hear is tested only with audio',
            );
            expect(r.skills.containsKey(PlacementSkill.say), isFalse);
          }
        }
      });

      test('time and items: median 28 items and 200 s, p95 40 and 300 s', () {
        // Per cell: persona x device x declaration. The 95th percentile
        // caps (40 items, 300 s) are true by construction (the picker stops
        // at them and never asks an item that would end after 300 s), so
        // the medians are the real gates.
        for (final c in cells) {
          final items = c.results.map((r) => r.items).toList();
          final secs = c.results.map((r) => r.seconds).toList();
          final reason =
              '${c.name} ${c.variant.label} ${declarationName(c.declaration)}';
          expect(percentile(items, 0.5), lessThanOrEqualTo(28), reason: reason);
          expect(percentile(secs, 0.5), lessThanOrEqualTo(200), reason: reason);
          expect(
            percentile(items, 0.95),
            lessThanOrEqualTo(40),
            reason: reason,
          );
          expect(
            percentile(secs, 0.95),
            lessThanOrEqualTo(300),
            reason: reason,
          );
        }
      });

      test('a run is bounded by the plan caps and repeats no card', () {
        for (final c in cells) {
          for (final r in c.results) {
            expect(r.items, lessThanOrEqualTo(40));
            expect(r.seconds, lessThanOrEqualTo(300));
            expect(r.repeatedCard, isFalse);
          }
        }
      });

      test('the baseline numbers are reported for the pending gates', () {
        // Printed so a later picker's author sees what to beat; asserted only
        // loosely (the numbers behind the pending gates, not a gate).
        for (final c in cells) {
          if (c.variant != Variant.full) continue;
          final items = c.results.map((r) => r.items).toList();
          final secs = c.results.map((r) => r.seconds).toList();
          final all = c.results.expand((r) => r.skills.values);
          // ignore: avoid_print
          print(
            '$code ${c.name} ${declarationName(c.declaration)}: items '
            '${percentile(items, 0.5)}/${percentile(items, 0.95)}, seconds '
            '${percentile(secs, 0.5)}/${percentile(secs, 0.95)}, within 1/10 '
            '${share(all, (SkillResult x) => x.over.abs() <= 2).toStringAsFixed(2)}, '
            'over 2/10 ${share(all, (SkillResult x) => x.over > 4).toStringAsFixed(3)}, '
            'range holds the truth '
            '${share(all, (SkillResult x) => x.low <= x.truth && x.truth <= x.high).toStringAsFixed(2)}',
          );
          expect(percentile(items, 0.95), lessThanOrEqualTo(40));
        }
      });
    });
  }
}
