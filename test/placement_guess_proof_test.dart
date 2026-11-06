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
import 'dart:math' as math;

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/generated_question.dart';
import 'package:fluenough/core/placement/guessability.dart';
import 'package:fluenough/core/placement/item_picker.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/placement_run.dart';
import 'package:fluenough/core/placement/placement_session.dart';
import 'package:fluenough/core/placement/question_builder.dart';
import 'package:fluenough/core/placement/question_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

const String _root = 'test/fixtures/sample-decks';

/// The highest deck index (0 based, so unit 20) a guesser may be placed at.
const int _bottom = 19;

const Timeout _long = Timeout(Duration(minutes: 10));

/// Chance of a four-option pick.
const double _chance = 0.25;

/// Five standard deviations of a Bernoulli(0.25) at n = 1000.
const double _margin = 0.07;

typedef _Strategy = int Function(GeneratedQuestion q);

/// Always the first option.
int _first(GeneratedQuestion q) => 0;

/// The option whose letters are most like the prompt's (first on a tie).
int _similar(GeneratedQuestion q) {
  final prompt = q.promptText ?? '';
  var best = 0;
  var bestScore = -1.0;
  for (final (i, option) in q.options.indexed) {
    final score = surfaceSimilarity(prompt, option);
    if (score > bestScore + 1e-12) {
      best = i;
      bestScore = score;
    }
  }
  return best;
}

/// The longest option (first on a tie).
int _longest(GeneratedQuestion q) {
  var best = 0;
  for (final (i, option) in q.options.indexed) {
    if (option.length > q.options[best].length) best = i;
  }
  return best;
}

String _label(String option) {
  final at = option.lastIndexOf(' — ');
  return at < 0 ? '' : option.substring(at + 3);
}

/// The option whose "— person" label differs from the three that agree;
/// the first option where there is no odd one out.
int _oddLabel(GeneratedQuestion q) {
  final labels = <String>[for (final o in q.options) _label(o)];
  for (final (i, label) in labels.indexed) {
    final others = <String>[
      for (final (j, l) in labels.indexed)
        if (j != i) l,
    ];
    if (others.toSet().length == 1 && others.first != label) return i;
  }
  return 0;
}

