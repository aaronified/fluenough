import 'dart:math' as math;

import 'assurance_model.dart';
import 'assurance_readout.dart';
import 'generated_question.dart';
import 'placement_data.dart';
import 'placement_questions.dart';
import 'placement_run.dart';
import 'placement_session.dart';
import 'question_bank.dart';
import 'item_picker.dart';

// The replay harness: the real placement engine (run controller, estimator,
// positioning) asked only questions of a bank, each answered by looking it
// up in a persona's answer table, one of several draws chosen per question by
// a seed. Pure Dart; tool/placement_replay.dart writes the outcome tables.

/// What a run showed for one skill.
class SkillOutcome {
  const SkillOutcome({
    required this.unit,
    required this.label,
    required this.atLeast,
  });

  /// The unit shown (0 for "from the start").
  final int unit;
  final AssuranceLabel label;
  final bool atLeast;
}

/// One simulated placement.
class ReplayOutcome {
  const ReplayOutcome({
    required this.persona,
    required this.seed,
    required this.asked,
    required this.atCheckpoint,
    required this.atEnd,
    required this.guessedFallback,
  });

  final String persona;
  final int seed;

  /// Questions asked at the end.
  final int asked;

  /// Each tested skill at the first checkpoint (or the end when none came)
  /// and at the end.
  final Map<PlacementSkill, SkillOutcome> atCheckpoint;
  final Map<PlacementSkill, SkillOutcome> atEnd;

  /// How many questions had no answer in any draw and were guessed.
  final int guessedFallback;
}

Map<PlacementSkill, SkillOutcome> _outcomes(
  Map<PlacementSkill, SkillAssurance> readout,
) => <PlacementSkill, SkillOutcome>{
  for (final e in readout.entries)
    if (e.value.questions > 0)
      e.key: SkillOutcome(
        unit: e.value.placedUnit,
        label: e.value.label,
        atLeast: e.value.lowerBound,
      ),
};

/// One placement of [persona] over [bank]. [draws] are the persona's answer
/// tables (question id to a pick index, an option's text, or a boolean); each
/// question takes the answer of the draw [seed] and its id pick. A question
/// with no answer in that draw is answered by a guess (counted).
ReplayOutcome replayRun({
  required String persona,
  required QuestionBank bank,
  required int deckCount,
  required List<int> levelMarkDecks,
  required List<int> grammarDecks,
  required List<Map<String, Object?>> draws,
  required PlacementDeclaration declaration,
  required int seed,
  int cap = 300,
}) {
  final data = PlacementLanguageData(
    language: 'xx',
    decks: <PlacementDeck>[
      for (var i = 0; i < deckCount; i++)
        PlacementDeck(id: 'd$i', cards: const []),
    ],
    levelMarkDecks: levelMarkDecks,
  );
  final config = PlacementRunConfig(
    deckCount: deckCount,
    skills: const <PlacementSkill>{
      PlacementSkill.read,
      PlacementSkill.hear,
      PlacementSkill.write,
    },
    declaration: declaration,
    microphone: false,
    seed: seed,
    pathCompleteToB1: true,
    allDecksDownloaded: true,
    grammarUnitDecks: grammarDecks,
  );
  final session = PlacementSession(
    config,
    data,
    questionSource: BankedBuilder(bank, deckCount),
  );
  final rng = math.Random(seed * 7919 + 17);
  var fallback = 0;
  Map<PlacementSkill, SkillOutcome>? first;
  var answers = 0;
  while (answers < cap) {
    if (session.atCheckpoint) {
      first ??= _outcomes(session.readout);
      session.keepGoing();
      continue;
    }
    final q = session.question;
    if (q == null) break;
    final id = q.bankId!;
    final pick = stableHash('$seed:$id') % draws.length;
    Object? answer = draws[pick][id];
    if (answer == null) {
      for (final draw in draws) {
        answer ??= draw[id];
      }
    }
    final bool correct;
    if (answer == null) {
      fallback++;
      correct =
          q.mode == PlacementAnswerMode.pick &&
          q.isRightPick(rng.nextInt(q.options.length));
    } else {
      correct = judgeAnswer(q, answer);
    }
    session.answer(correct);
    answers++;
  }
  final end = _outcomes(session.readout);
  return ReplayOutcome(
    persona: persona,
    seed: seed,
    asked: session.asked,
    atCheckpoint: first ?? end,
    atEnd: end,
    guessedFallback: fallback,
  );
}
