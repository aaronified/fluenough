// The picker of Find my level V3 over the real item banks of Spanish and
// Hindi (built from the decks): an honest learner answers by what they know,
// and the run stays inside the plan's rules.
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:fluenough/core/data/placement_course.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/item_bank.dart';
import 'package:fluenough/core/placement/item_registry.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/v3_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_v3_harness.dart';

PlacementCourse _course(String language) {
  final files = <String, String>{};
  for (final e in Directory('decks/$language').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.yaml')) {
      files[e.path.substring('decks/'.length)] = e.readAsStringSync();
    }
  }
  return loadPlacementCourse(files, language: language);
}

void main() {
  for (final language in <String>['es', 'hi']) {
    group('the picker over the $language bank', () {
      late ItemBank bank;
      late PlacementLevels levels;
      late List<PickerCandidate> candidates;

      setUpAll(() {
        bank = ItemBank.build(_course(language).data);
        final decks = bank.items.map((i) => i.deck).reduce(math.max) + 1;
        levels = PlacementLevels(decks, maxParts: 20);
        candidates = PickerCandidate.fromBank(bank);
      });

      ({V3Picker picker, JointPlacement model, int truth}) play(
        double tenth,
        int seed, {
        Set<String>? formats,
      }) {
        final truth = tenth <= 0 ? 0 : classAtTenth(levels, tenth);
        final rng = math.Random(seed);
        final model = JointPlacement(
          levels: levels,
          skills: const <PlacementSkill>[
            PlacementSkill.read,
            PlacementSkill.hear,
            PlacementSkill.write,
          ],
        );
        final picker = V3Picker(
          pool: CandidatePool(
            formats == null
                ? candidates
                : <PickerCandidate>[
                    for (final c in candidates)
                      if (formats.contains(c.format)) c,
                  ],
            levels,
          ),
          model: model,
          rng: rng,
        );
        while (true) {
          final c = picker.next();
          if (c == null) break;
          // A self-rated Say is only recorded, never evidence.
          if (c.selfRated) continue;
          final item = c.payload! as RegItem;
          final known = levels.knows(truth, c.deck);
          final right = known
              ? rng.nextDouble() >= c.slip
              : rng.nextDouble() < c.guess;
          model.observe(
            item.toJointItem(),
            right ? AnswerOutcome.right : AnswerOutcome.wrong,
          );
        }
        return (picker: picker, model: model, truth: truth);
      }

      test('asks only admitted items, once each, inside the caps', () {
        final admitted = <String>{for (final i in bank.items) i.id};
        for (var seed = 1; seed <= 10; seed++) {
          for (final tenth in <double>[0, 2, 5, 8, 10]) {
            final r = play(tenth, seed);
            final keys = <String>[
              for (final c in r.picker.asked) ...c.conflictKeys,
            ];
            expect(keys.toSet().length, keys.length);
            for (final c in r.picker.asked) {
              expect(admitted, contains(c.id));
            }
            expect(r.picker.items, lessThanOrEqualTo(40));
            expect(r.picker.seconds, lessThanOrEqualTo(300));
          }
        }
      });

      test('gives every skill four clean items and does not place high', () {
        for (var seed = 1; seed <= 10; seed++) {
          for (final tenth in <double>[0, 2, 5, 8, 10]) {
            final r = play(tenth, seed);
            final readout = r.model.readout();
            for (final e in readout.skills.entries) {
              expect(
                e.value.cleanItems,
                greaterThanOrEqualTo(4),
                reason: '${e.key.name} at $tenth, seed $seed',
              );
              // The truth is the same in every skill here.
              expect(
                e.value.startClass - r.truth,
                lessThanOrEqualTo(4),
                reason: '${e.key.name} at $tenth, seed $seed',
              );
            }
          }
        }
      });

      test('a sparse bank never leaves a skill short silently', () {
        // One or two admitted formats for a skill: the floor of four clean
        // items holds, or the run says it is coverage-short and names the
        // skill (and a skill with no format at all is always named).
        const sets = <Set<String>>[
          {'F2'},
          {'F2', 'F13'},
          {'F8', 'F13'},
          {'F2', 'F7'},
          {'F16', 'F2'},
        ];
        for (final formats in sets) {
          final supplied = <PlacementSkill>{
            for (final c in candidates)
              if (formats.contains(c.format)) ...c.skills,
          };
          for (final tenth in <double>[0, 2, 5, 8, 10]) {
            for (var seed = 1; seed <= 3; seed++) {
              final r = play(tenth, seed, formats: formats);
              final reason = '$formats at $tenth, seed $seed';
              expect(r.picker.endReason, isNotNull, reason: reason);
              final short = r.picker.shortSkills;
              for (final skill in <PlacementSkill>[
                PlacementSkill.read,
                PlacementSkill.hear,
                PlacementSkill.write,
              ]) {
                final clean = r.model.cleanItemsOf(skill);
                if (clean < 4) {
                  expect(short, contains(skill), reason: '$skill $reason');
                  expect(
                    r.picker.endReason,
                    EndReason.coverageShort,
                    reason: '$skill $reason',
                  );
                }
                if (!supplied.contains(skill)) {
                  expect(short, contains(skill), reason: '$skill $reason');
                } else if (clean < 4) {
                  // A skill with items is short only because a cap ended
                  // the run, never by giving up.
                  expect(
                    r.picker.endCause,
                    anyOf(EndReason.itemCap, EndReason.timeCap),
                    reason: '$skill $reason',
                  );
                }
              }
              expect(r.picker.seconds, lessThanOrEqualTo(300));
            }
          }
        }
      });
    });
  }
}