String _shape(String option) =>
    '${option.split(' ').length}:${option.contains('(')}';

/// The first option of the most common shape (word count and brackets).
int _commonShape(GeneratedQuestion q) {
  final shapes = <String>[for (final o in q.options) _shape(o)];
  var best = 0;
  var bestCount = 0;
  for (final (i, shape) in shapes.indexed) {
    final count = shapes.where((s) => s == shape).length;
    if (count > bestCount) {
      best = i;
      bestCount = count;
    }
  }
  return best;
}

final Map<String, _Strategy> _strategies = <String, _Strategy>{
  'first option': _first,
  'most like the prompt': _similar,
  'longest': _longest,
  'odd label out': _oddLabel,
  'most common shape': _commonShape,
};

PlacementQuestionRequest _request(
  PlacementVariant variant, {
  required PlacementTopic topic,
  required PlacementQuestionKind kind,
  required int deck,
  required int pick,
}) => PlacementQuestionRequest(
  number: 1,
  role: PlacementQuestionRole.base,
  topic: topic,
  variant: variant,
  kind: kind,
  skills: const <PlacementSkill>[PlacementSkill.read],
  deck: deck,
  percentile: 0,
  shortlistPick: pick,
);

/// The language's decks as the sample deck holds them, native English.
PlacementLanguageData _sample(Catalog catalog, String code) {
  final entries = <DeckEntry>[
    for (final entry in catalog.decks)
      if (entry.language.code == code &&
          entry.deck.native.code == 'en' &&
          entry.cards.isNotEmpty)
        entry,
  ];
  return PlacementLanguageData(
    language: code,
    decks: <PlacementDeck>[
      for (final entry in entries)
        PlacementDeck(id: entry.id, cards: entry.cards),
    ],
  );
}

/// Pick questions of the written-word and long-sentence kinds, over many
/// decks, shortlist picks and seeds.
List<GeneratedQuestion> _questions(PlacementLanguageData data) {
  final out = <GeneratedQuestion>[];
  for (var seed = 0; seed < 200; seed++) {
    final builder = QuestionBuilder(data, seed: seed);
    for (var deck = 0; deck < data.deckCount; deck++) {
      for (var pick = 0; pick < 5; pick++) {
        for (final request in <PlacementQuestionRequest>[
          _request(
            PlacementVariant.w1,
            topic: PlacementTopic.complexWords,
            kind: PlacementQuestionKind.pickOne,
            deck: deck,
            pick: pick,
          ),
          _request(
            PlacementVariant.k1,
            topic: PlacementTopic.longRecognition,
            kind: PlacementQuestionKind.pickMany,
            deck: deck,
            pick: pick,
          ),
        ]) {
          final outcome = builder.build(request);
          if (outcome is QuestionBuilt &&
              outcome.question.mode == PlacementAnswerMode.pick &&
              outcome.question.options.length == 4) {
            out.add(outcome.question);
          }
        }
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// A hundred decks of ten words, for whole runs: no word looks like its gloss,
// so nothing but the placement logic can show through.

Card _card(
  String id,
  String target,
  String native,
  int deck, {
  String pos = 'noun',
  List<CardBase> bases = const <CardBase>[],
  List<CardItem> confusables = const <CardItem>[],
}) => Card(
  id: id,
  deckId: 'deck-$deck',
  target: target,
  native: native,
  pos: pos,
  bases: bases,
  confusables: confusables,
  tags: <String>['t$deck'],
);

PlacementLanguageData _course() {
  const consonants = 'bcdfgklmnprstv';
  const vowels = 'aeiou';
  String word(int n) =>
      '${consonants[n % 14]}${vowels[(n ~/ 14) % 5]}'
      '${consonants[(n ~/ 70) % 14]}a';
  const families = <int, List<String>>{
    40: <String>['plural'],
    60: <String>['case'],
    80: <String>['tense'],
  };
  final decks = <PlacementDeck>[];
  for (var i = 0; i < 100; i++) {
    final cards = <Card>[
      for (var j = 0; j < 10; j++)
        _card('w-$i-$j', word(i * 10 + j), 'thing ${i * 10 + j}', i),
    ];
    if (i >= 30) {
      for (var j = 0; j < 4; j++) {
        final words = <String>[for (var k = 0; k < 9; k++) 'w$i$j$k'];
        cards.add(
          _card(
            's$i-$j',
            words.join(' '),
            'Long sentence $i-$j',
            i,
            pos: 'phrase',
            bases: <CardBase>[CardBase(word: words[2], base: 'root$i$j')],
            confusables: <CardItem>[
              for (var n = 0; n < 3; n++)
                CardItem(id: 'c$n', word: 'w$i${j}z$n'),
            ],
          ),
        );
      }
      for (var j = 0; j < 2; j++) {
        final words = <String>['q$i${j}a', 'q$i${j}b', 'q$i${j}c'];
        cards.add(
          _card(
            'short$i-$j',
            words.join(' '),
            'Short sentence $i-$j',
            i,
            pos: 'phrase',
            bases: <CardBase>[CardBase(word: words[1], base: 'short$i$j')],
            confusables: <CardItem>[
              for (var n = 0; n < 3; n++)
                CardItem(id: 'c$n', word: 'q$i${j}z$n'),
            ],
          ),
        );
      }
    }
    decks.add(
      PlacementDeck(
        id: 'deck-$i',
        cards: cards,
        grammarFamilies: families[i] ?? const <String>[],
      ),
    );
  }
  return PlacementLanguageData(
    language: 'xx',
    decks: decks,
    levelMarkDecks: const <int>[32, 65, 99],
  );
}

PlacementRunConfig _config(int seed) => PlacementRunConfig(
  deckCount: 100,
  skills: const <PlacementSkill>{
    PlacementSkill.read,
    PlacementSkill.hear,
    PlacementSkill.write,
  },
  declaration: PlacementDeclaration.advanced,
  microphone: false,
  seed: seed,
  pathCompleteToB1: true,
  allDecksDownloaded: true,
  grammarUnitDecks: const <int>[40, 60, 80],
);

/// How a simulated learner answers a question.
typedef _Answerer = bool Function(GeneratedQuestion q, math.Random rng);

_Answerer _guesser(String name) {
  switch (name) {
    case 'random':
      return (q, rng) =>
          q.mode == PlacementAnswerMode.pick &&
          rng.nextInt(q.options.length) == q.correctIndex;
    case 'always first':
      return (q, rng) =>
          q.mode == PlacementAnswerMode.pick && q.correctIndex == 0;
    default:
      return (q, rng) =>
          q.mode == PlacementAnswerMode.pick && q.isRightPick(_similar(q));
  }
}

/// A learner who knows the first [units] units, with no slips and no
/// guesses: right on a question about a card of those decks.
_Answerer _knower(int units) =>
    (q, rng) => q.difficulty.deck < units;

typedef _Played = ({
  Map<PlacementSkill, SkillAssurance> atCheckpoint,
  Map<PlacementSkill, SkillAssurance> atEnd,
  bool done,
  List<GeneratedQuestion> asked,
});

/// A run played to its end (or [cap] answers), Keep going at each
/// checkpoint; the readout at the first checkpoint and at the end.
_Played _play(
  PlacementLanguageData data,
  int seed,
  _Answerer answerer, {
  int cap = 75,
}) {
  final session = PlacementSession(_config(seed), data);
  final rng = math.Random(seed * 31 + 7);
  Map<PlacementSkill, SkillAssurance>? first;
  final asked = <GeneratedQuestion>[];
  var answers = 0;
  while (answers < cap + 1) {
    if (session.atCheckpoint) {
      first ??= session.readout;
      if (answers >= cap) break;
      session.keepGoing();
      continue;
    }
    final q = session.question;
    if (q == null) break;
    asked.add(q);
    session.answer(answerer(q, rng));
    answers++;
  }
  final end = session.readout;
  return (
    atCheckpoint: first ?? end,
    atEnd: end,
    done: session.isDone,
    asked: asked,
  );
}

int _highest(Map<PlacementSkill, SkillAssurance> readout) {
  var top = -1;
  for (final found in readout.values) {
    if (found.label == AssuranceLabel.notTested) continue;
    top = math.max(top, found.placedLevel);
  }
  return top;
}

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
          questions = _questions(_sample(catalog, code));
        });

        test('there are enough questions for the margin to be sound', () {
          expect(questions.length, greaterThanOrEqualTo(1000));
        });

        for (final MapEntry(key: name, value: strategy)
            in _strategies.entries) {
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
          _card('w-$j', 'palabra$j', 'word number $j', 1),
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
            _request(
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
      final data = _course();
      for (var seed = 0; seed < 10; seed++) {
        final played = _play(data, seed, _guesser('random'), cap: 50);
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
    final data = _course();

    for (final name in <String>['random', 'always first', 'similarity']) {
      test(
        '"$name": 95% of $runs runs end at unit ${_bottom + 1} or lower',
        () {
          var highCheckpoint = 0;
          var highEnd = 0;
          for (var seed = 0; seed < runs; seed++) {
            final played = _play(data, seed, _guesser(name));
            if (_highest(played.atCheckpoint) > _bottom) highCheckpoint++;
            if (_highest(played.atEnd) > _bottom) highEnd++;
          }
          // At most 5% of the runs (3 of 60) may be placed higher.
          expect(highCheckpoint, lessThanOrEqualTo(3), reason: 'checkpoint');
          expect(highEnd, lessThanOrEqualTo(3), reason: 'end');
        },
      );
    }

    test('a Not sure yet skill is placed at its lower bound', () {
      for (var seed = 0; seed < 20; seed++) {
        final played = _play(data, seed, _guesser('random'));
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
      final data = _course();
      for (final units in <int>[30, 60]) {
        test('$units units', () {
          final played = _play(data, 3, _knower(units), cap: 150);
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
