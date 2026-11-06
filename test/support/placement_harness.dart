// The adversarial harness of Find my level (owner, 2026-11-06): simulated
// learners and rogue guessers that play generated questions and whole runs,
// reusable by any placement test. lib/core only (plus the sample deck
// catalog for the sample languages).
//
// The API:
// - [SimulatedLearner]: `knows(card)` and `answer(question, data, rng)`.
//   [RogueGuesser] (a strategy over the options, knows nothing),
//   [KnowsFirstUnits] (knows every card of the first n decks, no slips),
//   [KnownWordsLearner] (knows the cards whose target is in a set, guesses
//   the rest at random; [KnownWordsLearner.fromJson] reads a profile such as
//   test/fixtures/placement/es-amateur-100.json: a JSON object with a list
//   under "words", "known" or "targets", or a plain list, of targets).
// - [playRun]: a seeded run of a [PlacementSession] over a course, Keep
//   going at each checkpoint, with the readout at the first checkpoint and
//   at the end.
// - [optionStrategies]: the guessing strategies over a question's options.
// - [sampleLanguageData], [generateQuestions], [syntheticCourse],
//   [runConfig], [highestPlaced].
import 'dart:convert';
import 'dart:math' as math;

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/generated_question.dart';
import 'package:fluenough/core/placement/guessability.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/placement_run.dart';
import 'package:fluenough/core/placement/placement_session.dart';
import 'package:fluenough/core/placement/question_builder.dart';

typedef OptionStrategy = int Function(GeneratedQuestion q);

/// Always the first option.
int pickFirst(GeneratedQuestion q) => 0;

