// The V3 run over the REAL item banks of Spanish and Hindustani (built from
// the decks): every skill in play has an askable format and is placed (the
// run never ends short of coverage), and every format the audit admits is
// asked in some run, unless it is on the documented list below with its
// reason. A format that quietly stops being asked fails here.
@Timeout(Duration(minutes: 15))
library;

import 'package:fluenough/core/placement/item_bank.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/v3_picker.dart'
    show EndReason, kUnaskableFormats;
import 'package:fluenough/core/placement/v3_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/v3_oracle.dart';

/// Admitted formats the picker does not ask, and why. Each is a decision of
/// the plan, not an accident; changing one means changing this list.
const Map<String, String> _notAsked = <String, String>{
  'S2': 'word order needs a grammaticality check (kUnaskableFormats)',
  'F9': 'matching needs a screen (kUnaskableFormats)',
  'F3':
      'its calibrated guess (0.45, GuessCalibration.seed) is above '
      'kCleanGuessMax (0.35): it never counts for coverage or proof, so the '
      'picker never chooses it. Provisional until the real-learner re-fit '
      '(step 8)',
  'F4':
      'the same: the seed calibration rates word tiles at 0.45 under their '
      'format code (the 0.30 of "F4decoys" is not used by '
      'PickerCandidate.fromItem), so they are never clean. Provisional until '
      'the re-fit',
  'F1': 'yes/no items are asked only in the optional yes/no block (off)',
  'F14': 'yes/no items are asked only in the optional yes/no block (off)',
};

/// Admitted formats the oracle learner's runs over one language do not reach
/// (they are asked in other languages' runs and by learners the oracle is not).
const Map<String, Map<String, String>> _notAskedIn =
    <String, Map<String, String>>{
      'hi': <String, String>{
        'F7':
            'Write is placed with the 6 s gap items (F21) and the sentence '
            'tiles; typing a whole Devanagari word costs 12 s and gives no '
            'more information per second',
        'F5':
            'a sentence pick costs 8 s at the guess of a word pick: chosen '
            'only when the word picks of a band are used up',
        'F17': 'the same, heard',
      },
    };

void main() {
  for (final language in <String>['es', 'hi']) {
    group('the run over the real $language bank', () {
      late PlacementLanguageData data;
      late ItemBank bank;
      setUpAll(() {
        data = language == 'hi' ? hindustaniWithScript() : loadData(language);
        bank = ItemBank.build(data);
      });

      test('places every skill and asks every admitted format', () {
        const skills = <PlacementSkill>{
          PlacementSkill.read,
          PlacementSkill.hear,
          PlacementSkill.say,
          PlacementSkill.write,
        };
        final askedBySkill = <PlacementSkill, Set<String>>{};
        final asked = <String>{};
        final ends = <EndReason?, int>{};
        var runs = 0;
        for (final audio in <bool>[true, false]) {
          for (final tenth in <double>[0.1, 0.4, 0.7, 0.95]) {
            for (var seed = 1; seed <= 3; seed++) {
              final run = V3Run(
                data: data,
                skills: skills,
                audio: audio,
                recogniser: audio,
                seed: seed,
                items: bank.items,
              );
              var guard = 0;
              while (!run.finished && guard++ < 100) {
                if (run.atCheckpoint) {
                  run.keepGoing();
                  continue;
                }
                final q = run.question!;
                if (q.item != null) {
                  asked.add(q.format);
                  for (final s in q.item!.info.skills) {
                    askedBySkill.putIfAbsent(s, () => <String>{}).add(q.format);
                  }
                }
                answerV3(run, (tenth * data.deckCount).round());
              }
              expect(run.finished, isTrue);
              final end = run.picker?.endReason;
              ends[end] = (ends[end] ?? 0) + 1;
              // Never ended short of four clean items for a tested skill.
              expect(
                end,
                isNot(EndReason.coverageShort),
                reason: '$language audio=$audio tenth=$tenth seed=$seed',
              );
              runs++;
            }
          }
        }
        final complete = ends[EndReason.complete] ?? 0;
        expect(
          complete,
          greaterThanOrEqualTo((runs * 0.75).floor()),
          reason: 'ends: $ends',
        );
        // Every skill in play has an askable admitted format, and was asked.
        for (final skill in skills) {
          final admitted = <String>{
            for (final i in bank.items)
              if (i.info.skills.contains(skill) &&
                  !_notAsked.containsKey(i.format))
                i.format,
          };
          expect(admitted, isNotEmpty, reason: '$language $skill');
          expect(
            askedBySkill[skill] ?? const <String>{},
            isNotEmpty,
            reason: '$language $skill was never asked',
          );
        }
        // Every admitted format is asked, or documented above.
        final admitted = bank.countsByFormat.keys.toSet();
        final here = _notAskedIn[language] ?? const <String, String>{};
        final missing = admitted
            .where(
              (f) =>
                  !asked.contains(f) &&
                  !_notAsked.containsKey(f) &&
                  !here.containsKey(f),
            )
            .toList();
        expect(
          missing,
          isEmpty,
          reason:
              '$language: admitted but never asked, and not on the list of '
              'documented exceptions (asked: ${asked.toList()..sort()})',
        );
        // The list stays honest: a listed format that is asked is removed.
        final stale = <String>[..._notAsked.keys, ...here.keys]
            .where((f) => asked.contains(f) && !kUnaskableFormats.contains(f))
            .toList();
        expect(stale, isEmpty, reason: 'now asked, so remove from the list');
      });
    });
  }
}
