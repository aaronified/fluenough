// Find my level must not be beatable by a learner who knows no word of the
// language (owner report 2026-11-06, Spanish: "this kind of questions in
// placement can easily be guessed", and "Read: unit 108" for about 100
// words known). wiki/Plan-Placement-V2.md, "Guess-proof questions".
//
// Rogue guessers play generated questions and whole runs. Everything here
// reads lib/core only; the sample decks (test/fixtures/sample-decks) are
// loaded through the catalog, as sample_decks_test.dart does.
//
// The maths. A strategy that has no information about the
// right option is a Bernoulli trial with p = 1/k (k options) on every
// question, so over n questions its accuracy has standard deviation
// sqrt(p (1 - p) / n). For k = 4 and n >= 1000 that is at most 0.0137; the
// allowed margin of 0.07 is five standard deviations, so an honest question
// set fails it about once in 3.5 million. The questions are drawn from the
// same few hundred cards under many seeds (the seed changes the distractors
// and the order of the options), so n is not fully independent; the margin
// is the one a strategy would have to beat by *information in the options*,
// and 0.07 is far below what the old leaks gave (a similarity guesser got
// about 0.6 on the pattern cells' "lemma (gloss) - person" options).
//
// Where a guesser is placed is tested in placement_credit_model_test.dart
// (the model, 3000 runs per profile) and placement_replay_test.dart (the
// engine over the banks).
@Timeout(Duration(minutes: 30))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/guessability.dart';
import 'package:fluenough/core/placement/generated_question.dart';
import 'package:fluenough/core/placement/item_picker.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/question_bank.dart';
import 'package:fluenough/core/placement/question_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_harness.dart';

void main() {
  group('rogue guessers over the generated banks (S6)', () {
    for (final code in <String>['es', 'hi']) {
      group('the $code bank', () {
        late List<GeneratedQuestion> questions;

        setUpAll(() {
          final pub = jsonDecode(
            File('test/fixtures/placement/banks/$code-bank.json')
                .readAsStringSync(),
          ) as Map<String, Object?>;
          final key = jsonDecode(
            File('test/fixtures/placement/banks/$code-bank-key.json')
                .readAsStringSync(),
          ) as Map<String, Object?>;
          final bank = bankFromJson(
            pub['questions']! as List<Object?>,
            key['questions']! as Map<String, Object?>,
            language: code,
          );
          questions = <GeneratedQuestion>[
            for (final e in bank.entries)
              if (e.question.mode == PlacementAnswerMode.pick) e.question,
          ];
        });

        for (final MapEntry(key: name, value: strategy)
            in optionStrategies.entries) {
          test(
            '"$name": on counted questions its 99% bound is under the floor',
            () {
              // Questions with a cue are left out of the credit posterior (plan
              // section 13), so what must hold is that on the questions that
              // count no strategy beats the guess floor (base + 0.10): the 99%
              // upper bound of its success (normal approximation, 2.576 sd) is
              // at most the mean floor, over at least 2,000 counted questions.
              var n = 0;
              var right = 0;
              var floor = 0.0;
              for (final q in questions) {
                final base = creditBaseOf(q);
                if (base == null || base >= 1) continue;
                n++;
                floor += base + creditKappa;
                if (q.isRightPick(strategy(q))) right++;
              }
              expect(
                n,
                greaterThanOrEqualTo(2000),
                reason: 'counted questions',
              );
              final p = right / n;
              final upper = p + 2.576 * math.sqrt(p * (1 - p) / n);
              expect(
                upper,
                lessThanOrEqualTo(floor / n),
                reason: '$name got $right of $n counted',
              );
            },
          );
        }
      });
    }
  });

  group('pattern cells are never questions', () {
    test('a table of "lemma (gloss) — person" cells is never asked', () {
      final cells = <Card>[
        for (final verb in <String>['dormir', 'comer', 'vivir', 'escribir'])
          for (final (i, person) in <String>['yo', 'tú', 'él/ella'].indexed)
            Card(
              id: 'es-grammar-estar-$verb-$i',
              deckId: 'deck-1',
              target: 'estoy ${verb}iendo',
              native: '$verb (to $verb) — $person',
              modes: DrillMode.vocabulary,
            ),
      ];
      final words = <Card>[
        for (var j = 0; j < 12; j++)
          courseCard('w-$j', 'palabra$j', 'word number $j', 1),
      ];
      final data = PlacementLanguageData(
        language: 'es',
        decks: <PlacementDeck>[
          PlacementDeck(id: 'deck-0', cards: words),
          PlacementDeck(id: 'deck-1', cards: <Card>[...cells, ...words]),
        ],
      );
      for (var seed = 0; seed < 40; seed++) {
        final builder = QuestionBuilder(data, seed: seed);
        for (var pick = 0; pick < 5; pick++) {
          final outcome = builder.build(
            wordRequest(
              PlacementVariant.w1,
              topic: PlacementTopic.complexWords,
              kind: PlacementQuestionKind.pickOne,
              deck: 1,
              pick: pick,
            ),
          );
          final q = (outcome as QuestionBuilt).question;
          expect(q.cardId, startsWith('w-'));
          for (final option in q.options) {
            expect(option, isNot(contains(') — ')));
          }
        }
      }
    });
  });

  group('a run never asks the same word family twice', () {
    test('first questions, probes and top-ups differ in lemma family', () {
      final data = syntheticCourse();
      for (var seed = 0; seed < 4; seed++) {
        final played = playRun(data, seed, rogueGuessers['random']!, cap: 30);
        final seen = <String>{};
        for (final q in played.asked) {
          final role = q.request.role;
          if (role != PlacementQuestionRole.base &&
              role != PlacementQuestionRole.probe &&
              role != PlacementQuestionRole.topUp) {
            continue;
          }
          final id = q.cardId;
          if (id == null) continue;
          final families = wordFamilies(data.cardById(id)!, data);
          expect(
            families.intersection(seen),
            isEmpty,
            reason: 'seed $seed asked family of $id again',
          );
          seen.addAll(families);
        }
      }
    });
  });
}