/// The option whose letters are most like the prompt's (first on a tie).
int pickMostSimilar(GeneratedQuestion q) {
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
int pickLongest(GeneratedQuestion q) {
  var best = 0;
  for (final (i, option) in q.options.indexed) {
    if (option.length > q.options[best].length) best = i;
  }
  return best;
}

String optionLabel(String option) {
  final at = option.lastIndexOf(' — ');
  return at < 0 ? '' : option.substring(at + 3);
}

/// The option whose "— person" label differs from the three that agree;
/// the first option where there is no odd one out.
int pickOddLabel(GeneratedQuestion q) {
  final labels = <String>[for (final o in q.options) optionLabel(o)];
  for (final (i, label) in labels.indexed) {
    final others = <String>[
      for (final (j, l) in labels.indexed)
        if (j != i) l,
    ];
    if (others.toSet().length == 1 && others.first != label) return i;
  }
  return 0;
}

String optionShape(String option) =>
    '${option.split(' ').length}:${option.contains('(')}';

/// The first option of the most common shape (word count and brackets).
int pickCommonShape(GeneratedQuestion q) {
  final shapes = <String>[for (final o in q.options) optionShape(o)];
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

final Map<String, OptionStrategy> optionStrategies = <String, OptionStrategy>{
  'first option': pickFirst,
  'most like the prompt': pickMostSimilar,
  'longest': pickLongest,
  'odd label out': pickOddLabel,
  'most common shape': pickCommonShape,
};

PlacementQuestionRequest wordRequest(
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
PlacementLanguageData sampleLanguageData(Catalog catalog, String code) {
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
List<GeneratedQuestion> generateQuestions(PlacementLanguageData data) {
  final out = <GeneratedQuestion>[];
  for (var seed = 0; seed < 200; seed++) {
    final builder = QuestionBuilder(data, seed: seed);
    for (var deck = 0; deck < data.deckCount; deck++) {
      for (var pick = 0; pick < 5; pick++) {
        for (final request in <PlacementQuestionRequest>[
          wordRequest(
            PlacementVariant.w1,
            topic: PlacementTopic.complexWords,
            kind: PlacementQuestionKind.pickOne,
            deck: deck,
            pick: pick,
          ),
          wordRequest(
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

Card courseCard(
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

PlacementLanguageData syntheticCourse() {
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
        courseCard('w-$i-$j', word(i * 10 + j), 'thing ${i * 10 + j}', i),
    ];
    if (i >= 30) {
      for (var j = 0; j < 4; j++) {
        final words = <String>[for (var k = 0; k < 9; k++) 'w$i$j$k'];
        cards.add(
          courseCard(
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
          courseCard(
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

PlacementRunConfig runConfig(int seed) => PlacementRunConfig(
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

/// A learner the harness plays: what the learner [knows] and how it
/// [answer]s a generated question of [data]. Deterministic given [rng].
abstract class SimulatedLearner {
  const SimulatedLearner();

  /// Whether the learner knows [card] (can answer a question about it).
  bool knows(Card card);

  /// Whether the learner answers [question] right.
  bool answer(
    GeneratedQuestion question,
    PlacementLanguageData data,
    math.Random rng,
  );
}

/// A learner who knows nothing and picks an option by [strategy] ([random]
/// when null); anything that is not a pick is wrong.
class RogueGuesser extends SimulatedLearner {
  const RogueGuesser(this.name, [this.strategy]);

  final String name;

  /// The strategy over the options, or null for a uniformly random pick.
  final OptionStrategy? strategy;

  @override
  bool knows(Card card) => false;

  @override
  bool answer(
    GeneratedQuestion question,
    PlacementLanguageData data,
    math.Random rng,
  ) {
    if (question.mode != PlacementAnswerMode.pick || question.options.isEmpty) {
      return false;
    }
    final pick =
        strategy?.call(question) ?? rng.nextInt(question.options.length);
    return question.isRightPick(pick);
  }
}

/// A learner who knows every card of the first [units] decks, with no slips
/// and no guesses.
class KnowsFirstUnits extends SimulatedLearner {
  const KnowsFirstUnits(this.units);

  final int units;

  @override
  bool knows(Card card) => false;

  @override
  bool answer(
    GeneratedQuestion question,
    PlacementLanguageData data,
    math.Random rng,
  ) => question.difficulty.deck < units;
}

/// A learner who knows the cards whose target is in [targets] and guesses
/// (at random) at the rest. A question about a card is known when its card
/// is; a pick is guessed uniformly, anything else is wrong.
class KnownWordsLearner extends SimulatedLearner {
  KnownWordsLearner(Iterable<String> targets)
    : targets = <String>{for (final t in targets) t.toLowerCase()};

  /// A profile as JSON: a list of targets, or an object holding one under
  /// "words", "known" or "targets" (entries are strings, or objects with a
  /// "target" or "word").
  factory KnownWordsLearner.fromJson(String json) {
    final decoded = jsonDecode(json);
    final Object? list = decoded is List
        ? decoded
        : decoded is Map
        ? (decoded['words'] ?? decoded['known'] ?? decoded['targets'])
        : null;
    return KnownWordsLearner(<String>[
      for (final entry in list is List ? list : const <Object?>[])
        if (entry is String)
          entry
        else if (entry is Map)
          '${entry['target'] ?? entry['word'] ?? ''}',
    ]);
  }

  final Set<String> targets;

  @override
  bool knows(Card card) => targets.contains(card.target.toLowerCase());

  @override
  bool answer(
    GeneratedQuestion question,
    PlacementLanguageData data,
    math.Random rng,
  ) {
    final id = question.cardId;
    final card = id == null ? null : data.cardById(id);
    if (card != null && knows(card)) return true;
    if (question.mode != PlacementAnswerMode.pick || question.options.isEmpty) {
      return false;
    }
    return question.isRightPick(rng.nextInt(question.options.length));
  }
}

/// The rogue guessers of the tests: random, always the first option, and
/// the option most like the prompt.
const Map<String, SimulatedLearner> rogueGuessers = <String, SimulatedLearner>{
  'random': RogueGuesser('random'),
  'always first': RogueGuesser('always first', pickFirst),
  'similarity': RogueGuesser('similarity', pickMostSimilar),
};

typedef PlayedRun = ({
  Map<PlacementSkill, SkillAssurance> atCheckpoint,
  Map<PlacementSkill, SkillAssurance> atEnd,
  bool done,
  List<GeneratedQuestion> asked,
});

/// A run played to its end (or [cap] answers), Keep going at each
/// checkpoint; the readout at the first checkpoint and at the end.
PlayedRun playRun(
  PlacementLanguageData data,
  int seed,
  SimulatedLearner learner, {
  int cap = 75,
}) {
  final session = PlacementSession(runConfig(seed), data);
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
    session.answer(learner.answer(q, data, rng));
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

int highestPlaced(Map<PlacementSkill, SkillAssurance> readout) {
  var top = -1;
  for (final found in readout.values) {
    if (found.label == AssuranceLabel.notTested) continue;
    top = math.max(top, found.placedLevel);
  }
  return top;
}
