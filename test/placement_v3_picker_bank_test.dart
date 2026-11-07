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
        int seed,
      ) {
        final truth = classAtTenth(levels, tenth);
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
          pool: CandidatePool(candidates, levels),
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
          for (final tenth in <double>[2, 5, 8]) {
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
          for (final tenth in <double>[2, 5, 8]) {
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
    });
  }
}
