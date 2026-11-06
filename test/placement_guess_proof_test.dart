// Find my level must not be beatable by a learner who knows no word of the
// language (owner report 2026-11-06, Spanish: "this kind of questions in
// placement can easily be guessed", and "Read: unit 108" for about 100
// words known). wiki/Plan-Placement-V2.md, "Guess-proof questions".
//
// Rogue guessers play generated questions and whole runs. Everything here
// reads lib/core only; the sample decks (test/fixtures/sample-decks) are
// loaded through the catalog, as sample_decks_test.dart does.
//
// The maths of the margins. A strategy that has no information about the
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
// The run statistics. A guesser's placement is bounded by [_bottom]; the
// claim is that at least 95% of seeded runs stay under it. With 60 runs per
// strategy a true failure rate of 1% fails the test (4 or more failures)
// with probability about 0.3%, and a true rate of 10% passes it with
// probability about 3%.
import 'dart:io';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/generated_question.dart';
import 'package:fluenough/core/placement/item_picker.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/question_builder.dart';
import 'package:fluenough/core/placement/question_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/placement_harness.dart';

const String _root = 'test/fixtures/sample-decks';

/// The highest deck index (0 based, so unit 20) a guesser may be placed at.
const int _bottom = 19;

const Timeout _long = Timeout(Duration(minutes: 10));

/// Chance of a four-option pick.
const double _chance = 0.25;

/// Five standard deviations of a Bernoulli(0.25) at n = 1000.
const double _margin = 0.07;

void main() {
  late Catalog catalog;

  setUpAll(() async {
    expect(Directory(_root).existsSync(), isTrue);
    catalog = await DeckCatalog(RepositoryDeckSource(_root)).load();
  });

  group('rogue guessers over generated questions', () {
    for (final code in <String>['es', 'te']) {
      group('the sample $code deck', () {
        late List<GeneratedQuestion> questions;

        setUpAll(() {
          questions = generateQuestions(sampleLanguageData(catalog, code));
        });

        test('there are enough questions for the margin to be sound', () {
          expect(questions.length, greaterThanOrEqualTo(1000));
        });

        for (final MapEntry(key: name, value: strategy)
            in optionStrategies.entries) {
          test('"$name" stays within chance (1/4 +- $_margin)', () {
            var right = 0;
            for (final q in questions) {
              if (q.isRightPick(strategy(q))) right++;
            }
            final accuracy = right / questions.length;
            expect(
              accuracy,
              closeTo(_chance, _margin),
              reason: '$name got $right of ${questions.length}',
            );
          });
        }

        test('options are alike: nothing odd in their labels or shapes', () {
          for (final q in questions) {
            expect(q.options.toSet(), hasLength(q.options.length));
            // No "lemma (gloss) — person" cell is ever an option.
            for (final option in q.options) {
              expect(option, isNot(contains(') — ')));
            }
          }
        });
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

  group('a run never asks the same word family twice', timeout: _long, () {
    test('first questions, probes and top-ups differ in lemma family', () {
      final data = syntheticCourse();
      for (var seed = 0; seed < 10; seed++) {
        final played = playRun(data, seed, rogueGuessers['random']!, cap: 50);
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

  group('rogue guessers are placed at the bottom', timeout: _long, () {
    const runs = 60;
    final data = syntheticCourse();

    for (final name in <String>['random', 'always first', 'similarity']) {
      test(
        '"$name": 95% of $runs runs end at unit ${_bottom + 1} or lower',
        () {
          var highCheckpoint = 0;
          var highEnd = 0;
          for (var seed = 0; seed < runs; seed++) {
            final played = playRun(data, seed, rogueGuessers[name]!);
            if (highestPlaced(played.atCheckpoint) > _bottom) highCheckpoint++;
            if (highestPlaced(played.atEnd) > _bottom) highEnd++;
          }
          // At most 5% of the runs (3 of 60) may be placed higher.
          expect(highCheckpoint, lessThanOrEqualTo(3), reason: 'checkpoint');
          expect(highEnd, lessThanOrEqualTo(3), reason: 'end');
        },
      );
    }

    test('a Not sure yet skill is placed at its lower bound', () {
      for (var seed = 0; seed < 20; seed++) {
        final played = playRun(data, seed, rogueGuessers['random']!);
        for (final found in played.atCheckpoint.values) {
          if (found.label != AssuranceLabel.notSureYet) continue;
          expect(found.lowerBound, isTrue);
          expect(found.placedLevel, lessThanOrEqualTo(_bottom));
        }
      }
    });
  });

  group(
    'a learner who knows the first units is still placed near them',
    timeout: _long,
    () {
      final data = syntheticCourse();
      for (final units in <int>[30, 60]) {
        test('$units units', () {
          final played = playRun(data, 3, KnowsFirstUnits(units), cap: 150);
          expect(played.done, isTrue);
          for (final found in played.atEnd.values) {
            if (found.label == AssuranceLabel.notTested) continue;
            expect(
              found.placedLevel,
              inInclusiveRange(units - 1 - 12, units - 1 + 12),
              reason: '${found.skill.name} of $units units',
            );
            expect(trustsPointEstimate(found.label), isTrue);
          }
        });
      }
    },
  );
}
